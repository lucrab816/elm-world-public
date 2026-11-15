extends SceneTree
const Life = preload("res://basic_life.gd")
const Store = preload("res://save_store.gd")
var checks := 0
var failures := 0
var base := "/tmp/cozy-life-test-"+str(OS.get_process_id())
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var life = Life.new()
	check(life.ensure_supply(0) and life.hearts==10 and life.food==4,"First creation gets food and hearts")
	check(not life.ensure_supply(7199.9) and life.hearts==10,"No repeated supply within world day")
	var restored = Life.new()
	check(restored.restore(life.snapshot()),"Life state round-trips")
	check(not restored.ensure_supply(7199.9) and restored.hearts==10,"Restart does not duplicate supply")
	check(restored.ensure_supply(7200) and restored.hearts==20 and restored.food==8,"Next running world day grants once")
	check(not restored.ensure_supply(7200),"Same boundary is idempotent")
	var migrated = Life.new()
	migrated.ensure_supply(17000)
	check(migrated.hearts==10 and migrated.last_supply_day==3,"Old world receives current supply only, no invented past grants")
	life.food = 0
	life.satiety = 0
	check(life.begin_meal() and life.meal_is_basic and life.food==0,"Empty pantry has free basic meal")
	check(not life.begin_meal(),"Active meal never reserves twice")
	life.finish_meal()
	life.finish_meal()
	check(life.meals_finished==1 and life.satiety==65,"Meal completion applied exactly once")
	life.energy = 20
	life.advance(30,true)
	check(life.energy>20,"Rest restores energy")
	var bad := life.snapshot()
	bad.food = -1
	check(not Life.valid_snapshot(bad),"Invalid resource balance rejected")
	bad = life.snapshot()
	bad.satiety = NAN
	check(not Life.valid_snapshot(bad),"Non-finite need rejected")

	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.store = Store.new(base)
	scene.saving_enabled = true
	scene.state_template = {"world_id":"life-test","simulation_seconds":0,"save_sequence":0,"world_state":{"furniture":{"kept":true}},"memories":[{"text":"keep"}]}
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	scene.needs.satiety = 54
	for i in range(4000):
		scene._advance_simulation(0.05)
		if scene.resident.mode=="eat":
			break
	check(scene.resident.mode=="eat" and scene.resident.meal_bowl.visible,"Hungry resident returns home and visibly eats")
	check(scene.needs.food==3 and scene.needs.meal_active,"Food reserved only at meal start")
	scene._advance_simulation(7)
	check(scene._save_now(),"Mid-meal saves atomically")
	var loaded: Dictionary = scene.store.load_state()
	var meal: Dictionary = loaded.state.resident
	var food_before: int = loaded.state.world_state.basic_life.food
	var time_left: float = meal.remaining
	check(time_left<30 and time_left>0,"Meal has partial progress")
	scene.resident.restore(meal)
	scene.needs.restore(loaded.state.world_state.basic_life)
	check(scene.needs.food==food_before and scene.resident.mode=="eat","Restart keeps reserved food and meal progress")
	scene._advance_simulation(time_left+0.1)
	check(scene.needs.meals_finished==1 and not scene.needs.meal_active and scene.needs.food==food_before,"Resume completes meal once, no second deduction")
	check(scene.needs.satiety>90 and not scene.resident.meal_bowl.visible,"Eating restores satiety and clears prop")
	check(scene._save_now(),"Completed meal saves")
	loaded = scene.store.load_state()
	check(loaded.state.memories==scene.state_template.memories and loaded.state.world_state.furniture.kept,"Life updates preserve unrelated world data and memories")
	var invalid: Dictionary = loaded.state.duplicate(true)
	invalid.world_state.basic_life.meal_active = true
	check(not Store.valid_state(invalid),"Inconsistent actor and meal state rejected")

	invalid = loaded.state.duplicate(true)
	invalid.resident = "broken"
	check(not Store.valid_state(invalid),"Malformed resident rejected before cross-field checks")

	# Layout replacement during an unfinished meal keeps the meal at a safe home point.
	scene.resident.catalog = scene.resident.catalog.duplicate(true)
	scene.resident.catalog.locations["place.home_front"].position = [-2.4,1.8]
	scene.needs.restore(loaded.state.world_state.basic_life)
	scene.needs.meal_active = true
	check(scene.resident.restore(meal) and scene.resident.mode=="eat" and is_equal_approx(scene.resident.remaining,time_left),"Changed layout preserves unfinished meal without duplicate consumption")
	scene.needs.finish_meal()
	scene.resident.mode = "observe"
	scene.resident.remaining = 1
	# More than three world days, no input or model; cross supply boundaries and save repeatedly.
	var initial_hearts: int = scene.needs.hearts
	var min_satiety := 100.0
	for i in range(21600):
		scene._advance_simulation(1.0)
		min_satiety = minf(min_satiety,scene.needs.satiety)
	check(scene.needs.last_supply_day==4 and scene.needs.hearts==initial_hearts+30,"Three full running days grant exactly three new supplies")
	check(scene.needs.food>=0 and scene.needs.food<=Life.PANTRY_LIMIT and min_satiety>0,"No user input needed to keep fed; pantry stays bounded")
	check(scene.needs.energy>0 and scene.needs.meals_finished>8,"Resident continues resting and eating over several days")
	check(scene._save_now() and scene.store.load_state().status=="ok","Long-running life remains saveable")
	# Genuine v1 envelope is accepted for upgrade; newer versions remain protected.
	var legacy: Dictionary = loaded.state.duplicate(true)
	legacy.world_state.erase("basic_life")
	legacy.resident.mode = "observe"
	var payload := JSON.stringify(legacy)
	var legacy_store = Store.new(base+"-legacy")
	DirAccess.make_dir_recursive_absolute(legacy_store.directory)
	var file := FileAccess.open(legacy_store.directory.path_join("world.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version":1,"payload_json":payload,"sha256":payload.sha256_text()}))
	file.close()
	check(legacy_store.load_state().status=="ok","Version 1 worlds remain readable")
	scene.saving_enabled = false
	print("BASIC_LIFE_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
