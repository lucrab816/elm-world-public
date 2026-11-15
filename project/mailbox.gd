extends RefCounted

const LIMIT := 128
const IMAGE_LIMIT := 20000
const SENDERS := ["玩家","ChatGPT","Gemini","Grok"]
const BACKGROUND := "小院的助手"
const LOCATION := Vector2(.5,4.1)
const STAND := Vector2(.5,5)
var route := PackedVector2Array()
var reading_id := ""
const Books = preload("res://elm_books.gd")
const Hobbies = preload("res://elm_hobbies.gd")
const Interior = preload("res://elm_interior.gd")
const DESK_APPROACH := Vector3(2.72,.04,.70)
var phase := ""
var remaining := 0.0
var indoor_position := Vector3.ZERO
var indoor_index := 0
var paper: Node3D
var desk_sheet: Node3D
var pencil: Node3D
var envelope: Node3D
var writing_trip := false
const SEATED_PHASES := ["reading","file_letter","get_stationery","writing","seal_letter"]
var retry_at := 0.0
var letters: Array = []
var potato_seed_letter := ""
var potato_parcel := ""
var viewed_replies := ConfigFile.new()
var next_scan := 0.0
var directory := OS.get_user_data_dir().path_join("mailbox/inbox")

static func today() -> String:
	return Time.get_date_string_from_system()

static func sender_name(value: String) -> String:
	for label in SENDERS:
		if value.strip_edges().nocasecmp_to(label)==0: return label
	return value.strip_edges()

func used_today(sender: String, field: String) -> bool:
	var date := today()
	for letter in letters:
		if sender_name(letter.sender)==sender and letter.get(field,"")==date: return true
	return false

func another_letter_today(letter: Dictionary) -> bool:
	var date := today()
	var sender := sender_name(letter.sender)
	for other in letters:
		if other.id==letter.id or sender_name(other.sender)!=sender: continue
		if other.get("read_day","")==date or other.get("reply_day","")==date: return true
	return false

func awaiting_reply(sender: String) -> bool:
	for letter in letters:
		if sender_name(letter.sender)==sender and letter.get("read",false) and letter.reply.is_empty(): return true
	return false

func restore(entries: Array) -> void:
	letters = entries.duplicate(true)
	viewed_replies.load(viewed_replies_path())
	for letter in letters:
		if letter.has("posted_day"): continue
		var path := directory.path_join(letter.id+".json")
		var date := ""
		if FileAccess.file_exists(path):
			var timestamp := FileAccess.get_modified_time(path)+int(Time.get_time_zone_from_system().bias)*60
			date = Time.get_datetime_string_from_unix_time(timestamp).left(10)
		letter.posted_day = date
		letter.read_day = date if letter.get("read",false) else ""
		letter.reply_day = date if not letter.reply.is_empty() else ""

func advance(world) -> void:
	if world.simulation_seconds<next_scan: return
	next_scan = world.simulation_seconds+10
	if not DirAccess.dir_exists_absolute(directory): return
	var known := {}
	for letter in letters: known[letter.id] = true
	var added := false
	var sent := {}
	for letter in letters: sent[sender_name(letter.sender)+"|"+str(letter.get("posted_day",""))] = true
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".json") or letters.size()>=LIMIT: continue
		var path := directory.path_join(name)
		var file := FileAccess.open(path,FileAccess.READ)
		if file==null or file.get_length()>24576: continue
		var entry = JSON.parse_string(file.get_as_text())
		if not entry is Dictionary: continue
		var timestamp := FileAccess.get_modified_time(path)+int(Time.get_time_zone_from_system().bias)*60
		var date := Time.get_datetime_string_from_unix_time(timestamp).left(10)
		var incoming_image = entry.get("incoming_image","")
		entry = {"id":entry.get("id"),"sender":entry.get("sender"),"body":entry.get("body"),"reply":"","read":false,"posted_day":date,"read_day":"","reply_day":"","thread_id":entry.get("thread_id","")}
		if incoming_image!="": entry["incoming_image"] = incoming_image
		if not valid_letter(entry) or known.has(entry.id): continue
		entry.sender = sender_name(entry.sender)
		if not entry.thread_id.is_empty() and not _can_continue(entry.thread_id,entry.sender): continue
		if name!=entry.id+".json":
			var slot_date := name.left(10)
			if not valid_day(slot_date) or slot_date>today() or name!=slot_name(entry.sender,slot_date): continue
			entry.posted_day = slot_date
		date = entry.posted_day
		var key: String = entry.sender+"|"+date
		if sent.has(key): continue
		sent[key] = true
		letters.append(entry)
		known[entry.id] = true
		added = true
	var manifest := directory.get_base_dir().path_join("red_potato_parcel.txt")
	var file := FileAccess.open(manifest,FileAccess.READ) if FileAccess.file_exists(manifest) else null
	if file!=null and file.get_length()<=64:
		var id := file.get_as_text().strip_edges()
		if valid_parcel_id(id): potato_parcel = id
	if _collect_potato_parcel() or added: world._save_now()

