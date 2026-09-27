extends Node3D
## The look, all in one room: a moonlit stone hall. Moonlight comes through
## three tall windows as shafts in the fog; torches breathe on the walls and
## throw pillar shadows through the haze; mist lies in one corner; an idol
## wobbles the PS1 way; a guard walks his round.
##
##   Godot --path . res://maps/retro_showcase.tscn
##
##   F6  the grid: 360 lines, 240 (PS1), 448 (PS2), off  (the Retro autoload,
##   F7  colour depth: 32 levels a channel, 64, full      in any scene of a
##   F8  dither on and off                               debug build)
##
## Everything here is built in code from the project's textures, sampled
## nearest-neighbour by the Retro autoload.

const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const Lights := preload("res://scripts/Visual/Lights/Lights.gd")
const PSX_SHADER := preload("res://scripts/Visual/retro_psx.gdshader")

const STONE_ROAD := preload("res://maps/test_stone_road.png")
const STONE_WEATHERED := preload("res://maps/test_stone_weathered.png")
const BRICK := preload("res://textures/stone_brick_1.png")
const MOSS := preload("res://textures/mossy_rock_1.png")
const WOOD := preload("res://textures/wood_1.png")
const PLASTER := preload("res://textures/plaster_1.png")
const GRASS := preload("res://textures/grass_ground_1.png")

var player: CharacterBody3D
var _idol: Node3D


func _ready() -> void:
	# Everything below is placed after it is added: draw it from where it ends up.
	reset_physics_interpolation.call_deferred()
	_hall()
	_lights()
	_props()

	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)

	_guard()

	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = Vector3(0, 1.05, 4.2)
	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")

	_sign(Vector3(-7.9, 2.3, 3.6), PI * 0.5, "THE LOOK\nF6  grid lines: 360 / 240 (PS1) / 448 (PS2) / off\nF7  colour depth: 32 / 64 / full\nF8  dither on / off")


func _process(delta: float) -> void:
	if _idol != null:
		_idol.rotate_y(delta * 0.6)


# ---------------------------------------------------------------------------
# The hall
# ---------------------------------------------------------------------------

func _hall() -> void:
	# Floor, ceiling, walls. Interior: x -8..8, z -12..6, 6 m high.
	_brush(Vector3(0, -0.25, -3), Vector3(16.8, 0.5, 18.8), STONE_ROAD, 2.0)
	_brush(Vector3(0, 6.25, -3), Vector3(16.8, 0.5, 18.8), WOOD, 2.0, "wood")
	_brush(Vector3(-8.2, 3, -3), Vector3(0.4, 6, 18.8), BRICK, 2.0)
	_brush(Vector3(0, 3, 6.2), Vector3(16.8, 6, 0.4), BRICK, 2.0)
	_brush(Vector3(0, 3, -12.2), Vector3(16.8, 6, 0.4), STONE_WEATHERED, 2.5)

	# The east wall, with three tall windows (z -9, -3 and 3).
	_brush(Vector3(8.2, 0.8, -3), Vector3(0.4, 1.6, 18.8), BRICK, 2.0)
	_brush(Vector3(8.2, 5.4, -3), Vector3(0.4, 1.2, 18.8), BRICK, 2.0)

	for pier in [[-11.0, 2.8], [-6.0, 4.8], [0.0, 4.8], [5.0, 2.8]]:
		_brush(Vector3(8.2, 3.2, pier[0]), Vector3(0.4, 3.2, pier[1]), BRICK, 2.0)

	# Pillars down the hall.
	for at in [Vector3(-3.5, 3, -8), Vector3(3.5, 3, -8), Vector3(-3.5, 3, -2), Vector3(3.5, 3, -2)]:
		_brush(at, Vector3(0.8, 6, 0.8), MOSS, 1.5)

	# A wooden gallery along the north wall, crates to climb to it.
	_brush(Vector3(0, 2.85, -10.6), Vector3(12, 0.3, 2.4), WOOD, 1.5, "wood")

	for x in [-5.0, 5.0]:
		_brush(Vector3(x, 1.35, -9.6), Vector3(0.25, 2.7, 0.25), WOOD, 1.5, "wood")

	# Moonlit ground outside the windows.
	_brush(Vector3(16, -0.25, -3), Vector3(15, 0.5, 30), GRASS, 2.0, "grass")


