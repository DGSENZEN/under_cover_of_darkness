extends Node3D
## A person: one of the Universal Base Characters, dressed from the wardrobe
## (a guard) or in a painted outfit (your arms), moved by
## the Universal Animation Library (both Quaternius, CC0). Guards are made of
## this, and so are your own arms. Presentation only: nothing here decides
## anything.
##
##   var man := Humanoid.new()
##   man.build(&"swordsman")            # outfit (tools/dress_characters.py)
##   add_child(man)
##   man.set_motion(velocity, fighting, delta) # every frame: walking, running
##   man.show_action(&"Sword_Attack", t)      # every frame an action shows
##   man.clear_action()                       # back to walking
##   man.play_once(&"Death01")                # plays itself out, and stays
##   man.add_ragdoll()                        # once, straight after build
##   man.go_limp(velocity)                    # physics has him (Ragdoll.gd)
##
## Walking blends idle, walk, jog and sprint by speed, played at the pace the
## feet need, backwards when he backs off; stepping sideways, his hips turn
## to the way he goes while his chest stays on his enemy (Posture.gd). In a
## fight his arms keep his guard up while his legs walk. Over it, two action
## slots crossfade: an attack, a guard, a flinch, a fall. An action is shown
## at whatever time the caller asks for, so a swing's frames follow the
## fight's own clock: the blade meets you when the guard's code says it does,
## whatever the animation's own pace.

const Layers := preload("res://scripts/Visual/Layers.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const PostureScript := preload("res://scripts/Visual/Posture.gd")
const RagdollScript := preload("res://scripts/Visual/Ragdoll.gd")
const SeveredScript := preload("res://scripts/Visual/Severed.gd")
const SeveredPartScript := preload("res://scripts/Visual/SeveredPart.gd")
const WardrobeScript := preload("res://scripts/Visual/Wardrobe.gd")
const ClothScript := preload("res://scripts/Visual/Cloth.gd")
const ClothResetScript := preload("res://scripts/Visual/ClothReset.gd")

const MALE_SCENE := "res://assets/characters/base/Superhero_Male_FullBody.gltf"
const FEMALE_SCENE := "res://assets/characters/base/Superhero_Female_FullBody.gltf"
const LIBRARIES := [
	"res://assets/characters/animations/UAL1_Standard.glb",
	"res://assets/characters/animations/UAL2_Standard.glb",
]
const OUTFITS := "res://assets/characters/outfits/T_%s.png"

## How fast each walking cycle covers the ground (m/s), measured off the
## animations: playback is scaled so the feet do not slide.
const WALK_SPEED := 1.1
const JOG_SPEED := 3.2
const SPRINT_SPEED := 4.4
## Animations that should loop but were not named so.
const LOOPED := [&"Sword_Idle"]
## Bones the legs keep while the arms hold a guard: the rest follow the arms.
const LEGS := [&"root", &"pelvis", &"spine_01", &"thigh_l", &"calf_l", &"foot_l", &"ball_l",
	&"thigh_r", &"calf_r", &"foot_r", &"ball_r"]
## Something held through the fist (a torch's stick, a lantern's bail, a
## haft), for attach on "hand_r" / "hand_l": its +Y along the thumb side,
## centred in the curled fingers. In a hand bone's own space +Y runs along
## the fingers and +Z out of the thumb side; the palm is -X on the right hand
## and +X on the left.
const FIST_R := Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)), Vector3(-0.03, 0.08, 0.0))
const FIST_L := Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)), Vector3(0.03, 0.08, 0.0))

static var _library: AnimationLibrary = null
static var _scenes := {}
static var _materials := {}

var model: Node3D
var skeleton: Skeleton3D
var body: MeshInstance3D
var mixer: AnimationTree
var player: AnimationPlayer
## Head, hips and a kicking leg laid over the animation.
var posture: SkeletonModifier3D
## The body of bones he falls as (Ragdoll.gd), once add_ragdoll has made it.
var ragdoll: Node
## What has been cut off him (Severed.gd), once anything has.
var severed: Node
## What the wardrobe rolled for him (dress: Wardrobe.roll, then the hair
## rules), empty if he was not dressed from it.
var look := {}
## The metal he wears as part of his clothes, by the bone it covers (a
## mail coif on his neck and head): bone -> the mesh.
var metal := {}
## What swings on him (Cloth.gd), if he wears any cloth that does.
var cloth: Node

var _root: AnimationNodeBlendTree
## Which action slot is in front (0 or 1), what each holds, and the blend.
var _front := 0
var _held: Array[StringName] = [&"", &""]
var _cross := 0.0
var _action := 0.0
var _action_goal := 0.0
var _fade_in := 0.08
var _fade_out := 0.16
var _fighting := 0.0
var _fighting_idle: StringName = &"Sword_Idle"
## How much his legs run under whatever he is doing (set_leg_drive).
var _legs := 0.0
var _legs_goal := 0.0
## The upper-body layer (show_upper): how much of it shows, toward what, and
## how fast it comes and goes.
var _upper := 0.0
var _upper_goal := 0.0
var _upper_in := 0.15
var _upper_out := 0.25
var _upper_clip: StringName = &""
## His stride at a walk: under 1, short quick steps; over 1, long ones (the
## pace the walk is played at follows). At a jog and faster, everyone's is 1.
var stride := 1.0
## An action playing itself out (play_once), how far in, and how fast.
var _once: StringName = &""
var _once_time := 0.0
var _once_speed := 1.0


## The whole library, both halves, loaded once for everyone.
static func library() -> AnimationLibrary:
	if _library != null:
		return _library

	_library = AnimationLibrary.new()

	for path in LIBRARIES:
		var part: AnimationLibrary = load(path)

		for name in part.get_animation_list():
			if not _library.has_animation(name):
				_library.add_animation(name, part.get_animation(name))

	for name in LOOPED:
		if _library.has_animation(name):
			var looped := _library.get_animation(name).duplicate() as Animation
			looped.loop_mode = Animation.LOOP_LINEAR
			_library.remove_animation(name)
			_library.add_animation(name, looped)

	return _library


