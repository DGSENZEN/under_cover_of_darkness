# Gunplay Polish, Part One Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** aiming on right mouse, spells on held keys, a kick that moves the aim, hits that show, a heavy gun, casings, a sound tail, and the shot's own effects (flash, smoke, tracer, impacts, holes). Then stop for the user's verdict.

**Architecture:**
- `Revolver` gains an aim state (in place of the braced grip) and drives recoil into the real aim (neck pitch and body yaw).
- `Caster` reads spell keys as hold-to-cast.
- The shot's effects are new mesh effects in `scripts/Visual/GunFx.gd`, on the Metro lab's `MeshVfx` + `vfx_mesh.gdshader` (copied from `metro-standard`).
- Hit feedback goes through the HUD crosshair's contact shapes and `Fx`.

**Tech Stack:** Godot 4.5.1, GDScript; the house headless suites.

**Spec:** `docs/superpowers/specs/2026-10-23-gunplay-and-magic-polish-design.md`. Part one is "The user's checkpoint", first part. The earlier build's spec and plan (`2026-10-23-revolver-and-magic*`) describe the code this changes.

## Global Constraints

- **Where:** worktree `.claude/worktrees/revolver-magic`, branch `revolver-magic`. Run suites with `.superpowers/run.sh <scenes>`, which parse-checks first, then `tools/run_suites.sh`.
- **Determinism:** frame-exact under `--fixed-fps 60`. Fixed patterns, not `randf`, in anything a check reads.
- **Standing rules:**
  - effects made in house only;
  - every effect is made of its stuff (powder flash, powder smoke, brass, stone, wood, iron);
  - never call a visual defect harmless;
  - no new words: barks unchanged, sign text only in gym signs.
- **Colour:**
  - the flash is in stepped bands: cream core, amber, burnt orange edge, never white or black;
  - smoke is grey-brown;
  - marigold is not used.
- **Effects method:**
  - meshes with noise scrolled over them;
  - hard erosion;
  - flat colour bands;
  - fresnel rims;
  - restraint;
  - the shader on the mesh's own surface slot, not `material_override`.
- **Helsby:**
  - impact carried more by translation than rotation;
  - the combat corridor kept clear;
  - the weapon low right at the hip;
  - no control taken away.
- **Arms:** checked on the new arms (`ViewArmsScript.new_arms = true` in suites, `FP_ARMS=new` for stills). Viewmodel effects go on `HandSlot.VIEWMODEL_LAYER`.
- **Sounds:** stand-ins from existing packs. Every new wanted sound is added to `docs/superpowers/refs/revolver_sounds.md`.

## Review Focus

1. **Aiming while climbing, reloading, sprinting, switching weapon, or dead:** the aim drops cleanly (FOV back, speed back, no stuck zoom). Pinned by A6 (Task 1).
2. **Recoil at the top of the look range** (looking straight up, then firing): the pitch clamps at the controller's limit and never flips. Pinned by K4 (Task 3).
3. **Effects when firing fast for a long time** (60 shots): effect nodes don't pile up; counts return to zero. Pinned by V5 (Task 8).
4. **A spell key held through a weapon switch, or tapped in the middle of drawing the gun:** no cast fires late, and nothing is spent. Pinned by S29 (Task 2).
5. **Holes on a moving prop or a guard:** a hole decal is only placed on static world geometry, never on bodies or rigid props. Pinned by H5 (Task 4).

---

### Task 1: Aiming on right mouse (replaces the braced grip)

**Files:**
- Modify: `scripts/Combat/Revolver.gd`, `scripts/Combat/PlayerCombat.gd` (`speed_scale`), `scripts/Magic/Caster.gd` (remove `BRACED`, `toggle_braced`, G), `scripts/Combat/ViewPoses.gd` (`REVOLVER["aim"]`)
- Tests: `tests/revolver_test.gd` (R6, R15 move to aiming), new checks A1–A6

**Interfaces:**
- **Produces, in `Revolver`:**
  - `var aimed := false` (fully up);
  - `func aim_amount() -> float` (0..1, raising/lowering);
  - action `aim` on the right mouse (`_ensure_action` with a mouse button);
  - `const AIM_RAISE := 0.18`, `AIM_LOWER := 0.15`, `AIM_FOV_CUT := 13.0` (75 → 62), `AIM_SPEED := 0.7`.
