# The Librarian's Shop, Part 1: the Static Set — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the rare-book librarian's walk-in shop as a set, in its own look-dev bay:
- the vaulted room;
- his corner (dealer, rite, hunt, work in progress);
- the five sections' shelves;
- the books, with live books that open as the player comes near and close as they leave.

Every piece is reviewed by the user family by family.

**Architecture:**
- **Kits:** four Blender kit scripts (`library_room`, `library_corner`, `library_shelves`, `library_books`) in `tools/eclipse/`. They are built to the recipe, held to the gate and painted by the layered painter.
- **The bay:** `maps/library_lab.gd` stages the kits, fills the shelves with MultiMesh books, and places `LiveBook` nodes, which hinge their covers by proximity and line of sight.
- **Tests:** a headless bay suite and a stills tool, as the underground bay has.

Part 2 (the living books: the made-up script, word-chains, section effects, floating books, auras, creature spectres) is planned after the user approves this part's shelves and books.

**Tech Stack:**
- Blender 4 (bpy, `--factory-startup`);
- Python 3 (layered_atlas, numpy/PIL);
- Godot 4.5.1 GDScript;
- the existing `common.export_piece`, `gate.py`, `underground_shapes.py` and `Painterly.material(..., &"bespoke")`.

**Spec:** `docs/superpowers/specs/2026-10-17-librarian-shop-design.md` (parent: `docs/superpowers/specs/2026-10-16-metro-underground-design.md`; rules: `docs/superpowers/refs/underground/recipe.md`, `docs/superpowers/refs/underground/vfx_method.md`).

## Global Constraints

**Modelling and painting**
- Every piece follows `recipe.md`:
  - `box`/`turned`/`pipe`/`slab` from `underground_shapes.py`;
  - the gate: faces at least 1 cm thick; same-facing faces more than 3 cm apart where they overlap; tubes at least 1.5 cm radius on 8 sides;
  - smooth shading with 50° hard edges;
  - a cause and history in every object, and no uniform spacing.
- Player capsule rules:
  - ways in at least 1.1 m wide;
  - clear to 2.1 m;
  - aisles 1.2 m (design §5);
  - checked by kit tests and walked by the player in the bay.
- Painting: the layered painter. Its recipes are in `tools/textures/recipes/underground/<slot>.json`. The user's brush sheets are read by rank, soft (brush_amount ≤ 0.18). The raw sheets never enter the repo.
- Material in game: `Painterly.material(atlas, &"bespoke")`. Glass slots get the bay's own glass material.

**Words, art and figures**
- The user writes all words and paints all signature art. The sign board, ledger page, book titles and spines with titles stay blank slots (`sign`, `paper`) for them.
- No human figures in this part.

**Effects**
- Effects are our own meshes (no free assets, no sprite cards).
- The F2 form light skips effects: they keep their own ShaderMaterial and cast no shadow.

**Process**
- **Review gates:** each task ends by sending the user stills of every new piece, close and in place. The next task does not start until the user's verdict is in. Anything the user flags is fixed first (test first).
- Never call a visual defect harmless. Close-up stills of every joint come before claiming a task done.
- Nothing is merged or pushed without the user's OK.

## Review Focus

1. **Snagging:** the player catches on the shopfront arch, a shelf foot, the ladder or the corner's chair. Expected: they walk from the corridor to the corner's front and down both aisles without stalling.
2. **Seeing books through shelves:** a live book behind a shelf opens for someone on the other side. Expected: a book opens only for a player who can see its face (line of sight from the camera, not distance alone).
3. **Books fighting their shelves:** book bottoms sit exactly on the board tops, or books poke through uprights and each other. Expected: a 2 mm gap above each board, none inside an upright or a neighbour.
4. **Performance:** hundreds of books as separate nodes. Expected: books drawn as MultiMesh, one per book mesh per section, with the frame time at or under the underground bay's.
5. **F2 form light:** it strips live books' or lamp's materials, or leaves them grey after. Expected: F2 on and off returns every material exactly.

---

### Task 1: The bay and the room's shell

