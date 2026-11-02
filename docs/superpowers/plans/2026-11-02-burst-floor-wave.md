# The Burst: a Wave Up Through the Floor, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Burst becomes thick obsidian spikes tearing up through the floor in a travelling wave, hitting each enemy as it arrives, with the hand slam, cracks, reactions and collapse the spec describes.

**Architecture:** `ObsidianBurst.gd` stays the spell: it throws off what is on you, then each tick hits what the wave has reached. `BurstWave.gd` (new) draws the spikes and rubble from the modelled glass on MultiMeshes, with no gameplay. `BurstCracks.gd` (new) is the floor's cracks and scar. Enemy reactions hang off the existing `struck` path.

**Tech Stack:** Godot 4.5.1 GDScript and spatial shaders; Blender headless Python.

**Spec:** `docs/superpowers/specs/2026-11-02-burst-floor-wave-design.md`

## Global Constraints

- Unchanged: damage 35, reach 5.5 m, cost 40, cast time 0.3 s, what is thrown off. Spikes neither block nor hurt on contact.
- The wave crosses in 0.5 s (`WAVE_TIME`). Anything on you is thrown off at release, before the wave.
- Glass wears `MagicFx.obsidian_look()`, whose shader needs barycentric corners in vertex COLOR. Models are closed; the build script refuses an open edge.
- No `juice.punch` pitch (it walks the aim off): trauma and roll only.
- Effects made by us; sounds from approved packs. Missing ones go on `docs/superpowers/refs/hunt/sounds_needed.md`.
- Commit explicit file lists. Test: `G=/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot; timeout 280 "$G" --headless --fixed-fps 60 --path . res://tests/burst_spell_test.tscn`; pass means exit 0 and no `^FAIL` or `SCRIPT ERROR`.

## Review Focus

1. An enemy freed or killed before the wave reaches it: no error, no second hit (pinned in Task 2).
2. Cast against a wall or in a corridor: no hit and no spike through it (Tasks 2, 3).
3. Cast in mid-air, or with no floor under part of the ring: enemies are still hit, spikes only where there is a floor (Task 3).
4. Letting go of the key early: cracks fade, nothing is left, nothing is spent (Task 4).
5. Casting twice quickly, or the scene ending mid-wave: both waves run or free cleanly (Task 3).

---

### Task 1: The glass models (the user sees them before the wave is built)

**Files:**
- Create: `tools/magic/build_burst_glass.py`, `assets/magic/burst_glass.glb`, `assets/magic/source/burst_glass.blend`
- Test: `tests/burst_spell_test.gd`

**Interfaces:**
- Produces: `assets/magic/burst_glass.glb` with meshes `Spike_1`..`Spike_5` (root at the origin, growing +Y in Godot, 1 m tall, about 0.3 m across at the root, tapering unevenly, faceted, flat-shaded) and `Chunk_1`..`Chunk_6` (about 0.15 to 0.3 m, closed, broken faces).

- [ ] **Step 1: Write the failing check `G1`**

```gdscript
var glass: Node3D = load("res://assets/magic/burst_glass.glb").instantiate()
var meshes := glass.find_children("*", "MeshInstance3D", true, false)
_check("G1 five spikes, six chunks", meshes.filter(func(m): return m.name.begins_with("Spike")).size() == 5 and meshes.filter(func(m): return m.name.begins_with("Chunk")).size() == 6)
var colours: PackedColorArray = meshes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
_check("G1b corners in its colours, for the glass's edges", colours.size() > 0)
```

