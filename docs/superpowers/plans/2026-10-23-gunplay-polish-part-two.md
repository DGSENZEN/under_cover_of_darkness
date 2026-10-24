# Gunplay Polish, Part Two Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the spells' effects in the shot's approved look (Obsidian circle and shard, Blink, the Ward in mesh smoke, Empower), and the gore stand-in pass. Then clips, every suite, and the whole-branch review.

**Architecture:**
- A new static `scripts/Visual/MagicFx.gd` holds the world effects (mirror shards, ripple, shatter, shockwave), as `GunFx` does for the gun.
- A small `scripts/Visual/MagicView.gd` (CanvasLayer) gives the edge-of-view colour: Blink's cold flash, Empower's pulse.
- The circles stay in `HandSlot` (viewmodel); the Ward's ring stays in `Ward.gd`; the tome flutter and the pelt-shadow hang off `HandSlot`.

**Tech Stack:** Godot 4.5.1, GDScript, MeshVfx + `vfx_mesh` / `vfx_smoke` / `vfx_gunflash` shaders.

**Spec:** `docs/superpowers/specs/2026-10-23-gunplay-and-magic-polish-design.md`, "Effects, piece by piece" (the part after the checkpoint).

**The user's verdict at the checkpoint:** "The shot's look works. Build part two in this look, and use mesh smoke for the Ward."

## Global Constraints

- **Look:** the shot's approved language.
  - Meshes (MeshVfx) with scrolled noise and hard-edged erosion.
  - Flat bands close together; a band contrast as wide as the first smoke draft's reads as camouflage.
  - Fresnel rims.
  - Glows only where the stuff glows (the flash). Smoke is lit (`vfx_smoke`), except the Ward's, which is ghostly (`vfx_mesh`, unshaded, low energy).
- **Colour:**
  - Ward `#CFE8F0` (core `#F2FAFC`, edge `#7FA6B4`).
  - Obsidian: black glass `#0A0A0D`, its glints cold `#E6EEF5`.
  - Empower: umber body `#4A3423`, bone core `#D8C7A3`, edge `#22170F`.
  - Not marigold, not oxblood.
- **Viewmodel pieces** (circles, flutter, pelt) are drawn at the arms' field of view:
  - shader materials set `fov_override` = `ViewArms.VIEW_FOV` when `new_arms`, and `z_clip` = `ViewArms.Z_CLIP`;
  - `StandardMaterial3D`s go through `ViewArms.dress()`.
- **Standing rules:** effects made in house; every effect is made of its stuff; never call a visual defect harmless; models one at a time with the user, so gore pieces stay code-built stand-ins behind a replaceable list.
- **Tests:** headless and frame-exact. Each effect spawns, lives its time and is cleaned up; counts are bounded. Looks are judged in windowed clips.
- **Where:** worktree `.claude/worktrees/revolver-magic`; run suites with `.superpowers/run.sh <scenes>`.

## Review Focus

1. **Casting cancelled half way** (key let go, gun put away, a hard hit): the circle, flutter and pelt go at once, with no release effect. Pinned by M3 (Task 1) and E5 (Task 5).
2. **Many blinks in a row** (10 taps): mirror shards and ripples stay bounded and clear. Pinned by B4 (Task 3).
3. **A ward stopping many shots at once** (a volley of 8 arrows): the bulges stay bounded and clear when the ward ends. Pinned by W4 (Task 4).
4. **Empower spent by a jump or a blink, not a blow:** the pelt and pulse go, and the shockwave is at the feet or the arrival. Pinned by E4 (Task 5).
5. **Effects when `Fx.enabled` is false** (tests, captures): no crash; the world effects are skipped. Pinned by M4 (Task 1).

---

### Task 1: Circles in the approved look, and the magic effects base

**Files:**
- Create: `scripts/Visual/MagicFx.gd` (static: `live_count()`, `_keep(node, seconds)`; skipped when `Fx.enabled` is false)
- Modify: `scripts/Interaction/HandSlot.gd` (`CIRCLE_LOOKS`, `_update_circle`)
- Tests: `tests/caster_test.gd` M1–M4

