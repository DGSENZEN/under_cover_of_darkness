# Locomotion Feel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One simulated body under the first-person camera and hands, momentum at today's speeds, and an F10 switch back to the old feel, pinned by a new `motion_test` suite.

**Architecture:** A RefCounted `BodyMotion` is stepped once per physics tick by the controller with a `Frame` of what the body feels (velocity, gait, stance, lean) and produces a head offset (added to the view by `CameraJuice`) and a shoulder offset (added to the hands by `HandSlot`), both drawn between the last two ticks and scaled by `camera_feel`. The controller's ground movement becomes an along/across momentum model. `legacy_feel` (F10) brings every old path back at once.

**Tech Stack:** Godot 4.5.1 (GDScript), headless test scenes, Python 3 + PIL for the comparison plot.

**Spec:** `docs/superpowers/specs/2026-09-26-locomotion-feel-design.md`

## Global Constraints

- Godot binary: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`. Run every suite as `Godot --headless --fixed-fps 60 --quit-after 120000 --path . res://tests/<suite>.tscn` under `perl -e 'alarm 900; exec @ARGV'` (a parse error hangs a headless run); check scripts first with `Godot --headless --path . --check-only -s <script>`.
- Cross-script references use `preload` consts, never `class_name` (CLI runs cannot see unregistered class names).
- Gameplay never reads the body: `aim_transform()`, `get_sight_points()`, the frob eye and the lean ray are unchanged.
- Top speeds (walk 6.5, sprint 8.5, crouch 3.0), jump height and timing, air control, coyote time and the jump buffer are unchanged.
- Locomotion rotates the view by at most 0.35° (0.0061 rad); landings may nod up to 1°. Sprinting does not change the FOV on the new path.
- `camera_feel` 0 means the body's outputs are exactly `Transform3D.IDENTITY`.
- Caps after scaling: head offset ≤ 0.15 m and ≤ 3° per axis; shoulder offset ≤ 0.2 m and ≤ 6° per axis.
- New strides: walk 2.0 m, sprint 2.4 m (crouch stays 1.1). Old path: 1.6 and 1.9.
- Every run is grepped for `SCRIPT ERROR` even when every check passes.
- Baseline at `afab738`: 399 checks pass; wardrobe K6 and K6b already fail (not ours; leave them).
- Commit per task on branch `locomotion-feel`, never push. End every message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- A teleport while walking (gym bay keys, test placement, a respawn): the head must not jolt. Pinned by Y19 in Task 3.
- A hit-stop or slow motion (`Engine.time_scale` 0.05) while something sets velocity directly (a shove, a kick): dividing by a tiny delta must not throw the body. Pinned by Y19 in Task 3.
- `camera_feel` above 1 (the export allows 2): caps apply after scaling. Pinned by Y19 in Task 3.
- Leaving locomotion mid-stride (a mantle, a hang) and coming back with a stale velocity: the first tick back feeds no acceleration. Pinned by Y19's teleport case and by Task 3's step at the end of every tick.
- Raising a guard or releasing sprint at full speed: the over-speed eases off (0.15 s), never a planted stop. Pinned by Y8b in Task 2.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/PlayerUtils/BodyMotion.gd` (new) | The body: footfalls, torso lean, legs, stance knee bend, lean dip, breathing, arms; outputs drawn between ticks |
| `scripts/PlayerController.gd` | Steps the body each tick, sends jump/land, momentum model, strides, `legacy_feel`, F10, `footfall_curve` export |
| `scripts/PlayerUtils/CameraJuice.gd` | `locomotion_from_body` + `body_head`: skips bob, strafe roll and sprint FOV, adds the head offset |
| `scripts/Interaction/HandSlot.gd` | New path: shoulder offset + sprint carry by `sprint_lean()` replace bob, hop, run and wobble |
| `scripts/UI/StealthHUD.gd` | `show_caption()` and the "old movement" tag (temporary) |
| `Player.tscn` | The `footfall_curve` Curve sub-resource |
| `tests/motion_test.gd/.tscn` (new) | Checks Y1–Y19 |
| `tests/sound_test.gd` | M12 runs with `legacy_feel` on |
| `tests/visual/stage_motion.gd/.tscn` (new) | Scripted run on both paths, CSV traces |
| `tools/plot_motion.py` (new) | Draws the old/new comparison PNG from the traces |

---

### Task 1: BodyMotion, the body model

**Files:**
- Create: `scripts/PlayerUtils/BodyMotion.gd`
- Create: `tests/motion_test.gd`, `tests/motion_test.tscn`

**Interfaces:**
- Produces:
  - `class Frame` with `velocity: Vector3`, `facing: Basis`, `grounded: bool`, `locomotion: bool`, `crouched: bool`, `gait: float`, `lean: float`, `eye_drop: float`, `eye_target_drop: float`, `walk_speed: float = 6.5`, `sprint_speed: float = 8.5`.
  - `var intensity := 1.0`
  - `func setup(footfall_curve: Curve, eye_rate: float) -> void`
  - `func step(delta: float, frame: Frame) -> void`
  - `func on_jump() -> void`, `func on_land(fall_speed: float) -> void`, `func reset() -> void`
  - `func head_offset(fraction: float) -> Transform3D` (eye space: x right, y up, z back)
  - `func shoulder_offset(fraction: float) -> Transform3D` (camera space, relative to the head)
  - `func sprint_lean() -> float` (0..1)
  - `static func default_footfall() -> Curve`
  - Constants the tests read: `HEAD_CAP := 0.15`, `HEAD_TURN_CAP := deg_to_rad(3.0)`, `SHOULDER_CAP := 0.2`, `SHOULDER_TURN_CAP := deg_to_rad(6.0)`.

- [ ] **Step 1: Write the suite scaffold and the model checks (synthetic frames, no player needed)**

`tests/motion_test.gd` follows `tests/smooth_test.gd`: `extends Node3D`, `results: Array[String]`, `_check(name, ok, detail)`, prints `==== RESULTS ====` then quits. The `.tscn` is a Node3D with the script. Task 1's checks build a standalone body (`BodyMotionScript.new()`, `setup(BodyMotionScript.default_footfall(), 12.0)`) and feed it frames at 1/60 s:

- `_walk(body, speed, stride, seconds, crouched := false) -> Array`: per tick, advance `gait = fposmod(gait + speed / stride / 60.0, 2.0)`, velocity `(0, 0, -speed)`, facing `Basis.IDENTITY`, grounded and locomotion true; record `{head: body.head_offset(1.0), shoulder: body.shoulder_offset(1.0), step: crossed an integer}`.
- Y1: after a walk and `on_land(14.0)` with `intensity = 0.0`, `head_offset(f)` and `shoulder_offset(f)` are exactly `Transform3D.IDENTITY` for f in 0, 0.5, 1.
- Y2 (model): walking (6.5, 2.0), sprinting (8.5, 2.4, speed ramped from 6.5) and crouch-walking (3.0, 1.1) for 3 s, skipping the first 1 s: at every step tick the head's y is lower than the tick before, and the lowest y before the next step comes within 6 ticks of the step.
- Y3: steady walk: peak-to-peak y in [0.008, 0.018], peak-to-peak x ≤ 0.010, every |euler.x| and |euler.z| ≤ 0.0061.
- Y4: steady sprint (after 1.5 s at 8.5): mean z ≤ -0.02, mean y ≤ -0.01, rotation ≤ 0.0061.
- Y5: steady crouch walk: p2p y < the walk's p2p y, and p2p x ≥ p2p y.
- Y6: walk 1.5 s, stop over 9 ticks (6.5 → 0 linearly), then from 0.6 s after the stop, for 1 s, |head.origin| ≤ 0.003.
- Y11 (model): idle body, `on_land(9.6)`: min y in [-0.04, -0.02]; `on_land(13.9)` on a settled body: min y in [-0.075, -0.045]; `on_land(40.0)`: min y ≥ -0.125; 0.5 s after each, |y| ≤ 0.004.
- Y12 (model): steady walk: for each step, the tick of min(head.y + shoulder.y) is later than the tick of min(head.y); landing 13.9: min(head.y + shoulder.y) < min(head.y); a start (0 → 6.5 over 0.35 s): max shoulder.z > 0.002; a stop (6.5 → 0 over 9 ticks): min shoulder.z < -0.003.
- Y13: ten `step(0.25, walking frame)` calls, then `on_land(40.0)` and ten more: every head and shoulder offset is inside the caps.
- Y14 (model): `head_offset(0.5).origin` equals the midpoint of `head_offset(0.0).origin` and `head_offset(1.0).origin` (±1e-6) mid-walk.
- Y15: standing still, `eye_target_drop` set to 0.8 and `eye_drop` eased each tick by `eye_drop += (target - eye_drop) * (1 - exp(-12 / 60.0))`; the view's drop `eye_drop - head.y` is ≥ `eye_drop - 0.002` while descending, its maximum is 0.802 to 0.82, and from 0.6 s on it stays within 0.0025 of 0.8. Standing back up (target 0): minimum -0.02 to -0.002, settled by 0.6 s.
- Y16 (model): lean eased 0 → 1 (`lean += (1 - lean) * (1 - exp(-9 / 60.0))`): at 0.5 s head.y in [-0.015, -0.005]; over the last 0.2 s of a 1 s hold, y varies by < 0.002.

- [ ] **Step 2: Run the suite and see it fail**

Run: `perl -e 'alarm 300; exec @ARGV' $GODOT --headless --fixed-fps 60 --quit-after 20000 --path . res://tests/motion_test.tscn`
Expected: a parse error for the missing `BodyMotion.gd` (after creating an empty stub `extends RefCounted`, every Y check FAILs).

