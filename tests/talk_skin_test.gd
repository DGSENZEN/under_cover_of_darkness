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
##   B36  an obsidian option's swipe wears its school chosen and unchosen; a
##        bare ! keeps the plain special look
##   B37  a Sense obsidian line takes the school's ink and doubling
##   B38  seven options: every one in view lies whole on the screen
##   B39  the wheel to the seventh keeps the chosen in view; number keys pick
##        by absolute place
##   B40  four options keep draft 28's rows (318 + 50 i)
##   B41  4-7 options at 1080p and 720p, painted and plain, every choice: each
##        option's words, ascent to descent, lie inside its swipe's painted
##        bristle band (the swipe shader's BAND_TOP..BAND_BOTTOM)
##   B42  a 3- or 4-line spoken line over a scrolling list: the top fade
##        never overlaps it, and every row in view stays whole on screen
##   B43  the wheel stops at the first and the last option (no wrapping)
##   B44  the live portrait: no positional shadows, a lean environment of its
##        own (no volumetric fog, SSAO, SSR or SSIL; glow modest; the world's
##        own untouched), rendered about 30 times a second
##   B45  plan() measures each text once, not every frame
##   B47  a 600-letter spoken line (and Sense line) at 1080p and 720p breaks
##        into 2 pages or more, none losing a word, each page's height as
##        its label draws it inside the line's area (182 to 318)
##   B48  E (and Enter) walks the pages (each told out afresh, the
##        more-marker on all but the last), the Sense line's after, then the
##        options
##   B49  options up, the wheel over the line pages back and on through the
##        pages read, over the options it still chooses; PageUp and
##        PageDown page; the marker and the line's area clear of the options
##        and their fade
##   B50  a short line is one page, as written, with no marker
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
	await _schools()
	await _many()
	await _rows_in_paint()
	await _paging()
	await _portrait_cost()
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
# B36-B37: magic options and Sense lines wear their school
# ---------------------------------------------------------------------------

## A character `id` whose opener has a Sense obsidian line, a spoken line,
## then an obsidian option, a bare ! one and a plain one.
func _schooled(id: String) -> String:
	return "\n".join(["== character %s" % id, "name: Fx", "body: duelist", "voice: female", "colour: copal",
		"== beat open", "Fx: <<Look.>>", "Sense obsidian: <<The glass is cold.>>", "Fx: <<Choose.>>",
		"> !obsidian <<Read the glass.>> -> end", "> ! <<Bleed for it.>> -> end", "> <<Leave.>> -> end"])


## Each option's look now: [school uniform, warm, its ink, its doubling's alpha].
func _option_looks(box: Node) -> Array:
	var looks := []

	for i in box._swipes.size():
		var material: Material = box._swipes[i].material
		var label: Label = box._option_labels[i]
		looks.append([int(_num(material, &"school")), _flag(material, &"warm"), label.get_theme_color(&"font_color"),
			label.get_theme_color(&"font_shadow_color").a])

	return looks


## The words' and the name's look now: [ink, doubling alpha, doubling offset, name ink].
func _words_look(box: Node) -> Array:
	var words: Label = box._words
	return [words.get_theme_color(&"font_color"), words.get_theme_color(&"font_shadow_color").a,
		Vector2(words.get_theme_constant(&"shadow_offset_x"), words.get_theme_constant(&"shadow_offset_y")),
		(box._name as Label).get_theme_color(&"font_color")]


