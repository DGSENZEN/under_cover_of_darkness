extends Node
## Fighting: Dark Messiah's weight, Chivalry's footsies, Dishonored's tricks.
## Lives on the player as "Combat".
##
##   LMB        attack at once; keep holding to charge a power attack.
##              Your movement picks the swing: strafe for a side slash,
##              forward for a thrust, standing still for an overhead chop.
##              Click again while a swing plays and the next one follows as
##              soon as it can: a combo, each wound up quicker than the last.
##   RMB        block (sword). Raise it just before a blow lands: a parry,
##              and the blow you answer with comes fast and hard (a riposte).
##              Pressing it again straight away does not parry again: a
##              parry is a commitment. Pressed during your own windup, the
##              attack is abandoned: a feint, to draw out his parry.
##   Q          dodge: a quick step the way you are moving (back if still).
##   F          kick. Guards stagger back, off ledges and onto spikes, and a
##              raised guard is knocked aside; crates fly; doors burst open.
##   bow        hold LMB to draw, release to loose. Drawing slows you and
##              narrows the view; RMB lets the string down.
##   falling    onto a guard with LMB pressed: a drop attack.
##   stamina    blocking a blow costs it (a brute's costs a lot), and so do
##              dodges, kicks and swings. A blow on a guard with none left
##              breaks through it. It comes back quickly when you stop.
##   adrenaline fills as you fight. Full, your next power attack is a
##              slow-motion finisher.
##
## Weight comes from the moment of contact. A blow that lands freezes the
## world for a few hundredths of a second (hit-stop), the blade drags through
## him, the view jolts against the cut and the swing carries on. A blow that
## is stopped (a wall, his blade) stops dead and bounces back, with sparks.
## The victim's side, blood, wounds and flinching, is the guard's own
## business (Guard.gd, GuardFighter.gd, GuardRig.gd).
##
## Blows and arrows are aimed from the head, not the camera: the camera's
## shake and punch are for show and never move a blow.

