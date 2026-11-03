extends Node3D
## The mouth, as a piece: the fused mass and its ribs (tools/monsters/build_anima_mouth.py), and
## the game's own hands and skulls pushed out of it, sunk past their ends, each still moving of
## itself. AnimaBody drives it; how it goes about is the body's.

const MODEL := "res://assets/monsters/anima_mouth.glb"
const HANDS_MODEL := "res://assets/monsters/anima_hands.glb"
const LEFT_MODEL := "res://assets/monsters/anima_hands_left.glb"
const AnimaSkullScript := preload("res://scripts/Monsters/AnimaSkull.gd")
const AnimaFire := preload("res://scripts/Monsters/AnimaFire.gd")
const FINGER_NAMES := ["index", "middle", "ring", "pinky", "thumb"]
const ARMS := [&"Arm_1", &"Arm_2", &"Arm_3", &"Arm_4", &"Arm_5"]
const FACES := [&"Face_1", &"Face_2", &"Face_3"]
const MESHES := [&"Mass", &"RibsLeft", &"RibsRight", &"Gullet", &"Candles", &"Bones"]
## How far along its marker each sits (m: past the collar, its end sunk), and the skulls' size.
const HAND_OUT := 0.2
const SKULL_SIZE := 1.3
## The model's floor and middle, from the body's: the monster stands at its own height above the floor.
const MIDDLE_BEHIND := -0.25
## How much bigger than it was built it stands: it is the heaviest of them.
const SIZE := 1.25
## How far each side of the ribs swings at the widest (rad).
const RIBS_SWING := 0.42
## The two that drag it: how fast each goes for its speed (not in step), how far each reaches and
## hauls (rad). How far it heaves with them (m), and rolls (rad).
const STRIDES := [2.1, 2.75]
const STRIDE_REACH := 0.6
const HEAVES := 0.09
const ROLLS := 0.11
## The rake: how far back each arm draws, how far over it comes (rad), a little after the last.
const RAKE_BACK := 0.75
const RAKE_OVER := 1.15
const RAKE_LAGS := 0.035
const RAKING_PAST := 0.35
## The life in what pushes out of it: how far an arm sways (rad), a finger's curl about what, how far.
const SWAY := 0.14
const CURL := 0.42
const CURLS := 0.32
const JAW_REST := 0.34
const JAW_WORKS := 0.3

var _parts := {}
var _souls: Array[Node3D] = []
var _hands: Array[Skeleton3D] = []
var _hand_meshes: Array[MeshInstance3D] = []
var _skulls: Array[Node3D] = []
var _embers: Array[MeshInstance3D] = []
var _rest: Dictionary = {}
var _ribs_open := 0.0
var _haul := 0.0
var _clock := 0.0
var _stride := [0.0, 0.0]
var _heave := 0.0
var _rake: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _rake_speed: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]


## Built on the body's flesh, and its bone: the same paint as the other forms.
func _init(flesh: ShaderMaterial, bone: ShaderMaterial, height: float) -> void:
	var made: Node3D = (load(MODEL) as PackedScene).instantiate()
	add_child(made)
	made.scale = Vector3.ONE * SIZE
	made.position = Vector3(0.0, -height, MIDDLE_BEHIND * -SIZE)

	for id in MESHES:
		var mesh: MeshInstance3D = made.find_child(id, true, false)
		_parts[id] = mesh
		mesh.set_surface_override_material(0, bone if id == &"RibsLeft" or id == &"RibsRight" or id == &"Bones" else flesh)

	for id in ARMS:
		var marker: Node3D = made.find_child(id, true, false)
		var hand: Node3D = (load(LEFT_MODEL if marker.position.x < 0.0 else HANDS_MODEL) as PackedScene).instantiate()
		hand.position = Vector3(0.0, 0.0, -HAND_OUT)
		marker.add_child(hand)
		var mesh: MeshInstance3D = hand.find_children("*", "MeshInstance3D", true, false)[0]
		mesh.set_surface_override_material(0, flesh)
		_hand_meshes.append(mesh)
		_hands.append(hand.find_children("*", "Skeleton3D", true, false)[0])
		_embers.append(AnimaFire.ember_on(mesh, 0.009))
		_souls.append(hand)

	for id in FACES:
		var marker: Node3D = made.find_child(id, true, false)
		var skull: Node3D = AnimaSkullScript.new(bone)
		skull.scale = Vector3.ONE * SKULL_SIZE
		marker.add_child(skull)
		_skulls.append(skull)
		_souls.append(skull)

	for i in _souls.size():
		_rest[_souls[i]] = _souls[i].transform


func part(id: StringName) -> MeshInstance3D:
	return _parts.get(id)


