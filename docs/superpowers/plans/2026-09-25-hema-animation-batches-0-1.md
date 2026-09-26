# HEMA Combat Animation, Batches 0–1: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Blender-to-Godot animation pipeline (batch 0), then the 8-clip proof and the runtime that plays it (batch 1), ending in a review package for the user.

**Architecture:**
- Clips are keyed on a control rig in Blender 5.2, built by a script. They are exported headless as skeleton-only GLBs plus a `beats.json` holding markers, kinds, the weapon's placement and first-person camera samples.
- A static `Clips.gd` loads them into the shared Humanoid animation library, samples poses and answers timing queries.
- GuardRig and the first-person HandSlot/PlayerCombat play HEMA clips when they exist, and fall back to today's clips when they don't.
- Three test layers prove it: Blender-side `unittest` suites, a data-check suite (`anim_test`) and a runtime suite (`hema_test`).

**Tech Stack:** Blender 5.2.2 LTS (Python, layered actions, glTF 2.0 exporter), Godot 4.5.1 (GDScript, AnimationTree, SkeletonModifier3D), bash.

**Spec:** `docs/superpowers/specs/2026-09-25-hema-combat-animation-design.md`

## Global Constraints

- **Blender:** `/Applications/Blender.app/Contents/MacOS/Blender`, 5.2 LTS. Scripts use layered actions (`action.layers`, `action.slots`, `strip.channelbag(slot)`), never the removed `action.fcurves`.
- **Godot:** `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`, 4.5.1. Suites run with `--headless --fixed-fps 60 --path . res://tests/<suite>.tscn` and print `PASS`/`FAIL` lines after `==== RESULTS ====`. Written below as `Godot …`.
- **Frame rate:** clips are 30 fps. Every action has `use_frame_range` on and starts at frame 0.
- **Clip names** match `^(fp_)?(sword|rapier|maul|crossbow|shared)_[a-z0-9_]+$`.
- **Position keys:** only `root` and `pelvis` carry them. Every other bone is rotation-only.
- **Deform flags:** every game-skeleton bone is deform; every control bone (`CTRL_*`) is not.
- **Rules don't change:** no gameplay value in `Guard`, `GuardFighter` or `PlayerCombat` changes, and every existing suite stays green.
- **Fallback:** a move without a valid HEMA clip plays today's clip, unchanged.
- **Blender hygiene:**
  - Work only in our own files (scenes named `AUCOD_anim_<family>`).
  - Save a copy before every export.
  - One Blender instance is shared, so Blender tasks run one at a time.
- **First-person framing** (spec 8.3): rest low and right, wind-ups off-screen, the centre band only during the strike.
- **Commit messages** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Deferred to Later Batch Plans

These parts of the spec are deliberately not in this plan, and they are not gaps:
- **Batch 2:**
  - finisher pairs (`Clips.pair`, trigger, alignment, fallbacks);
  - first-person block, parry, riposte, bounce-back, stagger, kick leg and drop attack;
  - keying the sword's other blocks and parries. The side-choosing code lands here, in Task 8.
- **Batch 3:**
  - the root progress curve and the travelling check;
  - the footwork 2D blend;
  - broken guard and get-ups.
- **Batch 5:** the two-handed `CTRL_grip2`, the left-hand grip IK and its check.

## Review Focus

