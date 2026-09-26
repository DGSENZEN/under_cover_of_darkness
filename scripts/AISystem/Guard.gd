class_name Guard
extends CharacterBody3D
## A guard: two senses feeding one number, and behaviour that follows it.
##
##   SENSES      vision (light x distance x view cone x cover) and hearing
##               (SoundBus events, carried along the navmesh) both push `alert`.
##   ALERT       0..100. It rises fast, holds, then decays slowly. Hearing
##               alone can never reach combat: that takes actually seeing you.
##   BEHAVIOUR   RELAXED patrols. SUSPICIOUS stops and looks. INVESTIGATING
##               walks to where the stimulus was. SEARCHING checks around it.
##               COMBAT chases while it can see you.
##
## The body origin is at the FEET. The capsule floats above step height and
## the body hovers on a ray, so stairs need no special handling.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const GuardBodyScript := preload("res://scripts/AISystem/GuardBody.gd")
const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const GuardRigScript := preload("res://scripts/AISystem/GuardRig.gd")
const GuardFighterScript := preload("res://scripts/AISystem/GuardFighter.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
## Bleeding (bleeding): at most this much a second, never below this share of
## his health, and bound this long after he last saw you.
const BLEED_MAX := 4.0
const BLEED_FLOOR := 0.12
const BIND_AFTER := 3.0
## A man cut apart shakes whoever sees it from this far.
const GORE_SEEN_RANGE := 14.0

## Off, cuts do not bleed (tests of exact damage).
static var bleeding_on := true

enum Alert {
	RELAXED,
	SUSPICIOUS,
	INVESTIGATING,
	SEARCHING,
	COMBAT,
}

signal alert_changed(new_state: int, old_state: int)
signal barked(text: String)
signal caught_player(player: Node3D)
signal knocked_out(body: RigidBody3D)
signal found_body(body: Node3D)
signal died(body: RigidBody3D)
signal hurt(amount: float)
## His guard was knocked aside (a power blow, a kick, too many quick cuts).
signal guard_broken
## He started a blow and abandoned it on the way up.
signal feinted
## A weapon reached him: "blocked", "parried", "hit" or "killed".
signal struck_by(result: StringName, kind: StringName, damage: float)
## Thrown off his balance (GuardFighter's posture): OPEN to a deathblow.
signal posture_broken
## You answered his blow as it asked: "dodged" out of it at the last moment,
## "jumped" his sweep (GuardFighter._answered).
signal answered(how: StringName)
## A blow landed while he was open.
signal deathblow
## He bound his wounds (bleeding stopped).
signal bound_wounds


@export_category("Patrol")
## A node whose children are the waypoints, visited in order, looping. While
## waiting at one, the guard faces the way that waypoint's -Z points.
@export var patrol_route: NodePath
@export var patrol_wait := 2.0
@export var patrol_speed := 1.6
@export var investigate_speed := 2.4
@export var chase_speed := 4.6
@export var acceleration := 12.0
@export var turn_speed := 5.0


@export_category("Vision")
@export var eye_height := 1.65
## Full view cone, in degrees.
@export var fov_horizontal := 140.0
@export var fov_vertical := 90.0
## Beyond this fraction of the half-angle, sight weakens toward the edge.
@export_range(0.0, 1.0, 0.05) var peripheral_start := 0.55
@export_range(0.0, 1.0, 0.05) var peripheral_strength := 0.4
## Fully lit: certain inside sight_min, invisible beyond sight_max. Both
## shrink with the target's exposure, so darkness collapses the whole cone.
@export var sight_min := 12.0
@export var sight_max := 35.0
## Alert per second at full visibility.
@export var vision_gain := 170.0
## Close enough to bump into: noticed whatever the light.
@export var touch_distance := 1.0
@export_flags_3d_physics var sight_mask := 1


@export_category("Hearing")
@export var hearing_acuity := 1.0
## Sound can raise alert to this and no further.
@export var hearing_alert_cap := 85.0


@export_category("Alert")
@export var suspicious_at := 20.0
@export var investigate_at := 45.0
@export var combat_at := 100.0
## Visibility needed, at that moment, to tip into combat.
@export var combat_needs_visibility := 0.25
## After the last stimulus, alert holds this long before it starts to fall.
@export var alert_hold_time := 2.0
@export var alert_decay := 12.0
## Seconds without sight before a chase becomes a search.
@export var lose_time := 4.0
@export var look_around_time := 3.0
@export var search_points := 3
@export var search_radius := 6.0
## Every scare leaves the guard a little sharper for the rest of the night.
@export var wariness_per_scare := 0.15
@export var wariness_max := 1.6
@export var catch_distance := 1.3


@export_category("Combat")
## "swordsman", "duelist", "brute" or "trainer" (see GuardFighter.gd). Empty
## is the plain watchman. Set before he enters the tree.
@export var archetype: StringName = &""
@export var attack_range := 1.7
## He cannot reach you on a ledge above him or below him.
@export var attack_reach_height := 1.2
@export var attack_damage := 34.0
@export var attack_cooldown := 1.1
@export var max_health := 100.0
## The raised blade before a blow: long enough to see coming and answer.
@export var windup_time := 0.55
@export var strike_time := 0.12
@export var recover_time := 0.55
## While fighting, the chance he raises his guard against a blow he sees
## coming. Up, it catches quick cuts from the front; a power blow, a kick, or
## enough quick cuts break it. Blows from behind and arrows get past it.
@export_range(0.0, 1.0, 0.05) var block_chance := 0.35
@export var stagger_time := 0.45
## Parried: he reels this long, wide open.
@export var parry_stun := 1.3
## Kicked: this long sliding, with no control.
@export var knockdown_time := 1.1
## Landing faster than this hurts him. 11 m/s is a fall of about 2.5 m;
## at 20 per m/s past it, 4 m hurts badly and 6 m is fatal.
@export var fall_damage_speed := 11.0
@export var fall_damage_per_speed := 20.0


@export_category("Pathing")
## A new goal closer than this to the current one keeps the current path.
@export var repath_distance := 0.5
## A locked door he has no key for is tried once, then left alone this long.
@export var locked_door_memory := 30.0
## Walking but not getting anywhere for this long (a jammed door, a crate in
## a corridor, another guard): the goal counts as reached.
@export var stuck_timeout := 1.5
## A patrol waypoint counts as reached within this distance.
@export var waypoint_radius := 1.0


@export_category("Alarm")
## Entering combat or finding a body, the guard shouts. Others who hear it
## come to where HE thinks the trouble is.
@export var shout_db := 72.0
@export var shout_alert := 60.0
## How lit a body has to be before it can be noticed at all.
@export var body_min_light := 0.08
## Seconds of seeing a body before it registers.
@export var body_notice_time := 0.5
@export var body_wariness := 0.3


@export_category("Voice")
## Who the subtitles say is speaking.
@export var speaker_name := "Guard"


@export_category("Keys")
## Doors with these key ids open for this guard.
@export var keys: Array[StringName] = []


@export_category("Debug")
## Draws the view cone, state and alert. Off by default: turn it on per guard
## or per level while tuning.
@export var debug_ai := false


var alert := 0.0
var state := Alert.RELAXED
var wariness := 1.0

## How visible the player is to this guard right now, 0..1.
var visibility := 0.0
var can_see_target := false
var last_known_position := Vector3.ZERO
var has_last_known := false

## Door.gd asks the frobber for an inventory with has_key().
var inventory := GuardKeys.new()

var _target: Node3D = null
var _agent: NavigationAgent3D
var _head: Node3D
var _bark_label: Label3D

var _waypoints: Array[Node3D] = []
var _waypoint_index := 0
var _wait_timer := 0.0
var _home := Transform3D.IDENTITY

var _since_stimulus := 99.0
var _since_seen := 99.0
var _look_timer := 0.0
var _look_from_yaw := 0.0
var _search_left := 0
var _door_wait := 0.0
var _bark_timer := 0.0
var _head_yaw_goal := 0.0
var _idle_time := 0.0
var _attack_timer := 0.0

## How many times this guard has asked for a new path. For tests and profiling.
var path_requests := 0

## Set when something on the path (a locked door) cannot be passed. The
## current goal then counts as reached: as far as he can get.
var _path_blocked := false
var _tried_doors := {}

var _knocked_out := false

var health := 100.0
## "", "windup", "strike" or "recover".
var _phase: StringName = &""
var _phase_timer := 0.0
## How long the current phase lasts in all (its timer counts down from this).
var _phase_length := 0.0
## Which blow: "overhead", "left", "right", "thrust", "heavy" or "kick".
var _attack: StringName = &"overhead"
## How he fights: GuardFighter.gd.
var _fighter: RefCounted
## On fire: seconds left, the flames on him, where he is running.
var _burning := 0.0
var _burn_tick := 0.0
var _flames: Node3D
var _flee := Vector3.ZERO
var _flee_timer := 0.0
var _stagger := 0.0
var _knock := 0.0
var _knock_velocity := Vector3.ZERO
var _block_flash := 0.0
var _fall_peak := 0.0
var _weapon: MeshInstance3D
var _body_mesh: Node3D
## How he looks and moves: presentation only, in GuardRig.gd.
var _rig: Node3D
## The last blow that landed on him, for which way he falls.
var _last_blow := Vector3.ZERO
## How the blow that kills him throws his body, and where it struck.
var _last_push := Vector3.ZERO
var _last_at := Vector3.INF
## What the blow now landing would cut off him, should it kill him (the
## attacker says: PlayerCombat), and what the one that killed him did.
var sever_hint: Array[StringName] = []
var _sever: Array[StringName] = []
## Open wounds: health lost a second, and the trail of drops he leaves. Deep
## cuts open more; they close slowly on their own, or at once when he has a
## moment to bind them (he has lost you). Bleeding alone never takes him
## below BLEED_FLOOR of his health.
var bleeding := 0.0
var _drip := 0.0
## The last wound, in his own space: where the drops fall from.
var _wound_local := Vector3(0.0, 1.2, 0.0)
## What he last found himself standing on (floor_surface), and when.
var _floor_surface := ""
var _floor_checked_at := -10.0
## When he last cried out (voice).
var _voice_at := -10.0
## Off his feet (a kick, a blast, a man flung into him): physics has him
## (Ragdoll.gd) and he stands in for himself where his hips are, until he
## lands, lies still a moment, and gets up.
var _downed := false
var _down_time := 0.0
var _down_still := 0.0
var _down_peak := 0.0
var _down_layer := 2
## Getting up: seconds left.
var _rising := 0.0
var _skid := 0.0
## Seconds of game time since this guard appeared.
var _game_time := 0.0
var _stuck_time := 0.0
var _last_walk_position := Vector3.ZERO
var _waypoint_retries := 0
var _retry_timer := 0.0
var _body_check_timer := 0.0
var _body_notice := {}
var _known_bodies := {}


class GuardKeys:
	var ids: Array[StringName] = []

	func has_key(key_id: StringName) -> bool:
		return ids.has(key_id)


func _ready() -> void:
	add_to_group(&"guards")
	# Whoever made him may place him after adding him: draw him from there.
	reset_physics_interpolation.call_deferred()
	collision_layer = 2
	collision_mask = 3

	_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	_head = get_node_or_null("Head") as Node3D
	_bark_label = get_node_or_null("Bark") as Label3D
	_home = global_transform
	inventory.ids = keys
	randomize()

	if _agent != null:
		_agent.path_desired_distance = 0.5
		_agent.target_desired_distance = 0.6

	if not patrol_route.is_empty():
		var route := get_node_or_null(patrol_route)

		if route != null:
			for child in route.get_children():
				if child is Node3D:
					_waypoints.append(child)

	# Spread the expensive body checks of many guards across frames.
	_body_check_timer = randf() * 0.15

	_fighter = GuardFighterScript.new(self)
	_fighter.apply(archetype)
	_fit_body_to_look()
	health = max_health
	_rig = GuardRigScript.new()
	_rig.setup(self)
	_weapon = _rig.weapon
	_body_mesh = _rig.body_mesh

	if not _waypoints.is_empty():
		_waypoint_index = 0
		_go_to(_waypoints[0].global_position, true)


## Listening starts and stops with the tree, so a guard that is moved or
## re-added does not go deaf.
func _enter_tree() -> void:
	SoundBus.add_listener(self)


func _exit_tree() -> void:
	SoundBus.remove_listener(self)


func _physics_process(delta: float) -> void:
	if _knocked_out:
		return

	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(&"player") as Node3D

	_since_stimulus += delta
	_since_seen += delta
	_idle_time += delta

	_game_time += delta
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_stagger = maxf(_stagger - delta, 0.0)
	_block_flash = maxf(_block_flash - delta, 0.0)

	if bleeding > 0.0:
		_bleed_tick(delta)

	if _downed:
		_update_downed(delta)
		return

	_rising = maxf(_rising - delta, 0.0)

	_sense_vision(delta)
	_sense_bodies(delta)
	_update_alert(delta)

	if _burning > 0.0:
		_burn(delta)

		if _knocked_out:
			return

	if _knock > 0.0:
		# Sent flying: no say in where he goes.
		_knock -= delta
		velocity.x = _knock_velocity.x
		velocity.z = _knock_velocity.z
		_knock_velocity = _knock_velocity.move_toward(Vector3.ZERO, 7.0 * delta)
		_skid_dust(delta)
	elif _burning > 0.0:
		_run_burning(delta)
	elif _stagger > 0.0:
		_stop(delta)

		# Getting up, he looks nowhere but at the floor.
		if state == Alert.COMBAT and _rising <= 0.0:
			_fighter.watch(delta)
	else:
		match state:
			Alert.RELAXED:
				_do_patrol(delta)
			Alert.SUSPICIOUS:
				_do_suspicious(delta)
			Alert.INVESTIGATING:
				_do_investigate(delta)
			Alert.SEARCHING:
				_do_search(delta)
			Alert.COMBAT:
				_do_combat(delta)

	_apply_ground(delta)

	if _knocked_out:
		return

	move_and_slide()

	if _knock <= 0.0:
		_open_doors_in_the_way()

	_update_head(delta)
	_update_weapon(delta)
	_update_bark(delta)

	if debug_ai:
		_debug_draw()


# ---------------------------------------------------------------------------
# Senses
# ---------------------------------------------------------------------------

func eye_position() -> Vector3:
	return global_position + Vector3.UP * eye_height


func look_direction() -> Vector3:
	var basis := global_transform.basis if _head == null else _head.global_transform.basis
	return -basis.z


func _sense_vision(delta: float) -> void:
	# A body on the floor, the player's included, is not someone to chase.
	if _target != null and _target.get("is_dead") == true:
		visibility = 0.0
		can_see_target = false
		return

	visibility = _visibility_of(_target)
	can_see_target = visibility > 0.02

	if not can_see_target:
		return

	_since_seen = 0.0
	_since_stimulus = 0.0
	last_known_position = _target.global_position
	has_last_known = true
	alert = minf(alert + visibility * vision_gain * wariness * delta, combat_at)


## Light, distance, view cone and cover, multiplied together.
func _visibility_of(target: Node3D) -> float:
	if target == null or not target.has_method("get_exposure"):
		return 0.0

	var eye := eye_position()
	var points: Array = target.get_sight_points()
	var seen := 0
	var cone := 0.0
	var nearest := INF

	for point in points:
		var to_point: Vector3 = point - eye
		var distance := to_point.length()
		var factor := _cone_factor(to_point)

		if factor <= 0.0:
			continue

		if not _line_of_sight(eye, point, target):
			continue

		seen += 1
		cone = maxf(cone, factor)
		nearest = minf(nearest, distance)

	if seen == 0:
		return 0.0

	var cover := float(seen) / float(points.size())
	var exposure: float = target.get_exposure()

	# The Dark Mod's rule: both distances scale with how lit the target is.
	var certain := sight_min * exposure
	var gone := certain + (sight_max - sight_min) * exposure
	var by_distance := exposure

	if nearest > certain:
		if nearest >= gone:
			by_distance = 0.0
		else:
			by_distance = exposure * (1.0 - (nearest - certain) / (gone - certain))

	var result := by_distance * cone * cover

	# Walking into a guard is noticed whatever the light; so is a man he is
	# crossing swords with, at arm's length.
	if nearest <= touch_distance or (state == Alert.COMBAT and nearest <= 3.0):
		result = maxf(result, 0.6)

	return clampf(result, 0.0, 1.0)


## 1 in the middle of the view, fading toward the edge, 0 outside it.
func _cone_factor(to_point: Vector3) -> float:
	var basis := global_transform.basis if _head == null else _head.global_transform.basis
	var local := basis.inverse() * to_point

	if local.z >= 0.0:
		return 0.0

	var yaw := absf(atan2(local.x, -local.z))
	var pitch := absf(atan2(local.y, Vector2(local.x, local.z).length()))
	var half_h := deg_to_rad(fov_horizontal * 0.5)
	var half_v := deg_to_rad(fov_vertical * 0.5)

	if yaw > half_h or pitch > half_v:
		return 0.0

	var edge := maxf(yaw / half_h, pitch / half_v)

	if edge <= peripheral_start:
		return 1.0

	var t := (edge - peripheral_start) / maxf(1.0 - peripheral_start, 0.001)
	return lerpf(1.0, peripheral_strength, t)


func _line_of_sight(from: Vector3, to: Vector3, target: Node3D) -> bool:
	var exclude: Array[RID] = [get_rid()]

	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())

	var query := PhysicsRayQueryParameters3D.create(from, to, sight_mask, exclude)
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## SoundBus calls this for every gameplay sound in the level.
func hear_sound(event: Dictionary) -> void:
	if _knocked_out:
		return

	var source: Object = event["source"]
	var reach: float = event["range"] * hearing_acuity

	# A path is never shorter than the straight line, so this settles most
	# sounds without asking the navmesh anything.
	var sound_at: Vector3 = event["position"]

	if global_position.distance_to(sound_at) > reach:
		return

	if source is Guard:
		# A colleague shouting: go to where HE thinks the trouble is.
		if event["kind"] == &"shout" and state != Alert.COMBAT:
			var from: Vector3 = event["position"]

			if _sound_distance(from) <= reach:
				var other := source as Guard
				last_known_position = other.last_known_position if other.has_last_known else from
				has_last_known = true
				alert = maxf(alert, shout_alert)
				_since_stimulus = 0.0

		return

	var position: Vector3 = event["position"]
	var distance := _sound_distance(position)

	if distance > reach:
		return

	var db: float = event["db"]
	var closeness := 1.0 - distance / reach
	var amount := clampf((db - 25.0) * 1.6, 0.0, 70.0) * closeness * wariness

	if amount < 1.0:
		return

	alert = maxf(alert, minf(alert + amount, hearing_alert_cap))
	_since_stimulus = 0.0

	# Hearing is imprecise: the farther away, the vaguer the position.
	var blur := distance * 0.08
	last_known_position = position + Vector3(randf_range(-blur, blur), 0.0, randf_range(-blur, blur))
	has_last_known = true


