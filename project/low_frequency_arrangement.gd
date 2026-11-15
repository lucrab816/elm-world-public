extends RefCounted
# Opt-in opportunities measured only in running world time. Never catches up offline.
const Journal = preload("res://life_journal.gd")
const INTERVAL := 3600.0
const WINDOW := 18000.0
const RETRY_CHECK := 60.0
const LIMIT := 2
var enabled := false
var next_check := 0.0
var tracked_id := 0
var acknowledged_id := 0
var attempts: Array = []
var last_error := ""
var wait_reason := ""
var notice := ""
func snapshot() -> Dictionary:
	return {"version":1,"enabled":enabled,"next_check":next_check,"tracked_id":tracked_id,"acknowledged_id":acknowledged_id,"attempts":attempts.duplicate(true),"last_error":last_error,"wait_reason":wait_reason}
func restore(value: Dictionary) -> void:
	enabled = value.enabled
	next_check = float(value.next_check)
	tracked_id = int(value.tracked_id)
	acknowledged_id = int(value.acknowledged_id)
	attempts = value.attempts.duplicate(true)
	last_error = value.last_error
	wait_reason = value.wait_reason
func set_enabled(world, value: bool) -> bool:
	if enabled==value: return true
	var before := snapshot()
	enabled = value
	last_error = ""
	wait_reason = ""
	if enabled:
		next_check = floorf(world.simulation_seconds)+INTERVAL
		acknowledged_id = tracked_id
	if not world._save_now():
		restore(before)
		notice = "设置未能保存，开关保持原状。"
		return false
	notice = ""
	if not enabled and int(world.self_arrangement.latest.get("id",0))==tracked_id and world.self_arrangement.latest.get("trigger","once")=="low_frequency":
		world.self_arrangement.cancel(world,"auto_disabled")
	return true
func _record(world) -> Dictionary:
	if int(world.self_arrangement.latest.get("id",0))==tracked_id: return world.self_arrangement.latest
	for record in world.self_arrangement.history:
		if int(record.id)==tracked_id: return record
	return {}
func advance(world) -> void:
	var now: float = floorf(world.simulation_seconds)
	attempts = attempts.filter(func(a): return now-float(a.seconds)<WINDOW)
	var record := _record(world)
	var changed := false
	# Recover the counter even if the app stopped immediately after persisting launch intent.
	if not record.is_empty() and record.get("trigger","once")=="low_frequency":
		if float(record.observed_seconds)>=0 and now-float(record.observed_seconds)<WINDOW and not attempts.any(func(a): return int(a.id)==tracked_id):
			attempts.append({"id":tracked_id,"seconds":float(record.observed_seconds)})
			changed = true
		if enabled and tracked_id>acknowledged_id and record.phase in ["failed","cancelled"]:
			enabled = false
			last_error = str(record.error).left(64)
			wait_reason = ""
			changed = true
	if changed and not world._save_now(): return
	if not enabled or world.quit_pending or world.fatal_save_error or not world.saving_enabled or now<next_check: return
	var reason := ""
	if attempts.size()>=LIMIT: reason = "window"
	elif world.self_arrangement.active() or world.self_arrangement.transport.pid>0 or not world.model_decision_ticket.is_empty() or not world.self_arrangement._eligible(world): reason = "busy"
	elif not world.self_arrangement.transport.configured():
		enabled = false
		last_error = "cli_missing"
		world._save_now()
		return
	else:
		var budget: Dictionary = world.self_arrangement.transport.budget_status(Time.get_unix_time_from_system())
		if budget.code!="ok": reason = "budget"
	if not reason.is_empty():
		wait_reason = reason
		next_check = now+RETRY_CHECK
		world._save_now()
		return
	var before := snapshot()
	# The opportunity and reservation persist in the same save made by arm().
	tracked_id = world.self_arrangement.next_id
	next_check = now+INTERVAL
	wait_reason = ""
	var accepted: Dictionary = world.self_arrangement.arm(world,"low_frequency")
	if not accepted.ok:
		restore(before)
		enabled = false
		last_error = "arm_failed"
		world._save_now()
func status_text(now: float) -> String:
	if not notice.is_empty(): return notice
	if not enabled:
		return "低频安排已暂停；需要时手动重新开启。" if not last_error.is_empty() else "低频安排关闭 · 不会定时请求模型。"
	if wait_reason=="window": return "本轮机会已用完，等运行时间窗口空出来。"
	if wait_reason=="budget": return "等待小世界的本地额度或请求间隔。"
	if wait_reason=="busy": return "等埃尔空闲、吃饱休息好，再考虑安排。"
	return "低频已开启 · 约%d运行分钟后检查；五小时最多2次。"%maxi(0,ceili((next_check-now)/60.0))
static func valid_snapshot(value: Variant, now: float, arrangement: Dictionary) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("enabled") is bool or not Journal.number(value.get("next_check")) or value.next_check>now+INTERVAL or not Journal.number(value.get("tracked_id")) or value.tracked_id!=floor(value.tracked_id): return false
	if not value.get("attempts") is Array or value.attempts.size()>LIMIT or not value.get("last_error") is String or value.last_error.length()>64 or value.get("wait_reason") not in ["","window","budget","busy"]: return false
	var upper: int = int(arrangement.get("next_id",1))
	if value.tracked_id>=upper or not Journal.number(value.get("acknowledged_id")) or value.acknowledged_id!=floor(value.acknowledged_id) or value.acknowledged_id>value.tracked_id: return false
	var previous := 0
	var previous_time := -1.0
	for attempt in value.attempts:
		if not attempt is Dictionary or not Journal.number(attempt.get("id")) or attempt.id!=floor(attempt.id) or attempt.id<=previous or attempt.id>value.tracked_id or not Journal.number(attempt.get("seconds")) or attempt.seconds<previous_time or attempt.seconds>now: return false
		previous = int(attempt.id)
		previous_time = float(attempt.seconds)
	var records: Array = arrangement.get("history",[]).duplicate()
	if not arrangement.get("latest",{}).is_empty(): records.append(arrangement.latest)
	for record in records:
		if record.id==value.tracked_id and record.get("trigger","once")!="low_frequency": return false
	return true
