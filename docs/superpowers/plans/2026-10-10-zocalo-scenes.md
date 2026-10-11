# The Zócalo's scenes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Zócalo's spacing-rule life with staged scenes (posed stand-ins, props, ambient effects), a planted garden and trees, switched by day and night, so the district feels alive before buildings and NPCs exist.

**Architecture:**
- Three new Blender kits follow the family pattern (`common.Mesh(outward=True)`, `shell()`, `shapes.py`, `export_piece(sets_each=True, out=kit)`): `figures_kit` (mannequins, dogs, a pigeon), `trees_kit` (trunks and leaf cards, the garden's iron), `scene_kit` (the scenes' props).
- A scene catalogue (`tools/level/scenes_catalogue.py`, data) and a director (`tools/level/dress_scenes.py`) add scenes, stations, emitters, trees and the garden to `dressing.json` after `dress_life`'s rules, which lose their life placements.
- Godot: KitLoader draws by time of day and gives leaf cards the foliage shader; a new `Ambient.gd` runs the effect emitters through the existing `FireParticles`/`FlameFx`; `Pigeons.gd` keeps the plaza's flocks; `zocalo.gd` gains the F1 scene labels.

**Tech Stack:** Blender 5.2 bpy/bmesh, Python 3 + numpy + Pillow, Godot 4.5.1 GDScript.

**Spec:** `docs/superpowers/specs/2026-10-10-zocalo-scenes-design.md` (approved Oct 10 2026). It follows the street-life plan (`docs/superpowers/plans/2026-10-10-zocalo-street-life.md`), whose Task 8 and final review were held for this plan and run as its Task 7.

## Global Constraints

