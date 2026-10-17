# The Prosecutor's First-person Arms Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** First-person arms made for the view (shoulders to fingertips, an older man's weathered hands, blue trench sleeves, two engraved rings), at real proportions, rigged for the arm solver and painted Deadlock × Hellboy. They replace the arms borrowed from the guards' body.

**Architecture:**
- A Blender-built armature and mesh (`assets/characters/fp_arms/`) is loaded by a new `FPArms.gd` that offers the Humanoid API the solver uses: `skeleton`, `library()`, `bone_global()`, `show_action()`.
- `ViewArms.gd` builds the new rig for the arms and keeps the old body only for the kick leg.
- An F12 switch (and the `FP_ARMS=new` environment variable) chooses old or new until piece 6 retires the old arms.

**Tech Stack:** Blender 4.x (`/Applications/Blender.app/Contents/MacOS/Blender`, background runs; the live MCP session for sculpt/paint pieces with the user), Python bpy, glTF export, Godot 4.5 GDScript, headless suites.

**Spec:** `docs/superpowers/specs/2026-10-16-prosecutor-fp-arms-design.md`. The art recipe is section 4 of `docs/superpowers/specs/2026-10-16-metro-underground-design.md`.

## Global Constraints

- **Bone names, per side `_l` / `_r`:**
  - `clavicle`, `upperarm`, `lowerarm`, `hand`;
  - fingers `index|middle|ring|pinky|thumb` joints `_01|_02|_03`;
  - one root, `root`.
- **Proportions (m, full size):**
  - upper arm 0.34 and forearm 0.31, so shoulder to wrist is **0.65**;
  - hand wrist to middle fingertip about 0.19;
  - shoulders 0.38 apart.
- **Poses** (actions exported as animations): `Open`, `Fist`, `Hook`, `Wrap`, `Push`, `SwordGrip`. The blockout ships `Open`, `Fist` and `Hook`; piece 2 adds the rest.
- **The old arms stay the default until piece 6.** Every suite that passes on `free-run` today keeps passing with the switch off.
- **The live Blender session belongs to the user** (it has their unsaved `lamp_refined.blend`). Piece 1 uses background Blender runs only; the live session is used from piece 2 with the user's say-so.
- **Raw brush sheets** (`~/Downloads/Texture_Abstract0*.png`) never enter git.
- **Models are reviewed by the user one piece at a time.** No piece starts before the previous one is approved.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never stage the unrelated uncommitted files.

## Review Focus

- **Switching arms mid-climb (F12 while hanging):** no error, the hands re-grip at once, and nothing of the old body is left drawn. Test FA9.
- **The kick with the new arms on:** the boot and leg still swing, and no torso or arm of the old body shows. Test FA8.
- **The sword held with the new arms:** the blade sits in the right fist (old grip offsets are only approximate until piece 6, but never an empty hand or a floating sword). Test FA10.
- **The roll and hanging, looking down:** no open cut at the shoulders (shoulder caps). Checked in piece 1's stills.
- **Fist learning:** the solver's closed fist comes from the new rig's `Fist`. A missing clip must not leave the fingers open on a grip. Test FA4.

---

## Piece 1: Blockout

### Task 1: Blockout rig in Blender

**Files:**
- Create: `tools/arms/build_fp_arms.py` (bpy, run headless), `tools/arms/test_fp_arms_spec.py` (pure Python checks of the spec table the builder uses)
- Output: `assets/characters/fp_arms/source/fp_arms_blockout.blend`, `assets/characters/fp_arms/fp_arms.glb`

**Interfaces:** produces `fp_arms.glb`, containing:
- an armature named `FPArms` with the bones above, the rest pose arms forward at chest height, bent 15° at the elbow, fingers relaxed;
- a skinned mesh `FPArmsBody`;
- actions `Open`, `Fist` and `Hook`, one frame each.

