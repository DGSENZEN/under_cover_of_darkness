extends Node
## PlayerCombat-compatible threat/defence state for the showcase intruder. IntruderBrain chooses actions.
## Ticks blow phases and mirrors GuardRig fields; landed strikes use guards' real take_hit paths.
## Incoming damage passes through dodge/parry/guard handling, with signals for defence, movement, hits, and kills.

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const CineEvents := preload("res://scripts/Cinema/CineEvents.gd")

## A blow of his turned aside, or taken on his guard: "parry", "block". Squad
## reads it (read "parry").
signal defended(result: StringName)
## He stepped out of the way. Squad reads it (read "dodge").
signal dodged(direction: Vector3)
## One of his blows met someone: take_hit's result ("hit", "killed",
## "blocked", "parried").
signal landed(target: Node3D, result: StringName)
## A man he cut down, and whether it was a riposte (a parry answered).
signal felled(target: Node3D, riposte: bool)

## In PlayerCombat.Phase's order: Squad reads `phase` as that number.
enum Phase { IDLE, WINDUP, CHARGING, STRIKE, RECOVER, DRAWING, KICK, DODGE, STAGGER }

## Each blow: its windup, strike and recovery (s).
const WINDUP := 0.42
const STRIKE := 0.12
const RECOVER := 0.4
## A riposte comes this much quicker (GuardFighter's own riposte windup).
const RIPOSTE_WINDUP := 0.4
## Recovering from a blow caught on a guard; reeling from one parried (s).
const BLOCKED_RECOVER := 0.5
const PARRIED_STAGGER := 0.9
## A guard raised this long before a blow lands turns it aside (s).
const PARRY_WINDOW := 0.25
## After a parry (or a blow answered, GuardFighter._answered), a blow begun
## within this long is a riposte (s).
const RIPOSTE_WINDOW := 0.6
## How far his blade reaches (m), how wide it cuts (degrees), and how far up
## or down a man can be and still be reached (m).
const REACH := 1.9
const THRUST_REACH := 2.2
const ARC := 110.0
const THRUST_ARC := 34.0
const REACH_HEIGHT := 1.2
## What his blows do: a cut, the heavy blow, a riposte's multiplier, the
## knife in the back.
const DAMAGE := 34.0
const HEAVY_DAMAGE := 60.0
const RIPOSTE_DAMAGE := 1.5
const BACKSTAB_DAMAGE := 999.0
## A step out of the way: how long and how fast.
const DODGE_TIME := 0.3
const DODGE_SPEED := 6.5
## Shoved by a boot, a pommel or the great blow: how long, how fast, and how
## long he is off his balance after.
const SHOVE_TIME := 0.3
const SHOVE_SPEED := 5.5
const CRUSH_SPEED := 7.0
const SHOVE_STAGGER := 0.45
const CRUSH_STAGGER := 0.65
## Each blow's weight on a raised guard (GuardFighter.defend), damage and
## reach factors, and strike factor: PlayerCombat's STYLES, in its keys.
const STYLES := {
	&"overhead": {"poise": 1.2, "damage": 1.0, "reach": 1.0, "strike": 1.0},
	&"left": {"poise": 1.0, "damage": 1.0, "reach": 1.0, "strike": 1.0},
	&"right": {"poise": 1.0, "damage": 1.0, "reach": 1.0, "strike": 1.0},
	&"thrust": {"poise": 0.8, "damage": 0.9, "reach": 1.15, "strike": 1.0},
	&"heavy": {"poise": 2.0, "damage": 1.75, "reach": 1.05, "strike": 1.2},
}

var intruder: CharacterBody3D
var phase := Phase.IDLE
var blocking := false
## Read by GuardFighter (a winded man is pressed): he never tires.
var stamina := 100.0

var _serial := 0
var _direction: StringName = &"left"
var _t := 0.0
var _length := 0.0
var _clock := 0.0
var _block_started := -100.0
var _dodged_at := -100.0
var _dodge_velocity := Vector3.ZERO
var _riposte_until := -100.0
var _riposte := false
var _victim: Node3D = null
var _outcome: StringName = &""
## The last man whose blow he turned aside (his riposte's man).
var last_parried: Node3D = null
## The man the blow under way is meant for.
var _meant_for: Node3D = null


func _init(p_intruder: CharacterBody3D = null) -> void:
	intruder = p_intruder
	name = "Combat"


