extends Node3D
## A playable gym for the traversal system. Every fixture is built here in
## code, so heights are exact and the file is easy to read. Walk the lanes
## from the start line; each sign says what the lane tests.
##
## Run it from the editor, or from the terminal:
##   Godot --path . res://maps/traversal_gym.tscn

const PLAYER := preload("res://Player.tscn")
const CLIMB := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const ROPE := preload("res://scripts/PlayerUtils/VerletRope.gd")

const LANE_WIDTH := 3.0

var _materials := {}


func _ready() -> void:
	# Everything below is placed after it is added: draw it from where it ends up.
	reset_physics_interpolation.call_deferred()
	_environment()
	_floor()

	_lane_stairs(0.0)
	_lane_mantles(8.0)
	_lane_vaults(16.0)
	_lane_hang_course(24.0)
	_lane_kick_and_upward(32.0)
	_lane_gaps(40.0)
	_lane_ladder_and_rope(48.0)
	_lane_facade(56.0)

	var player := PLAYER.instantiate()
	player.debug_traversal = true
	add_child(player)
	player.global_position = Vector3(0.0, 1.05, 8.0)


# ---------------------------------------------------------------------------
# Lanes
# ---------------------------------------------------------------------------

func _lane_stairs(x: float) -> void:
	_sign(x, "STEPS & STAIRS\nwalk: 0.15, 0.25, 0.35 steps\nthen 0.2 x 0.3 and 0.3 x 0.3 stairs")

	_block(x, -3.0, 2.0, 0.15, "steel")
	_block(x, -6.0, 2.0, 0.25, "steel")
	_block(x, -9.0, 2.0, 0.35, "steel")

	_stairs(x, -12.0, 0.2, 0.3, 8, "steel")
	_block(x, -15.4, 2.0, 1.6, "steel")

	_stairs(x, -19.0, 0.3, 0.3, 6, "steel")
	_block(x, -21.8, 2.0, 1.8, "steel")


func _lane_mantles(x: float) -> void:
	_sign(x, "MANTLES\nforward + jump\n0.6 crate, 1.2 ledge, 2.0 wall\n3.0 wall: jump then hold\nlow ceiling: crouched mantle")

	_block(x, -4.0, 2.0, 0.6, "stone")
	_block(x, -9.0, 2.0, 1.2, "stone")
	_block(x, -14.0, 2.0, 2.0, "stone")
	_block(x, -19.5, 2.0, 3.0, "stone")

	_block(x, -25.5, 2.0, 1.2, "stone")
	_box(Vector3(x, 2.7, -25.5), Vector3(LANE_WIDTH, 0.2, 2.0), "stone")


func _lane_vaults(x: float) -> void:
	_sign(x, "VAULTS & FLOW\nsprint + jump\n0.9 fence, 1.0 rail\ntwo fences 3 m apart: press jump\nagain mid-vault to chain")

	_box(Vector3(x, 0.45, -4.0), Vector3(LANE_WIDTH, 0.9, 0.2), "wood")
	_box(Vector3(x, 0.5, -8.0), Vector3(LANE_WIDTH, 1.0, 0.1), "wood")
	_box(Vector3(x, 0.45, -13.0), Vector3(LANE_WIDTH, 0.9, 0.2), "wood")
	_box(Vector3(x, 0.45, -16.0), Vector3(LANE_WIDTH, 0.9, 0.2), "wood")

	# A 0.6 crate then a fence: mantle into vault.
	_block(x, -22.0, 1.0, 0.6, "wood")
	_box(Vector3(x, 0.45, -25.0), Vector3(LANE_WIDTH, 0.9, 0.2), "wood")


func _lane_hang_course(x: float) -> void:
	_sign(x, "HANG COURSE\njump + hold at the 3.6 wall\nstrafe: shimmy, gap: strafe + jump\nends: corners\nbetween the two walls: turn, look, jump\nfar wall, right end: aim past the corner\nat the side wall's ledge, jump")

	# Ledge A, ledge B across a 1.5 m gap, block C making an inside corner.
	_box(Vector3(x - 0.25, 1.8, -4.5), Vector3(2.5, 3.6, 3.0), "brick")
	_box(Vector3(x + 3.75, 1.8, -4.5), Vector3(2.5, 3.6, 3.0), "brick")
	_box(Vector3(x + 6.25, 1.8, -1.75), Vector3(2.5, 3.6, 2.5), "brick")

	# A wall facing a different way, across a 1.5 m alley past the end of the
	# second pair. Hang near the far right end, aim past the corner, jump.
	_box(Vector3(x + 9.5, 1.8, -12.1), Vector3(3.0, 3.6, 4.8), "brick")

	# Two walls facing each other, 3 m apart, for the leap across.
	_box(Vector3(x + 2.0, 1.8, -9.5), Vector3(9.0, 3.6, 3.0), "brick")
	_box(Vector3(x, 1.8, -15.5), Vector3(5.0, 3.6, 3.0), "brick")


func _lane_kick_and_upward(x: float) -> void:
	_sign(x, "KICK & UPWARD LEAP\ntall wall: jump, press jump again\nbeside it, keep holding: grab the sill\nmolding wall: hang, look up, jump")

	# Tall wall with a sill at 4.2 m.
	_box(Vector3(x, 4.0, -4.5), Vector3(LANE_WIDTH, 8.0, 3.0), "dark")
	_box(Vector3(x, 4.05, -2.7), Vector3(LANE_WIDTH, 0.3, 0.6), "dark")

	# 4.6 m wall with a molding at 3.4 m, and the roof lip 1.2 m above it.
	_box(Vector3(x, 2.3, -12.5), Vector3(LANE_WIDTH, 4.6, 3.0), "dark")
	_box(Vector3(x, 3.375, -10.85), Vector3(LANE_WIDTH, 0.25, 0.3), "dark")


