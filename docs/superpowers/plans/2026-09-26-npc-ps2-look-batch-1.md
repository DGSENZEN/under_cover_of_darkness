# NPC PS2 Look, Batch 1 (Swordsman, Archer, Arms Master): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dress the swordsman, the archer and the arms master (the `trainer` archetype) from the wardrobe, as PS2-style low-poly characters built by the batch 0 pipeline, with their headgear, the arms master's face, hair and beard, and every K check proven on all four dressed kinds.

**Architecture:**
- **Blender:** `tools/wardrobe` gains the garment types these kinds need (hanging panels with 1–3 bones, four-panel skirts, pauldrons, gauntlet cuffs, bracers, a sash with tails, a swinging quiver), three headgear pieces (a nasal helm and its mail curtain, the archer's hood with a tail), the "old" face, and a hair pipeline (parted hair and a full beard). Everything is built the way batch 0 ended: even parametric grids fitted over what they cover, checked by the `fit`/`encloses`/`bare`/`shading` rules, each part baked alone.
- **Godot:** the variety roll gains dye and hair colours (appended draws, so existing looks never change); `Humanoid.dress` wears hair and beards and dresses kinds without headgear; dismemberment moves to the spec's general copy rule; the three archetypes gain their `kind`.

**Tech Stack:** Godot 4.5.1 (GDScript, Forward+), Blender 5.2.2 LTS (bpy, bmesh, numpy, Cycles on Metal), Python 3.

**Spec:** `docs/superpowers/specs/2026-09-25-npc-ps2-look-design.md` (cited as §n). **Batch 0 plan and ledger:** `docs/superpowers/plans/2026-09-25-npc-ps2-look-batch-0.md`, `.superpowers/sdd/2026-09-25-npc-ps2-look-batch-0/progress.md` (its `Ruling:` lines are standing decisions).

## Global Constraints

- **Binaries:** `$GODOT` = `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot` (4.5.1). `$BLENDER` = `/Applications/Blender.app/Contents/MacOS/Blender` (5.2.2 LTS).
- **Budgets (§5):** at most 3,000 triangles per NPC over every worn mesh (outfit, head, hair, beard, headgear), weapon excluded; outfit and mask 256×256; heads, headgear and hair 128×128; at most 64 colours per albedo; no normal, roughness or metallic maps.
- **Shading (§5, §2):** per pixel, `diffuse_lambert_wrap`, `specular_disabled`, shadows on; never per-vertex lighting; `filter_nearest_mipmap` set in the shader.
- **Rig (§6.7):** at most 4 influences a vertex; game-bone joints within 1 mm of the Quaternius skeleton; cloth bones `cloth_<chain>_<n>`; every worn mesh on `Layers.ACTORS`; modifier order Posture → Ragdoll → ClothReset → Cloth → Severed.
- **Batch 0 lessons (standing rules):**
  - shells that must enclose something (hoods, helm skulls, hair, beards) are built as even parametric grids with an enclosing pass, never by decimating body regions (the decimated coif let the skull through);
  - recipe colours are sRGB and go through `common.set_faces` (`color_srgb`);
  - every part is baked alone; every PNG import is held lossless (`export.lossless`); a backup is kept before every write;
  - Blender previews draw both sides: judge culling in the game (the stager's close back shot) or with a culled Workbench render;
  - every garment type that hangs over another is built after it and hangs clear of it.
- **Scope:** looks only (no rule, AI or animation changes); your arms untouched; the duelist and brute stay painted (batch 2); all other faces, hair styles and the full roll wait for batch 3.
- **Blender:** headless only; `AUCOD_*` scenes; never export the Quaternius eyes, eyebrows or hair meshes as they are (hair is rebuilt, §6.4).
- **Shared files:** `Humanoid.gd`, `GuardRig.gd`, `Guard.gd`, `GuardBody.gd` and `GuardFighter.gd` are edited by other sessions: re-read before editing, find code by function name, keep hooks small, never rewrite a file.
- **Shell:** the Claude Bash tool runs zsh, where an unquoted `$VAR` holding several words stays one word: use arrays or `bash -c`.
- **Running suites:** `bash .superpowers/sdd/<plan>/run_suite.sh <suite>...` (copy batch 0's `run_suite.sh` into this plan's workspace) or `$GODOT --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/<suite>.tscn`; after any export, `$GODOT --headless --path . --import` first.
- **Git:** nothing is committed without the user's go-ahead (they keep the tree as-is): skip every commit step unless they say otherwise.

## Decisions this plan makes (where the spec is silent or batch 0 changed it)

1. **Hair, beard and the old face come forward from batch 3**, only what the arms master needs: the `old` face, `parted` hair, the `full` beard. Batch 3 builds the rest.
2. **Hair pieces are baked one texture each** (`hair/<style>.png`, greyscale, 128², mask R = 1 so the shader tints them), not one shared strand texture (§6.4): each piece bakes its own occlusion, as every part does since batch 0.
3. **The nasal helm is built by the pipeline** (a pointed bowl, a brow band, a nasal bar), like the batch 0 kettle hat, not the old `nasalhelm.glb` (§6.4 said re-bake it): the user asked in batch 0 that headgear belong with the outfit. All headgear is skinned wholly to its bones; the JSON's `rigid`/`bone`/`offset` keys are dropped from the contract (the reviewer's "rigid ignored" minor becomes moot).
4. **New roll draws are appended** after the nine of §7.5: 10 = dye colour (from `dye.colours`), 11 = hair colour (from `hair_colours`). Every existing look stays the same.
5. **Headgear can carry a dye** (the archer's hood takes his tunic's dye): its JSON gains `dye_base`.
6. **The arms master is the `trainer` archetype**; his kind is `arms_master`.

## Data contracts (changes to batch 0's)

**Kind JSON `options`:**
```json
{"faces": ["weathered"], "tones": ["light", "dark"], "hair": [], "beards": [],
 "hair_colours": [[0.72, 0.70, 0.66]],
 "headgear": [["hood"]],
 "dye": {"colours": [[0.20, 0.30, 0.14], [0.34, 0.25, 0.15], [0.37, 0.37, 0.35]], "shift": 0.02, "fade": [0.0, 0.35]},
 "grime": [0.3, 1.0]}
```
`dye.colour` (one colour) stays valid; `dye.colours[0]` is the base the outfit was baked in. `headgear` may be `[[]]` (no headgear). `metal` lists the kind's metal bones.

**Headgear JSON:** `{"piece", "triangles", "metal", "hides_hair", "allows_beard", "cloth", "colliders", "dye_base"}` — `cloth` holds the piece's chains (the hood's tail: `{"chain": "hood_tail", "parent": "Head", "bones": [...], "tip", "stiffness", "drag", "gravity", "radius"}`), `dye_base` is `[r, g, b]` or absent.

