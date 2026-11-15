extends RefCounted

const Calendar = preload("res://world_calendar.gd")
# World starts at day 1, 08:00. The calendar sets the supply schedule.
const DAY_SECONDS := 7200.0
const MEAL_AT := 45.0
const REST_AT := 55.0
const DAILY_HEARTS := 10
const DAILY_FOOD := 2
const PANTRY_LIMIT := 12
const BATH_AT := 38.0
const TOILET_AT := 72.0
var cleanliness := 100.0
var toilet_need := 0.0
var last_bath_day := 0
var satiety := 85.0
var energy := 90.0
var hearts := 0
var food := 0
var last_supply_day := 0
var meals_finished := 0
var meal_active := false
var meal_is_basic := false
var garden_food := 0
var garden_by_plot: Array = [0,0,0]
var garden_meal_plot := 0
var garden_meals_finished := 0
var meal_is_garden := false
var last_event := ""

func ensure_supply(seconds: float) -> bool:
	var day := Calendar.day_at(seconds)
	if day<=last_supply_day:
		return false
	# Only current day on first migration; no invented past grants.
	var count := 1 if last_supply_day==0 else day-last_supply_day
	hearts += DAILY_HEARTS*count
	food = mini(PANTRY_LIMIT,food+(DAILY_FOOD if Calendar.anchor>=0 else 4)*count)
	last_supply_day = day
	last_event = "今日钱粮已送到 · 爱心+10，餐食已补充" if count==1 else "运行期间的钱粮已补齐"
	return true

func advance(seconds: float, resting: bool, working: bool = false) -> void:
	var day_length := Calendar.DAY if Calendar.anchor>=0 else Calendar.LEGACY_DAY
	cleanliness = maxf(0,cleanliness-seconds/day_length*(82.0 if working else 68.0))
	toilet_need = minf(100,toilet_need+seconds/day_length*155.0)
	satiety = clampf(satiety-seconds/36.0,0,100)
	energy = clampf(energy+seconds*(0.8 if resting else -1.0/90.0),0,100)

func wants_bath(now: float) -> bool:
	return cleanliness<=BATH_AT and last_bath_day<Calendar.day_at(now)

func wants_toilet() -> bool:
	return toilet_need>=TOILET_AT

func finish_bath(now: float) -> void:
	cleanliness = 100
	last_bath_day = Calendar.day_at(now)

func finish_toilet() -> void:
	toilet_need = 0

func toilet_status() -> String:
	if toilet_need>=90: return "需要尽快"
	if wants_toilet(): return "想上厕所"
	return "舒适"

func wants_meal() -> bool:
	return satiety<=MEAL_AT and not meal_active

func begin_meal(use_garden: bool = true) -> bool:
	if meal_active:
		return false
	meal_active = true
	meal_is_garden = use_garden and garden_food>0
	meal_is_basic = not meal_is_garden and food<=0
	if meal_is_garden:
		garden_food -= 1
		for i in range(garden_by_plot.size()):
			if int(garden_by_plot[i])>0:
				garden_meal_plot = i
				break
		garden_by_plot[garden_meal_plot] = 0
	elif food>0:
		food -= 1
	last_event = "开始吃自己种的青菜" if meal_is_garden else ("开始享用基础餐食" if meal_is_basic else "开始吃一份餐食")
	return true

func finish_meal() -> void:
	if not meal_active:
		return
	if meal_is_garden: garden_meals_finished += 1
	toilet_need = minf(100,toilet_need+4)
	last_event = "吃过自己种的青菜了" if meal_is_garden else "吃过饭了，慢慢继续今天"
	meal_active = false
	meal_is_basic = false
	meal_is_garden = false
	satiety = minf(100,satiety+65)
	energy = minf(100,energy+3)
	meals_finished += 1
	toilet_need = minf(100,toilet_need+4)

func finish_roasted_meal() -> void:
	finish_prepared_meal("烤了红土豆，吃完了一餐")

func finish_prepared_meal(description: String) -> void:
	satiety = minf(100,satiety+65)
	energy = minf(100,energy+3)
	meals_finished += 1
	toilet_need = minf(100,toilet_need+4)
	last_event = description

func snapshot() -> Dictionary:
	return {"version":1,"satiety":satiety,"energy":energy,"cleanliness":cleanliness,"toilet_need":toilet_need,"last_bath_day":last_bath_day,"hearts":hearts,"food":food,
		"last_supply_day":last_supply_day,"meals_finished":meals_finished,
		"meal_active":meal_active,"meal_is_basic":meal_is_basic,"last_event":last_event,
		"garden_by_plot":garden_by_plot.duplicate(),"garden_meal_plot":garden_meal_plot,"garden_food":garden_food,"garden_meals_finished":garden_meals_finished,"meal_is_garden":meal_is_garden}

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1:
		return false
	for key in ["satiety","energy","cleanliness","toilet_need"]:
		var n = value.get(key,{"cleanliness":100,"toilet_need":0}.get(key))
		if not (n is float or n is int) or not is_finite(float(n)) or n<0 or n>100:
			return false
	for key in ["hearts","food","last_supply_day","meals_finished","last_bath_day"]:
		var n = value.get(key,0 if key=="last_bath_day" else null)
		if not (n is float or n is int) or not is_finite(float(n)) or n<0 or n>1e15 or n!=floor(n):
			return false
	for key in ["garden_food","garden_meals_finished"]:
		var n = value.get(key,0)
		if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n!=floor(n) or n>1e15: return false
	if value.get("garden_food",0)>3 or value.get("garden_meals_finished",0)>value.meals_finished: return false
	var plots = value.get("garden_by_plot",[value.get("garden_food",0),0,0])
	if not plots is Array or plots.size()!=3: return false
	var total := 0
	for n in plots:
		if n!=0 and n!=1: return false
		total += int(n)
	if total!=value.get("garden_food",0): return false
	var source = value.get("garden_meal_plot",0)
	if not (source is int or source is float) or source<0 or source>2 or source!=floor(source): return false
	for key in ["meal_active","meal_is_basic"]:
		if not value.get(key) is bool: return false
	if not value.get("meal_is_garden",false) is bool: return false
	if value.get("meal_is_garden",false) and (not value.meal_active or value.meal_is_basic): return false
	return value.food<=PANTRY_LIMIT and value.get("meal_active") is bool and value.get("meal_is_basic") is bool and value.get("last_event") is String and value.last_event.length()<=128

func restore(value: Dictionary) -> bool:
	if not valid_snapshot(value):
		return false
	cleanliness = float(value.get("cleanliness",100))
	toilet_need = float(value.get("toilet_need",0))
	last_bath_day = int(value.get("last_bath_day",0))
	satiety = float(value.satiety)
	energy = float(value.energy)
	hearts = int(value.hearts)
	food = int(value.food)
	last_supply_day = int(value.last_supply_day)
	meals_finished = int(value.meals_finished)
	meal_active = value.meal_active
	meal_is_basic = value.meal_is_basic
	garden_food = int(value.get("garden_food",0))
	garden_by_plot = value.get("garden_by_plot",[garden_food,0,0]).duplicate()
	garden_meal_plot = int(value.get("garden_meal_plot",0))
	garden_meals_finished = int(value.get("garden_meals_finished",0))
	meal_is_garden = value.get("meal_is_garden",false)
	last_event = value.last_event
	return true
