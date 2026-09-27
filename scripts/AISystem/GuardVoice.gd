extends RefCounted
## A man's voice and breath.
##   heart     his heart rate, 60 asleep to 170 fighting, running, terrified:
##             it eases toward what his state asks (GOAL), plus running, fear
##             (the garrison's dread weighing on his nerve) and wounds; up
##             fast, down at his own pace. Kept up there, it tires him
##             (exhaustion, three steps, each raising where it settles).
##   breath    how fast he breathes follows his heart; racing, you hear it,
##             each breath out (frightened breathing if he is afraid). A
##             sleeper snores. Expression.gd lifts his chest with it and
##             Atmosphere.gd shows it on the cold air.
##   the ladder  breath < chatter < call-out < pain < death: a louder thing
##             stops a quieter one on the same man, and nothing quieter
##             starts over a louder one until it has passed.
##   murmur    a line of a conversation is heard as a murmur of speech, sized
##             to the line (a stretch of a longer recording, faded in and
##             out), pitched to him, softer whispered, harder shouted, from
##             his head; the subtitle carries the words.
##   emotes    a laugh, a sigh, a cough, a spit, a grunt: their own sounds.
##
## Every sound is a recording (Sfx): with none for a name, it is silent, and
## the rest works the same.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")

## The ladder.
const BREATH := 0
const CHATTER := 1
const CALL := 2
const PAIN := 3
const DEATH := 4
## Beats a minute: asleep, and as fast as it goes.
const HEART_ASLEEP := 60.0
const HEART_MAX := 170.0
## Where it settles for each Guard.Alert (relaxed .. combat).
const GOAL := [72.0, 88.0, 98.0, 108.0, 135.0]
## Added: running (faster than RUN_SPEED), fear (x the dread on his nerve),
## wounds (x how hurt).
const RUN_ADD := 25.0
const RUN_SPEED := 3.0
const FEAR_ADD := 40.0
const WOUND_ADD := 30.0
## How fast it rises (a rate: of the gap, each second).
const RISE := 0.6
## Above this for these many seconds in all, a step more tired; each step
## raises where it settles by this; this long under 100, a step less.
const EXHAUSTED_AT := 150.0
const EXHAUSTION_STEPS := [12.0, 25.0, 45.0]
const EXHAUSTION_FLOOR := 8.0
const RECOVER_STEP := 30.0
## From here up his breathing is heard.
const AUDIBLE_AT := 118.0
## How long a call or a cry holds the ladder (s).
const HOLD := {CALL: 1.2, PAIN: 0.7}
## How loud a line's murmur is, by how it is said, over its level (Sfx.GAIN's
## "murmur" once the recordings are in; MURMUR_DB till then).
const DELIVERY_DB := {&"": 0.0, &"whisper": -10.0, &"murmur": -5.0, &"shout": 7.0}
const MURMUR_DB := -8.0
## A line's murmur fades in and out over these (s).
const FADE_IN := 0.06
const FADE_OUT := 0.15
## From here on, a line comes out shouted if nothing says how.
const SHOUT_AT := 125.0
## A friend's death eases off this much a second (kin's does not).
const GRIEF_FADE := 0.01
## Afraid (the dread on his nerve past this): frightened breathing.
const AFRAID_AT := 0.3
## A conversation's line lasts this long (TalkDirector's measure), for the
## murmur's length.
const LINE_BASE := 0.9
const LINE_PER_CHAR := 0.055
## Emotes and the sounds they make.
const EMOTE_SOUNDS := {"laughs": &"laugh", "sighs": &"sigh", "coughs": &"cough", "spits": &"spit", "kicks": &"grunt_effort", "throws": &"grunt_effort"}
## Emote sounds a woman makes in her own recordings.
const OWN_VOICE := [&"laugh", &"sigh"]

var guard: CharacterBody3D
var heart := 72.0
var exhaustion := 0
## His breathing's own rate against the rest of him (Expression's variation).
var breath_scale := 1.0
## Game seconds since he was made.
var clock := 0.0

var _recovery := 0.06
var _held := -1.0
var _above := 0.0
var _below := 0.0
var _phase := 0.0
var _breaths := 0
var _rung := -1
var _rung_until := -1.0
var _mouth: AudioStreamPlayer3D
var _murmur_start := -1.0
var _murmur_length := 0.0
var _murmur_db := 0.0


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard
	var dice := RandomNumberGenerator.new()
	var seed_of: int = int(guard.get("look_seed")) if int(guard.get("look_seed")) >= 0 else hash(String(guard.name))
	dice.seed = hash(seed_of * 7919 + 13)
	_recovery = dice.randf_range(0.04, 0.08)
	_phase = dice.randf()


