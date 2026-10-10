# Card: the street and canal kit (Zócalo family 1)

**Status:** awaiting the user's approval (Oct 10 2026). Family 1 of the
Zócalo spec's build order (docs/superpowers/specs/2026-10-10-zocalo-district-design.md,
section 5.3): everything the rest stands on.

## Source: what it should look like

- **The paving.** The centre was paved in volcanic stone: grey-black basalt
  (*recinto*) setts in the streets, larger flags in the plaza, kerbs and
  steps of grey chiluca (`materials_textures_ornament.md`, sections 1 and 9;
  the bible's texture table, item 9). Casasola-era photographs of the 1920s
  Zócalo show a stone plaza crossed by tram lines, its edges worn smooth
  where crowds and carts turned.
- **The causeway stone** (the frame spec's shared thread): a band of older,
  darker, larger basalt running through each district towards its station:
  the line of the Aztec causeway under the colonial grid
  (`architecture_and_city.md`, section 1: the Iztapalapa causeway entered the
  city here).
- **The trams.** Electric trams ran from 1900 on the Mexican Light and Power
  Company's lines (`life_society_1920s.md`, "Trams"): steel grooved rails set
  flush in a strip of granite setts, with point blades at the junctions.
- **The canal.** The Acequia Real (the Canal de la Viga) entered the city with
  trajineras, landings, low bridges and willows (`architecture_and_city.md`,
  section 1; "the lake memory": canal water, flat boats, garitas at the
  waterline, dikes with gaps). Its walls are rubble masonry capped with cut
  stone; landings step down to the water; iron rings for mooring.

## Inspirations it carries (the user's rule: an advanced look, not a copy)

- **Thief:** lived-in wear: setts polished where feet go, puddles in the
  hollows, moss in the joints by the water.
- **Dishonored:** painted weight: chunky kerbs and copings with soft-cut
  edges, so the street reads from across the plaza.
- **Grim Fandango:** deco-noir silhouettes in the seeped pieces: the steel
  bridge's stepped piers and riveted bands.
- **Deadlock:** occult industry in the street: conduit and junction boxes
  bolted to colonial stone, numbered hatches over the new tunnels.
- **Game of Thrones:** grounded wear: no piece looks new; every surface has
  been mended at least once.

## Change: what the world did to it (each mark from an event field)

- **Subsidence** (strong round the cathedral and the old lake's edge):
  - the paving heaves and dips in long swells
  - kerbs tilt and sink
  - setts are relaid in patches of a different stone
  - tram rails are shimmed with steel plates where the ground fell away
  - The heave is a piece variant chosen by the field at placement, so flat
    pieces still tile.
- **Water** (the drain failed in 1900 and the canal came back):
  - The canal walls are **two eras on top of each other**: colonial ashlar
    below, hasty rubble above it where the walls were raised again.
  - A tide line and a green band at the waterline.
  - Drains choked with silt.
  - Iron rings worn bright.
- **Seepage** (dense round the palace and the station):
  - The tram rails carry a **third, insulated conductor rail** for the
    "novel transport" that runs the ring (the Zócalo's dressing).
  - Conduit runs along the kerbs into junction boxes.
  - Numbered iron hatches cover the Line 2 service shafts.
  - **One bridge is seeped steel**: a riveted girder span with stepped deco
    piers, patched to the old stone abutments with the Company's brass plates
    (the same patches as the kiosk and the arcade's steel column).
- **Use** (the market, the ring, Madero):
  - wear and polish on the setts
  - grime along kerbs
  - repairs in fresh stone where carts broke it

## Pieces (Blender object names)

| Object | What it is |
|---|---|
| `kerb_straight` | A chiluca kerb, 1.5 m, 0.3 wide, 0.2 proud of the street, its top worn round |
| `kerb_corner` | The kerb turning 90°, outside corner |
| `kerb_drop` | A kerb ramped down to street level at a crossing |
| `gutter_grate` | An iron drain grate in a stone gutter, 1.5 m |
| `causeway_band` | The causeway stone: a 3 m wide strip of large dark basalt slabs, 3 m long, tiling along its length, flush with the setts |
| `tram_track` | Two grooved rails in a 2.4 m strip of granite setts, 4.5 m long, flush |
| `tram_track_curve` | The same on a 90° curve, centre-line radius 12 m (for the ring's corners) |
| `tram_conductor` | The seeped third rail in its insulated chairs, laid along a `tram_track` (a separate object so it can be left out) |
| `hatch` | A numbered iron hatch, 1.2 m square, in a basalt frame (the user paints the numbers) |
| `junction_box` | A steel junction box with conduit stubs, bolted to a kerb |
| `canal_wall` | A canal wall 4.5 m long, 2 m from the street down to the water: ashlar below, rubble above, chiluca coping; its back is buried |
| `canal_wall_corner` | The same, turning 90° |
| `canal_landing_steps` | Stone steps from the street down to a landing, 1 m, and from the landing down to the water, 1 m (fits the plan's landings) |
| `mooring_ring` | An iron ring on a stone, set into the coping |
| `culvert` | An arched drain mouth in the canal wall, choked with silt |
| `bridge_stone` | A low stone arch bridge across the canal and its quays, 22 m long, 4 m wide, parapets 0.9 m |
| `bridge_steel` | The seeped steel bridge in the same place: riveted girders on stepped deco piers, brass-patched to the old abutments |

The plaza's flags, the street setts and the earth under them are **ground
tiles**, not pieces: Ground.gd lays them, hex-tiled, from recipes
(`ground_flags` for the plaza, `ground_setts` for the streets, the
`ground_earth` already painted).

## Dimensions (metres)

- **Grid:** 1.5 m along streets (kerb, gutter, track pieces tile at 1.5 or
  4.5); joints on 0.25.
- **Street:** the setts' top is y = 0; kerbs 0.2 proud; the arcade floors'
  0.25 step stays the arcade kit's.
- **Canal:** street at 0, landings at −1, water and canal floor at −2 (the
  plan). Wall thickness 0.6 at the coping. Coping 0.35 deep, 0.15 proud of
  the wall's face.
- **Bridges:** 4 m deck, 0.9 m parapets; the stone arch's crown 0.6 above the
  quays; deck ends meet the quays' setts flush (no step a player trips on).
- **Budgets (triangles):** kerb and gutter pieces ≤ 150; track ≤ 400 (curve ≤
  900); canal wall ≤ 600; steps ≤ 500; bridges ≤ 3,000 each; small props ≤ 200.

## Slots: material regions, with the Zócalo palette colours they lean toward

| Slot | Material | Palette |
|---|---|---|
| `basalt` | Volcanic setts, flags, the causeway band, hatch frames | `#14121a`, `#3a3340`, `#5a5560` |
| `chiluca` | Kerbs, copings, steps, arch voussoirs | `#5a5560`, `#8a8790`, `#b9b4b0` |
| `rubble` | The canal walls' raised courses, culvert mouths | `#3a3340`, `#5a5560`, `#7a5a24` |
| `steel` | Rails, the conductor rail, the steel bridge, junction boxes | `#3a3340`, `#5a5560` |
| `iron` | Grates, hatches, mooring rings | `#14121a`, `#2a3b2e` |
| `brass` | The Company's patch plates | `#7a5a24`, `#c49a40` |

## Joints the joint renders must frame

1. Kerb to setts (and kerb drop to the crossing)
2. Gutter grate to kerb and setts
3. Causeway band to setts on both sides
4. Tram strip to setts; curve to straight
5. Conductor rail chairs to the strip
6. Hatch frame to setts
7. Canal coping to the quay's setts
8. Ashlar courses to rubble courses
9. Landing steps to the coping, the landing and the water
10. Culvert arch to wall
11. Bridge abutment to quay (stone and steel); steel girder to brass patch
12. Bridge deck end to setts (flush)

## What I need from you

- **Approval** of this card (or changes).
- **Textures:** I'd fetch two more CC0 Poly Haven scans:
  - [volcanic_rock_tiles](https://polyhaven.com/a/volcanic_rock_tiles) for the plaza's flags and the causeway band
  - [stone_wall_04](https://polyhaven.com/a/stone_wall_04) for the canal's rubble

  The chiluca and steel keep the scans we have. If you'd rather paint or
  source the basalt yourself, say so and it stays a stand-in until then.
- **Words:** the hatch numbers and anything on the junction boxes are yours;
  the pieces carry blank canvases for them.
