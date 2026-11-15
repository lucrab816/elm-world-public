extends Node3D

const Calendar = preload("res://world_calendar.gd")
# A locally simulated companion. No health debt, model calls, or off-line catch-up.
const ID := "pet.rabbit.001"
const DISPLAY_NAME := "德雷克"
const VISUAL_SCALE := .55
const HOP_CYCLE := .68
const Feeding = preload("res://rabbit_feeding.gd")
const Hutch = preload("res://rabbit_hutch.gd")
const TIRED_AFTER := 120.0
const NIGHT_TIRED_AFTER := 46.0
const NIGHT_NAP_MAX := 155.0
const HUTCH_MODES := ["hutch_enter","sleeping","hutch_exit"]
const STATIONARY_MODES := ["rest","watch_car","petting","mia_pet","feeding"]+HUTCH_MODES
const FLIGHT_START := .10
const FLIGHT_END := .40
const HOP_DISTANCE := .72
const EVENT_LIMIT := 16
# Two authored quiet corners; a stable choice is not inferred from past visits.
const FAVORITES := {"home_grass":{"name":"屋旁的草地","point":Vector2(-4,4.5)},"flower_grass":{"name":"花丛旁的草地","point":Vector2(-5.5,4.0)}}
const MODES := ["rest","wander","follow","returning","watch_car","greet","petting","favorite_walk","mia_pet","hutch_return","feed_walk","feeding"]+HUTCH_MODES
const EVENTS := ["arrived","wander_started","follow_started","return_started","settled","watch_car","pet_started","pet_done","pet_cancelled","favorite_started","favorite_arrived","mia_pet_started","mia_pet_done","mia_pet_cancelled","hutch_return_started","sleep_started","sleep_finished","had_hay","drank_water","feed_walk_started"]
var display_name := DISPLAY_NAME
var hop_time := 0.0
var fatigue := 0.0
var appetite := 0.0
var hay := Feeding.CAPACITY
var water := Feeding.CAPACITY
var hind_feet: Array[Node3D] = []
var front_feet: Array[Node3D] = []
var world: Node3D
var model: Node3D
var ears: Array[Node3D] = []
var mode := "rest"
var remaining := 8.0
var elapsed := 0.0
var route: Array[Vector2] = []
var events: Array = []
var random := RandomNumberGenerator.new()
var born_seconds := 0.0
var favorite_id := ""
var favorite_visits := 0
var favorite_last_seconds = null
var at_favorite := false
func setup(owner_world: Node3D) -> void:
	world = owner_world
	name = "Rabbit"
	set_meta("pet_id",ID)
	model = Node3D.new()
	model.scale = Vector3.ONE*VISUAL_SCALE
	add_child(model)
	var body = world._ball(Vector3(0,.28,-.06),.30,"f3ebd8",model)
	body.scale = Vector3(1,.88,1.20)
	var head = world._ball(Vector3(0,.47,.22),.235,"fff5e2",model)
	head.scale = Vector3(1.12,1,1)
	for side in [-1,1]:
		var ear := Node3D.new()
		model.add_child(ear)
		ear.position = Vector3(side*.115,.63,.22)
		ear.rotation.z = side*-.14
		var outside = world._ball(Vector3(0,.21,0),.10,"fff5e2",ear)
		outside.scale = Vector3(.85,2.6,.62)
		var inside = world._ball(Vector3(0,.22,.065),.065,"e8b5b2",ear)
		inside.scale = Vector3(.66,2.65,.30)
		ears.append(ear)
		world._ball(Vector3(side*.139,.50,.408),.031,"39483d",model)
		world._ball(Vector3(side*.145,.510,.430),.008,"fff9ed",model)
		var foot = world._ball(Vector3(side*.16,.065,.22),.085,"e9dfcb",model)
		foot.scale = Vector3(.85,.65,1.1)
		front_feet.append(foot)
		var hind := Node3D.new()
		model.add_child(hind)
		hind.position = Vector3(side*.20,.105,-.19)
		var paw = world._ball(Vector3(0,-.025,0),.14,"e9dfcb",hind)
		paw.scale = Vector3(.85,.65,1.5)
		hind_feet.append(hind)
	world._ball(Vector3(0,.42,.472),.025,"dfaaa7",model)
	world._ball(Vector3(0,.30,-.40),.12,"fff7e7",model)
	random.randomize()
	visible = false
