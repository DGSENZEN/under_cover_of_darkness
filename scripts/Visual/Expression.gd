extends RefCounted
## GuardRig presentation state: gaze, temperament posture/gait, breathing, weight shifts, limps, and hand gestures.
## GuardRig calls update() each drawn frame. AI does not read these results.
## Seeded per-person variation and slow noise keep idle motion and gestures distinct.

const TalkScript := preload("res://scripts/AISystem/Talk/TalkScript.gd")

## Reached at run time: they read the rig's scripts in turn.
const TALK_DIRECTOR := "res://scripts/AISystem/Talk/TalkDirector.gd"
const GATHERING := "res://scripts/AISystem/Gathering.gd"

## Guard.Alert.
const SUSPICIOUS := 1
const COMBAT := 4

## By temperament: [chest_lean, shoulders, head_bow] (Posture).
const POSTURE := {
	&"rash": [0.06, 0.0, -0.05],
	&"craven": [0.12, 0.45, 0.12],
	&"stubborn": [-0.04, -0.1, -0.03],
	&"sly": [0.08, 0.15, 0.05],
	&"steady": [0.0, 0.0, 0.0],
}
## By temperament: [pace, stride].
const GAIT := {
	&"rash": [1.06, 1.1],
	&"craven": [1.03, 0.85],
	&"stubborn": [0.95, 1.0],
	&"sly": [1.0, 0.95],
	&"steady": [1.0, 1.0],
}
## How big his hands are when he talks.
const GESTURE := {&"rash": 1.0, &"steady": 0.7, &"craven": 0.5, &"stubborn": 0.4, &"sly": 0.25}
## How far and how often his eyes wander: [every (s), how far (rad)].
const DARTS := {&"sly": [Vector2(1.0, 2.5), 0.35], &"craven": [Vector2(1.0, 2.5), 0.35]}
const DARTS_CALM := [Vector2(3.0, 6.0), 0.15]
## How far his head turns (either way) and bows or lifts.
const GAZE_YAW := 1.2
const GAZE_PITCH := 0.6
## A man walking past this near, this fast, catches his eye; a fire this near.
const PASSER_NEAR := 4.0
const PASSER_SPEED := 0.8
## How often he looks round for someone passing (seconds): the one he saw
## holds his eye in between.
const PASSER_EVERY := 0.3
const FIRE_NEAR := 6.0
## Gestures from emotes: [clip, seconds] on the upper body.
const EMOTE_CLIPS := {
	"nods": [&"Yes", 1.2], "shakes": [&"Idle_No", 1.2], "drinks": [&"Consume", 1.33],
	"points": [&"Spell_Simple_Shoot", 0.62], "throws": [&"OverhandThrow", 0.9], "nudges": [&"Push", 1.5],
}
## Gestures made with the body alone: seconds.
const EMOTE_PULSES := {"shrugs": 0.6, "laughs": 1.0, "sighs": 1.2, "coughs": 0.8, "spits": 0.5, "kicks": 0.5}
## What he does with his hands (Guard.activity) on the upper body: [clip,
## weight].
const UPPER_ACTIVITIES := {
	&"fold_arms": [&"Idle_FoldArms", 0.9], &"listen": [&"Idle_FoldArms", 0.6], &"drink": [&"Consume", 0.9],
	&"scratch": [&"Zombie_Scratch", 0.85], &"warm_hands": [&"Spell_Simple_Idle", 0.85], &"check_blade": [&"Sword_Idle", 0.8],
	&"carry_log": [&"Walk_Carry", 0.9],
}
## Weight shifts at rest: this often (s, x his rhythm), this far.
const SHIFT_EVERY := Vector2(3.0, 7.0)
const SHIFT_SIZE := Vector2(0.4, 1.0)
## The captain passing straightens a man for this long.
const STRAIGHTEN := 2.0

static var _director_script: GDScript = null
static var _gathering_checked := false
static var _gathering_script: GDScript = null

var rig: Node3D
var guard: CharacterBody3D
## His variation (`variation`).
var traits: Dictionary = {}

var _time := 0.0
var _yaw := 0.0
var _pitch := 0.0
## How much his gaze has the head (0: the AI's own look; 1: what holds his
## eye, measured from his body).
var _weight := 0.0
var _dart := 0.0
var _dart_goal := 0.0
var _dart_in := 1.0
var _dart_hold := 0.0
var _gesture: StringName = &""
var _gesture_at := 0.0
var _gesture_for := 0.0
var _pulses := {}
var _shift_in := 2.0
var _calm := 1.0
var _straight_left := 0.0
var _noise := FastNoiseLite.new()
var _seed := 0
var _since_doing: StringName = &""
var _since_at := 0.0
var _passer: CharacterBody3D = null
var _passer_at := 0.0


