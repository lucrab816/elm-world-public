extends SceneTree
const Keepsakes = preload("res://keepsakes.gd")
const Journal = preload("res://life_journal.gd")
const Store = preload("res://save_store.gd")
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
	var m = Keepsakes.new()
	m.enabled_seconds = 100
	check(m.summary().contains("不会补写"),"Empty archive does not invent earlier events")
	m.record("drive_done",99)
	m.record("pet_started",101)
	m.record("greet_cancelled",102)
	check(m.records.is_empty(),"Old, incomplete and cancelled events are excluded")
	m.record("drive_done",110)
	m.record("pet_done",120)
	m.record("greet_done",130)
	m.record("pet_done",140)
	check(m.records.size()==3 and m.records.pet_done==120,"One completed real event retained per kind")
	var j = Journal.new()
	j.start(0)
	for day in range(160): j.record("place","小院","observe",day*Journal.DAY_SECONDS)
	check(j.records.size()==128 and m.records.drive_done==110,"Journal rotation does not evict keepsakes")
	var saved: Dictionary = m.snapshot()
	check(Keepsakes.valid_snapshot(saved,140),"Snapshot validates")
	var restored = Keepsakes.new()
	restored.restore(saved)
	check(restored.snapshot()==saved and Chat.simulated_reply("你珍藏了哪些回忆",{"keepsakes":restored.summary()}).contains("德雷克"),"Restore and local recall use the same records")
	var bad: Dictionary = saved.duplicate(true)
	bad.records.pet_done = 150
	check(not Keepsakes.valid_snapshot(bad,140),"Future events rejected")
	bad = saved.duplicate(true)
	bad.records.unknown = 120
	check(not Keepsakes.valid_snapshot(bad,140),"Unknown event rejected")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.journal_enabled = true
	scene.journal.start(0)
	scene.event_seconds = 1
	scene._remember_event("object.car.001","drive_done",1)
	check(scene.keepsakes.records.has("drive_done"),"Production completed-driving callback creates a keepsake")
	scene.keepsakes.records.clear()
	scene._remember_event("object.car.001","drive",2)
	check(scene.keepsakes.records.is_empty(),"Starting a ride is not completion")
	print("KEEPSAKES_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
