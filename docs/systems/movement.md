# Movement and traversal

[PlayerController.gd](../../scripts/PlayerController.gd) owns the first-person body, movement state, health, stealth measurements, and movement input. Physics uses metres, metres per second, radians for rotations, and game-time seconds unless a property explicitly names degrees or dB. Cosmetic camera/arm motion does not change the transform used to aim interactions or attacks.

## Responsibilities

| Source | Responsibility |
| --- | --- |
| [PlayerController](../../scripts/PlayerController.gd) | Input, velocity, stairs, jumping, crouch, leaning, traversal playback, hangs, climbs, water, health, sound/exposure, camera placement. |
| [TraversalScanner](../../scripts/PlayerUtils/TraversalScanner.gd) | Read-only physics measurement and capsule fit/sweep queries. |
| [ObstacleProfile](../../scripts/PlayerUtils/ObstacleProfile.gd) | Measurements produced by a scan, including feet-relative height and landing headroom. |
| [MoveVariant](../../scripts/PlayerUtils/MoveVariant.gd) | Resource rows matching stance/height/speed and configuring traversal playback. |
| [TraversalPlanner](../../scripts/PlayerUtils/TraversalPlanner.gd) | Ordered classification and collision-validated mantle/vault/hang/lower/corner/leap paths. |
| [TraversalMove](../../scripts/PlayerUtils/TraversalMove.gd) | Baked path, duration, contact, exit velocity, and hang destination. |
| [ClimbVolume](../../scripts/PlayerUtils/ClimbVolume.gd) | Flat climb or rope overlap registration, facing, and pursuit endpoints. |
| [VerletRope](../../scripts/PlayerUtils/VerletRope.gd) | Simulated rope/chain, grip parameter, swing velocity, following overlap volume and MultiMesh. |
| [BodyMotion](../../scripts/PlayerUtils/BodyMotion.gd) | Cosmetic head/shoulder springs and interpolated tick output. |
| [BodyPose](../../scripts/PlayerUtils/BodyPose.gd) | Movement pose name and world-space hand targets/weights. |
| [CameraJuice](../../scripts/PlayerUtils/CameraJuice.gd) | Cosmetic camera springs, shake, zoom, move feedback, and FOV. |

The controller expects its scene's `CollisionShape3D` to contain a capsule and `Neck/Camera3D` to provide the eye. `_ready()` duplicates the capsule before resizing it, captures its standing dimensions, configures scanner/planner/body motion, captures the mouse, creates combat and optional HUD, and uses existing inventory/frob/hand child references. Other systems call its APIs through method/property checks or the player group.

## Input and state

Input actions are `move_left`, `move_right`, `move_forward`, `move_back`, `jump`, `sprint`, `crouch`, `lean_left`, and `lean_right`; mouse movement changes yaw/pitch. Lean fallbacks are Z/C. F10 switches `legacy_feel` in debug builds. The controller handles mouse recapture; its suppression window and consumed attack press prevent the shared throw/attack button from triggering another action on the same press. Action bindings already in the project take precedence over runtime fallbacks.

| `MoveState` | Body movement and transitions |
| --- | --- |
| `LOCOMOTION` | Velocity-driven walk/sprint/crouch/jump/fall, ground acceleration, air steering, stair stepping, and wading. A valid plan enters `MOVING`; pushing into an overlapping climb can enter `CLIMBING`; deep unsupported water enters `SWIMMING`. |
| `MOVING` | Position follows `TraversalMove.points`, with optional windup and yaw. Each playback segment is swept again. Completion restores exit velocity and locomotion or enters a hang; a new obstruction cancels the move. Eligible buffered jump can chain another move. |
| `HANGING` | Feet are unsupported; shimmy follows measured lips, corners can become planned moves, pushing into the wall peeks, and crouch drops. Jump can pull up, leap to an aimed/side/upper ledge, or release toward a deeper catch target. Regrab delay prevents immediate recatch after dropping. |
| `CLIMBING` | Attached to a registered flat volume or rope. No normal gravity; input climbs, and jump detaches with exit velocity. Near the top a valid mantle enters `MOVING`. Aligned overlapping flat volumes can hand over; ropes cannot. |
| `SWIMMING` | Facing-directed swimming; crouch dives, jump rises or attempts a bank exit. The eye floats above the surface. Shallow support returns to locomotion/wading. Entering water releases carried objects and reduces falling speed. |

