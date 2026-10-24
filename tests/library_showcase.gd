extends Node3D
## The librarian's shop, Part 2, shown (docs/superpowers/plans/2026-10-19-librarian-shop-part-2.md): a tour of the joined
## map, in from the corridor, past every family of the strange shop, out again. Windowed --fixed-fps 60
## --resolution 1280x720, then -- --out=DIR: JPEG frames, 30 a second of its 60 (game time as it runs), for ffmpeg.
## A caption names what each shot shows; each fades in from black and out to it.
const MAP := preload("res://maps/underground_library_lab.tscn")
## Frames a second written; frames each fade takes.
const RATE := 30
const FADE := 9

var out := "/tmp/library_showcase/"
var eye: Camera3D
var lib: Node3D
var caption: Label
var veil: ColorRect
var written := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var map := MAP.instantiate()
	add_child(map)
	await _frames(8)
	map.player.queue_free()
	map.keys_label.visible = false
	eye = Camera3D.new()
	eye.fov = 62.0
	add_child(eye)
	eye.make_current()
	lib = map.library
	# (The chained book strains when the tour asks it to.)
	lib.chained._next = 1e9
	_overlay()
	_place(_w(Vector3(7.2, 1.7, 1.1)), _w(Vector3(15.6, 1.65, 1.1)))
	await _frames(120)

	await _shot("Into the shop", [_w(Vector3(7.2, 1.7, 1.1)), _w(Vector3(15.6, 1.65, 1.1))],
		[_l(Vector3(0.0, 1.7, -0.8)), _l(Vector3(0.0, 1.5, -6.0))], 8.0)
	await _shot("Under the vault: books in flight, words in waves", [_l(Vector3(0.0, 1.7, -0.6)), _l(Vector3(0.0, 3.1, -3.4))],
		[_l(Vector3(0.4, 1.6, -1.6)), _l(Vector3(-0.6, 3.0, -4.3))], 7.0)
	await _shot("Chronology", [_l(Vector3(-2.45, 1.6, -0.9)), _l(Vector3(-3.7, 1.15, -1.3))],
		[_l(Vector3(-2.6, 1.55, -0.95)), _l(Vector3(-3.7, 1.2, -1.3))], 6.0)
	await _shot("Necromancy", [_l(Vector3(-2.5, 1.75, -3.9)), _l(Vector3(-3.72, 1.55, -4.35))],
		[_l(Vector3(-2.65, 1.7, -4.0)), _l(Vector3(-3.72, 1.6, -4.35))], 6.0)
	await _shot("Alchemy", [_l(Vector3(2.5, 1.75, -1.25)), _l(Vector3(3.72, 1.55, -1.5))],
		[_l(Vector3(2.65, 1.7, -1.3)), _l(Vector3(3.72, 1.58, -1.5))], 6.0)
	await _shot("Occult metaphysics", [_l(Vector3(2.5, 1.5, -4.2)), _l(Vector3(3.72, 1.1, -4.55))],
		[_l(Vector3(2.65, 1.45, -4.3)), _l(Vector3(3.72, 1.12, -4.55))], 6.0)
	await _shot("Monster hunting", [_l(Vector3(2.9, 1.75, -4.4)), _l(Vector3(3.05, 1.55, -5.72))],
		[_l(Vector3(2.95, 1.7, -4.6)), _l(Vector3(3.05, 1.57, -5.72))], 6.0)
	await _shot("A novel: the duellist's sword", [_l(Vector3(3.15, 1.35, -0.95)), _l(Vector3(3.12, 1.02, -0.3))],
		[_l(Vector3(3.05, 1.4, -1.0)), _l(Vector3(3.12, 1.05, -0.3))], 5.0)
	await _shot("The novels: their characters' emblems", [_l(Vector3(0.55, 1.85, -1.15)), _l(Vector3(1.15, 1.55, -1.6))],
		[_l(Vector3(0.45, 1.8, -1.05)), _l(Vector3(1.15, 1.55, -1.6))], 5.0)
	await _shot("A spellbook, its words rising", [_l(Vector3(-2.2, 1.55, -1.4)), _l(Vector3(-2.8, 1.5, -0.4))],
		[_l(Vector3(-2.3, 1.6, -1.5)), _l(Vector3(-2.8, 1.6, -0.4))], 5.0)
	await _shot("Words between the stands", [_l(Vector3(0.2, 1.7, -3.4)), _l(Vector3(0.0, 2.3, -1.0))],
		[_l(Vector3(-0.2, 1.7, -3.2)), _l(Vector3(0.2, 2.4, -1.0))], 6.0)
	await _shot("A floating book comes home", [_l(Vector3(-1.5, 1.8, -1.0)), _l(Vector3(-3.4, 1.95, -1.2))],
		[_l(Vector3(-1.6, 1.8, -1.0)), _l(Vector3(-3.4, 1.95, -1.2))], 7.0, func(): lib.floating.come_home(6))
	await _shot("The quarantine cage, its books unexorcised", [_l(Vector3(-0.95, 1.5, -4.3)), _l(Vector3(-1.85, 0.9, -5.8))],
		[_l(Vector3(-0.85, 1.55, -4.2)), _l(Vector3(-1.85, 0.95, -5.8))], 5.0)
	await _stir()
	await _ward()
	await _shadow()
	await _shot("The librarian's shop", [_l(Vector3(-2.45, 1.65, -4.8)), _l(Vector3(0.0, 1.6, 2.0))],
		[_l(Vector3(-1.2, 1.9, -5.3)), _l(Vector3(0.6, 1.6, 2.0))], 6.0)
	print("showcase: %d frames" % written)
	get_tree().quit()