func _init(p_rig: Node3D) -> void:
	rig = p_rig
	guard = rig.guard
	_seed = int(rig.call(&"_look_seed"))
	traits = variation(_seed, StringName(guard.get("archetype")), _tag())
	_noise.seed = _seed
	_noise.frequency = 0.05
	# Not every man looks round on the same frame.
	_passer_at = float(absi(_seed) % 100) / 100.0 * PASSER_EVERY
	var man: Node3D = rig.man
	man.set("stride", float(GAIT.get(_tag(), [1.0, 1.0])[1]))

	if _is_captain():
		man.set_walk_clip(&"Walk_Formal")


## His own ways, drawn from `seed` around what his kind and temperament
## would have: {walk, rhythm, breath, gesture, darts}.
static func variation(seed: int, _kind: StringName, tag: StringName) -> Dictionary:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash(seed * 31 + 7)
	var gesture: float = GESTURE.get(tag, 0.7)
	return {
		"walk": clampf(dice.randfn(1.0, 0.04), 0.92, 1.08),
		"rhythm": clampf(dice.randfn(1.0, 0.12), 0.8, 1.25),
		"breath": clampf(dice.randfn(1.0, 0.08), 0.85, 1.15),
		"gesture": clampf(dice.randfn(gesture, 0.15), gesture * 0.6, gesture * 1.4),
		"darts": clampf(dice.randfn(1.0, 0.25), 0.5, 1.6),
	}


## How much faster or slower than his kind he walks at his ease (Guard sets
## his patrol speed by it once).
static func walk_scale(seed: int, kind: StringName, tag: StringName) -> float:
	return float(variation(seed, kind, tag)["walk"]) * float(GAIT.get(tag, [1.0, 1.0])[0])


## This man's walk_scale.
func walk_factor() -> float:
	return float(traits.get("walk", 1.0)) * float(GAIT.get(_tag(), [1.0, 1.0])[0])


## Where what holds his eye is, from his body: radians, positive to his
## left (GuardRig blends his head to it by `gaze_weight`).
func head_yaw() -> float:
	return _yaw


## How much his head is his gaze's, not the AI's look (0..1).
func gaze_weight() -> float:
	return _weight


## The small darts of his eyes, on top of wherever his head is.
func dart() -> float:
	return _dart


## How far he bows his head (radians, positive down).
func head_pitch() -> float:
	return _pitch


## A gesture: an emote of a conversation ("nods", "laughs", "points:the
## tower"...).
func emote(what: String) -> void:
	var word := what.get_slice(":", 0)

	if EMOTE_CLIPS.has(word):
		_gesture = EMOTE_CLIPS[word][0]
		_gesture_at = _time
		_gesture_for = float(EMOTE_CLIPS[word][1])
	elif EMOTE_PULSES.has(word):
		_pulses[word] = float(EMOTE_PULSES[word])


## Every drawn frame, from GuardRig._process.
func update(delta: float) -> void:
	_time += delta
	var man: Node3D = rig.man

	if man == null or man.get("posture") == null:
		return

	var posture: Object = man.posture
	var state := int(guard.get("state"))
	var fighting: bool = state >= COMBAT or guard.is_downed()
	# In a fight all this gives way to his stance.
	_calm = move_toward(_calm, 0.0 if fighting else 1.0, delta * 3.0)
	var drift := 1.0 + 0.1 * _noise.get_noise_1d(_time)

	for key in _pulses.keys():
		_pulses[key] = float(_pulses[key]) - delta

		if float(_pulses[key]) <= 0.0:
			_pulses.erase(key)

	_update_gaze(delta, state, drift)
	_update_posture(posture, delta)
	_update_weight(posture, delta, drift)
	_update_hands(man, fighting)


# Where he looks

func _update_gaze(delta: float, state: int, drift: float) -> void:
	var target: Variant = _gaze_target(state) if state <= SUSPICIOUS and _calm > 0.5 else null
	var yaw := 0.0
	var pitch := 0.0

	if target is Vector3:
		var local: Vector3 = guard.global_basis.inverse() * ((target as Vector3) - guard.eye_position())
		yaw = clampf(atan2(-local.x, -local.z), -GAZE_YAW, GAZE_YAW)
		var flat := Vector2(local.x, local.z).length()
		pitch = clampf(atan2(-local.y, maxf(flat, 0.01)), -GAZE_PITCH, GAZE_PITCH)

	var follow := 1.0 - exp(-8.0 * delta)
	_yaw = lerpf(_yaw, yaw, follow)
	_pitch = lerpf(_pitch, pitch * _calm, follow)
	_weight = lerpf(_weight, _calm if target is Vector3 else 0.0, 1.0 - exp(-6.0 * delta))

	# Small darts of the eyes (and so the head) on top.
	var darts: Array = DARTS.get(_tag(), DARTS_CALM)
	_dart_in -= delta * float(traits.get("darts", 1.0)) * drift

	if _dart_in <= 0.0:
		var every: Vector2 = darts[0]
		_dart_in = randf_range(every.x, every.y)
		_dart_goal = randf_range(-1.0, 1.0) * float(darts[1])
		_dart_hold = randf_range(0.4, 1.0)

	_dart_hold -= delta

	if _dart_hold <= 0.0:
		_dart_goal = 0.0

	_dart = lerpf(_dart, _dart_goal * _calm, 1.0 - exp(-12.0 * delta))