- [ ] **Step 2:** Run the test. Expected: FAIL (load error).
- [ ] **Step 3: Write `tools/magic/build_burst_glass.py`.** Shape each spike from an irregular faceted cone: 5 to 7 sides, a bent axis, one or two secondary blades fused at the base, a broken-off variant among them. Chunks are voronoi-style cuts of a spike. Split vertices per face so each triangle carries barycentric corners in COLOR. Refuse open edges. Render front, three-quarter and close previews to `assets/magic/source/`.
- [ ] **Step 4:** Build, import, run the test. Expected: `G1`, `G1b` pass.
- [ ] **Step 5:** Render them in the game with the obsidian look, in the gym's light (a one-off still). Send the user the picture. **Stop for the user's verdict; fix until approved.**
- [ ] **Step 6: Commit** `tools/magic/build_burst_glass.py`, the assets, `tests/burst_spell_test.gd`.

### Task 2: Hit when the wave arrives

**Files:**
- Modify: `scripts/Magic/ObsidianBurst.gd`, `tests/burst_spell_test.gd`

**Interfaces:**
- Produces: `ObsidianBurst.WAVE_TIME := 0.5`; `ObsidianBurst.wave_reach() -> float` (m, `REACH * elapsed / WAVE_TIME`, capped at `REACH`); `ObsidianBurst.was_hit(target: Node3D) -> bool`.

- [ ] **Step 1: Rewrite the timing checks.** `B2`, `B2b`, `B3`, `B4`, `B10` wait 35 frames after release. Add:

```gdscript
_check("W1 at release, nothing has been reached yet", near_a.health == 130.0)
# 3 m out is reached at 0.27 s; 5 m at 0.45 s.
_check("W2 the near one first, the far one a beat later", hit_frame_near < hit_frame_far and hit_frame_far - hit_frame_near >= 8)
_check("W3 each hit once", is_equal_approx(130.0 - near_a.health, 35.0))
_check("W4 freed before it arrives: no error, and the wave goes on", is_instance_valid(burst))
_check("W5 anything on you is off at once, at release", p.leech.count() == 0)
```

- [ ] **Step 2:** Run. Expected: `W1`, `W2` FAIL.
- [ ] **Step 3: Implement.** `_go` keeps `free_all`; `_strike` becomes `_physics_process`: each tick, for every live, awake target in `monsters` and `guards` not yet hit, within `wave_reach()` of the cast's centre and with a clear ray (as `_strike` does now), hit once with the same kind, damage and outward direction. The centre is fixed at the cast. Stop when `wave_reach() >= REACH`. Keep hits in a list of instance ids, so a freed target is never touched.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5: Commit.**

### Task 3: The spikes

**Files:**
- Create: `scripts/Magic/BurstWave.gd`
- Modify: `scripts/Magic/ObsidianBurst.gd` (remove `_wave`, `_ring`, `_leave_stuck`, `_splinter`), `tests/burst_spell_test.gd` (replace `B9`, `B9b`, `B9c`)

**Interfaces:**
- Consumes: `burst_glass.glb`; `ObsidianBurst.WAVE_TIME`, `REACH`.
- Produces: `BurstWave.rise_at(context: Node, floor_at: Vector3, reach: float, takes: float) -> Node3D`; `spikes_total() -> int`; `spikes_up() -> int`; `spike_places() -> PackedVector3Array`; `spike_height(i: int) -> float`; `rubble_left() -> int`. Group `burst_wave`. Frees itself when done.

Values: rings about 0.7 m apart from 0.9 m out, spaced so about 60 to 80 spikes. Height `lerp(1.5, 0.45, r / reach)` times `randf_range(0.75, 1.2)`. Each leans out up to 0.25 rad. Born at `takes * r / reach`, up in 0.09 s with an overshoot. Stands 0.6 to 1.0 s, later ones later. Then it cracks, sinks 0.1 s, and becomes 3 or 4 chunks falling under gravity, settling on the floor, gone by 4 s after the cast. Dust (`Fx.dust`) at about one spike in four. Rays are made once, at the cast.

- [ ] **Step 1: Write the failing checks.**

