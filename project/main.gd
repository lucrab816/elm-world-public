extends Node3D

const WindowStorage = preload("res://window_storage.gd")

const Calendar = preload("res://world_calendar.gd")
const Weather = preload("res://world_weather.gd")
const YardSurface = preload("res://yard_surface.gd")
var grass_material: StandardMaterial3D

const YardNavigation = preload("res://yard_navigation.gd")
var navigation = YardNavigation.new()
const LittleCar = preload("res://little_car.gd")
const MiaRabbit = preload("res://mia_rabbit.gd")
var mia_rabbit = MiaRabbit.new()
const GardenGrowth = preload("res://garden_growth.gd")
var garden_growth = GardenGrowth.new()
var garden_seedlings: Array[MeshInstance3D] = []
var garden_growth_leaves: Array[MeshInstance3D] = []
var displayed_growth_stage := -1
const GardenCare = preload("res://garden_care.gd")
var garden_care = GardenCare.new()
var garden_soil: MeshInstance3D
var garden_wet := false
const NeighborGreeting = preload("res://neighbor_greeting.gd")
var neighbor_greeting = NeighborGreeting.new()
const Neighbor = preload("res://neighbor.gd")
var neighbor: Node3D
var neighbor_enabled := false
var neighbor_pending := false
var neighbor_retry := 0.0
var neighbor_status: Button
const Rabbit = preload("res://rabbit.gd")
const RabbitFeeding = preload("res://rabbit_feeding.gd")
var rabbit_feeding: Node3D
const RabbitHutch = preload("res://rabbit_hutch.gd")
var rabbit: Node3D
var rabbit_enabled := false
const PetRecall = preload("res://pet_recall.gd")
const PetCompanion = preload("res://pet_companion.gd")
var pet_companion = PetCompanion.new()
var rabbit_status: Label
var car: Node3D
var follow_car := false
var follow_rabbit := false
var follow_neighbor := false
var garden_close := false
var tree_crowns: Array[MeshInstance3D] = []
const ChatPanel = preload("res://chat_panel.gd")
var chat_panel: Control
const JournalPanel = preload("res://journal_panel.gd")
var journal_panel: Control
const ExplicitMemory = preload("res://explicit_memory.gd")
var explicit_memory = ExplicitMemory.new()
const MemoryPanel = preload("res://memory_panel.gd")
var memory_panel: Control
var resident_press := Vector2.ZERO
var resident_click_armed := false
const BasicLife = preload("res://basic_life.gd")
var sunlight := "gentle"
var sky_environment: Environment
var porch_light: OmniLight3D
var porch_glass: StandardMaterial3D
var last_lighting_minute := -1
var weather := "gentle"
var shelter_from_rain := false
var rain: CPUParticles3D
var sun: DirectionalLight3D
var sunlight_button: Button
var rest_reason: Label
var needs: RefCounted
var needs_status: Label
var needs_ui_elapsed := 0.0
const LifeClock = preload("res://life_clock.gd")
var life_clock: RefCounted
var lifecycle_ready := false
var background_mode := false
var native_lifecycle: Dictionary = {}
var native_poll_us := 0
var consumed_quit_sequence := 0
var quit_pending := false
var background_label: Label
const SaveStore = preload("res://save_store.gd")
const LifeJournal = preload("res://life_journal.gd")
var journal = LifeJournal.new()
const Keepsakes = preload("res://keepsakes.gd")
var keepsakes = Keepsakes.new()
const PlantVisit = preload("res://plant_visit.gd")
var plant_visit = PlantVisit.new()
const PlantRoutine = preload("res://plant_routine.gd")
var plant_routine = PlantRoutine.new()
const ElmGardening = preload("res://elm_gardening.gd")
const FlowerVisual = preload("res://flower_visual.gd")
var elm_gardening = preload("res://flower_cycle.gd").new()
const VegetableProject = preload("res://vegetable_project.gd")
var vegetable_project = VegetableProject.new()
const ElmHobbies = preload("res://elm_hobbies.gd")
var hobbies = ElmHobbies.new()
const ElmBooks = preload("res://elm_books.gd")
var book_in_hand: Node3D
var house_interior: Node3D
var bookshelf_dialog: AcceptDialog
var house_exterior: Node3D
var close_cutaway: Button
var flower_in_hand: Node3D
var watering_can: Node3D
var watering_stream: Node3D
var watering_can_charges := 0
var oven_glow: MeshInstance3D
const OutdoorDining = preload("res://outdoor_dining.gd")
var dining: Node3D
var patio_chat = preload("res://patio_chat.gd").new()
var harvest_basket: Node3D
var stored_potatoes: Array[Node3D] = []
var stored_vegetables: Array[Node3D] = []
var seed_stock := {"vegetable":0,"potato":0}
var mailbox_button: Button
var mailbox_visual: Node3D
var mailbox_flag: Node3D
var mailbox_door: Node3D
const Mailbox = preload("res://mailbox.gd")
var mailbox = Mailbox.new()
var deep_bench: Node3D
var carried_bench: Node3D
var life_plan = preload("res://life_plan.gd").new()
var corner_nodes: Array[Node3D] = []
var border = preload("res://garden_border.gd").new()
var border_segments: Array[Node3D] = []
var basket_contents: Array = []
var potato_seed_packet: Node3D
var forest_bundle: Node3D
const ForestLand = preload("res://forest_land.gd")
var forest = preload("res://forest_walk.gd").new()
var vegetable_plots: Array = [vegetable_project]
var plot_meshes: Array = []
var vegetable_bed: Node3D
var vegetable_leaves: Node3D
var vegetable_dialogue: Label3D
var mia_seed_packet: Node3D
var elm_crop_gift: Node3D
const FlowerNeighborVisit = preload("res://flower_neighbor_visit.gd")
var flower_neighbor_visit = FlowerNeighborVisit.new()
var flower_visual: Node3D
const PlantArrangement = preload("res://plant_arrangement.gd")
var plant_arrangement = PlantArrangement.new()
var arranged_plant: Node3D
var plant_button: Button
const RestPreference = preload("res://rest_preference.gd")
var rest_preference = RestPreference.new()
const ChosenMemories = preload("res://chosen_memories.gd")
var chosen_memories = ChosenMemories.new()
var journal_enabled := false
var event_seconds := 0.0
var store: RefCounted
var save_status: Label
var state_template: Dictionary = {}
var simulation_seconds := 0.0
var autosave_elapsed := 0.0
var saving_enabled := false
var fatal_save_error := false
const ResidentScript = preload("res://resident.gd")
var resident_profile: Dictionary
var world_layout: Dictionary
var resident: Node3D
var resident_status: Label
var action_status: Label
var model_decision_ticket: Dictionary = {}
var camera: Camera3D
var focus := Vector3(0, 0.6, 0)
var azimuth := 0.64
var elevation := 0.70
const MIN_ZOOM := 1.8
const MAX_ZOOM := 34.0
const WHEEL_ZOOM_RATIO := 1.13
var zoom := 21.0
var rng := RandomNumberGenerator.new()
var materials := {}
const UiLayout = preload("res://ui_layout.gd")
var ui_layout: Node
var ui_sidebar_body: VBoxContainer
var ui_details: VBoxContainer
var ui_details_toggle: Button
var ui_heading: PanelContainer
var ui_heading_scroll: ScrollContainer
var ui_sidebar_toggle: Button
var build_mode = preload("res://build_mode.gd").new()
var ui_footer: PanelContainer
var ui_footer_help: Label
var ui_layout_queued := false
var ui_layout_dirty := false
var ui_size_picker: OptionButton
const SelfArrangement = preload("res://self_arrangement.gd")
var self_arrangement = SelfArrangement.new()
const LowFrequencyArrangement = preload("res://low_frequency_arrangement.gd")
var low_frequency_arrangement = LowFrequencyArrangement.new()
var low_frequency_toggle: CheckButton
var low_frequency_status: Label
var user_intent_serial := 0
var self_arrangement_button: Button
var self_arrangement_status: Label

func _ready() -> void:
	ElmBooks.load_local()
	get_tree().auto_accept_quit = false
	Engine.max_fps = 30
	ui_layout = UiLayout.new()
	add_child(ui_layout)
	ui_layout.setup()
	rng.seed = 20261025
	resident_profile = JSON.parse_string(FileAccess.get_file_as_string("res://resident.profile.json"))
	world_layout = JSON.parse_string(FileAccess.get_file_as_string("res://world.layout.json"))
	_build_lighting()
	grass_material = YardSurface.grass_material()
	_build_ground()
	_build_forest_trees()
	_build_border()
	_build_material_basket()
	_build_rest_corners()
	_build_mailbox()
	_build_oven()
	_build_house()
	_build_garden()
	var hutch := RabbitHutch.new()
	add_child(hutch)
	hutch.setup(self)
	rabbit_feeding = RabbitFeeding.new()
	add_child(rabbit_feeding)
	rabbit_feeding.setup(self)
	car = LittleCar.new()
	add_child(car)
	car.setup(self)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 150
	add_child(camera)
	_update_camera()
	_build_ui()
	_build_resident()
	_build_book_in_hand()
	forest_bundle = _ball(Vector3(0,-.43,.12),.13,"93734a",resident.left_arm)
	forest_bundle.visible = false
	carried_bench = Node3D.new()
	resident.model.add_child(carried_bench)
	carried_bench.position = Vector3(0,.85,.46)
	_make_forest_bench(carried_bench,.65)
	carried_bench.visible = false
	resident.set_process(false)
	rabbit = Rabbit.new()
	add_child(rabbit)
	rabbit.setup(self)
	neighbor = Neighbor.new()
	add_child(neighbor)
	neighbor.setup(self)
	if "--save-test" in OS.get_cmdline_user_args():
		return
	if not "--resident-test" in OS.get_cmdline_user_args() and not "--smoke-test" in OS.get_cmdline_user_args():
		_initialize_save()
	if not "--resident-test" in OS.get_cmdline_user_args() and not "--smoke-test" in OS.get_cmdline_user_args():
		_prepare_lifecycle()
	print("COZY_WORLD_3D_READY")
	if "--resident-test" in OS.get_cmdline_user_args():
		_test_resident()
		return
	if "--smoke-test" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1).timeout
		_quit()

func _mat(hex: String) -> StandardMaterial3D:
	if materials.has(hex):
		return materials[hex]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = 0.95
	materials[hex] = material
	return material

func _mesh(shape: Mesh, pos: Vector3, color: String, parent: Node3D = self) -> MeshInstance3D:
	var object := MeshInstance3D.new()
	object.mesh = shape
	object.material_override = _mat(color)
	parent.add_child(object)
	object.position = pos
	return object

func _box(pos: Vector3, dimensions: Vector3, color: String, parent: Node3D = self) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = dimensions
	return _mesh(shape, pos, color, parent)

func _ball(pos: Vector3, radius: float, color: String, parent: Node3D = self) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 9
	shape.rings = 4
	return _mesh(shape, pos, color, parent)

func _pole(pos: Vector3, radius: float, height: float, color: String, parent: Node3D = self) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius * 0.86
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 8
	return _mesh(shape, pos, color, parent)

func _show_arranged_plant(target: String) -> void:
	if not PlantArrangement.POSITIONS.has(target): return
	var p: Vector2 = PlantArrangement.POSITIONS[target]
	if arranged_plant!=null:
		if arranged_plant.get_parent()!=self: arranged_plant.reparent(self)
		arranged_plant.position = Vector3(p.x,_height(p.x,p.y),p.y)
		arranged_plant.rotation = Vector3.ZERO
		return
	arranged_plant = Node3D.new()
	if plant_button!=null: plant_button.visible = true
	arranged_plant.name = "ElmArrangedPlant"
	arranged_plant.set_meta("object_id","object.elm_plant.001")
	add_child(arranged_plant)
	arranged_plant.position = Vector3(p.x,_height(p.x,p.y),p.y)
	_pole(Vector3(0,.14,0),.18,.28,"c88969",arranged_plant)
	_pole(Vector3(0,.28,0),.19,.05,"ad6f56",arranged_plant)
	for offset in [Vector3(-.11,.38,0),Vector3(.1,.41,.03),Vector3(0,.48,-.03)]:
		_ball(offset,.12,"84a978",arranged_plant)
	_ball(Vector3(0,.53,0),.065,"e7b5bd",arranged_plant)

func _create_flower_garden() -> void:
	if flower_visual!=null: return
	flower_visual = FlowerVisual.new()
	add_child(flower_visual)
	flower_visual.setup(self)
	flower_in_hand = Node3D.new()
	resident.right_arm.add_child(flower_in_hand)
	flower_in_hand.position = Vector3(0,-.42,.1)
	_pole(Vector3(0,.08,0),.018,.19,"719b62",flower_in_hand)
	for i in range(5):
		var angle := TAU*i/5
		_ball(Vector3(cos(angle)*.055,.20+sin(angle)*.055,0),.042,"e6b6ca",flower_in_hand)
	flower_in_hand.hide()
	watering_can = Node3D.new()
	resident.right_arm.add_child(watering_can)
	watering_can.position = Vector3(0,-.42,.07)
	_pole(Vector3(0,-.05,0),.085,.14,"779c88",watering_can)
	_box(Vector3(0,.041,0),Vector3(.11,.043,.035),"597d68",watering_can)
	var spout := _pole(Vector3(0,-.01,.108),.023,.16,"779c88",watering_can)
	spout.rotation.x = PI*.36
	_ball(Vector3(0,.018,.18),.035,"a4baa0",watering_can)
	watering_stream = Node3D.new()
	watering_can.add_child(watering_stream)
	for i in range(4):
		_ball(Vector3(0,-.12-i*.08,.22+i*.017),.018,"a8d7e1",watering_stream)
	watering_stream.hide()
	watering_can.hide()
	if ElmGardening.POT not in navigation.decorations: navigation.decorations.append(ElmGardening.POT)

func _create_vegetable_bed() -> void:
	vegetable_bed = Node3D.new()
	add_child(vegetable_bed)
	var point: Vector2 = vegetable_plots[plot_meshes.size()].plot_position if not vegetable_plots.is_empty() else VegetableProject.BED
	vegetable_bed.position = Vector3(point.x,_height(point.x,point.y),point.y)
	_box(Vector3(0,.08,0),Vector3(1.18,.16,.55),"8b6952",vegetable_bed)
	var soil := _box(Vector3(0,.17,0),Vector3(1.05,.07,.45),"b48a60",vegetable_bed)
	var furrows := Node3D.new()
	var seeds := Node3D.new()
	var shoots := Node3D.new()
	for layer in [furrows,seeds,shoots]: vegetable_bed.add_child(layer)
	for z in [-.105,.105]:
		for i in range(5):
			var x := -.39+i*.195
			var clod := _box(Vector3(x,.212,z),Vector3(.166,.024,.069),"a07553",furrows)
			clod.rotation.y = sin(i*2.7+z)*.17
			var seed := _ball(Vector3(x,.235,z),.028,"29211a",seeds)
			seed.scale = Vector3(1.26,.52,.82)
			if i%2==0:
				_pole(Vector3(x,.248,z),.012,.085,"759855",shoots)
				for side in [-1,1]:
					var leaf := _ball(Vector3(x+side*.025,.279,z),.036,"a2c76a",shoots)
					leaf.scale = Vector3(1,.36,.70)
					leaf.rotation.z = side*.40
	vegetable_leaves = Node3D.new()
	vegetable_bed.add_child(vegetable_leaves)
	var potato_leaves := Node3D.new()
	vegetable_bed.add_child(potato_leaves)
	for x in [-.34,0,.34]:
		_ball(Vector3(x,.22,0),.12,"548347",potato_leaves)
		_ball(Vector3(x+.06,.18,-.08),.09,"71974a",potato_leaves)
	plot_meshes.append([vegetable_bed,vegetable_leaves,potato_leaves,soil,furrows,seeds,shoots])
	for x in [-.35,0,.35]:
		for z in [-.10,.10]:
			_ball(Vector3(x,.16,z),.14,"6e9d52",vegetable_leaves)
		_ball(Vector3(x,.24,0),.13,"a7c966",vegetable_leaves)
	if vegetable_dialogue!=null: return
	vegetable_dialogue = Label3D.new()
	neighbor.add_child(vegetable_dialogue)
	vegetable_dialogue.position.y = 1.8
	vegetable_dialogue.font_size = 34
	vegetable_dialogue.pixel_size = .006
	vegetable_dialogue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mia_seed_packet = _box(Vector3(0,-.43,.1),Vector3(.17,.20,.06),"e7cf97",neighbor.right_arm)
	elm_crop_gift = _ball(Vector3(0,-.46,.12),.17,"85b456",resident.right_arm)
	_update_vegetable_bed()

