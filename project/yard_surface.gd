extends RefCounted

const GRASS_COLOR := Color("#91a361")

const PATIO_CENTER := Vector2(4.40,-1.20)
const STONE_COLORS := ["c4bba7","b5aa96","c9bfaa","b9ad99"]
static var stone_textures: Array[ImageTexture] = []

static func grass_material() -> StandardMaterial3D:
	var grass := StandardMaterial3D.new()
	grass.roughness = .95
	grass.vertex_color_use_as_albedo = true
	grass.vertex_color_is_srgb = true
	grass.albedo_texture = _grass_texture()
	grass.texture_repeat = true
	grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return grass

static func _grass_texture() -> ImageTexture:
	const SIZE := 512
	var image := Image.create_empty(SIZE,SIZE,false,Image.FORMAT_RGB8)
	var cloud := FastNoiseLite.new()
	cloud.seed = 4031
	cloud.frequency = .009
	for y in SIZE:
		for x in SIZE:
			var a := float(x)/SIZE
			var b := float(y)/SIZE
			var top := lerpf(cloud.get_noise_2d(x,y),cloud.get_noise_2d(x-SIZE,y),a)
			var bottom := lerpf(cloud.get_noise_2d(x,y-SIZE),cloud.get_noise_2d(x-SIZE,y-SIZE),a)
			var shade := .953+lerpf(top,bottom,b)*.052
			image.set_pixel(x,y,Color(shade,shade,shade*.975))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2631
	for cluster in 76:
		var origin := Vector2(rng.randf_range(0,SIZE),rng.randf_range(0,SIZE))
		if cloud.get_noise_2dv(origin)<-.08: continue
		var spread := rng.randf_range(5,19)
		for blade in rng.randi_range(2,6):
			var start := origin+Vector2(rng.randf_range(-spread,spread),rng.randf_range(-spread,spread))
			var reach := Vector2.from_angle(rng.randf_range(0,TAU))*rng.randf_range(2.5,9)
			var strength := rng.randf_range(.038,.10)
			var tint := Color(.71,.76,.68) if blade%3 else Color(.84,.84,.70)
			for step in 12:
				var t := step/12.0
				var point := Vector2i((start+reach*t+Vector2(reach.x*.35*t*t,0)).round())
				var x := posmod(point.x,SIZE)
				var y := posmod(point.y,SIZE)
				image.set_pixel(x,y,image.get_pixel(x,y).lerp(tint,strength*(1-.57*t)))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func _stone_texture(seed_id: int) -> ImageTexture:
	var image := Image.create_empty(128,128,false,Image.FORMAT_RGB8)
	var field := FastNoiseLite.new()
	field.seed = seed_id
	field.frequency = .023
	var detail := FastNoiseLite.new()
	detail.seed = seed_id+391
	detail.frequency = .29
	var strata := FastNoiseLite.new()
	strata.seed = seed_id+752
	strata.frequency = .037
	var base := Color.WHITE
	for y in 128:
		for x in 128:
			var broad := field.get_noise_2d(x,y)
			var fine := detail.get_noise_2d(x,y)
			var shade := .975 + broad*.066 + fine*.007
			shade -= smoothstep(.30,.60,strata.get_noise_2d(x,y))*.105
			image.set_pixel(x,y,base*shade)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

static func make_editable_stone(seed_id: int) -> Node3D:
	if stone_textures.is_empty():
		for i in 7: stone_textures.append(_stone_texture(i*1253+76))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_id
	var object := Node3D.new()
	var w := rng.randf_range(.228,.262)
	var d := rng.randf_range(.154,.188)
	var c := rng.randf_range(.045,.088)
	var outline := [Vector2(-w+c,-d),Vector2(w-c,-d),Vector2(w,-d+c),Vector2(w,d-c),
		Vector2(w-c,d),Vector2(-w+c,d),Vector2(-w,d-c),Vector2(-w,-d+c)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var upper: Array[Vector3] = []
	var edge: Array[Vector3] = []
	var lower: Array[Vector3] = []
	var yaw := rng.randf_range(-.10,.1)
	var height := rng.randf_range(.014,.022)
	for corner in outline:
		var local: Vector2 = corner.rotated(yaw)+Vector2(rng.randf_range(-.012,.012),rng.randf_range(-.012,.012))
		var inset := local*.936
		upper.append(Vector3(inset.x,height,inset.y))
		edge.append(Vector3(local.x,.005,local.y))
		lower.append(Vector3(local.x,-.018,local.y))
	var center := Vector3(0,height,0)
	for i in upper.size():
		var j := (i+1)%upper.size()
		for v in [center,upper[i],upper[j],upper[i],edge[i],upper[j],upper[j],edge[i],edge[j],edge[i],lower[i],edge[j],edge[j],lower[i],lower[j]]:
			surface.set_smooth_group(-1)
			surface.set_uv(Vector2(.5+v.x/.62,.5+v.z/.48))
			surface.add_vertex(v)
	surface.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(STONE_COLORS[rng.randi_range(0,STONE_COLORS.size()-1)])
	mat.albedo_texture = stone_textures[rng.randi_range(0,stone_textures.size()-1)]
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = .96
	var stone := MeshInstance3D.new()
	stone.mesh = surface.commit()
	stone.material_override = mat
	object.add_child(stone)
	_add_selection(object,stone)
	return object

static func make_stepping_stone(seed_id: int) -> Node3D:
	var object := Node3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = .86*(.65 if seed_id==9 else .42)
	shape.bottom_radius = .65 if seed_id==9 else .42
	shape.height = .10
	shape.radial_segments = 8
	var stone := MeshInstance3D.new()
	stone.mesh = shape
	stone.position.y = .035
	stone.scale.x = 1.32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#b5aa93")
	mat.roughness = .95
	stone.material_override = mat
	object.add_child(stone)
	_add_selection(object,stone)
	return object

static func _add_selection(object: Node3D, stone: MeshInstance3D) -> void:
	var selection := MeshInstance3D.new()
	selection.name = "Selection"
	selection.mesh = stone.mesh
	selection.transform = stone.transform
	selection.position.y += .006
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color("#fff38d77")
	selection.material_override = overlay
	selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	object.add_child(selection)
	selection.hide()
