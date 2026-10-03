extends Node3D
## Flame sprites: solid main layer, offset/mirrored additive shimmer, and a bright core.
## Heat-sheet colour ramps and instance uniforms allow shared materials; sprites use Layers.FX.
## Torch calls shape() each frame; the local flipbook clock uses scaled game time.

const Layers := preload("res://scripts/Visual/Layers.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const FLAME := preload("res://scripts/Visual/Lights/flame.gdshader")
const FLAME_CORE := preload("res://scripts/Visual/Lights/flame_core.gdshader")

## sheet -> [frame width, frame height, frames, frames a second]
const SHEETS := {
	&"candle": [8, 16, 5, 9.0],
	&"small": [16, 24, 6, 10.0],
	&"torch": [32, 64, 8, 12.0],
	&"brazier": [64, 64, 10, 10.0],
	&"fire": [64, 96, 12, 8.0],
}
## How far the top of the flame goes with a full wind (m, at a 0.34 m flame).
const LEAN_REACH := 0.07
## Burning this low, it slows, and turns to its low ramp.
const LOW_AT := 0.35

@export var sheet := &"torch"
@export var ramp := &"torch"
@export var low_ramp := &"dying"
## The flame's height (m).
@export var size := 0.34
## Frames a second; 0 is the sheet's own.
@export var frame_rate := 0.0
## Flipbook sprites (1 for a candle among many).
@export var layers := 2
## The solid hot heart.
@export var core := true

## [0] is the main sprite (Torch.flame).
var sprites: Array[MeshInstance3D] = []
var frame := 0

static var _materials := {}
static var _warned := false

var _time := 0.0
## What each sprite's shader was last told (sent again only when it changes).
var _sent_frame := -1
var _sent_strength := -1.0
var _sent_lean := Vector3.INF
var _sent_low := -1.0
var _strength := 1.0
var _scale := 1.0
var _shown := 1.0
var _flat := 1.0
var _lean := Vector3.ZERO
var _low := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var info: Array = SHEETS.get(sheet, SHEETS[&"torch"])
	var quad := QuadMesh.new()
	quad.size = Vector2(size * float(info[0]) / float(info[1]), size)
	quad.center_offset = Vector3(0.0, size * 0.5, 0.0)

	for i in maxi(layers, 1):
		# The first solid (its shape holds over any wall), the rest added on.
		sprites.append(_sprite(quad, material(sheet, ramp, low_ramp, &"solid" if i == 0 else &"add"), "Flame%d" % i))

	if core:
		sprites.append(_sprite(quad, material(sheet, ramp, low_ramp, &"core"), "Heart"))

	# The second layer is the first mirrored, always.
	for i in sprites.size():
		sprites[i].set_instance_shader_parameter(&"mirror", 1.0 if i == 1 else 0.0)

	_apply()


func _process(delta: float) -> void:
	_time += delta
	var info: Array = SHEETS.get(sheet, SHEETS[&"torch"])
	var rate: float = frame_rate if frame_rate > 0.0 else float(info[3])

	if _strength < LOW_AT:
		rate *= 0.67

	var next := int(floor(_time * rate)) % int(info[2])

	if next != frame:
		frame = next
		_apply()


## Starts its loop `t` seconds in (the burner spreads its flames' phases).
func start_at(t: float) -> void:
	_time = t


## How it burns this frame: `wobble` its flicker (-1..1), `strength` 1 as
## made (less burning down), `lean` the wind, `flare` a stoked flare (0..1),
## `jump` a fire's surge or settling log (0..1, flames only).
func shape(wobble: float, strength: float, lean: Vector3, flare: float, jump: float) -> void:
	_strength = strength
	_scale = lerpf(0.35, 1.0, clampf(strength, 0.0, 1.5)) * (1.0 + 0.08 * wobble) * (1.0 + 0.45 * flare * flare) * (1.0 + 0.3 * jump)
	_lean = Vector3(lean.x, 0.0, lean.z)
	_flat = 1.0 - 0.1 * clampf(_lean.length(), 0.0, 1.0)
	_low = smoothstep(LOW_AT, 0.2, strength)
	_apply()


## How much of it shows (0..1): lighting grows it from nothing, snuffing
## pinches it out.
func set_shown(level: float) -> void:
	_shown = clampf(level, 0.0, 1.0)
	_apply()


func _apply() -> void:
	if sprites.is_empty():
		return

	var info: Array = SHEETS.get(sheet, SHEETS[&"torch"])
	var frames := int(info[2])
	var offset := _lean * LEAN_REACH * (size / 0.34)
	var s := _scale * _shown
	# The shaders are told only what changed (every call is a trip to the
	# renderer, for every sprite of every flame, every frame).
	var new_frame := frame != _sent_frame
	var new_strength := _strength != _sent_strength
	var new_lean := _lean != _sent_lean
	var new_low := _low != _sent_low

	for i in sprites.size():
		var sprite := sprites[i]
		var is_core := core and i == sprites.size() - 1
		sprite.visible = s > 0.01
		sprite.position = offset
		sprite.scale = Vector3(s, s * _flat, s) * (0.8 if is_core else 1.0)

		if new_frame:
			sprite.set_instance_shader_parameter(&"frame", frame + (frames / 2 if i == 1 else 0))

		if new_strength:
			sprite.set_instance_shader_parameter(&"strength", _strength)

		if new_lean:
			sprite.set_instance_shader_parameter(&"lean", _lean)

		if new_low:
			sprite.set_instance_shader_parameter(&"low", _low)

	_sent_frame = frame
	_sent_strength = _strength
	_sent_lean = _lean
	_sent_low = _low


func _sprite(quad: QuadMesh, look: ShaderMaterial, sprite_name: String) -> MeshInstance3D:
	var sprite := MeshInstance3D.new()
	sprite.name = sprite_name
	sprite.mesh = quad
	sprite.material_override = look
	sprite.layers = Layers.FX
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite


## The shared material for a sheet, its ramps, and its pass: "solid" (the
## main layer), "add" (the shimmer) or "core" (the hot heart).
static func material(sheet_name: StringName, ramp_name: StringName, low_name: StringName, pass_name: StringName) -> ShaderMaterial:
	var key := "%s/%s/%s/%s" % [sheet_name, ramp_name, low_name, pass_name]

	if _materials.has(key):
		return _materials[key]

	var look := ShaderMaterial.new()
	look.shader = FLAME if pass_name == &"add" else FLAME_CORE

	if pass_name == &"core":
		look.set_shader_parameter(&"core_cut", 0.8)
		look.set_shader_parameter(&"brightness", 2.5)
	elif pass_name == &"solid":
		look.set_shader_parameter(&"core_cut", 0.0)
		look.set_shader_parameter(&"brightness", 1.3)
	var info: Array = SHEETS.get(sheet_name, SHEETS[&"torch"])
	var path := "res://assets/vfx/flame_%s.png" % sheet_name

	if ResourceLoader.exists(path):
		look.set_shader_parameter(&"heat", load(path))
		look.set_shader_parameter(&"frames", int(info[2]))
	else:
		# Today's four-frame pixel flame, its red standing in for heat.
		if not _warned:
			_warned = true
			push_warning("FlameFx: no sheet %s; drawing the old flame" % path)

		look.set_shader_parameter(&"heat", Fx.texture(&"flame"))
		look.set_shader_parameter(&"frames", 4)

	look.set_shader_parameter(&"ramp", load("res://assets/vfx/ramps/%s.png" % ramp_name))
	look.set_shader_parameter(&"ramp_low", load("res://assets/vfx/ramps/%s.png" % low_name))
	_materials[key] = look
	return look