func _update_vegetable_bed() -> void:
	if vegetable_bed==null: return
	for i in range(mini(vegetable_plots.size(),plot_meshes.size())):
		var plot = vegetable_plots[i]
		var parts: Array = plot_meshes[i]
		var growing = plot.current_crop()
		var planted: bool = growing.planted and (growing!=plot or plot.cycle_harvest_at<0)
		var stage: int = growing.stage if planted else -1
		var now := maxf(simulation_seconds,event_seconds)
		var watered: bool = stage in [0,1,2] and growing.last_water>=0 and Calendar.day_at(growing.last_water)==Calendar.day_at(now)
		parts[3].material_override = _mat("684831" if watered or shelter_from_rain else "b48a60")
		parts[4].visible = planted
		for clod in parts[4].get_children(): clod.material_override = _mat("563a29" if watered or shelter_from_rain else "99704c")
		parts[5].visible = stage==0
		parts[6].visible = stage==1
		parts[1].visible = stage>=2 and growing==plot
		parts[2].visible = stage>=2 and growing!=plot
		for part in [1,2]:
			parts[part].scale = Vector3.ONE
			parts[part].scale.y = .70 if stage==2 else 1.20
			parts[part].position.y = .06 if stage==2 else .07
	var crop = vegetable_project
	for plot in vegetable_plots:
		if plot.meeting: crop = plot
	vegetable_bed.visible = true
	var talking: bool = crop.meeting and crop.elm_path.is_empty() and crop.mia_path.is_empty()
	vegetable_dialogue.visible = talking
	mia_seed_packet.visible = talking and crop.seeds_at<0
	elm_crop_gift.visible = (talking and crop.cycle_harvest_at>=0) or (resident.mode=="eat" and needs!=null and needs.meal_is_garden)
	if talking: vegetable_dialogue.text = "这包青菜种子给你。种浅一点，每天最多浇一次。" if crop.seeds_at<0 else ("谢谢，这是你种的第一把青菜！" if crop.gift_at<0 else "刚收的青菜真新鲜，谢谢你！")
	if flower_visual!=null:
		for plot in vegetable_plots:
			if plot.current_crop().phase=="watering": flower_visual.can.visible = true
			if plot.current_crop().phase=="sowing": flower_visual.seed_packet.visible = true

func _height(x: float, z: float) -> float:
	return 0.13 * sin(x * 0.45) * cos(z * 0.4) + 0.35 * exp(-((x+6)*(x+6)+(z+4)*(z+4))/18.0)

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	sky_environment = settings
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("e9e9dd")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e9e8df")
	settings.ambient_light_energy = .58
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58,33,0)
	sun.light_color = Color("fff1db")
	sun.light_energy = .36
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 2.8
	add_child(sun)
	rain = CPUParticles3D.new()
	rain.emitting = false
	rain.amount = 160
	rain.lifetime = 1.05
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(13,.15,10)
	rain.direction = Vector3(.15,-1,.08)
	rain.spread = 3
	rain.gravity = Vector3(0,-6,0)
	rain.initial_velocity_min = 7
	rain.initial_velocity_max = 9
	var drop := BoxMesh.new()
	drop.size = Vector3(.023,.34,.023)
	var drop_material := StandardMaterial3D.new()
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.albedo_color = Color("abc4d0")
	drop.material = drop_material
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.mesh = drop
	rain.visibility_aabb = AABB(Vector3(-15,-16,-12),Vector3(30,18,24))
	add_child(rain)

func _build_ground() -> void:
	_box(Vector3(0, -0.65, 0), Vector3(23.7, 1.0, 19.7), "b2a281")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-12, 12):
		for z in range(-10, 10):
			var vertices := [Vector3(x,_height(x,z),z), Vector3(x+1,_height(x+1,z),z), Vector3(x,_height(x,z+1),z+1), Vector3(x+1,_height(x+1,z+1),z+1)]
			for index in [0,1,2,1,3,2]:
				st.set_color(YardSurface.GRASS_COLOR.lightened(rng.randf_range(-0.035,0.035)))
				st.set_uv(Vector2(vertices[index].x,vertices[index].z)/3.4)
				st.add_vertex(vertices[index])
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	terrain.material_override = grass_material
	add_child(terrain)
	_build_yard_plan_markers()

	# The side lane continues to the edge where Mia heads home.
	for i in range(22):
		var x := Neighbor.GATE.x - i*.2
		var z := Neighbor.GATE.y
		_box(Vector3(x,_height(x,z)+.025,z),Vector3(.23,.04,.76),"cbbd93")

func _build_yard_plan_markers() -> void:
	var well := ElmGardening.WELL
	navigation.decorations.append(well)
	var y := _height(well.x,well.y)
	_pole(Vector3(well.x,y+.23,well.y),.56,.46,"918a7c")
	_pole(Vector3(well.x,y+.467,well.y),.43,.025,"7aadb4")
	for i in range(10):
		var a := TAU*i/10
		var rim := _box(Vector3(well.x+cos(a)*.47,y+.48,well.y+sin(a)*.47),Vector3(.16,.13,.29),"a49b8a")
		rim.rotation.y = -a
	var work := Vector2(6.60,5.8)
	_box(Vector3(work.x,_height(work.x,work.y)+.025,work.y),Vector3(2.5,.065,1.56),"b1a590")
	for x in [5.55,6.25,6.95,7.65]:
		_box(Vector3(x,_height(x,6.48)+.085,6.48),Vector3(.60,.17,.22),"99866e")
	var shed := Vector2(-1.95,-4.08)
	y = _height(shed.x,shed.y)
	# Top of the shed sits just below the cottage eave at y=3.02.
	var roof_y := 2.86
	var wall_height := roof_y-y-.08
	_box(Vector3(shed.x,y+wall_height/2,shed.y),Vector3(2.15,wall_height,.92),"aa805c")
	_box(Vector3(shed.x,roof_y,shed.y),Vector3(2.28,.16,1.05),"877967").rotation.x = -.08
	_box(Vector3(shed.x+1.085,y+.68,shed.y),Vector3(.06,1.31,.57),"826247")

func _build_forest_extension() -> void:
	_box(Vector3(-24,-.65,0),Vector3(24,1,20),"b2a281")
	var terrain_rng := RandomNumberGenerator.new()
	terrain_rng.seed = 1891
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-36,-12):
		for z in range(-10,10):
			var corners := [Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z+1)]
			for index in [0,1,2,1,3,2]:
				var point: Vector2 = corners[index]
				surface.set_color(YardSurface.GRASS_COLOR.lightened(terrain_rng.randf_range(-.035,.035)))
				surface.set_uv(point/3.4)
				surface.add_vertex(Vector3(point.x,_height(point.x,point.y),point.y))
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = surface.commit()
	terrain.material_override = grass_material
	add_child(terrain)
	for i in range(1,ForestLand.TRAIL.size()):
		var start: Vector2 = ForestLand.TRAIL[i-1]
		var finish: Vector2 = ForestLand.TRAIL[i]
		var pieces := ceili(start.distance_to(finish)/.35)
		for j in range(pieces+1):
			var point := start.lerp(finish,float(j)/pieces)
			var tile := _box(Vector3(point.x,_height(point.x,point.y)+.025,point.y),Vector3(.46,.04,.8),"cbbd93")
			tile.rotation.y = -(finish-start).angle()
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in range(-34,-13,3):
		for z in range(-8,9,3):
			var point := Vector2(x+terrain_rng.randf_range(-.6,.6),z+terrain_rng.randf_range(-.6,.6))
			var clear := true
			for i in range(1,ForestLand.TRAIL.size()):
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point,ForestLand.TRAIL[i-1],ForestLand.TRAIL[i]))<1.5:
					clear = false
					break
			if not clear or ForestLand.near_drive_loop(point,ForestLand.CLEARING_RADIUS): continue
			var height := _height(point.x,point.y)
			var size := terrain_rng.randf_range(.75,1.25)
			var color: String = ["819c58","74934f","96ad66"][terrain_rng.randi_range(0,2)]
			if ForestLand.BENCH_SITES.values().any(func(site): return point.distance_to(site)<1.65): continue
			_pole(Vector3(point.x,height+.75*size,point.y),.14*size,1.5*size,"80664a")
			_ball(Vector3(point.x,height+1.85*size,point.y),.85*size,color)
	var stone_rng := RandomNumberGenerator.new()
	stone_rng.seed = 7492
	for i in range(24):
		var point := Vector2(stone_rng.randf_range(-34,-13),stone_rng.randf_range(-8,8))
		var near_path := false
		for j in range(1,ForestLand.TRAIL.size()):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,ForestLand.TRAIL[j-1],ForestLand.TRAIL[j]))<1.8:
				near_path = true
				break
		if near_path or ForestLand.near_drive_loop(point,ForestLand.CLEARING_RADIUS) or ForestLand.BENCH_SITES.values().any(func(site): return point.distance_to(site)<1.5): continue
		var stone := _ball(Vector3(point.x,_height(point.x,point.y)+.07,point.y),stone_rng.randf_range(.10,.22),"aaa99a")
		stone.scale = Vector3(1.2,.65,.9)

func _build_forest_trees() -> void:
	_build_forest_extension()

func _build_material_basket() -> void:
	var rack := Node3D.new()
	add_child(rack)
	rack.name = "WindowStorageRack"
	var center := WindowStorage.CENTER
	rack.position = Vector3(center.x,WindowStorage.base_height(self),center.y)
	for z in [-.79,.79]:
		for x in [-.32,.32]:
			_box(Vector3(x,.12,z),Vector3(.08,.24,.08),"946c4c",rack)
	_box(Vector3(0,WindowStorage.SURFACE-.05,0),Vector3(.78,.10,WindowStorage.LENGTH),"b98c62",rack)
	_box(Vector3(-.35,.38,0),Vector3(.08,.18,WindowStorage.LENGTH),"9b744f",rack)
	var basket := _build_window_basket(rack,WindowStorage.MATERIALS)
	potato_seed_packet = _box(Vector3(.16,.238,0),Vector3(.16,.07,.21),"b56b50",basket)
	potato_seed_packet.visible = false
	for kind in ["松果","落枝","小石子"]:
		var items: Array = []
		for i in range(5):
			var x: float = -.18+(i%3)*.16
			var z: float = -.12+["松果","落枝","小石子"].find(kind)*.12
			var item: Node3D
			if kind=="落枝":
				item = _box(Vector3(x,.25+i*.015,z),Vector3(.32,.035,.035),"806344",basket)
				item.rotation.y = i*.4
			else:
				item = _ball(Vector3(x,.20+(i/3)*.09,z),.065,"87613d" if kind=="松果" else "a6aba0",basket)
			items.append(item)
		basket_contents.append(items)
	harvest_basket = _build_window_basket(rack,WindowStorage.HARVEST)
	harvest_basket.name = "SharedHarvestBasket"
	for i in range(3):
		var x := (i-1)*.137
		var tuber := _ball(Vector3(x,.15,-.085),.073,"a94b44",harvest_basket)
		tuber.scale = Vector3(1.1,.74,.94)
		stored_potatoes.append(tuber)
		var leaf := _ball(Vector3(x,.18,.085),.075,"89a968",harvest_basket)
		leaf.scale = Vector3(.85,1.15,.95)
		stored_vegetables.append(leaf)
	navigation.decorations.append_array([Vector2(center.x,-3.18),center,Vector2(center.x,-1.72)])

func _build_window_basket(rack: Node3D, point: Vector2) -> Node3D:
	var basket := Node3D.new()
	rack.add_child(basket)
	basket.position = Vector3(point.x-WindowStorage.CENTER.x,WindowStorage.SURFACE,point.y-WindowStorage.CENTER.y)
	_box(Vector3(0,.047,0),Vector3(.56,.094,.43),"a47d50",basket)
	for x in [-.26,.26]: _box(Vector3(x,.139,0),Vector3(.05,.19,.43),"be9b68",basket)
	for z in [-.20,.20]: _box(Vector3(0,.139,z),Vector3(.56,.19,.05),"be9b68",basket)
	return basket

func _build_oven() -> void:
	var oven := Node3D.new()
	add_child(oven)
	var point := ElmHobbies.OVEN
	oven.position = Vector3(point.x,_height(point.x,point.y),point.y)
	oven.rotation.y = PI/2
	_box(Vector3(0,.14,0),Vector3(.77,.28,.64),"aaa08b",oven)
	_box(Vector3(0,.44,0),Vector3(.68,.42,.57),"af7255",oven)
	_ball(Vector3(0,.63,-.04),.37,"bb7b5e",oven).scale = Vector3(1,.55,.78)
	_box(Vector3(0,.43,.296),Vector3(.35,.25,.025),"513d31",oven)
	oven_glow = _box(Vector3(0,.37,.314),Vector3(.23,.095,.014),"f5a443",oven)
	oven_glow.hide()
	_box(Vector3(.17,.76,-.15),Vector3(.16,.28,.16),"8f6150",oven)
	_box(Vector3(.17,.91,-.15),Vector3(.21,.055,.21),"a26d56",oven)

func _capture_elm_photo(subject: String) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(480,270)
	view.world_3d = get_viewport().world_3d
	add_child(view)
	var lens := Camera3D.new()
	lens.fov = 56
	view.add_child(lens)
	lens.current = true
	var eye := resident.global_position+Vector3(0,1.45,0)
	var target := harvest_basket.global_position+Vector3.UP*.25 if subject=="photo_harvest" else Vector3(-.7,.65,.0)
	lens.global_position = eye+(target-eye).normalized()*.24
	lens.look_at(target)
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	if background_mode:
		RenderingServer.force_draw(false)
	else:
		await RenderingServer.frame_post_draw
	var frame := view.get_texture().get_image()
	var data := PackedByteArray()
	if frame!=null and not frame.is_empty():
		data = frame.save_jpg_to_buffer(.78)
		if data.size()>32000: data = frame.save_jpg_to_buffer(.58)
	view.queue_free()
	if hobbies.finish_photo(data,simulation_seconds):
		journal.record("yard.album","埃尔的相册","photo_taken",simulation_seconds)
		_save_now()

func _open_elm_album() -> void:
	var dialog = preload("res://elm_album.gd").new()
	add_child(dialog)
	dialog.show_album(hobbies)

func _has_potato_harvest() -> bool:
	var crop = _potato_crop()
	return crop!=null and crop.harvested_at>=0

func _open_mailbox() -> void:
	var dialog = preload("res://mailbox_panel.gd").new()
	add_child(dialog)
	dialog.open_inbox(mailbox,func():
		mailbox.advance(self)
		_update_mailbox_flag(),_update_mailbox_button,hobbies.photo)

func _update_mailbox_button() -> void:
	if not is_instance_valid(mailbox_button): return
	var count: int = mailbox.new_reply_count()
	mailbox_button.text = "信箱 · %d 封新回信" % count if count>0 else "信箱"

func _build_mailbox() -> void:
	var box := Node3D.new()
	mailbox_visual = box
	add_child(box)
	var point: Vector2 = Mailbox.LOCATION
	box.position = Vector3(point.x,_height(point.x,point.y),point.y)
	navigation.decorations.append(point)
	var document := GLTFDocument.new()
	var asset := GLTFState.new()
	var result := document.append_from_file("res://assets/elm_mailbox.glb",asset)
	if result!=OK:
		push_error("Unable to load mailbox: "+error_string(result))
		return
	var model := document.generate_scene(asset)
	box.add_child(model)
	mailbox_door = model.find_child("MailboxDoor",true,false)
	mailbox_flag = model.find_child("MailboxFlag",true,false)
	_update_mailbox_flag()

func _update_mailbox_flag() -> void:
	if not is_instance_valid(mailbox_door) or not is_instance_valid(mailbox_flag): return
	var raised: bool = mailbox.has_unread_letters()
	mailbox_flag.rotation.x = 0.0 if raised else PI/2
	mailbox_door.rotation.x = mailbox.door_angle()


func _make_forest_bench(parent: Node3D, size: float = 1) -> void:
	var document := GLTFDocument.new()
	var asset := GLTFState.new()
	var result := document.append_from_file("res://assets/a07_forest_bench.glb",asset)
	if result!=OK:
		push_error("Unable to load A07 forest bench: "+error_string(result))
		return
	var bench := document.generate_scene(asset) as Node3D
	preload("res://patio_wood.gd").paint_tree(bench,["829576","A5AD80"],["D4BF8B","E1D19C"])
	parent.add_child(bench)
	bench.scale = Vector3.ONE*size

