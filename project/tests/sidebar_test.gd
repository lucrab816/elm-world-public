extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func settle() -> void:
	for i in range(8): await process_frame
func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
func wheel(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
func run() -> void:
	root.size = Vector2i(1024,700)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	Engine.max_fps = 0
	var before: Dictionary = scene.resident.snapshot()
	for index in range(3):
		scene.ui_layout.set_preference(index)
		scene._set_sidebar_collapsed(true,false)
		await settle()
		check(not scene.ui_heading.visible and scene.ui_sidebar_toggle.visible,"Collapsed sidebar leaves only the toggle at size "+str(index))
		check(scene.ui_sidebar_toggle.get_global_rect().end.x<root.get_visible_rect().size.x,"Expand toggle fits the window at size "+str(index))
		click(scene.ui_sidebar_toggle.get_global_rect().get_center())
		await settle()
		check(scene.ui_heading.visible and not scene.ui_layout.sidebar_collapsed,"Actual button click expands sidebar at size "+str(index))
		var zoom_before: float = scene.zoom
		wheel(scene.ui_heading.get_global_rect().get_center())
		check(scene.zoom==zoom_before,"Expanded sidebar still blocks camera zoom at size "+str(index))
		click(scene.ui_sidebar_toggle.get_global_rect().get_center())
		await settle()
		check(not scene.ui_heading.visible and scene.ui_layout.sidebar_collapsed,"Actual button click collapses sidebar at size "+str(index))
		wheel(scene.ui_heading.get_global_rect().get_center())
		check(is_equal_approx(scene.zoom,zoom_before-1.2),"Freed sidebar area now permits world zoom instead of a ghost input blocker at size "+str(index))
		zoom_before = scene.zoom
		wheel(scene.ui_sidebar_toggle.get_global_rect().get_center())
		check(scene.zoom==zoom_before,"Small expand button does not forward wheel to camera at size "+str(index))
	check(scene.resident.snapshot()==before,"Folding and unfolding never changes resident activity or memory")
	print("SIDEBAR_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