1. **Mixed old and new clips:** a combo that mixes a HEMA clip and a legacy clip (in batch 1 the swordsman's overhead is HEMA and his `right` is not) must not pop in the crossfade. Covered by Task 7, H9.
2. **Shared reactions on other bodies:** the brute (scale 1.25, maul) and the duelist (female) play `shared_hit_front_heavy` with their weapons still in hand. Covered by Task 8, H17.
3. **Game-time scaling:** during hit-stop and finisher slow-motion, clips follow game time, not real time. Covered by Task 10, H27.
4. **Swapping mid-swing:** switching weapon, or picking up a crate, mid-swing in first-person clip mode hands the arms back without the weapon jumping. Covered by Task 10, H28.
5. **Bad beats:** a clip that is in a GLB but has missing or malformed beats is ignored with one warning, and the move falls back. Covered by Task 4, A2–A3.

---

## Batch 0: Pipeline

### Task 1: Shared clip rules for the Blender tools

**Files:**
- Create: `tools/anim/anim_common.py`
- Create: `tools/anim/tests/run.py`, `tools/anim/tests/test_common.py`

**Interfaces:**
- Produces (Python, imported inside Blender):
  - `FPS = 30`
  - `FAMILIES = ("shared", "sword", "rapier", "maul", "crossbow")`
  - `NAME_RE`, the regex above
  - `REQUIRED_MARKERS: dict[str, tuple[str, ...]]`, keyed `attack, block, parry, bounce, reaction, broken_down, broken_up, getup, kick, shoot, reload, roar, finisher, evasion, loop, probe`. Values come from spec 5.3; `evasion` is `("from", "land", "ready")`, and `loop` and `probe` are empty.
  - `kind_of(name) -> str`, `family_of(name) -> str`, `stance_of(name) -> str`, `is_travelling(name) -> bool`
  - `to_gltf(v) -> tuple`, which maps `(x, y, z)` to `(x, z, -y)`
  - `to_gltf_matrix(m) -> Matrix`, which is `C @ m @ C.inverted()` with `C` = rows `(1,0,0),(0,0,1),(0,-1,0)` (4×4)
  - `WEAPON_OBJECT = {"shared": "W_Sword", "sword": "W_Sword", "rapier": "W_Rapier", "maul": "W_Maul", "crossbow": "W_Crossbow"}`
  - `EYE_BLENDER = (0.0, 0.1, 1.62)`: ViewArms.EYE in Blender axes, the body facing −Y
  - `CAMERA_FOV_Y_DEGREES = 75.0`
  - `LEGACY_GRIP`: GuardRig.GRIP as 4×4 rows in `hand_r`'s own frame: `((0,0,1,-0.03),(1,0,0,0.08),(0,1,0,0),(0,0,0,1))`
- `kind_of` rules. The first match wins:
  1. `shared_probe` → probe
  2. ends `_stance` or `_ready`, is `crossbow_aim`, or starts `shared_step_` → loop
  3. contains `_finisher_` or `_victim_` → finisher
  4. contains `_block` → block; `_parry` → parry; `_bounce` → bounce
  5. starts `shared_hit_`, or is `fp_sword_stagger` → reaction
  6. `shared_broken_down` → broken_down; `shared_broken_up` → broken_up; starts `shared_getup_` → getup
  7. ends `_kick` → kick; `crossbow_shoot` → shoot; `crossbow_reload` → reload; `maul_roar` → roar
  8. `shared_backstep` or `rapier_sidestep` → evasion
  9. anything else → attack
- `family_of` drops a leading `fp_` and returns the prefix.
- `stance_of`:
  - an `fp_` name → `fp_sword_ready`
  - crossbow → `crossbow_ready`
  - shared or sword → `sword_stance`
  - otherwise → `<family>_stance`
- `is_travelling` is true for `rapier_leap`, `maul_charge`, `rapier_sidestep`, `shared_backstep`, or anything starting `shared_step_`.

- [ ] **Step 1: Write the failing tests** in `tools/anim/tests/test_common.py`

```python
class TestCommon(unittest.TestCase):
    def test_kinds(self):
        cases = {"sword_overhead": "attack", "fp_sword_drop": "attack", "rapier_leap": "attack",
                 "fp_sword_ready": "loop", "shared_step_left": "loop", "crossbow_aim": "loop",
                 "sword_block_high": "block", "fp_sword_parry": "parry", "sword_bounce_side": "bounce",
                 "shared_hit_front_heavy": "reaction", "fp_sword_stagger": "reaction",
                 "shared_broken_down": "broken_down", "shared_getup_face_up": "getup",
                 "shared_kick": "kick", "fp_sword_kick": "kick", "crossbow_reload": "reload",
                 "maul_roar": "roar", "sword_victim_front": "finisher", "fp_sword_finisher_back": "finisher",
                 "shared_backstep": "evasion", "shared_probe": "probe"}
        for name, kind in cases.items():
            self.assertEqual(anim_common.kind_of(name), kind, name)

    def test_names(self):
        for good in ("sword_overhead", "fp_sword_ready", "shared_hit_front_heavy"):
            self.assertTrue(anim_common.NAME_RE.match(good))
        for bad in ("Sword_Attack", "sword-overhead", "axe_swing", "sword"):
            self.assertIsNone(anim_common.NAME_RE.match(bad))

    def test_stance_of(self):
        self.assertEqual(anim_common.stance_of("fp_sword_overhead"), "fp_sword_ready")
        self.assertEqual(anim_common.stance_of("crossbow_shoot"), "crossbow_ready")
        self.assertEqual(anim_common.stance_of("shared_hit_front_heavy"), "sword_stance")
        self.assertEqual(anim_common.stance_of("maul_heavy"), "maul_stance")

    def test_travelling(self):
        self.assertTrue(anim_common.is_travelling("shared_step_back"))
        self.assertFalse(anim_common.is_travelling("sword_overhead"))

    def test_axes(self):
        self.assertEqual(anim_common.to_gltf((1, 2, 3)), (1, 3, -2))

    def test_markers(self):
        self.assertEqual(anim_common.REQUIRED_MARKERS["attack"],
                         ("from", "cocked", "release", "contact", "follow", "done", "ready"))
        self.assertEqual(anim_common.REQUIRED_MARKERS["evasion"], ("from", "land", "ready"))
```

- [ ] **Step 2: Run to verify it fails**

Run: `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/anim/tests/run.py`
Expected: an ImportError for `anim_common`, and exit code 1. (`run.py` discovers `test_*.py`, puts `tools/anim` on `sys.path`, and exits 0 only when every test passes.)

- [ ] **Step 3: Implement** `tools/anim/anim_common.py` and `tools/anim/tests/run.py`.

- [ ] **Step 4: Run to verify it passes.** Same command. Expected: every test passes, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add tools/anim/anim_common.py tools/anim/tests/run.py tools/anim/tests/test_common.py
git commit -m "feat(anim): shared clip rules for the Blender tools"
```

### Task 2: The rig builder

**Files:**
- Create: `tools/anim/build_rig.py`, `tools/anim/tests/test_build_rig.py`
- Create: `assets/characters/animations/source/.gdignore` (empty)
- Modify: `.gitignore`, adding `assets/characters/animations/source/reference/` and `assets/characters/animations/source/backup/`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `build(family: str, out_path: str, body: str = "male") -> None`
  - CLI: `Blender -b --factory-startup --python tools/anim/build_rig.py -- --family <f> --out <path.blend> [--body female]`

  The saved file contains:
  - **Scene:** `AUCOD_anim_<family>`, 30 fps, `fps_base` 1.
  - **`Armature`:** imported from `assets/characters/base/Superhero_<Male|Female>_FullBody.gltf` with `bone_heuristic='BLENDER'` and `guess_original_bind_pose=True`. The body mesh is kept for preview. All 65 game bones are deform.
  - **Control bones,** all non-deform:
    - `CTRL_grip` (parent `root`);
    - `CTRL_hand_ik_r` (parent `CTRL_grip`);
    - `CTRL_hand_ik_l`, `CTRL_elbow_pole_l`, `CTRL_elbow_pole_r`, `CTRL_foot_ik_l`, `CTRL_foot_ik_r`, `CTRL_knee_pole_l`, `CTRL_knee_pole_r` (parent `root`).
    - The two-handed `CTRL_grip2` is added by the batch-5 plan.
  - **IK:** IK on `lowerarm_l`, `lowerarm_r`, `calf_l` and `calf_r`, with chain 2 and the matching targets and poles, and pole angles chosen so the rest pose is unchanged.
  - **Copy Rotation** (world space) from the IK bones onto `hand_l`, `hand_r`, `foot_l` and `foot_r`.
  - **`FistRef`:** a hidden armature holding the finger rotations of UAL1 `Sword_Idle` at 0.3 s for the right hand and `Idle` at 0.3 s for the left. They're read from `assets/characters/animations/UAL1_Standard.glb`, imported the same way, then deleted.
    - Each finger bone of `Armature` gets a local-space Copy Rotation to its `FistRef` twin.
    - The constraint's influence is driven by the object properties `curl_r` (default 1.0) and `curl_l` (default 0.3).
  - **`Weapon`:** a copy of `WEAPON_OBJECT[family]` appended from `assets/weapons/source/weapons.blend`. It is parented to bone `CTRL_grip`, and at rest its world matrix is `hand_r world @ LEGACY_GRIP`.
  - **`HeadCam`:** parented to bone `Head`. At rest it sits at `EYE_BLENDER`, looking along −Y with +Z up, with `sensor_fit='VERTICAL'` and `angle_y = radians(75)`.
  - **`Proxy`:** a one-triangle mesh (1 mm) at the origin, with vertex group `root` at weight 1 and an Armature modifier. It exists so the export writes a skin and Godot imports a Skeleton3D, like the UAL files.
  - **`export.py`:** a text block that runs `tools/anim/export_clips.py` through `runpy`, with the repo root four folders above the `.blend`.

- [ ] **Step 1: Write the failing tests** in `tools/anim/tests/test_build_rig.py`. `setUpClass` builds `sword` into a temp folder and opens it.
  - `test_scene_and_fps`: the scene name is `AUCOD_anim_sword`, `render.fps == 30` and `fps_base == 1`.
  - `test_game_bones_deform`: the 65 joint names in the base `.gltf` JSON are all `Armature` bones with `use_deform`.
  - `test_controls_not_deform`: the set of `CTRL_*` bones equals the nine names above, and none of them deform.
  - `test_rest_unchanged`: at frame 0 with no action, every non-finger deform bone's evaluated armature-space matrix equals `bone.matrix_local` within 0.1 mm and 0.1°.
  - `test_weapon_in_hand`: `Weapon.matrix_world` ≈ `Armature.matrix_world @ pose_bones["hand_r"].matrix @ Matrix(LEGACY_GRIP)`, within 1 mm and 0.5°.
  - `test_fists`:
    - with `curl_r = 1.0`, the local rotations of `{index,middle,ring,pinky,thumb}_0{1,2,3}_r` equal UAL `Sword_Idle` at frame 9, within 1°;
    - with `curl_r = 0.0`, they equal rest within 0.1°.
  - `test_head_camera`:
    - `HeadCam.parent_bone == "Head"`;
    - its world location is within 1 mm of `EYE_BLENDER`;
    - its local −Z in world space is within 1° of `(0, -1, 0)`;
    - `sensor_fit == "VERTICAL"` and `abs(angle_y - radians(75)) < 1e-4`.
  - `test_proxy`: `Proxy` has one polygon, a `root` vertex group, and an Armature modifier pointing at `Armature`.
  - `test_export_block`: `"export.py" in bpy.data.texts`.
  - `test_female_body`: `build("rapier", tmp, body="female")` imports the female mesh; its object name contains `Female`.

- [ ] **Step 2: Run to verify it fails.** Run the Blender test command. Expected: `test_build_rig` fails with an ImportError for `build_rig`.

- [ ] **Step 3: Implement** `build_rig.py`, then create the `.gdignore` and the `.gitignore` lines.

- [ ] **Step 4: Run to verify it passes.** Expected: every test passes, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add tools/anim/build_rig.py tools/anim/tests/test_build_rig.py assets/characters/animations/source/.gdignore .gitignore
git commit -m "feat(anim): script-built Blender control rig"
```

### Task 3: Validation and export

**Files:**
- Create: `tools/anim/export_clips.py`, `tools/anim/export_clips.sh`, `tools/anim/tests/test_export.py`

**Interfaces:**
- Consumes: Task 1, and Task 2's object names (`Armature`, `Weapon`, `HeadCam`, `Proxy`).
- Produces:
  - **`validate() -> list[str]`** on the open file. It returns one message per problem, each naming the action. The rules (spec 11.1 and 6.3):
    - The name matches `NAME_RE`, and its family is the scene's family.
    - `use_frame_range` is on and `frame_start == 0`.
    - The scene is at 30 fps (`fps_base` 1).
    - Every marker in `REQUIRED_MARKERS[kind_of(name)]` is a pose marker, in the listed order, inside the range.
    - A `loop` action has `action["loop"] == True`, and its first and last frames are within 0.5° per deform bone.
    - **Start pose:** within 2° per deform bone of `stance_of(name)` at frame 0. Exempt: reaction, bounce, getup, broken_up, and `*_victim_*`.
    - **End pose:** within 2° of the stance at frame 0. Exempt: broken_down, `*_victim_*` and loops. Blocks must end within 2° of their own `set` pose instead.
    - Poses are compared as each deform bone's evaluated rotation relative to its parent, constraints included. A stance missing from the file skips the stance comparisons without an error.
  - **`backup(keep: int = 5) -> str`:** `save_as_mainfile(filepath=<source>/backup/<stem>-<YYYYmmdd-HHMMSS>.blend, copy=True)`, deleting the oldest copies beyond `keep`.
  - **`export(out_dir: str, make_backup: bool = True) -> dict`:**
    - If validation fails, it raises `ValueError` with every message and writes nothing.
    - Otherwise it backs up, writes `HEMA_<family>.glb` and `HEMA_<family>.beats.json`, writes the `.import` stub, and returns the beats dict.
  - **CLI:** `Blender -b <file.blend> --python tools/anim/export_clips.py -- --out <dir> [--no-backup]`. It exits 1 and prints the messages on failure.
  - **`export_clips.sh <family|all>`:** runs the CLI on `assets/characters/animations/source/<family>.blend` (on every existing family file for `all`) with `--out assets/characters/animations`, then runs `Godot --headless --import --path .`.
- **GLB:** select `Armature` and `Proxy` only, then export with:
  - `export_format='GLB'`, `use_selection=True`
  - `export_def_bones=True`, `export_skins=True`, `export_leaf_bone=False`
  - `export_animations=True`, `export_animation_mode='ACTIONS'`, `export_force_sampling=True`, `export_frame_step=1`
  - `export_anim_slide_to_zero=True`, `export_reset_pose_bones=True`, `export_rest_position_armature=True`, `export_optimize_animation_size=False`
  - `export_materials='NONE'`, `export_morph=False`, `export_yup=True`, `export_apply=False`
- **The beats JSON** (the spec 5.4 schema as amended by this plan):
  - `family` and `fps`.
  - `weapon`: 12 floats. It is `to_gltf_matrix(Weapon.matrix_world)` at frame 0 of the family stance, written as basis x, y, z columns then the origin. Omitted when the stance is absent.
  - `clips`, per action:
    - `kind`, `length` in seconds, `loop`, `travelling`;
    - `markers`: name → `(frame − frame_start) / 30`;
    - for `fp_` clips only, `camera`: one sample per frame, `[t, px, py, pz, qx, qy, qz, qw]`. Each sample is `HeadCam`'s world matrix at `fp_sword_ready` frame 0, inverted, times `HeadCam`'s world matrix at that frame. Blender and Godot cameras share −Z forward and +Y up, so no axis change is needed.
  - `probe`, only when `shared_probe` exists:
    - `frame`: its last frame;
    - `points`: the bone heads of `pelvis, spine_01, spine_03, Head, upperarm_l, upperarm_r, lowerarm_l, lowerarm_r, hand_l, hand_r, thigh_l, thigh_r, calf_l, calf_r, foot_l, foot_r`, in world space through `to_gltf`;
    - `weapon`: 12 floats, as above;
    - `blade_tip`: the `Weapon` vertex with the largest local Z, in world space through `to_gltf`.
- **The `.import` stub,** written only if missing: `[remap]` with `importer="animation_library"` and `type="AnimationLibrary"`, followed by the `[params]` lines copied from `assets/characters/animations/UAL1_Standard.glb.import`.

- [ ] **Step 1: Write the failing tests** in `tools/anim/tests/test_export.py`. `setUp` builds a fresh `sword` file with Task 2's `build`. The helpers key `upperarm_r` rotations and add pose markers.
  - `test_validate_clean`: `sword_stance` (a loop over frames 0–20 with identical keys) plus `sword_overhead` gives `validate() == []`.
    - `sword_overhead` has markers from 0, cocked 8, release 12, contact 16, follow 20, done 26 and ready 34.
    - Its keys at frames 0 and 34 match the stance, with a 40° swing at 16.
  - `test_validate_missing_marker`: `sword_bad` without `contact` gives one message containing `sword_bad` and `contact`.
  - `test_validate_bad_name`: an action named `Sword_Upper` gives a message containing `Sword_Upper`.
  - `test_validate_wrong_family`: a `rapier_left` action in the sword file gives a message containing `rapier_left`.
  - `test_validate_fps`: at 24 fps, a message contains `30 fps`.
  - `test_validate_loop_seam`: a stance whose last key is 3° off gives a message containing `sword_stance` and `seamless`.
  - `test_validate_start_off_stance`: a `sword_left` starting 10° off gives a message containing `sword_left` and `stance`.
  - `test_validate_block_ends_on_set`: a `sword_block_high` ending 5° from its `set` pose gives a message containing `sword_block_high`.
  - `test_export_files`: `export(tmp, make_backup=False)` writes the GLB, the beats file and the `.import` file. In the beats:
    - `clips["sword_overhead"]["markers"]["contact"] == 16/30` (±1e-6);
    - its `kind == "attack"`, `travelling is False` and `loop is False`;
    - `clips["sword_stance"]["loop"] is True`;
    - `len(weapon) == 12`.

    The stub contains `importer="animation_library"` and `animation/fps=30`.
  - `test_glb_structure`: parsing the GLB's JSON chunk shows:
    - the scene root node is named `Armature`;
    - there is exactly one skin;
    - no node name starts with `CTRL_`;
    - the animation names are `{"sword_stance", "sword_overhead"}`.
  - `test_export_refuses_invalid`: with `sword_bad` present, `export` raises `ValueError` mentioning `sword_bad`, and no GLB exists afterwards.
  - `test_backup_keeps_five`: after six exports with backup, `source/backup/` holds 5 files.
  - `test_camera_samples`: with `fp_sword_ready` and `fp_sword_overhead` (Head yawed 10° at frame 10), `camera` has one sample per frame including the last. Sample 0 is the identity (1e-5), and sample 10 is rotated 10° (±0.5°).
  - `test_probe`: a `shared` file with `shared_probe` (frames 0–12) gives:
    - `probe["frame"] == 12`;
    - 16 `points`, with `points["hand_r"]` equal to the evaluated `hand_r` head at frame 12 through `to_gltf` (1e-5);
    - `len(probe["weapon"]) == 12` and `len(probe["blade_tip"]) == 3`.

- [ ] **Step 2: Run to verify it fails.** Run the Blender test command. Expected: the `test_export` tests fail with an ImportError for `export_clips`.

- [ ] **Step 3: Implement** `export_clips.py` and `export_clips.sh`. Make the shell script executable.

- [ ] **Step 4: Run to verify it passes.** Expected: every test passes, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add tools/anim/export_clips.py tools/anim/export_clips.sh tools/anim/tests/test_export.py
git commit -m "feat(anim): validate and export clips with their beats"
```

### Task 4: `Clips.gd`, the game-side loader

**Files:**
- Create: `scripts/Visual/Clips.gd`, `tests/anim_test.gd`, `tests/anim_test.tscn`
- Modify: `scripts/Visual/Humanoid.gd`:
  - `library()` calls `ClipsScript.add_to(_library)` after merging the UAL libraries;
  - `show_action` records what it shows;
  - a new `shown() -> Array`.

**Interfaces:**
- Consumes: Task 3's beats format.
- Produces: statics on `const ClipsScript := preload("res://scripts/Visual/Clips.gd")`.
  - **`add_to(library: AnimationLibrary) -> void`:** for each family in `["shared", "sword", "rapier", "maul", "crossbow"]` whose `res://assets/characters/animations/HEMA_<family>.glb` exists:
    - load it (an AnimationLibrary) and parse its `.beats.json`;
    - add each animation to `library`, duplicated with `LOOP_LINEAR` when `loop` is set;
    - record its beats.
  - **Test seam:** `register(family: StringName, clips: Dictionary, beats: Dictionary) -> void`, where `clips` maps a name to an Animation. It adds them to `Humanoid.library()` and records the beats. `unregister_all() -> void` undoes it.
  - **Queries:**
    - `has(clip) -> bool`: the clip is in the library, and its beats hold every marker its `kind` needs (the spec 5.3 table, mirrored as a const).
    - `kind(clip) -> StringName`, `markers(clip) -> Dictionary` (StringName → float), `marker(clip, name) -> float`, `length(clip) -> float`, `is_loop(clip) -> bool`.
    - `names() -> Array[StringName]`: every clip for which `has` is true.
  - **`stance_of(family) -> StringName`:** `&"fp"` gives `fp_sword_ready`, crossbow gives `crossbow_ready`, and anything else gives `<family>_stance`. Returns `&""` unless that clip passes `has`.
  - **`family_of_weapon(weapon: StringName) -> StringName`:** sword, rapier, maul and crossbow map to themselves; anything else maps to `&"sword"`.
  - **`pose_at(skeleton: Skeleton3D, clip: StringName, time: float) -> Array[Transform3D]`:** every bone's global pose in skeleton space. Each bone's local transform is its rest, overridden by the clip's `Armature/Skeleton3D:<bone>` position, rotation and scale tracks (`*_track_interpolate`), composed parent-first.
  - **`grip(family: StringName, skeleton: Skeleton3D, fallback: Transform3D) -> Transform3D`:** the weapon in `hand_r`'s frame, computed as `pose_at(skeleton, stance, 0.0)[hand_r].affine_inverse() * weapon`.
    - `weapon` is built from the beats' 12 floats. `Armature` carries no transform, so the glTF model space equals skeleton space.
    - Cached per family. Returns `fallback` when there is no stance or no `weapon`.
  - **`camera_offset(clip, time) -> Transform3D`:** interpolates between the two nearest `camera` samples (linear position, slerped rotation). The identity when there are no samples.
  - **`legacy_of(clip) -> StringName`:**
    `{sword_stance: Sword_Idle, sword_overhead: Sword_Attack, sword_left: Sword_Regular_A, sword_right: Sword_Regular_B, sword_thrust: Sword_Dash, sword_sweep: Sword_Heavy_Combo, sword_bash: Melee_Hook, sword_block_high: Sword_Block, sword_bounce_high: Sword_Attack, shared_hit_front_heavy: Hit_Chest, shared_hit_front_light: Hit_Head}`, otherwise `&""`.
  - **`Humanoid.shown() -> Array`:** `[clip: StringName, time: float, weight: float]` for the action slot in front.
  - **Bad beats:** missing or malformed beats make `has` false, with one `push_warning` per clip name.

- [ ] **Step 1: Write the failing checks.** `tests/anim_test.gd` follows `tests/squad_test.gd`'s shape: `results`, `_check(name, ok, detail)`, `_frames(n)`, then print after `==== RESULTS ====` and quit. Synthetic clips are `Animation`s with rotation tracks on `Armature/Skeleton3D:<bone>`.

```gdscript
_check("A1 a registered clip is known, with its markers", Clips.has(&"sword_test") and is_equal_approx(Clips.marker(&"sword_test", &"contact"), 0.5), "...")
_check("A2 a clip without beats is ignored", not Clips.has(&"sword_nobeats"), "...")
_check("A3 a clip missing a marker its kind needs is ignored", not Clips.has(&"sword_nocontact"), "...")
_check("A4 pose_at matches what the animation player shows", worst < 0.0001, "worst %.6f m" % worst)
_check("A5 grip recovers the weapon's place in the hand", grip.is_equal_approx(GuardRig.GRIP), "...")
_check("A6 camera_offset interpolates between samples", offset.origin.is_equal_approx(Vector3(0.01, 0, 0)), "...")
_check("A7 stance_of and family_of_weapon", Clips.stance_of(&"sword") == &"sword_stance" and Clips.stance_of(&"maul") == &"" and Clips.family_of_weapon(&"dagger") == &"sword", "...")
_check("A8 the Humanoid library carries registered clips and shown() reports the slot", man.shown()[0] == &"sword_test", "...")
```

  - A4: a watchman `Humanoid`, with its AnimationPlayer at `Sword_Idle` 0.3 s (`seek(0.3, true)`). Compare `get_bone_global_pose(i)` for every bone against `Clips.pose_at(skeleton, &"Sword_Idle", 0.3)`.
  - A5: register `sword_stance`, with the beats' `weapon` set to its t=0 `hand_r` global pose times `GuardRig.GRIP`.
  - A6: two camera samples, at t 0 with `x` 0 and at t 0.1 with `x` 0.02, queried at 0.05.

- [ ] **Step 2: Run to verify it fails**

Run: `Godot --headless --fixed-fps 60 --path . res://tests/anim_test.tscn`
Expected: a parse error for the missing `Clips.gd`, or FAIL lines.

- [ ] **Step 3: Implement** `Clips.gd` and the Humanoid changes.

- [ ] **Step 4: Run to verify it passes.** Expected: A1–A8 PASS. Also run `bodies_test` and `duel_test`: both must stay all PASS (with no HEMA files, the merge does nothing).

- [ ] **Step 5: Commit**

```bash
git add scripts/Visual/Clips.gd scripts/Visual/Humanoid.gd tests/anim_test.gd tests/anim_test.tscn
git commit -m "feat(anim): load HEMA clips and their beats into the game"
```

### Task 5: The round trip (the gate for everything after)

**Files:**
- Create: `assets/characters/animations/source/shared.blend`, plus its exports `HEMA_shared.glb`, `HEMA_shared.beats.json` and `HEMA_shared.glb.import`
- Modify: `tests/anim_test.gd` (A9–A12)

**Interfaces:**
- Consumes: Tasks 2–4.
- Produces: `shared_probe`, running frames 0–12.
  - Frame 0 is the rest pose.
  - Frame 12 is deliberately asymmetric:
    - the spine twisted 25° left and the head turned 30° right;
    - the right hand high and forward on the grip, the left arm out to the side;
    - the left knee bent 40° and the pelvis dropped 5 cm.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("A9 HEMA tracks address the same skeleton path as the library's", hema_prefix == ual_prefix, "%s vs %s" % [hema_prefix, ual_prefix])
_check("A10 on the male body the probe lands where Blender put it (5 mm)", worst_m <= 0.005, "worst %s %.4f m" % [worst_bone, worst_m])
_check("A11 on the female body every limb points where Blender's did (2°)", worst_deg <= 2.0, "worst %s %.2f°" % [worst_limb, worst_deg])
_check("A12 the Blender sword prop and the game's sword agree (blade tip, 5 mm)", tip_err <= 0.005, "%.4f m" % tip_err)
```

  - A9: the NodePath before `:` of the first rotation track, in `shared_probe` and in `Sword_Idle`.
  - A10 and A11:
    - A Humanoid (male, then female) at the origin shows `shared_probe` at its last frame.
    - Positions are measured in the glTF scene root's space: `man.model.global_transform.affine_inverse() * (skeleton.global_transform * skeleton.get_bone_global_pose(i)).origin`.
    - A11's limbs are upperarm→lowerarm and lowerarm→hand on both sides, thigh→calf and calf→foot on both sides, and spine_01→Head.
  - A12: `probe.weapon` as a Transform3D, times the `blade_tip` meta of `WeaponScript.guard_weapon_mesh(&"sword")`, against `probe.blade_tip`.

- [ ] **Step 2: Run to verify it fails.** Run `Godot … res://tests/anim_test.tscn`. Expected: A9–A12 FAIL, because there is no `HEMA_shared` yet.

- [ ] **Step 3: Build, key and export**
  - Build: `Blender -b --factory-startup --python tools/anim/build_rig.py -- --family shared --out assets/characters/animations/source/shared.blend`
  - Open the file in the connected Blender (MCP), key `shared_probe` as above, and save.
  - Export: `bash tools/anim/export_clips.sh shared`

- [ ] **Step 4: Run to verify it passes.** Expected: A1–A12 PASS.
  - If A10 or A11 fail, rebuild with `guess_original_bind_pose=False`, then re-key and re-export.
  - If they still fail, **stop** and report the measured errors to the user. The spec's fallback (Godot's humanoid retarget) is a design change.

