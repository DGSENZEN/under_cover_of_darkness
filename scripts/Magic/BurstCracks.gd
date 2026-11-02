extends MeshInstance3D
## The floor cracking under the Burst: creeping out from your feet as the circle closes, gone if you
## let go; thrown out with the wave on release, and lying as a scar a few seconds after. The scar lies
## on the floor it has: a grid laid on it by rays, its cells gone past an edge or behind a wall.

const CRACKS_SHADER := preload("res://scripts/Magic/burst_cracks.gdshader")

## How far they creep in the wind-up (m); how big the quad (m); how long a let go takes to fade.
const WIND_UP_REACH := 1.4
const SIZE := 6.2
const LET_GO_TAKES := 0.25
## The scar's grid: how fine (m), how far it looks up and down for a floor (m).
const CELL := 0.4
const LOOKS_UP := 0.5
const LOOKS_DOWN := 1.6
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
var _lies: Dictionary = {}


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
	_lay_on_the_floor()


## Whether the scar lies on this spot of the floor (only x and z are looked at).
func lies_at(spot: Vector3) -> bool:
	var i := int(round((spot.x - global_position.x) / CELL))
	var j := int(round((spot.z - global_position.z) / CELL))
	return _lies.has(Vector2i(i, j))


## Lays the quad out over what is really there. A corner with no floor, or a wall between it and the
## middle, is see-through (the shader cuts by its colour's alpha).
func _lay_on_the_floor() -> void:
	var space := get_world_3d().direct_space_state
	var centre := global_position
	var from := centre + Vector3.UP * LOOKS_UP
	var cells := int(ceil(SIZE / CELL))
	var heights := {}

	for j in range(-cells, cells + 1):
		for i in range(-cells, cells + 1):
			var flat := Vector3(float(i) * CELL, 0.0, float(j) * CELL)

			if flat.length() > SIZE:
				continue

			var over := centre + flat + Vector3.UP * LOOKS_UP

			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, over, 1)).is_empty():
				continue

			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * LOOKS_DOWN, 1))

			if not down.is_empty():
				heights[Vector2i(i, j)] = float(down["position"].y) + LIFT - centre.y

	_lies = heights
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for j in range(-cells, cells):
		for i in range(-cells, cells):
			var corners := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]

			if not corners.any(func(c): return heights.has(c)):
				continue

			for k in [0, 1, 2, 0, 2, 3]:
				_corner(st, corners[k], heights)

	mesh = st.commit()


func _corner(st: SurfaceTool, cell: Vector2i, heights: Dictionary) -> void:
	var there := heights.has(cell)
	var at := Vector3(float(cell.x) * CELL, heights.get(cell, 0.0), float(cell.y) * CELL)
	st.set_color(Color(1.0, 1.0, 1.0, 1.0 if there else 0.0))
	st.set_uv(Vector2(at.x, at.z) / (SIZE * 2.0) + Vector2(0.5, 0.5))
	st.add_vertex(at)


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
