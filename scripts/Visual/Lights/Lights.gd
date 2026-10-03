extends RefCounted
## Fixture builders. Placed builders add the result to parent; carried_torch()/carried_lantern() return unparented fixtures.
## overrides replace Torch export values after recipe settings. Wall/ground helpers align fixture sockets to world points.

const LightFixtureScript := preload("res://scripts/Visual/Lights/LightFixture.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")

## How far from a torch's flame torch_at looks for a wall, and down for a floor.
const WALL_REACH := 0.5
const FLOOR_REACH := 3.2
## A little further than FLOOR_REACH, so a floor just at it is found.
const FLOOR_MARGIN := 0.05
## A pole cresset's pole is never shorter than this.
const SHORTEST_POLE := 0.6


## Returns an added/placed LightFixture at world at with yaw in radians and a dynamic overrides Dictionary.
## Override keys name Torch/fixture settings; missing recipe/model reports an error and leaves available burner behavior.
static func make(parent: Node, fixture: StringName, at: Vector3, yaw := 0.0, overrides := {}) -> Node3D:
	var node: Node3D = LightFixtureScript.new()
	node.name = String(fixture).to_pascal_case()
	node.fixture = fixture
	node.overrides = overrides
	parent.add_child(node)
	node.global_position = at
	node.global_rotation = Vector3(0.0, yaw, 0.0)
	return node


## A torch in its sconce on a wall facing `wall_normal`, its flame at
## `flame_at` (its plate lands on the wall behind: put the flame out from
## the wall by the sconce's reach).
static func wall_torch(parent: Node, flame_at: Vector3, wall_normal: Vector3, overrides := {}) -> Node3D:
	return on_wall(parent, &"wall_torch", flame_at, wall_normal, overrides)


## A wall fixture placed by where its flame is and which way its wall faces.
static func on_wall(parent: Node, fixture: StringName, flame_at: Vector3, wall_normal: Vector3, overrides := {}) -> Node3D:
	var yaw := yaw_facing(wall_normal)
	var flame_local := _socket(fixture, "flame")
	return make(parent, fixture, flame_at - Basis(Vector3.UP, yaw) * flame_local, yaw, overrides)


## A torch where a level had a bare one: lit at once where its flame was
## (the returned burner), and on its second physics tick, once the level's
## walls are in the physics space, made into a fixture that fits the place:
## a wall torch on a wall within WALL_REACH (its plate on the wall, so its
## flame stands out by the sconce's reach), else a pole cresset on a floor
## within FLOOR_REACH below (its pole fitted to put the flame where it was),
## else it stays a bare flame and says so. Only static world geometry
## counts: never a door, a man or another light. `overrides` are more burner
## settings, on both (a level's own torch: {"can_douse": true}).
static func torch_at(parent: Node, flame_at: Vector3, energy := 2.4, light_range := 9.0, shadows := true, overrides := {}) -> Node3D:
	var bare: Node3D = TorchScript.new()
	bare.energy = energy
	bare.light_range = light_range
	bare.shadows = shadows

	for key in overrides:
		bare.set(key, overrides[key])

	parent.add_child(bare)
	bare.global_position = flame_at
	var resolver := Resolver.new()
	resolver.bare = bare
	resolver.flame_at = flame_at
	resolver.settings = {"energy": energy, "light_range": light_range, "shadows": shadows}
	resolver.settings.merge(overrides, true)
	bare.add_child(resolver)
	return bare


## Returns an unparented torch fixture for hand attachment; caller owns parenting and lifetime.
static func carried_torch() -> Node3D:
	var node: Node3D = LightFixtureScript.new()
	node.name = "RoundsLight"
	node.fixture = &"carried_torch"
	return node


## Returns an unparented lantern fixture for hand attachment; caller owns parenting and lifetime.
static func carried_lantern() -> Node3D:
	var node: Node3D = LightFixtureScript.new()
	node.name = "Lantern"
	node.fixture = &"carried_lantern"
	return node


## A lantern hung `chain` metres below a hook at `hook_at`; it swings in the wind.
static func hanging_lantern(parent: Node, hook_at: Vector3, chain := 0.6, overrides := {}) -> Node3D:
	var settings := overrides.duplicate()
	settings["hang_drop"] = chain
	return make(parent, &"hanging_lantern", hook_at, 0.0, settings)


