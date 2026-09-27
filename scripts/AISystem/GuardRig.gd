extends Node3D
## How a guard looks and moves, on top of what he decides. The AI picks what
## to do; the rig shows it. He is one of the base characters in his side's
## colours (Humanoid.gd), moved by the animation library: he walks, runs and
## backs off, squares up with his guard held, winds up and cuts, catches your
## blade, reels when parried, flinches, staggers when kicked, and falls when
## he dies. Springs on top add the jolt of every blow.
##
## Pure presentation: the AI reads nothing from here, so none of it can
## change a fight. His vision still comes from his logical "Head". Each
## swing is shown in step with the fight's own clock (his phase timers): the
## animated blade meets you when his code says it does, however quick or slow
## his windup is.

const Layers := preload("res://scripts/Visual/Layers.gd")
const HIT_RIM := preload("res://scripts/Visual/hit_rim.gdshader")
const BLADE_BLOOD := preload("res://scripts/Visual/blade_blood.gdshader")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const SwingTrailScript := preload("res://scripts/Visual/SwingTrail.gd")
const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const GuardFighterScript := preload("res://scripts/AISystem/GuardFighter.gd")
const HumanoidScript := preload("res://scripts/Visual/Humanoid.gd")
const ExpressionScript := preload("res://scripts/Visual/Expression.gd")

## Guard.Alert.SEARCHING and COMBAT: hunting, his guard is up.
const SEARCHING := 3
const COMBAT := 4
## Along the sword, from its grip (the weapon's own metas win).
const BLADE_BASE := Vector3(0.0, 0.14, 0.0)
const BLADE_TIP := Vector3(0.0, 0.86, 0.0)
const MAX_WOUNDS := 10
const MAX_ARROWS := 8
## A blade in the right hand, in the hand bone's space (+Y along the fingers,
## +Z the thumb side, +X the back of the hand): the blade out of the thumb
## side, its edges along the fingers, the grip across the palm.
const GRIP := Transform3D(Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)), Vector3(-0.03, 0.08, 0.0))
## A crossbow by its pistol grip, solved from the aiming pose: level and
## pointing where he looks.
const CROSSBOW_GRIP := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(76.3)), Vector3(-0.02, 0.08, 0.0))

## Each blow as the animations show it, in seconds into its clip (read off
## frame by frame, sword in hand): "from" where the windup starts, "cocked"
## the top of it (the key pose he holds, so you can read it), "contact" the
## blade meeting you, "follow" the follow-through, "done" the end of it.
## "release" is how long the blade takes from cocked to contact, whatever his
## windup: he gets to the cocked pose quickly, holds it, and lets go fast.
## "rec" is the clip he comes back to his guard with: [clip, from, to].
## "weight" is how much of the clip is shown over his own stance: the library's
## moves are a performer's, big and flung; a soldier keeps them tighter. A kick
## is laid over his stance instead (Posture.gd).
const SWINGS := {
	&"overhead": {"clip": &"Sword_Attack", "from": 0.08, "cocked": 0.38, "contact": 0.5, "follow": 0.6, "done": 1.2, "release": 0.15, "weight": 0.86},
	&"left": {"clip": &"Sword_Regular_A", "from": 0.0, "cocked": 0.12, "contact": 0.23, "follow": 0.32, "done": 0.43, "release": 0.13, "weight": 0.82,
		"rec": [&"Sword_Regular_A_Rec", 0.0, 0.64]},
	&"right": {"clip": &"Sword_Regular_B", "from": 0.02, "cocked": 0.16, "contact": 0.25, "follow": 0.34, "done": 0.53, "release": 0.13, "weight": 0.82,
		"rec": [&"Sword_Regular_B_Rec", 0.0, 0.69]},
	# Gathered at the hip, then the point driven out; he stays in the lunge
	# a moment, overextended, before he rises.
	&"thrust": {"clip": &"Sword_Dash", "from": 0.06, "cocked": 0.18, "contact": 0.29, "follow": 0.33, "done": 0.6, "release": 0.11, "weight": 0.74,
		"rec": [&"Sword_Dash", 0.97, 1.4]},
	# The overhead driven lower, into the floor.
	&"heavy": {"clip": &"Sword_Attack", "from": 0.05, "cocked": 0.4, "contact": 0.56, "follow": 0.72, "done": 1.2, "release": 0.24, "weight": 0.92},
	# The dash: crouched and gathered, driven in, the blade out ahead.
	&"lunge": {"clip": &"Sword_Dash", "from": 0.0, "cocked": 0.18, "contact": 0.29, "follow": 0.36, "done": 0.6, "release": 0.22, "weight": 0.78,
		"rec": [&"Sword_Dash", 0.97, 1.4]},
	# Down into a crouch with the blade drawn back low, and across at your shins.
	&"sweep": {"clip": &"Sword_Heavy_Combo", "from": 0.1, "cocked": 0.33, "contact": 0.44, "follow": 0.5, "done": 0.75, "release": 0.16, "weight": 0.8},
	# The off hand, pulled back and driven into you.
	&"bash": {"clip": &"Melee_Hook", "from": 0.0, "cocked": 0.16, "contact": 0.26, "follow": 0.31, "done": 0.31, "release": 0.1, "weight": 0.76,
		"rec": [&"Melee_Hook_Rec", 0.0, 0.6]},
	# Head down, shoulder first: the gather is short, the run is the release.
	&"charge": {"clip": &"Shield_Dash", "from": 0.0, "cocked": 0.05, "contact": 0.3, "follow": 0.42, "done": 1.1, "release": 0.3, "weight": 0.9},
	# A bound in from out of reach: she closes with the blade already up, and
	# brings it down as she arrives.
	&"leap": {"clip": &"Sword_Attack", "from": 0.08, "cocked": 0.36, "contact": 0.5, "follow": 0.6, "done": 1.2, "release": 0.17, "weight": 0.86},
	# Something picked up, drawn back overhead, and hurled (GuardHands).
	&"throw": {"clip": &"OverhandThrow", "from": 0.05, "cocked": 0.28, "contact": 0.33, "follow": 0.5, "done": 1.0, "release": 0.08, "weight": 0.95},
	# Bare-handed: the right fist driven across, the left jabbed out.
	&"punch": {"clip": &"Punch_Cross", "from": 0.1, "cocked": 0.2, "contact": 0.3, "follow": 0.45, "done": 1.0, "release": 0.1, "weight": 0.9},
	&"jab": {"clip": &"Punch_Jab", "from": 0.0, "cocked": 0.12, "contact": 0.3, "follow": 0.42, "done": 0.9, "release": 0.12, "weight": 0.9},
}
## What he is doing with his hands or himself (Guard.activity), as clips:
## [clip, loops, fade in, weight].
## (Talking, listening, arms folded, a drink are his upper body's, shown by
## Expression.gd over whatever he stands or walks.)
const ACTIVITIES := {
	&"lantern": [&"Idle_Torch", true, 0.3, 0.85],
	&"call": [&"Idle_Rail_Call", false, 0.15, 0.9],
	# At a station (GuardRota).
	&"sit": [&"Sitting_Idle", true, 0.3, 1.0],
	&"sit_talk": [&"Sitting_Talking", true, 0.3, 1.0],
	&"eat": [&"Consume", true, 0.2, 1.0],
	&"rummage": [&"Crouch_Idle", true, 0.3, 1.0],
	&"chop": [&"TreeChopping", true, 0.25, 1.0],
	&"lean": [&"Idle_Rail", true, 0.35, 1.0],
	# Passing the time (GuardPastimes): squatting by the fire.
	&"squat": [&"Crouch_Idle", true, 0.3, 1.0],
}
## Getting onto and off a station (GuardRota), each shown through its clip in
## its time: [clip, backwards, fade in].
const STATION_MOVES := {
	&"sit_down": [&"Sitting_Enter", false, 0.2],
	&"stand_up": [&"Sitting_Exit", false, 0.1],
	&"lie_down": [&"LayToIdle", true, 0.25],
	&"wake": [&"LayToIdle", false, 0.05],
	&"lid": [&"Chest_Open", false, 0.2],
	&"lift": [&"PickUp_Table", false, 0.2],
	&"set_down": [&"PickUp_Table", true, 0.2],
}
## Crossing what walking cannot (GuardClimb): hauling himself up in the
## climbing clip (in place, a metre to each CLIMB_CYCLE seconds of it); in the
## air in AIR_CLIP; gathering for a jump and landing from one in LAND_CLIP.
## Swimming (GuardWater): SWIM_CLIP on the move, TREAD_CLIP still.
const CLIMB_CLIP := &"ClimbUp_1m"
const CLIMB_CYCLE := 0.667
const AIR_CLIP := &"Jump"
const LAND_CLIP := &"Jump_Land"
const SWIM_CLIP := &"Swim_Fwd"
## Sneaking in a crouch (the showcase's intruder): SNEAK_CLIP on the move,
## CROUCH_CLIP still.
const SNEAK_CLIP := &"Crouch_Fwd"
const CROUCH_CLIP := &"Crouch_Idle"
const TREAD_CLIP := &"Swim_Idle"
## Begging (GuardMercy): on his knees in this clip, down by PLEA_KNEEL_DOWN
## seconds into it, rocking between PLEA_KNEEL_SWAY, getting up from
## PLEA_KNEEL_UP; on his feet, a hand out to you, in PLEA_STAND.
const PLEA_KNEEL := &"Fixing_Kneeling"
const PLEA_KNEEL_DOWN := 1.35
const PLEA_KNEEL_SWAY := Vector2(1.5, 4.8)
const PLEA_KNEEL_UP := 5.3
const PLEA_STAND := &"Spell_Simple_Idle"
## How much of a reaction clip is shown over his stance (as SWINGS' weight).
const REACT_WEIGHT := 0.78
## His temperament (Temperament.gd's tag) in how he stands between blows: a
## rash man leans in (the top of him tips toward -Z, his front), a craven one
## leans back and now and then looks over his shoulder for a way out, a sly
## one keeps low.
const STANCE_LEAN := {&"rash": -0.07, &"craven": 0.06}
const STANCE_CROUCH := {&"sly": -0.05}
## A craven man's glance back: how far his head turns, and for how long.
const GLANCE_YAW := 1.1
const GLANCE_TIME := 0.45
## Thrown off his balance (his posture broken, GuardFighter): down on one knee,
## his blade low. Open.
const OPEN_CLIP := &"Fixing_Kneeling"
## How he falls: [animation, from, speed]. It hits the floor IMPACT seconds
## into the animation.
const DEATH := [&"Death01", 0.25, 1.45]
const KNOCKOUT := [&"Death01", 0.3, 1.6]
const IMPACT := 1.15
## What a guard with no archetype wears and carries.
## The watchman: dressed from the wardrobe (Humanoid.dress), or painted with
## his kettle hat if the wardrobe cannot dress him.
const DEFAULT_LOOK := {"kind": &"watchman", "outfit": &"watchman", "armour": [&"kettlehat"], "weapon": &"sword"}
## Bones a wound or an arrow can ride on: the nearest takes it.
const FLESH_BONES := HumanoidScript.FLESH_BONES

