extends RefCounted
# Mia can actually visit Elm's bloomed flower once. No invented remote conversation.
const Gardening = preload("res://elm_gardening.gd")
const Neighbor = preload("res://neighbor.gd")
const STAND := Vector2(2.5,-2.5)
const OLD_STAND := Vector2(-2.5,5)
var phase := "idle"
var route: Array = []
var remaining := 0.0
var next_check := 0.0
var visited_at := -1.0
func active() -> bool: return phase in ["walking","looking"]
func _safe(world) -> bool:
	return world.neighbor_enabled and world.elm_gardening.stage==3 and world.elm_gardening.get("wilted_at")==-1 and world.resident.mode!="drive" and not world.neighbor_greeting.active() and not world.garden_care.active() and not world.mia_rabbit.active() and world.neighbor._car_clear(world.neighbor.flat()) and world.neighbor._car_clear(STAND)
func _cancel(world, now: float) -> void:
	phase = "idle"
	route.clear()
	remaining = 0
	next_check = floorf(now)+30
	if world.neighbor.mode=="flower_visit":
		world.neighbor.mode = "rest"
		world.neighbor.remaining = 4
		world.neighbor._pose(false)
func advance(world, delta: float, now: float) -> bool:
	if visited_at>=0 or not world.elm_gardening.enabled: return false
	if active() and (not _safe(world) or world.neighbor.mode!="flower_visit"):
		_cancel(world,now)
		return false
	if not active():
		if now<next_check: return false
		next_check = floorf(now)+30
		if not _safe(world) or world.neighbor.mode!="rest": return false
		var path: PackedVector2Array = world.navigation.path(world.neighbor.flat(),STAND,.28,Vector2(world.car.position.x,world.car.position.z),1.75)
		if path.is_empty() or path[-1].distance_to(STAND)>.1: return false
		route = []
		for point in path: route.append([point.x,point.y])
		phase = "walking"
		world.neighbor.mode = "flower_visit"
		world.neighbor.route.clear()
		world.neighbor.destination = ""
	world.neighbor.elapsed += delta
	if phase=="walking":
		var point := Vector2(route[0][0],route[0][1])
		var here: Vector2 = world.neighbor.flat()
		if not world.navigation.safe_segment(here,point,.28) or not world.neighbor._car_clear(point):
			_cancel(world,now)
			return false
		var direction := point-here
		if direction.length()>.001: world.neighbor.rotation.y = atan2(direction.x,direction.y)
		world.neighbor._place(here.move_toward(point,.65*delta))
		world.neighbor._pose(true)
		if world.neighbor.flat().distance_to(point)<.001:
			route.pop_front()
			if route.is_empty(): phase = "looking"; remaining = 6
	else:
		world.neighbor._pose(false)
		var direction: Vector2 = Gardening.POT-world.neighbor.flat()
		world.neighbor.rotation.y = atan2(direction.x,direction.y)
		world.neighbor.right_arm.rotation.x = -.9
		remaining = maxf(0,remaining-delta)
		if remaining<=0:
			visited_at = floorf(now)
			phase = "done"
			world.neighbor._note("elm_flower_seen",now)
			if world.journal_enabled: world.journal.record(Neighbor.ID,"埃尔的小花圃","flower_neighbor_seen",now)
			world.neighbor.mode = "rest"
			world.neighbor.remaining = 8
			world.neighbor._pose(false)
	world.neighbor._sync_obstacle()
	return true
func description() -> String:
	if visited_at>=0: return "米娅已经亲自走到花圃，看过埃尔养开的花。没有记录她与埃尔的一段聊天。"
	if active(): return "米娅正走过去看花，还没有完成这次到访。" if phase=="walking" else "米娅正在花圃旁看看，尚未完成到访。"
	return "米娅还没有实际到访这盆花。"
func snapshot() -> Dictionary:
	return {"version":1,"phase":phase,"route":route.duplicate(true),"remaining":remaining,"next_check":next_check,"visited_at":visited_at}
func restore(v: Dictionary) -> void:
	phase = v.phase
	route = v.route.duplicate(true)
	remaining = float(v.remaining)
	next_check = float(v.next_check)
	visited_at = float(v.visited_at)
static func valid_snapshot(v: Variant, now: float, npc: Dictionary, flower: Dictionary) -> bool:
	if not v is Dictionary or v.get("version")!=1 or v.get("phase") not in ["idle","walking","looking","done"] or not Neighbor.number(v.get("remaining")) or v.remaining>6 or not Neighbor.number(v.get("next_check")) or v.next_check>now+30 or not v.get("route") is Array or v.route.size()>1000: return false
	if not (v.get("visited_at") is int or v.get("visited_at") is float): return false
	for point in v.route:
		if not Neighbor.point(point): return false
	if v.phase=="done": return v.route.is_empty() and v.remaining==0 and Neighbor.number(v.visited_at) and v.visited_at<=now and (flower.has("cycles") or flower.get("stage")==3)
	if v.visited_at!=-1: return false
	if v.phase=="idle": return v.route.is_empty() and v.remaining==0 and npc.get("mode")!="flower_visit"
	if flower.get("stage")!=3 or npc.get("mode")!="flower_visit": return false
	if v.phase=="walking": return not v.route.is_empty() and v.remaining==0
	if Vector2(npc.position[0],npc.position[1]).distance_to(Vector2(2.5,-1.5))<.1: return v.route.is_empty() and v.remaining>0
	return v.route.is_empty() and v.remaining>0 and minf(Vector2(npc.position[0],npc.position[1]).distance_to(STAND),Vector2(npc.position[0],npc.position[1]).distance_to(OLD_STAND))<.1