Swimming entry requires feet deeper than `swim_start_depth` and floor depth greater than `water.SWIM_DEPTH + swim_depth_hysteresis`, with no stair lock. Exit uses a shallower/support-sensitive threshold to avoid oscillation. Stair collision moves the body immediately while view following smooths the step; stale `is_on_floor()` results are deliberately invalidated after states that bypass `move_and_slide()`.

## Controller integration APIs

Signatures below preserve source annotations. A default written with `:=` is inferred by GDScript; bare `Array` does not enforce an element type. Invalid/null inputs are accepted only where explicitly described.

| API | Input, output, effects, and sentinel |
| --- | --- |
| `aim_transform() -> Transform3D` | World-space neck transform including lean, excluding bob/shake/punch. Use for gameplay aim. |
| `get_feet_position() -> Vector3` | World origin minus half standing capsule height, including when crouched. |
| `get_light_level() -> float`, `get_exposure() -> float` | Light/exposure in 0..1. LightGem supplies light when available; otherwise `debug_light_level`. Stance, motion, and underwater visibility affect exposure. |
| `get_sight_points() -> Array` | Three world `Vector3` samples: head, chest, shins. Only the head shifts with lean. |
| `climb_goal() -> Vector3` | Climb endpoint, point over the held lip, or final move's feet destination. `Vector3.INF` outside those states, including swimming. |
| `is_off_feet() -> bool` | Traversal, climbing, hanging, or airborne locomotion; swimming is excluded. |
| `add_climb_volume(volume: Area3D) -> void`, `remove_climb_volume(volume: Area3D) -> void` | Maintain overlap registrations. Removal of the active climb hands over to an aligned flat volume or detaches. Volumes must expose the climb contract below. |
| `add_water_volume(volume: Area3D) -> void`, `remove_water_volume(volume: Area3D) -> void` | Maintain overlap registrations. `_update_water()` selects valid water, including a group lookup fallback after teleport. Water contract is in [interaction](interaction.md). |
| `is_underwater() -> bool`, `wade_scale() -> float` | Smoothed neck-base surface test; depth-scaled locomotion multiplier (1 outside water/locomotion). |
| `shove(push: Vector3, seconds: float) -> void` | Replaces a timed horizontal world push; Y is ignored. Inputs are not clamped by this setter. |
| `warn_attack(from: Node3D) -> void` | Forwards to a compatible HUD; the HUD decides how to display the warning. |
| `take_damage(amount: float, from: Node) -> void` | Dead/nonpositive damage exits. Invalid source becomes `null`. Combat filters first, even when invulnerable; remaining positive damage reduces health, updates recovery time, emits `damaged`, and may die. `from` may be null. |
| `hazard_hit(_hazard: Node, lethal_speed: float) -> void` | Deals 40 damage if `_hazard.into_speed(velocity)` (or horizontal speed) exceeds the threshold, at most once per game second. |
| `recover_limit() -> float` | Current shield's recovery ceiling. Whole lost shields stay lost; the current partial shield recovers after `recover_delay`. |
| `teleport(xform: Transform3D) -> void` | Sets world transform, clears velocity/traversal/hang/jump/shove/stair state, releases rope grip, resets interpolation, and blocks old contacts for the next physics tick. Overlap registrations are retained for teleports within a volume. Does not reset inventory or health. |
| `set_legacy_feel(on: bool) -> void` | Switches comparison feel, resets body motion, and informs HUD. |
| `spend_attack_press() -> void`, `is_attack_press_spent() -> bool`, `is_mouse_input_swallowed() -> bool` | Shared-action consumption until release and recapture suppression checks. |

