extends RefCounted
# One monotonic clock drives BOTH simulation and autosave in foreground and background.
var previous_us := -1
var previous_wake_sequence := -1
var dropped_gaps := 0

func reset(now_us: int) -> void:
	previous_us = now_us

func consume(now_us: int, sleeping: bool = false, wake_sequence: int = 0) -> float:
	if previous_us<0:
		previous_us = now_us
		previous_wake_sequence = wake_sequence
		return 0
	var elapsed := (now_us-previous_us)/1000000.0
	previous_us = now_us
	if sleeping or wake_sequence!=previous_wake_sequence:
		previous_wake_sequence = wake_sequence
		return 0
	if elapsed<0 or elapsed>2.0:
		dropped_gaps += 1
		return 0 # No burst of offline simulation after sleep or a long process suspension.
	return elapsed
