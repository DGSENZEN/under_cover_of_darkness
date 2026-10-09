# Eclipse City Style Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the style lab: the Metro kiosk and one Zócalo arcade bay, modelled from reference and textured in a blend of hand-painted atlases and a painterly shader, shown in-game in three variants so the user can fix the texturing pipeline for every later kit.

**Architecture:**
- **Pieces:** each is a reproducible Blender script (`tools/eclipse/`) that models it, lays its UVs onto one atlas, bakes an ambient-occlusion map and a region map, and exports a glTF.
- **Atlases:** a Pillow painter (`tools/textures/eclipse_atlas.py`, in the manner of `tools/textures/paint.py`) paints each atlas from those maps.
- **Shader:** a Godot spatial shader (`scripts/Visual/painterly.gdshader`) draws the painted atlas, then blends in world-space brush strokes and a palette mapping by `paint_mix`.
- **Lab map:** `maps/style_lab.tscn` shows the three variants side by side, by night and by day.

**Tech Stack:** Godot 4.5.1 (GDScript, spatial shaders), Blender 4 Python (bpy, Cycles bake), Python 3 + Pillow 12 + numpy.

**Spec:** `docs/superpowers/specs/2026-10-09-eclipse-city-frame-design.md` (section 7 and section 8 step 1). The research is in `docs/superpowers/refs/mexico_city/`.

## Global Constraints

- Branch `eclipse-city`. Godot is `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot` and Blender is `/Applications/Blender.app/Contents/MacOS/Blender`, as in `tools/level/level.sh`.
- Texturing is a **blend of hand-painted atlases and a shader-led painterly look**. **No vertex snapping** (`snap_lines` stays 0). The Retro screen's grid and dither stay as they are.
- **Only CC0 or self-made textures** are committed; the repo is public. No downloaded VFX or brush textures: strokes are made by our own code.
- **The user writes all words** and **paints glyphs, plaques and broadsides**. Pieces carry a blank sign panel (a canvas) instead of lettering or glyphs.
- Real landmarks are **remixed, never copied** (INAH). The arcade bay reads as the Portal de Mercaderes but is not a survey of it.
- Buildings are **well made, not overkill**:
  - pieces snap on a 0.25 m grid
  - no faces overlap in a plane (`tools/level/overlap.py` finds none)
  - budget per piece is **at most 2,500 triangles**
  - **48 px per metre** texel density on **one atlas of at most 512 × 512** per piece
- **Nothing is called done from tests alone:** joint renders and in-game stills are produced for the user's verdict. The user's choice is the end of this plan.
- The new function key is **F11** (day/night in the lab). F1-F10 are taken.

## Review Focus

1. **The lab opened without its generated assets** (a fresh checkout before the Blender and Pillow steps): the map should report which asset is missing and still load, not crash. The test lives in Task 6.
2. **The Retro autoload's material sweep meeting the painterly ShaderMaterial:** it must leave it alone (`retro_material` skips non-BaseMaterial3D) and the shader must keep its own nearest sampling. The test lives in Task 2.
3. **The atlas overpainted by the user:** the generator must never overwrite the user's file. The game uses `<piece>.png` if present, else `<piece>_base.png`, and the generator writes only `_base`. The tests live in Tasks 5 and 6.
4. **Glass drawn by the painterly shader:** the glass slot is excluded and gets its own translucent material, otherwise the kiosk canopy turns opaque. The test lives in Task 6.
5. **Texels at shallow angles and distance:** mipmapped nearest sampling with the brush pass must not shimmer more than the existing look. A still at 30 m and a grazing-angle still are in Task 6's capture list, judged by the user.

---

### Task 1: Reference cards for the kiosk and the arcade bay (user gate)

**Files:**
- Create: `docs/superpowers/refs/mexico_city/cards/kiosk.md`
- Create: `docs/superpowers/refs/mexico_city/cards/arcade_bay.md`

