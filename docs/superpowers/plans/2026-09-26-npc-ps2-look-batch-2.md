# NPC PS2 Look, Batch 2 (Brute, Duelist): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dress the brute (fur mantle, bare arms, hide strips, 3,500 triangles) and the duelist (the female body, puffed sleeves, a half-cape) from the wardrobe, with the faces and hair they need, and every K check proven on all six kinds.

**Architecture:**
- **Blender:** `tools/wardrobe` learns the second body. Heads and hair are built per body: the female parts live in their own source files and export beside the male ones. It gains a fur fabric and two trims (studs, slashes); the garment types `mantle`, `puff` and `half_cape`; a one-sided pauldron; boot cuffs in their own fabric; and a rapier hanger. New parts: the female face `sharp`, her `buns`, and the brute's `buzzed` cut. Everything is built the batch 1 way: even grids fitted over what they cover, cloth built clear of the colliders, each part baked alone.
- **Godot:** a kind's options drop any face or hair made for the other body. The brute and duelist archetypes gain their `kind`, and the stager covers six kinds.

**Tech Stack:** Godot 4.5.1 (GDScript, Forward+), Blender 5.2.2 LTS (bpy, bmesh, numpy, Cycles on Metal), Python 3.

**Spec:** `docs/superpowers/specs/2026-09-25-npc-ps2-look-design.md` (cited as §n). **Earlier plans:** `docs/superpowers/plans/2026-09-25-npc-ps2-look-batch-0.md`, `docs/superpowers/plans/2026-09-26-npc-ps2-look-batch-1.md`. Batch 1's rulings reached the user in its final report. Its deferred minors are fixed (`b425319`). Its ledger workspace was removed after the commit.

## Global Constraints

- **Binaries:** `$GODOT` = `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot` (4.5.1). `$BLENDER` = `/Applications/Blender.app/Contents/MacOS/Blender` (5.2.2 LTS).
- **Budgets (§5):**
  - At most 3,000 triangles per NPC over every worn mesh (the brute: 3,500, `common.budget_of`), weapon excluded.
  - Outfit albedo and mask 256×256; heads, headgear and hair 128×128.
  - At most 64 colours per albedo; no normal, roughness or metallic maps.
- **Shading (§5, §2):** per pixel, `diffuse_lambert_wrap`, `specular_disabled`, shadows on. Never per-vertex lighting. `filter_nearest_mipmap` is set in the shader.
- **Rig (§6.7):**
  - At most 4 influences per vertex.
  - Game-bone joints within 1 mm of **the part's own body's** Quaternius skeleton. Both bodies share the 65 bone names, in order, but not their positions.
  - Cloth bones are named `cloth_<chain>_<n>`.
  - Every worn mesh is on `Layers.ACTORS`.
  - Modifier order: Posture → Ragdoll → ClothReset → Cloth → Severed.
- **Standing lessons (batches 0–1):**
  - Anything that must enclose something is an even grid with an enclosing pass.
  - Recipe colours are sRGB and go through `common.set_faces`.
  - Every part is baked alone; PNG imports are held lossless; back up before every write.
  - Judge culling in the game, not in Blender previews.
  - Garments that hang over others are built after them and clear of them.
  - Layered hanging cloth rides one chain (`rides`).
  - Cloth is built clear of the posed colliders (`collider_push`, `STANCE`).
  - Bands stand upright.
  - A chain-settings or `marks` change needs only an export.
  - The watchman stays batch 0's (`"batch": 0`) until the user says otherwise.
  - The coif's cape keeps facing in until the user says otherwise.