func flat() -> Vector2:
	return Vector2(position.x,position.z)
func _place(point: Vector2) -> void:
	position = Vector3(point.x,world._height(point.x,point.y)+.025,point.y)
func _car_clear(point: Vector2, margin: float = 1.65) -> bool:
	if point.distance_to(Vector2(world.car.position.x,world.car.position.z))<margin:
		return false
	if world.resident.mode=="drive":
		var trip: Array = world.car.trip
		for i in range(1,trip.size()):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,trip[i-1],trip[i]))<margin:
				return false
	return true
func _home_point() -> Vector2:
	var grid = world.navigation.make_grid(.22,Vector2(world.car.position.x,world.car.position.z),1.65)
	var wanted := Vector2(-4,3)
	var best := Vector2.INF
	var distance := INF
	for x in range(grid.region.size.x):
		for z in range(grid.region.size.y):
			var id := Vector2i(x,z)
			var p: Vector2 = grid.get_point_position(id)
			if not grid.is_point_solid(id) and _car_clear(p) and p.distance_squared_to(wanted)<distance:
				distance = p.distance_squared_to(wanted)
				best = p
	return best
func adopt(seconds: float) -> void:
	born_seconds = floorf(seconds)
	elapsed = 0
	hop_time = 0
	fatigue = 0
	appetite = 0
	hay = Feeding.CAPACITY
	water = Feeding.CAPACITY
	display_name = DISPLAY_NAME
	favorite_id = ["home_grass","flower_grass"][random.randi_range(0,1)]
	favorite_visits = 0
	favorite_last_seconds = null
	at_favorite = false
	events.clear()
	route.clear()
	var home := _home_point()
	_place(home if home.is_finite() else Vector2(-4,3))
	mode = "watch_car" if world.resident.mode=="drive" else "rest"
	remaining = 8
	visible = true
	_note("arrived",seconds)
	_sync_obstacle()
func _sync_obstacle() -> void:
	world.navigation.pet_obstacle = Vector2.INF if mode in HUTCH_MODES else flat()
func _note(kind: String, seconds: float, interaction_id: int = 0) -> void:
	seconds = floorf(seconds)
	if not events.is_empty() and events.back().kind==kind and events.back().seconds==seconds:
		return
	var event := {"kind":kind,"seconds":seconds}
	if interaction_id>0: event["interaction_id"] = interaction_id
	events.append(event)
	while events.size()>EVENT_LIMIT: events.pop_front()
func heading_to_bed() -> bool:
	return mode=="hutch_return" or mode in HUTCH_MODES

func _start_path(target: Vector2, intent: String, seconds: float) -> bool:
	if not target.is_finite(): return false
	var path: PackedVector2Array = world.navigation.path(flat(),target,.22,Vector2(world.car.position.x,world.car.position.z),1.65)
	if path.is_empty() or flat().distance_to(path[path.size()-1])<.35:
		return false
	var previous := flat()
	for point in path:
		if not _car_clear(point) or not world.navigation.safe_segment(previous,point,.22):
			return false
		previous = point
	route.assign(path)
	at_favorite = false
	hop_time = 0
	mode = intent
	_note({"wander":"wander_started","follow":"follow_started","returning":"return_started","greet":"follow_started","favorite_walk":"favorite_started","hutch_return":"hutch_return_started","feed_walk":"feed_walk_started"}[intent],seconds)
	return true
