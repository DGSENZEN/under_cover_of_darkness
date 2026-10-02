extends CharacterBody3D
## First-person controller.
##
## LOCOMOTION  walking, sprinting, crouching, jumping. Velocity driven.
## MOVING      a choreographed TraversalMove: mantle, vault, pull up, lowering
##             over an edge, or reaching for a hang. Position driven, no input.
## HANGING     holding a ledge. Shimmy, peek, pull up or drop.
## CLIMBING    attached to a ClimbVolume (ladder, vines). Velocity driven, no gravity.
## SWIMMING    in water too deep to stand in (WaterVolume): afloat with the eyes
##             over the surface, swimming the way you face, diving (crouch) and
##             coming up (jump); jump at a bank low enough to climb out.
##             Shallower water is waded: slower, and every step splashes.
##
## The traversal pipeline is: scan -> classify -> generate -> play.
## See scripts/PlayerUtils for each stage.

const ObstacleProfile := preload("res://scripts/PlayerUtils/ObstacleProfile.gd")
const MoveVariantRes := preload("res://scripts/PlayerUtils/MoveVariant.gd")
const TraversalMove := preload("res://scripts/PlayerUtils/TraversalMove.gd")
const TraversalScanner := preload("res://scripts/PlayerUtils/TraversalScanner.gd")
const TraversalPlanner := preload("res://scripts/PlayerUtils/TraversalPlanner.gd")
const CameraJuice := preload("res://scripts/PlayerUtils/CameraJuice.gd")
const BodyPose := preload("res://scripts/PlayerUtils/BodyPose.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")
const StealthHUD := preload("res://scripts/UI/StealthHUD.gd")
const PlayerCombat := preload("res://scripts/Combat/PlayerCombat.gd")
const GemEnvironment := preload("res://scripts/Visual/GemEnvironment.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const BodyMotionScript := preload("res://scripts/PlayerUtils/BodyMotion.gd")
const WaterScript := preload("res://scripts/Interaction/WaterVolume.gd")
const LanternBody := preload("res://scripts/Visual/Lights/LanternBody.gd")

## The old feel's strides (legacy_feel): four steps a second at a walk.
const LEGACY_STRIDE_WALK := 1.6
const LEGACY_STRIDE_SPRINT := 1.9

signal damaged(amount: float)
signal died

enum MoveState {
	LOCOMOTION,
	MOVING,
	HANGING,
	CLIMBING,
	SWIMMING,
}


@export_category("View")
@export var mouse_sensitivity := 0.002
@export_range(1.0, 89.0, 1.0) var max_pitch_degrees := 88.0


@export_category("Locomotion")
@export var walk_speed := 6.5
@export var sprint_speed := 8.5
@export var crouch_speed := 3.0

## The old feel's straight-line starts and stops (legacy_feel), and the
## death stop.
@export var ground_acceleration := 45.0
@export var ground_deceleration := 55.0
@export var air_acceleration := 15.0

## Momentum on the ground. Setting off, the push is hardest from a standstill
## and eases off near the pace (this is its time constant, s); above walking
## pace a sprint gathers more slowly.
@export var start_time := 0.12
@export var sprint_build_time := 0.2
## Moving faster than asked (sprint let go, a guard raised): eased off.
@export var slow_time := 0.15
## A planted stop with no input, from walking pace and from a sprint (s).
@export var stop_time_walk := 0.15
@export var stop_time_sprint := 0.25
## How fast speed across the way you want to go is taken away (m/s²): quick
## at walking pace, lower at a sprint, so hard turns carve a little.
@export var turn_acceleration_walk := 45.0
@export var turn_acceleration_sprint := 28.0
@export var max_ground_acceleration := 60.0

@export var gravity := 24.0
@export var fall_gravity_multiplier := 1.35
@export var maximum_fall_speed := 35.0

@export var jump_speed := 8.3
@export_range(0.0, 1.0, 0.05) var jump_cut_multiplier := 0.5

@export var coyote_time := 0.12
@export var jump_buffer_time := 0.15


@export_category("Water")
## Swimming, and with sprint held; diving and coming up (m/s).
@export var swim_speed := 3.0
@export var swim_sprint_speed := 4.2
@export var dive_speed := 2.2
@export var swim_acceleration := 6.0
## Releasing a stroke settles sooner than changing its direction.
@export var swim_braking := 8.4
## The floor must be deeper than the standing exit threshold by this much
## before wading becomes swimming, so borderline shallows do not oscillate.
@export var swim_depth_hysteresis := 0.15
## Afloat, the eyes this far over the surface.
@export var float_eye := 0.12
## Chest-deep and nothing to stand on (m of water over the feet): swimming.
@export var swim_start_depth := 1.1
## A stroke heard at the surface (dB), and under it. (Wading, each step is
## as loud as on "water" in surface_db.)
@export var swim_db := 46.0
@export var swim_under_db := 30.0
## Wading, at waist deep, this much of your speed.
@export_range(0.1, 1.0, 0.05) var wade_speed_scale := 0.6


@export_category("Stairs")
## Highest step that walking climbs without a jump. Also the floor snap
## distance, so walking down stairs stays glued to them.
@export var stair_step_height := 0.35
## How quickly the eyes smooth out a step up or down.
@export var stair_view_smoothing := 14.0
## Walking off a step, the body is pulled down at this speed until it lands.
@export var stair_magnet_speed := 6.0
## Between steps, the eyes may rise or fall at most this fast (m/s) on their own.
@export var stair_view_catch_up := 2.5


@export_category("Crouch")
## Capsule height while crouched. The feet stay planted; the top comes down.
@export var crouch_height := 1.2
## How quickly the eyes follow a change in stance.
@export var view_height_speed := 12.0


@export_category("Traversal")
@export_flags_3d_physics var traversal_mask := 1

## Tops lower than this are steps, not obstacles.
@export var step_height := 0.35
## Highest top that can be grabbed, measured from the feet.
@export var max_reach := 2.6
## How far ahead of the body the scan looks at standstill.
@export var scan_distance := 1.2
## Forward input needed before any traversal is considered.
@export_range(0.0, 1.0, 0.05) var min_forward_input := 0.25

## Holding jump in the air grabs the first valid obstacle, but not while still
## rising faster than this.
@export var air_grab_max_rise := 2.0
## Falling faster than this, nothing can be caught. 20 is roughly a 6 m fall.
@export var maximum_grab_fall_speed := 20.0
## After dropping from a hang, how long before another grab is allowed.
@export var regrab_delay := 0.35

## Rows of MoveVariant, top to bottom = priority. Empty uses the built-in table.
@export var variant_table: Array[Resource] = []


@export_category("Flow")
## How many extra moves may be chained in the air after the first one.
## Flow never adds speed, and it never works while sneaking.
@export var max_chain_links := 1
## A buffered jump press may start the next move once the current one is
## this far along.
@export_range(0.0, 1.0, 0.05) var chain_window_start := 0.65
## Seconds of travel a chain looks ahead for the next obstacle. Longer than
## the grounded look-ahead, because the player is committed and moving fast.
@export var chain_lookahead_time := 0.3


@export_category("Wall Kick")
@export var max_wall_kicks := 1
## Upward speed of the kick. 5.0 is roughly half a metre of extra height.
@export var wall_kick_up := 5.0
## Push away from the wall. Reduced automatically for head-on kicks.
@export var wall_kick_push := 3.0
@export_range(0.0, 1.0, 0.05) var wall_kick_speed_kept := 0.9
## How close to the capsule the wall has to be.
@export var wall_kick_reach := 0.45


@export_category("Assisted Jump")
## Jumping toward a gap with a landing beyond it nudges the jump so it lands.
@export var jump_assist := true
## Only nudges this fraction of your current speed. Beyond it, you miss honestly.
@export_range(0.0, 0.5, 0.01) var jump_assist_tolerance := 0.15
@export var jump_assist_min_distance := 1.5
@export var jump_assist_max_distance := 6.5
@export var jump_assist_max_rise := 1.0
@export var jump_assist_max_drop := 1.5


@export_category("Hang")
## Standing at a drop and looking down past it more steeply than this,
## pressing crouch lowers you into a hang instead of crouching.
@export var lower_look_down_degrees := 35.0
@export var shimmy_speed := 1.3
## Time to reach full shimmy speed; release settles more quickly.
@export var shimmy_start_time := 0.12
@export var shimmy_stop_time := 0.08
@export var shimmy_max_turn_degrees := 25.0
## How far above the lip the eyes rise while peeking.
@export var peek_above_lip := 0.15

## Hang leap reach. These are level design metrics.
@export var leap_max_sideways := 2.5
@export var leap_max_across := 3.5
@export var leap_max_rise := 1.2
## Deeper than this, a downward leap becomes a drop: let go, fall, catch.
@export var leap_arc_max_drop := 1.5
## The deepest ledge below that a targeted drop will catch.
@export var leap_max_drop := 6.0


@export_category("Climb")
@export var climb_jump_push := 3.5
## On a simulated rope, how strongly the body is pulled to its grip point.
@export var rope_grip_stiffness := 14.0
## Rope end you cannot climb past, in metres from each end.
@export var rope_end_margin := 0.35
@export var climb_reattach_delay := 0.4
## While climbing upward, a top this close to the feet is mantled onto.
@export var climb_top_mantle_height := 1.4


@export_category("Stealth")
## Stands in for the lightgem when the player has no LightGem node.
@export_range(0.0, 1.0, 0.01) var debug_light_level := 1.0
## Crouching makes you a smaller, stiller shape.
@export_range(0.0, 1.0, 0.05) var crouch_exposure := 0.85
## Moving at walking speed makes you this much easier to see. Light still
## rules: in true darkness, movement adds nothing.
@export_range(0.0, 1.0, 0.05) var motion_exposure := 0.35

## Footstep loudness in dB. 50 carries 15 m; every 7 dB doubles or halves it.
@export var footstep_db_walk := 48.0
@export var footstep_db_sprint := 58.0
@export var footstep_db_crouch := 32.0
## Metres between footsteps: fewer, heavier steps than a scurry (at a walk,
## about three a second).
@export var stride_walk := 2.0
@export var stride_sprint := 2.4
@export var stride_crouch := 1.1
## Landing: this, plus landing_db_per_speed for each m/s of the fall.
@export var landing_db_base := 38.0
@export var landing_db_per_speed := 2.2
@export var landing_db_max := 66.0


@export_category("Health")
@export var max_health := 100.0
## Landing faster than this hurts.
@export var fall_damage_speed := 17.0
@export var fall_damage_per_speed := 6.0
@export var invulnerable := false
## When you die the level restarts after a moment. Off for tests.
@export var reload_on_death := true
## Health is in shields (the HUD's, max_health / shields each). Get away and
## catch your breath (nothing has hurt you for recover_delay seconds) and the
## shield you are in fills again, recover_rate a second; a shield lost whole
## stays lost. Running and regrouping is worth something; it is not a cure.
@export var shields := 5
@export var recover_delay := 6.0
@export var recover_rate := 5.0


@export_category("Carrying")
## A body over the shoulder: slower, no sprinting, heavier footsteps.
@export_range(0.1, 1.0, 0.05) var shoulder_speed_scale := 0.6
@export var shoulder_noise_db := 6.0


@export_category("Surfaces")
## Footstep loudness change by what the floor is made of. A floor body names
## its material with metadata "surface"; anything unnamed is stone.
@export var surface_db := {
	"carpet": -14.0,
	"grass": -8.0,
	"wood": -2.0,
	"stone": 0.0,
	"tile": 4.0,
	"metal": 8.0,
	"water": 6.0,
}


@export_category("Lean")
@export var lean_distance := 0.45
@export var lean_roll_degrees := 11.0
@export var lean_speed := 9.0


@export_category("HUD")
@export var show_hud := true


@export_category("Camera Feel")
## Master dial for the body under the view (steps, landings, leans into
## starts and stops), the move arcs and the hands' motion. 0 turns it all off.
@export_range(0.0, 2.0, 0.05) var camera_feel := 1.0
## One step's rise and fall under the view (BodyMotion.gd): x runs from a foot
## landing (0) to the next landing (1); y from lowest (-1) to highest (1).
@export var footfall_curve: Curve


@export_category("Debug")
## The traversal overlay: state, obstacle readout, markers. Off by default,
## the HUD covers normal play; the gyms switch it on.
@export var debug_traversal := false
## The old movement feel, for comparing (F10 in debug builds): straight-line
## starts and stops, the old strides, the old camera bob and hand motion.
## Goes once the new feel is signed off.
@export var legacy_feel := false


@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D
@onready var inventory: Node = get_node_or_null("Inventory")
@onready var frob: Node = get_node_or_null("Frob")
@onready var hand: Node = get_node_or_null("Neck/Camera3D/Hand")
@onready var light_gem: Node = get_node_or_null("LightGem")


var movement_state := MoveState.LOCOMOTION
var is_crouched := false

var health := 100.0
var is_dead := false

## -1 leaning fully left, +1 fully right.
var lean := 0.0
var hud: CanvasLayer = null
## How far a stair step moved the body during the last physics tick. The eye
## height cancels it at once; the drawn body only gets there over the tick.
var _step_change_tick := 0.0
## Climbing: how far you have gone since the last creak or hand-hold sound.
var _climb_sound_travel := 0.0
var _climb_last_y := 0.0
## Dead: how far through falling to the floor the view is, 0..1.
var _death_fall := 0.0
var combat: Node = null
var _hazard_cooldown := 0.0

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

## The latest obstacle measured in front of the player, or null.
var cached_profile: ObstacleProfile = null

var current_move: TraversalMove = null
var move_elapsed := 0.0
var move_progress := 0.0
var move_windup := 0.0

var hang_normal := Vector3.ZERO
var hang_lip_y := 0.0
var is_peeking := false
var _shimmy_velocity := 0.0
## A fresh press during a catch/corner is spent once the hands settle.
var _hang_buffered_action: StringName = &""

## Where a jump would leap to from the current hang, or {}.
var hang_target := {}

## True when the crosshair rests on something that is not the wall we hang
## from. Jump then means "go there", never "pull up".
var hang_aiming_elsewhere := false

## A ledge below that we let go to fall onto, or {}.
var drop_target := {}
var _pending_drop_target := {}

var current_climb: Area3D = null
var climb_volumes: Array[Area3D] = []
## The water you are in (WaterVolume), or null; the stroke count swimming.
var water: Area3D = null
var _strokes := 0.0
## The waters the body is in (WaterVolume tells us as we go in and come out).
var _water_volumes: Array[Area3D] = []

## Distance along a simulated rope where the hands are, or -1.
var rope_param := -1.0

var scanner := TraversalScanner.new()
var planner := TraversalPlanner.new()
var juice := CameraJuice.new()

## The body under the camera: the view and the hands ride it (BodyMotion.gd).
var body_motion := BodyMotionScript.new()
## What the body feels each tick, filled in by _step_body.
var _body_frame := BodyMotionScript.Frame.new()

## The pose name and hand targets an arm rig should follow. See BodyPose.gd.
var body_pose := BodyPose.new()

var _capsule: CapsuleShape3D
var _standing_height := 2.0
var _radius := 0.5
var _collider_base_y := 0.0
var _neck_stand_y := 0.8

var _jump_hold_consumed := false
## Own edge detection for crouch, so the "climb down" check never loses a
## race with the crouch itself.
var _crouch_held_last := false
var _crouch_just_pressed := false
var _regrab_timer := 0.0
var _climb_reattach_timer := 0.0
## Area overlap lists settle after a teleport; old contacts cannot attach
## during that tick. Retain registrations for teleports within one volume.
var _teleport_contacts_until := -1
var _failed_plan_cooldown := 0.0
var _last_reject := ""
## Scans that found nothing wait this long before looking again: holding jump
## in the air, climbing toward a top, a chain looking for its next obstacle.
const RESCAN_TIME := 0.05
var _air_scan_timer := 0.0
var _climb_scan_timer := 0.0
var _chain_scan_timer := 0.0
## The step-up's collision, reused every tick rather than made anew.
var _step_blocked := KinematicCollision3D.new()

var _chain_buffered := false
var _chain_links := 0
var _move_started_sneaking := false
var _kicks_this_airtime := 0

## Releasing jump early shortens a jump, but not a wall kick.
var _jump_cut_allowed := false

## Where the walk is, in steps: a foot lands at each whole step. The
## footsteps and the head bob both go by it, so every step is heard as the
## head comes down on it. (It runs 0..2, a left and a right.)
var gait := 0.0
var _gait_before := 0.0
var _steps := 0

## How fast the body is actually moving, whatever moves it. During a
## choreographed move velocity is zero, but a vault is still fast motion.
var _motion_speed := 0.0
var _last_motion_position := Vector3.ZERO
var _step_view_offset := 0.0
var _neck_base_y := 0.8
## is_on_floor() only updates when move_and_slide runs. Moves, hangs and
## climbs bypass it, so its answer is stale until locomotion moves again.
var _floor_valid := true
var _stepped_up_this_frame := false
## True on frames where the body is riding down a step edge.
var _on_stairs := false
## The stair magnet pulled the body down onto a tread it could not be set on:
## the touchdown that follows is a step, not a landing.
var _stair_pulled := false
## After a step up, the body holds its height until its centre has passed
## the riser. Otherwise the floor snap drags it back down onto the lower
## tread and it climbs the same step twice.
var _step_lock_timer := 0.0
var _step_lock_y := 0.0
var _step_lock_from := Vector3.ZERO
## Horizontal speed before the stairs started slowing us down.
var _recent_ground_speed := 0.0
## Seconds of game time. Timing that is part of gameplay uses this, never the
## wall clock: slow motion, a hitch, or a headless test all change the wall
## clock without changing the game.
var _game_time := 0.0
## When something last hurt you (take_damage, falls, hazards).
var _hurt_at := -100.0
## What the player is asking for right now, set by horizontal movement.
var _target_ground_velocity := Vector3.ZERO
var _assist_time := 0.0
var _hang_scan_timer := 0.0
## Measured climb rate of the current staircase, for the eye follower.
var _stair_rate := 0.0
var _last_step_time := -10.0
var _last_grounded_y := 0.0
var _was_grounded := false

var _assist_active := false
var _assist_left_ground := false
var _assist_direction := Vector3.ZERO
var _assist_speed := 0.0

## Shoved: a dodge, a kick, a blast. The legs have no say until it runs out.
var _shove_velocity := Vector3.ZERO
var _shove_time := 0.0
var _shove_length := 0.0


func _ready() -> void:
	assert(collider.shape is CapsuleShape3D)

	# Guards find the player through this group, and stand on layer 2.
	add_to_group(&"player")
	collision_mask |= 2

	health = max_health
	_ensure_action(&"lean_left", KEY_Z)
	_ensure_action(&"lean_right", KEY_C)

	combat = PlayerCombat.new()
	combat.name = "Combat"
	add_child(combat)

	# Make the level's placeholder sounds now, in the background, not on the
	# first footstep.
	Sfx.warm(self)

	if show_hud:
		hud = StealthHUD.new()
		add_child(hud)
		hud.setup(self)

	# The lightgem's cameras measure light, not the level's fog and glow.
	var gem_cameras: Array[Camera3D] = []

	for viewport in find_children("*", "SubViewport", false, false):
		for camera in viewport.find_children("*", "Camera3D", false, false):
			gem_cameras.append(camera as Camera3D)

	if not gem_cameras.is_empty():
		var gem_environment := GemEnvironment.new()
		gem_environment.name = "GemEnvironment"
		add_child(gem_environment)
		gem_environment.setup(gem_cameras)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Helps the player remain attached to stairs and descending slopes.
	floor_snap_length = stair_step_height + 0.05

	# Prevents movement speed changing merely because the floor is sloped.
	floor_constant_speed = true

	# Crouching edits the capsule, so work on a private copy of the resource.
	_capsule = collider.shape.duplicate() as CapsuleShape3D
	collider.shape = _capsule

	_standing_height = _capsule.height
	_radius = _capsule.radius
	_collider_base_y = collider.position.y
	_neck_stand_y = neck.position.y
	_neck_base_y = _neck_stand_y
	crouch_height = clampf(crouch_height, _radius * 2.0 + 0.01, _standing_height)

	scanner.setup(self, _radius, _standing_height, crouch_height)
	planner.scanner = scanner
	planner.eye_height = _neck_stand_y
	juice.setup(camera)
	body_motion.setup(footfall_curve if footfall_curve != null else BodyMotionScript.default_footfall(), view_height_speed)

	# Physics interpolation draws the body between physics ticks. The camera
	# is placed by hand each frame instead (_place_camera): at the drawn body,
	# looking where you look right now, so mouse look never waits for a tick.
	# The neck only carries aim, and is never drawn itself.
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	neck.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# The level places us after we are added; start drawing from there.
	reset_physics_interpolation.call_deferred()

	if variant_table.is_empty():
		variant_table = MoveVariantRes.default_table()

	if inventory != null and hand != null:
		inventory.belt_selection_changed.connect(hand.show_item)

	if frob != null and hand != null:
		frob.picked_up.connect(func(_body): hand.set_suppressed(true))
		# Let go of what you carried: the hands come back, unless you are dead.
		frob.released.connect(func(_body, _thrown): hand.set_suppressed(is_dead))


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseMotion
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and not is_dead
	):
		var mouse_event := event as InputEventMouseMotion
		# In screen pixels: the same turn for the same hand movement whatever
		# size the window is (relative shrinks as the HUD is scaled up).
		var turn := mouse_event.screen_relative

		# The body handles horizontal rotation.
		rotate_y(-turn.x * mouse_sensitivity)

		# The neck handles vertical rotation.
		neck.rotate_x(-turn.y * mouse_sensitivity)
		neck.rotation.x = clamp(
			neck.rotation.x,
			-deg_to_rad(max_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)

	elif (
		event is InputEventKey
		and (event as InputEventKey).pressed
		and not (event as InputEventKey).echo
		and (event as InputEventKey).keycode == KEY_F10
		and OS.is_debug_build()
	):
		# Compare the movement feels (until the new one is signed off).
		set_legacy_feel(not legacy_feel)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel"):
		# Esc pauses the game and lets the mouse go; the HUD's pause screen
		# takes it back on a click.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		if hud != null:
			get_tree().paused = true

		get_viewport().set_input_as_handled()

	elif (
		event is InputEventMouseButton
		and event.pressed
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		and DisplayServer.window_is_focused()
	):
		# Esc let the mouse go; a click in the window takes it back.
		_recapture_mouse()
		get_viewport().set_input_as_handled()


## The click that takes the mouse back is only that. Mouse-button actions
## (the blackjack, throwing) ignore the next few frames.
var _swallow_mouse_until := -1


## The old movement feel on or off (F10): the body under the view starts
## afresh, and the HUD says which feel you are on.
func set_legacy_feel(on: bool) -> void:
	legacy_feel = on
	body_motion.reset()

	if hud != null and hud.has_method("show_caption"):
		hud.show_caption("Movement: old" if on else "Movement: new", 1.6)


func _recapture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_swallow_mouse_until = Engine.get_physics_frames() + 3


func is_mouse_input_swallowed() -> bool:
	return Engine.get_physics_frames() <= _swallow_mouse_until


## A press of the attack button already used for something else: throwing
## what you held, swinging the blackjack. Combat must not read the same press
## as a blow, so it stays spent until the button comes back up.
var _attack_press_spent := false


func spend_attack_press() -> void:
	_attack_press_spent = true


func is_attack_press_spent() -> bool:
	if _attack_press_spent and not Input.is_action_pressed("throw"):
		_attack_press_spent = false

	return _attack_press_spent


func _sync_held_exclusion() -> void:
	scanner.extra_exclude.clear()

	if frob != null and frob.held != null and is_instance_valid(frob.held):
		scanner.extra_exclude.append(frob.held.get_rid())


## Where the head really is: the neck, leaning included, without any of the
## camera's bob, shake, punch or smoothing. Gameplay aims from here.
func aim_transform() -> Transform3D:
	var basis := neck.global_transform.basis.orthonormalized()
	return Transform3D(basis, neck.global_transform * Vector3(juice.lean_offset, 0.0, 0.0))


func _physics_process(delta: float) -> void:
	_game_time += delta
	_step_change_tick = 0.0
	_sync_held_exclusion()

	if is_dead:
		# No more control, but still a body: it falls and comes to rest.
		if movement_state == MoveState.LOCOMOTION:
			_stop_on_death(delta)

		_step_body(delta)
		return

	_track_motion(delta)
	_update_jump_windows(delta)
	_update_timers(delta)
	_recover(delta)
	_sync_scanner()
	_update_water()

	# A shove is spent on the ground; a climb or a hang ends it, rather than
	# leaving it to push when the move is over.
	if movement_state != MoveState.LOCOMOTION:
		_shove_time = 0.0

	match movement_state:
		MoveState.MOVING:
			_update_move(delta)
		MoveState.HANGING:
			_update_hang(delta)
		MoveState.CLIMBING:
			_update_climb(delta)
		MoveState.SWIMMING:
			_update_swim(delta)
		_:
			_update_locomotion(delta)

	_climb_sounds()

	if debug_traversal:
		_debug_draw()

	_step_body(delta)


func _process(delta: float) -> void:
	_update_view(delta)
	body_pose.update(self, delta)


## The body under the camera feels this tick: how it moves, where the walk
## is, the stance and the lean (BodyMotion.gd). (A teleport needs no care:
## its one-tick jump in velocity is capped like any push, and one tick of
## push barely moves the torso.)
func _step_body(delta: float) -> void:
	var frame := _body_frame
	frame.velocity = velocity
	frame.facing = global_basis
	frame.grounded = _on_floor_now() or _on_stairs
	frame.locomotion = movement_state == MoveState.LOCOMOTION and not is_dead
	frame.crouched = is_crouched
	frame.gait = gait
	frame.lean = lean
	frame.eye_drop = _neck_stand_y - _neck_base_y
	frame.eye_target_drop = (_standing_height - crouch_height) if is_crouched else 0.0
	frame.walk_speed = walk_speed
	frame.sprint_speed = sprint_speed
	frame.crouch_speed = crouch_speed
	body_motion.intensity = camera_feel
	body_motion.step(delta, frame)


# ---------------------------------------------------------------------------
# Locomotion
# ---------------------------------------------------------------------------

func _update_locomotion(delta: float) -> void:
	var wish_direction := _wish_direction()
	var facing_direction := _facing_direction()
	var grounded := _on_floor_now()

	if _update_crouch():
		return

	if not drop_target.is_empty() and _update_drop_catch():
		return

	# The player must be pushing toward what they are looking at.
	var forward_intent := wish_direction.dot(facing_direction) > min_forward_input

	var jump_pressed := Input.is_action_just_pressed("jump")
	var air_hold := (
		not grounded
		and Input.is_action_pressed("jump")
		and not _jump_hold_consumed
		and velocity.y < air_grab_max_rise
	)

	# A scan is two dozen physics queries: only run it when a jump could use
	# it, or when the debug overlay is showing it.
	cached_profile = null

	if forward_intent and (jump_pressed or (air_hold and _air_scan_timer <= 0.0) or debug_traversal):
		cached_profile = scanner.scan(facing_direction, velocity, not grounded)

		# Held in the air with nothing there: look again in a moment, not
		# every tick.
		if air_hold and not jump_pressed and cached_profile == null:
			_air_scan_timer = RESCAN_TIME

	var can_grab := (
		_regrab_timer <= 0.0
		and _failed_plan_cooldown <= 0.0
		and velocity.y > -maximum_grab_fall_speed
	)

	# Both hands on a crate: no climbing until you put it down.
	if _is_carrying():
		can_grab = false

	# Walking handles stairs. On a staircase the capsule rides the step edges
	# above the tread, so every measurement is off: a jump pressed there is a
	# jump. A staircase is several steps in a row (a measured climb rate), not
	# one step off a kerb or a roof edge. Once properly airborne, holding jump
	# can still grab a ledge, and climbing down from an edge is never blocked.
	var on_staircase := (
		_stair_rate > 0.0
		and _game_time - _last_step_time < 0.4
	)
	var stairs_jump := jump_pressed and on_staircase

	if forward_intent and can_grab and (jump_pressed or air_hold):
		if cached_profile != null and not stairs_jump and _try_traversal(cached_profile):
			return

		if OS.has_environment("TRAV_DEBUG") and jump_pressed:
			var why := scanner.last_reject if cached_profile == null else _last_reject
			print("press refused: ", why, "  grounded=", grounded, " crouched=", is_crouched)

		# Crouched at a drop with nothing to climb: lower over the edge.
		if jump_pressed and grounded and is_crouched and _try_lower(facing_direction):
			return

		# Something was there and could not be climbed: do not retry it
		# every frame. Nothing there at all needs no cooldown.
		if cached_profile != null:
			_failed_plan_cooldown = 0.1

	if _try_enter_climb(wish_direction):
		return

	if grounded:
		_kicks_this_airtime = 0

	# A second press in the air, beside a wall, with nothing to climb: kick off it.
	if (
		jump_pressed
		and not grounded
		and coyote_timer <= 0.0
		and not is_crouched
		and not _is_carrying()
		and _kicks_this_airtime < max_wall_kicks
	):
		_try_wall_kick(facing_direction)

	_update_jump_assist(wish_direction, grounded)
	_try_buffered_jump()
	_apply_horizontal_movement(wish_direction, delta)
	_apply_vertical_movement(delta)

	var fall_speed := -velocity.y
	var y_before := global_position.y

	_stepped_up_this_frame = false
	_on_stairs = false

	# A jump is not a step: it ends any lock and skips stepping this frame.
	var jumping := velocity.y > 0.5

	if jumping:
		_step_lock_timer = 0.0
		_stair_pulled = false

	var step_locked := _advance_step_lock(delta)

	if step_locked:
		# Hold the stepped-up height; slide forward onto the tread.
		_on_stairs = true
		velocity.y = 0.0
		global_position.y = _step_lock_y

	# Keep stepping while locked: on short treads the next riser is already
	# touching the capsule before the last step is finished.
	if (grounded or coyote_timer > 0.0 or step_locked) and not jumping:
		_try_step_up(delta)

	if grounded and not _stepped_up_this_frame and not step_locked:
		var ground_speed := Vector3(velocity.x, 0.0, velocity.z).length()
		_recent_ground_speed = maxf(ground_speed, _recent_ground_speed - 12.0 * delta)

	# After a hang, climb or move, the body's floor state is stale, and the
	# floor snap would pull it onto whatever is below. Skip it that frame.
	if _floor_valid and not step_locked and not _stepped_up_this_frame:
		floor_snap_length = stair_step_height + 0.05
	else:
		floor_snap_length = 0.0

	LanternBody.slide_character(self)
	_floor_valid = true

	if step_locked or _stepped_up_this_frame:
		global_position.y = _step_lock_y
		velocity.y = 0.0
		coyote_timer = coyote_time
	elif coyote_timer > 0.0:
		# Keep trying for the coyote window: the capsule needs a few frames to
		# roll clear of the edge before it can fit on the tread below.
		_try_step_down()

	# Landing on someone: combat may have a drop attack waiting.
	if is_on_floor() and not grounded and combat != null:
		combat.on_landed(fall_speed)

	# Pulled down onto the next tread by the stair magnet: that is a step.
	if is_on_floor() and _stair_pulled:
		_stair_pulled = false

		if not grounded and fall_speed < stair_magnet_speed + 2.0:
			_on_stairs = true

	if is_on_floor() and not grounded and fall_speed > 3.0 and not _on_stairs:
		if legacy_feel:
			juice.on_land(fall_speed)

			if hand != null and hand.has_method("land"):
				hand.land(fall_speed)
		else:
			# The legs take it (and the arms keep falling a moment): the body.
			body_motion.on_land(fall_speed)

		# What guards hear, you hear: the thud, the floor it was on, and on a
		# hard landing a puff of whatever the floor is made of.
		var surface := _surface_name()
		var landing_db := minf(landing_db_base + fall_speed * landing_db_per_speed, landing_db_max) + float(surface_db.get(surface, 0.0))
		_make_noise(landing_db, &"landing")
		Sfx.play_flat(self, _land_sound(surface), Sfx.loudness(landing_db))

		# Coming down hard: your whole weight in it.
		if fall_speed > 7.0:
			Sfx.play_flat(self, &"body_fall", Sfx.loudness(landing_db) - 8.0, 1.1)
			Sfx.play_flat(self, &"cloth", Sfx.loudness(landing_db) - 6.0)

		if fall_speed > 5.5:
			Fx.dust(self, get_feet_position() + Vector3.UP * 0.05, Vector3.UP, clampf((fall_speed - 4.0) / 6.0, 0.3, 1.2), surface if surface != "" else "stone")

		if fall_speed > fall_damage_speed:
			take_damage((fall_speed - fall_damage_speed) * fall_damage_per_speed, null)

	_update_footsteps()

	_smooth_ground_steps(y_before, grounded or step_locked)


func _wish_direction() -> Vector3:
	var input_axis := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var wish_direction := (
		global_transform.basis
		* Vector3(input_axis.x, 0.0, input_axis.y)
	)

	wish_direction.y = 0.0
	return wish_direction.normalized()


func _facing_direction() -> Vector3:
	var facing_direction := -global_transform.basis.z
	facing_direction.y = 0.0
	return facing_direction.normalized()


func _is_sprinting() -> bool:
	return Input.is_action_pressed("sprint") and not is_crouched


func _on_floor_now() -> bool:
	return is_on_floor() and _floor_valid


func _update_jump_windows(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	if _on_floor_now():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)


func _update_timers(delta: float) -> void:
	_regrab_timer = maxf(_regrab_timer - delta, 0.0)
	_climb_reattach_timer = maxf(_climb_reattach_timer - delta, 0.0)
	_failed_plan_cooldown = maxf(_failed_plan_cooldown - delta, 0.0)
	_air_scan_timer = maxf(_air_scan_timer - delta, 0.0)
	_climb_scan_timer = maxf(_climb_scan_timer - delta, 0.0)
	_chain_scan_timer = maxf(_chain_scan_timer - delta, 0.0)

	# A held jump may trigger one traversal. The next needs a fresh press.
	if not Input.is_action_pressed("jump"):
		_jump_hold_consumed = false

	var crouch_now := Input.is_action_pressed("crouch")
	_crouch_just_pressed = crouch_now and not _crouch_held_last
	_crouch_held_last = crouch_now


func _try_buffered_jump() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if coyote_timer <= 0.0:
		return

	velocity.y = jump_speed
	_jump_cut_allowed = true

	jump_buffer_timer = 0.0
	coyote_timer = 0.0

	Sfx.play_flat(self, _jump_sound(_surface_name()), Sfx.loudness(footstep_db_walk + _surface_offset()))

	if legacy_feel:
		juice.on_jump()

		if hand != null and hand.has_method("jump"):
			hand.jump()
	else:
		body_motion.on_jump()

	if jump_assist and not is_crouched:
		_try_jump_assist()


func _apply_horizontal_movement(
	wish_direction: Vector3,
	delta: float
) -> void:
	var target_speed := walk_speed
	var shouldering: bool = frob != null and frob.is_shouldering()
	var fighting_scale: float = combat.speed_scale() if combat != null else 1.0

	if is_crouched:
		target_speed = crouch_speed
	elif Input.is_action_pressed("sprint") and not shouldering and fighting_scale >= 1.0:
		target_speed = sprint_speed

	if shouldering:
		target_speed *= shoulder_speed_scale

	# A raised guard, a charged blow or a drawn bow: slower, and no sprinting.
	target_speed *= fighting_scale

	# Wading: the deeper, the slower.
	target_speed *= wade_scale()

	# Shoved (a dodge, a kick, a blast): carried along, easing off.
	if _shove_time > 0.0:
		var k := _shove_time / maxf(_shove_length, 0.001)
		var carried := _shove_velocity * (0.35 + 0.65 * k)
		velocity.x = carried.x
		velocity.z = carried.z
		_shove_time -= delta
		return

	# An assisted jump holds its solved speed until it lands or is cancelled.
	if _assist_active:
		velocity.x = _assist_direction.x * _assist_speed
		velocity.z = _assist_direction.z * _assist_speed
		return

	var target_velocity := wish_direction * target_speed
	_target_ground_velocity = target_velocity
	var horizontal_velocity := Vector3(
		velocity.x,
		0.0,
		velocity.z
	)

	if (_on_floor_now() or _on_stairs) and legacy_feel:
		var acceleration := ground_acceleration

		if wish_direction == Vector3.ZERO:
			acceleration = ground_deceleration

		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			acceleration * delta
		)

	elif _on_floor_now() or _on_stairs:
		horizontal_velocity = _ground_velocity(horizontal_velocity, wish_direction, target_speed, delta)

	elif wish_direction != Vector3.ZERO:
		# With no air input, momentum is preserved.
		# With input, the player can redirect gradually.
		horizontal_velocity = horizontal_velocity.move_toward(
			target_velocity,
			air_acceleration * delta
		)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