static func valid_parcel_id(id: Variant) -> bool:
	return id is String and (id.is_empty() or (id.length()==32 and id.is_valid_hex_number()))

func _collect_potato_parcel() -> bool:
	if potato_parcel.is_empty() or not potato_seed_letter.is_empty(): return false
	for letter in letters:
		if letter.id==potato_parcel and sender_name(letter.sender)=="Gemini" and letter.get("read",not letter.reply.is_empty()):
			potato_seed_letter = letter.id
			return true
	return false

func pending() -> Dictionary:
	for letter in letters:
		if not letter.get("read",not letter.reply.is_empty()) or not letter.reply.is_empty() or letter.has("draft") or another_letter_today(letter): continue
		var pending_letter := {"id":letter.id,"sender":letter.sender,"body":letter.body}
		var root: String = letter.get("thread_id","")
		if not root.is_empty():
			var history := []
			for earlier in thread(root):
				if earlier.id==letter.id: break
				if earlier.get("read",false):
					history.append({"sender":earlier.sender,"body":earlier.body.left(220),"reply":earlier.reply.left(220)})
			pending_letter["previous_turns"] = history.slice(maxi(0,history.size()-2))
		return pending_letter
	return {}

func prepare_reply(id: String, message: String, memory: String = "", photo_id: int = 0) -> bool:
	var body := message.strip_edges().left(1200)
	if body.is_empty(): return false
	for letter in letters:
		if letter.id==id and letter.get("read",false) and letter.reply.is_empty() and not letter.has("draft") and not another_letter_today(letter):
			letter.draft = {"body":body,"memory":memory.strip_edges().left(180),"photo_id":photo_id}
			return true
	return false

func _post_reply(letter: Dictionary) -> void:
	var draft: Dictionary = letter.draft
	letter.reply = draft.body
	letter.reply_day = today()
	if not draft.memory.is_empty(): letter.memory = draft.memory
	if draft.photo_id>0: letter.photo_id = draft.photo_id
	letter.erase("draft")

static func slot_name(sender: String, date: String) -> String:
	var index := SENDERS.find(sender)
	return date+"-"+str(index if index>=0 else "assistant")+".json"

func _can_continue(root_id: String, sender: String) -> bool:
	for letter in letters:
		if letter.id==root_id and letter.get("thread_id","").is_empty():
			return sender==reply_sender(letter)
	return false

static func reply_sender(root: Dictionary) -> String:
	var sender := sender_name(root.sender)
	return sender if sender in SENDERS else "玩家"

