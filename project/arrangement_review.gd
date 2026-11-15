extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# Read-only presentation of already saved records. Never creates an opportunity.
const Journal = preload("res://life_journal.gd")
const Recovery = preload("res://chat_recovery.gd")
const STATES := {"waiting":"等方便时再想","requesting":"正在思考","executing":"行动尚未完成","completed":"实际完成","declined":"继续日常","failed":"未完成","cancelled":"已取消"}
const CHOICES := {"":"还没有选择","none":"继续日常","visit_plant":"看看盆栽","rest_in_shade":"去树荫歇一会儿"}
static func records(value: Dictionary) -> Array:
	var result: Array = value.get("history",[]).duplicate(true)
	if not value.get("latest",{}).is_empty(): result.append(value.latest.duplicate(true))
	result.reverse()
	return result
static func when(seconds: float) -> String:
	return "第%d天 %s"%[Calendar.day_at(seconds),Journal.clock_text(seconds)]
static func label(record: Dictionary) -> String:
	return "安排%d · %s · %s"%[int(record.id),when(record.created_seconds),STATES[record.phase]]
static func detail(record: Dictionary) -> String:
	var lines := PackedStringArray([label(record),"机会来源："+("已开启的低频安排" if record.get("trigger","once")=="low_frequency" else "用户给出的一次机会"),"\n当时的观察"])
	var observation: Dictionary = record.observation
	if observation.is_empty():
		lines.append("还没有开始观察和思考，没有保存当时的生活快照。")
	else:
		lines.append("%s · 饱腹%d · 精力%d · %s日照"%[when(record.observed_seconds),int(observation.satiety),int(observation.energy),"柔和" if observation.sunlight=="gentle" else "强烈"])
		lines.append("当时活动："+str(observation.activity))
		var rest: Dictionary = observation.rest_experience
		lines.append("近期%d次实际完成的休息：长椅%d次、树荫%d次。这是有限记录，不代表全部经历。"%[int(rest.completed_in_recent_window),int(rest.bench_count),int(rest.shade_count)])
		lines.append("当时盆栽："+str(observation.plant))
		if not str(observation.memory_recent).is_empty(): lines.append("当时提供的近期生活记录（有限片段）：\n"+str(observation.memory_recent))
	lines.append("\n当时的选择与想法")
	lines.append("选择："+str(CHOICES[record.proposal]))
	lines.append("模型原话节选（当时的表达，不是行动证明）：\n"+str(record.reply) if not str(record.reply).is_empty() else "没有保留模型原话；不根据结果补写理由。")
	lines.append("\n后来实际怎样")
	var outcomes := {"waiting":"尚未开始思考，也没有因此新增行动。","requesting":"正在等待想法，还没有因此新增行动。","executing":"行动还在进行，尚未确认完成。","completed":"执行器已确认实际完成了这次选择的小事。","declined":"选择继续日常，没有因此新增行动。","failed":"这次安排没有确认完成，不会自动重试。","cancelled":"这次未完成的思考已取消，不会重新发送。"}
	lines.append(outcomes[record.phase])
	if record.phase=="executing":
		lines.append("当前进度："+str({"queued":"排队等待","moving":"还在途中","looking":"正在观察","resting":"正在休息"}.get(record.execution_status,"进行中")))
	if not str(record.error).is_empty():
		var reasons := {"restart":"重开时取消未完成的思考。","exit":"退出时取消未完成的思考。","sleep":"睡眠时取消未完成的思考。","cancelled":"这次思考已取消。","auto_disabled":"低频开关已关闭。","chat_reserve":"保留剩余尝试给聊天，这次没有请求。","wait_timeout":"等待较久，这次机会已结束。","world_changed":"等待时有了新邀请或环境变化，旧想法未执行。","save_failed":"决定未能保存，未新增行动。","action_failed":"执行器报告行动未完成。","action_replaced":"原行动已改变，不能确认完成。"}
		lines.append("说明："+str(reasons.get(record.error,Recovery.guidance(record.error))))
	lines.append("记录更新："+when(record.updated_seconds))
	return "\n".join(lines)
