extends SceneTree
const Transport = preload("res://chat_transport.gd")
class ReadyTransport extends Transport:
	func configured() -> bool:
		return true
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func write_ledger(transport, value: String) -> void:
	DirAccess.make_dir_recursive_absolute(transport.base)
	var f := FileAccess.open(transport.base.path_join("attempts.json"),FileAccess.WRITE)
	f.store_string(value)
	f.close()
func _run() -> void:
	var t = ReadyTransport.new()
	t.base = "/tmp/cozy-availability-"+str(OS.get_process_id())
	var ledger: String = t.base.path_join("attempts.json")
	check(t.budget_status(10000).remaining==5 and not FileAccess.file_exists(ledger),"Display of empty budget never creates ledger")
	write_ledger(t,"[10000]")
	var before := FileAccess.get_file_as_string(ledger)
	var state = t.budget_status(10001)
	check(state.remaining==4 and state.code=="cooldown" and state.cooldown_seconds==119,"Exact cooldown and remaining count")
	check(t.budget_status(10120).code=="ok","Cooldown expires at the exact boundary")
	check(FileAccess.get_file_as_string(ledger)==before,"Repeated display never changes quota")
	write_ledger(t,"[10000,10120,10240,10360,10480]")
	state = t.budget_status(10600)
	check(state.remaining==0 and state.code=="local_limit" and state.reset_seconds==17400,"Full budget shows next rolling restoration")
	check(t.budget_status(28000).remaining==1,"Only first expired attempt returns, not all five")
	check(t.budget_status(28480).remaining==5,"All attempts eventually expire")
	for value in ["broken","{}","[10001,10000]","[-1]","[40000]","[true]"]:
		write_ledger(t,value)
		check(t.budget_status(30000).code=="budget_unreadable","Corrupt/unordered/future ledger blocks: "+value)
	root.size = Vector2i(1200,800)
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	var panel = world.chat_panel
	panel.transport = t
	panel.open_chat()
	panel.mode_picker.select(1)
	var now := Time.get_unix_time_from_system()
	write_ledger(t,JSON.stringify([now-1]))
	panel.entry.text = "保留我的草稿"
	panel.refresh_availability()
	check(panel.send_button.disabled and panel.budget_label.text.contains("4 / 5") and panel.budget_label.text.contains("后可再发"),"Cooldown visible and real send disabled")
	panel.send_message()
	check(panel.entry.text=="保留我的草稿" and panel.transcript.is_empty(),"Enter during cooldown preserves draft and makes no transcript/request")
	panel.mode_picker.select(0)
	panel.refresh_availability()
	check(not panel.send_button.disabled,"Local simulation remains usable during real cooldown")
	write_ledger(t,JSON.stringify([now-900,now-700,now-500,now-300,now-130]))
	panel.mode_picker.select(1)
	panel.refresh_availability()
	check(panel.send_button.disabled and panel.budget_label.text.contains("0 / 5") and panel.budget_label.text.contains("恢复1次"),"Limit visible and never enables real send")
	write_ledger(t,JSON.stringify([now-121]))
	panel.refresh_availability()
	check(not panel.send_button.disabled and panel.connection_label.text.contains("手动发送时核实"),"Ready budget enables send without claiming a verified login")
	panel.transport.pid = 123
	panel._update_send()
	check(panel.send_button.disabled,"Helper cleanup keeps real send disabled")
	panel.transport.pid = -1
	write_ledger(t,"broken")
	panel.refresh_availability()
	check(panel.send_button.disabled and panel.budget_label.text.contains("不可读"),"Corrupt ledger pauses real mode visibly")
	for i in range(8):
		await process_frame
	check(panel.panel.get_global_rect().end.y<=800 and panel.entry.get_global_rect().end.y<800,"Availability labels and input fit the standard viewport")
	if DisplayServer.get_name()!="headless":
		write_ledger(t,JSON.stringify([now-1]))
		panel.refresh_availability()
		await create_timer(1).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/step-3.2.2.png"))
	world.saving_enabled = false
	print("AVAILABILITY_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
