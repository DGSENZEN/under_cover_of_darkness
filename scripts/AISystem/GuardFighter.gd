extends RefCounted
## How a guard fights. Guard.gd decides that he is fighting and whom; this
## decides how: where he stands, which blow he throws and when, and how he
## meets yours. GuardRig shows all of it.
##
## Guards fight by your rules. A blow is telegraphed: the blade goes up, and
## a glint says it is really coming. A raised guard catches quick cuts, but a
## power blow or a kick breaks it, and so do enough quick ones. A parry at the
## last instant throws the blow aside and leaves the attacker open. A feint
## (a blow abandoned on the way up) baits a parry out too early.
##
## Archetypes play those rules differently:
##   swordsman  guards, trades blows, strings two together, kicks a turtle.
##   duelist    quick; feints, parries and ripostes, sidesteps a charge.
##   brute      slow and heavy: his blows break a guard, and quick cuts do
##              not stop him mid-swing. Parry him and he reels for a long time.
##   archer     keeps his distance and shoots; the draw is the warning. Get
##              close and he kicks you off and backs away again.
##   trainer    stands still and swings on a steady beat: parry practice.
## A guard with no archetype is the plain watchman of the stealth levels.
##
## A crowd takes turns: only `max_attackers` guards swing at one target at a
## time, and one behind you waits a moment longer, so a fight against three
## is hard but readable. The rest spread round you to your sides and back, so
## a man who stands still is surrounded; when one of them is parried or cut,
## another steps in while you are busy.
##
## And they learn you. Blows thrown hard on each other's heels, or the same
## cut again and again, are read: a trained man parries them and answers. A
## light-footed one steps out of a long swing and punishes the miss. Their
## own blows come on no steady beat, a swordsman or a duelist can lunge in
## from out of reach, and the brute's great blow cannot be caught at all:
## get out of its way.
##
## Who he is shapes it (`temper`, Temperament.gd): a man rasher than his kind
## rests less between blows, guards less and stands closer in; a slyer one
## feints more and circles to his place quicker; a stubborn one is planted.
## The man his class describes fights exactly as ARCHETYPES says. The dread
## the garrison holds of you turns to anger in a bold man (drive_now). And his
## place in the hunt (Squad.gd) decides the rest: hold (at the edge of your
## reach, guard up, calling for help), fetch (running for help), flee,
## desperate (all in), and a rash flanker whose patience runs out.

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const ArrowScript := preload("res://scripts/Combat/Arrow.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const Comms := preload("res://scripts/AISystem/Comms.gd")
const Dangers := preload("res://scripts/AISystem/Dangers.gd")

## Guard.Alert.COMBAT.
const COMBAT := 4

## Each blow, relative to the guard's own numbers: windup (x windup_time),
## extra reach (m), damage (x attack_damage), how wide it cuts (degrees),
## the stamina a block of it costs (x guard_damage), recovery (x recover_time).
const ATTACKS := {
	&"overhead": {"windup": 1.0, "reach": 0.0, "damage": 1.0, "arc": 55.0, "guard": 1.0, "recover": 1.0},
	&"left": {"windup": 0.85, "reach": 0.1, "damage": 0.9, "arc": 110.0, "guard": 0.9, "recover": 0.9},
	&"right": {"windup": 0.85, "reach": 0.1, "damage": 0.9, "arc": 110.0, "guard": 0.9, "recover": 0.9},
	&"thrust": {"windup": 0.8, "reach": 0.45, "damage": 0.85, "arc": 34.0, "guard": 0.8, "recover": 0.85},
	&"heavy": {"windup": 1.45, "reach": 0.25, "damage": 1.5, "arc": 75.0, "guard": 2.6, "recover": 1.35},
	&"kick": {"windup": 0.0, "reach": -0.3, "damage": 0.2, "arc": 60.0, "guard": 0.0, "recover": 0.8},
	# In from out of reach: the blade driven ahead of a dash.
	&"lunge": {"windup": 1.15, "reach": 2.4, "damage": 1.0, "arc": 40.0, "guard": 1.0, "recover": 1.25},
	# An arrow: its windup is the draw (draw_time), its reach the whole yard.
	&"shoot": {"windup": 0.0, "reach": 0.0, "damage": 1.0, "arc": 0.0, "guard": 1.0, "recover": 1.0},
	# Low, at your legs: no guard stops it. Jump it, or be out of its reach.
	&"sweep": {"windup": 1.05, "reach": 0.25, "damage": 0.8, "arc": 130.0, "guard": 1.0, "recover": 1.15},
	# The pommel, close in: quick, and through a raised guard (BASH_WINDUP).
	&"bash": {"windup": 0.0, "reach": -0.35, "damage": 0.25, "arc": 70.0, "guard": 0.0, "recover": 0.75},
	# The brute's shoulder from out of reach: nothing stops it but a step aside.
	&"charge": {"windup": 0.85, "reach": 4.2, "damage": 1.1, "arc": 45.0, "guard": 3.0, "recover": 1.5},
	# A bound in from out of reach, the blade raised as he comes and brought
	# down as he arrives.
	&"leap": {"windup": 1.0, "reach": 2.3, "damage": 1.1, "arc": 50.0, "guard": 1.2, "recover": 1.3},
	# Bare-handed (his weapon lost): the fist across, the jab. Quick, light,
	# and caught on any guard.
	&"punch": {"windup": 0.6, "reach": -0.5, "damage": 0.3, "arc": 70.0, "guard": 0.4, "recover": 0.8},
	&"jab": {"windup": 0.45, "reach": -0.55, "damage": 0.2, "arc": 60.0, "guard": 0.3, "recover": 0.6},
	# Something picked up and thrown (GuardHands): its windup is the draw back
	# overhead (THROW_WINDUP), its reach THROW_RANGE.
	&"throw": {"windup": 1.0, "reach": 0.0, "damage": 0.0, "arc": 0.0, "guard": 0.6, "recover": 0.9},
}
## What each of his blows asks of you, as it is telegraphed (GuardRig's glow,
## the HUD's marks): "cut" a guard or a parry; "thrust" a parry or a step
## aside (a raised guard lets some of it through); "low" a jump (no guard stops
## it); "unblockable" a dodge; "bash" to be out of it or strike first.
const CALLS := {
	&"overhead": &"cut", &"left": &"cut", &"right": &"cut", &"leap": &"cut",
	&"thrust": &"thrust", &"lunge": &"thrust",
	&"sweep": &"low",
	&"heavy": &"unblockable", &"charge": &"unblockable",
	&"kick": &"bash", &"bash": &"bash",
}
## A pommel strike's own windup: short, and hard to see coming.
const BASH_WINDUP := 0.3
## Past this much of his windup (the glint: GuardRig) his blow is committed:
## a quick cut marks him but does not stop it (Guard.take_hit). Before it,
## you can beat him to it; after it, answer it (a parry, a counter, a dodge)
## or trade blows.
const COMMITTED := 0.64
## A blow that lands while he is open deals this many times its damage, and
## at least his whole health over `deathblows`.
const DEATHBLOW := 2.5
## A riposte rocks him this many times as long as a quick cut.
const RIPOSTE_ROCK := 1.3
## Shaken (his balance past SHAKEN_AT, until it is back under SHAKEN_UNTIL):
## he backs off for at most SHAKEN_MAX seconds, then comes again regardless,
## and is not shaken again for SHAKEN_REST.
const SHAKEN_AT := 0.75
const SHAKEN_UNTIL := 0.55
const SHAKEN_MAX := 1.3
const SHAKEN_REST := 2.5
## Thrown off balance (his posture broken): how long he is OPEN.
const OPEN_TIME := 1.7
## A kick's windup is its own: he rears back for this long.
const KICK_WINDUP := 0.4
## Running for help and getting no nearer for this long: he gives that man up.
const FETCH_STALL := 4.0
## A hop back out of a blow: how fast it starts, and how far it gets him
## before a blade that was about to land does.
const BACKSTEP_SPEED := 8.0
const BACKSTEP_REACH := 0.9
## A throw: drawn back this long, and it carries this far.
const THROW_WINDUP := 0.62
const THROW_RANGE := 14.0
## Calling where you are to the others who cannot see you: at most this often
## for the whole squad (Squad.may_call), and a lookout this often.
const SPOT_EVERY := 2.4
## Behind you, spikes, fire or a drop: the boot is that much likelier. He
## weighs it up this often (s), and his mind made up, means nothing else for
## this long: he closes to a kick's reach for it instead of swinging from
## where he stands.
const HAZARD_KICK := 0.4
const BOOT_EVERY := 1.2
const BOOT_TIME := 1.6

const ARCHETYPES := {
	&"swordsman": {
		"speaker": "Swordsman",
		"max_health": 110.0, "attack_damage": 30.0, "attack_range": 1.8, "chase_speed": 4.4,
		"windup_time": 0.52, "recover_time": 0.5, "attack_cooldown": 0.9, "block_chance": 0.5,
		"parry_chance": 0.15, "feint_chance": 0.12, "combo_max": 2, "reaction": 0.12,
		"dodge_chance": 0.0, "kick_chance": 0.4, "poise": 3.0, "guard_damage": 18.0,
		"strafe_speed": 1.1, "counter_chance": 0.35, "stagger_time": 0.32, "combo_breaker": true,
		"read_skill": 0.7, "backstep_chance": 0.25, "timing_variance": 0.25, "lunge_chance": 0.25,
		"attacks": {&"overhead": 1.0, &"left": 1.0, &"right": 1.0, &"thrust": 0.6, &"sweep": 0.3},
		"posture": 100.0, "delay_chance": 0.25, "grip_loss": 0.4, "spacing": 0.35,
		"follow": {&"left": [&"right", &"right", &"bash", &"overhead"], &"right": [&"left", &"overhead", &"thrust"], &"overhead": [&"thrust", &"left"], &"thrust": [&"left", &"right"], &"sweep": [&"overhead"], &"bash": [&"overhead", &"thrust"]},
		"look": {"scale": 1.0, "outfit": &"swordsman", "armour": [&"nasalhelm", &"pauldron_r", &"pauldron_l"], "weapon": &"sword"},
	},
	&"duelist": {
		"speaker": "Duelist",
		"max_health": 80.0, "attack_damage": 22.0, "attack_range": 1.9, "chase_speed": 5.2,
		"windup_time": 0.42, "recover_time": 0.34, "attack_cooldown": 0.55, "block_chance": 0.3,
		"parry_chance": 0.55, "feint_chance": 0.3, "combo_max": 3, "reaction": 0.09,
		"dodge_chance": 0.55, "kick_chance": 0.15, "poise": 2.0, "guard_damage": 12.0,
		"strafe_speed": 1.7, "counter_chance": 0.5, "stagger_time": 0.26, "combo_breaker": true,
		"read_skill": 1.0, "backstep_chance": 0.55, "timing_variance": 0.35, "lunge_chance": 0.45,
		"attacks": {&"left": 1.0, &"right": 1.0, &"thrust": 1.4, &"overhead": 0.5, &"sweep": 0.35},
		"posture": 85.0, "delay_chance": 0.35, "leap_chance": 0.35, "grip_loss": 0.3, "spacing": 0.55, "carries_lantern": false,
		"follow": {&"thrust": [&"thrust", &"left", &"right", &"sweep"], &"left": [&"right", &"thrust"], &"right": [&"left", &"thrust", &"sweep"], &"leap": [&"thrust", &"left"], &"sweep": [&"thrust"]},
		"look": {"scale": 0.94, "outfit": &"duelist", "female": true, "hair": [&"Hair_Buns"], "hair_tint": Color(0.35, 0.22, 0.14), "weapon": &"rapier"},
	},
	&"brute": {
		"speaker": "Brute",
		"max_health": 240.0, "attack_damage": 46.0, "attack_range": 2.1, "chase_speed": 3.6,
		"windup_time": 0.8, "recover_time": 0.75, "attack_cooldown": 1.3, "block_chance": 0.15,
		"parry_chance": 0.0, "feint_chance": 0.0, "combo_max": 1, "reaction": 0.2,
		"dodge_chance": 0.0, "kick_chance": 0.0, "poise": 6.0, "guard_damage": 40.0,
		"strafe_speed": 0.6, "counter_chance": 0.0, "hyper_armor": true, "kick_resist": 0.35, "topple_scale": 0.5,
		"stagger_time": 0.25, "parry_stun": 1.9, "knockdown_time": 0.6, "eye_height": 2.05, "combo_breaker": true,
		"read_skill": 0.3, "timing_variance": 0.12,
		"attacks": {&"heavy": 1.0, &"overhead": 0.7, &"left": 0.5, &"sweep": 0.45},
		"posture": 190.0, "delay_chance": 0.15, "charge_chance": 0.3, "deathblows": 2, "grip_loss": 0.0, "carries_lantern": false,
		"follow": {&"overhead": [&"heavy", &"sweep"], &"left": [&"overhead", &"heavy"], &"sweep": [&"heavy"], &"charge": [&"heavy"]},
		"look": {"scale": 1.25, "outfit": &"brute", "hair": [&"Hair_Buzzed", &"Hair_Beard"], "hair_tint": Color(0.25, 0.2, 0.18), "armour": [&"pauldron_r"], "weapon": &"maul"},
	},
	&"archer": {
		"speaker": "Archer",
		"max_health": 70.0, "attack_damage": 22.0, "attack_range": 1.5, "chase_speed": 4.4,
		"windup_time": 0.42, "recover_time": 0.45, "attack_cooldown": 1.4, "block_chance": 0.0,
		"parry_chance": 0.0, "feint_chance": 0.0, "combo_max": 1, "reaction": 0.15,
		"dodge_chance": 0.4, "kick_chance": 0.0, "poise": 2.0, "guard_damage": 8.0,
		"strafe_speed": 1.3, "counter_chance": 0.0, "stagger_time": 0.3,
		"ranged": true, "draw_time": 0.95, "shot_speed": 30.0, "backstep_chance": 0.3,
		"attacks": {&"kick": 1.0}, "posture": 60.0, "kick_range": 2.1, "grip_loss": 0.5,
		"look": {"scale": 0.97, "outfit": &"archer", "armour": [&"hood"], "weapon": &"crossbow"},
	},
	&"trainer": {
		"speaker": "Arms master",
		"max_health": 100000.0, "attack_damage": 4.0, "attack_range": 2.2, "chase_speed": 0.0,
		"windup_time": 0.6, "recover_time": 0.5, "attack_cooldown": 1.2, "block_chance": 0.0,
		"parry_chance": 0.0, "feint_chance": 0.0, "combo_max": 1, "reaction": 0.1,
		"poise": 99.0, "guard_damage": 14.0, "strafe_speed": 0.0, "stays_put": true, "kick_resist": 0.0, "topple_scale": 0.0, "posture": 99999.0,
		"timing_variance": 0.0, "grip_loss": 0.0, "carries_lantern": false,
		"attacks": {&"overhead": 1.0, &"left": 0.6, &"right": 0.6, &"thrust": 0.5},
		"look": {"scale": 1.0, "outfit": &"trainer", "hair": [&"Hair_SimpleParted", &"Hair_Beard"], "hair_tint": Color(0.7, 0.68, 0.64), "weapon": &"sword"},
	},
}

## How many guards may swing at one target at once.
static var max_attackers := 1
## How many archers may be drawing on one target at once.
static var max_shooters := 1
static var _shooters := {}
## target instance id -> Array of weakrefs to the fighters swinging at it.
static var _holders := {}

var guard: CharacterBody3D

# --- skill: the plain guard's by default; an archetype raises them -----------
var parry_chance := 0.0
var feint_chance := 0.0
var combo_max := 1
## Seconds to answer what he sees.
var reaction := 0.12
var dodge_chance := 0.0
## Against a raised guard held a while: a kick to break it.
var kick_chance := 0.0
var counter_chance := 0.0
var poise_max := 3.0
## Stamina a block of his blow costs you (before the blow's own scale).
var guard_damage := 16.0
## His blows are not stopped by quick cuts, arrows or thrown things.
var hyper_armor := false
## A kick moves him this much of the way.
var kick_resist := 1.0
## Kicked off his feet, he flies this much of the boot's speed.
var topple_scale := 0.8
var strafe_speed := 0.0
## Never takes a step: the training post.
var stays_put := false
## An archer: fights from range, with a bow.
var ranged := false
var draw_time := 0.95
var shot_speed := 30.0
## Where an archer likes to stand, and closer than which he backs off.
var keep_away := 8.0
var too_close := 4.0
var _hold_shot := false
## Just before he looses, his aim is set: step out of it and the arrow goes
## where you were.
var _aim_locked := false
var _locked_aim := Vector3.ZERO
## A trained man is not cut to pieces by a string of quick blows: hit twice
## running, he flinches less and gets his guard (or a step back) up at once.
var combo_breaker := false
## After a blow lands on him he looks to his defence this long before he
## swings again: a man just cut does not throw himself onto the next cut.
var wary_after_hit := 0.4
var attacks := {&"overhead": 1.0}
## How quickly he reads the way you fight, 0 (not at all) to 1: pressed on the
## same beat or cut the same way, he parries (or guards) it and answers.
var read_skill := 0.35
## Against a long swing that barely reaches him: a step back out of it, then
## in on your recovery.
var backstep_chance := 0.0
## How far his windups stray from a steady beat (fraction): you watch the
## blade, not the rhythm.
var timing_variance := 0.1
## From out of reach, the chance he lunges in rather than walks.
var lunge_chance := 0.0
## Thrown off his feet, the chance his weapon leaves his hand (GuardHands).
var grip_loss := 0.6
## How far (m) he drifts in and out of your reach between blows, footwork you
## have to read (Chivalry's footsies): nothing for a plain watchman.
var spacing := 0.0

# --- what he is doing -----------------------------------------------------------
## Everyone fighting the same enemy (Squad.gd): the plan, and his place in it.
var squad: RefCounted = null
## Who he is under his class (Temperament.gd): nerve, drive, guile.
var temper: RefCounted = null

## His balance (Sekiro's posture), 0 up to posture_max. Parried, dodged,
## jumped, kicked, cut, or holding his guard against hard blows, it fills;
## given room, it drains (slower the more he is hurt). Full, he is OPEN
## (is_open): no guard, no blow, and the next blow on him is a deathblow.
var posture := 0.0
var posture_max := 70.0
## How many deathblows kill him: one for most men, two for a brute.
var deathblows := 1
## How he is doing, and so how he fights (_judge_mood): "steady"; "shaken"
## (his balance going: he backs off to find it, guard up, striking only to
## punish); "hurt" (badly cut: wary, at the edge of reach, guard up, calling
## for help); "enraged" (a brute badly cut: faster, harder, no guard at all);
## "pressing" (you are the one in trouble: he comes on, longer strings);
## "desperate" (hurt and alone: all in).
var mood: StringName = &"steady"
var _mood_timer := 0.0
## How long this spell of being shaken has lasted, and how long before
## another may come.
var _shaken_for := 0.0
var _shaken_rest := 0.0
var _open := 0.0
var _posture_calm := 0.0
## After each blow, what he likes to follow it with (kind -> kinds), and how
## often a follow-up comes late, held back to catch a parry thrown too soon.
var follow := {}
var delay_chance := 0.0
## From out of reach: how often he leaps in (a swordmaster) or charges (a
## brute) instead of walking.
var leap_chance := 0.0
var charge_chance := 0.0
## How far his boot reaches, if not where his blade would (an archer kicks
## you off at sword's length).
var kick_range := 0.0
## The follow-up now under way is a late one.
var _late := false

## His guard is up: quick cuts from the front are caught.
var guarding := false
var _guard_hold := 0.0
var _poise := 3.0
## Guard broken: it cannot come up again until this runs out.
var _broken := 0.0
## The serial of the blow he last saw coming, when, and his answer.
var _threat := -1
var _threat_seen := 0.0
var _answer: StringName = &""
## When his parry is at its height (game time), and how long he is open after
## one that met nothing.
var _parry_at := -1.0
var _parry_miss := 0.0
var _combo_left := 0
## Part of the way up (0..1) that this blow is abandoned: a feint. <0: not.
var _feint_at := -1.0
## The next blow's windup, scaled: quicker in a combo, after a feint, as a
## riposte.
var _next_scale := 1.0
var _strafe := 1.0
var _strafe_timer := 0.0
## A short sidestep now and then, to keep the fight moving.
var _reposition := 0.0
var _hold_token := false
var _dodge := 0.0
var _dodge_velocity := Vector3.ZERO
var _last_attack: StringName = &""
var _repeats := 0
## How long you have hidden behind a raised guard in front of him.
var _turtle := 0.0
## How long he has waited behind you for his turn.
var _flank_wait := 0.0
## Last blow's outcome, for the combo: he presses on after a hit or a miss.
var _landed := false
## Blows that landed on him in a row, and how long until the run is over.
var _hit_streak := 0
var _streak_timer := 0.0
## Hit twice running: his next answer comes without thinking.
var _reflex := false
## Chose to attack into your charge: his guard must not hold him back.
var _countering := false
## The earliest moment his parry can meet a blade: he cannot parry faster
## than he can react.
var _parry_open_at := -1.0
## The blow he is watching has been held into a charge, and he has decided
## what to do about that.
var _answered_charge := false
## What he has read of you: how hard you have been pressing (blows started on
## each other's heels, decaying), when the last came, and which way you have
## been cutting (direction -> weight, decaying).
var _pressure := 0.0
var _last_threat_at := -10.0
var _habits := {}
## How well he read the last blow (0..1): a blow he saw coming barely rocks
## him, so a string of them cannot keep him reeling.
var _read_level := 0.0
## Stepped back out of a blow: until this game time he is set on punishing
## the miss.
var _punish_until := -1.0
## Holding you off alone: until his next call for help. His place last time
## (a new place starts its calls afresh), and how long, broken and away, he
## has not seen you.
var _help_call := 0.0
var _last_place: StringName = &""
var _fled_unseen := 0.0
## How long he has waited at his place at your side for his turn (a rash
## man's patience runs out), and how long more he gives ground (craven).
var _flank_waited := 0.0
var _yielding := 0.0
## Running for help: whether he has shouted to the man he is fetching yet,
## and until his next cry on the way.
var _shouted_for_help := false
var _fetch_call := 0.0
## Getting no nearer the man he is fetching: the nearest he has been, for how
## long he has not got nearer, and whether he has tried a fresh path.
var _fetch_best := INF
var _fetch_stalled := 0.0
var _fetch_repathed := false
## In the fight since he last came into it (a new sighting calls the hunt).
var _was_fighting := false
## His patience at your side had run out (said so once).
var _was_impatient := false
## His footwork in and out of your reach (spacing): where in the swing he is,
## and how quick this swing is.
var _space_phase := 0.0
var _space_rate := 1.3
## Lost you: followed the way you went a few steps on (GuardNav.scent), from
## where, and to where.
var _scented := false
var _scent_from := Vector3.INF
var _scent_point := Vector3.ZERO
## You are somewhere his feet cannot take him (up high, across a gap): looked
## at twice a second.
var _unreachable := false
var _reach_check := 0.0
## What he is going to pick up (a blade, or a thing to throw), and what he
## gave up on (could not get to it).
var _fetching: Node3D = null
var _gave_up_on := {}
var _fetch_check := 0.0
## Calling where you are: until the next call.
var _spot_timer := 0.0
## How his last blow went: "landed", "blocked", "dodged", "missed", or "".
var _outcome: StringName = &""
## Taunted you for being out of reach (once a while).
var _taunt_timer := 0.0
## An archer: trying for a clear line to you, and how long he has had none.
var _no_line := 0.0
var _line_side := 1.0
## An archer's mark when it is not you (powder, a rope): INF when it is you.
var _shot_point := Vector3.INF
## Whether something waits behind you (spikes, fire, a drop), and when he
## last looked.
var _hazard_there := false
var _hazard_checked_at := -10.0
## Set on booting you into it until then; when he last weighed it up.
var _boot_until := -10.0
var _boot_weighed := -10.0


func _init(p_guard: CharacterBody3D) -> void:
	guard = p_guard
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_strafe_timer = randf_range(1.0, 2.5)
	_space_phase = randf() * TAU
	_space_rate = randf_range(1.0, 1.7)
	_spot_timer = randf() * 0.5


# ---------------------------------------------------------------------------
# Archetypes
# ---------------------------------------------------------------------------

## Makes the guard one of ARCHETYPES. Call before he enters the tree (or in
## his _ready, before health is set).
func apply(archetype: StringName) -> void:
	if not ARCHETYPES.has(archetype):
		return

	var a: Dictionary = ARCHETYPES[archetype]

	for key in ["max_health", "attack_damage", "attack_range", "chase_speed", "windup_time",
			"recover_time", "attack_cooldown", "block_chance", "stagger_time", "parry_stun",
			"knockdown_time", "eye_height", "carries_lantern"]:
		if a.has(key):
			guard.set(key, a[key])

	if a.has("speaker") and guard.speaker_name == "Guard":
		guard.speaker_name = a["speaker"]

	parry_chance = a.get("parry_chance", parry_chance)
	feint_chance = a.get("feint_chance", feint_chance)
	combo_max = a.get("combo_max", combo_max)
	reaction = a.get("reaction", reaction)
	dodge_chance = a.get("dodge_chance", dodge_chance)
	kick_chance = a.get("kick_chance", kick_chance)
	counter_chance = a.get("counter_chance", counter_chance)
	poise_max = a.get("poise", poise_max)
	guard_damage = a.get("guard_damage", guard_damage)
	hyper_armor = a.get("hyper_armor", hyper_armor)
	kick_resist = a.get("kick_resist", kick_resist)
	posture_max = a.get("posture", posture_max)
	deathblows = a.get("deathblows", deathblows)
	follow = a.get("follow", follow)
	delay_chance = a.get("delay_chance", delay_chance)
	leap_chance = a.get("leap_chance", leap_chance)
	charge_chance = a.get("charge_chance", charge_chance)
	kick_range = a.get("kick_range", kick_range)
	topple_scale = a.get("topple_scale", topple_scale)
	strafe_speed = a.get("strafe_speed", strafe_speed)
	stays_put = a.get("stays_put", stays_put)
	ranged = a.get("ranged", ranged)
	draw_time = a.get("draw_time", draw_time)
	shot_speed = a.get("shot_speed", shot_speed)
	combo_breaker = a.get("combo_breaker", combo_breaker)
	attacks = a.get("attacks", attacks)
	read_skill = a.get("read_skill", read_skill)
	backstep_chance = a.get("backstep_chance", backstep_chance)
	timing_variance = a.get("timing_variance", timing_variance)
	lunge_chance = a.get("lunge_chance", lunge_chance)
	grip_loss = a.get("grip_loss", grip_loss)
	spacing = a.get("spacing", spacing)
	_poise = poise_max


static func look_of(archetype: StringName) -> Dictionary:
	return (ARCHETYPES.get(archetype, {}) as Dictionary).get("look", {})


# ---------------------------------------------------------------------------
# The fight, every physics frame while he is in combat
# ---------------------------------------------------------------------------

func fight(delta: float) -> void:
	var now: float = guard._game_time
	var target: Node3D = guard._target
	var sees: bool = guard.can_see_target and target != null and is_instance_valid(target)
	var to := Vector3.ZERO
	var dist := INF
	var level := INF

	if sees:
		var feet: Vector3 = guard._feet_of(target)
		to = feet - guard.global_position
		level = absf(to.y)
		to.y = 0.0
		dist = to.length()

	_tick(delta, now)
	_with_squad(target, delta)

	# Back on you after a search, or new to it: the others hear of it.
	if not _was_fighting:
		_was_fighting = true

		if squad != null:
			squad.sighted(guard)

	_update_mood(delta, target)

	# Waiting his turn at your side: a rash man's patience runs out.
	if role() == &"flank" and not _hold_token and guard._phase == &"":
		_flank_waited += delta
	else:
		_flank_waited = 0.0

	# ...and he says so as he goes in.
	var impatient: bool = role() == &"flank" and squad != null and squad.impatient_now(guard)

	if impatient and not _was_impatient and temper != null and guard._bark_timer <= 0.0:
		var said: String = temper.line(&"press")

		if said != "":
			guard.bark(said)

	_was_impatient = impatient

	if sees:
		_update_reach(delta, target, level)
		_call_out_where(delta, target)

	if guard._phase != &"":
		_update_attack(delta, target, sees, to, dist, level)
		return

	# Broken, and you on him: he begs for his life; let go, he gets up and
	# runs to his own (GuardMercy.gd). No guard, no blows, meanwhile.
	var broken: bool = squad != null and squad.will_of(guard) == &"broken" and role() in [&"flee", &"fetch"]

	if _dodge <= 0.0 and guard._mercy.update(delta, target, sees, broken):
		guarding = false
		_answer = &""
		return

	if sees:
		_read_threat(delta, target, dist, now)
		_reflex_defence(target, dist)
		_answer_threat(delta, target, dist, now)
	else:
		# Nobody to guard against.
		guarding = false
		_answer = &""

	if _dodge > 0.0:
		_update_dodge(delta)
		return

	_footwork(delta, target, sees, to, dist, level)

	if sees:
		_consider_attack(delta, target, to, dist, level)


func _tick(delta: float, now: float) -> void:
	_broken = maxf(_broken - delta, 0.0)
	_parry_miss = maxf(_parry_miss - delta, 0.0)
	_streak_timer -= delta

	if _streak_timer <= 0.0:
		_hit_streak = 0
		_reflex = false

	_strafe_timer -= delta
	_reposition = maxf(_reposition - delta, 0.0)

	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(2.0, 4.0)

		if randf() < 0.6:
			_strafe = -_strafe

		# Now and then a step aside, not a constant circling: squared up to
		# you, he is readable.
		if strafe_speed > 0.0 and randf() < 0.5 * _step_factor():
			_reposition = randf_range(0.4, 0.7)

	if not guarding:
		_poise = minf(_poise + delta / 1.6, poise_max)

	# His balance comes back given room, not while he is pressed; slower the
	# more he is hurt, and slower behind a raised guard.
	_posture_calm += delta

	if _open > 0.0:
		_open -= delta

		# Found his feet again: still shaken.
		if _open <= 0.0:
			posture = posture_max * 0.35
	elif _posture_calm > 1.2 and posture > 0.0:
		var whole: float = clampf(float(guard.health) / maxf(float(guard.max_health), 1.0), 0.0, 1.0)
		posture = maxf(posture - posture_max * 0.14 * (0.5 + 0.5 * whole) * (0.6 if guarding else 1.0) * delta, 0.0)

	# A parry that met nothing: he is left open for a moment.
	if _parry_at > 0.0 and now > _parry_at + 0.14:
		_parry_at = -1.0
		_parry_open_at = -1.0
		_parry_miss = 0.45


## Staggered: no footwork, no blows, no guard; but he still sees what is
## coming, so his answer is ready the moment he finds his feet.
func watch(delta: float) -> void:
	var now: float = guard._game_time
	_tick(delta, now)
	guarding = false
	var target: Node3D = guard._target

	if not guard.can_see_target or target == null or not is_instance_valid(target):
		return

	var feet: Vector3 = guard._feet_of(target)
	var dist := Vector2(feet.x - guard.global_position.x, feet.z - guard.global_position.z).length()
	_read_threat(delta, target, dist, now)


# ---------------------------------------------------------------------------
# Reading your blows, and answering them
# ---------------------------------------------------------------------------

func _combat_of(target: Node3D) -> Node:
	var combat: Variant = target.get("combat") if target != null else null
	return combat as Node if combat is Node and (combat as Node).has_method("threat_serial") else null


func _read_threat(delta: float, target: Node3D, dist: float, now: float) -> void:
	var combat := _combat_of(target)

	if combat == null:
		return

	var phase: StringName = combat.threat_phase()

	# Hiding behind a raised guard in front of him: he notices.
	if bool(combat.get("blocking")) and dist < 3.0:
		_turtle += delta
	else:
		_turtle = maxf(_turtle - 2.0 * delta, 0.0)

	if phase == &"":
		return

	var serial: int = combat.threat_serial()

	if serial == _threat:
		# A blow he chose to take, held back into a charge: think again.
		if _answer == &"" and phase == &"charging" and now - _threat_seen > 0.18 and not _answered_charge:
			_answered_charge = true
			_answer = _answer_to_charge(dist)
			_threat_seen = now
		return

	if dist > float(combat.threat_reach()) + 1.2:
		return

	_threat = serial
	_threat_seen = now
	_answered_charge = false
	_learn(now, combat.threat_direction() if combat.has_method("threat_direction") else &"overhead")
	_answer = _choose_answer(combat, dist)

	# A parry is timed off the windup and committed to at once: he reads the
	# blade going back and meets it where it will be. Abandon the blow (a
	# feint) and he parries thin air.
	if _answer == &"parry" and phase != &"charging":
		var arrives: float = combat.time_to_contact()

		if arrives >= 0.0:
			_schedule_parry(now, arrives, now)
			_answer = &""


## A parry timed to meet a blade `arrives` seconds from now, begun when he
## saw it at `seen`: it cannot be up before he has had time to react.
func _schedule_parry(now: float, arrives: float, seen: float) -> void:
	_parry_at = now + maxf(arrives, reaction * 0.5)
	_parry_open_at = maxf(seen + reaction, _parry_at - 0.09)


## Hit twice running and still under attack: up with the guard at once (or,
## light on his feet, a step back out of reach). A brute just swings back.
func _reflex_defence(target: Node3D, dist: float) -> void:
	if not _reflex or guard._stagger > 0.0 or guard._phase != &"":
		return

	var combat := _combat_of(target)

	if combat == null or combat.threat_phase() == &"":
		return

	_reflex = false
	_hit_streak = 0

	if hyper_armor:
		guard._attack_timer = 0.0
		_next_scale = 0.85
	elif dodge_chance > 0.0 and dist < _reach(&"overhead") + 0.8:
		_start_dodge(target)
	elif _broken <= 0.0 and guard._hands.armed:
		guarding = true
		_guard_hold = 0.5
		_answer = &""


## A blow started: how hard you are pressing him, and which way you cut.
func _learn(now: float, direction: StringName) -> void:
	var gap := now - _last_threat_at
	_last_threat_at = now
	# On each other's heels, blows add up; spaced out, the count dies away.
	_pressure = clampf(_pressure * exp(-gap / 1.4) + (1.0 if gap < 1.1 else 0.35), 0.0, 5.0)
	var fade := exp(-gap / 4.0)

	for way in _habits.keys():
		_habits[way] = float(_habits[way]) * fade

	_habits[direction] = float(_habits.get(direction, 0.0)) + 1.0


## How well he has read this blow, 0..1: you have been pressing on a beat, or
## this is the cut you keep throwing.
func _read(direction: StringName) -> float:
	var spam := clampf((_pressure - 1.0) / 1.8, 0.0, 1.0)
	var total := 0.0

	for way in _habits:
		total += float(_habits[way])

	var habit := 0.0

	if total > 1.8:
		habit = clampf((float(_habits.get(direction, 0.0)) / total - 0.4) / 0.5, 0.0, 1.0)

	return read_skill * maxf(spam, habit)


func _choose_answer(combat: Node = null, dist := 0.0) -> StringName:
	# Mid-parry, or just out of one that met nothing: no answer at all. (A
	# stagger does not stop him choosing: he answers when it passes.)
	if guard.state != COMBAT or guard._phase != &"" or _parry_miss > 0.0 or _parry_at > 0.0:
		return &""

	if guard._knock > 0.0:
		return &""

	var direction: StringName = combat.threat_direction() if combat != null and combat.has_method("threat_direction") else &"overhead"
	var read := _read(direction)
	_read_level = read

	# A blow a quick hop takes him out of (not a thrust's long reach): out of
	# it, and back in on the miss.
	if backstep_chance > 0.0 and combat != null and dist + BACKSTEP_REACH > float(combat.threat_reach()) + 0.35 and randf() < (backstep_chance + _plan(&"backstep")) * (1.0 + read):
		return &"back"

	# A man who knows what is coming can meet it: a parry if he has the skill,
	# his guard up if not.
	# (Reading raises the odds to a point; it never lowers a sure thing.)
	if parry_chance > 0.0 and guard._hands.armed and randf() < minf(parry_chance + _plan(&"parry") + read * 0.8, maxf(parry_chance, 0.92)):
		return &"parry"

	# Shaken or hurt he hides behind his blade; desperate he barely does;
	# berserk or enraged, not at all.
	var careful := 0.35 if mood == &"shaken" or mood == &"hurt" else (-0.2 if mood == &"desperate" else 0.0)
	var reckless: bool = role() == &"berserk" or role() == &"desperate" or mood == &"enraged"

	if _broken <= 0.0 and not reckless and guard._hands.armed and randf() < minf(guard.block_chance + careful + (_plan(&"guard") if guard.block_chance > 0.0 else 0.0) + read * 0.9 + _guard_bias(), maxf(guard.block_chance + careful, 0.95)):
		return &"guard"

	if dodge_chance > 0.0 and randf() < dodge_chance * 0.5:
		return &"dodge"

	return &""


## You are holding a power blow in front of him. A quick one can stop it, a
## step back makes it miss, a raised guard only delays the pain.
func _answer_to_charge(dist: float) -> StringName:
	# Caught mid-parry by a blow that did not come when he read it would.
	if guard._phase != &"" or guard._stagger > 0.0 or _parry_miss > 0.0 or _parry_at > 0.0:
		return &""

	if dodge_chance > 0.0 and randf() < dodge_chance:
		return &"dodge"

	if counter_chance > 0.0 and dist <= _reach(&"thrust") and randf() < counter_chance:
		return &"counter"

	return &""


func _answer_threat(delta: float, target: Node3D, dist: float, now: float) -> void:
	var combat := _combat_of(target)
	var phase: StringName = combat.threat_phase() if combat != null else &""

	if _answer != &"" and now - _threat_seen >= reaction:
		match _answer:
			&"guard":
				guarding = true
				_guard_hold = 0.35
				_answer = &""
			&"parry":
				# A charge loosed: he tries to meet it, but only from when he
				# sees it fall, and it falls fast (a charged blow is hard to
				# parry).
				if phase == &"strike":
					var arrives: float = combat.time_to_contact()
					_schedule_parry(now, clampf(arrives, 0.0, 0.6), now)
					_answer = &""
				elif phase == &"":
					_answer = &""
			&"dodge":
				if dist < _reach(&"overhead") + 0.8:
					_start_dodge(target)

				_answer = &""
			&"back":
				_start_dodge(target, true)
				_punish_until = now + 0.9
				_answer = &""
			&"counter":
				# Into the charge before it is loosed: guard down, blade up.
				_answer = &""
				guarding = false
				_countering = true
				guard._attack_timer = 0.0
				_next_scale = 0.8
			_:
				_answer = &""

	if guarding:
		# Held while a blow is coming that can reach him.
		if phase != &"" and dist <= float(combat.threat_reach()) + 1.2:
			_guard_hold = 0.35

		_guard_hold -= delta

		if _guard_hold <= 0.0 or _broken > 0.0:
			guarding = false


## Called by the guard when a weapon reaches him, before it does anything.
## "parried", "blocked", or "" to let it land.
func defend(kind: StringName, attacker: Node3D) -> StringName:
	if attacker == null or not (kind in [&"quick", &"power", &"thrown"]):
		return &""

	if guard.state != COMBAT or guard._stagger > 0.0 or guard._knock > 0.0:
		return &""

	# Only what comes at his front.
	var to := attacker.global_position - guard.global_position
	to.y = 0.0

	if to.length() > 0.01 and (-guard.global_basis.z).dot(to.normalized()) < 0.3:
		return &""

	var now: float = guard._game_time

	# In the middle of his own blow he has neither guard nor parry; with no
	# blade in his hand, neither at all.
	if guard._phase != &"" or not guard._hands.armed:
		return &""

	if _parry_at > 0.0 and now >= _parry_open_at and now <= _parry_at + 0.14 and kind != &"thrown":
		_parry_at = -1.0
		_parry_open_at = -1.0
		_parry_miss = 0.0
		_on_parried_you(attacker)
		return &"parried"

	if not guarding:
		return &""

	if kind == &"power":
		# A charged blow smashes through: the guard is broken and it lands.
		break_guard()
		return &""

	if kind == &"quick":
		# How hard the blow presses his guard: a heavy cut, a running blow.
		var combat := _combat_of(attacker)
		var weight := 1.0

		if combat != null and combat.has_method("blow_poise"):
			weight = float(combat.blow_poise())
		elif combat != null and combat.has_method("_style"):
			weight = float(combat._style()["poise"])

		_poise -= weight
		add_posture(8.0 * weight)

		if _poise <= 0.0:
			break_guard()

	return &"blocked"


## Thrown further off his balance by `amount`: full, he is OPEN.
func add_posture(amount: float) -> void:
	if amount <= 0.0 or _open > 0.0 or posture_max >= 9999.0:
		return

	posture = minf(posture + amount, posture_max)
	_posture_calm = 0.0
	# Shaken or not: judged again at once.
	_mood_timer = 0.0

	if posture >= posture_max:
		_break_posture()


func is_open() -> bool:
	return _open > 0.0


## Off his balance: guard gone, blow lost, reeling, open to a deathblow.
func _break_posture() -> void:
	_open = OPEN_TIME
	posture = posture_max
	guarding = false
	_broken = maxf(_broken, OPEN_TIME)
	guard._phase = &""
	_combo_left = 0
	_feint_at = -1.0
	_parry_at = -1.0
	guard._stagger = maxf(guard._stagger, OPEN_TIME)
	guard._attack_timer = maxf(guard._attack_timer, OPEN_TIME + 0.2)
	release_token()
	Sfx.play(guard, &"guard_break", guard.eye_position() - guard.global_basis.z * 0.3, 3.0, 0.8)

	if guard._rig != null and guard._rig.has_method("react_open"):
		guard._rig.react_open(OPEN_TIME)

	if guard.has_signal(&"posture_broken"):
		guard.emit_signal(&"posture_broken")


## What a blow of `damage` does to him while he is open.
func deathblow_damage(damage: float) -> float:
	return maxf(damage * DEATHBLOW, float(guard.max_health) / float(maxi(deathblows, 1)) + 1.0)


## The deathblow landed: whatever is left of him is his own again.
func end_open() -> void:
	_open = 0.0
	_broken = 0.0
	posture = posture_max * 0.35
	guard._stagger = minf(guard._stagger, 0.5)

	if guard._rig != null and guard._rig.has_method("end_open"):
		guard._rig.end_open()


## What each call looks like (his blade's glow, the HUD's marks).
static func call_colour(call: StringName) -> Color:
	match call:
		&"thrust":
			return Color(0.42, 0.7, 1.0)
		&"low":
			return Color(1.0, 0.5, 0.08)
		&"unblockable":
			return Color(1.0, 0.12, 0.05)
		&"bash":
			return Color(1.0, 0.86, 0.35)

	return Color(0.7, 0.72, 0.78)


## You answered his blow as it asked ("dodged" out of it at the last moment,
## "jumped" his sweep): he is left overextended, held in his follow-through,
## his balance shaken.
func _answered(how: StringName, target: Node3D) -> void:
	_combo_left = 0
	_feint_at = -1.0
	release_token()
	add_posture(38.0)

	if not is_open():
		guard._stagger = maxf(guard._stagger, 0.65)
		guard._attack_timer = maxf(guard._attack_timer, 0.8)

	var combat := _combat_of(target)

	if combat != null and combat.has_method("on_answered"):
		combat.on_answered(how, guard)

	if guard.has_signal(&"answered"):
		guard.emit_signal(&"answered", how)


## His guard is knocked aside: a power blow, a kick, too many quick cuts.
func break_guard() -> void:
	if not guarding and _broken > 0.0:
		return

	guarding = false
	_broken = 1.6
	_poise = 0.0
	guard._stagger = maxf(guard._stagger, 0.7)
	Sfx.play(guard, &"guard_break", guard.eye_position() - guard.global_basis.z * 0.4)

	if guard.has_signal(&"guard_broken"):
		guard.emit_signal(&"guard_broken")


## He turned your blow aside: sparks between you, and his answer comes at
## once, quicker than any other.
func _on_parried_you(attacker: Node3D) -> void:
	var clash: Vector3 = guard.eye_position().lerp(attacker.global_position + Vector3.UP * 0.6, 0.35)
	Fx.sparks(guard, clash, (attacker.global_position - clash).normalized(), 1.6)
	Sfx.play(guard, &"parry", clash, 0.0, 0.92)
	Sfx.play(guard, &"clang", clash, -7.0, 0.85)
	SoundBus.emit_sound(clash, 58.0, guard, &"clang")
	guard._rig.react_parry_success()
	guarding = false
	_combo_left = 0
	# The riposte.
	guard._attack_timer = 0.0
	_next_scale = 0.6


func is_parrying() -> bool:
	var now: float = guard._game_time
	return _parry_at > 0.0 and now >= _parry_at - 0.12 and now <= _parry_at + 0.14


## 0..1 through his parry motion (for the rig): rising to the parry's height,
## then falling away.
func parry_pose() -> float:
	if _parry_at <= 0.0:
		return 0.0

	var now: float = guard._game_time
	var d := now - _parry_at

	if d < -0.12 or d > 0.14:
		return 0.0

	return 1.0 - absf(d) / (0.12 if d < 0.0 else 0.14)


func on_kicked() -> void:
	if guarding:
		break_guard()

	_parry_at = -1.0
	_combo_left = 0
	release_token()


func on_hit(interrupted: bool) -> void:
	_hit_streak += 1
	_streak_timer = 1.2
	# It got through: whatever guard he had was not in the way.
	guarding = false
	_countering = false

	if combo_breaker and _hit_streak >= 2:
		_reflex = true

	if interrupted:
		_combo_left = 0
		_feint_at = -1.0
		_parry_at = -1.0
		_parry_open_at = -1.0
		release_token()

	# Cut twice running: his friends see he needs help.
	if _hit_streak >= 2:
		_call_in()


## How long a blow of `kind` rocks him. Hit twice running, a trained man
## rocks less each time: he is already bracing for the next. A riposte (out
## of his own blow turned aside, so nothing he could read or brace for)
## rocks him harder than a quick cut, but only a moment longer.
func stagger_for(kind: StringName, base: float, riposte := false) -> float:
	var heavy := kind == &"power" or kind == &"crush"
	var seconds := base * (1.8 if heavy else (RIPOSTE_ROCK if riposte else 1.0))

	# He saw it coming: it rocks him, but not for long.
	if not heavy and not riposte:
		seconds *= 1.0 - 0.7 * _read_level

	if combo_breaker and _hit_streak >= 2 and not heavy and not riposte:
		seconds = minf(seconds, 0.14)

	return seconds


## Whether `attacker`'s blow landing now is a riposte.
func riposted_by(attacker: Node3D) -> bool:
	var combat := _combat_of(attacker)
	return combat != null and combat.has_method("is_riposte") and combat.is_riposte()


## His blow met your raised guard: it bounces, and he recovers from it a
## little longer than from one that landed. A man who reads a fight well, with
## more of his string to come, turns it straight into the blow that beats a
## guard instead (a pommel, a boot, a point, one under it).
func recover_from_block() -> void:
	var kind: StringName = guard._attack
	_outcome = &"blocked"

	if _combo_left > 0 and read_skill >= 0.5 and guard._hands.armed:
		var breaker := _guard_breaker_after(kind)

		if breaker != &"":
			_combo_left -= 1
			_late = false
			_start(breaker, 0.8)
			return

	guard._phase = &"recover"
	guard._phase_length = guard.recover_time * float(ATTACKS.get(kind, ATTACKS[&"overhead"])["recover"]) * 1.15
	guard._phase_timer = guard._phase_length
	_combo_left = 0


## Out of the fight (lost you): nothing held up, nothing pending. He is still
## in the hunt (Squad.gd) until he gives it up.
func leave_combat() -> void:
	guarding = false
	_answer = &""
	_parry_at = -1.0
	_parry_open_at = -1.0
	_countering = false
	_was_fighting = false
	_scented = false
	_fetching = null
	_shot_point = Vector3.INF
	_boot_until = -10.0
	release_token()

	if guard._mercy != null:
		guard._mercy.reset()


## In the squad fighting `target` (Squad.gd), and helping it make its plan.
func _with_squad(target: Node3D, delta: float) -> void:
	var wanted: RefCounted = SquadScript.of(target) if target != null and is_instance_valid(target) else null

	if wanted != squad:
		if squad != null:
			squad.leave(guard)

		squad = wanted

		if squad != null:
			squad.join(guard)

	if squad != null:
		squad.think(delta)


## His place in the plan (engage when alone, or with no squad).
func role() -> StringName:
	return squad.role_of(guard) if squad != null else &"engage"


## The plan's push on one of his odds.
func _plan(what: StringName) -> float:
	return squad.bonus(what) if squad != null else 0.0


## How hard he presses now: his drive, and the anger a bold man turns the
## garrison's dread into.
func drive_now() -> float:
	if temper == null:
		return 0.5

	var target: Node3D = guard._target
	var garrison: RefCounted = GarrisonScript.of(target) if target != null and is_instance_valid(target) else null
	var anger: float = garrison.anger_of(float(temper.nerve)) if garrison != null else 0.0
	return minf(float(temper.drive) + 0.3 * anger, 1.0)


## What he says as he takes you on: of their dead, if the garrison's dread has
## turned to anger in him; else in his own way.
func engage_line() -> String:
	var target: Node3D = guard._target
	var garrison: RefCounted = GarrisonScript.of(target) if target != null and is_instance_valid(target) else null

	if temper != null and garrison != null and garrison.anger_of(float(temper.nerve)) > 0.2:
		var angry: String = temper.revenge_line(int(garrison.captains))

		if angry != "":
			return angry

	var own: String = temper.line(&"engage") if temper != null else ""
	return own if own != "" else "You there! Stop!"


## How far he is from his own kind (Temperament.gd): this is what makes him
## fight otherwise than his class does. Nothing, for the man his class is.
func _dn() -> float:
	return float(temper.nerve) - float(temper.base_nerve) if temper != null else 0.0


func _dd() -> float:
	return drive_now() - float(temper.base_drive) if temper != null else 0.0


func _dg() -> float:
	return float(temper.guile) - float(temper.base_guile) if temper != null else 0.0


## A man rasher than his kind keeps his guard up less.
func _guard_bias() -> float:
	return -0.4 * _dd()


## A slyer man feints more (if he feints at all).
func _feint_bias() -> float:
	return 0.3 * _dg() if feint_chance > 0.0 else 0.0


## How often he takes a step aside: more the slyer or rasher, less the more
## stubborn (planted).
func _step_factor() -> float:
	return clampf(1.0 + 1.5 * (_dg() + _dd()) - 1.5 * maxf(_dn(), 0.0), 0.3, 2.0)


## Running for help, or broken and away: losing sight of you does not make
## him go looking for you.
func keeps_running() -> bool:
	var place := role()
	return place == &"fetch" or (place == &"flee" and squad != null and squad.will_of(guard) == &"broken")


func on_parried() -> void:
	_combo_left = 0
	_feint_at = -1.0
	release_token()
	_call_in()


## Busy with me? Then another of us goes for you: the nearest friend fighting
## you, not already swinging, comes in quickly.
func _call_in() -> void:
	var target: Node3D = guard._target

	if target == null or not is_instance_valid(target) or not guard.is_inside_tree():
		return

	var best: Node = null
	var nearest := 5.0

	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		if other == guard or other.get("_fighter") == null or other.get("_target") != target:
			continue

		if int(other.state) != COMBAT or other._phase != &"" or other._stagger > 0.0 or other._fighter.ranged or other._fighter.stays_put:
			continue

		var d: float = (other as Node3D).global_position.distance_to(target.global_position)

		if d < nearest:
			nearest = d
			best = other

	if best != null:
		best._attack_timer = minf(best._attack_timer, 0.15)
		best._fighter._next_scale = minf(best._fighter._next_scale, 0.85)


## Gone from the fight: `killed`, or only knocked senseless.
func on_died(killed := true) -> void:
	release_token()

	if squad != null:
		squad.member_died(guard, killed)
		squad = null


# ---------------------------------------------------------------------------
# Footwork
# ---------------------------------------------------------------------------

func _footwork(delta: float, target: Node3D, sees: bool, to: Vector3, dist: float, level: float) -> void:
	if stays_put:
		guard._stop(delta)

		if sees:
			guard._face(to, delta)

		return

	var place := role()

	if place != _last_place:
		_last_place = place
		_help_call = 0.0
		_shouted_for_help = false
		_fetch_call = 0.0
		_fetch_best = INF
		_fetch_stalled = 0.0
		_fetch_repathed = false

	match place:
		&"flee":
			_flee(delta, target, sees, to)
			return
		&"fetch":
			# On foot, archer or not: to the man he is fetching.
			_fetch(delta, target, sees, to)
			return

	# His weapon lost, or you where he cannot reach: something to pick up.
	if _fetch_something(delta, target, sees, dist):
		return

	match place:
		&"rally":
			if _rally(delta, target, sees, to, dist):
				return
		&"bodyguard":
			if _stand_guard(delta, target, sees, to, dist):
				return
		&"lookout":
			if _keep_lookout(delta, sees, to, dist):
				return
		&"intercept":
			if _intercept(delta, target, sees, dist):
				return

	if ranged:
		_footwork_ranged(delta, target, sees, to, dist, level)
		return

	var reach := _reach(&"overhead")
	# Waiting his turn: at his place at your side or back (the plan's, or
	# his own among the others).
	# A rash man at your side whose patience has run out does not wait.
	var impatient: bool = place == &"flank" and squad != null and squad.impatient_now(guard)
	var waiting := (strafe_speed > 0.0 and not _hold_token and _someone_else_swinging(target)) or ((place == &"flank" or place == &"reserve") and not _hold_token and not impatient)
	var want := reach + 0.9 if waiting else maxf(reach * 0.8, 1.1)
	# A man rasher than his kind stands closer in; a warier one further off.
	want = maxf(want - 0.6 * _dd(), 1.0)

	if place == &"reserve":
		# Waiting his turn, a rash man edges in.
		want = reach + 2.4 - 1.2 * maxf(drive_now() - 0.5, 0.0)

	# How he is doing: shaken he steps out of reach to find his feet, hurt he
	# keeps to the edge of it; on top of you, he crowds you.
	match mood:
		&"shaken":
			want = maxf(want, reach + 1.3)
		&"hurt":
			want = maxf(want, reach + 0.5)
		&"pressing", &"desperate", &"enraged":
			if not waiting:
				want = maxf(reach * 0.65, 1.0)

	# Holding you off: at the edge of his reach if he has the nerve for it,
	# well out of it if not; guard up while you are close; calling for help.
	if place == &"hold":
		want = reach if temper != null and float(temper.nerve) >= 0.6 else reach + 2.0

		if sees and dist < 4.0 and _broken <= 0.0 and guard._hands.armed:
			guarding = true
			_guard_hold = maxf(_guard_hold, 0.2)

		_call_for_help(delta)

	# A craven man gives ground when you come at him.
	if temper != null and temper.tag == &"craven" and sees and target is CharacterBody3D:
		var closing: float = -(target as CharacterBody3D).velocity.dot(to / maxf(dist, 0.001))

		if closing > 1.2:
			_yielding = 0.6

	if _yielding > 0.0:
		_yielding -= delta
		want += 1.5

	# You where he cannot get to (up on a roof, across a gap): he keeps back
	# where he can still see you (under the ledge he could not), to throw
	# what he can at you, or to wait you out.
	if _unreachable and not waiting and _hold_off(delta, target, sees, to, dist):
		return

	# Shaken, he lets you go while he finds his feet: he does not come after
	# you while he can see you.
	var holding: bool = mood == &"shaken" and sees and level <= guard.attack_reach_height

	if not holding and (not sees or dist > want + 1.6 or level > guard.attack_reach_height):
		# Closing in: along the navmesh to where you will be if he can see
		# you running, else where he last saw you (or was told), and a few
		# steps on the way you went. Berserk, or told to rush you, he comes
		# faster; hurt, slower.
		guard._go_to(_chase_point(target, sees, dist))
		var hurry := 1.3 if place == &"berserk" else (1.15 if squad != null and squad.tactic == &"rush" else 1.0)

		if mood == &"hurt":
			hurry *= 0.75
		elif mood == &"enraged" or mood == &"desperate":
			hurry *= 1.15
		var arrived: bool = guard._walk(guard.chase_speed * hurry, delta)

		if arrived:
			guard._stop(delta)
			var look: Vector3 = to if sees else guard.last_known_position - guard.global_position
			guard._face(look, delta)

		return

	# Set on booting you into what is behind you: in to a kick's reach.
	var booting: bool = not waiting and guard._game_time < _boot_until

	if booting:
		want = minf(want, maxf(_reach(&"kick") - 0.3, 0.9))

	# Footwork you have to read: between blows he drifts in and out of the
	# edge of your reach (spacing), never quite where you left him.
	if spacing > 0.0 and not waiting and not booting and (place == &"engage" or place == &"breaker") and mood == &"steady":
		_space_phase += delta * _space_rate

		if _space_phase > TAU:
			_space_phase -= TAU
			_space_rate = randf_range(1.0, 1.7)

		want = maxf(want + spacing * sin(_space_phase), 1.0)

	# In the ring: square up, hold the distance; now and then a step aside.
	# Waiting his turn he goes to his own place at your side or back, so a man
	# who stands still is surrounded.
	var toward := to / maxf(dist, 0.001)
	var radial := clampf((dist - want) * 3.0, -2.2, 2.6)
	var side := Vector3.UP.cross(toward) * _strafe * strafe_speed * (1.0 if _reposition > 0.0 else 0.0)
	var slow := 0.5 if guarding else 1.0
	var wanted: Vector3 = (toward * radial + side) * slow + guard._nav.crowd() * 0.8

	if waiting:
		var slot := _flank_slot(target, want)

		if squad != null and (place == &"flank" or place == &"reserve"):
			slot = _squad_slot(target, want)

		var to_slot := slot - guard.global_position
		to_slot.y = 0.0

		if to_slot.length() > 0.3:
			wanted = to_slot.normalized() * minf(to_slot.length() * 3.0, strafe_speed * 2.4 * (1.0 + maxf(_dg(), 0.0)))

	if wanted.length() > 0.05 and not _safe_step(wanted):
		_strafe = -_strafe
		wanted = toward * radial * slow

		if not _safe_step(wanted):
			wanted = Vector3.ZERO

	var flat := Vector3(guard.velocity.x, 0.0, guard.velocity.z).move_toward(wanted, guard.acceleration * delta)
	guard.velocity.x = flat.x
	guard.velocity.z = flat.z
	guard._face(to, delta)


## Where he waits for his turn: out to your side or behind you, each of the
## waiting ones his own place, as you face now.
func _flank_slot(target: Node3D, want: float) -> Vector3:
	var waiting: Array = []

	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		var fighter: Variant = other.get("_fighter")

		if fighter == null or other.get("_target") != target or int(other.state) != COMBAT:
			continue

		if fighter.ranged or fighter.stays_put or fighter._hold_token:
			continue

		waiting.append(other)

	waiting.sort_custom(func(a: Node, b: Node) -> bool: return a.get_instance_id() < b.get_instance_id())
	var places := [100.0, -100.0, 180.0, 145.0, -145.0, 60.0, -60.0]
	var index := waiting.find(guard)
	var angle := deg_to_rad(places[index % places.size()] if index >= 0 else 100.0)
	var facing: Vector3 = -target.global_basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	return target.global_position + facing.rotated(Vector3.UP, angle) * want


## His place in the plan round you: the angle it gives him from where you
## face, at `want`.
func _squad_slot(target: Node3D, want: float) -> Vector3:
	var facing: Vector3 = -target.global_basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	return target.global_position + facing.rotated(Vector3.UP, deg_to_rad(squad.slot_angle(guard))) * want


## Broken and running: to the nearest of his own he would be safe with, and
## behind them (GuardMercy.run_to_haven); with nobody to run to, away from
## you, far enough to be out of it, then turned to watch you from there.
func _flee(delta: float, target: Node3D, sees: bool, to: Vector3) -> void:
	guarding = false

	if target == null or not is_instance_valid(target):
		guard._stop(delta)
		return

	# Broken and away, and no sight of you for a good while: he gives it up.
	_fled_unseen = 0.0 if sees else _fled_unseen + delta

	if _fled_unseen > 12.0 and squad != null and squad.will_of(guard) == &"broken":
		_fled_unseen = 0.0
		guard._give_up()
		return

	# Not just away: to his own, where he would be safe (GuardMercy.gd).
	if guard._mercy.run_to_haven(delta, target, sees, to):
		return

	var away: Vector3 = guard.global_position - target.global_position
	away.y = 0.0
	var far := away.length()
	away = away.normalized() if far > 0.01 else guard.global_basis.z

	if far < 14.0:
		guard._go_to(guard.global_position + away * 6.0)

		if guard._walk(guard.chase_speed * 1.1, delta):
			guard._stop(delta)

		if guard._bark_timer <= 0.0 and randf() < delta * 0.5:
			guard.bark("Help! Over here!")
			guard.shout()
	else:
		guard._stop(delta)

		if sees:
			guard._face(to, delta)


## Running for help: to the man he is fetching, crying out as he goes, a
## shout when he is near enough to be heard; on him, he rouses him to the
## hunt (Squad.rouse).
func _fetch(delta: float, target: Node3D, sees: bool, to: Vector3) -> void:
	guarding = false
	var helper: Node3D = squad.helper_of(guard) if squad != null else null

	if helper == null:
		guard._stop(delta)

		if sees:
			guard._face(to, delta)

		return

	guard._go_to(helper.global_position)
	var arrived: bool = guard._walk(guard.chase_speed * 1.1, delta)
	var gap: float = guard.global_position.distance_to(helper.global_position)

	# Getting no nearer (stuck, or the man where no path goes): a fresh path
	# once, and if that does not bring him closer he gives that man up.
	if gap < _fetch_best - 0.3:
		_fetch_best = gap
		_fetch_stalled = 0.0
	else:
		_fetch_stalled += delta

	if arrived and gap > 2.5 and not _fetch_repathed:
		_fetch_repathed = true
		guard._go_to(helper.global_position, true)

	if _fetch_stalled > FETCH_STALL:
		squad.abandon_fetch(guard, helper)
		_fetch_best = INF
		_fetch_stalled = 0.0
		_fetch_repathed = false
		guard._stop(delta)
		return

	if gap <= 12.0 and not _shouted_for_help:
		_shouted_for_help = true
		guard.shout()

	_fetch_call -= delta

	if _fetch_call <= 0.0 and guard._bark_timer <= 0.0:
		_fetch_call = 3.0
		var said: String = temper.line(&"fetch") if temper != null else ""
		guard.bark(said if said != "" else "Help! Over here!")

	if gap <= 2.5:
		_shouted_for_help = false
		squad.rouse(helper, guard)


## Holding you off alone: now and then a call for help, loud enough to carry.
func _call_for_help(delta: float) -> void:
	_help_call -= delta

	if _help_call > 0.0 or guard._bark_timer > 0.0:
		return

	_help_call = 6.0
	var said: String = temper.line(&"hold") if temper != null else ""
	guard.bark(said if said != "" else "Help! Over here!")
	guard.shout()


## Falling back: to the leader's side, close together, guard up. True while
## he is on his way or holding there.
func _rally(delta: float, target: Node3D, sees: bool, to: Vector3, dist: float) -> bool:
	if sees and dist < _reach(&"overhead"):
		# You came to him: he fights.
		return false

	var point: Vector3 = squad.rally_point()
	var ring := float(guard.get_instance_id() % 6) / 6.0 * TAU
	point += Vector3(cos(ring), 0.0, sin(ring)) * 1.3
	var off := Vector2(point.x - guard.global_position.x, point.z - guard.global_position.z).length()

	if off > 0.8:
		guard._go_to(point)
		guard._walk(guard.chase_speed, delta)
	else:
		guard._stop(delta)

	if sees:
		guard._face(to, delta)

	guarding = sees and dist < 5.0 and _broken <= 0.0 and guard._hands.armed
	return true


## Between you and the archer you are going for. True while he is getting
## there; once there he fights you as anyone would.
func _stand_guard(delta: float, target: Node3D, sees: bool, to: Vector3, dist: float) -> bool:
	var archer: Node3D = null
	var nearest := INF

	for member in squad.fighting():
		if member != guard and member.get("_fighter") != null and member._fighter.ranged:
			var d: float = member.global_position.distance_to(target.global_position)

			if d < nearest:
				nearest = d
				archer = member

	if archer == null or (sees and dist < _reach(&"overhead") + 0.6):
		return false

	var between: Vector3 = target.global_position - archer.global_position
	between.y = 0.0
	var point: Vector3 = archer.global_position + (between.normalized() if between.length() > 0.01 else Vector3.FORWARD) * minf(1.8, between.length() * 0.5)
	var off := Vector2(point.x - guard.global_position.x, point.z - guard.global_position.z).length()

	if off < 0.6:
		return false

	guard._go_to(point)
	guard._walk(guard.chase_speed * 1.1, delta)

	if sees:
		guard._face(to, delta)

	if guard._bark_timer <= 0.0 and randf() < delta * 0.4:
		guard.bark("Keep off him!")

	return true


## Where he runs to after you: where you will be, if he can see you running
## (GuardNav.lead); where he last had you (seen, or called by his own) if not;
## and, there and still nothing, a few steps on the way you went.
func _chase_point(target: Node3D, sees: bool, dist: float) -> Vector3:
	if sees:
		_scented = false
		_scent_from = Vector3.INF
		return guard._nav.lead(target, guard._feet_of(target), dist, guard.chase_speed)

	var lost_at: Vector3 = guard.last_known_position

	# Word of you somewhere else: after that, not the old trail.
	if _scented and _scent_from.distance_to(lost_at) > 2.0:
		_scented = false

	if not _scented and guard._flat_distance(lost_at) < 1.2:
		_scented = true
		_scent_from = lost_at
		_scent_point = guard._nav.scent(lost_at, guard._seen_heading)

	return _scent_point if _scented else lost_at


## Twice a second: whether you are where his feet cannot take him (too high or
## low, or no path gets there).
func _update_reach(delta: float, target: Node3D, level: float) -> void:
	_reach_check -= delta

	if _reach_check > 0.0:
		return

	_reach_check = 0.5

	if level > guard.attack_reach_height + 0.2:
		_unreachable = true
		return

	var feet: Vector3 = guard._feet_of(target)
	var map: RID = guard.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, guard.global_position, feet, true)

	if path.is_empty():
		_unreachable = true
		return

	var end: Vector3 = path[path.size() - 1]
	_unreachable = Vector2(end.x - feet.x, end.z - feet.z).length() > 1.6 or absf(end.y - feet.y) > guard.attack_reach_height


