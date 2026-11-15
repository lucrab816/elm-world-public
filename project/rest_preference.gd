extends RefCounted
# A short window of completed rests, not an inferred emotion or a complete history.
const WINDOW := 8
const MIN_OBSERVATIONS := 3
const LOCATIONS := ["object.bench.001","place.tree_shade"]
var recent: Array = []
func record(location: String) -> void:
	if location not in LOCATIONS: return
	recent.append(location)
	while recent.size()>WINDOW: recent.pop_front()
func preferred() -> String:
	var bench := recent.count(LOCATIONS[0])
	var shade := recent.count(LOCATIONS[1])
	if maxi(bench,shade)<MIN_OBSERVATIONS or absi(bench-shade)<2: return ""
	return LOCATIONS[0] if bench>shade else LOCATIONS[1]
func summary() -> String:
	var id := preferred()
	if id.is_empty(): return "最近完成的休息还不足以看出稳定的地点倾向。"
	var name := "长椅" if id==LOCATIONS[0] else "树荫"
	return "最近%d次完成的休息中，在%s较多；选择时也会考虑日照和精力。"%[recent.size(),name]
func chat_context() -> Dictionary:
	var id := preferred()
	return {"completed_in_recent_window":recent.size(),"window_limit":WINDOW,
		"bench_count":recent.count(LOCATIONS[0]),"shade_count":recent.count(LOCATIONS[1]),
		"observed_tendency":"长椅" if id==LOCATIONS[0] else ("树荫" if id==LOCATIONS[1] else "尚不确定")}
func snapshot() -> Dictionary:
	return {"version":1,"resident_id":"resident_001","recent":recent.duplicate()}
static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("resident_id")!="resident_001" or not value.get("recent") is Array or value.recent.size()>WINDOW: return false
	for id in value.recent:
		if not id is String or id not in LOCATIONS: return false
	return true
func restore(value: Dictionary) -> void:
	recent = value.recent.duplicate()
