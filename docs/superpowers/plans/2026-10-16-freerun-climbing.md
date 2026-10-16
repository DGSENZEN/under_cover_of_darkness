# Free-run Climbing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Holding sprint makes the first-person Prosecutor climb like AC 2 / Unity: auto vault/mantle, wall-run up to a hold, hand to hand up façades of placed handholds and detected ledges, leaps and back ejects, gap jumps only to validated landings, parkour down. The careful (walking/sneaking) layer stays as it is.

**Architecture:**
- A new `Handhold` node marks ledges, poles and points on geometry.
- A `HoldFinder` picks the next grip in a steered direction from both placed holds and the scanner's detected ledges.
- Free-run is a mode of `PlayerController`, active while sprint is held, not crouched and not carrying. It runs existing machinery without presses: `_try_traversal`, `planner.leap`, `_try_lower`, `_try_jump_assist`. It adds three moves: KIND_REACH (hand over hand), KIND_WALL_RUN, and pole climbing through a narrow ladder `ClimbVolume`.

**Tech Stack:** Godot 4.5 GDScript, headless suites (`tools/run_suites.sh`), the Python level pipeline (`tools/level/markers.py`).

**Spec:** `docs/superpowers/specs/2026-10-16-freerun-climbing-design.md`. The program it belongs to is `docs/superpowers/specs/2026-10-16-mexico-city-demo-program.md`.

## Global Constraints

- **Camera:** first person only. No third-person camera, no leap of faith, no climbing stamina meter.
- **Free-run input:** `Input.is_action_pressed("sprint")` (Shift) held, `not is_crouched`, `not _is_carrying()`. Parkour down is sprint + crouch held (Ctrl) at an edge or on a hold. On open ground sprint + crouch crouches as today; there is no slide.
- **Careful layer unchanged:** with sprint released every existing behaviour holds. `tests/traversal_test.tscn` (47), `tests/ledge_polish_test.tscn` (20), `tests/movement_gym_test.tscn` and the ledge sweep `tests/diag_ledge_sweep.tscn` keep passing.
- **Smooth walls are never climbed.** Free-run climbs only placed holds and ledges the scanner detects.
- **Falls:** free-run never moves you off a drop deeper than `freerun_max_auto_drop` unless a validated landing is the target. Fall damage stays `fall_damage_speed` / `fall_damage_per_speed`.
- **Noise:** every new move emits through `_make_noise` (`_start_move` already does this for `move.noise_db > 0`).
- **New move kinds:** `TraversalPlanner.KIND_REACH = 105`, `KIND_WALL_RUN = 106`. HandContacts and CameraJuice must map them; they hardcode kind ints.
- **Starting tunables** (exported on PlayerController and tuned with the user in the gym afterwards; tests read the vars, never literals):

| Variable | Value |
|---|---|
| `reach_up` | 1.0 |
| `reach_side` | 0.8 |
| `reach_down` | 1.0 |
| `hold_cone_degrees` | 50.0 |
| `wall_run_min_height` | 2.6 |
| `wall_run_max_height` | 3.8 |
| `wall_run_min_speed` | 4.0 |
| `freerun_max_auto_drop` | 3.0 |
| `roll_relief_speed` | 5.0 |
| `freerun_scan_interval` | 0.05 |
| `freerun_max_roll_degrees` | 4.0 |
| `reach_noise_db` | 35.0 |
| `wall_run_noise_db` | 52.0 |
- **Godot runs:** always `--headless --fixed-fps 60` with `--quit-after`, wrapped in `timeout`. A parse error makes a headless run hang.
- **Commits:** every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never stage files a task did not touch; the tree has unrelated uncommitted work.
- **Work on a branch `free-run`** cut from `eclipse-city` (worktree recommended).

Run one suite:
```bash
timeout 300 /Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . res://tests/freerun_test.tscn --quit-after 60000 2>&1 | grep -E "^(PASS|FAIL)|SCRIPT ERROR"
```

## Review Focus