Each card has these sections:
- **Source:** the real buildings or types, with 3-6 links taken from `bible.md` and `architecture_and_city.md`.
- **Change:** what the Eclipse, the sinking or 1920s repurposing did to it.
- **Pieces:** the parts it breaks into, with names used as Blender object names.
- **Dimensions:** in metres, on the 0.25 m grid.
- **Slots:** material regions with their colours from the Zócalo palette (Task 2).
- **Joints:** the list of joints Task 3's joint renders must frame.
- **Sign panel:** its size, as a canvas for the user.

Starting design values the cards refine:
- **Kiosk:**
  - **Source:** Guimard's Paris Métro entrances; the 1969 Metro's tiled stairs.
  - **Change:** an Aztec stepped-fret frieze where Guimard had plant forms, and the Light Company's brass patches on seeped iron.
  - **Footprint:** a 3.0 × 6.0 m stair opening.
  - **Parts:** railing 1.0 m high, two lamp standards 3.5 m, a glass fan canopy at 3.0 m over the stair head, a sign panel 1.5 × 0.5 m.
  - **Slots:** `iron`, `brass`, `glass`, `tile_line2`, `stone_step`.
- **Arcade bay:**
  - **Source:** the Portal de Mercaderes on the Zócalo.
  - **Change:** one stone column replaced by a seeped riveted steel column, and the upper floor's balcony iron replaced with tube rails from another decade.
  - **Size:** one bay 4.5 m wide, 4.0 m deep under the arcade, arch spring at 3.25 m, upper storey to 9.0 m, parapet to 9.75 m.
  - **Slots:** `tezontle`, `chiluca`, `lime`, `steel`, `iron`, `wood_door`, `tile_floor`.

- [ ] **Step 1: Write both cards** from the research notes with the sections and starting values above.
- [ ] **Step 2: Show the user both cards and stop until they approve or change them.** Record their changes in the cards. Tasks 3 and 4 build from the approved cards only.
- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/refs/mexico_city/cards
git commit -m "docs(eclipse city): the style lab's reference cards, the kiosk and the arcade bay"
```

---

### Task 2: The painterly shader, its brush tile and the Zócalo palette

**Files:**
- Create: `tools/textures/painterly.py` (the brush tile and the palette PNG)
- Create: `tools/textures/test_painterly.py`
- Create: `scripts/Visual/painterly.gdshaderinc` (the shared code), `scripts/Visual/painterly.gdshader` (includes it), `scripts/Visual/painterly_unshaded.gdshader` (defines `PAINTERLY_UNSHADED`, includes it; for the pixel check only)
- Create: `scripts/Visual/Painterly.gd`
- Create: `tests/painterly_test.gd`, `tests/painterly_test.tscn` (headless: settings)
- Create: `tests/painterly_pixels.gd`, `tests/painterly_pixels.tscn` (windowed: pixels; the suites run headless on the dummy renderer, which neither compiles shaders nor draws)
- Modify: `tools/level/level.sh` (add `python3 "$HERE/../textures/test_painterly.py"` to `test)`)

**Interfaces:**
- Produces:
  - `textures/painted/eclipse/brush.png`: 128 × 128, greyscale, seamless.
  - `textures/painted/eclipse/palette_zocalo.png`: 16 × 1, RGB.
  - `Painterly.material(atlas: Texture2D, preset: StringName, palette: Texture2D = ZOCALO) -> ShaderMaterial`
  - `Painterly.PRESETS: Dictionary` mapping `{&"painted_led": {"paint_mix": 0.25, "stroke_strength": 0.06}, &"even": {"paint_mix": 0.5, "stroke_strength": 0.12}, &"shader_led": {"paint_mix": 0.85, "stroke_strength": 0.2}}`
  - `Painterly.ZOCALO: Texture2D`, `Painterly.BRUSH: Texture2D`

The Zócalo palette, dark to light. These are design values; the user may repaint the PNG.

`#14121a #24202c #3a3340 #5a5560 #8a8790 #b9b4b0 #3d1f1c #6e2f26 #9a4a3a #2a3b2e #3f7a52 #7fd18a #7a5a24 #c49a40 #e8d8a8 #d8e4f0`

