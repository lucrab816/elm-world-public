extends Node3D
const DiningLayout = preload("res://outdoor_dining.gd")

signal activity_changed(description: String)
signal arrived(location_id: String, activity: String)
signal rest_choice_changed(reason: String)
const ActionRequest = preload("res://action_request.gd")
var user_action = ActionRequest.new()
const Car = preload("res://little_car.gd")
const RestChoice = preload("res://rest_choice.gd")
var rest_choice_reason := ""

const RESIDENT_ID := "resident_001"
const WALK_SPEED := 1.05
var needs: RefCounted
var meal_bowl: Node3D
var world: Node3D
var catalog: Dictionary
# Runtime identity and activity are independent of meshes and the asset catalog.
var current_location := "place.home_front"
var destination_id := ""
var mode := "observe"
var visit_index := -1
var remaining := 2.0
var route: Array[Vector3] = []
var recent_events: Array[String] = []
var visited: Dictionary = {}
var elapsed := 0.0
var model: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var umbrella: Node3D
var petting_legs: Node3D
var ride_requested := false
var driving_legs: Node3D
var marker: MeshInstance3D

func setup(owner_world: Node3D, layout: Dictionary) -> void:
	world = owner_world
	catalog = layout
	_build_model()
	position = _point(current_location)
	_sync_height()
	_emit_activity("在家门口看看小院")

func _point(id: String) -> Vector3:
	if id=="object.car.001":
		var boarding: Vector2 = world.navigation.boarding(Vector2(world.car.position.x,world.car.position.z))
		return Vector3(boarding.x,0,boarding.y)
	var value: Array
	if catalog.locations.has(id):
		value = catalog.locations[id].position
	else:
		value = catalog.waypoints[id]
	return Vector3(float(value[0]),0,float(value[1]))

func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	world._box(Vector3(0,0.78,0),Vector3(0.43,0.49,0.28),"e7d9b6",model)
	world._ball(Vector3(0,1.20,0),0.235,"d6b896",model)
	# Featureless wooden stand-in: final appearance not designed yet; persona is separate.
	for sign_value in [-1,1]:
		var leg := Node3D.new()
		model.add_child(leg)
		leg.position = Vector3(sign_value*0.12,0.53,0)
		world._box(Vector3(0,-0.21,0),Vector3(0.17,0.42,0.18),"8d9d88",leg)
		world._box(Vector3(0,-0.45,0.055),Vector3(0.19,0.12,0.29),"766956",leg)
		var arm := Node3D.new()
		model.add_child(arm)
		arm.position = Vector3(sign_value*0.29,0.95,0)
		world._box(Vector3(0,-0.18,0),Vector3(0.13,0.36,0.15),"e7d9b6",arm)
		world._ball(Vector3(0,-0.38,0),0.08,"d6b896",arm)
		if sign_value == -1:
			left_leg = leg
			left_arm = arm
		else:
			right_leg = leg
			right_arm = arm
	petting_legs = Node3D.new()
	model.add_child(petting_legs)
	for side in [-1,1]:
		world._box(Vector3(side*.12,.46,.02),Vector3(.17,.18,.29),"8d9d88",petting_legs)
		world._box(Vector3(side*.12,.43,.13),Vector3(.19,.12,.25),"766956",petting_legs)
	petting_legs.visible = false
	driving_legs = Node3D.new()
	model.add_child(driving_legs)
	for side in [-1,1]:
		world._box(Vector3(side*.12,.55,.13),Vector3(.17,.16,.30),"8d9d88",driving_legs)
		world._box(Vector3(side*.12,.35,.27),Vector3(.16,.28,.17),"8d9d88",driving_legs)
		world._box(Vector3(side*.12,.19,.32),Vector3(.19,.12,.29),"766956",driving_legs)
	driving_legs.visible = false
	var ring := TorusMesh.new()
	ring.inner_radius = 0.30
	ring.outer_radius = 0.34
	ring.rings = 16
	ring.ring_segments = 6
	marker = world._mesh(ring,Vector3(0,0.025,0),"f5e5b2",self)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	meal_bowl = Node3D.new()
	model.add_child(meal_bowl)
	world._pole(Vector3(0,0.83,0.35),0.13,0.10,"bba58b",meal_bowl)
	world._pole(Vector3(0,0.886,0.35),0.105,0.008,"dda868",meal_bowl)
	meal_bowl.visible = false

