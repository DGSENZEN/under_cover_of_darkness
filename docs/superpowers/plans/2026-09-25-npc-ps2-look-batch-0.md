# NPC PS2 Look, Batch 0 (Pipeline + Watchman): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Blender wardrobe pipeline and the Godot wardrobe path, and ship the complete PS2-style watchman (weathered face, kettle hat, mail coif), proven by checks K1–K12.

**Architecture:**
- **Blender side:** headless scripts in `tools/wardrobe/` turn a data recipe into a low-poly outfit `.blend`, bake PS2-style palettized textures with the light painted in, validate, and export GLB + PNG + JSON.
- **Godot side:**
  - `Wardrobe.gd` loads those parts, re-binds their skins to the game skeleton, rolls per-guard variety and makes shared shader materials;
  - `Humanoid.dress` assembles a guard;
  - `Cloth.gd` swings the cloth bones;
  - small hooks in `GuardRig`, `Guard` and `Humanoid` keep dismemberment, hit flash and armour sounds working.

**Tech Stack:** Godot 4.5.1 (GDScript, Forward+), Blender 5.2.2 LTS (bpy, bmesh, numpy, Cycles on Metal), Python 3.

**Spec:** `docs/superpowers/specs/2026-09-25-npc-ps2-look-design.md` (cited below as §n).

## Global Constraints

- **Binaries:** `$GODOT` = `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot` (4.5.1). `$BLENDER` = `/Applications/Blender.app/Contents/MacOS/Blender` (5.2.2 LTS).
- **Triangles:** at most 3,000 per NPC over every worn mesh, weapon excluded. Targets: outfit ~2,000, head ~400, hair, beard and headgear ~600 (§5).
- **Textures:**
  - outfit albedo and mask 256×256; head 128×128 per face and tone; headgear 128×128;
  - at most 64 colours per albedo;
  - no normal, roughness or metallic maps (§5).
- **Shading:**
  - per pixel, with `diffuse_lambert_wrap` and `specular_disabled`, shadows on;
  - per-vertex lighting is forbidden: it ignores omni-light shadows (§2);
  - sampling is `filter_nearest_mipmap`, set in the shader, because Retro only converts `BaseMaterial3D`s.
- **Rig:**
  - at most 4 influences per vertex;
  - every game-bone joint within 1 mm of the Quaternius skeleton;
  - cloth bones named `cloth_<chain>_<n>` (§6.3, §6.7);
  - every worn mesh on `Layers.ACTORS`;
  - skeleton modifier order: Posture → Ragdoll → Cloth → Severed (§7.4).
- **Scope:**
  - looks only: no rule, AI or animation changes;
  - your arms (`ViewArms`, `build(&"player")`, `Boots_Male.glb`) are untouched;
  - the swordsman, duelist, brute, archer and arms master keep the painted path in this batch.
- **Blender:**
  - headless only in this batch: the interactive Blender may be in use by the HEMA session;
  - scenes are named `AUCOD_*`;
  - a backup before every write;
  - never export the Quaternius eyes or eyebrows;
  - `.gdignore` in `source/`.
- **Shared files:** other sessions are editing `Humanoid.gd`, `GuardRig.gd` and `Guard.gd`.
  - re-read each one right before editing it;
  - find code by function name, not line number;
  - keep the hooks small and never rewrite a whole file.
- **Running suites:** `$GODOT --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/<suite>.tscn`. Run `$GODOT --headless --path . --check-only -s <script>` on each changed script first, because a parse error hangs a run.
- **Godot gotcha (from the bodies work):** skeleton modifiers' results are restored after the skin update. So `get_bone_global_pose` read from a test or a script returns the pose before Posture, Ragdoll or Cloth. Read simulated positions through `BoneAttachment3D` nodes, which do follow the modifiers.
- **Git:** nothing is committed without the user's go-ahead. Ask once before Task 1; if the answer is no, skip every commit step.

## Data contracts

These are shared by Tasks 3–9. Positions are in glTF/Godot model space (Y up, the model faces +Z), in metres.

**Kind JSON (`assets/characters/wardrobe/<kind>.json`):**

```json
{"kind": "watchman", "body": "male", "triangles": 1980,
 "cloth": [{"chain": "skirt_front", "parent": "pelvis", "bones": ["cloth_skirt_front_1", "cloth_skirt_front_2"],
            "tip": 0.14, "stiffness": 1.0, "drag": 0.4, "gravity": 1.0, "radius": 0.03}],
 "colliders": [{"bone": "thigh_l", "radius": 0.085, "height": 0.42}],
 "metal": [],
 "skin_tones": {"light": [1.0, 1.0, 1.0], "dark": [0.55, 0.42, 0.35]},
 "probe": [{"rest": [0.11, 1.32, 0.12], "near_body": [0.1, 1.31, 0.09]}],
 "options": {"faces": ["weathered"], "tones": ["light", "dark"], "hair": [], "beards": [],
             "headgear": [["kettlehat", "coif"]],
             "dye": {"colour": [0.62, 0.52, 0.16], "shift": 0.04, "fade": [0.0, 0.35]},
             "grime": [0.2, 0.8]}}
```

**Head JSON (`heads/<face>.json`):** `{"face": "weathered", "body": "male", "triangles": 400}`. Textures are `heads/<face>_<tone>.png`.

