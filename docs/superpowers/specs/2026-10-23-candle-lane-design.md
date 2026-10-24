# The Candle Lane: the librarian's shop on the way to the Metro

Design, Oct 23 2026. It follows the Metro Underground design (`docs/superpowers/specs/2026-10-16-metro-underground-design.md`), its approved layout (`tools/level/layouts/metro/`), the librarian's shop (`docs/superpowers/specs/2026-10-17-librarian-shop-design.md`, Parts 1 and 2) and the corridor bay's recipe (`docs/superpowers/refs/underground/recipe.md`).

## Intent

What we have built stands in two look-dev places:
- the corridor bay (`maps/underground_lab`): the curandera's stall and its neon, the Virgin's niche, the Light Company's services, the tiled walls with the crack through to older stone, the vault plaster, the floor's clutter, the trains' breathing, the crowd, the ánimas in the drain, the nahual on the bench;
- the librarian's shop (`maps/library_lab`): Part 1's room and Part 2's strange shop, with its rugs and what hangs.

The joined look-dev map, `maps/underground_library_lab`, sets the shop off the bay's corridor, but the corridor leads nowhere. This design puts both on the real Metro map as one place, the **candle lane**, and lays out the walk from the shop's arch to the trains.

### Where it is (agreed with the user)

The shop opens off the **candle lane**: the layout's side lane east from the **Pasaje** (the market corridor at floor −11 m) to the underground **chapel**:
- `candle_lane`: `rect(-4, 72, 28, 77)`, height 3.5;
- `chapel`: `rect(28, 62, 44, 86)`.

An exorcist who deals in dangerous books belongs between the market and the chapel: near the faithful, but in a lane you have to turn into. The bay becomes this lane. The niche and the candles belong in a lane that leads to a chapel. The curandera's stall belongs at the market's edge.

The way to the trains runs out of the lane's mouth into the Pasaje, north up the market stairs (`market_stairs`) to the ticket hall (`hall`, floor −8), through the turnstiles and down to the platforms (floor −14).

### The walk (agreed with the user): pockets of loud and quiet

From his arch, outward:

1. **His arch: quiet.** The shop's hush spills a little into the lane: its book-light, the ward's candles seen through the arch.
2. **The chapel end: quiet.** The lane's far end toward the chapel: votives thick on ledges, a few kneeling figures, murmured prayer. Warm, dim, close. The chapel's doorway glows; the chapel itself is not built here.
3. **The curandera's stall: a loud pocket.** Her stall mid-lane: customers bargaining, the tamale cart's steam and call, her radio. A small burst of life with its own light.
4. **The Virgin's niche: quiet.** A step past her, the niche: a dip back to candlelight and stillness.
5. **The lane's mouth: loud.** The Pasaje opens at once: neon, the crowd's density jumping, vendors calling, the floor shaking with the trains.
6. **The market stairs: thinning.** The noise falls away as you climb; the light grows from the ticket hall above.
7. **The ticket hall: echoing, sparser** (beyond this set; seen up the stairs).

The pockets are made with light (candle pools against neon), the crowd's density and sound. Sound uses placeholders until the user's own Metro recordings arrive (the bay's sounds were judged bad, Oct 17).

## Approaches (the user chose C)

- **A. Look-dev bay first, then rebuild in the map.** Approve the lane in a bay, then place every piece again in `maps/metro`.
  - For: fast iteration, as the stall was approved.
  - Against: everything placed twice, and the bay's proportions drift from the real lane's.
- **B. Straight into the real map.** Author and dress the lane inside `maps/metro`.
  - For: real sightlines, nothing placed twice.
  - Against: the whole map is slow to test and render, and pieces are reviewed inside a big unfinished level.
- **C. A set at the map's exact measure, instanced whole.** The candle lane is built as its own scene at the lane's real size and orientation from the layout, with the shop's room behind its wall and stubs of the Pasaje and the chapel doorway at its ends. It is reviewed on its own, piece by piece, then instanced into `maps/metro` at the lane's plan position, unchanged. The shop already works this way: it is embedded and rotated in the joined map today.
  - Chosen: one build, reviewable in isolation, no second placement.
  - Cost: stubbing the two ends until the Pasaje and the chapel are built for real.

## Goals

- The candle lane set (`maps/candle_lane.tscn`), built to the layout's measure, holding:
  - the approved bay's pieces, rearranged along the lane in the walk's order;
  - the shop, embedded with everything Part 2 and the dressing added;
  - the new pieces below.
- The set instanced into `maps/metro` at the candle lane's plan position. The greybox's own geometry for that space gives way to it, and the lane's openings line up with the Pasaje and the chapel.
- The walk's pockets, read in light, crowd and placeholder sound.
- Wayfinding a Metro rider would trust: the line's colour, arrows to the trains and to the exits, the station's glyph. The words and the glyph's drawing are the user's; the set leaves blank faces for them.
- The look-dev bays keep working: `maps/underground_lab` and `maps/library_lab` stay the places pieces are judged, and their suites pass.

### New pieces

- **The lane's shell at its measure:** the bay's tiled lower walls with the crack to older stone, the vault plaster ceiling, the Light Company's services along it, the tiled floor and its clutter.
- **The shop's front on the lane:** the shopfront wall and arch (Part 1's `room_front`) set in the lane's south wall, its pilasters and blank fascia facing the lane.
- **The chapel end:**
  - votive ledges on both walls with candles and melted wax;
  - milagros pinned on a board by the chapel's doorway (echoing those on his cage);
  - a few kneeling figures (placeholders under the no-figures rule, below);
  - the doorway itself, lit warm from inside.
