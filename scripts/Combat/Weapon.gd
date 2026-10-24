extends Resource
## Weapon Resource with melee, bow, gun, noise, and mesh tuning.
## Times are seconds, reach is metres, arc_degrees is degrees, noise is dB.
## find() shares cached sword/dagger/bow/revolver resources; builders create new ones.

enum Kind {
	MELEE,
	BOW,
	GUN,
}

@export var id: StringName = &"sword"
@export var display_name := "sword"
@export var kind := Kind.MELEE

@export_group("Melee")
@export var damage := 34.0
## A fully charged attack.
@export var power_damage := 70.0
## Seconds of holding before the attack counts as charged.
@export var charge_time := 0.55
@export var reach := 2.1
## Width of a side slash, in degrees.
@export var arc_degrees := 90.0
@export var windup := 0.14
## How long the blade is actually cutting.
@export var strike_time := 0.22
@export var recovery := 0.28
@export var can_block := true
## Dagger: an unaware target struck from behind dies outright.
@export var backstab_kills := false
## Any weapon: damage multiplier on an unaware target struck from behind.
@export var sneak_multiplier := 2.0

@export_group("Bow")
@export var draw_time := 0.9
@export var arrow_speed_min := 14.0
@export var arrow_speed_max := 48.0
@export var arrow_damage_min := 15.0
@export var arrow_damage_max := 70.0
@export var headshot_multiplier := 2.5

@export_group("Gun")
## The cylinder's chambers and the shot barrel's shells (a LeMat: one).
@export var rounds := 6
@export var shells := 1
@export var bullet_damage := 55.0
## The shot barrel: pellets in a cone `spread_degrees` wide, each falling
## off from full at `falloff_start` to nothing at `falloff_end` (metres).
@export var pellets := 9
@export var pellet_damage := 18.0
@export var spread_degrees := 8.0
@export var falloff_start := 3.0
@export var falloff_end := 12.0
## Most of a shell into one man this close: a blast, not pellets.
@export var blast_range := 2.0
## Seconds from a shot until the next is ready: in one hand, in both.
@export var ready_one_hand := 0.6
@export var ready_braced := 0.35
## Seconds per round through the gate, for the shell, to open or shut the gate.
@export var round_load := 0.45
@export var shell_load := 1.1
@export var gate_time := 0.25
@export var shot_db := 70.0
@export var shell_db := 74.0
## Seconds to take the gun in both hands, or let one go.
@export var grip_change := 0.4

@export_group("Noise")
@export var swing_db := 38.0
@export var hit_db := 52.0

var mesh: Mesh = null


# The armoury

static var _armoury := {}


## Returns the shared cached sword/dagger/bow Resource, or null for an unknown ID.
static func find(weapon_id: StringName) -> Resource:
	if _armoury.is_empty():
		for weapon in [sword(), dagger(), bow(), revolver()]:
			_armoury[weapon.id] = weapon

	return _armoury.get(weapon_id)


static func _new() -> Resource:
	return (load("res://scripts/Combat/Weapon.gd") as GDScript).new()


static func sword() -> Resource:
	var w := _new()
	w.id = &"sword"
	w.display_name = "sword"
	w.mesh = sword_mesh()
	return w


static func dagger() -> Resource:
	var w := _new()
	w.id = &"dagger"
	w.display_name = "dagger"
	w.damage = 22.0
	w.power_damage = 44.0
	w.charge_time = 0.4
	w.reach = 1.5
	w.arc_degrees = 60.0
	w.windup = 0.08
	w.strike_time = 0.15
	w.recovery = 0.2
	w.can_block = false
	w.backstab_kills = true
	w.swing_db = 30.0
	w.hit_db = 44.0
	w.mesh = dagger_mesh()
	return w


static func bow() -> Resource:
	var w := _new()
	w.id = &"bow"
	w.display_name = "bow"
	w.kind = Kind.BOW
	w.can_block = false
	w.swing_db = 30.0
	w.mesh = bow_mesh()
	return w


## The Prosecutor's revolver: a LeMat built up to a heavy man's gun, six
## big rounds round a shot barrel of one shell.
static func revolver() -> Resource:
	var w := _new()
	w.id = &"revolver"
	w.display_name = "revolver"
	w.kind = Kind.GUN
	w.can_block = false
	w.headshot_multiplier = 2.5
	w.swing_db = 30.0
	w.mesh = revolver_mesh()
	return w


# Meshes, with the grip at the origin so the hand pivots them there: the
# models from assets/weapons (made in Blender, source/weapons.blend), blade
# up +Y, or blocks of the same shape if a model is missing.

const MODELS := "res://assets/weapons/%s.glb"

static var _models := {}


