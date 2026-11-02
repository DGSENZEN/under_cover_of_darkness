extends Node3D
## The hands of whatever is on you, seen where they have hold of you: at your collar
## and shoulder, on the side each is on, clutching harder as it feeds, never over the
## crosshair. Drawn as the viewmodel is (HandSlot.gd). A camera child of the player;
## LifeLeech says who is on. Stand-in hands until the models are made.

const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")

const VIEWMODEL_LAYER := 1 << 18
## Where a pair sits as you look: to the left, the right, or low, if those are taken.
const ANCHORS := [Vector3(-0.27, -0.16, -0.42), Vector3(0.27, -0.16, -0.42), Vector3(-0.03, -0.25, -0.4)]
const CLUTCH := 0.45
const FINGERS := 4
const WITHERED := Color(0.17, 0.15, 0.12)

var player: CharacterBody3D
var _pairs: Array[Node3D] = []
var _look: StandardMaterial3D
var _clock := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_look = StandardMaterial3D.new()
	_look.albedo_color = WITHERED
	_look.emission_enabled = true
	_look.emission = WITHERED * 0.5
	_look.roughness = 1.0
	_look.use_z_clip_scale = true
	_look.z_clip_scale = ViewArmsScript.Z_CLIP
	_look.use_fov_override = true
	_look.fov_override = ViewArmsScript.VIEW_FOV
	_look.render_priority = 11

	for slot in 3:
		var pair := Node3D.new()
		pair.visible = false
		pair.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(pair)
		_build_hand(pair)
		_pairs.append(pair)


func _build_hand(pair: Node3D) -> void:
	_piece(pair, Vector3(0.06, 0.018, 0.08), Vector3(0, 0, 0.0))

	for i in FINGERS:
		var finger := Node3D.new()
		finger.name = "Finger%d" % i
		finger.position = Vector3((float(i) - 1.5) * 0.016, 0.0, -0.04)
		pair.add_child(finger)
		_piece(finger, Vector3(0.011, 0.011, 0.075), Vector3(0, 0, -0.037))


func _piece(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var piece := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _look
	piece.mesh = box
	piece.position = at
	piece.layers = VIEWMODEL_LAYER
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece)


func shown(slot: int) -> bool:
	return _pairs[slot].visible


## Where the pair in `slot` is on the screen, 0..1.
func on_screen(slot: int) -> Vector2:
	var at := _pairs[slot].position
	var tall := tan(deg_to_rad(ViewArmsScript.VIEW_FOV) * 0.5) * maxf(-at.z, 0.001)
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	return Vector2(at.x / (tall * aspect), -at.y / tall) * 0.5 + Vector2(0.5, 0.5)


func _process(delta: float) -> void:
	_clock += delta

	if player == null or player.leech == null:
		return

	var taken: Array[int] = []

	for slot in 3:
		var who: Node3D = player.leech.who_in(slot)
		_pairs[slot].visible = who != null and not player.is_dead

		if who == null:
			continue

		var anchor := _anchor_for(who, taken)
		taken.append(anchor)
		_pose(_pairs[slot], anchor, slot, float(who.fed))


## The side of your view it is on; low, if that side is taken.
func _anchor_for(who: Node3D, taken: Array[int]) -> int:
	var camera := get_parent() as Node3D
	var side: float = camera.to_local(who.global_position).x if camera != null else 0.0
	var wanted := 0 if side < 0.0 else 1

	if not taken.has(wanted):
		return wanted

	if not taken.has(2):
		return 2

	return 1 - wanted


func _pose(pair: Node3D, anchor: int, slot: int, fed: float) -> void:
	var from_side := -signf(ANCHORS[anchor].x) if anchor < 2 else 0.0
	var beat := sin(_clock * (5.0 + fed * 0.1) + float(slot) * 2.1) * 0.5 + 0.5
	pair.position = ANCHORS[anchor]
	pair.rotation = Vector3(-0.5, from_side * 0.9, from_side * 0.25)

	for child in pair.get_children():
		if child.name.begins_with("Finger"):
			child.rotation.x = -CLUTCH - beat * 0.5
