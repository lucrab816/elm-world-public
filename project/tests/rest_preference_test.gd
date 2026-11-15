extends SceneTree
const Preference = preload("res://rest_preference.gd")
const Choice = preload("res://rest_choice.gd")
const Life = preload("res://basic_life.gd")
const Store = preload("res://save_store.gd")
const Chat = preload("res://chat_panel.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://world.layout.json"))
	var p = Preference.new()
	check(p.preferred()=="" and p.summary().contains("不足"),"No retroactive preference")
	check(p.chat_context().completed_in_recent_window==0 and p.chat_context().observed_tendency=="尚不确定","Empty context does not claim a preference")
	p.record("place.tree_shade")
	p.record("place.tree_shade")
	check(p.preferred()=="","Two rests are not enough")
	p.record("place.tree_shade")
	check(p.preferred()=="place.tree_shade","Repeated completed rests form a tendency")
	check(p.chat_context().shade_count==3 and p.chat_context().bench_count==0 and p.chat_context().observed_tendency=="树荫","Context describes actual bounded observations")
	check(Choice.choose(layout,90,"gentle").destination=="object.bench.001" and Choice.choose(layout,90,"gentle",p.preferred()).destination=="place.tree_shade","Experience can change a future choice")
	check(Choice.choose(layout,10,"gentle",p.preferred()).destination=="object.bench.001","Low energy still prioritizes the seat")
	check(Choice.choose(layout,90,"strong","object.bench.001").destination=="place.tree_shade","Strong sunlight can outweigh the bench tendency")
	for i in range(8): p.record("object.bench.001")
	check(p.recent.size()==8 and p.preferred()=="object.bench.001","New experiences can change the tendency")
	var snap: Dictionary = p.snapshot()
	var copy = Preference.new()
	copy.restore(snap)
	check(Preference.valid_snapshot(snap) and copy.snapshot()==snap,"Experience survives restoration")
	var bad := snap.duplicate(true)
	bad.recent.append("invented_place")
	check(not Preference.valid_snapshot(bad),"Invalid or overlong experience rejected")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.saving_enabled = true
	scene.journal_enabled = true
	scene.journal.start(0)
	scene.store = Store.new("/tmp/cozy-rest-pref-"+str(OS.get_process_id()))
	scene.state_template = {"world_id":"pref-test","simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[{"keep":true}]}
	scene.needs = Life.new()
	scene.needs.ensure_supply(0)
	scene.resident.needs = scene.needs
	scene.resident.current_location = "place.tree_shade"
	scene.resident.mode = "rest"
	scene.resident.remaining = 1
	scene.resident.advance(.5)
	check(scene.rest_preference.recent.is_empty(),"A rest in progress is not counted")
	check(scene._save_now() and scene.store.load_state().state.world_state.rest_preference.recent.is_empty(),"Mid-rest save has no completion")
	scene.resident.advance(.5)
	check(scene.rest_preference.recent==["place.tree_shade"],"Actual completion records once")
	check(scene._save_now(),"Completed experience is saved")
	check(scene.chat_panel.context_for("你平时喜欢哪里休息").rest_experience.completed_in_recent_window==1,"Actual chat context includes current experience")
	var loaded = scene.store.load_state()
	check(loaded.status=="ok" and loaded.state.memories==[{"keep":true}] and loaded.state.world_state.rest_preference.recent==["place.tree_shade"],"Saved experience and prior memories remain")
	var fresh = Preference.new()
	fresh.restore(loaded.state.world_state.rest_preference)
	check(fresh.recent.size()==1,"Restore does not replay completion")
	check(Chat.simulated_reply("你喜欢在哪里休息",{"rest_preference":p.summary()}).contains("长椅"),"Local reply reflects observed tendency")
	print("REST_PREFERENCE_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
