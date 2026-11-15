extends SceneTree
const Transport = preload("res://chat_transport.gd")
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
	var transport = Transport.new()
	transport.base = "/tmp/cozy-transport-"+str(OS.get_process_id())
	check(transport.reserve(10000)=="ok","First manual attempt allowed")
	check(transport.reserve(10001)=="cooldown","Cooldown persists between attempts")
	check(transport.reserve(10121)=="ok" and transport.reserve(10242)=="ok","Three spaced attempts allowed")
	check(transport.reserve(10363)=="ok" and transport.reserve(10484)=="ok","Fourth and fifth attempts allowed")
	check(transport.reserve(10605)=="local_limit","Sixth attempt blocked")
	var restarted = Transport.new()
	restarted.base = transport.base
	check(restarted.reserve(10726)=="local_limit","Restart does not reset local budget")
	check(restarted.reserve(30000)=="ok","Expired local window permits another manual attempt")
	check(restarted.reserve(100)=="budget_unreadable","Backward clock cannot create a fresh budget")
	var file := FileAccess.open(transport.base.path_join("attempts.json"),FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	check(transport.reserve(40000)=="budget_unreadable","Unreadable budget blocks requests instead of resetting")
	transport.directory = transport.base.path_join("request")
	DirAccess.make_dir_recursive_absolute(transport.directory)
	var script: String = transport.base.path_join("fake_worker.py")
	file = FileAccess.open(script,FileAccess.WRITE)
	file.store_string("import sys,time,json\nfrom pathlib import Path\np=Path(sys.argv[1])\nwhile not (p/'cancel').exists():time.sleep(.02)\n(p/'output.json').write_text(json.dumps({'status':'cancelled'}))\n")
	file.close()
	transport.pid = OS.create_process("/usr/local/bin/python3",[script,transport.directory])
	transport.started_ms = Time.get_ticks_msec()
	check(transport.pid>0 and transport.poll().is_empty(),"Pending helper is polled without blocking world")
	transport.cancel()
	var result := {}
	for i in range(100):
		await create_timer(0.05).timeout
		result = transport.poll()
		if not result.is_empty():
			break
	check(result.get("status")=="cancelled" and transport.pid==-1,"Cancel stops and reaps helper")
	check(transport.directory.is_empty(),"Transient request files are cleaned")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var chat = scene.chat_panel
	chat.open_chat()
	chat.mode_picker.select(1)
	chat.entry.text = "你好"
	chat.send_message()
	check(not chat.pending and chat.status.text.contains("配置"),"Missing packaged runtime is a visible error, no simulated reply masquerading as AI")
	check(chat.transcript.is_empty() and chat.entry.text=="你好" and chat.send_button.disabled,"Unavailable send preserves draft without making a request")
	print("TRANSPORT_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