## Every physics frame, before his body moves (Intruder._physics_process):
## the clock of the blow under way.
func tick(delta: float) -> void:
	_clock += delta

	# Cut while winding up (Guard.take_hit cleared his phase): that blow is
	# lost.
	if (phase == Phase.WINDUP or phase == Phase.STRIKE) and intruder._phase == &"":
		_end_blow()

	if phase == Phase.STAGGER and intruder._stagger <= 0.0:
		phase = Phase.IDLE

	if phase == Phase.IDLE or phase == Phase.STAGGER:
		return

	_t += delta

	if _t < _length:
		_mirror()
		return

	match phase:
		Phase.WINDUP:
			_enter(Phase.STRIKE, STRIKE * float(_style()["strike"]))
			_land()
		Phase.STRIKE:
			_enter(Phase.RECOVER, BLOCKED_RECOVER if _outcome == &"blocked" else RECOVER)
		Phase.RECOVER:
			_end_blow()
		Phase.DODGE:
			_dodge_velocity = Vector3.ZERO
			phase = Phase.IDLE


## While a blow or a dodge has him, it moves him (from _puppet_drive): planted
## through a blow, with a step into it as it falls; off to the side in a
## dodge. True if it moved him, so nothing else should.
func move(delta: float) -> bool:
	match phase:
		Phase.DODGE:
			intruder.velocity.x = _dodge_velocity.x
			intruder.velocity.z = _dodge_velocity.z
			return true
		Phase.WINDUP, Phase.STRIKE, Phase.RECOVER:
			intruder._stop(delta)

			if phase == Phase.WINDUP and _t / maxf(_length, 0.01) > 0.78 and _direction in [&"overhead", &"thrust", &"heavy"]:
				var forward: Vector3 = -intruder.global_basis.z
				intruder.velocity.x = forward.x * 1.6
				intruder.velocity.z = forward.z * 1.6

			return true

	return false


## Whether a blow, a dodge or a stagger has him.
func busy() -> bool:
	return phase != Phase.IDLE


# What he does (his brain calls these)

## Starts a blade swing aimed at optional at; returns false outside idle/recover or while staggered/knocked.
## Unknown direction falls back to left.
## Updates mirrored rig/threat state; contact and signals occur later during tick().
func swing(direction: StringName, at: Node3D = null) -> bool:
	if phase != Phase.IDLE and phase != Phase.RECOVER:
		return false

	if intruder._stagger > 0.0 or intruder._knock > 0.0:
		return false

	guard_up(false)
	_direction = direction if STYLES.has(direction) else &"left"
	_riposte = _clock <= _riposte_until
	_riposte_until = -100.0
	_outcome = &""
	_serial += 1
	var windup := WINDUP * (1.5 if _direction == &"heavy" else 1.0) * (RIPOSTE_WINDUP if _riposte else 1.0)
	_meant_for = at
	_enter(Phase.WINDUP, windup)
	return true


## A knife in the back: a blow whose strike kills `victim`, if he is still in
## reach when it falls.
func backstab(victim: Node3D) -> bool:
	if not swing(&"overhead"):
		return false

	_victim = victim
	return true


## His guard up or down. Raised just before a blow lands, it turns the blow
## aside (a parry). Not in the middle of his own blow.
func guard_up(on: bool) -> void:
	if on and (phase == Phase.WINDUP or phase == Phase.STRIKE or phase == Phase.DODGE or phase == Phase.STAGGER):
		return

	if on and not blocking:
		_block_started = _clock

		# Up out of a recovery: that blow is over.
		if phase == Phase.RECOVER:
			_end_blow()

	blocking = on

	if intruder._fighter != null:
		intruder._fighter.guarding = on


## A quick step away from `from` (a point: whoever is coming at him).
func dodge(from: Vector3) -> bool:
	if phase == Phase.WINDUP or phase == Phase.STRIKE or phase == Phase.STAGGER:
		return false

	guard_up(false)
	var away := intruder.global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else intruder.global_basis.z
	_dodge_velocity = away * DODGE_SPEED
	_dodged_at = _clock
	_enter(Phase.DODGE, DODGE_TIME)
	intruder._phase = &""

	if intruder._rig != null:
		intruder._rig.react_dodge(away)

	dodged.emit(away)
	return true


# What a guard reads off him (PlayerCombat's read-outs)

func threat_serial() -> int:
	return _serial


func threat_phase() -> StringName:
	match phase:
		Phase.WINDUP:
			return &"windup"
		Phase.STRIKE:
			return &"strike"

	return &""


func time_to_contact() -> float:
	match phase:
		Phase.WINDUP:
			return maxf(_length - _t, 0.0) + STRIKE * 0.35
		Phase.STRIKE:
			return maxf(STRIKE * 0.35 - _t, 0.0)

	return -1.0


