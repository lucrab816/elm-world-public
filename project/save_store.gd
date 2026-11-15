extends RefCounted

const Calendar = preload("res://world_calendar.gd")

const SCHEMA_VERSION := 49
const FlowerNeighborVisit = preload("res://flower_neighbor_visit.gd")
const VegetableProject = preload("res://vegetable_project.gd")
const ElmGardening = preload("res://elm_gardening.gd")
const LowFrequencyArrangement = preload("res://low_frequency_arrangement.gd")
const SelfArrangement = preload("res://self_arrangement.gd")
const PlantRoutine = preload("res://plant_routine.gd")
const PlantVisit = preload("res://plant_visit.gd")
const PlantArrangement = preload("res://plant_arrangement.gd")
const RestPreference = preload("res://rest_preference.gd")
const ChosenMemories = preload("res://chosen_memories.gd")
const Keepsakes = preload("res://keepsakes.gd")
const MiaRabbit = preload("res://mia_rabbit.gd")
const GardenGrowth = preload("res://garden_growth.gd")
const GardenCare = preload("res://garden_care.gd")
const NeighborGreeting = preload("res://neighbor_greeting.gd")
const Neighbor = preload("res://neighbor.gd")
const PetCompanion = preload("res://pet_companion.gd")
const Rabbit = preload("res://rabbit.gd")
const ActionRequest = preload("res://action_request.gd")
const ExplicitMemory = preload("res://explicit_memory.gd")
const LifeJournal = preload("res://life_journal.gd")
const BasicLife = preload("res://basic_life.gd")
const MAX_BYTES := 5 * 1024 * 1024
const Resident = preload("res://resident.gd")
var directory: String
var writes_blocked := false
var last_error := ""

func _init(base_directory: String = "") -> void:
	directory = base_directory if not base_directory.is_empty() else OS.get_user_data_dir().path_join("saves")

func _path(name: String) -> String:
	return directory.path_join(name)

