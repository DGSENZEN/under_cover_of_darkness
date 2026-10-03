# The harbour, polished (Oct 2 2026)

The user's review of the harbour (sub-project 1 of the city on the rock):
places with no ground (you drop out of the world), the shipyard's arches
not built properly, textures missing on main, the customs house boring,
the bridge towards the lighthouse not properly built. Their answers: the
customs house rebuilt as **Lisbon Manueline**; "the bridge" is **both** the
mole to the golden tower and a built way along the spit to the fort.

## 1. Nowhere to fall out of the world

Found by a hole scan (tests/diag/diag_holes.gd: a ray down every metre
against the colliders and against what is drawn, and from 1, 4 and 7.5 m
over the built front) and pinned by city_test C16/C17.

- **The world's edge.** The ground stopped at x -260 and 300 and z 420:
  walk off the west land or the headland, or swim out, and you fell. Now
  the open sea's bed (far_sea_bed, 40 m cells, under the harbour's own
  where they meet) runs to x ±620, z 900; the west land (west_land: strata
  down to a wandering coast) to x -620; the headland on east (far_headland,
  its coast FAR_COAST a steep fall of rock) to x 607; the massing widened to
  x ±600. A wall no one sees (maps/city.gd WORLD) stands round it all at
  x ±590, z -700 and 860, from under the sea to over the castle.
- **The sea** is one water box out to the far bed; its shore survey and
  its guards' swim bake stay on the harbour's rectangle (WaterVolume
  shore_area / swim_area; the swim bake also bounded by
  filter_baking_aabb), so neither loses detail nor trips the engine's
  bake-size check. The far ground is nav_ignore (city.gd FAR_GROUND).
- **Slots**: a 2 m lane between the Terreiro and the customs house, and
  another between the Ribeira's last house and the Terreiro, had no floor
  (floored); the slip nave's basin had water and nothing under it (a bed
  at -3); the slipway ran down between floors 0.2 m thick over nothing
  (its piece now walls both its sides to the basin's bed).
- **The fort**: its bastion's prow chamfer colliders left a hole in its top
  (6.5 m deep now); its tower's loggia roof had no collider.

## 2. The shipyard's naves

Rebuilt bay by bay (kit_harbour): square piers on granite plinths with a
stepped impost; pointed arches a pier deep (1.2 m), their soffits coursed
round the curve, a voussoir ring on each face; each bay a true groin vault
(two pointed barrels meeting at sharp groins, smooth-shaded by per-corner
normals: kit_shapes polygon `normals`), springing 0.22 m up the arches'
faces so the arches stand out as bands; along the west wall, the sea wall
and the end walls, half-piers (responds) and wall arches, so no web stops
short of a wall; deep piers where they stand in the basin; a cornice on
the terrace's open east edge. Brick that follows the mesh's UVs
(brick_coursed). Pinned by test_kits: looking straight up anywhere in a
bay, in a wall bay and in a corner bay you see brick, never the terrace's
slab or the sky (this test fails on the old pieces).

## 3. The mole to the golden tower

One body of stone swept along its line (layouts/harbour/mole.py, laid as
terrain: its collider exactly what is drawn), round a 26 m bend with no
seam, each surface ending on the head's sixteen flats; riprap, mooring
rings, a granite flight up from the quay onto its root. test_mole: its top
whole underfoot round the bend to the head, its parapet unbroken, nothing
inside the head, its faces out.

## 4. The way to the fort

A stone bridge from the Ribeira quay's west end due south (four segmental
arches on cutwater piers, refuges over the cutwaters, steps up between
posts), then a causeway on the spit's crest, a dog-leg before the bastion,
into a gate in its north parapet (a portal with the rope carving). One mesh
(layouts/harbour/spit.py on harbour/sweep.py: mitred sweeps, the parapets
each one sweep from the quay to the bastion). test_spit.

## 5. The customs house

