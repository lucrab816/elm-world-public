extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# A saved plant visit, executed and recorded by the local world.
const Plan = preload("res://plant_arrangement.gd")
const Journal = preload("res://life_journal.gd")
const WALK_SPEED := 1.05
const LOOK_SECONDS := 4.0
const NOTE_LIMIT := 240
const STANDS := {"object.bench.001":Plan.TREE_APPROACH,"place.tree_shade":Plan.TREE_APPROACH}
const HISTORY_LIMIT := 12
var history: Array = []
var next_id := 1
var latest: Dictionary = {}
func phase() -> String: return str(latest.get("phase",""))
func active() -> bool: return phase() in ["queued","moving","looking"]
func busy() -> bool: return phase() in ["moving","looking"]
static func clean_note(text: String) -> String:
	var clean := text.replace("\r"," ").replace("\n"," ").replace("\t"," ").strip_edges()
	if clean.length()>NOTE_LIMIT: clean = clean.left(NOTE_LIMIT-1)+"…"
	return clean
func enqueue(location: String, now: float, declined: bool = false, note: String = "", source: String = "model_proposal") -> void:
	if not latest.is_empty() and not active():
		history.append(latest.duplicate(true))
		while history.size()>HISTORY_LIMIT: history.pop_front()
	latest = {"id":next_id,"source":source,"phase":"declined" if declined else "queued","location":location,"created_seconds":floorf(now),"updated_seconds":floorf(now),"route":[],"remaining":0.0}
	if not note.is_empty(): latest["decision_note"] = clean_note(note)
	next_id += 1
func status() -> String:
	if latest.is_empty(): return ""
	var labels := {"queued":"已决定去看盆栽，等合适的时候出发","moving":"正走向盆栽","looking":"正在盆栽旁看看","completed":"已经看过盆栽","declined":"这次选择继续当前生活","failed":"这次没有完成看盆栽"}
	return str(labels.get(phase(),""))
func decision_recall() -> String:
	if latest.is_empty(): return "还没有保留过看盆栽的决定。"
	var state := status()
	if not latest.has("decision_note"):
		return state+"；当时表达的话没有保存，无法确定具体理由。"
	return state+"。当时模型表达的想法："+str(latest.decision_note)
func _safe_to_start(world) -> bool:
	return world.resident.mode=="observe" and world.resident.route.is_empty() and not world.resident.user_action.active() and not world.resident.ride_requested and not world.pet_companion.active() and not world.pet_companion.requested and not world.neighbor_greeting.active() and (world.needs==null or (not world.needs.wants_meal() and world.needs.energy>=35))
func advance(world, delta: float, seconds: float) -> bool:
	if not active(): return false
	if world.plant_arrangement.phase!="placed" or world.plant_arrangement.target!=latest.location or world.arranged_plant==null:
		latest.phase = "failed"
		latest.updated_seconds = floorf(seconds)
		latest.route = []
		latest.remaining = 0.0
		return false
	if busy() and not _safe_to_start(world):
		# A new invitation or urgent need takes priority. No arrival is recorded.
		latest.phase = "queued"
		latest.route = []
		latest.remaining = 0.0
		latest.updated_seconds = floorf(seconds)
		world.resident._pose_stand()
		return false
	if phase()=="queued":
		if not _safe_to_start(world): return false
		var start := Vector2(world.resident.position.x,world.resident.position.z)
		var end: Vector2 = STANDS[latest.location]
		var parked := Vector2(world.car.position.x,world.car.position.z)
		var path: PackedVector2Array = world.navigation.path(start,end,.28,parked)
		if path.is_empty() or path[path.size()-1].distance_to(end)>.6 or path[path.size()-1].distance_to(Plan.POSITIONS[latest.location])>1.3: return false
		latest.route = []
		for p in path: latest.route.append([p.x,p.y])
		latest.phase = "moving"
		latest.updated_seconds = floorf(seconds)
		world.resident._emit_activity("走向盆栽，想去看看")
	world.resident.elapsed += delta
	if phase()=="moving":
		var point := Vector2(latest.route[0][0],latest.route[0][1])
		var here := Vector2(world.resident.position.x,world.resident.position.z)
		var direction := point-here
		if direction.length()>.001: world.resident.rotation.y = lerp_angle(world.resident.rotation.y,atan2(direction.x,direction.y),minf(delta*8,1))
		var next := here.move_toward(point,WALK_SPEED*delta)
		world.resident.position.x = next.x
		world.resident.position.z = next.y
		world.resident._sync_height()
		world.resident._walk_pose_step(delta)
		if next.distance_to(point)<.001:
			latest.route.pop_front()
			if latest.route.is_empty():
				latest.phase = "looking"
				latest.remaining = LOOK_SECONDS
				latest.updated_seconds = floorf(seconds)
				world.resident._pose_stand()
				var facing: Vector2 = Plan.POSITIONS[latest.location]-next
				world.resident.rotation.y = atan2(facing.x,facing.y)
				world.resident._emit_activity("在盆栽旁安静地看看")
	else:
		latest.remaining = maxf(0,float(latest.remaining)-delta)
		if latest.remaining<=0:
			latest.phase = "completed"
			latest.updated_seconds = floorf(seconds)
			world.resident.current_location = latest.location
			world.resident.remaining = 2.0
			world.resident._pose_stand()
			world.resident._emit_activity("看过盆栽，继续自己的日常")
			if world.journal_enabled: world.journal.record("object.elm_plant.001","盆栽旁","plant_visit_done",seconds)
	return true
