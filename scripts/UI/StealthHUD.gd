extends CanvasLayer
## The HUD. Built in code, so Player.tscn stays simple. Deliberately small:
## your hands show what you carry and what you have stolen, so the screen
## only carries what the body cannot show.
##
##   centre         a dot that warms over anything usable, and under it the
##                  keys and what they do: [E] Open door   [LMB] Throw
##   bottom centre  the lightgem, a cut jewel: dark when hidden, amber when
##                  lit; its rim brightens with exposure (stance, movement)
##   above the gem  who is speaking and what they said
##   bottom left    health, as shields that only show when you are hurt
##   everywhere     a red vignette when hit, with an arc on the side the
##                  blow came from; the colour drains during a finisher; a
##                  fade to black when caught, and a pause screen on Esc
##
## Nothing here is read by gameplay. Hide the layer and the game is unchanged.

const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const AdrenalineViewScript := preload("res://scripts/Visual/AdrenalineView.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const GuardFighterScript := preload("res://scripts/AISystem/GuardFighter.gd")

const SUBTITLE_RANGE := 22.0
const INK := Color(0.93, 0.88, 0.78)
const DIM := Color(0.62, 0.58, 0.5)
const AMBER := Color(1.0, 0.78, 0.36)
const BLOOD := Color(0.62, 0.08, 0.06)

var player: CharacterBody3D

var _root: Control
var _font: SystemFont
var _crosshair: Crosshair
var _prompts: HBoxContainer
var _prompt_signature := ""
var _prompt_alpha := 0.0
var _gem: Gem
var _caption: Label
var _caption_timer := 0.0
var _subtitle_panel: PanelContainer
var _subtitle: RichTextLabel
var _subtitle_timer := 0.0
var _shields: Shields
var _shield_timer := 0.0
var _adrenaline: Adrenaline
## Full adrenaline, felt at the edges of the view.
var _adrenaline_view: CanvasLayer
var _vignette: TextureRect
var _hurt_marks: HurtMarks
## Amber arcs: a blow being wound up somewhere you are not looking.
var _warn_marks: HurtMarks
## Blood thrown across your eyes by a kill up close.
var _splatter: Splatter
var _grade: ColorRect
var _grade_amount := 0.0
var _last_real := -1.0
var _fade: ColorRect
var _death: Label
var _pause: Control
var _scan_timer := 0.0
var _listening := {}
## When a sting last played, so being noticed never becomes a racket.
var _sting_at := -100.0
var _stab_at := -100.0
var _last_item_name := ""


# ---------------------------------------------------------------------------
# Drawn pieces
# ---------------------------------------------------------------------------

class Crosshair:
	extends Control

	var warm := 0.0
	var draw_amount := 0.0
	## Stamina, 0..1, and how visible its arc is; `short`: too little left
	## to hold a blow.
	var stamina := 1.0
	var stamina_alpha := 0.0
	var short := false

	func _draw() -> void:
		var c := size * 0.5

		# Stamina: an arc under the crosshair, draining from the right.
		if stamina_alpha > 0.01:
			var from := PI * 0.18
			var to := PI * 0.82
			draw_arc(c, 17.0, from, to, 24, Color(0, 0, 0, 0.4 * stamina_alpha), 3.0, true)
			var colour := Color(0.95, 0.92, 0.85) if not short else Color(0.95, 0.3, 0.2)

			if stamina > 0.001:
				draw_arc(c, 17.0, to - (to - from) * stamina, to, 24, Color(colour.r, colour.g, colour.b, 0.8 * stamina_alpha), 2.0, true)

		if draw_amount > 0.0:
			var ring := lerpf(22.0, 4.0, draw_amount)
			draw_arc(c, ring, 0.0, TAU, 32, Color(1.0, 0.85, 0.55, 0.35 + 0.5 * draw_amount), 1.4, true)
		var radius := lerpf(1.6, 3.2, warm)
		var colour := Color(1, 1, 1, 0.35).lerp(Color(1.0, 0.8, 0.4, 0.95), warm)
		draw_circle(c, radius + 1.0, Color(0, 0, 0, 0.35 + 0.3 * warm))
		draw_circle(c, radius, colour)


class Gem:
	extends Control

	## Shown value, eased toward `target` the way The Dark Mod fades its gem.
	var light := 0.0
	var target := 0.0
	var exposure := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var top := c + Vector2(0, -r)
		var right := c + Vector2(r * 0.62, 0)
		var bottom := c + Vector2(0, r)
		var left := c + Vector2(-r * 0.62, 0)

		# Glow behind the stone, only when lit.
		for i in range(4):
			var g := r * (1.25 + i * 0.22)
			draw_circle(c, g, Color(AMBER.r, AMBER.g, AMBER.b, 0.05 * light * (4 - i) / 4.0))

		var dark := Color(0.05, 0.05, 0.08)
		var body := dark.lerp(AMBER, light)
		var shade := body.darkened(0.45)
		var shine := body.lightened(0.35)

		# Four facets: two lit from the upper left, two in shade.
		draw_colored_polygon(PackedVector2Array([top, c, left]), shine)
		draw_colored_polygon(PackedVector2Array([top, right, c]), body)
		draw_colored_polygon(PackedVector2Array([c, right, bottom]), shade)
		draw_colored_polygon(PackedVector2Array([left, c, bottom]), body.darkened(0.2))

		# The setting: a dark rim that brightens with exposure.
		var rim := Color(0.18, 0.17, 0.2).lerp(Color(1.0, 0.95, 0.82), exposure)
		draw_polyline(PackedVector2Array([top, right, bottom, left, top]), rim, 2.0, true)
		draw_line(top, bottom, Color(rim.r, rim.g, rim.b, 0.25), 1.0, true)


class Adrenaline:
	extends Control

	var fraction := 0.0
	var pulse := 0.0

	func _draw() -> void:
		var w := size.x
		draw_rect(Rect2(0, 0, w, 4), Color(0, 0, 0, 0.45))
		var colour := AMBER.lerp(Color(1.0, 0.95, 0.8), pulse)
		draw_rect(Rect2(0, 0, w * fraction, 4), colour)


## Arcs at the edge of the view, on the side each blow came from (or, in
## amber, is coming from).
class HurtMarks:
	extends Control

	## [angle (0 = ahead, clockwise), life 1..0, colour (optional)]
	var marks: Array = []
	var tint := Color(minf(BLOOD.r * 1.5, 1.0), BLOOD.g, BLOOD.b)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.36

		for m in marks:
			var angle: float = m[0]
			var life: float = m[1]
			# In the colour of what the blow asks of you (a red one: get out
			# of its way).
			var hue: Color = m[2] if m.size() > 2 and m[2] is Color else tint
			var colour := Color(hue.r, hue.g, hue.b, 0.8 * life)
			# draw_arc counts from the right, clockwise: ahead is -PI/2.
			var from := angle - 0.45 - PI * 0.5
			draw_arc(c, r, from, from + 0.9, 18, colour, 6.0 + 6.0 * life, true)


## Blood across your eyes: splashes at the edges of the view (each a blot
## with droplets flung round it, darker where it is thickest), the big ones
## running a little, all of them fading.
class Splatter:
	extends Control

	## [position, radius, life 1..0, how fast it fades, run length, shade,
	## blobs: [offset, radius] of the droplets that make it up]
	var drops: Array = []

	func _draw() -> void:
		for d in drops:
			var life: float = d[2]
			var shade: float = d[5]
			var alpha := 0.9 * minf(life * 1.8, 1.0)
			var thin := Color(0.3 * shade, 0.02 * shade, 0.014 * shade, alpha * 0.55)
			var thick := Color(0.2 * shade, 0.012 * shade, 0.01 * shade, alpha)
			var at: Vector2 = d[0]
			var radius: float = d[1]

			for blob in d[6]:
				var centre: Vector2 = at + (blob[0] as Vector2)
				var r: float = blob[1]
				draw_circle(centre, r, thin)
				draw_circle(centre + Vector2(r * 0.12, r * 0.1), r * 0.62, thick)

			# A run below the bigger ones, thinning as it goes.
			var run: float = d[4]

			if run > 1.0:
				var width := radius * 0.42
				var from := at + Vector2(0.0, radius * 0.4)
				draw_line(from, from + Vector2(radius * 0.08, run * 0.6), thick, width, true)
				draw_line(from + Vector2(radius * 0.08, run * 0.6), from + Vector2(radius * 0.05, run), thick, width * 0.55, true)
				draw_circle(from + Vector2(radius * 0.05, run), width * 0.5, thick)


class Shields:
	extends Control

	var fraction := 1.0
	var count := 5

	func _draw() -> void:
		var w := 14.0
		var gap := 5.0

		for i in range(count):
			var x := i * (w + gap)
			var fill := clampf(fraction * count - i, 0.0, 1.0)
			var outline := PackedVector2Array([
				Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w, 9),
				Vector2(x + w * 0.5, 17), Vector2(x, 9), Vector2(x, 0),
			])
			draw_colored_polygon(outline.slice(0, 5), Color(0, 0, 0, 0.45))

			if fill > 0.0:
				var h := 17.0 * fill
				var y := 17.0 - h
				var clip := PackedVector2Array([
					Vector2(x + 1, maxf(y, 1)), Vector2(x + w - 1, maxf(y, 1)),
					Vector2(x + w - 1, maxf(y, 9)), Vector2(x + w * 0.5, 16),
					Vector2(x + 1, maxf(y, 9)),
				])
				draw_colored_polygon(clip, BLOOD.lightened(0.15))

			draw_polyline(outline, DIM, 1.2, true)


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func setup(p_player: CharacterBody3D) -> void:
	player = p_player
	layer = 5
	# The pause screen must keep working while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Laid out every frame: never interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Palatino", "Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman", "serif"])

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_vignette = TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.0))
	gradient.set_color(1, Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.85))
	gradient.set_offset(0, 0.55)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	_vignette.texture = texture
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_root.add_child(_vignette)

	_hurt_marks = HurtMarks.new()
	_hurt_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hurt_marks)

	_warn_marks = HurtMarks.new()
	_warn_marks.tint = AMBER
	_warn_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warn_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_warn_marks)

	_splatter = Splatter.new()
	_splatter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splatter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_splatter)

	# The finisher's grade: colour drains, the edges darken to red.
	_grade = ColorRect.new()
	_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade_shader := Shader.new()
	grade_shader.code = GRADE_SHADER
	var grade_material := ShaderMaterial.new()
	grade_material.shader = grade_shader
	_grade.material = grade_material
	_grade.visible = false
	_root.add_child(_grade)
	_root.move_child(_grade, 0)

	_crosshair = Crosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)

	_prompts = HBoxContainer.new()
	_prompts.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompts.add_theme_constant_override("separation", 22)
	_prompts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompts)

	_gem = Gem.new()
	_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_gem)

	_caption = _label(17, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_caption.modulate.a = 0.0

	_subtitle_panel = PanelContainer.new()
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0, 0, 0, 0.45)
	band.set_corner_radius_all(3)
	band.content_margin_left = 14
	band.content_margin_right = 14
	band.content_margin_top = 5
	band.content_margin_bottom = 6
	_subtitle_panel.add_theme_stylebox_override("panel", band)
	_subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_panel.modulate.a = 0.0
	_root.add_child(_subtitle_panel)
	_subtitle = RichTextLabel.new()
	_subtitle.bbcode_enabled = true
	_subtitle.fit_content = true
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	_subtitle.scroll_active = false
	_subtitle.add_theme_font_override("normal_font", _font)
	_subtitle.add_theme_font_size_override("normal_font_size", 21)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_panel.add_child(_subtitle)

	_shields = Shields.new()
	_shields.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shields.modulate.a = 0.0
	_root.add_child(_shields)

	_adrenaline = Adrenaline.new()
	_adrenaline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_adrenaline.modulate.a = 0.0
	_root.add_child(_adrenaline)
	_adrenaline_view = AdrenalineViewScript.new()
	_adrenaline_view.name = "AdrenalineView"
	add_child(_adrenaline_view)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	_death = _label(40, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_death.modulate.a = 0.0

	_build_pause()

	if player.has_signal("damaged"):
		player.damaged.connect(_on_damaged)

	if player.has_signal("died"):
		player.died.connect(func(): _death.text = "You were caught.")

	var combat: Node = player.get("combat")

	if combat != null and combat.has_signal("finisher_started"):
		combat.finisher_started.connect(func(): _grade_amount = 1.0)

	if player.get("inventory") != null:
		player.inventory.belt_selection_changed.connect(_on_item_selected)


func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.visible = false
	_root.add_child(_pause)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.add_child(dim)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	_pause.add_child(column)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_override("font", _font)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var hint := Label.new()
	hint.text = "Click to resume"
	hint.add_theme_font_override("font", _font)
	hint.add_theme_font_size_override("font_size", 19)
	hint.add_theme_color_override("font_color", DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	column.position = Vector2(-120, -50)
	column.size = Vector2(240, 100)


func _label(font_size: int, colour: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	return label


# ---------------------------------------------------------------------------
# Every frame
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	_pause.visible = get_tree().paused

	if get_tree().paused:
		return

	var view := _root.size
	var centre := view * 0.5

	# Prompts under the crosshair.
	var actions: Array = []

	if player.frob != null and player.frob.has_method("current_actions") and not player.is_dead:
		actions = player.frob.current_actions()

	# Falling toward a guard: the drop attack is offered.
	var fighting: Node = player.get("combat")

	if fighting != null and fighting.has_method("drop_target") and fighting.drop_target() != null and not player.is_on_floor():
		actions = [[&"throw", "Drop attack"]]

	_update_prompts(actions, delta)
	_crosshair.warm = lerpf(_crosshair.warm, 1.0 if not actions.is_empty() else 0.0, 1.0 - exp(-14.0 * delta))
	_crosshair.size = Vector2(52, 52)
	_crosshair.position = centre - _crosshair.size * 0.5
	_crosshair.queue_redraw()
	_prompts.position = Vector2(centre.x - 400, centre.y + 26)
	_prompts.size = Vector2(800, 30)
	_prompts.modulate.a = _prompt_alpha

	# The lightgem.
	_gem.target = player.get_light_level()
	_gem.light = lerpf(_gem.light, _gem.target, 1.0 - exp(-delta / 0.09))
	_gem.exposure = lerpf(_gem.exposure, player.get_exposure(), 1.0 - exp(-delta / 0.12))
	_gem.size = Vector2(40, 56)
	_gem.position = Vector2(centre.x - 20, view.y - 84)
	_gem.queue_redraw()

	# What just came into your hand, briefly.
	_caption_timer = maxf(_caption_timer - delta, 0.0)
	_caption.modulate.a = clampf(_caption_timer / 0.4, 0.0, 1.0)
	_place(_caption, Vector2(centre.x - 200, view.y - 118), Vector2(400, 24))

	# Subtitles.
	_subtitle_timer = maxf(_subtitle_timer - delta, 0.0)
	_subtitle_panel.modulate.a = clampf(_subtitle_timer / 0.35, 0.0, 1.0)
	var sub_size := _subtitle_panel.get_combined_minimum_size()
	_subtitle_panel.size = sub_size
	_subtitle_panel.position = Vector2(centre.x - sub_size.x * 0.5, view.y - 170)

	# Health: shields, only while hurt or just after a hit.
	var fraction := clampf(float(player.health) / maxf(float(player.max_health), 1.0), 0.0, 1.0)
	_shield_timer = maxf(_shield_timer - delta, 0.0)
	_shields.fraction = fraction
	var show_shields := fraction < 0.999 or _shield_timer > 0.0
	_shields.modulate.a = move_toward(_shields.modulate.a, 1.0 if show_shields else 0.0, delta * 2.0)
	_shields.position = Vector2(30, view.y - 50)
	_shields.size = Vector2(120, 20)
	_shields.queue_redraw()

	# Adrenaline: the bar while there is any; full, a finisher is ready, and
	# the edges of your sight beat with it.
	var combat: Node = player.get("combat")

	if combat != null:
		var a: float = combat.adrenaline / maxf(combat.adrenaline_max, 1.0)
		var winding: bool = combat.phase == combat.Phase.CHARGING or combat.phase == combat.Phase.WINDUP
		_adrenaline_view.set_health(float(player.health) / maxf(float(player.max_health), 1.0) if not player.is_dead else 1.0)
		_adrenaline_view.show_state(a if not player.is_dead else 0.0, winding, delta)
		_adrenaline.fraction = a
		_adrenaline.pulse = (0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)) if a >= 1.0 else 0.0
		_adrenaline.modulate.a = move_toward(_adrenaline.modulate.a, 1.0 if a > 0.0 else 0.0, delta * 2.0)
		_adrenaline.position = Vector2(30, view.y - 24)
		_adrenaline.size = Vector2(90, 4)
		_adrenaline.queue_redraw()

		# A drawn bow tightens the crosshair into a ring that closes.
		_crosshair.draw_amount = combat.draw if combat.phase == combat.Phase.DRAWING else 0.0

		# Stamina, only while it is not full.
		var s: float = combat.stamina / maxf(combat.stamina_max, 1.0)
		_crosshair.stamina = s
		_crosshair.short = combat.stamina < combat.block_cost_near()
		_crosshair.stamina_alpha = move_toward(_crosshair.stamina_alpha, 1.0 if s < 0.995 else 0.0, delta * 3.0)

	# Hurt, and caught. These run on real time: slow motion must not stretch
	# them.
	var real_delta := TimeFx.real_since(_last_real) if _last_real >= 0.0 else 0.0
	_last_real = TimeFx.real_time()
	_vignette.modulate.a = move_toward(_vignette.modulate.a, 0.0, delta * 1.2)

	for m in _hurt_marks.marks:
		m[1] = float(m[1]) - real_delta / 0.9

	_hurt_marks.marks = _hurt_marks.marks.filter(func(m): return float(m[1]) > 0.0)
	_hurt_marks.queue_redraw()

	for m in _warn_marks.marks:
		m[1] = float(m[1]) - real_delta / 0.6

	_warn_marks.marks = _warn_marks.marks.filter(func(m): return float(m[1]) > 0.0)
	_warn_marks.queue_redraw()

	if not _splatter.drops.is_empty():
		for d in _splatter.drops:
			d[2] = float(d[2]) - real_delta * float(d[3])

			# The big ones run, slowly, while they are wet.
			if float(d[1]) > 8.0 and float(d[2]) > 0.3:
				d[4] = minf(float(d[4]) + real_delta * float(d[1]) * 1.6, float(d[1]) * 4.0)

		_splatter.drops = _splatter.drops.filter(func(d): return float(d[2]) > 0.0)
		_splatter.queue_redraw()

	_grade_amount = move_toward(_grade_amount, 0.0, real_delta / 0.9)
	_grade.visible = _grade_amount > 0.01

	if _grade.visible:
		(_grade.material as ShaderMaterial).set_shader_parameter("amount", smoothstep(0.0, 0.35, _grade_amount))

	if player.is_dead:
		_fade.color.a = move_toward(_fade.color.a, 0.92, delta * 0.8)
		_death.modulate.a = move_toward(_death.modulate.a, 1.0, delta * 1.2)

	_place(_death, Vector2(centre.x - 400, centre.y - 40), Vector2(800, 60))

	# Find guards to listen to.
	_scan_timer -= delta

	if _scan_timer <= 0.0:
		_scan_timer = 1.0

		for guard in get_tree().get_nodes_in_group(&"guards"):
			if not _listening.has(guard) and guard.has_signal("barked"):
				_listening[guard] = true
				guard.barked.connect(_on_bark.bind(guard))

				if guard.has_signal("alert_changed"):
					guard.alert_changed.connect(_on_alert.bind(guard))


func _update_prompts(actions: Array, delta: float) -> void:
	var signature := str(actions)

	if actions.is_empty():
		_prompt_alpha = move_toward(_prompt_alpha, 0.0, delta * 8.0)

		if _prompt_alpha <= 0.0:
			_prompt_signature = ""
			_clear_prompts()

		return

	_prompt_alpha = move_toward(_prompt_alpha, 1.0, delta * 8.0)

	if signature == _prompt_signature:
		return

	_prompt_signature = signature
	_clear_prompts()

	for pair in actions:
		var action: StringName = pair[0]
		var verb: String = pair[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if action != &"":
			row.add_child(_key_cap(key_name(action)))

		var label := Label.new()
		label.text = verb
		label.add_theme_font_override("font", _font)
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", INK if action != &"" else DIM)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("outline_size", 6)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		_prompts.add_child(row)


func _clear_prompts() -> void:
	for child in _prompts.get_children():
		_prompts.remove_child(child)
		child.queue_free()


func _key_cap(text: String) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.08, 0.1, 0.8)
	box.border_color = Color(DIM.r, DIM.g, DIM.b, 0.9)
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 1
	box.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", AMBER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


## What the player presses for an input action: "E", "LMB", "Tab".
static func key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"

	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)

		if event is InputEventMouseButton:
			match (event as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT:
					return "LMB"
				MOUSE_BUTTON_RIGHT:
					return "RMB"
				MOUSE_BUTTON_MIDDLE:
					return "MMB"
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
					return "Wheel"

	return "?"


func prompt_texts() -> PackedStringArray:
	var texts := PackedStringArray()

	for row in _prompts.get_children():
		var parts := PackedStringArray()

		for piece in row.get_children():
			if piece is Label:
				parts.append((piece as Label).text)
			elif piece is PanelContainer:
				parts.append("[%s]" % (piece.get_child(0) as Label).text)

		texts.append(" ".join(parts))

	return texts


func _place(control: Control, at: Vector2, extent: Vector2) -> void:
	control.position = at
	control.size = extent


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _on_bark(text: String, guard: Node3D) -> void:
	if not is_instance_valid(guard) or not is_instance_valid(player):
		return

	if guard.global_position.distance_to(player.global_position) > SUBTITLE_RANGE:
		return

	var speaker: String = guard.get("speaker_name") if guard.get("speaker_name") != null else "Guard"
	_subtitle.text = "[color=#%s]%s[/color]   %s" % [DIM.to_html(false), speaker, text]
	_subtitle_timer = 3.2


## A guard's alert rose: a swell of unease when one grows suspicious, a stab
## when one comes for you. Only near enough to matter, and not too often.
func _on_alert(new_state: int, old_state: int, guard: Node3D) -> void:
	if not is_instance_valid(guard) or not is_instance_valid(player) or new_state <= old_state:
		return

	if guard.global_position.distance_to(player.global_position) > SUBTITLE_RANGE:
		return

	var now := TimeFx.real_time()

	# The stab matters most: it always plays, unless one just did. A swell
	# waits for quiet.
	if new_state >= 4:
		if now - _stab_at < 3.0:
			return

		Sfx.play_flat(self, &"sting_combat")
		_stab_at = now
		_sting_at = now
	elif new_state == 1 and now - _sting_at >= 3.0:
		Sfx.play_flat(self, &"sting_suspicious")
		_sting_at = now


func _on_item_selected(item: Dictionary) -> void:
	var item_name := String(item.get("name", ""))

	if item_name != "" and item_name != _last_item_name:
		_caption.text = item_name
		_caption_timer = 1.4

	_last_item_name = item_name


func _on_damaged(_amount: float) -> void:
	_vignette.modulate.a = 0.9
	_shield_timer = 4.0


## A blow landed from `from`, a direction in the player's own space.
func hurt_from(from: Vector3) -> void:
	if from.length() < 0.01:
		return

	_hurt_marks.marks.append([atan2(from.x, -from.z), 1.0])


## A guard began a blow. Out of sight (more than ~50 degrees off where you
## look), an amber arc shows where it is coming from.
func warn_attack(from: Node3D) -> void:
	if from == null or player == null:
		return

	var local: Vector3 = player.global_basis.inverse() * (from.global_position - player.global_position)
	local.y = 0.0

	if local.length() < 0.01 or (-local.z) / local.length() > 0.64:
		return

	var fighter: Variant = from.get("_fighter")
	var call: StringName = fighter.attack_info().get("call", &"cut") if fighter != null else &"cut"
	var hue: Color = AMBER if call == &"cut" else GuardFighterScript.call_colour(call)
	_warn_marks.marks.append([atan2(local.x, -local.z), 1.0, hue])


## A kill up close throws blood across your eyes (`amount` 0..1): drops
## about the edges of the view, never across the middle.
func splatter(amount: float) -> void:
	if Fx.gore <= 0.0 or _splatter == null:
		return

	var view := _splatter.size if _splatter.size.x > 1.0 else get_viewport().get_visible_rect().size
	var count := int(round(lerpf(5.0, 18.0, clampf(amount, 0.0, 1.0))))

	for n in count:
		# Toward one edge or corner: the middle of the view stays clear.
		var side := randi() % 4
		var at := Vector2(randf() * view.x, randf() * view.y)

		match side:
			0:
				at.x = randf_range(0.0, 0.24) * view.x
			1:
				at.x = randf_range(0.76, 1.0) * view.x
			2:
				at.y = randf_range(0.0, 0.2) * view.y
			_:
				at.y = randf_range(0.78, 1.0) * view.y

		# Mostly specks; now and then a real splash.
		var big := randf() < 0.2
		var radius := randf_range(1.5, 4.5) * (1.0 + amount * 0.5) * (3.2 if big else 1.0)
		var blobs: Array = [[Vector2.ZERO, radius]]

		# A splash is a blot and the droplets thrown off it, one way more
		# than the others.
		var toward := Vector2.from_angle(randf() * TAU)

		for b in range(randi_range(2, 6) if big else randi_range(0, 2)):
			var out := (toward * randf_range(0.4, 1.0) + Vector2.from_angle(randf() * TAU) * 0.6).normalized()
			blobs.append([out * radius * randf_range(0.8, 2.2), radius * randf_range(0.18, 0.55)])

		_splatter.drops.append([at, radius, 1.0, randf_range(0.28, 0.45), 0.0, randf_range(0.75, 1.15), blobs])

	_splatter.drops = _splatter.drops.slice(maxi(_splatter.drops.size() - 60, 0))
	_splatter.queue_redraw()


func splatter_count() -> int:
	return _splatter.drops.size() if _splatter != null else 0


func warn_mark_count() -> int:
	return _warn_marks.marks.size()


func hurt_mark_count() -> int:
	return _hurt_marks.marks.size()


func grade_amount() -> float:
	return _grade_amount


const GRADE_SHADER := """
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(c, vec3(grey) * vec3(1.15, 0.92, 0.85), 0.8);
	float edge = smoothstep(0.25, 0.75, length(SCREEN_UV - 0.5) * 1.4);
	graded = mix(graded, graded * vec3(0.6, 0.12, 0.08), edge * 0.6);
	COLOR = vec4(mix(c, graded, amount), 1.0);
}
"""


## Esc paused the game; any click resumes it.
func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused:
		return

	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed

	if click or event.is_action_pressed("ui_cancel"):
		resume()
		get_viewport().set_input_as_handled()


func resume() -> void:
	get_tree().paused = false

	if player != null and player.has_method("_recapture_mouse"):
		player._recapture_mouse()
