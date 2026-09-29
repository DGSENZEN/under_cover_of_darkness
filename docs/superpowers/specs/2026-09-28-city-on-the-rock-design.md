# The City on the Rock: Program Design

**Date:** 2026-09-28
**Status:** concept and build order approved in conversation; this document awaits the user's review.
**Supersedes:** the mission concept of `2026-09-26-canal-quarter-mission-design.md` (its sections 1–4, 7 and 12). That spec's level metrics (section 5) and Blender-to-Godot contract (section 6) still hold: the garrison program built the contract as `tools/level`, and this program extends it.
**Working names:** the city (unnamed yet), the Moon-Glass (the target), the districts below.

## 1. Goal

The user's first ask (Sept 26):

> a complete test level where we really test the verticality, the horizontality and the depth of possible levels ... modeled after a Thief level where we need to traverse a large map with several parts and levels to get a specific item (but still get chances to get other things), with many guards, many different levels and behaviours per sector and increasingly challenging stealth and movement puzzles.

And the direction that reshaped it (Sept 28):

> We want an expansive enough level that is about 90 minutes of gameplay, and has different parts where the verticality is shown, where the horizontality is shown. We want a grander than life sense of scale, imagine Game of Thrones style with its maximalism or Elden Ring with their palaces (albeit more controlled). Most of the examples I wish to go for are Spanish and Portuguese architecture with a mix of English castles. I want a level that is just several levels into one, with each one having different forms of access, gameplay, puzzles and general intent for the player to explore.

Also: a PS2 level of vertices, but buildings and terrain detailed enough; online references sought for every building and model.

## 2. Decisions

