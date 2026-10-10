# The street and canal kit (Zócalo family 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the street and canal kit from its approved card as closed, painted,
vertex-weathered pieces. Lay them and the painted ground tiles over the Zócalo
greybox with a dresser that reads the plan and its event fields. Walk-test the
result and show it in stills, day and night.

**Architecture:**
- Four Blender scripts build the pieces as named objects in four kits: `street_kit`, `canal_kit`, `bridge_stone` and `bridge_steel`. One atlas per kit.
- A shared dimensions module, `tools/eclipse/street_dims.py`, keeps the pieces and the dresser in agreement.
- The dresser, `tools/level/dress.py`, turns `plan.json` into `dressing.json`. That file holds three things:
  - placements, colliders and the greybox elements the dressing replaces;
  - the ground's areas, holes, inlays and relaid patches;
  - a district-wide overlap gate over every placed face.
- In Godot, `KitLoader.gd` draws each piece as one MultiMesh. `Ground.gd`, grown to district scale and chunked, lays flags and setts round the pieces.

**Tech Stack:** Blender 5.2 bpy/bmesh, Python 3 + numpy + Pillow, Godot 4.5.1 GDScript.

**Spec:**
- The card: `docs/superpowers/refs/mexico_city/cards/street_canal.md` (approved Oct 10 2026).
- The card sits inside `docs/superpowers/specs/2026-10-10-zocalo-district-design.md`, section 5.3, family 1.
- Ground tiles, vertex paint and hex-tiling follow `docs/superpowers/specs/2026-10-09-eclipse-vertex-paint-design.md`.

## Global Constraints

- **Grid:** 1.5 m along streets; pieces tile at 1.5 or 4.5; joints on 0.25. Kerbs stand 0.2 proud of the setts. The setts' top is y = 0.
- **Canal:** street 0, landings −1, water and canal floor −2. Wall 0.6 thick at the coping. Coping 0.35 deep and 0.15 proud of the wall's face.
- **Bridges:** 22 m long and 4 m wide, with parapets 0.9 m. The stone arch's crown is 0.6 above the quays. The deck ends meet the setts flush.
- **Budgets (triangles):** kerb and gutter pieces ≤ 150; track ≤ 400; curve ≤ 900; canal wall ≤ 600; steps ≤ 500; each bridge ≤ 3,000; small props ≤ 200.
- **Slots and palette:**
  - basalt `#14121a #3a3340 #5a5560`
  - chiluca `#5a5560 #8a8790 #b9b4b0`
  - rubble `#3a3340 #5a5560 #7a5a24`
  - steel `#3a3340 #5a5560`
  - iron `#14121a #2a3b2e`
  - brass `#7a5a24 #c49a40`
  - sign: the blank plates the user paints
