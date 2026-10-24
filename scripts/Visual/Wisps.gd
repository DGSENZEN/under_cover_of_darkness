extends Node3D
## Wisps of the ánimas' warmth (maps/candle_lane.gd), drawn the Deadlock way (docs/superpowers/refs/underground/
## vfx_method.md: a shaped mesh, banded colour, its edges eaten away): now and then one slips out of where they come
## up (a vent, the drain), rises, and threads along the lane in a slow curl toward the candles they long for, thinning,
## until it is drawn down into a flame and gone. Never many at once; nothing of it left after.
## Its points are in the world; the node itself stays at the origin of whatever holds it.

## How many at once; how long between one and the next (s); how fast one goes (m/s), and its least and most time.
const AT_ONCE := 3
const EVERY := Vector2(4.0, 11.0)
const SPEED := 2.4
const TIME := Vector2(2.5, 7.0)
## How high it rises over its way (m), how wide it curls round its line and how many turns a metre; how long its
## body is (m), how wide at its head; how far it may go to find a flame (m).
const RISE := Vector2(0.6, 1.4)
const CURL := 0.16
const TURNS := 0.6
const LENGTH := 1.5
const WIDTH := 0.16
const REACH := 14.0
const POINTS := 18
## Its colour: the ánimas' (scripts/Visual/Animas.gd), and how bright.
const CORE := Color("e6ff96")
const BODY := Color("b2ea3a")
const EDGE := Color("2a480b")
const ENERGY := 1.6

## Where they come up (world), and the flames they make for (world).
@export var sources := PackedVector3Array()
@export var targets := PackedVector3Array()
@export var seed := 9

## The wisps in flight: {from, to, rise, phase, t (0-1 along its way), time (s), head (world)}.
var flights: Array[Dictionary] = []
## How long until the next (s).
var next_in := 3.0
var _draws: Array[MeshInstance3D] = []
var _looks: Array[ShaderMaterial] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed
	next_in = _rng.randf_range(EVERY.x, EVERY.y)
	for k in AT_ONCE:
		var draw := MeshInstance3D.new()
		draw.name = "wisp_%d" % k
		draw.top_level = true
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var look := MeshVfx.look(CORE, BODY, EDGE, ENERGY, 0.3, 1.4, float(k) * 3.7)
		look.set_shader_parameter(&"tail_eat", 0.85)
		look.set_shader_parameter(&"tiling", Vector2(1.0, 2.5))
		look.set_shader_parameter(&"hardness", 0.03)
		add_child(draw)
		draw.global_transform = Transform3D.IDENTITY
		_draws.append(draw)
		_looks.append(look)


## How many are in flight.
func flying() -> int:
	return flights.size()


func _process(delta: float) -> void:
	next_in -= delta
	if next_in <= 0.0 and flights.size() < AT_ONCE and not sources.is_empty() and not targets.is_empty():
		_launch()
		next_in = _rng.randf_range(EVERY.x, EVERY.y)

	for w in flights:
		w["t"] = minf(1.0, w["t"] + delta / w["time"])
	flights = flights.filter(func(w): return w["t"] < 1.0)

	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else Vector3(0, 1.6, 0)
	for k in AT_ONCE:
		if k >= flights.size():
			_draws[k].mesh = null
			continue
		var w: Dictionary = flights[k]
		var t: float = w["t"]
		var points := PackedVector3Array()
		# (Its body behind its head along its way, its length a share of the way's.)
		var span := LENGTH / maxf(w["from"].distance_to(w["to"]), 0.5)
		for i in POINTS:
			points.append(_at(w, maxf(0.0, t - span * float(i) / (POINTS - 1))))
		w["head"] = points[0]
		var strip := MeshVfx.ribbon(points, WIDTH * (1.0 - 0.6 * t), eye)
		strip.surface_set_material(0, _looks[k])
		_draws[k].mesh = strip
		# (Coming out of the dark and eaten away as it goes into the flame.)
		var shown := minf(1.0, t * 6.0) * minf(1.0, (1.0 - t) * 5.0 + 0.2)
		_looks[k].set_shader_parameter(&"erosion", lerpf(0.95, 0.25, shown))


## One sent out of a source toward a flame within reach of it.
func _launch() -> void:
	var from := sources[_rng.randi() % sources.size()]
	var near := Array(targets).filter(func(c): return c.distance_to(from) < REACH)
	if near.is_empty():
		return
	var to: Vector3 = near[_rng.randi() % near.size()]
	flights.append({"from": from, "to": to, "rise": _rng.randf_range(RISE.x, RISE.y),
		"phase": _rng.randf_range(0.0, TAU), "t": 0.0, "head": from,
		"time": clampf(from.distance_to(to) / SPEED, TIME.x, TIME.y)})


## Where a wisp is at `t` along its way (world): out of its source, up and along in a curl, down into its flame.
func _at(w: Dictionary, t: float) -> Vector3:
	var from: Vector3 = w["from"]
	var to: Vector3 = w["to"]
	var e := t * t * (3.0 - 2.0 * t)
	var line := from.lerp(to, e)
	var up: Vector3 = Vector3.UP * float(w["rise"]) * sin(PI * t)
	var along := (to - from).normalized() if from.distance_to(to) > 0.01 else Vector3.RIGHT
	var side := along.cross(Vector3.UP).normalized()
	var a: float = w["phase"] + TAU * TURNS * from.distance_to(to) * t
	# (Its curl widest midway, gathered in at both ends.)
	var curl := (side * cos(a) + Vector3.UP * sin(a)) * CURL * sin(PI * t)
	return line + up + curl
