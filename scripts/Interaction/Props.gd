extends RefCounted
## Prototype props built in code: doors, chests, loot, keys, crates. Used by
## the interaction gym and the tests, and handy for greyboxing until real
## assets exist. Every builder returns the root node, already added to
## `parent` and placed at `position`.

const DoorScript := preload("res://scripts/Interaction/Door.gd")
const ChestScript := preload("res://scripts/Interaction/Chest.gd")
const LootScript := preload("res://scripts/Interaction/Loot.gd")
const KeyScript := preload("res://scripts/Interaction/KeyItem.gd")
const ToolScript := preload("res://scripts/Interaction/ToolItem.gd")
const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const HazardScript := preload("res://scripts/Combat/Hazard.gd")


static func material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.metallic = metallic
	return m


static func mesh_box(size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material(color)
	visual.mesh = mesh
	return visual


static func shape_box(size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	return shape


## A door hinged on its left edge (looking at its front, which faces -Z).
## `position` is the hinge's foot. The frame around it is up to the level.
static func door(
	parent: Node,
	position: Vector3,
	yaw := 0.0,
	width := 1.0,
	height := 2.1,
	locked := false,
	key_id: StringName = &"",
	door_name := "door"
) -> Node3D:
	var hinge := AnimatableBody3D.new()
	hinge.set_script(DoorScript)
	hinge.locked = locked
	hinge.key_id = key_id
	hinge.door_name = door_name

	var offset := Vector3(width * 0.5, height * 0.5, 0.0)
	var shape := shape_box(Vector3(width, height, 0.08))
	shape.position = offset
	hinge.add_child(shape)

	var visual := mesh_box(Vector3(width, height, 0.08), Color(0.45, 0.3, 0.18))
	visual.position = offset
	hinge.add_child(visual)

	var handle := mesh_box(Vector3(0.05, 0.05, 0.16), Color(0.7, 0.6, 0.3))
	handle.position = offset + Vector3(width * 0.4, 0.0, 0.0)
	hinge.add_child(handle)

	# Placed BEFORE entering the tree: a synced AnimatableBody3D treats a
	# later teleport as a kinematic move and gets stopped by whatever is in
	# the way. Give `parent` an identity transform, or place doors in the editor.
	hinge.position = position
	hinge.rotation.y = yaw
	parent.add_child(hinge)
	return hinge


## A chest whose lid hinges along its back top edge. `position` is the centre
## of the chest's footprint on the floor.
static func chest(
	parent: Node,
	position: Vector3,
	yaw := 0.0,
	size := Vector3(0.9, 0.55, 0.55),
	locked := false,
	key_id: StringName = &"",
	chest_name := "chest"
) -> Node3D:
	var hinge := Node3D.new()
	hinge.set_script(ChestScript)
	hinge.locked = locked
	hinge.key_id = key_id
	hinge.container_name = chest_name

	# Hollow body: floor plus four walls, so loot can sit inside.
	var body := StaticBody3D.new()
	body.name = "Body"
	var wall := 0.04
	var parts := [
		[Vector3(size.x, wall, size.z), Vector3(0.0, -size.y + wall * 0.5, size.z * 0.5)],
		[Vector3(wall, size.y, size.z), Vector3(-size.x * 0.5 + wall * 0.5, -size.y * 0.5, size.z * 0.5)],
		[Vector3(wall, size.y, size.z), Vector3(size.x * 0.5 - wall * 0.5, -size.y * 0.5, size.z * 0.5)],
		[Vector3(size.x, size.y, wall), Vector3(0.0, -size.y * 0.5, wall * 0.5)],
		[Vector3(size.x, size.y, wall), Vector3(0.0, -size.y * 0.5, size.z - wall * 0.5)],
	]

	for part in parts:
		var part_size: Vector3 = part[0]
		var part_position: Vector3 = part[1]
		var shape := shape_box(part_size)
		shape.position = part_position
		body.add_child(shape)
		var visual := mesh_box(part_size, Color(0.4, 0.26, 0.15))
		visual.position = part_position
		body.add_child(visual)

	hinge.add_child(body)

	parent.add_child(hinge)
	# The hinge sits at the back top edge of the chest.
	hinge.global_position = position + Vector3(0.0, size.y, -size.z * 0.5).rotated(Vector3.UP, yaw)
	hinge.rotation.y = yaw
	# Placed (position and turn), not slid there: reset only once it is all set.
	hinge.reset_physics_interpolation()

	# Added after the chest is placed: an AnimatableBody3D takes its physics
	# transform from where it is when it enters the tree.
	var lid := AnimatableBody3D.new()
	lid.name = "Lid"
	var lid_size := Vector3(size.x, 0.05, size.z)
	var lid_shape := shape_box(lid_size)
	lid_shape.position = Vector3(0.0, 0.025, size.z * 0.5)
	lid.add_child(lid_shape)
	var lid_visual := mesh_box(lid_size, Color(0.5, 0.33, 0.2))
	lid_visual.position = lid_shape.position
	lid.add_child(lid_visual)
	hinge.add_child(lid)
	return hinge


static func loot(parent: Node, position: Vector3, value: int, loot_name := "goblet") -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(LootScript)
	body.value = value
	body.loot_name = loot_name
	body.mass = 0.5
	body.add_child(shape_box(Vector3(0.14, 0.18, 0.14)))
	var visual := mesh_box(Vector3(0.14, 0.18, 0.14), Color(0.95, 0.8, 0.3))
	visual.name = "MeshInstance3D"
	body.add_child(visual)
	parent.add_child(body)
	body.global_position = position
	body.reset_physics_interpolation()
	return body


static func key(parent: Node, position: Vector3, key_id: StringName, key_name := "key") -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(KeyScript)
	body.key_id = key_id
	body.key_name = key_name
	body.mass = 0.1
	body.add_child(shape_box(Vector3(0.12, 0.03, 0.05)))
	var visual := mesh_box(Vector3(0.12, 0.03, 0.05), Color(0.8, 0.7, 0.35))
	visual.name = "MeshInstance3D"
	body.add_child(visual)
	parent.add_child(body)
	body.global_position = position
	body.reset_physics_interpolation()
	return body


## A belt tool lying in the world. `shape` is "sphere", "rod" or "box".
static func tool(
	parent: Node,
	position: Vector3,
	tool_id: StringName,
	tool_name: String,
	color: Color,
	shape := "sphere",
	count := 1
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(ToolScript)
	body.tool_id = tool_id
	body.tool_name = tool_name
	body.count = count
	body.mass = 0.3

	var mesh: Mesh
	var size := Vector3(0.1, 0.1, 0.1)

	match shape:
		"rod":
			var rod := CylinderMesh.new()
			rod.top_radius = 0.008
			rod.bottom_radius = 0.008
			rod.height = 0.16
			mesh = rod
			size = Vector3(0.03, 0.16, 0.03)
		"box":
			var box := BoxMesh.new()
			box.size = Vector3(0.08, 0.12, 0.04)
			mesh = box
			size = box.size
		_:
			var ball := SphereMesh.new()
			ball.radius = 0.05
			ball.height = 0.1
			mesh = ball

	mesh.material = material(color, 0.3)
	body.add_child(shape_box(size))

	var visual := MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = mesh
	body.add_child(visual)

	parent.add_child(body)
	body.global_position = position
	body.reset_physics_interpolation()
	return body


static func crate(parent: Node, position: Vector3, size := 0.5, mass := 5.0, color := Color(0.55, 0.42, 0.25)) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "crate"
	body.mass = mass
	body.add_child(shape_box(Vector3.ONE * size))
	body.add_child(mesh_box(Vector3.ONE * size, color))
	parent.add_child(body)
	body.global_position = position
	body.reset_physics_interpolation()
	return body


## The blackjack's shape, for the hand and for the world.
static func blackjack_mesh() -> Mesh:
	var modelled: Mesh = WeaponScript.model(&"blackjack")

	if modelled != null:
		# Held like a club (ViewPoses.gd).
		modelled.set_meta(&"view_poses", &"blackjack")
		return modelled

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.02
	mesh.height = 0.34
	mesh.material = material(Color(0.12, 0.1, 0.09))
	return mesh


## Sword, dagger, bow and a quiver, straight onto a player's belt.
static func give_weapons(player: Node, arrows := 12) -> void:
	for weapon_id in [&"sword", &"dagger", &"bow"]:
		var weapon: Resource = WeaponScript.find(weapon_id)
		player.inventory.add_belt_item(weapon.id, weapon.display_name, weapon.mesh)

	if arrows > 0:
		player.inventory.add_belt_item(&"arrows", "arrows", WeaponScript.arrow_mesh(), arrows)


## A weapon lying in the world, to be picked up.
static func weapon(parent: Node, position: Vector3, weapon_id: StringName) -> RigidBody3D:
	var w: Resource = WeaponScript.find(weapon_id)
	var body := RigidBody3D.new()
	body.set_script(ToolScript)
	body.tool_id = w.id
	body.tool_name = w.display_name
	body.mass = 1.5
	var bounds: AABB = w.mesh.get_aabb()
	var shape := shape_box(bounds.size)
	shape.position = bounds.get_center()
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = w.mesh
	body.add_child(visual)
	parent.add_child(body)
	body.global_position = position
	body.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	body.reset_physics_interpolation()
	return body


static func arrows(parent: Node, position: Vector3, count := 6) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.set_script(ToolScript)
	body.tool_id = &"arrows"
	body.tool_name = "arrows"
	body.count = count
	body.mass = 0.4
	body.add_child(shape_box(Vector3(0.12, 0.12, 0.7)))
	var visual := MeshInstance3D.new()
	visual.name = "MeshInstance3D"
	visual.mesh = WeaponScript.arrow_mesh()
	body.add_child(visual)
	parent.add_child(body)
	body.global_position = position
	body.reset_physics_interpolation()
	return body


## A wall of spikes. `center` is the middle of the spiked face; the spikes
## point along `facing`. The deadly space is a thin slab in front of it,
## thinner than a guard keeps from walls, so patrols pass it safely.
static func spikes(parent: Node, center: Vector3, width: float, height: float, facing: Vector3) -> Area3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_transform = Transform3D(Basis.looking_at(-facing, Vector3.UP), center)
	root.reset_physics_interpolation()

	var metal := material(Color(0.35, 0.33, 0.32), 0.7)
	var columns := maxi(int(width / 0.25), 1)
	var rows := maxi(int(height / 0.3), 1)

	for i in range(columns):
		for j in range(rows):
			var spike := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.035
			cone.height = 0.22
			cone.material = metal
			spike.mesh = cone
			spike.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			spike.position = Vector3(
				lerpf(-width * 0.5 + 0.12, width * 0.5 - 0.12, float(i) / maxf(columns - 1, 1)),
				lerpf(-height * 0.5 + 0.15, height * 0.5 - 0.15, float(j) / maxf(rows - 1, 1)),
				0.11
			)
			root.add_child(spike)

	var area := Area3D.new()
	area.set_script(HazardScript)
	var shape := shape_box(Vector3(width, height, 0.25))
	shape.position = Vector3(0.0, 0.0, 0.125)
	area.add_child(shape)
	root.add_child(area)
	return area


## Put a blackjack straight into a player's hands.
static func give_blackjack(player: Node) -> void:
	player.inventory.add_belt_item(&"blackjack", "blackjack", blackjack_mesh())
	player.inventory.select_by_id(&"blackjack")


## `surface` names what the floor is made of: "carpet", "grass", "wood",
## "stone", "tile" or "metal". It changes how loud footsteps on it are.
static func block(parent: Node, center: Vector3, size: Vector3, color := Color(0.5, 0.5, 0.52), surface := "") -> StaticBody3D:
	var body := StaticBody3D.new()

	if surface != "":
		body.set_meta(&"surface", surface)
	body.add_child(shape_box(size))
	body.add_child(mesh_box(size, color))
	parent.add_child(body)
	body.global_position = center
	body.reset_physics_interpolation()
	return body
