extends Node3D
## How a revenant moves: presentation only, on its own rig. It goes on four limbs, hauling itself along on arms too long for it, its knuckles on the floor and its left leg
## dragging under the weight of the crust; it gallops when it surges; it rears up from that to its whole height to bring its arms down on you. Every action is timed keys
## (POSES), and the weight goes through it: hips over what is planted, shoulder blades with the arm, its head always on you. `Revenant.gd` says what it is doing.

signal step_landed(side: int)
signal hand_landed(side: int)
## A blow of its whole weight has come down.
signal slammed

const MODEL := preload("res://assets/monsters/revenant.glb")
const RevenantLook := preload("res://scripts/Monsters/RevenantLook.gd")
const RevenantTrail := preload("res://scripts/Monsters/RevenantTrail.gd")
const FireShader := preload("res://scripts/Monsters/anima_fire.gdshader")
const FIRE_SHEET := "res://assets/vfx/fire.png"
const FLOOR_MASK := 1

## On four limbs: what it comes back to.
const ON_ALL_FOURS := {"lean": 0.62, "drop": 0.05, "head": 0.62, "jaw": 0.15, "plant_l": 1.0, "plant_r": 1.0, "shut": 0.5}
## What it is doing, as timed keys: each [seconds into it, values], eased, what a key leaves out carried from the one before. Anticipation, the blow, follow-through, in the
## times the brain gives each (Bestiary). lean: forward (rad), twist: its trunk round, its right shoulder back as it grows (rad), drop: its hips down (m), shift: over to its right
## (m), head: chin up (rad), jaw: open 0..1, shut: fingers closed (rad, on its rest), l/r: a wrist from where it hangs, in the body's x, y, z (m), reach_l/r: 0 that, 1 at you,
## plant_l/r: 1 on the floor, walking on it, limp: arms given up to the floor, wrath: the seep up in it 0..1.
## Over the clip: arms: how fast a free wrist may go (m/s), stiff: how quick it answers (Hz; low, they swing), follows: how quick its trunk follows the keys (Hz),
## stride: [seconds, side]: a foot driven forward under the blow, thud: seconds, when all its weight lands.
const POSES := {
	&"walk": {"arms": 5.0, "stiff": 2.0, "follows": 1.6, "keys": [[0.0, ON_ALL_FOURS]]},
	# Coiling: its weight back, its head down between its shoulders.
	&"surge_tell": {"arms": 5.0, "stiff": 3.0, "follows": 4.0, "keys": [
		[0.0, ON_ALL_FOURS],
		[0.5, {"lean": 0.78, "drop": 0.3, "shift": 0.0, "head": 0.8, "jaw": 0.85, "plant_l": 1.0, "plant_r": 1.0, "shut": 0.6, "wrath": 0.9}]]},
	&"surge": {"arms": 9.0, "stiff": 3.0, "follows": 4.0, "keys": [
		[0.0, {"lean": 0.78, "drop": 0.3, "head": 0.8, "jaw": 0.85, "plant_l": 1.0, "plant_r": 1.0, "shut": 0.6, "wrath": 0.9}],
		[0.25, {"lean": 0.86, "drop": 0.3, "head": 0.86, "jaw": 1.0, "wrath": 1.0}],
		[0.9, {"lean": 0.9, "drop": 0.32, "head": 0.9, "jaw": 1.0, "wrath": 0.7}]]},
	# A haymaker: it sinks; it comes up off its hands over its back leg, the arm going up behind it; then through, its weight following it down.
	&"swipe_wind": {"arms": 5.5, "stiff": 3.4, "follows": 4.5, "keys": [
		[0.0, ON_ALL_FOURS],
		[0.3, {"lean": 0.56, "twist": -0.14, "drop": 0.34, "shift": -0.04, "head": 0.54, "jaw": 0.2, "plant_l": 1.0, "plant_r": 0.5, "r": Vector3(0.05, 0.3, -0.25), "shut": 0.1, "wrath": 0.25}],
		[0.72, {"lean": 0.12, "twist": 0.5, "drop": 0.1, "shift": 0.08, "head": 0.22, "jaw": 0.6, "plant_l": 0.45, "plant_r": 0.0, "l": Vector3(-0.2, 0.3, -0.3), "r": Vector3(0.48, 0.92, 0.34), "shut": -0.55, "wrath": 0.7}],
		[0.94, {"lean": -0.08, "twist": 0.78, "drop": 0.04, "shift": 0.13, "head": 0.12, "jaw": 0.85, "plant_l": 0.0, "l": Vector3(-0.28, 0.42, -0.42), "r": Vector3(0.64, 1.3, 0.46), "shut": -0.8, "wrath": 1.0}],
		[1.0, {"lean": -0.1, "twist": 0.82, "drop": 0.03, "shift": 0.13, "head": 0.1, "jaw": 0.9, "plant_l": 0.0, "plant_r": 0.0, "l": Vector3(-0.28, 0.44, -0.44), "r": Vector3(0.66, 1.34, 0.48), "shut": -0.85, "wrath": 1.0}]]},
	&"swipe": {"arms": 13.0, "stiff": 7.0, "follows": 8.0, "stride": [0.04, 0], "thud": 0.2, "keys": [
		[0.0, {"lean": -0.1, "twist": 0.82, "drop": 0.03, "shift": 0.13, "head": 0.1, "jaw": 0.9, "plant_l": 0.0, "plant_r": 0.0, "l": Vector3(-0.28, 0.44, -0.44), "r": Vector3(0.66, 1.34, 0.48), "shut": -0.85, "wrath": 1.0}],
		[0.1, {"lean": 0.24, "twist": 0.1, "drop": 0.14, "shift": 0.02, "head": 0.3, "jaw": 1.0, "l": Vector3(-0.2, 0.2, 0.1), "r": Vector3(0.4, 1.0, -0.8), "shut": -0.2}],
		[0.2, {"lean": 0.62, "twist": -0.52, "drop": 0.34, "shift": -0.1, "head": 0.52, "jaw": 1.0, "plant_l": 0.6, "l": Vector3(-0.12, 0.1, 0.2), "r": Vector3(-0.42, 0.42, -1.1), "shut": 0.2}],
		[0.45, {"lean": 0.66, "twist": -0.74, "drop": 0.38, "shift": -0.14, "head": 0.56, "jaw": 0.7, "plant_l": 1.0, "r": Vector3(-0.94, 0.12, -0.64), "shut": 0.35, "wrath": 0.5}]]},
	# Up off all fours to all of its height, arms over its head; and down, all of it, as an animal brings its weight onto something.
	&"rake_wind": {"arms": 5.0, "stiff": 3.0, "follows": 4.0, "keys": [
		[0.0, ON_ALL_FOURS],
		[0.5, {"lean": 0.66, "drop": 0.5, "head": 0.66, "jaw": 0.5, "plant_l": 1.0, "plant_r": 1.0, "shut": 0.3, "wrath": 0.3}],
		[0.8, {"lean": 0.2, "drop": 0.2, "head": 0.3, "jaw": 0.8, "plant_l": 0.1, "plant_r": 0.1, "l": Vector3(-0.3, 0.7, 0.1), "r": Vector3(0.3, 0.75, 0.1), "shut": -0.4, "wrath": 0.55}],
		[1.14, {"lean": -0.36, "drop": -0.05, "head": 0.02, "jaw": 1.0, "plant_l": 0.0, "plant_r": 0.0, "l": Vector3(-0.42, 1.4, 0.04), "r": Vector3(0.42, 1.46, 0.04), "shut": -0.8, "wrath": 0.9}],
		[1.35, {"lean": -0.46, "drop": -0.08, "head": -0.04, "jaw": 1.0, "plant_l": 0.0, "plant_r": 0.0, "l": Vector3(-0.46, 1.54, 0.14), "r": Vector3(0.46, 1.6, 0.14), "shut": -0.9, "wrath": 1.0}]]},
	&"rake": {"arms": 13.0, "stiff": 6.5, "follows": 8.0, "stride": [0.03, 1], "thud": 0.3, "keys": [
		[0.0, {"lean": -0.46, "drop": -0.08, "head": -0.04, "jaw": 1.0, "plant_l": 0.0, "plant_r": 0.0, "l": Vector3(-0.46, 1.54, 0.14), "r": Vector3(0.46, 1.6, 0.14), "shut": -0.9, "wrath": 1.0}],
		[0.14, {"lean": 0.26, "drop": 0.16, "head": 0.34, "jaw": 1.0, "l": Vector3(-0.32, 1.0, -0.84), "r": Vector3(0.32, 1.05, -0.84), "shut": -0.3}],
		[0.3, {"lean": 0.94, "drop": 0.5, "head": 0.8, "jaw": 1.0, "plant_l": 0.5, "plant_r": 0.5, "l": Vector3(-0.2, 0.2, -1.0), "r": Vector3(0.2, 0.24, -1.0), "shut": 0.35}],
		[0.6, {"lean": 0.86, "drop": 0.52, "head": 0.8, "jaw": 0.6, "plant_l": 1.0, "plant_r": 1.0, "shut": 0.55, "wrath": 0.5}]]},
	# Unlike the others: it stays down. Quiet, low, one long arm coming up off the floor at you, the fingers opening. You learn to dread this one.
	&"grasp_wind": {"arms": 3.6, "stiff": 2.4, "follows": 3.0, "keys": [
		[0.0, ON_ALL_FOURS],
		[0.5, {"lean": 0.54, "twist": 0.18, "drop": 0.3, "shift": 0.05, "head": 0.58, "jaw": 0.15, "plant_l": 1.0, "plant_r": 0.0, "reach_r": 0.26, "shut": -0.5, "wrath": 0.4}],
		[1.4, {"lean": 0.66, "twist": 0.36, "drop": 0.4, "shift": 0.08, "head": 0.7, "jaw": 0.3, "plant_l": 1.0, "plant_r": 0.0, "reach_r": 0.6, "shut": -1.05, "wrath": 1.0}]]},
	&"grasp": {"arms": 13.0, "stiff": 7.5, "follows": 7.0, "stride": [0.0, 1], "keys": [
		[0.0, {"lean": 0.66, "twist": 0.36, "drop": 0.4, "head": 0.7, "jaw": 0.3, "plant_l": 1.0, "plant_r": 0.0, "reach_r": 0.6, "shut": -1.05, "wrath": 1.0}],
		[0.14, {"lean": 0.86, "twist": -0.3, "drop": 0.22, "head": 0.8, "jaw": 1.0, "reach_r": 1.0, "shut": -0.6}],
		[0.5, {"lean": 0.7, "twist": -0.14, "drop": 0.28, "head": 0.66, "jaw": 0.6, "plant_r": 0.4, "reach_r": 0.4, "shut": 0.25, "wrath": 0.5}]]},
	&"hold": {"arms": 8.0, "stiff": 6.0, "follows": 4.0, "keys": [
		[0.0, {"lean": 0.86, "twist": -0.3, "drop": 0.22, "head": 0.8, "jaw": 1.0, "plant_l": 1.0, "plant_r": 0.0, "reach_r": 1.0, "shut": -0.3, "wrath": 1.0}],
		[0.3, {"lean": 0.5, "twist": -0.1, "drop": 0.14, "head": 0.5, "jaw": 1.0, "plant_l": 0.0, "reach_r": 1.0, "reach_l": 0.9, "shut": 0.35}],
		[1.0, {"lean": 0.36, "twist": 0.1, "drop": 0.1, "head": 0.4, "jaw": 1.0, "plant_l": 0.0, "reach_r": 1.0, "reach_l": 1.0, "shut": 0.4}]]},
	&"shove": {"arms": 11.0, "stiff": 6.0, "follows": 6.0, "keys": [
		[0.0, {"lean": 0.36, "drop": 0.1, "head": 0.4, "jaw": 1.0, "l": Vector3(-0.1, 0.8, -0.72), "r": Vector3(0.1, 0.8, -0.72), "shut": -0.2}],
		[0.14, {"lean": -0.02, "drop": 0.04, "head": 0.1, "jaw": 0.6, "l": Vector3(-0.2, 0.95, -1.05), "r": Vector3(0.2, 0.95, -1.05), "shut": -0.8}],
		[0.4, {"lean": 0.24, "drop": 0.12, "head": 0.3, "jaw": 0.3, "plant_l": 0.5, "plant_r": 0.5, "l": Vector3(-0.2, 0.3, -0.3), "r": Vector3(0.2, 0.3, -0.3), "shut": 0.0}]]},
	# Knocked back up off its hands, the weight gone wrong, and down again.
	&"stagger": {"arms": 8.0, "stiff": 3.0, "follows": 4.5, "keys": [
		[0.0, {"lean": 0.62, "drop": 0.05, "head": 0.62, "jaw": 0.3, "plant_l": 0.5, "plant_r": 0.5}],
		[0.14, {"lean": 0.0, "twist": 0.3, "drop": 0.14, "shift": 0.1, "head": -0.3, "jaw": 1.0, "plant_l": 0.0, "plant_r": 0.0, "l": Vector3(-0.3, 0.5, 0.3), "r": Vector3(0.36, 0.6, 0.2), "shut": -0.7}],
		[0.34, {"lean": 0.14, "twist": -0.14, "drop": 0.26, "shift": -0.06, "head": 0.1, "jaw": 0.8, "l": Vector3(-0.2, 0.2, 0.2), "r": Vector3(0.2, 0.2, 0.1), "shut": -0.2}],
		[0.55, {"lean": 0.62, "twist": 0.0, "drop": 0.05, "shift": 0.0, "head": 0.62, "jaw": 0.3, "plant_l": 1.0, "plant_r": 1.0, "shut": 0.5}]]},
	# Its knees go first; a moment hung; then all of it comes down on its front.
	&"fall": {"arms": 7.0, "stiff": 2.0, "follows": 6.0, "thud": 0.68, "keys": [
		[0.0, {"lean": 0.62, "drop": 0.05, "head": 0.62, "jaw": 0.3, "plant_l": 0.0, "plant_r": 0.0}],
		[0.22, {"lean": 0.1, "twist": 0.14, "drop": 0.42, "head": -0.1, "jaw": 1.0, "l": Vector3(-0.2, 0.3, 0.1), "r": Vector3(0.2, 0.3, 0.1), "shut": -0.4}],
		[0.48, {"lean": 0.6, "twist": 0.18, "drop": 0.74, "head": 0.3, "jaw": 0.8, "limp": 0.5, "shut": 0.1}],
		[0.7, {"lean": 1.16, "twist": 0.1, "drop": 0.92, "head": 0.5, "jaw": 0.5, "limp": 1.0, "shut": 0.3}]]},
	&"down": {"arms": 3.0, "stiff": 2.0, "keys": [
		[0.0, {"lean": 1.16, "twist": 0.1, "drop": 0.92, "head": 0.5, "jaw": 0.5, "limp": 1.0, "shut": 0.3}],
		[3.0, {"lean": 1.2, "twist": 0.06, "drop": 0.94, "head": 0.44, "jaw": 0.2, "limp": 1.0, "shut": 0.4}],
		[4.3, {"lean": 1.14, "twist": 0.1, "drop": 0.92, "head": 0.6, "jaw": 0.5, "limp": 1.0, "shut": -0.1, "wrath": 0.5}]]},
	# Its hands first, flat on the floor; then it hauls the rest up over them, head last, still looking at you.
	&"rise": {"arms": 3.0, "stiff": 2.0, "follows": 3.0, "keys": [
		[0.0, {"lean": 1.14, "twist": 0.1, "drop": 0.92, "head": 0.6, "jaw": 0.5, "limp": 1.0, "shut": -0.1, "wrath": 0.5}],
		[0.45, {"lean": 1.02, "twist": 0.16, "drop": 0.84, "head": 0.72, "jaw": 0.7, "limp": 0.0, "plant_l": 1.0, "plant_r": 1.0, "shut": 0.3, "wrath": 0.8}],
		[1.1, {"lean": 0.72, "twist": -0.06, "drop": 0.46, "head": 0.6, "jaw": 0.9, "wrath": 1.0}],
		[1.6, {"lean": 0.62, "twist": 0.0, "drop": 0.05, "head": 0.62, "jaw": 0.4, "shut": 0.5, "wrath": 0.3}]]},
	&"dying_a": {"arms": 3.2, "stiff": 2.2, "follows": 2.4, "keys": [
		[0.0, {"lean": 0.62, "drop": 0.05, "head": 0.62, "jaw": 0.8}],
		[0.5, {"lean": 0.36, "twist": 0.2, "drop": 0.36, "head": 0.44, "jaw": 1.0, "reach_r": 0.7, "shut": -0.8}],
		[1.9, {"lean": 0.56, "twist": 0.26, "drop": 0.72, "head": 0.6, "jaw": 1.0, "reach_r": 0.95, "shut": -0.95}]]},
	&"dying_b": {"arms": 3.6, "stiff": 2.4, "follows": 2.6, "keys": [
		[0.0, {"lean": 0.62, "drop": 0.05, "head": 0.62, "jaw": 0.8}],
		[0.55, {"lean": -0.5, "twist": -0.2, "drop": 0.02, "head": -0.74, "jaw": 1.0, "l": Vector3(-0.32, 1.25, 0.05), "r": Vector3(0.3, 1.36, 0.05), "shut": -0.95}],
		[1.5, {"lean": -0.3, "twist": 0.26, "drop": 0.44, "head": -0.5, "jaw": 1.0, "l": Vector3(-0.42, 0.9, 0.22), "r": Vector3(0.24, 1.04, 0.3), "shut": -0.4}]]},
	&"dying_c": {"arms": 3.0, "stiff": 2.0, "follows": 2.2, "keys": [
		[0.0, {"lean": 0.3, "drop": 0.3, "jaw": 0.8}],
		[0.7, {"lean": 0.8, "twist": -0.2, "drop": 0.74, "head": 0.4, "jaw": 0.8, "limp": 0.7, "shut": 0.2}],
		[1.3, {"lean": 1.2, "twist": -0.3, "drop": 0.94, "head": 0.3, "jaw": 0.5, "limp": 1.0, "shut": 0.4}]]},
}
const NEUTRAL := {"lean": 0.0, "twist": 0.0, "drop": 0.0, "shift": 0.0, "head": 0.0, "jaw": 0.12, "shut": 0.0, "limp": 0.0, "reach_l": 0.0, "reach_r": 0.0, "plant_l": 0.0, "plant_r": 0.0, "wrath": 0.0}
const AT_REST := Vector3.ZERO
const TRUNK_FOLLOWS := 5.5
const SMALL_FOLLOWS := 9.0
## However it is interrupted, a mass this size only goes so fast: its head is on the end of a long lever (rad/s, m/s).
const TRUNK_TURNS_MOST := 3.0
const TRUNK_SINKS_MOST := 2.6
const LONGEST_CHANGES := 3.5
## It carries the crust on its left: it leans to it, and that leg drags: slower, lower, shorter than the other.
const LEANS_TO_CRUST := 0.075
const LEG_TAKES := [1.3, 0.9]
const LEG_LIFTS := [0.4, 1.25]
const LEG_REACHES := [0.82, 1.1]
## Where a foot lands, ahead of its hips (m), and how far behind where it wants to be before it goes; how long a step takes, at a walk and at its quickest (s); how high it lifts.
const STEP_LANDS_AHEAD := 0.42
const STEP_LETS_GO := 0.72
const STEP_TAKES := 0.56
const STEP_QUICKEST := 0.19
const STEP_LIFTS := 0.17
const STRIDE_DRIVES := 0.6
## The same for its hands: they land out ahead of its shoulders and a little outside them, and it hauls itself up to them.
const HAND_LANDS_AHEAD := 0.5
const HAND_LANDS_OUT := 0.2
const HAND_LETS_GO := 0.78
const HAND_TAKES := 0.5
const HAND_QUICKEST := 0.27
const HAND_LIFTS := 0.22
const HAND_ON_FLOOR := 0.11
## What a step does to the rest of it: its hips rise and fall, go over what's planted, and swing round with the leg, its chest the other way; its shoulders roll over the hand that's down.
const STEP_HEAVES := 0.08
const HIPS_OVER := 0.075
const HIPS_ROUND := 0.2
const CHEST_AGAINST := 1.4
const SHOULDERS_ROLL := 0.13
const SHOULDER_GOES_WITH := 0.34
const WEIGHT_EASES := 5.5
## Its pace, of its speed, as a hand hauls and between: averages about 1.
const LURCH_LOW := 0.55
const LURCH_HIGH := 1.2
const LURCH_EASES := 6.0
## How far its head twitches, and how often (rad, s): the wrongness of something that doesn't rest.
const TWITCH := 0.2
const TWITCH_EVERY := Vector2(2.2, 5.5)
const TWITCH_FADES := 7.0
## A free arm always keeps a bend, as near straight as it goes in a blow; wanting you, it draws out past its length at each joint (of its length; m). How much a free wrist overshoots.
const ARM_KEEPS_BENT := 0.86
const ARM_STRIKE_BENT := 0.95
const ARM_REACH_BENT := 0.985
const ARM_DRAWS := 0.42
const ARM_DAMP := 0.62
const STRIKES_AT := 10.0
const HAND_TURNS := 7.0
const ELBOW_TURNS := 7.0
const HEAD_REACHES := 1.15
const HEAD_TURNS := 2.8
const JAW_OPENS := 0.6
## How its heel comes down and its toe leaves (rad).
const HEEL_STRIKES := 0.42
const TOE_LEAVES := 0.6
const LIMP_HAND := 0.07
## How far its hips sink so its legs reach what they stand on, at most, and how quick (m, m/s).
const LEGS_SINK_MOST := 0.5
const LEGS_SINK_RATE := 6.0
## Struck: how far it gives, and for how long; how long a flash of it lasts (rad, m, s).
const FLINCH_LEAN := -0.14
const FLINCH_TWIST := 0.16
const FLINCH_DROP := 0.05
const FLINCH_TAKES := 0.3
const HURT_TAKES := 0.22
## Where it burns: [bone, how tall a flame (m), how wide]. Its fire is ordinary fire, hot and orange, and yours.
const FLAMES := [
	[&"chest", 1.25, 0.95], [&"spine", 1.1, 0.9], [&"hips", 0.95, 0.8], [&"clavicle_l", 1.05, 0.8], [&"clavicle_r", 0.8, 0.6], [&"arm_1_l", 0.85, 0.55],
	[&"arm_1_r", 0.8, 0.52], [&"arm_2_l", 0.72, 0.45], [&"arm_2_r", 0.68, 0.42], [&"leg_1_l", 0.8, 0.55], [&"leg_1_r", 0.8, 0.52], [&"neck_2", 0.72, 0.46], [&"head", 0.8, 0.46],
]
const FIRE_COOL := Color(0.3, 0.05, 0.008)
const FIRE_WARM := Color(0.85, 0.26, 0.03)
const FIRE_HOT := Color(1.0, 0.78, 0.32)
const FIRE_LIGHT := Color(1.0, 0.45, 0.14)
const FIRE_LIGHT_ENERGY := 1.5
const FIRE_LIGHT_REACH := 4.0
const FIRE_COMES := 2.5
const SIDES := ["_l", "_r"]
const FINGERS := ["thumb", "finger_1", "finger_2", "finger_3", "finger_4"]