## Sound travels along the navmesh, so a wall between you and the guard makes
## the sound go around it. No path at all counts as twice the straight line.
func _sound_distance(position: Vector3) -> float:
	var straight := global_position.distance_to(position)
	var map := get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, global_position, position, true)

	if path.size() < 2:
		return straight * 2.0

	# The path ends at the closest point on the mesh, which may be short of the sound.
	if path[path.size() - 1].distance_to(position) > 2.0:
		return straight * 2.0

	var length := 0.0

	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])

	return maxf(length, straight)


# ---------------------------------------------------------------------------
# Bodies, shouting, and being knocked out
# ---------------------------------------------------------------------------

## A body is only a problem if it can be SEEN, and that takes light. The
## lightgem only measures the player, so bodies are measured by arithmetic.
func _sense_bodies(delta: float) -> void:
	_body_check_timer -= delta

	if _body_check_timer > 0.0:
		return

	var interval := 0.15
	_body_check_timer = interval

	for body in get_tree().get_nodes_in_group(&"bodies"):
		if _known_bodies.has(body) or not (body is Node3D) or not body.visible:
			continue

		var at: Vector3 = body.global_position + Vector3.UP * 0.25
		var to_body := at - eye_position()
		var cone := _cone_factor(to_body)

		if cone <= 0.0 or not _line_of_sight(eye_position(), at, body):
			_body_notice.erase(body)
			continue

		var exclude: Array[RID] = [get_rid()]

		if body is CollisionObject3D:
			exclude.append(body.get_rid())

		var light := LightProbe.light_at(self, at, exclude)

		if light < body_min_light:
			_body_notice.erase(body)
			continue

		# The same distance rule as for the player, with the body's light.
		var certain := sight_min * light
		var gone := certain + (sight_max - sight_min) * light
		var distance := to_body.length()

		if distance >= gone:
			_body_notice.erase(body)
			continue

		var seen: float = _body_notice.get(body, 0.0) + interval * cone
		_body_notice[body] = seen

		if seen >= body_notice_time:
			_discover(body)