The coordinate frame matches the old body: his space faces −Z, with the shoulders' middle at about (0, 1.45, 0) so `ViewArms.EYE` (0, 1.62, 0.1) still sits over them.

Blockout forms (big, simple, readable):
- **Coat sleeve:** a tapered tube, wider at the shoulder, with a turned cuff ending 4 cm above the wrist and a rounded shoulder cap closing the top.
- **Shirt cuff:** a ring of 2 cm showing past the sleeve.
- **Hand:** a palm block and three segments per finger and thumb, with a slight bevel.
- **Rings:** two plain bands on the left middle and ring fingers.
- **Weights:** rigid per segment, blended over 2–3 cm at the elbow, wrist and knuckles.
- Flat-colour materials (blue coat, off-white cuff, skin, dark silver) so it reads in renders.

- [ ] **Step 1:** Write `tools/arms/test_fp_arms_spec.py`. It asserts the builder's `SPEC` dictionary gives upper 0.34 + fore 0.31 = 0.65, shoulders 0.38 apart, all bone names present (3 joints × 5 fingers × 2 sides + 4 arm bones × 2 + root = 39), and poses `Open`, `Fist`, `Hook`.
- [ ] **Step 2:** Run `python3 tools/arms/test_fp_arms_spec.py`. Expected: FAIL, the module is missing.
- [ ] **Step 3:** Write `build_fp_arms.py`: `SPEC` at the top (pure data, importable without bpy) and `build()` under `if __name__ == "__main__"` or when bpy is present. Run it as `/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/arms/build_fp_arms.py -- <repo>`. It saves the .blend and exports the .glb (`export_animations=True`, `export_skins=True`).
- [ ] **Step 4:** Run the spec test (PASS) and the build (exits 0, both files written).
- [ ] **Step 5:** Commit `feat(arms): blockout rig for the first-person arms`.

### Task 2: FPArms wrapper and the switch

**Files:**
- Create: `scripts/Visual/FPArms.gd`, `tests/fp_arms_test.gd`, `tests/fp_arms_test.tscn`
- Modify: `scripts/Visual/ArmReach.gd` (`fist_from: Array` instance var replacing the use of the const `FIST_FROM`, defaulting to `FIST_FROM`), `scripts/Interaction/ViewArms.gd` (new rig behind the switch; old body kept for the leg only), `scripts/Interaction/HandSlot.gd` (F12 toggles)

**Interfaces:**
- **`FPArms.gd`** (`extends Node3D`):
  - `var skeleton: Skeleton3D`;
  - `func build() -> void` instances `res://assets/characters/fp_arms/fp_arms.glb`;
  - `func library() -> AnimationLibrary`;
  - `func bone_global(bone: StringName) -> Transform3D`;
  - `func show_action(animation: StringName, time: float, fade_in := 0.08, weight := 1.0) -> void` poses the rest/`Open`;
  - `func add_boots()` is a no-op.
- **`ViewArms`:**
  - `static var new_arms := OS.get_environment("FP_ARMS") == "new"`;
  - `func use_new_arms(on: bool) -> void` rebuilds the rig.
  - With the new arms on, `man` is the FPArms. `reach.arm_length = 0.0` and `reach.fist_from = [[&"Fist", 0.0], [&"Fist", 0.0]]`.
  - `_leg_body: Node3D` is the old Humanoid kept for `set_foot`. Its `folded` bones are `spine_01` and `thigh_l`, so nothing but the right leg and boot draws.
- **`HandSlot`:** F12 calls `_arms.use_new_arms(not ViewArms.new_arms)`.

