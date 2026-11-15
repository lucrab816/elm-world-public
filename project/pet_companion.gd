extends RefCounted
# One shared local interaction; never invents a completed touch from proximity alone.
const Rabbit = preload("res://rabbit.gd")
const DURATION := 6.0
const COOLDOWN := 120.0
var phase := "idle"
var remaining := 0.0
var cooldown := 15.0
var requested := false
var next_id := 1
var latest: Dictionary = {}
func active() -> bool: return phase!="idle"
func invite() -> bool:
	if requested or active(): return false
	requested = true
	cooldown = 0
	return true
func _eligible(world) -> bool:
	return world.resident.mode=="observe" and world.resident.route.is_empty() and not world.resident.user_action.active() and not world.resident.ride_requested and (world.needs==null or (not world.needs.wants_meal() and world.needs.energy>=30))
func advance(world, delta: float, seconds: float) -> bool:
	cooldown = maxf(0,cooldown-delta)
	if active():
		if not _eligible(world) or (phase=="petting" and (world.rabbit.mode!="petting" or (world.rabbit.flat().distance_to(_actor(world))>.82 or world.rabbit.flat().distance_to(_actor(world))<.4))) or not world.navigation.clear_point(world.rabbit.flat(),.22) or not world.rabbit._car_clear(world.rabbit.flat()):
			_finish(world,seconds,false)
			return false
	else:
		var near_home: bool = world.resident.current_location=="place.home_front"
		if cooldown>0 or world.rabbit.heading_to_bed() or world.rabbit.mode in ["feed_walk","feeding"] or not _eligible(world) or (not requested and not near_home) or world.rabbit.flat().distance_to(_actor(world))>6:
			return false
		if not _approach(world,seconds):
			cooldown = 5
			return false
	world.resident.elapsed += delta
	if phase=="approaching":
		world.rabbit.advance(delta,seconds)
		world.resident._pose_stand()
		remaining = maxf(0,remaining-delta)
		var distance: float = world.rabbit.flat().distance_to(_actor(world))
		if distance>=.4 and distance<=.82:
			phase = "petting"
			remaining = DURATION
			latest.phase = "petting"
			latest.started_seconds = floorf(seconds)
			world.rabbit.route.clear()
			world.rabbit.at_favorite = false
			world.rabbit.mode = "petting"
			_note(world,"pet_started",seconds)
		elif remaining<=0 or world.rabbit.route.is_empty():
			_finish(world,seconds,false)
	else:
		world.rabbit.elapsed += delta
		world.rabbit._pose(false)
		world.rabbit.model.scale.y *= .90
		world.rabbit.ears[0].rotation.x = -.15
		world.rabbit.ears[1].rotation.x = -.15
		remaining = maxf(0,remaining-delta)
		var direction: Vector2 = world.rabbit.flat()-_actor(world)
		world.resident.rotation.y = atan2(direction.x,direction.y)
		world.rabbit.rotation.y = world.resident.rotation.y+PI
		world.resident._pose_pet(DURATION-remaining)
		if remaining<=0: _finish(world,seconds,true)
	return true
func _actor(world) -> Vector2: return Vector2(world.resident.position.x,world.resident.position.z)
func _approach(world, seconds: float) -> bool:
	var actor := _actor(world)
	var bunny = world.rabbit
	# A nearby safe grid point is sufficient; Elm waits, nobody teleports.
	var target := Vector2.INF
	var best := INF
	for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.LEFT,Vector2.UP]:
		var candidate: Vector2 = actor+direction*.60
		var path: PackedVector2Array = world.navigation.path(bunny.flat(),candidate,.22,Vector2(world.car.position.x,world.car.position.z),1.65)
		if path.is_empty(): continue
		var end := path[path.size()-1]
		if end.distance_to(actor)<.4 or end.distance_to(actor)>.82 or not bunny._car_clear(end): continue
		if end.distance_squared_to(bunny.flat())<best:
			best = end.distance_squared_to(bunny.flat())
			target = end
	if not target.is_finite(): return false
	var distance: float = bunny.flat().distance_to(actor)
	if distance<.4 or distance>.82:
		if not bunny._start_path(target,"greet",seconds): return false
	else:
		bunny.route.clear()
		bunny.at_favorite = false
		bunny.mode = "rest"
	phase = "approaching"
	remaining = 20
	requested = false
	latest = {"id":next_id,"phase":"approaching","invited_seconds":floorf(seconds)}
	next_id += 1
	world.resident._emit_activity("等德雷克过来，陪它待一会儿")
	return true