func souls() -> Array[Node3D]:
	return _souls


## How far the ribs stand open, 0..1.
func ribs_open() -> float:
	return _ribs_open


func ribs_to(open: float) -> void:
	_ribs_open = open
	# (RibsLeft lies at -x: it opens the way y turns, seen from above; RibsRight the other.)
	part(&"RibsLeft").rotation.y = RIBS_SWING * open
	part(&"RibsRight").rotation.y = -RIBS_SWING * open


## Where each dragging arm is in its stride, -1..1.
func arm_stride(which: int) -> float:
	return sin(_stride[which])


## How high the mass has heaved with them (m).
func heave() -> float:
	return _heave


## How far over it the mass has rolled with them (rad).
func roll() -> float:
	return (sin(_stride[0]) - sin(_stride[1])) * ROLLS * minf(_haul, 1.0)


## How many arms are coming over in a rake.
func arms_raking() -> int:
	var count := 0

	for value in _rake:
		count += 1 if value > RAKING_PAST else 0

	return count


## Each tick: what pushes out of it goes on moving, each in its own time. `speed`: how fast it is
## being dragged. `rake_to`: -1 drawn back, 0 at rest, 1 come over. `fed` shows on all of it.
func tick(delta: float, speed: float, rake_to: float, fed: float, hurt: float, smoulder: float) -> void:
	_clock += delta
	_haul = move_toward(_haul, minf(speed, 1.5), delta * 3.0)

	for i in _stride.size():
		_stride[i] += delta * STRIDES[i] * speed

	# Each haul lifts it and lets it drop.
	_heave = (absf(sin(_stride[0])) + absf(sin(_stride[1]))) * 0.5 * HEAVES * minf(_haul, 1.0)

	for i in _rake.size():
		var w := minf(TAU * 7.0, 0.8 / delta)
		var late := clampf(float(i) * RAKE_LAGS, 0.0, 0.2)
		_rake_speed[i] += (w * w * (rake_to - _rake[i]) - 2.0 * 0.75 * w * _rake_speed[i]) * delta * (1.0 - late)
		_rake[i] += _rake_speed[i] * delta

	for i in _souls.size():
		var soul := _souls[i]
		var seed := float(i) * 2.3 + 0.7
		var sway := Basis.from_euler(Vector3(sin(_clock * (0.9 + float(i) * 0.13) + seed), sin(_clock * (0.7 + float(i) * 0.09) + seed * 1.7), 0.0) * SWAY)
		var rest: Transform3D = _rest[soul]
		var swing := Basis.IDENTITY

		if i < _rake.size():
			var over: float = _rake[i] * (RAKE_OVER if _rake[i] > 0.0 else RAKE_BACK)
			# The two that drag it go on hauling.
			var haul: float = sin(_stride[i]) * STRIDE_REACH * minf(_haul, 1.0) if i < _stride.size() else 0.0
			swing = Basis(Vector3.RIGHT, -over + haul)

		soul.transform = Transform3D(swing * sway * rest.basis, rest.origin)

	for i in _hands.size():
		_curl_fingers(_hands[i], i)
		_hand_meshes[i].set_instance_shader_parameter(&"fed", fed)
		_hand_meshes[i].set_instance_shader_parameter(&"hurt", hurt)
		_hand_meshes[i].set_instance_shader_parameter(&"smoulder", smoulder)

	for i in _skulls.size():
		var seed := float(i) * 3.1
		_skulls[i].open_to(clampf(JAW_REST + sin(_clock * (2.1 + float(i) * 0.7) + seed) * JAW_WORKS, 0.0, 1.0), 0.3)
		_skulls[i].paint(fed, hurt, smoulder)

	for id in MESHES:
		var mesh: MeshInstance3D = part(id)
		mesh.set_instance_shader_parameter(&"fed", fed)
		mesh.set_instance_shader_parameter(&"hurt", hurt)
		mesh.set_instance_shader_parameter(&"smoulder", smoulder)


func _curl_fingers(hand: Skeleton3D, which: int) -> void:
	for f in FINGER_NAMES.size():
		var seed := float(f) * 1.9 + float(which) * 2.3
		var palsy := sin(_clock * 3.0 + seed) * 0.6 + sin(_clock * 7.7 + seed * 2.0) * 0.4
		var shut := CURL + palsy * CURLS

		for k in range(1, 4):
			var bone := hand.find_bone("%s_%02d" % [FINGER_NAMES[f], k])
			var rest: Basis = hand.get_bone_rest(bone).basis
			hand.set_bone_pose_rotation(bone, (rest * Basis(Vector3.RIGHT, -shut * [0.7, 1.0, 1.25][k - 1])).get_rotation_quaternion())