- [ ] **Step 1:** Write `tests/fp_arms_test.gd` (structure as `tests/freerun_test.gd`; `FP_ARMS` is set via `OS.set_environment` before the player is instanced):
  - FA1: FPArms loads, `skeleton` is set, all 39 bones are found.
  - FA2: shoulder to wrist at rest is within 0.02 of 0.65 (`bone_global` of upperarm, lowerarm, hand).
  - FA3: `library()` has `Open`, `Fist` and `Hook`.
  - FA4: with the new arms the solver's learned fist is non-empty (`reach._fingers.size() >= 30`), and a hand held with curl 1 has `index_02` rotated more than 25° from `Open`.
  - FA5: hanging on a sill with the new arms, FR61's measure holds (each held wrist drawn on screen within 6% of where its grip puts it), and FR62's (true size, true depth, worst 0.03 m).
  - FA6: the new arms are not stretched (`reach.arm_length == 0.0`, `solved_lengths` within 0.02 of 0.65).
  - FA7: hanging, the chest is below the view (as FR62c).
  - FA8: a kick with the new arms on swings the old leg (`_leg_body` right foot moves more than 0.2 m), and the old body's spine and left thigh stay folded.
  - FA9: F12 pressed while hanging switches without error, and within 10 frames both hands are held at their grips again.
  - FA10: the sword selected with the new arms is drawn in the right hand (`hand_position(1)` within 0.12 m of the sword's grip frame).
- [ ] **Step 2:** Run `timeout 300 Godot --headless --fixed-fps 60 --path . res://tests/fp_arms_test.tscn --quit-after 60000`. Expected: FAIL (FPArms missing).
- [ ] **Step 3:** Implement `FPArms.gd`, `ArmReach.fist_from`, ViewArms' switch and leg body, and the HandSlot F12 toggle.
- [ ] **Step 4:** Run `fp_arms_test` (all PASS), then `tools/run_suites.sh` on the movement, free-run, combat and hand suites with the switch off (unchanged).
- [ ] **Step 5:** Commit `feat(arms): FPArms behind F12, old body kept for the kick leg`.

### Task 3: Piece 1 review material

- [ ] **Step 1:** In Blender (background), render front, three-quarter and top views of the blockout in its `Open`, `Fist` and `Hook` poses to `<scratchpad>/fp_arms/blockout_*.png`.
- [ ] **Step 2:** With `FP_ARMS=new`, run `tests/visual/stage_freerun_arms.tscn -- --every=1` and make the station 17 climb and roll clips (as before), plus a sword-held still from `tests/visual/stage_movement_gym.tscn`.
- [ ] **Step 3:** Look at every frame for faults (open shoulder ends, old body showing, hands off their grips, intersections) and fix them before showing.
- [ ] **Step 4:** Send the renders and clips to the user. **Stop for their review of piece 1.**

---

## Pieces 2–6: each planned in detail once the previous piece is approved

Each piece follows the same loop: build → tests → renders/clips → user review → next.

- **Piece 2, the hand** (live Blender session, with the user's say-so):
  - full topology for an older man's hand: knuckles, tendons, nails, palm creases;
  - finger weights that bend cleanly;
  - the full pose library (`Wrap`, `Push`, `SwordGrip`);
  - HandContacts reports the hold kind, and the solver blends to the pose for it.
  - Tests: each pose's finger angles; on a sill the hand is in `Hook`, on a pipe in `Wrap`, pulling up in `Push`.
- **Piece 3, the sleeve and cuff:**
  - the blue trench sleeve (heavy, an elbow crease that reads under bend, seams);
  - the white shirt cuff;
  - shoulder caps.
- **Piece 4, the rings:** two engraved bands with Claude's drafted hex and ward glyphs from the six schools, for the user to approve or replace.
- **Piece 5, the paint:**
  - the five texture layers on skin, coat, cuff and rings, using the user's brush sheets;
  - scars on both palms, hair on the backs of the hands and forearms;
  - high-detail sculpt baked to normal maps;
  - lit by the game's lights.
- **Piece 6, integration:**
  - the new arms become the default and the F12 switch and old arms retire;
  - held items (sword, bow, purse, keys, letter) retuned to the new hands;
  - `ArmReach.arm_length` removed;
  - every suite green;
  - clips of climbing, grabbing, combat and the roll.
