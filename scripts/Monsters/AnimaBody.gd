extends Node3D
## What a ravenous ánima looks like, and how it moves. The hands are a real model, walking
## on their fingertips: each finger reaches for its place on the floor (a two-joint
## solve), stance and swing in turn, so they plant and don't slide; the palm arched up,
## the arm dragged behind. At rest they lie down on the palm, flexing. The face is a small
## dried skull (AnimaSkull.gd) floating behind two great hands: hung and slack at rest, its
## hands dangling; hauling itself through the air after you; drawn back and gaping in its
## tell, then hands and teeth thrown at you; biting on nothing when it misses. Its pose runs
## on springs, so each change overshoots and settles. On you, it is on your face instead
## (LeechFace.gd). The torso is the mouth (AnimaMouth.gd), awaiting its own moves (the
## plan's Task 12).

const Fx := preload("res://scripts/Visual/Fx.gd")
const FleshShader := preload("res://scripts/Monsters/anima_flesh.gdshader")
const BRUSH := preload("res://textures/painted/eclipse/brush.png")
const HANDS_MODEL := "res://assets/monsters/anima_hands.glb"
const LEFT_MODEL := "res://assets/monsters/anima_hands_left.glb"
const AnimaSkullScript := preload("res://scripts/Monsters/AnimaSkull.gd")
const AnimaFire := preload("res://scripts/Monsters/AnimaFire.gd")
const AnimaBurnScript := preload("res://scripts/Monsters/AnimaBurn.gd")
const AnimaDeathsScript := preload("res://scripts/Monsters/AnimaDeaths.gd")
const AnimaSpillScript := preload("res://scripts/Monsters/AnimaSpill.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const FINGER_NAMES := ["index", "middle", "ring", "pinky", "thumb"]
## Each finger's place in the walk (of a whole cycle): opposite fingers together.
const PHASES := [0.0, 0.5, 0.05, 0.55, 0.3]
## How far ahead of its knuckle each sets down (m), and how far out to the side.
const REACH := [0.2, 0.23, 0.2, 0.15, 0.04]
const SPLAY := [0.08, 0.01, 0.07, 0.17, 0.34]
## The share of a cycle a finger is off the floor, how high it lifts, how long a step
## is (m) at a run, and how many steps a metre.
const SWING := 0.32
const LIFT := 0.1
const STEP := 0.22
## The palm: how high it stands off the floor, how the hand is tipped (radians: wrist
## up), and how far it rears in a tell.
const MOST_STEPS := 3.4
const PALM_HIGH := 0.34
const TIP := 0.16
const REAR := 0.26
## How it holds its arm, against the hand's tip: out behind it, then down to the floor.
const ARM_OUT := -0.62
const ARM_DOWN := -0.42
## Fire at the end of the arm, nearly out.
## The hands, down on the palm at rest: how high it lies; thrown down by a miss, for how long.
const REST_HIGH := 0.13
const SLAM_FOR := 0.34
## The face's hands: how big, against the walking hands.
const FACE_HAND_SIZE := 0.86
## How its fingers open and spread, against what they rest at.
const FACE_FAN := 0.13
## Its poses. nod: + chin up. lift, back: of the head (+ back is away from you). jaw: 0..1.
## hand: where the wrists are (x out to the side, y up, z ahead is -). pitch: of the hands (-
## fingers down, + palm up at you). shut: of the fingers. fan: of their spread. snap: how
## quickly it gets there, in cycles a second.
const POSES := {
	&"rest": {"nod": -0.62, "lift": -0.2, "back": 0.03, "jaw": 0.3, "hand": Vector3(0.2, -0.5, -0.03), "pitch": -1.25, "shut": 0.56, "fan": 0.5, "snap": 1.6},
	&"wake": {"nod": 0.26, "lift": 0.07, "back": 0.1, "jaw": 0.95, "hand": Vector3(0.38, 0.1, -0.2), "pitch": 0.5, "shut": 0.08, "fan": 1.6, "snap": 7.0},
	&"rise": {"nod": -0.5, "lift": -0.3, "back": 0.06, "jaw": 0.55, "hand": Vector3(0.32, 0.16, -0.22), "pitch": 0.1, "shut": 0.2, "fan": 1.3, "snap": 3.0},
	&"rush": {"nod": -0.2, "lift": 0.0, "back": 0.0, "jaw": 0.36, "hand": Vector3(0.3, -0.12, -0.34), "pitch": -0.2, "shut": 0.5, "fan": 1.0, "snap": 4.0},
	&"circle": {"nod": -0.04, "lift": 0.03, "back": 0.02, "jaw": 0.3, "hand": Vector3(0.32, -0.22, -0.24), "pitch": -0.35, "shut": 0.62, "fan": 1.0, "snap": 3.0},
	&"tell": {"nod": 0.24, "lift": 0.1, "back": 0.15, "jaw": 1.0, "hand": Vector3(0.47, 0.27, -0.14), "pitch": 1.0, "shut": 0.0, "fan": 1.9, "snap": 6.0},
	&"leap": {"nod": -0.28, "lift": -0.02, "back": -0.2, "jaw": 1.0, "hand": Vector3(0.2, -0.02, -0.74), "pitch": -0.08, "shut": 0.26, "fan": 1.2, "snap": 9.0},
	&"missed": {"nod": -0.52, "lift": -0.12, "back": -0.06, "jaw": 0.0, "hand": Vector3(0.3, -0.36, -0.42), "pitch": -0.75, "shut": 1.05, "fan": 0.6, "snap": 11.0},
	&"thrown": {"nod": 0.7, "lift": 0.05, "back": 0.16, "jaw": 0.7, "hand": Vector3(0.48, 0.14, 0.18), "pitch": 0.9, "shut": 0.2, "fan": 1.6, "snap": 7.0},
	&"wind_up": {"nod": 0.12, "lift": 0.05, "back": 0.13, "jaw": 0.85, "hand": Vector3(0.44, 0.14, -0.1), "pitch": 0.65, "shut": 0.02, "fan": 1.7, "snap": 10.0},
	&"swipe": {"nod": -0.32, "lift": -0.02, "back": -0.24, "jaw": 0.12, "hand": Vector3(-0.1, -0.02, -0.62), "pitch": -0.1, "shut": 0.95, "fan": 0.7, "snap": 15.0},
	&"back_off": {"nod": -0.08, "lift": 0.02, "back": 0.1, "jaw": 0.3, "hand": Vector3(0.34, -0.2, -0.2), "pitch": -0.3, "shut": 0.5, "fan": 1.0, "snap": 5.0},
	&"crowd": {"nod": 0.2, "lift": 0.06, "back": 0.1, "jaw": 0.92, "hand": Vector3(0.42, 0.12, -0.14), "pitch": 0.5, "shut": 0.1, "fan": 1.5, "snap": 8.0},
	&"leave": {"nod": -0.5, "lift": -0.16, "back": 0.04, "jaw": 0.22, "hand": Vector3(0.34, -0.2, -0.2), "pitch": -0.35, "shut": 0.35, "fan": 0.8, "snap": 2.5},
	&"dead": {"nod": -0.42, "lift": 0.0, "back": 0.0, "jaw": 0.72, "hand": Vector3(0.36, -0.02, -0.26), "pitch": -0.04, "shut": 0.1, "fan": 1.25, "snap": 2.1},
	&"on": {"nod": 0.0, "lift": 0.0, "back": 0.0, "jaw": 0.6, "hand": Vector3(0.3, 0.0, -0.3), "pitch": 0.0, "shut": 0.5, "fan": 1.0, "snap": 5.0},
}
## Hauling itself along: how far each hand reaches and pulls, up and over; how fast.
const PAW_REACH := 0.13
const PAW_LIFT := 0.06
const PAW_RATE := 1.0
## At rest: how long between its starts, and what one does to its head.
const TIC_EVERY := Vector2(1.4, 3.8)
const TIC_KICK := 1.5
## Where its arms grow from, on the skull: behind the jaw, each side (m). How long they are, a
## length to each bone, as the model is cut.
const SHOULDER := Vector3(0.078, -0.07, 0.05)
const ARM_BONE := 0.42
## The way its elbows go, each side, out and up.
const ELBOW_OUT := Vector3(0.75, 0.55, 0.3)
## How each form dies: its own last moments (AnimaDeaths.gd).
const DEATHS: Dictionary = AnimaDeathsScript.TABLE
## Dead: how fast it falls (m/s²), how high the body lies off the floor, by form; how far over
## it lies; how fast a shot's push dies.
const FALLS := 11.0
const LIES_AT := {&"hands": 0.25, &"face": 0.16, &"torso": 0.5}
const PUSH_DIES := 3.5
const DEAD_HIGH := 0.075
## The hands, dying: how far up it rears (m, and the turn of it), how far a finger draws in, how
## much the heat draws them in once it is limp, and how hard they go when it shakes.
const REAR_UP := 0.46
const REAR_TURN := 1.32
const CURL_IN := 0.14
const HEAT_CURLS := 0.42
const SCRABBLES := 0.085
## How fast its fingers follow, thrashing and limp.
const FINGERS_QUICK := 16.0
const FINGERS_SLACK := 4.2
## The base of what a dying hand is told.
const HAND_DYING := {"low": 1.0, "rear": 0.0, "flip": 0.0, "up": 0.0, "roll": 0.0, "curl": 0.1, "open": 0.0, "shake": 0.0, "walk": 0.0, "drag": 0.0, "snap": 4.0}
## How much the heat shuts the face's hands once it is limp, and opens its jaw.
const HEAT_SHUTS := 0.5
const HEAT_GAPES := 0.18
## The size of what burns, by form, against what AnimaBurn.gd makes.
const BURNS_SIZE := {&"hands": 1.0, &"face": 1.2, &"torso": 1.7}
## The mouth's last moments, before the beats have said anything.
const MOUTH_DYING := {"ribs": 0.3, "rear": 0.0, "swell": 0.0, "slump": 0.0, "digs": true, "grab": 0.0, "drag": 0.0, "snap": 3.0, "falls": true}
## How long the parts of the face outlast its hands, burning.
const SKULL_LATE := 0.26
const JAW_LATE := 0.14
## Flung by the Burst: how long it tumbles.
const TUMBLES := 0.65
## Its swing, as the hands do it: how long, how far over it rolls.
const RAKE_TAKES := 0.16
const RAKE_ROLLS := 1.05
## A Shard through it: how long the knock lasts, how far it turns it.
const JOLTS := 0.3
const JOLT_ROLL := 0.7
## How far down it looks for a floor to fall on (m).
const FLOOR_LOOK := 12.0
## Where its flames stand, and how tall: along each hand's bones, and on the skull. (Bone, how
## far along it, how tall at its height.)
const FINGER_FLAME := 0.26
const HAND_FLAMES := [["hand", 0.1, 0.42], ["middle_01", 0.0, 0.36], ["arm_1", 0.1, 0.36], ["arm_1", 0.3, 0.32], ["arm_2", 0.1, 0.3], ["arm_2", 0.3, 0.24]]
const SKULL_FLAMES := [[Vector3(0.0, -0.13, -0.12), 0.4], [Vector3(0.045, 0.012, -0.11), 0.22], [Vector3(-0.045, 0.012, -0.11), 0.22], [Vector3(0.0, 0.12, -0.02), 0.32], [Vector3(0.0, -0.2, -0.08), 0.26]]
## How long a miss's bite lasts before it opens again and looks for you.
const BITE_HOLDS := 0.28
const LOOKS_ABOUT := 0.34
const AnimaMouthScript := preload("res://scripts/Monsters/AnimaMouth.gd")
const Bestiary := preload("res://scripts/Monsters/Bestiary.gd")
## The mouth, by what it is doing: how far its ribs stand open, how far it has reared (0..1), its
## arms (-1 drawn back, 1 come over), how quick its ribs and its rearing go. Rearing: how far back it
## tips (rad), how far up it comes (m). Knocked: how far over it goes (rad).
const MOUTH_POSES := {
	&"rest": {"ribs": 0.03, "rear": 0.0, "snap": 2.0},
	&"wake": {"ribs": 0.6, "rear": 0.4, "snap": 2.0, "rears": 1.2},
	&"rise": {"ribs": 0.3, "rear": 0.1, "snap": 1.6, "rears": 1.0},
	&"rush": {"ribs": 0.12, "rear": 0.0, "snap": 1.4, "rears": 1.0},
	&"circle": {"ribs": 0.22, "rear": 0.1, "snap": 1.4, "rears": 1.0},
	&"tell": {"ribs": 1.0, "rear": 1.0, "snap": 0.9, "rears": 0.75, "rake": -0.6, "swell": 0.75, "swells": 0.75},
	&"leap": {"ribs": 1.0, "rear": 0.45, "snap": 2.0, "rears": 1.2, "rake": 0.5, "swell": 1.0, "swells": 2.0, "grab": 1.0, "digs": false},
	&"missed": {"ribs": 0.08, "rear": 0.0, "snap": 5.0, "rears": 3.5, "swell": 0.0, "swells": 2.2},
	&"thrown": {"ribs": 0.7, "rear": 0.2, "snap": 3.0, "rears": 1.5, "digs": false},
	&"wind_up": {"ribs": 0.85, "rear": 0.65, "snap": 1.5, "rears": 1.1, "rake": -1.0, "swell": 0.5, "swells": 1.0},
	&"swipe": {"ribs": 0.0, "rear": 0.3, "snap": 7.0, "rears": 3.0, "rake": 1.0, "swell": 0.9, "swells": 2.6},
	&"back_off": {"ribs": 0.12, "rear": 0.1, "snap": 1.5, "rears": 1.0},
	&"crowd": {"ribs": 0.85, "rear": 0.9, "snap": 1.1, "rears": 0.9, "rake": -0.3, "swell": 0.5, "swells": 0.8},
	&"leave": {"ribs": 0.05, "rear": 0.0, "snap": 1.1, "rears": 0.9},
	&"on": {"ribs": 0.6, "rear": 0.5, "snap": 5.0, "digs": false, "grab": 1.0, "swell": 1.0},
}
## How fast it can come round (rad/s); how near you it keeps you in its mouth, whichever way it is going (m).
const MOUTH_TURNS := 1.0
const MOUTH_KEEPS_ON_YOU := 4.5
const MOUTH_REARS := 0.5
const MOUTH_RISES := 0.28
const MOUTH_TUMBLES := 1.1
const MOUTH_JOLTS := 0.4
## The mouth: where its fire trails from, from its middle.
const MOUTH_FIRES := [Vector3(0.05, -0.2, 1.3), Vector3(-0.15, -0.28, 1.1), Vector3(0.2, -0.25, 1.05)]
const FIRE_CORE := Color("#8E9C3C")
const FIRE_BODY := Color("#3E4624")
const FIRE_EDGE := Color("#16160E")

var form: StringName = &"hands"
## How big, if it is the elite mouth.
var elite_size := 0.0
## How much it has drunk, shown, 0..1.
var fed_shown := 0.0
var hurt := 0.0
## Resin burning on it while it is smoked, 0..1.
var smoulder := 0.0

var _parts := {}
var _skeleton: Skeleton3D
var _clock := 0.0
var _walk := 0.0
var _rear := 0.0
var _floor_y := -0.25
## How far over on its back it is, thrown off, 0..1.
var _flip := 0.0
var _ember_flare := 0.0
var _left_hand: Skeleton3D
var _right_hand: Skeleton3D
var _rig: Node3D
var _doing: StringName = &""
var _doing_for := 0.0
var _springs := {}
var _rest := 0.0
var _tic_in := 1.0
var _burn: Node3D
var _falling := Vector3.ZERO
var _floor_at := 0.0
var _landed := false
var _death: Dictionary = {}
var _death_t := 0.0
var _beats_said := 0
var _lies_side := 1.0
var _you: Node3D
var _curl_shown := 0.0
var _tumble := 0.0
var _jolt := 0.0
var _rake_roll := 0.0
var _rake_side := 1.0
var _last_wound: StringName = &""
var _nod := 0.0
var _back := 0.0
var _embers: Array[MeshInstance3D] = []
var _face_hands: Array[MeshInstance3D] = []
var _face_roots: Array[Node3D] = []
var _bones := {}
var _tips: Array[Vector3] = []
var _look: StandardMaterial3D
var _mouth_looked := false
var _mouth: Node3D
var _reared := 0.0
var _flesh: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_physics_process(false)
	_rng.randomize()
	_clock = _rng.randf() * 10.0

	if form == &"hands":
		_build_hands()
	elif form == &"face":
		_build_face()
	else:
		_build_mouth()


func part(id: StringName) -> MeshInstance3D:
	return _parts.get(id)


func skeleton() -> Skeleton3D:
	return _skeleton


## The face's hand on that side (-1 its left, 1 its right).
func hand_on(side: float) -> Skeleton3D:
	return _left_hand if side < 0.0 else _right_hand


## How far its jaw has dropped, 0..1.
func jaw_open() -> float:
	return _rig.jaw_open() if _rig != null else 0.0


## The face: how far its chin is up, in radians (- it hangs).
func head_nod() -> float:
	return _nod


## The face: how far back its head is drawn, in metres (- it is thrown at you).
func head_back() -> float:
	return _back


## The face: how high its hands are.
func hands_up() -> float:
	return (_face_roots[0].position.y + _face_roots[1].position.y) * 0.5


## The face: how far ahead its hands are.
func hands_ahead() -> float:
	return -(_face_roots[0].position.z + _face_roots[1].position.z) * 0.5


## The face: how far the end of its arm on that side is from the base of its skull (m).
func arm_gap(side: float) -> float:
	var hand := hand_on(side)
	var end := hand.get_bone_global_pose(hand.find_bone("arm_2")) * Vector3(0.0, ARM_BONE, 0.0)
	return (hand.global_transform * end).distance_to(_rig.skull().global_transform * _shoulder(side))


func _shoulder(side: float) -> Vector3:
	return Vector3(SHOULDER.x * side, SHOULDER.y, SHOULDER.z)


## The face, as a piece (AnimaSkull.gd).
func skull_rig() -> Node3D:
	return _rig


func _build_hands() -> void:
	var made: Node3D = (load(HANDS_MODEL) as PackedScene).instantiate()
	add_child(made)
	_skeleton = made.find_children("*", "Skeleton3D", true, false)[0]

	for mesh in made.find_children("*", "MeshInstance3D", true, false):
		_parts[StringName(mesh.name)] = mesh

	_flesh = ShaderMaterial.new()
	_flesh.shader = FleshShader
	_flesh.set_shader_parameter(&"stroke_sheet", BRUSH)
	_flesh.set_shader_parameter(&"wet", 0.0)
	_flesh.set_shader_parameter(&"fill", 0.46)
	_flesh.set_shader_parameter(&"rim", 0.34)
	part(&"Hand").set_surface_override_material(0, _flesh)
	_tips.resize(FINGER_NAMES.size())

	for i in FINGER_NAMES.size():
		var chain: Array[int] = []

		for k in range(1, 4):
			chain.append(_skeleton.find_bone("%s_%02d" % [FINGER_NAMES[i], k]))

		_bones[i] = chain

	_build_fire()
	_parts[&"Ember"] = AnimaFire.ember_on(part(&"Hand"), 0.01)


func _build_face() -> void:
	_flesh = _new_flesh()
	# Bone stays bone: not the red the painted fill gives things in the dark.
	_flesh.set_shader_parameter(&"fill_sky", Color(0.42, 0.42, 0.37))
	_flesh.set_shader_parameter(&"fill_ground", Color(0.42, 0.34, 0.26))
	_rig = AnimaSkullScript.new(_flesh)
	add_child(_rig)

	for id in [&"Skull", &"Jaw", &"Gullet", &"Tongue"]:
		_parts[id] = _rig.part(id)

	_right_hand = _face_hand(HANDS_MODEL, 1.0)
	_left_hand = _face_hand(LEFT_MODEL, -1.0)
	_parts[&"Ember"] = _embers[0]
	# What is left of its fire, trailing from the end of its gullet.
	var flame := MeshInstance3D.new()
	flame.mesh = MeshVfx.flame(0.3, 0.05, 8, 8)
	flame.material_override = MeshVfx.look(FIRE_CORE, FIRE_BODY, FIRE_EDGE, 0.7, 0.5, 1.1)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.0, -0.25, 0.04))
	_rig.skull().add_child(flame)


