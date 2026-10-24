# The Prosecutor's First-person Arms, Piece 2: The Hand — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hands that read as grabbing. The full pose library (Open, Fist, Hook, Wrap, Push, SwordGrip) bends cleanly at every joint. Each hand takes the pose for what it holds: a hook on a sill, a wrap on a pipe, rung or rope, a flat push when pulling up, a sword grip on the blade.

**Architecture:**
- **The builder** (`tools/arms/build_fp_arms.py`):
  - gains three poses;
  - gains joint weights that keep a bent finger's volume;
  - gains a Blender-run check of how much each bend keeps.
- **`ArmReach`** learns every pose in its man's library, not just one fist. Each hand has a named target pose, cross-faded over `POSE_FADE`, and the curl blends from rest toward it.
- **`HandContacts.grip_pose(side)`** names the pose and how far into it for a held hand. **`HandSlot`** picks poses for held items.
- Both use a pose only when the arms have it (`ViewArms.has_pose`). The old arms keep today's fist and curls exactly.

**Tech Stack:** Blender 5.2 background runs (bpy), Python 3, Godot 4.5 GDScript, headless suites.

**Spec:** `docs/superpowers/specs/2026-10-16-prosecutor-fp-arms-design.md` (section "Settled after the builder review": the poses are used, not just made; piece 2 in "Pieces"). Piece 1 plan: `docs/superpowers/plans/2026-10-16-prosecutor-fp-arms.md`.

## Global Constraints

- **Poses** (exported actions): `Open`, `Fist`, `Hook`, `Wrap`, `Push`, `SwordGrip`.
- **Which pose for what (spec):**
  - ledge hook on an edge or sill;
  - wrap on a pipe, rung or rope;
  - flat push on a top while pulling up or mantling;
  - sword grip on a held weapon;
  - open while reaching;
  - fist otherwise.
- **The old arms stay the default until piece 6.** With them on, every hand keeps today's fist and today's curl values (`HandContacts.curl` is unchanged). Every suite that passes today keeps passing.
- **Bone conventions from piece 1 stay:**
  - arm and hand bones have the palm on local −X (right) and +X (left), test FA11;
  - finger bones are rolled to their nails;
  - a curl is negative about local X;
  - thumb twist and swing are mirrored for the left hand.
- **Background Blender only.** The live Blender session holds the user's unsaved `lamp_refined.blend`.
- **Fine skin detail goes to piece 5.** Creases, veins, scars and hair are sculpted and baked or painted then, not modelled now (spec: "the fine detail … is sculpted on a high-detail version and baked to a normal map").
- **Review:** the user reviews piece 2 from renders and in-game clips before piece 3 starts.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never stage the unrelated uncommitted files (`maps/zocalo.gd`, `scripts/Level/KitLoader.gd`, `scripts/Interaction/HandContacts.gd` as it stood before this plan, `tests/zocalo_test.gd`, untracked diag files).

## Review Focus

- **Switching pose mid-hold** (a hang that turns into a pull-up: Hook → Push): no pop. The fingers cross-fade over `POSE_FADE` (test FA14).
- **A pole, which `HandContacts.curl` forgets today** (State.POLE falls to 0.5): the new arms wrap it (FA15).
- **The old arms with the new code:** `has_pose` is false for Hook, Wrap, Push and SwordGrip, so their hands use the fist at today's curls (FA17, and freerun FR-suite unchanged).
- **F12 mid-pose:** the new rig's ArmReach starts with no pose memory. It must start at the asked pose, not fade in from nothing (FA9 re-run plus FA14's settle check).
- **The thumb in Wrap and SwordGrip** wraps round toward the fingers and never through them. The Blender check (Task 2) measures thumb-to-index clearance.

---

### Task 1: The pose library in the builder

**Files:**
- Modify: `tools/arms/build_fp_arms.py` (SPEC `poses`), `tools/arms/test_fp_arms_spec.py`
- Output: `assets/characters/fp_arms/fp_arms.glb`, `assets/characters/fp_arms/source/fp_arms_blockout.blend`

**Interfaces:**
- Produces: actions `Open`, `Fist`, `Hook`, `Wrap`, `Push`, `SwordGrip` in the glb.
- SPEC `poses[name] = (finger_curls, thumb)`, where `finger_curls` is three degrees and `thumb` is three (curl, twist, swing) triples.
- New SPEC entry `pose_fingers`: optional per-finger overrides, `{pose: {finger: (c1, c2, c3)}}`. SwordGrip's index sits a little looser along the grip.