```gdscript
_check("S1 a wave of them, thick on the ground (%d)" % wave.spikes_total(), wave.spikes_total() >= 50 and wave.spikes_total() <= 90)
_check("S2 near first: few up at 0.1 s, all up by 0.6 s", up_early < wave.spikes_total() / 3 and up_late >= wave.spikes_total() - 2)
_check("S3 tall near you, short at the edge", mean_height_inner > mean_height_outer * 1.6)
_check("S4 not through a wall", spikes_past_wall == 0)
_check("S5 cast in the air, it still hurts", jumped_near.health < 130.0)
_check("S5b and nothing floats: every spike stands on a floor", all_on_floor)
_check("S6 they collapse into rubble", wave.spikes_up() == 0 and wave.rubble_left() > 0)
_check("S7 gone in a few seconds", get_tree().get_nodes_in_group(&"burst_wave").is_empty())
_check("S8 two casts close together: both run, both end", two_waves_seen and get_tree().get_nodes_in_group(&"burst_wave").is_empty())
```

- [ ] **Step 2:** Run. Expected: FAIL (no `burst_wave`).
- [ ] **Step 3: Implement `BurstWave.gd`.** One MultiMesh per spike shape and per chunk shape, material from `MagicFx.obsidian_look()` set on the mesh's surface, a wide `custom_aabb`, shadows off. Its own physics tick drives transforms. Free with `queue_free` when `rubble_left() == 0` and time has passed.
- [ ] **Step 4:** Run. Expected: PASS. Take stills (`diag_anima_stills --only=burst`, extended to 8 steps) and inspect them close up. Fix what looks thin.
- [ ] **Step 5: Commit.**

### Task 4: The wind-up, the slam, the scar

**Files:**
- Create: `scripts/Magic/BurstCracks.gd`, `scripts/Magic/burst_cracks.gdshader`
- Modify: `scripts/Magic/Caster.gd`, `scripts/Interaction/HandSlot.gd`, `scripts/Magic/ObsidianBurst.gd`, `docs/superpowers/refs/hunt/sounds_needed.md`, `tests/burst_spell_test.gd`

**Interfaces:**
- Produces: `BurstCracks.on_floor(context: Node, at: Vector3) -> Node3D`, `grow_to(share: float) -> void` (0..1 of the wind-up), `let_go() -> void` (fades in 0.25 s and frees), `scar(reach: float) -> void` (out to `reach` with the wave, fades over 4 s and frees); group `burst_cracks`. `HandSlot.slam_down() -> void`; `HandSlot.slam_shown() -> float` (how far down, 0..1).

The shader draws on a flat quad 0.015 m over the floor: dark glassy cracks from a warped radial pattern on `MeshVfx.noise()`, a cold hairline along them, alpha-cut, growing out with `grown`. Wind-up cracks reach 1.4 m. The caster makes them when `_casting` becomes `&"burst"`, grows them with `cast_progress()`, calls `let_go` on `_cancel`. The hand rises and clenches during the cast; `slam_down` drives it 0.12 m down in 0.07 s and back in 0.35 s, on the existing release pose. On release: `TimeFx.hitstop` 0.07 s, `add_trauma(0.4)`, a roll `juice.punch(0, 0, ±1.4)`, `thud` low and loud, `whoosh_heavy`, `ting`; the flash drops from energy 3.0 for 0.16 s to 1.4 for 0.3 s, so it no longer bleaches your arms.

- [ ] **Step 1: Write the failing checks.**