- **Removed:** `set_braced`, `braced`, `Caster.toggle_braced`, `Loadout.BRACED`, the `grip` action.
- **Renamed:** what read `braced` reads `aimed`: the half kick, the 0.35 s ready time, no spread, the support hand (`HandSlot.set_gun_support(aim_amount())`).
- **Shots part way up** use the hip's spread and kick.
- `PlayerCombat.speed_scale()` returns `AIM_SPEED` while `revolver.aim_amount() > 0`. Below 1.0, the controller already refuses sprint.
- `player.juice.set_zoom(AIM_FOV_CUT * aim_amount())` while the gun is drawn, 0 otherwise.
- The aim pose `ViewPoses.REVOLVER["aim"]`: grip about (0.0, -0.2, -0.36), barrel along -Z, sights on the reticle. Its exact numbers are set by checking the stills (the barrel within 1° of the view axis).

**Steps:**

- [ ] **Step 1: Write the failing tests** (revolver_test):
  - **A1.** Holding `aim`: at 10 frames `aim_amount()` is in 0.3..0.8; at 12 frames `aimed`; the camera fov is within 0.5 of 62 after 30 frames.
  - **A2.** Aimed shots 22 frames apart both fire, and hip shots 22 frames apart don't (R6 rewritten).
  - **A3.** Aimed, `player.combat.speed_scale()` is 0.7. Let go, 1.0 within 15 frames, and the fov is back to 75 ±0.5 within 30.
  - **A4.** While aimed, `caster.can_cast(&"shard")` is false and `can_cast(&"blink")` is true.
  - **A5.** R15's braced half is redone with aiming: the left hand within 0.08 × SCALE of the grip. The aim pose's barrel is within 1° of the camera's -Z.
  - **A6.** Aimed, then hanging from a ledge: fov 75 ±0.5 within 30 frames and `aim_amount() == 0`. Aimed, then switching to the sword: the same.
- [ ] **Step 2: Run them and see them fail.** Run `.superpowers/run.sh tests/revolver_test.tscn`. Expected: A1–A6 FAIL (or a script error on `aim_amount`).
- [ ] **Step 3: Implement.** Remove the braced code paths, `Caster` G and `toggle_braced`, and update `caster_test` S8 to use `aim`.
- [ ] **Step 4: Run them and see them pass.** Run revolver, caster, fp_arms. Expected: all PASS.
- [ ] **Step 5: Commit.** `feat(gunplay): right mouse aims down the sights; the braced grip goes`

### Task 2: Spells on held keys

**Files:**
- Modify: `scripts/Magic/Caster.gd`
- Tests: `tests/caster_test.gd` (move every cast from `block` to `spell_1..3`; helpers `_cast`, `_cast_ward`; S4–S9, S15–S16, S18–S26), new S27–S29

**Interfaces:**
- **Produces:**
  - Pressing `spell_N` = `select(KEYED[N-1])` + `_begin` while held; letting go before `cast_time` cancels.
  - `block` (right mouse) no longer casts anything.
  - With a non-gun weapon or empty hands, a spell key selects the revolver (`inventory.select_by_id(&"revolver")`). The cast begins once `gun_drawn()` and the key is still held.
  - Aimed, a spell key lowers the aim and begins (the aim is dropped by `Revolver.drop_aim()`, new).
  - An aimed Blink is cancelled by a fresh `aim` press (just pressed while Q is held), which does not raise the sights. `aim` held from before neither cancels nor drops.

**Steps:**

- [ ] **Step 1: Rewrite the cast helpers and checks to keys, and add new ones:**
  - **S27.** With the sword drawn, holding `spell_1` draws the revolver and Shard is done within 60 frames of the press.
  - **S28.** Aimed, holding `spell_2` drops the aim (`aim_amount() == 0` within 15 frames) and Ward is cast.
  - **S29.** `spell_1` held 10 frames then the belt switched to the sword: no `cast_done`, power 100. `spell_1` tapped 2 frames during the gun's draw: no cast at all.
  - **S30.** Q held (aiming a blink), then a fresh `aim` press: no blink on release of Q, and `aim_amount()` stays 0.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Run caster, revolver, gunfight, combat.
- [ ] **Step 5: Commit.** `feat(magic): spells cast from their keys, held while they form`

### Task 3: The kick moves the aim

**Files:**
- Modify: `scripts/Combat/Revolver.gd` (`_kicked`), `scripts/PlayerUtils/CameraJuice.gd` (a translation push, if it has none)
- Tests: `tests/revolver_test.gd` K1–K4