func _new_flesh() -> ShaderMaterial:
	var flesh := ShaderMaterial.new()
	flesh.shader = FleshShader
	flesh.set_shader_parameter(&"stroke_sheet", BRUSH)
	flesh.set_shader_parameter(&"wet", 0.0)
	flesh.set_shader_parameter(&"fill", 0.46)
	flesh.set_shader_parameter(&"rim", 0.34)
	return flesh


func _face_hand(model: String, side: float) -> Skeleton3D:
	var hand: Node3D = (load(model) as PackedScene).instantiate()
	hand.name = "HandRight" if side > 0.0 else "HandLeft"
	hand.scale = Vector3.ONE * FACE_HAND_SIZE
	add_child(hand)
	var mesh: MeshInstance3D = hand.find_children("*", "MeshInstance3D", true, false)[0]
	mesh.set_surface_override_material(0, _flesh)
	_face_hands.append(mesh)
	_face_roots.append(hand)
	_embers.append(AnimaFire.ember_on(mesh, 0.007))
	return hand.find_children("*", "Skeleton3D", true, false)[0]


## What is left of its fire, where its arm ends.
func _build_fire() -> void:
	var at := BoneAttachment3D.new()
	at.bone_name = "arm_2"
	_skeleton.add_child(at)
	var flame := MeshInstance3D.new()
	flame.mesh = MeshVfx.flame(0.3, 0.05, 8, 8)
	var look := MeshVfx.look(FIRE_CORE, FIRE_BODY, FIRE_EDGE, 0.7, 0.5, 1.1)
	flame.material_override = look
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3(0.0, float(_skeleton.get_bone_rest(_skeleton.find_bone("arm_2")).origin.length()), 0.0)
	at.add_child(flame)