func _lane_gaps(x: float) -> void:
	_sign(x, "GAPS\nup the stairs, then run and jump\n3 m: any jump\n4.6 m: assisted\n6.5 m: you will miss")

	_stairs(x, 5.0, 0.2, 0.3, 10, "moss")
	_box(Vector3(x, 1.0, -1.0), Vector3(LANE_WIDTH, 2.0, 6.0), "moss")
	_box(Vector3(x, 1.0, -9.0), Vector3(LANE_WIDTH, 2.0, 4.0), "moss")
	_box(Vector3(x, 1.0, -17.6), Vector3(LANE_WIDTH, 2.0, 4.0), "moss")
	_box(Vector3(x, 1.0, -28.1), Vector3(LANE_WIDTH, 2.0, 4.0), "moss")


func _lane_ladder_and_rope(x: float) -> void:
	_sign(x, "LADDER & ROPE\nwalk into them\nforward climbs the way you look\njump lets go\nrope: strafe swings around it")

	_box(Vector3(x, 2.5, -4.5), Vector3(LANE_WIDTH, 5.0, 3.0), "stone")
	_ladder(Vector3(x, 2.5, -2.65), 5.0)

	# A rope and a chain, each hanging from a beam, each beside a ledge.
	_box(Vector3(x, 7.15, -12.0), Vector3(LANE_WIDTH, 0.3, 0.3), "wood")
	_rope(Vector3(x, 7.0, -12.0), 6.0, ROPE.Style.ROPE)
	_box(Vector3(x, 2.25, -14.4), Vector3(LANE_WIDTH, 4.5, 3.0), "stone")

	_box(Vector3(x, 7.15, -21.0), Vector3(LANE_WIDTH, 0.3, 0.3), "wood")
	_rope(Vector3(x, 7.0, -21.0), 6.0, ROPE.Style.CHAIN)
	_box(Vector3(x, 2.25, -23.4), Vector3(LANE_WIDTH, 4.5, 3.0), "stone")


func _lane_facade(x: float) -> void:
	_sign(x, "FACADE\njump + hold at the wall: hang\nlook at the next ledge, jump\nlook down at a ledge, jump: drop to it\nclimb to the roof, then look down\nover the edge and press crouch")

	_box(Vector3(x, 4.0, -4.5), Vector3(5.0, 8.0, 3.0), "brick")
	_molding(x, 3.5)
	_molding(x + 1.1, 4.7)
	_molding(x - 0.4, 5.9)
	_molding(x + 0.9, 7.1)


# ---------------------------------------------------------------------------
# Builders
# ---------------------------------------------------------------------------

func _block(x: float, z: float, depth: float, height: float, material: String) -> void:
	_box(Vector3(x, height * 0.5, z), Vector3(LANE_WIDTH, height, depth), material)


func _stairs(x: float, z_start: float, riser: float, tread: float, count: int, material: String) -> void:
	for i in range(count):
		var top := riser * (i + 1)
		_box(
			Vector3(x, top * 0.5, z_start - tread * i - tread * 0.5),
			Vector3(LANE_WIDTH, top, tread),
			material
		)


func _box(center: Vector3, size: Vector3, material: String) -> void:
	var box := CSGBox3D.new()
	box.size = size
	box.use_collision = true
	box.material = _material(material)
	add_child(box)
	box.global_position = center


func _ladder(center: Vector3, height: float) -> void:
	var volume := Area3D.new()
	volume.set_script(CLIMB)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, height, 0.7)
	shape.shape = box
	volume.add_child(shape)
	add_child(volume)
	volume.global_position = center

	# Rungs, purely visual.
	var rungs := int(height / 0.3)

	for i in range(rungs):
		var rung := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.8, 0.04, 0.04)
		rung.mesh = mesh
		rung.material_override = _material("wood")
		add_child(rung)
		rung.global_position = Vector3(center.x, 0.3 * (i + 1), center.z - 0.28)


func _rope(anchor: Vector3, length: float, style: int) -> void:
	var rope := Area3D.new()
	rope.set_script(ROPE)
	rope.style = style
	rope.length = length
	# Placed before it is added: it hangs its links from where it is when it
	# enters the tree.
	rope.position = anchor
	add_child(rope)


## A thin ledge sticking 0.3 m out of a wall whose face is at z = -3.
func _molding(x: float, top: float) -> void:
	_box(Vector3(x, top - 0.125, -2.85), Vector3(1.2, 0.25, 0.3), "brick")


func _sign(x: float, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.008
	label.modulate = Color(0.95, 0.9, 0.8)
	label.outline_size = 8
	add_child(label)
	label.global_position = Vector3(x, 1.6, 3.0)


func _floor() -> void:
	_box(Vector3(24.0, -0.5, -10.0), Vector3(70.0, 1.0, 90.0), "floor")


func _environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.13, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	environment.ambient_light_energy = 0.7

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _material(name: String) -> StandardMaterial3D:
	if _materials.has(name):
		return _materials[name]

	var colors := {
		"floor": Color(0.22, 0.22, 0.24),
		"steel": Color(0.45, 0.5, 0.58),
		"stone": Color(0.55, 0.52, 0.48),
		"wood": Color(0.55, 0.38, 0.22),
		"brick": Color(0.6, 0.3, 0.25),
		"dark": Color(0.28, 0.28, 0.32),
		"moss": Color(0.3, 0.45, 0.28),
		"rope": Color(0.75, 0.62, 0.4),
	}

	var material := StandardMaterial3D.new()
	material.albedo_color = colors.get(name, Color.GRAY)
	material.roughness = 0.9
	_materials[name] = material
	return material
