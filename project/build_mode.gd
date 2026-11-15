extends Node3D

const Surface = preload("res://yard_surface.gd")
const ASSETS := {
	"limestone":{"label":"疏纹石砖","category":"铺地","builder":Surface.make_editable_stone,"half_size":Vector2(.27,.20)},
	"stepping_stone":{"label":"鹅卵石踏石","category":"小径","builder":Surface.make_stepping_stone,"half_size":Vector2(.56,.43),"large_half_size":Vector2(.86,.65)},
}
const LIMIT := 200
const LOWER := Vector2(-35.7,-9.7)
const UPPER := Vector2(11.7,9.7)
const GRID := Vector2(.25,.25)
var world
var objects: Array = []
var selected: Node3D
var active := false
const HANDLE_RADIUS := 43.0
const HANDLE_HIT := 11.0
var originals: Dictionary = {}
var overlay: Node2D
var gesture := ""
var mouse_start := Vector2.ZERO
var gesture_pivot := Vector2.ZERO
var gesture_starts: Dictionary = {}
var gesture_angles: Dictionary = {}
var gesture_angle := 0.0
var gesture_moved := false
var repeated := false
var valid_position := false
var undo_steps: Array = []
var redo_steps: Array = []
var panel: PanelContainer
var library: PanelContainer
var catalog: VBoxContainer
var category: OptionButton
var search: LineEdit
var hint: Label
var delete_button: Button
var delete_count: Label
var restore_library := false
var catalog_images: Dictionary = {}

func setup(owner_world) -> void:
	world = owner_world
	name = "BuildMode"
	var rng := RandomNumberGenerator.new()
	rng.seed = 756
	var rows := [4,5,6,6,6,5,4]
	for row in rows.size():
		for column in rows[row]:
			var x: float = Surface.PATIO_CENTER.x+(column-(rows[row]-1)*.5)*.572+[.03,-.13,.08,-.09,.14,-.05,.08][row]
			var z := Surface.PATIO_CENTER.y+(row-3)*.423
			var point := Vector2(x+rng.randf_range(-.035,.035),z+rng.randf_range(-.026,.026))
			_place("limestone",point,0,rng.randi_range(0,999999))

	_add_front_path()

func _add_front_path() -> void:
	for i in 10:
		var point := Vector2(lerpf(-2.18,-.30,float(i)/9)+sin(i*1.8)*.25,1.68+i*.68)
		_place("stepping_stone",point,wrapf(i*.73,-PI,PI),i)

func setup_panel(layer: CanvasLayer) -> void:
	overlay = Node2D.new()
	layer.add_child(overlay)
	overlay.draw.connect(_draw_handles)
	delete_button = Button.new()
	layer.add_child(delete_button)
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.tooltip_text = "删除选中物件"
	delete_button.add_theme_stylebox_override("normal",world._style("334b3ef2"))
	delete_button.add_theme_stylebox_override("hover",world._style("795444"))
	delete_button.add_theme_stylebox_override("pressed",world._style("593b33"))
	var delete_contents := HBoxContainer.new()
	delete_button.add_child(delete_contents)
	delete_contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	delete_contents.alignment = BoxContainer.ALIGNMENT_CENTER
	delete_contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(20,24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func(): _draw_trash(icon))
	delete_contents.add_child(icon)
	delete_count = Label.new()
	delete_count.add_theme_color_override("font_color",Color("#fff1d7"))
	delete_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delete_contents.add_child(delete_count)
	delete_button.pressed.connect(_delete_held)
	delete_button.hide()
	panel = PanelContainer.new()
	layer.add_child(panel)
	panel.position.y = 12
	panel.add_theme_stylebox_override("panel",world._style("f8f5e9f6"))
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var row := HFlowContainer.new()
	rows.add_child(row)
	row.custom_minimum_size.x = 380
	_button(row,"资产库",func():
		library.visible = not library.visible
		_position_delete_button())
	_button(row,"撤销",func(): _history(undo_steps,redo_steps))
	_button(row,"重做",func(): _history(redo_steps,undo_steps))
	_button(row,"完成",toggle)
	hint = Label.new()
	hint.add_theme_color_override("font_color",Color("#405848"))
	rows.add_child(hint)
	library = PanelContainer.new()
	layer.add_child(library)
	library.position.y = 104
	library.custom_minimum_size = Vector2(208,245)
	library.add_theme_stylebox_override("panel",world._style("f8f5e9f6"))
	var filters := VBoxContainer.new()
	library.add_child(filters)
	search = LineEdit.new()
	search.placeholder_text = "搜索资产"
	filters.add_child(search)
	category = OptionButton.new()
	category.add_item("全部资产")
	for id in ASSETS:
		var label: String = ASSETS[id].category
		var exists := false
		for i in category.item_count:
			exists = exists or category.get_item_text(i)==label
		if not exists: category.add_item(label)
	filters.add_child(category)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filters.add_child(scroll)
	catalog = VBoxContainer.new()
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(catalog)
	search.text_changed.connect(func(_text): _refresh_catalog())
	category.item_selected.connect(func(_index): _refresh_catalog())
	_refresh_catalog()
	panel.resized.connect(layout_panels)
	library.resized.connect(layout_panels)
	panel.hide()
	library.hide()