**Interfaces:**
- **Produces, in `Revolver`:**
  - `const KICK_PITCH := 3.5`, `KICK_PITCH_AIMED := 1.75`, `KICK_YAW_MAX := 0.8` (degrees), `SHELL_CLIMB := 1.4`, `RECOVER := 0.6`;
  - `const YAW_PATTERN := [0.6, -0.3, 0.8, -0.7, 0.2, -0.5]` (× `KICK_YAW_MAX`, by shot count).
- **Each shot** adds the pitch to `player.neck.rotation.x`, clamped to the controller's `max_pitch_degrees`, and the yaw to `player.rotation.y`.
- **Recovery:** over the settle time, `RECOVER` of that shot's climb is taken back, eased out, as a per-frame delta (so mouse movement in between adds on top).
- **The camera shake** keeps trauma, and the punch moves to translation: `juice.lunge(+0.35)` (back along the view) with the rotation punch halved.

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **K1.** A hip shot: 2 frames after, the neck pitch is up 3.5° ±0.2.
  - **K2.** After the settle (40 frames): the pitch is 1.4° ±0.2 above where it started (60 % recovered).
  - **K3.** Aimed: the pitch climb is 1.75° ±0.2. The shell: ×1.4 the hip climb.
  - **K4.** The neck at the top of its range: the shot leaves the pitch at the limit, never beyond.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Run revolver, gunfight (whose aimed checks re-aim before each shot).
- [ ] **Step 5: Commit.** `feat(gunplay): the kick throws the aim up, and part of it comes back`

### Task 4: What you hit shows it

**Files:**
- Modify: `scripts/AISystem/Guard.gd` (`take_hit` bullet/shot: shove, longer stagger, head snap), `scripts/Combat/Revolver.gd` (hit markers, kill hit-stop, holes), `scripts/UI/StealthHUD.gd` (`Crosshair` shapes `shot`, `headshot`, `kill`), `scripts/Visual/Fx.gd` (stain kind `hole`, its procedural texture, fade)
- Tests: `tests/revolver_test.gd` H1–H5

**Interfaces:**
- **Produces:**
  - Guard: a ball shoves `velocity += flat(blow) * 2.5` (pellets: `0.4` each). The stagger for `bullet` is ×1.5 the arrow's. A headshot calls `_rig.react_hit(blow, 1.6)` and the head snaps back. A killing ball's `_last_push` is ×1.4.
  - `Revolver` emits `signal hit_confirmed(kind: StringName)`, with kind `&"shot"`, `&"headshot"` or `&"kill"`.
  - `StealthHUD` connects and calls `_crosshair.contact(kind)`. New drawn shapes:
    - shot: four short ticks at 45°;
    - headshot: the same, longer, in pale amber;
    - kill: a heavier X, held 0.35 s.
  - Hit sounds (stand-ins): `hit_tick` (`ting`, pitch 1.8, -10 dB); `kill_tick` (`thud`, pitch 0.7, -6 dB, after a second `ting`).
  - Hit-stop: 0.04 s on a body hit, 0.07 s on a kill.
  - `Fx.stain(context, at, normal, 0.09, "hole")`. Its look by the surface meta: stone a dark pock with a pale broken rim; wood a dark split; metal a bright dent. It fades out between 25 and 30 s.
  - Holes are placed only when the collider is a `StaticBody3D` or `CSGShape3D`.
  - Sparks on iron: `surface` in [`metal`, `iron`] gives `Fx.sparks(..., 0.8)` in place of dust.

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **H1.** A body shot on a frozen guard: his horizontal velocity is ≥ 2.0 within 2 frames of the hit (physics on, `stays_put`).
  - **H2.** `hit_confirmed` gives `&"shot"` for a body hit, `&"headshot"` for a head hit, `&"kill"` for a killing hit, and the crosshair's `contact_kind` matches.
  - **H3.** A kill requests a hit-stop of 0.07 s (`TimeFx.is_active` for 4 frames, not 5, at `--fixed-fps 60`, given real-time hit-stop).
  - **H4.** A shot at a stone wall: `Fx.stains_in_use()` rises by 1. After 1860 frames (31 s) that hole is hidden.
  - **H5.** A shot at a `RigidBody3D` crate and at a guard: no new stain.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Run revolver, bodies, gunfight, combat.