static func outfit_material(outfit: StringName) -> StandardMaterial3D:
	if _materials.has(outfit):
		return _materials[outfit]

	var material := StandardMaterial3D.new()
	material.albedo_texture = load(OUTFITS % outfit)
	material.roughness = 0.85
	material.metallic = 0.0
	_materials[outfit] = material
	return material


## Builds the person: `outfit` is one of dress_characters.py's.
## `fighting_idle` is how he stands in a fight (a crossbowman: Pistol_Idle).
func build(outfit: StringName, female := false, fighting_idle: StringName = &"Sword_Idle") -> void:
	_fighting_idle = fighting_idle
	var path := FEMALE_SCENE if female else MALE_SCENE

	if not _scenes.has(path):
		_scenes[path] = load(path)

	# Posed every drawn frame, not every physics tick: drawn as posed, riding
	# whatever carries it (a guard, a body, the player's view).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	model = (_scenes[path] as PackedScene).instantiate()
	model.name = "Model"
	add_child(model)
	# The models look down +Z; everything in the game looks down -Z.
	model.rotation.y = PI
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D

	for child in skeleton.get_children():
		var mesh := child as MeshInstance3D

		if mesh == null:
			continue

		mesh.layers = Layers.ACTORS

		if body == null or mesh.mesh.get_surface_count() > 0 and _vertex_count(mesh) > _vertex_count(body):
			body = mesh

	if outfit != &"" and ResourceLoader.exists(OUTFITS % outfit):
		body.material_override = outfit_material(outfit)

	player = AnimationPlayer.new()
	player.name = "Anim"
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library(&"", library())

	mixer = AnimationTree.new()
	mixer.name = "Mixer"
	model.add_child(mixer)
	mixer.anim_player = mixer.get_path_to(player)
	_root = _build_tree()
	mixer.tree_root = _root
	mixer.active = true

	posture = PostureScript.new()
	posture.name = "Posture"
	posture.set("man", self)
	skeleton.add_child(posture)


