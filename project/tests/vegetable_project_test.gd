extends "res://tests/elm_gardening_test.gd"
const Crop = preload("res://vegetable_project.gd")

func completed_first_crop():
	var scene = garden_scene()
	scene.rabbit_enabled = true
	scene.rabbit.adopt(0)
	advance_to(scene,23000)
	scene.neighbor_enabled = scene.neighbor.adopt(scene.simulation_seconds)
	scene.flower_neighbor_visit.phase = "done"
	scene.flower_neighbor_visit.visited_at = 1
	var crop = scene.vegetable_project
	crop.start(0)
	crop.seeds_at = 10
	crop.planted = true
	crop.planted_at = 20
	crop.bloom_days = 3
	crop.last_water = 30
	crop.water_count = 1
	crop.wet_until = 180
	crop.growth = 420
	crop.stage = 3
	crop.milestones = [{"stage":1,"seconds":100},{"stage":2,"seconds":200},{"stage":3,"seconds":21620}]
	crop.harvest_at = 21700
	crop.gift_at = 21800
	# Restore the previous release's shape to exercise migration.
	var legacy: Dictionary = crop.snapshot()
	for key in ["cycle","cycle_harvest_at","harvest_count","shared_count","next_sow_at"]: legacy.erase(key)
	crop.restore(legacy)
	var flower: Dictionary = legacy.duplicate(true)
	flower.bloom_days = 5
	scene.elm_gardening.restore(flower)
	scene._create_vegetable_bed()
	return scene

func hide_mia(scene) -> void:
	var mia = scene.neighbor
	mia.mode = "away"
	mia.route.clear()
	mia.destination = ""
	mia._place(mia.ROAD_EDGE)
	mia.visible = false
	mia.home_until = floorf(scene.simulation_seconds)+900
	mia.visit_until = -1
	mia._sync_obstacle()

func mature_and_harvest(scene) -> bool:
	if not until(scene,func():return scene.vegetable_project.water_count>0,1800): return false
	var crop = scene.vegetable_project
	advance_to(scene,crop.planted_at+3*Gardening.Journal.DAY_SECONDS)
	return until(scene,func():return crop.cycle_harvest_at>=0,1800)

func reopen(scene):
	var fresh = fixture()
	fresh._initialize_save(scene.store)
	scene.saving_enabled = false
	check(not fresh.fatal_save_error,"Recurring crop reopens through the normal world loader")
	return fresh

func run() -> void:
	var scene = completed_first_crop()
	var crop = scene.vegetable_project
	check(crop.cycle==1 and crop.harvest_count==1 and crop.shared_count==1,"Old first harvest and gift migrate without inventing extra crops")
	check(scene._save_now(),"Migrated old crop saves")
	check(until(scene,func():return crop.phase=="sowing",300),"Elm walks over to sow the second crop")
	check(crop.cycle==2 and crop.harvest_at==21700 and crop.gift_at==21800,"Replanting retains first harvest and gift timestamps")
	check(scene._save_now(),"Second sowing saves")
	var resumed = reopen(scene)
	crop = resumed.vegetable_project
	check(until(resumed,func():return crop.planted,30),"Second crop resumes incomplete sowing")
	check(mature_and_harvest(resumed),"Second crop grows for three game days and is actually harvested")
	check(crop.harvest_count==2 and resumed.needs.garden_food==1 and not resumed.vegetable_leaves.visible,"One new harvest creates one edible bunch and empties the bed")
	hide_mia(resumed)
	resumed.needs.satiety = 50
	check(until(resumed,func():return resumed.needs.meal_is_garden,900),"Hungry Elm chooses his crop while Mia is away")
	check(resumed.needs.garden_food==0 and resumed.needs.garden_meals_finished==0 and crop.cycle==2,"Meal reserves the crop once and waits for actual eating")
	check(resumed._save_now(),"An unfinished garden meal saves")
	var eating = reopen(resumed)
	var food_before: int = eating.needs.food
	check(until(eating,func():return eating.needs.garden_meals_finished==1,60),"Reopened meal finishes once")
	check(eating.needs.food==food_before and eating.needs.satiety>55,"Eating homegrown greens replenishes hunger without consuming a supplied meal")
	check(eating.journal.records.any(func(e):return e.kind=="vegetable_eaten"),"Finished garden meal produces a truthful journal entry")
	check(until(eating,func():return eating.vegetable_project.cycle==3 and eating.vegetable_project.planted,1800),"After using the crop Elm sows a third batch")
	check(mature_and_harvest(eating),"A third crop also reaches actual harvest")
	crop = eating.vegetable_project
	eating.needs.satiety = 95
	check(until(eating,func():return crop.meeting and eating.elm_crop_gift.visible,2400),"A fed Elm meets visiting Mia with visible greens")
	check(crop.shared_count==1 and eating.needs.garden_food==1,"Unfinished handover keeps its stock and has not counted as sharing")
	check(eating._save_now(),"Repeated crop handover can save")
	var sharing = reopen(eating)
	check(until(sharing,func():return sharing.vegetable_project.shared_count==2,2400),"Reopened meeting actually shares the third harvest")
	crop = sharing.vegetable_project
	check(sharing.needs.garden_food==0 and sharing.needs.garden_meals_finished==1 and crop.harvest_count==3,"Eating and sharing consume separate real harvests")
	check(crop.gift_at==21800 and crop.harvest_at==21700,"Later harvests never overwrite the first crop's story")
	check(sharing._save_now(),"Completed repeated crop cycle saves")
	var final_world = reopen(sharing)
	final_world._advance_simulation(120)
	check(final_world.vegetable_project.shared_count==2 and final_world.needs.garden_meals_finished==1,"Reopen cannot duplicate sharing or completed eating")
	check(final_world.self_arrangement.transport.starts==0 and final_world.chat_panel.transport.starts==0,"Recurring life makes no model requests")
	var bad: Dictionary = final_world.vegetable_project.snapshot()
	bad.harvest_count += 1
	check(not Crop.valid_project(bad,final_world.simulation_seconds,final_world.resident.snapshot(),final_world.state_template.world_state),"Impossible extra harvest is rejected")
	for world in [scene,resumed,eating,sharing,final_world]: world.saving_enabled = false
	print("VEGETABLE_PROJECT_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