func layout_panels() -> void:
	if not active: return
	var available := get_viewport().get_visible_rect().size
	var right := available.x-12
	panel.position.x = right-panel.size.x
	library.position = Vector2(right-library.size.x,panel.position.y+panel.size.y+8)
	_position_delete_button()

func covers(screen: Vector2) -> bool:
	return active and (panel.get_global_rect().has_point(screen) or (library.visible and library.get_global_rect().has_point(screen)) or (delete_button.visible and delete_button.get_global_rect().has_point(screen)))

func _refresh_catalog() -> void:
	for child in catalog.get_children():
		catalog.remove_child(child)
		child.queue_free()
	var filter := category.get_item_text(category.selected)
	for id in ASSETS:
		var entry: Dictionary = ASSETS[id]
		if filter!="全部资产" and entry.category!=filter: continue
		if not search.text.strip_edges().is_empty() and not entry.label.containsn(search.text.strip_edges()): continue
		var card := _button(catalog,entry.label,func(): _add_asset(id))
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size.y = 58
		card.tooltip_text = entry.category
		card.add_theme_constant_override("icon_max_width",72)
		card.add_theme_constant_override("h_separation",8)
		if not catalog_images.has(id):
			var texture := load("res://assets/build_catalog/"+id+".png") as Texture2D
			if texture!=null:
				catalog_images[id] = texture
		card.icon = catalog_images.get(id)
	if catalog.get_child_count()==0:
		var empty := Label.new()
		empty.text = "没有匹配的资产"
		catalog.add_child(empty)

