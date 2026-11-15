extends Node3D

const PatioWood = preload("res://patio_wood.gd")
const Calendar = preload("res://world_calendar.gd")
const SEAT := Vector2(4,-2)
const SEAT_APPROACH := Vector2(3,-2)
const PLANT_CORNER := Vector2(3.56,-1.08)
const PLANT_APPROACH := Vector2(3,-.5)
const TABLE_SURFACE := .8275
const TABLE_CENTER := Vector3(0,0,1.29)
const TABLE_RADIUS := .86
const PIZZA_SIZE := 1.58
const PIZZA_OFFSET := Vector2(.04,.76)
const LANTERN_OFFSET := Vector2(-.12,1.56)
const LANTERN_BASE_WIDTH := .24
const LANTERN_BRONZE := "776044"
const LANTERN_TRIM := "a0865d"
const CHAIR_ASSET := "res://assets/a03_dining_chair.glb"
const A03_SEATED_HIP_HEIGHT := .555
const ELM_HIP_PIVOT_HEIGHT := .53
const A03_SEATED_LEG_ANGLE := -PI/2+.22
const SAGE := "89965a"
const TRIM := "a8af70"
const DROP := Vector2(5.5,-.5)
const PRICE := 10
const ORDER_AT := 30.0
const FALLBACK_AT := 18.0
const EMPTY := {"prepared":"","order_until":0.0,"order_day":0}
var state := EMPTY.duplicate()
var elm_path := PackedVector2Array()
var mia_path := PackedVector2Array()
var eating := 0.0
var serving := 0.0
var meal := ""
var box_on_table: Node3D
var table_light: OmniLight3D
var lantern_glass: StandardMaterial3D
var carried: Node3D
var world

func setup(owner_world) -> void:
	world = owner_world
	position = Vector3(SEAT.x,world._height(SEAT.x,SEAT.y),SEAT.y)
	_build_table()
	var second := Node3D.new()
	add_child(second)
	second.position = Vector3(1.05,world._height(SEAT.x+1.05,SEAT.y+.26)-position.y,.26)
	second.rotation.y = atan2(-1.05,TABLE_CENTER.z-.26)
	var document := GLTFDocument.new()
	var asset := GLTFState.new()
	var result := document.append_from_file(CHAIR_ASSET,asset)
	if result == OK:
		var chair := document.generate_scene(asset)
		PatioWood.paint_tree(chair,["909D60","DEA45F","B27A44"],["EAC583"])
		add_child(chair)
		second.add_child(chair.duplicate())
	else:
		push_error("Unable to load A03 dining chair: "+error_string(result))
	box_on_table = Node3D.new()
	add_child(box_on_table)
	box_on_table.position = Vector3(PIZZA_OFFSET.x,TABLE_SURFACE+.024,PIZZA_OFFSET.y)
	_make_pizza(box_on_table)
	box_on_table.hide()
	_build_lantern()

func _build_lantern() -> void:
	var lantern := Node3D.new()
	lantern.name = "DiningLantern"
	add_child(lantern)
	lantern.position = Vector3(LANTERN_OFFSET.x,TABLE_SURFACE,LANTERN_OFFSET.y)
	lantern.rotation.y = -.12
	_lantern_tier(lantern,.013,LANTERN_BASE_WIDTH,.22,.026,LANTERN_BRONZE)
	_lantern_tier(lantern,.038,.215,.185,.026,LANTERN_TRIM)
	var glass: MeshInstance3D = world._box(Vector3(0,.147,0),Vector3(.161,.205,.161),"d4aa62",lantern)
	lantern_glass = glass.material_override.duplicate()
	lantern_glass.emission_enabled = true
	lantern_glass.emission = Color("ffc36b")
	glass.material_override = lantern_glass
	for x in [-.084,.084]:
		for z in [-.084,.084]:
			world._box(Vector3(x,.147,z),Vector3(.020,.209,.020),LANTERN_BRONZE,lantern)
	for side in [-1,1]:
		world._box(Vector3(0,.146,side*.083),Vector3(.005,.058,.004),LANTERN_TRIM,lantern)
		world._box(Vector3(side*.083,.146,0),Vector3(.004,.058,.005),LANTERN_TRIM,lantern)
	_lantern_tier(lantern,.252,.219,.225,.023,LANTERN_TRIM)
	_lantern_tier(lantern,.299,.210,.084,.074,LANTERN_BRONZE)
	_lantern_tier(lantern,.350,.095,.076,.026,LANTERN_TRIM)
	_build_lantern_handle(lantern)
	table_light = OmniLight3D.new()
	table_light.name = "DiningLanternLight"
	lantern.add_child(table_light)
	table_light.position = Vector3(0,.40,0)
	# The decorative casing should not block the lantern's own light.
	for part in lantern.get_children():
		if part is GeometryInstance3D:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	table_light.shadow_enabled = true
	table_light.light_color = Color("ffc583")
	table_light.light_energy = 1.02
	table_light.omni_range = 2.8
	table_light.omni_attenuation = 1.7
	set_lantern(false)

