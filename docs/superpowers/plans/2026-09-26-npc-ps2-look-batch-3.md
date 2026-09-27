# NPC PS2 Look, Batch 3 (Heads and Variety): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every guard of a kind his own man: the spec's full set of faces, hair and beards, the watchman's bare-head helmet variant, each kind's full roll, and the painted outfits retired from the guard path.

**Architecture:**
- **Blender:** `tools/wardrobe` gains three faces (male `young` and `heavy`, female `soft`), two hair styles (male `tied`, female `tail`), two beards trimmed from the Quaternius beard (`short`, `moustache`), and a kettle hat fitted over a bare head and its hair (`kettlehat_bare`). `build_hair` learns to trim a style (`trim`, `keep`) and to add a tied tail (`tail`); the kettle learns to fit over heads and hair (`over: "head"`, `over_hair`). Hair and headgear are rebuilt over the new heads, as they must enclose every head of their body.
- **Godot:** a kind's options may list `""` (none) for hair and beards; options drop parts of another body (faces, hair, beards and now headgear). Every kind rolls its full set. A guard whose kind cannot be dressed becomes the plain base body; the painted guard outfits leave the guard path. `stage_wardrobe` draws crowd sheets.

**Tech Stack:** Godot 4.5.1 (GDScript, Forward+), Blender 5.2.2 LTS (bpy, bmesh, numpy, Cycles on Metal), Python 3.

**Spec:** `docs/superpowers/specs/2026-09-25-npc-ps2-look-design.md` (cited as §n; §8 per-kind variety and shared parts, §10 fallback, §11 "Retired in batch 3", §13 batch 3). **Earlier plans:** batch 0, 1 and 2 (`docs/superpowers/plans/2026-09-2*-npc-ps2-look-batch-*.md`). Batch 2 was final-reviewed, fixed and pushed (`4d8839a`); its rulings and deferred minors reached the user in its final report.

## Global Constraints

- **Binaries:** `$GODOT` = `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot` (4.5.1). `$BLENDER` = `/Applications/Blender.app/Contents/MacOS/Blender` (5.2.2 LTS).
- **Budgets (§5):**
  - At most 3,000 triangles per NPC over every worn mesh, for **every** combination his options allow (the brute: 3,500), weapon excluded.
  - Outfit albedo and mask 256×256; heads (per face and tone), hair and headgear 128×128.
  - At most 64 colours per albedo; no normal, roughness or metallic maps.
- **Shading (§5):** per pixel, `diffuse_lambert_wrap`, `specular_disabled`, shadows on. Never per-vertex lighting.
- **Rig (§6.7):** at most 4 influences per vertex; game-bone joints within 1 mm of the part's own body's skeleton; cloth bones `cloth_<chain>_<n>`; worn meshes on `Layers.ACTORS`; modifier order Posture → Ragdoll → ClothReset → Cloth → Severed.
- **Shared parts (§8):** heads male young, weathered, heavy, old and female sharp, soft, each in light and dark skin; hair buzzed, parted, tied back, buns; beards full, short, moustache; headgear kettle hat, mail coif, nasal helm with its curtain, archer's hood.
- **Faces by kind (§8):** watchmen, swordsmen and archers roll any male face; the brute heavy or weathered; the arms master always old; the duelist sharp or soft.
- **Standing lessons (batches 0–2):**
  - Anything that must enclose something is an even grid with an enclosing pass; hair and headgear are fitted over **every** head of their body, so rebuild them after heads change (`build.heads_tree` reads `heads.blend` from `common.SOURCE`).
  - Recipe colours are sRGB through `common.set_faces`. Every part is baked alone; PNG imports are lossless; back up before every write. After any build that changes geometry, **bake before export**.
  - A chain-settings, options or `marks` change needs only an export.
  - The watchman stays batch 0's (`"batch": 0`): his outfit is exported, never rebuilt. The coif's cape keeps facing in. Both are the user's calls.
  - Cloth checks drive whole blows and read at the rig's size; values shift a few mm (K12 ~0.5 m/s) with the idle-sway phase, so keep margin. Godot's `SpringBoneSimulator3D` ignores skeleton scale for radii.
