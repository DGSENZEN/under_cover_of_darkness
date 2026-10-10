# Zócalo plan and greybox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Zócalo map as plan data (six plan sheets, checked), then that plan as a walkable greybox in Godot with stills and a frame-rate report.

**Architecture:**
- A `Plan` builder records the plan elements (ground areas, plots, routes, underground spaces, landmarks, the tram loop, event fields and the brink). The Zócalo's parts lay them in `tools/level/layouts/zocalo/`.
- `plan_check.py` gates the plan, and `plan_draw.py` renders the sheets.
- `greybox.py` turns the plan into plain geometry, overlap-gated in Python. Godot only loads that geometry (`GreyboxLoader.gd`) into `maps/zocalo.tscn`, where the real player walks it.

**Tech Stack:** Python 3 + Pillow + numpy (the plan, checks, drawing, greybox geometry; `tools/level/overlap.py`), Godot 4.5.1 GDScript (loader, map, tests, stills).

**Spec:** `docs/superpowers/specs/2026-10-10-zocalo-district-design.md` (steps 1 and 2 of section 5).

## Global Constraints

- Branch `eclipse-city`; commit per task; messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Axes are the pipeline's, as `tools/level/layouts/lay.py` uses: x east, y up, z south, in metres. North is -z. The plaza's middle is (0, 0). The sheets draw north up.
- Spec values:
  - map 500-700 m a side (about 620 × 640)
  - plaza 200 × 220 m, with a 20 m ring street
  - canal about 12 m wide, its water level -2 m, three bridges
  - cathedral and Sagrario about 110 × 120 m; Templo Mayor dig about 90 × 80 m
  - Plaza de Santo Domingo about 60 × 80 m, centred about 250 m north
  - National Palace 200 m frontage, 80 m deep
  - Madero 15 m wide; the arcade run about 30 bays (4.5 m each)
  - Line 2 hall about 60 × 30 m, floor -8 m; platforms floor -14 m; an entrance kiosk at each plaza corner
  - house blocks of 2 or 3 storeys
- Interiors are the pawnshop and its vault, the Inquisition's rooms, one palace courtyard, and a scribe's office under the evangelistas' arcade.
- Event field kinds are exactly `subsidence`, `water`, `seepage` and `use`.
- The repo is public; no in-game words (sheet labels are developer labels: element names only).
- Godot: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`; headless suites `perl -e 'alarm 280; exec @ARGV' $G --headless --fixed-fps 60 --path . res://tests/<suite>.tscn`.
- Never `rm` with an unguarded shell variable.

## Review Focus

