# NPC Showcase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A self-running, recordable night in a garrison yard that shows every NPC behaviour (camp life, a murder and its witness, the alarm and the hunt, a squad fight with three endings) through a free camera and an auto-director.

**Architecture:** The guards run their real AI unchanged. The enemy they react to is `Intruder.tscn`, a `Guard.tscn` whose script is a subclass (`Intruder.gd`) with `puppet = true`: it skips the guard mind, joins the `player` group, and answers the player interface the AI reads. Camp life is a new, general guard module (`GuardRota.gd`) driven by `GuardStation` nodes. A director engine (`ShowDirector.gd`) runs a story (`ShowNight.gd`) as beats over a code-built map (`maps/npc_showcase.gd`), with `ShowCamera.gd` and `ShowOverlay.gd` for the viewer.

**Tech Stack:** Godot 4.5.1, GDScript. Godot binary: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot` (below: `$GODOT`). Suites run headless: `$GODOT --headless --fixed-fps 60 --quit-after 90000 --path . res://tests/<suite>.tscn`, and print `==== RESULTS ====` then one `PASS`/`FAIL` line per check.

**Spec:** `docs/superpowers/specs/2026-09-26-npc-showcase-design.md`

## Global Constraints

- Work only on branch `npc-showcase` in `.claude/worktrees/npc-showcase`. Commit per task. Do not touch main.
- Existing clips only (Universal Animation Library). No new modelling; the intruder is the archer's outfit with a near-black dye `Color(0.07, 0.07, 0.08)` and a sword.
- Guards' perception, decisions and fighting do not change. Every edit to shared AI files is a `puppet` gate, a station hook, or a sleep gate.
- New files follow the repo's comment style: `##` doc comments in plain English, blank line between blocks, typed GDScript.
- Every suite that spawns guards sets `TemperamentScript.rolling = false`, clears `SquadScript`/`GarrisonScript` between independent fights, and seeds spawns with `GuardScript.randomize_on = false; seed(n)`.
- After every suite run, grep stderr/stdout for `SCRIPT ERROR`: a run with it is a failure even if every check passes.
- Every existing suite stays green (run the full set at the end of tasks 1, 3, 4, 10 and 12).
- Plot armour floor: 30% of the intruder's `max_health`. Act II exposure damping: ×0.25 until the murder.
- Cast (name, archetype, preset): Mirelle duelist steady; Osric swordsman steady; Brand brute rash; Wat archer sly; Aldous watchman stubborn (lookout); Hendrik watchman steady; Piers watchman craven; Col watchman steady; Tam watchman steady; Gideon watchman steady; Ned watchman craven; Jory watchman steady.

**Deviations from the spec, decided here:**
1. Station behaviour lives in a new module `scripts/AISystem/GuardRota.gd`, not inside `GuardLife.gd` (651 lines already). `Guard.activity()` asks the rota before `GuardLife`.
2. A sleeping man also does not see (vision off while asleep), besides hearing ×0.15.
3. Ned's reaction to the murder is his own AI's; the director does not force "runs for the captain". The checks require only that he sees it and raises the cry.
4. The intruder's player interface lives on a `Guard` subclass (`Intruder.gd`, scene `Intruder.tscn` inheriting `Guard.tscn`) rather than a separate component, because the AI reads it off the target node itself.

## Review Focus

1. **Restarting or jumping acts repeatedly (R, 1–5):** static state (Squad, Garrison, TimeFx, SoundBus listeners, LightProbe cache) must not leak across reloads. Expect the same cast, no stale hunts and time at normal speed after every jump. Pinned by showcase_test D10.
2. **Pausing during a hit-stop or slow-motion request:** after unpausing, time must run at the chosen show speed, not stuck at 0.05. Pinned by showcase_test D11.
3. **The intruder dies or is freed mid-beat** (overwhelmed ending, then more keys): no errors, and the director stops issuing verbs to him. Pinned by showcase_test D12.
4. **The camera follows a man who dies:** it keeps framing where he fell, then drops back to free or director mode, with no errors. Pinned by showcase_test D13.
5. **A beat whose condition never comes true:** it times out, logs, and the show moves on. Pinned by showcase_test D2.

---

### Task 1: The puppet switch and look override in `Guard.gd`

**Files:**
- Modify: `scripts/AISystem/Guard.gd`, `scripts/AISystem/GuardRig.gd`, `scripts/Visual/Humanoid.gd`
- Create: `scripts/Showcase/Intruder.gd` (minimal: `extends "res://scripts/AISystem/Guard.gd"`, `puppet = true` in `_init`), `Intruder.tscn` (inherits `Guard.tscn`, root script `Intruder.gd`)
- Test: `tests/intruder_test.gd`, `tests/intruder_test.tscn`