var guard: CharacterBody3D
## The man himself (Humanoid.gd).
var man: Node3D
## What he shows of himself at his ease (Expression.gd).
var expression: RefCounted
var body_mesh: MeshInstance3D
var weapon: MeshInstance3D
var trail: MeshInstance3D
## A crossbowman's bolt, on the stock while he spans and aims.
var nock: MeshInstance3D
## How big he is drawn (an archetype's build).
var size := 1.0

# Springs, each a value and its velocity. The whole man tips (tilt: local,
# horizontal, its length the angle) and slides (offset) with a blow, and his
# blade shakes in his grip (jolt).
var _tilt := Vector3.ZERO
var _tilt_v := Vector3.ZERO
var _offset := Vector3.ZERO
var _offset_v := Vector3.ZERO
var _jolt := Vector3.ZERO
var _jolt_v := Vector3.ZERO

var _logical_head: Node3D
var _overlay: ShaderMaterial
var _flash := 0.0
var _walk_phase := 0.0
## His own clock, advanced every physics tick; reactions are timed on it.
var _time := 0.0
var _velocity := Vector3.ZERO
var _reel := 0.0
var _reel_length := 1.0
var _flail := 0.0
var _flail_length := 1.0
var _flinch: StringName = &""
var _flinch_at := -10.0
var _flourish := 0.0
var _push_dir := Vector3.BACK
var _hurt_dir := Vector3.BACK
var _last_phase: StringName = &""
var _glinted := false
var _roared := false
var _whooshed := false
var _bounced := false
var _wounds: Array[Node3D] = []
var _arrows: Array[Node3D] = []
var _holders := {}
## The blade is cutting: the trail is fed every drawn frame (see _process).
var _cutting := false
## Getting up off the floor: the animation, how long is left, and how fast.
var _rise_anim: StringName = &""
var _rising := 0.0
var _rise_length := 1.0
var _rise_speed := 1.0
## Which step of his walk he is on: a new one is a foot coming down.
var _step_index := 0
var _grip := GRIP
var _blade_base := BLADE_BASE
var _blade_tip := BLADE_TIP
var _blade_blood: ShaderMaterial
var _blood_on_blade := 0.0
## The weapon's edge, made readable in the dark, and how lit it is now: a
## blow that is really coming shows in the blade.
var _steel: Array[StandardMaterial3D] = []
var _telegraph := 0.0
var _crossbow := false
## A craven man's glance over his shoulder (visual only: his eyes are the
## logical head): the turn now, how far into it (<0: between glances), when
## the next comes, and which way.
var _glance := 0.0
var _glance_t := -1.0
var _glance_wait := 3.0
var _glance_side := 1.0
## Open (his posture broken): how long is left of it, and how long it was.
var _open_left := 0.0
var _open_length := 1.0
var _voice_pitch := 1.0
## A woman (the look says so): her voice is her own (Guard.voice).
var female := false
## The weapon in his hand now (GuardHands may have him pick up another).
var _carried: StringName = &"sword"
## Where a thing he picked up to throw sits in his hand (throwing_hand).
var _held_point: Node3D = null
## What he was last shown doing (Guard.activity), and since when.
var _activity: StringName = &""
var _activity_at := 0.0


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