func _lantern_tier(parent: Node3D, y: float, bottom: float, top: float, height: float, color: String) -> void:
	var shape := CylinderMesh.new()
	shape.radial_segments = 4
	shape.rings = 0
	shape.bottom_radius = bottom/sqrt(2.0)
	shape.top_radius = top/sqrt(2.0)
	shape.height = height
	var tier: MeshInstance3D = world._mesh(shape,Vector3(0,y,0),color,parent)
	tier.rotation.y = PI/4

func _build_lantern_handle(parent: Node3D) -> void:
	var arc := PackedVector3Array()
	for step in range(13):
		var angle := PI*step/12
		arc.append(Vector3(cos(angle)*.051,.358+sin(angle)*.070,0))
	for i in range(arc.size()-1):
		var a := arc[i]
		var b := arc[i+1]
		var rod := CylinderMesh.new()
		rod.top_radius = .009
		rod.bottom_radius = .009
		rod.height = a.distance_to(b)+.004
		rod.radial_segments = 6
		rod.rings = 0
		var piece: MeshInstance3D = world._mesh(rod,(a+b)*.5,LANTERN_BRONZE,parent)
		piece.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func set_lantern(lit: bool) -> void:
	table_light.visible = lit
	lantern_glass.emission_energy_multiplier = 1.35 if lit else 0.0

func _build_table() -> void:
	var table := Node3D.new()
	add_child(table)
	table.position = TABLE_CENTER
	var ring := PackedVector2Array()
	for i in range(32):
		var angle := TAU*i/32.0
		ring.append(Vector2(cos(angle),sin(angle))*TABLE_RADIUS)
	var board_colors := ["d99f55","dfa75c","e4ae61","dca359","e1a85b"]
	var board_count := board_colors.size()
	for i in range(board_count):
		var left := -TABLE_RADIUS+i*TABLE_RADIUS*2/board_count+.005
		var right := left+TABLE_RADIUS*2/board_count-.01
		var strip := PackedVector2Array([Vector2(-1,left),Vector2(1,left),Vector2(1,right),Vector2(-1,right)])
		for board in Geometry2D.intersect_polygons(ring,strip):
			_prism(table,board,TABLE_SURFACE-.115,TABLE_SURFACE,board_colors[i],true)
	var sections := [[.025,.22],[.19,.22],[.23,.27],[.29,.27],[.33,.21],[.42,.24],[.51,.19],[.61,.15],[.65,.21],[.70,.23],[.735,.31]]
	for i in range(sections.size()-1):
		var bottom: Array = sections[i]
		var top: Array = sections[i+1]
		var shape := CylinderMesh.new()
		shape.bottom_radius = bottom[1]
		shape.top_radius = top[1]
		shape.height = top[0]-bottom[0]
		shape.radial_segments = 12
		shape.rings = 0
		var piece: MeshInstance3D = world._mesh(shape,Vector3(0,(top[0]+bottom[0])*.5,0),SAGE,table)
		piece.material_override = PatioWood.finish(piece,1,Color(SAGE if i%3 else TRIM),true)
	var foot := PackedVector2Array([Vector2(.13,.055),Vector2(.20,.25),Vector2(.31,.255),Vector2(.43,.225),Vector2(.51,.15),Vector2(.59,.10),Vector2(.61,.03),Vector2(.48,.03),Vector2(.43,.08),Vector2(.34,.11),Vector2(.26,.07)])
	for i in range(4):
		var support := Node3D.new()
		table.add_child(support)
		support.rotation.y = PI/4+i*PI/2
		_prism(support,foot,-.10,.10,SAGE,false)
		for side in [-1,1]:
			var pin: MeshInstance3D = world._ball(Vector3(.33,.165,side*.101),.026,"dcbc77",support)
			pin.scale.z = .37

