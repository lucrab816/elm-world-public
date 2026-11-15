extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# A short encounter is created only when both residents are actually nearby and free.
const Neighbor = preload("res://neighbor.gd")
const Journal = preload("res://life_journal.gd")
const DURATION := 4.0
const COOLDOWN := 120.0
var phase := "idle"
var remaining := 0.0
var cooldown := 15.0
var next_id := 1
var latest: Dictionary = {}
func active() -> bool: return phase=="greeting"
func _actor(world) -> Vector2: return Vector2(world.resident.position.x,world.resident.position.z)
func _eligible(world) -> bool:
	return world.resident.mode=="observe" and world.resident.route.is_empty() and not world.resident.user_action.active() and not world.resident.ride_requested and not world.pet_companion.active() and not world.pet_companion.requested and (world.needs==null or (not world.needs.wants_meal() and world.needs.energy>=30))
func advance(world, delta: float, seconds: float) -> bool:
	cooldown = maxf(0,cooldown-delta)
	var distance: float = world.neighbor.flat().distance_to(_actor(world))
	if active():
		if not _eligible(world) or world.neighbor.mode!="greeting" or distance<.35 or distance>1.4 or not world.neighbor._car_clear(world.neighbor.flat()):
			_finish(world,seconds,false)
			return false
	else:
		if cooldown>0 or not _eligible(world) or world.neighbor.mode!="rest" or distance<.35 or distance>1.4: return false
		phase = "greeting"
		remaining = DURATION
		latest = {"id":next_id,"phase":"greeting","started_seconds":floorf(seconds)}
		next_id += 1
		world.neighbor.mode = "greeting"
		_note(world,"greet_started",seconds)
	world.resident.elapsed += delta
	world.neighbor.elapsed += delta
	remaining = maxf(0,remaining-delta)
	var direction: Vector2 = world.neighbor.flat()-_actor(world)
	world.resident.rotation.y = atan2(direction.x,direction.y)
	world.neighbor.rotation.y = world.resident.rotation.y+PI
	world.resident._pose_stand()
	world.resident.right_arm.rotation.x = -2.2 + sin((DURATION-remaining)*5)*.18
	world.neighbor._pose(false)
	world.neighbor.right_arm.rotation.x = -2.2 + sin((DURATION-remaining)*5+.5)*.18
	world.resident._emit_activity("和米娅挥手打招呼")
	if remaining<=0: _finish(world,seconds,true)
	return true
func _note(world, kind: String, seconds: float) -> void:
	world.neighbor._note(kind,seconds,int(latest.id))
	world.resident.recent_events.append(Neighbor.ID+":"+kind+":"+str(int(latest.id)))
	while world.resident.recent_events.size()>24: world.resident.recent_events.pop_front()
	if world.journal_enabled and world.journal.record(Neighbor.ID,"米娅身边",kind,seconds): world.keepsakes.record(kind,seconds)
func _finish(world, seconds: float, completed: bool) -> void:
	latest.phase = "completed" if completed else "cancelled"
	latest.finished_seconds = floorf(seconds)
	_note(world,"greet_done" if completed else "greet_cancelled",seconds)
	world.neighbor.mode = "rest"
	world.neighbor._pose(false)
	world.resident._pose_stand()
	world.resident._emit_activity("和米娅打过招呼，继续自己的日常" if completed else "先处理手头的事情，暂时停下招呼")
	phase = "idle"
	remaining = 0
	cooldown = COOLDOWN
func status() -> String:
	return "埃尔和米娅正在挥手打招呼" if active() else ""
func recall() -> String:
	if latest.is_empty(): return "还没有保留与米娅打招呼的记录。"
	var label := "第%d天 %s（世界时间）"%[Calendar.day_at(float(latest.started_seconds)),Journal.clock_text(float(latest.started_seconds))]
	if latest.phase=="completed": return label+"，我和米娅见面并挥手打了招呼。"
	if latest.phase=="greeting": return label+"开始的打招呼还在进行中。"
	return label+"开始的打招呼中途停下了，没有完成。"
func snapshot() -> Dictionary:
	return {"version":1,"phase":phase,"remaining":remaining,"cooldown":cooldown,"next_id":next_id,"latest":latest.duplicate(true)}
static func valid_snapshot(value: Variant, now: float, actor: Dictionary, npc: Dictionary, pet: Dictionary) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("phase") not in ["idle","greeting"]: return false
	for key in ["remaining","cooldown","next_id"]:
		if not Neighbor.number(value.get(key)): return false
	if value.remaining>DURATION or value.cooldown>COOLDOWN or value.next_id<1 or value.next_id!=floor(value.next_id) or not value.get("latest") is Dictionary: return false
	var event: Dictionary = value.latest
	if event.is_empty():
		if value.next_id!=1: return false
	else:
		if not Neighbor.number(event.get("id")) or event.id!=value.next_id-1 or event.id!=floor(event.id) or event.get("phase") not in ["greeting","completed","cancelled"]: return false
		if not Neighbor.number(event.get("started_seconds")) or event.started_seconds>now: return false
		if event.phase in ["completed","cancelled"]:
			if not Neighbor.number(event.get("finished_seconds")) or event.finished_seconds<event.started_seconds or event.finished_seconds>now: return false
		elif event.has("finished_seconds"): return false
	if value.phase=="idle": return value.remaining==0 and npc.get("mode")!="greeting" and (event.is_empty() or event.phase in ["completed","cancelled"])
	if event.is_empty() or event.phase!="greeting" or value.remaining<=0 or npc.get("mode")!="greeting" or actor.get("mode")!="observe" or not actor.get("route",[]).is_empty() or pet.get("phase","idle")!="idle": return false
	if actor.get("user_action",{}).get("latest",{}).get("phase","") not in ["","queued","completed","failed"]: return false
	if not npc.get("events",[]).any(func(e): return e.get("kind")=="greet_started" and e.get("interaction_id")==event.id and e.get("seconds")==event.started_seconds): return false
	if not actor.get("recent_events",[]).has(Neighbor.ID+":greet_started:"+str(int(event.id))): return false
	var distance := Vector2(actor.position[0],actor.position[1]).distance_to(Vector2(npc.position[0],npc.position[1]))
	return distance>=.35 and distance<=1.4
func restore(value: Dictionary) -> void:
	phase = value.phase
	remaining = float(value.remaining)
	cooldown = float(value.cooldown)
	next_id = int(value.next_id)
	latest = value.latest.duplicate(true)
