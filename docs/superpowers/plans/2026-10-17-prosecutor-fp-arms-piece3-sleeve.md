# The Prosecutor's First-person Arms, Piece 3: The Sleeve and Cuff — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The blue trench sleeve made for real. It is one heavy closed sleeve from shoulder to cuff, with:
- an elbow that bends without collapsing and folds in its crook;
- a seam down the back of the arm;
- a turned-back coat cuff with its lining;
- a white barrel shirt cuff with a button;
- coat shoulders that the sleeves run into.

It replaces the blockout's tubes, balls and egg.

**Architecture:**
- A new pure-Python module, `tools/arms/sleeve_form.py`, computes every vertex, face, material and bone weight for the sleeve, the cuffs and the yoke, from the joints `build_fp_arms.joints(sign)` gives. Pure Python means the shape and weights are unit-tested without Blender.
- `build_fp_arms.py` turns its output into the bmesh in place of `tube`, `ball`, `egg` and the old `sleeve`.
- A Blender-run check, `tools/arms/check_fp_arms_sleeves.py`, poses the arm and proves the shape:
  - closed surfaces;
  - elbow volume at 90° and 130°;
  - the wrist never through the shirt cuff;
  - the shirt cuff inside the coat cuff.

**Tech Stack:** Python 3 (pure geometry), Blender 5.2 background (bpy, bmesh), Godot 4.5 for in-game checks.