func _build_mouth() -> void:
	_flesh = _new_flesh()
	var bone := _new_flesh()
	# Bone stays bone: not the red the painted fill gives things in the dark.
	bone.set_shader_parameter(&"fill_sky", Color(0.42, 0.42, 0.37))
	bone.set_shader_parameter(&"fill_ground", Color(0.42, 0.34, 0.26))
	# Neither is what it looks like (anima_flesh.gdshader).
	# (No lilac from the moon in its edges: only what is its own.)
	_flesh.set_shader_parameter(&"rim_colour", Color(0.42, 0.46, 0.34))
	bone.set_shader_parameter(&"rim_colour", Color(0.42, 0.46, 0.34))
	_flesh.set_shader_parameter(&"burn_tile", 3.2)
	bone.set_shader_parameter(&"burn_tile", 3.2)
	_flesh.set_shader_parameter(&"spectral", 1.0)
	_flesh.set_shader_parameter(&"frays", 1.0)
	# (Less fill than the others: what it is made of is in its shadows, and they should stay shadows.)
	_flesh.set_shader_parameter(&"fill", 0.2)
	bone.set_shader_parameter(&"fill", 0.2)
	_flesh.set_shader_parameter(&"rim", 0.16)
	bone.set_shader_parameter(&"rim", 0.16)
	bone.set_shader_parameter(&"spectral", 0.6)
	_mouth = AnimaMouthScript.new(_flesh, bone, float(Bestiary.form(&"anima", form)["height"]))
	add_child(_mouth)

	# Its candles, alight: it has eaten what was left for the others.
	if elite_size > 0.0:
		_mouth.be_elite(elite_size, MeshVfx.flame(0.36, 0.07, 8, 8), MeshVfx.look(Color("#E4F09A"), Color("#8EB03C"), Color("#2A3414"), 1.4, 0.8, 1.1))

	for id in AnimaMouthScript.MESHES:
		_parts[id] = _mouth.part(id)

	# What is left of its fire, where the rest of it was.
	for at in MOUTH_FIRES:
		var flame := MeshInstance3D.new()
		flame.mesh = MeshVfx.flame(0.42, 0.09, 8, 8)
		flame.material_override = MeshVfx.look(FIRE_CORE, FIRE_BODY, FIRE_EDGE, 0.7, 0.5, 1.1)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = at
		_mouth.add_child(flame)


## The mouth: what pushes out of it, how far its ribs stand open.
func souls() -> Array[Node3D]:
	return _mouth.souls() if _mouth != null else ([] as Array[Node3D])


## The mouth: where a dragging arm is in its stride, how high it has heaved, how far it has reared
## (0..1), how far over it has been knocked, and how many arms are raking.
func arm_stride(which: int) -> float:
	return _mouth.arm_stride(which)


func heave() -> float:
	return _mouth.heave()


func reared() -> float:
	return _reared


func tipped() -> float:
	return _mouth.rotation.z


func arms_raking() -> int:
	return _mouth.arms_raking()


## Too many arms hauling one mass: it heaves and rolls with them. It rears up with its ribs apart
## before it comes, and they snap shut on the swing.
## How it has come apart (tests/anima_test.gd).
func ribs_flung() -> float:
	return _mouth.ribs_flung()


func souls_apart() -> int:
	return _mouth.souls_apart()


func souls_spread() -> float:
	return _mouth.souls_spread()


func tears_open() -> int:
	return _mouth.tears_open()


## Those in it (tests/anima_test.gd).
func presses_held() -> int:
	return _mouth.presses_held()


func press_held_off(n: int) -> void:
	_mouth.press_held_off(n)


func hold_press(n: int, at: Vector3, jaw: float) -> void:
	_mouth.hold_press(n, at, jaw)


## It has taken one in, and stands this big now.
func has_taken(kind: StringName, size: float) -> void:
	_mouth.has_taken(kind, size)


func candles_lit() -> bool:
	return _mouth.candles_lit()


func taken_shown(kind: StringName) -> int:
	return _mouth.taken_shown(kind)


func taken_up() -> int:
	return _mouth.taken_up()


func press_shown(n: int) -> bool:
	return _mouth.press_shown(n)


func press_strength(n: int) -> float:
	return _mouth.press_strength(n)


func press_kind(n: int) -> int:
	return _mouth.press_kind(n)


func press_jaw(n: int) -> float:
	return _mouth.press_jaw(n)


func press_on_skin(n: int) -> bool:
	return _mouth.press_on_skin(n)


func press_toward(n: int, at: Vector3) -> float:
	return _mouth.press_toward(n, at)


func skull_out(n: int) -> float:
	return _mouth.skull_out(n)


func burst_out() -> float:
	return _mouth.burst_out()