func threat_reach() -> float:
	return THRUST_REACH if _direction == &"thrust" else REACH


## A heavy blow reads as an overhead (the player's four ways).
func threat_direction() -> StringName:
	return &"overhead" if _direction == &"heavy" else _direction


func is_riposte() -> bool:
	return _riposte and phase != Phase.IDLE


func dodged_within(seconds: float) -> bool:
	return _clock - _dodged_at <= seconds


func blow_poise() -> float:
	return float(_style()["poise"])


func _style() -> Dictionary:
	return STYLES.get(_direction, STYLES[&"left"])


## He answered a guard's blow as it asked (GuardFighter._answered): his
## answer comes fast and hard.
func on_answered(_how: StringName, _by: Node) -> void:
	_riposte_until = _clock + RIPOSTE_WINDOW


func is_parrying() -> bool:
	return blocking and _clock - _block_started <= PARRY_WINDOW


# A guard's blow meeting him (Intruder.take_damage)

## How much of an incoming blow gets through: all of a boot or a low cut (and
## the boot shoves him); none of a blow parried; a little of one blocked.
## A blow on his blade, told to the camera (CineEvents "blow").
func _told(outcome: StringName, from: Node, heavy: bool) -> void:
	CineEvents.emit(&"blow", {"attacker": from if is_instance_valid(from) else null, "victim": intruder,
		"weight": &"heavy" if heavy else &"light", "outcome": outcome, "where": intruder.global_position})


## Returns damage remaining after dodge, parry, or guard handling for an incoming attacker.
## May emit defended and update defence/riposte state; the caller applies returned health damage.
func filter_incoming(amount: float, from: Node) -> float:
	var info: Dictionary = from.attack_info() if from != null and from.has_method("attack_info") else {}

	if bool(info.get("hazard", false)):
		return amount

	if bool(info.get("unblockable", false)):
		_shoved(from, bool(info.get("heavy", false)))
		return amount

	if bool(info.get("low", false)) or not blocking or not (from is Node3D):
		return amount

	var to_attacker: Vector3 = info.get("from_direction", (from as Node3D).global_position - intruder.global_position)
	to_attacker.y = 0.0
	var forward: Vector3 = -intruder.global_basis.z

	if to_attacker.length() < 0.01 or forward.dot(to_attacker.normalized()) < 0.35:
		return amount

	var clash: Vector3 = intruder.global_position + Vector3.UP * 1.3 + forward * 0.5
	var toward := to_attacker.normalized()
	SoundBus.emit_sound(clash, 56.0, intruder, &"clang")

	# An arrow on his blade: knocked away.
	if bool(info.get("ranged", false)):
		Fx.sparks(intruder, clash, toward, 0.9)
		Sfx.play(intruder, &"clang", clash, -4.0, 1.35)
		defended.emit(&"block")
		_told(&"blocked", from, false)
		return 0.0

	if _clock - _block_started <= PARRY_WINDOW:
		Fx.sparks(intruder, clash, toward, 1.8)
		Sfx.play(intruder, &"parry", clash)
		Sfx.play(intruder, &"clang", clash, -8.0, 1.1)

		if from.has_method("parried"):
			from.parried(intruder, 1.0)

		last_parried = from as Node3D

		if intruder._rig != null:
			intruder._rig.react_parry_success()

		_riposte_until = _clock + RIPOSTE_WINDOW
		defended.emit(&"parry")
		_told(&"parried", from, bool(info.get("heavy", false)))
		return 0.0

	var thrust: bool = bool(info.get("thrust", false))
	var heavy: bool = bool(info.get("heavy", false))
	Fx.sparks(intruder, clash, toward, 1.5 if heavy else 1.1)
	Sfx.play(intruder, &"clang", clash, 3.0 if heavy else 0.0, 0.82 if heavy else 0.95)

	if from.has_method("blocked_by"):
		from.blocked_by(intruder)

	if intruder._rig != null:
		intruder._rig.react_block(-toward)

	intruder._block_flash = 0.3
	defended.emit(&"block")
	_told(&"blocked", from, heavy)
	return amount * (0.4 if thrust else 0.25)


# Inside a blow

func _enter(new_phase: int, length: float) -> void:
	phase = new_phase as Phase
	_t = 0.0
	_length = maxf(length, 0.01)
	_mirror()


## The blow as his rig shows it: the guard fields it reads.
func _mirror() -> void:
	match phase:
		Phase.WINDUP:
			intruder._attack = _direction
			intruder._phase = &"windup"
		Phase.STRIKE:
			intruder._phase = &"strike"
		Phase.RECOVER:
			intruder._phase = &"recover"
		_:
			return

	intruder._phase_length = _length
	intruder._phase_timer = maxf(_length - _t, 0.0)


