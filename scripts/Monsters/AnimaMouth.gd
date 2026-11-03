extends Node3D
## The mouth, as a piece: the fused mass and its ribs (tools/monsters/build_anima_mouth.py), and
## arms grown out of it (build_mouth_arm.py), the game's own skulls pushed out of it, each still moving
## of itself. Its bottom hands dig into the earth and haul all of it up to them: a hand stays where it
## dug, in the world, and the arm is solved back from there to a shoulder sunk in the flesh. AnimaBody
## drives it; how it goes about is the body's.

const MODEL := "res://assets/monsters/anima_mouth.glb"
const ARM_MODEL := "res://assets/monsters/anima_mouth_arm.glb"
const LEFT_MODEL := "res://assets/monsters/anima_mouth_arm_left.glb"
const AnimaSkullScript := preload("res://scripts/Monsters/AnimaSkull.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const FINGER_NAMES := ["index", "middle", "ring", "pinky", "thumb"]
const ARMS := [&"Arm_1", &"Arm_2", &"Arm_3", &"Arm_4", &"Arm_5"]
const FACES := [&"Face_1", &"Face_2", &"Face_3"]
const MESHES := [&"Mass", &"RibsLeft", &"RibsRight", &"Gullet", &"Candles", &"Bones"]
## The skulls' size.
const SKULL_SIZE := 1.3
## The model's floor and middle, from the body's: the monster stands at its own height above the floor.
const MIDDLE_BEHIND := -0.25
## How much bigger than it was built it stands: it is the heaviest of them.
const SIZE := 1.25
## How far each side of the ribs swings at the widest (rad).
const RIBS_SWING := 0.42

## The arm's bones, as built (m, in the arm's own size); how far into the flesh the shoulder is from
## where it comes out, and how far an arm may be drawn out.
const BONE_LENGTH := 0.42
const SHOULDER_IN := 0.3
const DRAWN_OUT_MOST := 1.25
## Which arms dig: the two that haul it, then the two that brace and haul a little.
const DIGGERS := 4
const HAULERS := 2
## The order its limbs go in, as an animal's do: a front, the far rear, the other front, its rear. How long
## after one starts the next does, with it moving (s).
const GAIT: Array[int] = [0, 3, 1, 2]
const GAIT_GAP := Vector2(0.34, 0.86)
## The four are not a set: what each did to end up in it. How long each takes to come over, how high it
## lifts, where it digs in from its shoulder (m), ahead and out; how high it holds its wrist; how far its
## elbow stands out. The first reaches far and eager, the second is short and high, the third a splayed
## brace, the last drags, it hardly lifts.
const REACH_TAKES: Array[float] = [0.8, 1.05, 0.72, 1.25]
const REACH_LIFT: Array[float] = [0.5, 0.42, 0.3, 0.13]
const DIGS_AHEAD: Array[float] = [0.72, 0.4, 0.34, 0.16]
const DIGS_OUT: Array[float] = [0.56, 0.62, 0.96, 0.62]
const WRIST_UP: Array[float] = [0.38, 0.32, 0.42, 0.25]
const ELBOW_OUT: Array[float] = [0.7, 1.1, 0.35, 1.25]
## How much any one step differs from the last of that limb's, each way.
const STEP_VARIES := 0.28
## How long the haul with a limb takes to come and go (s): it surges when one has dug in.
const HAUL_TAKES: Array[float] = [1.5, 1.7, 1.9, 2.1]
## A step: how much of it is lifting out and over; where it hovers, feeling for the ground, and how high; how
## often it stops to, and how much slower it goes then. It strikes from there.
const STEP_OVER := 0.68
const STEP_HOVER_ENDS := 0.86
const HOVER_HIGH := 0.13
const HOVER_CHANCE := 0.45
const HOVER_SLOWS := 0.28
## How its hand drives into the earth, and how shut its fingers are, dug in; how far a step can turn it.
const DRIVES_DOWN := 1.5
const DUG_SHUT := 0.62
const STEP_TURNS := 0.45
## How far it lets a dug hand trail before it has to let go (m).
const TRAILS_MOST := 1.18
## It goes as it hauls: how fast, of its speed, with nothing hauling, and hauling flat out; what the
## braces add; how far it heaves up with a haul (m), rolls side to side and rocks onto its front (rad).
const LURCH_LEAST := 0.18
const LURCH_MOST := 0.95
const BRACES_ADD := 0.25
const HEAVES := 0.13
const ROLLS := 0.14
const ROCKS := 0.12
## How far it leans off a limb that is up (rad).
const LEANS_OFF := 0.07
## An arm that isn't digging, out from its shoulder (m), hanging; how fast it gets where it is going.
const FREE_OUT := 0.62
const FREE_HANGS := 0.3
const FREE_RATE := 7.0
const GRAB_RATE := 3.2
const GRAB_SPREAD := 0.28
## How far from its shoulder any arm can get, however hard it goes (m).
const ARM_GETS := 1.45
## The rake: how far back each arm draws, how far over it comes (rad), a little after the last.
const RAKE_BACK := 0.75
const RAKE_OVER := 1.15
const RAKE_LAGS := 0.035
const RAKING_PAST := 0.35
const RAKE_RATE := 2.4
## How much bigger it is at its most swollen, each way: across, up, out toward you; how far on it goes.
const SWELLS := Vector3(0.26, 0.15, 0.34)
const SWELLS_ON := 0.3
## The life in what pushes out of it: how far an arm sways (m, rad), a finger's curl about what, how far.
const SWAY := 0.05
const HEAD_SWAY := 0.14
const CURL := 0.42
const CURLS := 0.32
const JAW_REST := 0.34
const JAW_WORKS := 0.3
const FLOOR_MASK := 1
## How much of its hunger it has crawling along, and how fast it comes up and goes.
const HUNGER_LOW := 0.08
const HUNGER_RATE := 2.0
## Those in it, with its skin drawn over them, pushing up out of it (tools/monsters/build_mouth_sheaths.py).
const SHEATH_MODEL := "res://assets/monsters/mouth_sheath.glb"
## Where a face's jaw hangs from, its eyes and its gape are; how big each is; how far along the way out it goes,
## from under the skin to as far as it gets (m). How far its jaw drops (rad), and how hard the light in it burns.
const FACE_HINGE := Vector3(0.0, -0.043, -0.042)
const FACE_EYE := Vector3(0.044, 0.005, -0.088)
const FACE_THROAT := Vector3(0.0, -0.085, -0.015)
const FACE_SIZE := 1.3
const HAND_SIZE := 0.72
const FACE_OUT := Vector2(-0.24, 0.06)
const HAND_OUT := Vector2(-0.13, 0.015)
const JAW_DROPS := 0.8
const LightShader := preload("res://scripts/Monsters/mouth_light.gdshader")
const LIGHT_SHOWS_FROM := 0.72
const LEFT_BARE := "res://assets/monsters/anima_hands_left.glb"
const RIGHT_BARE := "res://assets/monsters/anima_hands.glb"
## How many; what each is, 0 a face, 1 a hand; how big each kind is, half across (m); where they can be.
const PRESSES := 6
const PRESS_KIND: Array[int] = [0, 1, 0, 1, 0, 1]
const PRESS_SIZE: Array[float] = [0.26, 0.34, 0.2]
## The elite: how many it can hold, how many of its candles are alight, how far out what it took stands (m).
const MOST_TAKEN := 3
## The arm it seizes with, how fast, and how far out it may be drawn.
const SEIZING_ARM := 2
const SEIZE_RATE := 22.0
const SEIZE_DRAWS_OUT := 2.6
const CANDLE_FLAMES := 7
const TAKEN_FACE_OUT := 0.02
const TAKEN_HAND_OUT := 0.012
const PRESS_PICKS := 4
const SPOT_TRIES := 140
const SPOT_CLEAR := 0.16
const SPOT_APART := 0.13
const SPOT_ABOVE := 0.2
const MOUTH_ENDS_Z := 0.32
const MOUTH_WIDE := 0.34
## How long each part of it takes (s); how far in the skin goes after it; how far a face turns to you; how
## many are the wrong way up.
const PRESS_RISES := Vector2(0.5, 1.2)
const PRESS_HOLDS := Vector2(0.6, 2.0)
const PRESS_HAULED := 0.12
const PRESS_RECOILS := 0.45
const PRESS_RESTS := Vector2(0.2, 1.6)
const PRESS_DENT := -0.4
const PRESS_LEANS := 0.45
const PRESS_UPSIDE_DOWN := 0.2
const PRESS_HUNGRY_FROM := 0.55
## The real hands that get out: how many; how long until the first (s), each part of it; where its wrist is,
## along the way out from its skin, hidden and out (m); how far past its wrist its fingers go.
const BURSTS := 2
const BURST_FIRST := 2.0
const BURST_SWELLS := 0.7
const BURST_COMES := 0.16
const BURST_CLAWS := Vector2(0.9, 2.2)
const BURST_HAULED := 0.14
const BURST_RESTS := Vector2(3.0, 8.0)
const BURST_HIDDEN := -0.8
const BURST_OUT := -0.1
const BURST_TIPS := 0.68
## Its heads straining out of it, from how far in to how far out (m), and how fast they go back (s).
const SKULL_IN := -0.08
const SKULL_OUT := 0.14
const SKULL_HAULED := 0.12
## Coming apart: how fast those in it get out of it (m/s), how far up they go; how much they keep of a bounce; what they
## lie at on the floor (m); how far a flame stands on it.
const FREED_SPEED := Vector2(1.6, 3.2)
const FREED_UP := Vector2(1.4, 2.8)
const FREED_BOUNCE := 0.28
const FREED_LIES := 0.1
const RIBS_LIE := 0.28
const FLAME_ON_IT := 0.42
const FLAME_ON_THEM := 0.3
const SLUMP_DOWN := 0.66
const SLUMP_OUT := 0.3
const LIMP_WRIST_UP := 0.1
## The earth it throws up round each hand: how many are out at once, how long one stays, how long it takes
## to rise, and to sink back; its paint.
const EARTHS := 12
const EARTH_STAYS := 9.0
const EARTH_RISES := 0.1
const EARTH_SINKS := 1.5
const EARTH_DARK := Color(0.03, 0.022, 0.018)
const EARTH_LIGHT := Color(0.085, 0.062, 0.045)

var _parts := {}
var _made: Node3D
var _made_at := Vector3.ZERO
var _souls: Array[Node3D] = []
var _hands: Array[Skeleton3D] = []
var _hand_meshes: Array[MeshInstance3D] = []
var _markers: Array[Node3D] = []
var _skulls: Array[Node3D] = []
var _rest: Dictionary = {}
var _ribs_open := 0.0
var _clock := 0.0
var _heave := 0.0
var _hauls := 0
var _swell := 0.0
var _rake: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _rake_speed: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
## Each arm: its wrist in the world; dug in, and where and on what; how long it has hauled, or been
## on its way; where it came up from; how shut its fingers are.
var _wrist: Array[Vector3] = []
var _dug: Array[bool] = []
var _dug_floor: Array[float] = []
var _haul_t: Array[float] = []
var _reach_t: Array[float] = []
var _came_from: Array[Vector3] = []
var _shut: Array[float] = []
var _stretch: Array[float] = []
## This step of each limb: how long, how high, how far on, how far out, how high its wrist, how turned; whether it hovers.
var _step_takes: Array[float] = []
var _step_lift: Array[float] = []
var _step_ahead: Array[float] = []
var _step_out: Array[float] = []
var _step_wrist: Array[float] = []
var _step_turn: Array[float] = []
var _step_hovers: Array[bool] = []
var _gait_at := 0
var _gait_in := 0.0
var _leaning := 0.0
var _flesh_look: ShaderMaterial
var _earths: Array[MeshInstance3D] = []
var _earth_age: Array[float] = []
var _earth_next := 0
var _earth_look: ShaderMaterial
var _mass_look: ShaderMaterial
var _skin_skull: Mesh
var _skin_jaw: Mesh
var _skin_hand: Mesh
var _skin_look: ShaderMaterial
var _light_look: ShaderMaterial
## The elite: how big it stands, of the plain one.
var _seizing := false
var _seized_at := Vector3.ZERO
var _elite := false
var _size := 1.0
var _candle_flames: Array[MeshInstance3D] = []
var _taken: Array[Dictionary] = []
var _taken_spots: Array[int] = []
var _press_nodes: Array[Node3D] = []
var _press_jaws: Array = []
var _press_lights: Array = []
var _held_jaw := -1.0
var _press_stage: Array[int] = []
var _press_t: Array[float] = []
var _press_takes: Array[float] = []
var _press_strength: Array[float] = []
var _press_jaw: Array[float] = []
var _press_spot: Array[int] = []
var _press_at: Array[Vector3] = []
var _press_way: Array[Vector3] = []
var _press_up: Array[Vector3] = []
var _press_roll: Array[float] = []
var _press_slide: Array[Vector3] = []
var _uniform_at := PackedVector4Array([Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4()])
var _uniform_way := PackedVector4Array([Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4()])
var _uniform_up := PackedVector4Array([Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4(), Vector4()])
var _uniform_size := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
var _burst_nodes: Array[Node3D] = []
var _burst_skeletons: Array[Skeleton3D] = []
var _burst_stage: Array[int] = []
var _burst_t: Array[float] = []
var _burst_takes: Array[float] = []
var _burst_at: Array[float] = []
var _burst_spot: Array[int] = []
var _tear: Array[float] = []
var _skull_stage: Array[int] = []
var _skull_t: Array[float] = []
var _skull_takes: Array[float] = []
var _skull_out: Array[float] = []
var _hunger := 0.0
## Coming apart: what has yet to get out; what has, flying or lying; where its ribs started from; how soon the next goes.
var _dying := false
var _still_in: Array[int] = []
var _freed: Array[Dictionary] = []
var _ribs_gone := false
var _ribs_from: Array[Vector3] = []
var _frees_in := 0.0
var _tear_at: Array[int] = []
var _rng := RandomNumberGenerator.new()
var _placed := false
var _floor_y := 0.0


## Built on the body's flesh, and its bone: the same paint as the other forms.
func _init(flesh: ShaderMaterial, bone: ShaderMaterial, height: float) -> void:
	_flesh_look = flesh
	var arm_look: ShaderMaterial = flesh.duplicate()
	arm_look.set_shader_parameter(&"frays", 0.0)
	_earth_look = flesh.duplicate()
	_earth_look.set_shader_parameter(&"spectral", 0.0)
	_earth_look.set_shader_parameter(&"frays", 0.0)
	_earth_look.set_shader_parameter(&"rim", 0.0)
	_earth_look.set_shader_parameter(&"fill", 0.2)
	_made = (load(MODEL) as PackedScene).instantiate()
	add_child(_made)
	_made.scale = Vector3.ONE * SIZE
	_made_at = Vector3(0.0, -height, MIDDLE_BEHIND * -SIZE)
	_made.position = _made_at

	for id in MESHES:
		var mesh: MeshInstance3D = _made.find_child(id, true, false)
		_parts[id] = mesh
		mesh.set_surface_override_material(0, bone if id == &"RibsLeft" or id == &"RibsRight" or id == &"Bones" else flesh)

	for id in ARMS:
		var marker: Node3D = _made.find_child(id, true, false)
		_markers.append(marker)
		var hand: Node3D = (load(LEFT_MODEL if marker.position.x < 0.0 else ARM_MODEL) as PackedScene).instantiate()
		marker.add_child(hand)
		var mesh: MeshInstance3D = hand.find_children("*", "MeshInstance3D", true, false)[0]
		mesh.set_surface_override_material(0, arm_look)
		_hand_meshes.append(mesh)
		_hands.append(hand.find_children("*", "Skeleton3D", true, false)[0])
		_souls.append(hand)
		_wrist.append(Vector3.ZERO)
		_dug.append(false)
		_dug_floor.append(0.0)
		_haul_t.append(0.0)
		_reach_t.append(0.0)
		_came_from.append(Vector3.ZERO)
		_shut.append(CURL)
		_stretch.append(1.0)
		var limb := mini(_markers.size() - 1, DIGGERS - 1)
		_step_takes.append(REACH_TAKES[limb])
		_step_lift.append(REACH_LIFT[limb])
		_step_ahead.append(DIGS_AHEAD[limb])
		_step_out.append(DIGS_OUT[limb])
		_step_wrist.append(WRIST_UP[limb])
		_step_turn.append(0.0)
		_step_hovers.append(false)

	for id in FACES:
		var marker: Node3D = _made.find_child(id, true, false)
		var skull: Node3D = AnimaSkullScript.new(bone)
		skull.scale = Vector3.ONE * SKULL_SIZE
		marker.add_child(skull)
		_skulls.append(skull)
		_souls.append(skull)
		_rest[skull] = skull.transform

	_build_presses()
	_build_bursts()


func _ready() -> void:
	arrive()


## Whole, from the first: its hands already in the earth where it stands, each at its own point in its haul.
func arrive() -> void:
	_placed = true
	_ensure_rng()
	_floor_y = global_position.y + _made_at.y

	for i in _hands.size():
		_wrist[i] = _free_wrist(i, 0.0)

		if i < DIGGERS:
			_reach_t[i] = 0.0
			var shoulder_at := _world_shoulder(i)
			_vary_step(i)
			var to := _clear_of_walls(shoulder_at, shoulder_at - global_basis.z * _step_ahead[i] * 0.5 + global_basis.x * signf(_markers[i].position.x) * _step_out[i])
			_dig_in(i, to, true)
			_haul_t[i] = HAUL_TAKES[i] * fposmod(float(i) * 0.37 + 0.11, 1.0)
			_shut[i] = DUG_SHUT

		_solve_arm(i, 0.0, Vector3.ZERO)


func _ensure_rng() -> void:
	_rng.seed = hash(global_position)


## This limb's next step: its own, and not its last.
func _vary_step(i: int) -> void:
	var by := func() -> float: return 1.0 + _rng.randf_range(-STEP_VARIES, STEP_VARIES)
	_step_takes[i] = REACH_TAKES[i] * by.call()
	_step_lift[i] = REACH_LIFT[i] * by.call()
	_step_ahead[i] = DIGS_AHEAD[i] * by.call() * _size
	_step_out[i] = DIGS_OUT[i] * by.call() * _size
	_step_wrist[i] = WRIST_UP[i] * lerpf(1.0, by.call(), 0.6) * _size
	_step_turn[i] = _rng.randf_range(-STEP_TURNS, STEP_TURNS)
	_step_hovers[i] = _rng.randf() < HOVER_CHANCE


## With it moving, the next limb in the order comes up.
func _work_gait(delta: float, speed: float) -> void:
	if speed <= 0.05:
		return

	_gait_in -= delta

	if _gait_in > 0.0:
		return

	var limb: int = GAIT[_gait_at]

	# It won't have both its front limbs off the earth: it would go on its face.
	if limb < HAULERS and not _dug[HAULERS - 1 - limb]:
		return

	if _dug[limb]:
		_let_go(limb)

	_gait_at = (_gait_at + 1) % GAIT.size()
	_gait_in = _rng.randf_range(GAIT_GAP.x, GAIT_GAP.y)


func _let_go(i: int) -> void:
	_dug[i] = false
	_reach_t[i] = 0.0
	_came_from[i] = _wrist[i]
	_vary_step(i)


## Whether that one shows, out of its skin.
func press_shown(n: int) -> bool:
	return _press_nodes[n].visible


## How many press out from under its skin, and what each is doing.
func presses_held() -> int:
	return PRESSES


func press_strength(n: int) -> float:
	return _press_strength[n]


func press_kind(n: int) -> int:
	return PRESS_KIND[n]


func press_jaw(n: int) -> float:
	return _press_jaw[n]


## Whether that one starts where its skin is.
func press_on_skin(n: int) -> bool:
	return _spot_ok(_press_spot[n])


## How much that one is turned to `at`, in the world: 1 straight at it.
func press_toward(n: int, at: Vector3) -> float:
	if _press_strength[n] < 0.3:
		return -1.0

	var mass := part(&"Mass")
	var from: Vector3 = mass.global_transform * _press_at[n]
	return (mass.global_basis * _press_way[n]).normalized().dot((at - from).normalized())


## For a picture: that one held out as hard as it goes, on the spot most toward `at`, its jaw so.
func hold_press(n: int, at: Vector3, jaw: float) -> void:
	var spots := _skin_spots()
	var mass := part(&"Mass")
	var to_at: Vector3 = (mass.global_basis.inverse() * (at - mass.global_position)).normalized()
	var best := -9.0

	for k in spots.size():
		var used := false

		for m in PRESSES:
			used = used or (m != n and _press_stage[m] == 2 and _press_spot[m] == k)

		var how_much: float = (spots[k][1] as Vector3).dot(to_at)

		if not used and how_much > best:
			best = how_much
			_press_spot[n] = k

	_press_stage[n] = 2
	_press_t[n] = 0.0
	_press_takes[n] = 9999.0
	_press_roll[n] = 0.0
	_press_slide[n] = Vector3.ZERO
	_held_jaw = jaw


## For a picture: that one gone, and staying gone.
func press_held_off(n: int) -> void:
	_press_stage[n] = 0
	_press_t[n] = 0.0
	_press_takes[n] = 9999.0


## How far one of its heads has got out of it.
func skull_out(n: int) -> float:
	return _skull_out[n]


## How far the furthest hand has got out through its skin (m), whether any is out, how torn it is.
func burst_out() -> float:
	var most := -9.0

	for b in BURSTS:
		if _burst_stage[b] != 0:
			most = maxf(most, _burst_at[b] + BURST_TIPS)

	return most


func burst_shown() -> bool:
	return _burst_nodes.any(func(node): return node.visible)


func tear_open() -> float:
	var most := 0.0

	for b in BURSTS:
		most = maxf(most, _tear[b])

	return most


func _build_presses() -> void:
	var look: ShaderMaterial = _flesh_look.duplicate()
	look.set_shader_parameter(&"burn_noise", MeshVfx.noise())
	look.set_shader_parameter(&"press_count", PRESSES + BURSTS)
	part(&"Mass").set_surface_override_material(0, look)
	_mass_look = look
	var spots := _skin_spots()
	var made: Node3D = (load(SHEATH_MODEL) as PackedScene).instantiate()
	_skin_skull = (made.find_child("SkinSkull", true, false) as MeshInstance3D).mesh
	_skin_jaw = (made.find_child("SkinJaw", true, false) as MeshInstance3D).mesh
	_skin_hand = (made.find_child("SkinHand", true, false) as MeshInstance3D).mesh
	made.free()
	_skin_look = _flesh_look.duplicate()
	_skin_look.set_shader_parameter(&"frays", 0.0)
	_light_look = ShaderMaterial.new()
	_light_look.shader = LightShader

	for n in PRESSES:
		var built: Array = _new_sheathed(PRESS_KIND[n])
		var root: Node3D = built[0]
		var jaw: Variant = built[1]
		var eyes: Array = built[2]
		_press_nodes.append(root)
		_press_jaws.append(jaw)
		_press_lights.append(eyes)
		_press_stage.append(0)
		_press_t.append(0.0)
		_press_takes.append(0.3 + float(n) * 0.55)
		_press_strength.append(0.0)
		_press_jaw.append(0.0)
		_press_spot.append(n % spots.size())
		_press_at.append(Vector3.ZERO)
		_press_way.append(Vector3.UP)
		_press_up.append(Vector3.UP)
		_press_roll.append(0.0)
		_press_slide.append(Vector3.ZERO)

	for n in 3:
		_skull_stage.append(0)
		_skull_t.append(float(n) * 1.1)
		_skull_takes.append(1.5 + float(n) * 1.3)
		_skull_out.append(0.0)


static var _spots_shared: Array = []


## Where on it they can press: spots on its skin, facing out from it, clear of its mouth and of what already
## pushes out of it. Each a position and the way out, as the mesh has them. Shared: it is one mesh.
func _skin_spots() -> Array:
	if not _spots_shared.is_empty():
		return _spots_shared

	var arrays: Array = part(&"Mass").mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var middle := Vector3(0.0, 0.55, 0.55)
	var stride := maxi(verts.size() / SPOT_TRIES, 1)
	var coarse := maxi(verts.size() / 1000, 1)

	for k in range(0, verts.size(), stride):
		var at := verts[k]
		var way := Vector3.ZERO

		# Its skin's way out, about here, not the wrinkle's.
		for m in range(0, verts.size(), coarse):
			if verts[m].distance_squared_to(at) < 0.03:
				way += normals[m]

		if way.length() < 0.01:
			continue

		way = way.normalized()
		var from_middle := (at - middle).normalized()

		if way.dot(from_middle) < 0.5 or (at.z < MOUTH_ENDS_Z and absf(at.x) < MOUTH_WIDE) or at.y < SPOT_ABOVE:
			continue

		var clear := true

		for marker in _markers:
			clear = clear and marker.position.distance_to(at) > SPOT_CLEAR

		for id in FACES:
			clear = clear and (_made.find_child(id, true, false) as Node3D).position.distance_to(at) > SPOT_CLEAR

		for other in _spots_shared:
			clear = clear and other[0].distance_to(at) > SPOT_APART

		if clear:
			_spots_shared.append([at, way])

	return _spots_shared


func _spot_ok(index: int) -> bool:
	var spots := _skin_spots()

	if index < 0 or index >= spots.size():
		return false

	var at: Vector3 = spots[index][0]
	return at.z >= MOUTH_ENDS_Z or absf(at.x) >= MOUTH_WIDE


## They strain at it from inside: up, and held, faces screaming, hands dragging at the skin; hauled back in, and
## the skin goes in after them.
func _work_presses(delta: float, grab_at: Vector3) -> void:
	var spots := _skin_spots()
	var mass := part(&"Mass")
	var to_you: Vector3 = (mass.global_basis.inverse() * (grab_at - mass.global_position)).normalized()
	var hungry := _hunger > PRESS_HUNGRY_FROM

	for n in PRESSES:
		_press_t[n] += delta
		var takes: float = _press_takes[n] * (0.08 if hungry and _press_stage[n] == 0 else 1.0)

		if _press_t[n] >= takes and not (hungry and _press_stage[n] == 2):
			_press_t[n] = 0.0
			_press_stage[n] = (_press_stage[n] + 1) % 5

			match _press_stage[n]:
				1:
					_press_takes[n] = _rng.randf_range(PRESS_RISES.x, PRESS_RISES.y)
					_press_choose(n, spots, to_you)
				2:
					_press_takes[n] = _rng.randf_range(PRESS_HOLDS.x, PRESS_HOLDS.y)
				3:
					_press_takes[n] = PRESS_HAULED
				4:
					_press_takes[n] = PRESS_RECOILS
				0:
					_press_takes[n] = _rng.randf_range(PRESS_RESTS.x, PRESS_RESTS.y)

		var u: float = clampf(_press_t[n] / maxf(takes, 0.01), 0.0, 1.0)
		var strain := sin(_clock * (9.0 + float(n) * 1.7) + float(n)) * 0.06 + sin(_clock * (23.0 + float(n) * 2.3)) * 0.03
		var strength: float

		match _press_stage[n]:
			1:
				strength = u * u * (3.0 - 2.0 * u) + strain * u
			2:
				strength = 1.0 + strain * 1.5 + _hunger * 0.15
			3:
				strength = lerpf(1.0, PRESS_DENT, u * u)
			4:
				strength = lerpf(PRESS_DENT, 0.0, u) * cos(u * PI * 3.0)
			_:
				strength = 0.0

		_press_strength[n] = strength
		_press_jaw[n] = _held_jaw if _held_jaw >= 0.0 else clampf(0.5 + sin(_clock * (2.3 + float(n) * 0.9)) * 0.7 + sin(_clock * 11.0 + float(n)) * 0.15, 0.0, 1.0) if _press_stage[n] != 0 else 0.0
		var spot: Array = spots[_press_spot[n]]
		# Dragging along under it, a hand; a face turning to find you.
		var slid: Vector3 = _press_slide[n] * (float(_press_stage[n] == 2) * clampf(_press_t[n] / 1.5, 0.0, 1.0) + float(_press_stage[n] > 2))
		_press_at[n] = spot[0] + slid
		var leans := PRESS_LEANS * (0.4 + _hunger * 0.6) if PRESS_KIND[n] == 0 else _hunger * 0.3
		_press_way[n] = (spot[1] as Vector3).lerp(to_you, leans).normalized()
		var up_was := Vector3.UP if absf(_press_way[n].y) < 0.9 else Vector3.BACK
		var up := (up_was - _press_way[n] * up_was.dot(_press_way[n])).normalized()
		_press_up[n] = up.rotated(_press_way[n], _press_roll[n])

	_work_taken()

	# The uniforms: the faces and hands, then where a real one has torn it.
	for n in PRESSES:
		_uniform_at[n] = Vector4(_press_at[n].x, _press_at[n].y, _press_at[n].z, _press_strength[n])
		_uniform_way[n] = Vector4(_press_way[n].x, _press_way[n].y, _press_way[n].z, 0.0)
		_show_press(n)
		_uniform_up[n] = Vector4(_press_up[n].x, _press_up[n].y, _press_up[n].z, _press_jaw[n])
		_uniform_size[n] = PRESS_SIZE[PRESS_KIND[n]]

	_mass_look.set_shader_parameter(&"press_at", _uniform_at)
	_mass_look.set_shader_parameter(&"press_way", _uniform_way)
	_mass_look.set_shader_parameter(&"press_up", _uniform_up)
	_mass_look.set_shader_parameter(&"press_size", _uniform_size)


## That one, out of its skin as far as it has got: a face turned on you, a hand flat under it, dragging.
func _show_press(n: int) -> void:
	var root := _press_nodes[n]
	var strength := _press_strength[n]
	root.visible = strength > 0.03

	if not root.visible:
		return

	var way := _press_way[n]
	var up := _press_up[n]
	var shake := Vector3(sin(_clock * 19.0 + float(n)), sin(_clock * 23.0 + float(n) * 2.0), 0.0) * 0.006 * strength

	if PRESS_KIND[n] == 0:
		var out := lerpf(FACE_OUT.x, FACE_OUT.y, clampf(strength, 0.0, 1.15))
		root.transform = Transform3D(Basis.looking_at(way, up).scaled(Vector3.ONE * FACE_SIZE), _press_at[n] + way * out + shake)
		_press_jaws[n].rotation.x = -_press_jaw[n] * JAW_DROPS
		# It burns behind what it is looking with: more the harder it goes at you.
		# (Only once it is up: below that they'd show through what it hasn't come out of.)
		for ember in _press_lights[n]:
			ember.visible = strength > LIGHT_SHOWS_FROM
			ember.scale = Vector3.ONE * (0.8 + _hunger * 0.35 + sin(_clock * 13.0 + float(n)) * 0.08)
	else:
		var across := way.cross(up).normalized()
		var flat := Basis(across, way, -up)
		var out := lerpf(HAND_OUT.x, HAND_OUT.y, clampf(strength, 0.0, 1.15))
		var twist := Basis(way, sin(_clock * 3.1 + float(n)) * 0.12)
		root.transform = Transform3D((twist * flat).scaled(Vector3.ONE * HAND_SIZE), _press_at[n] + way * out - up * 0.26 * HAND_SIZE + shake)


## A new place for it, and a new way up: they are not all the way up, and one in so many is upside down.
func _press_choose(n: int, spots: Array, to_you: Vector3) -> void:
	var index: int = _rng.randi() % spots.size()
	var best := -9.0

	# Of a few, the one most toward you: it is you they are trying to get to.
	for t in PRESS_PICKS:
		var maybe: int = _rng.randi() % spots.size()
		var free := true

		for m in PRESSES:
			free = free and (m == n or _press_stage[m] == 0 or _press_spot[m] != maybe)

		var how_much: float = (spots[maybe][1] as Vector3).dot(to_you)

		if free and how_much > best:
			best = how_much
			index = maybe

	_press_spot[n] = index
	_press_roll[n] = PI if _rng.randf() < PRESS_UPSIDE_DOWN else _rng.randf_range(-0.7, 0.7)
	var way: Vector3 = spots[index][1]
	var across := way.cross(Vector3.UP)
	_press_slide[n] = (across.normalized() if across.length() > 0.01 else Vector3.RIGHT) * _rng.randf_range(-0.2, 0.2) if PRESS_KIND[n] == 1 else Vector3.ZERO


## One of them with its skin drawn over it, not yet anywhere: a face (0), with its jaw and its lights, or a hand (1).
## [its root, its jaw or null, its lights].
func _new_sheathed(kind: int) -> Array:
	var root := Node3D.new()
	root.visible = false
	_made.add_child(root)
	var skinned := MeshInstance3D.new()
	skinned.mesh = _skin_hand if kind == 1 else _skin_skull
	skinned.material_override = _skin_look
	skinned.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(skinned)
	var jaw: MeshInstance3D = null
	var eyes: Array[MeshInstance3D] = []

	if kind == 0:
		jaw = MeshInstance3D.new()
		jaw.mesh = _skin_jaw
		jaw.material_override = _skin_look
		jaw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		jaw.position = FACE_HINGE
		root.add_child(jaw)

		for bit in [FACE_EYE * Vector3(-1.0, 1.0, 1.0), FACE_EYE, FACE_THROAT]:
			var ember := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radial_segments = 12
			ball.rings = 8
			ball.radius = 0.018 if bit != FACE_THROAT else 0.02
			ball.height = ball.radius * 2.0
			ember.mesh = ball
			ember.material_override = _light_look
			ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ember.position = bit
			root.add_child(ember)
			eyes.append(ember)

	return [root, jaw, eyes]


## Its arm out at what it is taking, wherever that is now.
func seize_at(at: Vector3) -> void:
	_seizing = true
	_seized_at = at


func seize_off() -> void:
	_seizing = false


## The elite: bigger, its candles alight.
func be_elite(size: float, flame: Mesh, look: Material) -> void:
	_size = size
	_elite = true
	_mass_look.set_shader_parameter(&"press_count", PRESSES + BURSTS + MOST_TAKEN)
	var candles := part(&"Candles")
	var points: PackedVector3Array = candles.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var sorted: Array = Array(points)
	sorted.sort_custom(func(a, b): return a.y > b.y)
	var picked: Array[Vector3] = []

	# Each candle's top: the highest of it, clear of the tops found.
	for at: Vector3 in sorted:
		if picked.size() >= CANDLE_FLAMES:
			break

		if picked.all(func(other): return Vector2(other.x - at.x, other.z - at.z).length() > 0.09):
			picked.append(at)
			var lit := MeshInstance3D.new()
			lit.mesh = flame
			lit.material_override = look
			lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lit.position = at
			candles.add_child(lit)
			_candle_flames.append(lit)


func candles_lit() -> bool:
	return not _candle_flames.is_empty() and _candle_flames[0].is_visible_in_tree()


## It has taken one in: it is this big now, and that one is there to see, up out of its flesh, and stays.
func has_taken(kind: StringName, size: float) -> void:
	_size = size
	var which: int = 0 if kind == &"face" else 1
	var built: Array = _new_sheathed(which)
	var spots := _skin_spots()
	var best := -1
	var best_how := -9.0

	# The one most toward its front that is free.
	for k in spots.size():
		var way: Vector3 = spots[k][1]
		var how_much: float = -way.z + way.y * 0.4 + _rng.randf_range(-0.25, 0.25)

		if not _taken_spots.has(k) and how_much > best_how:
			best_how = how_much
			best = k

	_taken_spots.append(best)
	_taken.append({"kind": kind, "which": which, "root": built[0], "jaw": built[1], "lights": built[2], "spot": spots[best], "roll": _rng.randf_range(-0.6, 0.6)})


func taken_shown(kind: StringName) -> int:
	return _taken.filter(func(one): return one["kind"] == kind).size()


func taken_up() -> int:
	return _taken.filter(func(one): return one["root"].visible).size()


## What it has taken, straining still, for good.
func _work_taken() -> void:
	for n in _taken.size():
		var one: Dictionary = _taken[n]
		var at: Vector3 = one["spot"][0]
		var way: Vector3 = one["spot"][1]
		var up_was := Vector3.UP if absf(way.y) < 0.9 else Vector3.BACK
		var up: Vector3 = (up_was - way * up_was.dot(way)).normalized().rotated(way, one["roll"])
		var root: Node3D = one["root"]
		root.visible = true
		var strain := sin(_clock * (17.0 + float(n) * 3.0)) * 0.006

		if one["which"] == 0:
			root.transform = Transform3D(Basis.looking_at(way, up).scaled(Vector3.ONE * FACE_SIZE), at + way * (TAKEN_FACE_OUT + strain))
			one["jaw"].rotation.x = -clampf(0.55 + sin(_clock * (2.0 + float(n))) * 0.35, 0.0, 1.0) * JAW_DROPS
		else:
			var across := way.cross(up).normalized()
			root.transform = Transform3D((Basis(way, sin(_clock * 2.3 + float(n)) * 0.1) * Basis(across, way, -up)).scaled(Vector3.ONE * HAND_SIZE), at + way * (TAKEN_HAND_OUT + strain) - up * 0.26 * HAND_SIZE)

		var slot := PRESSES + BURSTS + n
		_uniform_at[slot] = Vector4(at.x, at.y, at.z, 0.85)
		_uniform_way[slot] = Vector4(way.x, way.y, way.z, 0.0)
		_uniform_up[slot] = Vector4(up.x, up.y, up.z, 0.0)
		_uniform_size[slot] = PRESS_SIZE[one["which"]]


func _build_bursts() -> void:
	var left := false

	for b in BURSTS:
		var hand: Node3D = (load(LEFT_BARE if left else RIGHT_BARE) as PackedScene).instantiate()
		left = not left
		hand.visible = false
		_made.add_child(hand)
		var mesh: MeshInstance3D = hand.find_children("*", "MeshInstance3D", true, false)[0]
		mesh.set_surface_override_material(0, _flesh_look)
		_burst_nodes.append(hand)
		_burst_skeletons.append(hand.find_children("*", "Skeleton3D", true, false)[0])
		_burst_stage.append(0)
		_burst_t.append(0.0)
		_burst_takes.append(BURST_FIRST + float(b) * 3.5)
		_burst_at.append(BURST_HIDDEN)
		_burst_spot.append(0)
		_tear.append(0.0)


## Now and then one of them gets an arm out, a real one, through its skin: tears it, claws at it, and is hauled back.
func _work_bursts(delta: float) -> void:
	var spots := _skin_spots()

	for b in BURSTS:
		_burst_t[b] += delta
		var hungry_by := 1.0 - _hunger * 0.6

		if _burst_t[b] >= _burst_takes[b] * (hungry_by if _burst_stage[b] == 0 else 1.0):
			_burst_t[b] = 0.0
			_burst_stage[b] = (_burst_stage[b] + 1) % 5

			match _burst_stage[b]:
				1:
					_burst_takes[b] = BURST_SWELLS
					_burst_spot[b] = _rng.randi() % spots.size()
				2:
					_burst_takes[b] = BURST_COMES
				3:
					_burst_takes[b] = _rng.randf_range(BURST_CLAWS.x, BURST_CLAWS.y)
					var spot_way: Vector3 = spots[_burst_spot[b]][1]
					Fx.blood(self, _burst_nodes[b].global_transform * Vector3.ZERO, _made.global_basis * spot_way, 0.3)
				4:
					_burst_takes[b] = BURST_HAULED
				0:
					_burst_takes[b] = _rng.randf_range(BURST_RESTS.x, BURST_RESTS.y)

		var u: float = clampf(_burst_t[b] / maxf(_burst_takes[b], 0.01), 0.0, 1.0)
		var spot: Array = spots[_burst_spot[b]]
		var hand := _burst_nodes[b]
		var shake := sin(_clock * 37.0 + float(b)) * 0.012
		var tear_to := 0.0
		var swell_to := 0.0

		match _burst_stage[b]:
			1:
				_burst_at[b] = BURST_HIDDEN
				swell_to = u
			2:
				_burst_at[b] = lerpf(BURST_HIDDEN, BURST_OUT, 1.0 - pow(1.0 - u, 3.0))
				swell_to = 1.0
				tear_to = 1.0
			3:
				_burst_at[b] = BURST_OUT + shake + sin(_clock * 2.9 + float(b)) * 0.05
				swell_to = 0.7
				tear_to = 1.0
			4:
				_burst_at[b] = lerpf(BURST_OUT, BURST_HIDDEN, u * u)
				swell_to = lerpf(0.7, PRESS_DENT, u)
				tear_to = 0.8
			_:
				_burst_at[b] = BURST_HIDDEN

		_tear[b] = move_toward(_tear[b], tear_to, delta * (9.0 if tear_to > _tear[b] else 0.7))
		hand.visible = _burst_stage[b] >= 2
		var way: Vector3 = spot[1]

		if hand.visible:
			# It has hold of what it came out of: bent back over it, clawing, the fingers opening and shutting.
			var bend := Basis(Vector3.RIGHT, -1.0 * smoothstep(0.0, 0.5, u) * float(_burst_stage[b] == 3) + sin(_clock * 8.0 + float(b)) * 0.14)
			var up := Vector3.UP if absf(way.y) < 0.9 else Vector3.BACK
			hand.transform = Transform3D(Basis.looking_at(way, up) * bend, (spot[0] as Vector3) + way * _burst_at[b])
			_claw_at(_burst_skeletons[b], b)

		var index := PRESSES + b
		_uniform_at[index] = Vector4(spot[0].x, spot[0].y, spot[0].z, swell_to)
		_uniform_way[index] = Vector4(way.x, way.y, way.z, 2.0)
		var up_was := Vector3.UP if absf(way.y) < 0.9 else Vector3.BACK
		var flat_up := (up_was - way * up_was.dot(way)).normalized()
		_uniform_up[index] = Vector4(flat_up.x, flat_up.y, flat_up.z, _tear[b])
		_uniform_size[index] = PRESS_SIZE[2]

	# Its heads go at it too.
	for n in _skulls.size():
		_skull_t[n] += delta

		if _skull_t[n] >= _skull_takes[n]:
			_skull_t[n] = 0.0
			_skull_stage[n] = (_skull_stage[n] + 1) % 4
			_skull_takes[n] = [_rng.randf_range(1.0, 4.0), _rng.randf_range(0.5, 1.0), _rng.randf_range(0.4, 1.1), SKULL_HAULED][_skull_stage[n]]

		var u: float = clampf(_skull_t[n] / maxf(_skull_takes[n], 0.01), 0.0, 1.0)
		_skull_out[n] = [SKULL_IN, lerpf(SKULL_IN, SKULL_OUT, u * u * (3.0 - 2.0 * u)), SKULL_OUT + sin(_clock * 31.0 + float(n)) * 0.012, lerpf(SKULL_OUT, SKULL_IN, u * u)][_skull_stage[n]]


func _claw_at(hand: Skeleton3D, which: int) -> void:
	for f in FINGER_NAMES.size():
		var seed := float(f) * 1.9 + float(which) * 4.1
		var shut := 0.55 + sin(_clock * (6.0 + float(f)) + seed) * 0.5

		for k in range(1, 4):
			var bone := hand.find_bone("%s_%02d" % [FINGER_NAMES[f], k])
			var rest: Basis = hand.get_bone_rest(bone).basis
			hand.set_bone_pose_rotation(bone, (rest * Basis(Vector3.RIGHT, -shut * [0.7, 1.0, 1.25][k - 1])).get_rotation_quaternion())


## Dying: everything of it that burns, and how late; with all of those in it brought up under its skin, ready.
func start_dying(seed_of: int) -> Array:
	_dying = true
	_rng.seed = seed_of
	_placed = true
	var spots := _skin_spots()
	var to_you := Vector3.FORWARD
	_still_in.clear()

	for n in PRESSES:
		if _press_stage[n] == 0 or _press_strength[n] < 0.05:
			_press_choose(n, spots, to_you)

		_press_stage[n] = 2
		_still_in.append(n)

	# Then the real ones it has: its heads, and the hands that were on their way out.
	for n in _skulls.size():
		_still_in.append(PRESSES + n)

	# Not in order.
	for k in range(_still_in.size() - 1, 0, -1):
		var other: int = _rng.randi() % (k + 1)
		var was: int = _still_in[k]
		_still_in[k] = _still_in[other]
		_still_in[other] = was

	var meshes: Array = []

	for id in MESHES:
		meshes.append([part(id), 0.5 if id == &"RibsLeft" or id == &"RibsRight" else 0.0])

	for mesh in _hand_meshes:
		meshes.append([mesh, 0.15])

	for n in PRESSES:
		for piece in _press_nodes[n].find_children("*", "MeshInstance3D", false, false):
			if not _press_lights[n].has(piece):
				meshes.append([piece, _rng.randf_range(0.0, 0.4)])

	for skull in _skulls:
		for piece in skull.find_children("*", "MeshInstance3D", true, false):
			meshes.append([piece, 0.3])

	for b in BURSTS:
		_burst_nodes[b].visible = false

	return meshes


## Where its flames stand as it burns: on its skin, on each arm, and on each of those that gets out of it.
func flame_spots(finger_flame: float) -> Array:
	var spots: Array = []
	var skin := _skin_spots()
	var mass := part(&"Mass")

	for k in range(0, skin.size(), maxi(skin.size() / 14, 1)):
		spots.append([mass, skin[k][0], FLAME_ON_IT])

	for hand in _hands:
		for name_of in FINGER_NAMES:
			spots.append([hand, "%s_02" % name_of, 0.0, finger_flame])

		spots.append([hand, "arm_1", 0.2, FLAME_ON_THEM])

	for n in PRESSES:
		spots.append([_press_nodes[n], Vector3.ZERO, FLAME_ON_THEM])

	for skull in _skulls:
		spots.append([skull, Vector3.ZERO, FLAME_ON_THEM])

	return spots


## One of them tears free and goes its own way: `which`, a pressed one, then its heads.
func _tear_free(which: int, floor_y: float) -> void:
	var node: Node3D
	var way: Vector3

	if which < PRESSES:
		node = _press_nodes[which]
		node.visible = true
		way = part(&"Mass").global_basis * _press_way[which]
		_press_strength[which] = 0.0
		_tear_at.append(which)
	else:
		node = _skulls[which - PRESSES]
		way = -node.global_basis.z

	_fling(node, way, _rng.randf_range(FREED_SPEED.x, FREED_SPEED.y), _rng.randf_range(FREED_UP.x, FREED_UP.y), FREED_LIES, false)
	Fx.blood(self, node.global_position, way, 0.25)
	Fx.dust(self, Vector3(node.global_position.x, floor_y, node.global_position.z), Vector3.UP, 0.25, "dirt")


func _fling(node: Node3D, way: Vector3, speed: float, up: float, lies: float, is_ribs: bool) -> void:
	var where := node.global_transform
	node.top_level = true
	node.global_transform = where
	way.y = 0.0
	var flat := way.normalized() if way.length() > 0.01 else global_basis.x
	# Each its own way: nudged off what it would have done.
	flat = flat.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	# How it comes to lie: a face up at nothing, as they do, so you see what it was; ribs as they fall.
	var size: Vector3 = where.basis.get_scale()
	var lands := Basis.looking_at((Vector3.UP + flat * 0.35).normalized(), flat).scaled(size)
	_freed.append({"node": node, "velocity": flat * speed + Vector3.UP * up, "spin": Vector3(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-3.0, 3.0), _rng.randf_range(-5.0, 5.0)), "lies": lies, "ribs": is_ribs, "rest": false, "lands": lands})


