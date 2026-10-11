class_name Pigeons
extends Node3D
## The plaza's pigeons (dressing.json's "flocks"): each flock pecking about
## its spot, bobbing; when someone (the player, or `watcher`) comes within
## STARTLE metres they lift together and wheel overhead, and AWAY seconds
## after the last of them came near they settle again. One MultiMesh.

const STARTLE := 4.0
const AWAY := 8.0
## How high they wheel (m) and how wide.
const HEIGHT := Vector2(6.0, 10.0)
const WHEEL := 5.0

## Who startles them; the "player" group's first node when not set.
var watcher: Node3D = null

var _flocks: Array = []
var _birds: Array = []
var _multi: MultiMeshInstance3D
var _time := 0.0
var _rng := RandomNumberGenerator.new()


static func build(flocks: Array, mesh: Mesh) -> Pigeons:
	var out := Pigeons.new()
	out.name = "pigeons"
	# Placed as drawn each frame, not smoothed between physics ticks.
	out.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	out._rng.seed = 1867
	var count := 0

	for f in flocks:
		var at := Vector3(f["at"][0], f["at"][1], f["at"][2])
		out._flocks.append({"at": at, "flying": false, "quiet": AWAY, "height": out._rng.randf_range(HEIGHT.x, HEIGHT.y)})

		for k in int(f["count"]):
			var a := out._rng.randf() * TAU
			var r := sqrt(out._rng.randf()) * float(f["radius"])
			out._birds.append({"flock": out._flocks.size() - 1, "home": at + Vector3(cos(a) * r, 0, sin(a) * r),
				"phase": out._rng.randf() * TAU, "yaw": out._rng.randf() * TAU, "pos": at + Vector3(cos(a) * r, 0, sin(a) * r)})
			count += 1

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	out._multi = MultiMeshInstance3D.new()
	out._multi.multimesh = multi
	out._multi.custom_aabb = AABB(Vector3(-2000, -50, -2000), Vector3(4000, 200, 4000))
	out.add_child(out._multi)
	return out


func flying(flock: int) -> bool:
	return _flocks[flock]["flying"]


func _process(delta: float) -> void:
	step(delta)


## One step of `delta` seconds (the suite steps it by hand).
func step(delta: float) -> void:
	_time += delta
	var who := watcher

	if who == null and is_inside_tree():
		who = get_tree().get_first_node_in_group(&"player") as Node3D

	for f in _flocks:
		var near := who != null and who.global_position.distance_to(f["at"]) < STARTLE * (2.0 if f["flying"] else 1.0)

		if near:
			f["flying"] = true
			f["quiet"] = 0.0
		elif f["flying"]:
			f["quiet"] += delta

			if f["quiet"] >= AWAY:
				f["flying"] = false

	for k in _birds.size():
		var b: Dictionary = _birds[k]
		var f: Dictionary = _flocks[b["flock"]]
		var target: Vector3
		var t := Transform3D()

		if f["flying"]:
			var a: float = _time * 0.9 + b["phase"]
			target = f["at"] + Vector3(cos(a) * WHEEL, f["height"] + sin(a * 2.0) * 0.5, sin(a) * WHEEL)
			b["pos"] = (b["pos"] as Vector3).lerp(target, minf(delta * 2.0, 1.0))
			t.basis = Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.2 * sin(_time * 14.0 + b["phase"]))
		else:
			b["pos"] = (b["pos"] as Vector3).lerp(b["home"], minf(delta * 1.5, 1.0))
			var peck := maxf(sin(_time * 3.0 + b["phase"]), 0.0)
			t.basis = Basis(Vector3.UP, b["yaw"]) * Basis(Vector3.RIGHT, -0.5 * peck * peck)

		t.origin = b["pos"]

		if _multi != null:
			_multi.multimesh.set_instance_transform(k, t)