func advance(delta: float, seconds: float) -> void:
	elapsed += delta
	if mode in HUTCH_MODES:
		_advance_hutch(delta,seconds)
		return
	if mode=="feeding":
		remaining = maxf(0,remaining-delta)
		_pose(false)
		model.rotation.x = .16+sin(elapsed*8)*.05
		if remaining==0 or not _car_clear(flat()):
			if remaining==0:
				if hay>0:
					hay -= 1
					_note("had_hay",seconds)
				if water>0:
					water -= 1
					_note("drank_water",seconds)
				appetite = 0
			mode = "rest"
			remaining = 2
		return
	appetite = minf(Feeding.SNACK_AFTER,appetite+delta)
	if mode!="greet": fatigue = minf(TIRED_AFTER,fatigue+delta*(1.0 if route.is_empty() else 2.0))
	if mode=="watch_car":
		mode = "rest"
		remaining = 1.5
	if not route.is_empty():
		var previous_hop := hop_time
		hop_time += delta
		var travel := _hop_distance(hop_time)-_hop_distance(previous_hop)
		if mode=="follow" and flat().distance_to(Vector2(world.resident.position.x,world.resident.position.z))<1.0:
			route.clear()
		while travel>.000001 and not route.is_empty():
			var distance := flat().distance_to(route[0])
			var amount := minf(travel,distance)
			var next := flat().move_toward(route[0],amount)
			if not _car_clear(next) or (world.neighbor_enabled and world.neighbor.visible and next.distance_to(world.neighbor.flat())<.44 and next.distance_to(world.neighbor.flat())<flat().distance_to(world.neighbor.flat())):
				route.clear()
				break
			var direction := next-flat()
			if direction.length()>.0001:
				rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.y),minf(delta*12,1))
			_place(next)
			travel -= amount
			if distance<=amount+.00001: route.pop_front()
		if route.is_empty():
			if mode=="feed_walk" and flat().distance_to(Feeding.STAND)<.03 and _car_clear(flat()):
				mode = "feeding"
				remaining = 5
				rotation.y = PI
				_pose(false)
				_sync_obstacle()
				return
			if mode=="hutch_return" and flat().distance_to(Hutch.APPROACH)<.03 and _car_clear(flat()):
				mode = "hutch_enter"
				_advance_hutch(0,seconds)
				return
			var arrived_favorite: bool = mode=="favorite_walk" and not favorite_id.is_empty() and flat().distance_to(FAVORITES[favorite_id].point)<.4 and _car_clear(flat())
			mode = "rest"
			at_favorite = arrived_favorite
			remaining = random.randf_range(12,20) if arrived_favorite else random.randf_range(3,7)
			if arrived_favorite:
				favorite_visits = mini(favorite_visits+1,1000000000)
				favorite_last_seconds = floorf(seconds)
				_note("favorite_arrived",seconds)
			else:
				_note("settled",seconds)
		_pose(not route.is_empty())
	else:
		_pose(false)
		remaining = maxf(0,remaining-delta)
		if remaining<=0:
			at_favorite = false
			var actor := Vector2(world.resident.position.x,world.resident.position.z)
			if fatigue>=(NIGHT_TIRED_AFTER if Calendar.is_night(seconds) else TIRED_AFTER) and _car_clear(Hutch.APPROACH):
				if flat().distance_to(Hutch.APPROACH)<.03:
					mode = "hutch_enter"
					_advance_hutch(0,seconds)
					return
				if _start_path(Hutch.APPROACH,"hutch_return",seconds) and route.back()!=Hutch.APPROACH:
					route.clear()
					mode = "rest"
			elif appetite>=Feeding.SNACK_AFTER and (hay>0 or water>0) and world.hobbies.job not in Feeding.REFILL and _car_clear(Feeding.STAND):
				if flat().distance_to(Feeding.STAND)<.03:
					mode = "feeding"
					remaining = 5
					rotation.y = PI
				elif _start_path(Feeding.STAND,"feed_walk",seconds) and route.back()!=Feeding.STAND:
					route.clear()
					mode = "rest"
			elif flat().distance_to(Vector2(-4,3))>8:
				_start_path(_home_point(),"returning",seconds)
			elif random.randf()<.28 and _favorite_available() and flat().distance_to(FAVORITES[favorite_id].point)>=.4:
				_start_path(FAVORITES[favorite_id].point,"favorite_walk",seconds)
			elif world.resident.mode!="drive" and flat().distance_to(actor)>1.5 and flat().distance_to(actor)<9 and random.randf()<.60:
				_start_path(actor+Vector2(-1.3,.7),"follow",seconds)
			else:
				var target := Vector2(-4,3)+Vector2(random.randf_range(-2,2.5),random.randf_range(-.7,1.7))
				_start_path(target,"wander",seconds)
			if route.is_empty() and not at_favorite: remaining = 2.5
	_sync_obstacle()
