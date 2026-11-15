extends RefCounted

const Dining = preload("res://outdoor_dining.gd")
const Feeding = preload("res://rabbit_feeding.gd")
const Life = preload("res://basic_life.gd")
const Drawings = preload("res://elm_drawings.gd")
const WRITING := ["write_diary","write_book"]
var drawings: Array = []
var next_drawing := 1
var framed := 0
var writing: Array = []
var book: Dictionary = {}
var writing_draft: Dictionary = {}
const Books = preload("res://elm_books.gd")
const Journal = preload("res://life_journal.gd")
const LIMIT := 24
const OVEN := Vector2(1.18,-.22)
const OVEN_STAND := Vector2(2,0)
const PHOTO_SPOTS := {"photo_harvest":Vector2(2.5,-2),"photo_yard":Vector2(3.5,6)}
const PHOTO_NAMES := {"photo_harvest":"第一批红土豆","photo_yard":"小院一角"}
var pages_read: Dictionary = {}
var indoor_step := -1
var indoor_position := Vector3.ZERO
const SOFA_SPOT := Vector3(3.40,.04,1.32)
const Interior = preload("res://elm_interior.gd")
const DESK_SPOT := Interior.CHAIR_POSITION + Vector3(0,.02,0)
const STOVE_SPOT := Vector3(1.03,.04,-1.49)
const SINK_SPOT := Vector3(3.38,.04,-1.51)
const BATH_SPOT := Vector3(-3.33,.04,1.26)
const BED_SPOT := Vector3(-3.06,.04,-1.48)
const TOILET_SPOT := Vector3(-1.81,.04,2.04)
const CARE := ["wash_hands","practice_drawing"]
const BATHROOM := ["take_bath","use_toilet"]
const SLEEP := "sleep_in_bed"
const CARE_INTERVAL := 1800.0
var care_finished: Dictionary = {}
var last_evening_activity := -1.0
const EVENING_INTERVAL := 900.0
const Calendar = preload("res://world_calendar.gd")
const SKETCHES := {"sketch_bench":"林间木凳草图","sketch_planter":"分格花箱草图"}
var drafts: Array = []
var indoor_done := false
var sheltering := false
var last_rain_activity := ""
var rain_pause_until := -1.0
var rain_walk_until := -1.0
var took_rain_walk := false


var photos: Array = []
var next_id := 1
var used := 0
var job := ""
var replace_id := 0
var route := PackedVector2Array()
var remaining := 0.0
var retry_at := 0.0
var capturing := false
var carrying_plant := false
var carrying_flower := false
var route_goal := Vector2.INF
const Plant = preload("res://plant_arrangement.gd")
const MOVE_TARGETS := {"move_plant_bench":"object.bench.001","move_plant_shade":"place.tree_shade"}
const PLANT_STANDS := {"object.bench.001":Plant.TREE_APPROACH,"place.tree_shade":Plant.TREE_APPROACH}


func options(harvested: bool, letter_pending: bool, energy: float = 100.0) -> Array:
	var choices := []
	if job.is_empty():
		choices.append_array(Books.available(pages_read))
		if energy<=Life.REST_AT: choices.append("rest_sofa")
		for design in SKETCHES:
			if design not in drafts: choices.append(design)
		if photos.size()<LIMIT:
			if harvested and used<3: choices.append("photo_harvest")
			choices.append("photo_yard")
		else:
			for i in range(photos.size()): choices.append("replace_photo_%d"%(i+1))
	if letter_pending:
		for i in range(photos.size()): choices.append("attach_photo_%d"%(i+1))
	return choices

func care_options(now: float) -> Array:
	var choices := []
	if not job.is_empty(): return choices
	for action in CARE+WRITING:
		if action=="write_book" and book.get("finished",false): continue
		if now>=float(care_finished.get(action,-CARE_INTERVAL))+CARE_INTERVAL:
			choices.append(action)
	return choices

func consider_bathroom(world, now: float) -> void:
	if not job.is_empty() or now<retry_at or world.life_plan.phase!="idle" or world.border.active() or world.elm_gardening.active(): return
	if not world.elm_gardening._safe(world,false,true): return
	if world.needs.wants_toilet():
		choose("use_toilet")
	elif world.needs.wants_bath(now):
		choose("take_bath")