const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const ArrowScript := preload("res://scripts/Combat/Arrow.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const CombatView := preload("res://scripts/Visual/AdrenalineView.gd")
const RagdollScript := preload("res://scripts/Visual/Ragdoll.gd")

signal swung(power: bool, direction: StringName)
signal landed(target: Object, result: StringName, damage: float)
signal deflected(point: Vector3)
signal kicked(target: Object)
signal fired(arrow: Node3D)
signal finisher_started
## You met a blow: "parry", "block" or "broken" (no stamina left to hold it).
signal defended(result: StringName)
signal feinted
signal dodged(direction: Vector3)
## A blow thrown straight out of a parry.
signal riposte_started
signal drop_attacked(target: Node3D)
## Knocked off balance: `why` is "broken", "kicked" or "flinch".
signal staggered(why: StringName)
## You answered a blow as it asked (GuardFighter._answered): "dodged" out of
## it at the last moment, "jumped" a sweep.
signal answered(how: StringName)
## A blow landed on a man thrown off his balance (his posture broken).
signal deathblow_landed(target: Node3D)

enum Phase {
	IDLE,
	WINDUP,
	CHARGING,
	STRIKE,
	RECOVER,
	DRAWING,
	KICK,
	DODGE,
	STAGGER,
}

## How the weapon is held and swung in your view: ViewPoses.gd, pose by pose.
const ViewPoses := preload("res://scripts/Combat/ViewPoses.gd")

## Each kind of blow plays its own way (x the weapon's numbers): a thrust is
## quick, long and narrow and stops in the first man it meets; a side cut is
## even and wide and carries on through into the next; an overhead is slow to
## come but hits hardest, and whoever catches it on his guard feels it twice.
const STYLES := {
	&"thrust": {"windup": 0.82, "strike": 0.85, "reach": 1.15, "damage": 0.85, "cost": 0.8, "poise": 1.0, "through": false},
	&"left": {"windup": 1.0, "strike": 1.0, "reach": 1.0, "damage": 1.0, "cost": 1.0, "poise": 1.0, "through": true},
	&"right": {"windup": 1.0, "strike": 1.0, "reach": 1.0, "damage": 1.0, "cost": 1.0, "poise": 1.0, "through": true},
	&"overhead": {"windup": 1.15, "strike": 1.05, "reach": 1.0, "damage": 1.25, "cost": 1.15, "poise": 2.0, "through": false},
}

@export_group("Defence")
@export var parry_window := 0.25
## After a press opens a parry, this long must pass before another press can.
@export var parry_cooldown := 0.35
@export_range(0.0, 1.0, 0.05) var block_damage_scale := 0.2
@export_range(0.1, 1.0, 0.05) var block_speed_scale := 0.55
@export_range(0.1, 1.0, 0.05) var charge_speed_scale := 0.75
@export_range(0.1, 1.0, 0.05) var draw_speed_scale := 0.55
## A blow on a guard with no stamina behind it: this much gets through, and
## you are knocked off balance.
@export_range(0.0, 1.0, 0.05) var guard_break_damage := 0.6
@export var guard_break_stagger := 0.7
## Cut while winding up: the attack is lost and you flinch this long.
@export var flinch_time := 0.28

@export_group("Stamina")
@export var stamina_max := 100.0
@export var stamina_regen := 32.0
## Seconds after spending before it comes back; longer if it ran out.
@export var stamina_delay := 0.7
@export var stamina_empty_delay := 1.2
@export var cost_quick := 5.0
@export var cost_power := 12.0
@export var cost_kick := 12.0
@export var cost_dodge := 20.0
@export var cost_feint := 6.0
## A blow blocked with no number of its own costs this.
@export var cost_block := 16.0
@export var parry_refund := 8.0

@export_group("Flow")
## A click this long before a swing can start still counts.
@export var attack_buffer := 0.32
## Part of the recovery after which a clicked follow-up starts: soon after a
## hit, later after a miss (a blocked one: chain_after_stopped).
@export_range(0.0, 1.0, 0.05) var chain_after_hit := 0.35
@export_range(0.0, 1.0, 0.05) var chain_after_miss := 0.6
@export_range(0.1, 1.0, 0.05) var chained_windup_scale := 0.75
## Part of the recovery after which block can cut it short.
@export_range(0.0, 1.0, 0.05) var block_cancel := 0.3
@export var riposte_window := 0.9
@export_range(0.1, 1.0, 0.05) var riposte_windup_scale := 0.4
@export var riposte_damage := 1.5

@export_group("Dodge")
@export var dodge_speed := 7.5
@export var dodge_time := 0.22
@export var dodge_cooldown := 0.35

@export_group("Kick")
@export var kick_reach := 1.7
## Speed given to a guard, in m/s.
@export var kick_speed := 7.5
## Impulse given to a loose object.
@export var kick_impulse := 45.0
@export var kick_time := 0.42
@export var kick_cooldown := 0.75
@export var kick_db := 48.0
## How long you are held after a blow that did not land, in all, seconds:
## short, so a fight stays a quick back and forth. A wall in the way of a
## swing bounces it back.
@export var deflect_recovery := 0.4
## His blade caught yours.
@export var blocked_recovery := 0.3
## He parried you: your blade is flung aside a little longer (you can raise
## your guard at once, and must: he answers).
@export var parried_recovery := 0.36
## Part of a blocked or parried blow's recovery after which a clicked
## follow-up starts.
@export_range(0.0, 1.0, 0.05) var chain_after_stopped := 0.7
## Half the width of the band a swing cuts.
@export var blade_half_width := 0.22

@export_group("Drop attack")
@export var drop_damage := 260.0
## How far to the side of him you may land and still strike.
@export var drop_reach := 1.5

@export_group("Adrenaline")
## How much turning (radians, recent) picks a swing's direction, and how
## long a turn is remembered.
@export var swing_flick := 0.03
@export var swing_memory := 0.12
@export var adrenaline_max := 100.0
@export var adrenaline_per_damage := 0.45
@export var adrenaline_per_hurt := 0.35
@export var finisher_multiplier := 3.0
@export var finisher_time_scale := 0.3
## Real seconds of slow motion.
@export var finisher_time := 0.45

@export_group("Feel")
## Real seconds the world freezes when a blow lands: quick, heavy, finisher.
@export var hitstop_quick := 0.06
@export var hitstop_heavy := 0.1
@export var hitstop_finisher := 0.13
## The blade drags through a body: the swing runs at this speed just after a
## hit, back to full over `cleave_time`.
@export_range(0.05, 1.0, 0.05) var cleave_slow := 0.35
@export var cleave_time := 0.1

var player: CharacterBody3D
var weapon: Resource = null
var phase := Phase.IDLE
var blocking := false
var draw := 0.0
var adrenaline := 0.0
var stamina := 100.0
## Blows landed in a row, each following the last.
var combo := 0
## When you last dodged: a dodge just before his blow lands leaves him
## overreaching (GuardFighter).
var _dodged_at := -100.0

var _t := 0.0
var _charge := 0.0
var _charge_ready := false
var _power := false
var _finisher := false
var _riposte := false
var _direction: StringName = &"overhead"
## This blow's strike time (the weapon's, as its style has it).
var _strike_time := 0.2
## How the view has been turning just now (radians, decaying): x is yaw,
## positive turning left; y is pitch, positive looking up. The way you move
## your mouse (or stick) as you swing is the way the blade goes.
var _look_motion := Vector2.ZERO
var _last_look := Vector2.ZERO
var _look_known := false
var _hit_this_swing := {}
var _last_sweep := 0.0
var _block_started := -100.0
var _guard_sound_at := -100.0
var _kick_cooldown := 0.0
## Running (or in the air) as the kick began: a flying kick.
var _kick_momentum := false
var _kick_landed := false
var _game_time := 0.0
var _recovery := 0.0
var _windup := 0.1
## How the last swing ended: "hit", "miss", "blocked", "parried", "deflect".
var _outcome: StringName = &"miss"
var _cleave := 1.0
var _stagger_time := 0.0
var _dodge_cooldown := 0.0
var _stamina_rest := 0.0
var _riposte_until := -100.0
## Each windup a new number: guards watch it to know a new blow is coming.
var _serial := 0
## When attack was last clicked and not yet used.
var _attack_pressed_at := -100.0
var _drop_target: Node3D = null
var _drop_armed := false
## A click during a blow in progress: the next blow, whenever it can start.
var _queued := false
## The button has been held without a break since this blow began: only then
## is holding it a charge (not a second click held down).
var _held_through := false
var _combo_timer := 0.0

# The weapon hand's pose: what was last shown, and where a recovery starts.
## The weapon's frame as last shown (ViewPoses.gd), and where a windup and a
## recovery each set out from.
var _shown := Transform3D.IDENTITY
var _windup_from := Transform3D.IDENTITY
## How far into a sprint's carry the weapon is.
var _sprint := 0.0
## What was in hand last tick: a different weapon cancels what the old one
## was doing.
var _weapon_id: StringName = &""
## When block was last pressed with a parry in it: a parry counts from the
## press, so a guard held up through a kick does not come back as a fresh
## parry, and tapping it again at once opens nothing.
var _block_pressed_at := -100.0
var _parry_ready_at := 0.0
var _block_held := false
var _recover_from := Transform3D.IDENTITY


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	_ensure_action(&"block", KEY_NONE, MOUSE_BUTTON_RIGHT)
	_ensure_action(&"kick", KEY_F)
	_ensure_action(&"dodge", KEY_Q)
	stamina = stamina_max


func current_weapon() -> Resource:
	if player.inventory == null:
		return null

	var item: Dictionary = player.inventory.selected_item()

	if item.is_empty():
		return null

	return WeaponScript.find(item["id"])


# ---------------------------------------------------------------------------
# Every frame
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_game_time += delta
	_track_look(delta)
	_kick_cooldown = maxf(_kick_cooldown - delta, 0.0)
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	weapon = current_weapon()
	_regain_stamina(delta)

	# A string of blows is broken by a pause.
	if phase == Phase.IDLE:
		_combo_timer += delta

		if _combo_timer > 1.0:
			combo = 0
	else:
		_combo_timer = 0.0

	# Changed weapon (or put it away) mid-attack: that attack is over. A
	# charge does not carry into a bow, nor a drawn arrow into a dagger.
	var weapon_id: StringName = weapon.id if weapon != null else &""

	if weapon_id != _weapon_id:
		_weapon_id = weapon_id

		if phase != Phase.IDLE and phase != Phase.KICK and phase != Phase.DODGE and phase != Phase.STAGGER and phase != Phase.RECOVER:
			_reset()

	# The press itself, whatever combat is busy with: a fresh press is held
	# now and was not last tick. It opens a parry only if the last one has
	# had time to pass.
	var block_held := Input.is_action_pressed("block")
	var block_pressed := block_held and not _block_held

	if block_pressed and _game_time >= _parry_ready_at:
		_block_pressed_at = _game_time
		_parry_ready_at = _game_time + parry_window + parry_cooldown

	_block_held = block_held

	var able: bool = (
		not player.is_dead
		and player.movement_state == player.MoveState.LOCOMOTION
		and not player._is_carrying()
		and not get_tree().paused
	)

	if not able:
		_reset()
		_drop_armed = false
		_drop_target = null
		_send_pose(delta)
		return

	# A click that already threw what you held, or recaptured the mouse, is
	# not a blow.
	var spent: bool = player.is_mouse_input_swallowed() or player.is_attack_press_spent()
	var attack_pressed := Input.is_action_just_pressed("throw") and not spent
	var attack_held := Input.is_action_pressed("throw") and not spent

	# Falling onto someone: the click is a drop attack, not a swing.
	if _update_drop(attack_pressed):
		attack_pressed = false

	if attack_pressed:
		_attack_pressed_at = _game_time

		# Clicked while a blow is under way: the next one is owed, however
		# early the click came.
		if phase == Phase.WINDUP or phase == Phase.STRIKE:
			_queued = true

	var buffered := _game_time - _attack_pressed_at <= attack_buffer or _queued

	# The kick is no escape from a recovery: not before a blow could have
	# followed, and not at all out of one that was blocked or parried.
	var kick_ok := _kick_cooldown <= 0.0 and phase != Phase.STRIKE and phase != Phase.STAGGER and phase != Phase.DODGE

	if phase == Phase.RECOVER:
		kick_ok = kick_ok and (_outcome == &"hit" or _outcome == &"miss") and _t >= _recovery * 0.5

	if Input.is_action_just_pressed("kick") and kick_ok:
		_start_kick()

	if Input.is_action_just_pressed("dodge"):
		_try_dodge()

	match phase:
		Phase.KICK:
			_update_kick(delta)
		Phase.IDLE:
			_update_idle(buffered, attack_held)
		Phase.WINDUP:
			_t += delta
			_direction = _swing_direction()

			if not attack_held:
				_held_through = false

			if block_pressed:
				_feint()
			elif _t >= _windup:
				if attack_held and _held_through and not _riposte:
					_enter(Phase.CHARGING)
				else:
					_start_strike(false)
		Phase.CHARGING:
			_t += delta
			_direction = _swing_direction()
			_charge = clampf(_t / maxf(weapon.charge_time, 0.01), 0.0, 1.0)
			# The view narrows as the blow gathers.
			player.juice.set_zoom(3.0 * _charge * _charge)

			if _charge >= 1.0 and not _charge_ready:
				# Ready: a glint runs up the blade.
				_charge_ready = true
				_hand(&"show_glint")
				Sfx.play_flat(player, &"ting", -3.0)

			if block_pressed:
				_feint()
			elif not attack_held:
				_start_strike(_charge >= 1.0)
		Phase.STRIKE:
			_update_strike(delta)
		Phase.RECOVER:
			_update_recover(delta, buffered, block_held)
		Phase.DRAWING:
			_update_draw(delta, attack_held)
		Phase.DODGE:
			_t += delta

			if _t >= dodge_time:
				_enter(Phase.IDLE)
		Phase.STAGGER:
			_t += delta
			blocking = false

			if _t >= _stagger_time:
				_enter(Phase.IDLE)

	_send_pose(delta)


func _update_idle(buffered: bool, attack_held: bool) -> void:
	var was_blocking := blocking
	blocking = weapon != null and weapon.can_block and Input.is_action_pressed("block")

	if blocking and not was_blocking:
		_block_started = _block_pressed_at
		_guard_sound()

	if weapon == null or not buffered or blocking:
		return

	if weapon.kind == WeaponScript.Kind.BOW:
		# A bow is drawn by holding: a click let go long ago draws nothing.
		if arrow_count() > 0 and attack_held:
			_attack_pressed_at = -100.0
			draw = 0.0
			_enter(Phase.DRAWING)
			Sfx.play_flat(player, &"bow_draw")

		return

	_begin_attack(false)


## A new blow: wound up, and quicker if it follows another, quicker still
## straight out of a parry.
func _begin_attack(chained: bool) -> void:
	_attack_pressed_at = -100.0
	_queued = false
	_held_through = Input.is_action_pressed("throw")
	_charge = 0.0
	_charge_ready = false
	_riposte = _game_time <= _riposte_until
	_riposte_until = -100.0
	_direction = _swing_direction(true, chained)
	_windup = weapon.windup * float(_style()["windup"])

	if _riposte:
		_windup *= riposte_windup_scale
		riposte_started.emit()
		_hand(&"show_glint")
	elif chained:
		_windup *= chained_windup_scale

	_serial += 1
	_enter(Phase.WINDUP)
	# The head goes the other way first, then leads into the cut (on_swing).
	player.juice.on_windup(_side_of(_direction), _direction, _riposte)


func _update_recover(delta: float, buffered: bool, block_held: bool) -> void:
	_t += delta

	# Raising your guard cuts a recovery short; a parried blow can be
	# covered at once.
	var guard_now: bool = weapon != null and weapon.can_block and block_held
	var can_guard: bool = _t >= _recovery * block_cancel or _outcome == &"parried"

	if guard_now and can_guard:
		_enter(Phase.IDLE)
		blocking = true
		_block_started = _block_pressed_at
		_guard_sound()
		return

	# A click during the swing: the next one, as soon as this one allows.
	if buffered and weapon != null and weapon.kind == WeaponScript.Kind.MELEE:
		var chain_at := -1.0

		match _outcome:
			&"hit":
				chain_at = _recovery * chain_after_hit
			&"miss":
				chain_at = _recovery * chain_after_miss
			&"blocked", &"parried":
				chain_at = _recovery * chain_after_stopped

		if chain_at >= 0.0 and _t >= chain_at:
			_begin_attack(true)
			return

	if _t >= _recovery:
		_enter(Phase.IDLE)


func _enter(new_phase: int) -> void:
	if new_phase == Phase.RECOVER:
		# Recover from wherever the blade stopped: the end of its arc, or the
		# wall it hit.
		_recover_from = _shown
		_hand(&"set_trail", [false])

	if new_phase == Phase.WINDUP:
		# Wound up from wherever it is: rest, or the end of the last blow.
		_windup_from = _shown

	phase = new_phase
	_t = 0.0

	if new_phase != Phase.IDLE:
		blocking = false


func _reset() -> void:
	# A fresh start: no turn of the view carried into the next blow.
	_look_motion = Vector2.ZERO
	_look_known = false

	if phase == Phase.DRAWING:
		draw = 0.0

	if phase == Phase.DRAWING or phase == Phase.CHARGING:
		player.juice.set_zoom(0.0)

	if phase == Phase.STRIKE:
		_hand(&"set_trail", [false])

	phase = Phase.IDLE
	blocking = false
	_riposte = false
	_queued = false
	_t = 0.0


## Movement is slower with a raised guard, a charged blow, a drawn bow, or
## while knocked off balance.
func speed_scale() -> float:
	if blocking:
		return block_speed_scale

	match phase:
		Phase.CHARGING:
			return charge_speed_scale
		Phase.DRAWING:
			return draw_speed_scale
		Phase.STAGGER:
			return 0.6

	return 1.0


## Where blows and arrows come from and go: the head, without the camera's
## bob, shake and punch, which are only for show. Leaning counts: it is
## where your head really is.
func aim() -> Transform3D:
	return player.aim_transform()


# ---------------------------------------------------------------------------
# Stamina
# ---------------------------------------------------------------------------

func _spend(amount: float) -> void:
	if amount <= 0.0:
		return

	stamina = maxf(stamina - amount, 0.0)
	_stamina_rest = _game_time + (stamina_empty_delay if stamina <= 0.0 else stamina_delay)


func _regain_stamina(delta: float) -> void:
	if _game_time < _stamina_rest:
		return

	# Slower behind a raised guard.
	stamina = minf(stamina + stamina_regen * delta * (0.5 if blocking else 1.0), stamina_max)


# ---------------------------------------------------------------------------
# What a guard can read off you
# ---------------------------------------------------------------------------

## Changes with every blow you start.
func threat_serial() -> int:
	return _serial


## "windup", "charging", "strike" or "" for a blow coming his way.
func threat_phase() -> StringName:
	if weapon == null or weapon.kind != WeaponScript.Kind.MELEE:
		return &""

	match phase:
		Phase.WINDUP:
			return &"windup"
		Phase.CHARGING:
			return &"charging"
		Phase.STRIKE:
			return &"strike"

	return &""


## Seconds until the blade reaches the middle of its cut; -1 if nobody can
## tell (a charge is loosed when you let go).
func time_to_contact() -> float:
	if weapon == null:
		return -1.0

	match phase:
		Phase.WINDUP:
			return maxf(_windup - _t, 0.0) + weapon.strike_time * float(_style()["strike"]) * 0.35
		Phase.STRIKE:
			return maxf(_strike_time * 0.35 - _t, 0.0)

	return -1.0


func threat_reach() -> float:
	return weapon.reach * float(_style()["reach"]) if weapon != null else 0.0


## Which way the blow coming at him goes ("overhead", "left", "right",
## "thrust"): a guard who watches you learns your habits.
func threat_direction() -> StringName:
	return _direction


## Your blow just met nothing, and you are still recovering from it: the
## moment to punish.
func whiffed() -> bool:
	return phase == Phase.RECOVER and _outcome == &"miss"


## The style of the blow under way (STYLES).
func _style() -> Dictionary:
	return STYLES.get(_direction, STYLES[&"left"])


func is_riposte() -> bool:
	return _riposte


## The guard you would land on, if you are falling toward one with
## something to drop on him with.
func drop_target() -> Node3D:
	if _drop_target == null or not is_instance_valid(_drop_target) or not _can_drop_attack():
		return null

	return _drop_target


## What a block costs against the men around you right now: the dearest of
## their blows (a brute's is dear).
func block_cost_near() -> float:
	var cost := cost_block

	for node in get_tree().get_nodes_in_group(&"guards"):
		var guard := node as Node3D

		if guard == null or guard.get("state") != 4 or not guard.has_method("attack_info"):
			continue

		if guard.global_position.distance_to(player.global_position) < 5.0:
			cost = maxf(cost, float(guard.attack_info().get("guard_damage", cost_block)))

	return cost


# ---------------------------------------------------------------------------
# Melee
# ---------------------------------------------------------------------------

func _start_strike(power: bool) -> void:
	_power = power
	_finisher = power and adrenaline >= adrenaline_max
	_direction = _swing_direction()
	_hit_this_swing.clear()
	_last_sweep = 0.0
	_charge_ready = false
	_cleave = 1.0
	_outcome = &"miss"
	player.juice.set_zoom(0.0)
	_enter(Phase.STRIKE)
	_strike_time = weapon.strike_time * float(_style()["strike"])
	_spend((cost_power if power else cost_quick) * float(_style()["cost"]))

	player.juice.on_swing(_side_of(_direction), power, _direction)

	# A power blow is put into with the whole body, and heard.
	if power and randf() < 0.45:
		Sfx.play_flat(player, &"effort", -3.0 if _finisher else -6.0)
	_hand(&"set_trail", [true, power or _riposte, _finisher])

	var at := aim()
	var from := at.origin + at.basis * Vector3(0.2, -0.1, -0.6)
	_swing_sound(from)
	SoundBus.emit_sound(player.global_position, weapon.swing_db + (4.0 if power else 0.0), player, &"swing")
	swung.emit(power, _direction)

	# A heavy blow carries you into it: a step forward.
	if power and player.is_on_floor():
		var forward := -player.global_basis.z
		forward.y = 0.0
		player.shove(forward.normalized() * (3.2 if _direction == &"thrust" else 2.4), 0.16)

	if _finisher:
		adrenaline = 0.0
		TimeFx.request(get_tree(), &"finisher", finisher_time_scale, finisher_time)
		finisher_started.emit()


## +1 for a cut going to your left, -1 to your right, 0 for the others.
static func _side_of(direction: StringName) -> float:
	match direction:
		&"left":
			return 1.0
		&"right":
			return -1.0

	return 0.0


## The rush of the blade: a sword's recording, higher and lighter for a
## dagger, lower with a heavy rush under it for a power blow.
func _swing_sound(at: Vector3) -> void:
	var dagger: bool = weapon.id == &"dagger"
	var pitch := 1.3 if dagger else 1.0
	var volume := -3.0 if dagger else 0.0

	if _riposte:
		pitch *= 1.08
		volume += 1.0

	if _power:
		pitch *= 0.86 if dagger else 0.84
		volume += 3.0

	if _finisher:
		pitch *= 0.9
		volume += 1.0

	Sfx.play(player, &"whoosh", at, volume, pitch)

	if _power:
		Sfx.play(player, &"whoosh_heavy", at, -6.0 if dagger else 0.0, pitch)


## The swing your hand is making: the way the view is being turned. Across
## to the left or the right cuts that way, down brings it over from above, up
## drives the point in. Still, a fresh blow is a forehand and a chained one
## comes back from the other side; during a windup it keeps what it was.
func _swing_direction(fresh := false, chained := false) -> StringName:
	var motion := _look_motion

	if motion.length() < swing_flick:
		if not fresh:
			return _direction

		if chained and _direction == &"left":
			return &"right"

		return &"left"

	if absf(motion.x) >= absf(motion.y) * 0.8:
		return &"left" if motion.x > 0.0 else &"right"

	return &"overhead" if motion.y < 0.0 else &"thrust"


## Adds look motion as if the view had turned (radians: yaw left +, pitch up
## +). Your own turning is tracked on its own; tests and pads can push it.
func add_look_motion(motion: Vector2) -> void:
	_look_motion += motion


func _track_look(delta: float) -> void:
	var neck: Node3D = player.get("neck")

	if neck == null:
		return

	var look := Vector2(player.rotation.y, neck.rotation.x)

	if _look_known:
		var turned := Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y)

		# More than any hand turns in a frame: the view was set, not swung.
		if turned.length() < 1.2:
			_look_motion += turned

	_last_look = look
	_look_known = true
	_look_motion *= exp(-delta / maxf(swing_memory, 0.01))


