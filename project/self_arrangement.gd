extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# One authorized opportunity, one shared-budget request, then a factual outcome.
const Transport = preload("res://chat_transport.gd")
const Journal = preload("res://life_journal.gd")
const Visit = preload("res://plant_visit.gd")
const Recovery = preload("res://chat_recovery.gd")
const LIMIT := 12
const CHOICES := ["none","rest_in_shade","visit_plant"]
const ACTIVE := ["waiting","requesting","executing"]
const TERMINAL := ["completed","declined","failed","cancelled"]
var transport = Transport.new()
var next_id := 1
var latest: Dictionary = {}
var history: Array = []
var notice := ""
var token := ""
var guard: Dictionary = {}
var started_ms := 0
func phase() -> String: return str(latest.get("phase",""))
func active() -> bool: return phase() in ACTIVE
func owns_slot() -> bool: return phase() in ["waiting","requesting"] or transport.pid>0
func arm(world, trigger: String = "once") -> Dictionary:
	if trigger not in ["once","low_frequency"]: return {"ok":false,"message":"未知机会来源。"}
	if world.fatal_save_error or not world.saving_enabled or world.quit_pending:
		notice = "存档暂时不可写，这次没有接下安排。"
	elif world.life_plan.phase=="thinking" or active() or transport.pid>0 or world.chat_panel.pending or world.chat_panel.transport.pid>0 or not world.model_decision_ticket.is_empty():
		notice = "已有安排或请求在进行，先等它结束。"
	elif not transport.configured():
		notice = Recovery.guidance("cli_missing")
	else:
		var budget: Dictionary = transport.budget_status(Time.get_unix_time_from_system())
		if budget.code!="ok": notice = Recovery.guidance(budget.code)
		else:
			var before := snapshot()
			if not latest.is_empty(): history.append(latest.duplicate(true))
			while history.size()>LIMIT: history.pop_front()
			latest = {"id":next_id,"trigger":trigger,"phase":"waiting","created_seconds":floorf(world.simulation_seconds),"updated_seconds":floorf(world.simulation_seconds),"observation":{},"observed_seconds":-1.0,"proposal":"","reply":"","execution":{},"execution_status":"","error":""}
			next_id += 1
			notice = ""
			if world._save_now(): return {"ok":true,"message":"机会已保存，埃尔方便时用订阅想一次；收起画面也最多一次。"}
			restore(before,world.simulation_seconds,false)
			notice = "机会没有保存成功，没有发起请求。"
	return {"ok":false,"message":notice}
func _eligible(world) -> bool:
	for plot in world.vegetable_plots:
		if plot.active() or plot.meeting: return false
	return world.patio_chat.phase.is_empty() and world.mailbox.reading_id.is_empty() and not world.border.active() and not world.forest.active() and not world.vegetable_project.active() and not world.vegetable_project.meeting and not world.elm_gardening.active() and world.resident.mode=="observe" and world.resident.route.is_empty() and not world.resident.user_action.active() and not world.resident.ride_requested and not world.pet_companion.active() and not world.pet_companion.requested and not world.neighbor_greeting.active() and not world.plant_visit.active() and not world.plant_routine.visit.active() and world.needs!=null and not world.needs.meal_active and world.needs.satiety>=65 and world.needs.energy>=45 and not world.chat_panel.pending and world.chat_panel.transport.pid<=0 and not world.quit_pending
func _observe(world) -> Dictionary:
	var choices: Array = ["none"]
	if world.resident._request_target_available(): choices.append("rest_in_shade")
	if world.plant_arrangement.phase=="placed" and world.arranged_plant!=null: choices.append("visit_plant")
	return {"opportunity_source":latest.get("trigger","once"),"activity":world.resident_status.text.left(160),"satiety":roundi(world.needs.satiety),"energy":roundi(world.needs.energy),"sunlight":world.sunlight,"rest_experience":world.rest_preference.chat_context(),"memory_recent":world.journal.summary().left(900),"plant":world.plant_arrangement.description().left(240),"allowed_choices":choices}
func _finish(world, value: String, error: String = "") -> void:
	latest.phase = value
	latest.error = error.left(64)
	latest.updated_seconds = floorf(world.simulation_seconds)
	token = ""
	guard.clear()
	notice = ""
	world._save_now()
func advance(world) -> void:
	var result: Dictionary = transport.poll()
	if not result.is_empty() and phase()=="requesting": receive(world,result)
	if phase()=="waiting":
		if world.simulation_seconds-float(latest.created_seconds)>600:
			_finish(world,"cancelled","wait_timeout")
		elif _eligible(world): _begin(world)
	elif phase()=="executing": _sync(world)