| Question | Decision |
|---|---|
| Concept | **The city on the rock**: an Iberian city where a river gorge meets the sea, climbing a rock from its harbour to an English-style castle on the summit. Eight districts, each a level in its own right. |
| Architecture | Spanish and Portuguese (riverfronts, old towns, a Moorish palace of waters, a Gothic and Manueline cathedral, a gorge town, an aqueduct), with an English castle (concentric walls, drum towers, a great keep). |
| Scale | About 800 × 600 m and 180 m of height; larger than life but controlled. |
| Length | About 90 minutes for a thorough first run. |
| Detail | PS2 vertex budgets; triangles spent on silhouettes and on what is near the eye; texture, vertex paint and decals for the rest. |
| Look | PS2-inspired, not a copy: no vertex snapping (the user's ruling of Sept 28); keep the dither, grid, grading and painted detail. |
| Build order | **One district finished first** (the harbour) as the look's benchmark; then the rest of the city in blocks; then the missing systems; then an art pass per district. |
| Execution | Native, in the session; one final review per sub-project. |
| Carried over (Sept 26 answers) | Tap-or-hold mechanisms; a changing night (clouds over the moon, rain waves, a storm at the keep); a scripted kit with the level `.blend` editable by the user; target + loot goal + specials + stats; stealth first; swimming; all four thief's tools; quicksave anywhere but mid-fight; textures.com files kept out of git (the repository is public). |

## 3. What already exists

Other programs built much of what the canal quarter planned (Sept 26–28). This program uses it rather than building it again.

| What | Where | How this program uses it |
|---|---|---|
| The level pipeline: kit as data (`kit_recipes.py`, `kit_shapes.py`), layouts (`layouts/*.py`, `lay.Layout`), markers (`markers.py`), rules (`rules.py`), export with vertex bake (`shade.py`) and the z-fighting fix (`overlap.py`), the build's guard for edited files | `tools/level/`, `scripts/Level/LevelLoader.gd`, `Zones.gd` | Extended (section 8): new marker types and rules, terrain with mesh colliders, Iberian and fortification kit families, ships, massing |
| Night and weather (moon and clouds, weather states, rain, lightning, fog, noise floor, puddles, mist) | `scripts/Night/` | Configured per district; the storm at the keep |
| Lights and fire (burners, fixtures, coronas, the six-shadow LightBudget) and torch dousing (water flasks, relighting, guards noticing dark torches) | `scripts/Visual/Lights/`, `Torch.gd` | Used as is |
| Climbing and swimming for the player and the guards (NavLinks, GuardClimb, WaterVolume, GuardWater) | `scripts/AISystem/`, `scripts/Interaction/WaterVolume.gd` | Designed with: guards follow you up ladders, ropes and walls and into water, so the level answers with pulled-up ladders, retrieved ropes, gaps too wide for a guard's leap and long swims |
| Water shader, god rays, wind, foliage, wildlife | `scripts/Visual/` | Used as is |
| Textures: ps2ify, our own painted textures (`paint.py`), material slots (`Materials.gd`) | `tools/textures/`, `textures/painted/` | New Iberian slots (section 12) |
| The garrison's kit (walls, curtain, chapel, Tudor houses, props, nature) | `tools/level/kit_*.py` | Reused where it fits: the castle's curtain and chapel families |

## 4. The program

Each step gets its own plan and a final review; the user sees each.

1. **The harbour, finished.** The pipeline additions the harbour needs (section 8), the harbour at final art (section 6) with the rest of the city behind it as massing, its guards and ways in, and a performance benchmark. The look's benchmark for every later district.
2. **The city in blocks.** The seven other districts greyboxed with every way in, guard and puzzle; the scale systems (the navmesh baked offline in chunks with its climb links, cheaper thinking for far-off guards, the traversal rules over the whole map). The user walks the whole mission.
3. **Mechanisms**, with the save contract defined at its start so every new node saves from day one.
4. **The thief's tools**: water, rope, moss and noise arrows (dousing exists).
5. **Saving.**
6. **Mission systems**: objectives, the loot goal, specials, secrets, exits, the end screen.
7. **Art passes**, district by district, each to the harbour's standard: old town, cathedral, palace, aqueduct, gorge, undercroft, castle.

## 5. The city

### 5.1 Geography

The sea lies to the south. A river comes out of the hills to the north-west and cuts a gorge about 100 m deep down the west side of the rock before it reaches the harbour. The rock rises from the harbour to its summit in the north-west, where the castle stands over the gorge. The old town climbs the south slope in terraces; the cathedral stands on a terrace halfway up; the palace of waters holds the east shoulder; an aqueduct brings water from the hills to the north into the palace. Cisterns, catacombs and tunnels run beneath all of it.

| What | Height (m above the sea) |
|---|---|
| Undercroft floors | −15 to 0 |
| The sea, the harbour, the river mouth | 0 |
| Quays and the riverfront street | +2 to +3 |
| Old town terraces | +5 to +45 |
| Cathedral terrace / nave vault / bell tower | +45 / +85 / +140 |
| Palace terrace / its mirador | +75 / +100 |
| Aqueduct channel | +80 at the palace, 40 m over the valley floor |
| Gorge floor / rims | +5 / +95 to +100 |
| Great Bridge deck | +100 |
| Castle summit / curtain walk / keep top | +100 / +115 / +155 |

### 5.2 The eight levels

| Level | Purpose | Axis | Ways in | Signature play and puzzles |
|---|---|---|---|---|
| **Harbour** | Arrive unseen and get into the walled city | Horizontal | The Sea Gate; a carrack's yard reaching over the sea wall; the riverfront roofs to the wall-walk; the river mouth (to the gorge); the smugglers' cave (to the undercroft) | Lit quays with lantern patrols, ships to climb, the chain across the harbour mouth (its windlass: the boat exit) |
| **Old town** | Find the way up a vertical maze | Both | Stair-lanes; rooftops; the tavern cellar; the west rim | Rooftop runs against street routes, lamps the watch relights, a locked upper gate |
| **Cathedral** | Climb a vast interior and lift a relic | Vertical | The cloister door; the flying buttresses to the roof; the crypt | Galleries high in the nave, a bell tower climbed by ramps, bells every quarter hour that mask noise |
| **Palace of waters** | The heist | Horizontal: patios in a chain | The garden wall; the baths' drain; the aqueduct's end | Fountains as noise cover, lit patios against dark galleries, draining the great pool to open a vault |
| **Aqueduct** | The high traverse | Horizontal at height | Its piers from the valley; the hill reservoir; the palace roof | The exposed channel or the ledge below it, a watchtower mid-span, the sluice that drains the channel |
| **Gorge and the Great Bridge** | Descend and climb 100 m | Vertical | Cliff stairs from the old town; the river from the harbour; the bridge's inner stair | Hanging houses on the cliff, a chamber inside the bridge's arch, mills at the bottom |
| **Undercroft** | The dungeon: dark, deep, flooded | Depth | The tavern cellar; the cathedral crypt; the spiral well in the palace garden; the smugglers' cave | Swimming between cistern columns, the bone chapel, water levels set by the aqueduct's sluices |
| **Castle** | The fortress and the finale | Vertical: the keep | The barbican; the sally port on the gorge side; a wall climb from the hanging houses; the latrine chute; the cistern from the undercroft | The whole garrison (squads, bells, chapel, barracks); the storm breaks at the keep; the Moon-Glass at its top |

**Each district's own kind of access** (research rule 5: different access makes a different level):

| Level | Its gate |
|---|---|
| Harbour | Open, with many entries by water, quay, warehouse and ship |
| Old town | A movement rule: the streets belong to the watch, the roofs are the thief's highway |
| Cathedral | Vertical and timed: up from the crypt or down from the roof, moving under the bells |
| Palace of waters | A mechanism: the waterworks' valves change the fountains' sound and light, drain the great pool and open the baths route |
| Aqueduct | A shortcut opened from its far end (the loop home, rule 4) |
| Gorge and bridge | A mechanism split into stations: the bridge's lamps and its drawbridge stations, each key-locked |
| Undercroft | Water levels: its deep routes open only as the aqueduct's sluices drain them |
| Castle | A choice of front (the barbican), cliff path (overheard, as Edinburgh fell in 1314), the sea stair from the harbour's water gate (Harlech's 127 steps), the chapel window by the latrines at prayer time (Château Gaillard, 1204; Conwy, 1401) or the cistern; and the keep's vault a **count gate**: it opens to two of three seals (the harbourmaster's in the customs house, the bishop's in the cathedral, the lord's in the palace), as Leyndell's great runes do |

