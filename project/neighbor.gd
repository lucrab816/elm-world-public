extends Node3D
# Mia's first local routine. Her fuller personality and world-building are future work.
const ID := "neighbor.mia.001"
const NAME := "米娅"
const SPEED := .48
const CAR_CLEARANCE := 1.75
const PARKED_EXIT_CLEARANCE := 1.4
const GATE := Vector2(-7.5,4.5)
const ROAD_EDGE := Vector2(-11.9,4.5)
const VISIT_SECONDS := 300.0
const HOME_SECONDS := 900.0
const PLACES := [{"id":"garden","name":"菜地旁","point":Vector2(-6,2)}, {"id":"garden2","name":"第二块菜地","point":Vector2(-6,3)}, {"id":"garden3","name":"第三块菜地","point":Vector2(-6,3.5)}, {"id":"meadow","name":"草地边","point":Vector2(-5,5)}, {"id":"trees","name":"树荫附近","point":Vector2(6.5,.5)}, {"id":"bench","name":"餐桌旁","point":Vector2(5.5,-.5)}]
const MODES := ["rest","walk","watch_car","greeting","watering","pet_rabbit","flower_visit","crossing","away"]
const EVENTS := ["arrived","walk_started","settled","watch_car","greet_started","greet_done","greet_cancelled","water_started","water_done","water_cancelled","mia_pet_started","mia_pet_done","mia_pet_cancelled","elm_flower_seen","left_yard","returned_to_yard"]
const LIMIT := 16
var world: Node3D
var body: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var watering_can: Node3D
var droplets: Node3D
var mode := "rest"
var place_id := "garden"
var destination := ""
var remaining := 10.0
var elapsed := 0.0
var visit_until := -1.0
var home_until := -1.0
var born_seconds := 0.0
var route: Array[Vector2] = []
var events: Array = []
var random := RandomNumberGenerator.new()
func setup(owner: Node3D) -> void:
	world = owner
	name = "Mia"
	set_meta("neighbor_id",ID)
	body = Node3D.new()
	add_child(body)
	world._box(Vector3(0,.76,0),Vector3(.41,.48,.27),"e6aeb9",body)
	world._ball(Vector3(0,1.17,0),.23,"dfbc9d",body)
	# A simple straw-colored hat and soft pink clothes are placeholders for final art.
	world._pole(Vector3(0,1.36,0),.29,.06,"ddc185",body)
	world._ball(Vector3(0,1.40,0),.16,"ddc185",body)
	for side in [-1,1]:
		var leg := Node3D.new()
		body.add_child(leg)
		leg.position = Vector3(side*.12,.52,0)
		world._box(Vector3(0,-.21,0),Vector3(.16,.42,.17),"7c8a6c",leg)
		world._box(Vector3(0,-.45,.05),Vector3(.18,.12,.27),"816852",leg)
		var arm := Node3D.new()
		body.add_child(arm)
		arm.position = Vector3(side*.28,.92,0)
		world._box(Vector3(0,-.18,0),Vector3(.12,.36,.14),"e6aeb9",arm)
		world._ball(Vector3(0,-.37,0),.075,"dfbc9d",arm)
		if side<0:
			left_leg = leg
			left_arm = arm
		else:
			right_leg = leg
			right_arm = arm
	watering_can = Node3D.new()
	right_arm.add_child(watering_can)
	watering_can.position = Vector3(0,-.42,.03)
	world._pole(Vector3(0,-.07,0),.14,.22,"95babc",watering_can)
	var spout = world._box(Vector3(.15,-.03,.03),Vector3(.22,.055,.06),"95babc",watering_can)
	spout.rotation.z = .32
	watering_can.visible = false
	droplets = Node3D.new()
	body.add_child(droplets)
	for i in range(5):
		world._ball(Vector3(.29,.53-i*.07,.55+i*.22),.045,"9fcdd6",droplets)
	droplets.visible = false
	random.randomize()
	visible = false
func flat() -> Vector2: return Vector2(position.x,position.z)
func _place(p: Vector2) -> void:
	position = Vector3(p.x,world._height(p.x,p.y),p.y)
func _sync_obstacle() -> void:
	world.navigation.neighbor_obstacle = flat() if visible else Vector2.INF
