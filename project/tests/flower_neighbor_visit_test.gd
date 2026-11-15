extends "res://tests/elm_gardening_test.gd"
const VisitFlower = preload("res://flower_neighbor_visit.gd")
func run() -> void:
	var scene = garden_scene()
	scene.rabbit_enabled = true
	scene.rabbit.adopt(0)
	scene.neighbor_enabled = scene.neighbor.adopt(0)
	check(scene.neighbor_enabled,"Real isolated Mia safely enters yard")
	check(finish_bloom(scene),"Resident independently plants, waters and blooms with Mia living in same yard")
	check(until(scene,func():return scene.flower_neighbor_visit.phase=="looking",2400),"Mia actually walks to the bloomed flower")
	check(scene.neighbor.flat().distance_to(VisitFlower.STAND)<.1 and scene.flower_visual.mia_comment.visible,"At flower, Mia visibly reacts in world")
	check(scene.flower_neighbor_visit.visited_at==-1,"Ongoing visit is not yet counted")
	check(scene._save_now(),"Real shared-world visit progress validates and saves")
	var saved: Dictionary = scene.store.load_state().state
	var resumed = garden_scene()
	resumed.simulation_seconds = saved.simulation_seconds
	resumed.resident.restore(saved.resident)
	resumed.rabbit_enabled = true
	resumed.rabbit.restore(saved.world_state.rabbit,resumed.simulation_seconds)
	resumed.pet_companion.restore(saved.world_state.pet_companion)
	resumed.garden_care.restore(saved.world_state.garden_care)
	resumed.garden_growth.restore(saved.world_state.garden_growth)
	resumed.neighbor_greeting.restore(saved.world_state.neighbor_greeting)
	resumed.mia_rabbit.restore(saved.world_state.mia_rabbit)
	resumed.needs.restore(saved.world_state.basic_life)
	resumed.elm_gardening.restore(saved.world_state.elm_gardening)
	resumed.neighbor_enabled = resumed.neighbor.restore(saved.world_state.neighbor,resumed.simulation_seconds)
	resumed.flower_neighbor_visit.restore(saved.world_state.flower_neighbor_visit)
	resumed.journal.restore(saved.world_state.life_journal,resumed.simulation_seconds)
	check(resumed.neighbor_enabled and until(resumed,func():return resumed.flower_neighbor_visit.phase=="done",10),"Mia resumes remaining observation after restart")
	check(resumed.journal.records.any(func(e):return e.kind=="flower_neighbor_seen") and resumed.neighbor.events.any(func(e):return e.kind=="elm_flower_seen"),"Both world event and Mia retain actual completed visit")
	var completed: float = resumed.flower_neighbor_visit.visited_at
	resumed._advance_simulation(120)
	check(resumed.flower_neighbor_visit.visited_at==completed and resumed.journal.records.filter(func(e):return e.kind=="flower_neighbor_seen")[0].count==1,"Completed visit never replays or creates duplicate history")
	check(resumed._save_now(),"Completed visit and normal NPC life validate together")
	var invalid: Dictionary = resumed.flower_neighbor_visit.snapshot()
	invalid.visited_at = resumed.simulation_seconds+1
	check(not VisitFlower.valid_snapshot(invalid,resumed.simulation_seconds,resumed.neighbor.snapshot(),resumed.elm_gardening.snapshot()),"Reject future visit completion")
	invalid = resumed.flower_neighbor_visit.snapshot()
	check(not VisitFlower.valid_snapshot(invalid,resumed.simulation_seconds,resumed.neighbor.snapshot(),{"stage":0}),"No completed visit to an unbloomed flower")
	check(resumed._chat_context().flower_garden.contains("亲自走到花圃") and resumed.self_arrangement.transport.starts==0,"Chat reports actual visit without any model request")
	print("FLOWER_NEIGHBOR_VISIT_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
