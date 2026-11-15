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
	scene.car.random.seed = 42
	scene.rabbit.random.seed = 25
	scene.rabbit.adopt(0)
	scene.rabbit_enabled = true
	scene.store = Store.new("/tmp/cozy-rabbit-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"rabbit-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{"furniture":{"keep":true}},"memories":[{"reserved":"keep"}]}
	return scene
func semantic(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func mesh_height(node: Node3D) -> float:
	var low := INF
	var high := -INF
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var box: AABB = mesh.get_aabb()
		for x in [0,1]:
			for y in [0,1]:
				for z in [0,1]:
					var point: Vector3 = mesh.global_transform*(box.position+box.size*Vector3(x,y,z))
					low = minf(low,point.y)
					high = maxf(high,point.y)
	return high-low
func run() -> void:
	root.size = Vector2i(1200,800)
	var scene = fixture()
	var bunny = scene.rabbit
	check(bunny.display_name=="德雷克","Rabbit uses the user-given name")
	check(mesh_height(bunny)<mesh_height(scene.resident)*.48,"Rabbit's actual mesh is less than half Elm's standing height")
	var legacy_name: Dictionary = bunny.snapshot()
	legacy_name.erase("display_name")
	legacy_name.erase("hop_time")
	check(bunny.restore(legacy_name,0) and bunny.display_name=="德雷克" and bunny.events.size()==1,"Naming an old rabbit preserves identity and events")
	check(Chat.simulated_reply("德雷克在做什么",scene._chat_context()).contains("德雷克"),"Local chat recognizes the pet's actual name")
	check(bunny._start_path(Vector2(-1,4),"wander",0),"New gait has a real safe route")
	var still_frames := 0
	var moving_frames := 0
	var kick_seen := false
	var peak := 0.0
	for i in range(136):
		var previous: Vector2 = bunny.flat()
		scene._advance_simulation(.01)
		if bunny.flat().distance_to(previous)<.000001: still_frames += 1
		else: moving_frames += 1
		peak = maxf(peak,bunny.model.position.y)
		kick_seen = kick_seen or absf(bunny.hind_feet[0].rotation.x)>.25
	check(still_frames>30 and moving_frames>20,"Rabbit pauses on the ground instead of continuously sliding")
	check(peak>.075 and kick_seen,"Airborne hops include lift and a rear-paw kick")
	var gait_snapshot: Dictionary = bunny.snapshot()
	check(bunny.restore(gait_snapshot,scene.simulation_seconds) and bunny.hop_time==gait_snapshot.hop_time,"Mid-hop save/restore preserves the new gait phase")
	check(bunny.visible and bunny.get_meta("pet_id")==Rabbit.ID,"One stable rabbit is visible after adoption")
	check(bunny.events.filter(func(e): return e.kind=="arrived").size()==1 and bunny.events[0].kind=="arrived","Adoption records arrival without invented relationship")
	check(scene.navigation.clear_point(bunny.flat(),.22),"Rabbit starts outside house, beds and furniture")
	check(Chat.simulated_reply("兔子在哪",scene._chat_context()).contains("小兔子"),"Local chat reports actual pet state without model call")
	check(bunny._start_path(Vector2(-1.5,4),"wander",0),"Rabbit plans a small safe walk")
	scene._advance_simulation(1)
	check(bunny.mode=="wander" and bunny.flat().distance_to(Vector2(-4,3))>.5,"Rabbit actually moves, not just displays a model")
	var before: Dictionary = bunny.snapshot()
	check(scene._save_now(),"Moving pet can be saved")
	var loaded: Dictionary = scene.store.load_state()
	check(loaded.status=="ok" and loaded.state.world_state.rabbit.pet_id==Rabbit.ID,"Pet lives in saved world state")
	check(loaded.state.memories==[{"reserved":"keep"}] and loaded.state.world_state.furniture.keep,"Pet save preserves original memories and world fields")
	check(bunny.restore(loaded.state.world_state.rabbit,scene.simulation_seconds) and semantic(bunny.snapshot())==semantic(before),"Mid-walk restore preserves route, phase, random state and pet memories")
	var event_count: int = bunny.events.size()
	bunny.restore(loaded.state.world_state.rabbit,scene.simulation_seconds)
	check(bunny.events.size()==event_count,"Restore never repeats adoption or events")
	for i in range(1000):
		scene._advance_simulation(.05)
		if bunny.mode=="rest" and bunny.route.is_empty(): break
	check(bunny.remaining<=7,"Normal pauses are short enough to show activity")
	check(bunny.mode=="rest" and bunny.events.back().kind=="settled","Rabbit settles after finishing a trip")
	var id: String = bunny.snapshot().pet_id
	# Explicitly exercise the same production follow behaviour.
	var start: Vector2 = bunny.flat()
	check(bunny._start_path(Vector2(6.5,3.5),"follow",scene.simulation_seconds),"Follow intent can route around furniture")
	scene._advance_simulation(2)
	check(bunny.flat().distance_to(start)>1 and bunny.mode=="follow","Following uses actual movement")
	scene._look_at_rabbit()
	scene._advance_simulation(.2)
	check(scene.follow_rabbit and scene.focus.distance_to(bunny.position+Vector3.UP*.4)<.001,"Look-at-rabbit camera follows actual movement instead of an old point")
	scene._reset_camera()
	check(not scene.follow_rabbit,"Returning to yard ends camera following")
	check(scene.tree_crowns.all(func(crown): return crown.visible),"Ending pet close-up restores every tree crown")
	scene.follow_rabbit = true
	scene.focus = Vector3(4,.4,5.5)
	scene.azimuth = 0
	scene.elevation = .6
	scene._update_camera()
	check(scene.tree_crowns.any(func(crown): return not crown.visible),"Foreground crowns actually move out of the pet close-up")
	scene._reset_camera()
	# Ordinary rabbit movement continues outside the car route.
	for i in range(10000):
		scene._advance_simulation(.05)
		if scene.resident.mode=="drive": break
	check(scene.resident.mode=="drive","The resident starts a real drive")
	var frozen: Vector2 = bunny.flat()
	var car_safe := true
	var moved_during_drive := false
	for i in range(15000):
		if scene.resident.mode!="drive": break
		scene._advance_simulation(.05)
		if scene.resident.mode=="drive":
			car_safe = car_safe and bunny.flat().distance_to(Vector2(scene.car.position.x,scene.car.position.z))>=1.60
			moved_during_drive = moved_during_drive or bunny.flat().distance_to(frozen)>.01
	check(car_safe and moved_during_drive,"Rabbit keeps moving while staying clear of the car")
	check(bunny.snapshot().pet_id==id,"Companion identity never changes between activities")
	# One full running day with both actors enabled, including actual driving and rest.
	var safe := true
	var follows := false
	var wanders := false
	var saw_driving := false
	var minimum_clearance := INF
	for i in range(36000):
		scene._advance_simulation(.2)
		if bunny.mode not in Rabbit.HUTCH_MODES:
			safe = safe and scene.navigation.clear_point(bunny.flat(),.22)
		follows = follows or bunny.mode=="follow"
		wanders = wanders or bunny.mode=="wander"
		saw_driving = saw_driving or scene.resident.mode=="drive"
		if scene.resident.mode=="drive" and bunny.mode not in Rabbit.HUTCH_MODES:
			minimum_clearance = minf(minimum_clearance,bunny.flat().distance_to(Vector2(scene.car.position.x,scene.car.position.z)))
	check(safe and minimum_clearance>=1.60,"Whole-day rabbit movement stays on the plot and outside obstacles/cars")
	check(follows and wanders and saw_driving,"Ordinary life includes following, wandering and safe driving without user babysitting")
	check(bunny.events.size()<=16 and scene.needs.meals_finished>0,"Pet memory is bounded and Elm still eats normally")
	check(scene._save_now() and Rabbit.valid_snapshot(bunny.snapshot(),scene.simulation_seconds),"Whole-day state remains valid and durable")
	var bad: Dictionary = bunny.snapshot()
	bad.pet_id = "another-pet"
	check(not Rabbit.valid_snapshot(bad,scene.simulation_seconds),"Wrong pet identity rejected")
	bad = bunny.snapshot()
	bad.position = [999,0]
	check(not Rabbit.valid_snapshot(bad,scene.simulation_seconds),"Off-plot pet rejected")
	bad = bunny.snapshot()
	bad.born_seconds = scene.simulation_seconds+100
	check(not Rabbit.valid_snapshot(bad,scene.simulation_seconds),"Future adoption rejected")
	bad = bunny.snapshot()
	bad.events.append({"kind":"invented_story","seconds":scene.simulation_seconds})
	check(not Rabbit.valid_snapshot(bad,scene.simulation_seconds),"Unsupported pet story cannot enter save")
	# Preview uses actual production geometry, no synthetic user-world memories.
	if DisplayServer.get_name()!="headless":
		scene.resident.set_process(false)
		for child in scene.get_children():
			if child is CanvasLayer: child.hide()
		# Isolated scale comparison, not a staged event in the user's world.
		bunny._place(Vector2(-1.5,3.4))
		bunny.mode = "rest"
		bunny.route.clear()
		bunny._pose(false)
		scene.resident.position = bunny.position+Vector3(1.0,0,0)
		scene.resident._sync_height()
		scene.resident.rotation.y = 0
		scene.resident._pose_stand()
		scene.focus = bunny.position+Vector3(.5,.65,0)
		scene.zoom = 3.7
		# Isolated appearance preview: turn the actual production mesh toward camera.
		bunny.rotation.y = 0
		scene.azimuth = .35
		scene.elevation = .45
		scene._update_camera()
		await create_timer(.4).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/drake-scale-preview.png"))
	var saved_world: Dictionary = scene.store.load_state().state
	var fresh = load("res://main.tscn").instantiate()
	root.add_child(fresh)
	fresh.set_process(false)
	fresh.simulation_seconds = saved_world.simulation_seconds
	check(fresh.resident.restore(saved_world.resident) and fresh.rabbit.restore(saved_world.world_state.rabbit,fresh.simulation_seconds),"Fresh scene restores resident and pet together")
	check(semantic(fresh.rabbit.snapshot())==semantic(saved_world.world_state.rabbit),"Fresh scene does not respawn, re-record arrival or reroll rabbit behaviour")
	fresh.queue_free()
	var legacy = fixture()
	legacy.rabbit_enabled = false
	legacy.rabbit.hide()
	legacy.navigation.pet_obstacle = Vector2.INF
	for i in range(10000):
		legacy._advance_simulation(.05)
		if legacy.resident.mode=="drive": break
	var car_before: Dictionary = legacy.car.snapshot()
	legacy.rabbit.adopt(legacy.simulation_seconds)
	legacy.rabbit_enabled = true
	check(legacy.rabbit.mode=="watch_car" and legacy.rabbit._car_clear(legacy.rabbit.flat()),"Old world adoption during driving chooses a safe spot outside the entire saved trip")
	check(legacy.car.snapshot()==car_before,"Adoption does not reset or replan Elm's existing driving trip")
	legacy.saving_enabled = false
	scene.saving_enabled = false
	print("RABBIT_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
