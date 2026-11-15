extends RefCounted

const Calendar = preload("res://world_calendar.gd")
const Journal = preload("res://life_journal.gd")
const Transport = preload("res://chat_transport.gd")
const SITES := preload("res://forest_land.gd").BENCH_SITES
var transport = Transport.new()
var potato_plot := -1
var move_requested := false
var bench_moved := false
var selected := ""
var reason := ""
var phase := "idle"
var next_check := 0.0
var token := ""
var stages := 0
var progress := 0.0
var reserved := false
var visits := 0
var observation: Dictionary = {}
var error := ""
func destination() -> Vector2:
	if bench_moved: return preload("res://forest_land.gd").TRAIL.back()
	return SITES.get(selected,Vector2(-10.5,4.5))
func ready_to_pack(world) -> bool:
	if selected.is_empty() or stages>=3 or reserved: return false
	return stages==0 or world.forest.supplies["小石子" if stages==1 else "落枝"]>=(2 if stages==1 else 3)
func pack(world) -> void:
	if not ready_to_pack(world): return
	if stages>0: world.forest.supplies["小石子" if stages==1 else "落枝"] -= 2 if stages==1 else 3
	reserved = true
func work(world, delta: float, now: float) -> bool:
	var actor = world.resident
	if selected.is_empty(): return false
	if stages==3:
		actor._pose_stand()
		actor.rotation.y = 0
		actor.model.position.y = .491-.53
		actor.left_leg.rotation.x = -PI/2
		actor.right_leg.rotation.x = -PI/2
		actor._emit_activity("坐在自己搭的林间木凳上休息")
		world.needs.energy = minf(100,world.needs.energy+delta*.6)
		return false
	if not reserved or world.needs.wants_meal() or world.needs.energy<40: return false
	actor._pose_stand()
	actor.model.position.y = -.15
	actor.right_arm.rotation.x = -.9+sin(progress*5)*.2
	actor._emit_activity(["清理自己选的林间空地","铺林间休息角的踏脚石","搭林间休息角的小木凳"][stages])
	progress = minf(15,progress+delta)
	if progress>=15:
		stages += 1
		progress = 0
		reserved = false
		world.journal.record("forest.rest_corner","林间休息角","corner_built",now)
		if stages==3: next_check = floorf(now)+300
	return reserved