- **The lane's mouth:** a stub of the Pasaje, a few metres either way.
  - its first puestos, their neon (shapes and colours ours, words the user's) and the crowd;
  - the foot of the market stairs, in view up the Pasaje, lit from the hall.
- **Wayfinding:**
  - an enamel sign at the mouth, its words blank;
  - the line's colour band along the lane;
  - arrows toward the trains and the exits.

## Non-goals

- Building the Pasaje beyond its stub, the market, the chapel's interior, the ticket hall or the platforms.
- The final sounds (the user's recordings).
- Dialogue, quests, the librarian himself, commerce.
- Changing any approved look: the stall, the shop, Part 2's families, the rugs, the hangings.

## Anti-goals

- Uniform scatter: dressing in staged scenes with a cause, never "a cart every 6 m".
- Magic sprinkled without a cause in the world's events.
- Visible geometry faults: z-fighting, layered faces, holes, clipping. Each is fixed with a test, or named as unfinished with its task.
- Modelled human figures that look bad. Kneeling figures and the crowd stay as the bay's approved crowd, as silhouettes or as placeholders until a well-made figure is approved.
- A dead end: the lane must read as on the way somewhere, at both ends.

## Constraints

- **The layout is the authority for position.** The set's frame is the candle lane's plan rectangle and floor. The set may widen the lane's section (below), but only through the layout file, with the plan checks (`plan_check.UNDERGROUND_RULES`) passing.
- **Passages for the player's metre-wide capsule:** 1.1 m at least, clear to 2.1 m. The walk from the map's spawn to the shop's desk, the chapel's doorway and up the market stairs is tested from the spawn, never by teleporting into the space.
- **Performance:**
  - The shop keeps its 1.1× budget against the underground bay, measured as now: headless L20, and the windowed render check.
  - The set gets the same comparison against the bay. Effects off-screen do nothing a frame.
- **Rules carried over:**
  - our own VFX only;
  - CC0 or Apache assets, credited in `CREDITS.md`;
  - the user writes all words and paints the signature art;
  - the user reviews each new piece with stills (and a clip where it moves) before the next;
  - nothing merged or pushed without the user's OK.
- **The VFX session's uncommitted files** (`scripts/Level/Vfx.gd`, `scripts/Visual/Fumes.gd`, `tests/ambient_test.gd`, `tests/underground_lab_test.gd`) are not committed by this work.

## Decided by the user (after the builder check)

- **The lane widens to the bay's section: 6.9 m wide by 4.0 m tall** (the layout had 5 m by 3.5 m), so the stall, its sign and the services keep their approved proportions. The layout's `candle_lane` becomes `rect(-4, 72, 28, 78.9)` with height 4.0; nothing else stands there, and the plan checks must still pass.
- **People are flat black silhouettes** (Mignola's black as shape): cut-outs standing in the lane, made the way the librarian's shadow was (`tools/textures/librarian_shadow.py`: Quaternius's CC0 base body posed, dressed in shapes round its bones, rendered black). Poses for this set: customers at the stall (bargaining, waiting), kneelers at the chapel end, the crowd thickening at the mouth. Each pose is reviewed by the user before it goes in. The bay's sound-only crowd stays as their sound.

- **The chapel's doorway is open: a way through.** In the plan the chapel continues by `lane_se` to `corridor_se` and the south-east kiosk's exit stairs, so the quiet end is also a way out, riders crossing the chapel as Mexico City's churches are crossed. The set's east end lines up with the chapel's plan space (greybox until it is built) and is walk-tested through it. The lane's wayfinding points both ways: to the trains and the north exits by the Pasaje and the market stairs, and to the south-east exit through the chapel.


## Calls made (Claude's, for the user to check)

- **The Pasaje stub is the set's own, for judging it alone.** In `maps/candle_lane.tscn` the stub runs a few metres either way from the lane's mouth and ends in a lit backdrop. The market stairs' foot is 40 m up the Pasaje (plan z 34 against the mouth's 74.5), too far to build for a stub. Instanced in `maps/metro`, the stub is hidden and the map's own Pasaje meets the lane's mouth. The registry skips only the greybox meshes of `candle_lane` (and of the shop's room, a new plan space), never the Pasaje's.
- **Performance is measured and reported against the bay.** The shop keeps its 1.1× budget. The set's whole cost is measured windowed against the bay and reported; agreeing a budget for it is the user's, once there is a number.
- **Sound: silent, marked emitters.** Where each pocket's sounds will go is marked, and silent until the user's recordings arrive, so the review clips never replay the bay's rejected sounds.
- **The shop's room sits behind the lane's south wall near the chapel end,** its shopfront arch centred around x = 19 in plan. The shop's room needs 8 m along the lane and 6 m back, plus walls. The chapel end's quiet and his arch's quiet then run together, and the stall stands west of him toward the market.
- **Down the lane from the chapel to the Pasaje:**
  1. the chapel's doorway (x 28);
  2. votive ledges (x 22–28);
  3. his arch (x 15–23);
  4. the curandera's stall and the tamale cart (x 7–13);
  5. the Virgin's niche and its bench (x 1–4);
  6. the lane's mouth on the Pasaje (x −4).
- **The bay's supernatural picks come with it:**
  - the ánimas in the drain (a grate in the lane's floor);
  - the nahual on the bench by the niche;
  - the trains' breathing (the market's draught from the platforms).
  - The procession of shades and the dark train belong to the platforms and stay in the bay.
- **Instancing:** `maps/metro` gets a small registry of hand-built sets, `{space name: scene}`. Each set is placed at its space's plan origin, and the greybox skips the meshes of the spaces a set replaces. The plan, its routes and the map's labels stay as they are.

## Left to the builder

- How the bay's builders are shared by the bay and the set: shared components rather than copies, keeping the bay's suite passing.
- Exact positions within the order above, light energies, crowd counts, the stub lengths.
- The test list beyond the constraints, and the stills and clips for each piece's review.

## Implementation status (Oct 24 2026, branch metro-standard, not pushed)

Built by `docs/superpowers/plans/2026-10-23-candle-lane.md`, Tasks 1–10, with the user's revisions along the way.

- **The set** (`maps/candle_lane.tscn`): the bay at 33.6 m (plan x −4 to 29.6), the shop in its south wall at plan x 19, its own pieces (`tools/eclipse/candle_lane.py`):
  - the chapel's doorway frame;
  - votive ledges and floor masses of candles;
  - the milagros board, marigolds, papel picado;
  - the pipes' works (gas meter, gauge, the air line's hoods);
  - the culvert;
  - the mouth's portal;
  - the station's sign and the arrows, their faces blank.
- **What lives in it:**
  - the ánimas from the drain and three vents, each its own kind and size, never crowding into one;
  - the nahual travelling between four haunts, its eyes in the culvert while it is away;
  - wisps of the ánimas' warmth drawn into the flames.
- **Its people are gentle black shades** (`tools/textures/silhouettes.py`, `Silhouette.gd`, `ShadeCrowd.gd`):
  - the pair at her stall moving;
  - two kneeling toward the chapel;
  - a crowd that forms out of its mist and comes apart, thick across the Pasaje beyond the mouth and rare at the chapel, with a surge after the dark train.
- **The pockets** are made with light: candles at the chapel and the niche, his book-light at the arch, her magenta neon, the Pasaje's teal at the mouth. Every pocket's sound is marked by silent emitters, and the bay's rejected sounds are hushed in the lane.
- **In the Metro:** `maps/metro.gd` sets it in at its plan origin (registry `SETS`; the greybox skips `candle_lane` and `librarian_shop`). Walked from the Pasaje to the shop's desk and through the chapel into `lane_se`; the floors are level across both seams.
- **Numbers.** Windowed at 1600×900, the set draws in 8.42 ms against the bay's 8.32 (1.01×), and the shop's 1.1× check passes.
- **Suites:**
  - the candle lane C1–C22 with L1–L3, N1–N2 and W1 (28);
  - the Metro M1–M9;
  - ánimas A1–A5;
  - the kit's CandleLane tests;
  - silhouettes (5);
  - bay layout B1–B2;
  - library 23 / 91 / 15;
  - Underground 63.
- **Approved by the user:**
  - the kit and ends;
  - the crowded, haunted revision;
  - the seven poses;
  - the gentler shades;
  - the walk with its crowd.
- **Waiting on the user:**
  - the words and glyphs for the station's sign, the arrows, the puestos' boards and the gauges' dials (all blank `sign` faces);
  - the Metro recordings for every pocket's emitters (named by sound: `sound_murmured_prayer`, `sound_bargaining`, `sound_pasaje_crowd`, …);
  - the chapel itself (greybox beyond the doorway).
- **Open:**
  - another session's ánimas voices (uncommitted in this checkout) would be silenced in the lane by its hush;
  - the hush should let them through once they are in.