- [ ] **Step 1: Write the failing Python tests** in `tools/textures/test_painterly.py`, unittest style as in `tools/level/test_overlap.py`:
  - `test_brush_is_seamless`: the mean absolute difference between column 0 and column 127, and between row 0 and row 127, is under the mean difference between neighbouring columns times 1.5.
  - `test_brush_has_strokes`: the standard deviation of values is over 30 and under 90.
  - `test_brush_is_deterministic`: two builds are byte-identical.
  - `test_palette_zocalo`: the PNG is 16 × 1 and its pixels equal the 16 hex values above, in order.
- [ ] **Step 2: Run it and see it fail.** Run `python3 tools/textures/test_painterly.py`. Expected: errors, module `painterly` not found.
- [ ] **Step 3: Implement `tools/textures/painterly.py`** with these signatures:
  - `brush(seed: int = 11) -> PIL.Image`
  - `palette(colours: list[str]) -> PIL.Image`
  - `main(argv)`, which writes both files.

  For the brush, draw about 140 tapered elongated dabs (length 18-40 px, width 3-7 px, angle 70-110°, i.e. mostly vertical) at 4× size on a canvas wrapped by drawing each dab at its 9 tiled offsets, then shrink by averaging as `paint.py`'s `_finish` does, without palette cutting.
- [ ] **Step 4: Run the Python tests and see them pass.** Run `python3 tools/textures/painterly.py && python3 tools/textures/test_painterly.py`. Expected: OK.
- [ ] **Step 5: Write the failing Godot suite** `tests/painterly_test.gd`, with the `results` and `_check` pattern and the `==== RESULTS ====` print as in `tests/retro_test.gd`:
  - **P1:** `Painterly.material(Painterly.BRUSH, &"even")` is a ShaderMaterial whose `paint_mix` is 0.5 and `stroke_strength` 0.12.
  - **P2:** every preset in `PRESETS` makes a material whose uniforms equal the preset's values.
  - **P3:** the Retro autoload's `retro_geometry` on a box with that material leaves the ShaderMaterial unchanged (same instance, no `texture_filter` property set).

  And the windowed check `tests/painterly_pixels.gd` (same RESULTS pattern), on quads drawn with `painterly_unshaded.gdshader` into a 64 × 64 SubViewport read back after 5 frames:
  - **X1:** with `paint_mix` 0 every pixel equals the atlas texel under it within 2/255 (atlas: a 4 × 4 test checker).
  - **X2:** with `paint_mix` 1 and `stroke_strength` 0 every pixel is one of the 16 palette colours within 2/255.
  - **X3:** both shaders compile and draw, so no `SHADER ERROR` or engine ERROR line appears in the run's output.
- [ ] **Step 6: Run both and see them fail.** Run `tools/run_suites.sh tests/painterly_test.tscn` and `"$GODOT" --path . --resolution 640x360 res://tests/painterly_pixels.tscn`. Expected: script errors, `Painterly.gd` missing.
- [ ] **Step 7: Implement `scripts/Visual/painterly.gdshaderinc`** (with its two shader files) with these uniforms:
  - `atlas : source_color, filter_nearest_mipmap, repeat_enable`
  - `palette : source_color, filter_nearest`
  - `brush : filter_linear_mipmap, repeat_enable`
  - `paint_mix = 0.5`, `stroke_strength = 0.12`, `stroke_scale = 0.75` (metres per brush tile)
  - `roughness = 0.9`, `specular = 0.3`

  The body is an algorithm the signature does not determine:

```glsl
// fragment, after the vertex stage passed world position and world normal:
vec3 base = texture(atlas, UV).rgb;
vec3 w = abs(world_normal); w /= (w.x + w.y + w.z);
float s = texture(brush, world_pos.zy / stroke_scale).r * w.x
        + texture(brush, world_pos.xz / stroke_scale).r * w.y
        + texture(brush, world_pos.xy / stroke_scale).r * w.z;
vec3 pushed = base + (s - 0.5) * stroke_strength;
vec3 best = texelFetch(palette, ivec2(0, 0), 0).rgb; float d = 1e9;
for (int i = 0; i < 16; i++) {
    vec3 c = texelFetch(palette, ivec2(i, 0), 0).rgb;
    float e = dot(pushed - c, pushed - c);
    if (e < d) { d = e; best = c; }
}
ALBEDO = mix(base, best, paint_mix);
```

  `painterly.gdshader` declares `render_mode cull_back, diffuse_lambert, specular_schlick_ggx;`, and `painterly_unshaded.gdshader` declares `render_mode unshaded;`. Both `#include` the shared file. Then implement `scripts/Visual/Painterly.gd` (`class_name Painterly`, static) with the Interfaces above.