**Headgear JSON (`headgear/<piece>.json`):**
- Common keys: `{"piece", "triangles", "rigid", "bone", "offset", "metal", "hides_hair", "allows_beard", "cloth", "colliders"}`.
- Coif: rigid false, `metal` = ["neck_01", "Head"], `hides_hair` true, `allows_beard` true.
- Kettle hat: rigid true, `bone` "Head", `offset` = 12 floats (basis x, y, z, then origin, in the bone's space), `metal` [], `hides_hair` false.

**GLBs:**
- mesh and skeleton only, no textures;
- material slot names `WR_closed` (culls back faces) and `WR_strips` (drawn from both sides);
- the `.import` files set `meshes/generate_lods=false` and `meshes/ensure_tangents=false`.

**Outfit face attributes (Blender, between build, bake and validate):**

| Attribute | Type | Meaning |
|---|---|---|
| `wr_fabric` | int | index into `recipes.FABRICS` |
| `wr_part` | int | 0 = body skin, n = garment n |
| `wr_thickness` | float, metres | the garment's thickness |
| `wr_strip` | bool | the face is on a cloth strip |
| `wr_dye` | bool | the face is in the dye region |

## Review Focus

Five situations the spec implies but no K check covers, each with the test that now pins it:

1. **Cloth during hit-stop or slow motion** (TimeFx drops `Engine.time_scale` to ~0.05). Expected: the cloth slows with the game and never jumps when time resumes. Test: **K4b** in Task 8.
2. **A dressed guard kicked down and getting up.** Expected: the skirts follow him with no whip and no NaN. Test: **K6b** in Task 8.
3. **Partial wardrobe files.** Expected: if one of the kind's own files is missing, the guard spawns painted, with a warning; if an option names a missing head or headgear piece, that option is dropped, with a warning, and the guard still dresses. Test: **K1b** in Task 7.
4. **A squad of dressed guards.** Expected: they share one outfit Mesh, Skin and material, and only instance uniforms differ. Test: **K1c** in Task 7.
5. **A severed limb or head from a dressed guard.** Expected: it keeps that guard's dye, fade, skin tone and grime. Test: **K7b** in Task 9.

---

### Task 1: Wardrobe core: skin re-binding and added bones

**Files:**
- Create: `scripts/Visual/Wardrobe.gd` (extends RefCounted, static functions, loaded via `preload` like the other scripts; no `class_name`)
- Create: `tests/wardrobe_test.gd`, `tests/wardrobe_test.tscn` (a single Node3D root with the script, like `tests/retro_test.tscn`)

**Interfaces:**
- **Produces:**
  - `Wardrobe.rebind(skin: Skin, source: Skeleton3D, target: Skeleton3D) -> Skin`:
    - returns a new Skin with one named bind per source bind;
    - the bind pose is `target.get_bone_global_rest(t).affine_inverse() * source.get_bone_global_rest(s) * skin.get_bind_pose(i)` (§7.2);
    - the name is `skin.get_bind_name(i)`, or the source bone's name if that is empty;
    - a bone missing from `target` is reported with `push_error`, and its bind is placed on `root`.
  - `Wardrobe.add_bones(target: Skeleton3D, source: Skeleton3D, names: PackedStringArray) -> void`:
    - adds each missing bone in the given order, parents first, under its source parent found by name;
    - local rest is `target_global_rest(parent)⁻¹ · source_global_rest(bone)`, and the pose equals the rest.
  - `wardrobe_test.gd`'s harness: `_check(name: String, ok: bool, detail: String)`, `_frames(n)`, and results printed after `==== RESULTS ====`, as in `tests/retro_test.gd`.

- [ ] **Step 1: Write the failing test K3a** (synthetic re-binding; the spec's K3 comes in Task 6).

The test uses these helpers:
- `_game_skeleton()` instantiates `Superhero_Male_FullBody.gltf` under the test and returns its Skeleton3D.
- `_twisted_copy(sk)` returns a new Skeleton3D where:
  - every bone keeps its joint position but its global rest is rotated 37° about (1, 1, 0) normalized;
  - one extra bone `cloth_test_1` hangs under `pelvis`, 0.3 m down and 0.12 m forward.
- `_probe_mesh(src, bones)` returns an ArrayMesh and Skin: one small triangle 5 cm off each bone's joint, weight 1 on that bone, bind = the source global rest⁻¹.

```gdscript
# K3a a skin built on twisted bone frames lands exactly on the game skeleton
var target := _game_skeleton()
var source := _twisted_copy(target)
var made := _probe_mesh(source, [&"lowerarm_r", &"spine_02", &"cloth_test_1"])
Wardrobe.add_bones(target, source, PackedStringArray(["cloth_test_1"]))
var mi := MeshInstance3D.new()
mi.mesh = made[0]
mi.skin = Wardrobe.rebind(made[1], source, target)
target.add_child(mi)
mi.skeleton = NodePath("..")
await _frames(2)
var rest_err := _max_error(mi.bake_mesh_from_current_skeleton_pose(), made[0])      # every vertex vs its original
var arm := target.find_bone(&"lowerarm_r")
target.set_bone_pose_rotation(arm, target.get_bone_pose_rotation(arm) * Quaternion(Vector3.RIGHT, deg_to_rad(60)))
await _frames(2)
var pose_err := _max_error_moved(mi, target, arm)   # forearm triangle vs pose(arm)·rest(arm)⁻¹·v
var cloth := target.find_bone(&"cloth_test_1")
var bone_err := (target.get_bone_global_rest(cloth).origin - source.get_bone_global_rest(source.find_bone(&"cloth_test_1")).origin).length()
_check("K3a re-binding: twisted frames land exact, at rest and posed", rest_err <= 1e-4 and pose_err <= 1e-4 and bone_err <= 1e-5,
	"rest %.6f pose %.6f bone %.6f" % [rest_err, pose_err, bone_err])
```

- [ ] **Step 2: Run it and see it fail.** Run `$GODOT --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/wardrobe_test.tscn 2>&1 | grep -E "PASS|FAIL|ERROR"`. Expected: a parse error, "Could not preload resource … Wardrobe.gd".
- [ ] **Step 3: Implement `rebind` and `add_bones`** in `scripts/Visual/Wardrobe.gd`, with a header comment in the house style (see `Humanoid.gd`).
- [ ] **Step 4: Run it again.** Expected: `PASS  K3a …`.
- [ ] **Step 5: Commit** (only with the go-ahead): `git add scripts/Visual/Wardrobe.gd tests/wardrobe_test.* && git commit -m "feat(wardrobe): skin re-binding to the game skeleton"`

### Task 2: Variety roll and the wardrobe shader

**Files:**
- Modify: `scripts/Visual/Wardrobe.gd`
- Create: `scripts/Visual/wardrobe.gdshaderinc`, `scripts/Visual/wardrobe.gdshader` (`render_mode diffuse_lambert_wrap, specular_disabled`, default culling), `scripts/Visual/wardrobe_two_sided.gdshader` (the same modes plus `cull_disabled`, and `NORMAL = FRONT_FACING ? NORMAL : -NORMAL`); both include the `.gdshaderinc`
- Test: `tests/wardrobe_test.gd`

**Interfaces:**
- **Produces:**
  - `Wardrobe.roll(options: Dictionary, skin_tones: Dictionary, seed: int) -> Dictionary`. It is pure, with no file access, and returns `{face: StringName, tone: StringName, hair: StringName, beard: StringName, headgear: Array[StringName], dye: Color, fade: float, grime: float, height: float, skin: Color}`.
    - A `RandomNumberGenerator` seeded with `seed` takes exactly nine draws, always, in this order: face, tone, hair, beard, headgear set, dye shift, fade, grime, height.
    - An empty list yields `&""`, but its draw is still taken, so a new option never reshuffles other guards.
    - `dye` is built from the HSV of `options.dye.colour`, with `u = draw * 2 - 1`: `Color.from_hsv(wrapf(h + u * shift, 0, 1), s, clampf(v * (1 + 2 * u * shift), 0, 1))`.
    - `fade`, `grime` = lerp over their ranges; `height` = `1 + (draw * 2 - 1) * 0.03`; `skin` = `skin_tones[tone]` as a Color (white if missing).
    - Hair rules (headgear that hides hair) are applied by `Humanoid.dress`, not here.
  - `Wardrobe.material(albedo: Texture2D, mask: Texture2D, two_sided: bool, dye_base: Color) -> ShaderMaterial`. It is cached per argument set. A null mask uses a shared 1×1 black texture.
  - `Wardrobe.apply_look(mesh: GeometryInstance3D, look: Dictionary) -> void` sets the instance uniforms `dye_colour` (vec3), `dye_fade`, `skin_tone` (vec3) and `grime`.
  - Shader uniforms:
    - `albedo`: source_color, filter_nearest_mipmap, repeat_disable;
    - `mask`: filter_nearest_mipmap, repeat_disable;
    - `dye_base`: vec3;
    - instance uniforms with defaults: `dye_colour` 1, `dye_fade` 0, `skin_tone` 1, `grime` 0.
- **Fragment**, the one algorithm the uniforms don't fix (`LUMA` = vec3(0.299, 0.587, 0.114)):

```glsl
vec3 c = texture(albedo, UV).rgb;
vec3 m = texture(mask, UV).rgb;
vec3 dyed = dye_colour * (dot(c, LUMA) / max(dot(dye_base, LUMA), 0.001));
dyed = mix(dyed, vec3(dot(dyed, LUMA)), dye_fade);
c = mix(c, dyed, m.r);
c = mix(c, c * skin_tone, m.g);
c = mix(c, vec3(dot(c, LUMA)) * vec3(0.52, 0.46, 0.38), clamp(m.b * grime, 0.0, 1.0) * 0.6);
ALBEDO = c; ROUGHNESS = 1.0; METALLIC = 0.0;
```

- [ ] **Step 1: Write the failing test K10a.**

```gdscript
# K10a the roll: same seed same look, ranges held, new options never reshuffle
var o := {"faces": [&"weathered"], "tones": [&"light", &"dark"], "hair": [], "beards": [],
	"headgear": [[&"kettlehat", &"coif"]], "dye": {"colour": [0.62, 0.52, 0.16], "shift": 0.04, "fade": [0.0, 0.35]},
	"grime": [0.2, 0.8]}
var tones := {"light": [1.0, 1.0, 1.0], "dark": [0.55, 0.42, 0.35]}
var same := str(Wardrobe.roll(o, tones, 7)) == str(Wardrobe.roll(o, tones, 7))
var seen := {}
var ranged := true
var steady := true
var o2 := o.duplicate(true)
o2["faces"] = [&"weathered", &"old"]
for s in range(1, 9):
	var r := Wardrobe.roll(o, tones, s)
	seen[str(r)] = true
	ranged = ranged and r.fade >= 0.0 and r.fade <= 0.35 and r.grime >= 0.2 and r.grime <= 0.8 \
		and r.height >= 0.97 and r.height <= 1.03 and r.tone in [&"light", &"dark"]
	steady = steady and is_equal_approx(Wardrobe.roll(o2, tones, s).grime, r.grime)
var mat := Wardrobe.material(load("res://icon.svg"), null, false, Color(0.62, 0.52, 0.16))
var names := mat.shader.get_shader_uniform_list().map(func(u): return u.name)
_check("K10a the variety roll is repeatable, ranged and stable; the shader has its uniforms",
	same and seen.size() >= 2 and ranged and steady and "albedo" in names and "mask" in names and "dye_base" in names,
	"same %s distinct %d ranged %s steady %s uniforms %s" % [same, seen.size(), ranged, steady, names])
```

- [ ] **Step 2: Run it.** Expected: `FAIL K10a` or a parse error on `Wardrobe.roll`.
- [ ] **Step 3: Implement** `roll`, `material`, `apply_look` and the three shader files.
- [ ] **Step 4: Run it.** Expected: K3a and K10a PASS, and no shader compile errors in the log.
- [ ] **Step 5: Commit** (with the go-ahead): `feat(wardrobe): variety roll and PS2 wardrobe shader`

### Task 3: Export validation (Blender, test first)

**Files:**
- Create: `tools/wardrobe/common.py`, `tools/wardrobe/validate.py`, `tools/wardrobe/test_validate.py`, `tools/wardrobe/wardrobe.sh` (executable)

**Interfaces:**
- **Produces (`common.py`):**
  - constants: `ROOT` (repo root, from `__file__`), `WARDROBE = ROOT/"assets/characters/wardrobe"`, `SOURCE = WARDROBE/"source"`, `QUATERNIUS = {"male": …/Superhero_Male_FullBody.gltf, "female": …/Superhero_Female_FullBody.gltf}`, `PALETTE = 64`, `NPC_BUDGET = 3000`, `MARGIN = 0.005`;
  - `tri_count(obj) -> int`;
  - `import_quaternius(body: str) -> tuple[Object, Object, list[Object]]`: armature, body mesh, and [eyes, brows], imported with the glTF importer's default settings (the boots' round trip kept the bone frames exact);
  - `joints(armature) -> dict[str, tuple[float, float, float]]`: bone heads in armature space.
- **Produces (`validate.py`):**
  - `check(mesh, *, armature=None, reference_joints=None, cloth_bones=(), images=(), palette=64, combined_tris=None, budget=3000) -> list[str]`.
  - `images` is a list of `(path, (w, h), palettized: bool)`.
  - Each message starts with its rule id: `budget:`, `influences:`, `unweighted:`, `bone:`, `uv:`, `texture:`, `palette:`, `joint:` or `hidden:`.
  - The `hidden:` rule reads the face attributes `wr_part` and `wr_thickness`. A body face is under a garment if a ray from its centre along its normal hits a garment face within that garment's thickness + `MARGIN`.
- **Produces (`wardrobe.sh <build|bake|export|check|preview|test> <target> [--force]`):**
  - `test` runs `$BLENDER -b --factory-startup --python tools/wardrobe/test_validate.py`;
  - every other verb runs `$BLENDER -b <source file if it exists> --python tools/wardrobe/<verb>.py -- <target> [--force]`;
  - it exits non-zero on failure.

- [ ] **Step 1: Write the failing test** `test_validate.py`.
  - It builds one tiny scene per case, and asserts that exactly one message comes back, with that case's prefix:
    - `budget`: a 3,010-triangle mesh, with `combined_tris=3010`;
    - `influences`: a vertex in 5 groups;
    - `unweighted`: a vertex in no group;
    - `bone`: a group named `not_a_bone`;
    - `uv`: a UV at (1.2, 0.5);
    - `texture`: a 300×300 image where 256×256 is expected;
    - `palette`: a 256×256 image with 100 colours;
    - `joint`: an armature whose `pelvis` sits 2 mm off the reference;
    - `hidden`: a body quad 1 cm under a garment quad of thickness 0.006.
  - A `clean` case must return `[]`.
  - It prints `PASS <case>` / `FAIL <case>: <messages>` and calls `sys.exit(1)` on any failure.
- [ ] **Step 2: Run** `tools/wardrobe/wardrobe.sh test`. Expected: exit 1 (ImportError: `validate`).
- [ ] **Step 3: Implement** `common.py` (only the parts above), `validate.check` and `wardrobe.sh`.
- [ ] **Step 4: Run** `tools/wardrobe/wardrobe.sh test`. Expected: 10 `PASS` lines and exit 0.
- [ ] **Step 5: Commit** (with the go-ahead): `feat(wardrobe): export validation rules and runner`

### Task 4: Build the watchman outfit

**Files:**
- Create: `tools/wardrobe/recipes.py`, `tools/wardrobe/build.py`, `tools/wardrobe/preview.py`, `assets/characters/wardrobe/source/.gdignore`
- Modify: `tools/wardrobe/common.py` (geometry helpers)
- Modify: `.gitignore` (add `assets/characters/wardrobe/source/backup/`)

**Interfaces:**
- **Consumes:** `common.import_quaternius` and `validate.check` (Task 3).
- **Produces: `recipes.py`,** pure data with no bpy:
  - `FABRICS`: an ordered list of fabric names — `quilted_linen`, `wool`, `leather`, `mail`, `iron`, `skin`.
  - `WATCHMAN`, following §8. Its values are:
    - colours from the old painter: gambeson (0.36, 0.29, 0.20); tabard (0.62, 0.52, 0.16) as the dye with a (0.08, 0.08, 0.08) stripe; hose (0.20, 0.19, 0.18); boots (0.24, 0.15, 0.09); gloves (0.20, 0.13, 0.08); belt (0.20, 0.12, 0.07);
    - thicknesses: gambeson 0.03 (+0.015 chest, +0.01 belly); hose 0.006; leather 0.01;
    - the skirt: hem at mid-thigh, flare 1.35, 4 panels × 2 bones;
    - the tabard: front and back, 0.34 m wide, swinging below the belt, hem at the knee, 2 bones each;
    - props: belt with buckle, a pouch on the right hip, a key ring front left, a scabbard on the left hip at 20° back;
    - chains: stiffness 1.0, drag 0.4, gravity 1.0, radius 0.03;
    - colliders: thighs r 0.085, calves r 0.06, spine_01 r 0.15;
    - `metal` []; `options` as in the Data contracts.
  - Heights are given as `(bone, fraction along it)`, for example the skirt hem at `("thigh_l", 0.5)`, so recipes carry over to the female body in batch 2.
- **Produces: `build.py <kind> [--force]`** saves `source/<kind>.blend` with:
  - scene `AUCOD_<kind>`;
  - `Armature`: the game bones plus the cloth bones;
  - `Outfit`: one mesh with the face attributes from the Data contracts, an Armature modifier, and material slots `WR_closed`/`WR_strips` chosen by `wr_strip`;
  - `Reference`: the full-resolution body, hidden, never exported;
  - `scene["wardrobe_hash"]`: a hash of the generated mesh data;
  - `scene["wardrobe_probe"]`: 8 probe vertices on non-cloth parts (chest, back, each upper arm, forearm and thigh), with their rest and nearest-`Reference` positions converted to glTF space.
- **Produces: `common.py` steps** (§6.3):
  - `low_poly_base(body, target_tris)`, `mittens(base, armature)`;
  - `shell(base, regions, span, thickness, pad)`, `loft(rings, closed)`, `skirt(…)`, `panels(…)`, `ring(…)`, `prop(…)`;
  - `delete_hidden(base, garments, margin=MARGIN) -> int`;
  - `copy_weights(target, reference)`: Data Transfer `POLYINTERP_NEAREST`, limited to 4, normalized;
  - `add_chain(armature, chain, parent, points) -> list[str]`, `weight_strip(obj, faces, bones, parent)`;
  - `unwrap(obj, size, density)`;
  - `backup(path)`: a timestamped copy into `source/backup/`.
- **Produces: `preview.py <target>`** renders front, three-quarter, side and back views to `--out` (default the scratchpad). It uses Workbench with flat fabric colours before baking, and the textures after.

- [ ] **Step 1: See it fail.** `tools/wardrobe/wardrobe.sh check watchman`. Expected: "no source/watchman.blend".
- [ ] **Step 2: Implement** the recipe, `build.py`, the `common.py` steps and `preview.py`.
- [ ] **Step 3: Build.** `tools/wardrobe/wardrobe.sh build watchman`. Expected: the file is saved and `Outfit` prints ≤ 2,100 triangles.
- [ ] **Step 4: Check.** `tools/wardrobe/wardrobe.sh check watchman` runs the geometry rules, with `combined_tris` = outfit + 1,000 until the head and headgear exist. Expected: no messages.
- [ ] **Step 5: The hand-edit guard.**
  - Move one `Outfit` vertex 1 cm with `$BLENDER -b source/watchman.blend --python-expr "…; bpy.ops.wm.save_mainfile()"`.
  - Then `wardrobe.sh build watchman`. Expected: it refuses with "edited by hand since the last build; use --force".
  - Then run with `--force`. Expected: it rebuilds and writes a backup.
- [ ] **Step 6: Preview.** `tools/wardrobe/wardrobe.sh preview watchman`. Look at the PNGs; expected:
  - a flared skirt, the tabard and the belt kit;
  - no body showing except the mittens at the wrists;
  - no garment through another at rest.
- [ ] **Step 7: Commit** (with the go-ahead): `feat(wardrobe): recipe-driven low-poly watchman build`

### Task 5: Build the weathered head, kettle hat and coif

**Files:**
- Modify: `tools/wardrobe/recipes.py` (`HEADS["weathered"]`, `HEADGEAR["kettlehat"]`, `HEADGEAR["coif"]`), `tools/wardrobe/build.py` (targets `heads`, `headgear`), `tools/wardrobe/common.py` (head helpers)

**Interfaces:**
- **Produces: `source/heads.blend`** (`AUCOD_heads`):
  - `Head_weathered`: ~400 triangles, eye sockets closed, skinned to Head, neck_01 and spine_03, running from the crown down to the collar line;
  - `High_weathered`: the Quaternius head region, eyes and brows, hidden, used only for the bake;
  - both deformed by the same lattice `recipes.HEADS["weathered"]["lattice"]`: hollower cheeks, heavier brow.
- **Produces: `source/headgear.blend`** (`AUCOD_headgear`):
  - `Gear_kettlehat`: from `assets/armour/kettlehat.glb` (266 triangles), unwrapped into one 128 atlas, scaled so its inside clears the coif, origin at the Head bone. `offset` goes to its JSON.
  - `Gear_coif`: skinned, at most 200 triangles, `mail`. It is a shell of the low head 1.5 cm out, open from brow to chin, plus a short shoulder cape weighted to spine_03 and the clavicles.
- **Produces: `common.py`:** `extract_head(body, eyes, brows) -> tuple[Object, Object]` (high, low), `close_sockets(low)`, `face_lattice(objs, shape: dict)`.

- [ ] **Step 1: See it fail.** `tools/wardrobe/wardrobe.sh check heads`. Expected: "no source/heads.blend".
- [ ] **Step 2: Implement** the recipes, targets and helpers.
- [ ] **Step 3: Build** with `wardrobe.sh build heads` and `wardrobe.sh build headgear`, then run `check` on each. Expected:
  - the head ≤ 450, the coif ≤ 200 and the kettle hat 266 triangles;
  - outfit + head + hat + coif ≤ 3,000;
  - the head's lowest ring sits below the top of the outfit's collar.
- [ ] **Step 4: Preview** with `wardrobe.sh preview heads` and `wardrobe.sh preview watchman --with heads,headgear`. Expected:
  - the coif frames the face;
  - the kettle hat sits on the coif with no mail showing through its crown;
  - the collar hides the neck seam.
- [ ] **Step 5: Commit** (with the go-ahead): `feat(wardrobe): weathered head, kettle hat and coif`

### Task 6: Bake and export the watchman, the head and the headgear

**Files:**
- Create: `tools/wardrobe/fabrics.py` (node groups `quilted_linen`, `wool`, `leather`, `mail`, `iron`; a `grime` group; `sky_world()`), `tools/wardrobe/bake.py`, `tools/wardrobe/export.py`
- Output: `assets/characters/wardrobe/watchman.{glb,png,json}` and `watchman_mask.png`; `heads/weathered.{glb,json}` and `weathered_{light,dark}.png`; `headgear/{kettlehat,coif}.{glb,png,json}`; a `.import` beside each GLB
- Test: `tests/wardrobe_test.gd`

**Interfaces:**
- **Consumes:** the face attributes and scene properties from Tasks 4–5, and `validate.check`.
- **Produces:** the files in the Data contracts. `export.py` refuses to write anything when `validate.check` returns messages, and prints them all.
- **Bake**, the algorithm decided here:
  - **Passes:** a colour-only DIFFUSE pass (albedo), AO (distance 0.3 m, 64 samples) and a world-space NORMAL pass at rest. Each is baked at 4× size (1024 outfit, 512 head and headgear), box-downsampled, with a 2 px margin.
  - **Lit albedo:** `lit = albedo × (0.35 + 0.65·ao) × (0.78 + 0.22·n_z)`, in linear space, then converted to sRGB.
  - **Head:** the albedo is a selected-to-active bake from `High_weathered` (cage 0.01 m), once with `T_Superhero_Male_Ligh.png` and once with `…_Dark.png` as the skin. The grit layer comes after: stubble on the jaw, chin and upper lip; eye bags; lines; a scar on the left cheek. It is mixed through position masks baked as EMIT passes.
  - **Mask:** EMIT bakes, with R = `wr_dye` faces, G = `skin` fabric and B = the grime pattern (dirt rising from hems and boots, plus AO creases).
  - **Palette:** numpy k-means with `PALETTE` clusters, 12 iterations and a fixed seed, on the lit sRGB albedo. The mask is never palettized.
  - **Dark skin multiplier:** the per-channel mean of `T_Superhero_Male_Dark` divided by that of `T_Superhero_Male_Ligh`, over skin pixels, written to the JSON as `skin_tones.dark`.
- **Export:**
  - `export_scene.gltf(export_format='GLB', use_selection=True, export_materials='PLACEHOLDER', export_animations=False, export_skins=True, export_def_bones=True, export_yup=True)`. `Reference` and `High_*` are never selected.
  - The JSON's `cloth` and `colliders` come from `recipes.py`, so cloth tuning only needs a re-export.
  - It writes each `.import` only when it is missing: `Boots_Male.glb.import`'s params with `meshes/generate_lods=false` and `meshes/ensure_tangents=false`.
  - It adds an `export.py` text block to each `.blend` (the Export button, §6.6).

- [ ] **Step 1: Write the failing tests K2a and K3.**

```gdscript
# K2a the files keep the PS2 budgets
var sizes := {"watchman": 256, "watchman_mask": 256, "heads/weathered_light": 128, "heads/weathered_dark": 128,
	"headgear/kettlehat": 128, "headgear/coif": 128}
var ok := true
var why := []
for f in sizes:
	var img: Image = (load(Wardrobe.ROOT + f + ".png") as Texture2D).get_image()
	var colours := _colour_count(img)          # distinct RGB values
	var fits: bool = img.get_width() == sizes[f] and img.get_height() == sizes[f] and (f.ends_with("_mask") or colours <= 64)
	ok = ok and fits
	why.append("%s %dx%d %d" % [f, img.get_width(), img.get_height(), colours])
var tris := int(Wardrobe.kind_data(&"watchman").triangles) + int(Wardrobe.head_data(&"weathered").triangles) \
	+ int(Wardrobe.headgear_data(&"kettlehat").triangles) + int(Wardrobe.headgear_data(&"coif").triangles)
_check("K2a baked parts: 256/128 textures, at most 64 colours, at most 3,000 triangles", ok and tris <= 3000, "%s tris %d" % [why, tris])

# K3 (spec K3, male body) the exported watchman re-binds exactly onto the game skeleton
# _probe_errors(): for each probe, rest_err = baked vertex nearest `rest` at rest; pose_err = change in
# its distance to the nearest reference-body vertex to `near_body` after show_pose(&"Sword_Attack", 0.3) on both
var errs := await _probe_errors(&"watchman")
_check("K3 exported watchman: probes within 1 mm at rest, within 3 cm of the body mid-swing",
	errs.rest <= 0.001 and errs.pose <= 0.03, "rest %.4f pose %.4f over %d probes" % [errs.rest, errs.pose, errs.count])
```

- [ ] **Step 2: Run it.** Expected: `FAIL` for K2a and K3 (files missing), or a parse error on `Wardrobe.ROOT`/`kind_data`, which Task 7 defines. Add stubs now: `static var ROOT := "res://assets/characters/wardrobe/"` and the three `*_data` JSON readers. They are specified in Task 7.
- [ ] **Step 3: Implement** `fabrics.py`, `bake.py` and `export.py`.
- [ ] **Step 4: Bake and export.** Run `wardrobe.sh bake all && wardrobe.sh export all`, then `$GODOT --headless --path . --import`. Expected: validation prints no messages, and Godot prints no import errors.
- [ ] **Step 5: Run the suite.** Expected: K3a, K10a, K2a and K3 all PASS.
- [ ] **Step 6: Look at the textures.** Copy each PNG scaled ×4 with nearest filtering into the scratchpad, then run `wardrobe.sh preview watchman --with heads,headgear` with textures. Judge the quilting, dirt and face paint by eye, and fix obvious errors (flipped UV islands, black seams) before moving on.
- [ ] **Step 7: Commit** (with the go-ahead): `feat(wardrobe): PS2 bake and export for the watchman parts`

### Task 7: `Humanoid.dress` and the guard hooks

**Files:**
- Modify: `scripts/Visual/Wardrobe.gd`, `scripts/Visual/Humanoid.gd` (new functions only, plus a "Dressing" section)
- Modify: `scripts/AISystem/GuardRig.gd` (`DEFAULT_LOOK`, and the start of `setup` around `man.build`)
- Modify: `scripts/AISystem/Guard.gd` (one export)
- Test: `tests/wardrobe_test.gd`

**Interfaces:**
- **Produces (`Wardrobe`):**
  - `static var ROOT := "res://assets/characters/wardrobe/"`;
  - `kind_data(kind) -> Dictionary`, `head_data(face) -> Dictionary`, `headgear_data(piece) -> Dictionary`: cached JSON, `{}` if missing;
  - `can_dress(kind: StringName) -> bool`: true when the kind's glb, png, mask and json exist and at least one face and one headgear set in its options have all their files. Otherwise false, with one `push_warning` per kind;
  - `usable_options(options: Dictionary) -> Dictionary`: a copy of `options` with every face or headgear set whose files are missing dropped, one `push_warning` each (§10). `dress` rolls from these;
  - `skinned(path: String, target: Skeleton3D, body: String) -> Array`: returns `[Mesh, Skin]`. The skin is re-bound to `target` (`rebind`) after adding the GLB's missing bones (`add_bones`). The result is cached per `(path, body)`;
  - `forget() -> void`: clears every cache (tests).
- **Produces (`Humanoid`):**
  - `dress(kind: StringName, seed: int, fighting_idle: StringName = &"Sword_Idle") -> bool`. It returns false without building anything when `Wardrobe.can_dress` is false. Otherwise it:
    1. calls `build(&"", body == "female", fighting_idle)`;
    2. frees the base MeshInstance3Ds;
    3. rolls; drops the hair if a rolled piece `hides_hair`, and the beard unless every piece `allows_beard`;
    4. adds `Outfit` as `body` (the material per surface comes from `WR_closed`/`WR_strips`), then `Head_<face>`, then the headgear, each node named after its piece (`kettlehat`, `coif`): rigid pieces go through `attach(bone, node, Transform3D(offset))` into `armour`; skinned pieces are added like hair;
    5. applies `Wardrobe.apply_look` to each piece, and puts it on `Layers.ACTORS`;
    6. sets `scale = Vector3.ONE * look.height`.
  - `var look: Dictionary`: the roll after the rules;
  - `var metal: Dictionary`: StringName bone → MeshInstance3D, from the kind's `metal` (the outfit) and each skinned piece's `metal`;
  - `var cloth: Node`: filled in Task 8;
  - `worn() -> Array[MeshInstance3D]`: every skinned MeshInstance3D child of the skeleton, plus the valid rigid `armour` pieces. Marks, stumps and the weapon hang under BoneAttachment3Ds and are never included.
- **Produces (`GuardRig`):**
  - `DEFAULT_LOOK := {"kind": &"watchman", "outfit": &"watchman", "armour": [&"kettlehat"], "weapon": &"sword"}`;
  - `setup` tries `man.dress(look.kind, _look_seed(), idle)` when the look has `"kind"`, and falls back to today's painted path (build, hair, armour, boots) when that returns false;
  - `_look_seed() -> int` returns `guard.look_seed` when it is ≥ 0, otherwise `hash(String(guard.get_path()))`;
  - the ragdoll mass stays `size³`: height is visual only.
- **Produces (`Guard`):** `@export var look_seed := -1`.

- [ ] **Step 1: Write the failing tests K1, K1b, K1c, K2 and K10** (`_guard(seed)` spawns `Guard.tscn` with archetype `&""` and that `look_seed`, then waits 5 frames).

```gdscript
# K1 a watchman dresses in the wardrobe, nothing of the base body left
var g := await _guard(3)
var man = g._rig.man
var names := man.worn().map(func(m): return String(m.name))
var bare := names.any(func(n): return n in ["SuperHero_Male", "Eyes", "Eyebrows", "Boots"])
var layered := man.worn().all(func(m): return m.layers == Layers.ACTORS)
_check("K1 the watchman is dressed: outfit, weathered head, coif, kettle hat; no base body",
	man.body.name == "Outfit" and "Head_weathered" in names and "coif" in names
	and man.armour.any(func(a): return a.name == "kettlehat") and not bare and layered, str(names))
# K2 every worn triangle counted
var tris: int = man.worn().reduce(func(n, m): return n + m.mesh.get_faces().size() / 3, 0)
_check("K2 a dressed watchman is at most 3,000 triangles", tris <= 3000, "tris %d" % tris)
# K10 same seed, same man; four seeds, not four clones; the kettle hat always
var twin := await _guard(3)
var looks := {}
var hats := true
for s in [1, 2, 3, 4]:
	var w := await _guard(s)
	looks[str(w._rig.man.look)] = true
	hats = hats and w._rig.man.armour.any(func(a): return a.name == "kettlehat")
_check("K10 the same seed makes the same watchman, four seeds at least two looks, always the kettle hat",
	str(twin._rig.man.look) == str(man.look)
	and twin._rig.man.body.get_instance_shader_parameter("dye_colour") == man.body.get_instance_shader_parameter("dye_colour")
	and looks.size() >= 2 and hats, "distinct %d" % looks.size())
# K1b (Review Focus 3) a missing option is dropped; missing kind files: still a watchman, painted, kettle hat on
var kept := Wardrobe.usable_options({"faces": [&"weathered", &"nobody"], "tones": [&"light"], "hair": [], "beards": [],
	"headgear": [[&"kettlehat", &"coif"], [&"nothing"]], "dye": {"colour": [0.62, 0.52, 0.16], "shift": 0.04, "fade": [0.0, 0.35]},
	"grime": [0.2, 0.8]})
Wardrobe.ROOT = "user://no_wardrobe/"
Wardrobe.forget()
var painted := await _guard(5)
_check("K1b missing options are dropped; without wardrobe files the watchman falls back to the painted look",
	kept.faces == [&"weathered"] and kept.headgear.size() == 1
	and painted._rig.man.body.material_override is StandardMaterial3D
	and painted._rig.man.armour.any(func(a): return a.name == "kettlehat"), "kept %s" % kept)
Wardrobe.ROOT = "res://assets/characters/wardrobe/"
Wardrobe.forget()
# K1c (Review Focus 4) a squad shares one mesh, skin and material
var a := await _guard(21)
var b := await _guard(22)
var oa = a._rig.man.body
var ob = b._rig.man.body
_check("K1c dressed guards share the outfit's mesh, skin and material",
	oa.mesh == ob.mesh and oa.skin == ob.skin and oa.get_surface_override_material(0) == ob.get_surface_override_material(0), "")
```

- [ ] **Step 2: Run it.** Expected: K1, K2, K10, K1b and K1c FAIL (`dress` missing).
- [ ] **Step 3: Implement.** Re-read `Humanoid.gd`, `GuardRig.gd` and `Guard.gd` right before editing each one (Global Constraints). Then implement the Wardrobe loaders, `Humanoid.dress`, `worn`, `look` and `metal`, the `GuardRig` hook and `Guard.look_seed`.
- [ ] **Step 4: Run it.** Expected: every wardrobe check so far PASSes.
- [ ] **Step 5: Run the suites that spawn default guards:** `stealth_test`, `life_test`, `polish_test`, `hunt_test`. Expected: all PASS. If a check inspects the old painted body, update it to the wardrobe equivalent and note the reason in the test (§9.2).
- [ ] **Step 6: Commit** (with the go-ahead): `feat(wardrobe): guards dress from the wardrobe, painted fallback`

### Task 8: Cloth

**Files:**
- Create: `scripts/Visual/Cloth.gd`
- Modify: `scripts/Visual/Humanoid.gd` (`dress` makes the Cloth; `add_ragdoll` moves it after the ragdoll)
- Test: `tests/wardrobe_test.gd`

**Interfaces:**
- **Consumes:** the `cloth` and `colliders` entries of the kind and headgear JSON.
- **Produces:**
  - `Cloth.gd` extends `SpringBoneSimulator3D`.
  - `setup(chains: Array, colliders: Array) -> void`. For each chain:
    - the root bone is `bones[0]` and the end bone is `bones[-1]`;
    - `set_extend_end_bone(i, true)` and `set_end_bone_length(i, tip)`;
    - stiffness, drag, gravity and radius come from the chain;
    - gravity direction `Vector3.DOWN`;
    - `set_enable_all_child_collisions(i, true)`.
  - Each collider becomes a `SpringBoneCollisionCapsule3D` child, with `bone_name`, `radius`, `height` and `position_offset = Vector3(0, height / 2, 0)`, since bones run +Y.
  - `const JUMP := 1.0`: in `_process`, a skeleton that moved more than this since the last frame calls `reset()`.
  - `Humanoid.cloth` is set when any chain exists. `add_ragdoll` calls `skeleton.move_child(cloth, ragdoll.get_index() + 1)`.
  - `wardrobe_test` helper `_tips(man) -> Dictionary`: each chain name → the world position of its end bone's tip, for the speed and swing checks. It reads the tips through `BoneAttachment3D`s on the end bones, offset `tip` along +Y, because plain bone reads miss the simulation (Global Constraints).

- [ ] **Step 1: Write the failing tests K-order, K4, K4b, K5, K6, K6b and K12.**
  - **K-order:** among the skeleton's `SkeletonModifier3D` children, the index order is Posture < Ragdoll < Cloth.
  - **K4:** drive the guard forward at 3.2 m/s for 1 s (the stager way: set `velocity` and call `_rig.update(delta)` each physics frame while moving the node), then stop. Each skirt tip, relative to the pelvis, must swing ≥ 0.05 m after the stop, and every tip speed must fall below 0.02 m/s within 1.5 s. No NaN.
  - **K4b** (Review Focus 1): mid-swing, set `TimeFx.request(get_tree(), &"test", 0.05, 0.5)`. Once it expires, no tip moves faster than 5 m/s of game time in the next 10 frames. Call `TimeFx.clear()` in teardown.
  - **K5:** hold `kick_hit` and then `lunge` strike, 30 frames each (`_phase`, `_attack` and `_phase_timer` as in `tests/visual/stage_guards.gd`). Every skirt joint's distance to each thigh and calf capsule axis stays ≥ radius − 0.005.
  - **K6:** `guard.die(null)`. The tabard tip speed stays ≤ 5 m/s throughout and falls below 0.05 m/s within 2 s.
  - **K6b** (Review Focus 2): `guard.knock_down(guard.global_basis.z * 4.0)`, then wait for him to be up again (≤ 4 s). No NaN in any cloth bone pose, and tip speeds stay ≤ 5 m/s throughout.
  - **K12:** add 20 m to `global_position` in one frame. The tip speeds stay below 0.5 m/s over the next 5 frames.
- [ ] **Step 2: Run it.** Expected: FAIL (no Cloth).
- [ ] **Step 3: Implement** `Cloth.gd` and the `Humanoid` hooks.
- [ ] **Step 4: Run it and tune.** If K4–K6 fail, adjust `stiffness`, `drag`, `gravity` and `tip` in `recipes.py`, then `wardrobe.sh export watchman` and `--import`. Expected: all PASS.
- [ ] **Step 5: Commit** (with the go-ahead): `feat(wardrobe): spring-bone cloth for skirts and tabards`

### Task 9: Dismemberment, hit flash, armour sounds, and your arms

**Files:**
- Modify: `scripts/Visual/Humanoid.gd`:
  - `const FLESH_BONES`, the same list as `GuardRig.FLESH_BONES`;
  - `_cut_piece`: the copy rule, plus instance-uniform copies;
  - `armour_near`: metal zones.
- Modify: `scripts/AISystem/GuardRig.gd`:
  - `FLESH_BONES := HumanoidScript.FLESH_BONES`;
  - `_apply` and `_exit_tree` lay and clear the hit overlay over `man.worn()`.
- Modify: `scripts/Visual/Wardrobe.gd`: `weighted_bones(mesh: Mesh, skin: Skin) -> PackedStringArray`, cached. It returns the bones carrying any weight above 0.001.
- Test: `tests/wardrobe_test.gd`

**Interfaces:**
- **Produces:**
  - **The copy rule in `_cut_piece`:** a worn skinned mesh is copied when `Wardrobe.weighted_bones(mesh, skin)` meets the taken bone names. The copy carries `dye_colour`, `dye_fade`, `skin_tone` and `grime` from the original. For painted characters this picks exactly what the old rule picked: the body always, head pieces for the head, boots for the legs.
  - **`armour_near(point, reach := 0.12)`:** after the rigid pieces, find the nearest `FLESH_BONES` bone to `point`. When it is within 0.3 m and is in `metal`, return `metal[bone]`.
  - **The hit overlay** is laid when `_flash > 0.01`. Only overlays equal to `_overlay` are cleared, so the frob highlight is never touched.

- [ ] **Step 1: Write the failing tests K7, K7b, K8, K9 and K11.**
  - **K7:** a dressed watchman is killed (limp), then `man.sever(&"neck_01", Vector3(0, 2, 1))`. The piece's copy skeleton must hold MeshInstance3Ds named `Head_weathered` and `coif`, and a BoneAttachment3D holding `kettlehat`. Then `man.sever(&"thigh_l", Vector3(1, 1, 0))`: the piece holds `Outfit` but not `Head_weathered` or `coif`, no bone under `thigh_l` starts with `cloth_`, and `man.severed.bones` contains both bones.
  - **K7b** (Review Focus 5): the thigh piece's copied `Outfit` has the same `dye_colour`, `dye_fade`, `skin_tone` and `grime` instance parameters as the guard's outfit.
  - **K8:** `_rig.react_hit(g.global_basis.z, 1.0)`, then one `_rig.update(1.0 / 60.0)`. Every mesh in `man.worn()` has `material_overlay == _rig._overlay`. After 0.6 s, none does.
  - **K9:**
    - `man.metal` maps `neck_01` and `Head` to the `coif` mesh;
    - `armour_near` returns non-null 0.12 m above the Head bone, and at the neck_01 origin + 0.06 m forward;
    - it returns null at the spine_02 origin + 0.15 m forward (gambeson), and at the thigh_l midpoint.
  - **K11:** instantiate `Player.tscn`. The ViewArms `man.body.material_override` is a StandardMaterial3D whose albedo path ends in `T_player.png`. There is no Cloth node under its skeleton, and no mesh named `Outfit`.
- [ ] **Step 2: Run it.** Expected: K7, K7b, K8 and K9 FAIL. K11 may already pass; keep it as a guard.
- [ ] **Step 3: Implement** the `Humanoid` and `GuardRig` changes, re-reading both files first.
- [ ] **Step 4: Run the wardrobe suite and the neighbours:** `bodies_test`, `gore_test`, `sound_test` (M14) and `feel_test`. Expected: all PASS.
- [ ] **Step 5: Commit** (with the go-ahead): `feat(wardrobe): dismemberment, hit flash and metal zones for dressed guards`

### Task 10: `stage_wardrobe` and the PS2 tuning pass

**Files:**
- Create: `tests/visual/stage_wardrobe.gd`, `tests/visual/stage_wardrobe.tscn`
- Modify, while tuning: `tools/wardrobe/recipes.py`, `tools/wardrobe/bake.py` constants

**Interfaces:**
- **Produces:** the stager, a windowed visual check (not a test). It makes:
  - two sets:
    - **neutral:** `stage_guards.gd`'s environment and sun;
    - **night:** `Retro.night_environment()` and a `Torch` 2 m from the lineup;
  - a lineup: the old painted watchman (`build(&"watchman")` + `add_armour(&"kettlehat")` + `add_boots()`), then dressed watchmen with `look_seed` 1–4, using the Retro screen at 360 lines;
  - shots: a turnaround of seed 1 at 2 m (0°, 45°, 90°, 180°) and the whole lineup at 8 m;
  - files: `<out>/<set>_<shot>.png`, plus a `sheet.png` contact sheet assembled with `Image.blit_rect` at half size.
- **Run command:** `perl -e 'alarm 240; exec @ARGV' $GODOT --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_wardrobe.tscn -- --out=<dir>`

- [ ] **Step 1: Write and run the stager,** then view `sheet.png`.
- [ ] **Step 2: Run the every-pose stager** `tests/visual/stage_guards.tscn`. Look for skin or body through clothes, cloth through legs, and open collar seams in every pose. Fix what you find in the recipe or the build (§4, criterion 3). Then run `tests/visual/stage_gym.tscn` and `tests/visual/stage_look.tscn` (the showcase guard) to see watchmen in real levels.
- [ ] **Step 3: Tune the PS2 rules by eye,** in this order, re-running after each change:
  1. palette size (32, 64, 128);
  2. grime range;
  3. the bake light terms (0.35/0.65 and 0.78/0.22);
  4. texel density weights;
  5. cloth settings.

  Record the final values, with the reason, in comments in `recipes.py` and `bake.py`. Run the wardrobe suite again after the last change. Expected: all PASS.
- [ ] **Step 4: Send the user the sheets** (`SendUserFile`, display `render`): the before/after, the neutral and night lineups, and the turnaround. Ask for their batch 0 review of the look.
- [ ] **Step 5: Commit** (with the go-ahead): `feat(wardrobe): stage_wardrobe and the tuned PS2 watchman`

### Task 11: Full regression and hand-off

**Files:**
- Modify: `/Users/tinkertailorr/.claude/projects/-Users-tinkertailorr-a-world-of-darkness-alpha/memory/npc-ps2-look-project.md`

- [ ] **Step 1: Check syntax.** Run `--check-only` on every changed or new `.gd` file. Expected: no errors.
- [ ] **Step 2: Run every suite:** arena, bodies, combat, duel, exchange, feel, gore, gym, hunt, interaction, life, polish, retro, smooth, sound, squad, stealth, sturdy, traversal and wardrobe. Expected: no `FAIL` lines. Record the total count: the previous total plus the wardrobe checks (K1–K12, K1b, K1c, K2a, K3a, K4b, K6b, K7b, K10a, K-order).
- [ ] **Step 3: Update memory** with what's built, the commands (`wardrobe.sh`, the stagers), any gotchas found, and "next: batch 1 plan after the user's review".
- [ ] **Step 4: Report to the user:** the suite results, the sheets, what the tuning changed, and the proposed next step (the batch 1 plan).