static func _vertex_count(mesh: MeshInstance3D) -> int:
	if mesh == null or mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
		return 0

	return (mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func _build_tree() -> AnimationNodeBlendTree:
	var root := AnimationNodeBlendTree.new()
	root.add_node(&"relaxed", _walking(&"Idle"), Vector2(0, 0))
	root.add_node(&"fighting", _walking(_fighting_idle), Vector2(0, 200))
	# In a fight the arms hold the guard whatever the legs are doing.
	var guard_clip := AnimationNodeAnimation.new()
	guard_clip.animation = _fighting_idle
	root.add_node(&"guard_pose", guard_clip, Vector2(0, 320))
	var arms := AnimationNodeBlend2.new()
	arms.filter_enabled = true

	for path in _arm_tracks(_fighting_idle):
		arms.set_filter_path(path, true)

	root.add_node(&"arms", arms, Vector2(200, 250))
	root.connect_node(&"arms", 0, &"fighting")
	root.connect_node(&"arms", 1, &"guard_pose")
	var stance := AnimationNodeBlend2.new()
	root.add_node(&"stance", stance, Vector2(250, 100))
	root.connect_node(&"stance", 0, &"relaxed")
	root.connect_node(&"stance", 1, &"arms")
	root.add_node(&"pace", AnimationNodeTimeScale.new(), Vector2(450, 100))
	root.connect_node(&"pace", 0, &"stance")

	for slot in [&"a", &"b"]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = &"Idle"
		root.add_node(StringName("clip_" + slot), clip, Vector2(0, 400 if slot == &"a" else 550))
		root.add_node(StringName("seek_" + slot), AnimationNodeTimeSeek.new(), Vector2(200, 400 if slot == &"a" else 550))
		root.connect_node(StringName("seek_" + slot), 0, StringName("clip_" + slot))

	root.add_node(&"cross", AnimationNodeBlend2.new(), Vector2(400, 475))
	root.connect_node(&"cross", 0, &"seek_a")
	root.connect_node(&"cross", 1, &"seek_b")
	root.add_node(&"act", AnimationNodeBlend2.new(), Vector2(650, 250))
	root.connect_node(&"act", 0, &"pace")
	root.connect_node(&"act", 1, &"cross")
	# His legs, run under a blow thrown on the move (a lunge, a charge): the
	# feet keep up with the ground instead of sliding over it. A cycle of
	# their own, kept in step with the walking one.
	root.add_node(&"legs_walk", _walking(_fighting_idle), Vector2(450, 700))
	root.add_node(&"legs_pace", AnimationNodeTimeScale.new(), Vector2(650, 700))
	root.connect_node(&"legs_pace", 0, &"legs_walk")
	var legs := AnimationNodeBlend2.new()
	legs.filter_enabled = true

	for path in _tracks_of(&"Jog_Fwd", LEGS.filter(func(bone): return bone != &"spine_01")):
		legs.set_filter_path(path, true)

	root.add_node(&"legs", legs, Vector2(850, 400))
	root.connect_node(&"legs", 0, &"act")
	root.connect_node(&"legs", 1, &"legs_pace")
	# Over all of it, his arms, chest and head alone (show_upper): a gesture,
	# a drink, hands held to the fire, whatever the legs are doing.
	var upper_clip := AnimationNodeAnimation.new()
	upper_clip.animation = &"Idle"
	root.add_node(&"upper_clip", upper_clip, Vector2(850, 650))
	root.add_node(&"upper_seek", AnimationNodeTimeSeek.new(), Vector2(1050, 650))
	root.connect_node(&"upper_seek", 0, &"upper_clip")
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true

	for path in _arm_tracks(&"Idle"):
		upper.set_filter_path(path, true)

	root.add_node(&"upper", upper, Vector2(1250, 450))
	root.connect_node(&"upper", 0, &"legs")
	root.connect_node(&"upper", 1, &"upper_seek")
	root.connect_node(&"output", 0, &"upper")
	return root


## The tracks of `animation` that move any of `bones`.
static func _tracks_of(animation: StringName, bones: Array) -> Array[NodePath]:
	var paths: Array[NodePath] = []

	if not library().has_animation(animation):
		return paths

	var clip := library().get_animation(animation)

	for i in range(clip.get_track_count()):
		var path := clip.track_get_path(i)

		if path.get_subname_count() > 0 and StringName(path.get_subname(0)) in bones:
			paths.append(path)

	return paths


## The tracks of `animation` that move the upper body.
static func _arm_tracks(animation: StringName) -> Array[NodePath]:
	var paths: Array[NodePath] = []

	if not library().has_animation(animation):
		return paths

	var clip := library().get_animation(animation)

	for i in range(clip.get_track_count()):
		var path := clip.track_get_path(i)

		if path.get_subname_count() > 0 and not (StringName(path.get_subname(0)) in LEGS):
			paths.append(path)

	return paths


static func _walking(idle: StringName) -> AnimationNodeBlendSpace1D:
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = 6.0

	for point in [[idle, 0.0], [&"Walk", WALK_SPEED], [&"Jog_Fwd", JOG_SPEED], [&"Sprint", SPRINT_SPEED]]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = point[0]
		space.add_blend_point(clip, point[1])

	return space


# ---------------------------------------------------------------------------
# Driving it
# ---------------------------------------------------------------------------

## Walking, running or standing, ready to fight or not. `velocity` is in his
## own space (he looks down -Z), at his own size. Call every frame.
func set_motion(velocity: Vector3, fighting: bool, delta: float) -> void:
	if mixer == null:
		return

	_fighting = move_toward(_fighting, 1.0 if fighting else 0.0, delta * 4.0)
	var speed := Vector2(velocity.x, velocity.z).length()
	var position := clampf(speed, 0.0, 6.0)
	# Which way the feet go from where he faces, positive to his left. Going
	# backwards, the cycle runs in reverse; sideways, the hips turn to it.
	var reverse := 1.0
	var legs := 0.0

	if speed > 0.3:
		var angle := atan2(-velocity.x, -velocity.z)

		if absf(angle) > deg_to_rad(110.0):
			reverse = -1.0
			angle = wrapf(angle + PI, -PI, PI)

		legs = clampf(angle, -1.2, 1.2)

	posture.set("hips_yaw", legs)
	mixer.set(&"parameters/relaxed/blend_position", position)
	mixer.set(&"parameters/fighting/blend_position", position)
	mixer.set(&"parameters/legs_walk/blend_position", position)
	mixer.set(&"parameters/stance/blend_amount", _fighting)
	# The guard held up at a walk, loosened at a sprint.
	mixer.set(&"parameters/arms/blend_amount", lerpf(1.0, 0.55, clampf((position - JOG_SPEED) / (SPRINT_SPEED - JOG_SPEED), 0.0, 1.0)))
	# Played at the pace the feet need, between the cycles it blends.
	var natural := WALK_SPEED

	if position > JOG_SPEED:
		natural = lerpf(JOG_SPEED, SPRINT_SPEED, clampf((position - JOG_SPEED) / (SPRINT_SPEED - JOG_SPEED), 0.0, 1.0))
	elif position > WALK_SPEED:
		natural = lerpf(WALK_SPEED, JOG_SPEED, (position - WALK_SPEED) / (JOG_SPEED - WALK_SPEED))

	# His own stride is his walk's; at a jog and faster every man runs alike.
	var own_stride := lerpf(maxf(stride, 0.1), 1.0, clampf((position - WALK_SPEED) / (JOG_SPEED - WALK_SPEED), 0.0, 1.0))
	var pace := 1.0 if position < 0.3 else clampf(position / (natural * own_stride), 0.6, 1.6) * reverse
	mixer.set(&"parameters/pace/scale", pace)
	mixer.set(&"parameters/legs_pace/scale", pace)


## How much his legs run (0..1) under the action he is showing: a blow
## thrown on the move.
func set_leg_drive(amount: float) -> void:
	_legs_goal = clampf(amount, 0.0, 1.0)


## Shows `animation` at `time` on his arms, chest and head only, over
## whatever the rest of him does. Call every frame it lasts; `weight` below 1
## keeps some of what was under it.
func show_upper(animation: StringName, time: float, fade_in := 0.15, weight := 0.9) -> void:
	if mixer == null or not library().has_animation(animation):
		return

	if _upper_clip != animation:
		(_root.get_node(&"upper_clip") as AnimationNodeAnimation).animation = animation
		_upper_clip = animation

	_upper_in = fade_in
	_upper_goal = clampf(weight, 0.0, 1.0)
	mixer.set(&"parameters/upper_seek/seek_request", maxf(time, 0.0))


## His upper body back to the rest of him, over `fade` seconds.
func clear_upper(fade := 0.25) -> void:
	_upper_goal = 0.0
	_upper_out = fade


## How much the upper layer shows now (0..1).
func upper_weight() -> float:
	return _upper


## The walk he walks at his ease (the captain's formal step).
func set_walk_clip(clip: StringName) -> void:
	if _root == null or not library().has_animation(clip):
		return

	var space := _root.get_node(&"relaxed") as AnimationNodeBlendSpace1D
	(space.get_blend_point_node(1) as AnimationNodeAnimation).animation = clip


## Where his eyes are turned: radians, positive to his left.
func turn_head(yaw: float) -> void:
	if posture != null:
		posture.set("head_yaw", yaw)


## His head tipped up (positive) or down: radians.
func pitch_head(pitch: float) -> void:
	if posture != null:
		posture.set("head_pitch", pitch)


## Leaning back at the waist (a breath in, asleep in his seat): radians.
func lean_back(angle: float) -> void:
	if posture != null:
		posture.set("lean", angle)


## A kick laid over whatever he is doing: `knee` 0..1 up, `extend` 0..1 out.
func kick_pose(knee: float, extend: float) -> void:
	if posture != null:
		posture.set("knee", knee)
		posture.set("extend", extend)


## Plays `animation` through once at `speed`, then holds its last frame. For
## a fall: nothing else needs to drive it.
func play_once(animation: StringName, speed := 1.0, from := 0.0) -> void:
	_once = animation
	_once_speed = speed
	_once_time = from
	kick_pose(0.0, 0.0)
	turn_head(0.0)

	if posture != null:
		posture.set("hips_yaw", 0.0)


## Shows `animation` at `time` (seconds into it) over the walking. Call every
## frame the action lasts; a new animation crossfades from the last. `weight`
## below 1 keeps some of his stance under it: the same move, more restrained.
func show_action(animation: StringName, time: float, fade_in := 0.08, weight := 1.0) -> void:
	if mixer == null or not library().has_animation(animation):
		return

	if _held[_front] != animation:
		# Into the other slot, and fade across to it.
		var back := 1 - _front

		if _held[back] != animation:
			(_root.get_node(StringName("clip_" + ("a" if back == 0 else "b"))) as AnimationNodeAnimation).animation = animation
			_held[back] = animation

		_front = back

	_fade_in = fade_in
	_action_goal = clampf(weight, 0.0, 1.0)
	var slot := "a" if _front == 0 else "b"
	mixer.set(StringName("parameters/seek_" + slot + "/seek_request"), maxf(time, 0.0))


## Back to walking, fading the action out over `fade` seconds.
func clear_action(fade := 0.16) -> void:
	_action_goal = 0.0
	_fade_out = fade


func is_acting() -> bool:
	return _action > 0.01


func action_length(animation: StringName) -> float:
	return library().get_animation(animation).length if library().has_animation(animation) else 0.0


func _process(delta: float) -> void:
	if mixer == null:
		return

	if _once != &"":
		_once_time += delta * _once_speed
		var end := action_length(_once) - 0.02
		show_action(_once, minf(_once_time, end), 0.12)

		if _once_time > end + 0.5 and _action >= 1.0 and is_equal_approx(_cross, float(_front)):
			# Lying still for good: his pose is worked out no more.
			mixer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			set_process(false)
			return

	var rate := 1.0 / maxf(_fade_in if _action_goal > _action else _fade_out, 0.01)
	_action = move_toward(_action, _action_goal, delta * rate)
	_cross = move_toward(_cross, float(_front), delta / 0.08)
	_legs = move_toward(_legs, _legs_goal * (1.0 if _action > 0.01 else 0.0), delta / 0.12)
	mixer.set(&"parameters/act/blend_amount", _action)
	mixer.set(&"parameters/cross/blend_amount", _cross)
	mixer.set(&"parameters/legs/blend_amount", _legs)
	var upper_rate := 1.0 / maxf(_upper_in if _upper_goal > _upper else _upper_out, 0.01)
	_upper = move_toward(_upper, _upper_goal, delta * upper_rate)
	mixer.set(&"parameters/upper/blend_amount", _upper)


# ---------------------------------------------------------------------------
# Going limp
# ---------------------------------------------------------------------------

## The body he falls as. Made once, straight after build, while he still
## stands in his rest pose (its joints are measured from it).
func add_ragdoll(mass_scale := 1.0) -> Node:
	if ragdoll != null:
		return ragdoll

	skeleton.reset_bone_poses()
	ragdoll = RagdollScript.new()
	ragdoll.build(self, mass_scale)
	# After the animation: physics has the final say over his bones.
	skeleton.add_child(ragdoll)

	# His cloth drapes over whatever physics does with him (Cloth.gd), its
	# restarter just ahead of it.
	if cloth != null:
		var restart := skeleton.get_node_or_null("ClothReset")

		if restart != null:
			skeleton.move_child(restart, ragdoll.get_index() + 1)
			restart.ragdoll = ragdoll

		skeleton.move_child(cloth, ragdoll.get_index() + 1)

	return ragdoll


## His cloth started afresh (ClothReset.gd), for whoever puts him somewhere
## in one step: getting up, being laid down. Nothing if he wears none.
func restart_cloth() -> void:
	var restart := skeleton.get_node_or_null("ClothReset") if skeleton != null else null

	if restart != null:
		restart.restart()


## Physics has him from the pose he is in, all of him moving at `velocity`.
func go_limp(velocity := Vector3.ZERO) -> void:
	if ragdoll != null:
		ragdoll.go_limp(velocity)


func is_limp() -> bool:
	return ragdoll != null and ragdoll.is_limp()


## The animation stops where it is: what physics does not move (hands, feet,
## the neck) keeps the pose it had.
func hold_still() -> void:
	_once = &""

	if mixer != null:
		mixer.active = false

	if posture != null:
		posture.active = false


## Animated again (getting up, or put back on his feet).
func wake() -> void:
	if mixer != null:
		mixer.active = true
		mixer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE

	if posture != null:
		posture.active = true

	set_process(true)


## Straight into one frame of `animation`, at once and held: how he lies to
## be let fall (a body slung off a shoulder).
func show_pose(animation: StringName, time := 0.0) -> void:
	if mixer == null or not library().has_animation(animation):
		return

	mixer.active = true
	show_action(animation, time, 0.0)
	_action = 1.0
	_cross = float(_front)
	mixer.set(&"parameters/act/blend_amount", 1.0)
	mixer.set(&"parameters/cross/blend_amount", _cross)
	mixer.advance(0.0)
	mixer.active = false


# ---------------------------------------------------------------------------
# Cut apart
# ---------------------------------------------------------------------------

## What a blade can take off him, by the bone it hangs from: [the stump's
## radius, the piece's mass (kg), the bone at its far end, how far past it
## the piece's shape runs].
const SEVERABLE := {
	&"neck_01": [0.065, 4.5, &"Head", 0.2],
	&"upperarm_l": [0.055, 3.6, &"hand_l", 0.1],
	&"upperarm_r": [0.055, 3.6, &"hand_r", 0.1],
	&"lowerarm_l": [0.045, 1.8, &"hand_l", 0.1],
	&"lowerarm_r": [0.045, 1.8, &"hand_r", 0.1],
	&"thigh_l": [0.08, 9.5, &"foot_l", 0.08],
	&"thigh_r": [0.08, 9.5, &"foot_r", 0.08],
	&"calf_l": [0.055, 4.5, &"foot_l", 0.14],
	&"calf_r": [0.055, 4.5, &"foot_r", 0.14],
}

static var _stump_material: StandardMaterial3D


## Cuts away what hangs from `bone` (SEVERABLE): gone from him but for a
## stump that bleeds, and flung off at `velocity` as a piece of its own
## (SeveredPart.gd), dressed as it was. The piece, or null.
func sever(bone: StringName, velocity := Vector3.ZERO) -> RigidBody3D:
	if skeleton == null or not SEVERABLE.has(bone):
		return null

	var root := skeleton.find_bone(bone)

	if root < 0 or (severed != null and bone in severed.bones):
		return null

	var taken := _bones_under(root)
	var names: Array[StringName] = []

	for index in taken:
		names.append(StringName(skeleton.get_bone_name(index)))

	# Where each bone of it is this instant (physics may have him).
	var poses := {}

	for index in taken:
		poses[index] = pose_now(index)

	var carried := velocity

	if ragdoll != null and ragdoll.is_limp():
		var part: PhysicalBone3D = ragdoll.body(bone)

		if part != null:
			carried += part.linear_velocity

	var piece := _cut_piece(bone, taken, poses, carried)

	# Gone from him: shrunk to nothing where it joined, and no weight in his fall.
	if severed == null:
		severed = SeveredScript.new()
		severed.name = "Severed"
		skeleton.add_child(severed)

	severed.bones.append(bone)

	# What kept his cloth off the part goes with it: an invisible leg would
	# still prop his skirts.
	if cloth != null:
		for name in names:
			var keep := cloth.get_node_or_null("Keep_" + String(name))

			if keep != null:
				keep.queue_free()

	if ragdoll != null:
		ragdoll.drop_bodies(names)

	_stump(bone)
	return piece


## The skinned meshes he wears that put weight on any of `bones` (skeleton
## indices): what a part cut there takes with it (§7.6).
func weighted_meshes(bones: PackedInt32Array) -> Array[MeshInstance3D]:
	var wanted := {}

	for index in bones:
		wanted[skeleton.get_bone_name(index)] = true

	var out: Array[MeshInstance3D] = []

	for child in skeleton.get_children():
		var worn := child as MeshInstance3D

		if worn == null or worn.skin == null or worn.mesh == null:
			continue

		for name in _weighed_bones(worn):
			if wanted.has(name):
				out.append(worn)
				break

	return out


## Which bones (by name) a skinned mesh puts any weight on: read once per
## mesh and skin.
static var _weighed := {}


func _weighed_bones(worn: MeshInstance3D) -> Dictionary:
	var key := "%d|%d" % [worn.mesh.get_instance_id(), worn.skin.get_instance_id()]

	if _weighed.has(key):
		return _weighed[key]

	var binds := {}

	for i in range(worn.skin.get_bind_count()):
		var name := String(worn.skin.get_bind_name(i))
		binds[i] = name if name != "" else String(skeleton.get_bone_name(worn.skin.get_bind_bone(i)))

	var found := {}

	for surface in range(worn.mesh.get_surface_count()):
		var arrays := worn.mesh.surface_get_arrays(surface)

		if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
			continue

		var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]

		for k in range(mini(ids.size(), weights.size())):
			if weights[k] > 0.0:
				found[binds.get(ids[k], "")] = true

	_weighed[key] = found
	return found


