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
##               COMBAT fights you (GuardFighter.gd).
##   THE HUNT    Once he has taken you on he is one of a hunt (Squad.gd) until
##               he dies or gives the search up: losing sight of you, he
##               searches the ground the hunt gives him (where you could be
##               hiding: SearchSpots.gd); a friend who finds you again calls
##               him in (hear_call), and a runner can fetch him to it from his
##               post (join_hunt).
##   WHO HE IS   his temperament (`temperament`, Temperament.gd), and what the
##               whole garrison knows and dreads of you (Garrison.gd, ticked
##               by every guard).
##   HIS LIFE    between fights he talks with the man beside him, notices what
##               is out of place, misses a friend gone from his post, covers a
##               friend who goes to look at a noise, and lights a lantern in
##               the dark once the garrison is roused (GuardLife.gd). A lookout
##               sweeps his ground; stirred, he watches from his post and
##               sends a man down to look, rings the bell when they fight
##               below, and comes down when he is needed (_holds_post).
##   HIS HANDS   what he holds and picks up: his weapon, lost and recovered;
##               things to throw; the bell rope; the lantern (GuardHands.gd).
##   GETTING     round men and things the navmesh does not know of, doors
##   ABOUT       opened as he reaches them, a runner led, a lost man's trail
##               followed a few steps (GuardNav.gd); clear of lit powder. Up
##               onto what he can reach, down off it, across gaps, up and down
##               ladders, into water and out (GuardClimb.gd, NavLinks.gd).
##   WORD        what they call to each other, out loud (Comms.gd): where you
##               are, where you went, powder, a noise, all clear, the bell.
##   HIS OWN     at his ease, what he does with himself, in his own way
##   WAYS        (GuardHabits.gd): sits, dozes, leans on a wall or a rail,
##               eats, chops wood, tends the fire, carries crates, goes over
##               to a friend, paces, fidgets; walks his rounds with a light.
##
## The body origin is at the FEET. The capsule floats above step height and
## the body hovers on a ray, so stairs need no special handling.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const GuardBodyScript := preload("res://scripts/AISystem/GuardBody.gd")
const WeaponScript := preload("res://scripts/Combat/Weapon.gd")
const GuardRigScript := preload("res://scripts/AISystem/GuardRig.gd")
const GuardFighterScript := preload("res://scripts/AISystem/GuardFighter.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TorchScript := preload("res://scripts/Visual/Torch.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Comms := preload("res://scripts/AISystem/Comms.gd")
const Dangers := preload("res://scripts/AISystem/Dangers.gd")
const GuardNavScript := preload("res://scripts/AISystem/GuardNav.gd")
const GuardLifeScript := preload("res://scripts/AISystem/GuardLife.gd")
const GuardHandsScript := preload("res://scripts/AISystem/GuardHands.gd")
const GuardMercyScript := preload("res://scripts/AISystem/GuardMercy.gd")
const GuardClimbScript := preload("res://scripts/AISystem/GuardClimb.gd")
const GuardWaterScript := preload("res://scripts/AISystem/GuardWater.gd")
const GuardHabitsScript := preload("res://scripts/AISystem/GuardHabits.gd")
const SearchSpotsScript := preload("res://scripts/AISystem/SearchSpots.gd")
## Bleeding (bleeding): at most this much a second, never below this share of
## his health, and bound this long after he last saw you.
const BLEED_MAX := 4.0
const BLEED_FLOOR := 0.12
const BIND_AFTER := 3.0
## A man cut apart shakes whoever sees it from this far.
const GORE_SEEN_RANGE := 14.0
## A lit fuse is heard this near (m), whichever way he faces.
const FUSE_HEARD := 4.0
## Seen going up a ladder, over an edge or through the air, and lost: for this
## long (s) he knows where you come out (_follow_through).
const FOLLOW_THROUGH := 3.0
## In a fight his eyes go up and down after you (on a wall, up a ladder), up
## to this far (rad) from level.
const LOOK_PITCH := 1.1
## A man set to watch is on his post within POST_NEAR of it. There he keeps
## it, while there are friends of his within POST_FRIENDS to do the walking:
## what he sees or hears he watches from up there, and sends the nearest of
## them at their ease to look into it (POST_SEND of him); something at his
## post itself (POST_OWN) he looks into himself. His friends fighting below,
## he rings the bell first if there is one within POST_BELL to be rung; and
## seeing nothing of you from up there for POST_BLIND, he comes down to them,
## and stays down until the hunt is over.
const POST_NEAR := 6.0
const POST_FRIENDS := 30.0
const POST_SEND := 25.0
const POST_OWN := 4.0
const POST_BELL := 30.0
const POST_BLIND := 3.0
## The parts of one man (a head, an arm) lie this near each other: one find.
const BODY_SAME := 4.0
## He shouts about a find at most this often (s).
const BODY_SHOUT_GAP := 15.0
## Just lost you, and you were going somewhere: the search begins by running
## on after you the way you went (the trail), as far as you could have got
## since (up to TRAIL_MAX, m), while it is fresh (TRAIL_FRESH, s since he had
## you); each man a little to one side (TRAIL_SPREAD, m), not in single file.
## Word or a sound of you mid-search breaks off his look and sends him to it
## at a run (HOT_PACE of his chase speed) for HOT_TIME (s); and he does not
## give up while it keeps coming (at least HOT_POINTS more places to look).
const TRAIL_FRESH := 6.0
const TRAIL_MAX := 18.0
const TRAIL_SPREAD := 2.5
## A tracker (guile at least TRACKER_GUILE, or an archer's eye) reads the
## ground instead: the trail goes the way the floor goes on from where he lost
## you, round a corner or through a doorway, not only straight on until a
## wall. The turns of it he tries (rad, off the way you were going: the
## straightest first), and how roundabout a way may be (its length over the
## straight line) and still be the way you went.
const TRACKER_GUILE := 0.65
const TRACK_TURNS := [0.0, 0.45, -0.45, 0.9, -0.9, 1.35, -1.35]
const TRACK_ROUNDABOUT := 1.6
const HOT_TIME := 5.0
const HOT_PACE := 0.85
const HOT_POINTS := 2
## Searching a place where you could be hiding (SearchSpots): he looks into it
## as he comes up to it (from this near, m), and for this share of his look
## about him there; a door he holds for a man gone through it, all his look,
## HOLD_LOOK times as long. What he says going to it, now and then (this
## share of the time); a place he has searched is left alone SEARCHED_FOR (s),
## unless you are seen again.
const PEER_NEAR := 6.0
const PEER_SHARE := 0.45
const HOLD_LOOK := 2.0
const SPOT_LINE := 0.35
const SEARCHED_FOR := 60.0
## The lines for going to each kind of place.
const SPOT_LINES := {&"nook": &"peer", &"dark": &"peer", &"room": &"room", &"ledge": &"peer_up", &"hold": &"hold_door"}
## Called to a fight (a shout, a call of where you are, the bell): he goes at
## a run, not a walk.
const URGENT := [&"shout", &"call", &"alarm"]
## Wary (wary()): this long (s) after he was last hunting you, or while the
## garrison's alarm is at least this (a fight, a body, the bell).
const WARY_AFTER := 60.0
const WARY_ALARM := 0.45
## A fight near his post goes on counting this long (s) after the last sign
## of it (no turning back and forth for the bell).
const FIGHT_NEAR_HOLD := 2.0
## Lines as his state changes: the passing ones ("Hm?", "I'd better take a
## look") wait this long (s), and go unsaid if he is past them by then; a
## line is on show at least this long before another of his takes its place;
## the same kind of line not again from him for this long.
const STATE_LINE_WAIT := 0.35
const LINE_SHOWN := 1.0
const LINE_AGAIN := 8.0
## The fight over and his blade gone, he goes back for one this near (m).
const REARM_REACH := 15.0

## Off, cuts do not bleed (tests of exact damage).
static var bleeding_on := true
## Off, a man thrown off his feet never loses his grip on his weapon (tests
## of exact fights).
static var grip_loss_on := true
## Off, a man made does not randomize() the dice, so a test that seeds them
## first gets the same man, and the same fight, every run.
static var randomize_on := true

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
## Set to watch (a tower, a wall walk): he keeps his post, sweeping his ground,
## and sees further than most. Stirred, he looks from his post and sends a
## friend to look; seeing you, he calls out where you are (and runs to ring a
## bell, if there is one near) while his friends have you in hand, and comes
## down to them when they need him (POST_*, Squad._keeps_post).
@export var lookout := false
## Searching somewhere dark once the garrison is roused, he lights a lantern.
@export var carries_lantern := true
## Walks his rounds (and stands his post) with a light: "lantern" (held out,
## his blade at his belt), "torch" (held up), or "" (none).
@export var rounds_light: StringName = &""
## At his ease, what he does with himself (GuardHabits): only these, if any
## are given ("sit", "lean", "rail", "eat", "chop", "tend", "carry", "visit",
## "pace", "fidget"); his quirk, if the level gives him one (GuardHabits.QUIRKS);
## and how far from his post he goes for it (m).
@export var habits: Array[StringName] = []
@export var quirk: StringName = &""
@export var habit_range := 10.0
## What the garrison calls him ("" picks one for him, the same every load).
@export var given_name := ""


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
## Which man of his kind he looks like (Wardrobe.roll: face, skin, fading,
## dirt, height): -1 takes it from his place in the level, so he is the same
## man every load. Set before he enters the tree.
@export var look_seed := -1
## Who he is, under his class (Temperament.gd): "" rolls him afresh each
## time the level loads; "steady", "stubborn", "craven", "rash" or "sly"
## pins him.
@export var temperament: StringName = &""
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
## Whether he has seen you (or fought you) since he was last at his ease: it
## was no rat. And when he was last hunting you (game time).
var _saw_you := false
var _hunted_at := -1000.0
## Running on along your trail, the search's first leg (TRAIL_*); running to
## fresh word of you until then (HOT_TIME).
var _trailing := false
var _hot_until := -100.0
## The place he is searching (SearchSpots: stand, peer, kind), {} if none;
## the places he has searched himself ([point, game time]).
var _spot := {}
var _searched: Array = []
var _standing_still := true
## A line waiting its moment: [text, kind, when (game time), the state it is
## for, voices]; and when he last said each kind of line (_chorus).
var _pending_line: Array = []
var _said_kinds := {}

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
## Last seen off your feet (on a ladder, over an edge, in the air): followed
## through to where you come out (_follow_through).
var _seen_off_feet := false
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
## When he last shouted about a body (_discover).
var _body_shouted_at := -100.0
## The man he last sent from his post to look (_send_to_look).
var _sent: WeakRef = null
## Set to watch: come down from his post to help (fetched, needed, or no use
## up there), until the hunt is over; and how long, stirred, he has seen
## nothing of you from it.
var _left_post := false
var _post_blind_for := 0.0
## On his way to the bell (_ring_for_fight).
var _to_bell := false
## Getting about, his life off duty, his hands, and his life at your mercy
## (GuardNav, GuardLife, GuardHands, GuardMercy).
var _nav: RefCounted
var _life: RefCounted
var _hands: RefCounted
var _mercy: RefCounted
## Crossing what his path cannot walk: a climb, a drop, a leap, a ladder,
## into or out of water (GuardClimb, NavLinks); in water, wading or swimming
## (GuardWater).
var _climb: RefCounted
var _water: RefCounted
## What he does with himself at his ease (GuardHabits).
var _habits: RefCounted
## When he came into the level (Comms.now): a man only misses those who were
## there before him.
var _born_at := 0.0
## When he last saw a fight near his post (_fight_near).
var _fight_near_at := -100.0
## Going back for a blade (his own, thrown down or knocked from his hand, or
## another he can use) now the fight is over; where he was going before; and
## when he next looks for one.
var _rearm_blade: RigidBody3D = null
var _rearm_back := Vector3.INF
var _rearm_check := 0.0
## What last stirred him: "sight", "noise", "shout", "body", "call", "alarm",
## "oddity", "missing" or "fight".
var _stimulus: StringName = &""
## When he last had word of you from one of his own (their call's time), and
## how long ago that was: in a fight, word keeps him in it as sight does.
var _heard_of_at := -100.0
var _since_heard_of := 99.0
## Which way you were going when he last saw you.
var _seen_heading := Vector3.ZERO
## Where he looks, in turn, when he stops to look about him, and for how long
## this look lasts; keeping watch for the hunt from a vantage.
var _scan: Array = []
var _look_length := 3.0
var _watching := false
## Lit powder: seen (or heard) this long, and running from it (from where,
## how far, how much longer).
var _powder_seen := 0.0
var _evade_from := Vector3.ZERO
var _evade_radius := 0.0
var _evade_left := 0.0


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

	if randomize_on:
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
	_fighter.temper = TemperamentScript.roll(archetype, temperament)
	_fit_body_to_look()
	health = max_health
	_rig = GuardRigScript.new()
	_rig.setup(self)
	_weapon = _rig.weapon
	_body_mesh = _rig.body_mesh
	_nav = GuardNavScript.new(self)
	_life = GuardLifeScript.new(self)
	_hands = GuardHandsScript.new(self, StringName(GuardFighterScript.look_of(archetype).get("weapon", &"sword")))
	_mercy = GuardMercyScript.new(self)
	_climb = GuardClimbScript.new(self)
	_water = GuardWaterScript.new(self)
	_habits = GuardHabitsScript.new(self)

	if _agent != null:
		_agent.link_reached.connect(_on_link_reached)
	_born_at = Comms.now()

	if given_name == "":
		given_name = _free_name(look_seed if look_seed >= 0 else hash(String(get_path())), bool(_rig.get("female")))

	# Set to watch: he sees further than a man on his rounds.
	if lookout:
		sight_min *= 1.3
		sight_max *= 1.4

	if not _waypoints.is_empty():
		_waypoint_index = 0
		_go_to(_waypoints[0].global_position, true)


## His blade gone from his hands (thrown down begging, knocked out of them)
## and the fight over: before anything else he goes back for it, or for
## another lying near that he can fight with (GuardHands.usable). True while
## he is about it. Hunting, he takes up the search where he left it after.
func _rearming(delta: float) -> bool:
	if _hands == null or _hands.armed or _climb.active() or _water.swimming or _mercy.pleading:
		_rearm_blade = null
		_rearm_back = Vector3.INF
		return false

	var blade_ok := _rearm_blade != null and is_instance_valid(_rearm_blade) and not _rearm_blade.is_queued_for_deletion() and not Dangers.claimed(_rearm_blade, self)
	_rearm_check -= delta

	if not blade_ok and _rearm_check <= 0.0:
		_rearm_check = 1.0
		var near := Dangers.weapons_near(get_tree(), global_position, REARM_REACH, _hands.usable(), self)
		_rearm_blade = near[0] if not near.is_empty() else null
		blade_ok = _rearm_blade != null

		if blade_ok and _agent != null and _rearm_back == Vector3.INF:
			_rearm_back = _agent.target_position

	if not blade_ok:
		_rearm_blade = null
		_rearm_back = Vector3.INF
		return false

	if _habits.busy():
		_habits.interrupt()

	if _hands.can_reach(_rearm_blade):
		_stop(delta)
		_hands.stoop_for(_rearm_blade, &"weapon")
		_rearm_blade = null

		# Back to where he was going, once it is in his hand.
		if state == Alert.SEARCHING and _rearm_back != Vector3.INF:
			_go_to(_rearm_back, true)

		_rearm_back = Vector3.INF
		return true

	Dangers.claim(_rearm_blade, self)
	_go_to(_rearm_blade.global_position)

	if _walk(patrol_speed if state == Alert.RELAXED else investigate_speed, delta):
		# As near as he can get, and still out of reach: not that one.
		Dangers.unclaim(_rearm_blade, self)
		_rearm_blade = null
		_rearm_check = 5.0
		return false

	return true


## His name (Temperament.name_for, the same every time the level loads), or
## the next one along if another man about already has it: no two men of one
## garrison answer to the same name.
func _free_name(seed: int, female: bool) -> String:
	var taken := {}

	for other in get_tree().get_nodes_in_group(&"guards"):
		if other != self and String(other.get("given_name")) != "":
			taken[String(other.get("given_name"))] = true

	var names: Array = TemperamentScript.NAMES_F if female else TemperamentScript.NAMES

	for i in names.size():
		var called: String = TemperamentScript.name_for(seed + i, female)

		if not taken.has(called):
			return called

	return TemperamentScript.name_for(seed, female)


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

	if state >= Alert.SEARCHING:
		_hunted_at = _game_time

	# Standing still (for how he holds his lantern up), with some give either
	# way so it does not flick between the two at a shuffle.
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	_standing_still = flat_speed < 0.3 or (_standing_still and flat_speed < 0.7)

	if can_see_target and state >= Alert.SUSPICIOUS:
		_saw_you = true

	# The garrison's memory of you keeps its own time, whoever of them is about.
	if _target != null and is_instance_valid(_target):
		GarrisonScript.of(_target).tick(delta)

	# In a hunt, whatever he is doing: it keeps thinking while any of them is
	# in it, fighting or not.
	if _fighter != null and _fighter.squad != null:
		_fighter.squad.think(delta)

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_stagger = maxf(_stagger - delta, 0.0)
	_block_flash = maxf(_block_flash - delta, 0.0)
	_since_heard_of += delta

	if bleeding > 0.0:
		_bleed_tick(delta)

	if _downed:
		_update_downed(delta)
		return

	_rising = maxf(_rising - delta, 0.0)

	_sense_vision(delta)
	_sense_bodies(delta)
	_update_alert(delta)
	_water.update(delta)
	_hands.update(delta)
	_life.update(delta)
	_habits.update(delta)
	_watch_for_powder(delta)

	if _burning > 0.0:
		_burn(delta)

		if _knocked_out:
			return

	# Climbing, dropping, leaping: the move has him, and puts him where he
	# goes (GuardClimb). A knock takes him off it first.
	if _knock > 0.0 or _burning > 0.0:
		_climb.interrupt()

	var carried: bool = _climb.active()

	if carried:
		_climb.update(delta)

		if state == Alert.COMBAT:
			_fighter.watch(delta)
	elif _knock > 0.0:
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
	elif _evade_left > 0.0:
		# Kept clear while it still fizzes; a moment more once it is gone.
		if Dangers.lit_powder_near(get_tree(), _evade_from, -2.0) != null:
			_evade_left = maxf(_evade_left, 0.3)

		_evade_left -= delta
		_run_from_powder(delta)
	elif _hands.busy():
		# Stooping, straightening, at the bell rope: nothing else until done.
		_stop(delta)

		if state == Alert.COMBAT:
			_fighter.watch(delta)
	elif state != Alert.COMBAT and state != Alert.INVESTIGATING and _rearming(delta):
		# His blade first (the fight has its own way of getting one).
		pass
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

	if not carried:
		# Afloat, the water holds him up; standing in it, it slows him.
		if _water.swimming:
			_water.float_him(delta)
		else:
			_apply_ground(delta)
			_water.wade(delta)

	if _knocked_out:
		return

	if not carried:
		move_and_slide()

	if _knock <= 0.0 and not carried:
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
		_follow_through()
		return

	_since_seen = 0.0
	_since_stimulus = 0.0
	_stimulus = &"sight"
	last_known_position = _target.global_position
	has_last_known = true
	_seen_off_feet = _target.has_method("is_off_feet") and _target.is_off_feet()
	alert = minf(alert + visibility * vision_gain * wariness * delta, combat_at)

	# Which way you were going: where he looks first once he loses you.
	var going: Variant = _target.get("velocity")

	if going is Vector3 and Vector2((going as Vector3).x, (going as Vector3).z).length() > 0.8:
		_seen_heading = Vector3((going as Vector3).x, 0.0, (going as Vector3).z)


## Last seen on a ladder, hanging, going over an edge or in the air: which way
## you were going is plain (up, over, down), so for a moment after he loses
## you he knows where you come out, until you are on your feet again. Not
## under water: that is hiding.
func _follow_through() -> void:
	if not _seen_off_feet:
		return

	if _target == null or not is_instance_valid(_target) or _since_seen > FOLLOW_THROUGH:
		_seen_off_feet = false
		return

	last_known_position = _target.global_position
	_seen_off_feet = _target.has_method("is_off_feet") and _target.is_off_feet()


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

	# Asleep in his seat he sees nothing, but for a touch.
	if _habits != null and _habits.dozing() and nearest > touch_distance:
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

	# One of his own saying something (Comms.gd), or the bell.
	if event.has("message"):
		_hear_message(event)
		return

	var source: Object = event["source"]
	# Asleep, he hears only what is loud or near (and wakes to it).
	var dozing: bool = _habits != null and _habits.dozing()
	var reach: float = event["range"] * hearing_acuity * (GuardHabitsScript.DOZE_HEARING if dozing else 1.0)

	# A path is never shorter than the straight line, so this settles most
	# sounds without asking the navmesh anything.
	var sound_at: Vector3 = event["position"]

	if global_position.distance_to(sound_at) > reach:
		return

	if source is Guard:
		# A colleague shouting: go to where HE thinks the trouble is.
		if event["kind"] == &"shout" and state != Alert.COMBAT:
			if dozing:
				_habits.wake()

			var from: Vector3 = event["position"]

			if _sound_distance(from) <= reach:
				var other := source as Guard
				# A fight shouted outweighs covering a friend's look.
				_life.stop_covering()
				last_known_position = other.last_known_position if other.has_last_known else from
				has_last_known = true
				alert = maxf(alert, shout_alert)
				_since_stimulus = 0.0
				_stimulus = &"shout"

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

	if dozing:
		_habits.wake()

	# Covering a friend's look, and this is somewhere else: his own business.
	if _life.covering() and position.distance_to(_life.covered_place()) > GarrisonScript.LOOK_REACH:
		_life.stop_covering()

	alert = maxf(alert, minf(alert + amount, hearing_alert_cap))
	_since_stimulus = 0.0
	_stimulus = &"noise"

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
# Word from his own (Comms.gd)
# ---------------------------------------------------------------------------

## Something called out (or the bell), heard if it carries this far round the
## walls to him.
func _hear_message(event: Dictionary) -> void:
	var message: Dictionary = event["message"]
	var from: Vector3 = event["position"]
	var reach: float = float(event["range"]) * hearing_acuity

	if global_position.distance_to(from) > reach or _sound_distance(from) > reach:
		return

	var where: Vector3 = message.get("where", from)

	match message.get("what", &""):
		&"spotted":
			_heard_spotted(message, where)
		&"danger":
			if global_position.distance_to(where) < float(message.get("radius", 4.0)) + 1.5:
				_start_evade(where, float(message.get("radius", 4.0)), false)
		&"noise":
			_heard_noise(message, where)
		&"clear":
			if _life.covering() and Comms.caller(message) == _life._covering.get_ref():
				_life.stop_covering()
				alert = minf(alert, suspicious_at * 0.5)
		&"alarm":
			_heard_alarm(where)
		&"look":
			_heard_look(message, where)


## One of them calls where you are. In a fight he cannot see you in, the
## fresher word is where he goes; at his post, he comes to look.
func _heard_spotted(message: Dictionary, where: Vector3) -> void:
	var fresh := float(message.get("time", 0.0))

	if fresh <= _heard_of_at:
		return

	if state == Alert.COMBAT:
		if can_see_target:
			return

		_heard_of_at = fresh
		_since_heard_of = 0.0
		last_known_position = where
		has_last_known = true
		_since_stimulus = 0.0
		return

	_heard_of_at = fresh
	_since_heard_of = 0.0
	last_known_position = where
	has_last_known = true
	_since_stimulus = 0.0
	_stimulus = &"call"
	_life.stop_covering()
	alert = maxf(alert, shout_alert + 10.0)

	# Already on his way: he says he is coming (else stirring to it says so).
	if state >= Alert.INVESTIGATING:
		_go_to(_look_from(where), true)
		_ack(0.5)


## A friend heard something and is going to look: this one covers him.
func _heard_noise(message: Dictionary, where: Vector3) -> void:
	var caller := Comms.caller(message)

	if state > Alert.SUSPICIOUS or caller == null or caller == self:
		return

	last_known_position = where
	has_last_known = true
	_since_stimulus = 0.0
	_stimulus = &"noise"
	alert = maxf(alert, suspicious_at + 5.0)
	_life.cover(caller)

	if state == Alert.RELAXED:
		_set_state(Alert.SUSPICIOUS)


## The bell: everyone comes, to where the man who rang it saw you.
func _heard_alarm(where: Vector3) -> void:
	if state == Alert.COMBAT:
		return

	last_known_position = where
	has_last_known = true
	_since_stimulus = 0.0
	_stimulus = &"alarm"
	_life.stop_covering()
	alert = maxf(alert, investigate_at + 25.0)

	if state >= Alert.INVESTIGATING:
		_go_to(_look_from(where), true)
		_ack(0.4)


## The man set to watch calls down to one of them to go and look at
## something he has seen from his post: that one goes; the others at their
## ease hear it and keep an eye that way.
func _heard_look(message: Dictionary, where: Vector3) -> void:
	if state > Alert.SUSPICIOUS:
		return

	var to: Variant = message.get("to")
	var sent: bool = to is WeakRef and (to as WeakRef).get_ref() == self
	last_known_position = where
	has_last_known = true
	_since_stimulus = 0.0

	if not sent:
		_stimulus = &"noise"
		alert = maxf(alert, suspicious_at + 5.0)

		if state == Alert.RELAXED:
			_set_state(Alert.SUSPICIOUS)

		return

	# Sent: his to look into (whoever else is near covers him), and he says
	# so when he finds nothing.
	_stimulus = &"sent"
	alert = maxf(alert, investigate_at + 5.0)
	_life.stop_covering()
	_life.sent_to_look(where)
	_set_state(Alert.INVESTIGATING)


## Something to look into at `where` (a thing out of place, a missing man, a
## friend gone quiet): he goes.
func notice(where: Vector3, why: StringName) -> void:
	last_known_position = where
	has_last_known = true
	_since_stimulus = 0.0
	_stimulus = why
	alert = maxf(alert, investigate_at + 5.0)

	if state == Alert.INVESTIGATING or state == Alert.SEARCHING:
		_look_timer = 0.0
		_go_to(_look_from(where), true)


## Says the line his temperament has for `situation`, now and then (`chance`),
## and not over something he is already saying.
func say(situation: StringName, chance := 1.0) -> void:
	if _bark_timer > 0.0 or randf() >= chance or _fighter == null or _fighter.temper == null:
		return

	var said: String = _fighter.temper.line(situation)

	if said != "":
		bark(said)


## What he is doing with his hands or himself, for the rig: crossing a link
## ("climb", "ladder", "hang", "gather", "fall", "leap", "land": GuardClimb),
## swimming ("swim", "tread": GuardWater),
## "pickup", "ring", "hold", his light on his rounds ("carry_lantern",
## "carry_torch": GuardHands), begging ("kneel", "plead_kneel", "plead_stand",
## "rise", "rise_knees": GuardMercy), his own ways (GuardHabits: "sit",
## "sit_talk", "doze", "sit_down", "stand_up", "stand_up_quick", "lean",
## "rail", "reach", "eat", "chop", "kneel_down", "tend", "kneel_up", "carry",
## "set_down", "fold_arms", "drink", "nod", "shake", "dance"), "talk",
## "listen" ("nod", "shake": GuardLife), "lantern", "call", or "".
func activity() -> StringName:
	var crossing: StringName = _climb.activity() if _climb != null else &""

	if crossing != &"":
		return crossing

	var afloat: StringName = _water.activity() if _water != null else &""

	if afloat != &"":
		return afloat

	var busy: StringName = _hands.activity() if _hands != null else &""

	if busy != &"":
		return busy

	var begging: StringName = _mercy.activity() if _mercy != null else &""

	if begging != &"":
		return begging

	# What he does with himself (GuardHabits), talking the while (GuardLife):
	# sat, he talks where he sits.
	var own: StringName = _habits.activity() if _habits != null else &""
	var doing: StringName = _life.activity() if _life != null else &""

	if own == &"sit" and doing != &"":
		return &"sit_talk"

	if own != &"":
		return own

	if doing != &"":
		return doing

	if _hands != null and _hands.lantern != null and state != Alert.COMBAT and _standing_still:
		return &"lantern"

	return &""


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


## Found lying there. The parts of one man (a head, an arm) are one find, and
## a man found in the middle of a fight is no news to him: nothing more to it
## than that he knows. Otherwise he looks about for whoever did it, and
## shouts it (not every time: once in a while is enough).
func _discover(body: Node3D) -> void:
	var news := not _knows_body_near(body.global_position)
	_known_bodies[body] = true
	_body_notice.erase(body)
	var first_to_find: bool = body.get("discovered") != true
	body.set("discovered", true)

	# Word spreads: one more of theirs found lying where you left him.
	if first_to_find and _target != null and is_instance_valid(_target):
		GarrisonScript.of(_target).on_body_found()

	if not news or state == Alert.COMBAT:
		return

	last_known_position = body.global_position
	has_last_known = true
	_since_stimulus = 0.0
	_stimulus = &"body"
	alert = maxf(alert, hearing_alert_cap)
	wariness = minf(wariness + body_wariness, wariness_max)
	found_body.emit(body)

	if state == Alert.SEARCHING:
		# Already searching: start again, around the body.
		_search_left = search_points
		_look_timer = 0.0
		_next_search_point()
	else:
		_set_state(Alert.SEARCHING)

	if _game_time - _body_shouted_at >= BODY_SHOUT_GAP:
		_body_shouted_at = _game_time
		# Two finding him at once: one cry for them both (both shout).
		_chorus(&"body", "He's dead! Murder!" if body.get("dead") == true else "A body! Someone's in here!", 1, 0.0, true)
		shout()


## Whether a body he already knows of lies within BODY_SAME of `point`.
func _knows_body_near(point: Vector3) -> bool:
	for known in _known_bodies:
		if is_instance_valid(known) and (known as Node3D).global_position.distance_to(point) < BODY_SAME:
			return true

	return false


## Those of his own in the fight who saw him fall know of his body: they do
## not "find" it later.
func _witnessed_by_friends(body: Node3D) -> void:
	if body == null:
		return

	for other in get_tree().get_nodes_in_group(&"guards"):
		if other == self or int(other.get("state")) != Alert.COMBAT:
			continue

		if (other as Node3D).global_position.distance_to(global_position) < 30.0:
			other._known_bodies[body] = true


func shout() -> void:
	SoundBus.emit_sound(eye_position(), shout_db, self, &"shout")


## One of the hunt has found you again, near enough to hear: he goes there.
func hear_call(where: Vector3) -> void:
	last_known_position = where
	has_last_known = true
	_since_stimulus = 0.0
	_stimulus = &"call"
	_life.stop_covering()
	alert = maxf(alert, shout_alert)


## Fetched to the hunt by one of his own (Squad.rouse): he knows where they
## last saw you, and goes.
func join_hunt(where: Vector3) -> void:
	last_known_position = where
	has_last_known = true
	_since_stimulus = 0.0
	_stimulus = &"call"
	_life.stop_covering()
	alert = maxf(alert, investigate_at + 25.0)

	# Fetched to it by one of his own: a man set to watch comes down too.
	_left_post = true

	if state < Alert.INVESTIGATING:
		_set_state(Alert.INVESTIGATING)
	else:
		_go_to(where, true)

	var said: String = _fighter.temper.line(&"rouse") if _fighter != null and _fighter.temper != null else ""

	if said != "":
		bark(said)


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
		_mercy.died()
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

	# Struck on a wall or a ladder: he loses his hold. Whatever he was about
	# of his own is over.
	_climb.interrupt()
	_habits.wake()
	_habits.interrupt()

	# Cut down on his knees, or cut and he gives up on your mercy.
	if health <= 0.0:
		_mercy.died()
	else:
		_mercy.struck(attacker)

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
	# thrown things: they mark him and he swings on. Nor does any man whose
	# blade is already let go (past his glint: GuardFighter.COMMITTED) for a
	# quick cut: it comes anyway, and you trade.
	var shrugged: bool = health > 0.0 and ((_fighter.hyper_armor and _phase != &"" and _phase != &"recover" and kind in [&"quick", &"arrow", &"thrown"]) or (_fighter.committed() and kind == &"quick"))
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
		_hands.interrupt()
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


## Lit powder near him that he knows of: he gets clear of it, and shouts it.
## A man at his ease does not notice a fuse; one on his guard does, a moment
## after he sees it fizz (as quick as he answers a blow, and a little more).
func _watch_for_powder(delta: float) -> void:
	if state < Alert.INVESTIGATING or _evade_left > 0.0:
		_powder_seen = 0.0
		return

	var barrel := Dangers.lit_powder_near(get_tree(), global_position)

	if barrel == null:
		_powder_seen = 0.0
		return

	var at := barrel.global_position + Vector3.UP * 0.3
	var eye := eye_position()
	# A fuse fizzing this near is heard, whichever way he faces (it is at his
	# feet while he watches you); further off it has to be seen.
	var heard := eye.distance_to(at) <= FUSE_HEARD

	if not heard and (_cone_factor(at - eye) <= 0.0 or not _line_of_sight(eye, at, barrel)):
		return

	_powder_seen += delta

	if _powder_seen < float(_fighter.reaction) + 0.3:
		return

	_powder_seen = 0.0
	_start_evade(barrel.global_position, Dangers.blast_reach(barrel), true)


## Away from `from` until he is `radius` and a little more clear of it,
## dropping whatever he was about; shouting it, if he saw it himself.
func _start_evade(from: Vector3, radius: float, shout: bool) -> void:
	if _evade_left > 0.0 or _knocked_out:
		return

	_evade_from = from
	_evade_radius = radius + 1.5
	_evade_left = 2.5
	_phase = &""

	# Up and away, whatever he was about: off his seat, the word unfinished.
	if _habits != null and _habits.busy():
		_habits.interrupt()

	if _life != null and _life.talking():
		_life.end_talk()

	if _fighter != null:
		_fighter.release_token()
		_fighter.guarding = false

	if shout:
		bark(Comms.danger_line())
		Comms.call_out(self, &"danger", from, {"radius": radius})


func _run_from_powder(delta: float) -> void:
	var away := global_position - _evade_from
	away.y = 0.0

	if away.length() >= _evade_radius:
		_stop(delta)

		# Clear of it: he waits out the fuse there, watching the fight, and
		# does not take a step back in until it has gone up.
		if Dangers.lit_powder_near(get_tree(), _evade_from, -2.0) == null:
			_evade_left = 0.0
		elif _target != null and is_instance_valid(_target):
			_face(_target.global_position - global_position, delta)

		return

	var direction := away.normalized() if away.length() > 0.05 else global_basis.z
	# Along the navmesh: where that way runs out, he turns along it.
	var ahead := global_position + direction * 0.8
	var closest := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, ahead)

	if Vector2(closest.x - ahead.x, closest.z - ahead.z).length() > 0.3:
		var side := Vector3.UP.cross(direction) * (1.0 if get_instance_id() % 2 == 0 else -1.0)
		direction = (direction * 0.3 + side).normalized()

	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * chase_speed * 1.1, acceleration * 1.5 * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_face(direction, delta)