func _build_rest_corners() -> void:
	var point: Vector2 = ForestLand.TRAIL.back()
	deep_bench = Node3D.new()
	add_child(deep_bench)
	deep_bench.position = Vector3(point.x,_height(point.x,point.y),point.y)
	_make_forest_bench(deep_bench)
	deep_bench.visible = false
	for id in life_plan.SITES:
		var spot := Node3D.new()
		add_child(spot)
		var p: Vector2 = life_plan.SITES[id]
		spot.position = Vector3(p.x,_height(p.x,p.y),p.y)
		spot.set_meta("site",id)
		var ground := _box(Vector3(0,.01,0),Vector3(1.3,.025,1.2),"b9ad86",spot)
		ground.set_meta("stage",1)
		var stones := Node3D.new()
		spot.add_child(stones)
		stones.set_meta("stage",2)
		for i in range(4): _ball(Vector3((i%2)*.45-.2,.06,(i/2)*.3+.3),.17,"aaa994",stones).scale = Vector3(1,.3,1)
		var bench := Node3D.new()
		spot.add_child(bench)
		bench.set_meta("stage",3)
		_make_forest_bench(bench)
		corner_nodes.append(spot)

func _build_border() -> void:
	for plot in VegetableProject.BEDS:
		var segment := Node3D.new()
		add_child(segment)
		var edge: float = plot.x-.66
		segment.position = Vector3(edge,_height(edge,plot.y),plot.y)
		for z in [-.38,.38]:
			_pole(Vector3(0,.22,z),.045,.44,"99734e",segment)
		_box(Vector3(0,.27,0),Vector3(.07,.08,.76),"b59061",segment)
		segment.visible = false
		border_segments.append(segment)

func _build_house() -> void:
	var cottage := Node3D.new()
	add_child(cottage)
	cottage.position = Vector3(-2.18,.12,-1.5)
	cottage.scale.x = 1.23
	var house := Node3D.new()
	house_exterior = house
	cottage.add_child(house)
	_box(Vector3(0,.20,0),Vector3(4.9,.43,4.25),"807b70",cottage)
	var stones := ["aaa18c","8e8b7e","b4a992","958d7d"]
	for row in range(2):
		for i in range(9):
			_box(Vector3(-2.15+i*.535,.11+row*.21,2.128),Vector3(.517,.194,.066),stones[(i+row*2)%4],cottage)
		for i in range(8):
			_box(Vector3(2.46,.11+row*.21,-1.87+i*.534),Vector3(.067,.194,.514),stones[(i+row+1)%4],cottage)
	_box(Vector3(0,1.65,0),Vector3(4.4,2.45,3.8),"b58a62",house)
	var boards := ["d4aa75","bb8c58","c79b68","dcb581"]
	for i in range(8):
		var y := .56+i*.30
		_box(Vector3(0,y,1.91),Vector3(4.36,.282,.082),boards[i%4],house)
		_box(Vector3(2.21,y,0),Vector3(.079,.282,3.74),boards[(i+2)%4],house)
	for x in [-2.18,2.18]:
		for z in [-1.90,1.90]:
			_box(Vector3(x,1.66,z),Vector3(.18,2.54,.20),"815c3d",house)
	_box(Vector3(0,2.83,1.94),Vector3(4.51,.17,.14),"8d6540",house)
	_house_roof(house,2.57,2.26,2.90,1.20)
	_box(Vector3(0,.86,2.00),Vector3(1.06,1.60,.15),"835b3e",house)
	for i in range(5):
		_box(Vector3(-.38+.19*i,.87,2.09),Vector3(.174,1.45,.072),boards[(i+1)%4],house)
	for y in [.51,1.29]:
		_box(Vector3(-.24,y,2.136),Vector3(.43,.061,.034),"5f5043",house)
	_ball(Vector3(.29,.87,2.16),.057,"6f5840",house)
	_box(Vector3(0,.10,2.53),Vector3(1.57,.20,.72),"b4a895",house)
	_box(Vector3(0,.20,2.28),Vector3(1.37,.23,.55),"a99b85",house)
	var porch := Node3D.new()
	house.add_child(porch)
	porch.position = Vector3(0,1.73,2.18)
	porch.rotation.y = PI/2
	_build_porch_lantern(house)
	_house_roof(porch,.48,.76,.02,.39,false)
	for x in [-.54,.54]:
		var brace := _box(Vector3(x,1.55,2.13),Vector3(.08,.37,.11),"9b6d48",house)
		brace.rotation.z = signf(x)*.46
	_window(Vector3(-1.43,1.66,1.99),house)
	_window(Vector3(1.43,1.66,1.99),house,true)
	var side := Node3D.new()
	house.add_child(side)
	side.position = Vector3(2.26,1.63,-1.02)
	side.rotation.y = PI/2
	_window(Vector3.ZERO,side)
	_stone_chimney(house,stones)
	house_interior = preload("res://elm_interior.gd").new()
	cottage.add_child(house_interior)
	house_interior.position.y = .42
	house_interior.scale = Vector3(.55,1,.67)
	house_interior.setup(self)
	house_interior.hide()

func _build_porch_lantern(house: Node3D) -> void:
	var lantern := Node3D.new()
	lantern.name = "PorchLantern"
	house.add_child(lantern)
	lantern.position = Vector3(.83,2.25,2.19)
	_box(Vector3(0,.44,-.07),Vector3(.055,.07,.28),"644934",lantern)
	_pole(Vector3(0,.31,0),.019,.20,"654735",lantern)
	var glass := _box(Vector3(0,.13,0),Vector3(.16,.21,.15),"d6a464",lantern)
	porch_glass = glass.material_override.duplicate()
	glass.material_override = porch_glass
	porch_glass.emission_enabled = true
	porch_glass.emission = Color("ffc076")
	porch_glass.emission_energy_multiplier = 0
	for y in [.015,.245]:
		_box(Vector3(0,y,0),Vector3(.21,.045,.21),"644934",lantern)
	for x in [-.085,.085]:
		for z in [-.08,.08]:
			_box(Vector3(x,.13,z),Vector3(.025,.22,.025),"765437",lantern)
	porch_light = OmniLight3D.new()
	lantern.add_child(porch_light)
	porch_light.position = Vector3(0,.12,.25)
	porch_light.light_color = Color("ffc688")
	porch_light.light_energy = 1.37
	porch_light.shadow_enabled = true
	porch_light.omni_range = 3.6
	porch_light.omni_attenuation = 1.6
	porch_light.hide()

func _house_roof(parent: Node3D, half_width: float, half_depth: float, eaves: float, rise: float, tiled: bool = true) -> void:
	var peak := eaves+rise
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-half_width,eaves,-half_depth),Vector3(-half_width,peak,0),Vector3(-half_width,eaves,half_depth),Vector3(half_width,eaves,-half_depth),Vector3(half_width,peak,0),Vector3(half_width,eaves,half_depth)]
	for i in [0,1,2,3,5,4]:
		surface.add_vertex(points[i])
	surface.generate_normals()
	_mesh(surface.commit(),Vector3.ZERO,"a88055",parent).material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	var slope := atan(rise/half_depth)
	var length := Vector2(half_depth,rise).length()
	var slate := ["788754","879365","738351","929b6c"]
	for side in [-1,1]:
		var board := _box(Vector3(0,(eaves+peak)*.5,side*half_depth*.5),Vector3(half_width*2,.12,length),"647247",parent)
		board.rotation.x = side*slope
		for x in [-half_width,half_width]:
			var edge := _box(Vector3(x,(eaves+peak)*.5+.08,side*half_depth*.5),Vector3(.14,.15,length+.10),"a8774d",parent)
			edge.rotation.x = side*slope
		if not tiled: continue
		for row in range(5):
			var t := (row+.53)/5
			for col in range(9):
				var x := -half_width+(col+.5)*half_width*2/9
				var shingle := _box(Vector3(x,peak-rise*t+.085,side*half_depth*t),Vector3(half_width*2/9-.022,.058,length/5-.018),slate[(col*3+row*7+(col+row)%3)%4],parent)
				shingle.rotation.x = side*slope
	_box(Vector3(0,peak+.09,0),Vector3(half_width*2+.13,.14,.18),"a8774d",parent)

func _stone_chimney(house: Node3D, stones: Array) -> void:
	var x := 2.39
	var z := .46
	_box(Vector3(x,.28,z),Vector3(.82,.56,.77),"857b6d",house)
	_box(Vector3(x,2.38,z),Vector3(.57,4.38,.53),"8e8a7f",house)
	for row in range(14):
		var y := .52+row*.278
		var offset := .035 if row%2==0 else -.035
		for i in range(2):
			_box(Vector3(x+.292,y,z-.133+i*.27+offset),Vector3(.034,.25,.25),stones[(row+i)%4],house)
			_box(Vector3(x-.144+i*.29+offset,y,z+.27),Vector3(.267,.25,.032),stones[(row+i+1)%4],house)
	_box(Vector3(x,4.49,z),Vector3(.72,.15,.70),"aaa394",house)
	for dx in [-.25,.25]:
		for dz in [-.23,.23]:
			_box(Vector3(x+dx,4.67,z+dz),Vector3(.075,.24,.075),"886c4e",house)
	var cap := _pole(Vector3(x,4.82,z),.43,.13,"76786f",house)
	cap.scale = Vector3(1,1,.9)
	_ball(Vector3(x,4.95,z),.082,"9c7951",house)

func _build_book_in_hand() -> void:
	book_in_hand = Node3D.new()
	resident.right_arm.add_child(book_in_hand)
	book_in_hand.position = Vector3(.11,-.44,.09)
	_box(Vector3.ZERO,Vector3(.33,.041,.22),"6d899a",book_in_hand)
	for x in [-.077,.077]:
		_box(Vector3(x,.031,0),Vector3(.146,.029,.20),"f4e3b7",book_in_hand)
	book_in_hand.hide()

func _window(pos: Vector3, parent: Node3D, lavender: bool = false) -> void:
	_box(pos,Vector3(0.82,1.0,0.11),"726a51",parent)
	_box(pos+Vector3(0,0,0.065),Vector3(0.63,0.79,0.035),"a9c7bd",parent)
	_box(pos+Vector3(0,0,0.095),Vector3(0.06,0.83,0.04),"eddfb9",parent)
	_box(pos+Vector3(0,0,0.10),Vector3(0.66,0.06,0.04),"eddfb9",parent)
	for x in [-0.53,0.53]:
		_box(pos+Vector3(x,0,0),Vector3(0.22,0.95,0.1),"758b64",parent)
	_box(pos+Vector3(0,-0.61,0.12),Vector3(1.04,0.2,0.36),"a68161",parent)
	for x in [-0.33,-0.1,0.16,0.36]:
		_ball(pos+Vector3(x,-0.43,0.15),0.14,"8a9d5d",parent)
		if lavender:
			_pole(pos+Vector3(x,-.30,.21),.018,.32,"6d8560",parent)
			_ball(pos+Vector3(x,-.15-absf(x)*.22,.21),.060,"9a7ca7",parent).scale.y = 1.6
		else:
			_ball(pos+Vector3(x,-0.32,0.17),0.075,"e9bc93",parent)

func _tree(x: float, z: float, scale_factor: float) -> void:
	var tree := Node3D.new()
	add_child(tree)
	tree.position = Vector3(x,_height(x,z),z)
	tree.scale = Vector3.ONE * scale_factor
	_pole(Vector3(0,1.15,0),0.16,2.3,"8b7356",tree)
	for entry in [Vector3(0,2.65,0),Vector3(-0.65,2.15,0.12),Vector3(0.6,2.3,0.25),Vector3(0.1,2.2,-0.6)]:
		var crown := _ball(entry,1.08,["79945b","88a366","9baf71"][rng.randi_range(0,2)],tree)
		crown.scale = Vector3(1,1.12,1)
		tree_crowns.append(crown)

func _build_garden() -> void:
	for point in [Vector3(-7,-5,1.35),Vector3(-8,1,1.0),Vector3(5,-6,1.25),Vector3(8,-1,1.0),Vector3(4,7,0.85),Vector3(-8.6,7.2,0.85),Vector3(-1,-7,0.85)]:
		_tree(point.x,point.y,point.z)
	# Split-rail fence around the back and left edge of the garden.
	for i in range(7):
		var x := 1.0+i*1.25
		_pole(Vector3(x,_height(x,-7.5)+0.53,-7.5),0.075,1.05,"d7c49c")
		if i<6:
			for y in [0.35,0.75]:
				_box(Vector3(x+0.625,_height(x,-7.5)+y,-7.5),Vector3(1.3,0.09,0.08),"d7c49c")
	for i in range(10):
		var z := -7.5+i*1.25
		_pole(Vector3(-8.5,_height(-8.5,z)+0.53,z),0.075,1.05,"d7c49c")
		if i<9:
			for y in [0.35,0.75]:
				_box(Vector3(-8.5,_height(-8.5,z)+y,z+0.625),Vector3(0.08,0.09,1.3),"d7c49c")
	for i in range(5):
		var z := -7.5+i*1.25
		_pole(Vector3(8.5,_height(8.5,z)+.53,z),.075,1.05,"d7c49c")
		if i<4:
			for y in [.35,.75]: _box(Vector3(8.5,_height(8.5,z)+y,z+.625),Vector3(.08,.09,1.3),"d7c49c")
	# Preserve the location identifier used by existing saves.
	var bench := Node3D.new()
	bench.name = "object.bench.001"
	add_child(bench)
	var bench_point: Array = world_layout.locations["object.bench.001"].position
	bench.position = Vector3(float(bench_point[0]),0,float(bench_point[1]))
	for z in [-0.23,0,0.23]:
		_box(Vector3(0,0.52,z),Vector3(1.9,0.09,0.19),"b6956b",bench)
	for x in [-0.7,0.7]:
		_box(Vector3(x,0.25,0),Vector3(0.12,0.5,0.65),"6c7560",bench)
		_box(Vector3(x,0.78,-0.28),Vector3(0.1,1,0.1),"6c7560",bench)
	for y in [0.85,1.1]:
		_box(Vector3(0,y,-0.28),Vector3(1.9,0.17,0.09),"b6956b",bench)
	bench.hide()
	dining = OutdoorDining.new()
	add_child(dining)
	dining.setup(self)
	add_child(build_mode)
	build_mode.setup(self)
	# Flower beds, grass tufts and small stones.
	for i in range(65):
		var x := rng.randf_range(-10,10)
		var z := rng.randf_range(-8.5,8.5)
		if (x>1.4 and x<7 and z>3.3 and z<6.5) or (x>-5.4 and x<0.6 and z>-4.4 and z<2.0) or abs(x-(0.5+sin(z*0.45)*0.9))<1.1:
			continue
		# Keep the open yard drivable; decorative clusters stay near fixed obstacles.
		if navigation.near_lane(Vector2(x,z)) or (x< -3 and z>=3.5):
			continue
		var point := Vector2(x,z)
		var corridor := [Vector2(-6,3),Vector2(-7.5,4.5),Vector2(-8.1,3.8),Vector2(-11,3.8)]
		var beside_driveway := RabbitHutch.FOOTPRINT.grow(1.0).has_point(point)
		for j in range(1,corridor.size()):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,corridor[j-1],corridor[j]))<1.45:
				beside_driveway = true
				break
		if i%4==0 and x<-8.5 and z>2.3 and z<7.0: continue
		if not beside_driveway: navigation.decorations.append(point)
		var y := _height(x,z)
		if i%4==0:
			var rock := _ball(Vector3(x,y+0.12,z),0.26,"b3b5a0")
			rock.scale = Vector3(1.3,0.65,0.8)
			rock.visible = not beside_driveway
		else:
			for j in range(3):
				var offset := Vector3(rng.randf_range(-0.25,0.25),0,rng.randf_range(-0.25,0.25))
				_pole(Vector3(x,y+0.17,z)+offset,0.017,0.30,"768c54").visible = not beside_driveway
				_ball(Vector3(x,y+0.34,z)+offset,0.075,["ead4a0","d6a99c","e6e5c7"][i%3]).visible = not beside_driveway
	# Water barrel beside the front wall.
	_pole(Vector3(0.05,0.48,-0.7),0.38,0.85,"a58b63")
	_pole(Vector3(0.05,0.92,-0.7),0.33,0.025,"92b1af")

func _load_oak_chair() -> Node3D:
	var document := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var error := document.append_from_file("res://assets/chair_oak_v02.glb", gltf_state)
	if error != OK:
		push_warning("Oak chair unavailable: " + str(error))
		return null
	return document.generate_scene(gltf_state)

func _update_camera() -> void:
	camera.size = zoom
	camera.position = focus + Vector3(sin(azimuth)*cos(elevation),sin(elevation),cos(azimuth)*cos(elevation))*30
	camera.look_at(focus)
	build_mode.refresh_handles()
	if is_instance_valid(rain): rain.position = Vector3(focus.x,8.5,focus.z)
	for crown in tree_crowns:
		if follow_rabbit or follow_neighbor or garden_close or zoom<=6:
			var inverse := crown.global_transform.affine_inverse()
			crown.visible = crown.get_aabb().grow(.15).intersects_segment(inverse*focus,inverse*camera.position)==null
		else:
			crown.visible = true