## Momentum on the ground, at the same speeds. Along the way you want to go,
## the push closes the gap to `target_speed` in proportion to it (hardest from
## a standstill, easing off near the pace; more slowly above walking pace, so
## a sprint gathers); moving faster than asked eases off. Speed across the way
## you want to go is taken away quickly at walking pace and less quickly at a
## sprint, so a hard turn carves a little. With no input, a planted stop.
func _ground_velocity(current: Vector3, wish: Vector3, target_speed: float, delta: float) -> Vector3:
	var pace := clampf((current.length() - walk_speed) / maxf(sprint_speed - walk_speed, 0.01), 0.0, 1.0)

	if wish == Vector3.ZERO:
		var stop_time := lerpf(stop_time_walk, stop_time_sprint, pace)
		var reference := lerpf(walk_speed, sprint_speed, pace)
		return current.move_toward(Vector3.ZERO, reference / maxf(stop_time, 0.01) * delta)

	var along := current.dot(wish)
	var across := current - wish * along
	var gap := target_speed - along

	if gap > 0.0:
		var build := start_time if along < walk_speed - 0.01 else sprint_build_time
		var push := clampf(gap / maxf(build, 0.01), 2.0, max_ground_acceleration)
		along = minf(along + push * delta, target_speed)
	elif gap < 0.0:
		var easing := clampf(-gap / maxf(slow_time, 0.01), 2.0, max_ground_acceleration)
		along = maxf(along - easing * delta, target_speed)

	# Speed across the way you want to go goes in proportion, the way the
	# push closes its gap, and never faster than the turn allows. (Against a
	# wall that speed is the slide along it, made again every tick; taken
	# away at a flat rate it braked the slide to a crawl.)
	var turn := lerpf(turn_acceleration_walk, turn_acceleration_sprint, pace)
	var shed := clampf(across.length() / maxf(start_time, 0.01), 2.0, turn)
	across = across.move_toward(Vector3.ZERO, shed * delta)

	# Never faster than the pace asked for, or than you already were.
	return (wish * along + across).limit_length(maxf(target_speed, current.length()))