func burst_shown() -> bool:
	return _mouth.burst_shown()


func tear_open() -> float:
	return _mouth.tear_open()


func arm_hovering(which: int) -> bool:
	return _mouth.arm_hovering(which)


func arm_reach_of(which: int) -> float:
	return _mouth.arm_reach_of(which)


func hunger() -> float:
	return _mouth.hunger()


## Its arms, for what has to know where they are (tests/anima_test.gd).
func arm_dug_in(which: int) -> bool:
	return _mouth.arm_dug_in(which)


func dug_floor(which: int) -> float:
	return _mouth.dug_floor(which)


func wrist(which: int) -> Vector3:
	return _mouth.wrist(which)


func fingertip_y(which: int) -> float:
	return _mouth.fingertip_y(which)


func arm_stretch(which: int) -> float:
	return _mouth.arm_stretch(which)


func arm_end_gap(which: int) -> float:
	return _mouth.arm_end_gap(which)


func soul_at(index: int) -> Transform3D:
	return _mouth.soul_at(index)


func earth_shown() -> int:
	return _mouth.earth_shown()


## How swollen it is, how big it stands, and where its front is.
func swollen() -> float:
	return _mouth.swollen()


func mouth_size() -> Vector3:
	return _mouth.size_now()


func front_of_it() -> Vector3:
	return _mouth.global_position - _mouth.global_basis.z * 0.5


## How many of its hauls have landed, and how far it has rocked into the last.
func hauls_done() -> int:
	return _mouth.hauls_done() if _mouth != null else 0


func rock() -> float:
	return _mouth.rock() if _mouth != null else 0.0


## How it goes, of its speed: with its arms' hauls.
func lurch() -> float:
	return _mouth.lurch() if _mouth != null else 1.0


## Backing off or going round you, the mouth keeps you in it: it doesn't turn its back and walk.
func _mouth_stays_on_you(doing: StringName, you: Node3D) -> bool:
	if form != &"torso":
		return false

	var near := global_position.distance_to(you.global_position) < MOUTH_KEEPS_ON_YOU
	return doing == &"back_off" or doing == &"circle" or (doing == &"rush" and near)


func _work_mouth(delta: float, doing: StringName, you: Node3D, moving: Vector3, fed: float) -> void:
	# (The moment it knows you: it has been looking at you all along, and its hands are where it stood.)
	if not _mouth_looked and you != null:
		_mouth_looked = true
		var at_you := Vector3(you.global_position.x - global_position.x, 0.0, you.global_position.z - global_position.z)

		if at_you.length() > 0.01:
			global_basis = Basis.looking_at(at_you.normalized(), Vector3.UP)

		_mouth.arrive()

	# On you, it is all round you: LeechCage.gd is what you see.
	visible = doing != &"on"
	var pose: Dictionary = MOUTH_POSES.get(doing, MOUTH_POSES[&"rush"])
	var snap: float = float(pose.get("snap", 5.0))
	_mouth.ribs_to(clampf(_spring(&"mouth_ribs", float(pose["ribs"]), snap, 0.8, delta), 0.0, 1.15))
	_reared = maxf(_spring(&"mouth_rear", float(pose["rear"]), float(pose.get("rears", 3.0)), 0.7, delta), 0.0)
	var rake_to: float = float(pose.get("rake", 0.0))
	var swell := _spring(&"mouth_swell", float(pose.get("swell", 0.0)), float(pose.get("swells", 1.6)), 0.75, delta)
	var grab := _spring(&"mouth_grab", float(pose.get("grab", 0.0)), 3.0, 0.9, delta)
	var grab_at: Vector3 = you.global_position + Vector3.UP * 0.15 if you != null else global_position
	_mouth.tick(delta, moving.length(), moving, rake_to, bool(pose.get("digs", true)), clampf(grab, 0.0, 1.0), grab_at, swell, fed, hurt, smoulder)
	var knocked := _tumble * MOUTH_TUMBLES * _lies_side + _jolt * MOUTH_JOLTS * _lies_side
	_mouth.rotation = Vector3(_reared * MOUTH_REARS + _tumble * MOUTH_TUMBLES * 0.5 - _mouth.rock(), 0.0, _mouth.roll() + knocked)
	_mouth.position = Vector3(0.0, _mouth.heave() + _reared * MOUTH_RISES, 0.0)


func ribs_open() -> float:
	return _mouth.ribs_open() if _mouth != null else 0.0


func ribs_to(open: float) -> void:
	if _mouth != null:
		_mouth.ribs_to(open)


## Each tick: what it is doing, whom at, how it moves, how much it has drunk (0..1).
func tick(delta: float, doing: StringName, you: Node3D, moving: Vector3, fed: float, exposed: bool, smoked: bool) -> void:
	_clock += delta

	if doing != _doing:
		_doing = doing
		_doing_for = 0.0

		if doing == &"swipe":
			_rake_side = -1.0 if _rng.randf() < 0.5 else 1.0

	_doing_for += delta
	_tumble = move_toward(_tumble, 0.0, delta / TUMBLES)
	_jolt = move_toward(_jolt, 0.0, delta / JOLTS)
	fed_shown = fed
	hurt = move_toward(hurt, 0.0, delta / 0.25)
	smoulder = move_toward(smoulder, 1.0 if smoked else 0.0, delta * (6.0 if smoked else 3.0))
	var flat := Vector3(moving.x, 0.0, moving.z)

	if you != null and doing != &"rest" and (flat.length() < 0.2 or doing == &"tell" or doing == &"on" or doing == &"wind_up" or doing == &"swipe" or _mouth_stays_on_you(doing, you)):
		var way := you.global_position - global_position
		way.y = 0.0

		if way.length() > 0.01:
			flat = way

	if flat.length() > 0.01 and doing != &"thrown":
		var wanted := Basis.looking_at(flat.normalized(), Vector3.UP)
		var now := global_basis.orthonormalized()

		if form == &"torso":
			# Too heavy to spin: it comes round at the rate it can, however far it has to.
			var off := now.get_rotation_quaternion().angle_to(wanted.get_rotation_quaternion())
			global_basis = now.slerp(wanted, minf(MOUTH_TURNS * delta / maxf(off, 0.001), 1.0))
		else:
			global_basis = now.slerp(wanted, 1.0 - exp(-12.0 * delta))

	if form == &"hands":
		_walk_hand(delta, doing, Vector3(moving.x, 0.0, moving.z).length(), fed, exposed)
		return

	if form == &"face":
		# On you, it is on your face: LeechFace.gd is what you see.
		visible = doing != &"on"
		_work_face(delta, doing, Vector3(moving.x, 0.0, moving.z).length(), fed)
		return

	_work_mouth(delta, doing, you, Vector3(moving.x, 0.0, moving.z), fed)


## How far its fire is up, 0..1.
func ember_flare() -> float:
	return _ember_flare


## How far over on its back it is, 0..1.
func flipped() -> float:
	return _flip


