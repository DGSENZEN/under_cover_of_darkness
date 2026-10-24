extends Node3D
## The talk box's character skins (the talk and quests spec, section 4,
## "Character skins"; Task 6b): a character with paintings talks in its own
## painted box, one without in the plain box, and a checkout without the
## paintings (they are kept out of git) falls back quietly.
##   B8   a skinned character opens the painted box, an unskinned one the plain
##   B11  a missing skin folder (a fresh checkout) falls back without errors
##   B12  the chosen swipe follows the choice
##   B17  the curandera's and the librarian's .json give draft 28's and
##        librarian2's crop, swipe paint and cursor
##   B18  the painted box's layout at 1920x1080 is draft 28's
##   B19  the paintings are sampled filtered, with mipmaps, never upscaled, and
##        the box sits over the Retro pixel pass
##   B20  the living painting: the eyes glow in the shade's colour and follow
##        flare, dim and gutter; the portrait warms, greys and flickers; the
##        panel shifts a little with the mouse, never far
##   B21  with the user's paintings present, the curandera's and the
##        librarian's skins load whole (else a NOTE: the fresh-checkout case)
##   B22  the shaders compile, and nothing in the suite errs or warns
## The painted fixture skin is drawn by this suite into user://, so it runs
## the same with or without the user's paintings.
##   Godot --headless --fixed-fps 60 --path . res://tests/talk_skin_test.tscn

const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const Shade := preload("res://scripts/Interaction/Shade.gd")
const PLAYER := preload("res://Player.tscn")
const TalkBox := preload("res://scripts/UI/TalkBox.gd")
const TalkSkin := preload("res://scripts/UI/TalkSkin.gd")
const FIXTURES := "res://tests/fixtures/dialogue"
## Where this suite paints its fixture skins.
const PAINTED := "user://talk_skin_test/painted/"
const BARE := "user://talk_skin_test/bare/"
const NOWHERE := "user://talk_skin_test/nowhere/"

var results: Array[String] = []
var notes: Array[String] = []
var _real_root := ""


## Counts the engine's errors and warnings while it is listening.
class Listener extends Logger:
	var errors: Array[String] = []
	var listening := false
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		_lock.lock()

		if listening:
			errors.append("%s %s (%s:%d %s)" % ["WARNING" if error_type == ERROR_TYPE_WARNING else "ERROR", rationale if rationale != "" else code,
				file.get_file(), line, function])

		_lock.unlock()


func _ready() -> void:
	# B22: every error and warning the suite meets (a shader that fails to
	# compile prints one, and draws nothing).
	var everything := Listener.new()
	everything.listening = true
	OS.add_logger(everything)
	_real_root = TalkSkin.root
	_paint_fixtures()
	_data()
	await _boxes()
	_real()
	TalkSkin.root = _real_root
	everything.listening = false
	OS.remove_logger(everything)
	_check("B22 the box's shaders compile and nothing in the suite errs or warns", everything.errors.is_empty(),
		"; ".join(everything.errors.slice(0, 6)) if not everything.errors.is_empty() else "no errors")
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	for line in notes:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


# ---------------------------------------------------------------------------
# The fixture skins
# ---------------------------------------------------------------------------