func _schools() -> void:
	DialogueBook.use(DialogueBook.check_alone({"fx_curandera.dialogue": _schooled("fx_curandera"),
		"fx_plain.dialogue": _schooled("fx_plain")}))
	CityState.begin()
	CityState.people.load_state({})
	TalkSkin.root = PAINTED
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.reload_on_death = false
	player.invulnerable = true
	player.global_position = Vector3(0, 1.05, 0)
	await _frames(10)
	var obsidian: int = DialogueBook.SCHOOLS.find("obsidian") + 1
	var look: Dictionary = TalkBox.SCHOOL_LOOK.get("obsidian", {})
	var b36: Array[String] = []
	var b37: Array[String] = []

	for id in ["fx_curandera", "fx_plain"]:
		var box: Node = await _open(player, id)

		if box == null:
			b36.append("%s: no box" % id)
			b37.append("%s: no box" % id)
			continue

		var painted: bool = box.skin.backdrop != null
		var tries := 0

		while box._kind != &"sense" and tries < 10:
			box.press_advance()
			await _frames(12)
			tries += 1

		var sense := _words_look(box)

		while box._kind != &"line" and tries < 20:
			box.press_advance()
			await _frames(12)
			tries += 1

		var spoken := _words_look(box)
		await _to_options(box)
		var first := _option_looks(box)
		box.choose_by_pointing(1)
		await _frames(3)
		var second := _option_looks(box)
		var where := "%s (%s)" % [id, "painted" if painted else "plain"]

		# Unchosen: dim, its own ink; chosen: its own chosen treatment (not the
		# gold wash's dark ink) and still clearly the chosen one (warm set).
		var ok_36: bool = (first.size() == 3 and second.size() == 3 and painted == (id == "fx_curandera")
			and first[0][0] == obsidian and first[0][1] == true and first[0][2] == look.get("chosen") and first[0][3] > 0.0
			and second[0][0] == obsidian and second[0][1] == false and second[0][2] == look.get("ink") and second[0][3] > 0.0
			and first[1][0] == 0 and first[1][2] == TalkBox.COCHINEAL and first[1][3] == 0.0
			and second[1][0] == 0 and second[1][1] == true and second[1][2] == TalkBox.DARK_INK and second[1][3] == 0.0
			and first[2][0] == 0 and first[2][2] == TalkBox.MARIGOLD and first[2][3] == 0.0)

		if not ok_36:
			b36.append("%s: chosen first %s, then the bare ! %s" % [where, first, second])

		var ok_37: bool = (sense[0] == look.get("ink") and sense[1] > 0.0 and sense[2] != Vector2.ZERO and sense[3] == look.get("ink")
			and spoken[0] == TalkBox.CREAM and spoken[1] == 0.0 and spoken[3] == TalkBox.MARIGOLD)

		if not ok_37:
			b37.append("%s: sense %s, the spoken line after %s" % [where, sense, spoken])

		await _close(box)

	_check("B36 an obsidian option's swipe wears its school chosen and unchosen, on the painted and the plain box; a bare ! keeps the plain special look",
		b36.is_empty(), "; ".join(b36) if not b36.is_empty() else "obsidian swipes school %d both ways, cold ink doubled; bare ! cochineal, gold when chosen" % obsidian)
	_check("B37 a Sense obsidian line takes the school's ink and doubling; the next spoken line is plain again",
		b37.is_empty(), "; ".join(b37) if not b37.is_empty() else "both boxes")
	player.queue_free()
	await _frames(2)
	TalkSkin.root = _real_root
	DialogueBook.reload()


# ---------------------------------------------------------------------------
# B38-B40: any number of options
# ---------------------------------------------------------------------------

## A character `id` whose opener offers `count` options, each setting its own
## flag (o1, o2, ...) and ending.
func _offering(id: String, count: int) -> String:
	var lines := ["== character %s" % id, "name: Fx", "body: duelist", "voice: female", "colour: copal", "== beat open", "Fx: <<Choose.>>"]

	for i in count:
		lines.append("> <<Option number %d.>> -> end {do: set(o%d)}" % [i + 1, i + 1])

	return "\n".join(lines)


## Whether every option in view lies whole on `screen` (its words and its
## swipe), and every other one is hidden; what is wrong, else "".
func _rows_off(box: Node, screen: Vector2) -> String:
	box._layout(screen)
	var rects: Dictionary = box.layout_rects()
	var in_view: Array = box.options_in_view()
	var whole := Rect2(Vector2.ZERO, screen)
	var off: Array[String] = []

	for i in box._swipes.size():
		var shown: bool = box._swipes[i].visible and box._option_labels[i].visible

		if shown != in_view.has(i):
			off.append("row %d shown %s, in view %s" % [i, shown, in_view.has(i)])

		if in_view.has(i) and not (whole.encloses(rects["option %d" % i]) and whole.encloses(rects["swipe %d" % i])):
			off.append("row %d at %s / %s" % [i, rects["option %d" % i], rects["swipe %d" % i]])

	return "; ".join(off)


