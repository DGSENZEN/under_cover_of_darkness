extends Node3D
## Real windows at play (the real-windows spec, sections 5-6): from a
## district's window records (LevelLoader's Level.windows, kit_glazing's)
## and its rooms (box markers "room"), the moon's shafts falling in through
## every window it stands in front of and sees, each from the beam's mouth at
## the room's face to where its corners' rays land; and what stands under a
## roof in a shaft made to cast again. Made by DistrictMap once the navmesh
## is in (a physics frame has passed: rays find the level).

const GodRaysScript := preload("res://scripts/Visual/GodRays.gd")
const SightRay := preload("res://scripts/StimuliSystem/SightRay.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

## The moon stands in front of a window when its way into the glass is at
## least this much along the glass's inward normal.
const FACING := 0.1
## Of the 3 x 3 rays from the glass toward the moon, at least this many must
## reach the sky; how far they go.
const SKY_NEEDED := 5
const SKY_REACH := 200.0
## How far a shaft may reach into its room.
const ROOM_REACH := 30.0
## A window's room is the one holding a point this far past the room's face.
const INSIDE := 0.3
const MOON_TINT := Color(0.6, 0.78, 1.25)
## What a shaft's rays pass through: glass, and what lies loose.
const SKIP: Array[StringName] = [&"glass", &"loose"]

## Each window: {piece, lead, outline (the glass's corners), normal (out),
## middle, outside, inside (the wall's faces from the glass), room, facing,
## sky (its share of clear sky), shaft, spot, lamp_shaft}.
var windows: Array[Dictionary] = []
## Each room by name: {transform, size, lamps, lamp, rays, fade}.
var rooms := {}
## The moon's shafts, all of them (one GodRays).
var moon_rays: Node3D = null
## What stood under a roof and stands in a shaft: on the world's layer again.
var recast: Array[GeometryInstance3D] = []

var _levels: Array = []
var _made: Array = []
var _moon: DirectionalLight3D = null


## Reads the levels' windows and rooms (`made`: their LevelGameplay
## records, whose lights are the rooms' lamps) and builds the shafts.
func build(levels: Array, made: Array, moon: DirectionalLight3D) -> void:
	_levels = levels
	_made = made
	_moon = moon
	rooms.clear()
	windows.clear()

	for level in levels:
		for m in level.of("room"):
			if m["size"] == null:
				continue

			rooms[String(m["name"])] = {"transform": m["transform"], "size": m["size"], "lamps": [], "lamp": null, "rays": null, "fade": 0.0}

	for level in levels:
		for raw in level.windows:
			var outline := PackedVector3Array()
			var middle := Vector3.ZERO

			for p in raw["outline"]:
				outline.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
				middle += outline[outline.size() - 1]

			middle /= maxf(float(outline.size()), 1.0)
			var normal := Vector3(float(raw["normal"][0]), float(raw["normal"][1]), float(raw["normal"][2])).normalized()
			var inside := float(raw.get("inside", 0.0))
			windows.append({"piece": String(raw.get("piece", "")), "lead": String(raw.get("lead", "casement")), "outline": outline,
				"normal": normal, "middle": middle, "outside": float(raw.get("outside", 0.0)), "inside": inside,
				"room": room_of(middle - normal * (inside + INSIDE)), "facing": 0.0, "sky": 0.0, "shaft": null, "spot": null, "lamp_shaft": null})

	rebuild()


## The moon's shafts made again (the moon moved): the old ones freed, what
## they made cast put back under its roof first.
func rebuild() -> void:
	for mesh in recast:
		if is_instance_valid(mesh):
			mesh.layers = Layers.ROOFED

	recast.clear()

	if moon_rays != null and is_instance_valid(moon_rays):
		moon_rays.queue_free()

	moon_rays = null

	for w in windows:
		w["shaft"] = null

	if _moon == null or not is_instance_valid(_moon):
		return

	var way := -_moon.global_basis.z.normalized()
	moon_rays = GodRaysScript.new()
	moon_rays.name = "MoonShafts"
	moon_rays.set("direction", way)
	moon_rays.set("tint", MOON_TINT)
	moon_rays.set("least", 0.0)
	add_child(moon_rays)
	var space := get_world_3d().direct_space_state

	for w in windows:
		w["shaft"] = _moon_shaft(space, w, way)

	_recast()


## The smallest room box holding `point` ("" if none).
func room_of(point: Vector3) -> String:
	var best := ""
	var least := INF

	for room_name in rooms:
		var room: Dictionary = rooms[room_name]
		var local: Vector3 = (room["transform"] as Transform3D).affine_inverse() * point
		var half: Vector3 = (room["size"] as Vector3) * 0.5

		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			var volume: float = (room["size"] as Vector3).x * (room["size"] as Vector3).y * (room["size"] as Vector3).z

			if volume < least:
				least = volume
				best = String(room_name)

	return best


# The moon in

func _moon_shaft(space: PhysicsDirectSpaceState3D, w: Dictionary, way: Vector3) -> MeshInstance3D:
	var normal: Vector3 = w["normal"]
	w["facing"] = normal.dot(-way)
	w["sky"] = 0.0

	if float(w["facing"]) <= FACING:
		return null

	var frame := _frame(w)
	var clear := 0

	for fu in [0.2, 0.5, 0.8]:
		for fv in [0.2, 0.5, 0.8]:
			var p: Vector3 = w["middle"] + frame["across"] * lerpf(frame["box"].position.x, frame["box"].end.x, fu) \
				+ frame["up"] * lerpf(frame["box"].position.y, frame["box"].end.y, fv) + normal * 0.05

			if SightRay.first_solid(space, PhysicsRayQueryParameters3D.create(p, p - way * SKY_REACH, 1), SKIP).is_empty():
				clear += 1

	w["sky"] = clear / 9.0

	if clear < SKY_NEEDED:
		return null

	# The beam's mouth at the room's face: the inner opening, less what the
	# outer opening, carried along the moon's way through the wall, shades.
	var depth := float(w["outside"]) + float(w["inside"])
	var through := way * depth / maxf(-way.dot(normal), 0.0001)
	var shifted := PackedVector2Array()

	for q in frame["poly"]:
		shifted.append(q + Vector2(through.dot(frame["across"]), through.dot(frame["up"])))

	var mouth2 := _clip(frame["poly"], shifted)

	if mouth2.size() < 3:
		return null

	var face: Vector3 = w["middle"] - normal * float(w["inside"])
	var mouth := PackedVector3Array()
	var uvs := PackedVector2Array()
	var reaches := PackedFloat32Array()
	var box: Rect2 = frame["box"]

	for q in mouth2:
		var p: Vector3 = face + frame["across"] * q.x + frame["up"] * q.y
		mouth.append(p)
		uvs.append(Vector2((q.x - box.position.x) / maxf(box.size.x, 0.001), (box.end.y - q.y) / maxf(box.size.y, 0.001)))
		var from := p + way * 0.02
		var hit := SightRay.first_solid(space, PhysicsRayQueryParameters3D.create(from, from + way * ROOM_REACH, 1), SKIP)
		reaches.append(0.02 + (from.distance_to(hit["position"]) if not hit.is_empty() else ROOM_REACH))

	return moon_rays.call("add_window", mouth, uvs, reaches, Vector3.INF, float(w["sky"]))


## A window's plane: `across` (along the wall), `up`, its outline about its
## middle in those (counter-clockwise seen from outside), and their box.
func _frame(w: Dictionary) -> Dictionary:
	var normal: Vector3 = w["normal"]
	var across := Vector3.UP.cross(normal)
	across = across.normalized() if across.length() > 0.001 else Vector3.RIGHT
	var up := normal.cross(across)
	var poly := PackedVector2Array()

	for p in w["outline"]:
		poly.append(Vector2((p - w["middle"]).dot(across), (p - w["middle"]).dot(up)))

	if _area(poly) < 0.0:
		poly.reverse()

	var box := Rect2(poly[0], Vector2.ZERO)

	for q in poly:
		box = box.expand(q)

	return {"across": across, "up": up, "poly": poly, "box": box}


## Twice the signed area of `poly` (counter-clockwise positive).
static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0

	for i in poly.size():
		sum += poly[i].cross(poly[(i + 1) % poly.size()])

	return sum


## `subject` less what lies outside the convex, counter-clockwise `clip`
## (Sutherland-Hodgman).
static func _clip(subject: PackedVector2Array, clip: PackedVector2Array) -> PackedVector2Array:
	var out := subject

	for i in clip.size():
		var a := clip[i]
		var b := clip[(i + 1) % clip.size()]
		var given := out
		out = PackedVector2Array()

		for j in given.size():
			var p := given[j]
			var q := given[(j + 1) % given.size()]
			var dp := (b - a).cross(p - a)
			var dq := (b - a).cross(q - a)

			if dp >= 0.0:
				out.append(p)

			if (dp >= 0.0) != (dq >= 0.0):
				out.append(p + (q - p) * (dp / (dp - dq)))

		if out.is_empty():
			break

	return out


## What stands under a roof in a moon shaft casts in moonlight again.
func _recast() -> void:
	var boxes: Array[AABB] = []

	for w in windows:
		if w["shaft"] != null:
			var shaft: MeshInstance3D = w["shaft"]
			boxes.append(shaft.global_transform * shaft.get_aabb())

	if boxes.is_empty():
		return

	for level in _levels:
		if level.root == null or not is_instance_valid(level.root):
			continue

		for node in level.root.find_children("*", "GeometryInstance3D", true, false):
			var mesh := node as GeometryInstance3D

			if mesh.layers != Layers.ROOFED:
				continue

			var bounds := mesh.global_transform * mesh.get_aabb()

			if boxes.any(func(b): return (b as AABB).intersects(bounds)):
				mesh.layers = Layers.WORLD
				recast.append(mesh)
