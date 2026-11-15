extends "res://elm_gardening.gd"

var harvested_at := -1.0

func _init() -> void:
	crop_name = "红土豆"

func _cycle_days() -> int:
	return 3

func _new_job(now: float) -> String:
	if harvested_at>=0: return ""
	if stage==3: return "harvest"
	return super._new_job(now)

func _record(world, kind: String, now: float) -> void:
	var event: String = {"flower_sown":"potato_sown","flower_watered":"potato_watered","flower_bloomed":"potato_ripe"}.get(kind,kind)
	if world.journal_enabled: world.journal.record("garden.red_potato","红土豆",event,now)

func _finish_harvest(world, now: float) -> void:
	harvested_at = floorf(now)
	_record(world,"potato_harvested",now)
	world.collect_crop_seeds("potato",now,str(plot_position))

func description() -> String:
	if harvested_at>=0: return "已收下一篮自己种的红土豆，放在材料篮旁。"
	if not planted: return "我选好了菜地，准备种下红土豆种子。"
	return "我种下了红土豆。现在%s，已浇水%d次。"%[["刚播种","发芽了","长出了叶子","成熟了"][stage],water_count]

func snapshot() -> Dictionary:
	var state := super.snapshot()
	state["harvested_at"] = harvested_at
	return state

func restore(state: Dictionary) -> void:
	super.restore(state)
	harvested_at = float(state.harvested_at)

static func valid_crop(state: Variant, now: float, actor: Dictionary, ws: Dictionary, stand: Vector2) -> bool:
	if not valid_snapshot(state,now,actor,ws,stand,true) or not state.enabled: return false
	var harvest = state.get("harvested_at")
	if harvest==-1: return state.job!="harvest" or state.stage==3
	return Journal.number(harvest) and harvest<=now and state.phase=="idle" and state.stage==3 and harvest>=state.milestones.back().seconds
