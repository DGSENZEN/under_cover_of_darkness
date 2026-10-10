# The Eclipse City: Design of the City Frame (sub-project 0)

**Date:** 2026-10-09. **Status:** approved in brainstorming, section by section; written for the user's review before planning.

**Replaces:** the Iberian "city on the rock" program (`2026-09-28-city-on-the-rock-design.md`, `2026-10-02-old-town-design.md`). On Oct 7 2026 the user moved the whole setting to an alternate-universe 1920s Mexico City. The harbour, old town and garrison maps stay in the repo, unchanged, as references and test beds.

**References:** the world-building bible and its seven research notes of Oct 7 2026: `docs/superpowers/refs/mexico_city/` (`bible.md` and the seven notes). They hold architecture, materials, art, folklore, 1920s life, fiction and music, art-direction case studies, licence rules, with links. Every historical claim below that is not a design value comes from them.

---

## 1. Goal

The user (Oct 7 and Oct 9 2026):

> I want this to be very inspired by Post-Colonial Mexico, with a mix of its own folklore and gothic horror ... a mix of Grim Fandango's very Mexican flavoured New York and CDMX, with colonial touches and a lot of Deadlock inspirations ... a completely alternate universe 1920's.

> Let's focus on being just like Deadlock where each map and sector is unique, has very specific things that make each part much more filled with the sauce.

The game is a small, self-contained open world: a stranger Dishonored with mystery and investigation, melee, magic and diversion over the existing stealth systems, plus Grim Fandango's puzzles and dialogue. Three districts are showcased first: the **Zócalo**, **Lomas de Chapultepec** and **Roma**. Each must feel very different, and they are joined by shared threads and the Metro.

The first finished version is an **explorable art slice**. Each district is walkable and traversable, with ambient life and the Metro between them, but there are no missions yet. It is judged on look, mood and movement.

This spec covers **sub-project 0, the city frame**: the premise, the shared threads, the art-style method, the shared kit, the Metro, the edge of the world and the sky, and placeholder pockets. Each district then gets its own spec, plan and build, in the order **Zócalo, Roma, Lomas** (Roma and Lomas order to be confirmed after the Zócalo).

## 2. Decisions (from brainstorming)

| # | Decision |
|---|---|
| D1 | Explorable art slice first: no missions, no guards required; ambient life, traversal, the Metro |
| D2 | Geometry: a drawn top-down plan per map that the user approves first; every building and kit piece modelled deliberately in Blender from reference; placement from an authored layout, never rule-generated lots |
| D3 | The world broke at the **Eclipse of 10 September 1923** (a real total solar eclipse that crossed Mexico): a total, temporary merging of dimensions that comes once a thousand years. It tore rifts beneath space-time, and things seeped in from other realities, past and future. The rifts **already happened**: no rift sites appear in the maps |
| D4 | The city broke into **pockets** floating in a void. Only the oldest layer, the underground (colonial vaults on Aztec temple shells), still joins them |
| D5 | **Each district bleeds its own** anachronism over the 1920s base (section 4) |
| D6 | The map's edge is **the brink**: streets break into floating chunks and haze; the other districts hang in the void beyond |
| D7 | **The Metro** links the districts: real lines and stations, ridden in a car you can walk in, the load hidden by the ride |
| D8 | The Zócalo's novel transport (a future bus line) is **set dressing only**, not a way between maps |
| D9 | Maps are big and expansive: about **500-700 m across** of playable ground each |
| D10 | Texturing: a **blend of hand-painted atlases and a shader-led painterly look**, tuned in a style lab before any kit is built at volume |
| D11 | The user writes **all words** and paints the **glyphs, plaques and broadside layouts**. Claude builds the surfaces they go on, with canvas templates. **VFX are made in house**; nothing downloaded (memory: no free VFX) |
| D12 | Buildings are **well made, not overkill**: a modular kit, each family taken from real-world references, so the player thinks "this looks like X", but the world has changed it |

## 3. The premise and the shared threads

### 3.1 The Eclipse and the seepage

- The foundation is the 1920s, unchanged: trams, lime-washed walls, Calles-era politics, pulque, the Cristero silence of the churches.
- Foreign things have **crashed into** that base, and they look foreign and repurposed, not seamless. Example: a 1980s terminal in a carved wooden case with brass knobs someone added.
- Aztec cosmology grounds the event: in Aztec belief the Tzitzimimeh (star demons) descend during an eclipse. How much of this is spoken in the game is the user's writing.

### 3.2 Threads: the same thing in every district, dressed differently

