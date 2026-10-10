# The street's life and its uncanny (Zócalo family 1b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved street-life card as four painted, weathered kits. Lay them densely over the dressed Zócalo with the dresser, light the Company's lamps, walk-test, and show it in stills, day and night.

**Architecture:**
- Four Blender scripts follow family 1's pattern (`common.Mesh(outward=True)`, `shell()`, `shapes.py`, `export_piece(sets_each=True, out=kit)`):
  - `furniture_kit`: bollards, poles, wires, wards, signs, posters, seepage objects;
  - `trade_kit`: carts, kiosks, stands, booths, the monster wagon;
  - `uncanny_kit`: the god's traces, wards on the ground, El Secreto's containment;
  - `bound_god`: the placeholder god, its cage and plinth.
- A second dresser module, `tools/level/dress_life.py`, adds its placements, colliders and lamp lights to the same `dressing.json`. The district gate checks them with everything else.
- KitLoader gains glass surfaces and the Company's lamps (OmniLights) from the dressing.

**Tech Stack:** Blender 5.2 bpy/bmesh, Python 3 + numpy + Pillow, Godot 4.5.1 GDScript.

**Spec:**
- The card: `docs/superpowers/refs/mexico_city/cards/street_life.md` (approved Oct 10 2026, the uncanny in a Hellboy and Deadlock register).
- The card sits inside `docs/superpowers/specs/2026-10-10-zocalo-district-design.md`, section 5.3.
- The user said "for the God's look, let's have a basic placeholder".

## Global Constraints

- **Pieces built right:**
  - closed solid meshes, built per shell;
  - no same-facing faces within 3 cm;
  - no face under 1 cm thin;
  - no shared atlas texels;
  - budgets as the card sets them;
  - walk-tested with the real player;
  - painted stills sent per kit;
  - brush strokes colour-only.
- **Every blank canvas uses the `sign` slot:** plaques, plates, posters, notices, ward plates, tags, boards, backdrops, proofs and bills. The user paints all words, glyphs and pictures.
- **Colour carries meaning:**
  - marigold amber `#F2A20C`/`#D9660A` for the dead's;
  - cyan-white `#CFE8F0` for the wards;
  - oxblood `#6E1F1A` for the gods';
  - phosphor green `#7FD36A` for the seeped future.
  Nothing else wears them.
- **Repo is public:**
  - The `rough_linen` CC0 Poly Haven scan is fetched for canvas and burlap, credited in CREDITS.md, and kept in gitignored `textures/scans/`.
  - Never download VFX: the lamp glow and candle flames are our own geometry and emission.
- **Wires and chains** are solid and at least 3 cm across.
- **Placement:** pieces stand on the ground they belong to (y 0 street, 0.2 plaza), never floating, never buried past their foot.
- **Density:** follow the card's density table; the user's rule is "add A LOT".
- **Commits:** one per task, never pushed; each ends `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Defects:** never call a visual defect harmless.

## Rulings carried in

1. **The Bound God is a placeholder** (the user's call). It is a blocky seated figure, a cuboid head with a slab brow, eye sockets and a jaw, arms down and legs folded, 6 m. It sits inside a 4 × 4 × 7 m iron cage with chains from the cage's corners to its wrists, on a stepped 6 × 6 m chiluca plinth 1.2 m high with a blank plaque. Its offerings heap is its own piece. It stands at the plaza's middle (0, 0.2, 0), where the causeway band ends.
2. **The lamps are lit** with one OmniLight3D per lamp piece: ward-cage lamps cyan-white `#CFE8F0`, plain pole lamps the Company's `#e8d8a8`. Range 14 m, shadows off except the eight round the god. Dead lamps are unlit.
3. **Plaques, plates and poster clusters go on the greybox plots' walls** facing streets, 4 cm off them (a board, never a sticker), until the house family brings real walls. Corner plaques sit at 4.5 m on the corner's two faces.
4. **Lights and glass in KitLoader.**
   - Surfaces whose material is named `glass` get a glass material: frosted, emissive when the piece is a lit lamp.
   - The dressing gains `"lights": [{"at", "colour", "range", "shadow"}]`.
5. **`dress.kit_of` becomes a lookup** in the loaded kits' faces (a piece's kit is whichever kit holds an object of that name). Names stay unique across kits; a test checks it.
6. **Collision:**
   - box colliders for poles, bollards, carts, kiosks, booths, stands, the wagon, the god's plinth and cage, crates and hoardings;
   - none for petals, candles, discs, plaques, posters, wires or the claw-scored inlay;
   - the god itself is a mesh collider.

## Review Focus

- **Pieces near family 1's:**
  - a pole on a kerb or on the tram strip;
  - a cart over a gutter grate;
  - a hoarding across a canal landing;
  - a kiosk on a hatch.
  No overlaps, and every piece on open ground. A dresser test checks footprints against family 1's.