- [ ] **Step 5: Commit.** `feat(gunplay): hits shove, snap, mark and leave holes`

### Task 5: A heavy gun

**Files:**
- Modify: `scripts/Interaction/HandSlot.gd` (lag and draw time per item), `scripts/Combat/Revolver.gd` (not ready until drawn; sprint lowering)
- Tests: `tests/revolver_test.gd` W1–W3

**Interfaces:**
- **Produces:**
  - The mesh meta `&"draw_time"` (0.45) and `&"stow_time"` (0.35) on `revolver_mesh()`. `HandSlot` uses them in place of `switch_time` for that item.
  - The meta `&"sway_lag"` (2.2× the default) on the revolver; while aimed, the lag is ×0.4. The counter-rotation is capped at 4°.
  - `Revolver.ready_to_fire()` is false until `HandSlot.is_item_visible()` and its lowering is 0.
  - Sprinting with the gun lowered: no shot until 0.15 s after the sprint ends.

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **W1.** Selecting the revolver: no shot at 20 frames; a shot at 30 frames.
  - **W2.** A quick 30° turn in one frame: the gun's frame lags at least 2° behind and at most 4°, back within 1° after 30 frames.
  - **W3.** Sprinting then stopping: a shot 5 frames after the stop does not fire; one at 12 frames does.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Run revolver, fp_arms, interaction.
- [ ] **Step 5: Commit.** `feat(gunplay): the revolver draws, turns and runs heavy`

### Task 6: Casings at the reload

**Files:**
- Create: `scripts/Visual/Casings.gd` (static, like `Gore.gd`)
- Modify: `scripts/Combat/Revolver.gd` (`_start_loading`)
- Tests: `tests/revolver_test.gd` C1–C3

**Interfaces:**
- **Produces:**
  - `Casings.drop(context: Node, at: Vector3, out: Vector3, count: int) -> void`: one brass casing every 0.08 s, as `RigidBody3D`s:
    - collision layer 0, mask 1;
    - a 9 × 30 mm cylinder;
    - a tinkle (stand-in `coins`, pitch 2.2, -14 dB) on its first contact.
  - `Casings.live_count() -> int`, `MAX_LIVE := 24`, `LIFE := 10.0` (shrink away over the last 0.5 s).
  - Spent chambers are `rounds - loaded[cylinder]` when the gate opens.
  - The drop point is the gate's place in the world, from the viewmodel frame mapped back to world space (`HandSlot` gives `gate_world_position() -> Vector3`).

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **C1.** Three shots then R: three casings, all within 0.3 s.
  - **C2.** A full cylinder and R: none (no reload starts).
  - **C3.** Ten reloads of six: never more than 24; after 660 frames, 0.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Commit.** `feat(gunplay): spent casings fall from the gate`

### Task 7: The sound's tail

**Files:**
- Modify: `scripts/Combat/Revolver.gd` (`_sound` for shots)
- Modify: `docs/superpowers/refs/revolver_sounds.md`
- Tests: `tests/revolver_test.gd` T1–T2 (with `Sfx.recording = true`, as `feel_test` uses)

**Interfaces:**
- **Produces:**
  - `SOUNDS[&"gunshot_tail"] = [&"explosion", -16.0, 0.8]` and `SOUNDS[&"shellshot_tail"] = [&"explosion", -13.0, 0.7]` (stand-ins).
  - The tail plays 0.06 s after the crack: a scene timer in physics, created with `process_always = false`, `process_in_physics = true`.
  - Its volume is `tail_db + lerpf(-8.0, 0.0, enclosure)`, where `Vector2(size, enclosure) = Sfx.probe_room(space, eye, [player rid])`.

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **T1.** A shot in the open: `Sfx.recorded` has the crack at once and the tail 3–5 frames later.
  - **T2.** The same inside a closed box room (built in the test): the tail's recorded volume is at least 5 dB louder than in the open.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Commit.** `feat(gunplay): the shot rings on after its crack, more in a room`

### Task 8: The muzzle flash, smoke and tracer