func _begin(world) -> void:
	if latest.get("trigger","once")=="low_frequency":
		var budget: Dictionary = transport.budget_status(Time.get_unix_time_from_system())
		if budget.code!="ok":
			_finish(world,"cancelled",str(budget.code))
			return
	latest.observation = _observe(world)
	latest.observed_seconds = floorf(world.simulation_seconds)
	latest.phase = "requesting"
	latest.updated_seconds = floorf(world.simulation_seconds)
	token = Crypto.new().generate_random_bytes(16).hex_encode()
	guard = {"world_id":str(world.state_template.world_id),"layout":world.resident._layout_signature(),"intent":world.user_intent_serial,"plant_target":world.plant_arrangement.target}
	started_ms = Time.get_ticks_msec()
	# Persist consumption of the opportunity before reserving quota or creating any process.
	if not world._save_now():
		_finish(world,"failed","save_failed")
		return
	var code: String = transport.begin({"kind":"self_arrangement","message":"请根据此刻的状态与近期真实经历，自己选择一件方便做的小事，也可以继续日常。","context":latest.observation,"decision_token":token})
	if code!="ok": _finish(world,"failed",code)
func receive(world, result: Dictionary) -> bool:
	if phase()!="requesting" or token.is_empty(): return false
	var valid: bool = result.get("status")=="ok" and result.get("source")=="codex_subscription" and result.get("decision_token")==token and result.get("reply") is String and not str(result.get("reply","")).strip_edges().is_empty() and str(result.get("reply","")).length()<=1200 and result.get("proposal") in latest.observation.allowed_choices
	for key in result:
		if key not in ["status","source","reply","proposal","decision_token","metrics"]: valid = false
	if not valid:
		_finish(world,"failed",str(result.get("diagnostic",result.get("status","invalid_decision"))) if result.get("status")!="ok" else "invalid_decision")
		return false
	latest.proposal = result.proposal
	latest.reply = Visit.clean_note(result.reply)
	if world.fatal_save_error or not world.saving_enabled or world.quit_pending or Time.get_ticks_msec()-started_ms>90000 or str(world.state_template.world_id)!=guard.world_id or world.resident._layout_signature()!=guard.layout or world.user_intent_serial!=guard.intent or world.plant_arrangement.target!=guard.plant_target or world.resident.user_action.active() or world.plant_visit.active() or world.plant_routine.visit.active():
		_finish(world,"failed","world_changed")
		return false
	var proposal: String = result.proposal
	if (proposal=="visit_plant" and (world.plant_arrangement.phase!="placed" or world.arranged_plant==null)) or (proposal=="rest_in_shade" and not world.resident._request_target_available()):
		_finish(world,"failed","world_changed")
		return false
	var before := snapshot()
	var before_visit: Dictionary = world.plant_visit.snapshot()
	var before_action: Dictionary = world.resident.user_action.snapshot()
	latest.proposal = proposal
	latest.reply = Visit.clean_note(result.reply)
	latest.updated_seconds = floorf(world.simulation_seconds)
	latest.phase = "declined" if proposal=="none" else "executing"
	if proposal=="visit_plant":
		world.plant_visit.enqueue(world.plant_arrangement.target,world.simulation_seconds,false,latest.reply)
		latest.execution = {"kind":"plant","id":world.plant_visit.latest.id}
	elif proposal=="rest_in_shade":
		world.resident.user_action.enqueue(world.simulation_seconds,"self_arrangement")
		latest.execution = {"kind":"rest","id":world.resident.user_action.latest.id}
	latest.execution_status = "" if proposal=="none" else "queued"
	if not world._save_now():
		world.plant_visit.restore(before_visit)
		world.resident.user_action.restore(before_action,world.simulation_seconds)
		restore(before,world.simulation_seconds,false)
		_finish(world,"failed","save_failed")
		return false
	token = ""
	guard.clear()
	return true
func _sync(world) -> void:
	var record: Dictionary = world.plant_visit.latest if latest.execution.kind=="plant" else world.resident.user_action.latest
	if record.get("id")!=latest.execution.id:
		_finish(world,"failed","action_replaced")
		return
	if record.phase in ["completed","failed"]:
		latest.execution_status = record.phase
		_finish(world,record.phase,"" if record.phase=="completed" else "action_failed")
	elif latest.execution_status!=record.phase:
		latest.execution_status = record.phase
		latest.updated_seconds = floorf(world.simulation_seconds)
		world._save_now()
