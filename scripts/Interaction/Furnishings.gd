extends RefCounted
## Furniture for a garrison at its ease, each piece with the places a guard
## uses it from (IdleSpot.gd), for GuardHabits.gd:
##   chair / stool / bench   seats ("seat")
##   table                   a table to sit at: chairs round it, facing it
##   provisions              a counter with bread on it ("table")
##   campfire                a ring of stones and a fire, to tend ("fire")
##   chopping_block          a stump and a pile of logs ("chop")
##   crate_piles             two piles of crates with a way between, each a
##                           "pile": crates are carried from one to the other
##                           (restack puts them all back on the first)
##   cart                    a cart with a wheel to see to ("work")
##   railing                 posts and a bar at forearm height, to lean on
##                           ("rail"), along a walkway's edge
##   lean_spots              places along a wall to lean back on ("lean")
## All static bodies on the world layer: guards walk round them, and the
## navmesh is baked round them (the low ones too: `_keep_off`).
##
##   Furnishings.chair(parent, at, yaw)   at: the middle of the seat, on the
##       floor; yaw: which way the man sitting on it faces (as a node's yaw).

const Props := preload("res://scripts/Interaction/Props.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const IdleSpotScript := preload("res://scripts/Interaction/IdleSpot.gd")

const WOOD := Color(0.36, 0.25, 0.15)
const DARK_WOOD := Color(0.26, 0.18, 0.11)
const STONE := Color(0.42, 0.4, 0.38)
const BREAD := Color(0.62, 0.43, 0.2)
## How high a seat is (its top), and how far in front of it a man's feet
## are when he sits (IdleSpot.SEAT_BACK).
const SEAT_HEIGHT := 0.44
## A railing's bar, at the height a man's forearms rest on it (Idle_Rail).
const RAIL_HEIGHT := 1.0
## Standing at a rail, a man's body is this far back from it (his reach over
## it is the rig's: GuardRig.POSE_SHIFT).
const RAIL_BACK := 0.32
## Leaning on a wall, his heels this far out from it.
const LEAN_OUT := 0.36
## A piece lower than this the navmesh would take for a step up (a seat, a
## stump, the fire's ring) and send men over: the baker is told to keep the
## way round it instead (NavBaker, "nav_blocks").
const LOW := 0.7


## A chair (a stool if `stool`): its seat centred on `at`, and a man on it
## facing `yaw`. Returns its body.
static func chair(parent: Node, at: Vector3, yaw: float, stool := false) -> StaticBody3D:
	var body := _body(parent, "Stool" if stool else "Chair", at, yaw)
	var seat := Vector3(0.44, 0.06, 0.44)
	_part(body, Vector3(0, SEAT_HEIGHT - 0.03, 0), seat, WOOD)

	for x in [-0.18, 0.18]:
		for z in [-0.18, 0.18]:
			_part(body, Vector3(x, (SEAT_HEIGHT - 0.06) * 0.5, z), Vector3(0.05, SEAT_HEIGHT - 0.06, 0.05), DARK_WOOD, false)

	# One box stands for the seat and its legs, to walk round.
	_shape(body, Vector3(0, SEAT_HEIGHT * 0.5, 0), Vector3(0.44, SEAT_HEIGHT, 0.44))

	if not stool:
		# The back, behind the man (+Z, his back).
		_part(body, Vector3(0, SEAT_HEIGHT + 0.3, 0.2), Vector3(0.44, 0.6, 0.05), WOOD)
		_part(body, Vector3(-0.19, SEAT_HEIGHT + 0.3, 0.2), Vector3(0.05, 0.6, 0.06), DARK_WOOD, false)

	_seat_spot(parent, [body], at, yaw)
	return body


## A bench `length` long: seats along it, every man on it facing `yaw`.
static func bench(parent: Node, at: Vector3, yaw: float, length := 1.8) -> StaticBody3D:
	var body := _body(parent, "Bench", at, yaw)
	_part(body, Vector3(0, SEAT_HEIGHT - 0.03, 0), Vector3(length, 0.06, 0.38), WOOD)

	for x in [-length * 0.5 + 0.12, length * 0.5 - 0.12]:
		_part(body, Vector3(x, (SEAT_HEIGHT - 0.06) * 0.5, 0), Vector3(0.06, SEAT_HEIGHT - 0.06, 0.34), DARK_WOOD, false)

	_shape(body, Vector3(0, SEAT_HEIGHT * 0.5, 0), Vector3(length, SEAT_HEIGHT, 0.38))
	var seats := maxi(int(floor(length / 0.7)), 1)

	for i in seats:
		var along := (float(i) + 0.5) / float(seats) * length - length * 0.5
		_seat_spot(parent, [body], at + Basis(Vector3.UP, yaw) * Vector3(along, 0, 0), yaw)

	return body


## A table `size` (width along x, depth along z) at `at`, turned `yaw`, with
## `chairs` chairs round it facing it (two a side at most).
static func table(parent: Node, at: Vector3, yaw: float, size := Vector2(1.6, 0.8), chairs := 4) -> StaticBody3D:
	var body := _body(parent, "Table", at, yaw)
	var top := 0.76
	_part(body, Vector3(0, top - 0.03, 0), Vector3(size.x, 0.06, size.y), WOOD)

	for x in [-size.x * 0.5 + 0.08, size.x * 0.5 - 0.08]:
		for z in [-size.y * 0.5 + 0.08, size.y * 0.5 - 0.08]:
			_part(body, Vector3(x, (top - 0.06) * 0.5, z), Vector3(0.07, top - 0.06, 0.07), DARK_WOOD, false)

	_shape(body, Vector3(0, top * 0.5, 0), Vector3(size.x, top, size.y))
	# A jug and a cup or two.
	_part(body, Vector3(size.x * 0.2, top + 0.09, 0.05), Vector3(0.11, 0.18, 0.11), Color(0.5, 0.45, 0.4), false)
	_part(body, Vector3(-size.x * 0.25, top + 0.05, -0.1), Vector3(0.08, 0.1, 0.08), Color(0.45, 0.38, 0.3), false)
	var turn := Basis(Vector3.UP, yaw)
	var placed := 0

	for side in [1.0, -1.0]:
		for x in [-size.x * 0.25, size.x * 0.25]:
			if placed >= chairs:
				break

			# Behind the chair's seat the man's back; he faces the table.
			var seat := at + turn * Vector3(x, 0, side * (size.y * 0.5 + 0.42))
			var seated_at := chair(parent, seat, yaw + (0.0 if side > 0.0 else PI))
			# Sitting down he goes in under the table's edge too.
			for spot in parent.get_tree().get_nodes_in_group(&"idle_spots"):
				if spot.get_meta(&"bodies", []).has(seated_at):
					spot.set_meta(&"bodies", [seated_at, body])

			placed += 1

	return body


## A counter at waist height with bread on it: a man comes to it, takes some
## and eats it there ("table" spot in front of it, facing it).
static func provisions(parent: Node, at: Vector3, yaw: float) -> StaticBody3D:
	var body := _body(parent, "Provisions", at, yaw)
	var top := 0.98
	_part(body, Vector3(0, top * 0.5, 0), Vector3(1.2, top, 0.5), DARK_WOOD)
	_shape(body, Vector3(0, top * 0.5, 0), Vector3(1.2, top, 0.5))

	for x in [-0.35, -0.1, 0.2]:
		_part(body, Vector3(x, top + 0.05, 0.02), Vector3(0.16, 0.08, 0.1), BREAD, false)

	_part(body, Vector3(0.42, top + 0.08, 0.0), Vector3(0.12, 0.16, 0.12), Color(0.5, 0.45, 0.4), false)
	# He stands before its front (-Z of the counter), facing it (+Z).
	var front := at + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.62)
	IdleSpotScript.build(parent, &"table", front, yaw + PI)
	return body


