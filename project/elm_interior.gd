extends Node3D

const WOOD := "b68157"
const DARK_WOOD := "845a3e"
const PLASTER := "efe0ba"
const TRIM := "b89b71"
const LINEN := "f2e7ce"
const MOSS := "829d85"
const DESK_SHIFT := .56
const CHAIR_POSITION := Vector3(2.72,.02,-.67+DESK_SHIFT)
const CHAIR_SEAT_HEIGHT := .415
var world
var sketches: Dictionary = {}
var pendant_light: OmniLight3D
var pendant_glass: StandardMaterial3D
var cooking_pot: Node3D
var desk_drawer: MeshInstance3D

func setup(owner_world) -> void:
	world = owner_world
	_build_shell()
	_build_bed()
	_build_bookshelf()
	_build_kitchen()
	_build_sofa()
	_build_workbench()
	_build_bathroom()
	_build_pendant()

func _block(x: float, y: float, z: float, w: float, h: float, d: float, color: String) -> MeshInstance3D:
	return world._box(Vector3(x,y,z),Vector3(w,h,d),color,self)

func _round(x: float, y: float, z: float, radius: float, height: float, color: String) -> void:
	world._pole(Vector3(x,y,z),radius,height,color,self)

func _build_shell() -> void:
	_block(0,-.07,0,8.16,.13,6.09,DARK_WOOD)
	var floor_colors := ["c58c61","cb9569","bb8259","ce986c","c38b64"]
	for x in range(18):
		for z in range(3):
			var seam := .23*((x%3)-1)
			var edges := [-3.0,-1.08+seam,.89-seam,3.0]
			var a: float = edges[z]
			var b: float = edges[z+1]
			_block(-3.78+.445*x,-.035,(a+b)/2,.433,.11,b-a-.019,floor_colors[(x+z*3)%5])
	_block(0,.9,-3.05,8.16,1.8,.14,PLASTER)
	_block(-4,.68,0,.14,1.36,6.03,PLASTER)
	_block(4,.38,0,.14,.76,6.03,PLASTER)
	_block(-2.34,.21,3.04,3.45,.42,.14,PLASTER)
	_block(2.36,.21,3.04,3.40,.42,.14,PLASTER)
	_block(0,1.80,-3.05,8.21,.10,.22,DARK_WOOD)
	_block(-4,1.36,0,.22,.10,6.13,DARK_WOOD)
	_block(4,.76,0,.22,.10,6.13,DARK_WOOD)
	_block(0,.055,3.13,1.28,.12,.38,WOOD)
	for x in [-.66,.66]: _block(x,.25,3.04,.09,.52,.16,DARK_WOOD)
	# Glazed windows and muted shutters.
	_window(Vector3(-3.91,.83,-1.10),PI/2)
	_window(Vector3(3.91,.65,.57),-PI/2)

func _window(point: Vector3, yaw: float) -> void:
	var sash := Node3D.new()
	add_child(sash)
	sash.position = point
	sash.rotation.y = yaw
	world._box(Vector3.ZERO,Vector3(.96,.73,.10),DARK_WOOD,sash)
	world._box(Vector3(0,0,.06),Vector3(.79,.58,.04),"b9d3c9",sash)
	for x in [-.59,.59]:
		world._box(Vector3(x,0,.01),Vector3(.19,.74,.06),MOSS,sash)
	world._box(Vector3(0,0,.095),Vector3(.055,.59,.035),LINEN,sash)
	world._box(Vector3(0,0,.095),Vector3(.79,.055,.035),LINEN,sash)

func _build_bed() -> void:
	_block(-3.06,.25,-1.58,1.28,.33,2.08,WOOD)
	for x in [-3.66,-2.46]:
		for z in [-2.55,-.62]:
			_block(x,.28,z,.11,.56,.12,DARK_WOOD)
	_block(-3.06,.59,-2.55,1.30,.54,.14,WOOD)
	_block(-3.06,.47,-1.58,1.13,.20,1.88,LINEN)
	_block(-3.06,.61,-2.18,.81,.17,.39,"fff6df").rotation.z = -.06
	_block(-3.06,.60,-1.30,1.15,.12,1.25,"9eac88")
	_block(-3.06,.61,-.78,1.15,.14,.18,MOSS)
	_block(-1.98,.27,-2.47,.62,.53,.61,WOOD)
	_block(-1.98,.55,-2.47,.67,.085,.66,"cf9d70")
	_block(-1.98,.34,-2.15,.22,.044,.05,DARK_WOOD)
	_block(-1.98,.628,-2.47,.35,.073,.24,"668478")
	_block(-2.06,.69,-2.47,.11,.06,.26,"4d6158")
	for z in [-2.53,-2.46,-2.39]:
		_block(-1.91,.67,z,.045,.022,.035,"e4d4ab")

