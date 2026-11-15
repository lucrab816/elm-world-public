extends RefCounted
# One existing bed grows only during real running time after a completed watering.
const Care = preload("res://garden_care.gd")
const BED_ID := Care.BED_ID
const THRESHOLDS := [0.0,90.0,270.0]
const STAGES := ["小芽","长出叶片","茂盛菜苗"]
var started_seconds := 0.0
var growth_seconds := 0.0
var stage := 0
var events: Array = []
func start(now: float) -> void:
	started_seconds = floorf(now)
	growth_seconds = 0
	stage = 0
	events.clear()
func advance(from_seconds: float, to_seconds: float, completed_water_count: int, wet_until: float) -> void:
	if completed_water_count<=0 or to_seconds<=from_seconds: return
	var wet := maxf(0,minf(to_seconds,wet_until)-from_seconds)
	if wet<=0: return
	growth_seconds = minf(THRESHOLDS.back(),growth_seconds+wet)
	while stage<2 and growth_seconds>=THRESHOLDS[stage+1]:
		stage += 1
		events.append({"stage":stage,"seconds":floorf(to_seconds)})
func description() -> String:
	if stage==0 and growth_seconds<=0:
		return "菜地里是小芽，浇过水后会慢慢长大。"
	if stage==0: return "菜地里的小芽正在长大。"
	if stage==1: return "菜苗长出了更多叶片，正在慢慢长大。"
	return "菜苗已经长得茂盛；还没有收获。"
func snapshot() -> Dictionary:
	return {"version":1,"bed_id":BED_ID,"started_seconds":started_seconds,"growth_seconds":growth_seconds,"stage":stage,"events":events.duplicate(true)}
static func valid_snapshot(value: Variant, now: float, care: Dictionary) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("bed_id")!=BED_ID: return false
	if not Care.Neighbor.number(value.get("started_seconds")) or value.started_seconds>now or not Care.Neighbor.number(value.get("growth_seconds")) or value.growth_seconds>THRESHOLDS.back() or value.growth_seconds>now-value.started_seconds+1: return false
	if not Care.Neighbor.number(value.get("stage")) or value.stage!=floor(value.stage) or value.stage>2 or not value.get("events") is Array or value.events.size()!=int(value.stage): return false
	var expected := 2 if value.growth_seconds>=THRESHOLDS[2] else (1 if value.growth_seconds>=THRESHOLDS[1] else 0)
	if value.stage!=expected or (value.growth_seconds>0 and (care.get("water_count",0)<=0 or care.get("last_completed_seconds")==null)): return false
	var previous: float = value.started_seconds
	for i in range(value.events.size()):
		var event = value.events[i]
		if not event is Dictionary or event.get("stage")!=i+1 or not Care.Neighbor.number(event.get("seconds")) or event.seconds<previous or event.seconds>now: return false
		previous = event.seconds
	return true
func restore(value: Dictionary) -> void:
	started_seconds = float(value.started_seconds)
	growth_seconds = float(value.growth_seconds)
	stage = int(value.stage)
	events = value.events.duplicate(true)
