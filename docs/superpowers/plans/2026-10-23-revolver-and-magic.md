# Revolver and Magic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a LeMat-style revolver in the right hand, a caster in the left (bare hand, tome, or both hands on the gun), the four starting spells, guards who react to guns, and gibbing.

**Architecture:**
- Two new hand systems sit beside `PlayerCombat`:
  - `Revolver` (right hand: barrels, kick, reload, grip);
  - `Caster` (left hand: loadout, cast timeline, spells), drawing on a shared `PowerPool`.
- Both deliver hits through `Guard.take_hit` with new kinds, so ragdolls, severing and blood work unchanged.
- `PlayerCombat` stands down while the gun is drawn, except for the kick.

**Tech Stack:**
- Godot 4.5.1, GDScript.
- Headless suites in the house style: a scene plus a script, numbered `PASS`/`FAIL` lines, `tools/run_suites.sh`.

**Spec:** `docs/superpowers/specs/2026-10-23-revolver-and-magic-design.md`. Read it first. Every number below comes from it, and every number is a starting value to tune in the gym.

## Global Constraints

- **Branch.** Cut `revolver-magic` from `free-run` at its last commit. Do not commit `free-run`'s uncommitted edits or the untracked `fp_arms_posing.blend`.
- **Godot binary:** `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`.
- **One suite:** `tools/run_suites.sh tests/<name>_test.tscn`. Logs go to `$TMPDIR/suites/<name>.log`.
- **Determinism.** Suites run frame-exact under `--fixed-fps 60`.
  - No unseeded `randf`/`randi` in anything a check reads.
  - Spread and pellet patterns are fixed rosettes, not random.
  - New engine `ERROR:` lines fail `run_suites` unless they are listed in `tools/expected_errors.txt`.
- **Code.** Match the house idiom:
  - `##` doc comments in plain prose;
  - `preload` consts at the top;
  - `StringName` kinds (`&"bullet"`);
  - static armoury builders in `Weapon.gd`;
  - `_ensure_action` for new inputs, as `PlayerCombat._ready` does.
- **Art.** Stand-ins only: block meshes made of primitives (`Weapon._assemble`) and the existing hand poses (`Open`, `Fist`, `Wrap`, `Push`). The real revolver, tome, poses, circles and gore pieces are separate supervised art tracks (spec Art A–D). They are not part of this plan.
- **Sound.**
  - New sound names go through `Sfx.play`/`play_flat`. Where `Sfx` lacks a name, use the stand-ins listed per task.
  - Never synthesize audio.
  - Write each new sound name the user must source into `docs/superpowers/refs/revolver_sounds.md` (Task 16).
- **Words.** No new dialogue text. Guard barks reuse existing lines. A new callout line uses the placeholder `"[gun callout]"` for the user to write.
- **Capsule.** The player's capsule is r 0.5, h 2. Anything that places the player (Blink) must clear that capsule.

## Review Focus

1. **Firing or casting while hanging, climbing, carrying, dead or paused.** No shot and no hand or tome cast happens. Blink still works while hanging and in the air. Pinned by R9 (Task 5) and S12 (Task 9).
2. **Empty or short ammunition.** Firing an empty barrel gives a click and does no damage. R with no stock does nothing. A reload never takes more rounds than exist. Pinned by R13 (Task 4).
3. **Switching away mid-reload, mid-cast or mid-aim** (belt wheel, climbing, grip key). Nothing is left half done: the gate closes, the cast is refunded nothing and nothing spent, and the Blink mark is cleared. Pinned by R14 (Task 4) and S7 (Task 8).
4. **Blinking into floors, ceilings, corners, a guard, or straight down.** You never end inside geometry or another body; you stop short. Pinned by S11 (Task 9).
5. **The pool at its edges.** It never goes negative or over 100. A spell you can't afford doesn't start, and says so: a dry click, and the arc flashes. Pinned by S3 (Task 7).

---

## Part 1: the revolver

### Task 1: The revolver as a weapon, and PlayerCombat standing down