- **Pieces built right:** closed solid meshes built per shell; no same-facing faces within 3 cm; no face under 1 cm thin; no shared atlas texels; walk-tested; stills sent per kit; brush strokes colour-only. Leaf cards are the one exception (Ruling 1).
- **Blank canvases:** every word, picture or glyph surface (ex-votos, the canary's cards, typed letters, newspapers, the reporters' pads) is a `sign` slot for the user.
- **Colour carries meaning:** marigold `#F2A20C`/`#D9660A` the dead's; cyan-white `#CFE8F0` the wards'; oxblood `#6E1F1A` the gods'; phosphor green `#7FD36A` the seeped. Nothing else wears them.
- **Stand-ins read as placeholders:** plain clay grey `#9A958C`, faceless.
- **Repo is public:** only CC0 or self-made textures; no downloaded VFX (every sprite drawn by `tools/textures/paint.py` or `tools/props/flames.py`).
- **Scenes, not sprinkles:** no life piece is placed by a spacing rule over a lane; every scene records its site's reason and its story.
- **Budgets:** figures 600-900; trees 120-180; scenes 120-160; emitters ≤ 220 placed, ≤ 40 running; dressed fps within 10% of the street-life dressing's dressed number.
- **Commits:** one per task (more allowed), never pushed; each ends `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Defects:** never call a visual defect harmless.

## Rulings carried in

1. **Canopies are leaf cards, not closed shells.** The repo's foliage pipeline (`scripts/Visual/foliage.gdshader`, our painted `textures/painted/leaf_crown.png`, `palm_frond.png`, `twigs.png`, `laundry.png`, wind through `Materials.blow`) cuts its painting out of two-faced cards; cut-out on closed shells would show their insides. Leaf and laundry slots are exempt from the closed, 3 cm and 1 cm gates, and their UVs span their own painting outside the atlas (`export_piece(..., cards=(...))`). Cost if wrong: the canopies look like the harbour's trees.
2. **Effects reuse what exists.** Steam, smoke and embers are `FireParticles` kinds (copal is smoke tinted `#ECE6DA`; mist is smoke tinted `#7FD36A`, low and slow); candle flames are `FlameFx` sheet `candle`. New `FireParticles` kinds `petal`, `leaf` and `dust` use sprites painted by `paint.py`.
3. **Time of day lives on the dressing.** Pieces, colliders, stations and emitters carry `"when": "day" | "night"` (absent means both). Day and night parts may overlap (never seen together); everything else may not.
4. **The garden's beds are ground.** Beds are dressing `ground` areas of `ground_earth`, paths `ground_cobbles` gravel stand-in, laid by the director; the plaza's flags stay round them.
5. **The idol stays a rule** (the subsidence put it there); its barrier, copal and onlookers become the `idol_surfacing` scene.
6. **Awnings stay still.** The trade kit's canopies are solid canvas in the atlas; only cards sway (leaves, laundry). Cost if wrong: a later pass weights the canopies' vertices for the wind.
7. **Kit tests** run as `Blender -b --factory-startup --python-exit-code 1 --python tools/eclipse/test_kit_bpy.py` (every kit's class; the new ones fail until their kit is built).

## Review Focus

- **A day scene and a night scene sharing a site:** the clash check and the district gate skip day-against-night pairs only; a "both" part still clashes with either. Test in Task 5.
- **A scene across the player's way:** no scene collider within 0.6 m of a street-level plan route's line, a door's front or a kerb drop. Test in Task 5.
- **The night falling on the player:** a night scene's colliders switch on only where the player is not standing inside them (held until clear). Test in Task 6.
- **The plaza at night, every effect near:** copal, candles and mist round the god; at most 40 emitters run, the nearest. Test in Task 4, fps in Task 7.
- **The walk round the god:** the devotees kneel inside 6 m on the offerings' side; Z16's loop at 7 m still passes. Checked in Task 6.

---

### Task 1: The figures kit

**Files:**
- Create: `tools/textures/recipes/eclipse/clay.json` (painted `#9A958C`, faint fingerprints of darker clay, no under).
- Create: `tools/eclipse/figures_kit.py`. Atlas 1024. `SLOTS = ["clay"]`.
  - Objects: `fig_stand`, `fig_queue`, `fig_walk`, `fig_kneel_pray`, `fig_sit_kerb`, `fig_sit_chair`, `fig_lean_wall`, `fig_push_cart`, `fig_carry_basket`, `fig_point`, `fig_crouch_inspect`, `fig_hold_lantern`, `fig_type`, `fig_dictate`, `fig_barker`, `fig_photographer`, `fig_mourner`, `fig_child`, `fig_child_held`, `fig_sleep_wall`, `dog_sit`, `dog_lie`, `dog_sniff`, `pigeon`.
  - A figure is shells per part: head (lathe), neck, torso (loft), pelvis, upper and lower arms and legs (bevelled boxes), hands and feet blocks, laid by a pose table of joint angles (`POSES = {name: {joint: (pitch, yaw, roll)}}`) on one skeleton (standing 1.70 m, child 1.15 m). Feet at the origin, the figure facing Blender -Y. Carried things belong to the scene kit, never the figure (`fig_carry_basket`'s hands are empty, raised to a basket's height).
  - `fig_child_held` is an adult with a child seated on its shoulders, one object.
- Test: `tools/eclipse/test_kit_bpy.py::FiguresKit`:
  - every object exists, closed, no degenerate triangle;
  - budgets: figures ≤ 320 triangles, `fig_child_held` ≤ 560, dogs ≤ 200, `pigeon` ≤ 48;
  - standing poses' top at 1.70 ± 0.05, `fig_child` 1.15 ± 0.05; every figure's lowest point 0 ± 1e-4 (`fig_sleep_wall` and `fig_sit_kerb` sit on 0);
  - no part through another (the gate's layered and sliver checks clean).
- [ ] Write the test, run it: `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python tools/eclipse/test_kit_bpy.py` → FAIL (no figures_kit).
- [ ] Build (`tools/eclipse/lab.sh figures_kit`, gate clean), paint (`python3 tools/textures/eclipse_atlas.py figures_kit`), test → PASS.
- [ ] Stills: `kit_stills --kit=figures_kit`; look at every pose; send to the user.
- [ ] Commit `feat(kit): the figures kit: posed clay stand-ins, dogs and a pigeon`

### Task 2: Trees and the garden

**Files:**
- Modify: `tools/eclipse/common.py`: `export_piece(..., cards=())`: faces whose slot is in `cards` keep their UVs (0..1 over the card), leave the atlas, and are left out of the closed, layered and sliver gates; every card is two faces back to back.
- Modify: `tools/textures/paint.py`: `willow()` (hanging strands, 256×512) and `laurel()` (dense small glossy leaves, 512×512), registered with the others.
- Create: `tools/textures/recipes/eclipse/bark.json` (fissured grey-brown), `tools/eclipse/trees_kit.py`. Atlas 1024. `SLOTS = ["bark", "iron", "wood", "sign", "leaf_crown", "palm_frond", "willow", "laurel", "twigs"]`, `CARDS = ("leaf_crown", "palm_frond", "willow", "laurel", "twigs")`.
  - Objects: `tree_ash` (9 m), `tree_ash_young` (5.5 m), `palm_canary` (8 m, thick ringed trunk), `tree_laurel` (8 m, wide low crown), `tree_willow` (7 m, hanging strands), `ahuehuete_split` (12 m, trunk split to its fork, one half dead with `twigs`, eight `sign` ex-voto plates nailed at 1.4-2.2 m), `tree_guard` (iron cage 1.2 m), `garden_bench` (iron and wood), `garden_edging` (2 m iron hoops, stretchy).
  - Trunks lathed (`shapes.lathe`) with limbs lofted; crowns as cards over ellipsoids after `kit_nature._crown`'s pattern.
- Test: `test_kit_bpy.py::TreesKit`:
  - every object exists; its solid faces closed; cards two-faced;
  - budgets: trees ≤ 900, the ahuehuete ≤ 1,400, guard, bench and edging ≤ 300;
  - every trunk's foot at 0 ± 1e-4; crown cards' lowest at ≥ 2.2 m over the ground for `tree_ash`, `tree_laurel`, `palm_canary` (a man walks under);
  - `CARDS` faces' UVs inside 0..1 and not in the atlas.
- [ ] Test (FAIL), paint the two new leaf sheets (`python3 tools/textures/paint.py willow laurel`), build, paint the atlas, test (PASS).
- [ ] Joints: a tree in its guard on the plaza's flags; a bench at the edging. Stills; send.
- [ ] Commit `feat(kit): trees and the garden: ash, palm, laurel, willow, the split ahuehuete`

### Task 3: The scene kit

**Files:**
- Create: `tools/eclipse/scene_kit.py`. Atlas 1536. `SLOTS = ["wood", "iron", "brass", "canvas", "clay_pot", "wax", "marigold", "sign", "glass", "chiluca", "steel", "laundry"]`, `CARDS = ("laundry",)` (Ruling 1). Add `tools/textures/recipes/eclipse/clay_pot.json` (terracotta `#A4532E`, black soot under).
  - Objects: `barrel_organ`, `typewriter_desk`, `stool`, `chair`, `coffin_on_chairs`, `brazier`, `comal_pots`, `basket`, `baskets_stack`, `crate`, `canary_box` (cage and a card box, `sign` cards), `censer`, `lantern_carried`, `lantern_set`, `chalk_ring` (flush, 3 m, top at 0), `cart_overturned`, `crates_spilled`, `pulque_barrels`, `cart_covered`, `laundry_line` (8 m, two hooks, cloths as `laundry` cards, stretchy), `exvoto_plate`, `crate_soapbox`, `camera_tripod`, `firewood_stack`, `firewood_bundle`, `atole_pot`, `flowers_bucket`.
  - Everything rests at z 0 (the laundry line's origin is its west hook at z 0, hung at 3.2 m).
- Test: `test_kit_bpy.py::SceneKit`: closed (cards aside), no degenerate triangle; budgets props ≤ 600, `barrel_organ` and `coffin_on_chairs` ≤ 800, `typewriter_desk` ≤ 500; lowest point 0 ± 1e-4 (the line at its hooks' feet); `chalk_ring` top at 0.
- [ ] Test (FAIL), build, paint, test (PASS); stills; send.
- [ ] Commit `feat(kit): the scene kit: the street's props for its scenes`

### Task 4: Effects, ambient emitters, pigeons

**Files:**
- Modify: `tools/textures/paint.py`: `petal_sprite()`, `leaf_sprite()`, `dust_sprite()` (4 frames each, 32×32, alpha) written to `assets/vfx/petal.png`, `leaf.png`, `dust.png`.
- Modify: `scripts/Visual/Lights/FireParticles.gd`: kinds `&"petal"` (max 200, tumble and drift, marigold), `&"leaf"` (max 200, tumble, falls ~1 m/s), `&"dust"` (max 150, hangs and wanders); `steam` max 80 → 200.
- Create: `scripts/Level/Ambient.gd`: `class_name Ambient extends Node3D`.
  - `static func build(emitters: Array) -> Ambient` from the dressing's `emitters` (`{"effect", "at": [x,y,z], "when"?, "scene"}`).
  - `const EFFECTS := {"steam", "copal", "smoke", "embers", "mist", "petals", "leaves", "dust", "candles", "canal_fog"}` each mapped to a FireParticles kind, rate, size, tint and wind; `candles` makes three `FlameFx` (sheet `candle`, 0.05 m) at its spot instead.
  - `const REACH := 60.0`, `const ACTIVE := 40`: each frame (at most every 0.25 s) the nearest ≤ 40 emitters within REACH of the camera that match the time run; the rest are still.
  - `func set_day(day: bool) -> void`; `func running() -> Array` (the indices running).
- Create: `scripts/Level/Pigeons.gd`: `class_name Pigeons extends Node3D`. `static func build(flocks: Array, mesh: Mesh) -> Pigeons` from the dressing's `flocks` (`{"at", "count", "radius"}`); one MultiMesh; birds peck (bob) on the ground; within `const STARTLE := 4.0` m of the player (group `player`) a flock lifts to 6-10 m, circles, and lands again after `const AWAY := 8.0` s. `func flying(flock: int) -> bool`.
- Test: `tests/ambient_test.gd` (+ `.tscn`), headless, a synthetic dressing:
  - A1 an emitter 10 m from the camera runs, one at 80 m does not;
  - A2 with 100 emitters within 30 m, `running().size() == 40` and they are the nearest;
  - A3 a night emitter is still by day and runs at night;
  - A4 copal emits smoke tinted `#ECE6DA`; mist emits low (spawn y ≤ at.y + 0.3);
  - A5 a flock lifts when the player stands 3 m off and lands after 8 s with the player gone;
  - A6 petal, leaf and dust kinds draw their sprites.
- [ ] Test (FAIL), paint the sprites, implement, test (PASS); `tests/lights_test.tscn` still passes.
- [ ] An effects still (a test scene with every effect side by side, day and night); send.
- [ ] Commit `feat(fx): the street's ambient effects and the plaza's pigeons`

### Task 5: The scene director

**Files:**
- Create: `tools/level/scenes_catalogue.py`: `@dataclass Recipe(name, sites, when, story, pieces, figures, emitters, spacing=80.0, landmark=None, variant_of=None)`; parts in the scene's frame (front +Z toward the street, metres): `pieces: [(piece, (x, z), turn)]`, `figures: [(pose, (x, z), turn, role)]`, `emitters: [(effect, (x, y, z))]`. `RECIPES`: every scene in the spec's two tables (31 names, plus night and day variants named `<name>_night` / `<name>_day` with `variant_of`), their parts drawn from the three new kits and the street-life kits, counts within the spec's ranges.
- Create: `tools/level/dress_scenes.py`:
  - `@dataclass Site(kind, at, facing, reason, zone)`; `KINDS = ("tram_stop", "metro_mouth", "god_ring", "hall_door", "landing", "church_steps", "arcade", "street_mouth", "plot_door", "wall_foot", "corner", "dark_spot", "subsidence", "sealed_hatch", "claw_slab", "rails", "plaza_edge", "madero", "market")`.
  - `sites(d: dress.Dresser, life: dress_life.Life) -> list[Site]` from the plan (landmarks, plots and their families, ground, events) and the rules' dressing (lamps for dark spots, hatches, claw slabs, the idols, the tram loop).
  - `zone(d, x, z) -> str` one of `plaza`, `hall`, `madero`, `side`, `lane_end`, `other` (the spec's zone table; `lane_end` is market ground over 90 m from the market hall's centre).
  - `DENSITY = {"plaza": 25.0, "hall": 25.0, "madero": 40.0, "side": 60.0, "lane_end": None}`, `APART = 15.0`.
  - `scenes(d, life, seed=1921) -> None`: landmarks first, then fill zones; a scene is placed only if every part fits (`life.fits`), else none of it; writes `d.scenes`, `d.stations`, `d.emitters`, `d.flocks` and its pieces and colliders (figures, dogs, props with a footprint ≥ 0.3 m collide as boxes; cards, chalk and petals do not).
  - `garden(d, life) -> None`: the plaza's four quarters round the god's ring as beds (Ruling 4) with edging, paths from the four Metro corners to the ring, benches along the paths, trees in guards (ash and palms), laurels at the market hall's doors, willows along the canal's copings every 18-24 m, ash in side streets ≥ 12 m wide every 20-30 m, the ahuehuete by the dig's north-west pit; 3 pigeon flocks on the plaza; `canal_fog` emitters (night) every 30 m along the canal; `dust` emitters (night) under one lit lamp in four; `leaves` emitters in every third tree's crown.
- Modify: `tools/level/dress_life.py`: `Life.fits(piece, x, z, yaw, when=None) -> bool` (the check `put` makes, without placing); `put(..., when=None)` records `when` on the piece and its collider; the clash check ignores day-against-night pairs (Ruling 3); `life()` no longer calls `market()`, `shoeshine()`, `candles()`, `dark()`, and `plaza_life()` no longer lays the edge kiosks, the Metro-corner news kiosks, the booths or the poster columns' market set; `idols()` lays only the idol.
- Modify: `tools/level/dress.py`: `KITS` gains `figures_kit`, `trees_kit`, `scene_kit`; `dress()` runs `dress_scenes.garden` then `dress_scenes.scenes` after `dress_life.life` and returns `scenes`, `stations`, `emitters`, `flocks`; `gate()` skips day-against-night pairs.
- Modify: `tools/level/test_dress_life.py`: `test_density` drops the cart and kiosk counts; a new `test_no_life_by_rule`: the rules alone (`dress_life.life` on a fresh dresser) place no cart, kiosk, shoeshine stand, curiosity stand, wagon, shrine, booth, crate, candles, petals or cage trap.
- Test: `tools/level/test_dress_scenes.py`:
  - `test_every_recipe_placed`: every recipe name in `RECIPES` appears in `scenes` at least once; landmarks exactly once;
  - `test_sites_accept`: each placed scene's site kind is in its recipe's `sites` and its `reason` is non-empty;
  - `test_spacing`: no recipe within its `spacing` of itself; outside `plaza` and `hall`, no two scenes within `APART` (a variant and its own at the same site excepted);
  - `test_zone_counts`: plaza ≥ 20, hall ≥ 8, madero ≥ 10, side ≥ 15, lane_end 0; total 120-160;
  - `test_whole_or_nothing`: every placed scene has all of its recipe's pieces, figures and emitters;
  - `test_stations`: one station per figure, its pose a `figures_kit` object, its `when` the scene's;
  - `test_budgets`: figures 600-900, trees 120-180, emitters ≤ 220;
  - `test_day_night_overlap_only`: overlapping parts are only ever day-against-night;
  - `test_routes_clear`: no scene collider within 0.6 m of a street-level route's line, a plot door's front or a kerb drop;
  - `test_god_ring_walkable`: no scene collider between 6.4 and 7.6 m of the god's centre;
  - `test_gate_clean`: `dress.gate` over everything is empty.
- [ ] Write the tests, run (`python3 tools/level/test_dress_scenes.py`) → FAIL (no module).
- [ ] Implement, run → PASS; `python3 tools/level/test_dress_life.py` PASS; `level.sh zocalo` writes it clean; `level.sh test` exits 0.
- [ ] A top-down map of the scenes (`plan_draw` with the scenes' dots and names) for the user.
- [ ] Commit `feat(zocalo): the scene director: staged life, the garden and its trees`

### Task 6: Scenes in Godot

**Files:**
- Modify: `scripts/Level/KitLoader.gd`:
  - groups keyed by `when` too; `func set_day(day: bool) -> void` shows the matching groups, hides the rest, and calls `set_lights(not day)`;
  - colliders carry `when`; a switched-on collider whose box holds the player (group `player`) waits until the player is clear (checked each physics frame);
  - one lit lamp in eight stutters (`scripts/Visual/Lights/Flicker.gd` on its light and globe), chosen by its position's hash;
  - surfaces of card slots (`leaf_crown`, `palm_frond`, `willow`, `laurel`, `twigs`, `laundry`) get the foliage material (`Materials._foliage`'s pattern: their `textures/painted/<slot>.png`, rustle 0.05, bough 0.02, laundry `hanging`), tracked in `Materials.swaying`.
- Modify: `maps/zocalo.gd`: builds `Ambient` and `Pigeons` from the dressing, adds a `Wind` node; `set_day` calls `kit.set_day(day)` and `ambient.set_day(day)`; F1 toggles `Label3D`s at each scene within 40 m of the camera showing `name — story` (default off).
- Modify: `tests/zocalo_test.gd`, `_scenes()`:
  - Z19 the scenes load: drawn figures equal the stations of the time of day; trees drawn equal the dressing's;
  - Z20 `set_day(false)` hides a day scene's figures and switches off its colliders, and shows a night scene's; back again by day;
  - Z21 the player walking into a tamale_stop's queue stops short of it;
  - Z22 a night collider over the player at nightfall stays off until the player steps out, then switches on;
  - Z23 the ambient runs near the camera at the god (copal running) and ≤ 40 emitters run;
  - Z23b a stuttering lamp's light energy varies over 2 s at night;
  - Z24 F1 shows a label at the nearest scene; F1 again hides it;
  - Z16 still passes (the god's ring).
- [ ] Tests (FAIL), implement, all suites (PASS): `zocalo_test`, `ground_test`, `style_lab_test`, `ambient_test`.
- [ ] Commit `feat(zocalo): scenes by day and night, effects, pigeons and the F1 labels`

### Task 7: Stills, frame rate, review

This is the street-life plan's held Task 8, over the scenes.

**Files:**
- Modify: `tools/level/layouts/zocalo/cameras.py`: the god's devotion (day, night), the evangelistas, the market hall's doors (day, night), the monster wagon, a payphone's queue at night (séance), a wake in a side street, a brazier watch at a dark end, the garden and its trees, the ring under the wires, a corner with its guard stone and plaques.
- Update the memory: `zocalo-district-project.md` and its MEMORY.md line.
- [ ] Stills day and night (`tests/zocalo_stills.gd`, windowed); look at every one for floating, buried, overlapping or stretched pieces and figures; each fault gets a failing test, then a fix.
- [ ] `--load-report` and `--fps-report=40`, dressed against `--undressed` and against the street-life dressing's number (commit `9c602cd`); explain any worst-frame drop.
- [ ] Send the stills with the open calls.
- [ ] Commit `docs(zocalo): the scenes' cameras`
- [ ] The final review over both plans (`review-package` from `5576121` to HEAD), the opus reviewer given both plans, both specs/cards and both ledgers' rulings; one fix pass; report rulings and deferred minors; delete both plans' workspaces.
