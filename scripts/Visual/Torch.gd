extends Node3D
## A torch: a warm light that breathes and gutters, and a flame drawn as a
## four-frame pixel flipbook that always faces you. Its shadows are on, so in
## a foggy room it throws shafts past pillars and through doorways.
##
## A real light: guards see you by it (and see you flicker with it), and the
## lightgem reads it. Put the node where the flame is.
##
##   var torch := Torch.new(); torch.position = Vector3(0, 2.2, 0); add_child(torch)

const Fx := preload("res://scripts/Visual/Fx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

@export var color := Color(1.0, 0.64, 0.32)
@export var energy := 2.4
@export var light_range := 9.0
## How much the light wavers, as a fraction of its energy.
@export_range(0.0, 0.6, 0.01) var flicker := 0.16
@export var shadows := true
## Flame frames per second.
@export var frame_rate := 9.0
@export var flame_size := 0.34

var light: OmniLight3D
var flame: MeshInstance3D

var _flame_material: StandardMaterial3D
var _time := 0.0
var _phase := 0.0


func _ready() -> void:
	# The light wavers and the flame changes every drawn frame: drawn as set.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_phase = randf() * 100.0
	_time = _phase

	light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.15
	light.shadow_enabled = shadows
	light.shadow_blur = 1.5
	light.light_volumetric_fog_energy = 1.4
	# Just above the flame, so the flame does not shadow its own light.
	light.position = Vector3(0.0, 0.12, 0.0)
	add_child(light)

	flame = MeshInstance3D.new()
	flame.name = "Flame"
	var quad := QuadMesh.new()
	quad.size = Vector2(flame_size * 0.75, flame_size)
	flame.mesh = quad
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.layers = Layers.FX

	_flame_material = StandardMaterial3D.new()
	_flame_material.albedo_texture = Fx.texture(&"flame")
	_flame_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_flame_material.alpha_scissor_threshold = 0.5
	_flame_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_flame_material.albedo_color = Color(1.6, 1.3, 1.0)
	_flame_material.disable_fog = true
	_flame_material.uv1_scale = Vector3(0.25, 1.0, 1.0)
	flame.material_override = _flame_material
	add_child(flame)


func _process(delta: float) -> void:
	_time += delta

	# A slow breath, a quicker waver and a nervous flutter.
	var n := (
		sin(_time * 1.7) * 0.45
		+ sin(_time * 5.3 + 1.1) * 0.35
		+ sin(_time * 13.1 + 2.3) * 0.2
	)
	light.light_energy = energy * (1.0 + flicker * n)
	light.position = Vector3(sin(_time * 3.1) * 0.02, 0.12 + sin(_time * 4.7) * 0.015, cos(_time * 2.9) * 0.02)

	var frame := int(floor(_time * frame_rate)) % 4
	_flame_material.uv1_offset = Vector3(0.25 * frame, 0.0, 0.0)
	flame.scale = Vector3.ONE * (1.0 + 0.08 * n)
