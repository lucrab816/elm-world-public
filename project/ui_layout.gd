extends Node
# Interface preferences are separate from the resident's world and memories.
const FACTORS := [0.75,0.85,1.0]
var preference := 1
var sidebar_collapsed := true
var elapsed := 0.0
var persistent := true
func setup() -> void:
	persistent = not ("--save-test" in OS.get_cmdline_user_args() or "--resident-test" in OS.get_cmdline_user_args() or "--smoke-test" in OS.get_cmdline_user_args())
	if persistent:
		var config := ConfigFile.new()
		if config.load("user://interface.cfg")==OK and config.get_value("interface","version",1)==2:
			preference = clampi(int(config.get_value("interface","size",1)),0,FACTORS.size()-1)
		sidebar_collapsed = config.get_value("interface","sidebar_collapsed",true)==true
		apply_scale()
		_restore_geometry(config)
func _restore_geometry(config: ConfigFile) -> void:
	var window := get_window()
	var screen := DisplayServer.window_get_current_screen()
	var native := native_scale()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var saved_position = config.get_value("window","position",null)
	var saved_size = config.get_value("window","size",null)
	if saved_position is Vector2i and saved_size is Vector2i:
		var center: Vector2i = saved_position+saved_size/2
		for i in range(DisplayServer.get_screen_count()):
			var candidate := DisplayServer.screen_get_usable_rect(i)
			if candidate.has_point(center):
				usable = candidate
				break
	var target: Vector2i = saved_size if saved_size is Vector2i else Vector2i(Vector2(1024,700)*native)
	target.x = clampi(target.x,mini(640,usable.size.x),usable.size.x)
	target.y = clampi(target.y,mini(480,usable.size.y),usable.size.y)
	window.size = target
	var position: Vector2i = saved_position if saved_position is Vector2i else usable.position+(usable.size-target)/2
	position.x = clampi(position.x,usable.position.x,usable.end.x-target.x)
	position.y = clampi(position.y,usable.position.y,usable.end.y-target.y)
	window.position = position
func save_preferences() -> void:
	if not persistent: return
	var config := ConfigFile.new()
	config.set_value("interface","version",2)
	config.set_value("interface","size",preference)
	config.set_value("interface","sidebar_collapsed",sidebar_collapsed)
	config.set_value("window","size",get_window().size)
	config.set_value("window","position",get_window().position)
	config.save("user://interface.cfg")
func set_preference(index: int) -> void:
	preference = clampi(index,0,FACTORS.size()-1)
	apply_scale()
	save_preferences()
static func backing_scale(platform: String, current: float, maximum: float) -> float:
	# macOS reports window coordinates in the maximum backing scale, even on a 1x display.
	return maxf(1,maximum if platform=="macOS" else current)
func native_scale() -> float:
	return backing_scale(OS.get_name(),DisplayServer.screen_get_scale(DisplayServer.window_get_current_screen()),DisplayServer.screen_get_max_scale())
func apply_scale() -> void:
	var native := native_scale() if persistent else 1.0
	var factor: float = native*FACTORS[preference]
	if not is_equal_approx(get_window().content_scale_factor,factor):
		get_window().content_scale_factor = factor
func _process(delta: float) -> void:
	if not persistent: return
	elapsed += delta
	if elapsed>=1:
		elapsed = 0
		apply_scale()
static func readable(node: Node) -> void:
	if node is Control:
		node.mouse_force_pass_scroll_events = false
		var theme := Theme.new()
		theme.default_font_size = 18
		node.theme = theme
	_readable_children(node)
static func _readable_children(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit or node is ItemList:
		node.add_theme_font_size_override("font_size",maxi(16,node.get_theme_font_size("font_size")))
	if node is Button or node is LineEdit:
		node.custom_minimum_size.y = maxf(36,node.custom_minimum_size.y)
	for child in node.get_children(): _readable_children(child)
static func scrollable(panel: PanelContainer) -> ScrollContainer:
	var body: Control = panel.get_child(0)
	panel.remove_child(body)
	var scroll := ScrollContainer.new()
	scroll.mouse_force_pass_scroll_events = false
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return scroll
