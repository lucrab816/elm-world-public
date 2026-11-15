extends RefCounted
# Only user-submitted cards. Never extract facts automatically from chat/model output.
const LIMIT := 24
const TITLE_LIMIT := 32
const TEXT_LIMIT := 160
var records: Array = []
var next_id := 1
static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=1e12
static func valid_text(value: Variant, limit: int) -> bool:
	return value is String and not value.strip_edges().is_empty() and value==value.strip_edges() and value.length()<=limit and not "\n" in value and not "\r" in value and not "\t" in value
static func valid_snapshot(value: Variant, now: float) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("resident_id")!="resident_001" or not number(value.get("next_id")) or value.next_id<1 or value.next_id!=floor(value.next_id):
		return false
	if not value.get("records") is Array or value.records.size()>LIMIT:
		return false
	var ids := {}
	var titles := {}
	for record in value.records:
		if not record is Dictionary or not number(record.get("id")) or record.id<1 or record.id!=floor(record.id) or record.id>=value.next_id or ids.has(int(record.id)):
			return false
		if record.get("source")!="user_explicit" or not valid_text(record.get("title"),TITLE_LIMIT) or not valid_text(record.get("text"),TEXT_LIMIT):
			return false
		if titles.has(record.title.to_lower()):
			return false
		if not number(record.get("created_seconds")) or not number(record.get("updated_seconds")) or record.updated_seconds<record.created_seconds or record.updated_seconds>now+.000001:
			return false
		ids[int(record.id)] = true
		titles[record.title.to_lower()] = true
	return true
func snapshot() -> Dictionary:
	return {"version":1,"resident_id":"resident_001","next_id":next_id,"records":records.duplicate(true)}
func restore(value: Dictionary, now: float) -> bool:
	if not valid_snapshot(value,now):
		return false
	records = value.records.duplicate(true)
	next_id = int(value.next_id)
	return true
func change(action: String, id: int, title: String, text: String, now: float) -> String:
	if not number(now):
		return "时间暂时不可用，请稍后重试。"
	var index := -1
	for i in range(records.size()):
		if int(records[i].id)==id:
			index = i
	if action=="forget":
		if index<0:
			return "这条记录已不存在，请重新选择。"
		records.remove_at(index)
		return "ok"
	if action not in ["add","edit"]:
		return "这项操作暂时不可用。"
	title = title.strip_edges()
	text = text.strip_edges()
	if not valid_text(title,TITLE_LIMIT) or not valid_text(text,TEXT_LIMIT):
		return "请填写主题（1—32字）和内容（1—160字），每项写成一行。"
	for i in range(records.size()):
		if records[i].title.to_lower()==title.to_lower() and (action=="add" or i!=index):
			return "已有同名主题，请选择原记录进行纠正。"
	if action=="add":
		if records.size()>=LIMIT or next_id>=1000000000000:
			return "已经记满24条。请先纠正或忘记不再需要的记录。"
		records.append({"id":next_id,"source":"user_explicit","title":title,"text":text,"created_seconds":floorf(now),"updated_seconds":floorf(now)})
		next_id += 1
	else:
		if index<0:
			return "这条记录已不存在，请重新选择。"
		if now<float(records[index].created_seconds):
			return "时间暂时不可用，请稍后重试。"
		records[index].title = title
		records[index].text = text
		records[index].updated_seconds = floorf(now)
	return "ok"
static func normalized(text: String) -> String:
	text = text.to_lower()
	for word in ["名字","姓名","称呼","叫我"]:
		text = text.replace(word,"name")
	return text
func recall(query: String) -> String:
	var general := false
	for phrase in ["记得什么","告诉过你什么","记住了什么","有哪些记忆"]:
		general = general or phrase in query
	var ranked: Array = []
	var normalized_query := normalized(query)
	for record in records:
		var score := 0
		var title := normalized(str(record.title))
		var body := normalized(str(record.text))
		var seen := {}
		for i in range(normalized_query.length()-1):
			var token := normalized_query.substr(i,2)
			if seen.has(token) or token in ["我的","你的","记得","什么","告诉","了吗","的吗","你还","你记","我告","过你"] or token.strip_edges().length()<2:
				continue
			seen[token] = true
			if token in title: score += 4
			if token in body: score += 1
		if score>0 or general:
			ranked.append({"score":score,"record":record})
	ranked.sort_custom(func(a,b): return a.score>b.score if a.score!=b.score else a.record.updated_seconds>b.record.updated_seconds)
	var lines := PackedStringArray()
	for candidate in ranked.slice(0,3):
		var record: Dictionary = candidate.record
		lines.append("你明确告诉我的 · %s：%s"%[record.title,record.text])
	return "\n".join(lines) if not lines.is_empty() else "没有找到对应的明确记录；不知道的内容不会补写。"
