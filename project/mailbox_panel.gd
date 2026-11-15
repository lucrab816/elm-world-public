extends AcceptDialog

var mailbox
var on_post: Callable
var on_read: Callable
var photo_provider: Callable
var filters: HBoxContainer
var list: ItemList
var detail: RichTextLabel
var empty: Label
var composer: VBoxContainer
var back: Button
var write: Button
var reply_button: Button
var save_attachment: Button
var attachment_menu: MenuButton
var attachment_status: Label
var exportable_photos: Array = []
var compose_senders: HBoxContainer
var compose_title: Label
var compose_body: TextEdit
var compose_image := ""
var image_preview: TextureRect
var remove_image: Button
var compose_status: Label
var reply_to := ""
var filter := ""
var selected_id := ""
var displayed: Array = []
var signature := ""

func open_inbox(source, scan: Callable, refresh_badge: Callable, lookup_photo: Callable = Callable()) -> void:
	mailbox = source
	on_post = scan
	on_read = refresh_badge
	photo_provider = lookup_photo
	title = "埃尔的信箱"
	ok_button_text = "关闭"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(410,300)
	stack.add_theme_constant_override("separation",8)
	add_child(stack)
	var toolbar := HBoxContainer.new()
	stack.add_child(toolbar)
	back = Button.new()
	back.text = "‹ 返回信箱"
	back.pressed.connect(_go_back)
	toolbar.add_child(back)
	filters = HBoxContainer.new()
	filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(filters)
	var group := ButtonGroup.new()
	for sender in [""]+mailbox.SENDERS:
		var button := Button.new()
		button.text = "全部" if sender.is_empty() else sender
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = sender.is_empty()
		button.pressed.connect(_select_filter.bind(sender))
		filters.add_child(button)
	write = Button.new()
	write.text = "写信"
	write.pressed.connect(_show_composer.bind(false))
	toolbar.add_child(write)
	reply_button = Button.new()
	reply_button.text = "回信"
	reply_button.pressed.connect(_show_composer.bind(true))
	toolbar.add_child(reply_button)
	save_attachment = Button.new()
	save_attachment.text = "保存附件"
	save_attachment.pressed.connect(func(): _choose_attachment_path(0))
	toolbar.add_child(save_attachment)
	attachment_menu = MenuButton.new()
	attachment_menu.text = "保存附件 ▾"
	attachment_menu.get_popup().id_pressed.connect(_choose_attachment_path)
	toolbar.add_child(attachment_menu)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_open_conversation)
	stack.add_child(list)
	empty = Label.new()
	empty.text = "这里还没有信。"
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(empty)
	detail = RichTextLabel.new()
	detail.selection_enabled = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(detail)
	attachment_status = Label.new()
	attachment_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attachment_status.hide()
	stack.add_child(attachment_status)
	_build_composer(stack)
	var timer := Timer.new()
	timer.wait_time = 1
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)
	_show_inbox()
	popup_centered()

func _select_filter(sender: String) -> void:
	filter = sender
	_refresh()

func _go_back() -> void:
	if composer.visible and not reply_to.is_empty():
		_show_thread()
	else:
		_show_inbox()

func _show_inbox() -> void:
	reply_to = ""
	reply_button.hide()
	_hide_attachment_controls()
	selected_id = ""
	signature = ""
	back.text = "‹ 返回信箱"
	back.hide()
	composer.hide()
	detail.hide()
	filters.show()
	write.show()
	list.show()
	_refresh()
	list.grab_focus()

func _refresh() -> void:
	if composer.visible: return
	if detail.visible:
		_render_detail()
		return
	var ordered: Array = mailbox.conversations(filter)
	var rows := PackedStringArray()
	for conversation in ordered:
		var letter: Dictionary = conversation.latest
		var reply: String = letter.reply
		var fresh: bool = conversation.fresh
		var date: String = conversation.date
		var preview: String = reply if not reply.is_empty() else letter.body
		preview = preview.replace("\r"," ").replace("\n"," ").strip_edges()
		if preview.length()>14: preview = preview.left(14)+"…"
		rows.append("%s%s   %s   %s   %s" % ["● " if fresh else "",letter.sender,date,_status(letter),preview])
	var current := str(ordered.map(func(letter): return letter.id))+"|"+str(rows)
	if current==signature: return
	signature = current
	displayed = ordered
	list.clear()
	for row in rows:
		list.add_item(row)
		if row.begins_with("●"): list.set_item_custom_fg_color(list.item_count-1,Color("a8dc9d"))
		list.set_item_tooltip_enabled(list.item_count-1,false)
	empty.visible = rows.is_empty()

