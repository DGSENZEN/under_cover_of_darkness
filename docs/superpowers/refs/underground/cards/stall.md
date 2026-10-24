# Card: the corridor stall (the Underground's hero piece)

**Status:** option A (the curandera) chosen Oct 16 2026; the stall approved Oct 17 2026 (its rules: `../recipe.md`). Still the user's: the neon's words and colour, the saint's and the photograph's prints, the enamel sign's face.

This is the first model built to the new standard (`docs/superpowers/specs/2026-10-16-metro-underground-design.md`, section 4). What it teaches becomes the recipe for every piece after it.

## Source: what it should look like

- **CDMX Metro puestos:** stalls packed so tight along the pasillos that they swallow the corridor and even an entrance (Hospital General on the reference board). They are thin steel frames, tarps, hand-lettered signs, and goods stacked to the ceiling.
- **Hellboy II's Troll Market:** a stall carved into old stone, lit by lanterns, heavy with clutter, every surface used.
- **Deadlock's Broadway:** chunky, slightly exaggerated forms, big soft bevels and painted light, with neon as the loudest colour in the frame.
- **Mignola:** a readable silhouette with black drawn as shape in the deepest recesses (under the counter lip, behind the shelves).

## Change: what the world did to it

- **The frame is the Light Company's steel**, offcuts of conduit and rail. Rented pitches in the pasillos are Company ground, and brass patch plates are bolted over the joints.
- **The awning is old Company canvas,** re-dyed and stitched, sagging between its rails, with a scalloped hem.
- **The neon is rented from the Company,** which holds the trade in light. It draws power with a cable tied to the corridor's brass conduit pipe, and this is the cause of its buzz and flicker.
- **The folklore corner is the vendor's own:**
  - **Option A:** a small ofrenda niche bolted to the post, with a saint, marigolds and a candle.
  - **Option B:** a brass-framed saint over the shelf with marigolds at its foot.

## The two options (blockouts: `stall/a_curandera_*.png`, `stall/b_tortas_*.png`)

| | A: the curandera | B: tortas |
|---|---|---|
| Sells | herbs, candles, copal, jars of remedies | tortas off a griddle |
| Front | herb bundles hanging from a rail along the hem | a glass case of bread and a griddle on a steel top |
| Back | three shelves of candles and jars | two shelves of tins, and a charcoal brazier |
| Folklore | an ofrenda niche, a censer of copal smoking on the counter | a saint's corner, smoke from the brazier |
| Ties to | the Copal school (the demo program's magic) | street life, the Zócalo's tamale carts |

## Pieces (Blender object names)

| Object | What it is |
|---|---|
| `stall_frame` | The steel posts and rails, the patch plates and the sign brackets |
| `stall_counter` | The counter's body and top |
| `stall_awning` | The canvas and its hem |
| `stall_shelves` | The back shelving |
| `stall_clutter` | The goods: candles, jars, herbs (A); bread, tins (B) |
| `stall_ofrenda` | The folklore corner |
| `stall_neon` | The sign's tubes (slot `neon`, atlas-free); the box they sit on is part of `stall_frame` |

## Dimensions (metres)

- **Footprint:** 2.4 wide × 1.4 deep. The frame top is at 2.25 and the sign's top at about 2.85. The counter is 0.95 high.
- **Origin:** the front centre, on the floor; the front faces -Y.
- **Budget:** at most 20,000 triangles to start; the look-dev sets the real figure.
- **Bevels:** `common.bevel`, in 2 segments, at least 1.8 cm wide (the sliver gate). On the frame and counter 4-6 cm, so the forms read as chunky.

## Slots

| Slot | Material | Leaning toward |
|---|---|---|
| `steel` | Company steel, oxidised green-black, worn bright on the edges | `#2a3b2e`, `#3f7a52` |
| `wood` | Counter and shelves, scrubbed and dark in the grain | `#5a3a22`, `#8a5a32` |
| `cloth` | The awning canvas, re-dyed | Metro orange or cochineal red |
| `brass` | Patch plates and brackets | `#7a5a24`, `#c49a40` |
| `tin` | Tins and the censer | `#4a4e52`, `#9aa0a4` |
| `paper` | The saint's print and labels | painted by the user if it carries an image |
| `wax` | Candles | `#d8c8a0` |
| `glass` | Jars and the bread case | its own material |
| `neon` | The tubes | its own material (Neon.gd) |

## Needed from the user

1. **Option A or B**, or a change to either.
2. **The neon sign's words and colour.** The sign is the stall's name or what it sells. The user writes all words.
3. **The saint's print:** paint one, source one, or leave the frame empty for now.
