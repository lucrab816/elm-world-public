extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# One real completed event per kind, independent of the rotating daily journal.
const Journal = preload("res://life_journal.gd")
const KINDS := {"drive_done":"一次开车兜风", "pet_done":"陪德雷克待了一会儿", "greet_done":"向米娅打了招呼"}
var enabled_seconds := 0.0
var records: Dictionary = {}
func record(kind: String, seconds: float) -> void:
	if KINDS.has(kind) and not records.has(kind) and Journal.number(seconds) and seconds>=enabled_seconds:
		records[kind] = floorf(seconds)
func snapshot() -> Dictionary:
	return {"version":1,"resident_id":"resident_001","enabled_seconds":enabled_seconds,"records":records.duplicate(true)}
static func valid_snapshot(value: Variant, now: float) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("resident_id")!="resident_001" or not Journal.number(value.get("enabled_seconds")) or value.enabled_seconds>now or not value.get("records") is Dictionary or value.records.size()>KINDS.size(): return false
	for kind in value.records:
		if not KINDS.has(kind) or not Journal.number(value.records[kind]) or value.records[kind]!=floor(value.records[kind]) or value.records[kind]<value.enabled_seconds or value.records[kind]>now: return false
	return true
func restore(value: Dictionary) -> void:
	enabled_seconds = float(value.enabled_seconds)
	records = value.records.duplicate(true)
func summary() -> String:
	var lines := PackedStringArray()
	for kind in KINDS:
		if records.has(kind):
			var time: float = float(records[kind])
			lines.append("第%d天 %s · %s"%[Calendar.day_at(time),Journal.clock_text(time),KINDS[kind]])
	return "\n".join(lines) if not lines.is_empty() else "还没有新的片段。启用前的经历不会补写。"