- **Weapon drawn when you start climbing:** the sword vanishes from the hands while climbing and comes back on landing. No attack fires from a hold. Test FR27.
- **Sprint released mid-leap or mid-reach:** the move finishes and you stay on the hold you reached. Release never cancels into a fall. Test FR15.
- **Free-running at a roof edge with a guard chase behind you:** no valid landing means a stop at the lip, even at full speed. Test FR19 (speed 8.5).
- **A placed hold whose geometry was moved or is missing:** a hold inside solid geometry, or with no room for the hanging body, is never offered by HoldFinder (`fits()` checked). Test FR4.
- **Very low frame rates:** the free-run scan throttle must not miss a wall at a sprint. Test FR16 runs at 30 Hz physics as well as 60.

---

### Task 1: Handhold node and HoldFinder

**Files:**
- Create: `scripts/PlayerUtils/Handhold.gd`, `scripts/PlayerUtils/HoldFinder.gd`, `tests/freerun_test.gd`, `tests/freerun_test.tscn`
- Modify: `scripts/PlayerController.gd` (add `holds: HoldFinder`, set up next to `planner`; add the tunables from Global Constraints as `@export`)

**Interfaces:**
- Produces, in `Handhold.gd` (`extends Node3D`; loaded by `preload`, no class_name):
  - `enum Kind { LEDGE, POLE, POINT }`, `@export var kind := Kind.LEDGE`
  - `@export var length := 1.0`: LEDGE runs along local X, centred on the origin; POLE runs along local Y, upward from the origin; POINT ignores it.
  - `const GROUP := &"handholds"`, joined in `_ready`.
  - `func outward() -> Vector3` returns global +Z, flattened and normalized: the side the climber hangs on.
  - `func grip_near(world_point: Vector3) -> Vector3` returns the closest point on the hold.
  - `func ends() -> PackedVector3Array` returns the world end points (a single point for POINT).
- Produces, in `HoldFinder.gd` (`extends RefCounted`):
  - `func setup(p_scanner, p_planner, p_body: Node3D) -> void`
  - `func next_hold(anchor: Vector3, wall_normal: Vector3, lip_y: float, direction: Vector3, max_reach: float) -> Dictionary` returns a hang-target dictionary `{anchor, normal, lip_y, face_point, hold, reach}`, or `{}`.
    - `hold` is the Handhold, or `null` for a detected ledge.
    - `reach` is true when the target is within `reach_up` / `reach_side` / `reach_down` of the current grip.
    - The direction is a world vector in the wall plane.
  - `func hold_target(hold: Node3D, near: Vector3) -> Dictionary` returns the same shape for one hold, or `{}` if the hanging body does not fit.
  - `func holds_within(point: Vector3, radius: float) -> Array`
- Consumes: `planner.hang_anchor(face_point, normal, lip_y)`, `planner.probe_hang(point, normal, lip_y, max_lip_change)`, `scanner.fits(origin, false)`, and the controller's existing `_find_upper_lip` for detected ledges above. Expose it as `PlayerController.find_upper_lip(...)` if needed by HoldFinder, and keep the private name working.

Selection rules:
1. Score candidates within `hold_cone_degrees` of the direction, measured from the current grip to the candidate's grip point.
2. Prefer `reach` candidates over leaps.
3. Then prefer the smallest angle, then the nearest.
4. Detected ledges come from `planner.probe_hang` at points stepped along the direction and from `find_upper_lip` when the direction is mostly up.
5. A candidate must pass `scanner.fits(anchor, false)`.

- [ ] **Step 1: Write the failing tests** in `tests/freerun_test.gd`.
  - Structure and helpers: copy `tests/ledge_polish_test.gd` (`_box`, `_place`, `_hang`, `_release_all`, `_aim`, `_frames`, `_check`, RESULTS printing). Add a `_hold(kind, at: Vector3, yaw: float, length: float) -> Node3D` helper that instances Handhold. Add a labels collector as in `tests/traversal_test.gd` `_physics_process`.
  - The `.tscn` follows the four-line pattern of `tests/traversal_test.tscn` with node name `FreerunTest`.
  - Checks, each built on its own geometry with x spaced 10 m apart from 0:
    - `FR1 grip_near clamps to a ledge's ends`: a LEDGE of length 2 at the origin with yaw 0. `grip_near(Vector3(5,0,0))` is within 0.001 of `(1,0,0)`.
    - `FR2 next_hold picks the hold above within reach`: a wall with LEDGE holds at lip +0.9 and +2.0 above a hanging anchor. `next_hold(..., Vector3.UP, …)` returns the +0.9 hold, with `reach == true`.
    - `FR3 next_hold leaps when nothing is in reach`: the same wall with only the +2.0 hold. That hold is returned with `reach == false`.
    - `FR4 a hold buried in geometry is never offered`: a POINT inside a box returns `{}` from `hold_target`.
    - `FR5 a detected ledge counts as a hold`: no Handholds, a box lip 0.9 above returns non-empty with `hold == null`.
    - `FR6 the cone excludes holds off to the side`: a hold at 80° from UP is not returned for UP.
