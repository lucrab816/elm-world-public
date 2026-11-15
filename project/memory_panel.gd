extends Control

const Calendar = preload("res://world_calendar.gd")
const UiLayout = preload("res://ui_layout.gd")
const Memory = preload("res://explicit_memory.gd")
const Journal = preload("res://life_journal.gd")
var return_handler: Callable
var back_button: Button
var provider: Callable
var writer: Callable
var panel: PanelContainer
var list: ItemList
var topic: LineEdit
var body: LineEdit
var origin: Label
var status: Label
var forget_button: Button
var selected_id := 0
var ids: Array[int] = []
func label(parent: Node, text: String, font_size: int = 15) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",Color("405848"))
	parent.add_child(item)
	return item
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
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",10)
	panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := label(header,"你告诉埃尔的事",23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := Button.new()
	back_button = back
	back.text = "返回小院"
	back.pressed.connect(return_to_conversation)
	header.add_child(back)
	label(stack,"只有你在这里点保存才会记住，最多24条。聊天不会自动存入；写下约定不等于埃尔已答应或完成。")
	list = ItemList.new()
	list.custom_minimum_size.y = 140
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(select_record)
	stack.add_child(list)
	var new_button := Button.new()
	new_button.text = "新记一件事"
	new_button.pressed.connect(new_record)
	stack.add_child(new_button)
	origin = label(stack,"")
	label(stack,"主题")
	topic = LineEdit.new()
	topic.placeholder_text = "例如：我的称呼（最多32字）"
	topic.max_length = Memory.TITLE_LIMIT
	stack.add_child(topic)
	label(stack,"想让埃尔记住的内容")
	body = LineEdit.new()
	body.placeholder_text = "写一件事（最多160字）"
	body.max_length = Memory.TEXT_LIMIT
	stack.add_child(body)
	var actions := HBoxContainer.new()
	stack.add_child(actions)
	var save := Button.new()
	save.text = "保存这件事"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(save_record)
	actions.add_child(save)
	forget_button = Button.new()
	forget_button.text = "忘记这件事"
	forget_button.pressed.connect(forget_record)
	actions.add_child(forget_button)
	status = label(stack,"",14)
	status.custom_minimum_size.y = 40
	label(stack,"纠正或忘记后会清空临时聊天及模型决定原话（含自己安排），生活日记保留。",13)
	UiLayout.readable(panel)
	UiLayout.scrollable(panel)
	get_viewport().size_changed.connect(resize_panel)
	resize_panel()
	visible = false
func resize_panel() -> void:
	var available := get_viewport_rect().size
	panel.size = Vector2(minf(720,available.x-24),minf(700,available.y-24))
	panel.position = (available-panel.size)*.5
	settle.call_deferred()
func settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var available := get_viewport_rect().size
	panel.size = Vector2(minf(720,available.x-24),minf(700,available.y-24))
	panel.position = (available-panel.size)*.5
func refresh_list() -> void:
	list.clear()
	ids.clear()
	var memory = provider.call()
	for record in memory.records:
		list.add_item(str(record.title))
		ids.append(int(record.id))
		if int(record.id)==selected_id:
			list.select(ids.size()-1)
func open_memory() -> void:
	visible = true
	refresh_list()
	new_record()
	resize_panel()
func return_to_conversation() -> void:
	close_memory()
	if return_handler.is_valid(): return_handler.call()
func close_memory() -> void:
	visible = false
func new_record() -> void:
	selected_id = 0
	list.deselect_all()
	topic.clear()
	body.clear()
	forget_button.disabled = true
	origin.text = "新记录 · 来源：你主动告诉埃尔"
	status.text = "已记 %d / 24 条。点保存后才写入存档。"%provider.call().records.size()
	topic.grab_focus()
func select_record(index: int) -> void:
	selected_id = ids[index]
	var memory = provider.call()
	for record in memory.records:
		if int(record.id)==selected_id:
			topic.text = record.title
			body.text = record.text
			origin.text = "你主动告诉埃尔 · 最近更新：第%d天 %s"%[Calendar.day_at(float(record.updated_seconds)),Journal.clock_text(float(record.updated_seconds))]
			forget_button.disabled = false
			status.text = "可直接纠正内容，再点保存；不会自动改动其他记忆。"
func save_record() -> void:
	var result: Dictionary = writer.call("add" if selected_id==0 else "edit",selected_id,topic.text,body.text)
	status.text = result.message
	if result.ok:
		selected_id = int(result.id)
		refresh_list()
		select_record(ids.find(selected_id))
		status.text = result.message
func forget_record() -> void:
	var result: Dictionary = writer.call("forget",selected_id,"","")
	if result.ok:
		refresh_list()
		new_record()
	status.text = result.message
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		return_to_conversation()
		get_viewport().set_input_as_handled()