## A shot: the eye eased from `a` to `b` ([where, looking at]) over `seconds`; `act` called `at` seconds in. It fades in
## and out unless told not to (a shot carried on by the next).
func _shot(label: String, a: Array, b: Array, seconds: float, act := Callable(), at := 0.0, fade_in := true,
		fade_out := true) -> void:
	caption.text = label
	var n := int(seconds * RATE)
	for i in n:
		var t := smoothstep(0.0, 1.0, float(i) / maxf(n - 1, 1))
		_place((a[0] as Vector3).lerp(b[0], t), (a[1] as Vector3).lerp(b[1], t))
		if act.is_valid() and i == int(at * RATE):
			act.call()
		var dark := 0.0
		if fade_in:
			dark = maxf(dark, 1.0 - float(i) / FADE)
		if fade_out:
			dark = maxf(dark, 1.0 - float(n - 1 - i) / FADE)
		veil.color.a = clampf(dark, 0.0, 1.0)
		await _frames(2)
		_capture()


## The shelves: the chronology case looked at, then away; unwatched, its boards stand their books by height; back.
func _stir() -> void:
	var at := _l(Vector3(-2.3, 1.6, -0.9))
	var case_look := _l(Vector3(-3.7, 1.25, -1.2))
	var away := _l(Vector3(1.5, 1.9, -1.6))
	var label := "Unwatched, the shelves rearrange"
	await _shot(label, [at, case_look], [at, case_look], 2.5, Callable(), 0.0, true, false)
	await _shot(label, [at, case_look], [at, away], 1.5, Callable(), 0.0, false, false)
	await _shot(label, [at, away], [at, away], 1.0, func():
		var case: Node3D = lib.sections["chronology"]
		for i in lib.book_spots.size():
			if lib.book_spots[i]["case"] == case:
				# (Long enough unseen for the tour's sake: in play, five seconds.)
				lib.stir._seen[i] = -100.0
				lib.stir.try_board(i), 0.5, false, false)
	await _shot(label, [at, away], [at, case_look], 1.5, Callable(), 0.0, false, false)
	await _shot(label, [at, case_look], [at, case_look], 2.5, Callable(), 0.0, false, true)


## The ward: the book strains, its words crawl for the salt and are thrown back, the sigils near them lit, the candles
## leaning away; then closer, on the book and on a candle.
func _ward() -> void:
	await _shot("The chained book strains against its ward", [_l(Vector3(0.6, 2.5, -1.9)), _l(Vector3(-0.1, 0.25, -4.5))],
		[_l(Vector3(0.2, 2.3, -2.1)), _l(Vector3(-0.2, 0.3, -4.5))], 6.0, func(): lib.chained.strain_now(), 0.4)
	await _shot("Its words slither out for the salt", [_l(Vector3(-0.15, 1.6, -3.3)), _l(Vector3(-0.85, 0.85, -4.3))],
		[_l(Vector3(0.9, 0.9, -2.7)), _l(Vector3(-0.3, 0.5, -4.1))], 5.0, func(): lib.chained.strain_now(), 0.2)
	await _shot("The candles lean away; the sigils wake", [_l(Vector3(1.2, 0.4, -3.3)), _l(Vector3(0.9, 0.12, -3.64))],
		[_l(Vector3(1.05, 0.45, -3.2)), _l(Vector3(0.75, 0.12, -3.64))], 5.0, func(): lib.chained.strain_now(), 0.6)


## His shadow: from the runner, the necromancy case in the corner of the eye (past the low case, near enough face on
## that his shadow reads on it); he crosses; the eye turns, he is gone.
func _shadow() -> void:
	var at := _l(Vector3(-0.4, 1.65, -2.4))
	var ahead := _l(Vector3(-2.1, 1.4, -7.1))
	var shadow: Node3D = lib.effects.shadow
	var label := "From the corner of the eye: his shadow"
	shadow.only = 1
	await _shot(label, [at, ahead], [at, ahead], 4.2, func(): shadow.cross_now(1), 0.3, true, false)
	var him: Vector3 = shadow.shade.global_position
	await _shot(label, [at, ahead], [at, him], 0.9, Callable(), 0.0, false, false)
	await _shot(label, [at, him], [at, him], 2.0, Callable(), 0.0, false, true)
	shadow.only = -1


func _overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	veil = ColorRect.new()
	veil.color = Color(0.0, 0.0, 0.0, 1.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(veil)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	caption.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	caption.add_theme_constant_override("outline_size", 6)
	caption.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	caption.position = Vector2(40.0, 720.0 - 64.0)
	layer.add_child(caption)


func _w(p: Vector3) -> Vector3:
	return p


func _l(p: Vector3) -> Vector3:
	return lib.to_global(p)


func _place(from: Vector3, target: Vector3) -> void:
	eye.global_transform = Transform3D(Basis.IDENTITY, from).looking_at(target, Vector3.UP)


func _capture() -> void:
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_jpg(out + "f_%05d.jpg" % written, 0.92)
	written += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
