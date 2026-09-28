extends Node3D
## The look: the Retro autoload's screen and materials, the lightgem kept
## clear of fog and glow, the night environment, torches, textures, and the
## showcase level. Headless, so this checks settings, not pixels; the pixels
## were checked by eye in a window.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const GemEnvironment := preload("res://scripts/Visual/GemEnvironment.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")

const NEAREST_MIPS := BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

var results: Array[String] = []


## Writes down where a camera is each frame, after everything else has moved.
class CameraRecorder:
	extends Node

	var camera: Camera3D
	var seen: Array[float] = []

	func _process(_delta: float) -> void:
		seen.append(camera.global_position.z)


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	await _frames(5)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	var retro: CanvasLayer = get_node_or_null("/root/Retro")

	# R1 the screen: under the HUD, a square grid, the 3D drawn only as sharp
	#    as the grid needs
	# The window's own pixels (the visible rect is in the HUD's scaled units).
	var window := Vector2(get_tree().root.size)
	var height_before: int = retro.virtual_height if retro != null else 0
	var grid := Vector2.ZERO
	var scale := 0.0

	if retro != null:
		retro.virtual_height = 120
		grid = retro.virtual_size()
		scale = get_tree().root.scaling_3d_scale

	var square := grid.y == 120.0 and absf(grid.x / grid.y - window.x / window.y) < 0.01
	_check("R1 the retro screen sits under the HUD, square cells, 3D at two pixels a cell",
		retro != null and retro.layer < 5 and square and is_equal_approx(scale, clampf(240.0 / window.y, 0.25, 1.0)),
		"autoload %s layer %d grid %s window %s render scale %.3f" % [retro != null, retro.layer if retro else -1, grid, window, scale])

	# R2 off is off: no grid, full resolution
	if retro != null:
		retro.virtual_height = 0

	var screen: Control = retro.get_node("RetroScreen") if retro != null else null
	var off_ok: bool = screen != null and not screen.visible and get_tree().root.scaling_3d_scale == 1.0

	if retro != null:
		retro.virtual_height = height_before

	_check("R2 with the grid off the screen hides and the 3D renders full size", off_ok and screen.visible,
		"hidden when off %s, back on %s" % [off_ok, screen.visible if screen else false])

	# R3 materials, as they enter the tree, sample their texels nearest
	var linear := StandardMaterial3D.new()
	linear.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var box := BoxMesh.new()
	box.material = linear
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	var overridden := StandardMaterial3D.new()
	var chained := StandardMaterial3D.new()
	overridden.next_pass = chained
	var skipped := StandardMaterial3D.new()
	skipped.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	skipped.set_meta(&"retro_skip", true)
	var other := MeshInstance3D.new()
	other.mesh = BoxMesh.new()
	other.material_override = overridden
	var third := MeshInstance3D.new()
	third.mesh = BoxMesh.new()
	third.material_override = skipped
	var csg := CSGBox3D.new()
	var csg_material := StandardMaterial3D.new()
	csg.material = csg_material
	var sprite := Sprite3D.new()
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	for node in [mesh, other, third, csg, sprite]:
		add_child(node)

	await _frames(2)
	var converted := (
		linear.texture_filter == NEAREST_MIPS
		and overridden.texture_filter == NEAREST_MIPS
		and chained.texture_filter == NEAREST_MIPS
		and csg_material.texture_filter == NEAREST_MIPS
		and sprite.texture_filter == NEAREST_MIPS
	)
	_check("R3 materials entering the scene sample nearest, and 'retro_skip' is respected",
		converted and skipped.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR,
		"mesh %d override %d next pass %d csg %d sprite %d skipped %d" % [linear.texture_filter, overridden.texture_filter, chained.texture_filter, csg_material.texture_filter, sprite.texture_filter, skipped.texture_filter])

	for node in [mesh, other, third, csg, sprite]:
		node.queue_free()

	# R10 a material given just after the mesh is added (the usual order in
	#     code) is converted too; switching the look off puts filters back
	var late := MeshInstance3D.new()
	late.mesh = BoxMesh.new()
	add_child(late)
	var late_material := StandardMaterial3D.new()
	late_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	late.material_override = late_material
	await _frames(2)
	var late_converted := late_material.texture_filter == NEAREST_MIPS
	retro.enabled = false
	var restored := late_material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	retro.enabled = true
	await _frames(2)
	_check("R10 materials set just after their mesh is added are converted, and restored when the look is off",
		late_converted and restored and late_material.texture_filter == NEAREST_MIPS,
		"converted %s restored %s converted again %s" % [late_converted, restored, late_material.texture_filter == NEAREST_MIPS])
	late.queue_free()

	# R4 the lightgem sees the level's light but none of its atmosphere, and
	#    keeps up when the level changes it
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.2, 0.1)
	environment.ambient_light_energy = 0.7
	environment.volumetric_fog_enabled = true
	environment.glow_enabled = true
	environment.ssao_enabled = true
	environment.fog_enabled = true
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var player: CharacterBody3D = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.global_position = Vector3(0, 1.05, 0)

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	await _frames(5)
	var gem_node: Node = player.get_node_or_null("GemEnvironment")
	var cameras: Array = gem_node.cameras if gem_node != null else []
	var gem: Environment = cameras[0].environment if cameras.size() > 0 else null
	var clean: bool = gem != null and not gem.volumetric_fog_enabled and not gem.glow_enabled and not gem.ssao_enabled and not gem.fog_enabled and gem.tonemap_mode == Environment.TONE_MAPPER_LINEAR
	var same_light: bool = gem != null and gem.ambient_light_color == environment.ambient_light_color and gem.ambient_light_energy == environment.ambient_light_energy
	var both: bool = cameras.size() == 2 and cameras[1].environment == gem

	environment.ambient_light_energy = 0.3
	await _frames(40)
	var followed_edit: bool = cameras.size() > 0 and is_equal_approx(cameras[0].environment.ambient_light_energy, 0.3)
	var replacement := Environment.new()
	replacement.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	replacement.ambient_light_color = Color(0.1, 0.2, 0.3)
	world_environment.environment = replacement
	await _frames(40)
	var followed_swap: bool = cameras.size() > 0 and cameras[0].environment.ambient_light_color == Color(0.1, 0.2, 0.3)
	_check("R4 the lightgem's cameras get the level's light without fog, glow or tonemap, and follow changes",
		clean and same_light and both and followed_edit and followed_swap,
		"clean %s same light %s both cameras %s followed an edit %s followed a swap %s" % [clean, same_light, both, followed_edit, followed_swap])
	world_environment.queue_free()

	# R5 the night environment: shafts in fog, glow, a filmic curve, dark
	var night := RetroScript.night_environment()
	_check("R5 the night environment has fog that makes shafts, glow and a filmic curve",
		night.volumetric_fog_enabled and night.volumetric_fog_density > 0.0 and night.volumetric_fog_anisotropy > 0.0 and night.glow_enabled and night.tonemap_mode == Environment.TONE_MAPPER_FILMIC and night.ambient_light_energy < 0.3,
		"fog %.3f anisotropy %.2f glow %s ambient %.2f" % [night.volumetric_fog_density, night.volumetric_fog_anisotropy, night.glow_enabled, night.ambient_light_energy])

	# R6 a torch breathes and its flame moves
	var torch: Node3D = TorchScript.new()
	add_child(torch)
	torch.position = Vector3(5, 2, 5)
	var energies := []
	var frames := {}

	for i in 60:
		await _frames(1)
		energies.append(torch.light.light_energy)
		frames[torch.frame] = true

	var low: float = energies.min()
	var high: float = energies.max()
	_check("R6 a torch flickers within its range and animates its flame", high > low + 0.05 and low > torch.energy * (1.0 - torch.flicker) - 0.01 and high < torch.energy * (1.0 + torch.flicker) + 0.01 and frames.size() >= 3 and torch.light.shadow_enabled,
		"energy %.2f..%.2f flame frames seen %d shadows %s" % [low, high, frames.size(), torch.light.shadow_enabled])
	torch.queue_free()

	# R7 the project's textures come with mipmaps, uncompressed
	var textured := 0
	var paths := ["res://textures/stone_brick_1.png", "res://textures/wood_1.png", "res://maps/test_stone_road.png", "res://textures/proto_tex/dark/texture_01.png"]

	for path in paths:
		var image: Image = (load(path) as Texture2D).get_image()

		if image != null and image.has_mipmaps() and not image.is_compressed():
			textured += 1

	_check("R7 textures import with mipmaps and without lossy compression", textured == paths.size(),
		"%d of %d" % [textured, paths.size()])

	# R9 two frames to a physics tick (a 120 Hz screen): the view still moves
	#    every frame, not every other one
	player.global_position = Vector3(0, 1.05, 10)
	player.rotation.y = 0.0
	Engine.physics_ticks_per_second = 30
	Input.action_press("move_forward")

	for i in 40:
		await get_tree().process_frame

	# Read where the camera is drawn: after everyone's _process, the player's
	# included.
	var recorder := CameraRecorder.new()
	recorder.camera = player.camera
	recorder.process_priority = 1000
	add_child(recorder)

	for i in 25:
		await get_tree().process_frame

	recorder.queue_free()
	Input.action_release("move_forward")
	var steps := []

	for i in range(1, recorder.seen.size()):
		steps.append(absf(recorder.seen[i] - recorder.seen[i - 1]))

	Engine.physics_ticks_per_second = 60
	var smallest: float = steps.min()
	var largest: float = steps.max()
	# Without the carry, every other frame the view would not move at all.
	_check("R9 at two frames a physics tick the view moves every frame, evenly", smallest > 0.0 and largest < smallest * 1.6,
		"per-frame steps %.4f..%.4f m" % [smallest, largest])

	await _crisp_checks(retro, player)

	# R8 the showcase loads and runs clean
	player.queue_free()
	await _frames(3)
	var showcase: Node3D = load("res://maps/retro_showcase.tscn").instantiate()
	add_child(showcase)
	await _frames(120)
	var torches := showcase.find_children("*", "OmniLight3D", true, false).size()
	var shafts := 0

	for light in showcase.find_children("*", "DirectionalLight3D", true, false):
		if light.shadow_enabled and light.light_volumetric_fog_energy > 0.0:
			shafts += 1

	var mist := showcase.find_children("*", "FogVolume", true, false).size()
	_check("R8 the showcase has torches, a moon for shafts and mist, and runs", torches >= 5 and shafts == 1 and mist >= 1,
		"torch lights %d moon %d mist %d" % [torches, shafts, mist])
	showcase.queue_free()
	await _frames(3)
	await _psx_checks(retro)


