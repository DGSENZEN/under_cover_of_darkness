class_name Occult
extends Node3D
## The caged god breathing (the effects plan, Task 7): one Breath, read by
## everything that breathes with it. On its inhale the god draws copal,
## petals and dust in at its mouth (an attractor) and pushes them out on the
## exhale; its eight ward lamps, humming, dim; the lamps round its ring dip;
## the haze in its cage thickens; its chest swells. On a deep exhale its
## chains snap taut and the seals on them throw sparks that bounce on the
## plinth, and rust sifts from the links. The wards' sigils write themselves
## on and fade, staying written near the player; close under a ward lamp
## the air round its lenses bends.

const Layers := preload("res://scripts/Visual/Layers.gd")
const SIGIL := preload("res://scripts/Visual/vfx_sigil.gdshader")
const SIGIL_STROKES := preload("res://assets/vfx/sigil_strokes.png")
const RING := preload("res://scripts/Visual/vfx_ward_ring.gdshader")
## The chains' seals over the god's spot (tools/eclipse/bound_god.py).
const SEALS := "res://assets/eclipse/source/bound_god_seals.json"
const WARD := Color("#CFE8F0")
const RUST := Color("#7A3B1E")
## Over the god's spot (tools/eclipse/bound_god.py): its mouth (the jaw's
## front), its chest (the torso's middle) and how far its swell reaches.
const MOUTH := Vector3(0, 5.4, 0.8)
const CHEST := Vector3(0, 3.9, 0)
const CHEST_REACH := 1.6
## How far the chest swells on a full inhale (m).
const SWELL := 0.06
## The plinth's steps (half-width, from, to over the god's spot).
const PLINTH := [[3.0, 0.0, 0.4], [2.6, 0.4, 0.8], [2.2, 0.8, 1.2]]
## The breath's reach (m) and pull.
const REACH := 9.0
const PULL := 1.5
## The wards' hum (a second), how much the ward lamps dim and the ring's
## lamps dip on a full inhale.
const HUM := 1.1
const WARD_DIM := 0.4
const RING_DIP := 0.25
## Ward lamps this near the god are its own; lamps this near dip.
const WARD_REACH := 12.0
const RING_REACH := 30.0
## The haze in the cage on a full exhale and on a full inhale.
const HAZE := 0.06
const HAZE_IN := 0.2
## A sigil disc's face, out from its back (furniture_kit.sigil_disc), the
## sigil this far proud of it, this wide.
const DISC_FACE := 0.04
const SIGIL_PROUD := 0.04
const SIGIL_SIZE := 0.32
## A sigil writes itself on (s), holds, fades, and writes again; this near
## the player it stays written.
const WRITE := 4.0
const CYCLE := 9.0
const WRITTEN_NEAR := 5.0
## Within this far of a ward lamp (across the ground) the air bends.
const RING_NEAR := 3.0
## A sigil is drawn (and written) only this near the camera.
const SIGIL_SEEN := 40.0

var breath: Breath
var kit: KitLoader
## The god's spot.
var god := Vector3.ZERO
var attractor: GPUParticlesAttractorSphere3D
var ward_lights: Array[OmniLight3D] = []
var ring_lights: Array[OmniLight3D] = []
var ward_lenses: Array[StandardMaterial3D] = []
var cage_fog: FogVolume
var sparks: Array[GPUParticles3D] = []
var rust: Array[GPUParticles3D] = []
var sigils: Array[MeshInstance3D] = []
var god_look: ShaderMaterial
var ward_ring: MeshInstance3D

var _wards: Array[OmniLight3D] = []
var _time := 0.0
var _hum := 1.0