func _build_umbrella() -> void:
	umbrella = Node3D.new()
	umbrella.name = "GiftUmbrella"
	model.add_child(umbrella)
	umbrella.position = Vector3(.29,.95,.38)
	world._pole(Vector3(0,.38,0),.022,.92,"725443",umbrella)
	var canopy := SurfaceTool.new()
	canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(-.18,.99,.0)
	for i in range(8):
		var angle := TAU*i/8
		var next_angle := TAU*(i+1)/8
		var rim := Vector3(cos(angle)*.68-.18,.69,sin(angle)*.68)
		var next := Vector3(cos(next_angle)*.68-.18,.69,sin(next_angle)*.68)
		var middle := tip.lerp(rim,.58)+Vector3.UP*.04
		var next_middle := tip.lerp(next,.58)+Vector3.UP*.04
		canopy.set_color(Color("fff0d2") if i%2 else Color("dde6d3"))
		for point in [tip,middle,next_middle,middle,rim,next,next,middle,next_middle]:
			canopy.add_vertex(point)
	canopy.generate_normals()
	var cover := MeshInstance3D.new()
	cover.mesh = canopy.commit()
	var canvas := StandardMaterial3D.new()
	canvas.albedo_color = Color("63826e")
	canvas.vertex_color_use_as_albedo = true
	canvas.roughness = .9
	canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	cover.material_override = canvas
	umbrella.add_child(cover)
	world._ball(tip,.035,"725443",umbrella)
	umbrella.hide()

func update_umbrella(open: bool) -> void:
	if not open and umbrella==null: return
	if umbrella==null: _build_umbrella()
	if open:
		right_arm.rotation.x = -PI/2
		right_arm.rotation.z = 0
	elif umbrella.visible:
		right_arm.rotation.x = sin(elapsed*8)*.315 if mode=="move" else 0.0
	umbrella.visible = open

func _process(delta: float) -> void:
	advance(minf(delta,0.1))

func advance(delta: float) -> void:
	elapsed += delta
	if mode=="arrange_plant":
		remaining = maxf(0,remaining-delta)
		right_arm.rotation.x = -1.15 + sin(elapsed*5)*.22
		if remaining<=0:
			world.plant_arrangement.finish(world,_action_time())
			_pose_stand()
			arrived.emit(current_location,"plant_placed")
			_start_next_visit()
		return
	if mode=="drive":
		var completed: bool = world.car.advance_trip(delta)
		remaining = maxf(0,(world.car.trip_distance-world.car.travelled)/Car.SPEED)
		_show_drive_activity()
		if completed:
			_pose_stand()
			position = _point("object.car.001")
			_sync_height()
			recent_events.append("object.car.001:drive_done")
			if recent_events.size()>24:
				recent_events.pop_front()
			arrived.emit("object.car.001","drive_done")
			if world.shelter_from_rain:
				mode = "observe"
				remaining = 0.5
			else:
				_start_next_visit()
		return
	if mode == "move":
		if route.is_empty():
			_finish_walk()
			return
		var target := route[0]
		var flat := Vector3(position.x,0,position.z)
		var direction := target-flat
		if direction.length() > 0.001:
			rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(delta*8,1))
		var next := flat.move_toward(target,WALK_SPEED*delta)
		if not world.navigation.furniture_clear(Vector2(next.x,next.z),.28):
			mode = "observe"
			route.clear()
			remaining = 2
			_pose_stand()
			return
		position.x = next.x
		position.z = next.z
		_sync_height()
		_pose_walk()
		if next.distance_to(target) < 0.001:
			route.pop_front()
			if route.is_empty():
				_finish_walk()
	else:
		remaining = maxf(0,remaining-delta)
		if remaining <= 0:
			if mode == "rest":
				if current_location=="object.bench.001":
					position.x = DiningLayout.SEAT_APPROACH.x
					position.z = DiningLayout.SEAT_APPROACH.y
					_sync_height()
				world.rest_preference.record(current_location)
				if world.plant_arrangement.try_begin(world,self):
					mode = "arrange_plant"
					remaining = world.plant_arrangement.DURATION
					_pose_stand()
					right_arm.rotation.x = -1.15
					_emit_activity("整理一盆小植物，想把它放在常休息的地方")
					return
			if mode == "eat" and needs!=null:
				needs.finish_meal()
			_start_next_visit()

