extends Node3D
## The nahual (docs/superpowers/refs/underground/supernatural_refs.md): the old man who sits on
## the bench every night, become an enormous black dog lying beside it. Its head turns to watch
## whoever watches it (`watcher`, else whichever camera is drawing); once it has been looked at,
## it is gone the moment they look away, and it comes back only when its place is unwatched,
## a while later (`away_for`, s). Its body and head are the uncanny kit's
## (tools/eclipse/underground_uncanny.py), the head turned about the neck.

## Where the head turns on the body, where its eyes are on the head (each, and between them), and
## its body's middle (this node's axes: the dog lies along +X, the kit's frame turned Godot's way).
const NECK := Vector3(0.88, 0.64, 0.0)
const EYES := Vector3(0.15, 0.075, 0.0)
const EYE := Vector3(0.165, 0.075, 0.052)
const MIDDLE := Vector3(0.5, 0.3, 0.0)
## Its eyes' glow: the halo's size (m) and its light's energy and reach.
const HALO := 0.075
const EYE_LIGHT := 0.22
const EYE_REACH := 1.4
## Walked into: how near (from its middle, m) scatters it, how far they must go before it re-forms,
## and how fast it goes and comes back (per s).
const SCATTER_NEAR := 1.3
const REFORM_FAR := 2.6
const SCATTER_RATE := 3.0
const REFORM_RATE := 0.5
## Its scatter a puff (s): the smoke thrown out, then eaten away, while they still stand there.
const BURST_FOR := 1.2
## (A small sphere round each eye, not a card: brightest where it faces you, fading to nothing at its
## rim, so no edge shows however the light falls or where it meets the skull.)
const HALO_CODE := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 colour : source_color;
uniform float presence = 1.0;
void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float soft = pow(facing, 3.0);
	ALBEDO = colour.rgb * soft * presence * 0.6 * (0.85 + 0.15 * sin(TIME * 2.3));
}
"""
## How far its head turns either way and up or down (degrees), and how fast it follows (per s).
const TURN := 70.0
const NOD := 15.0
const FOLLOW := 4.0
## How long it must be looked at before it will go, how long looked away before it does (s),
## and how far off it notices being looked at (m).
const SEEN_FOR := 1.0
const AWAY_FOR := 1.5
## Once it goes, how fast it dissolves into its smoke (per s): about a second and a half.
const VANISH_RATE := 0.65
const REACH := 14.0

@export var watcher: Camera3D
## Whoever may walk into it (the player).
@export var intruder: Node3D
@export var away_for := Vector2(40.0, 90.0)
@export var seed := 11

var body: MeshInstance3D
var head: MeshInstance3D
var solid: StaticBody3D
var eye_halos: Array[MeshInstance3D] = []
var eye_light: OmniLight3D
## Its smoke, the Deadlock way (vfx_method.md): tendrils rising off its back always, and a scatter
## of them thrown up and out when it is walked into; `scattering` how far that throw has gone.
var tendrils: Array[MeshInstance3D] = []
var scatter_tendrils: Array[MeshInstance3D] = []
var scattering := 0.0
## How far its puff has gone (0 thrown, 1 eaten away); below 0, none.
var _burst := -1.0
var _smoke_looks: Array[ShaderMaterial] = []
var _scatter_looks: Array[ShaderMaterial] = []
## How much of it is here: 1 whole, 0 scattered.
var presence := 1.0
var _spectre: ShaderMaterial
var _ember: Material
var _halo_looks: Array[ShaderMaterial] = []
var _vanishing := false

var _rng := RandomNumberGenerator.new()
var _seen_time := 0.0
var _unseen_time := 0.0
var _watched := false
var _back_in := 0.0


## Its body and head from the kit, painted `look`, its eyes `ember`.
func build(body_mesh: Mesh, head_mesh: Mesh, look: Material, ember: Material) -> void:
	_rng.seed = seed
	body = _part(body_mesh, look, ember, "nahual_body")
	add_child(body)
	head = _part(head_mesh, look, ember, "nahual_head")
	add_child(head)
	head.position = NECK
	solid = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = body_mesh.create_convex_shape()
	solid.add_child(shape)
	body.add_child(solid)
	_spectre = look as ShaderMaterial
	_ember = ember
	var glow_colour := (ember as StandardMaterial3D).albedo_color if ember is StandardMaterial3D else Color("ff5a1e")

	# A halo round each eye, and the faint red light they throw.
	for sz in [-1.0, 1.0]:
		var halo := MeshInstance3D.new()
		halo.name = "eye_halo"
		var disc := SphereMesh.new()
		disc.radius = HALO / 2.0
		disc.height = HALO
		disc.radial_segments = 24
		disc.rings = 12
		var soft := ShaderMaterial.new()
		soft.shader = Shader.new()
		soft.shader.code = HALO_CODE
		soft.set_shader_parameter(&"colour", glow_colour)
		disc.material = soft
		halo.mesh = disc
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(halo)
		halo.position = Vector3(EYE.x + 0.02, EYE.y, EYE.z * sz)
		eye_halos.append(halo)
		_halo_looks.append(soft)

	eye_light = OmniLight3D.new()
	eye_light.name = "eye_light"
	eye_light.light_color = glow_colour
	eye_light.light_energy = EYE_LIGHT
	eye_light.omni_range = EYE_REACH
	eye_light.shadow_enabled = false
	head.add_child(eye_light)
	eye_light.position = EYES + Vector3(0.12, 0.0, 0.0)
	_smoke()


## Here, unwatched, as it is when the night begins (tests begin from it).
func appear() -> void:
	_vanishing = false
	_come_back()
	presence = 1.0
	_watched = false
	_seen_time = 0.0
	_unseen_time = 0.0


## Its body's middle (world): where walking into it is measured from.
func middle() -> Vector3:
	return global_transform * MIDDLE


## Where its eyes are now (world).
func eyes() -> Vector3:
	return head.global_transform * EYES


func _part(mesh: Mesh, look: Material, ember: Material, node_name: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	part.mesh = mesh
	# (A spectre casts no shadow.)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for i in mesh.get_surface_count():
		var slot: Material = mesh.surface_get_material(i)
		part.set_surface_override_material(i, ember if slot != null and slot.resource_name == "ember" else look)

	return part


func _process(delta: float) -> void:
	var eye := watcher if watcher != null else get_viewport().get_camera_3d()

	if eye == null or head == null:
		return

	if _vanishing:
		# Dissolving into its smoke, its eyes the last of it.
		presence = maxf(0.0, presence - VANISH_RATE * delta)
		_show()
		if presence <= 0.0:
			_vanishing = false
			_go()
		return

	_scatter(delta)

	if visible and presence < 1.0:
		# (Scattered or re-forming: no watching it away meanwhile.)
		_seen_time = 0.0
		_unseen_time = 0.0
		return

	var seen := eye.global_position.distance_to(eyes()) < REACH and eye.is_position_in_frustum(eyes())

	if visible:
		_follow(eye, delta)

		if seen:
			_seen_time += delta
			_unseen_time = 0.0
			_watched = _watched or _seen_time >= SEEN_FOR
		elif _watched:
			_unseen_time += delta

			if _unseen_time >= AWAY_FOR:
				_vanishing = true
	else:
		_back_in -= delta

		if _back_in <= 0.0 and not seen:
			_come_back()


## Its head turned toward the eye, as far as a lying dog's will turn.
func _follow(eye: Camera3D, delta: float) -> void:
	var to := to_local(eye.global_position) - NECK
	var yaw := clampf(atan2(-to.z, to.x), -deg_to_rad(TURN), deg_to_rad(TURN))
	var pitch := clampf(atan2(to.y, Vector2(to.x, to.z).length()), -deg_to_rad(NOD), deg_to_rad(NOD))
	var ease := 1.0 - exp(-FOLLOW * delta)
	head.rotation.y = lerp_angle(head.rotation.y, yaw, ease)
	head.rotation.z = lerp_angle(head.rotation.z, pitch, ease)


## Walked into, it scatters into smoke and is no longer solid; once they have gone far enough, it
## re-forms.
func _scatter(delta: float) -> void:
	if intruder == null or not is_instance_valid(intruder) or not visible:
		return

	var off := intruder.global_position - middle()
	var near := Vector2(off.x, off.z).length()

	if near < SCATTER_NEAR:
		if presence >= 0.99:
			_burst = 0.0
		presence = maxf(0.0, presence - SCATTER_RATE * delta)
	elif near > REFORM_FAR:
		presence = minf(1.0, presence + REFORM_RATE * delta)

	if _burst >= 0.0:
		_burst = minf(1.0, _burst + delta / BURST_FOR)
	if presence >= 1.0:
		_burst = -1.0

	_show()


## Its look at its presence: its smoke thrown out in a puff as it goes, which eats itself away.
func _show() -> void:
	scattering = clampf(1.0 - presence, 0.0, 1.0)
	# The puff: whole for a moment as it is thrown, then eaten from its tips till nothing is left.
	var thrown := clampf(_burst, 0.0, 1.0)
	var eaten := 1.0 if _burst < 0.0 else lerpf(1.0, 0.3, smoothstep(0.0, 0.12, thrown)) + 0.7 * smoothstep(0.2, 1.0, thrown)

	for i in scatter_tendrils.size():
		var t := scatter_tendrils[i]
		t.scale = Vector3.ONE * (0.5 + 1.0 * (1.0 - pow(1.0 - thrown, 3.0)))
		_scatter_looks[i].set_shader_parameter(&"erosion", minf(eaten, 1.0))

	for look in _smoke_looks:
		look.set_shader_parameter(&"erosion", lerpf(0.3, 0.95, scattering))

	_spectre.set_shader_parameter(&"presence", presence)
	solid.collision_layer = 1 if presence > 0.5 else 0

	for soft in _halo_looks:
		soft.set_shader_parameter(&"presence", presence)

	eye_light.light_energy = EYE_LIGHT * presence
	_set_eyes(presence > 0.25)


func _set_eyes(on: bool) -> void:
	for i in head.mesh.get_surface_count():
		var slot: Material = head.mesh.surface_get_material(i)
		if slot != null and slot.resource_name == "ember":
			head.set_surface_override_material(i, _ember if on else _spectre)


## Its smoke: tendrils curling up off its back; and, hidden till it scatters, a ring of them thrown
## up and out from its body.
func _smoke() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 101
	# (Mignola's black: its smoke black too, only its last edge a cold grey.)
	var dark := [Color(0.05, 0.05, 0.06), Color(0.04, 0.04, 0.05), Color(0.2, 0.23, 0.26)]

	for i in 5:
		var root := Vector3(lerpf(0.05, 0.7, float(i) / 4.0), 0.4 + 0.05 * sin(i * 1.3), rng.randf_range(-0.05, 0.05))
		var path := PackedVector3Array()
		var lean := rng.randf_range(-0.6, 0.6)
		for k in 10:
			var t := k / 9.0
			path.append(root + Vector3(-0.12 * t + 0.04 * sin(t * 5.0 + i), 0.55 * t, lean * 0.15 * t + 0.03 * cos(t * 6.0 + i)))
		var smoke := _smoke_mesh(path, rng.randf_range(0.09, 0.13), dark, 0.22, 0.35, float(i) * 2.7)
		smoke.name = "tendril_%d" % i
		tendrils.append(smoke)
		_smoke_looks.append(smoke.get_surface_override_material(0))

	for i in 9:
		var a := TAU * i / 9.0
		var root := MIDDLE + Vector3(cos(a) * 0.25, 0.05, sin(a) * 0.12)
		var path := PackedVector3Array()
		for k in 10:
			var t := k / 9.0
			path.append(root + Vector3(cos(a) * 0.6 * t, 0.7 * t - 0.25 * t * t, sin(a) * 0.45 * t))
		var burst := _smoke_mesh(path, 0.075, dark, 1.0, 1.4, float(i) * 1.9 + 20.0)
		burst.name = "scatter_%d" % i
		scatter_tendrils.append(burst)
		_scatter_looks.append(burst.get_surface_override_material(0))


func _smoke_mesh(path: PackedVector3Array, radius: float, bands: Array, erosion: float, scroll: float,
		phase: float) -> MeshInstance3D:
	var smoke := MeshInstance3D.new()
	smoke.mesh = MeshVfx.tendril(path, radius)
	var look := MeshVfx.look(bands[0], bands[1], bands[2], 1.0, erosion, scroll, phase)
	look.set_shader_parameter(&"tail_eat", 0.7)
	look.set_shader_parameter(&"churn", 0.015)
	look.set_shader_parameter(&"tiling", Vector2(0.8, 0.6))
	look.set_shader_parameter(&"hardness", 0.03)
	look.set_shader_parameter(&"rim", 6.0)
	smoke.set_surface_override_material(0, look)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)
	return smoke


func _go() -> void:
	visible = false
	solid.process_mode = Node.PROCESS_MODE_DISABLED
	solid.collision_layer = 0
	_back_in = _rng.randf_range(away_for.x, away_for.y)
	_watched = false
	_seen_time = 0.0
	_unseen_time = 0.0


func _come_back() -> void:
	visible = true
	presence = 1.0
	_show()
	solid.process_mode = Node.PROCESS_MODE_INHERIT
	solid.collision_layer = 1