- **Look and inspirations:** Thief, Dishonored, Grim Fandango, Deadlock and Game of Thrones, as the card lists them. This is an advanced look, not a copy. Every mark comes from an event (subsidence, water, seepage, use), never from magic.
- **Kit pieces built right:** closed solid meshes, no layered faces nearer than 3 cm, no shared atlas texels. Pieces are walk-tested with the real player, and pictures are sent for each painted kit. Brush strokes are colour-only; never rebuild stroke normals.
- **The repo is public:** commit only CC0 or self-made textures. Scans stay in `textures/scans/`, which is gitignored, and are credited in `CREDITS.md`. Never download VFX.
- **Words:** hatch numbers and junction-box plates are blank `sign` regions. The user paints all words.
- **Shell:** never `rm` with an unguarded variable.
- **Commits:** one commit per task, never pushed. Each ends `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Defects:** never call a visual defect harmless. Fix it with a test first, or name it unfinished.

## Rulings carried in from the card (decided here, so tasks don't re-decide)

1. **The plaza is a pavement 0.2 m up**, so the card's kerb (0.2 proud) and kerb drops mean something. This is a plan-level change: the plan, the checks and the greybox all honour it (Task 1). The atrium and courtyards stay at 0.
2. **Kerbs ring the plaza and the four well mouths' plaza sides only.** Streets elsewhere are setts wall to wall; their pavements belong with the house family.
3. **Runs fit by an even stretch.**
   - A run of length L takes n = round(L / p) pieces of pitch p, each stretched along its length by L / (n·p).
   - The stretch must lie within [0.95, 1.05]; otherwise the dresser fails, naming the run.
   - The tram loop moves to (±111, ±120), so its straights are whole 4.5 m multiples (198 and 216) with radius-12 curves.
4. **Pieces added to the card's list, each forced by the plan's geometry:**
   - `canal_wall_low`, 1 m: the landings' walls and the canal face under a landing.
   - `canal_wall_short`, 1.5 m.
   - `kerb_heaved`: the subsidence variant.
   - `tram_track_shimmed`: the subsidence variant.
   - `culvert_open`: the culvert's mouth cut through into the canal walkway at the plan's two walkway openings.
5. **Event variants are chosen by `plan.field` at each placement's middle:**
   - subsidence ≥ 0.2 → heaved kerb or shimmed track;
   - seepage ≥ 0.5 → conductor rail laid on that track piece;
   - seepage ≥ 0.6 → a junction box behind every 20th kerb.
   - **The steel bridge** is the bridge nearest any seepage centre. Ties go east.
6. **The causeway band:** the plan gains `P.causeway(points)`, the line (0, 160) → (0, 0). It runs north up Calle 20 de Noviembre to the plaza's middle, over the station hall. The dresser breaks it 1.2 m either side of the tram's centreline and at the south kerb drop.
7. **Hatches:**
   - four over the corridors' middles at (±55, ±98);
   - four over the hall at (±20, ±12).
8. **Ground tiles:**
   - `ground_flags` from volcanic_rock_tiles: the plaza, the atrium, the palace gate and courtyard;
   - `ground_setts` from cobblestone_floor_04, darker basalt: every other street-level ground;
   - `ground_earth` (exists): the canal floor at −2, as silt;
   - `ground_setts`: the landings at −1.
9. **Water:** water surface rendering is not in this family. The canal floor reads as wet silt via vertex paint B (damp). This is named as unfinished in the report.
10. **The dressed map replaces these greybox elements:** `ground`, `plaza`, `canal`, `landing_w`, `landing_e`, `bridge_1..3`, `landing_*_stair` and `landing_*_steps`. Everything else of the greybox stays until its family.

## Review Focus

- **A run meeting the brink** (the canal at x ±310): the last piece must stop at the brink, never overhang the void. The test is in Task 8.
- **Pieces meeting at landings, wells and the bridge abutments:** no coplanar faces between neighbouring placed pieces, or between a piece and a kept greybox face. The district overlap gate in Task 8 checks it.
- **Ground cut round a curved inlay:** no crack the sky shows through, and no ground triangle over the curve. The Ground test in Task 3 checks the area sum; the piece's skirt hides the edge.
- **The player at a kerb, a drop, a bridge crown, landing steps and a curve:** they cross without snagging, falling through or being stopped. The walk checks are in Task 9.
- **Load time and frame rate of a dressed 620 m map:** load ≤ 10 s headless; the fps report is printed and compared with the greybox's. Task 10.

---

### Task 1: The plaza a pavement 0.2 m up

**Files:**
- Modify: `tools/level/layouts/plan.py` (a `RAISED` rule: a non-sunken ground with level > 0; `causeway()`)
- Modify: `tools/level/layouts/zocalo/plaza.py`: plaza `level=0.2`; tram `(±111, ±120)`; `P.causeway([(0, 160), (0, 0)])`
- Modify: `tools/level/layouts/zocalo/station.py`: kiosk stairs start at y 0.2
- Modify: `tools/level/plan_check.py`: a raised plaza counts as `street` for reach; holes inside a raised ground are measured from its level
- Modify: `tools/level/greybox.py`: a raised ground is cut from the street like a sunken one. It gets its top at its level (cut round the sunken places inside it) and its sides from 0 up, facing out. The walls of a sunken place inside it rise to its level.
- Modify: `tools/level/plan_draw.py`: draw the causeway line
- Test: `tools/level/test_plan.py`, `tools/level/test_greybox.py`, `tools/level/test_zocalo_plan.py`, `tests/zocalo_test.gd`

**Interfaces:**
- Produces:
  - `Plan.causeway(points)` → `data()["causeway"]`: `[[x, z], ...]`
  - `plan.RAISED_KINDS = ("plaza",)`
  - The greybox mesh `{"name": "plaza", "kind": "raised"}`

- [ ] **Step 1: Write the failing tests**
  - `test_plan.py::test_causeway_is_kept`: `P.causeway([(0, 5), (0, 0)])` → `data()["causeway"] == [[0.0, 5.0], [0.0, 0.0]]`.
  - `test_greybox.py::test_raised_ground_stands_on_the_street`:
    - a 20×20 plaza at level 0.2 holding a 4×4 well at −8;
    - the greybox has a `plaza` mesh whose up-facing faces all lie at y 0.2 with none over the well;
    - it has outward faces spanning y 0..0.2 on all four sides;
    - the well's walls reach y 0.2;
    - `gate()` passes.
  - `test_zocalo_plan.py`:
    - `test_plaza_is_a_pavement`: plaza level 0.2;
    - `test_tram_straights_are_whole_pieces`: every tram side minus 24 is a multiple of 4.5;
    - `test_causeway_runs_to_the_station`: ends at (0, 0) and (0, 160).

- [ ] **Step 2: Run them; expect FAIL** (no `causeway`; no raised mesh; plaza level 0).
  Run: `cd tools/level && python3 -m pytest test_plan.py test_greybox.py test_zocalo_plan.py -q`

- [ ] **Step 3: Implement it as the Files list says.**

- [ ] **Step 4: Run the Python tests and the plan's command; expect PASS**
  - `python3 -m pytest test_plan.py test_greybox.py test_zocalo_plan.py test_plan_check.py -q`
  - `tools/level/level.sh zocalo`: writes plan.json and greybox.json; the checks and gate are clean.

- [ ] **Step 5: Update `tests/zocalo_test.gd`** for the 0.2 plaza: the player on the plaza stands at y ≈ 0.2, and the well chain still walks.
  Run: `$GODOT --headless --fixed-fps 60 --path . res://tests/zocalo_test.tscn`. Expected: all Z checks PASS.

