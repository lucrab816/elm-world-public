extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Journal = preload("res://life_journal.gd")
const Chosen = preload("res://chosen_memories.gd")
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
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.saving_enabled = true
	scene.journal_enabled = true
	scene.journal.start(0)
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	scene.store = Store.new("/tmp/cozy-chosen-test-"+str(OS.get_process_id()))
	scene.state_template = {"world_id":"chosen-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"keep":true}]}
	scene.simulation_seconds = 100
	scene.journal.record("place.home_front","家门口","observe",10)
	scene.journal.record("place.home_front","家门口","observe",80)
	var event: Dictionary = scene.journal.entries()[0]
	var fake = event.duplicate(true)
	fake.count = 99
	check(not scene._change_chosen_memory("add",fake).ok,"Cannot add invented events")
	var diary = scene.journal_panel
	diary.open_diary()
	diary.refresh()
	diary.event_picker.select(0)
	scene.journal.record("object.car.001","小车","drive",90)
	diary.refresh()
	check(diary.choices[diary.event_picker.selected].location_id=="place.home_front","Selection stays on the same event when new events reorder the list")
	diary._change_memory()
	check(scene.chosen_memories.records.size()==1 and diary.memory_status.text.contains("已经收藏"),"Real diary choice is saved through UI")
	check(scene.chosen_memories.records[0].event.count==2,"Original grouped event details preserved")
	check(not scene._change_chosen_memory("add",event).ok,"Duplicate group rejected")
	var saved = scene.store.load_state()
	check(saved.status=="ok" and saved.state.memories==[{"keep":true}] and saved.state.world_state.chosen_memories.records.size()==1,"Saved world preserves previous memories and the chosen event")
	var restored = Chosen.new()
	restored.restore(saved.state.world_state.chosen_memories)
	for day in range(1,150): scene.journal.record("place.home_front","家门口","observe",day*Journal.DAY_SECONDS)
	check(scene.journal.records.size()==128 and restored.records[0].event.location_id==event.location_id and restored.records[0].event.count==2 and restored.records[0].event.first_seconds==10 and restored.records[0].event.last_seconds==80,"Chosen event survives journal rotation")
	check(Chat.simulated_reply("有哪些珍藏的回忆",{"chosen_memories":restored.summary()}).contains("家门口"),"Local recall includes the chosen facts")
	var bad: Dictionary = restored.snapshot()
	bad.records[0].event.count = 0
	check(not Chosen.valid_snapshot(bad,100),"Invalid event rejected")
	diary.kind_picker.select(8)
	diary.refresh()
	check(diary.content.text.contains("家门口") and diary.memory_button.text=="移出收藏","Chosen view has the saved event and remove action")
	scene.store.writes_blocked = true
	var before: Dictionary = scene.chosen_memories.snapshot()
	check(not scene._change_chosen_memory("remove",1).ok and scene.chosen_memories.snapshot()==before,"Failed save rolls removal back")
	scene.store.writes_blocked = false
	# The artificial journal rotation advanced event times; reset it to the real fixture time before saving.
	scene.journal.start(0)
	scene.journal.record("place.home_front","家门口","observe",80)
	diary._change_memory()
	check(scene.chosen_memories.records.is_empty() and scene.journal.records.size()==1,"Removing a favorite does not delete the diary")
	check(scene.store.load_state().state.world_state.chosen_memories.records.is_empty(),"Removal is durable")
	print("CHOSEN_MEMORIES_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