func _walk_hand(delta: float, doing: StringName, speed: float, fed: float, exposed: bool) -> void:
	var part_hand := part(&"Hand")
	part_hand.set_instance_shader_parameter(&"fed", fed)
	part_hand.set_instance_shader_parameter(&"hurt", hurt)
	part_hand.set_instance_shader_parameter(&"smoulder", smoulder)
	# Its fire, up as it drinks and as it rears.
	_ember_flare = clampf(fed * 0.7 + _rear * 0.25, 0.0, 0.95)
	part(&"Ember").set_instance_shader_parameter(&"flare", _ember_flare)
	# A step per stride, faster the faster it goes, up to what can still be seen as
	# fingers; at rest, they still work.
	_walk += delta * minf(speed * (1.0 - SWING) / STEP + 0.35, MOST_STEPS)
	var rear_wanted := 1.0 if doing == &"tell" or doing == &"wake" or doing == &"wind_up" or doing == &"crowd" else (0.6 if doing == &"leap" else 0.0)
	_rear = lerpf(_rear, rear_wanted, 1.0 - exp(-14.0 * delta))
	_rest = lerpf(_rest, 1.0 if doing == &"rest" else 0.0, 1.0 - exp(-(3.5 if doing == &"rest" else 12.0) * delta))
	# A miss throws it flat, and it gathers itself up again.
	var slam := 1.0 - smoothstep(SLAM_FOR * 0.6, SLAM_FOR, _doing_for) if doing == &"missed" else 0.0
	var low := maxf(_rest * (1.0 - sin(_clock * 1.3) * 0.08), slam)
	var hand_at := Vector3(0.0, lerpf(PALM_HIGH + _rear * REAR + sin(_walk * TAU * 2.0) * 0.016, REST_HIGH, low) - 0.25, 0.22 - _rear * 0.1)
	# It never holds still: a palsy all the time, worse when it rears. Hungry.
	var shake := sin(_clock * 46.0) * 0.012 * rear_wanted + (sin(_clock * 23.0) * 0.012 + sin(_clock * 37.0) * 0.008) * (1.0 - _rest * 0.8)
	# Thrown, it goes over on its back, scrabbling at the air, and rights itself.
	var flung := doing == &"thrown" or _tumble > 0.0
	_flip = move_toward(_flip, 1.0 if flung else 0.0, delta * (6.0 if flung else 3.2))
	hand_at.y -= smoothstep(0.0, 1.0, _flip) * 0.1
	# It rolls with each step, and drops its head into a surge.
	var surging := smoothstep(2.4, 4.5, speed)
	# Its swing: rolled hard over as it rakes, its fingers shutting through it.
	_rake_roll = sin(clampf(_doing_for / RAKE_TAKES, 0.0, 1.0) * PI) * RAKE_ROLLS * _rake_side if doing == &"swipe" else 0.0
	_curl_shown = _spring(&"rake_curl", 1.0 if doing == &"swipe" else 0.0, 16.0, 0.8, delta)
	var roll := sin(_walk * TAU) * 0.1 + shake + smoothstep(0.0, 1.0, _flip) * PI + _jolt * JOLT_ROLL * _lies_side + _rake_roll
	var tilt := Basis(Vector3.RIGHT, (-TIP - _rear * 0.5 - surging * 0.16) * (1.0 - low * 0.9) + slam * 0.2) * Basis(Vector3.BACK, roll * (1.0 - _rest * 0.7))
	var hand_bone := _skeleton.find_bone("hand")
	var rest: Transform3D = _skeleton.get_bone_rest(hand_bone)
	_skeleton.set_bone_pose_position(hand_bone, hand_at)
	_skeleton.set_bone_pose_rotation(hand_bone, (tilt * rest.basis).get_rotation_quaternion())
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("arm_1"), _arm_turn("arm_1", ARM_OUT + sin(_clock * 2.3) * 0.05))
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("arm_2"), _arm_turn("arm_2", ARM_DOWN + sin(_clock * 3.1) * 0.08))
	var hand_pose := _skeleton.get_bone_global_pose(hand_bone)

	for i in FINGER_NAMES.size():
		var chain: Array[int] = _bones[i]
		var knuckle_rest: Transform3D = _skeleton.get_bone_rest(chain[0])
		var frame: Transform3D = hand_pose * knuckle_rest
		var target := _foot_for(i, knuckle_rest, hand_pose, doing)
		_tips[i] = target
		_reach_to(chain, frame, target)


## A value going after where it should be, with the weight to overshoot and settle.
func _spring(id: StringName, to: float, rate: float, damp: float, delta: float) -> float:
	if not _springs.has(id):
		_springs[id] = [to, 0.0]

	var state: Array = _springs[id]
	# (Past this, a step overshoots by more than it corrects, and it shakes itself apart.)
	var w := minf(TAU * rate, 0.8 / delta)
	state[1] += (w * w * (to - state[0]) - 2.0 * damp * w * state[1]) * delta
	state[0] += state[1] * delta
	return state[0]


## Gives a value a shove.
func _kick(id: StringName, by: float) -> void:
	if _springs.has(id):
		_springs[id][1] += by


## The face: it runs from pose to pose (POSES), with what each moment adds on top.
func _work_face(delta: float, doing: StringName, speed: float, fed: float) -> void:
	var pose: Dictionary = POSES.get(doing, POSES[&"rush"]) if doing != &"dead" else _dying_pose(POSES[&"dead"])
	var snap: float = pose["snap"]
	var surging := smoothstep(2.0, 3.8, speed) if doing == &"rush" else 0.0
	var nod_to: float = pose["nod"]
	var jaw_to: float = pose["jaw"]
	var back_to: float = pose["back"]
	var yaw_to := 0.0
	var roll_to := 0.0
	var hand_to: Vector3 = pose["hand"]
	var shut_to: float = pose["shut"]
	var jaw_rate := snap * 1.4
	_flip = move_toward(_flip, 1.0 if doing == &"thrown" else 0.0, delta * 5.0)

	match doing:
		&"rest":
			# Hung, swaying a little; and now and then something starts in it.
			nod_to += sin(_clock * 0.7) * 0.05
			yaw_to = sin(_clock * 0.43) * 0.16
			roll_to = sin(_clock * 0.31) * 0.14
			jaw_to += sin(_clock * 1.1) * 0.05
			_tic_in -= delta

			if _tic_in <= 0.0:
				_tic_in = _rng.randf_range(TIC_EVERY.x, TIC_EVERY.y)
				_kick(&"nod", TIC_KICK * _rng.randf_range(0.5, 1.0))
				_kick(&"yaw", TIC_KICK * _rng.randf_range(-1.0, 1.0))
				_kick(&"jaw", -TIC_KICK * 1.2)
		&"rush":
			# Hauling itself through the air: its head down into a surge, teeth going.
			nod_to -= surging * 0.16
			back_to -= surging * 0.08
			jaw_to += sin(_clock * 3.1) * 0.08 + surging * 0.3 + sin(_clock * 31.0) * 0.1 * surging
			roll_to = sin(_walk * TAU) * 0.09
			shut_to -= surging * 0.22
			hand_to.z -= surging * 0.14
		&"circle":
			# Waiting its turn, chewing on nothing, its eyes on you.
			jaw_to += abs(sin(_clock * 4.3)) * 0.2
			yaw_to = sin(_clock * 1.1) * 0.08
		&"tell":
			# It shakes harder the nearer it is to letting go.
			var build := minf(_doing_for / 0.6, 1.0)
			nod_to += sin(_clock * 37.0) * 0.022 * build
			yaw_to = sin(_clock * 29.0) * 0.024 * build
		&"missed":
			# The bite on nothing, and it opens, and looks for you.
			if _doing_for > BITE_HOLDS:
				jaw_to = 0.3 + sin(_clock * 14.0) * 0.12
				jaw_rate = 5.0

			if _doing_for > LOOKS_ABOUT:
				yaw_to = sin((_doing_for - LOOKS_ABOUT) * 7.0) * 0.42
				nod_to = -0.3

			jaw_rate = maxf(jaw_rate, 5.0)
		&"dead":
			roll_to = float(pose.get("roll", 0.0)) * _lies_side
			yaw_to = float(pose.get("yaw", 0.0)) * _lies_side
			var shaking: float = pose.get("shake", 0.0)
			nod_to += sin(_clock * 37.0) * 0.14 * shaking
			yaw_to += sin(_clock * 29.0) * 0.14 * shaking
			jaw_to += sin(_clock * 31.0) * float(pose.get("chatter", 0.0))

			# Limp: only the heat moves it now, drawing its fingers in, its jaw down.
			if pose.get("limp", false):
				jaw_to += _burn.charred() * HEAT_GAPES
				shut_to += _burn.charred() * HEAT_SHUTS
		&"thrown":
			# Knocked loose: its jaw flapping.
			jaw_to = 0.5 + sin(_clock * 21.0) * 0.4
			roll_to = sin(_clock * 11.0) * 0.5 * (1.0 - minf(_doing_for / 1.2, 1.0))

	# Flung, it goes over whatever it was doing, jaw flapping.
	if _tumble > 0.0:
		roll_to = sin(_tumble * PI) * 1.5 * _lies_side
		nod_to = 0.6 * _tumble
		jaw_to = 0.5 + sin(_clock * 21.0) * 0.4
		hand_to = hand_to.lerp(Vector3(0.48, 0.14, 0.18), _tumble)
		snap = maxf(snap, 7.0)

	_walk += delta * (PAW_RATE + surging * 1.8)
	_nod = _spring(&"nod", nod_to, snap, 0.55, delta)
	_back = _spring(&"back", back_to, snap, 0.6, delta)
	var lift := _spring(&"lift", pose["lift"], snap, 0.55, delta)
	var yaw := _spring(&"yaw", yaw_to, snap, 0.5, delta)
	var roll := _spring(&"roll", roll_to, snap, 0.5, delta)
	var jaw := _spring(&"jaw", clampf(jaw_to, 0.0, 1.0), jaw_rate, 0.75, delta)
	_rig.open_to(clampf(jaw, 0.0, 1.0), clampf(0.2 + sin(_clock * 2.6) * 0.15 + (jaw_to - 0.3) * 0.5, 0.0, 1.0))
	var skull: Node3D = _rig.skull()
	skull.rotation = Vector3(_nod, yaw, roll)
	skull.position = Vector3(0.0, lift, _back)
	var flare := clampf(fed * 0.7 + _rear * 0.08, 0.0, 0.95)
	_ember_flare = flare
	_rig.throat_to(clampf(fed * 0.35, 0.0, 0.5) if doing != &"dead" else float(pose.get("throat", 0.0)) * (1.0 - smoothstep(0.7, 1.3, _death_t)))
	_rig.paint(fed, hurt, smoulder)

	for mesh in _face_hands:
		mesh.set_instance_shader_parameter(&"fed", fed)
		mesh.set_instance_shader_parameter(&"hurt", hurt)
		mesh.set_instance_shader_parameter(&"smoulder", smoulder)

	if doing != &"dead":
		for ember in _embers:
			ember.set_instance_shader_parameter(&"flare", flare)

	for side in [-1.0, 1.0]:
		_work_hand(float(side), doing, pose, hand_to, shut_to, surging, snap, delta)


