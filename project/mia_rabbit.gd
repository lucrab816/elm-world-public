extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# A short local encounter. Elm remains independent, and no unseen event is added to his diary.
const Neighbor = preload("res://neighbor.gd")
const Rabbit = preload("res://rabbit.gd")
const Journal = preload("res://life_journal.gd")
const DURATION := 5.0
const COOLDOWN := 300.0
var phase := "idle"
var remaining := 0.0
var cooldown := 30.0
var next_id := 1
var latest: Dictionary = {}
func active() -> bool: return phase=="petting"
func _safe(world) -> bool:
	var distance: float = world.neighbor.flat().distance_to(world.rabbit.flat())
	return world.resident.mode!="drive" and not world.pet_companion.active() and not world.pet_companion.requested and distance>=.4 and distance<=.95 and world.neighbor._car_clear(world.neighbor.flat()) and world.rabbit._car_clear(world.rabbit.flat())
func advance(world, delta: float, seconds: float) -> bool:
	cooldown = maxf(0,cooldown-delta)
	if active():
		if world.neighbor.mode!="pet_rabbit" or world.rabbit.mode!="mia_pet" or not _safe(world):
			cancel(world,seconds)
			return false
	else:
		if cooldown>0 or world.neighbor.mode!="rest" or world.rabbit.mode!="rest" or not _safe(world): return false
		phase = "petting"
		remaining = DURATION
		latest = {"id":next_id,"phase":"petting","started_seconds":floorf(seconds)}
		next_id += 1
		world.neighbor.mode = "pet_rabbit"
		world.rabbit.mode = "mia_pet"
		world.rabbit.at_favorite = false
		_note(world,"mia_pet_started",seconds)
	world.neighbor.elapsed += delta
	world.rabbit.elapsed += delta
	remaining = maxf(0,remaining-delta)
	var direction: Vector2 = world.rabbit.flat()-world.neighbor.flat()
	world.neighbor.rotation.y = atan2(direction.x,direction.y)
	world.rabbit.rotation.y = world.neighbor.rotation.y+PI
	world.neighbor._pose_pet_rabbit(DURATION-remaining)
	world.rabbit._pose(false)
	world.rabbit.ears[0].rotation.x = -.15
	world.rabbit.ears[1].rotation.x = -.15
	if remaining<=0: _finish(world,seconds,true)
	return true
func _note(world, kind: String, seconds: float) -> void:
	world.neighbor._note(kind,seconds,int(latest.id))
	world.rabbit._note(kind,seconds,int(latest.id))
func cancel(world, seconds: float) -> void:
	if active(): _finish(world,seconds,false)
func _finish(world, seconds: float, completed: bool) -> void:
	latest.phase = "completed" if completed else "cancelled"
	latest.finished_seconds = floorf(seconds)
	_note(world,"mia_pet_done" if completed else "mia_pet_cancelled",seconds)
	world.neighbor.mode = "rest"
	world.neighbor._pose(false)
	if world.rabbit.mode=="mia_pet":
		world.rabbit.mode = "rest"
		world.rabbit.remaining = maxf(1,world.rabbit.remaining)
		world.rabbit._pose(false)
	phase = "idle"
	remaining = 0
	cooldown = COOLDOWN
func recall() -> String:
	if latest.is_empty(): return "小院里还没有保留米娅和德雷克相处的记录。"
	var label := "第%d天 %s（世界时间）"%[Calendar.day_at(float(latest.started_seconds)),Journal.clock_text(float(latest.started_seconds))]
	if latest.phase=="completed": return "小院记录："+label+"，米娅轻轻摸了摸德雷克。"
	if latest.phase=="petting": return "小院记录："+label+"开始的陪伴还在进行。"
	return "小院记录："+label+"开始的陪伴中途停下，没有完成。"
func snapshot() -> Dictionary:
	return {"version":1,"phase":phase,"remaining":remaining,"cooldown":cooldown,"next_id":next_id,"latest":latest.duplicate(true)}
static func valid_snapshot(value: Variant, now: float, npc: Dictionary, bunny: Dictionary, elm_pet: Dictionary) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("phase") not in ["idle","petting"]: return false
	for key in ["remaining","cooldown","next_id"]:
		if not Neighbor.number(value.get(key)): return false
	if value.remaining>DURATION or value.cooldown>COOLDOWN or value.next_id<1 or value.next_id!=floor(value.next_id) or not value.get("latest") is Dictionary: return false
	var event: Dictionary = value.latest
	if event.is_empty():
		if value.next_id!=1: return false
	else:
		if not Neighbor.number(event.get("id")) or event.id!=value.next_id-1 or event.id!=floor(event.id) or event.get("phase") not in ["petting","completed","cancelled"]: return false
		if not Neighbor.number(event.get("started_seconds")) or event.started_seconds>now or event.started_seconds<npc.born_seconds or event.started_seconds<bunny.born_seconds: return false
		if event.phase in ["completed","cancelled"]:
			if not Neighbor.number(event.get("finished_seconds")) or event.finished_seconds<event.started_seconds or event.finished_seconds>now: return false
		elif event.has("finished_seconds"): return false
	if value.phase=="idle": return value.remaining==0 and npc.get("mode")!="pet_rabbit" and bunny.get("mode")!="mia_pet" and (event.is_empty() or event.phase in ["completed","cancelled"])
	if event.is_empty() or event.phase!="petting" or value.remaining<=0 or npc.get("mode")!="pet_rabbit" or bunny.get("mode")!="mia_pet" or elm_pet.get("phase","idle")!="idle": return false
	for actor in [npc,bunny]:
		if not actor.get("events",[]).any(func(e): return e.get("kind")=="mia_pet_started" and e.get("interaction_id")==event.id and e.get("seconds")==event.started_seconds): return false
	var distance := Vector2(npc.position[0],npc.position[1]).distance_to(Vector2(bunny.position[0],bunny.position[1]))
	return distance>=.4 and distance<=.95
func restore(value: Dictionary) -> void:
	phase = value.phase
	remaining = float(value.remaining)
	cooldown = float(value.cooldown)
	next_id = int(value.next_id)
	latest = value.latest.duplicate(true)
