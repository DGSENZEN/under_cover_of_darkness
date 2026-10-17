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
const HALO := 0.13
const EYE_LIGHT := 0.22
const EYE_REACH := 1.4
## Walked into: how near (from its middle, m) scatters it, how far they must go before it re-forms,
## and how fast it goes and comes back (per s).
const SCATTER_NEAR := 1.3
const REFORM_FAR := 2.6
const SCATTER_RATE := 3.0
const REFORM_RATE := 0.5
const HALO_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 colour : source_color;
uniform float presence = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float soft = pow(clamp(1.0 - length(p), 0.0, 1.0), 2.5);
	ALBEDO = colour.rgb * soft * presence * (0.85 + 0.15 * sin(TIME * 2.3));
}
"""
## How far its head turns either way and up or down (degrees), and how fast it follows (per s).
const TURN := 70.0
const NOD := 15.0
const FOLLOW := 4.0
## How long it must be looked at before it will go, how long looked away before it does (s),
## and how far off it notices being looked at (m).
const SEEN_FOR := 1.0
const AWAY_FOR := 0.4
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
## Its smoke thrown up when it scatters (a Vfx effect the bay gives it).
var scatter: GPUParticles3D
## How much of it is here: 1 whole, 0 scattered.
var presence := 1.0
var _spectre: ShaderMaterial
var _ember: Material
var _halo_looks: Array[ShaderMaterial] = []

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
		var disc := QuadMesh.new()
		disc.size = Vector2.ONE * HALO
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


## Here, unwatched, as it is when the night begins (tests begin from it).
func appear() -> void:
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

	_scatter(delta)

	if presence < 1.0:
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
				_go()
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
		presence = maxf(0.0, presence - SCATTER_RATE * delta)
	elif near > REFORM_FAR:
		presence = minf(1.0, presence + REFORM_RATE * delta)

	if scatter != null:
		scatter.emitting = presence < 0.95 and near < REFORM_FAR

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
	solid.process_mode = Node.PROCESS_MODE_INHERIT
	solid.collision_layer = 1