var _model: Node3D
var _bones: Skeleton3D
var _mesh: MeshInstance3D
var _rest := {}
var _parent := {}
var _now := {}
var _springs := {}
var _limited := {}
var _placed := false
var _floor_y := 0.0
var _rng := RandomNumberGenerator.new()
var _doing: StringName = &""
var _clip_t := 0.0
var _stride_done := false
var _thud_done := false
## Feet, by side.
var _foot_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _step_t: Array[float] = [-1.0, -1.0]
var _step_takes: Array[float] = [STEP_TAKES, STEP_TAKES]
var _foot_yaw: Array[float] = [0.0, 0.0]
var _foot_yaw_from: Array[float] = [0.0, 0.0]
var _stride_of: Array[float] = [1.0, 1.0]
var _foot_out: Array[float] = [0.0, 0.0]
var _ankle_up := 0.1
var _legs_sink := 0.0
var _short_by := 0.0
## Hands on the floor, by side.
var _hand_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_t: Array[float] = [-1.0, -1.0]
var _hand_takes: Array[float] = [HAND_TAKES, HAND_TAKES]
var _plant: Array[float] = [1.0, 1.0]
## Free wrists and what the arm does with them.
var _wrist: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _wrist_going: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _elbow_way: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_way: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _stretch: Array[float] = [1.0, 1.0]
var _longest: Array[float] = [-1.0, -1.0]
var _head_turn := Quaternion.IDENTITY
var _twitch := Quaternion.IDENTITY
var _twitch_in := 3.0
var _heave := 0.0
var _hips_over := 0.0
var _hips_round := 0.0
var _shoulders_roll := 0.0
var _lurch := 1.0
var _flinch := 0.0
var _flinch_side := 1.0
var _hurt_now := 0.0
var _trail: Node3D
var _flames: MultiMeshInstance3D
var _fire_light: OmniLight3D
var _fire := 0.0
var _flames_lit := 0
var _eyes_now := 0.0
var _halos: Array[MeshInstance3D] = []
var _pool: Node3D


