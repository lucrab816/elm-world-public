extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Care = preload("res://garden_care.gd")
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
	scene.neighbor.random.seed = 13
	scene.neighbor.adopt(0)
	scene.neighbor_enabled = true
	scene.store = Store.new("/tmp/cozy-garden-care-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"garden-care-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{"asset":{"keep":true}},"memories":[{"reserved":"keep"}]}
	return scene
func ready_mia(scene) -> void:
	scene.neighbor._place(Care.EDGE)
	scene.neighbor.place_id = "garden"
	scene.neighbor.mode = "rest"
	scene.neighbor.remaining = 12
	scene.neighbor.route.clear()
	scene.neighbor.destination = ""
	scene.neighbor._sync_obstacle()
	scene.garden_care.cooldown = 0
	scene.neighbor_greeting.cooldown = 120
func count_event(scene, kind: String) -> int:
	return scene.neighbor.events.filter(func(e): return e.kind==kind).size()
func run() -> void:
	var scene = fixture()
	ready_mia(scene)
	check(scene.garden_soil!=null and not scene.garden_wet,"Existing bed begins dry")
	check(not Care._at_bed(Vector2(-6.5,2)) and not Care._at_bed(Vector2(-6,2.3)),"Watering requires alignment with the actual bed")
	check(Chat.simulated_reply("米娅浇过水吗",scene._chat_context()).contains("没有保留"),"No watering is invented before action")
	scene._advance_simulation(.1)
	check(scene.garden_care.active() and scene.neighbor.mode=="watering","Mia starts actual watering near the bed")
	check(scene.neighbor.watering_can.visible and scene.neighbor.droplets.visible,"The real scene shows a watering can and water")
	check(count_event(scene,"water_started")==1 and scene.garden_care.water_count==0 and not scene.garden_wet,"Starting does not wet or mark completion")
	check(Chat.simulated_reply("米娅浇过水吗",scene._chat_context()).contains("还没有完成"),"An in-progress watering is not reported as finished")
	check(scene._save_now(),"In-progress watering and world save together")
	var saved: Dictionary = scene.store.load_state().state
	check(Store.valid_state(saved) and saved.memories==[{"reserved":"keep"}] and saved.world_state.asset.keep,"World validation preserves existing memory and assets")
	var fresh = fixture()
	fresh.simulation_seconds = saved.simulation_seconds
	fresh.needs.restore(saved.world_state.basic_life)
	fresh.resident.restore(saved.resident)
	fresh.rabbit.restore(saved.world_state.rabbit,fresh.simulation_seconds)
	fresh.pet_companion.restore(saved.world_state.pet_companion)
	fresh.neighbor.restore(saved.world_state.neighbor,fresh.simulation_seconds)
	fresh.neighbor_greeting.restore(saved.world_state.neighbor_greeting)
	fresh.garden_care.restore(saved.world_state.garden_care)
	fresh.journal.restore(saved.world_state.life_journal,fresh.simulation_seconds)
	check(fresh.garden_care.active() and count_event(fresh,"water_started")==1 and absf(fresh.garden_care.remaining-scene.garden_care.remaining)<.00001,"Fresh scene resumes the same watering without repeating its start")
	var before_wait: float = fresh.neighbor.remaining
	for i in range(250):
		fresh._advance_simulation(.05)
		if not fresh.garden_care.active(): break
	check(fresh.garden_care.latest.phase=="completed" and count_event(fresh,"water_done")==1 and fresh.garden_care.water_count==1,"One completed action creates one event and count")
	check(fresh.garden_wet and fresh.garden_soil.material_override==fresh._mat("5e4f3f"),"Completed watering makes the actual bed darker")
	check(fresh.neighbor.remaining==before_wait and not fresh.neighbor.watering_can.visible,"Mia returns to her previous pause and puts away the can")
	check(Chat.simulated_reply("米娅浇过水吗",fresh._chat_context()).contains("1次完成"),"Local recall cites a completed watering")
	check(fresh._save_now(),"Completed watering and wet state save together")
	var watered: Dictionary = fresh.store.load_state().state
	var restored = fixture()
	restored.simulation_seconds = watered.simulation_seconds
	restored.neighbor.restore(watered.world_state.neighbor,restored.simulation_seconds)
	restored.garden_care.restore(watered.world_state.garden_care)
	restored._update_garden_water(restored.simulation_seconds)
	check(restored.garden_wet and restored.garden_care.water_count==1,"Wet appearance and count survive a fresh restore")
	restored._update_garden_water(restored.garden_care.wet_until+.01)
	check(not restored.garden_wet and restored.garden_soil.material_override==restored._mat("8d7758") and restored.garden_care.water_count==1,"Drying changes appearance without erasing the real event")
	fresh._advance_simulation(2)
	check(count_event(fresh,"water_done")==1 and fresh.garden_care.cooldown>0,"Cooldown prevents immediate duplicate watering")
	# Interrupt a true in-progress watering with car activity.
	scene.resident.mode = "drive"
	scene.garden_care.advance(scene,.05,scene.simulation_seconds)
	scene.resident.mode = "observe"
	check(scene.garden_care.latest.phase=="cancelled" and count_event(scene,"water_cancelled")==1 and scene.garden_care.water_count==0 and not scene.garden_wet,"Driving interrupts without a false watering or wet soil")
	check(Chat.simulated_reply("米娅浇过水吗",scene._chat_context()).contains("没有算作完成"),"Cancelled work is not narrated as success")
	var bad: Dictionary = saved.duplicate(true)
	bad.world_state.garden_care.remaining = 80
	check(not Store.valid_state(bad),"Impossible work timer rejected")
	bad = saved.duplicate(true)
	bad.world_state.neighbor.position = [6,6]
	check(not Store.valid_state(bad),"Remote watering is rejected")
	bad = saved.duplicate(true)
	bad.world_state.neighbor.events = bad.world_state.neighbor.events.filter(func(e): return e.kind!="water_started")
	check(not Store.valid_state(bad),"A start event is required for active watering")
	bad = saved.duplicate(true)
	bad.world_state.erase("garden_care")
	check(not Store.valid_state(bad),"Orphaned watering mode is rejected")
	bad = watered.duplicate(true)
	bad.world_state.garden_care.water_count = 0
	check(not Store.valid_state(bad),"Wet soil cannot be paired with zero completed visits")
	bad = watered.duplicate(true)
	bad.world_state.garden_care.last_completed_seconds = watered.simulation_seconds+1
	check(not Store.valid_state(bad),"Future completed watering is rejected")
	var legacy: Dictionary = watered.duplicate(true)
	legacy.world_state.erase("garden_care")
	legacy.world_state.erase("garden_growth")
	legacy.world_state.erase("mia_rabbit")
	check(Store.valid_state(legacy),"Old idle world without garden care remains valid")
	# Natural local day. No staging or acceleration of the actual world.
	var natural = fixture()
	var watered_naturally := false
	var greeted := false
	var ate := false
	var safe := true
	for i in range(36000):
		natural._advance_simulation(.2)
		watered_naturally = watered_naturally or natural.garden_care.water_count>0
		greeted = greeted or natural.neighbor_greeting.latest.get("phase")=="completed"
		ate = ate or natural.needs.meals_finished>0
		if natural.resident.mode=="drive": safe = safe and natural.neighbor.flat().distance_to(Vector2(natural.car.position.x,natural.car.position.z))>=1.7
	check(watered_naturally and greeted and ate and safe,"An ordinary day includes actual watering, greeting, meals and safe driving")
	check(natural._save_now() and natural.store.load_state().status=="ok","Natural activity remains valid after a full day")
	if DisplayServer.get_name()!="headless":
		var preview = fixture()
		ready_mia(preview)
		preview._advance_simulation(2)
		for world in [scene,fresh,restored,natural]:
			world.hide()
			for child in world.get_children():
				if child is CanvasLayer: child.hide()
		for child in preview.get_children():
			if child is CanvasLayer: child.hide()
		preview.resident.hide()
		preview.rabbit.hide()
		preview.car.hide()
		preview.camera.make_current()
		preview.follow_neighbor = true
		preview.focus = preview.neighbor.position+Vector3(0,.55,-.55)
		preview.zoom = 4.2
		preview.azimuth = -1.1
		preview.elevation = .6
		preview._update_camera()
		print("PREVIEW_WATER phase=",preview.garden_care.phase," can=",preview.neighbor.watering_can.visible," drops=",preview.neighbor.droplets.visible)
		await create_timer(.3).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/mia-watering-preview.png"))
		preview.saving_enabled = false
	for world in [scene,fresh,restored,natural]: world.saving_enabled = false
	print("GARDEN_CARE_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
