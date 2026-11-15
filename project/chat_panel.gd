extends Control
const UiLayout = preload("res://ui_layout.gd")
const PetRecall = preload("res://pet_recall.gd")
# Manual chat with transient history; world actions and long-term memory are excluded.
const MAX_MESSAGES := 20
const ActionRequest = preload("res://action_request.gd")
const Transport = preload("res://chat_transport.gd")
const Recovery = preload("res://chat_recovery.gd")
var failed_message := ""
var last_error := ""
var recovery_actions: HBoxContainer
var restore_button: Button
var memory_requested: Callable
var memory_button: Button
var help_button: Button
var help_dialog: AcceptDialog
var transport = Transport.new()
var mode_picker: OptionButton
var mode_label: Label
var connection_label: Label
var budget_label: Label
var budget_view := {}
var local_ready := false
var cancel_button: Button
var external_busy_provider: Callable
var context_provider: Callable
var explicit_context_provider: Callable
var action_provider: Callable
var decision_issuer: Callable
var decision_applier: Callable
var decision_token := ""
var request_kind := "chat"
var panel: PanelContainer
var activity: Label
var events: Label
var history: Label
var messages_scroll: ScrollContainer
var entry: LineEdit
var send_button: Button
var status: Label
var transcript: Array[Dictionary] = []
var shutting_down := false
var pending := false
var request_id := 0
var refresh_elapsed := 0.0