- [ ] **Step 2: Run, expect FAIL** (scripts missing). Use the run command above.
- [ ] **Step 3: Implement** `Handhold.gd` and `HoldFinder.gd` with the interfaces above. Add `holds` and the tunables to PlayerController.
- [ ] **Step 4: Run, expect FR1–FR6 PASS.**
- [ ] **Step 5: Commit** `feat(freerun): Handhold node and HoldFinder`.

---

### Task 2: Hanging on placed holds (careful layer)

**Files:**
- Modify: `scripts/PlayerController.gd` (`_update_locomotion` air grab, `_enter_hang`, `_update_hang`, `_lip_under_hands`, `_shimmy`)
- Test: `tests/freerun_test.gd`

**Interfaces:**
- Produces:
  - `var hang_hold: Node3D = null`: the Handhold being held, if any. It is cleared by `_drop_from_hang`, `_start_move` (unless the move ends on a hold) and `teleport`.
  - `_enter_hang` gains `hold: Node3D = null` as its last parameter.
  - `TraversalMove` gains `var end_hold: Node3D = null`, which `_finish_move` passes to `_enter_hang`.
- Consumes: `holds.hold_target`, `planner.leap(start, target, from_normal)`, which already accepts the target dictionary.

Behaviour:
- Holding jump in the air near a placed LEDGE or POINT within the existing grab reach catches it, as for a detected lip. Use the existing air-hold path: when `scanner.scan` finds nothing, try `holds.holds_within(feet + up*2, 1.2)` facing ≥ 0.3 toward the body.
- While `hang_hold != null`:
  - `_lip_under_hands()` is true.
  - Shimmy on a LEDGE moves along it, clamped to `ends()`. At an end it falls back to `planner.corner` or HoldFinder sideways.
  - A POINT does not shimmy.
- Pull-up works when the hold is a lip with room on top (existing `planner.pull_up`). A POINT has no pull-up; the user presses jump with a target, or drops.

- [ ] **Step 1: Write the failing tests:**
  - `FR7 a held jump catches a placed bracket`: a POINT 2.3 m above the feet on a smooth 6 m wall. Run in, jump and hold. Expect `movement_state == 2` and `hang_hold` is the hold.
  - `FR8 hanging on a placed hold does not drop for want of a lip ray`: a POINT with a 2 cm geometry nub. After 120 frames, still hanging.
  - `FR9 shimmy stops at a placed ledge's end`: a LEDGE of length 2 on a smooth wall. Hold `move_right` for 150 frames. x stays ≤ the hold end + 0.05, still hanging.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** the behaviour above.
- [ ] **Step 4: Run** freerun_test and `tests/ledge_polish_test.tscn` and `tests/traversal_test.tscn`. Expect all PASS.
- [ ] **Step 5: Commit** `feat(freerun): hang from placed ledges and brackets`.

---

### Task 3: Poles (drainpipes)

**Files:**
- Modify: `scripts/PlayerUtils/Handhold.gd` (POLE builds its climb volume), `scripts/PlayerController.gd` (`_try_enter_climb`, `_update_climb` side step-off), `scripts/Interaction/HandContacts.gd` (new `State.POLE`)
- Test: `tests/freerun_test.gd`

**Interfaces:**
- Produces:
  - A POLE Handhold adds, in `_ready`, a child Area3D with `ClimbVolume.gd`: `rope = false`, `open = false`, a BoxShape3D sized `(0.3, length, 0.5)`, centred `length/2` up and `0.25` out along +Z, so its climb normal is the hold's `outward()`.
  - `Handhold.climb_volume() -> Area3D`.
  - `var climb_hold: Node3D` on the controller while climbing a pole.
  - `HandContacts.State.POLE`: both hands on the pole line (`grip_near`), alternating as height changes, 0.35 m apart.
