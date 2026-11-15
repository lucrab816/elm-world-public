extends RefCounted

const LIMIT := 24
const TITLES := ["林间木凳","分格花箱","窗下的盆栽","德雷克的家","林间小车","夜里的小屋"]

static func texture(id: int, motif: int) -> ImageTexture:
	var canvas := Image.create(192,128,false,Image.FORMAT_RGB8)
	canvas.fill(Color("e9ddbc"))
	var ink := Color(["45675d","566e76","795c65"][posmod(id,3)])
	for y in range(14,116,12): canvas.fill_rect(Rect2i(12,y,168,1),Color("ded1ae"))
	var roof := motif in [3,5]
	if motif==0:
		segment(canvas,Vector2i(39,66),Vector2i(150,66),ink)
		segment(canvas,Vector2i(40,42),Vector2i(149,42),ink)
		for x in [47,142]: segment(canvas,Vector2i(x,40),Vector2i(x,102),ink)
	elif motif==1 or motif==2:
		for x in [59,95,131]:
			segment(canvas,Vector2i(x,78),Vector2i(x,44),ink)
			segment(canvas,Vector2i(x,58),Vector2i(x-13,48),ink)
			segment(canvas,Vector2i(x,63),Vector2i(x+13,53),ink)
		outline(canvas,Rect2i(39,77,114,23),ink)
	elif roof:
		outline(canvas,Rect2i(51,57,90,46),ink)
		outline(canvas,Rect2i(82,75,26,28),ink)
		segment(canvas,Vector2i(41,59),Vector2i(95,25),ink)
		segment(canvas,Vector2i(95,25),Vector2i(152,59),ink)
	else:
		outline(canvas,Rect2i(40,64,112,23),ink)
		outline(canvas,Rect2i(60,48,65,16),ink)
		for x in [55,120]: outline(canvas,Rect2i(x,86,16,16),ink)
	return ImageTexture.create_from_image(canvas)

static func outline(canvas: Image, box: Rect2i, ink: Color) -> void:
	var a := box.position
	var b := box.end
	for line in [[a,Vector2i(b.x,a.y)],[a,Vector2i(a.x,b.y)],[Vector2i(a.x,b.y),b],[Vector2i(b.x,a.y),b]]:
		segment(canvas,line[0],line[1],ink)

static func segment(canvas: Image, a: Vector2i, b: Vector2i, ink: Color) -> void:
	var steps := maxi(absi(b.x-a.x),absi(b.y-a.y))
	for i in range(steps+1):
		var p := Vector2i(Vector2(a).lerp(Vector2(b),float(i)/maxi(1,steps)))
		canvas.fill_rect(Rect2i(p,Vector2i(2,2)),ink)