| Thread | What it is | How it varies by district |
|---|---|---|
| **The Company's lamps** | One lamp family owned by the Light Company that keeps the pockets lit | Zócalo: cast-iron deco. Lomas: garden bollards and hanging globes. Roma: converted French gas lamps |
| **The Metro entrance** | One kiosk design: iron and glass, Guimard-style Paris Métro crossed with an Aztec stepped fret | Station tile inside in the district's line colour |
| **The causeway stone** | A band of old dark basalt paving running through each district toward its station: the thread underfoot, the way home | Its condition and setting |
| **Two-name street plaques** | Real in the 1920s, when the city renamed its streets; here the second name dates from after the break | Plaque surface per district; the user paints them |
| **Station glyphs** | A glyph per station, in the spirit of the Metro's pictograms (Lance Wyman's 1969 system, itself drawn from Aztec glyphs; his designs are in copyright, so ours are new) | The user paints them |
| **Broadsides** | Posada-style news sheets pasted in all three districts, the same news everywhere | The user paints the layouts and writes them |
| **The void sky** | The other districts hang in the void, seen from each | Section 6 |
| **The cornered moon** | The eclipse never fully let go: the moon wears a permanent black corona and casts a thin, wrong light | The same moon everywhere; haze colour differs |

## 4. The three districts (identity sheets; each gets its own spec)

| | **Zócalo** (the hub) | **Lomas de Chapultepec** | **Roma** |
|---|---|---|---|
| 1920s base | Colonial plaza: a leaning, sinking cathedral; the palace; arcades with public letter-writers; the pawnshop; the Inquisition palace a block away | A real 1922 development sold as "Chapultepec Heights": an American-style garden city of California colonial and New York revival houses on wooded ravines | Porfirian French mansions and English villas, Art Nouveau, mansard roofs, boulevards, spiritist salons |
| Its bleed | **The future**: green-phosphor terminals in the bureaucracy, cars from the 1980s and beyond, novel transport, steam-and-magic machinery | **The deep past and the wild**: Ice-Age beasts of the Valley of Mexico (mammoths really lived there), overgrowth, ancient forest swallowing lawns | **An Old-World gothic reality**: gaslight fog, catacombs, things from a dead Victorian/Parisian elsewhere; the Mexican-gothic mood |
| Movement | Mostly flat and easy to cross: arcade roofs, market awnings, tram lines, crowds | Vertical: ravines, terraced gardens, stepped lanes, water towers, cliff houses, trees | Horizontal and vertical: boulevards at street level, plus mansard roofscapes, chimneys, balconies and courtyards above |
| Life | Crowds, markets, trams, broadsides, many things at once | Wildlife, sprinklers, gardeners, strange events in the hedges | Few people, fog, séances behind windows, a watchful quiet |
| Seen from the void | The leaning towers and a huge machine or antenna | A colossal tree or a beast's skeleton on the hill | A witch-house tower (after the real Casa de las Brujas) and a forest of chimneys |
| Colour | Grey stone, gold, phosphor green | Eucalyptus green, stucco cream, terracotta | Plum, verdigris, gaslight amber |
| Station | **Zócalo**, Line 2 (blue): the grand station under the plaza | **Auditorio**, Line 7 (orange): small, perhaps a funicular up the slope | **Insurgentes**, Line 1 (pink): a Parisian-style station |