- Consumes: the existing CLIMBING machinery (`add_climb_volume`, `_try_enter_climb`, `_update_climb`, `_leave_climb`).

Behaviour:
- Climbing works as on a ladder.
- At the pole's top, the existing top scan mantles onto a roof if there is one.
- Holding strafe at a pole with a LEDGE hold or detected lip within `reach_side` that way starts a `planner.leap` to it (a step-off), ending in hang.

- [ ] **Step 1: Write the failing tests:**
  - `FR10 climb a drainpipe to its top`: a POLE of length 6 against a 6 m wall with a roof. Hold forward. Expect state 3, then the feet end ≥ 5.9 on the roof.
  - `FR11 step off a pipe onto a ledge beside it`: a LEDGE hold 0.6 m to the right at mid-height. Hold `move_right` while climbing. Expect state 2 with `hang_hold` that ledge.
  - `FR12 hands hold the pipe`: while climbing, both `HandSlot` hand positions are within 0.08 m of the pole line. Read them through the player's hand slot as `tests/sturdy_test.gd` or `tests/bodies_test.gd` do; find the accessor there.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS** (plus the ledge and traversal suites).
- [ ] **Step 5: Commit** `feat(freerun): drainpipe poles`.

---

### Task 4: Hand-over-hand climbing while free-running

**Files:**
- Modify: `scripts/PlayerUtils/TraversalPlanner.gd` (`KIND_REACH`, `reach(...)`), `scripts/PlayerController.gd` (`_update_hang` free-run branch, `free_running()`)
- Test: `tests/freerun_test.gd`

**Interfaces:**
- Produces:
  - `func free_running() -> bool` on the controller: sprint held, not crouched, not carrying.
  - `TraversalPlanner.KIND_REACH := 105`.
  - `func reach(start: Vector3, target: Dictionary, from_normal: Vector3) -> TraversalMove`:
    - A short move to `target.anchor`, `label = &"reach"`, `ends_in_hang`, with `end_hold = target.hold`.
    - Duration ≈ distance / 1.6 m/s, clamped to 0.25–0.55 s.
    - `noise_db = reach_noise_db`. Set the contact from the target (`_set_contact_from_target`).
    - Path cleared with `_best_clear_path`, otherwise null.
- Consumes: `holds.next_hold`, `planner.leap`, `planner.pull_up`.

Behaviour, in `_update_hang` when `free_running()` and the move input is held:
1. Direction = the wish vector mapped onto the wall plane. Forward is up, back is down, strafe is sideways (camera-relative).
2. Every `freerun_scan_interval`, `holds.next_hold(...)`. A `reach` target starts `planner.reach`, otherwise `planner.leap`.
3. Up held with no hold above and room on top: auto `pull_up`.
4. Sideways with no hold: the existing shimmy.
5. Sprint released: nothing new starts. A move in progress finishes into its hang.

- [ ] **Step 1: Write the failing tests:**
  - `FR13 holding sprint+forward climbs a column of sills to the roof`: a 9 m wall with LEDGE holds every 0.9 m and a roof. Start hanging on the lowest. Hold sprint+forward for at most 600 frames. Labels contain `reach`; the feet end on the roof (≥ 8.9); and at no frame is `movement_state == 0` while the feet are below 8.5 (never a fall).
  - `FR14 a 2 m gap above is leapt`: holds 2.0 apart. Labels contain `leap`.
  - `FR15 releasing sprint stops on the hold`: release sprint after the second reach starts. After 90 frames: state 2, and the lip equals the next hold's.
  - `FR13b diagonal`: hold sprint + forward + right with holds up-right at 45°. It reaches the up-right hold, not the straight-up one 60° away.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS** (plus the ledge and traversal suites).
- [ ] **Step 5: Commit** `feat(freerun): hand-over-hand climbing with sprint held`.

---

### Task 5: Free-run on the ground (auto vault, mantle, wall run up)

