# Eclipse vertex paint, macro variation and hex-tiling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Break the style lab's 1-2 m repetition with rule-baked, user-editable vertex paint (grime, material blend, tint, baked light), an under atlas, a world-space macro layer, hex-tiling, and a real painted ground.

**Architecture:** The Blender kit builder densifies each piece and bakes RGBA vertex colours from pure-numpy rules (`weather_rules.py`) fed by ray measurements (`weather.py`), merges the user's harvested touch-ups, and exports `COLOR_0`. The atlas painter adds an under layer per piece and paints seamless ground tiles. The painterly shader reads the vertex colour, the under atlas, a macro tile and hex-tiled samples; `Ground.gd` builds a vertex-painted ground; the lab wires it all with live toggles.

**Tech Stack:** Blender 5.2 bpy/bmesh/mathutils (BVHTree, KDTree), Python 3 + numpy + Pillow, Godot 4.5.1 GDScript and spatial shaders.

**Spec:** `docs/superpowers/specs/2026-10-09-eclipse-vertex-paint-design.md`

## Global Constraints

- Branch `eclipse-city`; commit per task; messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Repo is public: only CC0 or self-made textures committed; raw scans stay in gitignored `textures/scans/`; new scans credited in `CREDITS.md`.
- Never download free VFX; macro and brush tiles are drawn by our code.
- No brush-stroke normals anywhere (strokes, blend lip and tint are colour only).
- Look stays shader-led variant D; smooth filtering (LINEAR_WITH_MIPMAPS); 480-line grid.
- Kit pieces stay closed and solid; geometry gate stays strict (3 cm layers, coplanar overlap, slivers, UV range, atlas clashes); triangle budget **5000** per piece.
- Grid **0.5 m**, world-aligned; story-line cuts within **2 cm** of a grid line snap to it; no face thinner than **2 cm**.
- Rules: damp to **1.2 m**, soot plume **1.5 m**, streak reach **2 m**, AO **24 rays**, reach **3 m**, deterministic (seeded by piece name).
- Touch-up match: **1 mm** position, facing dot **> 0.99**, touched = differs from its starting copy by **> 1/255**.
- `vertex_paint` uniform default **0**, giving exactly today's image; `macro_amount` 0 and `hex_tiling` 0 likewise switch their layers off.
- Macro scales **23 m** and **7.3 m**; macro shifts Oklab lightness by at most **±6%**.
- Lab keys: **F1** vertex paint, **F2** macro, **F4** hex-tiling; F11 stays day/night; F3, F6-F8, F10 are taken globally.
- `tezontle` as the `lime` under layer is a **stand-in**: say so in every caption and the ledger; never call it finished.
- Never `rm` with an unguarded shell variable; use literal paths or `"${D:?}"`.
- Godot binary: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`; Blender: `/Applications/Blender.app/Contents/MacOS/Blender`. Headless suites: `perl -e 'alarm 280; exec @ARGV' $G --headless --fixed-fps 60 --path . res://tests/<suite>.tscn`; pixel suites run windowed: `$G --path . --resolution 640x360 res://tests/painterly_pixels.tscn`.

## Review Focus

1. **A mesh with no vertex colours under a material with vertex paint on**: Godot reads `COLOR` as white (1,1,1,1), which would mean full grime, full blend and full bleach. Expected: it looks exactly as today. Owner: Task 6, which enables `vertex_paint` only on meshes that carry colours (`Painterly.has_vertex_colours`); test L11b.
2. **First build, or an old .blend without `yours_*` layers, or no .blend at all**: the build proceeds on rules alone and leaves any saved npz untouched. Owner: Task 3, `test_harvest_without_layers_keeps_saved`.
3. **Float drift after a rebuild** (vertex positions differing by fractions of a millimetre): the user's strokes still land. Owner: Task 3, `test_apply_matches_within_a_millimetre`.
4. **Hex-tiling mip seams**: derivatives broken across hex borders draw lines at a distance. Expected: no lines; sample with `textureGrad` on the unrotated, then rotated, derivatives. Owner: Task 7, X13.
5. **Soot empties exported into the glb** as stray nodes. Expected: they are baked, then deleted before export. Owner: Task 4, `test_no_soot_nodes_exported`.

---

### Task 1: The rules (pure numpy)

**Files:**
- Create: `tools/eclipse/weather_rules.py`
- Create: `tools/eclipse/test_weather_rules.py`
- Modify: `tools/eclipse/lab.sh` (the `test)` case also runs `python3 "$HERE/test_weather_rules.py"`)
- Modify: `tools/level/level.sh` (the `test)` list gains `python3 "$HERE/../eclipse/test_weather_rules.py"`)
- Modify: `docs/superpowers/specs/2026-10-09-eclipse-vertex-paint-design.md` (sections 3 and 7: the source .blend lives at `assets/eclipse/source/<piece>.blend`, not `tools/eclipse/source/`)