## All that has got out: thrown, falling, coming to rest on the floor, where it burns on.
func _work_freed(delta: float, floor_y: float) -> void:
	for item in _freed:
		if item["rest"]:
			continue

		var node: Node3D = item["node"]

		if not is_instance_valid(node):
			continue

		var velocity: Vector3 = item["velocity"]
		velocity.y -= 9.0 * delta
		var at := node.global_position
		var next := at + velocity * delta
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.05, next + Vector3.UP * 0.05, FLOOR_MASK))

		if not hit.is_empty() and absf(float(hit["normal"].y)) < 0.5:
			velocity = velocity.bounce(hit["normal"]) * FREED_BOUNCE
			next = at

		if next.y <= floor_y + float(item["lies"]):
			next.y = floor_y + float(item["lies"])
			var hard := -velocity.y
			velocity = Vector3(velocity.x * 0.5, hard * FREED_BOUNCE, velocity.z * 0.5)
			item["spin"] = item["spin"] * 0.45

			if hard < 1.0:
				item["rest"] = true

		var spin: Vector3 = item["spin"]
		var turned := node.global_basis

		if spin.length() > 0.01:
			turned = Basis(spin.normalized(), spin.length() * delta) * turned

		# Coming down, it comes round to how it will lie.
		if not item["ribs"] and next.y < floor_y + float(item["lies"]) + 0.7:
			var scale_was: Vector3 = turned.get_scale()
			var lands: Basis = item["lands"]
			turned = turned.orthonormalized().slerp(lands.orthonormalized(), 1.0 - exp(-7.0 * delta)).scaled(scale_was)

		node.global_transform = Transform3D(turned, next)
		item["velocity"] = velocity