func setup(provider: Callable, memory_provider: Callable = Callable(), local_action_provider: Callable = Callable(), proposal_issuer: Callable = Callable(), proposal_applier: Callable = Callable()) -> void:
	context_provider = provider
	explicit_context_provider = memory_provider
	action_provider = local_action_provider
	decision_issuer = proposal_issuer
	decision_applier = proposal_applier
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.12,0.16,0.12,0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f8f5e9")
	style.set_corner_radius_all(16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",10)
	panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := Label.new()
	title.text = "和埃尔聊聊"
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_color",Color("405848"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	help_button = Button.new()
	help_button.text = "聊天帮助"
	help_button.pressed.connect(open_help)
	header.add_child(help_button)
	var close_button := Button.new()
	close_button.text = "返回小院"
	close_button.pressed.connect(close_chat)
	header.add_child(close_button)
	var details := VBoxContainer.new()
	mode_label = _label(details,"当前：本地模拟",16)
	mode_picker = OptionButton.new()
	mode_picker.add_item("本地模拟（不调用模型）")
	mode_picker.add_item("真实聊天（使用订阅额度）")
	mode_picker.add_item("让埃尔决定：树荫休息（使用订阅）")
	mode_picker.add_item("让埃尔决定：看看盆栽（使用订阅）")
	mode_picker.item_selected.connect(func(index):
		mode_label.text = "当前：让埃尔决定 · 看看盆栽或继续生活" if index==3 else ("当前：让埃尔决定 · 仅树荫休息，检查后执行" if index==2 else ("当前：真实聊天 · 回复不代表行动已执行" if index==1 else "当前：本地模拟"))
		refresh_availability())
	stack.add_child(mode_picker)
	connection_label = _label(details,"",14)
	budget_label = _label(stack,"",14)
	_label(details,"本地限制：滚动5小时最多%d次尝试，间隔2分钟；失败或取消也计次。此处显示小世界的本地上限。"%Transport.MAX_ATTEMPTS,14)
	activity = _label(stack,"",15)
	var details_toggle := Button.new()
	details_toggle.text = "展开接入与生活详情"
	details_toggle.toggle_mode = true
	stack.add_child(details_toggle)
	stack.add_child(details)
	details.visible = false
	details_toggle.toggled.connect(func(open):
		details.visible = open
		details_toggle.text = "收起接入与生活详情" if open else "展开接入与生活详情"
		_resize_panel())
	memory_button = Button.new()
	memory_button.text = "管理埃尔记住的事"
	memory_button.tooltip_text = "普通聊天不自动存档。只有你明确保存的重要信息，才会长期记住；也可以在这里纠正或忘记。"
	memory_button.pressed.connect(func():
		if not pending and memory_requested.is_valid(): memory_requested.call())
	details.add_child(memory_button)
	_label(details,"聊天不会自动保存为长期记忆。需要时在这里明确保存、纠正或忘记一件事。",14)
	events = _label(details,"",14)
	messages_scroll = ScrollContainer.new()
	messages_scroll.custom_minimum_size.y = 120
	messages_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(messages_scroll)
	history = _label(messages_scroll,"还没有对话，先打个招呼吧。",16)
	history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry = LineEdit.new()
	entry.placeholder_text = "试试：今天陪过德雷克吗？（最多240字）"
	entry.max_length = 240
	entry.text_changed.connect(func(_text): _update_send())
	entry.text_submitted.connect(func(_text): send_message())
	entry.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			entry.accept_event()
			close_chat())
	stack.add_child(entry)
	send_button = Button.new()
	send_button.text = "发送"
	send_button.pressed.connect(send_message)
	stack.add_child(send_button)
	cancel_button = Button.new()
	cancel_button.text = "取消等待"
	cancel_button.pressed.connect(cancel_network)
	cancel_button.visible = false
	stack.add_child(cancel_button)
	status = _label(stack,"",14)
	recovery_actions = HBoxContainer.new()
	stack.add_child(recovery_actions)
	restore_button = Button.new()
	restore_button.text = "把原话放回输入框"
	restore_button.pressed.connect(restore_failed_message)
	recovery_actions.add_child(restore_button)
	var local_button := Button.new()
	local_button.text = "先用本地模拟"
	local_button.pressed.connect(use_local_mode)
	recovery_actions.add_child(local_button)
	var refresh_button := Button.new()
	refresh_button.text = "刷新本机状态"
	refresh_button.pressed.connect(refresh_local_status)
	recovery_actions.add_child(refresh_button)
	recovery_actions.visible = false
	help_dialog = AcceptDialog.new()
	help_dialog.title = "聊天接入与恢复"
	help_dialog.dialog_text = "真实聊天和「让埃尔决定」都需手动选择并发送，失败也计入本地尝试。决定模式可选树荫休息或看看盆栽，程序重新检查后执行；可以选择不去。看盆栽的决定会保存最近一次模型表达的想法。\n本地模拟不调用模型，埃尔的日常生活会继续。\n\n登录失效：按官方说明为本机接入工具用ChatGPT账号登录，再回来手动发送。\n额度不足：等待账户额度恢复；本地次数不代表账户额度。\n连接或回复超时：检查网络，等本地冷却结束后手动再发。\n\n「刷新本机状态」只检查工具文件和本地次数，不验证登录、不联网、不发送。\n「把原话放回输入框」只恢复文字，仍需你另按发送。"
	help_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_dialog.get_label().custom_minimum_size.x = 480
	help_dialog.ok_button_text = "知道了"
	help_dialog.add_button("官方登录说明",false,"auth_help")
	help_dialog.custom_action.connect(func(action):
		if action=="auth_help":
			OS.shell_open(Recovery.AUTH_HELP))
	add_child(help_dialog)
	_label(stack,"普通聊天退出后不保存；最近的盆栽决定、自己安排与模型想法会保存。",13)
	UiLayout.readable(panel)
	UiLayout.scrollable(panel)
	get_viewport().size_changed.connect(_resize_panel)
	_resize_panel()
	refresh_availability()
	visible = false