**Interfaces:**
- Produces, all arrays numpy float64, n vertices, Blender Z-up piece space:
  - constants `DAMP = 1.2`, `SOOT_HEIGHT = 1.5`, `STREAK_REACH = 2.0`, `STREAK_COLUMN = 0.25`, `SUN = normalise((-0.369, -0.527, 0.766))` (the lab sun's toward-vector in Blender axes), `WEAR_REACH = 0.3`, `CAVITY_REACH = 0.12`
  - `grime(points, floor_gap, concave, soot, seed) -> (n,)`, where `floor_gap` is the distance down to the floor below (inf if none) and `soot` is a list of `(3,)` plume origins
  - `blend(points, floor_gap, convex, blendable, seed) -> (n,)`, where `blendable` is a `(n,)` bool
  - `tint(points, normals, overhang_gap, seed) -> (n,)`, where `overhang_gap` is the distance up to a down-facing face (inf if none) and 0.5 is neutral
  - `light(open_sky, normals) -> (n,)`, where `open_sky` is the AO fraction 0-1 and a little warm bounce goes on down-facing normals; never above 1
  - `rules(points, normals, floor_gap, overhang_gap, convex, concave, open_sky, blendable, soot, seed) -> (n, 4)`, RGBA clipped to 0-1
  - `seed_of(name: str) -> int`, from `zlib.crc32`

- [ ] **Step 1: Write the failing tests** in `test_weather_rules.py` (unittest; build small synthetic arrays)

```python
class Grime(unittest.TestCase):
    def test_grime_falls_with_height(self):        # points up a wall, floor_gap = z
        g = weather_rules.grime(pts_up_wall, z, zeros, [], 1)
        self.assertGreater(g[z < 0.2].mean(), 0.7); self.assertLess(g[z > 1.5].max(), 0.05)
    def test_soot_rises_over_its_origin_only(self):
        # a vertex 0.5 m above a soot origin > 0.3; 0.5 m below it == 0; 2 m above it == 0
    def test_concave_adds_grime(self):              # same point, concave 1 vs 0: higher with
class Blend(unittest.TestCase):
    def test_blend_zero_where_not_blendable(self)
    def test_blend_at_wall_foot_and_convex_edges(self) # floor_gap 0.1 -> > 0.5; convex 1 at z 2 -> > 0.5
class Tint(unittest.TestCase):
    def test_streak_hangs_under_an_overhang(self)   # some column with overhang_gap 0.3 < 0.4; the same column, overhang_gap inf, >= 0.5
    def test_up_faces_bleach_more_than_down_faces(self)
    def test_neutral_on_a_plain_wall(self)           # vertical, facing away from SUN, no overhang: within 0.05 of 0.5
class Light(unittest.TestCase):
    def test_occluded_darker_than_open(self)        # open_sky 0.3 vs 1.0
    def test_never_brightens(self)                   # max <= 1
class Rules(unittest.TestCase):
    def test_rules_shape_range_and_determinism(self) # (n,4), 0..1, same seed -> identical, other seed -> differs somewhere
```

- [ ] **Step 2: Run to see them fail**

Run: `python3 tools/eclipse/test_weather_rules.py`
Expected: ImportError / FAIL (no module `weather_rules`).

- [ ] **Step 3: Implement `weather_rules.py`**

The damp top edge is ragged with a seeded 1D value noise along `x + y` (period about 0.6 m, ±0.25 m). The soot plume is a cone, radius `0.2 + 0.3*dz/SOOT_HEIGHT`, fading with `dz`. Streak columns hash `floor((x + y) / STREAK_COLUMN)` with the seed to a strength in 0.3-1 and a length in 0.6-2 m; `tint = 0.5 - 0.35*strength*(1 - gap/length)` where gap < length. Bleach adds `0.2*max(n.z, 0) + 0.1*max(dot(n, SUN), 0)`. Grime, blend and tint are each broken by the same seeded noise so they read as patches, not bands. No randomness beyond `np.random.default_rng(seed)`.

- [ ] **Step 4: Run tests to pass**

Run: `python3 tools/eclipse/test_weather_rules.py`
Expected: OK.

- [ ] **Step 5: Commit**: `feat(kit): the weathering rules: grime, blend, tint, baked light from measurements`

---

### Task 2: Densify and measure in Blender (weather.py)

**Files:**
- Create: `tools/eclipse/weather.py`
- Create: `tools/eclipse/test_weather_bpy.py` (run inside Blender)
- Modify: `tools/eclipse/lab.sh` (the `test)` case also runs `"$BLENDER" -b --factory-startup --python "$HERE/test_weather_bpy.py"`; the script exits non-zero on failure via `sys.exit(not result.wasSuccessful())`)

**Interfaces:**
- Consumes: `weather_rules.rules`, `weather_rules.seed_of` (Task 1); `common.Mesh` to build test objects.
- Produces:
  - `GRID = 0.5`, `SNAP = 0.02`
  - `densify(objects, lines=(), grid=GRID, coarse=None) -> None`, where `lines` is a list of `(axis: "x"|"y"|"z", value: float)` story lines and `coarse` is `{object_name: grid}`. It runs `bmesh.ops.bisect_plane` on every world-aligned grid plane crossing each object, plus every story line (snapped to a grid line within `SNAP`). Planes are global per object, so no T-junctions. Loop UVs are interpolated by bmesh.
  - `measure(objects) -> dict` of per-object arrays: `points`, `normals`, `floor_gap`, `overhang_gap`, `convex`, `concave`, `open_sky` (n,), in object order, per vertex.
    - The BVHTree covers all objects.
    - `floor_gap`: a ray down to an up-facing face (normal z > 0.7), or `z` if z >= 0 and nothing is hit.
    - `overhang_gap`: a ray up to a down-facing face (normal z < -0.7), inf if none.
    - `convex` / `concave`: from dihedral angles on a welded copy (remove_doubles 1e-4), as proximity 0-1 within `WEAR_REACH` / `CAVITY_REACH`.
    - `open_sky`: 24 cosine-weighted rays from point + normal*1e-3, reach 3 m, seeded.
  - `bake(objects, name, blendable_slots=(), soot=None) -> None`: writes the point-domain `FLOAT_COLOR` attribute `rules` on each mesh from `weather_rules.rules`. `blendable` comes from each face's slot (material name) being in `blendable_slots`. `soot` defaults to the world locations of every empty named `soot_*`.

- [ ] **Step 1: Write the failing tests** in `test_weather_bpy.py` (unittest inside Blender; build objects with `common.Mesh`)

```python
def test_densify_keeps_area_and_cuts_to_grid(self):    # 3 x 2 m wall + 1 x 1 m slab
    # total area before == after (1e-6); every face edge <= 0.5 + 1e-6 except along story lines; all verts on the original planes
def test_story_line_snaps_to_grid(self):               # line z 1.49 -> a cut at 1.5, no face thinner than 0.02
def test_coarse_object_uses_its_own_grid(self)         # coarse={"stairs": 1.0}: no edge > 1.0, fewer faces than at 0.5
def test_measure_floor_and_overhang(self)              # wall with a sill slab above: wall vertex under the sill has overhang_gap ~ sill height - z
def test_soffit_darker_than_open_wall(self)            # an arch-like box tunnel: inside-ceiling open_sky < outside-wall open_sky - 0.2
def test_bake_writes_rules_attribute(self)             # attribute "rules", POINT, len == vertex count, values within 0..1
def test_bake_is_deterministic(self)                   # two bakes of identical scenes: equal arrays
```

- [ ] **Step 2: Run to see them fail**

Run: `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/eclipse/test_weather_bpy.py`
Expected: ImportError for `weather`, non-zero exit.

- [ ] **Step 3: Implement `weather.py`** with the interfaces above. `sys.path` gets the script's folder as `common.py` does.

- [ ] **Step 4: Run tests to pass** (same command, exit 0)

- [ ] **Step 5: Commit**: `feat(kit): densify on a world grid, measure floors, overhangs, edges and sky per vertex`

---

### Task 3: The user's touch-ups (harvest and apply)

**Files:**
- Modify: `tools/eclipse/weather.py`
- Create: `tools/eclipse/harvest.py` (runs inside Blender on an existing piece .blend)
- Create: `tools/eclipse/yours/.gitkeep`
- Modify: `tools/eclipse/test_weather_bpy.py`
- Modify: `tools/eclipse/lab.sh` (`piece()` first runs `"$BLENDER" -b "$ROOT/assets/eclipse/source/$1.blend" --python "$HERE/harvest.py" -- "$1"` when that file exists)

**Interfaces:**
- Consumes: the `rules` attribute (Task 2).
- Produces:
  - `LAYERS = ("yours_grime", "yours_blend", "yours_tint", "yours_light")` (channel order R, G, B, A); `YOURS = HERE / "yours"`
  - `paint_layers(objects) -> None`: writes the four point-domain `BYTE_COLOR` greyscale layers, each a copy of its `rules` channel as grey, plus hidden copies `start_grime`, `start_blend`, `start_tint`, `start_light`.
  - `harvest(objects, name) -> int`: for every vertex where a layer differs from its start copy by > 1/255, records object name, local position, vertex normal, channel and value. It merges with any existing `YOURS/<name>.npz` (new strokes replace old at the same key), saves, and returns the number of touched values. With no layers present it returns 0 and leaves the npz alone.
  - `apply(objects, name) -> list[str]`: loads `YOURS/<name>.npz` (none: `[]`). It matches by object name + KDTree within 1 mm + normal dot > 0.99, and writes the user's values over `rules` channel by channel. It returns one line per unmatched stroke: `"<object> (x, y, z): <channel> lost"`.
  - `harvest.py`: opens nothing itself (Blender was started on the .blend), calls `harvest(meshes, name)`, prints `harvest: <name> <n> touched values`.
  - `PAINTING_NOTE` text written by `paint_layers` callers (Task 4) to `assets/eclipse/source/PAINTING.md`: which layer is which story (R grime and soot, G wear-through to the under layer, B tint with mid grey neutral / darker damp / lighter bleach, A baked light), to paint in Vertex Paint mode on the `yours_*` layer, to leave `start_*` alone, then run `tools/eclipse/lab.sh <piece>`.

- [ ] **Step 1: Write the failing tests** in `test_weather_bpy.py`

```python
def test_paint_layers_start_as_rules(self)              # yours_tint grey == rules B
def test_stroke_survives_a_rebuild(self):              # paint yours_grime=1.0 on one vertex, harvest, rebuild scene, bake, apply: that vertex R == 1.0, its neighbour unchanged
def test_apply_matches_within_a_millimetre(self)       # rebuilt vertex moved 0.4 mm: still applied; moved 3 mm: reported lost
def test_removed_vertex_is_reported(self)              # apply() returns one "... grime lost" line
def test_harvest_without_layers_keeps_saved(self)      # npz exists, objects without yours_* -> returns 0, npz bytes unchanged
def test_untouched_vertices_follow_new_rules(self)     # change a rule input, rebake + apply: untouched vertex takes the new value
```

Tests write to a temp `YOURS` (patch `weather.YOURS`), never the real folder.

- [ ] **Step 2: Run to see them fail** (Blender test command): AttributeError on `paint_layers`.
- [ ] **Step 3: Implement** the interfaces and `harvest.py`.
- [ ] **Step 4: Run tests to pass**.
- [ ] **Step 5: Commit**: `feat(kit): the user's vertex paint touch-ups: four greyscale layers, harvested and laid over the rules`

---

### Task 4: Export with vertex colour; rebuild the lab pieces

**Files:**
- Modify: `tools/eclipse/common.py` (`export_piece`)
- Modify: `tools/eclipse/gate.py` (`BUDGET = 5000`, plus a sliver rule: no face whose shortest altitude is < 0.02 m)
- Modify: `tools/eclipse/test_gate.py`
- Modify: `tools/eclipse/kiosk.py`, `tools/eclipse/arcade_bay.py` (declare `WEATHER` and place `soot_*` empties)
- Modify: `tools/eclipse/test_weather_bpy.py`
- Create: `tests/vertex_colour_import.gd`, `tests/vertex_colour_import.tscn` (headless)
- Regenerate: `assets/eclipse/lab/*.glb`, `assets/eclipse/source/*`

**Interfaces:**
- Consumes: `weather.densify`, `measure`, `bake`, `paint_layers`, `apply` (Tasks 2-3).
- Produces:
  - `export_piece(name, atlas_px, slots, merge=None, gate_sets=None, share=None, weather=None)`, where `weather` is a dict `{"lines": [...], "coarse": {...}, "blendable": [slot names]}`.
    - After the clash check and before the glTF export, it runs `densify` → `bake` → `apply` (lost strokes printed as `"<name>: " + line`) → `paint_layers`, and writes `PAINTING.md` (Task 3).
    - `apply` writes the user's values into `rules` itself; `rules` is made the active and render colour, so it is what goes out as `COLOR_0`.
    - It deletes the `soot_*` empties.
    - The exporter gets the active-colour option. Look up the exact parameter name for Blender 5.2 in the bundled API docs (`export_vertex_color="ACTIVE"` in 4.2+).
  - Kiosk `WEATHER = {"lines": [("z", 0.3), ("z", 1.2)], "coarse": {<the stair blocks' object>: 1.0}, "blendable": ["iron", "stone_step"]}`, with `soot_*` over each lamp anchor.
  - Arcade bay `WEATHER = {"lines": [("z", 0.3), ("z", 1.2), ("z", <sill - 0.05>), ("z", <cornice underside>), ("x", <each door jamb's x>), ("z", <door head>)], "blendable": ["lime", "iron"]}`, with `soot_*` over each door opening's head (the jamb and head lines are the spec's cuts round each opening).
  - `vertex_colour_import.gd` loads `res://assets/eclipse/lab/kiosk.glb`. It finds the vertex nearest a known piece position (the first riser's foot, from `kiosk.py`) and checks two things: the mesh has `ARRAY_COLOR`, and that vertex's colour matches the value printed by the Blender build for it (`kiosk: probe <r g b a>`) within 2/255, once read as linear and once as sRGB. It records which of the two matched as `const VERTEX_COLOUR_SRGB := true|false` in `scripts/Visual/Painterly.gd`, for Task 6.

- [ ] **Step 1: Write the failing tests**
  - `test_gate.py`: `test_budget_is_5000` and `test_sliver_under_2cm_fails` (a 1 m x 1 cm quad gives a "sliver" problem).
  - `test_weather_bpy.py`: `test_no_soot_nodes_exported` (export a test piece with a `soot_a` empty; the glb's JSON nodes hold no name starting `soot_`) and `test_export_has_color_0` (the glb's primitives carry `COLOR_0`).
  - `tests/vertex_colour_import.gd`: checks V1 (the mesh has colours) and V2 (the probe colour matches in one colour space).
- [ ] **Step 2: Run to see them fail**: `python3 tools/eclipse/test_gate.py`; the Blender test command; `$G --headless --path . res://tests/vertex_colour_import.tscn` (V1 FAIL: no colours).
- [ ] **Step 3: Implement** the export changes and the pieces' `WEATHER`; print the probe in `kiosk.py`.
- [ ] **Step 4: Rebuild and verify**
  - `tools/eclipse/lab.sh all` exits 0: gate clean, each piece ≤ 5000 triangles, no "lost" lines.
  - All three tests pass.
  - `style_lab_test` L7 (stair walk), L8 (hole scan) and L9 (back of building) still PASS on the densified meshes.
- [ ] **Step 5: Commit**: `feat(kit): the lab pieces densified, weathered and exported with vertex colour`

---

### Task 5: The under atlas

**Files:**
- Modify: `tools/textures/eclipse_atlas.py`
- Modify: `tools/textures/test_eclipse_atlas.py`
- Modify: `tools/textures/recipes/eclipse/lime.json` (`"under": "tezontle"`), `iron.json` (inline `under`: `scan` `metal_plate_02`, tint 0.9, contrast 0.8, with base/dark/light greys of bare steel), `stone_step.json` (inline `under`: the same scan with a lighter `base` and contrast 0.7)
- Regenerate: `textures/painted/eclipse/{kiosk,arcade_bay}_under.png`, `_under_normal.png`

**Interfaces:**
- Produces:
  - `under_recipe(recipes: dict, slot: str) -> dict | None`: a string names another recipe (loaded with `load_recipes`); a dict is the slot's recipe updated with that block; absent gives None.
  - `paint_atlas(...)` additionally writes `<piece>_under.png` and `<piece>_under_normal.png`. The under pass paints with each slot's under recipe. Afterwards, every texel whose slot has no under recipe is copied from the top images, using the slot index grown by the same margin the top uses.

- [ ] **Step 1: Write the failing tests** in `test_eclipse_atlas.py` (on the existing synthetic fixture)
  - `test_under_atlases_written`
  - `test_slot_without_under_copies_top` (texels exactly equal)
  - `test_slot_with_under_differs` (mean Oklab distance > 0.05)
  - `test_under_recipe_by_name_and_inline`
- [ ] **Step 2: Run to see them fail**: `python3 tools/textures/test_eclipse_atlas.py`.
- [ ] **Step 3: Implement** the interfaces and the recipe edits.
- [ ] **Step 4: Run tests, then repaint**: `python3 tools/textures/eclipse_atlas.py kiosk arcade_bay` writes all four images per piece.
- [ ] **Step 5: Commit**: `feat(look): the under atlas: what the plaster and paint wear through to (tezontle a stand-in)`

---

### Task 6: The shader reads the vertex paint

**Files:**
- Modify: `scripts/Visual/painterly.gdshaderinc`
- Modify: `scripts/Visual/Painterly.gd`
- Modify: `tests/painterly_pixels.gd`
- Modify: `tests/style_lab_test.gd`

**Interfaces:**
- Consumes: `Painterly.VERTEX_COLOUR_SRGB` (Task 4); the under atlases (Task 5).
- Produces:
  - Uniforms, with defaults that keep today's image:
    - `under_atlas` and `under_normal`, sampled the same way as `atlas` and `normal_atlas`; when unset they default to `atlas` (Painterly.material sets them).
    - `vertex_paint` = 0, `blend_edge` = 0.06, `blend_break` = 0.5, `tint_amount` = 0.5, `grime_amount` = 0.6, `grime_colour` = palette dark brown `#3d1f1c`, `baked_light_amount` = 1.0.
    - A varying `baked_light`, read in `light()`: the lambert × attenuation input is multiplied by `mix(1.0, baked_light, vertex_paint*baked_light_amount)`. Painted ambient `EMISSION` is multiplied by the same factor.
  - Fragment order before the palette match: blend (G) → tint (B, in Oklab) → grime (R). `edge = smoothstep(0.5 - blend_edge, 0.5 + blend_edge, G + (s - 0.5)*blend_break)`. The lip is `1.0 - 0.25*smoothstep(0.0, blend_edge, edge)*smoothstep(1.0, 1.0 - blend_edge, edge)`, a darkening band, colour only. `NORMAL_MAP` mixes top to under by `edge`. Every effect is scaled by `vertex_paint`. If `VERTEX_COLOUR_SRGB`, convert `COLOR` to linear first.
  - `Painterly.material(atlas, preset, palette = ZOCALO, normal = null, under = null, under_normal = null) -> ShaderMaterial`
  - `static func has_vertex_colours(mesh: Mesh) -> bool`: true if any surface's arrays hold `ARRAY_COLOR`
  - Preset `shader_led` gains `"vertex_paint": 1.0`. The lab still disables it per mesh without colours (Review Focus 1).

- [ ] **Step 1: Write the failing pixel checks** in `painterly_pixels.gd`. They draw a quad mesh built with `SurfaceTool.set_color`, with a red under atlas and the checker top.
  - `X8 vertex_paint 0 reproduces today` (colours set to arbitrary values; image equals the plain draw within 1/255)
  - `X9 G = 1 shows the under atlas` (> 90% of pixels near red)
  - `X10 a G ramp gives a ragged edge` (the edge column's position varies across rows by > 3 px)
  - `X11 R darkens` (mean lightness drops > 0.1)
  - `X12 A pulls lit pixels toward the ramp's shadow` (on the lit sphere, A = 0.3 shifts mean colour toward the ramp's first stop)

  In `style_lab_test.gd`: `L11b a mesh without vertex colours keeps vertex paint off` (lab materials on colourless meshes have `vertex_paint` == 0).
- [ ] **Step 2: Run to see them fail** (pixel suite windowed; `style_lab_test` headless).
- [ ] **Step 3: Implement** the interfaces.
- [ ] **Step 4: Run** the pixel suite (X1-X12 PASS), `painterly_test`, `style_lab_test` and `retro_test`.
- [ ] **Step 5: Commit**: `feat(look): the painterly shader reads vertex paint: blend to the under layer, tint, grime, baked light`

---

### Task 7: Hex-tiling

**Files:**
- Modify: `scripts/Visual/painterly.gdshaderinc`
- Modify: `tests/painterly_pixels.gd`

**Interfaces:**
- Produces:
  - `vec4 hex_sample(sampler2D tex, vec2 uv, bool rotate)`
  - Uniform `hex_tiling` (0 or 1, default 0).
  - The brush's three triplanar lookups use `hex_sample(brush, ..., false)` when `hex_tiling` > 0.5.
  - Uniform `tiled` (0 or 1, default 0): when set, the atlas and under atlas are sampled with `hex_sample(..., true)`. The ground uses this; kit atlases never do.

Algorithm (after Mikkelsen 2022, JCGT 11(2); the implementer cannot derive it from the signature):

```glsl
vec2 hex_hash(vec2 p) {
	return fract(sin(mat2(vec2(127.1, 311.7), vec2(269.5, 183.3)) * p) * 43758.5453);
}

// The triangle of hex centres round st, and each one's weight.
void hex_grid(vec2 st, out vec3 w, out vec2 v1, out vec2 v2, out vec2 v3) {
	vec2 skewed = mat2(vec2(1.0, 0.0), vec2(-0.57735027, 1.15470054)) * (st * 3.46410162);
	vec2 base = floor(skewed);
	vec3 t = vec3(fract(skewed), 0.0);
	t.z = 1.0 - t.x - t.y;
	float s = step(0.0, -t.z);
	float s2 = 2.0 * s - 1.0;
	w = vec3(-t.z * s2, s - t.y * s2, s - t.x * s2);
	v1 = base + vec2(s, s);
	v2 = base + vec2(s, 1.0 - s);
	v3 = base + vec2(1.0 - s, s);
}

vec2 hex_centre(vec2 v) {
	return mat2(vec2(1.0, 0.0), vec2(0.5, 0.8660254)) * v / 3.46410162;
}
```

For each vertex `v`:
- `uv' = rot(a)*(uv - c) + c + hex_hash(v)`, where `c = hex_centre(v)` and `a = 2π * hex_hash(v + 7.0).x`, or 0 when not rotating.
- Sample with `textureGrad(tex, uv', rot(a)*dFdx(uv), rot(a)*dFdy(uv))`.

Weights: `W = w*w*w` scaled by `mix(1.0, luminance(sample_i), 0.6)`, then raised to 7, then normalised (Mikkelsen's contrast-preserving gain). Return `Σ W_i * sample_i`.

- [ ] **Step 1: Write the failing checks** in `painterly_pixels.gd`. A 40 × 40 m plane is drawn ortho from above with `tiled` = 1, its atlas a 64 px seeded noise tile at 1 m per tile.
  - `X13 plain tiling repeats at its period`: the correlation of the image with itself shifted one period exceeds 0.9 when `hex_tiling` = 0 and `tiled` = 0.
  - `X14 hex-tiling breaks the repeat`: the same correlation with hex on is < 0.5.
  - `X15 no seams at a distance`: on a grazing-angle draw, the 99th-percentile neighbour difference with hex is ≤ 1.5 × plain's.
- [ ] **Step 2: Run to see them fail** (X14 fails: the `hex_tiling` uniform does nothing).
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run** the pixel suite. All PASS.
- [ ] **Step 5: Commit**: `feat(look): hex-tiling (Mikkelsen 2022) for the brush and tiled grounds`

---

### Task 8: The world macro layer

**Files:**
- Modify: `tools/textures/painterly.py` (`macro()`, written by `main` to `macro.png`)
- Modify: `tools/textures/test_painterly.py`
- Modify: `scripts/Visual/painterly.gdshaderinc`, `scripts/Visual/Painterly.gd` (`const MACRO`, set in `material()`)
- Modify: `tests/painterly_pixels.gd`
- Create: `textures/painted/eclipse/macro.png`

**Interfaces:**
- Produces:
  - `macro(seed: int = 23) -> Image`: RGB, `MACRO_SIZE = 256`, seamless. R is value, G warmth, B grime, each with mean about 128. It is soft blotches at three sizes (cells 4, 9, 20 across the tile) with a light brush-tile break, so its energy is low-frequency.
  - Uniforms: `macro` (sampler, linear, repeat), `macro_amount` (default 0; `shader_led` preset 1.0), `macro_scales = vec2(23.0, 7.3)`.
    - Sample at `(world_pos.xz + vec2(world_pos.y*0.37, -world_pos.y*0.29)) / scale` for both scales and average.
    - Shift Oklab L by `(R - 0.5)*0.12*macro_amount`, which is at most ±6%.
    - Rotate hue a little by G.
    - Add `(B - 0.5)*0.3*macro_amount` to grime.
  - It applies after vertex paint and before the palette match.

- [ ] **Step 1: Write the failing tests**
  - `test_painterly.py` class `Macro`: `test_macro_is_seamless` (same metric as the brush), `test_macro_is_soft` (90% of spectral energy below 1/16 of Nyquist), `test_macro_channels_centred` (each mean within 6 of 128), `test_macro_is_deterministic`.
  - `painterly_pixels.gd`: `X16 identical quads at different world places differ through macro` (mean colours differ > 2/255 with `macro_amount` 1; equal within 1/255 with 0).
- [ ] **Step 2: Run to see them fail**.
- [ ] **Step 3: Implement**; run `python3 tools/textures/painterly.py` to write `macro.png`.
- [ ] **Step 4: Run** `test_painterly.py` and the pixel suite. All PASS.
- [ ] **Step 5: Commit**: `feat(look): the world macro layer: our own painted blotches at 23 m and 7.3 m`

---

### Task 9: The ground

**Files:**
- Modify: `tools/textures/fetch_scans.py` (add `"brown_mud_dry"`), `CREDITS.md` (its Poly Haven authors, as fetched in `info.json`)
- Create: `tools/textures/recipes/eclipse/ground_cobbles.json` (scan `cobblestone_floor_04`, basalt greys from the palette, `"under": "ground_earth"`), `ground_earth.json` (scan `brown_mud_dry`)
- Modify: `tools/textures/eclipse_atlas.py`, `tools/textures/test_eclipse_atlas.py`
- Create: `scripts/Visual/Ground.gd`
- Create: `tests/ground_test.gd`, `tests/ground_test.tscn` (headless)
- Create: `textures/painted/eclipse/ground_cobbles.png`, `ground_cobbles_normal.png`, `ground_earth.png`, `ground_earth_normal.png`

**Interfaces:**
- Produces:
  - `paint_tile(slot: str, px: int = 256, out_dir=OUT) -> Path`: writes `<slot>.png` and `<slot>_normal.png`. It builds a synthetic source in a temp dir: a flat up-facing plane spanning **two** periods of the slot's scan size (from its `info.json`), with `regions.json`, a `texels.npz` and a white `ao.png`. It runs the same painting over it, crops the central period, and closes the wrap with a 10% cosine cross-fade at the edges.
  - `class_name Ground extends StaticBody3D`
    - `static func build(area: Rect2, openings: Array[Rect2], footprints: Array[Dictionary], seed: int) -> Ground`. Footprints are `{"rect": Rect2, "roofed": bool}`, and the mesh is a 1 m grid.
    - UV is world xz divided by `TILE_M` (const, the cobble scan's 1.5).
    - Material: `Painterly.material(cobbles, &"shader_led", ZOCALO, cobbles_normal, earth, earth_normal)` with `tiled` 1, `hex_tiling` 1, `vertex_paint` 1.
    - Colliders: one `BoxShape3D` per grid cell row-run, 0.5 m deep, top at y 0. Same footprint as today's: no gaps, no overlap with openings.
  - Ground vertex rules, in Ground.gd (the same stories as the kit, measured in 2D):
    - R rises within 0.8 m of a footprint edge and in its corners.
    - G is wear-through along seeded walking lines between footprints' doors, round each opening's rim, and where `floor_gap` would be.
    - B is damp: seeded patches below 0.5.
    - A is 0.55 under roofed footprints and 0.85 within 0.5 m of a wall, otherwise 1.
    - Seeded by `seed`.

- [ ] **Step 1: Write the failing tests**
  - `test_eclipse_atlas.py`: `test_paint_tile_is_seamless` (on a synthetic scan fixture: wrap-edge difference < 1.5 × neighbour difference) and `test_paint_tile_sizes` (`px` square, normal map too).
  - `ground_test.gd` (headless):
    - G1 the mesh's openings hold no triangles
    - G2 every vertex has a colour and no grid edge is longer than 1 m
    - G3 grime is higher within 0.5 m of a footprint than 5 m away
    - G4 a roofed footprint's A is < 0.7
    - G5 a ray down at every opening misses and elsewhere hits the collider at y 0
    - G6 deterministic for one seed
- [ ] **Step 2: Run to see them fail**.
- [ ] **Step 3: Implement**. Run `python3 tools/textures/fetch_scans.py brown_mud_dry`, then the painter's `paint_tile` for both slots (add `--tiles` to `main`).
- [ ] **Step 4: Run** both test files. All PASS.
- [ ] **Step 5: Commit**: `feat(look): Ground.gd: a painted, hex-tiled, vertex-weathered ground`

---

### Task 10: Into the lab, toggles, stills, judging

**Files:**
- Modify: `maps/style_lab.gd`
- Modify: `tests/style_lab_test.gd`, `tests/style_lab_stills.gd`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `_ground()` is replaced by `Ground.build(GROUND, openings, footprints, 7)`. The footprints are the bays (roofed arcade depth) and the kiosks.
  - `_painterly()` passes `under_for(piece)` / `under_normal_for(piece)` (files `<piece>_under.png`, `<piece>_under_normal.png`). Each placed mesh gets `vertex_paint` from `Painterly.has_vertex_colours`.
  - `set_layer(layer: StringName, on: bool)` for `&"vertex_paint"`, `&"macro"`, `&"hex"`. It sets the uniform (`vertex_paint`, `macro_amount`, `hex_tiling`) on every lab painterly material, colourless meshes excepted.
  - `_unhandled_input`: F1, F2 and F4 toggle the three layers.
  - A `Label` in a `CanvasLayer` reads e.g. `F1 vertex paint ON · F2 macro ON · F4 hex ON · F11 day`.
  - `style_lab_stills.gd` gets a new view `ground_long`: eye 1.7 m, looking along the ground across all three stations.

- [ ] **Step 1: Write the failing lab checks** in `style_lab_test.gd`:
  - L11 the three shader_led bays' mean rendered albedo samples differ (macro on); equal with macro and vertex paint off
  - L12 F1/F2/F4 flip their uniforms on every lab material and the label's text
  - L13 the ground is a `Ground` with colliders under the player's start
  - L7, L8, L9, L10 still PASS
- [ ] **Step 2: Run to see them fail**.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Verify everything**
  - Python: `tools/eclipse/lab.sh test`, `tools/level/level.sh test`.
  - Godot headless: `style_lab_test`, `painterly_test`, `retro_test`, `lights_test`, `ground_test`, `vertex_colour_import`.
  - Windowed: `painterly_pixels`.
  - All green.
- [ ] **Step 5: Stills and judging.**
  - Capture `--only=shader_led` into the scratchpad.
  - Build a before/after sheet against `grid480/` and `smooth/`: day far, ground_long, arcade, kiosk_close, night grazing.
  - Build a layer sheet using variants `--variant="all|"`, `--variant="no_vp|vertex_paint=0"`, `--variant="no_macro|macro_amount=0"`, `--variant="no_hex|hex_tiling=0"`.
  - Send both sheets. The caption names tezontle as a stand-in.
  - Tell the user how to walk the lab (`maps/style_lab.tscn`, F1/F2/F4/F11).
- [ ] **Step 6: Commit**: `feat(lab): vertex paint, macro, hex-tiling and the painted ground in the style lab; F1/F2/F4 toggles`

Tuning rounds follow on the user's word (A/B/C variants of the Task 6 and Task 8 uniforms), each committed with its stills.
