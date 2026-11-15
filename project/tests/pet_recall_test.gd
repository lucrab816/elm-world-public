extends SceneTree
const Recall = preload("res://pet_recall.gd")
const Journal = preload("res://life_journal.gd")
const Companion = preload("res://pet_companion.gd")
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
	var journal = Journal.new()
	journal.start(0)
	var session = Companion.new()
	var context: Dictionary = Recall.context(journal,session,20,"德雷克")
	check(Chat.simulated_reply("最近陪过德雷克吗",context).contains("没找到"),"Empty history does not fabricate companionship")
	check(context.pet_memory_recent.contains("不代表以前从未"),"Missing bounded history does not assert lifetime absence")
	check(Chat.simulated_reply("昨天摸过兔子吗",context).contains("第1天"),"World day one has no yesterday")
	check(Recall.scope("你今天和德雷克做了什么")=="today","Natural today question routes to companionship")
	check(Recall.scope("上次什么时候摸过德雷克")=="recent","Last-time question uses retained recent history")
	check(Recall.scope("昨天有没有陪过兔子")=="yesterday","Yesterday has an explicit world-day scope")
	check(Recall.scope("德雷克现在在做什么").is_empty(),"Current pet status stays separate from history")
	check(Recall.scope("今天去摸摸德雷克")=="unsupported","Invitation is not silently treated as completed history")
	check(Chat.simulated_reply("昨天给德雷克喂了什么",context).contains("不能据此确认"),"Unimplemented feeding has no fabricated answer")
	check(Chat.simulated_reply("德雷克喜欢你吗",context).contains("不能据此确认"),"Activity facts do not imply affection")
	check(Chat.simulated_reply("明天陪德雷克吗",context).contains("只能回顾"),"Future plans are not fabricated from history")
	journal.record(Recall.PET_ID,"德雷克身边","pet_started",100)
	session.phase = "petting"
	session.latest = {"id":1,"phase":"petting","invited_seconds":98,"started_seconds":100}
	context = Recall.context(journal,session,102,"德雷克")
	check(context.pet_memory_recent.contains("尚未完成") and context.pet_memory_recent.contains("没找到"),"Active start is distinguished from a completion")
	journal.record(Recall.PET_ID,"德雷克身边","pet_cancelled",103)
	session.phase = "idle"
	session.latest.phase = "cancelled"
	session.latest.finished_seconds = 103
	context = Recall.context(journal,session,110,"德雷克")
	check(context.pet_memory_recent.contains("中途停下") and context.pet_memory_recent.contains("没有完成"),"Interrupted touch is not reported as success")
	session.latest = {"id":2,"phase":"cancelled","invited_seconds":111,"finished_seconds":115}
	check(Recall.context(journal,session,120,"德雷克").pet_memory_recent.contains("没有开始"),"Failed approach is distinguished from an interrupted touch")
	journal.record(Recall.PET_ID,"德雷克身边","pet_started",200)
	journal.record(Recall.PET_ID,"德雷克身边","pet_done",206)
	session.latest = {"id":3,"phase":"completed","invited_seconds":198,"started_seconds":200,"finished_seconds":206}
	context = Recall.context(journal,session,210,"德雷克")
	check(context.pet_memory_recent.contains("轻轻摸了摸") and context.pet_memory_recent.contains("1次"),"Journal and shared completion are not double-counted")
	journal.record(Recall.PET_ID,"德雷克身边","pet_done",400)
	context = Recall.context(journal,session,500,"德雷克")
	check(context.pet_memory_recent.contains("2次") and context.pet_memory_recent.contains(Recall.stamp(400)),"Grouped event count and last timestamp remain factual")
	context = Recall.context(journal,session,7300,"德雷克")
	check(context.pet_memory_today.contains("没找到") and not context.pet_memory_today.contains("轻轻摸了摸"),"Yesterday's completion is not moved into today")
	check(context.pet_memory_yesterday.contains("2次"),"Yesterday's query retains its correct grouped count")
	journal.record(Recall.PET_ID,"德雷克身边","pet_started",7400)
	journal.record(Recall.PET_ID,"德雷克身边","pet_done",7406)
	session.latest = {"id":4,"phase":"completed","invited_seconds":7398,"started_seconds":7400,"finished_seconds":7406}
	context = Recall.context(journal,session,7500,"德雷克")
	check(context.pet_memory_today.contains("1次") and context.pet_memory_yesterday.contains("2次") and context.pet_memory_recent.contains("3次"),"Today, yesterday and recent scopes do not mix totals")
	session.requested = true
	check(Recall.context(journal,session,7500,"德雷克").pet_memory_today.contains("邀请本身不算完成"),"Pending invitation is explicitly not a new completed event")
	session.requested = false
	session.latest = {"id":5,"phase":"completed","invited_seconds":7598,"started_seconds":7600,"finished_seconds":7606}
	check(Recall.context(journal,session,7700,"德雷克").pet_memory_recent.contains(Recall.stamp(7606)),"Latest shared completion remains usable if journal lacks the new event")
	check(Recall.context(null,session,7700,"德雷克").pet_memory_recent.contains(Recall.stamp(7606)),"Latest real interaction is a bounded fallback without the journal")
	var journal_before: Dictionary = journal.snapshot()
	var session_before: Dictionary = session.snapshot()
	for i in range(100): Recall.context(journal,session,7700,"德雷克")
	check(journal.snapshot()==journal_before and session.snapshot()==session_before,"Repeated recall is strictly read-only")
	var restored = Journal.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(journal_before)),7700),"Existing persisted journal can be restored without new schema")
	var restored_session = Companion.new()
	restored_session.restore(JSON.parse_string(JSON.stringify(session_before)))
	check(Recall.context(restored,restored_session,7700,"德雷克")==Recall.context(journal,session,7700,"德雷克"),"Recall survives JSON save and fresh component restore")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.journal = journal
	scene.journal_enabled = true
	scene.pet_companion = session
	scene.rabbit.adopt(7700)
	scene.rabbit_enabled = true
	scene.simulation_seconds = 7700
	scene.needs = preload("res://basic_life.gd").new()
	scene.needs.ensure_supply(7700)
	scene.simulation_seconds = 7000
	scene._update_needs_ui()
	check(scene.needs_status.text.begins_with("第1天 07:20"),"Pre-08:00 HUD and journal use the same running-day index")
	scene.simulation_seconds = 7700
	scene._update_needs_ui()
	check(scene.needs_status.text.begins_with("第2天") and scene.needs.last_supply_day==2,"HUD, supply and today recall share one world-day boundary")
	var state_before: Dictionary = scene.rabbit.snapshot()
	context = scene._chat_context()
	check(context.has("pet_memory_today") and context.has("pet_memory_recent"),"Production chat receives bounded pet evidence")
	check(Chat.simulated_reply("你最近和德雷克做了什么",context).contains(Recall.stamp(7606)),"Production local chat quotes latest factual companionship")
	check(Chat.simulated_reply("德雷克在做什么",context)==context.pet,"Ordinary pet-status reply remains intact")
	check(scene.rabbit.snapshot()==state_before and session.snapshot()==session_before,"Asking never moves or queues either actor")
	check(JSON.stringify(context).length()<4000,"Added evidence stays small enough for bounded chat context")
	# Eviction is honest: no unbounded archive or fabricated lost completion.
	var limited = Journal.new()
	limited.start(0)
	limited.record(Recall.PET_ID,"德雷克身边","pet_done",10)
	for i in range(128): limited.record("place."+str(i),"散步处","observe",20+i)
	var empty_session = Companion.new()
	check(limited.records.size()==128 and Recall.context(limited,empty_session,200,"德雷克").pet_memory_recent.contains("没找到"),"Evicted history stays unknown rather than being reconstructed")
	var only_start = Journal.new()
	only_start.start(0)
	only_start.record(Recall.PET_ID,"德雷克身边","pet_started",20)
	check(Recall.context(only_start,empty_session,30,"德雷克").pet_memory_recent.contains("不能把它当成已经完成"),"Journal-only old state does not turn start into success")
	# Exercise the actual local send path, not a real provider.
	scene.chat_panel.open_chat()
	scene.chat_panel.mode_picker.select(0)
	scene.chat_panel.entry.text = "今天陪过德雷克吗"
	scene.chat_panel.send_message()
	await create_timer(.45).timeout
	check(not scene.chat_panel.pending and scene.chat_panel.transcript.back().text.contains("轻轻摸了摸"),"Actual local-send flow returns companionship recall")
	check(scene.chat_panel.status.text.contains("没有调用模型"),"Recall is labelled as a local reply")
	scene.saving_enabled = false
	print("PET_RECALL_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
