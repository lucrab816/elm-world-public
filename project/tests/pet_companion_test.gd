extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Companion = preload("res://pet_companion.gd")
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
	scene.store = Store.new("/tmp/cozy-pet-play-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"pet-play-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{"furniture":{"keep":true}},"memories":[{"reserved":"keep"}]}
	return scene
func home(scene) -> void:
	scene.resident.position = scene.resident._point("place.home_front")
	scene.resident._sync_height()
	scene.resident.current_location = "place.home_front"
	scene.resident.mode = "observe"
	scene.resident.remaining = 12
	scene.resident.route.clear()
	scene.resident.ride_requested = false
	scene.resident._pose_stand()
	scene.rabbit._place(Vector2(-4,3))
	scene.rabbit.route.clear()
	scene.rabbit.mode = "rest"
	scene.rabbit.remaining = 4
func until_phase(scene, phase: String, limit: int = 600) -> void:
	for i in range(limit):
		scene._advance_simulation(.05)
		if scene.pet_companion.phase==phase: return
func count_pet(scene, kind: String) -> int:
	return scene.rabbit.events.filter(func(e): return e.kind==kind).size()
func run() -> void:
	root.size = Vector2i(1200,800)
	var scene = fixture()
	home(scene)
	check(scene.pet_companion.invite() and not scene.pet_companion.invite(),"Invitation is bounded and duplicate clicks are idempotent")
	check(scene._save_now() and scene.store.load_state().state.world_state.pet_companion.requested,"Pending invitation persists without fabricating a touch")
	check(count_pet(scene,"pet_started")==0 and scene.journal.entries(0,"pet").is_empty(),"Invitation alone does not create a pet memory")
	var old_actor: Vector3 = scene.resident.position
	scene._advance_simulation(.1)
	check(scene.pet_companion.phase=="approaching" and scene.resident.position==old_actor,"Elm waits while the rabbit really approaches")
	check(scene._save_now(),"Approach can be saved as a valid paired state")
	until_phase(scene,"petting")
	check(scene.pet_companion.phase=="petting" and scene.rabbit.mode=="petting","Petting starts only after real proximity")
	check(count_pet(scene,"pet_started")==1 and scene.journal.entries(0,"pet").size()==1,"Both actors record one actual start")
	scene._advance_simulation(1)
	var arm: float = scene.resident.right_arm.rotation.x
	var bunny_pos: Vector3 = scene.rabbit.position
	scene._advance_simulation(.25)
	check(absf(scene.resident.right_arm.rotation.x-arm)>.01 and scene.resident.model.position.y<-.2,"Elm crouches and animates the hand")
	check(scene.rabbit.position==bunny_pos and scene.rabbit.ears[0].rotation.x<0,"Rabbit settles rather than hopping during the touch")
	check(scene._save_now(),"Mid-touch saves resident, rabbit and shared timer atomically")
	var saved: Dictionary = scene.store.load_state().state
	check(Store.valid_state(saved),"Paired mid-touch state passes complete save validation")
	var fresh = fixture()
	fresh.simulation_seconds = saved.simulation_seconds
	fresh.needs.restore(saved.world_state.basic_life)
	fresh.resident.restore(saved.resident)
	fresh.rabbit.restore(saved.world_state.rabbit,fresh.simulation_seconds)
	fresh.journal.restore(saved.world_state.life_journal,fresh.simulation_seconds)
	fresh.pet_companion.restore(saved.world_state.pet_companion)
	check(absf(fresh.pet_companion.remaining-scene.pet_companion.remaining)<.000001 and count_pet(fresh,"pet_started")==1,"Fresh world resumes exact touch phase without another start")
	var wait: float = fresh.resident.remaining
	until_phase(fresh,"idle",160)
	check(fresh.pet_companion.latest.phase=="completed" and count_pet(fresh,"pet_done")==1,"Exactly one completed touch follows the actual animation")
	check(fresh.keepsakes.records.has("pet_done"),"Completed touch creates an enduring memory")
	check(fresh.rabbit.events.filter(func(e): return e.kind=="pet_done")[0].interaction_id==fresh.pet_companion.latest.id,"Rabbit's completion refers to the stable shared interaction")
	check(fresh.journal.entries(0,"pet").size()==2 and fresh.resident.recent_events.has("pet.rabbit.001:pet_done:"+str(int(fresh.pet_companion.latest.id))),"Elm journal and resident records match the rabbit's completed interaction")
	check(fresh.resident.remaining==wait and fresh.resident.model.rotation.x==0 and fresh.resident.right_arm.rotation.z==0,"Ordinary visit progress and neutral pose survive completion")
	fresh._advance_simulation(2)
	check(count_pet(fresh,"pet_done")==1 and fresh.pet_companion.phase=="idle","Cooldown prevents repeated interaction and duplicated completion")
	check(fresh._save_now() and fresh.store.load_state().status=="ok","Completed pair remains durable")
	# Hunger interrupts a real touch; completion is never invented.
	scene.needs.satiety = 54
	scene._advance_simulation(.05)
	check(scene.pet_companion.latest.phase=="cancelled" and count_pet(scene,"pet_done")==0,"Hunger cancels a touch instead of falsely completing it")
	check(count_pet(scene,"pet_cancelled")==1 and scene.resident.model.position.y==0,"Cancellation records both sides and releases the pose")
	scene.needs.satiety = 85
	home(scene)
	scene.pet_companion.invite()
	scene.resident.user_action.enqueue(scene.simulation_seconds)
	scene._advance_simulation(.05)
	check(scene.pet_companion.phase=="idle" and scene.pet_companion.requested,"Explicit local action takes priority over invitation")
	scene.resident.user_action.latest.clear()
	scene.resident.mode = "drive"
	check(not scene.pet_companion.advance(scene,.05,scene.simulation_seconds),"Pet interaction cannot hold a driver")
	scene.resident.mode = "eat"
	check(not scene.pet_companion.advance(scene,.05,scene.simulation_seconds),"Pet interaction cannot interrupt a meal")
	home(scene)
	scene.needs.energy = 20
	check(not scene.pet_companion.advance(scene,.05,scene.simulation_seconds),"Low energy takes priority")
	scene.needs.energy = 90
	# Corrupt pair/unknown phase/future times must protect saves.
	var bad: Dictionary = saved.duplicate(true)
	bad.world_state.rabbit.events = bad.world_state.rabbit.events.filter(func(e): return e.kind!="pet_started")
	check(not Store.valid_state(bad),"Active touch without the rabbit start record rejected")
	bad = saved.duplicate(true)
	bad.world_state.pet_companion.remaining = 99
	check(not Store.valid_state(bad),"Impossible touch duration rejected")
	bad = saved.duplicate(true)
	bad.world_state.pet_companion.latest.started_seconds = bad.simulation_seconds+1
	check(not Store.valid_state(bad),"Future touch event rejected")
	bad = saved.duplicate(true)
	bad.world_state.rabbit.mode = "rest"
	check(not Store.valid_state(bad),"Mismatched actor modes rejected")
	bad = saved.duplicate(true)
	bad.world_state.erase("pet_companion")
	check(not Store.valid_state(bad),"Orphaned touch state rejected")
	bad = saved.duplicate(true)
	bad.world_state.rabbit.position = [7,6]
	check(not Store.valid_state(bad),"Remote touch rejected")
	# Genuine old v7 state has no companion component or new rabbit mode.
	var legacy: Dictionary = fresh.store.load_state().state
	legacy.world_state.erase("pet_companion")
	check(Store.valid_state(legacy),"Old idle rabbit save still loads without replay or backfill")
	check(saved.memories==[{"reserved":"keep"}] and saved.world_state.furniture.keep,"Interaction leaves reserved memory and unrelated assets untouched")
	# Automatic life includes companionship without any invitation.
	var natural = fixture()
	var completed := false
	var eats := false
	for i in range(36000):
		natural._advance_simulation(.2)
		completed = completed or natural.pet_companion.latest.get("phase")=="completed"
		eats = eats or natural.needs.meals_finished>0
	check(completed and eats,"A full local day naturally includes completed companionship and meals")
	check(natural._save_now() and natural.rabbit.events.size()<=16,"Full-day paired state stays bounded and valid")
	if DisplayServer.get_name()!="headless":
		until_phase(fresh,"idle",1)
		home(fresh)
		fresh.pet_companion.invite()
		until_phase(fresh,"petting")
		fresh._advance_simulation(2)
		for world in [scene,fresh,natural]:
			for child in world.get_children():
				if child is CanvasLayer: child.hide()
		fresh.camera.make_current()
		scene.hide()
		natural.hide()
		fresh.focus = fresh.resident.position+Vector3(0,.45,.2)
		fresh.zoom = 3.5
		fresh.azimuth = .65
		fresh.elevation = .45
		fresh._update_camera()
		await create_timer(.3).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/pet-companion-preview.png"))
	for world in [scene,fresh,natural]: world.saving_enabled = false
	print("PET_COMPANION_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
