extends SceneTree
const Chosen = preload("res://chosen_memories.gd")
const Journal = preload("res://life_journal.gd")
const Chat = preload("res://chat_panel.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var j = Journal.new()
	j.start(0)
	var m = Chosen.new()
	var samples := [["pet.rabbit.001","德雷克身边","pet_done",10],["neighbor.mia.001","米娅身边","greet_done",20],["object.car.001","小车停靠点","drive_done",30],["place.tree_shade","树荫","rest",40]]
	for s in samples:
		j.record(s[0],s[1],s[2],s[3])
		check(m.add(j.records.back(),j,100)=="ok","Real sample can be collected")
	var before: Dictionary = m.snapshot()
	var pet: String = m.recall("你收藏过哪些关于德雷克的回忆？")
	check(pet.contains("德雷克") and not pet.contains("米娅") and not pet.contains("兜风"),"Named rabbit returns only relevant items")
	check(m.recall("收藏的小兔子回忆").contains("德雷克"),"Rabbit alias matches")
	check(m.recall("收藏的米娅回忆").contains("米娅"),"Mia name matches")
	check(m.recall("收藏的兜风经历").contains("兜风"),"Activity alias matches")
	check(m.recall("收藏的树下休息").contains("树荫"),"Location and activity intersect")
	check(m.recall("收藏的桥回忆").contains("没有找到"),"Unknown topic never returns unrelated facts")
	check(m.recall("收藏的米娅和德雷克的回忆").contains("没有找到"),"Combined subjects do not invent a shared event")
	check(m.recall("有哪些收藏的回忆").contains("显示最近收藏的 3 组"),"General recall is capped and says it is partial")
	check(Chat.simulated_reply("收藏的米娅回忆",{"chosen_memories":m.recall("收藏的米娅回忆")}).contains("米娅"),"Collection query routes before neighbor status")
	check(m.snapshot()==before,"Retrieval does not alter remembered events")
	print("CHOSEN_RECALL_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
