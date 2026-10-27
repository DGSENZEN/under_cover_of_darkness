extends Node3D
## A filmed tour of the Metro as it stands, for the user: the north astral passage walked along
## its way, the Pasaje, into the candle lane to the librarian's desk, the south passage. Shots joined by soft fades;
## the player carried along each so the passages answer (the plane's look, the glimpses, the muffle). No HUD. Recorded
## by Godot's movie maker, in the game's time:
##   Godot --path . --write-movie <out>.avi --fixed-fps 30 --resolution 1920x1080 res://tests/tour_video.tscn
const MAP := preload("res://maps/metro.tscn")
## The eye's height over the floor (m), the floor of the market's level (m).
const EYE := 1.65
const FLOOR := -11.0
## How long a fade between shots takes (s).
const FADE := 0.8

var map: Node3D
var eye: Camera3D
var curtain: ColorRect


func _ready() -> void:
	map = MAP.instantiate()
	add_child(map)
	eye = Camera3D.new()
	eye.fov = 75.0
	eye.far = 4000.0
	add_child(eye)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(curtain)
	await _seconds(2.0)
	eye.make_current()
	_hide_hud()
	# (The player carried along unseen: the eye is theirs.)
	for part: Node in map.player.find_children("*", "VisualInstance3D", true, false):
		(part as VisualInstance3D).visible = false
	var north: Array = map.NORTH_WAY[0]
	var south: Array = map.SOUTH_WAY[0]
	# The north passage: from the market stairs in through its gate, along its way to the market.
	await _shot(_along(north, Vector2(-10.0, 30.5), Vector2(-9.0, 58.5)), 20.0)
	# The Pasaje: down the market among its stalls and its shades.
	await _shot([[_at(-9.0, 57.5), _at(-9.5, 72.0, -0.3)], [_at(-8.0, 64.0), _at(-12.0, 70.0, -0.2)],
		[_at(-7.0, 71.0), _at(-1.0, 75.4, -0.1)]], 11.0)
	# Into the candle lane, to the librarian's desk.
	await _shot([[_at(-6.5, 75.45), _at(4.0, 75.45, -0.2)], [_at(4.0, 75.4), _at(14.0, 75.0, -0.1)],
		[_at(14.0, 75.0), _at(19.0, 78.0, -0.3)], [_at(19.0, 76.0), _at(19.0, 84.0, -0.4)]], 13.0)
	# The south passage: from the kiosk island in through the market's south mouth, along its way.
	# (Down the kiosk island's west side, then in through the arch.)
	await _shot([[_at(-11.8, 86.0), _at(-11.0, 95.0, 0.2)], [_at(-11.8, 93.0), _at(-9.2, 97.0, 0.2)]]
		+ _along(south, Vector2(-9.4, 94.6), Vector2(-9.0, 119.0), true), 20.0)
	# The deep over it: the eclipse, the aurora, the colossi.
	var mid: Vector3 = _at(-9.0, 106.0)
	await _shot([[mid, mid + Vector3(-6.0, 4.0, -20.0)], [mid, mid + Vector3(8.0, 12.0, -14.0)],
		[mid, mid + Vector3(14.0, 3.0, 4.0)]], 9.0)
	get_tree().quit(0)


## A point on the market's level, at the eye's height (and `rise` m more).
func _at(x: float, z: float, rise := 0.0) -> Vector3:
	return Vector3(x, FLOOR + EYE + rise, z)


## Keys along a way (its points, x-z), from `from` to `to`, each looking a little ahead along it.
func _along(points: Array, from: Vector2, to: Vector2, reversed := false) -> Array:
	var line: Array = [from]
	var middle := points.duplicate()
	if reversed:
		middle.reverse()
	line += middle
	line.append(to)
	var keys := []
	for i in line.size():
		var here: Vector2 = line[i]
		var ahead: Vector2 = line[mini(i + 2, line.size() - 1)]
		if ahead.distance_to(here) < 0.5:
			ahead = here + (here - line[maxi(i - 1, 0)]).normalized() * 4.0
		keys.append([_at(here.x, here.y), _at(ahead.x, ahead.y, -0.2)])
	return keys


## One shot: the eye eased through `keys` ([where, looking at]) over `seconds`, the player carried beside it; faded in
## and out.
func _shot(keys: Array, seconds: float) -> void:
	_place(keys, 0.0)
	await _seconds(0.1)
	_fade(0.0)
	var frames := int(seconds * 30.0)
	for f in frames:
		_place(keys, float(f) / (frames - 1))
		if f == frames - int(FADE * 30.0):
			_fade(1.0)
		await get_tree().process_frame
		get_tree().paused = false


func _place(keys: Array, t: float) -> void:
	var span := t * (keys.size() - 1)
	var k := mini(int(span), keys.size() - 2) if keys.size() > 1 else 0
	var s := smoothstep(0.0, 1.0, span - k) if keys.size() > 1 else 0.0
	var a: Array = keys[k]
	var b: Array = keys[mini(k + 1, keys.size() - 1)]
	var at: Vector3 = (a[0] as Vector3).lerp(b[0], s)
	var look: Vector3 = (a[1] as Vector3).lerp(b[1], s)
	eye.global_transform = Transform3D(Basis.IDENTITY, at).looking_at(look, Vector3.UP)
	map.player.global_position = at - Vector3(0.0, EYE - 1.05, 0.0)


func _fade(to: float) -> void:
	create_tween().tween_property(curtain, "color:a", to, FADE)


func _hide_hud() -> void:
	for layer: Node in map.find_children("*", "CanvasLayer", true, false):
		if not String(layer.name).begins_with("plane_shift"):
			(layer as CanvasLayer).visible = false


func _seconds(s: float) -> void:
	for i in maxi(int(s * 30.0), 1):
		await get_tree().process_frame
		get_tree().paused = false