func is_unreachable() -> bool:
	return _unreachable


## Where you are, called to the others of the hunt who cannot see you (at most
## every SPOT_EVERY for the squad, sooner when one of them is about to give
## you up for lost): they come to it. A lookout calls it every SPOT_EVERY
## whoever else sees you.
func _call_out_where(delta: float, target: Node3D) -> void:
	_spot_timer -= delta

	if _spot_timer > 0.0:
		return

	_spot_timer = 0.3
	var watching := role() == &"lookout"

	if squad == null:
		return

	if not watching:
		# Someone who cannot see you, near enough to be told; sooner if he is
		# about to give you up for lost.
		var blind := false
		var losing := false

		for member in squad.members():
			if member == guard or member.get("can_see_target") == true or member.global_position.distance_to(guard.global_position) >= 45.0:
				continue

			blind = true
			var unseen := minf(float(member.get("_since_seen")), float(member.get("_since_heard_of")))

			if unseen > float(member.get("lose_time")) - 1.5:
				losing = true

		if not blind or not squad.may_call(losing):
			return

	var feet: Vector3 = guard._feet_of(target)
	var going: Variant = target.get("velocity")
	Comms.call_out(guard, &"spotted", feet, {"heading": going if going is Vector3 else Vector3.ZERO})

	# Calling you out is a lookout's whole work: he says it over anything.
	if watching or guard._bark_timer <= 0.0:
		guard.bark(Comms.spotted_line(feet, guard))

	squad.called()

	if watching:
		_spot_timer = SPOT_EVERY


