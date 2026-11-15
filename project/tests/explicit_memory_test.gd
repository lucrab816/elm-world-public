extends SceneTree
const Memory = preload("res://explicit_memory.gd")
const Store = preload("res://save_store.gd")
const Chat = preload("res://chat_panel.gd")
class FailedStore extends RefCounted:
	func save_state(_state: Dictionary) -> bool:
		return false
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
	var memory = Memory.new()
	check(memory.records.is_empty() and memory.recall("我的名字").contains("没有找到"),"Empty memory never invents identity")
	check(memory.change("add",0,"我的称呼","你可以叫我小花。",10)=="ok","Explicitly submitted fact can be recorded")
	check(memory.records[0].source=="user_explicit" and memory.records[0].created_seconds==10,"Fact records source and real creation time")
	check(memory.recall("你记得我的名字吗").contains("小花"),"Name/label query retrieves saved fact")
	check(not memory.recall("我在哪里上学").contains("小花") and memory.recall("我在哪里上学").contains("没有找到"),"Unmatched question does not reuse unrelated facts")
	check(memory.change("add",0," 我的称呼 ","另一个内容",11)!="ok" and memory.records.size()==1,"Duplicate subject cannot silently replace a fact")
	var before: Dictionary = memory.snapshot()
	check(memory.change("add",0,"","内容",11)!="ok" and memory.snapshot()==before,"Empty inputs cannot alter memory")
	check(memory.change("add",0,"过长","x".repeat(161),11)!="ok","Oversize text rejected")
	check(memory.change("add",0,"多行","一行\n二行",11)!="ok","Multiline card rejected without truncation")
	check(memory.change("edit",1,"我的称呼","以后叫我小树。",20)=="ok" and not memory.recall("我的名字").contains("小花"),"Correction replaces recalled old content")
	check(memory.records[0].created_seconds==10 and memory.records[0].updated_seconds==20,"Correction preserves origin and updates edit time")
	var restored = Memory.new()
	var disk: Dictionary = JSON.parse_string(JSON.stringify(memory.snapshot()))
	check(restored.restore(disk,20) and restored.recall("我的名字").contains("小树"),"JSON restore recalls corrected record")
	var bad: Dictionary = disk.duplicate(true)
	bad.records[0].source = "model_output"
	check(not restored.restore(bad,20),"Non-user memory provenance rejected")
	bad = disk.duplicate(true)
	bad.records[0].updated_seconds = 99
	check(not restored.restore(bad,20),"Future fact rejected")
	bad = disk.duplicate(true)
	bad.records.append(bad.records[0].duplicate(true))
	check(not Memory.valid_snapshot(bad,20),"Duplicate ids rejected")
	check(restored.change("forget",1,"","",21)=="ok" and not restored.recall("我的名字").contains("小树"),"Forgotten fact is removed from recall")
	check(restored.change("add",0,"新事实","独立内容",22)=="ok" and restored.records[0].id==2,"Deletion never recycles stable ids")
	var full = Memory.new()
	for i in range(24):
		full.change("add",0,"主题%d"%i,"内容%d"%i,30+i)
	before = full.snapshot()
	check(full.change("add",0,"第25条","内容",60)!="ok" and full.snapshot()==before,"Capacity refuses new fact without evicting old ones")
	check(full.recall("你记得什么").split("\n").size()==3,"Chat receives at most three cards")
	check(Chat.simulated_reply("请记住我的名字",{"explicit_facts":"不可自动存入"}).contains("不会自动保存"),"Ordinary chat cannot write a fact")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.saving_enabled = true
	scene.journal_enabled = true
	scene.journal.start(0)
	scene.simulation_seconds = 100
	scene.store = Store.new("/tmp/cozy-explicit-"+str(OS.get_process_id()))
	scene.state_template = {"world_id":"explicit-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{"furniture":{"keep":true}},"memories":[{"reserved":"keep"}]}
	var panel = scene.memory_panel
	panel.open_memory()
	for i in range(4):
		await process_frame
	check(panel.visible and panel.panel.position.y>=0 and panel.panel.size.y<=root.size.y,"Memory form fits actual initial viewport")
	panel.topic.text = "我的称呼"
	panel.body.text = "你可以叫我小花。"
	panel.save_record()
	check(panel.status.text.contains("已保存") and panel.ids.size()==1,"Actual UI saves a fact and selects it")
	var loaded: Dictionary = scene.store.load_state()
	check(loaded.status=="ok" and loaded.state.world_state.explicit_memory.records[0].text.contains("小花"),"Fact is immediately durable on disk")
	check(loaded.state.memories==[{"reserved":"keep"}] and loaded.state.world_state.furniture.keep,"Saving fact preserves reserved memory and world fields")
	var recalled: Dictionary = scene.chat_panel.context_for("你记得我的名字吗")
	check(Chat.simulated_reply("你记得我的名字吗",recalled).contains("小花"),"Production chat path retrieves explicit memory")
	var restart = load("res://main.tscn").instantiate()
	root.add_child(restart)
	restart.set_process(false)
	for child in restart.get_children():
		if child is CanvasLayer:
			child.hide()
	check(restart.explicit_memory.restore(loaded.state.world_state.explicit_memory,loaded.state.simulation_seconds) and restart.chat_panel.context_for("我的名字").explicit_facts.contains("小花"),"Fresh world/chat instance recalls disk fact after restart")
	before = scene.explicit_memory.snapshot()
	var good_store = scene.store
	scene.store = FailedStore.new()
	panel.body.text = "保存失败的新内容"
	panel.save_record()
	check(panel.status.text.contains("没有保存成功") and panel.body.text=="保存失败的新内容" and scene.explicit_memory.snapshot()==before,"Save failure rolls memory back and preserves input draft")
	panel.forget_record()
	check(scene.explicit_memory.snapshot()==before and panel.status.text.contains("没有保存成功"),"Failed forget preserves original fact")
	scene.store = good_store
	scene.chat_panel._append("埃尔（本地模拟）","旧回答：小花")
	panel.body.text = "以后叫我小树。"
	scene.simulation_seconds = 120
	panel.save_record()
	loaded = scene.store.load_state()
	check(loaded.state.world_state.explicit_memory.records[0].text.contains("小树") and not scene.chat_panel.context_for("我的名字").explicit_facts.contains("小花"),"Saved UI correction changes disk and next chat context")
	check(scene.chat_panel.transcript.is_empty() and scene.chat_panel.history.text.contains("清空"),"Correction removes stale transient replies before next request")
	bad = loaded.state.duplicate(true)
	bad.world_state.explicit_memory.records[0].text = ""
	check(not Store.valid_state(bad),"Corrupt fact invalidates save instead of silently losing memory")
	if DisplayServer.get_name()!="headless":
		await create_timer(.4).timeout
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/step-3.3.3-memory.png"))
	scene.chat_panel._append("埃尔（本地模拟）","旧回答：小树")
	panel.forget_record()
	check(scene.chat_panel.transcript.is_empty(),"Forget excludes old recalled text from recent chat as well")
	loaded = scene.store.load_state()
	check(loaded.state.world_state.explicit_memory.records.is_empty() and not scene.chat_panel.context_for("我的名字").explicit_facts.contains("小树"),"Actual forget saves removal and excludes future context")
	scene.fatal_save_error = true
	check(not scene._change_explicit_memory("add",0,"新事实","内容").ok,"Protected save forbids memory mutation")
	panel.close_memory()
	check(not panel.visible,"Close returns to yard")
	scene.saving_enabled = false
	print("EXPLICIT_MEMORY_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
