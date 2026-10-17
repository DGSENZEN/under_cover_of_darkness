# The Metro Underground: design

Date: 2026-10-16. Settled with the user in conversation. Part of the Mexico
City demo (`2026-10-16-mexico-city-demo-program.md`) and the Eclipse city
frame (`2026-10-09-eclipse-city-frame-design.md`, section 5, the Metro).
Lines marked *(Claude's call)* were proposed by Claude and either accepted or
not corrected. Everything else is the user's.

## 1. Intent

The Metro Underground is **the first real piece of level design in the new
city**, and it sets the quality bar for everything after it. The user's words:
"we want the Metro Underground to feel really authored and inspired, we want a
lot of details, bespoke effect work". Also: "it's basically dressing for the
setting plus just getting the player into the world by immersing them in it."

Nothing made for the Zócalo so far meets the bar ("None, that is why I want
us to really get it good"). Claude's diagnosis, which the user agreed with:

- **Models are primitive.** They are boxes and faceted cylinders, with no
  bevels, no exaggerated proportion, no secondary detail, and no silhouette
  that reads from its shadow.
- **Textures are smeared, not painted.** The Kuwahara-filtered scans read as
  mush. Values are low in contrast and washed purple, and no value structure
  was designed. There is no top light, no edge wear and no separation between
  materials.
- **The feel is flat.** The buildings are blank boxes, the light has no
  strong shapes, and nothing reads as lived in.

What the user would wince at is exactly this: **models, textures, and the
general feeling being wrong.**

## 2. What it is

- **Where:** under the Zócalo. This is the Zócalo's Line 2 station and the
  world grown around it. The opening (demo program, step 6) arrives here by
  Metro car; the player walks out through station, corridors and stairs into
  the plaza. The Zócalo's existing Metro entrances lead down into it.
- **How big:** about **20 minutes for a curious player to see all of it**.
  That makes it a full sub-level, about the size of a Thief mission's
  underworld, not a station you pass through.
- **What the player does:**
  - gets leads;
  - talks to characters;
  - does small sub-quests that lead up into the Zócalo or to other areas' quests;
  - above all, is immersed in the setting.
- *(Claude's call)* It is a calm place, not a fight. There are no guard
  patrols or combat set pieces. The danger is mood and folklore, and the
  creatures are mostly life, not enemies.
- *(Claude's call)* The talk and quest systems do not exist yet (demo program
  step 5). This project builds the places where characters live, such as a
  stall keeper's counter, a shrine keeper's corner and a squatter's nook, and
  stages them with placeholder figures. The user writes all words and quests
  later.
- *(Claude's call)* The 20 minutes come from wandering and noticing. Alleys
  pay off with a small scene, a vista or a character, not loot. A few climb
  routes (pipe runs, catwalks, a vent shaft) let free-running reach hidden
  corners. It is not an obstacle course.
- **The demo order:** this project starts now, ahead of the demo program's
  powers and combat steps. That is the user's choice. Its people and quests
  are filled in once talking is built.

## 3. The look and the feel

### 3.1 A real metro, made picturesque

It must **look and feel like an actual metro station** that a passenger can
navigate:
- line colours (Line 2 is blue);
- hanging direction signs;
- *Correspondencia*, *Salida* and *Andén* signage pointing the way;
- station glyphs in the spirit of Lance Wyman's pictograms. Ours are new, and
  the user paints them;
- tiled walls, turnstiles and a ticket booth.

It is **much more picturesque** than any real station, and it feels like a
world of its own:
- pipelines everywhere;
- fume vents breathing;
- little creatures here and there;
- corridors lined with stalls under neon signs;
- side alleys and side passages;
- graffiti and posters.

**No explicit 80s tech.** The period comes from mixing what we have built:
- the Eclipse's seepage of the future Metro into colonial tunnels;
- the Light Company's brass and wood patches;
- our VFX register.

Folklore gives it grit: ofrendas, curandera stalls, copal smoke, marigold,
and painted saints beside the signage.

### 3.2 Older means more Aztec and more Deadlock

"As it gets older it should feel more Aztec and Deadlock in its essence."
*(Claude's call:* older means deeper, so the player walks back in time going
down.*)* The layers:

1. **The working station.** Ticket hall, platforms, signage. It is readable and
   real, built from our materials plus grime, drips, posters and graffiti.
2. **The corridors and the market.** Pasillos lined with puestos, side
   alleys and service passages. Folklore creeps in here, with creatures under
   stalls and in the pipes.
3. **The old passages.** Colonial vaults and drains give way to Aztec stone:
   carved walls, and a temple shell standing inside the tunnel. The anchor
   is the real Ehécatl temple inside Pino Suárez station. Ours is invented,
   not a copy (the INAH rule). The Deadlock essence is strongest here: bold
   painted shapes, heavy colour, authored light and effects, stranger
   creatures. The pipes run on, corroded and sunk into stone.

The existing crypt, the Templo Mayor shells and the pawnshop vault under the
cathedral belong to this oldest layer.

### 3.3 References

The user's verdict on the reference board: **a hodge-podge of all of it.**
The CDMX Metro cards got the most clicks, so it is the base of the mix:
- Wyman's pictograms;
- opening week in 1969;
- the Zócalo platform and its exit tunnel;
- stalls swallowing a Metro entrance (Hospital General);
- hanging direction signs;
- Pino Suárez's Ehécatl temple.

Layered on top:
- **Deadlock:** the neon Broadway lane (Times Square), the subway tunnel under
  it, the Haunted Lot's sickly light and fungus. Valve has published nothing
  on its painting method, so we read it from screenshots.
- **Mike Mignola:** black as a shape drawn first; simplified planes; chunky
  silhouettes; rough stone, skulls and ornament; Dave Stewart's flat, limited
  colour with one red accent. The nearest film is *Hellboy II*'s Troll Market,
  a vertical, lantern-lit market under a bridge.
- **New York subway, 1970s-80s:** cars tagged inside and out, mosaic name
  tablets, tiled platforms, tired light.
- **Also:** Dishonored 2 (Arkane's documented painterly method: "volumes and
  masses", no noise); Arcane's Zaun (an under-city in coloured haze);
  Metro 2033 (the station as a town).

The board, with sources and licences, is saved at
`.superpowers/brainstorm/15850-1792200839/content/reference-board.html`.
That folder is excluded from git. Copy it into `docs/superpowers/refs/` if it
needs to last.

## 3b. The car and the ride (in scope, user)

The opening's first sight is the ride between rifts, so this project builds
it. It follows the frame spec, section 5.3:

- **The orange car**, after the MP-68 / NM-73: rubber-tyred, with a walkable
  interior, built to the new standard as a hero model. Its exterior is grimed,
  tagged and patched with Light Company brass and wood. Its line indicator
  flips colour.
- **The ride scene** is built once and reused. The car stands still and the
  tunnel scrolls past, so the player walks freely inside with no
  moving-platform physics. The windows run the sequence:
  1. colonial brick vaults;
  2. the Aztec temple shells stacked in the dark;
  3. the tears opening onto the void, with ghost stations and the drifting
     districts.

  It is effects-heavy and bespoke.
- **The ride hides the load** (about 30-40 s, holding longer if the load is not
  done). The doors open onto this level's platform, where the car waits in the
  same pose.
- *(Claude's call)* For the demo, the ride ends here. It reuses the frame
  spec's route and ghost-station data, so the other districts can plug in
  later.

## 4. The new standard for models and textures

- **Past the PS2 limits.** The old triangle budgets (the kiosk was capped at
  2,500) and nearest-filtered textures no longer bind. **The pixel-grid screen
  is turned off** (user). *(Claude's call:* the new standard holds from here
  on, so the Zócalo is lifted to it in time.*)*
- **Built in a live Blender session** over the Blender connection, with renders
  shown as each model develops. The user can open the same file and push
  vertices. Their edits flow back through the existing workshop round trip
  (`level.sh workshop` / `yours.json`).
- **Shape first.** Chunky, slightly exaggerated proportions; big soft bevels; a
  silhouette that reads from its shadow. Then secondary detail: rivets,
  hinges, welds, chips, cable ties.
- **Textures painted in layers, Deadlock-style:**
  1. a flat colour field designed per material;
  2. a top-down light gradient;
  3. baked AO and curvature driving bright worn edges and dark grime in crevices;
  4. brush-stroke breakup;
  5. Mignola's solid black in the deepest recesses.

  The existing light shader (warm ramp, painted ambient and rim) goes on top.
  Grime, graffiti, posters and signage are **decals**, so one model can be
  dressed many ways.
- **The user's brush sheets.** The user made these five greyscale painterly
  masks themselves. They are in `~/Downloads/Texture_Abstract00.png` to
  `04.png`; one is named `Texture_Abstract01 .png`, with a space. They hold
  blocky flat-brush strokes, spray speckle and chipped patches. Three have
  alpha and two are solid light washes. Most tile; 02 and 03 have faint seams
  to clean.
  - **The raw sheets stay out of the public repo** (user). They are kept in a
    local, git-excluded folder the way `textures/ps2` is.
  - *(Claude's call: a reading of "I made them" for the user to confirm.)* The
    textures we paint with them count as self-made and are committed, so a
    clean checkout renders the level.
  - *(Claude's call)* Sheets 02 and 03 give stroke breakup on large surfaces,
    04 gives edge wear and crevice grime, and 00 and 01 give gentle variation
    within a material.
- **Effects are part of the model.** Neon that buzzes and flickers, steam from
  vents, dripping water. A piece is not finished until its effects are in.
  Effects are made in house (no free VFX assets).

## 5. How the work proceeds

1. **The hero piece: a corridor stall with its neon sign** (agreed). It tests
   wood, metal, cloth, neon, clutter and a touch of folklore at once. It is
   iterated with the user until approved. What it teaches becomes **the
   recipe**: modelling rules, texture layers, shader settings, decal use and
   effects, written down for every piece after it. Nothing is made at volume
   before that.
2. **The layout.** The existing greybox is a skeleton:
   - a 60×30 m ticket hall 8 m down;
   - two 100 m platforms 14 m down;
   - four plain corridors to the kiosk stairs;
   - a 145 m tunnel to the crypt.

   It is re-planned in the existing level pipeline
   (`tools/level/layouts/zocalo/station.py` and the plan / greybox / sheets
   tools) to the 20-minute scope, with the three layers, the corridors and
   market, side alleys, service and pipe passages, climb routes, and the
   character places. The user approves the sheets and walks the greybox for
   route, sightlines and the station-to-Aztec shift. The kiosk's 3 m stair is
   reconciled with the greybox's 8 m drop.
   *(Claude's call:* the hero piece and the layout don't depend on each other
   and may run side by side. Models at volume wait for both.*)*
3. **Then models in sets** (user): after the hero piece, the user reviews a
   family at a time, for example a stall with all its variants or the whole
   pipe kit. Sets come in an order the layout dictates. Each set is built,
   painted, given its effects and placed, then reviewed by the user in game
   and fixed before the next set starts. The car is a hero model and is
   reviewed on its own.

## 6. Standing rules that apply

- Models in supervised sets (the hero piece and the car on their own). Jitter, odd geometry and seams are fixed
  before moving on.
- Kit pieces are closed, solid meshes with no layered quads. Walk-test with the
  player. Hole-scan and close-up renders of every joint before calling a piece
  done. Never call a visual defect harmless.
- Every strange thing has a cause in the world's events: the pipes are the
  Light Company's power and heat; creatures have reasons to be there. No
  magic is sprinkled in.
- Scenes, not sprinkles: dressing is staged scenes with a cause, never uniform
  spacing. Detail a lot.
- The user writes all words and paints or sources the signature designs:
  station glyphs, posters, graffiti pieces, sign artwork and station tile.
  Claude asks when one is needed and never stretches stand-ins.
- Textures are CC0 or self-made in the public repo. Real monuments are
  remixed, not copied (INAH).

## 7. Non-goals

- Combat, guards and stealth set pieces down here.
- Rides to the other districts (Roma, Lomas, Condesa); they plug into the same ride scene later.
- Dialogue, quests and the talk UI (demo program step 5; places are staged
  for them).
- Explicit 1980s technology on display.

## 8. Calls settled after the builder check *(all Claude's calls)*

- **Its own map, loaded during the climb.** The Underground is its own map,
  not part of the Zócalo scene. A 20-minute level at the new standard, stacked
  into the Zócalo (which has already missed its frame budget), is too great a
  risk. The walk out stays unbroken: the long exit stair and tunnel up to the
  kiosk hide the Zócalo's load, just as the ride hides the station's. The
  Zócalo's kiosks lead down into this map the same way. This becomes a new
  gate kind in `Districts` / `CityState`.
- **Nothing is gated.** On arrival a clear, readable spine runs from the
  platform to the exit, inside the five-minute opening. Everything else (the
  market, the alleys, the old layers) is open to wander from the first visit,
  and every branch loops back to the spine, so the player can always return to
  a train.
- **Older really is deeper.** The oldest layer sits below the platforms
  (below −14 m). The existing crypt, Templo Mayor shells and pawnshop vault are
  re-planned into it, rebuilt to the new standard and counted in the 20
  minutes. The crypt keeps its link up to the cathedral.
- **Creatures are ambient life, not AI.** They are animated life with simple
  reactions, such as scattering or hiding when the player comes close, and
  peering out again, in the manner of the existing pigeons. They have no
  perception or nav systems.
- **The grid goes off everywhere** (it is a global setting). The Zócalo near
  the exits stays at the old standard until its own lift. The mismatch is
  accepted for now and named as unfinished, not hidden.

## 9. Left to the builder

- The exact layout: room sizes, routes and the placement of each scene and
  character place, within the user's approval of the sheets.
- New triangle and texture budgets, and the performance target, set by
  measuring the hero piece.
- Shader and bake specifics of the texture layers, and how the brush sheets
  are applied.
- First proposals for creature designs and their causes, shown to the user
  before modelling.
- The order of models after the hero piece.
