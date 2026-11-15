extends Node3D
# Local navigation; selected routes and parking survive saves without rerolling.
const ForestLand = preload("res://forest_land.gd")
const STOP_DURATION := 26.0
var stop_index := -1
var stop_elapsed := 0.0
const SPEED := .65 # Twice the old ellipse's average ground speed (~.325 units/s).
var trip: Array[Vector2] = []
var forest_trip := false
var trip_distance := 0.0
var travelled := 0.0
var parked := Vector2(2,4.8)
var heading := 0.0
var random := RandomNumberGenerator.new()
var world: Node3D
var wheels: Array[Node3D] = []
func setup(owner_world: Node3D) -> void:
	world = owner_world
	name = "LittleCar"
	set_meta("object_id","object.car.001")
	world._box(Vector3(0,.18,0),Vector3(.88,.16,1.30),"83b6a0",self)
	world._box(Vector3(0,.32,-.48),Vector3(.88,.30,.28),"a5cbbb",self)
	for side in [-1,1]:
		world._box(Vector3(side*.42,.38,0),Vector3(.13,.30,1.05),"a5cbbb",self)
		for z in [-.43,.43]:
			var tire = world._pole(Vector3(side*.49,.20,z),.20,.13,"4e5a54",self)
			tire.rotation.z = PI/2
			wheels.append(tire)
			var hub = world._pole(Vector3(side*.57,.20,z),.09,.015,"f3dfad",self)
			hub.rotation.z = PI/2
	world._box(Vector3(0,.29,.55),Vector3(.88,.28,.32),"a5cbbb",self)
	world._box(Vector3(0,.17,.77),Vector3(.94,.10,.10),"f3dfad",self)
	world._box(Vector3(0,.51,-.08),Vector3(.57,.10,.48),"ddbd85",self)
	world._box(Vector3(0,.68,-.33),Vector3(.57,.32,.10),"ddbd85",self)
	for x in [-.29,.29]:
		world._ball(Vector3(x,.40,.74),.075,"fff0ba",self)
	var ring := TorusMesh.new()
	ring.inner_radius = .13
	ring.outer_radius = .17
	ring.rings = 12
	ring.ring_segments = 6
	var steering = world._mesh(ring,Vector3(0,.74,.32),"586b5b",self)
	steering.rotation.x = .65
	world._box(Vector3(0,.56,.34),Vector3(.045,.30,.045),"586b5b",self)
	random.randomize()
	_place(parked,0)
func _place(point: Vector2, yaw: float) -> void:
	position = Vector3(point.x,world._height(point.x,point.y)+.035,point.y)
	rotation.y = yaw
	for wheel in wheels:
		wheel.rotation = Vector3(0,0,PI/2)
		wheel.rotate_object_local(Vector3.UP,travelled/.2)
func _start_forest_trip() -> bool:
	var gate: Vector2 = ForestLand.DRIVE_TRAIL.front()
	var path: PackedVector2Array = world.navigation.path(parked,gate,.98)
	if path.is_empty() or path[-1].distance_to(gate)>.01: return false
	var points: Array[Vector2] = [parked]
	for point in path:
		if not world.navigation.safe_segment(points.back(),point,.98): return false
		points.append(point)
	for point in ForestLand.DRIVE_TRAIL.slice(1):
		for walker in [world.navigation.neighbor_obstacle,world.navigation.pet_obstacle]:
			if walker.is_finite() and walker.distance_to(Geometry2D.get_closest_point_to_segment(walker,points.back(),point))<1.8:
				return false
		points.append(point)
	# Pick a turnaround and optional side trails on each trip.
	var outward: Array[Vector2] = [gate]
	var turnaround := random.randi_range(5,ForestLand.DRIVE_TRAIL.size()-1)
	for p in ForestLand.DRIVE_TRAIL.slice(1,turnaround+1): outward.append(p)
	points.resize(points.size()-ForestLand.DRIVE_TRAIL.size()+1)
	var parked_stop := -1
	for loop in ForestLand.DRIVE_LOOPS:
		var first: int = outward.find(loop.front())
		var last: int = outward.find(loop.back())
		if first>=0 and last>first and random.randf()<.75:
			outward.assign(outward.slice(0,first)+loop+outward.slice(last+1))
	points.append_array(outward.slice(1))
	var return_start := points.size()-outward.size()+1
	if random.randf()<.72:
		var stops: Array[int] = []
		for i in range(return_start,points.size()):
			if ForestLand.near_drive_loop(points[i],.01) and points[i] not in ForestLand.DRIVE_TRAIL: stops.append(i)
		if not stops.is_empty(): parked_stop = stops[random.randi_range(0,stops.size()-1)]
	var destination: Vector2 = outward.back()
	var main_index: int = ForestLand.DRIVE_TRAIL.find(destination)
	for i in range(main_index-1,-1,-1): points.append(ForestLand.DRIVE_TRAIL[i])
	for i in range(return_start-2,-1,-1): points.append(points[i])
	_set_trip(points,true)
	stop_index = parked_stop
	return true