1. **A route end that floats** (a plank 0.5 m above the roof it should rest on, or a stair foot off its floor). Expected: the check names the dangling end. Owner: Task 2, `test_route_end_must_rest_on_a_surface`.
2. **A concave plot or a non-rectangular sunken area** (the clipping and the greybox's hole-cutting assume convex plots and rectangular sunken areas). Expected: the check refuses it by name. Owner: Task 2, `test_concave_plot_refused` and `test_sunken_area_must_be_a_rectangle`.
3. **The player spawning inside a plot, over a hole or in the void.** Expected: they stand on street ground. Owner: Task 6, Z2.
4. **A walkable roof reachable only from another roof that is itself unreachable.** Expected: connectivity is measured from the street, not pairwise. Owner: Task 2, `test_roof_island_is_unreachable`.
5. **Frame rate across a 620 m map of colliders.** Expected: a report along a fixed route, average and worst, printed and given to the user. Owner: Task 7.

---

### Task 1: The Plan builder and the event fields

**Files:**
- Create: `tools/level/layouts/plan.py`
- Create: `tools/level/test_plan.py`
- Modify: `tools/level/level.sh` (`test)` list gains `python3 "$HERE/test_plan.py"`)

**Interfaces:**
- Produces, in `plan.py`:
  - `GROUND_KINDS = ("plaza", "street", "atrium", "courtyard", "market", "canal", "landing", "dig", "well")`, of which `SUNKEN_KINDS = ("canal", "landing", "dig", "well")` sit below the street.
  - `FRONTAGE_KINDS = ("plaza", "street", "atrium", "market", "canal", "landing", "courtyard")`.
  - `ROUTE_KINDS = ("roof_link", "climb", "stair", "bridge", "tunnel")`.
  - `EVENT_KINDS = ("subsidence", "water", "seepage", "use")`.
  - `rect(x0, z0, x1, z1) -> list[tuple]`, a CCW-from-above polygon.
  - `class Plan(name)` with:
    - `ground(name, kind, polygon, level=0.0)`
    - `plot(name, family, polygon, storeys, height, base=0.0, roof=True, interior=False)`
    - `route(name, kind, points)`, where points are `[(x, y, z), ...]` with at least 2 and the ends resting on surfaces
    - `space(name, polygon, floor, height, openings=())`, each opening `{"to": name or "street", "at": (x, z), "width": w}`
    - `landmark(name, kind, at, **props)`, at `(x, z)` or `(x, y, z)`
    - `tram(points)`, a closed loop of `(x, z)`
    - `event(kind, **shape)`, where a shape is `centre=(x, z), radius=r, strength=s` or `line=[(x, z), ...], reach=r, strength=s`
    - `brink(polygon)`
    - `data() -> dict`, JSON-serialisable, with keys `name, ground, plots, routes, spaces, landmarks, tram, events, brink`. Each element is a dict with its arguments under the same names; polygons are lists of `[x, z]`.
  - `field(data, kind, x, z) -> float` in 0..1: the max over that kind's shapes of `strength * smooth(1 - d / reach)`, where `d` is the distance to the centre or the polyline and `smooth` is smoothstep clamped to 0..1.
  - `centroid(polygon)`, `area(polygon)`, `top(plot) = base + height`.

- [ ] **Step 1: Write the failing tests** in `test_plan.py` (unittest, `sys.path` gains `layouts/`):
  - `test_elements_recorded`: one of each element recorded with its arguments.
  - `test_data_is_json`: `json.dumps(P.data())` works.
  - `test_rect_is_ccw_from_above`: the signed area of `rect(0, 0, 2, 1)` is positive, with x right and z down the page; state the convention in the docstring.
  - `test_field_radial`: `strength` at the centre, 0 at and past the radius, monotonic between.
  - `test_field_line`: 1 × strength on the line, 0 at reach.
  - `test_field_takes_the_strongest_shape`.
  - `test_unknown_kind_refused`: `ValueError` for a ground, route or event kind outside the tuples.
- [ ] **Step 2: Run to fail**: `python3 tools/level/test_plan.py` gives ImportError.
- [ ] **Step 3: Implement `plan.py`.**
- [ ] **Step 4: Run to pass.**
- [ ] **Step 5: Commit**: `feat(zocalo): the Plan builder and event fields`

---

### Task 2: The plan's checks

**Files:**
- Create: `tools/level/plan_check.py`
- Create: `tools/level/test_plan_check.py`
- Modify: `tools/level/level.sh` (test list)

**Interfaces:**
- Consumes: `plan.py` (Task 1).
- Produces:
  - `check(data) -> list[str]`, one problem a line, each naming the elements involved; empty means clean.
  - `walkable(data) -> list[dict]`, the surfaces: `{"name", "polygon", "y"}` for every ground area at its level, every plot roof with `roof=True` at `top`, and every space floor.
  - `reach(data) -> set[str]`, the names of the surfaces reachable from the street.

Rules (each its own problem line):
- **Plots:**
  - Must be convex (`"plot <n> is not convex"`).
  - Must not overlap one another by 0.5 m² or more (convex clipping, as `overlap._clipped`).
  - Must not overlap a ground area of a FRONTAGE kind by 0.5 m² or more.
  - Must have an edge within 0.5 m of a FRONTAGE ground area's edge (`"plot <n> faces no street"`).
- **Sunken ground areas** must be axis-aligned rectangles (`"sunken <n> is not a rectangle"`).
- **Route ends:** each lies inside a walkable surface's polygon (0.3 m slack at the edges) with |y - surface y| ≤ 0.6, or else `"route <n> end <i> dangles at (x, y, z)"`.
- **Connectivity, from the street:**
  - Surfaces at one y that share an edge or overlap are joined, and so are those a route links.
  - The street is the union of every `plaza` and `street` ground area at level 0.
  - Every walkable roof and every space must be reachable (`"<n> cannot be reached from the street"`).
- **Size:** the brink's bounding box is 500-700 m on each side, and every element lies inside the brink (`"<n> lies outside the brink"`).
- **Events:** each of the four kinds has at least one shape, and every shape's centre or line lies inside the brink.

- [ ] **Step 1: Write the failing tests** in `test_plan_check.py`. A small clean fixture plan `_town()` is built in the test: one 520 m brink, plaza, streets, two plots with roofs joined by a roof_link, a climb from the street, a well with a stair down to one space, and every event kind. Then:
  - `test_clean_town_passes` (`check == []`)
  - `test_overlapping_plots`
  - `test_plot_in_the_street`
  - `test_plot_faces_no_street`
  - `test_concave_plot_refused`
  - `test_sunken_area_must_be_a_rectangle`
  - `test_route_end_must_rest_on_a_surface` (a plank end 0.8 m above the roof)
  - `test_roof_island_is_unreachable` (two roofs linked only to each other)
  - `test_space_unreachable_without_its_stair`
  - `test_map_too_small` (a 400 m brink)
  - `test_outside_the_brink`
  - `test_missing_event_kind`

  Each asserts exactly one problem containing the element's name.
- [ ] **Step 2: Run to fail**: `python3 tools/level/test_plan_check.py`.
- [ ] **Step 3: Implement `plan_check.py`.**
- [ ] **Step 4: Run to pass.**
- [ ] **Step 5: Commit**: `feat(zocalo): the plan's checks: overlaps, frontage, routes, reach, size, events`

---

### Task 3: The plan sheets

**Files:**
- Create: `tools/level/plan_draw.py`
- Create: `tools/level/test_plan_draw.py`
- Modify: `tools/level/level.sh` (test list)

**Interfaces:**
- Consumes: `plan.py`, and `plan_check.walkable` for roofs.
- Produces:
  - `SHEETS = ("street", "roofs", "underground", "canal", "events", "all")`.
  - `draw(data, out_dir, px_per_m=2.0) -> list[Path]`, which writes `plan_<sheet>.png` for each sheet.
  - `to_px(x, z) -> (px, py)`: north up, a 40 px margin, the brink's bounds mapped.

Each sheet:
- a 10 m grid (a darker line every 100 m)
- a scale bar and a north arrow
- element names as developer labels at their centroids (Pillow's default font)

What each sheet shows:
- **street:** ground areas filled by kind, plots coloured by family, the tram loop, landmarks as dots.
- **roofs:** the street faded, walkable roofs filled by height, roof_link and climb routes drawn.
- **underground:** spaces filled by floor depth, stair and tunnel routes, wells.
- **canal:** canal, landings and bridges strong, the rest faded.
- **events:** the four fields as a colour mix (subsidence red, water blue, seepage green, use amber), sampled every 4 m, with the plots outlined.
- **all:** every layer.

- [ ] **Step 1: Write the failing tests** using Task 2's fixture (import `_town` from `test_plan_check`):
  - `test_six_sheets_written`
  - `test_sheet_size_matches_the_brink` (width = brink width × px_per_m + 80)
  - `test_plot_drawn_in_its_family_colour` (the street sheet's pixel at a plot's centroid equals `FAMILY_COLOURS[family]` within 8 per channel)
  - `test_events_sheet_reddens_at_subsidence_centre` (red there exceeds red 200 m away by 40)
  - `test_north_is_up` (a plot at z -100 draws above one at z +100)
- [ ] **Step 2: Run to fail.**
- [ ] **Step 3: Implement `plan_draw.py`** with `FAMILY_COLOURS` (a dict, one colour per family name used by the Zócalo; unknown families grey).
- [ ] **Step 4: Run to pass.**
- [ ] **Step 5: Commit**: `feat(zocalo): the plan sheets: street, roofs, underground, canal, events, all`

---

### Task 4: The Zócalo's plan

**Files:**
- Create: `tools/level/layouts/city_zocalo.py`. Not `zocalo.py`: a module beside the package `zocalo/` would be shadowed by it. This matches `city_harbour.py` with `harbour/`.
- Create: `tools/level/layouts/zocalo/__init__.py` and the parts `plaza.py`, `north.py` (cathedral, atrium, Templo Mayor dig, deco tower, Santo Domingo), `east.py` (palace), `west.py` (Portal de Mercaderes, Madero, Iturbide, Monte de Piedad), `south.py` (Portal de las Flores, canal, bridges, landings, market quarter), `station.py` (kiosks, wells, hall, platforms, tunnels, crypt, Templo Mayor shells), `houses.py` (the colonial blocks filling to the brink), `roofs.py` (roof links and climbs), `edges.py` (brink), `events.py` (the four fields), `cameras.py` (camera landmarks for stills and the frame-rate route). Each part has `lay(P)`.
- Create: `tools/level/test_zocalo_plan.py`
- Modify: `tools/level/level.sh`, adding a command `zocalo` that writes `assets/eclipse/zocalo/plan.json` and draws the sheets into `assets/eclipse/zocalo/plan/` (that folder gets a `.gdignore`), plus the test.

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces:
  - `city_zocalo.plan() -> dict` (`Plan("zocalo")` laid by every part in order: edges, plaza, north, east, west, south, station, houses, roofs, events, cameras).
  - `city_zocalo.layout() -> dict` (`lay.Layout("zocalo").data()`, empty until the families arrive).
  - Landmark kinds used: `metro_entrance` ×4, `spawn` ×1 (on the plaza's south ring street), `camera` (at least 8; each with props `look_at=(x, y, z)` and `y`), `door` (the interiors' ways in), `tram_stop`.
  - Plot families used: `house`, `arcade`, `cathedral`, `sagrario`, `palace`, `pawnshop`, `iturbide`, `inquisition`, `evangelistas`, `church`, `deco_tower`, `market_hall`, `stall`, `town_hall`.

- [ ] **Step 1: Write the failing tests** in `test_zocalo_plan.py`:
  - `test_the_plan_is_clean`: `plan_check.check(plan()) == []`, the failures printed.
  - `test_plaza_size`: the `plaza` ground is 200 × 220 within 1 m; a ring of `street` ground 20 m wide on all four sides; the tram loop is closed and every point of it lies on that ring street.
  - `test_canal`: the `canal` ground runs east-west, is 12 m ± 1 wide, at level -2, south of the plaza; exactly 3 `bridge` routes cross it.
  - `test_north`:
    - cathedral and sagrario together within 100-130 m wide;
    - a `dig` ground of 90 × 80 ± 5 north-east of the cathedral, with a `deco_tower` plot standing in it, its height ≥ 60;
    - a `plaza` ground named `santo_domingo`, 60 × 80 ± 5, its centre's z between -270 and -230;
    - an `inquisition` plot with a chamfered corner (a 5- or more-sided convex polygon) on its south-east.
  - `test_palace`: the `palace` plots east of the plaza span 200 ± 10 m north-south and 80 ± 5 m deep.
  - `test_west`:
    - an `arcade` run on the plaza's west side holding 28-32 bays' length (4.5 m each);
    - a `street` ground `madero` 15 ± 1 wide running west from the plaza's north-west corner;
    - `pawnshop` and `iturbide` plots.
  - `test_station`:
    - a space `station_hall` 60 × 30 ± 2 with floor -8;
    - platform spaces at floor -14;
    - 4 `metro_entrance` landmarks, one within 30 m of each plaza corner, each over a `well` with a `stair` route down to the hall;
    - `tunnel` routes station→crypt and crypt→`templo_shells`.
  - `test_interiors`: plots or spaces flagged `interior=True` (or spaces) named `pawnshop`, `pawn_vault`, `inquisition_rooms`, `palace_courtyard`, `scribe_office`.
  - `test_houses`: at least 40 `house` plots, every one with storeys 2 or 3.
  - `test_size`: the brink is 600-660 m east-west and 600-660 m north-south.
  - `test_events_shape_the_map`:
    - `field(data, "subsidence")` ≥ 0.6 at the cathedral's centroid and < 0.2 at the palace's;
    - `water` ≥ 0.6 on the canal;
    - `seepage` ≥ 0.6 at the station hall's centroid and at the palace's;
    - `use` ≥ 0.4 in the market.
  - `test_cameras`: at least 8 `camera` landmarks inside the brink.
- [ ] **Step 2: Run to fail.**
- [ ] **Step 3: Author the parts.** Positions follow the spec's section 3 map. Plot polygons are convex (chamfered corners allowed), and house blocks are split into convex lots of 15-30 m frontage. Every sunken area is a rectangle. Each roof link rests on its two roofs.
- [ ] **Step 4: Run to pass.** Then run `tools/level/level.sh zocalo` and look at every sheet. If a sheet shows a wrong arrangement, fix the part and rerun.
- [ ] **Step 5: Commit** (the layouts, the test, `level.sh`, `assets/eclipse/zocalo/plan.json`, the six sheets): `feat(zocalo): the Zócalo's plan: plaza, cathedral, palace, portales, canal, market, station, houses, events`. Send the six sheets to the user.

---

### Task 5: The greybox geometry

**Files:**
- Create: `tools/level/greybox.py`
- Create: `tools/level/test_greybox.py`
- Modify: `tools/level/level.sh` (`zocalo` also writes `assets/eclipse/zocalo/greybox.json`; the test list)

**Interfaces:**
- Consumes: plan data (Task 1); `overlap.fights` and `tools/eclipse/gate.layered` (via `sys.path`).
- Produces:
  - `build(data) -> dict`: `{"meshes": [{"name", "kind", "faces": [{"points": [[x, y, z], ...], "normal": [x, y, z]}]}]}`. Kinds are `ground`, `sunken`, `plot`, `space`, `route` and `brink`.
  - `faces(greybox) -> list[dict]`, every face in `overlap.py`'s shape (`owner`, `normal`, `points`).
  - `gate(greybox) -> list[str]`: `overlap.fights` and `gate.layered`, one line each.

Geometry:
- **ground:** the brink's rectangle at y 0 as rectangular cells, cut by every sunken rectangle's edges. No cell inside a sunken rectangle. The brink's outer edge falls 20 m as a cliff face into the void.
- **sunken:** a floor at its level and four walls up to 0, facing in.
- **plot:** walls outward from base to top, and a flat roof cap facing up. No bottom.
- **space:** floor up, ceiling down and walls in, each wall cut by a gap `width` wide (3 m) and 3 m high at each opening on it.
- **routes** (each end on its surface):
  - `stair`: a solid wedge 2.4 m wide, rising from its lower end to its upper.
  - `bridge`: a 4 m wide, 0.4 m thick slab.
  - `roof_link`: a 0.8 m wide, 0.15 m thick plank.
  - `climb`: a stack of 0.5 m steps 1.2 m wide against the wall.
  - `tunnel`: a 3 × 3 m corridor of inward faces between its two gaps.
- **Doubled faces:** where two plots meet, their shared walls face opposite ways (allowed). A plank's underside may touch nothing else.

- [ ] **Step 1: Write the failing tests** on Task 2's fixture town:
  - `test_gate_clean` (`gate(build(_town())) == []`)
  - `test_ground_has_a_hole_at_the_well` (no ground face contains the well's centre)
  - `test_sunken_floor_at_its_level`
  - `test_plot_is_closed_above` (one up-facing face at top over the footprint's area ± 1e-6)
  - `test_space_wall_has_its_gap` (no wall face covers the opening's point at floor + 1.5)
  - `test_stair_rises_from_floor_to_street` (its top face's lowest y equals the space floor and highest y 0, ± 0.01)
  - `test_brink_falls_away` (cliff faces reach y -20)
  - `test_overlap_caught` (two plots made to overlap give a gate line)
- [ ] **Step 2: Run to fail.**
- [ ] **Step 3: Implement `greybox.py`.**
- [ ] **Step 4: Run to pass**, then `level.sh zocalo`: the Zócalo's greybox writes, and its `gate()` is empty (the command fails otherwise).
- [ ] **Step 5: Commit**: `feat(zocalo): the greybox geometry from the plan, overlap-gated`

---

### Task 6: The greybox in Godot, walked

**Files:**
- Create: `scripts/Level/GreyboxLoader.gd` (`class_name GreyboxLoader extends Node3D`)
- Create: `maps/zocalo.gd`, `maps/zocalo.tscn`
- Create: `tests/zocalo_test.gd`, `tests/zocalo_test.tscn`

**Interfaces:**
- Consumes: `assets/eclipse/zocalo/greybox.json` and `plan.json` (Tasks 4-5).
- Produces:
  - `GreyboxLoader.build(greybox: Dictionary) -> GreyboxLoader`: one MeshInstance3D per kind (`StandardMaterial3D`, colour by kind and, for plots, `FAMILY_COLOURS` passed in from the plan's family list), and one StaticBody3D per mesh with a `ConcavePolygonShape3D` from the triangulated faces (fans).
  - `maps/zocalo.gd`:
    - `var plan: Dictionary`, `var greybox: GreyboxLoader`, `var player`
    - `set_day(day: bool)`, toggled with F11, with lights like the style lab's
    - the player spawned at the `spawn` landmark (y + 1.05)
    - `cameras() -> Array`, the camera landmarks
    - `--fps-report=<s>`: a camera flies through the cameras for s seconds; prints `fps: average <a> worst <w>`, then quits

- [ ] **Step 1: Write the failing checks** in `zocalo_test.gd`:
  - Z1: the greybox loads (meshes for every kind, a collider per mesh).
  - Z2: the spawn stands on street ground. A ray down from spawn + 3 m hits at y 0 ± 0.05, and that point is not inside any plot's footprint.
  - Z3: at the canal's centre a ray down hits y -2 ± 0.05; at the Templo Mayor dig's centre it hits its level.
  - Z4: at every space's centre, a ray from floor + 1 m hits the floor down and the ceiling up.
  - Z5: the real player walks down one entrance stair. They start at the well's top, press forward along the stair for up to 10 s, and end within the station hall's footprint at y -8 ± 0.5 without falling below it.
  - Z6: the real player walks across one roof link. They are placed on a house roof at the link's end and press forward along it, staying at roof height ± 0.5, and end on the other roof.
  - Z7: the real player walks down a stair from the street onto a canal landing.
- [ ] **Step 2: Run to fail**: `zocalo_test` fails to load the scene.
- [ ] **Step 3: Implement** the loader and the map.
- [ ] **Step 4: Run to pass.**
- [ ] **Step 5: Commit**: `feat(zocalo): the greybox in Godot: loaded, spawned, walked`

---

### Task 7: Stills and the frame-rate report

**Files:**
- Create: `tests/zocalo_stills.gd`, `tests/zocalo_stills.tscn` (windowed)

**Interfaces:**
- Consumes: `maps/zocalo.tscn` (Task 6).
- Produces stills `--out=<dir>`:
  - `top_day.png`: orthographic from above, the whole map.
  - `<camera>_day.png` and `<camera>_night.png` for every camera landmark.
  - `sheet_cameras.png`: a contact sheet of the day views.

- [ ] **Step 1: Write the still script** with the style lab stills as its pattern (`--out`, hide no labels: there are none). It quits after saving, and prints `still: <path>` per file.
- [ ] **Step 2: Run it**: `$G --path . --resolution 1920x1080 res://tests/zocalo_stills.tscn -- --out=<scratch>/zocalo`. Expected: one `still:` line per file, and the files exist.
- [ ] **Step 3: Run the frame-rate report**: `$G --path . --resolution 1920x1080 res://maps/zocalo.tscn -- --fps-report=30`. Expected: a `fps:` line; record it.
- [ ] **Step 4: Run every suite**:
  - `tools/level/level.sh test`
  - `zocalo_test`
  - the lab suites (`style_lab_test`, `painterly_pixels`), to make sure nothing shared broke

  All must be green.
- [ ] **Step 5: Commit** the stills script, then send the user the top-down still, the camera contact sheet and the frame-rate line: `feat(zocalo): greybox stills and frame-rate report`