- [ ] **Step 8: Run both and see them pass.** Run the two commands of Step 6. Expected: P1-P3 PASS and X1-X3 PASS, no ERROR lines.
- [ ] **Step 9: Commit**

```bash
git add tools/textures/painterly.py tools/textures/test_painterly.py textures/painted/eclipse scripts/Visual/painterly* scripts/Visual/Painterly.gd tests/painterly_test.* tests/painterly_pixels.* tools/level/level.sh
git commit -m "feat(eclipse city): the painterly shader, its brush and the Zócalo palette"
```

---

### Task 3: The geometry gate and the kiosk

**Files:**
- Create: `tools/eclipse/common.py` (shared bpy helpers)
- Create: `tools/eclipse/gate.py` (geometry checks)
- Create: `tools/eclipse/kiosk.py`
- Create: `tools/eclipse/test_gate.py`
- Create: `tools/eclipse/lab.sh`
- Create: `assets/eclipse/lab/` (outputs)

**Interfaces:**
- Consumes: the approved `cards/kiosk.md` (dimensions, pieces, slots, joints).
- Produces, for each piece `<p>`:
  - `assets/eclipse/lab/<p>.glb`: material slots named exactly as the card's slots, one UV map inside [0, 1]
  - `assets/eclipse/lab/<p>.blend`: the source, for the user's edits
  - `assets/eclipse/lab/<p>_ao.png`: baked AO at atlas size
  - `assets/eclipse/lab/<p>_regions.png`: each UV island filled with its slot's index colour, `(index * 16, 0, 0)`
  - `assets/eclipse/lab/<p>_regions.json`: the list of slot names by index
- Also produces:
  - `gate.check(faces: list[dict], tris: int, uvs: list[tuple[float, float]]) -> list[str]`: problem descriptions, empty when clean. Faces are in `overlap.py`'s shape, one owner per object.
  - `common.dump_faces(objects) -> list[dict]`
  - `common.export_piece(name: str, atlas_px: int)`: does the UV pack, the AO and region bakes, the glb and the blend.
  - `lab.sh <piece>|all|test|joints <piece>`, the runner.

- [ ] **Step 1: Write the failing tests** in `tools/eclipse/test_gate.py` (pure Python):
  - `test_clean_piece_passes`: two boxes touching edge to edge give no problems.
  - `test_coplanar_overlap_fails`: two quads sharing a plane and half their area give one "overlap" problem naming both owners.
  - `test_triangle_budget`: 2,501 triangles gives "over budget".
  - `test_uv_outside`: a UV at (1.02, 0.5) gives "uv outside".
  - `test_degenerate_face`: a face under 1e-6 m² gives "degenerate".
- [ ] **Step 2: Run them and see them fail.** Run `python3 tools/eclipse/test_gate.py`. Expected: module `gate` not found.
- [ ] **Step 3: Implement `tools/eclipse/gate.py`.** It uses `overlap.fights` from `tools/level/overlap.py` (via `sys.path`), with `BUDGET = 2500`, `GRID = 0.25` and `LEAST_AREA = 1e-6`.
- [ ] **Step 4: Run the tests and see them pass.** Run `python3 tools/eclipse/test_gate.py`. Expected: OK.
- [ ] **Step 5: Implement `tools/eclipse/common.py` and `tools/eclipse/kiosk.py`.**
  - Model the kiosk from the card with bmesh, origin at the stair head's centre on the street level, Y up on export.
  - Object names come from the card's pieces. The fret frieze is real geometry. The canopy glass is single-sided with its own `glass` slot.
  - `kiosk.py` ends with `common.export_piece("kiosk", 512)`, then runs `gate.check` on the dumped faces and exits non-zero on any problem.
  - `lab.sh kiosk` runs `$BLENDER -b --factory-startup --python tools/eclipse/kiosk.py`, then `"$GODOT" --headless --path . --import`, so Godot imports the new glb and PNGs before any map loads them.
