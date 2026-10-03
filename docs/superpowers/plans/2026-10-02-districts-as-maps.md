# Districts as Maps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each district of the city becomes its own map, joined to the others by loading transitions at its real gates, remembering what the player did there, with its navmesh baked offline; the harbour is the first district and a bare stand-in old town the second.

**Architecture:** A district registry (`data/districts.json`) is read by both the Python level pipeline (its new cross-district rules) and Godot. `maps/city.gd`'s flow is lifted into a `DistrictMap` base that every district's map extends; a `Mission` scene holds the current map and swaps it at a gate, while a `CityState` autoload keeps each district's state (captured from every changeable node's `save_state()`), the player's carried state and the watchmen following him through. Each district exports a low-poly proxy the other maps draw far off; the shared city wall is laid into both levels by the same code; the navmesh is baked by a headless step and loaded from file when its source hash matches.

**Tech Stack:** Godot 4.5.1 (GDScript), Blender 5.2.2 (bpy) with Python 3 for the level pipeline (`tools/level`).

**Spec:** `docs/superpowers/specs/2026-10-02-old-town-design.md` (sections 3A, 4.5, 9, 11, 12, 14.1). The program spec it amends: `docs/superpowers/specs/2026-09-28-city-on-the-rock-design.md`.

## Global Constraints

- Godot: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`; suites run `--headless --fixed-fps 60 --quit-after 40000 --path . res://tests/<suite>.tscn` and print `N pass, 0 fail`; the long suites (cinema, intruder, showcase, talk) are run one at a time with `--quit-after 3000000`.
- Blender: `/Applications/Blender.app/Contents/MacOS/Blender` (via `tools/level/level.sh`). A full harbour build and export takes about 22 minutes.
- Work in a worktree of its own: branch `old-town` from the commit that adds this plan (`0d8ad0d` or later on `city-harbour`) at `.claude/worktrees/old-town`. Another session polishes the harbour, uncommitted, in `.claude/worktrees/city-harbour`; before Task 9 merge `city-harbour` into `old-town` if it has new commits.
- The repository is public: never commit textures.com photos or anything rendered from them (`textures/source`, `textures/ps2` stay gitignored; stills showing them stay out of git).
- `maps/garrison.gd` and the garrison level are not modified; every garrison suite still passes.
- Comments and docstrings follow the codebase: prose sentences saying what a thing does; `snake_case`; GDScript `##` doc comments.
- Marker names are unique across all districts' levels. Gate names: a district's exits keep their names (`exit_sea_gate`, ...); arrivals are `from_<district>_<gate>`; the stand-in old town's exits are `to_harbour_<gate>`; its spawn is `old_town_start`. A map finds its spawn by kind (`spawn`), not by name.
- An exit's `to` names a registry district (a built one: the player travels) or an unbuilt one (sealed: a caption, as today).
- Held and shouldered things are set down at the gate in the district they came from; only purse, tools, keys and health travel.
- The worktree guard refuses compound shell commands and `git -C`: write multi-step commands as scripts in the plan's workspace and run them plainly.

## Review Focus

1. **Arriving and walking straight back:** the arrival lies outside the destination's exit box and exits ignore the player for `GRACE` (1.0 s) after arrival, so a player who stands still or turns round does not ping-pong. Pinned in Task 11 (T6).
2. **Leaving with a body on the shoulder or an item in hand:** it is set down at the exit in the district it came from and is found there on return. Pinned in Task 11 (T9).
3. **A follower knocked out in the destination, then the player goes home:** the home district does not respawn him; his body stays where it fell. Pinned in Task 11 (T11).
4. **A stale saved navmesh** (the level re-exported since the bake): the map bakes live and says so; it never uses a navmesh from another export. Pinned in Task 8 (K25) and Task 10 (T2).
5. **A pickup knocked about but not taken:** restored where it lay, not at its marker. Pinned in Task 5 (S3).

---

### Task 1: The district registry, gate markers and cross-district rules

**Files:**
- Create: `data/districts.json`
- Create: `tools/level/districts.py`
- Create: `tools/level/test_districts.py`
- Modify: `tools/level/markers.py` (SCHEMA: `arrival`; `exit` gains `to`, `arrive`)
- Modify: `tools/level/rules.py` (`STANDING` gains `"arrival"`; new `district_problems`)
- Modify: `tools/level/level.sh` (`test` runs `test_districts.py`)

**Interfaces:**
- Produces: `data/districts.json` = `{"start": "harbour", "districts": {"harbour": {"map": "res://maps/city.tscn", "levels": ["city_harbour"], "massing": "", "proxy": true}, "old_town": {"map": "res://maps/old_town.tscn", "levels": ["old_town"], "massing": "old_town", "proxy": false}}, "unbuilt": ["cathedral", "palace", "gorge", "undercroft", "aqueduct", "castle"]}`.
- Produces: `districts.load(path=districts.PATH) -> dict`; `districts.district_of(registry: dict, level: str) -> str | None`.
- Produces: `rules.district_problems(registry: dict, datas: dict) -> list[str]` where `datas` maps a level name to its level data (as `layout()` returns it); one sentence per problem.
- Produces: marker `arrival` (`required: []`, `optional: {"label": ""}`, point); `exit` optional `to: ""`, `arrive: ""`.