func _discover(body: Node3D) -> void:
	_known_bodies[body] = true
	_body_notice.erase(body)
	body.set("discovered", true)

	last_known_position = body.global_position
	has_last_known = true
	_since_stimulus = 0.0
	alert = maxf(alert, hearing_alert_cap)
	wariness = minf(wariness + body_wariness, wariness_max)
	found_body.emit(body)

	if state == Alert.SEARCHING:
		# Already searching: start again, around the body.
		_search_left = search_points
		_look_timer = 0.0
		_next_search_point()
	elif state != Alert.COMBAT:
		_set_state(Alert.SEARCHING)

	bark("He's dead! Murder!" if body.get("dead") == true else "A body! Someone's in here!")
	shout()


func shout() -> void:
	SoundBus.emit_sound(eye_position(), shout_db, self, &"shout")


# ---------------------------------------------------------------------------
# Being fought
# ---------------------------------------------------------------------------

func is_unaware() -> bool:
	return state <= Alert.SUSPICIOUS


## Outside his view cone: behind him, or well off to the side.
func is_behind(attacker: Node3D) -> bool:
	return _cone_factor(attacker.global_position - eye_position()) <= 0.0


## A weapon struck him. Returns "blocked", "parried", "hit", "killed" or
## "none". `point` is where it struck, `direction` the way the blow was
## travelling. `kind`: "quick", "power", "backstab", "drop", "arrow",
## "thrown", "blast", "fire" or "crush".
func take_hit(damage: float, attacker: Node3D, kind: StringName, point: Vector3, direction: Vector3) -> StringName:
	if _knocked_out:
		return &"none"

	# Whoever it was may be gone by now (the archer of an arrow still flying).
	if not is_instance_valid(attacker):
		attacker = null

	var blow := _blow_direction(attacker, direction)
	var at: Vector3 = point if point != Vector3.ZERO else _rig.chest()
	_last_blow = blow

	if kind == &"backstab" or (kind == &"drop" and damage >= health):
		_rig.react_hit(blow, 1.4)
		_bleed(at, blow, 1.6)
		_last_push = blow * 1.4 + (Vector3.DOWN * 2.0 if kind == &"drop" else Vector3.ZERO)
		_last_at = at
		_sever = sever_hint.duplicate()
		struck_by.emit(&"killed", kind, damage)
		die(attacker)
		return &"killed"

	# He may see it coming: a parry, or a raised guard. Not from the floor.
	var answer: StringName = &"" if _downed else _fighter.defend(kind, attacker)

	if answer == &"parried":
		_engage(attacker)
		struck_by.emit(&"parried", kind, 0.0)
		return &"parried"

	if answer == &"blocked":
		_block_flash = 0.3
		_engage(attacker)
		# Steel on steel, between the two of you.
		var clash: Vector3 = at - blow * 0.25
		Fx.sparks(self, clash, -blow, 1.0)

		if kind == &"thrown":
			Sfx.play(self, &"thud_wood", clash, -2.0)

		_rig.react_block(blow)
		struck_by.emit(&"blocked", kind, 0.0)
		return &"blocked"

	# Open (thrown off his balance): whatever lands is a deathblow.
	var opened: bool = _fighter.is_open() and kind in [&"quick", &"power", &"drop", &"thrown"]

	if opened:
		damage = _fighter.deathblow_damage(damage)
		_fighter.end_open()
		deathblow.emit()

	health -= damage
	hurt.emit(damage)

	# Cut, he is shaken: a heavy blow the more, a riposte most.
	var riposte: bool = _fighter.riposted_by(attacker)

	if not opened:
		_fighter.add_posture(26.0 if riposte else (22.0 if kind in [&"power", &"drop", &"crush", &"blast"] else 10.0))

	# How hard it rocks him: a quick cut, a heavy blow, an arrow by its force.
	var strength := 0.6

	if opened:
		strength = 1.0

	if kind == &"power" or kind == &"drop" or kind == &"blast" or kind == &"crush" or damage >= 60.0:
		strength = 1.0

	if kind == &"arrow":
		strength = clampf(damage / 60.0, 0.4, 1.2)

	if kind == &"thrown":
		strength = clampf(damage / 25.0, 0.4, 0.9)

	if health <= 0.0:
		strength = maxf(strength, 1.3)

	# A brute in the middle of a swing does not stop for quick cuts, arrows or
	# thrown things: they mark him and he swings on.
	var shrugged: bool = _fighter.hyper_armor and _phase != &"" and _phase != &"recover" and kind in [&"quick", &"arrow", &"thrown"] and health > 0.0
	_rig.react_hit(blow, strength * (0.35 if shrugged else 1.0))

	if _downed:
		_rig.man.ragdoll.shove(blow * 1.6 * strength, at, 0.5)

	if kind != &"fire":
		_bleed(at, blow, strength)
		_open_wound(at, kind, strength, riposte or opened)

	_hit_sound(kind, at, strength)

	if kind == &"arrow":
		_rig.embed_arrow(at, direction)

	if not shrugged and not _downed:
		# A hit interrupts his own blow; a heavy one rocks him longer. Then
		# for a moment he looks to his guard before he swings again.
		_phase = &""
		_fighter.on_hit(true)
		var rocked: float = _fighter.stagger_for(kind, stagger_time, riposte)

		# A riposte takes the opening his parried blow made: it rocks him hard
		# but briefly, and he is back in the fight, not left reeling out the
		# rest of the parry.
		if riposte:
			_stagger = rocked
			_rig.end_reel()
		else:
			_stagger = maxf(_stagger, rocked)

		_attack_timer = maxf(_attack_timer, _stagger + float(_fighter.wary_after_hit))

	# A heavy blow shoves him back a step.
	if (kind == &"power" or kind == &"drop" or kind == &"crush") and not _downed:
		var shove: Vector3 = Vector3(blow.x, 0.0, blow.z).normalized() * 3.2 * float(_fighter.kick_resist)
		velocity.x += shove.x
		velocity.z += shove.z

	if health <= 0.0:
		# Thrown by it as he falls, away from whoever struck him and along the
		# cut: a quick cut barely, a heavy blow hard.
		var thrown := blow.normalized()

		if attacker != null and is_instance_valid(attacker):
			var away := global_position - attacker.global_position
			away.y = 0.0

			if away.length() > 0.01:
				thrown = (away.normalized() * 0.8 + thrown * 0.5).normalized()

		_last_push = thrown * lerpf(1.4, 3.4, clampf((strength - 0.6) / 0.8, 0.0, 1.0))

		# A blast or a falling weight throws a man bodily.
		if kind == &"blast" or kind == &"crush":
			_last_push = thrown * 5.5 + Vector3.UP * 3.0

		_sever = sever_hint.duplicate()

		# A blast tears men apart.
		if kind == &"blast" and _sever.is_empty():
			_sever = _torn_by_blast(damage)

		_last_at = at
		struck_by.emit(&"killed", kind, damage)
		die(attacker)
		return &"killed"

	_engage(attacker)
	struck_by.emit(&"hit", kind, damage)

	# Cut, he cries out (fire has its own screams, below).
	if kind != &"fire" and randf() < 0.8:
		voice(&"pain", 2.0 if strength >= 1.0 else 0.0)

	if _bark_timer <= 0.0 and randf() < 0.5:
		bark("Argh!")

	return &"hit"