`damaged(amount: float)` reports actual post-defence damage; `died` reports death. Footsteps, landings, climbing, traversal, and swimming emit SoundBus events and Sfx. Surface metadata `surface` names the floor material; `surface_db: Dictionary` maps surface names to dB offsets, with unnamed floors treated as stone for loudness. Shoulder carrying changes speed and sound. Health death optionally reloads the level after the death delay.

## Traversal data

`ObstacleProfile` is a RefCounted record, with inferred field types from its initial values unless annotated. All points and normals are world-space; `face_normal` is horizontal/unit/outward. `height = top_point.y - feet_y`, so jumping changes the same obstacle's measured height.

| Fields | Schema/meaning |
| --- | --- |
| `face_point`, `face_normal`, `top_point`, `top_normal`, `far_edge`, `far_floor`, `landing` | `Vector3`; front face/top/far edge/floor and mantle feet surface. `far_edge` is meaningful only for finite thickness. |
| `feet_y`, `height`, `thickness`, `approach_speed`, `facing_dot` | `float`; feet world Y, relative height, measured thickness, nonnegative inward speed, and facing dot. Thickness starts as `INF` if the top does not end within the survey. |
| `has_far_floor`, `airborne` | `bool`; gate floor data and variant matching. |
| `headroom` | `Headroom.STANDING`, `CROUCHED`, or `BLOCKED`. Thin tops below standable thickness are blocked for standing/mantling. |
| `collider: Object` | Face collider or null. |
| `far_drop() -> float` | `feet_y - far_floor.y`, or `INF` without a far floor; a higher floor gives negative drop. |

`MoveVariant` is a Resource. `label: StringName` is presentation, `kind` is `VAULT/MANTLE/HANG_ENTER`; height bounds are inclusive feet-relative metres. `air` is ANY/GROUNDED/AIRBORNE, `stance` is ANY/SNEAK/NOT_SNEAK/SPRINT, and `min_speed` is inward m/s. For `needs_thin`, permitted thickness is `thickness_base + thickness_per_speed * approach_speed`, and `far_drop()` must meet `max_drop`. Playback uses `move_speed`, `min_time`, `max_time`, `smoothing` (0..1), `speed_kept` (0..1), and `noise_db`.

`default_table() -> Array[Resource]` creates fresh built-in rows tuned for a 2 m capsule. `make(p_label: StringName, p_kind: Kind, p_min_height: float, p_max_height: float, p_move_speed: float, p_min_time: float, p_max_time: float, p_smoothing: float, p_speed_kept: float) -> Resource` initializes those values and leaves other tuning at defaults. Empty controller `variant_table` uses the built-in table. Priority is table order, but a matching row with a blocked path is skipped in favor of the next matching row.

`TraversalMove` stores `points: PackedVector3Array` of **body origins**, not foot contacts. `bake() -> void` builds cumulative lengths and `total_length`; call it after changing points. `position_at(s: float) -> Vector3` clamps distance fraction to 0..1, returns `Vector3.ZERO` for no points, and the last point for zero length. Changing points without rebaking leaves stale distances.

Move playback fields include seconds `duration/windup_time`, metres `windup_dip`, normalized `smoothing/ease_out`, radians `yaw_delta`, world `exit_velocity`, crouch-shape bool, entry speed and retained fraction, noise dB, and optional contact (`has_contact`, world point/normal). `ends_in_hang`, `hang_normal`, and world `hang_lip_y` describe the destination. Planner-only kinds are `KIND_PULL_UP=100`, `KIND_LOWER=101`, `KIND_CORNER=102`, `KIND_LEAP=103`, `KIND_DROP_RELEASE=104`.

## Scanner and planner APIs

