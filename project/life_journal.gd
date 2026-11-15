extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# Facts from simulation callbacks only. No chat text, LLM summaries or fabricated backfill.
const MAX_RECORDS := 128
const DAY_SECONDS := 7200.0
const RESIDENT_ID := "resident_001"
const ACTIONS := {"patio_chat":"和米娅坐在院里的餐桌旁聊了一会儿","pizza_ordered":"用床头电话叫了披萨","pizza_delivered":"米娅把披萨送到户外餐桌","pizza_eaten":"坐在户外餐桌吃完披萨","write_diary":"在书桌前写了一页日记","write_book":"为自己的书写了一页手稿","frame_drawing":"挑了一幅画装框挂在家里","vegetable_seed_found":"从青菜收成里留下了种子","potato_seed_found":"从红土豆收成里留下了种薯","vegetable_cooked":"在厨房煮了自己收的青菜，吃完一餐","refill_rabbit_hay":"给德雷克添了干草","refill_rabbit_water":"给德雷克添了水","practice_drawing":"坐在小木椅上练习画图","wash_hands":"在厨房水槽洗了手","take_bath":"在屋里泡了澡","use_toilet":"使用了浴室的马桶","sleep_in_bed":"回屋在床上睡了一觉","sofa_rest":"在屋里坐沙发休息","design_sketch":"在工作台画完一张草图","book_page_read":"在屋檐下读完一页","flower_wilted":"这一茬花自然枯萎","flower_gifted":"剪下一朵花送给米娅","plant_moved":"把观赏盆栽搬到新位置","photo_taken":"拍下一张照片","potato_roasted":"烤熟并吃了一个红土豆","potato_sown":"播下 Gemini 送的红土豆种子","potato_watered":"红土豆浇过水","potato_ripe":"红土豆成熟了","potato_harvested":"收下亲手种的红土豆","observe":"看看周围", "rest":"开始休息", "rest_done":"结束休息", "eat":"开始吃饭", "meal_done":"吃完饭", "drive":"开小车兜风", "drive_done":"结束兜风", "pet_started":"开始摸摸德雷克", "pet_done":"陪德雷克待了一会儿", "pet_cancelled":"暂时停下陪伴", "greet_started":"开始向米娅打招呼", "greet_done":"和米娅打了招呼", "greet_cancelled":"暂时停下招呼", "plant_placed":"放好一盆小植物", "plant_visit_done":"看过自己摆放的盆栽","flower_sown":"亲手种下花种","flower_watered":"给自己的花浇过水","flower_bloomed":"亲手照料的花开了","flower_neighbor_seen":"米娅来看埃尔种的花","vegetable_seeds_received":"米娅送来青菜种子，教埃尔播种","vegetable_sown":"在菜地播下青菜种子","vegetable_watered":"给青菜浇水","vegetable_ripe":"埃尔种的青菜成熟了","vegetable_harvested":"收下亲手种的青菜","vegetable_shared":"把亲手种的青菜送给米娅","vegetable_eaten":"吃过自己种的青菜","border_built":"亲手搭好一段菜地木围边","corner_rest_chosen":"特意去林间木凳坐了一会儿","corner_rest_routine":"散步时顺路在林间木凳坐了一会儿","corner_bench_moved":"把木凳搬到树林深处","forest_explore_chosen":"特意深入树林散步后回到小院","corner_built":"完成自己规划的林间休息角的一个阶段"}
var started_seconds := 0.0
var records: Array = []
func start(seconds: float) -> void:
	started_seconds = floorf(seconds)
	records.clear()
static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=1e12
static func valid_snapshot(value: Variant, now: float, calendar_start: float = INF) -> bool:
	if not value is Dictionary or value.get("version")!=1 or value.get("resident_id")!=RESIDENT_ID or not number(value.get("started_seconds")) or value.started_seconds>now:
		return false
	if not value.get("records") is Array or value.records.size()>MAX_RECORDS:
		return false
	var seen := {}
	var previous := -1.0
	for event in value.records:
		if not event is Dictionary or not ACTIONS.has(event.get("kind")):
			return false
		if not event.get("location_id") is String or event.location_id.is_empty() or event.location_id.length()>128 or not event.get("location_name") is String or event.location_name.is_empty() or event.location_name.length()>64:
			return false
		if not number(event.get("first_seconds")) or not number(event.get("last_seconds")) or event.first_seconds<value.started_seconds or event.first_seconds>event.last_seconds or event.last_seconds>now+0.000001 or event.last_seconds<previous:
			return false
		if not number(event.get("day")) or event.day!=floor(event.day) or event.day!=Calendar.day_at(event.first_seconds,calendar_start) or event.day!=Calendar.day_at(event.last_seconds,calendar_start):
			return false
		if not number(event.get("count")) or event.count<1 or event.count>1000000000 or event.count!=floor(event.count):
			return false
		var key: String = str(int(event.day))+":"+event.location_id+":"+event.kind
		if seen.has(key):
			return false
		seen[key] = true
		previous = event.last_seconds
	return true