func _update_strike(delta: float) -> void:
	# Through a body the blade drags, then runs free again.
	_t += delta * _cleave
	_cleave = move_toward(_cleave, 1.0, delta / maxf(cleave_time, 0.01) * (1.0 - cleave_slow))
	var p := clampf(_t / maxf(_strike_time, 0.01), 0.0, 1.0)

	# Two rays per frame, at this frame's blade position and halfway back to
	# the last one, so a fast cut leaves no gaps.
	for sample in [(_last_sweep + p) * 0.5, p]:
		if phase != Phase.STRIKE:
			return

		_sweep(sample)

	_last_sweep = p

	if phase == Phase.STRIKE and p >= 1.0:
		_recovery = weapon.recovery
		_enter(Phase.RECOVER)


## The blade at progress p: three rays across its width, so a blow cuts a
## band as wide as a sword and not a line. A single ray passes anyone who is
## not dead centre.
func _sweep(p: float) -> void:
	var at := aim()
	var basis := at.basis
	var forward := -basis.z
	var reach: float = weapon.reach * float(_style()["reach"])
	var direction := forward
	var half := deg_to_rad(weapon.arc_degrees * 0.5)

	match _direction:
		&"left":
			direction = forward.rotated(basis.y, lerpf(-half, half, p))
		&"right":
			direction = forward.rotated(basis.y, lerpf(half, -half, p))
		&"overhead":
			direction = forward.rotated(basis.x, lerpf(deg_to_rad(35.0), deg_to_rad(-30.0), p))
		&"thrust":
			reach *= lerpf(0.5, 1.15, p)

	var from := at.origin

	# The width runs across the swing: sideways for a chop, up and down for a
	# side slash; a point goes in wherever it meets, so a thrust looks both ways.
	var across := basis.x if _direction == &"overhead" or _direction == &"thrust" else basis.y
	var hit := {}
	var offsets: Array = [Vector3.ZERO, across * blade_half_width, -across * blade_half_width]

	if _direction == &"thrust":
		offsets.append(basis.y * -blade_half_width * 1.6)
		offsets.append(basis.y * blade_half_width)

	for offset in offsets:
		var start: Vector3 = from + offset
		var exclude: Array[RID] = [player.get_rid()]
		# Bodies too (layer 3): a man on the floor, whether he is getting up
		# or never will.
		var query := PhysicsRayQueryParameters3D.create(start, start + direction * reach, 1 | 2 | 4, exclude)
		query.collide_with_areas = false
		# Point-blank: a swing that starts inside him still connects.
		query.hit_from_inside = true
		var found := player.get_world_3d().direct_space_state.intersect_ray(query)

		if found.is_empty():
			continue

		# A limb is its man's: him, if he is down but alive; his body if not.
		var limb_of := RagdollScript.owner_of(found.get("collider"))

		if limb_of != null:
			found["collider"] = limb_of

		# Someone in the band beats a wall beside them.
		if hit.is_empty() or (found.get("collider") as Object).has_method("take_hit"):
			hit = found

			if (found.get("collider") as Object).has_method("take_hit"):
				break

	if hit.is_empty():
		return

	var collider: Object = hit.get("collider")
	var point: Vector3 = hit["position"]

	if collider != null and collider.has_method("take_hit"):
		if _hit_this_swing.has(collider):
			return

		# A thrust goes into one man; a cut may carry on into the next.
		if not bool(_style()["through"]) and not _hit_this_swing.is_empty():
			return

		_hit_this_swing[collider] = true
		_strike_target(collider as Node3D, point, _blow_direction(direction, basis))
		return

	# A dead man: the blade goes through him.
	if collider != null and collider.has_method("struck"):
		if not _hit_this_swing.has(collider):
			_hit_this_swing[collider] = true
			collider.struck(point, direction, _power, weapon.id == &"sword" and _direction != &"thrust")
			Sfx.play(player, &"flesh", point, -4.0, 0.9)

		return

	var blow_kind: StringName = &"power" if _power else &"quick"

	if collider is RigidBody3D:
		# Props are knocked about by a swing, and do not stop it. Some care
		# (a powder barrel).
		if not _hit_this_swing.has(collider):
			_hit_this_swing[collider] = true

			if collider.has_method("strike"):
				collider.strike(blow_kind, point, direction)

			(collider as RigidBody3D).apply_impulse(direction * 6.0, point - (collider as RigidBody3D).global_position)
			Fx.dust(player, point, -direction, 0.5, "wood")
			Sfx.play(player, &"thud_wood", point, -5.0)
			player.juice.add_trauma(0.12)

		return

	# Something fixed that gives to a blade: a rope. The blade goes through.
	if collider != null and collider.has_method("strike"):
		if not _hit_this_swing.has(collider):
			_hit_this_swing[collider] = true
			collider.strike(blow_kind, point, direction)
			Fx.dust(player, point, -direction, 0.4, "carpet")

		return

	# A wall, a floor, a door: the blade bounces off.
	var normal: Vector3 = hit.get("normal", -direction)
	_strike_surface(collider, point, normal)
	SoundBus.emit_sound(point, 50.0, player, &"clang")
	deflected.emit(point)
	TimeFx.hitstop(get_tree(), 0.045, 0.06)
	player.juice.add_trauma(0.32)
	player.juice.punch(0.4, 0.0)
	player.juice.on_impact(0.6)
	_hand(&"impact", [&"deflect"])
	_outcome = &"deflect"
	_recovery = deflect_recovery
	_enter(Phase.RECOVER)