## Replaces the guard's stand-in looks (the "Body" capsule, whatever hangs off
## his "Head") with the man. The Head itself stays where it is, for his eyes.
func setup(p_guard: CharacterBody3D) -> void:
	guard = p_guard
	name = "Rig"
	guard.add_child(self)

	var stand_in := guard.get_node_or_null("Body")

	if stand_in != null:
		guard.remove_child(stand_in)
		stand_in.free()

	_logical_head = guard.get_node_or_null("Head") as Node3D

	if _logical_head != null:
		for child in _logical_head.get_children():
			if child is GeometryInstance3D:
				_logical_head.remove_child(child)
				child.free()

	var look: Dictionary = guard.look() if guard.has_method("look") else GuardFighterScript.look_of(guard.archetype)

	if not look.has("outfit"):
		look = DEFAULT_LOOK.merged(look, true)

	size = float(look.get("scale", 1.0))
	var carried: StringName = look.get("weapon", &"sword")
	_carried = carried
	_crossbow = carried == &"crossbow"

	man = HumanoidScript.new()
	man.name = "Man"
	add_child(man)
	var idle: StringName = &"Pistol_Idle" if _crossbow else &"Sword_Idle"
	# From the wardrobe if his kind is there, else painted as before.
	var dressed: bool = look.has("kind") and man.dress(look["kind"], _look_seed(), idle)

	if not dressed:
		man.build(look.get("outfit", &"watchman"), bool(look.get("female", false)), idle)

	# Dyed his own colour (Guard.look_override).
	if dressed and look.has("dye"):
		man.set_dye(look["dye"])

	# His voice: a big man's lower, and each his own. A woman speaks in her
	# own recordings (Guard.voice), at her own pitch.
	female = bool(look.get("female", false))
	_voice_pitch = (1.0 if female else 1.0 / sqrt(maxf(size, 0.5))) * randf_range(0.95, 1.05)
	body_mesh = man.body

	for style in look.get("hair", []) if not dressed else []:
		man.add_hair(style, look.get("hair_tint", Color.WHITE))

	for piece in look.get("armour", []) if not dressed else []:
		man.add_armour(piece)

	if not dressed and not bool(look.get("female", false)):
		man.add_boots()

	# The body he falls as (Ragdoll.gd): made now, while he stands in his rest
	# pose and at his own size, which its joints are measured in.
	transform = Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3.ZERO)
	man.add_ragdoll(size * size * size)
	man.ragdoll.owner_node = guard

	weapon = MeshInstance3D.new()
	weapon.name = "Weapon"
	weapon.mesh = WeaponScript.guard_weapon_mesh(carried)
	weapon.layers = Layers.ACTORS
	_grip = CROSSBOW_GRIP if _crossbow else GRIP
	man.attach(&"hand_r", weapon, _grip)
	_readable()
	_blade_base = weapon.mesh.get_meta(&"blade_base", BLADE_BASE)
	_blade_tip = weapon.mesh.get_meta(&"blade_tip", BLADE_TIP)

	# Your blood on his blade, once he has cut you (blade_blood.gdshader).
	if not _crossbow and weapon.mesh.has_meta(&"blade_tip"):
		_blade_blood = ShaderMaterial.new()
		_blade_blood.shader = BLADE_BLOOD
		_blade_blood.set_shader_parameter("blade_base", _blade_base)
		_blade_blood.set_shader_parameter("blade_tip", _blade_tip)
		_blade_blood.set_shader_parameter("seed", randf() * 30.0)
		_blade_blood.set_shader_parameter("amount", 0.0)
		weapon.material_overlay = _blade_blood

	if _crossbow:
		nock = MeshInstance3D.new()
		nock.name = "Nocked"
		nock.mesh = WeaponScript.arrow_mesh()
		nock.layers = Layers.ACTORS
		# Along the top of the stock, the head past the prod.
		nock.transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.55), Vector3(0.0, 0.115, -0.21))
		nock.visible = false
		weapon.add_child(nock)

	trail = SwingTrailScript.new()
	trail.name = "Trail"
	trail.setup(Layers.FX)
	trail.top_level = true
	trail.color = Color(0.86, 0.88, 0.95, 0.24)
	trail.lifetime = 0.1
	trail.base_fade = 0.45
	add_child(trail)

	_overlay = ShaderMaterial.new()
	_overlay.shader = HIT_RIM
	expression = ExpressionScript.new(self)
	_apply()


## Which of his kind he is (Humanoid.dress): the guard's own look_seed if
## set, else his place in the tree, so each guard of a level is the same man
## every time it loads.
func _look_seed() -> int:
	var chosen: Variant = guard.get("look_seed")
	return int(chosen) if chosen != null and int(chosen) >= 0 else hash(String(guard.get_path()))


## Steel that shows in the dark: less of a mirror (the night has nothing to
## reflect), and a faint sheen of its own, on the edge only (a maul's head).
## His blade is what you read to parry him. On this weapon's own copies: the
## mesh is shared.
func _readable() -> void:
	var mesh := weapon.mesh
	var edges := []

	for wanted in ["M_Steel", "M_Iron"]:
		for i in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(i)

			if material is StandardMaterial3D and material.resource_name == wanted:
				edges.append(i)

		if not edges.is_empty():
			break

	# A mesh without named materials: anything metal.
	if edges.is_empty():
		for i in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(i) as StandardMaterial3D

			if material != null and material.metallic >= 0.4:
				edges.append(i)

	for i in edges:
		var steel := (mesh.surface_get_material(i) as StandardMaterial3D).duplicate() as StandardMaterial3D
		steel.metallic = 0.25
		steel.roughness = 0.45
		steel.emission_enabled = true
		steel.emission = Color(0.7, 0.72, 0.78)
		steel.emission_energy_multiplier = 0.1
		weapon.set_surface_override_material(i, steel)
		_steel.append(steel)


## The blade brightens from the glint to the end of the blow: committed. It
## says what the blow asks of you (GuardFighter.CALLS): pale steel a cut, cold
## blue a thrust, orange a sweep at your legs, red one no guard will hold.
func _update_telegraph(delta: float) -> void:
	var phase: StringName = guard._phase
	var kind: StringName = guard._attack
	var committed := (phase == &"windup" and _phase_u() >= 0.64) or phase == &"strike"
	var goal := 1.0 if committed and not (kind in [&"kick", &"bash", &"punch", &"jab", &"throw"]) else 0.0
	_telegraph = move_toward(_telegraph, goal, delta * (12.0 if goal > _telegraph else 4.0))
	var call: StringName = GuardFighterScript.CALLS.get(kind, &"cut") if phase != &"" else &"cut"
	# A blow that cannot be caught, or goes under a guard, burns from the
	# moment it is raised.
	var hot: bool = call == &"unblockable" or call == &"low"

	if hot and phase == &"windup":
		_telegraph = maxf(_telegraph, minf(_phase_u() * 2.5, 1.0))

	var colour := GuardFighterScript.call_colour(call)
	var energy := 1.6 if hot else (1.0 if call == &"thrust" else 0.55)

	for steel in _steel:
		steel.emission_energy_multiplier = lerpf(0.1, energy, _telegraph)
		steel.emission = Color(0.7, 0.72, 0.78).lerp(colour, _telegraph if call != &"cut" else 0.0)


# ---------------------------------------------------------------------------
# Every physics frame, called by the guard
# ---------------------------------------------------------------------------