func start_trip() -> bool:
	if random.randi_range(0,3)==0 and _start_forest_trip(): return true
	var grid: AStarGrid2D = world.navigation.make_grid(.98)
	var start: Vector2i = world.navigation.nearest(grid,parked)
	var cursor := start
	var chosen: Array[Vector2] = [parked]
	var parking_verified := false
	# Pick several reachable destinations across the yard, ending at a new parking point.
	for stop in range(3):
		var choices: Array[Vector2i] = []
		for x in range(grid.region.size.x):
			for z in range(grid.region.size.y):
				var id := Vector2i(x,z)
				if not grid.is_point_solid(id) and grid.get_point_position(cursor).distance_to(grid.get_point_position(id))>4:
					choices.append(id)
		for attempt in range(50):
			if choices.is_empty():
				break
			var target := choices[random.randi_range(0,choices.size()-1)]
			if stop==2:
				var parking_point := grid.get_point_position(target)
				var boarding_point: Vector2 = world.navigation.boarding(parking_point)
				var can_leave := true
				for destination in [Vector2(-2.5,1.75),Vector2(-6,2)]:
					if world.navigation.path(boarding_point,destination,.28,parking_point).is_empty():
						can_leave = false
				if not can_leave:
					continue
			var segment: PackedVector2Array = grid.get_point_path(cursor,target)
			if segment.is_empty():
				continue
			var valid := true
			var previous_size := chosen.size()
			for point in segment:
				if not world.navigation.safe_segment(chosen.back(),point,.98):
					valid = false
					break
				chosen.append(point)
			if valid:
				cursor = target
				if stop==2:
					parking_verified = true
				break
			chosen.resize(previous_size)
	# Every accepted point must have safe connecting geometry.
	if chosen.size()<2 or not parking_verified:
		return false
	_set_trip(chosen,false)
	return trip_distance>1

func _set_trip(points: Array[Vector2], in_forest: bool) -> void:
	stop_index = -1
	stop_elapsed = 0
	trip.assign(points)
	forest_trip = in_forest
	trip_distance = 0
	for i in range(1,trip.size()):
		trip_distance += trip[i-1].distance_to(trip[i])
	travelled = 0
func stopping() -> bool:
	return stop_index>=0 and travelled+0.00001>=_stop_distance() and stop_elapsed<STOP_DURATION

func _stop_distance() -> float:
	var distance := 0.0
	for i in range(1,stop_index+1): distance += trip[i-1].distance_to(trip[i])
	return distance

func stop_walk_position() -> Vector2:
	var stop := trip[stop_index]
	var direction := (trip[stop_index+1]-stop).normalized()
	var progress := stop_elapsed/STOP_DURATION
	var step_out := minf(1.0, minf(progress,1-progress)*6.0)
	return stop+direction*step_out*2.1

func advance_trip(delta: float) -> bool:
	# Once Elm has stepped out, finish the walk back to the car.
	if world.shelter_from_rain and stop_index>=0 and travelled+0.00001<_stop_distance():
		stop_index = -1
		stop_elapsed = 0
	if stop_index>=0 and stop_elapsed<STOP_DURATION:
		var stop_distance := _stop_distance()
		if travelled+0.00001>=stop_distance:
			stop_elapsed = minf(STOP_DURATION,stop_elapsed+delta)
			return false
		if travelled+SPEED*delta>=stop_distance:
			travelled = stop_distance
			apply_distance()
			return false
	travelled = minf(trip_distance,travelled+SPEED*delta)
	apply_distance()
	if travelled>=trip_distance:
		parked = trip.back()
		heading = rotation.y
		return true
	return false