func consider_evening_activity(world, now: float) -> void:
	if not Calendar.is_night(now) or not job.is_empty() or world.life_plan.phase!="idle":
		return
	if last_evening_activity>=0 and now<last_evening_activity+EVENING_INTERVAL: return
	if now<retry_at or not world.elm_gardening._safe(world,false,true) or world.border.active(): return
	var reading := Books.available(pages_read)
	if world.needs.energy<=Life.REST_AT:
		choose(SLEEP)
	elif not reading.is_empty():
		choose(reading[0])
	else:
		var options := care_options(now)
		var desk_choices := ["practice_drawing"]
		desk_choices.sort_custom(func(a,b): return care_finished.get(a,-1)<care_finished.get(b,-1))
		for action in desk_choices:
			if action in options:
				choose(action)
				break

func consider_rain_shelter(world, now: float) -> void:
	if now<rain_walk_until: return
	if not job.is_empty() or now<retry_at or world.life_plan.phase!="idle" or world.border.active() or world.elm_gardening.active(): return
	if world.dining.meal!="" or world.dining.state.prepared!="" or world.dining.state.order_until>0 or not world.patio_chat.phase.is_empty(): return
	if not world.elm_gardening._safe(world,false,true): return
	_choose_rain_activity(world,now)

func _choose_rain_activity(world, now: float) -> void:
	var reading := Books.available(pages_read)
	var options := care_options(now)
	if world.needs.energy<=Life.REST_AT:
		choose(SLEEP)
	elif world.needs.wants_toilet():
		choose("use_toilet")
	elif not reading.is_empty() and not Books.catalog().has(last_rain_activity):
		choose(reading[0])
	elif "practice_drawing" in options:
		choose("practice_drawing")
	elif last_rain_activity!="rest_sofa":
		choose("rest_sofa")
	elif not reading.is_empty():
		choose(reading[0])
	else:
		choose("practice_drawing")
	rain_pause_until = -1.0
	sheltering = true

func _can_stay_inside(world) -> bool:
	return world.event_seconds>=rain_walk_until and world.shelter_from_rain and not world.needs.wants_meal() and world.dining.state.prepared=="" and world.mailbox.reading_id.is_empty()

func consider_home_meal(world, now: float) -> void:
	if Calendar.anchor<0 or not job.is_empty() or now<retry_at or world.life_plan.phase!="idle": return
	if world.needs==null or not world.needs.wants_meal() or world.dining.state.prepared!="" or world.dining.meal!="" or world.dining.state.order_until>0: return
	if not world.elm_gardening._safe(world,true) or world.border.active(): return
	if world.needs.garden_food>0:
		choose("cook_vegetables")
	elif world._has_potato_harvest() and used<3:
		choose("roast_potato")
	elif world.dining.can_order(now) and world.dining.prefers_delivery(now):
		choose("call_pizza")

func consider_rabbit_care(world, now: float) -> void:
	if not world.rabbit_enabled or not job.is_empty() or world.life_plan.phase!="idle" or now<retry_at: return
	if world.rabbit.mode in ["feed_walk","feeding"] or not world.elm_gardening._safe(world) or world.border.active(): return
	var threshold := 0 if Calendar.is_night(now) else Feeding.REFILL_AT
	if world.rabbit.water<=threshold:
		choose("refill_rabbit_water")
	elif world.rabbit.hay<=threshold:
		choose("refill_rabbit_hay")

func garden_options(world) -> Array:
	var choices := []
	if not job.is_empty(): return choices
	if world.plant_arrangement.phase=="placed":
		for action in MOVE_TARGETS:
			if Plant.POSITIONS[MOVE_TARGETS[action]]!=Plant.POSITIONS[world.plant_arrangement.target]: choices.append(action)
	if world.elm_gardening.can_pick() and world.neighbor_enabled and world.neighbor.visible:
		choices.append("gift_flower")
	return choices

