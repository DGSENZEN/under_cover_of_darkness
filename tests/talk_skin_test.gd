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
##   B23  a second open of the same character decodes no painting again
##   B24  at 1280x720 the painted box is draft 28's, two thirds as big
##   B25  while talking the HUD shows no rows at all (line or options)
##   B26  the live portrait's camera sees the world, actors and effects, never
##        the player's hands or the lightgem's probe, and only 25 m out
##   B27  E pressed while the box lifts off opens no second box
##   B28  pointing after a choice touches nothing that has gone
##   B29  a back key already held when the talk opens is not walking away;
##        a fresh hold is
##   B30  number keys by their physical key, and the numpad's, pick
##   B31  the mouse: over a swipe chooses it (repainted gold), a click picks
##        it, and the click that closes the box is no blow
##   B32  the pause screen: the box's words hide under it, and come back
##   B33  the panel's and the portrait's paint is whole up to a narrow fray
##        (no translucent band at the top)
##   B34  the view eases so the speaker's head stands just above the panel
##   B35  the box does not re-set its type sizes every frame
## The painted fixture skin is drawn by this suite into user://, so it runs
## the same with or without the user's paintings.
##   Godot --headless --fixed-fps 60 --path . res://tests/talk_skin_test.tscn

const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const Shade := preload("res://scripts/Interaction/Shade.gd")
const PLAYER := preload("res://Player.tscn")
const TalkBox := preload("res://scripts/UI/TalkBox.gd")
const TalkSkin := preload("res://scripts/UI/TalkSkin.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
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
	await _functional()
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
	# The .json alone (no paintings needed: a fresh checkout reads them too).
	TalkSkin.root = _real_root
	var her: Dictionary = TalkSkin._read("curandera")
	var him: Dictionary = TalkSkin._read("librarian")
	var near := func(a: Variant, b: Rect2) -> bool: return a is Rect2 and a.position.distance_to(b.position) < 0.0005 and a.size.distance_to(b.size) < 0.0005
	var uv := func(x0: float, y0: float, x1: float, y1: float) -> Rect2: return Rect2(x0 / 2000.0, y0 / 1120.0, (x1 - x0) / 2000.0, (y1 - y0) / 1120.0)
	var ok: bool = (near.call(her.get("crop"), uv.call(98, 22, 1900, 1072)) and near.call(her.get("dark_region"), uv.call(100, 620, 260, 900))
		and near.call(her.get("warm_region"), uv.call(130, 965, 700, 1075)) and absf(float(her.get("cursor_tip", 0.0)) - 0.685) < 0.001
		and near.call(him.get("crop"), uv.call(109, 40, 1887, 1076)) and near.call(him.get("dark_region"), uv.call(60, 720, 400, 960))
		and near.call(him.get("warm_region"), uv.call(1700, 420, 1930, 820))
		and (him.get("cursor_tint", Color.WHITE) as Color).is_equal_approx(Color8(255, 70, 60))
		and absf(float(him.get("cursor_tint_amount", 0.0)) - 0.75) < 0.001 and him.get("cursor_from") == "curandera"
		and absf(float(her.get("cursor_tint_amount", 0.0))) < 0.001 and absf(float(her.get("cursor_saturation", 0.0)) - 0.6) < 0.001
		and absf(float(her.get("aspect", 0.0)) - 1802.0 / 1050.0) < 0.002 and absf(float(him.get("aspect", 0.0)) - 1802.0 / 1050.0) < 0.002
		and (her.get("breathe", []) as Array).size() == 2 and (her.get("eyes", []) as Array).size() == 3
		and (him.get("breathe", []) as Array).size() >= 1 and (him.get("eyes", []) as Array).size() >= 1)
	_check("B17 the curandera's and the librarian's .json give draft 28's and librarian2's crop, swipe paint and cursor (no paintings needed)", ok,
		"her %s; his %s" % [her, him])


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
	# tall: 352 wide), every rect (see _layout_off).
	var layout_off: Array[String] = ["no box"]

	if painted != null:
		await _to_options(painted)
		layout_off = _layout_off(painted, Vector2(1920, 1080))

	_check("B18 the painted box's layout at 1920x1080 is draft 28's (panel, portrait, words, options, swipes)", layout_off.is_empty(),
		"; ".join(layout_off) if not layout_off.is_empty() else "panel %s portrait %s" % [painted.layout_rects()["panel"], painted.layout_rects()["portrait"]])

	# B24: the same at 1280 x 720, two thirds as big.
	var small_off: Array[String] = ["no box"]

	if painted != null:
		small_off = _layout_off(painted, Vector2(1280, 720))
		painted._layout(painted._screen())

	_check("B24 at 1280x720 the painted box is draft 28's, two thirds as big", small_off.is_empty(),
		"; ".join(small_off) if not small_off.is_empty() else "all rects 2/3")

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
		b20_ok = (_flag(pm, &"living") and calm[0] < 0.01 and flare[0] > 0.5 and dim[0] < 0.01
			and flare[1] > 0.5 and calm[1] < 0.1 and dim[2] > 0.5 and calm[2] < 0.1 and gutter > 0.5
			and eye_colour.distance_to(Vector3(colour.r, colour.g, colour.b)) < 0.01
			and shift.length() > 0.5 and shift.length() <= 4.0)
		b20 = "eyes calm %.2f flare %.2f dim %.2f; warmth %.2f/%.2f; grey %.2f/%.2f; flicker %.2f; eye colour %s (shade %s); shift %s" % [calm[0],
			flare[0], dim[0], calm[1], flare[1], calm[2], dim[2], gutter, eye_colour, colour, shift]

	_check("B20 the eyes glow in the shade's colour only on a cue (none at rest) and follow flare, dim and gutter; the portrait warms, greys and flickers; the panel shifts a little",
		b20_ok, b20)
	await _close(painted)
	var decoded: int = TalkSkin.decodes
	var again: Node = await _open(player, "fx_curandera")
	var again_ok: bool = again != null and again.skin.backdrop != null and TalkSkin.decodes == decoded and decoded >= 3
	_check("B23 a second open of the same character decodes no painting again", again_ok,
		"decodes %d then %d, painted %s" % [decoded, TalkSkin.decodes, again.skin.backdrop if again else null])
	await _close(again)

	var plain: Node = await _open(player, "fx_librarian")
	var plain_ok: bool = (plain != null and plain.skin.backdrop == null and plain.skin.portrait == null and plain._viewport != null
		and _flag(plain._panel.material, &"procedural"))
	_check("B8 a skinned character opens the painted box, an unskinned one the plain box", her_ok and plain_ok,
		"hers: backdrop %s portrait %s cursor %s live %s; his: backdrop %s live %s" % [skin.backdrop if skin else null, skin.portrait if skin else null,
			skin.cursor if skin else null, painted._viewport if painted else null, plain.skin.backdrop if plain else null,
			plain._viewport if plain else null])
	var camera: Camera3D = plain._camera if plain != null else null
	var mask: int = camera.cull_mask if camera != null else 0
	_check("B26 the live portrait's camera sees the world, actors and effects, never the hands or the gem probe, 25 m out",
		camera != null and mask & (Layers.VIEWMODEL | Layers.GEM_PROBE) == 0 and mask & Layers.ACTORS != 0 and mask & Layers.FX != 0
		and mask & 1 != 0 and absf(camera.far - 25.0) < 0.5,
		"mask %x, far %.1f" % [mask, camera.far if camera != null else -1.0])
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


# ---------------------------------------------------------------------------
# B25, B27-B35: the box as a working piece of the game's UI
# ---------------------------------------------------------------------------

func _functional() -> void:
	DialogueBook.use(DialogueBook.load_dir(FIXTURES))
	CityState.begin()
	CityState.people.load_state({})
	TalkSkin.root = PAINTED
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.reload_on_death = false
	player.invulnerable = true
	player.global_position = Vector3(0, 1.05, 0)
	await _frames(10)
	var listener := Listener.new()
	OS.add_logger(listener)

	# B29 (1): back is held before the talk opens, and stays held.
	Input.action_press("move_back")
	await _frames(2)
	var box: Node = await _open(player, "fx_curandera")
	await _frames(int(ceil(TalkBox.WALK_AWAY * 60.0)) + 10)
	var held_through: bool = box != null and player.frob.talking() == box
	Input.action_release("move_back")
	await _frames(3)
	var shade: Node = box.shade if box != null else null

	if box == null:
		_check("B25 while talking the HUD shows no rows at all", false, "no box")
		player.queue_free()
		OS.remove_logger(listener)
		return

	# B25 (the line).
	var line_rows: Array = player.frob.current_actions()

	# B34: the view has eased round; the head stands above the panel.
	await _frames(60)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var head: Vector3 = shade.head_point()
	var on_screen: Vector2 = camera.unproject_position(head) if camera != null else Vector2(-1, -1)
	var panel: Rect2 = box.layout_rects()["panel"]
	var k: float = box._screen().y / 1080.0
	_check("B34 the view eases so the speaker's head stands just above the panel",
		camera != null and not camera.is_position_behind(head) and on_screen.y < panel.position.y - 40.0 * k and on_screen.y > panel.position.y - 220.0 * k
		and on_screen.x > panel.position.x and on_screen.x < panel.end.x,
		"head at %s, panel top %.1f (x %.1f..%.1f)" % [on_screen, panel.position.y, panel.position.x, panel.end.x])

	# B35: no type size is re-set while nothing changes size.
	var changed := [0]
	var count := func() -> void: changed[0] += 1

	for label in [box._name, box._words]:
		(label as Control).theme_changed.connect(count)

	await _frames(20)

	for label in [box._name, box._words]:
		(label as Control).theme_changed.disconnect(count)

	_check("B35 the box does not re-set its type sizes every frame", changed[0] == 0, "%d theme changes in 20 frames" % changed[0])

	# B33: the paint is whole up to a narrow fray.
	var soft := [_num(box._panel.material, &"fray_soft"), _num(box._portrait.material, &"fray_soft")]
	_check("B33 the panel's and the portrait's paint is whole up to a narrow fray (no translucent band)",
		soft.all(func(s): return s > 0.0 and s <= 6.0), "fray soft %s px" % [soft])

	# B32: paused, the box's words hide under the pause screen.
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	var hidden_paused: bool = not box._words.is_visible_in_tree() and not box._name.is_visible_in_tree()
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame
	var back_after: bool = box._words.is_visible_in_tree() and box._name.is_visible_in_tree()

	# On to the options (B25 again).
	await _to_options(box)
	var option_rows: Array = player.frob.current_actions()
	var hud_rows: PackedStringArray = player.hud.prompt_texts() if player.hud != null else PackedStringArray()
	_check("B25 while talking the HUD shows no rows at all (line or options)",
		line_rows.is_empty() and option_rows.is_empty() and hud_rows.is_empty(),
		"line %s, options %s, HUD %s" % [line_rows, option_rows, hud_rows])

	# B32 (the options too).
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	var options_hidden: bool = box._option_labels.all(func(l): return not (l as Control).is_visible_in_tree()) \
		and box._swipes.all(func(s): return not (s as Control).is_visible_in_tree())
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame
	var options_back: bool = box._option_labels.all(func(l): return (l as Control).is_visible_in_tree())
	_check("B32 paused, the box's words and options hide under the pause screen, and come back",
		hidden_paused and back_after and options_hidden and options_back,
		"words hidden %s, back %s; options hidden %s, back %s" % [hidden_paused, back_after, options_hidden, options_back])

	# B31 (1): the mouse over the second swipe chooses it, repainted gold.
	var offered: Array = box.shown_options()
	var second: Rect2 = box.layout_rects().get("swipe 1", Rect2())
	await _point(second.get_center())
	var chose: int = box._choice
	var repainting: float = box._swipe_reveal[1] if box._swipe_reveal.size() > 1 else -1.0
	await _frames(30)
	var repainted: float = box._swipe_reveal[1] if box._swipe_reveal.size() > 1 else -1.0
	var gold: bool = box._swipes.size() > 1 and _flag(box._swipes[1].material, &"warm") \
		and (box._option_labels[1] as Label).get_theme_color(&"font_color") == TalkBox.DARK_INK

	# B30 (1): the numpad's 1 picks the first option ("Ask about the book").
	var asked_text: String = offered[0] if not offered.is_empty() else ""
	await _key(KEY_KP_1)
	var picked_by_pad: bool = CityState.people.holds("said(asked)", "fx_curandera")

	# B28: pointing now (the options gone) touches nothing.
	listener.listening = true
	box.choose_by_pointing(1)
	box.choose_by_pointing(0)
	box.choose_by_pointing(5)
	await _frames(2)
	listener.listening = false
	var stale_errors: Array[String] = listener.errors.duplicate()
	listener.errors.clear()
	_check("B28 pointing after a choice touches nothing that has gone", stale_errors.is_empty() and box.is_open(),
		"errors %s, open %s" % [stale_errors, box.is_open()])

	# B30 (2): on her next options, the physical 1 key (no key code at all)
	# picks "Ask for the book as a gift".
	await _to_options(box)
	var gift_options: Array = box.shown_options()
	await _key(KEY_1)
	await _frames(40)
	var gifted: bool = box.shown_text() == "<<Take it, then.>>" or box._text == "<<Take it, then.>>"
	_check("B30 number keys by their physical key, and the numpad's, pick",
		picked_by_pad and asked_text == "<<Ask about the book.>>" and gift_options.size() >= 1 and gifted,
		"numpad picked %s ('%s'), then options %s, the 1 key gave '%s'" % [picked_by_pad, asked_text, gift_options, box._text])

	# B31 (2): a click on the last option picks it; the box closes, and the
	# click is no blow.
	await _to_options(box)
	var take: Rect2 = box.layout_rects().get("swipe 0", Rect2())
	var pressed_before: float = player.combat._attack_pressed_at
	await _point(take.get_center(), true)
	var closed_by_click: bool = player.frob.talking() == null
	await _frames(12)
	var no_blow: bool = player.combat._attack_pressed_at == pressed_before and player.combat.phase == player.combat.Phase.IDLE
	_check("B31 the mouse: over a swipe chooses it (repainted gold), a click picks it, and the click that closes the box is no blow",
		chose == 1 and repainting < 1.0 and repainted >= 1.0 and gold and closed_by_click and no_blow,
		"chose %d, repainting %.2f then %.2f, gold %s; closed by the click %s, no blow %s (pressed at %.2f, phase %s)" % [chose, repainting,
			repainted, gold, closed_by_click, no_blow, player.combat._attack_pressed_at, player.combat.phase])

	# B27: E (and talk) while the box lifts off: no second box.
	var lifting: bool = is_instance_valid(box) and box._closing
	player.frob.talk(shade)
	Input.action_press("frob")
	await _frames(1)
	Input.action_release("frob")
	await _frames(1)
	var boxes := player.get_children().filter(func(n): return n is TalkBox and not n.is_queued_for_deletion()).size()
	var second_box: bool = player.frob.talking() != null
	await _frames(40)
	player.frob.talk(shade)
	var after_lift: Node = player.frob.talking()
	_check("B27 E pressed while the box lifts off opens no second box; after it, a talk opens again",
		lifting and boxes <= 1 and not second_box and after_lift != null,
		"lifting %s, boxes %d, second up %s, after %s" % [lifting, boxes, second_box, after_lift])

	# B29 (2): a fresh hold of back walks away.
	await _frames(40)
	Input.action_press("move_back")
	await _frames(int(ceil(TalkBox.WALK_AWAY * 60.0)) + 4)
	var walked: bool = player.frob.talking() == null and CityState.people.holds("said(walked_off)", "fx_curandera")
	Input.action_release("move_back")
	_check("B29 a back key already held when the talk opens is not walking away; a fresh hold is",
		held_through and walked, "open while the old hold lasted %s; walked off on a fresh hold %s" % [held_through, walked])

	await _frames(30)
	OS.remove_logger(listener)

	if is_instance_valid(shade):
		shade.queue_free()

	player.queue_free()
	await _frames(2)
	TalkSkin.root = _real_root
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


## Told out, then on to the options.
func _to_options(box: Node) -> void:
	var tries := 0

	while box.shown_options().is_empty() and tries < 30:
		box.press_advance()
		await _frames(12)
		tries += 1

	await _frames(int(ceil(TalkBox.OPTION_GUARD * 60.0)) + 20)


## Every rect of `box` laid out on `screen`, against draft 28's numbers by
## hand (scaled by the height over 1080): the panel 1000 wide at the skin's
## shape, its top 40 below H - its height; the portrait 470 tall at its
## shape, 70 over the panel's left and 70 above it; the pair centred; the
## name across the panel at 146, the line's 560 in its middle at 182; the
## options' words 30 into one shared column (the longest + 70) at 318 + 50 i;
## the swipes from the column's left, the unchosen ones the column wide and
## 42 tall from 6 above the words, the chosen one longer by the marker
## (150 - 20) and 46 tall from 8 above.
func _layout_off(box: Node, screen: Vector2) -> Array[String]:
	box._layout(screen)
	var rects: Dictionary = box.layout_rects()
	var k := screen.y / 1080.0
	var wide := 1000.0 * k
	var tall: float = wide / box.skin.panel_aspect()
	var face_wide: float = 470.0 * k * box.skin.face_aspect()
	var left := (screen.x - (face_wide - 70.0 * k + wide)) * 0.5 + face_wide - 70.0 * k
	var top := screen.y - tall + 40.0 * k
	var column: float = box._plan.get("column", 0.0)
	var words_x := left + ((1000.0 - column) * 0.5 + 30.0) * k
	var want := {
		"panel": [rects.get("panel"), Rect2(left, top, wide, tall)],
		"portrait": [rects.get("portrait"), Rect2(left - face_wide + 70.0 * k, top - 70.0 * k, face_wide, 470.0 * k)],
	}
	var off: Array[String] = []

	for key in want:
		var got: Rect2 = want[key][0] if want[key][0] is Rect2 else Rect2()
		var w: Rect2 = want[key][1]

		if got.position.distance_to(w.position) > 2.0 or got.size.distance_to(w.size) > 2.0:
			off.append("%s %s not %s" % [key, got, w])

	var points := {"name x": [(rects.get("name", Rect2()) as Rect2).position.x, left], "name y": [(rects.get("name", Rect2()) as Rect2).position.y, top + 146.0 * k],
		"line x": [(rects.get("line", Rect2()) as Rect2).position.x, left + 220.0 * k], "line y": [(rects.get("line", Rect2()) as Rect2).position.y, top + 182.0 * k]}

	for i in box._options.size():
		var chosen: bool = i == box._choice
		var words: Rect2 = rects.get("option %d" % i, Rect2())
		var swipe: Rect2 = rects.get("swipe %d" % i, Rect2())
		points["option %d x" % i] = [words.position.x, words_x]
		points["option %d y" % i] = [words.position.y, top + (318.0 + 50.0 * i) * k]
		points["swipe %d x" % i] = [swipe.position.x, words_x - 30.0 * k]
		points["swipe %d y" % i] = [swipe.position.y, top + (318.0 + 50.0 * i - (8.0 if chosen else 6.0)) * k]
		points["swipe %d w" % i] = [swipe.size.x, (column + (130.0 if chosen else 0.0)) * k]
		points["swipe %d h" % i] = [swipe.size.y, (46.0 if chosen else 42.0) * k]

	for key in points:
		if absf(float(points[key][0]) - float(points[key][1])) > 2.0:
			off.append("%s %.1f not %.1f" % [key, points[key][0], points[key][1]])

	if box._options.size() < 2 or column < 70.0:
		off.append("options %d, column %.1f" % [box._options.size(), column])

	return off


## The mouse at `at` (the box's canvas units), and a left click there.
func _point(at: Vector2, click := false) -> void:
	var to_window := get_viewport().get_final_transform()
	var motion := InputEventMouseMotion.new()
	motion.position = to_window * at
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await _frames(2)

	if not click:
		return

	for down in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = down
		button.position = motion.position
		button.global_position = motion.position
		Input.parse_input_event(button)
		Input.flush_buffered_events()
		await _frames(1)


## A key pressed and let go, known only by where it sits (its physical key).
func _key(physical: Key) -> void:
	for down in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = physical
		key.pressed = down
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await _frames(1)


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