**Spec:** `docs/superpowers/specs/2026-10-16-prosecutor-fp-arms-design.md`. It asks for:
- a blue trench coat, heavy and worn, creasing at the elbow and ending a little above the wrist (Claude's call: a white shirt cuff shows at each wrist, heavy wool or gabardine);
- "the coat sleeves end in closed shoulder caps, a small yoke, so no open cut can show from any angle";
- piece 3: "The blue trench coat and the shirt cuff, with the elbow crease under bend."

Earlier plans: piece 1 `docs/superpowers/plans/2026-10-16-prosecutor-fp-arms.md`, piece 2 `docs/superpowers/plans/2026-10-17-prosecutor-fp-arms-piece2-hand.md`.

## Global Constraints

- **Kit rule** (memory, Oct 9 2026): solid closed meshes, no layered single-sided quads, no open edge that can show its back face. Godot culls back faces, so an open tube seen down its end shows a hole.
- **Budget:** the whole arms mesh stays within 20–30k triangles (it is 16.6k now).
- **Dimensions from piece 1:**
  - the coat ends `sleeve_short_of_wrist` 0.04 short of the wrist;
  - the shirt cuff shows `cuff_length` 0.025 past it;
  - the sleeve top blends onto the clavicle (shoulder slide, piece 1);
  - FA19 and FA20 stay green: the shoulders sit where the old body's did and stay out of view on a pull-up.
- **Bone conventions stand** (FA11 palm axis, finger rolls). Hand and finger weights are untouched.
- **Materials:**
  - `Coat`, `ShirtCuff` and `Skin` as now;
  - a new `Lining` (dark, worn red-brown, 0.18, 0.07, 0.06) inside the turned cuff;
  - a `Button` (horn, dark).
  - Flat colours only: painting is piece 5. Seams and folds are geometry.
- **Background Blender only.** The user's live session holds an unsaved file.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never stage the unrelated uncommitted files (`maps/zocalo.gd`, `scripts/Level/KitLoader.gd`, the `LEAD_AFTER`/`TRAIL_AFTER` hunk of `scripts/Interaction/HandContacts.gd`, `tests/zocalo_test.gd`, untracked diags).
- **Review:** the user reviews piece 3 from renders and clips before piece 4 starts.

## Review Focus

- **Looking down the cuff** (hands raised toward the eye in a climb): no see-through hole, no gap where the shirt cuff meets the wrist that shows the wrist stump's end. The stump's open top lies inside the coat sleeve.
- **Wrist bent hard** (a hook over a sill bends it ~40°): skin never pokes through the shirt cuff (check script).
- **Elbow at 130° on a pull-up:** the sleeve keeps its thickness and the folds don't cross through each other (check: elbow keep ≥ 0.8, inner fold rings ordered along the arm).
- **Shoulder slide 0.45 m** (a far reach): the stretched upper sleeve stays a closed tube, and the yoke's armhole still covers the sleeve's top ring at rest.
- **F12 between arms** after the rebuild: FA9 stays green.

---

### Task 1: One continuous sleeve, shoulder to cuff

**Files:**
- Create: `tools/arms/sleeve_form.py`
- Modify: `tools/arms/build_fp_arms.py` (the forms section: the upper sleeve, elbow ball, forearm tube and coat cuff band are replaced), `tools/arms/test_fp_arms_spec.py`

**Interfaces:**
- **`sleeve_form.sleeve(shoulder, elbow, wrist, side) -> Part`**, with points as 3-tuples (Blender axes) and side `"l"`/`"r"`.
- **`Part`** is a small class with:
  - `verts: list[tuple]`;
  - `faces: list[tuple[int, ...]]`;
  - `face_mats: list[str]`;
  - `weights: list[dict[str, float]]`, bone names with the side suffix.
- **The path** runs from the shoulder through the elbow to the coat's end (`wrist − fore_dir × sleeve_short_of_wrist`).
  - Rings about every 12 mm along it (`RING_STEP = 0.012`), each `SEGMENTS = 24` around.
  - Near the elbow the rings tilt to the bisector plane over ±3 cm, so they never cross.
- **The profile** (radius by distance along the arm, metres), interpolated smoothly:
  - shoulder 0.064;
  - mid upper arm 0.060;
  - elbow 0.056;
  - mid forearm 0.050;
  - coat end 0.047.
  - The cross-section is slightly oval: 1.08 × deeper than wide (cloth hangs).
- **The ends.** The shoulder end is closed by a cap, which the yoke hides. The coat end is open in Task 1; Task 3 closes it with the turned cuff.
- **Weights:**
  - the top ring onto the clavicle as now (smoothstep over the first 35%, from 5%);
  - the elbow: `upperarm` → `lowerarm` across the bisector plane, blended `ELBOW_BACK = 0.045` on the outer side (the point of the elbow, the arm's local back) and `ELBOW_CROOK = 0.015` on the inner side;
  - everything below on `lowerarm`.

- [ ] **Step 1:** Add to `test_fp_arms_spec.py` a `Sleeve` test case, built from `sleeve_form.sleeve(*joints(1)[...], "r")`:
  - `test_closed_except_the_cuff`: every edge is in two faces except the coat-end ring's (24 edges).
  - `test_profile_tapers`: the mean ring radius at the shoulder is above the elbow's, which is above the coat end's.
  - `test_weights_sum_to_one`.
  - `test_elbow_point_blends_wider_than_crook`: at 2 cm past the elbow plane, the back vertex's `lowerarm_r` weight is below the crook vertex's by more than 0.15.
  - `test_top_on_the_clavicle`: the top ring is ≥ 0.95 `clavicle_r`.
  - `test_triangle_budget`: both sleeves ≤ 6000 triangles.
- [ ] **Step 2:** Run `python3 tools/arms/test_fp_arms_spec.py`. Expected: FAIL (no `sleeve_form`).
- [ ] **Step 3:** Write `sleeve_form.py`. In the builder, add each part's verts, faces, materials and weights to the bmesh, replacing the upper sleeve, elbow ball, forearm tube and coat band.
- [ ] **Step 4:** Spec tests PASS. The build exits 0. `fp_arms_test` PASS (23).
- [ ] **Step 5:** Commit `feat(arms): one continuous trench sleeve, shoulder to cuff`.

### Task 2: The elbow bends, and folds in its crook

**Files:**
- Create: `tools/arms/check_fp_arms_sleeves.py` (bpy: poses, measures, `SLEEVES PASS`/`SLEEVES FAIL`, exit 1 on failure)
- Modify: `tools/arms/sleeve_form.py`, `tools/arms/test_fp_arms_spec.py`

**What the check measures:**
- **Elbow volume.** With `lowerarm_l` and `lowerarm_r` bent 90° and 130° about their local X (toward the chest), measure the coat's thickness through the elbow on the bisector plane. Back-to-crook distance must be ≥ 0.8 of rest, and side-to-side ≥ 0.85.
- **Fold order.** At 130°, the crook's fold rings stay in order along the arm: no ring's crook vertex passes its neighbour's.

**The folds** are static cloth, always there:
- The inner elbow gets 3 soft folds: a radial sine of amplitude 0.004 and wavelength 0.022, windowed ±4 cm about the elbow, on the crook side only (a cosine mask about the inner direction, zero past 90°).
- Above the coat end, two shallow bunching rings: amplitude 0.0025, all round.
- The back seam is a 1.2 mm groove, 6 mm wide, down the outer back of the arm (the back of the upper arm and the forearm's little-finger side).

Steps:
- [ ] **Step 1:** Spec tests:
  - `test_folds_only_in_the_crook`: the outer back verts within ±4 cm of the elbow sit on the plain profile within 0.0005; some crook verts sit off it by > 0.003.
  - `test_back_seam_is_a_groove`: the seam verts' radius is 0.001–0.0015 under their ring's mean.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Add folds and seam to `sleeve_form`. Write the check script. Build and run the check; tune `ELBOW_BACK`/`ELBOW_CROOK` until `SLEEVES PASS`.
- [ ] **Step 4:** Render the elbow at 0°, 90° and 130° (outside, crook side, and from the eye) and look at every fold.
- [ ] **Step 5:** Commit `feat(arms): an elbow that bends and creases`.

### Task 3: The coat cuff and the shirt cuff

**Files:**
- Modify: `tools/arms/sleeve_form.py` (`cuffs(elbow, wrist, side) -> Part`), `tools/arms/build_fp_arms.py` (`Lining`, `Button` materials; the old shirt-cuff tube removed), `tools/arms/check_fp_arms_sleeves.py`, `tools/arms/test_fp_arms_spec.py`

**Interfaces:**
- **The coat cuff, turned back:**
  - 5 cm long and 3 mm proud of the sleeve;
  - its edge rolls over (a 4 mm round lip) into a lining wall that runs 3 cm back inside at radius −4 mm, then closes to the sleeve's inside;
  - a closed annulus, so the coat end is now closed;
  - the lining faces take `Lining`.
- **The shirt cuff, a barrel cuff:**
  - outer radius 0.039, inner 0.033;
  - it starts 1 cm inside the coat and ends `cuff_length` past it;
  - rounded both edges, a closed annulus;
  - a horn button (r 5 mm, 2 mm thick) on the outside, the thumb side.
- All on `lowerarm`.

**What the check measures:**
- **Wrist clearance.** With the hand bent ±40° about its local X and Z (four poses), no skin vertex within the shirt cuff's span lies outside its outer wall.
- **Cuffs nest.** At rest, no shirt-cuff vertex lies outside the coat cuff where they overlap.
- **Closed.** Every coat, lining, shirt-cuff and button island has no boundary edges.

Steps:
- [ ] **Step 1:** Spec tests:
  - `test_cuffs_closed` (no boundary edges in either part);
  - `test_shirt_cuff_inside_coat`;
  - `test_cuff_shows_past_the_coat` (0.020–0.030 m past);
  - `test_lining_material_present`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. Rebuild. Run the check. If the wrist pokes out, widen the shirt cuff's inner radius or move the stump's wrist blend (`WRIST_BLEND`); the check decides.
- [ ] **Step 4:** Close-up renders: down the cuff from the hand's side, and the wrist bent both ways.
- [ ] **Step 5:** Commit `feat(arms): the turned coat cuff and the shirt cuff`.

### Task 4: The coat's shoulders

**Files:**
- Modify: `tools/arms/sleeve_form.py` (`yoke(shoulders) -> Part`), `tools/arms/build_fp_arms.py` (the egg and shoulder balls removed), `tools/arms/test_fp_arms_spec.py`, `tests/fp_arms_test.gd` (FA7, FA19, FA20 stay; nothing new unless one fails)

**Interfaces:**
- **The yoke** is lofted superellipse sections (exponent 3) from a collar ring at 1.50 down to 1.04, all on `root`:
  - width 0.40 at the chest, reaching ±0.24 at the shoulder line;
  - depth 0.22;
  - sloping 4 cm from collar to shoulder point.
- **Armholes:** the sleeve top caps sit inside the yoke. The test asserts every sleeve vertex within 4 cm of a shoulder point lies inside the yoke's superellipse.
- **The collar:** a 3 cm stand, closed on top (no hole looking down).

Steps:
- [ ] **Step 1:** Spec tests:
  - `test_yoke_hides_the_sleeve_tops`;
  - `test_yoke_closed`;
  - `test_yoke_below_the_eye` (its top below 1.55, under `ViewArms.EYE` 1.62).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement and rebuild. `fp_arms_test` PASS (FA7, FA19, FA20 included).
- [ ] **Step 4:** Commit `feat(arms): the coat's shoulders`.

### Task 5: Piece 3 review material

- [ ] **Step 1:** Blender renders of both arms (three-quarter, from the eye, from behind), the elbow at 0°/90°/130°, and both cuffs close up.
- [ ] **Step 2:** In game (`FP_ARMS=new`): `tests/visual/stage_fp_hands.tscn` stills and the pull-up clip; the station 17 clip (`--every=1`, retry until more than 150 frames).
- [ ] **Step 3:** Run `tools/run_suites.sh` on the free-run, traversal, ledge, gym, combat (four), feel, motion, interaction, sturdy, life and climb_swim suites, plus `fp_arms_test`. All as before.
- [ ] **Step 4:** Look at every frame. Fix faults test-first. Send to the user. **Stop for their review of piece 3.**
