extends SceneTree
const Choice = preload("res://rest_choice.gd")
const Life = preload("res://basic_life.gd")
const Store = preload("res://save_store.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func wait_for_rest(scene) -> void:
	for i in range(2400):
		scene._advance_simulation(0.05)
		if scene.resident.mode=="rest":
			return
func _run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://world.layout.json"))
	var gentle := Choice.choose(layout,90,"gentle")
	var strong := Choice.choose(layout,90,"strong")
	check(gentle.destination=="object.bench.001","Gentle sunlight favors the seat")
	check(strong.destination=="place.tree_shade","Strong sunlight favors shade for a rested resident")
	check(gentle.reason.contains("座位") and strong.reason.contains("树荫"),"Reasons describe real choice factors")
	check(Choice.choose(layout,10,"strong").destination=="object.bench.001","Low energy gives seated rest priority")
	var altered: Dictionary = layout.duplicate(true)
	altered.locations["place.tree_shade"].comfort.shade = 0
	check(Choice.choose(altered,90,"strong").destination=="object.bench.001","Removing shade changes the preferred destination")
	altered = layout.duplicate(true)
	altered.locations.erase("object.bench.001")
	check(Choice.choose(altered,10,"gentle").destination=="place.tree_shade","Missing furniture is excluded")
	altered.locations["place.tree_shade"].activities = ["observe"]
	check(Choice.choose(altered,90,"strong").is_empty(),"No rest candidates returns an explicit fallback")

	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.store = Store.new("/tmp/cozy-rest-test-"+str(OS.get_process_id()))
	scene.saving_enabled = true
	scene.state_template = {"world_id":"rest-test","simulation_seconds":0,"save_sequence":0,"world_state":{"environment":{"version":1,"sunlight":"gentle","future_hint":"keep"},"furniture":{"keep":true}},"memories":[{"text":"kept"}]}
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	scene._toggle_sunlight()
	check(scene.sunlight=="strong" and scene.sun.light_energy>0.6,"Sunlight control changes visible lighting as well as the condition")
	check(scene.rest_reason.text.contains("下次"),"Environment change explains when the next choice takes effect")
	# Begin at home with the ordinary initial countdown.
	for i in range(41):
		scene._advance_simulation(0.05)
	check(scene.resident.mode=="move" and scene.resident.destination_id=="place.tree_shade","Actual resident begins the chosen safe route")
	check(scene.rest_reason.text.contains("树荫"),"Chosen reason appears in the interface")
	var walking: Dictionary = scene.resident.snapshot()
	check(scene._save_now(),"Chosen route can be saved")
	var loaded: Dictionary = scene.store.load_state()
	check(loaded.state.world_state.environment.sunlight=="strong" and loaded.state.world_state.environment.future_hint=="keep","Environment state and unrelated hints round-trip")
	check(scene.resident.restore(walking) and scene.resident.snapshot()==walking,"Mid-route restore preserves destination, path, progress and reason")
	wait_for_rest(scene)
	check(scene.resident.mode=="rest" and scene.resident.current_location=="place.tree_shade","Resident arrives and rests in shade")
	check(is_equal_approx(scene.resident.left_leg.rotation.x,0),"Resting on ground never applies a floating chair pose")
	var resting: Dictionary = scene.resident.snapshot()
	check(scene.resident.restore(resting) and scene.resident.snapshot()==resting,"Tree rest pose and countdown survive restart")
	var previous: Dictionary = scene.resident.snapshot()
	scene._toggle_sunlight()
	check(scene.resident.snapshot()==previous,"Changing sunlight does not teleport or interrupt the current rest")
	check(scene.sunlight=="gentle" and is_equal_approx(scene.sun.light_energy,0.6),"Gentle light restores its lighting")
	# Next choice should respond to the new environment, while normal food/home visits remain.
	for i in range(6000):
		scene._advance_simulation(0.05)
		if scene.resident.mode=="move" and scene.resident.destination_id=="object.bench.001":
			break
	check(scene.resident.destination_id=="object.bench.001","Following rest selection responds to changed sunlight")
	wait_for_rest(scene)
	check(scene.resident.current_location=="object.bench.001" and is_equal_approx(scene.resident.left_leg.rotation.x,-PI/2),"Bench choice retains seated pose")
	check(scene._save_now(),"Changed environment and rest remain persistable")
	loaded = scene.store.load_state()
	check(loaded.state.memories==scene.state_template.memories and loaded.state.world_state.furniture.keep,"Choices preserve world identity and memory fields")
	var invalid: Dictionary = loaded.state.duplicate(true)
	invalid.world_state.environment.sunlight = "unknown"
	check(not Store.valid_state(invalid),"Invalid environment state is rejected")
	invalid = loaded.state.duplicate(true)
	invalid.resident.rest_choice_reason = 7
	check(not Store.valid_state(invalid),"Malformed saved choice explanation is rejected")
	var legacy: Dictionary = scene.resident.snapshot()
	legacy.erase("rest_choice_reason")
	check(scene.resident.restore(legacy),"Older snapshots without explanations are accepted")
	# Three running world days in strong sunlight: still visit home, eat, rest, and stay on safe paths.
	scene.car.random.seed = 120
	scene._set_sunlight("strong")
	var safe := true
	var fed := true
	var saw_shade := false
	for i in range(108000):
		scene._advance_simulation(0.2)
		var p: Vector3 = scene.resident.position
		safe = safe and absf(p.x)<=11 and absf(p.z)<=9 and not (p.x>-5.15 and p.x<0.15 and p.z<1.4 and p.z>-4)
		fed = fed and scene.needs.satiety>0
		saw_shade = saw_shade or (scene.resident.current_location=="place.tree_shade" and scene.resident.mode=="rest")
	check(safe,"Dynamic routes never leave the plot or cross the house footprint")
	check(fed and scene.needs.meals_finished>8,"Rest choices do not starve meal/home visits")
	check(saw_shade and scene.needs.energy>0,"Strong-light routine includes shade rest and keeps energy available")
	check(scene.needs.hearts==40 and scene.needs.last_supply_day==4,"Comfort choices never charge resources or duplicate daily provisions")
	scene.saving_enabled = false
	print("REST_CHOICE_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