func _read(name: String) -> Dictionary:
	var path := _path(name)
	if not FileAccess.file_exists(path):
		return {"status":"missing"}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length()>MAX_BYTES:
		return {"status":"invalid"}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error!=OK:
		return {"status":"invalid"}
	var envelope = parser.data
	if not envelope is Dictionary or not envelope.has("schema_version"):
		return {"status":"invalid"}
	if not _number(envelope.schema_version) or envelope.schema_version<1 or envelope.schema_version!=floor(envelope.schema_version):
		return {"status":"invalid"}
	if envelope.schema_version>SCHEMA_VERSION:
		return {"status":"newer_version"}
	if not envelope.get("payload_json") is String or not envelope.get("sha256") is String:
		return {"status":"invalid"}
	if envelope.payload_json.sha256_text()!=envelope.sha256:
		return {"status":"invalid"}
	var payload_parser := JSON.new()
	if payload_parser.parse(envelope.payload_json)!=OK:
		return {"status":"invalid"}
	var state = payload_parser.data
	if not valid_state(state):
		return {"status":"invalid"}
	return {"status":"ok","state":state}

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func valid_state(state: Variant) -> bool:
	if not state is Dictionary:
		return false
	if not state.get("world_id") is String or state.world_id.is_empty() or state.world_id.length()>128:
		return false
	if not _number(state.get("simulation_seconds")) or state.simulation_seconds<0 or state.simulation_seconds>1e12:
		return false
	if not _number(state.get("save_sequence")) or state.save_sequence<0 or state.save_sequence!=floor(state.save_sequence):
		return false
	if not state.get("world_state") is Dictionary or not state.get("memories") is Array:
		return false
	var calendar_start = state.world_state.get("calendar_start",-1)
	if not _number(calendar_start) or calendar_start < -1 or calendar_start!=floor(calendar_start) or calendar_start>ceil(state.simulation_seconds): return false
	var storage = state.world_state.get("window_storage",false)
	if not storage is bool: return false
	var charges = state.world_state.get("watering_can_charges",0)
	if not _number(charges) or charges!=floor(charges) or charges<0 or charges>ElmGardening.CAN_CAPACITY: return false
	var seeds = state.world_state.get("seed_stock",{"vegetable":0,"potato":0})
	if not seeds is Dictionary: return false
	for kind in ["vegetable","potato"]:
		var count = seeds.get(kind)
		if not _number(count) or count!=floor(count) or count<0 or count>12: return false
	if state.world_state.has("outdoor_dining") and not preload("res://outdoor_dining.gd").valid(state.world_state.outdoor_dining): return false
	var seed_letter = state.world_state.get("potato_seed_letter","")
	if not preload("res://mailbox.gd").valid_parcel_id(seed_letter): return false
	if seed_letter!="":
		var mail = state.world_state.get("mailbox",[])
		if not mail is Array or not mail.any(func(letter): return letter is Dictionary and letter.get("id")==seed_letter and letter.get("sender")=="Gemini" and letter.get("read",false)): return false
	if state.world_state.has("mailbox") and not preload("res://mailbox.gd").valid(state.world_state.mailbox): return false
	if state.world_state.has("life_plan") and not preload("res://life_plan.gd").valid(state.world_state.life_plan,float(state.simulation_seconds)): return false
	if state.world_state.has("garden_border") and not preload("res://garden_border.gd").valid(state.world_state.garden_border,float(state.simulation_seconds)): return false
	if state.world_state.has("forest_walk") and not preload("res://forest_walk.gd").valid(state.world_state.forest_walk,float(state.simulation_seconds)): return false
	if state.world_state.has("neighbor") and not Neighbor.valid_snapshot(state.world_state.neighbor,float(state.simulation_seconds)): return false
	if state.world_state.has("rabbit") and not Rabbit.valid_snapshot(state.world_state.rabbit,float(state.simulation_seconds)):
		return false
	if state.world_state.has("explicit_memory") and not ExplicitMemory.valid_snapshot(state.world_state.explicit_memory,float(state.simulation_seconds)):
		return false
	if state.world_state.has("life_journal") and not LifeJournal.valid_snapshot(state.world_state.life_journal,float(state.simulation_seconds),calendar_start):
		return false
	if state.world_state.has("keepsakes") and not Keepsakes.valid_snapshot(state.world_state.keepsakes,float(state.simulation_seconds)):
		return false
	if state.world_state.has("chosen_memories") and not ChosenMemories.valid_snapshot(state.world_state.chosen_memories,float(state.simulation_seconds)):
		return false
	if state.world_state.has("rest_preference") and not RestPreference.valid_snapshot(state.world_state.rest_preference):
		return false
	if state.world_state.has("environment"):
		var environment = state.world_state.environment
		if not environment is Dictionary or environment.get("version")!=1 or environment.get("sunlight") not in ["gentle","strong"]:
			return false
	if not Resident.valid_snapshot(state.get("resident")):
		return false
	if state.world_state.has("plant_arrangement"):
		if not PlantArrangement.valid_snapshot(state.world_state.plant_arrangement,float(state.simulation_seconds),state.resident): return false
	elif state.resident.get("mode")=="arrange_plant": return false
	if state.world_state.has("plant_visit") and not PlantVisit.valid_snapshot(state.world_state.plant_visit,float(state.simulation_seconds),state.resident,state.world_state.get("plant_arrangement",{})): return false
	if state.world_state.has("plant_visit"):
		var manual: Dictionary = state.world_state.plant_visit
		for record in manual.get("history",[])+([manual.latest] if not manual.latest.is_empty() else []):
			if record.source!="model_proposal": return false
	if state.world_state.has("plant_routine"):
		if not PlantRoutine.valid_snapshot(state.world_state.plant_routine,float(state.simulation_seconds),state.resident,state.world_state.get("plant_arrangement",{})): return false
		if state.world_state.plant_routine.execution.latest.get("phase") in ["queued","moving","looking"] and state.world_state.get("plant_visit",{}).get("latest",{}).get("phase") in ["queued","moving","looking"]: return false
	if state.world_state.has("flower_neighbor_visit") and not FlowerNeighborVisit.valid_snapshot(state.world_state.flower_neighbor_visit,float(state.simulation_seconds),state.world_state.get("neighbor",{}),state.world_state.get("elm_gardening",{})): return false
	if state.world_state.get("neighbor",{}).get("mode")=="flower_visit" and state.world_state.get("flower_neighbor_visit",{}).get("phase") not in ["walking","looking"]: return false
	if state.world_state.has("vegetable_project") and not VegetableProject.valid_project(state.world_state.vegetable_project,float(state.simulation_seconds),state.resident,state.world_state): return false
	if state.world_state.has("additional_plots"):
		var extras = state.world_state.additional_plots
		if not extras is Array or extras.size()!=2: return false
		for i in range(2):
			if extras[i].get("plot_index")!=i+1 or not VegetableProject.valid_project(extras[i],float(state.simulation_seconds),state.resident,state.world_state): return false
	var primary_plot: Dictionary = state.world_state.get("vegetable_project",{})
	var all_plots: Array = [primary_plot]+state.world_state.get("additional_plots",[])
	var potato_plots := all_plots.filter(func(plot): return plot.has("red_potato")).size()
	var pending_plot = state.world_state.get("life_plan",{}).get("potato_plot",-1)
	if potato_plots>1 or (pending_plot>=0 and (seed_letter.is_empty() or potato_plots>0 or pending_plot>=all_plots.size())): return false
	if state.world_state.has("elm_hobbies"):
		var harvested := all_plots.any(func(plot): return plot.get("red_potato",{}).get("harvested_at",-1)>=0)
		var hobbies = state.world_state.elm_hobbies
		if not preload("res://elm_hobbies.gd").valid(hobbies,float(state.simulation_seconds),harvested): return false
		if state.world_state.get("mailbox",[]).any(func(letter): return letter.get("photo_id",0)>=hobbies.next_id or letter.get("draft",{}).get("photo_id",0)>=hobbies.next_id): return false
	if state.world_state.has("elm_gardening") and not preload("res://flower_cycle.gd").valid_cycle(state.world_state.elm_gardening,float(state.simulation_seconds),state.resident,state.world_state): return false
	if state.world_state.has("self_arrangement") and not SelfArrangement.valid_snapshot(state.world_state.self_arrangement,float(state.simulation_seconds),state.resident,state.world_state): return false
	if state.world_state.has("low_frequency_arrangement") and not LowFrequencyArrangement.valid_snapshot(state.world_state.low_frequency_arrangement,float(state.simulation_seconds),state.world_state.get("self_arrangement",{})): return false
	if state.resident.has("user_action") and not ActionRequest.valid_snapshot(state.resident.user_action,float(state.simulation_seconds)):
		return false
	if state.world_state.has("pet_companion"):
		if not state.world_state.has("rabbit") or not PetCompanion.valid_snapshot(state.world_state.pet_companion,float(state.simulation_seconds),state.resident,state.world_state.rabbit): return false
	elif state.world_state.get("rabbit",{}).get("mode") in ["greet","petting"]: return false
	if state.world_state.has("neighbor_greeting"):
		if not state.world_state.has("neighbor") or not NeighborGreeting.valid_snapshot(state.world_state.neighbor_greeting,float(state.simulation_seconds),state.resident,state.world_state.neighbor,state.world_state.get("pet_companion",{})): return false
	elif state.world_state.get("neighbor",{}).get("mode")=="greeting": return false
	if state.world_state.has("garden_care"):
		if not state.world_state.has("neighbor") or not GardenCare.valid_snapshot(state.world_state.garden_care,float(state.simulation_seconds),state.world_state.neighbor,state.world_state.get("neighbor_greeting",{})): return false
	elif state.world_state.get("neighbor",{}).get("mode")=="watering": return false
	if state.world_state.has("garden_growth"):
		if not state.world_state.has("garden_care") or not GardenGrowth.valid_snapshot(state.world_state.garden_growth,float(state.simulation_seconds),state.world_state.garden_care): return false
	if state.world_state.has("mia_rabbit"):
		if not state.world_state.has("neighbor") or not state.world_state.has("rabbit") or not MiaRabbit.valid_snapshot(state.world_state.mia_rabbit,float(state.simulation_seconds),state.world_state.neighbor,state.world_state.rabbit,state.world_state.get("pet_companion",{})): return false
	elif state.world_state.get("neighbor",{}).get("mode")=="pet_rabbit" or state.world_state.get("rabbit",{}).get("mode")=="mia_pet": return false
	if state.world_state.has("basic_life"):
		var life = state.world_state.basic_life
		if not BasicLife.valid_snapshot(life):
			return false
		if life.meal_active != (state.get("resident",{}).get("mode")=="eat"):
			return false
		if life.get("last_bath_day",0)>life.last_supply_day or int(life.last_supply_day)!=Calendar.day_at(float(state.simulation_seconds),calendar_start):
			return false
	elif state.get("resident",{}).get("mode")=="eat":
		return false
	return true