## R12-R17 the PS1's wobble on the world: its vertices snap to the grid's
## cells (gently: the grid's own lines, not a PS1's 240), every material
## drawing the world through a snapping twin of itself that follows it (the
## night wets the stones), the hands and held things and 'retro_skip' left
## smooth, the world's own shaders snapping alike; the dither reads.
func _psx_checks(retro: CanvasLayer) -> void:
	RetroScript.twin_headless = true
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.6, 0.5, 0.4)
	stone.roughness = 0.9
	var picture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	stone.albedo_texture = picture
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	(wall.mesh as BoxMesh).material = stone
	var held := MeshInstance3D.new()
	held.mesh = BoxMesh.new()
	held.material_override = StandardMaterial3D.new()
	held.layers = Layers.VIEWMODEL
	var skipped := MeshInstance3D.new()
	skipped.mesh = BoxMesh.new()
	skipped.material_override = StandardMaterial3D.new()
	skipped.material_override.set_meta(&"retro_skip", true)

	for node in [wall, held, skipped]:
		add_child(node)

	await _frames(3)
	var twin := wall.get_surface_override_material(0) as ShaderMaterial
	var snapping := twin != null and twin.shader != null and twin.shader.code.contains("psx_snapped(")
	var kept := twin != null and (twin.get_shader_parameter(&"albedo") as Color).is_equal_approx(stone.albedo_color) \
		and twin.get_shader_parameter(&"texture_albedo") != null
	var base_kept := (wall.mesh as BoxMesh).material == stone
	_check("R12 a mesh drawing the world gets a snapping twin of its material, the same colour and texture; its own material left as it was",
		snapping and kept and base_kept, "twin %s snapping %s kept %s own kept %s" % [twin != null, snapping, kept, base_kept])
	var smooth := held.material_override is BaseMaterial3D and skipped.material_override is BaseMaterial3D
	_check("R13 the hands and held things (the view's layer) and 'retro_skip' keep their own smooth materials", smooth,
		"held %s skipped %s" % [held.material_override, skipped.material_override])

	# R14 the twin follows its material (the night wetting the stones)
	stone.albedo_color = Color(0.3, 0.25, 0.2)
	stone.roughness = 0.15
	for f in 30:
		await get_tree().process_frame
	var followed := twin != null and (twin.get_shader_parameter(&"albedo") as Color).is_equal_approx(Color(0.3, 0.25, 0.2)) \
		and is_equal_approx(float(twin.get_shader_parameter(&"roughness")), 0.15)
	_check("R14 a twin follows its material as it changes (wet stone darker and glossier)", followed,
		"albedo %s roughness %s" % [twin.get_shader_parameter(&"albedo") if twin else null, twin.get_shader_parameter(&"roughness") if twin else null])

	# R15 the snap follows the grid: its lines while the look is on, none off
	var height_before: int = retro.virtual_height
	var on_lines: float = retro.snap_lines()
	retro.virtual_height = 240
	var at_240: float = retro.snap_lines()
	retro.snap = false
	var snap_off: float = retro.snap_lines()
	retro.snap = true
	retro.virtual_height = 0
	var grid_off: float = retro.snap_lines()
	retro.virtual_height = height_before
	_check("R15 vertices snap to the grid's lines (gently: 360 by default), none with the snap or the grid off",
		is_equal_approx(on_lines, float(height_before)) and is_equal_approx(at_240, 240.0) and snap_off == 0.0 and grid_off == 0.0 and height_before >= 300,
		"on %.0f at 240 %.0f snap off %.0f grid off %.0f (grid %d)" % [on_lines, at_240, snap_off, grid_off, height_before])

	# R16 the world's own shaders snap alike (leaves, water, glowing glass,
	# the stains on the floor, the men's clothes and skin)
	var own := {}

	for path in ["res://scripts/Visual/foliage.gdshader", "res://scripts/Visual/water.gdshader", "res://scripts/Visual/Lights/glow.gdshader",
			"res://scripts/Visual/ground_stain.gdshader", "res://scripts/Visual/retro_psx.gdshader", "res://scripts/Visual/wardrobe.gdshaderinc"]:
		var resource: Resource = load(path)
		own[path.get_file()] = String(resource.get("code")).contains("psx_snapped(")

	_check("R16 the world's own shaders snap alike: foliage, water, glow, floor stains, the old psx shader, the men's wardrobe", own.values().all(func(v): return v),
		"%s" % [own])

	# R17 the look off: the twins given back, the world's own materials on
	retro.enabled = false
	var given_back := wall.get_surface_override_material(0) == null
	retro.enabled = true
	await _frames(3)
	var twinned_again := wall.get_surface_override_material(0) is ShaderMaterial
	_check("R17 with the look off the world draws with its own materials again; on again, twinned again", given_back and twinned_again,
		"given back %s twinned again %s" % [given_back, twinned_again])

	# R18 the PS1's crunch reads: colour cut to 24 levels a channel or fewer,
	# the dither at full strength
	_check("R18 the dither reads: 24 levels a channel or fewer, dithered at full strength",
		retro.color_levels <= 24.0 and retro.color_levels > 0.0 and retro.dither >= 0.95, "levels %.0f dither %.2f" % [retro.color_levels, retro.dither])
	RetroScript.twin_headless = false

	for node in [wall, held, skipped]:
		node.queue_free()

	await _frames(2)


