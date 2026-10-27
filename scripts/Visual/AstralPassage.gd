extends Node3D
## An astral passage (docs/superpowers/specs/2026-10-26-astral-passages-design.md): a dark stretch beyond the market's
## wards, where nothing built holds back the Metro's thin dark (the same the north circle's rite opened), walked as
## through the astral plane toward the market. The stretch's box is gone: its greybox unseen (still solid), windows
## where its walls, ceiling and floor were (astral_window.gdshader), and behind them, seen only through them, the void
## with real depth, in the city's own colours (phosphor green the seeped, oxblood the gods, cyan-white the wards,
## marigold the dead): its painted sky (astral_sky.gdshader), the city's eclipse seen from the other side, rivers of
## the dead flowing toward the market, the script's glyphs as constellations lit one by one as the walker goes; the
## city's fragments and the presences drifting in it (the feathered serpent, eyes in cracks in the dark, the shades,
## the hand). Veils of pale light across the way part round the walker (astral_veil.gdshader); motes drift toward the
## market; each gap a ward-gate's vortex. Our own effects: no lights.
## Set up by `make` (maps/metro.gd), in the map's frame.

const Layers := preload("res://scripts/Visual/Layers.gd")
const WINDOW := preload("res://scripts/Visual/astral_window.gdshader")
## The void marked round the gates and past the gaps (what lies in its plane over it leans toward the eye).
const MARK := preload("res://scripts/Visual/astral_mark.gdshader")
const SKY := preload("res://scripts/Visual/astral_sky.gdshader")
const VEIL := preload("res://scripts/Visual/astral_veil.gdshader")
const STONE := preload("res://scripts/Visual/astral_stone.gdshader")
const KIT := "res://assets/eclipse/kit/astral.glb"
const STONES := ["way_stone_a", "way_stone_b", "way_stone_c"]
## How far apart the way's stones lie along it (m); how far from its line the walker may go (m: the way 1.5 m wide
## with the walker's own half metre either side); the landings across its ends' gaps.
const STONE_EVERY := 1.1
const HALF_WAY := 0.75
const INK := preload("res://scripts/Visual/astral_ink.gdshader")
## The city's fragments drifting in the void: the kit's pieces, how many float, how far out past the walls, the
## ceiling and the floor (m), how big, how fast each turns (degrees a second) and bobs (m, Hz).
const FRAGMENT_KINDS := ["arch", "stairs", "doorway", "lamp_post", "bell", "tile_slab", "stall_frame"]
const FRAGMENTS := 22
const FRAGMENT_OUT := Vector2(4.0, 30.0)
const FRAGMENT_SIZE := Vector2(1.0, 2.2)
const FRAGMENT_TURN := Vector2(0.5, 3.0)
const FRAGMENT_BOB := Vector2(0.25, 0.08)
const CUTOUT := preload("res://scripts/Visual/astral_cutout.gdshader")
const EYE := preload("res://scripts/Visual/astral_eye.gdshader")
const Silhouette := preload("res://scripts/Visual/Silhouette.gd")
## The presences: the serpent (its length, its circle's radius round the passage, its pace round it in radians a
## second); the eyes' clusters [where (out from the passage's middle), how many]; the shades walking a way of their own
## (how far out past the east wall, who, their pace); the giant hand (its size, where it drifts).
const SERPENT_LENGTH := 30.0
const SERPENT_ROUND := 26.0
const SERPENT_PACE := 0.018
const EYES := [[Vector3(-22.0, 3.0, -4.0), 3], [Vector3(18.0, 7.0, 6.0), 1], [Vector3(-4.0, -16.0, 2.0), 4]]
const SHADES_OUT := 11.0
const SHADE_WALKS := ["city_priest", "city_grandmother", "city_pelona", "walk_coat", "city_nun", "city_old_man"]
const SHADE_PACE := 0.55
const HAND_SIZE := 6.0
const HAND_AT := Vector3(-18.0, 9.0, 0.0)
const SERPENT := preload("res://scripts/Visual/astral_serpent.gdshader")
## The serpent's swim (its reach at its tail, m); its feathers along its back (how far apart, m; how long, a share of
## its body's girth there), the ruff round its neck (how many, how long, m), its tail's plume (how many, how long, m).
const SERPENT_SWIM := 1.2
const FEATHER_EVERY := 0.85
const FEATHER_LENGTH := 2.2
const RUFF := 14
const RUFF_LENGTH := 2.0
const PLUME := 7
const PLUME_LENGTH := 3.4
## Its tongue flicking out: how often (s), how long it is out (s).
const TONGUE_EVERY := 4.5
const TONGUE_TIME := 0.7
## Each eye's socket, the crack in the dark it looks through (its quad's size against the eye's).
const SOCKET := Vector2(1.35, 1.6)
const MEMBRANE := preload("res://scripts/Visual/astral_membrane.gdshader")
const RING := preload("res://scripts/Visual/astral_ring.gdshader")
const SPIRAL := preload("res://scripts/Visual/astral_spiral.gdshader")
const PLANE := preload("res://scripts/Visual/astral_plane.gdshader")
## The ward-gates: their three rings' sheet (tools/textures/astral_glyphs.py), the rings' depths (m off the gate's
## face) and turns (radians a second, against each other); the vortex's circle (its share of the gap's shorter side);
## its embers and spiralling motes (how many, how long each lives, s).
const RINGS_SHEET := "astral_rings.png"
const RING_DEPTHS := [0.0, -0.15, 0.15]
const RING_TURN := [0.11, -0.19, 0.07]
const GATE_CIRCLE := 0.34
## The void round a gate's circle starts at its rim (a share of its circle's radius), its fire burning over it; the
## sheet's outer ring's rim (its share of the cell).
const GATE_HOLE := 1.0
## How far what lies in the plane of a gate's frame or a bleed (its vortex, rings, burning edge) leans toward the eye
## off it (m), so nothing fights the void's depth there.
const LEAN := 0.015
const RING_SHEET_RIM := 0.48
const TEAR_EDGE := preload("res://scripts/Visual/astral_tear.gdshader")
## Each gate's arch: how far out round its circle (a share of its rim), its stones' size (along, across, deep, m), how
## far apart (m), how far they float (m).
const ARCH := preload("res://scripts/Visual/astral_arch.gdshader")
const ARCH_OUT := 1.24
const ARCH_STONE := Vector3(0.36, 0.34, 0.5)
const ARCH_EVERY := 0.44
const ARCH_FLOAT := 0.035
## How thick the unseen jambs closing a gap beside its arch are (m).
const JAMB_DEPTH := 0.3
## The void bleeding out past its gaps: how far its tongues reach (m), how far off the world's surfaces (m, clear of
## them).
const BLEED := 1.6
const BLEED_OFF := 0.03
const EMBERS := 70
const EMBER_LIFE := 1.8
const SPIRAL_MOTES := 90
const SPIRAL_LIFE := 5.0
const ECLIPSE := preload("res://scripts/Visual/astral_eclipse.gdshader")
const RIVER := preload("res://scripts/Visual/astral_river.gdshader")
const STAR := preload("res://scripts/Visual/astral_star.gdshader")
## The eclipse: how far off (m), how high (degrees over the horizon), how far round from straight ahead toward the
## market (degrees, west), its size (m).
const ECLIPSE_FAR := 300.0
const ECLIPSE_HIGH := 25.0
const ECLIPSE_ROUND := 30.0
const ECLIPSE_SIZE := 236.0
## The rivers of the dead: [how far under or over the floor (m), how far out east (m), how wide (m), its tilt
## (radians about its flow), its sway (m)]; the first under the way itself, following it.
const RIVERS := [[-4.5, 0.0, 3.0, 0.0, 0.8], [12.0, -6.0, 4.0, 0.35, 5.0], [1.0, 16.0, 3.5, 0.8, 2.0]]
## How far they run on past the passage's ends (m), to the deep's horizon either way.
const RIVER_BEYOND := 140.0
## The colossi far out in the deep, for its size: the sun stone adrift (its radius, thickness, [how far, degrees round
## from ahead toward the market (west negative), degrees up]); the city hanging upside down overhead (its pieces' size,
## where); the stair spiralling down into the abyss (its steps, their drop, the spiral's radius, where).
const COLOSSUS := preload("res://scripts/Visual/astral_colossus.gdshader")
const SUN_STONE := Vector2(70.0, 10.0)
const SUN_STONE_AT := Vector3(420.0, -65.0, 14.0)
const CITY_SCALE := 14.0
const CITY_AT := Vector3(260.0, 55.0, 32.0)
const STAIR_STEPS := 110
const STAIR_DROP := 1.7
const STAIR_ROUND := 26.0
const STAIR_AT := Vector3(220.0, 125.0, -30.0)
## The constellations: the glyphs' strokes (tools/textures/astral_glyphs.py), their size (m), how far out (m), how
## fast the lit one brightens and the rest fade (a share a second; its threads drawn in as it does), how fast the
## flare of its lighting fades (a share a second).
const CONSTELLATIONS_FILE := "res://textures/painted/underground/astral_constellations.json"
const CONSTELLATION_SIZE := 22.0
const CONSTELLATION_OUT := 55.0
const LIT_EASE := 0.8
const FLARE_FADE := 1.2
## The glimpses from spot to spot: [its name, where along the passage it shows (a share from its far end)]; how near
## the walker must be to it (a share), how fast it forms and goes (a share a second). The echo of the way hung upside
## down overhead (how far up, m); the band of starry eyes across the deep (how many, how far, its arch's span in
## degrees); the great door standing in the deep ahead (its size, [how far, degrees round, degrees up]).
const GLIMPSES := [["echo", 0.15], ["star_skirt", 0.5], ["great_door", 0.85]]
const GLIMPSE_NEAR := 0.17
const GLIMPSE_EASE := 0.6
const ECHO_UP := 34.0
const SKIRT_EYES := 36
const SKIRT_FAR := 120.0
const SKIRT_SPAN := 150.0
const DOOR_SCALE := 26.0
const DOOR_AT := Vector3(170.0, 60.0, 9.0)
## The plane over the eye: its canvas layer (under the HUD), how fast it eases in inside and out outside (a share a
## second), how long the breath of a crossing takes to fall away (s). The muffle inside: the World and Ambience buses'
## low-pass, its cutoff inside and out (Hz), how fast it eases (a share a second, in log).
const PLANE_LAYER := -5
const PLANE_IN := 1.0
const PLANE_OUT := 0.7
const SHIFT_TIME := 1.1
const MUFFLE_BUSES := [&"World", &"Ambience"]
const MUFFLE := Vector2(900.0, 20000.0)
const MUFFLE_EASE := 2.5
## How far below the floor the floor's window lies (the way's stones over it hide it), and the walls' windows reach.
const BELOW := 0.6
## The sky's sphere round the passage's middle (m); the brush sheet breaking its clouds.
const SKY_RADIUS := 45.0
const BRUSH := "res://textures/brushes/brush_02.png"
## Where along the passage (its share from the market's mouth) the veils hang.
const VEILS_AT := [0.25, 0.5, 0.75]
## The motes drifting toward the market: how many, how long each lives (s), their pace (m/s).
const MOTES := 180
const MOTE_LIFE := 14.0
const MOTE_PACE := Vector2(0.12, 0.35)

