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
func wheel(point: Vector2, button: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event,true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
func run() -> void:
	root.size = Vector2i(1024,700)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene._set_sidebar_collapsed(false,false)
	scene.set_process(false)
	Engine.max_fps = 0
	scene.ui_details_toggle.set_pressed(true)
	scene.rest_reason.text = "生活详情会随着实际活动改变。".repeat(40)
	for index in range(3):
		scene.ui_layout.set_preference(index)
		await settle()
		var scroll = scene.ui_heading_scroll
		scroll.scroll_vertical = 0
		await settle()
		var point: Vector2 = scroll.get_global_rect().get_center()
		var original: float = scene.zoom
		wheel(point,MOUSE_BUTTON_WHEEL_DOWN)
		await settle()
		check(scroll.scroll_vertical>0,"Wheel really scrolls sidebar content at size "+str(index))
		check(scene.zoom==original,"Scrolling sidebar leaves world camera unchanged at size "+str(index))
		scroll.scroll_vertical = 0
		await settle()
		wheel(point,MOUSE_BUTTON_WHEEL_UP)
		await settle()
		check(scene.zoom==original,"Top edge cannot pass upward wheel to world at size "+str(index))
		scroll.scroll_vertical = 100000
		await settle()
		wheel(point,MOUSE_BUTTON_WHEEL_DOWN)
		await settle()
		check(scene.zoom==original,"Bottom edge cannot pass downward wheel to world at size "+str(index))
		wheel(scene.ui_footer.get_global_rect().get_center(),MOUSE_BUTTON_WHEEL_UP)
		await settle()
		check(scene.zoom==original,"Footer does not forward wheel to camera at size "+str(index))
		var bounds := root.get_visible_rect().size
		wheel(Vector2(bounds.x-30,bounds.y*.45),MOUSE_BUTTON_WHEEL_UP)
		await settle()
		check(is_equal_approx(scene.zoom,original-1.2),"Wheel over open world still zooms at size "+str(index))
	print("UI_SCROLL_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