func update(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	_time += delta
	_reel = maxf(_reel - delta, 0.0)
	_flail = maxf(_flail - delta, 0.0)
	_flourish = maxf(_flourish - delta, 0.0)
	_flash = move_toward(_flash, 0.0, delta / 0.08)

	var phase: StringName = guard._phase
	_open_left = maxf(_open_left - delta, 0.0)

	if phase == &"windup" and _last_phase != &"windup":
		_glinted = false
		_whooshed = false
		_roared = false
		# The counter-move: his weight goes back as he gathers himself...
		_tilt_v += Vector3(0.0, 0.0, 0.36 if guard._attack in [&"heavy", &"charge", &"sweep"] else 0.2)

	# ...and forward into the blow as it goes.
	if phase == &"strike" and _last_phase != &"strike" and guard._attack != &"shoot":
		_tilt_v += Vector3(0.0, 0.0, -0.95 if guard._attack in [&"heavy", &"charge", &"sweep", &"leap"] else -0.55)
		_offset_v += Vector3(0.0, 0.0, -0.25)

	# His balance going: the blade trembles in his hand.
	var fighter: RefCounted = guard._fighter

	if fighter != null and phase == &"" and _open_left <= 0.0:
		var shaken: float = clampf(float(fighter.posture) / maxf(float(fighter.posture_max), 1.0), 0.0, 1.0)

		if shaken > 0.55:
			var shake := (shaken - 0.55) / 0.45
			_jolt_v += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 6.0 * shake * dt

	if phase != &"recover" and phase != &"strike":
		_bounced = false

	var local_velocity: Vector3 = guard.global_basis.inverse() * guard.velocity
	local_velocity.y = 0.0
	_velocity = _velocity.lerp(local_velocity, 1.0 - exp(-12.0 * dt))
	var speed := local_velocity.length()

	# Each foot coming down, heard in mail and boots: you hear him coming.
	_walk_phase += speed * dt * PI / (0.75 * size)
	var step := int(floor(_walk_phase / PI))

	if step != _step_index:
		_step_index = step

		if speed > 0.6:
			Sfx.play(guard, _step_sound(speed), guard.global_position + Vector3.UP * 0.05, Sfx.loudness(44.0 + speed * 2.5))

	# A lean into his running, away from what hit him, and with a kick.
	var tilt_goal := local_velocity * 0.012

	if guard._knock > 0.0:
		tilt_goal += _push_dir * 0.3
	elif guard._stagger > 0.0 and _reel <= 0.0:
		tilt_goal += _hurt_dir * 0.1

	# Between blows, he stands as the man he is.
	var standing := _in_stance()

	if standing:
		tilt_goal += Vector3(0.0, 0.0, stance_lean())

	_update_glance(delta, standing)

	# Heavy springs, nearly critically damped: a man with weight to him
	# rocks and settles, he does not wobble. A big man is slower still.
	var mass := maxf(size, 0.5)
	_tilt_v += ((tilt_goal - _tilt) * 110.0 / mass - _tilt_v * 17.0 / sqrt(mass)) * dt
	_tilt += _tilt_v * dt
	var rest := Vector3(0.0, stance_crouch(), 0.0) if standing else Vector3.ZERO
	_offset_v += ((rest - _offset) * 100.0 / mass - _offset_v * 16.0 / sqrt(mass)) * dt
	_offset += _offset_v * dt
	_jolt_v += (-_jolt * 260.0 - _jolt_v * 22.0) * dt
	_jolt += _jolt_v * dt

	# Keep a runaway spring (a huge frame) from folding him in half.
	_tilt = _tilt.limit_length(0.6)
	_offset = _offset.limit_length(0.45)

	_apply()
	_events(phase)
	_update_telegraph(delta)
	_cutting = phase == &"strike" or (phase == &"windup" and _phase_u() > 0.85 and guard._attack != &"shoot" and guard._attack != &"kick")
	_last_phase = phase


## What shows most in him (Temperament.gd): steady, stubborn, craven, rash,
## sly.
func _tag() -> StringName:
	var fighter: RefCounted = guard._fighter if guard != null else null
	return fighter.temper.tag if fighter != null and fighter.temper != null else &"steady"


## How far his stance tips him (toward -Z, his front, if negative).
func stance_lean() -> float:
	return float(STANCE_LEAN.get(_tag(), 0.0))


## How much lower his stance keeps him.
func stance_crouch() -> float:
	return float(STANCE_CROUCH.get(_tag(), 0.0))


## Fighting, and between blows: nothing else is being shown.
func _in_stance() -> bool:
	return int(guard.state) == 4 and guard._phase == &"" and _reel <= 0.0 and guard._stagger <= 0.0 and guard._knock <= 0.0 and _open_left <= 0.0


## A craven man looks over his shoulder every few seconds, for a way out.
func _update_glance(delta: float, standing: bool) -> void:
	if _tag() != &"craven" or not standing:
		_glance_t = -1.0
		_glance = move_toward(_glance, 0.0, delta * 4.0)
		return

	if _glance_t < 0.0:
		_glance = move_toward(_glance, 0.0, delta * 4.0)
		_glance_wait -= delta

		if _glance_wait <= 0.0:
			_glance_t = 0.0
			_glance_side = 1.0 if randf() < 0.5 else -1.0

		return

	_glance_t += delta
	var u := _glance_t / GLANCE_TIME

	if u >= 1.0:
		_glance_t = -1.0
		_glance_wait = randf_range(2.5, 4.0)
		_glance = 0.0
		return

	# Out and back, eased.
	_glance = _glance_side * GLANCE_YAW * sin(u * PI)


## His step in mail on the floor he walks, at a walk or at a run.
func _step_sound(speed: float) -> StringName:
	var surface: String = guard.floor_surface() if guard.has_method("floor_surface") else ""
	return Sfx.step(surface, speed > 3.0, "step", true)


func _apply() -> void:
	# He tips about his feet.
	var angle := _tilt.length()
	var basis := Basis.IDENTITY

	if angle > 0.0001:
		basis = Basis(Vector3.UP.cross(_tilt / angle).normalized(), angle)

	transform = Transform3D(basis * Basis.from_scale(Vector3.ONE * size), Vector3(_offset.x, maxf(_offset.y, -0.1), _offset.z))

	# The weapon, knocked about its grip by any jolt.
	var jolt_angle := _jolt.length()
	var held := _grip

	if jolt_angle > 0.0001:
		held.basis = Basis(_jolt / jolt_angle, jolt_angle) * held.basis

	weapon.transform = held

	# The hit flash, on everything he wears (his head and gear too).
	if man != null:
		var flashing := _flash > 0.01

		if flashing:
			_overlay.set_shader_parameter("amount", _flash * _flash)

		for worn in man.worn():
			if flashing:
				worn.material_overlay = _overlay
			elif worn.material_overlay == _overlay:
				worn.material_overlay = null


## 0..1 through his current phase, `ahead` seconds from now.
func _phase_u(ahead := 0.0) -> float:
	var length: float = guard._phase_length if guard._phase_length > 0.0 else guard.windup_time
	return 1.0 - clampf((guard._phase_timer - ahead) / maxf(length, 0.01), 0.0, 1.0)


## The warning glint at the top of his swing, and the rush of the blade.
func _events(phase: StringName) -> void:
	if nock != null:
		nock.visible = guard._attack == &"shoot" and phase == &"windup" and _phase_u() > 0.4

	if phase != &"windup":
		return

	var u := _phase_u()
	var kind: StringName = guard._attack
	var call: StringName = GuardFighterScript.CALLS.get(kind, &"cut")
	var heavy := call == &"unblockable"

	if kind == &"shoot":
		# The crank of spanning it, then a glint on the bolt: loose is near.
		if not _whooshed:
			_whooshed = true
			Sfx.play(guard, &"bow_draw", weapon.global_position, 2.0, 0.85)

		if not _glinted and u >= 0.64:
			_glinted = true
			var head := weapon.global_transform * Vector3(0.0, 0.115, -0.43)
			Fx.glint(guard, head, 0.16, weapon)
			Sfx.play(guard, &"ting", head, -2.0, 1.2)

		return

	# The great blow is roared as it is raised: no guard will hold it. The
	# sweep is grunted low as he drops.
	if (heavy or call == &"low") and not _whooshed and u >= 0.05 and not _roared:
		_roared = true

		if guard.has_method("voice"):
			guard.voice(&"roar" if heavy else &"grunt", 2.0 if heavy else 0.0)

	# A glint: this one is coming, in the colour of what it asks of you. A
	# kick or a fist gives none, only the knee or the fist drawn back; nor
	# does a thing drawn back to be thrown.
	var bare: bool = kind in [&"kick", &"bash", &"punch", &"jab", &"throw"]

	if not _glinted and u >= 0.64 and not bare:
		_glinted = true
		var tip := weapon.global_transform * _blade_tip
		var colour := GuardFighterScript.call_colour(call).lerp(Color(1.0, 0.96, 0.85), 0.35 if call != &"cut" else 1.0)
		Fx.glint(guard, tip, 0.24 if heavy or call == &"low" else 0.18, weapon, colour)
		# A point rings higher; low steel scrapes lower.
		var pitch := 0.7 if heavy else (1.35 if call == &"thrust" else (0.82 if call == &"low" else 1.0))
		Sfx.play(guard, &"ting", tip, 2.0 if heavy else 0.0, pitch)

	# The rush of the blade, timed so its loudest moment is the blow.
	if not _whooshed and u >= (0.85 if bare else 0.9):
		_whooshed = true
		var pitch := 1.0 / sqrt(size)

		if bare:
			Sfx.play(guard, &"whoosh_light", guard.global_position + Vector3.UP * 0.6, -2.0, 0.8)
		else:
			Sfx.play(guard, &"whoosh", weapon.global_position, 2.0 if heavy else 0.5, pitch * (0.78 if heavy else 0.92))
			Sfx.play(guard, &"whoosh_heavy", weapon.global_position, 6.0 if heavy else 0.0, pitch * 0.9)


# ---------------------------------------------------------------------------
# Every drawn frame: what the man shows, and where in it
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if man == null or guard == null or not is_instance_valid(guard) or man.get_parent() != self:
		return

	if _rising > 0.0:
		# Up off the floor: nothing else is shown until he is.
		_rising = maxf(_rising - _delta, 0.0)
		man.show_action(_rise_anim, (_rise_length - _rising) * _rise_speed, 0.0)

		if _rising <= 0.0:
			man.clear_action(0.25)

		return

	# Physics has him.
	if man.is_limp():
		return

	# Between physics ticks, how far into the next one this frame is drawn.
	var ahead := Engine.get_physics_interpolation_fraction() / float(maxi(Engine.physics_ticks_per_second, 1))
	man.set_motion(_velocity / size, guard.state >= SEARCHING, _delta)
	man.turn_head((_logical_head.rotation.y if _logical_head != null else 0.0) + _glance + (expression.head_yaw() if expression != null else 0.0))
	_animate(ahead)

	if expression != null:
		expression.update(_delta)

	# The trail follows the blade where it is drawn this frame.
	if _cutting and weapon.is_visible_in_tree():
		var blade := weapon.global_transform
		trail.push(blade * _blade_base, blade * _blade_tip)


func _animate(ahead: float) -> void:
	var now := _time + ahead
	var kicking: bool = guard._attack == &"kick" and guard._phase != &""
	_kick(ahead if kicking else -1.0)

	# A blow thrown on the move: his legs run under it.
	man.set_leg_drive(clampf((_velocity.length() / size - 1.2) / 2.5, 0.0, 0.85) if guard._phase != &"" and not kicking else 0.0)

	if _open_left > 0.0:
		_show_open(_open_length - _open_left + ahead)
		return

	if guard._knock > 0.0 or _flail > 0.0:
		# Kicked: bowled back, off balance, finding his feet.
		man.show_action(&"Idle_Shield_Break", _held_open(_flail_length - _flail + ahead, _flail_length, 0.2), 0.05, 0.9)
		return

	if _reel > 0.0:
		# Parried: his blade thrown wide, open, until he gathers himself.
		man.show_action(&"Idle_Shield_Break", _held_open(_reel_length - _reel + ahead, _reel_length, 0.25), 0.05, 0.88)
		return

	if guard._phase != &"" and not kicking:
		_show_blow(ahead)
		return

	var fighter: RefCounted = guard._fighter
	var parry: float = fighter.parry_pose() if fighter != null else 0.0

	if parry > 0.0 or _flourish > 0.0:
		man.show_action(&"Sword_Block", lerpf(0.02, 0.26, maxf(parry, _flourish / 0.25)), 0.04)
		return

	if guard._block_flash > 0.0 or (fighter != null and fighter.guarding):
		man.show_action(&"Sword_Block", 0.3, 0.06)
		return

	var since := now - _flinch_at

	if _flinch != &"" and not kicking and since < man.action_length(_flinch) - 0.05:
		man.show_action(_flinch, since, 0.04, REACT_WEIGHT)
		return

	if not kicking and _show_activity(now):
		return

	man.clear_action(0.2 if not kicking else 0.1)


## What he is doing with his hands or himself (Guard.activity): stooping for
## something, pulling the bell rope, a thing held back to throw, begging for
## his life, talking, arms folded, a pull from his flask, his lantern held
## up. True if shown.
func _show_activity(now: float) -> bool:
	var doing: StringName = guard.activity() if guard.has_method("activity") else &""

	if doing != _activity:
		_activity = doing
		_activity_at = now

	# At a station his blade is put away (GuardRota.sheathed), and drawn the
	# moment he is stirred: hidden, not dropped (`visible` says he has it).
	var rota: RefCounted = guard.get("_rota")
	var layers: int = 0 if rota != null and rota.sheathed() else Layers.ACTORS

	if weapon != null and weapon.layers != layers:
		weapon.layers = layers

	var since := now - _activity_at
	var hands: RefCounted = guard.get("_hands")

	match doing:
		&"":
			return false
		&"pickup":
			# Down to the floor and back up (a reach to the ground).
			man.show_action(&"Farm_Harvest", lerpf(0.15, 2.2, float(hands.pickup_progress())), 0.1)
			return true
		&"ring":
			man.show_action(&"Interact", lerpf(0.3, 2.3, float(hands.ring_progress())), 0.1)
			return true
		&"hold":
			# Drawn back at the shoulder, ready to throw; his legs his own.
			man.set_leg_drive(clampf(_velocity.length() / size - 0.3, 0.0, 0.85))
			man.show_action(&"OverhandThrow", 0.2, 0.15, 0.75)
			return true
		&"kneel", &"plead_kneel", &"rise_knees", &"plead_stand":
			_show_plea(doing, since)
			return true
		&"climb", &"ladder", &"hang", &"gather", &"fall", &"leap", &"land":
			_show_crossing(doing)
			return true
		&"sleep":
			# Lying still on his bedroll: the first moment of getting up.
			man.show_action(&"LayToIdle", 0.0, 0.3)
			return true
		&"carry":
			# A crate in his arms, stepping with it as he goes.
			var cycle := maxf(man.action_length(&"Walk_Carry"), 0.1)
			var pace := _velocity.length() / size
			man.show_action(&"Walk_Carry", fmod(since * clampf(pace / 1.4, 0.6, 1.3), cycle) if pace > 0.2 else 0.3, 0.2)
			return true
		&"sneak":
			# Crouched (the showcase's intruder): stepping low as he goes,
			# still when he stops.
			var low := maxf(man.action_length(SNEAK_CLIP), 0.1)
			var still := maxf(man.action_length(CROUCH_CLIP), 0.1)
			var pace := _velocity.length() / size

			if pace > 0.2:
				man.show_action(SNEAK_CLIP, fmod(since * clampf(pace / 1.3, 0.6, 1.4), low), 0.2)
			else:
				man.show_action(CROUCH_CLIP, fmod(since, still), 0.25)

			return true
		&"swim", &"tread":
			# Stroke by stroke as he goes; treading water where he is.
			var stroke := maxf(man.action_length(SWIM_CLIP), 0.1)
			var tread := maxf(man.action_length(TREAD_CLIP), 0.1)

			if doing == &"swim":
				man.show_action(SWIM_CLIP, fmod(since * clampf(_velocity.length() / size / 1.6, 0.6, 1.4), stroke), 0.25)
			else:
				man.show_action(TREAD_CLIP, fmod(since, tread), 0.3)

			return true

	if STATION_MOVES.has(doing):
		var move: Array = STATION_MOVES[doing]
		var length := maxf(man.action_length(move[0]), 0.1)
		var at := minf(since, length - 0.02)
		man.show_action(move[0], length - 0.02 - at if bool(move[1]) else at, float(move[2]))
		return true

	var spec: Array = ACTIVITIES.get(doing, [])

	if spec.is_empty():
		return false

	var clip: StringName = spec[0]
	var length := maxf(man.action_length(clip), 0.1)
	var t: float = fmod(since, length) if bool(spec[1]) else minf(since, length - 0.02)
	man.show_action(clip, t, float(spec[2]), float(spec[3]))
	return true


## Crossing what walking cannot (GuardClimb): hauling himself up (the
## climbing clip, paced by how far he has climbed), hanging off an edge,
## gathered for a jump, in the air, and landing.
func _show_crossing(doing: StringName) -> void:
	var climb: RefCounted = guard.get("_climb")
	var u: float = float(climb.progress()) if climb != null else 0.0

	match doing:
		&"climb", &"ladder":
			var metres: float = float(climb.climbed()) if climb != null else 0.0
			man.show_action(CLIMB_CLIP, fmod(metres * CLIMB_CYCLE, CLIMB_CYCLE), 0.1)
		&"hang":
			man.show_action(CLIMB_CLIP, 0.13, 0.15)
		&"gather":
			man.show_action(LAND_CLIP, lerpf(0.95, 0.35, u), 0.08)
		&"fall", &"leap":
			man.show_action(AIR_CLIP, 0.6, 0.1)
		&"land":
			man.show_action(LAND_CLIP, lerpf(0.25, 0.9, u), 0.05)


## Begging for his life (GuardMercy): going down on his knees, bowed low on
## them and rocking as he begs, getting up off them; or on his feet with a
## hand held out to you.
func _show_plea(doing: StringName, since: float) -> void:
	var mercy: RefCounted = guard.get("_mercy")
	var progress: float = float(mercy.progress()) if mercy != null else 1.0

	match doing:
		&"kneel":
			man.show_action(PLEA_KNEEL, lerpf(0.0, PLEA_KNEEL_DOWN, progress), 0.12)
		&"plead_kneel":
			var sway := pingpong(since * 0.45, PLEA_KNEEL_SWAY.y - PLEA_KNEEL_SWAY.x)
			man.show_action(PLEA_KNEEL, PLEA_KNEEL_SWAY.x + sway, 0.12)
		&"rise_knees":
			man.show_action(PLEA_KNEEL, lerpf(PLEA_KNEEL_UP, man.action_length(PLEA_KNEEL) - 0.05, progress), 0.08)
		&"plead_stand":
			man.show_action(PLEA_STAND, fmod(since, maxf(man.action_length(PLEA_STAND), 0.1)), 0.25, 0.9)


## A gesture (a conversation's emote: Guard.emote).
func emote(what: String) -> void:
	if expression != null:
		expression.emote(what)


## Where a thing he picks up to throw sits in his hand (GuardHands).
func throwing_hand() -> Node3D:
	if _held_point == null or not is_instance_valid(_held_point):
		_held_point = Node3D.new()
		_held_point.name = "Held"
		man.attach(&"hand_r", _held_point)

	return _held_point


## His weapon in his hand again: his own, or one of `kind` picked up off the
## floor (a sword where he had a rapier: it is what he fights with now).
func take_weapon(kind: StringName) -> void:
	if weapon == null:
		return

	if kind != _carried and not (kind == &"crossbow") and not _crossbow:
		_carried = kind
		weapon.mesh = WeaponScript.guard_weapon_mesh(kind)
		weapon.transform = _grip

		for i in range(weapon.get_surface_override_material_count()):
			weapon.set_surface_override_material(i, null)

		_steel.clear()
		_readable()
		_blade_base = weapon.mesh.get_meta(&"blade_base", BLADE_BASE)
		_blade_tip = weapon.mesh.get_meta(&"blade_tip", BLADE_TIP)

		if _blade_blood != null:
			_blade_blood.set_shader_parameter("blade_base", _blade_base)
			_blade_blood.set_shader_parameter("blade_tip", _blade_tip)

	weapon.visible = true


## A reel's time in its animation: thrown back over `open`, held there, and
## the last half second finding his feet again.
static func _held_open(elapsed: float, length: float, open: float) -> float:
	var left := length - elapsed

	if elapsed < open:
		return elapsed

	if left > 0.5:
		return open

	return lerpf(open, 0.9, 1.0 - left / 0.5)


## The kick laid over his stance: the knee up through the windup, the heel
## driven out in the strike, the leg back down in the recovery.
func _kick(ahead: float) -> void:
	if ahead < 0.0:
		man.kick_pose(0.0, 0.0)
		return

	var u := _phase_u(ahead)

	match guard._phase:
		&"windup":
			man.kick_pose(1.0 - (1.0 - u) * (1.0 - u), 0.0)
		&"strike":
			man.kick_pose(1.0, minf(u * 2.5, 1.0))
		_:
			var down := clampf(u / 0.6, 0.0, 1.0)
			man.kick_pose(1.0 - down, 1.0 - down)


func _show_blow(ahead: float) -> void:
	var kind: StringName = guard._attack
	var phase: StringName = guard._phase
	var u := _phase_u(ahead)

	if kind == &"shoot":
		match phase:
			&"windup":
				if u < 0.6:
					# Spanning it: the reload, sped to fit.
					man.show_action(&"Pistol_Reload", lerpf(0.2, 1.9, u / 0.6))
				else:
					man.show_action(&"Pistol_Aim_Neutral", 0.1, 0.12)
			&"strike":
				man.show_action(&"Pistol_Shoot", u * 0.2, 0.02)
			_:
				if u < 0.75:
					man.show_action(&"Pistol_Shoot", 0.2 + u * 0.6)
				else:
					man.clear_action(0.25)
		return

	var spec: Dictionary = SWINGS.get(kind, SWINGS[&"overhead"])
	var clip: StringName = spec["clip"]
	var weight: float = spec.get("weight", 0.85)

	match phase:
		&"windup":
			man.show_action(clip, windup_time_in(spec, u, maxf(float(guard._phase_length), 0.01)), 0.08, weight)
		&"strike":
			# Through the blow and slowing: the weight of the blade carries on.
			man.show_action(clip, lerpf(spec["contact"], spec["follow"], _ease_out(u)), 0.08, weight)
		_:
			var rec: Array = spec.get("rec", [])

			if _bounced and u < 0.3:
				# Off your guard: the blade comes back the way it went.
				man.show_action(clip, lerpf(spec["follow"], spec["cocked"], _ease_out(u / 0.3)), 0.08, weight)
			elif _bounced:
				man.clear_action(0.3)
			elif not rec.is_empty():
				# The follow-through eases out, then back to his guard.
				if u < 0.3 and float(spec["done"]) > float(spec["follow"]):
					man.show_action(clip, lerpf(spec["follow"], spec["done"], _ease_out(u / 0.3)), 0.08, weight)
				elif u < 0.92:
					var back := clampf((u - (0.3 if float(spec["done"]) > float(spec["follow"]) else 0.0)) / 0.62, 0.0, 1.0)
					man.show_action(rec[0], lerpf(rec[1], rec[2], smoothstep(0.0, 1.0, back)), 0.12, weight * 0.95)
				else:
					man.clear_action(0.25)
			elif u < 0.7:
				man.show_action(clip, lerpf(spec["follow"], spec["done"], _ease_out(u / 0.7)), 0.08, weight)
			else:
				man.clear_action(0.3)


## Where in its clip a windup `u` of the way through (of `length` seconds)
## is: up to the cocked pose quickly, easing into it; held there; then let go,
## gathering speed into the blow, over the swing's release time.
static func windup_time_in(spec: Dictionary, u: float, length: float) -> float:
	var release := clampf(float(spec.get("release", 0.12)) / length, 0.12, 0.6)
	var gather := 0.45 * (1.0 - release)
	var hold_end := 1.0 - release

	if u < gather:
		return lerpf(spec["from"], spec["cocked"], _ease_out(u / gather))

	if u < hold_end:
		return spec["cocked"]

	var t := (u - hold_end) / release
	return lerpf(spec["cocked"], spec["contact"], t * t)


static func _ease_out(x: float) -> float:
	var k := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


## Open: flung back, down onto one knee, his blade low, and at the last
## getting up again.
func _show_open(elapsed: float) -> void:
	var left := _open_length - elapsed

	if elapsed < 0.16:
		man.show_action(&"Idle_Shield_Break", elapsed * 1.1, 0.04)
	elif left > 0.45:
		var down := clampf((elapsed - 0.16) / 0.3, 0.0, 1.0)
		# Down fast, then his shoulders heave.
		man.show_action(OPEN_CLIP, lerpf(0.3, 0.7, _ease_out(down)) + 0.08 * sin(elapsed * 5.0) * down, 0.08)
	else:
		man.show_action(OPEN_CLIP, lerpf(0.7, 0.15, 1.0 - left / 0.45), 0.08)


## How his voice is pitched (Guard.voice).
func voice_pitch() -> float:
	return _voice_pitch


## How high his weapon hand is above his feet: for tests.
func grip_height() -> float:
	return weapon.global_position.y - guard.global_position.y


## Seconds from death until he hits the floor (GuardBody times its thud).
func fall_time(killed: bool) -> float:
	var how: Array = DEATH if killed else KNOCKOUT
	return (IMPACT - float(how[1])) / float(how[2])


# ---------------------------------------------------------------------------
# Reactions, called by the guard
# ---------------------------------------------------------------------------

## Struck: he tips away from the blow and flinches. `strength` 0.6 a quick
## cut, 1 a heavy one, 1.5 a killing blow.
func react_hit(direction: Vector3, strength: float) -> void:
	var d := _local_flat(direction)
	_hurt_dir = d
	_tilt_v += d * 1.5 * strength
	_offset_v += d * 0.6 * strength
	_jolt_v += Vector3.UP.cross(d).normalized() * 2.2 * strength
	_flash = 1.0
	_flinch = &"Hit_Head" if strength >= 0.9 and randf() < 0.5 else &"Hit_Chest"
	_flinch_at = _time


## He caught your blow on his blade.
func react_block(direction: Vector3) -> void:
	var d := _local_flat(direction)
	_offset_v += d * 0.6
	_tilt_v += d * 0.8
	_jolt_v += Vector3(0.0, 0.0, 4.0)


## His blow met your raised blade: it bounces back and so does he.
func react_blocked() -> void:
	_bounced = true
	_jolt_v += Vector3(5.0, 0.0, 0.0)
	_offset_v += Vector3(0.0, 0.0, 0.8)
	_tilt_v += Vector3(0.0, 0.0, 1.2)


## Parried: the blade flung up and back, and he reels, open, for `seconds`.
func react_parried(seconds: float) -> void:
	_reel = seconds
	_reel_length = maxf(seconds, 0.3)
	_bounced = false
	_tilt_v += Vector3(0.0, 0.0, 2.4)
	_offset_v += Vector3(0.0, 0.0, 0.9)
	_jolt_v += Vector3(-6.0, 0.0, 2.0)


## Off his balance (his posture broken): down and open for `seconds`.
func react_open(seconds: float) -> void:
	_open_left = seconds
	_open_length = maxf(seconds, 0.6)
	_reel = 0.0
	_flail = 0.0
	_bounced = false
	_tilt_v += Vector3(0.0, 0.0, 2.8)
	_offset_v += Vector3(0.0, 0.0, 0.8)
	_jolt_v += Vector3(-7.0, 0.0, 3.0)


## The deathblow landed, or he found his feet: no longer open.
func end_open() -> void:
	_open_left = 0.0


func is_open_shown() -> bool:
	return _open_left > 0.0


## A riposte caught him in the middle of his reel: the reel is over, and the
## blow's own flinch shows instead.
func end_reel() -> void:
	_reel = 0.0


## He turned your blow aside: a flourish of the blade.
func react_parry_success() -> void:
	_flourish = 0.25
	_jolt_v += Vector3(-3.0, 0.0, -2.5)
	_tilt_v += Vector3(0.0, 0.0, -1.0)


## A quick step away from a blow.
func react_dodge(step: Vector3) -> void:
	_tilt_v += _local_flat(step) * 1.8


## Kicked: he is bowled back with the push, off balance for `seconds`.
func react_kick(push: Vector3, seconds: float) -> void:
	var d := _local_flat(push)
	_push_dir = d
	_flail = seconds
	_flail_length = maxf(seconds, 0.3)
	_tilt_v += d * 3.2
	_jolt_v += Vector3(3.0, 0.0, 0.0)


## Came down hard.
func react_land(speed: float) -> void:
	_offset_v.y -= clampf(speed * 0.08, 0.0, 1.2)
	_tilt_v += _push_dir * clampf(speed * 0.05, 0.0, 0.8)


# ---------------------------------------------------------------------------
# Marks on him
# ---------------------------------------------------------------------------

## A wound where he was cut, painted on him; it moves with the part of him
## that was cut.
func add_wound(point: Vector3, wound_size := 0.22) -> void:
	if man == null:
		return

	var bone := _nearest_bone(point)
	var centre: Vector3 = man.bone_global(bone).origin
	var normal := point - centre
	normal = normal.normalized() if normal.length() > 0.001 else guard.global_basis.z
	var decal := Fx.wound(_holder(bone), point, normal, wound_size)

	if decal == null:
		return

	_wounds.append(decal)

	if _wounds.size() > MAX_WOUNDS:
		_wounds.pop_front().queue_free()


## An arrow that went in stays in, sticking out the way it came.
func embed_arrow(point: Vector3, direction: Vector3) -> void:
	if man == null or direction.length() < 0.001:
		return

	var dir := direction.normalized()
	var shaft := MeshInstance3D.new()
	shaft.name = "Arrow"
	shaft.set_meta(&"embedded_arrow", true)
	shaft.mesh = WeaponScript.arrow_mesh()
	shaft.layers = Layers.ACTORS
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_holder(_nearest_bone(point)).add_child(shaft, true)
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	# The head a hand's depth in, the shaft and fletching outside.
	shaft.global_transform = Transform3D(Basis.looking_at(dir, up), point - dir * 0.12)
	_arrows.append(shaft)

	if _arrows.size() > MAX_ARROWS:
		_arrows.pop_front().queue_free()


func _nearest_bone(point: Vector3) -> StringName:
	var best: StringName = &"spine_02"
	var gap := INF

	for bone in FLESH_BONES:
		var d: float = man.bone_global(bone).origin.distance_to(point)

		if d < gap:
			gap = d
			best = bone

	return best


## What rides on `bone`: marks go on it and move with it.
func _holder(bone: StringName) -> Node3D:
	if not _holders.has(bone) or not is_instance_valid(_holders[bone]):
		var holder := BoneAttachment3D.new()
		holder.name = "Marks_" + bone
		holder.bone_name = bone
		man.skeleton.add_child(holder)
		_holders[bone] = holder

	return _holders[bone]


## A killing wound pumps for a while: from `point`, out of him and along
## the blow.
func spurt(point: Vector3, blow: Vector3, seconds := 1.4) -> void:
	if man == null:
		return

	var bone := _nearest_bone(point)
	var centre: Vector3 = man.bone_global(bone).origin
	var out: Vector3 = point - centre
	out = out.normalized() if out.length() > 0.001 else blow
	var holder := _holder(bone)
	var local := holder.global_transform.affine_inverse()
	var direction: Vector3 = (out + blow.normalized() * 0.4).normalized()
	Fx.spurt(holder, local * point, local.basis * direction, seconds)


## Let go of the shader materials laid over his meshes before they are freed.
func _exit_tree() -> void:
	if weapon != null:
		weapon.material_overlay = null

	if man != null and is_instance_valid(man):
		for worn in man.worn():
			if worn.material_overlay == _overlay:
				worn.material_overlay = null


## His blade drew blood: it shows on the steel.
func bloody(amount: float) -> void:
	if _blade_blood == null:
		return

	_blood_on_blade = clampf(_blood_on_blade + amount, 0.0, 1.0)
	_blade_blood.set_shader_parameter("amount", _blood_on_blade)
	_blade_blood.set_shader_parameter("wet", 1.0)


func blood_on_blade() -> float:
	return _blood_on_blade


func wound_count() -> int:
	return _wounds.size()


func arrow_count() -> int:
	return _arrows.size()


## The middle of him, for effects.
func chest() -> Vector3:
	if man == null or man.skeleton == null:
		return guard.global_position + guard.global_basis.y * 1.25 * size

	return man.bone_global(&"spine_03").origin


# ---------------------------------------------------------------------------
# Death
# ---------------------------------------------------------------------------

## He lets go of his weapon: it falls and clatters. Nothing picks it up yet.
func drop_weapon() -> RigidBody3D:
	if weapon == null or not weapon.visible:
		return null

	var sword := RigidBody3D.new()
	sword.name = "DroppedSword"
	sword.mass = 1.6
	# It rests on the world and nothing else: not a step for your feet, not a
	# thing the frob ray finds, not a body for the guards.
	sword.collision_layer = 0
	sword.collision_mask = 1
	sword.continuous_cd = true

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var bounds := weapon.mesh.get_aabb()
	box.size = Vector3(maxf(bounds.size.x, 0.04), maxf(bounds.size.y, 0.04), maxf(bounds.size.z, 0.04))
	shape.shape = box
	shape.position = bounds.get_center()
	sword.add_child(shape)

	var visual := MeshInstance3D.new()
	visual.mesh = weapon.mesh

	for i in range(weapon.mesh.get_surface_count()):
		visual.set_surface_override_material(i, weapon.get_surface_override_material(i))

	sword.add_child(visual)

	sword.contact_monitor = true
	sword.max_contacts_reported = 2
	var clatters := [0]
	sword.body_entered.connect(
		func(_other: Node) -> void:
			if clatters[0] < 3 and sword.linear_velocity.length() > 1.0:
				clatters[0] += 1
				Sfx.play(sword, &"clank", sword.global_position, -6.0 - clatters[0] * 4.0, 1.1)
	)

	var parent := guard.get_parent()
	var held := weapon.global_transform.orthonormalized()
	sword.transform = (parent as Node3D).global_transform.affine_inverse() * held if parent is Node3D else held
	sword.linear_velocity = guard.velocity * 0.5 + Vector3(randf_range(-1.0, 1.0), 1.4, randf_range(-1.0, 1.0))
	sword.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0), randf_range(-6.0, 6.0))
	parent.add_child(sword)
	weapon.visible = false
	_cutting = false
	trail.clear()
	sword.reset_physics_interpolation()
	return sword