func post(sender: String, body: String, thread_id: String = "", incoming_image: String = "") -> String:
	if sender not in SENDERS: return "请选择发信人。"
	if not thread_id.is_empty() and not _can_continue(thread_id,sender): return "找不到这封原信，或发件人不匹配。"
	var destination := directory.path_join(slot_name(sender,today()))
	if used_today(sender,"posted_day") or FileAccess.file_exists(destination): return "这个发信人今天已投递一封，明天可以再写。"
	if letters.size()>=LIMIT: return "信箱已满。"
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	var letter := {"id":id,"sender":sender.strip_edges(),"body":body.strip_edges(),"reply":"","read":false,"thread_id":thread_id}
	if not incoming_image.is_empty():
		if not valid_image(incoming_image): return "图片无法投递。"
		letter["incoming_image"] = incoming_image
	if not valid_letter(letter): return "请填写署名和正文，正文最多 800 字。"
	if DirAccess.make_dir_recursive_absolute(directory)!=OK: return "暂时无法打开投递目录。"
	var temporary := directory.path_join(id+".tmp")
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return "暂时无法写入来信。"
	file.store_string(JSON.stringify(letter))
	file.close()
	if DirAccess.rename_absolute(temporary,destination)!=OK: return "暂时无法投递。"
	next_scan = 0
	return ""

func door_angle() -> float:
	return minf(1.0,clampf(remaining,0,2)*3)*PI*.46 if phase in ["collect","deliver"] else 0.0

func indoors() -> bool:
	return phase in SEATED_PHASES or phase in ["desk_in","desk_out"]

func walk_to_mailbox(world, delta: float, now: float) -> bool:
	var actor = world.resident
	if world.border.active() or not world.elm_gardening._safe(world) or world.elm_gardening.active():
		if not reading_id.is_empty(): _end_trip(world,now)
		return false
	if reading_id.is_empty():
		if now<retry_at or world.needs.satiety<65 or not world.hobbies.job.is_empty() or world.life_plan.phase!="idle": return false
		for letter in letters:
			if letter.has("draft") and not another_letter_today(letter):
				reading_id = letter.id
				phase = "walk_to_write"
				writing_trip = true
				break
		if reading_id.is_empty():
			for letter in letters:
				if not letter.get("read",false) and not another_letter_today(letter) and not awaiting_reply(sender_name(letter.sender)):
					reading_id = letter.id
					phase = "collect_walk"
					writing_trip = false
					break
		if reading_id.is_empty(): return false
	var letter: Dictionary
	for entry in letters:
		if entry.id==reading_id:
			letter = entry
			break
	if letter.is_empty() or another_letter_today(letter):
		_end_trip(world,now)
		return false
	if indoors():
		_advance_desk(world,letter,delta,now)
		return true
	match phase:
		"collect_walk","carry_letter","walk_to_write","deliver_walk":
			var to_box := phase in ["collect_walk","deliver_walk"]
			var goal := STAND if to_box else Books.DOOR_APPROACH
			var status := {"collect_walk":"走到信箱取信","carry_letter":"拿着来信回屋","walk_to_write":"空手走向书桌准备回信","deliver_walk":"拿着回信去信箱"}
			var result := _walk(world,goal,delta,status[phase],phase in ["carry_letter","deliver_walk"])
			if result<0:
				_end_trip(world,now)
				return false
			if result>0:
				if to_box:
					phase = "collect" if phase=="collect_walk" else "deliver"
					remaining = 2
				else:
					phase = "desk_in"
					indoor_index = 0
					indoor_position = Books.ENTRY
		"collect","deliver":
			actor._pose_stand()
			actor.rotation.y = PI
			actor.right_arm.rotation.x = -1.42+.5*remaining
			_show_letter(world,phase=="collect" and remaining<1,phase=="deliver" and remaining>1)
			actor._emit_activity("从信箱取出来信" if phase=="collect" else "把写好的回信投进信箱")
			remaining -= delta
			if remaining<=0:
				if phase=="collect":
					phase = "carry_letter"
				else:
					_post_reply(letter)
					_end_trip(world,now)
					world._save_now()
	return true

