# Locomotion feel (polish sub-project A): design

Date: 2026-09-26. Branch `locomotion-feel`, worktree `.claude/worktrees/locomotion-feel`.

## 1. Context

The user asked for "some UI polish, and some general movement and animation movement
polish", because things feel rough while playing. Their answers:

- **UI:** all of it. The HUD looks out of place over the retro screen, it is hard to read
  and cluttered, there are no real menus, and the gym and debug overlays are messy.
- **Movement:** all of it: speed and weight, camera motion, parkour moves, stances and
  transitions.
- **Hands:** "the way hands act with the parkour system is janky and rough", "same when
  grabbing things".
- **Speed and weight:** *same speed, more weight*: roughly today's pace, but with momentum,
  planted stops and heavier landings.
- **Camera:** the bob feels mechanical; there is too much motion; the camera floats (starts,
  stops, turns and stance changes barely move the head); jumps and landings don't sell.

The work is split into three sub-projects, done in this order:

| | Sub-project | Scope |
|---|---|---|
| **A** | Locomotion feel (this spec) | Speeds and momentum, jumps and landings, crouch, sprint and lean, the camera's body motion, the hands' bob and sway |
| B | Parkour and grabbing, move by move | Mantle, vault, hang/shimmy, ladder, rope, leap, drop, corner; pick up, carry, throw, shoulder. Per move: reliability, timing, camera path and hands together |
| C | UI | A HUD that belongs to the retro look and reads cleanly; main, pause and settings menus; gym and debug overlays |

A goes first because every parkour move and grab starts from and returns to locomotion.

The standard for all first-person motion is David Helsby's GDC 2015 talk (see the
`fp-animation-principles` memory): immediate feedback from input, preserve motion between
actions, no speed bumps, motion grounds you in the world, the head leads, and impact goes
into translation rather than rotation.

The unmerged HEMA animation branch is out of scope. Work as if it did not exist.

## 2. What is there today

- `PlayerController._apply_horizontal_movement`: on the ground, one `move_toward` at 45 m/s²
  (55 with no input). Walk 6.5 m/s is reached in 0.14 s; a walk stops dead in 0.12 s.
  Sprint 8.5, crouch 3.0. Air control 15 m/s². Jump 8.3 m/s with gravity 24 (1.35× falling):
  a 1.43 m jump that lands at 9.6 m/s.
- Footsteps: `gait` counts steps (`stride_walk` 1.6 m, `stride_sprint` 1.9, `stride_crouch`
  1.1), so a walk is four steps a second.
- `CameraJuice` draws the locomotion view from sines and springs: bob `sin(2φ)` at 3.5 cm
  amplitude (7 cm peak to peak) plus 2 cm of sideways sway, 1.8° of strafe roll, +6° FOV
  when sprinting, spring kicks for jump, landing and crouch. The same object also carries the
  combat camera, shake, the parkour move arcs, the death fall, the lean and the bow zoom.
- `HandSlot._place_hands` adds its own motion: a Lissajous idle wobble, a sine bob that
  reads `juice.bob_phase()`, a hop spring for jumps and landings, a fixed-rate running
  carry, and the drag behind mouse turns.

Head, hands and feet are separate layers with separate timing. That is a large part of
why the view feels floating and mechanical.

## 3. Goals and success criteria

1. Same top speeds, with weight: eased starts, planted stops, turns that carve at a sprint,
   and heavier landings, without adding input latency or ever taking control away.
2. One body under the view. Every locomotion motion of the camera and the hands has a
   physical cause (a foot, a change of speed, a landing, a change of stance), and there is
   less of it than today.
3. Comfort: locomotion rotates the view by at most 0.35°; impacts are carried by translation.
   Sprinting no longer widens the FOV.
4. Gameplay never reads any of it: aim, sight points, the frob ray and the lean ray stay as
   they are.
5. The user compares old and new by playing (F10) and signs off. Then the old paths are
   deleted.
6. The new motion suite passes, every existing suite stays green, and no run prints a
   `SCRIPT ERROR`.

## 4. Non-goals

- Parkour move timing, parkour camera arcs, and hands on ledges, rungs, ropes and held
  objects: all of that is sub-project B. `CameraJuice`'s move arcs and `grip_below` stay as
  they are.
- Menus, settings and HUD changes: sub-project C. The only HUD change here is a temporary
  caption for the F10 switch.
- Top speeds, jump height and timing, air control, coyote time and the jump buffer.
- A stumble or slowdown on landing (Helsby: no speed bumps). It can be added later.
- Visible legs or a full first-person body; NPC locomotion.

## 5. Design

### 5.1 Structure

A new `scripts/PlayerUtils/BodyMotion.gd` (a RefCounted like `CameraJuice` and `BodyPose`,
owned by the player as `player.body_motion`) is the body under the camera:

- **Hips** on a leg spring. Footfalls, landings and crouching push them down; a jump's
  push-off and standing up push them up; they shift sideways over the planted foot.
- **Torso** balanced on the hips. It leans with the body's real horizontal acceleration:
  back as you set off, forward over your feet as you stop, into a sprint, and into turns.
- **Head** on top, steadied like a real neck and eyes: it takes the torso's position but
  keeps only a small share (about 20%) of its rotation.
- **Shoulders** on the torso, not steadied. The hands hang from them, so they move more
  than the view.

Data flow:

- Each physics tick, after the state update (and so after `move_and_slide` in locomotion),
  the controller calls `body_motion.step(...)` with the real velocity, the facing, whether
  it is grounded, whether it is in plain locomotion, the stance, sprinting, the gait (the
  same step count that times the footstep sounds) and the lean.
- Events arrive as they happen: `on_jump()`, `on_land(fall_speed)`, `on_crouch(down)`.
- The simulation runs on the fixed tick, so it is deterministic and a long frame cannot
  throw it. Its outputs are kept for the last two ticks and drawn between them, the way the
  body and the combat hand poses already are.
- Outputs, both scaled by `camera_feel` (0 means exactly nothing):
  - `head_offset(fraction)`: an eye-space transform that `CameraJuice` adds to the view;
  - `shoulder_offset(fraction)`: a camera-space transform, relative to the head, that
    `HandSlot` applies to both hands.

What moves out of `CameraJuice` in the new path: the walk bob, the strafe roll, the sprint
FOV, and the jump, landing and crouch kicks. What stays: the combat camera (wind-ups,
swings, hits, kicks, impacts, shake), the parkour move arcs and `grip_below` (B), the death
fall, the lean offset and roll, and the bow zoom.

While not in plain locomotion (a parkour move, a hang, a climb, dead), the body stops
taking steps and acceleration, and its springs settle. The first tick back in locomotion
feeds no acceleration, so a move's end velocity or a teleport cannot jolt the head.

### 5.2 What the body does

Less motion, and every bit of it has a cause. The numbers are starting points, to be
tuned by feel with F10.

| Situation | New | Today |
|---|---|---|
| Walk footfalls | From one authored footfall curve: a quick drop as the foot lands, a slower rise through the stride. About 1.2 cm up and down, 0.6 cm side to side over the planted foot, under 0.3° of roll | 7 cm sine up and down, 4 cm side to side, 1.8° strafe roll, four times a second |
| Cadence | Longer strides: walk 2.0 m, sprint 2.4 m (about 3.3 and 3.5 steps a second). Footstep sounds and what guards hear follow the same steps, so a walk makes about 20% fewer footstep noises | 1.6 m and 1.9 m (about 4 and 4.5 a second) |
| Sprint | Longer, harder footfalls (about 2 cm); the body leans into the run, the head about 3 cm forward and 2 cm lower, with no pitch; no FOV change (2° only if sprinting then feels slow) | Bigger sine, +6° FOV |
| Crouch walk | Softer footfalls (about 0.6 cm), more side-to-side weight shift (about 0.8 cm): a sneak | Smaller sine |
| Starting | The head lags about 1 cm as you set off, then comes with you | Nothing |
| Stopping | The head carries 2 to 3 cm forward over your planted feet with under 1° of nod and settles back in about 0.3 s | Nothing |
| Turning at speed | A slight lean into the turn: under 0.6° of roll, mostly a sideways shift | Strafe roll only |
| Jump | The push-off is on the tick of the press: the legs extend and the view rises about 2 cm faster than the body | A spring kick |
| Landing | The legs absorb it: a quick compression (about 0.08 s) and a slower recovery, both growing with the fall. About 3 cm for a normal jump, 6 cm for a 3 m drop, capped at 12 cm; a small nod on hard landings | A spring dip |
| Crouch and stand | The gameplay eye height eases as it does now; the body adds the knee bend: going down settles a little past, standing pushes a little above | A spring kick |
| Lean | How far and how fast stay gameplay; the body adds the bend: a small dip at full lean and a settle at the end | Nothing |
| Standing still | Breathing: about 2 mm in the view, more in the hands, faster and deeper for a few seconds after a sprint | A Lissajous wobble in the hands |

The footfall curve is a `Curve` exported on the player (`footfall_curve`) and saved in
`Player.tscn`, so it can be tweaked in the inspector. Its x runs over one step (0 = the foot
lands, 1 = the next foot lands) and its y is the hips' height in units of the gait's
amplitude. At x = 0 it is already falling, it bottoms out early in the step (well within
0.1 s of the footstep sound) and it rises through the rest of the stride. The sideways
weight shift runs over a whole stride (two steps), toward each planted foot. Amplitudes
blend from crouch to walk to sprint with the gait and ramp in with speed, so starting to
walk grows into the bob rather than switching it on.

