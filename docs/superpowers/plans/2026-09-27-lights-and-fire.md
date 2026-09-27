# Lights and Fire Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every light source and fire in the game rebuilt as a Blender-made PS2-style fixture with our own flipbook flames, Thief 3 coronas, embers, smoke, soot, lit/out looks and designed sounds, without changing gameplay.

**Architecture:**
- `Torch.gd` becomes **the burner**: the light, the `Flicker` value, a `FlameFx` per flame point, the `Corona`, the lit/out state and the loop sound.
- `LightFixture.gd` **extends it** with a model built by `tools/props` (headless Blender), with sockets, material slots from `Materials.gd` (the user's photos via `ps2ify.py`, or flat colours), soot, drafts and fire events.
- Particles (`FireParticles`) and the shadow cap (`LightBudget`) are static per-level managers in the style of `Fx.gd`.

**Tech Stack:** Godot 4.5.1 (GDScript, Forward+), Blender 5.2.2 headless (bpy, Cycles), Python 3 + Pillow 12 + numpy, ffmpeg.

**Spec:** `docs/superpowers/specs/2026-09-27-lights-and-fire-design.md` (approved 2026-09-27; corrected while planning in a9e2ff1). Read it before any task. Section numbers below (§) are the spec's.

## Global Constraints

- Work only in the worktree `.claude/worktrees/lights-and-fire` (branch `lights-and-fire`). Main moves under other sessions. Commit at the end of every task; never push.
- Tools:
  - `GODOT=/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`
  - `BLENDER=/Applications/Blender.app/Contents/MacOS/Blender`
  - `python3` (Pillow, numpy)
  - `ffmpeg`
- First time in the worktree, and after adding any PNG, GLB, WAV or OGG: `$GODOT --headless --path . --import`.
- **Photos never enter git.** Keep `textures/source/`, `textures/ps2/` and anything derived from a `TCom_*` file out (the repository is public).
- **No downloaded VFX.** Every file in `assets/vfx/` is rendered or drawn by `tools/props/flames.py`.
- **Sounds only from the user's packs:**
  - TomMusic `~/Downloads/Free Fantasy SFX Pack By TomMusic`
  - NOX `~/Downloads/Essentials_Series_NOX_SOUND/Nature_Essentials_NOX_SOUND` (CC0)
  - `~/Downloads/AUCOD Web SFX`
  - `~/Downloads/400 Sounds Pack`
  - `~/Downloads/FilmCow Recorded SFX`
  - `~/Downloads/FilmCow Designed SFX`

  Credit every new source in `CREDITS.md`. No procedural audio.
- **Effects never touch gameplay:**
  - Everything `FlameFx`, `Corona`, `FireParticles` and the haze draw sits on `Layers.FX`. The lightgem's cameras (`cull_mask` 655359) exclude it.
  - A burner's light stays `energy × _strength × (1 + flicker × v) × (1 + FLARE_LIGHT × _flare²) × _lit_level`, with |v| ≤ 1.
  - Energies and ranges of existing lights stay as today (§8.1).
- **Determinism:** every random draw in a burner comes from its own `RandomNumberGenerator` seeded with `Flicker.seed_of(global_position)`. Suites run headless with `--fixed-fps 60`.
- **Existing suites:** their assertions do not change. The single exception is retro R6, which reads `torch.frame` instead of `material_override.uv1_offset.x` (Task 6).
- **Style:** GDScript with `##` doc comments in the project's plain voice and British spelling ("colour"), tabs, `preload` consts, static builders returning the node already added. Python in the style of `tools/wardrobe` and `tools/prepare_sfx.py`.
- **Running suites:**
  - one: `perl -e 'alarm 900; exec @ARGV' $GODOT --headless --fixed-fps 60 --path . res://tests/<name>.tscn 2>&1 | grep -E "PASS|FAIL|SCRIPT ERROR"`
  - all: `tools/run_suites.sh` (Task 2).

## Review Focus

These are the inputs the spec implies but no feature test exercises. Each has its test in the named task.

1. **A burner freed mid-transition.** A guard's dropped lantern freed while dousing, or a level unloading while a torch cools, must leave no errors and no dangling particle or budget entries (Task 9, L22).
2. **A level reloaded.** `FireParticles` and `LightBudget` are static per level. After the scene is freed and another built, they must start fresh and never touch freed nodes. This is `LightProbe`'s old lesson (Task 10, L26).
3. **No camera.** Burners built before the player exists, or in a scene with no `Camera3D`, must run without errors. Coronas stay hidden, embers are not emitted, the budget keeps shadows as made (Task 10, L27).
4. **Rapid toggling.** `light()`, `put_out()`, `light()` in one frame (the gallery's L key held) must end lit, with one `lit_changed` per real change and no stacked tweens (Task 9, L21).
5. **`torch_at` beside a door or a guard.** The wall search must only take static world geometry. A torch must never mount on a door or a man (Task 13, L33d).

---

## File Structure

| File | Responsibility |
|---|---|
| `tools/textures/ps2ify.py`, `test_ps2ify.py`, `recipes/*.json` | Photos → PS2 textures (gitignored output) |
| `scripts/Visual/Materials.gd` | One shared material per slot: photo or flat colour, vertex colour on; glowing variant |
| `tools/props/flames.py`, `test_sheets.py` | Heat sheets, smoke, corona, soot, ramps (committed); the lantern cookie |
| `scripts/Visual/Lights/Flicker.gd` | Pure flicker and draft functions |
| `scripts/Visual/Lights/FlameFx.gd`, `flame.gdshaderinc`, `flame.gdshader`, `flame_core.gdshader` | Sprites at one flame point |
| `scripts/Visual/Torch.gd` (rewritten) | The burner |
| `scripts/Visual/Lights/Corona.gd`, `corona.gdshader` | The halo |
| `scripts/Visual/Lights/FireParticles.gd`, `smoke.gdshader` | Embers, smoke, steam, sparks |
| `scripts/Visual/Lights/LightBudget.gd` | The shadow cap |
| `scripts/StimuliSystem/LightProbe.gd` (1 line) | Reads `casts_shadow` meta |
| `tools/props/*` (`props.sh`, `recipes.py`, `common.py`, `build.py`, `check.py`, `bake.py`, `export.py`, `preview.py`, `test_check.py`, `test_build.py`) | The Blender pipeline |
| `assets/props/source/*.blend`, `assets/props/lights/*.glb`, `*.json` | Built fixtures |
| `scripts/Visual/Lights/LightFixture.gd`, `glow.gdshader`, `haze.gdshader` | A fixture: the model on a burner |
| `scripts/Visual/Lights/Lights.gd` | Builders |
| `tools/prepare_sfx.py`, `scripts/Audio/Sfx.gd`, `CREDITS.md` | New sounds |
| `scripts/AISystem/GuardHands.gd`, `GuardRig.gd`, `scripts/Combat/Fire.gd`, `scripts/Interaction/Furnishings.gd`, six maps | Switched over |
| `maps/lights_gallery.tscn/.gd`, `tests/lights_test.tscn/.gd`, `tests/visual/stage_lights.tscn/.gd`, `tools/run_suites.sh` | Review and tests |

---

### Task 1: The texture converter

**Files:**
- Create: `tools/textures/ps2ify.py`, `tools/textures/test_ps2ify.py`, `tools/textures/recipes/{rust_iron,chain,wood_old,bark,stone_rubble,stone_ashlar}.json`
- Modify: `.gitignore`

**Interfaces:**
- Produces:
  - CLI `python3 tools/textures/ps2ify.py import [folder=~/Downloads]` copies `TCom_*` files into `textures/source/`.
  - CLI `python3 tools/textures/ps2ify.py build [name ...]` writes `textures/ps2/<name>.png` for each (or every) recipe. It exits 1 naming the recipe on any failure.
  - `convert(image: PIL.Image.Image, recipe: dict) -> PIL.Image.Image` (pure)
  - `load_recipe(path: Path) -> dict`
  - `build(name: str, source_dir: Path, out_dir: Path) -> Path`
  - Recipe keys (JSON):

    | Key | Meaning |
    |---|---|
    | `source` | file name in `textures/source/` |
    | `size` | `[w, h]` |
    | `colours` | int ≤ 256 |
    | `crop` | `[x, y, w, h]` as fractions of the source, or null |
    | `tint` | `[r, g, b]` multipliers |
    | `contrast` | 1 = unchanged |
    | `brightness` | 1 = unchanged |
    | `desaturate` | 0–1 |
    | `grime` | 0–1: darkening by seeded low-frequency noise |
    | `ao` | a source file to multiply in, or null |
    | `alpha` | `"none"` or `"threshold"` |
    | `threshold` | default 128 |
    | `key` | `[r, g, b, tolerance]` to key a background out to transparent, or null |

- [ ] **Step 1: Write the failing tests** in `tools/textures/test_ps2ify.py` (`unittest`, synthetic images only, no photos needed):
  - `test_size`: a 700×500 RGB noise image with `size: [128, 128]` gives 128×128.
  - `test_palette`: `colours: 16` gives at most 16 distinct RGB colours.
  - `test_no_dither`: a horizontal gradient converted to 4 colours has at most 3 colour changes along any row.
  - `test_threshold_alpha`: an RGBA image with alpha ramp 0–255 and `alpha: "threshold"` has alpha values ⊆ {0, 255}.
  - `test_crop`: a 200×200 image, red in its top-left quadrant, with `crop: [0, 0, 0.5, 0.5]`: ≥ 95% of the output pixels have R > 200 and G, B < 60.
  - `test_key`: a white background keyed with `[255, 255, 255, 30]` becomes alpha 0.
  - `test_sixteen_bit`: an `I;16` TIFF written to a temp dir converts without error.
  - `test_missing_source`: `build("x", empty_dir, out)` raises `FileNotFoundError` whose message contains the source name.
- [ ] **Step 2: Run to verify they fail.** Run `python3 -m unittest tools/textures/test_ps2ify.py -v`. Expected: errors (module missing).
- [ ] **Step 3: Implement `ps2ify.py`.**
  - Order in `convert`: crop → 8-bit RGB(A) → downscale with `Image.Resampling.BOX` → tint, brightness, contrast, desaturate → AO multiply → grime (seeded `numpy` noise, 8 px cells, bilinear-upsampled) → key → `quantize(colours, dither=Image.Dither.NONE)` → alpha threshold.
  - `import` copies only files starting `TCom_`.
- [ ] **Step 4: Write the six recipes**, all `size: [128, 128]`:

  | Recipe | Source | Settings |
  |---|---|---|
  | `rust_iron` | `TCom_Rust0221_16_seamless_S.png` | desaturate 0.5, brightness 0.55, colours 24 |
  | `chain` | `TCom_MetalVarious0033_1_S.jpg` | key its background, alpha threshold, colours 16 |
  | `wood_old` | `TCom_WoodPlanksOld0239_2_seamless_S.jpg` | colours 24 |
  | `bark` | `TCom_Wood_BarkOak9_0.8x0.8_A_2K_albedo.tif` | colours 24 |
  | `stone_rubble` | `TCom_StoneOldMixedSize0057_1_seamless_S.jpg` | colours 32 |
  | `stone_ashlar` | `TCom_StoneRegularWeathered0227_1_seamless_S.jpg` | colours 32 |

- [ ] **Step 5: Add to `.gitignore`:** `textures/source/`, `textures/ps2/`, `assets/props/source/backup/`.
- [ ] **Step 6: Run the tests.** Run `python3 -m unittest tools/textures/test_ps2ify.py -v`. Expected: 8 OK. Then run `python3 tools/textures/ps2ify.py import && python3 tools/textures/ps2ify.py build`. Expected: 6 PNGs in `textures/ps2/`. `git status` shows none of them.
- [ ] **Step 7: Commit:** `feat(textures): ps2ify, the photos made PS2 textures outside git`.

### Task 2: Materials, the lights suite and its baselines

**Files:**
- Create: `scripts/Visual/Materials.gd`, `tests/lights_test.gd`, `tests/lights_test.tscn`, `tools/run_suites.sh`

**Interfaces:**
- Produces:
  - `Materials.SLOTS: Dictionary`: slot `StringName` → `{"photo": String, "colour": Color, "metallic": float, "roughness": float}`, with the 13 slots and flat colours of §6.2. `photo` is `""` for pitch, brass, clay, wax, horn, char and coal. Metallic is 0.35 for iron, chain and brass and 0 elsewhere; roughness is 0.85.
  - `static var folder := "res://textures/ps2/"`
  - `static var photo_names := {}` (slot → photo name; filled from `SLOTS` on first use; tests may overwrite entries)
  - `static func surface(slot: StringName) -> StandardMaterial3D`, cached per slot. An unknown slot gives flat #FF00FF and pushes one error. `vertex_color_use_as_albedo = true`; texture filter `NEAREST_WITH_MIPMAPS`.
  - `static func photo(slot: StringName) -> Texture2D`: null when `ResourceLoader.exists` says no.
  - `static func clear_cache() -> void`
  - `static func fallbacks() -> Array[StringName]`: the slots that have a photo name but no photo found, for the gallery's `--verbose` (§12)
  - `lights_test.gd` harness: `_frames(n)` and `_check(name, ok, detail)` exactly as `tests/retro_test.gd`. Checks are named `L<n> …`. It prints `==== RESULTS ====` then quits.
  - `tools/run_suites.sh [glob=tests/*_test.tscn]` runs 6 suites at a time with `--fixed-fps 60` and a 900 s alarm, logs to `${TMPDIR:-/tmp}/suites/<name>.log`, and prints `PASS n / FAIL n` per suite. It lists any suite missing `==== RESULTS ====` or containing `SCRIPT ERROR`, and exits 1 if any fail.

- [ ] **Step 1: Write the failing checks** in `lights_test.gd`:
  - **L1:** with `Materials.folder = "res://nowhere/"`, `surface(&"iron")` has a null `albedo_texture`, `albedo_color` = #2A2826, and `vertex_color_use_as_albedo`.
  - **L2:** with `folder = "res://textures/"` and `photo_names[&"stone"] = "stone_brick_1"`, `surface(&"stone").albedo_texture` is not null. Restore both, then `clear_cache()`.
  - **L3 (baselines):** build a bare `Torch` at (0, 2, 0), `Fire.brazier` at (20, 0, 0) and `Furnishings.campfire` at (40, 0, 0) on a floor block. Set each burner's `flicker = 0` (the campfire's `Torch` is the child of its body; the brazier's is `fire.torch`). Wait 5 frames. Record `LightProbe.light_at(self, p)` at 2 m horizontally from each flame, at chest height 1.2 m.

    Run once, print the six numbers, and paste them into `const PROBE_BASELINE := [..]`. From then on, L3 asserts each reading is within 10% of its baseline.
- [ ] **Step 2: Run to verify L1 and L2 fail.** Run `lights_test`. Expected: L1 and L2 FAIL (script missing). L3 prints the numbers.
- [ ] **Step 3: Implement `Materials.gd`** (static, `extends RefCounted`, like `Props.gd`) and `tools/run_suites.sh`.
- [ ] **Step 4: Run `lights_test` to verify it passes.** Expected: L1–L3 PASS. Then run `tools/run_suites.sh`. Expected: all 32 existing suites as they are on main. Record any suite that already fails on main in the commit message, so later tasks are not blamed for it.
- [ ] **Step 5: Commit:** `feat(lights): Materials by slot, the lights suite, probe baselines`.

### Task 3: Our flames, smoke, corona, soot and ramps

**Files:**
- Create: `tools/props/flames.py`, `tools/props/test_sheets.py`, `tools/props/props.sh` (with the `flames` verb only for now)
- Create (generated, committed): `assets/vfx/flame_{candle,small,torch,brazier,fire}.png`, `assets/vfx/smoke.png`, `assets/vfx/corona.png`, `assets/vfx/soot.png`, `assets/vfx/ramps/{candle,lamp,torch,brazier,fire,dying,gutter}.png`

**Interfaces:**
- Produces:
  - `tools/props/props.sh flames` runs `$BLENDER -b --factory-startup --python-exit-code 1 --python tools/props/flames.py -- all`.
  - Sheets are horizontal strips, greyscale 8-bit, heat quantised to 16 levels (values `round(h × 15) × 17`); 0 means empty.

    | Sheet | Frame size | Frames | Sheet size |
    |---|---|---|---|
    | candle | 8×16 | 5 | 40×16 |
    | small | 16×24 | 6 | 96×24 |
    | torch | 32×64 | 8 | 256×64 |
    | brazier | 64×64 | 10 | 640×64 |
    | fire | 64×96 | 12 | 768×96 |

  - `smoke.png`: 128×32, 4 puffs, white RGB with alpha ⊆ {0, 128, 255}.
  - `corona.png`: 64×64 grey, value `(1 − r)^2.2`, 16 levels.
  - `soot.png`: 128×128 RGBA, black, alpha from rising noise, ⊆ 8 levels.
  - `ramps/*.png`: 64×1 RGBA. The first column where alpha is 255 is the cut.

- [ ] **Step 1: Write the failing tests** in `test_sheets.py` (`unittest` + Pillow, reading the committed files):
  - **dimensions:** every sheet matches the table above.
  - **levels:** each flame sheet has ≤ 16 distinct values.
  - **loop seam:** the mean absolute difference between the last and first frame is ≤ 1.5 × the mean difference between adjacent frames.
  - **not static:** the mean adjacent-frame difference is > 2 (out of 255).
  - **pinned base:** the bottom 15% of every frame has non-empty pixels within the middle 60% of its width.
  - **smoke and soot:** alpha sets as above.
  - **ramps:** 64×1; alpha is 0 at column 0; the last column is brightest.
- [ ] **Step 2: Run to verify they fail.** Run `python3 -m unittest tools/props/test_sheets.py -v`. Expected: errors (files missing).
- [ ] **Step 3: Implement `flames.py`.**
  - **Flame render:** Cycles on the CPU, 8 samples, emission only, orthographic camera, rendered at 4× the frame size.
  - **The flame shader:** a teardrop gradient (wide at the base, a point at the top) minus a 4D Noise Texture (scale 2.2, detail 3, distortion 0.6), plus a vertical stretch. The noise's `Vector.z` and `W` travel a circle of radius 0.9 over the loop, so frame N meets frame 0. The flame is pinned to the fuel: there is no upward scroll, only change of shape. Brazier and fire sheets add a second, lower-frequency layer so tongues pinch off.
  - Each frame is read back, block-averaged 4× with numpy, and quantised to 16 levels.
  - Smoke, corona and soot are drawn with numpy (seeded) and saved via `bpy.data.images`.
  - **Ramps** are written from data. Each stop is `(position, hex)`; positions before the cut are transparent:

    | Ramp | Stops |
    |---|---|
    | `torch` | cut 0.12 #5A0A02, 0.35 #C8320A, 0.55 #FF8200, 0.75 #FFB040, 0.9 #FFE8A0, 1.0 #FFFFF0 |
    | `brazier` | cut 0.14 #4A0802, 0.4 #B42808, 0.6 #FF7A00, 0.8 #FFAE3C, 1.0 #FFF4C8 |
    | `fire` | cut 0.12 #500902, 0.4 #B42808, 0.65 #FF8D0B, 0.8 #FFAE3C, 1.0 #FFF4C8 |
    | `candle` | cut 0.2 #7A1E04, 0.45 #FF8200, 0.7 #FFB85A, 0.9 #FFF0C0, 1.0 #FFFFFF |
    | `lamp` | as `candle` with 0.45 #FF7800 |
    | `dying` | cut 0.2 #3C0602, 0.5 #8C1C04, 0.8 #D2500A, 1.0 #FF9A3C |
    | `gutter` | cut 0.2 #1E2A6E, 0.35 #7A1E04, 0.6 #FF7800, 1.0 #FFE0A0 |

  - The `.png.import` of each ramp sets `mipmaps/generate=false`.
- [ ] **Step 4: Render and test.** Run `tools/props/props.sh flames && python3 -m unittest tools/props/test_sheets.py -v`. Expected: all OK. Then `$GODOT --headless --path . --import`.
- [ ] **Step 5: Look at the sheets**: open `assets/vfx/flame_torch.png` scaled ×8. The flame reads as fire (tongues, a hot core low and central), not blobs. If it reads wrong, adjust the shader numbers and re-render.
- [ ] **Step 6: Commit:** `feat(vfx): our own heat flipbooks, smoke, corona, soot and ramps`.


### Task 4: Flicker

**Files:**
- Create: `scripts/Visual/Lights/Flicker.gd`
- Test: `tests/lights_test.gd` (L4–L6)

**Interfaces:**
- Produces (`extends RefCounted`, static):
  - `const KINDS := {&"candle": 0.0, &"lamp": 4.5, &"torch": 5.0, &"cresset": 3.5, &"brazier": 2.4, &"fire": 1.7}`, the puff rate in Hz.
  - `const DRIFT := 0.4`, `const DRAFT_RATE := 10.0`, `const DRAFT_TIME := 1.0`.
  - `static func value(kind: StringName, t: float, salt: int) -> float` returns `0.55·sin(2π·r·t + φ1) + 0.25·sin(2π·1.73r·t + φ2) + 0.2·sin(2π·DRIFT·t + φ3)`, with phases drawn from `salt` (not named `seed`, which would shadow the built-in). It returns 0 for `candle`.
  - `static func draft(since: float) -> float` returns `sin(2π·DRAFT_RATE·since) × (1 − since/DRAFT_TIME)²` for 0 ≤ since < `DRAFT_TIME`, else 0.
  - `static func seed_of(at: Vector3) -> int`: a stable hash of `at` rounded to cm.

- [ ] **Step 1: Write the failing checks:**
  - **L4:** for every kind and 3 seeds, |value| ≤ 1 over 10 s sampled at 60 Hz.
  - **L5:** for every kind but candle, a 480-sample DFT (8 s at 60 Hz) peaks at a frequency within 20% of the kind's rate.
  - **L6:** `value(&"candle", t, s) == 0` for all t; `draft(0.3) != 0`; `draft(1.0) == 0`; max |draft| over [0.8, 1.0) < 0.05.
- [ ] **Step 2: Run to verify they fail.** Run `lights_test`. Expected: L4–L6 FAIL.
- [ ] **Step 3: Implement `Flicker.gd`.**
- [ ] **Step 4: Run to verify they pass.** Run `lights_test`. Expected: L1–L6 PASS.
- [ ] **Step 5: Commit:** `feat(lights): flicker at the rate real flames puff`.

### Task 5: FlameFx and the flame shaders

**Files:**
- Create: `scripts/Visual/Lights/FlameFx.gd`, `flame.gdshaderinc`, `flame.gdshader`, `flame_core.gdshader`
- Test: `tests/lights_test.gd` (L7–L10)

**Interfaces:**
- Consumes: the sheets and ramps from Task 3.
- Produces:
  - `FlameFx` (`extends Node3D`):
    - `const SHEETS := {&"candle": [8, 16, 5, 9.0], &"small": [16, 24, 6, 10.0], &"torch": [32, 64, 8, 12.0], &"brazier": [64, 64, 10, 10.0], &"fire": [64, 96, 12, 8.0]}` (width, height, frames, default fps).
    - Exports: `sheet := &"torch"`, `ramp := &"torch"`, `low_ramp := &"dying"`, `size := 0.34` (flame height, m), `frame_rate := 0.0` (0 = the sheet's default), `layers := 2`, `core := true`.
    - `var sprites: Array[MeshInstance3D]`; `sprites[0]` is the primary. `var frame := 0`.
    - `const LEAN_REACH := 0.07`.
    - `func advance(delta: float, wobble: float, strength: float, lean: Vector3, flare: float, jump: float) -> void`. Here `wobble` is the flicker value −1..1, `jump` a 0..1 flame-only boost from fire events, and `delta` is scaled time.
    - `func set_shown(level: float) -> void` (0..1: grows and shrinks the sprites for lighting and snuffing).
    - `static func material(sheet: StringName, ramp: StringName, low_ramp: StringName, core_pass: bool) -> ShaderMaterial`, cached.
    - A missing sheet PNG (not `ResourceLoader.exists`) falls back to today's `Fx.texture(&"flame")` drawn as a 4-frame strip, and pushes one warning (§12).
  - Shaders:
    - `flame.gdshader` is `unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled`; `flame_core.gdshader` is `unshaded, blend_mix, depth_draw_opaque, cull_disabled, fog_disabled` with a discard below `core_cut = 0.8`, output ×2.5.
    - Both include `flame.gdshaderinc`, which declares:
      - `uniform sampler2D heat : filter_nearest, repeat_disable`
      - `uniform sampler2D ramp : filter_nearest, repeat_disable`
      - `uniform sampler2D ramp_low : filter_nearest, repeat_disable`
      - `uniform int frames`
      - `instance uniform int frame; instance uniform float strength; instance uniform vec3 lean; instance uniform float mirror; instance uniform float low`
    - It billboards with fixed Y in `vertex()`, shears the top vertices by `lean`, samples `textureLod(ramp, vec2(h, 0.5), 0.0)`, and mixes `ramp_low` by `low`.

- [ ] **Step 1: Write the failing checks:**
  - **L7:** a `FlameFx` with `layers = 2, core = true` has 3 sprites, all with `layers == Layers.FX` and shadows off. Two `FlameFx` of the same sheet share one `ShaderMaterial` (the `material_override` of each primary is the same object).
  - **L8:** `frame` changes at the sheet's rate. Over 120 physics frames at `Engine.time_scale = 1.0` it takes ≥ 20 changes for `torch` (12 fps × 2 s ≈ 24). At `time_scale = 0.5` over the same 120 frames it takes ≤ 14. Restore `time_scale = 1.0`.
  - **L9:** `advance(…, lean = Vector3(1, 0, 0), …)` puts `sprites[0].position.x` ≥ 0.05 and `sprites[0].scale.y` < 1.
  - **L10:** `advance` with strength 0.2 sets instance uniform `low` > 0.5 on `sprites[0]` (read with `get_instance_shader_parameter`); strength 1.0 sets `low` == 0.
- [ ] **Step 2: Run to verify they fail.** Expected: L7–L10 FAIL.
- [ ] **Step 3: Implement.**
  - Quad size is `size × w/h` wide and `size` tall, base at the node's origin + `size/2`.
  - Layer 2 is mirrored and starts `frames/2` later; frame rate × 0.67 when strength < 0.35.
  - `scale = lerp(0.35, 1, clamp(strength, 0, 1.5)) × (1 + 0.08·wobble) × (1 + 0.45·flare²) × (1 + 0.3·jump)`.
  - Lean offset is `lean_flat × LEAN_REACH × size/0.34`, with scale.y × `(1 − 0.1·|lean|)`.
  - `low = smoothstep(0.35, 0.2, strength)`.
- [ ] **Step 4: Run to verify.** Expected: L1–L10 PASS.
- [ ] **Step 5: Commit:** `feat(lights): FlameFx, flames drawn from heat through a ramp`.

### Task 6: The burner (`Torch.gd` rewritten)

**Files:**
- Modify: `scripts/Visual/Torch.gd` (rewrite, keeping its header's voice), `tests/retro_test.gd` (R6: one expression)
- Test: `tests/lights_test.gd` (L11)

**Interfaces:**
- Consumes: `Flicker`, `FlameFx`.
- Produces: `Torch.gd`, the burner. Everything below, plus everything it has today.
  - **Kept exports:** `color` (default becomes `Color("FF9829")`), `energy := 2.4`, `light_range := 9.0`, `flicker := 0.16`, `shadows := true`, `frame_rate := 0.0` (0 = sheet default), `flame_size := 0.34`.
  - **Kept members:** `light: OmniLight3D`, `flame: MeshInstance3D` (= `flames[0].sprites[0]`), `crackle: AudioStreamPlayer3D`, `_crackle_db`, `_strength`, `_lean`, `_flare`.
  - **Kept constants:** `CRACKLE`, `CRACKLE_DB`, `CRACKLE_REACH`, `FLARE_LIGHT`, `FLARE_SIZE`, `FLARE_TIME`, `LEAN_REACH`.
  - **Kept methods:** `lean(v)`, `set_strength(k)`, `flare(amount := 1.0)`, and group `torches`.
  - **New exports:** `flicker_kind := &"torch"`, `sheet := &"torch"`, `ramp := &"torch"`, `low_ramp := &"dying"`, `flame_points: PackedVector3Array = [Vector3.ZERO]`, `flame_layers := 2`, `core := true`, `corona_px := 48.0` (0 = none; used from Task 7), `loop_path := CRACKLE`, `loop_db := CRACKLE_DB`, `loop_reach := CRACKLE_REACH`, `lit := true` (Task 9), `ember_rate := 6.0`, `smoke_rate := 3.0` (Task 8), `event_every := Vector2.ZERO` (Task 16).
  - **New members:**
    - `var flames: Array[FlameFx]`
    - `var frame: int` (getter: `flames[0].frame`)
    - `var rng: RandomNumberGenerator` (seeded `Flicker.seed_of(global_position)` in `_ready`)
    - `var _jump := 0.0`
    - `func _before_ready() -> void`, an empty hook that `LightFixture` overrides to set exports before the burner builds itself.
  - The light sits at mean(flame_points) + (0, 0.12, 0), jittering 1–3 cm only for `flicker_kind` torch and cresset. It has `set_meta(&"casts_shadow", shadows)` (read by `LightProbe` in Task 10).

- [ ] **Step 1: Write the failing check.** **L11:** a bare `Torch.new()`:
  - is in `torches` and answers `lean`, `set_strength` and `flare`;
  - has `flame is MeshInstance3D` on `Layers.FX`;
  - has `light.get_meta(&"casts_shadow") == true`;
  - `frame` takes ≥ 3 values over 60 frames;
  - over 300 frames the light energy stays within `energy × (1 ± flicker)` (±0.01);
  - after `set_strength(0.2)` the energy is < 0.6 × `energy`;
  - `flare(1.0)` raises `_flare` to 1 and it decays below 0.1 within `FLARE_TIME + 0.1` s.
- [ ] **Step 2: Change retro R6** to read `torch.frame` where it read `torch.flame.material_override.uv1_offset.x`. The assertion is unchanged. Run `lights_test`: L11 FAIL (no `frame`).
- [ ] **Step 3: Rewrite `Torch.gd`.**
  - Its `_ready` calls `_before_ready()`, seeds `rng`, builds the light and one `FlameFx` per flame point (sheet, ramp, low_ramp, size = `flame_size`, layers = `flame_layers`, core), then builds the loop exactly as today from `loop_path`, `loop_db` and `loop_reach`.
  - `_process` keeps today's order: flare decay, the light formula of Global Constraints with `v = Flicker.value(flicker_kind, _time, Flicker.seed_of(global_position))` (computed once in `_ready` as `_salt`), range from strength, and `advance` on each `FlameFx`.
  - Keep `_listen` unchanged apart from using `loop_reach` and `loop_db`.
- [ ] **Step 4: Run** `lights_test`, `retro_test`, `aliveness_test`, `routines_test`, `habits_test`, `sound_test`, `smooth_test`. Expected: every check passes (A19, R2, H25, M13, R6 included).
- [ ] **Step 5: Commit:** `feat(lights): Torch becomes the burner, flames by FlameFx and Flicker`.

### Task 7: The corona

**Files:**
- Create: `scripts/Visual/Lights/Corona.gd`, `corona.gdshader`
- Modify: `scripts/Visual/Torch.gd` (makes one when `corona_px > 0`, at mean(flame_points) + (0, 0.06, 0); updated each physics tick)
- Test: `tests/lights_test.gd` (L12–L14)

**Interfaces:**
- Produces:
  - `Corona` (`extends Node3D`):
    - Exports: `size_px := 48.0`, `tint := Color.WHITE`.
    - `var visibility := 0.0`; `const FADE := 0.15`; `const RAYS := 3`; `const MASK := 1 | 2` (world and guards' physics layers).
    - `func tick(camera: Camera3D, glow: float, light_range: float, exclude: Array[RID], delta: float) -> void`. Here `glow` = current energy ÷ energy.
    - `static func distance_fade(distance: float, light_range: float) -> float`: 1 up to 1.5 × range, 0 from 3 × range, smooth between.
    - `func world_radius(camera: Camera3D) -> float`: size_px on the 360-line grid converted to metres at the corona's distance.
  - `corona.gdshader`: `unshaded, blend_add, depth_test_disabled, fog_disabled, cull_disabled`, `corona.png`. `instance uniform float size_px; instance uniform float amount; instance uniform vec4 tint`. `vertex()` scales the quad in clip space to `size_px / 360 × 2` NDC units tall (aspect-corrected), so its screen size is constant.

- [ ] **Step 1: Write the failing checks** (a `Camera3D` made current in the test at the origin, looking −Z):
  - **L12:** a burner at (0, 1.6, −6) has corona visibility > 0.9 after 15 frames. With a 4×4×0.3 m `Props.block` between, visibility is < 0.05 within 12 frames. Removed, it is > 0.9 within 12 frames.
  - **L13:** a guard (`Guard.tscn`, `collision_layer` 2) standing so that only one of the three rays is blocked gives visibility between 0.2 and 0.9.
  - **L14:** `distance_fade(10, 5) == 1`, `distance_fade(15, 5) == 0`, `0 < distance_fade(11.5, 5) < 1`. The corona and its quad are on `Layers.FX`. In an instanced `Player.tscn`, every `Camera3D` whose `cull_mask` includes `Layers.GEM_PROBE` (the lightgem's) has `cull_mask & Layers.FX == 0`.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.**
  - Rays go from the camera to the centre and to ± `world_radius/4` along the camera's right vector, cast only while the corona is in the camera frustum (`camera.is_position_in_frustum`) and `distance_fade > 0`.
  - Visibility is eased at `delta / FADE` toward (clear rays ÷ 3). It snaps to 0 off screen or when there is no camera.
  - The ray exclude list is the player body's RID plus `exclude`.
- [ ] **Step 4: Run to verify.** Expected: L1–L14 PASS; `retro_test` still passes.
- [ ] **Step 5: Commit:** `feat(lights): Thief 3 coronas, hidden by walls and men`.

### Task 8: Embers, smoke, steam and sparks

**Files:**
- Create: `scripts/Visual/Lights/FireParticles.gd`, `smoke.gdshader`
- Modify: `scripts/Visual/Torch.gd` (emission)
- Test: `tests/lights_test.gd` (L15–L18)

**Interfaces:**
- Produces:
  - `FireParticles` (`extends Node3D`; one per level, made on first use under `tree.current_scene`, exactly like `Fx._world_for`):
    - `static func emit(context: Node, kind: StringName, at: Vector3, count: int, wind := Vector3.ZERO, tint := Color.WHITE) -> void`
    - `static func live(kind: StringName) -> int`
    - `static func clear() -> void`
    - `static func world_node() -> Node`
    - `const MAX := {&"ember": 400, &"smoke": 300, &"steam": 80, &"spark": 120}`
  - Kinds:

    | Kind | Rise | Life | Behaviour |
    |---|---|---|---|
    | `ember` | 0.8–1.6 m/s | 0.6–1.2 s | drag 1.2/s, 30% wind; additive, stretched along velocity, 1–2 px wide on the 360-line grid, #FFA040 fading to #C83010 |
    | `smoke` | 0.3–0.6 m/s | 2–3 s | grows ×2.5, alpha 0.2–0.35; `smoke.gdshader` (blend mix) lights the lower half with `tint` fading upward |
    | `steam` | 0.8 m/s | 0.6 s | as smoke, white, alpha 0.4 |
    | `spark` | 2–3 m/s spread | 0.3 s | gravity 4 m/s² down, additive |

    One `MultiMeshInstance3D` per kind, on `Layers.FX`. Scaled `delta`.
  - In `Torch.gd`:
    - While lit and the camera is within 30 m, each flame point emits embers at `ember_rate` and smoke at `smoke_rate` per second, with a fractional accumulator and `rng`.
    - Embers are skipped when `embers_by_atmosphere` (a new `var`, default false) is true and `Atmosphere.of(self) != null`.
    - `flare()` also emits a burst of `12 + 8·amount` embers.

- [ ] **Step 1: Write the failing checks:**
  - **L15:** a burner with `ember_rate = 6` 3 m from the camera gives `live(&"ember")` between 3 and 12 after 2 s. Moved to 40 m and cleared, 0 after 2 s.
  - **L16:** a single smoke puff's scale grows ≥ ×2 and it is gone by 3.1 s.
  - **L17:** with an `Atmosphere` node in the scene and `embers_by_atmosphere = true`, no embers are emitted in 2 s.
  - **L18:** every `FireParticles` draw node is on `Layers.FX`. At `time_scale = 0.5` an ember rises about half as far in the same frames (0.4–0.6 of the time_scale 1 distance).
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to verify.** Expected: L1–L18 PASS; `aliveness_test` A17 still passes.
- [ ] **Step 5: Commit:** `feat(lights): embers and smoke lit from below, one MultiMesh a kind`.

### Task 9: Lit and out

**Files:**
- Modify: `scripts/Visual/Torch.gd`
- Test: `tests/lights_test.gd` (L19–L22)

**Interfaces:**
- Produces, in `Torch.gd`:
  - `signal lit_changed(lit: bool)`
  - `func light(instant := false) -> void`
  - `func put_out(how := &"snuff", instant := false) -> void`
  - `func is_lit() -> bool`
  - `var _lit_level := 1.0` (multiplies the light)
  - `var _cool := 0.0` (1 → 0 over 3 s after a douse)
  - `func _show_lit(state: StringName) -> void`: a hook (`&"lit"`, `&"out"`, `&"cooling"`), empty here; `LightFixture` overrides it.
  - Sound names (silent until Task 17): `&"ignite_torch"` for sheets torch, brazier and fire; `&"ignite"` otherwise; `&"snuff"`; `&"douse"`.
- Timings (§7.6):

  | Transition | Lit level | Effects |
  |---|---|---|
  | `light()` | 0 → 1 over 0.5 s (ease out) | flames `set_shown` 0 → 1; 8 sparks |
  | snuff | → 0 over 0.1 s | then smoke at 3/s from each flame point for 2.5 s |
  | douse | → 0 at once | 6 steam puffs; `_cool` = 1 |
  | `instant` | jumps | no effects, no sound |

  At level 0 the light's `visible = false`. `LightProbe.invalidate()` runs on every change. `lit_changed` is emitted only when `is_lit()` actually changes. Transitions are driven in `_process` from a target level, not tweens, so a new call simply retargets.

- [ ] **Step 1: Write the failing checks:**
  - **L19:** `put_out(&"snuff")`: energy ≤ 0.01 within 8 frames; one `lit_changed(false)`; smoke puffs appear. `light()`: energy back within band by 35 frames; one `lit_changed(true)`. `put_out(&"douse")`: energy 0 the next frame; `_cool` goes from 1 to < 0.05 within 3.2 s.
  - **L20:** `LightProbe.light_at` 2 m from the burner drops by ≥ 80% when put out, and returns when lit.
  - **L21 (Review Focus 4):** `light(); put_out(); light()` in one frame on a lit burner ends lit and in band after 40 frames, with zero `lit_changed` emissions (it never really went out).
  - **L22 (Review Focus 1):** `put_out(&"douse")`, then `queue_free()` the burner the next frame. Wait 4 s. The test is still running, and `FireParticles.live(&"steam")` returns to 0.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run to verify.** Expected: L1–L22 PASS. Grep the log for `SCRIPT ERROR` and `ERROR:`; expect none.
- [ ] **Step 5: Commit:** `feat(lights): lit and out, snuffed and doused`.

### Task 10: The shadow budget, and gameplay keeping its shadows

**Files:**
- Create: `scripts/Visual/Lights/LightBudget.gd`
- Modify: `scripts/StimuliSystem/LightProbe.gd` (the `if light.shadow_enabled:` line), `scripts/Visual/Torch.gd` (register when `shadows`)
- Test: `tests/lights_test.gd` (L23–L27)

**Interfaces:**
- Produces:
  - `LightBudget` (`extends Node`, one per level like `FireParticles`):
    - `const SHADOWS := 6`, `const NEAR := 12.0`, `const EVERY := 0.25`
    - `static func register(burner: Node3D) -> void`, `static func unregister(burner: Node3D) -> void`
    - `static func shadowed() -> int`
    - `static var warned := false`
  - Rule:
    - Every `EVERY` s, the lit registered burners are sorted by distance to the camera; the nearest `SHADOWS` want shadows.
    - A light switches only while its distance is > max(`NEAR`, `light_range + 1`).
    - If more than `SHADOWS` want shadows within `NEAR`, it pushes one warning per level.
    - With no camera, nothing changes.
  - `LightProbe`: `if light.get_meta(&"casts_shadow", light.shadow_enabled):`.

- [ ] **Step 1: Write the failing checks:**
  - **L23:** 10 shadowed burners on a line 2 m apart starting 14 m from the camera give `shadowed() <= 6` after 1 s. Moving the camera along the line never lets a burner within max(12, range + 1) change its `shadow_enabled` (record per tick).
  - **L24:** a burner whose `light.shadow_enabled` was forced false, but whose `casts_shadow` meta is true, still reads dark behind a wall in `LightProbe.light_at`: within 5% of the reading with shadows on.
  - **L25:** 8 shadowed burners within 12 m of the camera set `warned` once.
  - **L26 (Review Focus 2):** build burners inside a child `Node3D` "level", then `queue_free` it and build 3 new burners elsewhere. Budget and particles work: `shadowed() == 3`, embers emitted. No errors in the log.
  - **L27 (Review Focus 3):** with the test's camera `current = false` and no other camera, a burner runs 60 frames. Its corona visibility is 0, no embers are emitted, `shadow_enabled` is unchanged, and nothing errors.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `lights_test` and `stealth_test`. Expected: all PASS.
- [ ] **Step 5: Commit:** `feat(lights): six shadows at most, never where you stand, and the guards still see by shadow`.

### Task 11: The props pipeline: build and check

**Files:**
- Create: `tools/props/common.py`, `recipes.py`, `build.py`, `check.py`, `test_check.py`
- Modify: `tools/props/props.sh` (verbs `build`, `check`, `list`, `test`)
- Create (generated, committed): `assets/props/source/wall_torch.blend`

**Interfaces:**
- Produces:
  - **`recipes.py`** (plain data):
    - `SLOTS` (the 13 slot names of §6.2), `FIXTURES: dict[str, dict]`, `KINDS = list(FIXTURES)`.
    - `def variant(base: str, **changes) -> dict` merges a copy of a base recipe.
    - Recipe keys:

      | Key | Meaning |
      |---|---|
      | `family` | `torches`, `lanterns`, `candles` or `fires` |
      | `mount` | `wall`, `floor`, `hang`, `carried` or `table` |
      | `budget` | triangle budget |
      | `parts` | list |
      | `sockets` | name → list of (x, y, z), Blender space, metres, Z up |
      | `burner` | dict of `Torch` export names → values: sheet, ramp, low_ramp, flicker_kind, flicker, energy, light_range, shadows, color hex, corona_px, ember_rate, smoke_rate, flame_size, flame_layers, core, loop, loop_db, loop_reach, event_every |
      | `soot` | bool |
      | `cookie` | bool |

  - **Part types** (each dict has `type`, `name`, `slot`, and optional `glow: bool`, `at` (x, y, z), `rotate` (deg x, y, z), `seed`):

    | Type | Parameters |
    |---|---|
    | `lathe` | `profile` [(r, z)…], `segments` |
    | `tube` | `points` [(x, y, z)…], `radius`, `sides` (4 = square bar) |
    | `box` | `size` |
    | `ring` | `radius`, `thickness`, `sides`, `segments`, `axis` |
    | `chain` | `start`, `end`, `link` (length, width, wire) |
    | `stones` | `count`, `radius`, `size`, `jitter` |
    | `logs` | `logs` [(from, to, radius)…], `sides`, with ends in slot `char` |
    | `blob` | `profile`, `segments`, `noise` (a lathe with radial noise: tow heads, wax pools, drips, coal beds) |
    | `panes` | `sides`, `radius`, `height`, `bars` (a frame of bars with panes between, panes in the part's slot) |
    | `collider` | `size` (a box exported with the `-colonly` suffix) |

  - **`common.py`:** `ROOT`, `SOURCE = ROOT/"assets/props/source"`, `OUT = ROOT/"assets/props/lights"`, `BACKUP`, `fail(msg)`, `scene_fresh()`, `tri_count(obj)`, `unwrap(obj, px_per_m=64)`, `smooth(obj, angle=40)`, `backup(path)`, `to_godot(v) -> (x, z, -y)`, `recipe_hash(recipe) -> str`.
  - **`build.py <fixture>`** writes `SOURCE/<fixture>.blend`: one mesh object per part named after it; materials named by slot (`<slot>_glow` for glow parts); one empty per socket entry named `socket:<name>:<i>`; one mesh per collider named `<name>-colonly`.
  - **`check.py <fixture>`** exits 1 listing broken rules:
    - `budget`: visible tris ≤ budget;
    - `sockets`: flames need `corona`; mount wall needs `mount`; hang needs `hang`; carried needs `grip`; every fixture has ≥ 1 `flame`;
    - `slots`: materials ⊆ SLOTS (+ `_glow`);
    - `density`: every UV-mapped face within 64 px/m ± 50% at 128 px.

- [ ] **Step 1: Write the failing tests** in `test_check.py`, run in Blender:
  - `wall_torch` builds and passes `check`.
  - Sabotaged copies of its recipe each fail exactly their rule:
    - budget 50 fails `budget`;
    - removing `corona` fails `sockets`;
    - slot `gold` fails `slots`;
    - a part scaled ×10 without re-unwrapping fails `density`.
- [ ] **Step 2: Run to verify they fail.** Run `tools/props/props.sh test`. Expected: errors.
- [ ] **Step 3: Implement** `common.py`, `build.py`, `check.py` and the `wall_torch` recipe.
  - **Plate:** a box 0.10 × 0.02 × 0.22 (iron).
  - **Arm:** a square tube from the plate's centre out 0.20 and up 0.10 (iron).
  - **Ring cup:** a ring of radius 0.045 at the arm's end (iron).
  - **Stick:** a lathe (bark) 0.55 long, r 0.022 → 0.016, through the ring, tilted 20° out from the wall.
  - **Head:** a blob (pitch, glow) r 0.04, 0.12 tall at the stick's top.
  - **Sockets:** `flame` at the head's top; `corona` 0.06 above it; `mount` at the plate's back centre.
  - **Burner:** sheet torch, ramp torch, flicker_kind torch, flicker 0.12, energy 2.4, light_range 9, shadows true, color FF9829, corona_px 48, ember_rate 6, smoke_rate 3, flame_size 0.34, loop torch_loop, loop_db −13, loop_reach 11.
  - soot true; budget 300.
- [ ] **Step 4: Run to verify.** Run `tools/props/props.sh test && tools/props/props.sh build wall_torch && tools/props/props.sh check wall_torch`. Expected: tests OK, check clean.
- [ ] **Step 5: Commit:** `feat(props): the props pipeline builds and checks, the wall torch first`.

### Task 12: Bake, export and the fixture in Godot

**Files:**
- Create: `tools/props/bake.py`, `export.py`, `preview.py`, `test_build.py`; `scripts/Visual/Lights/LightFixture.gd`, `glow.gdshader`, `Lights.gd`
- Modify: `tools/props/props.sh` (verbs `bake`, `export`, `preview`, `all`)
- Create (generated, committed): `assets/props/lights/wall_torch.glb`, `.glb.import`, `.json`
- Test: `tests/lights_test.gd` (L28–L32)

**Interfaces:**
- Consumes: `Materials.surface`, the burner.
- Produces:
  - **`bake.py <fixture>`** writes the byte colour attribute `Col` (corner domain), active for export:
    - Cycles AO (32 samples; the tests use `gpu=False`);
    - × grime: seeded noise, 0.8–1.0;
    - × soot: `1 − 0.7·exp(−d_h²/0.02)` for vertices above (flame.z − 0.05), within 0.35 m horizontally of each flame socket, where d_h is the horizontal distance.
    - It backs up before writing.
  - **`export.py <fixture>`** writes:
    - `OUT/<fixture>.glb`: `export_format="GLB"`, `export_materials="EXPORT"`, `export_image_format="NONE"`, `export_vertex_color="ACTIVE"`, `export_yup=True`, colliders included.
    - The `.glb.import` from the wardrobe's `IMPORT` template when missing.
    - `OUT/<fixture>.json`: `{"fixture", "family", "mount", "tris", "slots", "glow_parts", "sockets": {name: [[x, y, z], …] in Godot space}, "burner": {...}, "soot", "cookie", "hash"}`.
  - **`preview.py <fixture> --out=<dir>`** renders four Workbench views with vertex colours.
  - **`LightFixture.gd`** (`extends "res://scripts/Visual/Torch.gd"`):
    - `@export var fixture := &""`
    - `var model: Node3D`, `var sockets := {}` (StringName → Array[Vector3], fixture space)
    - `var glow_meshes: Array[GeometryInstance3D]`
    - `static func spec(name: StringName) -> Dictionary` (cached JSON; `{}` when missing)
    - `func socket(name: StringName, index := 0) -> Vector3`
    - `_before_ready()` does the following:
      1. reads the spec and applies `burner` to the exports, `flame_points` from `sockets.flame`, and the corona position from `sockets.corona`;
      2. instances the GLB as `model`;
      3. replaces every surface material by `Materials.surface(slot)`, or `Materials.glowing(slot)` for `<slot>_glow`;
      4. collects the glow meshes.
    - A missing spec pushes one error naming the fixture and leaves a bare burner.
    - `_show_lit(state)` sets the glow meshes' instance uniforms: `glow = light ratio` when lit, `glow = _cool` and `charred = 1 − _cool` when cooling or out.
    - The soot decal: if `soot` and `mount == "wall"`, a `Decal` with `soot.png`, 0.5 × 0.9 m (Y), centred 0.4 m above the flame, pushed into the wall along −normal, `cull_mask = Layers.WORLD_ALL`, extending up to the ceiling found by one ray up within 1.2 m.
  - **`Materials.glowing(slot: StringName) -> ShaderMaterial`** (added to `Materials.gd`): `glow.gdshader` with the slot's photo or colour, vertex colour, `instance uniform float glow; instance uniform float charred; instance uniform vec4 heat_tint`, emission = `heat_tint × glow × 2.0`, albedo mixed toward #1C1714 by `charred`, filter nearest.
  - **`Lights.gd`** (`extends RefCounted`, static):
    - `static func make(parent: Node, fixture: StringName, at: Vector3, yaw := 0.0, overrides := {}) -> Node3D`: builds a `LightFixture` placed so its origin is `at`, sets overrides (export name → value), adds it, returns it.
    - `static func wall_torch(parent: Node, flame_at: Vector3, wall_normal: Vector3, overrides := {}) -> Node3D`: origin = `flame_at − (flame socket in wall space)`, yawed to face `wall_normal`.

- [ ] **Step 1: Write the failing tests.**
  - Blender (`test_build.py`): rebuilding `wall_torch` gives the same `recipe_hash`; after `bake`, the mean `Col` luminance of vertices above the flame socket is < 0.8 × that of vertices below it.
  - Godot:
    - **L28:** `Lights.wall_torch(self, Vector3(0, 2.5, -3.8), Vector3(0, 0, 1))` against a wall block gives a `LightFixture` with 1 flame point, its light within 1 cm of flame + (0, 0.12, 0), and `socket(&"mount")` within 3 cm of the wall face.
    - **L29:** every model surface's material is `Materials.surface(slot)` or a glowing `ShaderMaterial`; the imported mesh has `Mesh.ARRAY_COLOR` data.
    - **L30:** one `Decal` child with `cull_mask == Layers.WORLD_ALL`, its centre above the flame.
    - **L31:** `put_out(&"douse", false)`: the glow mesh's `charred` rises to ≥ 0.95 within 3.2 s.
    - **L32:** `Lights.make(self, &"no_such_fixture", …)` gives a burner with 1 flame at its origin and a light (the error is expected in the log).
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.** Then run `tools/props/props.sh bake wall_torch && tools/props/props.sh export wall_torch && $GODOT --headless --path . --import`.
- [ ] **Step 4: Run to verify.** Expected: `props.sh test` OK; `lights_test` L1–L32 PASS.
- [ ] **Step 5: Look** at `props.sh preview wall_torch --out=$TMPDIR/prev`: iron reads as iron, the head sits in the ring, soot shows on the arm.
- [ ] **Step 6: Commit:** `feat(props): bake and export; LightFixture puts the model on the burner`.

### Task 13: The torch family and `torch_at`

**Files:**
- Modify: `tools/props/recipes.py`, `scripts/Visual/Lights/Lights.gd`
- Create (generated): `carried_torch`, `cresset_pole`, `cresset_wall` (`.blend`, `.glb`, `.json`)
- Test: `tests/lights_test.gd` (L33–L34)

**Interfaces:**
- Produces:
  - **Recipes** (§8.1 budgets):

    | Recipe | Model | Sockets | Burner and extras |
    |---|---|---|---|
    | `carried_torch` | stick 0.56 m, r 0.026 → 0.021; head as `wall_torch` | origin at the flame socket; `grip` 0.36 below it | energy 2.1, light_range 7.5, shadows false, flicker 0.22, flame_size 0.3; budget 120 |
    | `cresset_pole` | a 2.4 m square iron pole on a three-foot base (0.4 spread); a 6-bar basket r 0.16, 0.22 tall; a pitch-rope blob (glow) inside | `flame` 0.05 below the basket top; `mount` at the foot | sheet fire, ramp fire, flicker_kind cresset, flicker 0.12, energy 2.8, light_range 10, shadows true, flame_size 0.55, ember_rate 10, smoke_rate 5, loop fire_small, loop_db −12, loop_reach 12, corona_px 60; budget 600 |
    | `cresset_wall` | the basket on a 0.45 m bracket | `mount` | soot true |

  - **`Lights.gd`:**
    - `static func carried_torch() -> Node3D`: a `LightFixture` not added to any parent; origin = flame.
    - `static func cresset(parent, at, variant := &"pole", yaw := 0.0, overrides := {}) -> Node3D`: pole = `at` is the foot; wall = `at` is the mount.
    - `static func torch_at(parent: Node, flame_at: Vector3, energy := 2.4, light_range := 9.0, shadows := true) -> Node3D`: returns at once a bare burner at `flame_at` with those values (the light is live immediately). On its first physics tick it resolves its form:
      1. Cast 8 horizontal rays from `flame_at` out to 0.5 m with mask 1, accepting only `StaticBody3D` hits that are not in groups `doors` or `guards`, and not an `AnimatableBody3D`. The nearest hit gives `wall_torch(parent, flame_at, normal, same values)`.
      2. Else a ray down within 3.2 m hitting a `StaticBody3D` gives `cresset(parent, floor_point, &"pole")` with the pole scaled so the flame lands at `flame_at`.
      3. Else it stays bare and pushes one warning with the position.

      The bare burner is freed once the fixture exists; energy, range and shadows carry over.

- [ ] **Step 1: Write the failing checks:**
  - **L33a:** `torch_at` 0.3 m from a wall becomes a `wall_torch` fixture within 3 frames.
  - **L33b:** in the open, 2.6 m above a floor, it becomes a `cresset_pole` whose flame is within 3 cm of `flame_at`.
  - **L33c:** 5 m above nothing, it stays a bare burner, with the warning.
  - **L33d (Review Focus 5):** 0.3 m from a `Props.door` (and, separately, from a guard) with no wall, it does not become a `wall_torch` on it; it becomes a cresset or stays bare.
  - **L33e:** the light's energy is never 0 across the switch-over.
  - **L34:** `carried_torch()` has `socket(&"flame") == Vector3.ZERO` and `socket(&"grip").y` ≈ −0.36.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.** Then run `props.sh all` for the three recipes and re-import.
- [ ] **Step 4: Run to verify.** Expected: L1–L34 PASS; `props.sh check` clean.
- [ ] **Step 5: Commit:** `feat(lights): carried torch, cressets, and torch_at finding its wall`.

### Task 14: Lanterns and lamps

**Files:**
- Modify: `tools/props/recipes.py`, `tools/props/flames.py` (verb `cookie`), `tools/props/props.sh`, `scripts/Visual/Lights/LightFixture.gd`, `Lights.gd`
- Create (generated): `carried_lantern`, `hanging_lantern`, `wall_lantern`, `lamp_post`; `assets/vfx/cookie_lantern.png`
- Test: `tests/lights_test.gd` (L35–L36)

**Interfaces:**
- Produces:
  - **Recipes.** All use sheet small, ramp lamp, low_ramp gutter, flicker_kind lamp, flicker 0.05, color FFA645, corona_px 28, ember_rate 0, smoke_rate 0, loop "". Horn panes are slot `horn`, glow.

    | Recipe | Model | Sockets | Burner and extras |
    |---|---|---|---|
    | `carried_lantern` | 8-sided `panes` r 0.075 × 0.2 in iron bars; domed vented roof 0.06; base 0.025; bail tube up 0.13 | origin at the flame (the body's centre); `hang` at the bail top | energy 1.5, light_range 6.5, shadows false, corona_px 28; budget 400 |
    | `hanging_lantern` | 1.5× the carried lantern | `hang` at the ring on top | energy 1.4, light_range 7, shadows true, cookie true; budget 500 (lantern only; the chain is added by the builder) |
    | `wall_lantern` | a square box lantern 0.16 × 0.26 on a 0.3 m bracket | `mount` | energy 1.2, light_range 6, shadows false, soot true; budget 450 |
    | `lamp_post` | a 2.8 m timber post 0.12 square (`wood_old`); a crook arm (iron) 0.6 m out at 2.6 m; the hanging lantern's parts hung from it | `mount` at the foot | energy 1.6, light_range 9, shadows true, cookie true; budget 700 |

  - **`props.sh cookie`** renders `cookie_lantern.png`: Cycles, CPU, a panoramic equirectangular camera at `hanging_lantern`'s flame socket, the frame and roof as black holdouts, a white world, 512×256, greyscale.
  - **`LightFixture`**: when `cookie`, it sets `light.light_projector = preload("res://assets/vfx/cookie_lantern.png")`.
    - For mount `hang`, the model sits under a `Hanging` node at the hook. `lean` feeds the swing: each tick it adds `lean × 0.8` rad/s² to `Hanging._spin`, using `Hanging`'s existing fields.
  - **`Lights.gd`:**
    - `carried_lantern() -> Node3D`
    - `hanging_lantern(parent, hook_at: Vector3, chain := 0.6) -> Node3D`. The chain is a `chain` part per fixture, from a shared `chain_link.glb` exported by the pipeline as recipe `chain_link`, budget 40, repeated along the length.
    - `wall_lantern(parent, mount_at, wall_normal)`
    - `lamp_post(parent, foot_at, yaw := 0.0)`

- [ ] **Step 1: Write the failing checks:**
  - **L35:** a `hanging_lantern` has a non-null `light_projector` and `shadow_enabled`. With `lean(Vector3(1, 0, 0))` for 2 s, its model tilts > 0.05 rad from vertical.
  - **L36:** a `carried_lantern` has no projector and no shadows. A `lamp_post` has the projector and its flame is between 2.2 and 2.6 m above its foot.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.** Run `props.sh all` for the new recipes, then `props.sh cookie`, then re-import.
- [ ] **Step 4: Run to verify.** Expected: L1–L36 PASS; check clean.
- [ ] **Step 5: Commit:** `feat(lights): horn lanterns, the hanging lantern's bars on the walls, lamp posts`.

### Task 15: Candles, oil lamps and drafts

**Files:**
- Modify: `tools/props/recipes.py`, `scripts/Visual/Torch.gd` (`draft()`), `scripts/Visual/Lights/LightFixture.gd`, `Lights.gd`
- Create (generated): `candle_6`, `candle_10`, `candle_16`, `candlestick_iron`, `candlestick_brass`, `candelabra_3`, `candelabra_5`, `chandelier_6`, `chandelier_8`, `oil_lamp_clay`, `oil_lamp_hanging`
- Test: `tests/lights_test.gd` (L37–L38)

**Interfaces:**
- Produces:
  - **Recipes.** Candles: sheet candle, ramp candle, low_ramp gutter, flicker_kind candle, flicker 0.04. Every recipe in this task: color FFA645, ember_rate 0, smoke_rate 0, loop "". The candles on sticks, candelabra and chandeliers use `flame_layers` 1 and `core` false, with one flame socket per candle.

    | Recipe | Model | Burner | Budget |
    |---|---|---|---|
    | `candle_6`, `candle_10`, `candle_16` | a tallow lathe r 0.02 of that height (cm), a drip blob and a wax pool (`wax`); flame 0.012 above the top | energy 0.35, light_range 2.5, shadows false, corona_px 12, flame_size 0.05 | 60 |
    | `candlestick_iron` | a pricket: dish r 0.07, stem 0.18, drip pan, spike; a 10 cm candle | as candle | 150 |
    | `candlestick_brass` | a lathe socket stick 0.2 m (`brass`); a 10 cm candle | as candle | 150 |
    | `candelabra_3`, `candelabra_5` | brass base r 0.09, stem 0.3, arms spread 0.12 / 0.22 with cups | energy 0.9, light_range 4.5, corona_px 20 | 450 |
    | `chandelier_6`, `chandelier_8` | an iron band hoop r 0.35, cups, 3 chains 0.5 m to a ring; `hang` at the ring | energy 1.6, light_range 8, shadows true, corona_px 36 | 900 |
    | `oil_lamp_clay` | a 0.12 m bowl with a spout and handle (`clay`); flame at the spout | sheet small, ramp lamp, low_ramp gutter, flicker_kind lamp, flicker 0.04, energy 0.5, light_range 3, corona_px 16, flame_size 0.06 | 120 |
    | `oil_lamp_hanging` | a brass bowl on 3 chains 0.3 m | as `oil_lamp_clay` | 120 |

  - **Distance fade:** candles and oil lamps set `light.distance_fade_enabled`, begin 20 m, length 5 m, and fade the corona by the same distance.
  - **`Torch.draft()`** restarts the draft clock. For `flicker_kind == candle`, `v = Flicker.draft(since)`.
  - **Draft detection** (`LightFixture`, family candles only, every 0.25 s): a member of `player` or `guards` within 1.5 m with horizontal speed > 3 m/s, or a member of `doors` within 3 m whose `rotation.y` changed by > 0.02 rad since the last look, calls `draft()`.
  - **`Lights.gd`:** `candle(parent, at, height := 10)`, `candlestick(parent, at, variant := &"iron")`, `candelabra(parent, at, arms := 3)`, `chandelier(parent, hook_at, candles := 6, chain := 1.0)`, `oil_lamp(parent, at, variant := &"clay")`.

- [ ] **Step 1: Write the failing checks:**
  - **L37:** a `candelabra_5` has exactly 1 `OmniLight3D`, 5 `FlameFx` each with 1 sprite and no core, and 1 `Corona`. A lone `candle_10` has light energy constant (±0.001) over 120 frames.
  - **L38:** a `Props.door` 2 m away swung open (drive its angle directly as `interaction_test` does) makes the candle's energy vary by > 1% within 0.5 s and settle back within 1.5 s. A guard walked past at 4 m/s within 1 m does the same.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement,** then `props.sh all` for the new recipes, then re-import.
- [ ] **Step 4: Run to verify.** Expected: L1–L38 PASS; check clean.
- [ ] **Step 5: Commit:** `feat(lights): candles, candelabra, chandeliers, oil lamps, and the draft`.

### Task 16: Open fires

**Files:**
- Create: `scripts/Visual/Lights/haze.gdshader`
- Modify: `tools/props/recipes.py`, `scripts/Visual/Torch.gd` (events), `scripts/Visual/Lights/LightFixture.gd` (haze), `Lights.gd`
- Create (generated): `brazier`, `campfire`, `hearth`
- Test: `tests/lights_test.gd` (L39–L41)

**Interfaces:**
- Produces:
  - **Recipes:**

    | Recipe | Model | Burner and extras | Budget |
    |---|---|---|---|
    | `brazier` | a tripod of 3 iron legs 0.9 m; bowl r 0.42 top, 0.18 bottom, 0.3 high at 0.8–1.1 m (today's dimensions); a coal-bed blob (`coal`, glow); flame socket at 1.35 m | sheet brazier, ramp brazier, flicker_kind brazier, flicker 0.12, energy 2.6, light_range 8, shadows true, flame_size 0.8, corona_px 72, ember_rate 15, smoke_rate 6, loop fire_medium, loop_db −11, loop_reach 14, event_every (15, 30) | 700 |
    | `campfire` | 8 stones (`stone`) on r 0.3; 5 crossed logs (`bark`, char ends); an ember bed (`coal`, glow); flame at 0.22 m | sheet fire, ramp fire, flicker_kind fire, flicker 0.18, energy 2.2, light_range 7, shadows true, flame_size 0.5, corona_px 72, ember_rate 20, smoke_rate 6, loop fire_medium, loop_db −11, loop_reach 14, event_every (20, 40) | 600 |
    | `hearth` | `ashlar` masonry 1.6 m wide: an opening 1.0 × 0.8 m, depth 0.6, a hood rising to 2.4 m, a chimney breast to 3.0 m; firedogs (iron); 3 logs; colliders for both sides, the back, the hood and the breast; flame at 0.3 m | as campfire but energy 2.6, light_range 9, loop fire_big, loop_db −14, smoke_rate 4 | 1,500 |

  - **Events (`Torch.gd`):** when `event_every != Vector2.ZERO`, `rng` draws the next event time in that range.
    - An event sets `_jump = 1`, easing to 0 over 1.5 s (flames only; the light formula does not include `_jump`).
    - It bursts 16 embers.
    - It plays `&"log_settle"` for flicker_kind fire and `&"coal_pop"` for brazier (silent until Task 17).
  - **Doused coals:** after `put_out(&"douse")`, family fires emit 3–5 embers spread over the next 20 s from the coal bed (§7.6), then none.
  - **Haze:** fixtures of family fires get a `MeshInstance3D` quad 0.6 × 0.9 m above the flame, `haze.gdshader` (`hint_screen_texture`, UV offset by 1/360 × scrolling noise, `unshaded`, `blend_mix`, `depth_draw_never`, on `Layers.FX`), shown only within 15 m of the camera.
  - **`Lights.gd`:** `brazier(parent, at) -> Node3D`, `campfire(parent, at) -> Node3D`, `hearth(parent, at, yaw := 0.0) -> Node3D`.

- [ ] **Step 1: Write the failing checks:**
  - **L39:** a campfire's haze is visible 5 m from the camera and hidden at 20 m.
  - **L40:** a campfire with `event_every = Vector2(0.5, 0.6)`, sampled every frame for 20 s, keeps its light within `energy × (1 ± flicker)`, while `_jump` peaks above 0.9 at least 10 times.
  - **L40b:** a doused brazier emits between 3 and 5 embers over the next 20 s and none in the 10 s after.
  - **L41:** the hearth imports ≥ 4 `StaticBody3D` colliders, and a ray aimed at its hood hits one.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement,** then `props.sh all` for the three recipes, then re-import.
- [ ] **Step 4: Run to verify.** Expected: L1–L41 PASS; check clean.
- [ ] **Step 5: Commit:** `feat(lights): brazier, campfire and hearth, with surges, settling logs and haze`.

### Task 17: The sounds

**Files:**
- Modify: `tools/prepare_sfx.py`, `scripts/Audio/Sfx.gd` (`GAIN`), `CREDITS.md`
- Create (generated): `audio/ambience/{fire_small,fire_medium,fire_big,chimney}.ogg`; `audio/sfx/{crackle,coal_pop,log_settle,ignite_torch,snuff,douse,lantern_creak,bail_rattle}_N.wav`

**Interfaces:**
- Produces:
  - **`prepare_sfx.py` additions:**
    - `NOX = ~/Downloads/Essentials_Series_NOX_SOUND/Nature_Essentials_NOX_SOUND/`, `FOUR_HUNDRED = ~/Downloads/400 Sounds Pack/`, `FILMCOW = ~/Downloads/FilmCow Recorded SFX/`.
    - A `FIRE_LOOPS` list of `(name, source, start, end, lowpass_hz or None, pitch)`, made mono, 44.1 kHz, with a 1.5 s equal-power crossfade (`make_loop` on mono), peak-normalised to −3 dB, written as OGG (`ffmpeg -c:a libvorbis -q:a 5`) to `audio/ambience/`:

      | Name | Source | Start–end | Low-pass | Pitch |
      |---|---|---|---|---|
      | `fire_small` | NOX `Ambiance_Firecamp_Small_Loop_Mono.wav` | 0–20 s | none | 1.0 |
      | `fire_medium` | NOX `Ambiance_Firecamp_Medium_Loop_Mono.wav` | 0–20 s | none | 1.0 |
      | `fire_big` | NOX `Ambiance_Fire_Big_Loop_Mono.wav` | 0–20 s | 5000 Hz | 1.0 |
      | `chimney` | NOX `Ambiance_Wind_Calm_Loop_Stereo.wav` | 0–20 s | 900 Hz | 0.7 |

    - `crackle` and `coal_pop` join `VOICES` as `"split"` entries: crackle 6 takes from the NOX medium and small loops; coal_pop 4 takes from `fire_big`'s source.
    - A `LAYERED` list of `(name, [(source, start, end, gain_db, offset_s, lowpass_hz)…], fade_out)`: each layer is decoded, filtered (ffmpeg `lowpass`), offset and summed, then goes through the same peak and group-matching path as `SOUNDS`:

      | Sound | Layers |
      |---|---|
      | `ignite_torch_1/2` | TomMusic `Torch/Light Torch with Starting Loop {1,2}.wav` (0–1.4 s) + `400 Sounds Pack/Environment/fire_lighting.wav` (−6 dB) |
      | `snuff_1/2` | `400 Sounds Pack/Environment/air_burst.wav` (first 0.15 s) + FilmCow `gas leak.wav` tail (0.4 s, −10 dB, low-pass 6 kHz) |
      | `douse_1/2` | `400 Sounds Pack/Environment/water_splashing.wav` (0–0.5 s) + FilmCow `gas leak.wav` (0.9 s, −4 dB) |
      | `log_settle_1..3` | FilmCow `footstep on branch heavy.wav` + Kenney RPG `chop.ogg` (−8 dB, low-pass 2 kHz) |
      | `lantern_creak_1..3` | Kenney RPG `creak1-3.ogg` pitched ×1.3 + FilmCow `metal latch` takes (−10 dB) |
      | `bail_rattle_1..4` | FilmCow `chain` takes, auto-bounded, ≤ 0.25 s |

  - **`Sfx.GAIN` entries** are target minus measured LUFS (printed by the script), capped at +4. Targets: crackle −30, coal_pop −28, log_settle −26, ignite_torch −24, snuff −32, douse −24, lantern_creak −30, bail_rattle −30.
  - **`CREDITS.md`**: NOX (CC0); 400 Sounds Pack and FilmCow (approved by the user 2026-09-27); plus the existing Kenney line if its files are reused.

- [ ] **Step 1: Find the existing loudness check.** Run `grep -n "D26b" tests/*.gd` to find the check that every `GAIN` name is a mono 44.1 kHz recording with a gain. Adding the new names to `GAIN` first makes it fail. Run that suite: expect FAIL on the new names.
- [ ] **Step 2: Implement.** Run `python3 tools/prepare_sfx.py --only=crackle,coal_pop,log_settle,ignite_torch,snuff,douse,lantern_creak,bail_rattle`, then the fire loops step (the `FIRE_LOOPS` pass runs in a full run; add `--fire` to run only it), then `$GODOT --headless --path . --import`.
- [ ] **Step 3: Verify** with `ffprobe` that each new file is 44.1 kHz mono. Run that suite again: expect PASS. Also run `sound_test`: expect PASS.
- [ ] **Step 4: Commit:** `feat(sound): fire beds, crackles, lighting, snuffing and dousing from the user's packs`.

### Task 18: Fixture sounds wired

**Files:**
- Modify: `scripts/Visual/Torch.gd` (crackles, transition sounds), `scripts/Visual/Lights/LightFixture.gd` (creak, the hearth's chimney loop), `scripts/AISystem/GuardRig.gd` (bail rattle, at the step at line ~622)
- Test: `tests/lights_test.gd` (L42–L44)

**Interfaces:**
- Produces:
  - **Loops.** The burner loads `loop_path` from `res://audio/ambience/<loop>.ogg` when the recipe's `loop` is a name. Fixtures with `loop` "" have no loop player.
  - **Crackles.** While the loop plays, the next crackle time is drawn from `rng` as exponential with rate `{torch: 0.6, cresset: 0.8, brazier: 1.0, fire: 1.0}[flicker_kind]` (/s; hearth 0.5 via a recipe override `crackle_rate`). It plays `Sfx.play(self, crackle or coal_pop (40% for brazier and fire), flame, 0.0)`.
  - **The chimney loop** (hearth only) is a second `AudioStreamPlayer3D` at the hood's top, −20 dB, same reach.
  - **Lantern creak.** Mount hang: when `Hanging`'s swing speed passes 0.6 rad/s (rising edge), play `lantern_creak`, at most every 0.8 s.
  - **Bail rattle.** In `GuardRig`, right after the step sound: if `guard._hands.light_kind == &"lantern"` and a new per-rig step counter is even, `Sfx.play(guard, &"bail_rattle", lantern position, Sfx.loudness(30.0))`.

- [ ] **Step 1: Write the failing checks** (with `Sfx.enabled = true` and `Sfx.recording = true`, reading `Sfx.recorded` as `sound_test` does):
  - **L42:** a campfire 3 m from the camera has its loop playing on `World` with the `fire_medium` stream. At 20 m it stops. Behind a sealed box its cutoff is `Sfx.OCCLUDED_CUTOFF`.
  - **L43:** over 60 s of recorded crackles from a brazier, there are 40–80 events, and the coefficient of variation of the intervals is > 0.6 (irregular, never on a grid).
  - **L44:** a hanging lantern pushed by `lean(Vector3(3, 0, 0))` records ≥ 1 `lantern_creak`. A guard carrying a lantern walking 10 steps records 4–6 `bail_rattle`.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `lights_test` and `sound_test`. Expected: all PASS.
- [ ] **Step 5: Commit:** `feat(sound): fires crackle at random, lanterns creak and rattle`.

### Task 19: Guards, brazier and campfire switched over

**Files:**
- Modify: `scripts/AISystem/GuardHands.gd` (`_hang_lantern`, `_torch`), `scripts/Combat/Fire.gd` (`brazier`), `scripts/Interaction/Furnishings.gd` (`campfire`)
- Test: `tests/lights_test.gd` (L45–L46)

**Interfaces:**
- Consumes: `Lights.carried_lantern()`, `Lights.carried_torch()`, `Lights.brazier()`, `Lights.campfire()`.
- Produces:
  - **`_hang_lantern(bone, size, flicker)`** builds `Lights.carried_lantern()`, sets `energy = LANTERN_ENERGY`, `light_range = LANTERN_RANGE` and `flicker`, and keeps the grip, `Hanging` (length `LANTERN_HANG`) and return value. `size` sets `flame_size`.
  - **`_torch()`** returns `Lights.carried_torch()` with `TORCH_ENERGY` and `TORCH_RANGE`, attached exactly as today.
  - **`drop_lantern`** is unchanged; its tween of `energy` works because the fixture is a burner.
  - **`Fire.brazier(parent, position)`** keeps its `StaticBody3D` stand collider, metadata and the `Fire` area. It replaces the cylinder meshes and the `TorchScript` with `Lights.brazier(stand, Vector3.ZERO)`, sets `fire.torch` to it and `embers_by_atmosphere = true`.
  - **`Furnishings.campfire`** keeps its body, collider and idle spots. It replaces the stone and log parts and the `Torch` with `Lights.campfire(body, Vector3.ZERO)`; the spots' `fire` meta points at the fixture.

- [ ] **Step 1: Write the failing checks:**
  - **L45:** a guard given `carry_light(&"lantern")` holds a `LightFixture` whose `fixture == &"carried_lantern"` under a `Hanging`. `carry_light(&"torch")` holds `&"carried_torch"`. `drop_lantern()` leaves a `dropped_lights` body whose light dims to 0 after `DROPPED_LIGHT_TIME + 3` s.
  - **L46:** a guard pushed into `Fire.brazier` catches fire (the arena test's way of doing it).
  - **L3** must still pass: probe baselines within 10%.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `lights_test`, `habits_test`, `routines_test`, `aliveness_test`, `arena_test`, `combat_test`, `life_test`, `showcase_test`. Expected: all PASS.
- [ ] **Step 5: Commit:** `feat(lights): the guards carry the new lantern and torch; the brazier and campfire rebuilt`.

### Task 20: The maps

**Files:**
- Modify: `maps/retro_showcase.gd`, `maps/stealth_gym.gd`, `maps/combat_gym.gd`, `maps/combat_arena.gd`, `maps/npc_gym.gd`, `maps/npc_showcase.gd`
- Test: `tests/lights_test.gd` (L47)

**Interfaces:**
- Consumes: `Lights.torch_at`.
- Produces: each map's own `_torch(at, …)` body becomes one `Lights.torch_at(self, at, energy, light_range, shadows)` call with the values it passed before. In `retro_showcase` the loop calls `Lights.torch_at(self, at)` and `_bracket(at)` is deleted, along with the function if it has no other callers.

- [ ] **Step 1: Write the failing check.** **L47:** load each of the six maps in turn (instantiate, 120 frames, count, free, 10 frames). Every burner under the map is a `LightFixture` (wall torch, cresset, brazier or campfire); zero stay bare (no `torch_at` warning). Before the change: FAIL (bare `Torch` nodes).
- [ ] **Step 2: Implement.** Where a spot resolves bare (a torch hanging in the air), change that one call to an explicit fixture that fits the place (a `cresset_wall` on the nearest pillar, or a `hanging_lantern`), and note it in the commit message.
- [ ] **Step 3: Run** `lights_test`, `retro_test` (R8 counts ≥ 5 torch lights), `stealth_test`, `combat_test`, `arena_test`, `showcase_test`, `stations_test`, `gym_test`. Expected: all PASS.
- [ ] **Step 4: Commit:** `feat(lights): every map's torches in sconces and cressets`.

### Task 21: The lights gallery

**Files:**
- Create: `maps/lights_gallery.gd`, `maps/lights_gallery.tscn`
- Test: `tests/lights_test.gd` (L48)

**Interfaces:**
- Produces: a stone hall 40 × 12 × 6 m in the `retro_showcase` style (built in code from `Props.block`, `Retro.night_environment()`, `NavBaker`, the player at the entrance).
  - **Four bays**, each lit only by its own family:
    - torches: wall torch ×2, cresset pole, cresset wall;
    - lanterns: hanging lantern, wall lantern, lamp post;
    - candles: every candle, candlestick, candelabra, chandelier and oil lamp variant on a table (`Props.block`);
    - fires: brazier, campfire, hearth set into the end wall.
  - **In each bay:** a pillar between two lights (for coronas); a `Props.door` that swings every 6 s on a timer (for drafts); one guard with a lantern and one with a torch on a two-point patrol.
  - **Keys** (debug builds, `_unhandled_input`):
    - L cycles every burner lit → snuffed → lit → doused → lit;
    - K sets wind off / gentle (0.4) / strong (1.0) from +X, calling `lean` on every node in `torches`;
    - J toggles coronas;
    - H sets `set_strength` to 1 → 0.3 → 1 on the fires.
  - A sign per bay (the `_sign` pattern) lists the keys.
  - With `--verbose` after `--`, it prints frame time every 5 s and, once at start, `Materials.fallbacks()` (§12).

- [ ] **Step 1: Write the failing check.** **L48:** instantiate the gallery; after 180 frames every fixture with a JSON in `res://assets/props/lights/` (except `chain_link`; the carried ones on the guards) appears among its `LightFixture` nodes, all lit. Calling the gallery's `cycle_lights()` (the L key's handler) once leaves them all out; three more calls leave them all lit.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** `lights_test`. Expected: L1–L48 PASS. Open the gallery windowed: `$GODOT --path . res://maps/lights_gallery.tscn`. It runs, and the four bays are lit and readable.
- [ ] **Step 4: Commit:** `feat(lights): the lights gallery`.

### Task 22: The stager and the review sheet

**Files:**
- Create: `tests/visual/stage_lights.gd`, `tests/visual/stage_lights.tscn`

**Interfaces:**
- Produces:
  - A windowed stager in the `stage_look.gd` style (`--out=<dir>`, `Sfx.volume_db = -60`). It loads `lights_gallery` and, for each fixture, frames it at 1, 3 and 8 m, lit and then out (instant), taking one screenshot each through the Retro pass. It also takes one wide shot per bay.
  - It assembles `sheet.png`: labelled rows per fixture, with Pillow via a `python3` call (or Godot `Image.blit_rect`).
  - It logs frame time per bay, and the lightgem reading for a player standing 2 m from a wall torch, the brazier and the campfire.
- Run: `perl -e 'alarm 600; exec @ARGV' $GODOT --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_lights.tscn -- --out=$TMPDIR/lights_shots`

- [ ] **Step 1: Capture main's baseline.** The stager's `--gem-only` mode builds a floor, a bare `Torch.new()`, `Fire.brazier` and `Furnishings.campfire` 20 m apart, then puts an instanced `Player.tscn` 2 m from each flame in turn (burner `flicker = 0`) and logs `player.get_light_level()` after 60 frames. It uses only APIs that exist on main.
  1. `git worktree add $TMPDIR/main-gem main` and copy `stage_lights.gd/.tscn` into it (untracked).
  2. Run `--gem-only` there after `--import`.
  3. Write the three numbers into the stager as `MAIN_GEM`.
  4. `git worktree remove --force $TMPDIR/main-gem`.
- [ ] **Step 2: Implement and run.** Expected: the sheet exists, and every gem reading is within 10% of `MAIN_GEM` (logged as PASS or FAIL lines).
- [ ] **Step 3: Look at the sheet.** Check each item:
  - flames read as fire at 3 m and 8 m;
  - coronas sit on the flames;
  - out states read (charred heads, dark coals);
  - soot shows above wall fixtures;
  - no sprite shows on the lightgem.

  Fix what reads wrong before handing over.
- [ ] **Step 4: Commit:** `test(lights): the lights stager and its review sheet`.

### Task 23: Full verification and hand-over

**Files:** none new.

- [ ] **Step 1:** Run `python3 -m unittest tools/textures/test_ps2ify.py tools/props/test_sheets.py -v`. Expected: all OK.
- [ ] **Step 2:** Run `tools/props/props.sh test && for f in $(tools/props/props.sh list); do tools/props/props.sh check $f; done`. Expected: all OK, all clean.
- [ ] **Step 3:** Run `tools/run_suites.sh`. Expected: every suite PASS, with none missing results and no `SCRIPT ERROR`. Any failure also failing on main (Task 2's record) is noted, not fixed here.
- [ ] **Step 4:** Check `git status --ignored` shows `textures/ps2/` and `textures/source/` ignored. Check `git log -p lights-and-fire --not main -- textures` shows no photo-derived file.
- [ ] **Step 5:** Send the user:
  - the stager's `sheet.png`;
  - the `props.sh preview all` sheets;
  - the gallery command;
  - the list of new sounds to audition;
  - any spots in the maps changed from `torch_at` by hand.

  Update the memory note `look-and-sound-polish-program.md` with the state.