func _status(letter: Dictionary) -> String:
	if not letter.reply.is_empty(): return "埃尔已回信"
	return "埃尔已读" if letter.get("read",false) else "埃尔还没读"

func _open_conversation(index: int) -> void:
	selected_id = displayed[index].id
	_show_thread()

func _show_thread() -> void:
	composer.hide()
	back.text = "‹ 返回信箱"
	list.hide()
	empty.hide()
	filters.hide()
	write.hide()
	back.show()
	reply_button.show()
	detail.show()
	signature = ""
	_render_detail()
	back.grab_focus()

func _render_detail() -> void:
	var turns: Array = mailbox.thread(selected_id)
	var attached := {}
	if photo_provider.is_valid():
		for turn in turns:
			var id := int(turn.get("photo_id",0))
			if id>0: attached[id] = photo_provider.call(id)
	var current: String = str(turns)+mailbox.potato_seed_letter+mailbox.potato_parcel+str(attached.keys())+str(attached.values().map(func(item): return not item.is_empty()))
	if current==signature: return
	signature = current
	detail.clear()
	exportable_photos.clear()
	for i in range(turns.size()):
		var letter: Dictionary = turns[i]
		if i>0: detail.add_text("\n\n────────\n\n")
		_add_heading(letter.sender+(" 的来信" if i==0 else " 的续信"),letter.get("posted_day",""))
		detail.add_text("\n"+letter.body)
		var incoming: String = letter.get("incoming_image","")
		if not incoming.is_empty():
			var picture := Image.new()
			if picture.load_jpg_from_buffer(Marshalls.base64_to_raw(incoming))==OK:
				var width := mini(picture.get_width(),340)
				detail.add_text("\n\n来信图片\n")
				detail.add_image(ImageTexture.create_from_image(picture),width,roundi(float(width)*picture.get_height()/picture.get_width()))
		var parcel: String = mailbox.attachment_text(letter)
		if not parcel.is_empty(): detail.add_text("\n\n"+parcel)
		detail.add_text("\n\n")
		_add_heading("埃尔的回信",letter.get("reply_day",""))
		detail.add_text("\n"+(_status(letter) if letter.reply.is_empty() else letter.reply))
		var photo_id := int(letter.get("photo_id",0))
		if photo_id>0:
			var item: Dictionary = attached.get(photo_id,{})
			var image := Image.new()
			if not item.is_empty() and image.load_jpg_from_buffer(Marshalls.base64_to_raw(item.jpeg))==OK:
				if not exportable_photos.any(func(existing): return existing.id==item.id):
					exportable_photos.append(item)
				detail.add_text("\n\n照片 · "+item.title+"\n")
				detail.add_image(ImageTexture.create_from_image(image),340,191)
			else:
				detail.add_text("\n\n照片已从相册移除")
		mailbox.mark_reply_viewed(letter)
	save_attachment.visible = exportable_photos.size()==1
	attachment_menu.visible = exportable_photos.size()>1
	var popup := attachment_menu.get_popup()
	popup.clear()
	for i in range(exportable_photos.size()):
		var photo: Dictionary = exportable_photos[i]
		popup.add_item("%s（照片 %d）"%[photo.title,int(photo.id)],i)
	detail.scroll_to_line(maxi(0,detail.get_line_count()-1))
	on_read.call()

func _hide_attachment_controls() -> void:
	save_attachment.hide()
	attachment_menu.hide()
	attachment_status.hide()

func _choose_attachment_path(index: int) -> void:
	if index<0 or index>=exportable_photos.size(): return
	var item: Dictionary = exportable_photos[index]
	var bytes := Marshalls.base64_to_raw(item.jpeg)
	var dialog := FileDialog.new()
	dialog.title = "保存埃尔的照片"
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.add_filter("*.jpg, *.jpeg","JPEG 照片")
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	dialog.current_file = "埃尔-%s-%d.jpg"%[item.title,int(item.id)]
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.file_selected.connect(func(path: String):
		var result := _save_jpeg(path,bytes)
		attachment_status.text = ("已保存 "+path.get_file()) if result==OK else "附件未能保存，请检查目录权限或换一个位置。"
		attachment_status.show()
		dialog.queue_free())
	dialog.popup_centered_ratio(.7)