func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	_mesh = RevenantLook.dress(_model)
	_bones = _model.find_children("*", "Skeleton3D", true, false)[0]

	for i in _bones.get_bone_count():
		var name_of := StringName(_bones.get_bone_name(i))
		_rest[name_of] = _bones.get_bone_global_rest(i)
		var up := _bones.get_bone_parent(i)
		_parent[name_of] = StringName(_bones.get_bone_name(up)) if up >= 0 else &""

	_ankle_up = (_rest[&"foot_l"] as Transform3D).origin.y

	for side in 2:
		_foot_out[side] = (_rest[StringName("foot" + SIDES[side])] as Transform3D).origin.x

	_rng.seed = hash(name) + 7
	_now = _rest.duplicate()
	_build_flames()
	_trail = RevenantTrail.new()
	_trail.name = "Trail"
	add_child(_trail)

	for found in _bones.find_children("Halo", "MeshInstance3D", true, false):
		_halos.append(found)

	_pool = _model.get_node("Pool")


func _build_flames() -> void:
	var flame := QuadMesh.new()
	var look := ShaderMaterial.new()
	look.shader = FireShader
	look.set_shader_parameter(&"sheet", load(FIRE_SHEET))
	look.set_shader_parameter(&"noise", MeshVfx.noise())
	look.set_shader_parameter(&"cool", FIRE_COOL)
	look.set_shader_parameter(&"warm", FIRE_WARM)
	look.set_shader_parameter(&"hot", FIRE_HOT)
	flame.material = look
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = flame
	many.instance_count = FLAMES.size()
	_flames = MultiMeshInstance3D.new()
	_flames.name = "Flames"
	_flames.multimesh = many
	_flames.top_level = true
	_flames.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 100, 400))
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.visible = false
	add_child(_flames)

	for i in FLAMES.size():
		many.set_instance_custom_data(i, Color(float(i) * 0.37, 0.0, 0.0, 0.0))

	_fire_light = OmniLight3D.new()
	_fire_light.light_color = FIRE_LIGHT
	_fire_light.omni_range = FIRE_LIGHT_REACH
	_fire_light.light_energy = 0.0
	_fire_light.visible = false
	_fire_light.position = Vector3(0.0, 1.5, 0.0)
	add_child(_fire_light)