## His weapon gone: back for it (or any blade near he can use), unless you
## stand over it. You where he cannot reach, or he has no blade: something to
## throw at you. True while he is about it.
func _fetch_something(delta: float, target: Node3D, sees: bool, dist: float) -> bool:
	var hands: RefCounted = guard._hands

	if hands.busy():
		guard._stop(delta)
		return true

	# What he was going for, if it is still worth it: a blade while he has
	# none; a thing to throw while his blade cannot get to you (or he has
	# none) and his hands are empty; and nobody else's by now.
	if _fetching != null:
		var blade := is_instance_valid(_fetching) and _fetching.is_in_group(&"dropped_weapons")

		if not is_instance_valid(_fetching) or Dangers.claimed(_fetching, guard) or (blade and hands.armed) or (not blade and (hands.held != null or (hands.armed and not _unreachable))):
			if is_instance_valid(_fetching):
				Dangers.unclaim(_fetching, guard)

			_fetching = null

	_fetch_check -= delta

	if _fetching == null and _fetch_check <= 0.0:
		_fetch_check = 0.5

		if not hands.armed:
			_fetching = _blade_to_fetch(target)

		if _fetching == null and hands.held == null and sees and dist <= THROW_RANGE + 2.0 and (_unreachable or not hands.armed) and not ranged:
			_fetching = _thing_to_throw()

	if _fetching == null:
		return false

	var what: StringName = &"weapon" if _fetching.is_in_group(&"dropped_weapons") else &"throwable"

	# Close enough: down for it.
	if hands.can_reach(_fetching):
		guard._stop(delta)
		hands.stoop_for(_fetching, what)
		_fetching = null
		return true

	Dangers.claim(_fetching, guard)
	guard._go_to(_fetching.global_position)

	if guard._walk(guard.chase_speed, delta):
		# As near as he can get and still out of reach (on a table, a ledge):
		# not that one.
		Dangers.unclaim(_fetching, guard)
		_gave_up_on[_fetching] = true
		_fetching = null
		return false

	return true