## Dying. As `tick`, told by the beats.
func tick_dying(delta: float, speed: float, going: Vector3, digs: bool, grab: float, grab_at: Vector3, swell: float, slump: float, pose: Dictionary, floor_y: float, flare: float) -> void:
	_clock += delta
	_swell = swell
	_floor_y = floor_y
	var limp: bool = pose.get("limp", false)
	_made.scale = Vector3(1.0 + SWELLS.x * swell + SLUMP_OUT * slump, 1.0 + SWELLS.y * swell - SLUMP_DOWN * slump, 1.0 + SWELLS.z * swell + SLUMP_OUT * slump * 0.5) * SIZE * _size
	_made.position = _made_at + Vector3(0.0, 0.0, -SWELLS_ON * swell)
	_hunger = lerpf(_hunger, 0.0 if limp else 1.0, 1.0 - exp(-3.0 * delta))
	_work_gait(delta, speed)

	# Its ribs go.
	if pose.has("bursts") and not _ribs_gone:
		_ribs_gone = true
		var hard: float = float(pose["bursts"])
		_ribs_from = [part(&"RibsLeft").global_position, part(&"RibsRight").global_position]
		_fling(part(&"RibsLeft"), -global_basis.x - global_basis.z * 0.6, hard, hard * 0.75, RIBS_LIE, true)
		_fling(part(&"RibsRight"), global_basis.x - global_basis.z * 0.6, hard, hard * 0.75, RIBS_LIE, true)

	# And those in it.
	if pose.has("frees"):
		_frees_in -= delta

		while _frees_in <= 0.0 and not _still_in.is_empty():
			_tear_free(_still_in.pop_back(), floor_y)
			_frees_in += float(pose["frees"])

			if float(pose["frees"]) <= 0.0:
				_frees_in = 0.0

	_work_freed(delta, floor_y)
	var heaved := 0.0

	for i in _hands.size():
		var on_earth: bool = digs and i < DIGGERS and not limp
		var shut_to: float

		if on_earth:
			shut_to = _dig(i, delta, speed, going)
			heaved = maxf(heaved, _hauling(i) if i < HAULERS else 0.0)
		else:
			_dug[i] = false
			_reach_t[i] = 0.0
			_came_from[i] = _wrist[i]
			var wanted: Vector3

			if limp:
				# Nothing in them: they drop, and lie where they drop.
				wanted = Vector3(_wrist[i].x, floor_y + LIMP_WRIST_UP, _wrist[i].z)
			else:
				wanted = _within_reach(i, _free_wrist(i, grab).lerp(_grab_point(i, grab_at), grab))

			_wrist[i] = _wrist[i].lerp(wanted, 1.0 - exp(-lerpf(FREE_RATE, GRAB_RATE, grab) * delta * (0.7 if limp else 1.0)))
			shut_to = 0.25 if limp else lerpf(CURL, -0.1, grab)

		_shut[i] = lerpf(_shut[i], shut_to, 1.0 - exp(-8.0 * delta))
		_solve_arm(i, grab, grab_at)
		_curl_fingers(_hands[i], i)
		_hand_meshes[i].set_instance_shader_parameter(&"hunger", _hunger)

	_heave = heaved * HEAVES
	_work_dying_presses(delta, pose)

	# Their lights last as long as there is anything of them.
	for lights in _press_lights:
		for ember in lights:
			ember.visible = not limp or flare > 0.3

	for i in _skulls.size():
		if _still_in.has(PRESSES + i):
			var rest: Transform3D = _rest[_skulls[i]]
			_skull_out[i] = lerpf(_skull_out[i], SKULL_OUT, 1.0 - exp(-4.0 * delta))
			_skulls[i].transform = Transform3D(rest.basis, rest.origin + Vector3(0.0, 0.0, -_skull_out[i]))

		_skulls[i].open_to(1.0 if not limp else 0.6, 0.3)

	for id in [&"Mass", &"RibsLeft", &"RibsRight", &"Bones"]:
		part(id).set_instance_shader_parameter(&"hunger", _hunger)

	part(&"Mass").set_instance_shader_parameter(&"swell", maxf(swell, 0.0))
	part(&"Gullet").set_instance_shader_parameter(&"hunger", _hunger)


