extends RefCounted
# One bounded local action. Model text never enters this executor.
const TARGET := "place.tree_shade"
const ACTIVE := ["queued","moving","resting"]
const PHASES := ["queued","moving","resting","completed","failed"]
const REASONS := ["busy","meal","walking","resting","done","missing_target","blocked","layout_changed"]
var next_id := 1
var latest: Dictionary = {}
static func recognizes(message: String) -> bool:
	var text := message.strip_edges()
	for punctuation in ["。","！","？","!","?"," ","\t","\n","\r","，",","]:
		text = text.replace(punctuation,"")
	for prefix in ["请你","请","能不能","可以"]:
		if text.begins_with(prefix):
			text = text.trim_prefix(prefix)
			break
	for suffix in ["好吗","可以吗","吧"]:
		if text.ends_with(suffix):
			text = text.trim_suffix(suffix)
			break
	return text in ["去树荫歇一会儿","去树荫歇一会","去树下歇一会儿","去树下歇一会","去树荫休息一下","去树下休息一下","到树荫歇一会儿","到树下休息一下"]
func phase() -> String:
	return str(latest.get("phase",""))
func active() -> bool:
	return phase() in ACTIVE
func enqueue(seconds: float, origin: String = "user") -> void:
	latest = {"id":next_id,"action":"rest","target":TARGET,"phase":"queued","reason":"busy","created_seconds":floorf(seconds),"updated_seconds":floorf(seconds)}
	if origin!="user": latest["origin"] = origin
	next_id += 1
func mark(value: String, reason: String, seconds: float) -> void:
	latest.phase = value
	latest.reason = reason
	latest.updated_seconds = floorf(seconds)
func snapshot() -> Dictionary:
	return {"version":1,"next_id":next_id,"latest":latest.duplicate(true)}
static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=1e12
static func valid_snapshot(value: Variant, now: float) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not number(value.get("next_id")) or value.next_id<1 or value.next_id!=floor(value.next_id) or not value.get("latest") is Dictionary:
		return false
	var request: Dictionary = value.latest
	if request.is_empty():
		return value.next_id==1
	if not number(request.get("id")) or request.id<1 or request.id!=floor(request.id) or request.id!=value.next_id-1:
		return false
	if request.get("action")!="rest" or request.get("target")!=TARGET or request.get("phase") not in PHASES or request.get("reason") not in REASONS:
		return false
	if request.get("origin","user") not in ["user","self_arrangement"]: return false
	var phase_reasons := {"queued":["busy","meal"],"moving":["walking"],"resting":["resting"],"completed":["done"],"failed":["missing_target","blocked","layout_changed"]}
	if request.reason not in phase_reasons[request.phase]:
		return false
	if not number(request.get("created_seconds")) or not number(request.get("updated_seconds")) or request.updated_seconds<request.created_seconds or request.updated_seconds>now+.000001:
		return false
	return true
func restore(value: Dictionary, now: float) -> bool:
	if not valid_snapshot(value,now):
		return false
	next_id = int(value.next_id)
	latest = value.latest.duplicate(true)
	return true
func status_text() -> String:
	if latest.is_empty():
		return "可在本地聊天说：去树荫歇一会儿"
	var descriptions := {"queued":"已收到，等当前活动结束","moving":"正在走向树荫","resting":"正在树荫休息","completed":"已完成树荫休息","failed":"这次未完成"}
	var reasons := {"meal":"先回家吃饭，再去树荫","missing_target":"树荫地点暂时不可用","blocked":"去树荫的路暂时不通","layout_changed":"小院变化，原请求已取消"}
	var text: String = descriptions[phase()]
	if latest.reason in reasons:
		text += " · "+str(reasons[latest.reason])
	return "请求%d · %s"%[int(latest.id),text]
