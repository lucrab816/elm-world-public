extends SceneTree
const Action = preload("res://action_request.gd")
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
class FailedStore extends RefCounted:
	func save_state(_state: Dictionary) -> bool:
		return false
class BlockedNavigation extends RefCounted:
	func path(_from: Vector2,_to: Vector2,_radius: float,_park: Vector2) -> PackedVector2Array:
		return PackedVector2Array()
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
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
	scene.store = Store.new("/tmp/cozy-action-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"action-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{"furniture":{"keep":true}},"memories":[{"reserved":"keep"}]}
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	scene.car.random.seed = 42
	return scene
func wait_phase(scene, phase: String, max_seconds: float = 240) -> void:
	for i in range(int(max_seconds/.05)):
		if scene.resident.user_action.phase()==phase:
			return
		scene._advance_simulation(.05)
func run() -> void:
	root.size = Vector2i(1200,800)
	check(Action.recognizes("请你去树荫歇一会儿吧！") and Action.recognizes("去树下休息一下"),"Finite polite rest requests recognized")
	for text in ["不要去树荫歇一会儿","你会去树荫歇一会儿吗","明天去树荫歇一会儿","他说去树荫歇一会儿","去厨房做饭","去树下坐一会儿"]:
		check(not Action.recognizes(text),"Negation, questions, quotes and unsupported actions never execute: "+text)
	var scene = fixture()
	var actor = scene.resident
	var result: Dictionary = scene._submit_local_action("去树荫歇一会儿")
	check(result.handled and actor.user_action.phase()=="queued" and actor.mode=="observe","Request queues without interrupting current action")
	var id: int = actor.user_action.latest.id
	var duplicate: Dictionary = scene._submit_local_action("去树下休息一下")
	check(actor.user_action.latest.id==id and duplicate.message.contains("不会重复"),"Duplicate active request is idempotent")
	var loaded: Dictionary = scene.store.load_state()
	check(loaded.status=="ok" and loaded.state.resident.user_action.latest.phase=="queued","Accepted request is saved before acknowledgment")
	var resumed_queue = fixture()
	check(resumed_queue.resident.restore(loaded.state.resident) and resumed_queue.resident.user_action.latest.id==id and resumed_queue.resident.user_action.phase()=="queued","Queued request survives fresh resident restoration")
	resumed_queue.queue_free()
	await process_frame
	check(loaded.state.memories==[{"reserved":"keep"}] and loaded.state.world_state.furniture.keep,"Request preserves other world and memory fields")
	wait_phase(scene,"moving")
	check(actor.mode=="move" and actor.destination_id==Action.TARGET,"Resident really starts walking to requested shade")
	var saved: Dictionary = actor.snapshot()
	check(actor.restore(saved) and actor.snapshot()==saved,"Walking request resumes without replanning or duplication")
	wait_phase(scene,"resting")
	check(actor.current_location==Action.TARGET and actor.mode=="rest" and is_equal_approx(actor.remaining,30),"Arrival begins real 30-second shade rest")
	check(scene._chat_context().rest_reason.contains("你的邀请"),"Rest explanation identifies the real user invitation")
	check(scene.store.load_state().state.resident.user_action.latest.phase=="resting","Arrival transition is immediately saved")
	var rest_events: int = scene.journal.entries(0,"rest").size()
	scene._advance_simulation(5)
	saved = actor.snapshot()
	check(actor.restore(saved) and is_equal_approx(actor.remaining,25) and scene.journal.entries(0,"rest").size()==rest_events,"Mid-rest restore keeps progress and does not re-record arrival")
	if DisplayServer.get_name()!="headless":
		for child in scene.get_children():
			if child is CanvasLayer: child.hide()
		scene.focus = actor.position+Vector3.UP*.6
		scene.zoom = 7
		scene._update_camera()
		await create_timer(.4).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/step-3.4.1-rest.png"))
	wait_phase(scene,"completed")
	check(actor.user_action.phase()=="completed" and actor.mode=="move","Rest really finishes and ordinary life resumes")
	check(scene.journal.entries(0,"rest").any(func(e): return e.kind=="rest_done"),"Completion appears only after actual rest ends")
	loaded = scene.store.load_state()
	var restored = fixture()
	check(restored.resident.restore(loaded.state.resident) and restored.resident.user_action.phase()=="completed","Completed request remains terminal after restart")
	check(scene._submit_local_action("去树荫歇一会儿").handled and actor.user_action.latest.id==id+1,"A new request after completion gets a new id")
	var tired = fixture()
	tired.needs.energy = 10
	tired._submit_local_action("去树荫歇一会儿")
	wait_phase(tired,"resting")
	check(tired.resident.mode=="rest" and is_equal_approx(tired.resident.remaining,60),"Low-energy requested rest safely extends to 60 seconds")
	var without_rest: Dictionary = tired.resident.snapshot()
	tired.resident.catalog.locations[Action.TARGET].activities = ["observe"]
	check(tired.resident.restore(without_rest) and tired.resident.user_action.phase()=="failed" and tired.resident.mode=="observe","Lost rest affordance during restore cancels safely instead of corrupting save")
	# Finish meal first, then execute instead of making hunger wait.
	var hungry = fixture()
	hungry.needs.satiety = 40
	hungry._submit_local_action("去树荫歇一会儿")
	hungry._advance_simulation(3)
	check(hungry.resident.user_action.phase()=="queued" and hungry.resident.destination_id=="place.home_front","Hungry resident goes home before requested rest")
	wait_phase(hungry,"moving")
	check(hungry.needs.meals_finished==1 and hungry.resident.destination_id==Action.TARGET,"Queued action starts after real meal completion")
	# No jumping out of a moving car.
	var driving = fixture()
	for i in range(6000):
		driving._advance_simulation(.05)
		if driving.resident.mode=="drive": break
	var car_point: Vector3 = driving.car.position
	driving._submit_local_action("去树荫歇一会儿")
	check(driving.resident.mode=="drive" and driving.car.position==car_point,"Request never teleports Elm out of the moving car")
	wait_phase(driving,"moving",300)
	check(driving.resident.mode=="move" and driving.resident.destination_id==Action.TARGET,"Requested walk begins after actual parking")
	# Concrete failures, no fake completion or automatic retries.
	var blocked = fixture()
	blocked._submit_local_action("去树荫歇一会儿")
	blocked.navigation = BlockedNavigation.new()
	blocked._advance_simulation(3)
	check(blocked.resident.user_action.phase()=="failed" and blocked.resident.user_action.latest.reason=="blocked","Unreachable target fails visibly")
	var missing = fixture()
	missing.resident.catalog.locations.erase(Action.TARGET)
	check(missing._submit_local_action("去树荫歇一会儿").message.contains("没有接下") and missing.resident.user_action.latest.is_empty(),"Missing rest affordance rejects before acceptance")
	var failure = fixture()
	failure.store = FailedStore.new()
	check(failure._submit_local_action("去树荫歇一会儿").message.contains("保存失败") and failure.resident.user_action.latest.is_empty(),"Save failure cannot leave an acknowledged live request")
	var bad: Dictionary = loaded.state.duplicate(true)
	bad.resident.user_action.latest.target = "unknown"
	check(not Store.valid_state(bad),"Unsupported saved action target rejected")
	bad = loaded.state.duplicate(true)
	bad.resident.user_action.latest.updated_seconds = bad.simulation_seconds+100
	check(not Store.valid_state(bad),"Future action timestamps rejected")
	bad = loaded.state.duplicate(true)
	bad.resident.user_action.latest.phase = "resting"
	check(not Store.valid_state(bad),"Action phase inconsistent with physical mode rejected")
	var legacy: Dictionary = actor.snapshot()
	legacy.erase("user_action")
	check(actor.restore(legacy) and actor.user_action.latest.is_empty(),"Legacy resident without requests is accepted")
	# Actual chat dispatch, even when real chat configuration is unavailable.
	var chat_scene = fixture()
	var panel = chat_scene.chat_panel
	panel.open_chat()
	panel.mode_picker.select(1)
	panel.entry.text = "去树荫歇一会儿"
	panel._update_send()
	check(not panel.send_button.disabled and panel.send_button.text.contains("本地行动"),"Local command remains usable when real chat is blocked")
	panel.send_message()
	check(chat_scene.resident.user_action.phase()=="queued" and not panel.pending and panel.transcript.back().speaker=="行动请求（本地）","Chat dispatch executes locally with no model wait")
	check(panel.activity.text.contains("请求1"),"Chat shows current request progress")
	for child in root.get_children():
		if child is Node3D: child.saving_enabled = false
	print("ACTION_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
