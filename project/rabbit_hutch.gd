extends Node3D

const CENTER := Vector2(4,-6.53)
const APPROACH := Vector2(4,-5.5)
const BED := Vector2(4,-6.42)
const FOOTPRINT := Rect2(3.25,-7.14,1.50,1.16)
const FLOOR := .30
const THRESHOLD_Z := -5.96

func setup(world) -> void:
	name = "DrakesHutch"
	position = Vector3(CENTER.x,world._height(CENTER.x,CENTER.y),CENTER.y)
	for x in [-.62,.62]:
		for z in [-.48,.48]:
			world._box(Vector3(x,.05,z),Vector3(.15,.40,.15),"8a6346",self)
	world._box(Vector3(0,FLOOR-.06,0),Vector3(1.50,.12,1.16),"a47753",self)
	for row in range(5):
		var y := .38+row*.148
		world._box(Vector3(0,y,-.54),Vector3(1.48,.143,.09),"bf9266",self)
		for x in [-.71,.71]:
			world._box(Vector3(x,y,0),Vector3(.08,.143,1.10),"bf9266" if row%2==0 else "c79b71",self)
	for x in [-.70,-.34,.34,.70]:
		world._box(Vector3(x,.66,.55),Vector3(.072,.75,.077),"9c704b",self)
	for x in [-.52,.52]:
		world._box(Vector3(x,.67,.54),Vector3(.32,.63,.065),"84654a",self)
		for bar in [-1,0,1]:
			world._box(Vector3(x+bar*.095,.67,.589),Vector3(.022,.63,.023),"d2b686",self)
	world._box(Vector3(0,1.03,.56),Vector3(1.48,.15,.08),"c99d6d",self)
	for i in range(9):
		var straw: MeshInstance3D = world._box(Vector3(-.49+i*.118,FLOOR+.014,-.12),Vector3(.16,.027,.76),"d7b86e" if i%2==0 else "e1c788",self)
		straw.rotation.y = sin(i*2.5)*.16
	var end_height: float = world._height(APPROACH.x,APPROACH.y)-position.y
	var run := APPROACH.y-THRESHOLD_Z
	var ramp: MeshInstance3D = world._box(Vector3(0,(FLOOR+end_height)/2-.035,(APPROACH.y+THRESHOLD_Z)/2-CENTER.y),
		Vector3(.62,.07,Vector2(run,FLOOR-end_height).length()),"bb8a5f",self)
	ramp.rotation.x = atan2(FLOOR-end_height,run)
	for i in range(1,5):
		var t := i/5.0
		world._box(Vector3(0,lerpf(FLOOR,end_height,t),lerpf(THRESHOLD_Z,APPROACH.y,t)-CENTER.y),Vector3(.60,.028,.043),"d1a577",self)
	for side in [-1,1]:
		for row in range(3):
			var t := (row+.5)/3
			var shingle: MeshInstance3D = world._box(Vector3(side*.82*t,1.44-.38*t,0),
				Vector3(.32,.08,1.36),["ac5c46","b8624b","bd6a51"][row],self)
			shingle.rotation.z = -side*atan2(.38,.82)
	world._box(Vector3(0,1.45,0),Vector3(.17,.10,1.41),"a45140",self)
	# Wooden nameplate above the opening.
	world._box(Vector3(0,1.17,.565),Vector3(.63,.20,.055),"deb78a",self)
	var sign_label := Label3D.new()
	sign_label.text = "德雷克的家"
	sign_label.font_size = 27
	sign_label.pixel_size = .0034
	sign_label.modulate = Color("644b36")
	sign_label.outline_size = 0
	add_child(sign_label)
	sign_label.position = Vector3(0,1.17,.597)

static func height_at(world, point: Vector2) -> float:
	var floor_y: float = world._height(CENTER.x,CENTER.y)+FLOOR
	var approach_y: float = world._height(APPROACH.x,APPROACH.y)
	return lerpf(floor_y,approach_y,clampf(inverse_lerp(THRESHOLD_Z,APPROACH.y,point.y),0,1))