## Set alight: he burns for `seconds`, running about with no fight in him,
## until it goes out or he dies. Again while burning: longer.
func ignite(seconds := 4.5) -> void:
	if _knocked_out:
		return

	if _burning <= 0.0:
		_flames = TorchScript.new()
		_flames.energy = 1.8
		_flames.light_range = 6.0
		_flames.flame_size = 0.9
		_flames.shadows = false
		add_child(_flames)
		_flames.position = Vector3(0.0, 1.2, 0.0)
		Sfx.play(self, &"ignite", _rig.chest())
		SoundBus.emit_sound(eye_position(), shout_db, self, &"shout")
		bark("Fire! FIRE!")
		_flee_timer = 0.0

	_burning = maxf(_burning, seconds)
	_phase = &""
	_fighter.release_token()
	_fighter.guarding = false


func is_burning() -> bool:
	return _burning > 0.0


func _burn(delta: float) -> void:
	_burning -= delta
	_burn_tick -= delta

	if _burn_tick <= 0.0:
		_burn_tick = 0.5
		take_hit(9.0, null, &"fire", _rig.chest(), Vector3.UP)

	if _burning <= 0.0 and _flames != null:
		_flames.queue_free()
		_flames = null


## Running blind: a new way every moment, never off an edge on purpose.
func _run_burning(delta: float) -> void:
	_flee_timer -= delta

	if _flee_timer <= 0.0:
		_flee_timer = randf_range(0.5, 0.9)
		var angle := randf() * TAU
		_flee = Vector3(cos(angle), 0.0, sin(angle))

	var ahead := global_position + _flee * 0.7
	var closest := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, ahead)

	if Vector2(closest.x - ahead.x, closest.z - ahead.z).length() > 0.3:
		_flee = -_flee

	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(_flee * chase_speed * 0.8, acceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_face(_flee, delta)


## What his current blow is: its type, and what a block of it costs.
func attack_info() -> Dictionary:
	return _fighter.attack_info()


## The sound of a hit that nobody else voices: a sword's cut is the
## swordsman's to play (it knows the weapon), an arrow's the arrow's.
func _hit_sound(kind: StringName, at: Vector3, strength: float) -> void:
	match kind:
		&"thrown":
			Sfx.play(self, &"thud", at, -2.0, 1.1)
		&"blast", &"crush":
			Sfx.play(self, &"flesh", at, 0.0, 0.8)
			Sfx.play(self, &"flesh_heavy", at)
		&"fire":
			Sfx.play(self, &"burning", at, -2.0)
		_:
			pass


## Kicked. Caught off balance (in the middle of a blow, reeling, near
## done for) or by a running, leaping boot, he goes off his feet and flies
## (knock_down); standing ready, he only slides away with no say in it, off
## ledges and onto spikes. A big man stays up unless both.
func kick(push: Vector3, attacker: Node3D) -> void:
	if _knocked_out:
		return

	if _downed:
		# A man on the floor, booted along it.
		_rig.man.ragdoll.shove(push * 0.5 + Vector3.UP * 1.2, _rig.man.ragdoll.chest(), 0.5)
		return

	if _topples_from_kick(attacker) and _rig != null and _rig.man != null and _rig.man.ragdoll != null:
		var fly := Vector3(push.x, 0.0, push.z) * float(_fighter.topple_scale) + Vector3.UP * 2.2
		var chest: Vector3 = _rig.man.bone_global(&"spine_03").origin
		health -= 6.0
		_fighter.on_kicked()

		if health <= 0.0:
			_last_push = fly
			_last_at = chest
			die(attacker)
			return

		knock_down(fly, attacker, chest)
		return

	# A big man barely shifts, but it tells on his balance.
	_fighter.add_posture(28.0)

	if _fighter.is_open():
		health -= 6.0
		return

	_knock = knockdown_time
	_knock_velocity = Vector3(push.x, 0.0, push.z) * float(_fighter.kick_resist)
	_phase = &""
	_last_blow = _knock_velocity
	_fighter.on_kicked()
	_rig.react_kick(_knock_velocity, knockdown_time)
	health -= 6.0

	if health <= 0.0:
		die(attacker)
		return

	_engage(attacker)


## His blow met a raised guard at just the right moment.
## Off his balance (his posture broken): the next blow is a deathblow.
func is_open() -> bool:
	return _fighter != null and _fighter.is_open()


## What a blow of `damage` would do to him now.
func deathblow_damage(damage: float) -> float:
	return _fighter.deathblow_damage(damage) if is_open() else damage


func parried(_by: Node3D) -> void:
	# A point turned aside throws the man behind it off his feet more than a
	# cut does.
	var thrust: bool = _attack in [&"thrust", &"lunge", &"leap"]
	_phase = &""
	_stagger = parry_stun * (1.15 if thrust else 1.0)
	_attack_timer = attack_cooldown
	_fighter.on_parried()
	_rig.react_parried(_stagger)
	_fighter.add_posture(50.0 if thrust else 34.0)


## His blow met a raised guard.
func blocked_by(_by: Node3D) -> void:
	_fighter.recover_from_block()
	_rig.react_blocked()
	_fighter.add_posture(6.0)


## Spikes and the like. Thrown into them, or running into them, he dies.
func hazard_hit(_hazard: Node, lethal_speed: float) -> void:
	if _knocked_out:
		return

	var speed := Vector2(velocity.x, velocity.z).length()

	# Speed into it, not past it: a guard chasing you along a spiked wall
	# brushes it and lives; one kicked or charging into it does not.
	if _hazard != null and _hazard.has_method("into_speed"):
		speed = _hazard.into_speed(velocity)

	if _knock > 0.0 or speed > lethal_speed:
		# Run through. He bleeds back out of them and slumps off them.
		var into := Vector3(velocity.x, 0.0, velocity.z)
		into = into.normalized() if into.length() > 0.1 else global_basis.z
		var chest: Vector3 = _rig.chest()
		Fx.blood(self, chest + into * 0.25, -into, 2.2)
		Sfx.play(self, &"flesh", chest, 2.0, 0.8)
		Sfx.play(self, &"flesh_heavy", chest)
		_rig.add_wound(chest + into * 0.3, 0.3)
		_last_blow = -into
		die(null)


func die(_attacker: Node3D) -> void:
	if _knocked_out:
		return

	_knocked_out = true
	remove_from_group(&"guards")
	SoundBus.remove_listener(self)
	collision_layer = 0
	_fighter.on_died()
	_rig.drop_weapon()
	visible = false

	var body: RigidBody3D = GuardBodyScript.spawn(self, true, _last_blow)

	# Cut apart by the blow that killed him: off along it, before he falls.
	if not _sever.is_empty() and _rig.has_method("sever"):
		_rig.sever(_sever, _last_push)
		_horrify(_sever.has(&"neck_01"))

	# His last cry: none from a man whose head is gone.
	if not _sever.has(&"neck_01"):
		voice(&"death")

	_rig.transfer_to(body, _last_push, _last_at)

	# A dying scream. Others come to where he last knew trouble to be.
	SoundBus.emit_sound(eye_position(), shout_db, self, &"shout")
	died.emit(body)
	queue_free()


func _engage(attacker: Node3D) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return

	# An archer's stray arrow: it hurts, but his own side does not turn on him.
	if attacker.is_in_group(&"guards"):
		return

	last_known_position = attacker.global_position
	has_last_known = true
	_since_stimulus = 0.0
	_since_seen = 0.0
	alert = combat_at

	if state != Alert.COMBAT:
		_set_state(Alert.COMBAT)


func _take_fall(speed: float) -> void:
	var damage := (speed - fall_damage_speed) * fall_damage_per_speed
	health -= damage
	hurt.emit(damage)
	_rig.react_land(speed)
	Fx.dust(self, global_position + Vector3.UP * 0.05, Vector3.UP, 1.3)
	Sfx.play(self, _chain_land(), global_position, 0.0)
	Sfx.play(self, &"body_fall", global_position, -3.0)

	if health <= 0.0:
		Fx.blood(self, _rig.chest(), Vector3.UP, 0.9)

	if health <= 0.0:
		die(null)
	else:
		_stagger = maxf(_stagger, stagger_time * 2.0)


## Unaware, the blackjack works from anywhere. Once he is hunting, only from
## where he cannot see you. In a fight, never.
func can_be_knocked_out_by(attacker: Node3D) -> bool:
	if state == Alert.COMBAT:
		return false

	if state <= Alert.SUSPICIOUS:
		return true

	return _cone_factor(attacker.global_position - eye_position()) <= 0.0


## True when he goes down. A failed attempt tells him exactly where you are.
func knock_out(attacker: Node3D, force := false) -> bool:
	# `force`: dropped on from above, awareness does not save him.
	if not force and not can_be_knocked_out_by(attacker):
		last_known_position = attacker.global_position
		has_last_known = true
		_since_stimulus = 0.0
		alert = maxf(alert, 92.0)
		SoundBus.emit_sound(eye_position(), 54.0, attacker, &"clang", self)
		# The club rings off his helm.
		Sfx.play(self, &"clank", eye_position(), -2.0, 0.8)
		Fx.sparks(self, eye_position(), (attacker.global_position - eye_position()).normalized(), 0.5, false)
		bark("Club me, would you?")
		return false

	# Out of everything at once. queue_free waits for the end of the frame,
	# and until then he must not see, hear, bark or be counted.
	_knocked_out = true
	remove_from_group(&"guards")
	SoundBus.remove_listener(self)
	collision_layer = 0
	_fighter.on_died()
	_rig.drop_weapon()
	visible = false

	# He crumples away from the blow.
	var fall := global_position - attacker.global_position
	var body: RigidBody3D = GuardBodyScript.spawn(self, false, fall)
	# His knees go: he folds forward, away from the club.
	var slump := Vector3(fall.x, 0.0, fall.z).normalized() * 0.9 + Vector3.DOWN * 0.6
	_rig.transfer_to(body, slump, _rig.chest() if _rig.man == null else _rig.man.bone_global(&"spine_03").origin)
	Sfx.play(self, &"thud", eye_position(), -2.0, 1.2)

	# The thud is the attacker's noise: other guards can hear it.
	SoundBus.emit_sound(global_position, 44.0, attacker, &"body", self)
	knocked_out.emit(body)
	queue_free()
	return true


# ---------------------------------------------------------------------------
# Off his feet
# ---------------------------------------------------------------------------

## Whether a kick takes him off his feet: caught in the middle of something,
## reeling, nearly done for, or met by a boot with a run or a leap behind
## it. A big man needs both.
func _topples_from_kick(attacker: Node3D) -> bool:
	if _fighter.stays_put:
		return false

	var flying := false

	# A run or a leap into the kick, as it was when the kick began.
	var boot: Node = attacker.get("combat") if attacker != null else null

	if boot != null and boot.has_method("kick_had_momentum"):
		flying = boot.kick_had_momentum()
	elif attacker is CharacterBody3D:
		var body := attacker as CharacterBody3D
		flying = Vector2(body.velocity.x, body.velocity.z).length() > 4.0 or not body.is_on_floor()

	var off_balance := _phase != &"" or _stagger > 0.0 or _knock > 0.0 or health <= max_health * 0.3

	if float(_fighter.kick_resist) < 0.5:
		return flying and off_balance

	return flying or off_balance


## How much a man flung into him must carry (mass times speed, a guard's
## mass as 1) to take him off his feet too.
func topple_threshold() -> float:
	return 8.0 if float(_fighter.kick_resist) < 0.5 else 3.8


func is_downed() -> bool:
	return _downed


## Off his feet: physics has him (Ragdoll.gd), all of him moving at `push`
## plus how he was already moving, the part at `at` the most. He stands in
## for himself where his hips are until he gets up.
func knock_down(push: Vector3, attacker: Node3D = null, at := Vector3.INF) -> void:
	if _knocked_out:
		return

	if _rig == null or _rig.man == null or _rig.man.ragdoll == null:
		return

	if _downed:
		_rig.man.ragdoll.shove(push, at)
		return

	_downed = true
	_down_time = 0.0
	_down_still = 0.0
	_rising = 0.0
	_phase = &""
	_knock = 0.0
	_stagger = 99.0
	_burning = 0.0
	# Nothing to walk into, strike or see where he stood: he is on the floor.
	if collision_layer != 0:
		_down_layer = collision_layer

	collision_layer = 0
	_fighter.release_token()
	_last_blow = push
	_rig.go_limp(velocity, push, at)
	_down_peak = _rig.man.ragdoll.centre().y
	voice(&"pain", -2.0)

	if attacker != null:
		_engage(attacker)


func _update_downed(delta: float) -> void:
	var rag: Node = _rig.man.ragdoll if _rig != null and _rig.man != null else null

	if rag == null or not rag.is_limp():
		_downed = false
		collision_layer = _down_layer
		return

	_down_time += delta
	var hips: Vector3 = rag.centre()
	_down_peak = maxf(_down_peak, hips.y)
	# Standing in for himself where he lies: on the ground under his hips.
	global_position = _ground_under(hips)
	velocity = rag.velocity()
	_topple_others(rag)

	if rag.speed() < 0.4:
		_down_still += delta
	else:
		_down_still = 0.0

	var settled := _down_still > 0.45 and _down_time > 0.9

	if not settled and not (_down_time > 3.5 and rag.speed() < 1.2):
		return

	# A long way down hurts, and can kill.
	var drop := _down_peak - hips.y

	if drop > 2.2:
		var damage := (drop - 2.2) * 32.0
		health -= damage
		hurt.emit(damage)
		Sfx.play(self, &"body_fall", hips, 0.0, 0.85)

		if health <= 0.0:
			_last_push = Vector3.ZERO
			die(null)
			return

	_get_up(rag)


## Up off the floor from how he lies: flat on his back he sits up and stands
## facing his feet; on his front he pushes up toward his head.
func _get_up(rag: Node) -> void:
	var hips: Vector3 = rag.centre()
	var head: Vector3 = rag.head()
	var along := Vector3(head.x - hips.x, 0.0, head.z - hips.z)
	along = along.normalized() if along.length() > 0.05 else global_basis.z
	var up: bool = rag.face_up()
	var yaw: float
	var feet := _ground_under(hips)

	if up:
		# Getting up (LayToIdle) starts on his back with his head behind him,
		# his hips a little behind his feet.
		yaw = atan2(along.x, along.z)
		feet -= Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 0.24)
	else:
		yaw = atan2(-along.x, -along.z)

	global_position = _standing_room(feet)
	rotation.y = yaw
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	collision_layer = _down_layer
	_downed = false
	_rising = _rig.get_up(up)
	_stagger = _rising
	_attack_timer = maxf(_attack_timer, _rising + 0.25)


