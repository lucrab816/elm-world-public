extends AcceptDialog

const Calendar = preload("res://world_calendar.gd")

func show_album(hobbies) -> void:
	title = "埃尔的相册 · %d / %d"%[hobbies.photos.size(),hobbies.LIMIT]
	ok_button_text = "关闭"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(410,290)
	add_child(column)
	if hobbies.photos.is_empty():
		var empty := Label.new()
		empty.text = "埃尔还没有拍照。"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(empty)
	else:
		var picker := OptionButton.new()
		column.add_child(picker)
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(picture)
		var photos: Array = hobbies.photos.duplicate()
		photos.reverse()
		for item in photos: picker.add_item(item.title+" · 第%d天"%[Calendar.day_at(item.seconds)])
		var display := func(index: int):
			var image := Image.new()
			if image.load_jpg_from_buffer(Marshalls.base64_to_raw(photos[index].jpeg))==OK:
				picture.texture = ImageTexture.create_from_image(image)
		picker.item_selected.connect(display)
		display.call(0)
	popup_centered()

func show_notebook(hobbies) -> void:
	title = "埃尔的画册 · %d / 24"%hobbies.drawings.size()
	ok_button_text = "关闭"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(380,290)
	add_child(column)
	var picker := OptionButton.new()
	column.add_child(picker)
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(picture)
	var words := Label.new()
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(words)
	var art = preload("res://elm_drawings.gd")
	var entries: Array = []
	for item in hobbies.drawings:
		picker.add_item(art.TITLES[int(item.motif)]+" · 第%d天"%Calendar.day_at(item.seconds)+(" · 已挂上墙" if item.id==hobbies.framed else ""))
		entries.append(item)
	if entries.is_empty():
		picker.hide()
		picture.hide()
		words.text = "等埃尔画完第一张画或写完第一页。"
	else:
		var display := func(index: int):
			var item: Dictionary = entries[index]
			picture.visible = item.has("motif")
			words.text = item.get("text","")
			if picture.visible: picture.texture = art.texture(int(item.id),int(item.motif))
		picker.item_selected.connect(display)
		display.call(0)
	popup_centered()

func show_writing(hobbies, diary: bool) -> void:
	var novel: Dictionary = hobbies.book
	title = "埃尔的日记本" if diary else novel.get("title","埃尔的书")
	ok_button_text = "关闭"
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(450,320)
	add_child(column)
	var picker := OptionButton.new()
	column.add_child(picker)
	var words := RichTextLabel.new()
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(words)
	var entries: Array = hobbies.writing.duplicate() if diary else novel.get("chapters",[])
	if diary: entries.reverse()
	for index in entries.size():
		var item: Dictionary = entries[index]
		if diary:
			picker.add_item(("旧手稿归档" if item.kind=="write_book" else "日记")+" · 第%d天"%Calendar.day_at(item.seconds))
		else:
			picker.add_item("第%d章 · %s"%[index+1,item.heading.left(26)])
	if entries.is_empty():
		picker.hide()
		words.text = "埃尔还没有写日记。" if diary else "埃尔还没有开始写他的书。"
	else:
		var display := func(index: int):
			words.text = entries[index].text
			words.scroll_to_line(0)
		picker.item_selected.connect(display)
		display.call(0)
	popup_centered()