func _many() -> void:
	DialogueBook.use(DialogueBook.check_alone({"fx_curandera.dialogue": _offering("fx_curandera", 7),
		"fx_plain.dialogue": _offering("fx_plain", 7), "fx_four.dialogue": _offering("fx_four", 4)}))
	CityState.begin()
	CityState.people.load_state({})
	TalkSkin.root = PAINTED
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.reload_on_death = false
	player.invulnerable = true
	player.global_position = Vector3(0, 1.05, 0)
	await _frames(10)
	var big := Vector2(1920, 1080)
	var b38: Array[String] = []
	var b39: Array[String] = []

	for id in ["fx_curandera", "fx_plain"]:
		var box: Node = await _open(player, id)

		if box == null:
			b38.append("%s: no box" % id)
			continue

		await _to_options(box)
		var where := "%s (%s)" % [id, "painted" if box.skin.backdrop != null else "plain"]
		var off := _rows_off(box, big)
		var seen: Array = box.options_in_view()

		if box.shown_options().size() != 7 or off != "" or seen.size() >= 7 or seen.is_empty() or not box._fade_bottom.visible \
				or box._fade_top.visible or _rows_off(box, Vector2(1280, 720)) != "":
			b38.append("%s: %d options, in view %s, %s, fades %s/%s" % [where, box.shown_options().size(), seen, off,
				box._fade_top.visible, box._fade_bottom.visible])

		# The wheel down to the last: the chosen one always whole in view.
		var lost: Array[String] = []

		for i in range(1, 7):
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			Input.parse_input_event(wheel)
			Input.flush_buffered_events()
			await _frames(2)
			var row_off := _rows_off(box, big)

			if box._choice != i or not box.options_in_view().has(i) or row_off != "":
				lost.append("at %d: choice %d, in view %s %s" % [i, box._choice, box.options_in_view(), row_off])

		var top_fade: bool = box._fade_top.visible and not box._fade_bottom.visible
		# Scrolled to the end, a number key still picks by its own place: 2 is the second.
		await _key(KEY_2)
		await _frames(3)
		var picked: bool = CityState.people.holds("said(o2)", id) and not CityState.people.holds("said(o7)", id)

		if not lost.is_empty() or not top_fade or not picked:
			b39.append("%s: %s, fades top only %s, key 2 picked o2 %s" % [where, "; ".join(lost), top_fade, picked])

		await _close(box)

	# Four options sit as draft 28 has them: 318 + 50 i under the panel's top.
	var four: Node = await _open(player, "fx_four")
	var b40 := "no box"
	var b40_ok := false

	if four != null:
		await _to_options(four)
		four._layout(big)
		var rects: Dictionary = four.layout_rects()
		var top: float = (rects["panel"] as Rect2).position.y
		var ys := []

		for i in 4:
			ys.append(snappedf((rects["option %d" % i] as Rect2).position.y - top, 0.1))

		b40_ok = ys == [318.0, 368.0, 418.0, 468.0] and four.options_in_view() == [0, 1, 2, 3] and not four._fade_top.visible \
			and not four._fade_bottom.visible and is_equal_approx((rects["swipe 1"] as Rect2).size.y, 42.0)
		b40 = "rows at %s, in view %s, swipe 1 %s" % [ys, four.options_in_view(), rects["swipe 1"]]
		await _close(four)

	_check("B38 seven options at 1080p (and 720p): every option in view lies whole on the screen, the rest hidden, a fade under the list",
		b38.is_empty(), "; ".join(b38) if not b38.is_empty() else "painted and plain")
	_check("B39 the wheel to the seventh keeps the chosen option whole in view (the list scrolls, the fade moves over it); a number key still picks by its own place",
		b39.is_empty(), "; ".join(b39) if not b39.is_empty() else "painted and plain")
	_check("B40 four options keep draft 28's rows, 318 + 50 i, no fades", b40_ok, b40)
	player.queue_free()
	await _frames(2)
	TalkSkin.root = _real_root
	DialogueBook.reload()


# ---------------------------------------------------------------------------
# B41-B43: the rows in their paint, the fades, the wheel's ends
# ---------------------------------------------------------------------------

