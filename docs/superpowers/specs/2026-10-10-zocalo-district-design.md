# The Zócalo district: design

Date: 2026-10-10. Branch: eclipse-city. The first district of the Eclipse
city (docs/superpowers/specs/2026-10-09-eclipse-city-frame-design.md,
section 4: the hub). The look is settled (the style lab; variant D with
vertex paint, the macro layer and hex-tiling,
docs/superpowers/specs/2026-10-09-eclipse-vertex-paint-design.md).

## 1. Intent

The user: keep building assets for the Zócalo map, with stills as each piece
is built. The map is planned first (frame spec decision D2: a drawn
top-down plan the user approves), then built family by family.

Two principles from the user govern every asset (Oct 10 2026):

- **An advanced art style, not a 1:1 copy.** The PS2 era is a seasoning,
  not a target. Each kit family names the inspirations it carries and how:
  Grim Fandango's deco-noir silhouettes, Deadlock's occult industrial,
  Dishonored's painted weight, Thief's lived-in grime, Elden Ring's scale,
  Game of Thrones' grounded wear. Real buildings are remixed, never copied
  (frame spec, the INAH rule).
- **A world built by its events.** Everything looks as it does because
  something happened to it: the Eclipse of 1923 and its seepage, the
  sinking lakebed, the failed drain and the returning canal, the
  Inquisition that never closed, 1980s machinery bolted into colonial
  rooms. No magic sprinkled in, no runes, auras or glows for their own
  sake; any uncanny thing is a physical thing with a history.

## 2. The plan as data

The map is a layout in the existing level pipeline:
`tools/level/layouts/zocalo.py`, its parts in `tools/level/layouts/zocalo/`
(plaza, cathedral, palace, south and canal, madero, santo_domingo,
templo_mayor, market, station, edges). `build.py` builds its .blend,
`export.py` and `LevelLoader.gd` bring it into `maps/zocalo.tscn`, and the
user's workshop round trip stays.