## Every physics frame.
func update(delta: float) -> void:
	clock += delta

	# A friend's death weighs on him a while; kin, all night.
	if float(guard.get("grief")) > 0.0 and bool(guard.get("grief_fades")):
		guard.set("grief", maxf(float(guard.get("grief")) - GRIEF_FADE * delta, 0.0))

	_update_heart(delta)
	_update_breath(delta)
	_update_murmur()


## Breaths a second: slow at rest, quick with his heart racing.
func breath_rate() -> float:
	return lerpf(0.22, 0.8, clampf((heart - 60.0) / 110.0, 0.0, 1.0)) * breath_scale


## Where he is in a breath: 0..0.5 in, 0.5..1 out.
func breath_phase() -> float:
	return _phase


func out_breath() -> bool:
	return _phase >= 0.5


## Tests: his heart held at `bpm` (-1 lets it go).
func hold_heart(bpm: float) -> void:
	_held = bpm

	if bpm >= 0.0:
		heart = bpm


## Says something on rung `rung` of the ladder: false (nothing said) if
## something louder is sounding. A line of chatter is murmured; anything
## louder stops a murmur.
func utter(rung: int, text: String, delivery: StringName) -> bool:
	if sounding() > rung:
		return false

	if rung > CHATTER:
		_stop_murmur()

	_rung = rung

	if rung == CHATTER:
		var length := LINE_BASE + LINE_PER_CHAR * text.length()
		_rung_until = clock + length
		_murmur(length, delivery)
	else:
		_rung_until = clock + float(HOLD.get(rung, 1.0))

	return true


## A cry: "pain", "death", "roar", "grunt" (a dying cry always).
func cry(kind: StringName, volume := 0.0) -> void:
	var rung := DEATH if kind == &"death" else PAIN

	if sounding() > rung:
		return

	_stop_murmur()
	_rung = rung
	_rung_until = INF if rung == DEATH else clock + float(HOLD[PAIN])
	var pitch := _pitch()
	# A woman speaks with her own voice ("pain_f"...).
	var spoken := StringName(String(kind) + "_f") if _female() else kind
	Sfx.play(guard, spoken, guard.eye_position(), volume, pitch, 0.03)


## The sound of an emote, if it has one ("laughs", "sighs", ...).
func emote(what: String) -> void:
	var sound: StringName = EMOTE_SOUNDS.get(what, &"")

	if sound == &"" or sounding() > CHATTER:
		return

	if _female() and OWN_VOICE.has(sound):
		sound = StringName(String(sound) + "_f")

	Sfx.play(guard, sound, guard.eye_position(), 0.0, _pitch(), 0.03)


## The rung sounding now; -1 if nothing.
func sounding() -> int:
	return _rung if clock < _rung_until else -1


func murmuring() -> bool:
	return _murmur_start >= 0.0 and clock < _murmur_start + _murmur_length


## How a line comes out when nothing says: shouted with his heart racing,
## whispered when something is wrong, else as he talks.
func delivery_for(marked: StringName, uneasy: bool) -> StringName:
	if marked != &"":
		return marked

	if heart >= SHOUT_AT:
		return &"shout"

	return &"whisper" if uneasy else &""


# ---------------------------------------------------------------------------
# The heart
# ---------------------------------------------------------------------------

func _update_heart(delta: float) -> void:
	if _held >= 0.0:
		heart = _held
		return

	var goal := _goal()
	var rate := RISE if goal > heart else _recovery
	heart = clampf(heart + (goal - heart) * (1.0 - exp(-rate * delta)), HEART_ASLEEP * 0.95, HEART_MAX)

	# Kept racing, he tires; eased a good while, he gets it back.
	if heart > EXHAUSTED_AT:
		_above += delta
		_below = 0.0

		while exhaustion < EXHAUSTION_STEPS.size() and _above >= float(EXHAUSTION_STEPS[exhaustion]):
			exhaustion += 1
	elif heart < 100.0 and exhaustion > 0:
		_below += delta

		if _below >= RECOVER_STEP:
			_below = 0.0
			exhaustion -= 1
			_above = float(EXHAUSTION_STEPS[exhaustion - 1]) if exhaustion > 0 else 0.0


