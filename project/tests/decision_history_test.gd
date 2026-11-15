extends SceneTree
const Visit = preload("res://plant_visit.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var v = Visit.new()
	var actor := {"mode":"observe","route":[]}
	var plant := {"phase":"placed","target":"object.bench.001"}
	for i in range(20): v.enqueue("object.bench.001",i*10,true,"这次先继续日常。")
	check(v.history.size()==12 and v.latest.id==20 and v.history[0].id==8,"Keeps a bounded sequence without replacing all earlier choices")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(v.snapshot()))
	check(Visit.valid_snapshot(snapshot,200,actor,plant),"History survives JSON validation")
	var fresh = Visit.new()
	fresh.restore(snapshot)
	check(fresh.history.size()==12 and fresh.history_recall().contains("决定20"),"Restored history can be recalled")
	check(fresh.history_recall().contains("选择继续日常") and not fresh.history_recall().contains("实际看过"),"Declines never become completed visits")
	fresh.clear_statements()
	check(not fresh.latest.has("decision_note") and fresh.history.all(func(r): return not r.has("decision_note")),"Memory corrections clear historical quotations too")
	var bad: Dictionary = snapshot.duplicate(true)
	bad.history[0].phase = "moving"
	check(not Visit.valid_snapshot(bad,200,actor,plant),"Active history is rejected")
	bad = snapshot.duplicate(true)
	bad.history[0].id = 20
	check(not Visit.valid_snapshot(bad,200,actor,plant),"Duplicate or unordered history is rejected")
	var old := {"version":1,"next_id":1,"latest":{}}
	check(Visit.valid_snapshot(old,200,actor,plant),"Old snapshots without history still load")
	fresh.restore(old)
	check(fresh.history.is_empty(),"No past choices invented during migration")
	print("DECISION_HISTORY_TEST_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