Before any kit piece exists, each part lays **plan elements**, at true scale
on the kit grid (metres; plan x east, y north; the level's own axes follow
the pipeline's convention):

- **Ground areas:** plaza, streets, the canal and its landings, the market
  floor, and the **brink**, the edge where the map ends at the void.
- **Plots:** a footprint polygon, its kit family, storeys and height,
  whether its azotea is walkable, whether it opens inside.
- **Routes:** roof links (planks, parapets, arcade roofs), climbs (ladders,
  drainpipes, towers), stairs, bridges over the canal.
- **Underground spaces:** a footprint, a floor depth and a height, and the
  openings that join them to each other and to the street.
- **Landmarks and openings:** the Metro entrances, doors that open, the
  tram loop.
- **Event fields:** the history that shaped each place, as values over the
  map (section 4).

`tools/level/plan_draw.py` renders the plan as **six sheets**, PNGs with a
10 m grid, a scale bar and labels: street, roofs, underground, canal,
events, and all together. The user approves the sheets.

The same elements become the **greybox**, plain blocks the real player can
walk. Later each plot is filled with its family's pieces; the plan approved
is what gets built.

## 3. What the map holds

About 620 × 640 m, closed by the brink. The real centre's arrangement and
rough distances, every building our own. Distances below are from the
middle of the plaza, x east, y north.

### 3.1 Street level

- **The plaza:** 200 × 220 m, open in the middle, crossed by the basalt
  causeway band; a 20 m ring street carries the tram loop.
- **North:** the cathedral and Sagrario, about 110 × 120 m, leaning, an
  atrium before it. North-east of it the Templo Mayor dig, about 90 × 80 m,
  with the deco tower rising from it as its seventh shell. Two blocks of
  houses further north, Plaza de Santo Domingo (about 60 × 80 m, centred
  about 250 m north): the Inquisition palace on its south-east chamfered
  corner, the evangelistas' arcade on its west side, the church on its
  north.
- **East:** the National Palace, a 200 m frontage, 80 m deep.
- **West:** the Portal de Mercaderes, the arcade bay run (about 30 bays).
  Calle Madero, 15 m wide, leaves west from the plaza's north-west corner
  past the Palacio de Iturbide. The Monte de Piedad faces the cathedral's
  west front.
- **South:** the Portal de las Flores. Behind it the canal (the Acequia
  Real) runs east-west, about 12 m wide, its water 2 m below the street,
  with landings and three bridges; beyond it the market quarter.
- **Between:** colonial house blocks of two or three storeys out to the
  brink, where the streets end at the void; the other districts hang in
  the sky.

### 3.2 Above

Linked azoteas across the house blocks, the arcade roofs, the cathedral's
lower roofs and a tower climb, the palace's roofline, the market hall's iron
ribs.

### 3.3 Below

- **Station:** the Line 2 hall, about 60 × 30 m and 8 m down; platforms
  running east-west 14 m down; an entrance kiosk at each corner of the
  plaza.
- **Tunnels:** a service tunnel from the station to the cathedral's crypt;
  the crypt to the Templo Mayor's nested shells; the canal's lower walkway
  under the market.

### 3.4 Interiors

The pawnshop and its vault; the Inquisition's rooms; one palace courtyard;
a scribe's office under the evangelistas' arcade. Everything else is
façade.

### 3.5 Life and the skyline

Crowds and stalls to the south and west, the tram loop, Line 2 beneath. From
the void the skyline reads as the cathedral's leaning towers and the deco
tower.

## 4. The events, as fields

Four fields over the map, drawn on the events sheet, read by every kit
family when its pieces are placed, so marks come from where a piece stands,
not from hand-sprinkling:

| field | what happened | what it marks on the assets |
|---|---|---|
| **subsidence** | the lakebed swallowing its footings; worst round the cathedral and the old lake's edge | lean and settling, cracks, buttresses and shoring, doors and windows re-cut level, steps added to sunken thresholds |
| **water** | the drain failed and the canal returned; old flood lines | tide marks on walls, damp, raised thresholds, boarded or bricked ground floors near the canal |
| **seepage** | the Eclipse's future leaking in, densest round the palace's bureaucracy and the station | 1980s terminals, cabling, conduit, junction boxes and patched machinery bolted into colonial fabric |
| **use and age** | foot traffic, the market's spill, what is kept up against what is abandoned | wear, grime and repairs (feeding the vertex-paint rules) |

Each field is a set of authored shapes (centres, gradients and edges) in the
layout data, so the user can move them.

## 5. Build order

Each step ends with stills, and no family starts before the user's verdict
on the one before.

1. **The plan:** the layout data, `plan_draw.py` and its checks. Stills: the
   six sheets. Approval fixes the map.
2. **The greybox:** the approved plan as plain blocks (plots at their
   heights, ground, canal, roofs, underground volumes) walkable with the
   real player. Stills: top-down, and street- and roof-level views from
   fixed spots; the user can walk `maps/zocalo.tscn`.
3. **Kit families, one at a time.** Each: a reference card (source,
   inspirations, the event that changed it, its pieces) that the user
   approves; closed, solid pieces with atlas, under layer and vertex paint,
   walk-tested; stills on their plots in the greybox, day and night.
   1. the street and canal kit: basalt band, kerbs, tram rails, canal walls,
      landings, bridges, the plaza's ground tiles
   2. the colonial house block: tezontle and chiluca fronts of two and three
      storeys, chamfered corners, zaguán doors, azotea parapets
   3. the arcade runs completed: corners, ends and upper-storey variants of
      the lab's bay (Portal de Mercaderes, Portal de las Flores)
   4. the Line 2 station: four entrance kiosks, stairs, ticket hall,
      platforms, line-coloured tile
   5. the cathedral and Sagrario, leaning: façade, towers, nave and crypt
      sections
   6. the National Palace: façade bays and the open courtyard
   7. the Monte de Piedad and the Madero fronts (Iturbide), the pawnshop and
      its vault inside
   8. Santo Domingo: the Inquisition on its corner and its rooms, the
      evangelistas' arcade, the church front
   9. the Templo Mayor dig, its nested shells, and the deco tower
   10. the market: iron-and-glass hall, stall lanes, awnings
   11. dressing: lamps in three dressings, the tram and novel transport,
       broadside and plaque surfaces for the user to paint, the crowds'
       props

The first implementation plan covers steps 1 and 2 only. Each family
afterwards gets its own short plan, after the user's word on the greybox.

## 6. Checks and gates

- **The plan** (a Python suite added to `level.sh test`): no plot overlaps
  another or sits in a street, canal or the plaza; every plot faces a
  street, the plaza or the canal; each layer's routes form one connected
  graph and touch the street; every underground space is reachable from the
  street; the map lies within 500-700 m a side and the brink closes it; the
  event fields cover the map.
- **The greybox:** the map-wide overlap scan (`tools/level/overlap.py`) as a
  hard gate; the real player walking a fixed route through street, roofs,
  underground and canal, where sticking or falling fails; a frame-rate check
  on a fixed camera route (`--fps-report`).
- **Every family:** closed, solid geometry, walk-tested; the geometry gate;
  no shared texels; daylight close-ups of every joint; stills on its plots,
  day and night, for the user's verdict. Passing tests are never called
  done before the user has seen it.
- **The user's words and art:** broadside, plaque and glyph surfaces get
  canvases and templates; Claude writes no in-game text.

## 7. Out of scope

Roma and Lomas; the Metro ride itself and the brink's drifting districts
(the frame spec's sub-project 0, steps 3-4); NPC populations and missions
(the crowds' props are dressing only); signature textures the user sources
or paints (tezontle, Talavera, rótulos): Claude asks for them as each family
needs them.
