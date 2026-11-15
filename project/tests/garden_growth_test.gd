extends SceneTree
const Store = preload("res://save_store.gd")
const Life = preload("res://basic_life.gd")
const Care = preload("res://garden_care.gd")
const Growth = preload("res://garden_growth.gd")
const Chat = preload("res://chat_panel.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fixture():
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.saving_enabled = true
	scene.journal_enabled = true
	scene.journal.start(0)
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	scene.car.random.seed = 42
	scene.rabbit.random.seed = 25
	scene.rabbit.adopt(0)
	scene.rabbit_enabled = true
	scene.neighbor.random.seed = 13
	scene.neighbor.adopt(0)
	scene.neighbor_enabled = true
	scene.store = Store.new("/tmp/cozy-growth-"+str(OS.get_process_id())+"-"+str(root.get_child_count()))
	scene.state_template = {"world_id":"growth-fixture","simulation_seconds":0,"save_sequence":0,"world_state":{"asset":{"keep":true}},"memories":[{"reserved":"keep"}]}
	return scene
func ready_mia(scene) -> void:
	scene.neighbor._place(Care.EDGE)
	scene.neighbor.place_id = "garden"
	scene.neighbor.mode = "rest"
	scene.neighbor.remaining = 12
	scene.neighbor.route.clear()
	scene.neighbor.destination = ""
	scene.neighbor._sync_obstacle()
	scene.garden_care.cooldown = 0
	scene.neighbor_greeting.cooldown = 120
func run() -> void:
	var growth = Growth.new()
	growth.start(0)
	growth.advance(0,1000,0,0)
	check(growth.stage==0 and growth.growth_seconds==0 and growth.events.is_empty(),"A dry bed with no completed watering cannot grow")
	growth.advance(0,100,0,500)
	check(growth.growth_seconds==0,"A fabricated wet deadline without a completed watering has no effect")
	growth.advance(0,45,1,45)
	growth.advance(45,1000,1,45)
	check(absf(growth.growth_seconds-45)<.00001 and growth.stage==0,"Only the wet portion contributes; dry running time does not")
	growth.advance(1000,1045,1,1045)
	check(growth.stage==1 and growth.events.size()==1 and growth.events[0].stage==1,"A genuine wet threshold produces exactly one leaf-stage event")
	growth.advance(1045,1225,1,1225)
	check(growth.stage==2 and growth.growth_seconds==270 and growth.events.size()==2,"Accumulated wet time reaches the mature seedling stage")
	growth.advance(1225,9999,100,9999)
	check(growth.stage==2 and growth.events.size()==2 and growth.growth_seconds==270,"Mature plants stay bounded without duplicate transitions")
	var scene = fixture()
	scene._update_garden_growth()
	scene._look_at_garden()
	check(scene.garden_close and scene.focus.distance_to(Vector3(-6,.45,.3))<.001 and scene.zoom<5,"Garden close-up focuses the real existing bed")
	scene._reset_camera()
	check(not scene.garden_close and scene.tree_crowns.all(func(c): return c.visible),"Returning to the yard ends garden close-up and restores crowns")
	check(scene.garden_seedlings.size()==3 and scene.garden_seedlings[0].scale.x<.5 and scene.garden_growth_leaves.all(func(x): return not x.visible),"The actual treated bed starts with small sprouts before extra leaves")
	check(Chat.simulated_reply("菜苗长得怎么样",scene._chat_context()).contains("小芽"),"Local chat reports the true growth stage")
	ready_mia(scene)
	scene._advance_simulation(.1)
	check(scene.garden_care.active() and scene.garden_growth.growth_seconds==0,"Starting watering does not immediately credit completed care")
	for i in range(200):
		scene._advance_simulation(.05)
		if not scene.garden_care.active(): break
	check(scene.garden_care.water_count==1 and scene.garden_growth.growth_seconds==0,"Only time after a completed watering is credited")
	scene.neighbor_greeting.cooldown = 120
	scene._advance_simulation(45)
	check(scene.garden_growth.stage==0 and scene.garden_growth.growth_seconds>44,"The seedling grows during actual wet running time")
	check(scene._save_now(),"A partially grown bed saves alongside the world")
	var saved: Dictionary = scene.store.load_state().state
	check(Store.valid_state(saved) and saved.memories==[{"reserved":"keep"}] and saved.world_state.asset.keep,"Partially grown state and unrelated memories validate")
	var fresh = fixture()
	fresh.simulation_seconds = saved.simulation_seconds
	fresh.needs.restore(saved.world_state.basic_life)
	fresh.resident.restore(saved.resident)
	fresh.rabbit.restore(saved.world_state.rabbit,fresh.simulation_seconds)
	fresh.pet_companion.restore(saved.world_state.pet_companion)
	fresh.neighbor.restore(saved.world_state.neighbor,fresh.simulation_seconds)
	fresh.neighbor_greeting.restore(saved.world_state.neighbor_greeting)
	fresh.garden_care.restore(saved.world_state.garden_care)
	fresh.garden_growth.restore(saved.world_state.garden_growth)
	fresh._update_garden_water(fresh.simulation_seconds)
	fresh._update_garden_growth()
	check(absf(fresh.garden_growth.growth_seconds-scene.garden_growth.growth_seconds)<.00001 and fresh.garden_growth.events.is_empty(),"Fresh scene restores exact progress without a new growth event")
	fresh._advance_simulation(50)
	check(fresh.garden_growth.stage==1 and fresh.garden_seedlings[0].scale.x>.7 and fresh.garden_growth.events.size()==1 and fresh.garden_growth_leaves.filter(func(x): return x.visible).size()==6,"A running world visibly grows its first leaves")
	check(Chat.simulated_reply("菜苗长得怎么样",fresh._chat_context()).contains("叶片"),"Local recall reports the visible leaf stage")
	check(fresh._save_now(),"Leaf stage and event save")
	var leaf: Dictionary = fresh.store.load_state().state
	var resumed = fixture()
	resumed.simulation_seconds = leaf.simulation_seconds
	resumed.garden_growth.restore(leaf.world_state.garden_growth)
	resumed._update_garden_growth()
	check(resumed.garden_growth.stage==1 and resumed.garden_growth.events.size()==1 and resumed.garden_seedlings[0].scale.x>.7,"Reopen displays saved growth without replaying a stage")
	var bad: Dictionary = leaf.duplicate(true)
	bad.world_state.garden_growth.stage = 2
	check(not Store.valid_state(bad),"A claimed stage inconsistent with progress is rejected")
	bad = leaf.duplicate(true)
	bad.world_state.garden_growth.events[0].seconds = leaf.simulation_seconds+1
	check(not Store.valid_state(bad),"A future growth event is rejected")
	bad = leaf.duplicate(true)
	bad.world_state.garden_care.water_count = 0
	bad.world_state.garden_care.last_completed_seconds = null
	bad.world_state.garden_care.wet_until = 0
	bad.world_state.garden_care.latest = {}
	bad.world_state.garden_care.next_id = 1
	check(not Store.valid_state(bad),"Progress without any completed watering is rejected")
	bad = leaf.duplicate(true)
	bad.world_state.erase("garden_care")
	check(not Store.valid_state(bad),"An orphaned growth component is rejected")
	var legacy: Dictionary = leaf.duplicate(true)
	legacy.world_state.erase("garden_growth")
	check(Store.valid_state(legacy),"Old saves without the growth component remain valid")
	var migrated = Growth.new()
	migrated.start(leaf.simulation_seconds)
	check(migrated.stage==0 and migrated.growth_seconds==0 and migrated.events.is_empty(),"Migration does not invent past growth stages")
	var frozen: Dictionary = fresh.garden_growth.snapshot()
	var second_reload = Growth.new()
	second_reload.restore(frozen)
	check(second_reload.snapshot()==frozen and second_reload.events.size()==1,"Repeated reload does not backfill time or duplicate the transition")
	# Real autonomous life, run only in this isolated fixture.
	var natural = fixture()
	var saw_leaf := false
	var saw_mature := false
	var watered := false
	var ate := false
	for i in range(36000):
		natural._advance_simulation(.2)
		watered = watered or natural.garden_care.water_count>0
		saw_leaf = saw_leaf or natural.garden_growth.stage>=1
		saw_mature = saw_mature or natural.garden_growth.stage>=2
		ate = ate or natural.needs.meals_finished>0
	check(watered and saw_leaf and saw_mature and ate,"A full local day includes real watering, visible growth and ordinary meals")
	check(natural._save_now() and natural.store.load_state().status=="ok","Full-day growth remains valid and durable")
	for world in [scene,fresh,resumed,natural]: world.saving_enabled = false
	print("GARDEN_GROWTH_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