**Files:**
- Copy from `metro-standard` (`git show metro-standard:<path> > <path>`): `scripts/Visual/MeshVfx.gd`, `scripts/Visual/vfx_mesh.gdshader`. Then run `Godot --headless --import --path .` once, since `MeshVfx` has a `class_name`.
- Create: `scripts/Visual/GunFx.gd` (static: the gun's effects)
- Modify: `scripts/Combat/Revolver.gd` (calls), `scripts/Interaction/HandSlot.gd` (`muzzle_world_transform(which)`)
- Create: `tests/visual/stage_gunfx.gd`/`.tscn`
- Tests: `tests/revolver_test.gd` V1–V5

**Interfaces:**
- **Consumes:** `MeshVfx.look(core, body, edge, energy, erosion, scroll, seed)`, `MeshVfx.flame`, `MeshVfx.tendril`/`plume`, `MeshVfx.ribbon` (`metro-standard` signatures).
- **Produces, in `GunFx`:**
  - `flash(hand: Node3D, at: Transform3D, shell: bool) -> Node3D`: on the viewmodel layer, a child of the hand, at the viewmodel muzzle.
    - Four (shell: six) flat petals in a star about the barrel axis, plus a lathed `MeshVfx.flame` cone along it. Petal length 0.07 m, ×1.5 for the shell, in viewmodel units ×SCALE.
    - Bands: core `#FFF1C9`, body `#F2A33A`, edge `#B2481B`; energy 3.0.
    - Roll from `ROLLS := [0.0, 0.7, 1.9, 2.6, 3.8, 4.9]` by shot count. Lives 2 physics frames, then is freed.
  - `smoke(context: Node, at: Vector3, ahead: Vector3, shell: bool) -> Node3D`: in the world.
    - 3 (shell: 5) tendrils/plumes rising and curling from `at`, grey-brown body `#6B6258`, edge `#3E3833`, a light core `#9C9284`.
    - Erosion goes 0.2 → 1.0 over `SMOKE_LIFE := 1.2` (shell `2.0`), then freed.
  - `tracer(context: Node, from: Vector3, to: Vector3) -> Node3D`: a ribbon 0.012 m wide, core `#FFF6E0` to edge `#D08A3A`, for 0.06 s.
  - `live_count() -> int` (all of the above).
  - Shell sparks: `Fx.sparks(context, muzzle, ahead, 1.6)` along the aim.

**Steps:**

- [ ] **Step 1: Write the failing tests:**
  - **V1.** A shot creates one flash under `player.hand` on `VIEWMODEL_LAYER`; 3 frames later it is gone.
  - **V2.** A shot creates 3 smoke pieces in the world; after 1.2 s + 5 frames, none.
  - **V3.** A tracer from the eye's muzzle to the hit point; after 5 frames, gone.
  - **V4.** A shell: 6 petals and 5 smoke pieces; `Fx` sparks rise.
  - **V5.** 60 shots (reloads as needed): `GunFx.live_count()` never above 30; 0 after 3 s.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** Then render `stage_gunfx` windowed and look at every frame closely before going on. Fix what looks like a card, a disc or a white blob.
- [ ] **Step 4: Run them and see them pass.** Run revolver, caster, combat, fp_arms.
- [ ] **Step 5: Commit.** `feat(gunfx): a powder flash, smoke that hangs, a tracer`

### Task 9: The checkpoint: stills, clips, every suite, and stop

**Files:**
- Modify: `tests/visual/stage_gunfx.gd` (the sequences below)
- Modify: `maps/combat_gym.gd` (the range sign's controls text: right mouse aims, 1/2/3 hold to cast, no G)
- Modify: `docs/systems/combat.md` (controls table)

**Steps:**

- [ ] **Step 1:** In the windowed stage, write PNG frame sequences to the scratchpad, each a short clip:
  - a hip shot at a stone wall 6 m off, frames 0–75;
  - an aimed shot;
  - a shell at a wooden crate and a guard at 2 m;
  - a reload with three spent;
  - the same shot seen from the side, 4 m off (a free camera, the player hidden);
  - dark and lit.
- [ ] **Step 2:** Make a contact sheet per clip with PIL into the scratchpad (also an animated GIF per clip), and look at them all. Fix anything that reads as a card, a disc or a blob, and re-render.
- [ ] **Step 3:** Run every suite with `tools/run_suites.sh`. Expected: everything passes except the four already known (`vfx_test` needs a window, `sway_test` lacks gitignored atlases, `transitions_test`'s own lambda, FR50 and the gym navigation ERROR line). Anything else is fixed.
- [ ] **Step 4: Commit.** `feat(gym): the range's controls for aiming and spell keys; docs`
- [ ] **Step 5: Stop.** Send the user the contact sheets and GIFs, and ask for the verdict on the look and whether mesh smoke will do for the Ward.