Rebuilt (kit_customs) after Lisbon's Casa dos Bicos: a front of
diamond-pointed limestone over a loggia where the king's beam weighs what
is landed (twisted columns, basket arches, a beamed ceiling); the hall's
front behind it, its door a Manueline portal (twisted colonnettes, a rope
archivolt round the king's arms) between barred windows; rope-framed
windows each under an armillary sphere, an azulejo panel of a caravel, a
loading door under a hoist (its rope climbable); a watchtower on the
corner (quoins, a balcony to the harbour, a lookout of twin arches, a tiled
pyramid and its sphere); whitewashed sides with granite quoins, plinth and
courses; a hipped canal-tile roof laid strip by strip up to its hips.
Ground floor 4 m, upper 3.5 m. Its paintings are ours (paint.py
azulejo_ship, arms_royal). The doors, office, strongbox, key and the
watchman's round follow it (markers.py).

The Terreiro's side arcades now end at the quay in walls of their own
(terreiro_end_l/_r) instead of showing a bay's slice.

## 6. Rooms lived in

The user, mid-way: the captain's chambers barren, the customs office
"needs so much more". kit_interiors (our own paintings: paint.py
sea_chart, parchment, book_spines): the carrack's great cabin a box bed
with its curtains, a sea chest at its foot, his chair at his table and his
instruments on his chart, a washstand, swords and his cloak on the
bulkhead, a globe, a hanging lantern (the hull's own cot left out); the
harbourmaster's office a writing desk on a rug (its candle the office's
light, the loot on it), his chair, a cabinet of pigeonholes full of rolled
papers, shelves of ledgers, a chart table, a sea chart on the wall, a
globe, a sideboard, candle stands, the king's arms on a red hanging over
his strongbox, a bench for those who wait; the hall a row of posts and
braces carrying a girder and beams under the upper floor, racked casks,
bolts of cloth, spice chests, olive jars, a clerk's desk, notices inside
the door, more seized goods (the watchman's round kept clear); the store
upstairs in aisles of crates, sacks, casks, cloth and kegs.

## 7. Textures on main

The 29 converted city photos lived only in the harbour worktree
(textures/ps2 is gitignored: the repo is public). Copied into the main
checkout, never committed.

## 8. The shipyard at work, and loose things

The user, mid-way: "the shipyard needs a bit more detail"; "we need to be
able to grab things". Each nave has its trade (kit_harbour yard pieces:
timber and planks, a mast on trestles, benches, oars racked, tar heating,
blocks and tackle hung from the arches, a sail spread, a new keel, a saw
trestle, a forge), shavings and soot on the floors, the tar's fire and the
forge's coals as glows. Loose things are bodies (lay.put `loose=` kg: a
"loose" marker; the exporter leaves their colliders out of the level's and
lists them; LevelLoader makes each a RigidBody3D, asleep until touched):
tools, buckets, crates, books, ledgers, candlesticks, tankards, bottles,
chairs, stools, chests: 71, all a man can carry (city_test C18).

## 9. The frame rate: roofs the moon never sees

The polish cost frames (96 to 88 fps on the bench, p99 15.8 to 20 ms): the
moon's shadow pass drew every new piece, ~80% of the draws seen from the
mole. What stands under a roof (kit_recipes.roofed: a recipe flagged
"roofed" — a room's furniture, the yard's work, the naves' vaults and the
arches between bays, the customs house's office, stair and hall frame — or
dressing inside a "roofed" box marker: the customs hall and store, the
naves) is drawn on its own layer (Layers.ROOFED), which the city's moon
leaves out of its shadow pass (shadow_caster_mask); lanterns and candles
still cast from it. city_test C19.

The start's rowboat lay in the mole's new riprap: moved out to 13 m from
the mole's line, a step from a boulder.

## 10. The city in the distance

The user: the massing must give "the sense of distance ... add more to the
harbor sector, not less"; "certain roofs in the entry are looking culled";
"more effects to the massing to give it more depth"; and the universe is
"a grounded dark fantasy mix between Thief, Elden Ring and Game of
Thrones", so *some* details must say this is not our world.