- [ ] **Step 3: Implement `BodyMotion.gd`**

Constants (starting points, named in the file): `KEEP 0.2`, `TORSO 0.6`, `ACC_CAP 45.0`; footfall half-travel `WALK_DROP 0.006`, `SPRINT_DROP 0.010`, `CROUCH_DROP 0.003`; weight shift `WALK_SHIFT 0.003`, `SPRINT_SHIFT 0.003`, `CROUCH_SHIFT 0.004`; `STEP_ROLL deg 0.25`; torso gains `LAG_START 0.00035`, `LAG_STOP 0.0008`, `BANK 0.0005`, spring `TORSO_OMEGA 12, TORSO_ZETA 0.8`; `SPRINT_FORWARD 0.03`, `SPRINT_DOWN 0.02`; legs `LEG_OMEGA 16`, `LEG_SOFT_OMEGA 10`, `LEG_ZETA 0.8`, `JUMP_RISE 0.02`; stance `STANCE_OMEGA 15, STANCE_ZETA 0.9`; `LEAN_DIP 0.01`; arms `ARM_OMEGA 14, ARM_ZETA 0.45, ARM_EXTRA 0.0004`; breath `BREATH_HEAD 0.001`, `BREATH_HANDS 0.002`, rates 0.25 → 0.55 Hz.