**Hair JSON (`hair/<style>.json`):** `{"style": "parted", "kind": "hair" | "beard", "body": "male", "triangles": 180, "dye_base": [0.5, 0.5, 0.5]}`; textures `hair/<style>.png` and `hair/<style>_mask.png`.

**`Humanoid.look`** gains `"hair_colour": Color`.

## Review Focus

Five situations the spec implies but no K check covers, each with the test that now pins it:

1. **A mixed squad of all four kinds.** Expected: guards of a kind share one outfit Mesh, Skin and material; different kinds never share one (a cache-key mix-up would dress a swordsman in watchman colours). Test: **K1c** per kind, Task 9.
2. **One kind's files missing.** Expected: that kind alone falls back to its own painted look (the swordsman keeps his painted nasal helm and pauldrons), with a warning; the others still dress. Test: **K1b** per kind, Task 9.
3. **Layered hanging cloth** (the surcoat over the mail skirt). Expected: through a run, a stop and a kick, the outer layer never swings through the inner. Test: **K21**, Task 6.
4. **Overhead strikes in pauldrons.** Expected: the pauldrons never bury themselves in the head or the helm's curtain. Test: **K22**, Task 6.
5. **Every chain through the kind's own attacks** (the quiver, the hood tail, the sash tails, the doublet skirt). Expected: no chain joint enters a thigh or calf capsule. Test: **K5** per kind, Tasks 6–8.

---

### Task 1: Pipeline plumbing for more kinds

**Files:**
- Modify: `tools/wardrobe/wardrobe.sh`, `tools/wardrobe/common.py`, `tools/wardrobe/check.py`, `tools/wardrobe/export.py`, `tools/wardrobe/build.py`
- Create: `tools/wardrobe/test_build.py` (Blender, factory-fresh, run by `wardrobe.sh test` after the other two)

**Interfaces:**
- **Produces:**
  - `wardrobe.sh list` prints the recipe kinds (from `recipes.KINDS`, read with plain `python3`, recipes being pure data); `all` = heads, hair, headgear, then every listed kind. `KINDS=(...)` is gone.
  - `common.part_limit(folder: str, name: str) -> int`: heads 450; headgear 300 (coif 240); hair 220 (beards 150). `check.py` and `export.py` use only this (their own `HEAD_LIMIT`/`GEAR_LIMIT` go).
  - `build.chain_bones(arm, chain: str, parent: str, points: list[Vector]) -> list[str]`: `len(points) - 1` connected-in-order bones `cloth_<chain>_1..n`, the first under `parent`, all deform. `add_chains(kind)` calls it for every `kind.chains` entry, whose `points` may now hold 2–4 points. The chain JSON's `tip` is the last segment's length.
  - `export.heaviest_parts(recipe) -> int` adds the heaviest hair and heaviest beard the kind can roll (from `hair/<style>.json`) to the heaviest head and headgear set.
  - `export_parts` writes a headgear piece's `cloth` and `colliders` from its scene data (`scene["wardrobe_chains"]` entries tagged with the piece) and `dye_base` when the piece has dye faces.

- [ ] **Step 1: Write the failing tests** in `test_build.py`:

```python
def case_chain_bones():
    """Four points make three bones in order, the first under the parent."""
    fresh()
    arm = armature()                      # root + pelvis, as test_validate's
    names = build.chain_bones(arm, "test", "pelvis", [Vector((0, 0, 1)), Vector((0, 0, 0.8)), Vector((0, 0, 0.6)), Vector((0, 0, 0.4))])
    bones = arm.data.bones
    ok = names == ["cloth_test_1", "cloth_test_2", "cloth_test_3"] and bones["cloth_test_1"].parent.name == "pelvis" \
        and bones["cloth_test_3"].parent.name == "cloth_test_2" and all(bones[n].use_deform for n in names)
    return [] if ok else ["chain: %s" % names]

def case_limits():
    ok = (common.part_limit("heads", "weathered"), common.part_limit("headgear", "coif"),
          common.part_limit("headgear", "kettlehat"), common.part_limit("hair", "parted")) == (450, 240, 300, 220)
    return [] if ok else ["limits"]
```
Also `wardrobe.sh list` prints `watchman` (a shell check in the step's command).

- [ ] **Step 2: Run them** — `tools/wardrobe/wardrobe.sh test; tools/wardrobe/wardrobe.sh list` — Expected: `FAIL chain`, `FAIL limits` (no such functions), and `list` rejected as an unknown verb.
- [ ] **Step 3: Implement** the Produces list above (`build.py` must stay importable: guard its `main()` as `bake.py`'s is).
- [ ] **Step 4: Run** `tools/wardrobe/wardrobe.sh test && tools/wardrobe/wardrobe.sh list && tools/wardrobe/wardrobe.sh build all && tools/wardrobe/wardrobe.sh check all` — Expected: all PASS, `watchman` listed, the watchman rebuilds with the same triangle count (1828) and checks clean.
- [ ] **Step 5: Commit** (with the go-ahead): `chore(wardrobe): plumbing for more kinds`

### Task 2: Godot plumbing: colours, bare heads, hair, the general sever rule

**Files:**
- Modify: `scripts/Visual/Wardrobe.gd`, `scripts/Visual/Humanoid.gd`, `tests/wardrobe_test.gd`

**Interfaces:**
- **Produces:**
  - `Wardrobe.roll(options, skin_tones, seed)`: after the nine draws of §7.5, draw 10 picks `dye.colours` (when given; the dye is that colour shifted and faded as before) and draw 11 picks `hair_colours`; the look gains `"hair_colour"` (default `Color(0.3, 0.25, 0.2)`). Draws 1–9 are untouched.
  - `Wardrobe.can_dress(kind)`: a kind needs faces; its headgear may be `[[]]`. `usable_options` keeps an empty set, and drops hair and beard styles whose `hair/<style>.glb/.png/_mask.png/.json` are missing (with a warning).
  - `Wardrobe.hair_data(style: StringName) -> Dictionary` (cached JSON, `{}` if missing).
  - `Humanoid.dress`: wears `look.hair` and `look.beard` (when rolled and allowed) as `Hair_<style>` / `Beard_<style>` with their mask and `dye_base`, then sets their `dye_colour` instance uniform to `look.hair_colour`; passes a headgear piece's `dye_base` (white if absent).
  - `Humanoid.weighted_meshes(bones: PackedInt32Array) -> Array[MeshInstance3D]`: the worn skinned meshes with a bind on any of `bones` carrying a non-zero weight. `_cut_piece` takes exactly these (§7.6's general rule; it replaces "a head takes every non-boot mesh, a leg its boots").
  - `Humanoid.sever` frees the cloth's `Keep_<bone>` capsules for every severed bone.
  - Test harness (in `wardrobe_test.gd`):
    - `_guard(seed: int, archetype: StringName = &"")`;
    - `const DRESSED := {&"watchman": &""}` (kind → archetype), grown by Tasks 6–8; every per-kind check loops over it;
    - `_doctor(kind: StringName, changes: Dictionary)`: puts the kind's JSON, with `changes` merged into its `options`, into `Wardrobe._json[Wardrobe.ROOT + "<kind>.json"]` (the cache `_read` keys by full path), so the next guard of that kind dresses from it; `_doctor_missing(kind)` puts `{}` there instead; `Wardrobe.forget()` undoes both (a GLB under `user://` cannot be loaded unimported, so fixtures doctor data, never files);
    - `_worn(man, name) -> MeshInstance3D` (the worn mesh of that name, or null); `_rings(g, bone) -> bool` (whether `man.armour_near` answers at that bone's joint, as K9 asks);
    - K5 per kind drives every attack in its archetype's `attacks` (the watchman: kick and lunge, as before).

- [ ] **Step 1: Write the failing tests:**

```gdscript
# K10a (extended) new draws never change the old ones; dye colours are picked from the list
var o3 := o.duplicate(true)
o3["dye"] = {"colours": [[0.2, 0.3, 0.14], [0.34, 0.25, 0.15], [0.37, 0.37, 0.35]], "shift": 0.0, "fade": [0.0, 0.0]}
o3["hair_colours"] = [[0.72, 0.7, 0.66]]
var hues := {}
var kept := true
for s in range(1, 13):
	var a: Dictionary = Wardrobe.roll(o, tones, s)
	var b: Dictionary = Wardrobe.roll(o3, tones, s)
	kept = kept and [a.face, a.tone, a.headgear, a.fade, a.grime, a.height] == [b.face, b.tone, b.headgear, b.fade, b.grime, b.height]
	hues[snappedf(b.dye.h, 0.01)] = true
_check("K16 the dye rolls from its colours, and new draws change no old look", kept and hues.size() >= 2 and Wardrobe.roll(o3, tones, 5).hair_colour.is_equal_approx(Color(0.72, 0.7, 0.66)), str(hues))

# K17 a kind without headgear dresses (the watchman, doctored to headgear [[]])
_doctor(&"watchman", {"headgear": [[]]})
var bare := await _guard(3)
var names := _worn_names(bare._rig.man)
Wardrobe.forget()
_check("K17 a kind with no headgear dresses", bare._rig.man.body.name == "Outfit" and bare._rig.man.look.headgear.is_empty()
	and names.all(func(n): return n in ["Outfit", "Head_weathered"]), str(names))

# K19 a severed part takes exactly the worn meshes weighted to its bones
var g := await _guard(41)
var weighted := g._rig.man.weighted_meshes(_bones_under(g, &"thigh_l")).map(func(m): return String(m.name))
_check("K19 a leg takes what is weighted to it: his outfit, not his head or gear", weighted == ["Outfit"], str(weighted))

# K20 a severed leg's cloth capsules go with it
g.die(null)
await _frames(5)
g._rig.man.sever(&"thigh_l", Vector3.RIGHT)
await _frames(2)
var left: Array = g._rig.man.cloth.get_children().map(func(c): return String(c.name))
_check("K20 a severed leg no longer props his skirts", not ("Keep_thigh_l" in left) and not ("Keep_calf_l" in left) and "Keep_thigh_r" in left, str(left))
```
(`_bones_under(g, bone)` wraps `man._bones_under`.)

- [ ] **Step 2: Run** the wardrobe suite — Expected: K16, K17, K19, K20 FAIL (unknown keys, `can_dress` false, no `weighted_meshes`, capsules kept); every batch 0 check still PASS.
- [ ] **Step 3: Implement** the Produces list. `dress` keeps its painted fallback untouched. `weighted_meshes` reads each mesh's `ARRAY_BONES`/`ARRAY_WEIGHTS` once and caches the set of bone indices it weighs (per mesh resource), then maps skin binds to skeleton bones by name.
- [ ] **Step 4: Run** the wardrobe suite, then `bodies_test gore_test` — Expected: all PASS (K7 and K7b unchanged in outcome).
- [ ] **Step 5: Commit** (with the go-ahead): `feat(wardrobe): dye and hair colours, bare heads, the general sever rule`

### Task 3: The new garment types

**Files:**
- Modify: `tools/wardrobe/build.py`, `tools/wardrobe/fabrics.py`, `tools/wardrobe/recipes.py` (`FABRICS` gains `"wrapped"`, `"hair"` at the end: indices are baked into `wr_fabric`), `tools/wardrobe/test_build.py`

**Interfaces:**
- **Produces** (garment types in `BUILDERS`; recipe keys as listed; every type sets its faces through `Kind.add`):
  - `panels`: front and back panels hanging from under the belt to `hem`, `width` wide, over a hip row (the batch 0 tabard's lower part, factored out); `bones` 1–3 (rows: belt+`tuck`, hip, then `bones` evenly to `hem`); chains `<name>_front`, `<name>_back`; they hang clear of every part built before them (shells, boots, skirts, earlier panels). `tabard` = its painted upper part + `panels` with the recipe's `bones` (the watchman keeps 2).
  - `skirt`: panels may cross his front (0°) or back (180°): such a panel is built whole, centred, on a chain `<name>_front`/`<name>_back`; side panels stay mirrored (`<name>_l`/`<name>_r`). Chain names are derived so; the recipe's per-panel `chains` mapping goes (the watchman's stay `skirt_l`/`skirt_r`). `bones` 1 or 2.
  - `pauldron`: a plate cap over the shoulder, a grid of `rings` × 6 over the deltoid from the acromion out `reach` and down `drop`, `clearance` off what it goes `over`, its lower edge rolled (`roll`); wholly on `upperarm_l` (mirrored to `_r`). Trim notes: a bright rim, two painted lames.
  - `mittens` gains `cuff` (a flared gauntlet cuff ring over the sleeve end, 0 = none); `boots`' `cuff` may be 0 (no cuff).
  - `bracer`: a leather ring on one forearm (`bone`, `from`..`to` along it), over the sleeve by `thickness`; whole (not mirrored), wholly on its bone.
  - `sash`: a cloth band round the waist (it sets `kind.belt_ring` as a belt does, so props hang from it) and `tails` strips hanging from `at` degrees, each `length` long on a `bones`-bone chain `<name>_<n>`.
  - `prop` shapes gain `quiver` (a tapered box with bolt fletchings, its lower two thirds on a 1-bone chain `quiver`) and `knife` (a small sheath, rigid).
  - `fabrics.paint`: `WRAPPED` (bands wound on the diagonal, 3 cm apart), `HAIR` (grey strands along the growth direction, flowing down and back).

- [ ] **Step 1: Write the failing test** `case_types` in `test_build.py`: build a test recipe on the male body (one of each new type, plus a shell for them to go over) into a temporary `.blend`, then assert:

```python
chains = {c["chain"]: c for c in json.loads(scene["wardrobe_chains"])}
assert len(chains["mail_front"]["bones"]) == 2 and len(chains["coat_front"]["bones"]) == 3   # panels, 2 and 3 bones
assert {"test_front", "test_back", "test_l", "test_r"} <= set(chains) and len(chains["test_front"]["bones"]) == 1  # four-panel skirt
assert len(chains["sash_1"]["bones"]) == 3 and len(chains["sash_2"]["bones"]) == 3 and len(chains["quiver"]["bones"]) == 1
assert faces_on(outfit, "pauldron") <= {"upperarm_l", "upperarm_r"} and faces_on(outfit, "bracer") == {"lowerarm_l"}
assert validate.check(outfit, armature=arm, reference_joints=joints, cloth_bones=cloth, bare={"head", "hand"}) == []
```
(`faces_on(obj, part_name)` = the set of dominant bones of the part's vertices.)

- [ ] **Step 2: Run** `tools/wardrobe/wardrobe.sh test` — Expected: `FAIL types` (unknown garment types).
- [ ] **Step 3: Implement** the types. Pauldrons, bracers and quivers are built like the kettle hat: rings sampled from what they cover (`common.outer_hit`), pushed `clearance` out, never by cutting body regions.
- [ ] **Step 4: Run** `tools/wardrobe/wardrobe.sh test && tools/wardrobe/wardrobe.sh build watchman && tools/wardrobe/wardrobe.sh check watchman` — Expected: all PASS; the watchman unchanged (his tabard's panels still 2 bones, 1828 triangles).
- [ ] **Step 5: Commit** (with the go-ahead): `feat(wardrobe): panels, four-panel skirts, pauldrons, cuffs, bracers, sashes, quivers`

### Task 4: Headgear: the nasal helm, its mail curtain, the archer's hood

**Files:**
- Modify: `tools/wardrobe/build.py`, `tools/wardrobe/recipes.py`, `tools/wardrobe/check.py`, `tools/wardrobe/export.py`, `tests/wardrobe_test.gd`

**Interfaces:**
- **Consumes:** `build.chain_bones` (Task 1); the batch 0 `kettle`, `coif`, `cape_shell`, `enclose`, `ride`, `rigid`, `trunk_tree`.
- **Produces:**
  - `HEADGEAR["nasalhelm"]` — type `helm`: the kettle's bowl without a brim, its crown drawn up to a point (`point` 0.03 m), a raised brow band (`band` 0.028 m, iron, riveted), a nasal bar down the front (`nasal`: width 0.022, length 0.075, standing 0.008 proud); fitted over the head (`"over": "head"`), `clearance` 0.006, `slack` 0.009, `rest` 0.035; `metal` ["Head"]; `hides_hair` true, `allows_beard` true; ≤ 220 triangles.
  - `HEADGEAR["curtain"]` — type `curtain`: mail hanging from the helm's foot ring (tucked 4 mm inside it) round his sides and back (open ±40° at his face), 3 rings, `length_side` 0.15, `length_back` 0.19, laid `clear` 0.07 of his trunk; the top ring on Head, the middle ring half Head half `neck_01`, the lowest ring on `CAPE_BONES`; drawn from both sides; `metal` ["neck_01", "spine_03"]; ≤ 140 triangles.
  - `HEADGEAR["hood"]` — type `coif` with `fabric` "wool", `dye` true (colour = the archer's first dye), `thickness` 0.012, the coif's grid and opening, a shorter cape (`clear` 0.06, `length_front` 0.13, `length_side` 0.14), and `tail`: a tapering strip from the crown's back down `length` 0.32 on a 3-bone chain `hood_tail` under Head (`stiffness` 1.0, `drag` 0.5, `gravity` 1.0, `radius` 0.025); ≤ 280 triangles.
  - `check.fit` accepts `"over": "head"` (the surface under it is every `Head_` object in `heads.blend`) and a recipe `fit_rays` (`{"elevations": [...], "azimuths": [...]}`; default the crown fan of batch 0).

- [ ] **Step 1: Write the failing tests:**
  - pipeline: `tools/wardrobe/wardrobe.sh check headgear` must pass `fit` for the helm over every head, `encloses` for the hood, the budgets above;
  - Godot, in `_k13` style:

```gdscript
# K13b the curtain rides his head at its top and his neck and shoulders below
var top_on_head := _weights_where(&"curtain", func(p): return p.y > HELM_FOOT - 0.01).all(func(w): return w.keys() == [&"Head"])
var low_off_head := _weights_where(&"curtain", func(p): return p.y < HELM_FOOT - 0.12).all(func(w): return not w.has(&"Head"))
_check("K13b the curtain hangs from his helm and rides his neck below", top_on_head and low_off_head, "")
# K13c the hood's tail is its own chain under his head
var tail: Array = Wardrobe.headgear_data(&"hood").get("cloth", []).filter(func(c): return c.chain == "hood_tail")
_check("K13c the hood's tail swings on three bones under his head", tail.size() == 1 and tail[0].parent == "Head" and tail[0].bones.size() == 3, str(tail))
```
(`_weights_where(piece, pick) -> Array[Dictionary]` returns, for each vertex of the piece's GLB passing `pick`, `{bone name: weight}` of its non-zero weights; `HELM_FOOT` = the helm's `base_z`.)

- [ ] **Step 2: Run** `tools/wardrobe/wardrobe.sh check headgear` and the wardrobe suite — Expected: check refuses (no such pieces); K13b and K13c FAIL.
- [ ] **Step 3: Implement** the three pieces, `fit` over the head, and the export of the hood's chain and `dye_base`.
- [ ] **Step 4: Run** `tools/wardrobe/wardrobe.sh build headgear && … check headgear && … bake headgear && … export headgear`, then `$GODOT --headless --path . --import` and the wardrobe suite — Expected: all PASS; the watchman's coif and kettle hat unchanged in triangles (200, 240).
- [ ] **Step 5: Look** at `wardrobe.sh preview headgear --textured --at=1.72 --distance=0.8` and a culled Workbench render from behind (batch 0's `bow_render` approach): no head through a helm or hood, no gap between helm and curtain.
- [ ] **Step 6: Commit** (with the go-ahead): `feat(wardrobe): nasal helm, mail curtain, archer's hood`

### Task 5: The old face, parted hair and a full beard

**Files:**
- Modify: `tools/wardrobe/recipes.py` (`HEADS["old"]`, `HAIR`), `tools/wardrobe/build.py` (`build_hair`), `tools/wardrobe/bake.py` (`bake_hair`), `tools/wardrobe/export.py`, `tools/wardrobe/check.py`, `tests/wardrobe_test.gd`
- Create (generated): `assets/characters/wardrobe/source/hair.blend`, `assets/characters/wardrobe/hair/*`, `heads/old*`

**Interfaces:**
- **Produces:**
  - `HEADS["old"]`: the weathered head's recipe shape plus older pushes — cheeks sunken (−0.007), jowls dropped (0, 0, −0.005 at the jaw's sides), brow heavier; `eyes` 0.8; `grit` {"stubble": 0.35, "bags": 0.9, "lines": 1.0}; `brows` grey (0.62, 0.60, 0.57).
  - `HAIR = {"parted": {"from": "assets/characters/hair/Hair_SimpleParted.gltf", "kind": "hair", "tris": 180, "clearance": 0.004, "fit_rays": crown}, "full": {"from": "assets/characters/hair/Hair_Beard.gltf", "kind": "beard", "tris": 120, "clearance": 0.003, "fit_rays": jaw}}`: each imported, decimated to `tris` with symmetry, pushed out until it clears every head it can go on by `clearance` (the batch 0 `enclose` pass, over the heads' vertices under it), shaded smooth, weighted from the head (Head, neck_01), fabric `hair`, all faces dyed (mask R = 1).
  - `wardrobe.sh <verb> hair`: build, check (budgets from `part_limit`, `fit` over the head along its `fit_rays`, shading, weights), bake (greyscale `hair/<style>.png` and `_mask.png`), export (`hair/<style>.glb` + JSON per the contract).

- [ ] **Step 1: Write the failing test:**

```gdscript
# K18 hair and beard are worn and tinted his hair colour (the watchman, doctored bare-headed and old)
_doctor(&"watchman", {"faces": ["old"], "tones": ["light"], "hair": ["parted"], "beards": ["full"],
	"hair_colours": [[0.72, 0.70, 0.66]], "headgear": [[]]})
var old := await _guard(7)
var man = old._rig.man
Wardrobe.forget()
var hair := _worn(man, "Hair_parted")
var beard := _worn(man, "Beard_full")
var tinted: bool = hair != null and beard != null and hair.get_instance_shader_parameter(&"dye_colour").is_equal_approx(man.look.hair_colour) \
	and beard.get_instance_shader_parameter(&"dye_colour").is_equal_approx(man.look.hair_colour)
_check("K18 his hair and beard are worn and tinted his hair colour", "Head_old" in _worn_names(man) and tinted, str(_worn_names(man)))
```
- [ ] **Step 2: Run** the wardrobe suite and `tools/wardrobe/wardrobe.sh check heads` — Expected: K18 FAIL (no old face, no hair files); `check heads` passes (no old face yet to check).
- [ ] **Step 3: Implement** the Produces list.
- [ ] **Step 4: Run** `tools/wardrobe/wardrobe.sh build heads && … build hair && … check heads && … check hair && … bake heads && … bake hair && … export heads && … export hair`, the import, then the wardrobe suite — Expected: all PASS; the old head ≤ 450, parted ≤ 220, full ≤ 150 triangles.
- [ ] **Step 5: Look** at a textured preview of the old head with hair and beard (grey tint applied by hand in the preview): no scalp or chin through the shells.
- [ ] **Step 6: Commit** (with the go-ahead): `feat(wardrobe): the old face, parted hair and a full beard`

### Task 6: The swordsman

**Files:**
- Modify: `tools/wardrobe/recipes.py` (`SWORDSMAN`, `KINDS`), `tests/wardrobe_test.gd` (`DRESSED[&"swordsman"] = &"swordsman"`, K21, K22)
- Create (generated): `source/swordsman.blend`, `swordsman.glb/.png/_mask.png/.json`

**Interfaces:**
- **Consumes:** Tasks 1–4.
- **Produces** — `SWORDSMAN` (male, `base_tris` 1300, `bare` ["head"], belt `spine_01` 0.0), garments in this order:

| Name | Type | Fabric, colour (sRGB) | Key settings |
|---|---|---|---|
| sleeves | shell | quilted_linen (0.42, 0.40, 0.37) | regions lower; `sleeve_end` hand_l 0.0 less 0.016; thickness 0.02; lips sleeve |
| hose | shell | wool (0.24, 0.23, 0.22) | regions pelvis, thigh, calf; bottom calf_l 0.6; top spine_01 0.0; 0.006 |
| boots | boots | leather (0.24, 0.15, 0.09) | top calf_l 0.45; cuff 0.04; 0.012 |
| mail | shell | mail (0.36, 0.36, 0.38) | regions torso, pelvis, upper; bottom thigh_l 0.2; `sleeve_end` lowerarm_l 0.1; 0.022; smooth 8; lips sleeve, bottom; chest pad 0.01 |
| gauntlets | mittens | leather (0.22, 0.14, 0.08) | `cuff` 0.035 |
| mail_skirt | panels | mail (0.36, 0.36, 0.38) | width 0.36; hem calf_l 0.05; bones 2 |
| surcoat | tabard | wool (0.52, 0.09, 0.07), dye, stripe (0.86, 0.84, 0.78) | over mail; width 0.30; hem calf_l 0.25; bones 3 |
| belt | belt | leather (0.20, 0.12, 0.07) | as the watchman's |
| pauldron | pauldron | iron (0.30, 0.30, 0.32) | over mail; reach 0.14; drop 0.12; rings 3; clearance 0.012 |
| scabbard | prop | leather, iron fittings | as the watchman's |

  - `chains`: `mail_skirt_front/back` {stiffness 2.2, drag 0.9, gravity 1.6, radius 0.03}; `surcoat_front/back` {1.2, 0.6, 1.0, 0.03}.
  - `colliders`: thigh_l/r 0.09, calf_l/r 0.065, spine_01 0.16.
  - `metal`: ["spine_01", "spine_02", "spine_03", "pelvis", "upperarm_l", "upperarm_r"].
  - `options`: faces [weathered], tones [light, dark], hair [], beards [], headgear [["nasalhelm", "curtain"]], dye {colour (0.52, 0.09, 0.07), shift 0.02, fade [0, 0.3]}, grime [0.2, 0.9].

- [ ] **Step 1: Write the failing tests:** add `&"swordsman"` to `DRESSED` (every per-kind check now covers him: K1, K1c, K2, K3, K4, K5 through his own attacks, K6, K6b, K7, K8, K10 with silhouette key `nasalhelm`, K12), and:

```gdscript
# K9b steel rings on his chest, back and shoulders; not on his calves
_check("K9b a swordsman's mail and pauldrons ring", _rings(sw, &"spine_02") and _rings(sw, &"upperarm_l") and not _rings(sw, &"calf_l"), "")
# K21 (Review Focus 3) the surcoat never swings through the mail skirt
_check("K21 through a run, a stop and a kick his surcoat stays over his mail skirt", worst_behind <= 0.01, "%.3f m" % worst_behind)
# K22 (Review Focus 4) overhead, his pauldrons stay out of his head and curtain
_check("K22 his pauldrons clear his head through an overhead strike", nearest >= 0.10, "%.3f m" % nearest)
```
(`worst_behind`: over the run, stop and kick, the largest amount the `surcoat_front` hem marker (batch 0's `_watch` tips) sits behind the `mail_skirt_front` hem marker along +Z, his forward, in the pelvis frame. `nearest`: through an overhead strike driven as K5 drives its attacks, the least distance from the Head bone to any outfit vertex weighted ≥ 0.99 to `upperarm_l` or `upperarm_r` and resting above y = 1.42 (the pauldrons), CPU-skinned with batch 0's `_skinned`.)

- [ ] **Step 2: Run** the wardrobe suite — Expected: every swordsman check FAILs (no files).
- [ ] **Step 3: Build** — `tools/wardrobe/wardrobe.sh build swordsman && … check swordsman` — and fix what the rules report in the recipe or the builders, until `check swordsman` is clean.
- [ ] **Step 4: Bake, export, import:** `tools/wardrobe/wardrobe.sh bake swordsman && … export swordsman && $GODOT --headless --path . --import`.
- [ ] **Step 5: Run** the wardrobe suite — Expected: all PASS; his heaviest combination ≤ 3,000 triangles.
- [ ] **Step 6: Commit** (with the go-ahead): `feat(wardrobe): the swordsman`

### Task 7: The archer

**Files:**
- Modify: `tools/wardrobe/recipes.py` (`ARCHER`), `tests/wardrobe_test.gd` (`DRESSED[&"archer"] = &"archer"`, K16b)
- Create (generated): `source/archer.blend`, `archer.*`

**Interfaces:**
- **Produces** — `ARCHER` (male, `base_tris` 1300, `bare` ["head", "hand"]), garments in order:

| Name | Type | Fabric, colour | Key settings |
|---|---|---|---|
| tunic | shell | wool (0.20, 0.30, 0.14), dye | regions pelvis, upper, lower; bottom thigh_l 0.35; sleeves to the wrist; 0.008; lips sleeve, bottom |
| jerkin | shell | leather (0.26, 0.17, 0.10) | regions torso; 0.016; smooth 6 |
| hose | shell | wool (0.22, 0.20, 0.17) | regions pelvis, thigh, calf; bottom calf_l 0.6 |
| wraps | shell | wrapped (0.46, 0.41, 0.33) | regions calf; top calf_l 0.05; bottom calf_l 0.7; 0.01 |
| boots | boots | leather (0.26, 0.18, 0.11) | top calf_l 0.72; cuff 0; 0.008 |
| hands | mittens | skin (his skin) | `cuff` 0 |
| bracer | bracer | leather (0.22, 0.14, 0.08) | bone lowerarm_l; from 0.35 to 0.85 |
| belt | belt | leather (0.20, 0.12, 0.07) | buckle iron |
| pouch | prop | leather | at −110 |
| knife | prop | leather, iron | at 30 |
| quiver | prop | leather (0.30, 0.20, 0.12) | at 110; length 0.42 |

  - `chains`: `quiver` {stiffness 2.0, drag 0.8, gravity 1.2, radius 0.035}.
  - `colliders`: as the swordsman's. `metal`: [].
  - `options`: faces [weathered], tones [light, dark], headgear [["hood"]], dye {colours [(0.20, 0.30, 0.14), (0.34, 0.25, 0.15), (0.37, 0.37, 0.35)], shift 0.02, fade [0, 0.35]}, grime [0.3, 1.0].

- [ ] **Step 1: Write the failing tests:** add `&"archer"` to `DRESSED` (K10's silhouette key: `hood`), and:

```gdscript
# K16b a squad of archers wears more than one colour, hood and tunic alike
var dyes := {}
var matched := true
for s in range(1, 9):
	var a := await _guard(s, &"archer")
	var tunic: Color = a._rig.man.body.get_instance_shader_parameter(&"dye_colour")
	matched = matched and tunic.is_equal_approx(_worn(a._rig.man, "hood").get_instance_shader_parameter(&"dye_colour"))
	dyes[snappedf(tunic.h, 0.02)] = true
_check("K16b archers roll green, brown or grey, hood and tunic the same", dyes.size() >= 2 and matched, str(dyes.keys()))
```
- [ ] **Step 2: Run** the wardrobe suite — Expected: every archer check FAILs.
- [ ] **Steps 3–5:** as Task 6 (build, check clean, bake, export, import, suite all PASS; ≤ 3,000 triangles).
- [ ] **Step 6: Commit** (with the go-ahead): `feat(wardrobe): the archer`

### Task 8: The arms master

**Files:**
- Modify: `tools/wardrobe/recipes.py` (`ARMS_MASTER`), `tests/wardrobe_test.gd` (`DRESSED[&"arms_master"] = &"trainer"`)
- Create (generated): `source/arms_master.blend`, `arms_master.*`

**Interfaces:**
- **Produces** — `ARMS_MASTER` (male, `base_tris` 1300, `bare` ["head"]):

| Name | Type | Fabric, colour | Key settings |
|---|---|---|---|
| hose | shell | wool (0.20, 0.19, 0.18) | as the watchman's |
| boots | boots | leather (0.24, 0.16, 0.10) | top calf_l 0.82; cuff 0; 0.01 |
| doublet | shell | quilted_linen (0.62, 0.58, 0.50) | regions torso, pelvis, upper, lower; bottom thigh_l 0.05; sleeves to the wrist; 0.016; smooth 8; chest pad 0.008 |
| gloves | mittens | leather (0.30, 0.22, 0.15) | `cuff` 0.02 |
| collar | collar | quilted_linen (0.62, 0.58, 0.50) | on doublet; height 0.045; lean_in 0.25 (his bare neck's seam goes under it: §6.4, checked by `check heads`) |
| doublet_skirt | skirt | quilted_linen (0.62, 0.58, 0.50) | panels front [−40, 40], back [140, 220], left [45, 135]; hem thigh_l 0.35; bones 1 |
| sash | sash | wool (0.14, 0.12, 0.13) | height 0.07; tails 2 at 60°; length 0.35; bones 3 |
| scabbard | prop | leather, iron | at 100, from the sash |

  - `chains`: `doublet_skirt_front/back/l/r` {1.6, 0.7, 1.0, 0.03}; `sash_1`, `sash_2` {1.0, 0.5, 1.0, 0.025}.
  - `colliders`: as the swordsman's. `metal`: [].
  - `options`: faces [old], tones [light], hair [parted], beards [full], hair_colours [(0.72, 0.70, 0.66)], headgear [[]], no dye, grime [0.1, 0.3].

- [ ] **Step 1: Write the failing tests:** add `&"arms_master"` to `DRESSED`; his K10 silhouette key is `Hair_parted` and `Beard_full` worn, and K10 for him requires every seed to give the same face, hair and beard (he is one man). K7 for him: a severed head takes `Head_old`, `Hair_parted`, `Beard_full`. `tools/wardrobe/wardrobe.sh check heads` must pass the neck-seam rule for the old face under his collar.
- [ ] **Step 2: Run** the wardrobe suite — Expected: every arms master check FAILs.
- [ ] **Steps 3–5:** as Task 6.
- [ ] **Step 6: Commit** (with the go-ahead): `feat(wardrobe): the arms master`

### Task 9: The archetypes dress; mixed squads; per-kind fallbacks

**Files:**
- Modify: `scripts/AISystem/GuardFighter.gd` (only the three `look` dictionaries), `tests/wardrobe_test.gd`

**Interfaces:**
- **Produces:** `ARCHETYPES.swordsman.look.kind = &"swordsman"`, `archer.look.kind = &"archer"`, `trainer.look.kind = &"arms_master"`; their painted fields stay for the fallback (§10).

- [ ] **Step 1: Write the failing tests:**

```gdscript
# K1c (Review Focus 1) a mixed squad: shared within a kind, never across kinds
var squad := {}
for kind in DRESSED:
	squad[kind] = [await _guard(51, DRESSED[kind]), await _guard(52, DRESSED[kind])]
var within := squad.values().all(func(p): return p[0]._rig.man.body.mesh == p[1]._rig.man.body.mesh
	and p[0]._rig.man.body.get_surface_override_material(0) == p[1]._rig.man.body.get_surface_override_material(0))
var materials := squad.values().map(func(p): return p[0]._rig.man.body.get_surface_override_material(0))
_check("K1c every kind shares its own mesh and material, and no two kinds share one", within and _distinct(materials), "")
# K1b (Review Focus 2) one kind's files gone: that kind alone falls back to its own painted look
_doctor_missing(&"swordsman")
var sw := await _guard(53, &"swordsman")
var ar := await _guard(54, &"archer")
Wardrobe.forget()
_check("K1b a swordsman without files is painted, with his own helm; the archer still dresses",
	sw._rig.man.body.material_override is StandardMaterial3D and sw._rig.man.armour.any(func(a): return a.name == "nasalhelm")
	and ar._rig.man.body.name == "Outfit", "")
```
(`_distinct(list)` is true when no two entries are the same object.)

- [ ] **Step 2: Run** the wardrobe suite — Expected: K1c and the archetype guards FAIL (the three archetypes still paint).
- [ ] **Step 3: Implement:** the three `kind` keys (re-read `GuardFighter.gd` first; nothing else in it changes).
- [ ] **Step 4: Run** the wardrobe suite, then `squad_test gym_test combat_test duel_test exchange_test hunt_test` — Expected: all PASS (their checks that looked inside the old painted body are updated to the wardrobe equivalents with the reason noted, §9.2).
- [ ] **Step 5: Look:** `tests/visual/stage_guards.tscn` — every pose of every dressed kind, cropped per kind: no skin through clothes, no cloth through legs, no head through headgear.
- [ ] **Step 6: Commit** (with the go-ahead): `feat(wardrobe): swordsmen, archers and arms masters dress`

### Task 10: `stage_wardrobe` for four kinds and the look pass

**Files:**
- Modify: `tests/visual/stage_wardrobe.gd`; while tuning: `tools/wardrobe/recipes.py`, `fabrics.py`, `bake.py` constants

**Interfaces:**
- **Produces:** the stager takes `--kinds=watchman,swordsman,archer,arms_master` (default all dressed kinds); for each kind, in both sets (neutral and night by a torch): a lineup of four seeds beside its old painted self at 8 m, a before/after at 3.2 m, a turnaround at 2.2 m (0/45/90/180°), his face from under his headgear, and the close back shot; `sheet_<kind>.png` per kind plus `sheet.png` of the four lineups.

- [ ] **Step 1: Run** `perl -e 'alarm 480; exec @ARGV' $GODOT --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_wardrobe.tscn -- --out=<dir>` and view every sheet.
- [ ] **Step 2: Fix by eye** in the recipes and builders, in this order: silhouettes at 8 m at night (§4.1: each kind recognisable), layering and clipping, colours and dirt against the watchman (one world), headgear against its outfit (the user's batch 0 note: headgear must belong with the outfit). Re-run after each change; record each value you change and why in a comment beside it.
- [ ] **Step 3: Run** the wardrobe suite — Expected: all PASS.
- [ ] **Step 4: Send the user the sheets** (`SendUserFile`, display `render`): the four-kind lineup at night, each kind's before/after and turnaround. Ask for their batch 1 review.
- [ ] **Step 5: Commit** (with the go-ahead): `feat(wardrobe): stage_wardrobe for four kinds, tuned`

### Task 11: Full regression and hand-off

**Files:**
- Modify: `/Users/tinkertailorr/.claude/projects/-Users-tinkertailorr-a-world-of-darkness-alpha/memory/npc-ps2-look-project.md`

- [ ] **Step 1: Check syntax:** `$GODOT --headless --path . --check-only -s <script>` on every changed `.gd` file. Expected: no errors.
- [ ] **Step 2: Run** `tools/wardrobe/wardrobe.sh test` and every suite: arena, bodies, combat, duel, exchange, feel, gore, gym, hunt, interaction, life, polish, retro, smooth, sound, squad, stealth, sturdy, traversal, wardrobe. Expected: no `FAIL` lines; record the total (batch 0 ended at 397).
- [ ] **Step 3: Update memory:** the three kinds, the new garment types and headgear, the hair pipeline, the new checks, the counts, and "next: batch 2 (brute, duelist) after the user's review".
- [ ] **Step 4: Report to the user:** the suite results, the sheets, what tuning changed, and the proposed next step.