func _start_next_visit() -> void:
	# Basic needs can recover even when the usual furniture or its route is unavailable.
	if needs!=null and user_action.phase()!="resting":
		if needs.satiety<=10 and needs.wants_meal():
			needs.begin_meal()
			mode = "eat"
			remaining = 16
			_pose_stand()
			_pose_eat()
			_emit_activity("先吃一份餐食恢复体力")
			arrived.emit(current_location,"eat")
			return
		if needs.energy<=12:
			mode = "rest"
			remaining = 60
			_pose_stand()
			_emit_activity("在原地歇一会儿恢复精力")
			arrived.emit(current_location,"rest")
			return
	if user_action.phase()=="resting":
		user_action.mark("completed","done",_action_time())
		_note_requested_event("rest_done")
	var meal_first := false
	if user_action.phase()=="queued":
		if needs!=null and needs.wants_meal():
			user_action.mark("queued","meal",_action_time())
			meal_first = true
		elif _begin_requested_rest():
			return
	visit_index = (visit_index+1)%catalog.visits.size()
	var car_index := -1
	for i in range(catalog.visits.size()):
		if catalog.visits[i].get("activity")=="drive":
			car_index = i
	if ride_requested and car_index>=0 and (needs==null or (not needs.wants_meal() and needs.energy>=35)):
		visit_index = car_index
	if visit_index==car_index and needs!=null:
		if needs.wants_meal():
			visit_index = catalog.visits.size()-1
		elif needs.energy<35:
			visit_index = 0
	# After resting in the shade, continue to the garden rather than visit it twice.
	if needs!=null and visit_index==1 and current_location=="place.tree_shade":
		visit_index = 2
	if visit_index==car_index and needs!=null:
		if needs.wants_meal():
			visit_index = catalog.visits.size()-1
		elif needs.energy<35:
			visit_index = 0
	if meal_first:
		visit_index = catalog.visits.size()-1
	var visit: Dictionary = catalog.visits[visit_index]
	destination_id = visit.destination
	if needs!=null and visit_index==0 and needs.energy<=needs.REST_AT:
		var choice: Dictionary = RestChoice.choose(catalog,needs.energy,world.sunlight,world.rest_preference.preferred())
		if choice.is_empty():
			mode = "observe"
			remaining = 3
			_emit_activity("暂时看看小院，慢慢再出发")
			return
		destination_id = choice.destination
		rest_choice_reason = choice.reason
		rest_choice_changed.emit(rest_choice_reason)
	# Missing furniture can be handled locally without resetting the resident.
	if not catalog.locations.has(destination_id):
		mode = "observe"
		remaining = 3
		_emit_activity("暂时停留，看看周围")
		return
	_pose_stand()
	mode = "move"
	route.clear()
	var target := _point(destination_id)
	if destination_id=="object.bench.001":
		target = Vector3(DiningLayout.SEAT_APPROACH.x,0,DiningLayout.SEAT_APPROACH.y)
	elif destination_id=="place.home_front":
		target = Vector3(-2,0,2.5)
	var parked_point := Vector2(world.car.position.x,world.car.position.z)
	var path: PackedVector2Array = world.navigation.resident_path(Vector2(position.x,position.z),Vector2(target.x,target.z),parked_point)
	for point in path: route.append(Vector3(point.x,0,point.y))
	if route.is_empty():
		mode = "observe"
		remaining = 3
		_emit_activity("等路通了再走")
		return
	_emit_activity("走向"+str(catalog.locations[destination_id].name))