## A bone and everything that hangs from it.
func _bones_under(root: int) -> Array[int]:
	var found: Array[int] = [root]
	var i := 0

	while i < found.size():
		for child in skeleton.get_bone_children(found[i]):
			found.append(child)

		i += 1

	return found


## Where `bone` is right now, in the skeleton's space: where physics has him
## if he is limp, else where the animation does.
func pose_now(bone: int) -> Transform3D:
	if ragdoll != null and ragdoll.is_limp():
		var part: PhysicalBone3D = ragdoll.body(StringName(skeleton.get_bone_name(bone)))

		if part != null:
			return skeleton.global_transform.affine_inverse() * part.global_transform * part.body_offset.affine_inverse()

		var parent := skeleton.get_bone_parent(bone)

		if parent >= 0:
			return pose_now(parent) * skeleton.get_bone_pose(bone)

	return skeleton.get_bone_global_pose(bone)


func _cut_piece(bone: StringName, taken: Array[int], poses: Dictionary, velocity: Vector3) -> RigidBody3D:
	var spec: Array = SEVERABLE[bone]
	var root := skeleton.find_bone(bone)
	var size := global_transform.basis.get_scale().x
	var to_world := skeleton.global_transform

	# Its shape: a head is a ball; a limb, a rod from the cut to its end.
	var start: Vector3 = to_world * (poses[root] as Transform3D).origin
	var end_bone := skeleton.find_bone(spec[2])
	var end: Vector3 = to_world * (poses.get(end_bone, poses[root]) as Transform3D).origin
	var piece_xform := Transform3D.IDENTITY
	var shape := CollisionShape3D.new()

	if bone == &"neck_01":
		var ball := SphereShape3D.new()
		ball.radius = 0.12 * size
		shape.shape = ball
		piece_xform.origin = to_world * ((poses.get(end_bone, poses[root]) as Transform3D) * Vector3(0.0, 0.09, 0.02))
	else:
		var along := (end - start).normalized() if end.distance_to(start) > 0.01 else Vector3.DOWN
		end += along * float(spec[3]) * size
		var rod := CapsuleShape3D.new()
		rod.radius = float(spec[0]) * size
		rod.height = maxf(start.distance_to(end) + rod.radius * 2.0, rod.radius * 2.0 + 0.01)
		shape.shape = rod
		piece_xform = Transform3D(RagdollScript._basis_along(along), (start + end) * 0.5)

	var piece: RigidBody3D = SeveredPartScript.new()
	piece.name = "Severed_" + String(bone)
	piece.set("part", bone)
	piece.mass = float(spec[1]) * size * size * size
	piece.add_child(shape)

	# A copy of him, posed as he was, in which only the part is drawn: its
	# root is its own now, and everything else hangs from a root shrunk away.
	var copy := Skeleton3D.new()
	copy.name = "Skeleton3D"

	for i in range(skeleton.get_bone_count()):
		copy.add_bone(skeleton.get_bone_name(i))

	for i in range(skeleton.get_bone_count()):
		copy.set_bone_parent(i, -1 if i == root else skeleton.get_bone_parent(i))
		copy.set_bone_rest(i, skeleton.get_bone_rest(i))

	for i in range(skeleton.get_bone_count()):
		var local: Transform3D = skeleton.get_bone_pose(i)

		if i == root:
			local = poses[root]
		elif poses.has(i) and poses.has(skeleton.get_bone_parent(i)):
			local = (poses[skeleton.get_bone_parent(i)] as Transform3D).affine_inverse() * (poses[i] as Transform3D)

		copy.set_bone_pose_position(i, local.origin)
		copy.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		copy.set_bone_pose_scale(i, local.basis.get_scale())

		# The rest of him shrinks away into the cut, not somewhere off
		# where his feet were.
		if skeleton.get_bone_parent(i) < 0 and i != root:
			copy.set_bone_pose_position(i, (poses[root] as Transform3D).origin)
			copy.set_bone_pose_scale(i, Vector3.ONE * 0.001)

	piece.add_child(copy)
	copy.transform = piece_xform.affine_inverse() * to_world

	# Dressed as he was: every mesh he wears that weighs on its bones (§7.6:
	# a head its face, hair, beard and headgear; a leg its boot or its piece
	# of the outfit).
	var taking := weighted_meshes(PackedInt32Array(taken))

	for child in skeleton.get_children():
		var worn := child as MeshInstance3D

		if worn == null or worn.skin == null or not taking.has(worn):
			continue

		var drawn := MeshInstance3D.new()
		drawn.name = worn.name
		drawn.mesh = worn.mesh
		drawn.skin = worn.skin
		drawn.material_override = worn.material_override
		drawn.layers = worn.layers

		for surface in range(worn.get_surface_override_material_count()):
			drawn.set_surface_override_material(surface, worn.get_surface_override_material(surface))

		# His own dye, fading, skin and dirt (Wardrobe.apply_look) go with it.
		for look_of in LOOK_UNIFORMS:
			var value: Variant = worn.get_instance_shader_parameter(look_of)

			if value != null:
				drawn.set_instance_shader_parameter(look_of, value)

		copy.add_child(drawn)
		drawn.skeleton = NodePath("..")

	# What rode on the part (a helmet, a shoulder plate, wounds, arrows) goes
	# with it.
	for child in skeleton.get_children():
		var holder := child as BoneAttachment3D

		if holder == null or skeleton.find_bone(holder.bone_name) not in taken:
			continue

		var moved := BoneAttachment3D.new()
		moved.name = holder.name
		moved.bone_name = holder.bone_name
		copy.add_child(moved)

		for item in holder.get_children():
			item.reparent(moved, false)

		holder.queue_free()

	# The cut end: raw, and bleeding as it flies.
	var cut := BoneAttachment3D.new()
	cut.name = "Cut"
	cut.bone_name = bone
	copy.add_child(cut)
	cut.add_child(_stump_mesh(float(spec[0]) * 0.95))

	# It flies free of what it was cut from.
	if ragdoll != null:
		for part in ragdoll.bodies():
			piece.add_collision_exception_with(part)

	var level: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	level.add_child(piece)
	piece.global_transform = piece_xform
	piece.reset_physics_interpolation()
	piece.linear_velocity = velocity
	piece.angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(5.0, 11.0)
	Fx.blood(piece, start, velocity.normalized() if velocity.length() > 0.1 else Vector3.UP, 1.6)
	Fx.spurt(cut, Vector3.ZERO, Vector3.DOWN, 1.0, 0.8)
	return piece


