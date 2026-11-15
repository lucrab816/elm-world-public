extends RefCounted

const WindowStorage = preload("res://window_storage.gd")

const Calendar = preload("res://world_calendar.gd")
# Actual local gardening, with saved walking/action progress and growth measured in game days.
const Journal = preload("res://life_journal.gd")
const POT := WindowStorage.FLOWER
const STAND := Vector2(2,-2.5)
const OLD_STAND := Vector2(-1.5,5.0)
const THRESHOLDS := [0.0,75.0,210.0,420.0]
const STAGES := ["种下的种子","嫩芽","花苞","盛开的花"]
const WELL := Vector2(-6.7,-4.1)
const WELL_STAND := Vector2(-6.5,-3.0)
const CAN_CAPACITY := 3
const REFILL_SECONDS := 4.0
const DURATION := 8.0
const WET_SECONDS := 150.0
const MIN_BLOOM_DAYS := 5
const MAX_BLOOM_DAYS := 10
var plot_position := POT
var work_position := STAND
var crop_name := "花"
var enabled := false
var started_seconds := 0.0
var next_check := 0.0
var phase := "idle"
var job := "sow"
var route: Array = []
var remaining := 0.0
var planted := false
var planted_at := -1.0
var bloom_days := 0
var last_water := -1.0
var water_count := 0
var wet_until := 0.0
var growth := 0.0
var stage := 0
var milestones: Array = []
func start(now: float) -> void:
	enabled = true
	started_seconds = floorf(now)
	next_check = started_seconds+20
func active() -> bool: return phase!="idle"
func _safe(world, allow_hungry: bool = false, allow_tired: bool = false) -> bool:
	for plot in world.vegetable_plots:
		if plot!=self and plot.current_crop()!=self and (plot.active() or plot.meeting): return false
	return not world.forest.active() and world.resident.mode=="observe" and world.resident.route.is_empty() and not world.resident.user_action.active() and not world.resident.ride_requested and not world.pet_companion.active() and not world.pet_companion.requested and not world.neighbor_greeting.active() and not world.plant_visit.active() and not world.plant_routine.visit.active() and not world.self_arrangement.active() and world.model_decision_ticket.is_empty() and world.needs!=null and (allow_hungry or not world.needs.wants_meal()) and not world.needs.meal_active and (allow_tired or world.needs.energy>=40) and not world.quit_pending
func _cancel(world, now: float) -> void:
	phase = "idle"
	route.clear()
	remaining = 0
	next_check = floorf(now)+30
	world.resident._pose_stand()
func _record(world, kind: String, now: float) -> void:
	if world.journal_enabled: world.journal.record("garden.elm_flower.001","埃尔的小花圃",kind,now)
func _new_job(now: float) -> String:
	if not planted: return "sow"
	if stage==3 or (last_water>=0 and Calendar.day_at(last_water)==Calendar.day_at(now)): return ""
	return "water"
func _cycle_days() -> int:
	return randi_range(MIN_BLOOM_DAYS,MAX_BLOOM_DAYS)
func _finish_harvest(_world, _now: float) -> void:
	pass
func water_today(now: float) -> bool:
	if not planted or stage>=3 or (last_water>=0 and Calendar.day_at(last_water)==Calendar.day_at(now)):
		return false
	water_count += 1
	last_water = floorf(now)
	wet_until = last_water+WET_SECONDS
	return true

func _route_to(world, target: Vector2) -> bool:
	var start := Vector2(world.resident.position.x,world.resident.position.z)
	var parked := Vector2(world.car.position.x,world.car.position.z)
	if parked.distance_to(target)<1.5: return false
	var path: PackedVector2Array = world.navigation.path(start,target,.28,parked)
	if path.is_empty() or path[-1].distance_to(target)>(.08 if target==WELL_STAND else .3): return false
	route.clear()
	for point in path: route.append([point.x,point.y])
	return true