```gdscript
_check("U1 holding the key, cracks creep out from your feet", cracks != null and cracks_grew)
_check("U2 let go early: they fade, nothing is left, nothing is spent", get_tree().get_nodes_in_group(&"burst_cracks").is_empty() and is_equal_approx(p.power.power, 100.0))
_check("U3 on release your hand slams down", slam_seen > 0.8)
_check("U3b your view thumps, and your aim stays where it was", trauma_seen > 0.3 and aim_after.is_equal_approx(aim_before))
_check("U4 a scar stays a few seconds, then goes", scar_at_2s and scar_gone_at_6s)
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement** as above. Add any sound still wanted (a glass tearing up through stone; a collapse) to `sounds_needed.md`.
- [ ] **Step 4:** Run. Expected: PASS. Stills of the wind-up and release, inspected.
- [ ] **Step 5: Commit.**

### Task 5: What it does to them

**Files:**
- Modify: `scripts/Monsters/Anima.gd`, `scripts/Monsters/AnimaBody.gd`, `scripts/Monsters/FloatingEye.gd`, `scripts/Monsters/EyeBody.gd`, `scripts/Magic/ObsidianBurst.gd`, `tests/burst_spell_test.gd`
- Create: `scripts/Monsters/AnimaSpill.gd`

**Interfaces:**
- Consumes: `MagicFx.stuck_in(target, at, direction)` (a child of the monster, so it goes when the monster goes out of play); `anima_fire.gdshader`.
- Produces: `Anima.flung_up(from: Vector3) -> void`; `AnimaBody.tumble(way: Vector3) -> void`, `tumbling() -> float` (0..1); `AnimaBody.last_wound() -> StringName` (`&"fire"` or `&"blood"`); `AnimaSpill.at(context: Node, point: Vector3, out: Vector3) -> Node3D`, group `anima_spill`; `EyeBody.crack() -> void`.

Values: lift 5 m/s, on the existing `_fall` for crawlers, a decaying `_lift` for faces. Tumble 0.6 s: hands go over (`_flip`), a face rolls and its jaw flaps. Its state does not change, so there is no new stun and no new exposure. Three shards, 0.15 m apart, pointing back along the wave's way. An obsidian hit on an ánima spills a few sick flames and ash for 0.6 s instead of `Fx.blood`; its other wounds stay as they are until those spells get their turn. An eye takes two shards, more blood, and `crack()` adds 0.3 to its shown wounds for 1.5 s.

- [ ] **Step 1: Write the failing checks.**

```gdscript
_check("R1 knocked up (%.2f m) and back" % rose, rose > 0.4 and moved_out > 1.5)
_check("R1b it tumbles, and its state has not changed", tumble_seen > 0.8 and near.state == state_was and not near.is_exposed())
_check("R2 glass stuck in it", stuck_on(near) >= 2)
_check("R3 an ánima spills fire, not blood", near.body.last_wound() == &"fire" and not get_tree().get_nodes_in_group(&"anima_spill").is_empty())
_check("R3b a bullet still does what it did", shot.body.last_wound() == &"blood")
_check("R4 an eye cracks, and takes the glass", eye.body.cracked() and stuck_on(eye) >= 1)
_check("R5 killed by it: into its death, its body burning", killed.dead and get_tree().get_nodes_in_group(&"anima_ash").size() == 1)
_check("R6 a man takes it as before", man.health < man_was)
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement** as above. `ObsidianBurst` calls `flung_up` if the target has it, and `MagicFx.stuck_in` for monsters only.
- [ ] **Step 4:** Run. Expected: PASS. Stills of a crowd taking the wave, close and far, inspected.
- [ ] **Step 5: Commit.**

### Task 6: Judged whole

**Files:**
- Modify: `docs/systems/hunts.md`, `tests/diag_anima_stills.gd`

- [ ] **Step 1:** Windowed, wave 3 of the gym: measure frame time before and during a cast into the full wave. Expected: no sustained drop under 60 fps on this machine. Ledger the numbers, and the ánima burn's too (still owed).
- [ ] **Step 2:** Stills in the room and in the dark yard, close and far, frame by frame through the whole spell; inspect; fix what looks thin or cheap.
- [ ] **Step 3:** Run `anima_test`, `anima_gym_test`, `burst_spell_test`, `copal_line_test`, `round_read_test`, `floating_eye_test`, `hunt_loop_test`, `caster_test`, `revolver_test`, `ammo_ui_test`, `loadout_test`. Expected: all exit 0.
- [ ] **Step 4:** Update `docs/systems/hunts.md`. Commit.
- [ ] **Step 5:** Hand the user the gym. The Shard, Ward, Blink and Empower wait on the verdict.