## Returns a shared imported Mesh or null if its file/mesh is missing; caches null misses.
static func model(file: StringName) -> Mesh:
	if _models.has(file):
		return _models[file]

	var mesh: Mesh = null
	var path := MODELS % file

	if ResourceLoader.exists(path):
		var scene := (load(path) as PackedScene).instantiate()
		var found := scene.find_children("*", "MeshInstance3D", true, false)

		if not found.is_empty():
			mesh = (found[0] as MeshInstance3D).mesh

		scene.free()

	_models[file] = mesh
	return mesh


## Clears imported-model and arrow caches; does not clear the weapon armoury.
static func forget_models() -> void:
	_models.clear()
	_arrow = null

static func _material(color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


## One surface per part, so each keeps its own material.
static func _assemble(parts: Array) -> ArrayMesh:
	var result := ArrayMesh.new()

	for part in parts:
		var primitive: PrimitiveMesh = part[0]
		var xform: Transform3D = part[1]
		var arrays := primitive.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

		for i in range(vertices.size()):
			vertices[i] = xform * vertices[i]
			normals[i] = (xform.basis * normals[i]).normalized()

		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(result.get_surface_count() - 1, part[2])

	return result


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func sword_mesh() -> Mesh:
	var mesh := model(&"sword")

	if mesh == null:
		var steel := _material(Color(0.72, 0.74, 0.78), 0.55, 0.32)
		var brass := _material(Color(0.7, 0.55, 0.25), 0.6, 0.4)
		var leather := _material(Color(0.22, 0.14, 0.09))
		mesh = _assemble([
			[_box(Vector3(0.045, 0.78, 0.008)), Transform3D(Basis.IDENTITY, Vector3(0, 0.47, 0)), steel],
			[_box(Vector3(0.17, 0.024, 0.03)), Transform3D(Basis.IDENTITY, Vector3(0, 0.075, 0)), brass],
			[_box(Vector3(0.028, 0.14, 0.028)), Transform3D(Basis.IDENTITY, Vector3.ZERO), leather],
			[_box(Vector3(0.04, 0.035, 0.04)), Transform3D(Basis.IDENTITY, Vector3(0, -0.085, 0)), brass],
		])

	mesh.set_meta(&"hold_scale", 0.62)
	mesh.set_meta(&"hold_rotation", Vector3(-0.55, 0.15, 0.25))
	# How it is held in your view (ViewPoses.gd).
	mesh.set_meta(&"view_poses", &"sword")
	# Where the edge runs, for trails and glints: just above the guard to the tip.
	mesh.set_meta(&"blade_base", Vector3(0, 0.1, 0))
	mesh.set_meta(&"blade_tip", Vector3(0, 0.84, 0))
	return mesh


## The revolver: the grip at the origin, its handle along Y, the barrels
## forward along -Z above the hand, the shot barrel under the cylinder's.
## The cylinder, hammer and loading gate are their own meshes (metas), so the
## hand can turn and move them. A stand-in of blocks until the model is made.
static func revolver_mesh() -> Mesh:
	var mesh := model(&"revolver")
	var iron := _material(Color(0.2, 0.2, 0.22), 0.75, 0.4)
	var worn := _material(Color(0.42, 0.4, 0.38), 0.7, 0.3)
	var walnut := _material(Color(0.3, 0.17, 0.09))

	if mesh == null:
		mesh = _assemble([
			# The handle, raked back, under the frame.
			[_box(Vector3(0.034, 0.12, 0.042)), Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, -0.005, 0.012)), walnut],
			# The frame over the hand, the trigger guard under it.
			[_box(Vector3(0.036, 0.045, 0.11)), Transform3D(Basis.IDENTITY, Vector3(0, 0.075, -0.035)), iron],
			[_box(Vector3(0.012, 0.03, 0.05)), Transform3D(Basis.IDENTITY, Vector3(0, 0.04, -0.04)), iron],
			# The long barrel, and the fat shot barrel under it.
			[_box(Vector3(0.026, 0.026, 0.24)), Transform3D(Basis.IDENTITY, Vector3(0, 0.1, -0.2)), iron],
			[_box(Vector3(0.03, 0.03, 0.17)), Transform3D(Basis.IDENTITY, Vector3(0, 0.072, -0.165)), worn],
		])

	mesh.set_meta(&"hold_scale", 0.62)
	mesh.set_meta(&"hold_rotation", Vector3(0.0, 0.0, 0.0))
	mesh.set_meta(&"view_poses", &"revolver")
	# Heavy: slow to draw and to put away, lagging further behind a turn (to
	# at most 4 degrees: the hand's sway turns the gun 0.6 of itself).
	mesh.set_meta(&"draw_time", 0.45)
	mesh.set_meta(&"stow_time", 0.35)
	mesh.set_meta(&"sway_lag", 2.2)
	mesh.set_meta(&"sway_most", deg_to_rad(4.0) / 0.6)
	mesh.set_meta(&"muzzle", Vector3(0, 0.1, -0.32))
	mesh.set_meta(&"shot_muzzle", Vector3(0, 0.072, -0.25))

	if not mesh.has_meta(&"cylinder_mesh"):
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.026
		cylinder.bottom_radius = 0.026
		cylinder.height = 0.05
		cylinder.radial_segments = 6
		cylinder.rings = 1
		cylinder.material = worn
		mesh.set_meta(&"cylinder_mesh", cylinder)
		# Its axis along the barrel: the mesh's Y turned onto Z.
		mesh.set_meta(&"cylinder_at", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.088, -0.065)))
		mesh.set_meta(&"hammer_mesh", _assemble([[_box(Vector3(0.01, 0.03, 0.014)), Transform3D.IDENTITY, iron]]))
		mesh.set_meta(&"hammer_at", Transform3D(Basis.IDENTITY, Vector3(0, 0.11, 0.012)))
		mesh.set_meta(&"gate_mesh", _assemble([[_box(Vector3(0.006, 0.022, 0.016)), Transform3D.IDENTITY, iron]]))
		mesh.set_meta(&"gate_at", Transform3D(Basis.IDENTITY, Vector3(0.021, 0.088, -0.045)))

	return mesh


