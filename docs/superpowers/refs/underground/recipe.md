# The Underground recipe

**Status:** drawn from the curandera's stall, approved by the user on Oct 17 2026 after three rounds of look-dev. Every piece in the Metro Underground after it is built by these rules. The spec is `docs/superpowers/specs/2026-10-16-metro-underground-design.md`, section 4.

The stall itself is in `tools/eclipse/stall.py`, and its look-dev bay is `maps/underground_lab.tscn`.

## 1. Modelling

- **A piece is a build script,** `tools/eclipse/<piece>.py`. It is the single source of truth. Any change made in Blender goes back into the script.
- **Use the stall's helpers** (lift them into a shared module when the second piece needs them):
  - `box(m, lo, hi, slot, r, turn)`: a box with every edge rounded, each box rounded on its own. Do not apply `common.bevel` over a whole object; its clamp pinches where solids touch. Use 2 segments. The radius is at most 0.4 of the thinnest side, and the flat face left between two roundings must be at least 1.2 cm. Below a 1.85 cm radius the box stays square.
  - `turned(m, profile, sides, slot, at, twist, jitter, lean, towards)`: a lathe whose ends are single polygons. It can be tipped (`lean`, `towards`) and roughened (`jitter`).
  - `pipe(m, points, r, sides, slot, closed)` for tubes and loops; `slab(m, grid, offset, slot, slot_of)` for cloth and sheets, with a slot per cell for sewn patches.
- **Chunky over fine.** The gate (`tools/eclipse/gate.py`) sets the smallest detail:
  - Every face must be at least 1 cm thick (area over longest edge).
  - Faces that face the same way must be more than 3 cm apart where they overlap. Decide this before building: plates and labels stand at least 3.5 cm proud, or are stacked bands of one lathe; stoppers and seals are each over 3 cm tall; neighbours sit a hand apart.
  - Tubes: radius at least 1.5 cm on 8 sides, 1.1 cm on 6.
  - A small lathe's end rings: radius at least 1.6 cm on 7-8 sides.
- **Shading:** smooth, with edges sharper than 50° kept hard (`SMOOTH_ANGLE`).
- **History in every piece.** Each object has a cause in the world: Company steel with brass collars at its joins, a salvaged Metro-blue board, a lost shoe replaced by a wooden block, canvas patched with a rebozo, a mended shelf, nail heads, tags, the owner's own things. No uniform spacing.
- **Sized for the game's body as well as for people.** The player is a capsule 1 m across and 2 m tall:
  - ways in at least 1.1 m wide;
  - clear to 2.1 m;
  - aisles a metre deep.

  The kit tests check that these spaces are empty, and the bay checks that the player walks through them.
- **Budget:** the hero stall is 23,172 triangles (capped at 40,000). Its 2048 atlas gives 92 px/m. A 4096 atlas is the fix if the paint reads soft.

## 2. Painting (`tools/textures/layered_atlas.py`)

The layers, in order:
1. a flat colour per material;
2. top light (`light`) and height light;
3. bright worn edges (`wear`, from 0.2 of convexity over 0.35);
4. grime in the crevices (`grime`, cavity × occlusion);
5. brush breakup (the user's sheets, world-aligned);
6. Mignola's black, `#0b0a0c`, in the deepest recesses.

The recipes are in `tools/textures/recipes/underground/<slot>.json`.

| Family | Colour | light | wear → colour | grime | brush, amount | black |
|---|---|---|---|---|---|---|
| Company steel | `#2f4a3e` | 0.6 | 0.9 → `#8fa89a` | 0.8 | brush_03, 0.16 | 0.35 |
| Wood | `#6a4428` | 0.7 | 0.7 → `#b88a5a` | 0.8 | brush_02, 0.18 | 0.4 |
| Canvas | `#8a2a2e` | 0.8 | 0.3 | 0.5 | brush_00, 0.15 | 0 |
| Brass | `#8a6a2a` | 0.6 | 1.0 → `#e8c878` | 0.7 | brush_01, 0.15 | 0.3 |
| Metro blue (salvaged) | `#2f4c7a` | 0.6 | 1.0 → wood `#6a4428` | 0.7 | brush_04, 0.16 | 0.3 |
| Enamel | `#d8d0b8` | 0.5 | 1.0 → `#22242a` (chips) | 0.6 | brush_04, 0.1 | 0.2 |
| Basalt | `#3a3634` | 0.7 | 0.8 → `#7a7470` | 0.6 | brush_04, 0.18 | 0.3 |
| Herbs, dried herbs | `#4e5e2a`, `#8a7a4a` | 0.8 | 0.4 | 0.6 | brush_02, 0.18 | 0.2 |

Other rules:
- **Brush sheets:** 02 and 03 break up large surfaces, 04 is for chipped and worn things, and 00 and 01 give quiet variation.
- **Glass** of any tint (`glass`, `glass_amber`, `glass_green`) and **neon** stay out of the atlas. Each has its own material in game.
- **Blank faces** (`sign`, the prints' `paper`) wait for the user's art.

## 3. The material in game

- **The `&"bespoke"` preset** (`scripts/Visual/Painterly.gd`): paint_mix 0, stroke 0.08, painted_light 1, ramp 0.35, ambient 0.08, rim 0.1, macro 0.25. The atlas carries the colour; the shader adds painted light.
- **Light for judging:**
  - warm work lights, `Color(1.0, 0.76, 0.5)` at 2.6;
  - a cool fill, ambient `Color(0.36, 0.44, 0.58)` at 0.28;
  - neon light at 0.35 or less, with a range of 2 m or less. More than that floods the piece in its colour.
- **Textures load as imported resources,** never as loose files.

## 4. Decals (`tools/textures/decals.py`)

- **drip:** water off a pipe or ledge, on the wall below it.
- **soot:** over a flame or smoke source.
- **grime:** worn floor where feet stand.

They are RGBA and see-through at their edges. Each one is placed where its cause is.

## 5. Effects (each a part of its piece; made in house)

| Effect | How | Rule |
|---|---|---|
| Candle flames | `m.wick(point)` on lit candles, exported to `<piece>_wicks.json`; `Vfx.system("candles")` placed on them | One flickering light for the cluster |
| Copal smoke | `Vfx` preset `censer` | Lift (gravity 0.4) above the particles' 0.2-0.4 damping or it stalls; its life ends under any cloth over it; haze pool at density 1.4 |
| Neon | `NeonSign` (seeded pattern on game time), emissive wash decal at 0.5, hum `audio/ambience/neon_hum.wav` following the flicker | Sign light at 0.35 or less |
| Sparks | `FireParticles` "spark" at a bodged electrical tap, every 5-13 s (seeded) | Only where there is a cause |
| Light shafts | A cone `FogVolume` under each lamp, density 0.6 | Thicker reads as fog in the camera's face |
| Drips | Particles off a pipe, a puddle decal, `audio/weather/drip.wav` | |
| Hanging things | `Sway` pivot in the corridor's one draught, 2.5° | Seeded |
| Creatures | `Moths` round a bulb | Each has a cause: drawn to the light |

## 6. Review checklist, every piece

1. Kit tests: parts, closed, budget, footprint, spaces clear (`tools/eclipse/test_kit_bpy.py`).
2. Gate clean; diagnostic for any fault before changing numbers.
3. Joint renders (`tools/eclipse/lab.sh joints <piece>`): no holes, seams or z-fighting.
4. Paint: the atlas checked unshaded in game (`underground_lab_stills -- --plain`), so its mapping is right.
5. Stills under the work lights and under the form light; every view looked at.
6. Bay suite green; the player walks round it and into it.
7. Show the user. Iterate until approved.
