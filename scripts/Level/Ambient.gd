class_name Ambient
extends Node3D
## A district's ambient effects (the scenes' steam, copal, smoke, embers,
## mist, petals, leaves, dust, canal fog, candles, braziers; the dressing's
## "emitters", tools/level/dress_scenes.py), each built by Vfx.gd when it
## first comes near and kept: only the nearest ACTIVE within REACH of the
## camera that belong to the time of day run, thinner further off (full
## within FULL, down to THIN at REACH); the district's Gusts carries what
## they give off.

const REACH := 60.0
const ACTIVE := 40
## Fog volumes cost the most: of those running, only the nearest FOG show.
const FOG := 8
const FULL := 20.0
const THIN := 0.3
## Which emitters run is chosen again this often (s).
const CHOOSE_EVERY := 0.25

var emitters: Array = []
var day := true
## The wind (Gusts) carrying what they give off, if any.
var gusts: Node = null

var _running: Array[int] = []
var _systems := {}
var _choose := 0.0


static func build(list: Array) -> Ambient:
	var out := Ambient.new()
	out.name = "ambient"
	out.emitters = list
	return out


func set_day(is_day: bool) -> void:
	day = is_day
	_choose = 0.0


## The emitters running now, by index.
func running() -> Array[int]:
	return _running


## An emitter's effect node, once it has come near (null before).
func system(index: int) -> Node3D:
	return _systems.get(index)


func _process(delta: float) -> void:
	step(delta)


## One step of `delta` seconds (the suite steps it by hand).
func step(delta: float) -> void:
	_choose -= delta

	if _choose <= 0.0:
		_choose = CHOOSE_EVERY
		_pick()

	if gusts != null:
		var wind: Vector3 = gusts.wind()

		for i in _running:
			Vfx.blow(_systems[i], wind)


func _at(e: Dictionary) -> Vector3:
	return Vector3(e["at"][0], e["at"][1], e["at"][2])


## The nearest ACTIVE emitters of this time of day within REACH run, built
## when first needed; the rest stop (what they gave off fades on).
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
	var chosen := {}

	for pair in near.slice(0, ACTIVE):
		chosen[pair[1]] = pair[0]

	for i in _systems:
		if not chosen.has(i):
			Vfx.emit(_systems[i], false)

	_running.clear()

	for i in chosen:
		if not _systems.has(i):
			var node := Vfx.system(String(emitters[i]["effect"]))

			if node == null:
				continue

			add_child(node)
			Vfx.place(node, _at(emitters[i]), emitters[i])
			_systems[i] = node

		Vfx.emit(_systems[i], true)
		Vfx.thin(_systems[i], 1.0 if chosen[i] <= FULL else lerpf(1.0, THIN, (chosen[i] - FULL) / (REACH - FULL)))
		_running.append(i)

	_running.sort()
	# Of the running fog volumes only the nearest FOG show.
	var foggy: Array = []

	for i in _running:
		if not _systems[i].find_children("*", "FogVolume", true, false).is_empty():
			foggy.append([chosen[i], i])

	foggy.sort_custom(func(a, b): return a[0] < b[0])

	for k in foggy.size():
		for volume in _systems[foggy[k][1]].find_children("*", "FogVolume", true, false):
			volume.visible = k < FOG