Call `TraversalScanner.setup(p_body: CharacterBody3D, p_radius: float, p_standing_height: float, p_crouch_height: float) -> void` before queries and assign it to `TraversalPlanner.scanner`. Directions are expected to be meaningful normalized horizontal world directions; the routines do not generally sanitize zero/invalid directions. `mask` selects scanned terrain; capsule safety additionally uses `body_mask`. Reusable shapes shrink by `SKIN=0.02 m` so resting contacts are not treated as penetration. `extra_exclude: Array[RID]` is used by ray/fit/sweep primitives; the broad face sweep explicitly excludes only the player.

| API | Contract |
| --- | --- |
| `feet_position() -> Vector3`, `origin_for_feet(surface_point: Vector3) -> Vector3` | Convert between world feet and standing-capsule origin; origin conversion adds floor clearance. |
| `scan(direction: Vector3, velocity: Vector3, airborne: bool) -> ObstacleProfile` | Current-origin scan; null on rejection. |
| `scan_from(origin: Vector3, direction: Vector3, velocity: Vector3, airborne: bool, lookahead_time := -1.0, max_top_y := INF) -> ObstacleProfile` | Alternate body-origin scan, optionally carried velocity and world ceiling limit. Negative lookahead uses configured default; null and `last_reject` on failure. Measures face/top/thickness/far floor/landing/headroom. |
| `edge_below(direction: Vector3, needed_drop: float) -> Dictionary` | `{face_point: Vector3, normal: Vector3, lip_y: float}` or `{}`; checks the floor ends ahead and finds the ledge face below. |
| `find_jump_target(direction: Vector3, min_distance: float, max_distance: float, max_rise: float, max_drop: float) -> Dictionary` | Gap followed by standable landing `{point: Vector3, distance: float}`, or `{}`. Bounds/distances are metres from feet. |
| `ray(from: Vector3, to: Vector3, hit_back_faces := true) -> Dictionary` | Solid-body Godot hit record (position/normal/collider/RID etc.) or `{}`. No areas/inside hits. |
| `fits(origin_position: Vector3, crouched: bool) -> bool` | Skin-shrunk capsule free at this body origin; crouch centre drops to preserve feet. |
| `motion_is_clear(from: Vector3, to: Vector3, crouched: bool) -> bool` | End fit plus swept route; catches thin obstacles missed by point samples. |
| `path_is_clear(points: PackedVector3Array, crouched: bool) -> bool` | Consecutive motion checks; empty/single-point paths return true without an isolated fit test. |
| `classify(profile: ObstacleProfile, is_sneaking: bool, is_sprinting: bool, table: Array[Resource]) -> Array[MoveVariantRes]` | Matching rows in priority order; skips resources not castable to MoveVariant; empty result when none match. Requires nonnull profile. |
| `generate(profile: ObstacleProfile, variant: MoveVariantRes, start: Vector3) -> TraversalMove` | Baked validated move or null; `start` is world body origin. Mantles can retry crouched and reduced clearance; vaults require far floor; hangs require standing fit. |
| `hang_anchor(face_point: Vector3, normal: Vector3, lip_y: float) -> Vector3` | Body origin outside the face with eyes below world lip Y. |
| `water_exit(profile: ObstacleProfile, start: Vector3, min_floor_y: float) -> TraversalMove` | Validated bank exit or thin-rail crossing to a sufficiently high interior floor; null otherwise. |
| `pull_up(hang_normal: Vector3, start: Vector3, lip_y := NAN) -> TraversalMove` | Validates the actual held lip, rather than a higher shelf; NAN infers its Y from the anchor; null on failure. |
| `lower(edge: Dictionary, start: Vector3, current_yaw: float) -> TraversalMove` | Edge schema above; validated lowering with turn to the wall, or null. |
| `probe_hang(point: Vector3, normal: Vector3, lip_y: float, max_lip_change: float) -> Dictionary` | `{anchor: Vector3, normal: Vector3, lip_y: float, face_point: Vector3}` or `{}`. Probe padding does not enlarge permitted lip-height change. |
| `corner(start: Vector3, hang_normal: Vector3, lip_y: float, direction: Vector3) -> TraversalMove` | Inside/outside turn to another hang, or null. |
| `leap(start: Vector3, target: Dictionary, from_normal: Vector3) -> TraversalMove` | Target requires anchor/normal/lip_y; optional face_point supplies hand contact. Tries several arcs and higher lift before null. |