func choose(choice: String) -> void:
	if not job.is_empty(): return
	if choice in WRITING+["roast_potato","cook_vegetables","call_pizza","gift_flower","rest_sofa",SLEEP]+CARE+BATHROOM+Feeding.REFILL or (SKETCHES.has(choice) and choice not in drafts) or PHOTO_SPOTS.has(choice) or MOVE_TARGETS.has(choice) or choice in Books.available(pages_read):
		job = choice
	elif choice.begins_with("replace_photo_"):
		var i := int(choice.get_slice("_",2))-1
		if photos.size()!=LIMIT or i<0 or i>=photos.size(): return
		replace_id = photos[i].id
		job = "photo_yard"

func attachment(choice: String) -> int:
	if not choice.begins_with("attach_photo_"): return 0
	var i := int(choice.get_slice("_",2))-1
	return int(photos[i].id) if i>=0 and i<photos.size() else 0

func photo(id: int) -> Dictionary:
	for item in photos:
		if item.id==id: return item
	return {}

func indoors() -> bool:
	return indoor_step>=0

func reading_inside() -> bool:
	return indoor_step==2 and remaining>0 and Books.catalog().has(job)

func _leave_room(world) -> void:
	indoor_step = -1
	sheltering = false
	if indoor_done: job = ""
	indoor_done = false
	world.resident.model.position = Vector3.ZERO
	world.resident.model.show()
	world.resident._pose_stand()

func _reset_travel(world) -> void:
	if indoors(): _leave_room(world)
	route.clear()
	route_goal = Vector2.INF
	remaining = 0
	if carrying_plant: world._show_arranged_plant(world.plant_arrangement.target)
	carrying_plant = false
	carrying_flower = false

