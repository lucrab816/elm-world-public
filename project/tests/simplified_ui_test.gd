extends "res://tests/self_arrangement_test.gd"
func settle() -> void:
	for i in range(10): await process_frame
func text_buttons(node: Node) -> Array:
	var result: Array = []
	if node is Button: result.append(node.text)
	for child in node.get_children(): result.append_array(text_buttons(child))
	return result
func run() -> void:
	var scene = fixture()
	scene._set_sidebar_collapsed(false,false)
	await settle()
	var texts := text_buttons(scene.ui_heading)
	for removed in ["请埃尔开车兜风","陪德雷克待一会儿","告诉埃尔一件事","翻翻自主安排"]:
		check(removed not in texts,"Obsolete sidebar entry removed: "+removed)
	check("和埃尔聊聊" in texts and "生活日记" in texts,"Two clear primary entrances remain")
	check(not scene.ui_details.visible and not scene.low_frequency_toggle.is_visible_in_tree() and not scene.self_arrangement_button.is_visible_in_tree(),"Advanced controls start folded, with no hidden model trigger")
	var before: Dictionary = scene.self_arrangement.snapshot()
	var actor: Dictionary = scene.resident.snapshot()
	for resolution in [Vector2i(1024,768),Vector2i(800,600)]:
		root.size = resolution
		for index in range(3):
			scene.ui_layout.set_preference(index)
			await settle()
			check(scene.ui_heading.size.y<root.get_visible_rect().size.y*.8,"Compact sidebar does not fill screen at "+str(resolution)+" preset "+str(index))
			check(scene.ui_heading.get_global_rect().end.y<scene.ui_footer.position.y,"Compact sidebar stays above footer")
			scene.ui_details_toggle.set_pressed(true)
			await settle()
			check(scene.ui_details.visible and scene.low_frequency_toggle.is_visible_in_tree(),"Settings remain reachable when explicitly expanded")
			scene.ui_details_toggle.set_pressed(false)
			await settle()
	scene.chat_panel.open_chat()
	await settle()
	check(not scene.chat_panel.memory_button.disabled,"Remembered facts are reachable inside chat details")
	scene.chat_panel.entry.text = "保留的草稿"
	scene.chat_panel._append("你","已有聊天")
	var prior: Array = scene.chat_panel.transcript.duplicate(true)
	scene.chat_panel.memory_button.pressed.emit()
	check(scene.memory_panel.visible and not scene.chat_panel.visible,"Chat opens explicit saved-fact management without competing sidebar entrance")
	check(scene.memory_panel.back_button.text=="返回聊天","Saved-fact screen returns to conversation")
	scene.memory_panel.back_button.pressed.emit()
	check(scene.chat_panel.visible and not scene.memory_panel.visible and scene.chat_panel.entry.text=="保留的草稿" and scene.chat_panel.transcript==prior,"Returning retains chat and draft without sending")
	scene.chat_panel.pending = true
	scene.chat_panel._update_send()
	check(scene.chat_panel.memory_button.disabled,"Cannot leave an active model request through memory button")
	scene._open_chat_memory()
	check(not scene.memory_panel.visible,"Busy guard protects direct callback too")
	scene.chat_panel.pending = false
	scene.chat_panel.close_chat()
	scene.journal_panel.open_diary()
	scene.journal_panel.kind_picker.select(9)
	scene.journal_panel.refresh()
	check(scene.journal_panel.arrangement_picker.visible and scene.journal_panel.content.text.contains("还没有保留"),"Autonomous arrangements remain inside single diary entrance")
	check(scene.self_arrangement.snapshot()==before and scene.resident.snapshot()==actor and scene.self_arrangement.transport.starts==0,"Navigation never changes resident behavior, memory or request count")
	print("SIMPLIFIED_UI_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