func _work_hand(side: float, doing: StringName, pose: Dictionary, hand_to: Vector3, shut_to: float, surging: float, snap: float, delta: float) -> void:
	# (The model's own root, which holds its size: the skeleton sits inside it.)
	var root: Node3D = _face_roots[0 if side > 0.0 else 1]
	var hand := hand_on(side)
	var seed := 0.0 if side > 0.0 else 2.3
	var id := "r" if side > 0.0 else "l"
	var wanted_hand: Vector3 = pose.get("hand_r" if side > 0.0 else "hand_l", hand_to)
	var at := Vector3(wanted_hand.x * side, wanted_hand.y, wanted_hand.z)
	var pawing := 1.0 if doing == &"rush" or doing == &"circle" else 0.0
	# Each reaches in turn, up and over, and pulls back and down, closing on the air.
	var paw := sin(_walk * TAU + (0.0 if side > 0.0 else PI))
	var over := cos(_walk * TAU + (0.0 if side > 0.0 else PI))
	at += Vector3(0.0, over * PAW_LIFT, -paw * PAW_REACH) * pawing
	# Limp at rest, they drift; awake, they tremble.
	var drift := 0.4 if doing == &"rest" else 1.0
	at += Vector3(sin(_clock * 3.1 * drift + seed) * 0.018, sin(_clock * 2.3 * drift + seed) * 0.022, sin(_clock * 4.3 * drift + seed) * 0.024)
	root.position = Vector3(_spring(StringName(id + "x"), at.x, snap, 0.6, delta), _spring(StringName(id + "y"), at.y, snap, 0.55, delta), _spring(StringName(id + "z"), at.z, snap, 0.55, delta))
	var pitch_to: float = float(pose.get("pitch_r" if side > 0.0 else "pitch_l", pose["pitch"])) + paw * 0.28 * pawing
	var pitch := _spring(StringName(id + "p"), pitch_to, snap, 0.6, delta)
	# Palms down and thrust ahead; up and out, showing you the palm, as it rears. Thrown, flung back.
	var inward := _spring(StringName(id + "i"), float(pose.get("inward", 0.0)), snap, 0.7, delta)
	var aim := Basis(Vector3.UP, side * (-0.16 + inward)) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, side * (0.3 + sin(_clock * 1.7 * drift + seed) * 0.07))
	root.basis = aim.scaled(Vector3.ONE * FACE_HAND_SIZE)
	_reach_shoulder(hand, side)
	var fan := _spring(StringName(id + "f"), float(pose["fan"]) * FACE_FAN, snap, 0.7, delta)
	var this_shut: float = pose.get("shut_r" if side > 0.0 else "shut_l", shut_to) if doing == &"dead" else shut_to
	var shut_base := _spring(StringName(id + "s"), this_shut + paw * 0.28 * pawing, snap * 1.3, 0.7, delta)
	var palsy_size := 0.05 if doing == &"rest" else (0.32 if doing == &"thrown" else (float(pose.get("shake", 0.0)) * 2.0 if doing == &"dead" else 0.17))

	for f in FINGER_NAMES.size():
		var finger_seed := float(f) * 1.9 + seed
		var palsy := sin(_clock * 13.0 * drift + finger_seed) * 0.6 + sin(_clock * 21.3 * drift + finger_seed * 2.0) * 0.4
		var jerk := sin(floor(_clock * 6.0 * drift + finger_seed) * 12.9898) * 0.5
		var shut := shut_base + (palsy + jerk) * palsy_size
		var out_of_middle := (float(f) - 1.5) * fan if f < 4 else fan * 2.2

		for k in range(1, 4):
			var bone := hand.find_bone("%s_%02d" % [FINGER_NAMES[f], k])
			var rest: Basis = hand.get_bone_rest(bone).basis
			var turn := Basis(Vector3.RIGHT, -shut * [0.7, 1.0, 1.25][k - 1])

			if k == 1:
				turn = Basis(Vector3.BACK, -out_of_middle * side) * turn

			hand.set_bone_pose_rotation(bone, (rest * turn).get_rotation_quaternion())


## The arm, from the wrist back to the base of the skull: a two-joint solve, its elbow out and
## up. Past what it can reach, it strains straight at it.
func _reach_shoulder(hand: Skeleton3D, side: float) -> void:
	var arm_1 := hand.find_bone("arm_1")
	var arm_2 := hand.find_bone("arm_2")
	var hand_pose: Transform3D = hand.get_bone_global_pose(hand.find_bone("hand"))
	var from: Vector3 = hand_pose * hand.get_bone_rest(arm_1).origin
	var target: Vector3 = hand.global_transform.affine_inverse() * (_rig.skull().global_transform * _shoulder(side))
	var way := target - from
	var far := clampf(way.length(), 0.02, ARM_BONE * 1.99)
	var along := way.normalized()
	# The pole, in the wrist's space: the elbow's way, as the body has it.
	var pole: Vector3 = (hand.global_basis.inverse() * (global_basis * Vector3(ELBOW_OUT.x * side, ELBOW_OUT.y, ELBOW_OUT.z))).normalized()
	var out := (pole - along * pole.dot(along)).normalized()
	var height := sqrt(maxf(ARM_BONE * ARM_BONE - far * far * 0.25, 0.0))
	var elbow := from + along * far * 0.5 + out * height
	var first := _aim_bone(hand, arm_1, hand_pose.basis, (elbow - from).normalized())
	_aim_bone(hand, arm_2, first, (from + along * far - elbow).normalized())


## Turns a bone so it runs along `wanted`, in the skeleton's space, the least it can from how
## it rests. Returns where that leaves it.
func _aim_bone(hand: Skeleton3D, bone: int, parent: Basis, wanted: Vector3) -> Basis:
	var rest: Basis = parent * hand.get_bone_rest(bone).basis
	var turn := Quaternion(rest.y.normalized(), wanted)
	var aimed := Basis(turn) * rest
	hand.set_bone_pose_rotation(bone, (parent.inverse() * aimed).get_rotation_quaternion())
	return aimed


func _arm_turn(bone_name: String, angle: float) -> Quaternion:
	var rest: Basis = _skeleton.get_bone_rest(_skeleton.find_bone(bone_name)).basis
	return (rest * Basis(Vector3.RIGHT, angle)).get_rotation_quaternion()


## Where a finger's tip wants to be, in the skeleton's space: stance, going back along
## the floor under it; swing, up and over to the next place.
func _foot_for(i: int, knuckle_rest: Transform3D, hand_pose: Transform3D, doing: StringName) -> Vector3:
	var knuckle: Vector3 = hand_pose * knuckle_rest.origin
	var side := signf(knuckle.x) if absf(knuckle.x) > 0.001 else 0.0
	var home := Vector3(knuckle.x + side * SPLAY[i], _floor_y, knuckle.z - REACH[i])

	if doing == &"rest":
		# Lying on them, curled under it; a finger gathers in and taps now and then.
		var tap: float = fposmod(_clock * 0.31 + float(i) * 0.37, 1.0)
		var lifted := sin(tap / 0.14 * PI) * 0.05 if tap < 0.14 else 0.0
		return Vector3(knuckle.x + side * SPLAY[i] * 0.6, _floor_y + lifted, knuckle.z - REACH[i] * 0.72 + sin(_clock * 1.1 + float(i) * 1.7) * 0.022 + lifted * 0.5)

	if doing == &"swipe":
		# Shut, one after another, through the rake.
		var shuts := smoothstep(0.0, 1.0, _doing_for / RAKE_TAKES * 1.6 - float(i) * 0.14)
		return Vector3(knuckle.x + side * SPLAY[i] * (1.0 - shuts) * 1.4, knuckle.y - 0.02 - shuts * 0.1, knuckle.z - float(REACH[i]) * lerpf(1.3, 0.3, shuts))

	if doing == &"tell" or doing == &"leap" or doing == &"on" or doing == &"wake" or doing == &"wind_up":
		# Up, spread, and hooked at you.
		return Vector3(knuckle.x * 1.5 + side * SPLAY[i], knuckle.y + 0.02 + sin(_clock * 30.0 + float(i)) * 0.012, knuckle.z - REACH[i] * 1.25)

	if doing == &"thrown" or _tumble > 0.0:
		return Vector3(knuckle.x * 1.3, knuckle.y - 0.08 + sin(_clock * 22.0 + float(i) * 1.7) * 0.05, knuckle.z - REACH[i] * 0.8)

	var phase: float = fposmod(_walk + float(PHASES[i]), 1.0)
	# No two steps alike: each sets down a little off from the last.
	var step_number: float = floor(_walk + float(PHASES[i])) + float(i) * 7.0
	home.x += sin(step_number * 12.9898) * 0.022
	home.z += sin(step_number * 78.233) * 0.03

	if phase < SWING:
		var u := phase / SWING
		home.z += lerpf(STEP * 0.5, -STEP * 0.5, u)
		home.y += sin(u * PI) * LIFT
	else:
		var u := (phase - SWING) / (1.0 - SWING)
		home.z += lerpf(-STEP * 0.5, STEP * 0.5, u)

	return home