**Interfaces:**
- **Produces, in `HandSlot`:** `CIRCLE_LOOKS[school] = [Mesh, Material]`.
  - **obsidian:** a thin pointed glass splinter, a bipyramid 6 × 34 × 3 mm, from `MagicFx.splinter_mesh(width, length, depth)`. Its material is a `StandardMaterial3D`: albedo `#0A0A0D`, metallic 0.85, roughness 0.08, rim 0.6 tinted `#E6EEF5`, dressed.
  - **copal:** a short rising tendril (`MeshVfx.tendril`), with the `vfx_gunflash` shader (it has the field of view) in the ward colours at energy 1.1, opacity 0.8.
- **Produces, in `MagicFx`:** `static func splinter_mesh(width: float, length: float, depth: float) -> ArrayMesh`, its long axis on +Y.
- **Shown:** the circle is up only while a hand cast runs; a cancel clears it the same frame.

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **M1.** Holding `spell_1`: `player.hand._circle` has 12 visible pieces whose mesh is not a `BoxMesh`, and whose material has metallic ≥ 0.8.
  - **M2.** Holding `spell_2`: its pieces' mesh is not a `SphereMesh`, and its material's `core` parameter is `#F2FAFC`.
  - **M3.** `spell_1` let go at 10 frames: the circle is hidden within 1 frame.
  - **M4.** With `Fx.enabled = false`, a blink, a shard and a ward cast raise no script error, and `MagicFx.live_count() == 0`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Run caster, fp_arms.
- [ ] **Step 5: Commit.** `feat(magicfx): circles of black glass and of ward smoke`

### Task 2: The shard as a spinning splinter, shattering

**Files:**
- Modify: `scripts/Magic/Shard.gd` (visual, spin, shatter), `scripts/Visual/MagicFx.gd` (`shatter`)
- Tests: `tests/caster_test.gd` M5–M6

**Interfaces:**
- **Produces:**
  - Shard's visual is `MagicFx.splinter_mesh(0.03, 0.2, 0.012)`, long axis along the flight, spinning 14 rad/s about it, with the obsidian material.
  - `MagicFx.shatter(context: Node, at: Vector3, normal: Vector3) -> void`: 8 tiny splinters (rigid bodies, layer 0, mask 1), thrown out along the normal with a fixed spread, gone after 1.5 s; a glass crack (stand-in `ting`, pitch 2.4).

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **M5.** In flight, the shard's visual rotation about its long axis changes between two frames by about 14/60 rad (±0.05).
  - **M6.** A shard at a stone wall: 8 shatter pieces exist within 2 frames; 0 after 1.5 s + 5 frames.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Commit.** `feat(magicfx): the shard spins as black glass and shatters`

### Task 3: Blink's mirror-crack, cold flash and ripple

**Files:**
- Create: `scripts/Visual/MagicView.gd` (CanvasLayer + ColorRect + a small vignette shader `scripts/Visual/magic_view.gdshader`)
- Modify: `scripts/Visual/MagicFx.gd` (`mirror_crack`, `ripple`, the ripple shader `scripts/Visual/vfx_ripple.gdshader`), `scripts/Magic/Caster.gd` (`_blink_to`)
- Tests: `tests/caster_test.gd` B1–B4