func _finish_walk() -> void:
	if user_action.phase()=="moving":
		if not _request_target_available() or destination_id!=ActionRequest.TARGET:
			user_action.mark("failed","missing_target",_action_time())
			mode = "observe"
			remaining = 2
			_pose_stand()
			return
		current_location = destination_id
		visited[current_location] = true
		mode = "rest"
		remaining = 60.0 if needs!=null and needs.energy<35 else 30.0
		user_action.mark("resting","resting",_action_time())
		rest_choice_reason = "应你的邀请，到树荫歇一会儿"
		rest_choice_changed.emit(rest_choice_reason)
		_pose_stand()
		_pose_rest()
		_note_requested_event("rest")
		return
	current_location = destination_id
	var visit: Dictionary = catalog.visits[visit_index]
	mode = visit.activity
	remaining = float(visit.seconds)
	if mode=="rest" and needs!=null and needs.energy>needs.REST_AT:
		mode = "observe"
		remaining = 6.0
	visited[current_location] = true
	_pose_stand()
	if mode == "observe" and current_location=="place.home_front" and needs!=null and needs.wants_meal() and (preload("res://world_calendar.gd").anchor<0 or (needs.satiety<=10 and world.dining.meal.is_empty() and world.dining.state.order_until==0)):
		needs.begin_meal(preload("res://world_calendar.gd").anchor<0)
		mode = "eat"
		remaining = 30.0
	if mode=="drive":
		if world.shelter_from_rain and not ride_requested:
			mode = "observe"
			remaining = 0.5
		elif not world.car.start_trip():
			mode = "observe"
			remaining = 3
			_emit_activity("小车先停一会儿，等路通了再兜风")
		else:
			ride_requested = false
			remaining = world.car.trip_distance/Car.SPEED
			_pose_drive()
			_emit_activity("开着薄荷小车，去树林兜一圈再回家" if world.car.forest_trip else "开着薄荷小车，在院子里兜风")
	elif mode == "rest":
		if needs!=null and needs.energy<35:
			remaining = maxf(remaining,60.0)
		_pose_rest()
	elif mode == "eat":
		_pose_eat()
		_emit_activity("在家门口慢慢吃饭")
	else:
		_sync_height()
		_emit_activity("在"+str(catalog.locations[current_location].name)+"看看周围")
	recent_events.append(current_location+":"+mode)
	if recent_events.size()>24:
		recent_events.pop_front()
	arrived.emit(current_location,mode)

func _sync_height() -> void:
	position.y = world._height(position.x,position.z)
	# The garden path is slightly raised above the terrain.
	if absf(position.x-(0.5+sin(position.z*0.45)*0.9))<0.72:
		position.y += 0.07

func _walk_pose_step(delta: float) -> void:
	elapsed += delta
	_pose_walk()

func _pose_walk() -> void:
	var swing := sin(elapsed*8)*0.45
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -swing*0.7
	right_arm.rotation.x = swing*0.7
	model.position.y = absf(sin(elapsed*8))*0.025

func _pose_rest() -> void:
	var place: Dictionary = catalog.locations[current_location]
	if place.has("seat_height"):
		rotation.y = 0
		position.x = DiningLayout.SEAT.x
		position.z = DiningLayout.SEAT.y
		position.y = world._height(position.x,position.z)-.09
		left_leg.rotation.x = -PI/2
		right_leg.rotation.x = -PI/2
		left_arm.rotation.x = -0.6
		right_arm.rotation.x = -0.6
		_emit_activity("坐在"+str(place.name)+"上休息")
	else:
		_sync_height()
		_emit_activity("在"+str(place.name)+"下歇一会儿")

func _pose_eat() -> void:
	_sync_height()
	meal_bowl.visible = true
	left_arm.rotation.x = -0.9
	right_arm.rotation.x = -0.9

func _show_drive_activity() -> void:
	if not world.car.stopping():
		_pose_drive()
		_emit_activity("开着薄荷小车在树林兜风，最后回小院" if world.car.forest_trip else "开着薄荷小车在院子里兜风")
		return
	var point: Vector2 = world.car.stop_walk_position()
	var previous := position
	_pose_stand()
	position = Vector3(point.x,world._height(point.x,point.y),point.y)
	var movement := position-previous
	if Vector2(movement.x,movement.z).length_squared()>.000001:
		rotation.y = atan2(movement.x,movement.z)
		_pose_walk()
	_emit_activity("把小车停在林间，下车走走")

func _pose_drive() -> void:
	world.car.apply_distance()
	position = world.car.position
	rotation.y = world.car.rotation.y
	model.position.y = .02
	left_leg.visible = false
	right_leg.visible = false
	driving_legs.visible = true
	left_arm.rotation.x = -.8
	right_arm.rotation.x = -.8

func _pose_pet(seconds: float) -> void:
	_pose_stand()
	model.position.y = -.30
	model.rotation.x = .30
	left_leg.visible = false
	right_leg.visible = false
	petting_legs.visible = true
	right_arm.rotation.x = -1.05+sin(seconds*5)*.12
	right_arm.rotation.z = -.50
	_emit_activity("蹲下来，轻轻摸摸德雷克")

func _pose_stand() -> void:
	petting_legs.visible = false
	left_leg.visible = true
	right_leg.visible = true
	driving_legs.visible = false
	meal_bowl.visible = false
	model.position.y = 0
	model.rotation.x = 0
	for limb in [left_leg,right_leg,left_arm,right_arm]:
		limb.rotation.x = 0
		limb.rotation.z = 0