- [ ] **Step 6: Run the build and see the gate pass.** Run `tools/eclipse/lab.sh kiosk`. Expected:
  - prints `kiosk: clean, <n> tris` with n ≤ 2500
  - the five outputs exist in `assets/eclipse/lab/`
- [ ] **Step 7: Render the joints.** Add `lab.sh joints <piece>`: Blender Eevee, a flat daylight sun, one 768 × 768 close-up per joint listed in the card, written to `/tmp/eclipse-joints/<piece>_<joint>.png`. Run `tools/eclipse/lab.sh joints kiosk`. Look at every image yourself. Fix any gap, seam or interpenetration and re-run Steps 6-7 until there are none.
- [ ] **Step 8: Commit**

```bash
git add tools/eclipse assets/eclipse/lab/kiosk.*
git commit -m "feat(eclipse city): the Metro kiosk modelled from its card, and the geometry gate"
```

---

### Task 4: The arcade bay

**Files:**
- Create: `tools/eclipse/arcade_bay.py`
- Modify: `tools/eclipse/lab.sh` (`arcade_bay` and `all`)

**Interfaces:**
- Consumes: `common.export_piece`, `gate.check` (Task 3); the approved `cards/arcade_bay.md`.
- Produces: the five `assets/eclipse/lab/arcade_bay.*` outputs, as in Task 3.

- [ ] **Step 1: Implement `tools/eclipse/arcade_bay.py`** from the card.
  - **Modelling:** one bay on the 0.25 m grid, with the two half-columns at its sides cut on the bay's edges so bays tile edge to edge. The seeped steel column replaces the bay's left column, and rivets are geometry only where seen from the arcade floor.
  - **Tiling check:** a second bay placed 4.5 m along X must pass `gate.check` together with the first. Build both in the script, check both, then export one.
- [ ] **Step 2: Run the build and see the gate pass.** Run `tools/eclipse/lab.sh arcade_bay`. Expected: `arcade_bay: clean, <n> tris` with n ≤ 2500, and `arcade_bay: two bays clean`.
- [ ] **Step 3: Render the joints and fix what they show.** Run `tools/eclipse/lab.sh joints arcade_bay`, with the card's joints plus the bay-to-bay seam. Fix and re-run until clean.
- [ ] **Step 4: Commit**

```bash
git add tools/eclipse/arcade_bay.py tools/eclipse/lab.sh assets/eclipse/lab/arcade_bay.*
git commit -m "feat(eclipse city): the Zócalo arcade bay, its seeped steel column, tiling clean"
```

---

### Task 5: The painted atlases

**Files:**
- Create: `tools/textures/eclipse_atlas.py`
- Create: `tools/textures/test_eclipse_atlas.py`
- Create: `tools/textures/recipes/eclipse/<slot>.json`, one per slot used by the two cards
- Modify: `tools/level/level.sh` (`test)` gains the new test)

**Interfaces:**
- Consumes: `<p>_ao.png`, `<p>_regions.png`, `<p>_regions.json` (Task 3); `palette_zocalo.png` (Task 2).
- Produces: `textures/painted/eclipse/<p>_base.png` at the atlas size. It never writes `<p>.png`, which is the user's overpaint.
- Slot recipe: `{"base": "#hex", "light": "#hex", "dark": "#hex", "grime": 0.0-1.0, "wear": 0.0-1.0, "mottle": int}`.

- [ ] **Step 1: Write the failing tests** in `tools/textures/test_eclipse_atlas.py`. Each uses a synthetic 64 × 64 region map (two slots) and an AO map:
  - `test_regions_take_their_slot_colours`: each region's median colour is within 24 of its recipe's base.
  - `test_ao_darkens`: pixels under AO 0.3 are darker on average than pixels under AO 1.0.
  - `test_grime_rises_from_the_bottom`: with `grime` 1, the bottom quarter of a region (lowest V) is darker than its top.
  - `test_never_writes_the_users_file`: with `<p>.png` already present, a run leaves its bytes unchanged and writes `<p>_base.png`.
  - `test_deterministic`: two runs are byte-identical.
