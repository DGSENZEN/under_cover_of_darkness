extends Node3D
## A section's aura (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "auras rise from the sections"): sparse
## tendrils of the section's colour rising from real books on its case's boards, swaying and eaten as they climb, never
## past the board above; always there, whoever is near (the shop is never still), and gone under the form light.

const MeshVfx := preload("res://scripts/Visual/MeshVfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

## How many tendrils a section has, how high one climbs at most (m), and the board room it needs.
const COUNT := 4
const CLIMB := 0.3
## (Rooted where they have the most room to climb, never less than this: short, they read as candle flames on the
## books' heads.)
const NEEDS := 0.12

var tendrils: Array[MeshInstance3D] = []
var _ceilings := {}
var _seed := 0.0
var _looks: Array[ShaderMaterial] = []
var _clock := 0.0


## The aura of `section` (its colour `colour`) rising from books of `lab`'s layout on `case`.
func build(lab: Node3D, section: StringName, case: Node3D, colour: Color, seed: float) -> void:
	_seed = seed
	name = "aura_%s" % section
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# The books on this case with room above them, spread across its boards and along them.
	var choices := []
	for entry: Dictionary in lab.book_layout:
		var spot: Dictionary = lab.book_spots[entry["spot"]]
		if spot["case"] != case:
			continue
		var box: AABB = entry["box"]
		var ceiling: float = spot["top"] + spot["head"] - 0.012
		if ceiling - box.end.y < NEEDS:
			continue
		choices.append([entry, spot, box, ceiling])
	# The most room above first; at most two to a board, apart along it.
	choices.sort_custom(func(a, b): return a[3] - a[2].end.y > b[3] - b[2].end.y)
	var used_boards := {}
	var picked := []
	for c: Array in choices:
		if picked.size() >= COUNT:
			break
		var board: int = c[0]["spot"]
		if used_boards.get(board, 0) >= 2 or picked.any(func(p): return p[0]["spot"] == board and absf(p[2].get_center().x - c[2].get_center().x) < 0.3):
			continue
		used_boards[board] = used_boards.get(board, 0) + 1
		picked.append(c)

	for k in picked.size():
		var c: Array = picked[k]
		var box: AABB = c[2]
		var frame: Transform3D = c[1]["xform"]
		var foot: Vector3 = frame * Vector3(box.get_center().x, box.end.y, box.get_center().z)
		var top: float = (frame * Vector3(0.0, c[3], 0.0)).y
		var climb := minf(CLIMB, top - foot.y)
		# (Thin and faint they were lost against the books: thicker, brighter, eaten mostly near their top.)
		var look := MeshVfx.look(colour.lerp(Color.WHITE, 0.25), colour, colour.darkened(0.7), 2.2, 0.12, 0.7, seed + k)
		look.set_shader_parameter("tail_eat", 0.4)
		look.set_shader_parameter("opacity", 0.95)
		_looks.append(look)
		var path := PackedVector3Array()
		for i in 10:
			var t := float(i) / 9.0
			path.append(Vector3(0.018 * sin(t * 4.0 + k), t * climb * 0.9, 0.012 * cos(t * 3.0 + k)))
		var tendril := MeshInstance3D.new()
		tendril.name = "tendril_%d" % k
		tendril.mesh = MeshVfx.tendril(path, 0.009, 7)
		tendril.set_surface_override_material(0, look)
		tendril.layers = Layers.FX
		tendril.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tendril)
		tendril.global_position = foot
		tendrils.append(tendril)
		_ceilings[tendril] = top


## The height (world) a tendril must stay under: the underside of the board above its book, less a margin.
func ceiling_of(tendril: MeshInstance3D) -> float:
	return _ceilings.get(tendril, INF)


func _process(delta: float) -> void:
	_clock += delta
	var time := _clock
	for k in _looks.size():
		_looks[k].set_shader_parameter("sway", Vector3(0.006 * sin(time * 0.9 + k * 1.7 + _seed), 0.0,
			0.006 * cos(time * 0.7 + k)))
