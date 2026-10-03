extends Node3D
## A page held up in both hands (the harbour's job spec, sections 4-5): the
## letter, or a notice, a paper or a ledger read where it is. Its words are
## drawn by a RichTextLabel into a SubViewport and laid on a sheet in the
## view's miniature (HandSlot's space, ViewArms.SCALE of full size), lit by
## the world but never below LIGHT_FLOOR, so it can be read in the dark.
## HandSlot places it; its edges are where the hands hold it.

const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")

## Its size at full size (m), by what it is.
const SIZES := {&"letter": Vector2(0.21, 0.28), &"paper": Vector2(0.21, 0.28), &"notice": Vector2(0.24, 0.32), &"ledger": Vector2(0.36, 0.25)}
## Its paper, by what it is.
const PAPERS := {&"letter": Color(0.74, 0.68, 0.54), &"paper": Color(0.7, 0.64, 0.5), &"notice": Color(0.68, 0.62, 0.48),
	&"ledger": Color(0.72, 0.66, 0.51)}
const INK := Color(0.1, 0.07, 0.05)
## Pixels per metre of page (the words' sharpness).
const DENSITY := 2400.0
## How much of the light falling on it the page gives back.
const LIGHT_TAKEN := 0.5
## A line of words is this much of a letter's width (its size).
const LINE := 14.0
## Its words glow this much of themselves: readable however dark it is.
const LIGHT_FLOOR := 0.07
## Where along its height the hands hold it (from the middle, of its height).
const HOLD_LOW := -0.3

var side := 0
var look: StringName = &"letter"
var _sides := PackedStringArray()
var _viewport: SubViewport
var _paper: ColorRect
var _words: RichTextLabel
var _sheet: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_paper = ColorRect.new()
	_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_paper)
	_words = RichTextLabel.new()
	_words.bbcode_enabled = true
	_words.scroll_active = false
	_words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 44)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Palatino", "Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman", "serif"])
	# (Heavier than the HUD's: the page is small in the view, and thin
	# strokes shrink to nothing.)
	serif.font_weight = 600
	var italic := SystemFont.new()
	italic.font_names = serif.font_names
	italic.font_italic = true
	italic.font_weight = 600
	_words.add_theme_font_override(&"normal_font", _heavier(serif))
	_words.add_theme_font_override(&"italics_font", _heavier(italic))
	_words.add_theme_color_override(&"default_color", INK)
	_paper.add_child(_words)

	_sheet = MeshInstance3D.new()
	# (HandSlot.VIEWMODEL_LAYER; HandSlot squeezes its material in front.)
	_sheet.layers = 1 << 18
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.mesh = QuadMesh.new()
	_material = StandardMaterial3D.new()
	_material.albedo_texture = _viewport.get_texture()
	# (Close to the eye a lamp would wash it white: it takes the light
	# softly, its words dark however near the flame.)
	_material.albedo_color = Color(LIGHT_TAKEN, LIGHT_TAKEN, LIGHT_TAKEN)
	_material.emission_enabled = true
	_material.emission = Color.WHITE
	_material.emission_texture = _viewport.get_texture()
	_material.emission_energy_multiplier = LIGHT_FLOOR
	_material.roughness = 1.0
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_sheet.material_override = _material
	add_child(_sheet)
	_lay_out()


## Shows `sides` (BBCode, one per side) as a `look` (SIZES); the side shown
## kept if it still is one.
func show_sides(sides: PackedStringArray, new_look: StringName) -> void:
	_sides = sides
	look = new_look if SIZES.has(new_look) else &"paper"
	side = clampi(side, 0, maxi(_sides.size() - 1, 0))

	if is_node_ready():
		_lay_out()


## The next side (round to the first after the last).
func turn() -> void:
	if _sides.size() > 1:
		side = (side + 1) % _sides.size()
		_redraw()


func side_count() -> int:
	return _sides.size()


func text_of(i: int) -> String:
	return _sides[i] if i >= 0 and i < _sides.size() else ""


func paper_material() -> StandardMaterial3D:
	return _material


## Where a hand holds the page, in the world, as a hold (HandContacts.Grip:
## the palm's frame, full size): on its side edge, a little below the
## middle; palms in on its sides, fingers up along them.
func edge(hand: int) -> Transform3D:
	var size: Vector2 = SIZES[look] * ViewArmsScript.SCALE
	var sign := -1.0 if hand == 0 else 1.0
	var mine := transform * Vector3(sign * size.x * 0.5, size.y * HOLD_LOW, 0.0)
	var holder := get_parent() as Node3D
	var basis := transform.basis * Basis(Vector3.FORWARD, sign * PI * 0.5)

	if holder == null:
		return Transform3D(basis, mine / ViewArmsScript.SCALE)

	# The view's miniature grown back to full size, then into the world.
	return holder.global_transform * Transform3D(basis, mine / ViewArmsScript.SCALE)


func _lay_out() -> void:
	var size: Vector2 = SIZES[look]
	(_sheet.mesh as QuadMesh).size = size * ViewArmsScript.SCALE
	_viewport.size = Vector2i(roundi(size.x * DENSITY), roundi(size.y * DENSITY))
	_paper.color = PAPERS[look]
	# (Sized to the sheet's width at full size: the same hand on every page.)
	var words := roundi(0.21 * DENSITY / LINE)
	_words.add_theme_font_size_override(&"normal_font_size", words)
	_words.add_theme_font_size_override(&"italics_font_size", words)
	_redraw()


static func _heavier(font: Font) -> Font:
	var heavier := FontVariation.new()
	heavier.base_font = font
	heavier.variation_embolden = 0.4
	return heavier


func _redraw() -> void:
	_words.text = text_of(side)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

