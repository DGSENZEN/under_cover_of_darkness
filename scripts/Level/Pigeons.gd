class_name Pigeons
extends Node3D
## The plaza's pigeons (dressing.json's "flocks"): each flock pecking about
## its spot, bobbing; when someone (the player, or `watcher`) comes within
## STARTLE metres they lift together and wheel overhead, each bird steering
## for its own place on the flock's wheel (spaced by its phase) and turning
## smoothly; AWAY seconds after the last of them came near they come down,
## each down a straight glide to its spot, wings still for the last GLIDE
## metres. One MultiMesh; each bird's custom (its phase, flap, spread) moves
## its wings (scripts/Visual/pigeon.gdshader).

const PIGEON := preload("res://scripts/Visual/pigeon.gdshader")
const STARTLE := 4.0
const AWAY := 8.0
## How high they wheel (m) and how wide.
const HEIGHT := Vector2(6.0, 10.0)
const WHEEL := 5.0
## How fast they fly (m/s), how quickly they turn (1/s), how fast at most a
## landing bird comes down (m/s), and the last stretch of a landing they
## glide (m).
const SPEED := 6.0
const TURN := 2.5
const DESCENT := 2.5
const GLIDE := 2.0

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
			var home := at + Vector3(cos(a) * r, 0, sin(a) * r)
			out._birds.append({"flock": out._flocks.size() - 1, "home": home, "phase": out._rng.randf() * TAU,
				"yaw": out._rng.randf() * TAU, "pos": home, "vel": Vector3.ZERO, "aloft": false})
			count += 1

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = count
	out._multi = MultiMeshInstance3D.new()
	out._multi.multimesh = multi
	out._multi.custom_aabb = AABB(Vector3(-2000, -50, -2000), Vector3(4000, 200, 4000))
	out.add_child(out._multi)
	return out


## The figures kit's material made the pigeons' (its wings moving).
static func look(kit: ShaderMaterial) -> ShaderMaterial:
	var out := kit.duplicate() as ShaderMaterial
	out.shader = PIGEON
	return out


func flying(flock: int) -> bool:
	return _flocks[flock]["flying"]


## A bird's custom data as its shader reads it: r its phase (0..1), g its
## flap (1 beating), b its spread (1 wings out).
func custom(bird: int) -> Color:
	return _birds[bird].get("custom", Color())


func bird_position(bird: int) -> Vector3:
	return _birds[bird]["pos"]


## Where a bird pecks about when its flock is down.
func home(bird: int) -> Vector3:
	return _birds[bird]["home"]


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
		var flap := 0.0
		var spread := 0.0
		var t := Transform3D()

		if f["flying"]:
			if not b["aloft"]:
				# Up off the ground with a clatter.
				b["aloft"] = true
				b["vel"] = Vector3(cos(b["phase"]), 3.0, sin(b["phase"]))

			_wheel(b, f, delta)
			flap = 1.0
			spread = 1.0
		elif b["aloft"]:
			flap = 1.0 if _land(b, delta) > GLIDE else 0.0
			spread = 1.0

		if b["aloft"]:
			var vel: Vector3 = b["vel"]
			var way := vel.normalized() if vel.length() > 0.1 else Vector3(sin(b["yaw"]), 0, cos(b["yaw"]))
			# (The bird looks along +Z.)
			t.basis = Basis.looking_at(-way, Vector3.UP)
			b["yaw"] = atan2(way.x, way.z)
		else:
			var peck := maxf(sin(_time * 3.0 + b["phase"]), 0.0)
			t.basis = Basis(Vector3.UP, b["yaw"]) * Basis(Vector3.RIGHT, -0.5 * peck * peck)

		t.origin = b["pos"]
		b["custom"] = Color(fposmod(b["phase"], TAU) / TAU, flap, spread, 0.0)

		if _multi != null:
			_multi.multimesh.set_instance_transform(k, t)
			_multi.multimesh.set_instance_custom_data(k, b["custom"])


## A flying bird steers for its place on its flock's wheel (its phase spaces
## it from the rest), turning smoothly.
func _wheel(b: Dictionary, f: Dictionary, delta: float) -> void:
	var a: float = _time * 0.9 + b["phase"]
	var r: float = WHEEL * (0.85 + 0.3 * fposmod(b["phase"] * 3.7, 1.0))
	var slot: Vector3 = f["at"] + Vector3(cos(a) * r, f["height"] + sin(a * 2.0) * 0.5, sin(a) * r)
	var to: Vector3 = slot - b["pos"]
	var want := to.normalized() * minf(SPEED, to.length() * 2.0) if to.length() > 0.01 else Vector3.ZERO
	b["vel"] = (b["vel"] as Vector3).lerp(want, minf(delta * TURN, 1.0))
	b["pos"] = (b["pos"] as Vector3) + b["vel"] * delta


## A landing bird comes down a straight glide to its spot, never faster
## than DESCENT down; on it, it is down. Its distance left after the step (m).
func _land(b: Dictionary, delta: float) -> float:
	var to: Vector3 = b["home"] - b["pos"]

	if to.length() < 0.05:
		b["pos"] = b["home"]
		b["vel"] = Vector3.ZERO
		b["aloft"] = false
		return 0.0

	# Down at its pace; across at the pace that brings it in as it touches.
	var drop := clampf(to.y, -DESCENT, DESCENT)
	var flat := Vector3(to.x, 0, to.z)
	var time_left := maxf(absf(to.y) / DESCENT, 0.4)
	var across := flat / time_left
	across = across.limit_length(SPEED)
	b["vel"] = (b["vel"] as Vector3).lerp(Vector3(across.x, drop, across.z), minf(delta * TURN, 1.0))
	b["vel"].y = maxf(b["vel"].y, -DESCENT)
	b["pos"] = (b["pos"] as Vector3) + (b["vel"] as Vector3) * delta

	# (Close and low: set down, never past the spot.)
	if (b["pos"] as Vector3).y < b["home"].y:
		b["pos"].y = b["home"].y

	return (b["home"] - b["pos"]).length()