## A man flung fast and heavy enough into another takes him down too, and
## loses some of his flight to him.
func _topple_others(rag: Node) -> void:
	var v: Vector3 = rag.velocity()
	var speed := Vector2(v.x, v.z).length()

	if speed < 2.5:
		return

	var momentum: float = speed * float(rag.total_mass()) / 72.0

	for other in get_tree().get_nodes_in_group(&"guards"):
		if other == self or not is_instance_valid(other) or not other.has_method("knock_down") or other.is_downed():
			continue

		var centre: Vector3 = (other as Node3D).global_position + Vector3.UP * 1.0

		if centre.distance_to(rag.centre()) > 0.85 and centre.distance_to(rag.chest()) > 0.85:
			continue

		if momentum < float(other.topple_threshold()):
			continue

		other.knock_down(v * 0.6 + Vector3.UP * 1.0, null, centre)
		rag.shove(-v * 0.4)


func _ground_under(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3, point + Vector3.DOWN * 2.5, 1, [get_rid()])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else point + Vector3.DOWN * 0.2


## Somewhere near `point` a man can stand without being in a wall.
func _standing_room(point: Vector3) -> Vector3:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D

	if shape_node == null or shape_node.shape == null:
		return point

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.collision_mask = 1
	query.exclude = [get_rid()]

	for ring in [0.0, 0.3, 0.6]:
		for i in range(8 if ring > 0.0 else 1):
			var angle := TAU * float(i) / 8.0
			var at: Vector3 = point + Vector3(cos(angle), 0.0, sin(angle)) * ring
			query.transform = Transform3D(Basis.IDENTITY, at + shape_node.position + Vector3.UP * 0.02)

			if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				return at

	return point