## Where it stands now becomes where its limbs are: as it arrives, or comes back from being out of sight.
func come_back() -> void:
	_placed = true
	_floor_y = global_position.y
	var ahead: Vector3 = -global_basis.z

	for side in 2:
		_foot_at[side] = _world_of((_rest[StringName("foot" + SIDES[side])] as Transform3D).origin)
		_foot_at[side].y = _floor_y + _ankle_up
		_step_t[side] = -1.0
		_foot_yaw[side] = global_rotation.y
		_foot_yaw_from[side] = global_rotation.y
		_hand_at[side] = _hand_wants(side, Vector3.ZERO, 0.0, 0.0) + ahead * 0.05
		_hand_t[side] = -1.0
		_plant[side] = 1.0
		_wrist[side] = _hand_at[side]
		_wrist_going[side] = Vector3.ZERO
		_elbow_way[side] = Vector3.ZERO
		_hand_way[side] = Vector3.ZERO


## The floor it stands on, as the brain finds it.
func lie_at(floor_y: float) -> void:
	_floor_y = floor_y


func wrist(side: int) -> Vector3:
	return _world_of(_now_at(&"hand", side))


func elbow(side: int) -> Vector3:
	return _world_of(_now_at(&"arm_2", side))


func foot(side: int) -> Vector3:
	return _foot_at[side]


func foot_planted(side: int) -> bool:
	return _step_t[side] < 0.0


func hand_planted(side: int) -> bool:
	return _plant[side] > 0.97 and _hand_t[side] < 0.0


func hand_on_floor(side: int) -> Vector3:
	return _hand_at[side]


## How far its leg falls short of the foot it is standing on (m).
func ankle_gap(side: int) -> float:
	return _world_of(_now_at(&"foot", side)).distance_to(_foot_at[side])


func head_at() -> Vector3:
	return _world_of((_now[&"head"] as Transform3D).origin)


func arm_stretch(side: int) -> float:
	return _stretch[side]


## The hand that grasps: where it is.
func grasp_point() -> Vector3:
	return wrist(1)


## How fast it goes now, of its speed: it hauls itself along, a lurch to each.
func lurch() -> float:
	return _lurch


func flames_lit() -> int:
	return _flames_lit


func eyes_now() -> float:
	return _eyes_now


func wrath_now() -> float:
	return float(_springs[&"wrath"][0]) if _springs.has(&"wrath") else 0.0


func smear_points() -> int:
	return _trail.points_now()


## It's over: nothing of it left burning.
func put_out_now() -> void:
	_fire = 0.0
	_flames_lit = 0
	_flames.visible = false
	_fire_light.visible = false


## It has been struck.
func flinch(side: float, hard := 1.0) -> void:
	_flinch = maxf(_flinch, clampf(hard, 0.0, 1.0))
	_flinch_side = side
	_hurt_now = maxf(_hurt_now, clampf(hard, 0.3, 1.0))


## As it finishes, each 0..1: how far the char has run over it, and how far the ash of it has fallen away.
func burn_away(charred: float, crumbled: float) -> void:
	_mesh.set_instance_shader_parameter(&"charred", charred)
	_mesh.set_instance_shader_parameter(&"crumbled", crumbled)
	_pool.scale = Vector3.ONE * (1.0 - crumbled * 0.92)

	for halo in _halos:
		halo.visible = charred < 0.75