- **Scope:** looks only (no rule, AI or animation changes). Your arms are untouched. Faces and hair beyond what these two kinds need wait for batch 3.
- **Blender:** headless only; `AUCOD_*` scenes. Never export the Quaternius eyes, eyebrows or hair as they are.
- **Shared files:** other sessions edit `Humanoid.gd`, `GuardRig.gd`, `Guard.gd`, `GuardBody.gd`, `GuardFighter.gd` and `sound_test.gd`. Re-read before editing, keep hooks small, never rewrite a file. Other sessions also commit into this checkout: read `git log` before assuming the tree is yours.
- **Shell:** the Claude Bash tool runs zsh, where an unquoted `$VAR` holding several words stays one word.
- **Running suites:**
  - Suite: `$GODOT --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/<suite>.tscn` (wardrobe_test prints a NOTE when frames are not paced).
  - After any export, run `$GODOT --headless --path . --import` first.
  - Blender tests: `tools/wardrobe/wardrobe.sh test`.
- **Git:** commit as the user decides at the handoff.

## Decisions this plan makes (where the spec is silent)

1. **Female parts get their own source files.** They are `source/heads_female.blend` and `source/hair_female.blend`, built on the female Quaternius body (targets `heads_female`, `hair_female`).
   - `all` = heads, heads_female, hair, hair_female, headgear, then the kinds.
   - They export into the same `heads/` and `hair/` folders (names are unique across bodies), with `"body": "female"`.
   - One armature per file keeps every GLB's skeleton its own body's.
2. **Only what these kinds need comes forward from batch 3:**
   - new parts: the female face `sharp`, the female hair `buns`, the male hair `buzzed`;
   - the brute rolls `weathered` (§8: "heavy or weathered"; heavy waits for batch 3), `buzzed` and the existing `full` beard;
   - the duelist rolls `sharp` and `buns` (soft and tied hair wait for batch 3).
3. **The fur mantle is rigid.** §8 lists only the hide strips as the brute's chains. It is a closed fur roll over his shoulders, riding `CAPE_BONES` as the coif's cape does.
4. **The half-cape hangs from her left shoulder line**, from the back of her neck to her left shoulder point, on three chains of three bones (§8: half-cape ×3 (3)). Capsules on `spine_02` and `upperarm_l` keep it off her back and arm.
5. **`pauldron` gains `side`** (`both` | `left` | `right`, default `both`). The brute wears the right one only; his metal zone is `upperarm_r`.
6. **Hide strips are the existing `skirt` type** with four narrow panels on two bones each (§8).
7. **Sizes stay the archetypes'** (the brute 1.25, the duelist 0.94; `GuardRig` scales the rig). Recipes build at the base body's size.
8. **The duelist keeps `female` on her archetype** (her voice). Her body comes from her JSON.
9. **The brute's padded gut is the shell's existing `pads`** (front, pelvis to spine_02).

## Data contracts (changes to batch 1's)

- `recipes.HEADS` and `recipes.HAIR` entries carry `"body"` (default `"male"`). Their JSON already writes it.
- `Wardrobe.usable_options(options, body := "male")` drops a face or hair style whose JSON `body` is not `body`, with a warning. `can_dress` and `dress` pass the kind's body.
- The duelist's kind JSON has `"body": "female"`. No other key changes.

## Review Focus

Five situations the spec implies but no existing check covers, each with the test that now pins it:

1. **The female body end to end.**
   - Expected: her outfit, face and hair skin exactly on the female skeleton, and no kind ever wears a face or hair built for the other body (it would sit at the other body's head height).
   - Tests: K3 on the duelist (Task 5); K26 (Task 3).
2. **The brute at 1.25 scale.**
   - Expected: his hide strips swing, settle and stay out of his bigger legs, and a teleport or knockdown whips nothing.
   - Tests: K4, K5, K6, K6b and K12 on the brute, run at his archetype's size (Task 4).
3. **The half-cape through her attacks.**
   - Expected: through thrusts, sweeps and a run, no cape joint enters her back or left arm.
   - Test: K27 (Task 5).
4. **The mantle and his beard.**
   - Expected: through his overhead and a look down, the fur never cuts through his beard or face.
   - Test: K28, edges through faces as in K22 (Task 4).
5. **Bare arms.**
   - Expected: his arms are skin tinted his rolled tone, with no garment patches or holes at the jerkin's armholes, and steel rings only at his right shoulder.
   - Tests: `check brute` (`bare`); K29, his left upper arm's texels are skin in the mask; K9c (Task 4).

---

### Task 1: Two bodies in the pipeline

**Files:**
- Modify: `tools/wardrobe/wardrobe.sh`, `tools/wardrobe/common.py`, `tools/wardrobe/build.py` (`build_heads`, `build_hair`, `head_points`, `main`), `tools/wardrobe/check.py`, `tools/wardrobe/bake.py`, `tools/wardrobe/export.py` (`export_parts`), `tools/wardrobe/recipes.py` (`"body"` on every `HEADS` and `HAIR` entry), `tools/wardrobe/test_build.py`

**Interfaces:**
- **Produces:**
  - `common.parts_of(table: dict, body: str) -> list[str]`: the names in `table` whose `"body"` is `body` (missing means `"male"`), in table order.
  - `build.build_heads(force, body="male")` and `build.build_hair(force, body="male")`:
    - they build only that body's recipes, into `heads.blend`/`hair.blend` (male) or `heads_female.blend`/`hair_female.blend`;
    - each on that body's skeleton (`start(name, body)`);
    - hair fits over the heads of its own body (`head_points(body)`).
  - `wardrobe.sh <step> heads_female|hair_female`. `all` runs in the order of decision 1.
  - check, bake and export of a target use its body: `export.reference_joints(body)`, and the JSON's `"body"`.

- [ ] **Step 1: Write the failing tests** in `test_build.py`:

```python
def case_bodies():
    """Parts are grouped by body; a female part is built on, and checked
    against, the female skeleton."""
    table = {"m": {"body": "male"}, "f": {"body": "female"}, "n": {}}
    ok = common.parts_of(table, "female") == ["f"] and common.parts_of(table, "male") == ["m", "n"]
    fresh()
    head = build.start("heads_female", "female")[0].data.bones["Head"].head_local.z
    ok = ok and abs(export.reference_joints("female")["Head"][2] - head) < 0.001 \
        and abs(export.reference_joints("male")["Head"][2] - head) > 0.03
    return [] if ok else ["bodies"]

def case_male_parts():
    """The male heads and hair rebuild as committed (vertices by place with
    their weights, as `watchman` compares): the split changed nothing."""
```
(`case_male_parts` builds `heads` and `hair` into a temp folder, with `heads.blend` copied there first for the hair fit. It compares every `Head_*`/`Hair_*` object with the committed source, using `case_watchman`'s vertex matching.)

- [ ] **Step 2: Run** `tools/wardrobe/wardrobe.sh test`. Expected: `FAIL bodies` (no `parts_of`); `male_parts` PASS.
- [ ] **Step 3: Implement** the Produces list. The male targets behave exactly as before.
- [ ] **Step 4: Run** `tools/wardrobe/wardrobe.sh test`. Expected: all PASS, including `male_parts` and `watchman`.
- [ ] **Step 5: Commit:** `feat(wardrobe): heads and hair per body`

### Task 2: Fur, studs, slashes and the new garment types

**Files:**
- Modify: `tools/wardrobe/build.py`, `tools/wardrobe/fabrics.py`, `tools/wardrobe/bake.py` (`trim`), `tools/wardrobe/recipes.py` (`FABRICS` gains `"fur"` at the end: indices are baked into `wr_fabric`), `tools/wardrobe/test_build.py`, `tools/wardrobe/test_bake.py`

**Interfaces:**
- **Produces:**
  - `fabrics.FUR`: clumped tufts about 1.5 cm across, dark at the roots and light at the tips (tips lighter where the surface faces up), with a broken edge.
  - `bake.trim` paints two more kinds of note:
    - `studs`: iron dots with a dark ring, `spacing` apart in rows on the named part;
    - `slashes`: `count` vertical stripes of `colour` along a bone (the puffs' lining showing through).
  - `mantle`: a closed fur roll over his shoulders.
    - Built from four rings round his neck base, laid out as `cape_shell` lays its rings: the inner top snug at the neck; the outer top `reach` beyond his shoulder points; the rim `thickness` below that; the inner bottom tucked back to the chest (`depth_front`) and back (`depth_back`).
    - It stands `clear` of what is under it, is weighted on `CAPE_BONES` (`ride`), culls its back faces, and carries a fur fabric.
  - `puff`: rings along `upperarm_l`, mirrored to `_r`.
    - The rings run from `from` to `to` of the bone, 8 around, swelling to `puff` beyond the sleeve under them at `peak`.
    - Both ends are tucked 3 mm inside the sleeve; the puff is wholly on its upper arm.
    - It carries `slashes` notes.
  - `half_cape`: a strip from her left shoulder line (the back of her neck, `spine_03`, to her left shoulder point) hanging to `hem`.
    - It stands `clear` of what is under it; its top row rides `spine_03` and `clavicle_l`.
    - It has `chains` columns, each a chain `<name>_<n>` of `bones` bones under `spine_03`, drawn from both sides, and built clear of the colliders (`collider_push`).
  - `pauldron` gains `side`.
  - `boots` gain `cuff_fabric` and `cuff_colour`: the turned-down cuff in its own fabric (fur tops).
  - A new `prop` shape, `hanger`: a slim scabbard (`size`) on two straps from the belt at `at`, angled `back`.

- [ ] **Step 1: Write the failing tests.**
  - In `test_build.py`, `case_types2` builds two test recipes: `TYPES2` on the male body (a shell with a front `pads` entry, fur-cuffed boots, a mantle, a right pauldron, a hanger) and `TYPES3` on the female body (a sleeved shell, puffs, a half-cape).

```python
assert faces_on(male, "mantle") <= set(build.CAPE_BONES) and fabrics_of(male, "mantle") == {"fur"}
assert faces_on(male, "pauldron", side=1.0) == set() and faces_on(male, "pauldron", side=-1.0) == {"upperarm_r"}
assert "fur" in fabrics_of(male, "boots") and hangs_off(male, "hanger") <= 0.03
assert faces_on(female, "puff") == {"upperarm_l", "upperarm_r"} and puff_depth(female) >= 0.02   # beyond the sleeve at its peak
assert [len(chains["half_cape_%d" % n]["bones"]) for n in (1, 2, 3)] == [3, 3, 3]
assert all(chains["half_cape_%d" % n]["parent"] == "spine_03" for n in (1, 2, 3))
assert validate.check(male, ...) == [] and validate.check(female, ...) == []   # each against its own body's joints
```
  - In `test_bake.py`: `fur` (across 1.5 cm the shade changes faster than a wool field's, and upward-facing tips are lighter than roots); `studs` and `slashes` (painted only on their part or bone, as `plates` checks).

- [ ] **Step 2: Run** `tools/wardrobe/wardrobe.sh test`. Expected: `FAIL types2` (unknown types), `FAIL fur`, `FAIL studs`, `FAIL slashes`.
- [ ] **Step 3: Implement.** Mantles, puffs and hangers are sampled from what they cover (`common.outer_hit`), never cut from body regions. Build the half-cape's rows the way `panels` builds its rows.
- [ ] **Step 4: Run** `tools/wardrobe/wardrobe.sh test`. Expected: all PASS (`watchman` still PASS: nothing he uses changed).
- [ ] **Step 5: Commit:** `feat(wardrobe): fur, mantles, puffs, the half-cape`

### Task 3: The sharp face, buns and the buzzed cut

**Files:**
- Modify: `tools/wardrobe/recipes.py` (`HEADS["sharp"]`, `HAIR["buns"]`, `HAIR["buzzed"]`), `scripts/Visual/Wardrobe.gd` (`usable_options`, `can_dress`), `scripts/Visual/Humanoid.gd` (`dress` passes the body: one argument), `tests/wardrobe_test.gd` (K26)
- Create (generated): `source/heads_female.blend`, `source/hair_female.blend`, `heads/sharp*`, `hair/buns*`, `hair/buzzed*`

**Interfaces:**
- **Produces:**
  - `HEADS["sharp"]`:
    - body `"female"`, `tris` 340;
    - shape: cheekbones 4 mm higher and fuller, the jaw 4 mm narrower at its sides, a straight nose;
    - `eyes` 0.85;
    - `grit` {"stubble": 0.0, "bags": 0.3, "lines": 0.3, "scar": "brow"};
    - `brows` (0.14, 0.10, 0.08); tones light and dark.
  - `HAIR["buns"]`: body `"female"`, from `assets/characters/hair/Hair_Buns.gltf`, `kind` hair, `tris` 200, `clearance` 0.004, crown rays.
  - `HAIR["buzzed"]`: body `"male"`, from `Hair_Buzzed.gltf`, `kind` hair, `tris` 120, `clearance` 0.002 (a shell close to the scalp), crown rays.
  - `Wardrobe.usable_options(options, body)` as in the data contracts.

- [ ] **Step 1: Build the parts:**
  - `wardrobe.sh build heads_female && … check heads_female && … bake heads_female && … export heads_female`;
  - the same for `hair_female`;
  - then `build hair`, `check hair`, `bake hair`, `export hair` (buzzed; restore `parted` and `full`'s committed PNGs if their re-bake is not byte-identical, as batch 1 did for the weathered head);
  - then the import.
  - Expected: every check OK; `sharp` ≤ 450, `buns` ≤ 220, `buzzed` ≤ 220 triangles; every fit clears its own body's heads.
- [ ] **Step 2: Write the failing test:**

```gdscript
# K26 a kind never wears a face or hair of the other body (the watchman, doctored with the duelist's)
_doctor(&"watchman", {"faces": ["weathered", "sharp"], "hair": ["buns"], "headgear": [[]]})
var mixed := []
for s in range(1, 9):
	mixed.append_array(_worn_names((await _guard(s))._rig.man))
Wardrobe.forget()
_check("K26 a kind never wears a face or hair of the other body", "Head_weathered" in mixed
	and not ("Head_sharp" in mixed) and not ("Hair_buns" in mixed), str(mixed))
```
- [ ] **Step 3: Run** the wardrobe suite. Expected: K26 FAIL (some seeds wear `Head_sharp` on the male skeleton).
- [ ] **Step 4: Implement** the body filter in `usable_options`; `can_dress` and `dress` pass the kind's body.
- [ ] **Step 5: Run** the wardrobe suite. Expected: all PASS.
- [ ] **Step 6: Look** at a textured preview of `sharp` with `buns`, and of `weathered` with `buzzed` and `full`: no scalp through the shells.
- [ ] **Step 7: Commit:** `feat(wardrobe): the sharp face, buns, the buzzed cut`

### Task 4: The brute

**Files:**
- Modify: `tools/wardrobe/recipes.py` (`BRUTE`, `KINDS`), `tests/wardrobe_test.gd` (`DRESSED[&"brute"] = &"brute"`, `EXPECT.brute`, K9c, K28, K29)
- Create (generated): `source/brute.blend`, `brute.glb/.png/_mask.png/.json`

**Interfaces:**
- **Consumes:** Tasks 1–3.
- **Produces:** `BRUTE`: male, `base_tris` 1400, `bare` ["head", "upper", "lower"], belt `spine_01` 0.0. Garments, in this order:

| Name | Type | Fabric, colour (sRGB) | Key settings |
|---|---|---|---|
| trousers | shell | wool (0.24, 0.19, 0.14) | regions pelvis, thigh, calf; bottom calf_l 0.6; top spine_01 0.0; 0.008 |
| boots | boots | leather (0.20, 0.14, 0.09) | top calf_l 0.5; cuff 0.05, `cuff_fabric` fur (0.36, 0.28, 0.20); 0.012 |
| hands | mittens | skin | `cuff` 0 |
| gut | shell | quilted_linen (0.40, 0.33, 0.24) | regions torso, pelvis; bottom thigh_l 0.05; no sleeves; 0.014; `pads` [front, pelvis 0.0 to spine_02 0.5, 0.05] |
| jerkin | shell | leather (0.24, 0.16, 0.10) | regions torso; over gut; 0.012; `studs` spacing 0.05 |
| bracer_l, bracer_r | bracer | leather (0.22, 0.15, 0.09) | lowerarm_l / lowerarm_r, from 0.3 to 0.85 |
| hides | skirt | leather (0.34, 0.26, 0.18) | panels front [−25, 25], back [155, 205], left [60, 110]; hem thigh_l 0.45; bones 2 |
| belt | belt | leather (0.16, 0.11, 0.07) | height 0.09; iron buckle 0.07 × 0.012 × 0.06 |
| mantle | mantle | fur (0.30, 0.24, 0.18) | over jerkin; reach 0.16; thickness 0.05; depth_front 0.12; depth_back 0.18; clear 0.02 |
| pauldron | pauldron | iron (0.28, 0.27, 0.27) | side right; over jerkin; reach 0.14; drop 0.12; rings 3; clearance 0.012 |
| pouch | prop | leather | at −100 |

  - `chains`: `hides_front/back/l/r` {stiffness 1.8, drag 0.8, gravity 1.0, radius 0.035}.
  - `colliders`: thigh_l/r 0.10, calf_l/r 0.07, spine_01 0.18.
  - `metal`: ["upperarm_r"].
  - `options`:
    - faces [weathered], tones [light, dark];
    - hair [buzzed], beards [full], hair_colours [(0.25, 0.20, 0.18), (0.14, 0.11, 0.09), (0.45, 0.30, 0.18)];
    - headgear [[]], no dye, grime [0.4, 1.0].
  - `EXPECT.brute`: worn ["Outfit", "Head_weathered", "Hair_buzzed", "Beard_full"]; key ["Hair_buzzed", "Beard_full"]; rings [[upperarm_r, 0, 0]]; silent [[upperarm_l, 0, 0], [spine_02, 0, 0.15], [thigh_l, calf_l]]; metal {upperarm_r: "Outfit"}.

- [ ] **Step 1: Write the failing tests.** Add `&"brute"` to `DRESSED`. Every per-kind check now covers him, K2 against 3,500. Then add:

```gdscript
# K9c his right pauldron rings; his bare left arm and his leathers do not
_check("K9c a brute rings only at his pauldron", _rings(br, &"upperarm_r") and not _rings(br, &"upperarm_l") and not _rings(br, &"spine_02"), "")
# K28 (Review Focus 4) through his overhead and a look down, his mantle never cuts his beard or face
_check("K28 his mantle never cuts through his beard or face", cuts == 0, "%d cuts" % cuts)
# K29 (Review Focus 5) his bare left upper arm is skin in his mask (so it takes his tone)
_check("K29 his bare arms are skin", skin_share >= 0.9, "%.2f of his left upper arm's vertices" % skin_share)
```
  - `cuts`: `_cuts` (K22's) between the mantle's faces and the `Beard_full` and `Head_weathered` faces, CPU-skinned each frame through an overhead strike and 30 frames with his head bowed 35° (a Posture look target).
  - `skin_share`: of the outfit's vertices weighted ≥ 0.99 to `upperarm_l`, the share whose mask texel is G ≥ 0.5.
  - The mantle's faces are the outfit's faces wholly on `CAPE_BONES` above `spine_02`: `_faces_of`, filtered by a `_vertices_on(bones, above)` helper.
- [ ] **Step 2: Run** the wardrobe suite. Expected: every brute check FAILs (no files).
- [ ] **Step 3: Build and check:** `tools/wardrobe/wardrobe.sh build brute && … check brute`. Fix what the rules report, in the recipe or the builders, until `check brute` is clean.
- [ ] **Step 4: Bake, export, import:** `… bake brute && … export brute && $GODOT --headless --path . --import`.
- [ ] **Step 5: Run** the wardrobe suite. Expected: all PASS; his heaviest combination ≤ 3,500 triangles; K4, K5, K6, K6b and K12 pass at his size (tune his chains as batch 1 did, one ledgered ruling per value).
- [ ] **Step 6: Commit:** `feat(wardrobe): the brute`

### Task 5: The duelist

**Files:**
- Modify: `tools/wardrobe/recipes.py` (`DUELIST`), `tests/wardrobe_test.gd` (`DRESSED[&"duelist"] = &"duelist"`, `EXPECT.duelist`, K27)
- Create (generated): `source/duelist.blend`, `duelist.*`

**Interfaces:**
- **Produces:** `DUELIST`: female, `base_tris` 1300, `bare` ["head"], belt `spine_01` 0.0. Garments, in this order:

| Name | Type | Fabric, colour (sRGB) | Key settings |
|---|---|---|---|
| breeches | shell | wool (0.10, 0.09, 0.10) | regions pelvis, thigh; bottom calf_l 0.1; top spine_01 0.0; 0.008 |
| boots | boots | leather (0.12, 0.09, 0.07) | top thigh_l 0.35; cuff 0.06 (folded down); 0.01 |
| doublet | shell | wool (0.50, 0.06, 0.08), dye | regions torso, pelvis, upper, lower; bottom thigh_l 0.05; sleeves to the wrist; 0.012; lips sleeve, bottom |
| puffs | puff | wool (0.50, 0.06, 0.08), dye | from 0.0 to 0.55 of upperarm; peak 0.25; puff 0.035; `slashes` 6 of gold (0.78, 0.60, 0.22) |
| gloves | mittens | leather (0.10, 0.08, 0.07) | `cuff` 0.03 |
| collar | collar | wool (0.78, 0.60, 0.22) | on doublet; height 0.035 |
| skirt | skirt | wool (0.50, 0.06, 0.08), dye | panels front [−40, 40], back [140, 220], left [45, 135]; hem thigh_l 0.25; bones 1 |
| belt | belt | leather (0.10, 0.08, 0.07) | gold buckle |
| half_cape | half_cape | wool (0.10, 0.09, 0.11) | hem spine_01 −0.05; clear 0.02; chains 3; bones 3 |
| hanger | prop | leather (0.10, 0.08, 0.07), gold fittings | shape hanger; at 100; back 35; size (0.03, 0.018, 0.95) |

  - `chains`: `skirt_front/back/l/r` {1.6, 0.7, 1.0, 0.03}; `half_cape_1..3` {1.2, 0.6, 1.0, 0.03}.
  - `colliders`: thigh_l/r 0.08, calf_l/r 0.06, spine_01 0.14, spine_02 0.14, upperarm_l 0.05.
  - `metal`: [].
  - `options`:
    - faces [sharp], tones [light, dark];
    - hair [buns], beards [], hair_colours [(0.35, 0.22, 0.14), (0.12, 0.09, 0.07), (0.55, 0.38, 0.20)];
    - headgear [[]];
    - dye {colours [(0.50, 0.06, 0.08), (0.40, 0.05, 0.10), (0.56, 0.12, 0.06)], shift 0.02, fade [0, 0.3]};
    - grime [0.1, 0.5].
  - `EXPECT.duelist`: worn ["Outfit", "Head_sharp", "Hair_buns"]; key ["Hair_buns"]; rings []; silent [[Head, 0.12, 0], [spine_02, 0, 0.15], [thigh_l, calf_l]]; metal {}.

- [ ] **Step 1: Write the failing tests.** Add `&"duelist"` to `DRESSED`. Every per-kind check now covers her; K3 runs on the female skeleton; K7's severed head takes `Head_sharp` and `Hair_buns`. Then add:

```gdscript
# K27 (Review Focus 3) through her attacks and a run, no half-cape joint enters her back or left arm
_check("K27 her half-cape stays off her back and left arm", worst >= -0.005, "closest %.3f past the surface (%s)" % [worst, where])
```
  - `worst` and `where` come from K5's driving (her own attacks after five idles, and a run): every `half_cape_*` joint against the `spine_02` and `upperarm_l` capsules.
- [ ] **Step 2: Run** the wardrobe suite. Expected: every duelist check FAILs.
- [ ] **Steps 3–5:** as Task 4: build, check clean, bake, export, import; then the suite, all PASS, ≤ 3,000 triangles.
- [ ] **Step 6: Commit:** `feat(wardrobe): the duelist`

### Task 6: The archetypes dress

**Files:**
- Modify: `scripts/AISystem/GuardFighter.gd` (only the brute's and duelist's `look`), `tests/wardrobe_test.gd` if needed

**Interfaces:**
- **Produces:** `ARCHETYPES.brute.look.kind = &"brute"` and `duelist.look.kind = &"duelist"`. Their painted fields stay for the fallback (§10). The duelist's `female` stays for her voice.

- [ ] **Step 1: Run** the wardrobe suite before the change. Expected: K1c and K1b FAIL for the two kinds (their archetypes still paint).
- [ ] **Step 2: Implement:** the two `kind` keys (re-read `GuardFighter.gd` first; nothing else in it changes).
- [ ] **Step 3: Run** the wardrobe suite, then `squad_test gym_test combat_test duel_test exchange_test hunt_test wits_test sound_test`. Expected: all PASS. A check that looked inside the old painted body is updated to its wardrobe equivalent, with the reason noted (§9.2).
- [ ] **Step 4: Look** at `tests/visual/stage_guards.tscn`: every pose of the brute and the duelist. No skin through clothes; no cloth through legs or her arm; no head through the mantle.
- [ ] **Step 5: Commit:** `feat(wardrobe): brutes and duelists dress`

### Task 7: Six kinds on the stager, and the look pass

**Files:**
- Modify: `tests/visual/stage_wardrobe.gd` (its `KINDS` map gains `brute` and `duelist`). While tuning: `tools/wardrobe/recipes.py`, `fabrics.py`, `bake.py` constants.

- [ ] **Step 1: Run** `perl -e 'alarm 600; exec @ARGV' $GODOT --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_wardrobe.tscn -- --out=<dir>` and view every sheet.
- [ ] **Step 2: Fix by eye** in the recipes and builders, in this order:
  - silhouettes at 8 m at night (§4.1): the brute's fur shoulders and the duelist's puffs and half-cape must read;
  - layering and clipping;
  - colours and dirt against the other four kinds (one world);
  - the user's batch 1 look notes, if they have given them.

  Re-run after each change, and record each changed value and why in a comment beside it.
- [ ] **Step 3: Run** the wardrobe suite. Expected: all PASS.
- [ ] **Step 4: Send the user the sheets** (`SendUserFile`, display `render`): the six-kind lineup at night, and each new kind's before/after and turnaround. Ask for their batch 2 review.
- [ ] **Step 5: Commit:** `feat(wardrobe): six kinds on the stager, tuned`

### Task 8: Full regression and hand-off

**Files:**
- Modify: `/Users/tinkertailorr/.claude/projects/-Users-tinkertailorr-a-world-of-darkness-alpha/memory/npc-ps2-look-project.md`

- [ ] **Step 1: Run** `tools/wardrobe/wardrobe.sh test`, `tools/wardrobe/wardrobe.sh check all`, and every suite in `tests/*.tscn` with `--fixed-fps 60`. Expected: no `FAIL` lines. Record the totals (batch 1 ended at 542 checks in 23 suites; Blender validate 14, bake 9, build 6).
- [ ] **Step 2: Update memory:** the two kinds, the per-body pipeline, the new types, the checks, the counts, and "next: batch 3 (heads and variety) after the user's review".
- [ ] **Step 3: Report to the user:** the results, the sheets, what tuning changed, the rulings made, and the proposed next step.
