extends SceneTree

const Mailbox = preload("res://mailbox.gd")
const MailboxPanel = preload("res://mailbox_panel.gd")
const ORIGINAL := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
var simulation_seconds := 60.0

func _initialize() -> void:
	call_deferred("_run")

func _save_now() -> void:
	pass

func _run() -> void:
	var box := Mailbox.new()
	box.directory = "/private/tmp/cozy-mailbox-thread-%d/inbox"%OS.get_process_id()
	box.restore([{"id":ORIGINAL,"sender":"玩家","body":"旧信","reply":"以前的回信","read":true,"posted_day":"2000-01-01","reply_day":"2000-01-01"}])
	assert(not box.post("Grok","身份不同",ORIGINAL).is_empty())
	assert(box.post("玩家","我想接着聊",ORIGINAL).is_empty())
	assert(not box.post("玩家","重复",ORIGINAL).is_empty())
	box.advance(self)
	assert(box.thread(ORIGINAL).size()==2)
	assert(box.conversations("").size()==1)
	var turn: Dictionary = box.thread(ORIGINAL).back()
	assert(turn.thread_id==ORIGINAL and not turn.read)
	turn.read = true
	var pending := box.pending()
	assert(pending.previous_turns[0].reply=="以前的回信")
	assert(box.prepare_reply(turn.id,"新的回信","",1))
	assert(turn.reply.is_empty() and turn.has("draft"))
	box._post_reply(turn)
	var restored := Mailbox.new()
	restored.directory = box.directory
	restored.restore(JSON.parse_string(JSON.stringify(box.letters)))
	assert(Mailbox.valid(restored.letters) and restored.thread(ORIGINAL).size()==2)
	var panel := MailboxPanel.new()
	root.add_child(panel)
	var image := Image.create_empty(16,16,false,Image.FORMAT_RGB8)
	image.fill(Color.CORAL)
	var original := image.save_jpg_to_buffer()
	var item := {"id":1,"title":"测试照片","jpeg":Marshalls.raw_to_base64(original)}
	panel.open_inbox(restored,func(): pass,func(): pass,func(_id): return item)
	panel._open_conversation(0)
	assert("新的回信" in panel.detail.get_parsed_text())
	assert(panel.save_attachment.visible and not panel.attachment_menu.visible)
	var destination := box.directory.get_base_dir().path_join("saved.jpg")
	assert(MailboxPanel._save_jpeg(destination,original)==OK)
	assert(FileAccess.get_file_as_bytes(destination)==original)
	assert(MailboxPanel._save_jpeg(destination.path_join("cannot-write.jpg"),original)!=OK)
	panel.reply_button.pressed.emit()
	assert(panel.composer.visible and panel.reply_to==ORIGINAL)
	panel.back.pressed.emit()
	assert(panel.detail.visible and not panel.composer.visible)
	assert(restored.new_reply_count()==0)
	print("MAILBOX_THREAD_TEST_OK")
	quit()