## A blade he can fight with lying near, that he can get to, and that you
## are not standing over.
func _blade_to_fetch(target: Node3D) -> Node3D:
	var feet: Vector3 = guard._feet_of(target) if target != null and is_instance_valid(target) else Vector3.INF

	for blade in Dangers.weapons_near(guard.get_tree(), guard.global_position, 10.0, guard._hands.usable(), guard):
		if _gave_up_on.has(blade):
			continue

		var mine := guard.global_position.distance_to(blade.global_position)
		var yours := feet.distance_to(blade.global_position) if feet != Vector3.INF else INF

		# You standing over it (and nearer it than he is): not worth his life.
		if yours < 1.6 and yours < mine:
			continue

		if _can_walk_to(blade.global_position):
			return blade

	return null


## Something within a few steps to throw at you.
func _thing_to_throw() -> Node3D:
	for thing in Dangers.throwables_near(guard, guard.global_position, 7.0):
		if not _gave_up_on.has(thing) and _can_walk_to(thing.global_position):
			return thing

	return null


## A path gets him within reach of `point`.
func _can_walk_to(point: Vector3) -> bool:
	var map: RID = guard.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, guard.global_position, point, true)

	if path.size() < 2:
		return guard._flat_distance(point) < 2.0 and absf(point.y - guard.global_position.y) < 1.2

	var end: Vector3 = path[path.size() - 1]
	return Vector2(end.x - point.x, end.z - point.z).length() < 1.1 and point.y - end.y < 1.4 and end.y - point.y < 0.8