- **Scope:** looks only (no rule, AI or animation changes). Your first-person arms keep the painted path (`T_player`, K11). The painted guard textures stay on disk: deleting them needs the user's go-ahead (§11).
- **Blender:** headless only; `AUCOD_*` scenes. Never export the Quaternius eyes, eyebrows or hair as they are.
- **Shared files:** other sessions edit `Humanoid.gd`, `GuardRig.gd`, `Guard.gd`, `GuardBody.gd`, `GuardFighter.gd` and `sound_test.gd`. Re-read before editing, keep hooks small, never rewrite a file. The user pulls and commits the whole working tree ("fix N") at any moment: keep any sabotage of a real file to seconds and restore it at once.
- **Running suites:** `$GODOT --headless --fixed-fps 60 --quit-after 80000 --path . res://tests/<suite>.tscn`; after any export, `$GODOT --headless --path . --import` first; Blender tests `tools/wardrobe/wardrobe.sh test`.
- **Git:** as the user decides at the handoff.

## Decisions this plan makes (where the spec is silent)

1. **Names** (unique across bodies): faces `young`, `heavy` (male), `soft` (female); hair `tied` (male), `tail` (female); beards `short`, `moustache`; headgear `kettlehat_bare`.
2. **Sources.** The Quaternius pack has no short beard, moustache or tied hair. `short` and `moustache` are cut from `Hair_Beard.gltf`; `tied` is `Hair_SimpleParted.gltf` with a tail; `tail` is `Hair_Long.gltf` cut at her nape with a tail.
3. **"None" is an option.** `""` in a kind's `hair` or `beards` list means none (the watchman's clean chin shows his face's stubble). It is drawn like any entry and kept by `usable_options` without a file check.
4. **Helmet variants = the spec's one:** the watchman wears the kettle hat over the coif **or over his bare head** (§8), so his hair and beard show under the brim. `kettlehat_bare` is the same hat fitted over the male heads and the hair he may roll. No other variants (dented or deeper hats, open coifs, a battered helm) are built: the spec names none. The user may add them at plan review.
5. **Rolls** (§8, and where the spec's "Varies per guard" is silent, nothing more):

| Kind | faces | hair | beards | headgear sets |
|---|---|---|---|---|
| watchman | young, weathered, heavy, old | parted, buzzed, tied (seen only under the bare hat) | "", short, moustache, full | [kettlehat, coif], [kettlehat_bare] |
| swordsman | young, weathered, heavy, old | — | — | unchanged |
| archer | young, weathered, heavy, old | — | — | unchanged |
| brute | heavy, weathered | buzzed | short, full | unchanged (none) |
| duelist | sharp, soft | buns, tail | — | unchanged (none) |
| arms master | unchanged (old, parted, full) | | | |

   The watchman gains `hair_colours` [(0.20, 0.14, 0.09), (0.10, 0.08, 0.06), (0.35, 0.25, 0.15), (0.45, 0.30, 0.18)]. A kind's silhouette key may be alternatives: the watchman's is either kettle hat.
6. **Approved parts move a little.** Rebuilding hair and headgear over the new (wider) heads can move the arms master's hair and beard, the brute's buzzed cut and beard, and every helmet a few millimetres outward. That is ruled acceptable; each must still pass its `fit` and `encloses` checks.
7. **Painted outfits leave the guard path (§11).** A guard whose kind cannot be dressed is built as the plain base body of his archetype's sex (`Humanoid.build(&"", female)`), warned once; no painted texture, hair, armour or boots. The archetypes' `outfit`, `hair`, `hair_tint` and `armour` look fields and `GuardRig.DEFAULT_LOOK`'s go. `Humanoid.build`'s painted path stays for your arms.
8. **Deferred minors folded in** (they sit on the roll's path): M2 `check_kind` refuses a kind whose options name another body's face, hair or headgear; M3 `usable_options`' `body` has no default and its warning names the cause; M4 `common.part_target` fails with a message; M5 K5 requires leg colliders; M6 the kind JSON exports its `budget`. Headgear gains the body filter (batch 2's declined item).
9. **Crowd sheets** replace the painted before/after shot: `stage_wardrobe -- --crowd` stands 12 guards of each kind (seeds 1–12) at 6 m by day and by torchlight, and a strip of their faces at 0.7 m.

## Data contracts (changes to batch 2's)

- `recipes.HAIR` entries may carry `"trim": {"below": z}` (drop faces whose centre is under `z`, in the body's head space), `"keep": {"box": [[x0, y0, z0], [x1, y1, z1]]}` (keep only faces whose centre is inside), and `"tail": {"length": m, "width": m, "sides": 6, "at": [y, z]}` (a tapered tail from the back of the head at `(0, y, z)` down the neck).
- `recipes.HEADGEAR` entries carry `"body"` (default `"male"`); their JSON writes it. A `kettle` may have `"over": "head"` with `"over_hair": [styles]`.
- The kind JSON gains `"budget"` (`common.budget_of`).
- Options: `""` in `hair` or `beards` = none.
- `Wardrobe.usable_options(options: Dictionary, body: String) -> Dictionary` (no default) drops faces, hair, beards and headgear sets of another body.
- Test `EXPECT`: `worn` goes (K1 derives it from the roll); `key` holds alternatives (`[["kettlehat", "kettlehat_bare"]]`: one of each inner list is worn).

## Review Focus

Five situations the spec implies but no existing check covers, each with the test that now pins it:

1. **Hair under the bare kettle hat.**
   - Expected: for every face and hair he may roll, no hair or scalp pokes through the bowl, at rest, bowed or mid-overhead.
   - Tests: `check headgear` (`fit` over heads and hair, Task 4); K31 (Task 4).
2. **Old helmets on new faces.**
   - Expected: the coif, hood, nasal helm and curtain still enclose the heavy face's wider jaw and brow; no face shows through mail or wool.
   - Tests: `check headgear` over all four male heads; K15 on every face (Task 2).
3. **Beards on every face.**
   - Expected: each beard sits on each male face's jaw or lip, never floating or sunk (the moustache on the upper lip of the heavy and the young face alike).
   - Tests: `check hair` (`fit` with its rays on every male head); `case_beards` (Task 3).
4. **The full roll is reachable and honoured.**
   - Expected: over 32 seeds every listed face, hair, beard (and "none") and headgear set of every kind appears, and the dresser wears exactly what was rolled (hair only where the headgear allows it).
   - Test: K10 (Task 5).
5. **Missing files never paint a guard.**
   - Expected: without a kind's files the guard is the plain base body of his sex, with no `T_<kind>` texture, hair or armour; your arms are still painted.
   - Tests: K1b, K24 (Task 6); K11 unchanged.

---

### Task 1: Options machinery

**Files:**
- Modify: `scripts/Visual/Wardrobe.gd` (`usable_options`, `can_dress`, `_warn_once`, the `""` rule), `scripts/Visual/Humanoid.gd` (`dress`: headgear body; one argument), `tools/wardrobe/check.py` (`check_kind`), `tools/wardrobe/common.py` (`part_target`), `tools/wardrobe/export.py` (`"budget"`, headgear `"body"`), `tests/wardrobe_test.gd` (K2, K30, K32, K5's collider requirement), `tools/wardrobe/test_build.py`

**Interfaces:**
- **Produces:** `Wardrobe.usable_options(options, body)` as in the data contracts; `""` kept in `hair`/`beards`; `Wardrobe.headgear_data(piece).get("body", "male")`; kind JSON `"budget"`; `check.check_kind` messages `"options: <part> is made for the <b> body"`.

- [ ] **Step 1: Write the failing tests.**
  - `wardrobe_test.gd`:

```gdscript
# K2 every combination his options allow, from the JSONs' triangle counts
_check("K2 %s: every combination within %d triangles" % [kind, budget], heaviest <= budget and budget == int(data.budget), ...)
# K30 "" means none: a doctored watchman with beards ["", "full"] rolls a clean chin for some seed, wears no Beard_*, and no warning names ""
_check("K30 an empty style is none, not a missing file", clean_seen and not warned, ...)
# K32 headgear of another body is dropped (the duelist doctored with the kettle hat set): she dresses bare-headed
_check("K32 a kind never wears headgear made for the other body", "kettlehat" not in names and man.body.name == "Outfit", ...)
```
  - K5's condition gains `colliders.has(&"thigh_l") and colliders.has(&"thigh_r")` (M5).
  - `test_build.py` `case_foreign_parts`: a kind recipe whose options name `sharp` on the male body fails `check_kind` with `"options: sharp is made for the female body"`; `common.part_target("heads", "elf")` stops through `common.fail` (`SystemExit`) after printing `wardrobe: no heads for the elf body` (the test captures stdout).
- [ ] **Step 2: Run** the wardrobe suite and `wardrobe.sh test`. Expected: FAIL K2 (no `budget` in the JSON), K30, K32, `foreign_parts`.
- [ ] **Step 3: Implement** the Produces list. `export_kind` writes `"budget"`; headgear JSON writes `"body"`. Re-export every kind and the headgear (`wardrobe.sh export all`; nothing is rebuilt), then `--import`.
- [ ] **Step 4: Run** both. Expected: all PASS.
- [ ] **Step 5: Commit:** `feat(wardrobe): none as an option, parts of one body, budgets in the JSON`

### Task 2: Young, heavy and soft faces

**Files:**
- Modify: `tools/wardrobe/recipes.py` (`HEADS`), `tools/wardrobe/test_build.py`
- Create (generated): `heads/young*`, `heads/heavy*`, `heads/soft*`; rebuilt `source/heads.blend`, `heads_female.blend`, `hair.blend`, `hair_female.blend`, `headgear.blend` and their exports

**Interfaces:**
- **Produces** (shapes use the landmarks of `weathered` and `sharp`; every entry is mirrored as theirs are; `tris` 340, tones light and dark):
  - `young` (male): cheeks fuller `{"at": (0.047, -0.07, 1.648), "radius": 0.03, "along_normal": 0.003}`, the jaw shorter `{"at": (0.0, -0.09, 1.575), "radius": 0.04, "move": (0.0, 0.0, 0.002)}`, the brow lighter `{"at": (0.032, -0.088, 1.722), "radius": 0.03, "move": (0.0, 0.002, 0.002)}`; `eyes` 0.9; `grit` {"stubble": 0.25, "bags": 0.1, "lines": 0.1}; `brows` (0.20, 0.14, 0.09).
  - `heavy` (male): the jaw's sides wider `{"at": (0.05, -0.05, 1.585), "radius": 0.035, "move": (0.006, 0.0, 0.0)}`, jowls fuller `{"at": (0.052, -0.06, 1.595), "radius": 0.03, "along_normal": 0.006}`, the nose broader `{"at": (0.0, -0.1, 1.64), "radius": 0.015, "along_normal": 0.003}`, the brow heavier `{"at": (0.032, -0.088, 1.722), "radius": 0.03, "move": (0.0, -0.005, -0.003)}`; `eyes` 0.8; `grit` {"stubble": 0.8, "bags": 0.5, "lines": 0.4}; `brows` (0.12, 0.09, 0.07).
  - `soft` (female): lower cheeks fuller `{"at": (0.05, -0.063, 1.61), "radius": 0.028, "along_normal": 0.004}`, the jaw rounder `{"at": (0.05, -0.045, 1.558), "radius": 0.03, "move": (0.002, 0.0, 0.002)}`, the nose smaller `{"at": (0.0, -0.1, 1.633), "radius": 0.012, "along_normal": -0.002}`; `eyes` 0.9; `grit` {"stubble": 0.0, "bags": 0.15, "lines": 0.1}; `brows` (0.25, 0.17, 0.10).

- [ ] **Step 1: Write the failing test** `case_faces` in `test_build.py` (heads built into a temp folder, as `case_male_parts`):

```python
assert set(common.parts_of(recipes.HEADS, "male")) >= {"young", "weathered", "heavy", "old"} and "soft" in common.parts_of(recipes.HEADS, "female")
assert half_width(heads["heavy"], z=1.585) >= half_width(heads["weathered"], z=1.585) + 0.004
assert depth_at(heads["young"], (0.047, -0.07, 1.648)) >= depth_at(heads["weathered"], (0.047, -0.07, 1.648)) + 0.005  # not hollowed
assert half_width(heads["soft"], z=1.558) >= half_width(heads["sharp"], z=1.558) + 0.003
assert all(common.tri_count(h) <= 450 for h in heads.values())
```
  (New helpers in `test_build.py`: `half_width(obj, z)`, the widest |x| of its vertices within 5 mm of `z`; `depth_at(obj, point)`, how far its surface stands out from the head's middle toward `point`.)
  - `wardrobe_test.gd`, K15 on every male face (Review Focus 2): a watchman and an archer doctored per face (`Wardrobe._json` override of `faces`), dressed; no edge of the face passes through the coif, hood or curtain (edges through faces, as K22), at rest and bowed (`_bow` 0.61).
- [ ] **Step 2: Run** `wardrobe.sh test` and the wardrobe suite. Expected: `FAIL faces`; K15 FAILs for `young` and `heavy` (no files).
- [ ] **Step 3: Implement** the Produces list. Then, in this order, `build`, `check`, `bake`, `export`: `heads`, `heads_female`, `hair`, `hair_female`, `headgear` (decision 6), then `export all` (kind JSONs read the parts' counts) and `--import`.
- [ ] **Step 4: Run** `wardrobe.sh test`, `wardrobe.sh check all` and the wardrobe suite. Expected: all PASS; `check headgear` passes `fit` and `encloses` on all four male heads; K15 on every face.
- [ ] **Step 5: Commit:** `feat(wardrobe): the young, heavy and soft faces`

### Task 3: Tied hair, the tail, short beard and moustache

**Files:**
- Modify: `tools/wardrobe/build.py` (`build_hair`: `trim`, `keep`, `tail`), `tools/wardrobe/recipes.py` (`HAIR`), `tools/wardrobe/check.py` (hair `fit` rays per style), `tools/wardrobe/test_build.py`
- Create (generated): `hair/tied*`, `hair/tail*`, `hair/short*`, `hair/moustache*`

**Interfaces:**
- **Produces:**
  - `HAIR["short"]`: from `Hair_Beard.gltf`, body male, kind beard, `trim` {"below": 1.555}, `tris` 90, `clearance` 0.003, `fit_rays` JAW.
  - `HAIR["moustache"]`: from `Hair_Beard.gltf`, body male, kind beard, `keep` {"box": [[-0.04, -0.13, 1.626], [0.04, -0.07, 1.648]]} (the upper lip: the mouth's line is at z 1.623, `bake.weather`), `tris` 40, `clearance` 0.002, `fit_rays` {"elevations": [-20, -10], "azimuths": [-30, -15, 15, 30]}.
  - `HAIR["tied"]`: from `Hair_SimpleParted.gltf`, body male, kind hair, `tail` {"length": 0.12, "width": 0.035, "sides": 6, "at": [0.07, 1.60]}, `tris` 200 in all, `clearance` 0.004, `fit_rays` CROWN.
  - `HAIR["tail"]`: from `Hair_Long.gltf`, body female, kind hair, `trim` {"below": 1.50}, `tail` {"length": 0.18, "width": 0.04, "sides": 6, "at": [0.065, 1.555]}, `tris` 220 in all, `clearance` 0.004, `fit_rays` CROWN.
  - `build_hair` cuts before it decimates; the tail is a tapered loft of `sides` round from `at` down the back of the neck, clear of the neck by `clearance`, its top on `Head`, its lower half blended onto `neck_01` (no chain: it rides).

- [ ] **Step 1: Write the failing tests** in `test_build.py`, `case_beards` and `case_tails` (built into a temp folder over the committed heads):

```python
assert lowest(hair["short"]) >= lowest(hair["full"]) + 0.025                  # shorter
assert jaw_covered(hair["short"], heads)                                      # JAW rays at -30 deg still meet it on every male head
assert all(abs(v.x) <= 0.045 and 1.62 <= v.z <= 1.65 and v.y <= -0.07 for v in verts(hair["moustache"]))
assert bones_of(hair["tied"]) <= {"Head", "neck_01"} and lowest(hair["tied"]) <= 1.49   # a tail down his neck
assert bones_of(hair["tail"]) <= {"Head", "neck_01"} and nothing_below_nape_but_tail(hair["tail"])
```
  (New helpers: `lowest(obj)`, its lowest vertex's z; `verts(obj)`; `bones_of(obj)`, the bones any vertex is weighted to (`weights_of` already returns per-vertex weights); `jaw_covered(obj, heads)`, check.fit's JAW rays at -30 degrees meet it on every head; `nothing_below_nape_but_tail(obj)`, every vertex under z 1.50 belongs to the tail's loft.)
- [ ] **Step 2: Run** `wardrobe.sh test`. Expected: FAIL `beards`, `tails`.
- [ ] **Step 3: Implement.** Then `build`, `check`, `bake`, `export` `hair` and `hair_female`, rebuild `headgear` (the bare hat in Task 4 fits over this hair), `export all`, `--import`.
- [ ] **Step 4: Run** `wardrobe.sh test` and `wardrobe.sh check all`. Expected: all PASS (`check hair` fits each beard on every male head with its own rays).
- [ ] **Step 5: Commit:** `feat(wardrobe): tied hair, the tail, the short beard and the moustache`

### Task 4: The kettle hat over a bare head

**Files:**
- Modify: `tools/wardrobe/build.py` (`kettle`: `over: "head"`, `over_hair`; `hair_tree(body, styles)`), `tools/wardrobe/check.py` (headgear `fit` over heads and `over_hair`), `tools/wardrobe/recipes.py` (`HEADGEAR["kettlehat_bare"]`), `tools/wardrobe/test_build.py`, `tests/wardrobe_test.gd` (K31)
- Create (generated): `headgear/kettlehat_bare*`

**Interfaces:**
- **Consumes:** Task 2's heads, Task 3's `parted`, `buzzed`, `tied`.
- **Produces:** `HEADGEAR["kettlehat_bare"]`: the kettle hat's recipe with `"over": "head"`, `"over_hair": ["parted", "buzzed", "tied"]`, `"base_z": 1.735`, `"clearance": 0.006`, `"slack": 0.009`, `"rest": 0.04`, `"fit_rays": {"elevations": [15, 35, 55, 75], "azimuths": list(range(0, 360, 30))}`, `"hides_hair": False`, `"allows_beard": True`, `"body": "male"`, `"metal": ["Head"]`. `build.hair_tree(body, styles)`: one BVH over those hair shells from `hair.blend` (after `heads_tree`'s pattern). The kettle's outline and crown come from the outermost of the heads and those hair shells.

- [ ] **Step 1: Write the failing tests.**
  - `test_build.py` `case_bare_hat`: `kettlehat_bare` built into a temp folder; along its `fit_rays`, the gap from the outermost of every male head and every `over_hair` shell to the hat is in [`clearance`, `rest`].
  - `wardrobe_test.gd` K31:

```gdscript
# K31 (Review Focus 1) a bare-headed watchman's hair and head never cut through his hat: every face x hair he may roll
# (doctored options), at rest, bowed (_bow 0.61) and mid-overhead; edges through faces as K22
_check("K31 the bare kettle hat never cuts his hair or head", cuts == 0 and pairs == 12, "%d cuts over %d face-hair pairs" % [cuts, pairs])
```
- [ ] **Step 2: Run** `wardrobe.sh test` and the wardrobe suite. Expected: FAIL `bare_hat` (unknown piece), FAIL K31 (no piece).
- [ ] **Step 3: Implement**, then `build`, `check`, `bake`, `export` `headgear`, `--import`.
- [ ] **Step 4: Run** both. Expected: all PASS.
- [ ] **Step 5: Commit:** `feat(wardrobe): the kettle hat over a bare head`

### Task 5: The full roll

**Files:**
- Modify: `tools/wardrobe/recipes.py` (`options` of `WATCHMAN`, `SWORDSMAN`, `ARCHER`, `BRUTE`, `DUELIST` per decision 5), `tests/wardrobe_test.gd` (K1, K10, `EXPECT`, every check that names a face or hair reads it from the roll: K26, K28, K3c)
- Regenerated: every kind's JSON (`export all`; the watchman is exported, not built)

**Interfaces:**
- **Consumes:** Tasks 1–4's parts and options rules.
- **Produces:** each kind's options per decision 5; `EXPECT[kind].key` as alternatives; `EXPECT[kind].worn` removed.

- [ ] **Step 1: Write the failing tests** in `wardrobe_test.gd`:

```gdscript
# K1 he wears exactly his roll: Outfit, Head_<face>, Hair_<hair> unless a piece hides hair, Beard_<beard> unless one forbids it or "", his headgear set
# (_rolled(look) -> Array[String]: those names, from the roll and the pieces' hides_hair / allows_beard)
_check("K1 %s dresses as rolled" % kind, names.size() == _rolled(man.look).size() and _rolled(man.look).all(func(n): return n in names), ...)
# K10 (Review Focus 4) over 32 seeds every face, hair, beard ("" too) and headgear set listed appears, each guard wears his roll,
# the same seed makes the same man, his silhouette key (one of each alternative list) always
_check("K10 %s: the whole roll is reached and worn" % kind, unseen.is_empty() and all_worn and twin_same and keyed, "unseen %s" % unseen)
```
- [ ] **Step 2: Run** the wardrobe suite. Expected: FAIL K10 on the watchman, swordsman, archer, brute and duelist (unseen faces, hair, beards, sets).
- [ ] **Step 3: Implement** the options; `wardrobe.sh export all`; `--import`.
- [ ] **Step 4: Run** the wardrobe suite, then `squad_test gym_test combat_test duel_test exchange_test hunt_test wits_test sound_test posts_test climb_swim_test`. Expected: all PASS; K2 holds on every combination (the heaviest, a bare-headed watchman with tied hair and a full beard, about 2,810).
- [ ] **Step 5: Commit:** `feat(wardrobe): every guard his own face, hair and beard`

### Task 6: The painted outfits leave the guard path

**Files:**
- Modify: `scripts/AISystem/GuardRig.gd` (the fallback; `DEFAULT_LOOK`), `scripts/AISystem/GuardFighter.gd` (only the archetypes' `outfit`, `hair`, `hair_tint`, `armour` look fields), `tests/wardrobe_test.gd` (K1b, K24), `tests/visual/stage_wardrobe.gd` (its before/after shot)

**Interfaces:**
- **Produces:** `GuardRig`: `dressed or man.build(&"", bool(look.get("female", false)), idle)`, with no painted hair, armour or boots; `DEFAULT_LOOK := {"kind": &"watchman", "weapon": &"sword"}`.

- [ ] **Step 1: Write the failing tests** (re-read `GuardRig.gd` and `GuardFighter.gd` first):

```gdscript
# K1b (Review Focus 5) without his kind's files each guard is the plain base body of his sex: no T_<kind> texture on any mesh, no hair, no armour; the next kind still dresses
_check("K1b each kind without its files is the plain base body", fallen.values().all(func(ok): return ok) and next_dresses, str(fallen))
# K24 a kind whose hair or beards are all missing is the plain body, as one without its headgear
```
- [ ] **Step 2: Run** the wardrobe suite. Expected: FAIL K1b, K24 (painted).
- [ ] **Step 3: Implement** the Produces list; drop the look fields; `stage_wardrobe` loses its before/after shot (the crowd replaces it in Task 7).
- [ ] **Step 4: Run** the wardrobe suite (K11 still PASS: your arms painted) and every suite in `tests/*.tscn`. Expected: all PASS.
- [ ] **Step 5: Commit:** `feat(guards): the painted outfits leave the guard path`

### Task 7: Crowd sheets and a polish pass on every kind

**Files:**
- Modify: `tests/visual/stage_wardrobe.gd` (`--crowd`); while tuning, `recipes.py` values (each change commented with why)

- [ ] **Step 1: Implement** `--crowd`: per kind, seeds 1–12 in two rows of six, 1.2 m apart, shot at 6 m by day and by torchlight, and a strip of the twelve faces at 0.7 m (`crowd_<kind>_day.png`, `crowd_<kind>_night.png`, `faces_<kind>.png`). Run: `perl -e 'alarm 900; exec @ARGV' $GODOT --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_wardrobe.tscn -- --crowd --out=<dir>`.
- [ ] **Step 2: Look and fix by eye**, in this order: each kind still reads as itself in a crowd at night (§4.1: its silhouette key); no two faces in a row look like one face; beards and hair sit on every face (the moustache on the heavy face); nothing clips under the bare hat; colours of hair and beards against the other kinds. Re-run after each change.
- [ ] **Step 2b: Polish every kind's model** (the user, at the handoff: "we need to polish and better the models a bit more"). By eye at 2 m and 8 m, day and torch, and in `stage_guards`' poses, with each change pinned by the test that covers it (or a new one) and within the budgets. Start from what batch 2 left:
  - the duelist's half-cape reads as a sash from behind: make it read as a cape (its hem wider than its top, clear of her hanging arm);
  - ragged skin at the brute's bracer rims; the weathered head's neck seam under his mantle's front dip (M9);
  - then whatever the crowd sheets and poses show on any kind: silhouettes that blur at night, garments that read flat or plastic, seams, clipping, textures without wear.
  The watchman's outfit stays batch 0's (his rebuild is the user's call).
- [ ] **Step 3: Run** the wardrobe suite. Expected: all PASS.
- [ ] **Step 4: Send the user** the crowd sheets and face strips (`SendUserFile`, `render`) and ask for the batch 3 review, including whether to delete the painted guard textures.
- [ ] **Step 5: Commit:** `feat(wardrobe): crowd sheets, a polish pass` (a commit per kind polished is fine)

### Task 8: Full regression and hand-off

**Files:**
- Modify: `/Users/tinkertailorr/.claude/projects/-Users-tinkertailorr-a-world-of-darkness-alpha/memory/npc-ps2-look-project.md`

- [ ] **Step 1: Run** `tools/wardrobe/wardrobe.sh test`, `tools/wardrobe/wardrobe.sh check all`, and every suite in `tests/*.tscn`. Expected: no `FAIL`. Record the totals (batch 2 ended at 620 checks in 25 suites; Blender validate 16, bake 13, build 11).
- [ ] **Step 2: Update memory:** the new parts and rolls, the retired painted path, the counts, and what remains (the user's open calls: the half-cape, the watchman rebuild, the coif's cape, the approved kinds' cloth redesign, deleting the painted textures).
- [ ] **Step 3: Report to the user:** results, sheets, tuning, rulings, deferred minors.