func _place_in_hutch(point: Vector2) -> void:
	position = Vector3(point.x,Hutch.height_at(world,point)+.025,point.y)

func _advance_hutch(delta: float, seconds: float) -> void:
	if mode=="sleeping":
		remaining = maxf(0,remaining-delta)
		if remaining==0:
			fatigue = 0
			mode = "hutch_exit"
			_note("sleep_finished",seconds)
	elif mode=="hutch_enter":
		rotation.y = PI
		_place_in_hutch(flat().move_toward(Hutch.BED,delta*.8))
		if flat().distance_to(Hutch.BED)<.001:
			mode = "sleeping"
			remaining = random.randf_range(95,NIGHT_NAP_MAX) if Calendar.is_night(seconds) else random.randf_range(26,42)
			_note("sleep_started",seconds)
	elif _car_clear(Hutch.APPROACH) and (not world.neighbor_enabled or not world.neighbor.visible or world.neighbor.flat().distance_to(Hutch.APPROACH)>.5):
		rotation.y = 0
		_place_in_hutch(flat().move_toward(Hutch.APPROACH,delta*.8))
		if flat().distance_to(Hutch.APPROACH)<.001:
			mode = "rest"
			remaining = 2.0
	_pose(false)
	_sync_obstacle()

func _favorite_available() -> bool:
	if not FAVORITES.has(favorite_id): return false
	var point: Vector2 = FAVORITES[favorite_id].point
	return world.navigation.clear_point(point,.22) and _car_clear(point)
func favorite_description() -> String:
	if not FAVORITES.has(favorite_id): return "还没有选定喜欢的休息角落。"
	var text: String = "德雷克偏爱的休息角落是"+str(FAVORITES[favorite_id].name)+"。"
	if favorite_last_seconds==null: return text+"目前还没有记录到它在那里休息。"
	return text+"实际去过%d次，最近一次是第%d天 %s（世界时间）。"%[favorite_visits,Calendar.day_at(float(favorite_last_seconds)),preload("res://life_journal.gd").clock_text(float(favorite_last_seconds))]
static func _hop_distance(seconds: float) -> float:
	var phase := fmod(seconds,HOP_CYCLE)
	var progress := clampf((phase-FLIGHT_START)/(FLIGHT_END-FLIGHT_START),0,1)
	# Grounded paws stay still; a short airborne burst carries the body forward.
	var distance := progress-sin(TAU*progress)/TAU
	return (floorf(seconds/HOP_CYCLE)+distance)*HOP_DISTANCE
func _pose(moving: bool) -> void:
	model.position.y = 0
	model.rotation.x = 0
	var shape := Vector3.ONE
	for foot in hind_feet: foot.rotation.x = 0
	for foot in front_feet: foot.rotation.x = 0
	if moving:
		var phase := fmod(hop_time,HOP_CYCLE)
		if phase<FLIGHT_START:
			var crouch := sin(PI*phase/FLIGHT_START)
			shape = Vector3(1,.99-.14*crouch,1+.05*crouch)
			for foot in hind_feet: foot.rotation.x = -.45*crouch
		elif phase<FLIGHT_END:
			var air := (phase-FLIGHT_START)/(FLIGHT_END-FLIGHT_START)
			model.position.y = .10*sin(PI*air)
			model.rotation.x = -.12*sin(TAU*air)
			shape = Vector3(1,1.03,.98)
			for foot in hind_feet: foot.rotation.x = -.55*cos(PI*air)
			for foot in front_feet: foot.rotation.x = .25*sin(PI*air)
		elif phase<.51:
			var landing := sin(PI*(phase-FLIGHT_END)/.11)
			shape = Vector3(1,.99-.16*landing,1+.06*landing)
	else:
		shape.y = .97+sin(elapsed*2)*.015
	if mode=="sleeping": shape.y = .69+sin(elapsed*2.4)*.018
	model.scale = shape*VISUAL_SCALE
	for i in range(ears.size()):
		ears[i].rotation.x = -.72 if mode=="sleeping" else sin(elapsed*1.7+i)*.025