## The end left on him where `bone` was cut away: a raw stump that pumps.
func _stump(bone: StringName) -> void:
	var root := skeleton.find_bone(bone)
	var parent := skeleton.get_bone_parent(root)

	if parent < 0:
		return

	var holder := BoneAttachment3D.new()
	holder.name = "Stump_" + String(bone)
	holder.bone_name = skeleton.get_bone_name(parent)
	skeleton.add_child(holder)
	# At the joint, facing the way the part went.
	var joint := skeleton.get_bone_pose(root)
	var cap := _stump_mesh(float(SEVERABLE[bone][0]))
	cap.transform = Transform3D(joint.basis.orthonormalized(), joint.origin)
	holder.add_child(cap)
	var out: Vector3 = joint.basis.orthonormalized() * Vector3.UP
	Fx.spurt(holder, joint.origin, out, 2.6 if bone == &"neck_01" else 1.8, 1.2)


## A low, raw cap: flesh round a pale core, flat across the cut.
static func _stump_mesh(radius: float) -> MeshInstance3D:
	if _stump_material == null:
		_stump_material = StandardMaterial3D.new()
		_stump_material.albedo_color = Color(0.32, 0.03, 0.025)
		_stump_material.roughness = 0.35
		_stump_material.metallic_specular = 0.6
		_stump_material.emission_enabled = true
		_stump_material.emission = Color(0.05, 0.0, 0.0)

	var cap := MeshInstance3D.new()
	cap.name = "Stump"
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 0.7
	ball.radial_segments = 8
	ball.rings = 3
	ball.material = _stump_material
	cap.mesh = ball
	cap.layers = Layers.ACTORS
	return cap


