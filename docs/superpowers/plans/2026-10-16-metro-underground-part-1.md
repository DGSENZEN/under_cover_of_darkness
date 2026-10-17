# Metro Underground, part 1: the new standard, the hero stall and the layout

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two things. First, turn off the pixel grid and set the new standard for models and textures by building one hero piece, a corridor stall with its neon sign, until the user approves it, then write that recipe down. Second, re-plan the Underground under the Zócalo as its own 20-minute greybox map, which the user approves by walking it.

**Architecture:** There are two independent tracks.

- **Track A (Tasks 1-11)** extends the existing Eclipse kit pipeline (`tools/eclipse/common.py` → `export_piece`) with bevels and per-kit budgets. It adds a new layered atlas painter beside `eclipse_atlas.py`, fed by the user's brush sheets, plus a `&"bespoke"` shader preset, a neon material and a look-dev bay `maps/underground_lab`.
- **Track B (Tasks 12-16)** adds a standalone map to the existing plan → greybox pipeline (`tools/level/`): a `metro` layout, plan-check rules for a map with no street, a sheet for each depth band, and `maps/metro`.

Neither track depends on the other.

**Tech Stack:**
- Blender 5.x Python (headless for builds, plus the live Blender MCP session for iterating and renders)
- Python 3 with numpy and PIL (painter, plan tools; `unittest`)
- Godot 4 GDScript (maps, shader preset, suites)

**Spec:** `docs/superpowers/specs/2026-10-16-metro-underground-design.md`

**What is not in this plan.** Two later plans follow, written once this one's gates pass:

- **Part 2:** the orange car, the ride scene and hidden loads. This covers threaded loading and the gate kinds in `Districts`/`CityState`. It also cuts the old station out of the Zócalo's plan, reconciles the kiosk's 3 m stair with the 8 m drop, wires the Zócalo's kiosks to `maps/metro`, and loads the Zócalo during the exit climb.
- **Part 3 onward:** the Underground's model sets, in the order the approved layout dictates, including the ambient creatures.

Both depend on this plan's two user gates: the recipe (Task 11) and the layout (Task 16).

## Global Constraints

- The pixel-grid screen is turned off (user). Past the PS2 limits: the old triangle budgets and nearest-filtered textures no longer bind.
- The user's brush sheets are `~/Downloads/Texture_Abstract00.png` … `Texture_Abstract04.png`; sheet 01 is `Texture_Abstract01 .png`, with a space. **The raw sheets stay out of the public repo.** Textures painted with them are self-made and committed.
- Every model is a closed, solid mesh with no layered quads. It must pass `tools/eclipse/gate.py`: the 3 cm layered gate (`LAYER_GAP = 0.03`), no coplanar fights, no slivers (`SLIVER = 0.01` m), and no degenerate faces.
- Never call a visual defect harmless. Hole-scan, then make close-up renders of every joint before a piece is called done.
- The user writes all words, including the neon sign's text, and paints or sources signature designs (glyphs, posters, graffiti, sign artwork, station tile). Ask when one is needed; never stretch a stand-in.
- No free VFX assets: effects are made in house. Sounds come only from the approved packs through `tools/prepare_sfx.py`, never generated.
- Every strange thing has a cause in the world's events. Dress with scenes, not sprinkles.
- Line 2 is blue.
- Godot suites must be frame-exact under `--fixed-fps 60`: seed every random draw (memory: headless-test-determinism).
- Binaries:
  - `BLENDER=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}`
  - `GODOT=${GODOT:-/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot}`
  - Godot suites run as `"$GODOT" --headless --fixed-fps 60 --path . res://tests/<suite>.tscn`, or several at once with `tools/run_suites.sh`.

## Review Focus

1. **A fresh checkout has no brush sheets.** The painter must stop with a message naming the missing file and the command that prepares it (Task 3). Committed atlases still load in game without the sheets (Task 9 L9).
2. **The space in `Texture_Abstract01 .png`.** Preparation finds and copies it under a clean name (Task 2, `test_space_in_name`).
3. **Text and HUD with the grid off.** CrispText and the HUD must still draw when `virtual_height` is 0 (Task 1, R16).
4. **Neon flicker in headless runs.** The flicker is a seeded pattern on game time, so two runs give identical light energies (Task 5, N3).
5. **Stacked spaces in the metro.** A space directly above another, with a 0.5 m slab between, must pass the greybox gate. Truly overlapping volumes must fail it (Task 14, `test_stacked_spaces_pass_the_gate` and `test_overlapping_spaces_fail`).
6. **Bevels against the sliver gate.** A bevel narrower than 1 cm fails `gate.SLIVER`, so `common.bevel` refuses widths under 0.012 m (Task 4).

