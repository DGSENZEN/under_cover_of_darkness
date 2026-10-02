# System Polish and Movement Gym Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans. Tasks use independent ownership for combat and stealth; the main worker integrates movement and the gym.

**Goal:** Make movement, combat and stealth transitions predictable, and provide a repeatable movement stress course.

**Architecture:** Preserve the existing player, planner and guard systems. Extend the procedural traversal gym with separated stations, ordered checkpoint timing, safe resets and a small diagnostics HUD. Use existing collision, water, climbing and guard implementations.

**Tech Stack:** Godot 4.5.1, GDScript, existing scene test runner.

**Spec:** User requests in this conversation: ledge transitions/corners/complex leaps; polish combat/movement/stealth; build an advanced movement gym.

## Global Constraints

- Preserve existing city and project configuration edits.
- Keep established alert decay, movement limits, controls and combat legality.
- Restore global physics rate and time scale when leaving the gym.
- No commits or publication requested.

## Review Focus

- Reset during a targeted drop or rope climb must clear pending traversal work.
- Held inputs at reset must not create an unintended traversal or attack.
- Wrong checkpoint order must not finish a timed route.
- Dynamic obstacles must restart at a reproducible phase.
- Practice death and altered physics/time settings must not leak into subsequent scenes.

### Task 1: Combat transitions

**Files:** scripts/Combat/PlayerCombat.gd; tests/combat_polish_test.gd/.tscn.

- [x] Reproduce dodge presses lost during strike/early recovery, stale queued attacks and unavailable-state parries.
- [x] Implement a short dodge buffer, consumed only when legal; expire/clear unavailable actions.
- [x] Pass new regressions and existing combat, duel, blade and feel tests.

### Task 2: Stealth perception and search

**Files:** scripts/AISystem/Guard.gd; tests/stealth_polish_test.gd/.tscn.

- [x] Reproduce stale visible heading, silhouette threshold flicker, changed-target tracking and ignored fresh clues.
- [x] Stabilize already-acquired visibility and clear target-specific memory; resume investigation on fresh clues.
- [x] Pass regressions and stealth, hunt and squad tests.

### Task 3: Repeatable movement gym

**Files:** maps/traversal_gym.gd; maps/MovementGymRun.gd; maps/MovementGymFixtures.gd; scripts/PlayerController.gd; tests/movement_gym_test.gd/.tscn.

**Interfaces:** Gym select_station(index: int), reset_station(), checkpoint_reached(station: int, gate: int, body: Node3D). MovementGymRun tracks ordered gates, elapsed/splits/best and attempts.

- [x] Add failing real-player reset tests and course ordering/timing tests.
- [x] Clear residual drop/assist/cooldown state in PlayerController.teleport.
- [x] Separate eight existing lanes into station roots; add eight advanced fixtures for seams, corners, clearance, obstructions, slopes, water, vertical relay and mixed combat/stealth.
- [x] Add station navigation, reset, timed gates, state/speed/rejection readout, damage toggle, slow motion and physics-rate controls.
- [x] Verify reset, moving obstacle phase, checkpoints, global setting restoration and representative fixture traversal.
- [x] Visually inspect the playable course and document controls in maps/MOVEMENT_GYM.md.

### Task 4: Integration

- [x] Review diffs and new tests, including cross-system reset behavior.
- [x] Run focused suites and full tools/run_suites.sh outside the sandbox if settings tests require user:// access.
- [x] Report measured results and any existing unrelated failures without claiming subjective feel is fully validated by headless tests.

## Verification record

- Integrated movement/traversal/climb/smoothing/combat/stealth: 124 assertions passed.
- Full 44-scene run: 1203 passed, 1 failed; 43 scenes green. The showcase D7 Brand-berserk condition failed; the earlier traversal-only run failed D9 instead. Full setup rechecks subsequently passed all 43 showcase assertions with both current and unchanged Guard.gd; record this as an intermittent showcase result, not a confirmed unrelated defect.
- Follow-up physics-clock/TimeFx/cinema/combat/stealth verification: 180 assertions passed. Final gym suite: 19 assertions passed, including clock continuity and advancement in both directions.
- Rendered 16-station overview, nine first-person station views and optional guard relay; moved HUD away from instructions.
- Independent review reproduced and verified guard cleanup, held-forward ladder reset, hand revival, slow-motion ownership, impossible gate placement and combat resource reset.
- Existing city and project edits preserved; no commits.

- Showcase follow-up: seeds 7, 99 and 4242 all showed Brand berserk with both guard versions; standalone default 1926 also showed it. Final full showcase traces: current 43 pass / 0 fail, unchanged-guard control 43 pass / 0 fail. No showcase code or assertions were changed.