- [ ] **Step 2: Run them and see them fail.** Run `python3 tools/textures/test_eclipse_atlas.py`. Expected: module not found.
- [ ] **Step 3: Implement `paint_atlas(piece: str, lab_dir: Path, out_dir: Path) -> Path`** in `tools/textures/eclipse_atlas.py`. It paints at 4× and then shrinks, as `paint.py` does. For each slot region:
  - fill with base mottled toward light and dark (`azulejo`-style strokes, `mottle` dabs per 64 px²)
  - multiply by AO
  - darken toward the region's lowest V by `grime`
  - lighten region edges by `wear`
  - finish with `_finish` cut to 64 colours (not to the 16-colour palette: the shader does that)
- [ ] **Step 4: Run the tests and see them pass.** Run `python3 tools/textures/test_eclipse_atlas.py`. Expected: OK.
- [ ] **Step 5: Paint both atlases and look at them.** Run `python3 tools/textures/eclipse_atlas.py kiosk arcade_bay`. Open both PNGs. Every region must read as its material (tezontle red-porous, chiluca grey, lime-washed plaster, iron, brass). Adjust the recipes until it does.
- [ ] **Step 6: Commit**

```bash
git add tools/textures/eclipse_atlas.py tools/textures/test_eclipse_atlas.py tools/textures/recipes/eclipse textures/painted/eclipse/*_base.png tools/level/level.sh
git commit -m "feat(eclipse city): the lab's painted atlases, the kiosk and the arcade bay"
```

---

### Task 6: The lab map, its suite and its stills

**Files:**
- Create: `maps/style_lab.gd`, `maps/style_lab.tscn`
- Create: `tests/style_lab_test.gd`, `tests/style_lab_test.tscn`
- Create: `tests/style_lab_stills.gd`, `tests/style_lab_stills.tscn`

**Interfaces:**
- Consumes: `Painterly.material`, `Painterly.PRESETS` (Task 2); `assets/eclipse/lab/*.glb` (Tasks 3-4); `textures/painted/eclipse/<p>.png` or `<p>_base.png` (Task 5).
- Produces:
  - `StyleLab.STATIONS`: `[&"painted_led", &"even", &"shader_led"]`, each station at x = -20, 0, +20 m.
  - `StyleLab.atlas_for(piece: StringName) -> Texture2D`: the user's `<p>.png` if present, else `<p>_base.png`, else null with a warning naming the missing file.
  - `StyleLab.set_day(day: bool) -> void`
  - `StyleLab.missing: PackedStringArray`

Layout (design values):
- A 70 × 30 m paved ground (a flat basalt-grey quad, painterly `even`).
- Each station: one kiosk and three arcade bays in a row behind it at 8 m, the bays tiled 4.5 m apart.
- A Company lamp placeholder (an OmniLight3D, warm `#e8d8a8`, range 12 m) at each kiosk's lamp standards.
- Night: `Retro.night_environment()` plus a cold DirectionalLight3D moon (`#d8e4f0`, energy 0.35, 50° elevation).
- Day: a ProceduralSky environment and a sun at energy 1.0 for the daylight check.
- F11 toggles day and night.
- The player spawns at (0, 0, 14) facing the stations, as `maps/retro_showcase.gd` places its player.

- [ ] **Step 1: Write the failing suite** `tests/style_lab_test.gd`:
  - **L1:** the map loads with three stations, each with 1 kiosk and 3 bays.
  - **L2:** every non-glass surface of every lab mesh in station k uses a ShaderMaterial with that station's preset `paint_mix` (0.25, 0.5, 0.85).
  - **L3:** every `glass` slot surface uses a translucent StandardMaterial3D (`transparency` ALPHA, albedo alpha ≤ 0.5), not the painterly shader.
  - **L4:** `set_day(true)` swaps in an environment with a sky and the sun at energy 1.0; `set_day(false)` swaps them back.
  - **L5:** with `textures/painted/eclipse/kiosk.png` absent and `kiosk_base.png` present, `atlas_for(&"kiosk")` loads `_base`. With a temp `kiosk.png` written to `user://` and its path override set (`StyleLab.atlas_dir`), it loads the user's file.
  - **L6:** with `StyleLab.lab_dir` pointed at an empty folder, the map loads without a script error, and `missing` names the two glbs.
