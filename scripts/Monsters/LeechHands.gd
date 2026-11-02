extends Node3D
## The hands of whatever is on you, clawing AT you: withered and real, coming up from out
## in the world on the side each is on, palm to you, nails hooked at your face. Before a
## gulp they rear back, open; on it they rake down your view and close, a finger at a time,
## and between gulps the fingers go on scrabbling at you. Worse as they feed. Never over the
## crosshair. Drawn as the viewmodel is (HandSlot.gd). A camera
## child of the player; LifeLeech says who is on.

const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const FleshShader := preload("res://scripts/Monsters/anima_flesh.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")
const HANDS_MODEL := "res://assets/monsters/anima_hands.glb"
const AnimaFire := preload("res://scripts/Monsters/AnimaFire.gd")

const VIEWMODEL_LAYER := 1 << 18
const FINGER_NAMES := ["index", "middle", "ring", "pinky", "thumb"]
## Where a hand has hold, as you look (its wrist): left, right, or low if those are taken.
const ANCHORS := [Vector3(-0.33, -0.21, -0.66), Vector3(0.36, -0.21, -0.66), Vector3(-0.09, -0.42, -0.66)]
## The way its fingers point from there: AT you. Up and toward your face, the palm
## turned to you, the arm running away behind it into the world, to what it belongs to.
const POINTS := [Vector3(0.28, 0.42, 0.86), Vector3(-0.28, 0.42, 0.86), Vector3(0.02, 0.5, 0.86)]
const BACKS := [Vector3(-0.1, 0.9, -0.42), Vector3(0.1, 0.9, -0.42), Vector3(0.0, 0.9, -0.5)]
## How big, in the view's miniature.
const SIZE := 0.44
## How the fingers curl: wide open on the wind-up, shut at the end of a rake, and how
## they sit between; a finger's lag behind the one before; how hard they scrabble.
const CURL_OPEN := -0.1
const CURL_SHUT := 1.15
const CURL_REST := 0.62
const FINGER_LAG := 0.13
const SCRABBLE := 0.17
## The rake, as a share of a gulp's fading it takes; how high it rears, how far down
## it drags, how far at you it lunges, how far it swings across.
const RAKE_TAKES := 0.42
const REARS := 0.1
const DRAGS := 0.065
const LUNGE := 0.1
const ACROSS := 0.035
## How far apart the fingers fan: wide on the wind-up, drawn in down the rake.
const SPLAY_WIDE := 0.17
## How far it tips its palm up at you, rearing.
const REAR_TIP := 0.85
const SPLAY_SHUT := 0.03
## In from out of your sight when it gets hold, flung back out when it loses it.
const ARRIVES := 0.14
const FLUNG_FOR := 0.14
const COMES_FROM := 0.42
const FLUNG_TO := 0.6
const FULL := 60.0

var player: CharacterBody3D
var _hands: Array[Node3D] = []
var _skeletons: Array[Skeleton3D] = []
var _meshes: Array[MeshInstance3D] = []
var _embers: Array[MeshInstance3D] = []
var _anchor_of: Array[int] = [0, 1, 2]
var _squeeze: Array[float] = [0.0, 0.0, 0.0]
var _curl: Array[float] = [0.0, 0.0, 0.0]
var _spread: Array[float] = [0.0, 0.0, 0.0]
var _arrive: Array[float] = [0.0, 0.0, 0.0]
var _flung: Array[float] = [0.0, 0.0, 0.0]
var _held: Array[bool] = [false, false, false]
var _fed: Array[float] = [0.0, 0.0, 0.0]
var _splay_low: Array[float] = [9.0, 9.0, 9.0]
var _splay_high: Array[float] = [-9.0, -9.0, -9.0]
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
		_embers.append(AnimaFire.ember_on(mesh, 0.008, ViewArmsScript.Z_CLIP, ViewArmsScript.VIEW_FOV))


func shown(slot: int) -> bool:
	return _hands[slot].visible


## How hard the hand in `slot` has hold, 0..1.
func squeeze(slot: int) -> float:
	return _squeeze[slot]


func has_ember(slot: int) -> bool:
	return _embers[slot] != null


## How far its fingers are shut, as a whole.
func curl(slot: int) -> float:
	return _curl[slot]


## How far into your view it has come, 0..1.
func arrival(slot: int) -> float:
	return _arrive[slot]


## How much is left of its being flung off, 0 when it isn't.
func flung(slot: int) -> float:
	return _flung[slot]


## How far its fingers' fan has ranged.
func splay_range(slot: int) -> float:
	return _splay_high[slot] - _splay_low[slot]


## How high the hand in `slot` is, in your view.
func reach_y(slot: int) -> float:
	return _hands[slot].position.y


## How far apart its fingers are, curling.
func finger_spread(slot: int) -> float:
	return _spread[slot]


