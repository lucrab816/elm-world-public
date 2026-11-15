extends SceneTree
const Transport = preload("res://chat_transport.gd")
const Recovery = preload("res://chat_recovery.gd")
class FakeTransport extends Transport:
	var starts := 0
	var next_code := "ok"
	var result := {}
	func configured() -> bool:
		return true
	func begin(_payload: Dictionary) -> String:
		starts += 1
		if next_code=="ok":
			reserve(Time.get_unix_time_from_system())
		return next_code
	func poll() -> Dictionary:
		var value := result
		result = {}
		return value
	func cancel(_reason: String = "cancelled") -> void:
		pass
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _run() -> void:
	root.size = Vector2i(1200,800)
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	var chat = world.chat_panel
	var fake = FakeTransport.new()
	fake.base = "/tmp/cozy-recovery-"+str(OS.get_process_id())
	chat.transport = fake
	chat.open_chat()
	chat.mode_picker.select(1)
	chat.entry.text = "溪边的小路真好看"
	chat.send_message()
	check(chat.pending and fake.starts==1,"Only explicit initial send creates a request")
	fake.result = {"status":"request_failed","diagnostic":"login_expired"}
	for i in range(40):
		await create_timer(.05).timeout
		if not chat.pending:
			break
	check(not chat.pending and chat.status.text.contains("登录已失效") and chat.recovery_actions.visible,"Real polling shows login recovery")
	check(chat.transcript.back().speaker=="系统","Failure never masquerades as Elm speech")
	var ledger: String = fake.base.path_join("attempts.json")
	var before := FileAccess.get_file_as_string(ledger)
	chat.restore_failed_message()
	check(chat.entry.text=="溪边的小路真好看" and fake.starts==1,"Restore action only returns original text")
	chat.entry.text = "这是一句新的草稿"
	chat._update_send()
	chat.restore_failed_message()
	check(chat.entry.text=="这是一句新的草稿" and chat.restore_button.disabled,"Recovery never overwrites a newer draft")
	chat.entry.clear()
	chat.refresh_local_status()
	chat.open_help()
	check(chat.help_dialog.visible and fake.starts==1,"Help and local refresh do not send")
	check(chat.help_dialog.dialog_text.contains("不验证登录") and chat.help_dialog.dialog_text.contains("仍需你另按发送"),"Help explains local-only checks and explicit sending")
	chat.help_dialog.hide()
	chat.use_local_mode()
	check(chat.mode_picker.selected==0,"User may switch to local simulation")
	chat.entry.text = "你好"
	chat.send_message()
	await create_timer(.4).timeout
	check(chat.transcript.back().speaker=="埃尔（本地模拟）" and fake.starts==1,"Local response remains local during remote failure")
	check(FileAccess.get_file_as_string(ledger)==before,"Recovery actions and local chat never reset or change attempts")
	for code in ["subscription_login_required","login_expired","usage_limit","rate_limit","network_error","timeout","cancelled","cli_missing","local_limit","cooldown","budget_unreadable","host_permission","invalid_decision","unexpected_tool_activity","unknown"]:
		chat.show_failure(code)
		check(chat.status.text==Recovery.guidance(code) and not chat.pending and fake.starts==1,"Clear static guidance without retry: "+code)
	chat.mode_picker.select(1)
	chat.failed_message = "保留原话"
	chat.entry.clear()
	chat.show_failure("timeout")
	chat.restore_failed_message()
	chat.send_message()
	check(fake.starts==1 and chat.entry.text=="保留原话" and chat.status.text.contains("间隔"),"Retry cannot bypass cooldown or lose restored draft")
	chat.close_chat()
	chat.open_chat()
	check(fake.starts==1 and chat.entry.text=="保留原话","Reopening keeps draft and never retries")
	chat.cancel_network()
	check(not chat.recovery_actions.visible,"Idle background cancellation does not invent failure")
	var actor = world.resident
	var elapsed: float = actor.elapsed
	world._advance_simulation(.5)
	check(actor.elapsed>elapsed,"World continues living through recovery")
	# Force the existing helper watchdog over its boundary using a fake local worker.
	var t = Transport.new()
	t.base = fake.base.path_join("watchdog")
	t.directory = t.base.path_join("request")
	DirAccess.make_dir_recursive_absolute(t.directory)
	var script: String = t.base.path_join("fake_worker.py")
	var file := FileAccess.open(script,FileAccess.WRITE)
	file.store_string("import sys,time\nfrom pathlib import Path\np=Path(sys.argv[1])\nwhile not (p/'cancel').exists():time.sleep(.01)\n")
	file.close()
	t.pid = OS.create_process("/usr/local/bin/python3",[script,t.directory])
	t.started_ms = Time.get_ticks_msec()-76000
	var outcome := {}
	for i in range(100):
		outcome = t.poll()
		if not outcome.is_empty():
			break
		await create_timer(.03).timeout
	check(outcome.get("status")=="timeout" and t.pid==-1,"Watchdog timeout stays timeout after helper cleanup")
	# Realistic long context and error body must leave the input and actions visible.
	chat.context_provider = func(): return {"activity":"坐在长椅上休息", "events":"菜地旁 · 看看周围\n家门口 · 看看周围\n长椅 · 开始休息\n树荫 · 看看周围\n菜地旁 · 看看周围"}
	chat.refresh_context()
	chat.show_failure("login_expired")
	for i in range(10):
		await process_frame
	check(chat.panel.get_global_rect().position.y>=0 and chat.panel.get_global_rect().end.y<=800 and chat.entry.get_global_rect().end.y<800,"Recovery fits standard 800px viewport")
	if DisplayServer.get_name()!="headless":
		await create_timer(.5).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/step-3.2.3.png"))
	if DisplayServer.get_name()!="headless":
		chat.open_help()
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/step-3.2.3-help.png"))
	world.saving_enabled = false
	print("RECOVERY_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
