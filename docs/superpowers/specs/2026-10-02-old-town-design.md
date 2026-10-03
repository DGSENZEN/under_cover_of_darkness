# The Old Town: Design (the city on the rock, sub-project 2)

**Date:** 2026-10-02. **Status:** approved in brainstorming, section by section; written for the user's review before planning.

**Program:** `docs/superpowers/specs/2026-09-28-city-on-the-rock-design.md` (the city spec), amended by this document (section 15). Sub-project 1, the harbour, is built and merged (`origin/main` 64f043a).

**References** (in `docs/superpowers/refs/`, read-only research of Oct 2 2026; every number below that is not a design value comes from them):

| Report | Covers |
|---|---|
| `old_town_porto.md` | Barredo and its stairs, the Sé hill before its 1940s clearance, the merchants' lanes and the vaulted stream, the Fernandine wall, Rua das Flores, the Judiaria do Olival, tower-houses, the night city, and a kit specification for the Porto house |
| `old_town_lisbon.md` | Lisbon after 1755: the Baixa's grid and trades, the Pombaline building in depth, azulejo fronts (1838-1900), the Carmo ruin and the watch's barracks, Bairro Alto, Alfama, the vilas, the castle village, miradouros, fountains, night lighting, the Guarda Real, and a kit specification for the Pombaline house |
| `old_town_spain.md` | Seville's Santa Cruz, the patio house and the corral, adarves and cobertizos, Santiago, Salamanca and Cáceres, Girona, Cuenca, the Spanish house details, the sereno, and a kit specification for the patio house |
| `old_town_level_design.md` | How the best stealth cities were built (Thief: Deadly Shadows, Thief II, Dishonored 1 and 2, Hitman's Sapienza, Deus Ex, the Dark Mod, Randy Smith, Totten, Burgess) and 25 rules for the old town |
| `iberian.md`, `castles.md`, `scale.md` | The program's earlier research (Sept 28) |

---

## 1. Goal

The user (Oct 2 2026), after the harbour:

> We need to make the old town a bigger map, the harbor was just the introduction. I want to really show the level design skills, go full detail oriented, really well thought out houses and buildings.

With Porto and Lisbon as the main references, **Lisbon after 1755 (Pombaline building and azulejos)**, mixed with Spain. And on how the city is played:

> We want to have loading sections for each sector, we don't want them to be real time traversed ... Each sector has its own part ... Basically a complete map for each part.

## 2. Decisions

| Question | Decision |
|---|---|
| What comes next | **The old town, finished** to the harbour's standard (layout, guards, puzzles, full art), not the city spec's seven greyboxed districts |
| How districts join | **Each district is its own map**, joined by loading transitions at its real gates (Thief: Deadly Shadows' and Deus Ex's hubs). Each map holds one finished district and low-poly versions of the rest |
| What districts remember | **Everything the player did**: loot, doors, lamps, guards, bodies, moved things. Purse, tools and health are carried. This is the core of the save contract |
| Navmesh | **Baked offline** after export and saved with its links; baked live only when missing or stale |
| Size | **About 330 × 360 m and 82 m of climb**, about 2.5 times the harbour's ground; 30-40 minutes on a thorough first run |
| Period | **A timeless Iberian mix, medieval to the 19th century**, held together by the story of the great fire (section 4.2) |
| Buildings | **Four house families** from the references, generated from parameters on one grid; **six hand-made key buildings**; **one building in five or six enterable** (1-3 rooms); every other front honest |
| People | The night watch and the key buildings' households. **Townsfolk are their own sub-project, after this one**; the old town reserves their places |
| Build approach | The harbour's pipeline: a hand-laid Python layout, generators for the houses, the rules checking every route |
| Order of work | Three plans, each reviewed by the user: **A** districts as maps, **B1** the old town playable, **B2** its art pass |

## 3. What already exists

| What | Where | Used for |
|---|---|---|
| The level pipeline (kit as data, layouts, markers, rules, terrain, export with vertex bake, the build's guard over edited files) | `tools/level/` | Extended (section 9) |
| The harbour as a level, its map, its loading screen | `maps/city.gd/.tscn`, `scripts/Level/`, `LoadingScreen` | Split into district maps (section 3A) |
| Gameplay builders: doors, lights, water, ladders, bells, chests, pickups, props, noise zones, smokes, mechanism stubs | `scripts/Level/LevelGameplay.gd` | Each gains save and load (section 3A) |
| NavBaker with climb, leap, ladder and water links, swim regions, doorway regions | `scripts/AISystem/NavBaker.gd`, `NavLinks.gd` | Baked offline (section 3A) |
| Guards: archetypes, routes, stations, habits, squads, hunts, temperaments, climbing and swimming, doors, relighting doused lamps | `scripts/AISystem/` | The watch and the households |
| The talk director and its `.talk` scripts | `scripts/AISystem/Talk/`, `data/talk/` | Overheard conversations that carry the puzzles' facts |
| Night and weather (moon, clouds, rain, fog), lights and fire, the LightBudget's six shadows, torch dousing | `scripts/Night/`, `scripts/Visual/Lights/` | The moon decides the lamps (section 7.4) |
| The Iberian house generator (`casa`), its windows, balconies, eaves and roofs; painted textures; material slots | `tools/level/kit_iberian.py`, `tools/textures/paint.py`, `Materials.gd` | The starting point of the four families |

---

## 3A. Part A: districts as maps (the foundation)

This comes first: the old town cannot be reached until it exists.

**One map per district.** `maps/city.gd` becomes a district-map script that every district's map uses. A map loads its own level, the low-poly versions of the other built districts and the massing of the unbuilt ones (each district's massing sector skipped where the district is built), the night, the player and its guards. The harbour becomes the first district map; the old town the second.

**Low-poly district proxies.** At export, each district also writes a proxy: its pieces' blocky `boxes`, merged per sector, and a thinned copy of its terrain, with its lit windows kept. Other maps draw it beyond about 60 m, in fog. It follows its district's layout with no one maintaining it. The old town's map sees the harbour's proxy below; the harbour's map sees the old town's proxy above, in place of the massing's old-town houses.

**The shared edge.** The city wall and the Sea Gate between the two districts are laid by the same layout code into both levels at full detail: the player arrives right beside them.

**Doorways.** An `exit` marker gains `to` (a district) and `arrive` (an `arrival` marker's name there). Walking into it fades out, shows the loading screen (the user's words), writes the district's state, loads the destination and puts the player at the arrival, facing in. A rule checks that every exit's arrival exists in its destination.

**Memory.** A city-state store (an autoload) keeps each district's state as a dictionary keyed by marker name: pickups and chests taken, doors (open, unlocked, broken, barred), lamps lit or doused, every guard (alive, knocked out or dead; where; his alert state and his search), bodies and moved props where they lie, mechanisms' states. Every node that can change carries `save_state() -> Dictionary` and `load_state(state)`. The store is written when the player leaves a district and applied after the district is built when he returns. Purse, tools, health and held items travel with the player. Saving (the program's step 5) later writes the same store to disk: this is the save contract, defined here.

**No escape hatch.** Watchmen chasing the player when he passes a gate follow him through: they are carried into the destination's state and arrive at the same arrival a few seconds behind (their distance over their speed). The alert level carries over. (Deadly Shadows' players sprinted for load zones where nobody followed: `old_town_level_design.md` §1.)

**Offline navmesh.** After export, a headless step loads each district's map, lets NavBaker bake (land, swim regions, doorway regions and every link), and saves the result beside the export, marked with the export's content hash. The map instances the saved navmesh; it bakes live only when the file is missing or its hash is stale (a warning says so).

**A stand-in old town.** Until plan B1 builds it, the old town is a bare terrace with its arrivals, so the transitions can be tested end to end.

---

## 4. The old town's shape

### 4.1 Size and place

About **330 × 360 m**: x −180 to +150, z −21 to −380 (Godot's axes, the harbour's frame: x east, y up, z south). It rises from **+3 m** behind the Sea Gate to **+85 m** at the upper gate. Its south edge is the harbour's wall: the Ribeira's wall (z −21.2), wall C (x −99.2), wall D with the Sea Gate (z −73.2, gate at x −55), and the retaining wall over the shipyard's back lane (z −72) to the east wall (x 151.2).

Beyond it the unbuilt districts move back to make room, as massing: the cathedral's terrace north of the upper gate (about +85 to +90), the palace on the east shoulder, the castle on the summit to the north-west, the gorge down the west side. The massing layout is redrawn to match.

### 4.2 The story that holds the mix together

A great earthquake and fire (the city's 1755) levelled the low town behind the Sea Gate. It was rebuilt to a plan as a Pombaline grid; the hills around it kept their medieval lanes. The great church that burned on the hill was left roofless as a memorial, and its convent became the watch's barracks. This is Lisbon's own history (`old_town_lisbon.md` §1, §7), and it lets the Baixa stand beside Porto's and Seville's old quarters honestly.

### 4.3 The five quarters

| Quarter | Where (x; z) | Height | References | How it plays |
|---|---|---|---|---|
| **The Baixa** | −100 to 15; −73 to −170 | +3 to +6 | Lisbon's Baixa Pombalina | Wide, straight, lamp-lit streets the watch owns (main street 13.2 m, secondary 8.8 m); a uniform roofline crossed by fire walls every 2-6 buildings, a plateau with a rhythm of walls to vault; trades by street (goldsmiths, silversmiths, cloth) as a loot map; a sewer (about 2.2 × 3.1 m) under the main street; a Rossio-like square with a fountain at its head; the Sea Gate's arrival |
| **The stairs** | −180 to −100; −21 to −290 | +14 to +60 | Porto's Barredo, Lisbon's Alfama | Stair-lanes 1.2-3 m wide; houses built over the stairs; houses with doors on two levels (shortcuts between terraces); dead-end alleys; a fountain square where seven lanes meet; a tannery yard; the stream vaulted over with houses on it (the thief's sewer); the sailors' tavern and its cellar; poor and dark, torches the player can douse |
| **The Judiaria** | 15 to 150; −73 to −290 | +14 to +55 | Seville's Santa Cruz, Córdoba, Porto's Judiaria do Olival | Patio houses turned inward behind blank whitewashed walls; lanes down to about 1 m; dead-end alleys gated at night; houses bridging the lanes; flat roof terraces linked house to house with lookouts (a second roof highway, flat and walkable, so the watch comes up too); the tenement court (kept for the townsfolk); two iron gates shut at the curfew bell |
| **The Carmo hill** | −100 to 15; −170 to −290 | +20 to +55 | Lisbon's Chiado and the Carmo | The roofless church (a nave about 72 m long; pillar shadows under the moon); its convent the watch house; the dolphin fountain under its canopy on the square; a lookout terrace on a 20 m retaining wall over the Baixa, lamp-lit, with a watchman and the view of the harbour and the cathedral |
| **The upper town** | −180 to 150; −290 to −380 | +60 to +85 | Porto's Sé hill before 1940, Cáceres, Rua das Flores | Granite tower-houses (the tallest, about 30 m, is the district's landmark; cut-down ones are roof platforms); the merchants' street of tall Porto houses with skylit stairwells and rooftop lookouts; a great house on its rock (after Porto's bishop's palace); the chapel; walled garden houses on the gorge rim; the upper gate, an arch through a 22 m crenellated tower |

The quarters meet at terrace edges: the Baixa's basin (+3) lies 11 m under the stairs (west) and the Judiaria (east), with stairs and retaining walls between, as Lisbon's Baixa lies between its hills.

**Difficulty climbs with altitude** (`old_town_level_design.md` rule 13): dark, soft-floored and poor at the bottom; lit, hard-floored and watched at the top, where the watch relights its lamps.

### 4.4 Landmarks

- **The whole city:** the castle above, the sea below.
- **The district:** the tower-house, the ruin's broken nave, the watch house's lantern and the upper gate, about 60-120 m apart, placed so one is seen from every square, every roof chain, every key building's door and each gate.
- **Each place:** fountains, lamp-lit wall shrines, azulejo panels, tiled street names (white with a blue frame, after Seville's 1767 plates). An azulejo map of the quarter on a wall inside the Sea Gate.

### 4.5 Ways in and out

| # | Way | Where | Leads to |
|---|---|---|---|
| 1 | The Sea Gate | x −55, z −73, +2.5 | The harbour's Terreiro (built both ways) |
| 2 | The east wall-walk | x 151, z −70, +14.5 | The harbour's shipyard wall (both ways) |
| 3 | The Guindais gate | x −184.5, z −91, about +30 | The harbour's Guindais stair (both ways) |
| 4 | The west wall's top | x −179, z −116, about +50 | The harbour's west wall-walk (both ways) |
| 5 | The upper gate | x −30, z −380, +85 | The cathedral (sealed until built) |
| 6 | The west rim's cliff stair | x −180, z −326 | The gorge (sealed) |
| 7 | The palace's garden wall | x 150, z −230 | The palace (sealed) |
| 8 | The tavern's cellar | the stairs, about x −140, z −60 | The undercroft (sealed) |

A sealed way is a barred door, grating or rope-less drop that says where it leads; it opens in the sub-project that builds its district.

---

## 5. The buildings

### 5.1 One kit, one grid, standards first

After Skyrim's kits (`old_town_level_design.md` §8.3): a **0.5 m plan grid**; the existing door (1.2 × 2.2 m); openings, sills, balconies and lips sized to the controller's metrics (mantle 2.3 m, hang 3.9 m, the rules' gaps), so every front reads true to how it is climbed. Each house is generated from parameters, as the harbour's `casa` is: family, lot, storeys, bays, cladding, roof and **one quirk**. Clutter varies more than architecture.

### 5.2 Four families

| Family | Where | Dimensions (sourced unless marked design) | Variants |
|---|---|---|---|
| **The Porto house** (`old_town_porto.md` §13 and its kit) | The stairs, the upper town | Lots 4.5 m (medieval) or 6 m (Almada), 10-22 m deep; 3-5 storeys, upper floors 3.2 m, shop floor 3.8 m (design); granite party walls 0.4 m; fronts 0.6 m with 1.25 m openings, two bays to 4.5 m, three to 6 m; jettied timber upper floors on old houses (0.4 m); a straight stair against a party wall (old) or a two-flight stair across the middle under a skylight (later); kitchen on the top floor; dormers and a rooftop lookout; balconies 0.5 m slabs on corbels | Narrow single-bay; double-bay; corner; against the wall (a top-floor door onto the wall-walk); shop house with a lookout; the 1.5 m slot house |
| **The Pombaline building** (`old_town_lisbon.md` §4 and its kit) | The Baixa, the Carmo hill | Bays of 2.7 m (1.35 m opening, 1.35 m pier; derived), 3-6 bays; a vaulted stone shop floor (about 3.7-4.0 m), three floors and an attic or mansard; balcony doors (*sacadas*) on the first floor, sill windows above, dormers every 2-3 bays; two flats per landing, each with a front and a service door; windowless inner rooms lit through glazed fanlights; a 1.2 m light well; fire walls 0.5 m thick standing above the roofs; azulejo fronts (14 cm tiles, framed openings, a double frieze under the cornice) | Block corner (four-pitch roof); mid-block; hill street; shop building; gated workers' row |
| **The patio house** (`old_town_spain.md` §2-3 and its kit) | The Judiaria | Design lots 6 × 18 m (small) and 10 × 25 m (merchant); patio at least a quarter of the lot (Córdoba's rule); a bent entrance passage, an iron gate (*cancela*) onto a galleried patio with a well; room ranges 4-5 m deep; ground floor lived in summer, upper in winter; a storage loft under a flat roof terrace with a parapet and a lookout | Small patio house; merchant's patio house with a lookout tower; the tenement court (corral) of one- and two-room cells round one patio; the corner house with a tile shrine |
| **The tower-house** (`old_town_spain.md` §6, `old_town_porto.md` §9) | The upper town | 7-10 m square, granite; cut down to its house's roof plus one floor, or full height (25-30 m; Bujaco 10 m square and 25 m) | Cut-down; full height (the landmark) |

### 5.3 Interiors, in three tiers

1. **Six key buildings, made by hand**, each a small level with several ways in of different kinds (`old_town_level_design.md` rule 3):

   | Building | Quarter | Ways in | What it holds |
   |---|---|---|---|
   | The tavern | The stairs | 4: the street door, the yard, an upper window off a roof, the cellar from the vaulted stream | Drinkers' seats (reserved), the off-duty watchman of the side job, the cellar's sealed door to the undercroft |
   | The tower-house | The upper town | 3: its door, the latrine chute, a leap from a neighbour's roof to its top | The landmark's climb and view; loot in its top room |
   | The merchant's house | The upper town | 4-5: the street door, the shop's door, the skylight over the stair, the rooftop lookout, the yard | The upper gate's key; the strongbox; ledgers and letters |
   | The watch house | The Carmo hill | 3: the barracks gate, the ruin's side through the cloister, the roof lookout | The sergeant's office, the armoury, the reserve asleep in the barracks, the drum |
   | The chapel | The upper town | 3: the nave, the sacristy, the belfry from the roofs | The silver altar walled up behind plaster (Porto's 1807 story) |
   | The walled garden house | The upper town, on the gorge rim | 3: the gate, the wall by the fig tree, the cistern channel | A private garden; the cistern under the upper gate (one of its four ways) |

2. **Ordinary enterable houses:** about one building in five or six, 1-3 rooms each, laid out by its family's real plan so its rooms can be reasoned about (the shop below, the kitchen at the top of a Porto house; the reception room to the street of a Pombaline flat). Each offers **at least two of**: a route (between terraces, or street to roof), a view worth scouting from, a story (one chain of objects and a note naming a neighbour), or a reward (loot, a lockpick, a flask refill). No house exists only for a key hunt (rule 18).

3. **Every other front is honest:** shutters shut, doors barred or boarded, lit windows. No door looks openable that is not (rule 22).

**Furnishing** from the period inventories in the reports: the shop's counter, scales and strongbox; the hall's damask chairs, card table and cabinet; curtained and folding beds, chests and coffers; the kitchen's hearth, oven, stone sink and water jars; the attic's trunks and pallets; the patio's well, trough and pots.

**Townsfolk's places, reserved:** about a third of the ordinary houses are marked lived-in, with their beds; the tavern's seats; work spots (the baker's oven, the tannery). They stay empty until the townsfolk sub-project.

---

## 6. Routes and layers

From `old_town_level_design.md`'s rules (numbers in brackets).

- **Streets:** 3-5 loops spiralling up the terraces; no dead end without loot, a view or a hatch (9). Public squares are open ground for getting bearings; the tavern has rules (behind the bar, the cellar); houses are private; the merchant's study and the watch's armoury are personal (20).
- **Roofs:** 2-3 chains per quarter, each 3-6 houses (25-60 m), broken at every lane and square; a break is crossed by a leap, a plank, a laundry beam, a house bridging the lane, or a pass through a house (6).
- **Below:** the vaulted stream under the stairs, the Baixa's sewer, the Judiaria's cisterns and a few linked cellars: 3-4 entrances in all (9).
- **Terrace steps:** each has at least two public connectors (stair-lanes, ramps) and one or two thief's (a climbable retaining wall, a cistern shaft, best of all a house with doors on two levels) (10).
- **Roofs are never fully safe:** every roof chain has a visible way up for the watch; two roofs are manned, the watch house's lookout and the Judiaria's terraces (7).
- **Scouting spots:** every stair head, square mouth and terrace edge has an unlit, parapeted overlook (11).
- **Sound:** surfaces taught side by side once; stairwells and shafts cut sound between floors so one noise does not wake a whole building; only the fountains and the tavern mask the player (15).

## 7. The watch, the night and the puzzles

### 7.1 The watch

The Guarda Real (`old_town_lisbon.md` §15): about ten men, plus the key buildings' households.

| Post | Men | Archetype (design) |
|---|---|---|
| The upper gate | 2 | Watchman, swordsman |
| The watch house: inside, and on its roof lookout | 2 | Watchman, archer |
| The lookout terrace | 1 | Watchman |
| Low patrol (Baixa and stairs), paired | 2 | Watchmen |
| High patrol (Carmo hill and upper town), paired | 2 | Watchmen |
| The sergeant: relights lamps, tries doors | 1 | Swordsman |
| The *sereno* in the Judiaria: lantern, pike, every door's key, a whistle on the hours | 1 | Watchman |
| The gate's relief, off duty in the tavern until his turn at the gate (GuardRota) | 1 | Watchman |
| The merchant's household: doorman, guard | 2 | Watchman, duelist |
| The tower-house | 1 | Watchman |
| The reserve, asleep in the barracks | 4 | Watchmen |

Loops readable in 45-90 s (16). A household's alarm stays inside its walls; only the watch spreads an alert (8).

### 7.2 The night's states

- **The night (normal):** the curfew bell has rung as the player arrives; anyone abroad is suspect; the Judiaria's gates are shut and the sereno opens them with his keys.
- **The alarm:** a full alarm brings the watch's drum. The reserve turns out of the barracks, patrols double, shutters close, the gates are manned. It lasts until the hunt is given up; the district remembers it (section 3A).

### 7.3 The upper gate (the main puzzle)

Four ways through (rule 4):
1. **The merchant's key**: the clean way.
2. **A hard lock** to pick.
3. **Over**: from the tower-house's roof onto the gate tower.
4. **Under**: the cistern from the walled garden house.

**The side job** (rule 24): the gate's relief, drinking in the tavern until his turn, owes the merchant; his IOU is in the merchant's ledger chest. Leave it on his table and, when he takes his turn at the gate, he leaves its postern unbarred. Delivering an item to a place changes a door's state: a small `job` marker (section 9).

**Every vital fact three or four ways** (rule 5): where the key is kept, when the merchant sleeps, when the gate changes guard, where the cistern runs. Each comes from a readable (a ledger, a letter, a notice), an overheard conversation (the talk director's `.talk` lines) and a clue in a room. Important doors and objects are lit, framed by the approach, or heard.

### 7.4 Lamps and the moon

Corner lamps on curved iron arms at street corners (`old_town_lisbon.md` §14) are lit only on dark nights: the night's moon decides, at load, whether they burn (marker `dark_only`). Wall shrines burn all night and can be snuffed. On a bright night the moon lights the whitewash; on a dark one the lamps light the corners and leave the middle of each block dark.

### 7.5 Loot and secrets

- **Loot:** the trade streets (gold and watches, silver, cloth); the merchant's strongbox; the chapel's walled-up silver; a little along the streets too.
- **Secrets:** the 1.5 m hidden house between two buildings (Porto's Casa Escondida); the alley along the old wall, bricked up long ago (Porto, 1802); the tower-house's latrine chute; the sewer under the Baixa.

### 7.6 Memory the player can see

On return (section 3A): burgled houses are boarded, with a notice on the door; the lamps the player doused are relit by the sergeant; a theft at the merchant's adds a man at the gate; after an alarm the district stays in its alarm state for a while.

---

## 8. The look and the sound

**The colour key:** azulejo blue and whitewash under the moon, with amber pools of lamplight.

| Quarter | Palette | Signature surfaces |
|---|---|---|
| The Baixa | Pombaline ochre and pale render, cream limestone frames | Azulejo fronts with framed openings and a double frieze; iron balconies; wave-pattern pavement in the square; painted shop signs |
| The stairs | Faded pastel render and whitewash, granite steps worn in vertex paint | Laundry, flower pots, jettied timber upper floors, tile shrine panels with oil lamps |
| The Judiaria | Brilliant whitewash with a red-ochre band at the foot, blue-tiled shrines | Bulging iron window grilles; iron patio gates leaking warm light into the lanes; green pots; cypress tops over the walls |
| The Carmo hill | Grey Gothic stone under the moon, cream limestone | The broken nave, the fountain's canopy, the lookout's pergola and azulejo benches |
| The upper town | Granite and relief-tile Porto fronts, iron balconies | Heraldic doors, tower-house crenellations, skylight drums on the roofs |

**Light:** the garrison's rules (small hot lights separated by real darkness): corner lamps, wall shrines, tavern doors, lit windows, the watch's lanterns; indoors, candles and oil lamps, and glazed fanlights leaking light from room to room. Vertex-baked shade as in the harbour; one atmosphere zone per quarter for its grade and fog. PS2-inspired, not a copy: dither, pixel grid and grading; no vertex snapping.

**Textures:** the user's own first (the azulejos, plasters, Portuguese pavement, golden ashlar, medieval floors, shutters and doors of the city spec's section 12); our own painted ones next (iron balcony rails and window grilles, patio gates, glazed fanlights, tiled street-name plates, shrine panels, tile borders and friezes, shop signs); a short buy list last, checked by a read-only agent, for the user to buy (cream limestone, a Lisbon pattern tile, interior floors and ceilings). Nothing from textures.com goes into git.

**Sound** (the user's packs and approved ones only; any new download shown to the user first): fountains mask noise near them and the tavern around its door; the curfew bell; the watch's drum on a full alarm; the sereno's whistle and the clap that summons him (he has no spoken lines: voices stay NOX Voices Essentials only); footsteps across pavement, granite, timber and tile.

---

## 9. Pipeline additions

**Markers** (`tools/level/markers.py`):
- `arrival` (where a player arrives from another district; facing).
- `exit` gains `to` and `arrive`.
- `light` gains `dark_only`.
- `readable` (a note, ledger, letter or notice: its text's id).
- `household` (a box: a key building's bounds, inside which its people's alarm stays; names its people).
- `door` gains `curfew` (shut at the bell; the sereno's keys open it).
- `job` (deliver an item to a box; a door's state changes).
- Townsfolk reservations: `home` (bed), `seat`, `work`.

**Rules** (`tools/level/rules.py`):
- Every exit's arrival exists in its destination's layout.
- Marker names are unique across districts (closes a deferred minor of the harbour).
- Every key building is reachable three ways or more, of different kinds (checked through route checks into its `household` box).
- Every terrace step has its public and thief's connectors.

**Generators and kits:** the four families as generators (sections 5.1-5.2), a room kit (room shells, stair cores, partitions, fanlights, furniture and props), the six key buildings, the terraces and retaining walls (terrain and kit), the street furniture (corner lamps, shrines, fountains, street-name plates, signs).

**Small systems the old town needs** (Godot):
- **Readables:** a frobbed note is held in the hands (the two-handed viewmodel) with its page shown; texts in one data file. Readable texts and overheard lines are drafted by us and gathered in one place for the user to rewrite, as the loading screen's words were left to the user.
- **The night's states:** the curfew bell, the drum, the reserve turning out, the alarm state.
- **Moon lamps:** `dark_only` lamps lit or not from the night's moon at load.
- **Keys for the sereno:** a guard carrying keys opens and shuts curfew doors on his round.
- **Households:** an alarm raised inside a `household` box reaches only its people.
- **Jobs:** delivery triggers.
- **Visible memory:** boarded doors and notices on burgled houses; the extra man at the gate.

## 10. Performance

The harbour's targets, for one district per map: **60 fps average, 99th-percentile frame under 25 ms at 1080p on the user's Mac, the map loading in under 15 s** (expected well under with the saved navmesh).

- A dense town hides most of itself: facades become occluders (from their colliders, as now).
- Interior contents draw only near (about 30 m) and when not hidden behind their shells.
- Fronts carry the detail; backs and party walls stay plain.
- Other districts are proxies or massing beyond about 60 m, in fog.
- The LightBudget's six shadows; the per-sector triangle budget (stage 2, 120,000), with quarters split into sectors of at most about 100 m.

## 11. Testing

- `tools/level/level.sh test`: the generators (doors, stairs and rooms meet the metrics; budgets; every room reachable), the new markers and rules against broken fixtures.
- **A transitions suite** (plan A): harbour to the stand-in old town and back; loot, doors, lamps and guards remembered; purse and tools carried; a chasing watchman follows through a gate; every exit has its arrival; the saved navmesh matches a live bake.
- **An old-town suite** (plans B1 and B2): the map loads and every marker resolves; every guard stands on the navmesh and reaches his route; every key building's ways in walked and climbed through the real controller; the roof chains and terrace connectors walked; the upper gate's four ways; the side job; a chase through the Sea Gate; the curfew and alarm states; memory after leaving and returning; light probes (moon, shadow, lamp) under both moons; the shadow budget.
- Stills of the key views judged at full size from many angles; the benchmark walk; every existing suite green, with the long four (cinema, intruder, showcase, talk) run alone.

## 12. Plans and order

Each plan is reviewed by the user before the next begins. Work happens in a worktree of its own (the harbour's polish continues separately in `city-harbour`).

1. **Plan A: districts as maps** (about 8-10 tasks): section 3A, tested with the stand-in old town.
2. **Plan B1: the old town playable** (split into B1a, the shell, and B1b, the night: section 16) (Arkane's order: the shell first, then the routes dug in): the generators, the room kit, the six key buildings, the terraces; the layout quarter by quarter; the watch, households, the night's states, moon lamps, the sereno's keys, readables, jobs, the upper gate's four ways, loot and secrets. The user walks it before any art.
3. **Plan B2: the old town's art pass:** textures and painted textures, detail on fronts, interiors furnished, shrines, signs, laundry and plants, light and sound; stills judged at full size; the benchmark.

## 13. Risks

| Risk | Handling |
|---|---|
| 12 ha at full detail is a lot of building | Generators on one grid with one quirk per house; hand work only on the six key buildings and where the player pauses |
| Interiors and density may cost frames | Occluders from facades; interiors drawn near only; the benchmark in B1, not only B2 |
| Memory across districts has many cases (bodies, searches, followers) | One save contract on every changeable node, each with a test; the stand-in old town before the real one |
| A chase following through a gate has edge cases (a dead follower, a gate re-crossed) | Followers carried as ordinary saved guards of the destination; tested both ways |
| Another session works in the harbour's worktree | The old town in a worktree of its own; its shared files (the wall, the Sea Gate) merged with care |
| The puzzles' facts depend on writing the user may want to do | Texts drafted and gathered in one file for the user to rewrite |

## 14. Success criteria

1. **Plan A:** the harbour and the stand-in old town join both ways through every gate, remembering what was done and carrying purse, tools and health; a chasing watchman follows; the harbour loads faster than its 13.8 s; every suite green.
2. **Plan B1:** the user walks the old town from each of the harbour's gates to the upper gate, through each of its four ways, and into each key building by at least three ways; every suite green.
3. **Plan B2:** the old town passes the user's look review at full size; 60 fps average, p99 under 25 ms, load under 15 s; every suite green, with no script errors.

## 16. Amendments of Oct 3 2026

After plan A (merged, `origin/main` 5795638), the user decided:

1. **The harbour's polish lands on main first.** That work, `docs/superpowers/specs/2026-10-02-harbour-polish-design.md`, is not yet merged. It brings the haze, the far land, the colossus, the comet, the keep's balefire and its pillar, the gorge's corpse-lights, lit windows, chimney smoke, loose bodies, the roofed shadow layer, `kit_interiors` and our painted facades. Plan B1 starts from a main that has it, merged with plan A's district maps. The city's sky and distance belong to every district map.
2. **Plan B1 splits in two**, each reviewed by the user:
   - **B1a, the shell:** the four house generators, the room kit, the terraces and the ground below, the street furniture, the six key buildings and the Carmo ruin, all five quarters with their streets, roof chains, terrace connectors and ways in and out, the massing redrawn round the old town, and the old town seen from the harbour. The user walks it empty, with no guards and no puzzles.
   - **B1b, the night:** the watch, households, curfew and alarm, moon lamps, the sereno's keys, readables, jobs, the upper gate's lock and key, loot and secrets, and visible memory.
3. **The old town's own uncanny touches.** These sit beside what it sees in the distance: the comet, the colossus, the balefire and the gorge's corpse-lights. Like the harbour's, they stay restrained and are never explained:
   - **The comet in the tiles.** Azulejo panels and wall shrines show the red comet over the city, and the forgotten king (the colossus) as a saint. They are painted by us. After 1755 small devotional panels were put on buildings to ward off new disasters (`old_town_lisbon.md` §6). Here the city has lived under the comet a long time.
   - **The ruin's red light.** While the comet is in the sky, the roofless Carmo nave's altar is lit red by it through the broken tracery. The watch won't stand inside the nave (B1b).
   - **Corpse-lights on the rim.** The gorge's corpse-lights drift up into the walled garden houses on the west rim. Stared at, they go out, as in the gorge.
   - **The balefire on the towers.** From the upper town the keep is close. Its cold green-white light falls on the tower-house tops and the upper gate, and its pillar stands over the whole district.

## 15. Amendments to the city spec

To be recorded in `2026-09-28-city-on-the-rock-design.md`:

- **Program step 2** ("the city in blocks": seven districts greyboxed) is replaced by: **districts as maps, then the old town finished**; the other districts follow one at a time, each finished, in an order to be chosen.
- **Districts are separate maps** joined by loading transitions, each remembering what was done; the "scale systems" of section 10 reduce to the offline navmesh (built here).
- **The period** is a timeless Iberian mix, medieval to the 19th century, Pombaline Lisbon and azulejo fronts included.
- **The old town** is about 330 × 360 m and 82 m of climb (its section 5.2 row and pacing grow accordingly: about 30-40 minutes).
- **Townsfolk** (a civilian system: schedules, homes, reactions) become their own sub-project after the old town.