### 5.3 Momentum in the controller

Only the ground branch of `_apply_horizontal_movement` changes. The velocity is split into
the part along the wanted direction and the part across it:

- **Starting:** the push along the wanted direction is proportional to the gap to the
  target speed (a time constant of about 0.12 s, capped at about 60 m/s²), so it is hardest
  from a standstill and eases off near the top. Over half the walking speed within 0.1 s,
  full speed by about 0.35 s.
- **Sprint build:** above walking speed the gap closes more slowly (about 0.2 s), so a
  sprint gathers over about 0.5 s instead of switching on.
- **Slowing down while still moving** (sprint released, a guard raised): the extra speed
  eases off over about 0.15 s.
- **Stopping** (no input): planted, at a deceleration that gives about 0.15 s from a walk
  and 0.25 s from a sprint. The weight is felt through the head carrying forward (5.2), not
  through sliding, so stopping at a ledge or the edge of a light stays precise.
- **Turning:** the part of the velocity across the wanted direction is removed at a
  sideways acceleration that is high at walking pace (about 45 m/s², as today) and capped
  lower at a sprint (about 28 m/s²), so hard turns at a sprint carve a slight arc. A reversal
  is a stop followed by a start, about 0.35 s from a walk. No ice.
- **Landings do not slow you.**

Unchanged: top speeds, jump height and timing, air control, coyote time and the jump
buffer, stairs (they read the same wish velocity and recent ground speed), every parkour
move, shoves, dodges and kicks (they set velocity directly), combat's speed scales and the
shoulder-carry scale, and the death stop.

New exports go in the Locomotion category (start, sprint-build and stop times, turn
accelerations at a walk and a sprint, the acceleration cap). The old `ground_acceleration`
and `ground_deceleration` stay for the old path and the death stop.

### 5.4 The hands ride the same body

`HandSlot` already lives under the camera, so the hands inherit everything the head does.
What it adds on top becomes the shoulders' motion relative to the head. It replaces the
sine bob, the jump and landing hop, the fixed-rate running carry and the Lissajous wobble.

- **Footfalls** reach the hands a beat after the head, because the arms are lower in the
  chain, have their own inertia and are not steadied: at a walk the hands dip a little
  more than the view and roll slightly toward the planted foot.
- **Landings:** the hands drop further than the view and come back a little later.
- **Starts and stops:** the hands lag as you set off and swing forward a touch as you stop,
  then settle.
- **Sprint:** the running carry (arms lower, the weapon tipped) builds with the body's lean
  into the run (`sprint_lean()`), not at a fixed rate.
- **Breathing:** a slow rise and fall of a few millimetres, faster and deeper for a few
  seconds after a sprint.
- **Off hand:** it rides the same shoulders at 80% of the main hand, as today.

Unchanged: the drag behind mouse turns (the life suite pins it), recoil, the shudder,
combat poses and swings, the bow, the off hand's purse and key jobs, and every grip on
the world.

### 5.5 The comparison switch (temporary)

- `PlayerController.legacy_feel` (exported, Debug category, default false).
- F10 toggles it in debug builds (editor runs), in every map. F10 is unbound today.
- True brings back the old paths together: `CameraJuice`'s bob, strafe roll, sprint FOV and
  kicks, `HandSlot`'s old motion, the old `move_toward`, and the old strides (1.6 and 1.9 m).
- The HUD shows a caption on each switch ("Movement: new" / "Movement: old") and a small
  corner tag while the old feel is on.
- After the user's sign-off, the switch, the old paths, the caption and the tag are deleted.

## 6. Interfaces

`scripts/PlayerUtils/BodyMotion.gd`:

```
var intensity := 1.0
func setup(footfall_curve: Curve) -> void
func step(delta, velocity: Vector3, facing: Basis, grounded: bool, locomotion: bool,
          crouched: bool, sprinting: bool, gait: float, lean: float) -> void
func on_jump() -> void
func on_land(fall_speed: float) -> void
func on_crouch(down: bool) -> void
func reset() -> void
func head_offset(fraction: float) -> Transform3D      # eye space, drawn between ticks
func shoulder_offset(fraction: float) -> Transform3D  # camera space, relative to the head
func sprint_lean() -> float                           # 0..1
```

`PlayerController`: `body_motion`, `legacy_feel`, `footfall_curve`, the new Locomotion
exports; `step` after the state update in `_physics_process`; events from
`_try_buffered_jump`, the landing block and `_set_crouched` (the old `juice.on_*` and
`hand.land/jump` calls stay only on the old path); `_update_view` hands the head offset to
`CameraJuice` each frame; F10 in `_unhandled_input`.