func _label(parent: Node, value: String, size_value: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",Color("405848"))
	parent.add_child(label)
	return label

func _resize_panel() -> void:
	var available := get_viewport_rect().size
	panel.size = Vector2(minf(720,available.x-24),minf(740,available.y-24))
	panel.position = (available-panel.size)*0.5
	_settle_panel.call_deferred()

func open_chat() -> void:
	visible = true
	_resize_panel()
	refresh_context()
	refresh_availability()
	entry.grab_focus()

func close_chat() -> void:
	_discard_decision()
	if pending:
		_append("系统","本次等待已取消。")
	transport.cancel()
	request_id += 1
	pending = false
	status.text = ""
	recovery_actions.visible = false
	help_dialog.hide()
	cancel_button.visible = false
	_update_send()
	entry.release_focus()
	visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		close_chat()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var result: Dictionary = transport.poll()
	if not result.is_empty() and pending:
		finish_network(result)
	if not visible:
		return
	refresh_elapsed += delta
	if refresh_elapsed>=0.5:
		refresh_elapsed = 0
		refresh_context()
		refresh_availability()

func finish_network(result: Dictionary) -> void:
	var can_decide := pending and visible and not shutting_down and not decision_token.is_empty()
	pending = false
	cancel_button.visible = false
	if result.get("status")=="ok" and result.get("reply") is String:
		if request_kind=="decision":
			if not can_decide or result.get("decision_token")!=decision_token or not decision_applier.is_valid():
				status.text = "这条建议已失效，没有执行动作。"
			else:
				_append("埃尔的想法（尚未执行）",result.reply)
				var outcome: Dictionary = decision_applier.call(result)
				_append("程序检查结果",str(outcome.message))
				status.text = "决定已处理 · 请看行动进度" if outcome.get("ok",false) else "建议未执行 · "+str(outcome.message)
		else:
			_append("埃尔（模型回复）",result.reply)
			status.text = "订阅回复完成 · 没有执行游戏动作"
		last_error = ""
		failed_message = ""
		recovery_actions.visible = false
	else:
		show_failure(str(result.get("diagnostic",result.get("status","request_failed"))))
		_append("系统",status.text)
	_discard_decision()
	refresh_availability()

func show_failure(code: String) -> void:
	last_error = code
	status.text = failure_text(code)
	recovery_actions.visible = true
	_update_send()
	_settle_panel.call_deferred()

func restore_failed_message() -> void:
	if pending or failed_message.is_empty():
		return
	if not entry.text.is_empty() and entry.text!=failed_message:
		return
	entry.text = failed_message
	entry.grab_focus()
	_update_send()

func use_local_mode() -> void:
	if pending or shutting_down:
		return
	mode_picker.select(0)
	refresh_availability()

func refresh_local_status() -> void:
	# Local file checks only; no CLI execution, login request or budget write.
	refresh_availability()

func open_help() -> void:
	help_dialog.popup_centered(Vector2i(mini(560,int(get_viewport_rect().size.x)-24),0))

func refresh_context() -> void:
	var context: Dictionary = context_provider.call()
	activity.text = "当前活动："+str(context.get("activity","暂时没有活动信息"))
	if context.has("action_status"):
		activity.text += "\n行动："+str(context.action_status)
	events.text = "生活记忆（最近保留的5组）：\n"+str(context.memory_recent) if context.has("memory_recent") else "近期真实到达记录：\n"+str(context.get("events","还没有记录"))

static func wait_text(seconds: int) -> String:
	if seconds>=3600:
		return str(seconds/3600)+"小时"+str((seconds%3600)/60)+"分"
	if seconds>=60:
		return str(seconds/60)+"分"+str(seconds%60)+"秒"
	return str(seconds)+"秒"

func refresh_availability() -> void:
	mode_label.text = "当前：让埃尔决定 · 看看盆栽或继续生活" if mode_picker.selected==3 else ("当前：让埃尔决定 · 仅树荫休息，检查后执行" if mode_picker.selected==2 else ("当前：真实聊天 · 回复不代表行动已执行" if mode_picker.selected==1 else "当前：本地模拟"))
	local_ready = transport.configured()
	budget_view = transport.budget_status(Time.get_unix_time_from_system())
	connection_label.text = "接入：本机工具已配置 · 登录及订阅可用性在手动发送时核实" if local_ready else "接入：本机工具未配置或已失效 · 本地模拟仍可使用"
	if budget_view.code=="budget_unreadable":
		budget_label.text = "本地尝试记录不可读，真实发送已暂停；不会自动清零。"
	else:
		budget_label.text = "小世界本地剩余尝试："+str(budget_view.remaining)+" / "+str(Transport.MAX_ATTEMPTS)
		if budget_view.code=="local_limit":
			budget_label.text += " · 约"+wait_text(budget_view.reset_seconds)+"后恢复1次"
		elif budget_view.cooldown_seconds>0:
			budget_label.text += " · 约"+wait_text(budget_view.cooldown_seconds)+"后可再发"
		else:
			budget_label.text += " · 已结束冷却"
	_update_send()

func _real_block() -> String:
	if external_busy_provider.is_valid() and external_busy_provider.call(): return "busy"
	if transport.pid>0:
		return "busy"
	if not local_ready:
		return "cli_missing"
	return str(budget_view.get("code","budget_unreadable"))

func _update_send() -> void:
	if memory_button!=null: memory_button.disabled = pending or not memory_requested.is_valid()
	var local_command := mode_picker.selected<2 and action_provider.is_valid() and ActionRequest.recognizes(entry.text)
	var real_blocked := mode_picker.selected>=1 and not local_command and _real_block()!="ok"
	send_button.disabled = shutting_down or pending or entry.text.strip_edges().is_empty() or real_blocked
	send_button.tooltip_text = failure_text(_real_block()) if real_blocked else ("这个请求由本地程序执行，不调用模型。" if local_command else "")
	send_button.text = "发送（本地行动）" if local_command else ("发送（请埃尔决定，使用订阅）" if mode_picker.selected>=2 else ("发送（使用订阅）" if mode_picker.selected==1 else "发送（本地模拟）"))
	mode_picker.disabled = pending
	if restore_button!=null:
		restore_button.disabled = pending or failed_message.is_empty() or (not entry.text.is_empty() and entry.text!=failed_message)
		restore_button.tooltip_text = "输入框已有新文字，请先保留或处理草稿。" if not entry.text.is_empty() and entry.text!=failed_message else "只恢复文字，不会发送。"

func _append(speaker: String, value: String) -> void:
	transcript.append({"speaker":speaker,"text":value})
	while transcript.size()>MAX_MESSAGES:
		transcript.pop_front()
	var lines: PackedStringArray = []
	for message in transcript:
		lines.append(str(message.speaker)+"："+str(message.text))
	history.text = "\n\n".join(lines)
	_scroll_latest.call_deferred()

func send_message() -> void:
	var value := entry.text.strip_edges().left(240)
	if shutting_down or not visible or pending or value.is_empty():
		return
	if mode_picker.selected<2 and action_provider.is_valid():
		var action_result: Dictionary = action_provider.call(value)
		if action_result.get("handled",false):
			_append("你",value)
			entry.clear()
			_append("行动请求（本地）",str(action_result.message))
			status.text = "本地请求结果 · 没有调用模型"
			_update_send()
			refresh_context()
			return
	refresh_availability()
	if mode_picker.selected>=1 and _real_block()!="ok":
		show_failure(_real_block())
		return
	decision_token = ""
	request_kind = "decision" if mode_picker.selected>=2 else "chat"
	if request_kind=="decision":
		if not decision_issuer.is_valid() or not decision_applier.is_valid():
			status.text = "这个决定入口尚未配置，没有发送请求。"
			return
		var ticket: Dictionary = decision_issuer.call("plant") if mode_picker.selected==3 else decision_issuer.call()
		if not ticket.get("ok",false):
			status.text = str(ticket.message)
			return
		decision_token = str(ticket.token)
	last_error = ""
	recovery_actions.visible = false
	if mode_picker.selected>=1:
		failed_message = value
	_append("你",value)
	entry.clear()
	pending = true
	request_id += 1
	var ticket := request_id
	_update_send()
	if mode_picker.selected>=1:
		var history_data: Array = []
		for message in transcript.slice(maxi(0,transcript.size()-6)):
			history_data.append({"speaker":message.speaker,"text":str(message.text).left(400)})
		var payload := {"message":value,"context":context_for(value),"recent_chat":history_data}
		if request_kind=="decision":
			payload["kind"] = "plant_decision" if mode_picker.selected==3 else "decision"
			payload["decision_token"] = decision_token
		var start_status: String = transport.begin(payload)
		if start_status!="ok":
			_discard_decision()
			pending = false
			show_failure(start_status)
			_append("系统",status.text)
			_update_send()
		else:
			status.text = "正在等待订阅回复（最多约75秒）…"
			cancel_button.visible = true
		refresh_availability()
		return
	status.text = "正在准备本地模拟回复…"
	await get_tree().create_timer(0.35).timeout
	if ticket!=request_id or not visible:
		return
	var context: Dictionary = context_for(value)
	_append("埃尔（本地模拟）",simulated_reply(value,context))
	pending = false
	status.text = "本地模拟回复完成 · 没有调用模型"
	_update_send()
	refresh_context()

func context_for(message: String) -> Dictionary:
	var context: Dictionary = context_provider.call().duplicate(true)
	if explicit_context_provider.is_valid():
		context.merge(explicit_context_provider.call(message),true)
	return context

static func simulated_reply(message: String, context: Dictionary) -> String:
	if "种菜" in message or "青菜" in message or "菜种" in message:
		return str(context.get("vegetable_project","还没有可确认的种菜记录。"))
	if "种花" in message or "小花圃" in message or "开花" in message or "花苞" in message or ("花" in message and ("浇" in message or "长" in message)):
		return str(context.get("flower_garden","还没有可确认的种花记录。"))
	if "安排" in message or "打算" in message or "自己选" in message or "后来做" in message:
		if "以前" in message or "过去" in message or "历史" in message: return str(context.get("self_arrangement_history","还没有保留安排历史。"))
		return str(context.get("self_arrangement","还没有保留自己安排的记录。"))
	if ("盆栽" in message or "植物" in message) and ("自己" in message or "主动" in message or "日常" in message):
		return str(context.get("plant_routine","还没有自主看盆栽的日常记录。"))
	if ("盆栽" in message or "植物" in message) and ("以前" in message or "过去" in message or "历史" in message or "做过哪些决定" in message):
		return str(context.get("plant_decision_history","还没有保留盆栽决定。"))
	if ("盆栽" in message or "小植物" in message or "这盆植物" in message) and (("为什么" in message or "原因" in message or "理由" in message) and ("看" in message or "去" in message)):
		return str(context.get("plant_decision_recall","还没有可回顾的决定。"))
	if ("盆栽" in message or "小植物" in message or "这盆植物" in message) and ("看过" in message or "去过" in message or "看了" in message):
		var visit_status := str(context.get("plant_visit",""))
		return (visit_status+"\n" if not visit_status.is_empty() else "")+str(context.get("plant_routine","还没有保留自主看盆栽的日常记录。"))
	if ("盆栽" in message or "小植物" in message or "这盆植物" in message or "花盆" in message) and ("为什么" in message or "原因" in message or "怎么想到" in message):
		return str(context.get("plant_arrangement_reason","尚无可确认的摆放原因。"))
	if ("盆栽" in message or "小植物" in message or "这盆植物" in message or "花盆" in message) and ("放" in message or "摆" in message or "哪里" in message):
		return str(context.get("plant_arrangement","尚未摆放小植物。"))
	if ("休息" in message or "歇" in message) and ("喜欢" in message or "偏好" in message or "倾向" in message):
		return str(context.get("rest_preference","最近完成的休息还不足以看出稳定的地点倾向。"))
	if "收藏" in message:
		return "你收藏的生活片段：\n"+str(context.get("chosen_memories","还没有可查询的收藏。"))
	if "珍藏" in message or "长期回忆" in message or "珍贵的回忆" in message:
		return "自动留下的生活片段：\n"+str(context.get("keepsakes","还没有新的片段。启用前的经历不会补写。"))+"\n\n你收藏的生活片段：\n"+str(context.get("chosen_memories","你还没有收藏生活片段。"))
	if "米娅" in message and ("德雷克" in message or "兔" in message) and ("摸" in message or "互动" in message or "相处" in message):
		return str(context.get("mia_rabbit","小院里还没有保留米娅和德雷克相处的记录。"))
	if ("菜苗" in message or "菜地" in message or "小芽" in message or "作物" in message) and ("长" in message or "怎么样" in message or "状态" in message):
		return str(context.get("garden_growth","暂时没有可确认的菜苗生长信息。"))
	if "米娅" in message or "邻居" in message:
		if "浇水" in message or "浇过" in message or "浇了" in message:
			return str(context.get("neighbor_water","还没有保留米娅完成浇水的记录。"))
		if "招呼" in message or "见过" in message or "见面" in message or "碰面" in message:
			return str(context.get("neighbor_memory","还没有保留与米娅打招呼的记录。"))
		return str(context.get("neighbor_activity","暂时没有可确认的邻居信息。"))
	if ("德雷克" in message or "兔" in message or "宠物" in message) and ("喜欢哪里" in message or "喜欢在哪" in message or "喜欢的地方" in message or "休息角落" in message or "偏爱" in message):
		return str(context.get("pet_favorite","暂时没有可确认的偏好地点。"))
	if not PetRecall.scope(message).is_empty():
		return PetRecall.reply(message,context)
	if "兔" in message or "宠物" in message or "德雷克" in message:
		return str(context.get("pet","暂时没有可确认的小兔子信息。"))
	if "记住" in message and not "记住了什么" in message:
		return "这句话不会自动保存。在聊天的「接入与生活详情」里打开「管理埃尔记住的事」，选择内容并保存。"
	if "记得" in message or "名字" in message or "称呼" in message or "告诉过" in message or "有哪些记忆" in message or "记住了什么" in message:
		return str(context.get("explicit_facts","还没有可引用的明确记录。可以在聊天详情的「管理埃尔记住的事」里主动保存。"))
	if "今天" in message or "今日" in message:
		return "今天最近保留的生活记录是：\n"+str(context.get("memory_today","生活记忆还未启用，不补写过去。"))
	if "最近" in message or "经历" in message or "哪里" in message:
		return "记录里最近发生的是：\n"+str(context.get("memory_recent",context.get("events","暂时还没有到达记录。")))
	if "为什么" in message or "休息" in message:
		var reason := str(context.get("rest_reason",""))
		return "最近一次休息选择的原因是："+reason if not reason.is_empty() else "还没有可回顾的休息选择，等实际发生后再看。"
	if "去" in message or "建" in message or "种" in message or "坐" in message:
		return "这类动作目前不能执行。可以明确说「去树荫歇一会儿」，由本地程序检查和安排；其他时候我会继续日常生活。"
	if "吃" in message or "饿" in message or "精力" in message:
		return str(context.get("needs","基础生活还没有可显示的信息。"))
	if "做" in message or "忙" in message or "你好" in message or "嗨" in message:
		return "你好！现在的实际活动是："+str(context.get("activity","暂时没有活动信息。"))
	return "收到你的话了。这是固定规则的本地模拟，暂时不能理解自由对话；可以试问我在做什么、最近去了哪里。"

func _scroll_latest() -> void:
	await get_tree().process_frame
	messages_scroll.scroll_vertical = int(messages_scroll.get_v_scroll_bar().max_value)

func _settle_panel() -> void:
	# Wrapped labels calculate their minimum height only after receiving a width.
	await get_tree().process_frame
	await get_tree().process_frame
	var available := get_viewport_rect().size
	var target := Vector2(minf(720,available.x-24),minf(740,available.y-24))
	panel.size = target
	panel.position = (available-panel.size)*0.5

func cancel_network() -> void:
	_discard_decision()
	transport.cancel()
	if not pending:
		return
	_append("系统","已取消等待，本地生活继续。")
	pending = false
	request_id += 1
	cancel_button.visible = false
	show_failure("cancelled")
	_update_send()

func stop_requests() -> bool:
	_discard_decision()
	shutting_down = true
	_update_send()
	transport.cancel()
	var deadline := Time.get_ticks_msec()+15000
	while transport.pid>0 and Time.get_ticks_msec()<deadline:
		transport.poll()
		await get_tree().create_timer(0.1).timeout
	return transport.pid<=0

static func failure_text(code: String) -> String:
	return Recovery.guidance(code)

func reset_after_memory_change() -> void:
	# Do not send obsolete recalled facts back through transient recent_chat.
	close_chat()
	transcript.clear()
	failed_message = ""
	last_error = ""
	history.text = "记忆卡片已纠正或移除，临时对话已清空，避免旧回答干扰。可以重新聊聊。"

func _discard_decision() -> void:
	if not decision_token.is_empty() and decision_applier.is_valid():
		decision_applier.call({"decision_token":decision_token,"status":"cancelled"})
	decision_token = ""
