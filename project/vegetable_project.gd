extends "res://elm_gardening.gd"
# Both gifts require an in-person meeting beside the flower.
const RedPotato = preload("res://red_potato.gd")
const MIA_STAND := Vector2(-2.5,5)
const BEDS := [Vector2(-4.5,2),Vector2(-4.5,2.75),Vector2(-4.5,3.5)]
const STANDS := [Vector2(-6,2),Vector2(-6,3),Vector2(-6,3.5)]
const BED := BEDS[0]
const BED_STAND := STANDS[0]
const LEGACY_STANDS := [Vector2(-7,-1),Vector2(-7,.5),Vector2(-7,1.5)]
var potato: RefCounted
var plot_index := 0
var seeds_at := -1.0
var harvest_at := -1.0
var gift_at := -1.0
const REPLANT_DELAY := 300.0
var cycle := 1
var cycle_harvest_at := -1.0
var harvest_count := 0
var shared_count := 0
var next_sow_at := 0.0
var meeting := false
var meeting_retry := 0.0
var meeting_remaining := 3.0
var elm_path := PackedVector2Array()
var mia_path := PackedVector2Array()

func _init() -> void:
	plot_position = BED
	work_position = BED_STAND
	crop_name = "青菜"

func set_plot(index: int) -> void:
	plot_index = index
	plot_position = BEDS[index]
	work_position = STANDS[index]

func can_plant_potato() -> bool:
	return potato==null and not active() and not meeting and (not planted or cycle_harvest_at>=0)

func start_potato(now: float) -> void:
	potato = RedPotato.new()
	potato.plot_position = plot_position
	potato.work_position = work_position
	potato.start(now)

func current_crop():
	if potato!=null and potato.harvested_at<0: return potato
	return self

func active() -> bool:
	return current_crop().phase!="idle"

func _cycle_days() -> int:
	return 3

func _new_job(now: float) -> String:
	if current_crop()!=self: return potato._new_job(now)
	if seeds_at<0 or cycle_harvest_at>=0: return ""
	if stage==3: return "harvest"
	return super._new_job(now)

func _record(world, kind: String, now: float) -> void:
	var event: String = {"flower_sown":"vegetable_sown","flower_watered":"vegetable_watered","flower_bloomed":"vegetable_ripe"}.get(kind,kind)
	if world.journal_enabled: world.journal.record("garden.elm_vegetable.001","埃尔的菜地",event,now)

func _finish_harvest(world, now: float) -> void:
	cycle_harvest_at = floorf(now)
	harvest_count += 1
	next_sow_at = floorf(now)+REPLANT_DELAY
	if harvest_at<0: harvest_at = cycle_harvest_at
	if cycle>1:
		world.needs.garden_food += 1
		world.needs.garden_by_plot[plot_index] += 1
	_record(world,"vegetable_harvested",now)
	world.collect_crop_seeds("vegetable",now,str(plot_index))

func advance(world, delta: float, now: float, can_work: bool = true) -> bool:
	if current_crop()!=self: return potato.advance(world,delta,now,can_work)
	if enabled and can_work and not active() and not meeting and gift_at>=0 and cycle_harvest_at>=0 and world.seed_stock.vegetable>0 and now>=next_sow_at and world.needs.garden_by_plot[plot_index]==0 and not (world.needs.meal_is_garden and world.needs.garden_meal_plot==plot_index) and _safe(world):
		world.seed_stock.vegetable = int(world.seed_stock.vegetable)-1
		cycle += 1
		cycle_harvest_at = -1
		planted = false
		planted_at = -1
		bloom_days = 0
		last_water = -1
		water_count = 0
		wet_until = 0
		growth = 0
		stage = 0
		milestones.clear()
		job = "sow"
		next_check = floorf(now)
	return super.advance(world,delta,now,can_work)

func _can_give(world) -> bool:
	if seeds_at<0: return true
	if gift_at<0: return harvest_at>=0
	return cycle>1 and cycle_harvest_at>=0 and world.needs.garden_by_plot[plot_index]>0 and world.needs.satiety>=70

func _meeting_safe(world) -> bool:
	return _safe(world) and world.neighbor_enabled and world.neighbor.mode=="rest" and not world.garden_care.active() and not world.mia_rabbit.active() and not world.flower_neighbor_visit.active()

