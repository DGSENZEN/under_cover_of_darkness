# The Pasaje: the market's middle stretch — design

Oct 26 2026. Build 2 of the user's three (after the candle lane's landmarks, before the south platform): the Pasaje,
the Metro's market spine. This design is **the Pasaje set and its middle stretch**. The creature cast (alebrijes,
neon moths, drain axolotls, eyes under the stalls; a cadejo, a tzitzimitl, a feathered serpent's coils, a procession
of carried lights) is the next project, with its own design; this set leaves room for it.

## Intent

The candle lane is the only finished place in a greybox Metro, so walking out of its mouth drops you into grey
blocks. The Pasaje — 10 m wide, 4.5 m high, 116 m long (plan x −14…−4, z 34…150, floor −11) — is what you see first
and last. The user's picture, as agreed: **a night market under a vault that never closes**: the Light Company's
tiled corridor swallowed by trade; puestos down both walls, each under its own neon (Deadlock's Broadway lane), a
walking street down the middle; hanging direction signs, cable bundles, sagging bulb strings, the Company's pipes;
posters and graffiti thickening further from the stairs. Folklore creeps in (the creature cast follows).

The four stretches, each with its cause (only the middle is built here):
1. North, by the market stairs (z 34–55): the arrival, the station bleeding down — cleaner tile, a newsstand, a
   shoeshine chair, a ticket tout's booth; brighter, tidier.
2. **The middle, round the herb market and the candle lane (z 55–95): the thick of the market** — food stalls
   breathing steam, herbs spilling out of the herb market's mouth, the candle / copal / milagro sellers clustered
   round the lane's mouth because her trade draws them; the crowd of shades thickest.
3. South, by the tianguis and rag lanes (z 95–140): secondhand — junk and rag sellers, a crackling radio-repair
   stall, a pawn counter; dimmer, more cluttered.
4. South end, at the small square (z 140–150): older stone breaking through the tile toward Pino Suárez.

## Goals (this design)

1. A Pasaje set scene whose middle stretch (z 55–95, 40 m) is built to the candle lane's density and standard, set
   into the Metro in its place; the stretches north and south stay greybox until their turns.
2. From the candle lane's mouth looking out, and from the stretch's own north end (z 55) looking down it, the middle
   stretch reads as a crowded, lit, living market: stalls by trade, each its own neon colour; signs overhead; steam;
   shades.
   - **The view's end (my call):** the Pasaje is a straight 116 m corridor, so the middle of any view down it is its far
     end, still greybox (with a sodium lamp over the Correspondencia sign at z 144). The stretch closes its own view: at
     its south end (z ≈ 88–95) the stallholders have hung a tarpaulin canopy and a gantry of hanging signs across the
     street, above head height, the walk clear under them, so the eye stops in the market, not in the grey beyond.
     When the south stretch is built, the canopy stays as the two stretches' join.
3. Every stall and every scene has a cause in the world (a trade, a reason to be there); no uniform spacing.
4. Room left for the creature cast: places under stalls, along awnings, at grates and puddles, and under the vault,
   where the next project's creatures will live.

## Non-goals

- The north and south stretches, the side lanes (herb market, tianguis, rag, cistern lanes) and the square — later.
- The creature cast — the next design.
- Sound (the user is sourcing recordings; emitters may be marked silent, as in the lane).
- Words, sign faces, poster lettering and glyphs — the user's.

## Anti-goals (a failure even if it works)

- A modelled human figure (*no modelled human figures*): stallkeepers and passers-by are the black shades, as in the
  lane.
- Downloaded VFX or textures (*no free VFX assets*).
- Props sprinkled at regular spacing (*scenes, not sprinkles*); every stall is a staged scene.
- A stretch that blocks the walk or the side openings (the herb market's, the lane's).
- Walking from finished art straight into grey at the lane's mouth: the set must reach at least 15 m past the mouth
  each way.
- Visual faults waved through (*never call visual defects harmless*): z-fighting, layered faces, seams with the
  greybox are fixed with a test or named unfinished.

## Constraints

- **The plan.** The Metro takes whole plan spaces from the greybox for a set (`maps/metro.gd` `SETS`). The Pasaje is
  one space today, so `tools/level/layouts/metro/market.py` splits it into `pasaje_n` (z 34–55), `pasaje` (z 55–95)
  and `pasaje_s` (z 95–150), joined across their full width; each side opening moves to the space it opens from
  (cistern lane → `pasaje_n`; herb market, candle lane → `pasaje`; tianguis, rag lane, the square → `pasaje_s`);
  the market stairs stay on `pasaje_n`. The set takes `pasaje` only. `tools/level/test_metro_plan.py` and
  `level.sh metro` keep passing.
- **Seams** with the greybox at z 55 and z 95 and at the side openings meet the candle lane's standard (no face flush
  with a greybox wall's, no part of the set standing in another space; the Metro suite's M12/M13 kind of checks).
- **The lane's crowd.** The candle lane's shade crowd already walks two routes in the Pasaje (`pasaje_north`,
  `pasaje_south`, plan x ≈ −5.6 / −6.9, z ≈ 67–84). The Pasaje set takes over the Pasaje's crowd; set into the
  Metro, the lane keeps only its routes into and out of itself, so shades are never doubled.
- **The walk.** A clear walking street down the middle at least 4 m wide end to end, the side openings clear, the
  player's capsule (1 m wide, 2 m tall) able to reach every stall's front.