- [ ] **Step 6: Commit** `feat(zocalo): the plaza a pavement 0.2 up, the tram loop on whole track pieces, the causeway's line`

### Task 2: The scans and the ground tiles

**Files:**
- Modify: `tools/textures/fetch_scans.py`: add `"volcanic_rock_tiles", "stone_wall_04"` to `SCANS`
- Modify: `CREDITS.md`: both scans, with their authors from `info.json`
- Create: `tools/textures/recipes/eclipse/ground_flags.json`
  - scan `volcanic_rock_tiles`, tint 0.7
  - basalt palette: base `#3a3340`, light `#5a5560`, dark `#14121a`
  - `"bands": 4`, `"under": "ground_earth"`
- Create: `tools/textures/recipes/eclipse/ground_setts.json`
  - scan `cobblestone_floor_04`, tint 0.8, contrast 1.1
  - basalt palette, `"under": "ground_earth"`
- Create: `tools/textures/recipes/eclipse/basalt.json`, `rubble.json`, `granite.json`
  - basalt: the slot recipe from `volcanic_rock_tiles`, under `ground_earth`
  - rubble: `stone_wall_04` in the rubble palette, under `lime`
  - granite (the tram strip's setts): `cobblestone_floor_04`, palette `#5a5560 #8a8790 #3a3340`, under `ground_earth`
- Modify: `tools/textures/eclipse_atlas.py`: `GROUND_TILES = ("ground_cobbles", "ground_earth", "ground_flags", "ground_setts")`
- Test: `tools/textures/test_eclipse_atlas.py`

- [ ] **Step 1: Write the failing test.** `test_ground_tiles_include_the_zocalo_tiles` asserts:
  - `{"ground_flags", "ground_setts"} <= set(GROUND_TILES)`;
  - each tile has a recipe on disk naming a scan in `fetch_scans.SCANS`.

- [ ] **Step 2: Run it; expect FAIL.** Run: `cd tools/textures && python3 -m pytest test_eclipse_atlas.py -q -k ground_tiles`

- [ ] **Step 3: Implement.** Then run:
  ```
  python3 tools/textures/fetch_scans.py volcanic_rock_tiles stone_wall_04
  python3 tools/textures/eclipse_atlas.py --tiles
  ```

- [ ] **Step 4: Check the results.**
  - The tile test passes, and the whole atlas test file passes.
  - `textures/painted/eclipse/ground_flags.png` and `ground_setts.png` (+ `_normal`) exist, 256 px.
  - `git status` shows no file under `textures/scans/`.

- [ ] **Step 5: Show the user.** Send the two tiles tiled 3×3 (a contact sheet in the scratchpad) as a still.

- [ ] **Step 6: Commit** `feat(look): the Zócalo's flags and setts tiles, basalt, rubble and granite recipes, two CC0 scans credited`

### Task 3: Ground at district scale

**Files:**
- Modify: `scripts/Visual/Ground.gd`
- Create: `scripts/Visual/DistrictGround.gd`
- Test: `tests/ground_test.gd` (G8–G13)

**Interfaces:**
- Produces:
  - `Ground.build(area: Rect2, openings: Array[Rect2], footprints: Array[Dictionary], seed: int, options := {}) -> Ground`. The options:
    - `"tile": StringName` (default `&"ground_cobbles"`): loads `textures/painted/eclipse/<tile>.png` and `_normal`; the under is `ground_earth`.
    - `"level": float` (0): the y of the top and the collider.
    - `"inlays": Array[PackedVector2Array]`: cut from the mesh, collider kept.
    - `"covered": Array[PackedVector2Array]`: cells whose four corners lie inside are skipped, no collider, no rim wear.
    - `"patches": Array[Rect2]`: relaid stone. B = 0.65 and G = 0 inside.
    - `"cell": float` (1.0).
  - `DistrictGround.build(ground: Dictionary, seed: int) -> Node3D`. `ground` is `dressing.json["ground"]`: `{"chunk": 50, "areas": [{"tile", "level", "rect": [x0, z0, x1, z1], "openings": [...rects], "covered": [...polygons], "inlays": [...polygons], "patches": [...rects], "footprints": [{"rect", "roofed"}]}]}`. One Ground per area per 50 m chunk; each gets only the openings, inlays, covered polygons, patches and footprints that touch it.

- [ ] **Step 1: Write the failing tests** in `ground_test.gd`.
  - **G8:** `level` 0.2 puts every vertex at y 0.2 and the collider's top at 0.2. `tile` &"ground_setts" sets the material's albedo to that texture.
  - **G9:** a curved inlay (a 90° annular sector, r 10.8–13.2, 16 segments) leaves:
    - no ground triangle whose centroid lies inside it;
    - a total ground area equal to the area minus the inlay, within 0.01 m².
  - **G10:** a ray down at the inlay's middle still hits a collider at the ground's level.
  - **G11:** a `covered` square holds no triangles. A vertex 0.3 m outside it has G (wear) = 0, which shows no rim wear.
  - **G12:** a `patches` rect's vertices have B = 0.65 and G = 0.
  - **G13:** `DistrictGround` over a 120×60 area makes 3×2 chunks. No chunk mesh's AABB is wider than 50 m. A down-ray at every 7 m hits ground except over openings.

- [ ] **Step 2: Run them; expect G8–G13 FAIL** (unknown options, no DistrictGround).
  Run: `$GODOT --headless --path . res://tests/ground_test.tscn`

- [ ] **Step 3: Implement.**
  - **Inlays:** cells that meet an inlay's bounding box are cut with `Geometry2D.clip_polygons(cell, inlay)` per inlay, and the remains are triangulated with `Geometry2D.triangulate_polygon`. A remain flagged as a hole (the inlay inside a cell) is an error that is pushed and skipped.
  - **Edges:** rect-shaped inlays and covered rects add grid lines, as openings do.
  - **The existing behaviour stays as it is** when no options are passed: G1–G7 and the style lab are unchanged.

- [ ] **Step 4: Run the ground test, the style lab test and the vertex-colour import; expect PASS.**
  - `ground_test`: G1–G13
  - `style_lab_test`: 15/15
  - `vertex_colour_import`: 2/2

- [ ] **Step 5: Commit** `feat(ground): tiles, levels, curved inlays, covered cells and relaid patches; DistrictGround lays a district in 50 m chunks`

### Task 4: Kit plumbing and the shared dimensions

**Files:**
- Create: `tools/eclipse/street_dims.py`. Pure Python, no bpy. The card's dimensions as constants, plus:
  - `footprint(piece) -> [(x, y)]`: the outline in Blender x/y, front −Y, origin at the run's start on the front line.
  - `curve_centreline(segments=16) -> [(x, y)]`: start (0, 0) heading +X, turning to +Y, radius 12.
  - `PITCH = {"kerb_straight": 1.5, "tram_track": 4.5, "canal_wall": 4.5, "canal_wall_short": 1.5, ...}`
- Modify: `tools/eclipse/common.py`:
  - `export_piece(..., out=OUT, sets_each=False)`: `sets_each=True` gates, bakes AO and weathers each object on its own.
  - It always writes `SOURCE/<name>_faces.json`: `{object: [{"normal", "points"}]}` in Godot axes (x, z, −y), and `{object: tris}`.
- Create: `assets/eclipse/kit/.gitkeep`. The kits export to `assets/eclipse/kit/`.
- Modify: `tools/eclipse/weather_rules.py`: `tide(z, band) -> (grime, tint)`. Inside `band = (lo, hi)` it returns grime ≥ 0.6 and tint 0.3 (damp green), fading over 0.1 m above `hi`. Outside it returns (0, 0.5).
- Modify: `tools/eclipse/weather.py`: `bake` applies `settings["tide"]` when given.
- Test: `tools/eclipse/test_weather_rules.py` (tide), `tools/eclipse/test_street_dims.py` (new), `tools/eclipse/test_weather_bpy.py` (faces.json and sets_each)

**Interfaces:**
- Produces:
  - `street_dims.footprint`, `street_dims.curve_centreline`, `street_dims.PITCH`
  - `SOURCE/<kit>_faces.json`
  - `export_piece(out=, sets_each=)`
  - `weather_rules.tide`

- [ ] **Step 1: Write the failing tests.**
  - `test_street_dims.py`:
    - the curve centreline starts at (0, 0) and ends at (12, 12), with every point 12 m from (0, 12);
    - `footprint("tram_track_curve")` is a closed polygon whose area is 2.4 × (π/2 · 12) within 1 %;
    - every `PITCH` is 1.5 or 4.5 except `causeway_band` (3.0).
  - `test_weather_rules.py::test_tide_band`:
    - `tide(-1.8, (-2.0, -1.55))` gives grime ≥ 0.6 and tint 0.3;
    - `tide(-1.0, ...)` gives (0, 0.5).
  - `test_weather_bpy.py::test_faces_json_written_in_godot_axes`:
    - export a one-box piece at z 0..1;
    - its `_faces.json` holds the box's 6 faces;
    - the top face's normal is (0, 1, 0).

- [ ] **Step 2: Run; expect FAIL.**
  - `python3 tools/eclipse/test_street_dims.py`
  - `python3 tools/eclipse/test_weather_rules.py`
  - `tools/eclipse/lab.sh test`

- [ ] **Step 3: Implement it as the Files list says.**

- [ ] **Step 4: Run the same commands; expect PASS.** `lab.sh test` stays 34/34-style OK, and kiosk and arcade_bay still build clean (`tools/eclipse/lab.sh all`).

- [ ] **Step 5: Commit** `feat(kit): shared street dimensions, faces dump for district gates, per-object sets, tide band`

### Task 5: The street kit

**Files:**
- Create: `tools/eclipse/street_kit.py`. `NAME = "street_kit"`, `ATLAS = 1024`.
  - `SLOTS = ["basalt", "chiluca", "granite", "steel", "iron", "brass", "sign"]`
  - It exports with `sets_each=True` to `assets/eclipse/kit/`.
  - It defines `JOINTS` for card joints 1–6 and a `WEATHER` with `"blendable": ["basalt", "chiluca", "granite"]`, `"foot": ["chiluca", "basalt"]`.
- Modify: `tools/eclipse/lab.sh`: `PIECES` gains the kits. A kit's `.glb` goes to `assets/eclipse/kit/`.
- Modify: `tools/eclipse/test_kit_bpy.py`: a `StreetKit` case
- Modify: `tools/textures/eclipse_atlas.py` `main` default list: add the kits

**Objects** (front −Y, origin at the run's start on the front line, the street at z 0, X along):

| Object | Shape |
|---|---|
| `kerb_straight` | 1.5 long. Chiluca block, y 0..0.3, z −0.15..0.2. Top front edge worn round with a 2-step chamfer of 0.04. Closed. |
| `kerb_heaved` | The same, rotated 2° about its back top edge (y 0.3, z 0.2) so the front sinks, and chipped (one corner notch 0.05). |
| `kerb_corner` | An outside corner 0.3×0.3 with the same section turning 90°. The runs start 0.3 from the plaza's corner. |
| `kerb_drop` | 3.0 long. The kerb's top falls to z 0.02 over its middle 2.0 m, with a chiluca ramp behind it 1.2 deep rising 0.02 → 0.2 and closed wings either side. Its plaza footprint is `footprint("kerb_drop")`. |
| `gutter_grate` | 1.5 × 0.5 in front of a kerb (y −0.5..0). Basalt gutter frame, iron grate of 6 bars, a dark sump 0.1 down. Top at z 0. Skirt to −0.3. |
| `causeway_band` | 3.0 × 3.0 centred on the line (y −1.5..1.5). Three large basalt slabs with 0.25 joints, slabs bevelled 0.02. Top at z 0. Skirt to −0.3. |
| `tram_track` | 4.5 long, y −1.2..1.2. Granite strip; two grooved steel rails at gauge 1.435, heads flush at z 0, groove 0.04 wide × 0.04 deep. Skirt to −0.3. |
| `tram_track_shimmed` | The same, with two brass-patched steel shim plates under the rail heads, rising 0.01. |
| `tram_track_curve` | `curve_centreline(16)`, the strip ±1.2 round it, the rails at ±0.7175. Its footprint matches `street_dims.footprint`. |
| `tram_conductor` | A third steel rail in five insulated chairs (iron chairs, brass caps), set 0.9 off the centreline in the strip. Heads at z 0.03. Laid over a `tram_track` placement. |
| `hatch` | 1.2 square: a basalt frame 0.15 wide, an iron plate with a raised blank `sign` plaque of 0.4×0.25 for the user's number, four bolt heads. Top at z 0. Skirt to −0.3. |
| `junction_box` | Steel 0.6 × 0.35 × 0.9 on a basalt plinth, two conduit stubs (tubes, 8 sides) running down into the pavement, a blank `sign` plate, brass hinge strips. |

- [ ] **Step 1: Write the failing tests** in `test_kit_bpy.py::StreetKit`:
  - `test_every_card_piece_is_an_object`: the 12 objects above all exist.
  - `test_every_object_is_closed`: every edge is shared by exactly two faces, after a remove-doubles of 1e-5.
  - `test_budgets`, from the card:
    - kerbs, grate ≤ 150
    - band, hatch, junction box ≤ 200
    - tracks ≤ 400
    - curve ≤ 900
    - conductor ≤ 200
  - `test_flush_pieces_top_at_zero`: the band, tracks, hatch and grate have their highest up-facing face at z 0 ± 1e-4.
  - `test_kerb_proud`: the kerb's top is at 0.2. The heaved kerb's back top edge is at 0.2 ± 1e-3.
  - `test_curve_matches_its_footprint`: the curve's top outline equals `footprint("tram_track_curve")` within 1e-4.

- [ ] **Step 2: Run; expect FAIL** (no `street_kit` module). Run: `tools/eclipse/lab.sh test`

- [ ] **Step 3: Build the kit.** Run `tools/eclipse/lab.sh street_kit`. Expected: `street_kit: clean, <tris>`.

- [ ] **Step 4: Paint it and render the joints.**
  ```
  python3 tools/textures/eclipse_atlas.py street_kit
  tools/eclipse/lab.sh joints street_kit
  ```
  Look at every joint render closely: holes, slivers, stretched texels. Fix what you find before Step 5; each fix is a test or a gate.

- [ ] **Step 5: Run `tools/eclipse/lab.sh test`; expect PASS.**

- [ ] **Step 6: Show the user.** Send the joint renders, plus a contact still of the painted kit from the style lab's look: `tests/kit_stills.gd`, which lays each object in a row on a Ground, day light, the shader_led preset.

- [ ] **Step 7: Commit** `feat(kit): the street kit: kerbs, drop, grate, causeway band, tram track, curve and conductor, hatch, junction box`

### Task 6: The canal kit

**Files:**
- Create: `tools/eclipse/canal_kit.py`
  - `NAME = "canal_kit"`, `ATLAS = 1024`
  - `SLOTS = ["chiluca", "rubble", "basalt", "iron", "brass"]`
  - `sets_each=True`, `JOINTS` for card joints 7–10
  - `WEATHER` with `"tide": (-2.0, -1.55)` and the `ground_holes` the water side needs
- Modify: `tools/eclipse/test_kit_bpy.py`: a `CanalKit` case
- Modify: `tests/kit_stills.gd`: the canal row

**Objects** (front −Y looks into the water or landing; the top at z 0 is the street; buried backs closed):

| Object | Shape |
|---|---|
| `canal_wall` | 4.5 long. Ashlar (chiluca) courses z −2..−1.1. Rubble courses −1.1..−0.35, with the joint between the eras a ragged line in the geometry: 3 steps. Chiluca coping −0.35..0, y −0.15..0.2. Body to y 0.6, foot to −2.3. |
| `canal_wall_short` | The same at 1.5. |
| `canal_wall_low` | 4.5 long, 1 m: ashlar −1..−0.35, coping above. |
| `canal_wall_corner` | The landing's inside corner, 1 m: a mitred coping block 0.6×0.6 and its two faces, so neither run's coping overlaps it. Runs stop 0.6 from the corner. |
| `culvert` | A `canal_wall` with an arched mouth 1.4 wide × 1.0 high (8-segment arch, chiluca voussoirs), choked with a basalt-silt mound inside, 0.6 deep. |
| `culvert_open` | A `canal_wall` with an arch 3.0 wide, from z −2 to −0.45, cut through the full thickness so the walkway behind shows. Its reveals are closed. |
| `canal_landing_steps` | A 1 m flight of 6 risers × 0.1667, treads 0.3, 2.4 wide, solid to its foot, sides closed, chiluca. Origin at the top nosing's middle; it descends along +X. |
| `mooring_ring` | A chiluca block 0.3×0.3 inset in the coping, its top 0.03 proud. An iron ring (12 segments, section 4 sides) lies over it, worn bright (vertex paint wear 1). |

- [ ] **Step 1: Write the failing tests** in `CanalKit`:
  - objects exist and are closed;
  - budgets: walls and culverts ≤ 600; steps ≤ 500; ring ≤ 200;
  - the coping's top is at z 0 and its front at y −0.15;
  - the wall's water face is at y 0 from z −2 to −0.35;
  - the steps' top tread is at z 0 and the lowest at z −0.8333;
  - the culvert_open's cut runs through, shown by a ray along +Y at (2.25, *, −1.2) hitting nothing.

- [ ] **Step 2: Run; expect FAIL.**

- [ ] **Step 3: Build, paint, render joints.**
  ```
  tools/eclipse/lab.sh canal_kit
  python3 tools/textures/eclipse_atlas.py canal_kit
  tools/eclipse/lab.sh joints canal_kit
  ```
  Look at every render and fix what you find.

- [ ] **Step 4: Run `lab.sh test`; expect PASS.** Send the joint renders and the kit row still.

- [ ] **Step 5: Commit** `feat(kit): the canal kit: two-era walls, low walls and corner, culverts, landing steps, mooring rings`

### Task 7: The bridges

**Files:**
- Create: `tools/eclipse/bridge_stone.py`. Origin at the deck's middle, on the canal's centreline, the street at z 0; X across the canal (22 m, −11..11), Y along the deck's width.
  - A segmental arch spanning the canal (12 m), springing at the copings' fronts (±6.15, z −0.35), its crown soffit at z 0.25.
  - The deck rising from z 0 at ±11 to 0.6 at 0, in 8 facets a side.
  - Parapets 0.9 above the deck, 0.35 thick, chiluca copings.
  - Abutments on the quays, x ±6.15..±11, down to −0.6.
  - The spandrels rubble, the voussoirs chiluca.
  - The canal walls run under it: the dresser keeps them, and the arch's springers sit on their copings without sharing a face.
- Create: `tools/eclipse/bridge_steel.py`. The same frame.
  - Two riveted steel plate girders 1.0 deep spanning ±6.15 on stepped deco piers: three steps, each 0.15 in.
  - The old stone abutments are kept. Brass patch plates (4 cm thick) are bolted over the joints of girder and stone.
  - A steel deck with chequer-plate relief, from z 0 at ±11 to 0.3 at 0 (8 facets).
  - Railings of 0.9 steel posts and two rails.
- Modify: `tools/eclipse/test_kit_bpy.py`: a `Bridges` case

- [ ] **Step 1: Write the failing tests.**
  - Each bridge is closed and ≤ 3,000 tris.
  - The deck top at x ±11 is at z 0 ± 1e-4.
  - The stone deck's highest point is 0.6.
  - No deck facet is steeper than 8°, so the player walks it.
  - The parapet tops are 0.9 above the deck at every facet.
  - Nothing of either bridge lies inside the canal wall's coping box (x ±6.15..±6.8, z −0.35..0) other than touching faces.

- [ ] **Step 2: Run; expect FAIL.**

- [ ] **Step 3: Build, paint, render joints 11–12, look, fix.**
  ```
  tools/eclipse/lab.sh bridge_stone bridge_steel
  python3 tools/textures/eclipse_atlas.py bridge_stone bridge_steel
  ```

- [ ] **Step 4: Run `lab.sh test`; expect PASS.** Send the joint renders and stills.

- [ ] **Step 5: Commit** `feat(kit): the stone arch bridge and the seeped steel bridge`

### Task 8: The dresser

**Files:**
- Create: `tools/level/dress.py`
  - `dress(data: dict, faces: dict) -> dict` (the dressing)
  - `fill(length: float, pitch: float) -> (n: int, stretch: float)`, which raises `ValueError` outside [0.95, 1.05]
  - `gate(dressing, greybox, faces) -> [problems]`
  - The CLI: `python3 tools/level/dress.py <plan.json> <greybox.json> <dressing.json>` exits 1 on a problem.
- Modify: `tools/level/level.sh`: `zocalo` runs the dresser after the greybox
- Create: `tools/level/test_dress.py`

**Interfaces:**
- Consumes:
  - `plan.field`, `plan.json`'s `tram`, `causeway`, `ground`, `routes`, `spaces`, `plots`, `events`
  - `street_dims.*`
  - `assets/eclipse/source/<kit>_faces.json`
- Produces `dressing.json`:

```json
{"skip": ["ground", "plaza", "canal", "landing_w", ...],
 "pieces": [{"kit": "street_kit", "piece": "kerb_straight", "at": [x, y, z], "yaw": deg, "stretch": s}],
 "colliders": [{"box": [cx, cy, cz, sx, sy, sz], "yaw": deg} | {"kit", "piece", "at", "yaw", "stretch"}],
 "ground": {"chunk": 50, "areas": [...as Task 3...]}}
```

- **Yaw:** about Godot +Y. Yaw 0 maps the piece's local front (Blender −Y) to Godot +Z.
- **Stretch:** scales local X.

**The rules** (Rulings 1–10, plus):
- **Plaza kerbs:**
  - each side from the plaza's corner + 0.3, front on the plaza's edge facing the street;
  - corners at the four plaza corners;
  - drops at N x 0, S x 0, E z 0, W z 42.75 (Calle 16 de Septiembre's middle), centred.
  - The kerbs at each well mouth face into the well.
- **Gutter grates:** one in front of every 10th kerb (not drops).
- **Tram:** straights and four curves on the moved loop; conductor and shim by field.
- **Causeway:** runs at 3.0 pitch along its line, broken as Ruling 6 says.
- **Hatches:** at Ruling 7's points.
- **Junction boxes:** by Ruling 5.
- **Canal walls:**
  - along z 167 (front +Z) and z 179 (front −Z), x −310..310;
  - broken at the landings (`canal_wall_low` under them at top −1);
  - `culvert_open` centred on the walkway openings (±100, 179);
  - `culvert` every 45 m, never within 6 m of a bridge or a landing.
- **Landings:** `canal_wall_low` + `_short` + `canal_wall_corner` round three sides; the plan's two stairs as `canal_landing_steps` (street → landing along +X at z 163.5; landing → water facing the canal at x0 + 12).
- **Mooring rings:** every 18 m on both copings, not on a bridge or a landing.
- **Bridges:** at each `bridge` route's middle, yawed across the canal. `bridge_steel` goes where Ruling 5 says.
- **Ground areas:**
  - `ground_setts` at level 0: every street-level ground, with the plaza, flag areas and canal (grown 0.2 for the copings) as openings, and the plots as covered;
  - `ground_flags` at 0.2: the plaza inset 0.3 for the kerbs, the wells and drop ramps cut;
  - `ground_flags` at 0: the atrium and courtyards;
  - `ground_setts` at −1: the landings;
  - `ground_earth` at −2: the canal, minus the steps' footprints.
- **Inlays:** every flush piece's footprint, placed.
- **Patches:** 2–4 m rects, seeded by position, where subsidence ≥ 0.3, one per 150 m².
- **Colliders:**
  - one box per kerb side and per canal wall run (its body);
  - meshes for drops, steps, bridges and junction boxes;
  - nothing for flush pieces (the ground's collider holds).
- **Gate:** every placed piece's faces, transformed and stretched, plus the greybox's faces minus `skip`, through `greybox._layered` (3 cm, by bucket). Every placement inside the brink's x/z bounds.

- [ ] **Step 1: Write the failing tests** in `test_dress.py`. It runs the real plan and the real `_faces.json`, and skips with a message if the kits aren't built.
  - `test_fill_even_stretch`:
    - `fill(200, 1.5) == (133, 200/199.5)`;
    - `fill(10, 4.5)` raises.
  - `test_no_piece_overhangs_the_brink`: every placed piece's transformed AABB lies inside x ±310, z −340..300.
  - `test_tram_straights_are_unstretched`: every `tram_track*` has stretch 1.0 ± 1e-9.
  - `test_drops_at_the_four_gates`: 4 `kerb_drop`s at the ruled positions.
  - `test_steel_bridge_nearest_seepage`: exactly one `bridge_steel`, at x 150.
  - `test_variants_follow_fields`:
    - every `kerb_heaved` and `tram_track_shimmed` has subsidence ≥ 0.2 at its middle, and every plain one < 0.2;
    - every `tram_conductor` has seepage ≥ 0.5.
  - `test_inlays_do_not_overlap`: no two inlay polygons overlap by more than 1e-4 m².
  - `test_district_gate_clean`: `gate(...) == []`.
  - `test_every_piece_exists_in_its_kit`.

- [ ] **Step 2: Run; expect FAIL.** Run: `cd tools/level && python3 -m pytest test_dress.py -q`

- [ ] **Step 3: Implement it.** Fix what the gate finds in the kit pieces or the rules, not in the gate.

- [ ] **Step 4: Run the tests and the command; expect PASS.**
  - `python3 -m pytest test_dress.py -q`
  - `tools/level/level.sh zocalo` writes `dressing.json`
  - `tools/level/level.sh test` still exits 0

- [ ] **Step 5: Commit** `feat(zocalo): the street and canal dresser: runs, event variants, ground areas and inlays, a district overlap gate`

### Task 9: Dressed in Godot, walk-tested

**Files:**
- Create: `scripts/Level/KitLoader.gd`. `class_name KitLoader`:
  - `static func build(dressing: Dictionary) -> Node3D`. Per (kit, piece): one `MultiMeshInstance3D` named `<piece>`, with the mesh taken from `res://assets/eclipse/kit/<kit>.glb`'s MeshInstance3D of that name.
  - Material: `Painterly.material(atlas, &"shader_led", Painterly.ZOCALO, normal, under, under_normal)`, with `vertex_paint` 1. The atlas is the user's overpaint `<kit>.png`, else `<kit>_base.png`.
  - Colliders as `dressing.colliders` say.
  - `static func atlas(kit: String, suffix: String) -> Texture2D`
- Modify: `scripts/Level/GreyboxLoader.gd`: `build(greybox, skip: Array = [])`
- Modify: `maps/zocalo.gd`: if `res://assets/eclipse/zocalo/dressing.json` exists:
  - build the greybox with its `skip`;
  - add `DistrictGround.build(dressing.ground, 11)`;
  - add `KitLoader.build(dressing)`;
  - `--undressed` keeps the plain greybox.
- Modify: `tests/zocalo_test.gd`: Z8–Z13

- [ ] **Step 1: Write the failing checks** (the real player, `--fixed-fps 60`):
  - **Z8 the dressing loads:** every piece named in `dressing.json` has a MultiMesh with that many instances. No skipped greybox element is present.
  - **Z9 kerb:** walk north from spawn (0, 0, 120) for 6 s. The player crosses the south kerb away from the drop and stands on the plaza at y 0.2 ± 0.05.
  - **Z10 drop:** the same through the S drop at x 0.
  - **Z11 curve:** walk diagonally across the SE tram curve. The player never drops below y −0.05 and never stops for more than 0.3 s.
  - **Z12 bridge:** for bridges 1 and 3, walk from (x, 0, 160) to (x, 0, 187). The player arrives, and their highest y is within 0.1 of the deck's crown.
  - **Z13 landing:** from (−58, 0, 163.5), walk east down the steps onto the landing (y −1 ± 0.05). Then walk south down the water steps to the canal floor (y −2 ± 0.05).

- [ ] **Step 2: Run; expect Z8–Z13 FAIL.** Run: `$GODOT --headless --fixed-fps 60 --path . res://tests/zocalo_test.tscn`

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run every suite; expect PASS.**
  - `zocalo_test` (all Z)
  - `ground_test`
  - `style_lab_test`
  - `tools/level/level.sh test`
  - `tools/eclipse/lab.sh test`

- [ ] **Step 5: Commit** `feat(zocalo): the street and canal kit laid over the greybox, walk-tested`

### Task 10: Stills, frame rate, and the record

**Files:**
- Modify: `tools/level/layouts/zocalo/cameras.py`. Add the cameras:
  - `kerb_drop_south` (4, 1.7, 116) → (0, 0, 108)
  - `tram_curve_se` (100, 1.7, 112) → (111, 0, 120)
  - `landing_w` (−50, 1.7, 158) → (−55, −1.5, 168)
  - `bridge_stone` (−140, 1.7, 158) → (−150, 0, 173)
  - `bridge_steel` (160, −1.7, 170) → (150, 0, 173)
  - `hatches` (50, 1.9, 95) → (55, 0.2, 98)
- Modify: `tests/zocalo_stills.gd`: shoots every camera dressed, day and night, to `/tmp/zocalo-stills/<name>_<day|night>.png`
- Modify: `maps/zocalo.gd`: `--load-report` prints `load: <s> s`
- Update the memory: `zocalo-district-project.md` and the MEMORY.md line

- [ ] **Step 1: Run the reports.**
  - `$GODOT --headless --path . res://maps/zocalo.tscn -- --load-report`. Expected: `load: ≤ 10 s`.
  - `$GODOT --path . res://maps/zocalo.tscn -- --fps-report=40`, windowed, both `--undressed` and dressed. Record both lines.

- [ ] **Step 2: Shoot the stills.** Look at every still closely: seams, holes, z-fighting, floating pieces, stretched texels. Any fault found goes back to its task with a failing test first.

- [ ] **Step 3: Send the user the stills, day and night,** with the fps and load numbers and the open items:
  - water surface not in this family;
  - tezontle still a stand-in;
  - hatch and junction-box plates blank for the user.

- [ ] **Step 4: Commit** `docs(zocalo): street and canal kit stills cameras, load report`
