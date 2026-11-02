extends MeshInstance3D
## The floor cracking under the Burst: creeping out from your feet as the circle closes, gone if you
## let go; thrown out with the wave on release, and lying as a scar a few seconds after.

const CRACKS_SHADER := preload("res://scripts/Magic/burst_cracks.gdshader")

## How far they creep in the wind-up (m); how big the quad (m); how long a let go takes to fade.
const WIND_UP_REACH := 1.4
const SIZE := 6.2
const LET_GO_TAKES := 0.25
## Off the floor, to lie on it and not in it.
const LIFT := 0.015
## The scar: how long it lies, and how long it takes to go; how hot it starts, and how soon it cools.
const SCAR_LIES := 2.4
const SCAR_GOES := 1.6
const HOT := 1.0
const COOLS := 1.2

var _look: ShaderMaterial
var _reach := 0.0
var _grow_to := 0.0
var _grow_takes := 0.0
var _heat := 0.3
var _fade := 0.0
var _letting_go := false
var _scar_t := -1.0


static func on_floor(context: Node, at: Vector3) -> Node3D:
	var cracks: MeshInstance3D = (load("res://scripts/Magic/BurstCracks.gd") as GDScript).new()
	context.add_child(cracks)
	cracks.global_position = at + Vector3.UP * LIFT
	return cracks


func _ready() -> void:
	add_to_group(&"burst_cracks")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * SIZE * 2.0
	mesh = quad
	_look = ShaderMaterial.new()
	_look.shader = CRACKS_SHADER
	_look.set_shader_parameter(&"noise", MeshVfx.noise())
	_look.set_shader_parameter(&"size", SIZE)
	material_override = _look


## How far out they have run (m).
func reach_now() -> float:
	return _reach


## In the wind-up: `share` of the way through it; where your feet are.
func grow_to(share: float, at: Vector3) -> void:
	_reach = WIND_UP_REACH * share
	global_position = at + Vector3.UP * LIFT
	_look.set_shader_parameter(&"reach_now", _reach)
	_look.set_shader_parameter(&"heat", 0.2 + share * 0.5)


## Let go early.
func let_go() -> void:
	_letting_go = true


## Released: out with the wave to `reach`, over `takes`, and then a scar.
func scar(reach: float, takes: float) -> void:
	_grow_to = reach
	_grow_takes = takes
	_scar_t = 0.0
	_heat = HOT


func _physics_process(delta: float) -> void:
	if _letting_go:
		_fade += delta / LET_GO_TAKES
		_look.set_shader_parameter(&"fade", _fade)

		if _fade >= 1.0:
			queue_free()

		return

	if _scar_t < 0.0:
		return

	_scar_t += delta
	_reach = move_toward(_reach, _grow_to, _grow_to / maxf(_grow_takes, 0.01) * delta)
	_heat = HOT * (1.0 - clampf(_scar_t / COOLS, 0.0, 1.0)) + 0.04
	_fade = clampf((_scar_t - SCAR_LIES) / SCAR_GOES, 0.0, 1.0)
	_look.set_shader_parameter(&"reach_now", _reach)
	_look.set_shader_parameter(&"heat", _heat)
	_look.set_shader_parameter(&"fade", _fade)

	if _fade >= 1.0:
		queue_free()