Values (degrees), set from reference and tuned by the renders in Task 2:
- **Wrap** (a 4 cm pipe): fingers (55, 80, 50); thumb ((25, −35, 0), (25, 0, 0), (30, 0, 0)).
- **Push** (palm flat, fingers spread on a top): fingers (−8, 5, 5); thumb ((−10, 15, 0), (0, 0, 0), (5, 0, 0)).
- **SwordGrip:** fingers (80, 90, 60) with index (65, 75, 50); thumb ((30, −30, 0), (30, 0, 0), (35, 0, 0)).

- [ ] **Step 1:** Add to `test_fp_arms_spec.py`:
  - `test_full_pose_library`: all six names are in `SPEC["poses"]`.
  - `test_push_is_flat`: every finger curl ≤ 10.
  - `test_wrap_closes_less_than_fist`: Wrap's 01 and 02 are each below Fist's, and above 40.
  - `test_sword_grip_index_looser`: the SwordGrip index 02 is below middle 02.
- [ ] **Step 2:** Run `python3 tools/arms/test_fp_arms_spec.py`. Expected: FAIL (Wrap missing).
- [ ] **Step 3:** Add the poses and `pose_fingers` to SPEC. The pose loop reads per-finger overrides.
- [ ] **Step 4:** Spec test PASS. The build exits 0 and prints 39 bones.
- [ ] **Step 5:** Commit `feat(arms): the full hand pose library`.

### Task 2: Bends that keep their volume

**Files:**
- Create: `tools/arms/check_fp_arms_bends.py` (bpy, run headless on the built .blend; exits 1 on failure)
- Modify: `tools/arms/build_fp_arms.py` (`hand_weights` blend widths, `JOINT_BLEND` / `KNUCKLE_BLEND`, dorsal/palmar asymmetry), `tools/arms/test_fp_arms_spec.py` (keep the HandWeights tests green)

**Interfaces:**
- `check_fp_arms_bends.py -- <blend>` prints one line per check and `BENDS PASS` or `BENDS FAIL`.