## A fire in a ring of stones, and places round it to crouch and tend it.
static func campfire(parent: Node, at: Vector3, spots := 3) -> Node3D:
	var body := _body(parent, "Campfire", at, 0.0)

	for i in 8:
		var angle := TAU * float(i) / 8.0
		_part(body, Vector3(cos(angle) * 0.3, 0.06, sin(angle) * 0.3), Vector3(0.14, 0.12, 0.12), STONE, false)

	_part(body, Vector3(0, 0.05, 0), Vector3(0.36, 0.06, 0.08), DARK_WOOD, false)
	_part(body, Vector3(0, 0.07, 0), Vector3(0.08, 0.06, 0.36), DARK_WOOD, false)
	_shape(body, Vector3(0, 0.1, 0), Vector3(0.7, 0.2, 0.7))
	var flame: Node3D = TorchScript.new()
	flame.energy = 2.2
	flame.light_range = 7.0
	flame.flame_size = 0.5
	flame.shadows = false
	body.add_child(flame)
	flame.position = Vector3(0, 0.22, 0)

	for i in spots:
		var angle := TAU * float(i) / float(spots) + 0.4
		var out := Vector3(cos(angle), 0, sin(angle))
		# Kneeling, his hands are half a metre ahead of him: on the fire.
		_spot_facing(parent, &"fire", at + out * 0.78, -out)

	return body


