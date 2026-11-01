extends Node3D
## A filmed reel of the new work in the Metro, for the user: a train's pass heard on the north platform, the walk up
## into the hall, the Company's engine at work (a second train drawing on the line while it is filmed), then the Pasaje
## and the candle lane long enough for its theme to build from calm to full, the librarian's shop, out toward the
## chapel: the score and the sound following each space. Walked as a player
## walks (their steps, their bob) where it walks; the engine filmed by its own eye. No HUD, no captions. Recorded by Godot's
## movie maker, in the game's time:
##   Godot --path . --write-movie <out>.avi --fixed-fps 30 --resolution 1920x1080 res://tests/showcase_reel.tscn
## Run headless with -- --check to print each walk's legs and quit (no film).
const MAP := preload("res://maps/metro.tscn")
const RATE := 30.0
## How long a fade takes (s).
const FADE := 0.8
## How much of the way to its heading the walker turns each frame.
const TURN := 0.12
## Close enough to a walk's point (m), and the frames a leg may take.
const REACHED := 0.6
const LEG_FRAMES := 600
## The walker's pace (m/s): a stroll, slow enough to see each space by (the game's walk is 6.5).
const STROLL := 3.6
## The hall's floor and the engine's middle on it.
const HALL := -8.0
const ENGINE := Vector3(0.0, -8.0, 0.0)

var map: Node3D
var eye: Camera3D
var curtain: ColorRect
var check := false


func _ready() -> void:
	check = "--check" in OS.get_cmdline_user_args()
	map = MAP.instantiate()
	add_child(map)
	eye = Camera3D.new()
	eye.fov = 72.0
	eye.far = 4000.0
	# (Moved each frame, not in the physics step: drawn interpolated it judders.)
	eye.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	_hide_hud()

	# 1. The north platform: a train's pass in the tunnel, its draught, the signs sagging on the line.
	var player: CharacterBody3D = map.player
	player.walk_speed = STROLL
	_stand(Vector3(0.0, -14.0, -9.0), -PI / 2.0)
	await _seconds(1.0)
	_fade(0.0)
	var train: TrainPass = map.get_node("PlaceSound").train
	await _seconds(1.5)
	train.start_pass()
	await _turn_to(PI / 2.0, 11.0)
	# 2. Up the north stairwell into the hall.
	var up := await _walk([[0, -14, -9], [-2, -14, -13], [-2, -14, -29.2], [-6, -14, -29.2], [-6, -14, -28.5],
		[-6, -8, -14], [-6, -8, -12.5], [-7, -8, -8]])
	await _fade_out()

	# 3. The Company's engine, filmed by its own eye.
	_carry_player(false)
	eye.make_current()
	await _shot(func(t: float): return [Vector3(-12.0, -6.2, -11.0).lerp(Vector3(-8.5, -6.4, -7.0), t),
		Vector3(0.0, -4.6, 0.0)], 8.0)
	# (A train drawing on the line while the engine is circled: it labours.)
	train.start_pass()
	await _shot(func(t: float):
		var a := deg_to_rad(lerpf(215.0, 395.0, t))
		return [ENGINE + Vector3(cos(a) * 6.4, 2.0 + 0.4 * sin(t * PI), sin(a) * 6.4), ENGINE + Vector3(0.0, 2.6 + 0.8 * t, 0.0)],
		16.0)
	await _shot(func(t: float): return [Vector3(7.5, -6.8, lerpf(2.6, -2.6, t)), Vector3(2.7, -6.6, lerpf(0.5, -0.5, t))],
		7.0)
	await _shot(func(t: float):
		var a := deg_to_rad(lerpf(100.0, 150.0, t))
		var at := ENGINE + Vector3(cos(a) * 3.15, 0.54 + 1.65, sin(a) * 3.15)
		var into := ENGINE + Vector3(cos(a) * 1.4, 0.54 + lerpf(2.0, 6.0, smoothstep(0.0, 1.0, t)), sin(a) * 1.4)
		return [at, into], 10.0)
	_carry_player(true)

	player.camera.make_current()
	# 5. The Pasaje, its crowd and its bed; into the candle lane, where its theme comes in calm and builds over two
	# phrases to its full (the trumpet, the backbeat); her stall, the librarian's shop, out toward the chapel.
	_stand(Vector3(-9.0, -11.0, 58.0), PI)
	await _seconds(0.3)
	_fade(0.0)
	var lane := await _walk([[-9, -11, 58], [-8.5, -11, 66]])
	await _turn_to(player.rotation.y - PI * 0.35, 3.0)
	await _turn_to(player.rotation.y + PI * 0.55, 4.0)
	lane["on"] = await _walk([[-8.5, -11, 66], [-6.5, -11, 74.6], [-2, -11, 75.45], [5, -11, 75.5]])
	# (Her stall: the theme's calm layers come in.)
	await _turn_to(player.rotation.y - PI * 0.3, 6.0)
	await _turn_to(player.rotation.y + PI * 0.5, 8.0)
	lane["shop"] = await _walk([[5, -11, 75.5], [12.5, -11, 75.6], [18.6, -11, 76.6], [19, -11, 80.2], [19, -11, 82.4]])
	# (In his shop the theme reaches its full.)
	await _turn_to(player.rotation.y + PI * 0.6, 8.0)
	await _turn_to(player.rotation.y - PI * 0.9, 10.0)
	var score := map.get_node("PlaceScore")
	print("reel: in the shop the lane's theme is %s, playing %s" % [score.intensity_of(&"lane"), score.theme_playing(&"lane")])
	lane["out"] = await _walk([[19, -11, 82.4], [19, -11, 77.0], [24.5, -11, 75.2], [27.5, -11, 74.8]])
	await _turn_to(player.rotation.y + PI * 0.25, 8.0)
	await _fade_out()
	await _seconds(0.5)

	if check:
		print("reel: up %s" % [up])
		print("reel: lane %s" % [lane])
	get_tree().quit(0)