**Interfaces:**
- **Produces:**
  - `MagicFx.mirror_crack(context, at: Vector3, facing: Vector3) -> void`:
    - 10 flat shards (quads 6–12 cm) on a ring of 0.5 m about body height (`at` + up 1.0);
    - metallic 1.0, roughness 0.04, a cold rim;
    - burst outward 0.3 m and fade (alpha) over `MIRROR_LIFE := 0.6`.
  - `MagicFx.ripple(context, at: Vector3) -> void`: a sphere shell scaling 0.2 → 1.4 m over `RIPPLE_LIFE := 0.3`, its shader bending the screen behind it (`hint_screen_texture`) by its normal, strongest at its rim, fading out.
  - `MagicView.cold(tree, seconds := 0.1)`: the edge vignette in `#DDE6F2`, rising and falling over that time. `MagicView.of(tree)` makes it on first use; `cold_amount() -> float`.
  - `Caster._blink_to`: `mirror_crack` where you stood, `MagicView.cold`, `ripple` where you arrive.

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **B1.** A blink tap: 10 mirror shards are in the world within 2 frames, and none after 0.6 s + 5 frames.
  - **B2.** A ripple is at the arrival within 2 frames (within 0.3 m of the player's new position + up 1), and gone after 0.3 s + 5 frames.
  - **B3.** `MagicView.of(tree).cold_amount() > 0` within 3 frames of the blink, and 0 after 10 frames.
  - **B4.** 10 blinks 12 frames apart: `MagicFx.live_count()` never above 40, and 0 after 1 s.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Run caster, traversal (blink onto a ledge).
- [ ] **Step 5: Commit.** `feat(magicfx): Blink leaves a mirror-crack and arrives in a ripple`

### Task 4: The Ward in mesh smoke, and its bulge

**Files:**
- Modify: `scripts/Magic/Ward.gd` (visual: replaces the sphere puffs; `bulge(at)`; `turned_aside` calls the ward's bulge)
- Tests: `tests/caster_test.gd` W1–W4

**Interfaces:**
- **Produces, in `Ward`:**
  - 12 rising plumes round the ring (`MeshVfx.plume`, 0.6–1.1 m tall, from 0.06 to 0.16 m across), with the ward colours on `vfx_mesh` (unshaded, ghostly) at energy 1.1, opacity 0.75, a slow turn.
  - **Erosion:** 1.0 → 0.25 over the first 0.25 s (rising), held, then → 1.0 over the last 0.5 s.
  - `func bulge(at: Vector3) -> void`:
    - 3 short plumes pushed outward at `at`, eroding away over 0.45 s;
    - the two plumes nearest `at` thin (erosion +0.3) for 0.4 s;
    - at most 6 bulges live per ward (the oldest go first).
  - `static func turned_aside(context, at, direction, ward: Node3D = null)`: with a ward, its bulge.
  - `Ward.stops` returns the ward too. Callers move to `stopped_by(from, to, shooter) -> Dictionary` (`{at, ward}`), and `stops()` is kept as a thin wrapper.

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **W1.** A ward: 12 plumes, their material's `core` is `#F2FAFC`; at 5 frames their erosion is above 0.5 (rising), at 30 frames about 0.25.
  - **W2.** An arrow stopped: the ward's bulge count rises by 1, with 3 new plumes; they are gone after 0.45 s + 5 frames.
  - **W3.** After the ward's life: no ward plumes or bulges are left.
  - **W4.** 8 arrows in one frame: bulges never above 6, and all gone when the ward ends.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Run caster, combat, squad.
- [ ] **Step 5: Commit.** `feat(magicfx): the Ward rises as ghostly copal smoke and bulges where it stops a shot`

### Task 5: Empower: the pages, the pelt, the pulse, the crack

**Files:**
- Modify: `scripts/Interaction/HandSlot.gd`:
  - tome page flutter: `func set_tome_flutter(amount: float)`, three page quads turning about the spine;
  - pelt overlay: `func set_pelt(amount: float)`, a `material_overlay` on the arms' meshes with a new `scripts/Visual/pelt.gdshader`, masked to the left forearm and hand.
- Modify: `scripts/Magic/Caster.gd` (drives them, `MagicView` beast pulse, a shockwave when spent), `scripts/Visual/MagicFx.gd` (`shockwave`), `scripts/Visual/MagicView.gd` (`set_beast(amount)`, `beast_amount()`)
- Tests: `tests/caster_test.gd` E1–E5

**Interfaces:**
- **Produces:**
  - **Flutter:** while an Empower cast runs, `set_tome_flutter(cast_progress())`; pages flip one after another (3 pages, each over a third of the cast).
  - **Pelt:** while `empowered()`, `set_pelt(1.0)` (eased in 0.3 s), else 0 at once.
    - The shader is umber fur-like noise drifting along the arm (the noise's scroll along model-space Y).
    - Alpha at most 0.35, masked by `smoothstep` on the model-space side of the left arm. The side's sign is read from `bone_global("hand_l")`.
  - **Pulse:** `MagicView.set_beast(amount)`, an umber vignette pulsing at 70 bpm while charged.
  - `MagicFx.shockwave(context, at: Vector3, up: Vector3) -> void`: a flat ring mesh scaling 0.2 → 1.8 m over 0.3 s on `vfx_mesh`, umber/bone bands, eroding out; with a heavier crack (stand-ins `bone_crack` + `thud`, pitch 0.7).
  - **When the charge is spent:** for a blow, at the struck man's chest (or the kick contact); for a jump, at the feet; for a blink, at the arrival; for a shot, at the muzzle. The pelt and pulse go at once.

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **E1.** During the Empower cast at 50 % progress, `player.hand._pages` show a page turned (rotation about the spine > 0.5 rad on page 1).
  - **E2.** Charged: `player.hand.pelt_amount() > 0.9` after 30 frames, and `MagicView.of(tree).beast_amount() > 0`.
  - **E3.** An empowered kick: a shockwave appears within 2 frames, the pelt is 0 within 1 frame, and the beast pulse is 0 within 1 frame. The shockwave is gone after 0.3 s + 5 frames.
  - **E4.** Charged, then spent by a held jump: the shockwave is within 0.5 m of the feet at the spend. Charged, then spent by a blink: the shockwave is within 0.5 m of the arrival.
  - **E5.** An Empower cast broken by a hard hit: the flutter is 0 within 1 frame, and no pelt.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Run caster, revolver, fp_arms, combat.
- [ ] **Step 5: Commit.** `feat(magicfx): Empower turns the pages, marks the arm, and lands with a crack`

### Task 6: Gore pieces: lumpy, wet, replaceable

**Files:**
- Modify: `scripts/Visual/Gore.gd`
- Tests: `tests/revolver_test.gd` G1–G2

**Interfaces:**
- **Produces:**
  - `static var piece_meshes: Array[Mesh]`. When empty, it is filled with 5 code-built lumpy meshes (a subdivided sphere pushed out by a fixed noise, 6–12 cm, squashed differently).
  - `static var piece_material: Material`: a wet sheen, albedo `#4A0A08`, roughness 0.18, a rim.
  - Replacing `piece_meshes` with the user's models changes the pieces with no other change.
  - Collision is a small sphere per piece.

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **G1.** A burst's pieces use meshes from `Gore.piece_meshes`; none is a `BoxMesh` or `SphereMesh`; the material's roughness is ≤ 0.2.
  - **G2.** With `Gore.piece_meshes = [a custom BoxMesh]`, a burst's pieces all use it.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Run revolver, bodies.
- [ ] **Step 5: Commit.** `feat(gore): lumpy, wet stand-in pieces from a list the real ones replace`

### Task 7: Clips, every suite, the whole-branch review

**Files:**
- Create: `tests/visual/stage_magic.gd`/`.tscn`: clips of the Shard (cast, flight, shatter on stone), Blink (departure, travel, arrival), the Ward (rise, an arrow stopped, sinking), and Empower (cast, charged, an empowered kick), lit and dark.
- Modify: `docs/systems/combat.md` (MagicFx, MagicView, the circles, the Ward's smoke)

**Steps:**

- [ ] **Step 1:** Render the clips; contact sheets and GIFs into the scratchpad. Look at each frame; fix what reads as a card, a disc, a blob or camouflage, and re-render.
- [ ] **Step 2:** Run every suite. Expected: everything passes but the known pre-existing failures (`vfx_test` needs a window, `sway_test` atlases, `transitions_test`'s lambda, FR50, the navigation ERROR lines, `job_test`'s provoked ERROR, the `showcase_test` load flake that passes alone).
- [ ] **Step 3: Commit.** `test(magicfx): stills and clips of the spells; docs`
- [ ] **Step 4:** The whole-branch review of `revolver-magic` from `free-run` (both builds and both polish parts). Use superpowers:requesting-code-review's code-reviewer on the most capable model, with the specs, the plans, their Review Focus lines, and the ledgers' `Ruling:` lines. Then one fix pass, each fix test-first.
- [ ] **Step 5:** Send the user the clips and the review's results.