func _build_bookshelf() -> void:
	for y in [.91,1.29]:
		_block(-.83,y,-2.77,1.27,.074,.39,"a47550")
		for x in [-1.32,-.34]: _block(x,y-.14,-2.84,.09,.24,.19,DARK_WOOD)
		for i in range(5):
			var height: float = [.19,.25,.22,.27,.18][i]
			var color: String = ["9e6657","738e78","6d899a","bc9254","967989"][i]
			_block(-1.29+i*.225,y+.045+height/2,-2.75,.146,height,.24,color)

	# The gift stands at the end of the upper shelf.
	_block(-.23,1.49,-2.75,.085,.31,.24,"728379")
	_block(-.23,1.57,-2.625,.068,.025,.014,"e6d3a5")

func _build_kitchen() -> void:
	for x in [1.02,1.95]:
		_block(x,.39,-2.50,.91,.76,.77,WOOD)
	_block(3.16,.39,-2.50,1.49,.76,.77,WOOD)
	for x in [1.02,1.95,2.81,3.53]:
		_block(x,.43,-2.10,.68,.43,.04,"c99a6c")
		_block(x,.57,-2.065,.20,.047,.05,DARK_WOOD)
	_block(2.23,.80,-2.49,3.40,.10,.86,"c79b76")
	_block(1.03,.87,-2.50,.79,.055,.68,"6a635a")
	for x in [.86,1.22]:
		_round(x,.913,-2.50,.13,.05,"3c3835")
		_round(x,.944,-2.50,.077,.013,"918479")
	_block(3.38,.864,-2.49,.68,.052,.58,"b7ada0")
	_block(3.38,.893,-2.49,.53,.013,.43,"756f66")
	_round(3.38,.904,-2.49,.05,.012,"aaa59b")
	_round(3.38,.98,-2.77,.045,.22,"a7a79a")
	_block(3.38,1.074,-2.69,.075,.062,.18,"a7a79a")
	_block(1.02,1.66,-2.80,.73,.20,.43,TRIM)
	_block(1.02,1.87,-2.88,.42,.24,.29,DARK_WOOD)
	cooking_pot = Node3D.new()
	add_child(cooking_pot)
	cooking_pot.position = Vector3(.86,1.0,-2.50)
	world._pole(Vector3.ZERO,.14,.13,"637c72",cooking_pot)
	world._pole(Vector3(0,.073,0),.134,.025,"859b86",cooking_pot)
	world._box(Vector3(0,.101,0),Vector3(.085,.035,.055),"59483a",cooking_pot)
	world._box(Vector3(.15,.014,0),Vector3(.10,.035,.055),"59483a",cooking_pot)
	cooking_pot.hide()

func _build_sofa() -> void:
	_block(2.84,.022,1.76,2.03,.035,2.05,"d8b49b")
	for x in [1.89,3.80]: _block(x,.045,1.76,.075,.019,1.96,"ab8275")
	for z in [.81,1.09,2.40,2.65]: _block(2.83,.044,z,1.91,.018,.052,"e7c4aa")
	_block(3.50,.24,1.77,.96,.29,1.83,DARK_WOOD)
	_block(3.84,.57,1.77,.21,.79,1.90,"c88d5f")
	for z in [1.33,2.20]:
		_block(3.44,.47,z,.73,.23,.79,"dca674")
		_block(3.72,.70,z,.27,.45,.78,"e0a773").rotation.z = -.10
	for z in [.85,2.69]: _block(3.49,.52,z,.95,.41,.20,"c78959")
	_round(2.09,.27,1.92,.09,.46,DARK_WOOD)
	_round(2.09,.49,1.92,.43,.10,"c28b59")
	_round(2.05,.555,1.91,.13,.026,LINEN)
	_round(2.05,.615,1.91,.085,.10,MOSS)