- **A plaque or poster board on a greybox wall:** 4 cm off, never inside the wall or floating off its end. A dresser test checks it.
- **The overhead at the curves and stops:** the trolley wire follows the track, with no span through a building. A dresser test checks it.
- **Lights' cost at night:** about 40 OmniLights. Fps reported dressed against undressed, with any worst-frame drop explained.
- **The player among the clutter:** they can still walk the ring, the plaza, the market lanes and round the god without being boxed in. A walk test covers it.

---

### Task 1: Recipes and the canvas scan

**Files:**
- Modify: `tools/textures/fetch_scans.py`: add `"rough_linen"`
- Modify: `CREDITS.md`
- Create: `tools/textures/recipes/eclipse/`, each with an `under` where it wears:
  - `wood.json`: stained_pine, warm brown, under bare grey wood
  - `canvas.json`: rough_linen, cream to umber
  - `talavera.json`: the azulejo_border recipe in its blue and white
  - `obsidian.json`: painted black, glossy, light `#3a3340`
  - `marigold.json`: painted `#F2A20C`/`#D9660A`
  - `wax.json`: painted cream `#FFD9A0`
  - `flesh.json`: painted pale waxy
  - `glass.json`: frosted grey, for the painted fallback
- Test: `tools/textures/test_eclipse_atlas.py::test_street_life_recipes`: each of the eight recipes loads; a scan, if named, is in `fetch_scans.SCANS`.

- [ ] Write the test, run it (FAIL), add the recipes, run (PASS).
- [ ] Fetch the scan: `python3 tools/textures/fetch_scans.py rough_linen`.
- [ ] Commit: `feat(look): street life's recipes and the rough_linen canvas scan`

### Task 2: Shapes for small things

**Files:**
- Modify: `tools/eclipse/shapes.py`:
  - `lathe(m, profile, sides, slot)`: a closed solid of revolution about Z from `[(r, z)]`, the ends capped as fans. For bollards, columns, candles, jars, pots and the lamp globe.
  - `sag(m, a, b, radius, sides, drop, segments, slot)`: a closed tube along a catenary-like sag from a to b dropping `drop` at its middle. For wires and chain.
- Test: `tools/eclipse/test_kit_bpy.py::Shapes`:
  - a lathed profile is closed with volume ≈ the analytic one (within 2%);
  - a sag tube is closed and its lowest point is `drop` below the line;
  - no triangle under 1e-7 m².

- [ ] Test (FAIL), implement, test (PASS), commit `feat(kit): lathe and sag shapes`

### Task 3: The furniture kit

