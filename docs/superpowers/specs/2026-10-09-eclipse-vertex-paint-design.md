# Eclipse city: vertex paint, macro variation and hex-tiling (design)

Date: 2026-10-09. Branch: eclipse-city. Sub-project of the style lab
(docs/superpowers/specs/2026-10-09-eclipse-city-frame-design.md, section 7).

## 1. Why

The user, playing the style lab after smooth filtering (7c484d4): "the
textures are too uniform everywhere ... it's the same repeated ... it looks
massively repetitive for the ground and just in general", then: "Could you
do vertex painting to add detailing and variation?"

What was measured before designing:

- The ground is one 1.5 m tile (the cobblestone scan, recoloured, 256 px)
  repeated about 930 times over 70 x 30 m; the grid shows in the long view.
- Every wall atlas projects a 1-2 m CC0 scan by world position, wrapped, so
  each surface repeats every 1-2 m apart from wear, AO and the story mask.
- The brush tile repeats every 1.2 m on every surface.
- The three arcade bays are one piece with one atlas: identical copies.
- Nothing varies between 3 m and 30 m: no grime toward the ground, no damp,
  no fade, no stains. Every surface has detail at one scale only.
- The kit glbs carry no vertex colours (POSITION, NORMAL, TANGENT,
  TEXCOORD_0 only) and are coarse: the arcade bay is 820 triangles, mostly
  large wall quads, so a vertex colour would have nowhere to change.

## 2. What the user chose

- Vertex paint baked from **rules first; the user touches up** in Blender,
  and the user's strokes win.
- Four stories, one per channel: **grime and soot**, **material blend**
  (PS2-style: plaster wearing through to what is under it), **tint and
  fade**, **baked light** (PS2 prelighting).
- **Approach A, layered:** vertex paint + an under atlas for material
  blends + a world-space macro layer (so copies differ) + hex-tiling for the
  textures that really tile (ground, brush).
- Motion: **the user plays the lab**; live toggles, no recorded clips.
  Animated environment art (flicker, smoke, cloth) is not in this spec.

Unchanged: the look is shader-led variant D (warm painted ramp, painted
ambient and rim, lamp pools), smooth PS2 filtering, 480-line grid. No
brush-stroke normals (the user removed them; colour only). Kit pieces stay
closed, solid, gate-clean and walk-tested.

## 3. Vertex data and the rules (tools/eclipse/weather.py)

A new module, run by `common.export_piece` after a piece is built and
before it is exported.

### 3.1 Densify

- Every face is cut by a world-aligned 0.5 m grid (planar cuts: the shape
  and silhouette do not change; UVs are interpolated, the atlas and its
  islands are untouched).