## Out of his reach: far enough back to see up onto where you stand (a little
## more than its height), facing you. True while he is about it; lost from
## sight, he gives it up to the chase (and so goes round to find a way).
func _hold_off(delta: float, target: Node3D, sees: bool, to: Vector3, dist: float) -> bool:
	if not sees or target == null or not is_instance_valid(target):
		return false

	var rise: float = absf(guard._feet_of(target).y - guard.global_position.y)
	var back := clampf(rise * 1.4 + 1.5, 3.0, 8.0)
	var toward := to / maxf(dist, 0.001)
	var wanted := Vector3.ZERO

	if dist < back - 0.4:
		wanted = -toward * minf((back - dist) * 3.0, 2.2)
	elif dist > back + 2.5:
		wanted = toward * minf((dist - back) * 2.0, guard.chase_speed)

	if wanted.length() > 0.05 and not _safe_step(wanted):
		wanted = Vector3.ZERO

	var flat := Vector3(guard.velocity.x, 0.0, guard.velocity.z).move_toward(wanted, guard.acceleration * delta)
	guard.velocity.x = flat.x
	guard.velocity.z = flat.z
	guard._face(to, delta)
	return true


## A lookout: to the bell first if one near can be rung (and he rings it,
## calling everyone to where he saw you); then back to his post, watching you
## and calling where you are. You come to him, he fights. True while he is
## about it.
func _keep_lookout(delta: float, sees: bool, to: Vector3, dist: float) -> bool:
	guarding = false

	if sees and dist < _reach(&"overhead") + 1.5:
		return false

	var bell: Node3D = Dangers.bell_near(guard.get_tree(), guard.global_position, 30.0)

	if bell != null:
		var rope: Vector3 = bell.rope_point()

		if guard._flat_distance(rope) > 0.9:
			guard._go_to(rope)
			guard._walk(guard.chase_speed, delta)
			return true

		guard._stop(delta)
		guard._face(bell.global_position - guard.global_position, delta)
		guard._hands.ring_bell(bell, guard.last_known_position)
		guard.say(&"bell")
		return true

	var post: Vector3 = guard._home.origin

	if guard._flat_distance(post) > 0.8:
		guard._go_to(post)
		guard._walk(guard.chase_speed * 0.8, delta)
	else:
		guard._stop(delta)

		if sees:
			guard._face(to, delta)

	return true