## A part of him, flung, met a hazard (Hazard.gd): fast enough into it, and
## it is the end of him, and he stays on it.
func ragdoll_hazard(hazard: Node, lethal_speed: float, part: PhysicalBone3D) -> void:
	if _knocked_out or not _downed:
		return

	var speed: float = hazard.into_speed(part.linear_velocity) if hazard.has_method("into_speed") else part.linear_velocity.length()

	if speed <= lethal_speed:
		return

	var at := part.global_position
	Fx.blood(self, at, -part.linear_velocity.normalized(), 2.0)
	Sfx.play(self, &"flesh", at, 2.0, 0.8)
	Sfx.play(self, &"flesh_heavy", at)
	_rig.add_wound(at, 0.3)
	_pin(part)
	_last_push = Vector3.ZERO
	die(null)


## Held where it is, on the spikes.
static func _pin(part: PhysicalBone3D) -> void:
	part.linear_velocity = Vector3.ZERO
	var pin := PinJoint3D.new()
	pin.name = "Impaled"
	part.add_child(pin)
	pin.node_a = pin.get_path_to(part)


# ---------------------------------------------------------------------------
# The alert ladder
# ---------------------------------------------------------------------------

func _update_alert(delta: float) -> void:
	# Relaxed and suspicious guards calm down on their own. The busier states
	# end when their behaviour ends, not on a timer.
	if state <= Alert.SUSPICIOUS and _since_stimulus > alert_hold_time:
		alert = maxf(alert - alert_decay * delta, 0.0)

	match state:
		Alert.RELAXED:
			if alert >= investigate_at and has_last_known:
				_set_state(Alert.INVESTIGATING)
			elif alert >= suspicious_at:
				_set_state(Alert.SUSPICIOUS)
		Alert.SUSPICIOUS:
			if alert >= investigate_at and has_last_known:
				_set_state(Alert.INVESTIGATING)
			elif alert < suspicious_at * 0.6:
				_set_state(Alert.RELAXED)

	# From anywhere below: sure of it, and looking right at them.
	if state != Alert.COMBAT and alert >= combat_at and visibility >= combat_needs_visibility:
		_set_state(Alert.COMBAT)


func _set_state(new_state: int) -> void:
	if new_state == state:
		return

	var old := state
	state = new_state as Alert
	_wait_timer = 0.0
	_look_timer = 0.0

	if old == Alert.COMBAT and _fighter != null:
		_fighter.leave_combat()
	_bark_for(new_state, old)
	alert_changed.emit(new_state, old)

	match new_state:
		Alert.COMBAT:
			shout()
		Alert.INVESTIGATING:
			_go_to(last_known_position, true)
		Alert.SEARCHING:
			_search_left = search_points
			_next_search_point()
		Alert.RELAXED:
			_resume_patrol()


func _bark_for(new_state: int, old_state: int) -> void:
	match new_state:
		Alert.SUSPICIOUS:
			bark("Hm? What was that?")
		Alert.INVESTIGATING:
			if alert >= shout_alert and _since_seen > 1.0 and not can_see_target:
				bark("I'm coming!")
			else:
				bark("I'd better take a look.")
		Alert.SEARCHING:
			if old_state == Alert.COMBAT:
				bark("Where did you go? Show yourself!")
			else:
				bark("Someone's been here...")
		Alert.COMBAT:
			bark("You there! Stop!")
		Alert.RELAXED:
			if old_state == Alert.SEARCHING:
				bark("Must have been rats.")
			elif old_state == Alert.SUSPICIOUS:
				bark("Probably nothing.")


func bark(text: String) -> void:
	_bark_timer = 3.0
	barked.emit(text)

	if _bark_label != null:
		_bark_label.text = text


# ---------------------------------------------------------------------------
# Behaviours
# ---------------------------------------------------------------------------

func _do_patrol(delta: float) -> void:
	if _waypoints.is_empty():
		# No route: stand post, and walk back to it if something drew us away.
		# As close as the navmesh allows counts as back.
		if _flat_distance(_home.origin) > 0.8:
			_go_to(_home.origin)

			if not _walk(patrol_speed, delta):
				return

		_stop(delta)
		_face(-_home.basis.z, delta)
		return

	if _wait_timer > 0.0:
		_wait_timer -= delta
		_stop(delta)
		_face(-_waypoints[_waypoint_index].global_transform.basis.z, delta)

		if _wait_timer <= 0.0:
			_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
			_go_to(_waypoints[_waypoint_index].global_position, true)

		return

	if not _walk(patrol_speed, delta):
		return

	# "Finished" is not always "there": before the navmesh is ready a path is
	# empty and finishes at once. Ask again, rather than skip the waypoint.
	var waypoint := _waypoints[_waypoint_index].global_position
	_retry_timer -= delta

	if _flat_distance(waypoint) > waypoint_radius and not _path_blocked:
		var no_path := _agent.get_current_navigation_path().is_empty()

		if _retry_timer <= 0.0 and (no_path or _waypoint_retries < 3):
			_retry_timer = 0.5
			_waypoint_retries += 0 if no_path else 1
			_go_to(waypoint, true)
			return

		if no_path:
			return

	_waypoint_retries = 0
	_wait_timer = maxf(patrol_wait, 0.05)


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _resume_patrol() -> void:
	if _waypoints.is_empty():
		return

	# Carry on from whichever waypoint is nearest.
	var best := 0
	var best_distance := INF

	for i in range(_waypoints.size()):
		var d := global_position.distance_to(_waypoints[i].global_position)

		if d < best_distance:
			best_distance = d
			best = i

	_waypoint_index = best
	_go_to(_waypoints[best].global_position, true)


