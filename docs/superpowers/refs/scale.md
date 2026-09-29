# Scale: grand but controlled, PS2 budget, several levels in one

Research notes for the 90-minute night mission: an Iberian city on a rock above a gorge and the sea, crowned by an English-style castle (harbour, old town, aqueduct, Moorish palace of waters, cathedral, gorge and great bridge, cisterns and catacombs, castle).

Compiled 28 Sept 2026. Read-only web research: links only, nothing downloaded or installed.

## How to read this

- Every claim is tied to a source listed at the end (section 7). Source tags:
  - **[primary]**: a developer talk, interview, postmortem or official material.
  - **[secondary]**: journalism, a wiki, an academic thesis or a design analysis.
  - **[tourism]**: a tourist board or travel site.
  - **[unverified]**: I could not confirm it. Treat it as a lead.
  - **[ours]**: our proposal, not a sourced fact.
- The Japanese CEDEC reports were read in machine translation.
- I did not watch the GDC Vault videos. Where a talk is cited, only its abstract or a written report was read, and the entry says so.
- Quotations are kept to a minimum. Almost everything is paraphrased.

## Contents

0. [The ten rules](#0-the-ten-rules)
1. [Game of Thrones locations in Spain and Portugal](#1-game-of-thrones-and-house-of-the-dragon-in-spain-and-portugal)
2. [Elden Ring and FromSoftware](#2-elden-ring-and-fromsoftware)
3. [PS2-era grand scale on a small budget](#3-ps2-era-grand-scale-on-a-small-budget)
4. [Multi-district stealth missions](#4-multi-district-stealth-missions)
5. [Terrain, cliffs and a 100 m gorge at PS2 fidelity](#5-terrain-cliffs-and-a-100-m-gorge-at-ps2-fidelity)
6. [Mapping to our districts](#6-mapping-to-our-districts-ours) **[ours]**
7. [Sources](#7-sources)

---

## 0. The ten rules

Each rule is tied to the references it comes from. Sections 1 to 5 give the evidence.

1. **One crown, visible from everywhere, and landmarks in three tiers.**
   - Make the castle the city's Erdtree: the landmark you see from the first minute and from every district.
   - Give each district one medium landmark: the cathedral tower, the aqueduct line, the great bridge, the palace dome.
   - Add small lit signposts (lamps, shrines, a torch at a cistern mouth) for local guidance.
   - References:
     - Miyazaki calls the Erdtree a landmark visible from nearly everywhere outdoors (Famitsu 2022).
     - FromSoftware's large, medium and small landmark tiers (CEDEC+KYUSHU 2022).
     - Ueda built ICO's castle so the player always senses its whole structure (Edge 2015).
     - Disney's "weenie" (Level Design Book).
2. **Make the route an ascension that reveals itself.**
   - Enter low (the harbour) with a panorama of the whole rock.
   - Dip into the gorge and the cisterns, then climb to the castle.
   - Rank the districts by height: commoners low, the lord on top.
   - At vistas and save points, show the next goal.
   - References:
     - Elden Ring's regions follow a pattern: enter at mid height with a panorama, descend to the lowest point, then climb to the boss at the top (Grau 2025).
     - Prince of Persia's palace was modelled on a castle with floors ranked up to the king (Lacoste, Ubisoft 2024).
     - Its columns of sand give visions of future areas (Wikipedia).
     - The Dragonstone arrival procession (Riley, Deadline 2018).
3. **Build each district as a mini-sandbox.**
   - Give it at least three ways in.
   - Lay it out as a spiral with no dead ends.
   - Make each building its own encounter cell, so one alert does not spread through the district.
   - References:
     - Stormveil has a lethal front gate, a side path the gatekeeper hints at, and a hidden bypass (Game Informer 2021; Wikipedia).
     - Sapienza's "Swiss cheese" and spiral layouts (PC Gamer 2017; RPS via Game Developer 2017).
     - Life of the Party's rooftop houses are self-contained encounters (Keverne 2010).
4. **Every district loops home.**
   - A district ends by opening a door, lift, ladder or drawbridge from the far side.
   - That opening drops the player back near a hub (a safehouse or a fence).
   - The shortcut is the reward for finishing the district.
   - References:
     - GMTK Boss Keys on Dark Souls: one-way doors and the lift back to Firelink.
     - The Level Design Book's study of the Undead Burg.
     - Castle Sol's door that you unlock from the inside (Fextralife).
5. **Different access makes a different level.** Give each district its own kind of gate:
   - a key found elsewhere (Raya Lucaria);
   - a count gate, where you need 2 of N tokens (Leyndell);
   - clues combined from two other districts (the Haligtree's medallion halves and puzzle);
   - a mechanism split into sub-zones (Kaldwin's Bridge in Dishonored);
   - a movement rule (Life of the Party: stay off the streets);
   - social access tiers (Hitman's public and private spaces, GDC 2019).
6. **Controlled maximalism: one idea per district, and cut the rest.**
   - Give each district one deliberately "jarring" landmark whose design direction differs from its surroundings.
   - Give each district a colour key.
   - Vary repeated modules by orientation, scale and height.
   - Spend hand-placed detail where the player pauses after a transition.
   - Use unique details sparingly: players notice repeated details before they notice repeated walls.
   - References:
     - FromSoftware's layout rules (CEDEC 2025) and region colours (CEDEC+KYUSHU 2022).
     - Ueda's "subtracting design" (GDC 2004).
     - Skyrim's modular kits (GDC 2013).
     - Castlevania: Lament of Innocence as the cautionary case.
7. **Build near, paint far, fog between.**
   - Use three distance tiers:
     - full geometry within about 100 m;
     - district proxies at 1/30 to 1/100 of the polygons;
     - a rendered panorama on distant cards.
   - Spend the far-view budget on landmarks.
   - Give big landmarks their own larger streaming cell.
   - Let fog hide the handovers.
   - Put streaming seams at gates, tunnels and bends.
   - References:
     - Shadow of the Colossus's "Super Low" system (Game Watch 2005).
     - Jak's "flats" for distant geometry (postmortem 2002).
     - Elden Ring's 512 m and 1024 m cells for large distant structures (CEDEC 2022).
     - ICO's ocean and fog.
     - Prince of Persia's S-shaped streaming corridors.
8. **Anchor, then extend (the Game of Thrones trick).**
   - Build real scale and detail wherever the player can touch.
   - Extend upward cheaply: extra tiers, forced-perspective upper storeys on towers the player cannot reach, silhouettes.
   - References:
     - The Osuna bullring was one tier on location and three on screen; the VFX supervisor's rule is to keep a real photographic anchor under any CG (fxguide).
     - Disneyland's Main Street is built at 3/4, 5/8 and 1/2 scale going up.
     - Riley used forced perspective in Dragonstone's throne room.
9. **Rock reads big through strata, silhouette and value, not through polygons.**
   - Use vertex-colour light and blends, and 256² tiling rock textures.
   - Paint horizontal strata bands as a height ruler.
   - Give cliff tops jagged silhouettes against a vertical fog gradient.
   - Light the destination and keep the edges dark.
   - Grow houses into boulders so the seams disappear.
   - References:
     - Shadow of the Colossus's environment textures and vertex-colour lighting (Froyok 2012).
     - The PS2 rendered one texture per pass (Godbolt 2010).
     - CEDEC 2025 on silhouettes and fog.
     - The Zumaia flysch cliffs and Monsanto's boulder houses.
10. **Pace the 90 minutes like a Thief II mission.**
    - Thief II and Dishonored missions average roughly 80 minutes.
    - Alternate tension and rest.
    - Put an empty but terrifying stretch before the scariest district, as the Shalebridge Cradle does.
    - Add a mid-mission turn, like Thief's two-missions-in-one "Assassins".
    - Give each district one set piece, and end with a return run.
    - Loot quotas: Life of the Party asks for about 26 / 39 / 54 % of the total by difficulty and hides 7 secrets.
    - Difficulty re-authors guards and items.
    - Use per-district "scene boxes" for grading.
    - References: Life of the Party and Shipping and Receiving data (Thief wiki), the Cradle (Wikipedia), the Level Design Book's pacing chapter, and Shadow of the Colossus scene boxes.

---

## 1. Game of Thrones (and House of the Dragon) in Spain and Portugal

### 1.1 Location by location

Seasons and roles come from the cited pages. "Why it reads maximal" and "Borrow" are our reading of the evidence.

**San Juan de Gaztelugatxe (Bizkaia): the Dragonstone approach**

- Played: the Dragonstone approach and stair in Season 7, filmed July to October 2016. The castle on top is computer-generated.
- Why it reads maximal: a rock islet is tied to the mainland by one stone bridge. 241 steps zig-zag up its spine to a hermitage 80 m above the sea. The path is a line drawn straight to the crown.
- Borrow: the castle approach as one switchback causeway up the rock's spine, legible from the harbour. Keep the real rock and crown it with the fantasy silhouette.
- Sources: Wikipedia; the official site says the fortress and dragons were CG **[tourism]**.

**Itzurun beach, Zumaia: the Dragonstone landing**

- Played: the Dragonstone beach landing (Season 7, episode 1).
- Why it reads maximal: flysch cliffs, tilted and stacked strata that let the eye measure height.
- Borrow: strata bands on the gorge and sea cliffs as a built-in scale ruler.
- Sources: **[tourism]**.

**Real Alcázar, Seville: the Water Gardens of Dorne**

- Played: the Water Gardens of Dorne in four episodes of Season 5 and one of Season 6.
- Spaces used: Mercury's Pool (seen from a balcony), the Carlos V pavilion and gardens, the Baths of María de Padilla (underground), and the Hall of Ambassadors (gilded dome, shot from below).
- In Season 6, episode 1, the Alcázar was digitally merged with a patio of the Alcazaba of Almería.
- Why it reads maximal: nested courtyards and a raised gallery over a pool, where the water doubles the arcades. A gilded dome makes you look up. A dark vaulted bath sits under bright gardens.
- Borrow: the palace of waters in three layers:
  - gardens: open and patrolled;
  - halls: social space;
  - baths and cistern: dark and quiet.
  Reflecting pools double the architecture for free.
- Sources: andalucia.com; Turismo de Sevilla **[tourism]**.

**Atarazanas (medieval shipyards), Seville: the Red Keep dungeons**

- Played: the Red Keep dungeons with the dragon skulls, filmed November 2016.
- Why it reads maximal: identical brick vault bays marching into perspective.
- Borrow: build the cisterns and catacombs from one vault-bay module repeated in perspective.
- Source: Turismo de Sevilla **[tourism]**.

**Plaza de Toros, Osuna: Daznak's Pit**

- Played: Daznak's Pit in Meereen (Season 5, episode 9).
- Why it reads maximal: the real ring has one tier; the screen version has three. A 200 ft greenscreen ran around the top, crowds were replicated, and the CG Sons of the Harpy were added.
- Borrow: build the tier the player touches; add cheap tiers above.
- Source: fxguide, quoting VFX supervisor Joe Bauer **[primary]**.

**Itálica amphitheatre, Santiponce: the Dragonpit**

- Played: the Dragonpit (Seasons 7 and 8).
- Why it reads maximal: a 160 × 137 m ruin built for 25,000 people. Emptiness at a huge scale.
- Borrow: a ruined public space as the neutral big stage.
- Source: Wikipedia.

**Girona old town: Braavos, King's Landing and Oldtown**

- Played: Braavos, parts of King's Landing and Oldtown in Season 6.
  - The cathedral stair became the Great Sept of Baelor steps; tourism sources say a sea view was added at the top.
  - The interior of Sant Pere de Galligants became the Citadel library.
  - The Arab Baths also appear in tourism lists.
- Why it reads maximal: a long monumental stair (about 90 steps; counts vary) as a stage. Lanes and stairs make chase routes.
- Borrow: the cathedral district's stair as both stage and sightline. A monastery interior as a library.
- Sources: costabrava.org and others **[tourism]**. The step count is **[unverified]**.

**Peñíscola: Meereen**

- Played: Meereen in Season 6.
- Why it reads maximal: a walled town on a rocky promontory, joined to land by a narrow isthmus, with the castle on top.
- Borrow: the city-on-a-rock silhouette, with a single neck of land as a natural gate.
- Sources: **[tourism]**.

**Cáceres old town: King's Landing streets**

- Played: the King's Landing streets for Euron's parade (Season 7, episode 3). The town was used again in House of the Dragon.
- Why it reads maximal: a density of stone palaces and tower-houses (Torre de Bujaco, Arco de la Estrella), with stepped lanes.
- Borrow: an old-town kit of tower-houses, with arch gates as district thresholds.
- Source: Turismo Extremadura **[tourism]**.

**Trujillo castle: Casterly Rock**

- Played: Casterly Rock in Season 7.
- Why it reads maximal: a castle on a granite hill, with battlements looking down on an army.
- Borrow: castle walls that look down on the routes the player just climbed.
- Source: Turismo Extremadura **[tourism]**.

**Castle of Zafra (Guadalajara): the Tower of Joy**

- Played: the Tower of Joy in three episodes of Season 6.
- Why it reads maximal: the castle occupies the whole sandstone outcrop, at about 1,400 m. A wall encloses the top, linking the entrance tower to the main buildings.
- Borrow: make the castle's footprint the rock's footprint, with walls that continue the cliff.
- Source: Wikipedia.

**Almodóvar del Río: Highgarden**

- Played: Highgarden in Season 7; its dungeon stood in for Casterly Rock.
- Why it reads maximal: a hilltop castle above the Guadalquivir with three distinct towers: square, round, and the keep.
- Borrow: give our castle three differently shaped towers, so it can be read from any side.
- Sources: Wikipedia; the castle's own site **[tourism]**.

**Roman bridge, Córdoba: the Long Bridge of Volantis**

- Played: the Long Bridge of Volantis in Season 5.
- Why it reads maximal: a long bridge used as a street and a stage, with a preaching crowd.
- Borrow: the great bridge as an inhabited street.
- Sources: **[tourism]**.

**Los Barruecos: the Goldroad battle**

- Played: the Goldroad battle in Season 7, episode 4.
- Why it reads maximal: a field of granite boulders around a lake.
- Borrow: boulder fields as cheap, strong silhouettes.
- Source: Turismo Extremadura **[tourism]**.

**Monsanto (Portugal): House of the Dragon**

- Played: House of the Dragon, filmed in 2021. Tourism sources say it was Dragonstone.
- Why it reads maximal: houses and walls built into giant granite boulders.
- Borrow: let rock and masonry interpenetrate. It hides seams cheaply and makes the city grow out of the rock.
- Source: Portugal.com **[tourism, role unverified]**.

Game of Thrones itself: I found no location in Portugal. The Portuguese reference is House of the Dragon.

### 1.2 What the productions teach (cross-cutting)

- **Anchor, then extend.** The show's VFX rule was to keep an anchor in real photography when adding CG (fxguide, Joe Bauer) **[primary]**. Osuna shows the method: shoot the real single tier, then add two tiers and a crowd.
  - Game translation **[ours]**: full-detail, real-scale geometry wherever the player can touch or climb; cheaper, taller extensions above reach.
- **Arrival as a procession.** Deborah Riley describes the Dragonstone arrival: the last five minutes of that episode have no dialogue as Daenerys lands on the island and makes her way into the castle, through the audience chamber to the map room (Deadline 2018) **[primary]**.
  - She says she is interested in how spaces feel as much as how they look.
  - The audience chamber drew on the power of totalitarian architecture, with forced perspective to pull focus to the throne. References were Louis Kahn's Salk Institute and Notre-Dame de Royan.
  - Borrow: the castle district as a wordless sequence of thresholds, ending at one focal object.
- **Composite freely.** Dorne on screen is the Seville Alcázar merged with a patio of Almería's Alcazaba (andalucia.com) **[tourism]**. Our city can likewise combine Ronda, Toledo, Seville and Granada.
- **Fantasy crown on real rock.** Dragonstone is the real islet plus a CG castle (Wikipedia; official site). This is the exact brief of a city on a rock crowned by a castle.

### 1.3 Real-world scale references (not Game of Thrones)

- **Ronda, the natural analogue for our gorge.**
  - El Tajo gorge is more than 100 m deep.
  - The Puente Nuevo was built between 1751 and 1793. Wikipedia gives its height as 120 m above the canyon floor; other sources give lower figures, so check before using **[unverified]**.
  - The old city sits on one side and the newer Mercadillo on the other.
  - The Arab baths (13th to 14th century) lie below the city (Wikipedia).
- **Measured anchors:**
  - Gaztelugatxe: 241 steps, 80 m.
  - Itálica: 160 × 137 m.
  - Zafra: the castle fills a single outcrop.

---

## 2. Elden Ring and FromSoftware

### 2.1 What FromSoftware staff have said

- **Miyazaki (Weekly Famitsu, 10 March 2022; English translation by Frontline JP)** **[primary]**:
  - The Erdtree serves both mood and navigation. It is visible from almost anywhere outdoors and acts as a landmark.
  - Map fragments deliberately omit detail, so discovery survives.
- **Legacy dungeon definition (Game Informer preview by Daniel Tack, 27 Aug 2021)** **[secondary]**:
  - Legacy dungeons are curated dungeon crawls with NPCs, looping levels, drop-downs, lifts, several paths and secrets, all on the way to a big boss.
  - In Stormveil, the front gate means arrows and a troll head-on. The winding side path lets you reach the troll from behind, unseen, and put it to sleep with a dart.
- **CEDEC 2022, Tatsuo Matsumoto (System Design Director), report by Denfaminicogamer** **[primary via report]**:
  - The open field is split into streaming grid cells of 256 m.
  - Large structures seen from far away are cut to separate 512 m and 1024 m cells, so they stay visible at distance.
  - Reusable asset layers are kept apart from map-specific base geometry.
  - The same report covers the team's tooling: an "information map", automated daily traversal tests and a dependency database.
- **CEDEC+KYUSHU 2022, Atsushi Miyauchi (Chief 3D Graphics Artist) and Teppei Morita, report by Famitsu** **[primary via report]**. The field is built on large, medium and small landmarks:
  - **Large**: region-defining, each with a theme colour: Limgrave gold, Liurnia blue, Caelid red, Altus Plateau yellow.
  - **Medium**: forts and churches with graces, the places the team wants players to visit, placed to be seen from key vantage points.
  - **Small**: caves and camps, signposted with torches at cave mouths, guiding statues, glowing items and scarabs.
  - The stated goal is gentle guidance. Big dungeons stay visible over long distances, often revealed at cliff-edge transitions.
- **CEDEC 2025, Hidenori Sato (Environment Art Director on Shadow of the Erdtree) and Satoshi Katahira, reports by 4Gamer, CGWorld and GameMakers** **[primary via report]**. This talk is FromSoftware's clearest statement of controlled maximalism.
  - **Two quality rules**: remove monotonous parts, and balance eye guidance.
  - **Repetition**: reduce identical shapes as far as possible, varying orientation, scale and height. Keep directional lines aimed at the goal. (One report implies a hard limit on repeats; CGWorld gives no number, so treat it as "minimise".)
  - **Line**: break all-curve compositions with straight elements, such as a single-direction light shaft. S-curves are used a great deal for paths.
  - **Symmetry**: avoid left-right mirroring unless the architecture demands it. Stagger elements in depth.
  - **Value**: widen the brightness range. Darken the periphery and light the destination. Separate near and far with different light colours. Check a "mosaic" (colour-block) reduction of the image to find monotony.
  - **Silhouette**: replace straight edges, such as cliff lines, with complex, jagged ones.
  - **Landmarks**: add an element that deliberately jars, with a design direction unlike its surroundings. Oversized landmarks that run past the frame make the player pan up, like viewing a huge painting up close.
  - **Detail placement**: concentrate hand-placed quality at viewpoints, the places where the player pauses after the situation changes.
  - **Fog and light**: layer vertical and depth fog gradients together. Group light shafts, rather than scattering them, and point them at goals.
  - **Under constraint** (a flat arena with no collision allowed): build the composition from sky and fog, and add non-colliding distant elements, such as glowing phantom flags toward the horizon, for depth and direction.

### 2.2 The six palaces and castles

**Stormveil Castle**

- Access and gating: a lethal front gate (ballistas, a troll) or the side path along the cliff that the gatekeeper Gostoc suggests. An obscure eastern path skips the castle entirely. An analysis counts about six ways in, and argues the castle is really a threshold between two regions rather than a destination.
- Vertical stacking and loops: climb broken walls to the ramparts, then choose between rooftops and dropping through the interior to the Godrick courtyard. The first quarter teaches you to look up, with rewards and enemies overhead. Locked doors, empty lifts and seemingly impassable spots invite exploration.
- Borrow: a castle with a front gate that is a trap, a side path hinted by an NPC, and a secret third route. The castle doubles as the threshold to the escape.
- Sources: Game Informer 2021; Wikipedia; The Escapist (JM8, 2022); A.V. Club (2023); GameSpot (Stephen T. Wright, 2022); Crumley (Substack, 2026) **[secondary]**.

**Academy of Raya Lucaria**

- Access and gating: the only way in is the main gate, sealed by a barrier. It opens with the Academy Glintstone Key, found elsewhere. Two bridges lead to the gate.
- Vertical stacking and loops: map layers run lower floor, ground floor, first to third floors, church balcony, rooftops, and the Grand Library. Windows and damaged walls reveal adjacent spaces.
- Borrow: a key-gated institution with a rooftop layer and a library finale. Let windows preview the next rooms.
- Sources: Fextralife; Archpaper 2022 **[secondary]**.

**Leyndell, Royal Capital**

- Access and gating: the gate needs two Great Runes, a count gate.
- Vertical stacking and loops: ramparts, a fortified manor, and an underground layer (Subterranean Shunning-Grounds, catacombs). The Erdtree dominates every view.
- Note: GMTK observes the game becomes more linear from about here (cited in Maj 2023).
- Borrow: the castle's inner ward opens only once you hold 2 of 3 district tokens.
- Sources: Fextralife; Famitsu 2022; Maj 2023 citing GMTK **[secondary]**.

**Miquella's Haligtree and Elphael**

- Access and gating: hidden behind two locks. A secret medallion made of two halves (one is in Castle Sol) opens the way into the snowfield region. There, a candle puzzle at Ordina activates the waygate to the tree.
- Vertical stacking and loops: a walk along the canopy branches, then a town, then the Elphael castle. It is falls-heavy and ranged-threat-heavy.
- Borrow: a secret district reached only by combining clues from two other districts.
- Sources: Fextralife **[secondary]**.

**Castle Sol**

- Access and gating: a mountaintop castle reached by a northern bridge.
- Vertical stacking and loops: courtyard, wall-walks with ballista crews, and ladders. The Church of the Eclipse is the landmark and safe node. A door you unlock from the inside becomes a shortcut back to the entrance.
- Borrow: a rampart walk under ranged threat, with a chapel as the safe anchor.
- Sources: Fextralife **[secondary]**.

**Crumbling Farum Azula**

- Access and gating: reached by a story event.
- Vertical stacking and loops: described as maze-like with branching paths, in six vertical map layers, with a temple lift. Displaced, levitating domes, columns and walls serve as walkways.
- A Substack analysis finds its density holds up on replays despite its small map footprint.
- Borrow: ruined aqueduct and bridge fragments over the gorge used as walkways.
- Sources: Fextralife; Thoughts Thought (Substack, 2024) **[secondary]**.

### 2.3 Analyses of sightlines, loops and stacking

- **GMTK, "The World Design of Elden Ring" (Mark Brown, Nov 2022)** **[secondary]**:
  - Covers how areas are placed to lead the player while leaving room to explore and find secrets.
  - Criticises content repetition and a restrictive end game (80.lv summary).
- **GMTK, "The World Design of Dark Souls | Boss Keys"** **[secondary]**:
  - Firelink Shrine is a hub whose branches loop back through shortcuts, lifts and doors that open from one side. The one-way doors stop the player being overwhelmed early.
  - The world works as an accordion of exploration and forward push.
  - Fast travel, once unlocked, weakens the loops.
  - This is the classic "shortcuts back to the hub" reference.
- **The Level Design Book, "Undead Burg"** **[secondary]**:
  - One-way drops enforce flow.
  - Glowing pickups and enemies act as breadcrumbs.
  - The broken bridge and archer tower orient you toward what is next.
  - Ambushes follow a teach, test, twist pattern.
- **Ribbing and Melander, "Examining the Souls Series Level Design" (DiVA thesis)** **[secondary]**:
  - Dark Souls III's High Wall starts with a short enclosed "birth canal", so the designers control the first reveal.
  - Torch-lit paths and a well-placed archer pull attention to a shortcut.
  - Of the levels they examined, the Undead Burg is the densest and the most connected, bordering four other areas.
- **"Worlds Worth Believing In: On Demon's Souls and Dark Souls" (Game Developer, 2015)** **[secondary]**:
  - Vistas work two ways: some preview a future climax (Boletaria's distant tower), and some summarise progress (looking back at the plateau you crossed).
  - Shortcuts land you like finding a familiar street after wandering new roads.
- **Grau, "Implicit Wayshowing in Open World Games" (thesis, 2025)** **[secondary]**:
  - Players enter each Elden Ring region at a middle height with a panorama.
  - They descend to the lowest point, then climb to the highest point, where the main boss waits.
  - The way up is the way on.
  - Persistent landmarks (minor Erdtrees, Divine Towers, one or two region landmarks) keep orientation.
- **Mondrety, "The World Design of Elden Ring, and 3 Lessons" (LinkedIn, 2022)** **[secondary]**. The first Limgrave view composes:
  - the castle on a rising slope, as the region goal;
  - the broken aqueduct-bridge, as the region boundary, with fog beyond;
  - the Erdtree, as the final goal and a sense of distance;
  - a far brazier, as the end of the map.
- **Scavnicky, Archpaper (2022)** **[secondary]**:
  - Reused assets work as typology: repeated shacks signal safety without UI.
  - Raya Lucaria's windows and broken walls teach wayfinding.

### 2.4 How FromSoftware keeps maximalism controlled

- **One big thing per view**, with a design direction unlike its surroundings (CEDEC 2025). Everything else stays calmer and repeats quietly.
- **Colour keys per region** (CEDEC+KYUSHU 2022), with near and far separated by light colour (CEDEC 2025).
- **Repeat modules, but break the repetition.** Rotate, scale and stagger them, and avoid mirror symmetry (CEDEC 2025). Modules can also carry meaning: shacks mean safety (Archpaper).
- **Fog and silhouette do the grandeur.** Vertical and depth fog gradients sit behind jagged silhouettes, and oversized landmarks bleed off the frame (CEDEC 2025).
- **Budget follows attention.** Hand-placed detail goes to viewpoints (CEDEC 2025). Big distant structures get their own larger streaming cells (CEDEC 2022).
- **Density sits inside, not between.** Legacy dungeons are dense and looped, and the field around them is calmer (Game Informer 2021; Grau 2025).

---

## 3. PS2-era grand scale on a small budget

### 3.1 The hardware frame

- **Memory**: 32 MB of main RAM, and 4 MB of eDRAM on the Graphics Synthesizer holding the frame buffers, the Z buffer and the texture cache. Textures are 4-bit or 8-bit palettised (CLUT) (Copetti; Wikipedia) **[secondary]**.
- **Texturing**: the GS sampled a single texture and could add or alpha-blend with the screen. There was no multiply mode. More layers meant more passes, and lighting relied on pre-computed ambient and vertex colour (Godbolt, on the PS2 renderer of SWAT, 2010) **[primary]**.
  - Consequence for terrain: blends between rock, earth and moss were vertex-colour or vertex-alpha passes, not splat maps.
- **Throughput**: Sony estimated 7.5 to 16 million polygons per second; independent estimates ranged from 3 to 20 million (Wikipedia) **[secondary]**.
  - Derived ceiling **[ours]**: about 250k to 530k polygons per frame at 30 fps, or 125k to 270k at 60 fps. Real scenes with lighting and several passes came in well under this.
  - I found **no primary per-frame scene counts** for the games below.

### 3.2 Game by game

**ICO (2001)**

- **One coherent castle.**
  - Ueda built the castle so the player would "always be aware of its entire structure" (Edge, 2015) **[primary]**.
  - Vantage points show places already visited and places still to come.
  - A fan-stitched map of the whole castle reportedly exists (Wireframe, via a search summary) **[unverified]**.
  - There are no invisible walls. Where barriers were unavoidable, they were made to look real.
  - The twin gatehouses are near-identical, and the symmetry reads as believability rather than cheap reuse.
  - The inspirations were imagined rather than scouted; Ueda credits the etcher Gérard Trignac.
  - Each challenge was treated as a level, and the route was plotted by difficulty.
- **Subtracting design (GDC 2004 slides)** **[primary]**:
  - Remove every element that does not serve the core experience.
  - Compensate with higher density and quality in what remains.
  - The team called it a risky method.
- **Fog and ocean (shmuplations translation of developer interviews)** **[primary]**:
  - Ueda enclosed the world with an ocean and thick fog, so distance did not need detail.
  - He balanced the background piece by piece: more blocks where an area felt too open, curves where there were too many straight lines.
  - Wide-angle long shots established height and depth.
- Real-time stencil shadows fell only on Ico and Yorda (Game Watch 2005).

**Shadow of the Colossus (2005)**. Impress Game Watch, 7 Dec 2005, by Zenji Nishikawa, English translation **[primary]**.

- **Three-tier landscape.**
  - The foreground is high-res terrain in 100 × 100 m chunks.
  - The middle distance is low-res terrain in 600 × 600 m chunks, cut to roughly 1/30 to 1/100 of the polygons.
  - The far view, which the team nicknamed "Super Low", is a rendered image or texture on a distant polygon. It is updated by rendering the low-res model, so the handover is seamless.
  - It is explicitly not distance fog.
- **Memory follows landmarks.** Because memory was scarce, the far-view budget was concentrated around the landmark that represents each area.
- **Streaming.** Areas stream in and out with no loading screens, and memory is defragmented in the background during vertical blank.
- **Scene boxes.** Trigger volumes placed all over the map set the bloom, exposure and afterglow for each area, blending smoothly when you cross between them. This produces the dark sanctuary looking out onto blown-out daylight. The cost was that hand-placing boxes over such a large world took a lot of production time.
- **Variable frame rate.** The frame rate swings from 60 to about 15 fps, and motion blur hides it.
- **Budgets.**
  - Wander is about 3,000 polygons; a colossus is about 18,000.
  - Colossi have **no** distance LOD (there was no memory to spare).
  - Shadow proxies are about 1/40 of the full model.
- **Textures** (Froyok frame breakdown, 2012) **[secondary]**:
  - Environments use 256 × 256 tiling textures; character models use 128 × 128.
  - Lighting is stored in vertex colour.
  - Rocks carry a comparatively high polycount.
- **Art direction** (Fourcade, Game Developer, 2014) **[secondary]**:
  - Temples, bridges and columns are built at a scale not meant for humans.
  - Bright haze swallows the distance.
  - The overall effect is vertigo, both vertical and horizontal.

**Prince of Persia: The Sands of Time (2003)**

- **Palace concept** (Lacoste, Ubisoft News 2024) **[primary]**:
  - Modelled on *The King and the Mockingbird*: one castle with floors ranked up to the king at the top.
  - Designed for verticality and a journey through the castle to the top of the tower.
  - Structural fixes became play, e.g. poles propping a broken pillar became swing points.
  - Level design started as blocks, dressed into art later (Guyot).
- **Navigation and streaming** (Wikipedia) **[secondary]**:
  - Columns of sand give visions of future areas and act as save points.
  - Rooms were linked by S-shaped corridors. Halfway through, the previous room was unloaded and the next loaded, invisibly.
- **Postmortem** (Yannis Mallat, Game Developer, April 2004) **[primary]**:
  - Mallat says the game was above all about level design.
  - A playable editor allowed instant tweaking.
  - Dynamic loading was not settled at the start, which caused memory pain.
  - Maps arrived late for AI work.

**Final Fantasy XII (2006)**

- **Art direction** (Wikipedia, citing IGN and others, 2003) **[secondary]**:
  - Ivalice is a mix of medieval Mediterranean countries, and the art team visited Turkey.
  - Other influences include India and New York.
  - Kamikokuryo designed the cities with varied architecture to feel like walking through a real metropolis (Wikipedia, citing the Collector's Edition bonus disc).
- **Rabanastre** (Graham R, Substack, 2026) **[secondary]**:
  - Four quarters by cardinal direction, a palace road closed to commoners, and Lowtown underneath.
  - Many layered buildings are unreachable, so the player builds an image of the whole city and projects it onto the parts they can visit.
  - Tunnels and chokepoints alternate with open plazas.
- I found **no primary technical figures** for its PS2 environments.

**Castlevania: Lament of Innocence (2003)**, a cautionary case

- A room near the entrance holds portals to five areas, all open from the start (Wikipedia).
- IGN, Eurogamer and PALGN all called the rooms and corridors repetitive. There is no whole-castle map, and there is a lot of backtracking.
- Lesson: a modular castle dies without landmarks, unique rooms, and corridors that do work.

**Thief: Deadly Shadows (2004, Xbox/PC)**, a cautionary case

- Because of limited memory, city and mission levels were split into parts joined by load zones (Wikipedia) **[secondary]**.
- A community "Gold" mod later stitched the mission parts together and redesigned the transitions (PC Gamer, 2014).
- The City hub has districts you explore between missions, fences who buy loot, and shops.
- Lesson: plan seams as diegetic thresholds from day one.

**Jak and Daxter (2001) and Jak II (2003)**, outside the brief but relevant

- **Postmortem** (Stephen White, Game Developer, 2002) **[primary]**:
  - The world is seamless, with no load screens.
  - The goal was to see a landmark far off, even in another level, and travel there without a break.
  - Several LOD schemes were used, differing by object type and distance: simplified models for far backgrounds, and flat cards ("flats") for distant geometry.
- **Precomputed visibility** was stored as per-region bit strings and looked up with a BSP tree. **[secondary: from a search summary of the postmortem; I did not re-read that passage]**
- **Background renderers** (OpenGOAL documentation) **[secondary]**:
  - "tfrag" draws unique level geometry with LOD and time-of-day vertex colours blended from 8 palette weights.
  - "tie" draws instanced props, with at most 43 prototypes per tree.
  - "shrub" draws small plants.
- **Jak II** (Wikipedia, citing IGN and Game Informer 2003) **[secondary]**:
  - Character polygon counts rose from 3,000–5,000 to 12,000–15,000.
  - Haven City is 24 times larger than any Jak 1 level.

**Dragon Quest VIII (2004)**

- A seamless field reaches full-size towns and dungeons, with no world-map icons, in cel-shaded 3D (Wikipedia) **[secondary]**.

**Primal (2003)**

- I found **no primary technical or design sources**, only staff recollections of ambitious environments.

**Silent Hill (1999)**, the fog precedent

- Distance fog and darkness hid pop-in and draw distance, and became the atmosphere (Wikipedia) **[secondary]**.

### 3.3 Numbers at a glance

- **SotC foreground terrain chunk**: 100 × 100 m (Game Watch 2005).
- **SotC mid-distance chunk**: 600 × 600 m, at 1/30 to 1/100 of the polygons (Game Watch 2005).
- **SotC far view**: an image on a distant polygon, "Super Low" (Game Watch 2005).
- **Model budgets**:
  - SotC Wander about 3,000 polygons; a colossus about 18,000; shadow proxies about 1/40 (Game Watch 2005).
  - God of War II Kratos: 5,700 polygons, 1,200 of them in the face, with 5 textures (PlayStation Blog 2019).
  - Jak II characters: 12,000 to 15,000, up from 3,000 to 5,000 (IGN via Wikipedia).
- **SotC textures**: 256 × 256 tiling for the environment, 128 × 128 for characters (Froyok 2012).
- **SotC frame rate**: 60 down to about 15 fps, with motion blur (Game Watch 2005).
- **Elden Ring streaming cells**: 256 m, with 512 m and 1024 m cells for large distant structures (CEDEC 2022).
- **Skyrim kits** (GDC 2013):
  - 7 dungeon kits, and the cave kit was used 200+ times.
  - A small hallway sub-kit has about 50 pieces.
  - Footprints are 512 and 256 units, with the snap grid at half the footprint.
  - 2 kit artists supported 400+ dungeon cells.
- **PS2 memory**: 32 MB of main RAM and 4 MB of eDRAM (Copetti; Wikipedia).
- **Jak background props**: at most 43 "tie" prototypes per tree (OpenGOAL).

### 3.4 Art-direction rules distilled from the era

- **Subtract, then densify.** Cut anything that does not serve the core, and pour the budget into what is left (ICO, GDC 2004).
- **Enclose the world.** Sea, fog and haze bound it, so the distance never needs detail (ICO; SotC haze; Silent Hill).
- **Architecture bigger than people.** Scale is read against the body (SotC; Fourcade).
- **One castle, felt as a whole.** Let vantage points look back and ahead (ICO, Edge 2015).
- **Stratify by rank, climb to the top** (Prince of Persia, Lacoste).
- **Hide streaming in the architecture.** Use S-bends, gatehouses and tunnels (Prince of Persia; Jak's seamless world; Thief: Deadly Shadows as the counter-example).
- **Let the player project the city** onto layered facades they cannot reach (FFXII).
- **Grade per area** with trigger volumes (SotC scene boxes).
- **Don't let modules show.** Lament of Innocence's identical corridors are the warning.

---

## 4. Multi-district stealth missions

### 4.1 Thief II: "Life of the Party" (designer Emil Pagliarulo)

- **Structure**:
  - You start on a bell tower far from the goal, with no set route across the rooftops (the "Thieves' Highway").
  - The objective is to travel by rooftop and stay off the streets.
  - Along the way are houses and towers: the Shemenov estate, the Necromancer's Spire (with a lift), Lady Louisa's estate, the Keepers' chapel and others.
  - The goal is Angelwatch, a six-storey Mechanist tower in Art Deco style. Ducts reach floors 2 to 5.
  - You end by returning to the bell tower.
- **Why it works** (Justin Keverne, *Groping the Map*, 2010–11) **[secondary]**:
  - Each building is a discrete encounter space whose guards do not follow you across the roofs, so one mistake does not snowball.
  - The multilinear rooftops give way to a single vertical interior.
  - Angelwatch's scale reads as an intrusion on the city: its electric lights resist water arrows, and it holds more guards.
- **Economy** (Thief wiki) **[secondary]**:
  - Loot requirements are 750 / 1,100 / 1,550 on Normal / Hard / Expert, out of about 2,850 available.
  - Hard and Expert add a no-killing rule.
  - There are 7 secrets, which pay out in tools as well as gold.
- **Production notes** (the Thief wiki summarising the designer's forum answers) **[secondary]**:
  - It was inspired by rooftop levels in the first Rainbow Six.
  - The rooftop area shrank from the demo because the mission kept hitting the engine's object limit.

### 4.2 Thief II: "Shipping... and Receiving" (designer Mike Chrzanowski)

- **Setting**:
  - A dockside warehouse complex (Rampone's) holding several small businesses: shipping, a small gallery, recipes and records.
  - A docked ship secretly run by pirate-smugglers.
  - The briefing promises few guards, dark corners and several points of entry.
- **Economy and difficulty** (Thief wiki) **[secondary]**:
  - The loot quota is 500 / 650 / 850. Expert adds a no-killing rule.
  - Harder settings add guards (sword guards 8 / 12 / 12, bow guards 6 / 9 / 13), remove items and change patrol stop points.
- **Story delivery** (Whalen, 2015) **[secondary]**: overheard talk introduces the Mechanists, and the first camera and robot glimpses foreshadow them.

### 4.3 Thief: "Assassins" (The Level Design Book) **[secondary]**

- Four beats make two missions in one: an ambush, a tail through the streets, the mansion infiltration, and an optional escape.
- The streets feel like a vast labyrinth but use only a handful of loops.
- The spaces turn from safe public, to risky private, to hostile public.
- Two mansions compared act as characterisation through architecture.

### 4.4 Thief: Deadly Shadows: the Shalebridge Cradle and the City

- **The Cradle** was designed by Jordan Thomas with Randy Smith, aiming at the scariest level ever made (Wikipedia, citing PC Gamer UK 2005 and GAMBIT 2011) **[secondary]**.
  - The outer Cradle is built to terrify but secretly holds no enemies. The inner Cradle is patrolled.
  - Lights dim and brighten imperceptibly, like breathing, and flicker when Puppets approach.
  - The history emerges non-linearly from found clues.
- **The City** (Wikipedia) **[secondary]**:
  - After each mission you reappear in the nearest district and can explore freely.
  - Fences buy loot and shops sell gear.
  - Memory forced load zones.
- **Randy Smith's stealth fundamentals** (GDC talk in 2002; Game Developer "GDC Radio" post, 2006) **[secondary]**:
  - Analog systems of light, sound surfaces and multiple routes.
  - The goal is plans the player makes that need no explicit designer support.

### 4.5 Dishonored (2012) and Dishonored 2 (2016)

- **Missions as sandboxes** (Wikipedia) **[secondary]**:
  - Start from a cohesive area, fill it with activities, define routes to the target, then expand.
  - Unplanned power combinations from playtests were accommodated by redesigning levels rather than banned.
- **Plausibility** (Wikipedia) **[secondary]**:
  - The Hound Pits pub's large exterior clashed with an interior that needed too many stairs, so its third floor was closed.
  - Antonov and Mitton scouted the side streets of London and Edinburgh, not the busy ones.
  - They designed from a constrained "rat's viewpoint".
- **Dishonored 2's Karnaca** (Wikipedia) **[secondary]**:
  - Inspired by the Mediterranean: Greece, Italy, Spain, plus Cuba and Lyon references. The city is less vertical, with flat roofs.
  - The designers avoided illogical man-sized vents and insisted that buildings have toilets and that guard posts make sense.
  - The Clockwork Mansion reconfigures its rooms.
  - "A Crack in the Slab" lets you shift between the present and three years in the past.
  - The Dust District has two factions and dust storms you can use as cover.
- **Kaldwin's Bridge ("The Royal Physician")** (Dishonored wiki) **[secondary]**:
  - The bridge is four sub-zones: Southside Gate, Drawbridge Way, Midrow Substation, North End.
  - Drawbridge stations are multi-level, with key-locked levers, arc pylons and a wall of light.
  - Floodlights must be switched off so the boat can pass.
  - A powered cargo car crosses elevated tracks.
  - There are side jobs, a secret room and a safe.
  - Collectibles: 5 runes, 3 bone charms, 1 shrine, 1 painting, and about 3,600 coins.
  - This is the closest direct model for our great bridge.
- **Steve Lee, "An Approach to Holistic Level Design"** (GDC 2017; abstract only) **[primary, not watched]**: level designers should design gameplay, presentation and story together (affordances, intentionality, world building).

### 4.6 Hitman (2016): Sapienza, and IO's guidance talks

- **The making of Sapienza** (PC Gamer 2017; interviews with creative director Christian Elverdam and lead level designer Torbjørn Christensen) **[primary]**:
  - The whole brief was "Coastal Town".
  - Christensen modelled it on the Amalfi coast, to explore coastal verticality and how streets and corridors connect everything.
  - Elverdam's contrast: a palace is easy to picture whole (floors, basement, gardens), while a coastal town has no guessable start or end, which makes organic exploration satisfying.
  - He calls it "Swiss cheese" design: a volume full of connections, so you never get lost and never have to backtrack.
  - A mafia-boss idea produced the villa and a secret cave beneath it, which became a lab.
  - Contrast is used as a mood tool: the idyllic town against the target's turmoil.
- **Spirals** (RPS interview via Game Developer, 2017) **[primary via report]**:
  - Levels are "snail houses" with no dead ends, so you can keep moving forward.
  - This makes them feel larger than their footprint.
- **Space types** (Mette Andersen, GDC 2019, via Game Developer) **[primary via report]**:
  - Public space comes in three tiers: basic, purpose, rule.
  - Private space comes in three tiers: basic trespass, professional (fit the role), personal (rare and story-heavy).
  - Bigger public areas keep players engaged without trespass.
- **Guidance** (GDC Europe 2016 abstract; Andersen and Mikkelsen) **[primary, abstract]**:
  - User research found Paris's scale incomprehensible and the learning curve too steep.
  - The fix was guidance and a tutorial layered on top of the sandbox, not a smaller sandbox.

### 4.7 What makes several-levels-in-one work (distilled)

- **A hub with a view.**
  - The start point sees the goal: the bell tower that sees Angelwatch, Firelink's paths, Limgrave's first view.
  - Players return to it, or loop past it (Life of the Party; Dark Souls; Elden Ring).
- **Districts as distinct rule-sets, not just skins.**
  - Rooftops only, then a vertical tower (Life of the Party).
  - An outer Cradle with no threat, then an inner one hunting you (Cradle).
  - A public town, then a private villa, then a secret lab (Sapienza).
  - Bridge sub-zones with a mechanism (Kaldwin's Bridge).
- **Multiple entries, contained alerts, no dead ends.** Several points of entry (Shipping and Receiving); encounter cells (Life of the Party); spirals and Swiss cheese (Hitman).
- **Legibility at scale.**
  - Landmarks in tiers (FromSoftware).
  - A readable grammar of public and private space (Hitman).
  - Guidance layered on top when the sandbox is big (Hitman 2016).
- **Plausible architecture.** Exteriors must match interiors (the Hound Pits). No nonsense vents; guard posts that make sense (Dishonored 2).
- **Two-missions-in-one turns** change the goal midway ("Assassins"; "A Crack in the Slab").

### 4.8 Pacing across 60 to 90 minutes

- **Benchmarks** (HowLongToBeat figures via a search summary; approximate) **[secondary]**:
  - Thief II main story is about 20 h over 15 missions, roughly 80 min each.
  - Dishonored is about 12 h over 9 missions, roughly 80 min each.
  - A 90-minute mission sits right at the genre norm.
- **The Level Design Book, "Pacing"** **[secondary]**:
  - Think in beats with pulse, accent, rest and variation.
  - Start slow, alternate highs and lows, and give rests as palette cleansers.
  - Build at least one set piece you are excited about.
  - Do not end on a maximum-intensity peak without falling action.
  - Very long intense fights drag after about 10 minutes.
- **Patterns from the references**:
  - Calm before dread (the Cradle's empty outer half).
  - A mid-mission goal change ("Assassins").
  - Open multilinear play funnelling into one vertical finale (Life of the Party).
  - A return trip over conquered ground (Life of the Party's return to the bell tower).
  - Each Elden Ring region's descend-then-ascend shape (Grau).

### 4.9 Loot and secrets economy

**Life of the Party**

- Loot required: 750 / 1,100 / 1,550 out of about 2,850, i.e. roughly 26 % / 39 % / 54 % of the total.
- Other rules: no killing on Hard and Expert; 7 secrets that pay out in tools and potions.
- Source: Thief wiki.

**Shipping... and Receiving**

- Loot required: 500 / 650 / 850.
- Other rules: no killing on Expert. Difficulty adds guards and removes items and keys.
- Source: Thief wiki.

**Kaldwin's Bridge**

- Collectibles: 5 runes, 3 bone charms, 1 shrine, 1 painting, about 3,600 coins.
- Other rules: side objectives, a secret room, and a safe whose code you earn by rescuing someone.
- Source: Dishonored wiki.

**Thief: Deadly Shadows**

- Loot is sold to fences in the City hub.
- The gold buys gear in shops.
- Source: Wikipedia.

**Proposal [ours]**: use a quota of about 30 / 45 / 60 % of the total by difficulty and about one secret per district (7 to 9 in all). Each secret pays out in a tool or a route, not only in gold. Difficulty re-authors patrols and removes items, as Thief II does.

---

## 5. Terrain, cliffs and a 100 m gorge at PS2 fidelity

### 5.1 What the era did (sourced)

- **Tiered landscape.** High-res terrain near, low-res proxies in the middle, and a rendered panorama on distant polygons, with the far budget spent on landmarks (SotC, Game Watch 2005).
  - Jak used simplified far backgrounds and flat cards for distant geometry (postmortem 2002).
  - Elden Ring gives large distant structures their own bigger streaming cells (CEDEC 2022).
- **Fog as a budget and a mood.** ICO used ocean and thick fog. Silent Hill turned hidden draw distance into atmosphere. SotC used bright haze, and explicitly *not* fog for its far terrain.
- **Shading in vertex colour.**
  - SotC stores lighting in vertex colour (Froyok).
  - Jak's tfrag blends 8 time-of-day palettes per vertex (OpenGOAL).
  - The PS2 sampled one texture per pass, so material blends were vertex-colour or alpha-weighted extra passes (Godbolt).
  - Community discussion suggests vertex-colour blends and floating "mesh decals" for walls and terrain transitions **[unverified: forum, polycount 2023]**.
- **Texture scale.** Environments tiled 256 × 256 textures; characters used 128 × 128 (Froyok).
- **Silhouette over polygons.** FromSoftware replaces straight cliff edges with jagged ones and layers vertical and depth fog gradients behind them. Light shafts are grouped toward the goal (CEDEC 2025).

### 5.2 What this means for our gorge and our rock **[ours]**

These are proposals drawn from the sources above.

- **Three distance tiers for the gorge.**
  - **Near**, within about 100 m of the player (SotC's foreground chunk size): real cliff geometry. Spend polygons on ledges you can use and on the top edge's silhouette.
  - **Middle**, the far wall of the gorge and the city faces seen across it: proxies at 1/30 to 1/100 of the polygons, with baked vertex colour and no unique props.
  - **Far**, the sea, the hinterland and distant ridges: panorama cards or skybox layers, updated only when the time of day or weather changes.
- **A height ruler.** Put horizontal strata bands (the Zumaia look) and one known object at each third of the 100 m drop:
  - a house at the top;
  - a mill, cistern outlet or aqueduct arch in the middle;
  - the river and a footbridge at the bottom.
  The eye measures the depth by stacking these familiar sizes.
- **Silhouette first.** Give the rim and the castle outline jagged, non-mirrored profiles. Leave flat faces to 256 px photo textures and vertex-colour AO. At night, the silhouette against moonlit fog is most of what reads.
- **Value.** Light the destination: the castle's torches, the bridge lamps, the palace's water glow. Keep the gorge sides dark. Give each district its own light colour key (CEDEC 2025 and CEDEC+KYUSHU 2022 applied to night).
- **Grow the city from the rock**, as Monsanto and Zafra do. Walls start where the cliff stops, and houses swallow boulders. The joins become features instead of seams.
- **Streaming seams** go at the bridge's gatehouses, the tunnels into the cisterns and the S-bends of the stair (Prince of Persia's S-corridors; Thief: Deadly Shadows as the warning).
- **Scene boxes.** Per-district volumes set fog density, exposure and bloom, and blend over a second or two when crossed (SotC).
- **Water at the bottom** is a sound landmark as well as a visual one. The river's roar grows as you descend.

### 5.3 Godot 4 mapping **[ours]**

- **Tiers and impostors**: `GeometryInstance3D` visibility ranges (begin and end distances, margins, and fade modes of self or dependencies), with `visibility_parent` for hierarchical LOD. A single larger mesh can replace many small ones, or a sprite impostor can replace a mesh at distance (Godot docs, "Visibility ranges (HLOD)").
- **Scene boxes**: `Area3D` volumes that tween the `Environment` settings (fog, exposure, glow). Check how this fits the existing environment setup before building it.
- **Occlusion**: baked occluders are the modern equivalent of Jak's precomputed visibility, good for the dense old town and the cistern bays.
- **Kits**: follow Skyrim's rule that footprints are multiples of one another and the snap grid is half a footprint (GDC 2013), mapped to our TrenchBroom grid.

---

## 6. Mapping to our districts **[ours]**

A first pass. Each district gets its own access form, play style, puzzle and intent, so the mission is several levels in one.

**Harbour**

- Access: open, but with several entries by water, quays, warehouses and ship (Shipping and Receiving).
- Gameplay and puzzle: light stealth and loot. Overheard talk sets up the plot.
- Landmark: the castle crown above, and a lighthouse or quay crane.
- Models: Shipping and Receiving; Peñíscola's walled rock and isthmus.

**Old town**

- Access: streets or rooftops.
- Gameplay and puzzle: a "Thieves' Highway" of houses as encounter cells; public and private space tiers.
- Landmark: the cathedral tower; tower-houses.
- Models: Life of the Party; Cáceres; Sapienza's Swiss cheese; Rabanastre's unreachable facades.

**Aqueduct**

- Access: a traversal spine along the top, maintenance ducts, and the water channel itself.
- Gameplay and puzzle: a fast shortcut between districts, open only after you reach its far end. It works as a loop home.
- Landmark: the arch line itself, a directional line toward the castle (CEDEC 2025).
- Models: Dark Souls shortcuts; the aqueduct-bridge as a boundary in the first Limgrave view.

**Palace of waters**

- Access: social. A party or reception, with a disguise or an invitation. Private tiers hold the loot.
- Gameplay and puzzle: water-channel valves change sound and light, drain pools and open the baths route.
- Landmark: the gilded dome; reflecting pools.
- Models: the Alcázar (Dorne); Life of the Party's party; Hitman's space types.

**Cathedral**

- Access: vertical, from the crypt up through the nave, triforium and bell tower.
- Gameplay and puzzle: a timing puzzle on bell ropes and chimes, as sound cover.
- Landmark: the bell tower, which is also where the mission starts.
- Models: Girona's stair; ICO's vertical interiors; Life of the Party's bell-tower start.

**Gorge and great bridge**

- Access: a mechanism. The drawbridge stations are key-locked, and the floodlights must be switched off.
- Gameplay and puzzle: the bridge as four sub-zones; you can go over, through or under it.
- Landmark: the bridge span and the river roar.
- Models: Kaldwin's Bridge; Ronda; Córdoba's bridge as a street; Farum Azula's fragments as walkways.

**Cisterns and catacombs**

- Access: hidden, through a clue combined from two other districts (a key half from the palace and one from the cathedral).
- Gameplay and puzzle: dread. A threat-free first half, then a hunted second half. Water levels rise and fall.
- Landmark: the vault-bay perspective; torch-lit mouths.
- Models: the Shalebridge Cradle; the Atarazanas vaults; the Haligtree's halves; the Undead Burg's one-way drops.

**Castle**

- Access: a count gate (2 of 3 tokens), plus a choice of the front gate (disguise, lethal), the cliff path (a climb, hinted by an NPC) or the cistern tunnel (secret).
- Gameplay and puzzle: an arrival procession and rampart walks under ranged threat, ending at the vault.
- Landmark: three different towers; a keep that runs off the frame.
- Models: Stormveil; Leyndell's count gate; the Dragonstone arrival; Zafra and Trujillo; Castle Sol.

**Escape**

- Access: a loop back down, by lift, rope, the aqueduct or the sea gate.
- Gameplay and puzzle: a return run over conquered ground.
- Landmark: the harbour lights.
- Models: Life of the Party's return; the lift back to Firelink.

**Draft 90-minute beat plan [ours]**

| Time | Beat |
|---|---|
| 0–10 min | Harbour arrival and panorama |
| 10–30 min | Old town and rooftops, with the aqueduct opened |
| 30–50 min | Palace of waters **or** cathedral (branch), to collect access tokens |
| 50–65 min | Gorge and bridge set piece **or** cisterns (dread) |
| 65–85 min | Castle ascent and vault |
| 85–90 min | Escape loop to the harbour |

Not every district is on the critical path. Two of the middle districts are alternatives, which makes replays and difficulty tiers work.

---

## 7. Sources

Grouped by section. The tags repeat those used above.

### Game of Thrones and House of the Dragon

- Gaztelugatxe (Wikipedia): https://en.wikipedia.org/wiki/Gaztelugatxe
- San Juan de Gaztelugatxe official site, Game of Thrones page [tourism]: https://sanjuangaztelugatxe.com/en/game-of-thrones-at-san-juan-de-gaztelugatxe/
- Alcázar of Seville and Game of Thrones, Fiona Flores Watson (andalucia.com) [tourism]: https://www.andalucia.com/cities/seville/alcazar/game-of-thrones.htm
- Turismo de la Provincia de Sevilla, Game of Thrones sets, including the Atarazanas [tourism]: https://www.turismosevilla.org/en/what-see-and-do/recommended-plans/game-thrones-sets
- fxguide, "Game of Thrones' fifth season of extraordinary effects" (Joe Bauer on Osuna) [primary]: https://www.fxguide.com/fxfeatured/game-of-thrones-fifth-season-of-extraordinary-effects/
- Roman amphitheatre of Italica (Wikipedia): https://en.wikipedia.org/wiki/Roman_amphitheatre_of_Italica
- Castle of Zafra, Guadalajara (Wikipedia): https://en.wikipedia.org/wiki/Castle_of_Zafra_(Guadalajara)
- Castle of Almodóvar del Río (Wikipedia): https://en.wikipedia.org/wiki/Castle_of_Almod%C3%B3var_del_R%C3%ADo
- Castillo de Almodóvar, Game of Thrones page [tourism]: https://castillodealmodovar.com/en/game-of-thrones/
- Turismo de Extremadura, Game of Thrones scenarios (Cáceres, Trujillo, Los Barruecos) [tourism]: https://www.turismoextremadura.com/en/ven-a-extremadura/Game-of-thrones-scenarios/
- Costa Brava Girona, Game of Thrones on location [tourism]: https://costabrava.org/en/blog/game-of-thrones-on-location/
- Peñíscola as Meereen [tourism]: https://www.servigroup.com/en/blog/peniscola-as-the-scene-of-shooting-in-game-of-thrones/
- Córdoba Roman Bridge as Volantis [tourism]: https://www.historyhit.com/locations/cordoba-roman-bridge/
- Monsanto and House of the Dragon (Portugal.com) [tourism]: https://www.portugal.com/place/monsanto-portugal-the-idyllic-scenery-for-house-of-the-dragon/
- Deborah Riley interview (Deadline, Matt Grobar, 17 Aug 2018) [primary]: https://deadline.com/2018/08/game-of-thrones-deborah-riley-emmys-hbo-interview-1202439600/
- Ronda (Wikipedia): https://en.wikipedia.org/wiki/Ronda

### Elden Ring and FromSoftware

- Miyazaki, Famitsu interview, 10 Mar 2022 (Frontline JP translation) [primary]: https://www.frontlinejp.net/2022/03/05/elden-ring-release-interview-with-director-miyazaki-part-1/
- CEDEC 2025, background layout (Sato and Katahira) [primary via report]:
  - GameMakers: https://gamemakers.jp/article/2025_09_02_116013/
  - 4Gamer (a): https://www.4gamer.net/games/866/G086614/20250723068/
  - 4Gamer (b): https://www.4gamer.net/games/866/G086614/20250724066/
  - CGWorld: https://cgworld.jp/article/202508-cedec-eldenring.html
  - Session page: https://cedec.cesa.or.jp/2025/timetable/detail/s67af327dba680/
- CEDEC+KYUSHU 2022, open-field "hospitality" (Miyauchi and Morita), Famitsu report [primary via report]: https://www.famitsu.com/news/202212/02283435.html
- CEDEC 2022, open-field systems (Matsumoto), Denfaminicogamer report [primary via report]: https://news.denfaminicogamer.jp/kikakuthetower/220825m
- Game Informer, "Elden Ring's First Legacy Dungeon Is Stormveil Castle" (Daniel Tack, 27 Aug 2021): https://gameinformer.com/preview/2021/08/27/elden-rings-first-legacy-dungeon-is-stormveil-castle
- Stormveil Castle (Wikipedia, with critics' citations): https://en.wikipedia.org/wiki/Stormveil_Castle
- The Escapist, "Stormveil Castle Is the True Tutorial of Elden Ring" (JM8, 2022): https://www.escapistmagazine.com/elden-ring-stormveil-castle-game-design-tutorial-anatomy/
- A.V. Club on Stormveil (2023): https://www.avclub.com/elden-ring-one-year-anniversary-stormveil-castle-1850158135
- Cathal Crumley, "Stormveil Castle: Defenceless Architecture" (2026): https://cathalcrumley.substack.com/p/stormveil-castle-tarnished-architecture
- Thoughts Thought, "The Best of Elden Ring's Level Design" (2024): https://doshmanziari.substack.com/p/the-best-of-elden-rings-level-design
- Fextralife wiki pages:
  - Raya Lucaria: https://eldenring.wiki.fextralife.com/Academy+of+Raya+Lucaria
  - Leyndell: https://eldenring.wiki.fextralife.com/Leyndell,+Royal+Capital
  - Haligtree: https://eldenring.wiki.fextralife.com/Miquella's+Haligtree
  - Castle Sol: https://eldenring.wiki.fextralife.com/Castle+Sol
  - Farum Azula: https://eldenring.wiki.fextralife.com/Crumbling+Farum+Azula
- GMTK, "The World Design of Elden Ring": https://www.youtube.com/watch?v=LvnlvB9n6ic (80.lv summary: https://80.lv/articles/a-look-at-the-world-design-of-elden-ring)
- GMTK, "The World Design of Dark Souls | Boss Keys": https://www.youtube.com/watch?v=QhWdBhc3Wjc
- The Level Design Book:
  - Undead Burg: https://book.leveldesignbook.com/studies/sp/undead-burg
  - Disneyland: https://book.leveldesignbook.com/studies/irl/disneyland
- Ribbing and Melander, "Examining the Souls's Series Level Design" (DiVA): http://www.diva-portal.org/smash/get/diva2:935733/FULLTEXT01.pdf
- "Worlds Worth Believing In: On Demon's Souls and Dark Souls" (Game Developer, 2015): https://www.gamedeveloper.com/design/worlds-worth-believing-in-on-demon-s-souls-and-dark-souls
- Grau, "Implicit Wayshowing in Open World Games" (2025): https://www.theseus.fi/handle/10024/904850
- Mondrety, "The World Design of Elden Ring, and 3 Lessons" (2022): https://www.linkedin.com/pulse/world-design-elden-ring-vishnu-vardhan-mondrety
- Scavnicky, "Elden Ring has a lot to teach architects..." (Archpaper, 2022): https://www.archpaper.com/2022/08/elden-ring-teach-architects-about-immersive-digital-space/
- Maj, "Otwarty świat i narracja rozproszona w grze Elden Ring" (2023; cites GMTK on the later linearity): https://bibliotekanauki.pl/articles/55995594

### PS2 era

- "The Making of Shadow of the Colossus" (Impress Game Watch, 7 Dec 2005, by Zenji Nishikawa; English translation, PDF mirror) [primary]: http://lukasz.dk/files/making_of_sotc.pdf
  - Original article: http://www.watch.impress.co.jp/game/docs/20051207/3dwa.htm
- Froyok (Léna Piquet), SotC PS2 breakdown (2012): https://www.froyok.fr/blog/2012-10-breakdown-shadow-of-the-colossus-pal-ps2/
- Fourcade, "The Art of Shadow of the Colossus (4/6): Visual Design" (Game Developer, 2014): https://www.gamedeveloper.com/design/the-art-of-shadow-of-the-colossus-4-6-visual-design
- "Game Design Methods of ICO" (GDC 2004), slide transcript [primary]: https://tale-of-tales.com/tales/ueda/transcript.txt
  - Notes: https://www.intelligent-artifice.com/2004/04/gdc_2004_game_d.html
- ICO developer interviews (shmuplations translation) [primary]: https://shmuplations.com/ico/
- Edge, "The austere masonry of Ico's castle..." (GamesRadar, 2015; Ueda quotes) [primary]: https://www.gamesradar.com/why-icos-castle-feels-real-place/
- Wireframe, "Ico's level design: when less is more" [unverified; not fetched, the page redirected and then returned 403]: https://wireframe.raspberrypi.com/articles/icos-level-design-when-less-is-more
- Ubisoft News, "Prince of Persia – Creating The Sands of Time Trilogy" (2024; Lacoste, Guyot) [primary]: https://news.ubisoft.com/en-us/article/3oAqiLg5k7GazIw5OWYTO2/prince-of-persia-creating-the-sands-of-time-trilogy
- Mallat, "The making of Prince of Persia: The Sands of Time" (Game Developer postmortem) [primary]: https://www.gamedeveloper.com/business/the-making-of-i-prince-of-persia-the-sands-of-time-i-
- Prince of Persia: The Sands of Time (Wikipedia; sand visions, S-corridors): https://en.wikipedia.org/wiki/Prince_of_Persia:_The_Sands_of_Time
- Final Fantasy XII (Wikipedia): https://en.wikipedia.org/wiki/Final_Fantasy_XII
- Isamu Kamikokuryo (Wikipedia): https://en.wikipedia.org/wiki/Isamu_Kamikokuryo
- Graham R, "A Guided Tour of Final Fantasy XII's Rabanastre" (2026): https://mechanizednarrative.substack.com/p/a-guided-tour-of-final-fantasy-xiis
- Castlevania: Lament of Innocence (Wikipedia): https://en.wikipedia.org/wiki/Castlevania:_Lament_of_Innocence
- Thief: Deadly Shadows (Wikipedia): https://en.wikipedia.org/wiki/Thief:_Deadly_Shadows
- PC Gamer on the TDS Gold mod (2014): https://www.pcgamer.com/thief-deadly-shadows-mod-removes-mid-mission-loads-redesigns-transition-zones/
- White, "Postmortem: Naughty Dog's Jak and Daxter" (Game Developer, 2002) [primary]: https://www.gamedeveloper.com/design/postmortem-naughty-dog-s-i-jak-and-daxter-the-precursor-legacy-i-
- OpenGOAL documentation:
  - Drawable and TFrag: https://opengoal.dev/docs/porting-info/drawable_and_tfrag/
  - Porting tfrag: https://opengoal.dev/docs/porting-info/drawable_and_tfrag/porting_tfrag/
- Jak II (Wikipedia): https://en.wikipedia.org/wiki/Jak_II
- Dragon Quest VIII (Wikipedia): https://en.wikipedia.org/wiki/Dragon_Quest_VIII
- Silent Hill (Wikipedia): https://en.wikipedia.org/wiki/Silent_Hill_(video_game)
- Copetti, "PlayStation 2 Architecture": https://www.copetti.org/writings/consoles/playstation-2/
- PlayStation 2 (Wikipedia): https://en.wikipedia.org/wiki/PlayStation_2
- Godbolt, "Rendering in SWAT: PlayStation 2" (2010) [primary]: https://xania.org/201003/swat-ps2-renderer
- PlayStation Blog, "The Polygonal Evolution of 5 Iconic PlayStation Characters" (2019): https://blog.playstation.com/2019/12/16/the-polygonal-evolution-of-5-iconic-playstation-characters/
- Polycount, "Blending of textures in PS2" (2023) [unverified]: https://polycount.com/discussion/232570/blending-of-textures-in-ps2

### Stealth missions

- Thief wiki:
  - Life of the Party: https://thief.fandom.com/wiki/Life_of_the_Party
  - Shipping... and Receiving: https://thief.fandom.com/wiki/Shipping..._and_Receiving
- Thief and Thief 2 level designer credits: http://www.digital-eel.com/zdim/stuff/TDPdesign.htm
- Keverne, *Groping the Map: Life of the Party*:
  - Part 1: https://gropingtheelephant.com/blog/?p=2771
  - Part 4: https://gropingtheelephant.com/blog/?p=2925
- Whalen, *Evangelizing Thief*, "Shipping... and Receiving" (2015): https://thiefdesign.blogspot.com/2015/06/thief-ii-mission-2-shippingand-receving.html
- The Level Design Book:
  - Assassins: https://book.leveldesignbook.com/studies/sp/assassins
  - Pacing: https://book.leveldesignbook.com/process/preproduction/pacing
- Sabbagh, "Thief: tense narrative through level design and mechanics" (Game Developer, 2017): https://www.gamedeveloper.com/design/thief-tense-narrative-through-level-design-and-mechanics
- Robbing the Cradle (Wikipedia): https://en.wikipedia.org/wiki/Robbing_the_Cradle
- GDC Radio, Randy Smith on stealth design (Game Developer, 2006): https://www.gamedeveloper.com/game-platforms/gdc-radio-i-thief-i-s-randy-smith-on-stealth-gameplay-design
- Dishonored (Wikipedia): https://en.wikipedia.org/wiki/Dishonored
- Dishonored 2 (Wikipedia): https://en.wikipedia.org/wiki/Dishonored_2
- Dishonored wiki:
  - Kaldwin's Bridge: https://dishonored.fandom.com/wiki/Kaldwin%27s_Bridge
  - The Royal Physician: https://dishonored.fandom.com/wiki/The_Royal_Physician
- Steve Lee, "Level Design Workshop: An Approach to Holistic Level Design" (GDC 2017; abstract only): https://www.gdcvault.com/play/1024301/Level-Design-Workshop-An-Approach
- Savage, "The making of Sapienza, Hitman's best level" (PC Gamer, 2017) [primary]: https://www.pcgamer.com/the-making-of-sapienza-hitmans-best-level/
- "From 'Coastal Town' to Sapienza" (Game Developer, 2017): https://www.gamedeveloper.com/design/from-coastal-town-to-sapienza-designing-a-i-hitman-i-level
- "Hitman dev says the secret to expansive level design is spirals" (Game Developer, 2017): https://www.gamedeveloper.com/design/-i-hitman-i-dev-says-the-secret-to-expansive-level-design-is-spirals
- "Mapping out the subtle social cues throughout Hitman's level design" (Game Developer, 2019): https://www.gamedeveloper.com/design/mapping-out-the-subtle-social-cues-throughout-i-hitman-i-s-level-design
- "Level Design in HITMAN: Guiding Players in a Non-Linear Sandbox" (GDC Europe 2016; abstract only): https://www.gdcvault.com/play/1023872/Level-Design-in-HITMAN-Guiding
- Burgess and Purkeypile, "Skyrim's Modular Approach to Level Design" (Game Developer, 2013) [primary]: https://www.gamedeveloper.com/design/skyrim-s-modular-approach-to-level-design

### Engine

- Godot docs, "Visibility ranges (HLOD)": https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html

### Could not verify or access

- The GDC Vault videos: only abstracts were read.
- The TTLG thread with Pagliarulo's own answers, the Beyond3D polygon thread, and the gamedev.net PS2 terrain thread all returned 403.
- HowLongToBeat could not be fetched; its figures came via a search summary.
- No primary PS2 per-frame polygon counts or FFXII environment figures were found.
- Primal: no primary sources found.