func advance(world, delta: float, now: float) -> bool:
	if capturing: return true
	if not indoors() and ((job=="take_bath" and not world.needs.wants_bath(now)) or (job=="use_toilet" and not world.needs.wants_toilet())):
		_reset_travel(world)
		job = ""
	if job.is_empty() or now<retry_at: return false
	var actor = world.resident
	if not world.elm_gardening._safe(world,indoors() or job in ["cook_vegetables","roast_potato","call_pizza"],(job==SLEEP or job in BATHROOM)) or world.plant_visit.active() or world.plant_routine.visit.active():
		_reset_travel(world)
		return false
	if indoors(): return _advance_indoor_activity(world,delta,now)
	var moving_plant := MOVE_TARGETS.has(job)
	if moving_plant and (world.plant_arrangement.phase!="placed" or world.arranged_plant==null or world.plant_arrangement.target==MOVE_TARGETS[job]):
		_reset_travel(world)
		job = ""
		return false
	var gifting := job=="gift_flower"
	if gifting and not world.elm_gardening.can_pick():
		_reset_travel(world)
		job = ""
		return false
	if gifting and (not world.neighbor_enabled or not world.neighbor.visible or world.neighbor.mode!="rest"):
		_reset_travel(world)
		return false
	if job=="cook_vegetables" and world.needs.garden_food==0:
		job = ""
		_reset_travel(world)
		return false
	var indoor_activity := Books.catalog().has(job) or job in ["rest_sofa","cook_vegetables","call_pizza",SLEEP] or SKETCHES.has(job) or job in CARE+BATHROOM+WRITING
	var roasting := job=="roast_potato"
	var refilling := job in Feeding.REFILL
	var target: Vector2
	if moving_plant:
		target = PLANT_STANDS[MOVE_TARGETS[job] if carrying_plant else world.plant_arrangement.target]
	elif gifting:
		target = world.neighbor.flat() if carrying_flower else world.elm_gardening.work_position
	elif roasting:
		target = OVEN_STAND
	elif indoor_activity:
		target = Books.DOOR_APPROACH
	elif refilling:
		target = Feeding.STAND
	else:
		if DisplayServer.get_name()=="headless": return false
		target = PHOTO_SPOTS[job]
	var here := Vector2(actor.position.x,actor.position.z)
	var parked := Vector2(world.car.position.x,world.car.position.z)
	if target.distance_to(parked)<1.75 or (moving_plant and Plant.POSITIONS[MOVE_TARGETS[job]].distance_to(parked)<1.45):
		_reset_travel(world)
		retry_at = now+15
		return false
	var tolerance := .8 if gifting and carrying_flower else .01
	if here.distance_to(target)>tolerance:
		if route_goal!=target:
			route.clear()
			route_goal = target
		if route.is_empty(): route = world.navigation.path(here,target,.28,parked,1.75)
		if route.is_empty() or route[-1].distance_to(target)>tolerance or not world.navigation.safe_segment(here,route[0],.28) or not world.neighbor._car_clear(route[0]):
			_reset_travel(world)
			retry_at = now+15
			return false
		var direction := route[0]-here
		if direction.length()>.001: actor.rotation.y = atan2(direction.x,direction.y)
		var point := here.move_toward(route[0],1.05*delta)
		actor.position.x = point.x
		actor.position.z = point.y
		actor._sync_height()
		actor._walk_pose_step(delta)
		if carrying_plant or carrying_flower: actor.right_arm.rotation.x = -.9
		var activity := "走向烤炉" if roasting else "走去找角度拍照"
		if indoor_activity: activity = "走向小屋正门"
		if refilling: activity = "走向德雷克的食水角"
		if moving_plant: activity = "抱着盆栽去新位置" if carrying_plant else "去搬观赏盆栽"
		if gifting: activity = "拿着花去找米娅" if carrying_flower else "去花圃挑一朵花"
		actor._emit_activity(activity)
		if point.distance_to(route[0])<.001: route.remove_at(0)
		return true
	if refilling:
		if world.rabbit.mode in ["feed_walk","feeding"]:
			_reset_travel(world)
			retry_at = now+10
			return false
		if remaining<=0: remaining = 4
		remaining = maxf(0,remaining-delta)
		actor.rotation.y = PI
		actor._pose_stand()
		actor.right_arm.rotation.x = -.75
		actor._emit_activity("给德雷克添水" if job=="refill_rabbit_water" else "给德雷克添草")
		if remaining==0:
			if job=="refill_rabbit_water": world.rabbit.water = Feeding.CAPACITY
			else: world.rabbit.hay = Feeding.CAPACITY
			if world.journal_enabled: world.journal.record("pet.rabbit.001","德雷克的食水角",job,now)
			job = ""
			route.clear()
			actor._pose_stand()
		return true
	if moving_plant:
		if not carrying_plant:
			carrying_plant = true
			world.arranged_plant.reparent(actor.right_arm,false)
			world.arranged_plant.position = Vector3(0,-.42,.09)
		else:
			world.plant_arrangement.move_to(world,MOVE_TARGETS[job],now)
			carrying_plant = false
			job = ""
		route.clear()
		return true
	if gifting:
		if not carrying_flower:
			carrying_flower = true
		else:
			if remaining<=0: remaining = 3
			remaining -= delta
			actor._pose_stand()
			actor.right_arm.rotation.x = -1
			actor._emit_activity("把花递给米娅")
			if remaining>0: return true
			world.elm_gardening.picked = true
			world.elm_gardening._record(world,"flower_gifted",now)
			actor._pose_stand()
			actor.right_arm.rotation.x = -1
			actor._emit_activity("把花送给米娅")
			carrying_flower = false
			job = ""
		route.clear()
		return true
	if indoor_activity:
		indoor_position = Books.ENTRY
		indoor_step = 0
		route.clear()
		return _advance_indoor_activity(world,delta,now)
	if not roasting:
		capturing = true
		actor._pose_stand()
		actor._emit_activity("举起相机拍照")
		world._capture_elm_photo.call_deferred(job)
		return true
	if remaining<=0: remaining = 12
	remaining -= delta
	actor._pose_stand()
	actor.rotation.y = atan2(OVEN.x-OVEN_STAND.x,OVEN.y-OVEN_STAND.y)
	actor.right_arm.rotation.x = -.9
	actor._emit_activity("用小烤炉烤红土豆")
	if remaining<=0:
		used += 1
		job = ""
		world.dining.state.prepared = "potato"
		actor._pose_stand()
	return true

