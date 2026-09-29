# The City on the Rock, Sub-project 1: The Harbour, Finished — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The harbour district of the city on the rock built to final art in Blender through `tools/level`, playable in Godot with its nine guards and five ways into the walled city, the rest of the city standing behind it as massing, meeting the performance target, as the look's benchmark for every later district.

**Architecture:** Extend the existing level pipeline (`tools/level`: kit as data, layouts as Python, markers, rules, export with the vertex bake) with new marker types and rules, a terrain generator whose meshes export with mesh colliders, and six new kit families (fortification, Iberian, harbour, ships, planting, massing). Two levels, `city_harbour` and `city_massing`, each its own `.blend`, load together into `maps/city.tscn`, whose gameplay nodes come from a new shared `scripts/Level/LevelGameplay.gd` (lifted from `maps/garrison.gd`, which is left untouched).

**Tech Stack:** Python 3 (pure-data kit, layouts, rules, terrain; `unittest`), Blender 5.2.2 headless (`bpy`, `bmesh`, glTF export), Godot 4.5.1 (GDScript; the headless test suites), Pillow + numpy (`tools/textures`).

**Spec:** `docs/superpowers/specs/2026-09-28-city-on-the-rock-design.md` (sections 6–12 are this sub-project's). Its level metrics and Blender-to-Godot contract come from `docs/superpowers/specs/2026-09-26-canal-quarter-mission-design.md` §5–6. References: `docs/superpowers/refs/{iberian,castles,scale,textures_harbour}.md`.

## Global Constraints

- Godot: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot` (4.5.1, Forward+). Blender: `/Applications/Blender.app/Contents/MacOS/Blender` (5.2.2).
- Axes: Godot's everywhere in data (x east, y up, z south), metres. Sea level is y 0; quay tops are y 2.5.
- Level metrics (canal spec §5): storey 3.0; doors 1.2 × 2.2; treads 0.3, risers 0.2; mantle ≤ 2.3; hang ≤ 3.9 with 2.05 × 1.0 clear under the lip; lips ≥ 0.15 deep; gaps walk ≤ 4.0, sprint ≤ 5.3, assisted ≤ 6.2, never ≥ 6.5 (6.2–6.5 uncertain); rungs on multiples of 0.3; navmesh agent radius 0.4 (the garrison's), cell 0.1.
- Budgets: a piece ≤ 800 triangles (`kit_shapes.PIECE_TRIS`) unless its recipe sets `budget`; a terrain object ≤ 24,000; a sector ≤ 120,000 at stage2 (`rules.BUDGET`).
- Look: PSX-inspired, not a copy — **no vertex snapping**; the dither, pixel grid and grading stay.
- textures.com photos and anything made from them are **never committed** (the repository is public): `textures/source/` and `textures/ps2/` stay gitignored, only recipes are committed, every slot has a flat-colour fallback. Our own paintings (`tools/textures/paint.py` → `textures/painted/`) are committed.
- No free VFX assets: sprays, splashes and particles are drawn or baked by us; the web is reference only.
- Sounds only from the user's packs or packs they approved (`tools/prepare_sfx.py`, `~/Downloads/AUCOD Web SFX`); any new download is shown to the user first.
- Work in the worktree `.claude/worktrees/city-harbour` on branch `city-harbour`; other sessions commit to main. `maps/garrison.gd` and its level are not modified; the garrison must still build, check, export and pass `tests/level_test.tscn`.
- Godot suites: `perl -e 'alarm 900; exec @ARGV' $GODOT --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/<suite>.tscn`; gate every new script with `$GODOT --headless --path . --check-only --script <file>`; a run passes only with no `SCRIPT ERROR` in its output; suites set `TemperamentScript.rolling = false`.
- Every look is judged at full size, from several angles, in-game, before it is called done.

## Review Focus

1. **A level the user has edited in Blender** (a piece moved, the terrain sculpted): `level.sh build` refuses to overwrite it without `--force`, and `export` ships the edit — the terrain's collider follows the sculpted mesh, not the generator. Pinned in Task 4 (`test_guard.sh`: a terrain vertex moved) and Task 5 (K7: the collider matches the exported mesh).
2. **A fresh clone without the photos**: every new slot draws in its flat colour and nothing errors or warns. Pinned in Task 6 (K10: `Materials.folder` pointed at an empty folder).
3. **Two levels in one scene**: the harbour and the massing both have sectors, colliders and markers; nothing collides or is shared by accident (node names, zones, occluders). Pinned in Task 5 (K8: the fixture loaded twice under one parent).
4. **A swimmer beyond the navmesh**: a guard chasing the player into the open bay stops at the navmesh's edge and falls back to searching; he never loops or stands in the water forever. Pinned in Task 15 (C13).
5. **A marker buried by the terrain** (the ground sculpted up over a guard's post or a waypoint): the check names it. Pinned in Task 4 (`test_a_marker_under_the_terrain`).

---

## The harbour at a glance (the layout's anchors)

Every task that places or tests something uses these. The layout (Task 13) is their source of truth once written.

| What | Where (x, y, z) | Notes |
|---|---|---|
| The sea | y 0; the water box x −260…300, z −10…420, y −12…0 | One `water` marker, murk 0.5 |
| Quay line | z 0 from x −178 to 150 | Tops y 2.5; faces down to y −3 |
| The Ribeira | x −178…−100 | Quay z 0…−6; granite arcade z −6…−10 (13 bays of 6 m); houses z −10…−20 over and behind it; the city wall's face z −22, 10 m high (walk y 12.5) |
| The Guindais stair | x −186…−183, from (−184.5, 2.5, −8) to (−184.5, 30.5, −80) | Flights of 10 risers, 3 m landings; ends at the upper gate (locked; sub-project 2) |
| West wall | face x −180, z −22…−120 | Climbs the slope beside the stair |
| The Terreiro | x −100…−10, z −72…0, floor y 2.5 | Arcades W (x −100…−92), N (z −72…−64), E (x −18…−10): 6 m bays, 8 m deep, two storeys, ridge y 17; the water stair (Cais das Colunas) x −65…−45 at z 0 down to y 0; the king's statue at (−55, 2.5, −34); six lamp posts |
| The Sea Gate | (−55, 2.5, −72) | Drum towers at x −62 and −48 (8 m across, top y 22.5); passage 4 × 5 m through z −72…−88; portcullis at z −72.5; the wall behind the Terreiro 12 m high (walk y 14.5) |
| Customs house | x −10…14, z −60…−6 | Ground 4 m + upper 3.5 m + roof; the harbourmaster's office upstairs (north-east room) |
| Shipyard sea wall | face z −6, x −10…150 | 12 m high (walk y 14.5); the Nasrid water gate centred x 68.6 (7 m horseshoe) |
| Royal shipyard | x 14…114.8 (12 naves of 8.4 m), z −66…−6 | Piers 1.2 m square; pointed arches spring y 8, apex y 10.9; the vault terrace y 13 (walkable, stairs up to the walk); the slip nave is nave 6 (x 64.4…72.8), its basin z −26…−6; the galley on the stocks in nave 3 (x 39.2…47.6) |
| Rope yard | x 114.8…150, z −40…−6 | Open, inside the walls; cranes; the east wall's face x 150 |
| The mole | root (165, 3.5, 0) → (165, 3.5, 140) → head (95, 3.5, 200) | 14 m wide, top y 3.5, seaward parapet to y 5.5, boulders at its seaward foot |
| Golden tower | centre (90, 3.5, 205) | Twelve-sided: ⌀15 m to y 21.5 (terrace, the lookout and bell), ⌀9 m to y 30.5, ⌀4.5 m lantern to y 36, dome to y 40; the windlass inside at ground |
| The fort | tower centre (−75, 4, 205) | Bastion 30 × 24 m at y 4; tower 12 × 12 m to y 34; four domed turrets; embrasures at y 1.5 |
| West spit | from (−215, 0, 10) to (−85, 0, 195) | Rock, crest y 2–5 |
| The river | x −195…−235 at its mouth, north to z −150 | Its banks rise to y 40 by z −150 (massing beyond) |
| The chain | from (82, 0.3, 205) to (−60, 0.3, 205) | On floats every 12 m |
| Carrack | hull centre (40, 0, 8), bow to +x | Mainmast at x 40; the fighting top at y 20; the mainyard under it at y 18 (its footing's top y 18.25, its furled sail clear of the merlons at y 16.3), braced so its north arm reaches over the sea wall's parapet (z −6) to z −9: a 3.75 m drop to the walk, under the player's safe fall (4.46 m) |
| Caravel | (−120, 0, 10), bow to −x | At the Ribeira quay |
| Smugglers' cave | mouth (225, 0, 60) facing south-east; beach (230, 0.6, 15); blowhole top (232, 26, 0) | In the east cliff, which runs from (175, 0, 0) round to (260, 0, 90), top y 20–28; its tunnel north sealed (sub-project 2) |
| Start | in a rowboat at (178, 0, 120), by the mole's seaward boulders | |

**The five ways into the walled city (sub-project 1):** the Sea Gate; the carrack's mainyard onto the shipyard's sea wall; the Ribeira's balconies and roofs onto the wall-walk; the Nasrid water gate into the slip nave; the customs house from the Terreiro (its door locked; the key on the watchman's desk) through to the shipyard. The river mouth, the smugglers' cave's tunnel and the Guindais stair's upper gate lead to districts not built yet: each ends at an `exit` marker with its label.

**The nine guards:** two at the Sea Gate (posts); a lantern pair on the quays (one route, the second a half-round behind); the customs watchman (a route through the ground floor and the office); the carrack's deck watch; the lookout archer on the golden tower's terrace (a bell beside him); a patrol along the mole; a brute in the shipyard, round the galley.

**Sectors:** `city_harbour` has `sea`, `mole`, `fort`, `terreiro`, `ribeira`, `shipyard`, `ships`, `cave`, `river`. `city_massing` has `rock`, `old_town`, `cathedral`, `palace`, `aqueduct`, `gorge`, `castle`. Massing positions (spec §5.1 heights): the old town x −170…150, z −30…−250, y 5…45; the cathedral at (−20, 45, −200), its bell tower at (20, 45, −190) to y 140; the palace at (150, 75, −230), its mirador to y 100; the aqueduct from (200, 80, −600) to (150, 80, −260), its valley floor y 40; the gorge x −250…−300, z 0…−500, floor y 5, rims y 95–100; the Great Bridge at z −380, deck y 100; the castle at (−200, 100, −480), curtain walk y 115, keep top y 155.

---

## File Structure

**Pipeline (`tools/level/`)**
- `markers.py` — modify: the new marker types, their enums, the unknown-property check.
- `rules.py` — modify: route checks by move, headroom along guard routes, locked doors and keys, terrain as floor.
- `terrain.py` — create: the terrain generator (pure Python): height grids, cliff strips, tunnels, strata tints.
- `geo.py` — modify: `TriGrid` (triangles bucketed on a grid, ray casts down and up).
- `common.py` — modify: `material(slot)` moved here from `kit.py`; `content_hash` covers the terrain.
- `kit.py` — modify: uses `common.material`.
- `build.py`, `read.py`, `export.py` — modify: terrain objects built, read back, baked, exported and listed in the manifest.
- `kit_shapes.py` — modify: horseshoe arch heads.
- `kit_fort.py`, `kit_iberian.py`, `kit_harbour.py`, `kit_ships.py`, `kit_planting.py`, `kit_massing.py` — create: the six kit families (each imported at the end of `kit_recipes.py`, as `kit_houses` is).
- `kit_recipes.py` — modify: `WALLS` gains `granite` and `render`; imports the new families.
- `layouts/lay.py` — modify: `mark()` takes pitch and roll; `terrain()`; `ship()` emits a ship's climb markers.
- `layouts/fixture.py` — modify: a terrain slope and one of each new marker.
- `layouts/city_harbour.py` and `layouts/harbour/*.py` — create: the harbour, split by sector.
- `layouts/city_massing.py` — create: the rest of the city as silhouettes.
- `test_rules.py`, `test_kit_shapes.py`, `test_guard.sh`, `level.sh` — modify; `test_terrain.py`, `test_kits.py` — create.

**Textures (`tools/textures/`)**
- `ps2ify.py` — modify: `mask`, `seams` and `multiply` recipe keys.
- `recipes/*.json` — create one per new photo slot.
- `paint.py` — modify: the ironwork, ratlines, the coil mask and Mediterranean foliage paintings.

**Godot**
- `scripts/Level/LevelLoader.gd` — modify: terrain colliders and occluders, a root named after its level.
- `scripts/Level/LevelGameplay.gd` — create: the game's nodes from a level's markers.
- `scripts/StimuliSystem/SoundBus.gd` — modify: noise zones (local masking).
- `scripts/Visual/Materials.gd` — modify: the new slots; `tile` as [u, v]; `offset`.
- `scripts/Night/Night.gd`, `scripts/Night/NightSky.gd` — modify: a per-map skyline.
- `scripts/Visual/Blowhole.gd` — create: the cave's roar and spray (our own particles).
- `maps/city.gd`, `maps/city.tscn` — create: the mission's map.
- `tests/level_test.gd` — modify: K6–K12 on the fixture.
- `tests/city_test.gd`/`.tscn` — create: the city suite. `tests/city_stills.gd`/`.tscn` — create: the look stills.
- `tools/skyline/skyline.py`, `skyline.sh` — modify: a `city` scene.

---

### Task 1: New markers and the unknown-property check

**Files:**
- Modify: `tools/level/markers.py`, `tools/level/layouts/lay.py`
- Test: `tools/level/test_rules.py`

**Interfaces:**
- Produces: `markers.SCHEMA` entries below; enums `TOOL_KINDS`, `PROP_KINDS`, `MOVES`, `PROBE_EXPECT`, `ROUNDS_LIGHTS`, `MECHANISMS`; `markers.problems(marker)` also names unknown properties; `Layout.mark(name, ucd, at, yaw=0.0, sector=..., size=None, pitch=0.0, roll=0.0, **props)`.

- [ ] **Step 0: Set up the worktree** (superpowers:using-git-worktrees): branch `city-harbour` from main at `.claude/worktrees/city-harbour`. Copy in the spec to `docs/superpowers/specs/2026-09-28-city-on-the-rock-design.md`, this plan to `docs/superpowers/plans/2026-09-29-city-harbour.md`, and the four references to `docs/superpowers/refs/`. Copy `textures/ps2/` from the main checkout (gitignored). Run `python3 tools/textures/ps2ify.py import` (the new `TCom_*` files into `textures/source/`). Check that `tools/level/level.sh test` passes on the untouched branch. Commit the docs.

- [ ] **Step 1: Write the failing tests** in `test_rules.py`:

```python
def test_the_new_markers_pass_when_right(self):
    data = good()
    data["markers"] += [
        marker("purse", "loot", (0.5, 0, 0.5), {"value": 25}),
        marker("seal", "loot", (1.0, 0, 0.5), {"value": 0, "special": True, "kind": "seal", "label": "the harbourmaster's seal"}),
        marker("office_key", "key", (1.5, 0, 0.5), {"key_id": "office"}),
        marker("office_door", "door", (0, 0, -2.2), {"locked": True, "key": "office"}),
        marker("flask", "tool", (2.0, 0, 0.5), {"tool": "flask", "count": 2}),
        marker("crate_1", "prop", (2.5, 0, 0.5), {"kind": "crate"}),
        marker("rope_1", "rope", (3.0, 4, 0.5), {"length": 4.0}),
        marker("roar", "noise_zone", (0, 1, 0), {"db": 30.0}, size=[4, 3, 4]),
        marker("gate_up", "portcullis", (0, 0, -2), {"state": "up"}),
        marker("to_old_town", "exit", (0, 1, 1), {"label": "the old town"}, size=[2, 2, 2]),
        marker("see_moon", "probe", (1, 1, 1), {"expect": "moon"}),
    ]
    self.assertEqual(rules.problems(data), [])

def test_an_unknown_property(self):
    data = good()
    data["markers"][0]["props"]["colour"] = "red"
    self.assertTrue(any("no property 'colour'" in p for p in rules.problems(data)))

def test_bad_enums(self):
    for ucd, props, word in (("tool", {"tool": "grenade"}, "tool"), ("prop", {"kind": "piano"}, "prop kind"),
                             ("probe", {"expect": "sun"}, "expect"), ("guard", {"archetype": "watchman", "light": "flare"}, "light")):
        data = good()
        data["markers"].append(marker("odd", ucd, (0.5, 0, 0.5), props))
        self.assertTrue(any(word in p for p in rules.problems(data)), ucd)
```

- [ ] **Step 2: Run** `python3 tools/level/test_rules.py`. Expected: the three new tests FAIL (unknown marker kinds; no property check).

- [ ] **Step 3: Implement.** In `markers.py` add to `SCHEMA` (required / optional with defaults / box):
  - `loot`: [`value`] / `label` "goblet", `kind` "", `special` False / no.
  - `key`: [`key_id`] / `label` "key" / no.
  - `tool`: [`tool`] / `count` 1, `label` "" / no. `TOOL_KINDS = ["flask", "flash_bomb", "lockpick", "arrows"]`.
  - `chest`: [] / `locked` False, `key` "", `pick` True, `label` "chest", `large` False / no.
  - `prop`: [`kind`] / `mass` 0.0 / no. `PROP_KINDS = ["crate", "crate_small"]`.
  - `rope`: [`length`] / `chain` False / no.
  - `lever`, `wheel`, `portcullis`, `sluice`, `hoist`, `slider` (`MECHANISMS`): [] / `target` "", `state` "", `label` "", `hold` False, `width` 4.0, `height` 5.0 / no.
  - `objective`: [`label`] / `kind` "steal" / no. `exit`: [`label`] / — / box. `secret`: [] / `label` "" / box.
  - `noise_zone`: [`db`] / `period` 0.0, `label` "" / box.
  - `probe`: [`expect`] / — / no. `PROBE_EXPECT = ["moon", "shadow", "lamp"]`.
  - `route_check`: [`route`, `order`, `move`] / — / no. `MOVES = ["walk", "stairs", "mantle", "hang", "jump", "sprint_jump", "assist_jump", "drop", "climb", "rope", "swim", "balance"]`.
  - `DECAL_KINDS` gains `salt` (our painting, Task 6).
  - `guard` gains the optional `light` "" (`ROUNDS_LIGHTS = ["", "lantern", "torch"]`, the Guard's `rounds_light`). `door` gains `pick` True.
  - In `problems()`: any key in `props` outside `required` + `optional` → `"%s (%s): no property '%s'"`; enum checks for `tool`, `prop` (word "prop kind"), `probe` (word "expect"), `route_check` (`move`), guard `light`. `write_json` also writes the new enums.
  - In `lay.py`: `mark()` takes `pitch` and `roll` into `geo.rotation(yaw, pitch, roll)`.

- [ ] **Step 4: Run** `python3 tools/level/test_rules.py`. Expected: all pass. Then `tools/level/level.sh check garrison` in the worktree (build it first if the `.blend` is not there: `level.sh build garrison`): 0 problems — the garrison carries no property outside its schema (add any it does carry to `optional`, never delete it from the garrison).

- [ ] **Step 5: Commit** `feat(level): the city's markers (loot, keys, tools, mechanisms, exits, probes, route checks) and no unknown property`.

---

### Task 2: Route checks, headroom and keys

**Files:**
- Modify: `tools/level/rules.py`
- Test: `tools/level/test_rules.py`

**Interfaces:**
- Consumes: Task 1's `route_check` marker and `MOVES`.
- Produces: `rules.GAPS = {"jump": 4.0, "sprint_jump": 5.3, "assist_jump": 6.2}`, `rules.NEVER = 6.5`, `rules.MANTLE = 2.3`, `rules.HANG = 3.9`, `rules.HANG_CLEAR = (2.05, 1.0)`, `rules.LIP = 0.15`, `rules.HEADROOM = 1.95`, `rules.SAFE_DROP = 17.0 ** 2 / (2 * 24.0 * 1.35)` (4.46 m: the player's `fall_damage_speed`, `gravity` and `fall_gravity_multiplier` in `scripts/PlayerController.gd`, quoted in a comment); `rules.move_problems(data, boxes, ground)`, `rules.headroom_problems(data, boxes, ground)`, `rules.key_problems(data)`, all called from `problems()`. `ground` is the terrain's `geo.TriGrid` or None (Task 4 passes it).

- [ ] **Step 1: Write the failing tests.** Build a small ledge fixture in the test (floor tiles and a wall box):

```python
def test_a_jump_names_its_class(self):
    # two floors 4.6 m apart edge to edge, same height
    data = gap_level(4.6)
    data["markers"] += checks("leap", [((0, 0, 0), "walk"), ((6.6, 0, 0), "jump")])
    self.assertTrue(any("sprint" in p for p in rules.problems(data)))   # 4.6 > 4.0: needs a sprint
    data["markers"][-1]["props"]["move"] = "sprint_jump"
    self.assertEqual(rules.problems(data), [])

def test_the_uncertain_and_never_gaps(self):
    for gap, word in ((6.3, "uncertain"), (6.6, "never")):
        data = gap_level(gap)
        data["markers"] += checks("leap", [((0, 0, 0), "walk"), ((gap + 2.0, 0, 0), "assist_jump")])
        self.assertTrue(any(word in p for p in rules.problems(data)), gap)

def test_a_hang_needs_room_under_its_lip(self):
    data = ledge_level(top=3.6)                        # a wall 3.6 high, 0.4 deep on top
    data["markers"] += checks("up", [((0, 0, 1.0), "walk"), ((0, 3.6, -0.2), "hang")])
    self.assertEqual(rules.problems(data), [])
    data["pieces"].append(piece("crate_in_the_way", "crate_stack", (0, 0, 0.6)))   # something under the lip
    self.assertTrue(any("room under" in p for p in rules.problems(data)))

def test_a_mantle_too_high(self):
    data = ledge_level(top=2.6)
    data["markers"] += checks("up", [((0, 0, 1.0), "walk"), ((0, 2.6, -0.2), "mantle")])
    self.assertTrue(any("mantle" in p and "2.6" in p for p in rules.problems(data)))

def test_a_guard_route_under_a_low_beam(self):
    data = good()
    data["pieces"].append(piece("beam", "beam_low", (2.5, 0, 0.5)))  # a box 1.6 m over the floor across the route
    self.assertTrue(any("headroom" in p for p in rules.problems(data)))

def test_a_locked_door_needs_its_key_or_a_pick(self):
    data = good()
    data["markers"].append(marker("office_door", "door", (0, 0, -2.2), {"locked": True, "key": "office", "pick": False}))
    self.assertTrue(any("no key 'office'" in p for p in rules.problems(data)))
    data["markers"].append(marker("office_key", "key", (0.5, 0, 0.5), {"key_id": "office"}))
    self.assertEqual(rules.problems(data), [])

def test_a_key_to_nothing(self):
    data = good()
    data["markers"].append(marker("stray", "key", (0.5, 0, 0.5), {"key_id": "nowhere"}))
    self.assertTrue(any("opens nothing" in p for p in rules.problems(data)))
```

  `gap_level`, `ledge_level` and `checks(route, [(at, move), ...])` are test helpers (a route_check per point, order from 1). `beam_low` and `crate_stack` are test-only recipes added to `kit_recipes.PIECES` inside the test module (removed in `tearDown`).

- [ ] **Step 2: Run** `python3 tools/level/test_rules.py`. Expected: the seven new tests FAIL.

- [ ] **Step 3: Implement** in `rules.py`. For each route (route_checks grouped by `route`, sorted by `order`), each consecutive pair a → b is judged by b's move:
  - `jump`/`sprint_jump`/`assist_jump`: the gap is the horizontal distance between the floors' edges along a→b (walk from a toward b until the floor under drops away; walk back from b likewise); over the move's limit names the class it needs ("needs a sprint", "needs an assisted jump"); 6.2 < gap < 6.5 → "uncertain"; ≥ 6.5 → "never". Rise over 0.6 → "lands too high".
  - `mantle`: rise ≤ `MANTLE`, a floor under b, the top ≥ `LIP` deep along a→b.
  - `hang`: rise ≤ `HANG`; the box `HANG_CLEAR` tall × wide, 0.4 deep, hanging under the lip on a's side, free of colliders ("no room under its lip"); lip ≥ `LIP`.
  - `drop`: fall ≤ `SAFE_DROP`.
  - `walk`/`stairs`/`balance`: a floor within 0.45 m under every 0.5 m along a→b.
  - `climb`/`rope`: a `ladder` or `rope` marker's box contains a→b's midpoint (a rope's box: 0.6 m round its line, its `length` down).
  - `swim`: a `water` marker's box contains a and b.
  - Headroom: along every guard route (waypoints in order, the last back to the first), every 0.5 m: nothing solid from 0.1 to `HEADROOM` over the floor (doorway markers' openings excepted), else `"%s: no headroom at (x, z) (%.2f m)"`.
  - Keys: a locked door or chest with `pick` False needs a `key` marker of its `key` (`"no key '%s'"`); a key whose id no door or chest names → `"opens nothing"`.
  Floors and rays come from the boxes and, when given, the terrain `TriGrid` (Task 4).

- [ ] **Step 4: Run** `python3 tools/level/test_rules.py`: all pass; `level.sh check garrison`: still 0 problems.

- [ ] **Step 5: Commit** `feat(level): route checks by move (gap classes, mantle, hang room), headroom on guard routes, keys for locked doors`.

---

### Task 3: The terrain generator

**Files:**
- Create: `tools/level/terrain.py`, `tools/level/test_terrain.py`
- Modify: `tools/level/geo.py`

**Interfaces:**
- Produces:
  - `terrain.TERRAIN_TRIS = 24000`.
  - `terrain.grid(name, sector, x0, z0, x1, z1, cell, height, slot, surface="stone", tint=None, keep=None, skirt=0.0, occluder=False) -> dict` — `height(x, z) -> y`; `slot(x, y, z, slope_deg) -> str`; `tint(x, y, z) -> [r, g, b]` (default `strata`); `keep(ys) -> bool` per quad (drop quads wholly under the sea bed, say); `skirt` m hung down round the edge.
  - `terrain.cliff(name, sector, path, base, top, band=6.0, jitter=0.6, seed=0, slot="cliff", surface="stone", step=4.0, lean=0.15) -> dict` — `path` [(x, z)], the face looking to the path's left; rows of quads per strata band, each band stepped in or out by up to `jitter` (seeded), leaning back `lean` m per band.
  - `terrain.tunnel(name, sector, path, radii, floor, sides=10, seed=0, slot="rock", surface="stone") -> dict` — `path` [(x, y, z)], `radii` [(rx, ry)] per point; faces look inward; vertices below `floor` are flattened onto it.
  - `terrain.strata(x, y, z, band=6.0, depth=0.12, wet=(0.0, 1.5)) -> [r, g, b]` — alternating band values ±`depth`, darker and greener in the wet band.
  - Each returns `{"name", "sector", "surface", "occluder", "verts": [[x,y,z]], "faces": [[i,j,k]], "slots": [str per face], "tints": [[r,g,b] per vertex]}` (triangles, wound outward, counter-clockwise seen from outside).
  - `terrain.triangles(t) -> [[a, b, c]]`, `terrain.height_at(t, x, z) -> float | None`.
  - `geo.TriGrid(triangles, cell=4.0)` with `.down(point, reach) -> float | None` (the distance to the first triangle below) and `.up(point, reach) -> float | None`.

- [ ] **Step 1: Write the failing tests** (`test_terrain.py`, `unittest`):

```python
def test_a_grid_follows_its_height(self):
    t = terrain.grid("slope", "yard", 0, 0, 20, 20, 2.0, lambda x, z: 0.1 * x, lambda *a: "grass")
    self.assertAlmostEqual(terrain.height_at(t, 10.0, 7.0), 1.0, places=3)
    self.assertEqual(len(t["faces"]), 10 * 10 * 2)

def test_faces_wind_outward(self):
    t = terrain.grid("flat", "yard", 0, 0, 4, 4, 2.0, lambda x, z: 0.0, lambda *a: "grass")
    self.assertTrue(all(face_normal(t, f)[1] > 0.99 for f in t["faces"]))
    c = terrain.cliff("face", "yard", [(0, 0), (20, 0)], 0.0, 18.0)
    self.assertTrue(all(face_normal(c, f)[2] < -0.5 for f in c["faces"]))   # looks left of +x: toward -z

def test_slopes_choose_slots(self):
    t = terrain.grid("hill", "yard", 0, 0, 20, 20, 2.0, lambda x, z: 0.0 if x < 10 else (x - 10) * 2.0,
                     lambda x, y, z, s: "cliff" if s > 50 else "grass")
    self.assertIn("cliff", t["slots"]); self.assertIn("grass", t["slots"])

def test_keep_and_skirt(self):
    t = terrain.grid("bed", "sea", 0, 0, 40, 40, 4.0, lambda x, z: -8.0 if x > 20 else 1.0, lambda *a: "sand",
                     keep=lambda ys: max(ys) > -2.0, skirt=1.5)
    self.assertTrue(all(max(t["verts"][i][0] for i in f) <= 24.0 for f in t["faces"] if min(t["verts"][i][1] for i in f) > -1.0))
    self.assertTrue(any(v[1] < -0.5 for v in t["verts"]))                   # the skirt hangs down

def test_a_tunnel_faces_in_and_has_a_floor(self):
    t = terrain.tunnel("cave", "cave", [(0, 2, 0), (0, 2, -20)], [(4, 3), (3, 2.5)], floor=0.5)
    self.assertAlmostEqual(min(v[1] for v in t["verts"]), 0.5, places=3)
    self.assertIsNotNone(geo.TriGrid(terrain.triangles(t)).down([0, 1.5, -10], 3.0))
    self.assertIsNotNone(geo.TriGrid(terrain.triangles(t)).up([0, 1.5, -10], 5.0))

def test_strata_bands_and_the_wet_foot(self):
    self.assertNotEqual(terrain.strata(0, 3, 0), terrain.strata(0, 9, 0))
    self.assertLess(sum(terrain.strata(0, 0.5, 0)), sum(terrain.strata(0, 3, 0)))

def test_the_budget(self):
    with self.assertRaises(ValueError):
        terrain.grid("huge", "yard", 0, 0, 400, 400, 2.0, lambda x, z: 0.0, lambda *a: "grass")
```

  `face_normal(t, face)` is a test helper.

- [ ] **Step 2: Run** `python3 tools/level/test_terrain.py`. Expected: FAIL (no module).

- [ ] **Step 3: Implement** `terrain.py` and `geo.TriGrid` (Möller–Trumbore against the triangles in the xz cells a vertical ray passes; triangles bucketed by their xz bounds). Names must match `^[a-z0-9_]+$` (Godot keeps them as node names; `ValueError` otherwise). Over `TERRAIN_TRIS` → `ValueError` naming the count.

- [ ] **Step 4: Run** `python3 tools/level/test_terrain.py`: all pass.

- [ ] **Step 5: Commit** `feat(level): a terrain generator (grids, cliff strips, tunnels, strata) and triangle rays`.

---

### Task 4: Terrain through the pipeline

**Files:**
- Modify: `tools/level/common.py`, `kit.py`, `build.py`, `read.py`, `rules.py`, `export.py`, `edited.py` (only if needed), `layouts/lay.py`, `layouts/fixture.py`, `level.sh`, `test_guard.sh`
- Test: `tools/level/test_rules.py`, `tools/level/test_guard.sh`

**Interfaces:**
- Consumes: Task 3's terrain dicts and `geo.TriGrid`.
- Produces:
  - A level's data may carry `"terrain": [terrain dicts]` (from the layout) and reads back as `"terrain": [{"name", "sector", "surface", "occluder", "tris": [[a, b, c]] in Godot axes}]`.
  - `Layout.terrain(t)` appends a terrain dict; `Layout.data()` includes it.
  - In the `.blend`: a mesh object per terrain named `t["name"]`, custom props `terrain` = 1, `surface`, `occluder`; a colour attribute `Tint`; a material per slot (`common.material`).
  - `common.material(slot)` (moved from `kit.py`); `common.content_hash(data)` includes each terrain's rounded vertices.
  - `rules.problems(data)` treats terrain triangles as floor (standing markers, route checks, headroom) and names a standing marker with terrain within 1.7 m over it as `"its body is under the ground"`.
  - The manifest gains `"terrain": [{"name", "sector", "surface", "occluder"}]`; each terrain is in its sector's glb, its colour `Tint × shade` (`shade.colour` with occlusion against the whole level).
  - `level.sh test` also runs `test_terrain.py`.

- [ ] **Step 1: Write the failing tests.** In `test_rules.py`:

```python
def test_a_marker_on_the_terrain(self):
    data = good()
    data["terrain"] = [flat_terrain("ground", y=0.0, x0=6, x1=14)]
    data["markers"].append(marker("on_ground", "hide", (10, 0.0, 0)))
    self.assertEqual(rules.problems(data), [])

def test_a_marker_under_the_terrain(self):
    data = good()
    data["terrain"] = [flat_terrain("mound", y=1.2, x0=6, x1=14)]
    data["markers"].append(marker("buried", "hide", (10, 0.0, 0)))
    self.assertTrue(any("under the ground" in p for p in rules.problems(data)))
```

  `flat_terrain` returns the read-back form (`tris`). In `test_guard.sh` add a fifth check: after the forced build, move one terrain vertex of the fixture in Blender and save → `level.sh build fixture` is refused.

- [ ] **Step 2: Run** `python3 tools/level/test_rules.py` and `tools/level/test_guard.sh`. Expected: the new checks FAIL.

- [ ] **Step 3: Implement** as the Interfaces say. `fixture.py` gains a terrain slope (`terrain.grid("bank", "yard", 6, -6, 14, 6, 1.0, lambda x, z: (x - 6) * 0.25, ...)`, surface "gravel") beside its yard. In `export.bake`, terrain objects join the occlusion tree and are baked (not subdivided, not ungripped: layouts keep floors off terrain faces); their final colour multiplies `Tint`.

- [ ] **Step 4: Run** `tools/level/level.sh test` (rules, terrain, guard): all pass. `level.sh build fixture && level.sh export fixture`: exported with its terrain in `yard.glb` and the manifest's `terrain` list. `level.sh check garrison`: 0 problems.

- [ ] **Step 5: Commit** `feat(level): terrain built, read back, checked as floor, baked and exported`.

---

### Task 5: Terrain colliders, two levels in one scene, noise zones (Godot)

**Files:**
- Modify: `scripts/Level/LevelLoader.gd`, `scripts/StimuliSystem/SoundBus.gd`
- Test: `tests/level_test.gd`

**Interfaces:**
- Consumes: the manifest's `terrain` list (Task 4).
- Produces:
  - `LevelLoader.load_level(parent: Node3D, folder: String, root_name := "Level") -> Level`; the terrain: a `StaticBody3D` named `terrain_<name>` under its sector, collision layer 1, meta `surface`, one `CollisionShape3D` with the mesh's `create_trimesh_shape()`; `occluder` terrain gets an `OccluderInstance3D` with an `ArrayOccluder3D` of its mesh.
  - `SoundBus.add_zone(box: AABB, db: float) -> int`, `SoundBus.remove_zone(id: int)`, `SoundBus.clear_zones()`, `SoundBus.masking_at(position: Vector3) -> float` (the greater of `masking_db` and every zone containing `position`); `emit_sound`/`emit_message` use `masking_at(position)`.

- [ ] **Step 1: Write the failing checks** in `tests/level_test.gd` (on the fixture, before the garrison):
  - `K6 the fixture's bank is solid terrain: a ray down onto it hits gravel at its height` — ray at (10, 5, 0) down; `_surface(hit) == "gravel"`, hit y ≈ 1.0 (± 0.05).
  - `K7 the terrain's collider is its drawn mesh` — the body's shape faces equal the `terrain_bank` mesh's triangle count, and its AABB matches the mesh's.
  - `K8 two levels load side by side under their own roots` — `load_level(self, fixture, "fixture_a")` and `"fixture_b"`: two roots named so, each with its own sectors and colliders, `level_b.of("guard").size() == 1`.
  - `K9 a noise zone masks what is made inside it` — `SoundBus.add_zone(AABB(...), 40.0)`: a 50 dB sound inside reaches `range_for(10)`, outside `range_for(50)`; `clear_zones()` after.

- [ ] **Step 2: Gate and run** `level_test.tscn`. Expected: K6–K9 FAIL.

- [ ] **Step 3: Implement.** The garrison keeps `root_name` "Level" (its tests look for it).

- [ ] **Step 4: Run** `level_test.tscn`: every K and G check passes, no `SCRIPT ERROR`.

- [ ] **Step 5: Commit** `feat(level): terrain colliders and occluders, levels side by side, noise zones`.

---

### Task 6: The harbour's textures

**Files:**
- Modify: `tools/textures/ps2ify.py`, `tools/textures/paint.py`, `scripts/Visual/Materials.gd`, `tools/level/common.py` (`SLOT_COLOURS`)
- Create: `tools/textures/recipes/<slot>.json` for each photo slot below
- Test: `tools/textures/test_ps2ify.py`, `tools/textures/test_paint.py`, `tests/level_test.gd`

**Interfaces:**
- Produces: the slots below in `Materials.SLOTS` and `common.SLOT_COLOURS`; `Materials` reads `"tile"` as a number or `[u, v]` (world metres per photo, across and up) and `"offset"` (the world height, m, where the photo's top row sits: a waterline band anchored to the sea); recipe keys `mask` (a second source file, or `painted/<name>.png`, as the alpha), `seams` (`[period px, width px, darken]`: sailcloth seams), `multiply` (a second source, e.g. a height map, multiplied into the colour), `seamless` (true: a photo that does not tile is made to — shifted half its size and its seams cross-faded — for both hulls, the sailcloth and the frieze).

**Photo slots (recipe → source; tile m):**

| Slot | Source (`TCom_…`) | Tile |
|---|---|---|
| `granite` (quays, paving) | StoneRegularWeathered0084_1 | 2.0 |
| `granite_rough` (rock-faced walls, the sea wall, the fort's base) | StoneFacade0043_1 | 2.5 |
| `ashlar_gold` (the golden tower's dressings, frames) | StoneRegularWeathered0227_1 | 2.0 |
| `render_ochre`, `render_salmon`, `render_blue` | PlasterPaintWorn0152_1, 0169_2, 0007_3 | 2.5 |
| `render_straw` (the golden tower's lime) | PlasterPaintWorn0152_1, desaturated and lightened | 2.5 |
| `whitewash` | Wall_Plaster2_3x3_1K_albedo | 3.0 |
| `azulejo_green`, `azulejo_cube`, `azulejo_blue`, `azulejo_blue2` | TilesRelief0010_2, TilesPatterned0311_4, TilesAzulejoBlue0006_2, TilesAzulejoBlue0067_1 | 0.6 |
| `azulejo_border` | TilesPatterned0311_3 | [0.6, 0.15] |
| `waterline_tide`, `waterline_algae` | StoneRegularWeathered0163_2, 0241_1 | [3.0, 3.0] with `offset` 1.4 |
| `calcada` (the Terreiro) | FloorsPortuguese0047_1 | 2.0 |
| `terracotta`, `terracotta_hex` | Pavement_TerracottaAntique_512_albedo, Pavement_TerracottaHexagon_512_albedo | 1.2 |
| `roof_spanish` (UV'd along slopes) | Roofing_SpanishOld_2K_albedo, `multiply` its `_height` | — |
| `brick` (the shipyard's naves) | BrickSmallPatterns0069_2 | 1.5 |
| `rock`, `cliff` | RockBlocky0085_1, Cliffs0211_1 | 3.0, 8.0 |
| `hull_tarred`, `hull_bare` | WoodPlanksPainted0242, WoodPlanksBare0437_8 (desaturate 0.35, darker) | 2.0 |
| `sailcloth` | FabricPlain0138, `seams` | 2.0 |
| `rope_lay` | Various0236_1 | [1.0, 0.25] |
| `rope_coil` (a card) | Various0215_1, `mask` `painted/coil_mask.png` | — |
| `net` (a card, cut) | RopeNet_512_albedo, `mask` RopeNet_512_alpha | — |
| `manueline` (the fort's rope mouldings) | OrnamentsVarious0001 | — |

**Painted (committed):** `iron_rail` (a balcony's wrought rail: bars, a scroll band, cut), `window_grille` (cut), `ratlines` (shrouds and ratlines on a clear card, cut), `coil_mask` (a white ellipse on black: `rope_coil`'s alpha), `decal_salt` (a salt bloom's tide marks for quay faces and hulls), `palm_frond`, `cypress`, `agave`, `orange_leaves` (with fruit), each with `sway` as the garrison's foliage.

- [ ] **Step 1: Write the failing tests.** `test_ps2ify.py`: a recipe with `mask` takes its alpha from the second file; `seams` darkens columns every period; `multiply` darkens where the second image is dark; `seamless` makes the left column match the right and the top row the bottom (mean difference under 8 levels). `test_paint.py`: each new painting renders at its size with a clean cut alpha (only 0 and 255). `level_test.gd`:
  - `K10 with no photos on the machine every new slot draws in its flat colour, and nothing errors` — `Materials.folder` set to an empty scratch folder, `Materials.clear_cache()`, every new slot's `level_surface` has no albedo texture and its colour; restored after.
  - `K11 a waterline band is anchored to the sea: its photo's top row falls at y 1.4 on a quay face` — from `level_surface(&"waterline_tide")`'s `uv1_scale` and `uv1_offset` under Godot's world triplanar mapping, the side projection's v at y 1.4 is a whole number, and `uv1_scale` is `Vector3(1/3, 1/3, 1/3)`.
  - `K12 every new painted slot finds its painting`.

- [ ] **Step 2: Run** `python3 tools/textures/test_ps2ify.py`, `python3 tools/textures/test_paint.py`, `level_test.tscn`. Expected: the new tests FAIL.

- [ ] **Step 3: Implement,** then `python3 tools/textures/ps2ify.py build` and `python3 tools/textures/paint.py`.

- [ ] **Step 4: Run** the three again: all pass. Look at each converted texture at 4× beside its photo (a contact sheet in the scratchpad), and each painting at full size: tiling seamless, palettes clean.

- [ ] **Step 5: Commit** (recipes, paintings, `Materials.gd`, `common.py`, tests — never `textures/ps2` or `textures/source`) `feat(textures): the harbour's slots (granite, render, azulejo, waterline, hulls, sails, rope, net) and our ironwork and Mediterranean foliage`.

---

### Task 7: Fortification kit and horseshoe arches

**Files:**
- Modify: `tools/level/kit_shapes.py`, `tools/level/kit_recipes.py`, `tools/level/test_kit_shapes.py`
- Create: `tools/level/kit_fort.py`, `tools/level/test_kits.py`

**Interfaces:**
- Produces: `kit_shapes.arched_wall(..., horseshoe=0.0)` (how far below the springing the arch's circle continues, as a share of its radius: 0.33 for the Nasrid gate); the pieces:

| Piece | Size (x × y × z) | Budget | Notes |
|---|---|---|---|
| `city_wall_12_6`, `city_wall_12_3`, `city_wall_12_corner` | 6/3/2.4 × 12 × 2.4 | 800 | Walk on top at y 12; English square merlons: 3.0 m bays of a 2.1 m merlon and a 0.9 m gap, 1.8 m high, on the outer (+z) side; a batter (granite_rough) to 4 m, ashlar above; cols: the body and the merlons |
| `city_wall_10_6`, `city_wall_10_3`, `city_wall_10_corner` | as above, 10 high | 800 | The Ribeira's |
| `wall_stair_12`, `wall_stair_10` | 3 wide, along the inner face | 800 | Up to the walk: risers 0.2, treads 0.3, a landing every 10 risers |
| `tower_drum_8` | ⌀8 × 20 | 800 | 16 sides, crenellated top, a door at the walk |
| `tower_square_8` | 8 × 20 × 8 | 800 | |
| `gold_stage_1`, `gold_stage_2`, `gold_stage_3` | ⌀15 × 18; ⌀9 × 9; ⌀4.5 × 5.5 + dome | 1,200 each | Twelve-sided, render_straw with ashlar_gold dressings; stage 1 has blind horseshoe arches, a crenellated terrace (walkable), a door to the mole and an inner stair (cols) |
| `fort_bastion` | 30 × 4 × 24 | 1,200 | Faceted; embrasures at y 1.5 on the water; walkable top |
| `fort_tower` | 12 × 30 × 12 | 1,600 | Belém-like: a loggia on its south face, a Manueline rope band, shield merlons |
| `turret_domed` | ⌀2.5 × 5 | 300 | A garita: ribbed dome (lathe) |
| `gate_front` | 12 × 14 × 3 | 800 | The Sea Gate's arch face, the portcullis groove, a machicolation gallery over it |
| `gate_passage_16` | 4 wide × 5 high × 16 | 800 | Vaulted, three murder holes in the vault |
| `machicolation_6` | 6 × 2 × 1.2 | 400 | Corbels and a parapet |
| `nasrid_gate` | 12 × 12 × 2.4 | 1,000 | A sea-wall piece with the horseshoe arch (7 m wide, springing 6 m) in an alfiz frame; brick and stone |
| `chain_span_12` | 12 long | 300 | Iron links sagging to a float; no cols |
| `windlass` | 4 × 2.5 × 3 | 600 | A timber windlass with capstan bars (static until sub-project 3) |

- [ ] **Step 1: Write the failing tests.** `test_kit_shapes.py`: `test_a_horseshoe_head_runs_below_its_springing` (its arc's lowest points below the springing by 0.33 r, narrower than the span). `test_kits.py` (new; the kit's families against the metrics and budgets):

```python
class Fort(unittest.TestCase):
    def test_budgets(self):
        for name, recipe in kit_recipes.PIECES.items():
            if recipe["family"] in ("fort",):
                self.assertLessEqual(tris(recipe), recipe.get("budget", kit_shapes.PIECE_TRIS), name)

    def test_battlements_are_three_metre_bays(self):
        merlons = [c for c in kit_recipes.PIECES["city_wall_12_6"]["cols"] if c[1] > 12.0]
        self.assertEqual(len(merlons), 2)
        self.assertAlmostEqual(merlons[0][3], 2.1, places=2)

    def test_the_walk_is_walkable_and_parapeted(self):
        cols = kit_recipes.PIECES["city_wall_12_6"]["cols"]
        body = max(cols, key=lambda c: c[3] * c[4] * c[5])
        self.assertAlmostEqual(body[1] + body[4] / 2.0, 12.0, places=2)      # the walk's top
        self.assertTrue(all(c[2] > 0.0 for c in cols if c[1] > 12.0))         # merlons on the outer side
        self.assertGreaterEqual(2.4 - max(c[5] for c in cols if c[1] > 12.0), 1.2)   # a man's width of walk

    def test_wall_stairs_keep_the_metrics(self):
        steps = treads(kit_recipes.PIECES["wall_stair_12"])   # [(top y, depth along the flight)] in order
        rises = [round(b[0] - a[0], 3) for a, b in zip(steps, steps[1:])]
        self.assertTrue(all(r == 0.2 for r in rises))
        self.assertTrue(all(d == 0.3 or (i + 1) % 10 == 0 for i, (_, d) in enumerate(steps[:-1])))
```

  (`tris(recipe)` counts `kit_shapes.build(recipe["shapes"])` triangles, or 12 per box.)

- [ ] **Step 2: Run** `python3 tools/level/test_kit_shapes.py` and `python3 tools/level/test_kits.py`: FAIL.

- [ ] **Step 3: Implement** `kit_fort.py` (family `"fort"`, pure data like `kit_houses.py`), the horseshoe head in `kit_shapes._head`; import it at the end of `kit_recipes.py`.

- [ ] **Step 4: Run** both tests: pass. `level.sh kit`, then render each new piece (`preview.py` on a scratch level placing one of each, `LEVEL_SOURCE` a scratch folder) and look at it from four sides against the references (`refs/castles.md` for the walls and gate, `refs/iberian.md` for the Torre del Oro and Belém).

- [ ] **Step 5: Commit** `feat(level): the fortification kit (city walls, towers, the golden tower, the Belém fort, the Sea Gate, the Nasrid gate) and horseshoe arches`.

---

### Task 8: Iberian kit

**Files:**
- Create: `tools/level/kit_iberian.py`
- Modify: `tools/level/kit_recipes.py` (`WALLS` gains `"granite": ("granite", "stone")` and `"render": ("render_ochre", "stone")`; the import), `tools/level/test_kits.py`

**Interfaces:**
- Produces: `wall_granite_*` and `wall_render_*` (by the existing `WALLS` loop); the houses and pieces below. A house's pivot is its footprint's middle at the arcade's top (y 0 local = the first floor over the arcade), its front toward +z, like `kit_houses`.

| Piece | Size | Budget | Notes |
|---|---|---|---|
| `casa_a` … `casa_h` | 6 × (3–5 storeys of 3.0 + roof) × 10 | 2,200 | Tall narrow fronts inside granite frames (quoins, a cornice); fronts: a azulejo_green, b azulejo_cube, c azulejo_blue, d render_ochre, e render_salmon, f render_blue, g whitewash, h azulejo_blue2; tall windows 1.0 × 2.2 with shutters; iron balconies (a 0.12 slab 0.9 deep, an `iron_rail` card, brackets) on every storey of a, c, d, f and the top storey of the rest; roof_spanish at 20° with a walkable collider along each slope; some windows lit (`glass_lit`) |
| `arcade_ribeira_6` | 6 × 3.6 × 4 | 600 | A low heavy segmental arch 4.4 wide, piers 1.6, a vaulted ceiling; granite |
| `terreiro_bay_6`, `terreiro_corner` | 6 × 13 × 8 | 1,000 | Round arch arcade 6 m high, the storey over it with balconied windows, the roof; render_ochre (Lisbon's yellow) with granite dressings |
| `cais_colunas` | 2 columns ⌀1 × 7 on plinths | 400 | The water stair's pair |
| `water_stair_20` | 20 wide, y 2.5 → 0 | 600 | Treads 0.3 × risers 0.2 |
| `granite_flight_3`, `granite_landing_3`, `granite_parapet_3` | 3 wide | 400 | The Guindais stair: flights of 10 risers |
| `statue_king` | 3 × 7 × 5 | 1,200 | Equestrian on a plinth |
| `alminha` | 1 × 1.6 × 0.3 | 200 | A wall shrine: an azulejo panel, a candle niche (a `light` marker candle goes in it) |

- [ ] **Step 1: Write the failing tests** in `test_kits.py`: budgets for family `"iberian"`; `test_balconies_ladder_up_a_front` (on `casa_a` the balcony floors step 3.0 m apart: each one's lip is within `rules.HANG` of the one below, and 1.0 m of clear wall under each lip); `test_house_doors_meet_the_metrics` (≥ 1.2 × 2.2); `test_roofs_are_walkable` (roof collider pitch ≤ 25°); `test_granite_and_render_walls_exist` (`wall_granite_door`, `wall_render_window` in `PIECES`).

- [ ] **Step 2: Run** `python3 tools/level/test_kits.py`: FAIL.

- [ ] **Step 3: Implement** `kit_iberian.py` (family `"iberian"`; its houses `"house"` like `kit_houses` so the export's small-dressing ranges skip them).

- [ ] **Step 4: Run** the tests: pass. `level.sh kit`; preview each house at full size against the Ribeira photos in `refs/iberian.md`; adjust proportions (a narrow tall front reads Porto; a squat one does not).

- [ ] **Step 5: Commit** `feat(level): the Iberian kit (tall tiled and washed houses with iron balconies, the Ribeira arcade, the Terreiro's arcades, granite stairs)`.

---

### Task 9: Harbour and shipyard kit

**Files:**
- Create: `tools/level/kit_harbour.py`
- Modify: `tools/level/kit_recipes.py` (import), `tools/level/test_kits.py`

**Interfaces:**
- Produces:

| Piece | Size | Budget | Notes |
|---|---|---|---|
| `quay_8`, `quay_4`, `quay_corner` | 8/4 × 5.5 (y −3 → 2.5) × 6 | 400 | Granite top with a 0.4 m coping lip, the face in `waterline_tide` under y 1.2, mooring rings |
| `quay_steps_8` | 8 × 5.5 × 1.4 | 500 | A flight set into the face, parallel to it, y 2.5 → 0 |
| `bollard` | ⌀0.5 × 0.7 | 60 | Solid |
| `mole_8`, `mole_head` | 8 × (y −6 → 3.5) × 14; head ⌀24 | 700 / 1,200 | Top y 3.5, seaward parapet to 5.5, a battered granite_rough face, boulders (rock) at its foot, the inner side a quay face |
| `slipway_8` | 8 × 8.4 | 300 | A ramp from y 2.5 to −2 |
| `crane_jib` | 4 × 10 × 6 | 900 | Timber jib crane with its wheel |
| `nave_pier` | 1.2 × 8 × 1.2 | 100 | Brick, stone imposts |
| `nave_arch_x`, `nave_arch_z` | 8.4 span, springing 8, apex 10.9 | 200 | Pointed, brick |
| `nave_vault` | 8.4 × 2.1 × 8.4 (y 10.9 → 13) | 250 | Groin vault underneath; a flat walkable terrace on top at y 13 |
| `nave_end_wall` | 8.4 × 13 × 0.8 | 300 | Brick with a high window |
| `galley_stocks` | 40 × 7 × 8 | 2,500 | Keel on its blocks, ribs as arcs, part-planked lower hull, scaffolds both sides at y 2.5 and 5 (walkable planks: cols), two ladders (climbs) |
| Dressing | | ≤ 400 each | `net_hung` (poles and cut net cards), `net_pile`, `basket_fish`, `anchor_big`, `anchor_small`, `oars_stack`, `crate_stack`, `rope_coil`, `lobster_pots`, `barrel_row`, `cargo_bales` (family `"dressing"`, drawn to `SMALL_RANGE`) |

  A piece may carry `"climbs": [[cx, cy, cz, sx, sy, sz, yaw]]` (climb boxes in its frame); `Layout.ship()`/`Layout.put(..., climbs=True)` (Task 13) turns them into `ladder` markers.

- [ ] **Step 1: Write the failing tests** in `test_kits.py`: budgets for `"harbour"` and `"dressing"`; `test_a_quay_meets_the_sea` (top at 2.5, face to −3, the lip ≥ 0.15); `test_nave_bays_tile` (pier + arches + vault span exactly 8.4 m; the vault's terrace at 13.0); `test_the_galley_scaffold_climbs` (its planks are walkable boxes, 2.5 m apart vertically ≤ `rules.MANTLE`, its `climbs` reach the upper plank).

- [ ] **Step 2: Run** `python3 tools/level/test_kits.py`: FAIL.

- [ ] **Step 3: Implement** `kit_harbour.py` (families `"harbour"`, `"quay"` — graded by the bake — and `"dressing"`).

- [ ] **Step 4: Run** the tests: pass. `level.sh kit`; preview a nave of three bays with the galley against the Atarazanas and Drassanes photos (`refs/iberian.md`); the quay against Porto's.

- [ ] **Step 5: Commit** `feat(level): the harbour kit (granite quays, the mole, the shipyard's brick naves, the galley on the stocks, the dressing)`.

---

### Task 10: Ships

**Files:**
- Create: `tools/level/kit_ships.py`
- Modify: `tools/level/kit_recipes.py` (import), `tools/level/test_kits.py`

**Interfaces:**
- Produces (family `"ship"`; pivot at the waterline under the mainmast, bow toward +x):

| Piece | Size | Budget | Notes |
|---|---|---|---|
| `carrack_hull` | 30 × (−3.5 → 8) × 9 | 2,800 | Tarred below, bare upperworks; forecastle deck y 6.5, main deck y 2.0 behind 1.0 m bulwarks, sterncastle decks y 5.0 and 8.0; the captain's cabin (5 × 6 m, a door off the main deck, stern windows lit); cols: decks, bulwarks, castle walls, hull sides |
| `carrack_rig` | masts and stays | 1,400 | Fore, main (to y 28, a fighting top at y 20: a walkable 2.5 m platform with a rail, the main yard's place 2 m under it) and mizzen masts; furled sails on the fore and mizzen yards; shrouds as `ratlines` cards; `climbs` up the main shrouds (deck to top, each side) and the fore shrouds |
| `carrack_mainyard` | 22 × 0.5 × 0.5 | 300 | The main yard with its furled sail; its top a walkable 0.45 m footing (a `balance` route); placed separately so its bracing can reach the wall |
| `caravel` | 20 × (−2.5 → 6) × 6 | 1,800 | Two lateen masts, the lateen yards, one `climbs` up the main shrouds |
| `boat_fishing` | 8 × 1.6 × 2.4 | 400 | A stubby mast, a net heap |
| `rowboat` | 4.5 × 0.8 × 1.5 | 180 | Oars shipped |

- [ ] **Step 1: Write the failing tests** in `test_kits.py`: budgets; `test_the_carrack_shrouds_reach_the_top` (a `climbs` box runs from the main deck to within `rules.MANTLE` of the fighting top); `test_the_top_is_a_floor` (the fighting top's col is ≥ 2.0 m across at y 20); `test_decks_meet_their_bulwarks` (the main deck at 2.0 and its bulwarks 1.0 over it); `test_the_cabin_door` (≥ 1.2 × 2.0 — a ship's door may be low: 2.0).

- [ ] **Step 2: Run**: FAIL.

- [ ] **Step 3: Implement** `kit_ships.py` from the carrack references (`refs/iberian.md` §harbour: the Santa María and Mary Rose sections).

- [ ] **Step 4: Run**: pass. Preview the carrack from the quay and from its own deck at full size.

- [ ] **Step 5: Commit** `feat(level): ships (the carrack with its climbable rig and yard, a caravel, fishing boats, rowboats)`.

---

### Task 11: Mediterranean planting and the city's massing

**Files:**
- Create: `tools/level/kit_planting.py`, `tools/level/kit_massing.py`
- Modify: `tools/level/kit_recipes.py` (imports), `tools/level/export.py` (the manifest's `shadowless` list), `scripts/Level/LevelLoader.gd` (applies it), `tools/level/test_kits.py`

**Interfaces:**
- Produces:
  - Planting (family `"nature"`, as `kit_nature`): `palm_date` (a lathe trunk, `palm_frond` cards; 400), `cypress` (a narrow crown of `cypress` cards; 300), `orange_tree` (in a stone planter; 400), `agave` (spiky `agave` cards; 120).
  - Massing (family `"massing"`, each ≤ 600 tris, `glass_lit` cards for windows, box cols so nothing falls through): `mass_houses_20`, `mass_houses_tall_20`, `mass_terrace_wall_40` (a retaining wall 40 × 12), `mass_cathedral` (a nave 90 × 40 to y +40 over its terrace, buttresses as fins), `mass_belltower` (13.5 square, 95 high), `mass_palace` (a block 60 × 40 × 20), `mass_mirador` (a tower 10 × 25 × 10), `mass_aqueduct_40` (two tiers of arches 40 high), `mass_bridge` (three arches, 95 high), `mass_curtain_30`, `mass_castle_tower`, `mass_keep` (36 × 55 × 36).
  - The export draws `"massing"` pieces with shadows off (a manifest list `shadowless`, applied by the loader): far silhouettes cost the moon's shadow pass nothing.

- [ ] **Step 1: Write the failing tests** in `test_kits.py`: budgets for both families; `test_massing_casts_no_shadow` (the manifest built from a massing piece lists it under `shadowless`); `test_the_keep_is_the_crown` (`mass_keep`'s height puts its top at y 155 when placed on the summit at y 100).

- [ ] **Step 2: Run**: FAIL.

- [ ] **Step 3: Implement** both files; the loader applies `shadowless` (`cast_shadow = OFF` on those pieces' meshes) — a small change in `LevelLoader._ranges`' neighbour `_shadowless(level, names)`.

- [ ] **Step 4: Run**: pass. Preview the massing pieces; the palm and cypress at full size.

- [ ] **Step 5: Commit** `feat(level): Mediterranean planting and the city's massing`.

---

### Task 12: Shared gameplay builders

**Files:**
- Create: `scripts/Level/LevelGameplay.gd`, `scripts/Visual/Blowhole.gd`
- Modify: `tools/level/layouts/fixture.py` (one of each new marker), `tests/level_test.gd`

**Interfaces:**
- Consumes: `LevelLoader.Level` (`of()`, `get_marker()`, `marks`), `Props` (door, chest, loot, key, tool, crate), `Lights` (as `maps/garrison.gd._light`), `WaterVolume.build`, `ClimbVolume`, `VerletRope`, `AlarmBell.build`, `GuardStation`, `SoundBus.add_zone` (Task 5), `Materials`.
- Produces (static functions; `parent` is the map; each returns what it made):
  - `doors(parent: Node3D, level) -> Dictionary` (name → door; studded planks; `pick` False makes the lock unpickable if `Door` supports it, else noted).
  - `lights(parent: Node3D, level) -> Array[Node]` (every light kind the garrison makes, `window_shaft` without the chapel's constants).
  - `water(parent, level) -> Array[Area3D]`, `ladders(parent, level) -> Array[Area3D]`, `ropes(parent, level) -> Array[Node]` (VerletRope hanging from the marker, `length`, chain style when `chain`), `bells(parent, level) -> Array`, `decals(parent, level) -> Array` (the garrison's `_decal`).
  - `routes(parent, level) -> Dictionary` (route name → Node3D of Marker3D points, named `<route>_route`), `stations(parent, level) -> Dictionary`.
  - `guards(parent, level, routes: Dictionary, stations: Dictionary, scene: PackedScene) -> Dictionary` (name → Guard; `archetype` through `{"watchman": &"", "arms_master": &"trainer"}`, `temperament`, `look_seed`, `lookout`, `light` → `rounds_light`, `patrol_route` set before `add_child`).
  - `pickups(parent, level) -> Dictionary` (loot, keys and tools by name; loot's `special` sets meta `special` and group `specials`; `kind` "seal" adds group `seals`).
  - `chests(parent, level) -> Dictionary`, `props(parent, level) -> Array` (crates).
  - `noise_zones(parent, level) -> Array[int]` (SoundBus zone ids; removed when `parent` exits the tree).
  - `mechanisms(parent, level) -> Array[Node3D]` (sub-project 1 stubs: a `Node3D` per marker in group `mechanism`, metas `kind`, `target`, `state`; a portcullis draws its iron grid, `width` × `height`, raised when `state` is "up", with a box collider when down).
  - `mission_marks(parent, level) -> void` (`objective`, `exit` (an `Area3D` over its box, group `district_exit`, meta `label`, signal-free: the map connects `body_entered`), `secret`, `probe` (Marker3D in group `probe`, meta `expect`)).
  - `Blowhole.gd` (`Node3D`): `period`, `spray_height`, `roar_db`; every `period` s a roar (a sound cut from the user's packs by `prepare_sfx.py` — a sea surge; ask before adding a pack) and a spray of our own particles (a `GPUParticles3D` of quads drawn by a small shader, no bought or free sprite), and while roaring its SoundBus zone masks `roar_db`.

- [ ] **Step 1: Write the failing checks** in `level_test.gd` (the fixture now has `loot`, `key`, `tool`, `chest`, `prop`, `rope`, `noise_zone`, `portcullis` (down), `exit`, `probe` markers):
  - `K13 every marker of the fixture is made into its node by LevelGameplay` — counts per kind match the markers; the loot's value, the key's id, the tool's count carried over.
  - `K14 a portcullis stub down blocks the way, up lets through` — a ray through its opening hits when `state` is "down", not when "up".
  - `K15 a guard from LevelGameplay walks his route` — the fixture's guard, after the fixture's bake, reaches waypoint 2 within 20 s.
  - `K16 walking into an exit's box is seen` — a body moved into it fires `body_entered`.

- [ ] **Step 2: Gate and run** `level_test.tscn`: K13–K16 FAIL.

- [ ] **Step 3: Implement** by lifting the garrison's code (`maps/garrison.gd`'s `_doors`, `_things`, `_stations_from_markers`, `_routes_from_markers`, `_light`, `_decal`, `_spawn_cast`) into static functions, the garrison's constants passed in or given defaults. `maps/garrison.gd` is not changed.

- [ ] **Step 4: Run** `level_test.tscn`: every check passes, no `SCRIPT ERROR`.

- [ ] **Step 5: Commit** `feat(level): LevelGameplay, the game's nodes from any level's markers; the blowhole`.

---

### Task 13: The harbour and the massing laid out

**Files:**
- Create: `tools/level/layouts/city_harbour.py`, `tools/level/layouts/harbour/{__init__,ground,quays,ribeira,terreiro,shipyard,mole,fort,cave,ships,markers}.py`, `tools/level/layouts/city_massing.py`
- Modify: `tools/level/layouts/lay.py` (`ship()`, `put(..., climbs=False)`)

**Interfaces:**
- Consumes: every kit family (Tasks 7–11), `terrain` (Task 3), the markers (Task 1), the anchors table above.
- Produces: `city_harbour.layout()` and `city_massing.layout()` returning level data; `Layout.ship(piece, at, yaw, sector)` puts a piece and one `ladder` marker per `climbs` box (named `<piece name>_climb_<n>`).

Each `harbour/*.py` has `def lay(L: Layout) -> None` for its sector; `city_harbour.layout()` calls them in order. What each must hold (positions from the anchors table):

- **ground** (`sea`, `river`, `cave` terrain): `sea_bed` grid x −260…300, z −10…420, 8 m cells, −6 in the bay, −10 past the mouth, rising to −2 at the quay faces, drop quads under −9.5 beyond z 380; `west_spit` grid at 2 m cells kept above −2; `river_banks` cliffs both sides of the river (y 3 → 40 by z −150); `east_cliff` cliff strip from (175, 0) round to (260, 90), top y 20–28, a gap for the cave mouth; `cave` tunnel from the mouth (225, 1, 60) to the beach (230, 1, 15) and on to its sealed end (232, 1, −20), radii 6 × 8 narrowing to 3 × 3, floor 0.6 on the beach; the blowhole shaft a tunnel from (232, 6, 0) up to (232, 26, 0).
- **quays**: the quay line in `quay_8` pieces with `quay_steps_8` every 40 m, bollards every 8 m, a waterline decal (`moss`) under each flight.
- **ribeira**: 13 `arcade_ribeira_6` bays; `casa_*` over them (heights varied: a 5, b 4, c 6, d 3, e 5, f 4, g 6, h 4, repeated with yaw kept), their backs against `city_wall_10_*` at z −22; the Guindais stair (flights and landings, parapets) to the upper gate (a locked `door`, `pick` False, no key — its `exit` marker "the old town's upper gate"); the west wall up the slope; lit windows and hanging lanterns every second bay; an `alminha` at the stair's foot with a candle.
- **terreiro**: the square's floor (`floor_calcada_4` — add to `FLOORS` in `kit_recipes`), the three arcades (`terreiro_bay_6`, corners), the water stair and `cais_colunas`, the statue, six `lamp_post` lights, the Sea Gate (`gate_front`, `gate_passage_16`, two `tower_drum_8`, the city wall `city_wall_12_*` behind the square), the portcullis marker (`state` "up"), the gate's city end: an `exit` "the old town (the Sea Gate)"; zones (`terreiro` outside with a warm fog, `sea_gate` indoors).
- **shipyard**: the sea wall (`city_wall_12_*` along z −6 with `nasrid_gate` at x 68.6), 12 naves (`nave_pier`, arches, vaults, end walls), the slip basin (a `water` marker z −26…−6 in nave 6, `slipway_8`), the galley on the stocks in nave 3 and its scaffold climbs, the customs house (`wall_granite_*`, `wall_render_*`, floors `terracotta`, stairs, the office with the seal's chest (locked, `pick` True) and the watchman's desk with `customs_key`), the customs house's door into the shipyard barred on the shipyard side (`barred` True: opened from within — the harbour's loop home, back to the Terreiro), the rope yard with `crane_jib` and cargo, the east wall at x 150 with a `wall_stair_12`, the vault terrace stairs up to the walk; `exit`s at the walk's ends "the old town (the wall-walk)" and the shipyard's north gate; zones `shipyard` (indoors, dark), `customs` (indoors).
- **mole**: `mole_8` from the root south and round to `mole_head` (8 m pieces, 10° steps on the bend), boulders, the golden tower's three stages on the head, the `windlass` inside, the chain (`chain_span_12` × 12 to the fort), the beacon brazier on the terrace, the `bell` by the lookout.
- **fort**: `fort_bastion`, `fort_tower`, four `turret_domed`, a lantern, optional loot (the powder room: a `secret` box).
- **cave**: the smugglers' jetty, crates, contraband `loot` (three), a lantern (`glow`), the `noise_zone` round the blowhole (db 45, the blowhole's), the sealed tunnel end (an `exit` "the undercroft (sealed)").
- **ships**: the carrack (`carrack_hull`, `carrack_rig`, `carrack_mainyard` braced so its north arm's tip is over the sea wall's walk), a gangplank to the quay, the captain's cabin (a strongbox `chest` locked, `pick` True, loot inside); the caravel; four fishing boats; six rowboats (one at the start).
- **markers**: the nine guards — the Sea Gate a swordsman and a watchman (posts); the quays' pair a watchman and a swordsman, both `light` "lantern"; the customs watchman; the carrack's deck watch a duelist; the lookout an archer (`lookout` True); the mole's patrol a watchman; the shipyard's brute — their routes (waypoints on floors, the mole patrol's to the golden tower's door), stations for the Sea Gate posts; `spawn` "start" in the rowboat; loot about 20 pieces worth about 1,500 in all, the harbourmaster's seal (`special` True, `kind` "seal") in the office chest; keys `customs_key`, `cabin_key`; tools (two flasks in the fishing sheds); probes (eight: under the Ribeira arcade "shadow", the open Terreiro "lamp", the mole top "moon", nave 5 "shadow", the carrack's deck "moon", the customs office "lamp", the cave beach "shadow", the fort's bastion "moon"); `vantage`s for the stills (the mole's start, the quay looking up at the whole rock, the Terreiro from the water stair, the Sea Gate, the Ribeira from the caravel, down a nave, the galley, the carrack's top, the golden tower's terrace, the cave from its beach); `route_check` routes for each way in (`way_carrack`: deck → shrouds (climb) → top → yard (balance) → drop onto the walk; `way_roofs`: quay → balcony hangs up casa_d (three storeys: its eaves y 15.1, 2.6 m over the walk) → roof → drop onto the walk; `way_nasrid`: swim through the gate → the slip's steps; `way_mole`: boat → boulders (mantle) → the parapet (mantle) → the top), a `bench_1…bench_8` mark path for the benchmark; `landmark`s the guards name places by (the Sea Gate, the golden tower, the customs house, the shipyard, the Ribeira, the mole, the carrack); `hide` spots in the arcades' shadows and the naves; a `hunt_area` per sector.
- **city_massing**: a `rock` terrain grid 800 × 720 m at 10 m cells (the old town's terraces, the cathedral and palace terraces, the summit at y 100, the gorge cut 100 m deep, its rims ragged `cliff` strips), and the massing pieces at the positions in "Sectors" above, lit windows sparse and warm.

- [ ] **Step 1: Write the check first:** add `city_harbour` and `city_massing` to a new test `test_rules.py::test_the_city_layouts_check_clean` that imports both layouts and asserts `rules.problems(data, "stage2") == []` (pure Python: the kit's recipes, the terrain triangles; it runs without Blender).

- [ ] **Step 2: Run** `python3 tools/level/test_rules.py`: FAIL (no layouts).

- [ ] **Step 3: Implement** sector by sector, running the test after each; a failing route check means the geometry is wrong, not the check.

- [ ] **Step 4: Build, check, export** both: `level.sh kit && level.sh build city_harbour && level.sh export city_harbour && level.sh build city_massing && level.sh export city_massing`: 0 problems, every sector under its budget (print the counts). `level.sh preview city_harbour <scratch>`: look at the plan and the four bird's-eye views against the anchors table.

- [ ] **Step 5: Commit** (the layouts, the rebuilt `kit.blend`, the levels' `.blend`s in `assets/level/source/` — the user's to edit from now on, as the garrison's is — and the exported `assets/level/city_*` glbs and manifests) `feat(city): the harbour laid out (quays, the Ribeira, the Terreiro and the Sea Gate, the shipyard and customs house, the mole and golden tower, the fort, the cave, ships) and the city's massing`.

---

### Task 14: The mission's map

**Files:**
- Create: `maps/city.gd`, `maps/city.tscn`
- Modify: `scripts/Night/Night.gd`, `scripts/Night/NightSky.gd` (`skyline` path), `tools/skyline/skyline.py`, `tools/skyline/skyline.sh` (a `city` scene → `assets/sky/skyline_city.png`)

**Interfaces:**
- Consumes: `LevelLoader.load_level(parent, folder, root_name)`, every `LevelGameplay` builder, `NavBaker`, `Night`, `Player.tscn`, `Guard.tscn`, `Props.give_blackjack`/`give_tools`.
- Produces: `maps/city.gd` (extends `Node3D`):
  - `const DISTRICTS := ["res://assets/level/city_harbour", "res://assets/level/city_massing"]`.
  - `var levels := {}` (name → Level), `var guards := {}`, `var player: CharacterBody3D`, `var night: Node3D`, `var baker: NavigationRegion3D`.
  - `signal ready_to_play`; `func _ready()`: `TemperamentScript.rolling = false` while building, Squad/Garrison cleared, `LightProbe.invalidate()`; load the districts; the environment (the garrison's night environment and moon: moon from the south-south-west, `toward = Vector3(0.3, -0.57, -0.77)`, shadow distance 120 m); every LevelGameplay builder; `Night` (seed 1947, start "clear", puddles on the Terreiro and quays, mist over the water box's surface, `skyline` "res://assets/sky/skyline_city.png") and the harbour's changing night: a `WEATHER` schedule `[[minute, state, seconds], ...]` (clear; cloudy at 4 min; drizzle at 9; a shower at 13; cloudy at 16) played by `Night.to()`, and a cloud over the moon (`cover_moon`) every 90–150 s (seeded); `Wind` (the palms and cypresses sway) and `Wildlife` (bats round the golden tower's lantern, none over the water); the Blowhole at the cave; `baker` (agent radius 0.4, max climb 0.3, `min_island` 1.2, `drop_unreached`, `bake_bounds` the land and 25 m of water round it: `AABB(Vector3(-240, -12, -130), Vector3(520, 60, 360))`); await `baker.baked`; the guards (seeded, `GuardScript.randomize_on = false` while made); the player at `start`, with blackjack and tools; exits print and toast their label; `ready_to_play`.
  - `-- --fps-report=N`: a camera follows `bench_1…bench_8` over N seconds; prints `city: fps avg %.1f, p99 %.1f ms, load %.1f s` and quits. `-- --vantage=<name>` starts the player at a vantage.
  - The player's camera `far` at least 1,200 m (check `Player.tscn`); the environment's fog hides the massing's hand-over.

- [ ] **Step 1: Gate** `maps/city.gd` with `--check-only`.

- [ ] **Step 2: Run the map** headless for 600 frames (`--quit-after 600`): no `SCRIPT ERROR`, the bake finishes, nine guards made, the player made.

- [ ] **Step 3: Render the skyline** (`tools/skyline/skyline.sh city`): far hills to the north behind the rock, the coast east and west, open sea to the south with a faint far headland; look at it at full size.

- [ ] **Step 4: Play it windowed** (`$GODOT --path . res://maps/city.tscn`) and walk each way in once by hand. Note what breaks for Task 15's checks.

- [ ] **Step 5: Commit** `feat(city): the mission's map (the harbour and the massing, the night and the sea, the guards, the player)`.

---

### Task 15: The city suite

**Files:**
- Create: `tests/city_test.gd`, `tests/city_test.tscn`

**Interfaces:**
- Consumes: `maps/city.tscn` (its `ready_to_play`, `levels`, `guards`, `player`), the markers' nodes, `LightProbe`, `NavigationServer3D`, `Input` actions (`move_forward`, `jump`, `crouch`, …) as `tests/climb_swim_test.gd` drives them.

- [ ] **Step 1: Write the suite** (`_check(name, ok, detail)`; results printed at the end):
  - `C1 the harbour and the massing load under their own roots; the navmesh bakes; the load takes under 15 s` (the time printed).
  - `C2 every marker is made into its node` (counts per kind against the manifests).
  - `C3 every guard stands on the navmesh and can reach every point of his route` (`NavigationServer3D.map_get_path` from his spawn to each waypoint ends within 0.5 m of it).
  - `C4 every locked door and chest opens: its key is in the level, or it can be picked`.
  - `C5 every probe reads what it expects` (`LightProbe` at the probe: "moon" lit by the moon and no flame, "shadow" under 0.15, "lamp" lit by a flame).
  - `C6 the carrack's way: from the deck up the shrouds to the top, onto the yard, along it and down onto the wall-walk, through the controller, within 60 s, the player unhurt`.
  - `C7 the roofs' way: up casa_d's balconies and over its roof onto the wall-walk, through the controller, the player unhurt`.
  - `C8 the Sea Gate's passage is on the navmesh from the Terreiro to the city side; its portcullis is up`.
  - `C9 the bay is swum: dropped off the water stair the player swims, and reaches the Nasrid gate's slip`.
  - `C10 the west spit is solid rock underfoot ("stone"), and walked up`.
  - `C11 the blowhole's roar hides a noise: a guard 12 m off hears a 60 dB noise outside its zone and not inside it while it roars`.
  - `C12 each zone's grade eases in with the camera in it` (terreiro, shipyard, customs, cave).
  - `C13 a guard chasing the player out into the open bay stops at the navmesh's edge and searches within 20 s; he never stands in the water past it`.
  - `C14 no more than six lights cast shadows at once anywhere on the benchmark path` (LightBudget).

- [ ] **Step 2: Gate and run** it: every check that fails names a real fault in the level, the map or the builders. Fix the fault (the layout, a kit piece, a builder), never the check's threshold, and re-export.

- [ ] **Step 3: Run** `level_test`, `city_test`, `climb_swim_test`, `night_test`, `lights_test`, `interaction_test`, `stealth` (and the rest of `tests/*.tscn` once): all pass, no `SCRIPT ERROR`.

- [ ] **Step 4: Commit** `test(city): the harbour's suite (loads, markers, guards' reach, keys, light, the ways in through the controller, water, noise, zones)`.

---

### Task 16: The benchmark

**Files:**
- Modify: `maps/city.gd` (only as the measurements demand), `tools/level/layouts/harbour/*.py`, kit files

- [ ] **Step 1: Measure** windowed at 1920 × 1080: `$GODOT --path . --resolution 1920x1080 res://maps/city.tscn -- --fps-report=90`. Record average fps, p99 frame time and the load time.

- [ ] **Step 2: If short of 60 fps average or 25 ms p99 or 15 s load,** find the cost with Godot's monitors (draw calls, primitives, shadow casters, physics time, navigation) and fix it at its source: visibility ranges on dressing and ships' rigging, more of the massing unshadowed, sectors merged into fewer meshes, the terrain's cells coarser where only seen, the navmesh's `cell_size` 0.2 (with `AGENT_RADIUS` 0.4 still whole cells) if the bake is the load's cost. Re-run Task 15's suite after each change.

- [ ] **Step 3: Record** the numbers in the commit message.

- [ ] **Step 4: Commit** `perf(city): the harbour at <avg> fps, p99 <ms> ms, loaded in <s> s`.

---

### Task 17: The look, judged

**Files:**
- Create: `tests/city_stills.gd`, `tests/city_stills.tscn` (a stager: `-- --out=DIR`, one 1920 × 1080 still per vantage, under clear, cloudy and rain)
- Modify: whatever the judging finds (kit, layouts, recipes, `maps/city.gd`'s light)

- [ ] **Step 1: Take the stills** windowed (`$GODOT --path . --resolution 1920x1080 res://tests/city_stills.tscn -- --out=<scratch>/stills`).

- [ ] **Step 2: Judge each at full size** against spec §9 and the colour key (granite grey and sea green under the moon, lamp amber on the quays, the golden tower warm): small hot lights and real darkness; lit windows sparse; the keep visible from the quays as the crown; no seams, stretched textures, floating pieces, z-fighting or light leaks; the scale reading grand (people small against the gate, the naves, the tower).

- [ ] **Step 3: Fix and retake** until every still passes; re-run `city_test` after changes.

- [ ] **Step 4: Send the stills to the user** (SendUserFile) with the numbers from Task 16, and ask for their look review at full size in-game.

- [ ] **Step 5: Commit** `feat(city): the harbour's look (<what changed>)`.

---

### Task 18: Wrap-up

- [ ] **Step 1:** Update `tools/level/level.sh`'s usage and the docstrings of every changed module (what they now do, not what they did); write `docs/superpowers/specs`' status line to "sub-project 1 built".
- [ ] **Step 2:** Run every suite once more (`tools/level/level.sh test`, the textures' tests, `tests/*.tscn`): all pass.
- [ ] **Step 3:** One fresh review of the whole branch on the most capable model (superpowers:requesting-code-review), fix what it finds, re-run the suites.
- [ ] **Step 4:** Update memory (`canal-quarter-mission-program.md` → the city program's status; `MEMORY.md`'s line).
- [ ] **Step 5:** Ask the user before merging into main (superpowers:finishing-a-development-branch).
