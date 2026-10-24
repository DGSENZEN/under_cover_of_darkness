class_name LiveBook
extends Node3D
## One of the librarian's live books (docs/superpowers/specs/2026-10-17-librarian-shop-design.md): it lies shut
## until someone comes near and can see it, then opens, its front half turning over on the spine and its leaves
## fanning after, and shuts again once they go. Built from the books kit's live parts (tools/eclipse/library_books.py):
## this node's origin is the book's hinge (along its spine's outer face, at its middle depth), its spine along z,
## its pages to +x, up y. What each kind does once open (the novels' words, the studies' spectres, the spells'
## chains) is the effects' (Part 2); here they share one look.

signal opened(book: LiveBook)
signal closed(book: LiveBook)

enum Kind {NOVEL, STUDY, SPELL}

## Nearer than this (m, from the eye) and in sight it opens; farther than this it shuts (between, it keeps on).
const OPEN_NEAR := 1.5
const CLOSE_FAR := 2.2
## How long it takes to open, to shut (s).
const OPEN_TIME := 0.7
const CLOSE_TIME := 0.9
## How many leaves fan over as it turns, and how far behind the board each follows (of the turn).
const LEAVES := 3
const LEAF_LAG := 0.12

@export var kind := Kind.NOVEL
@export var section := &""
## Whoever it opens for (a camera); else whichever camera is drawing.
@export var watcher: Node3D

## How open it is, 0 shut to 1 flat open; whether it is opening (someone near and in sight).
var open := 0.0
var wanted := false
## Every mesh of it.
var parts: Array[MeshInstance3D] = []

var _front: Node3D
var _leaves: Array[MeshInstance3D] = []
var _was_open := false
@export var seed := 17
var _clock := 0.0


## Builds the book from the kit's live parts (by name), all in `material`; `hinge` is the kit's hinge point
## (Blender axes: the parts are moved so it lies at this node's origin).
func build(meshes: Dictionary, material: Material, hinge: Vector3) -> void:
	# (glTF: Blender's x, y, z are Godot's x, z, -y.)
	var offset := -Vector3(hinge.x, hinge.z, -hinge.y)
	# (Its halves and leaves move every frame: drawn where they are, not interpolated between physics ticks.)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_front = Node3D.new()
	_front.name = "front"
	add_child(_front)

	for part in ["live_cover_back", "live_block_right", "live_spine_back"]:
		var piece := _part(meshes.get(part), material, self, offset)
		if piece != null:
			piece.set_meta("book_part", part)
	for part in ["live_cover_front", "live_block_left", "live_spine_front"]:
		_part(meshes.get(part), material, _front, offset)

	# The leaves hang from the hinge at the back half's top (they begin where the spine ends).
	for i in LEAVES:
		var pivot := Node3D.new()
		pivot.name = "leaf_%d" % i
		add_child(pivot)
		var leaf := _part(meshes.get("live_leaf"), material, pivot, Vector3(-hinge.x, 0.0, 0.0))
		if leaf != null:
			leaf.visible = false
			_leaves.append(leaf)

	_pose()


func _part(mesh: Mesh, material: Material, parent: Node3D, offset: Vector3) -> MeshInstance3D:
	if mesh == null:
		return null
	var m := MeshInstance3D.new()
	m.mesh = mesh
	for i in mesh.get_surface_count():
		m.set_surface_override_material(i, material)
	parent.add_child(m)
	m.position = offset
	parts.append(m)
	return m


func _process(delta: float) -> void:
	_clock += delta
	var eye := watcher if is_instance_valid(watcher) else get_viewport().get_camera_3d()
	if eye != null:
		var far := eye.global_position.distance_to(_middle())
		if far > CLOSE_FAR:
			wanted = false
		elif far < OPEN_NEAR and _in_sight(eye):
			wanted = true

	open = move_toward(open, 1.0 if wanted else 0.0, delta / (OPEN_TIME if wanted else CLOSE_TIME))
	_pose()

	if open >= 1.0 and not _was_open:
		_was_open = true
		opened.emit(self)
	elif open <= 0.0 and _was_open:
		_was_open = false
		closed.emit(self)


## Where it is looked at: the middle of its top while shut (world).
func _middle() -> Vector3:
	return to_global(Vector3(0.12, 0.035, 0.0))


## Nothing solid between the eye and its top.
func _in_sight(eye: Node3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(eye.global_position, _middle())
	var body := eye.get_parent()
	while body != null and not body is CollisionObject3D:
		body = body.get_parent()
	if body != null:
		ray.exclude = [(body as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


## The front half turned over about the hinge (z), eased; the leaves following, each a little behind, seen only
## while in the air.
func _pose() -> void:
	var turn := smoothstep(0.0, 1.0, open)
	if _front != null:
		var breath := 0.5 + 0.5 * sin(_clock * 2.7 + seed)
		var lift := 0.007 * breath * (1.0 - turn) - 0.035 * breath * turn
		_front.rotation.z = PI * turn + lift

	for i in _leaves.size():
		var lag := LEAF_LAG * (i + 1)
		var t := smoothstep(0.0, 1.0, clampf((open - lag) / (1.0 - lag), 0.0, 1.0)) if open < 1.0 else 1.0
		if open > 0.95:
			t = lerpf(t, 0.88 + 0.065 * sin(_clock * 3.4 + seed + i * 1.4), (open - 0.95) / 0.05)
		var pivot := _leaves[i].get_parent() as Node3D
		pivot.rotation.z = PI * t
		_leaves[i].visible = t > 0.02 and t < 0.98
