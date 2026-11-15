extends SceneTree
const Clock = preload("res://life_clock.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var clock = Clock.new()
	check(clock.consume(1000000)==0,"First frame has no elapsed time")
	check(is_equal_approx(clock.consume(1033333),0.033333),"Foreground time")
	check(is_equal_approx(clock.consume(1233333),0.2),"Background tick keeps same real-time speed")
	check(clock.consume(11233333)==0,"Suspended process does not catch up")
	check(is_equal_approx(clock.consume(11433333),0.2),"Normal tick resumes after long gap")
	check(clock.consume(11633333,true)==0,"Sleep freezes time")
	check(clock.consume(11833333,false,1)==0,"Wake sequence discards elapsed interval")
	check(is_equal_approx(clock.consume(12033333,false,1),0.2),"Time resumes following wake")
	check(clock.consume(1000,false,1)==0,"Backward timer reset ignored")
	clock.reset(5000000)
	check(is_equal_approx(clock.consume(5200000,false,1),0.2),"Manual resume resets clock")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var actor = scene.resident
	actor.set_process(false)
	var initial: Dictionary = actor.snapshot()
	# Equal logical seconds at different tick rates must not freeze or accelerate the world.
	for i in range(300):
		scene._advance_simulation(1.0/30.0)
	var front: Dictionary = actor.snapshot()
	actor.restore(initial)
	for i in range(50):
		scene._advance_simulation(0.2)
	var back: Dictionary = actor.snapshot()
	check(front.mode==back.mode,"Same activity at 30fps and 5Hz")
	check(Vector2(front.position[0],front.position[1]).distance_to(Vector2(back.position[0],back.position[1]))<0.15,"Same movement speed at different tick rates")
	check(absf(front.remaining-back.remaining)<0.15,"Same resting countdown")
	scene._set_background(true)
	check(scene.background_mode and Engine.max_fps==5,"Background polling reduced")
	scene._set_background(false)
	check(not scene.background_mode and Engine.max_fps==30,"Foreground rendering policy restored")
	print("LIFECYCLE_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
