extends RefCounted

const TRAIL := [Vector2(-8.1,3.8),Vector2(-11,3.8),Vector2(-12,4.5),Vector2(-16,4.5),Vector2(-20,2),Vector2(-24,2),Vector2(-28,-1),Vector2(-32,-1)]
const DRIVE_TRAIL := [Vector2(-7.5,4.5),Vector2(-8.1,3.8),Vector2(-11,3.8),Vector2(-12,4.5),Vector2(-16,4.5),Vector2(-20,2),Vector2(-24,2),Vector2(-28,-1),Vector2(-29.5,-1)]
const DRIVE_LOOPS := [
	[Vector2(-16,4.5),Vector2(-17,7.6),Vector2(-21,7.6),Vector2(-23,5),Vector2(-24,2)],
	[Vector2(-24,2),Vector2(-25,5.2),Vector2(-29,5.2),Vector2(-32,2.5),Vector2(-29.5,-1)]
]
const CLEARING_RADIUS := 1.4
const BENCH_SITES := {"forest_near":Vector2(-16,6.3),"forest_shade":Vector2(-24,.2),"forest_middle":Vector2(-20,.05)}
const CENTER := Vector2(-24,0)

static func drive_edge(a: Vector2, b: Vector2) -> bool:
	for track in [DRIVE_TRAIL]+DRIVE_LOOPS:
		var index: int = track.find(a)
		var other: int = track.find(b)
		if index>=0 and other>=0 and absi(index-other)==1: return true
	return false

static func drive_vertex(point: Vector2) -> bool:
	return point in DRIVE_TRAIL or DRIVE_LOOPS.any(func(track): return point in track)

static func near_drive_loop(point: Vector2, margin: float) -> bool:
	for track in DRIVE_LOOPS:
		for i in range(1,track.size()):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,track[i-1],track[i]))<margin:
				return true
	return false

static func contains_trail_point(point: Vector2) -> bool:
	for i in range(1,TRAIL.size()):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,TRAIL[i-1],TRAIL[i]))<.05:
			return true
	for site in BENCH_SITES.values():
		var entrance: Vector2 = TRAIL[nearest_trail_index(site)]
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,entrance,site))<.05:
			return true
	return false

static func nearest_trail_index(point: Vector2) -> int:
	var best := 0
	for i in range(1,TRAIL.size()):
		if point.distance_squared_to(TRAIL[i])<point.distance_squared_to(TRAIL[best]):
			best = i
	return best
