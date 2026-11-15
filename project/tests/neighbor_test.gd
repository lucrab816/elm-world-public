extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Neighbor = preload("res://neighbor.gd")
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
	scene.rabbit.adopt(0)
	scene.rabbit_enabled = true
	scene.car.random.seed = 42
	scene.neighbor.random.seed = 13
	scene.store = Store.new("/tmp/cozy-neighbor-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"neighbor-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{"custom":{"keep":true}},"memories":[{"reserved":"keep"}]}
	return scene
func semantic(value): return JSON.parse_string(JSON.stringify(value))
func run() -> void:
	var scene = fixture()
	var mia = scene.neighbor
	check(mia.adopt(0),"Mia can find a safe place to enter")
	scene.neighbor_enabled = true
	check(mia.get_meta("neighbor_id")==Neighbor.ID and mia.visible and mia.events.size()==1,"Mia has one stable identity and one arrival")
	check(scene.navigation.clear_point(mia.flat(),.28) and mia._car_clear(mia.flat()),"Mia starts outside obstacles and clear of parked car")
	check(mia.description().contains("菜地") or mia.description().contains("小院"),"Status reflects her actual start position")
	check(mia._start_next(0),"Mia plans a route using the actual yard")
	var start: Vector2 = mia.flat()
	scene._advance_simulation(2)
	check(mia.mode=="walk" and mia.flat().distance_to(start)>.5,"Mia actually moves, independently of Elm")
	scene._look_at_neighbor()
	scene._advance_simulation(.2)
	check(scene.follow_neighbor and scene.focus.distance_to(mia.position+Vector3.UP*.7)<.001,"Mia close-up follows her actual movement")
	scene._reset_camera()
	check(not scene.follow_neighbor and scene.tree_crowns.all(func(c): return c.visible),"Returning to yard restores the camera and crowns")
	check(scene._save_now() and scene.store.load_state().status=="ok","Moving neighbor state saves with the original world")
	var saved: Dictionary = scene.store.load_state().state
	check(saved.memories==[{"reserved":"keep"}] and saved.world_state.custom.keep,"Adding Mia preserves reserved memory and unrelated world fields")
	var fresh = fixture()
	fresh.simulation_seconds = saved.simulation_seconds
	check(fresh.resident.restore(saved.resident) and fresh.rabbit.restore(saved.world_state.rabbit,fresh.simulation_seconds),"Original actors restore before Mia")
	check(fresh.neighbor.restore(saved.world_state.neighbor,fresh.simulation_seconds),"Mia restores her position and current route")
	fresh.neighbor_enabled = true
	check(semantic(fresh.neighbor.snapshot())==semantic(saved.world_state.neighbor),"Route, events, random state and timer do not reroll")
	check(fresh.neighbor.events.filter(func(e): return e.kind=="arrived").size()==1,"Restoring does not create a second arrival")
	var bad: Dictionary = saved.world_state.neighbor.duplicate(true)
	bad.neighbor_id = "someone-else"
	check(not Neighbor.valid_snapshot(bad,saved.simulation_seconds),"Wrong neighbor identity rejected")
	bad = saved.world_state.neighbor.duplicate(true)
	bad.position = [100,100]
	check(not Neighbor.valid_snapshot(bad,saved.simulation_seconds),"Out-of-yard positions rejected")
	bad = saved.world_state.neighbor.duplicate(true)
	bad.born_seconds = saved.simulation_seconds+10
	check(not Neighbor.valid_snapshot(bad,saved.simulation_seconds),"Future arrival rejected")
	bad = saved.world_state.neighbor.duplicate(true)
	bad.events.append({"kind":"harvested_berries","seconds":0,"place":"garden"})
	check(not Neighbor.valid_snapshot(bad,saved.simulation_seconds),"Unimplemented harvest cannot be inserted as history")
	bad = saved.duplicate(true)
	bad.world_state.neighbor.mode = "walk"
	bad.world_state.neighbor.route = []
	check(not Store.valid_state(bad),"Orphaned walking state is rejected by save validation")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.world_state.erase("neighbor")
	legacy.world_state.erase("neighbor_greeting")
	legacy.world_state.erase("garden_care")
	legacy.world_state.erase("garden_growth")
	legacy.world_state.erase("mia_rabbit")
	check(Store.valid_state(legacy),"Older saves without Mia still validate")
	var entrance = fixture()
	var returning = entrance.neighbor
	returning.adopt(0)
	returning.mode = "crossing"
	returning.destination = "entrance"
	returning._place(Neighbor.GATE-Vector2(.0245,0))
	returning.advance(.05,.05)
	check(returning.mode=="rest" and returning.flat()==Neighbor.GATE,"Returning Mia lands exactly inside the walkable yard")
	check(Neighbor.valid_snapshot(semantic(returning.snapshot()),.05),"The arrival frame can be saved")
	returning.advance(1,1.05)
	returning.advance(.05,1.10)
	check(returning.mode=="walk" and returning.flat().distance_to(Neighbor.GATE)>.001 and entrance.navigation.clear_point(returning.flat(),.28),"Mia walks into the yard after returning")
	entrance.free()
	# The car plans around Mia, and Mia can walk outside the reserved driving route.
	var drives := false
	var minimum := INF
	var moving := false
	var rests := false
	var eats := false
	var safe := true
	var previous_position: Vector2 = fresh.neighbor.flat()
	var was_driving := false
	var moved_while_driving := false
	var bad_terrain := false
	var went_home := false
	var returned := false
	var away_restored := false
	for i in range(36000):
		fresh._advance_simulation(.2)
		var npc = fresh.neighbor
		went_home = went_home or (npc.mode=="away" and not npc.visible and not fresh.navigation.neighbor_obstacle.is_finite())
		if npc.mode=="away" and not away_restored:
			var saved_away: Dictionary = semantic(npc.snapshot())
			away_restored = npc.restore(saved_away,fresh.simulation_seconds) and not npc.visible and npc.home_until==saved_away.home_until
		returned = returned or (went_home and npc.visible and npc.events.any(func(e): return e.kind=="returned_to_yard"))
		if npc.mode not in ["away","crossing"]: bad_terrain = bad_terrain or not fresh.navigation.clear_point(npc.flat(),.28)
		safe = safe and not bad_terrain
		moving = moving or npc.mode=="walk"
		rests = rests or npc.mode=="rest"
		eats = eats or fresh.needs.meals_finished>0
		if fresh.resident.mode=="drive":
			drives = true
			if npc.visible: minimum = minf(minimum,npc.flat().distance_to(Vector2(fresh.car.position.x,fresh.car.position.z)))
			moved_while_driving = moved_while_driving or (npc.visible and was_driving and npc.mode=="walk" and npc.flat().distance_to(previous_position)>.001)
		previous_position = npc.flat()
		was_driving = fresh.resident.mode=="drive"
	print("NEIGHBOR_DIAG safe=",safe," driving=",drives," clearance=",minimum," movement=",moved_while_driving," terrain=",bad_terrain)
	check(safe and drives and moved_while_driving and minimum>=1.7,"Mia can keep moving during drives with safe clearance")
	check(away_restored,"An away snapshot keeps Mia hidden and preserves her return time")
	check(went_home and returned,"Mia leaves the yard, frees her obstacle, and returns on foot")
	check(moving and rests and eats,"Mia has walking and pauses while Elm retains ordinary meals")
	check(fresh.neighbor.events.size()<=Neighbor.LIMIT and fresh._save_now(),"A full day of bounded events remains saveable")
	check(fresh.store.load_state().status=="ok","Full-day save can be loaded")
	# New arrival during an old saved car trip avoids every segment, not just the car's current point.
	var old_world = fixture()
	for i in range(10000):
		old_world._advance_simulation(.05)
		if old_world.resident.mode=="drive": break
	check(old_world.resident.mode=="drive","Legacy migration fixture has a real active drive")
	var trip_before: Dictionary = old_world.car.snapshot()
	var adopted: bool = old_world.neighbor.adopt(old_world.simulation_seconds)
	check(not adopted or (old_world.neighbor.mode=="watch_car" and old_world.neighbor._car_clear(old_world.neighbor.flat())),"Mid-drive arrival is outside the entire old route or safely waits to appear")
	check(semantic(old_world.car.snapshot())==semantic(trip_before),"Adding a neighbor never rerolls the existing trip")
	var bench_world = fixture()
	bench_world.neighbor.adopt(0)
	bench_world.resident.mode = "rest"
	bench_world.resident.current_location = "object.bench.001"
	bench_world.resident.route.clear()
	bench_world.resident.position.x = 4.7
	bench_world.resident.position.z = 2.1
	bench_world.resident._pose_rest()
	check(bench_world.neighbor._start_next(0) and bench_world.neighbor.destination=="bench","Mia chooses to join Elm at his bench")
	for i in range(1000):
		bench_world.neighbor.advance(.05,(i+1)*.05)
		if bench_world.neighbor.mode=="rest": break
	check(bench_world.neighbor.place_id=="bench" and bench_world.neighbor.body.position.z<-.8 and bench_world.neighbor.left_leg.rotation.x< -1,"Mia walks over and visibly sits on the free end")
	var seated: Dictionary = semantic(bench_world.neighbor.snapshot())
	check(bench_world.neighbor.restore(seated,60) and bench_world.neighbor.body.position.z<-.8,"Seated visitor restores her real pose")
	bench_world.neighbor.remaining = 0
	bench_world.resident.mode = "observe"
	bench_world.neighbor.advance(.05,60)
	bench_world.neighbor.advance(.05,60.05)
	check(bench_world.neighbor.mode=="walk" and bench_world.neighbor.body.position.z==0,"Mia gets up and continues her visit")
	bench_world.free()
	if DisplayServer.get_name()!="headless":
		for world in [scene,fresh,old_world]:
			for child in world.get_children():
				if child is CanvasLayer: child.hide()
		fresh.hide()
		old_world.hide()
		scene.resident.hide()
		scene.rabbit.hide()
		scene.car.hide()
		mia.rotation.y = 0
		mia._pose(false)
		scene.follow_rabbit = true # Reuse the close-up foreground-crown rule in this isolated preview.
		scene.camera.make_current()
		scene.focus = mia.position+Vector3.UP*.7
		scene.zoom = 4.2
		scene.azimuth = .2
		scene.elevation = .48
		scene._update_camera()
		await create_timer(.3).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/mia-placeholder-preview.png"))
	for world in [scene,fresh,old_world]: world.saving_enabled = false
	print("NEIGHBOR_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