func _goal() -> float:
	var rota: RefCounted = guard.get("_rota")

	if rota != null and rota.asleep():
		return HEART_ASLEEP

	var state := clampi(int(guard.get("state")), 0, GOAL.size() - 1)
	var goal: float = GOAL[state]
	var speed := Vector2(guard.velocity.x, guard.velocity.z).length()

	if speed > RUN_SPEED:
		goal += RUN_ADD

	goal += FEAR_ADD * _fear()
	var most := maxf(float(guard.get("max_health")), 1.0)
	goal += WOUND_ADD * clampf(1.0 - float(guard.get("health")) / most, 0.0, 1.0)

	if state > 0:
		goal += EXHAUSTION_FLOOR * exhaustion

	return minf(goal, HEART_MAX)


## The garrison's dread, as it weighs on his nerve (0..1).
func _fear() -> float:
	var fighter: RefCounted = guard.get("_fighter")
	var target: Node3D = guard.get_tree().get_first_node_in_group(&"player") as Node3D if guard.is_inside_tree() else null

	if fighter == null or fighter.temper == null or target == null:
		return 0.0

	var garrison: RefCounted = GarrisonScript.of(target)
	return float(garrison.fear_of(float(fighter.temper.nerve))) if garrison != null else 0.0


# ---------------------------------------------------------------------------
# Breath
# ---------------------------------------------------------------------------

func _update_breath(delta: float) -> void:
	var was_out := out_breath()
	_phase = fposmod(_phase + breath_rate() * delta, 1.0)

	if out_breath() and not was_out:
		_breathe_out()


## A breath out: heard if his heart races or he is spent; a sleeper snores
## every other one.
func _breathe_out() -> void:
	_breaths += 1

	if sounding() > BREATH or not guard.is_inside_tree():
		return

	var rota: RefCounted = guard.get("_rota")

	if rota != null and rota.asleep():
		if _breaths % 2 == 0:
			Sfx.play(guard, &"snore", guard.eye_position(), -2.0, _pitch(), 0.05)

		return

	if heart < AUDIBLE_AT and exhaustion < 1:
		return

	var afraid := _fear() > AFRAID_AT
	Sfx.play(guard, &"breath_scared" if afraid else &"breath_heavy", guard.eye_position(),
		lerpf(-14.0, -4.0, clampf((heart - AUDIBLE_AT) / (HEART_MAX - AUDIBLE_AT), 0.0, 1.0)), _pitch(), 0.05)


# ---------------------------------------------------------------------------
# The murmur
# ---------------------------------------------------------------------------

func _murmur(length: float, delivery: StringName) -> void:
	_murmur_start = clock
	_murmur_length = length
	_murmur_db = float(Sfx.GAIN.get(&"murmur", MURMUR_DB)) + float(DELIVERY_DB.get(delivery, 0.0))

	if Sfx.recording:
		Sfx.recorded.append([&"murmur", _murmur_db, true])

	var stream := Sfx.stream(&"murmur_f" if _female() else &"murmur")

	if stream == null or not Sfx.enabled or not guard.is_inside_tree():
		return

	if _mouth == null or not is_instance_valid(_mouth):
		_mouth = AudioStreamPlayer3D.new()
		_mouth.name = "Mouth"
		_mouth.bus = Sfx.BUS_WORLD
		_mouth.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		_mouth.attenuation_filter_db = Sfx.AIR_DB
		var head := guard.get_node_or_null("Head")
		(head if head != null else guard).add_child(_mouth)

	_mouth.stream = stream
	_mouth.pitch_scale = _pitch() * randf_range(0.97, 1.03)
	_mouth.volume_db = _murmur_db - 30.0
	var from := randf_range(0.0, maxf(stream.get_length() - length, 0.0))
	_mouth.play(from)


func _update_murmur() -> void:
	if _mouth == null or not is_instance_valid(_mouth) or not _mouth.playing:
		return

	var t := clock - _murmur_start

	if t >= _murmur_length:
		_mouth.stop()
		return

	var gain := clampf(t / FADE_IN, 0.0, 1.0) * clampf((_murmur_length - t) / FADE_OUT, 0.0, 1.0)
	_mouth.volume_db = _murmur_db + linear_to_db(maxf(gain, 0.001))


func _stop_murmur() -> void:
	_murmur_start = -1.0

	if _mouth != null and is_instance_valid(_mouth):
		_mouth.stop()


func _pitch() -> float:
	var rig: Variant = guard.get("_rig")
	return rig.voice_pitch() if rig != null and rig.has_method("voice_pitch") else 1.0


func _female() -> bool:
	var rig: Variant = guard.get("_rig")
	return rig != null and bool(rig.get("female"))