## Bends a finger's three bones so its tip comes to `target`: a two-joint solve, its
## last bone following its middle one, the knuckle up, as a walking finger's is.
func _reach_to(chain: Array[int], frame: Transform3D, target: Vector3) -> void:
	var length_1: float = _skeleton.get_bone_rest(chain[1]).origin.length()
	var length_2: float = _skeleton.get_bone_rest(chain[2]).origin.length()
	var length_3 := length_2 * 0.82
	var lower := (length_2 + length_3) * 0.95
	var t: Vector3 = frame.affine_inverse() * target
	# In the bone's frame: +Y along it, +Z its back, +X what it bends about.
	var yaw := atan2(-t.x, t.y)
	var forward := Vector2(t.x, t.y).length()
	var reach := clampf(Vector2(forward, t.z).length(), 0.02, (length_1 + lower) * 0.995)
	var line := atan2(t.z, forward)
	var at_knuckle := acos(clampf((length_1 * length_1 + reach * reach - lower * lower) / (2.0 * length_1 * reach), -1.0, 1.0))
	var at_tip := acos(clampf((lower * lower + reach * reach - length_1 * length_1) / (2.0 * lower * reach), -1.0, 1.0))
	var bend := at_knuckle + at_tip
	var rest_1: Basis = _skeleton.get_bone_rest(chain[0]).basis
	_skeleton.set_bone_pose_rotation(chain[0], (rest_1 * Basis(Vector3.BACK, yaw) * Basis(Vector3.RIGHT, line + at_knuckle)).get_rotation_quaternion())
	var rest_2: Basis = _skeleton.get_bone_rest(chain[1]).basis
	_skeleton.set_bone_pose_rotation(chain[1], (rest_2 * Basis(Vector3.RIGHT, -bend * 0.62)).get_rotation_quaternion())
	var rest_3: Basis = _skeleton.get_bone_rest(chain[2]).basis
	_skeleton.set_bone_pose_rotation(chain[2], (rest_3 * Basis(Vector3.RIGHT, -bend * 0.38)).get_rotation_quaternion())


## How low its lowest fingertip is, above the floor it stands on.
func lowest_tip() -> float:
	var lowest := INF

	for i in FINGER_NAMES.size():
		var chain: Array[int] = _bones[i]
		var last := _skeleton.get_bone_global_pose(chain[2])
		var length := float(_skeleton.get_bone_rest(chain[2]).origin.length()) * 0.82
		lowest = minf(lowest, (last * Vector3(0.0, length, 0.0)).y)

	return lowest - _floor_y


## How high the palm stands off the floor.
func palm_height() -> float:
	return _skeleton.get_bone_global_pose(_skeleton.find_bone("hand")).origin.y - _floor_y


## `source`: what did it. Glass spills its fire; for the rest, for now, blood.
func struck(point: Vector3, direction: Vector3, result: StringName, source: StringName = &"") -> void:
	hurt = 1.0 if result != &"resisted" else 0.25

	if source == &"obsidian":
		_last_wound = &"fire"
		AnimaSpillScript.at(self, point - Vector3.UP * 0.04, -direction.normalized())
		return

	_last_wound = &"blood"
	Fx.blood(self, point, -direction.normalized(), 0.2 if result == &"resisted" else 0.7)


## What its last wound let out.
func last_wound() -> StringName:
	return _last_wound


## Flung, it goes over, flailing, and rights itself.
func tumble(_way: Vector3) -> void:
	_tumble = 1.0
	_lies_side = -1.0 if _rng.randf() < 0.5 else 1.0


## A Shard through it: knocked over a little, and it comes back.
func jolt(_way: Vector3) -> void:
	_jolt = 1.0
	_lies_side = -1.0 if _rng.randf() < 0.5 else 1.0
	_kick(&"nod", 3.0)
	_kick(&"roll", 4.0 * _lies_side)
	_kick(&"jaw", 4.0)


## How far over its swing has it rolled (radians).
func rake_roll() -> float:
	return _rake_roll


## The face: how far out from its middle its hands are, at most; below nothing, they have crossed.
func hand_across() -> float:
	return minf(_face_roots[0].position.x, -_face_roots[1].position.x)


## How much of a knock is left, 0..1.
func jolting() -> float:
	return _jolt


## How much of a tumble is left, 0..1.
func tumbling() -> float:
	return _tumble


## What is burning it down, once it is dead.
func burning() -> Node3D:
	return _burn


## The face: how far ahead its hand on that side is.
func hand_ahead(side: float) -> float:
	return -_face_roots[0 if side > 0.0 else 1].position.z


## The face: how far the tips of its hands' middle fingers are from the middle of its skull.
func fingers_from_skull() -> float:
	var skull: Vector3 = _rig.skull().global_position
	var total := 0.0

	for side in [1.0, -1.0]:
		var hand := hand_on(side)
		total += (hand.global_transform * hand.get_bone_global_pose(hand.find_bone("middle_03")).origin).distance_to(skull)

	return total * 0.5


## The hands, dying: how far its fingers are drawn in, 0..1.
func finger_curl() -> float:
	return _curl_shown


## Dead: it leaves the monster (which is out of play) for `world`, plays out its last moments
## (`kind` of its form's, or any), goes limp, and its own fire burns it down (AnimaBurn.gd). It
## frees itself when it has gone.
func burn_away(world: Node, push: Vector3, you: Node3D = null, kind := -1) -> void:
	if not DEATHS.has(form):
		queue_free()
		return

	reparent(world)
	reset_physics_interpolation()
	add_to_group(&"anima_ash")
	visible = true
	_you = you
	var deaths: Array = DEATHS[form]
	_death = deaths[kind if kind >= 0 and kind < deaths.size() else _rng.randi() % deaths.size()]
	_lies_side = -1.0 if _rng.randf() < 0.5 else 1.0
	_doing = &"dead"
	_falling = Vector3(push.x, maxf(push.y, 0.0), push.z) * 0.45
	_floor_at = _find_floor()
	var meshes: Array = []
	var embers: Array[MeshInstance3D] = []
	var from: Vector3

	if form == &"hands":
		meshes.append([part(&"Hand"), 0.0])
		embers.append(part(&"Ember"))
		from = _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("hand")).origin
	elif form == &"torso":
		meshes = _mouth.start_dying(_rng.randi())
		from = _mouth.global_position
	else:
		for mesh in _face_hands:
			meshes.append([mesh, 0.0])

		embers = _embers.duplicate()
		meshes.append([part(&"Skull"), SKULL_LATE])
		meshes.append([part(&"Jaw"), JAW_LATE])
		meshes.append([part(&"Tongue"), JAW_LATE])
		meshes.append([part(&"Gullet"), JAW_LATE])
		from = _rig.skull().global_transform * Vector3(SKULL_FLAMES[0][0])

	_burn = AnimaBurnScript.new()
	add_child(_burn)
	_burn.start({
		"meshes": meshes, "embers": embers, "spots": _flame_spots(), "place": _flame_place,
		"floor": _floor_at, "size": float(BURNS_SIZE[form]), "seed": hash(global_position),
		"ignites": float(_death["ignites"]), "crumbles": float(_death["crumbles"]), "from": from,
	})
	set_physics_process(true)


## What it should be doing, this moment of its last: each beat up to now, laid over `base`.
func _dying_pose(base: Dictionary) -> Dictionary:
	var pose := base.duplicate()

	for beat: Dictionary in _death["beats"]:
		if float(beat["at"]) <= _death_t:
			pose.merge(beat, true)

	return pose


func _physics_process(delta: float) -> void:
	if _burn == null:
		return

	_death_t += delta
	var beats: Array = _death["beats"]

	while _beats_said < beats.size() and float(beats[_beats_said]["at"]) <= _death_t:
		var said: Variant = beats[_beats_said].get("say")
		_beats_said += 1

		if said != null:
			Sfx.play(self, said[0], global_position, said[1], said[2])

	var pose := _dying_pose(POSES[&"dead"] if form == &"face" else (MOUTH_DYING if form == &"torso" else HAND_DYING))

	# While there is anything in it, it trembles. After that, nothing moves it of itself.
	if float(pose.get("shake", 0.0)) > 0.0 or float(pose.get("chatter", 0.0)) > 0.0 or float(pose.get("walk", 0.0)) > 0.0:
		_clock += delta

	_fall(delta, pose)

	if not pose.get("limp", false) and form != &"torso":
		_face_you(delta)

	if form == &"hands":
		_die_hand(delta, pose)
	elif form == &"torso":
		_die_mouth(delta, pose)
	else:
		_work_face(delta, &"dead", 0.0, fed_shown)

	_ember_flare = _burn.flare()


