extends RefCounted

const CENTER := Vector2(1.23,-2.50)
const LENGTH := 1.92
const SURFACE := .29
const FLOWER := Vector2(CENTER.x,-3.07)

const MATERIALS := Vector2(CENTER.x,-2.39)
const HARVEST := Vector2(CENTER.x,-1.88)

static func base_height(world) -> float:
	return world._height(CENTER.x,CENTER.y)
