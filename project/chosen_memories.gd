extends RefCounted
# User-chosen snapshots of real journal groups, kept separately from the rotating journal.
const Journal = preload("res://life_journal.gd")
const LIMIT := 24
var records: Array = []
var next_id := 1
func snapshot() -> Dictionary:
	return {"version":1,"resident_id":"resident_001","next_id":next_id,"records":records.duplicate(true)}
static func valid_snapshot(value: Variant, now: float) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("resident_id")!="resident_001" or not Journal.number(value.get("next_id")) or value.next_id<1 or value.next_id!=floor(value.next_id) or not value.get("records") is Array or value.records.size()>LIMIT: return false
	var seen := {}
	var event_keys := {}
	for record in value.records:
		if not record is Dictionary or not Journal.number(record.get("id")) or record.id<1 or record.id!=floor(record.id) or record.id>=value.next_id or seen.has(int(record.id)): return false
		if not Journal.number(record.get("saved_seconds")) or record.saved_seconds>now or not record.get("event") is Dictionary: return false
		var e: Dictionary = record.event
		if not Journal.valid_snapshot({"version":1,"resident_id":"resident_001","started_seconds":0,"records":[e]},now) or e.last_seconds>record.saved_seconds: return false
		var key := "%d:%s:%s"%[int(e.day),e.location_id,e.kind]
		if event_keys.has(key): return false
		seen[int(record.id)] = true
		event_keys[key] = true
	return true
func restore(value: Dictionary) -> void:
	records = value.records.duplicate(true)
	next_id = int(value.next_id)
func add(event: Dictionary, journal: Journal, now: float) -> String:
	if not journal.records.has(event): return "这条日记刚刚更新了，请重新选择。"
	for record in records:
		var e: Dictionary = record.event
		if e.day==event.day and e.location_id==event.location_id and e.kind==event.kind: return "这一组经历已经收藏了。"
	if records.size()>=LIMIT: return "已收藏24组，可以先移出不再需要的片段。"
	if next_id>=1000000000000: return "收藏编号已用完。"
	records.append({"id":next_id,"saved_seconds":floorf(now),"event":event.duplicate(true)})
	next_id += 1
	return "ok"
func remove(id: int) -> String:
	for i in range(records.size()):
		if int(records[i].id)==id:
			records.remove_at(i)
			return "ok"
	return "这条收藏已不存在，请重新选择。"
static func describe(e: Dictionary) -> String:
	var times: String = Journal.clock_text(float(e.last_seconds))
	if e.count>1: times = Journal.clock_text(float(e.first_seconds))+"—"+times
	return "第%d天 %s · %s · %s%s"%[int(e.day),times,e.location_name,Journal.ACTIONS[e.kind],"（共%d次）"%int(e.count) if e.count>1 else ""]
func summary() -> String:
	var lines := PackedStringArray()
	for record in records: lines.append(describe(record.event))
	return "\n".join(lines) if not lines.is_empty() else "你还没有收藏生活片段。"

# Small, transparent keyword retrieval. A missing match is never evidence that an event did not happen.
const SEARCH_TERMS := {
	"德雷克":"pet", "小兔子":"pet", "小兔":"pet", "兔子":"pet", "兔兔":"pet", "宠物":"pet",
	"米娅":"neighbor", "邻居":"neighbor",
	"开车":"car", "兜风":"car", "小车":"car", "汽车":"car",
	"休息":"rest", "歇息":"rest", "吃饭":"meal", "用餐":"meal",
	"树荫":"shade", "树下":"shade", "长椅":"bench", "家门口":"home", "菜地":"garden"
}
const GENERAL_WORDS := ["有哪些","有没有","有什么","哪一些","哪些","什么","还记得","记得","能不能","事情","找到","回顾","告诉","看看","请问","帮我","分享","讲讲","说说","一起","事","收藏","珍藏","生活","片段","回忆","记忆","经历","相关","关于","有关","你","我","的","中","里","了","吗","呢","呀","是","过","和","与","啊","？","?","，",",","。"," "]
static func _tags(event: Dictionary) -> Array:
	var tags: Array = []
	for group in ["pet","neighbor","car","rest","meal"]:
		if event.kind in Journal.GROUPS[group]: tags.append(group)
	var location: String = event.location_id+" "+event.location_name
	for pair in [["树荫","shade"],["长椅","bench"],["家门口","home"],["菜地","garden"]]:
		if pair[0] in location: tags.append(pair[1])
	return tags
func recall(query: String) -> String:
	var requested: Array = []
	for word in SEARCH_TERMS:
		if word in query and not SEARCH_TERMS[word] in requested: requested.append(SEARCH_TERMS[word])
	var remainder := query
	var words: Array = SEARCH_TERMS.keys()
	words.sort_custom(func(a,b): return a.length()>b.length())
	for word in words: remainder = remainder.replace(word,"")
	for word in GENERAL_WORDS: remainder = remainder.replace(word,"")
	var matches: Array = []
	# Unknown content is not treated as a broad query; avoid presenting unrelated records as a match.
	if not remainder.strip_edges().is_empty():
		return "没有找到与这个问题匹配的收藏；这不代表以前没有发生过。"
	for record in records:
		var tags := _tags(record.event)
		var matches_all := true
		for tag in requested:
			if tag not in tags: matches_all = false
		if matches_all: matches.append(record)
	if matches.is_empty():
		return "还没有收藏生活片段。" if records.is_empty() else "没有找到与这个问题匹配的收藏；这不代表以前没有发生过。"
	matches.reverse()
	var lines := PackedStringArray()
	for record in matches.slice(0,3): lines.append(describe(record.event))
	return ("匹配 %d 组，显示最近收藏的 3 组：\n"%matches.size() if matches.size()>3 else "匹配 %d 组：\n"%matches.size())+"\n".join(lines)
