extends Node3D
## The Metro Underground's look-dev bay (docs/superpowers/plans/2026-10-16-metro-underground-part-1.md,
## Task 9): the hero stall against the wall of a stretch of tiled corridor,
## painted in the bespoke blend, its neon and bulb lit, the conduit its
## cable draws from running along the wall, two sodium work lights.
##   F1  work lights on / off
##   F2  form light: everything neutral grey under one white light, to judge shape
##   F3  grime decals on / off
##   F4  a train now (they pass every 90-150 s on their own)
##   F5  the dark train now (it runs every 10-20 min on its own)
##   F9  the procession now (her dead walk on their own every 4-8 min)
##
## The stall's atlas is the committed painted file (the user's overpaint
## stall.png before the painter's stall_base.png); the bay never reads the
## user's local brush sheets.

const PLAYER := preload("res://Player.tscn")
const Vfx := preload("res://scripts/Level/Vfx.gd")
const FireParticles := preload("res://scripts/Visual/Lights/FireParticles.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const Painterly := preload("res://scripts/Visual/Painterly.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")
const AnimasScript := preload("res://scripts/Visual/Animas.gd")
const NahualScript := preload("res://scripts/Visual/Nahual.gd")
const ProcessionScript := preload("res://scripts/Visual/Procession.gd")
const ShadowScript := preload("res://scripts/Visual/OwnerlessShadow.gd")
## The procession's file: its shades in order (the uncanny kit's, shade_refs.md); each holds its candle
## where the kit's wicks file says.
const PROCESSION := ["shade_capirote", "shade_veiled", "shade_child", "shade_sombrero", "shade_capirote"]
const UNCANNY_WICKS := "res://assets/eclipse/source/underground_uncanny_wicks.json"
## The dark train (supernatural_refs.md): Ehécatl's wind running the line dug through his temple, rarely;
## how rare (s), how far every light sinks, how hard the draught, and the wind heard (a stand-in until
## the user's tunnel-wind recording, sound_list.md #10).
const DARK_EVERY := Vector2(600.0, 1200.0)
const DARK_SINK := 0.85
const DARK_DRAUGHT := Vector3(2.2, 0.0, 0.0)
const DARK_WIND := "res://audio/ambience/cave.ogg"
const DARK_WIND_DB := -14.0

## The corridor (m): its run along X, the wall the stall backs onto, the far wall, the vault.
const RUN := 12.0
const BACK_WALL := -2.35
const FAR_WALL := 4.55
const HEIGHT := 4.0
const WALL := 0.3
## Godot positions of what the stall's script built (Blender x, z, -y).
const BULB := Vector3(0.1, 2.15, -1.1)
## Where the bulb's cord meets the canvas: the pivot it swings from.
const BULB_PIVOT := Vector3(0.1, 2.47, -1.1)
## The top of the copal on the censer.
const CENSER := Vector3(0.0, 1.2, -0.22)
## The corridor's draught, the one wind the smoke and the bulb answer to (m/s).
const DRAUGHT := Vector3(0.35, 0.0, 0.0)
const HUM := "res://audio/ambience/neon_hum.wav"
## The hum at full, and how near silence it falls when the tube goes dark (dB).
const HUM_DB := -8.0
const HUM_DARK := 0.05
## Where the stall's lit candles stand (tools/eclipse/stall.py's wicks).
const WICKS := "res://assets/eclipse/source/stall_wicks.json"
## The neon's glow on its sign's face (Blender's recessed face, y 0.05).
const SIGN_FACE := Vector3(0.0, 2.65, -0.02)
const SIGN_SIZE := Vector2(1.9, 0.44)
const WASH_ENERGY := 0.5
## The bodged tap at the junction box throws a few sparks every so often (s).
const SPARKS_EVERY := Vector2(5.0, 13.0)
## Water off the conduit, beside the stall.
const DRIP_AT := Vector3(-2.3, 3.15, -2.17)
const DRIP_SOUND := "res://audio/weather/drip.wav"
## A passing train: its rumble at full (dB), the jars' rattle, where the shelves stand.
const RUMBLE := "res://audio/sfx/train_rumble_1.wav"
const BOX_HUM := "res://audio/ambience/electric_box.wav"
## What lies on the floor (tools/eclipse/underground_ground.py), and the marigold trail's ends:
## from her ofrenda, curving across the floor to the wall where it leads.
const GROUND_KIT := "res://assets/eclipse/kit/underground_ground.glb"
const TRAIL_START := Vector3(-1.2, 0.0, 0.35)
const TRAIL_END := Vector3(-5.5, 0.0, -2.2)
const TRAIL_BEND := Vector3(-3.6, 0.0, 0.9)
const TRAIL_HEADS := 18
const TRAIL_PATCHES := 9
## Where the cable run stands (tools/eclipse/underground_ground.py CABLE_AT): its riser up into the junction box.
const CABLE_AT := Vector3(1.55, 0.0, -2.2)
const STOCK := ["sack_slumped", "sack_lying", "crate", "crate_corn"]
## The services along the walls (tools/eclipse/underground_services.py), each hung at its height:
## on the back wall the water main (CONDUIT), the gas line, the Company's tray; on the far wall
## the fire main, the air line, heavy cables on hooks high under the vault.
const SERVICES_KIT := "res://assets/eclipse/kit/underground_services.glb"
const GAS_Y := 3.0
const TRAY_Y := 3.6
const FIRE_Y := 3.1
const AIR_Y := 2.75
const HOOK_Y := 3.88
## The corridor's furniture (tools/eclipse/underground_furniture.py) and its candles' wicks.
const FURNITURE_KIT := "res://assets/eclipse/kit/underground_furniture.glb"
const FURNITURE_WICKS := "res://assets/eclipse/source/underground_furniture_wicks.json"
## The steamer's lid knob on the cart, in the cart's own axes (the kit's POT_TOP, Godot's way round).
const POT_LOCAL := Vector3(0.15, 1.51, 0.0)
## The niche's shelf on the wall (the kit's NICHE_SILL).
const NICHE_SILL := 1.05
## The bench's seat (the kit's BENCH_SEAT).
const BENCH_SEAT := 0.45
const STEAM_HISS := "res://audio/ambience/steam_hiss.wav"
## Where the vent breathes, along the back wall past her stall, in the work light's reach.
const VENT_X := 3.6
const VENT_HUM := "res://audio/ambience/vent_hum.wav"
## The tiled floor (tools/eclipse/underground_floor.py): its modules' size, how deep its tiles and
## their bed go under the floor, the drain's middle in its module's own axes; the corridor is
## 20 modules long and 5 deep with a narrow edge row (0.9 m) against the far wall.
const FLOOR_KIT := "res://assets/eclipse/kit/underground_floor.glb"
const MODULE := 1.2
const EDGE_DEPTH := 0.9
const TILE_DEPTH := 0.12
const DRAIN_LOCAL := Vector3(0.6, 0.0, -0.6)
## The uncanny kit (tools/eclipse/underground_uncanny.py): the nahual lying by the bench's west end,
## its head toward the corridor; the old man's hat on the bench by his paper.
const UNCANNY_KIT := "res://assets/eclipse/kit/underground_uncanny.glb"
const NAHUAL_AT := Vector3(-5.0, 0.0, 4.35)
## Enormous, as the tellings have it: the kit's dog made half again as big (about 1.7 m long lying).
const NAHUAL_SCALE := 1.35
const SPECTRE := preload("res://scripts/Visual/spectre.gdshader")
const HAT_AT := Vector3(-3.9, 0.45, 4.25)
const EMBER := Color("ff5a1e")
## The gaps between the drain's grate bars, along the grate (m from its middle): the floor kit's
## bars (tools/eclipse/underground_floor.py _drain) leave 12 of them, 4 cm apart.
## Which way the niche's candles are open, and how far off their flames a hand keeps (m).
const NICHE_OPEN := Vector3(0.0, 0.0, -0.2)
## Her shrine's candles reached from this far in front of it (m), the wrist this far above the flame's height;
## how far round her stall's corner they go.
const SHRINE_CLEAR := 0.16
const SHRINE_LIFT := 0.06
const STALL_ROUND := 0.35
const GRATE_LANES := [-0.22, -0.18, -0.14, -0.1, -0.06, -0.02, 0.02, 0.06, 0.1, 0.14, 0.18, 0.22]
## The drain's column, beside her stall where the conduit's water pools; the worn modules' cells.
const DRAIN_COLUMN := 8
## The tiled walls (tools/eclipse/underground_walls.py): how far the tiles' face stands off the
## wall behind them (BACK_WALL and FAR_WALL are the tiles' face, where everything hangs); the
## crack's opening along its panel (where the marigold trail ends), its column; the worn panels.
const WALL_KIT := "res://assets/eclipse/kit/underground_walls.glb"
const WALL_FACE := 0.067
const CRACK_X := Vector2(0.36, 0.84)
const CRACK_COLUMN := 5
const WORN_BACK := [2, 9, 14, 17]
const WORN_FAR := [1, 6, 12, 18]
## The vault's plaster (tools/eclipse/underground_vault.py): its spans and their thickness under the vault.
const VAULT_KIT := "res://assets/eclipse/kit/underground_vault.glb"
const VAULT_SPAN := 4.8
const VAULT_PLASTER := 0.04
const WORN := [Vector2i(2, 1), Vector2i(5, 3), Vector2i(11, 4), Vector2i(13, 2), Vector2i(16, 1), Vector2i(18, 3)]
const RUMBLE_DB := -4.0
const RATTLES := ["res://audio/sfx/jars_rattle_1.wav", "res://audio/sfx/jars_rattle_2.wav"]
const SHELVES_AT := Vector3(0.0, 1.4, -1.9)
## How far the lights sag when it runs by (a share of their power), how hard its gust swings the bulb.
const BROWNOUT := Vector2(0.25, 0.3)
const GUST_SWING := 2.0
const SIGN := Vector3(0.0, 2.65, 0.6)
const JUNCTION_TOP := Vector3(1.5, 2.85, -2.17)
const CONDUIT := Vector3(0.0, 3.25, -2.17)
const SODIUM := Color(1.0, 0.76, 0.5)
const BULB_COLOUR := Color(1.0, 0.76, 0.48)
## The sign's colour until the user gives the sign its words and colour.
const NEON_COLOUR := Color(1.0, 0.3, 0.6)
const TILE := Color(0.42, 0.45, 0.46)
const LINE_2 := Color(0.16, 0.3, 0.55)
const FLOOR := Color(0.2, 0.19, 0.18)

## How far the corridor runs each way from its middle (m: the bay's RUN; a map built on it, the candle lane, runs it
## longer), and where the pieces that move with it stand: the tamale cart (her stool beside it), the bench (the news on
## it, the bin and cone by it, the old hat at its end), the Virgin's niche (and which way it faces: π on the far wall,
## 0 on the back), the nahual at the far wall's foot. Set before _ready.
var half_run := RUN
var places := {"cart": Vector3(4.2, 0.0, 2.6), "bench": Vector3(-2.4, 0.0, FAR_WALL), "niche": Vector3(1.2, 0.0, FAR_WALL),
	"niche_yaw": PI, "nahual": NAHUAL_AT}

## Where the piece and its painted files are.
var lab_dir := "res://assets/eclipse/lab/"
var atlas_dir := "res://textures/painted/underground/"
var missing := PackedStringArray()

var stall: Node3D
var neon: NeonSign
var bulb: OmniLight3D
var bulb_pivot: Sway
var censer: Node3D
var dust: Array[Node3D] = []
var hum: AudioStreamPlayer3D
var flames: Node3D
var neon_wash: Decal
var next_spark := 0.0
var shafts: Array[FogVolume] = []
var drip: GPUParticles3D
var puddle: Decal
var drip_sound: AudioStreamPlayer3D
var moths: Moths
var train: TrainPass
var crowd: Crowd
var junction_hum: AudioStreamPlayer3D
var clutter: Array[MeshInstance3D] = []
var services: Array[MeshInstance3D] = []
var _service_meshes := {}
var _service_material: ShaderMaterial
var furniture: Array[MeshInstance3D] = []
var floor_tiles: Array[MeshInstance3D] = []
var animas: Node3D
var procession: Node3D
var ownerless: Node3D
var dark_train: TrainPass
var dark_wind: AudioStreamPlayer
var nahual: Node3D
var old_hat: MeshInstance3D
var wall_panels: Array[MeshInstance3D] = []
var vault_spans: Array[MeshInstance3D] = []
var cart_steam: Node3D
var cart_hiss: AudioStreamPlayer3D
var niche_flames: Node3D
var niche_wicks: Array[Vector3] = []
var vent_breath: Node3D
var vent_hum: AudioStreamPlayer3D
var _kit_meshes := {}
var _kit_material: ShaderMaterial
var rumble: AudioStreamPlayer
var dust_sift: GPUParticles3D
var rattles := 0
var _full := {}
var _rattle: AudioStreamPlayer3D
var _clock := 0.0
var _sparks := RandomNumberGenerator.new()
var work_lights: Array[Light3D] = []
## Each work lamp's light coming back up off the tiles onto the ceiling (a child of its lamp, so F1 and F2 take it).
var bounce_lights: Array[OmniLight3D] = []
var form_light: DirectionalLight3D
var form_material: StandardMaterial3D
var decals: Array[Decal] = []
var player: Node3D
var world: WorldEnvironment
var keys_label: Label

var _form := false
## Embedded rooms manage their own material overrides during inspection.
var inspection_sections: Array[Node3D] = []
var _work_on := true
## Set into a larger map (maps/metro: the candle lane): its player is the map's (`host_player`), and the bay keeps
## none of its own environment or key help (the map has its own). Set before _ready.
var embedded := false
var host_player: Node3D


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	if not embedded:
		_environment()
	_corridor()
	_stall()
	_lights()
	_tiles()
	_walls()
	_decals()
	_clutter()
	_services()
	_furnish()
	_effects()
	if not embedded:
		_keys()
	if host_player != null:
		player = host_player
	else:
		player = PLAYER.instantiate()
		player.debug_traversal = false
		add_child(player)
		player.global_position = Vector3(0.0, 1.05, 4.0)
	# (After the player: the uncanny shy from it, and watch it.)
	_dark_train()
	_animas()
	_procession()
	_ownerless()
	_nahual()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_F1:
			set_work_lights(not _work_on)
		KEY_F2:
			set_form(not _form)
		KEY_F3:
			set_decals(not decals[0].visible)
		KEY_F4:
			train.start_pass()
		KEY_F5:
			if dark_train != null:
				dark_train.start_pass()
		KEY_F9:
			if procession != null and not procession.walking:
				procession.start()


func set_work_lights(on: bool) -> void:
	_work_on = on
	for light in work_lights:
		light.visible = on and not _form

	_name_keys()


## The form light: every mesh of the bay a neutral grey under one white
## light, the work lights off; or everything as it was.
func set_form(on: bool) -> void:
	if on == _form:
		return
	_form = on

	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if inspection_sections.any(func(section): return section.is_ancestor_of(mesh)):
			continue
		if is_instance_valid(player) and player.is_ancestor_of(mesh):
			continue

		# (Effects are drawn by their own shaders and cast no shadow: the form light greys props only.)
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mesh.mesh != null \
				and (mesh.get_surface_override_material(0) is ShaderMaterial or mesh.mesh.surface_get_material(0) is ShaderMaterial):
			continue

		if on:
			mesh.material_override = form_material
		elif neon != null and mesh == neon.tube:
			mesh.material_override = neon.tube_material()
		else:
			mesh.material_override = null

	form_light.visible = on
	# Nothing coloured lights the grey: the bulb and the neon's glow go dark too.
	bulb.visible = not on

	if neon != null:
		neon.light.visible = not on

	for light in work_lights:
		light.visible = _work_on and not on
	_name_keys()


func set_decals(on: bool) -> void:
	for d in decals:
		d.visible = on

	_name_keys()


# The stall

func _stall() -> void:
	var path := lab_dir + "stall.glb"

	if not ResourceLoader.exists(path):
		missing.append(path)
		push_warning("underground lab: %s is not built (tools/eclipse/lab.sh stall)" % path)
		return

	stall = (load(path) as PackedScene).instantiate()
	stall.name = "stall"
	add_child(stall)
	var atlas := _painted(["stall.png", "stall_base.png"])
	var painted := Painterly.material(atlas, &"bespoke")
	var tube: MeshInstance3D = null

	for mesh: MeshInstance3D in stall.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var slot: Material = mesh.mesh.surface_get_material(i)
			var slot_name := slot.resource_name if slot != null else ""

			if slot_name == "glass":
				mesh.set_surface_override_material(i, _glass())
			elif slot_name != "neon":
				mesh.set_surface_override_material(i, painted)

		if mesh.name == "stall_neon":
			tube = mesh
		elif mesh.name != "stall_bulb":
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = mesh.mesh.create_trimesh_shape()
			body.add_child(shape)
			mesh.add_child(body)

	# The neon tube lit by its own sign, which takes the first mesh it holds as its tube.
	neon = NeonSign.new()
	neon.name = "neon"
	neon.colour = NEON_COLOUR
	neon.pattern = "mmmmmmmmmmmmmmmammmmmmmmmzmmmmmmmmmmmmmmmmmaam"
	neon.seed = 11
	neon.light_energy = 0.35
	neon.light_range = 2.0

	if tube != null:
		tube.get_parent().remove_child(tube)
		neon.add_child(tube)

	var glow := OmniLight3D.new()
	glow.name = "light"
	neon.add_child(glow)
	glow.position = SIGN
	stall.add_child(neon)


## A painted file as a texture; `alpha` keeps its transparency (a decal's,
## without which it draws as a dark box).
func _painted(names: Array, alpha := false) -> Texture2D:
	for file in names:
		var path: String = atlas_dir + file

		# The imported texture, as an exported game has it; a file Godot has
		# not imported yet (just painted) read straight from disk meanwhile.
		if ResourceLoader.exists(path):
			return load(path) as Texture2D

		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			image.convert(Image.FORMAT_RGBA8 if alpha else Image.FORMAT_RGB8)
			image.generate_mipmaps()
			return ImageTexture.create_from_image(image)

	missing.append(atlas_dir + String(names[-1]))
	return null


func _glass() -> StandardMaterial3D:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.albedo_color = Color(0.66, 0.78, 0.74, 0.32)
	glass.roughness = 0.1
	glass.metallic_specular = 0.8
	return glass


# The corridor, greybox until its own kit

## How many tile modules a longer corridor adds at each end: column indices counted from the bay's own west end.
func _shift() -> int:
	return int(round((half_run - RUN) / MODULE))


func _corridor() -> void:
	var tile := _flat(TILE)
	# The floor under the tiles (_tiles lays them); walked on at the tiles' tops.
	_box(Vector3(-half_run, -0.2 - TILE_DEPTH, BACK_WALL - WALL), Vector3(half_run, -TILE_DEPTH, FAR_WALL + WALL), _flat(FLOOR), "floor")
	var walked := StaticBody3D.new()
	walked.name = "floor_walked"
	var top := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(2.0 * half_run, TILE_DEPTH, FAR_WALL - BACK_WALL + 2.0 * WALL)
	top.shape = slab
	walked.add_child(top)
	add_child(walked)
	walked.position = Vector3(0.0, -TILE_DEPTH / 2.0, (BACK_WALL + FAR_WALL) / 2.0)
	# The walls themselves, set back behind their tiles (_walls hangs them).
	_box(Vector3(-half_run, 0.0, BACK_WALL - WALL_FACE - WALL), Vector3(half_run, HEIGHT, BACK_WALL - WALL_FACE), tile, "back_wall")
	_box(Vector3(-half_run, 0.0, FAR_WALL + WALL_FACE), Vector3(half_run, HEIGHT, FAR_WALL + WALL_FACE + WALL), tile, "far_wall")
	# The vault itself, over its plaster (_walls lays the plaster).
	_box(Vector3(-half_run - WALL_FACE - WALL, HEIGHT + VAULT_PLASTER, BACK_WALL - WALL),
		Vector3(half_run + WALL_FACE + WALL, HEIGHT + VAULT_PLASTER + 0.2, FAR_WALL + WALL), tile, "vault")

	# The end walls, set back behind their tiles too.
	for x in [-half_run - WALL_FACE - WALL, half_run + WALL_FACE]:
		_box(Vector3(x, 0.0, BACK_WALL - WALL), Vector3(x + WALL, HEIGHT, FAR_WALL + WALL), tile, "end_%d" % x)




func _flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	return m


func _box(lo: Vector3, hi: Vector3, material: Material, node_name: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = hi - lo
	mesh.mesh = box
	mesh.material_override = null
	box.material = material
	add_child(mesh)
	mesh.position = (lo + hi) / 2
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = hi - lo
	shape.shape = solid
	body.add_child(shape)
	mesh.add_child(body)


# The light

func _environment() -> void:
	# A cool fill under the warm lamps: the colours separate, warm against cool.
	var environment := RetroScript.night_environment(Color(0.36, 0.44, 0.58), 0.28)
	environment.volumetric_fog_density = 0.02
	world = WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _lights() -> void:
	for x in [-2.8, 2.8]:
		var light := OmniLight3D.new()
		light.name = "work_%d" % int(x)
		light.light_color = SODIUM
		light.light_energy = 2.6
		light.omni_range = 9.0
		light.shadow_enabled = true
		# (A shaded lamp: its light falls below its shade, never on the vault over it.)
		light.light_cull_mask &= ~Layers.SHADED_ABOVE
		add_child(light)
		light.position = Vector3(x, HEIGHT - 0.4, 2.2)
		work_lights.append(light)
		_bounce(light)
		_box(light.position + Vector3(-0.25, 0.25, -0.12), light.position + Vector3(0.25, 0.4, 0.12),
			_flat(Color(0.1, 0.1, 0.1)), "fixture_%d" % int(x))

	bulb_pivot = Sway.new()
	bulb_pivot.name = "bulb_pivot"
	bulb_pivot.draught = DRAUGHT
	bulb_pivot.seed = 7
	add_child(bulb_pivot)
	bulb_pivot.position = BULB_PIVOT
	var hanging: Node3D = stall.find_child("stall_bulb", true, false) if stall != null else null

	if hanging != null:
		hanging.reparent(bulb_pivot, true)

	bulb = OmniLight3D.new()
	bulb.name = "bulb"
	bulb.light_color = BULB_COLOUR
	bulb.light_energy = 0.9
	bulb.omni_range = 3.5
	bulb.shadow_enabled = true
	bulb_pivot.add_child(bulb)
	bulb.position = BULB - BULB_PIVOT

	form_light = DirectionalLight3D.new()
	form_light.name = "form_light"
	form_light.light_energy = 1.2
	# No shadow: the corridor's vault would put the whole bay in it.
	form_light.shadow_enabled = false
	form_light.visible = false
	add_child(form_light)
	form_light.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	form_material = StandardMaterial3D.new()
	form_material.albedo_color = Color(0.6, 0.6, 0.6)
	form_material.roughness = 1.0


## A shaded lamp's light coming back up off the lit tiles: soft, unshadowed, low over the floor, lighting only the
## ceiling (its shade keeps the lamp's own light off it), so the ceiling reads as one, warm and dim, not a night sky.
func _bounce(lamp: OmniLight3D) -> void:
	var up := OmniLight3D.new()
	up.name = "bounce"
	up.light_color = SODIUM.darkened(0.25)
	up.light_energy = 0.9
	up.omni_range = 6.0
	up.omni_attenuation = 0.7
	up.shadow_enabled = false
	up.light_cull_mask = Layers.SHADED_ABOVE
	lamp.add_child(up)
	up.position = Vector3(0.0, 0.6 - lamp.position.y, 0.0)
	bounce_lights.append(up)


# The effects: copal off the censer, dust in the work lights, the neon's hum

func _effects() -> void:
	censer = Vfx.system("censer")
	add_child(censer)
	censer.position = CENSER
	Vfx.blow(censer, DRAUGHT)
	Vfx.emit(censer, true)

	for light in work_lights:
		var motes: Node3D = Vfx.system("dust")
		add_child(motes)
		motes.position = light.position - Vector3(0.0, 2.0, 0.0)
		Vfx.emit(motes, true)
		dust.append(motes)

	_candle_flames()
	_neon_wash()
	_sparks.seed = 23
	next_spark = _sparks.randf_range(SPARKS_EVERY.x, SPARKS_EVERY.y)
	_shafts()
	_drip()
	_train()
	crowd = Crowd.new()
	crowd.name = "crowd"
	crowd.seed = 41
	add_child(crowd)
	junction_hum = AudioStreamPlayer3D.new()
	junction_hum.name = "junction_hum"
	junction_hum.stream = load(BOX_HUM)
	junction_hum.max_distance = 5.0
	junction_hum.unit_size = 1.0
	junction_hum.volume_db = -6.0
	junction_hum.autoplay = true
	add_child(junction_hum)
	junction_hum.position = JUNCTION_TOP
	moths = Moths.new()
	moths.name = "moths"
	moths.seed = 5
	moths.around = bulb
	add_child(moths)

	if neon != null:
		hum = AudioStreamPlayer3D.new()
		hum.name = "hum"
		hum.stream = load(HUM)
		hum.max_distance = 8.0
		hum.unit_size = 2.0
		hum.autoplay = true
		neon.add_child(hum)
		hum.position = SIGN


## The hum's loudness (dB) for the tube's level (0 dark, 1 full).
func hum_volume(level: float) -> float:
	return HUM_DB + linear_to_db(lerpf(HUM_DARK, 1.0, clampf(level, 0.0, 1.0)))


func _process(delta: float) -> void:
	if hum != null and neon != null:
		hum.volume_db = hum_volume(neon.level())

	if neon_wash != null and neon != null:
		neon_wash.emission_energy = WASH_ENERGY * neon.level()

	next_spark -= delta

	if next_spark <= 0.0:
		spark()

	_breathe(delta)


## The metro breathing: everything answers the passing train's strength.
func _breathe(delta: float) -> void:
	if train == null:
		return

	_clock += delta
	var s := train.strength()
	# The dark train: no rumble, no brownout; every light sinks smoothly, the candles gutter.
	var d := dark_train.strength() if dark_train != null else 0.0
	# The lights sag unevenly as the train draws on the Company's line.
	var dip := clampf(0.5 + 0.5 * sin(_clock * 23.0) * sin(_clock * 7.3 + 1.1), 0.0, 1.0)
	var sag := (1.0 - s * (BROWNOUT.x + BROWNOUT.y * dip)) * (1.0 - DARK_SINK * d)

	for light: Light3D in _full:
		light.light_energy = _full[light] * sag

	if neon != null:
		neon.dim = sag

	bulb_pivot.gust = GUST_SWING * maxf(s, 1.6 * d)
	var draught := DRAUGHT * (1.0 + 4.0 * s) + DARK_DRAUGHT * d
	Vfx.blow(censer, draught)

	if vent_breath != null:
		Vfx.blow(vent_breath, draught)

	for motes in dust:
		Vfx.blow(motes, draught)

	for candles in [flames, niche_flames]:
		if candles != null:
			_gutter(candles, d)
			Vfx.blow(candles, draught)

	if animas != null:
		animas.hush = d

	if dark_wind != null:
		dark_wind.volume_db = DARK_WIND_DB + linear_to_db(maxf(d, 0.001))

	dust_sift.amount_ratio = clampf((s - 0.3) / 0.7, 0.0, 1.0)

	if crowd != null:
		crowd.duck = s
	rumble.volume_db = RUMBLE_DB + linear_to_db(maxf(s, 0.001))


## A cluster's flames guttered (0 none, 1 nearly out), their light with them.
func _gutter(candles: Node3D, amount: float) -> void:
	for draw: MultiMeshInstance3D in candles.find_children("*", "MultiMeshInstance3D", false, false):
		draw.set_meta("gutter", amount)
		(draw.multimesh.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter(&"gutter", amount)

	# (Their light is their flicker's, VfxFlicker.energy.)
	if "energy" in candles:
		if not candles.has_meta("full"):
			candles.set_meta("full", candles.energy)
		candles.energy = float(candles.get_meta("full")) * (1.0 - 0.75 * amount)


## The dark train: no light, no wheels, only Ehécatl's wind through the line.
func _dark_train() -> void:
	dark_train = TrainPass.new()
	dark_train.name = "dark_train"
	dark_train.seed = 913
	dark_train.every = DARK_EVERY
	add_child(dark_train)
	dark_wind = AudioStreamPlayer.new()
	dark_wind.name = "dark_wind"
	dark_wind.stream = load(DARK_WIND)
	dark_wind.volume_db = -80.0
	add_child(dark_wind)
	dark_train.began.connect(dark_wind.play)


## The train, its rumble, the dust its shaking sifts from the vault, the jars' rattle.
func _train() -> void:
	train = TrainPass.new()
	train.name = "train"
	train.seed = 31
	add_child(train)

	for light in work_lights + bounce_lights + [bulb]:
		_full[light] = light.light_energy

	rumble = AudioStreamPlayer.new()
	rumble.name = "rumble"
	rumble.stream = load(RUMBLE)
	rumble.volume_db = -80.0
	add_child(rumble)
	train.began.connect(rumble.play)

	_rattle = AudioStreamPlayer3D.new()
	_rattle.name = "rattle"
	_rattle.max_distance = 10.0
	add_child(_rattle)
	_rattle.position = SHELVES_AT
	train.peaked.connect(func():
		_rattle.stream = load(RATTLES[rattles % RATTLES.size()])
		_rattle.play()
		rattles += 1)

	dust_sift = GPUParticles3D.new()
	dust_sift.name = "dust_sift"
	dust_sift.amount = 240
	dust_sift.lifetime = 7.0
	dust_sift.amount_ratio = 0.0
	dust_sift.local_coords = false
	var fall := ParticleProcessMaterial.new()
	fall.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	fall.emission_box_extents = Vector3(RUN * 0.5, 0.02, (FAR_WALL - BACK_WALL) * 0.5)
	fall.gravity = Vector3(0, -0.6, 0)
	fall.damping_min = 0.3
	fall.damping_max = 0.6
	# (What lands on the canvas stays on it: none falls through the cloth.)
	fall.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	dust_sift.process_material = fall
	var speck := QuadMesh.new()
	speck.size = Vector2(0.02, 0.02)
	var grit := StandardMaterial3D.new()
	grit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grit.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grit.albedo_color = Color(0.55, 0.5, 0.42, 0.6)
	grit.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	speck.material = grit
	dust_sift.draw_pass_1 = speck
	dust_sift.visibility_aabb = AABB(Vector3(-RUN * 0.5, -HEIGHT, -3.5), Vector3(RUN, HEIGHT + 0.5, 7.0))
	add_child(dust_sift)
	dust_sift.position = Vector3(0.0, HEIGHT - 0.05, (FAR_WALL + BACK_WALL) * 0.5)
	dust_sift.emitting = true
	var canvas := GPUParticlesCollisionBox3D.new()
	canvas.name = "canvas_catch"
	canvas.size = Vector3(3.3, 0.12, 2.5)
	add_child(canvas)
	canvas.position = Vector3(0.0, 2.45, -1.0)


## The junction's bodged tap throws a few sparks, and the next is reckoned.
func spark() -> void:
	FireParticles.emit(self, &"spark", JUNCTION_TOP + Vector3(-0.05, -0.08, 0.06), _sparks.randi_range(5, 9), DRAUGHT,
		Color(1.0, 0.85, 0.55))
	next_spark = _sparks.randf_range(SPARKS_EVERY.x, SPARKS_EVERY.y)


## A flame on each of the stall's lit wicks, their light flickering over them.
func _candle_flames() -> void:
	if not FileAccess.file_exists(WICKS):
		return

	var wicks: Array = []

	for list in (JSON.parse_string(FileAccess.get_file_as_string(WICKS)) as Dictionary).values():
		wicks += list

	if wicks.is_empty():
		return

	var middle := Vector3.ZERO

	for w in wicks:
		middle += Vector3(w[0], w[1], w[2]) / wicks.size()

	flames = Vfx.system("candles")
	add_child(flames)
	Vfx.place(flames, middle, {"wicks": wicks})
	Vfx.emit(flames, true)


## The neon's own glow washed over its sign's face: an emissive decal,
## pulsing with the tube.
func _neon_wash() -> void:
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 0.0)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	glow.gradient = fade
	neon_wash = Decal.new()
	neon_wash.name = "neon_wash"
	neon_wash.size = Vector3(SIGN_SIZE.x, 0.2, SIGN_SIZE.y * 2.0)
	neon_wash.texture_emission = glow
	neon_wash.modulate = NEON_COLOUR
	neon_wash.emission_energy = WASH_ENERGY
	neon_wash.albedo_mix = 0.0
	add_child(neon_wash)
	neon_wash.position = SIGN_FACE + Vector3(0, 0, 0.08)
	neon_wash.rotation_degrees = Vector3(90, 0, 0)


## The work lights' beams in the air: a cone of haze under each, its point at the lamp.
func _shafts() -> void:
	for light in work_lights:
		var cone := FogVolume.new()
		cone.name = "shaft"
		cone.shape = RenderingServer.FOG_VOLUME_SHAPE_CONE
		cone.size = Vector3(2.2, 3.4, 2.2)
		var haze := FogMaterial.new()
		haze.density = 0.6
		haze.albedo = Color(1.0, 0.86, 0.66)
		haze.edge_fade = 0.6
		cone.material = haze
		add_child(cone)
		cone.position = light.position - Vector3(0, 1.7, 0)
		shafts.append(cone)


## Water off the conduit: a drop every so often, falling to a puddle, heard.
func _drip() -> void:
	drip = GPUParticles3D.new()
	drip.name = "drip"
	drip.amount = 3
	drip.lifetime = 0.85
	drip.fixed_fps = 60
	drip.local_coords = false
	var fall := ParticleProcessMaterial.new()
	fall.gravity = Vector3(0, -9.8, 0)
	fall.direction = Vector3.DOWN
	fall.initial_velocity_min = 0.0
	fall.initial_velocity_max = 0.05
	drip.process_material = fall
	var drop := QuadMesh.new()
	drop.size = Vector2(0.012, 0.045)
	var water := StandardMaterial3D.new()
	water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color = Color(0.75, 0.85, 0.95, 0.7)
	water.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = water
	drip.draw_pass_1 = drop
	drip.visibility_aabb = AABB(Vector3(-0.5, -3.5, -0.5), Vector3(1, 4, 1))
	add_child(drip)
	drip.position = DRIP_AT
	drip.emitting = true

	puddle = Decal.new()
	puddle.name = "puddle"
	puddle.size = Vector3(0.7, 0.3, 0.5)
	puddle.texture_albedo = _painted(["decal_grime.png"], true)
	puddle.modulate = Color(0.32, 0.38, 0.45)
	add_child(puddle)
	puddle.position = Vector3(DRIP_AT.x, 0.0, DRIP_AT.z + 0.1)

	drip_sound = AudioStreamPlayer3D.new()
	drip_sound.name = "drip_sound"
	drip_sound.stream = load(DRIP_SOUND)
	drip_sound.max_distance = 10.0
	drip_sound.unit_size = 1.5
	drip_sound.autoplay = true
	add_child(drip_sound)
	drip_sound.position = puddle.position


# What lies on the floor, staged as scenes, each with its cause

func _clutter() -> void:
	if not ResourceLoader.exists(GROUND_KIT):
		missing.append(GROUND_KIT)
		return

	_kit_meshes = _kit(GROUND_KIT)
	_kit_material = Painterly.material(_painted(["underground_ground.png", "underground_ground_base.png"]), &"bespoke")

	# Her customers drop their emptied cones and cups by the counter.
	_lay("cone_crushed", Vector3(-0.4, 0.0, 0.55), 0.7)
	_lay("cone_crushed", Vector3(0.15, 0.0, 0.78), 2.1)
	_lay("jarrito", Vector3(-0.15, 0.0, 0.42), 1.0)
	# Commuters' newspapers, one dropped open, one folded and forgotten by the far wall.
	_lay("news_spread", Vector3(-3.6, 0.0, 1.7), 0.3)
	_lay("news_folded", Vector3(3.4, 0.0, 3.9), -0.6)
	# Her stock against the wall, kept along past the drip's wet.
	_lay("crate_corn", Vector3(-3.15, 0.0, -1.98), 0.1)
	_lay("crate", Vector3(-3.72, 0.0, -2.0), -0.05)
	_lay("crate", Vector3(-3.7, 0.3, -2.0), 0.12)
	_lay("sack_slumped", Vector3(-4.25, 0.0, -2.08), 0.4)
	_lay("sack_lying", Vector3(-3.45, 0.0, -1.55), 1.4)
	# Her power drops from the junction box beside the post and runs on along the wall's foot,
	# taped off where the next stall will stand, its spare coiled.
	_lay("cable_run", CABLE_AT, 0.0)
	# Her grandchild's top, left in her aisle.
	_lay("trompo", Vector3(-0.3, 0.0, -1.5), 2.4)

	# The marigold trail she lays for her dead, from her ofrenda across the floor to the wall:
	# loose petals strewn thick along it, whole heads dropped among them in twos and threes.
	var heads := []

	for i in TRAIL_HEADS:
		var ends := i == 0 or i == TRAIL_HEADS - 1
		var t := clampf(float(i) / (TRAIL_HEADS - 1) + (0.0 if ends else sin(i * 3.7) * 0.025), 0.0, 1.0)
		var at := _trail(t)
		var across := _trail_tangent(t).cross(Vector3.UP).normalized()
		heads.append(at + across * (0.0 if ends else sin(i * 2.3) * 0.09))

	heads.sort_custom(func(a, b): return a.distance_to(TRAIL_END) > b.distance_to(TRAIL_END))

	for i in heads.size():
		_lay("marigold_head", heads[i], i * 1.9)

	for i in TRAIL_PATCHES:
		var t := (i + 0.5) / TRAIL_PATCHES
		var ahead := _trail_tangent(t)
		var patch := _decal("petals", _trail(t), Vector3(0.8, 0.3, 0.45), Vector3(0, rad_to_deg(atan2(-ahead.z, ahead.x)), 0))
		patch.name = "decal_petals_%d" % i


## The marigold trail at `t` (0 at her ofrenda, 1 at the wall): a curve bowed out into the corridor.
func _trail(t: float) -> Vector3:
	return TRAIL_START.lerp(TRAIL_BEND, t).lerp(TRAIL_BEND.lerp(TRAIL_END, t), t)


func _trail_tangent(t: float) -> Vector3:
	return (TRAIL_BEND - TRAIL_START).lerp(TRAIL_END - TRAIL_BEND, t).normalized()


## One of the floor kit's pieces laid at `at`, turned `yaw` about the vertical;
## stock solid to walk against, litter not.
func _lay(kind: String, at: Vector3, yaw: float) -> MeshInstance3D:
	var piece := _place(_kit_meshes[kind], _kit_material, kind, at, yaw, kind in STOCK)
	clutter.append(piece)
	return piece


## The meshes of an exported kit by piece name.
func _kit(path: String) -> Dictionary:
	var meshes := {}
	var kit: Node3D = (load(path) as PackedScene).instantiate()

	for mesh: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		meshes[String(mesh.name)] = mesh.mesh

	kit.free()
	return meshes


## A kit piece set at `at`, turned `yaw` about the vertical, solid if asked.
func _place(mesh: Mesh, material: Material, kind: String, at: Vector3, yaw: float, solid: bool) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = kind
	piece.mesh = mesh
	piece.set_meta("kind", kind)

	for i in piece.mesh.get_surface_count():
		var slot: Material = piece.mesh.surface_get_material(i)
		var glazed := slot != null and slot.resource_name.begins_with("glass")
		piece.set_surface_override_material(i, _glass() if glazed else material)

	add_child(piece, true)
	piece.position = at
	piece.rotation.y = yaw

	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = piece.mesh.create_convex_shape()
		body.add_child(shape)
		piece.add_child(body)

	return piece


# The services along the walls, in the Company's colours

func _services() -> void:
	if not ResourceLoader.exists(SERVICES_KIT):
		missing.append(SERVICES_KIT)
		return

	_service_meshes = _kit(SERVICES_KIT)
	_service_material = Painterly.material(_painted(["underground_services.png", "underground_services_base.png"]), &"bespoke")

	# The back wall. The water main, its lengths jointed so one joint weeps over the wall
	# beside her stall (the drip, DRIP_AT); it runs on into the end walls.
	for run in [[-12.3, "pipe_green_2"], [-10.3, "pipe_green_4"], [-6.3, "pipe_green_4"], [-2.3, "pipe_green_4"],
			[1.7, "pipe_green_4"], [5.7, "pipe_green_4"], [9.7, "pipe_green_2"], [11.7, "pipe_green_2"]]:
		_hang(run[1], Vector3(run[0], CONDUIT.y, BACK_WALL), false)

	# The gas line below it, its joints falling elsewhere.
	for i in 7:
		_hang("pipe_ochre_4", Vector3(-13.3 + 4.0 * i, GAS_Y, BACK_WALL), false)

	# The Company's tray above, its bundle of power; over her stall, where her power was tapped,
	# a cable has come loose and hangs out in a loop.
	for i in 7:
		_hang("cable_tray_4_spill" if i == 3 else "cable_tray_4", Vector3(-13.0 + 4.0 * i, TRAY_Y, BACK_WALL), false)

	# Her power, up from the junction box on her stall's post into the tray.
	_hang("conduit_drop", JUNCTION_TOP, false)

	# The far wall, its pieces turned to face back across the corridor (they run toward -x).
	# The fire main, a gate valve in it, ending in a hydrant low on the wall by the end wall.
	for run in [[13.0, "pipe_red_4"], [9.0, "pipe_red_valve"], [5.0, "pipe_red_4"], [1.0, "pipe_red_4"],
			[-3.0, "pipe_red_4"], [-7.0, "pipe_red_4"], [-11.0, "pipe_red_drop"]]:
		_hang(run[1], Vector3(run[0], FIRE_Y, FAR_WALL), true, run[1] == "pipe_red_drop")

	# The air line below it.
	for i in 7:
		_hang("pipe_blue_4", Vector3(14.5 - 4.0 * i, AIR_Y, FAR_WALL), true)

	# Heavy cables swagged on hooks high under the vault, out of the end walls and back into them.
	for i in 9:
		_hang("cable_swag", Vector3(13.0 - 3.0 * i, HOOK_Y, FAR_WALL), true)

	if half_run > RUN + 0.01:
		_run_on()


## A corridor longer than the bay: each line of services run on past the bay's own lengths to its ends, in its plain
## module, joint to joint (the fire main past its hydrant's drop, which becomes a branch off it).
func _run_on() -> void:
	for line in [["pipe_green_4", CONDUIT.y, false], ["pipe_ochre_4", GAS_Y, false], ["cable_tray_4", TRAY_Y, false],
			["pipe_red_4", FIRE_Y, true], ["pipe_blue_4", AIR_Y, true], ["cable_swag", HOOK_Y, true]]:
		var wall: float = FAR_WALL if line[2] else BACK_WALL
		var reach := Vector2(INF, -INF)
		var plain: Array[MeshInstance3D] = []
		for piece: MeshInstance3D in services:
			var box := piece.transform * piece.get_aabb()
			if absf(piece.position.y - line[1]) < 0.01 and absf(piece.position.z - wall) < 0.01:
				reach = Vector2(minf(reach.x, box.position.x), maxf(reach.y, box.end.x))
				if String(piece.get_meta("kind", "")) == line[0]:
					plain.append(piece)
		if reach.x == INF:
			continue
		var size: float = (_service_meshes[line[0]] as Mesh).get_aabb().size.x
		# Each way to the corridor's end exactly: whole modules, all drawn out (or in) alike to fill it; or, less than
		# half a module short, the line's last module drawn out to meet it.
		for way: float in [1.0, -1.0]:
			var from: float = reach.y if way > 0.0 else reach.x
			var gap := half_run - from * way
			if gap < 0.01:
				continue
			if gap < size / 2.0:
				var last: MeshInstance3D = null
				for piece in plain:
					var at := (piece.transform * piece.get_aabb()).get_center().x
					if last == null or at * way > (last.transform * last.get_aabb()).get_center().x * way:
						last = piece
				if last != null:
					_stretch(last, gap, way)
				continue
			var count := maxi(1, roundi(gap / size))
			for k in count:
				var piece := _hang(line[0], Vector3(from, line[1], wall), line[2])
				piece.scale.x = gap / (count * size)
				var box := piece.transform * piece.get_aabb()
				piece.position.x += from - (box.position.x if way > 0.0 else box.end.x)
				from += way * box.size.x


## A run's last module drawn out `by` toward `way` (+1 or -1 along x), its inner end kept where it was.
func _stretch(piece: MeshInstance3D, by: float, way: float) -> void:
	var box := piece.transform * piece.get_aabb()
	var inner := box.position.x if way > 0.0 else box.end.x
	piece.scale.x *= (box.size.x + by) / box.size.x
	box = piece.transform * piece.get_aabb()
	piece.position.x += inner - (box.position.x if way > 0.0 else box.end.x)


# The corridor's furniture, each piece with its cause

func _furnish() -> void:
	if not ResourceLoader.exists(FURNITURE_KIT):
		missing.append(FURNITURE_KIT)
		return

	var meshes := _kit(FURNITURE_KIT)
	var look := Painterly.material(_painted(["underground_furniture.png", "underground_furniture_base.png"]), &"bespoke")
	var set_down := func(kind: String, at: Vector3, yaw: float) -> MeshInstance3D:
		var piece := _place(meshes[kind], look, kind, at, yaw, kind != "vent_grille")
		furniture.append(piece)
		return piece

	# The tamale seller's pitch, where her cart stands of a night (its grease on the floor, decal_oil),
	# her stool beside it; her steamer steams and hisses under its lid.
	var cart_at: Vector3 = places["cart"]
	var cart: MeshInstance3D = set_down.call("tamale_cart", cart_at, deg_to_rad(25.0))
	set_down.call("stool", cart_at + Vector3(0.75, 0.0, -0.55), 0.4)
	var pot := cart.global_transform * POT_LOCAL
	cart_steam = Vfx.system("pot_steam")
	cart_steam.name = "cart_steam"
	add_child(cart_steam)
	Vfx.place(cart_steam, pot)
	Vfx.emit(cart_steam, true)
	cart_hiss = _loop("cart_hiss", STEAM_HISS, pot, -14.0, 4.0)

	# A bench against the far wall, someone's newspaper left on it; the bin beside it, missed.
	var bench: Vector3 = places["bench"]
	set_down.call("bench", bench, PI)
	_lay("news_folded", bench + Vector3(-0.95, BENCH_SEAT, -0.4), 0.5)
	set_down.call("trash_bin", bench + Vector3(0.65, 0.0, -0.4), 0.6)
	_lay("cone_crushed", bench + Vector3(1.05, 0.0, -0.7), 1.9)

	# The Virgin's niche, built out from the far wall facing her stall; its candles lit, their soot above.
	var niche: MeshInstance3D = set_down.call("niche", places["niche"], places["niche_yaw"])

	if FileAccess.file_exists(FURNITURE_WICKS):
		var wicks := []

		for w in (JSON.parse_string(FileAccess.get_file_as_string(FURNITURE_WICKS)) as Dictionary).get("niche", []):
			var at: Vector3 = niche.global_transform * Vector3(w[0], w[1], w[2])
			niche_wicks.append(at)
			wicks.append([at.x, at.y, at.z])

		var middle := Vector3.ZERO

		for at in niche_wicks:
			middle += at / niche_wicks.size()

		niche_flames = Vfx.system("candles")
		niche_flames.name = "niche_flames"
		add_child(niche_flames)
		Vfx.place(niche_flames, middle, {"wicks": wicks})
		Vfx.emit(niche_flames, true)

	# (Over the niche on whichever wall it stands, turned to project into that wall with the image's top kept up.)
	var niche_at: Vector3 = places["niche"]
	var off_wall := Vector3(0.0, 0.0, -0.1).rotated(Vector3.UP, float(places["niche_yaw"]) - PI)
	_decal("soot", Vector3(niche_at.x, NICHE_SILL + 1.15, niche_at.z) + off_wall, Vector3(0.8, 0.4, 0.9),
		Vector3(90, rad_to_deg(float(places["niche_yaw"])), 0)).name = "decal_soot_niche"

	# A vent low in the back wall breathing the warm air of the works behind it; its breath has
	# stained the wall above it.
	var vent: MeshInstance3D = set_down.call("vent_grille", Vector3(VENT_X, 0.0, BACK_WALL), 0.0)
	vent_breath = Vfx.system("vent_breath")
	vent_breath.name = "vent_breath"
	add_child(vent_breath)
	Vfx.place(vent_breath, vent.global_position + Vector3(0.0, 0.35, 0.06))
	vent_breath.rotation_degrees.x = 90.0
	Vfx.emit(vent_breath, true)
	vent_hum = _loop("vent_hum", VENT_HUM, vent.global_position + Vector3(0.0, 0.35, 0.1), -10.0, 6.0)
	_decal("soot", Vector3(VENT_X, 1.0, BACK_WALL + 0.1), Vector3(0.8, 0.4, 1.0), Vector3(90, 0, 0)).name = "decal_soot_vent"


## A looping sound at `at`, heard to `reach` m.
func _loop(node_name: String, path: String, at: Vector3, db: float, reach: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.name = node_name
	sound.stream = load(path)
	sound.max_distance = reach
	sound.unit_size = 1.0
	sound.volume_db = db
	sound.autoplay = true
	add_child(sound)
	sound.position = at
	return sound


## A services piece hung on a wall at `at` (its wall face, its height), turned to face back across
## the corridor if it hangs on the far wall.
func _hang(kind: String, at: Vector3, far: bool, solid := false) -> MeshInstance3D:
	var piece := _place(_service_meshes[kind], _service_material, kind, at, PI if far else 0.0, solid)
	services.append(piece)
	return piece


# The walls, tiled

func _walls() -> void:
	if not ResourceLoader.exists(WALL_KIT):
		missing.append(WALL_KIT)
		return

	var meshes := _kit(WALL_KIT)
	var look := Painterly.material(_painted(["underground_walls.png", "underground_walls_base.png"]), &"bespoke")
	var columns := int(round(2.0 * half_run / MODULE))

	for c in columns:
		var x := -half_run + MODULE * c
		# (Its column counted from the bay's own west end, so a longer corridor keeps the bay's panels where they were.)
		var cc := c - _shift()
		# The back wall, where the marigold trail ends at the crack showing the older city's stone.
		var kind := "wall_crack" if cc == CRACK_COLUMN else ("wall_tiled_worn" if cc in WORN_BACK else "wall_tiled")
		wall_panels.append(_place(meshes[kind], look, kind, Vector3(x, 0.0, BACK_WALL - WALL_FACE), 0.0, true))
		# The far wall, its panels turned to face back across the corridor.
		kind = "wall_tiled_worn" if cc in WORN_FAR else "wall_tiled"
		wall_panels.append(_place(meshes[kind], look, kind, Vector3(x + MODULE, 0.0, FAR_WALL + WALL_FACE), PI, true))

	# The corridor's ends: six panels across each, a little past its walls into their corners.
	for k in 6:
		var kind := "wall_tiled_worn" if k == 2 else "wall_tiled"
		wall_panels.append(_place(meshes[kind], look, kind, Vector3(half_run + WALL_FACE, 0.0, BACK_WALL - 0.15 + MODULE * k), -PI / 2.0, true))
		kind = "wall_tiled_worn" if k == 4 else "wall_tiled"
		wall_panels.append(_place(meshes[kind], look, kind, Vector3(-half_run - WALL_FACE, 0.0, FAR_WALL + 0.15 - MODULE * k), PI / 2.0, true))

	# The vault's plaster in spans, each turned one way or the other against repetition.
	if ResourceLoader.exists(VAULT_KIT):
		var soffit: Mesh = _kit(VAULT_KIT)["vault_span"]
		var plaster := Painterly.material(_painted(["underground_vault.png", "underground_vault_base.png"]), &"bespoke")
		# (A warm bounce off the lit tiles below, its shadows not tinted cool: the shaded lamps never light it, and in
		# the painted light's cool shadow and sky it read as a night sky.)
		plaster.set_shader_parameter("ambient_ground", Color(0.52, 0.38, 0.26))
		plaster.set_shader_parameter("ambient_sky", Color(0.46, 0.36, 0.27))
		plaster.set_shader_parameter("ambient_amount", 0.26)
		plaster.set_shader_parameter("shadow_cool", Vector3(0.95, 0.9, 0.92))
		plaster.set_shader_parameter("rim_colour", Color(0.5, 0.38, 0.27))

		for i in int(round(2.0 * half_run / VAULT_SPAN)):
			var x := -half_run + VAULT_SPAN * i
			# (Turned by its span counted from the bay's own west end.)
			var turned := posmod(i - int(round((half_run - RUN) / VAULT_SPAN)), 2) == 1
			var at := Vector3(x + VAULT_SPAN, HEIGHT, BACK_WALL - WALL_FACE) if turned else Vector3(x, HEIGHT, FAR_WALL + WALL_FACE)
			var span := _place(soffit, plaster, "vault_span", at, PI if turned else 0.0, false)
			# (Above the work lamps' shades: they never light it.)
			span.layers = Layers.SHADED_ABOVE
			vault_spans.append(span)
	else:
		missing.append(VAULT_KIT)

	# The station's name on each wall, framed in mosaic.
	wall_panels.append(_place(meshes["name_tablet"], look, "name_tablet", Vector3(-9.5, 1.6, BACK_WALL), 0.0, false))
	wall_panels.append(_place(meshes["name_tablet"], look, "name_tablet", Vector3(9.0, 1.6, FAR_WALL), PI, false))

	# Bills pasted over the tiles, newer over older, a little askew; what they say is the user's.
	# Each bill on its own coloured paper, faded: the street's fluorescent pinks, yellows and greens, a white.
	var papers := [Color("e8a0b0"), Color("f0d878"), Color("a8d8a0"), Color("f2ece0"), Color("f0b888"), Color("e8a0b0")]
	var bills := [[6.0, 1.95, false, 0.0], [6.36, 1.82, false, 4.0], [-7.6, 1.85, false, -2.5],
			[4.6, 1.9, true, 2.0], [-7.0, 1.75, true, -5.0], [-6.62, 2.02, true, 3.0]]

	for i in bills.size():
		var bill: Array = bills[i]
		var pasted := _wall_decal("poster", Vector3(bill[0], bill[1], 0.0), Vector2(0.58, 0.82), bill[2], bill[3], false)
		pasted.name = "decal_poster"
		pasted.modulate = papers[i]

	# The floor's wet and dirt splashed up the walls' feet by mops and feet.
	for foot in [[-10.5, false], [-7.2, false], [-3.0, false], [5.2, false], [9.0, false],
			[-10.0, true], [-5.5, true], [0.0, true], [3.5, true], [8.5, true], [11.0, true]]:
		_wall_decal("drip", Vector3(foot[0], 0.35, 0.0), Vector2(2.4, 0.7), foot[1], 0.0, true).name = "decal_splash"


## A decal laid on a wall's tiles at `at` (its x and height), the image's top up (or down when
## `rising`, for what climbs from the floor), rolled `roll` degrees in the wall's plane.
func _wall_decal(kind: String, at: Vector3, size: Vector2, far: bool, roll: float, rising: bool) -> Decal:
	var wall := FAR_WALL - 0.1 if far else BACK_WALL + 0.1
	var d := _decal(kind, Vector3(at.x, at.y, wall), Vector3(size.x, 0.4, size.y), Vector3.ZERO)
	var turn := Vector3(-90 if rising else 90, (0 if rising else 180) if far else (180 if rising else 0), 0)
	d.basis = Basis(Vector3(0, 0, 1), deg_to_rad(roll)) * Basis.from_euler(turn * PI / 180.0)
	return d


# The uncanny

## Ánimas in the drain (docs/superpowers/refs/underground/supernatural_refs.md): the old city's
## drowned, come up the drain from its cistern, drawn by the candles and begging of the living.
func _animas() -> void:
	for module: MeshInstance3D in floor_tiles:
		if module.get_meta("kind") != "floor_border_drain":
			continue

		animas = AnimasScript.new()
		animas.name = "animas"
		# Hands reaching up out of their fire (the uncanny kit's, cut from the CC0 base body), in Graves'
		# chartreuse (vfx_method.md).
		if ResourceLoader.exists(UNCANNY_KIT):
			var hands := _kit(UNCANNY_KIT)
			animas.hand_meshes = [hands["anima_hand_reach"], hands["anima_hand_claw"]] as Array[Mesh]
		animas.colour = Color("b8f04a")
		animas.seed = 23
		animas.flee_from = player
		# What they make for: her ofrenda's candles, and the Virgin's in the niche across the way (out of their reach).
		# Each reached from its open side: the niche's from the corridor, the shrine's from in front of it.
		var lit := PackedVector3Array(niche_wicks)
		var open := PackedVector3Array()
		open.resize(lit.size())
		# (Its open side out of whichever wall it stands on: NICHE_OPEN on the far wall.)
		open.fill(Basis(Vector3.UP, float(places["niche_yaw"]) - PI) * NICHE_OPEN)

		var shrine := stall.find_child("stall_ofrenda", true, false) as MeshInstance3D
		var stall_box := (stall.find_child("stall_frame", true, false) as MeshInstance3D)
		var front := (shrine.global_transform * shrine.get_aabb()).end.z if shrine != null else 0.0

		if FileAccess.file_exists(WICKS):
			for list in (JSON.parse_string(FileAccess.get_file_as_string(WICKS)) as Dictionary).values():
				for w in list:
					# (Her stall's wicks are in the bay's frame: the souls go by the world's, wherever the bay stands.)
					var wick := to_global(Vector3(w[0], w[1], w[2]))
					lit.append(wick)
					# (Reached from just in front of her shrine, into it.)
					open.append(Vector3(0.0, SHRINE_LIFT, front + SHRINE_CLEAR - wick.z))
		animas.candles = lit
		animas.sides = open
		# The way round her stall, from the drain behind it out to its front: past its corner.
		if stall_box != null:
			var box := stall_box.global_transform * stall_box.get_aabb()
			animas.ways = PackedVector3Array([Vector3(box.position.x - STALL_ROUND, 1.0, box.end.z + STALL_ROUND),
				Vector3(box.position.x - STALL_ROUND, 0.6, box.position.z + 0.6)])
		# The grate's bars run along the module's X; its gaps sit along its Z (Godot's -Y of the kit).
		animas.lanes = PackedFloat32Array(GRATE_LANES)
		add_child(animas)
		animas.global_position = module.global_transform * DRAIN_LOCAL
		animas.rotation.y = module.rotation.y


## The procession: her dead in white with their candles, walking her marigold trail into the old stone.
func _procession() -> void:
	if not ResourceLoader.exists(UNCANNY_KIT):
		return

	var meshes := _kit(UNCANNY_KIT)
	var held := {}

	if FileAccess.file_exists(UNCANNY_WICKS):
		held = JSON.parse_string(FileAccess.get_file_as_string(UNCANNY_WICKS))

	var cast := []

	for walker in PROCESSION:
		var w: Array = held.get(walker, [[0.25, 1.0, 0.0]])[0]
		cast.append([meshes[walker], Vector3(w[0], w[1], w[2])])

	procession = ProcessionScript.new()
	procession.name = "procession"
	procession.trail = _trail
	procession.length = _trail_length()
	procession.animas = animas
	add_child(procession)
	procession.build(cast)


func _trail_length() -> float:
	var total := 0.0
	var was := _trail(0.0)

	for i in range(1, 41):
		var at := _trail(i / 40.0)
		total += was.distance_to(at)
		was = at

	return total


## A shadow with no owner, crossing the far wall's tiles.
func _ownerless() -> void:
	ownerless = ShadowScript.new()
	ownerless.name = "ownerless"
	ownerless.wall_z = FAR_WALL
	ownerless.far = true
	ownerless.from_x = -7.0
	ownerless.to_x = 7.0
	add_child(ownerless)


## The nahual: the old man who sits on the bench, become an enormous black dog lying beside it;
## his hat left on the bench. It watches whoever is watching (the drawing camera: the player's).
func _nahual() -> void:
	if not ResourceLoader.exists(UNCANNY_KIT):
		missing.append(UNCANNY_KIT)
		return

	var meshes := _kit(UNCANNY_KIT)
	var look := Painterly.material(_painted(["underground_uncanny.png", "underground_uncanny_base.png"]), &"bespoke")
	# The dog is a spectre in Mignola's black: one flat shape, its edges fraying into climbing smoke.
	var black := ShaderMaterial.new()
	black.shader = SPECTRE
	black.set_shader_parameter(&"noise", Vfx.noise_3d())
	var ember := StandardMaterial3D.new()
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.albedo_color = EMBER
	# Its eyes glow: emissive past white, so the night's bloom takes them.
	ember.emission_enabled = true
	ember.emission = EMBER
	ember.emission_energy_multiplier = 4.0
	nahual = NahualScript.new()
	nahual.name = "nahual"
	nahual.intruder = player
	add_child(nahual)
	nahual.build(meshes["nahual_body"], meshes["nahual_head"], black, ember)
	nahual.position = places["nahual"]
	# Turned so it lies along the far wall's foot with its head toward the corridor's middle.
	nahual.rotation.y = PI / 2.0
	nahual.scale = Vector3.ONE * NAHUAL_SCALE
	old_hat = _place(meshes["old_hat"], look, "old_hat", (places["bench"] as Vector3) + (HAT_AT - Vector3(-2.4, 0.0, FAR_WALL)), 0.7, false)


# The floor, tiled

func _tiles() -> void:
	if not ResourceLoader.exists(FLOOR_KIT):
		missing.append(FLOOR_KIT)
		return

	var meshes := _kit(FLOOR_KIT)
	var look := Painterly.material(_painted(["underground_floor.png", "underground_floor_base.png"]), &"bespoke")
	var columns := int(round(2.0 * half_run / MODULE))

	for c in columns:
		var x := -half_run + MODULE * c
		var cc := c - _shift()
		# Along the back wall: the border row (its dark row at the wall), with the drain.
		var kind := "floor_border_drain" if cc == DRAIN_COLUMN else "floor_border"
		floor_tiles.append(_place(meshes[kind], look, kind, Vector3(x, 0.0, BACK_WALL + MODULE), 0.0, false))

		# The open floor, each module turned one way or the other so their painting does not repeat.
		for r in range(1, 5):
			var worn := Vector2i(cc, r) in WORN
			kind = "floor_field_worn" if worn else "floor_field"
			var turned := fposmod(sin(cc * 12.9898 + r * 78.233) * 43758.5453, 1.0) > 0.5
			var low := BACK_WALL + MODULE * r
			var at := Vector3(x + MODULE, 0.0, low) if turned else Vector3(x, 0.0, low + MODULE)
			floor_tiles.append(_place(meshes[kind], look, kind, at, PI if turned else 0.0, false))

		# Against the far wall: the narrow edge row, turned so its dark row is at the wall.
		floor_tiles.append(_place(meshes["floor_edge"], look, "floor_edge", Vector3(x + MODULE, 0.0, FAR_WALL - EDGE_DEPTH), PI, false))


# The grime, each with its cause

func _decals() -> void:
	# Water off the conduit runs down the wall beside the stall.
	_decal("drip", Vector3(-2.3, 2.3, BACK_WALL + 0.1), Vector3(0.9, 0.4, 1.6), Vector3(90, 0, 0))
	# The censer's copal smoke has browned the canvas over it.
	_decal("soot", Vector3(0.0, 2.3, -0.22), Vector3(0.9, 0.5, 0.9), Vector3(180, 0, 0))
	# Feet and spills have worn the floor in front of the counter.
	_decal("grime", Vector3(0.0, 0.0, 0.7), Vector3(2.8, 0.4, 1.4), Vector3.ZERO)
	# The commuters' path down the corridor's middle, trodden dark; the dirt of feet by the bench.
	for walk in [[-9.0, 1.2, 8.0], [-4.6, 0.9, -6.0], [4.8, 1.0, 5.0], [9.4, 1.3, -4.0]]:
		_decal("grime", Vector3(walk[0], 0.0, walk[1]), Vector3(3.8, 0.4, 1.7), Vector3(0, walk[2], 0)).name = "decal_tread"
	_decal("grime", Vector3(-3.3, 0.0, 3.85), Vector3(2.2, 0.4, 0.9), Vector3.ZERO).name = "decal_tread_bench"
	# A tamale cart's axle grease, where it stands of a night.
	_decal("oil", Vector3(4.2, 0.0, 2.6), Vector3(1.3, 0.4, 1.0), Vector3(0, 25, 0))
	# The water off the conduit pools wet at the wall's foot and runs to the drain, shining.
	var wet := _decal("wet", Vector3(-2.05, 0.0, -1.85), Vector3(1.3, 0.4, 0.95), Vector3(0, -20, 0))
	var shine := Image.create(4, 4, false, Image.FORMAT_RGB8)
	shine.fill(Color(1.0, 0.12, 0.0))
	wet.texture_orm = ImageTexture.create_from_image(shine)


func _decal(kind: String, at: Vector3, size: Vector3, turn: Vector3) -> Decal:
	var d := Decal.new()
	d.name = "decal_" + kind
	d.size = size
	d.texture_albedo = _painted(["decal_%s.png" % kind], true)
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	add_child(d)
	d.position = at
	d.rotation_degrees = turn
	decals.append(d)
	return d


func _keys() -> void:
	var screen := CanvasLayer.new()
	add_child(screen)
	keys_label = Label.new()
	keys_label.position = Vector2(12, 8)
	keys_label.add_theme_font_size_override("font_size", 14)
	screen.add_child(keys_label)
	_name_keys()


func _name_keys() -> void:
	if keys_label == null or work_lights.is_empty() or decals.is_empty():
		return

	keys_label.text = "F1 work lights %s  ·  F2 form light %s  ·  F3 decals %s  ·  F4 a train  ·  F5 the dark train  ·  F9 the procession" % [
		"ON" if work_lights[0].visible else "off", "ON" if _form else "off", "ON" if decals[0].visible else "off"]