- [ ] **Step 1: Write the failing tests** in `tools/level/test_districts.py` (helpers `piece`/`marker`/`good` as in `test_rules.py`):

```python
REG = {"start": "a", "districts": {"a": {"levels": ["la"]}, "b": {"levels": ["lb"]}}, "unbuilt": ["gorge"]}

def test_an_arrival_stands_on_a_floor(self):
    data = good(); data["markers"].append(marker("from_x", "arrival", (0, 5.0, 0)))
    self.assertTrue(any("from_x" in p and "no floor" in p for p in rules.problems(data)))

def test_an_exit_to_a_district_needs_its_arrival(self):
    la, lb = level("la"), level("lb")
    la["markers"].append(marker("exit_x", "exit", (0, 1, 0), {"label": "b", "to": "b", "arrive": "from_a_x"}, size=[2, 2, 2]))
    found = rules.district_problems(REG, {"la": la, "lb": lb})
    self.assertTrue(any("exit_x" in p and "from_a_x" in p for p in found), found)
    lb["markers"].append(marker("from_a_x", "arrival", (0.5, 0, 0.5)))
    self.assertEqual(rules.district_problems(REG, {"la": la, "lb": lb}), [])

def test_an_exit_to_no_district(self):        # to "atlantis" -> a problem naming 'atlantis'
def test_an_exit_to_an_unbuilt_district_is_sealed(self):   # to "gorge", no arrive -> []
def test_an_exit_to_a_built_district_without_arrive(self): # to "b", arrive "" -> a problem
def test_names_are_unique_across_districts(self):          # "Inigo" in la and lb -> "Inigo: in la and lb"
def test_the_registry_names_levels_with_layouts(self):     # every level in districts.load() imports from layouts/
```
(`level(name)` returns `good()` with its `"level"` set and every marker renamed `name + "_" + marker name`, so the fixtures share no names.)

- [ ] **Step 2: Run them to see them fail**

Run: `python3 tools/level/test_districts.py`
Expected: FAIL/ERROR: `no marker called 'arrival'`, `module 'rules' has no attribute 'district_problems'`, `No module named 'districts'`.

- [ ] **Step 3: Implement** the registry file and `districts.py` (`PATH` = repo root `/data/districts.json`, found from `__file__`), the schema entries, `"arrival"` in `STANDING`, and `district_problems`: every `exit` whose `to` is non-empty must name a key of `registry["districts"]` or an entry of `registry["unbuilt"]`; one naming a district must carry `arrive`, and some level of that district in `datas` must have an `arrival` of that name; every marker name appears in one level only (across all of `datas`). Add `python3 "$HERE/test_districts.py"` to `level.sh test`.

- [ ] **Step 4: Run them to see them pass**

