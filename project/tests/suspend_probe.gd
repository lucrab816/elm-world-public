extends SceneTree
const Clock = preload("res://life_clock.gd")
var clock = Clock.new()
var simulated := 0.0
var started := 0
func _initialize() -> void:
	call_deferred("_start")
func _start() -> void:
	started = Time.get_ticks_usec()
	clock.consume(started)
	var timer := Timer.new()
	root.add_child(timer)
	timer.wait_time = 0.2
	timer.timeout.connect(func():
		simulated += clock.consume(Time.get_ticks_usec())
		var wall := (Time.get_ticks_usec()-started)/1000000.0
		if wall>=8:
			print(JSON.stringify({"simulated":simulated,"wall":wall,"dropped_gaps":clock.dropped_gaps}))
			quit(0 if clock.dropped_gaps>0 and simulated<wall-4 else 1))
	timer.start()