**Files:**
- Create: `tools/eclipse/library_room.py`, `maps/library_lab.gd`, `maps/library_lab.tscn`, `tests/library_lab_test.gd`, `tests/library_lab_test.tscn`, `tests/library_lab_stills.gd`, `tests/library_lab_stills.tscn`
- Create recipes: `tools/textures/recipes/underground/{boards,brick,brick_old,rug,iron}.json` (reuse `plaster_vault`, `wood`, `sign`, `tile_cream`, `tile_dark`, `grout`, `steel` where they fit)
- Modify: `tools/eclipse/lab.sh` (add `library_room` to `KITS`), `tools/eclipse/test_kit_bpy.py` (class `LibraryRoom`)

**Interfaces:**
- Produces: `library_room.py`:
  - constants (m, the room's frame: the shopfront plane z = 0, the room into −y in Blender, which is −z in Godot; the floor at 0; x across):
    - `WIDTH = 8.0`, `DEPTH = 6.0`, `SPRING = 3.0`, `CROWN = 4.5`;
    - `FRONT_W = 3.0`, `FRONT_SPRING = 2.3`, `FRONT_CROWN = 2.9`.
  - `build(width=WIDTH, depth=DEPTH, crown=CROWN)`, parametric (design §5, placement-ready);
  - pieces:
    - `room_vault` (the brick barrel vault and its side walls);
    - `room_back` (the back wall);
    - `room_front` (the shopfront wall with its arch, its sign board as a `sign` slot);
    - `room_floor` (boards over a strip of Metro tile at the threshold);
    - `room_rug` (a runner from the arch to the corner's front);
  - exports `assets/eclipse/kit/library_room.glb`.
- Produces: `maps/library_lab.gd`:
  - `extends Node3D`;
  - `var player`, `var missing: Array[String]`, `var room: Dictionary` (name → MeshInstance3D);
  - `const ROOM_KIT := "res://assets/eclipse/kit/library_room.glb"`;
  - `func set_form(on: bool)` and `func set_work_lights(on: bool)`, which behave as the underground bay's;
  - `func _kit(path) -> Dictionary`, `func _place(mesh, material, kind, at, yaw, solid) -> MeshInstance3D`, `func _painted(names) -> Texture2D` and `func _glass() -> StandardMaterial3D`, copied from the underground bay;
  - `var atlas_dir := "res://textures/painted/underground/"` (where the painter writes `<kit>_base.png`; each later task commits its kit's atlas there);
  - a 3 m strip of corridor outside the arch, built from the `underground_floor` and `underground_walls` kits;
  - the player spawns at `SPAWN := Vector3(0.0, 1.05, 2.2)`, facing −z into the shop;
  - lighting: the corner's lamp light is a placeholder `OmniLight3D` until Task 2, plus two dim work lights;
  - keys: F1 work lights, F2 form light.
- Produces: `tests/library_lab_stills.gd`:
  - the underground stills tool's options `--out= --only= --settle= --clip= --dolly=`;
  - `VIEWS` named `shop_front`, `shop_inside`, `shop_corner`, `shop_aisle_l`, `shop_aisle_r`, `shop_vault`, plus a view per piece added by each task.

- [ ] **Step 1: Write the kit tests** in `test_kit_bpy.py`, class `LibraryRoom` (pattern: `UndergroundFurniture`):
  - `test_every_piece_is_an_object`: names equal `{"room_vault", "room_back", "room_front", "room_floor", "room_rug"}`;
  - `test_every_object_is_closed`, `test_budgets` (vault 9000, back 3000, front 6000, floor 6000, rug 800), `test_each_passes_the_gate`;
  - `test_the_way_in`:
    - the arch's opening, sampled at x ∈ [−0.55, 0.55] by z-ray from 0 to 2.1 m, meets no face;
    - its width at 2.1 m is ≥ 1.1 m;
  - `test_the_vault`: the crown (max z of `room_vault`) is 4.5 ± 0.02, the side walls stand to `SPRING` ± 0.02;
  - `test_parametric`: `build(width=6.0, depth=5.0, crown=4.0)` gives a vault 6.0 ± 0.05 across, 5.0 ± 0.05 deep, crown 4.0 ± 0.02.
- [ ] **Step 2: Run them, see them fail.** Run: `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python tools/eclipse/test_kit_bpy.py -- LibraryRoom`. Expected: an ImportError for `library_room`.
- [ ] **Step 3: Write `library_room.py`.**
  - Bricks: the vault is laid in courses as stacked bands of its lathe (no layered quads). Its mortar is a recessed slot ≥ 3 cm back, as `underground_walls` does. Two courses are patched in older stone (`brick_old`), where the room was cut into the old city.
  - The arch is rounded with `turned`.
  - Floor boards run the room's depth, a few replaced in a different wood; a strip of the corridor's Metro tile shows under the threshold.
- [ ] **Step 4: Run the kit tests.** Expected: `LibraryRoom` OK; the whole file still OK.
- [ ] **Step 5: Export and paint.** Run `bash tools/eclipse/lab.sh library_room`, then `python3 tools/textures/layered_atlas.py library_room`. Expected: `assets/eclipse/kit/library_room.glb`, `textures/painted/underground/library_room_base.png`, and the gate passes.
- [ ] **Step 6: Write the bay tests** in `tests/library_lab_test.gd` (harness: the underground suite's `_check`, `_frames`, `_walk`):
  - L1, the shell: all five room pieces placed, each in the bespoke material with its atlas, and `missing` is empty.
  - L2, the way in: from `SPAWN`, walking yaw 0 (−z), the player reaches z < −4.0 with a stall under 20 frames.
  - L3, the first look: from `SPAWN`'s camera, the room's back-wall middle at (0, 1.5, −DEPTH) is in the frustum within 8° of the view's centre.
  - L4, the form light: F2 turns every room piece to the form material, and F2 off restores exactly the materials it had.
- [ ] **Step 7: Run the bay tests, see them fail.** Run: `perl -e 'alarm 600; exec @ARGV' $GODOT --headless --fixed-fps 60 --path . res://tests/library_lab_test.tscn`. Expected: L1–L4 fail, or a load error for the missing `maps/library_lab.tscn`.
- [ ] **Step 8: Write `maps/library_lab.gd` and `.tscn`** to the interface above; import (`$GODOT --headless --path . --import`).
- [ ] **Step 9: Run the bay tests.** Expected: L1–L4 PASS.
- [ ] **Step 10: Write the stills tool; shoot every view** at `--settle=4`, plus close-ups of the arch's joints and the vault's ends. Read every still; fix any visible fault (test first) before the gate.
- [ ] **Step 11: Commit.**
  ```bash
  git add tools/eclipse/library_room.py tools/eclipse/lab.sh tools/eclipse/test_kit_bpy.py tools/textures/recipes/underground maps/library_lab.* tests/library_lab_* assets/eclipse/kit/library_room.glb textures/painted/underground/library_room_base.png
  git commit -m "feat(library): the librarian's shop, its vaulted room and look-dev bay"
  ```
- [ ] **Step 12: Review gate.** Send the user the stills. Stop until their verdict.

### Task 2: The corner, the dealer

**Files:**
- Create: `tools/eclipse/library_corner.py`
- Create recipes: `{leather_old,felt_green,cotton_white,coat_black,hat_felt,glue}.json`, reusing `wood`, `brass`, `paper`, `glass`
- Modify: `lab.sh` (`library_corner`), `test_kit_bpy.py` (class `LibraryCorner`), `maps/library_lab.gd` (`_corner()`), `tests/library_lab_test.gd`, `tests/library_lab_stills.gd` (views `corner_desk`, `corner_chair`, `corner_hook`)

**Interfaces:**
- Produces: `library_corner.py`:
  - `NAME = "library_corner"`;
  - `DESK_TOP = 1.05`, the high clerk's desk facing the customers;
  - `CORNER_AT = (0.0, -(DEPTH - 1.6))` in the room's frame;
  - `build()` builds the families added in Tasks 2–5;
  - this task's pieces: `desk`, `desk_chair`, `lamp` (green shade a `glass_green` slot, its bulb point exported to `library_corner_wicks.json` under `"lamp"`, as the furniture kit's wicks are), `ledger` (open, its pages a `paper` slot for the user's words), `magnifier` (lens a `glass` slot), `gloves`, `repair_kit` (bone folder, glue pot, a spool of waxed thread), `coat_hook` (his coat and hat on it).
- Produces: in the bay:
  - `func _corner()` places the corner at `CORNER_AT`;
  - `var lamp_light: OmniLight3D` at the lamp's bulb (warm, shadowed);
  - `var corner: Dictionary` (name → MeshInstance3D).

- [ ] **Step 1: Write the kit tests**, class `LibraryCorner`:
  - every piece an object, closed, in budget (desk 6000, chair 2500, lamp 2000, ledger 1500, magnifier 800, gloves 1200, repair_kit 1500, coat_hook 5000), through the gate;
  - `test_desk_height`: the desk's writing top is `DESK_TOP` ± 0.01;
  - `test_lamp_bulb`: `library_corner_wicks.json["lamp"]` lies inside the lamp's shade bounds;
  - `test_ledger_lies_open_on_the_desk`: the ledger's lowest z is within 2–5 mm of `DESK_TOP` (no z-fight, not floating).
- [ ] **Step 2: Run them, see them fail** (ImportError).
- [ ] **Step 3: Write the dealer's pieces.** Each gets a cause:
  - the desk's front is scuffed where customers lean;
  - a brass rail runs along its top;
  - the chair is pushed back, half-turned;
  - the coat has a torn hem mended;
  - the hat is a Mignola-black felt.
- [ ] **Step 4: Run the kit tests** (OK), export (`lab.sh library_corner`) and paint (`layered_atlas.py library_corner`).
- [ ] **Step 5: Write the bay tests:**
  - L5, the corner: the dealer's eight pieces are placed and painted, and the desk stands with its front to the shopfront (its local −y toward +z).
  - L6, the lamp: a light at the lamp's bulb, warm (r > b), casting shadows, with energy > 0.5.
  - L7, the walk to the desk: from `SPAWN` the player reaches within 0.9 m of the desk's front (stall < 20) and never passes inside the desk's bounds.
- [ ] **Step 6: Run, see L5–L7 fail; write `_corner()`; run, see L1–L7 pass.**
- [ ] **Step 7: Shoot the corner views and the close-ups; read them; fix faults** (test first).
- [ ] **Step 8: Commit** (`feat(library): the librarian's corner, the dealer's desk`). **Review gate.**

### Task 3: The corner, the rite

**Files:**
- Modify: `library_corner.py`, `test_kit_bpy.py`, the bay, the bay suite, the stills tool (view `corner_rite`)
- Create recipes: `{velvet_purple,silver,bone,wax_white,salt}.json`

**Interfaces:**
- Produces these pieces: `rituale` (worn, ribbon markers standing ≥ 3.5 cm proud), `stole` (draped over the lamp's arm, a `slab`), `crucifix`, `aspergillum`, `salt_tin`, `oil_phial` (a glass slot), `reliquary` (a glass case and a bone inside), `benedict_medal` (nailed to the desk's front edge).

- [ ] **Step 1: Write the kit tests:**
  - the new pieces are objects, closed, in budget (each ≤ 2500, reliquary ≤ 4000), through the gate;
  - `test_the_rite_lies_on_the_desk`: rituale, crucifix, salt_tin, oil_phial and reliquary each sit 2–5 mm above `DESK_TOP`, within the desk's top bounds, and no two overlap in plan;
  - `test_the_stole_hangs_from_the_lamp`: the stole's top touches the lamp arm's bounds.
- [ ] **Step 2: Run them, see them fail. Write the pieces. Run them, see them pass.**
- [ ] **Step 3: Bay test:** L8, the rite: all eight placed and painted; the reliquary's glass and the phial take the bay's glass material.
- [ ] **Step 4: Run, see L8 fail; place them; run, see L1–L8 pass.**
- [ ] **Step 5: Shoot `corner_rite` and the close-ups; read them; fix faults.**
- [ ] **Step 6: Commit** (`feat(library): the corner's rite`). **Review gate.**

### Task 4: The corner, the hunt

**Files:**
- Modify: `library_corner.py`, `test_kit_bpy.py`, the bay, the bay suite, the stills tool (view `corner_hunt`)

**Interfaces:**
- Produces these pieces:
  - `hunt_rack` (on the back wall behind the desk);
  - `stakes`, `sword_cane`, `revolver` and `rounds` (a box of engraved rounds);
  - `crossbow`;
  - `bandolier` (holy-water phials, glass slots);
  - `chains`;
  - `trap_jaws` (bear-trap jaws hung like a trophy).
- Each weapon is its own object, so Part 2's monster-hunting spectres can reuse it.

- [ ] **Step 1: Write the kit tests:**
  - the new pieces are objects, closed, in budget (rack ≤ 5000, each weapon ≤ 3500), through the gate;
  - `test_the_rack_meets_the_wall`: the rack's back is within 1 mm of the back wall's plane;
  - `test_each_weapon_hangs_on_the_rack`: every weapon's bounds touch a rack peg's bounds and none overlaps another.
- [ ] **Step 2: Run, see them fail; write the pieces; run, see them pass.**
- [ ] **Step 3: Bay test:** L9, the hunt: the rack and its weapons are placed, painted, against the back wall behind the desk (between the desk and the wall in z).
- [ ] **Step 4: Run, see L9 fail; place them; run, see L1–L9 pass.**
- [ ] **Step 5: Shoot `corner_hunt` and the close-ups; read them; fix faults.**
- [ ] **Step 6: Commit** (`feat(library): the corner's hunt`). **Review gate.**

### Task 5: The corner, the work in progress

**Files:**
- Modify: `library_corner.py`, `test_kit_bpy.py`, the bay, the bay suite, the stills tool (views `corner_chained`, `corner_cage`, `corner_ward`)
- Create: `scripts/Visual/ChainedBook.gd`
- Create decals: `ward_circle` and `salt_line` in `tools/textures/decals.py` (KINDS), our own drawing. The circle's glyphs are left blank until Part 2's script.

**Interfaces:**
- Produces these pieces:
  - `chained_book`, in three parts: `chained_book_cover` (iron nails through it, separate solids ≥ 1.6 cm), `chained_book_block`, and `chained_book_chain` (links to a ring bolted on the desk);
  - `quarantine_cage` (a barred, padlocked cabinet);
  - `quarantine_books` (six to eight books inside, separate objects named `quarantine_book_<n>`).
- Produces: `class_name ChainedBook extends Node3D`:
  - `@export var cover: MeshInstance3D`, `@export var block: MeshInstance3D`;
  - `var strain := 0.0` (0–1);
  - `func strain_now()`;
  - every `STRAIN_EVERY := Vector2(14.0, 30.0)` seconds it strains: the cover lifts against its chain by up to `LIFT_DEG := 12.0` in jerks over `STRAIN_FOR := 1.6` s, then drops.
  - The words and the ward's flare come in Part 2. Here only the motion is built.
- Produces: in the bay, the quarantined books each twitch: a small rotation jolt every 6–20 s, each on its own clock, never in step.

- [ ] **Step 1: Write the kit tests:**
  - the new pieces are objects, closed, in budget, through the gate;
  - `test_the_book_is_chained_to_the_desk`: the chain's ends touch the book's cover and the desk ring's bounds;
  - `test_the_cage_holds_its_books`: every `quarantine_book_*` lies inside the cage's bounds, and none intersects a bar.
- [ ] **Step 2: Run, see them fail; write the pieces; run, see them pass.**
- [ ] **Step 3: Write the bay tests:**
  - L10, the chained book strains: after `strain_now()` the cover's hinge angle exceeds 6° within 1 s, and it is back under 0.5° within 3 s.
  - L11, the quarantine stirs: over 40 s every quarantined book twitches at least once, and no two twitch on the same frame more than twice.
  - L12, the ward: the circle and salt-line decals lie on the floor round the desk (their AABB contains the desk's plan), and F3 hides them.
- [ ] **Step 4: Run, see L10–L12 fail; write `ChainedBook.gd` and the bay's staging; run, see L1–L12 pass.**
- [ ] **Step 5: Shoot the views, and a 6 s clip (`--clip=6`) of the chained book straining; read them; fix faults.**
- [ ] **Step 6: Commit** (`feat(library): the chained book and the quarantine cage`). **Review gate.**

### Task 6: The five sections' shelves

**Files:**
- Create: `tools/eclipse/library_shelves.py`
- Create recipes: `{lacquer_black,copper,clockwork_brass,sigil_wood,iron_hooks,bone_inlay}.json`
- Modify: `lab.sh`, `test_kit_bpy.py` (class `LibraryShelves`), the bay (`_shelves()`), the bay suite, the stills tool (views `shelf_chronology`, `shelf_necromancy`, `shelf_alchemy`, `shelf_metaphysics`, `shelf_hunting`, `shelf_middle`, `shelf_ladder`)

**Interfaces:**
- Produces: `library_shelves.py`:
  - `SECTIONS = ("chronology", "necromancy", "alchemy", "metaphysics", "hunting")`;
  - one case per section, named `shelf_<section>`, 1.8 m wide and 3.2 m tall, its boards at `BOARDS = (0.12, 0.55, 1.0, 1.45, 1.9, 2.35, 2.8)`;
  - each section's shape and ornament:
    - chronology: brass and clockwork, gears in its crest, a clock face (blank `sign` slot);
    - necromancy: bone and black lacquer, a skull-and-bone frieze;
    - alchemy: copper and glass, retorts on its top, flask niches;
    - metaphysics: dark wood cut with sigils (relief ≥ 3.5 cm);
    - hunting: iron, hooks, a trophy crest.
  - `shelf_middle`, the double-sided free-standing case, 1.4 m tall so the corner shows over it;
  - `ladder` and `ladder_rail`;
  - `BOARD_SPOTS`, written to `library_shelves_wicks.json` under `"boards"`: per case, each board's (x0, x1, top_z, depth), for the book filler.
- Produces: in the bay:
  - `func _shelves()`, where each section takes a bay of the side walls (two per side) and hunting flanks the corner (design §5), and necromancy sits beside the cage;
  - `var sections: Dictionary` (section → MeshInstance3D).

- [ ] **Step 1: Write the kit tests**, class `LibraryShelves`:
  - every piece an object, closed, in budget (each case ≤ 12000, middle ≤ 9000, ladder ≤ 2500), through the gate;
  - `test_each_section_differs_in_shape`: no two section cases have outlines (their max-z profile along x, sampled every 5 cm) within 3 cm everywhere;
  - `test_boards`: `BOARD_SPOTS` matches each case's actual board tops ± 0.005;
  - `test_middle_case_is_low`: max z ≤ 1.45.
- [ ] **Step 2: Run, see them fail; write the shelves; run, see them pass; export; paint.**
- [ ] **Step 3: Write the bay tests:**
  - L13, the sections: five section cases plus the middle case and ladder placed and painted; the hunting case is within 2.5 m of the desk, and the necromancy case is within 2.0 m of the cage.
  - L14, the aisles: walking from `SPAWN` down the left aisle and the right aisle, the player reaches the back on each side (stall < 20). A capsule shape-cast 1.0 m wide along each aisle's line hits nothing.
  - L15, the corner still shows: from `SPAWN`'s camera, a ray to the desk's lamp is unblocked by the middle case.
- [ ] **Step 4: Run, see L13–L15 fail; write `_shelves()`; run, see L1–L15 pass.**
- [ ] **Step 5: Shoot each section's view and close-ups; read them; fix faults.**
- [ ] **Step 6: Commit** (`feat(library): the five sections' shelves`). **Review gate.** The user reviews all five cases, a family of five. Any case they reject is redone and re-shown before Task 7.

### Task 7: The books, and the live books

**Files:**
- Create: `tools/eclipse/library_books.py`, `scripts/Visual/LiveBook.gd`, `scripts/Visual/BookFiller.gd`
- Create recipes: `{leather_red,leather_brown,leather_green,leather_black,cloth_blue,vellum,gilt,page_edge}.json`
- Modify: `lab.sh`, `test_kit_bpy.py` (class `LibraryBooks`), the bay (`_books()`), the bay suite, the stills tool (views `books_shelf`, `books_live`, `books_table`), the clip views

**Interfaces:**
- Produces: `library_books.py`:
  - static books `book_<k>` (12 variants: folio, quarto, octavo, thick, thin, worn, clasped, ribbon-marked; spines a `sign`-like blank slot `spine` for the user's titles);
  - stacks `book_stack_<k>` (3 variants);
  - the live book in parts, its hinge on the spine's line:
    - `live_cover_front`, `live_cover_back`;
    - `live_block_left`, `live_block_right` (the page blocks each side of the gutter);
    - `live_leaf` (one page, fanned by the bay);
  - `LIVE_HINGE = (0, 0, 0)` and `LIVE_SIZE = (0.24, 0.32, 0.06)`;
  - a lectern `lectern` and a table `front_table` for novels at the shopfront.
- Produces: `class_name LiveBook extends Node3D`:
  - `enum Kind {NOVEL, STUDY, SPELL}`;
  - `@export var kind: Kind`, `@export var section: StringName`;
  - `var open := 0.0` (0 shut, 1 open), `var watcher: Camera3D`;
  - `OPEN_NEAR := 1.5`, `CLOSE_FAR := 2.2`;
  - `OPEN_TIME := 0.7` and `CLOSE_TIME := 0.9`, eased; pages fan as it opens;
  - `signal opened(book: LiveBook)` and `signal closed(book: LiveBook)`;
  - it opens only when the watcher is within `OPEN_NEAR` and a ray from the watcher to the book's face is unblocked;
  - Part 2 hangs its effects on the signals.
- Produces: `class_name BookFiller extends RefCounted`, `static func fill(spots: Array, meshes: Array[Mesh], material: Material, seed: int) -> Array[MultiMeshInstance3D]`:
  - it fills each board with books of varied mesh, height, lean (0–12°) and gaps, and a fallen or stacked book now and then;
  - it returns one MultiMeshInstance3D per book mesh.
- Produces: in the bay:
  - `var live_books: Array[LiveBook]`, about 12: two or three per section, novels on `front_table`, two spellbooks on lecterns;
  - `var book_draws: Array[MultiMeshInstance3D]`.

- [ ] **Step 1: Write the kit tests**, class `LibraryBooks`:
  - every piece an object, closed, in budget (book ≤ 600, stack ≤ 1500, each live part ≤ 800, lectern ≤ 2500, table ≤ 4000), through the gate;
  - `test_live_parts_share_a_hinge`: both covers' spine edges lie on the hinge line ± 1 mm;
  - `test_live_book_closes_flat`: at rest, the covers and blocks do not intersect (bounds overlap < 1 mm).
- [ ] **Step 2: Run, see them fail; write the books; run, see them pass; export; paint.**
- [ ] **Step 3: Write the bay tests:**
  - L16, the shelves are full and varied:
    - at least 400 books, drawn by ≤ 20 MultiMeshInstance3D nodes;
    - every board holds books;
    - no book's bounds intersect an upright or a neighbour's;
    - each book's lowest point sits 1–4 mm above its board;
    - along any board, no three neighbours share mesh, height and lean.
  - L17, a live book opens and closes: the player 1.2 m in front of a live book, facing it, makes `open` reach ≥ 0.95 within 1.2 s and `opened` fire once. The player at 3 m makes it reach ≤ 0.05 within 1.5 s and `closed` fire once.
  - L18, not through shelves: the player 1.2 m from a live book but behind its case (no line of sight) leaves `open` at 0 after 2 s.
  - L19, the kinds: the live books include ≥ 3 novels, ≥ 2 spells, and a study in each of the five sections.
  - L21, the form light spares them: F2 on, then off, leaves every live book's parts, the lamp and the chained book with exactly the materials they had, and the lamp light lit again.
  - L20, the frame time: the median process frame over 300 frames at the shop's middle is ≤ 1.1 × the underground bay's, measured the same way in the same run.
- [ ] **Step 4: Run, see L16–L21 fail; write `LiveBook.gd`, `BookFiller.gd` and `_books()`; run, see L1–L21 pass.**
- [ ] **Step 5: Shoot the book views and a 6 s clip walking past the front table (`--dolly=2`), so the novels open and close; read them; fix faults.**
- [ ] **Step 6: Run every headless suite** (`bash tools/run_suites.sh`) and the kit tests. Expected: all pass, and the known windowed vfx_test V1/V6 failures are reported as they stand.
- [ ] **Step 7: Commit** (`feat(library): the books, and the live books that open as you come near`). **Review gate.** After the user approves the shelves and books, write Part 2's plan (the living books).