func is_evading() -> bool:
	return _evade_left > 0.0


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

	_mercy.struck(attacker)
	_climb.interrupt()
	_habits.interrupt()

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
	_hands.interrupt()
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


## His blow turned aside: `strength` 1 for a parry, more for a perfect
## deflect or a counter (PlayerCombat), which throw him further off balance.
func parried(_by: Node3D, strength := 1.0) -> void:
	# A point turned aside throws the man behind it off his feet more than a
	# cut does.
	var thrust: bool = _attack in [&"thrust", &"lunge", &"leap"]
	_phase = &""
	_stagger = parry_stun * (1.15 if thrust else 1.0) * lerpf(1.0, 1.25, clampf(strength - 1.0, 0.0, 1.0))
	_attack_timer = attack_cooldown
	_fighter.on_parried()
	_rig.react_parried(_stagger)
	_fighter.add_posture((50.0 if thrust else 34.0) * strength)


## His blade met yours in the air (a clash: PlayerCombat): neither landed.
## It bounces as off a raised guard, and shakes him a little more.
func clashed(_by: Node3D) -> void:
	_fighter.recover_from_block()
	_rig.react_blocked()
	_fighter.add_posture(12.0)


## You stepped into his thrust and onto his blade (Mikiri: PlayerCombat): it
## is pinned under your foot, and he is thrown hard off his balance.
func mikiri(_by: Node3D) -> void:
	_phase = &""
	_stagger = parry_stun * 1.6
	_attack_timer = attack_cooldown + 0.4
	_fighter.on_parried()
	_rig.react_parried(_stagger)
	_fighter.add_posture(62.0)


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

	# Killed before anyone knew you were there: his post stands empty.
	_leave_post()
	_knocked_out = true
	remove_from_group(&"guards")
	SoundBus.remove_listener(self)
	collision_layer = 0
	_fighter.on_died()
	_let_go()
	visible = false

	var body: RigidBody3D = GuardBodyScript.spawn(self, true, _last_blow)
	_witnessed_by_friends(body)

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