- **The culled roofs** were the massing's houses seen from the Terreiro:
  low gable prisms in tile, their ends tile too, over plain boxes.
  Rebuilt (kit_massing): walls carried up into closed gable ends, roofs of
  two slopes at a real pitch with eaves standing out, chimneys; their
  fronts a painted facade (ours: windows, shutters, a door) at true scale,
  in whitewash, ochre, salmon and blue; parish churches with belfries and
  tower houses breaking the skyline; cypresses.
- **Haze**: a depth fog from 100 m (none before: the volumetric fog
  reaches 32 m), coloured by the sky at the horizon (aerial perspective),
  thicker low; weather thickens it. Each tier of the rock paler than the
  one before it.
- **Far hills** beyond the rock, ridge behind ridge, so the castle stands
  against land and haze, not an empty sky.
- **Life**: many more lit windows, candle-warm and each its own; torches
  on the castle's walls and the Great Bridge; smoke from the old town's
  chimneys drifting with the wind; mist lying between the tiers and down
  the gorge.
- **The uncanny** (the user's choices): a red comet across the night sky;
  a colossus, a forgotten king's broken statue half sunk in the far hills;
  a cold green-white balefire on the keep, a faint pillar of light rising
  from it; corpse-lights drifting in the gorge.

How it is made:

- **Houses** (kit_massing `_house`): walls are polygons laid in metres
  along each wall and up it, so the painted fronts (paint.py `facade_*`,
  12 x 7 m: two storeys of four windows; Materials `uv_tile`, not
  world-triplanar) put their windows where the kit lights them (lit cards
  in openings: every 3 m from 1.5 m along, 1.7 m over each 3.5 m storey);
  gable ends closed in the wall's own render; two roof slabs at 25 degrees,
  eaves 0.45 m out, verges 0.25 m, timber undersides; neighbours overlap
  4 cm (no slit). Rows `mass_houses_20`, `_tall_20`, `_low_20`,
  `_mixed_20`; `mass_tower_house` (a merchant's mirante), `mass_parish`
  (a nave and its belfry). Chimney tops are sockets ("chimney"). test_kits:
  from either end between eaves and ridge a ray meets a gable; from the
  front and back, a wall; lit windows sit on the storeys' openings.
- **The far land** (city_massing `far_land`): one grid 62 m a cell from
  x -2604 to 2604, z -2706 to 1262, its lines on the near ground's edges
  (x -620/620, z -722), quads only outside them; under the near ground's
  edge 4 m sunk, at the sea's edge a 1.5 m coast with a 30 m skirt; ridges
  rising with distance to ~350 m; south of z 700 falling to the coast in
  the haze. In the massing level, so no guard's (nav_ignore with it).
- **The colossus** (`mass_colossus`, 488 tris, 249 m): at (-600, -1800),
  behind the castle and to its left from the harbour, on a levelled
  shoulder, turned 40 degrees off the harbour's line, sword arm toward it.
  Sited by a line-of-sight search over the rock's heights: 75-92% of him
  shows from the harbour's mouth, the boat, the mole and the fort.
- **The haze** (city.gd HAZE_*): depth fog 90 m to 1600 m (curve 1.6, at
  most 0.8), aerial perspective 0.5, never on the sky; Night closes it to
  30% of its reach in thick fog.
- **Distance.gd** (city.gd builds it from the massing's markers and
  sockets): `far_light` torches and the balefire (distance_glow.gdshader:
  additive quads facing the eye, never under 2.5 px, their own haze; the
  balefire's pillar distance_pillar.gdshader, 14 x 340 m; an OmniLight
  greening the keep's top), `far_air` mist (distance_mist.gdshader: cards
  turned about their upright, ragged, soft into the ground, gone near) and
  corpse-lights (glows on slow game-clock paths; stared at 1.6 s they go
  for 9 s), chimney smoke (distance_smoke.gdshader, a ribbon leaning with
  the night's wind) from 30% of the chimneys. One draw per kind, on the
  effects' layer.
- **The comet** (night_sky.gdshader `comet`, Night `comet`): a hard head in
  a small coma, a red dust tail 0.5 rad long curving and widening, a faint
  fan round it; behind clouds, gone in fog. The city's night sets it.
- **Lit windows** (lit_window.gdshader for `glass_lit`): each piece its own
  brightness and warmth, a third of them flickering like a flame.
- city_test C20 (it is all there), C21 (a corpse-light stared at goes out
  and comes back).

After the first renders (the user: "blend in a bit more into the
foreground ... more particle effects to make it look more consolidated"):
the far land rises gently by the harbour (rolling land 5-40 m, the ridges
only far out: no black wall over the headland); the haze is paler and bluer
than the night (0.17, 0.2, 0.28), so the far tiers and the colossus pale
with distance instead of sinking into black; mist lies along the foot of
each of the old town's steps and over the rows above the Ribeira (far_air
markers), and low over the harbour's water between the quays and the mole
(Distance SEA_MIST, gone within 70 m); the smoke is moonlit grey, thick
enough to be seen; the balefire's pillar is a soft glow broken into slow
streaks, not a beam.

## 11. The moon in the water

The user: the moon's reflection stops short, it glints under roofs, and
"it doesn't look natural whenever you are submerged".

- **The glade** (water_surface.gdshaderinc): the moon's column of glints
  from under it to the eye, as a lamp's column with its mirror image at
  infinity: narrow far off (glade_far), wider near (glade_near), shivered
  and broken into dashes across the swell, brighter aslant (Fresnel); the
  sharp glints in the ripples kept close by.
- **Where it can be seen** (WaterVolume.survey_moon): once the shore is
  surveyed and the moon is up, a ray toward the moon every 1.6 m over the
  survey (400 m long); the glints only where nothing stands in the way:
  none under the naves' vaults, in the cave, under the bridges' arches.
- **Under the water** (underwater.gdshader, WaterView): the surface drawn
  from below wherever a view ray meets it before the scene (it was
  discarded: everything over the water showed through, unbent): rippled;
  inside Snell's window the world above refracted and squeezed, dimmer to
  its rim, the night sky's light in it and the moon's blurred image; outside
  it the surface mirrors the dark water. The moon's shafts are soft beams,
  not a net. Specks drift in the water round the eye (our puff texture).
  The distance's effects hide while you are under (drawn after the murk).

## 12. The night sky

The user: "a bit more like Skyrim's or Halo Reach's mixed into the art
style"; chosen: a rich galaxy and the aurora (night_sky.gdshader).

- **The galaxy** (every night's, `galaxy`): violet, teal and rose gas along
  the Milky Way, a warm core north-east 28 degrees up cut by dark rifts, a
  finer field of faint stars in the band.
- **The aurora** (a map's, `aurora`; Night.aurora, the city's on): two veils
  of slow curtains low in the north over the castle, teal at their folding
  hems and violet above, rayed; behind the clouds, gone in fog.
- The comet's tail is clamped past its end (a NaN there blacked out a wedge
  of sky).

## 13. The frame rate, won back

The roofed layer only held the line (88-90 fps) once the distance came in;
the cost was draws, the shipyard's above all (hiding it alone: 2600-3300
fewer). The distance itself (its effects, the haze, the sky, the far land)
cost nothing measurable.

- **Merging** (kit_recipes.merge_groups; export.py `_merge`, MERGE_LEVELS:
  the harbour): pieces of a recipe flagged "merge" (the naves' piers,
  arches, vaults, responds, wall arches, terrace edges, end walls; floors,
  the city's walls, quays, the Terreiro's arcade bays) are joined at export,
  by sector, a 34 m cell at a time, roofed ones apart from the open: 1947 of
  the harbour's 2623 pieces into 54 meshes. Their .blend keeps them apart;
  the manifest lists each merged mesh's members ("merged") and the roofed
  ones among the roofed. Nothing finds these pieces by name (colliders,
  occluders, decals and the water's survey all work from colliders).
- Surfaces drawn: the shipyard 2392 -> 496, the Terreiro 964 -> 138, the
  Ribeira 492 -> 331.
- The bench (bench.sh): **106 fps, p99 16 ms, load 5.8 s** (before the
  polish 96 fps, p99 15.8 ms, load 13.8 s).
