class_name PlaceZones
extends RefCounted
## Where you are, for a place score (PlaceScore): the map's plan (its spaces'
## floor polygons, floors, heights, layers and openings) turned into how much
## each theme should sound at a point, and how deep the point is.
## - A space plays its theme (score.json `spaces`); an unmapped space plays the
##   theme of the nearest mapped space it opens from, through its openings.
## - Within THRESHOLD of an opening onto another theme, both sound: half and
##   half on the opening itself, the far side fading out THRESHOLD in.
## - A circle (her stall in the lane) is a small space inside a bigger one:
##   all its own within `full` of its middle, nothing past `radius`; as it
##   comes in, the space it sits in leans toward it (down to 1 - LEAN).
## - Depth is the space's age (its plan layer), not its height; only in the
##   old layer does going further down deepen it more.

const THRESHOLD := 3.0
const LEAN := 0.6
const LAYER_DEPTH := {1: 0.0, 2: 0.35, 3: 0.7}
const DEEP_FROM := -21.0
const DEEPEST := -26.0
## A point this far under a floor still stands on it (steps, the floor's own slop).
const UNDER := 0.5

var _spaces := {}
var _themes := {}
var _circles: Array = []


static func from_plan(plan: Dictionary, spaces: Dictionary, circles: Array) -> PlaceZones:
	var zones := PlaceZones.new()
	for space in plan.get("spaces", []):
		var polygon := PackedVector2Array()
		for corner in space.polygon:
			polygon.append(Vector2(float(corner[0]), float(corner[1])))
		zones._spaces[String(space.name)] = {
			"polygon": polygon, "floor": float(space.floor), "height": float(space.get("height", 4.0)),
			"layer": int(space.get("layer", 1)), "openings": space.get("openings", [])}
	for name in zones._spaces:
		zones._themes[name] = zones._resolve(name, spaces)
	zones._circles = circles
	return zones


## The space a point stands in: inside its polygon and between its floor and
## ceiling; of stacked spaces, the highest floor under the point. "" in none.
func space_at(point: Vector3) -> String:
	var best := ""
	var best_floor := -INF
	var flat := Vector2(point.x, point.z)
	for name in _spaces:
		var space: Dictionary = _spaces[name]
		var floor_y: float = space.floor
		if point.y < floor_y - UNDER or point.y > floor_y + float(space.height):
			continue
		if floor_y <= best_floor or not Geometry2D.is_point_in_polygon(flat, space.polygon):
			continue
		best = name
		best_floor = floor_y
	return best


## The theme a space plays: its own, or that of the nearest mapped space it opens from.
func theme_of(space: String) -> String:
	return String(_themes.get(space, ""))


## {theme: weight 0..1} at a point ("" for a space with no theme); {} when it stands in no space.
func weights_at(point: Vector3) -> Dictionary:
	var by_space := _space_weights(point)
	var weights := {}
	for name in by_space:
		# A space with no theme still counts, under "": standing there is somewhere,
		# and the themes around fade out (no space at all returns {}).
		var theme := theme_of(name)
		weights[theme] = float(weights.get(theme, 0.0)) + float(by_space[name])
	for circle in _circles:
		var inside := theme_of(String(circle.get("inside", "")))
		var middle := Vector3(float(circle.at[0]), float(circle.at[1]), float(circle.at[2]))
		var d := Vector2(point.x - middle.x, point.z - middle.z).length()
		var amount := smoothstep(float(circle.radius), float(circle.full), d)
		if amount <= 0.0 or not weights.has(inside):
			continue
		weights[inside] = float(weights[inside]) * (1.0 - LEAN * amount)
		weights[String(circle.theme)] = maxf(float(weights.get(String(circle.theme), 0.0)), amount)
	return weights


## 0 (the station) .. 1 (the bottom of the old layer) at a point; 0 in no space.
func depth_at(point: Vector3) -> float:
	var by_space := _space_weights(point)
	var depth := 0.0
	for name in by_space:
		depth += float(by_space[name]) * _depth_of(name, point.y)
	return depth


func _depth_of(name: String, y: float) -> float:
	var layer := int(_spaces[name].layer)
	var depth := float(LAYER_DEPTH.get(layer, 0.0))
	if layer == 3:
		depth += 0.3 * clampf((DEEP_FROM - y) / (DEEP_FROM - DEEPEST), 0.0, 1.0)
	return depth


## {space: weight}: the space stood in, and across its openings' thresholds
## the spaces beyond (those playing another theme).
func _space_weights(point: Vector3) -> Dictionary:
	var here := space_at(point)
	if here.is_empty():
		return {}
	var weights := {here: 1.0}
	var space: Dictionary = _spaces[here]
	var flat := Vector2(point.x, point.z)
	for opening in space.openings:
		var beyond := String(opening.to)
		if not _spaces.has(beyond) or theme_of(beyond) == theme_of(here):
			continue
		var d := _distance_to_opening(flat, space.polygon, opening)
		if d >= THRESHOLD:
			continue
		var share := 0.5 * (1.0 - d / THRESHOLD)
		weights[beyond] = float(weights.get(beyond, 0.0)) + share
		weights[here] = float(weights[here]) - share
	return weights


## How far a point is from an opening: a gap `width` wide centred on `at`,
## along the polygon edge it lies on.
func _distance_to_opening(point: Vector2, polygon: PackedVector2Array, opening: Dictionary) -> float:
	var at := Vector2(float(opening.at[0]), float(opening.at[1]))
	var along := Vector2.RIGHT
	var closest := INF
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var d := at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))
		if d < closest and a != b:
			closest = d
			along = (b - a).normalized()
	var half := along * float(opening.get("width", 1.0)) * 0.5
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, at - half, at + half))


## Breadth-first through the openings to the nearest space with a theme.
func _resolve(start: String, spaces: Dictionary) -> String:
	var seen := {start: true}
	var queue: Array[String] = [start]
	while not queue.is_empty():
		var name: String = queue.pop_front()
		if spaces.has(name):
			return String(spaces[name])
		for opening in _spaces[name].openings:
			var next := String(opening.to)
			if _spaces.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return ""
