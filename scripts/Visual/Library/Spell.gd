extends Node3D
## A spellbook's working (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "a spellbook throws sigils,
## wards and auras"; spellbooks take their section's colour): over an opened spellbook on its lectern, three ward
## rings interlocked like an armillary's, each marked with the hours of a working, turning against each other, and
## round the book a thin shell of aura in the section's colour, broken and climbing, its rim bright. Upright in the
## room whatever the lectern's slope, scaled to the room above the pages.

const MeshVfx := preload("res://scripts/Visual/MeshVfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const Chronology := preload("res://scripts/Visual/Library/Chronology.gd")

## The wards' middle (over the gutter, 0.13 m left of the right-hand page's middle), their radius; the shell's middle
## and radius (round the whole open book).
const GUTTER := Vector3(-0.13, 0.0, 0.0)
const HEART := GUTTER + Vector3(0.0, 0.15, 0.0)
const RADIUS := 0.08
const SHELL := 0.28
## The room it is built for above the pages.
const ROOM := 0.3
## Each ward ring's tilt (its axis) and turn (rad/s).
const TURNS := [[Vector3(1.0, 0.0, 0.0), 0.5], [Vector3(0.5, 0.0, 0.87), -0.42], [Vector3(-0.5, 0.0, 0.87), 0.36]]

var kind := &"spell"
var colour := Color.WHITE
var wards: Array[MeshInstance3D] = []
var shell: MeshInstance3D

var _seed := 0.0
var _looks: Array[ShaderMaterial] = []
var _shell_look: ShaderMaterial


func build(seed: float, tint: Color) -> void:
	_seed = seed
	colour = tint
	name = "spell"
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false

	for k in TURNS.size():
		var look := MeshVfx.look(colour.lerp(Color.WHITE, 0.5), colour, colour.darkened(0.75), 2.0, 0.05, 0.6, seed + k)
		look.set_shader_parameter("tail_eat", 0.25)
		look.set_meta("erosion", 0.05)
		_looks.append(look)
		var ring := MeshInstance3D.new()
		ring.name = "ward_%d" % k
		var mesh := Chronology._torus(RADIUS - k * 0.006, 0.0032)
		var ticks := Chronology._ticks(RADIUS - k * 0.006 - 0.0032, 8 + k * 4, -0.008, 0.004)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(mesh, 0, Transform3D.IDENTITY)
		st.append_from(ticks, 0, Transform3D.IDENTITY)
		ring.mesh = st.commit()
		ring.set_surface_override_material(0, look)
		ring.layers = Layers.FX
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.position = HEART
		wards.append(ring)

	# The shell: a dome over the book, broken by climbing noise, faint but for its rim.
	_shell_look = MeshVfx.look(colour.lerp(Color.WHITE, 0.4), colour, colour.darkened(0.8), 1.3, 0.45, 0.35, seed + 7.0)
	_shell_look.set_shader_parameter("tail_eat", 0.5)
	_shell_look.set_shader_parameter("rim", 3.0)
	# (Mostly eaten: whole, it read as crumpled glass, not an aura.)
	_shell_look.set_meta("erosion", 0.64)
	_looks.append(_shell_look)
	var dome := SphereMesh.new()
	dome.radius = SHELL
	dome.height = SHELL * 1.3
	dome.is_hemisphere = true
	dome.radial_segments = 28
	dome.rings = 10
	shell = MeshInstance3D.new()
	shell.name = "shell"
	shell.mesh = dome
	shell.set_surface_override_material(0, _shell_look)
	shell.layers = Layers.FX
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	shell.position = GUTTER


## Where it stands (the pages' top middle, the book's heading), how present (0 gone to 1), the room above it.
func set_state(presence: float, clearance: float, time: float, at: Vector3, heading: float) -> void:
	visible = presence > 0.001
	if not visible:
		return
	var fit := clampf(clearance / ROOM, 0.4, 1.0)
	global_transform = Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * fit), at)
	for look in _looks:
		look.set_shader_parameter("opacity", presence * (0.22 if look == _shell_look else 1.0))
		look.set_shader_parameter("erosion", lerpf(0.97, float(look.get_meta("erosion")), presence))
	for k in wards.size():
		var turn: Array = TURNS[k]
		wards[k].quaternion = Quaternion((turn[0] as Vector3).normalized(), PI / 2.0) \
			* Quaternion(Vector3.UP, time * float(turn[1]) + _seed + k)
		wards[k].position = HEART + Vector3(0.0, 0.006 * sin(time * 0.9 + k), 0.0)
	shell.scale = Vector3.ONE * lerpf(0.5, 1.0, presence) * (1.0 + 0.02 * sin(time * 1.4))
	shell.rotation = Vector3(0.0, time * 0.2, 0.0)


## Every piece it draws.
func parts() -> Array:
	return find_children("*", "GeometryInstance3D", true, false)