func _work_flames(delta: float, burn: float) -> void:
	_fire = move_toward(_fire, 1.0 if burn > 0.0 else 0.0, delta * FIRE_COMES)
	_flames_lit = 0
	var many := _flames.multimesh
	_flames.visible = _fire > 0.01
	_fire_light.visible = _flames.visible
	_flames.global_transform = Transform3D.IDENTITY

	if not _flames.visible:
		return

	for i in FLAMES.size():
		var spot: Array = FLAMES[i]
		# (Not all at once: it catches, spot by spot.)
		var here := clampf(_fire * 1.6 - float(i) / float(FLAMES.size()) * 0.6, 0.0, 1.0)
		var at := _world_of((_now[spot[0]] as Transform3D).origin) + Vector3.DOWN * 0.1
		many.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(float(spot[2]), float(spot[1]), 1.0) * maxf(here, 0.001)), at))
		_flames_lit += 1 if here > 0.2 else 0

	_fire_light.light_energy = FIRE_LIGHT_ENERGY * _fire * (0.85 + 0.15 * sin(float(Time.get_ticks_msec()) * 0.013))


func _now_at(stem: StringName, side: int) -> Vector3:
	return (_now[StringName(String(stem) + SIDES[side])] as Transform3D).origin


func _world_of(at: Vector3) -> Vector3:
	return _bones.global_transform * at


func _spring(id: StringName, to: float, rate: float, damp: float, delta: float) -> float:
	if not _springs.has(id):
		_springs[id] = [to, 0.0]

	var state: Array = _springs[id]
	var w := minf(TAU * rate, 0.8 / delta)
	state[1] += (w * w * (to - state[0]) - 2.0 * damp * w * state[1]) * delta
	state[0] += state[1] * delta
	return state[0]


func _no_faster(id: StringName, value: float, most: float, delta: float) -> float:
	_limited[id] = move_toward(float(_limited.get(id, value)), value, most * delta)
	return _limited[id]


## The values at `t` through timed keys: each eased from the one before.
func _keys_at(keys: Array, t: float) -> Dictionary:
	var from: Dictionary = NEUTRAL.duplicate()
	from["l"] = AT_REST
	from["r"] = AT_REST
	var from_t := 0.0

	for key in keys:
		var to: Dictionary = key[1]

		if float(key[0]) > t:
			var share := clampf((t - from_t) / maxf(float(key[0]) - from_t, 0.001), 0.0, 1.0)
			return _between(from, to, share * share * (3.0 - 2.0 * share))

		var carried := from.duplicate()
		carried.merge(to, true)
		from = carried
		from_t = float(key[0])

	return from


func _between(from: Dictionary, to: Dictionary, share: float) -> Dictionary:
	var out := {}

	for name_of in from:
		var a: Variant = from[name_of]
		var b: Variant = to.get(name_of, a)
		out[name_of] = (a as Vector3).lerp(b as Vector3, share) if a is Vector3 else lerpf(float(a), float(b), share)

	return out


## Each tick, after it has moved: what it is doing, how it is moving (m/s, world), where you are.
func tick(delta: float, doing: StringName, moving: Vector3, you_at: Vector3, burn: float, seared: float, eyes: float) -> void:
	if not _placed:
		come_back()

	if doing != _doing:
		_doing = doing
		_clip_t = 0.0
		_stride_done = false
		_thud_done = false

	_clip_t += delta
	var clip: Dictionary = POSES.get(doing, POSES[&"walk"])
	var here := _keys_at(clip["keys"], _clip_t)
	var follows: float = float(clip.get("follows", TRUNK_FOLLOWS))
	var lean := _no_faster(&"lean", _spring(&"lean", float(here["lean"]) + _flinch * FLINCH_LEAN, follows, 0.85, delta), TRUNK_TURNS_MOST, delta)
	var twist := _no_faster(&"twist", _spring(&"twist", float(here["twist"]) + _flinch * _flinch_side * FLINCH_TWIST, follows, 0.85, delta), TRUNK_TURNS_MOST, delta)
	var drop := _no_faster(&"drop", _spring(&"drop", float(here["drop"]) + _flinch * FLINCH_DROP, follows, 0.9, delta), TRUNK_SINKS_MOST, delta)
	var shift := _spring(&"shift", float(here["shift"]), follows, 0.9, delta)
	_flinch = move_toward(_flinch, 0.0, delta / FLINCH_TAKES)
	_hurt_now = move_toward(_hurt_now, 0.0, delta / HURT_TAKES)
	var wrath := _spring(&"wrath", float(here["wrath"]), SMALL_FOLLOWS, 0.9, delta)
	var nod := _spring(&"head", float(here["head"]), SMALL_FOLLOWS, 0.85, delta)
	var jaw := _spring(&"jaw", float(here["jaw"]), SMALL_FOLLOWS, 0.8, delta)
	var shut := _spring(&"shut", float(here["shut"]), SMALL_FOLLOWS, 0.8, delta)
	var limp := _spring(&"limp", float(here["limp"]), follows, 0.95, delta)
	var reach := [_spring(&"reach_l", float(here["reach_l"]), SMALL_FOLLOWS, 0.9, delta), _spring(&"reach_r", float(here["reach_r"]), SMALL_FOLLOWS, 0.9, delta)]
	_plant[0] = move_toward(_plant[0], float(here["plant_l"]), delta * 5.0)
	_plant[1] = move_toward(_plant[1], float(here["plant_r"]), delta * 5.0)

	if clip.has("stride") and not _stride_done and _clip_t >= float(clip["stride"][0]):
		_stride_done = true
		_drive_forward(int(clip["stride"][1]))

	if clip.has("thud") and not _thud_done and _clip_t >= float(clip["thud"]):
		_thud_done = true
		slammed.emit()

	_walk_limbs(delta, moving, limp, drop)
	_pose_trunk(delta, lean, twist, drop, shift, nod, jaw, you_at)

	for side in 2:
		var off: Vector3 = here["l"] if side == 0 else here["r"]
		_pose_arm(delta, side, off, reach[side], limp, shut, you_at, float(clip["arms"]), float(clip["stiff"]))
		_pose_leg(delta, side)

	_work_flames(delta, burn)
	_eyes_now = move_toward(_eyes_now, eyes, delta * 4.0)

	for halo in _halos:
		halo.set_instance_shader_parameter(&"hot", maxf(_eyes_now, wrath * 0.6))

	_mesh.set_instance_shader_parameter(&"burn", _fire * clampf(burn, 0.0, 1.0))
	_mesh.set_instance_shader_parameter(&"seared", seared)
	_mesh.set_instance_shader_parameter(&"eyes", _eyes_now)
	_mesh.set_instance_shader_parameter(&"wrath", clampf(wrath, 0.0, 1.0))
	_mesh.set_instance_shader_parameter(&"hurt", _hurt_now)
	_trail.work(delta, float(clip["arms"]) >= STRIKES_AT, wrist(1), elbow(1), wrist(0), elbow(0))


## A foot driven forward under a blow: the weight goes onto it.
func _drive_forward(side: int) -> void:
	var ahead: Vector3 = -global_basis.z
	_foot_from[side] = _foot_at[side]
	_foot_to[side] = _ground_under(_world_of((_now[&"hips"] as Transform3D).origin) + global_basis.x * _foot_out[side] + ahead * STRIDE_DRIVES)
	_foot_yaw_from[side] = _foot_yaw[side]
	_foot_yaw[side] = global_rotation.y
	_step_t[side] = 0.0
	_step_takes[side] = STEP_QUICKEST * 1.2