func apply_distance() -> void:
	var left := travelled
	for i in range(1,trip.size()):
		var length := trip[i-1].distance_to(trip[i])
		if length<=.00001:
			continue
		if left<=length or i==trip.size()-1:
			var direction := trip[i]-trip[i-1]
			_place(trip[i-1].lerp(trip[i],clampf(left/length,0,1)),atan2(direction.x,direction.y))
			return
		left -= length
func snapshot() -> Dictionary:
	var points: Array = []
	for p in trip:
		points.append([p.x,p.y])
	return {"version":1,"forest_trip":forest_trip,"parked":[parked.x,parked.y],"heading":heading,"trip":points,"travelled":travelled,"stop_index":stop_index,"stop_elapsed":stop_elapsed,"random_state":str(random.state)}
static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("parked") is Array or value.parked.size()!=2:
		return false
	if not value.get("trip") is Array or value.trip.size()>1000 or not value.get("random_state") is String or not value.random_state.is_valid_int():
		return false
	if not value.get("forest_trip",false) is bool: return false
	for p in [value.parked]+value.trip:
		if not p is Array or p.size()!=2:
			return false
		for n in p:
			if not (n is float or n is int) or not is_finite(float(n)) :
				return false
		if (absf(p[0])>9 or absf(p[1])>9) and (not value.get("forest_trip",false) or not ForestLand.drive_vertex(Vector2(p[0],p[1]))): return false
	if absf(value.parked[0])>9 or absf(value.parked[1])>9: return false
	if value.get("forest_trip",false) and (value.trip.size()<3 or value.trip.front()!=value.parked or value.trip.back()!=value.parked): return false
	for key in ["heading","travelled"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])):
			return false
	var saved_stop = value.get("stop_index",-1)
	var pause = value.get("stop_elapsed",0)
	if not (saved_stop is int or saved_stop is float) or not is_finite(float(saved_stop)) or saved_stop!=floor(saved_stop) or saved_stop< -1 or saved_stop>=maxi(0,value.trip.size()-1): return false
	if not (pause is int or pause is float) or not is_finite(float(pause)) or pause<0 or pause>STOP_DURATION: return false
	if saved_stop>=0 and (not value.get("forest_trip",false) or saved_stop==0 or not ForestLand.near_drive_loop(Vector2(value.trip[int(saved_stop)][0],value.trip[int(saved_stop)][1]),.01)): return false
	if saved_stop<0 and pause!=0: return false
	var length := 0.0
	for i in range(1,value.trip.size()):
		length += Vector2(value.trip[i-1][0],value.trip[i-1][1]).distance_to(Vector2(value.trip[i][0],value.trip[i][1]))
	return value.travelled>=0 and value.travelled<=length+.0001 and absf(value.heading)<=1000000
func restore(value: Dictionary) -> bool:
	if not valid_snapshot(value):
		return false
	var points: Array[Vector2] = []
	for p in value.trip:
		points.append(Vector2(p[0],p[1]))
	var park := Vector2(value.parked[0],value.parked[1])
	if not world.navigation.clear_point(park,.98):
		return false
	for i in range(1,points.size()):
		var trail_segment: bool = value.get("forest_trip",false) and ForestLand.drive_edge(points[i-1],points[i])
		if not trail_segment and not world.navigation.safe_segment(points[i-1],points[i],.98):
			return false
	stop_index = int(value.get("stop_index",-1))
	stop_elapsed = float(value.get("stop_elapsed",0))
	parked = park
	forest_trip = value.get("forest_trip",false)
	heading = float(value.heading)
	trip.assign(points)
	travelled = float(value.travelled)
	random.state = value.random_state.to_int()
	trip_distance = 0
	for i in range(1,trip.size()):
		trip_distance += trip[i-1].distance_to(trip[i])
	_place(parked,heading)
	return true