**Files:**
- Modify: `scripts/PlayerController.gd` (`_update_locomotion`), `scripts/PlayerUtils/TraversalPlanner.gd` (`KIND_WALL_RUN`, `wall_run(...)`)
- Test: `tests/freerun_test.gd`

**Interfaces:**
- Produces:
  - `TraversalPlanner.KIND_WALL_RUN := 106`.
  - `func wall_run(profile: ObstacleProfile, target: Dictionary, start: Vector3) -> TraversalMove`: a path that runs up the face (two or three points rising along it), ending in hang on the target, with `label = &"wall run"`. `noise_db = wall_run_noise_db`, `end_hold = target.hold`.
- Consumes: `scanner.scan`, `_try_traversal`, `holds.next_hold` / `holds.hold_target`.

Behaviour, in `_update_locomotion` when `free_running()`, there is forward intent and the player is grounded:
1. Scan every `freerun_scan_interval` with no jump press and call `_try_traversal(profile)`. Vault and mantle chain as today.
2. If no mantle matches, the approach speed is ≥ `wall_run_min_speed`, and a hold or detected lip sits between `wall_run_min_height` and `wall_run_max_height` above the feet on that face, start `wall_run`.
3. A smooth face with nothing in that band: run into it and stop (no climb).

- [ ] **Step 1: Write the failing tests:**
  - `FR16 sprinting at a fence vaults it with no press`: run at both 60 and 30 Hz. The second run sets `Engine.physics_ticks_per_second = 30` and restores it to 60. Expect label `vault` and position beyond the fence.
  - `FR17 sprinting at a 1.2 m wall mantles it with no press`.
  - `FR18 sprinting at a 3.4 m wall with a sill wall-runs up to it`: label `wall run`, state 2, lip 3.4.
  - `FR18b a smooth 3.4 m wall is not climbed`: no labels, state 0.
  - `FR18c walking (no sprint) at the fence does nothing without a press`: no labels.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS** (plus the traversal, ledge, movement_gym and stealth_polish suites).
- [ ] **Step 5: Commit** `feat(freerun): auto vault, mantle and wall run with sprint held`.

---

### Task 6: Gaps and edges

**Files:**
- Modify: `scripts/PlayerController.gd` (`_update_locomotion`, `_try_jump_assist`)
- Test: `tests/freerun_test.gd`

**Interfaces:** consumes `scanner.find_jump_target`, `_jump_airtime`, `scanner.edge_below`.

Behaviour, when `free_running()` and grounded:
- Within 0.6 m of an edge whose drop exceeds `freerun_max_auto_drop`:
  - If the jump assist finds a landing (`find_jump_target` + the airtime check), jump automatically with the assist.
  - Otherwise clamp horizontal velocity toward the edge to zero, so the player stops at the lip.
- Drops of `freerun_max_auto_drop` or less are run off normally.

- [ ] **Step 1: Write the failing tests:**
  - `FR19 a roof gap with a landing is jumped`: two roofs 6 m up, a 2.5 m gap. Sprint at it. Expect the feet on the far roof, no damage taken.
  - `FR19b a roof edge with no landing stops you at the lip`: one roof 6 m up. Sprint at 8.5 m/s for 120 frames. The feet stay ≥ 5.9 and within 0.7 m of the edge.
  - `FR19c a 1 m step down is simply run off`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(freerun): jump gaps to validated landings, stop at drops`.

---

### Task 7: Back eject

**Files:**
- Modify: `scripts/PlayerController.gd` (`_find_aimed_ledge` / `_find_looked_at_target` also consider placed holds)
- Test: `tests/freerun_test.gd`

Behaviour: hanging, looking behind at a hold or ledge across an alley within `planner.leap` reach, and pressing jump leaps to it, turning to face the new wall. This holds with or without sprint. Extend the aimed search to Handholds: the closest hold to the crosshair ray within 0.4 m, through `holds.hold_target`.

- [ ] **Step 1: Write the failing tests:**
  - `FR20 back eject to a ledge across an alley`: two walls facing each other 3 m apart. Hang on one, `_aim` at the other's lip, tap jump. Expect state 2, `hang_normal` reversed, label `leap`.
  - `FR21 back eject to a placed bracket`: the same, with the far wall smooth plus a POINT hold.
- [ ] **Step 2: Run.** FR20 may already pass; FR21 must FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(freerun): back eject to holds behind you`.