func _prism(parent: Node3D, profile: PackedVector2Array, low: float, high: float, color: String, horizontal: bool) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := profile.duplicate()
	if Geometry2D.is_polygon_clockwise(outline): outline.reverse()
	var vertices := PackedVector3Array()
	for level in [low,high]:
		for p in outline:
			vertices.append(Vector3(p.x,level,p.y) if horizontal else Vector3(p.x,p.y,level))
	var count := outline.size()
	var triangles := Geometry2D.triangulate_polygon(outline)
	var indices := PackedInt32Array()
	for i in range(0,triangles.size(),3):
		indices.append_array([triangles[i],triangles[i+2],triangles[i+1],count+triangles[i],count+triangles[i+1],count+triangles[i+2]])
	for i in range(count):
		var j := (i+1)%count
		indices.append_array([i,j,i+count,j,j+count,i+count])
	for i in range(0,indices.size(),3):
		surface.set_smooth_group(-1)
		surface.add_vertex(vertices[indices[i]])
		surface.add_vertex(vertices[indices[i+1 if horizontal else i+2]])
		surface.add_vertex(vertices[indices[i+2 if horizontal else i+1]])
	surface.generate_normals()
	var piece: MeshInstance3D = world._mesh(surface.commit(),Vector3.ZERO,color,parent)
	piece.material_override = PatioWood.finish(piece,0,Color(color),horizontal)

func _make_pizza(parent: Node3D) -> void:
	parent.scale = Vector3(PIZZA_SIZE,1,PIZZA_SIZE)
	world._box(Vector3.ZERO,Vector3(.34,.048,.34),"d6b38d",parent)
	world._pole(Vector3(0,.037,0),.139,.028,"d58b48",parent)
	world._pole(Vector3(0,.056,0),.119,.014,"ebbf66",parent)
	for offset in [Vector3(.05,.067,.04),Vector3(-.05,.067,-.04),Vector3(-.037,.067,.05)]:
		world._pole(offset,.025,.008,"a75644",parent)

func _exit_to(point: Vector2, destination: Vector2) -> PackedVector2Array:
	var parked := Vector2(world.car.position.x,world.car.position.z)
	var route: PackedVector2Array = world.navigation.path(point,destination,.28,parked,1.75)
	if route.is_empty() or route[-1]!=destination or not world.navigation.safe_segment(point,route[0],.28):
		return PackedVector2Array()
	return route

func can_order(now: float) -> bool:
	var needs = world.needs
	return needs.satiety<=ORDER_AT and needs.satiety>FALLBACK_AT and needs.hearts>=PRICE and needs.food==0 and needs.garden_food==0 and (not world._has_potato_harvest() or world.hobbies.used>=3) and state.prepared=="" and state.order_until==0 and state.order_day!=Calendar.day_at(now) and world.neighbor_enabled and not _exit_to(world.neighbor.GATE,DROP).is_empty()

func prefers_delivery(now: float) -> bool:
	# Keep the decision stable while hunger falls through this window.
	var key := "%s/pizza/%d"%[world.state_template.get("world_id",""),Calendar.day_at(now)]
	return key.sha256_text().substr(0,4).hex_to_int()%4!=0

func order(now: float) -> void:
	if can_order(now):
		state.order_day = Calendar.day_at(now)
		state.order_until = floorf(now)+150
		if world.journal_enabled: world.journal.record("home.phone","床头电话","pizza_ordered",now)

func advance_delivery(delta: float, now: float) -> bool:
	if carried!=null: carried.hide()
	if state.order_until<=0: return false
	var mia = world.neighbor
	if now>=state.order_until or world.needs.hearts<PRICE:
		state.order_until = 0.0
		mia_path.clear()
		serving = 0
		return false
	if mia.mode=="away":
		mia.home_until = minf(mia.home_until,now)
		return false
	if mia.mode!="rest" or not mia.visible or world.resident.mode=="drive":
		mia_path.clear()
		serving = 0
		return false
	if mia.flat().distance_to(DROP)>.03:
		if mia_path.is_empty(): mia_path = _exit_to(mia.flat(),DROP)
		if mia_path.is_empty(): return false
		var point: Vector2 = mia.flat()
		var next := point.move_toward(mia_path[0],delta*.9)
		if not mia._car_clear(next):
			mia_path.clear()
			return false
		var movement := next-point
		if movement.length_squared()>.000001: mia.rotation.y = atan2(movement.x,movement.y)
		mia._place(next)
		mia.elapsed += delta
		mia._pose(true)
		mia._sync_obstacle()
		if next.distance_to(mia_path[0])<.001: mia_path.remove_at(0)
	else:
		serving += delta
		mia._pose(false)
		mia.rotation.y = atan2(SEAT.x-DROP.x,SEAT.y+1.29-DROP.y)
		if serving>=2.0:
			state.order_until = 0.0
			state.prepared = "pizza"
			world.needs.hearts -= PRICE
			serving = 0
			mia.remaining = 1
			if world.journal_enabled: world.journal.record("yard.dining","户外餐桌","pizza_delivered",now)
			return false
	if carried==null:
		carried = Node3D.new()
		mia.right_arm.add_child(carried)
		carried.position = Vector3(0,-.36,.20)
		_make_pizza(carried)
	mia.right_arm.rotation.x = -.8 if serving==0 else lerpf(-.8,-1.25,serving/2)
	carried.show()
	return true

