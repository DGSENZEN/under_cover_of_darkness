extends Node3D
## The nahual (docs/superpowers/refs/underground/supernatural_refs.md): the old man who sits on
## the bench every night, become an enormous black dog lying beside it. Its head turns to watch
## whoever watches it (`watcher`, else whichever camera is drawing); once it has been looked at,
## it is gone the moment they look away, and it comes back only when its place is unwatched,
## a while later (`away_for`, s). Its body and head are the uncanny kit's
## (tools/eclipse/underground_uncanny.py), the head turned about the neck.

## Where the head turns on the body, and where its eyes are on the head (this node's axes: the
## dog lies along +X, the kit's frame turned Godot's way round).
const NECK := Vector3(0.88, 0.64, 0.0)
const EYES := Vector3(0.13, 0.035, 0.0)
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
@export var away_for := Vector2(40.0, 90.0)
@export var seed := 11

var body: MeshInstance3D
var head: MeshInstance3D
var solid: StaticBody3D

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


## Here, unwatched, as it is when the night begins (tests begin from it).
func appear() -> void:
	_come_back()
	_watched = false
	_seen_time = 0.0
	_unseen_time = 0.0


## Where its eyes are now (world).
func eyes() -> Vector3:
	return head.global_transform * EYES


func _part(mesh: Mesh, look: Material, ember: Material, node_name: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	part.mesh = mesh

	for i in mesh.get_surface_count():
		var slot: Material = mesh.surface_get_material(i)
		part.set_surface_override_material(i, ember if slot != null and slot.resource_name == "ember" else look)

	return part


func _process(delta: float) -> void:
	var eye := watcher if watcher != null else get_viewport().get_camera_3d()

	if eye == null or head == null:
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
