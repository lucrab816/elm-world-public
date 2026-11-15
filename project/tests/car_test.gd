extends SceneTree
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
func fixture():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.store = Store.new("/tmp/cozy-car-"+str(OS.get_process_id()))
	scene.saving_enabled = true
	scene.journal_enabled = true
	scene.state_template = {"world_id":"car-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"text":"keep existing"}]}
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	return scene
func _run() -> void:
	root.size = Vector2i(1200,800)
	var scene = fixture()
	var actor = scene.resident
	scene.car.random.seed = 12
	check(scene.car.get_meta("object_id")=="object.car.001","Stable car identity")
	for i in range(2600):
		scene._advance_simulation(.05)
		if actor.mode=="drive":
			break
	check(actor.mode=="drive" and actor.current_location=="object.car.001","Ordinary local day includes driving without invitation")
	check(actor.driving_legs.visible and not actor.left_leg.visible,"Actual Elm model has a seated driving pose")
	var start: Vector3 = actor.position
	scene._advance_simulation(9)
	check(actor.position.distance_to(start)>1 and actor.position.distance_to(scene.car.position)<.001,"Elm travels continuously with the actual car")
	check(absf(actor.rotation.y-scene.car.rotation.y)<.001,"Driver faces travel direction")
	var progress: float = actor.remaining
	check(scene._save_now(),"Mid-drive world can be saved")
	var loaded = scene.store.load_state()
	check(loaded.status=="ok" and loaded.state.resident.mode=="drive" and loaded.state.memories==[{"text":"keep existing"}],"Disk snapshot keeps driving and prior memories")
	var saved_position: Vector3 = actor.position
	check(actor.restore(loaded.state.resident) and absf(actor.remaining-progress)<.001 and actor.position.distance_to(saved_position)<.001,"Mid-drive restore reconstructs car and driver at same position")
	var journal_count: int = scene.journal.records.size()
	actor.restore(loaded.state.resident)
	check(scene.journal.records.size()==journal_count,"Restoring driving does not invent another ride event")
	for i in range(20000):
		scene._advance_simulation(.05)
		check_bounds(scene)
		if actor.mode!="drive":
			break
	check(actor.mode=="move" and actor.left_leg.visible and not actor.driving_legs.visible,"Completes one lap, gets out, and resumes normal walking")
	var park_distance := Vector2(scene.car.position.x,scene.car.position.z).distance_to(Vector2(2,4.8))
	check(park_distance<.01 if scene.car.forest_trip else park_distance>1,"Forest trips return to their starting space and yard trips find a new parking space")
	var kinds := []
	for event in scene.journal.records:
		kinds.append(event.kind)
	check(kinds.has("drive") and kinds.has("drive_done"),"Actual ride start and finish become separate life memories")
	actor.mode = "observe"
	actor.remaining = 0
	actor.visit_index = 1
	scene.needs.satiety = 50
	actor.ride_requested = true
	actor._start_next_visit()
	check(actor.destination_id=="place.home_front" and actor.ride_requested,"Hunger postpones car invitation and sends Elm home")
	scene.needs.satiety = 90
	scene.needs.energy = 20
	actor.visit_index = 1
	actor._start_next_visit()
	check(actor.destination_id!="object.car.001","Tired resident rests instead of driving")
	scene.needs.energy = 90
	actor._start_next_visit()
	check(actor.destination_id=="object.car.001" and actor.ride_requested,"Invitation remains pending on the way to the car")
	# A temporary obstruction at the parking point prevents departure; the invitation
	# must survive both that failure and a save until a later trip really starts.
	scene.navigation.pet_obstacle = scene.car.parked
	actor._finish_walk()
	check(actor.mode=="observe" and actor.ride_requested,"Blocked departure keeps the invitation pending")
	check(scene._save_now() and scene.store.load_state().state.resident.ride_requested,"Pending invitation survives saving")
	scene.navigation.pet_obstacle = Vector2.INF
	actor._start_next_visit()
	actor._finish_walk()
	check(actor.mode=="drive" and not actor.ride_requested,"Invitation completes only after departure succeeds")
	var bad = actor.snapshot()
	bad.mode = "drive"
	bad.current_location = "place.home_front"
	check(not actor.valid_snapshot(bad),"Invalid driving location rejected")
	bad.current_location = "object.car.001"
	bad.remaining = 100
	check(not actor.valid_snapshot(bad),"Out-of-range driving phase rejected")
	var reached := {"west":false,"east":false,"north":false,"south":false}
	scene.car.random.seed = 42
	for trip_index in range(16):
		check(scene.car.start_trip(),"Reachable random trip planned")
		for p in scene.car.trip:
			if p.x<-4: reached.west = true
			if p.x>6: reached.east = true
			if p.y<-4: reached.north = true
			if p.y>5: reached.south = true
			check_bounds_at(scene,p)
		scene.car.advance_trip(10000)
	check(reached.west and reached.east and reached.north and reached.south,"Trips cover all sides of the yard")
	check(scene.car.start_trip(),"Car can depart its new parking point")
	var before: float = scene.car.travelled
	scene.car.advance_trip(1)
	check(absf(scene.car.travelled-before-.65)<.00001,"Ground speed is twice the old average speed")
	var saved_car: Dictionary = scene.car.snapshot()
	var saved_rng: int = scene.car.random.state
	scene.car.advance_trip(10000)
	check(scene.car.restore(saved_car) and scene.car.random.state==saved_rng,"Park, route and random state survive exact restore")
	var original_path: Array = saved_car.trip.duplicate(true)
	check(scene.car.snapshot().trip==original_path,"Restore never rerolls the route")
	var old = actor.snapshot()
	old.erase("car_state")
	old.mode = "drive"
	old.remaining = 20
	old.current_location = "object.car.001"
	check(actor.restore(old) and actor.mode=="observe","Old fixed-loop driving migrates safely without losing history")
	check(not scene._car_hit(Vector2(-100,-100)),"Far clicks do not invite driving")
	# Render the same production driver, not a separate illustration or dummy.
	actor.mode = "drive"
	actor.current_location = "object.car.001"
	actor.visit_index = 2
	actor.remaining = (scene.car.trip_distance-scene.car.travelled)/.65
	actor._pose_drive()
	scene.focus = scene.car.position+Vector3.UP*.65
	scene.zoom = 4.7
	scene.azimuth = 1.55
	scene.elevation = .55
	scene._update_camera()
	for child in scene.get_children():
		if child is CanvasLayer:
			child.hide()
	if DisplayServer.get_name()!="headless":
		await create_timer(.6).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/elm-driving.png"))
	scene.saving_enabled = false
	print("CAR_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
func check_bounds(scene) -> void:
	check_bounds_at(scene,Vector2(scene.car.position.x,scene.car.position.z))
func check_bounds_at(scene, p: Vector2) -> void:
	if scene.car.forest_trip and p.x< -7.5:
		var trail = preload("res://forest_land.gd").DRIVE_TRAIL
		for i in range(1,trail.size()):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,trail[i-1],trail[i]))<.05: return
	if not scene.navigation.clear_point(p,.98):
		failures += 1
		push_error("Car intersects a yard obstacle at "+str(p))
