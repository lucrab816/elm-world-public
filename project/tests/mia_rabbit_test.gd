extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
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
	scene.rabbit.adopt(0)
	scene.rabbit_enabled = true
	scene.neighbor.adopt(0)
	scene.neighbor_enabled = true
	scene.store = Store.new("/tmp/cozy-mia-rabbit-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"mia-rabbit-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"keep":true}]}
	return scene
func position_pair(scene) -> void:
	scene.resident.mode = "observe"
	scene.resident.remaining = 25
	scene.resident.route.clear()
	scene.neighbor._place(Vector2(-5.5,3))
	scene.neighbor.mode = "rest"
	scene.neighbor.remaining = 12
	scene.neighbor.route.clear()
	scene.neighbor.destination = ""
	scene.neighbor._sync_obstacle()
	scene.rabbit._place(Vector2(-4.8,3))
	scene.rabbit.mode = "rest"
	scene.rabbit.remaining = 12
	scene.rabbit.route.clear()
	scene.rabbit._sync_obstacle()
	scene.mia_rabbit.cooldown = 0
	scene.neighbor_greeting.cooldown = 120
	scene.pet_companion.cooldown = 120
	scene.garden_care.cooldown = 120
func run() -> void:
	var scene = fixture()
	position_pair(scene)
	var before: float = scene.resident.elapsed
	scene._advance_simulation(.1)
	check(scene.mia_rabbit.active() and scene.neighbor.mode=="pet_rabbit" and scene.rabbit.mode=="mia_pet","Mia and Drake start a real encounter")
	check(scene.resident.elapsed>before,"Elm continues his own life during the encounter")
	check(scene._save_now(),"Encounter can be saved while in progress")
	var loaded = scene.store.load_state()
	check(loaded.status=="ok" and loaded.state.memories==[{"keep":true}],"Save keeps existing memories")
	var saved: Dictionary = loaded.state
	var fresh = fixture()
	fresh.simulation_seconds = saved.simulation_seconds
	fresh.needs.restore(saved.world_state.basic_life)
	fresh.resident.restore(saved.resident)
	fresh.rabbit.restore(saved.world_state.rabbit,fresh.simulation_seconds)
	fresh.pet_companion.restore(saved.world_state.pet_companion)
	fresh.neighbor.restore(saved.world_state.neighbor,fresh.simulation_seconds)
	fresh.neighbor_greeting.restore(saved.world_state.neighbor_greeting)
	fresh.garden_care.restore(saved.world_state.garden_care)
	fresh.mia_rabbit.restore(saved.world_state.mia_rabbit)
	fresh.journal.restore(saved.world_state.life_journal,fresh.simulation_seconds)
	check(fresh.mia_rabbit.active(),"Encounter resumes from saved state")
	for i in range(120):
		fresh._advance_simulation(.05)
		if not fresh.mia_rabbit.active(): break
	check(fresh.mia_rabbit.latest.phase=="completed","Interaction completes")
	check(fresh.neighbor.events.back().kind=="mia_pet_done" and fresh.rabbit.events.back().kind=="mia_pet_done","Both participants record completion")
	check(Chat.simulated_reply("米娅和德雷克互动过吗",fresh._chat_context()).contains("米娅轻轻摸了摸德雷克"),"Local recall describes the real event")
	check(fresh._save_now() and fresh.store.load_state().status=="ok","Completed encounter remains valid and saved")
	scene._invite_pet()
	check(scene.pet_companion.requested,"Elm's invitation is accepted during the encounter")
	scene._advance_simulation(.05)
	check(scene.mia_rabbit.latest.phase=="cancelled" and not scene.mia_rabbit.active(),"Elm's invitation safely interrupts Mia's encounter")
	check(scene._save_now() and scene.store.load_state().status=="ok","Interrupted encounter and request save consistently")
	print("MIA_RABBIT_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