**Interfaces:**
- Produces on `Guard`:
  - `@export var puppet := false`
  - `@export var look_override: Dictionary = {}`
  - `func look() -> Dictionary` = `GuardFighterScript.look_of(archetype).merged(look_override, true)`; used by `_ready` (hands' weapon) and `GuardRig.setup`.
  - `func _puppet_drive(_delta: float) -> void` (virtual, empty): called instead of the state machine when `puppet`.
- Produces on `Humanoid`: `func set_dye(colour: Color) -> void` (sets `look.dye`, re-applies `Wardrobe.apply_look` to every worn mesh).
- `GuardRig.setup`: after dressing, `if look.has("dye"): man.set_dye(look["dye"])`.

Puppet gates in `Guard.gd` (each one line or a guarded block):
- `_ready`: `add_to_group(&"player")` instead of `&"guards"` when `puppet`.
- `_enter_tree`: no `SoundBus.add_listener` when `puppet`.
- `_physics_process`: skip the target lookup, garrison tick and squad think; skip `_sense_vision`, `_sense_bodies`, `_update_alert`, `_life.update`, `_watch_for_powder`; replace `match state` with `_puppet_drive(delta)`.
- `take_hit`: `answer` is `&""` when `puppet` (no double defence); `opened` is false when `puppet`.
- `bark`: returns at once when `puppet`.
- `die`: skip `_leave_post` and `_horrify` when `puppet`; the spawned body leaves group `&"bodies"` (nobody finds the intruder's corpse as a friend's).

- [ ] **Step 1: Write the failing tests** in `tests/intruder_test.gd` (harness copied from `tests/posts_test.gd`: `_frames`, `_until`, `_check`, `_fresh`, a NavBaker floor; no Player instance):
  - `I1 the intruder is in the player group, not the guards group, and not a SoundBus listener`: `is_in_group(&"player") and not is_in_group(&"guards") and not SoundBus._listeners.has(i)` (use the listener array's real name).
  - `I2 his look is the archer outfit dyed near-black, with a sword`: `i._rig._carried == &"sword"` and `i._rig.man.look.dye.is_equal_approx(Color(0.07, 0.07, 0.08))` (when the wardrobe dresses him; else skip with detail "painted").
  - `I3 he never barks, and his state never changes by itself over 300 frames beside a guard in light`: barked count 0, `i.state == RELAXED`.
  - `I4 killed, he leaves no body in "bodies", no fallen post in the garrison, and no dread`: after `i.take_hit(999, g, &"quick", ...)`, `get_nodes_in_group(&"bodies").is_empty()`, `GarrisonScript.of(i).dread == 0.0`.
- [ ] **Step 2: Run** `$GODOT --headless --fixed-fps 60 --quit-after 20000 --path . res://tests/intruder_test.tscn`. Expected: FAIL (no `puppet`, no `Intruder.tscn`).
- [ ] **Step 3: Implement** the gates, `look()`, `look_override`, `_puppet_drive`, `Humanoid.set_dye`, the rig's dye, `Intruder.gd` (`_init`: `puppet = true`, `archetype = &"archer"`, `look_override = {"weapon": &"sword", "dye": Color(0.07, 0.07, 0.08)}`, `given_name = "the intruder"`) and `Intruder.tscn`.
- [ ] **Step 4: Run** intruder_test (expected: I1–I4 PASS), then every existing suite (expected: all PASS, no SCRIPT ERROR).
- [ ] **Step 5: Commit** `feat(showcase): the puppet switch and look override`.

### Task 2: The intruder speaks the player interface; blows both ways

**Files:**
- Modify: `scripts/Showcase/Intruder.gd`
- Create: `scripts/Showcase/IntruderCombat.gd`
- Test: `tests/intruder_test.gd`

**Interfaces:**
- `Intruder.gd` (on the puppet node, read by the AI):
  - `var combat: IntruderCombat` (child node, created in `_ready`)
  - `var is_dead := false` (true in `die`)
  - `var armoured := true`; `const ARMOUR_FLOOR := 0.3`
  - `var exposure_scale := 1.0` (the director's Act II damping)
  - `var crouched := false`
  - `func get_light_level() -> float` (`LightProbe` at chest height)
  - `func get_exposure() -> float` = `clampf(light × (0.85 if crouched else 1.0) × (1 + 0.35 × clampf(speed / 1.6, 0, 1.3)) × exposure_scale, 0, 1)`
  - `func get_sight_points() -> Array` (head 1.6 m / chest 1.0 m / shins 0.3 m above his feet; ×0.62 heights when crouched)
  - `func take_damage(amount: float, from: Node) -> void`: `amount = combat.filter_incoming(amount, from)`; if `armoured`, clamp so health stays ≥ `ARMOUR_FLOOR × max_health`; then `take_hit(amount, from, kind, point, dir)` on himself (kind `&"power"` for `heavy`/`charge`, else `&"quick"`) so flinches, blood and death come from the guard code.
  - `func warn_attack(from: Node3D) -> void`: forwards to `brain.on_warned(from)` (Task 3; a no-op until then).
  - `func fall() -> void`: `armoured = false`.
  - `_physics_process` (after `super`): keeps `health ≥ ARMOUR_FLOOR × max_health` while armoured (bleeding cannot take it lower).
- `IntruderCombat.gd` (`extends Node`):
  - `signal defended(result: StringName)`, `signal dodged(direction: Vector3)`
  - `enum Phase { IDLE, WINDUP, CHARGING, STRIKE, RECOVER, DRAWING, KICK, DODGE, STAGGER }` (the same order as `PlayerCombat.Phase`: Squad reads `phase` as that int)
  - `var phase := Phase.IDLE`, `var blocking := false`
  - Read-outs as `PlayerCombat`'s: `threat_serial() -> int`, `threat_phase() -> StringName`, `time_to_contact() -> float`, `threat_reach() -> float` (1.9 m), `threat_direction() -> StringName`, `is_riposte() -> bool`, `dodged_within(seconds: float) -> bool`, `blow_poise() -> float`, `_style() -> Dictionary` (`{"poise", "damage", "reach", "strike"}`), `on_answered(how: StringName, by: Node) -> void` (opens a riposte window of 0.6 s).
  - `func swing(direction: StringName) -> void` where direction ∈ `overhead`, `left`, `right`, `thrust`, `heavy`: sets the puppet's `_attack`/`_phase` (`windup` 0.42 s, ×1.5 for `heavy`; `strike` 0.12 s; `recover` 0.4 s) so `GuardRig` shows it, bumps `threat_serial`, and at strike start calls `victim.take_hit(damage, intruder, kind, point, dir)` on the guard in reach (1.9 m, 110° arc; `thrust` 2.2 m, 34°). Damage 34 (`heavy` 60, `power`; a riposte ×1.5). The result `parried` staggers him 0.9 s (`_stagger`, `_rig.react_parried`); `blocked` bounces him (`_rig.react_blocked`, recover 0.5 s).
  - `func backstab(victim: Node3D) -> void`: an `overhead` swing whose strike calls `victim.take_hit(999, intruder, &"backstab", ...)`.
  - `func guard_up(on: bool) -> void`: `blocking = on`; mirrors to `intruder._fighter.guarding` for the rig. Guard raised at `t` → a parry if the blow lands within 0.25 s of `t`.
  - `func dodge(away_from: Vector3) -> void`: a 0.3 s backstep at 6.5 m/s (sets the puppet's `_knock`/`_knock_velocity`), records the time, emits `dodged`.
  - `func filter_incoming(amount: float, from: Node) -> float`, mirroring `PlayerCombat.filter_incoming` in outcome (not in camera or hand effects):
    - `hazard`: full; `unblockable`: full, and shoved (`_knock` 0.3 s at 5.5 m/s away; 0.65 s stagger for `heavy`);
    - `low`: full;
    - parry (guard raised ≤ 0.25 s, facing within 0.35): `from.parried(intruder, 1.0)`, sparks and `parry` sound, `defended.emit(&"parry")`, returns 0; opens a riposte window;
    - block: `from.blocked_by(intruder)`, sparks and `clang`, `defended.emit(&"block")`, returns `amount × 0.4` for a thrust else `× 0.25`;
    - otherwise full.

- [ ] **Step 1: Write the failing tests** (a watchman or swordsman spawned in light 4 m from the intruder, unless stated):
  - `I5 a guard who sees him in light takes him on`: within 240 frames `g.state == COMBAT and g._target == intruder`.
  - `I6 his exposure follows the light and his crouch: lit > dark, crouched < standing`.
  - `I7 his quick cut reaches a guard through take_hit`: a relaxed swordsman in reach, `swing(&"left")`; the guard's `struck_by` fires with kind `quick`.
  - `I8 a guarding guard blocks his cut`: swordsman in combat with `_fighter.guarding = true`, `_parry_at = -1`; `swing(&"right")` → struck_by result `blocked`.
  - `I9 his parry throws a guard's blow aside`: swordsman forced to `_fighter._start(&"overhead")`; `guard_up(true)` 0.1 s before contact → guard `_stagger > 0` and posture up by ≥ 34.
  - `I10 his read-outs follow his swing`: during windup `threat_phase() == &"windup"` and `time_to_contact() > 0`; the serial changes per swing.
  - `I11 a squad reads his turtle`: two guards in combat within 3 m, `guard_up(true)` held 8 s → `SquadScript.of(intruder).read[&"turtle"] > 0.55`.
  - `I12 plot armour: blows cannot take him under 30%; after fall() they kill him`.
  - `I13 his block feeds the squad's parry and dodge reads through defended/dodged`.
- [ ] **Step 2: Run** intruder_test. Expected: I5–I13 FAIL.
- [ ] **Step 3: Implement** `Intruder.gd` interface and `IntruderCombat.gd`.
- [ ] **Step 4: Run** intruder_test. Expected: I1–I13 PASS, no SCRIPT ERROR.
- [ ] **Step 5: Commit** `feat(showcase): the intruder answers to the guards as the player does`.

### Task 3: The intruder's brain, sneak gait, and the audio/time hooks

**Files:**
- Create: `scripts/Showcase/IntruderBrain.gd`
- Modify: `scripts/Showcase/Intruder.gd`, `scripts/AISystem/GuardRig.gd`, `scripts/Audio/Sfx.gd`, `scripts/Audio/Music.gd`, `scripts/Visual/TimeFx.gd`
- Test: `tests/intruder_test.gd`

**Interfaces:**
- `IntruderBrain.gd` (`extends RefCounted`, `_init(intruder, combat)`), called from `Intruder._puppet_drive(delta)` as `brain.drive(delta)`:
  - `func go_to(point: Vector3, gait: StringName) -> void` (`&"sneak"` 1.3 m/s crouched, `&"walk"` 1.6, `&"run"` 4.6; uses the puppet's `_go_to`/`_walk`/`_face`)
  - `func hide_at(point: Vector3) -> void` (go there sneaking, then crouch still)
  - `func backstab(victim: Node3D) -> void` (sneak to 1.1 m behind him, then `combat.backstab`)
  - `func fight(tactic: StringName, target: Node3D = null) -> void`
  - `func flee_by(route: Array[Vector3]) -> void` (runs them in turn; links carry him: GuardClimb)
  - `func face(point: Vector3) -> void`, `func stand() -> void`
  - `func done() -> bool` (the current verb finished: arrived, stabbed, route run)
  - `func activity() -> StringName` (`&"sneak"` when crouched: `Intruder.activity()` returns it before `super`)
  - `func on_warned(from: Node3D) -> void` (a blow is coming at him: the tactic decides parry, block, dodge or nothing)
  - `var tactic: StringName`, `var focus: Node3D`
- Fight tactics (each picks the nearest living guard in combat as its man unless `focus`); `fight` sets the puppet's `state = COMBAT` directly (the rig's fighting stance), `stand()` sets `RELAXED`:
  - `trade`: parry 45% / block 45% / nothing 10%; a cut back 0.25 s after his recovery, every 1.2–1.8 s otherwise; faces his man; keeps 1.6 m.
  - `turtle`: guard held; a swing only every 4 s.
  - `parry`: parry 85% of blows (timed off `warn_attack` and the attacker's `_phase_timer`), riposte after each parry; no other swings.
  - `focus`: goes for `focus` (walks round others), trade-style defence, cuts only at `focus`.
  - `press`: goes for the man with the lowest `Squad.will_of` resolve; cuts every 1.0 s; never strikes a man whose `activity()` is a plea.
  - `spare`: faces the nearest beggar, then walks away 10 m.
- `GuardRig._show_activity`: `&"sneak"`: `Crouch_Fwd_Loop` paced by speed when moving, `Crouch_Idle_Loop` when still (like the swim case).
- `Sfx._process` and `Music` (health read and hurt sting): treat a `player`-group node with `puppet == true` as unhurt (health 1.0).
- `TimeFx`: `static var base := 1.0`, `static func set_base(scale: float) -> void`; `_apply` sets `Engine.time_scale = base × min(requests)`.

- [ ] **Step 1: Write the failing tests:**
  - `I14 go_to(sneak) arrives, crouched, showing "sneak"`.
  - `I15 backstab kills an unaware guard from behind`: a relaxed watchman facing away; `backstab(g)`; within 600 frames `not is_instance_valid(g) or g._knocked_out`.
  - `I16 in trade he parries or blocks most of a swordsman's blows over 20 s`: count `defended` ≥ 60% of the guard's strikes.
  - `I17 press never strikes a begging man`: a broken, begging watchman beside a fighting one; no `struck_by` on the beggar in 10 s.
  - `I18 his hurt muffles nothing`: at 30% health `Sfx.world_cutoff_for` input stays 1.0 (read the value `Sfx` computed).
  - `I19 TimeFx.set_base(0.5) halves time, and a hit-stop under it restores 0.5 after`.
- [ ] **Step 2: Run** intruder_test. Expected: I14–I19 FAIL.
- [ ] **Step 3: Implement** the brain, the sneak case, and the Sfx/Music/TimeFx hooks.
- [ ] **Step 4: Run** intruder_test (I1–I19 PASS), then every existing suite (all PASS).
- [ ] **Step 5: Commit** `feat(showcase): the intruder's brain, sneaking, and time and sound hooks`.

### Task 4: Guard stations (camp life)

**Files:**
- Create: `scripts/AISystem/GuardStation.gd`, `scripts/AISystem/GuardRota.gd`
- Modify: `scripts/AISystem/Guard.gd`, `scripts/AISystem/GuardRig.gd`
- Test: `tests/stations_test.gd`, `tests/stations_test.tscn`

**Interfaces:**
- `GuardStation` (`class_name GuardStation`, `extends Marker3D`, joins group `&"guard_stations"`):
  - `@export var kind: StringName = &"sit"`: `sit`, `eat`, `sleep`, `rummage`, `carry`, `chop`, `lean`
  - `@export var chest: NodePath` (rummage: a `Chest.gd` hinge)
  - `@export var drop_to: NodePath` (carry: a Marker3D; this station is the pick-up)
  - `var holder: Node = null`
- `Guard`: `@export var stations: Array[NodePath] = []` (a rota; one entry is a single station); `var _rota: RefCounted` (made in `_ready`).
  - `_do_patrol`: `if _rota.has_stations(): _rota.patrol(delta); return` at its top.
  - `_set_state`: leaving RELAXED calls `_rota.stir()`.
  - `_physics_process`: `elif _rota.busy(): _stop(delta)` beside `_hands.busy()`.
  - `_sense_vision`: returns early while `_rota.asleep()`; `hear_sound`: acuity × `GuardRota.SLEEP_HEARING` while asleep.
  - `activity()`: `_rota.activity()` before `_life.activity()`.
- `GuardRota.gd` (`extends RefCounted`, `_init(guard)`, `setup(paths: Array[NodePath])`):
  - constants: `SIT_DOWN 1.3`, `STAND_UP 1.1`, `LIE_DOWN 2.0`, `WAKE 2.4`, `LID 0.8`, `LIFT 0.9`, `SET_DOWN 0.9`, `RUMMAGE_TIME Vector2(6, 10)`, `EAT_EVERY Vector2(6, 11)`, `CONSUME 2.0`, `REST_EVERY Vector2(15, 25)`, `STATION_RETURN 6.0`, `SLEEP_HEARING 0.15`, `CARRY_OFFSET Vector3(0, 1.0, -0.42)`, `CARGO_REACH 1.8`; measure the clip lengths in Step 3 and set the times to them.
  - `has_stations() -> bool`, `patrol(delta: float) -> void`, `activity() -> StringName`, `stir() -> void`, `busy() -> bool`, `asleep() -> bool`, `var carried: RigidBody3D`
  - Activities it reports: `sit_down`, `sit`, `sit_talk` (seated and `_life.talking()`), `stand_up`, `eat`, `lie_down`, `sleep`, `wake`, `lid`, `rummage`, `lift`, `carry`, `set_down`, `chop`, `lean`.
  - Seated, he calls `_life.at_rest(delta)` so gossip with a friend near can start.
  - Rummage: `lid` (`chest.frob(guard)`), `rummage` for a `RUMMAGE_TIME` draw with one muttered line (`RUMMAGE_LINES`, three lines, e.g. "Where's the damned lamp oil..."), `lid` (close), next station.
  - Carry: the nearest node of group `&"cargo"` within `CARGO_REACH` of the pick-up; frozen, collision off and held at `CARRY_OFFSET` while carried; set down at `drop_to` with 0.55 m stacking; no cargo left at the pick-up: the two ends swap.
  - Chop: `chop` loop; every `REST_EVERY` draw a 1.3 s `drink`.
  - Lean: `lean` facing the station; a lookout's head sweeps (`_life.watch_yaw` into `_head_yaw_goal`).
  - `stir()`: seated → `stand_up`; asleep → `wake`; carrying → the crate dropped loose (unfrozen, collision back, the guard's velocity); lid open → closed with a 50 dB `SoundBus` "clang"; then released from the station. `busy()` is true during `stand_up` and `wake`.
  - Back RELAXED for `STATION_RETURN` s: he walks back to his station.
- `GuardRig.ACTIVITIES` gains: `sit` `[Sitting_Idle_Loop, true]`, `sit_talk` `[Sitting_Talking_Loop, true]`, `eat` `[Consume, true]` (seated), `rummage` `[Crouch_Idle_Loop, true]`, `chop` `[TreeChopping_Loop, true]`, `lean` `[Idle_Rail_Loop, true]`; special cases in `_show_activity`: `sit_down` (Sitting_Enter), `stand_up` (Sitting_Exit), `sleep` (LayToIdle held at 0), `lie_down` (LayToIdle backwards), `wake` (LayToIdle forwards), `lid` (Chest_Open), `lift`/`set_down` (PickUp_Table forwards/backwards), `carry` (Walk_Carry_Loop paced by speed, held at 0.3 when still).

- [ ] **Step 1: Write the failing tests** in `tests/stations_test.gd` (one guard per station, a bench block for seats, a chest, cargo crates):
  - `T1 a man with a sit station walks there, sits (sit_down then sit), and faces its way`.
  - `T2 two seated men at ease within 3.8 m talk: one shows sit_talk`.
  - `T3 stirred (alert to 40), a sitter shows stand_up, is busy, then leaves RELAXED`.
  - `T4 a sleeper sees nothing in light at 5 m for 3 s, hears a 50 dB noise at 4 m at ×0.15, and wakes (wake) when it reaches suspicious`.
  - `T5 the quartermaster opens a chest, rummages, mutters, closes it, and goes to the next`.
  - `T6 the carrier carries a crate from the pick-up to drop_to and sets it down; stirred mid-carry, the crate falls loose and Dangers.throwables_near finds it`.
  - `T7 stirred with a lid open, the lid is shut and a clang is heard on the SoundBus`.
  - `T8 calm again for STATION_RETURN s, he goes back to his station`.
  - `T9 two men never hold one station`.
- [ ] **Step 2: Run** `$GODOT --headless --fixed-fps 60 --quit-after 40000 --path . res://tests/stations_test.tscn`. Expected: FAIL.
- [ ] **Step 3: Implement** `GuardStation`, `GuardRota`, the Guard hooks and the rig clips. Print each clip's `action_length` once and set the rota times to match.
- [ ] **Step 4: Run** stations_test (T1–T9 PASS), then every existing suite (all PASS).
- [ ] **Step 5: Stage** each station kind with a quick stager (`tests/visual/stage_stations.gd`: one man per station, 3 cameras) and look at the images: seat height, lying pose, carry grip. Fix what reads wrong.
- [ ] **Step 6: Commit** `feat(ai): guard stations: sit, eat, sleep, rummage, carry, chop, lean`.

### Task 5: The yard, the cast, and a performance check

**Files:**
- Create: `maps/npc_showcase.gd`, `maps/npc_showcase.tscn`
- Test: windowed fps report; `tests/showcase_test.gd`, `tests/showcase_test.tscn` (D1 only here)

**Interfaces:**
- `npc_showcase.gd` (`extends Node3D`) builds, in code (patterns from `maps/npc_gym.gd` `_torch`, `_stairs`, `_environment`, `_build_waterside`, and `maps/retro_showcase.gd`):
  - the yard (40 × 30 m, origin at its centre, gate on +Z, postern at the north-east corner), a 4 m curtain wall with a 1.6 m wall-walk and parapet, stairs at the west and east ends; the tower (north-west, 7 m platform with stairs, `AlarmBellScript.build`); open shed (west), store shed (east), fire (`Fire.gd`) with a log bench each side, woodpile and block, well, cart;
  - outside the north wall: lean-to roofs 2.5 m below the wall-walk and a canal (`WaterVolume`, 3 m deep);
  - lights: moon (DirectionalLight3D, low energy, blue), the fire, torches at the gate and tower (`Torch.gd`), a dim torch at the postern (tuned in Task 7 so Ned can see the murder);
  - landmarks (`&"landmarks"` group): the fire, the well, the gate, the tower, the store, the shed, the postern;
  - stations and props: 2 seats and an eat seat on the benches, a bedroll (sleep) in the shed, three chests in the store (Gideon's rota), cart pick-up with 4 crates in group `&"cargo"` and a drop marker in the store, the chopping block, the tower rail (lean);
  - `var cast := {}` name → guard, spawned with pinned `look_seed`, `temperament`, `given_name` (the Global Constraints cast); Wat's wall-walk route and Hendrik's yard route as waypoint nodes; Jory posted at the postern facing out;
  - `var marks := {}` name → Vector3 for the story (the intruder's drop-in point behind the store, his hiding spot, the fire, the escape route);
  - `func build() -> void`, `func spawn_intruder(at: Vector3) -> Node3D`;
  - `NavBaker` over the whole map; `await baker.baked` before the director starts.
  - Every guard's `Bark` Label3D hidden (`_bark_label.visible = false`): the overlay shows speech instead.
  - `--fps-report=N`: prints average and lowest fps over N seconds of Act I, then quits.
- [ ] **Step 1: Write the failing test** `D1 the yard builds and bakes, every cast member stands at his place, and each station has its man` in `tests/showcase_test.gd` (instantiates `maps/npc_showcase.tscn` with the director off).
- [ ] **Step 2: Run** showcase_test. Expected: FAIL (no map).
- [ ] **Step 3: Implement** the map (no director yet: the cast just lives).
- [ ] **Step 4: Run** showcase_test (D1 PASS). Then windowed: `$GODOT --path . --resolution 1920x1080 res://maps/npc_showcase.tscn -- --fps-report=30`. Expected: average ≥ 60 and lowest ≥ 45. If not, cut Col, then Hendrik, then Gideon (in that order) until it holds, and record the result in the commit message.
- [ ] **Step 5: Stage** a wide shot and three close shots of the yard at rest (a small stager, `tests/visual/stage_showcase.gd`, `--out=<dir>`); check that the buildings read, the lighting is moody but legible, and the camera can see into every shed.
- [ ] **Step 6: Commit** `feat(showcase): the garrison yard and its people`.

### Task 6: The director engine

**Files:**
- Create: `scripts/Showcase/ShowDirector.gd`
- Modify: `maps/npc_showcase.gd`
- Test: `tests/showcase_test.gd`

**Interfaces:**
- `ShowDirector.gd` (`extends Node`, `process_mode = PROCESS_MODE_ALWAYS`):
  - `static var start_act := 1`, `static var ending: StringName = &"random"` (survive `reload_current_scene`)
  - `signal act_started(index: int, title: String)`, `signal beat_started(name: StringName, shot: Dictionary)`, `signal beat_skipped(name: StringName)`, `signal show_ended`
  - `func setup(map: Node3D, story: RefCounted) -> void`, `func run() -> void`
  - Beat dictionary: `{"name": StringName, "do": Callable, "until": Callable (→ bool), "min": float, "timeout": float, "shot": Dictionary}`; an act: `{"title": String, "setup": Callable, "beats": Array}`.
  - A beat runs `do` once, then waits until `until` is true (after at least `min` s) or `timeout` s pass (then emits `beat_skipped`, prints `[show] skipped <name>`); the next beat starts.
  - `func jump_to(act: int) -> void`: `start_act = act`, clears `SquadScript`, `GarrisonScript`, `TimeFx`, `LightProbe`, reloads the scene.
  - `func next_beat() -> void`, `func cycle_ending() -> void`, `func chosen_ending() -> StringName` (random resolves once per run with the run's seed)
  - Keys (in `_unhandled_input`): 1–5 `jump_to`, N `next_beat`, E `cycle_ending`, R `jump_to(1)`, Space pause (`get_tree().paused`), `[` / `]` show speed ¼, ½, 1 (`TimeFx.set_base`).
  - Command line after `--`: `--act=N`, `--ending=overwhelmed|victor|escape`, `--auto`, `--quit-at-end` (quits 3 s after `show_ended`).
  - Determinism: before spawning the cast, `TemperamentScript.rolling = false`, `GuardScript.randomize_on = false`, `seed(1926)`; `randomize_on` back to true after the cast is in.
- [ ] **Step 1: Write the failing tests:**
  - `D2 a beat whose condition never comes true times out, is skipped with a log line, and the next beat starts` (a two-beat test story).
  - `D3 --act=3 --ending=escape are read from the command line` (call the parser with a fake argument list).
  - `D10 jumping acts twice leaves one cast, no hunts, no garrison memory, and time at 1`.
  - `D11 paused during a hit-stop, time comes back at the show speed after unpausing`.
- [ ] **Step 2: Run** showcase_test. Expected: D2, D3, D10, D11 FAIL.
- [ ] **Step 3: Implement** the director and wire it into the map (`--auto` or no args: Act 1).
- [ ] **Step 4: Run** showcase_test. Expected: D1–D3, D10, D11 PASS.
- [ ] **Step 5: Commit** `feat(showcase): the director runs acts and beats`.

### Task 7: The story, Acts I–III (rest, murder, the cry)

**Files:**
- Create: `scripts/Showcase/ShowNight.gd`
- Modify: `maps/npc_showcase.gd`
- Test: `tests/showcase_test.gd`

**Interfaces:**
- `ShowNight.gd` (`extends RefCounted`, `_init(map)`): `func acts() -> Array` (five act dictionaries), plus a condition helper per beat. Act titles exactly: `"I. The Watch at Rest"`, `"II. A Knife in the Dark"`, `"III. The Cry"`, `"IV. Steel"`, `"V. "` + `"Overwhelmed"`, `"The Victor"` or `"Over the Wall"`.
- Act I beats (≈70 s, all `until` by time): establishing crane; the fire talkers (their `_life._talk_rest` set to 0–3 s at act start); the sitters; the sleeper; the quartermaster; the carrier; the chopper; Wat stopping on the wall; the lookout. Shots name their subjects.
- Act II: setup spawns the intruder at `marks.drop_in` with `exposure_scale = 0.25`; beats: drop in and sneak along the store (`go_to(sneak)`); wait in the shadow until Wat is ≥ 12 m away on the wall-walk; `backstab(Jory)`; at the kill `exposure_scale = 1.0` and Ned's rota is timed so he rounds the store as Jory falls (hold him at a rota point until the intruder is 4 m from Jory); the witness beat waits until Ned's state ≥ SEARCHING or he barks "Murder" (timeout 12 s).
- Act III: setup (for a jump) kills Jory at setup through `take_hit(999, intruder, &"backstab", ...)`, puts the intruder at the postern and Ned at the body with alert 100; beats: the ripple (until the talkers, sitters, sleeper and chopper are all out of RELAXED; timeout 20 s); the intruder breaks sight to `marks.hide` (`hide_at`) until no guard has `can_see_target` for 3 s; the hunt (until two men searching and one lantern lit; timeout 30 s).
- [ ] **Step 1: Write the failing tests** (headless runs of each act from its own setup with the director at `--auto`):
  - `D4 Act I: every stationed man shows his station's activity at least once, and a pair talk`.
  - `D5 Act II: Jory dies by backstab, the damping is off after the kill, and Ned sees it (combat or searching, or a Murder bark) within 12 s`.
  - `D6 Act III: within 30 s every man is out of RELAXED, the bell has rung, and at least two men search`.
- [ ] **Step 2: Run** showcase_test. Expected: D4–D6 FAIL.
- [ ] **Step 3: Implement** Acts I–III. Tune the postern torch and Ned's timing until D5 passes.
- [ ] **Step 4: Run** showcase_test. Expected: D1–D6, D10, D11 PASS.
- [ ] **Step 5: Commit** `feat(showcase): acts I-III: the watch at rest, the murder, the cry`.

### Task 8: The story, Acts IV–V (the fight and the endings)

**Files:**
- Modify: `scripts/Showcase/ShowNight.gd`
- Test: `tests/showcase_test.gd`

**Interfaces (beats and their `until`, timeouts in brackets):**
- Act IV setup (for a jump): the intruder at the fire, Mirelle, Osric, Brand and Wat in combat with him, the rest arriving; garrison dread from one death.
  - `found`: the intruder steps into the firelight: until 2 men are in combat [15 s]
  - `trade`: `fight(&"trade")`: until 2 flankers hold flank places or 20 s [25 s]
  - `turtle`: `fight(&"turtle")`: until the squad plan is `break` and Brand's role is `breaker` [25 s]
  - `parry`: `fight(&"parry", Osric)`: until Osric is dead [35 s]
  - `focus`: `fight(&"focus", Mirelle)`: until Mirelle is dead [40 s]
  - `press`: `fight(&"press")`: until a man shows a plea activity [30 s]
- Act V setup (for a jump): Osric and Mirelle dead (by `take_hit`), squad heart lowered through the garrison's dread, a watchman broken.
  - overwhelmed: `fall()` and `fight(&"trade")`: until the intruder is dead [60 s]; a last wide shot.
  - victor: `fight(&"spare")`: until the spared man has run ≥ 10 m; then the intruder walks out of the gate [40 s]
  - escape: `flee_by(marks.escape)` (up the east stairs, the wall-walk, drop to the roofs, into the canal): until he is in the water and a guard has followed him onto a roof or into the water [60 s]
- [ ] **Step 1: Write the failing tests** (each from its act's setup):
  - `D7 Act IV: turtle brings the squad's break plan with Brand as breaker; parry leaves Osric dead; focus leaves Mirelle dead and Brand berserk; press brings a plea` (log which beats timed out; the check needs turtle, parry and focus to succeed).
  - `D8 each ending finishes before its timeout: overwhelmed (intruder dead), victor (the spared man ran ≥ 10 m), escape (intruder afloat, a guard followed)` (three sub-runs).
  - `D9 the whole night from Act I with --auto plays to show_ended in under 7 minutes of game time with no SCRIPT ERROR`.
- [ ] **Step 2: Run** showcase_test. Expected: D7–D9 FAIL.
- [ ] **Step 3: Implement** Acts IV–V. When a beat times out in D7, fix the tactic, not the condition.
- [ ] **Step 4: Run** showcase_test. Expected: D1–D11 PASS.
- [ ] **Step 5: Commit** `feat(showcase): act IV and the three endings`.

### Task 9: The show camera

**Files:**
- Create: `scripts/Showcase/ShowCamera.gd`
- Modify: `maps/npc_showcase.gd`
- Test: `tests/showcase_test.gd`

**Interfaces:**
- `ShowCamera.gd` (`extends Camera3D`, `process_mode = PROCESS_MODE_ALWAYS`, moves on real time from `Time.get_ticks_usec()`):
  - `enum Mode { FREE, FOLLOW, DIRECTOR }`, `var mode := Mode.DIRECTOR`
  - `func want(shot: Dictionary) -> void` (from `beat_started`): `{"type": &"wide"|&"two"|&"close"|&"track"|&"reveal", "subjects": Array[Node3D], "hold": float}`
  - `func follow(target: Node3D) -> void`, `func next_follow() -> void` (Tab, through the cast)
  - Free: WASD, Q/E down/up, right mouse held to look, Shift ×4, scroll ×1.25 per notch (0.5–40 m/s).
  - Follow: orbit at distance 2–20 m (scroll), height 1.7 m target, name card via the overlay.
  - Director: glides on a critically damped spring (half-life 0.6 s); cuts when the new framing is > 25 m away; with no shot, frames the man whose state changed most recently.
  - Any fly key or mouse motion in DIRECTOR mode → FREE; C → DIRECTOR.
  - A followed man freed: keeps framing his last position for 2 s, then DIRECTOR.
  - Shot framing (subjects' centre `c`, their spread `r`): wide = high crane at 22 m back, 14 m up; two = side-on at 2.2 × r + 3 m; close = 1.6 m in front of the face, level; track = 4 m behind and 2 m up, looking ahead; reveal = starts as close, pulls back to wide over `hold` s.
- [ ] **Step 1: Write the failing tests:**
  - `D13 following a man who dies, the camera frames where he fell, then returns to DIRECTOR within 3 s, with no errors`.
  - `D14 a "close" shot on a guard ends with his head in the middle third of the view`.
  - `D15 moving in FREE mode while paused changes the camera position`.
- [ ] **Step 2: Run** showcase_test. Expected: D13–D15 FAIL.
- [ ] **Step 3: Implement** the camera; the map adds it and connects `beat_started`.
- [ ] **Step 4: Run** showcase_test. Expected: D1–D15 PASS.
- [ ] **Step 5: Commit** `feat(showcase): the show camera: free, follow, director`.

### Task 10: The viewer overlay

**Files:**
- Create: `scripts/Showcase/ShowOverlay.gd`
- Modify: `maps/npc_showcase.gd`
- Test: `tests/showcase_test.gd`

**Interfaces:**
- `ShowOverlay.gd` (`extends CanvasLayer`, `process_mode = PROCESS_MODE_ALWAYS`):
  - `func watch(guard: Node3D, role: String) -> void` (connects `barked` and `alert_changed`)
  - Subtitles: `"<Name>: <line>"`, anchored over the speaker's head (screen projection, clamped to the screen), at most 3, only for speakers inside the view frustum and within 30 m of the camera, each 3.5 s then a 0.5 s fade.
  - Marks over the head for 2 s: `?` on SUSPICIOUS, an eye on INVESTIGATING or SEARCHING, `!` on COMBAT, a white flag while `activity()` is a plea (drawn in code: `Label` glyphs for `?` and `!`, a small `Polygon2D` flag and eye).
  - `func title(text: String) -> void`: centred, serif, 2.5 s in, hold, fade (from `act_started`).
  - `func name_card(text: String) -> void`: bottom-left while following ("Aldous, lookout").
  - H toggles `visible` for everything.
- `Guard.gd` is not changed for this: the map hides every `Bark` Label3D (Task 5).
- [ ] **Step 1: Write the failing tests:**
  - `D16 a bark from a guard in view shows as a subtitle with his name; one behind the camera does not`.
  - `D17 a man going to COMBAT shows "!" over him for about 2 s`.
  - `D18 H hides every subtitle, mark and title`.
- [ ] **Step 2: Run** showcase_test. Expected: D16–D18 FAIL.
- [ ] **Step 3: Implement** the overlay; the map calls `watch` for each cast member with his role.
- [ ] **Step 4: Run** showcase_test (D1–D18 PASS), then every existing suite (all PASS).
- [ ] **Step 5: Commit** `feat(showcase): subtitles, marks, titles and name cards`.

### Task 11: The unattended run, the review sheet, the final check

**Files:**
- Modify: `tests/visual/stage_showcase.gd`, `maps/npc_showcase.gd` (header doc: keys, flags, the Movie Maker command)
- Test: `tests/showcase_test.gd` (D12), the stager, Movie Maker

**Interfaces:**
- `stage_showcase.gd --out=<dir>`: runs the night with `--auto`, grabs a still at each beat start and at each ending's last beat (three endings), and writes `sheet.png` (a grid with each still labelled by act and beat).
- [ ] **Step 1: Write the failing test** `D12 with the intruder dead mid-beat (the overwhelmed ending) and 5 more seconds of keys (N, E, 4), there are no errors and no verbs issued to him`.
- [ ] **Step 2: Run** showcase_test. Expected: D12 FAIL until the director guards every verb on `is_instance_valid(intruder) and not intruder.is_dead`.
- [ ] **Step 3: Implement** the guard, the stager's sheet and the map's header doc.
- [ ] **Step 4: Run** the stager (`perl -e 'alarm 900; exec @ARGV' $GODOT --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_showcase.tscn -- --out=<scratchpad>/showcase`) and look at the sheet; fix framing problems. Then Movie Maker for the escape ending: `$GODOT --path . --write-movie <scratchpad>/showcase.avi --fixed-fps 60 --resolution 1920x1080 res://maps/npc_showcase.tscn -- --auto --ending=escape --quit-at-end`. Expected: the file is written and the process exits by itself.
- [ ] **Step 5: Run** every suite (all PASS, no SCRIPT ERROR).
- [ ] **Step 6: Commit** `feat(showcase): the review sheet and the unattended run`.
- [ ] **Step 7: Request the final review** (superpowers:requesting-code-review) of the whole branch against the spec, fix what it confirms, re-run every suite, commit.
