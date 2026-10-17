extends Node3D
## The Metro Underground's look-dev bay (docs/superpowers/plans/2026-10-16-metro-underground-part-1.md,
## Task 9): the hero stall against the wall of a stretch of tiled corridor,
## painted in the bespoke blend, its neon and bulb lit, the conduit its
## cable draws from running along the wall, two sodium work lights.
##   F1  work lights on / off
##   F2  form light: everything neutral grey under one white light, to judge shape
##   F3  grime decals on / off
##   F4  a train now (they pass every 90-150 s on their own)
##
## The stall's atlas is the committed painted file (the user's overpaint
## stall.png before the painter's stall_base.png); the bay never reads the
## user's local brush sheets.

const PLAYER := preload("res://Player.tscn")
const Vfx := preload("res://scripts/Level/Vfx.gd")
const FireParticles := preload("res://scripts/Visual/Lights/FireParticles.gd")
const Painterly := preload("res://scripts/Visual/Painterly.gd")
const RetroScript := preload("res://scripts/Visual/Retro.gd")

## The corridor (m): its run along X, the wall the stall backs onto, the far wall, the vault.
const RUN := 12.0
const BACK_WALL := -2.35
const FAR_WALL := 4.5
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
var form_light: DirectionalLight3D
var form_material: StandardMaterial3D
var decals: Array[Decal] = []
var player: Node3D
var world: WorldEnvironment
var keys_label: Label

var _form := false


func _ready() -> void:
	reset_physics_interpolation.call_deferred()
	_environment()
	_corridor()
	_stall()
	_lights()
	_decals()
	_clutter()
	_services()
	_effects()
	_keys()
	player = PLAYER.instantiate()
	player.debug_traversal = false
	add_child(player)
	player.global_position = Vector3(0.0, 1.05, 4.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_F1:
			set_work_lights(not work_lights[0].visible)
		KEY_F2:
			set_form(not _form)
		KEY_F3:
			set_decals(not decals[0].visible)
		KEY_F4:
			train.start_pass()


func set_work_lights(on: bool) -> void:
	for light in work_lights:
		light.visible = on

	_name_keys()


## The form light: every mesh of the bay a neutral grey under one white
## light, the work lights off; or everything as it was.
func set_form(on: bool) -> void:
	_form = on

	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(player) and player.is_ancestor_of(mesh):
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

	set_work_lights(not on)


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

func _corridor() -> void:
	var tile := _flat(TILE)
	_box(Vector3(-RUN, -0.2, BACK_WALL - WALL), Vector3(RUN, 0.0, FAR_WALL + WALL), _flat(FLOOR), "floor")
	_box(Vector3(-RUN, 0.0, BACK_WALL - WALL), Vector3(RUN, HEIGHT, BACK_WALL), tile, "back_wall")
	_box(Vector3(-RUN, 0.0, FAR_WALL), Vector3(RUN, HEIGHT, FAR_WALL + WALL), tile, "far_wall")
	_box(Vector3(-RUN, HEIGHT, BACK_WALL - WALL), Vector3(RUN, HEIGHT + 0.2, FAR_WALL + WALL), tile, "vault")

	for x in [-RUN - WALL, RUN]:
		_box(Vector3(x, 0.0, BACK_WALL - WALL), Vector3(x + WALL, HEIGHT, FAR_WALL + WALL), tile, "end_%d" % x)

	# Line 2's blue band along both walls at shoulder height.
	_box(Vector3(-RUN, 1.3, BACK_WALL), Vector3(RUN, 1.5, BACK_WALL + 0.02), _flat(LINE_2), "band_back")
	_box(Vector3(-RUN, 1.3, FAR_WALL - 0.02), Vector3(RUN, 1.5, FAR_WALL), _flat(LINE_2), "band_far")



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
		add_child(light)
		light.position = Vector3(x, HEIGHT - 0.4, 2.2)
		work_lights.append(light)
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
		motes.position = light.global_position - Vector3(0.0, 2.0, 0.0)
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
	# The lights sag unevenly as the train draws on the Company's line.
	var dip := clampf(0.5 + 0.5 * sin(_clock * 23.0) * sin(_clock * 7.3 + 1.1), 0.0, 1.0)
	var sag := 1.0 - s * (BROWNOUT.x + BROWNOUT.y * dip)

	for light: Light3D in _full:
		light.light_energy = _full[light] * sag

	if neon != null:
		neon.dim = sag

	bulb_pivot.gust = GUST_SWING * s
	Vfx.blow(censer, DRAUGHT * (1.0 + 4.0 * s))

	for motes in dust:
		Vfx.blow(motes, DRAUGHT * (1.0 + 4.0 * s))

	dust_sift.amount_ratio = clampf((s - 0.3) / 0.7, 0.0, 1.0)

	if crowd != null:
		crowd.duck = s
	rumble.volume_db = RUMBLE_DB + linear_to_db(maxf(s, 0.001))


## The train, its rumble, the dust its shaking sifts from the vault, the jars' rattle.
func _train() -> void:
	train = TrainPass.new()
	train.name = "train"
	train.seed = 31
	add_child(train)

	for light in work_lights + [bulb]:
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
		piece.set_surface_override_material(i, material)

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


## A services piece hung on a wall at `at` (its wall face, its height), turned to face back across
## the corridor if it hangs on the far wall.
func _hang(kind: String, at: Vector3, far: bool, solid := false) -> MeshInstance3D:
	var piece := _place(_service_meshes[kind], _service_material, kind, at, PI if far else 0.0, solid)
	services.append(piece)
	return piece


# The grime, each with its cause

func _decals() -> void:
	# Water off the conduit runs down the wall beside the stall.
	_decal("drip", Vector3(-2.3, 2.3, BACK_WALL + 0.1), Vector3(0.9, 0.4, 1.6), Vector3(90, 0, 0))
	# The censer's copal smoke has browned the canvas over it.
	_decal("soot", Vector3(0.0, 2.3, -0.22), Vector3(0.9, 0.5, 0.9), Vector3(180, 0, 0))
	# Feet and spills have worn the floor in front of the counter.
	_decal("grime", Vector3(0.0, 0.0, 0.7), Vector3(2.8, 0.4, 1.4), Vector3.ZERO)
	# A tamale cart's axle grease, where it stands of a night.
	_decal("oil", Vector3(4.2, 0.0, 2.6), Vector3(1.3, 0.4, 1.0), Vector3(0, 25, 0))
	# The water off the conduit pools wet at the wall's foot, shining.
	var wet := _decal("wet", Vector3(-2.3, 0.0, -1.95), Vector3(1.2, 0.4, 0.9), Vector3(0, -10, 0))
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

	keys_label.text = "F1 work lights %s  ·  F2 form light %s  ·  F3 decals %s" % [
		"ON" if work_lights[0].visible else "off", "ON" if _form else "off", "ON" if decals[0].visible else "off"]