## Gone (killed or put to sleep) while nobody knew you were about, from a
## post he stood: whoever knew him will miss him there (Garrison.fallen).
func _leave_post() -> void:
	if not _waypoints.is_empty() or state > Alert.SUSPICIOUS:
		return

	var target := _target if _target != null and is_instance_valid(_target) else get_tree().get_first_node_in_group(&"player") as Node3D

	if target != null:
		GarrisonScript.of(target).post_fell(_home.origin, given_name, Comms.now())


## Everything in his hands falls: his weapon (for anyone to pick up), what he
## held to throw, his lantern.
func _let_go() -> void:
	if _hands != null:
		_hands.drop_held()
		_hands.drop_lantern()

	var dropped: RigidBody3D = _rig.drop_weapon()

	if _hands != null:
		GuardHandsScript.mark_dropped(dropped, _hands.kind)


func _engage(attacker: Node3D) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return

	# An archer's stray arrow: it hurts, but his own side does not turn on him.
	if attacker.is_in_group(&"guards"):
		return

	# Taken on before he has had a moment to look about him (a guard sent
	# straight at you): whoever it is, is who he is after.
	if _target == null or not is_instance_valid(_target):
		_target = attacker

	last_known_position = attacker.global_position
	has_last_known = true
	_since_stimulus = 0.0
	_since_seen = 0.0
	_stimulus = &"fight"
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
	_leave_post()
	_knocked_out = true
	remove_from_group(&"guards")
	SoundBus.remove_listener(self)
	collision_layer = 0
	# Out of the hunt, but not killed: no dread for a man put to sleep.
	_fighter.on_died(false)
	_let_go()
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

	_climb.interrupt()
	_habits.interrupt()

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
	_hands.interrupt()
	_last_blow = push
	_rig.go_limp(velocity, push, at)
	_down_peak = _rig.man.ragdoll.centre().y
	voice(&"pain", -2.0)

	# Off his feet, his grip may go: his weapon clatters away.
	if grip_loss_on and _hands != null and randf() < float(_fighter.grip_loss):
		_hands.lose_weapon(push)

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
	# Set to watch and stirred, and nothing of you to be seen from up there.
	if lookout and state >= Alert.INVESTIGATING and not can_see_target:
		_post_blind_for += delta
	else:
		_post_blind_for = 0.0

	# Relaxed and suspicious guards calm down on their own. The busier states
	# end when their behaviour ends, not on a timer.
	if state <= Alert.SUSPICIOUS and _since_stimulus > alert_hold_time:
		alert = maxf(alert - alert_decay * delta, 0.0)

	match state:
		Alert.RELAXED:
			if alert >= investigate_at and has_last_known:
				_investigate_or_cover()
			elif alert >= suspicious_at:
				_set_state(Alert.SUSPICIOUS)
		Alert.SUSPICIOUS:
			if alert >= investigate_at and has_last_known and not _life.covering():
				_investigate_or_cover()
			elif alert < suspicious_at * 0.6:
				_set_state(Alert.RELAXED)

	# From anywhere below: sure of it, and looking right at them.
	if state != Alert.COMBAT and alert >= combat_at and visibility >= combat_needs_visibility:
		_set_state(Alert.COMBAT)