func _advance_indoor_activity(world, delta: float, now: float) -> bool:
	var actor = world.resident
	var reading := Books.catalog().has(job)
	var resting := job=="rest_sofa"
	var sketching := SKETCHES.has(job) or job=="practice_drawing" or job in WRITING
	var phoning := job=="call_pizza"
	var cooking := job=="cook_vegetables"
	var washing := job=="wash_hands"
	var bathing := job=="take_bath"
	var sleeping := job==SLEEP
	var using_toilet := job=="use_toilet"
	var target := DESK_SPOT
	if reading: target = Books.READING_SPOT
	elif resting: target = SOFA_SPOT
	elif washing: target = SINK_SPOT
	elif cooking: target = STOVE_SPOT
	elif phoning: target = Vector3(-1.92,.04,-1.58)
	elif bathing: target = BATH_SPOT
	elif sleeping: target = BED_SPOT
	elif using_toilet: target = TOILET_SPOT
	var approach := Books.HALL
	if sketching: approach = Vector3(2.72,.04,.70)
	elif washing or cooking: approach = Vector3(0,.04,-1.51)
	elif bathing or using_toilet: approach = Vector3(-.82,.04,1.26)
	elif sleeping: approach = Vector3(-2.03,.04,-.58)
	var pose_offset := Vector3.ZERO
	if indoor_step==2:
		remaining = maxf(0,remaining-delta)
		actor._pose_stand()
		if reading:
			actor.rotation.y = PI
			actor.right_arm.rotation.x = -.95
			actor.left_arm.rotation.x = -.95
			actor._emit_activity("在屋内读%s"%Books.catalog()[job].title)
		elif phoning:
			actor.rotation.y = PI
			actor.right_arm.rotation.x = -1.9
			actor._emit_activity("在床头打电话，请米娅送披萨")
		elif cooking:
			actor.rotation.y = PI
			actor.right_arm.rotation.x = -.89+sin(now*6)*.22
			actor._emit_activity("在厨房煮自己收的青菜" if remaining>5 else "把煮好的青菜装盘")
		elif sleeping:
			actor.rotation.y = 0
			actor.model.rotation.x = -PI/2
			pose_offset = Vector3(0,.73,.33)
			actor._emit_activity("在床上睡觉")
		elif using_toilet:
			actor.rotation.y = 0
			actor.left_leg.rotation.x = -PI/2
			actor.right_leg.rotation.x = -PI/2
			pose_offset.y = .53-.555
			actor._emit_activity("在浴室使用马桶")
		elif washing:
			actor.rotation.y = PI
			actor.right_arm.rotation.x = -.9+sin(now*8)*.12
			actor.left_arm.rotation.x = -.9-sin(now*8)*.12
			actor._emit_activity("在厨房水槽洗手")
		else:
			actor.rotation.y = 0.0 if bathing else (-PI/2 if resting else PI/2)
			actor.left_leg.rotation.x = -PI/2
			actor.right_leg.rotation.x = -PI/2
			pose_offset.y = -.13
			if resting:
				actor._emit_activity("在沙发上歇一会儿")
			elif bathing:
				pose_offset.y = -.04
				actor._emit_activity("在浴缸里泡澡")
			else:
				pose_offset.y = Interior.CHAIR_SEAT_HEIGHT-.555
				actor.right_arm.rotation.x = -.88+sin(now*7)*.13
				if job in WRITING:
					actor._emit_activity("在书桌前写日记" if job=="write_diary" else "在书桌前写自己的书")
				else:
					actor._emit_activity("在书桌前练习画图" if job=="practice_drawing" else "在工作台上画%s"%SKETCHES[job])
		if remaining<=0:
			if not indoor_done:
				_finish_indoor_activity(world,now)
				indoor_done = true
				last_rain_activity = job
				rain_pause_until = now+8.0
			if sheltering and _can_stay_inside(world) and not took_rain_walk and world.needs.energy>=65 and world.needs.satiety>=70:
				took_rain_walk = true
				rain_walk_until = now+60.0
			if sheltering and _can_stay_inside(world) and now<rain_pause_until and not world.needs.wants_toilet():
				actor._emit_activity("在屋里等雨停")
			else:
				actor._pose_stand()
				indoor_step = 3
	else:
		var route := [approach,target,approach,Books.ENTRY]
		var route_index := indoor_step if indoor_step<2 else indoor_step-1
		var current: Vector3 = world.house_interior.to_global(indoor_position)
		var destination: Vector3 = world.house_interior.to_global(route[route_index])
		var direction := destination-current
		if direction.length()>.001: actor.rotation.y = atan2(direction.x,direction.z)
		indoor_position = world.house_interior.to_local(current.move_toward(destination,delta*.85))
		actor.elapsed += delta
		actor._pose_walk()
		actor._emit_activity("在屋内走动" if indoor_step<2 or _can_stay_inside(world) else "走回小院")
		if indoor_position.distance_to(route[route_index])<.01:
			indoor_step += 1
			if indoor_step==2:
				remaining = Books.READ_SECONDS if reading else 20.0
				if resting: remaining = 24.0
				elif washing: remaining = 8.0
				elif bathing: remaining = 28.0
				elif sleeping: remaining = 45.0
				elif using_toilet: remaining = 8.0
				elif cooking: remaining = 25.0
				elif phoning: remaining = 5.0
			elif indoor_step>=4 and _can_stay_inside(world):
				job = ""
				indoor_done = false
				indoor_step = 0
				_choose_rain_activity(world,now)
			elif indoor_step==5:
				_leave_room(world)
				return true
	actor.model.position = actor.to_local(world.house_interior.to_global(indoor_position))+pose_offset
	actor.model.visible = world.house_interior.visible
	return true