func advance_meal(delta: float, now: float) -> bool:
	var elm = world.resident
	var needs = world.needs
	if needs==null or not world.elm_gardening._safe(world,true,true): return false
	if meal.is_empty():
		if state.prepared!="":
			meal = state.prepared
		elif world.hobbies.job.is_empty() and needs.wants_meal() and state.order_until==0:
			if needs.food>0 and (needs.garden_food==0 and (not world._has_potato_harvest() or world.hobbies.used>=3) or needs.satiety<=FALLBACK_AT): meal = "pantry"
			elif needs.satiety<=FALLBACK_AT: meal = "basic"
		if meal.is_empty(): return false
		eating = 16
	var here := Vector2(elm.position.x,elm.position.z)
	if here.distance_to(SEAT)>.02:
		if elm_path.is_empty():
			var parked := Vector2(world.car.position.x,world.car.position.z)
			if here.distance_to(SEAT_APPROACH)<.03 or (absf(here.y-SEAT.y)<.03 and here.x>SEAT_APPROACH.x and here.x<=SEAT.x):
				if SEAT.distance_to(parked)>=1.75:
					elm.position.x = SEAT.x
					elm.position.z = SEAT.y
					elm._sync_height()
					return true
			else:
				elm_path = _exit_to(here,SEAT_APPROACH)
		if elm_path.is_empty() or not world.navigation.safe_segment(here,elm_path[0],.28) or not world.neighbor._car_clear(elm_path[0]):
			elm_path.clear()
			meal = ""
			return false
		var next := here.move_toward(elm_path[0],delta*1.05)
		var movement := next-here
		if movement.length_squared()>.000001: elm.rotation.y = atan2(movement.x,movement.y)
		elm.position.x = next.x
		elm.position.z = next.y
		elm._sync_height()
		elm._walk_pose_step(delta)
		elm._emit_activity("端着餐点走向户外餐桌")
		if next.distance_to(elm_path[0])<.001: elm_path.remove_at(0)
		return true
	elm._pose_stand()
	elm.rotation.y = 0
	elm.model.position.y = A03_SEATED_HIP_HEIGHT-ELM_HIP_PIVOT_HEIGHT
	elm.left_leg.rotation.x = A03_SEATED_LEG_ANGLE
	elm.right_leg.rotation.x = A03_SEATED_LEG_ANGLE
	elm.right_arm.rotation.x = -.68+sin(eating*3)*.32
	elm.meal_bowl.visible = meal!="pizza"
	elm._emit_activity("坐在户外餐桌吃披萨" if meal=="pizza" else "坐在户外餐桌吃饭")
	eating = maxf(0,eating-delta)
	if eating==0:
		match meal:
			"pizza": needs.finish_prepared_meal("吃完米娅送来的披萨")
			"potato": needs.finish_roasted_meal()
			"vegetable":
				if needs.begin_meal(): needs.finish_meal()
			_:
				if needs.begin_meal(false): needs.finish_meal()
		if world.journal_enabled:
			var kind: String = {"pizza":"pizza_eaten","potato":"potato_roasted","vegetable":"vegetable_cooked"}.get(meal,"meal_done")
			world.journal.record("yard.dining","户外餐桌",kind,now)
		state.prepared = ""
		meal = ""
		elm._pose_stand()
		elm.position.x = SEAT_APPROACH.x
		elm.position.z = SEAT_APPROACH.y
		elm._sync_height()
		elm.remaining = 2
	return true

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("prepared") not in ["","pizza","potato","vegetable"]: return false
	for key in ["order_until","order_day"]:
		var n = value.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>1e12 or n!=floor(n): return false
	return value.order_until==0 or (value.prepared=="" and value.order_day>0)