func _apply_vertical_movement(delta: float) -> void:
	if Input.is_action_just_released("jump") and velocity.y > 0.0 and _jump_cut_allowed:
		velocity.y *= jump_cut_multiplier
		_jump_cut_allowed = false
		# A shorter jump lands short of where the assist aimed it.
		_assist_active = false

	if _on_floor_now() and velocity.y <= 0.0:
		# A small downward velocity helps maintain floor contact.
		velocity.y = -0.5
		return

	var applied_gravity := gravity

	if velocity.y < 0.0:
		applied_gravity *= fall_gravity_multiplier

	velocity.y = max(
		velocity.y - applied_gravity * delta,
		-maximum_fall_speed
	)


# ---------------------------------------------------------------------------
# Stealth: what guards can see and hear of the player
# ---------------------------------------------------------------------------

func _track_motion(delta: float) -> void:
	var moved := global_position.distance_to(_last_motion_position)
	_last_motion_position = global_position

	# A teleport is not movement.
	if delta <= 0.0 or moved > sprint_speed * 3.0 * delta:
		return

	_motion_speed = lerpf(_motion_speed, moved / delta, 1.0 - exp(-12.0 * delta))


func get_feet_position() -> Vector3:
	return global_position - Vector3.UP * _standing_height * 0.5


## Where your climb comes out, for a guard after you (Guard.goal_of): up a
## ladder or a rope, its top (going down it, its foot); hanging off an edge,
## over it; pulling yourself over one, where the move ends. INF on your feet
## (or swimming).
func climb_goal() -> Vector3:
	match movement_state:
		MoveState.CLIMBING:
			if current_climb != null and is_instance_valid(current_climb) and current_climb.has_method("ends"):
				var ends: Array = current_climb.ends()
				return ends[0] if velocity.y < -0.3 else ends[1]
		MoveState.HANGING:
			return Vector3(global_position.x, hang_lip_y + 0.2, global_position.z) - hang_normal * 0.6
		MoveState.MOVING:
			if current_move != null and current_move.points.size() > 0:
				return current_move.points[current_move.points.size() - 1] - Vector3.UP * _standing_height * 0.5

	return Vector3.INF


## Off your feet: on a ladder, hanging, mid-vault or mantle, or in the air
## (not swimming). A guard who last saw you so knows where you come down
## (Guard._follow_through).
func is_off_feet() -> bool:
	match movement_state:
		MoveState.MOVING, MoveState.HANGING, MoveState.CLIMBING:
			return true
		MoveState.LOCOMOTION:
			return not (_on_floor_now() or _on_stairs)

	return false


## How lit the player is, 0..1: the lightgem when there is one.
func get_light_level() -> float:
	if light_gem != null and is_instance_valid(light_gem):
		return clampf(float(light_gem.value), 0.0, 1.0)

	return debug_light_level


## How easy the player is to see, 0..1. Guards multiply this by distance,
## view cone and cover. Light dominates; stance and movement nudge it.
func get_exposure() -> float:
	var light := get_light_level()
	var speed := maxf(Vector3(velocity.x, 0.0, velocity.z).length(), _motion_speed)
	var moving := clampf(speed / maxf(walk_speed, 0.01), 0.0, 1.3)
	var stance := crouch_exposure if is_crouched else 1.0

	# Afloat, only your head is out of the water; under it, you are murk.
	if movement_state == MoveState.SWIMMING and water != null:
		stance = float(water.clarity) if is_underwater() else 0.6

	return clampf(light * stance * (1.0 + motion_exposure * moving), 0.0, 1.0)


## The points a guard aims sight rays at: head, chest, shins. Cover that
## hides some of them hides that fraction of you.
func get_sight_points() -> Array:
	var feet := global_position - Vector3.UP * _standing_height * 0.5
	var height := crouch_height if is_crouched else _standing_height

	# Leaning puts the head, and only the head, out past the corner.
	var head_shift := global_transform.basis.x * lean * lean_distance
	return [
		feet + Vector3.UP * height * 0.88 + head_shift,
		feet + Vector3.UP * height * 0.55,
		feet + Vector3.UP * height * 0.18,
	]


func _make_noise(db: float, kind: StringName) -> void:
	var feet := global_position - Vector3.UP * _standing_height * 0.5
	SoundBus.emit_sound(feet, db, self, kind)