## Its box (the map's frame: the corridor's floor to its ceiling), the market's mouth (the box's end nearest the
## Pasaje: -1 its low z end, 1 its high), and the corridor's gaps ([{a, b: Vector2 (x, z) ends, y0, y1}]).
var bounds: AABB
var mouth_end := 1
var gaps: Array = []
## Who walks through; the stretch's greybox (unseen, its collider kept); the way (polylines, the main first).
var walker: Node3D
var greybox: MeshInstance3D
var way: Array = []
## Its pieces.
var windows: Array[MeshInstance3D] = []
var sky: MeshInstance3D
var stones: Array[MeshInstance3D] = []
var fragments: Array[Node3D] = []
var presences: Array[Node3D] = []
var thresholds: Array[Node3D] = []
var eclipse: MeshInstance3D
var rivers: Array[MeshInstance3D] = []
var constellations: Array[Node3D] = []
var colossi: Array[Node3D] = []
## The void bled out past the market's mouth (windows and their burning edges).
var bleeds: Array[MeshInstance3D] = []
## The plane over the eye (astral_plane.gdshader).
var plane_shift: CanvasLayer
## What of its stretch's greybox lies past its box (a stretch running on beyond it, unbuilt), still drawn; null if none.
var rest: MeshInstance3D
## The glimpses from spot to spot (each its meta "at" and "shown", 0..1).
var glimpses: Array[Node3D] = []
## Which constellation is lit (the one beside the walker along the passage); -1 with the walker outside.
var lit_constellation := -1
var veils: Array[MeshInstance3D] = []
var motes: GPUParticles3D
## Its crossings (each time the walker passes a threshold) and whether the walker is inside.
var crossings := 0
var inside := false

var _mouth: Vector3
var _away: Vector3
var _stone_look: ShaderMaterial
var _span: float
var _clock := 0.0


## An astral passage over the corridor `box`, its market's mouth at its `end` (1: its high z end), its windows cut
## round `holes` ([{a, b, y0, y1}]), parting round `who`; `grey` the stretch's greybox mesh; `paths` its way.
static func make(box: AABB, end: int, holes: Array, who: Node3D, grey: MeshInstance3D = null, paths: Array = []) -> Node3D:
	var passage: Node3D = load("res://scripts/Visual/AstralPassage.gd").new()
	passage.bounds = box
	passage.mouth_end = end
	passage.gaps = holes
	passage.walker = who
	passage.greybox = grey
	passage.way = paths
	return passage


func _ready() -> void:
	var middle := bounds.get_center()
	_span = bounds.size.z
	_mouth = Vector3(middle.x, bounds.position.y, bounds.end.z if mouth_end > 0 else bounds.position.z)
	_away = Vector3(0.0, 0.0, -float(mouth_end))
	if greybox != null:
		greybox.visible = false
		rest = _rest_of(greybox)
	_windows()
	_sky()
	_eclipse()
	_colossi()
	_rivers()
	_constellations()
	_landings()
	_stones()
	_fragments()
	_presences()
	_thresholds()
	_veils()
	_motes()
	_glimpses()
	_plane()
	# (Held on the way after the walker has moved this frame.)
	process_physics_priority = 10


## What of `grey`'s mesh lies past its box along z (its triangles cut at the box's ends), drawn as `grey` was, in its
## place; null if nothing does.
func _rest_of(grey: MeshInstance3D) -> MeshInstance3D:
	if grey.mesh == null or grey.mesh.get_surface_count() == 0:
		return null
	var arrays := grey.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var to_box := grey.global_transform
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kept := 0
	for i in range(0, points.size() - 2, 3):
		var tri := [to_box * points[i], to_box * points[i + 1], to_box * points[i + 2]]
		# (Each side of the box's z-span: what lies before its near end, what lies past its far end.)
		for side in [[bounds.position.z, false], [bounds.end.z, true]]:
			var piece := _cut(tri, side[0], side[1])
			for j in range(1, piece.size() - 1):
				for v: Vector3 in [piece[0], piece[j], piece[j + 1]]:
					tool.set_normal(to_box.basis * normals[i])
					tool.add_vertex(to_box.affine_inverse() * v)
				kept += 1
	if kept == 0:
		return null
	var piece := MeshInstance3D.new()
	piece.name = "rest_of_" + String(grey.name)
	piece.mesh = tool.commit()
	piece.material_override = grey.material_override
	add_child(piece)
	piece.global_transform = grey.global_transform
	return piece


## The part of the polygon `poly` (world points) on one side of the plane z = `at` (past it if `past`, else before it).
func _cut(poly: Array, at: float, past: bool) -> Array:
	var out := []
	for i in poly.size():
		var p: Vector3 = poly[i]
		var q: Vector3 = poly[(i + 1) % poly.size()]
		# (A hair's tolerance: what lies on the plane itself is not past it, nor before it.)
		var p_in := p.z > at + 0.001 if past else p.z < at - 0.001
		var q_in := q.z > at + 0.001 if past else q.z < at - 0.001
		if p_in:
			out.append(p)
		if p_in != q_in and absf(q.z - p.z) > 0.0001:
			out.append(p.lerp(q, (at - p.z) / (q.z - p.z)))
	return out


## How strongly it shows `t` (share from the market's mouth) along.
func grown(t: float) -> float:
	return smoothstep(1.0, 0.55, t) * (0.45 + 0.55 * smoothstep(0.0, 0.18, t))