Rule: real landmarks are **remixed, never copied** (the bible's INAH monument-reproduction risk). The leaning cathedral reads as the cathedral, but it is ours.

## 5. The Metro

### 5.1 In the world

Mexico City's real Metro opened in 1969. Here it is itself seepage: the Eclipse dropped the future network into the colonial tunnels, with its orange rubber-tyred trains (the MP-68 type), tiled stations and line colours. Nobody built it. The Light Company runs it, and its 1920s staff patch it with brass and wood.

### 5.2 Lines and routes (the real network)

| Route | Path |
|---|---|
| Zócalo to Roma | Line 2 to **Pino Suárez**, Line 1 to **Insurgentes** |
| Roma to Lomas | Line 1 to **Tacubaya**, Line 7 to **Auditorio** |
| Zócalo to Lomas | Line 2, Pino Suárez, Line 1, Tacubaya, Line 7 |

And each route reversed. Since the break the tracks have **fused**: the car changes lines without the player changing trains, and its line indicator flips colour.

**Ghost stations:** the network's other real stations along each route flash past as dark platforms drifting in the void between the vaults: still named and tiled, their districts gone. Each route passes its own real stations in their real order. The ghost stations on each leg:

| Leg | Ghost stations, in order |
|---|---|
| Line 2, Zócalo to Pino Suárez | none (adjacent) |
| Line 1, Pino Suárez to Insurgentes | Isabel la Católica, Salto del Agua, Balderas, Cuauhtémoc |
| Line 1, Insurgentes to Tacubaya | Sevilla, Chapultepec, Juanacatlán |
| Line 7, Tacubaya to Auditorio | Constituyentes |

The station lists are to be checked against the current official network map when the route data is written.

### 5.3 Boarding and the ride

- **Every district map contains its own station:** the kiosk at street level, stairs, a ticket hall, a platform with a car waiting.
- **The route board:** a diegetic line map with a lever per destination. No menu screen.
- **The ride is one scene, built once and reused.** The car stays still while the tunnel scrolls past, so the player walks freely in the car without moving-platform physics. The windows run a fixed sequence:
  1. colonial brick vaults
  2. the Aztec temple shells stacked in the dark
  3. cracks opening onto the void: ghost stations and the drifting districts, with the interchanges marked as the indicator flips colour
- **The load is hidden by the ride.** The destination map loads in the background during the ride, which lasts about **30-40 s** and holds longer in the vaults if the load has not finished. There is no loading screen. The doors open onto the destination's own platform, which belongs to that district's map; the car there is placed in the same pose as the ride's, so the swap is not seen.

### 5.4 Fitting the existing code

- The Metro is a new kind of gate in the existing district system: `scripts/Level/Districts.gd` (registry, `data/districts.json`), `CityState` (each district's state as left; what the player carries) and `DistrictMap` (the map base).
- `data/districts.json` gets the three new districts plus the line and station data. Its `start` moves to the Zócalo, and the Iberian maps leave the registry.
- No guards follow the player onto the train in this slice.

## 6. The edge of the map, the sky, and scale

- **The brink.** Each map ends where the city tore. Streets run out, the paving breaks into floating chunks (a slab of cobbles, half a house, a lamp still lit) that thin into a luminous haze. It is a real drop with nothing hidden. **Falling in** wakes the player beside the nearest Company lamp after a short fade. There is no death in this slice.
- **The sky.** The other two districts hang in the void at impossible angles, slowly turning: from the Zócalo, Roma's chimneys upside-down above the cathedral, Lomas's colossal tree on its side in the haze. These are low-detail stand-ins using the existing proxy mechanism (`DistrictMap` already shows the other built districts' proxies), **placed by hand per map**. Belts of ghost-station fragments and debris drift between them.
- **Night only.** The game is played at night. Each district has its own weather and haze colour under the cornered moon, built on the existing `Night` / `NightSky` systems.
- **Scale.** About 500-700 m across of playable ground per district. For reference, the real Zócalo plaza alone is about 220 × 240 m, so the hub is the plaza and several blocks around it. Detail loads by distance through the existing view-range and stand-in system (`Distance.gd`). No streaming within a map for now; a district that outgrows one scene solves that in its own spec.

## 7. Art style and how the buildings are made

### 7.1 The style: painted atlas blended with a painterly shader

- **Base:** hand-painted texture atlases at the game's PS2-era resolution, with light, grime and wear painted in (the Grim Fandango side).
- **Over it:** a shader-led painterly layer: a brush-stroke projection plus palette mapping, tied into the existing dither and screen grid (`Retro.gd`, `retro_psx.gdshader`, `retro_screen.gdshader`) (the Deadlock side). No vertex snapping (memory: PSX-inspired, not a copy).
- **Per-district palettes** (section 4) drive the palette mapping.

### 7.2 The style lab: step 1, before any kit at volume

One hero piece, **the Metro kiosk plus one Zócalo arcade bay**, is built and textured in the blended style. Variants differ in **how much the shader does over the painted base**: for example painted-led with a light brush pass; an even blend; shader-led with flat painted colour fields. They are shown side by side in-game, at night under the cornered moon and in a daylight check. The user picks or adjusts, and the result becomes **the texturing pipeline for every kit after it**: atlas size and texel density, what is painted versus what the shader adds, and the palette mapping per district. Nothing else is built at volume until the lab is settled.

**Result, revised (the user, Oct 9 2026): the shader-led blend as variant D, with a warmer ramp.** Painted light through a painted light ramp (textures/painted/eclipse/ramp_zocalo.png: dusky violet shadow, warm stone, amber cream; the user may repaint it), painted ambient 0.15 (sky above, ground's bounce below), rim 0.25, the Company lamps throwing painted pools (lamp_pool.png). The brush tile was redrawn after the user's reference (soft, sweeping dry-brush plaster). Brush-stroke normals were built and removed ("gritty"): strokes are colour only. The frame's palette pull (Retro.palette_pull) exists but is off. Superseded below: the first verdict, "even".

**Result (the user, Oct 9 2026): the "even" blend, the paint as it is.** Shader: paint_mix 0.25, stroke_strength 0.08, palette matched in Oklab. Atlases: CC0 scans prepared (light out, anisotropic Kuwahara over colour and normals), painted in five value bands on Oklab ramps (shadows cool, lights warm), 35% scan detail back, wear on baked convex edges, dirt in occlusion and cavities, damp from the street, a light Kuwahara fuse, ten colours per slot, no dither (docs/superpowers/refs/mexico_city/painterly_texturing.md). Density about 50 px/m: 512 atlases for small pieces, 768 for a façade bay. Open: the user reports jitter (flicker, texel crawl, camera shake, shadow shimmer) and culling (see-through walls, pops at screen edge, clipping up close, far things vanishing), under investigation.

### 7.3 The kit: modular, well made, not overkill

- **One grid** across all kits, with storey heights true to each style. Pieces snap together edge to edge, never overlapping.
- **Modest budgets** suited to the look. Clean seams; no hidden geometry inside other geometry.
- **A reference card per kit family**, approved by the user before the family is built:
  - **source:** which real building or type, with photos from the bible
  - **change:** what the bleed, the sinking or 1920s repurposing did to it. Example: an arcade bay from the Portal de Mercaderes whose iron columns were replaced with seeped steel
  - **pieces:** the kit parts the family breaks into
- **One family at a time**, each reviewed in-game before the next.
- **Surfaces for the user's art** (glyphs, plaques, broadsides): Claude builds them with a fixed canvas size and a template file. The user paints them.
- **Textures:** when a texture or design is needed, Claude asks; the user sources or paints it (memory: ask for textures and designs). Only CC0 or self-made textures are committed; the repo is public.

### 7.4 Pipeline

The existing level pipeline's **export, loading and workshop round trip** stay (`tools/level/`: `kit.py`, `export.py`, `workshop.py`, `yours.py`, `LevelLoader.gd`), so the user can edit any piece in Blender and have the change reach the game. The **rule-based town generators are not used** for the new city (lot packers, house generators). Each map's placement is an authored layout file with explicit positions.

### 7.5 Quality gates: before the user sees anything

1. **Overlap scan over the whole map:** no coplanar or overlapping surfaces (z-fighting), using `tools/level/overlap.py`, as a hard gate.
2. **Daylight close-up renders of every joint** (memory: inspect geometry closely).
3. **Frame-rate check** along a fixed camera route (`--fps-report`).
4. **In-game captures** for the user's verdict. Tests passing is not "done" (memory: never call visual defects harmless).

## 8. Scope of sub-project 0, in order

1. **The style lab** (7.2): the kiosk and one arcade bay, blended style, variants in-game. The user's choice fixes the texturing pipeline.
2. **Reference cards and the shared kit:**
   - lamps in three dressings
   - the kiosk
   - the station kit: ticket hall, stairs, platform, line-coloured tile
   - the causeway basalt band
   - plaque, glyph and broadside surfaces with templates
3. **The Metro** (section 5): route board, the orange car, the ride scene, ghost stations, the Metro gate in `Districts` / `CityState`, the registry change.
4. **The brink and the sky** (section 6): the edge kit, fall-and-wake at the nearest lamp, hand-placed drifting districts, ghost-station debris belts, the cornered moon.
5. **Three placeholder pockets:** each district's real station plus one small blocked-out street with the threads in it, so the Metro works end to end before any district exists. Each district's own spec replaces its pocket.

**Planning:** the implementation plan covers **step 1 only**. Steps 2-5 are planned after the lab has settled the look, because the texturing pipeline changes how everything after it is built.

## 9. Testing

- **Six-route Metro test (headless):** ride every route (3 pairs, both ways) and check:
  - the player arrives on the right platform
  - inventory and purse survive
  - the district left behind keeps its state (CityState)
  - every frame of the ride has a loaded scene
  - the route's ghost stations and interchanges pass in their real order
- **Brink test:** falling off every edge of each pocket wakes the player at the nearest lamp; no edge can be walked off without falling, and none blocks the view.
- **Registry test:** the game boots into the Zócalo; the Iberian maps are out of the start registry and still open directly.
- **Kit tests:** each family's pieces snap on the grid with no overlaps (the overlap scan per piece and per assembled sample).
- **Visual review:** in-game captures of the ride's window sequence, the brink, the sky from each pocket and every kit family, judged by the user.

## 10. Out of scope here

- The districts themselves: each gets its own spec after this frame.
- Missions, guards, investigations, dialogue: after the art slice.
- Walking the tunnels as a level (a possible later fourth area).
- What the dark means for stealth: dousing the Company's lamps letting the void in. It is a strong idea for later; in this slice the lamps are recognisable, not mechanical.