func _do_suspicious(delta: float) -> void:
	_stop(delta)

	if has_last_known:
		_face(last_known_position - global_position, delta)


func _do_investigate(delta: float) -> void:
	# A fresher clue moves the goal.
	if _since_stimulus < 0.1 and has_last_known:
		_go_to(last_known_position)

	if _look_timer > 0.0:
		if _look_around(delta):
			_set_state(Alert.SEARCHING)

		return

	if _walk(investigate_speed, delta):
		_start_looking()


func _do_search(delta: float) -> void:
	# Heard or glimpsed something new mid-search: go there instead.
	if _since_stimulus < 0.1 and has_last_known and _look_timer <= 0.0:
		_go_to(last_known_position)

	if _look_timer > 0.0:
		if _look_around(delta):
			_search_left -= 1

			if _search_left <= 0:
				_give_up()
			else:
				_next_search_point()

		return

	if _walk(investigate_speed, delta):
		_start_looking()


func _do_combat(delta: float) -> void:
	# Out of sight too long, and not mid-blow: go looking.
	if _phase == &"" and _since_seen > lose_time:
		# The scare is counted once, when the search that follows is given up.
		alert = investigate_at + 25.0
		_set_state(Alert.SEARCHING)
		_fighter.release_token()
		return

	# Footwork, blows and guard: GuardFighter.gd.
	_fighter.fight(delta)


## Coming down in his mail on what he stands on.
func _chain_land() -> StringName:
	return Sfx.step(floor_surface(), false, "land", true)


## What he stands on ("stone", "wood", ... as the floor's "surface" meta
## says; "" when it does not), looked up now and then as he goes.
func floor_surface() -> String:
	if _game_time < _floor_checked_at + 0.3:
		return _floor_surface

	_floor_checked_at = _game_time
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.4, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var floor_body: Object = hit.get("collider") if not hit.is_empty() else null
	_floor_surface = String(floor_body.get_meta(&"surface")) if floor_body != null and floor_body.has_meta(&"surface") else ""
	return _floor_surface


## His voice: a cry of `kind` ("pain", "death", "roar", "grunt"), pitched to
## him (GuardRig.voice_pitch: a woman's higher, a big man's lower), and not
## on top of the last one (a dying cry always).
func voice(kind: StringName, volume := 0.0) -> void:
	if kind != &"death" and _game_time - _voice_at < 0.45:
		return

	_voice_at = _game_time
	var pitch: float = _rig.voice_pitch() if _rig != null and _rig.has_method("voice_pitch") else 1.0
	Sfx.play(self, kind, eye_position(), volume, pitch, 0.03)


## Where a body's feet are. The player's origin is its capsule centre.
func _feet_of(node: Node3D) -> Vector3:
	if node.has_method("get_feet_position"):
		return node.get_feet_position()

	return node.global_position


func _give_up() -> void:
	alert = suspicious_at * 0.5
	has_last_known = false
	_scare()
	_set_state(Alert.RELAXED)


func _scare() -> void:
	wariness = minf(wariness + wariness_per_scare, wariness_max)


func _next_search_point() -> void:
	var map := get_world_3d().navigation_map
	var center := last_known_position if has_last_known else global_position
	var angle := randf() * TAU
	var reach := randf_range(search_radius * 0.4, search_radius)
	var guess := center + Vector3(cos(angle), 0.0, sin(angle)) * reach
	_go_to(NavigationServer3D.map_get_closest_point(map, guess), true)


func _start_looking() -> void:
	_look_timer = look_around_time
	_look_from_yaw = rotation.y


## Turns a full circle over look_around_time. True when finished.
func _look_around(delta: float) -> bool:
	_stop(delta)
	_look_timer -= delta

	var done := 1.0 - clampf(_look_timer / maxf(look_around_time, 0.01), 0.0, 1.0)
	rotation.y = _look_from_yaw + done * TAU
	return _look_timer <= 0.0


# ---------------------------------------------------------------------------
# Moving
# ---------------------------------------------------------------------------

func _go_to(point: Vector3, force := false) -> void:
	if _agent == null:
		return

	# Re-asking for nearly the same goal throws the path away and plans a new
	# one. Chasing someone who stands still would do that every frame.
	if not force and _agent.target_position.distance_to(point) < repath_distance:
		return

	_path_blocked = false
	_stuck_time = 0.0
	_last_walk_position = global_position
	_agent.target_position = point
	path_requests += 1


## Walks along the current path. True on arrival.
func _walk(speed: float, delta: float) -> bool:
	if _agent == null or _agent.is_navigation_finished() or _path_blocked:
		_stop(delta)
		return true

	if _door_wait > 0.0:
		_door_wait -= delta
		_stop(delta)
		_last_walk_position = global_position
		return false

	# Pushing on, going nowhere: something is in the way that the navmesh
	# does not know about. As far as he can get is as far as he goes.
	var moved := _flat_distance(_last_walk_position)
	_last_walk_position = global_position

	if moved < speed * delta * 0.2:
		_stuck_time += delta

		if _stuck_time > stuck_timeout:
			_stuck_time = 0.0
			_path_blocked = true
			_stop(delta)
			return true
	else:
		_stuck_time = 0.0

	var next := _agent.get_next_path_position()
	var direction := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)

	if direction.length() < 0.01:
		return false

	direction = direction.normalized()

	# Brake into the destination instead of noticing it on arrival: at chase
	# speed that would overrun it by more than a metre.
	var path := _agent.get_current_navigation_path()

	if not path.is_empty():
		# The agent calls it arrived at path_desired_distance short of the
		# end, so that is where he has to have stopped.
		var remaining := _flat_distance(path[path.size() - 1]) - _agent.path_desired_distance
		speed = minf(speed, maxf(sqrt(2.0 * acceleration * maxf(remaining, 0.0)), 0.6))

	var wanted := direction * speed
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wanted, acceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_face(direction, delta)
	return false


func _stop(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, acceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z


## Turns toward `direction`; `rate` scales how quickly (a committed blow
## barely tracks).
func _face(direction: Vector3, delta: float, rate := 1.0) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)

	if flat.length() < 0.01:
		return

	var wanted := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, wanted, 1.0 - exp(-turn_speed * rate * delta))


## The capsule floats above step height; the feet ride a ray. Stairs and
## kerbs pass underneath without ever being a wall.
func _apply_ground(delta: float) -> void:
	var from := global_position + Vector3.UP * 0.6
	var to := global_position - Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	query.collide_with_areas = false

	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		velocity.y = maxf(velocity.y - 24.0 * delta, -30.0)
		_fall_peak = maxf(_fall_peak, -velocity.y)
		return

	var ground: Vector3 = hit["position"]

	if _fall_peak > fall_damage_speed:
		_take_fall(_fall_peak)

	_fall_peak = 0.0
	velocity.y = 0.0
	global_position.y = move_toward(global_position.y, ground.y, 6.0 * delta)


func _open_doors_in_the_way() -> void:
	for i in range(get_slide_collision_count()):
		var collider := get_slide_collision(i).get_collider()

		if collider == null or not collider.has_method("frob"):
			continue

		if collider.get("is_open") != false:
			continue

		var locked: bool = collider.get("locked") == true
		var key_id: StringName = collider.get("key_id") if collider.get("key_id") != null else &""

		if locked and not inventory.has_key(key_id):
			# Try the handle once, then treat it as the wall it is.
			var now := _game_time

			if now - float(_tried_doors.get(collider, -1000.0)) > locked_door_memory:
				_tried_doors[collider] = now
				collider.frob(self)

			_path_blocked = true
			continue

		collider.frob(self)
		_door_wait = 0.9


# ---------------------------------------------------------------------------
# Presentation
# ---------------------------------------------------------------------------

