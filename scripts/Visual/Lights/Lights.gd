extends RefCounted
## The light fixtures, built (as Props.gd builds props): every builder returns
## the fixture, already added to `parent` and placed. `overrides` lays burner
## settings (Torch.gd exports) over the fixture's own.
##
##   Lights.wall_torch(self, flame_at, wall_normal)

const LightFixtureScript := preload("res://scripts/Visual/Lights/LightFixture.gd")


## Any fixture, its origin at `at`, turned `yaw` about up.
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


## The yaw that turns a fixture's +Z (out of its wall) along `normal`.
static func yaw_facing(normal: Vector3) -> float:
	var flat := Vector3(normal.x, 0.0, normal.z)
	return atan2(flat.x, flat.z) if flat.length() > 0.001 else 0.0


static func _socket(fixture: StringName, socket_name: String, index := 0) -> Vector3:
	var points: Array = LightFixtureScript.spec(fixture).get("sockets", {}).get(socket_name, [])

	if index >= points.size():
		return Vector3.ZERO

	return Vector3(float(points[index][0]), float(points[index][1]), float(points[index][2]))