## A box lantern on a bracket, its plate at `mount_at` on a wall facing `wall_normal`.
static func wall_lantern(parent: Node, mount_at: Vector3, wall_normal: Vector3, overrides := {}) -> Node3D:
	return make(parent, &"wall_lantern", mount_at, yaw_facing(wall_normal), overrides)


## A lamp post standing on `foot_at`, its arm out along its +Z turned by `yaw`.
static func lamp_post(parent: Node, foot_at: Vector3, yaw := 0.0, overrides := {}) -> Node3D:
	return make(parent, &"lamp_post", foot_at, yaw, overrides)


## A candle `height` centimetres tall (6, 10 or 16) standing on `at`.
static func candle(parent: Node, at: Vector3, height := 10, overrides := {}) -> Node3D:
	return make(parent, StringName("candle_%d" % height), at, 0.0, overrides)


## A candlestick ("iron" pricket or "brass" socket) with its candle, on `at`.
static func candlestick(parent: Node, at: Vector3, variant := &"iron", overrides := {}) -> Node3D:
	return make(parent, StringName("candlestick_%s" % variant), at, 0.0, overrides)


## A brass candelabra of 3 or 5 candles standing on `at`, its arms along its X.
static func candelabra(parent: Node, at: Vector3, arms := 3, yaw := 0.0, overrides := {}) -> Node3D:
	return make(parent, StringName("candelabra_%d" % arms), at, yaw, overrides)


## An iron hoop of 6 or 8 candles hung `chain` metres below a hook at `hook_at`.
static func chandelier(parent: Node, hook_at: Vector3, candles := 6, chain := 1.0, overrides := {}) -> Node3D:
	var settings := overrides.duplicate()
	settings["hang_drop"] = chain
	return make(parent, StringName("chandelier_%d" % candles), hook_at, 0.0, settings)


## An oil lamp: "clay" standing on `at`, or "hanging" from a hook at `at`
## (`chain` metres more below it).
static func oil_lamp(parent: Node, at: Vector3, variant := &"clay", yaw := 0.0, chain := 0.0, overrides := {}) -> Node3D:
	var settings := overrides.duplicate()

	if chain > 0.0:
		settings["hang_drop"] = chain

	return make(parent, StringName("oil_lamp_%s" % variant), at, yaw, settings)


## A tripod brazier standing on `at` (the look alone: Fire.brazier makes the
## hazard round one).
static func brazier(parent: Node, at: Vector3, overrides := {}) -> Node3D:
	return make(parent, &"brazier", at, 0.0, overrides)


## A campfire in its ring of stones on `at`.
static func campfire(parent: Node, at: Vector3, overrides := {}) -> Node3D:
	return make(parent, &"campfire", at, 0.0, overrides)


## A stone hearth, its back on a wall at `at`, opening along its +Z turned by `yaw`.
static func hearth(parent: Node, at: Vector3, yaw := 0.0, overrides := {}) -> Node3D:
	return make(parent, &"hearth", at, yaw, overrides)


## A cresset: "pole" standing on `at` (its foot), or "wall" on its bracket
## (`at` its plate, turned by `yaw`).
static func cresset(parent: Node, at: Vector3, variant := &"pole", yaw := 0.0, overrides := {}) -> Node3D:
	return make(parent, StringName("cresset_%s" % variant), at, yaw, overrides)