## fx_curandera's painted skin (a 2000 x 1120 backdrop with draft 28's crop,
## its swipe regions painted in colours of their own; a 1497 x 2000 portrait;
## a cursor with a black ground), and a bare one: its .json and no paintings,
## as a fresh checkout has them.
func _paint_fixtures() -> void:
	for dir in [PAINTED + "fx_curandera", BARE]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	var backdrop := Image.create(2000, 1120, false, Image.FORMAT_RGB8)
	backdrop.fill(Color(0.05, 0.07, 0.06))
	backdrop.fill_rect(Rect2i(98, 22, 1802, 1050), Color(0.2, 0.25, 0.22))
	backdrop.fill_rect(Rect2i(100, 620, 160, 280), Color(0.5, 0.3, 0.6))
	backdrop.fill_rect(Rect2i(130, 965, 570, 110), Color(0.8, 0.65, 0.3))
	backdrop.save_png(PAINTED + "fx_curandera/backdrop.png")
	var portrait := Image.create(1497, 2000, false, Image.FORMAT_RGB8)
	portrait.fill(Color(0.6, 0.65, 0.7))
	portrait.save_png(PAINTED + "fx_curandera/portrait.png")
	var cursor := Image.create(600, 336, false, Image.FORMAT_RGBA8)
	cursor.fill(Color(0, 0, 0, 0))
	cursor.fill_rect(Rect2i(0, 200, 600, 30), Color(0.8, 0.8, 0.85))
	cursor.save_png(PAINTED + "fx_curandera/cursor.png")

	var data := FileAccess.get_file_as_string("res://assets/ui/talk/curandera.json")
	for path in [PAINTED + "fx_curandera.json", BARE + "fx_curandera.json"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(data)
		file.close()


# ---------------------------------------------------------------------------
# B17: the two skins' data
# ---------------------------------------------------------------------------

func _data() -> void:
	TalkSkin.root = _real_root
	var her = TalkSkin.new("curandera")
	var him = TalkSkin.new("librarian")
	var near := func(a: Rect2, b: Rect2) -> bool: return a.position.distance_to(b.position) < 0.0005 and a.size.distance_to(b.size) < 0.0005
	var uv := func(x0: float, y0: float, x1: float, y1: float) -> Rect2: return Rect2(x0 / 2000.0, y0 / 1120.0, (x1 - x0) / 2000.0, (y1 - y0) / 1120.0)
	var ok: bool = (near.call(her.crop, uv.call(98, 22, 1900, 1072)) and near.call(her.dark_region, uv.call(100, 620, 260, 900))
		and near.call(her.warm_region, uv.call(130, 965, 700, 1075)) and absf(her.cursor_tip - 0.685) < 0.001
		and near.call(him.crop, uv.call(109, 40, 1887, 1076)) and near.call(him.dark_region, uv.call(60, 720, 400, 960))
		and near.call(him.warm_region, uv.call(1700, 420, 1930, 820))
		and him.cursor_tint.is_equal_approx(Color8(255, 70, 60)) and absf(him.cursor_tint_amount - 0.75) < 0.001
		and absf(her.cursor_tint_amount) < 0.001 and absf(her.cursor_saturation - 0.6) < 0.001
		and absf(her.panel_aspect() - 1802.0 / 1050.0) < 0.002 and absf(him.panel_aspect() - 1802.0 / 1050.0) < 0.002
		and her.breathe.size() == 2 and her.eyes.size() == 3 and him.breathe.size() >= 1 and him.eyes.size() >= 1)
	_check("B17 the curandera's and the librarian's .json give draft 28's and librarian2's crop, swipe paint and cursor", ok,
		"her crop %s dark %s warm %s; his crop %s warm %s tint %s x %.2f; aspects %.4f %.4f; faces %d/%d eyes %d/%d" % [her.crop, her.dark_region,
			her.warm_region, him.crop, him.warm_region, him.cursor_tint, him.cursor_tint_amount, her.panel_aspect(), him.panel_aspect(),
			her.breathe.size(), him.breathe.size(), her.eyes.size(), him.eyes.size()])


# ---------------------------------------------------------------------------
# B8, B11, B12, B18-B20: the box in each skin
# ---------------------------------------------------------------------------

func _boxes() -> void:
	DialogueBook.use(DialogueBook.load_dir(FIXTURES))
	CityState.begin()
	CityState.people.load_state({})
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.reload_on_death = false
	player.invulnerable = true
	player.global_position = Vector3(0, 1.05, 0)
	await _frames(10)

	# B8: fx_curandera has a painted skin (the fixture's), fx_librarian none.
	TalkSkin.root = PAINTED
	var painted: Node = await _open(player, "fx_curandera")
	var skin = painted.skin if painted != null else null
	var panel: TextureRect = painted._panel if painted != null else null
	var portrait: TextureRect = painted._portrait if painted != null else null
	var her_ok: bool = (skin != null and skin.backdrop != null and skin.portrait != null and skin.cursor != null
		and panel != null and panel.texture == skin.backdrop and portrait.texture == skin.portrait and painted._viewport == null
		and not _flag(panel.material, &"procedural"))

	# B18: draft 28's numbers for her portrait's shape (1497 x 2000 at 470
	# tall: 352 wide); the pair centred (PIL's integer halving).
	var layout_off: Array[String] = []

	if painted != null:
		painted._layout(Vector2(1920, 1080))
		var rects: Dictionary = painted.layout_rects()
		var tall := 1000.0 / (1802.0 / 1050.0)
		var top := 1080.0 - tall + 40.0
		var face_wide := 1497.0 * 470.0 / 2000.0
		var left := floorf((1920.0 - (face_wide - 70.0 + 1000.0)) / 2.0) + face_wide - 70.0
		var want := {"panel": Rect2(left, top, 1000, tall), "portrait": Rect2(left - face_wide + 70.0, top - 70.0, face_wide, 470.0)}

		for key in want:
			var got: Rect2 = rects.get(key, Rect2())

			if got.position.distance_to(want[key].position) > 2.0 or got.size.distance_to(want[key].size) > 2.0:
				layout_off.append("%s %s not %s" % [key, got, want[key]])

		for pair in [["name", 146.0], ["line", 182.0]]:
			var got_y: float = (rects.get(pair[0], Rect2()) as Rect2).position.y

			if absf(got_y - (top + float(pair[1]))) > 2.0:
				layout_off.append("%s y %.1f" % [pair[0], got_y])
	else:
		layout_off.append("no box")

	_check("B18 the painted box's layout at 1920x1080 is draft 28's", layout_off.is_empty(),
		"; ".join(layout_off) if not layout_off.is_empty() else "panel %s portrait %s" % [painted.layout_rects()["panel"], painted.layout_rects()["portrait"]])

	# B19: filtered with mipmaps, never shown bigger than painted; over Retro.
	var retro: Node = get_node_or_null("/root/Retro")
	var retro_layer: int = retro.layer if retro is CanvasLayer else 4
	var b19_ok: bool = (painted != null and panel.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		and portrait.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		and skin.backdrop != null and skin.portrait != null and skin.cursor != null
		and skin.backdrop.get_image().has_mipmaps() and skin.portrait.get_image().has_mipmaps() and skin.cursor.get_image().has_mipmaps()
		and skin.backdrop.get_width() * skin.crop.size.x >= painted.layout_rects()["panel"].size.x
		and skin.portrait.get_height() >= painted.layout_rects()["portrait"].size.y
		and painted.layer > retro_layer)
	_check("B19 the paintings are sampled filtered with mipmaps, only scaled down, over the Retro pass", b19_ok,
		"filters %s/%s, mipmaps %s, backdrop %d px for a %.0f px panel, layer %d" % [panel.texture_filter if panel else -1,
			portrait.texture_filter if portrait else -1, skin.backdrop.get_image().has_mipmaps() if skin and skin.backdrop else false,
			int(skin.backdrop.get_width() * skin.crop.size.x) if skin and skin.backdrop else 0,
			painted.layout_rects()["panel"].size.x if painted else 0.0, painted.layer if painted else -1])

	# B12: on to the options; pointing at the third moves the chosen swipe
	# onto it, longer than the rest by the marker's width (less its overlap).
	var b12 := "no options"
	var b12_ok := false

	if painted != null:
		var tries := 0

		while painted.shown_options().is_empty() and tries < 20:
			painted.press_advance()
			await _frames(12)
			tries += 1

		var offered: Array = painted.shown_options()

		if offered.size() >= 3:
			painted.choose_by_pointing(2)
			await _frames(2)
			painted._layout(Vector2(1920, 1080))
			var rects: Dictionary = painted.layout_rects()
			var chosen: Rect2 = rects["swipe 2"]
			var other: Rect2 = rects["swipe 0"]
			var words: Rect2 = rects["option 2"]
			var marker_on := []

			for i in offered.size():
				marker_on.append(_num(painted._swipes[i].material, &"marker_x") >= 0.0)

			b12_ok = (absf(chosen.position.y - (words.position.y - 8.0)) < 2.0 and absf(chosen.size.x - other.size.x - (TalkBox.MARKER_WIDE - 20.0)) < 2.0
				and marker_on == [false, false, true] + range(offered.size() - 3).map(func(_i): return false)
				and _flag(painted._swipes[2].material, &"use_cursor"))
			b12 = "chosen %s, other %s, words y %.1f, markers %s" % [chosen, other, words.position.y, marker_on]
		else:
			b12 = "options %s" % [offered]

	_check("B12 the chosen swipe follows the choice", b12_ok, b12)

	# B20: the living painting follows the shade.
	var b20 := "no box"
	var b20_ok := false

	if painted != null:
		var shade: Node = painted.shade
		var pm := panel.material as ShaderMaterial
		var fm := portrait.material as ShaderMaterial
		var colour: Color = shade.dialogue.get("colour", Color())
		shade.set_resting(&"calm")
		await _frames(90)
		var calm := [_num(pm, &"eye_glow"), _num(fm, &"warmth"), _num(fm, &"grey")]
		shade.cue(&"flare")
		await _frames(90)
		var flare := [_num(pm, &"eye_glow"), _num(fm, &"warmth"), _num(fm, &"grey")]
		shade.cue(&"dim")
		await _frames(90)
		var dim := [_num(pm, &"eye_glow"), _num(fm, &"warmth"), _num(fm, &"grey")]
		shade.cue(&"gutter")
		await _frames(90)
		var gutter := _num(fm, &"flicker")
		shade.end_line()
		var raw_colour: Variant = pm.get_shader_parameter(&"eye_colour")
		var eye_colour: Vector3 = raw_colour if raw_colour is Vector3 else Vector3(-1, -1, -1)
		skin.animate(1.0, &"calm", Vector2(1, -1))
		var raw_shift: Variant = pm.get_shader_parameter(&"shift")
		var shift: Vector2 = raw_shift if raw_shift is Vector2 else Vector2.ZERO
		b20_ok = (_flag(pm, &"living") and flare[0] > calm[0] * 1.5 and dim[0] < calm[0] * 0.6
			and flare[1] > 0.5 and calm[1] < 0.1 and dim[2] > 0.5 and calm[2] < 0.1 and gutter > 0.5
			and eye_colour.distance_to(Vector3(colour.r, colour.g, colour.b)) < 0.01
			and shift.length() > 0.5 and shift.length() <= 4.0)
		b20 = "eyes calm %.2f flare %.2f dim %.2f; warmth %.2f/%.2f; grey %.2f/%.2f; flicker %.2f; eye colour %s (shade %s); shift %s" % [calm[0],
			flare[0], dim[0], calm[1], flare[1], calm[2], dim[2], gutter, eye_colour, colour, shift]

	_check("B20 the eyes glow in the shade's colour and follow flare, dim and gutter; the portrait warms, greys and flickers; the panel shifts a little",
		b20_ok, b20)
	await _close(painted)

	var plain: Node = await _open(player, "fx_librarian")
	var plain_ok: bool = (plain != null and plain.skin.backdrop == null and plain.skin.portrait == null and plain._viewport != null
		and _flag(plain._panel.material, &"procedural"))
	_check("B8 a skinned character opens the painted box, an unskinned one the plain box", her_ok and plain_ok,
		"hers: backdrop %s portrait %s cursor %s live %s; his: backdrop %s live %s" % [skin.backdrop if skin else null, skin.portrait if skin else null,
			skin.cursor if skin else null, painted._viewport if painted else null, plain.skin.backdrop if plain else null,
			plain._viewport if plain else null])
	await _close(plain)

	# B11: a fresh checkout: her .json, no paintings (BARE), or no skins at all
	# (NOWHERE). The plain box, and not a line of error or warning.
	var listener := Listener.new()
	OS.add_logger(listener)
	listener.listening = true
	TalkSkin.root = BARE
	var bare_exists: bool = TalkSkin.exists("fx_curandera")
	var bare: Node = await _open(player, "fx_curandera")
	var bare_ok: bool = bare != null and bare.skin.backdrop == null and bare._viewport != null and bare.shown_text() != ""
	await _close(bare)
	TalkSkin.root = NOWHERE
	var none: Node = await _open(player, "fx_curandera")
	var none_ok: bool = none != null and none.skin.backdrop == null and none.shown_text() != ""
	await _close(none)
	listener.listening = false
	OS.remove_logger(listener)
	_check("B11 a missing skin folder (a fresh checkout) falls back without errors",
		not bare_exists and bare_ok and none_ok and listener.errors.is_empty(),
		"exists %s, bare box %s, no-root box %s, errors %s" % [bare_exists, bare_ok, none_ok, listener.errors])

	TalkSkin.root = _real_root
	player.queue_free()
	await _frames(2)
	DialogueBook.reload()


## Opens a talk with a fresh shade of `character` and waits for its paint.
func _open(player: CharacterBody3D, character: String) -> Node:
	var shade: StaticBody3D = Shade.new()
	shade.character = character
	add_child(shade)
	shade.global_position = Vector3(0, 0, -1.5)
	await _frames(5)
	_aim(player, shade.global_position + Vector3(0, 1.2, 0))
	await _frames(5)
	player.frob.talk(shade)
	var box: Node = player.frob.talking()
	await _frames(70)
	return box


func _close(box: Node) -> void:
	if box == null:
		return

	var shade: Node = box.shade
	box.interrupt()
	await _frames(3)

	if is_instance_valid(shade):
		shade.queue_free()

	await _frames(3)


# ---------------------------------------------------------------------------
# B21: the user's own paintings
# ---------------------------------------------------------------------------

func _real() -> void:
	TalkSkin.root = _real_root
	var present := []

	for id in ["curandera", "librarian"]:
		if TalkSkin.exists(id):
			present.append(id)

	if present.is_empty():
		notes.append("NOTE  B21 skipped: no paintings in %s (a fresh checkout; run tools/prepare_talk_art.py)" % _real_root)
		return

	var lines: Array[String] = []
	var ok := true

	for id in present:
		var skin = TalkSkin.new(id)
		var whole: bool = (skin.backdrop != null and skin.portrait != null and skin.cursor != null
			and skin.backdrop.get_width() >= 1802 and skin.portrait.get_height() >= 1000 and skin.cursor.get_width() >= 1000)
		ok = ok and whole
		lines.append("%s backdrop %s portrait %s cursor %s" % [id, skin.backdrop.get_size() if skin.backdrop else null,
			skin.portrait.get_size() if skin.portrait else null, skin.cursor.get_size() if skin.cursor else null])

	_check("B21 the user's paintings load whole for %s" % ", ".join(present), ok, "; ".join(lines))


# ---------------------------------------------------------------------------

## Turns the player's view on `point`.
func _aim(player: CharacterBody3D, point: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck/Camera3D").global_position
	var to := point - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Neck").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A shader flag or number (unset: false, 0).
func _flag(material: Material, param: StringName) -> bool:
	return (material as ShaderMaterial).get_shader_parameter(param) == true if material is ShaderMaterial else false


func _num(material: Material, param: StringName) -> float:
	var v: Variant = (material as ShaderMaterial).get_shader_parameter(param) if material is ShaderMaterial else null
	return float(v) if v is float or v is int else 0.0


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
