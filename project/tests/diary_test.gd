extends SceneTree
const Journal = preload("res://life_journal.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1200,800)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var j = scene.journal
	j.start(0)
	j.record("home","家门口","eat",10)
	j.record("home","家门口","meal_done",40)
	j.record("car","薄荷小车","drive",45)
	j.record("car","薄荷小车","drive_done",100)
	j.record("tree","树荫","rest",200)
	j.record("tree","树荫","rest",400)
	j.record("home","家门口","observe",7300)
	scene.simulation_seconds = 7400
	var before: Dictionary = j.snapshot()
	check(j.entries().size()==6 and j.entries()[0].day==2,"Diary includes all retained groups newest first")
	check(j.entries(1,"meal").size()==2,"Meals distinguish start and completion")
	check(j.entries(1,"car").size()==2,"Driving distinguishes start and completion")
	check(j.entries(2,"rest").is_empty(),"Day filter never borrows a different day's facts")
	check(j.entries(1,"rest")[0].count==2,"Merged counts remain actual counts")
	check(j.entries(0,"unsupported").is_empty(),"Unknown filter returns no invented facts")
	var copy: Array = j.entries()
	copy[0].location_name = "Changed"
	check(j.snapshot()==before,"Reading or changing query output never changes memory")
	var diary = scene.journal_panel
	diary.open_diary()
	await process_frame
	await process_frame
	await process_frame
	check(diary.visible and diary.selected_day==2,"Opening diary defaults to today")
	check(diary.content.text.contains("看看周围") and not diary.content.text.contains("开始吃饭"),"Today view shows only today's facts")
	diary.selected_day = 1
	diary.kind_picker.select(3)
	diary.refresh()
	check(diary.content.text.contains("开始吃饭") and diary.content.text.contains("吃完饭") and not diary.content.text.contains("开小车"),"Actual panel applies both day and meal filter")
	diary.kind_picker.select(4)
	diary.refresh()
	check(diary.content.text.contains("开小车兜风") and diary.content.text.contains("结束兜风"),"Actual panel shows car start and end")
	diary.selected_day = 2
	diary.refresh()
	check(diary.content.text.contains("还没有符合"),"Empty filtered day is explicit")
	diary.selected_day = 0
	diary.kind_picker.select(0)
	diary.refresh()
	check(diary.content.text.contains("08:40—09:20") and diary.content.text.contains("共2次"),"Repeated actions show first/latest times and count")
	check(j.snapshot()==before,"Opening and filtering never writes or prunes records")
	j.record("car","薄荷小车","drive",7400)
	diary.refresh()
	check(diary.content.text.begins_with("第2天") and diary.count_label.text.contains("7 组"),"New real callbacks appear without reopening")
	check(diary.panel.position.x>=0 and diary.panel.position.y>=0 and diary.panel.size.y<=root.size.y,"Diary fits actual viewport")
	if DisplayServer.get_name()!="headless":
		await create_timer(.4).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/step-3.3.2-diary.png"))
	diary.close_diary()
	check(not diary.visible,"Returning to yard closes diary")
	print("DIARY_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