## Sent to cut you off (you running, another coming straight after you):
## where you are going, ahead of you. Near enough, he fights. True while he
## is about it.
func _intercept(delta: float, target: Node3D, sees: bool, dist: float) -> bool:
	if not sees or dist < _reach(&"lunge"):
		return false

	var going: Variant = target.get("velocity")
	var run := Vector3((going as Vector3).x, 0.0, (going as Vector3).z) if going is Vector3 else Vector3.ZERO

	if run.length() < 1.5:
		return false

	var feet: Vector3 = guard._feet_of(target)
	var ahead := feet + run.normalized() * clampf(dist * 0.9, 3.0, 10.0)
	var map: RID = guard.get_world_3d().navigation_map
	guard._go_to(NavigationServer3D.map_get_closest_point(map, ahead))
	guard._walk(guard.chase_speed * 1.1, delta)
	return true


## An archer's ground: far enough to draw in peace, near enough to hit.
## Too close and he backs off; out of sight or range and he comes on.
func _footwork_ranged(delta: float, target: Node3D, sees: bool, to: Vector3, dist: float, level: float) -> void:
	if not sees or dist > 22.0:
		guard._go_to(guard.last_known_position)

		if guard._walk(guard.chase_speed, delta):
			guard._stop(delta)

		if sees:
			guard._face(to, delta)

		return

	var toward := to / maxf(dist, 0.001)
	var radial := clampf((dist - keep_away) * 1.2, -3.0, 1.2)

	if dist < too_close:
		radial = -3.2

	var circling := _reposition > 0.0 or (strafe_speed > 0.0 and _someone_else_shooting(target))
	var way := _strafe

	# No clear line to you (a pillar, one of his own in the way): he works
	# round for one, the other way if that one does not open up.
	if strafe_speed > 0.0 and guard._hands.armed and not _clear_shot(target):
		_no_line += delta

		if _no_line > 1.6:
			_no_line = 0.0
			_line_side = -_line_side

		circling = true
		way = _line_side
	else:
		_no_line = 0.0

	var side := Vector3.UP.cross(toward) * way * strafe_speed * (1.3 if circling and way == _line_side else 1.0) * (1.0 if circling else 0.0)
	var wanted := toward * radial + side

	if wanted.length() > 0.05 and not _safe_step(wanted):
		_strafe = -_strafe
		wanted = toward * radial

		if not _safe_step(wanted):
			wanted = Vector3.ZERO

	var flat := Vector3(guard.velocity.x, 0.0, guard.velocity.z).move_toward(wanted, guard.acceleration * delta)
	guard.velocity.x = flat.x
	guard.velocity.z = flat.z
	guard._face(to, delta)


## A step that stays on the navmesh at this level: no backing off a ledge.
func _safe_step(velocity: Vector3) -> bool:
	var map: RID = guard.get_world_3d().navigation_map
	var probe: Vector3 = guard.global_position + velocity.normalized() * 0.7
	var closest := NavigationServer3D.map_get_closest_point(map, probe)
	return Vector2(closest.x - probe.x, closest.z - probe.z).length() < 0.3 and absf(closest.y - guard.global_position.y) < 0.45


func _start_dodge(target: Node3D, straight_back := false) -> void:
	var away: Vector3 = guard.global_position - target.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else guard.global_basis.z
	# Back and a little aside; a backstep just back, out of reach.
	var step := (away + Vector3.UP.cross(away) * _strafe * 0.6).normalized() * 4.8

	if straight_back:
		step = away * BACKSTEP_SPEED

	if not _safe_step(step):
		step = Vector3.UP.cross(away) * _strafe * 4.0

		if not _safe_step(step):
			return

	_dodge = 0.3
	_dodge_velocity = step
	guarding = false
	guard._rig.react_dodge(step)
	Sfx.play(guard, &"whoosh_light", guard.global_position + Vector3.UP, -4.0, 0.9)


func _update_dodge(delta: float) -> void:
	_dodge -= delta
	var k := clampf(_dodge / 0.3, 0.0, 1.0)
	guard.velocity.x = _dodge_velocity.x * k
	guard.velocity.z = _dodge_velocity.z * k

	var target: Node3D = guard._target

	if target != null and is_instance_valid(target):
		guard._face(target.global_position - guard.global_position, delta)


# ---------------------------------------------------------------------------
# Throwing blows
# ---------------------------------------------------------------------------

func _consider_attack(delta: float, target: Node3D, to: Vector3, dist: float, level: float) -> void:
	# You swung and met nothing: in, now, while you recover. Stepped out of it,
	# he lunges straight back in.
	var combat_now := _combat_of(target)
	var now: float = guard._game_time

	if combat_now != null and combat_now.has_method("whiffed") and combat_now.whiffed() and guard._stagger <= 0.0 and guard._knock <= 0.0 and _dodge <= 0.0:
		var set_on := now < _punish_until

		if set_on or randf() < read_skill * delta * 3.0:
			guard._attack_timer = 0.0
			_next_scale = minf(_next_scale, 0.75)

			if dist > _reach(&"overhead") and dist <= _reach(&"lunge") and _take_token(target):
				_punish_until = -1.0
				_start(&"lunge", 0.65)
				return

	if guard._attack_timer > 0.0 or guard._stagger > 0.0 or guard._knock > 0.0:
		return

	# Something in his hand to throw: at you, if his blade cannot get to you
	# (or he has none); let fall, if you have come to him and his blade can.
	if guard._hands.held != null:
		if not _unreachable and guard._hands.armed and dist < _reach(&"overhead") + 1.0:
			guard._hands.drop_held()
		else:
			if dist <= THROW_RANGE and dist >= 1.5 and _clear_shot(target) and _take_shot(target):
				_start(&"throw")
				guard.say(&"throw", 0.5)

			return

	if _parry_miss > 0.0 or _parry_at > 0.0 or level > guard.attack_reach_height:
		# Up where his blade cannot reach: he says what he thinks of that.
		if level > guard.attack_reach_height:
			_taunt(delta)

		return

	# Shaken, he waits for his balance to come back: he strikes to punish
	# (above), or to get you off him when you crowd him.
	if mood == &"shaken" and not _countering and dist > _reach(&"overhead"):
		return

	# A guard up against a blow still coming stays up; an answer waiting to
	# be given is given first. A counter goes in regardless.
	var combat := _combat_of(target)

	if guarding and not _countering and combat != null and combat.threat_phase() != &"":
		return

	var kind := _choose_attack()

	# An archer shoots from anywhere he can see you, and up close (at a sword's
	# length) kicks you off him. Better than you, if he sees it: the powder
	# beside you, or the rope of the weight hung over you.
	if ranged:
		if dist <= _reach(&"kick"):
			kind = &"kick"
		elif not guard._hands.armed:
			# His crossbow on the floor: nothing to shoot with.
			return
		else:
			_shot_point = Vector3.INF
			var mark := _environment_shot(target)

			if mark != Vector3.INF and _take_shot(target):
				_shot_point = mark
				_start(&"shoot")
			elif dist >= maxf(_reach(&"kick"), 2.0) and _clear_shot(target) and _take_shot(target):
				_start(&"shoot")

			return

	# Across a gap, or somewhere no path goes: nothing he can swing at.
	if _unreachable and dist > _reach(&"overhead"):
		_taunt(delta)
		return

	# From out of reach: a swordmaster leaps in, a brute charges.
	if not ranged and guard._hands.armed and dist > _reach(&"thrust") + 0.3 and (squad == null or squad.may_strike(guard)) and _in_view_of(target):
		if leap_chance > 0.0 and dist <= _reach(&"leap") and randf() < leap_chance * delta * 1.5 and _take_token(target):
			_start(&"leap", _next_scale)
			_next_scale = 1.0
			return

		if charge_chance > 0.0 and dist >= 3.0 and dist <= _reach(&"charge") and randf() < charge_chance * delta * 1.5 and _take_token(target):
			_start(&"charge", _next_scale)
			_next_scale = 1.0
			return

	# Out of reach and in the open: a lunge closes it at once.
	if dist > _reach(kind) and lunge_chance > 0.0 and guard._hands.armed and dist <= _reach(&"lunge") and dist > _reach(&"thrust") + 0.3 and (squad == null or squad.may_strike(guard)):
		if randf() < (lunge_chance + _plan(&"lunge")) * delta * 2.0 and _in_view_of(target) and _take_token(target):
			_start(&"lunge", _next_scale)
			_next_scale = 1.0
			return

	if dist > _reach(kind):
		return

	# The plan says when he may strike: a man waiting his turn does not; one
	# at your side or back does when you are busy with someone else, and is
	# let in beside whoever is already swinging.
	if squad != null and not squad.may_strike(guard):
		return

	# At your side and you busy with another: he punishes it, and is let in
	# beside whoever is swinging. (A rash man going in out of turn is not.)
	var punishing: bool = squad != null and role() == &"flank" and squad._committed_away_from(guard)

	# Behind you, he waits his turn a little longer.
	if not _in_view_of(target):
		_flank_wait += delta

		if _flank_wait < ((0.3 if temper != null and float(temper.guile) >= SquadScript.PATIENT_GUILE else 0.5) if punishing else 0.8):
			return
	else:
		_flank_wait = 0.0

	if not _take_token(target, 1 if punishing else 0):
		return

	if _combo_left <= 0:
		_combo_left = randi_range(0, maxi(combo_max - 1, 0))

		# On top of you, or with nothing to lose: longer strings.
		if mood in [&"pressing", &"desperate", &"enraged"] and combo_max > 1:
			_combo_left = randi_range(1, combo_max)

	_start(kind, _next_scale)
	_next_scale = 1.0