## What a killing cut takes off him (Humanoid.sever), by where it met him: a
## cut high through the neck takes the head, low the legs (a sweep both), and
## between them the arm nearest it (at the elbow if the forearm was nearer).
## Only a clean cut: a heavy one (power, riposte, finisher, from above), or
## any once he is weak enough. A point goes in and cuts nothing off; a
## dagger is too short to take a limb.
func _sever_parts(target: Node3D, point: Vector3, dealt: float, health_before: float, kind: StringName, open := false) -> Array[StringName]:
	var none: Array[StringName] = []

	if weapon == null or weapon.id != &"sword" or _direction == &"thrust" or dealt < health_before:
		return none

	var most: float = float(target.get("max_health")) if target.get("max_health") != null else 100.0
	var clean := _power or _riposte or _finisher or open or kind == &"drop" or health_before <= most * 0.4

	if not clean:
		return none

	var rig := target.get_node_or_null("Rig")
	var man: Node3D = rig.get("man") as Node3D if rig != null else null

	if man == null or man.get("ragdoll") == null:
		return none

	var neck: Vector3 = man.bone_global(&"neck_01").origin

	if point.y >= neck.y - 0.08:
		return [&"neck_01"] as Array[StringName]

	var hips: Vector3 = man.bone_global(&"pelvis").origin

	if point.y < hips.y - 0.05:
		var knee_l: Vector3 = man.bone_global(&"calf_l").origin
		var knee_r: Vector3 = man.bone_global(&"calf_r").origin
		var knees := (knee_l.y + knee_r.y) * 0.5
		var segment := "calf" if point.y < knees + 0.03 else "thigh"

		if _direction == &"overhead":
			var left: Vector3 = man.bone_global(StringName(segment + "_l")).origin
			var right: Vector3 = man.bone_global(StringName(segment + "_r")).origin
			return [StringName(segment + ("_l" if point.distance_to(left) < point.distance_to(right) else "_r"))] as Array[StringName]

		return [StringName(segment + "_l"), StringName(segment + "_r")] as Array[StringName]

	var best: StringName = &""
	var nearest := INF

	for side in ["_l", "_r"]:
		var shoulder: Vector3 = man.bone_global(StringName("upperarm" + side)).origin
		var elbow: Vector3 = man.bone_global(StringName("lowerarm" + side)).origin
		var wrist: Vector3 = man.bone_global(StringName("hand" + side)).origin
		var upper := point.distance_to(Geometry3D.get_closest_point_to_segment(point, shoulder, elbow))
		var fore := point.distance_to(Geometry3D.get_closest_point_to_segment(point, elbow, wrist))

		if upper < nearest:
			nearest = upper
			best = StringName("upperarm" + side)

		if fore < nearest:
			nearest = fore
			best = StringName("lowerarm" + side)

	return [best] as Array[StringName] if best != &"" else none


## The way the edge was travelling when it struck: along the cut, and on
## into him. Blood flies this way, and he reels this way.
func _blow_direction(ray: Vector3, basis: Basis) -> Vector3:
	var along := Vector3.ZERO

	match _direction:
		&"left":
			along = -basis.x
		&"right":
			along = basis.x
		&"overhead":
			along = -basis.y
		&"thrust":
			along = -basis.z

	return (along + ray * 0.6).normalized()


## Steel on whatever a level is made of: sparks and a scratch on stone,
## splinters on wood, a ring on metal, a dull thump on soft things.
func _strike_surface(collider: Object, point: Vector3, normal: Vector3) -> void:
	var surface := _surface_of(collider)

	match surface:
		"wood":
			Fx.dust(player, point, normal, 1.0, "wood")
			Sfx.play(player, &"thud_wood", point)
		"metal":
			Fx.sparks(player, point, normal, 1.4)
			Sfx.play(player, &"clang", point)
		"grass", "carpet", "dirt":
			Fx.dust(player, point, normal, 0.8, surface)
			Sfx.play(player, &"thud", point, -4.0)
		_:
			Fx.sparks(player, point, normal, 0.8)
			Fx.dust(player, point, normal, 0.6, "stone")
			Fx.stain(player, point, normal, 0.26, "scratch")
			Sfx.play(player, &"clank", point)
			Sfx.play(player, &"clang", point, -9.0, 0.8)


