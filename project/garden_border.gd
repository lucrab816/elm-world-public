extends RefCounted
const Crop = preload("res://vegetable_project.gd")
const Journal = preload("res://life_journal.gd")
const WORK_SECONDS := 12.0
var completed := 0
var reserved := false
var progress := 0.0
var phase := "idle"
var route: Array = []
var pickup_remaining := 2.0
var next_check := 0.0
func active() -> bool: return phase!="idle"
func advance(world, delta: float, now: float) -> bool:
	if completed==3: return false
	var actor = world.resident
	var safe: bool = world.elm_gardening._safe(world) and not world.elm_gardening.active() and not world.garden_care.active()
	if not safe:
		if active():
			phase = "idle"
			route.clear()
			actor._pose_stand()
			next_check = floorf(now)+30
		return false
	if not active():
		if now<next_check or world.needs.satiety<70 or world.needs.energy<60 or (not reserved and world.forest.supplies["落枝"]<1): return false
		next_check = floorf(now)+30
		var target: Vector2 = Crop.STANDS[completed] if reserved else world.forest.BASKET_STAND
		var path = world.navigation.path(Vector2(actor.position.x,actor.position.z),target,.28,Vector2(world.car.position.x,world.car.position.z),1.75)
		if path.is_empty() or path[-1].distance_to(target)>.01: return false
		route.clear()
		for p in path: route.append([p.x,p.y])
		phase = "walking" if reserved else "fetching"
		pickup_remaining = 2
	actor.elapsed += delta
	if phase in ["walking","fetching"]:
		var here := Vector2(actor.position.x,actor.position.z)
		var target := Vector2(route[0][0],route[0][1])
		if not world.navigation.safe_segment(here,target,.28) or not world.neighbor._car_clear(target):
			phase = "idle"
			route.clear()
			actor._pose_stand()
			return false
		var direction := target-here
		if direction.length()>.001: actor.rotation.y = atan2(direction.x,direction.y)
		var point := here.move_toward(target,1.05*delta)
		actor.position.x = point.x
		actor.position.z = point.y
		actor._sync_height()
		actor._walk_pose_step(delta)
		actor._emit_activity("拿着落枝，走去搭菜地围边")
		if point.distance_to(target)<.001:
			route.pop_front()
			if route.is_empty(): phase = "working" if reserved else "picking"
	elif phase=="picking":
		actor._pose_stand()
		actor.rotation.y = PI
		actor.right_arm.rotation.x = -.9
		actor._emit_activity("从材料篮取一份落枝")
		pickup_remaining = maxf(0,pickup_remaining-delta)
		if pickup_remaining<=0:
			var target: Vector2 = Crop.STANDS[completed]
			var path = world.navigation.path(Vector2(actor.position.x,actor.position.z),target,.28,Vector2(world.car.position.x,world.car.position.z),1.75)
			if world.forest.supplies["落枝"]<1 or path.is_empty() or path[-1].distance_to(target)>.01:
				phase = "idle"
				return false
			world.forest.supplies["落枝"] -= 1
			reserved = true
			route.clear()
			for point in path: route.append([point.x,point.y])
			phase = "walking"
	else:
		actor._pose_stand()
		actor.rotation.y = PI/2
		actor.model.position.y = -.15
		actor.right_arm.rotation.x = -.9+sin(progress*6)*.25
		actor._emit_activity("慢慢搭好第%d段菜地围边"%(completed+1))
		progress = minf(WORK_SECONDS,progress+delta)
		if progress>=WORK_SECONDS:
			completed += 1
			progress = 0
			reserved = false
			phase = "idle"
			next_check = floorf(now)+180
			actor._pose_stand()
			if world.journal_enabled: world.journal.record("garden.border.001","菜地围边","border_built",now)
	return true
func snapshot() -> Dictionary:
	return {"pickup_remaining":pickup_remaining,"completed":completed,"reserved":reserved,"progress":progress,"phase":phase,"route":route.duplicate(true),"next_check":next_check}
func restore(value: Dictionary) -> void:
	pickup_remaining = float(value.get("pickup_remaining",2))
	completed = int(value.completed)
	reserved = value.reserved
	progress = float(value.progress)
	phase = value.phase
	route = value.route.duplicate(true)
	next_check = float(value.next_check)
static func valid(v: Variant, now: float) -> bool:
	if not v is Dictionary or not Journal.number(v.get("completed")) or v.completed!=floor(v.completed) or v.completed>3 or not v.get("reserved") is bool or v.get("phase") not in ["idle","walking","working","fetching","picking"]: return false
	if not Journal.number(v.get("progress")) or v.progress>=WORK_SECONDS or not Journal.number(v.get("next_check")) or v.next_check>now+180: return false
	if not Journal.number(v.get("pickup_remaining",2)) or v.get("pickup_remaining",2)>2: return false
	if not v.get("route") is Array or v.route.size()>1000: return false
	for point in v.route:
		if not preload("res://neighbor.gd").point(point): return false
	if v.phase in ["walking","fetching"] and v.route.is_empty(): return false
	if v.phase not in ["walking","fetching"] and not v.route.is_empty(): return false
	if (v.phase in ["walking","working"] or v.progress>0) and not v.reserved: return false
	return v.completed<3 or (v.phase=="idle" and not v.reserved and v.progress==0)
func description() -> String:
	return "菜地木围边已搭好%d段，共三段。每段需要一份带回家的落枝，埃尔空闲吃饱后会自己继续。"%completed