## Out of his reach: now and then he tells you what he thinks of it.
func _taunt(delta: float) -> void:
	_taunt_timer -= delta

	if _taunt_timer > 0.0:
		return

	_taunt_timer = randf_range(7.0, 12.0)
	guard.say(&"unreachable", 0.8)


func _choose_attack() -> StringName:
	# No blade in his hand: his fists and his boots.
	if not guard._hands.armed:
		if kick_chance > 0.0 and randf() < 0.3:
			return &"kick"

		return &"jab" if randf() < 0.45 else &"punch"

	# Your back to spikes, fire or a drop: the boot, to send you into it.
	if kick_chance > 0.0 and _booting():
		return &"kick"

	# Shaken and crowded: shove you off him.
	if mood == &"shaken" and randf() < 0.5:
		if _knows(&"bash"):
			return &"bash"

		if kick_chance > 0.0:
			return &"kick"

	# Against a man who hides behind his blade: the boot. The squad has seen
	# it too, and says so.
	var turtling: bool = _turtle > 0.6 or (squad != null and float(squad.read[&"turtle"]) > 0.5)

	if kick_chance > 0.0 and turtling and randf() < kick_chance + _plan(&"kick"):
		# A man who knows the pommel uses it: quicker than the boot.
		return &"bash" if _knows(&"bash") and randf() < 0.5 else &"kick"

	var total := 0.0

	for kind in attacks:
		total += _weight_of(kind)

	var pick := randf() * total

	for kind in attacks:
		pick -= _weight_of(kind)

		if pick <= 0.0:
			return kind

	return attacks.keys()[0] if not attacks.is_empty() else &"overhead"


## Whether he fights with this blow at all.
func _knows(kind: StringName) -> bool:
	if attacks.has(kind):
		return true

	for after in follow.values():
		if kind in (after as Array):
			return true

	return false


## What he follows `last` with: one of the blows he likes after it (or any),
## chosen by how the last went, the more so the better he reads a fight:
## caught on your guard, the blow that beats a guard; stepped out of, the one
## that reaches or goes low; landed, another quick one while you reel.
func _follow_up(last: StringName) -> StringName:
	var after: Array = follow.get(last, [])

	if after.is_empty():
		return _choose_attack()

	var weights: Array = []
	var total := 0.0

	for kind in after:
		var weight := 1.0 + read_skill * (_answer_weight(kind) - 1.0)
		weights.append(weight)
		total += weight

	var pick := randf() * total

	for i in range(after.size()):
		pick -= float(weights[i])

		if pick <= 0.0:
			return after[i]

	return after.back()


## How well `kind` answers the way his last blow went.
func _answer_weight(kind: StringName) -> float:
	var call: StringName = CALLS.get(kind, &"cut")

	match _outcome:
		&"blocked":
			if call == &"bash" or call == &"unblockable" or call == &"low":
				return 3.0

			return 2.0 if call == &"thrust" else 0.6
		&"dodged", &"missed":
			return 2.5 if kind in [&"thrust", &"lunge", &"sweep", &"leap"] else 0.8
		&"landed":
			return 1.8 if kind in [&"left", &"right", &"jab", &"punch"] else 1.0

	return 1.0


## Of the blows he follows `kind` with, the one that beats a raised guard
## (a pommel, a boot, a blow no guard holds, one under it, a point): "" if he
## has none.
func _guard_breaker_after(kind: StringName) -> StringName:
	var best: StringName = &""
	var best_rank := 0

	for after in follow.get(kind, []):
		var rank: int = {&"bash": 4, &"unblockable": 4, &"low": 3, &"thrust": 2}.get(CALLS.get(after, &"cut"), 0)

		if rank > best_rank or (rank == best_rank and rank > 0 and randf() < 0.5):
			best_rank = rank
			best = after

	return best


## Whether he means to boot you into what is behind you: weighed up now and
## then (not every time he looks for a blow, or he would always come to it),
## and once he means to, until he has, or it is no longer there.
func _booting() -> bool:
	var now: float = guard._game_time

	if not _hazard_behind_you():
		_boot_until = -10.0
		return false

	if now < _boot_until:
		return true

	if now - _boot_weighed < BOOT_EVERY:
		return false

	_boot_weighed = now

	if randf() < kick_chance + HAZARD_KICK:
		_boot_until = now + BOOT_TIME
		return true

	return false


## Spikes, fire, lit powder or a drop behind you, as he faces you (looked at
## a few times a second).
func _hazard_behind_you() -> bool:
	var now: float = guard._game_time

	if now - _hazard_checked_at < 0.4:
		return _hazard_there

	_hazard_checked_at = now
	var target: Node3D = guard._target

	if target == null or not is_instance_valid(target):
		_hazard_there = false
		return false

	var feet: Vector3 = guard._feet_of(target)
	_hazard_there = Dangers.behind(guard, feet, feet - guard.global_position) != &""
	return _hazard_there


## A better mark than you, beside you: powder near your feet (none of his own
## near it, and himself well clear), or the rope of a weight hung over you.
## INF if there is none he can hit.
func _environment_shot(target: Node3D) -> Vector3:
	var feet: Vector3 = guard._feet_of(target)
	var tree := guard.get_tree()

	for barrel in Dangers.powder_near(tree, feet, 2.6):
		var reach := Dangers.blast_reach(barrel)

		if guard.global_position.distance_to(barrel.global_position) < reach + 1.5 or _friend_within(barrel.global_position, reach + 0.5):
			continue

		var mark := barrel.global_position + Vector3.UP * 0.1

		if _clear_line(mark, barrel):
			return mark

	var weight: Node3D = Dangers.weight_over(tree, feet)

	if weight != null:
		var rope: Node3D = weight.get("rope")
		var load: Node3D = weight.get("body")

		if rope != null and is_instance_valid(rope) and load != null and not _friend_within(Vector3(load.global_position.x, feet.y, load.global_position.z), 1.2):
			if _clear_line(rope.global_position, rope):
				return rope.global_position

	return Vector3.INF


## One of his own (not himself) within `reach` of `point`.
func _friend_within(point: Vector3, reach: float) -> bool:
	for other in guard.get_tree().get_nodes_in_group(&"guards"):
		if other != guard and (other as Node3D).global_position.distance_to(point) < reach:
			return true

	return false


## Nothing solid (nor one of his own) between his eye and `point`, but `thing`
## itself.
func _clear_line(point: Vector3, thing: Object) -> bool:
	var exclude: Array[RID] = [guard.get_rid()]

	if thing is CollisionObject3D:
		exclude.append((thing as CollisionObject3D).get_rid())

	var query := PhysicsRayQueryParameters3D.create(guard.eye_position(), point, 1 | 2, exclude)
	return guard.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## How likely a blow is: less so the same one again; the blow nothing stops,
## much more so when he is sent to break your guard, or has nothing to lose.
## Hurt, he keeps to quick ones that leave him least open. Against a man they
## know dodges, the blows that reach and go low; against one who parries
## everything, the ones no parry is for.
func _weight_of(kind: StringName) -> float:
	var weight := float(attacks[kind]) * (0.25 if kind == _last_attack and _repeats >= 1 else 1.0)
	var call: StringName = CALLS.get(kind, &"cut")

	if kind in [&"thrust", &"lunge", &"sweep", &"leap"]:
		weight *= 1.0 + _plan(&"track")

	if call == &"unblockable" or call == &"low" or call == &"thrust":
		weight *= 1.0 + _plan(&"perilous")

	if kind == &"heavy" and (role() == &"breaker" or role() == &"berserk"):
		weight *= 3.0

	match mood:
		&"desperate", &"enraged":
			if call == &"unblockable" or call == &"low":
				weight *= 2.0
		&"hurt":
			if kind == &"heavy" or kind == &"sweep":
				weight *= 0.4

	return weight


func _update_mood(delta: float, target: Node3D) -> void:
	_mood_timer -= delta
	_shaken_rest = maxf(_shaken_rest - delta, 0.0)

	if mood == &"shaken":
		_shaken_for += delta

		# Enough backing off: he gathers himself and comes again.
		if _shaken_for >= SHAKEN_MAX:
			_shaken_rest = SHAKEN_REST
			_mood_timer = 0.0

	if _mood_timer > 0.0:
		return

	_mood_timer = 0.25
	var was := mood
	mood = _judge_mood(target)

	if mood != &"shaken":
		_shaken_for = 0.0

	if mood != was:
		_on_mood(was)


func _judge_mood(target: Node3D) -> StringName:
	var whole: float = clampf(float(guard.health) / maxf(float(guard.max_health), 1.0), 0.0, 1.0)
	var shaken: float = posture / maxf(posture_max, 1.0) if posture_max < 9999.0 else 0.0

	# Broken, and rash: all in, whatever else.
	if role() == &"desperate" and not is_open():
		return &"desperate"

	# His balance going (and it comes and goes: a margin either way), for a
	# short spell at a time.
	if not is_open() and not ranged and _shaken_rest <= 0.0 and (shaken >= SHAKEN_AT or (mood == &"shaken" and shaken > SHAKEN_UNTIL)):
		return &"shaken"

	if whole < 0.35:
		if hyper_armor:
			return &"enraged"

		var friends: int = squad.fighting().size() if squad != null else 1
		# Alone and badly cut, a rash man goes all in; anyone else is careful.
		return &"desperate" if friends <= 1 and not ranged and drive_now() >= SquadScript.DESPERATE_DRIVE else &"hurt"

	var yours: Variant = target.get("health") if target != null and is_instance_valid(target) else null
	var most: Variant = target.get("max_health") if target != null and is_instance_valid(target) else null
	var combat := _combat_of(target)
	var winded: bool = combat != null and float(combat.get("stamina")) < 15.0

	if (yours != null and most != null and float(yours) < float(most) * 0.35) or winded:
		return &"pressing"

	return &"steady"


## His mood changed: he says so.
func _on_mood(_was: StringName) -> void:
	var lines: Array = []

	match mood:
		&"shaken":
			lines = ["Hold... hold.", "Steady...", "Back, back!"]
		&"hurt":
			lines = ["I'm cut!", "Help me!", "Get him off me!"]
			_call_in()
		&"enraged":
			lines = ["RAAAGH!", "I'll break you!"]
			guard.voice(&"roar", 4.0)
		&"pressing":
			lines = ["He's finished!", "Finish him!", "He's done!"]
		&"desperate":
			lines = ["Come on, then!", "Die, damn you!"]

	if not lines.is_empty() and guard._bark_timer <= 0.0:
		guard.bark(lines[randi() % lines.size()])


func _start(kind: StringName, scale := 1.0) -> void:
	# Berserk or enraged: quicker, and no feints about it.
	if role() == &"berserk" or mood == &"enraged":
		scale *= 0.8
	elif role() == &"desperate":
		scale *= 0.85

	if kind == _last_attack:
		_repeats += 1
	else:
		_repeats = 0

	_last_attack = kind
	guard._attack = kind
	guard._phase = &"windup"
	_flank_waited = 0.0
	_countering = false
	_parry_at = -1.0
	_parry_open_at = -1.0

	if kind == &"kick":
		_turtle = 0.0
		_boot_until = -10.0

	var windup: float = KICK_WINDUP if kind == &"kick" else (BASH_WINDUP if kind == &"bash" else guard.windup_time * float(ATTACKS[kind]["windup"]))

	if kind == &"shoot":
		windup = draw_time

	if kind == &"throw":
		windup = THROW_WINDUP

	_aim_locked = false

	# No steady beat: a blow comes early or late (never a kick's rear-back).
	if timing_variance > 0.0 and kind != &"kick" and kind != &"bash" and kind != &"shoot" and kind != &"throw":
		windup *= randf_range(1.0 - timing_variance * 0.35, 1.0 + timing_variance)

	guard._phase_length = windup * scale
	guard._phase_timer = guard._phase_length
	guarding = false
	_answer = &""
	_feint_at = -1.0

	# A feint: only the first blow of a string, and never a kick or a slam.
	if kind in [&"overhead", &"left", &"right", &"thrust"] and scale >= 0.99 and feint_chance > 0.0 and randf() < feint_chance + _plan(&"feint") + _feint_bias():
		_feint_at = randf_range(0.36, 0.52)

	var target: Node3D = guard._target

	if target != null and is_instance_valid(target) and target.has_method("warn_attack"):
		target.warn_attack(guard)


## 0..1 through the current phase.
func progress() -> float:
	var length: float = guard._phase_length if guard._phase_length > 0.0 else guard.windup_time
	return 1.0 - clampf(guard._phase_timer / maxf(length, 0.01), 0.0, 1.0)


## His blade is let go (past the glint, COMMITTED): it comes whatever you do.
## Not a shot or a throw, which a cut still spoils.
func committed() -> bool:
	return guard._phase == &"windup" and progress() >= COMMITTED and not (guard._attack in [&"shoot", &"throw"])