func _finish_indoor_activity(world, now: float) -> void:
	if Calendar.is_night(now): last_evening_activity = floorf(now)
	var location := "yard.bookshelf"
	var label := ""
	var event := "book_page_read"
	if Books.catalog().has(job):
		pages_read[job] = int(pages_read.get(job,0))+1
		label = Books.catalog()[job].title
	elif job=="call_pizza":
		world.dining.order(now)
		return
	elif job=="cook_vegetables":
		world.dining.state.prepared = "vegetable"
		return
	elif job==SLEEP:
		world.needs.energy = minf(100,world.needs.energy+42)
		location = "home.bed"
		label = "木床"
		event = SLEEP
	elif job=="rest_sofa":
		world.needs.energy = minf(100,world.needs.energy+22)
		location = "home.sofa"
		label = "小屋沙发"
		event = "sofa_rest"
	elif job in WRITING:
		care_finished[job] = floorf(now)
		if writing_draft.is_empty(): return
		if job=="write_diary":
			writing.append({"kind":job,"seconds":floorf(now),"text":writing_draft.text})
			if writing.size()>48: writing.pop_front()
		else:
			if book.is_empty():
				book = {"title":writing_draft.title,"outline":writing_draft.outline,"chapters":[],"finished":false}
			book.chapters.append({"heading":writing_draft.heading,"text":writing_draft.text})
			book.finished = writing_draft.finished or book.chapters.size()>=64
		writing_draft = {}
		location = "home.workbench"
		label = "书桌"
		event = job
	elif job in CARE+BATHROOM:
		if job=="take_bath": world.needs.finish_bath(now)
		elif job=="use_toilet": world.needs.finish_toilet()
		if job=="practice_drawing": _save_drawing(world,next_drawing%Drawings.TITLES.size(),now)
		care_finished[job] = floorf(now)
		var furniture: Array = {
			"wash_hands":["home.kitchen","厨房水槽"],
			"take_bath":["home.bathroom","浴缸"],
			"use_toilet":["home.bathroom","马桶"],
			"practice_drawing":["home.workbench","书桌"]
		}[job]
		location = furniture[0]
		label = furniture[1]
		event = job
	else:
		drafts.append(job)
		_save_drawing(world,0 if job=="sketch_bench" else 1,now)
		world.house_interior.show_sketch(job)
		location = "home.workbench"
		label = SKETCHES[job]
		event = "design_sketch"
	if world.journal_enabled: world.journal.record(location,label,event,now)