## A noise worth a look: another man may already be looking into it (then
## this one covers him from where he stands), or it is his to go and see.
func _investigate_or_cover() -> void:
	if _stimulus == &"noise" and _life.claim_or_cover(last_known_position):
		alert = minf(alert, investigate_at - 1.0)

		if state == Alert.RELAXED:
			_set_state(Alert.SUSPICIOUS)

		return

	# Set to watch, and on his post: something he saw or heard himself, he
	# sends a friend to look into and covers him from up there. (Word from
	# one of his own, or the bell, he watches from his post: _look_from.)
	if _stimulus != &"call" and _stimulus != &"alarm" and _stimulus != &"sent" and _holds_post() and _send_to_look(last_known_position):
		alert = minf(alert, investigate_at - 1.0)

		if state == Alert.RELAXED:
			_set_state(Alert.SUSPICIOUS)

		return

	_set_state(Alert.INVESTIGATING)


## A man set to watch, on his post, with friends of his near enough to do the
## walking for him (POST_NEAR, POST_FRIENDS): he keeps his post, and looks
## into things from it, unless the thing is at his post itself (POST_OWN).
func _holds_post() -> bool:
	if not lookout or _left_post or global_position.distance_to(_home.origin) > POST_NEAR:
		return false

	if has_last_known and last_known_position.distance_to(_home.origin) < POST_OWN:
		return false

	# Seeing nothing of you from up there while they fight you below: he is
	# no use to them up here.
	if _post_blind_for > POST_BLIND and _fight_near():
		return false

	for other in get_tree().get_nodes_in_group(&"guards"):
		if other == self or bool(other.get("lookout")) or other.get("_knocked_out") == true:
			continue

		if (other as Node3D).global_position.distance_to(global_position) <= POST_FRIENDS:
			return true

	return false