# ---------------------------------------------------------------------------
# Dressing: hair, helmets, plates
# ---------------------------------------------------------------------------

const HAIR := "res://assets/characters/hair/%s.gltf"
## Boots over the base body's bare feet (made in Blender: assets/characters/
## boots/source/boots.blend), skinned to the leg's bones.
const BOOTS := "res://assets/characters/boots/%s.glb"
const ARMOUR := "res://assets/armour/%s.glb"
## Rigid pieces on bones: [bone, position, basis]. The armour was modelled
## with its origin at the bone (a helmet: at the skull's base), up +Y and the
## face toward +Z. An arm bone runs +Y down the arm, its +X up (right arm)
## or down (left) in the rest pose, so a shoulder plate is turned onto it.
const PIECES := {
	&"kettlehat": [&"Head", Vector3.ZERO, Basis.IDENTITY],
	&"nasalhelm": [&"Head", Vector3.ZERO, Basis.IDENTITY],
	&"hood": [&"Head", Vector3.ZERO, Basis.IDENTITY],
	&"pauldron_r": [&"upperarm_r", Vector3(0.0, 0.02, 0.0), Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))],
	&"pauldron_l": [&"upperarm_l", Vector3(0.0, 0.02, 0.0), Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))],
}

## Pieces that are cloth, not metal: a blade on them sounds of flesh.
const CLOTH_PIECES := [&"hood"]
## The bones a blow can land on: the nearest names where it landed.
const FLESH_BONES := [&"Head", &"neck_01", &"spine_03", &"spine_02", &"spine_01", &"pelvis",
	&"upperarm_l", &"upperarm_r", &"lowerarm_l", &"lowerarm_r", &"thigh_l", &"thigh_r", &"calf_l", &"calf_r"]
