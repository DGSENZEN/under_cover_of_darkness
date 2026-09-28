# The Garrison: Design

**Date:** 2026-09-27
**Status:** design approved in conversation; this document awaits the user's review.
**Program:** the first of five sub-projects the user ordered (the level, then Kurosawa rain and the silhouette look, NPCs you can read, cinematography pass 3, night pacing and sound). Together they make the showcase a full tech demo of the NPC system.
**Branch:** `garrison-level` (worktree `.claude/worktrees/npc-showcase`), from `showcase-environment` (night and weather, aba0b31), which it builds on.
**Builds:** the canal-quarter spec's section 6 level pipeline (`tools/level`), once, for both programs.

## 1. Goal

The user, having watched the night in the yard:

> we need a more detailed level for the barracks. It's too simple, we need inner chambers, corridors, more awesome lighting settings where we can truly expand upon our shots and director tech ... better looking terrain, more details, more stuff that can give an idea towards a full-fledged tech demo of the capabilities of our npc system.

and: "we want to have stylized lighting, good atmosphere, so don't be lazy, go all out on this with the knowledge we are going for that ps1-ps2 look."

## 2. Decisions

| Question | Decision |
|---|---|
| Scope | A new, bigger garrison; the showcase's night is re-staged in it, in six acts (section 4). |
| Pipeline | The canal spec's Blender-to-Godot level kit (`tools/level`): modular pieces, gameplay as markers in Blender, one command to check, export, assemble and bake. |
| Stages | Stage 1: the pipeline and the whole garrison in plain blocks with the six-act night running in it. Stage 2: the art pass. Each is shown to the user. |
| Look | Stylized PS1–PS2 lighting and atmosphere: vertex-painted shading, low-resolution photo textures, lighting set pieces per space, graded zones, fog, shafts and coronas (section 6). |
| Chapel | A tall gothic nave after Gloomwood's Hightown chapel (the user's reference): stained-glass saints throwing coloured shafts through dust, carved relief panels, iron candle chandeliers, dark pews, a red patterned runner. |

## 3. The garrison

A walled keep on the canal bank at the edge of the town, fitting the skyline (the town to the north and east, the canal to the south, trees to the west). About 60 × 50 m inside the walls, with ground outside on every side. Metrics are the canal spec's section 5 (the player 1.0 × 2.0 m, openings ≥ 1.2 m, stairs 0.3 m treads and 0.2 m risers, guard routes ≥ 1.0 × 1.8 m, ≥ 2.3 m where the brute goes; storey 3.0 m floor to floor, outer walls 0.4 m thick, partitions 0.2 m, doors 1.2 × 2.2 m).

