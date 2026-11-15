extends SceneTree
const Transport = preload("res://chat_transport.gd")
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
class FakeTransport extends Transport:
	var starts := 0
	var payload := {}
	func configured() -> bool: return true
	func begin(data: Dictionary) -> String:
		starts += 1
		payload = data.duplicate(true)
		return reserve(Time.get_unix_time_from_system())
	func cancel(_reason: String = "cancelled") -> void: pass
class FailedStore extends RefCounted:
	func save_state(_state: Dictionary) -> bool: return false
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fixture():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.saving_enabled = true
	scene.journal_enabled = true
	scene.journal.start(0)
	scene.store = Store.new("/tmp/cozy-proposal-world-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"proposal-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"reserved":"keep"}]}
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	return scene
func response(token: String, proposal: String = "rest_in_shade") -> Dictionary:
	return {"status":"ok","source":"codex_subscription","reply":"想去树荫歇一会儿，这只是我的想法。","proposal":proposal,"decision_token":token}
func run() -> void:
	root.size = Vector2i(1200,800)
	var scene = fixture()
	var ticket: Dictionary = scene._issue_model_decision()
	check(ticket.ok and ticket.token.length()==32,"Manual decision receives a unique nonce")
	var answer := response(ticket.token)
	check(scene._apply_model_decision(answer).ok and scene.resident.user_action.phase()=="queued","Allowed model proposal passes through real saved executor")
	check(not scene._apply_model_decision(answer).ok and scene.resident.user_action.latest.id==1,"Replayed response cannot enqueue twice")
	check(not scene._issue_model_decision().ok,"Active action prevents another paid decision before request begins")
	var declined = fixture()
	ticket = declined._issue_model_decision()
	check(declined._apply_model_decision(response(ticket.token,"none")).ok and declined.resident.user_action.latest.is_empty(),"Elm may choose no action without inventing a request")
	var stale = fixture()
	ticket = stale._issue_model_decision()
	stale.model_decision_ticket.issued_ms -= 90001
	check(not stale._apply_model_decision(response(ticket.token)).ok,"Expired suggestion cannot execute")
	ticket = stale._issue_model_decision()
	stale.state_template.world_id = "changed"
	check(not stale._apply_model_decision(response(ticket.token)).ok,"Different world refuses suggestion")
	ticket = stale._issue_model_decision()
	stale.resident.catalog.locations["place.tree_shade"].position = [6.8,1.1]
	check(not stale._apply_model_decision(response(ticket.token)).ok,"Changed layout refuses suggestion")
	ticket = stale._issue_model_decision()
	stale._submit_local_action("去树荫歇一会儿")
	check(not stale._apply_model_decision(response(ticket.token)).ok and stale.resident.user_action.latest.id==1,"Intervening local action makes model result stale")
	var invalid = fixture()
	for mutation in [{"proposal":"build_house"},{"target":"outside"},{"source":"unknown"},{"reply":""},{"proposal":[]}]:
		ticket = invalid._issue_model_decision()
		answer = response(ticket.token)
		answer.merge(mutation,true)
		check(not invalid._apply_model_decision(answer).ok and invalid.resident.user_action.latest.is_empty(),"Malformed proposal never changes world")
	ticket = invalid._issue_model_decision()
	check(not invalid._apply_model_decision(response("wrong")).ok and invalid.model_decision_ticket.token==ticket.token,"Wrong token cannot consume a different pending decision")
	invalid.store = FailedStore.new()
	check(not invalid._apply_model_decision(response(ticket.token)).ok and invalid.resident.user_action.latest.is_empty(),"Failed disk save rejects proposed action and rolls back")
	var closed = fixture()
	var panel = closed.chat_panel
	var fake = FakeTransport.new()
	fake.base = "/tmp/cozy-proposal-budget-"+str(OS.get_process_id())
	panel.transport = fake
	panel.open_chat()
	panel.mode_picker.select(2)
	panel.entry.text = "你想去树荫歇一会儿吗？"
	panel.send_message()
	check(panel.pending and fake.starts==1 and fake.payload.kind=="decision","Third mode is explicitly sent once, not parsed as a local command")
	check(fake.budget_status(Time.get_unix_time_from_system()).remaining==2,"Decision uses the existing shared attempt ledger")
	ticket = {"token":panel.decision_token}
	panel.close_chat()
	panel.finish_network(response(ticket.token))
	check(closed.resident.user_action.latest.is_empty() and closed.model_decision_ticket.is_empty(),"Closing chat invalidates late proposal and outstanding ticket")
	# A fresh isolated budget and a valid reply: full UI-to-executor path, no real model.
	var ready = fixture()
	panel = ready.chat_panel
	fake = FakeTransport.new()
	fake.base = "/tmp/cozy-proposal-ready-"+str(OS.get_process_id())
	panel.transport = fake
	panel.open_chat()
	panel.mode_picker.select(2)
	panel.entry.text = "去树荫歇一会儿"
	panel.send_message()
	check(panel.pending and ready.resident.user_action.latest.is_empty(),"Decision mode does not bypass the model via local exact-command shortcut")
	panel.finish_network(response(panel.decision_token))
	check(ready.resident.user_action.phase()=="queued" and panel.transcript.back().speaker=="程序检查结果","Validated UI response separates model wish from actual enqueue")
	check(not panel.pending and panel.decision_token.is_empty(),"Finished proposal is consumed once")
	# Cancellation and late delivery remain safe.
	var cancelled = fixture()
	panel = cancelled.chat_panel
	fake = FakeTransport.new()
	fake.base = "/tmp/cozy-proposal-cancel-"+str(OS.get_process_id())
	panel.transport = fake
	panel.open_chat()
	panel.mode_picker.select(2)
	panel.entry.text = "你要不要休息？"
	panel.send_message()
	var token: String = panel.decision_token
	panel.cancel_network()
	panel.finish_network(response(token))
	check(cancelled.resident.user_action.latest.is_empty(),"Cancelled proposal cannot execute later")
	# Ordinary real chat never invokes the proposal executor.
	var ordinary = fixture()
	panel = ordinary.chat_panel
	panel.open_chat()
	panel.request_kind = "chat"
	panel.pending = true
	panel.finish_network(response("ignored"))
	check(ordinary.resident.user_action.latest.is_empty(),"Normal chat does not execute unsolicited model actions")
	for child in root.get_children():
		if child is Node3D: child.saving_enabled = false
	print("PROPOSAL_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
