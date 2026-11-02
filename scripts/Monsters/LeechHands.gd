extends Node3D
## The hands of whatever is on you, clutching AT you: withered and real, coming up from
## out in the world on the side each is on, palm to you, nails hooked at your face. With
## every gulp they lunge closer and close on you, and clench harder as they feed. Never
## over the crosshair. Drawn as the viewmodel is (HandSlot.gd). A camera
## child of the player; LifeLeech says who is on.

const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const FleshShader := preload("res://scripts/Monsters/anima_flesh.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")
const HANDS_MODEL := "res://assets/monsters/anima_hands.glb"

const VIEWMODEL_LAYER := 1 << 18
const FINGER_NAMES := ["index", "middle", "ring", "pinky", "thumb"]
## Where a hand has hold, as you look (its wrist): left, right, or low if those are taken.
const ANCHORS := [Vector3(-0.33, -0.21, -0.66), Vector3(0.36, -0.21, -0.66), Vector3(-0.05, -0.31, -0.66)]
## The way its fingers point from there: AT you. Up and toward your face, the palm
## turned to you, the arm running away behind it into the world, to what it belongs to.
const POINTS := [Vector3(0.28, 0.42, 0.86), Vector3(-0.28, 0.42, 0.86), Vector3(0.02, 0.5, 0.86)]
const BACKS := [Vector3(-0.1, 0.9, -0.42), Vector3(0.1, 0.9, -0.42), Vector3(0.0, 0.9, -0.5)]
## How big, in the view's miniature.
const SIZE := 0.44
## How far the fingers curl at rest, and how much harder with a gulp: they close on you.
const CURL := 0.5
const CURL_GULP := 0.55
## With a gulp it lunges at you, this far.
const LUNGE := 0.07
const FULL := 60.0

var player: CharacterBody3D
var _hands: Array[Node3D] = []
var _skeletons: Array[Skeleton3D] = []
var _meshes: Array[MeshInstance3D] = []
var _anchor_of: Array[int] = [0, 1, 2]
var _squeeze: Array[float] = [0.0, 0.0, 0.0]
var _clock := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var look := ShaderMaterial.new()
	look.shader = FleshShader
	look.set_shader_parameter(&"stroke_sheet", BRUSH)
	look.set_shader_parameter(&"wet", 0.0)
	look.set_shader_parameter(&"fill", 0.5)
	look.set_shader_parameter(&"rim", 0.3)
	look.set_shader_parameter(&"z_clip", ViewArmsScript.Z_CLIP)
	look.set_shader_parameter(&"fov_override", ViewArmsScript.VIEW_FOV)
	var scene := load(HANDS_MODEL) as PackedScene

	for slot in 3:
		var hand: Node3D = scene.instantiate()
		hand.visible = false
		hand.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(hand)
		_hands.append(hand)
		_skeletons.append(hand.find_children("*", "Skeleton3D", true, false)[0])
		var mesh: MeshInstance3D = hand.find_children("*", "MeshInstance3D", true, false)[0]
		mesh.layers = VIEWMODEL_LAYER
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.set_surface_override_material(0, look)
		_meshes.append(mesh)


func shown(slot: int) -> bool:
	return _hands[slot].visible


## How hard the hand in `slot` has hold, 0..1.
func squeeze(slot: int) -> float:
	return _squeeze[slot]


## Where the hand in `slot` has hold on the screen, 0..1.
func on_screen(slot: int) -> Vector2:
	var at := _hands[slot].position
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
		_hands[slot].visible = who != null and not player.is_dead

		if who == null:
			continue

		var anchor := _anchor_for(who, taken)
		taken.append(anchor)
		_pose(slot, anchor, float(who.fed), player.leech.gulp())


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


func _pose(slot: int, anchor: int, fed: float, gulp: float) -> void:
	var fingers: Vector3 = POINTS[anchor].normalized()
	var haul := fingers * LUNGE * gulp * gulp
	# The model's fingers go along its -Z, the back of the hand its +Y.
	_hands[slot].transform = Transform3D(Basis.looking_at(fingers, BACKS[anchor]).scaled(Vector3.ONE * SIZE), ANCHORS[anchor] + haul)
	var tremble := sin(_clock * 31.0 + float(slot) * 2.1) * 0.03
	_squeeze[slot] = clampf(0.25 + clampf(fed / FULL, 0.0, 1.0) * 0.2 + gulp * 0.55, 0.0, 1.0)
	var curl: float = CURL + CURL_GULP * gulp + tremble
	var skeleton := _skeletons[slot]
	_meshes[slot].set_instance_shader_parameter(&"fed", clampf(fed / FULL, 0.0, 1.0))

	for finger in FINGER_NAMES:
		for k in range(1, 4):
			var bone := skeleton.find_bone("%s_%02d" % [finger, k])
			var rest: Basis = skeleton.get_bone_rest(bone).basis
			skeleton.set_bone_pose_rotation(bone, (rest * Basis(Vector3.RIGHT, -curl * (0.8 if k == 1 else 1.0))).get_rotation_quaternion())
