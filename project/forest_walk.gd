extends RefCounted
const BASKET := preload("res://window_storage.gd").MATERIALS
const BASKET_STAND := Vector2(2,-2.5)
const GATE := Vector2(-7.5,4.5)
const ForestLand = preload("res://forest_land.gd")
var phase := "idle"
var route: Array = []
var home := Vector2.ZERO
var pause := 0.0
var next_trip := 0.0
var trips := 0
var cargo := ""
var carrying_bench := false
var trip_kind := "routine"
var rest_requested := false
var explore_requested := false
var last_exploration := ""
var supplies := {"松果":0,"落枝":0,"小石子":0}
func active() -> bool: return phase!="idle"
func exploring() -> bool: return trip_kind in ["explore","chosen_explore"]
func advance(world, delta: float, now: float) -> bool:
	var actor = world.resident
	if not active():
		if world.shelter_from_rain: return false
		if now<next_trip or world.vegetable_project._new_job(now)!="" or world.elm_gardening._new_job(now)!="" or not world.elm_gardening._safe(world) or world.needs.satiety<75 or world.needs.energy<65 or world.vegetable_project.meeting or world.elm_gardening.active() or world.vegetable_project.active(): return false
		home = Vector2(actor.position.x,actor.position.z)
		var path = world.navigation.path(home,GATE,.28,Vector2(world.car.position.x,world.car.position.z),1.75)
		next_trip = floorf(now)+900
		if path.is_empty() or path[-1].distance_to(GATE)>.01: return false
		route.clear()
		if not explore_requested and world.life_plan.ready_to_pack(world):
			var first = world.navigation.path(home,BASKET_STAND,.28,Vector2(world.car.position.x,world.car.position.z),1.75)
			var second = world.navigation.path(BASKET_STAND,GATE,.28,Vector2(world.car.position.x,world.car.position.z),1.75)
			if not first.is_empty() and first[-1].distance_to(BASKET_STAND)<.01:
				for p in first: route.append([p.x,p.y])
				path = second
		for p in path: route.append([p.x,p.y])
		var clearing: Vector2 = world.life_plan.destination()
		trip_kind = "rest" if rest_requested and world.life_plan.stages==3 else "routine"
		if trip_kind=="rest": rest_requested = false
		if world.life_plan.move_requested and not world.life_plan.bench_moved:
			trip_kind = "move_bench"
			rest_requested = false
		if explore_requested and trip_kind=="routine":
			explore_requested = false
			trip_kind = "chosen_explore"
		if exploring() or world.life_plan.bench_moved or (trip_kind=="routine" and (world.life_plan.selected.is_empty() or world.life_plan.stages==3) and trips%2==0):
			if trip_kind=="routine" and trips%2==0: trip_kind = "explore"
			for point in ForestLand.TRAIL: route.append([point.x,point.y])
		else:
			if clearing.x<-11:
				for i in range(ForestLand.nearest_trail_index(clearing)+1):
					var point: Vector2 = ForestLand.TRAIL[i]
					route.append([point.x,point.y])
			route.append([clearing.x,clearing.y])
		phase = "outward"
	if phase=="packing":
		actor._pose_stand()
		actor._emit_activity("从材料篮准备自己规划的林间建设材料")
		pause = maxf(0,pause-delta)
		if pause>0: return true
		world.life_plan.pack(world)
		phase = "outward"
	if phase=="looking" and trip_kind=="move_bench":
		if not carrying_bench:
			carrying_bench = true
			for i in range(ForestLand.nearest_trail_index(Vector2(actor.position.x,actor.position.z)),ForestLand.TRAIL.size()):
				var point: Vector2 = ForestLand.TRAIL[i]
				route.append([point.x,point.y])
			phase = "outward"
		else:
			carrying_bench = false
			world.life_plan.move_requested = false
			world.life_plan.bench_moved = true
			world.journal.record("forest.rest_corner","林间休息角","corner_bench_moved",now)
			_begin_return(Vector2(actor.position.x,actor.position.z))
		return true
	if phase=="looking":
		if not exploring() and world.life_plan.work(world,delta,now): return true
		if exploring() or world.life_plan.stages<3: actor._pose_stand()
		if exploring() or world.life_plan.stages<3: actor._emit_activity("在林间看看，找找落在地上的小东西")
		pause -= delta
		if pause<=0:
			if randf()<.65:
				cargo = supplies.keys().pick_random()
				actor._emit_activity("捡起一份"+cargo+"，准备带回家")
			if not exploring() and world.life_plan.stages==3 and world.journal_enabled:
				world.journal.record("forest.rest_corner","林间休息角","corner_rest_chosen" if trip_kind=="rest" else "corner_rest_routine",now)
			_begin_return(Vector2(actor.position.x,actor.position.z))
		return true
	if phase=="unloading":
		actor._pose_stand()
		actor.rotation.y = PI
		actor.right_arm.rotation.x = -.9
		actor._emit_activity("把带回的"+cargo+"放进材料篮")
		pause = maxf(0,pause-delta)
		if pause>0: return true
	if route.is_empty():
		if phase=="outward":
			phase = "looking"
			pause = 20 if not exploring() and world.life_plan.stages==3 else 8
			if not exploring() and trip_kind!="move_bench" and world.life_plan.stages==3: world.life_plan.visits += 1
		elif phase=="returning" and not cargo.is_empty():
			phase = "unloading"
			pause = 2
		else:
			phase = "idle"
			trips += 1
			if trip_kind=="chosen_explore":
				last_exploration = "深入树林散步后回到小院，"+("带回一份"+cargo+"。" if not cargo.is_empty() else "这趟空手回来。")
				if world.journal_enabled: world.journal.record("forest.deep","树林深处","forest_explore_chosen",now)
			if not cargo.is_empty(): supplies[cargo] += 1
			cargo = ""
			next_trip = floorf(now)+900
			actor.remaining = 3
			actor._pose_stand()
		return true
	var target := Vector2(route[0][0],route[0][1])
	var here := Vector2(actor.position.x,actor.position.z)
	# Cars remain inside the yard. Wait if a parked car blocks the walking route.
	if here.x>=GATE.x and target.x>=GATE.x and not world.neighbor._car_clear(target): return true
	var point := here.move_toward(target,1.05*delta)
	var direction := point-here
	if direction.length()>.001: actor.rotation.y = atan2(direction.x,direction.y)
	actor.position.x = point.x
	actor.position.z = point.y
	actor._sync_height()
	actor._walk_pose_step(delta)
	if carrying_bench:
		actor.left_arm.rotation.x = -1
		actor.right_arm.rotation.x = -1
	actor._emit_activity("把木凳搬向树林深处" if carrying_bench else ("沿林间小路走向树林深处" if exploring() and phase=="outward" else ("沿林间小路散步" if phase=="outward" else "沿小路回家")))
	if point.distance_to(target)<.001:
		actor.position.x = target.x
		actor.position.z = target.y
		route.pop_front()
		if phase=="outward" and target==BASKET_STAND:
			phase = "packing"
			pause = 2
		if phase=="returning" and target==GATE:
			var path = world.navigation.path(GATE,BASKET_STAND if not cargo.is_empty() else home,.28,Vector2(world.car.position.x,world.car.position.z),1.75)
			for p in path:
				if p.distance_to(GATE)>.001: route.append([p.x,p.y])
	return true