Failed move planning sets `last_reject`; it is diagnostic text, not an enum. Empty/malformed dictionaries are not accepted as valid builder inputs. Timing and collision validation run in game time, including slow motion. The controller independently limits grab rise/fall speeds, chain count/stance, jump assist tolerance, and reattachment delays.

## Climb and presentation APIs

`ClimbVolume` uses local -Z into a flat wall, a BoxShape3D covering the full climb, and world vertical speeds. `rope` changes the interpretation to a line through its origin. `get_climb_normal() -> Vector3` returns horizontal outward +Z or `Vector3.BACK` for degenerate facing. `get_rope_normal(from: Vector3) -> Vector3` returns the horizontal rope-to-point direction or flat normal when coincident. `get_plane_point() -> Vector3` returns the origin. `ends() -> Array` returns two world Vector3 endpoints (foot, top), uses metadata `climb_ends` when present, and falls back to `[global_position, global_position]` without a box. Callers placing metadata must supply exactly the expected endpoints; it is not validated.

`VerletRope` requires positive length and segment count and initialized points; it extends ClimbVolume. `closest_param(position: Vector3) -> float` selects the nearest simulated **point** distance in metres from the anchor. `rope_point(param: float) -> Vector3` interpolates at clamped 0..length. `rope_velocity(param: float, _delta: float) -> Vector3` uses the nearest point and the last integrated game step, caps to `max_swing_speed`, and returns zero before a positive integration; `_delta` is unused. `grip(param: float, push: Vector3) -> void` sets the distance and desired world acceleration, while `release() -> void` clears grip/push and preserves momentum. The solver rescales previous travel when time steps change and reseeds when its anchor moved over 1 m.

`BodyMotion.Frame` has world `velocity: Vector3`, body `facing: Basis`, bool `grounded/locomotion/crouched`, float gait (0..2 steps), lean (-1..1), current/target eye drop in metres, and reference walk/sprint/crouch speeds. `setup(footfall_curve: Curve, eye_rate: float) -> void` accepts null to choose the default curve. `step(delta: float, frame: Frame) -> void` ignores nonpositive delta, caps a tick's integration at 1/30 s, and substeps springs. `on_land(fall_speed: float)` and `on_jump()` inject impulses; `reset()` clears motion history. `head_offset(fraction: float)` and `shoulder_offset(fraction: float)` return interpolated `Transform3D` offsets. The footfall curve samples normalized step phase and signed rise/fall; body output is cosmetic.

`BodyPose.update(player: CharacterBody3D, delta: float) -> void` expects PlayerController fields, chooses a `pose: StringName`, and updates world `left_target/right_target: Transform3D` and 0..1 weights. Carry, hang, mantle, vault, ladder, and rope poses derive targets from existing geometry. [HandContacts/HandSlot](interaction.md) implement the current persistent presentation contacts.

`CameraJuice.setup(p_camera: Camera3D) -> void` requires a camera and captures base FOV. `update(delta: float, horizontal_speed: float, reference_speed: float, strafe: float, grounded: bool, crouched: bool, sprinting: bool, move_kind: int, move_s: float, windup := 0.0) -> void` advances spring/arc/shake output and writes FOV. Presentation move codes are 0 none, 1 mantle/pull-up, 2 vault, 3 lower, 4 leap, rather than raw TraversalMove.kind. `view_transform() -> Transform3D` is eye-local; `trauma() -> float` is 0..1, `add_trauma(amount: float)` clamps it, `set_zoom(amount: float)` reduces FOV in degrees. Event hooks cover landing/jump/hit/windup/swing/crouch/throw/kick/catch/impact. Side cuts use +1 left/-1 right; `hurt_from(from: Vector3, strength: float)` expects player-local attack direction. `locomotion_from_body` replaces legacy bob with `body_head`; lean remains independent of intensity.