## Where the hand in `slot` has hold on the screen, 0..1.
func on_screen(slot: int) -> Vector2:
	var at: Vector3 = ANCHORS[_anchor_of[slot]]
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

		if who == null or player.is_dead:
			if _held[slot] and not player.is_dead:
				_flung[slot] = FLUNG_FOR

			_held[slot] = false
			_flung[slot] = maxf(_flung[slot] - delta, 0.0)
			_hands[slot].visible = _flung[slot] > 0.0

			if _flung[slot] > 0.0:
				_pose(slot, _anchor_of[slot], _fed[slot], 0.0, 0.0)

			continue

		if not _held[slot]:
			_arrive[slot] = 0.0
			_held[slot] = true

		_flung[slot] = 0.0
		_arrive[slot] = minf(_arrive[slot] + delta / ARRIVES, 1.0)
		_hands[slot].visible = true
		var anchor := _anchor_for(who, taken)
		taken.append(anchor)
		_anchor_of[slot] = anchor
		_fed[slot] = float(who.fed)
		_pose(slot, anchor, float(who.fed), player.leech.gulp(), player.leech.coming())


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


func _pose(slot: int, anchor: int, fed: float, gulp: float, coming: float) -> void:
	var fingers: Vector3 = POINTS[anchor].normalized()
	var fed_share := clampf(fed / FULL, 0.0, 1.0)
	# Each hand a beat behind the last, so they don't move as one.
	var rake := clampf((1.0 - gulp) / RAKE_TAKES - float(slot) * 0.12, 0.0, 1.0)
	var raking := gulp > 0.001
	var eased := 1.0 - pow(1.0 - rake, 3.0)
	# Up and back as the next gulp comes, then down and at you with it.
	var wind := smoothstep(0.5, 1.0, coming)
	var height: float = lerpf(REARS, -DRAGS, eased) if raking else lerpf(-DRAGS, REARS, wind)
	var at_you: float = (sin(rake * PI) * LUNGE if raking else -wind * LUNGE * 0.5)
	var side := signf(ANCHORS[anchor].x)
	var swing: float = -side * ACROSS * (eased if raking else 1.0 - wind)
	var offset := Vector3(swing, height, 0.0) + fingers * at_you
	# Coming at you, and flung away.
	offset -= fingers * COMES_FROM * pow(1.0 - _arrive[slot], 2.0)

	if _flung[slot] > 0.0:
		var gone := 1.0 - _flung[slot] / FLUNG_FOR
		offset -= fingers * FLUNG_TO * gone * gone
		offset.y -= 0.25 * gone

	# Rearing, it tips its open palm up at you; down the rake it comes back over.
	var rears_up: float = wind if not raking else (1.0 - eased)
	var facing := Basis(Vector3.RIGHT, -REAR_TIP * rears_up) * Basis.looking_at(fingers, BACKS[anchor]).rotated(fingers, side * (0.35 * eased - 0.2))
	_hands[slot].transform = Transform3D(facing.scaled(Vector3.ONE * SIZE), ANCHORS[anchor] + offset)
	_squeeze[slot] = clampf(0.25 + fed_share * 0.2 + gulp * 0.55, 0.0, 1.0)
	var skeleton := _skeletons[slot]
	_meshes[slot].set_instance_shader_parameter(&"fed", fed_share)
	_embers[slot].set_instance_shader_parameter(&"flare", clampf(fed_share * 0.5 + gulp * 0.45, 0.0, 0.95))
	var total := 0.0
	var least := 9.0
	var most := -9.0

	for f in FINGER_NAMES.size():
		# Open on the wind-up; shut, one after another, down the rake; scrabbling between.
		var this_rake := clampf((1.0 - gulp) / RAKE_TAKES - float(f) * FINGER_LAG, 0.0, 1.0)
		var shut: float = lerpf(CURL_OPEN, CURL_SHUT, smoothstep(0.0, 1.0, this_rake)) if raking else lerpf(CURL_REST, CURL_OPEN, wind)
		# A palsy, uneven, and now and then a finger jerks of itself.
		var seed := float(f) * 1.9 + float(slot) * 2.3
		var palsy := sin(_clock * 15.0 + seed) * 0.6 + sin(_clock * 23.7 + seed * 2.0) * 0.4
		var jerk := sin(floor(_clock * 7.0 + seed) * 12.9898) * 0.6
		shut += (palsy + jerk) * SCRABBLE * (1.0 - wind) * (1.0 + fed_share)
		# Flailing, flung off.
		if _flung[slot] > 0.0:
			shut = sin(_clock * 40.0 + seed) * 0.5
		total += shut
		least = minf(least, shut)
		most = maxf(most, shut)

		# The fan, about the middle of the hand; and the last joint hooks the most.
		var fan_rake := smoothstep(0.0, 1.0, this_rake) if raking else 1.0 - wind
		var fan: float = lerpf(SPLAY_WIDE, SPLAY_SHUT, fan_rake)
		_splay_low[slot] = minf(_splay_low[slot], fan)
		_splay_high[slot] = maxf(_splay_high[slot], fan)
		var out_of_middle := (float(f) - 1.5) * fan if f < 4 else fan * 2.2

		for k in range(1, 4):
			var bone := skeleton.find_bone("%s_%02d" % [FINGER_NAMES[f], k])
			var rest: Basis = skeleton.get_bone_rest(bone).basis
			var turn := Basis(Vector3.RIGHT, -shut * [0.7, 1.0, 1.25][k - 1])

			if k == 1:
				turn = Basis(Vector3.BACK, -out_of_middle) * turn

			skeleton.set_bone_pose_rotation(bone, (rest * turn).get_rotation_quaternion())

	_curl[slot] = total / float(FINGER_NAMES.size())
	_spread[slot] = most - least
