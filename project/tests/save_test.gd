extends SceneTree

const Store = preload("res://save_store.gd")
var failures := 0
var checks := 0
var base := "/tmp/cozy-save-test-"+str(OS.get_process_id())

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var actor = scene.resident
	actor.set_process(false)
	for i in range(100):
		actor.advance(0.05)
	check(actor.mode=="move","Fixture should be mid-walk")
	var moving: Dictionary = actor.snapshot()
	for i in range(20):
		actor.advance(0.05)
	check(actor.restore(moving),"Restore walking snapshot")
	check(actor.snapshot()==moving,"Walking position, route and progress round trip exactly")
	actor.advance(0.05)
	check(actor.position.distance_to(Vector3(moving.position[0],actor.position.y,moving.position[1]))<0.06,"No teleport on resumed walk")
	for i in range(2000):
		if actor.mode=="rest":
			break
		actor.advance(0.05)
	actor.advance(3.0)
	var resting: Dictionary = actor.snapshot()
	check(resting.mode=="rest" and resting.remaining<20,"Fixture should be mid-rest")
	check(actor.restore(resting),"Restore resting snapshot")
	check(is_equal_approx(actor.left_leg.rotation.x,-PI/2),"Rest pose restored")
	check(actor.snapshot()==resting,"Rest duration and events unchanged by restore")
	var event_count: int = actor.recent_events.size()
	actor.advance(0.05)
	check(actor.recent_events.size()==event_count,"Restore does not duplicate arrival events")
	var store = Store.new(base)
	check(store.load_state().status=="new","Empty directory starts new")
	var state := {"world_id":"test-world","simulation_seconds":42.0,"save_sequence":0,
		"resident":resting,"world_state":{"furniture":{"object.bed.001":{"state":"future"}}},
		"memories":[{"event_id":"event-1","text":"第一次坐上长椅"}],"future_optional":{"kept":true}}
	for n in range(1,6):
		state.save_sequence = n
		check(store.save_state(state),"Write generation "+str(n))
	var loaded: Dictionary = store.load_state()
	check(loaded.status=="ok" and loaded.state.save_sequence==5,"Read newest generation")
	check(loaded.state.memories==state.memories and loaded.state.future_optional==state.future_optional,"Memories and unknown optional fields retained")
	check(loaded.state.world_state==state.world_state,"World instance state kept separate")
	for n in range(1,4):
		check(store._read("backup%d.json"%n).state.save_sequence==5-n,"Backup chronology "+str(n))
	check(actor.restore(loaded.state.resident),"Restore disk-round-tripped JSON")
	check(actor.recent_events==resting.recent_events,"Disk restore preserves events")
	write_text(base.path_join("world.json"),"broken")
	loaded = store.load_state()
	check(loaded.status=="ok" and loaded.recovered and loaded.state.save_sequence==4,"Corrupt primary uses most recent valid backup")
	state.save_sequence = 6
	check(store.save_state(state),"Can save recovered world")
	check(store._read("backup1.json").status=="ok" and store._read("backup1.json").state.save_sequence==4,"Corrupt primary never replaces a good backup")
	# Valid JSON with an invalid checksum is still corrupt.
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("world.json")))
	envelope.payload_json += " "
	write_text(base.path_join("world.json"),JSON.stringify(envelope))
	check(store.load_state().recovered,"Integrity mismatch recovered from backup")
	write_text(base.path_join("backup1.json"),"broken")
	check(store.load_state().source=="backup2.json","Skips corrupt backup")
	for name in ["world.json","backup1.json","backup2.json","backup3.json"]:
		write_text(base.path_join(name),"broken")
	check(store.load_state().status=="unreadable","All corrupt files block startup")
	check(not store.save_state(state),"Unreadable saves cannot be overwritten")
	check(FileAccess.get_file_as_string(base.path_join("world.json"))=="broken","Blocked save preserves original bytes")
	var future = Store.new(base+"-future")
	DirAccess.make_dir_recursive_absolute(future.directory)
	write_text(future.directory.path_join("world.json"),'{"schema_version":50}')
	check(future.load_state().status=="newer_version","Newer schema blocks downgrade")
	check(not future.save_state(state),"Never write over newer schema")
	check(FileAccess.get_file_as_string(future.directory.path_join("world.json"))=='{"schema_version":50}',"Newer save retained exactly")
	var invalid := state.duplicate(true)
	invalid.resident.position = [900,0]
	check(not Store.valid_state(invalid),"Out-of-bounds actor rejected")
	invalid = state.duplicate(true)
	invalid.resident.remaining = -5
	check(not Store.valid_state(invalid),"Negative rest time rejected")
	var changed_events: Array = actor.recent_events.duplicate()
	actor.catalog.locations["object.bed.001"] = {"position":[-2,-1],"name":"床铺","activities":["sleep"]}
	check(actor.restore(resting) and actor.recent_events==changed_events,"New asset replans activity without wiping recorded events")
	var blocked = Store.new(base+"-not-a-directory")
	write_text(blocked.directory,"occupied")
	check(not blocked.save_state(state),"Unwritable destination reports failure")
	# App-level autosave preserves unrelated data when refreshing actor state.
	scene.store = Store.new(base+"-integration")
	scene.state_template = state.duplicate(true)
	scene.state_template.resident["future_preference"] = "preserved"
	scene.simulation_seconds = 42
	scene.saving_enabled = true
	scene.autosave_elapsed = 59.99
	scene._process(0.02)
	var app_saved: Dictionary = scene.store.load_state()
	check(app_saved.status=="ok","App autosaves at the interval")
	check(app_saved.state.resident.future_preference=="preserved","App save keeps optional resident fields")
	check(app_saved.state.memories==state.memories,"App autosave does not wipe long-term memory data")
	check(app_saved.state.world_state==state.world_state,"App autosave keeps world instance data")
	var interrupted = Store.new(base+"-interrupted")
	DirAccess.make_dir_recursive_absolute(interrupted.directory)
	DirAccess.copy_absolute(scene.store.directory.path_join("world.json"),interrupted.directory.path_join("world.tmp"))
	var interrupted_load: Dictionary = interrupted.load_state()
	check(interrupted_load.status=="ok" and interrupted_load.recovered,"Valid first-save temp can recover after interrupted promotion")
	scene.saving_enabled = false
	print("SAVE_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
