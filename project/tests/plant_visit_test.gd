extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Chat = preload("res://chat_panel.gd")
const Transport = preload("res://chat_transport.gd")
class FailedStore extends RefCounted:
	func save_state(_state: Dictionary) -> bool: return false
class FakeTransport extends Transport:
	var payload := {}
	func configured() -> bool: return true
	func begin(data: Dictionary) -> String:
		payload = data.duplicate(true)
		return reserve(Time.get_unix_time_from_system())
	func cancel(_reason: String = "cancelled") -> void: pass
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
	scene.store = Store.new("/tmp/cozy-plant-visit-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"visit-test","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"keep":true}]}
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	scene.plant_arrangement.phase = "placed"
	scene.plant_arrangement.target = "object.bench.001"
	scene.plant_arrangement.decision_evidence = {"source":"legacy_rule"}
	scene._show_arranged_plant(scene.plant_arrangement.target)
	return scene
func response(token: String, proposal: String) -> Dictionary:
	return {"status":"ok","source":"codex_subscription","reply":"我会根据情况决定。","proposal":proposal,"decision_token":token}
func run() -> void:
	var scene = fixture()
	var ticket: Dictionary = scene._issue_model_decision("plant")
	check(ticket.ok,"Available plant permits a manual decision")
	check(scene._apply_model_decision(response(ticket.token,"visit_plant")).ok and scene.plant_visit.phase()=="queued","A valid model proposal saves a queued visit")
	check(not scene._apply_model_decision(response(ticket.token,"visit_plant")).ok,"A response cannot be replayed")
	check(scene.store.load_state().state.memories==[{"keep":true}],"Queue save preserves existing memory")
	check(scene.store.load_state().state.world_state.plant_visit.latest.decision_note=="我会根据情况决定。","The actual model statement is saved with the decision")
	check(Chat.simulated_reply("为什么去看盆栽",scene.chat_panel.context_for("为什么去看盆栽")).contains("等合适的时候出发"),"Before departure recall states the action is still queued")
	check(not scene.chat_panel.context_for("你好").plant_decision_recall.contains("我会根据情况决定"),"Unrelated chat does not receive the decision statement")
	check(not scene.journal.records.any(func(e): return e.kind=="plant_visit_done"),"A decision is not a completed visit")
	for i in range(3000):
		scene._advance_simulation(.05)
		if scene.plant_visit.phase()=="moving": break
	check(scene.plant_visit.phase()=="moving","Elm actually starts walking toward the plant")
	check(scene._save_now(),"Mid-walk visit saves")
	var saved = scene.store.load_state().state
	var fresh = fixture()
	fresh.simulation_seconds = saved.simulation_seconds
	fresh.needs.restore(saved.world_state.basic_life)
	fresh.resident.restore(saved.resident)
	fresh.plant_visit.restore(saved.world_state.plant_visit)
	fresh.journal.restore(saved.world_state.life_journal,fresh.simulation_seconds)
	check(fresh.plant_visit.phase()=="moving","Walking progress survives restore")
	for i in range(4000):
		fresh._advance_simulation(.05)
		if fresh.plant_visit.phase()=="completed": break
	check(fresh.plant_visit.phase()=="completed","Elm reaches and observes the plant")
	check(fresh.plant_visit.decision_recall().contains("已经看过") and fresh.plant_visit.decision_recall().contains("我会根据情况决定"),"Completed visit keeps the associated actual statement")
	check(fresh.journal.records.any(func(e): return e.kind=="plant_visit_done"),"Only a real completed observation enters the diary")
	check(Chat.simulated_reply("你看过盆栽吗",fresh._chat_context()).contains("已经看过"),"Local recall uses actual completion status")
	check(fresh._save_now() and fresh.store.load_state().state.world_state.plant_visit.latest.phase=="completed","Completed visit is durable")
	var declined = fixture()
	ticket = declined._issue_model_decision("plant")
	check(declined._apply_model_decision(response(ticket.token,"none")).ok and declined.plant_visit.phase()=="declined","Declining is allowed and recorded separately")
	check(not declined.journal.records.any(func(e): return e.kind=="plant_visit_done"),"Decline never invents an arrival")
	check(declined.plant_visit.decision_recall().contains("继续当前生活") and declined.plant_visit.decision_recall().contains("我会根据情况决定"),"Declined choice retains its statement without inventing a visit")
	var old: Dictionary = declined.plant_visit.snapshot()
	old.latest.erase("decision_note")
	declined.plant_visit.restore(old)
	check(declined.plant_visit.decision_recall().contains("没有保存") and not declined.plant_visit.decision_recall().contains("我会根据情况"),"Legacy choice does not invent a reason")
	old.latest.decision_note = "x".repeat(241)
	check(not declined.plant_visit.valid_snapshot(old,declined.simulation_seconds,declined.resident.snapshot(),declined.plant_arrangement.snapshot()),"Oversized statement is rejected")
	var blocked = fixture()
	blocked.store = FailedStore.new()
	ticket = blocked._issue_model_decision("plant")
	check(not blocked._apply_model_decision(response(ticket.token,"visit_plant")).ok and blocked.plant_visit.latest.is_empty(),"Failed save rolls back a proposal")
	var interrupted = fixture()
	ticket = interrupted._issue_model_decision("plant")
	interrupted._apply_model_decision(response(ticket.token,"visit_plant"))
	for i in range(200):
		interrupted._advance_simulation(.05)
		if interrupted.plant_visit.phase()=="moving": break
	interrupted.resident.ride_requested = true
	check(interrupted._save_now(),"A new user invitation can be saved mid-walk")
	interrupted._advance_simulation(.05)
	check(interrupted.plant_visit.phase()=="queued" and not interrupted.journal.records.any(func(e): return e.kind=="plant_visit_done"),"User invitation pauses the visit without false completion")
	var wrong = fixture()
	ticket = wrong._issue_model_decision("plant")
	check(not wrong._apply_model_decision(response(ticket.token,"rest_in_shade")).ok,"Different decision scope is rejected")
	var ui = fixture()
	var panel = ui.chat_panel
	var fake = FakeTransport.new()
	fake.base = "/tmp/cozy-plant-ui-"+str(OS.get_process_id())
	panel.transport = fake
	panel.open_chat()
	panel.mode_picker.select(3)
	panel.entry.text = "你想去看看盆栽吗？"
	panel.send_message()
	check(panel.pending and fake.payload.kind=="plant_decision","New decision mode explicitly sends the plant scope")
	panel.finish_network(response(panel.decision_token,"visit_plant"))
	check(ui.plant_visit.phase()=="queued" and panel.transcript.back().speaker=="程序检查结果","UI separates model wish from real queued action")
	var privacy = fixture()
	check(privacy._change_explicit_memory("add",0,"称呼","小兔").ok,"User fact can be saved")
	ticket = privacy._issue_model_decision("plant")
	privacy._apply_model_decision(response(ticket.token,"visit_plant"))
	var safe_store = privacy.store
	privacy.store = FailedStore.new()
	check(not privacy._change_explicit_memory("forget",1,"","").ok and privacy.plant_visit.latest.has("decision_note") and privacy.explicit_memory.records.size()==1,"Failed forget restores both user fact and statement")
	privacy.store = safe_store
	check(privacy._change_explicit_memory("forget",1,"","").ok and not privacy.plant_visit.latest.has("decision_note") and privacy.plant_visit.phase()=="queued","Forgetting removes quoted text but preserves the actual queued action")
	print("PLANT_VISIT_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