static func _surface_of(collider: Object) -> String:
	if collider is Node and (collider as Node).has_meta(&"surface"):
		return String((collider as Node).get_meta(&"surface"))

	# Doors and chests are wood.
	if collider != null and collider.has_method("frob"):
		return "wood"

	return "stone"


func _strike_target(target: Node3D, point: Vector3, direction: Vector3) -> void:
	var kind: StringName = &"power" if _power else &"quick"
	var dealt: float = weapon.power_damage if _power else weapon.damage
	var unaware: bool = target.has_method("is_unaware") and target.is_unaware()
	var behind: bool = target.has_method("is_behind") and target.is_behind(player)

	if unaware and behind:
		if weapon.backstab_kills:
			kind = &"backstab"

		dealt *= weapon.sneak_multiplier

	if _finisher:
		dealt *= finisher_multiplier

	if _riposte:
		dealt *= riposte_damage

	dealt *= float(_style()["damage"])

	# Only the damage that actually lands counts toward adrenaline: overkill
	# does not, and a finisher spends adrenaline rather than refilling it.
	var health_before: float = float(target.get("health")) if target.get("health") != null else dealt
	# Off his balance: this is the deathblow.
	var open: bool = target.has_method("is_open") and target.is_open() and kind != &"backstab"
	# Should this kill him, what it cuts off him.
	var cut_off := _sever_parts(target, point, target.deathblow_damage(dealt) if open else dealt, health_before, kind, open)

	if target.get("sever_hint") != null:
		target.set("sever_hint", cut_off)

	var result: StringName = target.take_hit(dealt, player, kind, point, direction)
	var dagger: bool = weapon.id == &"dagger"

	if is_instance_valid(target) and target.get("sever_hint") != null:
		target.set("sever_hint", [] as Array[StringName])

	# Something came off him: the moment hangs.
	if result == &"killed" and not cut_off.is_empty():
		TimeFx.request(get_tree(), &"sever", 0.4, 0.25)
		CombatView.jolt(get_tree(), 1.2)

	# A kill up close (or a deathblow) that cuts him apart throws his blood
	# across your eyes.
	var gory: bool = not cut_off.is_empty() or open
	var close: bool = aim().origin.distance_to(point) < 2.2

	if close and (result == &"killed" or open) and (gory or _power or _finisher) and player.hud != null and player.hud.has_method("splatter"):
		player.hud.splatter(1.0 if gory else 0.45)

	# The deathblow: it lands like a finisher.
	if open and (result == &"hit" or result == &"killed"):
		TimeFx.request(get_tree(), &"deathblow", 0.3, 0.35)
		CombatView.jolt(get_tree(), 1.3)
		Sfx.play(player, &"flesh_heavy", point, 2.0, 0.8)
		adrenaline = minf(adrenaline + 15.0, adrenaline_max)
		deathblow_landed.emit(target)

	match result:
		&"blocked":
			SoundBus.emit_sound(point, 56.0, player, &"clang")
			Sfx.play(player, &"clang", point, 0.0, 1.2 if dagger else 1.0)
			# He caught it on his blade: yours stops dead and is thrown back.
			TimeFx.hitstop(get_tree(), 0.07, 0.05)
			player.juice.add_trauma(0.35)
			player.juice.punch(0.3, 0.0)
			player.juice.on_impact(0.5)
			_hand(&"impact", [&"blocked"])
			_outcome = &"blocked"
			combo = 0
			_recovery = blocked_recovery
			_enter(Phase.RECOVER)
		&"parried":
			# Turned aside at the last instant: flung wide, and he answers.
			TimeFx.hitstop(get_tree(), 0.09, 0.04)
			player.juice.add_trauma(0.45)
			player.juice.punch(0.45, 0.3 if _direction == &"right" else -0.3)
			player.juice.on_impact(0.7)
			_hand(&"impact", [&"blocked"])
			_outcome = &"parried"
			combo = 0
			_recovery = parried_recovery
			_enter(Phase.RECOVER)
		&"none":
			pass
		_:
			SoundBus.emit_sound(point, weapon.hit_db, player, &"hit")
			var heavy := _power or _finisher or _riposte or open or result == &"killed" or kind == &"backstab"
			var freeze := hitstop_finisher if _finisher else (hitstop_heavy if heavy else hitstop_quick)
			TimeFx.hitstop(get_tree(), freeze, 0.04)
			player.juice.add_trauma(0.5 if heavy else 0.28)
			player.juice.on_impact(1.0 if heavy else 0.5)
			CombatView.jolt(get_tree(), 1.3 if _finisher else (0.9 if heavy else 0.4))
			_recoil_view(1.0 if heavy else 0.6)
			_hand(&"impact", [&"heavy" if heavy else &"flesh"])

			if not target.has_meta(&"bloodless"):
				_hand(&"bloody", [0.4 if heavy else 0.22])

			_cut_sound(target, point, heavy, dagger)
			_cleave = cleave_slow
			_outcome = &"hit"
			combo += 1

			if not _finisher:
				var landed_damage := minf(dealt, maxf(health_before, 0.0))
				adrenaline = minf(adrenaline + landed_damage * adrenaline_per_damage, adrenaline_max)

	landed.emit(target, result, dealt)


## Your guard coming up: the grip tightening in its leather and the blade
## brought across, both close and quiet, never twice in a breath.
func _guard_sound() -> void:
	if _game_time - _guard_sound_at < 0.25:
		return

	_guard_sound_at = _game_time
	Sfx.play_flat(player, &"grab", -9.0, randf_range(0.9, 1.0))
	Sfx.play_flat(player, &"blade_draw", -19.0, 1.3)


## Steel into him: the recording, higher for a dagger, lower and with a
## heavy thump under it for a blow that means it. A straw man says what it
## sounds like instead.
func _cut_sound(target: Node, at: Vector3, heavy: bool, dagger: bool) -> void:
	var pitch := 1.22 if dagger else 1.0
	var volume := -2.0 if dagger else 0.0

	if heavy:
		pitch *= 0.88
		volume += 2.5

	Sfx.play(player, target.get_meta(&"hit_sound", &"flesh"), at, volume, pitch)

	if heavy:
		Sfx.play(player, &"flesh_heavy", at, -4.0 if dagger else 0.0)

	# The blow's weight going into him: a body struck, under the cut.
	if not target.has_meta(&"hit_sound"):
		Sfx.play(player, &"kick", at, -9.0 if heavy else -14.0, 0.9 if heavy else 1.05)

	# On his helmet or a shoulder plate, the edge rings on the iron as it
	# bites.
	if target.has_method("armoured_at") and target.armoured_at(at):
		Sfx.play(player, &"ting", at, -1.0 if heavy else -4.0, 0.78 if heavy else 0.9)
		Sfx.play(player, &"clang", at, -12.0 if heavy else -15.0, 0.7)


## The body the blade met pushes back on it: the view kicks against the cut,
## knocked back more than turned.
func _recoil_view(strength: float) -> void:
	match _direction:
		&"overhead":
			player.juice.punch(0.45 * strength, 0.0)
			player.juice.lunge(0.35 * strength)
		&"left":
			player.juice.punch(0.12 * strength, -0.35 * strength)
			player.juice.lunge(0.25 * strength)
		&"right":
			player.juice.punch(0.12 * strength, 0.35 * strength)
			player.juice.lunge(0.25 * strength)
		&"thrust":
			player.juice.lunge(0.7 * strength)


## Up it went, and back it comes: no blow. A parry he spent on it is wasted.
func _feint() -> void:
	_spend(cost_feint)
	_reset()
	player.juice.set_zoom(0.0)
	Sfx.play_flat(player, &"whoosh_light", -12.0, 1.3)
	feinted.emit()

	# The press that feinted raises your guard, if you hold it.
	if weapon != null and weapon.can_block and Input.is_action_pressed("block"):
		blocking = true
		_block_started = _block_pressed_at
		_guard_sound()


# ---------------------------------------------------------------------------
# The dodge
# ---------------------------------------------------------------------------

func _try_dodge() -> void:
	if _dodge_cooldown > 0.0 or not player.is_on_floor() or stamina < 1.0:
		return

	if phase == Phase.STRIKE or phase == Phase.KICK or phase == Phase.DODGE or phase == Phase.STAGGER:
		return

	if phase == Phase.RECOVER and _t < _recovery * 0.25:
		return

	# The way you are moving, or straight back.
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	if axis.length() < 0.2:
		axis = Vector2(0.0, 1.0)

	var direction := player.global_basis * Vector3(axis.x, 0.0, axis.y)
	direction.y = 0.0
	direction = direction.normalized()

	_reset()
	_spend(cost_dodge)
	player.shove(direction * dodge_speed, dodge_time)
	_dodge_cooldown = dodge_time + dodge_cooldown
	_dodged_at = _game_time
	_enter(Phase.DODGE)
	# Lean into it.
	player.juice.punch(0.0, 0.0, -signf(axis.x) * 1.4)
	player.juice.on_impact(0.35)
	Sfx.play_flat(player, &"whoosh_light", -8.0, 0.75)
	Sfx.play_flat(player, &"cloth", -4.0)
	SoundBus.emit_sound(player.global_position, 38.0, player, &"step")
	dodged.emit(direction)