func _begin_return(from: Vector2) -> void:
	route.clear()
	if from.x<-11:
		for i in range(ForestLand.nearest_trail_index(from),-1,-1):
			var point: Vector2 = ForestLand.TRAIL[i]
			route.append([point.x,point.y])
	route.append([GATE.x,GATE.y])
	phase = "returning"

func snapshot() -> Dictionary:
	return {"phase":phase,"route":route.duplicate(true),"home":[home.x,home.y],"pause":maxf(pause,0),"next_trip":next_trip,"trips":trips,"cargo":cargo,"trip_kind":trip_kind,"carrying_bench":carrying_bench,"rest_requested":rest_requested,"explore_requested":explore_requested,"last_exploration":last_exploration,"supplies":supplies.duplicate()}
func restore(value: Dictionary) -> void:
	phase = value.phase
	route = value.route.duplicate(true)
	home = Vector2(value.home[0],value.home[1])
	pause = float(value.pause)
	next_trip = float(value.next_trip)
	trips = int(value.trips)
	cargo = value.get("cargo","")
	carrying_bench = value.get("carrying_bench",false)
	trip_kind = value.get("trip_kind","routine")
	rest_requested = value.get("rest_requested",false)
	explore_requested = value.get("explore_requested",false)
	last_exploration = value.get("last_exploration","")
	supplies = value.supplies.duplicate()
func description() -> String:
	return "林间散步%s；已回家%d次。带回的材料：松果%d，落枝%d，小石子%d。"%["进行中" if active() else "休息中",trips,supplies["松果"],supplies["落枝"],supplies["小石子"]]
static func valid(value: Variant, now: float) -> bool:
	if not value is Dictionary or value.get("phase") not in ["idle","outward","looking","returning","unloading","packing"]: return false
	if not value.get("carrying_bench",false) is bool: return false
	if value.get("carrying_bench",false) and (value.get("trip_kind")!="move_bench" or value.phase not in ["outward","looking"]): return false
	if not value.get("explore_requested",false) is bool or not value.get("last_exploration","") is String or str(value.get("last_exploration","")).length()>160: return false
	if value.get("trip_kind","routine") not in ["routine","explore","chosen_explore","rest","move_bench"] or not value.get("rest_requested",false) is bool: return false
	if value.get("cargo","") not in ["","松果","落枝","小石子"]: return false
	if not value.get("route") is Array or value.route.size()>1000 or not value.get("supplies") is Dictionary: return false
	for key in ["pause","next_trip","trips"]:
		if not preload("res://life_journal.gd").number(value.get(key)): return false
	if value.pause>20 or value.next_trip>maxf(900,now+900) or value.trips!=floor(value.trips): return false
	var points: Array = value.route.duplicate()
	points.append(value.get("home"))
	for point in points:
		if not point is Array or point.size()!=2: return false
		for n in point:
			if not (n is int or n is float) or not is_finite(float(n))  : return false
		if (absf(point[0])>11 or absf(point[1])>11) and not ForestLand.contains_trail_point(Vector2(point[0],point[1])): return false
	for key in ["松果","落枝","小石子"]:
		var n = value.supplies.get(key)
		if not preload("res://life_journal.gd").number(n) or n!=floor(n): return false
	return true