- [ ] **Step 2: Run it and see it fail.** Run `tools/run_suites.sh tests/style_lab_test.tscn`. Expected: script error, `style_lab.gd` missing.
- [ ] **Step 3: Implement `maps/style_lab.gd`** (`class_name StyleLab`, with `lab_dir` and `atlas_dir` variables defaulting to `res://assets/eclipse/lab/` and `res://textures/painted/eclipse/`) and `maps/style_lab.tscn`, to the Interfaces and layout above.
- [ ] **Step 4: Run the suite and see it pass.** Run `tools/run_suites.sh tests/style_lab_test.tscn`. Expected: L1-L6 PASS, no ERROR lines.
- [ ] **Step 5: Implement `tests/style_lab_stills.gd`**, in the manner of `tests/city_stills.gd`. It takes `--out=` and `--only=`. For each station, by night and by day, it writes these 1920 × 1080 stills:
  - `front` at 9 m
  - `arcade` from under the arcade looking along the bays
  - `kiosk_close` at 2.5 m
  - `far` at 30 m
  - `grazing` along the bay façade at 10°

  It also prints, for each station's `front` view by night, the mean frame time over 240 frames with the painterly materials, and again with the same meshes on plain StandardMaterial3D (the spec's frame-rate gate). The painterly mean must be within 1.5 ms of the plain one.
- [ ] **Step 6: Capture.** Run:

```bash
"$GODOT" --path . --resolution 1920x1080 res://tests/style_lab_stills.tscn -- --out=/tmp/style-lab
```

  Expected: 30 PNGs (3 stations × 2 lights × 5 views), and three frame-time lines each within 1.5 ms of the plain baseline.
- [ ] **Step 7: Run the whole suite list** with `tools/run_suites.sh`, to check nothing else broke. Expected: the same pass counts as before this branch plus the two new suites.
- [ ] **Step 8: Commit**

```bash
git add maps/style_lab.* tests/style_lab_test.* tests/style_lab_stills.*
git commit -m "feat(eclipse city): the style lab, three blends side by side, night and day"
```

---

### Task 7: The user's verdict fixes the pipeline

**Files:**
- Modify: `docs/superpowers/specs/2026-10-09-eclipse-city-frame-design.md` (section 7.2 gains "Result")
- Modify: `scripts/Visual/Painterly.gd` (`PRESETS` gains `&"house"`, the chosen values)

Note: the lab's moon is a plain cold light. The cornered eclipse moon is frame step 4 and is not built here.

- [ ] **Step 1: Show the user** the 30 stills, contact-sheeted by view, and the command to walk the lab:

```bash
"$GODOT" --path . res://maps/style_lab.tscn
```

  Ask for their choice: one station, or adjusted values. They may also overpaint `textures/painted/eclipse/kiosk.png` / `arcade_bay.png` in Krita. The lab picks those files up with no rebuild.
- [ ] **Step 2: Apply the choice.**
  - Add `&"house"` to `PRESETS` with the chosen `paint_mix` and `stroke_strength`, plus any atlas size or texel density change.
  - Write the section 7.2 "Result" in the spec: the preset values, atlas size, texel density, what is painted versus what the shader adds, and the palette per district (Zócalo fixed; Lomas and Roma to be painted the same way when their specs come).
  - Re-run `tools/run_suites.sh tests/painterly_test.tscn tests/style_lab_test.tscn`. Expected: PASS.
- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-10-09-eclipse-city-frame-design.md scripts/Visual/Painterly.gd textures/painted/eclipse
git commit -m "docs(eclipse city): the style lab's result fixes the texturing pipeline"
```
