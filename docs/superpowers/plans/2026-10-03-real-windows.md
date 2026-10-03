# Real Windows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The harbour's enterable rooms get real glazed windows (cut through the wall, see-through leaded glass, collider whole) with moon shafts falling in where the moon reaches and lamplight thrown out of lit rooms, from a shared kit piece the old town can adopt.

**Architecture:** `tools/level/kit_glazing.py` draws a glazed opening and returns a window record; kits store records on their pieces, `export.manifest` writes them in world space, `LevelLoader` exposes `Level.windows`. At load, `scripts/Visual/Windows.gd` (made by `DistrictMap`) casts rays from each record to decide and shape moon shafts (`GodRays`, extended) and, for rooms (box markers `room`) with lit lamps, a warm point-source shaft plus a projector spotlight outside. Guards' sight and the light probe step past colliders in group `glass` (`SightRay.gd`).

**Tech Stack:** Python 3 (kit, unittest), Blender 4 (level build/export via `tools/level/level.sh`), Godot 4 GDScript (tabs), headless suites.

**Spec:** `docs/superpowers/specs/2026-10-03-real-windows-design.md`

## Global Constraints

- Work in worktree `.claude/worktrees/real-windows`, branch `real-windows`. Never edit `tools/level/kit_town.py` (the old town's session owns it) or the garrison.
- Godot: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`; suites run `--headless --fixed-fps 60 --path . res://tests/<name>.tscn`.
- The repo is PUBLIC: never commit textures.com photos or anything made from them (`textures/ps2`, `textures/source` stay untracked). Our own paintings (`tools/textures/paint.py` → `textures/painted`) are committed. No downloaded VFX.
- Moon energy and ambient are gameplay contracts: do not change `MOON_ENERGY`, `AMBIENT` or the moon's colour.
- Values from the spec: glass `setback` 0.12-0.2 m (default 0.15); moonward when `dot(normal, -way) > 0.1`; sky test 3 x 3 rays, 200 m, shaft only if >= 5 clear; room reach 30 m; outside reach 10 m; window inside point 0.3 m; spot 5 cm outside the glass, angle = the glass seen from the lamp + 4 degrees, range 8 m, no shadow, energy 0.5 x the lamp's; lamp fade 0.3 s; lamp shaft gain a third of the moon shafts' (0.14 / 3); glazing tint (0.55, 0.62, 0.56), alpha ~0.12 rising to 0.35 in the grime; moon shafts `least` 0.
- GDScript gotchas: extend/preload scripts by path (class cache); no multi-line lambdas inside call parentheses; headless runs use the dummy renderer (mesh/MultiMesh data still readable from the arrays you built).
- Every geometry change ends with daylight close-ups judged at full size (the inspect-closely rule), and after any harbour export: `tools/level/level.sh navmesh harbour` then `tools/level/level.sh navmesh old_town`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- A window in no room box (or a room with no lamp): its moon shaft is still built, it gets no lamplight, nothing errors. Pinned in Task 5 (GW5c) and Task 6 (GW9d).
- A lamp outside every room box: ignored, no spot anywhere, no error. Pinned in Task 6 (GW9d).
- Windows built again (a rebuild, the district re-entered): old shafts and spots freed, counts unchanged, no orphan lights. Pinned in Task 5 (GW5d).
- A room's lamp freed mid-night (a lantern carried off or broken): the room fades dark, no error, the next lit lamp takes over. Pinned in Task 6 (GW9e).
- Two panes in a row (a window seen through another): sight and the probe pass both. Pinned in Task 3 (GW2b).

## File Structure

| File | Responsibility |
|---|---|
| `tools/level/kit_glazing.py` (new) | outline, glazed opening (reveals, spandrels, glass, lead, glass collider, record), wall strips round holes, `around` for planar faces, record moving |
| `tools/level/test_glazing.py` (new) | the kit piece's geometry and records; customs and carrack records; manifest windows |
| `tools/textures/paint.py`, `tools/textures/test_paint.py` | `glazing` and `quarries` paintings |
| `scripts/Visual/glazing.gdshader` (new), `scripts/Visual/Materials.gd` | the glass; `quarries` slot |
| `tools/level/markers.py`, `tools/level/export.py`, `scripts/Level/LevelLoader.gd` | `room` marker; manifest `windows`, glass never an occluder; `Level.windows`, `glass` group |
| `scripts/StimuliSystem/SightRay.gd` (new), `scripts/AISystem/Guard.gd`, `scripts/StimuliSystem/LightProbe.gd` | rays that step past glass |
| `scripts/Visual/GodRays.gd`, `scripts/Visual/god_rays.gdshader` | per-corner reaches, point source, weight, follow_moon, tint, gain |
| `scripts/Visual/Windows.gd` (new), `scripts/Level/DistrictMap.gd` | moon shafts, rooms, lamplight, ROOFED re-cast; made at load |
| `tools/level/kit_customs.py`, `tools/level/kit_ships.py` | the customs house's and the carrack's windows glazed |
| `tools/level/layouts/harbour/markers.py` | room markers |
| `tests/windows_test.gd/.tscn` (new) | GW1-GW20 |

---

### Task 1: kit_glazing, the glazed opening

**Files:**
- Create: `tools/level/kit_glazing.py`
- Create: `tools/level/test_glazing.py`
- Modify: `tools/level/level.sh` (the `test` verb runs `test_glazing.py` after `test_kits.py`)

**Interfaces:**
- Produces (all in a wall frame: x along the wall, y up, the outer face at `face_z` looking +z, the inner face at `face_z - thickness`):
  - `SETBACK = 0.15`, `LEADS = {"quarries": "quarries", "casement": "casement", "grille": "window_grille"}`
  - `outline(x, sill, width, height, shape="square") -> list[[x, y]]`: counter-clockwise from outside, starting at the sill's left corner. `"square"` 4 points; `"round"` the 2 sill corners then the head from the right springing over to the left, 8 segments (9 points: 11 in all), springing at `sill + height - width / 2`; `"arched"` (pointed, equilateral) 4 segments a side (2 + 9 points).
  - `glazed(x, sill, width, height, face_z, thickness, shape="square", lead="casement", setback=SETBACK, slot="granite", inner_slot="plaster") -> (shapes, cols, record)`: everything inside the opening's rectangle `(x - w/2, x + w/2, sill, sill + height)`: jamb and head reveals from `face_z` to `face_z - thickness` (outer half in `slot`, inner half in `inner_slot`), the sill's top, the spandrels above a round or arched head (both faces), the glass (`glazing`) at `face_z - setback` in the outline's shape drawn both ways, the lead (`LEADS[lead]`) 1 cm in front of the glass, UVs spanning the rectangle 0..1, drawn both ways; one collider `[x, sill + h/2, face_z - thickness/2, w, h, thickness, "glass", 0, 0, 0]`; `record = {"outline": [[x, y, face_z - setback], ...], "normal": [0.0, 0.0, 1.0], "lead": lead}`.
  - `hole(x, sill, width, height) -> (x0, x1, y0, y1)`.
  - `split(x0, x1, y0, y1, holes) -> list[(a0, a1, b0, b1)]`: rectangles covering the area less the holes (copy kit_town.split's algorithm; do not import kit_town).
  - `strips(x0, x1, y0, y1, zc, thickness, holes, slot, surface="stone") -> (shapes, cols)`: a box and a collider for each `split` rectangle; no collider spans a hole.
  - `around(outline, holes, axis, slot, facing) -> shapes`: `outline` 3D points on a plane `axis` ("x" or "z") = constant, monotone in y; `holes` rectangles `(u0, u1, v0, v1)` with (u, v) = (z, y) for axis "x", (x, y) for axis "z"; `facing` the face's normal (3-vector). Returns polygons covering the outline less the holes.
  - `moved(records, yaw=0.0, offset=(0, 0, 0)) -> records`: turned and moved exactly as `kit_shapes.moved` turns shapes (outline points and normal; the normal not offset).

`around`'s algorithm (the signature does not fix it): take the outline's left and right boundaries u_left(v), u_right(v) (piecewise linear); cut at every outline vertex's v and every hole's v0, v1; each band [va, vb] is a trapezoid; within it leave out the u-spans of the holes covering the band; each remaining piece is a quad wound to face `facing`.

- [ ] **Step 0: Set up the workspace (untracked)**

```bash
mkdir -p .superpowers/sdd/2026-10-03-real-windows tests/diag
cp -R ../city-harbour/textures/ps2 textures/
cp ../city-harbour/tests/diag/diag_look.* ../city-harbour/tests/diag/diag_holes.* tests/diag/
printf '# Real windows ledger\n' > .superpowers/sdd/2026-10-03-real-windows/progress.md
```
Expected: `ls textures/ps2 | wc -l` > 100; `git status --short` shows nothing new (all excluded).

- [ ] **Step 1: Write the failing tests** in `tools/level/test_glazing.py` (unittest, runnable as `python3 tools/level/test_glazing.py`, same header style as test_kits.py):

```python
class Glazed(unittest.TestCase):
    def setUp(self):
        self.shapes, self.cols, self.rec = kit_glazing.glazed(0.0, 1.0, 1.0, 1.7, 0.0, 0.6, shape="round", lead="quarries")

    def test_the_outline_is_a_round_head_of_eight_segments(self):
        pts = kit_glazing.outline(0.0, 1.0, 1.0, 1.7, "round")
        self.assertEqual(len(pts), 11)
        self.assertAlmostEqual(max(p[1] for p in pts), 2.7, places=6)
        self.assertAlmostEqual(pts[2][1], 2.2, places=6)  # the right springing

    def test_the_reveals_go_through_the_whole_wall(self):
        built = kit_shapes.build(self.shapes)
        zs = [v[2] for v in built["verts"]]
        self.assertAlmostEqual(max(zs), 0.0, places=4)
        self.assertAlmostEqual(min(zs), -0.6, places=4)

    def test_the_glass_is_set_back_and_the_lead_in_front(self):
        glass = [s for s in self.shapes if s.get("slot") == "glazing"]
        lead = [s for s in self.shapes if s.get("slot") == "quarries"]
        self.assertTrue(glass and lead)
        gz = {round(p[2], 4) for s in glass for p in s["points"]}
        lz = {round(p[2], 4) for s in lead for p in s["points"]}
        self.assertEqual(gz, {-0.15})
        self.assertEqual(lz, {-0.14})

    def test_the_collider_fills_the_opening_as_glass(self):
        self.assertEqual(len(self.cols), 1)
        c = self.cols[0]
        self.assertEqual(c[6], "glass")
        self.assertEqual([round(v, 4) for v in c[:6]], [0.0, 1.85, -0.3, 1.0, 1.7, 0.6])

    def test_the_record_is_the_glass(self):
        self.assertEqual(self.rec["normal"], [0.0, 0.0, 1.0])
        self.assertEqual(self.rec["lead"], "quarries")
        self.assertEqual(len(self.rec["outline"]), 11)
        self.assertTrue(all(abs(p[2] + 0.15) < 1e-6 for p in self.rec["outline"]))


class Walls(unittest.TestCase):
    def test_no_strip_collider_spans_a_hole(self):
        holes = [kit_glazing.hole(2.0, 1.0, 1.0, 1.5), kit_glazing.hole(5.0, 0.0, 1.2, 2.2)]
        shapes, cols = kit_glazing.strips(0.0, 8.0, 0.0, 4.0, -0.3, 0.6, holes, "whitewash")
        for c in cols:
            for x0, x1, y0, y1 in holes:
                overlap = min(c[0] + c[3] / 2, x1) - max(c[0] - c[3] / 2, x0) > 1e-6 and min(c[1] + c[4] / 2, y1) - max(c[1] - c[4] / 2, y0) > 1e-6
                self.assertFalse(overlap, c)
        area = sum(c[3] * c[4] for c in cols)
        self.assertAlmostEqual(area, 32.0 - 1.5 - 1.2 * 2.2, places=6)

    def test_around_leaves_the_holes_and_covers_the_rest(self):
        outline = [[0.0, 0.0, -2.0], [0.0, 0.0, 2.0], [0.0, 3.0, 1.6], [0.0, 3.0, -1.6]]  # an x-plane, narrowing upward
        holes = [(-1.5, -1.0, 1.2, 1.8), (1.0, 1.5, 1.2, 1.8)]
        faces = kit_glazing.around(outline, holes, "x", "wood_old", (1.0, 0.0, 0.0))
        area = sum(polygon_area(f["points"]) for f in faces)
        self.assertAlmostEqual(area, 0.5 * (4.0 + 3.2) * 3.0 - 2 * 0.5 * 0.6, places=4)
        for f in faces:
            self.assertGreater(kit_shapes._normal(f["points"])[0], 0.99)
            cx = sum(p[2] for p in f["points"]) / len(f["points"])
            cy = sum(p[1] for p in f["points"]) / len(f["points"])
            self.assertFalse(any(u0 < cx < u1 and v0 < cy < v1 for u0, u1, v0, v1 in holes))

    def test_moved_records_turn_like_shapes(self):
        rec = kit_glazing.glazed(0.0, 1.0, 1.0, 1.5, 0.0, 0.6)[2]
        turned = kit_glazing.moved([rec], -90.0, (10.0, 0.0, 5.0))[0]
        probe = kit_shapes.moved([kit_shapes.polygon(rec["outline"], "glazing")], -90.0, (10.0, 0.0, 5.0))[0]["points"]
        for a, b in zip(turned["outline"], probe):
            self.assertTrue(all(abs(a[i] - b[i]) < 1e-6 for i in range(3)))
        self.assertAlmostEqual(abs(turned["normal"][0]), 1.0, places=6)
```
(`polygon_area` is a small helper in the test file: the planar polygon's area via the cross-product sum.)

- [ ] **Step 2: Run, expect failure**

Run: `python3 tools/level/test_glazing.py`
Expected: FAIL / ERROR, `ModuleNotFoundError: No module named 'kit_glazing'`.

- [ ] **Step 3: Implement `tools/level/kit_glazing.py`** with the interfaces above (pure data, imports `kit_shapes as ks` only; module docstring in the kits' style). The round head's reveal soffit can be `ks.ring` segments or polygons, whichever stays watertight with the spandrels.

- [ ] **Step 4: Run, expect pass**

Run: `python3 tools/level/test_glazing.py && python3 tools/level/test_kit_shapes.py`
Expected: all OK.

- [ ] **Step 5: Commit**

```bash
git add tools/level/kit_glazing.py tools/level/test_glazing.py tools/level/level.sh
git commit -m "feat(windows): kit_glazing, a glazed opening through the wall with its record"
```

### Task 2: The glass and the lead, painted and shaded

**Files:**
- Modify: `tools/textures/paint.py` (two paintings, registered in `PAINTINGS`), `tools/textures/test_paint.py`
- Create: `scripts/Visual/glazing.gdshader`
- Modify: `scripts/Visual/Materials.gd` (slots `glazing`, `quarries`; `level_surface` special case for `glazing`)
- Create: `textures/painted/glazing.png`, `textures/painted/quarries.png` (generated, committed with their `.import`)

**Interfaces:**
- Produces: slot `glazing` → `ShaderMaterial` (glazing.gdshader); slot `quarries` → painted, `cut: true` (alpha scissor) like `casement`.
- `glazing.gdshader` uniforms: `sampler2D grime : filter_nearest_mipmap` (the painting), `vec3 tint = (0.55, 0.62, 0.56)`, `float clear = 0.12`, `float grimy = 0.35`, `vec3 sky : source_color` (the sheen's colour), `float sheen = 0.5`. Render mode: `blend_mix, cull_disabled, depth_draw_opaque` (NO `depth_prepass_alpha`: alpha-blended surfaces stay out of the shadow pass). `ALPHA = mix(clear, grimy, grime.r) + fresnel * sheen`; `ROUGHNESS` 0.08; `SPECULAR` 0.6.

- [ ] **Step 1: Failing paint tests** (in test_paint.py):

```python
class Glazing(unittest.TestCase):
    def test_quarries_are_dark_lead_diamonds_cut_clean(self):
        image = paint.PAINTINGS["quarries"]()
        w, h = image.size
        self.assertEqual((w & (w - 1), h & (h - 1)), (0, 0))
        pixels = np.asarray(image)
        alpha = pixels[:, :, 3]
        self.assertTrue(set(np.unique(alpha)) <= {0, 255})
        self.assertTrue(0.08 < (alpha == 255).mean() < 0.35, "lead covers a small share")
        self.assertLess(pixels[alpha == 255][:, :3].mean(), 90.0, "lead is dark")

    def test_glazing_is_grime_thicker_at_the_edges(self):
        g = np.asarray(paint.PAINTINGS["glazing"]().convert("L"), dtype=float)
        h, w = g.shape
        edge = np.concatenate([g[:, : w // 8].ravel(), g[:, -w // 8 :].ravel(), g[-h // 8 :, :].ravel()])
        middle = g[h // 4 : 3 * h // 4, w // 4 : 3 * w // 4]
        self.assertGreater(edge.mean(), middle.mean() + 20.0)
```

- [ ] **Step 2: Run, expect failure**: `python3 -m unittest tools/textures/test_paint.py -v` → KeyError `'quarries'`.

- [ ] **Step 3: Implement** `quarries()` (64 x 128 px x SCALE: diamond lattice of lead cames, panes clear, a lead frame round the edge; `_finish(image, (64, 128), 8, mask_image)` as casement) and `glazing()` (64 x 128 greyscale-in-RGB: soft waves and a few seeds over a low base, grime rising toward the edges and the foot, seeded rng). Generate: `python3 tools/textures/paint.py quarries glazing`.

- [ ] **Step 4: Run, expect pass**: `python3 -m unittest tools/textures/test_paint.py -v` → OK.

- [ ] **Step 5: Shader + Materials.** Write `glazing.gdshader` per the interface; in `Materials.gd` add `&"glazing": {"photo": "glazing", "painted": true, "colour": Color("8C9E8F"), "metallic": 0.0, "roughness": 0.08}` and `&"quarries": {"photo": "quarries", "painted": true, "colour": Color("2A2B2C"), "metallic": 0.3, "roughness": 0.6, "cut": true}`; in `level_surface`, before the foliage case: `glazing` → a cached `ShaderMaterial` with `grime` = `photo(&"glazing")`, `sky` = Color(0.16, 0.2, 0.3). Import: `$GODOT --headless --path . --import`.

- [ ] **Step 6: Import cleanly**: `$GODOT --headless --path . --import 2>&1 | grep -i -E "glazing|quarries|error"` → no shader compile error. (The materials' kinds are asserted by GW1 in Task 3.)

- [ ] **Step 7: Commit**

```bash
git add tools/textures/paint.py tools/textures/test_paint.py textures/painted/glazing.png* textures/painted/quarries.png* scripts/Visual/glazing.gdshader scripts/Visual/Materials.gd
git commit -m "feat(windows): crown glass and diamond quarries, painted; the glazing shader lets the moon through"
```

### Task 3: Records through export and load; sight and light through glass

**Files:**
- Modify: `tools/level/markers.py` (schema `"room": {"required": [], "optional": {}, "box": True}`)
- Modify: `tools/level/kit_glazing.py` (`world_windows`), `tools/level/geo.py:213` (a `glass` box is never an occluder)
- Modify: `tools/level/export.py` (`manifest`: `"windows": kit_glazing.world_windows(data["pieces"], kit_recipes.PIECES)`)
- Modify: `tools/level/test_glazing.py` (class `Manifest`)
- Modify: `scripts/Level/LevelLoader.gd` (`Level.windows`; `_without` filters `"windows"`; the `glass` body joins group `&"glass"`)
- Create: `scripts/StimuliSystem/SightRay.gd`
- Modify: `scripts/AISystem/Guard.gd:1098` (`_line_of_sight`), `scripts/StimuliSystem/LightProbe.gd:75` (the shadow ray)
- Create: `tests/windows_test.gd`, `tests/windows_test.tscn`

**Interfaces:**
- Consumes: `PIECES[name]["windows"]` records (Task 1).
- Produces:
  - `kit_glazing.world_windows(pieces: list, recipes: dict) -> list`: for each placed piece whose recipe has `"windows"`, each record as `{"piece": str, "sector": str, "lead": str, "outline": [[x, y, z], ...], "normal": [x, y, z]}` in world space (`geo.add(position, geo.apply(basis, point))` for points, `geo.apply(basis, normal)` for the normal), rounded to 4 places. Pure (no Blender): `export.py` imports bmesh/bpy and cannot be unit-tested, so the manifest only calls this.
  - `geo.piece_boxes`: `box.occluder` is False for a box of surface `"glass"` (as well as for indices in `occlusion_exclude`); the manifest already writes `"occluder": False` for those.
  - `LevelLoader.Level.windows: Array` (the manifest's list).
  - `SightRay.first_solid(space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, skip: Array[StringName] = [&"glass"]) -> Dictionary`: `intersect_ray`, and while the hit collider is in any `skip` group, add its RID to `query.exclude` and cast again (at most 8 casts); returns the first other hit or `{}`.
  - `tests/windows_test.gd` scaffold: city_test's `_check`, `_frames`, `_seconds`, `_until`, results printing and `--only=<step>`; steps run in order; a helper `_fixture(walls_open := true) -> LevelLoader.Level` that writes `user://glass_fixture/glass_fixture.json` and loads it.

The fixture (all colliders surface "stone" unless said; basis rows identity; sector "s"): floor (0, -0.1, 0) size (7, 0.2, 7); ceiling (0, 3.1, 0) (7, 0.2, 7); north wall (0, 1.5, -3.2) (7, 3, 0.4); east (3.2, 1.5, 0) (0.4, 3, 7); west (-3.2, 1.5, 0) (0.4, 3, 7); the south wall round an opening x -0.5..0.5, y 1..2.5: (-1.95, 1.5, 3.2) (2.9, 3, 0.4), (1.95, 1.5, 3.2) (2.9, 3, 0.4), (0, 0.5, 3.2) (1, 1, 0.4), (0, 2.75, 3.2) (1, 0.5, 0.4); the glass (0, 1.75, 3.2) (1, 1.5, 0.4) surface "glass", occluder false. Window: piece "fixture_wall", sector "s", lead "casement", outline [[-0.5, 1, 3.15], [0.5, 1, 3.15], [0.5, 2.5, 3.15], [-0.5, 2.5, 3.15]], normal [0, 0, 1]. Marker `room_fixture`, ucd "room", position (0, 1.5, 0), size [6, 3, 6], props {}.

- [ ] **Step 1: Failing Python test** (test_glazing.py):

```python
class Manifest(unittest.TestCase):
    def setUp(self):
        shapes, cols, rec = kit_glazing.glazed(0.0, 1.0, 1.0, 1.5, 0.0, 0.6)
        wall = [0.0, 3.0, -0.3, 4.0, 1.0, 0.6, "stone", 0, 0, 0]
        self.recipe = {"family": "dressing", "slot": "stone", "surface": "stone", "boxes": [], "cols": cols + [wall], "windows": [rec],
                       "sockets": {}, "size": None, "opening": None, "shapes": shapes}
        self.rec = rec

    def test_windows_are_put_in_the_world(self):
        basis = [[0.0, 0.0, 1.0], [0.0, 1.0, 0.0], [-1.0, 0.0, 0.0]]  # turned 90 degrees
        pieces = [{"name": "probe", "piece": "glazing_probe", "sector": "s", "position": [10.0, 0.0, 5.0], "basis": basis},
                  {"name": "plain", "piece": "plain_probe", "sector": "s", "position": [0.0, 0.0, 0.0], "basis": geo.IDENTITY}]
        out = kit_glazing.world_windows(pieces, {"glazing_probe": self.recipe, "plain_probe": dict(self.recipe, windows=[])})
        self.assertEqual(len(out), 1)
        w = out[0]
        self.assertEqual((w["piece"], w["sector"], w["lead"]), ("probe", "s", "casement"))
        self.assertEqual(w["normal"], [round(v, 4) for v in geo.apply(basis, [0.0, 0.0, 1.0])])
        first = geo.add([10.0, 0.0, 5.0], geo.apply(basis, self.rec["outline"][0]))
        self.assertEqual(w["outline"][0], [round(v, 4) for v in first])

    def test_glass_never_occludes(self):
        boxes = geo.piece_boxes(self.recipe, [0.0, 0.0, 0.0], geo.IDENTITY)
        self.assertEqual([b.occluder for b in boxes if b.surface == "glass"], [False])
        self.assertEqual([b.occluder for b in boxes if b.surface == "stone"], [True])
```

- [ ] **Step 2: Run, expect failure**: `python3 tools/level/test_glazing.py Manifest` → AttributeError `world_windows`.

- [ ] **Step 3: Implement** the schema entry, `world_windows`, the geo rule, and the one line in `export.manifest`.

- [ ] **Step 4: Run, expect pass**: `python3 tools/level/test_glazing.py && tools/level/level.sh test` → all OK.

- [ ] **Step 5: Failing Godot checks** in `tests/windows_test.gd` (step `"loader"`, step `"sight"`):

```gdscript
# GW1
var level := _fixture()
var glass := level.root.find_children("*", "StaticBody3D", true, false).filter(func(b): return b.is_in_group(&"glass"))
var occluded := level.root.get_node("Occluders").get_children().any(func(o): return o.position.distance_to(Vector3(0, 1.75, 3.2)) < 0.01)
var cut := LevelLoader.load_level(self, "user://glass_fixture", "Cut", ["s"])
_check("GW1 a level's windows and room load; its glass bodies are in 'glass' and never occlude; a left-out sector drops its windows; glazing blends, quarries cut",
	level.windows.size() == 1 and level.of("room").size() == 1 and glass.size() == 1 and not occluded and cut.windows.is_empty()
	and Materials.level_surface(&"glazing") is ShaderMaterial and (Materials.level_surface(&"glazing") as ShaderMaterial).shader.code.contains("blend_mix")
	and not (Materials.level_surface(&"glazing") as ShaderMaterial).shader.code.contains("depth_prepass_alpha")
	and (Materials.level_surface(&"quarries") as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, detail)

# GW2 (after two physics frames)
var space := get_world_3d().direct_space_state
var through := SightRay.first_solid(space, PhysicsRayQueryParameters3D.create(Vector3(0, 1.75, 6), Vector3(0, 1.75, 0), 1))
var wall := SightRay.first_solid(space, PhysicsRayQueryParameters3D.create(Vector3(2, 1.75, 6), Vector3(2, 1.75, 0), 1))
# (GW2b: a second pane in the way, a glass box at (0, 1.75, 4.5) in group "glass".)
var twice := SightRay.first_solid(space, PhysicsRayQueryParameters3D.create(Vector3(0, 1.75, 6), Vector3(0, 1.75, 0), 1))
_check("GW2 a ray through one pane, or two, goes on; through a wall it stops", through.is_empty() and twice.is_empty() and not wall.is_empty(), detail)

# GW3: a DirectionalLight3D (shadow_enabled, toward (0, -0.57, -0.82)), LightProbe.invalidate()
var lit := LightProbe.light_at(self, Vector3(0, 0.05, 0.5))
var dark := LightProbe.light_at(self, Vector3(2.0, 0.05, 0.5))
_check("GW3 the probe reads the moon through the glass on the patch, and none a step beside under the ceiling", lit > dark + 0.3, "%.2f vs %.2f" % [lit, dark])
```

- [ ] **Step 6: Run, expect failure**: `$GODOT --headless --fixed-fps 60 --path . res://tests/windows_test.tscn` → GW1 FAIL (`windows` not on Level), GW2/GW3 error on `SightRay`.

- [ ] **Step 7: Implement** `LevelLoader` (`var windows: Array = []`, `level.windows = manifest.get("windows", [])`, `"windows"` in `_without`'s keys, `body.add_to_group(&"glass")` when the surface is "glass"), `SightRay.gd`, and swap both rays: Guard `_line_of_sight` → `SightRay.first_solid(get_world_3d().direct_space_state, query)`; LightProbe's shadow ray → `not SightRay.first_solid(space, query).is_empty()`.

- [ ] **Step 8: Run, expect pass**: windows_test GW1-GW3 PASS; then `tools/run_suites.sh tests/stealth_test.tscn tests/city_test.tscn tests/lights_test.tscn tests/level_test.tscn` → no new failures.

- [ ] **Step 9: Commit**

```bash
git add tools/level/markers.py tools/level/kit_glazing.py tools/level/geo.py tools/level/export.py tools/level/test_glazing.py scripts/Level/LevelLoader.gd scripts/StimuliSystem/SightRay.gd scripts/AISystem/Guard.gd scripts/StimuliSystem/LightProbe.gd tests/windows_test.gd tests/windows_test.tscn
git commit -m "feat(windows): window records and rooms through export and load; sight and light pass glass"
```

### Task 4: GodRays, extended

**Files:**
- Modify: `scripts/Visual/GodRays.gd`, `scripts/Visual/god_rays.gdshader`
- Modify: `tests/windows_test.gd` (step `"rays"`)

**Interfaces:**
- Produces:
  - `@export var follow_moon := true`, `@export var tint := Color(0.6, 0.78, 1.25)`, `@export var gain := 0.14` (pushed to the shader's `tint` and `gain` in `_ready`).
  - `add_window(outline: PackedVector3Array, uvs: PackedVector2Array, reaches := PackedFloat32Array(), source := Vector3.INF, weight := 1.0) -> MeshInstance3D`: each corner's way is `(p - source).normalized()` when `source` is finite, else `direction.normalized()`; its far end `p + way * reaches[i]` when `reaches.size() == outline.size()`, else `_reach(p, way)` (the node's planes); UV2 = `(along, weight)`; the round normals use each corner's way.
  - `_process`: when `follow_moon` is false, `strength` is left as its owner sets it and only pushed to the material.
  - Shader: `ALBEDO *= UV2.y` (every shaft is made by `add_window`, so the chapel's get 1.0).

- [ ] **Step 1: Failing check GW4**:

```gdscript
var rays := GodRaysScript.new(); rays.follow_moon = false; add_child(rays)
var outline := PackedVector3Array([Vector3(-0.5, 1, 0), Vector3(0.5, 1, 0), Vector3(0.5, 2, 0), Vector3(-0.5, 2, 0)])
var uvs := PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
var source := Vector3(0, 1.5, -2)
var beam := rays.add_window(outline, uvs, PackedFloat32Array([1, 2, 3, 4]), source, 0.5)
var arrays := (beam.mesh as ArrayMesh).surface_get_arrays(0)
# For each corner i, a vertex at outline[i] + (outline[i] - source).normalized() * (i + 1) exists (within 1e-3),
# every UV2.y == 0.5; then rays.strength = 0.7, two frames, the material's "strength" == 0.7.
_check("GW4 a point-sourced shaft spreads from its lamp to each corner's own reach, carries its weight, and a lamp's node keeps the strength it is given", ok, detail)
```

- [ ] **Step 2: Run, expect failure** (`add_window` takes 2 arguments).
- [ ] **Step 3: Implement** per the interface.
- [ ] **Step 4: Run, expect pass**: GW4 PASS; `tools/run_suites.sh tests/level_test.tscn` → G24 (the chapel's rays) still PASS.
- [ ] **Step 5: Commit**

```bash
git add scripts/Visual/GodRays.gd scripts/Visual/god_rays.gdshader tests/windows_test.gd
git commit -m "feat(windows): god rays from a point, to each corner's own reach, weighted"
```

### Task 5: Windows.gd, the moon in

**Files:**
- Create: `scripts/Visual/Windows.gd`
- Modify: `scripts/Level/DistrictMap.gd` (make it after the navmesh, before the guards)
- Modify: `tests/windows_test.gd` (step `"moon"`)

**Interfaces:**
- Consumes: `Level.windows`, `Level.of("room")` (Task 3); `GodRays.add_window(...)` (Task 4); `SightRay.first_solid` (Task 3).
- Produces (`extends Node3D`, preloaded by path):
  - constants: `FACING := 0.1`, `SKY_NEEDED := 5`, `SKY_REACH := 200.0`, `ROOM_REACH := 30.0`, `INSIDE := 0.3`, `MOON_TINT := Color(0.6, 0.78, 1.25)`.
  - `var windows: Array[Dictionary]` each `{piece: String, lead: String, outline: PackedVector3Array, normal: Vector3, middle: Vector3, room: String, facing: float, sky: float, shaft: MeshInstance3D (or null), spot: SpotLight3D (or null), lamp_shaft: MeshInstance3D (or null)}`.
  - `var rooms: Dictionary` name → `{transform: Transform3D, size: Vector3, lamps: Array, lamp: Node3D (or null), rays: Node3D (or null), fade: float}`.
  - `var moon_rays: Node3D` (one GodRays: `direction` the moon's way, `tint` MOON_TINT, `least` 0.0, `follow_moon` true, glass null).
  - `var recast: Array[GeometryInstance3D]`.
  - `build(levels: Array, made: Array, moon: DirectionalLight3D) -> void` (levels: LevelLoader.Level; made: LevelGameplay dicts, used in Task 6).
  - `rebuild() -> void`: frees every shaft and spot and builds again (counts stable).
  - `room_of(point: Vector3) -> String`: the smallest room box holding the point (in its transform's frame), "" if none.
- The moon's way: `-moon.global_basis.z` (the light shines along -Z).
- A window's moon shaft: `facing = normal.dot(-way)`; skip at or under FACING. Sky: 9 points at fractions (0.2, 0.5, 0.8) across the outline's bounding rectangle in its plane (across = `normal.cross(Vector3.UP).normalized()`), each `p + normal * 0.05` cast toward `-way` for SKY_REACH (mask 1, skip glass); `sky = clear / 9.0`; skip under SKY_NEEDED clear. Reach: each outline corner cast from `q + way * 0.02` along `way` for ROOM_REACH, skipping `[&"glass", &"loose"]`: the hit distance from `q`, else ROOM_REACH. Then `moon_rays.add_window(outline, uvs, reaches, Vector3.INF, sky)`, UVs the corners' places in the bounding rectangle.
- ROOFED re-cast: every `GeometryInstance3D` under the levels' roots with `layers == Layers.ROOFED` whose global AABB meets any moon shaft's AABB goes to `Layers.WORLD` and into `recast`.
- DistrictMap: `var windows: Node3D = null`; after `await baker.baked` and `LightProbe.invalidate()`: make it, `build` with every level but `MASSING` (and their `made`) and `night.moon`, then `LightProbe.invalidate()` again.

- [ ] **Step 1: Failing checks GW5-GW8, GW11** (fixture from Task 3; moon toward (0, -0.57, -0.82); a stub night in group `&"night"` whose `moon_share()` returns a settable `share`):

```gdscript
# GW5: a: built as is -> windows[0].shaft != null; b: the moon toward (0, -0.57, 0.82) (behind), rebuild -> null;
#      c: a box (0, 4, 6) size (4, 6, 1) outside, rebuild -> null; and, from a fixture written without its room marker, the shaft is built and the window's room is "";
#      d: rebuild() twice -> moon_rays.beams.size() unchanged and no freed node left in windows.
_check("GW5 a moon shaft only where the moon stands in front of the glass and sees it; any room or none; rebuilt without duplicates", ok, detail)
# GW6: every far vertex of the shaft (UV2.x == 1) has y within 0.1 of 0 (the floor)
_check("GW6 a moon shaft ends on what its corners' rays hit (the floor)", ok, detail)
# GW7: a MeshInstance3D (BoxMesh 0.5) at (0, 0.25, 0.8) on Layers.ROOFED under level.root goes to WORLD; one at (2.5, 0.25, -2.5) stays ROOFED
_check("GW7 what stands under a roof in a moon shaft casts again; elsewhere not", ok, detail)
# GW8: room_of(Vector3(0, 1.5, 0)) == "room_fixture"; with a second marker room_inner (0, 1.5, 0) size [2, 2, 2]: room_of -> "room_inner"; room_of(Vector3(0, 1.5, 9)) == ""
_check("GW8 a point's room is the smallest box holding it", ok, detail)
# GW11: share 0.0 -> moon_rays.strength < 0.01 after two frames; share 2.0 -> strength > brightness
_check("GW11 a cloud over the moon puts the window shafts out; lightning flares them", ok, detail)
```
(Room markers for GW8 are added to the fixture JSON by `_fixture(extra_rooms)`.)

- [ ] **Step 2: Run, expect failure** (no Windows.gd).
- [ ] **Step 3: Implement** Windows.gd's moon half and the DistrictMap hook per the interfaces.
- [ ] **Step 4: Run, expect pass**: GW5-GW8, GW11 PASS; `tools/run_suites.sh tests/city_test.tscn tests/transitions_test.tscn tests/state_test.tscn` → no new failures (the harbour has no records yet: Windows builds nothing).
- [ ] **Step 5: Commit**

```bash
git add scripts/Visual/Windows.gd scripts/Level/DistrictMap.gd tests/windows_test.gd
git commit -m "feat(windows): moon shafts through every window the moon reaches, built at load"
```

### Task 6: Windows.gd, lamplight out

**Files:**
- Modify: `scripts/Visual/Windows.gd`, `tests/windows_test.gd` (step `"lamps"`)

**Interfaces:**
- Consumes: `made[i]["lights"]` (marker name → Torch/LightFixture: `is_lit() -> bool`, `lit_changed(lit: bool)`, `light: OmniLight3D`).
- Produces: constants `OUT_REACH := 10.0`, `SPOT_OUT := 0.05`, `SPOT_PAD := 4.0`, `SPOT_RANGE := 8.0`, `SPOT_GAIN := 0.5`, `FADE := 0.3`, `POLL := 0.25`, `LAMP_TINT := Color(1.0, 0.62, 0.3)`, `LAMP_GAIN := 0.14 / 3.0`, `PAINTINGS := {"quarries": &"quarries", "casement": &"casement", "grille": &"window_grille"}`; per room `lamps` (every made light with `is_lit` whose position's `room_of` is the room), `lamp` (the lit lamp nearest the mean middle of the room's windows, or null), `fade` (0..1), `rays` (a GodRays, `follow_moon` false, `tint` LAMP_TINT, `gain` LAMP_GAIN); per window `spot`, `lamp_shaft`.
- Behaviour:
  - When a room's `lamp` changes to another lamp: free its windows' spots and lamp shafts and build them for the new lamp (fade carries on). When none is lit: keep them, fade to 0.
  - Spot: at `middle + normal * SPOT_OUT`, looking along `(middle - lamp_pos).normalized()`; `spot_angle = rad_to_deg(atan(half_diagonal / distance)) + SPOT_PAD`; `spot_range` SPOT_RANGE; no shadow, `set_meta(&"casts_shadow", false)`; colour the lamp light's; projector `Materials.photo(PAINTINGS[lead])`; NOT in group `lights`.
  - Lamp shaft: corners going out (`way.dot(normal) > 0`), `way = (q - lamp_pos).normalized()`, reach by ray (skip glass and loose) up to OUT_REACH, cut where it goes under the `surface_y()` of a body in group `&"water"` that is `over()` the point; `rays.add_window(outline, uvs, reaches, lamp_pos)`.
  - `_process(delta)`: every POLL s re-pick each room's lamp (catches a state restored without a signal, a lamp freed: `is_instance_valid`); `lit_changed` also re-picks at once; `fade = move_toward(fade, 1.0 if lamp else 0.0, delta / FADE)`; `rays.strength = fade`; each spot `light_energy = SPOT_GAIN * lamp.light.light_energy * fade` (the candle's flicker carried).

- [ ] **Step 1: Failing checks GW9, GW10** (fixture; `Lights.candle(self, Vector3(0, 1.0, 0))` as lamp A, `Lights.candle(self, Vector3(0, 1.0, -2.0))` as lamp B, `Lights.candle(self, Vector3(0, 1.0, 9.0))` as lamp C (outside every room), `made = [{"lights": {"a": A, "b": B, "c": C}}]`, all given to `build`; two seconds for the fixtures to settle):

```gdscript
# GW9 a: windows[0].spot exists, its global_position.z > 3.15, energy > 0.05, rooms.room_fixture.lamp == A
#     b: A.put_out(&"douse") -> lamp becomes B within 0.5 s, spot energy > 0.05 (B lit)
#     c: B.put_out(&"douse") -> within 0.5 s spot energy < 0.01 and fade < 0.01; A.relight() -> within 0.5 s energy > 0.05
#     d: C is in no room's lamps and no spot was ever aimed from it (each spot's aim passes within 0.1 m of A or B)
#     e: A.queue_free() while chosen (B still out) -> within 0.5 s the room's lamp is null and its spot energy < 0.01, no error
_check("GW9 a lit room throws its nearest lamp out through its glass; doused, the next; none, dark; a lamp in no room, or freed, is no one's", ok, detail)
# GW10: A.set("lit", false) without put_out (state restored silently) -> within 0.5 s the room no longer uses A
_check("GW10 a lamp's state restored without a signal is caught within the poll", ok, detail)
```

- [ ] **Step 2: Run, expect failure** (no spots).
- [ ] **Step 3: Implement** the lamplight half per the interfaces.
- [ ] **Step 4: Run, expect pass**: windows_test GW1-GW11 PASS.
- [ ] **Step 5: Commit**

```bash
git add scripts/Visual/Windows.gd tests/windows_test.gd
git commit -m "feat(windows): a lit room's lamp thrown out through its glass, following douse and relight"
```

### Task 7: The customs house glazed

**Files:**
- Modify: `tools/level/kit_customs.py` (`_piece` gains `windows=None` and stores `kit_glazing.moved(windows, 0.0, offset)` on `PIECES[name]["windows"]`; `_window`, `_upper_front`, `_side`, `_west_wall`, `_back_wall`, `_portal_wall`)
- Modify: `tools/level/test_glazing.py` (class `Customs`)

**Interfaces:**
- Consumes: `kit_glazing.glazed`, `hole`, `strips`, `moved` (Task 1).
- Produces: pieces `customs_upper_front` (3 records, "round", "quarries"), `customs_west_wall` (6: 3 "casement" upper, 3 "grille" lower), `customs_back_wall` (6, same split), `customs_portal_wall` (2, "grille"), each with no collider spanning an opening.

What changes (keep every ornament: frames, sills, corbels, rope, spheres, cornices, quoins, shutters):
- `_window` keeps its rope, ring, sill, corbel and sphere; its glass/casement/disc cards and its reveal go (glazed draws them). The flush (tower) variant is unchanged.
- `_upper_front`: the body from `kit_glazing.strips` (holes: each window's `hole(x, sill, 1.0, 1.7)` and the loading door's rectangle), plus `glazed(x, sill, 1.0, 1.7, Z1, 0.5, shape="round", lead="quarries", slot="ashlar_gold", inner_slot="ashlar_gold")` per window; the hand-built spandrel triangles go (glazed's). The loading door's dark card and leaves stay.
- `_side(length, openings, door)`: the whitewash box becomes `strips(0, length, 0, EAVES, -WALL / 2, WALL, holes, "whitewash")` with holes: each opening's barred window `hole(x, 1.2, 0.9, 1.2)` and casement `hole(x, UP + 0.9, 0.9, 1.5)`, and the door's `hole(door, 0.0, 1.2, 2.2)` when given (today the back wall's collider runs across the yard door and its panel sits inside the box: this opens it). Windows: `glazed(x, 1.2, 0.9, 1.2, 0.0, WALL, lead="grille", slot="whitewash", inner_slot="whitewash")` and `glazed(x, UP + 0.9, 0.9, 1.5, 0.0, WALL, lead="casement", ...)`. The old window_grille/casement/glass_dark cards go. Return the records too; `_west_wall`/`_back_wall` turn them with `kit_glazing.moved` as they turn shapes.
- `_portal_wall`: its two barred windows `glazed(x, 1.0, 1.0, 1.4, HALL_FRONT, WALL, lead="grille", slot="granite", inner_slot="whitewash")`; its colliders split round them (today "a barred window stops a man: its whole height solid").

- [ ] **Step 1: Failing tests** (class `Customs` in test_glazing.py):

```python
EXPECTED = {"customs_upper_front": (3, {"quarries"}), "customs_west_wall": (6, {"casement", "grille"}),
            "customs_back_wall": (6, {"casement", "grille"}), "customs_portal_wall": (2, {"grille"})}

def test_each_wall_carries_its_windows(self):
    for name, (count, leads) in EXPECTED.items():
        recs = kit_recipes.PIECES[name].get("windows", [])
        self.assertEqual(len(recs), count, name)
        self.assertEqual({r["lead"] for r in recs}, leads, name)

def test_no_collider_but_glass_spans_a_window(self):
    for name in EXPECTED:
        recipe = kit_recipes.PIECES[name]
        for rec in recipe["windows"]:
            mid = [sum(p[i] for p in rec["outline"]) / len(rec["outline"]) for i in range(3)]
            inside = [mid[i] - 0.25 * rec["normal"][i] for i in range(3)]
            for box in geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY):
                if box.surface != "glass":
                    self.assertFalse(box_holds(box, mid) or box_holds(box, inside), (name, mid))

def test_the_back_walls_door_is_open(self):
    recipe = kit_recipes.PIECES["customs_back_wall"]
    door = [d - p for d, p in zip([kit_customs.X1 - 8.0 + 0.0, 1.1, kit_customs.Z0 + kit_customs.WALL / 2.0], kit_customs.PIECE_AT["customs_back_wall"])]
    self.assertFalse(any(box_holds(b, door) for b in geo.piece_boxes(recipe, [0.0, 0.0, 0.0], geo.IDENTITY)))

def test_budgets_hold(self):
    for name in EXPECTED:
        self.assertLessEqual(tris(kit_recipes.PIECES[name]), kit_recipes.PIECES[name].get("budget", kit_shapes.PIECE_TRIS), name)
```
(`box_holds(box, point)` tests a point inside a geo box via its axes and half extents; `tris` as test_kits. The door point's x is in the back wall's own turned frame: check the sign against `_back_wall`'s 180-degree turn when writing it.)

- [ ] **Step 2: Run, expect failure**: `python3 tools/level/test_glazing.py Customs` → 0 records.
- [ ] **Step 3: Implement** per "What changes".
- [ ] **Step 4: Run, expect pass**: `tools/level/level.sh test` → all OK (raise a piece's `budget` only if the triangle count needs it, by the least amount).
- [ ] **Step 5: Render the pieces** (Blender workbench, the scratchpad render_pieces approach or `level.sh kit` + preview) of all four walls front and back at full size; list and fix any reveal not meeting its face, any gap round a spandrel, any lead not filling its glass.
- [ ] **Step 6: Commit**

```bash
git add tools/level/kit_customs.py tools/level/test_glazing.py
git commit -m "feat(windows): the customs house's windows glazed through its walls; its yard door opened"
```

### Task 8: The carrack's cabin glazed

**Files:**
- Modify: `tools/level/kit_ships.py` (`_stern`, the bulkhead in the castles' builder near line 832, the stern band of `_skin` where it crosses the cabin windows, the cabin colliders near line 1159; `PIECES["carrack_hull"]["windows"]`)
- Modify: `tools/level/test_glazing.py` (class `Carrack`)

**Interfaces:**
- Consumes: `kit_glazing.glazed`, `around`, `split`, `moved`.
- Produces: `PIECES["carrack_hull"]["windows"]`: 4 records, "quarries": 2 in the transom (normal (-1, 0, 0), middles at z ±1.25, y 3.6, glass 0.6 x 0.72), 2 in the bulkhead (normal (1, 0, 0), middles at z ±1.4, y 3.55, glass 0.5 x 0.6).

What changes:
- The transom: its outer band (from 2.45 up) and its inner face (`MAIN_DECK` to `CASTLE_DECK`) drawn with `kit_glazing.around(..., axis="x", ...)` round the two windows; each window's reveal and glass from `glazed(0.0, 0.0, 0.6, 0.72, 0.0, SKIN, lead="quarries", slot="timber", inner_slot="wood_old")` built in a +z frame, then turned with `ks.moved` (and its record with `kit_glazing.moved`) to face -x at `x = STERN`, centred at (z ±1.25, y 3.6). The glass_lit cards go; the timber frames stay.
- The bulkhead (`CASTLE_FRONT ± 0.1`): both faces of each half drawn with `around` round its window; the window glazed (thickness 0.2) facing +x; the glass_dark cards go.
- Colliders: the transom's single box and the bulkhead's two side boxes are each replaced by `split` rectangles round the windows (so no collider spans a window, and the transom no longer occludes the view out), plus the glass colliders.

- [ ] **Step 1: Failing tests** (class `Carrack`): 4 records with the normals and middles above (within 0.02 m); no non-glass collider of `carrack_hull` holds a record's middle or the point 0.15 m inside it; `test_ships.py` still passes; the hull within its budget.
- [ ] **Step 2: Run, expect failure** → 0 records.
- [ ] **Step 3: Implement** per "What changes".
- [ ] **Step 4: Run, expect pass**: `tools/level/level.sh test` → all OK.
- [ ] **Step 5: Render** the stern and the bulkhead, outside and inside, at full size; fix any hole in the skin round the cuts or band edge left open.
- [ ] **Step 6: Commit**

```bash
git add tools/level/kit_ships.py tools/level/test_glazing.py
git commit -m "feat(windows): the carrack's great cabin glazed, astern and onto the waist"
```

### Task 9: The harbour exported and played with real windows

**Files:**
- Modify: `tools/level/layouts/harbour/markers.py` (a `_rooms(L)` called from `lay`)
- Modify: `tests/windows_test.gd` (steps `"harbour_*"`: loads `maps/city.tscn` after the fixture steps, as city_test does, waiting for `ready_to_play`)
- Regenerated: `assets/level/source/kit.blend`, `assets/level/source/city_harbour.blend`, `assets/level/city_harbour/*`, `assets/level/navmesh/harbour.scn`, `assets/level/navmesh/old_town.scn` (and `assets/level/old_town/*` only if its export changes)

**Interfaces:**
- Consumes: everything above.
- Produces: room markers (sector "shipyard" or "ships"):
  - `room_customs_hall`: the box of `roofed_customs_hall` (same centre and size).
  - `room_customs_store`: the box of `roofed_customs_store`.
  - `room_customs_office`: house frame x from `kit_customs.OFFICE[0]` to `X1 - WALL`, z from `Z0 + WALL` to `OFFICE[1]`, y `CUSTOMS_UPPER` to `CUSTOMS_EAVES`, put in the world by the house's offset (`CUSTOMS_AT`): world x 4..13.4, z -33.4..-22.
  - `room_carrack_cabin`: the box of `zone_cabin`, sector "ships".

- [ ] **Step 1: Failing harbour checks**:

```gdscript
# GW12 the harbour's records: 21 (17 customs + 4 carrack); every glass body in "glass"; no occluder holds a record's middle
# GW13 the store front's three windows (normal.z > 0.9, middle y > CUSTOMS_UPPER) have moon shafts; no window with normal.z < -0.5 has one;
#      every shaft's window: facing > 0.1 and sky >= 5.0 / 9.0
# GW14 the probe: on the middle front window's shaft (the mean of its far vertices, up 0.05) lit; 1.2 m along the wall from it, inside, at least 0.15 darker
# GW15 a frozen guard on the quay sees, through the middle front window's glass, a point inside the store (the line crosses the outline: assert it);
#      the same line moved 2.25 m along the wall (through stone) is blocked
# GW16 a 2 kg RigidBody3D (layer 1, mask 1) thrown from inside the store at a front window's middle at 6 m/s outward is still inside after 1 s;
#      the player put on the hall floor facing a west window, walking and jumping into it for 2 s (city_test's _put/_steer), is still inside
# GW17 office_candle lit: the office's back window has a spot outside (its position z < the back wall's outer face) and a lamp shaft;
#      put_out -> spot energy < 0.01 within 0.5 s; relight -> > 0.05 within 0.5 s
# GW18 the cabin's lamps lit: its 4 windows each have a spot; the transom's spots lie astern (x < CARRACK_X + STERN), the bulkhead's over the waist (x > CARRACK_X + CASTLE_FRONT)
# GW19 Windows.recast is not empty and every recast mesh meets a moon shaft; no ROOFED mesh meets one
# GW20 office_candle.load_state({"lit": false}) -> its spot dark within 0.5 s; load_state({"lit": true}) -> lit again within 0.5 s
```

- [ ] **Step 2: Lay the rooms, build and export**:

```bash
tools/level/level.sh kit
tools/level/level.sh build city_harbour --force
tools/level/level.sh export city_harbour
tools/level/level.sh navmesh harbour
tools/level/level.sh navmesh old_town
```
Expected: each exits 0; the export's manifest has 21 windows: `python3 -c "import json; print(len(json.load(open('assets/level/city_harbour/city_harbour.json'))['windows']))"` → `21`. (`--force` is right only if `assets/level/source/city_harbour.blend` has no hand edits: check `git log -- assets/level/source/city_harbour.blend` and the `edited.py` guard's message first; if the user edited it, stop and ask.)

- [ ] **Step 3: Run, expect GW12-GW20 to pass**: `$GODOT --headless --fixed-fps 60 --path . res://tests/windows_test.tscn` → 20 pass, 0 fail. A failure here is fixed in the code it points at (Windows.gd, the kits), not by loosening the check.
- [ ] **Step 4: Regression**: `tools/run_suites.sh` (all), then cinema, intruder, showcase and talk alone (they tally 0/0 when run four at a time); compare against main's baseline (56 suites green). city_test's reach/locks/ways/holes must stay green with the yard door now open.
- [ ] **Step 5: Commit**

```bash
git add tools/level/layouts/harbour/markers.py tests/windows_test.gd assets/level
git commit -m "feat(windows): the harbour's rooms laid, exported with real windows; moon in, lamplight out"
```

### Task 10: Looked at closely, measured, finished

**Files:**
- Scratch (untracked): `.superpowers/sdd/2026-10-03-real-windows/views_day.json`, `views_night.json`, `bench.sh`, the renders
- Modify: whatever the inspection finds; `docs/superpowers/specs/2026-10-03-real-windows-design.md` (status line)

- [ ] **Step 1: Daylight close-ups.** Views (name, at, look, fov 60) for every one of the 21 windows from outside (2 m out, square on and 45 degrees) and inside (1.5 m in, square on, and up at the head), plus the carrack's stern and bulkhead from 3 m. Run:
`$GODOT --path . --resolution 1920x1080 res://tests/diag/diag_look.tscn -- --out=.superpowers/sdd/2026-10-03-real-windows/day --views=.superpowers/sdd/2026-10-03-real-windows/views_day.json`
Open every image at full size; write each defect into the ledger (a reveal not meeting its face, light leaking round a frame, lead not filling its glass, z-fighting, the glass reading as a hole, the yard door). Fix, re-render, repeat until none.
- [ ] **Step 2: Night stills.** The same tool with `--night`: the store from inside facing its front windows and looking down at the patches; the store front from the quay; the office window from the yard with the candle lit and doused; the carrack's stern from the water and her waist; the hall's west windows. Judge the shafts (do they land on the patches; are they too bright, too faint; dust; edge-on fade) and the lamplit patches (window-shaped bars, warmth). Tune only `Windows.gd` constants / GodRays gains, never the moon's energy or ambient; re-run windows_test after any constant changes.
- [ ] **Step 3: Holes.** `$GODOT --headless --path . res://tests/diag/diag_holes.tscn -- --out=.superpowers/sdd/2026-10-03-real-windows/holes`; no new void in or round the customs house and the carrack.
- [ ] **Step 4: Frame rate.** `bench.sh` as the harbour's (`maps/city.tscn -- --fps-report=40`, windowed 1920x1080) on this branch and on main; record both. Expected: within 3 fps and 1 ms p99 of main's (101.8 fps, p99 16.6 ms); if worse, find the cost (spots, transparent overdraw, lost occluders) before going on.
- [ ] **Step 5: Spec status.** Add a status line at the spec's top: built on `real-windows`, its commits, the bench numbers, and the deviations taken (if any) with their reasons.
- [ ] **Step 6: Commit**

```bash
git add -A tools scripts tests/windows_test.gd docs/superpowers/specs/2026-10-03-real-windows-design.md assets/level
git commit -m "fix(windows): what the close look found; the spec's status"
```