func _car_clear(p: Vector2) -> bool:
	if p.distance_to(Vector2(world.car.position.x,world.car.position.z))<CAR_CLEARANCE: return false
	if world.resident.mode=="drive":
		for i in range(1,world.car.trip.size()):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,world.car.trip[i-1],world.car.trip[i]))<CAR_CLEARANCE: return false
	return true
func _safe_spawn() -> Vector2:
	var grid = world.navigation.make_grid(.28,Vector2(world.car.position.x,world.car.position.z),CAR_CLEARANCE)
	var best := Vector2.INF
	var best_distance := INF
	for x in range(grid.region.size.x):
		for z in range(grid.region.size.y):
			var id := Vector2i(x,z)
			var p: Vector2 = grid.get_point_position(id)
			if not grid.is_point_solid(id) and _car_clear(p) and p.distance_squared_to(PLACES[0].point)<best_distance:
				best = p
				best_distance = p.distance_squared_to(PLACES[0].point)
	return best
func adopt(seconds: float) -> bool:
	var start := _safe_spawn()
	if not start.is_finite(): return false
	born_seconds = floorf(seconds)
	elapsed = 0
	place_id = "garden"
	destination = ""
	route.clear()
	events.clear()
	_place(start)
	mode = "watch_car" if world.resident.mode=="drive" else "rest"
	remaining = 12
	visible = true
	_note("arrived",seconds)
	_sync_obstacle()
	return true
func _note(kind: String, seconds: float, interaction_id: int = 0) -> void:
	var actual_place := "yard"
	for place in PLACES:
		if flat().distance_to(place.point)<.65:
			actual_place = place.id
			break
	var event := {"kind":kind,"seconds":floorf(seconds),"place":actual_place}
	if interaction_id>0: event["interaction_id"] = interaction_id
	events.append(event)
	while events.size()>LIMIT: events.pop_front()
func _start_next(seconds: float) -> bool:
	var start := random.randi_range(0,PLACES.size()-2)
	if world.resident.mode=="rest" and world.resident.current_location=="object.bench.001": start = PLACES.size()-1
	for offset in range(PLACES.size()):
		var place: Dictionary = PLACES[(start+offset)%PLACES.size()]
		if place.id==place_id: continue
		if place.id=="bench" and not (world.resident.mode=="rest" and world.resident.current_location=="object.bench.001"): continue
		var target: Vector2 = place.point
		if not world.navigation.clear_point(target,.28) or not _car_clear(target): continue
		var path: PackedVector2Array = world.navigation.path(flat(),target,.28,Vector2(world.car.position.x,world.car.position.z),CAR_CLEARANCE)
		if path.is_empty() or path[path.size()-1].distance_to(target)>.4: continue
		var previous := flat()
		var safe := true
		for p in path:
			if not world.navigation.safe_segment(previous,p,.28): safe = false; break
			previous = p
		if not safe: continue
		route.assign(path)
		destination = place.id
		mode = "walk"
		_note("walk_started",seconds)
		return true
	return false
func needs_visit_step(seconds: float) -> bool:
	return mode in ["away","crossing"] or destination=="exit" or (mode=="rest" and visit_until>=0 and seconds>=visit_until)

func _exit_segment_safe(from: Vector2, to: Vector2, parked: Vector2, rabbit: Vector2) -> bool:
	if parked.distance_to(Geometry2D.get_closest_point_to_segment(parked,from,to))<PARKED_EXIT_CLEARANCE: return false
	if rabbit.is_finite() and rabbit.distance_to(Geometry2D.get_closest_point_to_segment(rabbit,from,to))<.44:
		if from.distance_to(rabbit)>=.44 or (from-rabbit).dot(to-from)<0: return false
	return world.navigation.safe_segment(from,to,.28)

