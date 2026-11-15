extends "res://tests/self_arrangement_test.gd"
const Gardening = preload("res://elm_gardening.gd")
func garden_scene():
	var scene = fixture()
	scene.elm_gardening.start(0)
	scene._create_flower_garden()
	return scene
func until(scene, predicate: Callable, max_seconds: float) -> bool:
	for i in range(int(max_seconds/.05)):
		scene._advance_simulation(.05)
		if predicate.call(): return true
	return false
func advance_to(scene, seconds: float) -> void:
	scene.simulation_seconds = seconds
	scene.needs.ensure_supply(seconds)
	scene._advance_simulation(.05)
func finish_bloom(scene) -> bool:
	if not until(scene,func():return scene.elm_gardening.water_count>0,3000): return false
	var garden = scene.elm_gardening
	advance_to(scene,garden.planted_at+garden.bloom_days*Gardening.Journal.DAY_SECONDS)
	return garden.stage==3
func run() -> void:
	var scene = garden_scene()
	var memories: Array = scene.state_template.memories.duplicate(true)
	check(not scene.elm_gardening.planted and not scene.flower_visual.sprouts.visible,"New patch starts as empty soil, not a backfilled plant")
	check(until(scene,func(): return scene.elm_gardening.phase=="sowing",120),"Idle resident actually walks to patch before sowing")
	check(Vector2(scene.resident.position.x,scene.resident.position.z).distance_to(Gardening.STAND)<.1 and not scene.elm_gardening.planted,"Arrived sowing is still not completed planting")
	check(scene._save_now(),"Sowing action can save atomically")
	var saved: Dictionary = scene.store.load_state().state
	var resumed = garden_scene()
	resumed.simulation_seconds = saved.simulation_seconds
	resumed.resident.restore(saved.resident)
	resumed.needs.restore(saved.world_state.basic_life)
	resumed.journal.restore(saved.world_state.life_journal,resumed.simulation_seconds)
	resumed.elm_gardening.restore(saved.world_state.elm_gardening)
	check(until(resumed,func(): return resumed.elm_gardening.planted,15),"Restored sowing finishes remaining action without duplicate planting")
	check(resumed.journal.records.filter(func(e):return e.kind=="flower_sown").size()==1,"Exactly one planted event after resume")
	check(until(resumed,func(): return resumed.elm_gardening.phase=="watering",180),"Resident returns with a watering can")
	check(resumed.elm_gardening.water_count==0 and resumed.flower_visual.can.visible,"Visible ongoing watering has not counted as complete")
	check(until(resumed,func(): return resumed.elm_gardening.water_count==1,12),"Actual eight-second watering completes")
	check(resumed.elm_gardening.growth<1 and resumed.elm_gardening.stage==0,"Watering does not instantly grow or bloom")
	var garden = resumed.elm_gardening
	var days: int = garden.bloom_days
	check(days>=5 and days<=10,"Planting draws a cycle of five to ten game days")
	garden.restore(garden.snapshot())
	check(garden.bloom_days==days,"Saved bloom cycle is not rerolled")
	resumed._advance_simulation(180)
	check(garden.water_count==1,"A second watering is blocked within the same game day")
	advance_to(resumed,Gardening.Journal.DAY_SECONDS)
	check(until(resumed,func(): return garden.water_count==2,180),"Next game day allows watering again")
	var deadline: float = garden.planted_at+days*Gardening.Journal.DAY_SECONDS
	advance_to(resumed,deadline-1)
	check(garden.stage==2 and resumed.flower_visual.sprouts.visible and not resumed.flower_visual.blooms.visible,"Flower remains in bud just before its deadline")
	advance_to(resumed,deadline)
	check(garden.stage==3 and resumed.flower_visual.blooms.visible,"The chosen bloom date produces visible flowers")
	check(resumed.journal.records.any(func(e):return e.kind=="flower_bloomed") and resumed._chat_context().flower_garden.contains("开花了"),"Actual bloom becomes a truthful journal and chat fact")
	check(resumed._save_now() and resumed.store.load_state().state.memories==memories,"Completed gardening saves and preserves old memory")
	var count: int = resumed.elm_gardening.water_count
	var bloom: Dictionary = resumed.elm_gardening.snapshot()
	resumed.elm_gardening.restore(bloom)
	resumed._advance_simulation(.1)
	check(resumed.elm_gardening.water_count==count and resumed.journal.records.filter(func(e):return e.kind=="flower_bloomed")[0].count==1,"Reopen does not repeat water or bloom completion")
	var interrupted = garden_scene()
	check(until(interrupted,func():return interrupted.elm_gardening.phase=="sowing",120),"Interruption fixture reaches patch")
	interrupted.needs.satiety = 10
	interrupted._advance_simulation(.05)
	check(not interrupted.elm_gardening.active() and not interrupted.elm_gardening.planted,"Hunger interrupts incomplete sowing without credit")
	var driving = garden_scene()
	driving.resident.ride_requested = true
	driving.elm_gardening.next_check = 0
	driving._advance_simulation(.05)
	check(not driving.elm_gardening.active(),"Existing user invitation wins over gardening")
	var dry = garden_scene()
	dry.elm_gardening.planted = true
	dry.elm_gardening.planted_at = 0
	dry.elm_gardening.bloom_days = 5
	dry.elm_gardening.next_check = 1000
	dry.needs.satiety = 20
	dry._advance_simulation(60)
	check(dry.elm_gardening.growth==0,"Dry seed never grows with time alone")
	var watering = garden_scene()
	check(until(watering,func():return watering.elm_gardening.phase=="watering",240),"Interruption fixture starts actual watering")
	watering.resident.ride_requested = true
	watering._advance_simulation(.05)
	check(watering.elm_gardening.water_count==0 and watering.elm_gardening.wet_until==0,"Cancelled partial watering gives no moisture or growth credit")
	var blocked = garden_scene()
	blocked.car.position.x = Gardening.STAND.x
	blocked.car.position.z = Gardening.STAND.y
	blocked.elm_gardening.next_check = 0
	blocked.elm_gardening.advance(blocked,.05,.05)
	check(not blocked.elm_gardening.active() and not blocked.elm_gardening.planted,"Parked car blocking the patch prevents unsafe start")
	var invalid: Dictionary = bloom.duplicate(true)
	invalid.water_count = 0
	check(not Gardening.valid_snapshot(invalid,resumed.simulation_seconds,resumed.resident.snapshot(),{}),"Reject growth without actual watering")
	invalid = bloom.duplicate(true)
	invalid.stage = 1
	check(not Gardening.valid_snapshot(invalid,resumed.simulation_seconds,resumed.resident.snapshot(),{}),"Reject stage that disagrees with growth")
	invalid = bloom.duplicate(true)
	invalid.milestones[0].seconds = resumed.simulation_seconds+1
	check(not Gardening.valid_snapshot(invalid,resumed.simulation_seconds,resumed.resident.snapshot(),{}),"Reject invented future growth history")
	check(scene.self_arrangement.transport.starts==0 and resumed.self_arrangement.transport.starts==0,"Gardening never calls model")
	var before_view: Dictionary = resumed.elm_gardening.snapshot()
	resumed._look_at_flower()
	check(resumed.zoom==6 and resumed.elm_gardening.snapshot()==before_view,"World flower can be inspected without assigning tasks or changing growth")
	print("ELM_GARDENING_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