## The tome, open: its spine at the origin along Y, the boards out to either
## side, pages toward you (+Z). A stand-in of blocks until the model is made.
static func tome_mesh() -> Mesh:
	var mesh := model(&"tome")

	if mesh == null:
		var board := _material(Color(0.24, 0.1, 0.08))
		var paper := _material(Color(0.82, 0.76, 0.62))
		mesh = _assemble([
			[_box(Vector3(0.13, 0.2, 0.012)), Transform3D(Basis(Vector3.UP, 0.18), Vector3(-0.065, 0, -0.01)), board],
			[_box(Vector3(0.13, 0.2, 0.012)), Transform3D(Basis(Vector3.UP, -0.18), Vector3(0.065, 0, -0.01)), board],
			[_box(Vector3(0.12, 0.19, 0.02)), Transform3D(Basis(Vector3.UP, 0.18), Vector3(-0.062, 0, 0.004)), paper],
			[_box(Vector3(0.12, 0.19, 0.02)), Transform3D(Basis(Vector3.UP, -0.18), Vector3(0.062, 0, 0.004)), paper],
		])

	return mesh


## What a guard of each kind carries.
static func guard_weapon_mesh(kind: StringName) -> Mesh:
	match kind:
		&"rapier":
			return rapier_mesh()
		&"maul":
			return maul_mesh()
		&"bow":
			return bow_mesh()
		&"crossbow":
			return crossbow_mesh()

	return sword_mesh()


## The guards' crossbow: grip at the origin, the stock forward along -Z.
static func crossbow_mesh() -> Mesh:
	var mesh := model(&"crossbow")

	if mesh == null:
		var wood := _material(Color(0.42, 0.28, 0.15))
		var steel := _material(Color(0.6, 0.6, 0.64), 0.7, 0.4)
		mesh = _assemble([
			[_box(Vector3(0.05, 0.08, 0.62)), Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.07)), wood],
			[_box(Vector3(0.54, 0.02, 0.03)), Transform3D(Basis.IDENTITY, Vector3(0, 0.085, -0.32)), steel],
			[_box(Vector3(0.035, 0.12, 0.04)), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0.0)), wood],
		])

	return mesh


## The duelist's: long, thin and quick, with a cupped guard.
static func rapier_mesh() -> Mesh:
	var mesh := model(&"rapier")

	if mesh == null:
		var steel := _material(Color(0.8, 0.82, 0.86), 0.6, 0.25)
		var gold := _material(Color(0.75, 0.6, 0.3), 0.6, 0.35)
		var leather := _material(Color(0.12, 0.08, 0.06))
		mesh = _assemble([
			[_box(Vector3(0.018, 0.98, 0.008)), Transform3D(Basis.IDENTITY, Vector3(0, 0.58, 0)), steel],
			[_box(Vector3(0.1, 0.05, 0.08)), Transform3D(Basis.IDENTITY, Vector3(0, 0.07, 0)), gold],
			[_box(Vector3(0.24, 0.012, 0.012)), Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), gold],
			[_box(Vector3(0.026, 0.13, 0.026)), Transform3D(Basis.IDENTITY, Vector3.ZERO), leather],
		])

	mesh.set_meta(&"blade_base", Vector3(0, 0.11, 0))
	mesh.set_meta(&"blade_tip", Vector3(0, 1.07, 0))
	return mesh