## All of them at it, under its skin, until each gets out; and where each got out it is torn.
func _work_dying_presses(delta: float, pose: Dictionary) -> void:
	var strains: bool = pose.has("strain")

	for n in PRESSES:
		if _still_in.has(n):
			_press_strength[n] = move_toward(_press_strength[n], 1.0 if strains else 0.5, delta * 3.0) + sin(_clock * (21.0 + float(n) * 3.0)) * 0.03
			_press_jaw[n] = clampf(0.65 + sin(_clock * (7.0 + float(n))) * 0.35, 0.0, 1.0)
			_uniform_at[n] = Vector4(_press_at[n].x, _press_at[n].y, _press_at[n].z, _press_strength[n])
			_uniform_way[n] = Vector4(_press_way[n].x, _press_way[n].y, _press_way[n].z, 0.0)
			_uniform_up[n] = Vector4(_press_up[n].x, _press_up[n].y, _press_up[n].z, 0.0)
			_uniform_size[n] = PRESS_SIZE[PRESS_KIND[n]]
			_show_press(n)
		elif _tear_at.has(n):
			_uniform_at[n] = Vector4(_press_at[n].x, _press_at[n].y, _press_at[n].z, 0.8)
			_uniform_way[n] = Vector4(_press_way[n].x, _press_way[n].y, _press_way[n].z, 2.0)
			_uniform_up[n] = Vector4(_press_up[n].x, _press_up[n].y, _press_up[n].z, 1.0)
			_uniform_size[n] = PRESS_SIZE[2] * 1.4

	for b in BURSTS:
		_uniform_at[PRESSES + b].w = 0.0

	_mass_look.set_shader_parameter(&"press_at", _uniform_at)
	_mass_look.set_shader_parameter(&"press_way", _uniform_way)
	_mass_look.set_shader_parameter(&"press_up", _uniform_up)
	_mass_look.set_shader_parameter(&"press_size", _uniform_size)


