# The Old Town's Shell (plan B1a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The old town built as a district you can walk empty, with no guards and no puzzles. It covers:
- four generated house families on one grid, rooms inside the enterable ones;
- terraces, stairs and the ground below;
- the six key buildings and the Carmo ruin, each entered three or more ways;
- all five quarters with their streets, roof chains and terrace connectors;
- its ways to the harbour and its sealed ways;
- the massing redrawn round it, and the harbour seeing it;
- the city's sky over it, and its own uncanny touches.

These come later, not in B1a:
- **B1b:** guards, households' people, curfew and alarm, moon lamps' behaviour, the sereno's keys, readables, jobs, the upper gate's lock and key, loot, secrets' contents, visible memory, and the watch shunning the ruin.
- **B2:** the azulejo map inside the Sea Gate, tiled street-name plates, shop signs, furnishing beyond what a way in needs, textures, laundry and plants, and sound.

**Architecture:**
- **Python (`tools/level`).** One grammar module (`kit_town.py`) builds fronts, shells, floors, stairs, rooms and roofs. Four family kits build on it. The town's lot plan is data (`tools/level/town/`, one module per quarter), read by both the kits and the layout:
  - The kits register one recipe per distinct house design when `kit.blend` is built.
  - The layout places each lot, its doors and its route checks.
  - Key buildings are hand-made kits that list their ways in. The layout turns those into route checks, which the rules hold to three or more ways of different kinds.
- **Godot.** The old town's map shares the city's sky (haze, comet, roofed shadow layer, Distance) through `DistrictMap`. It adds two lights of its own: the comet's red light in the ruin, and the balefire's green light on the upper town. A new old-town suite walks every way in through the real controller.

**Tech Stack:** Python 3 level pipeline with unittest, Blender 5.2.2 (`tools/level/level.sh`), Godot 4.5.1 headless suites.

**Spec:** `docs/superpowers/specs/2026-10-02-old-town-design.md`. Sections 4-6 are the old town, 9-11 the pipeline, performance and testing, and **16 the amendments of Oct 3**: B1 splits into B1a and B1b, the harbour polish lands first, and the four in-town uncanny touches. The harbour polish this builds on is `docs/superpowers/specs/2026-10-02-harbour-polish-design.md`. Reference numbers come from `docs/superpowers/refs/old_town_{porto,lisbon,spain,level_design}.md`.

## Global Constraints

- **Before Task 1, main must contain the harbour polish merged with plan A.** Check that `scripts/Visual/Distance.gd`, `tools/level/kit_interiors.py` and `Layers.ROOFED` exist on main, and that `maps/city.gd` still extends `DistrictMap`. If not, stop: the user decided the polish lands first. Branch `old-town-b1a` from that main in a worktree of its own. Copy `textures/ps2` and `textures/source` in from the main checkout (they are gitignored).
- **Grid and metrics:**
  - Plans on a **0.5 m grid**. A family's own module (the Pombaline 2.70 m bay) is centred inside a snapped lot, with the end piers taking the slack.
  - The controller's metrics are those in `tools/level/rules.py`: `MANTLE 2.3`, `HANG 3.9`, `GAPS` jump 4.0 / sprint 5.3 / assist 6.2, `SAFE_DROP` about 4.46, `HEADROOM 1.95`, `LIP 0.15`.
  - The door is 1.2 × 2.2 m.
- **Budgets:** at stage 2 a sector has **120 000 triangles**. Quarters are split into sectors of **at most about 100 m**.
- **Names:** marker names are unique across districts (`rules.district_problems`). Keep the stand-in's gate names: `from_harbour_<gate>`, `to_harbour_<gate>` and `old_town_start`.
- **Textures:**
  - The repo DGSENZEN/under_cover_of_darkness is public. Never commit a textures.com photo or anything rendered from one; `textures/source` and `textures/ps2` stay gitignored.
  - Every new painting is ours, made in `tools/textures/paint.py`. No free VFX or texture assets. The web is reference only.
- **Look and sound:**
  - PSX-inspired, not a copy: keep the dither, grid and grading, and **never vertex snapping**.
  - Sounds come only from the user's packs or approved ones. Voices are NOX Voices Essentials only. B1a adds no voices.
- **Tone:** grounded dark fantasy. The uncanny stays restrained and is never explained (spec §16).
- **Don't break what exists:**
  - `maps/garrison.gd` is untouched, and the garrison suites pass.
  - Every existing suite stays green, with the long four (cinema, intruder, showcase, talk) run alone at `--quit-after 3000000`.
