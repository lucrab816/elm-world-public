extends "res://elm_gardening.gd"


const BLOOM_DURATION := 4 * Journal.DAY_SECONDS
const WILT_DURATION := Journal.DAY_SECONDS
var wilted_at := -1.0
var cycles := 0
var picked := false

func _new_job(now: float) -> String:
	if wilted_at>=0: return ""
	return super._new_job(now)

func advance(world, delta: float, now: float, can_work: bool = true) -> bool:
	if stage==3 and wilted_at<0 and Calendar.elapsed_days(milestones.back().seconds,now)>=4 and not world.flower_neighbor_visit.active():
		wilted_at = floorf(now)
		_record(world,"flower_wilted",now)
	if wilted_at>=0 and Calendar.elapsed_days(wilted_at,now)>=1:
		planted = false
		planted_at = -1
		bloom_days = 0
		last_water = -1
		water_count = 0
		wet_until = 0
		growth = 0
		stage = 0
		milestones.clear()
		wilted_at = -1
		picked = false
		next_check = floorf(now)
	return super.advance(world,delta,now,can_work)

func _record(world, kind: String, now: float) -> void:
	if kind=="flower_sown": cycles += 1
	super._record(world,kind,now)

func can_pick() -> bool:
	return stage==3 and wilted_at<0 and not picked

func description() -> String:
	if wilted_at>=0: return "这一茬花已经自然枯萎，我可以等盆土空出来再播种。"
	return super.description()+(" 我剪了一朵送给米娅。" if picked else "")

func snapshot() -> Dictionary:
	var state := super.snapshot()
	state.merge({"wilted_at":wilted_at,"cycles":cycles,"picked":picked})
	return state

func restore(state: Dictionary) -> void:
	super.restore(state)
	wilted_at = float(state.get("wilted_at",-1))
	cycles = int(state.get("cycles",1 if planted else 0))
	picked = state.get("picked",false)

static func valid_cycle(state: Variant, now: float, actor: Dictionary, world_state: Dictionary) -> bool:
	if not valid_snapshot(state,now,actor,world_state,STAND if world_state.get("window_storage_aligned",false) else (Vector2(2,-1.5) if world_state.get("window_storage",false) else OLD_STAND)): return false
	var wilt = state.get("wilted_at",-1)
	var count = state.get("cycles",0)
	var cut = state.get("picked",false)
	if not Journal.number(count) or count!=floor(count) or not cut is bool or (cut and state.stage!=3): return false
	return wilt==-1 or (Journal.number(wilt) and state.stage==3 and wilt>=state.milestones.back().seconds and Calendar.elapsed_days(state.milestones.back().seconds,wilt,float(world_state.get("calendar_start",-1)))>=4 and wilt<=now)