## What is his alone on each thing he wears (Wardrobe.apply_look).
const LOOK_UNIFORMS := [&"dye_colour", &"dye_fade", &"skin_tone", &"grime"]

static var _hair_meshes := {}
static var _armour_meshes := {}

## The armour he wears (add_armour).
var armour: Array[MeshInstance3D] = []


## His outfit dyed `colour` instead of what the wardrobe rolled him: every
## thing he wears takes it (Wardrobe.apply_look). Only for a dressed man.
func set_dye(colour: Color) -> void:
	if look.is_empty() or skeleton == null:
		return

	look["dye"] = colour

	for worn in skeleton.find_children("*", "GeometryInstance3D", true, false):
		WardrobeScript.apply_look(worn as GeometryInstance3D, look)


## Boots on his feet, bound to this skeleton by bone name.
func add_boots(file: StringName = &"Boots_Male") -> MeshInstance3D:
	var found := _skinned_mesh(BOOTS % file)

	if found.is_empty():
		return null

	var boots := MeshInstance3D.new()
	boots.name = "Boots"
	boots.mesh = found[0]
	boots.skin = found[1]
	skeleton.add_child(boots)
	boots.skeleton = NodePath("..")
	boots.layers = Layers.ACTORS
	return boots


## A hairstyle (or beard) from the pack, bound to this skeleton by bone name.
func add_hair(style: StringName, tint := Color.WHITE) -> MeshInstance3D:
	var mesh := _hair_mesh(style)

	if mesh == null:
		return null

	var hair := MeshInstance3D.new()
	hair.name = String(style)
	hair.mesh = mesh[0]
	hair.skin = mesh[1]
	skeleton.add_child(hair)
	hair.skeleton = NodePath("..")
	hair.layers = Layers.ACTORS

	if tint != Color.WHITE:
		for i in range(hair.mesh.get_surface_count()):
			var material := hair.mesh.surface_get_material(i)

			if material is StandardMaterial3D:
				var tinted := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
				tinted.albedo_color = tint
				hair.set_surface_override_material(i, tinted)

	return hair


static func _hair_mesh(style: StringName) -> Array:
	return _skinned_mesh(HAIR % style)


## The first skinned mesh in a scene file, and its skin: [mesh, skin], or
## nothing. Loaded once.
static func _skinned_mesh(path: String) -> Array:
	if _hair_meshes.has(path):
		return _hair_meshes[path]

	if not ResourceLoader.exists(path):
		return []

	var scene := (load(path) as PackedScene).instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	var result := []

	for node in found:
		var instance := node as MeshInstance3D

		if instance.skin != null:
			result = [instance.mesh, instance.skin]
			break

	scene.free()
	_hair_meshes[path] = result
	return result


## A rigid piece of armour on its bone (see PIECES).
func add_armour(piece: StringName) -> MeshInstance3D:
	if not PIECES.has(piece):
		return null

	var spec: Array = PIECES[piece]
	var file := String(piece).trim_suffix("_r").trim_suffix("_l")
	var mesh := armour_mesh(StringName(file))

	if mesh == null:
		return null

	var node := MeshInstance3D.new()
	node.name = String(piece)
	node.mesh = mesh
	node.layers = Layers.ACTORS
	attach(spec[0], node, Transform3D(spec[2], spec[1]))
	armour.append(node)
	return node


## The metal he wears nearest `point`, if it is within `reach` of it (a
## helmet, a shoulder plate: not a hood, and not a piece cut off with its
## limb); null if steel there would meet only him.
func armour_near(point: Vector3, reach := 0.12) -> MeshInstance3D:
	var nearest: MeshInstance3D = null
	var best := reach

	for piece in armour:
		if not is_instance_valid(piece) or not piece.is_visible_in_tree() or StringName(piece.name) in CLOTH_PIECES:
			continue

		if piece.mesh == null or not is_ancestor_of(piece):
			continue

		# How far the point is from the piece's box, in the world.
		var local := piece.global_transform.affine_inverse() * point
		var box := piece.mesh.get_aabb()
		var on_box := local.clamp(box.position, box.end)
		var distance := (piece.global_transform * on_box).distance_to(point)

		if distance <= best:
			best = distance
			nearest = piece

	# Mail and plate worn as part of his clothes or gear (a coif, a hauberk):
	# steel where the blow lands on a bone they cover.
	if nearest == null and not metal.is_empty():
		var bone := nearest_flesh(point)
		var worn_metal: Node = metal.get(bone)

		if worn_metal != null and is_instance_valid(worn_metal) and is_ancestor_of(worn_metal):
			return worn_metal as MeshInstance3D

	return nearest


## The bone of him a blow at `point` lands on (FLESH_BONES), or &"" if it
## misses him by more than a hand.
func nearest_flesh(point: Vector3) -> StringName:
	var best: StringName = &""
	var gap := 0.3

	for bone in FLESH_BONES:
		var distance := bone_global(bone).origin.distance_to(point)

		if distance < gap:
			gap = distance
			best = bone

	return best


static func armour_mesh(file: StringName) -> Mesh:
	if _armour_meshes.has(file):
		return _armour_meshes[file]

	var path := ARMOUR % file

	if not ResourceLoader.exists(path):
		return null

	var scene := (load(path) as PackedScene).instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	scene.free()

	# Open shells (a hood, a plate) are seen from both sides.
	if mesh != null:
		mesh = mesh.duplicate(true) as Mesh

		for i in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(i)

			if material is BaseMaterial3D:
				var both := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
				both.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.surface_set_material(i, both)

	_armour_meshes[file] = mesh
	return mesh


## Lets go of what everyone shares (for a clean exit in tests).
static func forget_shared() -> void:
	_library = null
	_scenes.clear()
	_materials.clear()
	_hair_meshes.clear()
	_armour_meshes.clear()


## Puts `node` on `bone`, at `offset` in the bone's own space.
func attach(bone: StringName, node: Node3D, offset := Transform3D.IDENTITY) -> BoneAttachment3D:
	var holder := BoneAttachment3D.new()
	holder.name = "On_" + bone
	holder.bone_name = bone
	skeleton.add_child(holder)
	holder.add_child(node)
	node.transform = offset
	return holder