func advance(world, delta: float, now: float, can_work: bool = true) -> bool:
	if not enabled: return false
	if world.shelter_from_rain:
		water_today(now)
		if phase!="idle" and job=="water":
			_cancel(world,now)
			world.resident._emit_activity("雨水已经浇湿了泥土")
	if planted and water_count>0 and stage<3:
		var fraction := clampf(Calendar.elapsed_days(planted_at,now)/bloom_days,0,1)
		growth = maxf(growth,THRESHOLDS.back()*fraction)
		while stage<3 and growth>=THRESHOLDS[stage+1]:
			stage += 1
			milestones.append({"stage":stage,"seconds":floorf(now)})
			if stage==3: _record(world,"flower_bloomed",now)
	if job=="water" and active() and not world.shelter_from_rain and (not planted or stage>=3 or (last_water>=0 and Calendar.day_at(last_water)==Calendar.day_at(now))):
		_cancel(world,now)
	if not can_work: return false
	if active() and (not _safe(world) or Vector2(world.car.position.x,world.car.position.z).distance_to(work_position)<1.4):
		_cancel(world,now)
		return false
	if not active():
		if now<next_check or not _safe(world) or world.needs.satiety<65 or world.needs.energy<55: return false
		next_check = floorf(now)+30
		var pending_job := _new_job(now)
		if pending_job.is_empty() or (world.shelter_from_rain and pending_job=="water"): return false
		var needs_refill: bool = pending_job=="water" and world.watering_can_charges==0
		if not _route_to(world,WELL_STAND if needs_refill else work_position): return false
		job = pending_job
		phase = "walking_to_well" if needs_refill else "walking"
		world.resident._pose_stand()
		world.resident._emit_activity("提着空水壶去井边" if needs_refill else ("走向菜地收获" if job=="harvest" else ("去给%s浇水"%crop_name if planted else "走过去种%s"%crop_name)))
	if job=="water" and world.watering_can_charges==0 and phase in ["walking","watering"]:
		if not _route_to(world,WELL_STAND):
			_cancel(world,now)
			return false
		phase = "walking_to_well"
		remaining = 0
	world.resident.elapsed += delta
	if phase in ["walking","walking_to_well"]:
		var here := Vector2(world.resident.position.x,world.resident.position.z)
		var point := Vector2(route[0][0],route[0][1])
		var parked := Vector2(world.car.position.x,world.car.position.z)
		if point.distance_to(parked)<1.2 or not world.navigation.safe_segment(here,point,.28):
			_cancel(world,now)
			return false
		var direction := point-here
		if direction.length()>.001: world.resident.rotation.y = atan2(direction.x,direction.y)
		var next := here.move_toward(point,1.05*delta)
		world.resident.position.x = next.x
		world.resident.position.z = next.y
		world.resident._sync_height()
		world.resident._walk_pose_step(delta)
		if next.distance_to(point)<.001:
			route.pop_front()
			if route.is_empty():
				if phase=="walking_to_well":
					phase = "refilling"
					remaining = REFILL_SECONDS
					world.resident._emit_activity("在井边装满水壶")
					return true
				phase = {"water":"watering","sow":"sowing","harvest":"harvesting"}[job]
				remaining = DURATION
				world.resident._emit_activity("蹲下收获%s"%crop_name if job=="harvest" else ("提着小壶，给%s浇水"%crop_name if planted else "蹲下来，把%s种子埋进土里"%crop_name))
	elif phase=="refilling":
		var actor = world.resident
		actor._pose_stand()
		actor.rotation.y = atan2(WELL.x-actor.position.x,WELL.y-actor.position.z)
		actor.model.position.y = -.18
		actor.right_arm.rotation.x = -.75+sin((REFILL_SECONDS-remaining)*3)*.34
		remaining = maxf(0,remaining-delta)
		if remaining<=0:
			world.watering_can_charges = CAN_CAPACITY
			if not _route_to(world,work_position):
				_cancel(world,now)
				return false
			phase = "walking"
			actor._pose_stand()
			actor._emit_activity("提着装满的水壶去给%s浇水"%crop_name)
	else:
		world.resident._pose_stand()
		world.resident.rotation.y = atan2(plot_position.x-world.resident.position.x,plot_position.y-world.resident.position.z)
		if phase in ["sowing","harvesting"]:
			world.resident.model.position.y = -.25
			world.resident.model.rotation.x = .2
		world.resident.right_arm.rotation.x = -1.0+sin((DURATION-remaining)*4)*.15
		world.resident.left_arm.rotation.x = -.7
		remaining = maxf(0,remaining-delta)
		if remaining<=0:
			if job=="sow":
				planted = true
				planted_at = floorf(now)
				bloom_days = _cycle_days()
				_record(world,"flower_sown",now)
			elif job=="harvest":
				_finish_harvest(world,now)
			elif world.watering_can_charges>0 and water_today(now):
				world.watering_can_charges -= 1
				_record(world,"flower_watered",now)
			phase = "idle"
			next_check = floorf(now)+15
			world.resident._pose_stand()
			world.resident.remaining = 2
			world.resident._emit_activity("收好了亲手种的%s"%crop_name if job=="harvest" else ("种好了%s，等会儿来浇水"%crop_name if job=="sow" else "浇好了水，让%s慢慢长大"%crop_name))
	return true
func description() -> String:
	if not enabled: return "小花圃还没有启用。"
	var text := "我还没有种下花，空闲且吃饱后会去试试。"
	if planted:
		text = "我亲手种的花现在是%s；已实际浇水%d次。"%[STAGES[stage],water_count]
		if stage<3: text += "每天最多浇一次。播种后约%d个游戏日开花。"%bloom_days
		# The first watering starts visible growth.
		if water_count==0: text += "还在等第一次浇水。"
		if stage==3: text += "已经开花了！"
	if phase=="walking": text += "现在正走过去，尚未完成这次照料。"
	elif phase=="sowing": text += "现在正在播种，还没种完。"
	elif phase=="watering": text += "现在正在浇水，这一次还没算完成。"
	return text+"这是本地自主生活，不使用模型决定。"