func cancel(world, reason: String = "cancelled") -> void:
	if phase() not in ["waiting","requesting"]: return
	transport.cancel()
	_finish(world,"cancelled",reason)
func stop(world) -> bool:
	cancel(world,"exit")
	transport.cancel()
	var deadline := Time.get_ticks_msec()+15000
	while transport.pid>0 and Time.get_ticks_msec()<deadline:
		transport.poll()
		await world.get_tree().create_timer(.1).timeout
	return transport.pid<=0
func status_text() -> String:
	if latest.is_empty(): return "给一次机会，方便时用订阅想一次，也可以什么都不做。"
	var labels := {"waiting":"等方便时自己安排一次","requesting":"正在想一件小事（使用订阅）","executing":"已选好，行动尚未完成","completed":"实际完成了自己选的小事","declined":"选择继续日常，没有新增行动","failed":"这次安排未完成，不会自动重试","cancelled":"这次思考已取消，不会重新发送"}
	return "安排%d · %s"%[int(latest.id),labels[phase()]]
func recall() -> String:
	if latest.is_empty(): return "还没有保留自己安排的记录。"
	var text := status_text()+"\n机会来源："+("已开启的低频安排" if latest.get("trigger","once")=="low_frequency" else "用户给出的一次机会")
	var names := {"none":"继续日常","rest_in_shade":"去树荫休息","visit_plant":"看看盆栽"}
	if not str(latest.proposal).is_empty(): text += "\n当时选择："+names[latest.proposal]
	if not latest.observation.is_empty():
		var o: Dictionary = latest.observation
		text += "\n当时观察（第%d天 %s）：饱腹%d，精力%d，%s日照；近期%d次完成休息中长椅%d次、树荫%d次。"%[Calendar.day_at(float(latest.observed_seconds)),Journal.clock_text(latest.observed_seconds),int(o.satiety),int(o.energy),"柔和" if o.sunlight=="gentle" else "强烈",int(o.rest_experience.completed_in_recent_window),int(o.rest_experience.bench_count),int(o.rest_experience.shade_count)]
	text += "\n当时模型表达（原话节选，不是行动证明）："+str(latest.reply) if not str(latest.reply).is_empty() else "\n没有保留模型原话。"
	if phase()=="executing": text += "\n实际进度："+str({"queued":"排队等待","moving":"还在途中","looking":"正在观察","resting":"正在休息"}.get(latest.execution_status,"进行中"))
	if not str(latest.error).is_empty():
		var reasons := {"restart":"重开取消未完成的思考","exit":"退出取消未完成的思考","sleep":"睡眠取消未完成的思考","wait_timeout":"等待时间较久，这次机会已结束","world_changed":"等待时有新的邀请或小院发生变化","save_failed":"未能保存决定，未新增行动","action_failed":"执行器报告未完成","action_replaced":"原行动已改变，无法确认完成","auto_disabled":"关闭低频安排，未完成的思考已取消"}
		text += "\n说明："+str(reasons.get(latest.error,Recovery.guidance(latest.error)))
	return text
func history_recall() -> String:
	var records: Array = history.duplicate(true)
	if not latest.is_empty(): records.append(latest)
	if records.is_empty(): return "还没有保留自己安排的记录。"
	var lines := PackedStringArray()
	var names := {"":"尚未选择","none":"继续日常","rest_in_shade":"树荫休息","visit_plant":"看盆栽"}
	var states := {"waiting":"等待","requesting":"思考中","executing":"尚未完成","completed":"实际完成","declined":"没有新增行动","failed":"未完成","cancelled":"已取消"}
	for record in records.slice(maxi(0,records.size()-3)):
		var line := "安排%d · 第%d天 %s · %s · %s"%[int(record.id),Calendar.day_at(float(record.created_seconds)),Journal.clock_text(record.created_seconds),names[record.proposal],states[record.phase]]
		line += "；原话节选："+str(record.reply).left(120)+("…" if str(record.reply).length()>120 else "") if not str(record.reply).is_empty() else "；没有保留模型原话"
		lines.append(line)
	return "最近保留的安排（最多显示3条）：\n"+"\n".join(lines)
func clear_statements() -> void:
	if not latest.is_empty(): latest.reply = ""
	for record in history: record.reply = ""
func snapshot() -> Dictionary:
	return {"version":1,"next_id":next_id,"latest":latest.duplicate(true),"history":history.duplicate(true)}
