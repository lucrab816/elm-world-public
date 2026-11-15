extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# Read-only, bounded evidence from the journal and the latest shared interaction.
const Journal = preload("res://life_journal.gd")
const PET_ID := "pet.rabbit.001"
static func scope(message: String) -> String:
	var pet := "德雷克" in message or "兔" in message or "宠物" in message
	if not pet: return ""
	var activity := false
	for word in ["陪","摸","互动","做了什么","做过什么","回顾"]:
		activity = activity or word in message
	var query := false
	for word in ["最近","上次","什么时候","今天","今日","昨天","昨日","有没有","是否","过","回顾","记得","吗","？","?"]:
		query = query or word in message
	if not query: return ""
	# Do not claim an unimplemented kind of interaction or interpret an invitation as history.
	for word in ["喂","吃","抱","洗澡","训练","喜欢","亲密","明天","后天","前天","上周","去摸","请摸","去陪","请陪"]:
		if word in message: return "unsupported"
	if not activity: return ""
	if "昨天" in message or "昨日" in message: return "yesterday"
	if "今天" in message or "今日" in message: return "today"
	return "recent"
static func stamp(seconds: float) -> String:
	return "第%d天 %s（世界时间）"%[Calendar.day_at(seconds),Journal.clock_text(seconds)]
static func matches(seconds: float, day: int) -> bool:
	return day==0 or Calendar.day_at(seconds)==day
static func review(journal, session, now: float, pet_name: String, day: int = 0) -> String:
	var lines: PackedStringArray = []
	var recent_done: Dictionary = {}
	var latest_event: Dictionary = {}
	var count := 0
	if journal!=null:
		for event in journal.entries(day,"pet"):
			if event.location_id!=PET_ID or event.last_seconds>now: continue
			if latest_event.is_empty(): latest_event = event
			if event.kind=="pet_done":
				count += int(event.count)
				if recent_done.is_empty(): recent_done = event
	var last: Dictionary = session.latest
	var finished: float = float(last.get("finished_seconds",-1))
	var shared_done: bool = last.get("phase")=="completed" and finished<=now and matches(finished,day)
	if shared_done and (recent_done.is_empty() or finished>float(recent_done.last_seconds)):
		lines.append("%s，我陪%s待了一会儿，轻轻摸了摸它。"%[stamp(finished),pet_name])
		if count>0: lines.append("日记中另外还保留着%d次完成记录。"%count)
	elif not recent_done.is_empty():
		lines.append("%s，我陪%s待了一会儿，轻轻摸了摸它。"%[stamp(recent_done.last_seconds),pet_name])
		lines.append("这个范围内还保留着%d次完成记录。"%count)
	else:
		lines.append("还保留的记录里，没找到这个时间范围内已完成的陪伴；这不代表以前从未发生过。")
	var activity_time: float = float(last.get("finished_seconds",last.get("started_seconds",last.get("invited_seconds",-1))))
	var in_scope := activity_time>=0 and activity_time<=now and matches(activity_time,day)
	if in_scope:
		if session.phase=="approaching":
			lines.append("这次我在等%s靠近，还没有开始摸摸它。"%pet_name)
		elif session.phase=="petting":
			lines.append("%s开始的这次摸摸还在进行，尚未完成。"%stamp(activity_time))
		elif last.get("phase")=="cancelled":
			lines.append("%s，最近这次陪伴中途停下，没有完成。"%stamp(activity_time) if last.has("started_seconds") else "%s，最近这次没能靠近，还没有开始摸摸。"%stamp(activity_time))
	# Old journal-only saves can still distinguish a start or cancellation from completion.
	elif not latest_event.is_empty() and latest_event.kind!="pet_done":
		lines.append("%s，记录的是%s，不能把它当成已经完成。"%[stamp(latest_event.last_seconds),"开始摸摸" if latest_event.kind=="pet_started" else "中途停止陪伴"])
	if session.requested and matches(now,day):
		lines.append("现在还收到了一次邀请，等忙完再陪它；邀请本身不算完成。")
	lines.append("这里只回顾有限的真实记录，不补写故事。")
	return "\n".join(lines)
static func context(journal, session, now: float, pet_name: String) -> Dictionary:
	var today := Calendar.day_at(now)
	return {"pet_memory_recent":review(journal,session,now,pet_name),"pet_memory_today":review(journal,session,now,pet_name,today),"pet_memory_yesterday":review(journal,session,now,pet_name,today-1) if today>1 else "现在是第1天，还没有上一个世界日可以回顾。"}
static func reply(message: String, context_data: Dictionary) -> String:
	var selected := scope(message)
	if selected=="unsupported":
		return "目前只能回顾已记录的摸摸陪伴，不能据此确认其他互动或关系。埃尔和德雷克会按自己的日常相处，不需要你安排陪伴。"
	return str(context_data.get("pet_memory_"+selected,"还没有可确认的陪伴回顾，不补写过去。"))