## What holds his eye now; null for straight ahead.
func _gaze_target(state: int) -> Variant:
	var target: Variant = guard.get("_target")

	if bool(guard.get("can_see_target")) and target != null and is_instance_valid(target):
		return (target as Node3D).global_position + Vector3.UP * 1.5

	if state == SUSPICIOUS and bool(guard.get("has_last_known")):
		return guard.get("last_known_position")

	var director := _director()

	if director != null:
		var speaker: Variant = director.speaker_near(guard)

		if speaker != null and is_instance_valid(speaker) and speaker.has_method("eye_position"):
			return speaker.eye_position()

	if _time >= _passer_at:
		_passer_at = _time + PASSER_EVERY
		_passer = null

		for other in guard.get_tree().get_nodes_in_group(&"guards"):
			if other != guard and other is CharacterBody3D and _passing(other as CharacterBody3D):
				_passer = other as CharacterBody3D
				break

	if _passer != null and is_instance_valid(_passer) and _passing(_passer):
		return _passer.eye_position() if _passer.has_method("eye_position") else _passer.global_position + Vector3.UP * 1.6

	var doing: StringName = guard.activity() if guard.has_method("activity") else &""

	if doing == &"warm_hands" or doing == &"squat":
		for fire in guard.get_tree().get_nodes_in_group(&"fires"):
			if (fire as Node3D).global_position.distance_to(guard.global_position) < FIRE_NEAR:
				return (fire as Node3D).global_position

	if doing == &"look_up":
		for mark in guard.get_tree().get_nodes_in_group(&"landmarks"):
			if String(mark.get_meta(&"landmark", "")) == "the tower":
				return (mark as Node3D).global_position + Vector3.UP * 2.0

	return null


## Someone going by near him, quick enough to look at.
func _passing(body: CharacterBody3D) -> bool:
	return body.is_inside_tree() and body.global_position.distance_to(guard.global_position) < PASSER_NEAR \
		and Vector2(body.velocity.x, body.velocity.z).length() > PASSER_SPEED


# How he stands

func _update_posture(posture: Object, delta: float) -> void:
	var row: Array = POSTURE.get(_tag(), POSTURE[&"steady"])
	var lean := float(row[0])
	var shoulders := float(row[1])
	var bow := float(row[2])
	var fear := _fear()

	if fear > 0.0:
		var craven: Array = POSTURE[&"craven"]
		lean += float(craven[0]) * fear
		shoulders += float(craven[1]) * fear
		bow += float(craven[2]) * fear

	if float(guard.get("grief") if guard.get("grief") != null else 0.0) > 0.5:
		shoulders -= 0.4

	# The captain passing: he straightens.
	if _captain_near():
		_straight_left = STRAIGHTEN

	_straight_left = maxf(_straight_left - delta, 0.0)

	if _straight_left > 0.0:
		var upright: Array = POSTURE[&"stubborn"]
		lean = float(upright[0])
		shoulders = float(upright[1])
		bow = float(upright[2])

	# The body's own gestures (a shrug, a laugh, a sigh...).
	if _pulses.has("shrugs"):
		shoulders += 0.8 * sin(PI * (1.0 - float(_pulses["shrugs"]) / float(EMOTE_PULSES["shrugs"])))

	if _pulses.has("laughs"):
		bow -= 0.15
		shoulders += 0.15 * sin(_time * 30.0)

	if _pulses.has("sighs"):
		shoulders -= 0.4 * sin(PI * (1.0 - float(_pulses["sighs"]) / float(EMOTE_PULSES["sighs"])))

	if _pulses.has("coughs"):
		bow += 0.2 * absf(sin(_time * 12.0))

	if _pulses.has("spits"):
		bow += 0.25

	if _pulses.has("kicks"):
		var u := 1.0 - float(_pulses["kicks"]) / float(EMOTE_PULSES["kicks"])
		rig.man.kick_pose(sin(PI * u) * 0.6, u)

	posture.set("chest_lean", lean * _calm)
	posture.set("shoulders", shoulders * _calm)
	posture.set("head_bow", (bow + _pitch) * _calm)
	posture.set("chest_yaw", 0.25 * _yaw * _weight)

	# His chest, breathing.
	var voice: Variant = guard.get("_voice")

	if voice != null:
		voice.breath_scale = float(traits.get("breath", 1.0))
		var depth := lerpf(0.4, 1.0, clampf((float(voice.heart) - 60.0) / 110.0, 0.0, 1.0))
		posture.set("breath", (0.5 - 0.5 * cos(TAU * float(voice.breath_phase()))) * depth)