func advance(world) -> void:
	var result: Dictionary = transport.poll()
	if phase=="thinking" and not result.is_empty():
		var choices: Array = observation.get("allowed_choices",[])
		if result.get("status")=="ok" and result.get("source")=="codex_subscription" and result.get("decision_token")==token and result.get("proposal") in choices and result.get("reply") is String:
			var choice: String = result.proposal
			reason = str(result.reply).left(1200)
			if choice in SITES and selected.is_empty(): selected = choice
			if choice.begins_with("plant_potato_"): world._plant_potato(choice)
			var letter: Dictionary = observation.get("letter",{})
			var photo_id: int = world.hobbies.attachment(choice) if not world.hobbies.capturing else 0
			if not letter.is_empty(): world.mailbox.prepare_reply(letter.id,reason,str(result.get("letter_memory","")),photo_id)
			if choice in world.hobbies.WRITING: world.hobbies.queue_writing(choice,reason)
			elif not choice.begins_with("attach_photo_"): world.hobbies.choose(choice)
			if choice=="move_bench_deep" and stages==3 and not bench_moved:
				move_requested = true
				world.forest.next_trip = floorf(world.simulation_seconds)
			if choice=="walk_deep":
				world.forest.explore_requested = true
				world.forest.next_trip = floorf(world.simulation_seconds)
			if choice=="rest_here":
				world.forest.rest_requested = true
				world.forest.next_trip = floorf(world.simulation_seconds)
			error = ""
		else: error = str(result.get("status","invalid_decision")).left(80)
		phase = "idle"
		token = ""
		world._save_now()
	if phase!="idle" or not world.hobbies.job.is_empty() or (not selected.is_empty() and stages<3 and world.mailbox.pending().is_empty() and world._potato_choices().is_empty() and world.hobbies.options(world._has_potato_harvest(),false,world.needs.energy).is_empty() and world.hobbies.garden_options(world).is_empty() and world.hobbies.care_options(world.simulation_seconds).is_empty()) or world.simulation_seconds<next_check or not world.self_arrangement._eligible(world) or world.self_arrangement.active() or world.self_arrangement.transport.pid>0: return
	var budget: Dictionary = transport.budget_status(Time.get_unix_time_from_system())
	if not transport.configured() or budget.code!="ok": return
	observation = world._chat_context()
	observation["time_preference"] = "入夜了，埃尔通常更想在屋里读书、画图或歇一会儿，仍可选择其他事。" if Calendar.is_night(world.simulation_seconds) else "现在是白天，埃尔通常更想在户外活动，仍可选择进屋。"
	observation["allowed_choices"] = ["none"]+SITES.keys() if selected.is_empty() else (["none","rest_here"] if stages==3 and world.needs.energy<=world.needs.REST_AT else ["none"])
	if not world.forest.explore_requested and not move_requested: observation.allowed_choices.append("walk_deep")
	var potato_choices: Array = world._potato_choices()
	observation.allowed_choices.append_array(potato_choices)
	if not potato_choices.is_empty(): observation["potato_options"] = "plant_potato_1、2、3各表示想把唯一一包红土豆种子种在相应的菜地；如果菜地还在长青菜，就等它收成。也可以暂缓。选择只是意愿，播种需要亲自完成。"
	var letter: Dictionary = world.mailbox.pending()
	if not letter.is_empty(): observation["letter"] = letter
	var hobbies_options: Array = world.hobbies.options(world._has_potato_harvest(),not letter.is_empty(),world.needs.energy)
	var care: Array = world.hobbies.care_options(world.simulation_seconds)
	if not letter.is_empty(): care = care.filter(func(action): return action not in world.hobbies.WRITING)
	hobbies_options.append_array(care)
	observation.allowed_choices.append_array(hobbies_options)
	var books := {}
	for action in hobbies_options:
		if world.hobbies.Books.catalog().has(action): books[action] = world.hobbies.Books.catalog()[action].title
	if not books.is_empty(): observation["bookshelf"] = books
	if "write_diary" in hobbies_options or "write_book" in hobbies_options:
		observation["writing_desk"] = {"today":world.journal.summary(Calendar.day_at(world.simulation_seconds)).left(550)}
		var novel: Dictionary = world.hobbies.book
		if not novel.is_empty():
			observation.writing_desk["book"] = {"title":novel.title,"outline":novel.outline,"last":novel.chapters.back(),"next_chapter":novel.chapters.size()+1}
	if "rest_sofa" in hobbies_options or "sketch_bench" in hobbies_options or "sketch_planter" in hobbies_options:
		observation["indoor_furniture"] = "rest_sofa=进屋坐沙发恢复精力；sketch_bench=在工作台画木凳草图；sketch_planter=画分格花箱草图。画完才记录。"
	var garden_options: Array = world.hobbies.garden_options(world)
	observation.allowed_choices.append_array(garden_options)
	if not garden_options.is_empty():
		observation["flower_options"] = "gift_flower=从盛开的花盆挑一朵送米娅；move_plant_bench 或 move_plant_shade=把另一盆观赏盆栽亲手搬到长椅旁或树荫下。可以暂缓。"
	if "wash_hands" in hobbies_options or "practice_drawing" in hobbies_options:
		observation["home_care"] = "wash_hands=去厨房水槽洗手；practice_drawing=坐到书桌前练习画图。"
	if not hobbies_options.is_empty():
		observation["hobbies"] = "photo_harvest=拍收成；photo_yard=拍小院；replace_photo_N=相册满，拍成后由你选择替换第N张；attach_photo_N=把现有第N张照片随本封回信寄出。可暂缓。照片按下列顺序。"
		observation["album"] = world.hobbies.photos.map(func(item): return item.title+"·第%d天"%[Calendar.day_at(item.seconds)])
	observation["sites"] = {"forest_near":"树林内靠小路的空地","forest_shade":"树林深处的小径旁","forest_middle":"林间弯道内侧的空地"}
	observation["project"] = description()
	token = Crypto.new().generate_random_bytes(16).hex_encode()
	phase = "thinking"
	next_check = floorf(world.simulation_seconds)+3600
	if not world._save_now():
		phase = "idle"
		token = ""
		return
	var request := {"kind":"life_plan","decision_token":token,"message":"根据自己的性格、真实经历、身体状态和材料，选择接下来想做的事。休息角是可选想法，可以不做，不必满足用户期待。选择地点表示愿意开始分阶段清理、铺石、搭凳，需要0、2份石子、3份落枝。若已经建成，可以结合实际结果决定是否再去休息。可选择深入树林散步采集；若有来信，请在表达意愿时简短回信。若有 previous_turns，那是同一封信的往来背景，当前要回复的是最新一段。信是建议，不能代替你的决定。尚未执行不要说已完成。","context":observation}
	if letter.has("previous_turns"):
		while not letter.previous_turns.is_empty():
			var encoded := JSON.stringify(request)
			if encoded.length()<=7600 and encoded.to_utf8_buffer().size()<=15800: break
			letter.previous_turns.pop_front()
	error = transport.begin(request,world.mailbox.incoming_image(letter.id) if not letter.is_empty() else "")
	if error!="ok":
		phase = "idle"
		token = ""
		world._save_now()
