extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# An occasional local daily activity. It never calls a model or replaces model decisions.
const Visit = preload("res://plant_visit.gd")
const Journal = preload("res://life_journal.gd")
const FIRST_DELAY := 120.0
const INTERVAL := 900.0
const RETRY := 30.0
var enabled_seconds := 0.0
var next_check := FIRST_DELAY
var completed_count := 0
var last_completed := -1.0
var visit = Visit.new()
func start(now: float) -> void:
	enabled_seconds = floorf(now)
	next_check = enabled_seconds+FIRST_DELAY
func _pending_model(world) -> bool:
	return not world.model_decision_ticket.is_empty() and Time.get_ticks_msec()-int(world.model_decision_ticket.get("issued_ms",0))<=90000
func _cancel(world, seconds: float) -> void:
	visit.latest.phase = "failed"
	visit.latest.updated_seconds = floorf(seconds)
	visit.latest.route = []
	visit.latest.remaining = 0.0
	next_check = floorf(seconds)+RETRY
	world.resident._pose_stand()
func advance(world, delta: float, seconds: float) -> bool:
	if visit.active():
		if world.plant_visit.active() or not visit._safe_to_start(world):
			_cancel(world,seconds)
			return false
	else:
		if seconds<next_check: return false
		next_check = floorf(seconds)+RETRY
		if world.plant_visit.active() or _pending_model(world) or not visit._safe_to_start(world): return false
		if world.needs==null or world.needs.meal_active or world.needs.satiety<65 or world.needs.energy<60: return false
		if world.plant_arrangement.phase!="placed" or world.arranged_plant==null: return false
		visit.enqueue(world.plant_arrangement.target,seconds,false,"","local_routine")
		visit.history.clear()
	var occupied: bool = visit.advance(world,delta,seconds)
	if visit.phase()=="completed":
		completed_count += 1
		last_completed = floorf(seconds)
		next_check = last_completed+INTERVAL
	elif visit.phase()=="queued":
		# A blocked route gives the normal day back immediately, rather than waiting forever.
		_cancel(world,seconds)
	return occupied
func recall() -> String:
	var text := "自主看盆栽属于本地日常规则，不调用模型。"
	if completed_count==0:
		text += "启用后还没有实际完成过，不补写之前的经历。"
	else:
		text += "启用后实际完成%d次，最近是第%d天 %s。"%[completed_count,Calendar.day_at(last_completed),Journal.clock_text(last_completed)]
	if visit.active(): text += "现在"+visit.status()+"，这一次尚未完成。"
	elif visit.phase()=="failed": text += "最近一次途中停下或未能出发，没有计作完成。"
	return text
func snapshot() -> Dictionary:
	return {"version":1,"enabled_seconds":enabled_seconds,"next_check":next_check,"completed_count":completed_count,"last_completed":last_completed,"execution":visit.snapshot()}
static func valid_snapshot(value: Variant, now: float, actor: Dictionary, plant: Dictionary) -> bool:
	if not value is Dictionary or value.get("version")!=1: return false
	for key in ["enabled_seconds","next_check","completed_count"]:
		if not Journal.number(value.get(key)): return false
	if value.enabled_seconds>now or value.next_check<value.enabled_seconds or value.next_check>now+INTERVAL+FIRST_DELAY or value.completed_count!=floor(value.completed_count): return false
	if not (value.get("last_completed") is int or value.get("last_completed") is float): return false
	if value.completed_count==0:
		if value.last_completed!=-1: return false
	elif not Journal.number(value.last_completed) or value.last_completed<value.enabled_seconds or value.last_completed>now: return false
	if not Visit.valid_snapshot(value.get("execution"),now,actor,plant): return false
	var e: Dictionary = value.execution.latest
	if not value.execution.get("history",[]).is_empty(): return false
	if e.is_empty(): return value.completed_count==0
	if e.source!="local_routine" or e.has("decision_note") or e.created_seconds<value.enabled_seconds: return false
	if value.completed_count>=value.execution.next_id: return false
	if e.phase=="completed": return value.completed_count>0 and value.last_completed==e.updated_seconds and value.next_check>=value.last_completed+INTERVAL
	return value.completed_count==0 or value.last_completed<=e.created_seconds
func restore(value: Dictionary) -> void:
	enabled_seconds = float(value.enabled_seconds)
	next_check = float(value.next_check)
	completed_count = int(value.completed_count)
	last_completed = float(value.last_completed)
	visit.restore(value.execution)