## Where he goes to look into `point`: from his post if he keeps it
## (_holds_post), else there.
func _look_from(point: Vector3) -> Vector3:
	return _home.origin if _holds_post() else point


## One of his own within POST_FRIENDS of him is fighting.
func _fight_near() -> bool:
	for other in get_tree().get_nodes_in_group(&"guards"):
		if other != self and int(other.get("state")) == Alert.COMBAT and (other as Node3D).global_position.distance_to(global_position) <= POST_FRIENDS:
			_fight_near_at = _game_time
			return true

	# A moment's lull in it (a man out of it and back in, a step past the
	# edge): still a fight near, so he does not turn back and forth.
	return _game_time - _fight_near_at < FIGHT_NEAR_HOLD


## Set to watch, and his friends fighting below: the bell first, if there is
## one near to be rung (it brings everyone), then back to what he was about.
## True while he is about it.
func _ring_for_fight(delta: float) -> bool:
	var bell: Node3D = Dangers.bell_near(get_tree(), global_position, POST_BELL) if lookout and _fight_near() else null

	if bell == null:
		# Rung (by him or another): to his post, or to them.
		if _to_bell:
			_to_bell = false
			_go_to(_look_from(last_known_position), true)

		return false

	var rope: Vector3 = bell.rope_point()

	if _flat_distance(rope) > 0.9:
		if not _to_bell:
			_to_bell = true
			_look_timer = 0.0

			if _fighter != null and _fighter.temper != null:
				_chorus(&"bell", _fighter.temper.line(&"bell"))

		# Whatever word comes to him on the way: the bell first.
		if _agent != null and _agent.target_position.distance_to(rope) > 0.3:
			_go_to(rope, true)

		_walk(chase_speed, delta)
		return true

	_stop(delta)
	_face(bell.global_position - global_position, delta)
	_hands.ring_bell(bell, last_known_position)
	return true


## Set to watch, stirred, and watching from his post seeing nothing of you
## while they fight you below: down to them (and he stays down until the
## hunt is over).
func _come_down_if_blind() -> void:
	if not lookout or _left_post or _post_blind_for <= POST_BLIND or not _fight_near():
		return

	_left_post = true
	_look_timer = 0.0
	_watching = false
	_go_to(last_known_position, true)
	say(&"descend")


## From his post: calls the nearest friend of his at his ease (within
## POST_SEND) by name to go and look at `where`, and covers him while he
## does. True if the man heard him and went.
func _send_to_look(where: Vector3) -> bool:
	# One man out at a time: while the last is still looking, he watches.
	var out: Node3D = _sent.get_ref() as Node3D if _sent != null else null

	if out != null and is_instance_valid(out) and out.get("_knocked_out") != true and int(out.get("state")) >= Alert.INVESTIGATING:
		return false

	var friend: Node3D = null
	var nearest := POST_SEND

	for other in get_tree().get_nodes_in_group(&"guards"):
		if other == self or bool(other.get("lookout")) or other.get("_knocked_out") == true or int(other.get("state")) > Alert.SUSPICIOUS:
			continue

		var d := (other as Node3D).global_position.distance_to(global_position)

		if d < nearest:
			nearest = d
			friend = other

	if friend == null:
		return false

	bark(Comms.send_line(where, self, String(friend.get("given_name"))))
	Comms.call_out(self, &"look", where, {"to": weakref(friend)})

	if int(friend.get("state")) < Alert.INVESTIGATING:
		return false

	_sent = weakref(friend)
	_life.cover(friend)
	return true


func _set_state(new_state: int) -> void:
	if new_state == state:
		return

	var old := state
	state = new_state as Alert
	_wait_timer = 0.0
	_look_timer = 0.0
	_spot = {}
	# A line he had yet to say for the state he was in goes unsaid.
	_pending_line = []

	if old == Alert.COMBAT and _fighter != null:
		_fighter.leave_combat()

	if _life != null:
		# Stirred: whatever he was saying or doing with himself is over.
		if new_state != Alert.RELAXED and _life.talking():
			_life.end_talk()

		# Done looking (it was nothing, or he gave it up): he says so, and
		# whoever covered him stands easy.
		if new_state == Alert.RELAXED and (old == Alert.INVESTIGATING or old == Alert.SEARCHING):
			_life.done_looking()

	# Into a fight: his lantern goes to the floor, still burning; what he was
	# stooping to look at can wait; whatever he meant to see to, or had
	# claimed to look into, is left (GuardLife.stirred_to_fight).
	if new_state == Alert.COMBAT and _hands != null:
		_hands.drop_lantern()
		_hands.stop_relighting()

		if _hands.stooping_for() == &"evidence":
			_hands.interrupt()

	if new_state == Alert.COMBAT and _life != null:
		_life.stirred_to_fight()

	# Back to his rounds (and his post): the hunt goes on without him, and he
	# is no longer its watcher.
	if new_state == Alert.RELAXED:
		_left_post = false
		_to_bell = false
		_watching = false

	if new_state == Alert.RELAXED and _fighter != null and _fighter.squad != null:
		_fighter.squad.stand_down(self)
		_fighter.squad = null

	if new_state == Alert.COMBAT:
		_saw_you = true

	_bark_for(new_state, old)
	alert_changed.emit(new_state, old)

	# At his ease again: what he saw is behind him (he stays wary a while).
	if new_state == Alert.RELAXED:
		_saw_you = false

	match new_state:
		Alert.COMBAT:
			shout()
		Alert.INVESTIGATING:
			_go_to(_look_from(last_known_position), true)
		Alert.SEARCHING:
			# A hunt searches longer than one man would.
			_search_left = search_points + (2 if _fighter != null and _fighter.squad != null else 0)
			_trailing = false
			var trail := _trail_point() if old == Alert.COMBAT else Vector3.INF

			# Just lost you on the move: on after you the way you went.
			if trail != Vector3.INF:
				_trailing = true
				_go_to(trail, true)
			else:
				_next_search_point()
		Alert.RELAXED:
			_resume_patrol()


## What he says as his state changes. What several would say at the same
## moment (coming, a noise heard, lost, given up) the first man near says for
## them all (_chorus).
func _bark_for(new_state: int, old_state: int) -> void:
	match new_state:
		Alert.SUSPICIOUS:
			# Covering a friend who went to look: he says so.
			if _life != null and _life.covering() and _fighter != null and _fighter.temper != null:
				bark(_fighter.temper.line(&"noise_cover"))
			else:
				# A moment first: sure of it the next instant, he says that
				# instead (STATE_LINE_WAIT).
				_chorus(&"heard", "Hm? What was that?", 1, STATE_LINE_WAIT)
		Alert.INVESTIGATING:
			if _stimulus == &"sent" and _fighter != null and _fighter.temper != null:
				bark(_fighter.temper.line(&"ack"))
			elif _holds_post() and _fighter != null and _fighter.temper != null:
				# Set to watch: he looks from where he is.
				_chorus(&"hold_post", _fighter.temper.line(&"watch"))
			elif alert >= shout_alert and _since_seen > 1.0 and not can_see_target:
				_chorus(&"coming", "I'm coming!")
			else:
				_chorus(&"look", "I'd better take a look.", 1, STATE_LINE_WAIT)
		Alert.SEARCHING:
			if old_state == Alert.COMBAT:
				# Which way you went, if he saw: the others hear it too.
				_chorus(&"lost", Comms.lost_line(last_known_position, _seen_heading, self) if _seen_heading.length() > 1.0 else "Where did you go? Show yourself!")
			elif _stimulus != &"body":
				# (A body found says so itself: _discover.)
				_chorus(&"sign", "Someone's been here...")
		Alert.COMBAT:
			# In his own way: of their dead, if the dread in him has turned to anger.
			bark(_fighter.engage_line() if _fighter != null else "You there! Stop!")
		Alert.RELAXED:
			if old_state == Alert.SEARCHING:
				_chorus(&"stand_down", _stand_down_line())
			elif old_state == Alert.SUSPICIOUS:
				_chorus(&"nothing", "Probably nothing.")