The tick (the one algorithm the checks do not determine):

```
dt = minf(delta, 1/30); if delta <= 0: return
active = frame.locomotion
flat velocity -> local = frame.facing.inverse() * v (y = 0), speed = its length
accel = 0; if active and _have_prev: accel = (local - _local_prev) / delta, limit_length(ACC_CAP)
_local_prev = local; _have_prev = active
tangential/normal split of accel along local.normalized() (all tangential below 0.3 m/s)
gain = LAG_START if accel.dot(local) > 0 else LAG_STOP
lean_target = -tangential * gain + normal * BANK * clamp(speed / walk, 0, 1)   (y = 0)
torso spring (_lean, _lean_v) toward lean_target; rotation comes only from _lean:
    torso_pitch = _lean.z / TORSO, torso_roll = -_lean.x / TORSO
sprint posture (no rotation): _sprint blends toward clamp((speed - walk) / (sprint - walk)) over 0.25 s
    (0 when crouched or inactive); posture = dir(local) * SPRINT_FORWARD * _sprint + (0, -SPRINT_DOWN * _sprint, 0)
gait weight: toward clamp(speed / walk, 0, 1) if active and grounded else 0, over 0.12 s; crouch blend over 0.15 s
footfall: phase = fposmod(gait, 1), stride = fposmod(gait, 2) / 2
    drop = footfall.sample(phase) * amp_drop * weight
    side = sin(TAU * stride + 0.314) * amp_shift * weight; roll = -side / amp_shift_max * STEP_ROLL
legs: _leg_omega relaxes to LEG_OMEGA at (LEG_OMEGA - LEG_SOFT_OMEGA) / 0.6 per s;
    spring (_leg, _leg_v) toward -LEAN_DIP * lean^2
stance: when eye_target_drop changes, _stance_v = eye_rate * (target - _stance); spring (_stance, _stance_v)
    toward the target; stance_y = eye_drop - _stance; inactive: _stance = eye_drop, _stance_v = 0
breath: exertion toward 1 while _sprint > 0.5 (+0.35/s) else 0 (-0.2/s); phase += lerp(0.25, 0.55, exertion) * dt
head = (side, drop + _leg + stance_y + breath_head, 0) + _lean + posture;
    head_turn = (torso_pitch * KEEP, 0, torso_roll * KEEP + roll)
arms, relative to the shoulders (a mass hanging from a moving base):
    x, z: spring (_arm, _arm_v) toward -tangential * ARM_EXTRA
    y: _arm_v.y += (-w^2 * _arm.y - 2 z w * _arm_v.y - head_acc_y) * dt, where head_acc_y is the
       head's own vertical acceleration (second difference of head.y over the last three ticks,
       capped at 60 m/s^2), so the arms lag a footfall and overshoot below it
    shoulder = _arm + (0, breath_hands, 0)
    shoulder_turn = (torso_pitch * (1 - KEEP), 0, torso_roll * (1 - KEEP) + roll * 2)
scale by k = intensity (k == 0: both IDENTITY), then clamp to the caps; _before = _now, _now = new
```

