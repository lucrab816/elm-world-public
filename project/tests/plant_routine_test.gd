extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Routine = preload("res://plant_routine.gd")
const Chat = preload("res://chat_panel.gd")
class BlockedNavigation extends RefCounted:
	func path(_a, _b, _radius, _car) -> PackedVector2Array: return PackedVector2Array()
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
	scene.saving_enabled = true
	scene.journal_enabled = true
	scene.journal.start(0)
	scene.store = Store.new("/tmp/cozy-routine-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"routine-test","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"keep":true}]}
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	scene.plant_arrangement.phase = "placed"
	scene.plant_arrangement.target = "object.bench.001"
	scene.plant_arrangement.decision_evidence = {"source":"legacy_rule"}
	scene._show_arranged_plant(scene.plant_arrangement.target)
	return scene
func ready_actor(scene) -> void:
	scene.resident.mode = "observe"
	scene.resident.route.clear()
	scene.resident.remaining = 20
	scene.needs.satiety = 85
	scene.needs.energy = 90
func finish(scene) -> void:
	for i in range(2400):
		scene._advance_simulation(.05)
		if scene.plant_routine.completed_count>0: break
func run() -> void:
	var scene = fixture()
	ready_actor(scene)
	check(not scene.plant_routine.advance(scene,.05,119) and scene.plant_routine.visit.latest.is_empty(),"Upgrade waits before scheduling and invents no past visits")
	scene.simulation_seconds = 120
	scene._advance_simulation(.05)
	check(scene.plant_routine.visit.phase()=="moving","Eligible idle Elm really starts a local visit")
	check(scene.plant_visit.latest.is_empty() and scene.model_decision_ticket.is_empty(),"Local routine neither fabricates a model proposal nor requests one")
	check(not scene.journal.records.any(func(e): return e.kind=="plant_visit_done"),"Starting the routine is not a completed memory")
	check(scene._save_now(),"Routine mid-walk and timer save with the world")
	var saved = scene.store.load_state().state
	var fresh = fixture()
	fresh.simulation_seconds = saved.simulation_seconds
	fresh.needs.restore(saved.world_state.basic_life)
	fresh.resident.restore(saved.resident)
	fresh.plant_routine.restore(saved.world_state.plant_routine)
	fresh.journal.restore(saved.world_state.life_journal,fresh.simulation_seconds)
	finish(fresh)
	check(fresh.plant_routine.completed_count==1 and fresh.plant_routine.visit.phase()=="completed","Restored walk reaches plant and observes for real")
	check(fresh.journal.records.any(func(e): return e.kind=="plant_visit_done" and e.count==1),"A completed observation produces one factual memory")
	check(Chat.simulated_reply("你自己去看过盆栽吗",fresh._chat_context()).contains("实际完成1次"),"Local conversation recalls actual autonomous completion")
	check(Chat.simulated_reply("你为什么去看盆栽",fresh.chat_panel.context_for("你为什么去看盆栽")).contains("本地日常"),"Latest local routine is not explained using an older model quotation")
	check(fresh._save_now(),"Completion and cooldown persist")
	var done: Dictionary = fresh.store.load_state().state
	var restored = fixture()
	restored.simulation_seconds = done.simulation_seconds
	restored.resident.restore(done.resident)
	restored.needs.restore(done.world_state.basic_life)
	restored.plant_routine.restore(done.world_state.plant_routine)
	restored.journal.restore(done.world_state.life_journal,restored.simulation_seconds)
	restored._advance_simulation(20)
	check(restored.plant_routine.completed_count==1 and restored.plant_routine.next_check==fresh.plant_routine.next_check,"Restart does not replay completion or reset the cooldown")
	check(done.memories==[{"keep":true}] and done.world_state.plant_visit.latest.is_empty(),"Existing memories and model decision storage remain separate")
	var bad: Dictionary = done.duplicate(true)
	bad.world_state.plant_routine.execution.latest.source = "model_proposal"
	check(not Store.valid_state(bad),"A model proposal cannot masquerade as autonomous history")
	bad = done.duplicate(true)
	bad.world_state.plant_visit = bad.world_state.plant_routine.execution.duplicate(true)
	check(not Store.valid_state(bad),"A local visit cannot masquerade as a manual model decision")
	bad = done.duplicate(true)
	bad.world_state.plant_routine.last_completed = done.simulation_seconds+1
	check(not Store.valid_state(bad),"Future completion is rejected")
	var interrupted = fixture()
	ready_actor(interrupted)
	interrupted.simulation_seconds = 120
	interrupted._advance_simulation(.05)
	interrupted.resident.ride_requested = true
	interrupted._advance_simulation(.05)
	check(interrupted.plant_routine.visit.phase()=="failed" and interrupted.plant_routine.completed_count==0 and interrupted.resident.ride_requested,"Ride invitation interrupts local activity without being lost")
	check(not interrupted.journal.records.any(func(e): return e.kind=="plant_visit_done"),"An interrupted routine leaves no false completion")
	var blocked = fixture()
	ready_actor(blocked)
	var navigation = blocked.navigation
	blocked.navigation = BlockedNavigation.new()
	check(not blocked.plant_routine.advance(blocked,.05,120) and blocked.plant_routine.visit.phase()=="failed","Blocked path yields immediately to regular life")
	blocked.navigation = navigation
	for condition in ["hungry","tired","driving","pet_invitation","rest_invitation","manual_visit","pending_model","missing_plant"]:
		var other = fixture()
		ready_actor(other)
		match condition:
			"hungry": other.needs.satiety = 54
			"tired": other.needs.energy = 40
			"driving": other.resident.mode = "drive"
			"pet_invitation": other.pet_companion.requested = true
			"rest_invitation": other.resident.user_action.enqueue(0)
			"manual_visit": other.plant_visit.enqueue("object.bench.001",0)
			"pending_model": other.model_decision_ticket = {"issued_ms":Time.get_ticks_msec()}
			"missing_plant": other.plant_arrangement.phase = "idle"
		check(not other.plant_routine.advance(other,.05,120) and other.plant_routine.visit.latest.is_empty(),"Does not interrupt "+condition)
	# An overdue check that cannot start must still remain saveable after completion.
	ready_actor(restored)
	restored.needs.energy = 40
	restored.simulation_seconds = restored.plant_routine.next_check
	restored.plant_routine.advance(restored,.05,restored.simulation_seconds)
	check(restored._save_now(),"Postponing a due visit does not invalidate completed history")
	var repeat = fixture()
	repeat.simulation_seconds = done.simulation_seconds
	repeat.plant_routine.restore(done.world_state.plant_routine)
	repeat.journal.restore(done.world_state.life_journal,repeat.simulation_seconds)
	repeat.plant_visit.enqueue("object.bench.001",0,true,"先做其他事。")
	var manual_before: Dictionary = repeat.plant_visit.snapshot()
	repeat.simulation_seconds = repeat.plant_routine.next_check
	ready_actor(repeat)
	repeat._advance_simulation(.05)
	for i in range(2400):
		repeat._advance_simulation(.05)
		if repeat.plant_routine.completed_count==2: break
	check(repeat.plant_routine.completed_count==2 and repeat.plant_routine.visit.history.is_empty(),"A later real visit increments count while local execution storage stays bounded")
	check(repeat.plant_visit.snapshot()==manual_before,"Repeated daily visits preserve the original manual model choice and quotation")
	check(repeat._save_now(),"A second visit and original model decision validate together")
	var old = fixture()
	old.plant_routine.start(50000)
	check(old.plant_routine.completed_count==0 and old.plant_routine.next_check==50120,"Old world starts from upgrade time with no offline catch-up")
	var natural = fixture()
	for i in range(9000): natural._advance_simulation(.2)
	check(natural.plant_routine.completed_count>0 and natural.plant_routine.completed_count<=2,"Regular daily scheduling produces occasional visits over 30 isolated minutes")
	check(natural._save_now(),"Naturally scheduled visits remain consistent with resident and needs")
	check(natural.plant_visit.latest.is_empty() and natural.model_decision_ticket.is_empty(),"Extended daily life makes no model request or proposal")
	print("PLANT_ROUTINE_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