func _lights() -> void:
	var environment := RetroScript.night_environment()
	# A moonlit night outside, so the windows read as windows.
	environment.background_color = Color(0.035, 0.05, 0.1)
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	# The moon, low in the east: it comes in through the windows as shafts.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.66, 1.0)
	moon.light_energy = 1.6
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 9.0
	moon.directional_shadow_max_distance = 45.0
	add_child(moon)
	# Low in the sky: long shafts that reach across the floor.
	moon.global_basis = Basis.looking_at(Vector3(-1.0, -0.46, -0.28).normalized(), Vector3.UP)

	# Torches along the west wall and on the pillars facing the middle.
	for at in [Vector3(-7.7, 2.5, -9.0), Vector3(-7.7, 2.5, -3.0), Vector3(-7.7, 2.5, 3.0), Vector3(-3.0, 2.3, -2.0), Vector3(3.0, 2.3, -8.0)]:
		Lights.torch_at(self, at, 2.4, 9.0, true, {"can_douse": true})

	# Mist lying in the south-west corner.
	var mist := FogVolume.new()
	mist.size = Vector3(5.5, 1.0, 4.5)
	var fog := FogMaterial.new()
	fog.density = 0.35
	fog.albedo = Color(0.8, 0.85, 1.0)
	fog.height_falloff = 1.5
	fog.edge_fade = 0.4
	mist.material = fog
	add_child(mist)
	mist.global_position = Vector3(-5.0, 0.3, 3.2)


func _props() -> void:
	Props.crate(self, Vector3(-5.6, 0.4, -8.2), 0.8, 20.0)
	Props.crate(self, Vector3(-5.6, 1.1, -8.2), 0.6, 10.0)
	Props.crate(self, Vector3(5.2, 0.35, -8.6), 0.7, 15.0)
	Props.crate(self, Vector3(6.4, 0.3, 4.4), 0.6, 8.0)

	# An idol on a pedestal, drawn with the PS1's wobble and swim.
	_brush(Vector3(0, 0.5, -6), Vector3(1.1, 1.0, 1.1), STONE_WEATHERED, 1.0)
	_idol = Node3D.new()
	# Turned every frame, in _process: drawn as set.
	_idol.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_idol)
	_idol.global_position = Vector3(0, 1.0, -6)

	var material := ShaderMaterial.new()
	material.shader = PSX_SHADER
	material.set_shader_parameter("albedo_texture", MOSS)
	material.set_shader_parameter("uv_scale", Vector2(2.0, 2.0))
	material.set_shader_parameter("snap_lines", 160.0)
	material.set_shader_parameter("affine", 1.0)
	material.set_shader_parameter("albedo", Color(1.0, 0.92, 0.8))

	var body := MeshInstance3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.32
	trunk.height = 0.9
	trunk.radial_segments = 6
	trunk.rings = 1
	body.mesh = trunk
	body.material_override = material
	body.position = Vector3(0, 0.45, 0)
	_idol.add_child(body)

	var head := MeshInstance3D.new()
	var skull := SphereMesh.new()
	skull.radius = 0.2
	skull.height = 0.4
	skull.radial_segments = 6
	skull.rings = 4
	head.mesh = skull
	head.material_override = material
	head.position = Vector3(0, 1.08, 0)
	_idol.add_child(head)


func _guard() -> void:
	var route := Node3D.new()
	route.name = "Route"
	add_child(route)

	for at in [Vector3(-4.8, 0, 1.5), Vector3(-4.8, 0, -6.5), Vector3(4.8, 0, -6.5), Vector3(4.8, 0, 1.5)]:
		var point := Node3D.new()
		route.add_child(point)
		point.global_position = at

	var g: CharacterBody3D = GUARD.instantiate()
	g.name = "Guard"
	g.debug_ai = false
	g.patrol_route = NodePath("../Route")
	g.speaker_name = "Night watch"
	add_child(g)
	g.global_position = Vector3(-4.8, 0, 1.5)


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

## A solid block with a texture laid on in world space, one tile every `tile`
## metres, so blocks side by side continue each other's texture.
func _brush(center: Vector3, size: Vector3, texture: Texture2D, tile: float, surface := "stone") -> StaticBody3D:
	var body := Props.block(self, center, size, Color.WHITE, surface)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / tile
	material.roughness = 0.92

	for child in body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = material

	return body


func _sign(at: Vector3, yaw: float, text: String) -> void:
	var label := Label3D.new()
	label.rotation.y = yaw
	label.text = text
	label.font_size = 28
	label.pixel_size = 0.006
	label.modulate = Color(0.95, 0.9, 0.8)
	label.outline_size = 8
	label.shaded = false
	add_child(label)
	label.global_position = at