## Whether you dodged in the last `seconds`.
func dodged_within(seconds: float) -> bool:
	return _game_time - _dodged_at <= seconds


## You answered his blow as it asked (a dodge out of it at the last moment, a
## jump over his sweep): he is left overreaching. The moment hangs, your breath
## comes back, and your answer to him comes fast and hard, like a riposte.
func on_answered(how: StringName, _by: Node) -> void:
	TimeFx.request(get_tree(), &"answer", 0.45, 0.3)
	CombatView.jolt(get_tree(), 0.45)
	player.juice.add_trauma(0.15)
	adrenaline = minf(adrenaline + 12.0, adrenaline_max)
	stamina = minf(stamina + parry_refund, stamina_max)
	_riposte_until = _game_time + riposte_window
	Sfx.play_flat(player, &"ting", -6.0, 1.45)
	answered.emit(how)


# ---------------------------------------------------------------------------
# Defence: called by the player when something hits them
# ---------------------------------------------------------------------------

## How much of an incoming blow gets through. A raised guard facing the
## attacker takes most of it, for stamina; raised just in time, all of it,
## and the attacker reels. A kick goes through any guard.
func filter_incoming(amount: float, from: Node) -> float:
	var info: Dictionary = from.attack_info() if from != null and from.has_method("attack_info") else {}

	# Fire and the like: no guard for it, nothing to parry.
	if bool(info.get("hazard", false)):
		return amount

	if bool(info.get("unblockable", false)):
		_kicked_by(from)
		return amount

	# At your legs, under any guard and any parry: it had to be jumped.
	if bool(info.get("low", false)):
		adrenaline = minf(adrenaline + amount * adrenaline_per_hurt, adrenaline_max)
		return amount

	if not blocking or not (from is Node3D):
		adrenaline = minf(adrenaline + amount * adrenaline_per_hurt, adrenaline_max)
		return amount

	# A missile knows which way it came; a man is where he stands.
	var to_attacker: Vector3 = info.get("from_direction", (from as Node3D).global_position - player.global_position)
	to_attacker.y = 0.0
	var forward := -player.global_transform.basis.z

	if to_attacker.length() < 0.01 or forward.dot(to_attacker.normalized()) < 0.35:
		adrenaline = minf(adrenaline + amount * adrenaline_per_hurt, adrenaline_max)
		return amount

	SoundBus.emit_sound(player.global_position + Vector3.UP * 0.3, 56.0, player, &"clang")

	# Steel meets steel just in front of you.
	var at := aim()
	var clash := at.origin + at.basis * Vector3(0.08, -0.05, -0.6)
	var toward := ((from as Node3D).global_position + Vector3.UP * 1.3 - clash).normalized()
	var heavy: bool = bool(info.get("heavy", false))

	# An arrow on your blade: knocked away, a parry or not; the archer is
	# too far off to be thrown by it.
	if bool(info.get("ranged", false)):
		var parried: bool = _game_time - _block_started <= parry_window
		Fx.sparks(player, clash, to_attacker.normalized(), 0.9)
		Sfx.play(player, &"parry" if parried else &"clang", clash, -4.0, 1.35)

		if not parried:
			_spend(float(info.get("guard_damage", 6.0)))

		_hand(&"impact", [&"parry" if parried else &"block"])
		player.juice.add_trauma(0.2)
		defended.emit(&"parry" if parried else &"block")
		return 0.0

	if _game_time - _block_started <= parry_window:
		Fx.sparks(player, clash, toward, 1.8)
		Sfx.play(player, &"parry", clash)
		Sfx.play(player, &"clang", clash, -8.0, 1.1)
		# The moment hangs: a freeze, then a breath of slow motion.
		TimeFx.hitstop(get_tree(), 0.1, 0.03)
		TimeFx.request(get_tree(), &"parry", 0.35, 0.35)
		player.juice.add_trauma(0.3)
		CombatView.jolt(get_tree(), 0.8)
		_hand(&"impact", [&"parry"])

		if from.has_method("parried"):
			from.parried(player)

		adrenaline = minf(adrenaline + 10.0, adrenaline_max)
		stamina = minf(stamina + parry_refund, stamina_max)
		# Your answer comes fast and hard; and a combo's next blow can be
		# parried again at once.
		_riposte_until = _game_time + riposte_window
		_parry_ready_at = _game_time
		defended.emit(&"parry")
		return 0.0

	# A point driven at you: a raised blade turns it only partly, and dearly.
	# It had to be parried, or stepped aside from.
	var thrust: bool = bool(info.get("thrust", false))
	var cost: float = float(info.get("guard_damage", cost_block)) * (1.5 if thrust else 1.0)

	if stamina < cost:
		# Nothing left to hold it with: the guard is knocked aside and most
		# of the blow gets through.
		_spend(stamina)
		Fx.sparks(player, clash, toward, 1.4)
		Sfx.play(player, &"guard_break", clash)
		Sfx.play(player, &"clang", clash, 0.0, 0.8)
		TimeFx.hitstop(get_tree(), 0.08, 0.05)
		player.juice.add_trauma(0.6)
		CombatView.jolt(get_tree(), 0.9)
		_hand(&"impact", [&"block"])
		_stagger(guard_break_stagger, &"broken")

		if from.has_method("blocked_by"):
			from.blocked_by(player)

		defended.emit(&"broken")
		return amount * guard_break_damage

	_spend(cost)
	Fx.sparks(player, clash, toward, 1.5 if heavy else 1.1)
	Sfx.play(player, &"clang", clash, 3.0 if heavy else 0.0, 0.82 if heavy else 0.95)
	# The weight of it through your arms: a dull knock under the ring.
	Sfx.play(player, &"thud", clash, -4.0 if heavy else -9.0, 0.8)
	TimeFx.hitstop(get_tree(), 0.08 if heavy else 0.06, 0.05)
	player.juice.add_trauma(0.7 if heavy else 0.45)
	player.juice.punch(0.5 if heavy else 0.3, 0.0)
	player.juice.on_impact(0.9 if heavy else 0.55)
	CombatView.jolt(get_tree(), 0.55 if heavy else 0.3)
	_hand(&"impact", [&"block"])

	if from.has_method("blocked_by"):
		from.blocked_by(player)

	defended.emit(&"block")
	return amount * (0.4 if thrust else block_damage_scale)


## His boot: through any guard, it shoves you back and knocks you off
## balance, and it winds you.
func _kicked_by(from: Node) -> void:
	# A great blow (the brute's) is no kick: it flattens a guard and throws you.
	var info: Dictionary = from.attack_info() if from != null and from.has_method("attack_info") else {}
	var crushing: bool = bool(info.get("heavy", false))

	if from is Node3D:
		var push := player.global_position - (from as Node3D).global_position
		push.y = 0.0
		push = push.normalized() if push.length() > 0.01 else player.global_basis.z
		player.shove(push * (7.0 if crushing else 5.5), 0.34 if crushing else 0.3)

	_spend(30.0 if crushing else 20.0)
	_stagger(0.65 if crushing else 0.45, &"crushed" if crushing else &"kicked")
	player.juice.on_impact(1.5 if crushing else 1.0)


func is_parrying() -> bool:
	return blocking and _game_time - _block_started <= parry_window


## Knocked off balance: no blow and no guard until it passes.
func _stagger(seconds: float, why: StringName) -> void:
	_reset()
	_stagger_time = seconds
	_enter(Phase.STAGGER)
	staggered.emit(why)


## A blow got through to you: called by the player once it has landed.
func on_hurt(amount: float, from: Node) -> void:
	var info: Dictionary = from.attack_info() if from != null and from.has_method("attack_info") else {}
	# A boot, a blast, a flame, a thrown crate: it hurts, but nothing cut you.
	var kick: bool = bool(info.get("unblockable", false)) or bool(info.get("hazard", false)) or bool(info.get("blunt", false))

	# Cut while winding up or drawing: that blow is lost.
	if phase == Phase.WINDUP or phase == Phase.CHARGING or phase == Phase.DRAWING:
		_stagger(flinch_time, &"flinch")

	TimeFx.hitstop(get_tree(), 0.075, 0.06)
	var local := Vector3.ZERO

	if info.has("from_direction"):
		local = player.global_basis.inverse() * (info["from_direction"] as Vector3)
		local.y = 0.0
	elif from is Node3D:
		local = player.global_basis.inverse() * ((from as Node3D).global_position - player.global_position)
		local.y = 0.0

	player.juice.hurt_from(local, clampf(amount / 34.0, 0.4, 1.5))
	var side := clampf(local.x / maxf(local.length(), 0.01), -1.0, 1.0) if local.length() > 0.01 else 0.0
	CombatView.cut(get_tree(), clampf(0.45 + amount / 40.0, 0.5, 1.0), side)
	CombatView.jolt(get_tree(), clampf(amount / 35.0, 0.35, 1.0))
	var at := aim()

	if not kick:
		# His steel in you, heard from your own chest.
		Sfx.play(player, &"flesh", at.origin + at.basis * Vector3(0.0, -0.45, -0.3), 1.5, 0.95)

	Sfx.play_flat(player, &"hurt")

	if player.hud != null and player.hud.has_method("hurt_from"):
		player.hud.hurt_from(local)

	if kick:
		return

	# A spray from the wound, away from the blow, across the bottom of the view.
	var away := -local.normalized() if local.length() > 0.01 else Vector3.BACK
	var spray := at.basis * Vector3(away.x * 0.8, 0.5, -0.6)
	Fx.blood(player, at.origin + at.basis * Vector3(0.0, -0.45, -0.4), spray, 0.45)