func _walk(world, goal: Vector2, delta: float, status: String, carrying: bool) -> int:
	var actor = world.resident
	var here := Vector2(actor.position.x,actor.position.z)
	if here.distance_to(goal)<.01:
		route.clear()
		return 1
	if route.is_empty():
		route = world.navigation.path(here,goal,.28,Vector2(world.car.position.x,world.car.position.z),1.75)
	if route.is_empty() or route[-1].distance_to(goal)>.01 or not world.navigation.safe_segment(here,route[0],.28) or not world.neighbor._car_clear(route[0]): return -1
	var direction := route[0]-here
	if direction.length()>.001: actor.rotation.y = atan2(direction.x,direction.y)
	var point := here.move_toward(route[0],1.05*delta)
	actor.position.x = point.x
	actor.position.z = point.y
	actor._sync_height()
	actor._walk_pose_step(delta)
	if carrying: actor.right_arm.rotation.x = -.95
	_show_letter(world,carrying and not writing_trip,carrying and writing_trip)
	actor._emit_activity(status)
	if point.distance_to(route[0])<.001: route.remove_at(0)
	return 0

func _advance_desk(world, letter: Dictionary, delta: float, now: float) -> void:
	var actor = world.resident
	if phase in SEATED_PHASES:
		actor._pose_stand()
		actor.rotation.y = PI/2
		actor.left_leg.rotation.x = -PI/2
		actor.right_leg.rotation.x = -PI/2
		actor.left_arm.rotation.x = -.85
		var status := ""
		match phase:
			"reading":
				actor.right_arm.rotation.x = -1.1
				status = "坐在书桌前读来信"
			"file_letter","get_stationery":
				actor.right_arm.rotation.x = -.62+sin(now*5)*.20
				status = "把读完的信收进抽屉" if phase=="file_letter" else "打开抽屉拿出纸笔"
				world.house_interior.set_desk_drawer(clampf(minf(3.0-remaining,remaining)*2.5,0,1))
			"writing":
				actor.right_arm.rotation.x = -.88+sin(now*7)*.16
				status = "坐在书桌前写回信"
			"seal_letter":
				actor.right_arm.rotation.x = -.91+sin(now*5)*.14
				status = "折好信纸，装进信封"
		actor._emit_activity(status)
		remaining -= delta
		if remaining<=0:
			match phase:
				"reading":
					phase = "file_letter"
					remaining = 3
				"get_stationery":
					world.house_interior.set_desk_drawer(0)
					phase = "writing"
					remaining = 12
				"writing":
					phase = "seal_letter"
					remaining = 3
				"file_letter","seal_letter":
					world.house_interior.set_desk_drawer(0)
					if phase=="file_letter":
						letter.read = true
						letter.read_day = today()
						_collect_potato_parcel()
						world.life_plan.next_check = minf(world.life_plan.next_check,world.simulation_seconds)
						world._save_now()
					phase = "desk_out"
					indoor_index = 0
	else:
		var entering := phase=="desk_in"
		var points := [Books.HALL,DESK_APPROACH,Hobbies.DESK_SPOT] if entering else [DESK_APPROACH,Books.HALL,Books.ENTRY]
		var current: Vector3 = world.house_interior.to_global(indoor_position)
		var goal: Vector3 = world.house_interior.to_global(points[indoor_index])
		var direction := goal-current
		if direction.length()>.001: actor.rotation.y = atan2(direction.x,direction.z)
		indoor_position = world.house_interior.to_local(current.move_toward(goal,delta*.85))
		actor.elapsed += delta
		actor._pose_walk()
		if entering!=writing_trip: actor.right_arm.rotation.x = -.95
		actor._emit_activity("拿着信走向书桌" if entering and not writing_trip else ("空手走向书桌" if entering else ("拿着回信走向门口" if writing_trip else "收好来信后离开书桌")))
		if indoor_position.distance_to(points[indoor_index])<.01:
			indoor_index += 1
			if indoor_index==points.size():
				if entering:
					phase = "get_stationery" if writing_trip else "reading"
					remaining = 3 if writing_trip else 7
				elif writing_trip:
					phase = "deliver_walk"
					_reset_pose(actor)
					return
				else:
					_end_trip(world,now)
					return
	var offset := Interior.CHAIR_SEAT_HEIGHT-.555 if phase in SEATED_PHASES else 0.0
	actor.model.position = actor.to_local(world.house_interior.to_global(indoor_position))+Vector3.UP*offset
	actor.model.visible = world.house_interior.visible
	_show_desk_props(world,phase=="writing" or (phase=="get_stationery" and remaining<1) or (phase=="seal_letter" and remaining>1.5))
	_show_letter(world,phase=="reading" or (phase=="file_letter" and remaining>1.5) or (phase=="desk_in" and not writing_trip),writing_trip and (phase=="desk_out" or (phase=="seal_letter" and remaining<=1.5)))