## All four. A foot goes when the body has left it behind, and lands where the body will have got to; so does a hand. At a walk one of each at a time, and never both on a side;
## galloping, its hands go together and its feet together.
func _walk_limbs(delta: float, moving: Vector3, limp: float, drop: float) -> void:
	var speed := Vector2(moving.x, moving.z).length()
	var going := Vector3(moving.x, 0.0, moving.z) / maxf(speed, 0.01)
	var run := clampf((speed - 2.5) / 3.0, 0.0, 1.0)
	var felt := 0.0
	var hauled := 0.0
	var rolled := 0.0

	for side in 2:
		if _step_t[side] >= 0.0:
			_step_t[side] += delta / _step_takes[side]
			var t := minf(_step_t[side], 1.0)
			_foot_at[side] = _foot_from[side].lerp(_foot_to[side], t * t * (3.0 - 2.0 * t)) + Vector3.UP * sin(t * PI) * STEP_LIFTS * LEG_LIFTS[side] * (1.0 + speed * 0.14)
			felt = maxf(felt, sin(t * PI))

			if t >= 1.0:
				_foot_at[side] = _foot_to[side]
				_step_t[side] = -1.0
				step_landed.emit(side)

		if _hand_t[side] >= 0.0:
			_hand_t[side] += delta / _hand_takes[side]
			var u := minf(_hand_t[side], 1.0)
			_hand_at[side] = _hand_from[side].lerp(_hand_to[side], u * u * (3.0 - 2.0 * u)) + Vector3.UP * sin(u * PI) * HAND_LIFTS * (1.0 + speed * 0.1)
			hauled = maxf(hauled, sin(u * PI))
			rolled += sin(u * PI) * (-1.0 if side == 0 else 1.0)

			if u >= 1.0:
				_hand_at[side] = _hand_to[side]
				_hand_t[side] = -1.0
				hand_landed.emit(side)

	# (Down on its knees it doesn't step.)
	if drop < 0.62 and limp < 0.4:
		_steps_wanted(going, speed, run, moving)

	# The rest of it feels that: eased, never read straight off a limb.
	_heave = move_toward(_heave, felt, WEIGHT_EASES * delta)
	var over := 0.0
	var round_on := 0.0
	var walking := clampf(speed / 1.2, 0.0, 1.0)

	for side in 2:
		if _step_t[side] >= 0.0:
			var sign_of := -1.0 if side == 0 else 1.0
			over -= sign_of
			round_on += sign_of * (minf(_step_t[side], 1.0) * 2.0 - 1.0)

	_hips_over = move_toward(_hips_over, over * HIPS_OVER * walking, WEIGHT_EASES * 0.2 * delta)
	_hips_round = move_toward(_hips_round, round_on * HIPS_ROUND * walking, WEIGHT_EASES * 0.3 * delta)
	_shoulders_roll = move_toward(_shoulders_roll, rolled * SHOULDERS_ROLL * walking, WEIGHT_EASES * 0.3 * delta)
	_lurch = move_toward(_lurch, lerpf(LURCH_LOW, LURCH_HIGH, maxf(hauled, felt * 0.6)) if speed > 0.1 else 1.0, LURCH_EASES * delta)


func _steps_wanted(going: Vector3, speed: float, run: float, moving: Vector3) -> void:
	var feet_out := [_foot_at[0].distance_to(_foot_wants(0, going, speed, 0.0)), _foot_at[1].distance_to(_foot_wants(1, going, speed, 0.0))]
	var first := 0 if feet_out[0] >= feet_out[1] else 1

	for order in 2:
		var side: int = first if order == 0 else 1 - first
		var other := 1 - side

		if _step_t[side] >= 0.0:
			continue

		var lets_go: float = STEP_LETS_GO * _stride_of[side] * LEG_REACHES[side] * (1.0 if speed > 0.1 else 0.5)

		# One at a time at a walk; galloping, they go together.
		# (Left far enough behind, it goes whatever the other is doing: it can't stand on that.)
		if feet_out[side] > lets_go and (_step_t[other] < 0.0 or run > 0.5 or feet_out[side] > lets_go * 1.45):
			var takes: float = lerpf(STEP_TAKES * LEG_TAKES[side], STEP_QUICKEST, run) * _rng.randf_range(0.92, 1.12)
			_foot_from[side] = _foot_at[side]
			_foot_to[side] = _ground_under(_foot_wants(side, going, speed, takes))
			_step_t[side] = 0.0
			_step_takes[side] = takes
			_stride_of[side] = _rng.randf_range(0.88, 1.16)
			_foot_yaw_from[side] = _foot_yaw[side]
			_foot_yaw[side] = global_rotation.y

	for side in 2:
		if _hand_t[side] >= 0.0 or _plant[side] < 0.5:
			continue

		var other := 1 - side
		var takes: float = lerpf(HAND_TAKES, HAND_QUICKEST, run)
		var off_by: float = _hand_at[side].distance_to(_hand_wants(side, going, speed, 0.0))
		var lets_go: float = HAND_LETS_GO * (1.0 if speed > 0.1 else 0.5)
		# (Never with the leg on its own side, at a walk: it would fall over.)
		var free_to: bool = (_hand_t[other] < 0.0 and _step_t[side] < 0.0) or run > 0.5

		if off_by > lets_go and free_to:
			_hand_from[side] = _hand_at[side]
			_hand_to[side] = _ground_under(_hand_wants(side, going, speed, takes), HAND_ON_FLOOR)
			_hand_t[side] = 0.0
			_hand_takes[side] = takes * _rng.randf_range(0.92, 1.1)


## Under its hips, and where they will have got to by the time it lands.
func _foot_wants(side: int, going: Vector3, speed: float, takes: float) -> Vector3:
	var ahead: Vector3 = going * (STEP_LANDS_AHEAD * LEG_REACHES[side] + speed * takes) * (1.0 if speed > 0.1 else 0.0)
	var at: Vector3 = _world_of((_now[&"hips"] as Transform3D).origin) + global_basis.x * _foot_out[side] + ahead
	at.y = _floor_y + _ankle_up
	return at


## Out ahead of its shoulder and a little outside it, where its shoulder will have got to.
func _hand_wants(side: int, going: Vector3, speed: float, takes: float) -> Vector3:
	var shoulder: Vector3 = (_now[StringName("arm_1" + SIDES[side])] as Transform3D).origin
	var out_way: float = -1.0 if side == 0 else 1.0
	var at := _world_of(shoulder) + global_basis.x * out_way * HAND_LANDS_OUT - global_basis.z * 0.12
	at += going * (HAND_LANDS_AHEAD + speed * takes) * (1.0 if speed > 0.1 else 0.0)
	at.y = _floor_y + HAND_ON_FLOOR
	return at


func _ground_under(at: Vector3, above := -1.0) -> Vector3:
	var up: float = _ankle_up if above < 0.0 else above

	if not is_inside_tree():
		return at

	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.9, at + Vector3.DOWN * 1.2, FLOOR_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return (hit["position"] as Vector3) + Vector3.UP * up if not hit.is_empty() else at