func snapshot() -> Dictionary:
	return {"version":2,"bloom_days":bloom_days,"enabled":enabled,"started_seconds":started_seconds,"next_check":next_check,"phase":phase,"job":job,"route":route.duplicate(true),"remaining":remaining,"planted":planted,"planted_at":planted_at,"last_water":last_water,"water_count":water_count,"wet_until":wet_until,"growth":growth,"stage":stage,"milestones":milestones.duplicate(true)}
func restore(v: Dictionary) -> void:
	enabled = v.enabled
	started_seconds = float(v.started_seconds)
	next_check = float(v.next_check)
	phase = v.phase
	job = v.job
	route = v.route.duplicate(true)
	remaining = float(v.remaining)
	planted = v.planted
	planted_at = float(v.planted_at)
	# Older plants get a stable cycle while retaining any stages already reached.
	bloom_days = int(v.get("bloom_days",MIN_BLOOM_DAYS+posmod(int(planted_at),6) if planted else 0))
	last_water = float(v.last_water)
	water_count = int(v.water_count)
	wet_until = float(v.wet_until)
	growth = float(v.growth)
	stage = int(v.stage)
	milestones = v.milestones.duplicate(true)
static func valid_snapshot(v: Variant, now: float, actor: Dictionary, ws: Dictionary, stand: Vector2 = STAND, vegetables: bool = false) -> bool:
	if not v is Dictionary or (v.get("version")!=1 and v.get("version")!=2) or not v.get("enabled") is bool or not v.get("planted") is bool or v.get("phase") not in (["idle","walking","walking_to_well","refilling","sowing","watering","harvesting"] if vegetables else ["idle","walking","walking_to_well","refilling","sowing","watering"]) or v.get("job") not in (["sow","water","harvest"] if vegetables else ["sow","water"]): return false
	for key in ["started_seconds","next_check","remaining","water_count","wet_until","growth","stage"]:
		if not Journal.number(v.get(key)): return false
	if v.started_seconds>now or v.next_check>now+30 or v.remaining>DURATION or v.growth>THRESHOLDS.back() or v.stage!=floor(v.stage) or v.stage>3 or v.water_count!=floor(v.water_count) or v.water_count>1000000000 or not v.get("route") is Array or v.route.size()>1000 or not v.get("milestones") is Array or v.milestones.size()!=int(v.stage): return false
	if v.version==1 and v.growth>v.water_count*WET_SECONDS+.01: return false
	if v.version==2:
		var days = v.get("bloom_days")
		if not Journal.number(days) or days!=floor(days): return false
		if v.planted and (days!=3 if vegetables else (days<MIN_BLOOM_DAYS or days>MAX_BLOOM_DAYS)): return false
		if not v.planted and days!=0: return false
	if not (v.get("planted_at") is int or v.get("planted_at") is float) or not (v.get("last_water") is int or v.get("last_water") is float): return false
	if not v.planted:
		if v.planted_at!=-1 or v.water_count!=0 or v.growth!=0 or v.stage!=0 or v.phase=="watering": return false
	elif not Journal.number(v.planted_at) or v.planted_at<v.started_seconds or v.planted_at>now or v.phase=="sowing" or (v.version==1 and v.growth>now-v.planted_at+1): return false
	if v.water_count==0:
		if v.last_water!=-1 or v.wet_until!=0 or v.growth!=0: return false
	elif not v.planted or not Journal.number(v.last_water) or v.last_water<v.planted_at or v.last_water>now or v.wet_until!=v.last_water+WET_SECONDS: return false
	var expected := 0
	for i in range(1,4):
		if v.growth>=THRESHOLDS[i]: expected = i
	if v.stage!=expected: return false
	var previous: float = v.planted_at
	for i in range(v.milestones.size()):
		var event = v.milestones[i]
		if not event is Dictionary or event.get("stage")!=i+1 or not Journal.number(event.get("seconds")) or event.seconds<previous or event.seconds>now: return false
		previous = event.seconds
	for p in v.route:
		if not p is Array or p.size()!=2: return false
		for n in p:
			if not (n is int or n is float) or not is_finite(float(n)) or absf(n)>9: return false
	if v.phase=="idle": return v.route.is_empty() and v.remaining==0
	if not v.enabled or actor.get("mode")!="observe" or not actor.get("route",[]).is_empty() or ws.get("plant_visit",{}).get("latest",{}).get("phase") in ["moving","looking"] or ws.get("plant_routine",{}).get("execution",{}).get("latest",{}).get("phase") in ["moving","looking"]: return false
	if (v.job=="sow")==v.planted: return false
	if v.phase=="walking_to_well":
		return v.job=="water" and not v.route.is_empty() and v.remaining==0
	if v.phase=="refilling":
		return v.job=="water" and v.route.is_empty() and v.remaining>0 and v.remaining<=REFILL_SECONDS and Vector2(actor.position[0],actor.position[1]).distance_to(WELL_STAND)<.1
	if v.phase=="walking": return not v.route.is_empty() and v.remaining==0
	return v.route.is_empty() and v.remaining>0 and Vector2(actor.position[0],actor.position[1]).distance_to(stand)<.1