static func _save_jpeg(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var result := file.get_error()
	file.close()
	return result

func _add_heading(label: String, date: String) -> void:
	detail.push_bold()
	detail.add_text(label)
	detail.pop()
	if not date.is_empty(): detail.add_text("   "+date)

func _show_composer(continuing: bool) -> void:
	reply_to = selected_id if continuing else ""
	compose_body.clear()
	_clear_compose_image()
	compose_status.text = ""
	compose_senders.visible = not continuing
	compose_title.visible = continuing
	back.text = "‹ 返回原信" if continuing else "‹ 返回信箱"
	if continuing:
		var turns: Array = mailbox.thread(reply_to)
		compose_title.text = "以 %s 的身份回复这封信" % mailbox.reply_sender(turns[0])
	reply_button.hide()
	_hide_attachment_controls()
	detail.hide()
	list.hide()
	empty.hide()
	filters.hide()
	write.hide()
	back.show()
	composer.show()
	compose_body.grab_focus()

func _build_composer(stack: VBoxContainer) -> void:
	composer = VBoxContainer.new()
	composer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(composer)
	compose_title = Label.new()
	composer.add_child(compose_title)
	compose_senders = HBoxContainer.new()
	composer.add_child(compose_senders)
	var group := ButtonGroup.new()
	for sender in mailbox.SENDERS:
		var option := Button.new()
		option.text = sender
		option.toggle_mode = true
		option.button_group = group
		option.button_pressed = sender=="玩家"
		compose_senders.add_child(option)
	var body := TextEdit.new()
	compose_body = body
	body.placeholder_text = "写给埃尔……"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	composer.add_child(body)
	var attachments := HBoxContainer.new()
	composer.add_child(attachments)
	var choose_image := Button.new()
	choose_image.text = "添加图片"
	attachments.add_child(choose_image)
	remove_image = Button.new()
	remove_image.text = "移除图片"
	remove_image.pressed.connect(_clear_compose_image)
	attachments.add_child(remove_image)
	image_preview = TextureRect.new()
	image_preview.custom_minimum_size = Vector2(96,52)
	image_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	attachments.add_child(image_preview)
	_clear_compose_image()
	var chooser := FileDialog.new()
	chooser.access = FileDialog.ACCESS_FILESYSTEM
	chooser.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	chooser.use_native_dialog = true
	chooser.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; 图片"])
	add_child(chooser)
	choose_image.pressed.connect(func(): chooser.popup_centered_ratio(.7))
	chooser.file_selected.connect(_load_compose_image)
	var status := Label.new()
	compose_status = status
	composer.add_child(status)
	var send := Button.new()
	send.text = "投递给埃尔"
	composer.add_child(send)
	send.pressed.connect(func():
		var sender: String = group.get_pressed_button().text
		if not reply_to.is_empty():
			var turns: Array = mailbox.thread(reply_to)
			sender = mailbox.reply_sender(turns[0])
		var error: String = mailbox.post(sender,body.text,reply_to,compose_image)
		status.text = error
		if not error.is_empty(): return
		body.clear()
		_clear_compose_image()
		on_post.call()
		if not reply_to.is_empty():
			_show_thread()
			return
		filter = ""
		filters.get_child(0).set_pressed_no_signal(true)
		_show_inbox())

func _clear_compose_image() -> void:
	compose_image = ""
	image_preview.texture = null
	image_preview.hide()
	remove_image.hide()

func _load_compose_image(path: String) -> void:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>16*1024*1024:
		compose_status.text = "请选择一张 16 MB 以内的图片。"
		return
	var picture := Image.load_from_file(path)
	if picture==null or picture.is_empty():
		compose_status.text = "这张图片无法打开。"
		return
	var longest := maxi(picture.get_width(),picture.get_height())
	var factor := minf(1.0,640.0/longest)
	picture.resize(maxi(1,roundi(picture.get_width()*factor)),maxi(1,roundi(picture.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	var encoded := Marshalls.raw_to_base64(picture.save_jpg_to_buffer(.78))
	while encoded.length()>mailbox.IMAGE_LIMIT and maxi(picture.get_width(),picture.get_height())>32:
		picture.resize(maxi(1,roundi(picture.get_width()*.8)),maxi(1,roundi(picture.get_height()*.8)),Image.INTERPOLATE_LANCZOS)
		encoded = Marshalls.raw_to_base64(picture.save_jpg_to_buffer(.78))
	if not mailbox.valid_image(encoded):
		compose_status.text = "这张图片无法压缩，请换一张。"
		return
	compose_image = encoded
	image_preview.texture = ImageTexture.create_from_image(picture)
	image_preview.show()
	remove_image.show()
	compose_status.text = ""