func _update_footsteps() -> void:
	_gait_before = gait

	if not (_on_floor_now() or _on_stairs):
		return

	var speed := Vector3(velocity.x, 0.0, velocity.z).length()

	# Stopped, the walk waits where it is: the next foot comes down on the
	# next whole step.
	if speed < 0.4:
		return

	var stride := LEGACY_STRIDE_WALK if legacy_feel else stride_walk
	var db := footstep_db_walk
	var running := false

	if is_crouched:
		stride = stride_crouch
		db = footstep_db_crouch
	elif speed > walk_speed + 0.5:
		stride = LEGACY_STRIDE_SPRINT if legacy_feel else stride_sprint
		db = footstep_db_sprint
		running = true

	gait += speed / stride * get_physics_process_delta_time()

	if gait >= float(_steps + 1):
		_steps = int(floor(gait))

		if _steps >= 2:
			_steps -= 2
			gait -= 2.0
			_gait_before -= 2.0

		if frob != null and frob.is_shouldering():
			db += shoulder_noise_db

		# The step guards hear is the step you hear, as loud and on the same
		# floor.
		var surface := _surface_name()
		var step_db := db + float(surface_db.get(surface, 0.0))
		_make_noise(step_db, &"footstep")
		Sfx.play_flat(self, _step_sound(surface, running), Sfx.loudness(step_db))

		# What you carry moves with you: cloth under the step, more of it at
		# a run, none when you creep; at a run your gear knocks on the same
		# hip every other step.
		if not is_crouched and randf() < (0.7 if running else 0.35):
			Sfx.play_flat(self, &"cloth", Sfx.loudness(step_db) - 9.0, randf_range(0.95, 1.1))

		if running and _steps == 1 and randf() < 0.75:
			Sfx.play_flat(self, &"gear", Sfx.loudness(step_db) - 7.0, randf_range(0.94, 1.06))


## What the floor under the feet is made of, as a loudness change in dB.
func _surface_offset() -> float:
	return float(surface_db.get(_surface_name(), 0.0))


## The floor under the feet: "stone", "wood", "metal", "grass", "carpet"...
## or "" when it does not say.
func _surface_name() -> String:
	var feet := global_position - Vector3.UP * _standing_height * 0.5

	# In water over the ankles, it is water you step in; in a puddle after
	# rain (Night), too.
	if water != null and water.depth_of(feet) > 0.1:
		return "water"

	var night := get_tree().get_first_node_in_group(&"night")

	if night != null and night.splashes_at(feet):
		return "water"

	var under := scanner.ray(feet + Vector3.UP * 0.2, feet - Vector3.UP * 0.4)

	if under.is_empty():
		return ""

	var floor_body: Object = under.get("collider")

	if floor_body == null or not floor_body.has_meta(&"surface"):
		return ""

	return String(floor_body.get_meta(&"surface"))


## A step on `surface`: at a walk, or at a run (Sfx.step).
static func _step_sound(surface: String, running := false) -> StringName:
	return Sfx.step(surface, running)


static func _jump_sound(surface: String) -> StringName:
	return Sfx.step(surface, false, "jump")


static func _land_sound(surface: String) -> StringName:
	return Sfx.step(surface, false, "land")


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

func take_damage(amount: float, from: Node) -> void:
	if is_dead or amount <= 0.0:
		return

	# Whoever it was may be gone by now (an arrow's archer, killed).
	if not is_instance_valid(from):
		from = null

	# A raised guard takes most of a blow, or, just in time, all of it.
	if combat != null:
		amount = combat.filter_incoming(amount, from)

	if invulnerable or amount <= 0.0:
		return

	health = maxf(health - amount, 0.0)
	_hurt_at = _game_time
	# A heavy one deadens your hearing for a moment.
	Sfx.body_hit(amount)

	# The blow's weight: a freeze, the head snapped away from it, a spray.
	if combat != null and combat.has_method("on_hurt"):
		combat.on_hurt(amount, from)
	else:
		juice.on_hit()

	damaged.emit(amount)

	if health <= 0.0:
		_die()


## Left alone long enough, the shield you are in fills again.
func _recover(delta: float) -> void:
	if health <= 0.0 or health >= max_health or _game_time - _hurt_at < recover_delay:
		return

	var shield := max_health / float(maxi(shields, 1))
	var top := ceilf(health / shield - 0.001) * shield
	health = minf(health + recover_rate * delta, minf(top, max_health))


## The top of the shield `health` is in: as far as rest brings it back.
func recover_limit() -> float:
	var shield := max_health / float(maxi(shields, 1))
	return minf(ceilf(health / shield - 0.001) * shield, max_health)


## Spikes and the like: running into them hurts; flung into them, worse.
func hazard_hit(_hazard: Node, lethal_speed: float) -> void:
	if _hazard_cooldown > _game_time:
		return

	var speed := Vector3(velocity.x, 0.0, velocity.z).length()

	# Into it, not along it.
	if _hazard != null and _hazard.has_method("into_speed"):
		speed = _hazard.into_speed(velocity)

	if speed > lethal_speed:
		_hazard_cooldown = _game_time + 1.0
		take_damage(40.0, null)