`on_land(fall)`: depth = `0.03 * fall / 9.6` below 9.6, else `0.03 + (fall - 9.6) * 0.007`, at most 0.12; hard = `clamp((fall - 9.6) / 7.4, 0, 1)`; `_leg_omega = lerp(LEG_OMEGA, LEG_SOFT_OMEGA, hard)`; `_leg_v -= depth * _leg_omega / 0.424` (0.424/ω is the peak of a ζ 0.8 spring kicked from rest); `_lean_v.z -= 0.35 * hard` (the nod); `_arm_v.y -= 0.8 * depth * ARM_OMEGA` (the arms keep falling when the legs stop, so the hands drop further than the view). `on_jump()`: `_leg_v += JUMP_RISE * _leg_omega / 0.424`. `default_footfall()`: `min_value -1, max_value 1`, points (0, 0.3, right tangent -7), (0.16, -1, 0), (0.62, 1, 0), (1, 0.3, left tangent -7).

- [ ] **Step 4: Run the suite; every Task 1 check passes, no SCRIPT ERROR**

Tune constants only inside the ranges the checks allow; if a check can only pass by leaving the spec's range, stop and report.

- [ ] **Step 5: Commit** — `feat(feel): BodyMotion, the body under the camera`

---

### Task 2: Momentum in the controller

**Files:**
- Modify: `scripts/PlayerController.gd` (exports near :43-60; `_apply_horizontal_movement` :869-931)
- Test: `tests/motion_test.gd`

**Interfaces:**
- Produces: `@export var legacy_feel := false` (Debug category); Locomotion exports `start_time := 0.12`, `sprint_build_time := 0.2`, `slow_time := 0.15`, `stop_time_walk := 0.15`, `stop_time_sprint := 0.25`, `turn_acceleration_walk := 45.0`, `turn_acceleration_sprint := 28.0`, `max_ground_acceleration := 60.0`; `func _ground_velocity(current: Vector3, wish: Vector3, target_speed: float, delta: float) -> Vector3`.

- [ ] **Step 1: Add the player to the suite and write the momentum checks**

`_ready` adds a floor (`Props.block(self, Vector3(0, -0.5, 0), Vector3(200, 1, 200))`), a 3 m platform (`Props.block(self, Vector3(-40, 1.5, 0), Vector3(6, 3, 6))`), the player (LightGem freed, invulnerable, `reload_on_death = false`, mouse visible) and a `_put_player(at, yaw)` like the smooth suite's. Speed is `Vector2(velocity.x, velocity.z).length()`.

