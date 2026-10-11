extends Node3D
## An effect whose light flickers with its flames (Vfx.gd: braziers, coals,
## candles): one value a frame, `flicker`, sets the light's energy and every
## flame material's `flicker`, so the fire and its light pulse together.

## The light's energy at a flicker of 1.
var energy := 1.0
var seed := 0.0
var flicker := 1.0
var light: OmniLight3D
var flames: Array[ShaderMaterial] = []

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	flicker = Vfx.flicker(_time, seed)

	if light:
		light.light_energy = energy * flicker

	for m in flames:
		m.set_shader_parameter(&"flicker", flicker)