| Space | Where | What it holds |
|---|---|---|
| Courtyard | Middle, about 32 × 26 m | The fire and its benches, the well, the woodpile, a cart; cobbles with drains and puddle hollows; a covered colonnade along the west side (arches on columns, alcoves). |
| Gatehouse | South wall, onto the quay | An arched passage (4 m wide, 5 m high) with a portcullis; a guardroom either side with arrow slits; the alarm bell; stairs to the wall-walk. Symmetric. |
| Walls and towers | All round | Curtain walls 6 m high, a crenellated wall-walk at 5 m; corner towers; the watchtower (north-west, 16 m) with a spiral stair and the archer's lookout. |
| Barracks wing | East, two storeys | Below: the mess hall (long tables, a great hearth), the kitchen and a pantry, a corridor the length of the wing. Above: the dormitory (bunks in rows, a stove), the captain's chamber (map table, bed, a window over the yard, a stout door), a gallery. Stairs at both ends. |
| West range | West, behind the colonnade | The armoury (racks, a grindstone) with a small drill yard of straw men; the storehouse (crates, the carrier's work); a cellar below the storehouse (barrel vaults, near black). |
| Chapel | North | A gothic nave about 8 × 18 m, 12 m to its ribbed vault; lancet windows of stained glass down both sides and three tall ones behind the altar; relief panels high on the walls; two iron chandeliers; pews either side of a red runner; a side door to the barracks gallery. |
| Postern | North-east corner | A small door onto the canal towpath. |
| Outside | All round | The quay (south): water, moored boats, posts, a crane; a lane of house fronts toward the town (north and east); a grassy bank with trees and bushes (west); the towpath along the canal. Real ground height throughout. |

Hiding places are part of the layout, not left over: colonnade alcoves, under both barracks stairs, behind crates and barrels, the cellar, bushes, the dark stretches between torch pools, the roofs of the west range, the chapel's side aisles.

## 4. The night in six acts

The story (`ShowNight`) is re-staged in the garrison; its beats are placed by the level's named marks, not by coordinates in code.

1. **The Watch at Rest.** Men round the courtyard fire; posts at the gate, on the wall-walk and in the watchtower; men eating in the mess; one asleep in the dormitory. The intruder comes in over the towpath wall.
2. **A Knife in the Dark.** He waits his moment; the kill falls in the dark colonnade as a cloud covers the moon (Night's veil); the witness.
3. **The Cry.** Grief gathers over the body; the cry; the bell rings in the gatehouse; men pour out of the barracks with lanterns; the captain divides them.
4. **The Divided Hunt.** Groups of three or four, each sent to its own area (the barracks wing; the west range and cellar; the walls and towers; the courtyard and quay), search it. The intruder, knowing he has been found, moves by stealth through the barracks, from hiding place to hiding place, between the groups.
5. **The Chapel.** One group finds him in the chapel. They fight; the intruder is left standing.
6. **The Escape.** He tries the captain's chamber and fails (barred, and the captain's men coming). He runs for it, and the night ends one of three ways: over the wall into the canal, a desperate leap (escape); cornered and killed (overwhelmed); he survives the fight in the courtyard, wounded but victorious (victor).

The weather follows (Night, as before): I clear; II clear, the veil for the knife, drizzle with the witness; III shower; IV rain; V storm outside, lightning through the stained glass; VI storm, easing to fog at the end.

The divided hunt needs one new behaviour: a hunt split into groups, each confined to a marked area (the hunt areas, section 5.3), searching it with the existing coordinated search. Making the orders and their obedience readable on screen is sub-project 3.

## 5. The pipeline (`tools/level`)

### 5.1 Commands and files

- `tools/level/level.sh kit | build <level> | check <level> | export <level> | preview <level> | test`, Python run by headless Blender (5.x), modelled on `tools/props` and `tools/wardrobe`.
- `assets/level/source/kit.blend`: built by `level.sh kit` from recipes (`tools/level/kit_recipes.py`); never hand-edited.
- `assets/level/source/garrison.blend`: assembled by `level.sh build garrison` from a layout recipe (`tools/level/layouts/garrison.py`), then the user's to edit in Blender.
- `assets/level/garrison/`: the exported glTF per sector plus a JSON manifest.
- `maps/garrison.tscn`: the assembled scene (sectors, collision, markers resolved to nodes, the baked navmesh, `Night`), and `maps/garrison.gd`, the showcase level script (the old `npc_showcase.gd`'s job, reading marks instead of coordinates).

### 5.2 The kit

Pieces on a 0.25 m grid, each an object `kit_<family>_<variant>` with a visual mesh, collision children (`<piece>-col`, boxes or convex parts), a `surface` property (stone, wood, metal, carpet, grass, dirt, gravel, water) and sockets as child empties (torch brackets, door hinges, candle points).

Families for the garrison:
- walls: ashlar, rubble, plaster, half-timber; plain, window, door, arch, corner, crenellated top, arrow slit;
- floors: cobbles, flagstones, boards; ceilings and beams;
- stairs: straight, spiral (the watchtower), with landings;
- roofs: slate and clay, gables, a ridge, dormers, chimneys;
- columns and arches (the colonnade), buttresses, vault ribs (the chapel, the cellar);
- openings: doors (plain, studded, the captain's), the gate and its portcullis, lancet windows with stained glass, shutters;
- quay pieces: quay wall, steps, mooring posts, the crane;
- dressing: bunks, long tables, benches, pews, the altar, weapon racks, straw men, a grindstone, barrels, crates, sacks, the cart, the well, banners, chandeliers, candle stands.

Stage 1 builds every piece as plain blocks at its true size (kit v0); stage 2 models them low-poly under the same names (kit v1), so the level updates without re-placement.

### 5.3 Markers

Gameplay is placed as empties (or box volumes) with a `ucd` property; the object's name is its id. The garrison uses the canal spec's markers (spawn, guard, route, door, light, bell, ladder, landmark, trigger, sector, water) plus:

| `ucd` | Properties | Becomes |
|---|---|---|
| `station` | `kind` (sit, eat, sleep, rummage, carry, chop, lean, pray, drill), `chest`, `drop_to` | A `GuardStation` |
| `hide` | `label` | A hiding spot the intruder's brain can use |
| `hunt_area` (a box) | `label` | An area a hunt group is confined to |
| `vantage` | `lens` (long, medium, or empty) | A `cine_vantage` marker for the Cinema editor |
| `zone` (a box) | `grade`, `fog`, `fog_color` | An atmosphere zone (section 6.3) |
| `mark` | — | A named spot the story uses (`ShowNight` reads marks by name) |
| `light` | adds `kind` chandelier, window_shaft; `cookie` | As the canal spec, plus the new kinds |

The schema lives in `tools/level/markers.py`; the check and the Godot assembler both read it (Godot through an exported JSON copy).

### 5.4 Export, assembly and the navmesh

- Blender exports each sector collection as glTF, custom properties as extras.
- A headless Godot step (`tools/level/assemble.gd`) turns each marker into its node, gives collision children static bodies with their `surface` metadata, and saves `maps/garrison/<sector>.scn`; `maps/garrison.tscn` instances them.
- The navmesh is baked offline by a headless tool scene (doors ignored, as `NavBaker` does now) and saved as a resource the level loads; one region per sector.
- `level.sh export garrison` does all of it.

### 5.5 The check

`level.sh check` refuses to export when a rule fails, naming the object and the rule: openings, stairs and headroom against the metrics; every route and door valid; every station, hide and hunt area placed on walkable ground; every `ucd` known with its required properties; triangle budgets per sector (60,000 in stage 1, 120,000 in stage 2). `level.sh test` runs each rule against a deliberately broken fixture. The traversal checks (hang lips, gaps) come with the canal mission.

## 6. The look

### 6.1 Painted in vertex colour

Every piece carries shading baked into its vertices in Blender, the PS2 way (`tools/props`' bake, extended): ambient occlusion, grime, soot above sconces and hearths, damp and moss at wall feet, wear on stair edges; a warm tint near torch sockets, a cold one on the moon side. The level shader multiplies it into the texture. The real lights stay the only gameplay light: the lightgem and the guards agree with what is seen.

### 6.2 Textures

The user's textures.com photos, converted by `tools/textures/ps2ify.py` to 128–256 px (512 for a few hero surfaces: the chapel glass, the reliefs, the gate), drawn nearest-filtered through the Retro screen; kept out of git (the repository is public), each slot with a flat-colour fallback (`Materials`). Slots come from what the user has: stone walls (ashlar, rubble, overgrown), plaster (white dirty, damaged), Tudor half-timber, medieval floors and patterned tiles, cobbles and ground, wooden planks and studded doors, slate and clay roof tiles, the stained glass, reliefs and ornament borders, moss, ivy, leaking decals, rust.

### 6.3 Lighting set pieces and zones

Each space is lit on purpose, with real lights placed as `light` markers:

- **Chapel:** moonlight through the stained glass as coloured shafts (spot lights projecting the glass as a cookie, caught in a dusty fog volume); two iron chandeliers of candles; the reliefs lit from below by candle stands; the rest dark red and black.
- **Corridors:** sconces spaced so torch pools alternate with real darkness (silhouettes, and somewhere to hide).
- **Mess:** the great hearth throwing long shadows across the tables; candles on them.
- **Courtyard:** the fire, the lit windows of the barracks, torches at the doors; the moon and its clouds (when a cloud covers the moon, it falls to shadow and torchlight).
- **Gate passage:** one brazier between symmetric arches.
- **Cellar:** near black; one lantern.
- **Dormitory:** a banked stove's glow; moonlight through a window.

Atmosphere zones (`zone` markers) each carry a colour grade, a fog density and a fog colour; the environment eases into a zone's as the camera enters it (over about a second). Warm amber indoors, red and gold in the chapel, cold blue-teal outside, a sick green-black in the cellar. With them: dust motes in the shafts, embers off the hearth and the fire, drips off the eaves in rain, the coronas on every flame (lights and fire).

### 6.4 Outside

Vertex-blended ground (grass, mud, gravel, cobbles) with tufts; PS2-style bushes and trees as low-poly cards (which hide a man); the canal as dark water catching the lights in streaks; the house fronts of the lane with lit windows.

### 6.5 Life in it

Detail doubles as the men's stations: bunks to sleep in, mess benches to eat at, racks and straw men to drill at, crates to carry, the woodpile to chop at, chapel pews to pray at (a new pastime, `pray`: kneeling, head bowed, a murmured line now and then). Banners, barrels, carts, straw, candles and grime decals everywhere else.

## 7. Stages

**Stage 1: the garrison in blocks, the night in it.**
- `tools/level` with its commands, the check, the markers and `level.sh test`.
- Kit v0 (every piece as blocks at its size); the garrison laid out from its recipe with every space in section 3, every marker placed (guards and their posts and routes, stations, lights, doors, the bell, hide spots, hunt areas, vantages, zones, the story's marks).
- The assembled `maps/garrison.tscn` with its baked navmesh and `Night`.
- The six-act night re-staged (section 4), including the divided hunt, the chapel fight and the three endings; the `pray` station.
- The showcase's entry points (`tools/record_showcase.sh`, the stills stage, `--fps-report`) move to the garrison. The old yard (`maps/npc_showcase`) stays in the repository.
- **Done when:** `level.sh check` and `export` run clean; the level and showcase suites pass on the garrison; stills of every space exist; the user has seen a recorded night.

**Stage 2: the art pass.**
- Kit v1: every piece modelled low-poly under its name, with sockets; foliage cards; the chapel's glass, reliefs and chandeliers.
- The vertex painting (6.1), the textures (6.2), the lighting set pieces and zones (6.3), the outside (6.4), the dressing (6.5).
- **Done when:** the budgets hold; the frame-rate report averages 60 fps or more at 1080p; the stills of the key views (the gatehouse, the courtyard in moonlight and under cloud, the colonnade, a corridor, the mess, the dormitory, the chapel, the cellar, the quay, the watchtower) pass the user's look review.

## 8. Testing

- **Pipeline:** `level.sh test`, every check rule against a broken fixture; the assembler's own checks (every marker resolved, every collision child a body).
- **A level suite (`tests/level_test`):** the garrison loads; every marker resolved to its node; every guard post, route point, station and hide spot on the navmesh and reachable from the courtyard; doors open for guards; every light marked is a light; every zone's grade eases in when the camera enters.
- **The showcase suite on the garrison:** the six acts play in order; the divided hunt sends at least three groups, each into its own hunt area, and the intruder moving through the barracks unseen by any guard for at least 20 s of the act; the chapel fight is won by the intruder; each of the three endings is reached from its act's start; the existing checks (the camera, the weather, voices, gatherings) still hold.
- **By eye:** a stills stage of every space (stage 1) and of the key views (stage 2); a recorded night.

## 9. Performance

The garrison's lights are many: the lights-and-fire `LightBudget` (six shadows) holds, the rest unshadowed; small props get visibility ranges; occlusion culling from the kit's walls. Target: 60 fps average at 1080p (the showcase's `--fps-report`), checked at the end of each stage.

## 10. Out of scope

- The Kurosawa rain rework and the silhouette look (sub-project 2).
- Making orders, their obedience and conversations readable on screen (sub-project 3); the divided hunt gets only the behaviour the story needs.
- The third camera pass (sub-project 4): the level provides vantages and light set pieces for it.
- Pacing polish (the murder's build-up, the grief) and the sound pass (sub-project 5).
- The canal mission's traversal checks, saving and mechanisms.

## 11. References, and what we take from them

Studied on 2026-09-27 at the user's request ("look for references as well to improve the general look"): Gloomwood's store screenshots and its Hightown chapel; The Dark Mod's media page; FILMGRAB stills of Seven Samurai, Throne of Blood and Ran (Kurosawa) and Andrei Rublev (Tarkovsky). Links: store.steampowered.com/app/1150760/Gloomwood, youtube.com/watch?v=u7gNuPdrdpU, thedarkmod.com/media, film-grab.com/2016/09/03/seven-samurai, film-grab.com/2016/09/24/throne-of-blood, film-grab.com/2017/03/04/ran, film-grab.com/2025/06/04/andrei-rublev.

Rules the garrison follows (stage 1 lays them out, stage 2 dresses them):

**Light (Gloomwood, The Dark Mod, Andrei Rublev)**
1. Light is small and hot: every source has a near-white core and a short, steep falloff; warm pools are separated by real darkness, never by a flat fill.
2. Lit windows are sparse warm accents on dark fronts, about one in four; the moon tints stone teal-blue, and low shots keep the moon or a lit sky gap in frame.
3. Candles come in clusters (three to seven) on floors, tables, the altar and window sills.
4. Coloured light is rare and deliberate: the chapel's glass red and gold, one green lantern in the cellar.
5. Light from below where it is dramatic: the hearth, the braziers, the candle stands under the chapel reliefs; sparks and embers with it.

**Composition (Kurosawa)**
6. Symmetry is built in: the gate passage, the chapel nave, the mess hall's long axis and the captain's chamber are symmetric about their centre lines, so a camera on the axis frames them square.
7. Foreground to frame through: palisade fences, lattice screens, the colonnade's columns, the cart, doorways, hanging banners; the vantage markers stand behind them.
8. One heraldic colour, crimson, on banners in rows and on the men's cloth, against muted stone and wood.
9. Fire behind lattices and fences throws silhouettes: a brazier behind a lattice screen in the gate passage, the courtyard fire seen past the cart and woodpile.
10. Figures small in large dark spaces: tall interiors (the chapel, the mess hall two storeys high at its hearth end) with one pool of light in them.

**Ground and air (Seven Samurai, Andrei Rublev)**
11. The ground has texture that weather changes: mud patches in the courtyard and outside that darken and shine in rain, puddle hollows, straw, drains; water in frame wherever it can be (puddles, the canal, drips off eaves).
12. Rain reads as a grey veil that washes out the background so dark figures stand against it (for sub-project 2); mist lies over the ground outside.

**Space (Tarkovsky, Thief)**
13. Enfilades: doorways in a line through several rooms (the barracks' ground floor, the upper gallery), so a camera can track or look through space after space.
14. Verticality and clutter: beams, balconies, railings, stairs, stacked roofs, chimneys; low angles up tall fronts.
15. Every place a fight or a kill can happen has a lighter backdrop somewhere behind it (a lit wall patch, a sky gap, fog, a window), so figures read as silhouettes.
