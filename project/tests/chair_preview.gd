extends SceneTree
# Isolated authoring preview: always run with --save-test; never loads user progress.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if not "--save-test" in OS.get_cmdline_user_args():
		push_error("Chair preview requires --save-test isolation")
		quit(1)
		return
	var world = load("res://main.tscn").instantiate()
	root.size = Vector2i(1200, 800)
	root.add_child(world)
	world.set_process(false)
	var chair = world.house_interior.get_node_or_null("OakDeskChair")
	if chair == null:
		push_error("Chair missing")
		quit(1)
		return
	var meshes := 0
	var triangles := 0
	var bounds := AABB()
	var first := true
	for part in chair.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		for i in range(part.mesh.get_surface_count()):
			var arrays = part.mesh.surface_get_arrays(i)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			var mat = part.mesh.surface_get_material(i)
			if mat == null:
				push_error("Chair material missing")
				quit(1)
				return
		var box = part.transform * part.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if meshes != 12 or triangles != 1056 or bounds.size.y < 0.70 or bounds.size.y > 0.80:
		push_error("Unexpected chair structure or scale")
		quit(1)
		return
	print("CHAIR_IMPORT_OK meshes=", meshes, " triangles=", triangles, " bounds=", bounds)
	if DisplayServer.get_name() != "headless":
		for child in world.get_children():
			if child is CanvasLayer:
				child.hide()
		world._open_house_interior()
		world.focus = chair.global_position + Vector3(0,.35,0)
		world.zoom = 4.5
		world._update_camera()
		await create_timer(1.5).timeout
		RenderingServer.force_draw()
		var path = ProjectSettings.globalize_path("res://../art/chair_oak_v02/desk_chair_preview.png")
		root.get_texture().get_image().save_png(path)
		print("CHAIR_DESK_PREVIEW_SAVED ", path)
	world.saving_enabled = false
	quit()