func _save_drawing(world, motif: int, now: float) -> void:
	var item := {"id":next_drawing,"motif":motif,"seconds":floorf(now)}
	if drawings.size()>=Drawings.LIMIT:
		var index := 1 if drawings[0].id==framed else 0
		drawings.remove_at(index)
	drawings.append(item)
	next_drawing += 1
	if framed==0 or _drawing_preference(item)>=_drawing_preference(framed_drawing()):
		framed = item.id
		world.house_interior.show_framed_drawing(item)
		if world.journal_enabled: world.journal.record("home.picture_frame",Drawings.TITLES[motif],"frame_drawing",now)

func _drawing_preference(item: Dictionary) -> int:
	return 0 if item.is_empty() else [5,5,3,6,4,5][int(item.motif)]

func framed_drawing() -> Dictionary:
	for item in drawings:
		if item.id==framed: return item
	return {}

func finish_photo(data: PackedByteArray, now: float) -> bool:
	capturing = false
	if data.is_empty() or data.size()>32000 or (photos.size()>=LIMIT and replace_id==0):
		retry_at = now+60
		return false
	if replace_id>0: photos = photos.filter(func(item): return item.id!=replace_id)
	photos.append({"id":next_id,"title":PHOTO_NAMES[job],"seconds":floorf(now),"jpeg":Marshalls.raw_to_base64(data)})
	next_id += 1
	job = ""
	replace_id = 0
	return true

func queue_writing(action: String, reply: String) -> void:
	if not job.is_empty(): return
	var draft = {"text":reply.strip_edges().left(600)} if action=="write_diary" else JSON.parse_string(reply)
	if not valid_draft(action,draft): return
	if action=="write_book" and not book.is_empty() and (book.finished or draft.title!=book.title or draft.outline!=book.outline): return
	writing_draft = draft
	job = action

static func valid_draft(action: String, draft: Variant) -> bool:
	if not draft is Dictionary or not _writing_text(draft.get("text"),600): return false
	if action=="write_diary": return draft.size()==1
	return action=="write_book" and draft.size()==5 and _writing_text(draft.get("title"),64) and _writing_text(draft.get("outline"),200) and _writing_text(draft.get("heading"),80) and draft.get("finished") is bool

static func _writing_text(value: Variant, limit: int) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length()<=limit

func snapshot() -> Dictionary:
	return {"drawings":drawings.duplicate(true),"next_drawing":next_drawing,"framed":framed,"writing":writing.duplicate(true),"book":book.duplicate(true),"writing_draft":writing_draft.duplicate(true),"last_evening_activity":last_evening_activity,"care_finished":care_finished.duplicate(),"drafts":drafts.duplicate(),"pages_read":pages_read.duplicate(),"photos":photos.duplicate(true),"next_id":next_id,"used":used,"job":"" if indoor_done else job,"replace_id":replace_id}

func restore(state: Dictionary) -> void:
	drawings = state.get("drawings",[]).duplicate(true)
	next_drawing = int(state.get("next_drawing",1))
	framed = int(state.get("framed",0))
	writing = state.get("writing",[]).duplicate(true)
	last_evening_activity = float(state.get("last_evening_activity",-1))
	care_finished = state.get("care_finished",{}).duplicate()
	drafts = state.get("drafts",[]).duplicate()
	pages_read = state.get("pages_read",{}).duplicate()
	photos = state.photos.duplicate(true)
	next_id = int(state.next_id)
	used = int(state.used)
	book = state.get("book",{}).duplicate(true)
	writing_draft = state.get("writing_draft",{}).duplicate(true)
	job = "" if state.job in WRITING and writing_draft.is_empty() else state.job
	if job==Books.LOCAL_EDITION and job not in Books.available(pages_read): job = ""
	replace_id = int(state.replace_id)