## A stump to split logs on, and the logs; a man comes to it with an axe
## ("chop" spot facing it, from `yaw`).
static func chopping_block(parent: Node, at: Vector3, yaw: float) -> StaticBody3D:
	var body := _body(parent, "ChoppingBlock", at, yaw)
	var stump := CylinderMesh.new()
	stump.top_radius = 0.26
	stump.bottom_radius = 0.3
	stump.height = 0.45
	var drawn := MeshInstance3D.new()
	drawn.mesh = stump
	drawn.material_override = Props.material(DARK_WOOD)
	body.add_child(drawn)
	drawn.position = Vector3(0, 0.225, 0)
	_shape(body, Vector3(0, 0.225, 0), Vector3(0.55, 0.45, 0.55))

	# The pile beside it.
	for i in 5:
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.09
		log_mesh.bottom_radius = 0.09
		log_mesh.height = 0.55
		var wood := MeshInstance3D.new()
		wood.mesh = log_mesh
		wood.material_override = Props.material(WOOD)
		body.add_child(wood)
		wood.position = Vector3(0.75 + (i % 3) * 0.19 - 0.19, 0.09 + float(i / 3) * 0.17, 0.1 + float(i / 3) * 0.1)
		wood.rotation = Vector3(PI * 0.5, 0.0, 0.0)

	_shape(body, Vector3(0.75, 0.2, 0.15), Vector3(0.6, 0.4, 0.6))
	# The blow lands 0.7 m ahead of him.
	IdleSpotScript.build(parent, &"chop", at + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.72), yaw)
	return body


## Crates stacked at `from`, a store at `to` (both "pile" spots, each the
## other's partner): a man carries them one at a time to whichever has
## fewer. Returns the crates.
static func crate_piles(parent: Node, from: Vector3, from_yaw: float, to: Vector3, to_yaw: float, count := 4) -> Array:
	var crates := []
	var turn := Basis(Vector3.UP, from_yaw)

	for i in count:
		var crate: RigidBody3D = Props.crate(parent, from + turn * _stacked(i), 0.42, 4.0)
		crate.add_to_group(&"stock")
		crates.append(crate)

	var a := IdleSpotScript.build(parent, &"pile", from, from_yaw)
	var b := IdleSpotScript.build(parent, &"pile", to, to_yaw)
	a.set_meta(&"other", b)
	b.set_meta(&"other", a)
	return crates


## `crates` (crate_piles') stacked again before `from` as they first were,
## wherever they have been carried or dropped since.
static func restack(crates: Array, from: Vector3, from_yaw: float) -> void:
	var turn := Basis(Vector3.UP, from_yaw)
	var i := 0

	for crate in crates:
		if not is_instance_valid(crate) or not (crate is RigidBody3D):
			continue

		var body := crate as RigidBody3D
		body.global_transform = Transform3D(turn, from + turn * _stacked(i))
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.reset_physics_interpolation()
		i += 1


## Where the `i`th crate of a pile sits, in its place's space: two by two
## before it (its -Z), where a man there reaches.
static func _stacked(i: int) -> Vector3:
	return Vector3((i % 2) * 0.5 - 0.25, 0.22 + float(i / 2) * 0.44, -0.75)


## A cart, one wheel to see to ("work" spot kneeling at it).
static func cart(parent: Node, at: Vector3, yaw: float) -> StaticBody3D:
	var body := _body(parent, "Cart", at, yaw)
	_part(body, Vector3(0, 0.75, 0), Vector3(1.2, 0.3, 2.0), WOOD)
	_part(body, Vector3(0, 1.0, 0.95), Vector3(1.2, 0.3, 0.06), DARK_WOOD, false)
	_shape(body, Vector3(0, 0.6, 0), Vector3(1.2, 1.2, 2.0))

	for side in [-1.0, 1.0]:
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.42
		wheel.bottom_radius = 0.42
		wheel.height = 0.08
		var drawn := MeshInstance3D.new()
		drawn.mesh = wheel
		drawn.material_override = Props.material(DARK_WOOD)
		body.add_child(drawn)
		drawn.position = Vector3(side * 0.66, 0.42, 0.1)
		drawn.rotation = Vector3(0.0, 0.0, PI * 0.5)

	# Kneeling at the right wheel, facing it.
	IdleSpotScript.build(parent, &"work", at + Basis(Vector3.UP, yaw) * Vector3(1.25, 0, 0.1), yaw + PI * 0.5)
	return body


