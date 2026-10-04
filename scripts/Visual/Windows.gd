extends Node3D
## Real windows at play (the real-windows spec, sections 5-6): from a
## district's window records (LevelLoader's Level.windows, kit_glazing's)
## and its rooms (box markers "room"), the moon's shafts falling in through
## every window it stands in front of and sees, each from the beam's mouth at
## the room's face to where its corners' rays land; what stands under a roof
## in a shaft made to cast again; and a lit room's nearest lamp thrown out
## through its glass (a warm shaft spreading from it, a window-shaped patch
## on what is outside), following the lamp as it is doused and relit. Made by
## DistrictMap once the navmesh is in (a physics frame has passed: rays find
## the level).

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
## A window's shafts are dust caught in a little light, not the chapel's
## coloured columns: fainter, soft to their edges (a face whole only seen
## square-on), the moon's dimming along their length, a lamp's fast.
const MOON_GAIN := 0.05
const SOFT_EDGE := Vector2(0.55, 1.0)
const MOON_FALL := 1.0
const LAMP_FALL := 2.5
## What a shaft's rays pass through: glass, and what lies loose.
const SKIP: Array[StringName] = [&"glass", &"loose"]
## A lamp's light out through its window: its shaft's reach; its patch, a
## spot this far out from the wall's face, its cone the glass seen from the
## lamp and this much more (degrees), its range, its share of the lamp's
## energy; how fast both follow the lamp (s); how often the lamps are looked
## at (s); the shaft's colour and gain.
const OUT_REACH := 4.0
const SPOT_OUT := 0.05
const SPOT_PAD := 4.0
const SPOT_RANGE := 8.0
const SPOT_GAIN := 0.5
const FADE := 0.3
const POLL := 0.25
const LAMP_TINT := Color(1.0, 0.62, 0.3)
const LAMP_GAIN := 0.03
## A lit window's glow from within (its reveal warm, seen from outside even
## where the lamp is far from the glass): this far inside the room's face,
## this reach, this share of the lamp's energy. For show: it lights no one up.
const GLOW_IN := 0.35
const GLOW_RANGE := 1.4
const GLOW_GAIN := 0.35

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
var _poll := 0.0


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

			rooms[String(m["name"])] = {"transform": m["transform"], "size": m["size"], "lamps": [], "lamp": null, "rays": null, "fade": 0.0,
				"built_for": null}

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
				"room": room_of(middle - normal * (inside + INSIDE)), "facing": 0.0, "sky": 0.0, "shaft": null, "spot": null, "lamp_shaft": null, "glow": null})

	# Each room's lamps: the lights standing in it.
	for record in made:
		for lamp in (record as Dictionary).get("lights", {}).values():
			if lamp == null or not is_instance_valid(lamp) or not (lamp as Node).has_method("is_lit"):
				continue

			var room := room_of((lamp as Node3D).global_position)

			if room == "":
				continue

			rooms[room]["lamps"].append(lamp)

			if (lamp as Node).has_signal("lit_changed"):
				(lamp as Node).connect("lit_changed", _lamp_changed.bind(room))

	rebuild()

	for room in rooms:
		_pick(room)


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
	moon_rays.set("gain", MOON_GAIN)
	moon_rays.set("edge_from", SOFT_EDGE.x)
	moon_rays.set("edge_to", SOFT_EDGE.y)
	moon_rays.set("fall_power", MOON_FALL)
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


# A lamp out

func _process(delta: float) -> void:
	_poll -= delta

	if _poll <= 0.0:
		_poll = POLL

		# (A lamp's state restored without a word, a lamp gone: caught here.)
		for room in rooms:
			_pick(room)

	for room_name in rooms:
		var room: Dictionary = rooms[room_name]

		if room["rays"] == null:
			continue

		room["fade"] = move_toward(float(room["fade"]), 1.0 if room["lamp"] != null else 0.0, delta / FADE)
		var made_for: Variant = room["built_for"]
		var light: Light3D = (made_for as Node).get("light") if made_for != null and is_instance_valid(made_for) else null
		var energy := light.light_energy if light != null and is_instance_valid(light) else 0.0
		(room["rays"] as Node3D).set("strength", float(room["fade"]))

		for w in windows:
			if w["room"] != room_name:
				continue

			if w["spot"] != null and is_instance_valid(w["spot"]):
				(w["spot"] as SpotLight3D).light_energy = SPOT_GAIN * energy * float(room["fade"])

			if w["glow"] != null and is_instance_valid(w["glow"]):
				(w["glow"] as OmniLight3D).light_energy = GLOW_GAIN * energy * float(room["fade"])


func _lamp_changed(_lit: bool, room: String) -> void:
	_pick(room)


## The room's lit lamp nearest its windows (or none); its light made out
## through them again when it is another lamp than they were made for.
func _pick(room_name: String) -> void:
	var room: Dictionary = rooms[room_name]
	var lamps: Array = room["lamps"]

	if lamps.is_empty():
		return

	var at := Vector3.ZERO
	var count := 0

	for w in windows:
		if w["room"] == room_name:
			at += w["middle"]
			count += 1

	if count == 0:
		return

	at /= float(count)
	var best: Node3D = null

	for lamp in lamps:
		if is_instance_valid(lamp) and bool((lamp as Node).call("is_lit")):
			if best == null or (lamp as Node3D).global_position.distance_to(at) < best.global_position.distance_to(at):
				best = lamp

	room["lamp"] = best

	if best != null and best != room["built_for"]:
		_light_out(room_name, best)