func _process(delta: float) -> void:
	_clock += delta
	for piece in fragments:
		piece.rotate(piece.get_meta("axis"), deg_to_rad(float(piece.get_meta("turn"))) * delta)
		var home: Vector3 = piece.get_meta("home")
		piece.position.y = home.y + FRAGMENT_BOB.x * sin(TAU * FRAGMENT_BOB.y * _clock + float(piece.get_meta("phase")))
	_drift(delta)
	for colossus in colossi:
		colossus.rotate_object_local(Vector3.UP, (colossus.get_meta("turn") as Vector3).y * delta)
	# The gates' rings turning against each other.
	for gate in thresholds:
		for k in RING_DEPTHS.size():
			var ring := gate.get_node_or_null("ring%d" % (k + 1)) as Node3D
			if ring != null:
				ring.rotation.z = wrapf(ring.rotation.z + float(RING_TURN[k]) * delta, -PI, PI)
		# Its arch's stones floating, each on its own slow breath.
		for stone: Node in gate.get_children():
			if stone.has_meta("home"):
				var home: Vector3 = stone.get_meta("home")
				var phase: float = stone.get_meta("phase")
				(stone as Node3D).position = home + Vector3(home.x, home.y, 0.0).normalized() * ARCH_FLOAT * sin(_clock * 0.7 + phase) \
					+ Vector3(0.0, 0.0, ARCH_FLOAT * sin(_clock * 0.5 + phase * 1.3))
	if walker == null or not is_instance_valid(walker):
		return
	var at := walker.global_position
	for veil in veils:
		(veil.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(&"walker", at)
	for gate in thresholds:
		for part: Node in gate.get_children():
			if part is MeshInstance3D and (part as MeshInstance3D).material_override is ShaderMaterial:
				((part as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter(&"walker", at)
	_light_constellations(at, delta)
	_show_glimpses(at, delta)
	# Crossing a threshold: in or out, the warp; inside, the world's sound eased dull.
	var now := at.x > bounds.position.x and at.x < bounds.end.x and at.z > bounds.position.z and at.z < bounds.end.z \
		and at.y > bounds.position.y - 1.0 and at.y < bounds.end.y
	if now != inside:
		inside = now
		crossings += 1
		_warp()
	_muffle(delta)
	_ease_plane(delta)


## The walker held on the way: off it by more than HALF_WAY inside the passage, set back to its edge, their going
## outward stopped (as a wall would).
func _physics_process(_delta: float) -> void:
	if walker == null or not is_instance_valid(walker) or way.is_empty():
		return
	var at := walker.global_position
	if at.x < bounds.position.x or at.x > bounds.end.x or at.z < bounds.position.z or at.z > bounds.end.z \
			or at.y < bounds.position.y - 1.0 or at.y > bounds.end.y:
		return
	var nearest := _nearest(at)
	var out := Vector2(at.x - nearest.x, at.z - nearest.z)
	if out.length() <= HALF_WAY:
		return
	var edge := out.normalized() * HALF_WAY
	walker.global_position = Vector3(nearest.x + edge.x, at.y, nearest.z + edge.y)
	if walker is CharacterBody3D:
		var body := walker as CharacterBody3D
		var flat := Vector2(body.velocity.x, body.velocity.z)
		var outward := out.normalized()
		var going := flat.dot(outward)
		if going > 0.0:
			flat -= outward * going
			body.velocity = Vector3(flat.x, body.velocity.y, flat.y)


## The nearest point of the way (its polylines, on the floor) to `at`, in x-z.
func _nearest(at: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for line: PackedVector3Array in way:
		for i in line.size() - 1:
			var p := Geometry3D.get_closest_point_to_segment(Vector3(at.x, line[i].y, at.z), line[i], line[i + 1])
			var d := Vector2(p.x - at.x, p.z - at.z).length()
			if d < best_d:
				best_d = d
				best = p
	return best


## Landings across its ends' gaps (the stairs', the market's mouth): the way as wide as the gap there, so the walker
## steps in anywhere and is on it.
func _landings() -> void:
	if way.is_empty():
		return
	var y: float = way[0][0].y
	for gap: Dictionary in gaps:
		var a: Vector2 = gap["a"]
		var b: Vector2 = gap["b"]
		# (Only the gaps in its ends, across the corridor: a side gap's branch is its own way.)
		if absf(a.y - b.y) > 0.05:
			continue
		var inward := 0.6 if absf(a.y - bounds.position.z) < 0.05 else -0.6
		var lo := minf(a.x, b.x) + HALF_WAY
		var hi := maxf(a.x, b.x) - HALF_WAY
		if hi > lo:
			way.append(PackedVector3Array([Vector3(lo, y, a.y + inward), Vector3(hi, y, a.y + inward)]))


## The way's stones along it, every STONE_EVERY, each a little turned and sized, their tops at the floor.
func _stones() -> void:
	if way.is_empty() or not ResourceLoader.exists(KIT):
		return
	var kit := SetKit.kit(KIT)
	var look := ShaderMaterial.new()
	look.shader = STONE
	look.set_shader_parameter(&"atlas", SetKit.painted(["astral.png", "astral_base.png"]))
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	look.set_shader_parameter(&"top_y", float(way[0][0].y))
	# (Held here as well, so it outlives every stone when the passage is freed: freed with the last of them, the
	# renderer still asks after it.)
	_stone_look = look
	var k := 0
	for line: PackedVector3Array in way:
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var count := maxi(int(ceil(a.distance_to(b) / STONE_EVERY)), 1)
			for j in count:
				var at := a.lerp(b, (j + 0.5) / count)
				var stone: MeshInstance3D = SetKit.place(self, kit[STONES[k % STONES.size()]], look, "stone", at,
					fposmod(k * 2.39, TAU), false)
				stone.material_override = look
				stone.scale = Vector3(1.0 + 0.12 * sin(k * 1.7), 1.0, 0.9 + 0.1 * cos(k * 2.3))
				stones.append(stone)
				k += 1


## The city's fragments, out in the void past its walls, its ceiling and below its floor, each its own size, turning
## slowly about its own axis and bobbing; drawn in the void's ink (seen only through the windows).
func _fragments() -> void:
	if not ResourceLoader.exists(KIT):
		return
	var kit := SetKit.kit(KIT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1938 + int(bounds.position.z)
	var middle := bounds.get_center()
	for k in FRAGMENTS:
		var kind: String = FRAGMENT_KINDS[k % FRAGMENT_KINDS.size()]
		if not kit.has(kind):
			continue
		var look := ShaderMaterial.new()
		look.shader = INK
		look.render_priority = -5
		look.set_shader_parameter(&"noise", Vfx.noise_3d())
		look.set_shader_parameter(&"flicker_seed", rng.randf() * 10.0)
		# (Out past one side, the ceiling or under the floor, along the passage and a little beyond its ends.)
		var out := rng.randf_range(FRAGMENT_OUT.x, FRAGMENT_OUT.y)
		var along := rng.randf_range(bounds.position.z - 4.0, bounds.end.z + 4.0)
		var at: Vector3
		match k % 4:
			0:
				at = Vector3(bounds.position.x - out, middle.y + rng.randf_range(-6.0, 6.0), along)
			1:
				at = Vector3(bounds.end.x + out, middle.y + rng.randf_range(-6.0, 6.0), along)
			2:
				at = Vector3(middle.x + rng.randf_range(-8.0, 8.0), bounds.end.y + 3.5 + out * 0.4, along)
			_:
				at = Vector3(middle.x + rng.randf_range(-8.0, 8.0), bounds.position.y - BELOW - 3.5 - out * 0.4, along)
		var piece := MeshInstance3D.new()
		piece.name = "fragment_" + kind
		piece.mesh = kit[kind]
		piece.material_override = look
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		piece.position = at
		piece.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		piece.scale = Vector3.ONE * rng.randf_range(FRAGMENT_SIZE.x, FRAGMENT_SIZE.y)
		piece.set_meta("kind", kind)
		piece.set_meta("home", at)
		piece.set_meta("axis", Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
		piece.set_meta("turn", rng.randf_range(FRAGMENT_TURN.x, FRAGMENT_TURN.y))
		piece.set_meta("phase", rng.randf() * TAU)
		fragments.append(piece)


## The presences in the dark, far off, never reached: the vast serpent's coils passing round the passage, eyes opening
## and closing, a line of the city's shades walking a way of their own toward the market, the soot hand's maker's hand
## drifting past. Seen only through the windows.
func _presences() -> void:
	var middle := bounds.get_center()
	presences.append(_serpent())
	# The eyes.
	for k in EYES.size():
		var cluster := Node3D.new()
		cluster.name = "eyes"
		cluster.set_meta("kind", "eyes")
		cluster.set_meta("home", middle + EYES[k][0])
		add_child(cluster)
		cluster.position = middle + EYES[k][0]
		for j in int(EYES[k][1]):
			var look := ShaderMaterial.new()
			look.shader = EYE
			look.render_priority = -4
			look.set_shader_parameter(&"seed", k * 0.37 + j * 0.21)
			var quad := QuadMesh.new()
			quad.size = Vector2(1.6, 0.8)
			var eye := MeshInstance3D.new()
			eye.name = "eye"
			eye.mesh = quad
			eye.material_override = look
			eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cluster.add_child(eye)
			eye.position = Vector3((j - 1.5) * 2.4 * sin(j * 1.3 + k), (j % 2) * 1.6 - 0.8, cos(j * 2.1) * 1.5)
			eye.scale = Vector3.ONE * (1.0 + 0.6 * ((j + k) % 3))
			# Its socket, the crack in the dark it looks through, drawn under it.
			var torn := ShaderMaterial.new()
			torn.shader = EYE
			torn.render_priority = -5
			torn.set_shader_parameter(&"socket", true)
			torn.set_shader_parameter(&"noise", Vfx.noise_3d())
			torn.set_shader_parameter(&"seed", k * 0.37 + j * 0.21)
			look.set_shader_parameter(&"noise", Vfx.noise_3d())
			var crack := QuadMesh.new()
			crack.size = quad.size * SOCKET
			var socket := MeshInstance3D.new()
			socket.name = "socket"
			socket.mesh = crack
			socket.material_override = torn
			socket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			eye.add_child(socket)
			socket.position.z = -0.02
		presences.append(cluster)
	# The shades walking their own way.
	var line := Node3D.new()
	line.name = "shades"
	line.set_meta("kind", "shades")
	add_child(line)
	for k in SHADE_WALKS.size():
		var shade: MeshInstance3D = Silhouette.make_loop(SHADE_WALKS[k])
		if shade == null:
			continue
		line.add_child(shade)
		var look: ShaderMaterial = shade.get("_look")
		look.shader = CUTOUT
		look.render_priority = -4
		shade.set_meta("along", float(k) / SHADE_WALKS.size() * (_span + 16.0))
		# (Under the presence their smoke rises at, so none rises off them out there; drawn whole all the same.)
		shade.presence = 0.7
		look.set_shader_parameter(&"presence", 1.0)
		look.set_shader_parameter(&"glow_strength", 0.45)
	line.position = Vector3(bounds.end.x + SHADES_OUT, bounds.position.y, bounds.position.z - 8.0)
	presences.append(line)
	# The hand.
	var hand := Node3D.new()
	hand.name = "hand"
	hand.set_meta("kind", "hand")
	add_child(hand)
	var sheet := SetKit.painted(["pasaje_marks.png"], SetKit.ATLAS_DIR, true)
	var palm := MeshInstance3D.new()
	palm.name = "palm"
	var quad := QuadMesh.new()
	quad.size = Vector2(HAND_SIZE, HAND_SIZE)
	palm.mesh = quad
	var look := ShaderMaterial.new()
	look.shader = CUTOUT
	look.render_priority = -4
	look.set_shader_parameter(&"sheet", sheet)
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	look.set_shader_parameter(&"cell_scale", Vector2(0.5, 0.5))
	look.set_shader_parameter(&"cell_offset", Vector2(0.0, 0.5))
	# (Its maker's colour, the gods' oxblood, round it.)
	look.set_shader_parameter(&"glow", Color(0.431, 0.122, 0.102))
	look.set_shader_parameter(&"glow_strength", 0.8)
	look.set_shader_parameter(&"reach", 0.035)
	palm.material_override = look
	palm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand.add_child(palm)
	presences.append(hand)
	_drift(0.0)


## The presences on their ways this frame.
func _drift(delta: float) -> void:
	if presences.is_empty():
		return
	var middle := bounds.get_center()
	for presence in presences:
		match String(presence.get_meta("kind", "")):
			"serpent":
				var a := _clock * SERPENT_PACE
				presence.position = middle + Vector3(cos(a) * SERPENT_ROUND, 2.0 + 4.0 * sin(a * 2.3), sin(a) * SERPENT_ROUND)
				# (Its head leading round its circle.)
				presence.rotation.y = -a
				# Its tongue: every few seconds out, two flicks, and in.
				var tongue := presence.get_node_or_null("tongue") as Node3D
				if tongue != null:
					var beat := fposmod(_clock, TONGUE_EVERY)
					var out := sin(clampf(beat / TONGUE_TIME, 0.0, 1.0) * PI)
					var flick := 0.85 + 0.15 * sin(beat * 40.0)
					tongue.scale.z = maxf(out * flick, 0.01)
					tongue.rotation.x = 0.15 * sin(beat * 25.0) * out
			"eyes":
				var home: Vector3 = presence.get_meta("home")
				presence.position = home + Vector3(0.0, 0.6 * sin(_clock * 0.11 + home.x), 0.4 * cos(_clock * 0.07 + home.z))
			"shades":
				for shade: Node in presence.get_children():
					if not shade is MeshInstance3D:
						continue
					var along: float = fposmod(float(shade.get_meta("along")) + delta * SHADE_PACE, _span + 16.0)
					shade.set_meta("along", along)
					(shade as Node3D).position = Vector3(0.0, 0.0, along if mouth_end > 0 else _span + 16.0 - along)
					shade.set("heading", Vector3(0.0, 0.0, float(mouth_end)))
					if delta > 0.0:
						shade.call("walk", delta * SHADE_PACE)
			"hand":
				presence.position = middle + HAND_AT + Vector3(0.0, sin(_clock * 0.05) * 1.5, sin(_clock * 0.03) * (_span * 0.5))
				presence.rotation = Vector3(0.0, PI / 2.0 + sin(_clock * 0.04) * 0.3, sin(_clock * 0.06) * 0.2)


## Its thresholds: a ward-gate in each of its gaps, its face across the gap: the vortex filling it, three rings of the
## script at their own depths turning against each other, embers burning off its rim, motes spiralling into it.
func _thresholds() -> void:
	var sheet := SetKit.painted([RINGS_SHEET], SetKit.ATLAS_DIR, true)
	for gap: Dictionary in gaps:
		var a: Vector2 = gap["a"]
		var b: Vector2 = gap["b"]
		var y0: float = gap["y0"]
		var y1: float = minf(float(gap["y1"]), bounds.end.y)
		var size := Vector2(a.distance_to(b), y1 - y0)
		var side := minf(size.x, size.y)
		var gate := Node3D.new()
		gate.name = "threshold"
		add_child(gate)
		var middle := (a + b) / 2.0
		gate.position = Vector3(middle.x, (y0 + y1) / 2.0, middle.y)
		var along := (b - a).normalized()
		gate.rotation.y = atan2(-along.y, along.x)
		# The vortex.
		var look := ShaderMaterial.new()
		look.shader = MEMBRANE
		look.set_shader_parameter(&"noise", Vfx.noise_3d())
		look.set_shader_parameter(&"size", size)
		look.set_shader_parameter(&"circle", GATE_CIRCLE)
		look.set_shader_parameter(&"lean", LEAN)
		_gate_quad(gate, "vortex", size, look)
		# Its rings, sized so the sheet's outer ring sits at its circle's rim.
		var rim := side * GATE_CIRCLE
		for k in RING_DEPTHS.size():
			var ring_look := ShaderMaterial.new()
			ring_look.shader = RING
			ring_look.set_shader_parameter(&"sheet", sheet)
			ring_look.set_shader_parameter(&"cell", float(k))
			ring_look.set_shader_parameter(&"seed", k * 1.7 + gate.position.z)
			ring_look.render_priority = 1
			ring_look.set_shader_parameter(&"lean", LEAN)
			var ring := _gate_quad(gate, "ring%d" % (k + 1), Vector2.ONE * rim / RING_SHEET_RIM, ring_look)
			ring.position.z = RING_DEPTHS[k]
			ring.rotation.z = k * 0.9
		# Round its circle, the void: a window with the circle cut out of it (from inside one with the passage's own
		# void, so the gate floats in it); past it, the void bleeding out over the world's surfaces.
		var frame_look := ShaderMaterial.new()
		frame_look.shader = MARK
		frame_look.set_shader_parameter(&"noise", Vfx.noise_3d())
		frame_look.set_shader_parameter(&"hole", rim * GATE_HOLE)
		frame_look.set_shader_parameter(&"size", size)
		_gate_quad(gate, "frame", size, frame_look)
		_arch(gate, rim, size, sheet)
		_jambs(gate, rim, size)
		gate.add_child(_embers(rim))
		gate.add_child(_spiral(rim * 0.95))
		thresholds.append(gate)
		_bleed(gaps.find(gap), gap)


## The burning edge's look over a torn window (astral_tear.gdshader), with the window's `params`.
func _tear_look(params: Dictionary) -> ShaderMaterial:
	var look := ShaderMaterial.new()
	look.shader = TEAR_EDGE
	look.set_shader_parameter(&"lean", LEAN)
	look.render_priority = 2
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	for key in params:
		look.set_shader_parameter(key, params[key])
	return look


## The arch round a gate's circle (`rim` m round, in its gap `size`): carved stones floating apart, up its jambs from
## the floor and over its top, a keystone at its crown; drawn in the void (astral_arch.gdshader).
func _arch(gate: Node3D, rim: float, size: Vector2, sheet: Texture2D) -> void:
	var out := rim * ARCH_OUT
	var base := -size.y / 2.0 + ARCH_STONE.y / 2.0
	# Its line: up the left jamb, over the top, down the right (in the gate's face, x-y).
	var line := PackedVector2Array([Vector2(-out, base)])
	for k in 25:
		var a := PI - PI * k / 24.0
		line.append(Vector2(cos(a), sin(a)) * out)
	line.append(Vector2(out, base))
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	var count := int(total / ARCH_EVERY)
	for k in count + 1:
		var s := float(k) / count
		var at := _on_line(line, s * total)
		var ahead := (_on_line(line, minf(s * total + 0.05, total)) - _on_line(line, maxf(s * total - 0.05, 0.0))).normalized()
		var keystone := absf(s - 0.5) < 0.5 / count
		var box := BoxMesh.new()
		box.size = ARCH_STONE * (1.35 if keystone else 1.0)
		var look := ShaderMaterial.new()
		look.shader = ARCH
		look.render_priority = -3
		look.set_shader_parameter(&"rings", sheet)
		look.set_shader_parameter(&"noise", Vfx.noise_3d())
		look.set_shader_parameter(&"gate_at", gate.global_position)
		look.set_shader_parameter(&"place", s)
		look.set_shader_parameter(&"keystone", keystone)
		look.set_shader_parameter(&"stone", Color(0.12, 0.1, 0.09).lerp(Color(0.16, 0.13, 0.11), fposmod(k * 0.37, 1.0)))
		var stone := MeshInstance3D.new()
		stone.name = "arch%d" % k
		stone.mesh = box
		stone.material_override = look
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gate.add_child(stone)
		# (Each a little apart from its fellows and turned, floating.)
		stone.position = Vector3(at.x, at.y, 0.0)
		stone.rotation.z = atan2(ahead.y, ahead.x) + sin(k * 2.3) * 0.08
		stone.rotation.x = sin(k * 1.7) * 0.06
		stone.set_meta("home", stone.position)
		stone.set_meta("phase", k * 0.9)


## Unseen jambs closing a gate's gap (`size`) either side of its arch (round its circle, `rim` m round), so the way in
## is only through the arch: never through the void beside it (and shoved onto the way after).
func _jambs(gate: Node3D, rim: float, size: Vector2) -> void:
	var opening := rim * ARCH_OUT - ARCH_STONE.y / 2.0
	var side := size.x / 2.0 - opening
	if side <= 0.01:
		return
	var body := StaticBody3D.new()
	body.name = "jambs"
	gate.add_child(body)
	for which in [-1.0, 1.0]:
		var box := BoxShape3D.new()
		box.size = Vector3(side, size.y, JAMB_DEPTH)
		var shape := CollisionShape3D.new()
		shape.shape = box
		body.add_child(shape)
		shape.position.x = which * (opening + side / 2.0)


## The point `by` m along `line`.
func _on_line(line: PackedVector2Array, by: float) -> Vector2:
	for i in line.size() - 1:
		var piece := line[i].distance_to(line[i + 1])
		if by <= piece:
			return line[i].lerp(line[i + 1], by / piece)
		by -= piece
	return line[line.size() - 1]


## The void bleeding out past gap `k` (`gap`) over the world's own surfaces beyond it, in ragged tongues spreading
## from the gap's edges (astral_mark.gdshader's bleed), burning along their edges (astral_tear.gdshader): past a
## corridor's mouth (a gap with an "inset": how far in the world's walls stand from its edges), over the corridor's
## floor, walls and ceiling; past a hole in a wall, over the floor below it and the wall round it.
func _bleed(k: int, gap: Dictionary) -> void:
	var a2: Vector2 = gap["a"]
	var b2: Vector2 = gap["b"]
	var y0: float = gap["y0"]
	var y1: float = minf(float(gap["y1"]), bounds.end.y)
	var along2 := (b2 - a2).normalized()
	var out2 := Vector2(-along2.y, along2.x)
	var centre := Vector2(bounds.get_center().x, bounds.get_center().z)
	if out2.dot((a2 + b2) / 2.0 - centre) < 0.0:
		out2 = -out2
	var along := Vector3(along2.x, 0.0, along2.y)
	var out := Vector3(out2.x, 0.0, out2.y)
	var reach := BLEED * 1.5
	var h := y1 - y0
	# [its middle, its two axes (their lengths its size), the edge it spreads from (two points)].
	var faces := []
	if gap.has("inset"):
		var inset: float = gap["inset"]
		var a := Vector3(a2.x, 0.0, a2.y) + along * inset
		var b := Vector3(b2.x, 0.0, b2.y) - along * inset
		var width := a.distance_to(b)
		var mid := (a + b) / 2.0
		for y in [y0 + BLEED_OFF, y1 - BLEED_OFF]:
			faces.append([mid + Vector3(0.0, y, 0.0) + out * reach / 2.0, along * width, out * reach,
				a + Vector3(0.0, y, 0.0), b + Vector3(0.0, y, 0.0)])
		for side in [[a, along], [b, -along]]:
			var foot: Vector3 = side[0] + side[1] * BLEED_OFF
			faces.append([foot + Vector3(0.0, y0 + h / 2.0, 0.0) + out * reach / 2.0, out * reach, Vector3.UP * h,
				foot + Vector3(0.0, y0, 0.0), foot + Vector3(0.0, y1, 0.0)])
	else:
		var a := Vector3(a2.x, 0.0, a2.y) + out * BLEED_OFF
		var b := Vector3(b2.x, 0.0, b2.y) + out * BLEED_OFF
		var width := a.distance_to(b)
		var mid := (a + b) / 2.0
		# The floor below it.
		faces.append([mid + Vector3(0.0, y0 + BLEED_OFF, 0.0) + out * reach / 2.0, along * (width + reach * 2.0),
			out * reach, Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z)])
		# The wall round it: either side of it and over it.
		for side in [[a, -along], [b, along]]:
			var edge: Vector3 = side[0]
			faces.append([edge + side[1] * reach / 2.0 + Vector3(0.0, y0 + (h + reach) / 2.0, 0.0), along * reach,
				Vector3.UP * (h + reach), edge + Vector3(0.0, y0, 0.0), edge + Vector3(0.0, y1, 0.0)])
		faces.append([mid + Vector3(0.0, y1 + reach / 2.0, 0.0), along * width, Vector3.UP * reach,
			a + Vector3(0.0, y1, 0.0), b + Vector3(0.0, y1, 0.0)])
	for face: Array in faces:
		var params := {&"bleed": BLEED, &"seg_a": face[3], &"seg_b": face[4]}
		var look := ShaderMaterial.new()
		look.shader = MARK
		look.set_shader_parameter(&"noise", Vfx.noise_3d())
		for key in params:
			look.set_shader_parameter(key, params[key])
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		for piece in [_plain(look, Vector2(u.length(), v.length())), _plain(_tear_look(params), Vector2(u.length(), v.length()))]:
			piece.name = "bleed"
			windows.erase(piece)
			piece.set_meta("gap", k)
			bleeds.append(piece)
			piece.transform = Transform3D(Basis(u.normalized(), v.normalized(), u.cross(v).normalized()), face[0])


func _gate_quad(gate: Node3D, name: String, size: Vector2, look: Material) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var piece := MeshInstance3D.new()
	piece.name = name
	piece.mesh = quad
	piece.material_override = look
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(piece)
	return piece


## A gate's embers: burning off its rim (`rim` m round), drifting up and out, marigold going to oxblood.
func _embers(rim: float) -> GPUParticles3D:
	var embers := GPUParticles3D.new()
	embers.name = "embers"
	embers.amount = EMBERS
	embers.lifetime = EMBER_LIFE
	embers.preprocess = EMBER_LIFE
	embers.layers = Layers.FX
	embers.local_coords = true
	embers.visibility_aabb = AABB(Vector3(-rim - 1.5, -rim - 1.5, -1.5), Vector3(rim * 2.0 + 3.0, rim * 2.0 + 3.5, 3.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	process.emission_ring_radius = rim
	process.emission_ring_inner_radius = rim * 0.96
	process.emission_ring_height = 0.06
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 60.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.45
	process.gravity = Vector3(0.0, 0.25, 0.0)
	process.damping_min = 0.2
	process.damping_max = 0.6
	process.scale_min = 0.5
	process.scale_max = 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.1))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	process.scale_curve = shrink_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.85, 0.55, 1.0))
	fade.set_color(1, Color(0.43, 0.12, 0.1, 0.0))
	fade.add_point(0.35, Color(1.0, 0.62, 0.16, 1.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	embers.process_material = process
	embers.draw_pass_1 = _glow_quad(0.04)
	return embers


## A gate's motes, spiralling in from its rim (`rim` m round) to its eye (astral_spiral.gdshader).
func _spiral(rim: float) -> GPUParticles3D:
	var spiral := GPUParticles3D.new()
	spiral.name = "spiral"
	spiral.amount = SPIRAL_MOTES
	spiral.lifetime = SPIRAL_LIFE
	spiral.preprocess = SPIRAL_LIFE
	spiral.layers = Layers.FX
	spiral.local_coords = true
	spiral.visibility_aabb = AABB(Vector3(-rim - 0.5, -rim - 0.5, -0.5), Vector3(rim * 2.0 + 1.0, rim * 2.0 + 1.0, 1.0))
	var process := ShaderMaterial.new()
	process.shader = SPIRAL
	process.set_shader_parameter(&"radius", rim)
	spiral.process_material = process
	spiral.draw_pass_1 = _glow_quad(0.035)
	return spiral


## A soft round glow, its colour the particle's own, added.
func _glow_quad(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	# (Faded out close to the eye, so none passes as a ball in front of it.)
	look.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	look.distance_fade_min_distance = 0.4
	look.distance_fade_max_distance = 1.6
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	soft.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	glow.gradient = soft
	look.albedo_texture = glow
	quad.material = look
	return quad


var _plane_look: ShaderMaterial
var _plane_in := 0.0
var _shift := 0.0


## The plane over the eye (astral_plane.gdshader), under the HUD, shown only while any of it is.
func _plane() -> void:
	plane_shift = CanvasLayer.new()
	plane_shift.name = "plane_shift"
	plane_shift.layer = PLANE_LAYER
	plane_shift.visible = false
	add_child(plane_shift)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plane_look = ShaderMaterial.new()
	_plane_look.shader = PLANE
	var flow := NoiseTexture2D.new()
	flow.seamless = true
	flow.width = 256
	flow.height = 256
	flow.noise = FastNoiseLite.new()
	_plane_look.set_shader_parameter(&"noise", flow)
	_plane_look.set_shader_parameter(&"strength", 0.0)
	rect.material = _plane_look
	plane_shift.add_child(rect)


## The crossing of a threshold: the breath of the shift of planes.
func _warp() -> void:
	_shift = 1.0


## The plane eased in while the walker is inside, out while not; the crossing's breath falling away.
func _ease_plane(delta: float) -> void:
	if _plane_look == null:
		return
	_plane_in = move_toward(_plane_in, 1.0 if inside else 0.0, (PLANE_IN if inside else PLANE_OUT) * delta)
	_shift = move_toward(_shift, 0.0, delta / SHIFT_TIME)
	# (Eased: the breath sharp at first, slow to let go.)
	_plane_look.set_shader_parameter(&"strength", smoothstep(0.0, 1.0, _plane_in))
	_plane_look.set_shader_parameter(&"shift", _shift * _shift)
	plane_shift.visible = _plane_in > 0.0 or _shift > 0.0


var _muffles: Array[AudioEffectLowPassFilter] = []
## The passages the walker is in now, and the one passage that eases the shared muffle each frame (the buses' filters
## are one for all of them: two easing them toward their own ends would fight).
static var _within := {}
static var _easer: Node


func _exit_tree() -> void:
	_within.erase(get_instance_id())


## Inside any passage, the world's sound eased dull; outside them all, eased back (the low-pass on World and Ambience,
## added once, shared).
func _muffle(delta: float) -> void:
	if inside:
		_within[get_instance_id()] = true
	else:
		_within.erase(get_instance_id())
	if _easer == null or not is_instance_valid(_easer):
		_easer = self
	if _easer != self:
		return
	if _muffles.is_empty():
		for name in MUFFLE_BUSES:
			var bus := AudioServer.get_bus_index(name)
			if bus < 0:
				continue
			var found: AudioEffectLowPassFilter = null
			for i in AudioServer.get_bus_effect_count(bus):
				var effect := AudioServer.get_bus_effect(bus, i)
				if effect is AudioEffectLowPassFilter and effect.resource_name == "astral":
					found = effect
			if found == null:
				found = AudioEffectLowPassFilter.new()
				found.resource_name = "astral"
				found.cutoff_hz = MUFFLE.y
				AudioServer.add_bus_effect(bus, found)
			_muffles.append(found)
	var target := MUFFLE.x if not _within.is_empty() else MUFFLE.y
	for filter in _muffles:
		var log_now := log(filter.cutoff_hz)
		filter.cutoff_hz = exp(lerpf(log_now, log(target), clampf(MUFFLE_EASE * delta, 0.0, 1.0)))


## The feathered serpent (astral_serpent.gdshader), along its own -z from its neck, its head forward of it: its scaled
## coils, its head with its jaw a little open, fangs and eyes, a ruff of feathers round its neck, feathers in pairs down
## its back and a plume at its tail. Every part swims together (their UV.x how far along it they are).
func _serpent() -> Node3D:
	var serpent := Node3D.new()
	serpent.name = "serpent"
	serpent.set_meta("kind", "serpent")
	add_child(serpent)
	var frames := _serpent_frames()
	_serpent_part(serpent, "coils", _coils_mesh(frames), 0, -7)
	_serpent_part(serpent, "feathers", _feathers_mesh(frames), 1, -6)
	# Its head: skull, jaw (hinged below its neck, a little open), fangs, eyes.
	_serpent_part(serpent, "head", _head_mesh([0.74, 0.95, 0.74, 0.62, 0.3, 0.12, 0.3], -0.1, 2.7, 0.0), 2, -5)
	var tongue := _serpent_part(serpent, "tongue", _tongue_mesh(), 5, -6)
	tongue.position = Vector3(0.0, -0.14, 2.2)
	tongue.scale = Vector3(1.0, 1.0, 0.01)
	var jaw := _serpent_part(serpent, "jaw", _head_mesh([0.62, 0.72, 0.14, 0.1, 0.24, 0.1], 0.0, 2.3, 0.0), 2, -6)
	jaw.position = Vector3(0.0, -0.28, 0.12)
	jaw.rotation.x = 0.22
	_serpent_part(serpent, "fangs", _fangs_mesh([Vector3(0.3, -0.12, 2.15), Vector3(-0.3, -0.12, 2.15),
		Vector3(0.42, -0.1, 1.75), Vector3(-0.42, -0.1, 1.75)], -1.0, 0.42), 3, -6)
	_serpent_part(jaw, "fangs_lower", _fangs_mesh([Vector3(0.26, 0.05, 1.95), Vector3(-0.26, 0.05, 1.95)], 1.0, 0.26), 3, -6)
	for side in [1.0, -1.0]:
		var eye := _serpent_part(serpent, "serpent_eye" if side > 0.0 else "serpent_eye_left", _dome_mesh(0.2), 4, -4)
		eye.position = Vector3(0.48 * side, 0.36, 1.18)
		eye.rotation = Vector3(-0.3, PI / 2.0 * side, 0.0)
	return serpent


func _serpent_part(parent: Node3D, name: String, mesh: ArrayMesh, part: int, priority: int) -> MeshInstance3D:
	var look := ShaderMaterial.new()
	look.shader = SERPENT
	look.render_priority = priority
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	look.set_shader_parameter(&"part", part)
	look.set_shader_parameter(&"swim", SERPENT_SWIM)
	look.set_shader_parameter(&"body_length", SERPENT_LENGTH)
	var piece := MeshInstance3D.new()
	piece.name = name
	piece.mesh = mesh
	piece.material_override = look
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (Its swim reaches past its mesh's bounds.)
	piece.extra_cull_margin = SERPENT_SWIM * 2.0
	parent.add_child(piece)
	return piece


## Its body's line, ring by ring from its neck to its tail: [where, forward, side, up, its girth's radius].
func _serpent_frames() -> Array:
	var rings := 140
	var points := []
	for i in rings + 1:
		var s := SERPENT_LENGTH * i / rings
		points.append(Vector3(1.8 * sin(s * 0.33), 1.0 * sin(s * 0.2 + 0.7), -s))
	var frames := []
	for i in rings + 1:
		var t := float(i) / rings
		var forward: Vector3 = (points[mini(i + 1, rings)] - points[maxi(i - 1, 0)]).normalized()
		var side := forward.cross(Vector3.UP).normalized()
		# (Thick behind its head, tapering to a point at its tail; swelling a little at its neck.)
		var r := (0.03 + 0.71 * pow(1.0 - t, 0.8)) * (1.0 + 0.08 * exp(-pow((t - 0.04) / 0.03, 2.0)))
		frames.append([points[i], forward, side, side.cross(forward), r])
	return frames


## Its scaled coils: a tube round its line (UV.x along it, UV.y round it, 0.25 its back, 0.75 its belly).
func _coils_mesh(frames: Array) -> ArrayMesh:
	var sections := []
	for frame: Array in frames:
		sections.append([frame[0], frame[2], frame[3], frame[4], frame[4], frame[4]])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(tool, sections, 16, func(i: int) -> float: return float(i) / (frames.size() - 1))
	tool.generate_normals()
	return tool.commit()


## A head's piece lofted from `z0` to `z1` along +z, its section at each share s an ellipse [its half width at its
## back, at its widest (s 0.3), its height over its middle at its back, at its snout, under its middle at its back, at
## its snout], closed to a point at its snout; it doesn't swim (UV.x 0), its plates on UV2.
func _head_mesh(shape: Array, z0: float, z1: float, y: float) -> ArrayMesh:
	var sections := []
	var steps := 14
	for i in steps + 1:
		var s := float(i) / steps
		var wide := lerpf(shape[0], shape[1], smoothstep(0.0, 0.3, s)) * (1.0 - 0.62 * s * s)
		var over := lerpf(shape[2], shape[3], s) * (1.0 - 0.45 * pow(s, 1.5))
		var under := lerpf(shape[4], shape[5], s)
		# (Its brows: two ridges over its eyes, s 0.42 along it.)
		var brow: float = float(shape[6]) * exp(-pow((s - 0.42) / 0.12, 2.0)) if shape.size() > 6 else 0.0
		sections.append([Vector3(0.0, y + 0.05 * s, lerpf(z0, z1, s)), Vector3(-1.0, 0.0, 0.0), Vector3.UP, wide, over,
			under, brow])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_loft(tool, sections, 18, func(_i: int) -> float: return 0.0)
	# Its snout closed.
	var last: Array = sections[steps]
	var tip := Vector3(0.0, y + 0.06, z1 + 0.12)
	var sides := 18
	for j in sides:
		var a := _section_point(last, j, sides)
		var b := _section_point(last, j + 1, sides)
		for v in [a, b, tip]:
			tool.set_uv(Vector2.ZERO)
			tool.set_uv2(Vector2(1.0, float(j) / sides))
			tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


## A loft through `sections` ([centre, side, up, half width, height over, height under]), `sides` round, UV.x from
## `along` (its section's index), UV.y round it, UV2 (its share along, round it).
func _loft(tool: SurfaceTool, sections: Array, sides: int, along: Callable) -> void:
	var last := sections.size() - 1
	for i in last:
		for j in sides:
			var corners := [[i, j], [i, j + 1], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i + 1, j]]
			for c: Array in corners:
				tool.set_uv(Vector2(along.call(c[0]), float(c[1]) / sides))
				tool.set_uv2(Vector2(float(c[0]) / last, float(c[1]) / sides))
				tool.add_vertex(_section_point(sections[c[0]], c[1], sides))


func _section_point(section: Array, j: int, sides: int) -> Vector3:
	var a := TAU * j / sides
	var s := sin(a)
	var height: float = section[4] if s > 0.0 else section[5]
	# (A brow ridge either side of its top, where it has one.)
	if s > 0.0 and section.size() > 6:
		height *= 1.0 + float(section[6]) * exp(-pow((absf(cos(a)) - 0.5) / 0.2, 2.0))
	return section[0] + section[1] * cos(a) * float(section[3]) + section[2] * s * height


## Fangs: a cone at each of `roots`, pointing `down` (-1 down, 1 up), `length` long, curving a little back.
func _fangs_mesh(roots: Array, down: float, length: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 8
	for root: Vector3 in roots:
		var tip := root + Vector3(0.0, down * length, -length * 0.25)
		var r := length * 0.16
		for j in sides:
			var a := TAU * j / sides
			var b := TAU * (j + 1) / sides
			var pa := root + Vector3(cos(a) * r, 0.0, sin(a) * r)
			var pb := root + Vector3(cos(b) * r, 0.0, sin(b) * r)
			for v in ([pb, pa, tip] if down < 0.0 else [pa, pb, tip]):
				tool.set_uv(Vector2.ZERO)
				tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


## An eye's dome, facing +z, `radius` round (UV2 its face, 0..1 across).
func _dome_mesh(radius: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	var sides := 14
	var point := func(i: int, j: int) -> Vector3:
		var lat := PI / 2.0 * i / rings
		var a := TAU * j / sides
		return Vector3(cos(a) * sin(lat), sin(a) * sin(lat), cos(lat) * 0.6) * radius
	for i in rings:
		for j in sides:
			for c in [[i, j], [i, j + 1], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i + 1, j]]:
				var v: Vector3 = point.call(c[0], c[1])
				tool.set_uv(Vector2.ZERO)
				tool.set_uv2(Vector2(v.x, v.y) / radius * 0.5 + Vector2(0.5, 0.5))
				tool.add_vertex(v)
	tool.generate_normals()
	return tool.commit()


## Its feathers: a ruff round its neck, pairs down its back's flanks every FEATHER_EVERY, a plume at its tail; each a
## curling strip (UV2 along and across it, UV.x where along its body its root is), two-sided.
func _feathers_mesh(frames: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var rings := frames.size() - 1
	# The ruff.
	for k in RUFF:
		var a := TAU * k / RUFF
		var out := Vector3(cos(a), sin(a) * 0.9 + 0.15, 0.0).normalized()
		_feather(tool, out * 0.62 + Vector3(0.0, 0.0, -0.1), (out * 0.75 + Vector3(0.0, 0.0, -0.66)).normalized(),
			RUFF_LENGTH * (0.8 + 0.3 * smoothstep(-0.3, 1.0, out.y)), 0.38, 0.004)
	# A crown on its head, swept back over its neck.
	for k in 6:
		var side := -1.0 if k % 2 == 0 else 1.0
		var root := Vector3(side * (0.12 + 0.1 * (k / 2)), 0.6, 1.15 - 0.22 * (k / 2))
		var dir := Vector3(side * 0.25, 0.5, -0.83).normalized()
		_feather(tool, root, dir, 1.6 + 0.3 * (k / 2), 0.3, 0.0)
	# Down its back: plumage in two rows a side, lying back along it, the upper row half a step on; a crest along
	# its spine over its front half.
	var s := 1.2
	var step := 0
	while s < SERPENT_LENGTH * 0.82:
		var frame: Array = frames[roundi(s / SERPENT_LENGTH * rings)]
		var r: float = frame[4]
		var length := FEATHER_LENGTH * (r / 0.74) * (0.85 + 0.15 * sin(s * 1.9)) + 0.35
		var row_angle := 70.0 if step % 2 == 0 else 35.0
		for side in [1.0, -1.0]:
			var radial: Vector3 = (frame[3] * cos(deg_to_rad(row_angle)) + frame[2] * side * sin(deg_to_rad(row_angle))).normalized()
			var dir: Vector3 = (frame[1] * 0.92 + radial * 0.38).normalized()
			_feather(tool, frame[0] + radial * r * 0.9, dir, length, length * 0.2, s / SERPENT_LENGTH)
		if s < SERPENT_LENGTH * 0.5 and step % 2 == 0:
			var crest: Vector3 = (frame[1] * 0.6 + frame[3] * 0.8).normalized()
			_feather(tool, frame[0] + frame[3] * r * 0.95, crest, length * 0.55, length * 0.16, s / SERPENT_LENGTH)
		s += FEATHER_EVERY / 2.0
		step += 1
	# The plume at its tail, fanned wide and drooping.
	var tail: Array = frames[rings]
	for k in PLUME:
		var spread := (k - (PLUME - 1) / 2.0) / PLUME
		var dir: Vector3 = (tail[1] + tail[2] * spread * 1.8 - tail[3] * 0.2).normalized()
		_feather(tool, tail[0], dir, PLUME_LENGTH * (1.0 - absf(spread) * 0.4), 0.55, 1.0)
	return tool.commit()


## Its forked tongue, out along +z from its mouth (the node scaled along z to flick it).
func _tongue_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	# Each line [its points ([where along it (m), its half width]), which way it forks (0 the strip, -1/1 a tine)].
	var lines := [[[[0.0, 0.07], [0.6, 0.05], [0.75, 0.05]], 0.0]]
	for side in [-1.0, 1.0]:
		lines.append([[[0.75, 0.025], [1.15, 0.008]], side])
	for line: Array in lines:
		var points: Array = line[0]
		var bend: float = line[1]
		for i in points.size() - 1:
			var a: Array = points[i]
			var b: Array = points[i + 1]
			var xa: float = (float(a[0]) - 0.75) * 0.3 * bend
			var xb: float = (float(b[0]) - 0.75) * 0.3 * bend
			var quad := [Vector3(xa - a[1], 0.0, a[0]), Vector3(xa + a[1], 0.0, a[0]), Vector3(xb + b[1], 0.0, b[0]),
				Vector3(xa - a[1], 0.0, a[0]), Vector3(xb + b[1], 0.0, b[0]), Vector3(xb - b[1], 0.0, b[0])]
			for order in [quad, [quad[0], quad[2], quad[1], quad[3], quad[5], quad[4]]]:
				for v: Vector3 in order:
					tool.set_uv(Vector2.ZERO)
					tool.set_uv2(Vector2(v.z / 1.15, 0.5))
					tool.add_vertex(v)
	return tool.commit()


## One feather from `root` along `dir`, `length` long and `width` wide, curling a little, its root `t` along the body.
func _feather(tool: SurfaceTool, root: Vector3, dir: Vector3, length: float, width: float, t: float) -> void:
	var across := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var curl := dir.cross(across).normalized()
	var steps := 4
	var edges := []
	for i in steps + 1:
		var u := float(i) / steps
		var at := root + dir * length * u + curl * length * 0.22 * u * u
		edges.append([at - across * width / 2.0, at + across * width / 2.0, u])
	for i in steps:
		var a: Array = edges[i]
		var b: Array = edges[i + 1]
		var quad := [[a[0], a[2], 0.0], [a[1], a[2], 1.0], [b[1], b[2], 1.0], [a[0], a[2], 0.0], [b[1], b[2], 1.0], [b[0], b[2], 0.0]]
		# (Both its faces.)
		for order in [quad, [quad[0], quad[2], quad[1], quad[3], quad[5], quad[4]]]:
			for v: Array in order:
				tool.set_uv(Vector2(t, 0.0))
				tool.set_uv2(Vector2(v[1], v[2]))
				tool.add_vertex(v[0])


## The windows where its walls, ceiling and floor were: each wall cut round its gaps (a run either side, a lintel over),
## the wall at the market's mouth left open, the floor's window BELOW the floor.
func _windows() -> void:
	var look := ShaderMaterial.new()
	look.shader = WINDOW
	var low := bounds.position.y - BELOW
	var high := bounds.end.y
	var x0 := bounds.position.x
	var x1 := bounds.end.x
	var z0 := bounds.position.z
	var z1 := bounds.end.z
	# [its line (from, to in x-z), its inward normal]; the market's end left out.
	var walls := [[Vector2(x0, z0), Vector2(x0, z1), Vector3(1, 0, 0)], [Vector2(x1, z0), Vector2(x1, z1), Vector3(-1, 0, 0)]]
	var far_z := z0 if mouth_end > 0 else z1
	walls.append([Vector2(x0, far_z), Vector2(x1, far_z), Vector3(0, 0, 1 if mouth_end > 0 else -1)])
	for wall: Array in walls:
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		var length := a.distance_to(b)
		var along := (b - a) / length
		# (Its gaps, as runs along it.)
		var holes := []
		for gap: Dictionary in gaps:
			var ga: Vector2 = gap["a"]
			var gb: Vector2 = gap["b"]
			var off_a := absf((ga - a).cross(along))
			var off_b := absf((gb - a).cross(along))
			if off_a < 0.05 and off_b < 0.05:
				var s0 := (ga - a).dot(along)
				var s1 := (gb - a).dot(along)
				holes.append([minf(s0, s1), maxf(s0, s1), float(gap["y1"])])
		holes.sort_custom(func(p, q): return p[0] < q[0])
		var from := 0.0
		for hole: Array in holes + [[length, length, high]]:
			if hole[0] - from > 0.01:
				_window(look, a + along * (from + hole[0]) / 2.0, along, hole[0] - from, low, high, wall[2])
			if hole[1] - hole[0] > 0.01 and high - hole[2] > 0.01:
				_window(look, a + along * (hole[0] + hole[1]) / 2.0, along, hole[1] - hole[0], hole[2], high, wall[2])
			from = maxf(from, hole[1])
	# The ceiling and, below the floor, the floor.
	for spec in [[high, Vector3.DOWN], [low, Vector3.UP]]:
		var flat := _plain(look, Vector2(bounds.size.x, bounds.size.z))
		flat.position = Vector3(bounds.get_center().x, spec[0], bounds.get_center().z)
		flat.rotation.x = PI / 2.0 if spec[1] == Vector3.DOWN else -PI / 2.0


## A window upright on a wall: `width` along `along` round `middle` (x, z), from `y0` to `y1`, facing `normal`.
func _window(look: Material, middle: Vector2, along: Vector2, width: float, y0: float, y1: float, normal: Vector3) -> void:
	var piece := _plain(look, Vector2(width, y1 - y0))
	piece.position = Vector3(middle.x, (y0 + y1) / 2.0, middle.y)
	piece.rotation.y = atan2(normal.x, normal.z)


func _plain(look: Material, size: Vector2) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var piece := MeshInstance3D.new()
	piece.name = "window"
	piece.mesh = quad
	piece.set_surface_override_material(0, look)
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	windows.append(piece)
	return piece


## The void's sky: a sphere round the passage, painted inside, drawn first of the void.
func _sky() -> void:
	var look := ShaderMaterial.new()
	look.shader = SKY
	look.render_priority = -10
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	# (The user's brush sheets, when they are here: kept out of the repository.)
	if ResourceLoader.exists(BRUSH):
		look.set_shader_parameter(&"brush", load(BRUSH))
	var sphere := SphereMesh.new()
	sphere.radius = SKY_RADIUS
	sphere.height = SKY_RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	sky = MeshInstance3D.new()
	sky.name = "sky"
	sky.mesh = sphere
	sky.set_surface_override_material(0, look)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.extra_cull_margin = SKY_RADIUS
	add_child(sky)
	sky.position = bounds.get_center()


## The eclipse, high ahead toward the market and a little west, far off in the deep.
func _eclipse() -> void:
	var look := ShaderMaterial.new()
	look.shader = ECLIPSE
	look.render_priority = -9
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	var quad := QuadMesh.new()
	quad.size = Vector2(ECLIPSE_SIZE, ECLIPSE_SIZE)
	eclipse = MeshInstance3D.new()
	eclipse.name = "eclipse"
	eclipse.mesh = quad
	eclipse.material_override = look
	eclipse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eclipse.extra_cull_margin = ECLIPSE_SIZE
	add_child(eclipse)
	var high := deg_to_rad(ECLIPSE_HIGH)
	var round_by := deg_to_rad(ECLIPSE_ROUND)
	var ahead := Vector3(-sin(round_by), 0.0, cos(round_by) * float(mouth_end))
	eclipse.position = bounds.get_center() + (ahead * cos(high) + Vector3.UP * sin(high)) * ECLIPSE_FAR


## Where `at` ([how far, degrees round from straight ahead toward the market, degrees up]) lies from its middle.
func _out_in_the_deep(at: Vector3) -> Vector3:
	var round_by := deg_to_rad(at.y)
	var high := deg_to_rad(at.z)
	var ahead := Vector3(sin(round_by), 0.0, cos(round_by) * float(mouth_end))
	return bounds.get_center() + (ahead * cos(high) + Vector3.UP * sin(high)) * at.x


## The colossi far out in the deep, turning slowly: the sun stone adrift, its wedge broken away; the city hanging
## upside down overhead; the stair spiralling down into the abyss.
func _colossi() -> void:
	# The sun stone.
	var disc := CylinderMesh.new()
	disc.top_radius = SUN_STONE.x
	disc.bottom_radius = SUN_STONE.x
	disc.height = SUN_STONE.y
	disc.radial_segments = 72
	var look := ShaderMaterial.new()
	look.shader = COLOSSUS
	look.render_priority = -9
	look.set_shader_parameter(&"rings", SetKit.painted([RINGS_SHEET], SetKit.ATLAS_DIR, true))
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	look.set_shader_parameter(&"radius", SUN_STONE.x)
	look.set_shader_parameter(&"half_thick", SUN_STONE.y / 2.0)
	look.set_shader_parameter(&"light_at", eclipse.global_position if eclipse != null else bounds.get_center() + Vector3.UP * 300.0)
	var stone := MeshInstance3D.new()
	stone.name = "sun_stone"
	stone.mesh = disc
	stone.material_override = look
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stone.extra_cull_margin = SUN_STONE.x * 2.0
	add_child(stone)
	stone.position = _out_in_the_deep(SUN_STONE_AT)
	stone.rotation = Vector3(1.15, 0.4, 0.25)
	stone.set_meta("turn", Vector3(0.0, 0.012, 0.0))
	colossi.append(stone)
	# The city hanging upside down.
	if ResourceLoader.exists(KIT):
		var kit := SetKit.kit(KIT)
		var city := Node3D.new()
		city.name = "hanging_city"
		add_child(city)
		city.position = _out_in_the_deep(CITY_AT)
		city.rotation = Vector3(0.0, 0.3, PI)
		var plan := [["arch", Vector3(0, 0, 0)], ["doorway", Vector3(30, 4, -10)], ["stairs", Vector3(-28, 0, 12)],
			["bell", Vector3(8, 22, 26)], ["lamp_post", Vector3(-12, 0, -30)], ["stall_frame", Vector3(40, -2, 28)],
			["tile_slab", Vector3(0, -6, 0)], ["arch", Vector3(-40, 6, -6)], ["doorway", Vector3(16, 0, 40)]]
		for k in plan.size():
			if not kit.has(plan[k][0]):
				continue
			var piece := MeshInstance3D.new()
			piece.name = "city_" + plan[k][0]
			piece.mesh = kit[plan[k][0]]
			piece.material_override = _far_ink(k * 1.3)
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.extra_cull_margin = 40.0
			city.add_child(piece)
			piece.position = plan[k][1]
			piece.rotation.y = k * 0.7
			piece.scale = Vector3.ONE * CITY_SCALE * (0.8 + 0.1 * (k % 4))
		city.set_meta("turn", Vector3(0.0, 0.006, 0.0))
		colossi.append(city)
	# The stair down into the abyss.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := BoxMesh.new()
	step.size = Vector3(9.0, 1.4, 3.2)
	for k in STAIR_STEPS:
		var a := k * 0.16
		var place := Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * STAIR_ROUND, -k * STAIR_DROP, sin(a) * STAIR_ROUND))
		tool.append_from(step, 0, place)
	var stair := MeshInstance3D.new()
	stair.name = "abyss_stair"
	stair.mesh = tool.commit()
	stair.material_override = _far_ink(7.7)
	stair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stair.extra_cull_margin = 200.0
	add_child(stair)
	stair.position = _out_in_the_deep(STAIR_AT)
	stair.set_meta("turn", Vector3(0.0, -0.01, 0.0))
	colossi.append(stair)


## The ink of what is far out in the deep: lost far more slowly into its haze, drawn behind all that is near.
func _far_ink(seed: float) -> ShaderMaterial:
	var look := ShaderMaterial.new()
	look.shader = INK
	look.render_priority = -9
	look.set_shader_parameter(&"noise", Vfx.noise_3d())
	look.set_shader_parameter(&"flicker_seed", seed)
	look.set_shader_parameter(&"glow", 0.7)
	look.set_shader_parameter(&"haze_near", 120.0)
	look.set_shader_parameter(&"haze_far", 520.0)
	return look


## The rivers of the dead, flowing toward the market: the first under the way itself, following it, the others far
## out over and beside the passage, each a ribbon of slow lights (astral_river.gdshader).
func _rivers() -> void:
	if way.is_empty():
		return
	var main: PackedVector3Array = way[0]
	# (Its line from the far end to the market's mouth, a little beyond each.)
	var line := PackedVector3Array(main)
	if line[0].distance_to(_mouth) < line[line.size() - 1].distance_to(_mouth):
		line.reverse()
	var floor_y := bounds.position.y
	for k in RIVERS.size():
		var spec: Array = RIVERS[k]
		var points := PackedVector3Array()
		var count := 160
		for i in count + 1:
			var s := float(i) / count
			var at: Vector3
			if k == 0:
				at = _along(line, s, RIVER_BEYOND)
			else:
				at = Vector3(lerpf(bounds.position.x, bounds.end.x, s * 0.6 + 0.2), 0.0,
					lerpf(bounds.position.z - RIVER_BEYOND, bounds.end.z + RIVER_BEYOND, s if mouth_end > 0 else 1.0 - s))
			at.x += float(spec[1]) + float(spec[4]) * sin(s * TAU * 1.3 + k)
			at.y = floor_y + float(spec[0]) + 0.6 * sin(s * TAU * 0.8 + k * 2.0)
			points.append(at)
		var river := MeshInstance3D.new()
		river.name = "river"
		river.mesh = _ribbon(points, float(spec[2]), float(spec[3]))
		var look := ShaderMaterial.new()
		look.shader = RIVER
		look.render_priority = -8
		look.set_shader_parameter(&"span", _length(points))
		look.set_shader_parameter(&"width", float(spec[2]))
		look.set_shader_parameter(&"noise", Vfx.noise_3d())
		look.set_shader_parameter(&"strength", 1.0 if k == 0 else 0.7)
		river.material_override = look
		river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		river.extra_cull_margin = 4.0
		river.set_meta("path", points)
		add_child(river)
		rivers.append(river)


## The point `s` (0..1) along `line`, run on `beyond` m past each of its ends.
func _along(line: PackedVector3Array, s: float, beyond: float) -> Vector3:
	var total := _length(line) + beyond * 2.0
	var at := s * total - beyond
	if at <= 0.0:
		return line[0] + (line[0] - line[1]).normalized() * -at
	for i in line.size() - 1:
		var piece := line[i].distance_to(line[i + 1])
		if at <= piece:
			return line[i].lerp(line[i + 1], at / piece)
		at -= piece
	var last := line.size() - 1
	return line[last] + (line[last] - line[last - 1]).normalized() * at


func _length(line: PackedVector3Array) -> float:
	var total := 0.0
	for i in line.size() - 1:
		total += line[i].distance_to(line[i + 1])
	return total


## A ribbon `width` wide along `points` (UV.x along it, UV.y across), lying flat, turned `tilt` about its flow.
func _ribbon(points: PackedVector3Array, width: float, tilt: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total := _length(points)
	var run := 0.0
	var edges := []
	for i in points.size():
		var ahead := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var across := ahead.cross(Vector3.UP).normalized().rotated(ahead, tilt) * width / 2.0
		if i > 0:
			run += points[i].distance_to(points[i - 1])
		edges.append([points[i] - across, points[i] + across, run / total])
	for i in edges.size() - 1:
		var a: Array = edges[i]
		var b: Array = edges[i + 1]
		for v in [[a[0], a[2], 0.0], [a[1], a[2], 1.0], [b[1], b[2], 1.0], [a[0], a[2], 0.0], [b[1], b[2], 1.0], [b[0], b[2], 0.0]]:
			tool.set_uv(Vector2(v[1], v[2]))
			tool.add_vertex(v[0])
	return tool.commit()


## The glyph constellations along the passage, out west, east and overhead in turn, in order from its far end to the
## market's mouth: the glyph's stroke ends and every third point a star, threads along its strokes.
func _constellations() -> void:
	if not FileAccess.file_exists(CONSTELLATIONS_FILE):
		return
	var glyphs: Array = JSON.parse_string(FileAccess.get_file_as_string(CONSTELLATIONS_FILE))
	var middle := bounds.get_center()
	var far_z := bounds.position.z if mouth_end > 0 else bounds.end.z
	for k in glyphs.size():
		var group := Node3D.new()
		group.name = "constellation"
		add_child(group)
		var z := far_z + float(mouth_end) * (k + 0.5) / glyphs.size() * _span
		var at: Vector3
		var up := Vector3.UP
		match k % 3:
			0:
				at = Vector3(bounds.position.x - CONSTELLATION_OUT, middle.y + 5.0, z)
			1:
				at = Vector3(bounds.end.x + CONSTELLATION_OUT, middle.y + 6.0, z)
			_:
				at = Vector3(middle.x, bounds.end.y + CONSTELLATION_OUT * 0.8, z)
				up = Vector3(0.0, 0.0, float(mouth_end))
		group.position = at
		group.look_at(Vector3(middle.x, middle.y, z), up)
		var star_look := ShaderMaterial.new()
		star_look.shader = STAR
		star_look.render_priority = -8
		var thread_look := star_look.duplicate() as ShaderMaterial
		thread_look.set_shader_parameter(&"star", false)
		var n := 0
		var m := 0
		var placed := {}
		for stroke: Array in glyphs[k]:
			var points := []
			for p: Array in stroke:
				points.append(Vector3((float(p[0]) - 0.5) * CONSTELLATION_SIZE, (0.5 - float(p[1])) * CONSTELLATION_SIZE, 0.0))
			for i in points.size():
				var key := Vector2i(roundi(points[i].x * 20.0), roundi(points[i].y * 20.0))
				if (i == 0 or i == points.size() - 1 or i % 3 == 0) and not placed.has(key):
					placed[key] = true
					var star := _flat(star_look, Vector2(3.2, 3.2) * (1.3 if i == 0 else 1.0))
					star.name = "star%d" % n
					group.add_child(star)
					star.position = points[i]
					star.set_instance_shader_parameter(&"seed", k * 3.1 + n * 0.73)
					n += 1
				if i > 0:
					var from: Vector3 = points[i - 1]
					var to: Vector3 = points[i]
					var thread := _flat(thread_look, Vector2(from.distance_to(to), 0.4))
					thread.name = "thread%d" % m
					group.add_child(thread)
					thread.position = (from + to) / 2.0
					thread.rotation.z = atan2(to.y - from.y, to.x - from.x)
					thread.set_instance_shader_parameter(&"seed", k * 3.1 + m * 0.41)
					m += 1
		group.set_meta("looks", [star_look, thread_look])
		group.set_meta("lit", 0.0)
		constellations.append(group)


func _flat(look: Material, size: Vector2) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var piece := MeshInstance3D.new()
	piece.mesh = quad
	piece.material_override = look
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return piece


## The constellation beside the walker lit, the rest fading: by how far along the passage toward the market they are.
func _light_constellations(at: Vector3, delta: float) -> void:
	if constellations.is_empty():
		return
	lit_constellation = -1
	if inside:
		var far_z := bounds.position.z if mouth_end > 0 else bounds.end.z
		var share := clampf((at.z - far_z) * float(mouth_end) / _span, 0.0, 0.999)
		lit_constellation = int(share * constellations.size())
	for k in constellations.size():
		var group := constellations[k]
		var was := float(group.get_meta("lit"))
		var lit := move_toward(was, 1.0 if k == lit_constellation else 0.0, LIT_EASE * delta)
		# Its lighting a moment: a flare through its stars as it starts.
		var flare := float(group.get_meta("flare", 0.0))
		flare = 1.0 if was == 0.0 and lit > 0.0 else move_toward(flare, 0.0, FLARE_FADE * delta)
		group.set_meta("lit", lit)
		group.set_meta("flare", flare)
		for look: ShaderMaterial in group.get_meta("looks"):
			look.set_shader_parameter(&"lit", lit)
			look.set_shader_parameter(&"flare", flare)


## How far along the passage `at` is (a share from its far end toward the market's mouth).
func _share(at: Vector3) -> float:
	var far_z := bounds.position.z if mouth_end > 0 else bounds.end.z
	return clampf((at.z - far_z) * float(mouth_end) / _span, 0.0, 1.0)


## The glimpses from spot to spot, each forming out of the dark only near its spot and going back to it after: the
## way echoed upside down overhead, a band of starry eyes opening across the deep (the codices' night), a great door
## standing far off in the deep ahead, lit from within.
func _glimpses() -> void:
	for spec: Array in GLIMPSES:
		var glimpse := Node3D.new()
		glimpse.name = spec[0]
		glimpse.set_meta("at", spec[1])
		glimpse.set_meta("shown", 0.0)
		add_child(glimpse)
		var looks := []
		match String(spec[0]):
			"echo":
				# The stones of the way upside down over it, their chequered tops toward the walker (drawn in the void:
				# astral_arch.gdshader, its chequer and no glyphs).
				var floor_y := bounds.position.y
				for stone in stones:
					var echo := MeshInstance3D.new()
					echo.mesh = stone.mesh
					var look := ShaderMaterial.new()
					look.shader = ARCH
					look.render_priority = -6
					look.set_shader_parameter(&"noise", Vfx.noise_3d())
					look.set_shader_parameter(&"glyphs", false)
					look.set_shader_parameter(&"chequer", true)
					look.set_shader_parameter(&"place", fposmod(stone.position.z * 0.37, 1.0))
					look.set_shader_parameter(&"gate_at", stone.position + Vector3.UP * (ECHO_UP * 2.0))
					echo.material_override = look
					echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					glimpse.add_child(echo)
					echo.transform = stone.transform
					echo.position.y = floor_y + ECHO_UP + (floor_y - stone.position.y)
					echo.rotation.z += PI
					looks.append(look)
			"star_skirt":
				var span := deg_to_rad(SKIRT_SPAN)
				for k in SKIRT_EYES:
					var a := -span / 2.0 + span * k / (SKIRT_EYES - 1)
					var look := ShaderMaterial.new()
					look.shader = EYE
					look.render_priority = -8
					look.set_shader_parameter(&"seed", k * 0.173)
					look.set_shader_parameter(&"noise", Vfx.noise_3d())
					var quad := QuadMesh.new()
					quad.size = Vector2(1.6, 0.8) * (4.0 + 2.0 * fposmod(k * 0.61, 1.0))
					var eye := MeshInstance3D.new()
					eye.name = "star_eye"
					eye.mesh = quad
					eye.material_override = look
					eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					glimpse.add_child(eye)
					# (Across the deep overhead from side to side, an arch of them, a little scattered.)
					var wobble := Vector3(sin(k * 1.9), cos(k * 2.7), sin(k * 0.8)) * 6.0
					eye.position = bounds.get_center() + Vector3(sin(a) * SKIRT_FAR, cos(a) * SKIRT_FAR * 0.7, 0.0) + wobble
					looks.append(look)
			"great_door":
				if ResourceLoader.exists(KIT):
					var kit := SetKit.kit(KIT)
					var door := MeshInstance3D.new()
					door.mesh = kit["doorway"]
					var look := _far_ink(3.3)
					look.render_priority = -7
					door.material_override = look
					door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					door.extra_cull_margin = 60.0
					glimpse.add_child(door)
					door.position = _out_in_the_deep(DOOR_AT)
					door.scale = Vector3.ONE * DOOR_SCALE
					door.look_at(bounds.get_center(), Vector3.UP)
					looks.append(look)
					# Its light spilling out of it (drawn over its leaf: a glow, soft at its edges).
					var glow := ShaderMaterial.new()
					glow.shader = STAR
					glow.render_priority = -6
					var light := _flat(glow, Vector2(1.0, 1.0) * DOOR_SCALE * 1.2)
					glimpse.add_child(light)
					light.position = door.position + Vector3.UP * DOOR_SCALE * 0.9
					glimpse.set_meta("light", glow)
		glimpse.set_meta("looks", looks)
		glimpses.append(glimpse)
	_show_glimpses(Vector3.INF, 0.0)


## Each glimpse forming near its spot and going away from it.
func _show_glimpses(at: Vector3, delta: float) -> void:
	var share := _share(at) if inside and at != Vector3.INF else -1.0
	for glimpse in glimpses:
		var near := share >= 0.0 and absf(share - float(glimpse.get_meta("at"))) < GLIMPSE_NEAR
		var shown := move_toward(float(glimpse.get_meta("shown")), 1.0 if near else 0.0, GLIMPSE_EASE * delta)
		glimpse.set_meta("shown", shown)
		glimpse.visible = shown > 0.0
		var eased := smoothstep(0.0, 1.0, shown)
		for look: ShaderMaterial in glimpse.get_meta("looks"):
			look.set_shader_parameter(&"shown", eased)
		if glimpse.has_meta("light"):
			(glimpse.get_meta("light") as ShaderMaterial).set_shader_parameter(&"lit", eased)


## The veils across the way.
func _veils() -> void:
	for t: float in VEILS_AT:
		var look := ShaderMaterial.new()
		look.shader = VEIL
		look.set_shader_parameter(&"noise", Vfx.noise_3d())
		look.set_shader_parameter(&"strength", grown(t))
		var quad := QuadMesh.new()
		quad.size = Vector2(bounds.size.x - 0.3, bounds.size.y - 0.1)
		var veil := MeshInstance3D.new()
		veil.name = "veil"
		veil.mesh = quad
		veil.set_surface_override_material(0, look)
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(veil)
		veil.position = _mouth + _away * t * _span + Vector3(0.0, (bounds.size.y - 0.1) / 2.0, 0.0)
		veils.append(veil)


## The motes, drifting toward the market.
func _motes() -> void:
	motes = GPUParticles3D.new()
	motes.name = "motes"
	motes.amount = MOTES
	motes.lifetime = MOTE_LIFE
	motes.preprocess = MOTE_LIFE
	motes.layers = Layers.FX
	motes.visibility_aabb = AABB(-bounds.size / 2.0 - Vector3.ONE, bounds.size + Vector3.ONE * 2.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(bounds.size.x / 2.0 - 0.4, bounds.size.y / 2.0 - 0.4, _span / 2.0)
	process.direction = -_away
	process.spread = 25.0
	process.initial_velocity_min = MOTE_PACE.x
	process.initial_velocity_max = MOTE_PACE.y
	process.gravity = Vector3.ZERO
	process.scale_min = 0.5
	process.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	fade.add_point(0.2, Color(0.8, 0.88, 1.0, 1.0))
	fade.add_point(0.8, Color(0.8, 0.88, 1.0, 1.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	motes.process_material = process
	motes.draw_pass_1 = _glow_quad(0.045)
	add_child(motes)
	motes.position = bounds.get_center()