func _button(row: Container, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	return button

func toggle() -> void:
	if not active and (not world.saving_enabled or world.fatal_save_error): return
	if active and not originals.is_empty() and valid_position: _drop()
	_cancel()
	active = not active
	panel.visible = active
	library.visible = active
	if active:
		world._reset_camera()
		world.focus = Vector3(1,.45,2.6)
		world.zoom = 13
		world._update_camera()
		_update_hint()
		layout_panels()
	else:
		_position_delete_button()
		world._manual_save()

func _update_hint() -> void:
	if not is_instance_valid(selected):
		hint.text = "点选物件 · ⌘ 点选多件"
	elif originals.is_empty():
		hint.text = "点击摆放 · Shift 连续铺设 · Esc 取消"
	else:
		hint.text = "%d 件 · 拖中心移动 · 拖外圈旋转 · 回车确认"%originals.size()
	refresh_handles()

func refresh_handles() -> void:
	if overlay==null: return
	overlay.queue_redraw()
	_position_delete_button()

func _draw_trash(icon: Control) -> void:
	var color := Color("#fff1d7")
	var origin := (icon.size-Vector2(20,24))*.5
	icon.draw_polyline(PackedVector2Array([origin+Vector2(5,9),origin+Vector2(6,19),origin+Vector2(14,19),origin+Vector2(15,9)]),color,1.5,true)
	icon.draw_line(origin+Vector2(3,7),origin+Vector2(17,7),color,1.5,true)
	icon.draw_polyline(PackedVector2Array([origin+Vector2(8,7),origin+Vector2(8,4),origin+Vector2(12,4),origin+Vector2(12,7)]),color,1.5,true)

func _position_delete_button() -> void:
	if delete_button==null: return
	if not active or originals.is_empty() or not is_instance_valid(selected):
		delete_button.hide()
		return
	var center := _screen_pivot()
	var bounds := get_viewport().get_visible_rect().grow(-6)
	if not bounds.has_point(center):
		delete_button.hide()
		return
	delete_count.text = "删除 %d 件"%originals.size() if originals.size()>1 else ""
	delete_count.visible = originals.size()>1
	var button_size := Vector2(96 if delete_count.visible else 36,34)
	var blocked: Array[Control] = [panel,library,world.ui_heading,world.ui_sidebar_toggle,world.ui_footer]
	for offset in [Vector2(57,-17),Vector2(-57-button_size.x,-17),Vector2(-button_size.x*.5,57),Vector2(-button_size.x*.5,-57-button_size.y)]:
		var candidate := Rect2(center+offset,button_size)
		if not bounds.encloses(candidate): continue
		if blocked.any(func(control): return control!=null and control.visible and candidate.intersects(control.get_global_rect())): continue
		delete_button.visible = true
		delete_button.position = candidate.position
		delete_button.size = button_size
		return
	delete_button.hide()

func _ground_pivot() -> Vector2:
	if originals.is_empty(): return Vector2(selected.position.x,selected.position.z)
	var center := Vector2.ZERO
	for object in originals:
		center += Vector2(object.position.x,object.position.z)
	return center/originals.size()

func _screen_pivot() -> Vector2:
	var center := _ground_pivot()
	return world.camera.unproject_position(Vector3(center.x,world._height(center.x,center.y)+.055,center.y))

func _draw_handles() -> void:
	if not active or not is_instance_valid(selected) or not selected.visible: return
	if originals.is_empty(): return
	var center := _screen_pivot()
	var color := Color("#f9e5a2") if valid_position else Color("#ef917b")
	overlay.draw_arc(center,HANDLE_RADIUS,0,TAU,48,Color("#28372bcc"),6,true)
	overlay.draw_arc(center,HANDLE_RADIUS,0,TAU,48,color,2,true)
	overlay.draw_circle(center,15,Color("#334b3e"),true,-1,true)
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		var tip: Vector2 = center+direction*10
		var tail: Vector2 = center+direction*5
		var side: Vector2 = direction.orthogonal()*3
		overlay.draw_line(center,tip,color,1.5,true)
		overlay.draw_polyline(PackedVector2Array([tail+side,tip,tail-side]),color,1.5,true)
	var angle := "%d°"%roundi(rad_to_deg(gesture_angle if originals.size()>1 else selected.rotation.y))
	var badge := Rect2(center+Vector2(18,-56),Vector2(49,23))
	overlay.draw_rect(badge,Color("#334b3e"))
	overlay.draw_string(ThemeDB.fallback_font,badge.position+Vector2(5,16),angle,HORIZONTAL_ALIGNMENT_CENTER,39,13,color)

func _place(id: String, point: Vector2, angle: float, seed_id: int) -> Node3D:
	var object: Node3D = ASSETS[id].builder.call(seed_id)
	add_child(object)
	object.set_meta("asset_id",id)
	object.set_meta("seed",seed_id)
	_move(object,point)
	object.rotation.y = angle
	objects.append(object)
	return object

func _move(object: Node3D, point: Vector2) -> void:
	object.position = Vector3(point.x,world._height(point.x,point.y),point.y)

func _select(object: Node3D) -> void:
	if is_instance_valid(selected): selected.get_node("Selection").hide()
	selected = object
	if is_instance_valid(selected): selected.get_node("Selection").show()

func _add_asset(id: String, continuous := false, angle := 0.0, seed_id := -1) -> void:
	_cancel()
	if objects.size()>=LIMIT: return
	repeated = continuous
	restore_library = library.visible
	library.hide()
	_select(_place(id,Vector2.ZERO,angle,seed_id if seed_id>=0 else randi_range(0,999999)))
	selected.hide()
	valid_position = false
	_update_hint()

func _rotate(direction: int) -> void:
	if not is_instance_valid(selected): return
	var angle := direction*PI/12
	if originals.is_empty():
		selected.rotation.y = wrapf(selected.rotation.y+angle,-PI,PI)
		return
	_begin_gesture("rotate",_screen_pivot()+Vector2(HANDLE_RADIUS,0))
	_apply_rotation(angle)
	gesture = ""

func _remove(object: Node3D) -> void:
	objects.erase(object)
	remove_child(object)
	object.queue_free()

func _clear_selection() -> void:
	for object in originals: object.get_node("Selection").hide()
	_select(null)
	originals.clear()
	gesture = ""
	gesture_angle = 0.0
	gesture_starts.clear()
	gesture_angles.clear()
	repeated = false
	if restore_library and active: library.show()
	restore_library = false
	_update_hint()

func _delete_held() -> void:
	if not is_instance_valid(selected): return
	if originals.is_empty():
		_cancel()
		return
	_remember()
	for object in originals.keys(): _remove(object)
	_clear_selection()

func _cancel() -> void:
	if is_instance_valid(selected) and originals.is_empty():
		_remove(selected)
		selected = null
	for object in originals:
		var entry: Array = originals[object]
		_move(object,Vector2(entry[1],entry[2]))
		object.rotation.y = entry[3]
	_clear_selection()

func _remember() -> void:
	undo_steps.append(snapshot())
	if undo_steps.size()>30: undo_steps.pop_front()
	redo_steps.clear()

func _history(from: Array, to: Array) -> void:
	_cancel()
	if not from.is_empty():
		to.append(snapshot())
		restore(from.pop_back())
	_update_hint()

func _half_size(object: Node3D) -> Vector2:
	var entry: Dictionary = ASSETS[object.get_meta("asset_id")]
	return entry.get("large_half_size",entry.half_size) if object.get_meta("seed")==9 else entry.half_size

func _preview(screen: Vector2, free: bool) -> void:
	var point := _ground(screen)
	if not free: point = point.snapped(GRID)
	var footprint := _half_size(selected)
	var edge := Rect2(LOWER+footprint,UPPER-LOWER-2*footprint)
	valid_position = edge.has_point(point)
	selected.visible = valid_position
	if valid_position: _move(selected,point)
	_update_hint()

func _drop() -> void:
	if not valid_position or not is_instance_valid(selected): return
	var id: String = selected.get_meta("asset_id")
	var angle := selected.rotation.y
	var seed_id: int = selected.get_meta("seed")
	var again := repeated and originals.is_empty()
	if originals.is_empty() or originals.keys().any(func(object): return _entry(object)!=originals[object]):
		_remember()
	_clear_selection()
	if again: _add_asset(id,true,angle,seed_id)

func _begin_gesture(kind: String, screen: Vector2) -> void:
	gesture = kind
	mouse_start = screen
	gesture_pivot = _ground_pivot()
	gesture_moved = false
	gesture_starts.clear()
	gesture_angles.clear()
	for object in originals:
		gesture_starts[object] = Vector2(object.position.x,object.position.z)
		gesture_angles[object] = object.rotation.y

func _positions_valid(positions: Dictionary) -> bool:
	for object in positions:
		if not Rect2(LOWER,UPPER-LOWER).has_point(positions[object]): return false
	return true

func _apply_rotation(angle: float) -> void:
	var positions := {}
	for object in gesture_starts:
		positions[object] = gesture_pivot+(gesture_starts[object]-gesture_pivot).rotated(-angle)
	if not _positions_valid(positions): return
	for object in positions:
		_move(object,positions[object])
		object.rotation.y = wrapf(gesture_angles[object]+angle,-PI,PI)
	gesture_angle = angle
	refresh_handles()

func _drag(screen: Vector2, free: bool) -> void:
	if not gesture_moved and mouse_start.distance_to(screen)<3: return
	gesture_moved = true
	if gesture=="rotate":
		var angle := -(_ground(mouse_start)-gesture_pivot).angle_to(_ground(screen)-gesture_pivot)
		_apply_rotation(angle if free else snappedf(angle,PI/12))
	else:
		var delta := _ground(screen)-_ground(mouse_start)
		if not free: delta = (gesture_pivot+delta).snapped(GRID)-gesture_pivot
		var positions := {}
		for object in gesture_starts: positions[object] = gesture_starts[object]+delta
		if _positions_valid(positions):
			for object in positions: _move(object,positions[object])
			refresh_handles()

func _ground(screen: Vector2) -> Vector2:
	var origin: Vector3 = world.camera.project_ray_origin(screen)
	var direction: Vector3 = world.camera.project_ray_normal(screen)
	var hit := origin
	for i in 4:
		hit = origin+direction*((world._height(hit.x,hit.z)-origin.y)/direction.y)
	return Vector2(hit.x,hit.z)

func _hit(screen: Vector2) -> Node3D:
	var hit := _ground(screen)
	var closest: Node3D
	var distance := INF
	for object in objects:
		var local: Vector3 = object.to_local(Vector3(hit.x,object.position.y,hit.y))
		var half := _half_size(object)
		if absf(local.x)>half.x or absf(local.z)>half.y: continue
		var score := local.length_squared()
		if score<distance:
			distance = score
			closest = object
	return closest

func _pick(object: Node3D, multiple: bool) -> void:
	if multiple and originals.has(object):
		originals.erase(object)
		object.get_node("Selection").hide()
		selected = originals.keys().back() if not originals.is_empty() else null
	else:
		originals[object] = _entry(object)
		selected = object
		object.get_node("Selection").show()
	valid_position = true
	_update_hint()

func input(event: InputEvent) -> bool:
	if not active: return false
	if event is InputEventMouse and covers(event.position) and gesture.is_empty(): return true
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.meta_pressed or event.ctrl_pressed) and event.keycode==KEY_Z:
			if event.shift_pressed: _history(redo_steps,undo_steps)
			else: _history(undo_steps,redo_steps)
			return true
		match event.keycode:
			KEY_ESCAPE:
				if is_instance_valid(selected): _cancel()
				else: toggle()
			KEY_ENTER,KEY_KP_ENTER: _drop()
			KEY_DELETE,KEY_BACKSPACE: _delete_held()
			KEY_Q,KEY_COMMA: _rotate(-1)
			KEY_E,KEY_PERIOD: _rotate(1)
			_: return false
		return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if not gesture.is_empty():
				if gesture_moved: _drag(event.position,event.alt_pressed)
				gesture = ""
			return true
		if is_instance_valid(selected) and originals.is_empty():
			repeated = event.shift_pressed or repeated
			_preview(event.position,event.alt_pressed)
			_drop()
			return true
		var object := _hit(event.position)
		if object!=null and event.shift_pressed:
			var id: String = object.get_meta("asset_id")
			var angle := object.rotation.y
			_add_asset(id,true,angle,object.get_meta("seed"))
			return true
		if object!=null and (event.meta_pressed or event.ctrl_pressed):
			_pick(object,true)
			return true
		if not originals.is_empty():
			var distance: float = event.position.distance_to(_screen_pivot())
			if absf(distance-HANDLE_RADIUS)<=HANDLE_HIT:
				_begin_gesture("rotate",event.position)
				return true
			if distance<=18 or originals.has(object):
				_begin_gesture("move",event.position)
				return true
			_drop()
		if object!=null:
			_pick(object,false)
			_begin_gesture("move",event.position)
		return true
	if event is InputEventMouseMotion and not event.button_mask & (MOUSE_BUTTON_MASK_RIGHT|MOUSE_BUTTON_MASK_MIDDLE):
		if not gesture.is_empty():
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT: _drag(event.position,event.alt_pressed)
			else: gesture = ""
			return true
		if is_instance_valid(selected) and originals.is_empty():
			_preview(event.position,event.alt_pressed)
			return true
		return bool(event.button_mask & MOUSE_BUTTON_MASK_LEFT)
	return false

func _entry(object: Node3D) -> Array:
	return [object.get_meta("asset_id"),object.position.x,object.position.z,object.rotation.y,object.get_meta("seed")]

func snapshot() -> Array:
	var layout := []
	for object in objects:
		if originals.has(object):
			layout.append(originals[object].duplicate())
		elif object!=selected:
			layout.append(_entry(object))
	return layout

func restore_saved(layout: Variant, has_front_path: bool) -> void:
	if layout is Array:
		restore(layout)
		if not has_front_path: _add_front_path()

func restore(layout: Variant) -> void:
	if not layout is Array or layout.size()>LIMIT+10: return
	for item in layout:
		if not item is Array or item.size()!=5 or not item[0] is String or not ASSETS.has(item[0]): return
		for i in range(1,5):
			if not (item[i] is int or item[i] is float) or not is_finite(item[i]): return
		if absf(item[1])>36 or absf(item[2])>10 or absf(item[3])>TAU or item[4]<0 or item[4]>999999: return
	for object in objects:
		remove_child(object)
		object.queue_free()
	objects.clear()
	for item in layout:
		_place(item[0],Vector2(item[1],item[2]),item[3],int(item[4]))