func _emit_activity(text: String) -> void:
	activity_changed.emit(text)

func snapshot() -> Dictionary:
	var points: Array = []
	for point in route:
		points.append([point.x,point.z])
	return {"resident_id":RESIDENT_ID,"position":[position.x,position.z],"rotation_y":rotation.y,
		"current_location":current_location,"destination_id":destination_id,"mode":mode,
		"visit_index":visit_index,"remaining":remaining,"route":points,"elapsed":elapsed,
		"recent_events":recent_events.duplicate(),"visited":visited.duplicate(),
		"ride_requested":ride_requested,"user_action":user_action.snapshot(),"car_state":world.car.snapshot(),"layout_signature":_layout_signature(),"rest_choice_reason":rest_choice_reason}

static func _finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _valid_point(point: Variant) -> bool:
	return point is Array and point.size()==2 and _finite(point[0]) and _finite(point[1]) and ((absf(point[0])<=11 and absf(point[1])<=9) or preload("res://forest_land.gd").contains_trail_point(Vector2(point[0],point[1])) )

static func valid_snapshot(state: Variant) -> bool:
	if not state is Dictionary or state.get("resident_id")!=RESIDENT_ID:
		return false
	var at = state.get("position")
	var forest_drive := false
	if state.get("mode")=="drive" and state.get("car_state") is Dictionary and state.car_state.get("forest_trip",false) and at is Array and at.size()==2 and _finite(at[0]) and _finite(at[1]):
		forest_drive = preload("res://forest_land.gd").near_drive_loop(Vector2(at[0],at[1]),.10) or (at[0]>=-30 and at[0]< -28 and absf(at[1]+1)<.10)
	if (not forest_drive and not _valid_point(at)) or state.get("mode") not in ["move","observe","rest","eat","drive","arrange_plant"]:
		return false
	for key in ["rotation_y","elapsed","remaining","visit_index"]:
		if not _finite(state.get(key)):
			return false
	if state.elapsed<0 or state.elapsed>1e12 or state.remaining<0 or state.remaining>(1800 if state.mode=="drive" else 300) or absf(state.rotation_y)>1e6:
		return false
	if state.visit_index<-1 or state.visit_index>1000 or state.visit_index!=floor(state.visit_index):
		return false
	for key in ["current_location","destination_id","layout_signature"]:
		if not state.get(key) is String or state[key].length()>128:
			return false
	if not state.get("route") is Array or state.route.size()>1000:
		return false
	for point in state.route:
		if not _valid_point(point):
			return false
	if not state.get("recent_events") is Array or state.recent_events.size()>24 or not state.get("visited") is Dictionary:
		return false
	for event in state.recent_events:
		if not event is String or event.length()>256:
			return false
	if state.visited.size()>256:
		return false
	for key in state.visited:
		if not key is String or key.length()>128 or not state.visited[key] is bool:
			return false
	if state.has("user_action"):
		if not ActionRequest.valid_snapshot(state.user_action,1e12):
			return false
		var phase: String = str(state.user_action.latest.get("phase",""))
		if phase=="moving" and (state.mode!="move" or state.destination_id!=ActionRequest.TARGET):
			return false
		if phase=="resting" and (state.mode!="rest" or state.current_location!=ActionRequest.TARGET or state.remaining>60):
			return false
	if not state.get("ride_requested",false) is bool:
		return false
	if state.has("car_state") and not Car.valid_snapshot(state.car_state):
		return false
	if state.mode=="drive":
		if state.current_location!="object.car.001":
			return false
		if state.has("car_state"):
			if state.car_state.trip.size()<2:
				return false
			var length := 0.0
			for i in range(1,state.car_state.trip.size()):
				length += Vector2(state.car_state.trip[i-1][0],state.car_state.trip[i-1][1]).distance_to(Vector2(state.car_state.trip[i][0],state.car_state.trip[i][1]))
			if absf(state.remaining-(length-state.car_state.travelled)/Car.SPEED)>.001:
				return false
		elif state.remaining>32:
			return false
	if state.mode=="move" and (state.visit_index<0 or state.destination_id.is_empty()):
		return false
	if not state.get("rest_choice_reason","") is String or state.get("rest_choice_reason","").length()>256:
		return false
	return true