- Y7: from standing (20 settled ticks) press forward: speed > 0 after 1 tick, ≥ 3.25 after 6, ≥ 6.175 after 24. From a steady walk, press sprint: the ticks to reach 8.4 are 21 to 42.
- Y8: release from a steady walk: speed < 0.05 within 12 ticks, travelled ≤ 0.6 m; from a steady sprint: within 18 ticks, ≤ 1.3 m. Y8b: sprinting steadily, release sprint only: the speed never drops by more than 0.35 m/s in one tick and reaches 6.6 within 30 ticks.
- Y9: from a steady walk forward, press back only: the velocity along back reaches 5.85 within 27 ticks. From a steady sprint forward, switch to right + sprint: while speed > 8, the forward component never drops faster than 31 m/s² per tick; it is under 0.5 within 27 ticks.
- Y10: standing, tap jump: the feet rise on the first or second tick after the press (same as with `legacy_feel`), apex feet rise 1.435 ± 0.02.
- Y11b: walking forward at full speed, jump and hold forward: horizontal speed 5 ticks after landing ≥ the speed on the tick before landing − 0.1.
- Legacy intact: with `legacy_feel = true`, from standing the speed after 6 ticks is 4.5 ± 0.05 and after 9 ticks 6.5.

- [ ] **Step 2: Run; Y7–Y9, Y8b fail on today's code (Y10, Y11b and legacy already pass: they are guards)**

- [ ] **Step 3: Implement `_ground_velocity` and route the ground branch through it unless `legacy_feel`**

No input: `move_toward(ZERO, reference / stop_time)` with `t = clamp((|v| - walk) / (sprint - walk))`, `reference = lerp(walk, sprint, t)`, `stop_time = lerp(stop_time_walk, stop_time_sprint, t)`. With input: `along = v·wish`, `across = v - wish * along`; below target, `rate = clamp(gap / tau, 2.0, max_ground_acceleration)` with `tau = start_time` while `along < walk_speed - 0.01`, else `sprint_build_time`, and `along = min(along + rate * dt, target)`; above target, `rate = clamp(-gap / slow_time, 2.0, max_ground_acceleration)`, `along = max(along - rate * dt, target)`; `across.move_toward(ZERO, lerp(turn_acceleration_walk, turn_acceleration_sprint, t) * dt)`; return `wish * along + across`. The old `move_toward` stays under `if legacy_feel`.

- [ ] **Step 4: Run the motion suite, then traversal, polish, smooth, combat, stealth; all pass, no SCRIPT ERROR**

- [ ] **Step 5: Commit** — `feat(feel): momentum at today's speeds`

---

### Task 3: The body carries the camera

**Files:**
- Modify: `scripts/PlayerController.gd` (`_ready`, `_physics_process` :564-600, `_track_motion` :959, landing block :748-775, `_try_buffered_jump` :846-866, `_set_crouched` :1543, `_update_footsteps` :1012-1062, `_update_view` :2643-2730, strides :184-186)
- Modify: `scripts/PlayerUtils/CameraJuice.gd` (`update` :240-400)
- Modify: `Player.tscn` (Curve sub-resource, `footfall_curve`)
- Test: `tests/motion_test.gd`

**Interfaces:**
- Consumes: Task 1's `BodyMotion` API; Task 2's `legacy_feel`.
- Produces: `var body_motion` on the player; `@export var footfall_curve: Curve` (Camera Feel category); `const LEGACY_STRIDE_WALK := 1.6`, `const LEGACY_STRIDE_SPRINT := 1.9`; strides `2.0` / `2.4`; `CameraJuice.locomotion_from_body: bool`, `CameraJuice.body_head: Transform3D`.

- [ ] **Step 1: Write the integration checks**