## How far its ribs have gone from where they were, the less of the two.
func ribs_flung() -> float:
	if _ribs_from.is_empty():
		return 0.0

	return minf(part(&"RibsLeft").global_position.distance_to(_ribs_from[0]), part(&"RibsRight").global_position.distance_to(_ribs_from[1]))


## How many have got well clear of it.
func souls_apart() -> int:
	var clear := 0

	for item in _freed:
		if not item["ribs"] and is_instance_valid(item["node"]) and (item["node"] as Node3D).global_position.distance_to(global_position) > 0.5:
			clear += 1

	return clear


## How far apart those that got out have gone: the most between any two.
func souls_spread() -> float:
	var most := 0.0

	for a in _freed:
		for b in _freed:
			if not a["ribs"] and not b["ribs"] and is_instance_valid(a["node"]) and is_instance_valid(b["node"]):
				most = maxf(most, (a["node"] as Node3D).global_position.distance_to((b["node"] as Node3D).global_position))

	return most


## How many places it is torn open where they got out.
func tears_open() -> int:
	return _tear_at.size()


## How hungry it is showing, 0..1.
func hunger() -> float:
	return _hunger


func part(id: StringName) -> MeshInstance3D:
	return _parts.get(id)


func souls() -> Array[Node3D]:
	return _souls