## He becomes his body: the man goes onto it and falls (the death animation),
## wounds, arrows and all, to lie where its capsule lies. The capsule is what
## you frob and carry; the man is what you see.
## The man goes to his body, and falls as physics has him: from how he
## stood, moving as he was, the part at `at` shoved by `push` (the blow).
## Already down (kicked off his feet), he just goes on falling.
func transfer_to(corpse: Node3D, push := Vector3.ZERO, at := Vector3.INF) -> void:
	if man == null:
		return

	var stand_in := corpse.get_node_or_null("Visual") as Node3D

	if stand_in != null:
		stand_in.visible = false

	_rising = 0.0
	var world := man.global_transform
	remove_child(man)
	corpse.add_child(man)
	# His own place in the world, not the body's: the body follows him.
	man.top_level = true
	man.global_transform = world

	if man.ragdoll != null:
		man.ragdoll.owner_node = corpse

	if man.ragdoll == null:
		var how: Array = DEATH if bool(corpse.get("dead")) else KNOCKOUT
		man.play_once(how[0], how[2], how[1])
	elif not man.is_limp():
		man.go_limp(guard.velocity)

	if man.ragdoll != null and push != Vector3.ZERO:
		man.ragdoll.shove(push, at)

	_wounds.clear()
	_arrows.clear()
	_holders.clear()