---

## Track A: the new standard and the hero stall

### Task 1: Turn the pixel grid off

**Files:**
- Modify: `scripts/Visual/Retro.gd:13` (default `virtual_height`), `:67` (`_grids`)
- Test: `tests/retro_test.gd` (R2 near lines 49-73, R11 near 334-387, R15 near 307-309; new R16)

**Interfaces:**
- Produces: `Retro.virtual_height` defaults to `0`. `Retro._grids == [0, 480, 360, 240]`, so the first F6 press turns a grid on.

- [ ] **Step 1: Update the tests.**
  - R15 expects `fresh.virtual_height == 0` and `_grids == [0, 480, 360, 240]`.
  - R2 and R11 set `Retro.virtual_height = 480` explicitly before their grid assertions, and restore `0` after.
  - New R16: with `virtual_height == 0`, `RetroScreen` is hidden, `root.scaling_3d_scale == 1.0`, and a `Label` the test adds in a `CanvasLayer` is visible, with non-empty text, and draws on screen (its rect is inside the viewport).
- [ ] **Step 2: Run** `"$GODOT" --headless --fixed-fps 60 --path . res://tests/retro_test.tscn`. Expected: R15 and R16 FAIL.
- [ ] **Step 3: Set the default to `0` and reorder `_grids`.** Keep `enabled := true`, because texture filters stay converted.
- [ ] **Step 4: Run** `retro_test` again (all PASS). Then run `tools/run_suites.sh` over `style_lab_test painterly_test zocalo_test`. Expected: no new FAIL. Any suite that assumed the grid gets the same explicit setup as R2.
- [ ] **Step 5: Commit** `feat(retro): the pixel grid is off by default (F6 still tries it)`

### Task 2: Prepare the brush sheets locally