- Y2i: walking 3 s with the real player, per tick record `body_motion.head_offset(1.0).origin.y` and `player._steps`; at every footstep (the step count changes) after the first second, y is lower than the tick before and the step's lowest y comes within 6 ticks.
- Y3i: new path, steady walk: `juice.view_position.y` peak to peak ≤ 0.02; `legacy_feel` on: ≥ 0.05. Steady sprint: `camera.fov == juice.base_fov` (± 0.01) on the new path, `base_fov + 6` (± 0.3) on the old.
- Y14: `Engine.physics_ticks_per_second = 30`, walking, record the drawn head offset (`body_motion.head_offset(Engine.get_physics_interpolation_fraction()).origin`) with a smooth-suite style `Recorder` for 24 frames: every frame differs from the one before by > 1e-6; restore 60.
- Y17: standing, crouched (settled 1 s) and leaning right (settled 1 s): `player.global_transform.affine_inverse() * player.aim_transform()` and the sight points relative to the body match between `legacy_feel` off and on to 1e-5.
- Y19: walking, move the player 20 m sideways and zero its velocity: for 30 ticks |head.origin| ≤ 0.02. Standing, `Engine.time_scale = 0.05`, `player.shove(Vector3(8, 0, 0), 0.3)`, 30 ticks: head and shoulder offsets inside the caps; restore 1.0. `camera_feel = 2.0`, walk and land from the 3 m platform: inside the caps; restore 1.0.

- [ ] **Step 2: Run; they fail (no `body_motion` on the player yet)**

- [ ] **Step 3: Wire it**

- `_ready`: `body_motion = BodyMotionScript.new()`, `body_motion.setup(footfall_curve if footfall_curve != null else BodyMotionScript.default_footfall(), view_height_speed)`; a reused `_body_frame := BodyMotionScript.Frame.new()`.
- `_step_body(delta)` fills the frame (velocity, `global_basis`, `_on_floor_now() or _on_stairs`, `movement_state == LOCOMOTION and not is_dead`, `is_crouched`, `gait`, `lean`, `_neck_stand_y - _neck_base_y`, `(_standing_height - crouch_height) if is_crouched else 0.0`, walk and sprint speeds), sets `body_motion.intensity = camera_feel` and steps; it runs at the end of every `_physics_process`, including the dead branch.
- `_track_motion`: on its teleport branch, `body_motion.reset()`.
- Jump and landing: new path `body_motion.on_jump()` / `on_land(fall_speed)`; old path keeps `juice.on_jump`, `hand.jump`, `juice.on_land`, `hand.land`. `_set_crouched`: `juice.on_crouch` only on the old path.
- `_update_footsteps`: strides from `LEGACY_STRIDE_*` when `legacy_feel`, else the exports (walk 2.0, sprint 2.4); the sprint sound choices use a `sprinting_gait` bool instead of `stride == stride_sprint`.
- `_update_view`: `juice.locomotion_from_body = not legacy_feel`; `juice.body_head = body_motion.head_offset(drawn_fraction)` on the new path, else identity.
- `CameraJuice.update`: when `locomotion_from_body`, the bob (`bob_x`, `bob_y`), `target_roll` and the sprint FOV are zero, and `body_head` is added last (`view_position += body_head.origin`, `view_rotation += body_head.basis.get_euler()`), before the death fall. It is already scaled; `intensity` does not scale it again.
- `Player.tscn`: a `Curve` sub-resource with `min_value = -1.0` and the default's four points, assigned to `footfall_curve`.

- [ ] **Step 4: Run the motion suite and the full regression; fix only checks that encode the old feel rather than a rule, and say which**

- [ ] **Step 5: Commit** — `feat(feel): the body carries the camera`

---

### Task 4: The hands ride the same body

**Files:**
- Modify: `scripts/Interaction/HandSlot.gd` (`_place_hands` :890-1006)
- Test: `tests/motion_test.gd`

**Interfaces:**
- Consumes: `player.body_motion.shoulder_offset(fraction)`, `player.body_motion.sprint_lean()`, `player.legacy_feel`.

- [ ] **Step 1: Write the check**

- Y12i: new path, standing with the sword in hand (`Props.give_weapons(player)`, `inventory.select_by_id(&"sword")`, 40 settled ticks): call `player.body_motion.on_land(13.9)` and record per frame `hand._main.position.y` and `body_motion.shoulder_offset(fraction).origin.y`; the hand's dip is ≥ 0.7× the shoulder offset's dip and their lowest frames are within 2 of each other; `hand._hop` stays 0. With `legacy_feel`, a real jump landing still moves `hand._hop`.

- [ ] **Step 2: Run; Y12i fails**