Run: `python3 tools/level/test_districts.py` then `python3 tools/level/test_rules.py`
Expected: `OK` both (the rules' 40 still pass).

- [ ] **Step 5: Commit**

```bash
git add data/districts.json tools/level/districts.py tools/level/test_districts.py tools/level/markers.py tools/level/rules.py tools/level/level.sh
git commit -m "feat(city): a district registry, arrivals and exits that lead somewhere, checked across districts"
```

---

### Task 2: The shared edge, the stand-in old town and the harbour's gates

**Files:**
- Create: `tools/level/edges.py`
- Create: `tools/level/layouts/old_town.py`
- Modify: `tools/level/layouts/harbour/markers.py` (the four old-town exits gain `to`/`arrive`; four arrivals)
- Modify: `tools/level/test_districts.py`

**Interfaces:**
- Consumes: Task 1's registry, `district_problems`, `arrival`.
- Produces: `edges.SHARED_EDGE` = `("city_wall_12_3", "city_wall_12_6", "city_wall_12_corner", "city_wall_12_postern", "gate_front", "gate_passage_16", "tower_drum_8", "wall_stair_12")`; `edges.shared_edge(data: dict) -> list[dict]` (the pieces of `data` whose kind is in `SHARED_EDGE`, as copies with their sector set to `"wall"`).
- Produces: `layouts/old_town.py: layout() -> dict` (level `"old_town"`), with these markers:

| Gate | Harbour exit (existing) gains | Harbour arrival (new, yaw) | Old town arrival (yaw) | Old town exit back (box) |
|---|---|---|---|---|
| Sea Gate | `to: old_town, arrive: from_harbour_sea_gate` | `from_old_town_sea_gate` (−55, 2.5, −62), 180 | `from_harbour_sea_gate` (−55, 2.5, −98), 0 | `to_harbour_sea_gate` (−55, 3.7, −80) [4, 2.4, 2], `arrive: from_old_town_sea_gate` |
| Wall-walk | `arrive: from_harbour_wall_walk` | `from_old_town_wall_walk` (151.2, 14.5, −64), 180 | `from_harbour_wall_walk` (148, 14, −78), 0 | `to_harbour_wall_walk` (151.2, 15.7, −73) [3, 2.4, 2] |
| Guindais | `arrive: from_harbour_guindais` | `from_old_town_guindais` (−184.5, stair top, −85), 180 | `from_harbour_guindais` (−172, ground, −91), −90 | `to_harbour_guindais` (−177, ground + 1.2, −91) [2, 2.4, 3] |
| West wall | `arrive: from_harbour_west_wall` | `from_old_town_west_wall` (−179.2, wall top, −109.4), 180 | `from_harbour_west_wall` (−179.2, wall top, −119.9), 0 | `to_harbour_west_wall` (−179.2, top + 1.2, −114) [3, 3, 3] |

(Every harbour exit in the table carries `to: old_town`, and every old-town exit `to: harbour` and `arrive: from_old_town_<gate>`. Heights marked "ground", "stair top" or "wall top" are found by the rules' floor check; place each on the floor it reports.) `exit_river` gets `to: gorge`, `exit_undercroft` gets `to: undercroft` (sealed). The stand-in's ground is one terrain grid over x −180…150, z −73…−380 at 5 m cells with the massing's terrace height (`city_massing._town`), the Sea Gate's square (x −75…−35, z −91…−115) at 2.5, and no quads over the gate passage's footprint (x −58…−52, z −75…−91: the height function returns a sentinel that `keep` drops); the shared edge from `edges.shared_edge(city_harbour.layout())`; spawn `old_town_start` on the square; no guards.

- [ ] **Step 1: Write the failing tests** (append to `test_districts.py`):

```python
def test_the_shared_edge_is_the_wall_and_the_gate(self):
    pieces = edges.shared_edge(city_harbour.layout())
    kinds = {p["piece"] for p in pieces}
    self.assertTrue({"gate_front", "gate_passage_16", "tower_drum_8", "city_wall_12_6"} <= kinds)
    self.assertFalse(kinds & {"wall_granite_4", "gold_stage_1", "fort_tower"})  # the passage's closing wall, the towers
    self.assertTrue(all(p["sector"] == "wall" for p in pieces))

def test_the_old_town_stand_in_checks_clean(self):
    self.assertEqual(rules.problems(old_town.layout(), "stage2"), [])

def test_the_city_checks_clean_across_districts(self):
    datas = {m.layout()["level"]: m.layout() for m in (city_harbour, city_massing, old_town)}
    self.assertEqual(rules.district_problems(districts.load(), datas), [])

def test_every_gate_leads_back(self):
    # each harbour exit to the old town arrives where an old-town exit leads back to a harbour arrival
```

- [ ] **Step 2: Run them to see them fail**

Run: `python3 tools/level/test_districts.py`
Expected: ERROR `No module named 'edges'` / `'old_town'`.

- [ ] **Step 3: Implement** `edges.py`, `layouts/old_town.py` and the harbour's markers as in the table; adjust heights until the rules report no floor problems.

- [ ] **Step 4: Run them to see them pass**

Run: `python3 tools/level/test_districts.py` then `python3 tools/level/test_rules.py`
Expected: `OK` both (`test_the_city_layouts_check_clean` still passes).

- [ ] **Step 5: Commit**

```bash
git add tools/level/edges.py tools/level/layouts/old_town.py tools/level/layouts/harbour/markers.py tools/level/test_districts.py
git commit -m "feat(city): the wall the districts share, a stand-in old town, and the harbour's gates paired with it"
```

---

### Task 3: District proxies, then the levels built and exported

**Files:**
- Create: `tools/level/proxy.py`, `tools/level/test_proxy.py`
- Modify: `tools/level/export.py` (`write_proxy`; `export()` calls it), `tools/level/level.sh` (`test` runs `test_proxy.py`; usage)
- Generated: `assets/level/city_harbour/*`, `assets/level/old_town/*`, `assets/level/fixture/*` (each with `proxy.glb`), `assets/level/source/{city_harbour,old_town,fixture}.blend`

**Interfaces:**
- Produces: `proxy.PROXY_MIN = 1.5` (m: colliders whose largest side is under it are left out), `proxy.PROXY_TERRAIN = 0.15` (the terrain's decimation ratio), `proxy.PROXY_TRIS = 150000`; `proxy.boxes(data) -> list[tuple[geo.Box, str]]` (every collider of every piece not in `edges.SHARED_EDGE` and at least `PROXY_MIN`, with its recipe's slot); `proxy.windows(data) -> list[list[float]]` (positions of `light` markers of kind `window`).
- Produces: `assets/level/<level>/proxy.glb`: one mesh of the boxes (material `proxy`, the slots' preview colours as vertex colours), a 0.8 × 1.2 × 0.1 m box of material `proxy_lit` at each window, and each terrain decimated to `PROXY_TERRAIN` (material `proxy`, its tint as vertex colour).

- [ ] **Step 1: Write the failing tests** (`test_proxy.py`):

```python
def test_small_dressing_is_left_out(self):      # a 0.6 m crate's collider is not in proxy.boxes()
def test_the_shared_edge_is_left_out(self):     # a city_wall_12_6 piece contributes no box
def test_a_house_keeps_its_slot(self):          # a casa_a's front collider is in, with slot "azulejo_green"
def test_the_harbours_proxy_is_cheap(self):     # 12 * len(boxes(harbour)) <= PROXY_TRIS
def test_windows_are_the_window_lights(self):   # count == number of light markers of kind window
```

- [ ] **Step 2: Run them to see them fail**

Run: `python3 tools/level/test_proxy.py`
Expected: ERROR `No module named 'proxy'`.

- [ ] **Step 3: Implement** `proxy.py`, and `export.write_proxy(data, out)` (Blender: build the box mesh and windows as new objects, copy each terrain with a Decimate modifier at `PROXY_TERRAIN`, export them alone to `out / "proxy.glb"` with the same glTF options as the sectors, write its `.glb.import`, delete the temporary objects); `export()` calls it after the sectors.

- [ ] **Step 4: Run the tests to see them pass**

Run: `python3 tools/level/test_proxy.py`
Expected: `OK`.

- [ ] **Step 5: Build and export** the fixture, the harbour and the old town (a workspace script running `tools/level/level.sh all fixture`, `tools/level/level.sh build city_harbour --force`, `... export city_harbour stage2`, `... build old_town`, `... export old_town stage2`).
Expected: each prints `level: exported <level>`, `0 problems`; `assets/level/{fixture,city_harbour,old_town}/proxy.glb` exist.

- [ ] **Step 6: Commit**

```bash
git add tools/level/proxy.py tools/level/test_proxy.py tools/level/export.py tools/level/level.sh assets/level/fixture assets/level/city_harbour assets/level/old_town assets/level/source/fixture.blend assets/level/source/city_harbour.blend assets/level/source/old_town.blend
git commit -m "feat(city): every district exports a low-poly proxy of itself; the harbour and the stand-in old town built"
```

---

### Task 4: The loader skips sectors and draws proxies far off

**Files:**
- Modify: `scripts/Level/LevelLoader.gd` (`load_level` gains `skip_sectors`; new `load_proxy`, `PROXY_NEAR`)
- Modify: `scripts/Visual/Materials.gd` (slots `proxy`: vertex colour, unshaded by the vertex bake's absence; `proxy_lit`: warm emissive)
- Modify: `tests/level_test.gd` (K22, K23)

**Interfaces:**
- Produces: `static func load_level(parent: Node3D, folder: String, root_name := "Level", skip_sectors: Array = []) -> Level` (a skipped sector gets no holder, no glb, no colliders, no terrain, no markers).
- Produces: `const PROXY_NEAR := 60.0`; `static func load_proxy(parent: Node3D, folder: String, near := PROXY_NEAR) -> Node3D` (named `<level>_proxy`; every `GeometryInstance3D` under it has `visibility_range_begin = near` and casts no shadow; no collision; materials `proxy`/`proxy_lit` made by `Materials` as vertex-colour and emissive).

- [ ] **Step 1: Write the failing checks** in `level_test.gd`:
  - `K22 a level loaded skipping a sector has none of it`: `load_level(holder, "res://assets/level/fixture", "fixture_skip", ["yard"])` → no child `yard` of the root, no `StaticBody3D` named `yard_*`, `level.markers.filter(func(m): return m["sector"] == "yard").is_empty()`.
  - `K23 a proxy draws only from 60 m and never collides`: `load_proxy(holder, "res://assets/level/fixture")` → node named `fixture_proxy`; every `GeometryInstance3D` under it has `visibility_range_begin == 60.0`; no `CollisionObject3D` under it.

- [ ] **Step 2: Run to see them fail**

Run: `Godot --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/level_test.tscn`
Expected: FAIL K22 (too many arguments / yard present), SCRIPT ERROR on `load_proxy`.

- [ ] **Step 3: Implement** both.

- [ ] **Step 4: Run to see them pass**

Run: the same.
Expected: `level_test`: all pass, 0 fail (K1-K23).

- [ ] **Step 5: Commit**

```bash
git add scripts/Level/LevelLoader.gd scripts/Visual/Materials.gd tests/level_test.gd
git commit -m "feat(city): the loader leaves sectors out and draws a district's proxy only far off"
```

---

### Task 5: Every changeable thing saves and loads its state

**Files:**
- Modify: `scripts/Interaction/Door.gd`, `scripts/Interaction/Chest.gd`, `scripts/Interaction/Loot.gd`, `scripts/Interaction/KeyItem.gd`, `scripts/Interaction/ToolItem.gd`, `scripts/Visual/Torch.gd` (inherited by `LightFixture`)
- Modify: `scripts/Level/LevelGameplay.gd` (`lights`: each named after its marker, `can_douse` from `props.douse`, the torch's replacement keeps the name; `lights` returned as a name → node Dictionary)
- Create: `tests/state_test.gd`, `tests/state_test.tscn` (loads the fixture with `LevelLoader.load_level` + `LevelGameplay.build_all`, as `level_test` does)

**Interfaces:**
- Produces, on each: `func save_state() -> Dictionary` and `func load_state(state: Dictionary) -> void`. `load_state` snaps (no animation, no sound, no noise event):
  - Door: `{"open": bool, "locked": bool}` (open snaps `rotation.y` to the open target; `locked` through its setter so the doorway's nav layers follow).
  - Chest: `{"open": bool, "locked": bool}`.
  - Loot, KeyItem, ToolItem: `{"taken": bool, "transform": Transform3D}`; `taken` frees the node; otherwise `global_transform` is set and the body sleeps.
  - Torch: `{"lit": bool}` (`kindle(true)` / `put_out(&"snuff", true)`).
- Produces: `LevelGameplay.lights(...)` returns `Dictionary` name → node (the key `"lights"` of `build_all` changes type; update its users: `grep -rn '\["lights"\]' scripts maps tests`).

- [ ] **Step 1: Write the failing checks** in `state_test.gd`:
  - `S1 a door's state survives`: unlock and open the fixture's door by `frob`, wait for it to finish; `var s := door.save_state()`; rebuild the fixture; `load_state(s)` → `is_open`, `not locked`, `absf(rotation.y - open target) < 0.01` on the first frame.
  - `S2 a chest's state survives`: the same for the chest.
  - `S3 loot taken stays taken; loot knocked about stays where it lay`: take one loot (`frob`), push another 1 m; capture both (`save_state` on the live one, `{"taken": true}` for the freed); rebuild; load → the first freed, the second within 0.05 m of where it lay.
  - `S4 a doused lamp stays out`: the fixture's light (marker `douse: true`) is put out by `put_out(&"douse")`; rebuild; load → `not is_lit()`.
  - `S5 lights are named after their markers and douse as marked`: `made["lights"]` has the fixture light's marker name; two physics frames later the node under that name is valid and `can_douse` is true.

- [ ] **Step 2: Run to see them fail**

Run: `Godot --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/state_test.tscn`
Expected: SCRIPT ERROR (no `save_state`), S5 FAIL.

- [ ] **Step 3: Implement** the methods and the `lights` changes.

- [ ] **Step 4: Run to see them pass**

Run: `state_test`, then `level_test` and `city_test`.
Expected: `state_test` 5 pass; `level_test` and `city_test` still all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/Interaction scripts/Visual/Torch.gd scripts/Level/LevelGameplay.gd tests/state_test.gd tests/state_test.tscn
git commit -m "feat(city): doors, chests, pickups and lamps save and load what was done to them"
```

---

### Task 6: Guards, bodies and the player's carried things save and load

**Files:**
- Modify: `scripts/AISystem/Guard.gd` (`save_state`, `load_state`, `spec`, `restore_downed`), `scripts/AISystem/GuardBody.gd` (`save_state`)
- Modify: `scripts/Interaction/Inventory.gd` (`save_state`, `load_state`), `scripts/Interaction/Props.gd` (`belt_mesh`), `scripts/PlayerController.gd` (`save_state`, `load_state`)
- Modify: `scripts/Level/LevelGameplay.gd` (`visitor`)
- Modify: `tests/state_test.gd` (S6-S9)

**Interfaces:**
- Produces, Guard: `func save_state() -> Dictionary` = `{"transform": Transform3D, "state": int, "alert": float, "has_last_known": bool, "last_known": Vector3, "health": float}`; `func load_state(state: Dictionary) -> void` (placed with `reset_physics_interpolation()`; a `SEARCHING` guard goes on searching from `last_known`); `func spec() -> Dictionary` = `{"name", "archetype", "temperament", "look_seed", "light", "keys"}` (what `LevelGameplay.guards` set from his marker); `func restore_downed(at: Transform3D, killed: bool, discovered: bool) -> RigidBody3D` (the body as `knock_out`/`die` would leave it, at `at`, with no bark, sound, alert or signal to squads; the guard freed).
- Produces, GuardBody: `func save_state() -> Dictionary` = `{"guard": called, "dead": bool, "transform": Transform3D, "discovered": bool}`.
- Produces: `static func visitor(parent: Node3D, spec: Dictionary, at: Transform3D, scene: PackedScene) -> CharacterBody3D` (a guard from a `spec`, with no route and no stations, named `spec.name`).
- Produces, Inventory: `save_state() -> Dictionary` = `{"purse": int, "keys": Array[StringName], "belt": Array[{"id", "name", "count"}], "belt_index": int}`; `load_state(state)` rebuilds the belt with `Props.belt_mesh(id)`. Props: `static func belt_mesh(id: StringName) -> Mesh` (the mesh each item's own kit or pickup gives it: find every `add_belt_item` and belt entry; keys get the key's box; an unknown id gives `null`).
- Produces, PlayerController: `save_state() -> Dictionary` = `{"health": float, "inventory": Dictionary}`; `load_state(state)`.

- [ ] **Step 1: Write the failing checks** in `state_test.gd` (the fixture's guard):
  - `S6 a searching guard is still searching where he was`: `_engage(player stand-in)`, then let him lose the target to `SEARCHING`; save; rebuild; load → `state == SEARCHING`, `has_last_known`, within 0.1 m of where he stood.
  - `S7 a guard knocked out is a body where he fell`: `knock_out(null, true)`; capture the body's `save_state()`; rebuild; `restore_downed(saved transform, false, false)` → no guard node of that name after a frame, one node in group `bodies` with `called` == his name within 0.1 m; no `barked` emitted.
  - `S8 a visitor is a guard with no route`: `LevelGameplay.visitor(...)` with the fixture guard's `spec()` → in group `guards`, named as the spec, standing (on the navmesh) after 1 s.
  - `S9 the player's carried things survive`: a player with the starting kit, a key and 120 loot, health 63; `save_state()`; a fresh player; `load_state` → purse 120, the key held, belt ids and counts equal, every known id's mesh non-null, health 63.

- [ ] **Step 2: Run to see them fail**

Run: `state_test`
Expected: SCRIPT ERRORs (missing methods).

- [ ] **Step 3: Implement** them.

- [ ] **Step 4: Run to see them pass**

Run: `state_test`, then `stealth_test`, `bodies_test`, `interaction_test`, `combat_test`.
Expected: `state_test` 9 pass; the others unchanged.

- [ ] **Step 5: Commit**

```bash
git add scripts/AISystem/Guard.gd scripts/AISystem/GuardBody.gd scripts/Interaction/Inventory.gd scripts/Interaction/Props.gd scripts/PlayerController.gd scripts/Level/LevelGameplay.gd tests/state_test.gd
git commit -m "feat(city): guards, bodies and the player's purse, tools and keys save and load"
```

---

### Task 7: The city's memory: DistrictState and the CityState autoload

**Files:**
- Create: `scripts/Level/DistrictState.gd`, `scripts/Level/CityState.gd`, `scripts/Level/Districts.gd`
- Modify: `project.godot` (`[autoload]` adds `CityState="*res://scripts/Level/CityState.gd"`)
- Modify: `tests/state_test.gd` (S10)

**Interfaces:**
- Consumes: Tasks 5-6 (`save_state`/`load_state`, `restore_downed`, `visitor`).
- Produces: `Districts.gd`: `static func registry() -> Dictionary` (parses `res://data/districts.json`, cached), `static func entry(district: StringName) -> Dictionary`, `static func is_built(district: StringName) -> bool`.
- Produces: `DistrictState.gd` (RefCounted, static): `static func capture(parent: Node, made: Dictionary, guards: Dictionary) -> Dictionary` and `static func apply(parent: Node, made: Dictionary, guards: Dictionary, state: Dictionary) -> void`. `made` is a district's level → `build_all` dict. The state: `{"doors": {name: s}, "chests": {...}, "pickups": {name: s}, "props": {name: transform}, "lights": {name: s}, "mechanisms": {name: state string}, "guards": {name: s or {"away": true}}, "bodies": [GuardBody state], "visitors": [{"spec", "state"}]}`. A pickup or guard whose node is gone is `{"taken": true}` / downed (its body holds it); a portcullis is set through `LevelGameplay.raise`.
- Produces: `CityState` (Node): `var districts := {}`, `var carried := {}`, `var followers: Array = []`, `const FOLLOW_RANGE := 30.0`; `func begin() -> void` (a new mission: everything empty); `func leave(map: Node, exit: Area3D) -> void` and `func enter(map: Node) -> void` (Task 11 fills their followers; here they capture/apply `DistrictState` and the player's `save_state`). `map` is anything with `district`, `made`, `guards`, `player` (the `DistrictMap` of Task 9).

- [ ] **Step 1: Write the failing check** `S10 a district captured and applied is as it was left`: on the fixture, open the door, take a loot, douse the light, knock out the guard; `DistrictState.capture`; free the level; rebuild it; `DistrictState.apply` → each of the four as left (door open, loot gone, light out, a body and no guard).

- [ ] **Step 2: Run to see it fail**

Run: `state_test`
Expected: SCRIPT ERROR (`DistrictState` not found).

- [ ] **Step 3: Implement** the three scripts and the autoload.

- [ ] **Step 4: Run to see it pass**

Run: `state_test`, then `level_test`, `city_test`.
Expected: `state_test` 10 pass; the others unchanged.

- [ ] **Step 5: Commit**

```bash
git add scripts/Level/DistrictState.gd scripts/Level/CityState.gd scripts/Level/Districts.gd project.godot tests/state_test.gd
git commit -m "feat(city): the city remembers each district (DistrictState, the CityState autoload)"
```

---

### Task 8: The navmesh saved and loaded

**Files:**
- Modify: `scripts/AISystem/NavBaker.gd` (`from_file`, `save_baked`, `load_baked`, `source_hash`)
- Modify: `tests/level_test.gd` (K24, K25)

**Interfaces:**
- Produces: `var from_file := false`; `func save_baked(path: String, source_hash: String) -> Error` (a PackedScene of a Node3D holding: the land `NavigationMesh`; each `Swim_<water>` and `Doorway_<door>` region with its mesh, cost and layers; each `NavigationLink3D` with its positions, costs and metas, a ladder's or rope's `volume` saved as its node's name; the hash as meta `source_hash`); `func load_baked(path: String, source_hash: String) -> bool` (false when missing or the hash differs; otherwise rebuilds the regions and links, re-links `water.swim_region`, `door.nav_region`, `link.volume` and `volume.climb_ends` by name, sets `navigation_mesh`, `from_file = true`, `is_baked = true` and emits `baked` deferred); `static func source_hash(folders: Array, settings: Dictionary) -> String` (md5 over each folder's `<level>.json` and `.glb` files' md5s, sorted, and `var_to_str(settings)`).

- [ ] **Step 1: Write the failing checks** in `level_test.gd` (the fixture with a baker as K-checks already build it):
  - `K24 a navmesh saved and loaded is the one baked`: bake live; `save_baked("user://fixture_nav.scn", h)`; a fresh baker over the same level `load_baked(...)` → true, `from_file`, the same polygon count, the same link count by kind, the door's `nav_region` meta set, the ladder's `climb_ends` set, a `map_get_path` between two fixed points the same length within 0.01 m.
  - `K25 a stale navmesh is refused`: `load_baked(path, "another hash")` → false.

- [ ] **Step 2: Run to see them fail**

Run: `level_test`
Expected: SCRIPT ERROR (`save_baked` not found).

- [ ] **Step 3: Implement** them.

- [ ] **Step 4: Run to see them pass**

Run: `level_test`
Expected: all pass (K1-K25).

- [ ] **Step 5: Commit**

```bash
git add scripts/AISystem/NavBaker.gd tests/level_test.gd
git commit -m "feat(city): a baked navmesh saved with its links and loaded when its sources match"
```

---

### Task 9: DistrictMap, lifted out of the harbour's map

**Files:**
- Create: `scripts/Level/DistrictMap.gd`
- Modify: `maps/city.gd` (extends `DistrictMap`, keeps only the harbour's own: weather, world bounds, far ground, bats, skyline, bench marks)
- Modify: `tools/level/level.sh` (verb `navmesh <district>`: runs the district's map headless with `-- --bake-navmesh`)
- Test: `tests/city_test.gd` (unchanged; it must still pass)

**Interfaces:**
- Consumes: `Districts` (Task 7), `LevelLoader.load_level(..., skip_sectors)`/`load_proxy` (Task 4), `NavBaker.load_baked`/`save_baked`/`source_hash` (Task 8).
- Produces: `class_name DistrictMap extends Node3D`: `@export var district: StringName`; `var arrival: StringName = &""` (set before it enters the tree); `signal ready_to_play`; `var levels := {}`, `var made := {}`, `var guards := {}`, `var player: CharacterBody3D`, `var night: Node3D`, `var baker: NavBaker`, `var load_seconds := 0.0`; `func marker(marker_name: String) -> Dictionary`; `const NAVMESH_DIR := "res://assets/level/navmesh"`.
- Produces, overridable: `func _dress() -> void` (the district's own look, after its levels), `func _nav(baker: NavBaker) -> void` (home, bounds, cell, climb, islands), `func _loading_words() -> Dictionary`.
- Produces, the flow (`_ready`): open the loading screen; load the district's levels; load `city_massing` skipping this district's massing sector and those of built districts whose `proxy` is true; load those districts' proxies; `build_all`; `_dress()`; navmesh: `load_baked(NAVMESH_DIR/<district>.scn, hash)` or a live bake with `print("navmesh: %s stale or missing, baking live" % district)`; guards; the player at `arrival` (`marker(arrival)`), else `--vantage=`, else the level's first `spawn` marker (by kind); `CityState.enter(self)` if a `Mission` holds it; close the screen; `ready_to_play`. With `--bake-navmesh`: after the live bake, `save_baked` and quit.

- [ ] **Step 1: Sync** `city-harbour` into `old-town` if it has new commits; run `city_test` and note its tally (the baseline).

- [ ] **Step 2: Implement** `DistrictMap.gd` and slim `maps/city.gd` onto it (no behaviour change for the harbour); add the `navmesh` verb.

- [ ] **Step 3: Run the harbour's suite**

Run: `Godot --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/city_test.tscn`
Expected: the baseline tally, 0 fail (it prints `navmesh: harbour stale or missing, baking live` until Task 10 bakes the file).

- [ ] **Step 4: Commit**

```bash
git add scripts/Level/DistrictMap.gd maps/city.gd tools/level/level.sh
git commit -m "refactor(city): a district's map lifted into DistrictMap; the harbour's keeps only its own"
```

---

### Task 10: The stand-in old town's map and both navmeshes baked

**Files:**
- Create: `maps/old_town.gd`, `maps/old_town.tscn` (root `OldTown` Node3D, script extends `DistrictMap`, `district = &"old_town"`)
- Create: `tests/transitions_test.gd`, `tests/transitions_test.tscn`
- Generated: `assets/level/navmesh/harbour.scn`, `assets/level/navmesh/old_town.scn`

**Interfaces:**
- Consumes: Task 9.
- Produces: the old town's `_nav`: home (−55, 2.5, −100), bake bounds AABB(Vector3(−200, −12, −400), Vector3(370, 120, 340)), the harbour's cell, climb and island settings; `_dress`: the night with the harbour's defaults, no wildlife.

- [ ] **Step 1: Write the failing checks** in `transitions_test.gd` (each map instantiated alone):
  - `T1 the stand-in old town loads by itself`: the player within 1 m of `old_town_start`; a node `city_harbour_proxy`; no massing sector `old_town`; `baker.from_file`.
  - `T2 the harbour loads its saved navmesh, faster than before`: `baker.from_file` and `load_seconds < 13.8`; then with the saved file's hash meta altered in a copy, a map pointed at it bakes live (`not from_file`).

- [ ] **Step 2: Run to see them fail**

Run: `Godot --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/transitions_test.tscn`
Expected: FAIL (no `maps/old_town.tscn`; `from_file` false).

- [ ] **Step 3: Implement** the old town's map; bake both navmeshes (`tools/level/level.sh navmesh harbour`, `... navmesh old_town`).
Expected: `assets/level/navmesh/harbour.scn` and `old_town.scn` written.

- [ ] **Step 4: Run to see them pass**

Run: `transitions_test`, then `city_test`.
Expected: T1, T2 pass; `city_test` the baseline tally.

- [ ] **Step 5: Commit**

```bash
git add maps/old_town.gd maps/old_town.tscn tests/transitions_test.gd tests/transitions_test.tscn assets/level/navmesh
git commit -m "feat(city): the stand-in old town's map; both districts' navmeshes baked and loaded from file"
```

---

### Task 11: The mission: travelling through the gates, followed

**Files:**
- Create: `maps/mission.gd`, `maps/mission.tscn` (root `Mission` Node3D)
- Modify: `scripts/Level/DistrictMap.gd` (`_exits`: an exit whose `to` is built calls `Mission.travel`; one to an unbuilt district shows its caption as today; exits ignore the player for `GRACE` after arrival)
- Modify: `scripts/Level/CityState.gd` (followers chosen in `leave`, spawned in `enter`)
- Modify: `tests/transitions_test.gd` (T3-T12)

**Interfaces:**
- Consumes: Tasks 7, 9, 10; `LevelGameplay.visitor` (Task 6); `PlayerFrob.put_down_body()`/`held` (existing).
- Produces: `Mission`: `var map: DistrictMap`; `const FADE := 0.3`, `const GRACE := 1.0`; `func go(district: StringName, arrival := &"") -> void` (fade out; free the held map, if any; instance the district's map with `arrival`; add it; await its `ready_to_play`; fade in); `func travel(exit: Area3D) -> void` (sets down whatever the player holds or shoulders at the exit, `CityState.leave(map, exit)`, then `go(exit's to, exit's arrive)`); `_ready`: `CityState.begin()`, `go(Districts.registry()["start"])`.
- Produces, followers: in `leave`, every guard of the map in `COMBAT` with the player as target, not downed, within `FOLLOW_RANGE` (flat) of the exit, is recorded as `{"spec": g.spec(), "to": district, "arrive": arrival, "delay": distance / g.chase_speed}` and marked `{"away": true}` in his own district; in `enter`, each follower for this map is made with `LevelGameplay.visitor` at the arrival after its delay and `_engage(player)`; he is then one of this district's `visitors` in its state.

- [ ] **Step 1: Write the failing checks** in `transitions_test.gd` (a `Mission` instanced as a child; the player put into an exit's box to use it):
  - `T3 the Sea Gate leads to the old town and back`: through `exit_sea_gate` → `map.district == &"old_town"`, the player within 1 m of `from_harbour_sea_gate` facing north (±10°); through `to_harbour_sea_gate` → harbour, at `from_old_town_sea_gate`.
  - `T4 all four gates pair both ways`: the same for the wall-walk, Guindais and west wall.
  - `T5 the purse, tools, keys and health travel`: purse +50, a flask used, a key taken, health 70 before the gate → equal after.
  - `T6 standing still on arrival does not send him back`: arrive, wait 3 s → still in the old town.
  - `T7 the harbour remembers`: take a loot, open a door, douse a lamp (one marked `douse`), go to the old town and back → all three as left.
  - `T8 a guard knocked out stays down`: knock out Inigo, travel out and back → no guard Inigo; a body named Inigo within 0.5 m of where he fell.
  - `T9 a body on the shoulder is left at the gate`: shoulder a knocked-out guard, travel → the player holds nothing in the old town; back in the harbour the body lies within 3 m of `exit_sea_gate`.
  - `T10 a chasing watchman follows through the gate`: a guard engaged on the player within 20 m of the Sea Gate, travel → in the old town within 10 s a guard of his name is in `COMBAT` within 15 m of `from_harbour_sea_gate`; the harbour's state marks him `away`.
  - `T11 a follower knocked out in the old town is not raised at home`: knock the follower out in the old town, travel home → no guard of his name in the harbour.
  - `T12 a sealed way says where it goes`: `exit_river` shows the caption "On to the gorge (the river)" and does not travel.

- [ ] **Step 2: Run to see them fail**

Run: `transitions_test`
Expected: T3-T12 FAIL (no `maps/mission.tscn`).

- [ ] **Step 3: Implement** the mission, the exits' wiring and the followers.

- [ ] **Step 4: Run to see them pass**

Run: `transitions_test`, then `city_test`, `state_test`, `level_test`.
Expected: `transitions_test` 12 pass; the others unchanged.

- [ ] **Step 5: Commit**

```bash
git add maps/mission.gd maps/mission.tscn scripts/Level/DistrictMap.gd scripts/Level/CityState.gd tests/transitions_test.gd
git commit -m "feat(city): the mission travels between districts through their gates, remembered and followed"
```

---

### Task 12: Wrap-up

**Files:**
- Modify: `docs/systems/world.md` (district maps, the registry, `CityState` and the save contract, proxies, the saved navmesh, `level.sh navmesh`), `tools/level/level.sh` usage, the docstrings of every changed module
- Modify: memory (`canal-quarter-mission-program.md`, `MEMORY.md`)

- [ ] **Step 1: Write the docs**: what each new piece does and how to run the mission (`Godot --path . res://maps/mission.tscn`).

- [ ] **Step 2: Run everything**

Run: `tools/level/level.sh test`; every `tests/*_test.tscn` four at a time; the long four alone.
Expected: every Python test OK; the guard test 10/10; every Godot suite 0 fail, no script errors.

- [ ] **Step 3: One fresh review of the whole branch** on the most capable model (superpowers:requesting-code-review), with this plan's Review Focus; fix what it finds with failing tests first; run everything again.

- [ ] **Step 4: Commit and ask the user** before merging (superpowers:finishing-a-development-branch); plan B1 (the old town playable) follows the user's review.

```bash
git add docs/systems/world.md tools/level/level.sh
git commit -m "docs(city): districts as maps, the city's memory, proxies and the saved navmesh"
```