func _show_desk_props(world, visible: bool) -> void:
	if not is_instance_valid(desk_sheet):
		if not visible: return
		desk_sheet = world._box(Vector3(3.31,.881,-.11),Vector3(.30,.014,.41),"fff0ce",world.house_interior)
		pencil = world._box(Vector3(.035,-.39,.03),Vector3(.024,.17,.024),"926447",world.resident.right_arm)
		pencil.rotation.x = -.6
	desk_sheet.visible = visible
	pencil.visible = visible

func _show_letter(world, sheet_visible: bool, envelope_visible: bool) -> void:
	if not is_instance_valid(paper):
		paper = Node3D.new()
		world.resident.right_arm.add_child(paper)
		paper.position = Vector3(.045,-.37,.035)
		world._box(Vector3.ZERO,Vector3(.18,.20,.015),"fff0ce",paper)
		for y in [-.04,0.0,.04]:
			world._box(Vector3(0,y,.009),Vector3(.11,.01,.003),"b79570",paper)
		envelope = world._box(Vector3(.045,-.37,.035),Vector3(.21,.145,.035),"dfbc88",world.resident.right_arm)
		world._box(Vector3(0,-.012,.021),Vector3(.035,.030,.009),"ab6657",envelope)
	paper.visible = sheet_visible
	envelope.visible = envelope_visible

func _reset_pose(actor) -> void:
	if is_instance_valid(paper): paper.hide()
	if is_instance_valid(envelope): envelope.hide()
	if is_instance_valid(desk_sheet): desk_sheet.hide()
	if is_instance_valid(pencil): pencil.hide()
	actor.model.position = Vector3.ZERO
	actor.model.show()
	actor._pose_stand()

func _end_trip(world, now: float) -> void:
	world.house_interior.set_desk_drawer(0)
	reading_id = ""
	phase = ""
	route.clear()
	retry_at = now+10
	_reset_pose(world.resident)

func recall_memories(query: String = "") -> Array:
	var notes: Array = []
	for letter in letters:
		if not letter.get("memory","").is_empty(): notes.append(letter)
	notes.reverse()
	notes.sort_custom(func(first, second):
		var first_matches: bool = not query.is_empty() and query.to_lower().contains(first.sender.to_lower())
		var second_matches: bool = not query.is_empty() and query.to_lower().contains(second.sender.to_lower())
		if first_matches!=second_matches: return first_matches
		if first.reply_day!=second.reply_day: return first.reply_day>second.reply_day
		return letters.find(first)>letters.find(second))
	return notes.slice(0,4).map(func(letter):
		return {"sender":letter.sender,"date":letter.reply_day,"memory":letter.memory})

func viewed_replies_path() -> String:
	return directory.get_base_dir().path_join("viewed_replies.cfg")

func has_unread_letters() -> bool:
	return letters.any(func(letter): return not letter.get("read",not letter.reply.is_empty()))

func has_new_reply(letter: Dictionary) -> bool:
	return not letter.reply.is_empty() and not viewed_replies.has_section_key("replies",letter.id)

func new_reply_count() -> int:
	var count := 0
	for letter in letters:
		if has_new_reply(letter): count += 1
	return count

func mark_reply_viewed(letter: Dictionary) -> void:
	if not has_new_reply(letter): return
	viewed_replies.set_value("replies",letter.id,true)
	var destination := viewed_replies_path()
	var temporary := destination+".tmp"
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir())==OK and viewed_replies.save(temporary)==OK:
		DirAccess.rename_absolute(temporary,destination)

func thread(root_id: String) -> Array:
	return letters.filter(func(letter): return letter.id==root_id or letter.get("thread_id","")==root_id)