## The swipe shader's bristle band: the middle of its height the paint lies on.
func _band() -> Vector2:
	var code: String = (load("res://scripts/UI/talk_swipe.gdshader") as Shader).code
	var top := RegEx.create_from_string("const float BAND_TOP = ([0-9.]+);").search(code)
	var bottom := RegEx.create_from_string("const float BAND_BOTTOM = ([0-9.]+);").search(code)
	return Vector2(top.get_string(1).to_float() if top != null else -1.0, bottom.get_string(1).to_float() if bottom != null else -1.0)


## Each option in view whose words (ascent to descent, at the size they are
## drawn) stand outside its swipe's painted band on `screen`; "" if none.
func _band_off(box: Node, screen: Vector2) -> String:
	box._layout(screen)
	var band := _band()
	var off: Array[String] = []

	for i in box.options_in_view():
		var label: Label = box._option_labels[i]
		var font := label.get_theme_font(&"font")
		var size := label.get_theme_font_size(&"font_size")
		var words := Vector2(label.position.y, label.position.y + font.get_ascent(size) + font.get_descent(size))
		var swipe: Rect2 = box._swipes[i].get_rect()
		var paint := Vector2(swipe.position.y + band.x * swipe.size.y, swipe.position.y + band.y * swipe.size.y)

		if words.x < paint.x - 0.01 or words.y > paint.y + 0.01:
			off.append("%s row %d%s words %.1f-%.1f paint %.1f-%.1f" % [screen, i, " (chosen)" if i == box._choice else "", words.x,
				words.y, paint.x, paint.y])

	return "; ".join(off)


## A character `id` whose opener says `line` and offers `count` options.
func _saying(id: String, line: String, count: int) -> String:
	return _offering(id, count).replace("Fx: <<Choose.>>", "Fx: %s" % line)


## A spoken line of `lines` lines in the box (its font, its width), made of
## words; a placeholder, so it reads as one still to write.
func _line_of(lines: int) -> String:
	var font: SystemFont = TalkBox._serif(400, false)
	var text := ""

	for words in range(4, 200):
		text = "<<%s>>" % " ".join(PackedStringArray(range(words).map(func(w): return "word%d" % w)))
		var high := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, TalkBox.LINE_WIDE, TalkBox.LINE_SIZE).y

		if int(round(high / font.get_height(TalkBox.LINE_SIZE))) == lines:
			return text

	return text


func _wheel(down: bool) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	await _frames(2)


