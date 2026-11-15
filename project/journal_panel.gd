extends Control
const ArrangementReview = preload("res://arrangement_review.gd")
var arrangement_picker: OptionButton
var arrangement_choices: Array = []
var arrangement_signature := ""
var selected_arrangement := 0
var arrangement_selection_started := false
const UiLayout = preload("res://ui_layout.gd")
const Journal = preload("res://life_journal.gd")
const Chosen = preload("res://chosen_memories.gd")
var provider: Callable
var writer: Callable
var event_picker: OptionButton
var memory_button: Button
var memory_status: Label
var choices: Array = []
var choice_signature := ""
var choice_scope := ""
var panel: PanelContainer
var day_picker: OptionButton
var kind_picker: OptionButton
var content: RichTextLabel
var count_label: Label
var days: Array[int] = []
var selected_day := 0
var elapsed := 0.0
func setup(source: Callable, save_change: Callable) -> void:
	provider = source
	writer = save_change
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(.12,.16,.12,.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f8f5e9")
	style.set_corner_radius_all(16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := Label.new()
	title.text = "埃尔的生活日记"
	title.add_theme_font_size_override("font_size",23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color",Color("405848"))
	header.add_child(title)
	var back := Button.new()
	back.text = "返回小院"
	back.pressed.connect(close_diary)
	header.add_child(back)
	var description := Label.new()
	description.text = "翻翻真实生活与已保存的安排。日记合并计数；安排里的想法与实际结果分别展示。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color",Color("405848"))
	stack.add_child(description)
	var filters := HBoxContainer.new()
	stack.add_child(filters)
	day_picker = OptionButton.new()
	day_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_picker.item_selected.connect(func(index): selected_day = days[index]; refresh())
	filters.add_child(day_picker)
	kind_picker = OptionButton.new()
	for label in ["全部活动","看看周围","休息","用餐","开车兜风","陪德雷克","与米娅碰面","留下的片段","我的收藏","自主安排"]:
		kind_picker.add_item(label)
	kind_picker.item_selected.connect(func(_index): refresh())
	filters.add_child(kind_picker)
	count_label = Label.new()
	count_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	count_label.add_theme_color_override("font_color",Color("405848"))
	stack.add_child(count_label)
	var choose_row := HBoxContainer.new()
	stack.add_child(choose_row)
	event_picker = OptionButton.new()
	event_picker.fit_to_longest_item = false
	event_picker.item_selected.connect(func(_index): memory_button.disabled = false)
	event_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choose_row.add_child(event_picker)
	memory_button = Button.new()
	memory_button.pressed.connect(_change_memory)
	choose_row.add_child(memory_button)
	memory_status = Label.new()
	memory_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	memory_status.add_theme_font_size_override("font_size",13)
	memory_status.add_theme_color_override("font_color",Color("65725f"))
	stack.add_child(memory_status)
	arrangement_picker = OptionButton.new()
	arrangement_picker.fit_to_longest_item = false
	arrangement_picker.item_selected.connect(func(index):
		selected_arrangement = int(arrangement_choices[index].id) if index<arrangement_choices.size() else 0
		content.clear()
		refresh())
	arrangement_picker.visible = false
	stack.add_child(arrangement_picker)
	content = RichTextLabel.new()
	content.custom_minimum_size.y = 140
	content.bbcode_enabled = false
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_color_override("default_color",Color("405848"))
	content.add_theme_font_size_override("normal_font_size",17)
	stack.add_child(content)
	var note := Label.new()
	note.text = "普通聊天不存入日记。安排的原话单独标注，未保存的经历和理由不会补写；翻阅不调用模型。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color",Color("65725f"))
	stack.add_child(note)
	UiLayout.readable(panel)
	UiLayout.scrollable(panel)
	get_viewport().size_changed.connect(_resize)
	_resize()
	visible = false
func _resize() -> void:
	var available := get_viewport_rect().size
	panel.size = Vector2(minf(720,available.x-24),minf(620,available.y-24))
	panel.position = (available-panel.size)*.5
	_settle.call_deferred()
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var available := get_viewport_rect().size
	panel.size = Vector2(minf(720,available.x-24),minf(620,available.y-24))
	panel.position = (available-panel.size)*.5
func open_diary() -> void:
	selected_day = int(provider.call().day)
	kind_picker.select(0)
	visible = true
	refresh()
	_resize()
	day_picker.grab_focus()
func open_arrangements() -> void:
	arrangement_selection_started = false
	selected_arrangement = 0
	open_diary()
	kind_picker.select(9)
	refresh()
	arrangement_picker.grab_focus()
func close_diary() -> void:
	visible = false
func refresh() -> void:
	var data: Dictionary = provider.call()
	var journal = data.journal
	day_picker.visible = kind_picker.selected!=9
	arrangement_picker.visible = kind_picker.selected==9
	if kind_picker.selected==9:
		_refresh_arrangements(data.get("arrangements",{}))
		return
	var new_days: Array[int] = [int(data.day)]
	for event in journal.records:
		if not int(event.day) in new_days:
			new_days.append(int(event.day))
	new_days.sort()
	new_days.reverse()
	new_days.push_front(0)
	if days!=new_days:
		days = new_days
		day_picker.clear()
		for day in days:
			day_picker.add_item("全部日子" if day==0 else "第%d天%s"%[day,"（今天）" if day==int(data.day) else ""])
	if not selected_day in days:
		selected_day = 0
	day_picker.select(days.find(selected_day))
	if kind_picker.selected==7:
		event_picker.visible = false
		memory_button.visible = false
		memory_status.text = ""
		count_label.text = "各留一次真实完成的经历，不随日记轮转消失"
		content.text = data.keepsakes.summary()+"\n\n从功能启用后开始记录，不代表以前没有发生过。"
		return
	if kind_picker.selected==8:
		count_label.text = "你收藏的生活片段 · %d / 24 组"%data.chosen.records.size()
		content.text = data.chosen.summary()
		_set_choices(data.chosen.records,true)
		return
	var group: String = ["all","observe","rest","meal","car","pet","neighbor"][kind_picker.selected]
	var entries: Array = journal.entries(selected_day,group)
	_set_choices(entries,false)
	count_label.text = "显示 %d 组 · 已记录 %d / 128 组"%[entries.size(),journal.records.size()]
	var lines := PackedStringArray()
	for event in entries:
		var times: String = Journal.clock_text(float(event.last_seconds))
		if event.count>1:
			times = Journal.clock_text(float(event.first_seconds))+"—"+times
		lines.append("第%d天 %s · %s\n%s%s"%[int(event.day),times,event.location_name,Journal.ACTIONS[event.kind],"（共%d次）"%int(event.count) if event.count>1 else ""])
	var next_text := "\n\n".join(lines) if not lines.is_empty() else "这里还没有符合条件的生活记录。"
	if content.text!=next_text:
		var scroll := content.get_v_scroll_bar().value
		content.text = next_text
		content.get_v_scroll_bar().set_deferred("value",scroll)
func _refresh_arrangements(source: Dictionary) -> void:
	event_picker.visible = false
	memory_button.visible = false
	memory_status.text = ""
	arrangement_choices = ArrangementReview.records(source)
	count_label.text = "保留当前安排与最近12条历史 · 当前%d条 · 翻阅不调用模型"%arrangement_choices.size()
	if not arrangement_selection_started:
		selected_arrangement = int(arrangement_choices[0].id) if not arrangement_choices.is_empty() else 0
		arrangement_selection_started = true
	var labels: Array = []
	var selected := -1
	for i in range(arrangement_choices.size()):
		labels.append(ArrangementReview.label(arrangement_choices[i]))
		if int(arrangement_choices[i].id)==selected_arrangement: selected = i
	if selected<0: labels.append("没有记录" if arrangement_choices.is_empty() else "请选择仍保留的安排")
	var signature := JSON.stringify(labels)
	if signature!=arrangement_signature:
		arrangement_signature = signature
		arrangement_picker.clear()
		for label in labels: arrangement_picker.add_item(label)
	var text := "还没有保留自主安排。翻阅不会替埃尔新建机会；需要时可从小院给他一次安排机会。"
	if selected>=0:
		arrangement_picker.select(selected)
		text = ArrangementReview.detail(arrangement_choices[selected])
	else:
		if not arrangement_choices.is_empty(): text = "原来选中的安排已移出有限历史，请重新选择一条。"
		arrangement_picker.select(arrangement_choices.size())
		selected_arrangement = 0
	arrangement_picker.disabled = arrangement_choices.is_empty()
	if content.text!=text:
		var scroll := content.get_v_scroll_bar().value
		content.text = text
		content.get_v_scroll_bar().set_deferred("value",scroll)

func _set_choices(items: Array, removing: bool) -> void:
	event_picker.visible = true
	memory_button.visible = true
	memory_button.text = "移出收藏" if removing else "收藏这组"
	var signature := JSON.stringify([items,removing])
	if signature!=choice_signature:
		var scope := "%d:%d:%s"%[selected_day,kind_picker.selected,str(removing)]
		var had_prior: bool = scope==choice_scope and not choices.is_empty()
		var prior_key := ""
		if scope==choice_scope and event_picker.selected>=0 and event_picker.selected<choices.size():
			prior_key = _choice_key(choices[event_picker.selected],removing)
		choice_scope = scope
		choice_signature = signature
		choices = items.duplicate(true)
		event_picker.clear()
		if choices.is_empty():
			event_picker.add_item("没有可选的片段")
		else:
			var selected := 0 if not had_prior else -1
			for i in range(choices.size()):
				var item: Dictionary = choices[i]
				event_picker.add_item(Chosen.describe(item.event if removing else item))
				if not prior_key.is_empty() and _choice_key(item,removing)==prior_key: selected = i
			event_picker.select(selected)
	memory_button.disabled = choices.is_empty() or event_picker.selected<0
func _choice_key(item: Dictionary, removing: bool) -> String:
	if removing: return str(item.id)
	return "%d:%s:%s"%[int(item.day),item.location_id,item.kind]
func _change_memory() -> void:
	if event_picker.selected<0 or event_picker.selected>=choices.size(): return
	var removing := kind_picker.selected==8
	var value: Variant = int(choices[event_picker.selected].id) if removing else choices[event_picker.selected]
	var result: Dictionary = writer.call("remove" if removing else "add",value)
	memory_status.text = result.message
	choice_signature = ""
	refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	if elapsed>=1:
		elapsed = 0
		refresh()
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		close_diary()
		get_viewport().set_input_as_handled()