# ---------------------------------------------------------------------------
# The drop attack
# ---------------------------------------------------------------------------

## Falling toward a guard below: remembers him, and a click while he is
## there is a drop attack when you land. True when the click was taken.
func _update_drop(attack_pressed: bool) -> bool:
	if player.is_on_floor() or player.velocity.y > -1.0:
		# Landed (on_landed has had its say) or going up: whatever was
		# waiting is over.
		_drop_target = null
		_drop_armed = false
		return false

	_drop_target = _find_drop_target()

	if _drop_target != null and attack_pressed and _can_drop_attack():
		_drop_armed = true
		_reset()
		return true

	return _drop_armed


func _can_drop_attack() -> bool:
	if weapon != null and weapon.kind == WeaponScript.Kind.MELEE:
		return true

	var item: Dictionary = player.inventory.selected_item() if player.inventory != null else {}
	return not item.is_empty() and item["id"] == &"blackjack"


func _find_drop_target() -> Node3D:
	var feet: Vector3 = player.get_feet_position()
	var best: Node3D = null
	var best_gap := drop_reach + 1.0

	for node in get_tree().get_nodes_in_group(&"guards"):
		var guard := node as Node3D

		if guard == null or not guard.has_method("take_hit"):
			continue

		var head: float = guard.global_position.y + float(guard.get("eye_height") if guard.get("eye_height") != null else 1.65)
		var above := feet.y - head

		if above < -0.3 or above > 7.0:
			continue

		var gap := Vector2(guard.global_position.x - feet.x, guard.global_position.z - feet.z).length()

		if gap < best_gap:
			best_gap = gap
			best = guard

	return best


## Called by the player on landing.
func on_landed(_fall_speed: float) -> void:
	var target := _drop_target
	var armed := _drop_armed
	_drop_armed = false
	_drop_target = null

	if not armed or target == null or not is_instance_valid(target):
		return

	var gap := Vector2(target.global_position.x - player.global_position.x, target.global_position.z - player.global_position.z).length()

	if gap <= drop_reach:
		_drop_attack(target)


func _drop_attack(target: Node3D) -> void:
	var item: Dictionary = player.inventory.selected_item() if player.inventory != null else {}
	var at: Vector3 = target.global_position + Vector3.UP * float(target.get("eye_height") if target.get("eye_height") != null else 1.65)

	# The blackjack, from above: out cold, fighting or not.
	if weapon == null and not item.is_empty() and item["id"] == &"blackjack":
		if target.has_method("knock_out") and target.knock_out(player, true):
			TimeFx.hitstop(get_tree(), 0.1, 0.05)
			player.juice.add_trauma(0.4)
			drop_attacked.emit(target)

		return

	if weapon == null:
		return

	# Point down, all your weight behind it.
	_direction = &"overhead"
	_power = true
	_finisher = false
	_riposte = false
	_hit_this_swing.clear()
	_hit_this_swing[target] = true
	_enter(Phase.STRIKE)
	_strike_time = weapon.strike_time
	_t = _strike_time * 0.45
	_last_sweep = 0.45
	_hand(&"set_trail", [true, true])
	var result: StringName = target.take_hit(drop_damage, player, &"drop", at, Vector3.DOWN)
	SoundBus.emit_sound(at, weapon.hit_db + 4.0, player, &"hit")
	TimeFx.hitstop(get_tree(), 0.15, 0.03)
	player.juice.add_trauma(0.7)
	player.juice.on_impact(1.4)
	_hand(&"impact", [&"heavy"])
	_hand(&"bloody", [0.5])
	Sfx.play(player, &"flesh", at, 3.0, 0.8)
	Sfx.play(player, &"flesh_heavy", at, 3.0)
	_outcome = &"hit"
	adrenaline = minf(adrenaline + 25.0, adrenaline_max)
	landed.emit(target, result, drop_damage)
	drop_attacked.emit(target)


# ---------------------------------------------------------------------------
# The kick
# ---------------------------------------------------------------------------

func _start_kick() -> void:
	_kick_momentum = Vector2(player.velocity.x, player.velocity.z).length() > 4.0 or not player.is_on_floor()
	_reset()
	_enter(Phase.KICK)
	_kick_landed = false
	_kick_cooldown = kick_cooldown + kick_time
	_spend(cost_kick)
	_hand(&"play_kick")
	player.juice.on_kick()
	Sfx.play_flat(player, &"whoosh_light", -6.0, 0.8)

	if randf() < 0.6:
		Sfx.play_flat(player, &"effort", -6.0, 1.05)


## Whether the kick now landing had a run or a leap behind it (a man kicked so
## goes off his feet: Guard.kick).
func kick_had_momentum() -> bool:
	return _kick_momentum


## Nothing solid between the hip and where the boot lands, other than the
## thing being kicked.
func _within_reach(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, target: Node3D) -> bool:
	var exclude: Array[RID] = [player.get_rid()]

	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())

	var ray := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
	ray.collide_with_areas = false
	return space.intersect_ray(ray).is_empty()


func _update_kick(delta: float) -> void:
	_t += delta

	if not _kick_landed and _t >= kick_time * 0.35:
		_kick_landed = true
		_kick_contact()

	if _t >= kick_time:
		_enter(Phase.IDLE)


func _kick_contact() -> void:
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var sphere := SphereShape3D.new()
	sphere.radius = 0.55

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, player.global_position + forward * (kick_reach - 0.55))
	query.collision_mask = 1 | 2 | 4
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false

	var struck := false
	var contact := player.global_position + forward * 0.9

	var space := player.get_world_3d().direct_space_state
	var hip := player.global_position + Vector3.UP * 0.2
	var boot := query.transform.origin

	var booted := {}

	for hit in space.intersect_shape(query, 8):
		var collider: Object = hit.get("collider")

		if collider == null:
			continue

		# A limb: its man, once. Down but alive, he is kicked along; a dead
		# man is shoved.
		var limb_of := RagdollScript.owner_of(collider)

		if limb_of != null:
			if booted.has(limb_of):
				continue

			booted[limb_of] = true

			if not limb_of.has_method("kick"):
				var rag: Node = RagdollScript.of(collider)

				if rag != null:
					rag.shove(forward * kick_speed * 0.7 + Vector3.UP * 1.5, (collider as Node3D).global_position, 0.6)
					Sfx.play(player, &"kick", (collider as Node3D).global_position)
					Fx.dust(player, (collider as Node3D).global_position, -forward, 0.4, "carpet")
					kicked.emit(limb_of)
					struck = true

				continue

			collider = limb_of

		# Only what the boot can reach: nothing kicked through a wall.
		if collider is Node3D and not _within_reach(space, hip, boot, collider as Node3D):
			continue

		if collider.has_method("kick"):
			var body := collider as Node3D
			contact = body.global_position + Vector3.UP * 1.1 - forward * 0.3
			collider.kick(forward * kick_speed, player)
			adrenaline = minf(adrenaline + 8.0, adrenaline_max)
			Sfx.play(player, &"kick", contact)
			Fx.dust(player, contact, -forward, 0.4, "carpet")
			kicked.emit(collider)
			struck = true
		elif collider is RigidBody3D and not (collider as RigidBody3D).freeze:
			var body := collider as RigidBody3D
			# Set, not applied: an impulse only shows in linear_velocity after
			# the next step, and what follows its flight must know it now.
			body.sleeping = false
			body.linear_velocity += (forward + Vector3.UP * 0.25) * kick_impulse / maxf(body.mass, 0.1)

			if body.has_method("strike"):
				body.strike(&"kick", body.global_position, forward)

			if player.frob != null and player.frob.has_method("arm_impact_noise"):
				player.frob.arm_impact_noise(body)

			contact = body.global_position - forward * 0.2
			Sfx.play(player, &"thud_wood", contact)
			Fx.dust(player, contact, -forward, 0.6, "wood")
			kicked.emit(collider)
			struck = true
		elif collider is Door and collider.get("is_open") == false and collider.get("locked") != true:
			# An unlocked door bursts open. A locked one only shudders.
			collider.frob(player)
			Sfx.play(player, &"thud_wood", contact, 3.0, 0.85)
			Fx.dust(player, contact, -forward, 0.8, "wood")
			kicked.emit(collider)
			struck = true

	if struck:
		TimeFx.hitstop(get_tree(), 0.07, 0.05)
		player.juice.add_trauma(0.4)
		player.juice.punch(-0.3, 0.0)
		player.juice.on_kick_land(1.0)
		_hand(&"impact", [&"kick"])
	else:
		# Nothing that moves: did the boot meet a wall?
		var foot := player.global_position + Vector3.DOWN * 0.3
		var ray := PhysicsRayQueryParameters3D.create(foot, foot + forward * kick_reach, 1, [player.get_rid()])
		var wall := player.get_world_3d().direct_space_state.intersect_ray(ray)

		if not wall.is_empty():
			Fx.dust(player, wall["position"], wall["normal"], 0.7, _surface_of(wall.get("collider")))
			Sfx.play(player, &"thud", wall["position"], -3.0)
			TimeFx.hitstop(get_tree(), 0.04, 0.08)
			player.juice.add_trauma(0.25)
			_hand(&"impact", [&"kick"])
			struck = true

	if struck:
		player.juice.on_impact(0.9)

	SoundBus.emit_sound(player.global_position + forward, kick_db if struck else kick_db - 12.0, player, &"kick")