func _stationary_exit_path(parked: Vector2) -> PackedVector2Array:
	var grid: AStarGrid2D = world.navigation.make_grid(.28,parked,PARKED_EXIT_CLEARANCE)
	var graph := AStar2D.new()
	var width := grid.region.size.x
	var height := grid.region.size.y
	var rabbit: Vector2 = world.rabbit.flat() if world.rabbit_enabled else Vector2.INF
	var start := width*height
	var exit_cell := Vector2i((GATE-grid.offset)/grid.cell_size)
	var finish := exit_cell.y*width+exit_cell.x
	graph.add_point(start,flat())
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x,y)
			if grid.is_point_solid(cell): continue
			var point := grid.get_point_position(cell)
			if rabbit.is_finite() and point.distance_to(rabbit)<.48: continue
			graph.add_point(y*width+x,point)
	for y in range(height):
		for x in range(width):
			var id := y*width+x
			if not graph.has_point(id): continue
			var point := graph.get_point_position(id)
			if point.distance_to(flat())<=1.1 and _exit_segment_safe(flat(),point,parked,rabbit):
				graph.connect_points(start,id)
			for offset in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]:
				var other: Vector2i = Vector2i(x,y)+offset
				if not grid.region.has_point(other): continue
				var next := other.y*width+other.x
				if graph.has_point(next) and _exit_segment_safe(point,graph.get_point_position(next),parked,rabbit):
					graph.connect_points(id,next)
	return graph.get_point_path(start,finish) if graph.has_point(finish) else PackedVector2Array()

func _begin_exit(seconds: float) -> void:
	var parked := Vector2(world.car.position.x,world.car.position.z)
	var path: PackedVector2Array = world.navigation.path(flat(),GATE,.28,parked,CAR_CLEARANCE)
	if world.resident.mode!="drive":
		var rabbit: Vector2 = world.rabbit.flat() if world.rabbit_enabled else Vector2.INF
		var previous := flat()
		for point in path:
			if not _exit_segment_safe(previous,point,parked,rabbit):
				path.clear()
				break
			previous = point
		if path.is_empty() or path[-1].distance_to(GATE)>.1:
			path = _stationary_exit_path(parked)
	if path.is_empty() or path[-1].distance_to(GATE)>.1 or not _car_clear(GATE):
		remaining = 5
		return
	route.assign(path)
	destination = "exit"
	mode = "walk"
	_note("walk_started",seconds)

func _advance_road(delta: float, seconds: float) -> void:
	if mode=="away":
		if seconds<home_until or not _car_clear(GATE): return
		mode = "crossing"
		destination = "entrance"
		home_until = -1
		visible = true
	var leaving := destination=="exit"
	var target := ROAD_EDGE if leaving else GATE
	var next := flat().move_toward(target,SPEED*delta)
	if next.distance_to(target)<.001:
		next = target
	if not _car_clear(next):
		_pose(false)
		return
	_place(next)
	rotation.y = -PI/2 if leaving else PI/2
	_pose(true)
	if next==target:
		destination = ""
		if leaving:
			mode = "away"
			visible = false
			home_until = floorf(seconds)+HOME_SECONDS
			_note("left_yard",seconds)
		else:
			mode = "rest"
			remaining = 1
			visit_until = floorf(seconds)+VISIT_SECONDS
			_note("returned_to_yard",seconds)
	_sync_obstacle()

func _walk_clear_of_car(from: Vector2, next: Vector2) -> bool:
	if destination!="exit" or world.resident.mode=="drive": return _car_clear(next)
	var parked := Vector2(world.car.position.x,world.car.position.z)
	return parked.distance_to(Geometry2D.get_closest_point_to_segment(parked,from,next))>=PARKED_EXIT_CLEARANCE