- **Standard** (the Metro's): grid off; the user's brush sheets carrying the paint, painterly (*brush sheets:
  painterly, not grime*); kit pieces built right (solid closed meshes, the 3 cm layered-face gate, no shared atlas
  texels, budgets); detail a lot (*detail a lot: big city*).
- **Review.** Pieces reviewed by the user as in-game stills from the real map, one family at a time
  (*models one by one, supervised*).
- **Performance.** The Metro with the Pasaje set stays playable: from views in the stretch, the frame time measured
  windowed is no more than 1.25× the candle lane's from its own views (my call; measured with the existing
  `tests/library_render_check.gd` way of measuring).

## Approaches (picked by the user)

- **The set: its own scene, `maps/pasaje.tscn`, set into the Metro like the candle lane (picked).** Its own small
  kits; judged standalone and in the real map; its stretches grow inside it one by one. Rejected: dressing the
  greybox straight from `metro.gd` (no standalone place to judge it; tangles with the plan generator); stretching
  the candle lane's set into the Pasaje (couples two places that should change apart; the lane is finished).
- **The order: the set's middle stretch first, then the creature cast (picked).** The creatures need somewhere to
  live; the set is the stage.

## What the middle stretch holds (decided)

- **The shell**: the Company's tiled corridor at the Pasaje's section (10 × 4.5 m), from the same families as the
  lane (tile walls with the line's band, a vault or ceiling, the floor, the services along the walls), so the lane's
  mouth and the Pasaje read as one Metro; worn harder than the lane (trade has eaten it).
- **Stalls down both walls**, about 12–16 across the stretch at varied widths with gaps for alcoves, each a trade
  and a scene. The trades, by the middle's cause:
  - round the candle lane's mouth: candles, copal, milagros and saints (her trade draws them);
  - round the herb market's mouth: herbs and roots spilling out of it, dried chiles, flowers;
  - between: food — tamales (steam), tortas, atole and coffee (steam), fruit, sweets — and one or two others the
    builder picks with a cause (a lottery seller, a tinsmith, a radio stall).
  The existing pieces are reused where they fit: the curandera's hero stall's language (`tools/eclipse/stall.py`),
  the tortas stall card (`docs/superpowers/refs/underground/cards/stall/b_tortas_*.png`), the candle lane's
  `puesto`, the bay's tamale cart.
- **Each stall under its own neon**, in different colours, faces blank (the user's words); bare bulbs on wires over
  the counters.
  - **The mouth's teal (my call):** the candle lane's teal pocket at its mouth (`MOUTH_NEON`, its check C17) was always
    meant as the Pasaje's neon spilling in. It gets its cause now: the stall on the Pasaje's east wall right beside the
    lane's mouth carries a teal neon, the one exception to the stretch's other colours, and the lane's `MOUTH_NEON`
    light stays where it is as that sign's spill (the lane itself is not changed).
- **Stall notes in the plan (my call):** `tools/level/layouts/metro/places.py`'s `PUESTOS` notes for the middle
  stretch (records and gloves by the lane's mouth, charms, herbs) give way to this design's trades, which the user
  approved later (Oct 26 2026); the notes for the north and south stretches stay for their turns.
- **Stallkeepers (my call):** the lane's silhouette sheets hold customers and passers-by, not people minding stalls.
  New stallkeeper poses (behind a counter, stirring a pot, fanning coals, weighing herbs, wrapping) are made through
  the same pipeline as the lane's (Quaternius bodies, `tools/textures/silhouettes.py`), as black shades, and go to the
  user as stills for review before they are placed — the shades are the one kind of figure the user has approved.
- **Overhead**: hanging direction signs (blank faces), cable bundles slung across, sagging bulb strings, the
  Company's pipes; papel picado or other strings only where a stall's cause puts them.
- **On the walls**: posters (painted images, no lettering) and graffiti (painted marks, no letterforms), thicker
  toward the south end of the stretch.
- **Life**: the shade crowd walking the street (the lane's ShadeCrowd), posed shades minding stalls (the lane's
  Silhouette poses), steam and smoke from the food (our Fumes / Vfx), neon flicker (NeonSign), hanging signs
  swinging on the corridor's draught (`draught_now()`), drips.
- **Room for the creatures**: open space under counters, along awning tops, at floor grates and puddles, and in the
  dark above the bulb strings.

## How we know it works

- **A Pasaje suite** (`tests/pasaje_test.tscn`, headless): the set's shell at the plan's measure; the walk clear end
  to end (≥ 4 m) and walked by the player from the market stairs' greybox through the stretch into the candle lane
  and the herb market's mouth; every stall placed against a wall, clear of the openings, its trade's pieces there;
  every face meant for words blank; the crowd walking and none of it doubled with the lane's.
- **The Metro suite** (`tests/metro_test.tscn`): the set in its place, the greybox gone from `pasaje` only, its seams
  clean (no flush faces, nothing in another space), the walks still pass.
- **A view test** like the lane's mouth view (run at the project's base size, 1152×648): from the lane's mouth looking
  out and from the stretch's north end (z 55) looking south, what reads — stalls' neon colours many and distinct;
  steam present; the canopy closing the view, so the frame's middle is the market, not greybox.
- **Kit gates** for the new kits; the performance measure above.

## Left to the builder

- The exact stall count, widths, trades beyond those named, and where each stands — within the causes above, the
  4 m walk and the clear openings.
- How many kits and how they split (by family is the pattern: shell, stalls, wares, overhead).
- The neon colours (distinct from each other, from the lane's magenta and red, and from the mouth's teal).
- The shell's exact construction from the lane's families.

## Open for the user (asked in review)

- The stall trades beyond those named, once they see the first stills.
- Whether the north stretch's arrival comes next or the creatures (the agreed order is the creatures next).
