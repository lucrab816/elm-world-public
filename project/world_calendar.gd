extends RefCounted

const LEGACY_DAY := 7200.0
const DAY := 14400.0
# A single world runs in the app. Save validation supplies each candidate's own anchor.
static var anchor := -1.0

static func _day_position(seconds: float, start: float) -> float:
	if start<0 or seconds<start:
		return seconds/LEGACY_DAY
	var old_hour_fraction := fposmod(start/LEGACY_DAY+1.0/3.0,1.0)
	return floor(start/LEGACY_DAY)+old_hour_fraction+(seconds-start)/DAY

static func day_at(seconds: float, start: float = INF) -> int:
	if start==INF: start = anchor
	return floori(_day_position(seconds,start))+1

static func hour_at(seconds: float) -> float:
	if anchor<0 or seconds<anchor:
		return fposmod(seconds/LEGACY_DAY+1.0/3.0,1.0)*24
	return fposmod(_day_position(seconds,anchor),1.0)*24

static func is_night(seconds: float) -> bool:
	if anchor<0: return false
	var hour := hour_at(seconds)
	return hour>=19.0 or hour<6.0

static func clock_text(seconds: float) -> String:
	var minutes := floori(hour_at(seconds)*60+.000001)%1440
	return "%02d:%02d"%[minutes/60,minutes%60]

static func elapsed_days(from: float, to: float, start: float = INF) -> float:
	if start==INF: start = anchor
	var legacy_seconds := to-from if start<0 else clampf(start-from,0,to-from)
	return legacy_seconds/LEGACY_DAY+(to-from-legacy_seconds)/DAY