func bone_global(bone: StringName) -> Transform3D:
	var index := skeleton.find_bone(bone)

	if index < 0:
		return global_transform

	return skeleton.global_transform * skeleton.get_bone_global_pose(index)


## Every mesh drawn on these render layers (a viewmodel, a gem probe...).
func set_layers(layers: int) -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).layers = layers


# ---------------------------------------------------------------------------
# Dressed from the wardrobe
# ---------------------------------------------------------------------------

## Builds him as a low-poly PS2 character of `kind` (Wardrobe.gd, made by
## tools/wardrobe): his outfit, a face, headgear, rolled from `seed` (the same
## seed, the same man). False, with nothing built, if the kind cannot be
## dressed: the caller builds him as the plain base body instead (GuardRig).
func dress(kind: StringName, seed: int, fighting_idle: StringName = &"Sword_Idle") -> bool:
	if not WardrobeScript.can_dress(kind):
		return false

	var data := WardrobeScript.kind_data(kind)
	var body_kind := String(data.get("body", "male"))
	var options := WardrobeScript.usable_options(data.get("options", {}), body_kind)
	build(&"", body_kind == "female", fighting_idle)

	# The base character's own meshes go: his outfit, head and gear are it.
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			skeleton.remove_child(child)
			child.free()

	look = WardrobeScript.roll(options, data.get("skin_tones", {}), seed)

	# Hair only where no headgear hides it; a beard only where all allow one.
	for piece in look.headgear:
		var info := WardrobeScript.headgear_data(piece)

		if bool(info.get("hides_hair", false)):
			look.hair = &""

		if not bool(info.get("allows_beard", true)):
			look.beard = &""

	var root := WardrobeScript.ROOT
	var dye_base := WardrobeScript.dye_base(options)
	body = _wear(root + "%s.glb" % kind, "Outfit", load(root + "%s.png" % kind), load(root + "%s_mask.png" % kind), dye_base, body_kind)
	_wear(root + "heads/%s.glb" % look.face, "Head_%s" % look.face, load(root + "heads/%s_%s.png" % [look.face, look.tone]), null,
		Color.WHITE, body_kind)

	# His hair and beard: one grey texture each, dyed his hair colour.
	for style in [look.get("hair", &""), look.get("beard", &"")]:
		if style == &"":
			continue

		var info := WardrobeScript.hair_data(style)
		var hair_base: Array = info.get("dye_base", [0.5, 0.5, 0.5])
		var strands := _wear(root + "hair/%s.glb" % style, ("Beard_%s" if info.get("kind") == "beard" else "Hair_%s") % style,
			load(root + "hair/%s.png" % style), load(root + "hair/%s_mask.png" % style), Color(hair_base[0], hair_base[1], hair_base[2]),
			body_kind)

		# A file with no skinned mesh (Wardrobe.skinned said so): left off.
		if strands == null:
			continue

		strands.set_instance_shader_parameter(&"dye_colour", look.get("hair_colour", Color(0.3, 0.25, 0.2)))

	for bone in data.get("metal", []):
		metal[StringName(bone)] = body

	for piece in look.headgear:
		# Its mask holds only dirt: how dirty he rolled reaches his hat too.
		var gear_mask_path := root + "headgear/%s_mask.png" % piece
		var gear_mask: Texture2D = load(gear_mask_path) if ResourceLoader.exists(gear_mask_path) else null
		var gear_dye: Array = WardrobeScript.headgear_data(piece).get("dye_base", [1.0, 1.0, 1.0])
		var worn_piece := _wear(root + "headgear/%s.glb" % piece, String(piece), load(root + "headgear/%s.png" % piece), gear_mask,
			Color(gear_dye[0], gear_dye[1], gear_dye[2]), body_kind)

		for bone in WardrobeScript.headgear_data(piece).get("metal", []):
			metal[StringName(bone)] = worn_piece

	# What swings on him: the outfit's chains and his headgear's.
	var chains: Array = data.get("cloth", []).duplicate()
	var colliders: Array = data.get("colliders", []).duplicate()

	for piece in look.headgear:
		chains += WardrobeScript.headgear_data(piece).get("cloth", [])
		colliders += WardrobeScript.headgear_data(piece).get("colliders", [])

	if not chains.is_empty():
		var restart := ClothResetScript.new()
		restart.name = "ClothReset"
		skeleton.add_child(restart)
		cloth = ClothScript.new()
		cloth.name = "Cloth"
		skeleton.add_child(cloth)
		cloth.setup(chains, colliders)
		restart.cloth = cloth

	# Taller or shorter than his kind: his look only (his reach, eyes and
	# collision are the guard's own). On his model, not on him: whoever
	# carries him may set his own transform.
	model.scale = Vector3.ONE * float(look.height)
	return true


## One part worn on his skeleton: its skin re-bound, the kind's shared
## material on each surface (strips drawn from both sides), his look.
func _wear(path: String, part_name: String, albedo: Texture2D, mask: Texture2D, dye_base: Color, body_kind: String) -> MeshInstance3D:
	var found := WardrobeScript.skinned(path, skeleton, body_kind)

	if found.is_empty():
		return null

	var worn_mesh := MeshInstance3D.new()
	worn_mesh.name = part_name
	worn_mesh.mesh = found[0]
	worn_mesh.skin = found[1]
	skeleton.add_child(worn_mesh)
	worn_mesh.skeleton = NodePath("..")
	worn_mesh.layers = Layers.ACTORS

	for surface in range(worn_mesh.mesh.get_surface_count()):
		var original := worn_mesh.mesh.surface_get_material(surface)
		var strips := original != null and String(original.resource_name).begins_with("WR_strips")
		worn_mesh.set_surface_override_material(surface, WardrobeScript.material(albedo, mask, strips, dye_base))

	WardrobeScript.apply_look(worn_mesh, look)
	return worn_mesh


## Everything he wears: every skinned mesh on him (his body or outfit, a
## head, hair, boots, gear) and his rigid armour. Never the marks, stumps or
## the weapon (they hang from bones).
func worn() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []

	if skeleton == null:
		return out

	for child in skeleton.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).skin != null:
			out.append(child)

	for piece in armour:
		if is_instance_valid(piece) and is_ancestor_of(piece) and not out.has(piece):
			out.append(piece)

	return out