## "Coming!" to a call (now and then, `chance`): the first of them near says
## it for all.
func _ack(chance: float) -> void:
	if randf() < chance and _bark_timer <= 0.0 and _fighter != null and _fighter.temper != null and Comms.may_voice(&"coming", global_position):
		bark(_fighter.temper.line(&"ack"))


## A line many would say at once: said by the first man near, the rest keep
## quiet (Comms.may_voice); and by him not again for a while (LINE_AGAIN).
## After `wait` (s), if he is still in the state it was for; and never on top
## of a line he has only just said (it waits its turn after it).
func _chorus(kind: StringName, text: String, voices := 1, wait := 0.0, urgent := false) -> void:
	if text == "" or _game_time - float(_said_kinds.get(kind, -100.0)) < LINE_AGAIN:
		return

	if _bark_timer > 3.0 - LINE_SHOWN and not urgent:
		wait = maxf(wait, _bark_timer - (3.0 - LINE_SHOWN))

	if wait > 0.0:
		_pending_line = [text, kind, _game_time + wait, int(state), voices]
		return

	_voice(kind, text, voices)


func _voice(kind: StringName, text: String, voices: int) -> void:
	if Comms.may_voice(kind, global_position, voices):
		_said_kinds[kind] = _game_time
		bark(text)


## Wary: hunting you not long since (WARY_AFTER), or the garrison roused (a
## fight, a body, the bell: its alarm past WARY_ALARM). At his ease he takes
## none (GuardHabits), and keeps his blade out.
func wary() -> bool:
	return _game_time - _hunted_at < WARY_AFTER or _garrison_alarm() >= WARY_ALARM


## His blade wanted in his hand (GuardRig draws it, or puts it by): looking
## into something, hunting, fighting, or on edge (wary). At his ease it is in
## its scabbard.
func wants_blade() -> bool:
	return state >= Alert.INVESTIGATING or wary()


## How roused the garrison is (Garrison.alarm), 0 with nobody to be roused
## about.
func _garrison_alarm() -> float:
	var target := _target if _target != null and is_instance_valid(_target) else get_tree().get_first_node_in_group(&"player") as Node3D
	return float(GarrisonScript.of(target).alarm) if target != null else 0.0


## Giving up the hunt: rats, if it was only ever a noise; if he saw you, or
## the garrison is roused (a body, the bell, their dead), something that
## knows better, in his own way.
func _stand_down_line() -> String:
	if not _saw_you and _garrison_alarm() < WARY_ALARM:
		return "Must have been rats."

	var own: String = _fighter.temper.line(&"gave_up") if _fighter != null and _fighter.temper != null else ""
	return own if own != "" else "He's gone. Stay sharp."


func bark(text: String) -> void:
	_bark_timer = 3.0
	barked.emit(text)

	if _bark_label != null:
		_bark_label.text = text


# ---------------------------------------------------------------------------
# Behaviours
# ---------------------------------------------------------------------------

func _do_patrol(delta: float) -> void:
	# About something of his own (a seat, the woodpile, a friend): it has him.
	if _habits.busy():
		_habits.run(delta)
		return

	if _waypoints.is_empty():
		# No route: stand post, and walk back to it if something drew us away.
		# As close as the navmesh allows counts as back.
		if _flat_distance(_home.origin) > 0.8:
			_go_to(_home.origin)

			if not _walk(patrol_speed, delta):
				_habits.walking()
				_life.walking()
				return

		_stop(delta)
		_life.at_rest(delta)
		_habits.at_rest(delta)

		if _habits.busy():
			return

		if _life.talking():
			_face(_life.partner_direction(), delta)
		elif lookout:
			# Set to watch: he sweeps his ground, slowly.
			var yaw: float = _life.watch_yaw(_home.basis.get_euler().y, delta)
			_face(Vector3(-sin(yaw), 0.0, -cos(yaw)), delta, 0.5)
		else:
			_face(-_home.basis.z, delta)

		return

	if _wait_timer > 0.0:
		_life.at_rest(delta)
		_habits.at_rest(delta, true)

		if _habits.busy():
			return

		# A word with the man beside him: his rounds wait for it.
		if _life.talking():
			_wait_timer = maxf(_wait_timer, 0.1)
			_stop(delta)
			_face(_life.partner_direction(), delta)
			return

		_wait_timer -= delta
		_stop(delta)
		_face(-_waypoints[_waypoint_index].global_transform.basis.z, delta)

		if _wait_timer <= 0.0:
			_waypoint_index = (_waypoint_index + 1) % _waypoints.size()
			_go_to(_waypoints[_waypoint_index].global_position, true)

		return

	_life.walking()
	_habits.walking()

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
	if _ring_for_fight(delta):
		return

	_come_down_if_blind()

	# A fresher clue moves the goal (or, looking from his post, his eyes).
	if _since_stimulus < 0.1 and has_last_known:
		var from := _look_from(last_known_position)
		_go_to(from)

		if from != last_known_position and _look_timer > 0.0:
			_scan = _post_headings()

	if _look_timer > 0.0:
		if _look_around(delta):
			_set_state(Alert.SEARCHING)

		return

	# Called to a fight: at a run. A noise to look into: at a walk.
	var pace := maxf(investigate_speed, chase_speed * HOT_PACE) if _stimulus in URGENT else investigate_speed

	if _walk(pace, delta):
		# Come to something out of place: he deals with it, then looks about.
		_life.deal_with_oddity()
		_start_looking()


func _do_search(delta: float) -> void:
	if _ring_for_fight(delta):
		return

	_come_down_if_blind()

	# Heard or glimpsed something new mid-search: go there instead, at a run,
	# breaking off his look; and not giving up while word of you keeps
	# coming. (Not the hunt's watcher: his place is his vantage, whatever the
	# others go to.)
	if _since_stimulus < 0.1 and has_last_known and not _watching:
		var from := _look_from(last_known_position)
		_search_left = maxi(_search_left, HOT_POINTS)

		# From his post: his eyes go to it, not his feet.
		if from != last_known_position:
			if _look_timer > 0.0:
				_scan = _post_headings()
		else:
			_trailing = false
			_spot = {}
			_hot_until = _game_time + HOT_TIME
			_look_timer = 0.0
			_go_to(from)

	if _look_timer > 0.0:
		if _look_around(delta):
			_searched_here()
			_search_left -= 1

			if _search_left <= 0:
				_give_up()
			else:
				_next_search_point()

		return

	var pace := investigate_speed

	if _trailing or _game_time < _hot_until:
		pace = maxf(investigate_speed, chase_speed * HOT_PACE)

	if _walk(pace, delta):
		# The trail's end: here is where he now thinks you are, and he looks
		# about him.
		if _trailing:
			_trailing = false
			last_known_position = global_position

		_start_looking()


func _do_combat(delta: float) -> void:
	# Out of sight too long (and no word of you from his own), and not
	# mid-blow: go looking.
	if _phase == &"" and minf(_since_seen, _since_heard_of) > lose_time and not _fighter.keeps_running():
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
	# Wading: it is water he steps in.
	if _water != null and _water.water != null and _water.water.depth_of(global_position) > 0.1:
		return "water"

	if _game_time < _floor_checked_at + 0.3:
		return _floor_surface

	_floor_checked_at = _game_time
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.4, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var floor_body: Object = hit.get("collider") if not hit.is_empty() else null
	_floor_surface = String(floor_body.get_meta(&"surface")) if floor_body != null and floor_body.has_meta(&"surface") else ""
	return _floor_surface


## Whether `point` is on the metal he wears (a helmet, a shoulder plate):
## steel there rings as well as bites.
func armoured_at(point: Vector3) -> bool:
	var man: Node = _rig.get("man") if _rig != null else null
	return man != null and man.has_method("armour_near") and man.armour_near(point) != null


## His voice: a cry of `kind` ("pain", "death", "roar", "grunt"), pitched to
## him (GuardRig.voice_pitch: a woman's higher, a big man's lower), and not
## on top of the last one (a dying cry always).
func voice(kind: StringName, volume := 0.0) -> void:
	if kind != &"death" and _game_time - _voice_at < 0.45:
		return

	_voice_at = _game_time
	var pitch: float = _rig.voice_pitch() if _rig != null and _rig.has_method("voice_pitch") else 1.0
	# A woman speaks with her own voice ("pain_f"...).
	var spoken := StringName(String(kind) + "_f") if _rig != null and bool(_rig.get("female")) else kind
	Sfx.play(self, spoken, eye_position(), volume, pitch, 0.03)


## Where a body's feet are. The player's origin is its capsule centre.
func _feet_of(node: Node3D) -> Vector3:
	if node.has_method("get_feet_position"):
		return node.get_feet_position()

	return node.global_position


## Where to go to get at `node`: where his feet are; or, on a ladder, off an
## edge or over one, where that comes out (the top he is going up to, the
## foot going down), so a man after him goes up the ladder behind him instead
## of waiting under it.
func goal_of(node: Node3D) -> Vector3:
	if node.has_method("climb_goal"):
		var goal: Vector3 = node.climb_goal()

		if goal != Vector3.INF:
			var on := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, goal)

			if on.distance_to(goal) < 1.5:
				return on

	return _feet_of(node)