static func build(dressing: Dictionary, loader: KitLoader, breathing: Breath) -> Occult:
	var out := Occult.new()
	out.name = "occult"
	out.kit = loader
	out.breath = breathing

	for p in dressing["pieces"]:
		if p["piece"] == "bound_god":
			out.god = Vector3(p["at"][0], p["at"][1], p["at"][2])

	out.attractor = GPUParticlesAttractorSphere3D.new()
	out.attractor.name = "breath"
	out.attractor.radius = REACH
	out.attractor.cull_mask = Layers.BREATHED
	out.attractor.position = out.god + MOUTH
	out.add_child(out.attractor)

	for light in loader.lights:
		if not light.light_color.is_equal_approx(WARD):
			var off := Vector2(light.position.x - out.god.x, light.position.z - out.god.z).length()

			if off < RING_REACH:
				out.ring_lights.append(light)

			continue

		out._wards.append(light)

		if light.position.distance_to(out.god) < WARD_REACH:
			out.ward_lights.append(light)

	for glass in loader.globes_near(out.god, WARD_REACH):
		if glass.emission.is_equal_approx(WARD):
			out.ward_lenses.append(glass)

	out._cage()
	out._chains()
	out._sigils(dressing)
	out.god_look = KitLoader.material("bound_god")
	out.god_look.set_shader_parameter(&"swell_centre", out.god + CHEST)
	out.god_look.set_shader_parameter(&"swell_radius", CHEST_REACH)
	out.ward_ring = MeshInstance3D.new()
	out.ward_ring.name = "ward_ring"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4, 1.4)
	var bend := ShaderMaterial.new()
	bend.shader = RING
	quad.material = bend
	out.ward_ring.mesh = quad
	out.ward_ring.visible = false
	out.ward_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	out.add_child(out.ward_ring)
	breathing.deep_exhale.connect(out._throw)

	# Drawn where effects are: never seen by the lightgem.
	for visual in out.find_children("*", "VisualInstance3D", true, false):
		if not visual is Light3D:
			Layers.effect(visual)

	return out


## Everything that breathes, set by the breath (`value`: +1 drawn in, -1
## out) at `time` (s, the hum's).
func apply(value: float, time: float) -> void:
	var inhale := maxf(value, 0.0)
	_hum = 0.75 + 0.25 * sin(time * TAU * HUM)
	attractor.strength = pull(value)
	var ward := _hum * (1.0 - WARD_DIM * inhale)
	var dip := 1.0 - RING_DIP * inhale

	for light in ward_lights:
		_dim(light, ward)

	for light in ring_lights:
		_dim(light, dip)

	if kit._night:
		for glass in ward_lenses:
			glass.emission_energy_multiplier = KitLoader.GLOW * ward

	(cage_fog.material as FogMaterial).density = lerpf(HAZE, HAZE_IN, inhale)
	god_look.set_shader_parameter(&"swell", SWELL * inhale)


## The breath's pull at its mouth (an attractor's strength) for a breath
## `value` (+1 drawn in, -1 out): a sphere attractor draws in at a positive
## strength.
static func pull(value: float) -> float:
	return value * PULL


## The air round the nearest ward lamp bends when `eye` (the player) stands
## within RING_NEAR of it across the ground, the more the nearer.
func ring_for(eye: Vector3) -> void:
	var nearest: OmniLight3D = null
	var best := RING_NEAR

	for light in _wards:
		var off := Vector2(light.global_position.x - eye.x, light.global_position.z - eye.z).length()

		if off < best:
			best = off
			nearest = light

	ward_ring.visible = nearest != null

	if nearest != null:
		ward_ring.global_position = nearest.global_position
		var bend := (ward_ring.mesh as QuadMesh).material as ShaderMaterial
		bend.set_shader_parameter(&"strength", 1.0 - best / RING_NEAR)
		bend.set_shader_parameter(&"hum", _time * TAU * HUM)


func _process(delta: float) -> void:
	_time += delta
	apply(breath.value(), _time)
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else Vector3.INF
	ring_for(eye)
	_write(eye)


## A lamp held at `share` of its energy (the kit keeps it through a stutter).
func _dim(light: OmniLight3D, share: float) -> void:
	kit.dims[light] = share

	if not kit.stuttering.has(light):
		light.light_energy = KitLoader.LAMP_ENERGY * share


## Each sigil writes itself on, holds and fades on its own phase, glowing
## with the hum; near the player written whole.
func _write(eye: Vector3) -> void:
	for k in sigils.size():
		var sigil := sigils[k]

		if sigil.global_position.distance_to(eye) > SIGIL_SEEN:
			continue

		var t := fposmod(_time + float(sigil.get_meta("phase")), CYCLE)
		var near := sigil.global_position.distance_to(eye) < WRITTEN_NEAR
		sigil.set_instance_shader_parameter(&"drawn", 1.0 if near else clampf(t / WRITE, 0.0, 1.0))
		sigil.set_instance_shader_parameter(&"glow", _hum * (1.0 if near else 1.0 - smoothstep(CYCLE - 2.0, CYCLE, t)))


## The haze in the god's cage: pale oxblood (the colour of gods).
func _cage() -> void:
	var haze := FogMaterial.new()
	haze.albedo = Color("#6E1F1A").lerp(Color.WHITE, 0.45)
	haze.density = HAZE
	haze.edge_fade = 0.5
	cage_fog = FogVolume.new()
	cage_fog.name = "cage_haze"
	cage_fog.size = Vector3(4.5, 8.0, 4.5)
	cage_fog.position = god + Vector3(0, PLINTH[2][2] + 4.0, 0)
	cage_fog.material = haze
	add_child(cage_fog)