# ---------------------------------------------------------------------------
# The bow
# ---------------------------------------------------------------------------

func _update_draw(delta: float, attack_held: bool) -> void:
	draw = clampf(draw + delta / maxf(weapon.draw_time, 0.01), 0.0, 1.0)
	player.juice.set_zoom(12.0 * draw)

	if Input.is_action_just_pressed("block"):
		# Let the string down without loosing.
		draw = 0.0
		player.juice.set_zoom(0.0)
		_enter(Phase.IDLE)
		return

	if attack_held:
		return

	var loosed := draw >= 0.15 and arrow_count() > 0

	if loosed:
		_loose()

	draw = 0.0
	player.juice.set_zoom(0.0)
	# The next arrow has to be fetched and put on the string (HandSlot).
	_recovery = 0.55 if loosed else 0.25
	_outcome = &"miss"
	_enter(Phase.RECOVER)


func _loose() -> void:
	var at := aim()
	var forward := -at.basis.z
	var strength := draw

	# Out past the bow, unless something is closer than that: then from the
	# eye, so its first step meets it rather than starting beyond it.
	var spawn := at.origin + forward * 0.6
	var clear := PhysicsRayQueryParameters3D.create(at.origin, spawn, 1 | 2, [player.get_rid()])

	if not player.get_world_3d().direct_space_state.intersect_ray(clear).is_empty():
		spawn = at.origin

	var arrow: StaticBody3D = ArrowScript.new()
	player.get_parent().add_child(arrow)
	arrow.launch(
		spawn,
		forward * lerpf(weapon.arrow_speed_min, weapon.arrow_speed_max, pow(strength, 0.8)),
		lerpf(weapon.arrow_damage_min, weapon.arrow_damage_max, strength),
		player,
		weapon.headshot_multiplier
	)
	_consume_arrow()
	SoundBus.emit_sound(player.global_position, weapon.swing_db, player, &"twang")
	Sfx.play(player, &"twang", at.origin, lerpf(-2.0, 1.0, strength), lerpf(1.15, 0.95, strength))
	_hand(&"impact", [&"bow"])
	player.juice.punch(0.25 * strength, 0.0)
	fired.emit(arrow)


func arrow_count() -> int:
	for entry in player.inventory.belt:
		if entry["id"] == &"arrows":
			return int(entry["count"])

	return 0


func _consume_arrow() -> void:
	for entry in player.inventory.belt:
		if entry["id"] == &"arrows":
			entry["count"] = maxi(int(entry["count"]) - 1, 0)
			player.inventory.changed.emit()
			return


# ---------------------------------------------------------------------------
# How the weapon hand looks
# ---------------------------------------------------------------------------

## Poses the weapon in your view (ViewPoses.gd). A swing follows its arc
## exactly: cocked, cut (faster and faster), followed through (slowing); a
## recovery eases back from wherever the blade stopped. Everything else
## glides.
func _send_pose(delta: float) -> void:
	if weapon == null:
		return

	var poses: Dictionary = ViewPoses.set_of(weapon.id)
	var bow: bool = weapon.kind == WeaponScript.Kind.BOW
	var sweeps: Dictionary = poses.get("sweeps", {})
	var sweep: Dictionary = sweeps.get(_direction, sweeps.get(&"overhead", {}))
	var rest := _rest_frame(poses, delta)
	var target := rest
	var exact := true

	match phase:
		Phase.WINDUP:
			# Drawn back: fast away from guard, settling as it loads.
			var w := _ease_out(_t / maxf(_windup, 0.01))
			target = ViewPoses.blend(_windup_from, _drawn(sweep, 0.0, rest), w)
		Phase.CHARGING:
			var c := _ease_out(_charge)
			var tremble := sin(_game_time * 60.0) * 0.006 * _charge
			target = _drawn(sweep, c, rest)
			target.origin += Vector3(tremble, tremble * 0.5, 0.0)
		Phase.STRIKE:
			var p := clampf(_t / maxf(_strike_time, 0.01), 0.0, 1.0)
			# Faster and faster into the cut, the body's turn carrying it on
			# after, slowing.
			var u := 0.5 * pow(p / 0.5, 2.0) if p < 0.5 else 0.5 + 0.5 * _ease_out((p - 0.5) / 0.5)
			target = ViewPoses.sweep_frame(sweep, u, 1.0 if _power else 0.0) if not sweep.is_empty() else rest
		Phase.RECOVER:
			# Back to guard, lifted on the way (not dragged along under the
			# view), and settling into it: it comes a little past, and back.
			var r := _ease_in_out(_t / maxf(_recovery, 0.01))
			target = ViewPoses.blend(_recover_from, rest, r)
			target.origin += Vector3(0.0, 0.07, -0.03) * sin(PI * minf(r / 0.7, 1.0))
			target.origin += Vector3(0.006, -0.018, 0.01) * sin(PI * clampf((r - 0.7) / 0.3, 0.0, 1.0))
		Phase.DRAWING:
			# Up to the eye in the first part of the draw, then the pull.
			var raise := _ease_out(clampf(draw * 2.2, 0.0, 1.0))
			var strain := sin(_game_time * 26.0) * 0.004 * draw * draw
			target = ViewPoses.blend(ViewPoses.bow_frame(poses["rest"]), ViewPoses.bow_frame(poses["drawn"]), raise)
			target.origin += Vector3(strain, strain * 0.6, 0.0)
		Phase.KICK:
			# Braced for the kick: the weapon drawn back out of the way.
			target = _pose(poses, "kick", rest)
			exact = false
		Phase.STAGGER:
			target = _pose(poses, "stagger", rest)
			exact = false
		_:
			exact = false

	if _drop_armed:
		target = _pose(poses, "drop", rest)
		exact = false

	if blocking and not bow:
		target = _pose(poses, "block", rest)

	if not exact:
		var follow := 1.0 - exp(-(24.0 if blocking or phase == Phase.STAGGER else 14.0) * delta)
		target = ViewPoses.blend(_shown, target, follow)

	_shown = target
	_hand(&"set_weapon_frame", [target])
	_hand(&"set_brace", [1.0 if blocking and weapon.id == &"sword" else 0.0])

	var hand: Node = player.hand

	if hand != null and hand.has_method("set_bow_draw"):
		var bow_up: bool = bow and arrow_count() > 0
		hand.set_bow_draw(draw if phase == Phase.DRAWING else 0.0, WeaponScript.arrow_mesh() if bow_up else null)


## Where the weapon settles when nothing is happening: its rest, carried
## lower through a sprint.
func _rest_frame(poses: Dictionary, delta: float) -> Transform3D:
	var bow: bool = weapon != null and weapon.kind == WeaponScript.Kind.BOW
	var sprinting: bool = player.has_method("_is_sprinting") and player._is_sprinting() and Vector2(player.velocity.x, player.velocity.z).length() > float(player.get("walk_speed")) + 0.3
	_sprint = move_toward(_sprint, 1.0 if sprinting and phase == Phase.IDLE and not blocking else 0.0, delta * 4.0)
	var rest: Transform3D = ViewPoses.bow_frame(poses["rest"]) if bow else ViewPoses.frame(poses["rest"])

	if _sprint > 0.0 and poses.has("sprint"):
		var run: Transform3D = ViewPoses.bow_frame(poses["sprint"]) if bow else ViewPoses.frame(poses["sprint"])
		rest = ViewPoses.blend(rest, run, _ease_in_out(_sprint))

	return rest


## A sweep drawn back, `charged` 0..1 further; `fallback` with no sweep.
static func _drawn(sweep: Dictionary, charged: float, fallback: Transform3D) -> Transform3D:
	return ViewPoses.sweep_frame(sweep, 0.0, charged) if not sweep.is_empty() else fallback


static func _pose(poses: Dictionary, key: String, fallback: Transform3D) -> Transform3D:
	return ViewPoses.frame(poses[key]) if poses.has(key) else fallback


func _hand(method: StringName, args: Array = []) -> void:
	var hand: Node = player.hand

	if hand != null and hand.has_method(method):
		hand.callv(method, args)


static func _ease_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c)


static func _ease_in_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _ensure_action(action: StringName, key: Key, mouse_button := -1) -> void:
	if InputMap.has_action(action):
		return

	InputMap.add_action(action)

	if key != KEY_NONE:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)

	if mouse_button != -1:
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = mouse_button
		InputMap.action_add_event(action, mouse_event)