func _layout_signature() -> String:
	var positions := {}
	for id in catalog.locations:
		positions[id] = catalog.locations[id].position
	return JSON.stringify({"positions":positions,"waypoints":catalog.waypoints,"visits":catalog.visits}).sha256_text()

func restore(state: Dictionary) -> bool:
	if not valid_snapshot(state):
		return false
	position = Vector3(float(state.position[0]),0,float(state.position[1]))
	rotation.y = float(state.rotation_y)
	current_location = state.current_location
	destination_id = state.destination_id
	mode = state.mode
	visit_index = int(state.visit_index)
	remaining = float(state.remaining)
	ride_requested = bool(state.get("ride_requested",false))
	user_action = ActionRequest.new()
	if state.has("user_action"):
		user_action.restore(state.user_action,1e12)
	elapsed = float(state.elapsed)
	rest_choice_reason = state.get("rest_choice_reason","")
	recent_events.assign(state.recent_events)
	visited = state.visited.duplicate()
	route.clear()
	for point in state.route:
		route.append(Vector3(float(point[0]),0,float(point[1])))
	var car_restored: bool = state.has("car_state") and world.car.restore(state.car_state)
	# A changed layout cancels only the current plan, never the resident's recorded history.
	if state.layout_signature!=_layout_signature() or not catalog.locations.has(current_location) or visit_index>=catalog.visits.size() or (mode=="drive" and not car_restored) or (user_action.active() and not _request_target_available()):
		if user_action.active():
			user_action.mark("failed","missing_target" if not _request_target_available() else "layout_changed",float(world.simulation_seconds))
		mode = "eat" if state.mode=="eat" else "observe"
		current_location = "place.home_front"
		position = _point(current_location)
		destination_id = ""
		visit_index = -1
		remaining = float(state.remaining) if mode=="eat" else 2.0
		route.clear()
	_pose_stand()
	_sync_height()
	if mode=="observe" and not world.navigation.furniture_clear(Vector2(position.x,position.z),.28):
		var point: Vector2 = world.navigation.boarding(Vector2(world.car.position.x,world.car.position.z)) if current_location=="object.car.001" else DiningLayout.SEAT_APPROACH
		position.x = point.x
		position.z = point.y
		_sync_height()
	if mode=="drive":
		_show_drive_activity()
	elif mode=="rest" and catalog.locations[current_location].activities.has("rest"):
		_pose_rest()
	elif mode=="arrange_plant":
		right_arm.rotation.x = -1.15
		_emit_activity("整理一盆小植物，想把它放在常休息的地方")
	elif mode=="eat":
		_pose_eat()
		_emit_activity("在家门口慢慢吃饭")
	elif mode=="move":
		_pose_walk()
		_emit_activity("走向"+str(catalog.locations.get(destination_id,{"name":"小院"}).name))
	else:
		mode = "observe"
		_emit_activity("在"+str(catalog.locations[current_location].name)+"看看周围")
	return true

func _action_time() -> float:
	return maxf(float(world.event_seconds),float(world.simulation_seconds))
func _request_target_available() -> bool:
	return catalog.locations.has(ActionRequest.TARGET) and "rest" in catalog.locations[ActionRequest.TARGET].get("activities",[])
func _note_requested_event(kind: String) -> void:
	recent_events.append(ActionRequest.TARGET+":"+kind)
	if recent_events.size()>24:
		recent_events.pop_front()
	arrived.emit(ActionRequest.TARGET,kind)
func _begin_requested_rest() -> bool:
	if not _request_target_available():
		user_action.mark("failed","missing_target",_action_time())
		return false
	var target := _point(ActionRequest.TARGET)
	var parked_point := Vector2(world.car.position.x,world.car.position.z)
	var path: PackedVector2Array = world.navigation.path(Vector2(position.x,position.z),Vector2(target.x,target.z),.28,parked_point)
	if path.is_empty() or path[path.size()-1].distance_to(Vector2(target.x,target.z))>.55:
		user_action.mark("failed","blocked",_action_time())
		return false
	_pose_stand()
	destination_id = ActionRequest.TARGET
	# Normal tree visit index, so the ordinary routine can continue afterwards.
	visit_index = 1
	mode = "move"
	route.clear()
	for point in path:
		route.append(Vector3(point.x,0,point.y))
	user_action.mark("moving","walking",_action_time())
	_emit_activity("自己选了树荫，走过去歇一会儿" if user_action.latest.get("origin")=="self_arrangement" else "应你的邀请，走向树荫休息")
	return true