- [ ] **Step 5: Commit**

```bash
git add assets/characters/animations/source/shared.blend assets/characters/animations/HEMA_shared.* tests/anim_test.gd
git commit -m "feat(anim): round-trip probe proves Blender clips land exactly in Godot"
```

---

## Batch 1: Proof

### Task 6: Checks on every exported clip

**Files:**
- Create: `tests/anim_checks.gd`, a RefCounted of static checks
- Modify: `tests/anim_test.gd`:
  - A13–A19 prove each check on synthetic good and bad clips;
  - A20 runs the checks over every exported clip.

**Interfaces:**
- Consumes: `Clips.pose_at/markers/kind/is_loop/length/camera_offset/stance_of/grip`, and `GuardFighterScript` ATTACKS and ARCHETYPES for reach.
- Produces: statics that each return `[ok: bool, detail: String]`.
  - They sample at 30 per second, on a male Humanoid at the origin, measuring in the glTF scene root's space. The model faces +Z; the floor is y = 0.
  - Thresholds are spec 10.1's, and the offending time and bone go in `detail`.
  - **`markers_ok(clip)`.**
  - **`pops_ok(man, clip)`:**
    - start and end poses within 2° per bone of the stance's frame 0 (spec 6.3 exemptions; blocks end on their `set` pose);
    - no bone turns more than 40° between samples;
    - loops are seamless within 0.5°.
  - **`feet_ok(man, clip)`:** a `foot_l`/`foot_r` head is planted when it is ≤ 0.03 m high and moving ≤ 0.25 m/s for ≥ 3 samples. While planted, it drifts ≤ 0.01 m horizontally.
  - **`joints_ok(man, clip)`:**
    - elbow and knee bend is the angle between the segment directions: 0–155°, with ≤ 5° of hyperextension;
    - the wrist, measured as `hand` relative to `lowerarm` in the forearm's frame: bend about X ±80°, sideways about Z ±35°, twist about Y ±45°.
  - **`travel_ok(clip)`:** in-place clips end with `root` within 0.1 m of where it started. The travelling-clip check arrives with batch 3.
  - **`contact_ok(man, clip, reach: float, low: bool)`:**
    - At `contact`, the blade crosses a capsule of radius 0.25 m, spanning 1.0–1.7 m high (0.1–0.6 m when `low`), with its axis at `(0, y, reach)`.
    - The blade runs from `blade_base` to `blade_tip` of the family's guard weapon, placed at `hand_r × Clips.grip`.
    - The tip moves at ≥ 3 m/s, measured by central difference.
  - **`framing_ok(clip)`,** for `fp_` clips:
    - The camera sits at eye `(0, 1.62, −0.1)`, looking along +Z, times `Clips.camera_offset(clip, t)`. The projection is 75° vertical at 16:9. The blade is sampled at 8 points.
    - Ready and loop poses: the grip projects into the lower-right quarter.
    - `from` to `release`: ≥ 60% of the blade samples are off-screen or in the outer 15% border.
    - The centre band (|x − 0.5| < 0.12) is entered only between `release` and `follow`.
    - At `contact`, the blade passes within 0.08 screen heights of the centre.

