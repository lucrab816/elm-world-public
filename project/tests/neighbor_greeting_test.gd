extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Greeting = preload("res://neighbor_greeting.gd")
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
	scene.store = Store.new("/tmp/cozy-greeting-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"greeting-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{"asset":{"keep":true}},"memories":[{"reserved":"keep"}]}
	return scene
func position_pair(scene) -> void:
	scene.resident.position = Vector3(-4.5,0,3)
	scene.resident._sync_height()
	scene.resident.mode = "observe"
	scene.resident.remaining = 25
	scene.resident.route.clear()
	scene.resident.ride_requested = false
	scene.resident._pose_stand()
	scene.neighbor._place(Vector2(-5.5,3))
	scene.neighbor.mode = "rest"
	scene.neighbor.remaining = 12
	scene.neighbor.route.clear()
	scene.neighbor.destination = ""
	scene.neighbor._sync_obstacle()
	scene.neighbor_greeting.cooldown = 0
func count_event(scene, kind: String) -> int:
	return scene.neighbor.events.filter(func(e): return e.kind==kind).size()
func run() -> void:
	var scene = fixture()
	position_pair(scene)
	check(Chat.simulated_reply("你见过米娅吗",scene._chat_context()).contains("没有保留"),"No encounter is invented before greeting")
	scene._advance_simulation(.1)
	check(scene.neighbor_greeting.active() and scene.neighbor.mode=="greeting","Two nearby free residents begin a real greeting")
	check(count_event(scene,"greet_started")==1 and scene.journal.entries(0,"neighbor").size()==1,"Both residents and diary record one real start")
	var id: int = int(scene.neighbor_greeting.latest.id)
	check(scene.resident.recent_events.has("neighbor.mia.001:greet_started:"+str(id)),"Elm's start has the shared ID")
	check(scene.neighbor.events.back().place=="yard","A mid-yard greeting is not attributed to Mia's previous destination")
	check(scene.neighbor.right_arm.rotation.x< -1.5 and scene.resident.right_arm.rotation.x< -1.5,"Both visibly wave")
	check(scene._save_now(),"A greeting in progress is saved as one paired state")
	var saved: Dictionary = scene.store.load_state().state
	check(Store.valid_state(saved),"Paired state passes full validation")
	var fresh = fixture()
	fresh.simulation_seconds = saved.simulation_seconds
	fresh.needs.restore(saved.world_state.basic_life)
	fresh.resident.restore(saved.resident)
	fresh.rabbit.restore(saved.world_state.rabbit,fresh.simulation_seconds)
	fresh.pet_companion.restore(saved.world_state.pet_companion)
	check(fresh.neighbor.restore(saved.world_state.neighbor,fresh.simulation_seconds),"Mia restores during greeting")
	fresh.neighbor_greeting.restore(saved.world_state.neighbor_greeting)
	fresh.journal.restore(saved.world_state.life_journal,fresh.simulation_seconds)
	check(count_event(fresh,"greet_started")==1 and absf(fresh.neighbor_greeting.remaining-scene.neighbor_greeting.remaining)<.00001,"Reload keeps phase and does not duplicate the start")
	var actor_wait: float = fresh.resident.remaining
	var npc_wait: float = fresh.neighbor.remaining
	for i in range(200):
		fresh._advance_simulation(.05)
		if not fresh.neighbor_greeting.active(): break
	check(fresh.neighbor_greeting.latest.phase=="completed" and count_event(fresh,"greet_done")==1,"Completed wave creates exactly one completion")
	check(fresh.keepsakes.records.has("greet_done"),"Completed greeting creates an enduring memory")
	check(fresh.neighbor.events.filter(func(e): return e.kind=="greet_done")[0].interaction_id==id and fresh.resident.recent_events.has("neighbor.mia.001:greet_done:"+str(id)),"Both completion records refer to the same interaction")
	check(fresh.journal.entries(0,"neighbor").size()==2 and Chat.simulated_reply("你见过米娅吗",fresh._chat_context()).contains("打了招呼"),"Diary and local recall report the actual completion")
	check(fresh.resident.remaining==actor_wait and fresh.neighbor.remaining==npc_wait,"Prior pauses resume without an artificial reset")
	check(fresh.resident.right_arm.rotation.x==0 and fresh.neighbor.right_arm.rotation.x==0,"Both return to their normal pose")
	fresh._advance_simulation(1)
	check(count_event(fresh,"greet_done")==1 and fresh.neighbor_greeting.cooldown>0,"Cooldown avoids immediate repeated completion")
	check(fresh._save_now() and fresh.store.load_state().status=="ok","Completed encounter remains durable")
	# A user action or urgent meal interrupts a real greeting, with no false success.
	scene.needs.satiety = 54
	scene._advance_simulation(.05)
	check(scene.neighbor_greeting.latest.phase=="cancelled" and count_event(scene,"greet_done")==0 and count_event(scene,"greet_cancelled")==1,"Urgent meal interrupts without recording completion")
	check(Chat.simulated_reply("和米娅打招呼了吗",scene._chat_context()).contains("没有完成"),"Recall distinguishes cancellation from completion")
	position_pair(scene)
	scene.needs.satiety = 85
	scene.resident.user_action.enqueue(scene.simulation_seconds)
	scene._advance_simulation(.05)
	check(not scene.neighbor_greeting.active(),"Explicit action has priority over greetings")
	scene.resident.user_action.latest.clear()
	position_pair(scene)
	scene.resident.ride_requested = true
	scene._advance_simulation(.05)
	check(not scene.neighbor_greeting.active(),"Driving invitation is not delayed by an automatic greeting")
	position_pair(scene)
	scene.pet_companion.phase = "approaching"
	check(not scene.neighbor_greeting.advance(scene,.05,scene.simulation_seconds),"No overlapping pet and neighbor interactions")
	scene.pet_companion.phase = "idle"
	position_pair(scene)
	scene.neighbor._place(Vector2(5,5))
	check(not scene.neighbor_greeting.advance(scene,.05,scene.simulation_seconds),"Distant residents cannot greet by teleportation")
	# A new request can be durably queued even during a wave; it then interrupts safely.
	var interrupted = fixture()
	position_pair(interrupted)
	interrupted._advance_simulation(.1)
	var request: Dictionary = interrupted._submit_local_action("去树荫歇一会儿")
	check(request.get("accepted",false) and interrupted.store.load_state().status=="ok","A new explicit request is saved during an active greeting")
	interrupted._advance_simulation(.05)
	check(not interrupted.neighbor_greeting.active() and interrupted.neighbor_greeting.latest.phase=="cancelled" and interrupted.resident.user_action.active(),"Saved request interrupts the wave without being lost")
	var ride = fixture()
	position_pair(ride)
	ride._advance_simulation(.1)
	ride.resident.ride_requested = true
	check(ride._save_now(),"A driving invitation remains saveable during a wave")
	ride._advance_simulation(.05)
	check(not ride.neighbor_greeting.active() and ride.resident.ride_requested,"Driving invitation interrupts the wave without being lost")
	var bad: Dictionary = saved.duplicate(true)
	bad.world_state.neighbor_greeting.remaining = 9
	check(not Store.valid_state(bad),"Impossible duration rejected")
	bad = saved.duplicate(true)
	bad.world_state.neighbor.position = [6,6]
	check(not Store.valid_state(bad),"Remote paired greeting rejected")
	bad = saved.duplicate(true)
	bad.world_state.neighbor.events = bad.world_state.neighbor.events.filter(func(e): return e.kind!="greet_started")
	check(not Store.valid_state(bad),"Missing Mia start event rejects a paired state")
	bad = saved.duplicate(true)
	bad.world_state.erase("neighbor_greeting")
	check(not Store.valid_state(bad),"Orphaned greeting mode is rejected")
	bad = saved.duplicate(true)
	bad.world_state.pet_companion.phase = "petting"
	check(not Store.valid_state(bad),"Simultaneous interactions are rejected")
	var legacy: Dictionary = fresh.store.load_state().state
	legacy.world_state.erase("neighbor_greeting")
	check(Store.valid_state(legacy),"Previous idle world without greeting data remains valid")
	check(saved.memories==[{"reserved":"keep"}] and saved.world_state.asset.keep,"Existing memories and assets survive")
	# Natural behavior is verified without staging or accelerating the user's world.
	var natural = fixture()
	var met := false
	var ate := false
	var clearance := INF
	for i in range(36000):
		natural._advance_simulation(.2)
		met = met or natural.neighbor_greeting.latest.get("phase")=="completed"
		ate = ate or natural.needs.meals_finished>0
		if natural.resident.mode=="drive": clearance = minf(clearance,natural.neighbor.flat().distance_to(Vector2(natural.car.position.x,natural.car.position.z)))
	check(met and ate and clearance>=1.7,"A full running day naturally includes a greeting, meals and safe driving")
	check(natural._save_now() and natural.store.load_state().status=="ok","Long-running shared state remains valid")
	for world in [scene,fresh,natural,interrupted,ride]: world.saving_enabled = false
	print("NEIGHBOR_GREETING_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