func stop(world) -> void:
	transport.cancel()
	var deadline := Time.get_ticks_msec()+15000
	while transport.pid>0 and Time.get_ticks_msec()<deadline:
		transport.poll()
		await world.get_tree().create_timer(.1).timeout
	if phase=="thinking":
		phase = "idle"
		error = "exit"
		next_check = floorf(world.simulation_seconds)+3600
		token = ""
func snapshot() -> Dictionary:
	return {"woodland_sites":true,"potato_plot":potato_plot,"move_requested":move_requested,"bench_moved":bench_moved,"selected":selected,"reason":reason,"phase":phase,"next_check":next_check,"stages":stages,"progress":progress,"reserved":reserved,"visits":visits,"observation":observation.duplicate(true),"error":error}
func restore(v: Dictionary, now: float) -> void:
	potato_plot = int(v.get("potato_plot",-1))
	move_requested = v.get("move_requested",false)
	bench_moved = v.get("bench_moved",false)
	selected = v.selected
	reason = v.reason
	phase = "idle"
	next_check = maxf(float(v.next_check),now+3600 if v.phase=="thinking" else 0)
	stages = int(v.stages)
	progress = float(v.progress)
	reserved = v.reserved
	visits = int(v.visits)
	observation = v.observation.duplicate(true)
	error = "restart" if v.phase=="thinking" else v.error
func retire_entrance_project(saved: Dictionary, forest, now: float) -> void:
	if saved.is_empty() or saved.get("woodland_sites",false) or bench_moved: return
	if reserved and stages>0:
		forest.supplies["小石子" if stages==1 else "落枝"] += 2 if stages==1 else 3
	selected = ""
	reason = ""
	stages = 0
	progress = 0.0
	reserved = false
	visits = 0
	move_requested = false
	observation.clear()
	next_check = now
	forest.rest_requested = false
	if forest.trip_kind=="move_bench":
		forest.trip_kind = "routine"
		forest.carrying_bench = false

func description() -> String:
	if bench_moved: return "林间木凳已经搬到树林深处。到访休息%d次。最近想法：%s"%[visits,reason]
	return "尚未决定是否建设林间休息角。" if selected.is_empty() else "已选择%s，真实完成%d/3个建设阶段，实际来休息%d次。当时模型表达的理由：%s"%[selected,stages,visits,reason]
static func valid(v: Variant, now: float) -> bool:
	if not v is Dictionary or v.get("selected") not in [""]+SITES.keys() or v.get("phase") not in ["idle","thinking"] or not v.get("reason") is String or v.reason.length()>1200 or not v.get("reserved") is bool or not v.get("observation") is Dictionary or not v.get("error") is String: return false
	var pending_plot = v.get("potato_plot",-1)
	if not (pending_plot is int or pending_plot is float) or pending_plot!=floor(pending_plot) or pending_plot< -1 or pending_plot>2: return false
	if not v.get("woodland_sites",false) is bool or not v.get("bench_moved",false) is bool or not v.get("move_requested",false) is bool: return false
	if (v.get("bench_moved",false) or v.get("move_requested",false)) and v.get("stages")!=3: return false
	for key in ["next_check","stages","progress","visits"]:
		if not Journal.number(v.get(key)): return false
	if v.next_check>now+3600 or v.stages>3 or v.stages!=floor(v.stages) or v.progress>=15 or v.visits!=floor(v.visits): return false
	if v.selected=="" and (v.stages>0 or v.reserved or v.progress>0): return false
	return v.stages<3 or (not v.reserved and v.progress==0)