func snapshot() -> Dictionary:
	return {"version":1,"next_id":next_id,"latest":latest.duplicate(true),"history":history.duplicate(true)}
static func valid_snapshot(value: Variant, now: float, actor: Dictionary, plant: Dictionary) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not Journal.number(value.get("next_id")) or value.next_id<1 or value.next_id!=floor(value.next_id) or not value.get("latest") is Dictionary: return false
	var e: Dictionary = value.latest
	var older = value.get("history",[])
	if not older is Array or older.size()>HISTORY_LIMIT: return false
	var previous_id := 0
	for record in older:
		if not record is Dictionary or not Journal.number(record.get("id")) or record.id<=previous_id or record.id>=value.next_id-1 or record.get("phase") not in ["completed","declined","failed"]: return false
		if not valid_snapshot({"version":1,"next_id":record.id+1,"latest":record},now,actor,plant): return false
		if e.is_empty() or record.updated_seconds>e.get("created_seconds",-1): return false
		previous_id = int(record.id)
	if e.is_empty(): return value.next_id==1
	if not Journal.number(e.get("id")) or e.id!=value.next_id-1 or e.id!=floor(e.id) or e.get("source") not in ["model_proposal","local_routine"] or e.get("phase") not in ["queued","moving","looking","completed","declined","failed"]: return false
	if not Plan.POSITIONS.has(e.get("location")) or not Journal.number(e.get("created_seconds")) or not Journal.number(e.get("updated_seconds")) or e.updated_seconds<e.created_seconds or e.updated_seconds>now: return false
	if e.has("decision_note"):
		var note = e.decision_note
		if not note is String or note.strip_edges().is_empty() or note!=clean_note(note) or note.length()>NOTE_LIMIT or "\r" in note or "\n" in note or "\t" in note: return false
	if not e.get("route") is Array or e.route.size()>1000 or not Journal.number(e.get("remaining")) or e.remaining>LOOK_SECONDS: return false
	for p in e.route:
		if not p is Array or p.size()!=2 or not (p[0] is int or p[0] is float) or not (p[1] is int or p[1] is float) or not is_finite(float(p[0])) or not is_finite(float(p[1])) or absf(p[0])>9 or absf(p[1])>9: return false
	if e.phase in ["queued","moving","looking"] and (plant.get("phase")!="placed" or plant.get("target")!=e.location): return false
	if e.phase in ["moving","looking"] and (actor.get("mode")!="observe" or not actor.get("route",[]).is_empty()): return false
	if e.phase=="moving": return not e.route.is_empty() and e.remaining==0
	if e.phase=="looking": return e.route.is_empty() and e.remaining>0
	return e.route.is_empty() and e.remaining==0
func restore(value: Dictionary) -> void:
	next_id = int(value.next_id)
	latest = value.latest.duplicate(true)
	history = value.get("history",[]).duplicate(true)

func clear_statements() -> void:
	latest.erase("decision_note")
	for record in history: record.erase("decision_note")
func history_recall() -> String:
	var records: Array = history.duplicate(true)
	if not latest.is_empty(): records.append(latest)
	if records.is_empty(): return "还没有保留盆栽决定。"
	var lines := PackedStringArray()
	for record in records.slice(maxi(0,records.size()-3)):
		var labels := {"queued":"等待出发","moving":"仍在途中","looking":"正在观察","completed":"实际看过","declined":"选择继续日常","failed":"没有完成"}
		var time := float(record.created_seconds)
		var line := "第%d天 %s · 决定%d · %s"%[Calendar.day_at(time),Journal.clock_text(time),int(record.id),labels[record.phase]]
		line += "；当时表达："+str(record.decision_note) if record.has("decision_note") else "；当时的原话没有保留"
		lines.append(line)
	return "最近保留的%d次决定（最多显示3次）：\n"%records.size()+"\n".join(lines)