**Pacing** (research rule 10: a Thief II mission runs about 80 minutes):

| Minutes | Beat |
|---|---|
| 0–10 | The harbour: arrival and the panorama of the whole rock |
| 10–30 | The old town and its rooftops; the aqueduct seen, the cathedral and palace ahead |
| 30–50 | The palace **or** the cathedral, for the seals |
| 50–65 | The gorge and the bridge **or** the undercroft (dread: a quiet first half, a hunted second) |
| 65–85 | The castle's ascent and the keep's vault; the storm breaks |
| 85–90 | The escape: a loop back down by the aqueduct, a lift, the sea stair or a rope |

Two of the middle districts are alternatives, so a replay can take another way.

**Routes to the Moon-Glass** (at least four whole-mission routes): Sea Gate → old town → cathedral square → barbican; smugglers' cave → undercroft → the castle cistern; river mouth → gorge → hanging houses → the curtain wall; old town → palace → the aqueduct's castellum → the castle's north wall. **Exits:** the harbour by boat (the chain lowered), the river down the gorge, across the Great Bridge, or a rope down the cliff from the castle.

**Guards:** about 61 — harbour 9, old town 10, cathedral 7, palace 10, aqueduct 3, gorge 4, undercroft 4, castle 14.

## 6. The harbour in detail

(Sub-project 1's content; the detailed layout is in its plan. References: Seville's river port, Porto's Ribeira, Lisbon's riverfront, Barcelona's and Málaga's shipyards, Palma's merchants' hall, Peñíscola; section 13.)