`CameraJuice`: `locomotion_from_body` (default false, so standalone uses such as the sturdy
suite keep today's behaviour) and `body_head`. When `locomotion_from_body` is true, the bob,
strafe roll and sprint FOV are skipped and `body_head` is added, scaled by `intensity`.

`HandSlot`: on the new path, `_place_hands` uses `player.body_motion.shoulder_offset()` and
`sprint_lean()` in place of the old bob, hop, run and wobble terms.

`StealthHUD`: `show_caption(text, seconds)` and the legacy tag (both temporary).

## 7. Testing and verification

A new headless suite, `tests/motion_test.tscn`, checks prefixed Y. Every check is written
to fail before the code that satisfies it:

| Check | What it pins |
|---|---|
| Y1 | At `camera_feel` 0 the head and shoulder offsets are exactly identity |
| Y2 | At every footstep sound (walk, sprint, crouch) the head is already descending and bottoms out within 0.1 s |
| Y3 | Walk budget: 0.8 to 1.8 cm up and down, at most 1 cm side to side, locomotion rotation at most 0.35° |
| Y4 | Sprint: head at least 2 cm forward and lower, rotation at most 0.35°, FOV unchanged by sprinting |
| Y5 | Crouch walk: softer vertically than a walk, with the side-to-side shift at least as large as the vertical |
| Y6 | Standing still: within 0.6 s of stopping, only breathing moves the head (at most 3 mm) |
| Y7 | Starts: over 50% of walk speed within 0.1 s, 95% by 0.4 s; the sprint build from a walk takes 0.35 to 0.7 s |
| Y8 | Stops: at most 0.2 s and 0.6 m from a walk, 0.3 s and 1.3 m from a sprint |
| Y9 | Turns: a reversal from a walk reaches 90% speed the other way within 0.45 s; a hard turn at a sprint carves, within the cap |
| Y10 | Jump: off the ground on the press tick; apex 1.43 m ± 0.02 |
| Y11 | Landing: deeper for a 3 m drop than a jump, never over 12 cm, recovered within 0.5 s; ground speed unchanged by touching down |
| Y12 | Hands: the shoulders bottom out after the head on a footfall; on a landing the hands drop further than the view |
| Y13 | A 250 ms step does not throw the body past its caps |
| Y14 | At two frames per tick the head offset is drawn evenly between ticks |
| Y15 | Crouch and stand: a dip past the crouched height and a rise past standing, both settled within 0.4 s |
| Y16 | Lean: a small dip at full lean that settles; the gameplay lean is unchanged |
| Y17 | Gameplay untouched: aim transform, sight points and the frob eye match between old and new at the same body state |
| Y18 | F10: switching both ways works without errors, and the old path still gives the old results |

Existing suites stay green. The sound suite's "bob lowest on each footstep" check runs with
`legacy_feel` on until the old path is deleted; Y2 covers the new path. The traversal stair
check measures the gameplay eye, which the body never touches, and the smooth suite turns
`camera_feel` off, which Y1 guarantees.

A visual stager, `tests/visual/stage_motion.tscn`, runs a scripted sequence (walk, sprint,
stop, jump, land, crouch walk, stand, lean) on the old and new paths, records the head's
and shoulders' offsets per tick with the footfalls marked, and saves a plot as a PNG. The
real verdict is the user's: play any gym and press F10.

## 8. Workflow

- Worktree `.claude/worktrees/locomotion-feel`, branch `locomotion-feel`, from local
  `main` at `afab738`. The main checkout, which other sessions use, is touched only by the
  final merge.
- One commit per task on the branch, never pushed.
- Every task ends with its suite and the full regression, grepping for `SCRIPT ERROR` even
  when every check passes.
- Baseline at `afab738`: 399 checks pass; wardrobe K6 and K6b (cloth on a limp or
  knocked-down watchman) already fail. They belong to the NPC-look work in progress and are
  left alone.
- The user asked (2026-09-26) for the implementation to be merged into `main` once it is
  done and green. The F10 switch ships with it, so the comparison happens in `main`.
- After the user plays and signs off (with any tuning rounds in between), a later change
  deletes the old paths and the switch, and moves the sound suite's check to the new path.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Springs wobble or cause nausea | Damping ratios near critical, rotation caps, `camera_feel` as a master dial (C will expose it in settings) |
| A wall bump or teleport jolts the head | Acceleration input capped; the first tick back in locomotion feeds none; offsets capped |
| Stairs lose speed with the new start curve (T22s allows 2 slow frames) | Stairs still hand back the recent ground speed; the full regression runs after the momentum task |
| Checks that assume today's strides or ramp-up (stealth, sound, traversal) | Found by the full regression; fixed where the check encodes the old feel rather than a rule |
| The drawn view steps at high refresh rates | Outputs interpolated between the last two ticks (Y14) |