func _build_workbench() -> void:
	for x in [3.12,3.71]:
		for z in [-1.23,-.14]:
			_block(x,.39,z+DESK_SHIFT,.12,.74,.12,DARK_WOOD)
	_block(3.42,.80,-.68+DESK_SHIFT,.88,.13,1.36,WOOD)
	desk_drawer = _block(3.07,.69,-.67+DESK_SHIFT,.34,.15,.73,"a77954")
	world._box(Vector3(-.18,0,0),Vector3(.035,.04,.19),DARK_WOOD,desk_drawer)
	var chair: Node3D = world._load_oak_chair()
	if chair != null:
		chair.name = "OakDeskChair"
		add_child(chair)
		chair.position = CHAIR_POSITION
		chair.rotation.y = PI/2
		var room_scale := global_basis.get_scale()
		chair.scale = Vector3(1.0/room_scale.z,1.0,1.0/room_scale.x)
	_block(3.41,.882,-1.14+DESK_SHIFT,.53,.036,.18,"c9a972").rotation.y = .11
	_block(3.21,.889,-.22+DESK_SHIFT,.07,.049,.25,"84705b").rotation.y = -.27
	for id in ["sketch_bench","sketch_planter"]:
		var sheet := Node3D.new()
		add_child(sheet)
		sheet.position = Vector3(3.40,.878,-.64+DESK_SHIFT)
		world._box(Vector3.ZERO,Vector3(.52,.018,.62),"d1ded1",sheet)
		if id=="sketch_bench":
			for z in [-.14,-.05,.04]:
				world._box(Vector3(0,.012,z),Vector3(.36,.008,.017),"536d63",sheet)
			for x in [-.15,.15]:
				world._box(Vector3(x,.012,.10),Vector3(.018,.008,.16),"536d63",sheet)
		else:
			for z in [-.16,.16]:
				world._box(Vector3(0,.012,z),Vector3(.35,.008,.017),"536d63",sheet)
			for x in [-.17,.17]:
				world._box(Vector3(x,.012,0),Vector3(.017,.008,.32),"536d63",sheet)
			world._box(Vector3(0,.012,0),Vector3(.017,.008,.28),"536d63",sheet)
		sketches[id] = sheet
		sheet.hide()

func show_sketch(id: String) -> void:
	for key in sketches:
		sketches[key].visible = key==id

func set_desk_drawer(amount: float) -> void:
	desk_drawer.position.x = 3.07-.22*amount

func _build_bathroom() -> void:
	for x in range(6):
		for z in range(5):
			_block(-3.72+x*.47,.035,.70+z*.47,.45,.035,.45,"cbd2bb" if (x+z)%2==0 else "bbc9b6")
	_block(-2.63,.40,.49,2.73,.80,.13,PLASTER)
	_block(-1.23,.40,2.39,.13,.80,1.21,PLASTER)
	_block(-3.33,.24,1.76,.95,.41,1.65,"b78b68")
	_block(-3.33,.46,1.76,1.02,.11,1.71,LINEN)
	_block(-3.33,.524,1.76,.78,.027,1.46,"92b3af")
	for x in [-3.78,-2.88]: _block(x,.55,1.76,.10,.10,1.62,LINEN)
	for z in [1.0,2.52]: _block(-3.33,.55,z,1.00,.10,.11,LINEN)
	_round(-3.34,.59,1.10,.045,.18,"a5a699")
	_round(-1.81,.25,2.04,.28,.41,LINEN)
	_round(-1.81,.48,2.04,.42,.095,"fff5de")
	_round(-1.81,.535,2.04,.30,.018,"a7b9af")
	_block(-1.81,.50,2.57,.70,.70,.28,LINEN)

func _build_pendant() -> void:
	# A short exposed ceiling beam holds the pendant in the cutaway.
	_block(.77,1.76,-2.80,.16,.20,.36,DARK_WOOD)
	_block(.77,1.83,-1.92,.14,.12,1.98,DARK_WOOD)
	_round(.77,1.67,-1.08,.019,.25,DARK_WOOD)
	var shade := CylinderMesh.new()
	shade.top_radius = .106
	shade.bottom_radius = .23
	shade.height = .14
	shade.radial_segments = 10
	world._mesh(shade,Vector3(.77,1.51,-1.08),"859985",self)
	var glass: MeshInstance3D = world._ball(Vector3(.77,1.444,-1.08),.091,"e8d6a4",self)
	pendant_glass = glass.material_override.duplicate()
	glass.material_override = pendant_glass
	pendant_glass.emission_enabled = true
	pendant_glass.emission = Color("ffd29b")
	pendant_light = OmniLight3D.new()
	add_child(pendant_light)
	pendant_light.position = Vector3(.77,1.39,-1.08)
	pendant_light.light_color = Color("ffd19b")
	pendant_light.light_energy = .82
	pendant_light.omni_range = 4.5
	pendant_light.omni_attenuation = 1.4
	set_lamp(false)

func set_lamp(on: bool) -> void:
	pendant_light.visible = on
	pendant_glass.emission_energy_multiplier = 1.15 if on else 0.0

func show_framed_drawing(item: Dictionary) -> void:
	var frame := get_node_or_null("FramedDrawing") as MeshInstance3D
	if item.is_empty():
		if frame!=null: frame.hide()
		return
	if frame==null:
		_block(1.07,1.29,-2.94,.91,.62,.10,DARK_WOOD)
		var face := QuadMesh.new()
		face.size = Vector2(.80,.51)
		frame = world._mesh(face,Vector3(1.07,1.29,-2.879),"ffffff",self)
		frame.name = "FramedDrawing"
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://elm_drawings.gd").texture(int(item.id),int(item.motif))
	frame.material_override = material
	frame.show()
