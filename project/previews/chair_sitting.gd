extends SceneTree
# An isolated live 3D fitting scene; no save load, simulation ticks, or model calls.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if not "--save-test" in OS.get_cmdline_user_args():
		push_error("Fitting scene requires --save-test")
		quit(1)
		return
	root.size = Vector2i(1200, 800)
	DisplayServer.window_set_title("埃尔试坐小木椅 · 独立美术预览")
	var world = load("res://main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	for child in world.get_children():
		if child is CanvasLayer:
			child.hide()
	var chair: Node3D = world._load_oak_chair()
	if chair == null:
		quit(1)
		return
	world.add_child(chair)
	chair.position = Vector3(2.6, world._height(2.6,1.8)-.006, 1.8)
	chair.rotation.y = -.35
	var elm = world.resident
	elm.set_process(false)
	elm.position = chair.position
	elm.rotation.y = chair.rotation.y
	elm.model.position.y = .415 - .535
	elm.marker.visible = false
	elm.meal_bowl.visible = false
	elm.left_leg.visible = false
	elm.right_leg.visible = false
	# Current Elm mannequin has rigid legs, so fit two-segment seated legs in
	# this authoring scene only. Existing identity and production poses stay intact.
	for side in [-1, 1]:
		world._box(Vector3(side*.12,.445,.105),Vector3(.17,.16,.28),"8d9d88",elm)
		world._box(Vector3(side*.12,.235,.235),Vector3(.16,.30,.17),"8d9d88",elm)
		world._box(Vector3(side*.12,.075,.285),Vector3(.19,.12,.29),"766956",elm)
	elm.left_arm.rotation.x = -.45
	elm.right_arm.rotation.x = -.45
	# Buttock at seat, knees forward, shins down, shoes rest at ground level.
	var sole_y: float = chair.position.y + .015
	var ground_y: float = world._height(chair.position.x,chair.position.z)
	if absf(sole_y-ground_y) > .04:
		push_error("Feet do not reach the ground")
		quit(1)
		return
	print("ELM_SEATED_PREVIEW_OK seat_height=0.415 feet_ground_delta=",sole_y-ground_y)
	world.focus = chair.position + Vector3(0,.65,0)
	world.zoom = 2.55
	world.azimuth = -.55
	world.elevation = .40
	world._update_camera()
	if DisplayServer.get_name() == "headless":
		quit()
		return
	await create_timer(1).timeout
	RenderingServer.force_draw()
	var folder = ProjectSettings.globalize_path("res://../art/chair_oak_v02/")
	root.get_texture().get_image().save_png(folder+"elm_seated_front.png")
	world.azimuth = 1.25
	world._update_camera()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(folder+"elm_seated_side.png")
	world.azimuth = -.55
	world._update_camera()
	print("ELM_SEATED_PREVIEWS_SAVED")
	if not "--keep-open" in OS.get_cmdline_user_args():
		quit()