## The room's windows lit from `lamp`: a warm shaft from it through each
## one's mouth at the wall's outer face, a patch thrown on what is outside.
func _light_out(room_name: String, lamp: Node3D) -> void:
	var room: Dictionary = rooms[room_name]

	if room["rays"] != null and is_instance_valid(room["rays"]):
		(room["rays"] as Node).queue_free()

	var rays: Node3D = GodRaysScript.new()
	rays.name = "LampShafts_%s" % room_name
	rays.set("follow_moon", false)
	rays.set("tint", LAMP_TINT)
	rays.set("gain", LAMP_GAIN)
	rays.set("edge_from", SOFT_EDGE.x)
	rays.set("edge_to", SOFT_EDGE.y)
	rays.set("fall_power", LAMP_FALL)
	add_child(rays)
	rays.set("strength", 0.0)
	room["rays"] = rays
	room["built_for"] = lamp
	var light: Light3D = lamp.get("light")
	var source := light.global_position if light != null and is_instance_valid(light) else lamp.global_position
	var space := get_world_3d().direct_space_state

	for w in windows:
		if w["room"] != room_name:
			continue

		for key in ["spot", "glow"]:
			if w[key] != null and is_instance_valid(w[key]):
				(w[key] as Node).queue_free()

			w[key] = null

		w["lamp_shaft"] = null
		var normal: Vector3 = w["normal"]
		var middle: Vector3 = w["middle"]
		var toward := middle - source

		if toward.dot(normal) <= 0.0:
			continue

		var frame := _frame(w)
		var spot := SpotLight3D.new()
		spot.name = "WindowLamp"
		spot.light_color = light.light_color if light != null else Color(1.0, 0.7, 0.4)
		spot.light_energy = 0.0
		spot.spot_range = SPOT_RANGE
		spot.spot_angle = rad_to_deg(atan((frame["box"] as Rect2).size.length() * 0.5 / maxf(toward.length(), 0.01))) + SPOT_PAD
		# (No projector: the engine draws one only through a shadow, and a
		# shadowed light a window costs too much. A soft warm patch; the probe
		# counts it unshadowed, as it is drawn.)
		spot.shadow_enabled = false
		spot.spot_angle_attenuation = 1.6
		spot.set_meta(&"casts_shadow", false)
		add_child(spot)
		spot.global_position = middle + normal * (float(w["outside"]) + SPOT_OUT)
		var aim := toward.normalized()
		spot.look_at(spot.global_position + aim, Vector3.UP if absf(aim.y) < 0.99 else Vector3.FORWARD)
		w["spot"] = spot
		w["lamp_shaft"] = _lamp_shaft(space, w, frame, source, rays)
		var glow := OmniLight3D.new()
		glow.name = "WindowGlow"
		glow.light_color = spot.light_color
		glow.light_energy = 0.0
		glow.omni_range = GLOW_RANGE
		glow.shadow_enabled = false
		# (For show: the probe and the lightgem leave it out.)
		glow.add_to_group(&"fx_light")
		glow.light_cull_mask = Layers.ALL_BUT_PROBE
		add_child(glow)
		glow.global_position = middle - normal * (float(w["inside"]) + GLOW_IN)
		w["glow"] = glow


## A lamp's shaft out through a window: its mouth at the wall's outer face
## (the outer opening, less what the inner opening, seen from the lamp,
## shades), each corner going on away from the lamp to what it meets (the
## water's top counts) or OUT_REACH.
func _lamp_shaft(space: PhysicsDirectSpaceState3D, w: Dictionary, frame: Dictionary, source: Vector3, rays: Node3D) -> MeshInstance3D:
	var normal: Vector3 = w["normal"]
	var middle: Vector3 = w["middle"]
	var outside := float(w["outside"])
	var inside := float(w["inside"])
	var depth := (source - middle).dot(normal)

	if depth >= -inside:
		return null

	# Each inner corner carried from the lamp onto the outer face.
	var seen := PackedVector2Array()
	var lamp2 := Vector2((source - middle).dot(frame["across"]), (source - middle).dot(frame["up"]))
	var t := (outside - depth) / (-inside - depth)

	for q in frame["poly"]:
		seen.append(lamp2 + (q - lamp2) * t)

	var mouth2 := _clip(frame["poly"], seen)

	if mouth2.size() < 3:
		return null

	var face: Vector3 = middle + normal * outside
	var box: Rect2 = frame["box"]
	var mouth := PackedVector3Array()
	var uvs := PackedVector2Array()
	var reaches := PackedFloat32Array()

	for q in mouth2:
		var p: Vector3 = face + frame["across"] * q.x + frame["up"] * q.y
		var way := (p - source).normalized()
		mouth.append(p)
		uvs.append(Vector2((q.x - box.position.x) / maxf(box.size.x, 0.001), (box.end.y - q.y) / maxf(box.size.y, 0.001)))
		var from := p + way * 0.02
		var hit := SightRay.first_solid(space, PhysicsRayQueryParameters3D.create(from, from + way * OUT_REACH, 1), SKIP)
		var reach := 0.02 + (from.distance_to(hit["position"]) if not hit.is_empty() else OUT_REACH)

		# (Over water, its top.)
		for water in get_tree().get_nodes_in_group(&"water"):
			if way.y < -0.001 and water.has_method("over") and bool(water.call("over", p)):
				var down := (p.y - float(water.call("surface_y"))) / -way.y

				if down > 0.0:
					reach = minf(reach, down)

		reaches.append(reach)

	return rays.call("add_window", mouth, uvs, reaches, source)


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