func _rows_in_paint() -> void:
	CityState.begin()
	CityState.people.load_state({})
	TalkSkin.root = PAINTED
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.reload_on_death = false
	player.invulnerable = true
	player.global_position = Vector3(0, 1.05, 0)
	await _frames(10)
	var screens := [Vector2(1920, 1080), Vector2(1280, 720)]
	var b41: Array[String] = []
	var thinnest := 1.0

	for id in ["fx_curandera", "fx_plain"]:
		for count in [4, 5, 6, 7]:
			DialogueBook.use(DialogueBook.check_alone({"%s.dialogue" % id: _offering(id, count)}))
			var box: Node = await _open(player, id)

			if box == null:
				b41.append("%s %d: no box" % [id, count])
				continue

			await _to_options(box)

			for choice in count:
				box.choose_by_pointing(choice)

				for screen in screens:
					var off := _band_off(box, screen)
					thinnest = minf(thinnest, float(box._plan.get("step", 50.0)) / TalkBox.OPTION_STEP)

					if off != "":
						b41.append("%s %d options, choice %d: %s" % [id, count, choice, off])

			box._layout(box._screen())
			await _close(box)

	_check("B41 4-7 options (painted and plain, 1080p and 720p, every choice): each option's words lie inside its swipe's painted band",
		b41.is_empty() and _band().x > 0.0, "; ".join(b41.slice(0, 4)) if not b41.is_empty() else "closest rows %.2f of draft 28's step" % thinnest)

	# B42 and B43: a long spoken line over a list that scrolls.
	var b42: Array[String] = []
	var b43 := ""

	for lines in [3, 4]:
		DialogueBook.use(DialogueBook.check_alone({"fx_curandera.dialogue": _saying("fx_curandera", _line_of(lines), 7)}))
		var box: Node = await _open(player, "fx_curandera")

		if box == null:
			b42.append("%d lines: no box" % lines)
			continue

		await _to_options(box)

		if lines == 3:
			await _wheel(false)
			var stayed_first: bool = box._choice == 0

			for i in 8:
				await _wheel(true)

			b43 = "up from the first: %d; down past the last: %d of %d" % [0 if stayed_first else -1, box._choice, box._options.size()]

			if stayed_first and box._choice == box._options.size() - 1:
				b43 = "ok " + b43
		else:
			for i in 6:
				await _wheel(true)

		for screen in screens:
			box._layout(screen)
			var fade: Rect2 = box._fade_top.get_rect()
			var said: Rect2 = box._words.get_rect()
			var rows := _rows_off(box, screen)

			if not box._fade_top.visible or fade.intersects(said) or rows != "" or int(box._plan.get("in_view", 7)) >= 7:
				b42.append("%d lines at %s: fade %s (shown %s) over the line %s; rows %s; in view %d" % [lines, screen, fade, box._fade_top.visible,
					said, rows, int(box._plan.get("in_view", 7))])

		box._layout(box._screen())
		await _close(box)

	_check("B42 a 3- or 4-line spoken line over a scrolling list: the top fade never overlaps it, every row in view whole on screen (1080p, 720p)",
		b42.is_empty(), "; ".join(b42) if not b42.is_empty() else "3 and 4 lines")
	_check("B43 the wheel stops at the first and the last option, never wrapping round", b43.begins_with("ok "), b43)
	player.queue_free()
	await _frames(2)
	TalkSkin.root = _real_root
	DialogueBook.reload()


# ---------------------------------------------------------------------------
# B47-B50: a long line in pages
# ---------------------------------------------------------------------------

## A placeholder line of sentences at least `letters` long (`seed` turns
## which sentence it starts on).
func _long_line(letters: int, seed_value: int) -> String:
	var sentences := ["She turns the egg over the smoke and does not look up.", "The copal has gone dark at its edges, as it does when the dead come close.",
		"Her hands know the work better than she does; they have done it longer.", "Somewhere down the lane a train goes by under the stone.",
		"She says the book was never his to keep, and the saint on her shelf says nothing.", "Ask her again and she will tell you less."]
	var text := ""
	var i := seed_value

	while text.length() < letters:
		text += ("" if text == "" else " ") + String(sentences[i % sentences.size()])
		i += 1

	return "<<%s>>" % text


## Squeezed to single spaces, to compare words with words.
static func _words_of(text: String) -> String:
	return " ".join(text.split(" ", false))


## Each page of `box`'s line whose height, as a label like the box's draws it
## on `screen`, is more than the line's area; "" if none.
func _pages_off(box: Node, screen: Vector2) -> String:
	box._layout(screen)
	var k := screen.y / 1080.0
	var room := (TalkBox.OPTIONS_AT - TalkBox.LINE_AT) * k
	var source: Label = box._words
	var probe := Label.new()
	probe.add_theme_font_override("font", source.get_theme_font(&"font"))
	probe.add_theme_font_size_override("font_size", source.get_theme_font_size(&"font_size"))
	probe.add_theme_constant_override("line_spacing", source.get_theme_constant(&"line_spacing"))
	probe.autowrap_mode = source.autowrap_mode
	probe.horizontal_alignment = source.horizontal_alignment
	probe.vertical_alignment = source.vertical_alignment
	probe.modulate.a = 0.0
	add_child(probe)
	probe.size = Vector2(source.size.x, 1.0)
	var off: Array[String] = []
	var pages: Array[String] = box.pages()

	for i in pages.size():
		probe.text = pages[i]
		await get_tree().process_frame
		var high := probe.get_minimum_size().y

		if high > room + 0.01:
			off.append("%s page %d %.1f px over %.1f (%d lines)" % [screen, i, high, room, probe.get_line_count()])

	probe.queue_free()
	return "; ".join(off)


## A wheel turn at `at` (the box's canvas units).
func _wheel_at(at: Vector2, down: bool) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = get_viewport().get_final_transform() * at
	wheel.global_position = wheel.position
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	await _frames(2)