## torch_at's work, on the bare torch's first physics tick.
class Resolver:
	extends Node

	const FixtureScript := preload("res://scripts/Visual/Lights/LightFixture.gd")

	var bare: Node3D
	var flame_at := Vector3.ZERO
	var settings := {}
	## Bodies added this frame are only in the physics space once it has
	## stepped: wait this many ticks.
	var _wait := 2

	func _physics_process(_delta: float) -> void:
		_wait -= 1

		if _wait > 0:
			return

		set_physics_process(false)
		var parent := bare.get_parent()
		var space := bare.get_world_3d().direct_space_state
		var wall := _wall(space)
		var built: Node3D = null

		if not wall.is_empty():
			var normal: Vector3 = wall["normal"]
			normal = Vector3(normal.x, 0.0, normal.z).normalized()
			var yaw := atan2(normal.x, normal.z)
			var flame_local := _socket(&"wall_torch", "flame")
			built = _make(parent, &"wall_torch", Vector3(wall["position"].x, flame_at.y - flame_local.y, wall["position"].z), yaw, settings)
		else:
			var floor := _floor(space)
			var high := _socket(&"cresset_pole", "flame").y

			if not floor.is_empty() and flame_at.y - floor["position"].y - high > SHORTEST_POLE - 2.4:
				var fitted := settings.duplicate()
				fitted["stretch"] = flame_at.y - floor["position"].y - high
				built = _make(parent, &"cresset_pole", floor["position"], 0.0, fitted)
			else:
				push_warning("Lights.torch_at: nothing to stand a torch on at %s: a bare flame" % flame_at)

		if built != null:
			built.set("can_douse", bare.get("can_douse"))

			# A level's light (LevelGameplay.lights): the fixture takes the
			# flame's name and its place in the level's lights.
			if bare.has_meta(&"marker"):
				var marker_name := String(bare.get_meta(&"marker"))
				bare.name = marker_name + "_flame"
				built.name = marker_name
				built.set_meta(&"marker", marker_name)
				var into: Variant = bare.get_meta(&"made_in") if bare.has_meta(&"made_in") else null

				if into is Dictionary:
					into[marker_name] = built

			bare.queue_free()

		queue_free()

	func _wall(space: PhysicsDirectSpaceState3D) -> Dictionary:
		var best := {}
		var nearest := INF

		for k in 8:
			var angle := TAU * k / 8.0
			var query := PhysicsRayQueryParameters3D.create(flame_at, flame_at + Vector3(cos(angle), 0.0, sin(angle)) * WALL_REACH, 1)
			query.collide_with_areas = false
			var hit := space.intersect_ray(query)

			if not hit.is_empty() and _is_ground(hit["collider"]):
				var distance := flame_at.distance_to(hit["position"])

				if distance < nearest:
					nearest = distance
					best = hit

		return best

	func _floor(space: PhysicsDirectSpaceState3D) -> Dictionary:
		var query := PhysicsRayQueryParameters3D.create(flame_at, flame_at + Vector3.DOWN * (FLOOR_REACH + FLOOR_MARGIN), 1)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		return hit if not hit.is_empty() and _is_ground(hit["collider"]) else {}

	## Static world: not a door (they move), a man or a light.
	func _is_ground(body: Object) -> bool:
		return body is StaticBody3D and not body is AnimatableBody3D and not (body as Node).is_in_group(&"doors") and not (body as Node).is_in_group(&"guards")

	func _socket(fixture: StringName, socket_name: String) -> Vector3:
		var points: Array = FixtureScript.spec(fixture).get("sockets", {}).get(socket_name, [])
		return Vector3(float(points[0][0]), float(points[0][1]), float(points[0][2])) if not points.is_empty() else Vector3.ZERO

	func _make(parent: Node, fixture: StringName, at: Vector3, yaw: float, overrides: Dictionary) -> Node3D:
		var node: Node3D = FixtureScript.new()
		node.name = String(fixture).to_pascal_case()
		node.fixture = fixture
		node.overrides = overrides
		# It carries on the bare torch's clock: no second roll of the dice.
		node.clock_from = bare._time
		parent.add_child(node)
		node.global_position = at
		node.global_rotation = Vector3(0.0, yaw, 0.0)
		return node


## The yaw that turns a fixture's +Z (out of its wall) along `normal`.
static func yaw_facing(normal: Vector3) -> float:
	var flat := Vector3(normal.x, 0.0, normal.z)
	return atan2(flat.x, flat.z) if flat.length() > 0.001 else 0.0


static func _socket(fixture: StringName, socket_name: String, index := 0) -> Vector3:
	var points: Array = LightFixtureScript.spec(fixture).get("sockets", {}).get(socket_name, [])

	if index >= points.size():
		return Vector3.ZERO

	return Vector3(float(points[index][0]), float(points[index][1]), float(points[index][2]))