func _update_weight(posture: Object, delta: float, drift: float) -> void:
	var still := Vector2(guard.velocity.x, guard.velocity.z).length() < 0.2
	_shift_in -= delta * drift

	if still and _shift_in <= 0.0:
		_shift_in = randf_range(SHIFT_EVERY.x, SHIFT_EVERY.y) * float(traits.get("rhythm", 1.0))
		posture.set("hip_shift", randf_range(SHIFT_SIZE.x, SHIFT_SIZE.y) * (1.0 if randf() < 0.5 else -1.0) * _calm)
	elif not still:
		posture.set("hip_shift", 0.0)

	# Stamping his feet against the cold.
	var doing: StringName = guard.activity() if guard.has_method("activity") else &""

	if doing == &"stamp":
		posture.set("hip_shift", sin(_time * TAU * 3.0))

	var most := maxf(float(guard.get("max_health")), 1.0)
	var whole := clampf(float(guard.get("health")) / most, 0.0, 1.0)
	posture.set("limp", clampf(1.0 - whole / 0.5, 0.0, 1.0))
	posture.set("limp_phase", fposmod(float(rig.get("_walk_phase")) / TAU, 1.0))


# His hands

func _update_hands(man: Node3D, fighting: bool) -> void:
	if fighting or man.call(&"is_limp"):
		_gesture = &""
		man.clear_upper(0.15)
		return

	# A gesture first.
	if _gesture != &"":
		var t := _time - _gesture_at

		if t < _gesture_for:
			man.show_upper(_gesture, t, 0.12, 0.9)
			return

		_gesture = &""

	var doing: StringName = guard.activity() if guard.has_method("activity") else &""
	var since := _time - _activity_since(doing)
	var acting: bool = man.is_acting()

	# Talking with his hands (not seated: the seat shows his talk).
	var director := _director()

	if director != null and director.speaking(guard) and not acting and doing != &"sit_talk":
		var weight := clampf(float(traits.get("gesture", GESTURE.get(_tag(), 0.7))), 0.0, 1.0)
		man.show_upper(&"Idle_Talking", fmod(_time, maxf(man.action_length(&"Idle_Talking"), 0.1)), 0.25, weight)
		return

	if UPPER_ACTIVITIES.has(doing) and not acting:
		var spec: Array = UPPER_ACTIVITIES[doing]
		var length := maxf(man.action_length(spec[0]), 0.1)
		# A drink is taken once; the rest go round.
		var t: float = minf(since, length - 0.02) if doing == &"drink" else fmod(since, length)
		man.show_upper(spec[0], t, 0.3, float(spec[1]))
		return

	man.clear_upper(0.3)


## When he began what he is doing now.
func _activity_since(doing: StringName) -> float:
	if doing != _since_doing:
		_since_doing = doing
		_since_at = _time

	return _since_at


# Helpers

func _tag() -> StringName:
	var fighter: RefCounted = guard.get("_fighter")
	return fighter.temper.tag if fighter != null and fighter.temper != null else &"steady"


func _fear() -> float:
	var voice: Variant = guard.get("_voice")
	return clampf(float(voice.call(&"_fear")), 0.0, 1.0) if voice != null else 0.0


func _is_captain() -> bool:
	var sheet: Dictionary = TalkScript.library().get("cast", {})
	var entry: Dictionary = sheet.get(String(guard.get("given_name")), {})
	return (entry.get("traits", []) as Array).has("captain")


func _director() -> RefCounted:
	if _director_script == null:
		_director_script = load(TALK_DIRECTOR)

	return _director_script.of(guard) if guard.is_inside_tree() else null


## On her round, the captain is near him (Gathering.captain_near).
func _captain_near() -> bool:
	if not _gathering_checked:
		_gathering_checked = true

		if ResourceLoader.exists(GATHERING):
			_gathering_script = load(GATHERING)

	if _gathering_script == null or not guard.is_inside_tree():
		return false

	var gatherings: RefCounted = _gathering_script.call(&"of", guard)
	return gatherings != null and gatherings.has_method("captain_near") and gatherings.captain_near(guard)