## At each seal on the chains: sparks with short trails that bounce on the
## plinth, and rust sifting down; both thrown on a deep exhale.
func _chains() -> void:
	for step in PLINTH:
		var floor_box := GPUParticlesCollisionBox3D.new()
		floor_box.size = Vector3(step[0] * 2.0, step[2] - step[1], step[0] * 2.0)
		floor_box.position = god + Vector3(0, (step[1] + step[2]) / 2.0, 0)
		floor_box.cull_mask = Layers.FX
		add_child(floor_box)

	var seals: Array = JSON.parse_string(FileAccess.get_file_as_string(SEALS))

	for s in seals:
		var at := god + Vector3(s[0], s[1], s[2])
		var out := Vector3(s[0], 0, s[2]).normalized()
		sparks.append(_burst(at, out, true))
		rust.append(_burst(at, out, false))


func _burst(at: Vector3, out: Vector3, hot: bool) -> GPUParticles3D:
	var burst := GPUParticles3D.new()
	burst.name = "sparks" if hot else "rust"
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 28 if hot else 30
	burst.lifetime = 1.4 if hot else 2.5
	burst.fixed_fps = 30
	burst.emitting = false
	burst.layers = Layers.FX
	burst.local_coords = false
	burst.collision_base_size = 0.02
	burst.position = at
	burst.visibility_aabb = AABB(Vector3(-4, -7, -4), Vector3(8, 10, 8))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.12
	process.direction = (out + Vector3(0, 0.6, 0)).normalized() if hot else Vector3.DOWN
	process.spread = 60.0 if hot else 40.0
	process.initial_velocity_min = 1.5 if hot else 0.05
	process.initial_velocity_max = 3.5 if hot else 0.3
	process.gravity = Vector3(0, -9.8 if hot else -0.8, 0)
	process.attractor_interaction_enabled = false

	if hot:
		process.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
		process.collision_bounce = 0.35
		process.collision_friction = 0.3
		burst.trail_enabled = true
		# (Bold enough to read from the plinth's foot: thin ones vanish past a
		# few metres.)
		burst.trail_lifetime = 0.12
		var ribbon := RibbonTrailMesh.new()
		ribbon.shape = RibbonTrailMesh.SHAPE_CROSS
		ribbon.size = 0.035
		# (Fewer than four sections and the trail draws nothing.)
		ribbon.sections = 4
		var taper := Curve.new()
		taper.add_point(Vector2(0, 0))
		taper.add_point(Vector2(1, 1))
		ribbon.curve = taper
		var spark := StandardMaterial3D.new()
		spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		spark.use_particle_trails = true
		spark.albedo_color = Color("FFC060")
		spark.disable_fog = true
		ribbon.material = spark
		burst.draw_pass_1 = ribbon
	else:
		process.scale_min = 0.015
		process.scale_max = 0.03
		var speck := QuadMesh.new()
		var dust := StandardMaterial3D.new()
		dust.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dust.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		dust.billboard_keep_scale = true
		dust.albedo_color = RUST
		speck.material = dust
		burst.draw_pass_1 = speck

	burst.process_material = process
	add_child(burst)
	return burst


## A deep exhale: the chains snap taut, the seals spark, rust sifts down.
func _throw() -> void:
	for burst in sparks + rust:
		burst.restart()
		burst.emitting = true


## A sigil on each sigil disc's face, SIGIL_PROUD out from it.
func _sigils(dressing: Dictionary) -> void:
	var look := ShaderMaterial.new()
	look.shader = SIGIL
	look.set_shader_parameter(&"sheet", SIGIL_STROKES)
	look.set_shader_parameter(&"colour", WARD)
	var quad := QuadMesh.new()
	quad.size = Vector2(SIGIL_SIZE, SIGIL_SIZE)
	quad.material = look
	var rng := RandomNumberGenerator.new()
	rng.seed = 1521

	for p in dressing["pieces"]:
		if p["piece"] != "sigil_disc":
			continue

		var basis := Basis(Vector3.UP, deg_to_rad(p["yaw"]))
		var sigil := MeshInstance3D.new()
		sigil.mesh = quad
		sigil.visibility_range_end = SIGIL_SEEN - 5.0
		sigil.visibility_range_end_margin = 5.0
		sigil.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sigil.transform = Transform3D(basis, Vector3(p["at"][0], p["at"][1], p["at"][2]) + basis * Vector3(0, 0, DISC_FACE + SIGIL_PROUD))
		sigil.set_meta("phase", rng.randf() * CYCLE)
		add_child(sigil)
		sigils.append(sigil)
