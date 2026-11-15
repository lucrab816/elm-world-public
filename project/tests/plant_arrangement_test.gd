extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Plan = preload("res://plant_arrangement.gd")
const Chat = preload("res://chat_panel.gd")
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
	scene.store = Store.new("/tmp/cozy-plant-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"plant-test","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"keep":true}]}
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	return scene
func run() -> void:
	var scene = fixture()
	for p in Plan.POSITIONS.values(): check(not scene.navigation.clear_point(p,.98),"Placement stays within existing car exclusion geometry")
	var actor = scene.resident
	actor.current_location = "object.bench.001"
	actor.destination_id = actor.current_location
	actor.position = actor._point(actor.current_location)
	actor.mode = "rest"
	actor.remaining = 1
	scene.rest_preference.record(actor.current_location)
	scene.rest_preference.record(actor.current_location)
	check(not scene.plant_arrangement.try_begin(scene,actor),"Two experiences do not cause a placement")
	scene._advance_simulation(1.05)
	check(actor.mode=="arrange_plant" and scene.plant_arrangement.phase=="placing" and scene.arranged_plant==null,"After a completed rest Elm begins the real action, with no premature object")
	check(scene._save_now(),"Mid-action state saves")
	var saved = scene.store.load_state().state
	check(saved.world_state.plant_arrangement.phase=="placing" and saved.memories==[{"keep":true}],"Mid-action state preserves existing memories")
	var fresh = fixture()
	fresh.simulation_seconds = saved.simulation_seconds
	fresh.needs.restore(saved.world_state.basic_life)
	fresh.resident.restore(saved.resident)
	fresh.rest_preference.restore(saved.world_state.rest_preference)
	fresh.plant_arrangement.restore(saved.world_state.plant_arrangement)
	fresh.journal.restore(saved.world_state.life_journal,fresh.simulation_seconds)
	check(fresh.resident.mode=="arrange_plant" and fresh.arranged_plant==null,"Reload resumes the unfinished action without creating the object")
	check(fresh.plant_arrangement.reason().contains("还没有放好"),"In-progress explanation does not claim completion")
	fresh._advance_simulation(5.1)
	check(fresh.plant_arrangement.phase=="placed" and fresh.arranged_plant!=null,"Completion creates an actual plant in the world")
	check(fresh.plant_button.visible,"Completed plant has a viewing entry")
	fresh._look_at_plant()
	check(fresh.focus.distance_to(fresh.arranged_plant.position+Vector3.UP*.35)<.001,"Viewing entry focuses on the real plant")
	check(fresh.arranged_plant.get_meta("object_id")=="object.elm_plant.001" and fresh.plant_arrangement.target=="object.bench.001","Stable object ID and chosen location reflect Elm's rest tendency")
	check(fresh.journal.records.any(func(e): return e.kind=="plant_placed"),"Journal records the completed placement")
	check(Chat.simulated_reply("盆栽放在哪里",fresh._chat_context()).contains("长椅"),"Local chat reports the actual result")
	var original_reason: String = fresh.plant_arrangement.reason()
	check(original_reason.contains("最近3次") and original_reason.contains("3次在长椅"),"Decision records the actual experience at the time")
	for i in range(8): fresh.rest_preference.record("place.tree_shade")
	check(fresh.plant_arrangement.reason()==original_reason,"Later changes to rest preference do not rewrite the original cause")
	check(Chat.simulated_reply("为什么把这盆植物放在这里",fresh._chat_context()).contains("最近3次"),"Local chat explains the actual choice")
	var legacy: Dictionary = saved.world_state.plant_arrangement.duplicate(true)
	legacy.version = 1
	legacy.erase("decision_evidence")
	var migrated = Plan.new()
	migrated.restore(legacy)
	migrated.phase = "placed"
	check(migrated.reason().contains("旧版") and migrated.reason().contains("没有保存当时的具体次数"),"Legacy explanation identifies inference and never invents counts")

	check(fresh._save_now(),"Completed placement saves")
	var done = fresh.store.load_state().state
	check(Store.valid_state(done) and done.world_state.plant_arrangement.phase=="placed","Saved object and action state validate together")
	var broken: Dictionary = saved.duplicate(true)
	broken.world_state.plant_arrangement.target = "unknown"
	check(not Store.valid_state(broken),"Invalid location is rejected")
	broken = saved.duplicate(true)
	broken.world_state.plant_arrangement.decision_evidence.shade_count = 8
	check(not Store.valid_state(broken),"Contradictory evidence cannot be saved")
	broken = saved.duplicate(true)
	broken.world_state.erase("plant_arrangement")
	check(not Store.valid_state(broken),"Orphaned action is rejected")
	var prior = fixture()
	prior.rest_preference.record("object.bench.001")
	prior.rest_preference.record("object.bench.001")
	prior.rest_preference.record("object.bench.001")
	prior.resident.current_location = "object.bench.001"
	prior.resident.ride_requested = true
	check(not prior.plant_arrangement.try_begin(prior,prior.resident),"User's ride invitation has priority")
	prior.resident.ride_requested = false
	prior.needs.satiety = 40
	check(not prior.plant_arrangement.try_begin(prior,prior.resident),"Eating takes priority")
	print("PLANT_ARRANGEMENT_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
