extends SceneTree
const Chat = preload("res://chat_panel.gd")
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
func _run() -> void:
	root.size = Vector2i(1200,800)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var panel = scene.chat_panel
	check(not panel.visible,"Chat starts closed")
	panel.open_chat()
	for i in range(8):
		await process_frame
	check(panel.panel.get_global_rect().end.y<=800 and panel.entry.global_position.y>0 and panel.entry.global_position.y<800,"Initial chat panel and input fit the viewport")
	check(panel.visible and panel.entry.max_length==240,"Chat opens with bounded text input")
	check(panel.send_button.disabled,"Empty input cannot send")
	panel.entry.text = "   "
	panel.send_message()
	check(panel.transcript.is_empty() and not panel.pending,"Whitespace does not create requests")
	var actor = scene.resident
	var head: Vector2 = scene.camera.unproject_position(actor.global_position+Vector3.UP*0.7)
	check(scene._resident_hit(head) and not scene._resident_hit(Vector2(-100,-100)),"Projected resident hit target excludes far-away clicks")
	panel.close_chat()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = head
	scene._unhandled_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = head+Vector2(30,0)
	scene._unhandled_input(release)
	check(not panel.visible,"Dragging does not open chat")
	scene._unhandled_input(press)
	release.position = head
	scene._unhandled_input(release)
	check(panel.visible,"Clicking the resident opens chat")
	check(panel.events.text.contains("还没有"),"Empty event list does not invent history")
	for i in range(1000):
		scene._advance_simulation(0.05)
	var context: Dictionary = scene._chat_context()
	check(not context.events.contains("还没有") and context.events.contains("长椅"),"Recent events derive from real arrival records")
	panel.refresh_context()
	check(panel.activity.text.contains(scene.resident_status.text),"Current activity is refreshed from the world")
	panel.entry.text = "你在做什么"
	panel.send_message()
	check(panel.pending and panel.send_button.disabled and panel.status.text.contains("模拟"),"Pending local reply has visible status and prevents repeat send")
	var count: int = panel.transcript.size()
	panel.send_message()
	check(panel.transcript.size()==count,"Repeated send during pending is ignored")
	var elapsed: float = actor.elapsed
	scene._advance_simulation(1)
	check(actor.elapsed>elapsed,"World continues living during chat")
	await create_timer(0.45).timeout
	check(not panel.pending and panel.transcript.back().speaker=="埃尔（本地模拟）","Reply is explicitly labelled simulated")
	check(panel.transcript.back().text.contains("实际活动"),"Activity question uses current real context")
	check(Chat.simulated_reply("最近去了哪里",context).contains(context.events),"History reply only quotes real event context")
	check(Chat.simulated_reply("请去树下坐下",context).contains("不能"),"Action requests do not pretend to execute")
	check(Chat.simulated_reply("记住我的名字",context).contains("不会"),"Memory requests do not claim persistence")
	check(Chat.simulated_reply("随便一句话",context).contains("暂时不能理解"),"Unsupported questions do not fabricate an answer")
	panel.entry.text = "你好"
	panel.send_message()
	panel.close_chat()
	var after_cancel: int = panel.transcript.size()
	await create_timer(0.45).timeout
	check(not panel.pending and panel.transcript.size()==after_cancel,"Closing cancels reply without a late response")
	panel.open_chat()
	check(panel.visible and not panel.pending,"Reopening after cancellation is usable")
	for i in range(30):
		panel._append("你","literal [b]<tag> "+str(i))
	check(panel.transcript.size()==20 and panel.history.text.contains("[b]<tag>"),"History stays bounded and renders text literally")
	# Save only the existing world format, without chat content or changing future memory fields.
	scene.store = Store.new("/tmp/cozy-chat-test-"+str(OS.get_process_id()))
	scene.state_template = {"world_id":"chat-test","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"text":"keep"}]}
	scene.simulation_seconds = 0
	scene.saving_enabled = true
	check(scene._save_now(),"World remains saveable while chat is open")
	var saved: Dictionary = scene.store.load_state()
	check(saved.state.memories==[{"text":"keep"}],"Chat does not overwrite memory fields")
	check(not JSON.stringify(saved.state).contains("literal [b]"),"Transient transcript is not written to world saves")
	panel.close_chat()
	scene.saving_enabled = false
	print("CHAT_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
