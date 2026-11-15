extends SceneTree
const Journal = preload("res://life_journal.gd")
const Store = preload("res://save_store.gd")
const Chat = preload("res://chat_panel.gd")
const Life = preload("res://basic_life.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _run() -> void:
	var j = Journal.new()
	j.start(100)
	check(j.records.is_empty() and j.summary().contains("不"),"New journal does not invent past events")
	check(not j.record("bench","长椅","build",101) and not j.record("bench","长椅","rest",99),"Unsupported or pre-enable events rejected")
	check(j.record("bench","长椅","rest",101),"Actual rest may be recorded")
	check(not j.record("bench","长椅","rest",101) and j.records[0].count==1,"Same callback timestamp is idempotent")
	j.record("home","家门口","eat",102)
	j.record("home","家门口","meal_done",132)
	j.record("bench","长椅","rest",140)
	check(j.records.size()==3 and j.records.back().count==2 and j.records.back().first_seconds==101,"Same-day repeated activities merge and move to latest")
	check(j.summary(1).contains("开始吃饭") and j.summary(1).contains("吃完饭") and j.summary(1).contains("共2次"),"Starts/completions and merged count described accurately")
	j.record("bench","长椅","rest",7300)
	check(j.records.size()==4 and j.records.back().day==2,"Another day remains a separate event")
	check(j.summary(3).contains("尚无"),"Empty day does not borrow yesterday's facts")
	var snapshot = j.snapshot()
	var fresh = Journal.new()
	check(fresh.restore(snapshot,7300) and fresh.snapshot()==snapshot,"Journal survives serialization restore")
	var mutation = snapshot.duplicate(true)
	mutation.records[0].kind = "invented"
	check(not fresh.restore(mutation,7300) and fresh.snapshot()==snapshot,"Invalid restore cannot wipe valid memory")
	for field in ["count","day","first_seconds","last_seconds"]:
		mutation = snapshot.duplicate(true)
		mutation.records[0][field] = -1
		check(not Journal.valid_snapshot(mutation,7300),"Invalid number rejected: "+field)
	mutation = snapshot.duplicate(true)
	mutation.records.append(mutation.records[0].duplicate(true))
	check(not Journal.valid_snapshot(mutation,7300),"Duplicate or unsorted records rejected")
	check(not Journal.valid_snapshot(snapshot,7000),"Future memory rejected")
	var bounded = Journal.new()
	for day in range(160):
		bounded.record("bench","长椅","rest",day*7200.0+1)
	check(bounded.records.size()==128 and bounded.records.front().day==33,"Oldest groups trimmed at capacity")
	check(bounded.summary().split("\n").size()==5,"Chat context contains at most five groups")
	check(not Chat.simulated_reply("记住我的名字",{"memory_today":"x"}).contains("x"),"Dialogue is not stored as event memory")
	var root_world = load("res://main.tscn").instantiate()
	root.add_child(root_world)
	root_world.set_process(false)
	root_world.store = Store.new("/tmp/cozy-journal-"+str(OS.get_process_id()))
	root_world.state_template = {"world_id":"journal-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"text":"keep reserved data"}]}
	root_world.saving_enabled = true
	root_world.journal_enabled = true
	root_world.journal.start(0)
	root_world.needs = Life.new()
	root_world.needs.ensure_supply(0)
	root_world.resident.needs = root_world.needs
	root_world.needs.satiety = 54
	for i in range(5000):
		root_world._advance_simulation(.05)
	var memory = root_world.journal.snapshot()
	check(not memory.records.is_empty() and Journal.valid_snapshot(memory,root_world.simulation_seconds),"Real simulation callbacks create valid timed events")
	var kinds := []
	for event in memory.records:
		kinds.append(event.kind)
	check(kinds.has("rest") and kinds.has("observe") and kinds.has("eat") and kinds.has("meal_done"),"Walking/exploration, resting and actual completed meal recorded")
	check(root_world._save_now(),"Journal included in atomic world save")
	var loaded = root_world.store.load_state()
	check(loaded.state.world_state.life_journal==JSON.parse_string(JSON.stringify(memory)) and loaded.state.memories==[{"text":"keep reserved data"}],"Disk round trip preserves new journal and old reserved memory")
	var another = Journal.new()
	check(another.restore(loaded.state.world_state.life_journal,float(loaded.state.simulation_seconds)),"Fresh journal restores from disk")
	root_world.journal = another
	root_world.resident.restore(loaded.state.resident)
	check(JSON.parse_string(JSON.stringify(root_world.journal.snapshot()))==JSON.parse_string(JSON.stringify(memory)),"Restoring current actor does not replay arrival memory")
	var context = root_world._chat_context()
	check(Chat.simulated_reply("今天做了什么",context).contains(context.memory_today),"Today's local reply uses only today's saved events")
	check(Chat.simulated_reply("最近去了哪里",context).contains(context.memory_recent),"Recent reply uses bounded saved facts")
	var valid = loaded.state.duplicate(true)
	valid.world_state.life_journal.records[0].last_seconds = 1e11
	check(not Store.valid_state(valid),"Save validator rejects corrupt optional journal")
	# Old v2 envelope is still accepted, with its existing data unchanged.
	var old = loaded.state.duplicate(true)
	old.world_state.erase("life_journal")
	var payload = JSON.stringify(old)
	var file := FileAccess.open(root_world.store.directory.path_join("world.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version":2,"payload_json":payload,"sha256":payload.sha256_text()}))
	file.close()
	check(root_world.store.load_state().state==old,"Old v2 saves load without invented journal backfill")
	root_world.chat_panel.open_chat()
	for i in range(8):
		await process_frame
	check(root_world.chat_panel.events.text.contains("生活记忆") and root_world.chat_panel.entry.get_global_rect().end.y<800,"Chat shows saved life groups without hiding input")
	if DisplayServer.get_name()!="headless":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/step-3.3.1.png"))
	root_world.saving_enabled = false
	print("JOURNAL_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