func restore(value: Dictionary, now: float, cancel_pending: bool = true) -> void:
	next_id = int(value.next_id)
	latest = value.latest.duplicate(true)
	history = value.history.duplicate(true)
	if cancel_pending:
		token = ""
		guard.clear()
	if cancel_pending and phase() in ["waiting","requesting"]:
		latest.phase = "cancelled"
		latest.error = "restart"
		latest.updated_seconds = floorf(now)
static func valid_snapshot(value: Variant, now: float, actor: Dictionary, world_state: Dictionary) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not Journal.number(value.get("next_id")) or value.next_id<1 or value.next_id!=floor(value.next_id) or not value.get("latest") is Dictionary or not value.get("history") is Array or value.history.size()>LIMIT: return false
	var records: Array = value.history.duplicate()
	if not value.latest.is_empty(): records.append(value.latest)
	elif value.next_id!=1 or not records.is_empty(): return false
	var previous_id := 0
	var previous_time := -1.0
	for record in records:
		if not record is Dictionary or not Journal.number(record.get("id")) or record.id!=floor(record.id) or record.id<=previous_id or record.id>=value.next_id or record.get("phase") not in ACTIVE+TERMINAL: return false
		if record!=value.latest and record.phase not in TERMINAL: return false
		if not Journal.number(record.get("created_seconds")) or not Journal.number(record.get("updated_seconds")) or record.created_seconds<previous_time or record.updated_seconds<record.created_seconds or record.updated_seconds>now: return false
		if record.get("trigger","once") not in ["once","low_frequency"]: return false
		if record.get("proposal") not in CHOICES+[""] or not record.get("reply") is String or record.reply.length()>Visit.NOTE_LIMIT or record.reply!=Visit.clean_note(record.reply) or not record.get("error") is String or record.error.length()>64 or not record.get("execution") is Dictionary or not record.get("execution_status") is String: return false
		var o = record.get("observation")
		if not o is Dictionary or JSON.stringify(o).length()>2400: return false
		if o.is_empty():
			if record.get("observed_seconds")!=-1: return false
		elif not Journal.number(record.get("observed_seconds")) or record.observed_seconds<record.created_seconds or record.observed_seconds>record.updated_seconds: return false
		if not o.is_empty():
			if o.get("opportunity_source","once")!=record.get("trigger","once"): return false
			if not o.get("activity") is String or o.activity.length()>160 or not o.get("memory_recent") is String or o.memory_recent.length()>900 or not o.get("plant") is String or o.plant.length()>240 or o.get("sunlight") not in ["gentle","strong"]: return false
			for key in ["satiety","energy"]:
				if not Journal.number(o.get(key)) or o[key]>100: return false
			var r = o.get("rest_experience")
			if not r is Dictionary or r.get("window_limit")!=8 or r.get("observed_tendency") not in ["长椅","树荫","尚不确定"]: return false
			for key in ["completed_in_recent_window","bench_count","shade_count"]:
				if not Journal.number(r.get(key)) or r[key]>8 or r[key]!=floor(r[key]): return false
			if r.bench_count+r.shade_count!=r.completed_in_recent_window: return false
			if not o.get("allowed_choices") is Array or o.allowed_choices.is_empty() or o.allowed_choices.size()>3 or "none" not in o.allowed_choices: return false
			var seen := {}
			for choice in o.allowed_choices:
				if choice not in CHOICES or seen.has(choice): return false
				seen[choice] = true
		if record.phase=="requesting" and o.is_empty(): return false
		if record.phase in ["waiting","requesting"] and (record.proposal!="" or not record.execution.is_empty()): return false
		if record.phase=="declined" and (record.proposal!="none" or o.is_empty() or not record.execution.is_empty()): return false
		if record.phase in ["executing","completed"]:
			var e: Dictionary = record.execution
			if record.proposal not in ["rest_in_shade","visit_plant"] or o.is_empty() or record.proposal not in o.allowed_choices or e.get("kind")!=("plant" if record.proposal=="visit_plant" else "rest") or not Journal.number(e.get("id")) or e.id<1 or e.id!=floor(e.id): return false
			if record.phase=="completed" and record.execution_status!="completed": return false
			if record.phase=="executing":
				var current: Dictionary = world_state.get("plant_visit",{}).get("latest",{}) if e.kind=="plant" else actor.get("user_action",{}).get("latest",{})
				if current.get("id")!=e.id or current.get("phase") not in ["queued","moving","looking","resting","completed","failed"]: return false
				if e.kind=="rest" and current.get("origin")!="self_arrangement": return false
		previous_id = int(record.id)
		previous_time = float(record.updated_seconds)
	return value.latest.is_empty() or value.latest.id==value.next_id-1