func _update_attack(delta: float, target: Node3D, sees: bool, to: Vector3, dist: float, level: float) -> void:
	var phase: StringName = guard._phase
	var u := progress()
	var kind: StringName = guard._attack

	guard._stop(delta)
	var forward: Vector3 = -guard.global_basis.z

	# Down it comes: a lunge into the blow.
	if phase == &"windup" and u > 0.78 and kind in [&"overhead", &"thrust", &"heavy"] and not stays_put:
		guard.velocity.x = forward.x * 1.6
		guard.velocity.z = forward.z * 1.6

	# A step in on the way up, if you are further than the blow reaches: his
	# blows cover the ground they need to.
	if phase == &"windup" and u > 0.3 and sees and not stays_put and kind in [&"left", &"right", &"overhead", &"sweep", &"bash", &"kick", &"thrust", &"punch", &"jab"]:
		var short := dist - (_reach(kind) - 0.35)

		if short > 0.0 and _safe_step(forward):
			var step := clampf(short * 3.0, 0.0, 2.8)
			guard.velocity.x = forward.x * step
			guard.velocity.z = forward.z * step

	# A charge: head down and at you, a leap: up and in.
	if (kind == &"charge" and (phase == &"windup" and u > 0.55 or phase == &"strike")) or (kind == &"leap" and (phase == &"windup" and u > 0.4 or phase == &"strike")):
		var room := dist - 1.1 if sees else 1.0
		var speed := 8.5 if kind == &"charge" else 6.0

		if room > 0.0 and _safe_step(forward):
			guard.velocity.x = forward.x * speed
			guard.velocity.z = forward.z * speed

	# A lunge: crouched and gathered, then driven in at you, stopping short.
	if kind == &"lunge" and not stays_put and (phase == &"windup" and u > 0.55 or phase == &"strike"):
		var ahead: Vector3 = -guard.global_basis.z
		var room := dist - 1.0 if sees else 1.0

		if room > 0.0 and _safe_step(ahead):
			guard.velocity.x = ahead.x * 7.5
			guard.velocity.z = ahead.z * 7.5

	# He tracks you on the way up; once the blade falls it is committed, and a
	# step aside can take you out of its path.
	if sees:
		var locked := 0.9 if kind == &"shoot" else (0.85 if kind == &"throw" else 0.78)
		var tracking := 1.0 if phase == &"windup" and u < locked else 0.22
		var facing := to

		# A shot at powder or a rope: he faces his mark.
		if kind == &"shoot" and _shot_point != Vector3.INF:
			facing = _shot_point - guard.global_position

		guard._face(facing, delta, tracking)

		# His aim set a moment before he looses: where you will be if you keep
		# going as you are (step out of it at the last and it goes past).
		if kind == &"shoot" and phase == &"windup" and u >= locked and not _aim_locked:
			_aim_locked = true
			_locked_aim = target.global_position + Vector3.UP * 0.25
			var going: Variant = target.get("velocity")

			if going is Vector3:
				var flight: float = guard.eye_position().distance_to(_locked_aim) / maxf(shot_speed, 1.0)
				_locked_aim += Vector3((going as Vector3).x, 0.0, (going as Vector3).z) * flight * 0.8

	guard._phase_timer -= delta

	if phase == &"windup" and _feint_at > 0.0 and u >= _feint_at:
		_feint()
		return

	if guard._phase_timer > 0.0:
		return

	match phase:
		&"windup":
			# Set before striking: a parry during the strike resets it.
			guard._phase = &"strike"
			guard._phase_length = guard.strike_time
			guard._phase_timer = guard.strike_time
			_strike(target)
		&"strike":
			if _combo_left > 0 and sees and dist <= _reach(&"overhead") + 0.4 and guard._stagger <= 0.0:
				_combo_left -= 1
				# What he follows this blow with; now and then held back, late,
				# to catch a parry thrown too soon (the more against a man
				# known to parry).
				_late = randf() < delay_chance + (_plan(&"delay") if delay_chance > 0.0 else 0.0)
				_start(_follow_up(kind), 1.35 if _late else 0.72)
			else:
				_combo_left = 0
				guard._phase = &"recover"
				guard._phase_length = guard.recover_time * float(ATTACKS.get(kind, ATTACKS[&"overhead"])["recover"])
				guard._phase_timer = guard._phase_length
		&"recover":
			guard._phase = &""
			guard._attack_timer = guard.attack_cooldown * randf_range(0.8, 1.25) * _cooldown_scale()
			release_token()
			_hold_shot = false


## Up it went, and back it comes: no blow. A parry spent on it is wasted.
func _feint() -> void:
	_feint_at = -1.0
	_combo_left = 0
	guard._phase = &""
	guard._attack_timer = 0.12
	_next_scale = 0.82
	Sfx.play(guard, &"whoosh_light", guard.eye_position(), -8.0, 1.2)

	if guard.has_signal(&"feinted"):
		guard.emit_signal(&"feinted")


func _reach(kind: StringName) -> float:
	if kind == &"kick" and kick_range > 0.0:
		return kick_range

	if kind == &"throw":
		return THROW_RANGE

	return guard.attack_range + float(ATTACKS.get(kind, ATTACKS[&"overhead"])["reach"])


## How far the blow reaches as it lands: a lunge, a leap or a charge has
## already covered the ground, and only the blade's own length is left. Back
## away from one as it comes and it falls short.
func _hit_reach(kind: StringName) -> float:
	if kind in [&"lunge", &"charge", &"leap"]:
		return guard.attack_range + 0.45

	return _reach(kind)


## What his blow is, for whoever it lands on: a raised guard reads this to
## know what catching it costs.
func attack_info() -> Dictionary:
	var kind: StringName = guard._attack if guard._attack != &"" else &"overhead"
	var a: Dictionary = ATTACKS.get(kind, ATTACKS[&"overhead"])
	var call: StringName = CALLS.get(kind, &"cut")
	return {
		"type": kind,
		"call": call,
		"guard_damage": guard_damage * float(a["guard"]),
		# Through any guard, with a shove: a boot, a pommel, the great blow,
		# a charge.
		"unblockable": call == &"unblockable" or call == &"bash",
		"heavy": kind == &"heavy" or kind == &"charge",
		# Under any guard: at your legs.
		"low": call == &"low",
		# Partly through a guard: a point driven at you.
		"thrust": call == &"thrust",
		"ranged": kind == &"shoot" or kind == &"throw",
	}


## The blow lands on whoever is in front of him, in reach, at his level.
func _strike(target: Node3D) -> void:
	var kind: StringName = guard._attack
	var a: Dictionary = ATTACKS.get(kind, ATTACKS[&"overhead"])

	if kind == &"heavy":
		_slam()

	if kind == &"shoot":
		_shoot(target)
		return

	if kind == &"throw":
		_throw_at(target)
		return

	if target == null or not is_instance_valid(target):
		_landed = false
		return

	var feet: Vector3 = guard._feet_of(target)
	var to := Vector3(feet.x - guard.global_position.x, 0.0, feet.z - guard.global_position.z)
	var facing: Vector3 = -guard.global_transform.basis.z
	_landed = false

	var near: bool = to.length() <= _hit_reach(kind) + 0.3
	var in_reach: bool = near and absf(feet.y - guard.global_position.y) <= guard.attack_reach_height
	var in_arc: bool = to.length() <= 0.05 or facing.dot(to.normalized()) >= cos(deg_to_rad(float(a["arc"]) * 0.5))
	var combat := _combat_of(target)
	var airborne: bool = target is CharacterBody3D and not (target as CharacterBody3D).is_on_floor()

	# Low at your legs: over it you go, and he is left with nothing.
	if kind == &"sweep" and near and in_arc and airborne and feet.y - guard.global_position.y > 0.15:
		_answered(&"jumped", target)
		return

	if not in_reach or not in_arc:
		_outcome = &"missed"

		# Out of it at the last moment: he is left overreaching. Out of a cut
		# (which asked for your blade) he only overreaches a little.
		if combat != null and combat.has_method("dodged_within") and combat.dodged_within(0.45) and to.length() < _hit_reach(kind) + 2.0:
			_outcome = &"dodged"

			if CALLS.get(kind, &"cut") == &"cut":
				add_posture(14.0)
			else:
				_answered(&"dodged", target)

		return

	_landed = true
	# (A raised guard in the way says otherwise: recover_from_block.)
	_outcome = &"landed"
	guard.caught_player.emit(target)

	# A boot or a fist lands with a thud (a blade's cut is yours to hear).
	if kind in [&"kick", &"punch", &"jab"]:
		Sfx.play(guard, &"kick", feet + Vector3.UP * (1.0 if kind == &"kick" else 1.5), 0.0 if kind == &"kick" else -3.0, 1.0 if kind == &"kick" else 1.2)

	var before: Variant = target.get("health")

	if target.has_method("take_damage"):
		target.take_damage(guard.attack_damage * float(a["damage"]), guard)

	# Only a blow that got through is worth crowing about.
	var hurt: bool = before != null and float(target.get("health")) < float(before)

	var blade: bool = not (kind in [&"kick", &"punch", &"jab"])

	if hurt and blade and guard._rig != null and guard._rig.has_method("bloody"):
		guard._rig.bloody(0.3)

	if hurt and guard._bark_timer <= 0.0 and blade:
		guard.bark("Got you!")


## Thrown at you: where you will be when it gets there, if you keep going
## as you are (GuardHands).
func _throw_at(target: Node3D) -> void:
	_landed = false

	if target == null or not is_instance_valid(target):
		guard._hands.drop_held()
		return

	var chest := target.global_position + Vector3.UP * 0.15
	var flight := clampf(guard.eye_position().distance_to(chest) / 12.0, 0.2, 1.3)
	var going: Variant = target.get("velocity")

	if going is Vector3:
		chest += Vector3((going as Vector3).x, 0.0, (going as Vector3).z) * flight * 0.6

	guard._hands.throw_held(chest, target)


## Loosed at you: from his eye, aimed at your chest with the drop allowed
## for, and a little of a man's unsteadiness. It hits whatever is in the way,
## his friends included. At powder or a rope when that is his mark.
func _shoot(target: Node3D) -> void:
	_landed = false

	if target == null or not is_instance_valid(target):
		return

	var from: Vector3 = guard.eye_position() - guard.global_basis.z * 0.5
	var chest: Vector3 = _locked_aim if _aim_locked else target.global_position + Vector3.UP * 0.25
	var spread := deg_to_rad(1.1)

	# A mark that is not you (a rope, a keg): still, and small, and he takes
	# his time over it.
	if _shot_point != Vector3.INF:
		chest = _shot_point
		_shot_point = Vector3.INF
		spread *= 0.3

	var distance := from.distance_to(chest)
	var flight := distance / maxf(shot_speed, 1.0)
	var aim := chest + Vector3.UP * 0.5 * 9.8 * flight * flight - from
	aim = aim.rotated(Vector3.UP, randf_range(-spread, spread))
	aim = aim.rotated(aim.cross(Vector3.UP).normalized(), randf_range(-spread, spread) * 0.6)
	var arrow: StaticBody3D = ArrowScript.new()
	guard.get_parent().add_child(arrow)
	arrow.launch(from, aim.normalized() * shot_speed, guard.attack_damage, guard, 1.5)
	Sfx.play(guard, &"twang", from, 0.0, randf_range(0.95, 1.05))
	SoundBus.emit_sound(from, 42.0, guard, &"twang")


## Nothing solid between his eye and your chest.
func _clear_shot(target: Node3D) -> bool:
	var from: Vector3 = guard.eye_position()
	var to: Vector3 = target.global_position + Vector3.UP * 0.25
	var exclude: Array[RID] = [guard.get_rid()]

	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())

	# Not through a wall, and not through one of his own.
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, exclude)
	return guard.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _take_shot(target: Node3D) -> bool:
	if _hold_shot:
		return true

	var key := target.get_instance_id()
	var list: Array = _shooters.get(key, [])
	list = list.filter(func(w: WeakRef) -> bool: return w.get_ref() != null and w.get_ref()._hold_shot)

	if list.size() >= max_shooters:
		_shooters[key] = list
		return false

	list.append(weakref(self))
	_shooters[key] = list
	_hold_shot = true
	return true


func _someone_else_shooting(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	for w in _shooters.get(target.get_instance_id(), []):
		var other: Variant = (w as WeakRef).get_ref()

		if other != null and other != self and other._hold_shot:
			return true

	return false


## A heavy blow meets the floor: dust, a thud, and the ground shakes near him.
func _slam() -> void:
	var at: Vector3 = guard.global_position - guard.global_basis.z * 1.4 + Vector3.UP * 0.05
	Fx.dust(guard, at, Vector3.UP, 1.2, "stone")
	Sfx.play(guard, &"thud", at, 2.0, 0.7)
	SoundBus.emit_sound(at, 58.0, guard, &"impact")
	var target: Node3D = guard._target

	if target != null and is_instance_valid(target) and target.get("juice") != null:
		var near: float = target.global_position.distance_to(at)

		if near < 5.0:
			target.juice.add_trauma(0.35 * (1.0 - near / 5.0))


# ---------------------------------------------------------------------------
# Taking turns
# ---------------------------------------------------------------------------

## How much sooner than usual he goes again: berserk much, an archer told to
## keep you from shooting somewhat.
func _cooldown_scale() -> float:
	# A man rasher than his kind rests less between blows; a warier one more.
	return _cooldown_base() * (1.0 - 0.5 * _dd())


func _cooldown_base() -> float:
	if role() == &"berserk":
		return 0.5

	if ranged and squad != null and squad.tactic == &"rush":
		return 0.7

	match mood:
		&"hurt":
			return 1.5
		&"pressing":
			return 0.7
		&"desperate", &"enraged":
			return 0.6

	return 1.0


## A turn to swing at `target`: as many may as the plan allows (`extra` more
## for a man punishing you at your side or back).
func _take_token(target: Node3D, extra := 0) -> bool:
	if _hold_token:
		return true

	var key := target.get_instance_id()
	var list: Array = _holders.get(key, [])
	list = list.filter(func(w: WeakRef) -> bool: return w.get_ref() != null and w.get_ref()._hold_token)
	var cap := maxi(max_attackers, squad.attackers() if squad != null else 1) + extra

	if list.size() >= cap:
		_holders[key] = list
		return false

	list.append(weakref(self))
	_holders[key] = list
	_hold_token = true
	return true


func release_token() -> void:
	_hold_token = false
	_hold_shot = false


func _someone_else_swinging(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	for w in _holders.get(target.get_instance_id(), []):
		var other: Variant = (w as WeakRef).get_ref()

		if other != null and other != self and other._hold_token:
			return true

	return false


## In front of you, where you can see him coming.
func _in_view_of(target: Node3D) -> bool:
	var to: Vector3 = guard.global_position - target.global_position
	to.y = 0.0

	if to.length() < 0.01:
		return true

	return (-target.global_basis.z).dot(to.normalized()) > 0.2
