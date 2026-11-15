extends RefCounted
# Conservative geometry for this authored yard. Both walking and driving use it.
const Hutch = preload("res://rabbit_hutch.gd")
const STEP := .5
const ORIGIN := Vector2(-7.5,-6.5)
const SIZE := Vector2i(33,29)
const TREES := [Vector2(-7,-5),Vector2(-8,1),Vector2(5,-6),Vector2(8,-1),Vector2(4,7),Vector2(-8.6,7.2),Vector2(-1,-7)]
const RECTS := [Rect2(-5.25,-3.8,6.14,5.15),Rect2(-3.4,1.25,1.8,.5),Rect2(-5.13,1.68,1.26,2.14),Rect2(-3.1,-4.61,2.3,1.0),Rect2(5.25,4.95,2.7,1.65),Rect2(2.15,1.35,.9,.9)]
const OVEN_FOOTPRINT := Rect2(.85,-.62,.66,.80)
const TABLE_FOOTPRINT := Rect2(3.14,-1.57,1.72,1.72)
const CHAIR_FOOTPRINT := Rect2(3.65,-2.40,.70,.69)
const SECOND_CHAIR := Rect2(4.67,-2.14,.79,.79)
const LANES := [[Vector2(-6,3),Vector2(-4,3),Vector2(0,4),Vector2(2,5),Vector2(6.5,4.5),Vector2(6.5,0),Vector2(3,-4),Vector2(1.5,-5.3),Vector2(-5,-5.3)]]
var decorations: Array[Vector2] = []
var pet_obstacle := Vector2.INF
var neighbor_obstacle := Vector2.INF
func near_lane(p: Vector2) -> bool:
	for lane in LANES:
		for i in range(1,lane.size()):
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,lane[i-1],lane[i]))<1.7:
				return true
	return false
func clear_point(p: Vector2, radius: float, include_decor: bool = true) -> bool:
	if p.x<ORIGIN.x or p.y<ORIGIN.y or p.x>8.5 or p.y>7.5:
		return false
	if radius>.5 and pet_obstacle.is_finite() and p.distance_to(pet_obstacle)<radius+.65:
		return false
	if radius>.5 and neighbor_obstacle.is_finite() and p.distance_to(neighbor_obstacle)<radius+.80:
		return false
	if Hutch.FOOTPRINT.grow(radius).has_point(p) or not furniture_clear(p,radius):
		return false
	for rect in RECTS:
		if rect.grow(radius).has_point(p):
			return false
	for tree in TREES:
		if p.distance_to(tree)<radius+.32:
			return false
	if p.distance_to(Vector2(.05,-.7))<radius+.4:
		return false
	for decor in (decorations if include_decor else []):
		if p.distance_to(decor)<radius+.36:
			return false
	return true
func make_grid(radius: float, parked: Vector2 = Vector2.INF, parked_radius: float = 1.15) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO,SIZE)
	grid.cell_size = Vector2.ONE*STEP
	grid.offset = ORIGIN
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(SIZE.x):
		for z in range(SIZE.y):
			var id := Vector2i(x,z)
			var p := grid.get_point_position(id)
			grid.set_point_solid(id,not clear_point(p,radius) or (parked.is_finite() and p.distance_to(parked)<parked_radius))
	return grid
func nearest(grid: AStarGrid2D, p: Vector2) -> Vector2i:
	var best := Vector2i(-1,-1)
	var distance := INF
	for x in range(SIZE.x):
		for z in range(SIZE.y):
			var id := Vector2i(x,z)
			if not grid.is_point_solid(id) and p.distance_squared_to(grid.get_point_position(id))<distance:
				distance = p.distance_squared_to(grid.get_point_position(id))
				best = id
	return best
func path(from: Vector2, to: Vector2, radius: float, parked: Vector2 = Vector2.INF, parked_radius: float = 1.15) -> PackedVector2Array:
	var grid := make_grid(radius,parked,parked_radius)
	return grid.get_point_path(nearest(grid,from),nearest(grid,to))
func boarding(car_point: Vector2) -> Vector2:
	var grid := make_grid(.28,car_point)
	return grid.get_point_position(nearest(grid,car_point+Vector2(-1.4,0)))
func safe_segment(a: Vector2, b: Vector2, radius: float) -> bool:
	for i in range(int(ceil(a.distance_to(b)/.05))+1):
		if not clear_point(a.lerp(b,float(i)/maxf(1,ceil(a.distance_to(b)/.05))),radius):
			return false
	return true

func furniture_clear(point: Vector2, radius: float) -> bool:
	for footprint in [OVEN_FOOTPRINT,TABLE_FOOTPRINT,CHAIR_FOOTPRINT,SECOND_CHAIR]:
		if footprint.grow(radius).has_point(point): return false
	return true

func resident_path(from: Vector2, destination: Vector2, parked: Vector2) -> PackedVector2Array:
	var points := path(from,destination,.28,parked)
	var cursor := from
	for point in points:
		if not safe_segment(cursor,point,.28):
			# An older save can start just inside a clearance margin.
			if cursor!=from or clear_point(from,.28) or not furniture_clear(from,.28) or not safe_segment(from,point,0): return PackedVector2Array()
		cursor = point
	if not points.is_empty() and clear_point(destination,.28) and safe_segment(cursor,destination,.28) and parked.distance_to(destination)>=1.15:
		points.append(destination)
	if cursor.distance_to(destination)>1.0 and (points.is_empty() or points[-1]!=destination): return PackedVector2Array()
	return points