## Cut apart (Humanoid.sever): each of `bones` goes off along `push`, up
## and away, with a spin.
func sever(bones: Array[StringName], push: Vector3) -> Array:
	var pieces := []

	if man == null:
		return pieces

	for bone in bones:
		var away := push * randf_range(1.1, 1.5) + Vector3.UP * (2.4 if bone == &"neck_01" else 1.2) + guard.velocity
		var piece: RigidBody3D = man.sever(bone, away)

		if piece != null:
			pieces.append(piece)

	# Bone going: once, loud, for the first part off him; the rest under it.
	for i in range(pieces.size()):
		Sfx.play(guard, &"bone_crack", (pieces[i] as Node3D).global_position, 0.0 if i == 0 else -6.0, randf_range(0.92, 1.05))

	return pieces


## Knocked off his feet (a kick, a blast, another man flung into him):
## physics has him, all of him moving at `velocity`, the part at `at`
## shoved by `push` besides.
func go_limp(velocity: Vector3, push := Vector3.ZERO, at := Vector3.INF) -> void:
	if man == null or man.ragdoll == null:
		return

	var world := man.global_transform
	man.top_level = true
	man.global_transform = world
	_rising = 0.0
	_cutting = false
	trail.clear()
	man.go_limp(velocity)

	if push != Vector3.ZERO:
		man.ragdoll.shove(push, at)


