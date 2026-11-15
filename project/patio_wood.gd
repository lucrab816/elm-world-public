extends RefCounted

const GRAIN = preload("res://patio_wood.gdshader")
static var grain_atlas: Texture2D
const BAKED_GREEN := Color("#909d60")
const CHAIR_GREEN := Color("#909d60")
const ACCENT := Color("#e1d19c")

static func paint_tree(root: Node3D, wood: Array[String], accents: Array[String]) -> void:
	for node in root.find_children("*","MeshInstance3D",true,false):
		var part := node as MeshInstance3D
		for index in part.mesh.get_surface_count():
			var source := part.get_active_material(index)
			if source==null: continue
			if source.resource_name.to_upper() in wood:
				var bounds := part.get_aabb()
				var axis := bounds.size.max_axis_index()
				var name := source.resource_name.to_upper()
				var color := Color(name) if name in ["DEA45F","B27A44"] else CHAIR_GREEN
				part.set_surface_override_material(index,finish(part,axis,color))
			elif source.resource_name.to_upper() in accents:
				var trim := StandardMaterial3D.new()
				trim.albedo_color = ACCENT
				trim.roughness = .82
				part.set_surface_override_material(index,trim)

static func finish(part: MeshInstance3D, axis: int, color: Color = CHAIR_GREEN, shared_coordinates := false) -> ShaderMaterial:
	var bounds := part.get_aabb()
	if grain_atlas==null:
		grain_atlas = load("res://assets/patio_grain.png") as Texture2D
	var stretch := Vector3(5,6,5)
	stretch[axis] = 2.0
	var material := ShaderMaterial.new()
	material.shader = GRAIN
	material.set_shader_parameter("atlas",grain_atlas)
	material.set_shader_parameter("baked_green",BAKED_GREEN)
	material.set_shader_parameter("base_color",color)
	material.set_shader_parameter("grain_scale",stretch)
	material.set_shader_parameter("grain_origin",bounds.position if not shared_coordinates else -part.position+Vector3(-.86,0,-.86))
	material.set_shader_parameter("grain_size",bounds.size if not shared_coordinates else Vector3(1.72,.75,1.72))
	material.set_shader_parameter("grain_offset",float(absi(hash(part.name))%113)*.017 if not shared_coordinates else 0.0)
	return material
