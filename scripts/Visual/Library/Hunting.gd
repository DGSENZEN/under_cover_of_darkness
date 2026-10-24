extends Node3D
## Monster hunting's projection (docs/superpowers/specs/2026-10-17-librarian-shop-design.md: "the creatures he hunts
## rising as spectres ... the weapon for each"): over an opened hunting study, the nahual (the approved model from the
## Underground's bench, tools/eclipse/underground_uncanny.py), small, prowling round a hunter's binding ring of
## iron-red fire on the pages, and above it the librarian's own weapons from his rack (the crossbow, the sword cane,
## the stakes: tools/eclipse/library_corner.py), both drawn black and rimmed in iron-red fire, the weapons circling
## and turned on it;
## now and then the crossbow looses a bolt of fire, and the beast flinches, frays and gathers itself again. The lechuza
## and the chupacabra join it once their own models pass review. Upright in the room, scaled to the room above.

const MeshVfx := preload("res://scripts/Visual/MeshVfx.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const Alchemy := preload("res://scripts/Visual/Library/Alchemy.gd")
const SILHOUETTE := preload("res://scripts/Visual/anima_silhouette.gdshader")
const AURA := preload("res://scripts/Visual/anima_aura.gdshader")

const CORNER_KIT := "res://assets/eclipse/kit/library_corner.glb"
const UNCANNY_KIT := "res://assets/eclipse/kit/underground_uncanny.glb"
const CORE := Color(1.0, 0.86, 0.78)
const IRON := Color("d55b55")
const EDGE := Color(0.25, 0.04, 0.03)
const EMBER := Color("ff5a1e")
## The room it is built for above the pages (m); its middle (from the right-hand page's middle, toward the gutter so
## the weapons' circle stays within the board's run kept clear for the book).
const ROOM := 0.33
const MIDDLE := Vector3(-0.05, 0.0, 0.0)
## The beast: drawn this much of the bench's nahual (its neck where the head hangs), the circle it prowls, how fast.
const BEAST_SCALE := 0.12
const NECK := Vector3(0.88, 0.64, 0.0)
const PROWL := 0.05
const PROWL_RATE := 0.45
## The weapons: each its rack piece, its length here (m), whether its tip is at its long side's negative end.
const WEAPONS := [["crossbow", 0.17, false], ["sword_cane", 0.19, true], ["stakes", 0.13, true]]
const ORBIT := 0.08
const ORBIT_AT := 0.19
## The crossbow's shot: how often, how long the bolt flies, how long the beast takes to gather itself again.
const SHOT_EVERY := 3.6
const FLIGHT := 0.22
const GATHER := 1.4

var kind := &"hunting"
var beast: Node3D
var weapons: Array[Node3D] = []
var ring: MeshInstance3D
## How much of the beast is here (1 whole, frayed lower).
var beast_whole := 1.0
## How many bolts the crossbow has loosed.
var shots := 0

var _seed := 0.0
var _inks: Array[ShaderMaterial] = []
var _spectre: ShaderMaterial
var _ring_look: ShaderMaterial
var _bolt: MeshInstance3D
var _bolt_look: ShaderMaterial
var _tips: Array[Vector3] = []
var _last_shot := -1
var _hit_at := -100.0
var _kits := {}


func build(seed: float) -> void:
	_seed = seed
	name = "hunting"
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false

	_ring_look = MeshVfx.look(CORE, IRON, EDGE, 2.2, 0.0, 0.4, seed)
	_ring_look.set_shader_parameter("tail_eat", 0.0)
	ring = _geometry("binding", _binding(0.07), _ring_look, self)
	ring.position = MIDDLE + Vector3(0.0, 0.004, 0.0)

	# The beast: black, rimmed and outlined in iron-red fire as the other families' spectres are, its eyes embers.
	# (The bench's fraying spectre look, at this size, frayed through and washed pale against the lit pages.)
	var uncanny := _kit(UNCANNY_KIT)
	_spectre = _ink()
	var ember := StandardMaterial3D.new()
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.albedo_color = EMBER
	ember.emission_enabled = true
	ember.emission = EMBER
	ember.emission_energy_multiplier = 4.0
	beast = Node3D.new()
	beast.name = "nahual"
	add_child(beast)
	var body := _kit_part("body", uncanny.get("nahual_body"), _spectre, ember, beast)
	var head := _kit_part("head", uncanny.get("nahual_head"), _spectre, ember, beast)
	var burn := _aura(0.02)
	for part in [body, head]:
		var outline := MeshInstance3D.new()
		outline.name = "outline"
		outline.mesh = part.mesh
		for i in part.mesh.get_surface_count():
			outline.set_surface_override_material(i, burn)
		outline.layers = Layers.FX
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.add_child(outline)
	head.position = NECK
	beast.scale = Vector3.ONE * BEAST_SCALE
	# (Its middle over the circle it prowls: the bench's dog lies from its tail at x 0 to its head past x 1.)
	for part in [body, head]:
		part.position -= Vector3(0.55, 0.0, 0.0)

	# The weapons, each its rack piece moved to its own middle, its long side along -z (where it points).
	var corner := _kit(CORNER_KIT)
	for spec: Array in WEAPONS:
		var pivot := Node3D.new()
		pivot.name = spec[0]
		add_child(pivot)
		var mesh: Mesh = corner.get(spec[0])
		if mesh == null:
			weapons.append(pivot)
			_tips.append(Vector3.FORWARD)
			continue
		var box := mesh.get_aabb()
		var long_axis := Vector3.RIGHT if box.size.x >= maxf(box.size.y, box.size.z) else (Vector3.UP if box.size.y >= box.size.z else Vector3.BACK)
		var length: float = box.size.dot(long_axis)
		var tip: Vector3 = -long_axis if spec[2] else long_axis
		var turn := Basis(Quaternion(tip, Vector3.FORWARD))
		var scale: float = float(spec[1]) / length
		var ink := _ink()
		# (Thin shapes: a tighter rim, or it covers them and they read pale, not black.)
		ink.set_shader_parameter(&"rim_power", 4.5)
		var piece := _geometry("ghost", mesh, ink, pivot)
		piece.transform = Transform3D(turn.scaled(Vector3.ONE * scale), turn * (-box.get_center()) * scale)
		var outline := _geometry("outline", mesh, _aura(0.006 / scale), piece)
		outline.position = Vector3.ZERO
		weapons.append(pivot)
		_tips.append(Vector3.FORWARD * float(spec[1]) * 0.5)

	_bolt_look = MeshVfx.look(CORE, IRON, EDGE, 3.6, 0.0, 1.4, seed + 5.0)
	_bolt_look.set_shader_parameter("tail_eat", 0.6)
	var path := PackedVector3Array()
	for i in 6:
		path.append(Vector3(0.0, 0.0, -0.05 * float(i) / 5.0))
	_bolt = _geometry("bolt", MeshVfx.tendril(path, 0.0035, 6), _bolt_look, self)
	_bolt.visible = false


## Where it stands (the pages' top middle, the book's heading), how present (0 gone to 1), the room above it.
func set_state(presence: float, clearance: float, time: float, at: Vector3, heading: float) -> void:
	visible = presence > 0.001
	if not visible:
		return
	var fit := clampf(clearance / ROOM, 0.4, 1.0) * lerpf(0.7, 1.0, presence)
	global_transform = Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * fit), at)
	_ring_look.set_shader_parameter("opacity", presence)
	_ring_look.set_shader_parameter("erosion", lerpf(0.95, 0.0, presence))
	for look in _inks:
		look.set_shader_parameter("presence", presence)

	# The beast prowls round the binding, facing where it goes; struck, it frays and gathers itself again.
	var round_at := time * PROWL_RATE + _seed
	beast.position = MIDDLE + Vector3(cos(round_at), 0.0, sin(round_at)) * PROWL + Vector3(0.0, 0.006, 0.0)
	beast.rotation = Vector3(0.0, -round_at - PI / 2.0, 0.0)
	var since := time - _hit_at
	beast_whole = 1.0 - 0.7 * (1.0 - smoothstep(0.0, GATHER, since)) if since >= 0.0 else 1.0
	_spectre.set_shader_parameter(&"presence", presence * beast_whole)
	_spectre.set_shader_parameter(&"energy", 3.2 + 4.0 * (1.0 - beast_whole))

	# The weapons circle above it, each turned on it.
	var target: Vector3 = beast.position + Vector3(0.0, 0.035, 0.0)
	for k in weapons.size():
		var a := TAU * float(k) / weapons.size() - time * 0.3 + _seed
		var w := weapons[k]
		w.position = MIDDLE + Vector3(cos(a) * ORBIT, ORBIT_AT + 0.012 * sin(time * 1.1 + k), sin(a) * ORBIT)
		w.basis = Basis.looking_at(target - w.position, Vector3.UP)

	# Now and then the crossbow looses: the bolt flies from its tip to the beast, which is struck as it lands.
	var shot := int(floor((time + _seed) / SHOT_EVERY))
	var flying := fposmod(time + _seed, SHOT_EVERY)
	if shot != _last_shot and flying < FLIGHT:
		_last_shot = shot
		shots += 1
	if flying < FLIGHT:
		var from: Vector3 = weapons[0].position + weapons[0].basis * _tips[0]
		var t := flying / FLIGHT
		_bolt.visible = true
		_bolt.position = from.lerp(target, t)
		_bolt.basis = Basis.looking_at(target - from, Vector3.UP)
		_bolt_look.set_shader_parameter("opacity", presence)
		if t > 0.9 and since > GATHER * 0.5:
			_hit_at = time
	else:
		_bolt.visible = false


