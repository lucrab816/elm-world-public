extends SceneTree
const Layout = preload("res://ui_layout.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func settle() -> void:
	for i in range(12): await process_frame
func in_view(control: Control, bounds: Vector2) -> bool:
	var r := control.get_global_rect()
	return r.position.x>=-.1 and r.position.y>=-.1 and r.end.x<=bounds.x+.1 and r.end.y<=bounds.y+.1
func run() -> void:
	check(Layout.backing_scale("macOS",1,2)==2,"Mixed-DPI Mac uses backing scale on the small non-Retina display")
	check(Layout.backing_scale("macOS",2,2)==2,"Moving back to Retina preserves the same logical interface size")
	check(Layout.backing_scale("macOS",1,1)==1,"An all-standard-display Mac does not get unnecessary double scaling")
	check(Layout.backing_scale("Windows",1.25,2)==1.25,"Other platforms retain their current display scale")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene._set_sidebar_collapsed(false,false)
	scene.set_process(false)
	Engine.max_fps = 0
	var before: Dictionary = scene.resident.snapshot()
	for resolution in [Vector2i(1024,700),Vector2i(1024,768),Vector2i(900,650),Vector2i(800,600),Vector2i(1600,900)]:
		root.size = resolution
		for index in range(3):
			scene.ui_layout.set_preference(index)
			await settle()
			var bounds := root.get_visible_rect().size
			var label := str(resolution)+" scale "+str(index)
			check(in_view(scene.ui_footer,bounds),"Footer fits "+label)
			check(in_view(scene.ui_heading,bounds) and scene.ui_heading.get_global_rect().end.y<scene.ui_footer.position.y,"Sidebar stays above footer "+label)
			check(in_view(scene.ui_size_picker,bounds) and scene.ui_size_picker.size.y>=36,"Size picker remains reachable "+label)
			check(scene.resident_status.get_theme_font_size("font_size")>=16,"Main text keeps a readable minimum "+label)
			for modal in [scene.chat_panel,scene.journal_panel,scene.memory_panel]:
				if modal==scene.chat_panel: modal.open_chat()
				elif modal==scene.journal_panel: modal.open_diary()
				else: modal.open_memory()
				await settle()
				check(in_view(modal.panel,bounds),"Modal fits "+modal.get_script().resource_path+" "+label)
				modal.hide()
			print("UI_LAYOUT ",label," logical=",bounds," sidebar=",scene.ui_heading.size," footer=",scene.ui_footer.size)
	root.size = Vector2i(1024,700)
	scene.ui_layout.set_preference(1)
	scene.chat_panel.open_chat()
	await settle()
	var chat = scene.chat_panel
	check(in_view(chat.entry,root.get_visible_rect().size) and in_view(chat.send_button,root.get_visible_rect().size),"At 1024x700 medium chat input and send are visible immediately")
	check(chat.entry.get_theme_font_size("font_size")>=18,"Chat entry uses readable text")
	check(scene.resident.snapshot()==before,"Interface resize and preference changes never change resident memory or activity")
	print("UI_LAYOUT_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