func _stop_on_death(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, ground_deceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z

	if _on_floor_now() and velocity.y <= 0.0:
		velocity.y = -0.5
	else:
		velocity.y = maxf(velocity.y - gravity * fall_gravity_multiplier * delta, -maximum_fall_speed)

	LanternBody.slide_character(self)
	_floor_valid = true


func _die() -> void:
	is_dead = true

	if hand != null and hand.has_method("set_suppressed"):
		hand.set_suppressed(true)

	velocity = Vector3(0.0, minf(velocity.y, 0.0), 0.0)

	if frob != null:
		frob.drop_held()

	# Whatever you were holding on to, you let go.
	match movement_state:
		MoveState.CLIMBING:
			_leave_climb(Vector3.ZERO)
		MoveState.HANGING:
			movement_state = MoveState.LOCOMOTION
		MoveState.MOVING:
			current_move = null
			movement_state = MoveState.LOCOMOTION
		MoveState.SWIMMING:
			# Nothing keeps a dead man afloat: he sinks.
			movement_state = MoveState.LOCOMOTION

	died.emit()

	if reload_on_death:
		# A paused game waits: pressing Esc while dead must not reload behind
		# the pause screen.
		await get_tree().create_timer(2.0, false).timeout

		if is_inside_tree():
			get_tree().reload_current_scene()


## Registers an input action at runtime if the project does not define it.
func _ensure_action(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return

	InputMap.add_action(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)


# ---------------------------------------------------------------------------
# Stairs
# ---------------------------------------------------------------------------

## A wet step uses the same hold as a dry one, until the capsule crosses it.
func _advance_step_lock(delta: float) -> bool:
	if _step_lock_timer > 0.0:
		_step_lock_timer -= delta
		var travelled := Vector3(global_position.x - _step_lock_from.x, 0.0, global_position.z - _step_lock_from.z).length()
		if travelled >= _radius + 0.05:
			_step_lock_timer = 0.0
	return _step_lock_timer > 0.0


## move_and_slide treats a step's riser as a wall. When a riser blocks us and
## there is room above it, lift the body so the slide carries it onto the tread
## and the floor snap settles it.
func _try_step_up(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if horizontal.length_squared() < 0.01:
		return

	var forward := horizontal.normalized()
	var motion := horizontal * delta
	var blocked := _step_blocked

	if not test_move(global_transform, motion, blocked):
		return

	# A walkable slope is not a step; the slide handles it. A step's edge
	# meets the capsule's rounded bottom at an angle, so be strict here.
	if blocked.get_normal().y > 0.75:
		return

	# Read the tread height just past the point of contact.
	var feet_y := global_position.y - _standing_height * 0.5
	var probe := blocked.get_position() + forward * 0.06
	var tread := scanner.ray(
		Vector3(probe.x, feet_y + stair_step_height + 0.02, probe.z),
		Vector3(probe.x, feet_y - 0.01, probe.z),
		false
	)

	if tread.is_empty():
		return

	var tread_point: Vector3 = tread["position"]
	var tread_normal: Vector3 = tread["normal"]
	var rise := tread_point.y - feet_y

	if rise < 0.02 or rise > stair_step_height or tread_normal.y < 0.7:
		return

	var lift := Vector3.UP * (rise + 0.01)

	# Room to rise, and clear to move forward once risen.
	if test_move(global_transform, lift):
		return

	if test_move(global_transform.translated(lift), motion + forward * 0.02):
		return

	global_position += lift
	velocity.y = 0.0
	_stepped_up_this_frame = true
	_on_stairs = true

	# Stairs do not slow you down: the riser that blocked us ate our speed,
	# so hand back the speed we arrived with. But only as much of it as the
	# player is still asking for: let go, turn back or crouch, and it is gone.
	var asked := maxf(_target_ground_velocity.dot(forward), 0.0)
	var kept := maxf(horizontal.length(), minf(_recent_ground_speed * 0.95, asked))
	velocity.x = forward.x * kept
	velocity.z = forward.z * kept

	# Hold this height until the centre of the capsule is over the tread.
	_step_lock_timer = 0.35
	_step_lock_from = global_position
	_step_lock_y = global_position.y
	_note_step(rise)


## Walking off a step, the capsule's rounded bottom rolls over the edge and
## loses the floor for a few frames. If a tread is right there below, set the
## body down on it instead of letting it fall.
func _try_step_down() -> void:
	if is_on_floor() or velocity.y > 0.0 or velocity.y < -stair_magnet_speed - 0.5:
		return

	var feet_y := global_position.y - _standing_height * 0.5
	var below := scanner.ray(
		Vector3(global_position.x, feet_y + 0.05, global_position.z),
		Vector3(global_position.x, feet_y - (stair_step_height + 0.05), global_position.z),
		false
	)

	if below.is_empty():
		return

	var below_normal: Vector3 = below["normal"]

	if below_normal.y < 0.7:
		return

	var below_point: Vector3 = below["position"]
	var target := scanner.origin_for_feet(below_point)
	var drop := global_position.y - target.y

	if drop < 0.02 or drop > stair_step_height + 0.05:
		return

	_on_stairs = true

	# Set down onto the tread when the capsule fits there. On short treads
	# it never quite does, because the capsule is wider than a tread, so
	# instead pull it down hard and let the edge contact resolve.
	if scanner.fits(target, is_crouched):
		global_position = target
		velocity.y = -0.5
		apply_floor_snap()
		_note_step(-drop)
		return

	velocity.y = minf(velocity.y, -stair_magnet_speed)
	_stair_pulled = true


## Remember how fast this staircase climbs, so the eyes can follow it at
## exactly that rate: a straight line instead of a wobble on every step.
func _note_step(rise: float) -> void:
	var now := _game_time
	var since := now - _last_step_time
	_last_step_time = now

	if since > 0.02 and since < 0.6:
		var rate := absf(rise) / since
		_stair_rate = rate if _stair_rate <= 0.0 else lerpf(_stair_rate, rate, 0.5)
	else:
		_stair_rate = 0.0


## Steps up and down move the body in one frame. The eyes catch up smoothly.
func _smooth_ground_steps(y_before: float, was_grounded: bool) -> void:
	var grounded := is_on_floor() or _on_stairs

	if grounded and was_grounded:
		var change := global_position.y - y_before

		if absf(change) > 0.04 and absf(change) <= stair_step_height + 0.15:
			_step_view_offset -= change
			_step_change_tick += change

	_was_grounded = grounded


# ---------------------------------------------------------------------------
# Wall kick
# ---------------------------------------------------------------------------

func _try_wall_kick(facing_direction: Vector3) -> bool:
	var best_normal := Vector3.ZERO
	var best_distance := INF

	# A small fan of rays, so a wall beside you counts as well as one ahead.
	for degrees in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		var direction := facing_direction.rotated(Vector3.UP, deg_to_rad(degrees))
		var hit := scanner.ray(
			global_position,
			global_position + direction * (_radius + wall_kick_reach)
		)

		if hit.is_empty():
			continue

		var raw_normal: Vector3 = hit["normal"]

		if absf(raw_normal.y) > scanner.max_wall_normal_y:
			continue

		var hit_point: Vector3 = hit["position"]
		var distance := global_position.distance_to(hit_point)

		if distance < best_distance:
			best_distance = distance
			best_normal = Vector3(raw_normal.x, 0.0, raw_normal.z).normalized()

	if best_distance == INF:
		return false

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	# Keep the motion along the wall, drop the part going into it.
	var along := horizontal - best_normal * minf(horizontal.dot(best_normal), 0.0)

	# Head-on, stay close to the wall so the ledge above is still in reach.
	var frontal := maxf(facing_direction.dot(-best_normal), 0.0)
	var push := wall_kick_push * (1.0 - 0.75 * frontal)

	velocity = along * wall_kick_speed_kept + best_normal * push
	# Never take height away: a kick while still rising keeps the rise.
	velocity.y = maxf(velocity.y, wall_kick_up)
	_jump_cut_allowed = false

	_kicks_this_airtime += 1
	_assist_active = false
	jump_buffer_timer = 0.0
	juice.on_kick()
	return true


# ---------------------------------------------------------------------------
# Assisted jump
# ---------------------------------------------------------------------------

func _try_jump_assist() -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal.length()

	if speed < 2.0:
		return

	var direction := horizontal / speed
	var target := scanner.find_jump_target(
		direction,
		jump_assist_min_distance,
		jump_assist_max_distance,
		jump_assist_max_rise,
		jump_assist_max_drop
	)

	if target.is_empty():
		return

	var landing: Vector3 = target["point"]
	var distance: float = target["distance"]
	var airtime := _jump_airtime(landing.y - scanner.feet_position().y)

	if airtime <= 0.0:
		return

	var needed := distance / airtime

	# Only a nudge. A jump that needs more than that is the player's to miss.
	if absf(needed - speed) > speed * jump_assist_tolerance:
		return

	_assist_active = true
	_assist_left_ground = false
	_assist_time = 0.0
	_assist_direction = direction
	_assist_speed = needed

	if debug_traversal:
		DebugDraw3D.draw_sphere(landing, 0.12, Color.MAGENTA, 1.0)


## Seconds until the feet come back down to `height_change` relative to the
## take-off height. Simulated with the same gravity rules the jump really
## uses, so it stays right whenever those are retuned.
func _jump_airtime(height_change: float) -> float:
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var height := 0.0
	var vertical := jump_speed

	for i in range(300):
		var applied := gravity

		if vertical < 0.0:
			applied *= fall_gravity_multiplier

		vertical = maxf(vertical - applied * step, -maximum_fall_speed)
		height += vertical * step

		if vertical < 0.0 and height <= height_change:
			return step * float(i + 1)

	return -1.0


func _update_jump_assist(wish_direction: Vector3, grounded: bool) -> void:
	if not _assist_active:
		return

	if not grounded:
		_assist_left_ground = true

	# A jump that never left the ground (cancelled on the same frame) must not
	# leave the assist steering the player along the floor.
	_assist_time += get_physics_process_delta_time()
	var landed := grounded and (_assist_left_ground or _assist_time > 0.2)
	var steering_away := wish_direction.length() > 0.3 and wish_direction.dot(_assist_direction) < 0.7

	# (A jump cut short ends it where the cut happens: a buffered jump pressed
	# and let go before landing is a full jump, held or not.)
	if landed or steering_away:
		_assist_active = false


# ---------------------------------------------------------------------------
# Crouch
# ---------------------------------------------------------------------------

## True when a crouch press started climbing down instead: the rest of the
## frame's locomotion must then not run.
func _update_crouch() -> bool:
	var wants_crouch := Input.is_action_pressed("crouch")

	# Standing at an edge, looking down over it: crouch means climb down.
	if (
		_crouch_just_pressed
		and not is_crouched
		and _on_floor_now()
		and neck.rotation.x < -deg_to_rad(lower_look_down_degrees)
		and _try_lower(_facing_direction())
	):
		return true

	if wants_crouch and not is_crouched:
		_set_crouched(true)
	elif not wants_crouch and is_crouched and _can_stand():
		_set_crouched(false)

	return false


func _can_stand() -> bool:
	return scanner.fits(global_position, false)


func _set_crouched(crouched: bool) -> void:
	if is_crouched == crouched:
		return

	is_crouched = crouched

	# The weight settling as you drop, or pushing up as you rise. (The body
	# under the view does this itself, from the eye's new height.)
	if legacy_feel and juice != null and juice.has_method("on_crouch"):
		juice.on_crouch(crouched)

	var height := crouch_height if crouched else _standing_height
	_capsule.height = height

	# The body origin stays where it is; the capsule shrinks from the top, so
	# its center moves down and the feet stay planted.
	collider.position.y = _collider_base_y - (_standing_height - height) * 0.5


# ---------------------------------------------------------------------------
# Traversal: choosing and starting a move
# ---------------------------------------------------------------------------

func _sync_scanner() -> void:
	# Copied every frame so the values can be tuned live in the Remote tree.
	scanner.mask = traversal_mask
	scanner.step_height = step_height
	scanner.max_reach = max_reach
	scanner.scan_distance = scan_distance


func _try_traversal(profile: ObstacleProfile, chained := false) -> bool:
	var candidates := planner.classify(
		profile,
		is_crouched,
		_is_sprinting(),
		variant_table
	)

	if candidates.is_empty():
		_last_reject = "no variant matches height %.2f" % profile.height
		return false

	for variant in candidates:
		var move := planner.generate(profile, variant, global_position)

		if move != null:
			_start_move(move, chained)
			return true

		_last_reject = planner.last_reject

	return false


func _try_lower(facing_direction: Vector3) -> bool:
	if _is_carrying():
		return false

	# Room needed under the lip for the whole hanging body.
	var needed_drop := (
		planner.hang_eye_drop
		+ _neck_stand_y
		+ _standing_height * 0.5
		+ 0.1
	)

	var edge := scanner.edge_below(facing_direction, needed_drop)

	if edge.is_empty():
		return false

	var move := planner.lower(edge, global_position, rotation.y)

	if move == null:
		_last_reject = planner.last_reject
		return false

	_start_move(move)
	return true


# ---------------------------------------------------------------------------
# MOVING: playing a TraversalMove
# ---------------------------------------------------------------------------

func _start_move(move: TraversalMove, chained := false) -> void:
	if chained:
		_chain_links += 1
	else:
		_chain_links = 0
		_move_started_sneaking = is_crouched

	_chain_buffered = false
	_chain_scan_timer = 0.0
	_assist_active = false

	current_move = move
	move_elapsed = 0.0
	move_progress = 0.0
	move_windup = 0.0
	_floor_valid = false
	_clear_ground_state()

	movement_state = MoveState.MOVING
	current_climb = null
	cached_profile = null
	is_peeking = false
	_shimmy_velocity = 0.0
	_hang_buffered_action = &""

	velocity = Vector3.ZERO
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_jump_hold_consumed = true
	_last_reject = ""

	if move.use_crouch_shape:
		_set_crouched(true)

	if move.noise_db > 0.0:
		_make_noise(move.noise_db, &"move")

	_move_sound(move)


## The sound of a move, as loud as the noise it makes: hands and boots on
## stone for a mantle, a rush of air over a vault, cloth for the quiet ones.
func _move_sound(move: TraversalMove) -> void:
	var loud := Sfx.loudness(maxf(move.noise_db, 30.0))

	match move.kind:
		MoveVariantRes.Kind.VAULT:
			Sfx.play_flat(self, &"whoosh_light", loud - 2.0, 0.9)
			Sfx.play_flat(self, &"cloth", loud)
		MoveVariantRes.Kind.MANTLE, TraversalPlanner.KIND_PULL_UP:
			Sfx.play_flat(self, &"scuff", loud)
			Sfx.play_flat(self, &"cloth", loud - 3.0)

			# Hauling yourself up: now and then it takes a breath of effort.
			if randf() < 0.35:
				Sfx.play_flat(self, &"effort", loud - 6.0)
		TraversalPlanner.KIND_LEAP:
			Sfx.play_flat(self, &"cloth", loud)
			Sfx.play_flat(self, &"whoosh_light", loud - 4.0, 0.8)
		TraversalPlanner.KIND_LOWER, TraversalPlanner.KIND_CORNER, TraversalPlanner.KIND_DROP_RELEASE:
			Sfx.play_flat(self, &"cloth", loud - 2.0)


func _update_move(delta: float) -> void:
	move_elapsed += delta
	# The press that started the move is already consumed. A new press is a
	# deliberate next action, even if the hands have not finished catching.
	if current_move.ends_in_hang:
		if Input.is_action_just_pressed("jump"):
			_hang_buffered_action = &"jump"
		if Input.is_action_just_pressed("crouch"):
			_hang_buffered_action = &"drop"

	# Windup: hold position with a small dip before launching.
	if move_elapsed < current_move.windup_time:
		var w := move_elapsed / current_move.windup_time
		var dip := current_move.points[0] - Vector3.UP * current_move.windup_dip * sin(w * PI)
		if scanner.motion_is_clear(global_position, dip, is_crouched):
			global_position = dip
		move_windup = w
		return

	move_windup = 0.0

	var elapsed := move_elapsed - current_move.windup_time
	var t := clampf(elapsed / maxf(current_move.duration, 0.001), 0.0, 1.0)

	# Constant speed, blended toward a symmetric ease and toward a launch.
	var symmetric := t * t * (3.0 - 2.0 * t)
	var launched := 1.0 - (1.0 - t) * (1.0 - t)
	var s := lerpf(t, symmetric, current_move.smoothing)
	s = lerpf(s, launched, current_move.ease_out)

	# Validate this tick too: moving doors and actors were not necessarily
	# here when the path was planned. Stop outside them and hand back gravity.
	var next := current_move.position_at(s)
	if not scanner.motion_is_clear(global_position, next, is_crouched):
		_cancel_blocked_move()
		return
	global_position = next

	# Turning happens through the middle of the move, not spread thin over it.
	if current_move.yaw_delta != 0.0:
		var turn := smoothstep(0.15, 0.85, s)
		var turn_before := smoothstep(0.15, 0.85, move_progress)
		rotate_y(current_move.yaw_delta * (turn - turn_before))

	move_progress = s

	# Flow: a jump pressed during the move is remembered, and once the move is
	# far enough along, the next obstacle may take over from mid-air.
	if Input.is_action_just_pressed("jump"):
		_chain_buffered = true

	if _chain_buffered and s >= chain_window_start and _chain_scan_timer <= 0.0 and _can_chain():
		if _try_chain():
			return

		_chain_scan_timer = RESCAN_TIME

	if t >= 1.0:
		_finish_move()


func _cancel_blocked_move() -> void:
	current_move = null
	move_progress = 0.0
	move_windup = 0.0
	movement_state = MoveState.LOCOMOTION
	velocity = Vector3.ZERO
	is_peeking = false
	_hang_buffered_action = &""
	_chain_buffered = false
	_pending_drop_target = {}
	drop_target = {}
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_regrab_timer = regrab_delay
	_jump_hold_consumed = true
	_last_reject = "move blocked by changed geometry"


func _can_chain() -> bool:
	if _chain_links >= max_chain_links or _move_started_sneaking:
		return false

	if current_move.ends_in_hang:
		return false

	# Only the table moves flow into each other: vaults and mantles.
	return (
		current_move.kind == MoveVariantRes.Kind.VAULT
		or current_move.kind == MoveVariantRes.Kind.MANTLE
	)


func _try_chain() -> bool:
	var points := current_move.points
	var travel := points[points.size() - 1] - points[0]
	travel.y = 0.0

	if travel.length_squared() < 0.0001:
		return false

	var direction := travel.normalized()

	# Velocity is zero during a move, so scan with the speed the move carries.
	# Measure from where this move LANDS, so the next obstacle's height is
	# judged against the ground, not against feet that are still in the air.
	# The path itself is planned from wherever the body is right now.
	var carried := direction * current_move.entry_speed * current_move.speed_kept
	var landing := points[points.size() - 1]
	var profile := scanner.scan_from(landing, direction, carried, true, chain_lookahead_time)

	if profile == null:
		if OS.has_environment("TRAV_DEBUG"):
			print("chain: no profile: ", scanner.last_reject, " s=%.2f" % move_progress)
		return false

	var ok := _try_traversal(profile, true)
	if OS.has_environment("TRAV_DEBUG"):
		print("chain: h %.2f t %.2f spd %.1f far %s -> %s  %s" % [profile.height, profile.thickness, profile.approach_speed, profile.has_far_floor, ok, _last_reject])
	return ok


func _finish_move() -> void:
	var move := current_move
	current_move = null
	move_progress = 0.0

	if move.kind == TraversalPlanner.KIND_DROP_RELEASE:
		var target := _pending_drop_target
		_pending_drop_target = {}
		_begin_drop_fall(target)
		return

	if move.ends_in_hang:
		# Reaching and leaping land with weight; corners and lowering do not.
		var caught := (
			move.kind == MoveVariantRes.Kind.HANG_ENTER
			or move.kind == TraversalPlanner.KIND_LEAP
		)
		_enter_hang(move.hang_normal, move.hang_lip_y, caught, _hang_buffered_action)
		return

	movement_state = MoveState.LOCOMOTION
	velocity = move.exit_velocity

	apply_floor_snap()


# ---------------------------------------------------------------------------
# HANGING
# ---------------------------------------------------------------------------

func _enter_hang(normal: Vector3, lip_y: float, caught := true, buffered_action: StringName = &"") -> void:
	movement_state = MoveState.HANGING
	# Hands slapping onto the ledge; softer when easing into the hang.
	Sfx.play_flat(self, &"grab", 0.0 if caught else -6.0)
	hang_normal = normal
	hang_lip_y = lip_y
	velocity = Vector3.ZERO
	is_peeking = false
	_shimmy_velocity = 0.0
	_hang_buffered_action = buffered_action
	hang_target = {}
	hang_aiming_elsewhere = false
	_kicks_this_airtime = 0
	_floor_valid = false
	_hang_scan_timer = 0.0
	_clear_ground_state()
	coyote_timer = 0.0

	# The hang pose was validated with the standing capsule.
	_set_crouched(false)

	if caught:
		juice.on_catch()


func _update_hang(delta: float) -> void:
	velocity = Vector3.ZERO

	var wish_direction := _wish_direction()
	var jump_requested := Input.is_action_just_pressed("jump") or _hang_buffered_action == &"jump"
	var drop_requested := Input.is_action_just_pressed("crouch") or _hang_buffered_action == &"drop"
	_hang_buffered_action = &""
	# Drop has priority over a queued pull-up.
	var pulling_away := Input.is_action_just_pressed("move_back") and _facing_direction().dot(-hang_normal) > 0.0
	if drop_requested or pulling_away:
		_drop_from_hang()
		return

	# Where would a jump take us? Up to a hundred physics queries, so it is
	# refreshed ten times a second, and at once when jump is pressed.
	_hang_scan_timer -= delta

	if _hang_scan_timer <= 0.0 or jump_requested:
		_hang_scan_timer = 0.1

		# The ledge may have gone from under the hands (a door swung open, a
		# crate pushed off): then there is nothing to hold.
		if not _lip_under_hands():
			_drop_from_hang()
			return

		hang_target = _find_hang_target(wish_direction)

	# Jump: leap to the target if there is one, otherwise climb onto the ledge.
	if jump_requested:
		jump_buffer_timer = 0.0
		if not hang_target.is_empty():
			var target_lip: float = hang_target["lip_y"]

			# A ledge well below: let go and fall onto it.
			if hang_lip_y - target_lip > leap_arc_max_drop:
				_start_drop_catch(hang_target)
				return

			var leap := planner.leap(global_position, hang_target, hang_normal)

			if leap != null:
				_start_move(leap)
				return

			# A ledge was chosen and cannot be reached. Stay put: climbing
			# onto the wall we hold is never what aiming elsewhere means.
			_last_reject = planner.last_reject
		elif hang_aiming_elsewhere:
			_last_reject = "no ledge in reach there"
		else:
			var move := planner.pull_up(hang_normal, global_position, hang_lip_y)

			if move != null:
				_start_move(move)
				return

			_last_reject = planner.last_reject

	# Sideways input, in world space, so it works whichever way you look.
	var lateral := hang_normal.cross(Vector3.UP).normalized()
	var sideways := wish_direction.dot(lateral)
	var wanted := sideways * shimmy_speed if absf(sideways) > 0.3 else 0.0
	var response := shimmy_start_time if wanted != 0.0 else shimmy_stop_time
	_shimmy_velocity = move_toward(_shimmy_velocity, wanted, shimmy_speed * delta / maxf(response, 0.001))

	if absf(_shimmy_velocity) > 0.001:
		_shimmy(lateral * signf(_shimmy_velocity), delta)
		if movement_state != MoveState.HANGING:
			return

	# Pushing into the wall lifts the eyes over the lip.
	is_peeking = wish_direction.dot(-hang_normal) > 0.5


## Something to hold where the hands are: a few rays down onto the lip, just
## past the face and a little deeper.
func _lip_under_hands() -> bool:
	for depth in [0.04, scanner.top_probe_depth, 0.3]:
		var hands: Vector3 = global_position - hang_normal * (_radius + planner.hang_gap + depth)
		var lip := scanner.ray(
			Vector3(hands.x, hang_lip_y + 0.27, hands.z),
			Vector3(hands.x, hang_lip_y - 0.17, hands.z),
			false
		)

		if not lip.is_empty():
			return true

	return false


func _drop_from_hang() -> void:
	movement_state = MoveState.LOCOMOTION
	is_peeking = false
	_shimmy_velocity = 0.0
	_hang_buffered_action = &""
	hang_target = {}
	hang_aiming_elsewhere = false
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

	# A small push clear of the wall, then gravity takes over.
	velocity = hang_normal * 0.6
	_regrab_timer = regrab_delay
	_jump_hold_consumed = true


func _shimmy(direction: Vector3, delta: float) -> void:
	var distance := absf(_shimmy_velocity) * delta
	var next := global_position + direction * distance
	var hit := planner.probe_hang(next, hang_normal, hang_lip_y, 0.12)

	if not hit.is_empty():
		var normal: Vector3 = hit["normal"]

		if normal.angle_to(hang_normal) <= deg_to_rad(shimmy_max_turn_degrees):
			# Spend the same travel budget on height/depth changes as sideways
			# travel. A seam must not snap the camera ten centimetres in a tick.
			var anchor: Vector3 = hit["anchor"]
			var step := global_position.move_toward(anchor, distance)
			if scanner.motion_is_clear(global_position, step, false):
				global_position = step
				hang_normal = normal
				hang_lip_y = hit["lip_y"]
				_last_reject = ""
				return

		_last_reject = "shimmy: ledge turns sharply"
	else:
		_last_reject = "shimmy: " + planner.last_reject

	# The ledge ended or something is in the way: try to go around the corner.
	var move := planner.corner(global_position, hang_normal, hang_lip_y, direction)

	if move != null:
		_start_move(move)
	else:
		_shimmy_velocity = 0.0


# ---------------------------------------------------------------------------
# Targeted drop: let go, fall, catch the ledge below
# ---------------------------------------------------------------------------

## Letting go starts with a short push away from the wall, so nothing that
## sticks out below can catch the body before it falls.
func _start_drop_catch(target: Dictionary) -> void:
	var out := global_position + hang_normal * 0.35

	if not scanner.fits(out, false):
		out = global_position

	var move := TraversalMove.new()
	move.label = &"let go"
	move.kind = TraversalPlanner.KIND_DROP_RELEASE
	move.points = PackedVector3Array([global_position, out])
	move.smoothing = 0.0
	move.ease_out = 0.6
	move.bake()
	move.duration = 0.1
	_pending_drop_target = target
	_start_move(move)


func _begin_drop_fall(target: Dictionary) -> void:
	var anchor: Vector3 = target["anchor"]
	var drop := global_position.y - anchor.y
	var fall_time := _fall_time(drop)
	var flat := Vector3(anchor.x - global_position.x, 0.0, anchor.z - global_position.z)

	movement_state = MoveState.LOCOMOTION
	is_peeking = false
	hang_target = {}
	drop_target = target
	_jump_hold_consumed = true
	_regrab_timer = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

	# Just enough sideways speed to arrive above the ledge as we reach it.
	velocity = Vector3.ZERO

	if flat.length() > 0.05 and fall_time > 0.05:
		var speed := clampf(flat.length() / fall_time, 0.0, 6.0)
		velocity = flat.normalized() * speed

	# Hold that speed through the fall unless the player steers away.
	_assist_active = velocity.length() > 0.05
	_assist_left_ground = true
	_assist_direction = velocity.normalized() if _assist_active else Vector3.ZERO
	_assist_speed = velocity.length()


## Seconds to fall `drop` metres from rest, with the real gravity rules.
func _fall_time(drop: float) -> float:
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var height := 0.0
	var vertical := 0.0

	for i in range(600):
		vertical = maxf(vertical - gravity * fall_gravity_multiplier * step, -maximum_fall_speed)
		height += vertical * step

		if height <= -drop:
			return step * float(i + 1)

	return -1.0


## Returns true when the catch move has started.
func _update_drop_catch() -> bool:
	var anchor: Vector3 = drop_target["anchor"]

	var abandoned := (
		_on_floor_now()
		or velocity.y < -maximum_grab_fall_speed
		or Input.is_action_just_pressed("crouch")
	)



	if abandoned:
		drop_target = {}
		_assist_active = false
		return false

	if velocity.y > 0.0:
		return false

	var flat := Vector3(anchor.x - global_position.x, 0.0, anchor.z - global_position.z)

	if absf(global_position.y - anchor.y) > 0.45 or flat.length() > 0.7:
		return false

	if not scanner.fits(anchor, false):
		return false

	var move := TraversalMove.new()
	move.label = &"catch"
	move.noise_db = 45.0
	move.kind = MoveVariantRes.Kind.HANG_ENTER
	move.points = PackedVector3Array([global_position, anchor])
	move.smoothing = 0.5
	move.bake()
	move.duration = 0.1
	move.ends_in_hang = true
	move.hang_normal = drop_target["normal"]
	move.hang_lip_y = drop_target["lip_y"]

	drop_target = {}
	_assist_active = false
	_start_move(move)
	return true


# ---------------------------------------------------------------------------
# Hang leaps: finding the target
# ---------------------------------------------------------------------------

func _find_hang_target(wish_direction: Vector3) -> Dictionary:
	var looked_at := _find_looked_at_target()

	if not looked_at.is_empty():
		return looked_at

	var lateral := hang_normal.cross(Vector3.UP).normalized()
	var sideways := wish_direction.dot(lateral)

	if absf(sideways) > 0.3:
		return _find_sideways_target(lateral * signf(sideways))

	return {}


func _find_looked_at_target() -> Dictionary:
	# The neck is where the player aims; the camera also carries feel offsets.
	var forward := -neck.global_transform.basis.z
	var flat := Vector3(forward.x, 0.0, forward.z)

	if flat.length() < 0.2:
		flat = _facing_direction()

	flat = flat.normalized()

	# First, whatever the crosshair actually rests on, whichever way it faces.
	var aimed := _find_aimed_ledge()

	if not aimed.is_empty():
		return aimed

	var into := flat.dot(-hang_normal)

	if into > 0.5:
		# Straight up the wall: a lip above on the same face.
		if neck.rotation.x > deg_to_rad(25.0):
			return _find_upper_lip()

		# Looking at our own wall with nothing else under the crosshair.
		return {}

	# Nothing under the crosshair: a ledge across open air, where the view
	# passes over the lip. March along the view in two height bands, around
	# our lip and above it, then below it.
	for lift in [0.65, -1.6]:
		for k in range(3):
			var origin: Vector3 = (
				global_position
				+ flat * (scanner.scan_distance * k)
				+ Vector3.UP * lift
			)
			var profile := scanner.scan_from(origin, flat, Vector3.ZERO, true)

			if profile == null:
				# Open air: keep marching. Anything else is a face we cannot use.
				if scanner.last_reject == "nothing ahead":
					continue

				break

			var candidate := _leap_target_from(
				profile.face_point,
				profile.face_normal,
				profile.top_point.y
			)

			if not candidate.is_empty():
				return candidate

			break

	return {}
## Is this surface part of the wall and ledge we are hanging from?
func _is_own_wall(point: Vector3, normal: Vector3) -> bool:
	var face := global_position - hang_normal * (_radius + planner.hang_gap)

	if normal.y >= scanner.min_top_normal_y:
		# A top surface: ours if it is our own lip, near our hands.
		var flat := Vector3(point.x - face.x, 0.0, point.z - face.z).length()
		return absf(point.y - hang_lip_y) < 0.15 and flat < 1.2

	var flat_normal := Vector3(normal.x, 0.0, normal.z)

	if flat_normal.length() < 0.2:
		return false

	if flat_normal.normalized().angle_to(hang_normal) > deg_to_rad(40.0):
		return false

	# Same direction is not enough: it must also be the same plane, give or
	# take a molding. A parallel wall across the street is somewhere else.
	return absf((point - face).dot(hang_normal)) < 0.6


## The ledge under the crosshair, whichever way it faces. Handles a wall face
## seen from the front or at an angle, and a ledge's top seen from above.
func _find_aimed_ledge() -> Dictionary:
	hang_aiming_elsewhere = false

	var forward := -neck.global_transform.basis.z
	var eye := neck.global_position
	var look := scanner.ray(eye, eye + forward * 8.0)

	if look.is_empty():
		return {}

	var raw_normal: Vector3 = look["normal"]
	var hit: Vector3 = look["position"]

	hang_aiming_elsewhere = not _is_own_wall(hit, raw_normal)

	if hit.y - hang_lip_y > leap_max_rise + 0.6 or hit.y - hang_lip_y < -leap_max_drop - 0.6:
		return {}

	# Looking down onto the top of a ledge: that surface is the lip. Find the
	# face you would hang from by looking back at it from outside.
	if raw_normal.y >= scanner.min_top_normal_y:
		var toward_us := Vector3(global_position.x - hit.x, 0.0, global_position.z - hit.z)
		var lateral := hang_normal.cross(Vector3.UP).normalized()
		var outward: Array[Vector3] = [hang_normal, -hang_normal, lateral, -lateral]

		if toward_us.length() > 0.3:
			outward.push_front(toward_us.normalized())

		for direction in outward:
			# The crosshair can rest well inside a roof, not just on its rim.
			# Find the outside of that surface, then look back at its face.
			for distance in [0.6, 1.2, 1.8, 2.4]:
				var outside: Vector3 = hit + direction * distance
				outside.y = hit.y - 0.04
				var face := scanner.ray(outside, outside - direction * (distance + 0.1))

				if face.is_empty():
					continue

				var face_raw: Vector3 = face["normal"]
				if absf(face_raw.y) > scanner.max_wall_normal_y:
					continue

				var face_normal := Vector3(face_raw.x, 0.0, face_raw.z).normalized()
				if face_normal.dot(direction) < 0.5:
					continue

				var face_hit: Vector3 = face["position"]
				var rim := face_hit - face_normal * scanner.top_probe_depth
				var top := scanner.ray(Vector3(rim.x, hit.y + 0.06, rim.z), Vector3(rim.x, hit.y - 0.06, rim.z), false)
				if top.is_empty() or top["collider"] != look["collider"] or (top["normal"] as Vector3).y < scanner.min_top_normal_y:
					continue

				var from_top := _leap_target_from(Vector3(face_hit.x, hit.y, face_hit.z), face_normal, hit.y)
				if not from_top.is_empty():
					return from_top

		return {}

	if absf(raw_normal.y) > scanner.max_wall_normal_y:
		return {}

	var normal := Vector3(raw_normal.x, 0.0, raw_normal.z).normalized()

	# The lip near where you look: on a molding that sticks out (probe just
	# outside the face) or on the wall's own top (probe just inside). Take
	# the one closest to the point you are looking at.
	var lip := {}
	var lip_error := INF

	for side in [0.1, -0.1]:
		var probe: Vector3 = hit + normal * side
		var found := scanner.ray(
			Vector3(probe.x, hit.y + 0.9, probe.z),
			Vector3(probe.x, hit.y - 0.7, probe.z),
			false
		)

		if found.is_empty():
			continue

		var found_normal: Vector3 = found["normal"]

		if found_normal.y < scanner.min_top_normal_y:
			continue

		var found_point: Vector3 = found["position"]
		var error := absf(found_point.y - hit.y)

		if error < lip_error:
			lip = found
			lip_error = error

	if lip.is_empty():
		return {}

	var lip_point: Vector3 = lip["position"]
	var face_point := Vector3(hit.x, lip_point.y, hit.z)
	return _leap_target_from(face_point, normal, lip_point.y)


func _find_upper_lip() -> Dictionary:
	var profile := scanner.scan_from(global_position, -hang_normal, Vector3.ZERO, true)

	# A thick ledge has nothing above it on the same face; that is a pull up.
	if profile == null or profile.thickness == INF:
		return {}

	# Look down from above, just inside the wall behind our ledge (a roof lip)
	# and just outside it (a molding that sticks out). Take the lower one.
	var upper := {}

	for side in [-0.1, 0.1]:
		var probe: Vector3 = profile.far_edge + profile.face_normal * side
		var found := scanner.ray(
			Vector3(probe.x, hang_lip_y + leap_max_rise + 0.1, probe.z),
			Vector3(probe.x, hang_lip_y + 0.3, probe.z),
			false
		)

		if found.is_empty():
			continue

		if upper.is_empty():
			upper = found
		else:
			var a: Vector3 = found["position"]
			var b: Vector3 = upper["position"]

			if a.y < b.y:
				upper = found

	if upper.is_empty():
		return {}

	var upper_point: Vector3 = upper["position"]
	var from := Vector3(global_position.x, upper_point.y - 0.15, global_position.z)
	var face := scanner.ray(from, from - hang_normal * (_radius + 1.5))

	if face.is_empty():
		return {}

	var raw_normal: Vector3 = face["normal"]

	if absf(raw_normal.y) > scanner.max_wall_normal_y:
		return {}

	var normal := Vector3(raw_normal.x, 0.0, raw_normal.z).normalized()
	var face_point: Vector3 = face["position"]
	return _leap_target_from(face_point, normal, upper_point.y)


func _find_sideways_target(direction: Vector3) -> Dictionary:
	var seen_gap := false
	var distance := 0.6

	while distance <= leap_max_sideways:
		var point := global_position + direction * distance
		var level := planner.probe_hang(point, hang_normal, hang_lip_y, 0.25)

		if level.is_empty():
			# A break in the ledge, or a change in its height, is what a leap crosses.
			seen_gap = true

			for change in [-0.4, 0.4, -0.8, 0.8]:
				var stepped := planner.probe_hang(
					point, hang_normal, hang_lip_y + change, 0.25
				)

				if not stepped.is_empty():
					return stepped
		elif seen_gap:
			return level

		distance += 0.2

	return {}


func _leap_target_from(face_point: Vector3, normal: Vector3, lip_y: float) -> Dictionary:
	var rise := lip_y - hang_lip_y

	# Small tolerance: level geometry is built to round numbers, and a rise
	# of exactly the limit must count.
	if rise > leap_max_rise + 0.03 or rise < -leap_max_drop - 0.03:
		return {}

	var flat := Vector3(
		face_point.x - global_position.x,
		0.0,
		face_point.z - global_position.z
	)

	if flat.length() > leap_max_across:
		return {}

	var anchor := planner.hang_anchor(face_point, normal, lip_y)

	# The lip we already hold is not a destination.
	if anchor.distance_to(global_position) < 1.0:
		return {}

	if not scanner.fits(anchor, false):
		return {}

	return {
		"anchor": anchor,
		"normal": normal,
		"lip_y": lip_y,
		"face_point": face_point,
	}


# ---------------------------------------------------------------------------
# CLIMBING
# ---------------------------------------------------------------------------

## Called by ClimbVolume when the player enters it.
func add_climb_volume(volume: Area3D) -> void:
	if not climb_volumes.has(volume):
		climb_volumes.append(volume)


## Called by ClimbVolume when the player leaves it.
func remove_climb_volume(volume: Area3D) -> void:
	climb_volumes.erase(volume)

	if current_climb == volume:
		# Onto the next volume of the same ladder or wall, if you are in one:
		# a ladder built of two volumes has no seam to fall through.
		var next := _climb_handover(volume)

		if next != null:
			current_climb = next
			return

		# Swung or slid out of it: let go, keeping the motion.
		_leave_climb(velocity)


## Another volume you are in that carries on the flat climb in `volume`
## (facing the same way), or null. Ropes are never handed over.
func _climb_handover(volume: Area3D) -> Area3D:
	if not is_instance_valid(volume) or volume.rope or volume.has_method("rope_point"):
		return null

	var normal: Vector3 = volume.get_climb_normal()

	for other in climb_volumes:
		if is_instance_valid(other) and not other.rope and not other.has_method("rope_point"):
			if (other.get_climb_normal() as Vector3).dot(normal) > 0.85:
				return other

	return null


func _is_carrying() -> bool:
	return frob != null and frob.is_carrying()


# ---------------------------------------------------------------------------
# SWIMMING
# ---------------------------------------------------------------------------

## Into the water, out of it: chest deep with nothing to stand on, you swim;
## where you can stand again, you wade.
func _update_water() -> void:
	var feet := get_feet_position()
	water = null

	for i in range(_water_volumes.size() - 1, -1, -1):
		var volume := _water_volumes[i]

		if not is_instance_valid(volume):
			_water_volumes.remove_at(i)
		elif water == null and volume.holds(feet + Vector3.UP * 0.05, 0.3):
			water = volume

	# Area notifications settle after a teleport. Resolve the destination now,
	# while the cached overlap list remains the usual fast path.
	if water == null:
		for volume in get_tree().get_nodes_in_group(&"water"):
			if volume.has_method("holds") and volume.holds(feet + Vector3.UP * 0.05, 0.3):
				water = volume
				break

	if water == null:
		if movement_state == MoveState.SWIMMING:
			_leave_swim()

		return

	if movement_state != MoveState.LOCOMOTION and movement_state != MoveState.SWIMMING:
		return

	var floor_depth := _swim_floor_depth()
	match movement_state:
		MoveState.LOCOMOTION:
			if _step_lock_timer <= 0.0 and water.depth_of(feet) > swim_start_depth and floor_depth > water.SWIM_DEPTH + swim_depth_hysteresis:
				_enter_swim()
		MoveState.SWIMMING:
			# Contact with a standable tread resolves the hysteresis band too.
			# Merely floating over the deep side of a bank does not.
			var supported := is_on_floor() or _step_lock_timer > 0.0
			var stand_depth: float = water.SWIM_DEPTH + (swim_depth_hysteresis if supported else 0.0)
			if floor_depth <= stand_depth and water.depth_of(feet) < swim_start_depth + 0.3:
				_leave_swim()


## Measure beneath the swimmer, excluding their capsule. A flooded roof
## above the surface is not the bottom of the pool.
func _swim_floor_depth() -> float:
	var bottom: float = water.bottom_y()
	var query := PhysicsRayQueryParameters3D.create(
		global_position, Vector3(global_position.x, bottom - 0.5, global_position.z), 1, [get_rid()])
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		bottom = (hit["position"] as Vector3).y
	return water.surface_y() - bottom


## Called by WaterVolume when the body goes in, and comes out.
func add_water_volume(volume: Area3D) -> void:
	if not _water_volumes.has(volume):
		_water_volumes.append(volume)


func remove_water_volume(volume: Area3D) -> void:
	_water_volumes.erase(volume)


func _enter_swim() -> void:
	movement_state = MoveState.SWIMMING
	_clear_ground_state()
	_floor_valid = false
	_on_stairs = false
	current_climb = null

	# Swimming is done standing, where there is room (a flooded culvert).
	if is_crouched and _can_stand():
		_set_crouched(false)

	# Nothing held swims with you.
	if frob != null:
		frob.drop_held()

	# The water takes the fall out of you.
	velocity.y = clampf(velocity.y * 0.3, -dive_speed, dive_speed)
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_jump_cut_allowed = false
	cached_profile = null
	_pending_drop_target = {}
	_strokes = 0.0


func _leave_swim() -> void:
	movement_state = MoveState.LOCOMOTION
	_floor_valid = false
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_jump_cut_allowed = false
	_strokes = 0.0


## The eyes are under the surface.
func is_underwater() -> bool:
	return water != null and global_position.y + _neck_base_y < water.surface_y() - 0.05


## Wading: the share of your speed the water leaves you (1 out of it).
func wade_scale() -> float:
	if water == null or movement_state != MoveState.LOCOMOTION:
		return 1.0

	var deep := clampf(water.depth_of(get_feet_position()) / swim_start_depth, 0.0, 1.0)
	return lerpf(1.0, wade_speed_scale, deep)


## Afloat: the way you face, as fast as you can swim; down while you hold
## crouch, up while you hold jump, and left alone you float up until your eyes
## are over the surface. Jump at a bank low enough, and you climb out.
func _update_swim(delta: float) -> void:
	if is_crouched and _can_stand():
		_set_crouched(false)

	var afloat_y: float = water.surface_y() + float_eye - _neck_stand_y
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := _wish_direction()
	var facing := _facing_direction()
	var speed := swim_sprint_speed if Input.is_action_pressed("sprint") else swim_speed
	var at_top := global_position.y > afloat_y - 0.3

	# Holding jump to surface also asks to climb out. A short ground jump
	# buffer cannot cover the ascent from deeper water. Rescan while held,
	# but consume the hold once a real, collision-checked exit starts.
	var exit_intent := not Input.is_action_pressed("crouch") and (jump_buffer_timer > 0.0 or Input.is_action_pressed("jump"))
	if at_top and exit_intent and not _jump_hold_consumed and wish.dot(facing) > min_forward_input and not _is_carrying():
		if _air_scan_timer <= 0.0 or Input.is_action_just_pressed("jump"):
			_air_scan_timer = RESCAN_TIME
			cached_profile = scanner.scan(facing, velocity, false)
			if cached_profile != null:
				var exit := planner.water_exit(cached_profile, global_position, water.surface_y() - water.SWIM_DEPTH - swim_depth_hysteresis)
				if exit != null:
					_start_move(exit)
					return
				_last_reject = planner.last_reject
			else:
				_last_reject = scanner.last_reject

	# A ladder or a rope that reaches down into the water: swim to it and take it.
	if _try_enter_climb(wish):
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		_jump_cut_allowed = false
		return

	# Forward/reverse follow the view below water; strafe stays level. At the
	# surface looking around does nothing until a stroke or dive is held.
	var course := (global_basis.x * axis.x + neck.global_basis.z * axis.y).normalized()
	var directed_vertical := absf(axis.y) > 0.05 and absf(course.y) > 0.15
	var target := wish * speed
	var surface_error := afloat_y - global_position.y
	var want := clampf(surface_error * 3.0, -1.0, 1.2)
	if directed_vertical and (surface_error > 0.05 or course.y < 0.0):
		target = course * speed
		want = target.y

	if Input.is_action_pressed("crouch"):
		want = -dive_speed
	elif Input.is_action_pressed("jump") and surface_error > 0.0:
		want = dive_speed

	# Begin braking before the eyes reach their surface height. No position
	# snap is needed, and the capsule still meets ceilings through physics.
	if want > 0.0:
		want = minf(want, maxf(surface_error * 3.0, 0.0))
	target.y = want
	target = target.limit_length(speed)
	var acceleration := swim_acceleration if not axis.is_zero_approx() else swim_braking
	if Input.is_action_pressed("crouch") or Input.is_action_pressed("jump"):
		acceleration = maxf(acceleration, 9.0)
	# One vector keeps turns inside the speed limit. Easing its axes at
	# different rates can briefly add speed when a diagonal dive turns steep.
	velocity = velocity.move_toward(target, acceleration * delta)
	var step_locked := _advance_step_lock(delta)
	_stepped_up_this_frame = false
	# At the surface, small flooded risers are steps, just as on land.
	# Explicit diving keeps full swim control and releases any tread hold.
	var diving := Input.is_action_pressed("crouch") or (directed_vertical and course.y < 0.0 and not Input.is_action_pressed("jump"))
	if diving:
		_step_lock_timer = 0.0
		step_locked = false
	elif at_top:
		if step_locked:
			global_position.y = _step_lock_y
			velocity.y = 0.0
		_try_step_up(delta)
	floor_snap_length = 0.0
	LanternBody.slide_character(self)
	if step_locked or _stepped_up_this_frame:
		global_position.y = _step_lock_y
		velocity.y = 0.0
	_swim_sounds(at_top)


## A stroke every metre and a half or so: heard at the surface, hardly at
## all under it.
func _swim_sounds(at_top: bool) -> void:
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()

	if speed < 0.4:
		return

	_strokes += speed * get_physics_process_delta_time() / 1.5

	if _strokes < 1.0:
		return

	_strokes -= 1.0
	var db := swim_db if at_top else swim_under_db
	_make_noise(db, &"swim")
	Sfx.play_flat(self, Sfx.step("water", speed > swim_speed + 0.3), Sfx.loudness(db))


## Pushes the body along `push` (m/s, horizontal) for `seconds`, easing off:
## a dodge, a kick, a blast. Movement input waits until it is over.
func shove(push: Vector3, seconds: float) -> void:
	_shove_velocity = Vector3(push.x, 0.0, push.z)
	_shove_time = seconds
	_shove_length = seconds


## A guard started a blow at you. If he is out of sight the HUD says so.
func warn_attack(from: Node3D) -> void:
	if hud != null and hud.has_method("warn_attack"):
		hud.warn_attack(from)


## Leaving the ground: stair locks, assists and a pending drop-catch belong to
## what the player was doing before, and must not fire later.
func _clear_ground_state() -> void:
	_step_lock_timer = 0.0
	_stair_pulled = false
	_assist_active = false
	drop_target = {}


func _try_enter_climb(wish_direction: Vector3) -> bool:
	if Engine.get_physics_frames() <= _teleport_contacts_until or climb_volumes.is_empty() or _climb_reattach_timer > 0.0 or _is_carrying():
		return false

	# Overlapping volumes (a ladder beside a rope, two halves of a wall): the
	# latest entered first, then any other one pushed into.
	var volume: Area3D = null

	for i in range(climb_volumes.size() - 1, -1, -1):
		var candidate := climb_volumes[i]

		if not is_instance_valid(candidate):
			climb_volumes.remove_at(i)
			continue

		var normal: Vector3 = candidate.get_climb_normal()

		if candidate.rope:
			normal = candidate.get_rope_normal(global_position)

		# Only attach when pushing into the surface.
		if wish_direction.dot(-normal) >= 0.3:
			volume = candidate
			break

	if volume == null:
		return false

	movement_state = MoveState.CLIMBING
	current_climb = volume
	rope_param = -1.0
	_floor_valid = false
	_clear_ground_state()

	# Climbing is done standing.
	if is_crouched and _can_stand():
		_set_crouched(false)
	velocity = Vector3.ZERO
	cached_profile = null
	_kicks_this_airtime = 0
	_assist_active = false
	return true


## Climbing makes itself heard every so often: a rope creaks, a chain
## rattles, a hand finds the next hold on a ladder or a wall.
func _climb_sounds() -> void:
	var y := global_position.y

	if movement_state != MoveState.CLIMBING or current_climb == null or not is_instance_valid(current_climb):
		_climb_sound_travel = 0.0
		_climb_last_y = y
		return

	_climb_sound_travel += absf(y - _climb_last_y)
	_climb_last_y = y

	if _climb_sound_travel < 0.45:
		return

	_climb_sound_travel = 0.0
	var sound := &"grab"

	if current_climb.get("rope") == true:
		# VerletRope: style 0 is a rope, anything else a chain.
		sound = &"rattle_chain" if int(current_climb.get("style") if current_climb.get("style") != null else 0) != 0 else &"creak_rope"

	Sfx.play_flat(self, sound, -3.0)


func _update_climb(_delta: float) -> void:
	# Left the volume: usually off the top or the bottom.
	if current_climb == null or not is_instance_valid(current_climb):
		_leave_climb(velocity)
		return

	if is_crouched and _can_stand():
		_set_crouched(false)

	if current_climb.has_method("rope_point"):
		_update_rope_climb(_delta)
		return

	var is_rope: bool = current_climb.rope
	var normal: Vector3 = current_climb.get_climb_normal()
	var wish_direction := _wish_direction()

	if is_rope:
		normal = current_climb.get_rope_normal(global_position)

	if Input.is_action_just_pressed("jump"):
		# Off a rope, jump the way you look; off a ladder, away from it.
		var push := normal

		if is_rope:
			push = _facing_direction()

		_leave_climb(push * climb_jump_push + Vector3.UP * jump_speed * 0.6)
		return

	if Input.is_action_just_pressed("crouch"):
		_leave_climb(normal * 0.5)
		return

	# Feet on the ground and walking away: step off.
	if is_on_floor() and wish_direction.dot(normal) > 0.3:
		_leave_climb(Vector3.ZERO)
		return

	# Hold a fixed gap to the surface with a spring rather than a teleport,
	# so uneven walls do not make the view jitter.
	var gap: float

	if is_rope:
		var axis: Vector3 = current_climb.global_position
		gap = Vector3(global_position.x - axis.x, 0.0, global_position.z - axis.z).length()
	else:
		var wall := scanner.ray(global_position, global_position - normal * (_radius + 1.0))

		if wall.is_empty():
			var plane_point: Vector3 = current_climb.get_plane_point()
			gap = (global_position - plane_point).dot(normal)
		else:
			var wall_point: Vector3 = wall["position"]
			gap = (global_position - wall_point).dot(normal)

	var wanted_gap: float = _radius + current_climb.climb_distance
	var spring := -normal * (gap - wanted_gap) * 10.0

	# Forward climbs the way you look: up normally, down when looking down.
	var input_axis := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	var look_sign := 1.0 if neck.rotation.x > -0.3 else -1.0
	var vertical := -input_axis.y * look_sign

	var lateral := normal.cross(Vector3.UP).normalized()
	var sideways := wish_direction.dot(lateral)

	var max_vertical: float = current_climb.max_vel_vert
	var max_horizontal: float = current_climb.max_vel_horiz

	# Near the top while climbing up: mantle onto whatever is in reach. On a
	# ladder that is the wall it leans on; on a rope, whatever you face.
	if vertical > 0.1 and _climb_scan_timer <= 0.0:
		_climb_scan_timer = RESCAN_TIME
		var profile: ObstacleProfile = null

		if is_rope:
			# The body hangs off to one side of the rope, so measure from the
			# rope itself. The move is still planned from the body's position.
			var axis: Vector3 = current_climb.global_position
			var from := Vector3(axis.x, global_position.y, axis.z)
			profile = scanner.scan_from(from, _facing_direction(), Vector3.ZERO, true)
		else:
			profile = scanner.scan(-normal, Vector3.ZERO, true)

		if profile != null and profile.height <= climb_top_mantle_height:
			if _try_traversal(profile):
				_climb_reattach_timer = climb_reattach_delay
				return

	velocity = (
		spring
		+ Vector3.UP * vertical * max_vertical
		+ lateral * sideways * max_horizontal
	)

	LanternBody.slide_character(self)


## A simulated rope: the hands hold a point that moves. The body is pulled to
## it, input swings it, and letting go keeps the swing.
func _update_rope_climb(delta: float) -> void:
	var rope := current_climb
	var rope_length: float = rope.length

	if rope_param < 0.0:
		rope_param = rope.closest_param(global_position)

	var wish_direction := _wish_direction()
	var input_axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var look_sign := 1.0 if neck.rotation.x > -0.3 else -1.0
	var vertical := -input_axis.y * look_sign
	var max_vertical: float = rope.max_vel_vert

	# Climb: hands move along the rope. Up is toward the anchor.
	rope_param = clampf(
		rope_param - vertical * max_vertical * delta,
		rope_end_margin,
		rope_length - rope_end_margin
	)

	var grip: Vector3 = rope.rope_point(rope_param)
	var grip_velocity: Vector3 = rope.rope_velocity(rope_param, delta)
	var normal: Vector3 = rope.get_rope_normal(global_position)

	if Input.is_action_just_pressed("jump"):
		rope.release()
		_leave_climb(grip_velocity + _facing_direction() * climb_jump_push + Vector3.UP * jump_speed * 0.6)
		return

	if Input.is_action_just_pressed("crouch"):
		rope.release()
		_leave_climb(grip_velocity)
		return

	if is_on_floor() and wish_direction.dot(normal) > 0.3:
		rope.release()
		_leave_climb(Vector3.ZERO)
		return

	# Near the top while climbing up: mantle onto whatever you face.
	if vertical > 0.1 and _climb_scan_timer <= 0.0:
		_climb_scan_timer = RESCAN_TIME
		var from := Vector3(grip.x, global_position.y, grip.z)
		var profile := scanner.scan_from(from, _facing_direction(), grip_velocity, true)

		if profile != null and profile.height <= climb_top_mantle_height:
			if _try_traversal(profile):
				rope.release()
				_climb_reattach_timer = climb_reattach_delay
				return

	# Swing: sideways and forward input push the rope, not the body. The body
	# follows the grip through a spring, so the swing reads as weight.
	var swing: Vector3 = wish_direction * rope.swing_strength
	rope.grip(rope_param, swing)

	var wanted: Vector3 = grip + normal * (_radius + rope.climb_distance)
	var spring := (wanted - global_position) * rope_grip_stiffness

	velocity = spring + grip_velocity
	LanternBody.slide_character(self)


## Puts the player at `xform` (the gym's bays): on his feet, with no move to
## finish, no ledge, ladder or rope held, no stair lock, and still.
func teleport(xform: Transform3D) -> void:
	if current_climb != null and is_instance_valid(current_climb) and current_climb.has_method("release"):
		current_climb.release()

	global_transform = xform
	_teleport_contacts_until = Engine.get_physics_frames() + 1
	movement_state = MoveState.LOCOMOTION
	current_move = null
	move_elapsed = 0.0
	move_progress = 0.0
	move_windup = 0.0
	cached_profile = null
	_chain_buffered = false
	current_climb = null
	rope_param = -1.0
	is_peeking = false
	_shimmy_velocity = 0.0
	_hang_buffered_action = &""
	hang_target = {}
	hang_aiming_elsewhere = false
	drop_target = {}
	_pending_drop_target = {}
	hang_normal = Vector3.ZERO
	hang_lip_y = 0.0
	_regrab_timer = 0.0
	_climb_reattach_timer = 0.0
	_failed_plan_cooldown = 0.0
	_air_scan_timer = 0.0
	_climb_scan_timer = 0.0
	_chain_scan_timer = 0.0
	_last_reject = ""
	_assist_active = false
	_assist_left_ground = false
	_assist_direction = Vector3.ZERO
	_assist_speed = 0.0
	_assist_time = 0.0
	_kicks_this_airtime = 0
	_jump_hold_consumed = Input.is_action_pressed("jump")
	_crouch_held_last = Input.is_action_pressed("crouch")
	_crouch_just_pressed = false
	_clear_ground_state()
	velocity = Vector3.ZERO
	_shove_time = 0.0
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	_jump_cut_allowed = false
	_floor_valid = false
	_step_view_offset = 0.0
	_step_change_tick = 0.0
	_last_motion_position = global_position
	reset_physics_interpolation()


func _leave_climb(exit_velocity: Vector3) -> void:
	if current_climb != null and is_instance_valid(current_climb) and current_climb.has_method("release"):
		current_climb.release()

	movement_state = MoveState.LOCOMOTION
	current_climb = null
	rope_param = -1.0
	velocity = exit_velocity
	_climb_reattach_timer = climb_reattach_delay
	_jump_hold_consumed = true
	# The press that took you off is spent, and there is no ground to jump from.
	jump_buffer_timer = 0.0
	coyote_timer = 0.0


# ---------------------------------------------------------------------------
# View: eye height and camera feel
# ---------------------------------------------------------------------------

func _update_view(delta: float) -> void:
	# Eye height follows the stance, plus the peek while hanging.
	var target_y := _neck_stand_y

	if is_crouched:
		target_y -= _standing_height - crouch_height

	if movement_state == MoveState.HANGING and is_peeking:
		var lift := planner.hang_eye_drop + peek_above_lip

		# Do not push the camera into a ceiling. Measured from where the eyes
		# are without the peek, so the answer does not flip once raised.
		var eyes := global_position + Vector3.UP * target_y

		if scanner.ray(eyes, eyes + Vector3.UP * (lift + 0.15)).is_empty():
			target_y += lift

	# On a staircase the eyes move at the stairs' own climb rate, which turns
	# a series of hops into one straight line. Off the stairs they catch up.
	var on_staircase := (_game_time - _last_step_time) < 0.5 and _stair_rate > 0.0
	var follow_rate := stair_view_catch_up

	if on_staircase:
		follow_rate = _stair_rate
	elif absf(_step_view_offset) > 0.001:
		follow_rate = maxf(absf(_step_view_offset) * stair_view_smoothing, stair_view_catch_up)

	_step_view_offset = move_toward(_step_view_offset, 0.0, follow_rate * delta)

	# Stance changes ease in; the step offset is applied as is, because it
	# exists precisely to cancel a jump the body just made.
	_neck_base_y = lerpf(
		_neck_base_y,
		target_y,
		1.0 - exp(-view_height_speed * delta)
	)
	neck.position.y = _neck_base_y + _step_view_offset

	_update_lean(delta)

	# Killed: down you go, and your head meets the floor.
	if is_dead and _death_fall < 1.0:
		_death_fall = move_toward(_death_fall, 1.0, delta / 0.9)

		if _death_fall >= 1.0:
			Sfx.play_flat(self, &"body_fall", 2.0, 0.9)

	juice.death = _death_fall

	# Camera feel reads the state, and writes only to the Camera3D.
	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var strafe := velocity.dot(global_transform.basis.x) / maxf(walk_speed, 0.01)
	var move_kind := 0

	if movement_state == MoveState.MOVING and current_move != null:
		match current_move.kind:
			MoveVariantRes.Kind.VAULT:
				move_kind = 2
			TraversalPlanner.KIND_LOWER:
				move_kind = 3
			TraversalPlanner.KIND_LEAP:
				move_kind = 4
			MoveVariantRes.Kind.MANTLE, TraversalPlanner.KIND_PULL_UP:
				move_kind = 1
			_:
				# Reaching for a hang, rounding a corner, letting go: no dip.
				move_kind = 0

	juice.intensity = camera_feel
	# The walk as drawn: between the last two ticks, like the body.
	var drawn_fraction := Engine.get_physics_interpolation_fraction() if get_tree().physics_interpolation else 1.0
	juice.gait = lerpf(_gait_before, gait, drawn_fraction)
	juice.grip_below = hand.grip_below(aim_transform()) if hand != null and hand.has_method("grip_below") else 0.0
	# The body under the view carries the walk (the old feel: the juice's bob).
	juice.locomotion_from_body = not legacy_feel
	juice.body_head = body_motion.head_offset(drawn_fraction) if not legacy_feel else Transform3D.IDENTITY
	juice.update(
		delta,
		horizontal_speed,
		walk_speed,
		clampf(strafe, -1.0, 1.0),
		(is_on_floor() or _on_stairs) and movement_state == MoveState.LOCOMOTION,
		is_crouched,
		_is_sprinting(),
		move_kind,
		move_progress,
		move_windup
	)
	_place_camera()


## The view: where the body is drawn this frame (between physics ticks, with
## physics interpolation on), looking where you look right now, plus camera
## feel on top. Gameplay never reads this; it aims from aim_transform().
func _place_camera() -> void:
	var interpolating := get_tree().physics_interpolation
	var fraction := Engine.get_physics_interpolation_fraction() if interpolating else 1.0
	var drawn := get_global_transform_interpolated().origin

	# A stair step was cancelled from the eye height on the tick it happened,
	# but the body is only drawn part of the way up it yet: put back what the
	# drawing has not caught up with, or every step would dip the view.
	var unfinished := (1.0 - fraction) * _step_change_tick
	var eye := drawn + global_basis * (neck.position + Vector3.UP * unfinished)
	camera.global_transform = Transform3D(neck.global_basis.orthonormalized(), eye) * juice.view_transform()


## Lean out to the side to look round a corner. The head moves; the body,
## and with it the lightgem, stays where it is.
func _update_lean(delta: float) -> void:
	var wanted := 0.0

	if movement_state == MoveState.LOCOMOTION and not is_dead:
		wanted = Input.get_action_strength("lean_right") - Input.get_action_strength("lean_left")

	# No leaning through a wall.
	if wanted != 0.0:
		var side := global_transform.basis.x * signf(wanted)
		var from := neck.global_position
		var blocked := scanner.ray(from, from + side * (lean_distance + 0.2))

		if not blocked.is_empty():
			var hit: Vector3 = blocked["position"]
			var room := maxf(from.distance_to(hit) - 0.2, 0.0)
			wanted = signf(wanted) * minf(absf(wanted), room / maxf(lean_distance, 0.01))

	lean = lerpf(lean, wanted, 1.0 - exp(-lean_speed * delta))

	if absf(lean) < 0.001:
		lean = 0.0

	juice.lean_offset = lean * lean_distance
	juice.lean_roll = -lean * deg_to_rad(lean_roll_degrees)


# ---------------------------------------------------------------------------
# Debug
# ---------------------------------------------------------------------------

func _debug_draw() -> void:
	var state_name: String = MoveState.keys()[movement_state]
	var line := state_name

	if current_move != null:
		line += "  >  %s  (%.2fs)" % [current_move.label, current_move.duration]

	if is_crouched:
		line += "  [crouched]"

	if _chain_links > 0:
		line += "  [chained]"

	if _assist_active:
		line += "  [assisted jump]"

	DebugDraw2D.set_text("Traversal", line)
	DebugDraw2D.set_text("Light", "%.2f   exposure %.2f" % [get_light_level(), get_exposure()])
	DebugDraw2D.set_text("Pose", "%s   L %.1f  R %.1f" % [body_pose.pose, body_pose.left_weight, body_pose.right_weight])

	# Where an arm rig would put the hands: left red, right blue.
	if body_pose.left_weight > 0.05:
		DebugDraw3D.draw_sphere(body_pose.left_target.origin, 0.05, Color(1.0, 0.3, 0.3))

	if body_pose.right_weight > 0.05:
		DebugDraw3D.draw_sphere(body_pose.right_target.origin, 0.05, Color(0.3, 0.5, 1.0))

	if frob != null:
		DebugDraw2D.set_text("Frob", frob.current_prompt())

	if inventory != null:
		var belt_text := "none"
		var item: Dictionary = inventory.selected_item()

		if not item.is_empty():
			belt_text = "%s x%d" % [item["name"], item["count"]]

		DebugDraw2D.set_text("Purse", "%d   belt: %s" % [inventory.purse, belt_text])

	# While hanging, mark the lip a jump would leap to.
	if movement_state == MoveState.HANGING and not hang_target.is_empty():
		var target_face: Vector3 = hang_target["face_point"]
		var target_lip: float = hang_target["lip_y"]
		var marker := Vector3(target_face.x, target_lip, target_face.z)
		DebugDraw3D.draw_sphere(marker, 0.1, Color.MAGENTA)
		DebugDraw3D.draw_line(neck.global_position - Vector3.UP * 0.3, marker, Color.MAGENTA)

	var p := cached_profile

	if p == null:
		var why := scanner.last_reject if _last_reject == "" else _last_reject
		DebugDraw2D.set_text("Obstacle", why)
		return

	var candidates := planner.classify(p, is_crouched, _is_sprinting(), variant_table)
	var first := "none"

	if not candidates.is_empty():
		first = String(candidates[0].label)

	var thickness_text := "thick"

	if p.thickness < INF:
		thickness_text = "%.2f" % p.thickness

	DebugDraw2D.set_text(
		"Obstacle",
		"h %.2f  t %s  speed %.1f  ->  %s   %s" % [
			p.height, thickness_text, p.approach_speed, first, _last_reject
		]
	)

	DebugDraw3D.draw_sphere(p.face_point, 0.05, Color.YELLOW)
	DebugDraw3D.draw_sphere(p.top_point, 0.05, Color.GREEN)
	DebugDraw3D.draw_sphere(p.landing, 0.06, Color.DODGER_BLUE)
	DebugDraw3D.draw_line(p.face_point, p.face_point + p.face_normal * 0.4, Color.YELLOW)

	if p.thickness < INF:
		DebugDraw3D.draw_sphere(p.far_edge, 0.05, Color.ORANGE)
		DebugDraw3D.draw_line(p.face_point, p.far_edge, Color.ORANGE)

	if p.has_far_floor:
		DebugDraw3D.draw_sphere(p.far_floor, 0.06, Color.CYAN)
