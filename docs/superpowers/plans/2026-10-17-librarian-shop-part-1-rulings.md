# Librarian shop, Part 1: rulings and deferred minors

Every decision made on the user's behalf while executing docs/superpowers/plans/2026-10-17-librarian-shop-part-1.md, in order, each with what it costs if wrong; then the final review's fixes and the minors left for later. (Copied from the plan's ledger before its workspace was removed.)

## Rulings

- T2 -> T5: T5's chain needs "a ring bolted on the desk"; T2's desk has none. Ruling: the ring is part of chained_book_chain (an anchor plate + ring on the desk top), so the desk stays as approved in T2 — cost if wrong: one small piece moved between objects.
- T2 -> T3: the stole hangs from the lamp's arm; T2's lamp must have an arm. Ruling: T2's lamp is a banker's lamp on a jointed brass arm (an arm the stole can drape over) — cost if wrong: lamp remodel in T3.
- Task 1: Ruling: the room goes into Blender +y, not -y as the plan says — glTF maps Blender +y to Godot -z, so the room still lies at Godot -z as planned — cost if wrong: none (tests check Godot positions).
- Task 1: Ruling: room_vault budget 24000 (plan 9000) — the recipe asks for modelled bricks (19k tris for ~1500 chunky 0.3x0.1 bricks); 9000 would mean painted bricks — cost if wrong: a lower-poly vault redo.
- Task 1: Ruling: common.pack(objects, margin=None) and export_piece(pack_margin=) — thousands of islands under the fractional 0.006 margin packed to 1.1 px/m; a kit may pass its own fraction (AABB shapes); every other kit packs as before — cost if wrong: none for other kits.
- Task 1: Ruling: recipes brick, boards, shopfront, rug added; brick_old -> the existing stone_old; iron not made (nothing uses it yet) — cost if wrong: one recipe later.
- Task 1: Ruling: test_kit_bpy.py runs only the classes named after `--` — the plan's per-class commands need it — cost if wrong: none.
- Task 1: Ruling: the bay's room pieces collide to their shape (trimesh, _place exact) — a convex hull of the vault fills the room — cost if wrong: none.
- Task 2: Ruling: L2's goal moved from z < -4.0 to z < -3.0 — the desk now stands at the back of the middle (the plan's own layout); the walk to the back is L14's — cost if wrong: none.
- Task 2: Ruling: the coat stand is a free-standing stand beside the desk, not a hook on the back wall — it stays right whatever depth the room is built to — cost if wrong: one piece moved.
- Task 2: Ruling: the kit test reads common.WICKS['lamp'] (the json is written from it at export); no 'glue' recipe (the pot's top is its tin); the ledger halves meet at the gutter (a lower spine failed the 3 cm gate) — cost if wrong: small.
- Task 3: Ruling: no 'salt' or 'bone' recipe made here — bone was made in Task 2, salt waits for the salt line (Task 5); the medal's face and the salt tin's label are blank for the user — cost if wrong: none.
- Task 3: Ruling: the reliquary is a monstrance (glass cylinder, bone upright inside), not a glazed box — the boxed version read as a solid brass block and its cushion broke the 3 cm gate — cost if wrong: one remodel.
- Task 4: Ruling: the rounds stand on the rack's shelf, not a peg (the test checks they rest on it); the hunt hangs 9 cm off the wall; the rack's face is green baize (bare wood read as a blank board) — cost if wrong: small.
- Task 4: Ruling: the stills tool calls RenderingServer.force_draw before each capture — with the window hidden every capture returned the first frame — cost if wrong: none.
- Task 5: Ruling: the chained book lies on its own rest bolted to the desk's left end (chained_book_rest), not on the desk top — the approved desk top had no room — cost if wrong: one piece moved.
- Task 5: Ruling: the chain swings and straightens after the cover's staple (its ends are wicks) — static, it came apart from the lifting cover; L10 checks the gap stays 0 — cost if wrong: none.
- Task 5: Ruling: the ward circle is open toward the customers and the salt closes it (the design's words); the gate treats exactly 3.0 cm as layered, so the cage's panels are 3.5 cm; links are tori built from their axes (the pipe helper's closing seam twisted tilted rings thin) — cost if wrong: small.
- Task 6: Ruling: cases stand 2.7 m (boards to 2.35), not 3.2 — the vault comes down to 3.0 m at the side walls and the 3.2 m cases and their crests went through it; a test now holds every case under the vault — cost if wrong: taller cases would need a taller room.
- Task 6: Ruling: the low case is placed twice, either side of the runner (x +-1.15), not once in the middle — the runner is the way to his desk and the first look at the corner; aisles run at x +-2.45 — cost if wrong: re-placement only.
- Task 6: Ruling: hunting stands on the back wall right of the rack (flanking the corner, 1.1 m from the desk); the room's fallen-plaster patch moves left of the cage so the case does not hide it — cost if wrong: the patch moves back.
- Task 6: Ruling: boards are written to library_shelves_boards.json in Godot's axes (not the wicks file); recipes made: lacquer_black, copper, sigil_wood, iron (clockwork_brass -> brass, bone_inlay -> bone); the shelves' atlas is 4096 (2048 gave 82 px/m) — cost if wrong: none.
- Task 7: Ruling: LIVE_HINGE is (0, 0, 0.03), at the book's mid-thickness, not (0, 0, 0) — opened about its middle the front board lands on the table level with the back and the two page blocks meet level — cost if wrong: one constant and the bay's pivot.
- Task 7: Ruling: books under 5 cm thick get no overhanging boards (lips) — a lip on a thin book lies within the gate's 3 cm of its own board face — cost if wrong: thin books read slightly plainer.
- Task 7: Ruling: BookFiller leaves reserved gaps on the boards where the live studies stand — a study among the static books must not overlap one — cost if wrong: none.
- Task 7: Ruling: every live book shares one look in Part 1; Part 2's effects tell the kinds apart — the spec gives the kinds their effects, not covers — cost if wrong: new covers per kind later.
- Task 7: Ruling: lecterns stand in the side-wall gaps at (+-3.25, 0, -3.0); the front table right of the runner by the door (x 0.75..1.6, z -0.35..-0.85) — both clear the aisles and the runner — cost if wrong: re-placement only.
- Task 7: Ruling: L17 stands the player 1.0 m off so the eye is within OPEN_NEAR; L18 hides a necromancy study behind its case's side panel — cost if wrong: none.
- Task 7: Ruling: the live book gets a leather spine in two halves (live_spine_back, live_spine_front, 12 mm) and its hinge moves to the spine's outer face (-0.012, 0, 0.03) — shut, the book showed bare page sides at its spine; opened, the halves lie side by side under the gutter — cost if wrong: two small pieces.
- Task 7: Ruling: supersedes the lectern line above — the lecterns stand either side of the runner just past the low cases (+-1.15, 0, -3.3), just outside his salt line, their desks toward the door; the side-wall gaps are where L18's watcher stands — cost if wrong: re-placement only.
- Task 7: Ruling: the front table holds two novels, scaled 0.8 (octavos beside his folios), the third lies on the right low case's top by the door — three opened side by side need 1.6 m, the table is 0.9 — cost if wrong: a bigger table.
- Task 7: Ruling: the studies lie flat on a board (1.0 or 1.45 m), spine along the board's depth, a run of 0.57 m kept clear of books for them to open into; seven: one per section, a second for necromancy and alchemy — cost if wrong: re-placement.
- Task 7: Ruling: BookFiller is an instance (`BookFiller.new().fill(spots, meshes, material, seed)`), its placements left in `layout` for the tests; a kind wider than tall lies as a stack — cost if wrong: none.
- Task 7: Ruling: L20 measured headless (CPU only) as the suites run; it exposed Task 1's floor collider, hundreds of boards hairline apart as one exact trimesh, costing the player's move_and_slide 0.36 ms a frame; the floor is now one flat box at the boards' tops (and the arch's tiles) — shop 0.36 ms vs underground 0.49 — cost if wrong: none, the boards are flush.
- Task 7: Ruling: L18 also checks the same study opens from in front at the same distance, so it cannot pass with studies that never open — cost if wrong: none.
- Final: Ruling: the stills' views re-aimed from places a body can stand (aisles, table, lecterns) and a plan view from under the vault added — the reviewer found the user approved the layout from unreachable eyes — cost if wrong: none.
- Final: Ruling: shelf books cast no shadows — their shadows were a fifth of the frame; the cases' own shadows darken their insides; Part 2 removes the work lights anyway — cost if wrong: books' self-shadowing back when the lights are fewer.
- Final: Ruling: commit 727a0a0 in the range is the VFX session's (candles and vent breath), not this plan's — it stands outside this review — cost if wrong: none.
- Final: Ruling: the VFX session's uncommitted files set aside — not this plan's — cost if wrong: none.
- Final: Ruling: the look of each piece set aside — the user approved each family from stills — cost if wrong: none.
- Final: Ruling: the Oct 18 strange-shop additions set aside — they are Part 2's — cost if wrong: none.
- Final: Ruling: no facing check for live books (one may open behind the player) — the spec asks for sight, and a book found open on turning round suits the shop — cost if wrong: a facing test in Part 2.
- Final: Ruling: mantling over the low cases not counted as a way in — the plan's walk is on foot; the passages are now walkable — cost if wrong: none.
- Final: Ruling: the gate and closedness beyond the kit tests — the kit classes ran 46/46 (shelves and books re-run 17/17 after the low case change) — cost if wrong: none.

## Final review

- Final review: fresh reviewer (opus) over 54306f0..23bae6f; verdict "with fixes": 1 Critical, 2 Important, 8 Minor.
- Final: re-grade — Minor 6 (moving book parts physics-interpolated) raised to Important: the user is sensitive to jitter and the parts move every frame; the rest stand as graded.
- Final: fixed neither aisle reachable from the door (the player's capsule is Godot's default, radius 0.5: a metre-wide body; the low cases, front table and lecterns closed both cross passages) — low cases 1.8 -> 1.4 m at z -2.0 (front passage 1.26 m, back 1.3 m); front table against the front wall right of the arch (2.9, -0.3); lecterns in the front-left corner (yaw 180) and the right wall's gap (3.7, -3.0, yaw -90); third novel at z -1.6 — L14 (now walks from SPAWN through waypoints) and L22 (new: the player's body flooded from SPAWN reaches every aisle and a standing place within reach and sight of every live book) RED->GREEN, suite 23/23.
- Final: fixed the frame-time gate measured no drawing — tests/library_render_check.tscn (windowed; this Mac's renderer reports GPU time 0, so the median windowed frame with vsync off): shop 3.79 ms vs underground 3.18 (FAIL) -> shelf books cast no shadows -> 3.26/3.25 vs 3.16/3.11 (PASS twice) RED->GREEN; not in run_suites (headless).
- Final: fixed BookFiller had no lean and no fallen books (the plan's variety rule) — leaning on the uprights at a board's start and end (5-12 deg), fallen on their side now and then — L16 (leaning >= 20, fallen >= 10) RED->GREEN (28 leaning, 20 fallen), suite 23/23.
- Final: fixed moving book parts interpolated between physics ticks — LiveBook, ChainedBook's cover and chain, Quarantine's books set PHYSICS_INTERPOLATION_MODE_OFF — L23 (new) RED->GREEN, suite 23/23.
- Final: fixed L18 stood its watcher inside the wall's collider — now (-3.46, 1.05, -3.12) in the wall's gap, where L22's flood reaches; L17 waits for its novel to shut first (the new L14 walk can leave the player beside it).

## Deferred minors

- line of sight is one ray to one point (LiveBook._in_sight); a two- or three-point test would be sturdier.
- `opened`/`closed` fire only at fully open/shut; a book turned back mid-way emits neither (Part 2 should know, or add opening/closing).
- kit constants copied by hand into the bay (CASE_LID, LOW_LID, LIVE_HINGE, LECTERN_DESK, TABLE_TOP, CORNER_AT...); write them to the kits' json or tie them by a test.
- library_corner.py CORNER_AT keeps the old y sign, working only through WALL_Y; rename or flip.
- room_back 3000->4000 and room_front 6000->9000 budget raises have no ruling (recorded now: both for the brick patch and the dressed stone arch).
- the stills tool's VIEWS doc comment is doubled.