func _update_head(delta: float) -> void:
	if _head == null:
		return

	match state:
		Alert.RELAXED:
			# An idle guard's gaze drifts.
			_head_yaw_goal = sin(_idle_time * 0.6) * deg_to_rad(35.0)
		Alert.SUSPICIOUS:
			if has_last_known:
				var to := last_known_position - global_position
				var wanted := atan2(-to.x, -to.z)
				_head_yaw_goal = clampf(wrapf(wanted - rotation.y, -PI, PI), -1.2, 1.2)
		_:
			_head_yaw_goal = 0.0

	_head.rotation.y = lerp_angle(_head.rotation.y, _head_yaw_goal, 1.0 - exp(-6.0 * delta))


## His sword and his body show what he is doing: GuardRig.gd.
## A bigger man stands taller and wider: his capsule and his eyes follow.
func _fit_body_to_look() -> void:
	var look: Dictionary = GuardFighterScript.look_of(archetype)
	var size: float = float(look.get("scale", 1.0))

	if is_equal_approx(size, 1.0):
		return

	var holder := get_node_or_null("CollisionShape3D") as CollisionShape3D

	if holder != null and holder.shape is CapsuleShape3D:
		var capsule := (holder.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		capsule.radius *= size
		capsule.height *= size
		holder.shape = capsule
		holder.position.y *= size

	var head := get_node_or_null("Head") as Node3D

	if head != null:
		head.position.y = eye_height


func _update_weapon(delta: float) -> void:
	if _rig != null:
		_rig.update(delta)


## Which way a blow was travelling: as given, else away from whoever struck.
func _blow_direction(attacker: Node3D, direction: Vector3) -> Vector3:
	if direction.length() > 0.01:
		return direction.normalized()

	if attacker != null and is_instance_valid(attacker):
		var away := global_position - attacker.global_position
		away.y = 0.0

		if away.length() > 0.01:
			return away.normalized()

	return global_basis.z


## A wound: blood from where he was cut, and a mark on him. (The sound is
## the weapon's: see _hit_sound.)
func _bleed(at: Vector3, blow: Vector3, strength: float) -> void:
	Fx.blood(self, at, blow, strength)
	_rig.add_wound(at, 0.16 + 0.08 * strength)

	# A killing blow: it goes on pumping out of him as he falls.
	if strength >= 1.3 and _rig.has_method("spurt"):
		_rig.spurt(at, blow, 1.6)


## A cut that bleeds: the harder, the more. Where it is, the drops fall from.
func _open_wound(at: Vector3, kind: StringName, strength: float, deep: bool) -> void:
	if kind == &"crush" or kind == &"blast" or health <= 0.0:
		return

	var more := lerpf(0.35, 1.7, clampf((strength - 0.5) / 0.6, 0.0, 1.0))

	if kind == &"arrow":
		more = 0.8

	if deep:
		more += 0.9

	if bleeding_on:
		bleeding = minf(bleeding + more, BLEED_MAX)

	_wound_local = to_local(at)


## Bleeding: health seeping away, drops falling behind him, the wound slowly
## closing. Once he has lost you, and has a moment, he binds it.
func _bleed_tick(delta: float) -> void:
	var floor_health := max_health * BLEED_FLOOR

	if health > floor_health:
		health = maxf(health - bleeding * delta, floor_health)

	bleeding = maxf(bleeding - delta * (0.1 + bleeding * 0.03), 0.0)
	_drip -= delta

	if _drip <= 0.0:
		_drip = lerpf(0.9, 0.16, clampf(bleeding / 3.0, 0.0, 1.0)) * randf_range(0.7, 1.3)
		var from := to_global(_wound_local)
		# Down his side to where it falls from.
		from.y = minf(from.y, global_position.y + 1.0)
		Fx.drip(self, from + global_basis.x * randf_range(-0.08, 0.08), 0.1 + 0.05 * clampf(bleeding, 0.0, 2.0))

	# Out of the fight a while: he stops and binds it.
	if state != Alert.COMBAT and _since_seen > BIND_AFTER and bleeding > 0.0:
		bleeding = 0.0
		Sfx.play(self, &"cloth", eye_position() - Vector3.UP * 0.6, 2.0, 0.8)

		if _bark_timer <= 0.0:
			bark(["Bloody... bind it, quick.", "Stop, stop the bleeding...", "Just a scratch. Just a scratch."][randi() % 3])

		bound_wounds.emit()


## What a blast tears off a man it kills: the closer (the more of it), the
## more of him.
func _torn_by_blast(damage: float) -> Array[StringName]:
	var limbs: Array[StringName] = [&"upperarm_l", &"upperarm_r", &"thigh_l", &"thigh_r", &"lowerarm_l", &"lowerarm_r", &"calf_l", &"calf_r"]
	limbs.shuffle()
	var count := 1 if damage < 60.0 else (2 if damage < 110.0 else 3)
	var torn: Array[StringName] = []

	for bone in limbs:
		if torn.size() >= count:
			break

		# One cut to a limb: not the forearm off an arm already gone.
		var side := String(bone).right(2)
		var arm := String(bone).contains("arm")
		var same_limb := torn.filter(func(b): return String(b).right(2) == side and String(b).contains("arm") == arm)

		if same_limb.is_empty():
			torn.append(bone)

	if damage >= 140.0 and randf() < 0.5:
		torn.append(&"neck_01")

	return torn


## Cut apart in front of his friends: whoever sees it is shaken, the squad's
## heart sinks, and they say so.
func _horrify(beheaded: bool) -> void:
	var here: Vector3 = _rig.chest()
	var shaken_squad := false

	for other in get_tree().get_nodes_in_group(&"guards"):
		if other == self or not other.has_method("witness_gore"):
			continue

		var d: float = (other as Node3D).global_position.distance_to(here)

		if d > GORE_SEEN_RANGE or not other._line_of_sight(other.eye_position(), here, self):
			continue

		other.witness_gore(beheaded, not shaken_squad)
		shaken_squad = true


## He saw a man cut apart.
func witness_gore(beheaded: bool, for_the_squad: bool) -> void:
	if _knocked_out:
		return

	if state == Alert.COMBAT:
		_fighter.add_posture(28.0 if beheaded else 18.0)

	var squad: RefCounted = _fighter.squad

	if for_the_squad and squad != null:
		squad.morale = maxf(float(squad.morale) - (0.15 if beheaded else 0.08), 0.0)

	if _bark_timer <= 0.0:
		bark(["Gods! His head!", "Oh gods...", "His HEAD!"][randi() % 3] if beheaded else ["Gods...", "Look at him!", "Butcher!"][randi() % 3])


## Feet dragged along the floor by a kick throw up dust.
func _skid_dust(delta: float) -> void:
	_skid -= delta

	if _skid > 0.0 or _knock_velocity.length() < 1.5:
		return

	_skid = 0.07
	Fx.dust(self, global_position + Vector3.UP * 0.05, (Vector3.UP - _knock_velocity.normalized() * 0.6).normalized(), 0.35)


func _update_bark(delta: float) -> void:
	# Up close the words would sit in the middle of a fight; the HUD's
	# subtitle carries them there. From afar they float over his head.
	if _bark_label != null:
		var camera := get_viewport().get_camera_3d()
		var near := 99.0 if camera == null else camera.global_position.distance_to(global_position)
		_bark_label.modulate.a = clampf((near - 5.0) / 3.0, 0.0, 1.0)
		_bark_label.outline_modulate.a = _bark_label.modulate.a

	if _bark_timer <= 0.0:
		return

	_bark_timer -= delta

	if _bark_timer <= 0.0 and _bark_label != null:
		_bark_label.text = ""


func _debug_draw() -> void:
	var colors := [Color.LIME_GREEN, Color.YELLOW, Color.ORANGE, Color.ORANGE_RED, Color.RED]
	var color: Color = colors[state]
	var eye := eye_position()
	var forward := look_direction()
	var reach := 4.0
	var half := deg_to_rad(fov_horizontal * 0.5)

	DebugDraw3D.draw_line(eye, eye + forward * reach, color)
	DebugDraw3D.draw_line(eye, eye + forward.rotated(Vector3.UP, half) * reach, color)
	DebugDraw3D.draw_line(eye, eye + forward.rotated(Vector3.UP, -half) * reach, color)

	var state_name: String = Alert.keys()[state]
	DebugDraw3D.draw_text(
		global_position + Vector3.UP * 2.5,
		"%s  alert %d  sees %.2f  wary %.2f" % [state_name, int(alert), visibility, wariness],
		32,
		color
	)

	if has_last_known:
		DebugDraw3D.draw_sphere(last_known_position + Vector3.UP * 0.2, 0.2, color)