## Where one of what pushes out of it is now: an arm by its wrist, a head by how it hangs.
func soul_at(index: int) -> Transform3D:
	return Transform3D(Basis.IDENTITY, _wrist[index]) if index < _hands.size() else _souls[index].transform


## How far the ribs stand open, 0..1.
func ribs_open() -> float:
	return _ribs_open


func ribs_to(open: float) -> void:
	_ribs_open = open
	# (RibsLeft lies at -x: it opens the way y turns, seen from above; RibsRight the other.)
	part(&"RibsLeft").rotation.y = RIBS_SWING * open
	part(&"RibsRight").rotation.y = -RIBS_SWING * open


## Where each hauling arm is in its going, -1..1.
func arm_stride(which: int) -> float:
	var round_takes: float = HAUL_TAKES[which] + _step_takes[which]
	var into: float = minf(_haul_t[which], HAUL_TAKES[which]) if _dug[which] else HAUL_TAKES[which] + _reach_t[which] * _step_takes[which]
	return sin(into / round_takes * TAU)


## Whether this arm's hand has dug in.
func arm_dug_in(which: int) -> bool:
	return _dug[which]


## The ground that hand last dug into.
func dug_floor(which: int) -> float:
	return _dug_floor[which]


## That arm's wrist, in the world.
func wrist(which: int) -> Vector3:
	return _wrist[which]


## How low the tip of that hand's longest finger is, in the world.
func fingertip_y(which: int) -> float:
	var hand := _hands[which]
	var last: Transform3D = hand.get_bone_global_pose(hand.find_bone("middle_03"))
	var tip: Vector3 = last * (Vector3.UP * hand.get_bone_rest(hand.find_bone("middle_03")).origin.length())
	return (hand.global_transform * tip).y


## How far that arm is drawn out past its length, 1 at its length.
func arm_stretch(which: int) -> float:
	return _stretch[which]


## How far the end of that arm is from its shoulder (m): it should come to it.
func arm_end_gap(which: int) -> float:
	var hand := _hands[which]
	var last: Transform3D = hand.get_bone_global_pose(hand.find_bone("arm_2"))
	return (last * (Vector3.UP * BONE_LENGTH)).distance_to(_shoulder())


## How many heaps of earth it has left, there now.
func earth_shown() -> int:
	return _earths.filter(func(earth): return earth.visible).size()


## How many hauls have landed: a hand has dug in, and will drag all of it on.
func hauls_done() -> int:
	return _hauls


## How high the mass has heaved with them (m).
func heave() -> float:
	return _heave


## How far over it the mass has rolled with them (rad).
func roll() -> float:
	return (_hauling(0) - _hauling(1)) * ROLLS + _leaning


## How far over onto its front the mass has rocked (rad): it pitches into each haul.
func rock() -> float:
	return (maxf(_hauling(0), _hauling(1)) - 0.5) * ROCKS * 2.0


## How it goes for now, of its speed: lurching on with each haul, and all but stopping between.
func lurch() -> float:
	var pulling := maxf(_hauling(0), _hauling(1)) + (_hauling(2) + _hauling(3)) * BRACES_ADD
	return LURCH_LEAST + minf(pulling * pulling, 1.0) * LURCH_MOST


## How far it is into its haul with that arm: nothing as it digs in, the most midway, nothing as it lets go.
func _hauling(which: int) -> float:
	return sin(clampf(_haul_t[which] / HAUL_TAKES[which], 0.0, 1.0) * PI) if _dug[which] else 0.0