## How truly a weapon aims at the beast (1 dead on).
func aim_of(weapon: Node3D) -> float:
	var target: Vector3 = beast.global_position + global_basis * Vector3(0.0, 0.035, 0.0)
	return (-weapon.global_basis.z).normalized().dot((target - weapon.global_position).normalized())


## Every piece it draws (the bolt only while it flies).
func parts() -> Array:
	return find_children("*", "GeometryInstance3D", true, false).filter(func(p): return p != _bolt or _bolt.visible)


## The hunter's binding, lying flat (facing +y), `radius` across: a ring, a cross through it, a smaller ring within.
static func _binding(radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flat := Basis(Vector3.RIGHT, -PI / 2.0)
	var strokes := [Alchemy._ring(radius), Alchemy._ring(radius * 0.55),
		Alchemy._line(Vector2(0.0, -radius * 1.15), Vector2(0.0, radius * 1.15)),
		Alchemy._line(Vector2(-radius * 0.75, radius * 0.3), Vector2(radius * 0.75, radius * 0.3))]
	for path: PackedVector3Array in strokes:
		st.append_from(Alchemy._bar(path, 0.0016), 0, Transform3D(flat, Vector3.ZERO))
	return st.commit()


## A kit's meshes by name (loaded once for this family; held by it, never past it).
func _kit(path: String) -> Dictionary:
	if not _kits.has(path):
		var meshes := {}
		if ResourceLoader.exists(path):
			var scene: Node = (load(path) as PackedScene).instantiate()
			for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
				meshes[String(mesh.name)] = mesh.mesh
			scene.free()
		_kits[path] = meshes
	return _kits[path]


func _kit_part(label: String, mesh: Mesh, look: Material, ember: Material, parent: Node3D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh if mesh != null else SphereMesh.new()
	part.layers = Layers.FX
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in part.mesh.get_surface_count():
		var slot: Material = part.mesh.surface_get_material(i)
		part.set_surface_override_material(i, ember if slot != null and slot.resource_name == "ember" else look)
	parent.add_child(part)
	return part


func _ink() -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = SILHOUETTE
	ink.set_shader_parameter(&"glow", IRON.lerp(CORE, 0.25))
	ink.set_shader_parameter(&"noise", MeshVfx.noise())
	ink.set_shader_parameter(&"seed", _seed + _inks.size())
	ink.set_shader_parameter(&"floor_y", -10.0)
	ink.set_shader_parameter(&"wrist", 0.0001)
	ink.set_shader_parameter(&"rim_power", 2.0)
	_inks.append(ink)
	return ink


## An outline of fire `thickness` out from the shape (in the shape's own metres).
func _aura(thickness: float) -> ShaderMaterial:
	var aura := ShaderMaterial.new()
	aura.shader = AURA
	aura.set_shader_parameter(&"glow", IRON)
	aura.set_shader_parameter(&"noise", MeshVfx.noise())
	aura.set_shader_parameter(&"seed", _seed + _inks.size())
	aura.set_shader_parameter(&"floor_y", -10.0)
	aura.set_shader_parameter(&"wrist", 0.0001)
	aura.set_shader_parameter(&"thickness", thickness)
	aura.set_shader_parameter(&"energy", 3.2)
	_inks.append(aura)
	return aura


func _geometry(label: String, mesh: Mesh, look: Material, parent: Node3D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	for i in mesh.get_surface_count():
		part.set_surface_override_material(i, look)
	part.layers = Layers.FX
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