func load_state() -> Dictionary:
	writes_blocked = false
	var names := ["world.json","backup1.json","backup2.json","backup3.json","world.tmp"]
	var found_any := false
	for name in names:
		var result := _read(name)
		if result.status=="missing":
			continue
		found_any = true
		if result.status=="newer_version":
			writes_blocked = true
			return {"status":"newer_version"}
		if result.status=="ok":
			result["recovered"] = name!="world.json"
			result["source"] = name
			return result
	if found_any:
		writes_blocked = true
		return {"status":"unreadable"}
	return {"status":"new"}

func save_state(state: Dictionary) -> bool:
	last_error = ""
	if writes_blocked:
		last_error = "现有存档需要处理，已保护原文件。"
		return false
	if not valid_state(state):
		last_error = "当前状态未通过校验，未覆盖存档。"
		return false
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		last_error = "无法创建存档目录。"
		return false
	# Re-check all files before writing: never downgrade a newer save.
	for name in ["world.json","backup1.json","backup2.json","backup3.json","world.tmp"]:
		if _read(name).status=="newer_version":
			writes_blocked = true
			last_error = "发现较新版本存档，请使用更新的程序。"
			return false
	var payload := JSON.stringify(state)
	var text := JSON.stringify({"schema_version":SCHEMA_VERSION,"payload_json":payload,"sha256":payload.sha256_text()},"\t")
	if text.to_utf8_buffer().size()>MAX_BYTES:
		last_error = "存档超出当前版本容量限制，原存档已保留。"
		return false
	var file := FileAccess.open(_path("world.tmp"),FileAccess.WRITE)
	if file==null:
		last_error = "暂时无法写入存档。"
		return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK or _read("world.tmp").status!="ok":
		last_error = "临时存档写入校验失败，原存档已保留。"
		return false
	# Copy only validated generations. Corrupt primary files never replace a valid backup.
	var valid_generations: Array[PackedByteArray] = []
	for name in ["world.json","backup1.json","backup2.json","backup3.json"]:
		if _read(name).status=="ok":
			valid_generations.append(FileAccess.get_file_as_bytes(_path(name)))
		if valid_generations.size()==3:
			break
	for i in range(valid_generations.size()-1,-1,-1):
		var backup_tmp := "backup%d.tmp"%(i+1)
		var backup := FileAccess.open(_path(backup_tmp),FileAccess.WRITE)
		if backup==null:
			last_error = "备份写入失败，未覆盖主存档。"
			return false
		backup.store_buffer(valid_generations[i])
		backup.flush()
		error = backup.get_error()
		backup.close()
		if error!=OK or _read(backup_tmp).status!="ok" or DirAccess.rename_absolute(_path(backup_tmp),_path("backup%d.json"%(i+1)))!=OK:
			last_error = "备份更新失败，未覆盖主存档。"
			return false
	if DirAccess.rename_absolute(_path("world.tmp"),_path("world.json"))!=OK:
		last_error = "保存替换失败，原存档与临时文件已保留。"
		return false
	return true