func description() -> String:
	if at_favorite and FAVORITES.has(favorite_id): return "在"+str(FAVORITES[favorite_id].name)+"安静歇着"
	return {"feed_walk":"正去兔屋旁吃草喝水","feeding":"在兔屋旁吃草喝水","hutch_return":"累了，正往后院的兔子房走","hutch_enter":"沿斜坡钻进兔子房","sleeping":"在兔子房里睡觉","hutch_exit":"睡醒了，准备出门","rest":"在附近歇着，耳朵动了动","wander":"在小院附近蹦蹦跳跳","follow":"正跟着埃尔走一小段","returning":"正回家附近歇脚","watch_car":"留在原地，看埃尔开车","greet":"蹦向埃尔，准备一起待一会儿","petting":"安静趴着，让埃尔轻轻摸摸","favorite_walk":"正去自己喜欢的草地歇一会儿","mia_pet":"安静待着，让米娅轻轻摸摸"}[mode]
func snapshot() -> Dictionary:
	var points: Array = []
	for p in route: points.append([p.x,p.y])
	return {"version":1,"pet_id":ID,"display_name":display_name,"hop_time":hop_time,"fatigue":fatigue,"appetite":appetite,"hay":hay,"water":water,"born_seconds":born_seconds,"position":[position.x,position.z],"rotation_y":rotation.y,"mode":mode,"remaining":remaining,"elapsed":elapsed,"route":points,"events":events.duplicate(true),"random_state":str(random.state),"favorite":{"id":favorite_id,"visits":favorite_visits,"last_seconds":favorite_last_seconds,"resting":at_favorite}}
static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=1e12
static func point(value: Variant) -> bool:
	return value is Array and value.size()==2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float) and is_finite(float(value[0])) and is_finite(float(value[1])) and value[0]>=-7.5 and value[0]<=8.5 and value[1]>=-6.5 and value[1]<=7.5
static func valid_snapshot(value: Variant, now: float) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("pet_id")!=ID or value.get("mode") not in MODES or not point(value.get("position")):
		return false
	if not value.get("display_name",DISPLAY_NAME) is String or value.get("display_name",DISPLAY_NAME).strip_edges().is_empty() or value.get("display_name",DISPLAY_NAME).length()>32:
		return false
	if not number(value.get("hop_time",0)) or not number(value.get("elapsed")) or value.get("hop_time",0)>value.get("elapsed",0):
		return false
	if not number(value.get("born_seconds")) or value.born_seconds>now or not number(value.get("elapsed")) or not number(value.get("remaining")) or value.remaining>(NIGHT_NAP_MAX if value.mode=="sleeping" else 60) or value.elapsed>now-value.born_seconds+.01:
		return false
	if not (value.get("rotation_y") is int or value.get("rotation_y") is float) or not is_finite(float(value.rotation_y)) or absf(value.rotation_y)>1000000:
		return false
	if not value.get("route") is Array or value.route.size()>1000 or not value.get("random_state") is String or not value.random_state.is_valid_int():
		return false
	for p in value.route:
		if not point(p): return false
	for supply in ["hay","water"]:
		var amount = value.get(supply,Feeding.CAPACITY)
		if not number(amount) or amount!=floor(amount) or amount>Feeding.CAPACITY: return false
	var saved_appetite = value.get("appetite",0)
	if not number(saved_appetite) or saved_appetite>Feeding.SNACK_AFTER: return false
	if value.mode=="feeding":
		var feeding_position := Vector2(value.position[0],value.position[1])
		if value.remaining>5 or (feeding_position.distance_to(Feeding.STAND)>.03 and feeding_position.distance_to(Feeding.PREVIOUS_STAND)>.03): return false
	if not number(value.get("fatigue",0)) or value.get("fatigue",0)>TIRED_AFTER: return false
	if (value.mode in STATIONARY_MODES)!=value.route.is_empty(): return false
	if value.mode=="hutch_return" and Vector2(value.route.back()[0],value.route.back()[1])!=Hutch.APPROACH: return false
	if value.mode in HUTCH_MODES:
		var at := Vector2(value.position[0],value.position[1])
		if absf(at.x-Hutch.BED.x)>.001 or at.y<Hutch.BED.y-.001 or at.y>Hutch.APPROACH.y+.001: return false
		if value.mode=="sleeping" and at.distance_to(Hutch.BED)>.001: return false
	if value.has("favorite"):
		var favorite = value.favorite
		if not favorite is Dictionary or favorite.get("id") not in FAVORITES or not number(favorite.get("visits")) or favorite.visits!=floor(favorite.visits) or favorite.visits>1000000000 or not favorite.get("resting") is bool: return false
		if favorite.visits==0 and favorite.get("last_seconds")!=null: return false
		if favorite.visits>0 and (not number(favorite.get("last_seconds")) or favorite.last_seconds<value.born_seconds or favorite.last_seconds>now): return false
		if favorite.resting and (value.mode!="rest" or Vector2(value.position[0],value.position[1]).distance_to(FAVORITES[favorite.id].point)>=.4): return false
	elif value.mode=="favorite_walk": return false
	if not value.get("events") is Array or value.events.size()>EVENT_LIMIT: return false
	var previous: float = value.born_seconds
	for event in value.events:
		if not event is Dictionary or event.get("kind") not in EVENTS or not number(event.get("seconds")) or event.seconds<previous or event.seconds>now+.000001:
			return false
		if event.get("kind") in ["pet_started","pet_done","pet_cancelled","mia_pet_started","mia_pet_done","mia_pet_cancelled"] and (not number(event.get("interaction_id")) or event.interaction_id<1 or event.interaction_id!=floor(event.interaction_id)): return false
		previous = event.seconds
	return true
