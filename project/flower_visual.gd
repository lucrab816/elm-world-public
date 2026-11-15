extends Node3D

const WindowStorage = preload("res://window_storage.gd")
const Gardening = preload("res://elm_gardening.gd")
var world: Node3D
var sprouts: Node3D
var buds: Node3D
var blooms: Node3D
var dried: Node3D
var seed_packet: Node3D
var mia_comment: Label3D
func setup(owner) -> void:
	world = owner
	position = Vector3(Gardening.POT.x,WindowStorage.base_height(world)+WindowStorage.SURFACE,Gardening.POT.y)
	world._pole(Vector3(0,.19,0),.34,.38,"bd8163",self)
	world._pole(Vector3(0,.37,0),.37,.10,"d69a72",self)
	world._pole(Vector3(0,.42,0),.30,.025,"74573c",self)
	sprouts = Node3D.new()
	add_child(sprouts)
	buds = Node3D.new()
	add_child(buds)
	blooms = Node3D.new()
	add_child(blooms)
	dried = Node3D.new()
	add_child(dried)
	for i in range(3):
		var x: float = (i-1)*.17
		var h: float = [.70,.90,.78][i]
		world._pole(Vector3(x,(.43+h)*.5,0),.025,h-.43,"719b62",sprouts)
		world._ball(Vector3(x-.08,h-.18,0),.10,"8cb56c",sprouts).scale = Vector3(1,.5,.7)
		world._ball(Vector3(x+.08,h-.12,0),.10,"96bd78",sprouts).scale = Vector3(1,.5,.7)
		world._ball(Vector3(x,h,0),.085,"c4a2c6",buds)
		var dead_stem = world._pole(Vector3(x,.52,0),.021,.23,"9d8058",dried)
		dead_stem.rotation.z = -.25
		world._ball(Vector3(x+.035,.63,0),.057,"ba916e",dried)
		var head := Node3D.new()
		blooms.add_child(head)
		for petal in range(5):
			var a: float = petal*TAU/5
			world._ball(Vector3(x+cos(a)*.11,h+sin(a)*.11,0),.09,"e6b6ca",head).scale.z = .65
		world._ball(Vector3(x,h,.055),.065,"f0d18b",head)
	seed_packet = Node3D.new()
	world.resident.left_arm.add_child(seed_packet)
	world._box(Vector3(0,-.43,.1),Vector3(.18,.23,.06),"e7cf97",seed_packet)
	mia_comment = Label3D.new()
	world.neighbor.add_child(mia_comment)
	mia_comment.position.y = 1.85
	mia_comment.text = "花开了，真好看。"
	mia_comment.font_size = 40
	mia_comment.pixel_size = .007
	mia_comment.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	update_state(world.elm_gardening)
func update_state(care) -> void:
	mia_comment.visible = world.flower_neighbor_visit.phase=="looking"
	dried.visible = care.wilted_at>=0
	sprouts.visible = care.planted and care.stage>=1 and not dried.visible
	sprouts.scale.y = .65 if care.stage==1 else 1.0
	buds.visible = care.planted and care.stage==2
	blooms.visible = care.planted and care.stage==3 and not dried.visible
	blooms.get_child(0).visible = not care.picked
	seed_packet.visible = care.phase=="sowing"
	var soil: MeshInstance3D = get_child(2)
	soil.material_override.albedo_color = Color("52432f" if world.shelter_from_rain or care.wet_until>maxf(world.event_seconds,world.simulation_seconds) else "74573c")