---

### Task 8: Parkour down

**Files:**
- Modify: `scripts/PlayerController.gd` (`_update_crouch`, `_update_hang`)
- Test: `tests/freerun_test.gd`

Behaviour, with sprint and crouch both held (check the raw `Input` actions; `_is_sprinting()` is false while crouched):
- **Grounded at an edge** (`scanner.edge_below`): `_try_lower` without a press, and without crouching the capsule first.
- **On open ground:** crouch as today.
- **Hanging:** `holds.next_hold(…, Vector3.DOWN, …)`. A reach or leap down goes there. With no hold below and the floor within `freerun_max_auto_drop` under the feet, let go (`_drop_from_hang`). With neither, stay.

- [ ] **Step 1: Write the failing tests:**
  - `FR22 sprint+crouch at a roof edge lowers into a hang`: state 2, no crouch.
  - `FR23 sprint+crouch on a façade climbs down hold to hold to the street`: start hanging at the top hold of FR13's wall. Feet reach < 0.2, never a damaging fall (`health` unchanged).
  - `FR24 sprint+crouch on open ground just crouches`: `is_crouched` is true.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(freerun): parkour down`.

---

### Task 9: Landing roll

**Files:**
- Modify: `scripts/PlayerController.gd` (landing, around the fall damage at `_update_locomotion`), `scripts/PlayerUtils/CameraJuice.gd` (`on_roll()`)
- Test: `tests/freerun_test.gd`

Behaviour:
- Landing while `free_running()` raises the damage threshold to `fall_damage_speed + roll_relief_speed`.
- If `fall_speed > roll_min_speed` (export, 9.0) it plays `juice.on_roll()`: a forward pitch tumble of about 0.5 s, within the camera roll cap. Landing noise is unchanged.

- [ ] **Step 1: Write the failing test** `FR25 a sprinting landing from 9 m hurts less than a walking one`. Drop twice from the same ledge with `invulnerable = false` and health restored between drops. Expect damage(sprint) < damage(walk), and damage(sprint) > 0 when `fall_speed > fall_damage_speed + roll_relief_speed`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(freerun): landing roll softens medium drops`.

---

### Task 10: Hands, camera and weapon while climbing

**Files:**
- Modify: `scripts/Interaction/HandContacts.gd` (`_state_now`: kind 105 maps to HANG on its contact, kind 106 has hands FREE until s 0.7 then HANG), `scripts/PlayerController.gd` (`_update_view` kind mapping: 105 to the leap code with a lower amplitude, 106 to mantle; free-run bob/roll), `scripts/PlayerUtils/CameraJuice.gd` (`freerun` intensity, roll cap `freerun_max_roll_degrees`), `scripts/Combat/PlayerCombat.gd` (stow)
- Test: `tests/freerun_test.gd`

**Interfaces:**
- Produces:
  - `PlayerCombat.set_stowed(stowed: bool) -> void`: hides the held weapon's viewmodel and refuses attacks, blocks and bow draws while true.
  - The controller calls it with `true` on entering MOVING (climb kinds), HANGING or CLIMBING, and with `false` back in LOCOMOTION. Find the weapon visual through `current_weapon()` / HandSlot.

- [ ] **Step 1: Write the failing tests:**
  - `FR26 hands plant on the reached hold`: at the end of a `reach`, both hands are within 0.1 m of the target lip.
  - `FR27 the sword is stowed on a hold and back on landing`:
    - Use the gym's sword-equipped setup: equip as `maps/traversal_gym.gd` does.
    - While hanging, the weapon is invisible and an attack input does not change `combat.phase`.
    - After pull-up and 30 frames, the weapon is visible.
  - `FR28 camera roll stays under the cap through FR13's climb`: track the max absolute camera roll; it stays ≤ `freerun_max_roll_degrees`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS** (plus the combat_test, combat_polish_test, feel_test and smooth_test suites).
- [ ] **Step 5: Commit** `feat(freerun): hands, camera and stowed weapon while climbing`.

---

### Task 11: Gym station 17 "FREE-RUN"