## A railing from `from` to `to` (on the floor), its bar at RAIL_HEIGHT;
## places to lean on it every `every` metres, facing across it toward `out`.
static func railing(parent: Node, from: Vector3, to: Vector3, out: Vector3, every := 1.6) -> StaticBody3D:
	var along := to - from
	along.y = 0.0
	var length := along.length()
	var yaw := atan2(-along.x, -along.z) + PI * 0.5
	var body := _body(parent, "Railing", (from + to) * 0.5, yaw)
	# Built along its own x.
	_part(body, Vector3(0, RAIL_HEIGHT - 0.04, 0), Vector3(length, 0.08, 0.1), WOOD)
	_part(body, Vector3(0, RAIL_HEIGHT * 0.5, 0), Vector3(length, 0.05, 0.05), DARK_WOOD, false)
	var posts := maxi(int(ceil(length / 1.2)), 1)

	for i in posts + 1:
		_part(body, Vector3(-length * 0.5 + length * float(i) / float(posts), RAIL_HEIGHT * 0.5, 0), Vector3(0.08, RAIL_HEIGHT, 0.08), DARK_WOOD, false)

	_shape(body, Vector3(0, RAIL_HEIGHT * 0.5, 0), Vector3(length, RAIL_HEIGHT, 0.1))
	var facing := Vector3(out.x, 0, out.z).normalized()
	var spots := maxi(int(floor(length / every)), 1)

	for i in spots:
		var on := from + along * ((float(i) + 0.5) / float(spots))
		_spot_facing(parent, &"rail", on - facing * RAIL_BACK, facing)

	return body


## Places to lean back on a wall, its face running from `from` to `to`, its
## side facing `out` (the way a man leaning on it looks).
static func lean_spots(parent: Node, from: Vector3, to: Vector3, out: Vector3, every := 2.0) -> Array:
	var facing := Vector3(out.x, 0, out.z).normalized()
	var along := to - from
	along.y = 0.0
	var count := maxi(int(floor(along.length() / every)), 1)
	var spots := []

	for i in count:
		var on := from + along * ((float(i) + 0.5) / float(count))
		spots.append(_spot_facing(parent, &"lean", on + facing * LEAN_OUT, facing))

	return spots


# ---------------------------------------------------------------------------

static func _body(parent: Node, body_name: String, at: Vector3, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.set_meta(&"surface", "wood")
	parent.add_child(body)
	body.global_position = at
	body.rotation.y = yaw
	return body


## A drawn box on `body`, at `at` in its space.
static func _part(body: Node3D, at: Vector3, size: Vector3, color: Color, shaded := true) -> MeshInstance3D:
	var part := Props.mesh_box(size, color)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shaded else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(part)
	part.position = at
	return part


static func _shape(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := Props.shape_box(size)
	body.add_child(shape)
	shape.position = at

	if at.y + size.y * 0.5 < LOW:
		_keep_off(body, at, size)


## Marks the box `size` at `at` (in `body`'s space) as ground to go round
## for the next bake (NavBaker): its outline seen from above, where it
## stands, and how high over that to keep off.
static func _keep_off(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var corners := PackedVector3Array()

	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		corners.append(body.global_transform * (at + Vector3(corner.x * size.x * 0.5, 0.0, corner.y * size.z * 0.5)))

	var blocks: Array = body.get_meta(&"nav_blocks", [])
	blocks.append({"corners": corners, "bottom": (body.global_transform * (at - Vector3(0, size.y * 0.5, 0))).y, "height": size.y + 1.0})
	body.set_meta(&"nav_blocks", blocks)
	body.add_to_group(&"nav_blocks")


## The seat spot for a seat centred on `seat_at`: his feet SEAT_BACK in front
## of it, facing `yaw`. `bodies`: what he goes in among to sit (the seat, a
## table's edge), let through as he does.
static func _seat_spot(parent: Node, bodies: Array, seat_at: Vector3, yaw: float) -> Node3D:
	var forward := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var spot := IdleSpotScript.build(parent, &"seat", seat_at + forward * IdleSpotScript.SEAT_BACK, yaw)
	spot.set_meta(&"bodies", bodies)
	return spot


## A spot of `kind` at `where`, the man there facing `facing`.
static func _spot_facing(parent: Node, kind: StringName, where: Vector3, facing: Vector3) -> Node3D:
	return IdleSpotScript.build(parent, kind, where, atan2(-facing.x, -facing.z))