func _pointer_over_camera_controls(screen: Vector2) -> bool:
	return build_mode.covers(screen) or (ui_heading.visible and ui_heading.get_global_rect().has_point(screen)) or ui_footer.get_global_rect().has_point(screen) or ui_sidebar_toggle.get_global_rect().has_point(screen)

func _zoom_at(screen: Vector2, target_size: float) -> void:
	var next := clampf(target_size,MIN_ZOOM,MAX_ZOOM)
	if is_equal_approx(next,zoom): return
	var plane := Plane(Vector3.UP,focus.y)
	var ray := camera.project_ray_normal(screen)
	var before = plane.intersects_ray(camera.project_ray_origin(screen),ray)
	zoom = next
	camera.size = zoom
	var after = plane.intersects_ray(camera.project_ray_origin(screen),ray)
	if before!=null and after!=null:
		focus += before-after
		focus.x = clampf(focus.x,-34,9)
		focus.z = clampf(focus.z,-8,8)
	follow_car = false
	follow_rabbit = false
	follow_neighbor = false
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if build_mode.input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and house_interior.visible:
		_set_house_cutaway(false)
		get_viewport().set_input_as_handled()
		return
	if (chat_panel!=null and chat_panel.visible) or (journal_panel!=null and journal_panel.visible) or (memory_panel!=null and memory_panel.visible):
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]:
		if not _pointer_over_camera_controls(event.position) and event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(event.position,zoom/WHEEL_ZOOM_RATIO)
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(event.position,zoom*WHEEL_ZOOM_RATIO)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMagnifyGesture:
		if not _pointer_over_camera_controls(event.position) and event.factor>0:
			_zoom_at(event.position,zoom/event.factor)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			resident_press = event.position
			resident_click_armed = true
		else:
			if resident_click_armed and resident_press.distance_to(event.position)<6:
				if _bookshelf_hit(event.position):
					_open_bookshelf()
					get_viewport().set_input_as_handled()
				elif _car_hit(event.position):
					_invite_drive()
					get_viewport().set_input_as_handled()
				elif _resident_hit(event.position):
					chat_panel.open_chat()
					get_viewport().set_input_as_handled()
				elif _front_door_hit(event.position):
					_open_house_interior()
					get_viewport().set_input_as_handled()
				elif _mailbox_hit(event.position):
					_open_mailbox()
					get_viewport().set_input_as_handled()
				elif _flower_hit(event.position):
					_look_at_flower()
					get_viewport().set_input_as_handled()
			resident_click_armed = false
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			azimuth -= event.relative.x*0.006
			elevation = clampf(elevation+event.relative.y*0.004,0.35,1.18)
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT or event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			follow_car = false
			follow_rabbit = false
			follow_neighbor = false
			garden_close = false
			var right := camera.global_basis.x
			var forward := Vector3(-right.z,0,right.x)
			focus += (-right*event.relative.x-forward*event.relative.y)*zoom/900.0
			focus.x = clampf(focus.x,-34,9)
			focus.z = clampf(focus.z,-8,8)
		_update_camera()
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		_reset_camera()

func _look_at_forest() -> void:
	_reset_camera()
	focus = Vector3(ForestLand.CENTER.x,.6,ForestLand.CENTER.y)
	zoom = 29
	_update_camera()

func _reset_camera() -> void:
	if is_instance_valid(house_interior):
		house_interior.hide()
		if hobbies.indoors() or mailbox.indoors(): resident.model.hide()
		house_exterior.show()
		if is_instance_valid(close_cutaway):
			close_cutaway.text = "室内"
			_resize_interface()
	garden_close = false
	follow_car = false
	follow_rabbit = false
	follow_neighbor = false
	focus = Vector3(0,0.6,0)
	azimuth = 0.64
	elevation = 0.70
	zoom = 21
	_update_camera()