## How many arms are coming over in a rake.
func arms_raking() -> int:
	var count := 0

	for value in _rake:
		count += 1 if value > RAKING_PAST else 0

	return count


## How swollen it is, 0..1 and a little past as it overshoots.
func swollen() -> float:
	return _swell


## How big it stands, as built, each way.
func size_now() -> Vector3:
	return _made.scale


## Each tick: what pushes out of it goes on moving, each in its own time. `speed`, `going`: how fast it is being
## dragged and where. `rake_to`: -1 drawn back, 0 at rest, 1 come over. `digs`: whether its hands are on
## the earth. `grab`: how far every arm it has is going for `grab_at`. `swell`, how swollen. `fed` shows on all of it.
func tick(delta: float, speed: float, going: Vector3, rake_to: float, digs: bool, grab: float, grab_at: Vector3, swell: float, fed: float, hurt: float, smoulder: float) -> void:
	_clock += delta
	_swell = swell
	_made.scale = (Vector3.ONE + SWELLS * swell) * SIZE * _size
	_made.position = _made_at + Vector3(0.0, 0.0, -SWELLS_ON * swell)

	if not _placed:
		arrive()

	# Gathering at you, swollen, feeding: it blazes.
	_hunger = move_toward(_hunger, clampf(HUNGER_LOW + swell * 1.1 + fed * 0.25, 0.0, 1.0), delta * HUNGER_RATE)
	_work_presses(delta, grab_at)
	_work_bursts(delta)
	_work_gait(delta, speed)

	for i in _rake.size():
		var w := minf(TAU * RAKE_RATE, 0.8 / delta)
		var late := clampf(float(i) * RAKE_LAGS, 0.0, 0.2)
		_rake_speed[i] += (w * w * (rake_to - _rake[i]) - 2.0 * 0.75 * w * _rake_speed[i]) * delta * (1.0 - late)
		_rake[i] += _rake_speed[i] * delta

	var heaved := 0.0

	for i in _hands.size():
		# The two that haul stay on the earth to the last; the rest come up for a rake.
		var on_earth: bool = digs and i < DIGGERS and (i < HAULERS or absf(rake_to) < 0.01) and not (i == SEIZING_ARM and _seizing)
		var shut_to: float

		if i == SEIZING_ARM and _seizing:
			# Out past where an arm goes, shut on it.
			_dug[i] = false
			_wrist[i] = _wrist[i].lerp(_seized_at, 1.0 - exp(-SEIZE_RATE * delta))
			shut_to = DUG_SHUT
		elif on_earth:
			shut_to = _dig(i, delta, speed, going)
		else:
			_dug[i] = false
			_reach_t[i] = 0.0
			_came_from[i] = _wrist[i]
			var wanted := _within_reach(i, _free_wrist(i, grab).lerp(_grab_point(i, grab_at), grab))
			_wrist[i] = _wrist[i].lerp(wanted, 1.0 - exp(-lerpf(FREE_RATE, GRAB_RATE, grab) * delta))
			shut_to = lerpf(CURL, -0.1, grab)

		_shut[i] = lerpf(_shut[i], shut_to, 1.0 - exp(-14.0 * delta))
		_solve_arm(i, grab, grab_at)
		_curl_fingers(_hands[i], i)
		_hand_meshes[i].set_instance_shader_parameter(&"fed", fed)
		_hand_meshes[i].set_instance_shader_parameter(&"hurt", hurt)
		_hand_meshes[i].set_instance_shader_parameter(&"smoulder", smoulder)

		if i < HAULERS:
			heaved = maxf(heaved, _hauling(i))

	_heave = heaved * HEAVES
	# Off whichever is up.
	var leans_to := 0.0

	for i in DIGGERS:
		if not _dug[i] and digs:
			leans_to -= signf(_markers[i].position.x) * sin(_reach_t[i] * PI) * LEANS_OFF

	_leaning = lerpf(_leaning, leans_to, 1.0 - exp(-4.0 * delta))
	_settle_earth(delta)

	for i in _skulls.size():
		var seed := float(i) * 3.1
		var skull := _skulls[i]
		var rest: Transform3D = _rest[skull]
		var sway := Basis.from_euler(Vector3(sin(_clock * (0.9 + float(i) * 0.13) + seed), sin(_clock * (0.7 + float(i) * 0.09) + seed * 1.7), 0.0) * HEAD_SWAY)
		skull.transform = Transform3D(sway * rest.basis, rest.origin + Vector3(0.0, 0.0, -_skull_out[i]))
		# (Stretched with the rest of it, or trying to get out of it, they gape.)
		skull.open_to(clampf(JAW_REST + sin(_clock * (2.1 + float(i) * 0.7) + seed) * JAW_WORKS + swell * 0.5 + maxf(_skull_out[i], 0.0) * 5.0, 0.0, 1.0), 0.3)
		skull.paint(fed, hurt, smoulder)

	for id in MESHES:
		var mesh: MeshInstance3D = part(id)
		mesh.set_instance_shader_parameter(&"fed", fed)
		mesh.set_instance_shader_parameter(&"hurt", hurt)
		mesh.set_instance_shader_parameter(&"smoulder", smoulder)

	part(&"Mass").set_instance_shader_parameter(&"swell", maxf(swell, 0.0))

	for id in [&"Mass", &"RibsLeft", &"RibsRight", &"Bones"]:
		part(id).set_instance_shader_parameter(&"hunger", _hunger)

	for mesh in _hand_meshes:
		mesh.set_instance_shader_parameter(&"hunger", _hunger)


## One arm on the earth: dug in and hauling, or up and on its way to dig in again. How shut its fingers should be.
func _dig(i: int, delta: float, speed: float, going: Vector3) -> float:
	var shoulder_at := _world_shoulder(i)

	if _dug[i]:
		# Standing still, it holds on. It lets go when the gait says, or when it is left behind.
		if speed > 0.05:
			_haul_t[i] += delta

		if (_wrist[i] - shoulder_at).length() > TRAILS_MOST * _size:
			_let_go(i)

		return DUG_SHUT + sin(_clock * 3.0 + float(i)) * 0.03

	var u0 := _reach_t[i]
	var slow := HOVER_SLOWS if _step_hovers[i] and u0 > STEP_OVER and u0 < STEP_HOVER_ENDS else 1.0
	_reach_t[i] = minf(u0 + delta / _step_takes[i] * slow, 1.0)
	var u := _reach_t[i]
	var heading := Vector3(going.x, 0.0, going.z)
	var ahead: Vector3 = heading.normalized() if heading.length() > 0.08 else -global_basis.z
	var out: Vector3 = global_basis.x * signf(_markers[i].position.x)
	var to: Vector3 = _clear_of_walls(shoulder_at, shoulder_at + ahead * _step_ahead[i] + out * _step_out[i])
	to.y = _floor_y + _step_wrist[i]
	# Out of the earth and over, the most of the way; then the last of it, down, hard.
	var across := smoothstep(0.08, STEP_OVER, u) * 0.93 + smoothstep(STEP_HOVER_ENDS, 1.0, u) * 0.07
	var over := sin(minf(u / STEP_OVER, 1.0) * PI * 0.5 + maxf(0.0, u - 0.34) / 0.34 * PI * 0.25)
	var high := lerpf(_step_lift[i] * clampf(over, 0.0, 1.0), HOVER_HIGH * (1.0 - smoothstep(STEP_HOVER_ENDS, 1.0, u)), smoothstep(STEP_OVER * 0.75, STEP_OVER, u))
	_wrist[i] = _came_from[i].lerp(to, across) + Vector3.UP * high

	if u >= 1.0:
		_dig_in(i, to)

	# Limp coming up, spread feeling for the ground, and it shuts as it goes in.
	return lerpf(lerpf(0.95, -0.15, smoothstep(0.1, STEP_OVER, u)), DUG_SHUT, smoothstep(STEP_HOVER_ENDS, 1.0, u))


## Whether that limb is up there feeling for the ground.
func arm_hovering(which: int) -> bool:
	return not _dug[which] and which < DIGGERS and _reach_t[which] > STEP_OVER and _reach_t[which] < STEP_HOVER_ENDS


## How far this limb means to go, ahead and out.
func arm_reach_of(which: int) -> float:
	return (DIGS_AHEAD[which] * DIGS_AHEAD[which] + DIGS_OUT[which] * DIGS_OUT[which]) ** 0.5


## Where it means to dig, kept on its own side of what is in the way.
func _clear_of_walls(from: Vector3, to: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(from, to, FLOOR_MASK)
	var hit := space.intersect_ray(ray)

	if hit.is_empty():
		return to

	var way := (to - from).normalized()
	return from + way * maxf(from.distance_to(hit["position"]) - 0.3, 0.0)


## It comes down: fingers into the earth, and what that throws up.
func _dig_in(i: int, to: Vector3, quietly := false) -> void:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(to + Vector3.UP * 0.7, to + Vector3.DOWN * 1.6, FLOOR_MASK)
	var hit := space.intersect_ray(ray)

	if not hit.is_empty():
		_floor_y = float(hit["position"].y)

	var at := Vector3(to.x, _floor_y + _step_wrist[i], to.z)
	_wrist[i] = at
	_dug[i] = true
	_dug_floor[i] = _floor_y
	_haul_t[i] = 0.0

	if quietly:
		return

	_hauls += 1
	var on_floor := Vector3(at.x, _floor_y, at.z)
	var heavy := 1.0 if i < HAULERS else 0.55
	Fx.dust(self, on_floor, Vector3.UP, heavy, "dirt")
	_throw_up_earth(on_floor + _finger_way(i) * 0.3, heavy)


## The way that hand's fingers go in, on the level.
func _finger_way(i: int) -> Vector3:
	var way := _wrist[i] - _world_shoulder(i)
	way.y = 0.0
	return way.normalized() if way.length() > 0.01 else -global_basis.z


## What its fingers turn over, where they go in. It stays where it was thrown up.
func _throw_up_earth(at: Vector3, heavy: float) -> void:
	if _earths.size() < EARTHS:
		var earth := MeshInstance3D.new()
		earth.mesh = _earth_mesh()
		earth.material_override = _earth_look
		earth.top_level = true
		earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		earth.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(earth)
		_earths.append(earth)
		_earth_age.append(0.0)

	var earth := _earths[_earth_next]
	_earth_age[_earth_next] = 0.0
	earth.visible = true
	earth.set_meta(&"at", at)
	earth.set_meta(&"size", 0.8 + heavy * 0.5)
	earth.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), at)
	_earth_next = (_earth_next + 1) % EARTHS


