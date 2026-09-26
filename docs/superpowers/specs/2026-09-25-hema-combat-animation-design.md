# HEMA Combat Animation: Design

**Date:** 2026-09-25
**Status:** design approved section by section in conversation; this document awaits the user's review.

## 1. Goal

More detailed combat animation for every character, with more weight and a grittier feel. The target is a mix of Dark Messiah of Might and Magic, Chivalry and Sekiro, grounded in historical European martial arts (HEMA). Claude hand-animates it in Blender from references the user supplies. The combat rules do not change.

## 2. Decisions

| Question | Decision |
|---|---|
| Where the animation comes from | Original hand-keyed clips, built from HEMA references and game inspirations. No motion-capture packs, and no tracing of anyone's commercial animation. |
| Weapons | Every character keeps its weapon: one-handed sword (watchmen, swordsmen, arms master), rapier (duelist), maul (brute), crossbow with kicks (archer). |
| The player | Included: the player's first-person sword. The dagger, blackjack and bow stay as they are. |
| Rules | Looks only. Every current rule, timing and number stays. |
| Approach | **Blender studio:** clips keyed on a control rig in Blender 5.2 LTS and exported to Godot. The user chose it over a technique library authored in Godot and over fully procedural animation. It is the option where every clip can be opened and fixed by hand in Blender. |

What each inspiration brings:
- **Chivalry:** big, directional wind-ups you can read.
- **Sekiro:** blade-on-blade clashes as hard, crisp moments, with a rebound, sparks and a jolt through both bodies.
- **Dark Messiah:** bodies that react to where and how hard they are hit.
- **HEMA:** real guards and cuts, with power coming from the hips and the footwork.

