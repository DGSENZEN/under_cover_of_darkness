# The Librarian's Shop, Part 2: the Living Books — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Execution approach remains for the user to select; no agents are dispatched by this document.

**Goal:** Finish the library's supernatural presentation: distinct effects from opening books, living words, floating books, section auras, and a room lit and disturbed by its contents.

**Architecture:** Keep the approved room and book geometry. A level-owned `LibraryEffects` node composes small controllers for book projections, word paths, floating books, lighting, shelf changes and the ward. Reuse the existing mesh-effect shaders and candle appearance; do not couple the library to the corridor's uncommitted vent work.

**Tech Stack:** Godot 4.5, GDScript, existing `MeshVfx`, `LiveBook`, `BookFiller`, Blender kit tools and Forward+ rendering. No new runtime dependencies.

**Spec:** `docs/superpowers/specs/2026-10-17-librarian-shop-design.md`, particularly §§2–5; Part 1 corrections in `docs/superpowers/plans/2026-10-17-librarian-shop-part-1-rulings.md`; appearance rules in `docs/superpowers/refs/underground/vfx_method.md`.

**Status:** Approved by the user Oct 19, 2026 for native execution in this chat. Tasks 1–2 are implemented and tested; Task 2's lighting family awaits visual review before Task 3. Tasks 3–10 remain pending. Changes remain uncommitted until that review. Current library: `.claude/worktrees/metro-standard/maps/library_lab.tscn`, on branch `metro-standard`.

**First family:** `docs/superpowers/refs/underground/library_stills/part2-lighting/README.md` contains the review media, verification results and implementation choices. This is the lighting and opening-state foundation, not completion of Part 2's projection/particle families.

**Revision after feedback:** The user requested more pizzazz. `docs/superpowers/refs/underground/library_stills/part2-radiance/README.md` is the current review: animated paper tracery, shaped wisps, fixed-pool mesh sparks, cage leaks and the section auras pulled forward from Task 4. Distinct section projections and the remaining Task 4 families still await implementation.

## Global Constraints

- Preserve the walkable Part 1 layout, including the front table at `(2.9, 0, -0.3)`, the two short low cases and the corrected lectern positions. Ways in at least 1.1 m, clear to 2.1 m; verify with the actual player's metre-wide capsule.
- Effects are our own meshes: hard alpha erosion, banded colour, fresnel rims, restrained quantities. No soft smoke-card clouds or downloaded VFX assets.
- Sections: chronology amber-gold; necromancy chartreuse; alchemy copper-orange/gold; metaphysics violet; hunting iron red. Novels have distinct character colours.
- The user writes all words and paints signature art. Existing title/sign/ledger slots remain available; invented script is temporary, replaceable content.
- Each new visual family is shown close up and in place, including motion, and reviewed by the user before the next family. Do not claim visual approval from automated tests.
- New human figures, lechuza and chupacabra models need separate reference/model reviews. First hunting delivery uses weapons/sigils and the approved nahual; novels use approved emblem stand-ins rather than crude bodies.
- Six to ten floating books; about twelve live books (currently twelve: seven studies, three novels, two spells). Books retain their existing proximity distances and timing.
- No librarian character, sound, commerce, dialogue, quests or placement in `maps/metro` in this project.
- Nothing merged or pushed without the user's OK. Preserve unrelated changes in `Vfx.gd`, `Fumes.gd`, `ambient_test.gd` and `underground_lab_test.gd`.

## Review Focus

1. A player leaves halfway through opening or reverses repeatedly: effects and lights track the actual opening amount and never remain orphaned. Task 1 tests this.
2. A lab is freed, recreated or viewed with a replacement camera: no retained nodes, materials or watcher references leak across scenes. Tasks 1 and 10 test this.
3. A book on a rotated shelf or sloped lectern opens: its projection starts on its pages and grows upward in the room, without intersecting the case above it. Tasks 1 and 3 test this.
4. A shelf is partly visible or visible through the arch: no rearrangement happens in sight or within a few seconds after being seen. Task 7 tests this conservatively.
5. F1/F2/F3 and cosmetic lighting interact with stealth: debug inspection restores the previous state, cosmetic glow does not illuminate the lightgem probe, and intentional book illumination is accounted for separately. Tasks 2 and 10 test this.

