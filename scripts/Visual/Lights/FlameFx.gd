extends Node3D
## A flame at one point: two flipbook sprites (one mirrored, half a loop
## behind the other, both added onto the scene) and a small solid hot heart
## that blooms. Drawn from a heat sheet through a colour ramp
## (flame.gdshaderinc), on the effects layer, so the lightgem never sees it.
##
## The flipbook runs on its own clock in _process, which Engine.time_scale
## already slows, so slow motion slows the fire too. Its burner (Torch.gd)
## calls `shape` every frame with how it wavers, how strongly it burns, the
## wind, a flare and a fire's jump. Put the node where the fuel is: the flame
## stands up from it.

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
		sprites.append(_sprite(quad, material(sheet, ramp, low_ramp, false), "Flame%d" % i))

	if core:
		sprites.append(_sprite(quad, material(sheet, ramp, low_ramp, true), "Heart"))

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

	for i in sprites.size():
		var sprite := sprites[i]
		var is_core := core and i == sprites.size() - 1
		sprite.visible = s > 0.01
		sprite.position = offset
		sprite.scale = Vector3(s, s * _flat, s) * (0.8 if is_core else 1.0)
		sprite.set_instance_shader_parameter(&"frame", frame + (frames / 2 if i == 1 else 0))
		sprite.set_instance_shader_parameter(&"strength", _strength)
		sprite.set_instance_shader_parameter(&"lean", _lean)
		sprite.set_instance_shader_parameter(&"mirror", 1.0 if i == 1 else 0.0)
		sprite.set_instance_shader_parameter(&"low", _low)


func _sprite(quad: QuadMesh, look: ShaderMaterial, sprite_name: String) -> MeshInstance3D:
	var sprite := MeshInstance3D.new()
	sprite.name = sprite_name
	sprite.mesh = quad
	sprite.material_override = look
	sprite.layers = Layers.FX
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite


## The shared material for a sheet, its ramps, and whether it is the heart.
static func material(sheet_name: StringName, ramp_name: StringName, low_name: StringName, core_pass: bool) -> ShaderMaterial:
	var key := "%s/%s/%s/%s" % [sheet_name, ramp_name, low_name, core_pass]

	if _materials.has(key):
		return _materials[key]

	var look := ShaderMaterial.new()
	look.shader = FLAME_CORE if core_pass else FLAME
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
