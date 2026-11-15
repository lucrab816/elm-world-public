extends RefCounted

const Dining = preload("res://outdoor_dining.gd")
const MIA_SEAT := Vector2(5.05,-1.74)
const MIA_APPROACH := Vector2(6,-1.0)
var phase := ""
var last_visit := -1.0
var retry_at := 0.0
var remaining := 0.0
var mia_route := PackedVector2Array()
var elm_route := PackedVector2Array()

func advance(world, delta: float, now: float, occupied: bool) -> bool:
	var mia = world.neighbor
	var elm = world.resident
	var dining = world.dining
	var free: bool = not occupied and mia.visible and mia.mode=="rest" and mia.visit_until>now and dining.meal.is_empty() and dining.state.prepared.is_empty() and dining.state.order_until==0 and world.elm_gardening._safe(world) and world.hobbies.job.is_empty() and world.mailbox.reading_id.is_empty() and not world.border.active()
	if not free:
		if not phase.is_empty(): _finish(world)
		return false
	if phase.is_empty():
		if now<retry_at or mia.visit_until==last_visit or mia.visit_until-now<38: return false
		retry_at = now+8
		var parked := Vector2(world.car.position.x,world.car.position.z)
		if not mia._car_clear(MIA_SEAT) or not mia._car_clear(Dining.SEAT): return false
		mia_route = world.navigation.path(mia.flat(),MIA_APPROACH,.28,parked,1.75)
		elm_route = world.navigation.path(Vector2(elm.position.x,elm.position.z),Dining.SEAT_APPROACH,.28,parked,1.75)
		if mia_route.is_empty() or mia_route[-1]!=MIA_APPROACH or elm_route.is_empty() or elm_route[-1]!=Dining.SEAT_APPROACH: return false
		last_visit = mia.visit_until
		if mia.random.randf()>.64: return false

		phase = "approach"
		remaining = 24
	if phase=="approach":
		if not _walk(world,mia,mia_route,delta,true) or not _walk(world,elm,elm_route,delta,false):
			_finish(world)
			return false
		elm._emit_activity("和米娅走向院里的餐桌")
		if mia_route.is_empty() and elm_route.is_empty():
			if not mia._car_clear(MIA_SEAT) or not mia._car_clear(Dining.SEAT):
				_finish(world)
				return false
			mia._place(MIA_SEAT)
			elm.position.x = Dining.SEAT.x
			elm.position.z = Dining.SEAT.y
			elm._sync_height()
			phase = "chat"
			_sit(world,now)
	elif phase=="chat":
		_sit(world,now)
		remaining -= delta
		if remaining<=0:
			if world.journal_enabled:
				world.journal.record("yard.dining","户外餐桌","patio_chat",now)
			_finish(world)
	return true

func _sit(world, now: float) -> void:
	var mia = world.neighbor
	var elm = world.resident
	mia._pose(false)
	elm._pose_stand()
	mia.rotation.y = atan2(-1.05,Dining.TABLE_CENTER.z-.26)
	elm.rotation.y = 0
	mia.body.position.y = Dining.A03_SEATED_HIP_HEIGHT-.52
	elm.model.position.y = Dining.A03_SEATED_HIP_HEIGHT-Dining.ELM_HIP_PIVOT_HEIGHT
	for leg in [mia.left_leg,mia.right_leg,elm.left_leg,elm.right_leg]:
		leg.rotation.x = Dining.A03_SEATED_LEG_ANGLE
	var mia_talking := fmod(remaining,8)>4
	var arm: Node3D = mia.right_arm if mia_talking else elm.right_arm
	arm.rotation.x = -.38+sin(now*6)*.19
	elm._emit_activity("坐在餐桌旁和米娅聊天")

func _walk(world, actor, route: PackedVector2Array, delta: float, visitor: bool) -> bool:
	if route.is_empty(): return true
	var from := Vector2(actor.position.x,actor.position.z)
	if not world.neighbor._car_clear(route[0]) or not world.navigation.safe_segment(from,route[0],.28): return false
	var direction := route[0]-from
	if direction.length()>.001: actor.rotation.y = atan2(direction.x,direction.y)
	var point := from.move_toward(route[0],delta)
	actor.position = Vector3(point.x,world._height(point.x,point.y),point.y)
	if visitor:
		actor.elapsed += delta
		actor._pose(true)
	else:
		actor._walk_pose_step(delta)
	if point.distance_to(route[0])<.001: route.remove_at(0)
	return true

func _finish(world) -> void:
	if phase=="chat":
		var parked := Vector2(world.car.position.x,world.car.position.z)
		var grid: AStarGrid2D = world.navigation.make_grid(.28,parked,1.75)
		var mia_exit: Vector2i = world.navigation.nearest(grid,MIA_APPROACH)
		var elm_exit: Vector2i = world.navigation.nearest(grid,Dining.SEAT_APPROACH)
		if mia_exit.x>=0: world.neighbor._place(grid.get_point_position(mia_exit))
		if elm_exit.x>=0:
			var feet: Vector2 = grid.get_point_position(elm_exit)
			world.resident.position.x = feet.x
			world.resident.position.z = feet.y
			world.resident._sync_height()
	phase = ""
	mia_route.clear()
	elm_route.clear()
	world.neighbor._pose(false)
	world.resident._pose_stand()