func _walk_to_meeting(world, path: PackedVector2Array, is_mia: bool, delta: float) -> bool:
	if path.is_empty(): return true
	var actor = world.neighbor if is_mia else world.resident
	var here := Vector2(actor.position.x,actor.position.z)
	var target: Vector2 = path[0]
	if not world.navigation.safe_segment(here,target,.28) or not world.neighbor._car_clear(target): return false
	var direction := target-here
	if direction.length()>.001: actor.rotation.y = atan2(direction.x,direction.y)
	var next := here.move_toward(target,(.65 if is_mia else 1.05)*delta)
	if is_mia:
		actor._place(next)
		actor._pose(true)
		actor._sync_obstacle()
	else:
		actor.position.x = next.x
		actor.position.z = next.y
		actor._sync_height()
		actor._walk_pose_step(delta)
	if next.distance_to(target)<.001:
		if is_mia: mia_path = path.slice(1)
		else: elm_path = path.slice(1)
	return true

func advance_meeting(world, delta: float, now: float) -> bool:
	if current_crop()!=self or not enabled or world.flower_neighbor_visit.visited_at<0: return false
	if not meeting and not _can_give(world): return false
	if not meeting:
		if now<meeting_retry or active() or world.elm_gardening.active() or not _meeting_safe(world): return false
		meeting_retry = now+30
		var parked := Vector2(world.car.position.x,world.car.position.z)
		elm_path = world.navigation.path(Vector2(world.resident.position.x,world.resident.position.z),STAND,.28,parked,1.75)
		mia_path = world.navigation.path(world.neighbor.flat(),MIA_STAND,.28,parked,1.75)
		if elm_path.is_empty() or mia_path.is_empty() or elm_path[-1].distance_to(STAND)>.1 or mia_path[-1].distance_to(MIA_STAND)>.1: return false
		meeting = true
		meeting_remaining = 3
		world.resident._emit_activity("去花圃见米娅")
	if not _meeting_safe(world) or not _walk_to_meeting(world,elm_path,false,delta) or not _walk_to_meeting(world,mia_path,true,delta):
		meeting = false
		meeting_retry = now+30
		world.resident._pose_stand()
		world.neighbor._pose(false)
		return false
	world.resident.elapsed += delta
	world.neighbor.elapsed += delta
	if elm_path.is_empty() and mia_path.is_empty():
		world.resident._pose_stand()
		world.neighbor._pose(false)
		world.resident.rotation.y = -PI/2
		world.neighbor.rotation.y = PI/2
		world.resident.right_arm.rotation.x = -1.15
		world.neighbor.right_arm.rotation.x = -1.15
		world.resident._emit_activity("听米娅讲怎么种青菜" if seeds_at<0 else "把第一把青菜送给米娅" if gift_at<0 else "把这次收的青菜分给米娅")
		meeting_remaining -= delta
		if meeting_remaining<=0:
			if seeds_at<0:
				seeds_at = floorf(now)
				_record(world,"vegetable_seeds_received",now)
			else:
				if gift_at<0:
					gift_at = floorf(now)
				else:
					world.needs.garden_food -= 1
					world.needs.garden_by_plot[plot_index] -= 1
				shared_count += 1
				next_sow_at = floorf(now)+REPLANT_DELAY
				_record(world,"vegetable_shared",now)
			meeting = false
			world.resident._pose_stand()
			world.neighbor._pose(false)
	return true

func description(eaten: int = 0) -> String:
	if current_crop()!=self: return potato.description()
	if seeds_at<0: return "我还在等和米娅见面，学学怎么种青菜。"
	if cycle==1 and harvest_at>=0 and gift_at<0: return "第一把青菜已经收好了。等和米娅碰面，我想分给她。"
	var text := "米娅教我种青菜。"
	if gift_at>=0: text += "第一把青菜已经亲手送给她了。"
	text += "现在是第%d茬，共收获%d把，分给米娅%d把，自己吃过%d把。"%[cycle,harvest_count,shared_count,eaten]
	if cycle_harvest_at>=0: return text+"这一茬已收好，用完后休息一会儿再种。"
	if not planted: return text+"空闲时会去播种。"
	return text+"这茬青菜现在%s，每天最多浇一次水，约三个游戏日成熟。"%["刚播种","长出小苗","长出了叶子","成熟了"][stage]