func restore(value: Dictionary, now: float) -> bool:
	if not valid_snapshot(value,now):
		return false
	started_seconds = float(value.started_seconds)
	records = value.records.duplicate(true)
	return true
func record(location_id: String, location_name: String, kind: String, seconds: float) -> bool:
	if not ACTIONS.has(kind) or location_id.is_empty() or location_id.length()>128 or location_name.is_empty() or location_name.length()>64 or not number(seconds) or seconds<started_seconds:
		return false
	# Whole simulation seconds survive JSON exactly; finer timing has no gameplay meaning.
	seconds = floorf(seconds)
	if not records.is_empty() and seconds<float(records.back().last_seconds):
		return false
	var day := Calendar.day_at(seconds)
	for i in range(records.size()):
		var event: Dictionary = records[i]
		if event.day==day and event.location_id==location_id and event.kind==kind:
			if seconds==float(event.last_seconds):
				return false
			event.last_seconds = seconds
			event.count = mini(int(event.count)+1,1000000000)
			records.remove_at(i)
			records.append(event)
			return true
	records.append({"day":day,"location_id":location_id,"location_name":location_name,"kind":kind,"first_seconds":seconds,"last_seconds":seconds,"count":1})
	while records.size()>MAX_RECORDS:
		records.pop_front()
	return true
func snapshot() -> Dictionary:
	return {"version":1,"resident_id":RESIDENT_ID,"started_seconds":started_seconds,"records":records.duplicate(true)}
func summary(day: int = 0) -> String:
	var selected: Array = []
	for event in records:
		if day==0 or event.day==day:
			selected.append(event)
	var lines: PackedStringArray = []
	for event in selected.slice(maxi(0,selected.size()-5)):
		var time := Calendar.clock_text(event.last_seconds)
		var line := "第%d天 %s · %s · %s"%[int(event.day),time,event.location_name,ACTIONS[event.kind]]
		if event.count>1:
			line += "（共%d次）"%int(event.count)
		lines.append(line)
	return "\n".join(lines) if not lines.is_empty() else ("今天尚无已记录的生活事件。" if day>0 else "记忆刚启用，还没有记录；不会补写过去。")

const GROUPS := {"all":["patio_chat","pizza_ordered","pizza_delivered","pizza_eaten","write_diary","write_book","frame_drawing","vegetable_seed_found","potato_seed_found","vegetable_cooked","refill_rabbit_hay","refill_rabbit_water","practice_drawing","wash_hands","take_bath","use_toilet","sleep_in_bed","sofa_rest","design_sketch","book_page_read","flower_wilted","flower_gifted","plant_moved","photo_taken","potato_roasted","potato_sown","potato_watered","potato_ripe","potato_harvested","forest_explore_chosen","corner_bench_moved","corner_rest_chosen","corner_rest_routine","corner_built","border_built","observe","rest","rest_done","eat","meal_done","drive","drive_done","pet_started","pet_done","pet_cancelled","greet_started","greet_done","greet_cancelled","plant_placed","plant_visit_done","flower_sown","flower_watered","flower_bloomed","flower_neighbor_seen","vegetable_seeds_received","vegetable_sown","vegetable_watered","vegetable_ripe","vegetable_harvested","vegetable_shared","vegetable_eaten"],"observe":["observe"],"rest":["rest","rest_done"],"meal":["eat","meal_done","vegetable_eaten"],"car":["drive","drive_done"],"pet":["pet_started","pet_done","pet_cancelled"],"neighbor":["greet_started","greet_done","greet_cancelled"]}
func entries(day: int = 0, group: String = "all") -> Array:
	var result: Array = []
	if not GROUPS.has(group):
		return result
	for i in range(records.size()-1,-1,-1):
		var event: Dictionary = records[i]
		if (day==0 or int(event.day)==day) and event.kind in GROUPS[group]:
			result.append(event.duplicate(true))
	return result
static func clock_text(seconds: float) -> String:
	return Calendar.clock_text(seconds)
