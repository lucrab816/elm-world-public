extends Node3D

const STAND := Vector2(2.5,-5.5)
const PREVIOUS_STAND := Vector2(3,-5.5)
const CAPACITY := 4
const REFILL_AT := 2
const SNACK_AFTER := 140.0
const REFILL := ["refill_rabbit_hay","refill_rabbit_water"]
var grass: Array[Node3D] = []
var water_surface: MeshInstance3D

func setup(world) -> void:
	name = "DrakesFeedingCorner"
	position = Vector3(STAND.x,world._height(STAND.x,-6.05),-6.05)
	world._box(Vector3(0,.034,0),Vector3(1.03,.075,.57),"a48260",self)
	world._pole(Vector3(.25,.10,.01),.20,.13,"8a9c9f",self)
	world._pole(Vector3(.25,.172,.01),.17,.02,"bdc7bb",self)
	world._pole(Vector3(.25,.184,.01),.141,.01,"666f67",self)
	water_surface = world._pole(Vector3(.25,.196,.01),.136,.012,"8cc0ce",self)
	world._box(Vector3(-.26,.13,0),Vector3(.40,.14,.33),"bd935f",self)
	for side in [-1,1]:
		world._box(Vector3(-.26+side*.19,.24,-.01),Vector3(.045,.23,.34),"8e6646",self)
	world._box(Vector3(-.26,.24,-.16),Vector3(.40,.23,.04),"a8784d",self)
	for i in range(CAPACITY):
		var bunch: MeshInstance3D = world._box(Vector3(-.26,.205+i*.034,0),Vector3(.31,.035,.23),"d8b464" if i%2==0 else "e8c67a",self)
		bunch.rotation.y = .12 if i%2==0 else -.15
		grass.append(bunch)
	_build_decor(world)

func _build_decor(world) -> void:
	var bale := Node3D.new()
	bale.name = "DecorativeHayBale"
	world.add_child(bale)
	bale.position = Vector3(5.28,world._height(5.28,-5.12),-5.12)
	world._box(Vector3(0,.19,0),Vector3(.38,.35,.31),"d0aa5b",bale)
	for x in [-.11,.11]:
		world._box(Vector3(x,.192,0),Vector3(.022,.36,.32),"a38547",bale)
	for i in range(5):
		var straw: MeshInstance3D = world._box(Vector3(-.14+i*.064,.379,.01),Vector3(.019,.025,.33),"ead089",bale)
		straw.rotation.y = sin(i*2.0)*.22
	var toy := Node3D.new()
	toy.name = "CarrotToy"
	world.add_child(toy)
	toy.position = Vector3(4.92,world._height(4.92,-4.85)+.065,-4.85)
	toy.rotation.y = -.55
	var carrot := CylinderMesh.new()
	carrot.top_radius = .056
	carrot.bottom_radius = .014
	carrot.height = .22
	carrot.radial_segments = 7
	var body: MeshInstance3D = world._mesh(carrot,Vector3.ZERO,"d88845",toy)
	body.rotation.x = PI/2
	for x in [-.034,0,.034]:
		var leaf: MeshInstance3D = world._box(Vector3(x,.018,.13),Vector3(.026,.035,.105),"7c9d61",toy)
		leaf.rotation.y = x*12

func update_supplies(hay: int, water: int) -> void:
	for i in range(grass.size()): grass[i].visible = i<hay
	water_surface.visible = water>0
	water_surface.position.y = .185+water*.008
