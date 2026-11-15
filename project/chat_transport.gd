extends RefCounted
# Shared local limits for chat and autonomous requests.
const MAX_ATTEMPTS := 5
const WINDOW := 5*3600.0
const COOLDOWN := 120.0
var pid := -1
var directory := ""
var started_ms := 0
var cancel_ms := 0
var stop_reason := "cancelled"
var base := OS.get_user_data_dir().path_join("ai_requests")

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	if FileAccess.get_file_as_bytes(path).size()>32768:
		return null
	var parser := JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(path))==OK else null

# Read-only projection of the same ledger used by reserve(); never refreshes quota.
func budget_status(now: float) -> Dictionary:
	var result := {"code":"ok", "remaining":MAX_ATTEMPTS, "cooldown_seconds":0, "reset_seconds":0, "attempts":[]}
	if not is_finite(now) or now<0:
		result.code = "budget_unreadable"
		return result
	var path := base.path_join("attempts.json")
	if not FileAccess.file_exists(path):
		return result
	var value = _read(path)
	if not value is Array:
		result.code = "budget_unreadable"
		return result
	var previous := -1.0
	for stamp in value:
		if not (stamp is float or stamp is int) or not is_finite(float(stamp)) or stamp<0 or stamp>now or stamp<previous:
			result.code = "budget_unreadable"
			return result
		previous = float(stamp)
		if now-float(stamp)<WINDOW:
			result.attempts.append(stamp)
	result.remaining = maxi(0,MAX_ATTEMPTS-result.attempts.size())
	if not result.attempts.is_empty():
		result.cooldown_seconds = maxi(0,int(ceil(COOLDOWN-(now-float(result.attempts.back())))))
		result.reset_seconds = maxi(0,int(ceil(WINDOW-(now-float(result.attempts.front())))))
	if result.remaining==0:
		result.code = "local_limit"
	elif result.cooldown_seconds>0:
		result.code = "cooldown"
	return result

func configured() -> bool:
	var config = _read("res://bridge/runtime.json")
	return config is Dictionary and config.get("python") is String and config.get("codex") is String and FileAccess.file_exists(config.python) and FileAccess.file_exists(config.codex) and FileAccess.file_exists("res://bridge/chat_worker.py")

func reserve(now: float) -> String:
	var state := budget_status(now)
	if state.code!="ok":
		return state.code
	var attempts: Array = state.attempts
	attempts.append(now)
	var path := base.path_join("attempts.json")
	DirAccess.make_dir_recursive_absolute(base)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		return "budget_unreadable"
	file.store_string(JSON.stringify(attempts))
	file.close()
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:
		return "budget_unreadable"
	return "ok"

func begin(payload: Dictionary, incoming_image: String = "") -> String:
	if pid>0:
		return "busy"
	var config = _read("res://bridge/runtime.json")
	if not configured():
		return "cli_missing"
	var quota := reserve(Time.get_unix_time_from_system())
	if quota!="ok":
		return quota
	directory = base.path_join(str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(directory)
	var input := FileAccess.open(directory.path_join("input.json"),FileAccess.WRITE)
	if input==null:
		return "request_failed"
	input.store_string(JSON.stringify(payload))
	input.close()
	if not incoming_image.is_empty():
		var attachment := FileAccess.open(directory.path_join("attachment.jpg"),FileAccess.WRITE)
		if attachment==null:
			_cleanup()
			return "request_failed"
		attachment.store_buffer(Marshalls.base64_to_raw(incoming_image))
		attachment.close()
	pid = OS.create_process(config.python,[ProjectSettings.globalize_path("res://bridge/chat_worker.py"),"--input",directory.path_join("input.json"),"--output",directory.path_join("output.json"),"--cancel",directory.path_join("cancel"),"--cli",config.codex])
	if pid<=0:
		_cleanup()
		return "request_failed"
	started_ms = Time.get_ticks_msec()
	cancel_ms = 0
	stop_reason = "cancelled"
	return "ok"

func cancel(reason: String = "cancelled") -> void:
	if pid<=0 or cancel_ms>0:
		return
	var flag := FileAccess.open(directory.path_join("cancel"),FileAccess.WRITE)
	if flag!=null:
		flag.store_string("cancel")
		flag.close()
	stop_reason = reason
	cancel_ms = Time.get_ticks_msec()

func poll() -> Dictionary:
	if pid<=0:
		return {}
	if Time.get_ticks_msec()-started_ms>75000:
		cancel("timeout")
	if OS.is_process_running(pid):
		return {}
	var result = _read(directory.path_join("output.json"))
	var cancelled := cancel_ms>0
	pid = -1
	_cleanup()
	if cancelled:
		return {"status":stop_reason}
	return result if result is Dictionary else {"status":"request_failed"}

func _cleanup() -> void:
	if directory.is_empty():
		return
	for name in ["input.json","output.json","output.tmp","cancel","attachment.jpg"]:
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	directory = ""