## The mouth in its last moments: told by the beats, what it does is its own (AnimaMouth.gd).
func _die_mouth(delta: float, pose: Dictionary) -> void:
	var snap: float = float(pose.get("snap", 3.0))
	_mouth.ribs_to(clampf(_spring(&"mouth_ribs", float(pose["ribs"]), snap, 0.8, delta), 0.0, 1.15))
	_reared = maxf(_spring(&"mouth_rear", float(pose["rear"]), snap, 0.7, delta), 0.0)
	var swell: float = _spring(&"mouth_swell", float(pose["swell"]), snap, 0.75, delta)
	var slump: float = clampf(_spring(&"mouth_slump", float(pose["slump"]), snap, 1.0, delta), 0.0, 1.0)
	var grab: float = clampf(_spring(&"mouth_grab", float(pose["grab"]), 3.0, 0.9, delta), 0.0, 1.0)
	var grab_at: Vector3 = _you.global_position + Vector3.UP * 0.15 if is_instance_valid(_you) else global_position
	var dragged := float(pose.get("drag", 0.0))
	var going: Vector3 = (grab_at - global_position) * Vector3(1.0, 0.0, 1.0)
	_mouth.tick_dying(delta, dragged, going.normalized() * dragged if going.length() > 0.01 else Vector3.ZERO, bool(pose["digs"]), grab, grab_at, swell, slump, pose, _floor_at, _burn.flare())
	_mouth.rotation = Vector3(_reared * MOUTH_REARS - _mouth.rock(), 0.0, _mouth.roll())
	_mouth.position = Vector3(0.0, _mouth.heave() + _reared * MOUTH_RISES, 0.0)


func _face_you(delta: float) -> void:
	if not is_instance_valid(_you):
		return

	var way := _you.global_position - global_position
	way.y = 0.0

	if way.length() > 0.05:
		global_basis = global_basis.orthonormalized().slerp(Basis.looking_at(way.normalized(), Vector3.UP), 1.0 - exp(-8.0 * delta))


## A hand in its last moments: its palm and tilt told by the beats, each finger going for where
## the beats say (reached out, or drawn in under the palm), thrashing while there is anything
## in it, each in its own time once there isn't.
func _die_hand(delta: float, pose: Dictionary) -> void:
	var snap: float = pose["snap"]
	var low := clampf(_spring(&"d_low", pose["low"], snap, 0.7, delta), 0.0, 1.0)
	var rear := _spring(&"d_rear", pose["rear"], snap, 0.6, delta)
	var flip := clampf(_spring(&"d_flip", pose["flip"], snap, 0.8, delta), 0.0, 1.0)
	var up := _spring(&"d_up", pose["up"], snap * 1.4, 0.5, delta)
	var roll := _spring(&"d_roll", float(pose["roll"]) * _lies_side, snap, 0.5, delta)
	var limp: bool = pose.get("limp", false)
	var curl_to: float = float(pose["curl"]) + (_burn.charred() * HEAT_CURLS if limp else 0.0)
	var curl := clampf(_spring(&"d_curl", curl_to, snap, 0.7, delta), 0.0, 1.0)
	var open := _spring(&"d_open", pose["open"], snap, 0.7, delta)
	var walk: float = pose["walk"]
	var shaking: float = pose["shake"]
	_flip = flip
	_curl_shown = curl
	_walk += delta * walk
	var hand_at := Vector3(0.0, lerpf(PALM_HIGH + sin(_walk * TAU * 2.0) * 0.016, DEAD_HIGH, low) + rear * REAR_UP + up + flip * 0.03 - 0.25, 0.22 - rear * 0.1)
	var tilt := Basis(Vector3.RIGHT, lerpf(-TIP, 0.0, low) + rear * REAR_TURN) * Basis(Vector3.BACK, roll + flip * PI + (sin(_walk * TAU) * 0.1 if walk > 0.0 else 0.0))
	var hand_bone := _skeleton.find_bone("hand")
	var rest: Transform3D = _skeleton.get_bone_rest(hand_bone)
	_skeleton.set_bone_pose_position(hand_bone, hand_at)
	_skeleton.set_bone_pose_rotation(hand_bone, (tilt * rest.basis).get_rotation_quaternion())
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("arm_1"), _arm_turn("arm_1", lerpf(ARM_OUT, -0.08, low) + sin(_clock * 19.0) * 0.1 * shaking))
	_skeleton.set_bone_pose_rotation(_skeleton.find_bone("arm_2"), _arm_turn("arm_2", lerpf(ARM_DOWN, -0.05, low) + sin(_clock * 23.0) * 0.1 * shaking))
	var hand_pose := _skeleton.get_bone_global_pose(hand_bone)

	for i in FINGER_NAMES.size():
		var chain: Array[int] = _bones[i]
		var knuckle_rest: Transform3D = _skeleton.get_bone_rest(chain[0])
		var frame: Transform3D = hand_pose * knuckle_rest
		var knuckle: Vector3 = hand_pose * knuckle_rest.origin
		var across: float = (tilt.inverse() * (knuckle - hand_at)).x
		var side := signf(across) if absf(across) > 0.001 else 0.0
		var shake_z := sin(_clock * 34.0 + float(i) * 1.7) * SCRABBLES * shaking
		var shake_y := cos(_clock * 27.0 + float(i) * 2.9) * SCRABBLES * 1.3 * shaking
		var target: Vector3

		if walk > 0.0:
			target = _foot_for(i, knuckle_rest, hand_pose, &"rush")
		else:
			target = knuckle + tilt * Vector3(side * SPLAY[i] * (1.0 + open) * (1.0 - curl * 0.8), -curl * CURL_IN + shake_y, -float(REACH[i]) * lerpf(1.45 + open * 0.3, 0.22, curl) + shake_z)
			# What lies on the floor stays out of it.
			target.y = maxf(target.y, _floor_y + 0.012)

			if flip < 0.5 and rear < 0.2 and low > 0.5:
				target.y = lerpf(target.y, _floor_y + 0.012, (low - 0.5) * 2.0 * (1.0 - curl * 0.6))

		var quick := FINGERS_QUICK if not limp else FINGERS_SLACK * (0.55 + float(i) * 0.28)
		target = _tips[i].lerp(target, 1.0 - exp(-quick * delta))
		_tips[i] = target
		_reach_to(chain, frame, target)


func _fall(delta: float, pose: Dictionary) -> void:
	var lies_at: float = _floor_at + float(LIES_AT[form])
	_falling.x = move_toward(_falling.x, 0.0, PUSH_DIES * delta)
	_falling.z = move_toward(_falling.z, 0.0, PUSH_DIES * delta)
	var next := global_position

	if not _landed and (form == &"hands" or pose.get("falls", false)):
		_falling.y -= FALLS * delta
		next.y += _falling.y * delta

		if next.y <= lies_at:
			next.y = lies_at
			_landed = true
			_kick(&"nod", -2.4)
			_kick(&"jaw", 3.0)
			Fx.dust(self, Vector3(next.x, _floor_at, next.z), Vector3.UP, 0.5)
			Sfx.play(self, &"flesh", next, -14.0, 0.6)

	var sideways := Vector3(_falling.x, 0.0, _falling.z)
	var drag: float = pose.get("drag", 0.0)

	if drag > 0.0 and is_instance_valid(_you):
		var way := _you.global_position - global_position
		way.y = 0.0

		if way.length() > 0.9:
			sideways += way.normalized() * drag

	if sideways.length() > 0.001 and not _wall_in_the_way(sideways * delta):
		next += sideways * delta

	global_position = next


func _wall_in_the_way(step: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position, global_position + step * 3.0, 1)
	return not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _find_floor() -> float:
	var from := global_position + Vector3.UP * 0.2
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * FLOOR_LOOK, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return float(hit["position"].y) if not hit.is_empty() else global_position.y - float(LIES_AT[form])


## Where its flames stand, listed: [a skeleton, its bone, how far along it, how tall], or [a
## place on its skull, how tall].
func _flame_spots() -> Array:
	if form == &"torso":
		return _mouth.flame_spots(FINGER_FLAME)

	var spots: Array = []
	var hands: Array = [_skeleton] if form == &"hands" else [_right_hand, _left_hand]

	for hand in hands:
		for name_of in FINGER_NAMES:
			spots.append([hand, "%s_02" % name_of, 0.0, FINGER_FLAME])

		for spot in HAND_FLAMES:
			spots.append([hand, spot[0], spot[1], spot[2]])

	if form == &"face":
		spots.append_array(SKULL_FLAMES)

	return spots


## Where that flame stands, this moment, in the world.
func _flame_place(spot: Array) -> Vector3:
	# (On the mouth, or on what has got out of it, wherever that has gone.)
	if spot.size() == 3:
		return spot[0].global_transform * Vector3(spot[1]) if is_instance_valid(spot[0]) else global_position

	if spot.size() == 2:
		return _rig.skull().global_transform * Vector3(spot[0])

	var hand: Skeleton3D = spot[0]
	return hand.global_transform * (hand.get_bone_global_pose(hand.find_bone(spot[1])) * Vector3(0.0, spot[2], 0.0))