func _settle_earth(delta: float) -> void:
	for n in _earths.size():
		var earth := _earths[n]

		if not earth.visible:
			continue

		_earth_age[n] += delta
		var age := _earth_age[n]

		if age >= EARTH_STAYS + EARTH_SINKS:
			earth.visible = false
			continue

		var up := minf(age / EARTH_RISES, 1.0) * (1.0 - clampf((age - EARTH_STAYS) / EARTH_SINKS, 0.0, 1.0))
		var size: float = earth.get_meta(&"size")
		var turned := Basis(earth.global_basis.get_rotation_quaternion())
		earth.global_transform = Transform3D(turned.scaled(Vector3(size, size * maxf(up, 0.01), size)), earth.get_meta(&"at"))


static var _earth_shared: ArrayMesh


## Clods and a torn lip of it, round a hole: one mesh, painted, and shared.
static func _earth_mesh() -> ArrayMesh:
	if _earth_shared != null:
		return _earth_shared

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41

	# A low heap of it first, then what is broken off lying on that, small and uneven.
	_add_clod(tool, Vector3(0.0, 0.0, 0.0), Vector3(0.27, 0.05, 0.23), EARTH_DARK, rng)

	for n in 22:
		var angle := rng.randf() * TAU
		var far := sqrt(rng.randf()) * 0.25
		var wide := rng.randf_range(0.016, 0.05)
		var at := Vector3(cos(angle) * far, 0.03 + wide * 0.4, sin(angle) * far)
		var size := Vector3(wide * rng.randf_range(0.8, 1.4), wide * rng.randf_range(0.6, 1.0), wide * rng.randf_range(0.8, 1.4))
		var tone := EARTH_DARK.lerp(EARTH_LIGHT, rng.randf())
		_add_clod(tool, at, size, tone, rng)

	tool.generate_normals()
	_earth_shared = tool.commit()
	return _earth_shared


## A lump, its faces flat enough to read as broken earth.
static func _add_clod(tool: SurfaceTool, at: Vector3, size: Vector3, tone: Color, rng: RandomNumberGenerator) -> void:
	const RINGS := 4
	const AROUND := 6
	var points: Array[Vector3] = []

	for r in RINGS + 1:
		var down := PI * float(r) / float(RINGS)

		for a in AROUND:
			var turn := TAU * float(a) / float(AROUND)
			var rough := rng.randf_range(0.93, 1.07)
			points.append(at + Vector3(sin(down) * cos(turn) * size.x, cos(down) * size.y, sin(down) * sin(turn) * size.z) * rough)

	for r in RINGS:
		for a in AROUND:
			var n := (a + 1) % AROUND
			var corners: Array[Vector3] = [points[r * AROUND + a], points[r * AROUND + n], points[(r + 1) * AROUND + n], points[(r + 1) * AROUND + a]]

			for k in [0, 1, 2, 0, 2, 3]:
				tool.set_color(tone)
				tool.add_vertex(corners[k])


## Where that arm's wrist would be if it wasn't on the earth: out from its shoulder, drawn back or come over for a rake.
func _free_wrist(i: int, _grab: float) -> Vector3:
	var over: float = _rake[i] * (RAKE_OVER if _rake[i] > 0.0 else RAKE_BACK)
	var out := Basis(Vector3.RIGHT, -over) * Vector3(0.0, 0.0, -FREE_OUT)
	var seed := float(i) * 2.3 + 0.7
	out += Vector3(sin(_clock * (0.9 + float(i) * 0.13) + seed), sin(_clock * (0.7 + float(i) * 0.09) + seed * 1.7), 0.0) * SWAY
	return _markers[i].global_transform * out + Vector3.DOWN * FREE_HANGS


## Each arm goes for its own part of you.
func _grab_point(i: int, grab_at: Vector3) -> Vector3:
	var angle := float(i) * TAU / float(_hands.size()) + 0.6
	return grab_at + (global_basis.x * cos(angle) + Vector3.UP * sin(angle)) * GRAB_SPREAD


## That wrist, no further from its shoulder than an arm goes.
func _within_reach(i: int, wanted: Vector3) -> Vector3:
	var shoulder_at := _world_shoulder(i)
	var off := wanted - shoulder_at
	return shoulder_at + off.limit_length(ARM_GETS * _size)


## The shoulder, in the arm's own space: sunk in the flesh, behind where it comes out.
func _shoulder() -> Vector3:
	return Vector3(0.0, 0.0, SHOULDER_IN)


func _world_shoulder(i: int) -> Vector3:
	return _hands[i].global_transform * _shoulder()


## The arm from its wrist back to its shoulder: the elbow out and up, the hand where it is going and how.
func _solve_arm(i: int, grab: float, grab_at: Vector3) -> void:
	var hand := _hands[i]
	var into := hand.global_transform.affine_inverse()
	var wrist_at: Vector3 = into * _wrist[i]
	var shoulder := _shoulder()
	var side := signf(_markers[i].position.x)
	# How the hand goes: down into the earth, dug in or coming to it; out at what it is after, else.
	var world_way: Vector3 = (_wrist[i] - _world_shoulder(i))
	world_way.y = 0.0
	world_way = world_way.normalized() if world_way.length() > 0.01 else -global_basis.z
	world_way = world_way.rotated(Vector3.UP, _step_turn[i]) if i < DIGGERS else world_way
	var low := 1.0 if _dug[i] else (1.0 if i < DIGGERS and _reach_t[i] > 0.0 else 0.0)
	var u := _reach_t[i]
	# In the earth: driven down. Coming up: hanging off its wrist, trailing. Over: out ahead, flat, feeling. Then down.
	var drives: float = 1.0 if _dug[i] else lerpf(lerpf(1.6, 0.25, smoothstep(0.1, STEP_OVER, u)), 1.0, smoothstep(STEP_HOVER_ENDS, 1.0, u))
	var trails: float = 0.0 if _dug[i] else (1.0 - smoothstep(0.05, 0.45, u)) * 0.7
	var pointing: Vector3 = (world_way * (1.0 - trails * 1.4) + Vector3.DOWN * DRIVES_DOWN * low * drives).normalized()

	if not _dug[i] and low <= 0.0:
		var from_shoulder: Vector3 = (_wrist[i] - _world_shoulder(i)).normalized()
		pointing = from_shoulder.lerp((grab_at - _wrist[i]).normalized(), grab).normalized()

	var fingers: Vector3 = (into.basis * pointing).normalized()
	var back: Vector3 = (into.basis * Vector3.UP).normalized()

	if absf(fingers.dot(back)) > 0.95:
		back = (into.basis * (-global_basis.z)).normalized()

	var hand_turned := Basis.looking_at(fingers, back)
	var hand_bone := hand.find_bone("hand")
	var hand_rest: Basis = hand.get_bone_rest(hand_bone).basis
	var hand_basis: Basis = hand_turned * hand_rest
	hand.set_bone_pose_position(hand_bone, wrist_at)
	hand.set_bone_pose_rotation(hand_bone, hand_basis.get_rotation_quaternion())
	# The elbow.
	var span := shoulder - wrist_at
	var far := span.length()
	var reach := BONE_LENGTH * 2.0
	var stretch := clampf(far / (reach * 0.98), 1.0, SEIZE_DRAWS_OUT if i == SEIZING_ARM and _seizing else DRAWN_OUT_MOST * 1.2)
	_stretch[i] = stretch
	var bone := BONE_LENGTH * stretch
	var along_span: Vector3 = span / maxf(far, 0.001)
	var elbow_way: Vector3 = (into.basis * (Vector3.UP + global_basis.x * side * ELBOW_OUT[mini(i, DIGGERS - 1)])).normalized()
	elbow_way = (elbow_way - along_span * elbow_way.dot(along_span)).normalized()
	var elbow := wrist_at + span * 0.5 + elbow_way * sqrt(maxf(bone * bone - far * far * 0.25, 0.0))
	var arm_1 := hand.find_bone("arm_1")
	var arm_2 := hand.find_bone("arm_2")
	var forearm := _aim(hand, arm_1, hand_basis, (elbow - wrist_at).normalized())
	hand.set_bone_pose_scale(arm_1, Vector3(1.0, stretch, 1.0))
	_aim(hand, arm_2, forearm, (shoulder - elbow).normalized())


func _aim(hand: Skeleton3D, bone: int, parent: Basis, wanted: Vector3) -> Basis:
	var rest: Basis = parent * hand.get_bone_rest(bone).basis
	var aimed := Basis(Quaternion(rest.y.normalized(), wanted)) * rest
	hand.set_bone_pose_rotation(bone, (parent.inverse() * aimed).get_rotation_quaternion())
	return aimed


func _curl_fingers(hand: Skeleton3D, which: int) -> void:
	for f in FINGER_NAMES.size():
		var seed := float(f) * 1.9 + float(which) * 2.3
		var palsy := sin(_clock * 3.0 + seed) * 0.6 + sin(_clock * 7.7 + seed * 2.0) * 0.4
		# (No two the same, on any hand; dug in, some are further in than others.)
		var own := sin(float(f) * 2.4 + float(which) * 1.3) * (0.3 if _dug[which] else 0.12)
		var shut := _shut[which] + own + palsy * CURLS * (0.15 if _dug[which] else 1.0)

		for k in range(1, 4):
			var bone := hand.find_bone("%s_%02d" % [FINGER_NAMES[f], k])
			var rest: Basis = hand.get_bone_rest(bone).basis
			hand.set_bone_pose_rotation(bone, (rest * Basis(Vector3.RIGHT, -shut * [0.7, 1.0, 1.25][k - 1])).get_rotation_quaternion())