**Files:**
- Create: `tools/textures/brushes.py`, `tools/textures/test_brushes.py`
- Modify: `.gitignore` (add `textures/brushes/` beside `textures/ps2/`, with a comment that these are the user's own sheets, kept local)

**Interfaces:**
- Produces:
  - `brushes.prepare(src_dir: Path, out_dir: Path) -> list[Path]` writes `out_dir/brush_00.png` … `brush_04.png`. Each is 1024² greyscale with alpha kept and seamless.
  - `brushes.load(name: str) -> np.ndarray` returns float32 values in [0, 1] (premultiplied value × alpha) and raises `FileNotFoundError` with the message `"brush sheet %s missing: run python3 tools/textures/brushes.py ~/Downloads"`.
  - The constant `BRUSHES = ROOT/"textures"/"brushes"`.

- [ ] **Step 1: Write the failing tests** in `test_brushes.py` (unittest, synthetic files in a temp dir):
  - `test_space_in_name`: a source named `Texture_Abstract01 .png` becomes `brush_01.png`.
  - `test_seamless`: for each output, the mean absolute difference across the wrap seam, in x and in y, is ≤ 1.5× the mean difference between neighbouring interior pixels. The input is a synthetic sheet with a deliberate step at its edge.
  - `test_missing_sheet_message`: `load("brush_03")` from an empty dir raises `FileNotFoundError` whose message contains `brushes.py`.
- [ ] **Step 2: Run** `python3 tools/textures/test_brushes.py`. Expected: FAIL (no module).
- [ ] **Step 3: Implement.** Find sources with a glob on `Texture_Abstract0?*.png` and sort by the digit. Resize to 1024 with LANCZOS. To make a sheet seamless, offset it by half, then cross-blend a 64 px band at the old edges with the unshifted image using a smoothstep weight.
- [ ] **Step 4: Run** the tests (PASS). Then run `python3 tools/textures/brushes.py ~/Downloads` and confirm five files in `textures/brushes/` and none under `git status`.
- [ ] **Step 5: Commit** `feat(textures): prepare the user's brush sheets locally (not in git)`

### Task 3: The layered painter

The new atlas painter. It runs beside `eclipse_atlas.py` and does not replace it.

**Files:**
- Create: `tools/textures/layered_atlas.py`, `tools/textures/test_layered_atlas.py`, `tools/textures/recipes/underground/README.md` (recipe keys, one line each)

**Interfaces:**
- Consumes:
  - `SOURCE/<piece>_regions.json` (`slots`, `atlas_px`, `px_per_m`)
  - `SOURCE/<piece>_texels.npz` (keys `slot`, `position`, `normal`, `tangent_u`, `tangent_v`, `wear`, `cavity`; row 0 = top)
  - `SOURCE/<piece>_ao.png`
  - `brushes.load()`
- Produces:
  - CLI `python3 tools/textures/layered_atlas.py <piece> [--recipes=underground] [--out=textures/painted/underground]`
  - `paint_slot(texels: dict, mask: np.ndarray, ao: np.ndarray, recipe: dict, brushes: dict) -> np.ndarray` (H×W×3 float sRGB)
  - Writes `<out>/<piece>_base.png`. The existing `KitLoader.atlas`/overpaint precedence still applies, so a user overpaint `<piece>.png` wins.
- Recipe JSON per slot, `tools/textures/recipes/underground/<slot>.json`, with keys:
  - `colour` (hex, the flat field)
  - `light` (0-1, top-down gradient strength)
  - `height_light` (0-1, lighter with world height over the piece)
  - `wear` (0-1, edge highlight from `wear`) and `wear_colour`
  - `grime` (0-1, from `cavity` × (1−AO)) and `grime_colour`
  - `brush` (sheet name) with `brush_scale_m` and `brush_amount`
  - `black` (0-1: cavity × occlusion threshold above which the texel goes to the Mignola black `#0b0a0c`)

- [ ] **Step 1: Write the failing tests** on synthetic texels (a 64² slot of upward normals beside one of sideways normals, with known `wear`, `cavity` and AO):
  - `test_flat_colour_alone`: with every amount 0, every texel equals `colour` within 1/255.
  - `test_top_light`: upward texels are lighter in Oklab L than sideways texels by at least `0.1 × light`.
  - `test_edge_wear`: texels with `wear > 0.6` are lighter than texels with `wear == 0`.
  - `test_crevice_grime`: texels with high `cavity` and AO < 0.5 move toward `grime_colour`.
  - `test_mignola_black`: texels past the `black` threshold equal `#0b0a0c` exactly, and nothing below the threshold is that dark.
  - `test_brush_breakup_bounded`: with `brush_amount` 0.2, Oklab L stays within ±0.2 of the unbrushed result, and its standard deviation is greater than 0.
  - `test_missing_recipe`: an unknown slot exits 1 with the message `no recipe for slot <name>`.
- [ ] **Step 2: Run** `python3 tools/textures/test_layered_atlas.py`. Expected: FAIL.
- [ ] **Step 3: Implement the layers in the spec's order:** flat → top light → wear and grime → brush → black.
  - Work in Oklab. Reuse the Oklab helpers from `eclipse_atlas.py` by importing them, not copying.
  - Brush sampling is world-aligned through `tangent_u`/`tangent_v` × `brush_scale_m`, as `_paint` does in `eclipse_atlas.py:502`.
  - Grow each slot into its margin before writing.
- [ ] **Step 4: Run** the tests (PASS).
- [ ] **Step 5: Commit** `feat(textures): layered painter (flat, top light, wear, grime, brush, Mignola black)`

### Task 4: Bevels and per-kit budgets in the kit pipeline

**Files:**
- Modify: `tools/eclipse/common.py` (new `bevel`; `export_piece` gains `budget=None` and passes it on), `tools/eclipse/gate.py:85` (`check(faces, tris, uvs, budget=BUDGET)`)
- Test: `tools/eclipse/test_gate.py`, `tools/eclipse/test_kit_bpy.py` (new class `Bevel`)

**Interfaces:**
- Produces:
  - `common.bevel(obj, width: float, segments: int = 3, angle: float = 35.0) -> None` applies a Bevel modifier (limit by angle, clamp overlap on, harden normals), then shades smooth by angle. It raises `ValueError` if `width < 0.012`, because a narrower bevel fails the sliver gate.
  - `export_piece(..., budget: int | None = None)`: `None` keeps `gate.BUDGET` (5000).

- [ ] **Step 1: Write the failing tests.**
  - `test_gate.py::test_budget_parameter`: 6000 triangles pass with `budget=8000` and fail with the default.
  - `test_kit_bpy.py::Bevel` builds a 1 m `common.Mesh` box:
    - `test_bevelled_box_stays_closed` (via `_closed`)
    - `test_bevel_adds_faces`
    - `test_narrow_bevel_refused` (0.005 raises `ValueError`)
    - `test_bevelled_box_passes_gate`: run `gate.check` on its dumped faces; the result is empty.
- [ ] **Step 2: Run** `python3 tools/eclipse/test_gate.py` and `"$BLENDER" -b --factory-startup --python-exit-code 1 --python tools/eclipse/test_kit_bpy.py`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.** `bevel` is called by a piece script on its objects, after `m.make()` and before `export_piece` unwraps.
- [ ] **Step 4: Run** both again, plus `tools/eclipse/lab.sh test`. Expected: all PASS, with existing kits unchanged.
- [ ] **Step 5: Commit** `feat(eclipse): soft bevels and per-kit triangle budgets`

### Task 5: The bespoke preset and the neon

**Files:**
- Modify: `scripts/Visual/Painterly.gd:22-30` (add a preset)
- Create:
  - `scripts/Visual/Neon.gd` (`class_name Neon`)
  - `scripts/Visual/neon.gdshader`
  - `tests/neon_test.gd` and `tests/neon_test.tscn`

**Interfaces:**
- Produces:
  - Preset `&"bespoke"`: `{"paint_mix": 0.0, "stroke_strength": 0.08, "painted_light": 1.0, "ramp_amount": 0.6, "ambient_amount": 0.12, "rim_amount": 0.2, "macro_amount": 0.25}`. These are starting values; the look-dev (Task 10) tunes them and the recipe records the final ones.
  - `Neon.material(colour: Color, energy: float = 4.0) -> ShaderMaterial`: an unshaded emissive tube with a soft core-to-edge falloff and no shadow casting.
  - `class NeonSign extends Node3D` in `Neon.gd`, with:
    - `@export var colour: Color`
    - `@export var pattern: String` (a flicker pattern string such as `"mmmmmaammmmzmmm"`; a=off, m=full, z=half)
    - `@export var seed: int`
    - `func energy_at(t: float) -> float`
  - The sign drives its tube material and its child `OmniLight3D` from game time, not wall time.

- [ ] **Step 1: Write the failing suite** `neon_test`:
  - N1: `Painterly.PRESETS.has(&"bespoke")` and its `paint_mix == 0.0`.
  - N2: `Neon.material(Color.HOT_PINK)` has emission and casts no shadow.
  - N3: two `NeonSign`s with the same pattern and seed return identical `energy_at` for t in 0..10 s at 0.1 s steps; a different seed differs at least once.
  - N4: the sign's light energy changes over 3 s of game time and is never negative.
- [ ] **Step 2: Run** `"$GODOT" --headless --fixed-fps 60 --path . res://tests/neon_test.tscn`. Expected: FAIL.
- [ ] **Step 3: Implement.** The seed offsets the pattern's start index and its step rate (±15%) through a `RandomNumberGenerator` seeded once.
- [ ] **Step 4: Run** `neon_test` (PASS) and `painterly_test` (no new FAIL).
- [ ] **Step 5: Commit** `feat(visual): bespoke preset and seeded neon signs`

### Task 6: The stall's design card (USER GATE)

**Files:**
- Create: `docs/superpowers/refs/underground/cards/stall.md`, plus blockout renders in `docs/superpowers/refs/underground/cards/stall/`

- [ ] **Step 1: Write the card** in the format of `docs/superpowers/refs/mexico_city/cards/kiosk.md`. It covers:
  - **What it is:** a pasillo puesto that sells something with a story. Propose two options to the user, for example a curandera's herb and candle stall or a tortas stall with a saint's corner.
  - **Its cause in the world:** the Light Company's steel frame, a tarp, and wood patches.
  - **Footprint:** about 2.4 × 1.4 m, 2.6 m tall.
  - **Parts:** frame, counter, shelving, awning cloth, hanging bulb, neon sign, clutter, and the folklore touch (a small ofrenda with marigolds and a candle).
  - **Slots:** `steel`, `wood`, `cloth`, `brass`, `tin`, `paper`, `wax`, plus atlas-free `glass` and `neon`.
  - **Silhouette notes:** chunky, slightly exaggerated proportions, big soft bevels.
  - **References** from the board (Hospital General puestos, Troll Market, Deadlock Broadway).
- [ ] **Step 2: Block out both options** as primitives in the live Blender session through the Blender MCP (`execute_blender_code`). Render three views of each with `render_viewport_to_path` into the card folder.
- [ ] **Step 3: Ask the user** to choose the option and to give the neon sign's words and colour. **Stop until the user approves the card.** Record their choices in the card.
- [ ] **Step 4: Commit** `docs(underground): the stall's design card`

### Task 7: Build the stall

**Files:**
- Create: `tools/eclipse/stall.py`
- Modify: `tools/eclipse/lab.sh:19` (add `stall` to `PIECES`), `tools/eclipse/test_kit_bpy.py` (new class `Stall`)

**Interfaces:**
- Consumes: `common.Mesh`, `common.bevel` (Task 4), `export_piece(..., budget=)`.
- Produces:
  - `assets/eclipse/lab/stall.glb` with objects `stall_frame`, `stall_counter`, `stall_awning`, `stall_shelves`, `stall_clutter`, `stall_ofrenda`, and `stall_neon` (slot `neon`, atlas-free). Each sits at the origin on the ground with its front facing -Y.
  - `SOURCE/stall_{regions.json,texels.npz,ao.png,faces.json}`
  - `NAME = "stall"`, `ATLAS = 2048`, and the `SLOTS` from the card.
- Iteration: the script is the source of truth. While shaping, run `build()` inside the live Blender session over MCP and show renders (`render_viewport_to_path`). Every accepted change goes back into `stall.py`; no hand edits are left only in the session.

- [ ] **Step 1: Write the failing test class** `Stall` in `test_kit_bpy.py`:
  - `test_every_part_is_an_object` (the seven names)
  - `test_every_object_is_closed`
  - `test_no_degenerate_triangles`
  - `test_everything_rests_on_the_ground`
  - `test_budget`: total triangles ≤ 20000, the starting budget the look-dev may revise.
  - `test_footprint`: the bounding box is within 2.2-2.6 × 1.2-1.6 × 2.4-2.8 m.
  - `test_bevelled`: at least 60% of the frame's and counter's sharp edges carry a bevel. Check by counting faces narrower than 0.05 m along edges.
- [ ] **Step 2: Run** the kit test. Expected: `Stall` FAILS.
- [ ] **Step 3: Build** `stall.py` from the card. Shape first: big forms, proportions, bevels; render and check the silhouette. Then the secondary detail named on the card (rivets, hinges, welds, chips, cable ties). Call `export_piece(NAME, ATLAS, SLOTS, budget=20000)`.
- [ ] **Step 4: Run** `tools/eclipse/lab.sh stall`. Expected: `stall: clean, N tris, X px/m`. The kit test: PASS.
- [ ] **Step 5: Run** `tools/eclipse/lab.sh joints stall`, after adding `JOINTS` to `stall.py` with a view per joint: the frame to the counter, the awning to the frame, the shelf brackets, and the neon mounts. Look at every image for holes, seams and z-fighting, and fix each fault before moving on.
- [ ] **Step 6: Commit** `feat(underground): the stall, modelled`

### Task 8: Paint the stall

**Files:**
- Create: `tools/textures/recipes/underground/{steel,wood,cloth,brass,tin,paper,wax}.json`
- Output (committed): `textures/painted/underground/stall_base.png`

- [ ] **Step 1: Write one recipe per slot.** Colours come from the reference board's palette: CDMX Metro orange and blue for accents, Mignola's muted purples, ochres and cold greens, and one red accent.
  - Brush 02 or 03 on large surfaces, 04 for wear and grime, 00 or 01 for gentle variation.
  - `black` set only on slots with deep recesses (the frame and the shelves).
- [ ] **Step 2: Run** `python3 tools/textures/layered_atlas.py stall`. Expected: `stall_base.png` written, with no `no recipe` error.
- [ ] **Step 3: Check the atlas** by viewing it, and its material separation in a Blender render of the textured stall over MCP. Fix the recipes until wood, steel, cloth and brass separate at a glance.
- [ ] **Step 4: Commit** `feat(underground): the stall, painted`

### Task 9: The look-dev bay

**Files:**
- Create:
  - `maps/underground_lab.gd` and `maps/underground_lab.tscn`
  - `tests/underground_lab_test.gd` and `.tscn`
  - `tests/underground_lab_stills.gd` and `.tscn`
  - `tools/textures/decals.py` and `tools/textures/test_decals.py`
- Output (committed): `textures/painted/underground/decal_{drip,soot,grime}.png`

**Interfaces:**
- Consumes:
  - `Painterly.material(..., &"bespoke", ...)`
  - `KitLoader.atlas` precedence, extended to look in `textures/painted/underground/` when the piece is in `UNDERGROUND = ["stall"]`
  - `Neon.material` and `NeonSign`
- Produces:
  - A 6 m wide, 4 m tall, 24 m long tiled corridor stub, greybox at first. The stall stands against one wall at z=0, lit by two sodium work lights (2000 K) and its own neon. There is a player spawn 6 m in front of it.
  - Keys: F1 work lights on and off; F2 a neutral grey "form light" to judge shape; F3 decals on and off.
  - `decals.py` builds decals from the brush sheets: `make(kind: str) -> PIL.Image` with RGBA output, for `kind` in `drip`, `soot` and `grime`.
  - Stills: `"$GODOT" --path . --resolution 1920x1080 res://tests/underground_lab_stills.tscn -- --out=/tmp/underground-lab` writes `front`, `three_quarter`, `side`, `close_counter`, `close_awning`, `close_neon` and `corridor_far`, each with the work lights and with the form light.

- [ ] **Step 1: Write the failing tests.**
  - `test_decals.py`: each kind has alpha, is non-empty, has transparent borders 8 px wide, and is seamless where needed. `soot` darkens toward the top edge.
  - `underground_lab_test` checks:
    - U1: the stall is loaded with all seven parts.
    - U2: its painted parts use preset `bespoke` (`paint_mix == 0.0`).
    - U3: the neon glows and its light flickers.
    - U4: the corridor is lit.
    - U5: the player walks a full loop around the stall's front without being stopped by an invisible collider.
    - U6: F2 switches to the form light.
    - U7: three decals are present, and F3 toggles them.
    - U8: `Retro.virtual_height == 0`.
    - U9: the bay loads with `textures/brushes/` absent (rename it for the check). The painted atlas is committed, so nothing is missing.
- [ ] **Step 2: Run** both. Expected: FAIL.
- [ ] **Step 3: Implement** the bay, the decals and the stills, using `maps/style_lab.gd` as the pattern (`_place`, colliders) and `tests/style_lab_stills.gd` (views).
- [ ] **Step 4: Run** `python3 tools/textures/test_decals.py` and `"$GODOT" --headless --fixed-fps 60 --path . res://tests/underground_lab_test.tscn`. Expected: PASS.
- [ ] **Step 5: Take the stills** and look at every one.
- [ ] **Step 6: Commit** `feat(underground): look-dev bay with decals and stills`

### Task 10: The stall's effects

**Files:**
- Modify: `maps/underground_lab.gd`, `tests/underground_lab_test.gd`
- Reuse: the Zócalo's in-house effects (memory: vfx-aesthetic-and-pipeline; the Vfx, Ambient and Occult scripts, the drift and the smoke sheets)

- [ ] **Step 1: Add failing checks.**
  - U10: the hanging bulb sways in the corridor draught, its swing < 4°.
  - U11: a thread of copal smoke rises from the ofrenda candle, with the existing smoke sheet and one wind.
  - U12: dust motes drift in the work lights' cones.
  - U13: the neon hum plays, positioned on the sign, falling to silence within 8 m, and its volume follows `energy_at`.
- [ ] **Step 2: Find a hum for U13.** Search the approved sound packs for a neon or electrical hum through `tools/prepare_sfx.py`. If none exists, **ask the user for one** and leave U13 pending until then.
- [ ] **Step 3: Implement** U10-U13, then run the suite. Expected: PASS, apart from U13 if it is pending on the user.
- [ ] **Step 4: Commit** `feat(underground): the stall's effects`

### Task 11: Look-dev with the user, then the recipe (USER GATE)

**Files:**
- Create: `docs/superpowers/refs/underground/recipe.md`

- [ ] **Step 1: Show the user the stills** from both lights, and ask them to walk the bay (`"$GODOT" --path . res://maps/underground_lab.tscn`).
- [ ] **Step 2: Iterate on each note.** Each round:
  1. Change the model, recipe, preset values, decals or effects.
  2. Re-run `lab.sh stall`, `layered_atlas.py stall` and `underground_lab_test`.
  3. Take new stills, look at them, then send them.

  Repeat until the user approves. **Stop here until they do.**
- [ ] **Step 3: Write the recipe** from what the approved stall actually uses:
  - modelling rules (proportion, bevel widths and segments, detail density, triangle budget per kind of prop);
  - atlas size and px/m;
  - the painter's layers with the final value ranges per material family;
  - the brush assignment;
  - the final `&"bespoke"` values (update `Painterly.gd` to match);
  - decal kinds and how they are placed;
  - effect rules (neon, light, smoke, motes, sound);
  - the review checklist (gate, joints, stills in both lights).
- [ ] **Step 4: Commit** `docs(underground): the approved recipe` together with any final preset values.

---

## Track B: the layout

### Task 12: Plan-check rules for a map with no street

**Files:**
- Modify: `tools/level/plan_check.py:362` (`check(data, rules=ZOCALO_RULES)`)
- Test: `tools/level/test_plan_check.py`

**Interfaces:**
- Produces:
  - `ZOCALO_RULES = {"size": (500, 700), "events": True, "reach_from": "street"}`
  - `UNDERGROUND_RULES = {"size": None, "events": False, "reach_from": ("arrival",)}`. With this rule, reach starts from the spaces containing landmarks of the listed kinds.
  - `check(data, rules)` skips the brink-size and event checks when they are `None` or `False`.

- [ ] **Step 1: Write the failing tests.**
  - `test_underground_reach_from_arrival`: two spaces joined by an opening, one holding an `arrival` landmark, with no street, give no problems under `UNDERGROUND_RULES`.
  - `test_unreached_space_reported`: a third, unjoined space is reported.
  - `test_zocalo_rules_unchanged`: `test_zocalo_plan.py` still passes.
- [ ] **Step 2: Run** `python3 tools/level/test_plan_check.py`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `tools/level/level.sh test`. Expected: all PASS.
- [ ] **Step 5: Commit** `feat(level): plan-check rules for underground maps`

### Task 13: Layers on spaces and a sheet per depth band

**Files:**
- Modify: `tools/level/layouts/plan.py` (`space(..., layer=None)` stored on the space), `tools/level/plan_draw.py` (`SHEETS`)
- Test: `tools/level/test_plan_draw.py`

**Interfaces:**
- Produces:
  - Spaces carry `"layer": 1 | 2 | 3 | None`.
  - `plan_draw.draw(data, out_dir, px_per_m=2.0, bands=None)`. With `bands=[(-10, -4, "station"), (-16, -10, "market"), (-40, -16, "old")]`, it also writes `plan_underground_<label>.png`, which draws only the spaces and routes whose floor or ends fall in that band, each labelled with its name and floor.

- [ ] **Step 1: Write the failing test.** Three spaces at -8, -14 and -20 give three band sheets, each containing exactly its own space: compare the coloured pixel bounds against the space rects at 2 px/m.
- [ ] **Step 2: Run** it. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `tools/level/level.sh test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(level): space layers and per-depth sheets`

### Task 14: The Underground's layout

**Files:**
- Create:
  - `tools/level/layouts/city_metro.py`
  - `tools/level/layouts/metro/__init__.py`
  - `tools/level/layouts/metro/station.py` (layer 1: the platforms, the arrival, the hall, the exit spine)
  - `tools/level/layouts/metro/market.py` (layer 2: pasillos lined with puestos, side alleys)
  - `tools/level/layouts/metro/service.py` (pipe galleries, vent shafts, catwalks, climb routes)
  - `tools/level/layouts/metro/old.py` (layer 3: colonial vaults and drains, the invented temple inside the tunnel, the rebuilt crypt, the Templo Mayor shells and the pawnshop vault)
  - `tools/level/layouts/metro/places.py` (character places and scene sites as landmarks)
  - `tools/level/test_metro_plan.py`
- Modify: `tools/level/greybox.py` (no street ground or brink when `data["brink"]` is empty)

**Interfaces:**
- Consumes: `Plan`, `rect`, `UNDERGROUND_RULES` (Task 12), `layer=` (Task 13).
- Produces:
  - `city_metro.plan() -> dict` with `PARTS = [station, market, service, old, places]`.
  - Landmarks:
    - `arrival` (on the platform, where the car's doors open)
    - `exit_zocalo` × 4 (the tops of the exit climbs, one under each Zócalo kiosk at (±90, ±98))
    - `character_place` (props: `who` such as `"stall_keeper"`, `"shrine_keeper"`, `"squatter"`)
    - `scene` (props: `scene`, `cause`)
  - Plan x and z match the Zócalo's, so the exits sit under the Zócalo's kiosks. The geometry under the cathedral matches the Zócalo's crypt position (x -50..10, z -250..-160).

- [ ] **Step 1: Write the failing tests** in `test_metro_plan.py`. All targets marked *(Claude's call)* in the spec's sense are open to change at the user's review.
  - `test_plan_check_clean`: `plan_check.check(DATA, UNDERGROUND_RULES) == []`.
  - `test_layers_by_depth`:
    - every layer-1 floor is in [-14, -6];
    - the mean layer-2 floor is below the mean layer-1 floor;
    - every layer-3 floor is below -16;
    - every space has a layer.
  - `test_spine`: the shortest path from `arrival` to the nearest `exit_zocalo` passes only through layer-1 spaces and is ≤ 250 m long, so it fits the five-minute opening.
  - `test_exits_under_kiosks`: each `exit_zocalo` is within 2 m of (±90, ±98).
  - `test_twenty_minutes` *(Claude's call)*: the total walkable centreline length (the long axis of every space plus every route) is between 1100 and 1600 m.
  - `test_places` *(Claude's call)*: at least 8 `character_place` and 12 `scene` landmarks. Every `scene` has a non-empty `cause`, and no two scenes of the same kind are within 15 m (scenes, not sprinkles).
  - `test_climbs` *(Claude's call)*: at least 4 `climb` routes and at least 1 vent shaft. A shaft is a space at least 8 m tall with a floor-to-ceiling `climb`.
  - `test_old_places_kept`: spaces `crypt`, `templo_shells` and `pawn_vault` exist in layer 3, and the crypt overlaps the Zócalo crypt's footprint by at least 80%.
  - `test_stacked_spaces_pass_the_gate`: `greybox.gate(greybox.build(DATA)) == []`.
  - `test_overlapping_spaces_fail`: a copy of the data with one market space moved to overlap a station space's volume gives a non-empty gate result.
- [ ] **Step 2: Run** `python3 tools/level/test_metro_plan.py`. Expected: FAIL.
- [ ] **Step 3: Lay the parts**, following the spec's layers and the reference board:
  - The station reads as a real metro and has signage landmarks (`sign`, props `says`: one of `"Correspondencia"`, `"Salida"`, `"Andén"`).
  - The market has pasillos with puesto bays and alleys off them.
  - Service routes thread pipes through all three layers.
  - The old layer lies under the platforms and runs out to the crypt.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(level): the Metro Underground layout`

### Task 15: Build and walk the metro map

**Files:**
- Modify: `tools/level/level.sh` (new case `metro)`, and the `test)` case runs `test_metro_plan.py`)
- Create: `maps/metro.gd`, `maps/metro.tscn`, `tests/metro_test.gd`, `tests/metro_test.tscn`
- Output (committed): `assets/eclipse/metro/plan.json`, `greybox.json`, `plan/*.png`

**Interfaces:**
- Produces:
  - `tools/level/level.sh metro` runs `city_metro.py` → `plan_draw.py` (with the bands from Task 13) → `greybox.py`. There is no `dress.py`; the metro has no dressing yet.
  - `maps/metro.gd` follows `maps/zocalo.gd`'s pattern: `PLAN` and `GREYBOX` paths, `GreyboxLoader.build`, the player at the `arrival` landmark + 1.05 m.
  - It adds dim greybox lighting: a sodium omni light at each `sign` and `scene` landmark, plus a dark environment so the user can walk it.

- [ ] **Step 1: Write the failing suite** `metro_test`, using `tests/zocalo_test.gd`'s `_walk` helper pattern (lines 108-160):
  - M1: the map loads and the player stands on the platform floor (-14) at `arrival`.
  - M2: the player walks the spine from `arrival` to an `exit_zocalo` along waypoints taken from the plan's shortest path, and never falls more than 0.5 m below any floor on the way.
  - M3: walk to one layer-2 space and one layer-3 space.
  - M4: every `climb` is a `ClimbVolume`.
  - M5: `Retro.virtual_height == 0`.
  - M6: no `ERROR:` lines are printed.
- [ ] **Step 2: Run** `tools/level/level.sh metro`, then `"$GODOT" --headless --fixed-fps 60 --path . res://tests/metro_test.tscn`. Expected: FAIL until the map exists.
- [ ] **Step 3: Implement** the map and the `level.sh` case.
- [ ] **Step 4: Run** `tools/level/level.sh metro` and `metro_test` (PASS), then `tools/run_suites.sh zocalo_test` (unchanged; the Zócalo's own station stays until Part 2).
- [ ] **Step 5: Commit** `feat(level): the metro greybox map, walkable`

### Task 16: Layout review with the user (USER GATE)

- [ ] **Step 1: Show the user** the sheets (`plan_underground_station/market/old.png`, `plan_all.png`) in the browser. Ask them to walk `maps/metro.tscn` from the arrival. Points to judge:
  - the route out and its sightlines;
  - the shift from station to market to Aztec stone;
  - whether it feels like 20 minutes.
- [ ] **Step 2: Iterate on each note** in `tools/level/layouts/metro/*`. Keep `test_metro_plan` and `metro_test` passing, adjusting the *(Claude's call)* targets where the user moves them. **Stop here until the user approves the layout.**
- [ ] **Step 3: Commit** `feat(level): the approved Underground layout`. Then write Part 2's and Part 3's plans from the approved recipe and layout.