func is_down() -> bool:
	return man != null and man.is_limp() and _rising <= 0.0


## Back on his feet, from lying on his back (`face_up`) or his front: the man
## is the rig's again (the guard has been put where he lies), the pose he
## lies in gives way to getting up. How long it takes, seconds.
func get_up(face_up: bool) -> float:
	if man == null:
		return 0.0

	man.top_level = false
	man.transform = Transform3D.IDENTITY
	# He is put back in one step: his cloth starts afresh, not whipped after.
	man.restart_cloth()
	man.wake()

	if face_up:
		# Sits up and stands, from flat on his back.
		_rise_anim = &"LayToIdle"
		_rise_speed = 1.15
		_rise_length = man.action_length(_rise_anim) / _rise_speed - 0.05
	else:
		# Pushes himself up onto his knees, and stands.
		_rise_anim = &"Crouch_Idle"
		_rise_speed = 1.0
		_rise_length = 0.75

	_rising = _rise_length
	man.show_action(_rise_anim, 0.0, 0.0)

	if man.ragdoll != null:
		man.ragdoll.recover(0.4)

	return _rise_length


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## A world direction as a flat direction in the guard's own space.
func _local_flat(direction: Vector3) -> Vector3:
	var d: Vector3 = guard.global_basis.inverse() * direction
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.BACK