How the check measures:
- **Keeps volume.** In each pose, for every finger joint (PIP, DIP, MCP) and both hands, take the evaluated (posed) mesh. Find the skin's nearest distance to the joint's centre on the back of the finger (verts of that finger with normals within 60° of the bone's local +Z). It must be at least 0.75 of the same distance at rest.
- **Thumb clearance.** In Wrap and SwordGrip, no thumb skin vertex lies inside the index finger's skin. The test: the nearest index vertex's normal points away from the thumb vertex.

Then:
- [ ] **Step 1:** Write the check script. Run it on today's build. Expected: report numbers; a FAIL is the finding to fix. Any joint already above 0.75 still gets its number in the ledger.
- [ ] **Step 2:** Tune the weights:
  - wider on the back of the joint, narrower on the palm side (a palmar crease folds sharp, the back stretches round);
  - `hand_weights` takes the vertex normal for this.
  Add `test_back_of_a_joint_blends_wider` to the spec test: at equal distance past a joint, a dorsal vertex's next-bone weight is lower than a palmar vertex's.
- [ ] **Step 3:** Rebuild, rerun the check until `BENDS PASS`. Render close-ups of each pose (top, palm, side; both hands) to the scratchpad and look at every joint.
- [ ] **Step 4:** Commit `feat(arms): finger bends that keep their volume`.

### Task 3: ArmReach learns and cross-fades every pose

**Files:**
- Modify: `scripts/Visual/ArmReach.gd`, `scripts/Interaction/ViewArms.gd`, `tests/fp_arms_test.gd`

**Interfaces:**
- **ArmReach:**
  - `var poses: Array[StringName] = [&"Fist", &"Fist"]`: the pose asked of each hand.
  - `var pose_weights: Array[Dictionary]`: per hand, pose → share of the shown pose. The shares sum to 1. A test reads them.
  - `const POSE_FADE := 0.12` (seconds to cross over).
  - `func has_pose(pose: StringName) -> bool`: the library has it.
  - Learns `_poses[pose][bone]` for every library animation in `[Open, Fist, Hook, Wrap, Push, SwordGrip]`.
  - The old `fist_from` still feeds `Fist` when the library has no `Fist` (the old arms).
  - `_curl` blends rest toward the share-weighted pose by the curl.
  - A hand with an empty `pose_weights` starts fully at its asked pose (no fade from nothing).
- **ViewArms:**
  - `func set_hand(side, target, weight, curl, pose := &"Fist")`;
  - `func has_pose(pose) -> bool`, which asks `reach`.

- [ ] **Step 1:** Add to `fp_arms_test.gd`:
  - FA12: `reach.has_pose` is true for all six with the new arms.
  - FA13: with `set_hand(0, …, 1.0, 1.0, &"Wrap")` held for 30 frames, `pose_weights[0][&"Wrap"]` > 0.99.
  - FA14: switching that hand to `&"Push"`, 2 frames later both shares are between 0.05 and 0.95, and after `POSE_FADE` + 10 frames Push > 0.99.
  - FA17: after F12 to the old arms, `has_pose(&"Hook")` is false and `has_pose(&"Fist")` is true.

  HandSlot sets the hands every frame, so FA13 and FA14 take the arms out of HandSlot's hands for the test: `player.hand.set_process(false)`, restored after.
- [ ] **Step 2:** Run `fp_arms_test`. Expected: FAIL (no `has_pose`).
- [ ] **Step 3:** Implement as the interfaces say. The fade rate is `get_process_delta_time() / POSE_FADE`. Shares move toward 1 for the asked pose and 0 for others, then normalise.
- [ ] **Step 4:** `fp_arms_test` all PASS. `freerun_test`, `traversal_test` and `combat_test` are unchanged (old arms).
- [ ] **Step 5:** Commit `feat(arms): the solver learns and cross-fades every hand pose`.

### Task 4: Hands take the pose for what they hold

**Files:**
- Modify: `scripts/Interaction/HandContacts.gd` (new function only), `scripts/Interaction/HandSlot.gd` (`_place_arms`), `tests/fp_arms_test.gd`

**Interfaces:**
- **`HandContacts.grip_pose(side: int) -> Array`** returns `[pose: StringName, amount: float]`:
  - HANG: `[&"Hook", lerpf(0.2, 1.0, smoothstep(0.6, 1.0, travel))]`;
  - LADDER, ROPE, POLE: `[&"Wrap", 1.0]`;
  - MANTLE, VAULT: `[&"Push", 1.0]`;
  - CARRY: `[&"Fist", 0.35]`;
  - otherwise `[&"Fist", 0.5]`.
- **HandSlot `_place_arms`:** each hand gets a pose alongside its curl, used only when `_arms.has_pose(pose)`, else Fist at today's curl.
  - the sword or another blade: `&"SwordGrip"`, 1.0;
  - the bow's stave hand: `&"Wrap"`, 1.0;
  - the brace: `&"Push"`, 1.0;
  - a world grip: `grip_pose` blended in by the grip weight. Above half grip weight the grip's pose is the asked pose; the curl lerps as today.
  - the roll tuck keeps Fist 0.45.

- [ ] **Step 1:** Add to `fp_arms_test.gd`:
  - FA15: hanging on a sill for 30 frames, both hands' `pose_weights` Hook > 0.95. On a pole (a `HANDHOLD.Kind.POLE`, grabbed as freerun's `_pole_checks` does), Wrap > 0.95.
  - FA16: pulling up from a sill (forward held until the move label is `pull up`), Push > 0.9 within 20 frames of the label. The sword drawn (as FA10): right-hand SwordGrip > 0.95.
  - FA18: with the old arms (after F12), hanging on a sill gives `reach.curls` equal to `contacts.curl(side)` within 0.01, as today.
- [ ] **Step 2:** Run. Expected: FAIL (no `grip_pose`).
- [ ] **Step 3:** Implement `grip_pose` and the HandSlot routing.
- [ ] **Step 4:** `fp_arms_test` PASS. Run `tools/run_suites.sh` on the free-run, traversal, ledge, movement gym, combat (all four), feel, motion, interaction, sturdy and life suites: all as before.
- [ ] **Step 5:** Commit `feat(arms): each hand takes the pose for what it holds`.

### Task 5: Piece 2 review material

- [ ] **Step 1:** Blender renders of all six poses, both hands, top, palm and side, as one sheet. Then close-ups of a PIP bend in Fist and of the thumb in Wrap.
- [ ] **Step 2:** With `FP_ARMS=new`, the station 17 clip (`tests/visual/stage_freerun_arms.tscn -- --every=1`; retry until more than 150 frames) and a sill-hang still at true depth. Also a pole and a ladder still from the movement gym (`tests/visual/stage_movement_gym.tscn`) and a sword-held still.
- [ ] **Step 3:** Look at every frame for faults (pops between poses, fingers through stone or each other, thumb through the index). Fix test-first before showing.
- [ ] **Step 4:** Send the renders and clips to the user. **Stop for their review of piece 2.**