func restore(value: Dictionary, now: float) -> bool:
	if not valid_snapshot(value,now): return false
	display_name = str(value.get("display_name",DISPLAY_NAME))
	hop_time = float(value.get("hop_time",0))
	fatigue = float(value.get("fatigue",0))
	appetite = float(value.get("appetite",0))
	hay = int(value.get("hay",Feeding.CAPACITY))
	water = int(value.get("water",Feeding.CAPACITY))
	born_seconds = float(value.born_seconds)
	elapsed = float(value.elapsed)
	remaining = float(value.remaining)
	rotation.y = float(value.rotation_y)
	mode = value.mode
	events = value.events.duplicate(true)
	random.state = value.random_state.to_int()
	if value.has("favorite"):
		favorite_id = value.favorite.id
		favorite_visits = int(value.favorite.visits)
		favorite_last_seconds = value.favorite.last_seconds
		at_favorite = value.favorite.resting
	else:
		favorite_id = ["home_grass","flower_grass"][random.randi_range(0,1)]
		favorite_visits = 0
		favorite_last_seconds = null
		at_favorite = false
	route.clear()
	for p in value.route: route.append(Vector2(p[0],p[1]))
	var saved_position := Vector2(value.position[0],value.position[1])
	if mode in HUTCH_MODES:
		_place_in_hutch(saved_position)
		visible = true
		_pose(false)
		_sync_obstacle()
		return true
	_place(saved_position)
	if (mode=="feeding" and flat().distance_to(Feeding.STAND)>.03) or (mode=="feed_walk" and route.back()!=Feeding.STAND):
		route.clear()
		mode = "rest"
		remaining = 0
	if not world.navigation.clear_point(flat(),.22) or not _car_clear(flat()):
		route.clear()
		var home := _home_point()
		_place(home if home.is_finite() else Vector2(-4,3))
		mode = "watch_car" if world.resident.mode=="drive" else "rest"
		at_favorite = false
		remaining = 5
	var previous := flat()
	for p in route:
		if not world.navigation.safe_segment(previous,p,.22):
			route.clear()
			mode = "rest"
			at_favorite = false
			remaining = 5
			break
		previous = p
	visible = true
	_pose(not route.is_empty())
	_sync_obstacle()
	return true