**Files:**
- Create: `tools/eclipse/furniture_kit.py`. Atlas 1024.
  - `SLOTS = ["iron", "steel", "brass", "chiluca", "obsidian", "glass", "sign", "talavera", "wood"]`
  - Objects (the card's names):
    - `bollard_guardstone`, `bollard_cannon`, `bollard_company`, `bollard_chain_post`, `chain_span` (1.5 m), `bollard_seeped`
    - `tram_pole`, `tram_pole_lamp`, `lamp_dead`, `ward_cage_lamp`, `span_wire` (20 m, sag 0.3), `trolley_wire` (30 m, sag 0.15, hangers)
    - `ward_plate`, `sigil_disc`, `tram_stop`, `traffic_light_dead`, `payphone_seeped`, `parking_meter`, `sign_bus_stop`
    - `plaque_talavera`, `plate_street`, `poster_column`, `poster_cluster`, `notice_board`, `ward_hoarding`
  - Origins: a post's foot at its centre on the ground; a wall piece's back face at y 0, looking -Y.
  - The lamps' globes are `glass`. The ward cage's lenses are `obsidian`.
- Test: `test_kit_bpy.py::FurnitureKit`:
  - every object exists, is closed and has no degenerate triangle;
  - budgets: bollards ≤ 200, poles ≤ 400, lamps ≤ 600, wires ≤ 200, signs ≤ 150, columns and hoardings ≤ 600;
  - exported budgets the same;
  - every post stands on z 0 (min z 0 ± 1e-4, or ≤ 0 for buried feet ≤ 0.3);
  - the trolley wire's ends are at z 5.5 and its middle 0.15 lower;
  - wire and chain cross-sections are ≥ 3 cm.
- Joints: card joints 1–3, 6, 7; staged with family 1's pieces where they meet (a pole on the setts, a chain on a coping).

- [ ] Test (FAIL), build (`lab.sh furniture_kit`, clean), paint, render joints, look and fix, test (PASS).
- [ ] Shoot stills (`kit_stills --kit=furniture_kit`), send them to the user.
- [ ] Commit `feat(kit): the furniture kit: bollards, the Company's poles, wires and wards, signs and posters, the seeped future`

### Task 4: The trade kit

**Files:**
- Create: `tools/eclipse/trade_kit.py`. Atlas 1024.
  - `SLOTS = ["wood", "iron", "canvas", "brass", "glass", "sign", "flesh", "obsidian", "marigold", "steel"]`
  - Objects:
    - `cart_hand`, `cart_flower`, `cart_tamale`, `cart_ice`, `cart_firewood`
    - `kiosk_news`, `kiosk_lottery`, `kiosk_sweets`, `shoeshine_stand`
    - `booth_photographer`, `stand_curiosities`, `wagon_monster`, `shrine_luchador`, `crates_relics`
  - The jars with hands in `stand_curiosities` and the ahuízotl in `wagon_monster` are `flesh` inside `glass`, modelled as closed solids inside closed glass.
- Test: `test_kit_bpy.py::TradeKit`:
  - every object exists, is closed and has no degenerate triangle;
  - budgets: carts ≤ 800, kiosks, booths and the wagon ≤ 1,500, stands ≤ 800;
  - exported budgets;
  - every wheel touches z 0 (each piece's lowest point is 0 ± 1e-4).

- [ ] Test (FAIL), build, paint, joints (card joints 4–5), fix, test (PASS), stills to the user.
- [ ] Commit `feat(kit): the trade kit: carts, kiosks, stands, and the market's pulp`

### Task 5: The uncanny kit and the Bound God placeholder

**Files:**
- Create: `tools/eclipse/uncanny_kit.py`. Atlas 1024.
  - `SLOTS = ["basalt", "chiluca", "iron", "brass", "wood", "marigold", "wax", "sign", "glass", "obsidian", "flesh", "steel"]`
  - Objects: `idol_surfacing`, `secreto_barrier`, `claw_scored_slab` (flush inlay 1.5 × 1.5, top at 0), `petals_marigold`, `candles_drift`, `booth_line_of_dead`, `booth_testimony`, `hatch_sealed` (family 1's hatch footprint, flush), `cage_trap`, `cage_trap_chaneque`, `cage_trap_lechuza`, `offerings_heap`
  - Petals, candles and offerings are mounded solids ≥ 4 cm high (never films on the ground).
- Create: `tools/eclipse/bound_god.py`. Atlas 1024, one object of shells.
  - `SLOTS = ["basalt", "iron", "brass", "chiluca", "sign"]`
  - Ruling 1's placeholder: god, cage, chains, plinth (plaque blank).
- Modify: `tools/eclipse/street_dims.py`: `footprint("claw_scored_slab")`, `footprint("hatch_sealed")` (the hatch's).
- Test: `test_kit_bpy.py::UncannyKit` and `::BoundGod`:
  - closed, no degenerate triangles, budgets (props ≤ 600, booths ≤ 1,500, idol ≤ 1,500, the god's whole ≤ 5,000);
  - flush pieces' tops at 0;
  - petals and candles ≥ 4 cm high;
  - the god's plinth top at 1.2, the god inside the cage's box (no part through the bars);
  - the cage's door side open 1.2 m wide at the offerings' side (the user's player can reach the heap).

- [ ] Test (FAIL), build, paint, joints (card joints 8–12), fix, test (PASS), stills to the user.
- [ ] Commit `feat(kit): the uncanny kit and the Bound God placeholder`

### Task 6: The street-life dresser

**Files:**
- Create: `tools/level/dress_life.py`. `life(dresser) -> None` adds to a `dress.Dresser`'s pieces, colliders and a new `lights` list, following the card's density table. Its rules:
  - **Guard stones and cannons:** at every plot corner touching a street or market ground, set 0.4 m out on the corner's bisector, alternating by hash.
  - **Plaques and plates:** on both corner faces of plot corners touching a named street, 4 cm off the wall, at 4.5 and 3.9 m.
  - **Company bollards:** 2 each side of each drop, 4 at each plaza corner, 0.6 m back from the kerb line.
  - **Tram overhead:**
    - poles on both sides of the loop, 5.4 m off the track's centreline (outside the strip and the kerb, in the setts), every 30 m;
    - a span wire across at each pair, the trolley wire over the track between spans, the curves by chords;
    - lamps on every other pole;
    - ward-cage lamps on the poles nearest the god's sightlines (the four mid-side pairs) and the dark ends;
    - a dead lamp on every eighth pole where seepage < 0.3.
  - **Sigil discs** on poles that face a side street. **Ward hoardings** across the ends of side streets meeting the ring or Madero (about 10), set 6 m into the side street.
  - **Chain posts** every 1.5 m with chains, on the copings 20 m either side of each bridge and along each landing's mouth.
  - **Kiosks:**
    - news kiosks at the four plaza corners near the Metro kiosks' wells (4 m off) and at the tram stop;
    - lottery and sweets kiosks every 25 m along the plaza's edge, 2.5 m in from the kerb;
    - shoeshine stands under the Portales every 9 m.
  - **Market carts** every 6 m on alternating sides of the market lanes, 1 m from the stalls' fronts.
  - **Poster columns:** 8 on the plaza, 6 in the market, 4 on Madero. Poster clusters on one in three street-facing plot walls, at 1.2–2.4 m.
  - **Seepage objects** where seepage ≥ 0.5, about 12:
    - payphones on poles;
    - dead traffic lights on span wires at the ring's corners;
    - parking meters, concrete bollards and bus-stop signs near the palace.
  - **The Bound God:** at (0, 0.2, 0), its offerings heap before its open side (south, facing the causeway band), eight ward-cage lamps on posts round it at 9 m.
  - **Dark spots** (a point on a street or the plaza further than 20 m from any lit lamp): marigold petals, and a cage trap on a post (every third). Each dead lamp gets a claw-scored slab and petals.
  - **Candle drifts** at about 20 seeded wall feet.
  - **Surfacing idols** where subsidence ≥ 0.6 (3), each with a barrier.
  - **Sealed hatches** replace the four corridor hatches nearest the crypt (z < 0).
  - **Booths:** Lines of the Dead (4, plaza corners), testimony booths (2, plaza north side), notice boards (4).
  - **Market:** curiosity stands (4), the monster wagon (1), luchador shrines (2), spirit photographers (2), relic crate carts (2).
  - **Lights:** one per lit lamp piece, at its globe, as Ruling 2 sets.
- Modify: `tools/level/dress.py`:
  - `kit_of` becomes a lookup in the loaded faces (Ruling 5);
  - `KITS` gains the four kits;
  - `dress()` calls `dress_life.life(d)` and returns `"lights"`;
  - footprints of placed non-flush pieces are checked against family 1's in `life`, which skips a spot that overlaps.
- Test: `tools/level/test_dress_life.py`:
  - every card piece is placed at least once (the god once);
  - counts within the density table (poles 50–70, carts ≥ 60, guard stones ≥ 150, plaques ≥ 150, kiosks ≥ 20);
  - no non-flush piece's footprint overlaps a kerb, track strip, hatch, grate, wall, plot, opening or another piece's (by box);
  - every wall piece is 4 cm off a plot's wall, within its face;
  - every span wire's ends sit on poles, and no wire passes through a plot;
  - every lit lamp has a light;
  - the god at (0, 0.2, 0) with its heap south of it;
  - the district gate is clean over everything;
  - piece names are unique across kits.

- [ ] Test (FAIL), implement, test (PASS), `level.sh zocalo` writes it clean, `level.sh test` exits 0.
- [ ] Commit `feat(zocalo): the street-life dresser: bollards, overhead, signs, carts, kiosks and the uncanny, laid densely`

### Task 7: Lit and walk-tested in Godot

**Files:**
- Modify: `scripts/Level/KitLoader.gd`:
  - glass surfaces get a glass material: frosted, emissive cyan-white or amber by the piece;
  - `lights` become OmniLight3Ds under a `lights` node, their energy following day and night (off by day);
  - box colliders for the new pieces come from the dressing.
- Modify: `maps/zocalo.gd`: `set_day` switches the kit's lights.
- Modify: `tests/zocalo_test.gd`:
  - **Z15:** the street life loads; every placed kind is drawn, and the lights number as many as the lit lamps.
  - **Z16:** the player walks round the god (a loop at 7 m) and through the market's middle lane end to end, never stalled more than 0.3 s.
  - **Z17:** a pole blocks the player (walking into one stops them); petals and candles do not.
  - **Z18:** at night a lit lamp's pool is lit (the light's energy > 0 and its position over the street); by day the lights are off.

- [ ] Test (FAIL), implement, all suites (PASS).
- [ ] Commit `feat(zocalo): street life lit and walk-tested`

### Task 8: Stills, frame rate, record

**Files:**
- Modify: `tools/level/layouts/zocalo/cameras.py`: cameras on the god (day and night), the market lane, a dark side street with its hoarding, the ring under the wires, a corner with its guard stone and plaques.
- Update the memory: `zocalo-district-project.md`.

- [ ] Stills day and night; look at every one for floating, buried, overlapping or stretched pieces. Each fault gets a failing test, then a fix.
- [ ] Load report and fps, dressed against undressed. Explain any worst-frame drop, or name it unfinished.
- [ ] Send the stills to the user with the open calls.
- [ ] Commit `docs(zocalo): street life's cameras`
