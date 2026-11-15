extends RefCounted
# One small decorative plant, placed only after a real local action.
const DURATION := 5.0
const TREE_POT := Vector2(-7.35,.62)
const TREE_APPROACH := Vector2(-7,0)
const POSITIONS := {"object.bench.001":TREE_POT,"place.tree_shade":TREE_POT}
var phase := "idle"
var target := ""
var completed_seconds := 0.0
var moved_seconds := 0.0
var original_target := ""
var decision_evidence: Dictionary = {}
func try_begin(world, actor) -> bool:
	if phase!="idle" or not world.journal_enabled or world.needs==null or world.needs.satiety<65 or world.needs.energy<35: return false
	if actor.user_action.active() or actor.ride_requested or world.pet_companion.requested or world.pet_companion.active(): return false
	var preferred: String = world.rest_preference.preferred()
	if preferred.is_empty() or actor.current_location!=preferred or not POSITIONS.has(preferred): return false
	var p: Vector2 = POSITIONS[preferred]
	if p.distance_to(world.car.parked)<1.6: return false
	if world.rabbit_enabled and p.distance_to(world.rabbit.flat())<.85: return false
	if world.neighbor_enabled and p.distance_to(world.neighbor.flat())<.85: return false
	phase = "placing"
	target = preferred
	var details: Dictionary = world.rest_preference.chat_context()
	decision_evidence = {"source":"observed_at_start","bench_count":details.bench_count,"shade_count":details.shade_count}
	return true
func finish(world, seconds: float) -> void:
	phase = "placed"
	completed_seconds = floorf(seconds)
	world._show_arranged_plant(target)
func move_to(world, destination: String, now: float) -> void:
	if original_target.is_empty(): original_target = target
	target = destination
	moved_seconds = floorf(now)
	world._show_arranged_plant(target)
	if world.journal_enabled: world.journal.record("object.elm_plant.001","观赏盆栽","plant_moved",now)

func snapshot() -> Dictionary:
	return {"version":2,"phase":phase,"target":target,"completed_seconds":completed_seconds,"decision_evidence":decision_evidence.duplicate(true),"original_target":original_target,"moved_seconds":moved_seconds}
static func valid_snapshot(value: Variant, now: float, actor: Dictionary) -> bool:
	if not value is Dictionary or (value.get("version")!=1 and value.get("version")!=2) or value.get("phase") not in ["idle","placing","placed"] or not value.get("target") is String: return false
	var seconds = value.get("completed_seconds")
	if not (seconds is int or seconds is float) or not is_finite(float(seconds)) or seconds<0 or seconds>now or seconds!=floor(seconds): return false
	var moved = value.get("moved_seconds",0)
	var first: String = str(value.get("original_target",""))
	if not (moved is int or moved is float) or not is_finite(float(moved)) or moved<0 or moved>now or moved!=floor(moved): return false
	if (moved>0 and (value.phase!="placed" or moved<seconds or not POSITIONS.has(first))) or (moved==0 and not first.is_empty()): return false
	if value.get("version")==2:
		var evidence = value.get("decision_evidence")
		if not evidence is Dictionary: return false
		if value.phase=="idle":
			if not evidence.is_empty(): return false
		elif evidence.get("source")=="legacy_rule":
			if evidence.size()!=1: return false
		elif evidence.get("source")=="observed_at_start":
			if evidence.size()!=3: return false
			for key in ["bench_count","shade_count"]:
				var count = evidence.get(key)
				if not (count is int or count is float) or not is_finite(float(count)) or count<0 or count>8 or count!=floor(count): return false
			if evidence.bench_count+evidence.shade_count>8 or maxi(int(evidence.bench_count),int(evidence.shade_count))<3 or absi(int(evidence.bench_count)-int(evidence.shade_count))<2: return false
			var derived := "object.bench.001" if evidence.bench_count>evidence.shade_count else "place.tree_shade"
			if (first if moved>0 else value.target)!=derived: return false
		else: return false
	if value.phase=="idle": return value.target=="" and seconds==0 and actor.mode!="arrange_plant"
	if not POSITIONS.has(value.target): return false
	if value.phase=="placing": return seconds==0 and actor.mode=="arrange_plant" and actor.current_location==value.target and actor.remaining>0 and actor.remaining<=DURATION
	return actor.mode!="arrange_plant"
func restore(value: Dictionary) -> void:
	phase = value.phase
	target = value.target
	completed_seconds = float(value.completed_seconds)
	moved_seconds = float(value.get("moved_seconds",0))
	original_target = value.get("original_target","")
	if value.get("version")==1:
		decision_evidence = {} if phase=="idle" else {"source":"legacy_rule"}
	else:
		decision_evidence = value.decision_evidence.duplicate(true)
func description() -> String:
	if phase=="idle": return "尚未摆放小植物。"
	if phase=="placing": return "正在整理小植物，还没有放好。"
	return "已在%s附近放好一盆小植物。"%("长椅" if target=="object.bench.001" else "树荫")
func reason() -> String:
	if phase=="idle": return "我还没有摆放这盆小植物，所以暂时没有选择地点的记录。"
	if phase=="placing": return "我还在整理小植物，还没有放好。"
	var place := "长椅" if target=="object.bench.001" else "树荫"
	if moved_seconds>0: return "我后来把观赏盆栽搬到了%s附近。"%place
	if decision_evidence.get("source")=="observed_at_start":
		var count := int(decision_evidence.bench_count)+int(decision_evidence.shade_count)
		var there := int(decision_evidence.bench_count) if target=="object.bench.001" else int(decision_evidence.shade_count)
		return "我把小植物放在%s附近。开始整理时，最近%d次完成的休息中有%d次在%s，所以按那时的休息倾向选了这里。"%[place,count,there,place]
	return "我把小植物放在%s附近。旧版只保存了摆放地点和完成时间；根据当时的摆放规则，可以知道地点来自近期休息倾向，但没有保存当时的具体次数。"%place