**Files:**
- Modify: `scripts/Combat/Weapon.gd` (enum `Kind`, new "Gun" export group, armoury, meshes)
- Modify: `scripts/Interaction/Inventory.gd` (ammunition stocks, save/load)
- Modify: `scripts/Interaction/Props.gd` (`give_revolver`, `ammo`)
- Modify: `scripts/Interaction/PlayerFrob.gd` or `scripts/Interaction/ToolItem.gd` (ammo pickups go to stocks, not the belt)
- Modify: `scripts/Combat/PlayerCombat.gd:345-494` (stand down for `Kind.GUN`)
- Create: `tests/revolver_test.gd`, `tests/revolver_test.tscn` (copy `combat_test`'s harness: floor, NavBaker, player, `_fighter`, `_put_player`, `_tap`, `_frames`, `_check`)

**Interfaces:**
- **Produces, in `Weapon.gd`:**
  - `enum Kind { MELEE, BOW, GUN }`.
  - Gun exports, with defaults equal to these values:

    | Export | Value |
    |---|---|
    | `rounds` | 6 |
    | `shells` | 1 |
    | `bullet_damage` | 55.0 |
    | `pellets` | 9 |
    | `pellet_damage` | 18.0 |
    | `spread_degrees` | 8.0 |
    | `falloff_start` | 3.0 |
    | `falloff_end` | 12.0 |
    | `blast_range` | 2.0 |
    | `ready_one_hand` | 0.6 |
    | `ready_braced` | 0.35 |
    | `round_load` | 0.45 |
    | `shell_load` | 1.1 |
    | `gate_time` | 0.25 |
    | `shot_db` | 70.0 |
    | `shell_db` | 74.0 |
    | `grip_change` | 0.4 |

  - `static func revolver() -> Resource`: id `&"revolver"`, `kind = Kind.GUN`, `can_block = false`, `headshot_multiplier = 2.5`. `find()` knows it.
  - `static func revolver_mesh() -> Mesh`: a stand-in block gun, grip at the origin, barrel along -Z. Metas:
    - `&"view_poses" = &"revolver"`;
    - `&"muzzle"`: the cylinder barrel's tip;
    - `&"shot_muzzle"`: the lower barrel's tip;
    - `&"cylinder_mesh"`: a separate six-sided cylinder mesh;
    - `&"cylinder_at"`: its centre;
    - `&"hammer_mesh"`, `&"hammer_at"`, `&"gate_mesh"`, `&"gate_at"`: the parts animated in code.
  - `static func tome_mesh() -> Mesh`: a stand-in open book, spine at the origin.
- **Produces, in `Inventory.gd`:**
  - `var ammo := {&"rounds": 0, &"shells": 0}`;
  - `func add_ammo(id: StringName, count: int) -> void` (emits `changed`);
  - `func take_ammo(id: StringName, count: int) -> int` (returns how many were taken, never more than held);
  - both kept by `save_state`/`load_state`.
- **Produces, in `Props.gd`:**
  - `static func give_revolver(player: Node, rounds := 24, shells := 4) -> void`. It puts the revolver on the belt and adds the stocks.
  - `static func ammo(parent: Node, position: Vector3, id: StringName, count: int) -> RigidBody3D`: a pickup like `Props.arrows`. Frobbing it calls `inventory.add_ammo`.
- **Produces, in `PlayerCombat.gd`:** `func gun_drawn() -> bool` (the selected weapon's kind is `GUN`).

**Steps:**

- [ ] **Step 1: Write the failing tests.** In `revolver_test.gd` `_run()`:
  - **R1.** `Props.give_revolver(player)`, then `_wield(&"revolver")`.
    - Assert `player.combat.gun_drawn()`.
    - Assert `player.inventory.ammo[&"rounds"] == 24 and player.inventory.ammo[&"shells"] == 4`.
    - `_tap("throw")` with a `_fighter` 1.5 m ahead: after 40 frames the guard's `health == max_health` (no sword blow) and `player.combat.phase == player.combat.Phase.IDLE`.
  - **R2.** With the revolver drawn and a guard 1.6 m ahead, `_tap("kick")`: the combat's `kicked` signal fires once (the kick still works).
  - **R3.** `Props.ammo(self, p, &"rounds", 6)` frobbed by the player: `ammo[&"rounds"]` rises by 6 and the belt does not change size.
- [ ] **Step 2: Run them and see them fail.** Run `tools/run_suites.sh tests/revolver_test.tscn`. Expected: a script error on `give_revolver`/`gun_drawn`, or FAIL lines.
- [ ] **Step 3: Implement.**
  - In `PlayerCombat._physics_process`, after `able`, when `gun_drawn()`:
    - force `attack_pressed`, `attack_held`, `block_held` and `block_pressed` to false;
    - skip the dodge press;
    - keep the kick branch.
  - `_update_idle` must not set `blocking`.
- [ ] **Step 4: Run them and see them pass.** Expected: `PASS R1`, `PASS R2`, `PASS R3`. Then run `tools/run_suites.sh tests/combat_test.tscn tests/interaction_test.tscn`: all PASS.
- [ ] **Step 5: Commit.** `feat(revolver): the revolver on the belt; combat stands down for it`

### Task 2: The cylinder: firing, kick and settle, the grip, noise

**Files:**
- Create: `scripts/Combat/Revolver.gd` (`extends Node`, the player's child `"Revolver"`)
- Modify: `scripts/PlayerController.gd:571` (create it next to `Combat`; `var revolver: Node`)
- Modify: `scripts/AISystem/Guard.gd:1692-1870` (`take_hit` kind `bullet`)
- Test: `tests/revolver_test.gd`

**Interfaces:**
- **Consumes:** `Weapon.revolver()`, `PlayerCombat.gun_drawn()`, `Inventory.ammo`.
- **Produces, in `Revolver.gd`:**
  - Signals:
    - `signal fired(barrel: StringName, hits: Array)`, where `barrel` is `&"cylinder"` or `&"shot"`;
    - `signal clicked_empty`.
  - State:
    - `var loaded := {&"cylinder": 6, &"shot": 1}` (starts full);
    - `var barrel: StringName = &"cylinder"`;
    - `var braced := false` (both hands on the gun).
  - `func ready_to_fire() -> bool`.
  - `func kick_amount() -> float`, in 0..1, decaying over the settle.
  - `func aim() -> Transform3D`. It returns `player.combat.aim()`, so shots follow the head, not camera effects.
  - `func set_braced(on: bool) -> void`. It takes `grip_change` seconds, during which `ready_to_fire()` is false.
- **Produces, in `Guard.take_hit`:** kind `&"bullet"`. The doc comment lists it.
  - `strength = clampf(damage / 50.0, 0.6, 1.2)`.
  - Posture +18.
  - No `defend()`: it already ignores kinds other than quick, power and thrown.
  - It bleeds and wounds like an arrow, with `_hit_sound` as the arrow's flesh sound, and it does not embed.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **R4.** Body shot: a `_fighter` 6 m ahead, aimed at the chest, `_tap("throw")`. After 5 frames:
    - the guard's health is `100 - 55`;
    - `revolver.loaded[&"cylinder"] == 5`;
    - one `fired` was emitted, with `barrel == &"cylinder"`.
  - **R5.** Headshot: aimed at `eye_position()`, one shot kills (`not is_instance_valid(g)` or `g.health <= 0`).
  - **R6.** Ready times: one-handed, a second `_tap("throw")` 30 frames after the first does not fire, and one 40 frames after does (0.6 s = 36 frames). After `set_braced(true)` and 30 frames, shots 22 frames apart both fire (0.35 s = 21 frames).
  - **R7.** Noise: an `Ear` (see `combat_test`) on `SoundBus` hears an event with `kind == &"gunshot"` and `db == 70.0`.
  - **R8.** Muzzle light: the frame of the shot `Fx.lights_lit()` rises, and within 10 frames it is back.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement `Revolver.gd`.**
  - **The shot.**
    - Hitscan along `aim()`, out to 120 m, mask `1 | 2 | 4`, excluding the player.
    - Headshot by the arrow's rule: `point.y - target.global_position.y >= eye_height - 0.25`.
    - Damage by `take_hit(dmg, player, &"bullet", point, dir)`.
    - Props get `apply_impulse(dir * 6.0, ...)`.
    - World hits get `Fx.dust`/`Fx.chips` by surface meta, as `Arrow._hit` does.
  - **The spread.** Braced: none. One-handed: `kick_amount() * 2.5°`, offset along a fixed rosette indexed by shot count.
  - **The kick.**
    - Call `player.juice.add_trauma` and `punch`. Strength 1.0 one-handed and 0.5 braced; the shot barrel ×1.4.
    - `kick_amount` jumps to 1 and eases to 0 over `ready_one_hand` (or `ready_braced`).
    - `TimeFx.hitstop(get_tree(), 0.04)` on a body hit.
    - `Fx.flash` at the muzzle: warm colour, energy 3, range 6, 0.06 s.
  - **Noise.** `SoundBus.emit_sound(muzzle, shot_db, player, &"gunshot")`.
  - **Sound.** `Sfx.play_flat(player, &"gunshot")`. Until the user supplies it, map it in `Sfx` to the loudest existing impact sound, and note this in the refs doc.
  - **Input.** Read `throw`, plus `grip` (G, via `_ensure_action`), only when `player.combat.gun_drawn()` and the combat's `able` conditions hold. Expose `PlayerCombat.is_able() -> bool` for that, and reuse it.
- [ ] **Step 4: Run them and see them pass.** Then run `combat_test` and `bodies_test`: all PASS.
- [ ] **Step 5: Commit.** `feat(revolver): the cylinder fires, kicks, settles; two-handed grip`

### Task 3: The shot barrel

**Files:**
- Modify: `scripts/Combat/Revolver.gd`, `scripts/AISystem/Guard.gd` (`take_hit` kind `shot`)
- Test: `tests/revolver_test.gd`

**Interfaces:**
- **Produces, in `Revolver`:**
  - `func flip_barrel() -> void` (X, via `_ensure_action(&"barrel", KEY_X)`). It takes 0.15 s, during which `ready_to_fire()` is false.
  - `func pellet_dirs(aim_basis: Basis) -> Array[Vector3]`: 9 directions. One at the centre, 8 on a fixed ring at `spread_degrees / 2`.
- **Produces, in `Guard.take_hit`:** kind `&"shot"` (each pellet is one call), with `strength = clampf(damage / 30.0, 0.4, 1.0)` per pellet. When one shell lands at least 6 of its pellets on one man within `blast_range`, the revolver makes a single `take_hit(total, player, &"blast", ...)` call instead of the pellet calls.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **R10.** At 5 m: `flip_barrel()`, then 12 frames, then `_tap("throw")`.
    - `loaded[&"shot"] == 0`;
    - `loaded[&"cylinder"]` is unchanged;
    - the guard lost between 50 and 162;
    - the falloff factor at 5 m is `1 - (5-3)/(12-3)`.
    - Use `GUARD_SCRIPT.bleeding_on = false`.
  - **R11.** At 14 m: a shell does 0 damage.
  - **R12.** At 1.5 m: one call with kind `&"blast"` (`landed` or a spy on the guard's `hurt`); the guard dies with at least one limb torn (`GuardRig` sever count > 0).
  - **R12b.** Firing the spent shot barrel: `clicked_empty` is emitted and no damage is done.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
  - Pellets are hitscan per direction, damage × the falloff factor, with the hit grouping above.
  - The shell's noise is `shell_db`, the kick ×1.4, and the muzzle `&"shot_muzzle"`.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Commit.** `feat(revolver): the shot barrel, its pellets, a blast up close`

### Task 4: Reloading

**Files:**
- Modify: `scripts/Combat/Revolver.gd`
- Test: `tests/revolver_test.gd`

**Interfaces:**
- **Produces:**
  - `enum Load { NONE, GATE, ROUNDS, SHELL }`;
  - `var loading := Load.NONE`;
  - `func is_reloading() -> bool` (for the guards in Task 14).
  - R (via `_ensure_action(&"reload", KEY_R)`) reloads the selected barrel:
    - **Cylinder:** the gate opens (`gate_time`), then one round per `round_load` from `ammo[&"rounds"]` until 6 are loaded or the stock is empty, then the gate closes (`gate_time`).
    - **Shot barrel:** one shell over `shell_load`.
  - `throw` during `ROUNDS` stops the reload: the gate snaps shut in 0.1 s and the shot goes. Rounds already in stay in.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **R13.** Running dry. Set `ammo[&"rounds"] = 2`, fire 4 shots, then R and wait 200 frames: `loaded[&"cylinder"] == 4` and `ammo[&"rounds"] == 0`. With `ammo` at 0, R does nothing: `loading` stays `NONE`.
  - **R13b.** Firing mid-reload. Fire 3 shots, R, wait `ceil((0.25 + 0.45) * 60) + 2` frames (one round in), then `_tap("throw")`. Within 8 frames:
    - `fired` is emitted;
    - `loaded[&"cylinder"] == 3`;
    - `loading == Load.NONE`.
  - **R13c.** The shot barrel reloads in `shell_load`: `loaded[&"shot"]` is 1 at 68 frames and not at 60.
  - **R14.** Switching away. Mid-reload, `player.inventory.select_next()`. Then:
    - `loading == Load.NONE`;
    - the round in progress is not taken from the stock;
    - drawing the revolver again gives `ready_to_fire()` within `grip_change` + the switch time.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** Each round's stock is taken when that round goes in, not before.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Commit.** `feat(revolver): reload round by round through the gate; the shell on its own`

### Task 5: The revolver in your hands

**Files:**
- Modify: `scripts/Combat/ViewPoses.gd`: a `REVOLVER` table:
  - `"rest"`, `"sprint"`, `"kick"` (the recoil peak), `"braced"`, `"gate"` (tilted, gate toward you), `"flip"` (the thumb at the nose), `"whip"` (raised butt-forward);
  - `static func revolver_frame(pose: Array) -> Transform3D`.
- Modify: `scripts/Interaction/HandSlot.gd`:
  - the revolver parts are child `MeshInstance3D`s of the main mesh when the item has `&"cylinder_mesh"`;
  - `func set_revolver_parts(cylinder_turn: float, hammer: float, gate: float) -> void`;
  - the left hand under the gun's grip when braced, `func set_gun_support(amount: float) -> void`.
- Modify: `scripts/Combat/Revolver.gd`: sends frames each tick like `PlayerCombat._send_pose`, and holsters while `player.combat.stowed`.
- Create: `tests/visual/stage_revolver.gd`, `tests/visual/stage_revolver.tscn` (frames rest, kick, braced, gate, flip for the user's look, like `stage_fp_hands`)
- Test: `tests/revolver_test.gd`

**Interfaces:**
- **Consumes:** `HandSlot.set_weapon_frame`, `ViewArms.VIEW_FOV`.
- **Produces:**
  - the cylinder turns 60° per shot;
  - the hammer goes 0 → 1 over the settle;
  - the gate goes 0..1 while loading.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **R9.** With the player hanging from a ledge (`Props.block` platform; `player._enter_hang(normal, lip_y)`), `_tap("throw")`: no `fired`, and `player.hand.is_item_visible() == false`. Standing again, the revolver is visible within 40 frames.
  - **R15.** Framing: in `rest`, the muzzle projects inside the viewport, in the lower right quarter. In `braced`, the left hand bone is within 0.08 m of the grip.
    - Use the screen-space projection helpers that `fp_arms_test` FA24–27 use, with `FP_ARMS=new`.
  - **R15b.** The parts: after one shot, the cylinder child's rotation about its axis is 60° (±1°).
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
  - Stand-in hand poses: `SwordGrip` on the revolver grip, `Wrap` for the support hand.
  - Wrist rule: no twist, at most 20° of bend. Check it with `diag_grip_health`, and put its numbers in the commit message.
  - The Tab check (`HandSlot.set_checking`) with the revolver drawn uses the `"gate"` pose with the gate open, so the loaded chambers show. There is no ammo HUD.
- [ ] **Step 4: Run them and see them pass.** Run `fp_arms_test` too: all PASS. Run the stage, and save stills to the scratchpad for the user.
- [ ] **Step 5: Commit.** `feat(revolver): held in view, parts that move, holstered on holds`

### Task 6: The pistol-whip

**Files:**
- Modify: `scripts/Combat/Revolver.gd`
- Modify: `scripts/Combat/PlayerCombat.gd` (the kick branch asks the revolver first)
- Test: `tests/revolver_test.gd`

**Interfaces:**
- **Produces:**
  - `func try_whip() -> bool`. A guard alive within 1.3 m and within 35° of the aim: a 0.35 s whip, `take_hit(20.0, player, &"power", ...)` at 0.15 s, the `"whip"` pose. Returns true.
  - `PlayerCombat` calls it on `kick` when `gun_drawn()`, and kicks only if it returns false.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **R16.** Guard at 1.0 m ahead, F: his health is −20 and `kicked` is not emitted.
  - **R16b.** Guard at 1.8 m ahead, F: `kicked` is emitted.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Commit.** `feat(revolver): a pistol-whip in arm's reach`

## Part 2: the caster, the pool, Blink and Shard

### Task 7: Spells as data, and the power pool

**Files:**
- Create: `scripts/Magic/Spells.gd` (`extends RefCounted`, static table)
- Create: `scripts/Magic/PowerPool.gd` (`extends Node`, the player's child `"Power"`)
- Modify: `scripts/PlayerController.gd` (create `Power`; `var power: Node`)
- Modify: `scripts/UI/StealthHUD.gd` (`Crosshair`: a pool arc above the crosshair, mirroring the stamina arc: `power`, `power_alpha`, `power_short_flash`)
- Create: `tests/caster_test.gd`, `tests/caster_test.tscn` (the same harness)

**Interfaces:**
- **Produces, in `Spells.gd`:**
  - `enum Tier { INNATE, HAND, TOME }`.
  - `static func info(id: StringName) -> Dictionary`, with keys `school: StringName`, `tier: int`, `cost: float`, `cast_time: float`, `movement: bool`.

    | Spell | School | Tier | Cost | Cast time | Movement |
    |---|---|---|---|---|---|
    | `blink` | obsidian | INNATE | 20 | 0.0 | true |
    | `shard` | obsidian | HAND | 15 | 0.4 | false |
    | `ward` | copal | HAND | 35 | 0.4 | false |
    | `empower` | nahual | TOME | 50 | 1.2 | false |

  - `static func all() -> Array[StringName]`.
- **Produces, in `PowerPool.gd`:**
  - `var power := 100.0`, `const MAX := 100.0`, `const REFILL := 5.0` per second, `const REFILL_DELAY := 2.0`;
  - `func can_pay(cost: float) -> bool`;
  - `func pay(cost: float) -> bool` (false and no change if it can't; resets the delay);
  - `func refused() -> void` (a dry click, `Sfx` `&"click_dry"`, flashes the HUD arc).

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **S1.** `Spells.info(&"empower")` has tier `TOME`, cost 50 and cast time 1.2. All four ids are in `all()`.
  - **S2.** Refill. `pay(40)`, then after 119 frames power is still 60. After a further 60 frames it is 65 (±0.2).
  - **S3.** Edges. With power 10, `pay(15)` returns false and power stays 10. 1000 frames of refill never pass 100.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** The HUD arc shows while the pool is under `MAX` and fades 1 s after it is full.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Commit.** `feat(magic): spells as data, one shared power pool`

### Task 8: The caster: loadouts and the cast timeline

**Files:**
- Create: `scripts/Magic/Caster.gd` (`extends Node`, the player's child `"Caster"`)
- Modify: `scripts/PlayerController.gd` (create it; `var caster: Node`; `take_damage` tells it about hard hits)
- Modify: `scripts/Interaction/HandSlot.gd`: `func set_left_hold(mode: StringName, frame: Transform3D) -> void`, where mode is `&""`, `&"cast"`, `&"tome"` or `&"braced"`. The existing left-hand jobs (pickup, key, purse, page) take precedence, and the mode comes back after them.
- Modify: `scripts/Combat/Revolver.gd` (`G` grip goes through the caster's loadout)
- Test: `tests/caster_test.gd`

**Interfaces:**
- **Consumes:** `Spells.info`, `PowerPool.pay`, `Revolver.set_braced`, `PlayerCombat.gun_drawn()`, `PlayerCombat.is_able()`.
- **Produces, in `Caster.gd`:**
  - `enum Loadout { HAND, TOME, BRACED }`; `var loadout := Loadout.HAND`; `var selected: StringName = &"shard"`.
  - `signal cast_started(id: StringName)`, `signal cast_done(id: StringName)`, `signal cast_broken(id: StringName)`.
  - `func select(id: StringName) -> void`, on keys 1/2/3 via `_ensure_action(&"spell_1", KEY_1)` and so on. Shard or Ward sets `HAND`; Empower sets `TOME`.
  - `func casting() -> StringName` (`&""` when idle).
  - `func cast_progress() -> float`, in 0..1.
  - `func on_hit(damage: float, kind: StringName) -> void`. It breaks a TOME cast when `damage >= 25.0` or kind is `power`, `blast` or `crush`.
  - `func can_cast(id: StringName) -> bool`, the tier rule:
    - **INNATE with `movement`:** always, unless dead or paused.
    - **Other INNATE:** with a free hand, meaning empty hands or the gun drawn.
    - **HAND:** gun drawn and `loadout == HAND`.
    - **TOME:** gun drawn and `loadout == TOME`.
    - **HAND and TOME:** never while hanging, climbing or carrying.
  - **The timeline.** Hold `block` (RMB) to cast `selected`:
    - progress runs over `cast_time`;
    - letting go early cancels it at no cost;
    - at the end, `pay(cost)` and then the spell's effect (`_effect(id)`, filled in by Tasks 10–13; until then it emits `cast_done` only).
  - G toggles `BRACED` (calls `revolver.set_braced`). Any spell key leaves `BRACED`.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **S4.** The hand tier. Gun drawn, `select(&"shard")`, hold `block`:
    - `cast_done` is not emitted at 22 frames and is emitted by 26 frames (0.4 s);
    - power is 85 afterwards.
  - **S5.** The tome tier. `select(&"empower")` (loadout `TOME`), hold: done between 70 and 74 frames, power 50.
  - **S6.** A broken tome cast. Empower, hold; at 30 frames `player.take_damage(30, guard)`. Then `cast_broken` is emitted, power is 100, and `casting() == &""`.
  - **S7.** Cancels. Letting go of `block` at 10 frames: no `cast_done` and power 100. The same while switching the belt away mid-cast.
  - **S8.** The tier rule.
    - With the sword drawn: `can_cast(&"shard") == false` and `can_cast(&"blink") == true`.
    - Gun drawn and BRACED: `can_cast(&"shard") == false`.
    - Hanging: only blink.
  - **S9.** The left hand. Gun drawn and loadout `TOME`: `player.hand` reports left mode `&"tome"`. Frobbing a key pickup mid-tome: the key is taken, and the mode is `&"tome"` again within 60 frames.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
  - RMB is `block`. While the gun is drawn, `PlayerCombat` already ignores it (Task 1).
  - **Stand-in viewmodel:**
    - `&"cast"`: an `Open` hand palm-forward at (-0.2, -0.2, -0.45);
    - `&"tome"`: `tome_mesh` held in `Wrap` at (-0.22, -0.26, -0.42), opened toward you;
    - `&"braced"`: the support hand from Task 5.
- [ ] **Step 4: Run them and see them pass.** Then run the revolver and combat suites: all PASS.
- [ ] **Step 5: Commit.** `feat(magic): the caster's loadouts and cast times by tier`

### Task 9: Blink

**Files:**
- Create: `scripts/Magic/Blink.gd` (`extends RefCounted`, static helpers)
- Modify: `scripts/Magic/Caster.gd` (the blink input and its effect)
- Modify: `scripts/Combat/PlayerCombat.gd` (Q: dodge only with a melee weapon drawn on the floor, tap; otherwise blink)
- Test: `tests/caster_test.gd`

**Interfaces:**
- **Produces, in `Blink.gd`:**
  - `const RANGE := 10.0`, `const STEP := 4.0`;
  - `static func arrival(player: CharacterBody3D, from: Vector3, toward: Vector3, reach: float) -> Vector3`. It goes along the line out to `reach` or the first solid or body hit, less 0.6 m, then back in 0.25 m steps until the player's own capsule shape (`PhysicsShapeQueryParameters3D`, r 0.5, h 2, excluding the player) fits. It returns `from` if nothing fits.
- **Produces, in `Caster`:**
  - The `blink` action on Q (`_ensure_action(&"blink", KEY_Q)`).
    - **Tap** (released within 0.18 s): `STEP` along the move input, or forward if still.
    - **Hold:** aim to `RANGE` along the view, with a mark (`Fx.glint` each tick at the arrival). Release to go; RMB cancels.
  - Paid on arrival through `player.teleport(...)`, keeping velocity in the air.
  - On arrival: `Fx.glint` at both ends, `Sfx` `&"blink"` (stand-in `&"whoosh_light"`), and `player.combat._dodged_at = player.combat._game_time`. That last one is so `GuardFighter` (line 3182, `dodged_within(0.45)`) counts it as a dodge.
  - **Q's split:** with a MELEE weapon drawn and on the floor, a tap of Q is the old dodge and a hold aims Blink. Everywhere else, Q is Blink.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **S10.** A tap with the gun drawn on open floor: the player moves 4 m forward (±0.3), and power is 80.
  - **S11.** Clearance:
    - a hold-aim at a wall 3 m ahead ends at least 0.5 m short of it;
    - aimed at the floor 2 m ahead, you end above the floor, not in it;
    - aimed at a guard, you end in front of him;
    - every end passes `test_move(xform, Vector3.ZERO) == false`.
  - **S12.** From anywhere:
    - hanging from a ledge, a tap of Q works (state goes from `HANGING` to `LOCOMOTION`, and the position changes);
    - mid-air, it keeps the fall speed;
    - with empty hands (`inventory.holster()`), it works;
    - with the sword drawn, a tap is the dodge (the `dodged` signal) and a hold is a blink.
  - **S13.** As a dodge. With a `_fighter` mid-CALL (copy combat_test's answered-dodge setup), a blink in the window: the guard's `answered` is emitted with `&"dodged"`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Then run `combat_test`, `freerun_test` and `traversal_test`: all PASS.
- [ ] **Step 5: Commit.** `feat(magic): Blink, a tap or an aimed step, from anywhere`

### Task 10: Blink onto a ledge

This comes last in Part 2 so it builds on settled climbing code. Before starting, check that `free-run`'s `HandContacts.gd` edits have been committed by the user. If not, stop and ask.

**Files:**
- Modify: `scripts/Magic/Blink.gd`, `scripts/Magic/Caster.gd`
- Test: `tests/caster_test.gd`

**Interfaces:**
- **Consumes:** `TraversalPlanner.probe_hang`, `TraversalPlanner.hang_anchor(face_point, normal, lip_y)`, `PlayerController._enter_hang(normal, lip_y)`.
- **Produces:** `static func ledge_at(player, hit: Dictionary) -> Dictionary`. It returns `{anchor, normal, lip_y}` when the aim hits a wall face within 1.2 m below a lip that `probe_hang` accepts, or `{}` otherwise. On a lip, the blink arrives at `anchor` and calls `_enter_hang`.

**Steps:**

- [ ] **Step 1: Write the failing test.** **S14.** Aim at a 3 m wall's face 0.6 m below its top, from 6 m away, then release: within 3 frames `movement_state == HANGING`, `hang_lip_y` equals the top (±0.05), and `test_move` is clear.
- [ ] **Step 2: Run it and see it fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it and see it pass.** Then run `freerun_test` and `traversal_test`: all PASS.
- [ ] **Step 5: Commit.** `feat(magic): Blink onto a ledge ends in a hang`

### Task 11: Shard

**Files:**
- Create: `scripts/Magic/Shard.gd` (`extends StaticBody3D`; flight copied from `Arrow.gd`: a ray per step, `gravity = 0.0`, speed 70 m/s, `lifetime` 3 s)
- Modify: `scripts/Magic/Caster.gd` (`_effect(&"shard")`, the stand-in Obsidian circle)
- Modify: `scripts/AISystem/Guard.gd` (`take_hit` kind `shard`)
- Test: `tests/caster_test.gd`

**Interfaces:**
- **Produces, in `Shard`:**
  - `func launch(from: Vector3, velocity: Vector3, damage: float, by: Node3D) -> void`, with damage 40.0;
  - on a guard, `take_hit(40, by, &"shard", point, dir)`;
  - on the world, `Fx.dust(..., "stone")` plus glass, then it frees (it does not stick);
  - `SoundBus` 36 dB, kind `&"shard"`.
- **Produces, in `Guard.take_hit`:** `&"shard"` bleeds like a quick cut, `strength 0.7`, posture +12. On a limb hit it may sever: the caster calls `player.combat._sever_parts(target, point, dealt, health_before, &"shard")`, as melee does.
- **The circle stand-in.** While a HAND cast of an Obsidian spell runs, 12 small black glass slivers (`Weapon._assemble` boxes, metallic 0.8, roughness 0.15) appear on a ring 0.09 m across in front of the cast hand, turning at 2 rev/s and closing from 0.18 to 0.09 m across over the cast. Viewmodel layer only (`HandSlot.VIEWMODEL_LAYER`).

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **S15.** Gun drawn, Shard at a `_fighter` 8 m ahead: health is −40 within 20 frames of `cast_done`.
  - **S16.** At a 0.9 m-high target point (his thigh) on a guard with 30 health: he dies with a torn leg (`_sever` contains `thigh_l` or `thigh_r`, or the rig's sever count is > 0). Bleeding is on for this check, so seed `GUARD_SCRIPT` as `combat_test` does for its severing checks.
  - **S17.** An `Ear` hears `&"shard"` at 36 dB and no `&"gunshot"`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Commit.** `feat(magic): Shard, a glass splinter from an obsidian circle`

## Part 3: Ward, the tome, Empower

### Task 12: Ward

**Files:**
- Create: `scripts/Magic/Ward.gd` (`extends Node3D`)
- Modify: `scripts/Combat/Arrow.gd:67-110`, `scripts/Magic/Shard.gd`, `scripts/Combat/Revolver.gd` (incoming checks)
- Modify: `scripts/Magic/Caster.gd` (`_effect(&"ward")`; the Copal circle stand-in, a smoke ring of `Fx.dust`-style puffs on the cast hand)
- Test: `tests/caster_test.gd`

**Interfaces:**
- **Produces, in `Ward.gd`:**
  - `const RADIUS := 1.0`, `const LIFE := 4.0`;
  - `static var active: Array` (weak refs);
  - `static func cast_on(player: Node3D) -> Node3D`: follows the player for `LIFE`;
  - `static func stops(from: Vector3, to: Vector3, shooter: Node) -> Vector3`. It returns where the segment first enters an active ward's sphere from outside, when the ward's owner is not `shooter`. Otherwise `Vector3.INF`.
  - Stand-in look: a ring of pale grey-green smoke puffs (made in house) at waist height, slowly turning.
- **Consumers:**
  - `Arrow._physics_process` calls `Ward.stops(from, to, shooter)` before its ray. On a stop: dust and `Sfx` `&"ward_stop"` (stand-in `&"thud_wood"`) at that point, then `queue_free()`.
  - `Shard` the same.
  - `Revolver` hitscan the same, for later enemy guns. The player's own shots have `shooter == player`, so they pass.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **S18.** Ward up, an `Arrow` launched at the player's chest from 10 m by a guard: the player's health is unchanged, and the arrow is freed at about 1.0 m from the player (±0.15).
  - **S19.** Ward up, a `_fighter` whose blow lands (copy combat_test's C6 setup, `invulnerable = false`): the player's health drops by the blow. Melee passes.
  - **S20.** Ward up, the player fires at a guard 6 m ahead: hit for 55.
  - **S21.** After 4.0 s plus 5 frames, `Ward.active` is empty, and an arrow hits again.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** Guards walk through it: the ward has no collision and is not in the navmesh.
- [ ] **Step 4: Run them and see them pass.** Then run `combat_test`, `squad_test` and `gym_test`: all PASS.
- [ ] **Step 5: Commit.** `feat(magic): Ward, ghostly smoke that stops shots and spells, not blades`

### Task 13: The tome and Empower

**Files:**
- Modify: `scripts/Magic/Caster.gd` (`_effect(&"empower")`, the charge)
- Modify: `scripts/Combat/PlayerCombat.gd` (`_kick_contact`), `scripts/Combat/Revolver.gd` (whip, shot), `scripts/PlayerController.gd` (jump), `scripts/Magic/Blink.gd` (range)
- Test: `tests/caster_test.gd`

**Interfaces:**
- **Produces, in `Caster`:**
  - `var empowered_until := -1.0` (game time; 8 s after `cast_done`);
  - `func empowered() -> bool`;
  - `func spend_empower(use: StringName) -> bool`, where `use` is `&"blow"`, `&"shot"`, `&"jump"` or `&"blink"`. It returns true once and clears the charge.
  - **Stand-in feel while charged:** `player.juice` adds a slow pulse, and `Sfx` `&"heartbeat"` (it exists) plays once.
- **Consumers:**
  - **Kick and whip:** damage ×3, and a killing blow uses kind `&"blast"`.
  - **Cylinder shot:** kind `&"blast"` with `bullet_damage`. It must not gib: Task 15 adds the `no_gib` flag that passes this on.
  - **Shell:** all pellets' damage is summed into one `&"blast"` at any range up to 6 m, with `gib := true`.
  - **Jump:** in `PlayerController`, when the jump key is still held 0.2 s after takeoff and `spend_empower(&"jump")`: set the upward velocity so the apex is twice the normal jump's apex height measured from takeoff.
  - **Blink:** `RANGE` ×2 and `STEP` ×2 for that blink.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **S22.** Empowered, a kick at a guard (health 100, kick base damage per `PlayerCombat`): damage ×3, and `empowered()` is false afterwards.
  - **S23.** Empowered, a tapped jump (released at 6 frames): `empowered()` stays true, and the apex is normal. A held jump: the apex is twice the normal one (±10%), and the charge is spent.
  - **S24.** Empowered, a blink tap: it moves 8 m (±0.3).
  - **S25.** Unused for 8 s plus 5 frames: `empowered()` is false.
  - **S26.** Empowered, a cylinder shot kills a 50-health guard as `&"blast"` (thrown: `_last_push.length() > 5`), with no gib.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Commit.** `feat(magic): the tome and Empower, one charge of beast strength`

## Part 4: guards and guns

### Task 14: Near misses, cover, and a rush at the reload

**Files:**
- Modify: `scripts/AISystem/Guard.gd`: `func near_miss(by: Node3D, at: Vector3) -> void`. The gunshot kind in `hear_sound` counts as a shout-level stimulus: `alert = maxf(alert, shout_alert)` and `last_known` at the source.
- Modify: `scripts/AISystem/Squad.gd`:
  - `read` gains `&"gun"`;
  - `func on_shot_at(member: Node3D) -> void`;
  - `_choose_tactic` gains `&"cover"`;
  - `CALLS[&"cover"] = ["[gun callout]"]`;
  - role `&"cover"`.
- Modify: `scripts/AISystem/Garrison.gd` (`habits` gains `&"gun"`)
- Modify: `scripts/AISystem/GuardFighter.gd`:
  - `func cover_point() -> Vector3`;
  - the `&"cover"` place in the chase code near line 1500: `guard._go_to(cover_point())`, then hold and face the player.
- Modify: `scripts/Combat/Revolver.gd` (calls `near_miss` and `Squad.of(player).on_shot_at`)
- Create: `tests/gunfight_test.gd`, `tests/gunfight_test.tscn`

**Interfaces:**
- **Consumes:** `Revolver.is_reloading()`, `Revolver.loaded`, `Revolver.barrel`.
- **Produces:**
  - **Near miss.** A bullet's ray passing within 1.5 m of a live guard's chest, missing him: `near_miss`. It does a `_rig.react_hit(dir, 0.3)` flinch, `_engage(by)`, and `squad.on_shot_at(self)`.
  - **The read.** `on_shot_at` adds 0.25 to `read[&"gun"]` (capped at 1). A hit adds 0.35, called from `take_hit` when kind is `bullet` or `shot`. It decays with the other reads.
  - **Tactics in `_choose_tactic`,** placed after `break` and before the `kite`/`bow` rush:
    - `gun > 0.5` and the nearest melee man > 8 m and not reloading → `&"cover"`;
    - `gun > 0.5` and (reloading, or the shot barrel selected and empty, or nearest ≤ 8 m) → `&"rush"`.
    - A switch to `rush` because of a reload ignores `KEEP`.
  - **`cover_point()`.** It samples 12 points on a ring 3–6 m from the guard at fixed angles, snapped to the navmesh (`NavigationServer3D.map_get_closest_point`). It keeps those where `SightRay.first_solid` from the player's eye to the point +1.2 m hits world geometry, and picks the nearest to the guard. It is cached until the player moves 3 m. With no cover, it returns his own position, so he stands.
  - **Roles.** Under `cover`, melee men take `&"cover"`, and archers keep `&"support"`.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **GF1.** Two guards behind three `Props.block` pillars, the player 20 m away. Fire twice past them, within 1 m:
    - `read[&"gun"] >= 0.5`;
    - the squad's tactic is `&"cover"` within 60 frames;
    - within 300 frames both men stand where `SightRay` from the player's eye to their chest is blocked.
  - **GF2.** Then R (a reload): within 30 frames the tactic is `&"rush"`, and both men close by at least 3 m within 120 frames.
  - **GF3.** A near miss on a lone relaxed guard: `alert` rises, and the flinch is called (spy `_rig.react_hit`, or check `_last_blow` set).
  - **GF4.** A guard 60 m away round a corner on the navmesh hears a shot (alert rises). One 200 m away does not.
  - **GF5.** With the gun drawn but never fired for 600 frames, a squad's `read[&"gun"]` stays 0.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Then run `squad_test`, `hunt_test`, `gym_test` and `combat_test`: all PASS.
- [ ] **Step 5: Commit.** `feat(guards): they read the gun: cover at range, a rush at the reload`

## Part 5: gibbing

### Task 15: Gibbing

**Files:**
- Create: `scripts/Visual/Gore.gd` (`extends RefCounted`, static)
- Modify: `scripts/AISystem/Guard.gd`:
  - the `take_hit` death path: a `gib` flag on the hit, via a new optional parameter `extra := {}`, with keys `gib: bool` and `no_gib: bool`;
  - `func _gib(at: Vector3, push: Vector3) -> void`.
- Modify: `scripts/Combat/Revolver.gd`. It passes `{gib = true}` on a point-blank shell, a blast with at least 6 pellets inside `blast_range`, and on an empowered shell. It passes `{no_gib = true}` on an empowered bullet.
- Modify: `scripts/Combat/PlayerCombat.gd`. An empowered killing kick or whip passes `{gib = true}`.
- Test: `tests/revolver_test.gd`

**Interfaces:**
- **Produces, in `Gore.gd`:**
  - `static func burst(context: Node, at: Vector3, push: Vector3, pieces := 10) -> Array[RigidBody3D]`. It makes code-built stand-in chunks (dark red boxes and rounded bits, made in house): mass 0.4–1.5, impulse `push * 0.6` plus a fixed spread pattern.
    - Each chunk sleeps after 3 s, fades and frees at 20 s.
    - The live count is capped at 60 (the oldest go first) and counted in `Fx.live`-style bookkeeping.
  - A spray of `Fx.blood` (amount 2.5) and 6 `Fx.stain` decals cast round `at` onto the floor and walls within 3 m.
- **Produces, in `Guard._gib`:**
  - `_sever` = both arms, both legs and `neck_01`, through the existing death and sever path;
  - `Gore.burst(...)` at the chest;
  - the torso stays whole with `Fx.wound` decals;
  - the existing "cut apart in front of his friends" response is called with double weight.
  - **Leave room for the later torso split:** `_gib` is the single place a body bursts, so a future `GuardRig.split_torso()` hooks in there.

**Steps:**

- [ ] **Step 1: Write the failing tests.**
  - **R17.** A shell at 1.2 m into a 100-health guard:
    - the corpse has all 4 limbs and the head severed (the rig's sever count is 5);
    - `Gore` live chunks ≥ 8;
    - at least 3 new stains.
  - **R18.** A shell at 5 m that kills: no gib (sever count ≤ 3, Gore live chunks 0).
  - **R19.** Ten gibs in a row: Gore's live chunks never exceed 60, and after 1300 frames they are 0.
  - **R20.** A witness 5 m away sees a gib: his squad's morale drops by more than for a plain kill (compare against a plain-kill run in the same test).
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.** Then run `bodies_test` and `combat_test`: all PASS.
- [ ] **Step 5: Commit.** `feat(gore): bodies burst under a point-blank shell or an empowered blow`

### Task 16: The range bay, the sound list, the docs, every suite

**Files:**
- Modify: `maps/combat_gym.gd`:
  - a range bay at x 30..60, z -40..-10: targets at 5, 15 and 30 m, a squad of three behind pillars, a dummy wall for spread, ammo and a tome on a table;
  - `Props.give_revolver` at the start;
  - a `_sign` with the controls (the controls table from the spec).
- Modify: `tests/gym_test.gd`: a check that the range bay builds and that the revolver is on the belt (next free G number).
- Create: `docs/superpowers/refs/revolver_sounds.md`: every new `Sfx` name used, what it stands for, and its stand-in, for the user to source.
- Modify: `docs/systems/combat.md` (the revolver, caster and Ward controls; the new `take_hit` kinds)

**Steps:**

- [ ] **Step 1:** Build the bay and add the gym check. Run `tools/run_suites.sh tests/gym_test.tscn`: PASS.
- [ ] **Step 2:** Write the sound list and the docs.
- [ ] **Step 3:** Run every suite with `tools/run_suites.sh`. Expected: every suite PASS, with no unexpected engine `ERROR:` lines. Any failure gets fixed (systematic debugging), not skipped.
- [ ] **Step 4:** Take the windowed stills of the range bay and of `stage_revolver` into the scratchpad for the user.
- [ ] **Step 5: Commit.** `feat(gym): a range bay for the revolver and spells; sounds to source; docs`

---

## Not in this plan (supervised art, with the user)

- **Art A:** the revolver model, built one piece at a time.
- **Art B:** the poses (revolver, two-handed grip, casting hand, tome), posed in live Blender.
- **Art C:** the Obsidian and Copal circles, built in the effects lab.
- **Art D:** the gore pieces.

Each replaces a stand-in named above without code changes beyond the mesh, meta and pose names.