func advance(delta: float, seconds: float) -> void:
	elapsed += delta
	if mode in ["away","crossing"]:
		_advance_road(delta,seconds)
		return
	if visit_until<0: visit_until = floorf(seconds)+VISIT_SECONDS
	if mode=="watch_car":
		mode = "rest"
		remaining = 3
	if mode=="walk" and not route.is_empty():
		var budget := SPEED*delta
		while budget>.000001 and not route.is_empty():
			var distance := flat().distance_to(route[0])
			var next := flat().move_toward(route[0],minf(distance,budget))
			if not _walk_clear_of_car(flat(),next) or not world.navigation.safe_segment(flat(),next,.28) or (world.rabbit_enabled and next.distance_to(world.rabbit.flat())<.44 and next.distance_to(world.rabbit.flat())<flat().distance_to(world.rabbit.flat())):
				route.clear()
				destination = ""
				mode = "rest"
				remaining = 4
				break
			var direction := next-flat()
			if direction.length()>.00001: rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.y),minf(delta*8,1))
			_place(next)
			var elm := Vector2(world.resident.position.x,world.resident.position.z)
			if destination!="exit" and world.resident.mode=="observe" and flat().distance_to(elm)<.9:
				route.clear()
				destination = ""
				mode = "rest"
				remaining = 12
				break
			budget -= minf(distance,budget)
			if distance<=.001 or next.distance_to(route[0])<.001: route.pop_front()
		if mode=="walk" and route.is_empty() and destination=="exit":
			mode = "crossing"
			visit_until = -1
		elif mode=="walk" and route.is_empty():
			place_id = destination
			destination = ""
			mode = "rest"
			remaining = random.randf_range(12,24)
			_note("settled",seconds)
		_pose(mode=="walk")
	else:
		_pose(false)
		remaining = maxf(0,remaining-delta)
		if remaining<=0:
			if seconds>=visit_until: _begin_exit(seconds)
			elif not _start_next(seconds): remaining = 5
	_sync_obstacle()
func _pose_pet_rabbit(seconds: float) -> void:
	_pose(false)
	body.position.y = -.22
	body.rotation.x = .28
	left_leg.rotation.x = -1.0
	right_leg.rotation.x = -1.0
	right_arm.rotation.x = -1.0+sin(seconds*5)*.10
	right_arm.rotation.z = -.45
func _pose_water(seconds: float) -> void:
	_pose(false)
	right_arm.rotation.x = -.8 + sin(seconds*3)*.10
	watering_can.rotation.z = -.25 + sin(seconds*3)*.10
	watering_can.visible = true
	droplets.visible = true
	droplets.position.y = sin(seconds*5)*.04
func _pose(moving: bool) -> void:
	watering_can.visible = false
	droplets.visible = false
	body.position.z = 0
	body.rotation.x = 0
	left_arm.rotation.z = 0
	right_arm.rotation.z = 0
	var swing := sin(elapsed*7)*.38 if moving else 0.0
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -swing*.7
	right_arm.rotation.x = swing*.7
	body.position.y = absf(sin(elapsed*7))*.02 if moving else 0

func description() -> String:
	if mode=="rest" and place_id=="bench": return "在餐桌旁歇一会儿"
	if mode=="away": return "回家了，过一阵再来串门"
	if destination=="exit": return "正沿小路回家"
	if mode=="crossing": return "正沿小路来串门"
	if mode=="watch_car": return "停下脚步，看小车驶过"
	if mode=="greeting": return "正和埃尔挥手打招呼"
	if mode=="watering": return "在菜地旁给植物浇水"
	if mode=="flower_visit": return "在看埃尔亲手照料的花"
	if mode=="pet_rabbit": return "轻轻摸摸德雷克"
	if mode=="walk": return "正走向"+place_name(destination)
	for place in PLACES:
		if place.id==place_id and flat().distance_to(place.point)<.65:
			return "在"+place_name(place_id)+"看看周围"
	return "在小院里停下看看周围"
static func place_name(id: String) -> String:
	for place in PLACES:
		if place.id==id: return place.name
	return "小院"
func snapshot() -> Dictionary:
	var points: Array = []
	for p in route: points.append([p.x,p.y])
	return {"version":1,"neighbor_id":ID,"born_seconds":born_seconds,"position":[position.x,position.z],"rotation_y":rotation.y,"mode":mode,"place_id":place_id,"destination":destination,"remaining":remaining,"elapsed":elapsed,"route":points,"events":events.duplicate(true),"random_state":str(random.state),"visit_until":visit_until,"home_until":home_until}
static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=1e12
static func point(value: Variant) -> bool:
	return value is Array and value.size()==2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float) and is_finite(float(value[0])) and is_finite(float(value[1])) and value[0]>=-7.5 and value[0]<=8.5 and value[1]>=-6.5 and value[1]<=7.5
