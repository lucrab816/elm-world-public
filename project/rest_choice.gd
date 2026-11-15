extends RefCounted
# Authored environment hints, not an automatic measurement of rendered shadows.
const CANDIDATES := ["object.bench.001","place.tree_shade"]
static func choose(layout: Dictionary, energy: float, sunlight: String, preferred: String = "") -> Dictionary:
	var best := {}
	var best_score := -INF
	for id in CANDIDATES:
		if not layout.locations.has(id):
			continue
		var place: Dictionary = layout.locations[id]
		if not "rest" in place.get("activities",[]):
			continue
		var hints: Dictionary = place.get("comfort",{})
		var shade := clampf(float(hints.get("shade",0)),0,1)
		var seat := bool(hints.get("seat",false))
		var comfort := clampf(float(hints.get("ease",0.5)),0,1)
		var seat_score := (60.0 if energy<35 else 15.0) if seat else 0.0
		var light_score := 45.0*shade if sunlight=="strong" else 0.0
		var experience_score := (10.0 if sunlight=="strong" else 25.0) if energy>=35 and id==preferred else 0.0
		var score := comfort*20+seat_score+light_score+experience_score
		if score<=best_score:
			continue
		best_score = score
		var reason: String
		if seat and energy<35:
			reason = "有些累了，这里有座位，坐着歇脚"
		elif sunlight=="strong" and shade>=0.7:
			reason = "阳光较强，这里的树荫更浓"
		elif seat:
			reason = "阳光柔和，这里有舒服的座位" if sunlight=="gentle" else "这里有座位，可以坐着歇一会儿"
		else:
			reason = "这里可以安静地歇一会儿"
		if experience_score>0:
			reason += "；最近在这里完成休息较多"
		best = {"destination":id,"score":score,"reason":str(place.name)+" · "+reason}
	return best