## Delivery order and files

Work in the existing `metro-standard` worktree. Its library is newer than the root checkout; do not copy the old root scene over it. Use native execution unless the user selects delegation.

Create runtime scripts under `scripts/Visual/Library/`: `LibraryEffects.gd` (composition), `BookProjection.gd` (one book's effect), `LibraryLight.gd` (light state), `LibraryGlyphs.gd` (replaceable script/font data), `WordChain.gd` (flow along a path), `FloatingBooks.gd` (overhead movement), `ShelfStir.gd` (unwatched edits), `LibraryWard.gd` (the chained book's reaction), and `LibraryShadow.gd` (the reviewed silhouette's routes). Only add another file where it has a distinct responsibility.

Create `tests/library_effects_test.gd` and its `.tscn`; keep Part 1 regressions in `tests/library_lab_test.gd`. Extend the existing library stills tool with named effects views and deterministic staging flags. Create `tools/eclipse/library_effects.py` and add a `LibraryEffects` kit-test class for new projection/candle geometry. Extend `tools/eclipse/lab.sh` only to register that kit.

The existing `.tscn` simply loads `library_lab.gd`; no scene-file change is required unless composition moves into the editor later.

### Task 1: Book effects that follow opening and closing

**Files:** Create `LibraryEffects.gd`, `BookProjection.gd`, the effects test scene/script; modify `maps/library_lab.gd` and the stills tool.

**Interfaces:** `LibraryEffects.build(lab: Node3D) -> void` called after the lab has built books and lights; `set_enabled(on: bool) -> void`; `set_inspection(on: bool) -> void`. `BookProjection.build(book: LiveBook, index: int) -> void`, `presence: float`, `origin_world() -> Vector3`. Controller nodes and resources belong to the lab. Keep `LiveBook.opened/closed` semantics intact.

- [ ] Add failures: every live book has exactly one controller; halfway-open reversal returns presence to zero when shut; twenty reversals do not increase node count. A replacement camera works after the old camera is freed. No camera leaves the controllers inert without errors.
- [ ] Run `bash tools/run_suites.sh tests/library_effects_test.tscn` and record the intended failures.
- [ ] Implement presence from `smoothstep(0, 1, book.open)`, with full erosion/hidden meshes at zero. Use the page-block bounds to anchor effects. Put effects on `Layers.FX`, disable shadow casting and physics interpolation for frame-driven motion; store ShaderMaterials in mesh surface slots so F2 spares them. Do not draw placeholder volumes as final effects.
- [ ] Add rotated-book and sloped-lectern assertions: anchor remains on the pages; generated effect envelope clears the board overhead. Bound study projections to the available gap, projecting outward into the aisle only above the book's reserved opening space.
- [ ] Re-run the effects and Part 1 suites. Check the baseline before blaming new code for pre-existing failures. Commit only this task's files.

### Task 2: The books light the shop

**Files:** Create `LibraryLight.gd`; modify the coordinator and lab's `_lights`, F1/F2 handling and regression tests.

**Interfaces:** `LibraryLight.build(lab: Node3D) -> void`, `set_inspection(on: bool) -> void`. Expose `section_lights: Dictionary`, `book_lights: Array[OmniLight3D]`, `cage_light: OmniLight3D` for diagnostics. Keep the corridor sodium separate from the shop's work lights.

- [ ] Add failures: two shop work lights off initially; corridor sodium and warm lamp remain on. Each of five cases and the cage has its own colour; live-book light energy is zero shut and follows presence when open. Both spellbooks receive explicit section assignments in the lab rather than an accidental empty-section fallback.
- [ ] Test F2 round trips with F1 both on and off: previous work-light state and lamp material are restored. Cosmetic projection lights exclude `Layers.GEM_PROBE`; designated shelf/book illumination remains a deliberate part of the exposure calculation and is measured at standing positions.
- [ ] Implement low, independently phased section light and cage seam glow. Start with short ranges, no new shadowed projection lights, and avoid washing out the painted shelf details. Use material copies for emission; do not mutate the shared book atlas material.
- [ ] Run both suites; capture `shop_front`, `shop_inside`, all five shelf views and `corner_cage` with F1 off. Inspect exposure, colour separation and the dark paths between pools. Present stills to the user; wait for the family review before Task 3. Commit the reviewed family.

### Task 3: Five sections, five recognizable projections

**Files:** Create `tools/eclipse/library_effects.py`; register it in `lab.sh`; extend `test_kit_bpy.py`; extend `BookProjection.gd`, the stills tool and effects suite.

**Interfaces:** Export `assets/eclipse/kit/library_effects.glb` with named parts: `chrono_hand`, `chrono_ring`, `chrono_page`, `necro_hand`, `necro_skull`, `alchemy_ouroboros`, `alchemy_flask`, `alchemy_homunculus`, `meta_ring`, `meta_eye`, `meta_plane`, `hunt_stake`, `hunt_crossbow`. `BookProjection` selects a composition by `book.section`, not by room position. Reuse approved meshes where suitable; new anatomical parts require review.

- [ ] Kit tests fail first for missing pieces, open geometry where a closed solid is required, degenerate faces and dimensions exceeding each book's projection envelope. Build the smallest visually complete family first; run the class with Blender's `--python-exit-code 1` before importing.
- [ ] Implement and review chronology: turning hands/rings, upward sand as small mesh grains, an aging/unaging page. Test grains stay bounded and recycle, and the effect shuts down on closing.
- [ ] Implement and review necromancy: articulated skeletal hand and skull, chartreuse mesh spirit-fire, faces carried in shaped eroding tendrils. Use approved anatomy or review new models; no blobs substituted for faces.
- [ ] Implement and review alchemy: rotating ouroboros, modelled flask/homunculus and gold symbols. Inspect transparent surfaces from both aisles for sorting faults.
- [ ] Implement and review metaphysics: nested sigils, an opening eye and folding planes. Folding planes have deliberate front/back treatment and depth separation.
- [ ] Implement and review hunting: the section's weapons with its sigils; include the existing approved nahual mesh as a spectre. Explicitly leave lechuza/chupacabra for their own reviewed model families.
- [ ] For each family, run the effects suite, capture a close view and an aisle view with a six-second opening/closing clip, inspect from both sides and obtain the user's verdict before starting the next family. Record which compositions are implemented; do not equate one generic ring with all five effects. Commit each reviewed family separately.

### Task 4: Novels, spells and section auras

**Files:** Extend the kit builder, `BookProjection.gd`, coordinator, effects tests and stills views.

**Interfaces:** Novel emblems chosen by stable book index, with separate colours; spells use their explicit section colour. `LibraryEffects` owns five persistent section aura roots independently of proximity-book presence.

- [ ] Add failures: the three novels show distinct emblems/colours; two spells show wards/sigils instead of novel emblems; five section auras remain attached to their cases; closing one book does not suppress another's effect.
- [ ] Implement novel stand-ins as carefully shaped hat/sword/rose emblems with dark bodies and coloured rims. Spells grow interlocking wards and thin shaped aura shells. Section auras rise in sparse tendrils from actual books rather than filling the whole room.
- [ ] Run both suites. Capture all kinds with the books open and closed, inspect F2 preservation and review novels, spells and auras as separate visual families. Commit after each review.

### Task 5: Living words, from book to bookstand

**Files:** Create `LibraryGlyphs.gd`, `WordChain.gd`, `library_glyph.gdshader`; extend coordinator, stills and effects tests.

**Interfaces:** `LibraryGlyphs.script(seed: int, count: int) -> String`, `mesh(text: String, font: Font, size: float) -> Mesh`; `WordChain.build(points: PackedVector3Array, text: String, font: Font) -> void`, `set_presence(value: float) -> void`, `set_text(text: String, font: Font) -> void`. The font/text are inputs, so readable Spanish/Latin can replace the invented script.

- [ ] Add failures: deterministic invented script, accented replacement text, spaces and missing-glyph fallback, empty text, zero-length path. Repeated text replacement keeps draw/node counts bounded and returns old resources.
- [ ] Make about forty original glyphs as font/vector outlines with SDF rendering for sharp edges; draw glyphs along arc-length-sampled curves in batches. Glyph surfaces may be planar, as the spec allows; do not use generic billboard smoke sprites. Font acquisition or generation must preserve the repository's licensing rules.
- [ ] Author book-origin streams and two inter-stand wave routes using the current table/lectern locations. Maintain readable spacing, stable path orientation, and a continuous loop without a jump at the seam. Shut books stop contributing their streams.
- [ ] Run the suite. Capture side/front/close views plus a clip following a wave to its destination. Review the glyph family and then the moving chains before committing.

### Task 6: Floating books beneath the vault

**Files:** Create `FloatingBooks.gd`; extend coordinator, stills tool and effects tests; reuse the existing live-book kit.

**Interfaces:** `FloatingBooks.build(meshes: Dictionary, look: Material, spots: Array) -> void`, `books: Array[Node3D]`, `set_enabled(on: bool) -> void`. Use a local seeded RNG and fixed-size book pool; do not add these books to proximity logic.

- [ ] Add failures: between six and ten books; all overhead travel bounds stay inside the vault and above 2.1 m; no book sweeps through another or through a shelf. At least one return/departure cycle completes with no duplicate visible shelf book at a transfer slot.
- [ ] Implement eight books on irregular, slow, separated routes with modest yaw/pitch and fanning pages. Reserve genuinely empty transfer slots instead of overlapping the filler. Returning books are hidden only after reaching their assigned shelf slot, never teleported in open view.
- [ ] Run suites and capture `shop_vault`, `shop_inside`, and an extended transfer clip. Inspect under the lowest vault sides and review the family before committing.

### Task 7: Shelves rearrange while unwatched

**Files:** Create `ShelfStir.gd`; extend `BookFiller.gd`, coordinator and tests.

**Interfaces:** Add stable `draw_index`, `instance_index` and local `transform` to each filler layout entry. `ShelfStir.build(spots: Array, layout: Array, draws: Array) -> void`, `try_stir() -> bool`, `changes: int`. Update layout bounds and the corresponding MultiMesh transform together.

- [ ] Add failures: a fully or partly visible board never changes; a board seen less than five seconds ago never changes; with no camera nothing changes. Test frustum intersection of the whole board, not only its centre. Treat uncertain visibility as visible.
- [ ] Implement scene-local 20–40 s scheduling and conservative board visibility. For occluded boards, require geometry rays for multiple points; do not treat a single blocked centre ray as enough. Make an atomic new arrangement only after validating board/upright bounds, reserved study/transfer slots, and neighbour separation.
- [ ] Chronology reorders by height; elsewhere slide a pulled book home, close a gap or straighten a lean. No invalid transformation is published. Reuse Part 1's placement assertions after every change.
- [ ] Test a visible board stays identical over 120 simulated seconds; looking away allows a change, looking back shows a valid arrangement; seeded scheduling stays within 20–40 s. Review a look-away/look-back clip and commit.

### Task 8: The chained book pushes against the ward

**Files:** Create `LibraryWard.gd`; extend kit builder for five candle stubs and coordinator, shader/tests/stills as needed. Reuse candle materials without rewriting the in-progress corridor VFX implementation.

**Interfaces:** `LibraryWard.build(chained: ChainedBook, centre: Vector3, radius: float) -> void`; `candles: Array[Node3D]`, `strength: float`. Read `ChainedBook.strain` and `staple_now()`; retain its existing animation/chain attachment.

- [ ] Add failures: exactly five stubs sit on the ward arc clear of its salt opening, desk legs and walking paths. At rest flame tilt is small; during `strain_now()` every flame leans away from the chained book; settled strain restores rest. Chain-to-staple separation remains below Part 1's 1 cm bound.
- [ ] Bind shaped flame tilt and ward flare to strain. Words crawl from the cover toward the circle, then recoil at its boundary; they never pass through the salt. Use Task 5's glyph/path implementation rather than a second text system.
- [ ] Run both suites. Capture `corner_chained`, `corner_ward`, and a repeated-strain clip with each candle and the salt opening visible. Review candles and the containment reaction before committing.

### Task 9: The librarian's ownerless shadow

**Files:** Create `LibraryShadow.gd`; add the reviewed silhouette under `textures/painted/underground/`; extend coordinator, tests and stills staging. Reuse the corridor shadow's timing/angle conventions without changing its existing routes.

**Interfaces:** `LibraryShadow.build(routes: Array[Transform3D], texture: Texture2D) -> void`, `watcher: Camera3D`, `cross_now() -> void`. Each route supplies a local wall frame and a shelf-front run. Track the current camera safely.

- [ ] Present a silhouette of the tall, wide-brimmed-hat/long-coat librarian for user review before installing it. Existing corridor artwork is a reference, not automatic approval for this character.
- [ ] Add failures: only appears in peripheral vision, disappears on direct gaze, does not project across the arch or unrelated surfaces, and survives camera replacement. Natural crossings occur every 60–120 s as the library design requests.
- [ ] Implement routes on actual shelf fronts/back-wall spans with shallow projection depth and correct orientation. F3 hides this decal with the others while preserving state on restore. Do not alter the corridor shadow's 40–90 s interval.
- [ ] Run tests; inspect a peripheral-to-direct-gaze clip. Obtain review and commit.

### Task 10: Integrated dressing, performance and handoff

**Files:** Complete coordinator wiring and regression coverage; extend `tests/library_render_check.gd`, stills and lab key help; update the design's implementation-status notes.

- [ ] Add failures for F2 material/state preservation across all new draws, F3 shadow/ward-decal state, effects disabled/re-enabled, partial initialization with missing kit assets, and repeated lab teardown/reload. Missing visuals report the resource path rather than crashing.
- [ ] Walk from SPAWN to both aisles, every live book and the desk with all effects running. Re-run Part 1 reachability and overlap tests. Check the player's view, not just detached inspection cameras.
- [ ] Run `bash tools/run_suites.sh tests/library_lab_test.tscn tests/library_effects_test.tscn`; then the relevant `ambient`, `vfx` and `underground_lab` suites after recording their existing dirty-worktree baseline. Run the Blender library-kit classes; run the full suite once for final integration and report known failures separately.
- [ ] Run the windowed `tests/library_render_check.tscn` on the same renderer/resolution as baseline. Add a comparison of effects enabled/disabled in the same library and retain the existing shop-versus-underground comparison (1.1×). Headless timing is not GPU evidence. Profile failures; agree any necessary budget change explicitly.
- [ ] Capture opening, closing, inter-stand words, overhead travel, all five sections, the cage and the ward in motion. Inspect close geometry, clipping, bloom, transparent sorting, frame-driven jitter and shader compilation errors. Keep review media in a dedicated Part 2 output directory.
- [ ] Record accepted families, deferred creature/character models, exact test results and unresolved defects. Only call Part 2 complete when each in-scope family has passed the user's review; do not merge or push.

## Oct 19 user revision: books and one continuous map

User direction after the radiance preview: effects must be part of the books; haunted books must move more as if alive; combine the Underground and library labs into one map. This explicitly replaces the earlier separate-lab scope. Execute in this chat under the existing authorization.

- Attach light tracery to actual paper materials. Align the small page filaments/glints to the physical page plane, with centimetre-scale surface bounds. Cage emission belongs to the animated paper seams, without separate floating leaks.
- Keep open leaves fluttering, covers breathing, quarantined books rocking between larger struggles, and the chained cover straining more strongly while preserving its chain attachment.
- Add `maps/underground_library_lab.tscn`: replace the Underground's eastern end wall with the library arch. Reuse the library as a translated/rotated room with one player, environment, HUD and F-key controller. Correct local/world anchors for book batches, live books, lamp and chains.
- Verify actual player traversal through the arch, not just sampled clearance; preserve both standalone scenes and their regressions. Render the continuous approach, reverse view and close motion clips.

This revision refines the current visual family. Distinct projection families and the other pending Part 2 tasks still need their own implementation and visual reviews.

## Oct 23 look polish

The user picked four faults in the Oct 19 stills: the front wall and shopfront, book light printing discs, the cage's flat glow and the camo, and the grade. All four are fixed in one pass; see `docs/superpowers/refs/underground/library_stills/polish-oct23/README.md`.

New checks: E31–E34 and J14–J16. E21 was restated, because it had pinned the flood this pass removes.

One part stays open: the painted textures' own brush mottle on the baize and the low cases' tops. That needs a recipe pass. Projection families (Task 3 onward) are still pending.

## Task 3, chronology (Oct 23, awaiting review)

`scripts/Visual/Library/Chronology.gd`, built by `BookProjection` over chronology studies. Over the opened pages:
- an astrolabe of three rings, each turning on its own axis, the outer one ticked inward with the hours;
- two clock hands on a hub;
- 36 sand grains climbing from the pages through a waist into the rings;
- a ghost leaf caught mid-turn at the gutter, ageing and growing young on a 7 s cycle while the hands run backward.

Review media: `docs/superpowers/refs/underground/library_stills/part2-chronology/`. Checks E35–E38: the family exists; it stays over the pages, under the board above and within the study's clear run; it moves; it clears on shutting.

Calls made:
- **Built in code, not a Blender kit.** The pieces are built like the ánimas' and the nahual's effects (`MeshVfx` style, v along each shape) instead of `tools/eclipse/library_effects.py`. The shared effect shader erodes and bands along each mesh's own UVs, which an exported kit's packed atlas UVs would scramble. Cost if wrong: the shapes move into a kit with authored UVs.
- **Studies only.** The section families sit over studies alone; the chronology spellbook gets its wards in Task 4.
- **Upright and fitted.** The family stands upright in the room whatever the pages' pitch, scaled to the headroom above (built for 0.33 m).

## Task 3, necromancy (Oct 23, awaiting review)

Chronology was approved by the user on Oct 23.

`scripts/Visual/Library/Necromancy.gd`, over necromancy studies, in the ánimas' Graves look (`anima_silhouette`, `anima_aura`):
- a skull hanging in a crown of chartreuse spirit-fire at the gutter, its jaw chattering in bursts, its eyes two points of fire;
- a skeletal hand reaching up out of the right-hand page, burning out of the paper at its forearm, its fingers curling and opening;
- three of the dead's faces (small skulls) carried up from the left-hand page on smoke columns, eaten away near the top and rising again.

Checks E39–E42; kit tests in `LibrarySpectres`. Review media: `docs/superpowers/refs/underground/library_stills/part2-necromancy/`.

Calls made:
- **The skull is CDmir's CC0 "human skull"** (OpenGameArt), picked by the user from two CC0 candidates. It is cut into skull and jaw by `tools/eclipse/library_spectres.py`, which writes the jaw's hinge and the eye sockets to `library_spectres.json`. It is credited in `CREDITS.md`, and its folder has a `.gdignore`, since only Blender reads the OBJ. A skull built from spheres in code first read as a black ball.
- **No CC0 hand skeleton exists**, so the hand's bones are built in code. Their lengths and joints come from the CC0 Quaternius base body's hand armature, drawn at 0.8 of life.
- **The ánima shaders gained `floor_y`** (default 0, which keeps the ánimas as they were), so a skull or a finger bone doesn't burn away at its own foot.
- **Per-frame cost trimmed.** Book projections cast their headroom ray only while their book is open, and the section auras measure theirs once. The Oct 19 effects had cost the shop's headless frame about 0.1 ms; L20 is back to 0.93×.
- **Known weakness:** the spirit-fire under the skull is faint, chartreuse against the chartreuse-lit pages.

## Task 3, alchemy (Oct 23, awaiting review)

Necromancy was approved by the user on Oct 23.

`scripts/Visual/Library/Alchemy.gd`, over alchemy studies:
- a black ouroboros outlined in copper fire, coiled a full turn, its head biting its tail, turning as it swallows itself;
- a round flask of glass hovering over the left-hand page, glowing amber water in its bulb, the homunculus curled inside, drifting, turning and breathing;
- the six old signs (sun, moon, mercury, sulphur, salt, fire) circling the serpent as they rise, flaring gold and burning out near the top.

Checks E43–E46; the homunculus's kit check is in `LibrarySpectres`. Review media: `docs/superpowers/refs/underground/library_stills/part2-alchemy/`.

Calls made:
- **The homunculus is a figure, built from Quaternius's CC0 male base body.** It is posed curled like an unborn child (`library_spectres.CURLED`, found by rendering), baked, cut to about 2,400 triangles and 5.5 cm. The female body read as an adult woman. It is drawn black with a copper rim, like the dead. It is the piece to judge hardest.
- **The serpent is black with a copper rim.** A glowing coil against the lit pages bloomed into a ring with no head.
- **The flask's glass draws both faces**, after its contents.

## Task 3, occult metaphysics (Oct 23, awaiting review)

Alchemy was approved by the user on Oct 23.

`scripts/Visual/Library/Metaphysics.gd`, over metaphysics studies, in violet:
- three nested sigils (a hexagram in its circle, a square in its circle, a triangle) at their own depths, turning against each other;
- an eye in front of them, its almond black with a violet rim, that opens slowly, looks about with its slit pupil and shuts;
- five black planes edged in violet fire over the left-hand page, folding up from a flat cross into an open box and lying flat again. Each plane has a grid of light on its front, 3 mm from the plane, and a bare back.

Checks E47–E50. Review media: `docs/superpowers/refs/underground/library_stills/part2-metaphysics/`.

Calls made:
- **Dim glowing lines.** The sigils' lines are kept dim (energy 1.25, violet core). Brighter, with the page's light, they bloomed into a white ball.
- **The eye stands in front of all the sigils**, its white a dim pearl. Further back and brighter, it was lost in the bloom.

## Task 3, monster hunting (Oct 23, awaiting review)

Metaphysics was approved by the user on Oct 23.

`scripts/Visual/Library/Hunting.gd`, over hunting studies:
- the approved nahual model (`underground_uncanny`), small, black with an iron-red burning rim and ember eyes, prowling round a binding ring of iron-red fire on the pages;
- the librarian's own rack weapons above it (crossbow, sword cane, stakes, from `library_corner`), drawn black and rimmed, circling and aimed at it;
- every 3.6 s the crossbow looses a bolt of fire, and the beast flinches, frays pale and gathers itself again.

Checks E51–E54. E35 no longer asserts that other sections lack a family, since every section now has one. Review media: `docs/superpowers/refs/underground/library_stills/part2-hunting/`.

Calls made:
- **The nahual is drawn black with a rim, not in the bench's fraying spectre shader.** At this size the spectre shader frayed through and washed pale against the lit pages.
- **The lechuza and the chupacabra wait** for their own reviewed models, as the plan says.
- **The family's kit meshes are cached on the family, not in a static variable.** A static cache left a null-material engine error at the headless renderer's exit.

With this, each section has its family: Task 3 is complete pending this review.

## Plan self-review

The tasks cover each Part 2 requirement in the existing design: projections (1/3/4), light (2), script and word waves (5), floating books (6), unseen stirring (7), containment/candles (8), shadow (9), and dressing/performance (10). Creature additions are explicitly separate reviews, as the spec permits. The plan preserves Part 1 corrections and endpoint signal semantics, accounts for the current uncommitted VFX work, and distinguishes functional tests from visual approval. New palette intensity, detailed glyph shapes and model appearance remain builder choices subject to the family reviews, not claims of existing approval.
