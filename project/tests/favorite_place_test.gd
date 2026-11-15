extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Rabbit = preload("res://rabbit.gd")
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
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	scene.rabbit.random.seed = 25
	scene.car.random.seed = 42
	scene.rabbit.adopt(0)
	scene.rabbit_enabled = true
	scene.store = Store.new("/tmp/cozy-favorite-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"favorite-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"reserved":"keep"}]}
	return scene
func semantics(value): return JSON.parse_string(JSON.stringify(value))
func run() -> void:
	var world = fixture()
	var rabbit = world.rabbit
	var favorite: String = rabbit.favorite_id
	var goal: Vector2 = Rabbit.FAVORITES[favorite].point
	check(Rabbit.FAVORITES.has(favorite) and world.navigation.clear_point(goal,.22),"A chosen authored corner is safe for the rabbit")
	check(rabbit.favorite_visits==0 and rabbit.favorite_last_seconds==null,"Choosing a preference does not invent a visit")
	check(rabbit.favorite_description().contains("没有记录"),"Chat honestly distinguishes preference from an actual visit")
	check(Chat.simulated_reply("德雷克喜欢在哪里休息",world._chat_context()).contains(Rabbit.FAVORITES[favorite].name),"Local chat reports the selected preference")
	var original_id: String = rabbit.ID
	var old: Dictionary = rabbit.snapshot()
	old.erase("favorite")
	check(rabbit.restore(old,0) and rabbit.ID==original_id and rabbit.events.size()==1 and rabbit.favorite_visits==0,"Legacy snapshot migrates without respawning or fabricating history")
	favorite = rabbit.favorite_id
	goal = Rabbit.FAVORITES[favorite].point
	world.resident.mode = "observe"
	world.resident.remaining = 250
	world.pet_companion.cooldown = 120
	check(rabbit._favorite_available() and rabbit._start_path(goal,"favorite_walk",0),"Rabbit can plan a real route to its chosen corner")
	check(rabbit.favorite_visits==0 and rabbit.events.back().kind=="favorite_started","Starting a route is not an arrival")
	world._advance_simulation(.5)
	check(rabbit.mode=="favorite_walk" and world._save_now(),"Travel can be saved while approaching")
	var moving: Dictionary = world.store.load_state().state
	check(moving.world_state.rabbit.favorite.id==favorite and moving.world_state.rabbit.favorite.visits==0,"The saved selection survives mid-route")
	var fresh = fixture()
	fresh.simulation_seconds = moving.simulation_seconds
	check(fresh.resident.restore(moving.resident) and fresh.rabbit.restore(moving.world_state.rabbit,fresh.simulation_seconds),"Fresh scene restores route and preference")
	check(semantics(fresh.rabbit.snapshot())==semantics(moving.world_state.rabbit),"Restore does not reroll preference or write a visit")
	fresh.needs.restore(moving.world_state.basic_life)
	fresh.pet_companion.restore(moving.world_state.pet_companion)
	fresh.pet_companion.cooldown = 120
	for i in range(1000):
		fresh._advance_simulation(.05)
		if fresh.rabbit.at_favorite: break
	check(fresh.rabbit.at_favorite and fresh.rabbit.flat().distance_to(goal)<.4,"The actual rabbit arrives at the selected place")
	check(fresh.rabbit.favorite_visits==1 and fresh.rabbit.favorite_last_seconds!=null and fresh.rabbit.events.back().kind=="favorite_arrived","Only actual arrival records a visit")
	check(fresh.rabbit.remaining>=12 and fresh.rabbit.remaining<=20 and fresh.rabbit.description().contains(Rabbit.FAVORITES[favorite].name),"The rabbit lingers and its visible status names the corner")
	check(fresh.rabbit.favorite_description().contains("1次") and not fresh.rabbit.favorite_description().contains("没有记录"),"Recall uses the true visit count and last time")
	check(fresh._save_now(),"Favorite rest and evidence save successfully")
	var rested: Dictionary = fresh.store.load_state().state
	var restored = fixture()
	restored.simulation_seconds = rested.simulation_seconds
	restored.resident.restore(rested.resident)
	check(restored.rabbit.restore(rested.world_state.rabbit,restored.simulation_seconds),"Resting state restores in a new scene")
	check(restored.rabbit.at_favorite and restored.rabbit.favorite_visits==1 and restored.rabbit.favorite_id==favorite,"Restore keeps place and count without counting again")
	var bad: Dictionary = rested.world_state.rabbit.duplicate(true)
	bad.favorite.id = "unknown"
	check(not Rabbit.valid_snapshot(bad,rested.simulation_seconds),"Unknown place is rejected")
	bad = rested.world_state.rabbit.duplicate(true)
	bad.favorite.last_seconds = rested.simulation_seconds+10
	check(not Rabbit.valid_snapshot(bad,rested.simulation_seconds),"A future visit cannot enter a save")
	bad = rested.world_state.rabbit.duplicate(true)
	bad.favorite.visits = 0
	check(not Rabbit.valid_snapshot(bad,rested.simulation_seconds),"A visit time without a visit is invalid")
	bad = rested.world_state.rabbit.duplicate(true)
	bad.position = [6,6]
	check(not Rabbit.valid_snapshot(bad,rested.simulation_seconds),"Resting at a distant place is rejected")
	var visits: int = fresh.rabbit.favorite_visits
	fresh.rabbit.mode = "favorite_walk"
	fresh.rabbit.route.assign([goal])
	fresh.rabbit.at_favorite = false
	fresh.resident.mode = "drive"
	fresh.rabbit.advance(.05,fresh.simulation_seconds)
	check(fresh.rabbit.mode=="watch_car" and fresh.rabbit.favorite_visits==visits,"Driving interrupts a route without inventing an arrival")
	# An obstacle at the preferred spot must make it unavailable, not force placement.
	fresh.resident.mode = "observe"
	fresh.navigation.decorations.append(goal)
	check(not fresh.rabbit._favorite_available(),"A newly blocked corner is not selected")
	fresh.navigation.decorations.clear()
	check(rested.memories==[{"reserved":"keep"}],"Preference migration and activity preserve resident memories")
	# Run an autonomous local day, without an invitation or staging the true world.
	var natural = fixture()
	var visited := false
	var safe := true
	var eats := false
	for i in range(36000):
		natural._advance_simulation(.2)
		visited = visited or natural.rabbit.favorite_visits>0
		safe = safe and natural.navigation.clear_point(natural.rabbit.flat(),.22)
		eats = eats or natural.needs.meals_finished>0
	check(visited and safe and eats,"Natural full-day life includes an actual safe visit and ordinary meals")
	check(natural._save_now() and natural.store.load_state().status=="ok","Natural preference state remains valid")
	for scene in [world,fresh,restored,natural]: scene.saving_enabled = false
	print("FAVORITE_PLACE_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