func _give_up() -> void:
	alert = suspicious_at * 0.5
	has_last_known = false
	_scare()
	_set_state(Alert.RELAXED)


func _scare() -> void:
	wariness = minf(wariness + wariness_per_scare, wariness_max)


func _next_search_point() -> void:
	_spot = {}
	# The hunt's watcher: to his vantage, for a long look from it.
	var watch: Variant = _fighter.squad.watch_point_for(self) if _fighter != null and _fighter.squad != null else null

	if watch is Vector3:
		_watching = true
		_go_to(watch, true)
		return

	_watching = false

	# A man set to watch searches from his post (unless he has come down
	# to help: then he searches as the others do).
	if lookout and not _left_post:
		_go_to(_home.origin, true)
		return

	# In a hunt, the squad shares the ground out: his own piece of it, and
	# the likeliest place in it to hide.
	var shared: Dictionary = _fighter.squad.search_spot_for(self) if _fighter != null and _fighter.squad != null else {}

	if not shared.is_empty():
		_search_at(shared)
		return

	# Alone: the likeliest place round where he thinks you are.
	var center := last_known_position if has_last_known else global_position
	var heading := _likely_heading()
	var own := SearchSpotsScript.pick(self, center, Vector3(heading.x, 0.0, heading.z), search_radius, [], 0.0, _searched_points())

	if not own.is_empty():
		_search_at(own)
		return

	var map := get_world_3d().navigation_map
	var angle := randf() * TAU
	var reach := randf_range(search_radius * 0.4, search_radius)
	var guess := center + Vector3(cos(angle), 0.0, sin(angle)) * reach
	_go_to(NavigationServer3D.map_get_closest_point(map, guess), true)


## To search `spot` (SearchSpots, or the hunt's share of the ground): there,
## looking into it as he comes; saying where, now and then (a door he holds,
## always: the man going through should know).
func _search_at(spot: Dictionary) -> void:
	_spot = spot
	_go_to(spot["stand"], true)
	var kind: StringName = spot.get("kind", &"")
	var line: StringName = SPOT_LINES.get(kind, &"")

	if line != &"" and _fighter != null and _fighter.temper != null and (kind == &"hold" or randf() < SPOT_LINE):
		_chorus(line, _fighter.temper.line(line))


## He has looked about him at the place he searched: it is searched (his own
## to leave alone, and the hunt's).
func _searched_here() -> void:
	if _spot.is_empty():
		return

	var point: Vector3 = _spot["stand"]
	_searched.append([point, _game_time])

	if _searched.size() > 12:
		_searched.pop_front()

	if _fighter != null and _fighter.squad != null:
		_fighter.squad.searched(point)

	_spot = {}


## The places he has searched himself, not long since.
func _searched_points() -> Array:
	var points := []

	for done in _searched:
		if _game_time - float(done[1]) < SEARCHED_FOR:
			points.append(done[0])

	return points


## What he is looking into as he searches (the place's "peer": SearchSpots):
## coming up to it, and the first part of his look about him there (a door
## he holds, all of it). INF if nothing: none, or it is where he stands.
func peer_point() -> Vector3:
	if _spot.is_empty() or state != Alert.SEARCHING or _trailing:
		return Vector3.INF

	var peer: Vector3 = _spot.get("peer", Vector3.INF)

	if peer == Vector3.INF or (_flat_distance(peer) < 1.2 and absf(peer.y - eye_position().y) < 1.0):
		return Vector3.INF

	if _look_timer > 0.0:
		var done := 1.0 - _look_timer / maxf(_look_length, 0.01)
		return peer if _spot.get("kind", &"") == &"hold" or done < PEER_SHARE else Vector3.INF

	return peer if _flat_distance(_spot["stand"]) < PEER_NEAR else Vector3.INF


## Where the trail of you, just lost, leads: on from where he last had you
## the way you were going, as far as you could have got since at your pace
## (TRAIL_MAX at most), as far as the ground goes that way (to a wall across
## it), and to one side of it by his own lot (so they do not all run in
## single file); a tracker's, the way the floor goes on (_tracked_trail).
## INF if there is no trail: you were standing, it has gone cold, or no
## ground goes that way (or it is near enough that he may as well look about
## him here).
func _trail_point() -> Vector3:
	var heading := _likely_heading()

	if not has_last_known or _since_seen > TRAIL_FRESH or Vector2(heading.x, heading.z).length() < 0.8:
		return Vector3.INF

	var way := Vector3(heading.x, 0.0, heading.z).normalized()
	var pace := clampf(Vector2(heading.x, heading.z).length(), 3.0, 7.0)
	var reach := clampf(pace * (_since_seen + 1.0), 6.0, TRAIL_MAX)

	if tracker():
		var tracked := _tracked_trail(way, reach)

		if tracked != Vector3.INF:
			return tracked

	var aside := Vector3.UP.cross(way) * randf_range(-TRAIL_SPREAD, TRAIL_SPREAD)
	var map := get_world_3d().navigation_map
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]

	if _target is CollisionObject3D:
		exclude.append((_target as CollisionObject3D).get_rid())

	var best := Vector3.INF
	var along := 2.0

	while along <= reach + 0.01:
		var guess := last_known_position + way * along + aside * (along / reach)
		var on := NavigationServer3D.map_get_closest_point(map, guess)

		if Vector2(on.x - guess.x, on.z - guess.z).length() > 1.2 or absf(on.y - guess.y) > 2.5:
			break

		# A wall across it (or a shut door): the trail ends there, not on the
		# floor beyond. Chest high: a crate in the way is only in the way.
		var chest := Vector3.UP * 1.3

		if best != Vector3.INF and not space.intersect_ray(PhysicsRayQueryParameters3D.create(best + chest, on + chest, 1, exclude)).is_empty():
			break

		best = on
		along += 2.0

	if best == Vector3.INF or _flat_distance(best) < 3.0:
		return Vector3.INF

	return best


## Whether he reads a trail as a tracker does (TRACKER_GUILE): the sly, and
## archers.
func tracker() -> bool:
	return _fighter != null and (bool(_fighter.ranged) or (_fighter.temper != null and float(_fighter.temper.guile) >= TRACKER_GUILE))


## A tracker's trail: where the floor leads on from where he lost you, the
## way you were going or the least turn off it that goes on (round a corner,
## through a doorway), as far along it as you could have got (`reach`). INF if
## no way goes on from there (or it is near enough to look about him here).
func _tracked_trail(way: Vector3, reach: float) -> Vector3:
	var map := get_world_3d().navigation_map
	var from := NavigationServer3D.map_get_closest_point(map, last_known_position)
	var best := Vector3.INF
	var best_score := -INF

	for turn: float in TRACK_TURNS:
		var guess := from + way.rotated(Vector3.UP, turn) * reach
		var goal := NavigationServer3D.map_get_closest_point(map, guess)
		var straight := _flat(from, goal)

		# The floor gives out soon that way, or it is another level.
		if straight < reach * 0.5 or absf(goal.y - from.y) > 2.5:
			continue

		var path := NavigationServer3D.map_get_path(map, from, goal, true)

		if path.size() < 2 or _flat(path[path.size() - 1], goal) > 0.5:
			continue

		var length := 0.0

		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])

		# A long way round is not the way anyone went.
		if length > straight * TRACK_ROUNDABOUT + 2.0:
			continue

		# Straight on if it goes as far; a turn off it if that goes further.
		var score := cos(turn) + 2.0 * minf(length, reach) / reach

		if score > best_score:
			best_score = score
			best = _along(path, minf(reach, length))

	if best == Vector3.INF or _flat_distance(best) < 3.0:
		return Vector3.INF

	return best


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The point `far` (m) along `path`.
static func _along(path: PackedVector3Array, far: float) -> Vector3:
	var left := far

	for i in range(1, path.size()):
		var leg := path[i - 1].distance_to(path[i])

		if leg >= left:
			return path[i - 1].lerp(path[i], left / maxf(leg, 0.0001))

		left -= leg

	return path[path.size() - 1]


func _start_looking() -> void:
	# Keeping watch for the hunt, or from his post: a long look. Holding a
	# door for a man gone through: longer.
	_look_length = look_around_time * (4.0 if _watching or lookout else HOLD_LOOK if _spot.get("kind", &"") == &"hold" else 1.0)
	_look_timer = _look_length
	_look_from_yaw = rotation.y
	var peer := peer_point()

	if _watching:
		_scan = _watch_headings()
	elif lookout and global_position.distance_to(_home.origin) <= POST_NEAR and has_last_known:
		_scan = _post_headings()
	elif peer != Vector3.INF:
		_scan = _peer_headings(peer)
	else:
		_scan = _scan_headings()


## Searching a place: into it first, across it either side, then about him
## (the way you were going first); a door he holds, only it.
func _peer_headings(peer: Vector3) -> Array:
	var to := peer - global_position
	var toward := atan2(-to.x, -to.z)

	if _spot.get("kind", &"") == &"hold":
		return [toward, toward + 0.3, toward, toward - 0.3, toward]

	var about := _scan_headings()
	return [toward, toward + 0.4, toward - 0.4, about[0], about[1], about[3]]


## Where he looks, in turn, when he stops to look about him: first the way
## you were going if he knows it (the hunt's last sighting, or his own), then
## to either side of it, then behind him. Every way, but the likeliest first.
func _scan_headings() -> Array:
	var first := rotation.y
	var heading := _likely_heading()

	if heading != Vector3.ZERO:
		first = atan2(-heading.x, -heading.z)

	return [first, first + deg_to_rad(110.0), first - deg_to_rad(110.0), first + PI]


## The hunt makes him its watcher (Squad.watch_point_for): to `point`, for a
## long look from it.
func keep_watch_at(point: Vector3) -> void:
	if state != Alert.SEARCHING:
		return

	_watching = true
	_look_timer = 0.0
	_go_to(point, true)