func _paging() -> void:
	var said := _long_line(600, 0)
	var sensed := _long_line(600, 3)
	# (_saying puts the speaker before it.)
	var lines := "%s\nSense obsidian: %s" % [said, sensed]
	DialogueBook.use(DialogueBook.check_alone({"fx_curandera.dialogue": _saying("fx_curandera", lines, 3),
		"fx_four.dialogue": _offering("fx_four", 3)}))
	CityState.begin()
	CityState.people.load_state({})
	TalkSkin.root = PAINTED
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.reload_on_death = false
	player.invulnerable = true
	player.global_position = Vector3(0, 1.05, 0)
	await _frames(10)
	var screens := [Vector2(1920, 1080), Vector2(1280, 720)]
	var b47: Array[String] = []
	var b47_seen: Array[String] = []
	var b48: Array[String] = []
	var b49: Array[String] = []
	var box: Node = await _open(player, "fx_curandera")

	if box == null:
		b47.append("no box")
	else:
		# B47 and B48: each line's pages at both sizes, then E through them.
		for kind in [&"line", &"sense"]:
			var whole: String = said if kind == &"line" else sensed

			if box._kind != kind:
				b48.append("%s: the box shows %s" % [kind, box._kind])
				break

			for screen in screens:
				var off: String = await _pages_off(box, screen)
				var pages: Array[String] = box.pages()
				b47_seen.append("%s %dp: %d pages of %s lines" % [kind, int(screen.y), pages.size(), box._page_lines])

				if pages.size() < 2 or off != "" or _words_of(" ".join(pages)) != _words_of(whole) or box.page() != 0:
					b47.append("%s at %s: %d pages (on %d) %s%s" % [kind, screen, pages.size(), box.page(), off,
						"" if _words_of(" ".join(pages)) == _words_of(whole) else ", words lost: %s" % [pages]])

			box._layout(box._screen())
			var count: int = box.pages().size()
			var walked := []

			for i in count:
				var fresh: bool = box.shown_text().length() < String(box.pages()[i]).length()
				walked.append([box.page(), fresh, box.more_shown(), box.shown_options().size()])

				if box.page() != i or not fresh or box.more_shown() != (i < count - 1) or not box.shown_options().is_empty():
					b48.append("%s page %d: on %d, told out afresh %s, marker %s, options %d" % [kind, i, box.page(), fresh, box.more_shown(),
						box.shown_options().size()])

				# The first press tells it out, the next turns the page (or goes on).
				box.press_advance()
				await _frames(2)

				if box.shown_text() != String(box.pages()[i]) or box.page() != i:
					b48.append("%s page %d not told out whole by E" % [kind, i])

				# (The Sense line's pages turned with Enter, the spoken line's with E.)
				if kind == &"sense":
					await _key(KEY_ENTER)
				else:
					box.press_advance()
					await _frames(2)

		var options: bool = box._kind == &"options" and box.shown_options().size() == 3

		if not options:
			b48.append("after the last page: %s, %d options" % [box._kind, box.shown_options().size()])
		else:
			# B49: options up on the Sense line's last page.
			await _frames(int(ceil(TalkBox.OPTION_GUARD * 60.0)) + 5)
			var last: int = box.pages().size() - 1
			var area: Rect2 = box.layout_rects()["line area"]
			var choice: int = box._choice
			await _wheel_at(area.get_center(), false)
			var back: Array = [box.page(), box.shown_text() == String(box.pages()[box.page()]), box.more_shown(), box._choice]
			await _wheel_at(area.get_center(), true)
			var on: Array = [box.page(), box.more_shown(), box._choice]

			if back != [last - 1, true, true, choice] or on != [last, false, choice]:
				b49.append("wheel over the line: back %s, on %s (last page %d, choice %d)" % [back, on, last, choice])

			# The options still choose under the wheel (off the line), the page stays.
			var row: Rect2 = box.layout_rects()["swipe 0"]
			await _point(row.get_center())
			var pointed: int = box._choice
			await _wheel_at(row.get_center(), true)

			if box._choice != pointed + 1 or box.page() != last:
				b49.append("wheel over the options: choice %d (was %d), page %d" % [box._choice, pointed, box.page()])

			await _key(KEY_PAGEUP)
			var up: int = box.page()
			await _key(KEY_PAGEDOWN)

			if up != last - 1 or box.page() != last or box.shown_options().size() != 3:
				b49.append("PageUp to %d, PageDown to %d (last %d), options %d" % [up, box.page(), last, box.shown_options().size()])

			# Turned back, the marker and the line's area stay clear of every row in view and of the fade.
			box.page_by(-1)

			for screen in screens:
				box._layout(screen)
				var rects: Dictionary = box.layout_rects()
				var clear := [rects["more"], rects["line area"], rects["line"]]

				for i in box.options_in_view():
					for part: Rect2 in clear:
						if part.intersects(rects["swipe %d" % i]) or part.intersects(rects["option %d" % i]):
							b49.append("%s: %s over row %d %s" % [screen, part, i, rects["swipe %d" % i]])

				if box._fade_top.visible:
					for part: Rect2 in clear:
						if part.intersects(box._fade_top.get_rect()):
							b49.append("%s: %s over the fade" % [screen, part])

				if not (rects["panel"] as Rect2).encloses(rects["more"]) or not box.more_shown():
					b49.append("%s: the marker %s (shown %s) not inside the panel %s" % [screen, rects["more"], box.more_shown(), rects["panel"]])

			box._layout(box._screen())

		await _close(box)

	# B50: a short line, one page as written.
	var b50 := "no box"
	var b50_ok := false
	var short: Node = await _open(player, "fx_four")

	if short != null:
		var pages: Array[String] = short.pages()
		var marker: bool = short.more_shown()
		var k: float = short._plan["scale"]
		var rect: Rect2 = short.layout_rects()["line"]
		var top: float = (short.layout_rects()["panel"] as Rect2).position.y
		await _to_options(short)
		var row: float = ((short.layout_rects()["option 0"] as Rect2).position.y - top) / k
		b50_ok = pages == ["<<Choose.>>"] and not marker and short.shown_options().size() == 3 and not short.more_shown() \
			and absf((rect.position.y - top) / k - TalkBox.LINE_AT) < 0.1 and absf(rect.size.y / k - TalkBox.LINE_STEP) < 0.1 \
			and absf(row - TalkBox.OPTIONS_AT) < 0.1
		b50 = "pages %s, marker %s, line at %.1f %.1f tall, first option at %.1f (1080p px), options %d" % [pages, marker,
			(rect.position.y - top) / k, rect.size.y / k, row, short.shown_options().size()]
		await _close(short)

	_check("B47 a 600-letter spoken line and Sense line at 1080p and 720p break into 2 pages or more, no word lost, each page's drawn height inside the line's area",
		b47.is_empty(), "; ".join(b47) if not b47.is_empty() else "; ".join(b47_seen))
	_check("B48 E (and Enter) walks the pages, each told out afresh with the marker on all but the last, the Sense line's after, then the options",
		b48.is_empty(), "; ".join(b48) if not b48.is_empty() else "both lines")
	_check("B49 options up, the wheel over the line pages back and on through the pages read, over the options it still chooses; PageUp and PageDown page; the marker and the line's area clear of the options and the fade",
		b49.is_empty(), "; ".join(b49.slice(0, 6)) if not b49.is_empty() else "1080p and 720p")
	_check("B50 a short line is one page, as written, no marker, laid out as before", b50_ok, b50)
	player.queue_free()
	await _frames(2)
	TalkSkin.root = _real_root
	DialogueBook.reload()