- **Shape:** a bay about 350 m along its quays, closed on the east by a mole (breakwater) and on the west by the river mouth. The harbour mouth lies between the mole's head and a fort at the river mouth, and a chain can close it.
- **The chain towers:**
  - On the mole's head, a golden twelve-sided tower in three stages (after the Torre del Oro: 36.75 m, a 15 m base, lime render the colour of straw), detached from the wall and joined to it.
  - At the river mouth, a fort on a bastion in the water (after the Torre de Belém: a 30 m tower, domed corner turrets, embrasures at water level).
  - The chain's windlass sits in the golden tower. Lowering it is the boat exit; the slack chain is a grab-line across the water.
- **The Ribeira:**
  - Granite quays with steps and mooring rings, and a low, heavy granite arcade along them: a shadowed walkway.
  - Tall, narrow houses of four to six storeys stand over the arcade against the city wall. Their fronts are tiled or colour-washed inside granite frames, with iron balconies that ladder up the facades.
  - A long stair climbs beside the wall to the old town (after Porto's Guindais stairs).
- **The Terreiro:**
  - A royal square on the water (after Lisbon's Praça do Comércio, at about half its 175 m).
  - It is arcaded on three sides and open to the harbour, with a grand stair down to the water, and lamplit: a no-go zone whose arcades are the way round.
  - The **Sea Gate** into the city stands at its back: twin towers, a portcullis, a vaulted passage, murder holes.
- **The royal shipyard:**
  - A long hall of brick naves: one bay of piers, a slightly pointed arch and a groin vault, repeated (after the Reales Atarazanas and the Drassanes, 8.4 m wide and high).
  - A galley is half-built on the stocks inside, its ribs and scaffold a climbing set piece.
  - Boats row in from the harbour through a sea gate, a horseshoe arch under its frame (after Málaga's Nasrid shipyard gate).
  - Part of it is the **customs house**, where the ledgers, seized cargo and the harbourmaster's seal (one of the keep's three) are kept.
- **Ships:** a carrack at the main quay (three masts, rigging and ratlines to climb, a yard that reaches over the wall's parapet, the captain's cabin), a caravel, fishing boats and rowboats.
- **Edges:**
  - The smugglers' sea cave in the east cliff, with a blowhole whose roar and spray cover sound and sight (after Peñíscola's Bufador); its tunnel is the undercroft's, sealed until sub-project 2.
  - The river mouth and the gorge opening in the west, the Great Bridge seen high up the gorge.
- **Start:** the outer end of the mole, in the dark.
- **Guards (9):**
  - two at the Sea Gate;
  - a lantern pair on the quays;
  - the customs house watchman;
  - the carrack's deck watch;
  - a lookout archer on the golden tower, with a bell;
  - a patrol on the mole;
  - a brute in the shipyard.
- **The vista:** from the quays the whole city rises: the old town's terraces, the cathedral tower, the palace, the castle and its keep on the summit, the gorge and the Great Bridge. In this sub-project the rest of the city is massing (low-poly silhouettes with lit windows) in fog and moonlight.
- **The harbour's colour key:** granite grey and sea green under the moon, lamp amber on the quays, the golden tower warm.

## 7. Scale, landmarks and control

From the grand-scale research (section 13), made concrete for this city:

1. **One crown, visible from everywhere:** the keep, the city's Erdtree. Medium landmarks, one per district: the chain towers, the cathedral tower, the palace's mirador, the aqueduct's arch line (pointing at the castle), the Great Bridge. Small lit signposts: lamps at stair heads, street shrines with candles (the Portuguese *alminhas*), a torch at a cistern mouth.
2. **The route climbs:** enter low at the harbour with the whole rock in view; dip into the gorge and the undercroft; climb to the castle. Viewpoints (the old town's *miradouros*) show the next goal.
3. **Each district is a small sandbox:** three ways in or more, routes that spiral with no dead ends, each building its own encounter (walls and navmesh distance keep one alarm from spreading through a district).
4. **Every district loops home:** it ends with a shortcut opened from the far side (a door unbarred from within, a ladder kicked down, a hoist, the aqueduct) back toward the old town.
5. **Its own kind of access** (the table in 5.2).
6. **Controlled maximalism:** one striking landmark and one colour key per district: the harbour sea-green and lamp amber; the old town azulejo blue on whitewash; the cathedral candle gold and deep red; the palace turquoise water light on ochre; the aqueduct silver moonlight on stone; the gorge blue-black and mill-fire orange; the undercroft sick green and bone white; the castle white-rendered walls (castles were lime-washed, like Conwy and the White Tower) and the garrison's crimson. Repeated modules vary by orientation and height; hand detail goes where the player pauses after a transition.
7. **Build near, paint far, fog between:** full geometry within about 100 m; district proxies at 1/30–1/100 of the triangles (the massing); rendered panorama cards for the sea, the hinterland and far ridges (the existing skyline tool). Godot visibility ranges do the handover; fog hides it; big landmarks carry their own far proxies.
8. **Anchor, then extend:** full scale and detail wherever the player can touch; unreachable upper storeys and tower tops simplified, forced perspective allowed.
9. **Rock reads big through strata, silhouette and value:** horizontal strata bands as a height ruler, jagged rims against a fog gradient, vertex-colour blends, 256 px rock textures, the destination lit and the sides dark; the city grows out of the rock (walls start where the cliff stops, houses swallow boulders). In the gorge, a known size at each third of its depth: a house at the top, a mill or arch midway, the river and a footbridge at the bottom.
10. **Scene boxes:** each district's atmosphere zones (the existing `Zones`) set its grade, fog and exposure, easing across the thresholds.

## 8. Pipeline additions (`tools/level`)

- **Markers:** loot, key, tool, chest, prop, rope, lever, wheel, portcullis, sluice, hoist, slider, objective, exit, secret, noise_zone, probe, route_check (waypoints carrying the move that reaches them); an unknown-property check.
- **Rules:** hang lips (clear space under them, depth, face angle), gaps between lips (walk, sprint, assisted, uncertain, never), route checks by move, headroom along guard routes, locked doors with a pickable key.
- **Terrain:** the rock, cliffs, the seabed and banks as unique meshes built by a generator (height grids and cliff strips at PS2 density, vertex-colour blends), exported with **mesh colliders** (a new collider kind the loader turns into concave shapes), counted as floor by the rules.
- **Kit families:** Iberian houses (tall narrow fronts, arcades, balconies with iron rails, azulejo panels, whitewash and ochre, terracotta roofs); fortification (sea wall, towers round and square, the gate with its portcullis and machicolations, parapets); harbour (granite quays and steps, the mole, the slipway, cranes, bollards, nets, baskets, anchors); ships (carrack, caravel, fishing boat, rowboat, a hull on the stocks, rigging as climb volumes); Mediterranean planting (palms, cypresses, orange trees, agave); massing (low-poly silhouettes for districts not yet built).
- **Shared gameplay builders:** `scripts/Level/LevelGameplay.gd`, lifted from `maps/garrison.gd` (doors, lights, water, ladders, bells, decals, chests), plus loot, keys, tools, props, guards with routes, and stubs for the mechanisms.
- **The mission's map:** `maps/city.gd/.tscn`, which loads its districts' levels (the harbour first), the night, the player and the guards.

## 9. The look

- The garrison's rules hold (its spec, section 11): small hot lights separated by real darkness; lit windows as sparse warm accents; coloured light rare and deliberate; light from below where dramatic; symmetry and foreground framing; figures small in large dark spaces; ground and air that weather changes.
- The Iberian palette at night: whitewash cool and pale under the moon, ochre and terracotta warm under lamps, azulejo blue, granite grey, the dark wood and pale sails of ships, water catching every light.
- Vertex paint (the existing bake), textures (section 12), decals (grime, leaks, moss, salt), props (nets, baskets, barrels, crates, anchors, oars, chains).
- Judge every piece and view at full size from many angles before calling it done (the garrison's lesson).

## 10. Performance

- **Sub-project 1 target:** the harbour at 60 fps average and a 99th-percentile frame under 25 ms at 1080p on the user's Mac, with its guards alive and the massing in view; the mission loading in under 15 s.
- **Measures in hand:** the LightBudget, visibility ranges on dressing, occluders from colliders, fog; the massing drawn as few large meshes.
- **At city scale (sub-project 2):** the navmesh baked offline in chunks with its climb links saved alongside, far-off guards thinking less often (or asleep until the player nears), and the benchmark walking every district.

## 11. Testing

- `tools/level/level.sh test`: every new marker and rule against a broken fixture; terrain colliders.
- A city level suite: the harbour loads; every marker resolves; every guard stands on the navmesh and reaches his route; every locked door has a pickable key; probes read their moonlight and shadow; the key climbs (the carrack's rigging to the wall, the roofs to the wall-walk) driven through the real controller.
- Stills of the key views, judged at full size from many angles; the benchmark; every existing suite green.

## 12. Textures

All kept out of git (the repository is public): the photos in `textures/source/`, the converted in `textures/ps2/`, only the recipes committed; every slot falls back to a flat colour. Our own painted textures (`tools/textures/paint.py`) are committed.

**What the user already owns, and where it goes:**

| Slot | Source |
|---|---|
| Azulejo facades and dados | TilesAzulejoBlue0006 and 0067, TilesPatterned0332 and 0358, TileMurals0014 (a mural panel) |
| Terracotta roofs | Roofing_SpanishOld (its height and AO multiplied into the colour), RooftilesCeramicOld0003 and 0087 |
| Whitewash and render | Wall_Plaster2 and 3, PlasterWhiteDirty0035, PlasterDamaged0925 (the damp feet of walls) |
| Stone | StoneRegularWeathered0227 (golden ashlar), 0289 (a quay wall with its moss band), StoneStripWall, Wall_Stone5, Wall_CobblestoneMixed and Mossy (rubble) |
| Pavement | FloorsPortuguese0047 (the Portuguese *calçada*), FloorsMedieval0030, 0031 and 0032 |
| Rock | Rock_CliffDesert3, Rock_WallMossy |
| Wood, doors, shutters | WoodPlanksOld0239 and 0292, WoodStudded0039 and 0044, WindowsShutters0291, DoorsMedieval0494, 0438 and 0587 |
| Iron, carving, decals | Rust0221, MetalVarious0033, Reliefs0048 and 0080, OrnamentBorder0321 and 0332, OrnamentsArches0121, the leak, grime and moss decals |

**To buy for the harbour** (20 credits at size S; every page checked on textures.com, none with the "Textures AI" badge; photos unless marked PBR):

| Need | Item | Credits |
|---|---|---|
| Ship hulls, tarred | [WoodPlanksPainted0242](https://www.textures.com/download/wood-planks-painted-0242/77755) | 1 |
| Ship hulls, bare | [WoodPlanksBare0437](https://www.textures.com/download/wood-planks-bare-0437/36926) (image 2 or 5) | 1 |
| Sailcloth | [FabricPlain0138](https://www.textures.com/download/fabric-plain-0138/107640) (we paint the seams and patches) | 1 |
| Rope along its length | [Various0236](https://www.textures.com/download/various-0236/29778) (image 1) | 1 |
| Coiled rope | [Various0215](https://www.textures.com/download/various-0215/27300) (we mask it) | 1 |
| Fishing net | [Thick Rope Net PBR00873](https://www.textures.com/download/thick-rope-net-pbr-material-pbr00873/145973) (albedo and alpha) | 2 |
| Granite quays | [StoneRegularWeathered0084](https://www.textures.com/download/stone-regular-weathered-0084/7301) | 1 |
| Rock-faced walls | [StoneFacade0043](https://www.textures.com/download/stone-facade-0043/2599) | 1 |
| Ochre render | [PlasterPaintWorn0152](https://www.textures.com/download/plaster-paint-worn-0152/46811) | 1 |
| Salmon render | [PlasterPaintWorn0169](https://www.textures.com/download/plaster-paint-worn-0169/134822) | 1 |
| Pale blue render | [PlasterPaintWorn0007](https://www.textures.com/download/plaster-paint-worn-0007/90011) | 1 |
| Green relief azulejo | [TilesRelief0010](https://www.textures.com/download/tiles-relief-0010/135249) | 1 |
| Polychrome azulejo and its border | [TilesPatterned0311](https://www.textures.com/download/tiles-patterned-0311/135342) (images 1 and 3) | 2 |
| Waterline, algae | [StoneRegularWeathered0241](https://www.textures.com/download/stone-regular-weathered-0241/2539) | 1 |
| Waterline, tide band | [StoneRegularWeathered0163](https://www.textures.com/download/stone-regular-weathered-0163/95018) | 1 |
| Terracotta floor | [Rustic Antique Terracotta PBR00193](https://www.textures.com/download/rustic-antique-terracotta-pavement-pbr00193/133597) | 0 |
| Worn hexagon floor | [Old Hexagon Terracotta PBR0600](https://www.textures.com/download/old-hexagon-terracotta-pavement-pbr0600/139489) (albedo) | 1 |
| Limestone cliff, far | [Cliffs0211](https://www.textures.com/download/cliffs-0211/58298) (image 1) | 1 |
| Limestone rock, close | [RockBlocky0085](https://www.textures.com/download/rock-blocky-0085/67615) | 1 |

**For later districts** (10 credits): Moorish stucco [OrnamentsMoorishStucco0223](https://www.textures.com/download/ornaments-moorish-stucco-0223/96168) and [0212](https://www.textures.com/download/ornaments-moorish-stucco-0212/96143); zellige [TilesZellige0098](https://www.textures.com/download/tiles-zellige-0098/96304) and [0024](https://www.textures.com/download/tiles-zellige-0024/96174); marble [MarbleTiles0148](https://www.textures.com/download/marble-tiles-0148/94888); a chequered church floor [FloorsCheckerboard0050](https://www.textures.com/download/floors-checkerboard-0050/115317); a Gothic frieze [OrnamentBorder0077](https://www.textures.com/download/ornament-border-0077/19279); Manueline rope stone [OrnamentsVarious0001](https://www.textures.com/download/ornaments-various-0001/3464); old brick [BricksSmallOld0199](https://www.textures.com/download/bricks-small-old-0199/110121); a clipped hedge [Hedges0060](https://www.textures.com/download/hedges-0060/42279).

**We paint ourselves** (`paint.py`): the wrought-iron balcony rails and window grilles (textures.com has no masked ironwork; a clean painted silhouette reads better at this size), the sails' seams and patches, the coiled rope's mask, and the tiles for the pieces that are not seamless (both hulls, the sailcloth, the frieze, the brick).

## 13. References

Three research reports (Sept 28), kept beside this spec in `docs/superpowers/refs/`: `iberian.md` (48 places across the eight districts, 136 Wikimedia Commons links, each figure sourced or flagged), `castles.md` (16 castles, their parts, how castles fell, night routines, a PS2 castle kit, 70 image links) and `scale.md` (Game of Thrones locations, FromSoftware's palaces, PS2-era scale, multi-district stealth missions, terrain at PS2 fidelity).

**Best reference per district, and the number that sets its scale:**

| District | Reference | Scale |
|---|---|---|
| Harbour | Seville's river port (Torre del Oro, its chain, the Reales Atarazanas) | The tower 36.75 m; the shipyard 17 brick naves over about 15,000 m² |
| Old town | Lisbon's Alfama, Granada's Albaicín, Toledo, Cáceres | The Albaicín: at least 20 cisterns within about 75 ha of walls |
| Aqueduct | Lisbon's Águas Livres with its distribution house; Segovia's two-tier module | 941 m and 35 arches across the valley, the greatest 65 m high with a span of nearly 29 m |
| Palace of waters | The Alhambra's Nasrid palaces, the Generalife, the Alcázar of Seville, Sintra | The Court of the Myrtles 36.6 × 23 m with a 34 × 7.1 m pool; the Comares Tower 45 m |
| Cathedral | Seville with the Giralda and the orange-tree court; Burgos; Batalha | The Giralda's 13.5 m square base and 35 ramps; the court 43 × 81 m |
| Gorge and bridge | Ronda (the Puente Nuevo, El Tajo, the water mine, the mills); Cuenca; Setenil | The bridge 98 m high over a gorge 100–120 m deep, a former prison chamber above its central arch, a mill channel through a pier |
| Undercroft | The cistern of the Casa de las Veletas (Cáceres); Coimbra's cryptoporticus; Évora's Chapel of Bones; Regaleira's initiation well; Lisbon's flooded Roman galleries | The cistern 13.5 × 9.9 m, 16 horseshoe arches on 12 columns in water |
| Castle | Harlech (its 61 m rock, the 127-step sea stair); Rochester's keep; the Alcázar of Segovia; Málaga's Alcazaba and Gibralfaro for the nested layout | Curtain walls 9–12 m high and 1.7–3.3 m thick; battlement bays of 3.0 m (2.1 m merlon, 0.9 m gap); gate passages about 3 m wide and 16 m long with three portcullises; keeps 21–36 m square and 27–34 m high (ours is grander, as the brief asks) |

**Modelling rules from the references:**
1. **Plain outside, rich inside.** The Alhambra was designed to be seen from within; Manueline carving sits only on portals and windows.
2. **Build one bay at its real size and repeat it.** Segovia's 167 arches come in two sizes; the Court of the Lions is a rhythm of one, two and three columns.
3. **Walls are three texture bands:** a tiled skirting, a stucco or patterned field, a wooden or honeycomb-vaulted ceiling. Only arch outlines, column shafts and eaves need geometry.
4. **Silhouette features are geometry:** Moorish pyramidal merlons against English square ones, Sintra's cone chimneys, openwork spires, buttress rows, cantilevered balconies, rock overhangs, bridge voids. Carved lace can be alpha cut-outs.
5. **Light and water baked into vertex colour, one material per district:** granite for the harbour, whitewash for the old town, red earth for the palace, golden sandstone for the cathedral, cream limestone for Manueline detail; star-shaped pools under the baths' skylights, dark arch undersides, damp wall feet.

**Castle facts that shape play:** castles were lime-washed white (Conwy, the White Tower); garrisons were small (Harlech 36, Conwy 30 soldiers); night watchmen checked every door "for fear of pickers and pilferers"; the best break-ins used timing and the overlooked (a cliff path a local knew, men crawling up like cattle on a feast night, a low chapel window by the latrines, a cart jammed in the gateway, a garrison at church). Clockwise stairs for right-handed defenders is a myth.

## 14. Risks and open questions

| Risk | Handling |
|---|---|
| Ninety minutes at this scale is three to four times the canal quarter's content | Greybox before art; one district finished first to fix the standard and the cost |
| A city this size may not hold 60 fps with 60 guards | The harbour benchmark first; offline chunked navmesh and far-guard activation in sub-project 2 |
| Guards now climb and swim, so roofs and water are no refuge | Designed in: pulled-up ladders, retrieved ropes, gaps wider than a guard's leap, long swims |
| Terrain collision is new to the pipeline | Its own rules and tests in sub-project 1 |
| The textures the Iberian look needs may be missing | The user's own tiles and roofs first, our painted textures next, a short buy list last |

## 15. Success criteria

1. Sub-project 1: the harbour passes the user's look review at full size, plays with its guards and ways in, and meets the performance target.
2. The whole mission plays from the mole to an exit in about 90 minutes on a thorough run, with at least four distinct routes to the Moon-Glass.
3. Every suite passes, with no script errors.