func snapshot() -> Dictionary:
	var state := super.snapshot()
	state.merge({"plot_index":plot_index,"seeds_at":seeds_at,"harvest_at":harvest_at,"gift_at":gift_at,"cycle":cycle,"cycle_harvest_at":cycle_harvest_at,"harvest_count":harvest_count,"shared_count":shared_count,"next_sow_at":next_sow_at})
	if potato!=null: state["red_potato"] = potato.snapshot()
	return state

func restore(v: Dictionary) -> void:
	super.restore(v)
	set_plot(int(v.get("plot_index",0)))
	seeds_at = float(v.seeds_at)
	harvest_at = float(v.harvest_at)
	gift_at = float(v.gift_at)
	cycle = int(v.get("cycle",1))
	cycle_harvest_at = float(v.get("cycle_harvest_at",harvest_at))
	harvest_count = int(v.get("harvest_count",1 if harvest_at>=0 else 0))
	shared_count = int(v.get("shared_count",1 if gift_at>=0 else 0))
	next_sow_at = float(v.get("next_sow_at",maxf(0,gift_at+REPLANT_DELAY)))
	if v.has("red_potato"):
		start_potato(float(v.red_potato.started_seconds))
		potato.restore(v.red_potato)

static func valid_project(v: Variant, now: float, actor: Dictionary, ws: Dictionary) -> bool:
	var index = v.get("plot_index",0) if v is Dictionary else -1
	if not index is int and not index is float: return false
	if index<0 or index>2 or index!=floor(index): return false
	var stand: Vector2 = (STANDS if ws.get("yard_plan_clear_gate",false) else ([Vector2(-7,3),Vector2(-7,4),Vector2(-7,5)] if ws.get("yard_plan",false) else LEGACY_STANDS))[int(index)] if v.has("plot_index") else Vector2(-3.5,5)
	if not valid_snapshot(v,now,actor,ws,stand,true): return false
	if v.has("red_potato"):
		if ws.get("potato_seed_letter","").is_empty() or not RedPotato.valid_crop(v.red_potato,now,actor,ws,stand): return false
		if v.red_potato.harvested_at<0 and (v.phase!="idle" or (v.planted and v.get("cycle_harvest_at",v.get("harvest_at",-1))<0)): return false
	for key in ["seeds_at","harvest_at","gift_at"]:
		var stamp = v.get(key)
		if stamp!=-1 and (not Journal.number(stamp) or stamp>now): return false
	if v.seeds_at<0: return not v.planted and v.phase=="idle" and v.harvest_at<0 and v.gift_at<0
	if v.planted and v.planted_at<v.seeds_at: return false
	if v.gift_at>=0 and (v.harvest_at<0 or v.gift_at<v.harvest_at): return false
	var current_cycle = v.get("cycle",1)
	for key in ["cycle","harvest_count","shared_count"]:
		var n = v.get(key,{"cycle":1,"harvest_count":1 if v.harvest_at>=0 else 0,"shared_count":1 if v.gift_at>=0 else 0}[key])
		if not Journal.number(n) or n!=floor(n): return false
	if current_cycle<1 or current_cycle>1000000000 or (current_cycle>1 and v.gift_at<0): return false
	var harvested = v.get("cycle_harvest_at",v.harvest_at)
	if harvested!=-1 and (not Journal.number(harvested) or harvested>now or v.stage!=3 or harvested<v.planted_at or not v.planted or v.phase!="idle"): return false
	if current_cycle==1 and harvested!=v.harvest_at: return false
	if v.get("harvest_count",1 if v.harvest_at>=0 else 0)!=current_cycle-1+(1 if harvested>=0 else 0): return false
	var shared = v.get("shared_count",1 if v.gift_at>=0 else 0)
	if shared>v.get("harvest_count",1 if v.harvest_at>=0 else 0) or (v.gift_at>=0 and shared<1): return false
	var sow_at = v.get("next_sow_at",0)
	if not Journal.number(sow_at) or sow_at>now+REPLANT_DELAY: return false
	var life: Dictionary = ws.get("basic_life",{})
	if life.get("garden_by_plot",[life.get("garden_food",0),0,0])[int(index)]>0 or (life.get("meal_is_garden",false) and life.get("garden_meal_plot",0)==index):
		if current_cycle<=1 or harvested<0: return false
	return true
