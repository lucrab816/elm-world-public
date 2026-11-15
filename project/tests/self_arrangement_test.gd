extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Transport = preload("res://chat_transport.gd")
const Arrangement = preload("res://self_arrangement.gd")
const Chat = preload("res://chat_panel.gd")
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
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func fixture():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	Engine.max_fps = 0
	scene.saving_enabled = true
	scene.journal_enabled = true
	scene.journal.start(0)
	var base := "/tmp/cozy-self-arrangement-"+str(OS.get_process_id())+"-"+str(root.get_child_count())
	scene.store = Store.new(base+"/saves")
	scene.state_template = {"world_id":"self-test","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"keep":true}]}
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	scene.resident.mode = "observe"
	scene.resident.route.clear()
	scene.resident.remaining = 20
	scene.self_arrangement.transport = FakeTransport.new()
	scene.self_arrangement.transport.base = base+"/requests"
	scene.chat_panel.transport = FakeTransport.new()
	scene.chat_panel.transport.base = base+"/requests"
	scene.plant_arrangement.phase = "placed"
	scene.plant_arrangement.target = "object.bench.001"
	scene.plant_arrangement.decision_evidence = {"source":"legacy_rule"}
	scene._show_arranged_plant(scene.plant_arrangement.target)
	return scene
func answer(scene, choice: String = "none") -> Dictionary:
	return {"status":"ok","source":"codex_subscription","decision_token":scene.self_arrangement.token,"reply":"根据刚才的经历，我想慢慢看看小院。","proposal":choice}
func begin(scene) -> void:
	check(scene.self_arrangement.arm(scene).ok,"One opportunity is durably accepted")
	scene._advance_simulation(.05)
	check(scene.self_arrangement.phase()=="requesting" and scene.self_arrangement.transport.starts==1,"Eligible idle resident makes exactly one request")
func run() -> void:
	var idle = fixture()
	idle._advance_simulation(3)
	check(idle.self_arrangement.latest.is_empty() and idle.self_arrangement.transport.starts==0,"No request without an explicit opportunity")
	idle.resident.ride_requested = true
	check(idle.self_arrangement.arm(idle).ok,"Opportunity may wait for an existing invitation")
	idle.self_arrangement.advance(idle)
	check(idle.self_arrangement.phase()=="waiting" and idle.self_arrangement.transport.starts==0,"Ride invitation takes priority before thinking")
	var waiting: Dictionary = idle.self_arrangement.snapshot()
	idle.self_arrangement.cancel(idle)
	check(idle.self_arrangement.phase()=="cancelled" and idle.self_arrangement.transport.starts==0,"Cancelling a waiting opportunity costs no request")
	var fresh = fixture()
	fresh.self_arrangement.restore(waiting,0)
	fresh._advance_simulation(.1)
	check(fresh.self_arrangement.phase()=="cancelled" and fresh.self_arrangement.transport.starts==0,"Restart cancels waiting opportunity without replay")
	var none = fixture()
	begin(none)
	var requesting: Dictionary = none.self_arrangement.snapshot()
	var payload: Dictionary = none.self_arrangement.transport.payload
	check(payload.kind=="self_arrangement" and payload.context.allowed_choices==["none","rest_in_shade","visit_plant"] and payload.context.rest_experience.completed_in_recent_window==0,"Choice uses actual available actions and bounded experience")
	check(none.chat_panel.transport.budget_status(Time.get_unix_time_from_system()).remaining==4,"Arrangement uses the same ledger as manual chat")
	check(not none.self_arrangement.arm(none).ok and not none._issue_model_decision().ok,"Duplicate opportunity and paid manual proposal are blocked")
	none.chat_panel.open_chat()
	none.chat_panel.mode_picker.select(1)
	none.chat_panel.entry.text = "你好"
	none.chat_panel.send_message()
	check(none.chat_panel.transport.starts==0 and not none.chat_panel.pending,"Concurrent real chat cannot start another request")
	none.chat_panel.close_chat()
	check(none.self_arrangement.phase()=="requesting","Closing unrelated chat does not cancel the explicit opportunity")
	var result: Dictionary = answer(none)
	check(none.self_arrangement.receive(none,result) and none.self_arrangement.phase()=="declined","Choosing regular life is a valid saved outcome")
	check(none.resident.user_action.latest.is_empty() and none.plant_visit.latest.is_empty(),"None creates no phantom execution")
	check(not none.self_arrangement.receive(none,result),"Duplicate result cannot execute twice")
	check(Chat.simulated_reply("刚才你自己安排了什么",none._chat_context()).contains("没有新增行动"),"Local recall distinguishes not acting")
	check(none._save_now() and none.store.load_state().state.memories==[{"keep":true}],"Selection record preserves existing memories")
	var restarted = fixture()
	restarted.self_arrangement.restore(requesting,restarted.simulation_seconds)
	restarted._advance_simulation(.1)
	check(restarted.self_arrangement.phase()=="cancelled" and restarted.self_arrangement.transport.starts==0,"Restart during request does not resubmit")
	var plant = fixture()
	begin(plant)
	check(plant.self_arrangement.receive(plant,answer(plant,"visit_plant")) and plant.plant_visit.phase()=="queued","Plant choice is atomically queued in the existing executor")
	check(plant.self_arrangement.phase()=="executing" and not plant.journal.records.any(func(e): return e.kind=="plant_visit_done"),"Accepted choice is not claimed completed")
	plant._advance_simulation(.05)
	check(plant._save_now(),"Active arrangement saves with real walking progress")
	var saved: Dictionary = plant.store.load_state().state
	var resumed = fixture()
	resumed.simulation_seconds = saved.simulation_seconds
	resumed.resident.restore(saved.resident)
	resumed.needs.restore(saved.world_state.basic_life)
	resumed.plant_visit.restore(saved.world_state.plant_visit)
	resumed.journal.restore(saved.world_state.life_journal,resumed.simulation_seconds)
	resumed.self_arrangement.restore(saved.world_state.self_arrangement,resumed.simulation_seconds)
	for i in range(4000):
		resumed._advance_simulation(.05)
		if resumed.self_arrangement.phase()=="completed": break
	check(resumed.self_arrangement.phase()=="completed" and resumed.plant_visit.phase()=="completed","Restored execution reaches and actually observes plant")
	check(resumed.self_arrangement.transport.starts==0,"Restoring accepted action never repeats the model request")
	check(resumed.journal.records.any(func(e): return e.kind=="plant_visit_done") and resumed.self_arrangement.recall().contains("实际完成"),"Actual outcome and recall agree")
	check(resumed._save_now(),"Completed arrangement remains valid on disk")
	var rest = fixture()
	begin(rest)
	check(rest.self_arrangement.receive(rest,answer(rest,"rest_in_shade")) and rest.resident.user_action.latest.origin=="self_arrangement","Rest choice uses existing executor with truthful origin")
	for i in range(6000):
		rest._advance_simulation(.05)
		if rest.self_arrangement.phase()=="completed": break
	check(rest.self_arrangement.phase()=="completed" and rest.resident.user_action.phase()=="completed","Real requested rest completes before arrangement says done")
	var changed = fixture()
	begin(changed)
	changed._invite_drive()
	check(not changed.self_arrangement.receive(changed,answer(changed,"visit_plant")) and changed.self_arrangement.phase()=="failed" and changed.resident.ride_requested,"New user invitation invalidates a stale model response")
	for condition in ["hungry","tired","rest_invitation","pet_invitation"]:
		var other = fixture()
		match condition:
			"hungry": other.needs.satiety = 50
			"tired": other.needs.energy = 30
			"rest_invitation": other.resident.user_action.enqueue(0)
			"pet_invitation": other.pet_companion.requested = true
		other.self_arrangement.arm(other)
		other.self_arrangement.advance(other)
		check(other.self_arrangement.phase()=="waiting" and other.self_arrangement.transport.starts==0,"Thinking waits for "+condition)
	var cancelled = fixture()
	begin(cancelled)
	result = answer(cancelled,"visit_plant")
	cancelled.self_arrangement.cancel(cancelled,"sleep")
	check(not cancelled.self_arrangement.receive(cancelled,result) and cancelled.plant_visit.latest.is_empty(),"Sleep cancellation rejects a late reply")
	var invalid = fixture()
	begin(invalid)
	result = answer(invalid,"build_house")
	check(not invalid.self_arrangement.receive(invalid,result) and invalid.self_arrangement.phase()=="failed","Unavailable proposal never executes")
	invalid._advance_simulation(2)
	check(invalid.self_arrangement.transport.starts==1,"Failure never causes an automatic retry")
	var fail = fixture()
	fail.store = FailedStore.new()
	check(not fail.self_arrangement.arm(fail).ok and fail.self_arrangement.latest.is_empty() and fail.self_arrangement.transport.starts==0,"Failure to save permission sends nothing")
	var atomic = fixture()
	begin(atomic)
	atomic.store = FailedStore.new()
	check(not atomic.self_arrangement.receive(atomic,answer(atomic,"rest_in_shade")) and atomic.resident.user_action.latest.is_empty() and atomic.self_arrangement.phase()=="failed","Failed decision save rolls back the executor")
	var malformed: Dictionary = saved.duplicate(true)
	malformed.world_state.self_arrangement.latest.execution.id += 20
	check(not Store.valid_state(malformed),"Active execution reference must match actual saved action")
	malformed = saved.duplicate(true)
	malformed.world_state.self_arrangement.latest.observation.energy = 999
	check(not Store.valid_state(malformed),"Impossible observed need is rejected")
	var history = fixture()
	for i in range(16):
		history.self_arrangement.arm(history)
		history.self_arrangement.cancel(history)
	check(history.self_arrangement.history.size()==12 and history.self_arrangement.transport.starts==0,"Bounded history keeps cancellations without spending model calls")
	var private = fixture()
	private._change_explicit_memory("add",0,"称呼","小兔")
	begin(private)
	private.self_arrangement.receive(private,answer(private))
	var original: Dictionary = private.self_arrangement.snapshot()
	var working_store = private.store
	private.store = FailedStore.new()
	check(not private._change_explicit_memory("forget",1,"","").ok and private.self_arrangement.snapshot()==original,"Failed forget restores arrangement quotations")
	private.store = working_store
	check(private._change_explicit_memory("forget",1,"","").ok and private.self_arrangement.latest.reply=="" and private.self_arrangement.phase()=="declined","Successful forget clears quotation but preserves factual outcome")
	var transaction = fixture()
	transaction._change_explicit_memory("add",0,"称呼","树叶")
	begin(transaction)
	var transaction_token: String = transaction.self_arrangement.token
	var original_store = transaction.store
	transaction.store = FailedStore.new()
	check(not transaction._change_explicit_memory("forget",1,"","").ok and transaction.self_arrangement.token==transaction_token,"Failed memory transaction preserves the live one-off token")
	transaction.store = original_store
	check(transaction.self_arrangement.receive(transaction,answer(transaction)),"Original one-off response still works after failed unrelated save")
	var exhausted = fixture()
	for i in range(5): exhausted.self_arrangement.transport.reserve(Time.get_unix_time_from_system()-750+i*130)
	check(not exhausted.self_arrangement.arm(exhausted).ok and exhausted.self_arrangement.transport.starts==0,"A spent shared budget prevents arming without retry")
	var late = fixture()
	begin(late)
	late.self_arrangement.started_ms -= 90001
	check(not late.self_arrangement.receive(late,answer(late,"visit_plant")) and late.plant_visit.latest.is_empty(),"Expired one-off reply cannot enqueue an action")
	var no_plant = fixture()
	no_plant.plant_arrangement.phase = "idle"
	no_plant.plant_arrangement.target = ""
	no_plant.plant_arrangement.decision_evidence.clear()
	no_plant.arranged_plant.queue_free()
	no_plant.arranged_plant = null
	begin(no_plant)
	check(no_plant.self_arrangement.transport.payload.context.allowed_choices==["none","rest_in_shade"],"A missing plant is excluded before asking the model")
	print("SELF_ARRANGEMENT_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