**Files:**
- Modify: `maps/traversal_gym.gd` (names array: add `"FREE-RUN"`), `maps/MovementGymFixtures.gd` (`build` case 16), `tests/movement_gym_test.gd` (the station count check), `maps/MOVEMENT_GYM.md` (table row)

A greybox façade, built with `gym._box` plus Handhold nodes added under `gym._fixture_root`, with station-local coordinates:
- A street with a 0.9 m fence and a 1.2 m cart.
- A 3.4 m wall with a sill (wall run).
- A 9 m façade with sills every 0.9 m, a 2 m gap, a bracket column and a drainpipe beside a ledge.
- A roof with a 2.5 m gap to a second roof.
- A dead-end roof edge with no landing.
- An alley 3 m wide to the opposite wall (back eject).
- A sign in the style of `gym._sign`: "FREE-RUN\nHold sprint: vault, wall run, climb, leap.\nSprint+crouch: climb down. Look behind + jump: back eject.\nThe dead-end roof stops you at its lip."

Gates: street start, top of the 9 m façade, far roof.

- [ ] **Step 1: Write the failing test** in `tests/movement_gym_test.gd`, `MG-FR station 17 free-run route`:
  1. Select station 16, teleport to the spawn.
  2. Hold sprint+forward with scripted steering (yaw toward each gate in turn).
  3. Expect to reach the far-roof gate within 1500 frames without `movement_state` falling to 0 above 3 m except on roofs, and no damage.
  
  Update the station count check to 17.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Build the station.**
- [ ] **Step 4: Run, expect PASS. Take three rendered stills** with `tests/visual/stage_movement_gym.tscn` (`-- --out=<scratchpad>`) and look at them for floating holds and z-fighting.
- [ ] **Step 5: Commit** `feat(gym): free-run station`.

---

### Task 12: Handhold markers in the level pipeline

**Files:**
- Modify: `tools/level/markers.py` (`SCHEMA["handhold"] = {"required": ["kind"], "optional": {"length": 1.0}, "box": False}`; `kind` is one of `"ledge"`, `"pole"`, `"point"`), `tools/level/layouts/lay.py` (`Layout.put(..., holds=True)` turns a piece's `k.PIECES[name]["holds"]` entries `[x, y, z, yaw, kind, length]` into `self.mark(f"{name}_hold_{i}", "handhold", where, yaw + h[3], kind=h[4], length=h[5])`, mirroring climbs at L42-44), `scripts/Level/LevelGameplay.gd` (`static func handholds(parent: Node, level) -> void` instances Handhold for each `level.of("handhold")`, called from `build_all`)
- Test: a Python test beside the existing tools tests (find the pattern: `tools/eclipse/test_*.py`, `tools/level`'s checks), plus `FR29` in `tests/freerun_test.gd`, which builds a minimal level dictionary through `LevelGameplay.handholds` and asserts one Handhold of each kind with the right length and transform.

Kit models are not touched here. The first real piece gets holds in the climbable-Zócalo project, reviewed with the user.

- [ ] **Step 1: Write the failing Python test** (a marker with kind "pole" validates; a bad kind fails) and `FR29`.
- [ ] **Step 2: Run, expect FAIL** (`python3 -m pytest <test> -q`; the Godot suite).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(level): handhold markers`.

---

### Task 13: Full regression and playtest gate

- [ ] **Step 1:** `TMPDIR=<scratchpad> bash tools/run_suites.sh`. Every suite that passed on `eclipse-city` before this branch still passes. Known failures from uncommitted work (`zocalo_test` parse error, `sway_test` KitLoader, `vfx_test` headless textures) are compared against a run on the base commit, not fixed here.
- [ ] **Step 2:** Ledge sweep on gym / zocalo `--radius=95` / harbour `--radius=75`, with careful-layer results equal to the Oct 16 run (only the station-12 moving blocker and the harbour cave pull-up refuse).
- [ ] **Step 3:** Update `~/.claude/projects/-Users-tinkertailorr-a-world-of-darkness-alpha/memory/traversal-system-status.md` with the free-run round.
- [ ] **Step 4:** Hand the gym to the user to playtest station 17. **No Zócalo façade work starts before their verdict on the feel.**