# ---------------------------------------------------------------------------
# B44-B45: what the box costs
# ---------------------------------------------------------------------------

## A counter of `box` (-1 if it has none).
func _count(box: Node, counter: StringName) -> int:
	var value: Variant = box.get(counter)
	return int(value) if value != null else -1


func _portrait_cost() -> void:
	DialogueBook.use(DialogueBook.check_alone({"fx_plain.dialogue": _offering("fx_plain", 3)}))
	CityState.begin()
	CityState.people.load_state({})
	TalkSkin.root = BARE
	# A world as heavy as the Metro's: fog, SSAO, SSR, SSIL and glow.
	var world := WorldEnvironment.new()
	var heavy := Environment.new()
	heavy.volumetric_fog_enabled = true
	heavy.ssao_enabled = true
	heavy.ssr_enabled = true
	heavy.ssil_enabled = true
	heavy.glow_enabled = true
	heavy.glow_intensity = 2.0
	heavy.glow_bloom = 0.4
	world.environment = heavy
	add_child(world)
	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	player.reload_on_death = false
	player.invulnerable = true
	player.global_position = Vector3(0, 1.05, 0)
	await _frames(10)
	var box: Node = await _open(player, "fx_plain")
	var b44 := "no box"
	var b44_ok := false
	var b45 := "no box"
	var b45_ok := false

	if box != null and box._viewport != null:
		var viewport: SubViewport = box._viewport
		var lean: Environment = box._camera.environment
		var renders := _count(box, &"_portrait_renders")
		await _frames(60)
		renders = _count(box, &"_portrait_renders") - renders if renders >= 0 else -1
		b44_ok = viewport.positional_shadow_atlas_size == 0 and lean != null and lean != heavy and not lean.volumetric_fog_enabled \
			and not lean.ssao_enabled and not lean.ssr_enabled and not lean.ssil_enabled and lean.glow_intensity <= 0.8001 \
			and lean.glow_bloom <= 0.0501 and heavy.volumetric_fog_enabled and heavy.ssao_enabled and renders >= 26 and renders <= 34 \
			and viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS
		b44 = "shadow atlas %d, own environment %s, fog %s ssao %s ssr %s ssil %s glow %.2f bloom %.2f, world's fog %s; %d renders in 60 frames, mode %d" % [
			viewport.positional_shadow_atlas_size, lean != null and lean != heavy, lean.volumetric_fog_enabled if lean else null,
			lean.ssao_enabled if lean else null, lean.ssr_enabled if lean else null, lean.ssil_enabled if lean else null,
			lean.glow_intensity if lean else -1.0, lean.glow_bloom if lean else -1.0, heavy.volumetric_fog_enabled, renders,
			viewport.render_target_update_mode]

		await _to_options(box)
		var measured := _count(box, &"_measures")
		await _frames(30)
		b45_ok = measured > 0 and _count(box, &"_measures") == measured
		b45 = "measured %d texts by the options, %d more over 30 frames" % [measured, _count(box, &"_measures") - measured]
		await _close(box)

	_check("B44 the live portrait: no positional shadows, a lean environment of its own (no fog, SSAO, SSR, SSIL; glow modest), about 30 renders a second",
		b44_ok, b44)
	_check("B45 plan() measures each text once, not every frame", b45_ok, b45)

	# B46: no smoothstep in the talk shaders with its edges reversed or equal
	# (undefined in GLSL), and the nahual claws' edge kept apart where they taper to nothing.
	var bad: Array[String] = []

	for path in ["res://scripts/UI/talk_swipe.gdshader", "res://scripts/UI/talk_fade.gdshader", "res://scripts/UI/talk_paint.gdshader",
			"res://scripts/UI/talk_school.gdshaderinc", "res://scripts/Visual/talk_shade.gdshader", "res://scripts/Visual/talk_shade_wisp.gdshader"]:
		var lines := FileAccess.get_file_as_string(path).split("\n")

		for n in lines.size():
			for found in RegEx.create_from_string("smoothstep\\(\\s*(-?[0-9.]+)\\s*,\\s*(-?[0-9.]+)\\s*,").search_all(lines[n]):
				if found.get_string(1).to_float() >= found.get_string(2).to_float():
					bad.append("%s:%d" % [path.get_file(), n + 1])

	var claws := FileAccess.get_file_as_string("res://scripts/UI/talk_school.gdshaderinc").contains("1.2 * max(taper, 1e-3) + 0.3")
	_check("B46 the talk shaders have no smoothstep with reversed or equal edges (the nahual's taper guarded)", bad.is_empty() and claws,
		"reversed %s, nahual guarded %s" % [bad, claws])
	player.queue_free()
	world.queue_free()
	await _frames(2)
	TalkSkin.root = _real_root
	DialogueBook.reload()


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
