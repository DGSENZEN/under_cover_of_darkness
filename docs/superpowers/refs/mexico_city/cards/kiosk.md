# Card: the Metro kiosk

**Status:** approved by the user, Oct 9 2026 (style lab, Task 1).

## Source: what it should look like

The Light Company's entrance to a Metro station. It is built in the 1920s Mexico City manner (Art Nouveau iron meeting Aztec-revival deco) over a stair that seeped in from 1969.

- **Hector Guimard's Paris Métro entrances (1900-1913):**
  - **The open "entourage":** a cast-iron balustrade around the stair head with two sinuous lamp stalks at the entry, each holding a red-orange globe, and the sign held between them. 154 of these were built. ([Wikipedia: Paris Métro entrances by Hector Guimard](https://en.wikipedia.org/wiki/Paris_M%C3%A9tro_entrances_by_Hector_Guimard))
  - **The roofed "édicule"** (Abbesses, Porte Dauphine): a fan-shaped "butterfly" glass roof carried on a central girder, an iron frame with enamelled lava panels, and wired glass. The iron is painted a green that evokes oxidised brass. ([Wikipedia: Abbesses station](https://en.wikipedia.org/wiki/Abbesses_station); [Architecture of the Paris Metro](https://en.wikipedia.org/wiki/Architecture_of_the_Paris_Metro))
- **Mexico City's 1920s neo-prehispanic deco:** stepped-fret (xicalcoliuhqui) and Mixtec-glyph ornament on new buildings, such as the Frontón México (1929) and La Nacional (1929-32). (`materials_textures_ornament.md`, section 5; `architecture_and_city.md`, section 4)
- **The 1969 Mexico City Metro:** tiled stair walls banded in the line's colour, terrazzo and concrete steps, and a station pictogram over every entrance (Lance Wyman's system; ours are new, painted by the user). (`bible.md`, the Metro section)

## Change: what the world did to it

- **The stair is seepage.** A 1969 Metro stair: terrazzo steps, walls banded in Line 2 blue tile. Nobody in 1923 built it; it was simply there after the Eclipse.
- **The kiosk is the Company's answer.** The Light Company framed the stair in its own iron: Guimard's open balustrade, but its panels are cast as **stepped frets** instead of plant forms. Two lamp standards at the entry carry the Company's globes (the lamps thread). A small **fan canopy** of wired glass on a central girder covers only the stair head, not the whole enclosure.
- **Where 1920s iron meets 1969 concrete, brass patch plates** are bolted over the joint: the Company's repairs, slightly too big and slightly crooked.
- The sign holder between the stalks carries a **blank panel**, the canvas for the user's glyph and station name.

## Pieces (Blender object names)

| Object | What it is |
|---|---|
| `kiosk_coping` | The stone curb the iron stands on: 0.375 m wide, 0.25 m high, around the three closed sides of the opening |
| `kiosk_balustrade` | Top rail, bottom rail and posts: 1.0 m high above the coping |
| `kiosk_frets` | The stepped-fret panels between the posts: real geometry, one thick extruded profile |
| `kiosk_lamp_left`, `kiosk_lamp_right` | Lamp standards at the entry corners: 3.5 m to the globe's centre, a globe 0.375 m across |
| `kiosk_sign` | The sign holder between the stalks, its underside at 2.5 m, holding the panel |
| `kiosk_sign_panel` | The canvas: a flat panel 1.5 × 0.5 m, its own UV island |
| `kiosk_girder` | The central girder from the lamp stalks back over the stair head |
| `kiosk_canopy_frame` | The fan ribs |
| `kiosk_canopy_glass` | The glass of the fan, single-sided, slot `glass` |
| `kiosk_patches` | The brass patch plates: 4-6 of them, at the coping-to-stair-wall joints |
| `kiosk_stair` | 20 steps (rise 0.15, tread 0.30): 6.0 m of run, 3.0 m of drop |
| `kiosk_stair_walls` | The two side walls and the landing wall at the bottom, tiled |

## Dimensions (metres)

- **Opening:** 3.0 × 6.0, the long axis along the stair. The entry is the open short side; the closed sides carry the balustrade.
- **Origin:** the centre of the entry edge, at street level (the top of the first step). Y is up on export.
- **Height:** the canopy's lowest edge at 3.0 m, the girder's top at 3.5 m.
- **Grid:** 0.25 m for every outer bound and every joint between pieces. Step rise and run (0.15 / 0.30) follow the 1969 stair, not the grid: the grid governs joints, not every vertex.
- **Budget:** at most 2,500 triangles.

## Slots: material regions, with the Zócalo palette colours they lean toward

| Slot | Material | Palette |
|---|---|---|
| `iron` | Company iron, oxidised-brass green-black | `#2a3b2e`, `#3f7a52` |
| `brass` | Patch plates, lamp collars | `#7a5a24`, `#c49a40` |
| `glass` | Canopy and globes; not painterly, its own translucent material | none |
| `tile_line2` | 1969 stair-wall tile, Line 2 blue band over off-white | `#2f4c7a`, `#e8d8a8` |
| `stone_step` | Terrazzo steps and the stone coping | `#5a5560`, `#8a8790`, `#b9b4b0` |
| `sign` | The canvas panel | Painted by the user |

## Joints the joint renders must frame

1. Balustrade posts to coping
2. A fret panel to its rails and posts
3. Lamp base to coping
4. Sign holder to both stalks
5. Girder to the lamp stalks
6. Fan ribs to the girder
7. Glass to ribs
8. Top step to coping (the entry edge)
9. Stair walls to coping (with the brass patches)
10. Stair walls to steps
11. Landing wall to side walls

## Sign panel: the canvas for the user

- **Size:** 1.5 × 0.5 m, at 48 px per metre: **72 × 24 px** in the atlas, at a fixed rectangle the Task 3 script reports.
- **What goes on it:** the station glyph on the left and the name space on the right. The user paints both. Claude leaves it a flat mid-grey.
