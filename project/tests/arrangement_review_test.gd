extends "res://tests/self_arrangement_test.gd"
const Review = preload("res://arrangement_review.gd")
func settle() -> void:
	for i in range(8): await process_frame
func run() -> void:
	var scene = fixture()
	var panel = scene.journal_panel
	var before: Dictionary = scene.self_arrangement.snapshot()
	panel.open_arrangements()
	check(panel.kind_picker.selected==9 and panel.content.text.contains("还没有保留"),"Direct entrance opens clear empty state")
	check(scene.self_arrangement.snapshot()==before and scene.self_arrangement.transport.starts==0,"Opening empty review never arms a thought")
	check(not panel.day_picker.visible and panel.arrangement_picker.visible and not panel.memory_button.visible and not panel.event_picker.visible,"Arrangement has its own selector without unrelated collection controls")
	begin(scene)
	panel.refresh()
	check(panel.content.text.contains("重新选择"),"New records never silently replace an existing empty selection")
	panel.open_arrangements()
	check(panel.content.text.contains("正在等待想法") and panel.content.text.contains("还没有因此新增行动"),"Requesting thought is never presented as completed action")
	scene.self_arrangement.receive(scene,answer(scene,"visit_plant"))
	panel.refresh()
	check(panel.content.text.contains("尚未确认完成") and panel.content.text.contains("排队等待"),"Accepted queued action is shown as unfinished")
	for i in range(4000):
		scene._advance_simulation(.05)
		if scene.self_arrangement.phase()=="completed": break
	panel.refresh()
	check(panel.content.text.contains("执行器已确认实际完成") and panel.content.text.contains("当时的观察") and panel.content.text.contains("模型原话节选"),"Actual completion displays observation, expression and outcome separately")
	check(panel.content.text.contains("用户给出的一次机会") and panel.content.text.contains("看看盆栽"),"Legacy or manual provenance and real choice remain readable")
	var snapshot: Dictionary = scene.self_arrangement.snapshot()
	var records: Array = Review.records(snapshot)
	records[0].reply = "do not mutate source"
	check(scene.self_arrangement.snapshot()==snapshot,"Presentation records are detached copies")
	var record: Dictionary = snapshot.latest.duplicate(true)
	for phase in ["waiting","requesting","executing","completed","declined","failed","cancelled"]:
		record.phase = phase
		record.error = "sleep" if phase=="cancelled" else ("world_changed" if phase=="failed" else "")
		record.proposal = "none" if phase=="declined" else "visit_plant"
		var text: String = Review.detail(record)
		check(text.contains(Review.STATES[phase]),"Every phase has a truthful visible state: "+phase)
	record.phase = "cancelled"
	record.error = "restart"
	record.reply = ""
	check(Review.detail(record).contains("没有保留模型原话") and Review.detail(record).contains("重开时取消"),"Cleared quote and interruption never fabricate a reason")
	record.trigger = "low_frequency"
	check(Review.detail(record).contains("已开启的低频安排"),"Automatic provenance is not called a manual opportunity")
	var old: Dictionary = snapshot.latest.duplicate(true)
	old.id = 1
	var newer: Dictionary = old.duplicate(true)
	newer.id = 2
	newer.reply = "[url=https://invalid.test]这是数据[/url]"
	scene.self_arrangement.history = [old]
	scene.self_arrangement.latest = newer
	scene.self_arrangement.next_id = 3
	panel.open_arrangements()
	check(panel.selected_arrangement==2 and panel.arrangement_choices[0].id==2,"Open defaults to newest saved record")
	panel.arrangement_picker.select(1)
	panel.arrangement_picker.item_selected.emit(1)
	check(panel.selected_arrangement==1 and panel.content.text.begins_with("安排1"),"History selector actually opens an older record")
	panel.refresh()
	check(panel.selected_arrangement==1,"Live refresh keeps selected identity")
	scene.self_arrangement.history.clear()
	panel.refresh()
	check(panel.selected_arrangement==0 and panel.content.text.contains("原来选中的安排已移出"),"Expired bounded history does not silently show a different record")
	panel.arrangement_picker.select(0)
	panel.arrangement_picker.item_selected.emit(0)
	check(not panel.content.bbcode_enabled and panel.content.text.contains("[url="),"Model text is shown as plain data without executable links or markup")
	scene.self_arrangement.clear_statements()
	panel.refresh()
	check(not panel.content.text.contains("[url=") and panel.content.text.contains("没有保留模型原话"),"Privacy-cleared quotes disappear from open review")
	panel.kind_picker.select(0)
	panel.refresh()
	check(panel.day_picker.visible and not panel.arrangement_picker.visible and panel.memory_button.visible,"Returning to diary restores original controls")
	before = scene.self_arrangement.snapshot()
	var sequence: int = int(scene.state_template.save_sequence)
	var count: int = scene.self_arrangement.transport.starts
	for resolution in [Vector2i(1024,768),Vector2i(800,600),Vector2i(512,384)]:
		root.size = resolution
		for size_index in range(3):
			scene.ui_layout.set_preference(size_index)
			panel.open_arrangements()
			await settle()
			var bounds := root.get_visible_rect().size
			check(panel.panel.get_global_rect().end.x<=bounds.x+.1 and panel.panel.get_global_rect().end.y<=bounds.y+.1,"Review fits small screen at preset "+str(size_index)+" "+str(resolution))
			check(panel.content.size.y>=139,"Review text retains usable height with outer scrolling")
			var zoom_before: float = scene.zoom
			var wheel := InputEventMouseButton.new()
			wheel.position = panel.panel.get_global_rect().get_center()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			root.push_input(wheel,true)
			check(scene.zoom==zoom_before,"Scrolling review never zooms world")
	check(scene.self_arrangement.snapshot()==before and int(scene.state_template.save_sequence)==sequence and scene.self_arrangement.transport.starts==count,"Reading, resizing and scrolling never save, request or mutate memories")
	panel.close_diary()
	check(not panel.visible,"Return closes the review without stopping world")
	print("ARRANGEMENT_REVIEW_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
