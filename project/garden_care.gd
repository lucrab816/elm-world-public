extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# One actual action on the existing garden bed; no harvest or simulated growth.
const Neighbor = preload("res://neighbor.gd")
const Journal = preload("res://life_journal.gd")
const BED_ID := "garden.bed.001"
const EDGE := Vector2(-6,2)
const DURATION := 8.0
const COOLDOWN := 180.0
const WET_SECONDS := 180.0
var phase := "idle"
var remaining := 0.0
var cooldown := 20.0
var next_id := 1
var latest: Dictionary = {}
var water_count := 0
var last_completed_seconds = null
var wet_until := 0.0
func active() -> bool: return phase=="watering"
static func _at_bed(point: Vector2) -> bool:
	return (point.distance_to(EDGE)<.75 and absf(point.x-EDGE.x)<.32 and point.y>=1.2 and point.y<=2.12) or preload("res://vegetable_project.gd").STANDS.any(func(p): return point.distance_to(p)<.35)
func _eligible(world) -> bool:
	return world.resident.mode!="drive" and world.neighbor._car_clear(world.neighbor.flat()) and _at_bed(world.neighbor.flat()) and world.navigation.clear_point(world.neighbor.flat(),.28)
func _plot(world):
	for plot in world.vegetable_plots:
		if world.neighbor.flat().distance_to(plot.work_position)<.35: return plot.current_crop()
	return null
func advance(world, delta: float, seconds: float) -> bool:
	cooldown = maxf(0,cooldown-delta)
	if world.shelter_from_rain:
		if active(): _finish(world,seconds,false)
		return false
	if active():
		if world.neighbor.mode!="watering" or not _eligible(world):
			_finish(world,seconds,false)
			return false
	else:
		if cooldown>0 or world.neighbor.mode!="rest" or not _eligible(world): return false
		var plot = _plot(world)
		if plot==null or not plot.planted or plot.stage==3 or plot.active() or (plot.last_water>=0 and Calendar.day_at(plot.last_water)==Calendar.day_at(seconds)): return false
		phase = "watering"
		remaining = DURATION
		latest = {"id":next_id,"phase":"watering","started_seconds":floorf(seconds)}
		next_id += 1
		world.neighbor.mode = "watering"
		world.neighbor._note("water_started",seconds,int(latest.id))
	world.neighbor.elapsed += delta
	remaining = maxf(0,remaining-delta)
	world.neighbor.rotation.y = PI/2
	world.neighbor._pose_water(DURATION-remaining)
	if remaining<=0: _finish(world,seconds,true)
	return true
func _finish(world, seconds: float, completed: bool) -> void:
	latest.phase = "completed" if completed else "cancelled"
	latest.finished_seconds = floorf(seconds)
	world.neighbor._note("water_done" if completed else "water_cancelled",seconds,int(latest.id))
	if completed:
		var plot = _plot(world)
		if plot!=null and plot.water_today(seconds):
			plot._record(world,"flower_watered",seconds)
		water_count = mini(water_count+1,1000000000)
		last_completed_seconds = floorf(seconds)
		wet_until = floorf(seconds)+WET_SECONDS
	world.neighbor.mode = "rest"
	world.neighbor._pose(false)
	phase = "idle"
	remaining = 0
	cooldown = COOLDOWN
func recall() -> String:
	var lines: PackedStringArray = []
	if last_completed_seconds==null:
		lines.append("还没有保留米娅完成浇水的记录。")
	else:
		var t: float = float(last_completed_seconds)
		lines.append("米娅最近一次在第%d天 %s（世界时间）浇过菜地；已记录%d次完成。"%[Calendar.day_at(t),Journal.clock_text(t),water_count])
	if phase=="watering": lines.append("她现在正在浇水，这次还没有完成。")
	elif latest.get("phase")=="cancelled": lines.append("最近一次尝试中途停下，没有算作完成。")
	return "\n".join(lines)
func snapshot() -> Dictionary:
	return {"version":1,"bed_id":BED_ID,"phase":phase,"remaining":remaining,"cooldown":cooldown,"next_id":next_id,"latest":latest.duplicate(true),"water_count":water_count,"last_completed_seconds":last_completed_seconds,"wet_until":wet_until}
static func valid_snapshot(value: Variant, now: float, npc: Dictionary, greeting: Dictionary) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("bed_id")!=BED_ID or value.get("phase") not in ["idle","watering"]: return false
	for key in ["remaining","cooldown","next_id","water_count","wet_until"]:
		if not Neighbor.number(value.get(key)): return false
	if value.remaining>DURATION or value.cooldown>COOLDOWN or value.next_id<1 or value.next_id!=floor(value.next_id) or value.water_count>1000000000 or value.water_count>value.next_id-1 or value.water_count!=floor(value.water_count) or not value.get("latest") is Dictionary: return false
	if value.water_count==0:
		if value.get("last_completed_seconds")!=null or value.wet_until!=0: return false
	else:
		if not Neighbor.number(value.get("last_completed_seconds")) or value.last_completed_seconds<npc.get("born_seconds",0) or value.last_completed_seconds>now or value.wet_until!=value.last_completed_seconds+WET_SECONDS: return false
	var event: Dictionary = value.latest
	if event.is_empty():
		if value.next_id!=1 or value.water_count!=0: return false
	else:
		if not Neighbor.number(event.get("id")) or event.id!=value.next_id-1 or event.id!=floor(event.id) or event.get("phase") not in ["watering","completed","cancelled"]: return false
		if not Neighbor.number(event.get("started_seconds")) or event.started_seconds>now: return false
		if event.phase in ["completed","cancelled"]:
			if not Neighbor.number(event.get("finished_seconds")) or event.finished_seconds<event.started_seconds or event.finished_seconds>now: return false
			if event.phase=="completed" and (value.last_completed_seconds!=event.finished_seconds or value.water_count<1): return false
		elif event.has("finished_seconds"): return false
		if event.phase!="completed" and value.last_completed_seconds!=null and value.last_completed_seconds>event.started_seconds: return false
	if value.phase=="idle": return value.remaining==0 and npc.get("mode")!="watering" and (event.is_empty() or event.phase in ["completed","cancelled"])
	if event.is_empty() or event.phase!="watering" or value.remaining<=0 or npc.get("mode")!="watering" or greeting.get("phase","idle")!="idle": return false
	if not npc.get("events",[]).any(func(e): return e.get("kind")=="water_started" and e.get("interaction_id")==event.id and e.get("seconds")==event.started_seconds): return false
	var point := Vector2(npc.position[0],npc.position[1])
	return _at_bed(point) or [Vector2(-7,3),Vector2(-7,4),Vector2(-7,5)].any(func(p): return point.distance_to(p)<.35) or preload("res://vegetable_project.gd").LEGACY_STANDS.any(func(p): return point.distance_to(p)<.35)
func restore(value: Dictionary) -> void:
	phase = value.phase
	remaining = float(value.remaining)
	cooldown = float(value.cooldown)
	next_id = int(value.next_id)
	latest = value.latest.duplicate(true)
	water_count = int(value.water_count)
	last_completed_seconds = value.last_completed_seconds
	wet_until = float(value.wet_until)