static func valid(state: Variant, now: float, harvested: bool) -> bool:
	if not state is Dictionary or not state.get("photos") is Array or state.photos.size()>LIMIT: return false
	for key in ["next_id","used","replace_id"]:
		var value = state.get(key)
		if not Journal.number(value) or value!=floor(value): return false
	if state.next_id<1 or state.used>3 or (not harvested and state.used>0): return false
	var evening = state.get("last_evening_activity",-1)
	if evening!=-1 and (not Journal.number(evening) or evening>now): return false
	var novel = state.get("book",{})
	if not novel is Dictionary: return false
	if not novel.is_empty():
		if not _writing_text(novel.get("title"),64) or not _writing_text(novel.get("outline"),200) or not novel.get("finished") is bool or not novel.get("chapters") is Array or novel.chapters.size() not in range(1,65): return false
		for chapter in novel.chapters:
			if not chapter is Dictionary or not _writing_text(chapter.get("heading"),80) or not _writing_text(chapter.get("text"),600): return false
	var draft = state.get("writing_draft",{})
	if not draft is Dictionary or (not draft.is_empty() and not valid_draft(state.get("job",""),draft)): return false
	var works = state.get("drawings",[])
	var entries = state.get("writing",[])
	var serial = state.get("next_drawing",1)
	var frame = state.get("framed",0)
	if not works is Array or works.size()>Drawings.LIMIT or not entries is Array or entries.size()>48: return false
	if not Journal.number(serial) or serial!=floor(serial) or serial<1 or not Journal.number(frame) or frame!=floor(frame): return false
	var last_id := 0
	var found_frame: bool = frame==0
	for item in works:
		if not item is Dictionary or not Journal.number(item.get("id")) or item.id!=floor(item.id) or item.id<=last_id or item.id>=serial: return false
		if not Journal.number(item.get("motif")) or item.motif!=floor(item.motif) or item.motif>=Drawings.TITLES.size() or not Journal.number(item.get("seconds")) or item.seconds>now: return false
		found_frame = found_frame or item.id==frame
		last_id = int(item.id)
	if not found_frame: return false
	for entry in entries:
		if not entry is Dictionary or entry.get("kind") not in WRITING or not Journal.number(entry.get("seconds")) or entry.seconds>now or not entry.get("text") is String or entry.text.is_empty() or entry.text.length()>600: return false
	var saved_care = state.get("care_finished",{})
	if not saved_care is Dictionary: return false
	for action in saved_care:
		if action not in CARE+BATHROOM+WRITING or not Journal.number(saved_care[action]) or saved_care[action]>now: return false
	var saved_drafts = state.get("drafts",[])
	if not saved_drafts is Array or saved_drafts.size()>SKETCHES.size(): return false
	var seen := {}
	for design in saved_drafts:
		if not SKETCHES.has(design) or seen.has(design): return false
		seen[design] = true
	if seen.has(state.get("job")): return false
	var read_pages = state.get("pages_read",{})
	if not Books.valid(read_pages): return false
	if state.get("job") not in ["","roast_potato","cook_vegetables","call_pizza","photo_harvest","photo_yard","move_plant_bench","move_plant_shade","gift_flower","rest_sofa",SLEEP]+CARE+BATHROOM+WRITING+Feeding.REFILL+Books.available(read_pages)+([Books.LOCAL_EDITION] if not Books.catalog().has(Books.LOCAL_EDITION) else [])+SKETCHES.keys(): return false
	if state.job in ["roast_potato","photo_harvest"] and (not harvested or state.used>=3): return false
	var previous := 0.0
	for item in state.photos:
		if not item is Dictionary or not Journal.number(item.get("id")) or item.id!=floor(item.id) or item.id<=previous or item.id>=state.next_id: return false
		if item.get("title") not in PHOTO_NAMES.values() or not Journal.number(item.get("seconds")) or item.seconds>now or not item.get("jpeg") is String or item.jpeg.length() not in range(4,42669): return false
		if not item.jpeg.begins_with("/9j/"): return false
		previous = item.id
	if state.replace_id>0:
		return state.photos.size()==LIMIT and state.job=="photo_yard" and state.photos.any(func(item): return item.id==state.replace_id)
	return state.photos.size()<LIMIT or not PHOTO_SPOTS.has(state.job)
