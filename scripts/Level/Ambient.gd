class_name Ambient
extends Node3D
## A district's ambient effects (the scenes' steam, copal, smoke, embers,
## mist, petals, leaves, dust and candles; tools/level/dress_scenes.py writes
## them to dressing.json's "emitters"): each a FireParticles kind breathed
## out at its place, or a few candle flames. Only the nearest ACTIVE within
## REACH of the camera that belong to the time of day run; the wind from the
## district's Gusts, when it has one, carries what they give off.

const FireParticles := preload("res://scripts/Visual/Lights/FireParticles.gd")
const FlameFx := preload("res://scripts/Visual/Lights/FlameFx.gd")

const REACH := 60.0
const ACTIVE := 40
## Which emitters run is chosen again this often (s).
const CHOOSE_EVERY := 0.25
## effect -> [kind, a second, size (m), tint, spread (m: round its place), rise (m: up from its place)]
const EFFECTS := {
	"steam": [&"steam", 6.0, 0.2, Color.WHITE, 0.1, 0.0],
	"copal": [&"smoke", 8.0, 0.5, Color("ECE6DA"), 0.2, 0.0],
	"smoke": [&"smoke", 3.0, 0.3, Color(0.55, 0.53, 0.5), 0.15, 0.0],
	"embers": [&"ember", 5.0, 0.0, Color.WHITE, 0.2, 0.0],
	"mist": [&"mist", 3.0, 0.6, Color("7FD36A"), 0.6, 0.05],
	"petals": [&"petal", 3.0, 0.0, Color.WHITE, 2.0, 2.2],
	"leaves": [&"leaf", 0.6, 0.0, Color.WHITE, 2.5, 0.0],
	"dust": [&"dust", 2.0, 0.0, Color(1.0, 0.92, 0.75), 2.5, 1.5],
	"canal_fog": [&"fog", 2.0, 1.2, Color(0.7, 0.75, 0.8), 4.0, 0.05],
	"candles": [&"", 0.0, 0.0, Color.WHITE, 0.0, 0.0],
}

var emitters: Array = []
var day := true
## The wind (Gusts) carrying what they give off, if any.
var gusts: Node = null

var _running: Array[int] = []
var _due: PackedFloat32Array = []
var _choose := 0.0
var _flames := {}
var _rng := RandomNumberGenerator.new()


static func build(list: Array) -> Ambient:
	var out := Ambient.new()
	out.name = "ambient"
	out.emitters = list
	out._due.resize(list.size())
	out._rng.seed = 1921
	return out


func set_day(is_day: bool) -> void:
	day = is_day
	_choose = 0.0


## The emitters running now, by index.
func running() -> Array[int]:
	return _running


func _process(delta: float) -> void:
	step(delta)


## One step of `delta` seconds (the suite steps it by hand).
func step(delta: float) -> void:
	_choose -= delta

	if _choose <= 0.0:
		_choose = CHOOSE_EVERY
		_pick()

	var wind: Vector3 = gusts.wind() if gusts != null else Vector3.ZERO

	for i in _running:
		var e: Dictionary = emitters[i]
		var look: Array = EFFECTS.get(e["effect"], [])

		if look.is_empty() or look[0] == &"":
			continue

		_due[i] += look[1] * delta

		while _due[i] >= 1.0:
			_due[i] -= 1.0
			var at := _at(e)
			var spread: float = look[4]
			var where := at + Vector3(_rng.randf_range(-spread, spread), _rng.randf_range(0.0, look[5]), _rng.randf_range(-spread, spread))
			FireParticles.emit(self, look[0], where, 1, wind * 0.15, look[3], look[2], float(e.get("floor", at.y)))


func _at(e: Dictionary) -> Vector3:
	return Vector3(e["at"][0], e["at"][1], e["at"][2])


## The nearest ACTIVE emitters of this time of day within REACH run; the
## candles among them are lit, the rest put out.
func _pick() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var from := camera.global_position if camera != null else Vector3.ZERO
	var near: Array = []

	for i in emitters.size():
		var when: String = emitters[i].get("when", "")

		if (when == "day" and not day) or (when == "night" and day):
			continue

		var d := _at(emitters[i]).distance_to(from)

		if d <= REACH:
			near.append([d, i])

	near.sort_custom(func(a, b): return a[0] < b[0])
	_running.clear()

	for pair in near.slice(0, ACTIVE):
		_running.append(pair[1])

	for i in _flames.keys():
		_flames[i].visible = i in _running

	for i in _running:
		if emitters[i]["effect"] == "candles" and not _flames.has(i):
			_flames[i] = _candles(_at(emitters[i]))


## Three candle flames (FlameFx's candle sheet) about a place.
func _candles(at: Vector3) -> Node3D:
	var group := Node3D.new()
	add_child(group)
	group.global_position = at

	for k in 3:
		var flame: Node3D = FlameFx.new()
		flame.sheet = &"candle"
		flame.ramp = &"candle"
		flame.size = 0.05
		flame.layers = 1
		flame.core = false
		group.add_child(flame)
		flame.position = Vector3(cos(k * 2.1) * 0.12, 0.0, sin(k * 2.1) * 0.12)

	return group