func _note(world, kind: String, seconds: float) -> void:
	world.rabbit._note(kind,seconds,int(latest.id))
	world.resident.recent_events.append(Rabbit.ID+":"+kind+":"+str(int(latest.id)))
	while world.resident.recent_events.size()>24: world.resident.recent_events.pop_front()
	if world.journal_enabled:
		if world.journal.record(Rabbit.ID,"德雷克身边",kind,seconds): world.keepsakes.record(kind,seconds)
func _finish(world, seconds: float, completed: bool) -> void:
	latest.phase = "completed" if completed else "cancelled"
	latest.finished_seconds = floorf(seconds)
	if latest.has("started_seconds"):
		_note(world,"pet_done" if completed else "pet_cancelled",seconds)
	world.rabbit.route.clear()
	world.rabbit.at_favorite = false
	world.rabbit.mode = "rest"
	world.rabbit.remaining = 3
	world.rabbit._pose(false)
	world.resident._pose_stand()
	world.resident._sync_height()
	world.resident._emit_activity("摸摸德雷克，继续慢慢过今天" if completed else "先照顾好自己，稍后再陪德雷克")
	phase = "idle"
	remaining = 0
	cooldown = COOLDOWN
func status() -> String:
	if requested: return "等埃尔忙完，再陪德雷克一会儿"
	if phase=="approaching": return "埃尔在等德雷克靠近"
	if phase=="petting": return "埃尔蹲下来，轻轻摸摸德雷克"
	return ""
func snapshot() -> Dictionary:
	return {"version":1,"phase":phase,"remaining":remaining,"cooldown":cooldown,"requested":requested,"next_id":next_id,"latest":latest.duplicate(true)}
static func valid_snapshot(value: Variant, now: float, actor: Dictionary, bunny: Dictionary) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("phase") not in ["idle","approaching","petting"] or not value.get("requested") is bool:
		return false
	for key in ["remaining","cooldown","next_id"]:
		if not Rabbit.number(value.get(key)): return false
	if value.cooldown>COOLDOWN or value.remaining>20 or value.next_id<1 or value.next_id!=floor(value.next_id): return false
	if not value.get("latest") is Dictionary: return false
	var event: Dictionary = value.latest
	if not event.is_empty():
		if not Rabbit.number(event.get("id")) or event.id<1 or event.id!=value.next_id-1 or event.id!=floor(event.id) or event.get("phase") not in ["approaching","petting","completed","cancelled"]: return false
		if not Rabbit.number(event.get("invited_seconds")) or event.invited_seconds>now: return false
		if event.has("started_seconds") and (not Rabbit.number(event.started_seconds) or event.started_seconds<event.invited_seconds or event.started_seconds>now): return false
		if event.has("finished_seconds") and (not Rabbit.number(event.finished_seconds) or event.finished_seconds<event.get("started_seconds",event.invited_seconds) or event.finished_seconds>now): return false
		if event.phase in ["petting","completed"] and not event.has("started_seconds"): return false
		if event.phase in ["completed","cancelled"] and not event.has("finished_seconds"): return false
	elif value.next_id!=1: return false
	if value.phase=="idle":
		return value.remaining==0 and (event.is_empty() or event.phase in ["completed","cancelled"]) and bunny.get("mode") not in ["greet","petting"]
	if event.is_empty() or event.phase!=value.phase or event.has("finished_seconds") or value.remaining<=0 or value.requested or actor.get("mode")!="observe" or not actor.get("route",[]).is_empty(): return false
	if actor.get("ride_requested",false) or actor.get("user_action",{}).get("latest",{}).get("phase","") not in ["","completed","failed"]: return false
	if value.phase=="petting":
		if value.remaining>DURATION or bunny.get("mode")!="petting": return false
		if not bunny.get("events",[]).any(func(e): return e.get("kind")=="pet_started" and e.get("interaction_id")==event.id and e.get("seconds")==event.started_seconds): return false
		if not actor.get("recent_events",[]).has(Rabbit.ID+":pet_started:"+str(int(event.id))): return false
		var distance := Vector2(actor.position[0],actor.position[1]).distance_to(Vector2(bunny.position[0],bunny.position[1]))
		return distance>=.4 and distance<=.82
	return bunny.get("mode") in ["greet","rest"]
func restore(value: Dictionary) -> void:
	phase = value.phase
	remaining = float(value.remaining)
	cooldown = float(value.cooldown)
	requested = value.requested
	next_id = int(value.next_id)
	latest = value.latest.duplicate(true)