- **Inspect geometry closely** (the user's standing rule). A quarter, or a key building, is not done until:
  - the hole scan over it is clean;
  - daylight close-up stills of its joints have been looked at full size: house to house, house to ground, stair to terrace, roof to roof (`tests/diag/diag_look`).
- **Merging:** ask the user before merging to main or pushing.
- **Shell commands:** the worktree guard refuses compound commands, `git -C` and odd heredocs. Write scripts into the plan's workspace and run them plainly.

## Review Focus

1. **A slit between neighbouring houses** (0.05-1.0 m), which a foot falls into or the eye sees through. Neighbours share a party wall, or leave a lane of 1.0 m or more. Test: Task 13 `test_no_slit_between_neighbours`.
2. **A door that looks openable but is not, or a door marker on a shut front** (rule 22). Every live door of a placed house has its marker, and no marker stands on a shut front. Test: Task 13 `test_every_live_door_has_its_marker`, `test_no_door_marker_on_a_shut_front`.
3. **Falling out of the world at the district's edges:** the gorge rim, beyond the upper gate, the east shoulder. There is ground under every column within the district plus 30 m, or a wall. Test: Task 21 O13.
4. **A way in the rules pass but the controller cannot do** (the capsule against a sill, a hatch, a lip). Test: Task 21 O8-O12 walk every key building's ways and the connectors through the real controller.
5. **Lamps and the balefire's light pushing past the LightBudget's six shadows, or 300 houses sinking the frame rate and load time.** Test: Task 22 O14 (at most six shadows on the bench path), O15 (load under 15 s), and the bench numbers recorded.

---

### Task 1: The old town's markers and rules

**Files:**
- Modify: `tools/level/markers.py`, `tools/level/rules.py`, `tools/level/level.sh` (its `test` verb)
- Test: `tools/level/test_town_rules.py`

**Interfaces:**
- Produces markers:
  - `household`: a box; requires `label`; optional `ways` 3 and `people` "" (B1b fills it).
  - `terrace_step`: a box; requires `label`; optional `public` 2 and `thief` 1.
  - `home` (point, `label` ""), `seat` (point, `label` ""), `work` (point, `kind` ""): townsfolk reservations, with no Godot builder.
  - `shunned` (box, `label`): the ruin's nave, where the watch won't stand. Its rule comes in B1b.
  - `LIGHT_KINDS` gains `comet_shaft`, built in Godot by Task 20.
- Produces marker props:
  - `route_check` gains optional `way` (one of "", "public", "thief", "roof", "below"), `step` "", `into` "" and `kind` (one of "", "door", "window", "roof", "below", "wall", "leap", "yard"). They are read from a route's `order` 1 marker.
  - `light` gains `dark_only` False; `door` gains `curfew` False. Both are used by B1b.
- Produces `rules.way_problems(data) -> list[str]`, called from `rules.problems`. `home`, `seat` and `work` join `STANDING`.

- [ ] **Step 1: Write the failing tests** in `test_town_rules.py`, building data with the existing `test_rules` helpers:

```python
def test_a_household_needs_three_kinds_of_way_in(self):
    data = good_with_household(ways=3, routes=[("door", inside), ("window", inside)])
    self.assertTrue(any("tavern (household): 2 ways in" in p for p in rules.problems(data)))
    add_route(data, "roof", inside)
    self.assertEqual(rules.problems(data), [])

def test_two_ways_of_one_kind_count_once(self):  # door, door, window -> 2 kinds
def test_a_way_in_ends_inside_its_household(self):  # last point outside the box -> "ends outside tavern"
def test_a_terrace_step_needs_two_public_and_one_thief(self):
def test_the_new_markers_have_defaults(self):  # with_defaults: household ways 3, light dark_only False, door curfew False
def test_a_home_stands_on_a_floor(self):  # a home marker in the air -> "it stands on nothing"
```

- [ ] **Step 2: Run** `cd tools/level && python3 -m unittest test_town_rules -v`. Expected: FAIL, because the schema has no `household`.
- [ ] **Step 3: Implement the schema entries and `way_problems`.**
  - For each household: count the distinct `kind`s among the routes whose first marker has `into` equal to its `label`. Each such route's last point must lie inside the box (use `geo` boxes as `rules` does).
  - For each terrace step: count the routes whose first marker has `step` equal to its `label`, by `way`.
  - Messages: `"%s (household): %d ways in (%s), needs %d of different kinds"`, `"route %s ends outside %s"`, `"%s (terrace step): %d public and %d thief connectors, needs %d and %d"`.
- [ ] **Step 4: Run** the new tests, then `tools/level/level.sh test`. Expected: all OK, and the harbour and massing layouts still check clean. Add `test_town_rules` to `level.sh test`.
- [ ] **Step 5: Commit** `feat(old town): households, terrace steps and the ways into them, checked`.

### Task 2: The town's grammar

**Files:**
- Create: `tools/level/kit_town.py`
- Modify: `tools/level/export.py` (`GRADED` gains `"town"`), `tools/level/kit_recipes.py` (an import line at the end)
- Test: `tools/level/test_town.py`

**Interfaces:**
- Consumes `kit_iberian`: `roof_cols`, `_tiled_roof`, `_balcony`, `_rail_cols`, `_frame`, `col`. Consumes `kit_shapes`, `kit_recipes.piece/model`, and `rules` metrics.
- Produces, in `kit_town`:
  - `GRID = 0.5`, `snap(v: float) -> float`
  - `HONEST = ("shut", "barred", "boarded", "lit", "blind")`, `LIVE = ("door", "window", "hatch")`
  - `@dataclass Opening(x: float, y: float, width: float, height: float, kind: str, face: str = "front")`
  - `wall(length: float, height: float, thickness: float, openings: list[Opening], slot: str, place: tuple) -> (shapes, cols)`. Its collider is split round **LIVE** openings only. An HONEST opening is drawn by `honest()` on the face and leaves the collider whole. `place` is `(x, z, yaw)` in the piece's frame.
  - `honest(o: Opening, slot: str) -> shapes`:
    - shut: shutters closed;
    - barred: a planked door with an iron bar;
    - boarded: boards across;
    - lit: `glass_lit` behind shutters ajar;
    - blind: plastered.
  - `floors(width, depth, levels: list[float], hole: tuple | None) -> (shapes, cols)`: 0.2 m slabs, with a stair hole.
  - `stair(kind: str, width: float, rise: float, at: tuple, yaw: float) -> (shapes, cols)`: kinds `"straight"`, `"two_flight"` and `"spiral"`. `RISER = 0.18`, `TREAD = 0.25`. Colliders are stepped boxes, as in `kit_recipes`' `stair_straight`.
  - `rooms(plan: list[tuple], y: float, height: float, doors: list[tuple]) -> (shapes, cols)`: partitions 0.1 m thick, door openings 0.9 × 2.1 m.
  - `roof(kind: str, width, depth, eaves_y, pitch, slot) -> (shapes, cols)`: kinds `"gable"`, `"hipped"`, `"four"`, `"mansard"` (65° lower, 25° upper) and `"flat"` (an azotea, parapet 1.0 m).
  - `register(name: str, family: str, slot: str, design: dict) -> str`:
    - `design` holds `shapes`, `cols` and `size`, and may hold `budget`, `doors` (`[x,y,z,yaw]` local, one per LIVE door), `entries` (the kinds of way in), `climbs`, `chimneys` (`[x,y,z]`, registered as sockets of kind `"chimney"`), `ways` (key buildings: `[{"kind", "points": [[x,y,z,move], ...]}]`) and `roofed`.
    - It registers the piece with family `"town"` (or the given family) and the extra keys.

- [ ] **Step 1: Write the failing tests:**

```python
def test_the_grid_snaps(self):
    self.assertEqual(kit_town.snap(4.26), 4.5); self.assertEqual(kit_town.snap(4.24), 4.0)
def test_an_honest_opening_leaves_the_wall_whole(self):
    # a 6 x 7 m wall with a "shut" window at x 0, y 3: a ray through the window's middle hits a collider
def test_a_live_door_is_a_way_through(self):
    # a "door" opening 1.2 x 2.2 at x 0: rays at heights 0.2, 1.0 and 2.0 through its middle pass every collider
def test_a_stair_climbs_a_storey(self):
    # stair("two_flight", 1.0, 3.2, ...) registered as test_stair; a route_check stairs walk from its foot to its top landing: rules.problems == []
def test_rooms_leave_doors_between_them(self):
    # three rooms in a 6 x 12 plan: a walk route between the room centres passes through their doors
def test_every_roof_kind_is_stood_on(self):
    # every face named roof* has a collider within 0.45 m below (as Iberian.test_every_city_roof_is_stood_on)
```

- [ ] **Step 2: Run** `cd tools/level && python3 -m unittest test_town -v`. Expected: FAIL, because there is no module `kit_town`.
- [ ] **Step 3: Implement `kit_town.py`.** Reuse `kit_iberian`'s roofs, balconies and frames rather than copying them. Add `"town"` to `export.GRADED`, and import `kit_town` at the end of `kit_recipes` (after `kit_interiors`).
- [ ] **Step 4: Run** the tests, then `level.sh test`. Expected: OK. Add `test_town` to `level.sh test`.
- [ ] **Step 5: Commit** `feat(old town): the town's grammar: fronts true to what opens, shells, floors, stairs, rooms, roofs`.

### Task 3: The Porto house

**Files:**
- Create: `tools/level/kit_porto.py`
- Test: `tools/level/test_houses.py` (class `Porto`)

**Interfaces:**
- Consumes `kit_town`.
- Produces `kit_porto.design(width: float, depth: float, storeys: int, quirk: str = "", enterable: bool = False, rooms: int = 0, front: str = "render", side: str = "granite", seed: int = 0) -> dict`, a `kit_town.register` design. Values (`old_town_porto.md` kit, §9 and §13):
  - Widths 3.0, 4.5, 6.0 and 7.5; depths 10-22.
  - Shop floor 3.8 m; upper floors 3.2.
  - Party walls 0.4; stone front 0.6 (tabique 0.15 on a jetty).
  - Bays 1.25 m wide: 1 per 3 m front, 2 per 4.5, 3 per 6 and 7.5. Sill 0.9, head 2.4.
  - Balcony doors 1.25 × 2.8. Balconies 0.5 deep on a 0.15 slab with corbels; rail 0.95.
  - Hipped canal-tile roof at **27°** (design, within 25-30), eaves of 3 courses.
  - Quirks (one per house):
    - `jetty` (0.4 m oversail);
    - `mirante` (2 × 2 × 2.2);
    - `dormer` (1.0 wide);
    - `privy_tower` (1.2 × 1.2 up the back);
    - `against_wall` (a top-floor door onto the wall-walk);
    - `corner_shrine`;
    - `two_level` (doors on two terraces: the back door one storey up);
    - `slot` (1.5 m wide, the hidden house).
  - Enterable: rooms by the real plan (shop below, kitchen at the top); a straight stair on a party wall (TwoFlight from 15 m deep).

- [ ] **Step 1: Write the failing tests:**

```python
def test_bays_follow_the_width(self):        # 3.0 -> 1, 4.5 -> 2, 6.0 -> 3, 7.5 -> 3 front openings per upper storey
def test_storeys_are_shop_then_3_2(self):    # eaves == 3.8 + (storeys - 1) * 3.2
def test_a_jetty_oversails_0_4(self):        # the upper front's face stands 0.4 m out of the ground floor's
def test_the_first_balcony_is_hung_from_the_street(self):  # its slab top is within rules.HANG of the street
def test_an_enterable_house_has_its_door_and_rooms(self):  # one LIVE door in doors; rooms 1-3 reached from it (as Task 2's rooms test)
def test_a_two_level_house_has_a_door_a_storey_up(self):
def test_porto_budget(self):                 # tris <= 1600 honest, 2800 enterable (design)
```

- [ ] **Step 2: Run** `python3 -m unittest test_houses.Porto -v`. Expected: FAIL (no module).
- [ ] **Step 3: Implement** `design` on `kit_town`.
- [ ] **Step 4: Run** `test_houses.Porto`, then `level.sh test`. Expected: OK. Add `test_houses` to `level.sh test`.
- [ ] **Step 5: Commit** `feat(old town): the Porto house, generated`.

### Task 4: The Pombaline building

**Files:**
- Create: `tools/level/kit_pombal.py`
- Test: `tools/level/test_houses.py` (class `Pombaline`)

**Interfaces:**
- Produces `kit_pombal.design(bays: int, depth: float, storeys: int = 4, kind: str = "mid", fire_walls: tuple = (False, False), quirk: str = "", enterable: bool = False, rooms: int = 0, front: str = "azulejo_blue", seed: int = 0) -> dict`. Values (`old_town_lisbon.md` kit and §4):
  - Kinds: `"mid"`, `"corner"` (four-pitch roof, two fronts), `"hill"` (2-3 bays, 3-4 storeys) and `"row"`.
  - Opening = pier = 1.35, end piers 1.6, bay pitch 2.70. 3-6 bays (2-3 for hill). The lot width is snapped up to the grid, and the end piers take the slack.
  - Storeys 4.0, 3.7, 3.4, 3.1, then an attic (dormers 1.0 × 1.4, one per 2-3 bays) or `quirk="mansard"` (65°/25°).
  - First floor: balcony doors (*sacadas*) 1.35 × 2.9, slabs projecting 0.45 m, rails 0.95. Above: sill windows 1.35 × 2.2 at sill 0.9.
  - Shop doors 1.35 × 3.0, or an arched 1.8.
  - Stone frames 0.2 wide and 3 cm proud.
  - Roof 27°. Fire walls 0.5 thick standing **0.6 m** above the roof with a tile cap, on the sides `fire_walls` names.
  - Enterable: rooms 2.7 or 5.4 × 4.5; two flights per storey on the axis, 1.0 wide.

- [ ] **Step 1: Write the failing tests:**

```python
def test_four_bays_are_12_7_wide(self):      # 2*1.6 + 7*1.35 == 12.65 before the snap; the lot 13.0
def test_a_fire_wall_stands_0_6_over_the_roof(self):
def test_sacadas_on_the_first_floor_only(self):
def test_a_corner_building_has_four_pitches_and_two_fronts(self):
def test_a_mansard_is_65_then_25(self):
def test_pombaline_budget(self):             # <= 2400 honest, 3600 enterable (design)
```

- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test_houses.Pombaline`, then `level.sh test`. Expected: OK.
- [ ] **Step 5: Commit** `feat(old town): the Pombaline building, generated`.

### Task 5: The patio house

**Files:**
- Create: `tools/level/kit_patio.py`
- Test: `tools/level/test_houses.py` (class `Patio`)

**Interfaces:**
- Produces `kit_patio.design(width: float, depth: float, kind: str = "small", quirk: str = "", enterable: bool = True, front: str = "whitewash", seed: int = 0) -> dict`. Values (`old_town_spain.md` kit, §2-4):
  - Kinds: `"small"` (6 × 18), `"merchant"` (10 × 25, with a mirador 2.5 × 2.5 × 3), `"corral"` (16 × 20: two floors of 3 × 4 cells, doors every 3 m along a gallery) and `"corner"` (8 × 8, a tile shrine).
  - Walls 0.5. The street front is blank: at most 15% of it open, with grilles 0.3 m proud.
  - A street door 2.2 × 3.2 with a wicket. A passage (*zaguán*) 2.0 wide that bends 90° once. An iron gate (*cancela*) 1.6 × 2.6 onto the patio.
  - The patio is **at least a quarter of the lot**, with a well-head (1.0).
  - Room ranges 4.0 deep. Galleries on 2.5 m post bays with 1.0 parapets.
  - Ground floor 4.0, upper 3.6.
  - A flat roof (*azotea*) with a 1.0 parapet and a 2 × 2 stair hut.
  - Quirks:
    - `linked`: a gap in the parapet onto the neighbour's azotea, which makes the roof highway;
    - `lookout`;
    - `bridge`: the house bridging a lane (*cobertizo*), clearance 3.6-5.0;
    - `shrine`.

- [ ] **Step 1: Write the failing tests:**

```python
def test_the_patio_is_a_quarter_of_the_lot(self):
def test_the_zaguan_bends_once(self):        # a ray from the street door's middle along the passage hits a wall before the patio
def test_the_front_is_mostly_blank(self):    # open area <= 15% of the street front
def test_the_azotea_is_walked_and_walled(self):  # a 1.0 parapet; a floor collider over the whole roof but the patio
def test_a_linked_roof_opens_to_its_neighbour(self):
def test_corral_cells_are_3_by_4(self):
def test_patio_budget(self):                 # <= 2400, merchant and corral 3600 (design)
```

- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test_houses.Patio`, then `level.sh test`. Expected: OK.
- [ ] **Step 5: Commit** `feat(old town): the patio house and the corral, generated`.

### Task 6: The tower-house

**Files:**
- Create: `tools/level/kit_tower.py`
- Test: `tools/level/test_houses.py` (class `Tower`)

**Interfaces:**
- Produces `kit_tower.design(side: float = 7.0, storeys: int = 4, kind: str = "cut", quirk: str = "", enterable: bool = False, seed: int = 0) -> dict`. Values (`old_town_porto.md` §9, `old_town_spain.md` §6):
  - Kinds: `"cut"` (cut down to its house's roof plus one floor: a parapeted platform) and `"full"` (crenellated). The landmark is `side=8, storeys=9`, about **30 m**.
  - Walls 1.0. Storeys 3.3. One room per floor; a straight stair on one wall.
  - Lancets, and corner machicolation boxes on `full`.
  - Quirks:
    - `chute`: a latrine chute 0.6 × 0.6 from the top room down to a street outlet, recorded in `climbs` as a ladder volume;
    - `dovecote`.

- [ ] **Step 1: Write the failing tests:**

```python
def test_the_landmark_stands_30_m(self):     # design(8, 9, "full")["size"][1] within 29-32
def test_a_cut_tower_is_a_platform(self):    # its top is a floor collider with a parapet; a route walks across it
def test_the_chute_climbs_from_the_street_to_the_top_room(self):
def test_tower_walls_are_1_m(self):
def test_tower_budget(self):                 # <= 1600, the landmark 2400 (design)
```

- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test_houses.Tower`, then `level.sh test`. Expected: OK.
- [ ] **Step 5: Commit** `feat(old town): the tower-house, cut down or full, with its chute`.

### Task 7: Terraces, stairs and the ground below

**Files:**
- Create: `tools/level/kit_terrace.py`
- Test: `tools/level/test_terrace.py`

**Interfaces:**
- Produces registered piece catalogues, named by their parameters. The layout picks a name and the kit registers it on demand (the `CATALOGUE` lists every one the old town's lot plan asks for):
  - `retaining_<length>_<height>`: granite with a 0.05 batter and a coping; `_parapet` adds a 1.0 parapet.
  - `stair_lane_<width>_<steps>`: widths 1.2, 1.5, 2.5 and 3.0; risers 0.18, treads 0.32; flights of 6-12 steps with 2 × 2 landings between.
  - `ramp_<width>_<length>_<rise>`
  - `arch_over_<span>`: a house over a lane, span 2.5, clear 2.2, after `ArchHouse_Over`.
  - `vault_<width>_<height>_<length>`: the vaulted stream (with a 0.8 walkway ledge) and the sewer (2.2 × 3.1).
  - `cistern_<length>` (a 3.0-wide vault)
  - `grate_hatch` (an entrance from the street, its ladder in `climbs`)
- Produces `kit_terrace.retaining(length, height, parapet=False) -> str`, `stair_lane(width, steps) -> str`, `vault(width, height, length, ledge=0.0) -> str` and `cistern(length) -> str`. Each returns the piece name and registers it if new.

- [ ] **Step 1: Write the failing tests:**

```python
def test_a_stair_lane_walks(self):           # route_check stairs from its foot to its head: rules.problems == []
def test_risers_are_0_18(self):
def test_a_retaining_wall_under_3_9_is_hung(self):  # its coping is a lip >= rules.LIP at <= rules.HANG
def test_the_sewer_is_2_2_by_3_1(self):
def test_an_arch_over_clears_2_2(self):
def test_a_hatch_climbs_down(self):          # its climbs volume reaches the vault's floor
```

- [ ] **Step 2: Run** `python3 -m unittest test_terrace -v`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**, then `level.sh test`. Expected: OK. Add `test_terrace` to `level.sh test`.
- [ ] **Step 5: Commit** `feat(old town): retaining walls, stair-lanes, arches over, the stream's vault, the sewer, cisterns`.

### Task 8: Street furniture, and the comet in the tiles

**Files:**
- Create: `tools/level/kit_street.py`
- Modify:
  - `tools/textures/paint.py` (`azulejo_comet`, `azulejo_king`, `azulejo_border` in `PAINTINGS`)
  - `tools/level/common.py` (`SLOT_COLOURS`)
  - `scripts/Visual/Materials.gd` (painted slots)
- Test: `tools/level/test_street.py`, `tools/textures/test_paint.py`

**Interfaces:**
- Produces pieces:
  - `corner_lamp`: a curved iron arm at **3.6 m** (design; not in the references) with two lanterns. The layout puts `light` markers of kind `lantern` with `dark_only` True at its sockets `lamp`.
  - `shrine_alminha`: a 0.6 × 0.9 niche, a votive lamp, socket `lamp`.
  - `shrine_retablo`: a 2 × 3-tile panel under a four-face little roof, a lantern at 2.5 m.
  - `panel_comet` and `panel_king`: **4 × 6 tiles of 14 cm** (0.56 × 0.84) in a one-tile frame.
  - `fountain_carmo`: four arches on Tuscan pillars over a two-step round platform, four spouts, two curved tanks.
  - `fountain_wall`: 300-500 tris.
  - `fountain_bowls`: about 400 tris.
  - Each fountain has a socket `water` where the layout puts a `noise_zone` (period 0, db 50).
- Produces paintings (ours, 32 px a tile):
  - `azulejo_comet`: blue on white, the city on its rock under a red-brown comet, tail long and curving, in a 4 × 6 panel.
  - `azulejo_king`: a crowned king as a saint, broken sword held down, a halo, in the colossus's pose.
  - `azulejo_border`: the frame strip.

- [ ] **Step 1: Write the failing tests:**

```python
def test_a_panel_is_4_by_6_tiles(self):      # the panel's tile face 0.56 x 0.84 within 0.01
def test_a_shrine_has_its_lamp(self):        # sockets["lamp"] inside the niche
def test_fountains_have_their_water(self):   # each fountain recipe has a "water" socket
def test_the_comet_and_the_king_are_painted(self):  # test_paint: PAINTINGS has both; each image is 128 x 192
```

- [ ] **Step 2: Run** both test files. Expected: FAIL.
- [ ] **Step 3: Implement.** Paint the panels in `paint.py`'s manner (`_finish`, `SCALE`), not from any photo. Add the slots to `common.SLOT_COLOURS`, and to `Materials.gd` with `"painted": true`.
- [ ] **Step 4: Run** them, then `python3 tools/textures/paint.py azulejo_comet azulejo_king azulejo_border` and look at the three images at full size. Expected: tests OK, and the images read as tile panels.
- [ ] **Step 5: Commit** `feat(old town): corner lamps, shrines, fountains, and the comet and the forgotten king in the tiles`. Commit the paintings: they are ours.

### Task 9: The tavern and the watch house

**Files:**
- Create: `tools/level/kit_tavern.py`, `tools/level/kit_watch.py`
- Test: `tools/level/test_keys.py` (classes `Tavern`, `WatchHouse`)

**Interfaces:**
- Produces pieces `tavern` (stairs quarter) and `watch_house` (the Carmo hill, built as the ruin's convent). Each design carries `doors` and `ways` (local), and `seats`, `beds` and `places` (local points for the layout's `seat`, `home` and `mark` markers).
- `tavern`:
  - 4 ways in: `door` (the street), `yard`, `window` (an upper window reached off a neighbouring roof), and `below` (the cellar from the vaulted stream).
  - The cellar's sealed door to the undercroft is a `place` named `undercroft_door`.
  - Drinkers' seats (12, design); the off-duty watchman's table is a `place`.
- `watch_house`:
  - 3 ways in: `door` (the barracks gate), `wall` (the ruin's side through the cloister), `roof` (the roof lookout).
  - The sergeant's office, the armoury, and the barracks with 4 beds (the reserve). The drum's place is a `place`.
- Both are built with `kit_town`'s walls, floors, stairs and rooms. Furniture is left to plan B2, except what a way in needs: the bar, tables to climb, the barracks beds.

- [ ] **Step 1: Write the failing tests:**

```python
def test_the_tavern_has_four_ways_of_four_kinds(self):   # ways kinds == {"door","yard","window","below"}
def test_every_way_into_the_tavern_checks(self):         # placed alone with its ways as route_checks: rules.problems == []
def test_the_watch_house_has_three_ways(self):           # {"door","wall","roof"}
def test_every_way_into_the_watch_house_checks(self):
def test_the_barracks_sleeps_four(self):
```

- [ ] **Step 2: Run** `python3 -m unittest test_keys -v`. Expected: FAIL.
- [ ] **Step 3: Implement** both kits. Lay their ways as `route_check` points with the moves the rules know (walk, stairs, mantle, hang, jump, drop, climb).
- [ ] **Step 4: Run**, then `level.sh test`. Expected: OK. Add `test_keys` to `level.sh test`.
- [ ] **Step 5: Commit** `feat(old town): the tavern and the watch house, with their ways in`.

### Task 10: The merchant's house and the chapel

**Files:**
- Create: `tools/level/kit_merchant.py`, `tools/level/kit_chapel.py`
- Test: `tools/level/test_keys.py` (classes `Merchant`, `Chapel`)

**Interfaces:**
- `merchant_house`: a Porto `ShopHouse_Merchant`, 7.5 × 20, ground + 3 + mirante.
  - 5 ways in, of three kinds: `door` (the street), `door` (the shop's), `roof` (the skylight over the stair), `roof` (the rooftop lookout) and `yard`.
  - Places: `strongbox`, `ledger_chest`, `key_place`.
- `chapel`:
  - 3 ways in: `door` (the nave), `door` (the sacristy) and `roof` (the belfry from the roofs). The household rule asks for 3 kinds, so the sacristy is entered by its window (`window`).
  - A place: `walled_altar`, the silver behind plaster (B1b breaks it).

- [ ] **Step 1: Write the failing tests:** `test_the_merchant_has_five_ways_of_three_kinds`, `test_every_way_into_the_merchants_checks`, `test_the_chapel_has_three_kinds`, `test_every_way_into_the_chapel_checks`, `test_the_merchant_keeps_his_places`.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**, then `level.sh test`. Expected: OK.
- [ ] **Step 5: Commit** `feat(old town): the merchant's house and the chapel, with their ways in`.

### Task 11: The landmark tower, the walled garden house and the upper gate

**Files:**
- Create: `tools/level/kit_landmarks.py`
- Test: `tools/level/test_keys.py` (classes `Landmark`, `Garden`, `UpperGate`)

**Interfaces:**
- `landmark_tower`: `kit_tower.design(8, 9, "full", "chute")` with its house at its foot.
  - 3 ways in: `door`, `below` (the latrine chute) and `leap` (from a neighbour's roof onto its top, a gap of at most `GAPS["jump"]`).
  - A place: `top_room`.
- `garden_house`: on the gorge rim.
  - 3 ways in: `door` (the gate), `wall` (the wall by the fig tree), `below` (the cistern channel).
  - The cistern runs on to the upper gate as the gate's **under** way.
  - A box place `wisps`, over the garden, where the gorge's corpse-lights come up (spec §16).
- `upper_gate`: a 22 m crenellated tower over a 3.5 m arch, with a postern 1.2 × 2.2.
  - Its passage door is the `gate_door` place (locked in B1b).
  - A stair inside the tower from its top down to the far side, which is the **over** way from the tower-house roof.
  - The cistern shaft comes up beyond it, the **under** way.
  - Places: `beyond` (the far side's terrace; the layout marks it `upper_gate_beyond`) and `balefire_target` (its top, where the balefire's light is aimed).

- [ ] **Step 1: Write the failing tests:** `test_the_landmark_has_three_kinds`, `test_the_leap_to_the_landmark_is_a_jump`, `test_the_garden_has_three_kinds`, `test_the_gate_is_passed_over_and_under` (two route-checked ways from the near side to `beyond`, of kinds roof and below), `test_the_gate_tower_is_22_m`.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**, then `level.sh test`. Expected: OK.
- [ ] **Step 5: Commit** `feat(old town): the landmark tower, the walled garden house and the upper gate, its ways over and under`.

### Task 12: The Carmo ruin

**Files:**
- Create: `tools/level/kit_carmo.py`
- Test: `tools/level/test_keys.py` (class `Ruin`)

**Interfaces:**
- Produces pieces `carmo_bay` (one nave bay), `carmo_apse`, `carmo_front` (the west door) and `carmo_buttress`.
  - Values (`old_town_lisbon.md` §7): **72 m** long over five bays; nave 24.64 m high; aisles 18.70; transept 33 wide; apse 15.40; three aisles; four side chapels; five flying buttresses on the south.
  - Roofless: the arches stand, two of the five nave arches whole and three broken off (design: bays 2 and 4 whole).
  - The east window's tracery is broken, and the altar stands under it.
  - The apse's design carries `places`: `altar` (where the comet's light falls) and `cloister_door` (the watch house's `wall` way).
- The pillars cast the moon's shadows on the floor (they are open-air, not roofed).

- [ ] **Step 1: Write the failing tests:** `test_the_ruin_is_72_m_long` (the bays plus the apse along the axis), `test_the_ruin_is_open_to_the_sky` (a ray straight up from the nave's floor in every bay meets nothing), `test_the_altar_stands_under_the_east_window` (the altar place is inside the apse, under the window's opening), `test_ruin_budget` (each piece under 4000, the whole under 18 000; design).
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**, then `level.sh test`. Expected: OK.
- [ ] **Step 5: Commit** `feat(old town): the Carmo ruin, roofless, its altar under the broken tracery`.

### Task 13: The ground, the lot plan and the old town's level

**Files:**
- Create:
  - `tools/level/town/__init__.py` (`Lot`, `TERRACES`, `height(x, z)`, `all_lots()`, `design_key(lot)`)
  - `tools/level/town/baixa.py`, `stairs.py`, `judiaria.py`, `carmo.py`, `upper.py` (each with `LOTS: list[Lot] = []` to start)
  - `tools/level/layouts/old_town/__init__.py` (`layout()`, `GATES`)
  - `tools/level/layouts/old_town/ground.py`
- Delete: `tools/level/layouts/old_town.py` (the stand-in)
- Modify:
  - `tools/level/kit_town.py` (`register_town()` called at the end of `kit_recipes`)
  - `tools/level/rules.py` (`door_problems`)
  - `tests/diag/diag_holes.gd` (`--district=<name>`: its levels and the massing from `Districts`, skipping the sectors its map skips; the scan's box from its bounds plus 30 m)
  - `tests/diag/diag_look.gd` (`--map=<scene>`, the harbour's map by default)
- Test: `tools/level/test_old_town.py`

**Interfaces:**
- `town.Lot`, a frozen dataclass: `name, family, x, z, y, yaw, width, depth, storeys, quirk="", enterable=False, rooms=0, lived=False, sector="", params=()`.
  - `x, z` are the front's middle and `y` the street's height there.
  - `params` holds the family's extra design arguments as `(key, value)` pairs.
- `town.design_key(lot) -> str`: the recipe name from the design fields only, e.g. `porto_45x12_s4_jetty_e2_3f9a`. Equal designs share one piece.
- `town.all_lots()` returns every quarter's `LOTS`.
- `kit_town.register_town()` registers each `design_key` once, through its family's `design`.
- `town.TERRACES` (design; spec §4.1 and §4.3):

  | Quarter | x | z | y |
  |---|---|---|---|
  | baixa | −100..15 | −73..−170 | 3.0 at the Sea Gate square, rising to 6.0 north |
  | stairs | −180..−100 | −21..−290 | terraces from 14 to 60 |
  | judiaria | 15..150 | −73..−290 | 14..55 |
  | carmo | −100..15 | −170..−290 | 20..55; the lookout terrace at **26.0**, on a 20 m wall over the Baixa's north edge |
  | upper | −180..150 | −290..−380 | 60..85; the upper gate at (−30, 85.0, −380) |

  Each quarter is a list of terrace plates, `(x0, z0, x1, z1, y)`, plus slopes. `height(x, z)` reads them.
- Sectors: `baixa_s`, `baixa_n`, `stairs_lo`, `stairs_hi`, `judiaria_lo`, `judiaria_hi`, `carmo`, `upper_w`, `upper_e`, `below` (the sewer, stream and cisterns) and `wall` (the shared edge). Each is at most about 100 m.
- `rules.door_problems(data)`:
  - every LIVE door of a placed piece has a `door` marker within 0.3 m of it, in world coordinates;
  - no `door` marker stands inside a placed house's footprint except at one of its live doors.
  - Messages: `"%s: its door at %s has no door marker"` and `"%s (door): on a shut front of %s"`.
- `layouts/old_town` places:
  - the ground (`terrain.grid` from `town.height`, with the gate passage left out as the stand-in did);
  - the shared edge (`edges.shared_edge`);
  - the four gates (`GATES` kept, their arrival heights read from `town.height`);
  - `old_town_start`;
  - every lot: `L.put(design_key(lot), ...)`, plus its door markers at its recipe's `doors`, its climbs, and a `home` marker at a bed if `lived`.

- [ ] **Step 1: Write the failing tests:**

```python
def test_the_old_town_checks_clean(self):        # rules.problems(old_town.layout(), "stage2") == []
def test_the_gates_keep_their_names(self):       # from_harbour_/to_harbour_ for sea_gate, wall_walk, guindais, west_wall; old_town_start
def test_no_slit_between_neighbours(self):       # any two lots' footprints: overlap <= 0.05 m or a gap >= 1.0 m (Review Focus 1)
def test_every_live_door_has_its_marker(self):   # a placed enterable house without its door marker -> door_problems names it (Review Focus 2)
def test_no_door_marker_on_a_shut_front(self):
def test_equal_designs_share_a_piece(self):      # two lots differing only in place -> one design_key
def test_terraces_cover_the_quarters(self):      # town.height defined (not HOLE) over each quarter's box but the passage
```

- [ ] **Step 2: Run** `python3 -m unittest test_old_town -v`. Expected: FAIL, because there is no package `town`.
- [ ] **Step 3: Implement.** Keep `GATES` as the stand-in had them, so the transitions suite and the harbour's arrivals stay paired.
- [ ] **Step 4: Run** the tests, `level.sh test`, `test_districts`, then build:

  ```bash
  tools/level/level.sh kit
  tools/level/level.sh build old_town --force
  tools/level/level.sh export old_town stage2
  tools/level/level.sh navmesh old_town
  ```

  Then run `transitions_test`. Expected: OK, and transitions 16/16.
- [ ] **Step 5: Commit** `feat(old town): the ground of five quarters, the lot plan, and the level that places it`.

### Tasks 14-18: The five quarters

Each quarter is one task with the same five steps:

1. **Tests:** add its tests to `test_old_town.py` (listed below), plus `test_the_<quarter>_checks_clean`.
2. **Run them:** expect FAIL.
3. **Lay it:** its lots in `town/<quarter>.py` and its streets, stairs, terraces, below, furniture, route checks, households, vantages, zone and sectors in `layouts/old_town/<quarter>.py`.
4. **Run, build and look:**
   - run the tests, then `level.sh test`;
   - `kit`, `build old_town --force`, `export`, `navmesh old_town`;
   - the hole scan over the quarter (`diag_holes --district=old_town`, from Task 13);
   - daylight close-up stills of its joints (`diag_look` with `--map=res://maps/old_town.tscn`), looked at full size;
   - transitions 16/16.
5. **Commit:** `feat(old town): <the quarter>`.

These rules hold in every quarter, and the rules check what they can:
- **Roof chains:** 2-3 per quarter, each 3-6 houses and 25-60 m, broken at every lane and square. Each break is crossed by a leap of at most `GAPS["jump"]`, a plank, a laundry beam, a house bridging the lane, or a pass through a house. Each chain is a `route_check` route `roof_<quarter>_<n>` with `way="roof"`. Each chain has one visible way up for the watch.
- **Terrace steps:** each has a `terrace_step` box with at least 2 public and 1-2 thief connectors as routes (`step=`, `way=`).
- **Street loops:** across the district, 3-5. A dead end ends in a view, a hatch, or a `mark` named `payoff_<n>` (B1b's loot).
- **Scouting spots:** at every stair head, square mouth and terrace edge, an unlit, parapeted `vantage`.
- **Enterable houses:** about one building in five or six, 1-3 rooms each, each offering at least two of route, view, story or reward. About a third of them are `lived`.
- **Lamps:** `corner_lamp` every 30-40 m on main lanes (lights `dark_only`). Shrines burn all night (`douse` True).
- **Landmarks:** one seen from every square and roof chain; in the district, they stand 60-120 m apart.
- **Sightlines** in the lane mazes stay under 20-25 m; lanes bend 15-40° every 3-5 lots.
- **Zones:** one per quarter, `zone` with grade `outside` (inside the key buildings, `indoors` and `cellar`).
- **Townsfolk reservations:** `home` at a bed in each `lived` house, `seat` at the tavern's seats, `work` at the tannery and at a baker's oven in the Baixa.
- **Positions:** the spec's places (gates, sealed ways) give x and z; y is `town.height` there.

| Task | Quarter (spec §4.3) | Must contain | Its tests |
|---|---|---|---|
| **14** | **The Baixa** | Pombaline blocks about 70 (N-S) × 25 m, corner buildings four-pitched, fire walls every 2-6 buildings. The main street **13.2 m** north from the Sea Gate square, secondaries **8.8**, alleys 6.6. The Rossio-like square at its head with `fountain_bowls`. The **sewer 2.2 × 3.1** under the main street with 2 hatches. The Sea Gate's arrival kept. A `panel_comet` inside the Sea Gate. Trades marked by street (`mark` `trade_gold`, `trade_silver`, `trade_cloth`) | `test_the_main_street_is_13_2`, `test_blocks_are_about_70_by_25`, `test_fire_walls_every_2_to_6`, `test_the_sewer_runs_under_the_main_street_with_two_hatches`, `test_the_sea_gate_arrival_stands_on_the_square` |
| **15** | **The stairs** | Porto houses on stair-lanes 1.2-3 m. Houses over the stairs (`arch_over`). `two_level` houses as thief's connectors. The fountain square where seven lanes meet (`fountain_wall`, `shrine_retablo`, `panel_king`). The tannery yard. The **vaulted stream** with houses on it, the tavern's cellar on it. The **tavern** (household `tavern`, ways 4). The Guindais gate and the west wall's top (kept). The slot house (`slot` quirk, a `secret` box). The bricked-up alley along the old wall (a `secret` box). The undercroft's sealed exit at about x −140, z −60 | `test_seven_lanes_meet_at_the_fountain`, `test_the_stream_is_vaulted_with_houses_on_it`, `test_the_tavern_is_entered_four_ways`, `test_two_level_houses_join_terraces`, `test_the_undercroft_is_sealed` |
| **16** | **The Judiaria** | Patio houses behind blank walls. Lanes down to about 1 m. Adarves (dead ends) gated at night (`door` with `curfew`). Cobertizos bridging lanes. The **azotea roof highway** of `linked` roofs with lookouts (two chains at least). The tenement court (a corral, `lived`, reserved). **Two iron quarter gates** 2.5 m (`door` with `curfew`). Cisterns. The east wall-walk's arrival (kept). The palace garden wall's sealed exit at x 150, z −230 | `test_the_azotea_highway_runs_house_to_house`, `test_two_quarter_gates_shut_at_curfew`, `test_lanes_narrow_to_one_metre`, `test_the_palace_is_sealed` |
| **17** | **The Carmo hill** | The **ruin** (Task 12) on its square. The **watch house** as its convent (household `watch_house`, ways 3). The dolphin fountain under its canopy (`fountain_carmo`). The **lookout terrace at 26.0** on a 20 m `retaining_..._20_parapet` over the Baixa, with benches and 1-2 lamps. A `light` of kind `comet_shaft` aimed at the ruin's altar (Task 20). A `shunned` box over the nave (its rule in B1b) | `test_the_lookout_stands_20_m_over_the_baixa`, `test_the_watch_house_is_entered_three_ways`, `test_the_altar_has_its_comet_light`, `test_the_ruin_is_on_its_square` |
| **18** | **The upper town** | The **landmark tower** (about 30 m) and cut-down towers as roof platforms. The merchants' street of tall Porto houses. The **merchant's house** (household `merchant_house`: ways 3 kinds, by its five routes). The great house on its rock. The **chapel** (household `chapel`, ways 3). The **walled garden houses** on the gorge rim (household `garden_house`, ways 3), with a `far_air` box of kind `wisps` over their gardens. The **upper gate** (Task 11) with its far terrace marked `upper_gate_beyond` and the cathedral's sealed exit beyond. The gorge's cliff stair sealed at x −180, z −326. A `mark` `balefire_target` on the gate's top | `test_the_landmark_is_seen_from_every_square` (a ray from 1.6 m over each square's middle to the tower's top meets nothing, or a vantage within 15 m sees it), `test_the_upper_gate_is_passed_over_and_under`, `test_the_gardens_have_their_corpse_lights`, `test_the_cathedral_and_the_gorge_are_sealed`, `test_every_key_building_is_entered_its_ways` |

`shunned` (Task 17) is a box marker added to `markers.py` in that task, with `label`. Its rule (no guard's station or waypoint inside) comes in B1b.

### Task 19: The massing makes room, and the harbour sees the old town

**Files:**
- Modify:
  - `tools/level/layouts/city_massing.py` (the rock round the old town, the unbuilt districts moved, the `old_town` sector removed)
  - `data/districts.json` (`old_town.proxy` → `true`)
  - `tools/level/export.py` and `tools/level/proxy.py` (`proxy.json`)
  - `scripts/Level/LevelLoader.gd` (`load_life`)
  - `scripts/Level/DistrictMap.gd` (Distance over the massing and the proxies' life)
  - `scripts/Visual/Distance.gd` (`build` over several sources)
  - `tests/city_test.gd`, `tests/transitions_test.gd`
- Test: `tools/level/test_proxy.py`, `tools/level/test_districts.py`, `tests/city_test.gd` (C-new), `tests/transitions_test.gd` (T1)

**Interfaces:**
- The massing rock's grid leaves out the old town's footprint (`keep=`). The old town's own ground fills it in the old town's map, and its proxy does in the harbour's.
- Each unbuilt district moves only as far as it must to clear the footprint (spec §4.1):
  - the cathedral's terrace north of the upper gate, at about +85 to +90;
  - the palace on the east shoulder;
  - the castle on the summit to the north-west;
  - the gorge down the west side.
  The `far_light` and `far_air` markers (the balefire on the keep, the castle's torches, the gorge's wisps) move with their districts. Each move is a ledger ruling.
- `export.write_proxy` also writes `proxy.json`: `{"sockets": [chimney sockets], "markers": [far_air and far_light markers]}`, in world coordinates.
- `LevelLoader.load_life(folder: String) -> Level` returns a Level whose `markers` and `sockets` come from that file. It has no root.
- `Distance.build(sources: Array, sea := Rect2(), sea_level := 0.0)`. `sources` are Levels (the massing, a district's own levels, the proxies' life); the old single-level calls pass `[level]`.
- `DistrictMap` builds `Distance` over `[massing] + own levels + proxies' life`.

- [ ] **Step 1: Write the failing tests:**
  - Python:
    - `test_the_massing_leaves_the_old_town_to_it`: no massing collider or terrain face inside the old town's footprint.
    - `test_the_proxy_carries_its_chimneys_and_mist`: `proxy.json` lists the old town's chimney sockets and its `far_air` boxes.
  - Godot:
    - city_test **C22**: the harbour draws the old town by its proxy, and its smoke rises from the old town's chimneys (`distance.counts().smoke >= 10`). C20 still holds.
    - T1 updated: the old town's map has no massing `old_town` node and its own ground present.
- [ ] **Step 2: Run** `level.sh test`, `suite.sh city_test` and `suite.sh transitions_test`. Expected: FAIL, because the massing still covers the footprint and there is no `proxy.json`.
- [ ] **Step 3: Implement.** Re-export `city_massing`, `city_harbour` and `old_town`, then rebake both navmeshes.
- [ ] **Step 4: Run** `level.sh test`, `city_test`, `transitions_test`, `level_test` and `state_test`. Expected: all green.
- [ ] **Step 5: Commit** `feat(city): the massing makes room for the old town; the harbour sees it, its chimneys smoking`.

### Task 20: The old town under the city's sky, with its uncanny

**Files:**
- Modify:
  - `scripts/Level/DistrictMap.gd` (the haze, comet, aurora and roofed shadow mask, and the world wall, for every district map: lift them from `maps/city.gd` if the polish merge left them there)
  - `maps/old_town.gd` (zones, the moon, real `BAKE_BOUNDS` and `HOME`, `_dress`: the balefire's wash)
  - `scripts/Level/LevelGameplay.gd` (light kind `comet_shaft`)
  - `scripts/Night/Night.gd` (`COMET_HEAD`, `COMET_COLOR` constants, shared with the shader's defaults)
  - `tools/level/markers.py` (`LIGHT_KINDS` gains `comet_shaft`)
- Create: `tests/old_town_test.gd`, `tests/old_town_test.tscn`

**Interfaces:**
- `LevelGameplay._light` kind `"comet_shaft"`:
  - a SpotLight3D placed `SHAFT_REACH = 30.0` m from its marker along `Night.COMET_HEAD` and aimed at the marker;
  - colour `Night.COMET_COLOR` (1, 0.36, 0.26), energy 3.0 (design), angle 14°, no shadow;
  - in group `comet_shafts`.
  - `DistrictMap._night_over` shows each one only while `night.comet > 0`.
- `old_town.gd` `_dress` adds `BalefireWash`:
  - a SpotLight3D at the massing's `far_light` of kind `balefire`, aimed at the `balefire_target` mark;
  - the balefire's colour as `Distance` lights it; energy `BALEFIRE_WASH 2.0` (design);
  - range = the distance + 40 m; the angle covering the upper town's towers;
  - `light_cull_mask` leaves `Layers.ROOFED` out; no shadow.
- `tests/old_town_test.gd`: steps with `--only=<step>`, as `city_test`. Checks:
  - **O1** the old town loads under its own root, every marker is made into its node (C2's logic), the navmesh comes from file, under 15 s.
  - **O2** under the city's sky: depth fog on, `night.comet == 1.0`, the moon's `shadow_caster_mask` leaves `ROOFED` out.
  - **O3** the distance: the balefire's light and pillar; the castle's torches; at least 20 smoke ribbons from the old town's own chimneys; mist; at least 3 corpse-lights inside the gardens' `wisps` box.
  - **O4** a corpse-light in the gardens, stared at, goes out and comes back (C21's logic).
  - **O5** the ruin's altar lies in the comet's light: inside the shaft's cone and range, unoccluded, red the strongest channel. With `night.comet = 0` the shaft is hidden.
  - **O6** the balefire's light reaches the landmark tower's top and the upper gate (in cone and range, unoccluded), and not the Baixa's main street.

- [ ] **Step 1: Write the failing suite** O1-O6.
- [ ] **Step 2: Run** `bash suite.sh old_town_test`. Expected: FAIL. O5 fails on an unknown light kind; O6 fails because there is no BalefireWash.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `old_town_test`, `city_test` and `transitions_test`. Expected: 6/6, and the others green.
- [ ] **Step 5: Commit** `feat(old town): the city's sky over it; the comet's red light on the ruin's altar; the balefire on its towers; corpse-lights in its gardens`.

### Task 21: The old town walked

**Files:**
- Create: `tests/walker.gd` (a RefCounted that follows a route through the controller)
- Modify: `tests/old_town_test.gd` (O13 runs `diag_holes --district=old_town` from Task 13)
- Test: `tests/old_town_test.gd` O7-O13

**Interfaces:**
- `Walker.new(player: CharacterBody3D, tree: SceneTree)`.
- `follow(points: Array) -> bool` (await). Each point is `{"at": Vector3, "move": String}`, and each move is played through the real controller:
  - walk and stairs steer, as `city_test._steer`;
  - mantle and hang face the lip and jump;
  - jump, sprint_jump and assist_jump run up and jump at the edge;
  - climb and rope face the volume (`_face_ladder`);
  - drop walks off;
  - balance walks.
  It returns true when each point is reached within 0.8 m and health has not fallen by 30 or more.
- `Walker.routes(level, filter: Callable) -> Dictionary`: route name → points, from the level's `route_check` markers.

- [ ] **Step 1: Write the failing checks:**
  - **O7** from each harbour gate's arrival, the player walks to its quarter's square.
  - **O8** each key building is entered by each of its ways (the routes with `into`): tavern 4, landmark 3, merchant 5, watch house 3, chapel 3, garden 3.
  - **O9** each roof chain (routes `way == "roof"`) is walked end to end.
  - **O10** every terrace step's thief connector is climbed.
  - **O11** each underground entrance is reached from the street and run through.
  - **O12** the upper gate is passed over and under, each reaching `upper_gate_beyond`.
  - **O13** the world is closed: ground under every 2 m column within the district plus 30 m (or a wall), and no drop-through from 4 or 7.5 m over the fronts (`diag_holes --district=old_town`).
- [ ] **Step 2: Run** `bash suite.sh old_town_test 3000000` alone. Expected: FAIL, because there is no Walker.
- [ ] **Step 3: Implement** `walker.gd`, and fix each way the walk finds wrong **in the layout or the kit, not in the walker**. Ledger each fix.
- [ ] **Step 4: Run** `old_town_test` alone. Expected: O1-O13 pass.
- [ ] **Step 5: Commit** `test(old town): every way in, roof chain, connector and the ground below walked through the controller; the world closed`.

### Task 22: Frames, load and the gates

**Files:**
- Modify: `maps/old_town.gd` (occluders, interiors' visibility range, the bench path for `--fps-report`), `tests/old_town_test.gd` (O14, O15), `tests/transitions_test.gd`

**Interfaces:**
- Facades become occluders, as the harbour's are.
- Interior contents (roofed) draw within 30 m.
- `BENCH` is the bench path: the Sea Gate, the main street, the stairs, the Carmo lookout, the upper gate.
- **O14:** at most six shadowed lights at once anywhere on `BENCH` (C14's logic).
- **O15:** the map loads in under 15 s with its saved navmesh.

- [ ] **Step 1: Write O14 and O15.**
- [ ] **Step 2: Run** them alone. Expected: they fail or pass. A pass at once is mutation-proved: drop the LightBudget's cap and O14 must fail.
- [ ] **Step 3: Measure and fix.**
  - Run the bench windowed at 1920 × 1080 on the user's Mac (`--fps-report`, as the harbour's `bench.sh`).
  - Targets: **60 fps on average, p99 under 25 ms, load under 15 s**.
  - Ledger the numbers before and after each fix.
  - Fixes in order: occluders, interiors' range, the roofed layer, the sectors' visibility ranges.
- [ ] **Step 4: Run** every suite: the short ones four at a time, the long four (and `old_town_test`) alone. Then `level.sh test`. Expected: all green. Every transitions check holds over the real old town: the gates pair, followers come through the Sea Gate onto its navmesh, memory works.
- [ ] **Step 5: Commit** `perf(old town): occluders, interiors drawn near; within six shadows; loads under 15 s`.

### Task 23: Wrap-up

**Files:**
- Modify:
  - `docs/systems/world.md`: the old town, the town's grammar, the lot plan, the key buildings, the uncanny touches, how to walk it (`Godot --path . res://maps/old_town.tscn`, or the mission from the harbour)
  - `docs/systems/development.md`: map rows, `old_town_test`, `diag_holes --district`
  - `tools/level/level.sh` usage
  - memory (`canal-quarter-mission-program.md`, `MEMORY.md`)

- [ ] **Step 1: Write the docs.**
- [ ] **Step 2: Run everything:** `level.sh test`; every Godot suite four at a time; the long four and `old_town_test` alone. Expected: all green, with no script errors.
- [ ] **Step 3: One fresh review** of the whole branch on the most capable model, with this plan's Review Focus. Fix what it finds with failing tests first, then run everything again.
- [ ] **Step 4: Commit, and ask the user** before merging (superpowers:finishing-a-development-branch). The user walks the old town empty. Plan B1b, the night, follows their review.

```bash
git add docs/systems/world.md docs/systems/development.md tools/level/level.sh
git commit -m "docs(old town): the shell: generators, lot plan, key buildings, quarters, the uncanny, the suite"
```