## The player set down at `at` (its floor), facing `yaw`, still.
func _stand(at: Vector3, yaw: float) -> void:
	var player: CharacterBody3D = map.player
	player.global_position = at + Vector3(0.0, 1.05, 0.0)
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw


## The player walked through `points` ([x, floor, z]) as a player walks: the forward key held, turned toward each next
## point a little every frame. What it reached: {"ok", "legs" (the frames each took), "end"}.
func _walk(points: Array) -> Dictionary:
	var player: CharacterBody3D = map.player
	var legs := []
	var ok := true
	Input.action_press("move_forward")

	for k in range(1, points.size()):
		var target := Vector3(points[k][0], points[k][1], points[k][2])
		var from := player.global_position
		var heading := Vector2(target.x - from.x, target.z - from.z)
		var reached := false
		var f := 0

		while f < LEG_FRAMES:
			var here := player.global_position
			var to := Vector2(target.x - here.x, target.z - here.z)
			if to.length() < REACHED or to.dot(heading) < 0.0:
				reached = true
				break
			player.rotation.y = lerp_angle(player.rotation.y, atan2(-to.x, -to.y), TURN)
			await get_tree().process_frame
			get_tree().paused = false
			f += 1

		legs.append(f)
		if not reached:
			ok = false
			break

	Input.action_release("move_forward")
	return {"ok": ok, "legs": legs, "end": player.global_position}


## The player turned, standing, to `yaw` over `seconds`.
func _turn_to(yaw: float, seconds: float) -> void:
	var player: CharacterBody3D = map.player
	var from := player.rotation.y
	var frames := int(seconds * RATE)
	for f in frames:
		player.rotation.y = lerp_angle(from, yaw, smoothstep(0.0, 1.0, float(f + 1) / frames))
		await get_tree().process_frame
		get_tree().paused = false


## One shot of the eye: `place(t)` gives [where, looking at] for t from 0 to 1 over `seconds`; faded in and out.
func _shot(place: Callable, seconds: float) -> void:
	_put(place.call(0.0))
	await _seconds(0.1)
	_fade(0.0)
	var frames := int(seconds * RATE)
	for f in frames:
		_put(place.call(smoothstep(0.0, 1.0, float(f) / (frames - 1))))
		if f == frames - int(FADE * RATE):
			_fade(1.0)
		await get_tree().process_frame
		get_tree().paused = false


func _put(keys: Array) -> void:
	eye.global_transform = Transform3D(Basis.IDENTITY, keys[0]).looking_at(keys[1], Vector3.UP)


## The player's own body and arms shown or hidden (hidden while the eye films).
func _carry_player(shown: bool) -> void:
	for part: Node in map.player.find_children("*", "VisualInstance3D", true, false):
		if part.has_meta("reel_hidden") or part.is_visible_in_tree() != shown:
			if shown:
				if part.has_meta("reel_hidden"):
					(part as VisualInstance3D).visible = true
					part.remove_meta("reel_hidden")
			elif (part as VisualInstance3D).visible:
				(part as VisualInstance3D).visible = false
				part.set_meta("reel_hidden", true)


func _fade(to: float) -> void:
	create_tween().tween_property(curtain, "color:a", to, FADE)


func _fade_out() -> void:
	_fade(1.0)
	await _seconds(FADE + 0.1)


func _hide_hud() -> void:
	for layer: Node in map.find_children("*", "CanvasLayer", true, false):
		if not String(layer.name).begins_with("plane_shift"):
			(layer as CanvasLayer).visible = false


func _seconds(s: float) -> void:
	for i in maxi(int(s * RATE), 1):
		await get_tree().process_frame
		get_tree().paused = false