static func valid_snapshot(value: Variant, now: float) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("neighbor_id")!=ID or value.get("mode") not in MODES: return false
	var road: bool = value.mode in ["away","crossing"]
	var location = value.get("position")
	if road:
		if not location is Array or location.size()!=2 or not (location[0] is float or location[0] is int) or not (location[1] is float or location[1] is int): return false
		if not is_finite(float(location[0])) or not is_equal_approx(float(location[1]),GATE.y) or location[0]<ROAD_EDGE.x-.001 or location[0]>GATE.x+.001: return false
		if value.mode=="away" and absf(location[0]-ROAD_EDGE.x)>.001: return false
	elif not point(location): return false
	var visit_end = value.get("visit_until",-1)
	var home_end = value.get("home_until",-1)
	if visit_end!=-1 and (not number(visit_end) or visit_end>now+VISIT_SECONDS): return false
	if home_end!=-1 and (not number(home_end) or home_end>now+HOME_SECONDS): return false
	if (value.mode=="away")!=(home_end>=0): return false
	if value.get("place_id") not in ["garden","garden2","garden3","meadow","trees","bench"] or value.get("destination") not in ["","garden","garden2","garden3","meadow","trees","bench","exit","entrance"]: return false
	if not number(value.get("born_seconds")) or value.born_seconds>now or not number(value.get("elapsed")) or value.elapsed>now-value.born_seconds+.01 or not number(value.get("remaining")) or value.remaining>60: return false
	if not (value.get("rotation_y") is int or value.get("rotation_y") is float) or not is_finite(float(value.rotation_y)) or absf(value.rotation_y)>1000000: return false
	if not value.get("route") is Array or value.route.size()>1000 or not value.get("random_state") is String or not value.random_state.is_valid_int(): return false
	for p in value.route:
		if not point(p): return false
	if value.mode=="walk" and (value.route.is_empty() or value.destination.is_empty()): return false
	if value.mode=="walk" and value.destination=="entrance": return false
	if value.mode=="crossing":
		if not value.route.is_empty() or value.destination not in ["entrance","exit"]: return false
	elif value.mode!="walk" and (not value.route.is_empty() or not value.destination.is_empty()): return false
	if not value.get("events") is Array or value.events.size()>LIMIT: return false
	var previous: float = value.born_seconds
	for event in value.events:
		if not event is Dictionary or event.get("kind") not in EVENTS or event.get("place") not in ["yard","garden","garden2","garden3","meadow","trees","bench"] or not number(event.get("seconds")) or event.seconds<previous or event.seconds>now: return false
		if event.kind in ["greet_started","greet_done","greet_cancelled","water_started","water_done","water_cancelled","mia_pet_started","mia_pet_done","mia_pet_cancelled"] and (not number(event.get("interaction_id")) or event.interaction_id<1 or event.interaction_id!=floor(event.interaction_id)): return false
		previous = event.seconds
	return true
func restore(value: Dictionary, now: float) -> bool:
	if not valid_snapshot(value,now): return false
	born_seconds = float(value.born_seconds)
	elapsed = float(value.elapsed)
	visit_until = float(value.get("visit_until",-1))
	home_until = float(value.get("home_until",-1))
	remaining = float(value.remaining)
	rotation.y = float(value.rotation_y)
	mode = value.mode
	place_id = value.place_id
	destination = value.destination
	events = value.events.duplicate(true)
	random.state = value.random_state.to_int()
	route.clear()
	for p in value.route: route.append(Vector2(p[0],p[1]))
	_place(Vector2(value.position[0],value.position[1]))
	# A save taken during patio chat can contain the seat rather than a walkable point.
	if mode=="rest" and flat().distance_to(Vector2(5.05,-1.74))<.05:
		var parked := Vector2(world.car.position.x,world.car.position.z)
		var grid: AStarGrid2D = world.navigation.make_grid(.28,parked,CAR_CLEARANCE)
		var exit: Vector2i = world.navigation.nearest(grid,Vector2(6,-1.5))
		if exit.x>=0: _place(grid.get_point_position(exit))
	if mode not in ["away","crossing"] and (not world.navigation.clear_point(flat(),.28) or not _car_clear(flat())):
		visible = false
		return false
	var previous := flat()
	for p in route:
		if not world.navigation.safe_segment(previous,p,.28):
			route.clear()
			destination = ""
			mode = "rest"
			remaining = 5
			break
		previous = p
	visible = mode!="away"
	_pose(mode in ["walk","crossing"])
	_sync_obstacle()
	return true