func _style(bg: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var heading := PanelContainer.new()
	ui_heading = heading
	heading.position = Vector2(12,12)
	heading.add_theme_stylebox_override("panel",_style("f8f5e9"))
	layer.add_child(heading)
	var stack := VBoxContainer.new()
	heading.add_child(stack)
	var title := Label.new()
	title.text = "小院，有了日常"
	title.add_theme_font_size_override("font_size",26)
	title.add_theme_color_override("font_color",Color("405848"))
	stack.add_child(title)
	var caption := Label.new()
	caption.text = str(resident_profile.title)+" · "+str(resident_profile.name_en)
	caption.add_theme_font_size_override("font_size",14)
	caption.add_theme_color_override("font_color",Color("75806e"))
	stack.add_child(caption)
	resident_status = Label.new()
	resident_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resident_status.text = str(resident_profile.display_name)+" · 正在看看小院"
	resident_status.add_theme_font_size_override("font_size",16)
	resident_status.add_theme_color_override("font_color",Color("405848"))
	stack.add_child(resident_status)
	save_status = Label.new()
	save_status.add_theme_font_size_override("font_size",13)
	save_status.add_theme_color_override("font_color",Color("75806e"))
	stack.add_child(save_status)
	needs_status = Label.new()
	needs_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	needs_status.add_theme_font_size_override("font_size",14)
	needs_status.add_theme_color_override("font_color",Color("546650"))
	stack.add_child(needs_status)
	sunlight_button = Button.new()
	sunlight_button.text = "日照：柔和"
	sunlight_button.add_theme_stylebox_override("normal",_style("e5e9d8"))
	sunlight_button.add_theme_color_override("font_color",Color("405848"))
	sunlight_button.tooltip_text = "切换小院日照；埃尔下次选择休息点时会考虑新条件。"
	sunlight_button.pressed.connect(_toggle_sunlight)
	stack.add_child(sunlight_button)
	rest_reason = Label.new()
	rest_reason.text = "休息选择：下次歇脚时再决定"
	rest_reason.custom_minimum_size.x = 260
	rest_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rest_reason.add_theme_font_size_override("font_size",14)
	rest_reason.add_theme_color_override("font_color",Color("546650"))
	stack.add_child(rest_reason)
	var chat_button := Button.new()
	chat_button.text = "和埃尔聊聊"
	chat_button.add_theme_stylebox_override("normal",_style("e5e9d8"))
	chat_button.add_theme_color_override("font_color",Color("405848"))
	chat_button.pressed.connect(func(): journal_panel.close_diary(); memory_panel.close_memory(); chat_panel.open_chat())
	stack.add_child(chat_button)
	self_arrangement_button = Button.new()
	self_arrangement_button.text = "让埃尔自己安排一次"
	self_arrangement_button.custom_minimum_size.y = 54
	self_arrangement_button.tooltip_text = "方便时用订阅想一次，收起画面也最多一次；与聊天共享本地次数。退出或睡眠取消未完成的思考。"
	self_arrangement_button.add_theme_stylebox_override("normal",_style("e5e9d8"))
	self_arrangement_button.add_theme_color_override("font_color",Color("405848"))
	self_arrangement_button.pressed.connect(_offer_self_arrangement)
	stack.add_child(self_arrangement_button)
	self_arrangement_status = Label.new()
	self_arrangement_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	self_arrangement_status.custom_minimum_size.x = 260
	self_arrangement_status.add_theme_font_size_override("font_size",14)
	self_arrangement_status.add_theme_color_override("font_color",Color("546650"))
	stack.add_child(self_arrangement_status)
	low_frequency_toggle = CheckButton.new()
	low_frequency_toggle.text = "开启低频自己安排"
	for color_key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		low_frequency_toggle.add_theme_color_override(color_key,Color("405848"))
	low_frequency_toggle.tooltip_text = "默认关闭。开启后，收起画面也能每运行1小时检查一次，近5运行小时最多2次。失败或取消会暂停，需要手动重新开启。睡眠、退出期间不补算机会。"
	low_frequency_toggle.toggled.connect(_toggle_low_frequency)
	stack.add_child(low_frequency_toggle)
	low_frequency_status = Label.new()
	low_frequency_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	low_frequency_status.custom_minimum_size.x = 260
	low_frequency_status.add_theme_font_size_override("font_size",14)
	low_frequency_status.add_theme_color_override("font_color",Color("546650"))
	stack.add_child(low_frequency_status)
	var diary_button := Button.new()
	diary_button.text = "生活日记"
	diary_button.add_theme_stylebox_override("normal",_style("e5e9d8"))
	diary_button.add_theme_color_override("font_color",Color("405848"))
	diary_button.pressed.connect(func(): chat_panel.close_chat(); memory_panel.close_memory(); journal_panel.open_diary())
	var diary_row := HBoxContainer.new()
	stack.add_child(diary_row)
	diary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diary_row.add_child(diary_button)
	mailbox_button = Button.new()
	mailbox_button.text = "信箱"
	mailbox_button.add_theme_stylebox_override("normal",_style("e5e9d8"))
	mailbox_button.add_theme_color_override("font_color",Color("405848"))
	mailbox_button.pressed.connect(_open_mailbox)
	diary_row.add_child(mailbox_button)
	action_status = Label.new()
	action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_status.custom_minimum_size.x = 260
	action_status.add_theme_font_size_override("font_size",13)
	action_status.add_theme_color_override("font_color",Color("546650"))
	stack.add_child(action_status)
	rabbit_status = Label.new()
	rabbit_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rabbit_status.custom_minimum_size.x = 260
	rabbit_status.add_theme_font_size_override("font_size",13)
	rabbit_status.add_theme_color_override("font_color",Color("546650"))
	rabbit_status.tooltip_text = "德雷克由小世界照顾好，不需要定时喂食。"
	stack.add_child(rabbit_status)
	var neighbor_row := HBoxContainer.new()
	stack.add_child(neighbor_row)
	neighbor_status = Button.new()
	neighbor_status.clip_text = true
	neighbor_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	neighbor_status.text = "邻居米娅 · 正在来小院的路上"
	neighbor_status.add_theme_font_size_override("font_size",13)
	neighbor_status.pressed.connect(_look_at_neighbor)
	neighbor_row.add_child(neighbor_status)
	var garden_button := Button.new()
	garden_button.text = "看看菜地"
	garden_button.add_theme_font_size_override("font_size",13)
	garden_button.pressed.connect(_look_at_garden)
	neighbor_row.add_child(garden_button)
	plant_button = Button.new()
	plant_button.text = "看看盆栽"
	plant_button.add_theme_font_size_override("font_size",13)
	plant_button.pressed.connect(_look_at_plant)
	plant_button.visible = false
	neighbor_row.add_child(plant_button)
	var footer := PanelContainer.new()
	layer.add_child(footer)
	ui_footer = footer
	footer.add_theme_stylebox_override("panel",_style("f8f5e9e8"))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",8)
	row.add_theme_constant_override("v_separation",6)
	footer.add_child(row)
	var help := Label.new()
	ui_footer_help = help
	help.text = "拖动漫游  ·  滚轮缩放  ·  右键旋转"
	help.add_theme_color_override("font_color",Color("546650"))
	row.add_child(help)
	for item in [["收起画面",_close_to_background],["保存",_manual_save],["回到小院",_reset_camera],["建筑模式",build_mode.toggle],["退出",_quit]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		button.add_theme_stylebox_override("normal",_style("e5e9d8"))
		button.add_theme_color_override("font_color",Color("405848"))
		row.add_child(button)
	build_mode.setup_panel(layer)
	close_cutaway = Button.new()
	close_cutaway.text = "室内"
	close_cutaway.pressed.connect(_open_house_interior)
	var views := MenuButton.new()
	views.text = "视角"
	var menu := views.get_popup()
	menu.add_item("看看树林")
	menu.add_item("看看"+str(resident_profile.display_name))
	menu.add_item("看看德雷克")
	menu.id_pressed.connect(func(id: int): [_look_at_forest,_look_at_resident,_look_at_rabbit][id].call())
	row.add_child(views)
	row.add_child(close_cutaway)
	ui_size_picker = OptionButton.new()
	for text in ["界面：小","界面：中","界面：大"]: ui_size_picker.add_item(text)
	ui_size_picker.select(ui_layout.preference)
	ui_size_picker.item_selected.connect(ui_layout.set_preference)
	row.add_child(ui_size_picker)
	ui_sidebar_body = stack
	ui_details = VBoxContainer.new()
	for child in stack.get_children():
		if child not in [title,resident_status,needs_status,chat_button,diary_row]:
			stack.remove_child(child)
			ui_details.add_child(child)
	ui_details_toggle = Button.new()
	ui_details_toggle.text = "小院详情与设置"
	ui_details_toggle.toggle_mode = true
	ui_details_toggle.add_theme_stylebox_override("normal",_style("e5e9d8"))
	ui_details_toggle.add_theme_color_override("font_color",Color("405848"))
	var albums := MenuButton.new()
	albums.text = "相册与画册"
	albums.get_popup().add_item("埃尔的相册",0)
	albums.get_popup().add_item("埃尔的画册",1)
	albums.get_popup().id_pressed.connect(func(id: int):
		if id==0:
			_open_elm_album()
		else:
			var dialog = preload("res://elm_album.gd").new()
			add_child(dialog)
			dialog.show_notebook(hobbies))
	ui_details.add_child(albums)
	var writing_menu := MenuButton.new()
	writing_menu.text = "日记与书"
	writing_menu.get_popup().add_item("埃尔的日记本",0)
	writing_menu.get_popup().add_item("埃尔的书",1)
	writing_menu.get_popup().id_pressed.connect(func(id: int):
		var dialog = preload("res://elm_album.gd").new()
		add_child(dialog)
		dialog.show_writing(hobbies,id==0))
	ui_details.add_child(writing_menu)
	var enter_house := Button.new()
	enter_house.text = "聚焦屋内"
	enter_house.pressed.connect(_focus_house_interior)
	ui_details.add_child(enter_house)
	stack.add_child(ui_details_toggle)
	stack.add_child(ui_details)
	ui_details.visible = false
	ui_details_toggle.toggled.connect(func(open):
		ui_details.visible = open
		ui_details_toggle.text = "收起详情与设置" if open else "小院详情与设置"
		_resize_interface())
	stack.minimum_size_changed.connect(_resize_interface)
	UiLayout.readable(heading)
	UiLayout.readable(footer)
	ui_heading_scroll = UiLayout.scrollable(heading)
	ui_heading_scroll.follow_focus = false
	ui_heading_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	ui_sidebar_toggle = Button.new()
	ui_sidebar_toggle.add_theme_stylebox_override("normal",_style("f8f5e9e8"))
	ui_sidebar_toggle.add_theme_stylebox_override("hover",_style("eeeede"))
	ui_sidebar_toggle.add_theme_stylebox_override("pressed",_style("e5e9d8"))
	for color_key in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		ui_sidebar_toggle.add_theme_color_override(color_key,Color("405848"))
	ui_sidebar_toggle.pressed.connect(_toggle_sidebar)
	layer.add_child(ui_sidebar_toggle)
	UiLayout.readable(ui_sidebar_toggle)
	_set_sidebar_collapsed(ui_layout.sidebar_collapsed,false)
	get_viewport().size_changed.connect(_resize_interface)
	_resize_interface()
	chat_panel = ChatPanel.new()
	layer.add_child(chat_panel)
	chat_panel.setup(_chat_context,_explicit_context,_submit_local_action,_issue_model_decision,_apply_model_decision)
	chat_panel.external_busy_provider = func(): return self_arrangement.owns_slot() or life_plan.phase=="thinking"
	journal_panel = JournalPanel.new()
	layer.add_child(journal_panel)
	journal_panel.setup(func(): return {"journal":journal,"keepsakes":keepsakes,"chosen":chosen_memories,"arrangements":self_arrangement.snapshot(),"day":Calendar.day_at(simulation_seconds)},_change_chosen_memory)
	memory_panel = MemoryPanel.new()
	layer.add_child(memory_panel)
	memory_panel.setup(func(): return explicit_memory,_change_explicit_memory)
	memory_panel.return_handler = func(): chat_panel.open_chat()
	memory_panel.back_button.text = "返回聊天"
	chat_panel.memory_requested = _open_chat_memory

func _open_chat_memory() -> void:
	if chat_panel.pending: return
	chat_panel.close_chat()
	journal_panel.close_diary()
	memory_panel.open_memory()

func _toggle_sidebar() -> void:
	_set_sidebar_collapsed(not ui_layout.sidebar_collapsed)
func _set_sidebar_collapsed(collapsed: bool, persist: bool = true) -> void:
	ui_layout.sidebar_collapsed = collapsed
	ui_heading.visible = not collapsed
	ui_sidebar_toggle.text = "展开面板 ›" if collapsed else "‹ 收起"
	ui_sidebar_toggle.tooltip_text = ""
	ui_sidebar_toggle.custom_minimum_size = Vector2(144 if collapsed else 96,54)
	ui_sidebar_toggle.size = ui_sidebar_toggle.custom_minimum_size
	_resize_interface()
	if persist: ui_layout.save_preferences()

func _resize_interface() -> void:
	ui_layout_dirty = true
	if ui_layout_queued: return
	ui_layout_queued = true
	_layout_interface.call_deferred()

func _layout_interface() -> void:
	ui_layout_dirty = false
	var available := get_viewport().get_visible_rect().size
	ui_footer_help.visible = available.x>=1280
	var footer_width := maxf(240,available.x-24)
	if not is_equal_approx(ui_footer.size.x,footer_width):
		ui_footer.size.x = footer_width
	await get_tree().process_frame
	# Keep the current bounds while the flow container settles after a width change.
	available = get_viewport().get_visible_rect().size
	ui_footer.size.y = ui_footer.get_combined_minimum_size().y
	ui_footer.position = Vector2(12,maxf(12,available.y-ui_footer.size.y-12))
	var width := minf(300,available.x-24)
	var desired_height: float = ui_sidebar_body.get_combined_minimum_size().y+ui_heading.get_theme_stylebox("panel").get_minimum_size().y
	ui_heading.size = Vector2(width,minf(maxf(100,ui_footer.position.y-24),desired_height))
	ui_sidebar_toggle.position = Vector2(12 if ui_layout.sidebar_collapsed else ui_heading.get_rect().end.x+8,12)
	build_mode.layout_panels()
	ui_layout_queued = false
	if ui_layout_dirty: _resize_interface()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_to_background()
	if what == NOTIFICATION_APPLICATION_RESUMED and life_clock!=null:
		life_clock.reset(Time.get_ticks_usec())

func _quit() -> void:
	if quit_pending:
		return
	quit_pending = true
	if not await self_arrangement.stop(self):
		quit_pending = false
		save_status.text = "安排请求仍在停止，请稍后再退出"
		return
	await life_plan.stop(self)
	if chat_panel!=null and not await chat_panel.stop_requests():
		quit_pending = false
		chat_panel.shutting_down = false
		chat_panel._update_send()
		save_status.text = "请求仍在停止，请稍后再次退出"
		return
	if fatal_save_error:
		_acknowledge_native_quit()
		get_tree().quit(0)
		return
	if saving_enabled and not _save_now():
		quit_pending = false
		chat_panel.shutting_down = false
		chat_panel._update_send()
		_show_exit_failure()
		return
	ui_layout.save_preferences()
	_acknowledge_native_quit()
	print("COZY_WORLD_EXIT")
	get_tree().quit(0)

func _build_resident() -> void:
	resident = ResidentScript.new()
	add_child(resident)
	resident.activity_changed.connect(func(text: String):
		var status := str(resident_profile.display_name)+" · "+text
		if resident_status.text!=status: resident_status.text = status)
	resident.rest_choice_changed.connect(func(reason: String): rest_reason.text = "休息选择："+reason)
	resident.arrived.connect(_remember_arrival)
	resident.setup(self,world_layout)

func _look_at_resident() -> void:
	garden_close = false
	follow_car = false
	follow_rabbit = false
	follow_neighbor = false
	focus = Vector3(resident.position.x,0.7,resident.position.z)
	zoom = 11
	_update_camera()

func _test_resident() -> void:
	resident.set_process(false)
	var was_moving := false
	var sat_down := false
	for step in range(4200):
		resident.advance(0.05)
		was_moving = was_moving or resident.mode == "move"
		sat_down = sat_down or resident.mode == "rest"
		if absf(resident.position.x)>11 or absf(resident.position.z)>9:
			push_error("Resident left world bounds")
			get_tree().quit(1)
			return
		if resident.mode == "move" and resident.position.x>-5.15 and resident.position.x<0.15 and resident.position.z<1.4 and resident.position.z>-4.0:
			push_error("Resident crossed cottage footprint")
			get_tree().quit(1)
			return
	# Replacing a visual key / adding furniture must not mutate resident state.
	var before := [resident.current_location,resident.visit_index,resident.recent_events.duplicate()]
	resident.catalog.locations["object.bench.001"].model_key = "replacement_bench"
	resident.catalog.locations["object.bench.001"].name = "户外餐椅"
	resident.catalog.locations["object.bed.001"] = {"name":"未来床铺","position":[-2.5,-1],"activities":["sleep"],"model_key":"future_bed"}
	var after := [resident.current_location,resident.visit_index,resident.recent_events.duplicate()]
	if resident.visited.size()!=4 or not was_moving or not sat_down or before!=after:
		push_error("Resident activity / catalog separation check failed")
		get_tree().quit(1)
		return
	print("RESIDENT_TEST_OK: visited 4 locations; moved, rested; catalog edit kept runtime identity and events")
	get_tree().quit(0)

func _initialize_save(save_backend = null) -> void:
	store = SaveStore.new() if save_backend==null else save_backend
	var loaded: Dictionary = store.load_state()
	if loaded.status in ["newer_version","unreadable"]:
		fatal_save_error = true
		resident.set_process(false)
		save_status.text = "存档已保护，等待处理"
		var dialog := AcceptDialog.new()
		add_child(dialog)
		dialog.title = "暂时无法继续小院"
		dialog.dialog_text = "这份存档来自更新版本，请使用更新的程序打开。" if loaded.status=="newer_version" else "现有存档和备份暂时无法读取。原文件已保留，请先恢复备份；不会自动覆盖成新世界。"
		dialog.confirmed.connect(_quit)
		dialog.popup_centered()
		return
	if loaded.status=="ok":
		state_template = loaded.state.duplicate(true)
		simulation_seconds = float(state_template.simulation_seconds)
		resident.restore(state_template.resident)
		save_status.text = "已从备份恢复 · 原进度继续" if loaded.recovered else "已恢复进度 · 欢迎回来"
		if loaded.recovered:
			var notice := AcceptDialog.new()
			add_child(notice)
			notice.title = "已找到可用备份"
			notice.dialog_text = "主存档暂时无法读取，已从最近的有效备份恢复。可能回到稍早的进度。"
			notice.popup_centered()
	else:
		state_template = {"world_id":"cozy-"+str(Time.get_unix_time_from_system())+"-"+str(OS.get_process_id()),"simulation_seconds":0,"save_sequence":0,"world_state":{},"memories":[]}
		save_status.text = "新的一天 · 每分钟自动保存"
	build_mode.restore_saved(state_template.world_state.get("builder_layout"),state_template.world_state.get("builder_front_path",false))
	Calendar.anchor = float(state_template.world_state.get("calendar_start",-1))
	if save_backend==null and Calendar.anchor<0:
		Calendar.anchor = ceilf(simulation_seconds)
	journal.start(simulation_seconds)
	keepsakes.enabled_seconds = floorf(simulation_seconds)
	if state_template.world_state.has("keepsakes"):
		keepsakes.restore(state_template.world_state.keepsakes)
	if state_template.world_state.has("chosen_memories"):
		chosen_memories.restore(state_template.world_state.chosen_memories)
	if state_template.world_state.has("rest_preference"):
		rest_preference.restore(state_template.world_state.rest_preference)
	plant_routine.start(simulation_seconds)
	if state_template.world_state.has("plant_routine"):
		plant_routine.restore(state_template.world_state.plant_routine)
	if state_template.world_state.has("self_arrangement"):
		self_arrangement.restore(state_template.world_state.self_arrangement,simulation_seconds)
	if state_template.world_state.has("low_frequency_arrangement"):
		low_frequency_arrangement.restore(state_template.world_state.low_frequency_arrangement)
	if state_template.world_state.has("plant_visit"):
		plant_visit.restore(state_template.world_state.plant_visit)
	if state_template.world_state.has("plant_arrangement"):
		plant_arrangement.restore(state_template.world_state.plant_arrangement)
		if plant_arrangement.phase=="placing" and resident.mode!="arrange_plant":
			plant_arrangement.phase = "idle"
			plant_arrangement.target = ""
			plant_arrangement.decision_evidence.clear()
		if plant_arrangement.phase=="placed": _show_arranged_plant(plant_arrangement.target)
	if state_template.world_state.has("life_journal"):
		journal.restore(state_template.world_state.life_journal,simulation_seconds)
	journal_enabled = true
	if state_template.world_state.has("explicit_memory"):
		explicit_memory.restore(state_template.world_state.explicit_memory,simulation_seconds)
	if Calendar.anchor<0:
		_set_sunlight(str(state_template.world_state.get("environment",{}).get("sunlight","gentle")))
	else:
		sunlight_button.hide()
		_update_daylight()
	if not resident.rest_choice_reason.is_empty():
		rest_reason.text = "最近的休息选择："+resident.rest_choice_reason
	needs = BasicLife.new()
	var world_state: Dictionary = state_template.world_state
	dining.state = world_state.get("outdoor_dining",OutdoorDining.EMPTY).duplicate()
	watering_can_charges = int(world_state.get("watering_can_charges",0))
	seed_stock = world_state.get("seed_stock",{"vegetable":0,"potato":0}).duplicate()
	if world_state.has("basic_life"):
		needs.restore(world_state.basic_life)
	needs.ensure_supply(simulation_seconds)
	resident.needs = needs
	if state_template.world_state.has("rabbit"):
		rabbit.restore(state_template.world_state.rabbit,simulation_seconds)
	else:
		rabbit.adopt(simulation_seconds)
	rabbit_enabled = true
	rabbit_feeding.update_supplies(rabbit.hay,rabbit.water)
	if world_state.has("pet_companion"):
		pet_companion.restore(world_state.pet_companion)
	if world_state.has("neighbor"):
		neighbor_enabled = neighbor.restore(world_state.neighbor,simulation_seconds)
		if not neighbor_enabled:
			fatal_save_error = true
			save_status.text = "米娅的位置需要检查，已保护原存档"
			return
	else:
		neighbor_enabled = neighbor.adopt(simulation_seconds)
		neighbor_pending = not neighbor_enabled
	if world_state.has("neighbor_greeting"):
		neighbor_greeting.restore(world_state.neighbor_greeting)
	if world_state.has("garden_care"):
		garden_care.restore(world_state.garden_care)
	_update_garden_water(simulation_seconds)
	if world_state.has("mia_rabbit"):
		mia_rabbit.restore(world_state.mia_rabbit)
	if world_state.has("garden_growth"):
		garden_growth.restore(world_state.garden_growth)
	else:
		garden_growth.start(simulation_seconds)
	_update_garden_growth()
	elm_gardening.start(simulation_seconds)
	if world_state.has("elm_gardening"):
		elm_gardening.restore(world_state.elm_gardening)
		if not world_state.get("window_storage_aligned",false) and elm_gardening.active(): elm_gardening._cancel(self,simulation_seconds)
	elm_gardening.plot_position = ElmGardening.POT
	elm_gardening.work_position = ElmGardening.STAND
	_create_flower_garden()
	if world_state.has("flower_neighbor_visit"):
		flower_neighbor_visit.restore(world_state.flower_neighbor_visit)
		if not world_state.get("window_storage_aligned",false) and flower_neighbor_visit.active(): flower_neighbor_visit._cancel(self,simulation_seconds)
	mailbox.restore(world_state.get("mailbox",[]))
	_update_mailbox_flag()
	mailbox.potato_seed_letter = world_state.get("potato_seed_letter","")
	if world_state.has("elm_hobbies"):
		hobbies.restore(world_state.elm_hobbies)
		house_interior.show_framed_drawing(hobbies.framed_drawing())
		if not hobbies.drafts.is_empty(): house_interior.show_sketch(hobbies.drafts.back())
	if world_state.has("life_plan"): life_plan.restore(world_state.life_plan,simulation_seconds)
	if world_state.has("forest_walk"): forest.restore(world_state.forest_walk)
	if world_state.has("garden_border") and world_state.get("yard_border_rebuilt",false):
		border.restore(world_state.garden_border)
	else:
		border.next_check = floorf(simulation_seconds)+180
		if world_state.get("garden_border",{}).get("reserved",false):
			forest.supplies["落枝"] += 1
	life_plan.retire_entrance_project(world_state.get("life_plan",{}),forest,simulation_seconds)
	if not world_state.get("sage_bench",false):
		if life_plan.reserved and life_plan.stages in [1,2]:
			forest.supplies["小石子" if life_plan.stages==1 else "落枝"] += 2 if life_plan.stages==1 else 3
		life_plan.selected = ""
		life_plan.reason = ""
		life_plan.observation.clear()
		life_plan.stages = 0
		life_plan.progress = 0
		life_plan.reserved = false
		life_plan.visits = 0
		life_plan.bench_moved = false
		life_plan.move_requested = false
		life_plan.next_check = floorf(simulation_seconds)+60
		forest.rest_requested = false
		if forest.trip_kind=="move_bench":
			forest.trip_kind = "routine"
			forest.carrying_bench = false
	vegetable_project.start(simulation_seconds)
	if world_state.has("vegetable_project"):
		vegetable_project.restore(world_state.vegetable_project)
		if not world_state.vegetable_project.has("plot_index") and vegetable_project.active():
			vegetable_project._cancel(self,simulation_seconds)
	vegetable_plots = [vegetable_project]
	var extras: Array = world_state.get("additional_plots",[])
	for i in range(1,3):
		var plot = VegetableProject.new()
		plot.start(simulation_seconds)
		plot.set_plot(i)
		if extras.size()>=i: plot.restore(extras[i-1])
		plot.seeds_at = vegetable_project.seeds_at
		vegetable_plots.append(plot)
	if not world_state.has("seed_stock"):
		if vegetable_plots.any(func(plot): return plot.harvest_count>0): seed_stock.vegetable = 2
		var old_potato = _potato_crop()
		if old_potato!=null and old_potato.harvested_at>=0: seed_stock.potato = 1
	if not world_state.get("yard_plan_clear_gate",false):
		for plot in vegetable_plots:
			var crop = plot.current_crop()
			if crop.active(): crop._cancel(self,simulation_seconds)
	for plot in vegetable_plots: _create_vegetable_bed()
	vegetable_bed = plot_meshes[0][0]
	vegetable_leaves = plot_meshes[0][1]
	_update_needs_ui()
	_update_action_status()
	saving_enabled = true
	if loaded.status=="new" or not state_template.world_state.has("rabbit") or (neighbor_enabled and not state_template.world_state.has("neighbor")):
		_save_now()

func _process(delta: float) -> void:
	if not lifecycle_ready:
		# Explicit test scenes can exercise autosave without native lifecycle or user files.
		if saving_enabled and not fatal_save_error:
			_advance_simulation(minf(delta,0.1))
		return
	var now := Time.get_ticks_usec()
	if now-native_poll_us>=200000:
		native_poll_us = now
		_poll_native_lifecycle()
	if fatal_save_error:
		life_clock.reset(now)
		return
	var native_background := bool(native_lifecycle.get("background",false))
	var minimized := get_window().mode==Window.MODE_MINIMIZED
	_set_background(minimized or native_background)
	var step: float = life_clock.consume(now,bool(native_lifecycle.get("sleeping",false)),int(native_lifecycle.get("wake_sequence",0)))
	_advance_simulation(step)

func _potato_crop():
	for plot in vegetable_plots:
		if plot.potato!=null: return plot.potato
	return null

func collect_crop_seeds(kind: String, now: float, plot_key: String) -> void:
	if seed_stock[kind]>=12: return
	var seed_key := "%s/%s/%s/%d"%[state_template.get("world_id",""),kind,plot_key,int(now)]
	var roll := seed_key.sha256_text().substr(0,8).hex_to_int()%100
	if roll>=85: return
	seed_stock[kind] = mini(12,int(seed_stock[kind])+(2 if roll<35 else 1))
	if journal_enabled:
		journal.record("home.window_storage","右窗收纳角","vegetable_seed_found" if kind=="vegetable" else "potato_seed_found",now)

func _plant_saved_potatoes(now: float) -> void:
	if seed_stock.potato<=0 or life_plan.potato_plot>=0 or hobbies.used<3: return
	var old = _potato_crop()
	if old==null or old.harvested_at<0 or not elm_gardening._safe(self): return
	var target = null
	for plot in vegetable_plots:
		if plot.phase!="idle" or plot.meeting or (plot.planted and plot.cycle_harvest_at<0): continue
		target = plot
		if plot.potato==old: break
	if target==null: return
	for plot in vegetable_plots:
		if plot.potato==old: plot.potato = null
	seed_stock.potato -= 1
	hobbies.used = 0
	if hobbies.job in ["roast_potato","photo_harvest"]: hobbies.job = ""
	target.start_potato(now)

func _potato_choices() -> Array:
	if mailbox.potato_seed_letter.is_empty() or _potato_crop()!=null or life_plan.potato_plot>=0: return []
	var choices := []
	var vacant := []
	for plot in vegetable_plots:
		var choice := "plant_potato_"+str(plot.plot_index+1)
		choices.append(choice)
		if plot.can_plant_potato(): vacant.append(choice)
	return choices if vacant.is_empty() else vacant

func _plant_potato(choice: String) -> void:
	if not mailbox.potato_seed_letter.is_empty() and _potato_crop()==null and life_plan.potato_plot<0:
		life_plan.potato_plot = int(choice.right(1))-1

func _start_pending_potato() -> void:
	if life_plan.potato_plot<0: return
	var plot = vegetable_plots[life_plan.potato_plot]
	if not plot.can_plant_potato(): return
	plot.start_potato(simulation_seconds)
	life_plan.potato_plot = -1
	_save_now()

func _vegetable_progress() -> Array:
	var progress: Array = [seed_stock.vegetable,seed_stock.potato,vegetable_project.phase,vegetable_project.stage,vegetable_project.water_count,vegetable_project.seeds_at,vegetable_project.harvest_at,vegetable_project.gift_at,vegetable_project.cycle,vegetable_project.cycle_harvest_at,vegetable_project.shared_count]
	for plot in vegetable_plots.slice(1): progress.append([plot.phase,plot.cycle,plot.stage,plot.water_count,plot.cycle_harvest_at,plot.shared_count,plot.gift_at])
	if needs!=null: progress.append_array([needs.garden_food,needs.meal_is_garden,needs.garden_meals_finished])
	var potato = _potato_crop()
	if potato!=null: progress.append([potato.phase,potato.stage,potato.water_count,potato.harvested_at])
	return progress

func _flower_progress() -> Array:
	return [elm_gardening.phase,elm_gardening.planted,elm_gardening.water_count,elm_gardening.stage,elm_gardening.wilted_at,elm_gardening.picked]

func _advance_simulation(seconds: float) -> void:
	if seconds<=0:
		return
	var forest_before: String = JSON.stringify([forest.phase,forest.trips,forest.supplies,forest.cargo,border.phase,border.completed,border.reserved,life_plan.stages,life_plan.reserved])
	var action_before: String = resident.user_action.phase()
	var routine_before: String = plant_routine.visit.phase()
	var mia_mode_before: String = neighbor.mode
	var flower_visit_before: String = flower_neighbor_visit.phase
	var vegetable_before: Array = _vegetable_progress()
	var potatoes_before: int = hobbies.used
	var books_before: Dictionary = hobbies.pages_read.duplicate()
	var drafts_before: int = hobbies.drafts.size()
	var indoor_done_before: bool = hobbies.indoor_done
	var gardening_before := _flower_progress()
	var can_before := watering_can_charges
	var plant_move_before: float = plant_arrangement.moved_seconds
	var supplies_before := Vector2i(rabbit.hay,rabbit.water)
	var dining_before: Dictionary = dining.state.duplicate()
	shelter_from_rain = saving_enabled and Weather.at(simulation_seconds+seconds,str(state_template.get("world_id","")))=="rain"
	var remaining_time := seconds
	while remaining_time>0.000001:
		var step := minf(remaining_time,0.05)
		if needs!=null:
			needs.advance(step,resident.mode=="rest",elm_gardening.active() or vegetable_project.active() or border.active())
		event_seconds = simulation_seconds + seconds - remaining_time + step
		if resident.mode=="observe" and dining.meal.is_empty() and patio_chat.phase.is_empty():
			var feet := Vector2(resident.position.x,resident.position.z)
			if feet.distance_to(OutdoorDining.SEAT)<.04:
				resident.position.x = OutdoorDining.SEAT_APPROACH.x
				resident.position.z = OutdoorDining.SEAT_APPROACH.y
				resident._sync_height()
		var was_eating: bool = needs!=null and needs.meal_active
		var was_garden_meal: bool = was_eating and needs.meal_is_garden
		var wet_before: float = garden_care.wet_until
		var water_count_before: int = garden_care.water_count
		if mia_rabbit.active() and (pet_companion.active() or pet_companion.requested or resident.mode=="drive"):
			mia_rabbit.cancel(self,event_seconds)
		if not patio_chat.phase.is_empty() and (neighbor.needs_visit_step(event_seconds) or dining.state.order_until>0):
			patio_chat._finish(self)
		var delivery_busy: bool = saving_enabled and dining.advance_delivery(step,event_seconds)
		var mia_flower_busy: bool = neighbor_enabled and neighbor.needs_visit_step(event_seconds) and not delivery_busy and not vegetable_project.meeting
		if mia_flower_busy:
			neighbor.advance(step,event_seconds)
		elif not delivery_busy:
			mia_flower_busy = flower_neighbor_visit.advance(self,step,event_seconds)
		mia_flower_busy = mia_flower_busy or delivery_busy
		if saving_enabled and mailbox.reading_id.is_empty():
			hobbies.consider_home_meal(self,event_seconds)
			hobbies.consider_bathroom(self,event_seconds)
			hobbies.consider_rabbit_care(self,event_seconds)
			if shelter_from_rain:
				hobbies.consider_rain_shelter(self,event_seconds)
			else:
				hobbies.consider_evening_activity(self,event_seconds)
		var indoor_busy: bool = hobbies.indoors() and hobbies.advance(self,step,event_seconds)
		var mail_busy: bool = indoor_busy or (saving_enabled and mailbox.walk_to_mailbox(self,step,event_seconds))
		var border_busy: bool = mail_busy or border.advance(self,step,event_seconds)
		var patio_busy: bool = saving_enabled and neighbor_enabled and patio_chat.advance(self,step,event_seconds,border_busy or mia_flower_busy or garden_care.active() or mia_rabbit.active())
		mia_flower_busy = mia_flower_busy or patio_busy
		var forest_busy: bool = patio_busy or border_busy or hobbies.advance(self,step,event_seconds) or (saving_enabled and Calendar.anchor>=0 and dining.advance_meal(step,event_seconds)) or forest.advance(self,step,event_seconds)
		if saving_enabled and not fatal_save_error:
			_start_pending_potato()
			if not forest_busy: _plant_saved_potatoes(event_seconds)
		var meeting_busy := false
		for plot in vegetable_plots:
			var busy := false
			for other in vegetable_plots:
				if other!=plot and (other.active() or other.meeting): busy = true
			if not forest_busy and not mia_flower_busy and not busy and not meeting_busy:
				meeting_busy = plot.advance_meeting(self,step,event_seconds)
		mia_flower_busy = mia_flower_busy or meeting_busy
		var flower_work: bool = elm_gardening.advance(self,step,event_seconds,not forest_busy and not meeting_busy and not vegetable_project.active())
		var vegetable_work := false
		for plot in vegetable_plots:
			var occupied := false
			for other in vegetable_plots:
				if other!=plot and (other.active() or other.meeting): occupied = true
			vegetable_work = plot.advance(self,step,event_seconds,not forest_busy and not meeting_busy and not flower_work and not occupied and not vegetable_work and not garden_care.active()) or vegetable_work
		var care_occupied: bool = forest_busy or meeting_busy or flower_work or vegetable_work
		var plant_busy: bool = care_occupied
		if not care_occupied: plant_busy = plant_visit.advance(self,step,event_seconds)
		if not care_occupied and (plant_routine.visit.active() or not self_arrangement.active()):
			plant_busy = plant_routine.advance(self,step,event_seconds) or plant_busy
		var greeting_busy: bool = not plant_busy and not mia_flower_busy and neighbor_enabled and neighbor_greeting.advance(self,step,event_seconds)
		if plant_busy or greeting_busy:
			var mia_pet_occupied: bool = not delivery_busy and mia_rabbit.active() and mia_rabbit.advance(self,step,event_seconds)
			if rabbit_enabled and not mia_pet_occupied: rabbit.advance(step,event_seconds)
			if plant_busy and neighbor_enabled and not mia_flower_busy and not mia_pet_occupied:
				var care_busy: bool = garden_care.advance(self,step,event_seconds)
				if not care_busy: neighbor.advance(step,event_seconds)
		else:
			var pet_busy: bool = rabbit_enabled and not mia_rabbit.active() and pet_companion.advance(self,step,event_seconds)
			var mia_pet_busy := false
			if not pet_busy:
				resident.advance(step)
				mia_pet_busy = not mia_flower_busy and neighbor_enabled and rabbit_enabled and mia_rabbit.advance(self,step,event_seconds)
				if rabbit_enabled and not mia_pet_busy: rabbit.advance(step,event_seconds)
			if neighbor_enabled and not mia_pet_busy and not mia_flower_busy:
				var care_busy: bool = garden_care.advance(self,step,event_seconds)
				if not care_busy: neighbor.advance(step,event_seconds)
		if not neighbor_enabled and neighbor_pending and not fatal_save_error:
			neighbor_retry = maxf(0,neighbor_retry-step)
			if neighbor_retry<=0:
				neighbor_enabled = neighbor.adopt(event_seconds)
				neighbor_pending = not neighbor_enabled
				neighbor_retry = 5
		garden_growth.advance(event_seconds-step,event_seconds,water_count_before,wet_before)
		if journal_enabled and was_eating and not needs.meal_active:
			_remember_event("place.home_front","meal_done",event_seconds)
			if was_garden_meal: vegetable_project._record(self,"vegetable_eaten",event_seconds)
		remaining_time -= step
	if not shelter_from_rain:
		hobbies.took_rain_walk = false
		hobbies.rain_walk_until = -1
	resident.update_umbrella(shelter_from_rain and not hobbies.indoors() and resident.mode!="drive" and resident.mode!="eat" and resident.mode!="rest" and not resident.meal_bowl.visible)
	_update_garden_water(event_seconds)
	_update_garden_growth()
	if flower_visual!=null: flower_visual.update_state(elm_gardening)
	_update_vegetable_bed()
	forest_bundle.visible = not forest.cargo.is_empty() or (border.active() and border.reserved)
	deep_bench.visible = life_plan.bench_moved
	carried_bench.visible = forest.carrying_bench
	for spot in corner_nodes:
		spot.visible = spot.get_meta("site")==life_plan.selected
		for part in spot.get_children():
			var stage: int = part.get_meta("stage",0)
			part.visible = stage<=life_plan.stages and (stage!=3 or not (life_plan.bench_moved or forest.carrying_bench))
	for i in range(border_segments.size()): border_segments[i].visible = i<border.completed
	var potato = _potato_crop()
	potato_seed_packet.visible = seed_stock.potato>0 or seed_stock.vegetable>0 or (not mailbox.potato_seed_letter.is_empty() and potato==null)
	for i in range(stored_vegetables.size()):
		stored_vegetables[i].visible = needs!=null and i<needs.garden_food
		stored_potatoes[i].visible = potato!=null and potato.harvested_at>=0 and i<3-hobbies.used
	oven_glow.visible = hobbies.job=="roast_potato" and hobbies.remaining>0
	book_in_hand.visible = hobbies.reading_inside()
	dining.box_on_table.visible = dining.state.prepared=="pizza"
	house_interior.cooking_pot.visible = hobbies.job=="cook_vegetables" and hobbies.indoor_step==2
	if watering_can!=null:
		watering_can.visible = elm_gardening.active() and elm_gardening.job=="water"
		var pouring: bool = elm_gardening.phase=="watering"
		for plot in vegetable_plots:
			var crop = plot.current_crop()
			watering_can.visible = watering_can.visible or (crop.active() and crop.job=="water")
			pouring = pouring or crop.phase=="watering"
		watering_stream.visible = pouring
		if pouring:
			watering_stream.rotation.x = -resident.right_arm.rotation.x
			watering_stream.position.y = -.08*fmod(event_seconds*6.0,1.0)
	if flower_in_hand!=null: flower_in_hand.visible = hobbies.carrying_flower
	for kind in range(basket_contents.size()):
		var count: int = int(forest.supplies[["松果","落枝","小石子"][kind]])
		for i in range(basket_contents[kind].size()): basket_contents[kind][i].visible = i<count
	if follow_car and resident.mode=="drive":
		focus = car.position+Vector3.UP*.7
		_update_camera()
	if follow_rabbit and rabbit_enabled:
		focus = rabbit.position+Vector3.UP*.4
		_update_camera()
	if follow_neighbor and neighbor_enabled and neighbor.visible:
		focus = neighbor.position+Vector3.UP*.7
		_update_camera()
	_update_action_status()
	if saving_enabled:
		simulation_seconds += seconds
		if needs!=null:
			if needs.ensure_supply(simulation_seconds):
				_save_now()
			needs_ui_elapsed += seconds
			if needs_ui_elapsed>=1:
				_update_needs_ui()
				_update_mailbox_button()
				needs_ui_elapsed = 0
		if dining_before!=dining.state: _save_now()
		if supplies_before!=Vector2i(rabbit.hay,rabbit.water):
			rabbit_feeding.update_supplies(rabbit.hay,rabbit.water)
			_save_now()
		if can_before!=watering_can_charges or potatoes_before!=hobbies.used or books_before!=hobbies.pages_read or drafts_before!=hobbies.drafts.size() or (not indoor_done_before and hobbies.indoor_done) or forest_before!=JSON.stringify([forest.phase,forest.trips,forest.supplies,forest.cargo,border.phase,border.completed,border.reserved,life_plan.stages,life_plan.reserved]) or (mia_mode_before!=neighbor.mode and (mia_mode_before in ["away","crossing"] or neighbor.mode in ["away","crossing"])) or vegetable_before!=_vegetable_progress() or action_before!=resident.user_action.phase() or routine_before!=plant_routine.visit.phase() or flower_visit_before!=flower_neighbor_visit.phase or gardening_before!=_flower_progress() or plant_move_before!=plant_arrangement.moved_seconds:
			_save_now()
		autosave_elapsed += seconds
		if autosave_elapsed>=60:
			_save_now()
		if not fatal_save_error:
			self_arrangement.advance(self)
			low_frequency_arrangement.advance(self)
			mailbox.advance(self)
			_update_mailbox_flag()
			life_plan.advance(self)
		_update_action_status()

func _save_now() -> bool:
	if store==null or fatal_save_error:
		return false
	var state := state_template.duplicate(true)
	state.world_state["builder_layout"] = build_mode.snapshot()
	state.world_state["builder_front_path"] = true
	state.world_state["watering_can_charges"] = watering_can_charges
	state.simulation_seconds = simulation_seconds
	if Calendar.anchor>=0: state.world_state["calendar_start"] = Calendar.anchor
	state.save_sequence = int(state.get("save_sequence",0))+1
	var actor_state: Dictionary = state.get("resident",{}).duplicate(true)
	actor_state.merge(resident.snapshot(),true)
	state.resident = actor_state
	if needs!=null:
		var world_state: Dictionary = state.world_state.duplicate(true)
		var life_state: Dictionary = world_state.get("basic_life",{}).duplicate(true)
		life_state.merge(needs.snapshot(),true)
		world_state.basic_life = life_state
		var environment_state: Dictionary = world_state.get("environment",{}).duplicate(true)
		environment_state.merge({"version":1,"sunlight":sunlight},true)
		world_state.environment = environment_state
		state.world_state = world_state
	if journal_enabled:
		state.world_state["life_journal"] = journal.snapshot()
		state.world_state["keepsakes"] = keepsakes.snapshot()
		state.world_state["chosen_memories"] = chosen_memories.snapshot()
		state.world_state["rest_preference"] = rest_preference.snapshot()
		state.world_state["plant_arrangement"] = plant_arrangement.snapshot()
		state.world_state["plant_visit"] = plant_visit.snapshot()
		state.world_state["plant_routine"] = plant_routine.snapshot()
		state.world_state["elm_gardening"] = elm_gardening.snapshot()
		state.world_state["vegetable_project"] = vegetable_project.snapshot()
		if vegetable_plots.size()>1:
			state.world_state["additional_plots"] = []
			for plot in vegetable_plots.slice(1): state.world_state["additional_plots"].append(plot.snapshot())
		state.world_state["forest_walk"] = forest.snapshot()
		state.world_state["garden_border"] = border.snapshot()
		state.world_state["yard_border_rebuilt"] = true
		state.world_state["life_plan"] = life_plan.snapshot()
		state.world_state["sage_bench"] = true
		state.world_state["mailbox"] = mailbox.letters.duplicate(true)
		state.world_state["potato_seed_letter"] = mailbox.potato_seed_letter
		state.world_state["window_storage"] = true
		state.world_state["yard_plan"] = true
		state.world_state["yard_plan_clear_gate"] = true
		state.world_state["window_storage_aligned"] = true
		state.world_state["seed_stock"] = seed_stock.duplicate()
		state.world_state["elm_hobbies"] = hobbies.snapshot()
		state.world_state["outdoor_dining"] = dining.state.duplicate()
		state.world_state["flower_neighbor_visit"] = flower_neighbor_visit.snapshot()
		state.world_state["self_arrangement"] = self_arrangement.snapshot()
		state.world_state["low_frequency_arrangement"] = low_frequency_arrangement.snapshot()
	if explicit_memory.next_id>1 or state.world_state.has("explicit_memory"):
		state.world_state["explicit_memory"] = explicit_memory.snapshot()
	if rabbit_enabled:
		state.world_state["rabbit"] = rabbit.snapshot()
		state.world_state["pet_companion"] = pet_companion.snapshot()
	if neighbor_enabled:
		state.world_state["neighbor"] = neighbor.snapshot()
		state.world_state["neighbor_greeting"] = neighbor_greeting.snapshot()
		state.world_state["garden_care"] = garden_care.snapshot()
		state.world_state["garden_growth"] = garden_growth.snapshot()
		state.world_state["mia_rabbit"] = mia_rabbit.snapshot()
	if not store.save_state(state):
		save_status.text = "尚未保存 · 点击保存重试"
		autosave_elapsed = 0
		return false
	state_template = state
	autosave_elapsed = 0
	save_status.text = "已保存 · "+Time.get_time_string_from_system()
	return true

func _manual_save() -> void:
	if not saving_enabled or fatal_save_error:
		return
	if not _save_now():
		var notice := AcceptDialog.new()
		add_child(notice)
		notice.title = "这次没有保存成功"
		notice.dialog_text = str(store.last_error)+" 可以稍后再次点击保存。"
		notice.popup_centered()

func _show_exit_failure() -> void:
	get_tree().paused = true
	var dialog := ConfirmationDialog.new()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialog)
	dialog.title = "退出前未能保存"
	dialog.dialog_text = str(store.last_error)+" 小院已暂停，可以重试保存，或返回小院稍后处理。"
	dialog.ok_button_text = "重试保存并退出"
	dialog.cancel_button_text = "返回小院"
	dialog.confirmed.connect(func():
		get_tree().paused = false
		if life_clock!=null:
			life_clock.reset(Time.get_ticks_usec())
		dialog.queue_free()
		_quit())
	dialog.canceled.connect(func():
		get_tree().paused = false
		if life_clock!=null:
			life_clock.reset(Time.get_ticks_usec())
		dialog.queue_free())
	dialog.popup_centered()

func _lifecycle_file(name: String) -> String:
	return OS.get_user_data_dir().path_join(name)

func _prepare_lifecycle() -> void:
	life_clock = LifeClock.new()
	life_clock.consume(Time.get_ticks_usec())
	lifecycle_ready = true
	if OS.get_name()=="macOS" and DisplayServer.get_name()!="headless":
		var result := GDExtensionManager.load_extension("res://native/cozy_lifecycle.gdextension")
		if result!=GDExtensionManager.LOAD_STATUS_OK and result!=GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
			push_warning("Native lifecycle unavailable; close falls back to minimizing.")
		if NativeMenu.has_system_menu(NativeMenu.APPLICATION_MENU_ID):
			var menu := NativeMenu.get_system_menu(NativeMenu.APPLICATION_MENU_ID)
			NativeMenu.add_item(menu,"回到小院",func(_tag): _restore_window())
			NativeMenu.add_item(menu,"收起画面，继续生活",func(_tag): _close_to_background())
			NativeMenu.add_item(menu,"保存并退出小世界",func(_tag): _quit())

func _poll_native_lifecycle() -> void:
	var path := _lifecycle_file("lifecycle.json")
	if not FileAccess.file_exists(path):
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary:
		return
	var data: Dictionary = parser.data
	if int(data.get("pid",-1))!=OS.get_process_id():
		return
	if bool(data.get("sleeping",false)) or int(data.get("wake_sequence",0))!=int(native_lifecycle.get("wake_sequence",0)):
		chat_panel.cancel_network()
		self_arrangement.cancel(self,"sleep")
	native_lifecycle = data
	var quit_sequence := int(data.get("quit_sequence",0))
	if quit_sequence>consumed_quit_sequence:
		consumed_quit_sequence = quit_sequence
		_restore_window()
		_quit()

func _write_lifecycle(name: String, value: Dictionary) -> bool:
	value["pid"] = OS.get_process_id()
	var file := FileAccess.open(_lifecycle_file(name),FileAccess.WRITE)
	if file==null:
		return false
	file.store_string(JSON.stringify(value))
	file.close()
	return true

func _acknowledge_native_quit() -> void:
	if not native_lifecycle.is_empty():
		_write_lifecycle("lifecycle-quit.json",{"allow_quit":true})

func _close_to_background() -> void:
	chat_panel.cancel_network()
	if fatal_save_error:
		_quit()
		return
	if saving_enabled:
		_save_now()
	if not native_lifecycle.is_empty() and _write_lifecycle("lifecycle-command.json",{"action":"hide"}):
		_set_background(true)
	else:
		get_window().mode = Window.MODE_MINIMIZED
		_set_background(true)

func _restore_window() -> void:
	if not native_lifecycle.is_empty():
		_write_lifecycle("lifecycle-command.json",{"action":"show"})
	if get_window().mode==Window.MODE_MINIMIZED:
		get_window().mode = Window.MODE_WINDOWED
	_set_background(false)
	life_clock.reset(Time.get_ticks_usec())

func _set_background(value: bool) -> void:
	if background_mode==value:
		return
	background_mode = value
	if value and chat_panel!=null:
		chat_panel.cancel_network()
	RenderingServer.render_loop_enabled = not value
	rain.emitting = not value and weather=="rain"
	Engine.max_fps = 5 if value else 30
	OS.low_processor_usage_mode_sleep_usec = 200000 if value else 33333
	print("COZY_LIFECYCLE ","background" if value else "foreground")

func _update_needs_ui() -> void:
	if needs==null or needs_status==null:
		return
	_update_daylight()
	needs_status.text = "第%d天 %s · %s\n爱心 %d · 餐食 %d\n饱腹 %d · 精力 %d\n清洁度 %d · 如厕：%s"%[Calendar.day_at(simulation_seconds),Calendar.clock_text(simulation_seconds),Weather.LABELS[weather],needs.hearts,needs.food,roundi(needs.satiety),roundi(needs.energy),roundi(needs.cleanliness),needs.toilet_status()]

func _update_daylight() -> void:
	if Calendar.anchor<0: return
	var hour := Calendar.hour_at(simulation_seconds)
	var minute := Calendar.day_at(simulation_seconds)*1440+floori(hour*60)
	if minute==last_lighting_minute: return
	last_lighting_minute = minute
	var altitude := sin(TAU*(hour-6.0)/24.0)
	var daylight := smoothstep(-.22,.52,altitude)
	var twilight := smoothstep(-.14,.02,altitude)*(1.0-smoothstep(.16,.45,altitude))
	var night := 1.0-smoothstep(-.28,-.075,altitude)
	weather = Weather.at(simulation_seconds,str(state_template.get("world_id","")))
	sunlight = "strong" if weather=="strong" else "gentle"
	var rainy := weather=="rain"
	var cloud_cover := .78 if rainy else (.57 if weather=="overcast" else 0.0)
	var day_ambient := Color("e9e8df").lerp(Color("b9c7d6"),cloud_cover)
	var night_ambient := Color("94a9cd").lerp(Color("a0b1c8"),cloud_cover)
	sky_environment.background_color = Color("263449").lerp(Color("e9e9dd").lerp(Color("a2b0bd"),cloud_cover),daylight)
	sky_environment.background_color = sky_environment.background_color.lerp(Color("e0a889"),twilight*.38*(1.0-cloud_cover))
	sky_environment.ambient_light_color = night_ambient.lerp(day_ambient,daylight)
	sky_environment.ambient_light_energy = lerpf(.19,.43+.04*cloud_cover,daylight)*(1.0-.10*twilight)

	# Cloudy skies still have a broad, cool key. At night the same light gives
	# roofs and trees a faint edge while the local lanterns light the paths.
	var direct := .64 if weather=="strong" else .51
	direct = lerpf(direct,.24,cloud_cover)
	var warm := twilight*(1.0-cloud_cover)
	var day_color := Color("fff1db").lerp(Color("c3d6ed"),cloud_cover).lerp(Color("ffc08b"),warm)
	sun.light_color = day_color.lerp(Color("b2cafa"),night)
	sun.light_energy = direct*smoothstep(-.055,.63,altitude)+.29*warm+.125*night
	var midday := smoothstep(.10,.65,altitude)
	var sun_angle := Vector3(-maxf(4,altitude*66),lerpf(-105,105,clampf((hour-6)/12,0,1)),0)
	sun_angle = sun_angle.lerp(Vector3(-58,33,0),midday)
	if hour>=16.0:
		sun_angle = sun_angle.lerp(Vector3(-24,-26,0),smoothstep(16.0,17.8,hour))
	var sky_angle := sun_angle.lerp(Vector3(-42,-28,0),cloud_cover)
	sun.rotation_degrees = sky_angle.lerp(Vector3(-33,-40,0),night)
	sun.shadow_enabled = true
	sun.shadow_blur = lerpf(2.3,7.0,maxf(cloud_cover,night*.56))
	sun.shadow_opacity = lerpf(.94,.48,maxf(cloud_cover,night*.35))
	rain.emitting = weather=="rain" and not background_mode
	var lantern_on := Calendar.is_night(simulation_seconds)
	var outdoor_lamps := lantern_on or (rainy and daylight<.66) or ((hour>=17.5 or hour<7.0) and sun.light_energy<.28)
	porch_light.visible = outdoor_lamps
	dining.set_lantern(outdoor_lamps)
	porch_glass.emission_energy_multiplier = 1.6 if outdoor_lamps else 0.0
	house_interior.set_lamp(lantern_on)

func _set_sunlight(value: String) -> void:
	sunlight = value
	sun.light_energy = 0.95 if value=="strong" else 0.6
	sun.light_color = Color("ffe0a0") if value=="strong" else Color("ffecd0")
	sunlight_button.text = "日照：强烈" if value=="strong" else "日照：柔和"

func _toggle_sunlight() -> void:
	if fatal_save_error or not saving_enabled:
		return
	_set_sunlight("strong" if sunlight=="gentle" else "gentle")
	rest_reason.text = "日照变了，下次歇脚时再选地点"
	_save_now()

func _open_house_interior() -> void:
	_set_house_cutaway(not house_interior.visible)

func _close_house_interior() -> void:
	_set_house_cutaway(false)

func _set_house_cutaway(open: bool) -> void:
	house_interior.visible = open
	house_exterior.visible = not open
	if hobbies.indoors() or mailbox.indoors(): resident.model.visible = open
	close_cutaway.text = "盖屋顶" if open else "室内"
	_resize_interface()

func _focus_house_interior() -> void:
	_reset_camera()
	_set_house_cutaway(true)
	focus = Vector3(-2.18,.42,-1.5)
	azimuth = .20
	elevation = .98
	zoom = 9.3
	_update_camera()

func _bookshelf_hit(screen: Vector2) -> bool:
	if not house_interior.visible: return false
	var inverse := house_interior.global_transform.affine_inverse()
	var origin := inverse * camera.project_ray_origin(screen)
	var direction := inverse.basis * camera.project_ray_normal(screen)
	var shelf := AABB(Vector3(-1.48,.73,-2.98),Vector3(1.36,1.0,.48))
	return shelf.intersects_ray(origin,direction)!=null

func _open_bookshelf() -> void:
	if is_instance_valid(bookshelf_dialog): return
	bookshelf_dialog = AcceptDialog.new()
	bookshelf_dialog.title = "埃尔的书架"
	bookshelf_dialog.ok_button_text = "关闭"
	add_child(bookshelf_dialog)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bookshelf_dialog.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	var books := ElmBooks.catalog()
	for id in books:
		var total: int = books[id].pages.size()
		var completed := clampi(int(hobbies.pages_read.get(id,0)),0,total)
		var percent := 100.0*completed/total if total>0 else 0.0
		var row := HBoxContainer.new()
		list.add_child(row)
		var title := Label.new()
		title.text = books[id].title
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var progress := Label.new()
		progress.text = ("%d%%" % int(percent)) if percent==floorf(percent) else ("%.1f%%" % percent)
		progress.tooltip_text = "%d / %d"%[completed,total]
		row.add_child(progress)
	bookshelf_dialog.visibility_changed.connect(func():
		if not bookshelf_dialog.visible:
			bookshelf_dialog.queue_free()
			bookshelf_dialog = null)
	var viewport_size := get_viewport().get_visible_rect().size
	bookshelf_dialog.popup_centered(Vector2i(minf(480,viewport_size.x-32),minf(370,viewport_size.y-32)))

func _front_door_hit(screen: Vector2) -> bool:
	var low := Vector3(-2.18,.38,.99)
	var high := low+Vector3.UP*(.15 if house_interior.visible else 1.48)
	if camera.is_position_behind(low): return false
	var a := camera.unproject_position(low)
	var b := camera.unproject_position(high)
	var edge := camera.unproject_position(low+Vector3.RIGHT*.68)
	var radius := maxf(23.0,edge.distance_to(a)+7.0)
	return Geometry2D.get_closest_point_to_segment(screen,a,b).distance_to(screen)<=radius

func _mailbox_hit(screen: Vector2) -> bool:
	if mailbox_visual==null: return false
	var center := mailbox_door.global_position+Vector3.UP*.15 if is_instance_valid(mailbox_door) else mailbox_visual.global_position+Vector3.UP*.83
	return not camera.is_position_behind(center) and camera.unproject_position(center).distance_to(screen)<=16

func _flower_hit(screen: Vector2) -> bool:
	if flower_visual==null or camera.is_position_behind(flower_visual.global_position): return false
	var center := camera.unproject_position(flower_visual.global_position+Vector3.UP*.5)
	return center.distance_to(screen)<=22
func _look_at_flower() -> void:
	if flower_visual==null: return
	follow_car = false
	follow_rabbit = false
	follow_neighbor = false
	garden_close = true
	focus = flower_visual.position+Vector3.UP*.5
	zoom = 6
	elevation = .6
	_update_camera()

func _car_hit(screen: Vector2) -> bool:
	if car==null or camera.is_position_behind(car.global_position):
		return false
	var rect := Rect2()
	var first := true
	for x in [-.65,.65]:
		for y in [.05,.9]:
			for z in [-.85,.85]:
				var point := camera.unproject_position(car.global_transform*Vector3(x,y,z))
				if first:
					rect = Rect2(point,Vector2.ZERO)
					first = false
				else:
					rect = rect.expand(point)
	return rect.grow(5).has_point(screen)

func _invite_drive() -> void:
	garden_close = false
	if fatal_save_error or not saving_enabled:
		return
	if resident.mode=="drive":
		rest_reason.text = "埃尔正在院子里兜风，会自己找个地方停车。"
	else:
		var was_requested: bool = resident.ride_requested
		resident.ride_requested = true
		if not _save_now():
			resident.ride_requested = was_requested
			rest_reason.text = "这次邀请暂时没有保存成功，请稍后再试。"
			return
		user_intent_serial += 1
		rest_reason.text = "兜风邀请已收到，埃尔忙完手头的事就去；饿了或累了会先照顾自己。"
	follow_car = true
	follow_rabbit = false
	follow_neighbor = false
	focus = car.position+Vector3.UP*.7
	# Look across the yard so the foreground tree does not hide the parked car.
	azimuth = 1.55
	elevation = .55
	zoom = 8.5
	_update_camera()

func _resident_hit(screen: Vector2) -> bool:
	if resident==null or camera.is_position_behind(resident.global_position):
		return false
	var feet := camera.unproject_position(resident.global_position)
	var head := camera.unproject_position(resident.global_position+Vector3.UP*1.45)
	var radius := clampf(feet.distance_to(head)*0.65,24,70)
	return screen.distance_to((feet+head)*0.5)<=radius

func _remember_event(location_id: String, kind: String, seconds: float) -> void:
	if not journal_enabled or not resident.catalog.locations.has(location_id):
		return
	if journal.record(location_id,str(resident.catalog.locations[location_id].name),kind,seconds):
		keepsakes.record(kind,seconds)

func _remember_arrival(location_id: String, kind: String) -> void:
	_remember_event(location_id,kind,event_seconds)

func _chat_context() -> Dictionary:
	var lines: PackedStringArray = []
	var actions := {"rest":"开始休息","observe":"看看周围","eat":"开始用餐","drive":"开小车兜风","drive_done":"结束兜风","rest_done":"结束休息"}
	for event in resident.recent_events.slice(maxi(0,resident.recent_events.size()-5)):
		var parts: PackedStringArray = event.split(":")
		if parts.size()==2:
			var place: Dictionary = resident.catalog.locations.get(parts[0],{})
			lines.append(str(place.get("name","过去的地点"))+" · "+str(actions.get(parts[1],"停留")))
	var context := {"activity":resident_status.text,"events":"\n".join(lines) if not lines.is_empty() else "还没有可显示的到达记录。",
		"weather":Weather.LABELS[weather],"letter_memories":mailbox.recall_memories(),"rest_reason":resident.rest_choice_reason,"rest_preference":rest_preference.summary(),"rest_experience":rest_preference.chat_context(),"action_status":resident.user_action.status_text(),
		"needs":("当前饱腹%d，精力%d，库存餐食%d份；没有库存时也有免费基础餐食。"%[roundi(needs.satiety),roundi(needs.energy),needs.food]) if needs!=null else "基础生活暂时没有可显示的信息。"}
	if needs!=null:
		context["harvest_meals"] = {"vegetable_servings":needs.garden_food,"red_potato_servings":maxi(0,3-hobbies.used) if _has_potato_harvest() else 0}
	if journal_enabled:
		if not hobbies.pages_read.is_empty(): context["reading"] = ElmBooks.recall(hobbies.pages_read)
		if not hobbies.drafts.is_empty(): context["drawn_designs"] = hobbies.drafts.map(func(id): return ElmHobbies.SKETCHES[id])
		context["crop_seeds"] = {"青菜":seed_stock.vegetable,"红土豆":seed_stock.potato}
		context["plant_arrangement"] = plant_arrangement.description()
		context["plant_arrangement_reason"] = plant_arrangement.reason()
		context["plant_visit"] = plant_visit.status()
		context["plant_routine"] = plant_routine.recall()
		context["forest_walk"] = forest.description()
		if not mailbox.potato_seed_letter.is_empty():
			var potato = _potato_crop()
			context["red_potato_seed"] = ("已收获红土豆，材料篮旁还剩%d个，已烤来吃%d个。"%[3-hobbies.used,hobbies.used] if potato.harvested_at>=0 else potato.description()) if potato!=null else "已从 Gemini 来信领取一包红土豆种子，放在材料篮。"
			if potato==null and life_plan.potato_plot>=0:
				context["red_potato_seed"] += "我已选好第%d块菜地，等这茬收成后再种。"%(life_plan.potato_plot+1)
		if not forest.last_exploration.is_empty(): context["forest_last_chosen_walk"] = forest.last_exploration
		context["garden_border"] = border.description()
		context["life_plan"] = life_plan.description()
		context["vegetable_project"] = ""
		for plot in vegetable_plots:
			context["vegetable_project"] += "第%d块菜地："%(plot.plot_index+1)+plot.description()+"\n"
		context["flower_garden"] = elm_gardening.description()+"\n"+flower_neighbor_visit.description()
		context["self_arrangement"] = self_arrangement.recall()
		context["keepsakes"] = keepsakes.summary()
		context["memory_recent"] = journal.summary()
		context["memory_today"] = journal.summary(Calendar.day_at(simulation_seconds))
	if neighbor_enabled:
		context["mia_rabbit"] = mia_rabbit.recall()
		context["garden_growth"] = garden_growth.description()
		context["neighbor_water"] = garden_care.recall()
		context["neighbor_memory"] = neighbor_greeting.recall()
		context["neighbor_activity"] = "米娅 · "+neighbor.description()
	if rabbit_enabled:
		context.merge(PetRecall.context(journal if journal_enabled else null,pet_companion,simulation_seconds,rabbit.display_name))
		context["pet"] = "小兔子"+rabbit.display_name+" · "+rabbit.description()+"。它由小世界照顾，不需要定时喂食。"
		context["pet_favorite"] = rabbit.favorite_description()
	return context

func _explicit_context(message: String) -> Dictionary:
	var visit_recall: String = plant_visit.decision_recall()
	if not plant_routine.visit.latest.is_empty() and float(plant_routine.visit.latest.created_seconds)>float(plant_visit.latest.get("created_seconds",-1)) and not ("模型" in message or "决定" in message):
		visit_recall = plant_routine.recall()+"（这是本地日常记录；手动模型决定另行保存。）"
	return {"letter_memories":mailbox.recall_memories(message),"self_arrangement_history":self_arrangement.history_recall() if ("安排" in message or "打算" in message) else "本次未检索安排历史。","explicit_facts":explicit_memory.recall(message),"chosen_memories":chosen_memories.recall(message),"plant_decision_history":plant_visit.history_recall() if ("盆栽" in message or "植物" in message) else "本次未检索盆栽决定历史。","plant_decision_recall":visit_recall if ("盆栽" in message or "植物" in message or "花盆" in message) else "没有检索到与本次问题相关的盆栽决定。"}

func _change_chosen_memory(action: String, value: Variant) -> Dictionary:
	if fatal_save_error or not saving_enabled or quit_pending:
		return {"ok":false,"message":"存档暂时不可写，没有修改收藏。"}
	var previous: Dictionary = chosen_memories.snapshot()
	var result := "操作暂时不可用。"
	if action=="add" and value is Dictionary:
		result = chosen_memories.add(value,journal,simulation_seconds)
	elif action=="remove" and value is int:
		result = chosen_memories.remove(value)
	if result!="ok": return {"ok":false,"message":result}
	if not _save_now():
		chosen_memories.restore(previous)
		return {"ok":false,"message":"保存失败，收藏没有改变。"}
	return {"ok":true,"message":"已经收藏，日记轮转后也会保留。" if action=="add" else "已移出收藏，原生活日记不受影响。"}

func _change_explicit_memory(action: String, id: int, title: String, text: String) -> Dictionary:
	if fatal_save_error or not saving_enabled or quit_pending:
		return {"ok":false,"message":"存档暂时不可写，原记录没有改动。"}
	var previous: Dictionary = explicit_memory.snapshot()
	var previous_visit: Dictionary = plant_visit.snapshot()
	var previous_arrangement: Dictionary = self_arrangement.snapshot()
	var result: String = explicit_memory.change(action,id,title,text,simulation_seconds)
	if result!="ok":
		return {"ok":false,"message":result}
	var saved_id: int = explicit_memory.next_id-1 if action=="add" else id
	# A past model statement may echo a corrected/forgotten fact. Keep the action,
	# but remove the quotation atomically along with the user's memory change.
	if action in ["edit","forget"]:
		plant_visit.clear_statements()
		self_arrangement.clear_statements()
	if not _save_now():
		explicit_memory.restore(previous,simulation_seconds)
		plant_visit.restore(previous_visit)
		self_arrangement.restore(previous_arrangement,simulation_seconds,false)
		return {"ok":false,"message":"这次没有保存成功，原记录保留。你的输入还在，可以稍后重试。"}
	user_intent_serial += 1
	if action in ["edit","forget"]:
		chat_panel.reset_after_memory_change()
	return {"ok":true,"id":saved_id,"message":"已从当前记忆中移除，不会再用于聊天。" if action=="forget" else "已保存，退出重开后仍能查看和纠正。"}

func _offer_self_arrangement() -> void:
	if self_arrangement.phase() in ["waiting","requesting"]:
		self_arrangement.cancel(self)
	else:
		self_arrangement.arm(self)
	_update_action_status()

func _toggle_low_frequency(value: bool) -> void:
	low_frequency_arrangement.set_enabled(self,value)
	_update_action_status()

func _update_action_status() -> void:
	if low_frequency_toggle!=null:
		low_frequency_toggle.set_pressed_no_signal(low_frequency_arrangement.enabled)
		low_frequency_status.text = low_frequency_arrangement.status_text(simulation_seconds)
	if self_arrangement_button!=null:
		self_arrangement_button.text = "取消这次安排" if self_arrangement.phase() in ["waiting","requesting"] else "让埃尔自己安排一次"
		self_arrangement_button.disabled = self_arrangement.phase()=="executing" or (self_arrangement.transport.pid>0 and self_arrangement.phase()!="requesting")
		self_arrangement_status.text = self_arrangement.notice if not self_arrangement.notice.is_empty() else self_arrangement.status_text()
	if neighbor_status!=null and neighbor_enabled:
		neighbor_status.text = "邻居米娅 · "+neighbor.description()
		neighbor_status.tooltip_text = "点击跟随米娅。\n"+garden_growth.description()
	if action_status!=null:
		var action_text: String = "行动："+resident.user_action.status_text()
		var plant_text: String = plant_visit.status()
		if not plant_text.is_empty(): action_text += "\n盆栽："+plant_text
		if action_status.text!=action_text: action_status.text = action_text
	if rabbit_status!=null and rabbit_enabled:
		var rabbit_text: String = rabbit.display_name+" · "+rabbit.description()
		var companion_text: String = pet_companion.status()
		if not companion_text.is_empty(): rabbit_text += "\n"+companion_text
		if rabbit_status.text!=rabbit_text: rabbit_status.text = rabbit_text
func _submit_local_action(message: String) -> Dictionary:
	if not ResidentScript.ActionRequest.recognizes(message):
		return {"handled":false}
	if fatal_save_error or not saving_enabled or quit_pending:
		return {"handled":true,"message":"现在不能接收请求：存档暂时不可写，埃尔会继续原来的生活。"}
	if not resident._request_target_available():
		return {"handled":true,"message":"这次没有接下请求：树荫地点暂时不可用。"}
	if resident.user_action.active():
		return {"handled":true,"message":"同一个树荫休息请求还在进行，不会重复安排。"+resident.user_action.status_text()}
	var before: Dictionary = resident.user_action.snapshot()
	resident.user_action.enqueue(simulation_seconds)
	if not _save_now():
		resident.user_action.restore(before,simulation_seconds)
		return {"handled":true,"message":"这次没有接下请求：保存失败，你可以稍后重试。"}
	user_intent_serial += 1
	_update_action_status()
	return {"handled":true,"accepted":true,"message":"已保存请求。埃尔会先安全结束当前活动；饿了先吃饭，再走到树荫休息30秒，精力低时会多歇一会儿。完成后会继续日常生活。"}

func _issue_model_decision(scope: String = "rest") -> Dictionary:
	if fatal_save_error or not saving_enabled or quit_pending:
		return {"ok":false,"message":"存档暂时不可写，这次没有请模型决定。"}
	if self_arrangement.active() or self_arrangement.transport.pid>0: return {"ok":false,"message":"已有自己安排的事项在进行，先等它结束。"}
	if scope not in ["rest","plant"]: return {"ok":false,"message":"决定类型暂时不可用。"}
	if forest.active() or resident.user_action.active() or plant_visit.active() or plant_routine.visit.active() or elm_gardening.active() or vegetable_project.active() or vegetable_project.meeting:
		return {"ok":false,"message":"已有行动在进行，先等它完成，不重复消耗次数。"}
	if scope=="rest" and not resident._request_target_available():
		return {"ok":false,"message":"树荫暂时不可用，这次没有请模型决定。"}
	if scope=="plant" and (plant_arrangement.phase!="placed" or arranged_plant==null):
		return {"ok":false,"message":"盆栽暂时不可用，这次没有请模型决定。"}
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	model_decision_ticket = {"token":token,"world_id":str(state_template.get("world_id","")),"layout":resident._layout_signature(),"action_serial":resident.user_action.next_id,"plant_serial":plant_visit.next_id,"plant_target":plant_arrangement.target,"scope":scope,"issued_ms":Time.get_ticks_msec()}
	return {"ok":true,"token":token}

func _apply_model_decision(result: Dictionary) -> Dictionary:
	var ticket: Dictionary = model_decision_ticket.duplicate(true)
	if ticket.is_empty() or result.get("decision_token")!=ticket.token:
		return {"ok":false,"message":"建议编号不正确或已经处理，没有执行动作。"}
	model_decision_ticket.clear()
	var allowed := ["status","source","reply","proposal","decision_token","metrics"]
	for key in result:
		if key not in allowed:
			return {"ok":false,"message":"建议包含不支持的字段，没有执行动作。"}
	if result.get("status")!="ok" or result.get("source")!="codex_subscription" or result.get("proposal") not in (["none","visit_plant"] if ticket.get("scope","rest")=="plant" else ["none","rest_in_shade"]) or not result.get("reply") is String or result.reply.strip_edges().is_empty() or result.reply.length()>1200:
		return {"ok":false,"message":"建议格式不正确，没有执行动作。"}
	if Time.get_ticks_msec()-int(ticket.issued_ms)>90000 or str(state_template.get("world_id",""))!=ticket.world_id or resident._layout_signature()!=ticket.layout or resident.user_action.next_id!=ticket.action_serial or plant_visit.next_id!=ticket.plant_serial or (ticket.scope=="plant" and plant_arrangement.target!=ticket.plant_target):
		return {"ok":false,"message":"等待期间小院或请求发生变化，这条建议已作废，没有执行。"}
	if ticket.scope=="plant":
		if fatal_save_error or not saving_enabled or quit_pending or resident.user_action.active() or plant_visit.active() or plant_arrangement.phase!="placed" or arranged_plant==null:
			return {"ok":false,"message":"当前条件已经变化，没有执行这条建议。"}
		var before: Dictionary = plant_visit.snapshot()
		plant_visit.enqueue(plant_arrangement.target,simulation_seconds,result.proposal=="none",result.reply)
		if not _save_now():
			plant_visit.restore(before)
			return {"ok":false,"message":"这次决定未能保存，原世界没有改动。"}
		_update_action_status()
		return {"ok":true,"message":"埃尔选择暂时继续自己的生活，决定已记录。" if result.proposal=="none" else "埃尔决定去看看盆栽；已保存，他会在方便时出发。"}
	if result.proposal=="none":
		return {"ok":true,"message":"埃尔选择暂时不去树荫，继续自己的日常。没有新增行动。"}
	if fatal_save_error or not saving_enabled or quit_pending or resident.user_action.active() or not resident._request_target_available():
		return {"ok":false,"message":"当前条件已经变化，没有执行这条建议。"}
	var applied: Dictionary = _submit_local_action("去树荫歇一会儿")
	return {"ok":bool(applied.get("accepted",false)),"message":str(applied.message)}

func _look_at_rabbit() -> void:
	garden_close = false
	if not rabbit_enabled: return
	follow_car = false
	follow_rabbit = true
	follow_neighbor = false
	focus = rabbit.position+Vector3.UP*.4
	var away := Vector2(rabbit.position.x+2.5,rabbit.position.z+1.5)
	azimuth = atan2(away.x,away.y)
	elevation = .6
	zoom = 4.5
	_update_camera()

func _invite_pet() -> void:
	if fatal_save_error or not saving_enabled or quit_pending: return
	var before: Dictionary = pet_companion.snapshot()
	if pet_companion.invite():
		if not _save_now(): pet_companion.restore(before)
		else: user_intent_serial += 1
	_update_action_status()
	_look_at_rabbit()

func _look_at_neighbor() -> void:
	garden_close = false
	if not neighbor_enabled or not neighbor.visible: return
	follow_car = false
	follow_rabbit = false
	follow_neighbor = true
	focus = neighbor.position+Vector3.UP*.7
	zoom = 5
	elevation = .6
	_update_camera()

func _update_garden_water(seconds: float) -> void:
	if garden_soil==null: return
	var wet: bool = shelter_from_rain or garden_care.wet_until>seconds
	if wet!=garden_wet:
		garden_wet = wet
		garden_soil.material_override = _mat("5e4f3f" if wet else "8d7758")

func _update_garden_growth() -> void:
	if displayed_growth_stage==garden_growth.stage: return
	displayed_growth_stage = garden_growth.stage
	var size: float = [0.45,0.72,1.05][garden_growth.stage]
	for seedling in garden_seedlings:
		seedling.scale = Vector3.ONE*size
		seedling.position.y = .25+.23*size*.8
	for leaf in garden_growth_leaves:
		leaf.visible = garden_growth.stage>=int(leaf.get_meta("show_stage"))

func _look_at_plant() -> void:
	if arranged_plant==null: return
	follow_car = false
	follow_rabbit = false
	follow_neighbor = false
	garden_close = true
	focus = arranged_plant.position+Vector3.UP*.35
	azimuth = PI
	elevation = .6
	zoom = 4.0
	_update_camera()

func _look_at_garden() -> void:
	follow_car = false
	follow_rabbit = false
	follow_neighbor = false
	garden_close = true
	focus = Vector3(-6,.45,.3)
	azimuth = -1.0
	elevation = .65
	zoom = 4.5
	_update_camera()