- Extra cuts on **story lines**, declared by the piece's builder:
  wall feet (0.3 m and 1.2 m above the piece's ground), just under each
  sill, ledge and cornice, and round each opening.
- The geometry gate's triangle budget rises from 2500 to **5000** per piece.
  All other gate rules (3 cm layers, coplanar overlap, slivers, UV range,
  atlas clashes) apply to the densified mesh. Sliver rule: no cut may leave
  a face thinner than 2 cm; story-line cuts within 2 cm of a grid line snap
  to it.

### 3.2 The rules (a colour attribute `rules`, RGBA, 0-1)

- **R, grime and soot.**
  - Rising damp and street dirt: 1 at the piece's ground falling to 0 by
    about 1.2 m, its top edge ragged (a seeded 1D noise along the wall).
  - Corners and inside edges: from the cavity measure the texel bake
    already computes, sampled at the vertex.
  - Soot: a plume over each opening and each lamp anchor (an empty named
    `soot_*` in the builder), widening upward, about 1.5 m tall.
- **G, material blend** (how far the top material has worn through):
  plaster at wall feet and round openings; the outer edges of steps and
  kerbs; the green paint on the `iron` slot's outer edges. Only on slots
  whose recipe names an `under` material; 0 elsewhere.
- **B, tint, 0.5 neutral.**
  - Below 0.5, damp: rain streaks hanging under each overhang (sill,
    cornice, balcony, canopy edge), vertical runs of seeded length below it.
  - Above 0.5, bleached: faces that look up, and faces turned to the sun's
    side (the lab's sun direction, a constant in weather.py).
- **A, baked light.** Ray-cast ambient occlusion from each vertex against
  the whole piece (24 rays, cosine-weighted, 3 m reach), with a little warm
  bounce added on faces that look down. 1 is fully open.

The rules are deterministic (seeded per piece name).

### 3.3 Export

The merged colours (section 6) go out as glTF `COLOR_0` (the exporter's
active-colour option). Godot imports them as the mesh's vertex colour; a
test pins whether Godot treats them as sRGB or linear (section 8).

## 4. The under atlas (tools/textures/eclipse_atlas.py)

- A slot's recipe (tools/textures/recipes/eclipse/<slot>.json) may name an
  `under` material: either another recipe's name (`"under": "tezontle"`) or
  an inline block with the same fields as a recipe (scan, tint, contrast,
  relief, bands, band).
- The painter paints, from the same texel bake, `<piece>_under.png` and
  `<piece>_under_normal.png` beside `<piece>_base.png` and
  `<piece>_normal_base.png`. Same size (768 px for the lab pieces).
- A slot without `under` is copied texel for texel from its top layer.

Under materials for the lab:

| slot (pieces) | top today | under | status |
|---|---|---|---|
| `lime` plaster (arcade_bay) | white_rough_plaster | the `tezontle` recipe | **stand-in**: the tezontle recipe is itself japanese_stone_wall pushed toward red, until the user paints or sources real tezontle |
| `iron` green-painted steel (kiosk, arcade_bay) | green_metal_rust | bare metal: metal_plate_02, inline | final |
| `stone_step` (kiosk) | terrazzo_tiles | the same scan, lighter and fresher (worn step edges), inline | final |
| ground cobbles (Ground.gd) | cobblestone_floor_04 | packed earth: one more CC0 Poly Haven dirt scan added to fetch_scans.py (gitignored, credited in CREDITS.md) | final |

Every other slot (`tezontle`, `chiluca`, `steel`, `brass`, `wood_door`,
`tile_floor`, `tile_line2`, `glass`, `sign`) has no under layer in this
sub-project; the rules leave G at 0 on them.

The stand-in is named as unfinished in the stills' captions and the
ledger, never called done.

## 5. The shader (scripts/Visual/painterly.gdshaderinc)

### 5.1 Order in the fragment, before the palette match

1. **Blend (G).** `edge = smoothstep(t - w, t + w, G + (brush - 0.5) * k)`:
   a crisp, ragged edge, not a vertex smear. Albedo mixes top to under by
   `edge`; a thin darker band follows the edge (the plaster's broken lip,
   colour only); the normal map switches from the top's to the under's by
   `edge`.
2. **Tint (B), in Oklab.** Below 0.5: lower lightness, a little cooler and
   richer. Above 0.5: higher lightness, greyer. Broken by the brush so runs
   read as painted streaks.
3. **Grime (R).** Mix toward a warm dark grime colour taken from the
   district palette, broken by the brush.
4. **Macro** (section 6.2), then the palette match and strokes as now.

### 5.2 In the light

**Baked light (A)** multiplies the painted light's input,
lambert x attenuation x A, so occluded corners and soffits take the ramp's
shadow colour; it also scales the painted ambient. It never brightens.

### 5.3 Uniforms

`vertex_paint` (0-1; 0 gives exactly today's image), `blend_edge`,
`blend_break`, `tint_amount`, `grime_amount`, `grime_colour`,
`baked_light_amount`, `macro_amount`, `macro_scales`, `hex_tiling` (0/1).
Defaults are set in Painterly.gd's presets and tuned in A/B/C still rounds
(tests/style_lab_stills.gd --variant), the user judging.

## 6. The ground, the macro layer, hex-tiling

### 6.1 Hex-tiling

After Mikkelsen, "Practical Real-Time Hex-Tiling" (JCGT 2022): the plane is
cut into a hexagonal grid; each hex samples the tile at its own random
offset (and rotation, where allowed); three samples blend with a
contrast-keeping weight. A helper `hex_sample(tex, uv, rotate)` in the
shader include, used for:

- the ground's tiled scan: offset and rotation;
- the brush tile: offset only (the strokes keep their shallow diagonal
  sweep); three axes x three samples.

### 6.2 The world macro layer

`textures/painted/eclipse/macro.png`: a 256 px seamless tile painted by
`tools/textures/painterly.py` (soft blotches at several sizes), three
channels: value, warmth, grime. The shader samples it by world position at
two incommensurate scales (about 23 m and 7.3 m; xz with height folded in,
so façades vary along their length) and shifts Oklab lightness by up to
about 6%, hue a little warm or cool, and adds to grime. Every copy of a kit
piece falls on a different part of it.

### 6.3 The ground (scripts/Visual/Ground.gd)

A reusable ground builder (the style lab uses it; district maps will):

- a 1 m grid mesh over a rectangle with rectangular openings cut out, and
  the same box colliders as now;
- the cobblestone scan prepared like the walls (scan_prep: delight and
  Kuwahara) at its true 1.5 m size, hex-tiled, through the painterly
  shader and the district palette (today it is the raw photo, recoloured).
  A new step in tools/textures/eclipse_atlas.py paints seamless ground
  tiles from a recipe (`ground_cobbles.png`, `ground_earth.png` and their
  normals, in textures/painted/eclipse/, committed: CC0-derived), the earth
  tile being the ground's under layer;
- vertex paint from rules against the footprints standing on it (passed in
  as rectangles): grime banked against wall feet, kerbs and corners; wear
  through to earth along walking lines, round the kiosk mouth and between
  doors; damp pooling in seeded patches; baked light darkened under the
  arcades (footprints flagged as roofed).

## 7. The user's touch-ups (round trip)

- Every build writes the piece's source .blend
  (`tools/eclipse/source/<piece>.blend`) with four greyscale painting
  layers, one story each, so the user never paints in false colour:
  `yours_grime`, `yours_blend`, `yours_tint` (mid grey neutral),
  `yours_light`. Each starts as a copy of what the rules baked.
- At the start of the next build the builder reads those layers back from
  the existing .blend. A vertex whose value differs from the copy it
  started as (by more than 1/255) is the user's. The user's values are
  saved to `tools/eclipse/yours/<piece>.npz` (committed), keyed by vertex
  position (1 mm) and facing.
- On every build: rules first, then the user's values over them where
  saved. Untouched vertices follow the rules, so rule changes still reach
  them. The densify grid is world-aligned and deterministic, so strokes land
  on the same vertices when other parts of the piece change.
- Strokes whose vertex no longer exists are listed in the build log, never
  dropped silently.
- `tools/eclipse/lab.sh` gains no new command; harvesting is part of the
  build. The .blend's README note (written beside it) says which layer is
  which and how to paint.

## 8. Tests (failing first)

Python (`tools/eclipse/test_weather.py`, added to level.sh `test`):

- densify keeps the shape: same total area per object, all cuts planar, no
  face edge longer than 0.5 m (story lines aside), no sliver under 2 cm;
- grime falls with height on a test wall; a rain streak hangs under a sill
  and not above it; an arch soffit's baked light is darker than an open
  wall's; bleach is higher on an up-facing face than a down-facing one;
- deterministic: two builds give the same colours;
- the user's strokes survive a rebuild; a stroke on a removed vertex is
  reported;
- the 5000-triangle budget holds for the kiosk and the arcade bay.

Painter (`test_eclipse_atlas.py`): the under atlases are written; a slot
without `under` copies its top layer exactly.

Godot:

- import: `COLOR_0` survives at known vertices of a test glb, and the test
  pins sRGB vs linear;
- pixels (`painterly_pixels.gd`): vertex_paint 0 reproduces today's image;
  G = 1 shows the under atlas with a ragged edge; R darkens; A pulls toward
  the ramp's shadow colour; on a large plane hex-tiling cuts the
  autocorrelation at the tile period well below plain tiling's; two
  identical quads at different world positions differ through the macro
  layer;
- lab (`style_lab_test.gd`): the three bays' mean colours differ; the stair
  walk (L7), passage hole scan (L8) and back-of-building (L9) still pass on
  the densified meshes; the ground's grid mesh has its openings and
  colliders;
- every existing suite stays green.

## 9. Judging

- Stills as before (day/night, front, arcade, close, grazing, stairs), plus
  a new long view across the ground, sent after each layer lands; variant
  rounds toggle each layer.
- **Live toggles in the lab** while the user walks it: F1 vertex paint,
  F2 macro layer, F4 hex-tiling (F11 stays day/night; F3, F6-F8, F10 are
  taken globally). An on-screen line names what is on.

## 10. Out of scope

Animated environment art (lamp flicker, smoke, cloth, dust), recorded
clips, new kit pieces, tezontle itself (the user's), texture density
changes, the remaining jitter/culling items (shadow shimmer, edge pops,
near clipping) from the earlier report.