Reference sources per weapon:
- **One-handed sword:** Fiore's sword in one hand, Marozzo's *spada sola*, Lecküchner's messer.
- **Rapier:** Capo Ferro, Fabris.
- **Maul:** pollaxe manuals (Le Jeu de la Hache, Fiore's axe).
- **The archer's kicks and shoves:** *Ringen* (wrestling).
- **Crossbow reloading:** period art.

## 3. Scope

**In scope:**
- stances;
- every current attack;
- blocks, parries, ripostes and feints;
- bounce-backs off blocks;
- reactions to hits, by direction and strength;
- broken guard and get-ups;
- kicks, footwork and backsteps;
- paired finishers;
- crossbow handling;
- the player's first-person sword.

**Out of scope:**
- new combat mechanics (blades locking in a bind, winding);
- the player's dagger, blackjack and bow;
- drawing and sheathing;
- patrol and ambient idles;
- deaths (ragdolls stay);
- attacks that travel further than today's rules allow;
- a separate field of view for the first-person arms.

## 4. Success criteria

- Each character type fights in a clearly different, recognisably HEMA-grounded way.
- Every enemy attack can be read from its wind-up.
- Hits and clashes feel heavy.
- Nothing pops or jumps between moves.
- All existing test suites still pass (the rules are unchanged), and the new animation checks in section 10 pass.
- The user approves each batch in the NPC gym.

## 5. Pipeline

### 5.1 Files

```
assets/characters/animations/
  HEMA_sword.glb, HEMA_sword.beats.json         exported; imported by Godot
  HEMA_rapier.*, HEMA_maul.*, HEMA_crossbow.*, HEMA_shared.*
  source/                                        has .gdignore: Godot never imports it
    sword.blend, rapier.blend, maul.blend, crossbow.blend, shared.blend
    notes/<technique>.md                         technique notes (section 9)
    reference/                                   stills for study; git-ignored
    backup/                                      copies saved before each export; git-ignored
tools/anim/
  build_rig.py                                   builds or refreshes the control rig in a family file
  export_clips.py                                validates and exports one family file
  export_clips.sh                                headless runner: export_clips.sh <family|all>
```

Each family file holds one rig and many actions. One file per weapon keeps files small, so a crash can damage at most one.

### 5.2 The rig (`build_rig.py`)

The rig is built on the Quaternius base skeleton, imported from `assets/characters/base/Superhero_Male_FullBody.gltf`. The rapier file previews on the female body; both bodies share the skeleton.

- **Deform flags:** every game-skeleton bone is marked deform and every control bone is not, so the export keeps only the game skeleton.
- **Grip control:** the weapon is parented to it. You animate the weapon, and the hand IK targets ride on it. One-handed weapons drive the right hand. The maul and the crossbow also drive the left hand, from a second grip point on the weapon.
- **Other controls:** foot IK targets with knee poles, elbow poles, and a hips control.
- **Spine, neck and head** are posed directly (FK). A finger-curl property closes the fingers around the grip.
- **Weapon props** are appended from `assets/weapons/source/weapons.blend`, for preview only.
- **Head camera:** rides the head bone. In the ready pose it sits at the ViewArms eye point (`ViewArms.EYE`, converted to Blender axes). It uses the player camera's vertical field of view, read from the player scene. Sensor fit is vertical, to match Godot's keep-height camera. It is used for first-person clips and preview renders.
- **Frame rate:** the scene runs at 30 fps.
- **Position keys:** only the root and pelvis carry them. Every other bone is rotation-only, so clips fit both base bodies' proportions.
- **Export button:** each file carries a small `export.py` text block that runs `tools/anim/export_clips.py` on the open file. Run Script exports after a hand edit.
- **Blender version:** the scripts target Blender 5.2's layered (slotted) actions.

### 5.3 Markers

Timing points are timeline markers on each action (pose markers). The export writes them to the beats file, and the game reads them instead of hand-typed tables.

| Clip type | Required markers, in order |
|---|---|
| Attack (guards and first person) | `from`, `cocked`, `release`, `contact`, `follow`, `done`, `ready` |
| Block | `from`, `set`, `impact`, `settle` |
| Parry | `from`, `contact`, `ready` |
| Bounce-back | `contact`, `recoil`, `ready` |
| Hit reaction | `impact`, `peak`, `ready` |
| Broken guard, going down | `impact`, `down` |
| Broken guard, getting up | `down`, `ready` |
| Get-up | `from`, `ready` |
| Kick | `from`, `chamber`, `contact`, `retract`, `ready` |
| Crossbow shot | `fire`, `ready` |
| Crossbow reload | `from`, `spanned`, `ready` |
| Roar | `from`, `peak`, `ready` |
| Evasion (backstep, sidestep) | `from`, `land`, `ready` |
| Finisher, both halves | `from`, `contact`, `kill`, `done` |
| Stance, steps, aim | none; the action gets a `loop` custom property |

What the attack markers mean:
- `from`: the wind-up starts.
- `cocked`: the top of the wind-up.
- `cocked` to `release`: **the coil**, a moving hold that tightens rather than freezing.
- `contact`: the blade meets the target.
- `follow`: the blade's travel ends.
- `done`: the body has settled.
- `ready`: back on guard, matching the stance.

### 5.4 Export (`export_clips.py`)

1. Validate every action (section 11.1). Stop at the first failure, naming the action and the problem.
2. Save a backup copy of the file to `source/backup/<file>-<timestamp>.blend` (`save_as_mainfile(copy=True)`), keeping the last five.
3. Export a skeleton-only GLB. Only deform bones are included, animation is sampled at 30 fps with constraints and IK baked in, and there is one glTF animation per action. The only mesh is a one-triangle proxy skinned to `root`, so Godot imports a Skeleton3D exactly as it does for the Quaternius files.
4. Write `HEMA_<family>.beats.json`, plus a `.import` stub (`importer="animation_library"`, the UAL files' parameters) if one doesn't exist yet.

It runs headless (`Blender -b <file> --python tools/anim/export_clips.py`), so Blender needs its window open only while animating.

The beats file holds:
- **`family`** and **`fps`**.
- **`weapon`:** the weapon's transform at the first frame of the family stance, in glTF model space, as 12 floats (basis x, y, z, then origin). Godot works out the grip offset from it and the stance's hand pose, so bone-axis conventions never have to match by hand.
- **`clips`:** per clip, its `kind`, its `length` in seconds, `loop`, `travelling` (section 6.2), and `markers` as name to seconds. First-person clips also carry `camera`: one sample per frame of the head camera's offset from its ready pose, in the camera's own frame, as `[t, px, py, pz, qx, qy, qz, qw]`.
- **`second_grip`** (batch 5): the second grip point in the weapon's space, for two-handed weapons.
- **`pairs`** (batch 2): per first-person finisher, the victim's clip, plus the victim's `offset` from the player on the floor as x, z and yaw.
- **`probe`:** shared file only. For one frame of `shared_probe`, measured in Blender: the world positions of the main bones, the weapon's transform, and its blade tip. Used by the round-trip test.

Example:

```json
{
  "family": "sword",
  "fps": 30,
  "weapon": [0, 1, 0, 0, 0, 1, 1, 0, 0, -0.21, 1.02, 0.31],
  "clips": {
    "sword_overhead": {
      "kind": "attack",
      "length": 1.53,
      "loop": false,
      "travelling": false,
      "markers": {"from": 0.0, "cocked": 0.33, "release": 0.5, "contact": 0.63, "follow": 0.8, "done": 1.13, "ready": 1.53}
    }
  },
  "pairs": {
    "fp_sword_finisher_front": {"victim": "sword_victim_front", "offset": [0.0, -1.1, 3.1416]}
  }
}
```

### 5.5 Safety

- A backup copy is saved before every export.
- The family files and exports are committed with each batch, with the user's go-ahead.
- `build_rig.py` can rebuild a file's rig without touching its actions.

## 6. The clips

72 clips. Names are `<family>_<move>`, and first-person clips start with `fp_`.

### 6.1 List

**`shared`** (everyone), 18 clips:
- `shared_hit_{front,back,left,right}_{light,heavy}` (8)
- `shared_broken_down`, `shared_broken_up` (2)
- `shared_getup_face_down`, `shared_getup_face_up` (2)
- `shared_kick` (1)
- `shared_step_{forward,back,left,right}`, `shared_backstep` (5)
- plus `shared_probe`, a test pose for the round-trip check that the game never plays

**`sword`** (watchmen, swordsmen, arms master), 14 clips:
- `sword_stance`
- `sword_overhead`, `sword_left`, `sword_right`, `sword_thrust`, `sword_sweep`, `sword_bash`
- `sword_block_{high,left,right}`
- `sword_parry_{high,low}`
- `sword_bounce_{high,side}`

**`sword`, first person** (the player), 14 clips plus 2 victim halves:
- `fp_sword_ready`
- `fp_sword_overhead`, `fp_sword_left`, `fp_sword_right`, `fp_sword_thrust`; charged holds use each clip's coil
- `fp_sword_block`, `fp_sword_parry`, `fp_sword_riposte`
- `fp_sword_bounce`, `fp_sword_stagger`, `fp_sword_kick`, `fp_sword_drop`
- `fp_sword_finisher_front`, `fp_sword_finisher_back`, with the victim halves `sword_victim_front` and `sword_victim_back`

**`rapier`** (duelist), 11 clips:
- `rapier_stance`
- `rapier_left`, `rapier_right`, `rapier_thrust` (a Capo Ferro lunge that recovers), `rapier_overhead`, `rapier_sweep`, `rapier_leap`
- `rapier_parry`, `rapier_sidestep`
- `rapier_bounce_{high,side}`

**`maul`** (brute), 9 clips:
- `maul_stance`
- `maul_heavy`, `maul_overhead`, `maul_left`, `maul_sweep`, `maul_charge`
- `maul_block`, `maul_roar`, `maul_bounce`

**`crossbow`** (archer), 4 clips:
- `crossbow_ready`, `crossbow_aim`, `crossbow_shoot`
- `crossbow_reload`, spanned with a lever. The lever is a small low-poly prop, modelled in the crossbow batch.

Reused rather than new:
- Guards' feints and ripostes reuse the attack clips at the rules' feint and riposte timing, as today.
- The guards' `lunge` plays the family's thrust with today's leg overlay stepping under it.
- The duelist blocks with `rapier_parry`, held at its `contact` pose.
- Deaths stay ragdolls.

### 6.2 Travel

- **Travelling clips** are `rapier_leap`, `maul_charge`, `rapier_sidestep`, `shared_backstep` and `shared_step_*`. The root's travel is taken off the mesh. The guard's body moves by the rules' distance, on the timing of the clip's root: distance(t) = rule distance × root progress(t). The keyed travel is within ±15% of the rules' distance, so feet don't skate.
- **Every other clip is in place.** It may step out and back within the clip (a lunge that recovers), but it ends within 10 cm of where it started. The body doesn't move; the mesh plays the keyed root motion.

### 6.3 Start and end poses

- **Family stance:** `<family>_stance`, or `crossbow_ready` for the crossbow. For first-person clips it's `fp_sword_ready`.
- **End pose:** every clip ends on its family stance. Shared clips end on `sword_stance`, and other families blend from it into their own stance over 0.2 s.
- **Start pose:** every clip starts on the same stance, except those that begin from another move: reactions (including `fp_sword_stagger`), bounce-backs, get-ups, `shared_broken_up` and the victim halves.
- **Exempt from the end rule:**
  - `shared_broken_down`, which ends kneeling;
  - blocks, which end on their `set` pose (the game blends out to the stance when the block drops);
  - the victim halves, which end dead.
- **Loops** (stances, steps, `crossbow_aim`) are exempt from both rules. They must be seamless instead.

## 7. Third person: how guards play clips

### 7.1 Loading

`scripts/Visual/Clips.gd` (new) loads the HEMA GLBs and beats files once and merges the clips into `Humanoid.library()`. It answers:
- whether a clip exists;
- its kind and markers;
- a bone pose at any time, sampled straight from the clip's tracks;
- the weapon grip offset, worked out from `weapon` and the stance's hand pose;
- the first-person camera offset;
- the root progress curve, sampled from the root track at load (batch 3);
- the finisher pairs (batch 2).

### 7.2 Stance and footwork

- **Family:** the archetype's weapon picks the family: `sword` for watchmen, swordsmen and the arms master, then `rapier`, `maul`, `crossbow`. The family's stance replaces `Sword_Idle` and `Pistol_Idle` as the fighting idle.
- **Footwork:** in a fight, at walking pace and below, the legs play a 2D blend of `shared_step_*` by the direction of motion. The arms keep the stance through the existing upper-body filter. Faster than walking, today's run cycle with the hips turned stays.
- **Shared clips:** the steps and the kick use only the legs and body; the arms come from the character's own stance. Reactions, broken guard and get-ups play whole.
- **Weapons:** they attach to `hand_r` at the grip offset worked out from the export (section 7.1), so the grip matches Blender.

### 7.3 Attacks

- **Clip choice:** GuardRig maps each attack kind to `<family>_<kind>`; for example, the brute's `heavy` plays `maul_heavy`. A kind without a new clip falls back to today's `SWINGS` entry (section 11.2).
- **Timing:** the rules still set each phase's length.
  - Wind-up: `from` to `cocked` quickly, as today's gather. Then the coil, `cocked` to `release`, is stretched across the telegraph hold, so it's a moving hold and never a freeze. Then `release` to `contact` over the rules' release time.
  - Strike: `contact` to `follow`.
  - Recovery: `follow` to `done` to `ready`. This replaces the separate `_Rec` clips.
- **Strength:** clips play at full weight; today's 0.74–0.92 damping goes.
- **Chains:** a chained blow crossfades over 0.08 s into the next clip's wind-up, as today.

### 7.4 Contact layer (at play time)

- **Clash:**
  - When a guard's blow is blocked, the existing hit-stop freezes it at contact.
  - Then the bounce-back plays from its `contact` marker, blended in over 0.05 s from the actual contact pose: `<family>_bounce_high` after overhead, heavy and leap blows, `_side` after every other kind.
  - Both bodies jolt through the existing springs, and sparks fly as today.
  - When the blow was parried instead, the bounce-back holds its `recoil` pose for the rules' reel time before finishing to `ready`.
- **Aim:**
  - `Posture.gd` gains aim pitch and yaw, spread over `spine_01` to `spine_03`.
  - During wind-up and strike, they bend the keyed blow toward the player's actual position: up to ±25° of pitch and ±20° of yaw.
  - The angle is measured against the clip's intended target, a standing man's chest at the attack's reach.
- **Blocks:**
  - Sword: overhead blows and thrusts are met with `sword_block_high`. Side cuts and sweeps are met with the block on the side of the guard's body the blow arrives at, worked out from the blow's direction in the guard's frame.
  - The brute meets every blow with `maul_block`. The duelist blocks with `rapier_parry` held at its `contact` pose. The archer doesn't block.
  - A blow landing on a block plays `impact` to `settle`, which returns to the `set` pose, and holds there.
- **Parries:** sword parries are `high` or `low` by the blow's height; only sweeps are low. The duelist has one parry for every blow. The brute and the archer don't parry.
- **Hits:**
  - The clip is `shared_hit_<direction>_<strength>`.
  - Direction comes from the blow in the guard's frame: front within ±45°, back beyond ±135°, left or right in between.
  - Strength uses today's scale (0.6 a quick cut, 1.0 a heavy blow, 1.5 a killing blow): below 0.9 is light, 0.9 and above is heavy.
  - While a guard is attacking, or shrugging a blow off under the brute's armour, the flinch stays a spring jolt so the attack isn't cut off.
- **Broken guard:** `shared_broken_down` holds at `down` for the rules' open time, then `shared_broken_up` plays.
- **Get-ups:** after a ragdoll knockdown, the face-down or face-up clip is chosen by the pelvis's orientation and blended in from the ragdoll's pose over 0.3 s.
- **Grip:** for two-handed weapons (the maul and the crossbow), a two-bone IK pass using ArmReach's solver keeps the left hand on the second grip point through blends and aiming.
- **Finishers:** the victim's half of a finisher plays through GuardRig, synced from the player's side (section 8.5).

## 8. First person: the player's sword

### 8.1 Clip mode

- **Clips drive the arms:** with the sword in hand, ViewArms plays `fp_sword_*` clips directly. ArmReach stops driving the right arm, and the left arm too unless HandContacts needs it.
- **The sword** rides `hand_r` at the same grip offset (section 7.1). Its trail, blood, glint and swing sounds keep working, since the weapon node still exists.
- **Existing effects:** sway, bob and recoil move the whole arms rig as offsets on top of the clip.
- **Ledges:** HandContacts keeps the left arm for ledges, mantles and vaults, which are already left-hand-only while a weapon is in hand.
- **Handing back:** anything that isn't sword combat hands the arms back to the procedural system (ViewPoses and ArmReach), blending over 0.15 s. That covers sprinting, carrying, two-handed climbing, frob actions, and the dagger, blackjack and bow.
- **The kick** shows ViewArms' own leg, replacing HandSlot's stand-in leg.

### 8.2 Phases to clips (`PlayerCombat`)

- **Idle:** `fp_sword_ready` loops.
- **Wind-up** (the sword's 0.1 s): `from` to `cocked`. Swings start moving on the frame you click.
- **Charging:** the coil (`cocked` to `release`) plays once, then holds its last pose with the existing charge shudder on top.
- **Strike:** `release` to `contact` to `follow`.
- **Recovery:** `follow` to `done` to `ready`. Chains crossfade over 0.08 s.
- **Direction:** mouse motion still picks overhead, left, right or thrust, and chained blows still alternate.
- **Feint:** the arms go back from the current wind-up pose to `ready` over the rules' feint time, as today.
- **Block, parry, riposte, stagger, kick and drop attack:** each plays its clip in the matching phase.
- **Your blow blocked:** `fp_sword_bounce` plays from its `contact` marker, blended from your contact pose over 0.05 s, with the camera jolt.
- **Flesh hits:** the hit-stop holds the blade, and the existing cleave slow-down stretches `contact` to `follow`.

### 8.3 Keying rules (checked in section 10)

- **Matching views:** the Blender head camera shows exactly the game's view. The arms miniature is scaled about the eye, which projects the same picture.
- **Framing (the Helsby rules):**
  - the ready pose sits low and to the right;
  - wind-ups start off-screen;
  - the blade crosses the middle band of the screen only during the strike;
  - at contact, the blade passes near the crosshair.

### 8.4 Camera

- **The head leads:** the head is keyed and leads each move with a counter-move, a lead into the swing, then settling.
- **Applied to the camera:** its motion relative to `fp_sword_ready`'s head is added to the camera, and only to the camera. It is capped at 4 cm and 3°, times a new CameraJuice comfort scale (default 1.0).
- **Arms stay put:** the arms stay anchored to the un-offset view, so the picture matches Blender's head camera.
- **Aim is unaffected:** aim comes from the neck, so the offset never moves your aim.

### 8.5 Finishers

- **Trigger:** the adrenaline power blow, thrown at a guard who can't defend (broken guard, or facing away) that the blow would kill. Otherwise the finisher stays today's slow-motion blow. Those guards can't block or dodge anyway, so the rules don't change.
- **Front or back:** front if you are within 90° of the direction the victim faces (you are in front of them), back otherwise.
- **Placement and sync:** the victim is eased into the pair's offset over 0.1 s, drops the weapon at `contact` (the existing weapon drop) and plays their half in sync.
- **Blood and dismemberment** fire at `kill`.
- **Control:** after `kill`, any input blends you out over 0.1 s. The victim finishes their half, then goes limp.
- **Fallback to today's finisher** if:
  - the placement point is blocked (checked with a shape cast);
  - the height difference is more than 0.3 m;
  - the victim's scale is outside 0.9–1.1, which rules out the brute.

## 9. References and the keying workflow

- **What the user sends,** per technique: a link, a timestamp range, the technique's name and the character it's for. Their own footage is welcome, filmed from the side at 60 fps.
- **Stills:** Claude pulls one every 0.1 s at the given timestamps. YouTube frames are grabbed in the browser pane without downloading; local files go through ffmpeg. They go to `source/reference/`, which is git-ignored. Stills are for study only and are never committed or shipped.
- **Technique notes:** `source/notes/<technique>.md` holds:
  - the source links and timestamps;
  - the key poses, described in our own words;
  - the timing, read from real-speed footage;
  - what changed for gameplay.

  No text is copied from modern translations of the manuals; the notes link to them instead.
- **Keying loop per clip:**
  1. **Block out:** set the key poses at the markers with stepped keys. Render them from the front, side and three-quarter views (plus the eye view for `fp_` clips), next to the reference stills.
  2. **Refine:** switch to smooth curves, then work the spacing (fast in, hold on the hit, ease out), the overlap (hips lead the chest, the chest leads the arm), follow-through and settle.
  3. **Test:** export, run the checks, then render in-game at the retro resolution.

## 10. Verification

### 10.1 Automated checks

These run in `tests/anim_test`, headless, on every exported clip. The thresholds are starting values, tuned during batch 1.

| Check | Threshold |
|---|---|
| Round trip | Blender's probe positions (hands, feet, head, blade tip) match Godot's within 5 mm, on the male and the female body. |
| Markers | All present for the clip's type, in order, inside the clip. |
| Grip | On two-handed weapons, the left hand stays within 1.5 cm of the second grip point. |
| Feet | A planted foot (≤ 3 cm above the floor, moving ≤ 0.25 m/s, for ≥ 3 frames) slides ≤ 1 cm. |
| Joints | Elbows and knees bend 0–155° and hyperextend ≤ 5°. Wrists bend ±80°, bend sideways ±35°, and twist ±45° against the forearm. |
| Pops | Start and end poses (section 6.3) are within 2° per bone. No bone turns more than 40° in one frame. Loops are seamless within 0.5°. |
| Travel | Travelling clips are within ±15% of the rules' distance. In-place clips end within 10 cm of where they started. |
| Contact | At `contact`, the blade crosses the target zone with its tip moving ≥ 3 m/s. The zone is a 0.25 m capsule 1.0–1.7 m high (0.1–0.6 m for sweeps) at the attack's reach in today's rules. For kicks, the foot must reach a capsule 0.7–1.2 m high at the kick range. |
| First-person framing | Ready pose: the grip is in the lower-right quarter of the screen. From `from` to `release`: ≥ 60% of blade samples are off-screen or in the outer 15% border. The middle band (the centre 24% of the screen width) is entered only between `release` and `follow`. At `contact`: the blade passes within 8% of screen height of the crosshair. |

### 10.2 Existing suites

All current suites (286 checks) stay green. Assertions about the old clips' looks get updated; none about the rules change.

### 10.3 Visual review

- **Stager:** the existing filmstrip stager, `tests/visual/stage_clips.tscn`, is extended. With `--markers`, it renders each clip at its markers and every third frame, at the retro resolution. It uses the front, side and three-quarter views, plus the eye view for `fp_` clips. `--compare` puts today's clip beside it. The contact sheets go to the user with each batch.
- **Animation bay:** bay 9 in the NPC gym (key 9). A guard on a stand, with its AI frozen, loops the batch's clips:
  - `[` and `]`: previous and next clip;
  - `P`: pause;
  - `-` and `=`: speed (0.25×, 0.5×, 1×);
  - `.`: jump to the next marker and freeze there;
  - `O`: switch between old and new;
  - `T`: quarter-speed game time inside the bay, for watching your own swings;
  - a label shows the clip, the time and the current marker.

  None of these keys is used by the game today.

## 11. Error handling

### 11.1 Export validation

The export refuses to write if any of these hold:
- a name doesn't match `^(fp_)?(sword|rapier|maul|crossbow|shared)_[a-z0-9_]+$`;
- a required marker is missing or out of order;
- the scene isn't at 30 fps;
- a loop isn't seamless;
- a clip breaks the start or end pose rule (section 6.3).

It names the action and the problem.

### 11.2 Runtime fallback

- A move without a new clip uses today's clip and `SWINGS` timings. The game keeps working between batches, and each character type switches over when its batch lands.
- A clip whose beats are missing or malformed is ignored, and the move falls back as above, with a single warning.
- The finisher's fallbacks are in section 8.5.

## 12. Components

**New:**
- `tools/anim/build_rig.py`, `tools/anim/export_clips.py`, `tools/anim/export_clips.sh`
- `assets/characters/animations/source/{sword,rapier,maul,crossbow,shared}.blend`, plus `notes/`
- `assets/characters/animations/HEMA_<family>.glb` and `.beats.json`
- `scripts/Visual/Clips.gd`
- `tests/anim_test.tscn` and its script, and `tests/anim_checks.gd` (the checks on clip data)
- `tests/hema_test.tscn` and its script (runtime behaviour)

**Changed:**
- `scripts/Visual/Humanoid.gd`: the HEMA libraries, stance per family, the footwork 2D blend, grip offsets.
- `scripts/AISystem/GuardRig.gd`: family clips with fallback, marker-driven timing with the coil, clash and bounce-backs, blocks and parries, reactions, broken guard, get-ups, kick, crossbow, roar, the finisher victim, the two-handed grip IK.
- `scripts/Visual/Posture.gd`: aim pitch and yaw.
- `scripts/AISystem/GuardFighter.gd`: travel on the clip's timing.
- `scripts/Interaction/HandSlot.gd`, `scripts/Interaction/ViewArms.gd`: clip mode and the hand-back to procedural.
- `scripts/Combat/PlayerCombat.gd`: phases to clips, the bounce-back, finisher pairs.
- `scripts/PlayerUtils/CameraJuice.gd`: the clip's head offset and the comfort scale.
- `maps/npc_gym.gd` and `maps/npc_gym.tscn`: bay 9.
- `scripts/Visual/TimeFx.gd`: `cancel(id)`, so the bay's slow motion can be switched off on its own.
- `tests/visual/stage_clips.gd`: markers, angles, eye view, old-vs-new, retro.
- `.gitignore`: reference stills and export backups.

## 13. Risks

| Risk | Mitigation |
|---|---|
| Blender's glTF import reorients bones, so clips land twisted in Godot. | The round trip is proven first, on both bodies, before any clip is keyed. If it fails, fix the importer's bone options first; Godot's humanoid retarget on import is the fallback. |
| Blender crashes or the MCP link drops mid-session. | Backups before every export, one file per weapon, commits per batch, and rigs that can be rebuilt by script. |
| Hand-keyed quality falls short. | Batch 1 is the proof; the user judges it before anything else is keyed. |
| Stretching clips to gameplay timings distorts them. | The coil absorbs most of the stretch, and clips are keyed at each archetype's actual phase lengths. |
| Blender 5.x API differences. | Scripts target 5.2 LTS only and use its layered action API. |

## 14. Rollout

Each batch ends with the user's review, and the next starts only after approval. The user supplies the references for a batch before it is keyed. Implementation plans are written per batch; the first plan covers batches 0 and 1.

| Batch | Clips | Runtime work it brings in |
|---|---|---|
| 0. Pipeline | none (only `shared_probe`) | The rig builder, the export and its validation, `Clips.gd`, the round-trip test, `.gitignore` entries. |
| 1. Proof | `sword_stance`, `sword_overhead`, `sword_left`, `sword_block_high`, `sword_bounce_high`, `shared_hit_front_heavy`, `fp_sword_ready`, `fp_sword_overhead` (8) | Family mapping with fallback, marker timing with the coil, clash and bounce-back, block and hit choice, the aim layer, first-person clip mode for idle and attacks, the camera head offset and comfort scale, the stager, the animation bay, and checks for these clips. |
| 2. Sword | the rest of `sword_*` and `fp_sword_*`, and the victim halves | First-person block, parry, riposte, bounce-back, stagger, kick and drop; finishers with their trigger and fallbacks. |
| 3. Shared | the rest of `shared_*` | Every hit direction and strength, broken guard, get-ups, the guards' kick, the footwork 2D blend, travel on the clip's timing. |
| 4. Duelist | `rapier_*` | The leap and sidestep travel. |
| 5. Brute | `maul_*` | The two-handed grip IK, the roar. |
| 6. Archer | `crossbow_*` | The lever prop; the grip IK reused. |