## Everything from its hips to its head: bent over, twisted, sunk, the weight going through it.
func _pose_trunk(delta: float, lean: float, twist: float, drop: float, shift: float, nod: float, jaw: float, you_at: Vector3) -> void:
	_turn_bone(&"root", Quaternion.IDENTITY)
	var ride := Vector3(shift + _hips_over, -drop - _legs_sink + (0.5 - _heave) * STEP_HEAVES, 0.0)
	var crust := Quaternion(Vector3.BACK, LEANS_TO_CRUST)
	var hips_turn := crust * Quaternion(Vector3.UP, _hips_round + twist * 0.25) * Quaternion(Vector3.RIGHT, -lean * 0.3) * Quaternion(Vector3.BACK, -_hips_over * 0.8)
	_turn_bone(&"hips", hips_turn, ride)
	var spine_turn := hips_turn * Quaternion(Vector3.UP, -_hips_round * CHEST_AGAINST * 0.5 + twist * 0.35) * Quaternion(Vector3.RIGHT, -lean * 0.32)
	_turn_bone(&"spine", spine_turn)
	var chest_turn := spine_turn * Quaternion(Vector3.UP, -_hips_round * CHEST_AGAINST * 0.5 + twist * 0.4) * Quaternion(Vector3.RIGHT, -lean * 0.38) * Quaternion(Vector3.BACK, _shoulders_roll)
	_turn_bone(&"chest", chest_turn)
	# Its neck comes back up against the lean, so its head stays on you.
	var neck_turn := chest_turn * Quaternion(Vector3.RIGHT, lean * 0.3)
	_turn_bone(&"neck_1", neck_turn)
	_turn_bone(&"neck_2", neck_turn * Quaternion(Vector3.RIGHT, lean * 0.2))
	var head_rest: Transform3D = _rest[&"head"]
	var flat_turn := neck_turn * Quaternion(Vector3.RIGHT, lean * 0.44 + nod * 0.4)
	var head_at_now := (_now[&"neck_2"] as Transform3D) * ((_rest[&"neck_2"] as Transform3D).affine_inverse() * head_rest.origin)
	var to_you := _bones.global_transform.affine_inverse().basis * (you_at - _world_of(head_at_now))
	var looking: Vector3 = flat_turn * Vector3.FORWARD
	var turn := Quaternion.IDENTITY

	if to_you.length() > 0.2 and looking.angle_to(to_you) < 2.6:
		var angle := minf(looking.angle_to(to_you), HEAD_REACHES)
		var axis := looking.cross(to_you)

		if axis.length() > 0.001:
			turn = Quaternion(axis.normalized(), angle)

	_head_turn = _head_turn.slerp(turn, 1.0 - exp(-HEAD_TURNS * delta))
	# Every so often, it twitches: small, sudden, wrong.
	_twitch_in -= delta

	if _twitch_in <= 0.0:
		_twitch_in = _rng.randf_range(TWITCH_EVERY.x, TWITCH_EVERY.y)
		_twitch = Quaternion(Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized(), TWITCH)

	_twitch = _twitch.slerp(Quaternion.IDENTITY, 1.0 - exp(-TWITCH_FADES * delta))
	var head_turn := _twitch * _head_turn * flat_turn
	_turn_bone(&"head", head_turn)
	_turn_bone(&"eye_l", head_turn)
	_turn_bone(&"eye_r", head_turn)
	_set_local_turn(&"jaw", Quaternion(Vector3.RIGHT, jaw * JAW_OPENS))


## A bone by how far it has turned from its rest, in the skeleton's space; `moved`, how far its head has shifted from where its parent carries it.
func _turn_bone(bone: StringName, turned: Quaternion, moved := Vector3.ZERO) -> void:
	var rest: Transform3D = _rest[bone]
	var up: StringName = _parent[bone]
	var origin := rest.origin

	if up != &"":
		var up_rest: Transform3D = _rest[up]
		origin = (_now[up] as Transform3D) * (up_rest.affine_inverse() * rest.origin)

	var now := Transform3D(Basis(turned) * rest.basis, origin + moved)
	_now[bone] = now
	_apply(bone, now)


func _set_local_turn(bone: StringName, turned: Quaternion) -> void:
	var rest: Transform3D = _rest[bone]
	var up: StringName = _parent[bone]
	var up_rest: Transform3D = _rest[up]
	var origin: Vector3 = (_now[up] as Transform3D) * (up_rest.affine_inverse() * rest.origin)
	var up_turn: Basis = (_now[up] as Transform3D).basis * up_rest.basis.inverse()
	var now := Transform3D(up_turn * Basis(turned) * rest.basis, origin)
	_now[bone] = now
	_apply(bone, now)


func _apply(bone: StringName, now: Transform3D) -> void:
	var i := _bones.find_bone(bone)
	var up: StringName = _parent[bone]
	var local: Transform3D = (_now[up] as Transform3D).affine_inverse() * now if up != &"" else now
	_bones.set_bone_pose_position(i, local.origin)
	_bones.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())


## A bone laid along a way, from wherever its parent has left it, drawn out from it by `drawn`.
func _along(bone: StringName, way: Vector3, drawn := 0.0) -> void:
	var rest: Transform3D = _rest[bone]
	var up: StringName = _parent[bone]
	var up_rest: Transform3D = _rest[up]
	var origin: Vector3 = (_now[up] as Transform3D) * (up_rest.affine_inverse() * rest.origin)
	var rest_way: Vector3 = rest.basis.y.normalized()
	var turned := Quaternion(rest_way, way.normalized()) if rest_way.dot(way.normalized()) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	var up_way: Vector3 = (_now[up] as Transform3D).basis.y.normalized()
	var now := Transform3D(Basis(turned) * rest.basis, origin + up_way * drawn)
	_now[bone] = now
	_apply(bone, now)