- [ ] **Step 1: Write the failing checks.** Each builds a synthetic good clip (must pass) and a synthetic bad clip (must fail, with the fault in `detail`).
  - A13 markers: the bad clip is missing `release`.
  - A14 pops: an end pose 5° off; a 50° jump between samples; a loop 1° off.
  - A15 feet: a planted foot sliding 3 cm.
  - A16 joints: an elbow bent 15° backwards; a wrist twisted 60°.
  - A17 travel: an in-place clip ending 0.2 m forward.
  - A18 contact: a blade stopping 0.5 m short; a blade crossing at 1 m/s.
  - A19 framing: a ready grip at screen centre; a wind-up through the centre band.
  - A20: every clip in `Clips.names()` passes every check for its kind. `shared_probe` is exempt from everything except markers. The reach is the swordsman's `attack_range` plus `ATTACKS[kind].reach`. The failures are listed.

- [ ] **Step 2: Run to verify it fails.** Run `Godot … res://tests/anim_test.tscn`. Expected: FAIL, because `anim_checks.gd` doesn't exist.

- [ ] **Step 3: Implement** `tests/anim_checks.gd`.

- [ ] **Step 4: Run to verify it passes.** Expected: A1–A20 PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/anim_checks.gd tests/anim_test.gd
git commit -m "test(anim): automatic checks for every exported clip"
```

### Task 7: Guards play HEMA attacks

**Files:**
- Modify: `scripts/AISystem/GuardRig.gd` (`setup`, `_show_blow`, plus the new members below)
- Modify: `scripts/AISystem/GuardFighter.gd`, adding `func reach_of(kind: StringName) -> float`, which returns `_reach(kind)`
- Create: `tests/hema_test.gd`, `tests/hema_test.tscn`. The runtime suite follows `tests/squad_test.gd`'s shape: a floor, the player with a sword, and guards via `_guard(archetype, at)`.

**Interfaces:**
- Consumes: `Clips.has/marker/markers/stance_of/family_of_weapon/grip`, `Humanoid.shown()`.
- Produces:
  - `GuardRig._family: StringName`, from `Clips.family_of_weapon(look.weapon)`.
  - `GuardRig._hema_clip(kind: StringName) -> StringName`: `"<family>_<kind>"` if `Clips.has` it, else `&""`.
  - `static func GuardRig.hema_windup_time(m: Dictionary, u: float, length: float) -> float`:

```
release := clampf((m.contact - m.release) / length, 0.12, 0.6)
gather := 0.45 * (1.0 - release)
hold_end := 1.0 - release
u < gather    → lerp(m.from, m.cocked, ease_out(u / gather))
u < hold_end  → lerp(m.cocked, m.release, (u - gather) / (hold_end - gather))   # the coil, stretched
otherwise     → lerp(m.release, m.contact, (u - hold_end) / release)
```

  - `_show_hema_blow(clip, phase, u)`, always at weight 1.0 with a 0.08 s fade-in:
    - wind-up uses `hema_windup_time`;
    - strike is `lerp(contact, follow, u)`;
    - recovery is `lerp(follow, ready, u)`, then `clear_action(0.2)` once u ≥ 0.98.
    - Bounced and parried blows are Task 8.
  - `setup`:
    - the fighting idle is `Clips.stance_of(_family)` when it is non-empty, else today's (`Pistol_Idle` or `Sword_Idle`);
    - `_grip = Clips.grip(_family, man.skeleton, <today's GRIP or CROSSBOW_GRIP>)`.

- [ ] **Step 1: Write the failing checks.**
  - Setup:
    - `_ready` registers synthetic clips with `Clips.register(&"sword", …)`: `sword_stance` (a loop) and `sword_overhead`.
    - `sword_overhead`'s markers are from 0.0, cocked 0.2, release 0.3, contact 0.4, follow 0.5, done 0.7 and ready 0.9.
    - Phases are driven by setting `guard._attack`, `_phase`, `_phase_timer` and `_phase_length`, then calling `rig._animate(0.0)`.

```gdscript
_check("H1 a swordsman stands in sword_stance", rig.man.shown()[0] == &"sword_stance", "...")
_check("H2 the overhead's wind-up reaches cocked quickly", absf(time_at_gather_end - 0.2) < 0.01, "...")
_check("H3 the telegraph hold is a moving coil, never a freeze", strictly_increasing and first >= 0.2 and last <= 0.3, "...")
_check("H4 the wind-up ends exactly at contact", absf(time_at_u1 - 0.4) < 0.001, "...")
_check("H5 the strike runs contact to follow, the recovery follow to ready", ..., "...")
_check("H6 a kind with no HEMA clip plays today's clip", rig.man.shown()[0] == &"Sword_Regular_B", "...")
_check("H7 HEMA clips play at full weight", is_equal_approx(rig.man.shown()[2], 1.0), "...")
_check("H8 the weapon sits at Clips.grip", rig.weapon.transform.is_equal_approx(expected_grip), "...")
_check("H9 an overhead chained into a legacy right never turns a bone 40° between frames", worst_deg < 40.0, "...")
```

- [ ] **Step 2: Run to verify it fails.** Run `Godot … res://tests/hema_test.tscn`. Expected: FAIL.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run to verify it passes.** Expected: H1–H9 PASS. Then run `duel_test`, `combat_test`, `feel_test` and `bodies_test`: all must stay PASS, because no real `sword_*` clips exist yet.

- [ ] **Step 5: Commit** with message `feat(anim): guards play HEMA attacks, timed by their markers`.

### Task 8: Clash, blocks and hits

**Files:**
- Modify: `scripts/AISystem/GuardRig.gd` (`_animate`, `react_block`, `react_hit`, plus the new members below)
- Modify: `tests/hema_test.gd` (H10–H17)

**Interfaces:**
- Produces:
  - **`_bounce_clip(kind) -> StringName`:**
    - sword and rapier: `"<family>_bounce_high"` for `overhead`, `heavy` and `leap`, else `"<family>_bounce_side"`;
    - maul: `maul_bounce`;
    - `&""` unless `Clips.has` it.
  - **Blocked** (the recover phase with `_bounced` set), with a 0.05 s fade-in:
    - for u < 0.3, time is `lerp(contact, recoil, ease_out(u / 0.3))`;
    - after that, `lerp(recoil, ready, (u − 0.3) / 0.7)`.
  - **Parried** (`_reel > 0`), with `elapsed = _reel_length − _reel` and `left = _reel`:
    - for the first 0.15 s, time is `lerp(contact, recoil, ease_out(elapsed / 0.15))`;
    - it holds at `recoil` while `left > 0.5`;
    - then `lerp(recoil, ready, 1 − left / 0.5)`.
    - With no bounce clip, today's `Idle_Shield_Break` plays.
  - **`_block_clip() -> StringName`**, the first candidate that `Clips.has`, else `&""` (today's `Sword_Block`):
    - sword: the side comes from the player's `combat.threat_direction()`: `overhead` or `thrust` → `high`, `left` → `left`, `right` → `right`. The candidates are `sword_block_<side>`, then `sword_block_high`.
    - maul: `maul_block`.
    - rapier: `rapier_parry`, held at `contact` instead of `set`.
    - crossbow: none.
  - **Showing a block:**
    - `from` → `set` over 0.12 s from when guarding began (`_block_since`), then hold at `set`.
    - `react_block` stamps `_block_hit_at`. For `settle − impact` seconds after that, time is `impact + (now − _block_hit_at)`, then back to `set`.
  - **`static func hit_side(push_local: Vector3) -> StringName`:**
    - `from := -push_local`; `a := rad_to_deg(atan2(-from.x, -from.z))`.
    - |a| ≤ 45 → `front`; |a| ≥ 135 → `back`; a > 0 → `left`; otherwise `right`.
  - **`_hit_clip(direction, strength) -> StringName`:** `"shared_hit_<side>_<heavy if strength >= 0.9 else light>"` when `Clips.has` it, else `&""`.
    - `react_hit` then sets `_flinch` to it, shown at weight 1.0, or to today's pick at `REACT_WEIGHT`.

- [ ] **Step 1: Write the failing checks**
  - H10 blocked: at recovery u = 0.3 the time is `sword_bounce_high`'s `recoil`, and at u = 1 it is `ready`.
  - H11 parried: 0.3 s into a 1.5 s reel the time is `recoil`. 0.25 s before the end, it is halfway from `recoil` to `ready`.
  - H12 block sides:
    - an overhead gets `sword_block_high`;
    - a left gets `sword_block_left` when that is registered, otherwise `sword_block_high`;
    - with no sword blocks registered, today's `Sword_Block` plays.
  - H13 a blow on the block plays `impact` to `settle` at 1× speed, then returns to `set`.
  - H14 `hit_side`: pushes (0,0,1) front, (0,0,−1) back, (1,0,0) left, (−1,0,0) right; and `(sin θ, 0, cos θ)` gives front at θ = 44° and left at θ = 46°.
  - H15 strength: 0.89 gives `…_light` and 0.9 gives `…_heavy` (both registered).
  - H16 during a wind-up, a hit leaves the shown clip as the attack, but `rig._tilt_v` changes.
  - H17 the brute (maul) and the duelist (female) play `shared_hit_front_heavy`. Their weapon stays a child of the `hand_r` BoneAttachment3D, and no error is logged. (Review Focus 2.)

- [ ] **Step 2: Run to verify it fails.** Run `Godot … res://tests/hema_test.tscn`. Expected: H10–H17 FAIL.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run to verify it passes.** Expected: H1–H17 PASS, and `duel_test`, `exchange_test` and `combat_test` stay PASS.

- [ ] **Step 5: Commit** with message `feat(anim): clash bounce-backs, blocks by side, hits by direction`.

### Task 9: Blows bend toward you

**Files:**
- Modify: `scripts/Visual/Posture.gd`, `scripts/AISystem/GuardRig.gd`, `tests/hema_test.gd` (H18–H21)

**Interfaces:**
- **Posture:**
  - `var aim_pitch := 0.0` (radians; positive bends him forward and down, which is a turn of −aim_pitch about his right axis).
  - `var aim_yaw := 0.0` (radians; positive turns him to his left, about his up axis).
  - Both are smoothed at rate 10/s, clamped to ±25° and ±20°, and applied after the hips over `spine_01`, `spine_02` and `spine_03` in shares 0.3, 0.35 and 0.35.
- **`static func GuardRig.aim_angles(target_local: Vector3, reach: float, size: float) -> Vector2`** returns pitch in x and yaw in y, in radians, unclamped:

```
shoulders := Vector3(0.0, 1.45 * size, 0.0)
authored := Vector3(0.0, 1.35, -reach) - shoulders
actual := target_local - shoulders
pitch := atan2(-actual.y, Vector2(actual.x, actual.z).length()) - atan2(-authored.y, Vector2(authored.x, authored.z).length())
yaw := atan2(-actual.x, -actual.z)
```

- **Driving it:**
  - `target_local` is your chest in his frame: the player's `neck` global position minus 0.3 m up, through `guard.global_transform.affine_inverse()`.
  - `reach` is `guard._fighter.reach_of(kind)`.
  - GuardRig sets Posture's aim during the wind-up and strike of a HEMA attack, and sets it to 0 otherwise.

- [ ] **Step 1: Write the failing checks**
  - H18 you crouch 1.8 m ahead: pitch > 0, and `spine_03`'s forward tips down by the applied angle, within 1°.
  - H19 you stand 60° to his side mid-wind-up: yaw clamps at 20°.
  - H20 outside wind-up and strike, the aim eases back to 0 within 0.5 s.
  - H21 you stand straight ahead at his reach: |pitch| < 2° and |yaw| < 1°.

- [ ] **Step 2: Run to verify it fails.** Expected: H18–H21 FAIL.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run to verify it passes.** Expected: H1–H21 PASS, and `stealth_test` and `bodies_test` stay PASS.

- [ ] **Step 5: Commit** with message `feat(anim): guards bend their blows toward where you are`.

### Task 10: First-person clip mode

**Files:**
- Modify: `scripts/Visual/ArmReach.gd`, `scripts/Interaction/ViewArms.gd`, `scripts/Interaction/HandSlot.gd`, `scripts/Combat/PlayerCombat.gd`, `tests/hema_test.gd` (H22–H28)

**Interfaces:**
- **ArmReach:** `var animated: Array[bool] = [false, false]`. `_curl` skips an animated side, so its fingers come from the clip.
- **ViewArms:**
  - `show_clip(clip: StringName, time: float) -> void`, which is `man.show_action(clip, time, 0.08, 1.0)`;
  - `clear_clip() -> void`, back to its `Idle` at 0.4 s;
  - `hand_frame(side: int) -> Transform3D`, the hand bone's frame in ViewArms' parent's space (the view's small world, scale included).
- **HandSlot:**
  - `set_arm_clip(clip: StringName, time: float) -> void`: combat calls it every physics tick. It is stored per tick and interpolated between the last two ticks, the way `set_weapon_frame` is.
  - `clear_arm_clip() -> void`.
  - `clip_weight() -> float`: moves toward 1 while a clip arrived within the last 2 physics ticks, otherwise toward 0, at 1/0.15 per second.
  - In `_place_hands`, with weight `w`:
    - `_arms.show_clip(...)` while w > 0, and `_arms.clear_clip()` once w reaches 0;
    - the right hand's IK weight is multiplied by (1 − w), and `reach.animated[RIGHT] = w > 0.5`. The left side is the same, unless HandContacts has the left hand.
    - the weapon's `_main.transform` blends today's frame with `hand_frame(RIGHT) * grip` by w, where `grip = Clips.grip(&"sword", arms.man.skeleton, HAND_GRIP)`;
    - the sway, bob, recoil and shudder turns and offsets apply × (1 − w) to the weapon frame and × w to `_arms`, about its origin (the eye).
- **PlayerCombat:** a new `var _charge_time := 0.0`, reset on entering CHARGING and advanced while charging. A new `var _ready_clock := 0.0`.
  - **`_fp_clip(delta: float) -> Array`** returns `[clip, time]` or `[]`:
    - `[]` unless all of these hold: `weapon.id == &"sword"`, `Clips.has(&"fp_sword_ready")`, not blocking, not `_drop_armed`, and the phase is not DRAWING, KICK or STAGGER.
    - IDLE and DODGE: `fp_sword_ready` at `fmod(_ready_clock, length)`. `_ready_clock += delta` on every call.
    - WINDUP, CHARGING, STRIKE and RECOVER: `clip = "fp_sword_" + _direction`, and `[]` unless `Clips.has(clip)`. With `m = Clips.markers(clip)`:
      - WINDUP: `lerp(m.from, m.cocked, ease_out(_t / _windup))`
      - CHARGING: `minf(m.cocked + _charge_time, m.release)`
      - STRIKE: `lerp(start, m.follow, _t / _strike_time)`, where `start` is `m.release` after a charge, otherwise `m.cocked`
      - RECOVER: `lerp(m.follow, m.ready, _t / _recovery)`
  - **Feint:** `_feint()` records the attack clip and the time it had reached, in `_feint_clip` and `_feint_from`.
    - For the next 0.2 s, `_fp_clip` returns that clip at `lerp(_feint_from, m.from, ease_in_out(elapsed / 0.2))`, playing the wind-up back.
    - Then IDLE shows `fp_sword_ready`.
    - Blocking takes precedence; if you are holding block, the result is `[]`.
  - **`_send_pose`** calls `_hand(&"set_arm_clip", fp)` when `fp` is non-empty, otherwise `_hand(&"clear_arm_clip", [])`. It keeps computing today's frame either way, so HandSlot can blend.

- [ ] **Step 1: Write the failing checks.** Register synthetic `fp_sword_ready` and `fp_sword_overhead`, with markers from 0, cocked 0.1, release 0.2, contact 0.3, follow 0.4, done 0.55 and ready 0.7.
  - H22 at rest, the arms show `fp_sword_ready`, and `clip_weight()` reaches 1 within 0.2 s.
  - H23 an overhead swing:
    - the wind-up ends on `cocked`;
    - the strike starts at `cocked` uncharged, or at `release` after a charge;
    - the strike ends on `follow`;
    - the recovery ends on `ready`;
    - a feint at `cocked` plays back to `from` within 0.2 s, then shows `fp_sword_ready`.
  - H24 a left swing (no clip) blends back to today's frame: `clip_weight()` is 0 within 0.2 s.
  - H25 in clip mode, the weapon's grip point is within 1 mm of `hand_frame(RIGHT) * grip`.
  - H26 in clip mode, the right hand's IK weight is 0 and `reach.animated[1]` is true.
  - H27 under `TimeFx.request(get_tree(), &"test", 0.3, 5.0)`, the ready loop's clip time advances 0.3 × the real time elapsed (±10%). (Review Focus 3.)
  - H28 switching to the dagger mid-strike: `clip_weight()` reaches 0 within 0.15 s, and the weapon never moves more than 0.1 m between frames. (Review Focus 4.)

- [ ] **Step 2: Run to verify it fails.** Expected: H22–H28 FAIL.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run to verify it passes.** Expected: H1–H28 PASS. Also run `life_test`, `interaction_test`, `smooth_test` and `feel_test` and confirm they stay PASS. They cover the procedural arms and hands, and nothing real is registered outside hema_test.

- [ ] **Step 5: Commit** with message `feat(anim): first-person sword plays keyed clips, with procedural fallback`.

### Task 11: The head leads (camera)

**Files:**
- Modify: `scripts/PlayerUtils/CameraJuice.gd`, `scripts/Interaction/HandSlot.gd`, `tests/hema_test.gd` (H29–H32)

**Interfaces:**
- **CameraJuice:**
  - `const CLIP_MAX_OFFSET := 0.04` and `const CLIP_MAX_DEGREES := 3.0`;
  - `var clip_comfort := 1.0` and `var clip_offset := Transform3D.IDENTITY`;
  - `set_clip_offset(offset: Transform3D) -> void` caps the translation at 0.04 m and the rotation angle at 3°, then scales both by `clip_comfort` (translation × c, rotation slerped from identity by c);
  - `view_transform()` returns today's transform `* clip_offset`.
- **HandSlot:**
  - In clip mode, each frame it calls `player.juice.set_clip_offset(Transform3D.IDENTITY.interpolate_with(Clips.camera_offset(clip, time), w))` and sets its own `transform` (the `Hand` node under `Camera3D`) to `player.juice.clip_offset.affine_inverse()`.
  - Out of clip mode, it sets both to the identity.

- [ ] **Step 1: Write the failing checks**
  - H29 a synthetic `fp_sword_overhead` camera sample of 2 cm right, at t: `juice.view_transform().origin.x` gains 0.02 at that time.
  - H30 a 10 cm, 10° sample is capped to 4 cm and 3°.
  - H31 with `clip_comfort = 0`, the offset is the identity.
  - H32 the hand bone's world position is the same with and without the offset, within 1 mm: the arms stay anchored.

- [ ] **Step 2: Run to verify it fails.** Expected: H29–H32 FAIL.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run to verify it passes.** Expected: H1–H32 PASS, and `feel_test` and `smooth_test` stay PASS.

- [ ] **Step 5: Commit** with message `feat(anim): first-person clips lead with the head, capped for comfort`.

### Task 12: Contact sheets

**Files:**
- Modify: `tests/visual/stage_clips.gd`, `tests/visual/stage_clips.tscn` (the existing filmstrip stager)

**Interfaces:**
- New flags, each producing one PNG sheet per clip per view in `--out`, named `<clip>_<view>.png`:
  - `--markers`: frames at every marker plus every third frame. Clips without markers fall back to `--steps`.
  - `--compare`: a second guard beside the first plays `Clips.legacy_of(clip)` at the same fraction of its length.
  - `--views=front,side,three_quarter` (all three by default).
  - `--eye`: for `fp_` clips, a camera at the ViewArms eye with a 75° field of view, a `ViewArms` rig showing the clip, and the weapon at `hand_frame(RIGHT) * grip`.
  - `--retro`: the Retro pixel grid at 640×360.

- [ ] **Step 1: Run before the change to see it fail**

Run: `perl -e 'alarm 300; exec @ARGV' Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_clips.tscn -- --clips=shared_probe --markers --retro --out=<scratchpad>/sheets`
Expected: there is no `shared_probe_front.png`, `shared_probe_side.png` or `shared_probe_three_quarter.png`.

- [ ] **Step 2: Implement** the flags.

- [ ] **Step 3: Run it again.** Expected: the three PNGs exist.

- [ ] **Step 4: Open the PNGs.** Confirm the three angles, the retro grid, and (with `--compare` on `Sword_Idle`-backed clips) the side-by-side legacy figure.

- [ ] **Step 5: Commit** with message `feat(anim): contact sheets by marker, angle, eye view and old-vs-new`.

### Task 13: The animation bay (NPC gym bay 9)

**Files:**
- Modify: `maps/npc_gym.gd`:
  - `BAYS` gets a 9th entry, `["ANIMATION", Vector3(-17, 0, -80), -1, <sign listing the keys>]`;
  - key `KEY_9` calls `_start_bay(8)`;
  - the back wall moves from z −72 to −90 and the corridor extends to match;
  - bay-9 key handling.
- Modify: `scripts/Visual/TimeFx.gd`, adding `static func cancel(id: StringName) -> void`
- Modify: `tests/gym_test.gd` (G1 covers bay 9; G5–G7 are new)

**Interfaces:**
- **Bay 9:**
  - A pedestal and one swordsman with physics and rig processing turned off.
  - The bay calls `man.show_action(clip, t, 0.0, 1.0)` every frame, cycling `Clips.names()` minus `shared_probe` and `fp_` clips. You watch the `fp_` clips on your own arms by swinging.
  - A `Label3D` shows `clip  time  marker`.
- **Keys,** active only in bay 9:
  - `[` and `]`: previous and next clip;
  - `P`: pause;
  - `-` and `=`: speed steps 0.25×, 0.5×, 1×;
  - `.`: jump to the next marker and pause;
  - `O`: switch between old and new (`Clips.legacy_of(clip)` at the same fraction);
  - `T`: toggle `TimeFx.request(get_tree(), &"anim_bay", 0.25, 3600.0)` / `TimeFx.cancel(&"anim_bay")`.
- **`TimeFx.cancel(id)`** removes that one request and reapplies the rest.

- [ ] **Step 1: Write the failing checks** in `gym_test`. Register the synthetic sword clips first, and drive keys through `gym._unhandled_input` with a pressed `InputEventKey` carrying `physical_keycode`.
  - G1 is extended: bay 9 starts with exactly one guard, its physics off, showing a HEMA clip (or `Sword_Idle` when none is registered).
  - G5 `9` starts bay 9, and `man.shown()[0]` is the first bay clip.
  - G6 `]` moves to the next clip. `.` lands on the next marker's time and pauses there.
  - G7 `O` on `sword_overhead` shows `Sword_Attack`, and `T` makes `TimeFx.is_active(&"anim_bay")` true, then false.

- [ ] **Step 2: Run to verify it fails.** Run `Godot … res://tests/gym_test.tscn`. Expected: G1 and G5–G7 FAIL.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run to verify it passes.** Expected: G1–G7 PASS, and `squad_test` stays PASS.

- [ ] **Step 5: Commit** with message `feat(anim): animation bay in the NPC gym`.

### Task 14: References and technique notes for the proof

This task is gated: it starts only once the user has sent references, each as a link, a timestamp range, the technique's name and the character it's for. The five techniques are:
- a one-handed sword guard stance;
- an overhead cut;
- a side cut;
- a high block;
- a heavy hit to the front.

**Files:**
- Create: `assets/characters/animations/source/notes/{stance,overhead,left,block_high,hit_front_heavy}.md`
- Stills go in `source/reference/<technique>/` and are git-ignored.

**Definitions used by the notes:**
- `sword_left` is the forehand: from high on his right, across and down to his left.
- `sword_right`, in batch 2, is the backhand.
- `fp_` versions use the same technique, reframed for the camera.

- [ ] **Step 1: Pull stills.** Grab one every 0.1 s over each timestamp range. For YouTube, draw the paused `<video>` onto a canvas in the browser pane (no download). For local files, use `ffmpeg -ss <a> -to <b> -vf fps=10`.
- [ ] **Step 2: Write each note:**
  - the sources and timestamps;
  - the key pose at each marker, in our own words;
  - the timing, read at real speed;
  - the gameplay changes. For the swordsman: the wind-up is `windup_time` 0.52 s × `ATTACKS[kind].windup` (overhead 0.52 s, left 0.44 s), with the coil taking the hold, and the recovery is 0.5 s × `ATTACKS[kind].recover`.

  No text copied from modern translations; link to them.
- [ ] **Step 3: Commit the notes** with message `docs(anim): technique notes for the proof clips`.

### Task 15: Key the stances: `sword_stance` and `fp_sword_ready`

**Files:**
- Create: `assets/characters/animations/source/sword.blend`, plus the `HEMA_sword.*` exports
- Modify: `tests/anim_test.gd` (A21)

- [ ] **Step 1: Write the failing check.**

```gdscript
const PROOF := [&"sword_stance", &"sword_overhead", &"sword_left", &"sword_block_high", &"sword_bounce_high", &"shared_hit_front_heavy", &"fp_sword_ready", &"fp_sword_overhead"]
_check("A21 the proof clips all exist", missing.is_empty(), "missing %s" % [missing])
```

- [ ] **Step 2: Run it.** Expected: A21 FAILS, listing all 8.
- [ ] **Step 3: Build the file.** `Blender -b --factory-startup --python tools/anim/build_rig.py -- --family sword --out assets/characters/animations/source/sword.blend`
- [ ] **Step 4: Key both loops,** about 2 s each, following the stance note:
  - breathing and a small weight shift;
  - `fp_sword_ready` framed low and right in `HeadCam`.
- [ ] **Step 5: Export and run the checks.** Run `bash tools/anim/export_clips.sh sword`, then `anim_test`. Expected: A20 passes for both clips; A21 still lists the other 6.
- [ ] **Step 6: Review the sheets.** Render them (`--markers --retro`, plus `--eye` for `fp_sword_ready`) and compare against the stills. Revise until the stance reads as the note's guard.
- [ ] **Step 7: Commit** with message `feat(anim): sword stance and first-person ready`.

### Task 16: Key the attacks: `sword_overhead`, `sword_left` and `fp_sword_overhead`

- [ ] **Step 1: Read the timing targets.** Swordsman: wind-up 0.52 s × the attack's windup factor, recovery 0.5 s × its recover factor. Player: read `_windup`, `_strike_time` and `_recovery` for an overhead from a scratch run that prints them.
- [ ] **Step 2: Block out each clip.** Set stepped keys at the markers, following the overhead and left notes, and render them next to the stills.
- [ ] **Step 3: Refine.**
  - Work the spacing: fast in, hold on the hit, ease out.
  - Add overlap (hips lead, chest follows, then arm), follow-through and settle.
  - The side cut must be a wide swing driven by the body turn, not a flick. That was the user's earlier complaint.
  - The first-person anticipation starts off-screen.
- [ ] **Step 4: Export and run the checks.** Run `bash tools/anim/export_clips.sh sword`, then `anim_test`. Expected: A20 passes for all three, including contact at reach 1.8 m for the overhead and 1.9 m for the left, and the framing checks for `fp_sword_overhead`.
- [ ] **Step 5: Regression run.** Run `hema_test`, `duel_test`, `combat_test` and `feel_test`, with the real clips now loaded. All must PASS.
- [ ] **Step 6: Review the sheets** with `--markers --compare --retro`, plus `--eye`, and revise until they read right.
- [ ] **Step 7: Commit** with message `feat(anim): overhead and side cut, guard and first person`.

### Task 17: Key the clash and the hit: `sword_block_high`, `sword_bounce_high` and `shared_hit_front_heavy`

- [ ] **Step 1: Key `sword_block_high`.** Markers from, set, impact and settle, where the settle pose equals set. It catches the overhead.
- [ ] **Step 2: Key `sword_bounce_high`.** It starts from `sword_overhead`'s contact pose, recoils back and up, and ends in the stance.
- [ ] **Step 3: Key `shared_hit_front_heavy`** in `shared.blend`. Markers impact, peak and ready: head and shoulders driven back, a step back to catch the weight, then the sword stance.
- [ ] **Step 4: Export and run the checks.** Run `bash tools/anim/export_clips.sh all`, then `anim_test`. Expected: A1–A21 PASS.
- [ ] **Step 5: Review in the game.** Run `hema_test`, `duel_test` and `exchange_test` (all PASS), and view the clash in bay 9 at 0.25×.
- [ ] **Step 6: Commit** with message `feat(anim): high block, bounce-back and heavy front hit`.

### Task 18: The batch-1 review package

- [ ] **Step 1: Full regression.** Every suite must be all PASS with 0 FAIL:

```bash
for t in tests/*_test.tscn; do echo "== $t"; /Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . "res://$t" 2>/dev/null | grep -E "^(PASS|FAIL)" | sort | uniq -c | awk '{print $1, $2}' | sort -u; done
```

  Also run the Blender suite, which must exit 0.
- [ ] **Step 2: Render the review sheets:** all 8 clips with `--markers --compare --retro`, plus `--eye` for the two `fp_` clips.
- [ ] **Step 3: Update the project memory** with the pipeline commands, the gotchas found, and the batch status.
- [ ] **Step 4: Commit** with message `chore(anim): batch 1 proof ready for review`.
- [ ] **Step 5: Hand over and stop.** Send the user the sheets and the bay-9 key list, and stop. Batch 2 waits for their verdict.