func conversations(sender: String) -> Array:
	var rows := []
	for root in letters:
		if not root.get("thread_id","").is_empty(): continue
		var turns := thread(root.id)
		if not sender.is_empty() and not turns.any(func(letter): return sender_name(letter.sender)==sender): continue
		var latest: Dictionary = root
		var activity_day := ""
		var fresh := false
		for letter in turns:
			var day: String = letter.get("reply_day","") if not letter.reply.is_empty() else letter.get("posted_day","")
			if day>=activity_day:
				activity_day = day
				latest = letter
			fresh = fresh or has_new_reply(letter)
		rows.append({"id":root.id,"latest":latest,"fresh":fresh,"date":activity_day,"order":letters.find(latest)})
	rows.sort_custom(func(first,second):
		if first.fresh!=second.fresh: return first.fresh
		return first.date>second.date if first.date!=second.date else first.order>second.order)
	return rows

func attachment_text(letter: Dictionary) -> String:
	if letter.id==potato_seed_letter: return "附件 · 红土豆种子 ×1（埃尔已收下）"
	if letter.id==potato_parcel: return "附件 · 红土豆种子 ×1（待领取）"
	return ""

static func valid_day(value: Variant) -> bool:
	if not value is String: return false
	if value.is_empty(): return true
	var parts: PackedStringArray = value.split("-")
	return value.length()==10 and parts.size()==3 and parts[0].length()==4 and parts[1].length()==2 and parts[2].length()==2 and parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int() and int(parts[1]) in range(1,13) and int(parts[2]) in range(1,32)

static func valid_letter(entry: Variant) -> bool:
	return entry is Dictionary and entry.get("id") is String and entry.id.length()==32 and entry.id.is_valid_hex_number() and entry.get("sender") is String and entry.sender.length() in range(1,81) and entry.get("body") is String and entry.body.length() in range(1,801) and entry.get("reply") is String and entry.reply.length()<=1200 and entry.get("read",false) is bool and valid_day(entry.get("posted_day","")) and valid_day(entry.get("read_day","")) and valid_day(entry.get("reply_day","")) and valid_parcel_id(entry.get("thread_id","")) and valid_memory(entry) and valid_image(entry.get("incoming_image",""))

static func valid_image(value: Variant) -> bool:
	if not value is String or value.length()>IMAGE_LIMIT: return false
	if value.is_empty(): return true
	return value.begins_with("/9j/") and value.length()%4==0

func incoming_image(id: String) -> String:
	for letter in letters:
		if letter.id==id: return letter.get("incoming_image","")
	return ""

static func valid_memory(letter: Dictionary) -> bool:
	if letter.has("draft"):
		var draft = letter.draft
		if not letter.get("read",false) or not letter.reply.is_empty() or not draft is Dictionary: return false
		if not draft.get("body") is String or draft.body.length() not in range(1,1201): return false
		if not draft.get("memory") is String or draft.memory.length()>180: return false
		var id = draft.get("photo_id")
		if not (id is int or id is float) or not is_finite(float(id)) or id<0 or id!=floor(id): return false
	if letter.has("photo_id"):
		var photo_id = letter.photo_id
		if not (photo_id is int or photo_id is float) or not is_finite(float(photo_id)) or photo_id<1 or photo_id!=floor(photo_id) or letter.reply.is_empty(): return false
	if not letter.has("memory"): return true
	return letter.memory is String and letter.memory.length() in range(1,181) and letter.get("read",false) and not letter.reply.is_empty() and not letter.get("reply_day","").is_empty()

static func valid(entries: Variant) -> bool:
	if not entries is Array or entries.size()>LIMIT: return false
	var seen := {}
	for letter in entries:
		if not valid_letter(letter) or seen.has(letter.id): return false
		var root: String = letter.get("thread_id","")
		if not root.is_empty() and (not seen.has(root) or not seen[root].get("thread_id","").is_empty() or sender_name(letter.sender)!=reply_sender(seen[root])): return false
		seen[letter.id] = letter
	return true