func _pose_arm(delta: float, side: int, off: Vector3, reach: float, limp: float, shut: float, you_at: Vector3, fastest: float, stiff: float) -> void:
	var tag: String = SIDES[side]
	var clavicle := StringName("clavicle" + tag)
	var arm_1 := StringName("arm_1" + tag)
	var arm_2 := StringName("arm_2" + tag)
	var hand := StringName("hand" + tag)
	var into := _bones.global_transform.affine_inverse()
	var chest_turn: Quaternion = ((_now[&"chest"] as Transform3D).basis * (_rest[&"chest"] as Transform3D).basis.inverse()).get_rotation_quaternion()
	# Its shoulder blade goes with the arm: it reaches from the back, not from a socket.
	var wrist_now: Vector3 = into * _wrist[side]
	var blade_from: Vector3 = (_now[&"chest"] as Transform3D) * ((_rest[&"chest"] as Transform3D).affine_inverse() * (_rest[clavicle] as Transform3D).origin)
	var blade_way: Vector3 = chest_turn * (_rest[clavicle] as Transform3D).basis.y.normalized()
	var wants_way: Vector3 = (wrist_now - blade_from).normalized()
	var blade_turn := Quaternion.IDENTITY

	if blade_way.dot(wants_way) > -0.9:
		var whole_turn := Quaternion(blade_way, wants_way)
		blade_turn = Quaternion.IDENTITY.slerp(whole_turn, SHOULDER_GOES_WITH)

	_turn_bone(clavicle, blade_turn * chest_turn)
	var shoulder: Vector3 = (_now[clavicle] as Transform3D) * ((_rest[clavicle] as Transform3D).affine_inverse() * (_rest[arm_1] as Transform3D).origin)
	var rest_shoulder: Vector3 = (_rest[arm_1] as Transform3D).origin
	var rest_wrist: Vector3 = (_rest[hand] as Transform3D).origin
	# Free: off the shoulder as it stands now, with the pose's offset, or at you.
	var free_local: Vector3 = shoulder + (rest_wrist - rest_shoulder) + off
	var wanted: Vector3 = _bones.global_transform * free_local
	wanted = wanted.lerp(you_at + Vector3.DOWN * 0.25, clampf(reach, 0.0, 1.0))

	if limp > 0.01:
		# Given up to the floor, out ahead of it, wherever its shoulders have got to.
		var on_floor: Vector3 = _bones.global_transform * Vector3(rest_wrist.x * 1.1, 0.0, shoulder.z - 0.3)
		on_floor.y = _floor_y + LIMP_HAND
		wanted = wanted.lerp(on_floor, limp)

	var planted: float = _plant[side] * (1.0 - limp)

	# On the floor it is the floor that has it: when it comes off, it starts from there.
	if planted > 0.0:
		wanted = wanted.lerp(_hand_at[side], planted)

	# It answers as weight on a spring does: low and slow, it swings and trails behind what the body does; quick, it's a blow.
	var w := minf(TAU * maxf(stiff, lerpf(stiff, 8.0, planted)), 0.8 / delta)
	_wrist_going[side] += (w * w * (wanted - _wrist[side]) - 2.0 * ARM_DAMP * w * _wrist_going[side]) * delta
	_wrist_going[side] = _wrist_going[side].limit_length(maxf(fastest, 7.0 * planted))
	_wrist[side] += _wrist_going[side] * delta

	# (Once it is there, the floor has it. Not before: it gets there first.)
	if planted > 0.97 and _wrist[side].distance_to(_hand_at[side]) < 0.04:
		_wrist[side] = _hand_at[side]
		_wrist_going[side] = Vector3.ZERO

	_wrist[side].y = maxf(_wrist[side].y, _floor_y + LIMP_HAND * 0.6)
	var wrist_at: Vector3 = into * _wrist[side]
	var upper: float = (_rest[arm_2] as Transform3D).origin.distance_to(rest_shoulder)
	var lower: float = rest_wrist.distance_to((_rest[arm_2] as Transform3D).origin)
	var span := wrist_at - shoulder
	var whole := upper + lower
	# (It keeps a bend, unless it wants you, or the floor is under it.)
	var strike := _spring(StringName("strike" + tag), 1.0 if fastest >= STRIKES_AT else 0.0, 6.0, 1.0, delta)
	var bent := lerpf(lerpf(ARM_KEEPS_BENT, ARM_STRIKE_BENT, clampf(strike, 0.0, 1.0)), 1.0, clampf(planted, 0.0, 1.0))
	var longest := whole * lerpf(bent, 1.0 + ARM_DRAWS * 2.0 / whole, clampf(reach, 0.0, 1.0))
	_longest[side] = longest if _longest[side] < 0.0 else move_toward(_longest[side], longest, LONGEST_CHANGES * delta)

	if span.length() > _longest[side]:
		span = span.normalized() * _longest[side]
		wrist_at = shoulder + span

	var far := span.length()
	var drawn := clampf(far - whole * ARM_REACH_BENT, 0.0, ARM_DRAWS * 2.0)
	_stretch[side] = 1.0 + drawn / whole
	var a := upper + drawn * 0.5
	var b := lower + drawn * 0.5
	far = maxf(minf(far, (a + b) * 0.995), 0.05)
	var along := span.normalized() if span.length() > 0.001 else Vector3.DOWN
	# Elbow out, and back: it comes round to that, and never flips over the line of the arm.
	var out := Vector3.RIGHT * (-1.0 if side == 0 else 1.0)
	var pole := (out * 0.9 + Vector3.BACK * 0.7 + Vector3.UP * 0.35).normalized()
	pole -= along * pole.dot(along)

	if pole.length() < 0.2:
		pole = out - along * out.dot(along)

	pole = pole.normalized()
	var had: Vector3 = _elbow_way[side] - along * _elbow_way[side].dot(along)
	_elbow_way[side] = pole if had.length() < 0.05 else _come_round(had.normalized(), pole, ELBOW_TURNS * delta)
	var offset := (a * a - b * b + far * far) / (2.0 * far)
	var elbow_at: Vector3 = shoulder + along * offset + _elbow_way[side] * sqrt(maxf(a * a - offset * offset, 0.0))
	_along(arm_1, elbow_at - shoulder)
	_along(arm_2, wrist_at - elbow_at, drawn * 0.5)
	# On the floor its hand is flat under it, its knuckles taking the weight; coming up, it hangs off its wrist; free, it goes on from the forearm; at you, spread.
	var fore := (wrist_at - elbow_at).normalized()
	var free_way := fore.lerp(Vector3.DOWN, 0.35 * (1.0 - reach)).normalized()
	var u := minf(_hand_t[side], 1.0) if _hand_t[side] >= 0.0 else 1.0
	var planted_way: Vector3 = (Vector3.FORWARD * 0.85 + Vector3.DOWN * 0.45).normalized().lerp((Vector3.BACK * 0.3 + Vector3.DOWN).normalized(), sin(u * PI) * 0.8).normalized()
	var pointing: Vector3 = free_way.lerp(planted_way, planted).normalized()
	_hand_way[side] = pointing if _hand_way[side] == Vector3.ZERO else _come_round(_hand_way[side], pointing, HAND_TURNS * delta)
	_along(hand, _hand_way[side], drawn * 0.5)

	for finger in FINGERS:
		var curl := Quaternion(Vector3.RIGHT, shut * (0.6 if finger == "thumb" else 1.0))
		_set_local_turn(StringName(finger + tag), curl)
		_set_local_turn(StringName(finger + "_b" + tag), curl)


func _pose_leg(delta: float, side: int) -> void:
	var tag: String = SIDES[side]
	var leg_1 := StringName("leg_1" + tag)
	var leg_2 := StringName("leg_2" + tag)
	var foot_bone := StringName("foot" + tag)
	var into := _bones.global_transform.affine_inverse()
	var hip: Vector3 = (_now[&"hips"] as Transform3D) * ((_rest[&"hips"] as Transform3D).affine_inverse() * (_rest[leg_1] as Transform3D).origin)
	var ankle: Vector3 = into * _foot_at[side]
	var upper: float = (_rest[leg_2] as Transform3D).origin.distance_to((_rest[leg_1] as Transform3D).origin)
	var lower: float = (_rest[foot_bone] as Transform3D).origin.distance_to((_rest[leg_2] as Transform3D).origin)
	var span := ankle - hip
	# Its hips go down as far as its legs need: what it stands on, it reaches. (Eased, from the tick before: this is its weight on them.)
	if side == 0:
		_short_by = 0.0

	var short := span.length() - (upper + lower) * 0.985

	if foot_planted(side):
		_short_by = maxf(_short_by, short)

	if side == 1:
		_legs_sink = move_toward(_legs_sink, clampf(_legs_sink + _short_by, 0.0, LEGS_SINK_MOST), LEGS_SINK_RATE * delta)

	var far := maxf(minf(span.length(), (upper + lower) * 0.995), 0.05)
	var along := span.normalized() if span.length() > 0.001 else Vector3.DOWN
	# Knees go forward and a little out.
	var pole := (Vector3.FORWARD + Vector3.RIGHT * (-0.25 if side == 0 else 0.25)).normalized()
	pole -= along * pole.dot(along)
	pole = pole.normalized() if pole.length() > 0.05 else Vector3.FORWARD
	var offset := (upper * upper - lower * lower + far * far) / (2.0 * far)
	var knee := hip + along * offset + pole * sqrt(maxf(upper * upper - offset * offset, 0.0))
	_along(leg_1, knee - hip)
	_along(leg_2, (hip + along * far) - knee)
	var foot_rest: Transform3D = _rest[foot_bone]
	# Toe off, heel down; and it lands the way it was facing then.
	var t := minf(_step_t[side], 1.0) if _step_t[side] >= 0.0 else 1.0
	var pitch: float = -TOE_LEAVES * sin(minf(t * 2.0, 1.0) * PI) * LEG_LIFTS[side] + HEEL_STRIKES * sin(maxf(t * 2.0 - 1.0, 0.0) * PI)
	var yaw := lerp_angle(_foot_yaw_from[side], _foot_yaw[side], t) - global_rotation.y
	var flat := Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch if _step_t[side] >= 0.0 else 0.0)
	var up_now: Transform3D = _now[leg_2]
	var origin: Vector3 = up_now * ((_rest[leg_2] as Transform3D).affine_inverse() * foot_rest.origin)
	var now := Transform3D(Basis(flat) * foot_rest.basis, origin)
	_now[foot_bone] = now
	_apply(foot_bone, now)


func _come_round(from: Vector3, to: Vector3, most: float) -> Vector3:
	var angle := from.angle_to(to)

	if angle < 0.0005 or most >= angle:
		return to

	var axis := from.cross(to)

	if axis.length() < 0.001:
		axis = from.cross(Vector3.RIGHT if absf(from.x) < 0.9 else Vector3.UP)

	return from.rotated(axis.normalized(), most).normalized()