func _end_blow() -> void:
	phase = Phase.IDLE
	_victim = null
	_riposte = false

	if intruder._phase in [&"windup", &"strike", &"recover"]:
		intruder._phase = &""


## The blade falls: on whoever is in front of him, in reach, at his level.
func _land() -> void:
	var victim: Node3D = null

	if _victim != null and is_instance_valid(_victim) and _in_reach(_victim):
		victim = _victim
	elif _meant_for != null and is_instance_valid(_meant_for) and not _meant_for._knocked_out and _in_reach(_meant_for) and not _begging(_meant_for):
		victim = _meant_for
	else:
		victim = _nearest_in_reach()

	_meant_for = null

	if victim == null or not victim.has_method("take_hit"):
		_outcome = &"miss"
		return

	var kind: StringName = &"power" if _direction == &"heavy" else &"quick"
	var damage: float = (HEAVY_DAMAGE if _direction == &"heavy" else DAMAGE * float(_style()["damage"]))

	if _riposte:
		damage *= RIPOSTE_DAMAGE

	# The knife in the back: only for a man who does not know he is there,
	# from behind him (as yours: PlayerCombat); else it is a cut like any.
	if victim == _victim and victim.has_method("is_unaware") and victim.is_unaware() and victim.is_behind(intruder):
		kind = &"backstab"
		damage = BACKSTAB_DAMAGE

	var to := victim.global_position - intruder.global_position
	to.y = 0.0
	var direction := to.normalized() if to.length() > 0.01 else -intruder.global_basis.z
	var result: StringName = victim.take_hit(damage, intruder, kind, victim.global_position + Vector3.UP * 1.2, direction)
	_outcome = result

	if result == &"killed":
		felled.emit(victim, _riposte)

	match result:
		&"parried":
			_parried()
		&"blocked":
			if intruder._rig != null:
				intruder._rig.react_blocked()
		&"hit", &"killed":
			if intruder._rig != null and intruder._rig.has_method("bloody"):
				intruder._rig.bloody(0.3)

	landed.emit(victim, result)


## His blow turned aside: he reels, open.
func _parried() -> void:
	phase = Phase.STAGGER
	_victim = null
	_riposte = false
	intruder._phase = &""
	intruder._stagger = maxf(intruder._stagger, PARRIED_STAGGER)

	if intruder._rig != null:
		intruder._rig.react_parried(PARRIED_STAGGER)


## A boot, a pommel, the great blow: shoved back, off his balance.
func _shoved(from: Node, crushing: bool) -> void:
	if not (from is Node3D):
		return

	var push := intruder.global_position - (from as Node3D).global_position
	push.y = 0.0
	push = push.normalized() if push.length() > 0.01 else intruder.global_basis.z
	guard_up(false)
	_end_blow()
	phase = Phase.STAGGER
	intruder._knock = SHOVE_TIME
	intruder._knock_velocity = push * (CRUSH_SPEED if crushing else SHOVE_SPEED)
	intruder._stagger = maxf(intruder._stagger, CRUSH_STAGGER if crushing else SHOVE_STAGGER)

	if intruder._rig != null:
		intruder._rig.react_kick(push, CRUSH_STAGGER if crushing else SHOVE_STAGGER)


## On his knees, or on his feet with a hand out (GuardMercy): not cut.
static func _begging(man: Node3D) -> bool:
	var mercy: Variant = man.get("_mercy")
	return mercy != null and bool((mercy as Object).get("pleading"))


func _in_reach(man: Node3D) -> bool:
	var to := man.global_position - intruder.global_position

	if absf(to.y) > REACH_HEIGHT:
		return false

	to.y = 0.0
	var reach := threat_reach()

	if to.length() > reach:
		return false

	var arc := THRUST_ARC if _direction == &"thrust" else ARC
	var forward: Vector3 = -intruder.global_basis.z
	forward.y = 0.0
	return to.length() < 0.05 or forward.normalized().dot(to.normalized()) >= cos(deg_to_rad(arc * 0.5))


func _nearest_in_reach() -> Node3D:
	var best: Node3D = null
	var best_distance := INF

	for man in intruder.get_tree().get_nodes_in_group(&"guards"):
		if not (man is Node3D) or not _in_reach(man as Node3D) or _begging(man as Node3D):
			continue

		var d := (man as Node3D).global_position.distance_to(intruder.global_position)

		if d < best_distance:
			best_distance = d
			best = man as Node3D

	return best