## R11 words over a man's head are drawn sharp over the grid, not through it
## (CrispText): where they are on the screen, big enough to read, with the 3D
## label kept off the render; hidden behind a wall; too far off to read in
## the world, not drawn; with the grid off, the 3D label back and nothing
## drawn over it. A guard's own words are among them.
func _crisp_checks(retro: CanvasLayer, player: CharacterBody3D) -> void:
	var crisp: Node = retro.get_node_or_null("CrispText") if retro != null else null
	var eye: Camera3D = player.camera
	var ahead := -eye.global_basis.z
	var words := Label3D.new()
	words.text = "Who goes there?"
	words.font_size = 36
	words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	words.add_to_group(&"crisp_text")
	add_child(words)
	words.global_position = eye.global_position + ahead * 9.0
	await _frames(10)
	var ours := func() -> Array:
		return crisp.shown().filter(func(entry): return entry["label"] == words) if crisp != null else []
	var drawn: Array = ours.call()
	var placed: bool = drawn.size() == 1 and (drawn[0]["at"] as Vector2).distance_to(eye.unproject_position(words.global_position)) < 1.0 \
		and int(drawn[0]["px"]) >= 12 and float(drawn[0]["presence"]) > 0.9
	var off_render: bool = words.layers == 0

	# A wall between.
	var wall := Props.block(self, eye.global_position + ahead * 4.0, Vector3(8, 8, 0.4))
	await _frames(20)
	var walled: bool = (ours.call() as Array).is_empty()
	wall.queue_free()
	await _frames(20)
	var back_in_view: bool = (ours.call() as Array).size() == 1

	# Too far off to read in the world.
	words.global_position = eye.global_position + ahead * 60.0
	await _frames(5)
	var far_gone: bool = (ours.call() as Array).is_empty()
	words.global_position = eye.global_position + ahead * 9.0

	# The grid off: the 3D label is back, nothing drawn over it; on again.
	var height: int = retro.virtual_height
	retro.virtual_height = 0
	await _frames(3)
	var restored: bool = words.layers == 1 and crisp.shown().is_empty()
	retro.virtual_height = height
	await _frames(3)
	var held_again: bool = words.layers == 0 and (ours.call() as Array).size() == 1
	words.queue_free()

	# A guard's words.
	var guard: Node3D = load("res://Guard.tscn").instantiate()
	guard.set("debug_ai", false)
	add_child(guard)
	guard.global_position = Vector3(30, 0, 30)
	await _frames(2)
	var bark: Node = guard.get_node_or_null("Bark")
	var his: bool = bark != null and bark.is_in_group(&"crisp_text")
	guard.queue_free()
	await _frames(2)
	_check("R11 words over a man's head are drawn sharp over the grid (not through it), hidden behind walls and when too far to read; the grid off, the 3D label is back",
		crisp != null and placed and off_render and walled and back_in_view and far_gone and restored and held_again and his,
		"drawn %s placed %s off the render %s, walled %s back %s, far %s, grid off: restored %s, on again %s, a guard's %s" % [drawn, placed, off_render, walled, back_in_view, far_gone, restored, held_again, his])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