## Keeping watch: toward where you were last seen, and either side of it.
func _watch_headings() -> Array:
	var squad: RefCounted = _fighter.squad if _fighter != null else null
	var seen: Vector3 = squad.last_sighting["position"] if squad != null else last_known_position
	var to := seen - global_position
	var toward := atan2(-to.x, -to.z) if Vector2(to.x, to.z).length() > 0.5 else rotation.y
	return [toward, toward + 0.6, toward - 0.6, toward + 1.1, toward - 1.1, toward]


## From his post: toward what he is looking into, and either side of it.
func _post_headings() -> Array:
	var to := last_known_position - global_position
	var toward := atan2(-to.x, -to.z) if Vector2(to.x, to.z).length() > 0.5 else rotation.y
	return [toward, toward + 0.5, toward - 0.5, toward + 1.0, toward - 1.0, toward]


## Which way you went, as far as he knows: the hunt's word if it is fresh and
## about here, else what he saw himself.
func _likely_heading() -> Vector3:
	var squad: RefCounted = _fighter.squad if _fighter != null else null

	if squad != null:
		var sighting: Dictionary = squad.last_sighting
		var going: Vector3 = sighting["velocity"]
		var seen_at: Vector3 = sighting["position"]

		if float(squad.clock) - float(sighting["time"]) < 12.0 and _flat_distance(seen_at) < 14.0 and Vector2(going.x, going.z).length() > 0.8:
			return Vector3(going.x, 0.0, going.z)

	if _since_seen < 15.0 and _seen_heading != Vector3.ZERO:
		return _seen_heading

	return Vector3.ZERO


## Looks each way of his scan in turn over look_around_time. True when done.
func _look_around(delta: float) -> bool:
	_stop(delta)
	_look_timer -= delta

	var done := 1.0 - clampf(_look_timer / maxf(_look_length, 0.01), 0.0, 1.0)

	if _scan.is_empty():
		_scan = _scan_headings()

	var goal: float = _scan[mini(int(done * float(_scan.size())), _scan.size() - 1)]
	rotation.y = lerp_angle(rotation.y, goal, 1.0 - exp(-7.0 * delta))
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

	if _climb != null:
		_climb.forget_wait()

	if _nav != null:
		_nav.new_path()


## His path has come to a way across it cannot walk (NavLinks): he makes the
## move (GuardClimb), unless he cannot just now (on the floor, flying).
func _on_link_reached(details: Dictionary) -> void:
	if _climb.active() or _knock > 0.0 or _downed or _stagger > 0.0 or _knocked_out:
		return

	_climb.begin(details)


## Walks along the current path. True on arrival.
func _walk(speed: float, delta: float) -> bool:
	# In water, as fast as it lets him (swimming, wading).
	speed *= _water.speed_scale()

	if _agent == null or _agent.is_navigation_finished() or _path_blocked:
		_stop(delta)
		return true

	if _door_wait > 0.0:
		_door_wait -= delta
		_stop(delta)
		_last_walk_position = global_position
		return false

	# Stepping round something in the way.
	if _nav.detouring():
		_last_walk_position = global_position
		_nav.walk_detour(speed, delta)
		return false

	var next := _agent.get_next_path_position()

	# At a ladder with someone on it: up it once it is clear.
	_climb.retry()

	# His path came to a way across it cannot walk: the move has him now.
	if _climb.active():
		return false

	# Waiting at its foot meanwhile.
	if _climb.waiting():
		_stop(delta)
		_last_walk_position = global_position
		return false

	var direction := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)

	# Pushing on, going nowhere: something is in the way that the navmesh
	# does not know about. A way round it if there is one; if not, as far as
	# he can get is as far as he goes.
	var moved := _flat_distance(_last_walk_position)
	_last_walk_position = global_position

	if moved < speed * delta * 0.2:
		_stuck_time += delta

		if _stuck_time > GuardNavScript.DETOUR_AFTER and _nav.try_detour(direction):
			_stuck_time = 0.0
			return false

		if _stuck_time > stuck_timeout:
			_stuck_time = 0.0
			_path_blocked = true
			_stop(delta)
			return true
	else:
		_stuck_time = 0.0

	# A closed door just ahead: opened as he comes to it, not walked into.
	var door: Node3D = _nav.door_ahead(next, delta)

	if door != null:
		_use_door(door)

		if _path_blocked:
			_stop(delta)
			return true

		if _door_wait > 0.0:
			_stop(delta)
			return false

	if direction.length() < 0.01:
		return false

	direction = direction.normalized()

	# Brake into the destination instead of noticing it on arrival: at chase
	# speed that would overrun it by more than a metre.
	var path := _agent.get_current_navigation_path()
	var remaining := INF

	if not path.is_empty():
		# The agent calls it arrived at path_desired_distance short of the
		# end, so that is where he has to have stopped.
		remaining = _flat_distance(path[path.size() - 1]) - _agent.path_desired_distance
		speed = minf(speed, maxf(sqrt(2.0 * acceleration * maxf(remaining, 0.0)), 0.6))

	var wanted := direction * speed

	# Easing round anyone too close, until he is nearly there.
	if remaining > 1.0:
		wanted += _nav.crowd(direction)

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
	# What he may pass through (a chair he steps in among to sit) is not
	# ground to him: stepping over its seat he would be lifted onto it.
	var exclude: Array[RID] = [get_rid()]

	for body in get_collision_exceptions():
		if is_instance_valid(body):
			exclude.append(body.get_rid())

	var query := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
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

		_use_door(collider)


## A closed door in his way: opened (and he waits a moment while it swings),
## or, locked and no key for it, tried once and then taken for the wall it is.
func _use_door(door: Object) -> void:
	var locked: bool = door.get("locked") == true
	var key_id: StringName = door.get("key_id") if door.get("key_id") != null else &""

	if locked and not inventory.has_key(key_id):
		# Try the handle once, then treat it as the wall it is.
		var now := _game_time

		if now - float(_tried_doors.get(door, -1000.0)) > locked_door_memory:
			_tried_doors[door] = now
			door.frob(self)

		_path_blocked = true
		return

	door.frob(self)
	_door_wait = 0.9


# ---------------------------------------------------------------------------
# Presentation
# ---------------------------------------------------------------------------

func _update_head(delta: float) -> void:
	if _head == null:
		return

	# Searching a place, what he looks into (INF: nothing in particular).
	var peer := peer_point()

	match state:
		Alert.RELAXED:
			# An idle guard's gaze drifts; a lookout's sweeps wider. About
			# something of his own, his head goes where that takes it.
			_head_yaw_goal = sin(_idle_time * (0.45 if lookout else 0.6)) * deg_to_rad(50.0 if lookout else 35.0)

			if _habits != null and (_habits.busy() or _habits.dozing()):
				_head_yaw_goal = _habits.head().x

			# Round at someone (GuardLife): the man he talks with, one going
			# by, one greeting him; as far as his head turns.
			var regard: Vector3 = _life.regard_direction() if _life != null else Vector3.ZERO

			if regard != Vector3.ZERO and (_habits == null or _habits.head_free()):
				var toward := atan2(-regard.x, -regard.z)
				_head_yaw_goal = clampf(wrapf(toward - rotation.y, -PI, PI), -GuardLifeScript.REGARD_MAX, GuardLifeScript.REGARD_MAX)
		Alert.SUSPICIOUS:
			if has_last_known:
				var to := last_known_position - global_position
				var wanted := atan2(-to.x, -to.z)
				_head_yaw_goal = clampf(wrapf(wanted - rotation.y, -PI, PI), -1.2, 1.2)
		_:
			# Stopped to look about him: his eyes go either side of the way
			# he faces. Searching a place: to it, as he comes and first thing
			# there.
			_head_yaw_goal = sin(_look_timer * 4.5) * 0.55 if _look_timer > 0.0 and state != Alert.COMBAT else 0.0

			if peer != Vector3.INF:
				var to := peer - global_position
				_head_yaw_goal = clampf(wrapf(atan2(-to.x, -to.z) - rotation.y, -PI, PI), -1.2, 1.2) + sin(_game_time * 1.7) * 0.12

	_head.rotation.y = lerp_angle(_head.rotation.y, _head_yaw_goal, 1.0 - exp(-6.0 * delta))

	# In a fight he looks up (or down) at you, where he sees you or last had
	# you: up a ladder, on a wall over him. Otherwise his eyes are level.
	var pitch_goal := 0.0

	if state == Alert.COMBAT and has_last_known:
		var aim: Vector3 = _target.global_position if can_see_target and _target != null and is_instance_valid(_target) else last_known_position
		var to := aim - eye_position()
		pitch_goal = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -LOOK_PITCH, LOOK_PITCH)
	elif state == Alert.RELAXED and _habits != null:
		# Up at the sky, out over a rail, down asleep.
		pitch_goal = _habits.head().y
	elif peer != Vector3.INF:
		# Up at a ledge, down into a corner.
		var into := peer - eye_position()
		pitch_goal = clampf(atan2(into.y, Vector2(into.x, into.z).length()), -LOOK_PITCH, LOOK_PITCH)

	_head.rotation.x = lerp_angle(_head.rotation.x, pitch_goal, 1.0 - exp(-6.0 * delta))


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
		# The less nerve he has, the harder it hits him.
		var nerve: float = float(_fighter.temper.nerve) if _fighter.temper != null else 0.5
		_fighter.add_posture((28.0 if beheaded else 18.0) * (1.4 - nerve))

	var squad: RefCounted = _fighter.squad

	if for_the_squad and squad != null:
		squad.morale = maxf(float(squad.morale) - (0.15 if beheaded else 0.08), 0.0)

	# And the whole garrison hears of it.
	if for_the_squad and _target != null and is_instance_valid(_target):
		GarrisonScript.of(_target).on_gore()

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
	# A line waiting its moment (_chorus): said now, if he is still as he was.
	if not _pending_line.is_empty() and _game_time >= float(_pending_line[2]):
		var line: Array = _pending_line
		_pending_line = []

		if int(line[3]) == int(state):
			_voice(line[1], line[0], int(line[4]))

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