- [ ] **Step 3: On the new path, `_place_hands` uses `motion_position = look drag + shoulder.origin + Vector3(0, -0.035, 0.02) * carry` and `motion_rotation = look drag + shoulder.basis.get_euler() + Vector3(0.18, 0, 0.1) * carry` with `carry = sprint_lean()`, and the Lissajous `sway` is zero; the off hand keeps its 0.8 ratio. The old terms stay under `legacy_feel`.**

- [ ] **Step 4: Run the motion and life suites; pass, no SCRIPT ERROR**

- [ ] **Step 5: Commit** — `feat(feel): the hands ride the body`

---

### Task 5: The F10 comparison switch

**Files:**
- Modify: `scripts/PlayerController.gd` (`_unhandled_input` :479-521)
- Modify: `scripts/UI/StealthHUD.gd`
- Modify: `tests/sound_test.gd` (M12)
- Test: `tests/motion_test.gd`

**Interfaces:**
- Produces: `func set_legacy_feel(on: bool) -> void` on the player; `StealthHUD.show_caption(text: String, seconds: float) -> void`; `StealthHUD.legacy_tag_visible() -> bool`.

- [ ] **Step 1: Write Y18**

Feed an `InputEventKey` (F10, pressed) to `player._unhandled_input`: `legacy_feel` is true, the HUD caption reads "Movement: old" and the tag is visible; feed it again: false, "Movement: new", tag hidden. With the old feel, 2 s of walking takes steps consistent with a 1.6 m stride (distance / 1.6, ± 1).

- [ ] **Step 2: Run; Y18 fails**

- [ ] **Step 3: Implement**

F10 (debug builds only, not echo) calls `set_legacy_feel(not legacy_feel)`: sets it, `body_motion.reset()`, and `hud.show_caption("Movement: old" / "Movement: new", 1.6)`. The HUD's caption reuses `_caption`; the tag is a DIM 14 px label at the bottom right, "old movement · F10", visible while `player.legacy_feel`. M12 in the sound suite sets `player.legacy_feel = true` for its two walks and restores it.

- [ ] **Step 4: Run the motion and sound suites; pass**

- [ ] **Step 5: Commit** — `feat(feel): F10 switches between the old and new feel`

---

### Task 6: The picture of the motion

**Files:**
- Create: `tests/visual/stage_motion.gd`, `tests/visual/stage_motion.tscn`, `tools/plot_motion.py`

- [ ] **Step 1: Stager**

Headless-safe. Builds the motion suite's floor and 3 m platform, gives the sword, and runs the same script on each path (old first): stand 0.5 s, walk 1.5 s, sprint 1.5 s, release 1 s, walk + jump + hold 1.2 s, walk off the platform, crouch-walk 1.5 s, stand 0.8 s, lean right 0.8 s, release 0.5 s. Per tick it writes `t, phase, speed, view_x, view_y, view_z, pitch_deg, roll_deg, fov, hand_y, step` (step = 1 on a footstep) to `<out>/motion_old.csv` and `<out>/motion_new.csv` (`--out=` after `--`, default `user://motion/`).

- [ ] **Step 2: Plot**

`python3 tools/plot_motion.py <out>` draws `motion_compare.png` with PIL: stacked rows for speed, view height (cm), view forward (cm), view sideways (cm), pitch and roll (deg), hand height (cm); old in grey, new in amber; footsteps as ticks; phase names across the top.

- [ ] **Step 3: Run both and look at the PNG**

Run: `$GODOT --headless --fixed-fps 60 --quit-after 5000 --path . res://tests/visual/stage_motion.tscn -- --out=<scratch>/motion` then the plot. Expected: both CSVs, a PNG where the new traces are smaller and follow the footsteps.

- [ ] **Step 4: Commit** — `test(feel): old/new motion traces and plot`

---

### Task 7: Regression, review, merge

- [ ] **Step 1: Full regression** — every suite; expected: all pass except the known wardrobe K6/K6b; zero SCRIPT ERROR lines. Commit any new `.uid` files Godot generated.
- [ ] **Step 2: Whole-branch review** — one fresh reviewer on the most capable model against the spec; fix what it confirms; re-run the regression.
- [ ] **Step 3: Merge** — if `main` moved since `afab738`, merge it into the branch and re-run the regression; then, in the main checkout (which holds another session's uncommitted cloth work in unrelated files), `git merge --no-ff locomotion-feel`.