## The brute's: a long haft and a head of iron.
static func maul_mesh() -> Mesh:
	var mesh := model(&"maul")

	if mesh == null:
		var iron := _material(Color(0.3, 0.3, 0.32), 0.7, 0.5)
		var wood := _material(Color(0.32, 0.22, 0.13))
		mesh = _assemble([
			[_box(Vector3(0.05, 1.05, 0.05)), Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)), wood],
			[_box(Vector3(0.36, 0.2, 0.2)), Transform3D(Basis.IDENTITY, Vector3(0, 0.88, 0)), iron],
			[_box(Vector3(0.07, 0.07, 0.07)), Transform3D(Basis.IDENTITY, Vector3(0, -0.17, 0)), iron],
		])

	# The head is what smears the air.
	mesh.set_meta(&"blade_base", Vector3(0, 0.74, 0))
	mesh.set_meta(&"blade_tip", Vector3(0, 1.0, 0))
	return mesh


static func dagger_mesh() -> Mesh:
	var mesh := model(&"dagger")

	if mesh == null:
		var steel := _material(Color(0.7, 0.72, 0.76), 0.55, 0.32)
		var leather := _material(Color(0.2, 0.13, 0.08))
		mesh = _assemble([
			[_box(Vector3(0.035, 0.26, 0.006)), Transform3D(Basis.IDENTITY, Vector3(0, 0.19, 0)), steel],
			[_box(Vector3(0.08, 0.018, 0.022)), Transform3D(Basis.IDENTITY, Vector3(0, 0.055, 0)), steel],
			[_box(Vector3(0.024, 0.11, 0.024)), Transform3D(Basis.IDENTITY, Vector3.ZERO), leather],
		])

	mesh.set_meta(&"hold_scale", 0.8)
	mesh.set_meta(&"hold_rotation", Vector3(-0.9, 0.2, 0.3))
	mesh.set_meta(&"view_poses", &"dagger")
	mesh.set_meta(&"blade_base", Vector3(0, 0.07, 0))
	mesh.set_meta(&"blade_tip", Vector3(0, 0.31, 0))
	# A small blade: its draw and sheath ring higher.
	mesh.set_meta(&"voice", 1.25)
	return mesh


static func bow_mesh() -> Mesh:
	var mesh := model(&"bow")

	if mesh == null:
		var wood := _material(Color(0.42, 0.28, 0.15))
		var cord := _material(Color(0.85, 0.82, 0.72))
		var limb := 0.52
		mesh = _assemble([
			[_box(Vector3(0.03, 0.14, 0.035)), Transform3D(Basis.IDENTITY, Vector3.ZERO), wood],
			[_box(Vector3(0.022, limb, 0.028)), Transform3D(Basis(Vector3.RIGHT, 0.32), Vector3(0, 0.3, 0.07)), wood],
			[_box(Vector3(0.022, limb, 0.028)), Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0, -0.3, 0.07)), wood],
			[_box(Vector3(0.004, 1.06, 0.004)), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.16)), cord],
		])

	mesh.set_meta(&"hold_scale", 0.55)
	mesh.set_meta(&"hold_rotation", Vector3(0.0, 0.0, 0.1))
	mesh.set_meta(&"view_poses", &"bow")
	# Off the back and over the shoulder, and back again.
	mesh.set_meta(&"draw_sound", &"bow_out")
	mesh.set_meta(&"stow_sound", &"bow_away")
	return mesh


static var _arrow: Mesh = null


## The arrow, built once and shared: nocked, flying, stuck in a guard.
static func arrow_mesh() -> Mesh:
	if _arrow == null:
		_arrow = model(&"arrow")

		if _arrow == null:
			_arrow = _build_arrow()

		_arrow.set_meta(&"hold_scale", 0.6)

	return _arrow


static func _build_arrow() -> Mesh:
	var wood := _material(Color(0.55, 0.42, 0.25))
	var steel := _material(Color(0.5, 0.5, 0.55), 0.8, 0.4)
	var fletch := _material(Color(0.75, 0.72, 0.65))
	# Pointing along -Z, the way a node looks.
	var mesh := _assemble([
		[_box(Vector3(0.008, 0.008, 0.7)), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), wood],
		[_box(Vector3(0.018, 0.018, 0.05)), Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.37)), steel],
		[_box(Vector3(0.002, 0.03, 0.09)), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3)), fletch],
		[_box(Vector3(0.03, 0.002, 0.09)), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3)), fletch],
	])
	mesh.set_meta(&"hold_scale", 0.6)
	return mesh
