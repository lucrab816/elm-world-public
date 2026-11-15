extends RefCounted

const Calendar = preload("res://world_calendar.gd")
const LABELS := {"strong":"晴 · 阳光强烈","gentle":"晴 · 阳光柔和","overcast":"阴天","rain":"雨天","clear":"晴朗"}
const DAY_STATES := ["strong","gentle","overcast","rain"]

static func at(seconds: float, world_id: String) -> String:
	var hour := Calendar.hour_at(seconds)
	var day := Calendar.day_at(seconds)
	var daily := RandomNumberGenerator.new()
	daily.seed = hash("%s/weather/%d"%[world_id,day])
	if hour<6 or hour>=18:
		# Sunset and the following night share one forecast across midnight.
		if hour<6: daily.seed = hash("%s/weather/%d"%[world_id,day-1])
		return "rain" if daily.randf()<.28 else "clear"
	var morning := daily.randi_range(0,DAY_STATES.size()-1)
	var afternoon := (morning+daily.randi_range(1,DAY_STATES.size()-1))%DAY_STATES.size()
	var change_hour := daily.randf_range(10.5,15.5)
	return DAY_STATES[morning if hour<change_hour else afternoon]
