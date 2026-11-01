# Hunts 1: to the first playable loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix fight movement, build the bestiary, status, round, loadout and safe-place spine, and add the plain floating eye, so the user can play clue → pack → fight in a hunt gym and judge the tempo.

**Architecture:** Bestiary, rounds and prep items are `Spells.gd`-style data tables. Monsters are `CharacterBody3D`s that implement the same `take_hit(damage, attacker, kind, point, direction) -> StringName` as guards, so the revolver, Shard and kick reach them unchanged. Round type reaches monsters by a hint set before the hit (as `gib_hint` does for guards), so guards keep treating every round as a bullet. Nothing changes outside a hunt: the default loadout is lead only and unlocked, and PowerPool's refill stays as it is.

**Tech Stack:** Godot 4.5.1, GDScript, headless check suites (`tests/*.tscn`), Blender for the eye model.

**Spec:** `docs/superpowers/specs/2026-11-01-hunt-combat-design.md`

**Scope of this plan:** the spec's order of parts 1–3. Parts 4–8 (ánimas, revenants, the first real hunt, variants, spectres) get their own plans **after** the user's tempo verdict in Task 14.

**Deferred on purpose:** choosing spells at the table (only three exist beside Blink, so there is no choice until the spectres' reveal power); gear (arrives with the coat and ánimas); shields as brushed ink and power in the veins (the veins need the arms with the user); bestiary pages beyond the pencil note.

**Weight:** the spec's weight items are met by measuring pacing in Task 1 (shots are already 0.6 s at the hip and 0.35 s aimed, so no change is assumed), casts that commit you (FM12), weapon-scaled pushes and a heavier hold on the right answer (Task 6), then the knobs in Task 14. Weight is the user's verdict, not a suite's.

## Global Constraints

- Branch `hunt-combat`, worktree `.claude/worktrees/hunt-combat`. Fresh-worktree setup: copy the main checkout's `.godot`, run `python3 tools/local_assets.py pull`, then `Godot --headless --path . --import`.
- Godot binary: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`. Suites run as `Godot --headless --fixed-fps 60 --path . res://tests/<name>.tscn`, print `PASS`/`FAIL` lines and exit non-zero on failure.
- Tests are written first and seen to fail. Style: see `tests/ammo_ui_test.gd` (a `Node3D` with `_check(label, ok)`, a one-node `.tscn`). Each new randomness uses a seeded `RandomNumberGenerator`; do not add draws to the global stream (`headless-test-determinism`).
- Every in-game word is the user's. Stand-ins go in `<<...>>` (job files) or are listed in `docs/superpowers/refs/hunt/words_needed.md` with their intent.
- No free VFX assets. No tesla arcs. Every strange thing has a cause in the world. UI is judged in the real game, never over a mock backdrop.
- The protagonist is the Exsecrator in new text. Don't rename old docs.
- First-person poses are never computed and shown as final: use existing poses or stand-ins, and list new poses needed for live Blender with the user.
- Match the surrounding GDScript: tabs, `##` doc comments in plain sentences, `const X := preload(...)`, blank lines between blocks.
- Melee numbers don't change. Blade and bow dodging stay on Q with `dodge_speed`, `dodge_time` as they are.

## Review Focus

- **Switching rounds with an empty pouch, or mid-reload:** refused with a dry click, nothing lost (test in Task 7).
- **The player dies with eyes on them, or while gazed at:** eyes stop attacking and nothing errors (test in Task 11).
- **Sliding into a wall, off an edge, or stopping under a low roof:** no stuck state; stays crouched until there is room (test in Task 4).
- **An old save without `cylinder_round` or the new stocks:** loads as lead with empty new pouches (test in Task 7).
- **A shell's pellets all landing in one tick on a monster that dies from the first:** one death, one refund, later pellets return `&"none"` (test in Task 6).

---

## Part zero: fight movement

### Task 1: The fight-move diagnosis

**Files:**
- Create: `tests/diag_fight_moves.gd`, `tests/diag_fight_moves.tscn`
- Create: `docs/superpowers/refs/hunt/fight_moves_baseline.md`

**Interfaces:**
- Produces: a scene that drives the real `Player.tscn` on a flat 40 × 40 m block via `Input.action_press`, revolver drawn (`Props.give_revolver`, `select_by_id(&"revolver")`), and prints one table row per move.

- [ ] **Step 1: Write the harness.** It measures and prints, each from standing start and with the camera pinned:

  | Row | Measures |
  |---|---|
  | strafe start | seconds to 90 % of `walk_speed` sideways |
  | strafe stop | seconds from release to under 0.2 m/s |
  | strafe reverse | seconds from a held left to 90 % held right |
  | strafe + sprint | sideways speed with sprint held; does `Revolver.ready_to_fire()` stay true? |
  | aim strafe | sideways speed aimed (`aim` action held) |
  | fire while strafing | shots landed in 3 s at walk |
  | gun lateral swing | peak-to-peak of `player.hand` item position in camera space over 2 s of strafing |
  | Q tap, gun drawn | distance, seconds, power spent |
  | Q tap, sword drawn | dodge distance and seconds (`Props.give_weapons`) |
  | shot cadence | seconds between shots, hip and aimed |
  | full reload | seconds, empty to six |

- [ ] **Step 2: Run it** and confirm a full table with no `SCRIPT ERROR`.

  Run: `Godot --headless --fixed-fps 60 --path . res://tests/diag_fight_moves.tscn`

- [ ] **Step 3: Write the numbers into `fight_moves_baseline.md`,** one line per row, plus what each number means for the player. Any surprise beyond what the next tasks fix goes in a "still open" list there.

- [ ] **Step 4: Commit** `tests/diag_fight_moves.*`, the baseline, message `test(fight): measure every fight move as it stands`.

### Task 2: Strafing

**Files:**
- Create: `tests/fight_move_test.gd`, `tests/fight_move_test.tscn`
- Modify: `scripts/PlayerController.gd` (`_apply_horizontal_movement`, `_is_sprinting`), `scripts/Combat/Revolver.gd` (`_send_pose`)

**Interfaces:**
- Produces: suite `fight_move_test` that later tasks add to.
- Produces: `PlayerController._sprint_counts(wish: Vector3) -> bool`: sprint held and `wish` within 60° of facing.

- [ ] **Step 1: Write the failing checks.**
  ```gdscript
  # all with the revolver drawn, unaimed
  _check("FM1 strafe reaches 90% of walk within 0.2 s", start <= 0.2)
  _check("FM2 strafe stops within 0.2 s", stop <= 0.2)
  _check("FM3 reversing reaches 90% the other way within 0.35 s", reverse <= 0.35)
  _check("FM4 sprint held while strafing stays at walk speed", absf(side_speed - p.walk_speed) < 0.3)
  _check("FM5 the gun stays ready through a sprint-held strafe", ready_every_tick)
  _check("FM6 sprinting forward still lowers the gun", not p.revolver.ready_to_fire())
  ```

- [ ] **Step 2: Run** `res://tests/fight_move_test.tscn`. Expected: FM4 and FM5 fail, since sprint applies in every direction today and lowers the gun. FM1–3 may already pass; if any fail, the fix belongs in Step 3.

- [ ] **Step 3: Implement.** `_sprint_counts(wish)` replaces the bare `_held(&"sprint")` in `_apply_horizontal_movement`'s target speed. `Revolver._send_pose`'s `sprinting` uses it too. Free-run stays on `_held(&"sprint")`. If FM1–3 failed, tune `start_time`, `stop_time_walk`, or `turn_acceleration_walk`, and run `movement_gym_test`, `freerun_test` and `traversal_test`.

- [ ] **Step 4: Run** `fight_move_test`, `traversal_test`, `freerun_test`, `feel_test`. Expected: all pass.

- [ ] **Step 5: Commit** `feat(fight): strafing keeps the gun up and walks at any held key`.

### Task 3: A dodge with the gun

**Files:**
- Modify: `scripts/Combat/PlayerCombat.gd` (`_physics_process` near line 463, `_try_dodge`, DODGE phase at line 515), `scripts/Combat/Revolver.gd` (`ready_to_fire`)
- Test: `tests/fight_move_test.gd`

**Interfaces:**
- Produces: input action `gun_dodge` (`KEY_ALT`) via `_ensure_action`.
- Produces: `PlayerCombat.dodge_lets_fire() -> bool`: true outside DODGE, or from 60 % of its length on.
- Keeps: `dodged` signal and `dodged_within(seconds)`, which monsters use.

- [ ] **Step 1: Write the failing checks.**
  ```gdscript
  _check("FM7 Alt with the gun dodges", p.combat.phase == p.combat.Phase.DODGE)
  _check("FM8 a gun dodge carries at least 2.4 m", moved >= 2.4)
  _check("FM9 a gun dodge goes the way you are moving, or back", dot >= 0.9)
  _check("FM10 no shot in the first 60%, a shot after", not early and late)
  _check("FM11 the reload carries on through a dodge", p.revolver.is_reloading())
  _check("FM12 no dodge during a tome cast", p.combat.phase != p.combat.Phase.DODGE)
  _check("FM13 out of stamina: no dodge and no shove", still)
  _check("FM14 it costs stamina and no power", spent_stamina == 20.0 and power_before == p.power.power)
  _check("FM15 Q with the gun is still Blink", blinked)
  ```

- [ ] **Step 2: Run.** Expected: FM7 onward fail.

- [ ] **Step 3: Implement.** Add `const GUN_DODGE_SPEED := 13.0`, `const GUN_DODGE_TIME := 0.3`. `_try_dodge` reads these when `gun_drawn()`, else the `dodge_speed` and `dodge_time` exports, and stores the length in `_dodge_length` for the DODGE phase check. Refuse when `player.caster.casting()` is a `Spells.Tier.TOME` spell. `Revolver.ready_to_fire()` also requires `player.combat.dodge_lets_fire()`.

- [ ] **Step 4: Run** `fight_move_test`, `revolver_test`, `gunfight_test`, `combat_test`. Expected: all pass.

- [ ] **Step 5: Commit** `feat(fight): a free dodge with the revolver drawn`.

### Task 4: The slide

**Files:**
- Modify: `scripts/PlayerController.gd` (`_update_crouch`, `_apply_horizontal_movement`, jump path)
- Test: `tests/fight_move_test.gd`

**Interfaces:**
- Produces: `PlayerController.is_sliding() -> bool`; `signal slid`.
- Constants: `SLIDE_BOOST := 1.5` (m/s over your speed), `SLIDE_TIME := 0.8`, `SLIDE_MIN_SPEED := 7.0`, `SLIDE_STEER := 3.0` (m/s² across).

- [ ] **Step 1: Write the failing checks.**
  ```gdscript
  _check("FM16 crouch at a sprint on open floor slides", p.is_sliding() and p.is_crouched)
  _check("FM17 it carries at least 4 m", moved >= 4.0)
  _check("FM18 crouch from a walk is only a crouch", not p.is_sliding())
  _check("FM19 the gun is ready within 0.2 s of starting", ready_at <= 0.2)
  _check("FM20 jump ends it in a hop, keeping speed", in_air and speed >= 6.0)
  _check("FM21 letting go of crouch ends it standing", not p.is_sliding() and not p.is_crouched)
  _check("FM22 it goes under a 1.3 m beam and stays crouched until there is room", passed and not stuck)
  _check("FM23 into a wall it ends at once, no jitter", not p.is_sliding() and speed < 0.5)
  _check("FM24 off a drop it ends and you fall", not p.is_sliding() and p.velocity.y < 0.0)
  _check("FM25 at a ledge, sprint + crouch still climbs down", p.movement_state != p.MoveState.LOCOMOTION)
  ```

- [ ] **Step 2: Run.** Expected: FM16 onward fail, except FM18 and FM25.

- [ ] **Step 3: Implement.** Start in `_update_crouch` **after** the parkour-down check returns no edge: `_crouch_just_pressed` and horizontal speed ≥ `SLIDE_MIN_SPEED` and floor and not carrying. In `_apply_horizontal_movement`, a sliding branch sits beside the shove branch: speed eases from start speed to `crouch_speed` over `SLIDE_TIME`, with `SLIDE_STEER` across. Sound stand-in: `Sfx.play_flat(self, &"cloth", -4.0)`. Camera: `juice.on_crouch` plus a small roll via `juice.punch`.

- [ ] **Step 4: Run** `fight_move_test`, `traversal_test`, `freerun_test`, `movement_gym_test`. Expected: all pass.

- [ ] **Step 5: Commit** `feat(fight): a slide out of a sprint, shooting as you go`.

---

## Part one: the spine

### Task 5: Bestiary, sources and statuses

**Files:**
- Create: `scripts/Monsters/Bestiary.gd`, `scripts/Monsters/Statuses.gd`
- Create: `scripts/Combat/Rounds.gd`
- Create: `tests/bestiary_test.gd`, `tests/bestiary_test.tscn`

**Interfaces:**
- Produces, `Rounds.gd` (RefCounted):
  ```gdscript
  const TABLE := {
      &"lead": {"stock": &"rounds", "source": &"lead", "colour": Color(0.55, 0.48, 0.3)},
      &"copal": {"stock": &"copal_rounds", "source": &"copal", "colour": Color(0.72, 0.55, 0.22), "status": &"smoked"},
  }
  static func info(id: StringName) -> Dictionary
  ```
- Produces, `Bestiary.gd` (RefCounted):
  ```gdscript
  const TABLE := {&"floating_eye": {"health": 60.0, "weak": {&"shot": 1.0, &"copal": 1.2, &"obsidian": 1.5, &"blast": 1.5}, "resist": {&"lead": 0.4}}}
  static func info(kind: StringName) -> Dictionary
  static func source_of(hit_kind: StringName, round_id: StringName) -> StringName
  static func scale_for(kind: StringName, source: StringName) -> float   # 1.0 if neither
  static func is_weak(kind: StringName, source: StringName) -> bool
  static func is_resisted(kind: StringName, source: StringName) -> bool
  ```
  `source_of`: `&"bullet"` → the round's source; `&"shot"` → `&"shot"`; `&"blast"` → `&"blast"`; `&"shard"` → `&"obsidian"`; `&"fire"` → `&"fire"`; anything else → `&"blow"`. The spec's "Empower" source is `&"blast"`.
- Produces, `Statuses.gd` (Node, one per bearer):
  ```gdscript
  signal started(id: StringName)
  signal ended(id: StringName)
  func apply(id: StringName, seconds: float) -> void   # longest wins
  func has(id: StringName) -> bool
  func left(id: StringName) -> float
  func clear(id: StringName) -> void
  func save_state() -> Dictionary
  func load_state(state: Dictionary) -> void
  ```

- [ ] **Step 1: Write the failing checks** (B1–B10): each `source_of` mapping above; `scale_for(&"floating_eye", &"lead") == 0.4`; unknown source scale 1.0; `is_weak` and `is_resisted`; `Statuses`: apply, `has`, runs out after its seconds in game time, `started` and `ended` fire once each, a shorter re-apply doesn't shorten, save and load keep time left.

- [ ] **Step 2: Run.** Expected: FAIL, scripts missing.

- [ ] **Step 3: Implement** the three scripts.

- [ ] **Step 4: Run.** Expected: PASS.

- [ ] **Step 5: Commit** `feat(hunt): bestiary, round and status tables`.

### Task 6: The monster base, weakness and the payback

**Files:**
- Create: `scripts/Monsters/Monster.gd`, `tests/monster_test.gd`, `tests/monster_test.tscn`
- Modify: `scripts/Magic/PowerPool.gd`, `scripts/Combat/Revolver.gd` (`_confirm`, `_deal`, `_shell`), `scripts/PlayerController.gd` (player `statuses` child)

**Interfaces:**
- Consumes: `Bestiary`, `Statuses`, `Rounds`.
- Produces, `Monster.gd` (`class_name Monster`, extends `CharacterBody3D`, `collision_layer = 2`, group `&"monsters"`):
  ```gdscript
  signal died(by: Node)
  signal exposed_now
  const EXPOSED_TIME := 0.8
  const EXPOSED_SCALE := 2.0       # any hit while exposed
  const REFUND := 8.0              # power, on a weakness hit
  const REFUND_GAP := 0.25         # one shell pays once
  const WEAK_HITSTOP := 0.09
  @export var kind: StringName
  var health: float
  var eye_height := 99.0           # no headshots unless a kind says so
  var round_hint: StringName = &"lead"
  var dead := false
  var statuses: Node
  func take_hit(damage: float, attacker: Node3D, hit_kind: StringName, point: Vector3, direction: Vector3) -> StringName
  func is_exposed() -> bool
  func save_state() -> Dictionary
  func load_state(state: Dictionary) -> void
  ```
  `take_hit` returns `&"none"` if dead, else `&"killed"`, `&"weak"`, `&"resisted"` or `&"hit"`. The refund and exposure come from the source, so a killing weak blow still refunds. A dead monster hides and disables its collider; it never frees itself, so a save can keep it. It registers with `SaveGame.register` as guards do. It adds `player.add_collision_exception_with(self)` and the reverse, so bodies don't block each other.
- Produces, `PowerPool`: `var refill_scale := 1.0` (multiplies `REFILL`), `func refund(amount: float) -> void` (adds up to MAX, does not reset the delay).
- Produces, `Revolver._hint_round(target: Object)`: sets `round_hint` if the target has it, called before `take_hit` in `_deal` and the blast in `_shell`, in the manner of `_hint_gib`.
- Produces, `Revolver.hit_confirmed` kinds `&"weak"`, `&"resisted"` beside `&"shot"`, `&"headshot"`, `&"kill"`.
- Produces, player: `player.statuses` (a `Statuses` child), saved with the player like `revolver.save_state()` at `PlayerController.gd:4133`.

- [ ] **Step 1: Write the failing checks,** using a `Monster` of kind `floating_eye` on a block, the real player and real shots via `revolver._pull`. M3–M7 set `m.health = 500.0` first, since a full 60-health eye dies to one right answer and would return `&"killed"`:
  ```gdscript
  _check("M1 a lead ball does 0.4 of its damage", is_equal_approx(m.health, 60.0 - 55.0 * 0.4))
  _check("M2 a lead hit confirms resisted, no hit-stop", last == &"resisted")
  _check("M3 a copal ball is weak: confirms weak, exposes", last == &"weak" and m.is_exposed())
  _check("M4 a weak hit refunds 8 power", is_equal_approx(p.power.power, before + 8.0))
  _check("M4b a weak blow that kills refunds too", is_equal_approx(p.power.power, before + 8.0))
  _check("M5 a whole shell refunds once", is_equal_approx(p.power.power, before + 8.0))
  _check("M6 a hit while exposed is doubled", is_equal_approx(lost, dmg * 2.0))
  _check("M7 a shard hit is weak (obsidian)", last_shard == &"weak")
  _check("M8 killed: died fires once, it hides and its collider is off", deaths == 1 and not m.visible)
  _check("M9 pellets after the killing one return none, no second death or refund", deaths == 1 and refunds == 1)
  _check("M10 a guard hit by a copal round takes it as a bullet", guard_kind == &"bullet")
  _check("M11 a hit pushes it, a shell further than a ball", shell_push > ball_push)
  _check("M12 save and load keep health and dead", restored)
  _check("M13 the player walks through it unblocked", passed)
  ```

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.** `_confirm`: `&"weak"` holds `Monster.WEAK_HITSTOP` and plays `Sfx` stand-in `ting` at pitch 1.5; `&"resisted"` has no hit-stop and plays `thud` at pitch 0.6, `-14 dB`. The shell's own `_confirm(&"hit" ...)` picks the strongest result its pellets returned.

- [ ] **Step 4: Run** `monster_test`, `revolver_test`, `gunfight_test`, `shard_fx_test`. Expected: all pass.

- [ ] **Step 5: Commit** `feat(hunt): monsters with weaknesses, and a right answer pays you back`.

### Task 7: Round types in the cylinder

**Files:**
- Modify: `scripts/Combat/Revolver.gd` (lines 464, 510, 514 and new input), `scripts/Interaction/Inventory.gd` (`save_state`, `load_state`), `scripts/UI/AmmoReadout.gd` (`snapshot`)
- Test: `tests/monster_test.gd`, `tests/ammo_ui_test.gd`

**Interfaces:**
- Consumes: `Rounds.info`, `player.loadout` from Task 8 is **not** needed yet. This task reads `var packed_rounds: Array[StringName] = [&"lead"]` on the Revolver, which Task 8 sets.
- Produces, `Revolver`: `var cylinder_round: StringName = &"lead"` (in `save_state`, defaulting to lead on load), `func switch_round() -> bool`, `func stock_id() -> StringName`, signal `round_switched(id: StringName)`. Input action `switch_round` (`KEY_T`).
- Rule: switching returns unfired rounds to their stock, empties the cylinder, sets the next packed type with a stock above zero, and starts a reload. Firing mid-reload still snaps the gate and fires what's in.

- [ ] **Step 1: Write the failing checks** in `monster_test`:
  ```gdscript
  _check("R1 T switches to copal and starts a reload", g.cylinder_round == &"copal" and g.is_reloading())
  _check("R2 unfired lead goes back to its pouch", inv.ammo[&"rounds"] == rounds_before + 4)
  _check("R3 a reload takes from the round's own pouch", inv.ammo[&"copal_rounds"] == 6)
  _check("R4 an empty next pouch refuses: dry click, nothing moves", not switched and g.cylinder_round == &"lead")
  _check("R5 switching mid-reload keeps what is loaded counted", total_before == total_after)
  _check("R6 with only lead packed, T does nothing", not switched_alone)
  _check("R7 a save with no cylinder_round loads as lead", g.cylinder_round == &"lead")
  _check("R8 a save with no new stocks loads them empty", inv.ammo.get(&"copal_rounds", 0) == 0)
  _check("R9 stocks of every kind survive save and load", inv.ammo[&"copal_rounds"] == 6)
  ```
  Add to `ammo_ui_test`: `state.get("round") == &"lead"`, and after a switch `state.get("reserve") == copal count`.

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.** `Inventory.save_state` writes every key of `ammo`. `load_state` keeps `rounds` and `shells` defaults, adds the rest. `AmmoReadout.snapshot` gains `round` and reads `stock_id()` for the cylinder. `ToolItem`'s pickup of `rounds` and `shells` is unchanged.

- [ ] **Step 4: Run** `monster_test`, `ammo_ui_test`, `revolver_test`, and the save suites (`save_test`, `save_coverage_test`). Expected: all pass.

- [ ] **Step 5: Commit** `feat(hunt): round types: switching the cylinder is a reload`.

### Task 8: The loadout, the kit table and prep items

**Files:**
- Create: `scripts/Hunt/Loadout.gd`, `scripts/Hunt/PrepItems.gd`, `scripts/Hunt/KitTable.gd`, `scripts/Hunt/KitPiece.gd`
- Create: `tests/loadout_test.gd`, `tests/loadout_test.tscn`
- Modify: `scripts/PlayerController.gd` (`loadout` child, saved)

**Interfaces:**
- Consumes: `Rounds`, `player.statuses`, `revolver.packed_rounds`.
- Produces, `PrepItems.gd`: `const TABLE := {&"egg": {"cures": &"evil_eye", "use_time": 0.8, "carry": 2}}`, `static func info(id) -> Dictionary`.
- Produces, `Loadout.gd` (Node, player's `loadout`):
  ```gdscript
  const MAX_ROUND_TYPES := 2     # shells always come along
  const MAX_ITEM_KINDS := 2
  const CARRY := {&"rounds": 24, &"copal_rounds": 12, &"shells": 6}
  signal item_used(id: StringName)
  signal changed
  var rounds: Array[StringName] = [&"lead"]
  var items: Array[StringName] = []
  var item_counts := {}
  var locked := false
  var owned := {&"rounds": 96, &"copal_rounds": 24, &"shells": 18, &"egg": 6}
  func pack_round(id: StringName) -> bool    # false when locked or full
  func unpack_round(id: StringName) -> bool  # never the last one
  func pack_item(id: StringName) -> bool
  func unpack_item(id: StringName) -> bool
  func restock() -> void        # fill to CARRY and item carry from owned; sets packed_rounds
  func lock() -> void
  func unlock() -> void
  func use_item(index := 0) -> bool
  func is_using() -> bool
  func save_state() -> Dictionary
  func load_state(state: Dictionary) -> void
  ```
  `use_item` takes `use_time` during which the hand can't fire or cast (a held `_using` flag that `Revolver.ready_to_fire` and `Caster.can_cast` read). At the end it clears the cure's status and spends one. Input action `use_item` (`KEY_V`). No new pose: list "egg limpia, left hand" in `docs/superpowers/refs/hunt/poses_needed.md`.
- Produces, `KitPiece.gd` (StaticBody3D): `@export var piece: StringName`, `@export var piece_type: StringName` (`&"round"` or `&"item"`), `var verb := "Pack"`, `func frob(player: Node) -> void` (toggle; when packed it slides 0.25 m to the table's near edge). Stand-in meshes from `Props.mesh_box`.
- Produces, `KitTable.gd` (Node3D): `static func build(parent: Node, at: Transform3D) -> Node3D` lays out one piece for lead, copal and the egg.

- [ ] **Step 1: Write the failing checks** with the real player:
  ```gdscript
  _check("L1 frobbing a piece packs it and moves it", lo.rounds.has(&"copal") and moved)
  _check("L2 a third round type is refused", not lo.pack_round(&"third"))
  _check("L3 the last round type can't be unpacked", not lo.unpack_round(&"lead"))
  _check("L4 locked: nothing packs", not lo.pack_item(&"egg"))
  _check("L5 restock fills pouches from what you own, and spends it", inv.ammo[&"copal_rounds"] == 12 and lo.owned[&"copal_rounds"] == 12)
  _check("L6 restock tops up, never over carry", inv.ammo[&"rounds"] == 24)
  _check("L7 restock can't make what you don't own", inv.ammo[&"copal_rounds"] == left_owned)
  _check("L8 the egg clears the evil eye after 0.8 s and spends one", not p.statuses.has(&"evil_eye") and lo.item_counts[&"egg"] == 1)
  _check("L9 no firing or casting while using one", not g.ready_to_fire() and not p.caster.can_cast(&"shard"))
  _check("L10 no eggs: V does nothing", not lo.is_using())
  _check("L11 packed_rounds follows the pack", g.packed_rounds == [&"lead", &"copal"])
  _check("L12 save and load keep the pack, counts, owned and lock", restored)
  _check("L13 the default loadout is lead, unlocked, and no pouch changes unless restocked", defaults)
  ```

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run** `loadout_test`, `monster_test`, `revolver_test`, `save_test`, `save_coverage_test`. Expected: all pass.

- [ ] **Step 5: Commit** `feat(hunt): a loadout packed at a kit table, and the egg`.

### Task 9: The safe place and dying back to the table

**Files:**
- Create: `scripts/Hunt/SafePlace.gd`, `tests/safe_place_test.gd`, `tests/safe_place_test.tscn`

**Interfaces:**
- Consumes: `Loadout`, `SaveGame.request_save(kind, named, slot)`, `SaveGame.gather()`, `SaveGame.apply(body)`.
- Produces, `SafePlace.gd` (Area3D): `signal left`, `signal returned`, `@export var size: Vector3`, `static func build(parent: Node, center: Vector3, size: Vector3) -> Area3D`. On the player leaving: `loadout.restock()`, `loadout.lock()`, `SaveGame.request_save(&"auto")`. On the player returning: `health = max_health` (lost shields back), `loadout.unlock()`, `loadout.restock()`.

- [ ] **Step 1: Write the failing checks.**
  ```gdscript
  _check("S1 leaving locks the pack and restocks", lo.locked and inv.ammo[&"rounds"] == 24)
  _check("S2 leaving asks for an auto save", saved_kind == &"auto")
  _check("S3 the saved game holds the pack and the pouches", body_has_loadout)
  _check("S4 applying that save restores what was used in the run", inv.ammo[&"copal_rounds"] == 12 and lo.item_counts[&"egg"] == 2)
  _check("S5 back inside: lost shields return and it unlocks", p.health == p.max_health and not lo.locked)
  _check("S6 walking back restocks from what's left owned", lo.owned[&"copal_rounds"] < owned_before)
  _check("S7 a monster killed stays dead after walking back", m.dead)
  _check("S8 in a run, used stays used", inv.ammo[&"copal_rounds"] == after_shots)
  ```

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.** Dying needs nothing new if the death page's load takes the latest save; confirm that by reading `show_death_page` and `SaveGame.quickload`. If it doesn't offer the latest auto save, add that and check it in S4's neighbour `S9`.

- [ ] **Step 4: Run** `safe_place_test`, `save_test`, `save_coverage_test`. Expected: all pass.

- [ ] **Step 5: Commit** `feat(hunt): a safe place: packing locks on leaving, and death returns you to it`.

---

## Part two: the floating eye

### Task 10: The hunt gym

**Files:**
- Create: `maps/hunt_gym.gd`, `maps/hunt_gym.tscn`, `data/jobs/hunt_gym.job`, `docs/superpowers/refs/hunt/words_needed.md`
- Create: `tests/hunt_gym_test.gd`, `tests/hunt_gym_test.tscn`

**Interfaces:**
- Consumes: `SafePlace.build`, `KitTable.build`, `Props.block`, `Props.readable(parent, at, look, slot)`, `CityState.job.reset(with_book)`, `JobBook.parse`.
- Produces: map with a lit **kit room** (safe place, table, clue readable, door), a dark **yard** past it (30 × 30 m, pillars, a low wall, a beam to slide under, a ledge), `func spawn(kind: StringName, at: Vector3) -> Node3D`, `func wave(number: int) -> void`, F5 restart, F6 next wave. Patterned on `maps/combat_gym.gd`. The revolver is given at start.
- The clue: one readable, slot `eye_clue`, and pencil note `eye_weakness` in `hunt_gym.job`, both `<<...>>` with `intent:` lines saying what the words must tell the player: eyes come in packs, single rounds won't do it, copal and shot will, an egg takes the eye off you.

- [ ] **Step 1: Write the failing checks.**
  ```gdscript
  _check("H1 the map loads with no script errors and the player in the kit room", in_room)
  _check("H2 the player reaches the yard on foot from spawn", reached)
  _check("H3 reading the clue adds the pencil note", job.notes.has("eye_weakness"))
  _check("H4 walking out locks and restocks", lo.locked)
  _check("H5 the slide beam is passable only by sliding or crouching", beam_ok)
  _check("H6 the job file has no parse errors", book_ok)
  ```
  H2 walks from spawn with real input; never teleports (`player-capsule-is-a-metre-wide`): gaps ≥ 1.1 m.

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.** Greybox and lit only. Stand-in materials. Add `words_needed.md` listing every stand-in word so far (pieces, prompts, clue).

- [ ] **Step 4: Run.** Expected: PASS.

- [ ] **Step 5: Commit** `feat(hunt): the hunt gym: a kit room, a clue, a yard`.

### Task 11: The floating eye, plain

**Files:**
- Create: `scripts/Monsters/FloatingEye.gd`, `tests/floating_eye_test.gd`, `tests/floating_eye_test.tscn`
- Modify: `scripts/Magic/PowerPool.gd` use (`refill_scale` from the player), `scripts/Combat/Revolver.gd` (`_stray`), `scripts/PlayerUtils/CameraJuice.gd`, `maps/hunt_gym.gd` (`wave`)

**Interfaces:**
- Consumes: `Monster`, `player.statuses`, `dodged_within`.
- Produces, `FloatingEye.gd` (extends `Monster`, `kind = &"floating_eye"`, seeded `_rng`):
  ```gdscript
  enum State { DRIFT, CIRCLE, TELL, SWOOP, BOUNCE }
  const NOTICE := 18.0
  const CIRCLE_RADIUS := Vector2(6.0, 9.0)
  const CIRCLE_HEIGHT := Vector2(1.6, 3.0)
  const TELL_TIME := 0.5
  const SWOOP_SPEED := 11.0
  const BITE := 12.0
  const GAZE_RANGE := 12.0
  const GAZE_TO_CURSE := 2.0     # seconds of being looked at, across the pack
  const EVIL_EYE_TIME := 8.0
  const MOST_SWOOPING := 2       # at once, across the pack
  var state: State
  ```
  It flies with `move_and_slide`, steering around geometry by feelers; no navmesh. SWOOP aims at where the player is at the end of TELL (it can be dodged, and it goes through). BITE lands by `player.take_damage(BITE, self)` on contact within 0.6 m. After a swoop or a wall it BOUNCEs back up, staggering, which is the opening to hit it.
- Evil eye on the player: `player.power.refill_scale = 0.5` while it lasts; `Revolver._stray` adds `EVIL_EYE_STRAY := 1.5°` even aimed; `CameraJuice.set_unsteady(amount: float)` adds a slow sway of up to 0.8°, its clock pinned by tests. All three end when the status ends.
- Smoked: copal hits apply `&"smoked"` for 4 s: 0.6 speed, no gaze, no swoop.
- Stand-in body: `SphereMesh` r 0.28 with a darker disc for the pupil, until Task 13. The hit shape is a sphere of r 0.3.
- Sounds: stand-ins from the existing library via `Sfx`, listed in `docs/superpowers/refs/hunt/sounds_needed.md` for the user.
- `wave(1)`: 3 eyes, `wave(2)`: 5, `wave(3)`: 6 and one guard.

- [ ] **Step 1: Write the failing checks.**
  ```gdscript
  _check("E1 it notices within 18 m with a clear line, not through a wall", noticed and not walled)
  _check("E2 it circles at its radius and height", in_band)
  _check("E3 it tells for 0.5 s before a swoop", is_equal_approx(tell, 0.5))
  _check("E4 standing still, the swoop bites for 12", is_equal_approx(lost, 12.0))
  _check("E5 a dodge in the tell makes it miss, and it bounces", not_bitten and e.state == e.State.BOUNCE)
  _check("E6 at most 2 of 5 swoop at once", most <= 2)
  _check("E7 2 s of gaze puts the evil eye on you", p.statuses.has(&"evil_eye"))
  _check("E8 out of its line, no gaze", not gazed)
  _check("E9 evil eye: refill halved, aim strays, view unsteady; all end with it", effects_on and effects_off)
  _check("E10 the egg takes it off", cured)
  _check("E11 smoked: slower, no gaze, no swoop", smoked_ok)
  _check("E12 3 lead balls or 1 copal ball kill, as designed", lead_hits == 3 and copal_hits == 1)
  _check("E13 a shell within 6 m kills", shell_kill)
  _check("E14 the player dead: eyes stop attacking, no errors", calm)
  _check("E15 it never leaves the yard or sticks in geometry over 60 s", stayed)
  _check("E16 the same seed flies the same path", same)
  ```

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.** E12 follows from the Task 5 numbers; if eyes then feel wrong to hit, tune in the verdict task, not here.

- [ ] **Step 4: Run** `floating_eye_test`, `monster_test`, `hunt_gym_test`, `revolver_test`, `feel_test`. Expected: all pass.

- [ ] **Step 5: Commit** `feat(hunt): the floating eye: packs that swoop, and the evil eye`.

### Task 12: The combat UI's first pieces

**Files:**
- Create: `scripts/UI/HuntReadout.gd`, `scripts/UI/evil_eye_view.gdshader`
- Modify: `scripts/UI/StealthHUD.gd` (lines 6, 95, 698–703, 851–852, 973–974, `_crosshair.contact`)
- Delete: `scripts/UI/AmmoReadout.gd` (and its `.uid`)
- Test: `tests/ammo_ui_test.gd` (renamed checks keep the same meaning)

**Interfaces:**
- Consumes: `Rounds.info(...)["colour"]`, `Loadout.item_counts`, `player.statuses`.
- Produces, `HuntReadout.gd` (Control), with the old `snapshot()` keys plus `"round"`, `"chambers"` (six colours, spent ones black), `"items"`, `"evil_eye"`. Drawn with the talk box's paint language (reuse `talk_paint.gdshader`'s brush edge, the HUD's ink and brass): a six-chamber cylinder rosette whose chambers are coloured by round, a shell mark on the hammer's side, small painted marks for packed items. The reserve is a small number in the HUD's font.
- Crosshair: `contact(&"weak")` is a brass burst; `contact(&"resisted")` is a short grey stroke.
- `evil_eye_view.gdshader`: a painted, eyelid-shaped darkening at the frame's edge, on a `ColorRect` under `_play`, faded in by the status. No new colours beyond the VFX colour rule (`vfx-aesthetic-and-pipeline`).

- [ ] **Step 1: Write the failing checks.**
  ```gdscript
  _check("U1 six chambers shown, coloured by round", snap["chambers"].size() == 6)
  _check("U2 firing empties a chamber", snap["loaded"] == 5)
  _check("U3 copal chambers take copal's colour", snap["chambers"][0] == Rounds.info(&"copal")["colour"])
  _check("U4 a packed egg shows its count", snap["items"][&"egg"] == 2)
  _check("U5 the evil eye view shows only under the status", shown_with and not shown_without)
  _check("U6 weak and resisted marks differ", mark_weak != mark_resisted)
  _check("U7 holstering hides the readout", snap.is_empty())
  ```

- [ ] **Step 2: Run.** Expected: FAIL.

- [ ] **Step 3: Implement.**

- [ ] **Step 4: Run** `ammo_ui_test`, plus any suite naming `_ammo`. Expected: all pass.

- [ ] **Step 5: See it in the real game.** Run `maps/hunt_gym.tscn` windowed at 1152×648 with a capture script, save stills to the scratchpad of: full cylinder, mixed reload, evil eye on, weak mark, resisted mark. Inspect each for legibility against both the lit room and the dark yard. Fix what fails (`never-call-visual-defects-harmless`).

- [ ] **Step 6: Commit** `feat(hunt): the first painted combat marks, on the cylinder's chambers`.

### Task 13: The eye's model, with the user

**Files:**
- Create: `tools/monsters/build_eye.py`, `assets/monsters/floating_eye.glb`, `docs/superpowers/refs/hunt/eye_silhouettes.png`
- Modify: `scripts/Monsters/FloatingEye.gd` (`const MODEL`, falls back to the stand-in)

This task is supervised and has no agent-only path (`models-one-by-one-supervised`). Executors stop for the user at each marked step.

- [ ] **Step 1: Propose silhouettes.** Render four 2D silhouettes on one sheet: Terraria's Demon Eye as the idea, carried by the aesthetic checklist (Mignola and Deadlock chunky shapes, a physical thing with a history as *mal de ojo*: lids, a torn optic trail, maybe the milagro eye charms it came from). **Stop: the user picks.**
- [ ] **Step 2: Build the picked one** with `tools/monsters/build_eye.py` in Blender: solid closed meshes, no planar cuts (spec, "How monsters must look and feel"), under 1,500 tris. Separate lid and iris parts so the tell can dilate and the lids can narrow. A trail of hanging tissue is bones or a shader sway, not a hidden flat quad.
- [ ] **Step 3: Run the hole scan and close-up renders of every joint** (`inspect-geometry-closely`). Fix every fault found.
- [ ] **Step 4: Put it in the gym** with the tell's dilation, a bite snap and the bounce's roll. **Stop: the user reviews it in the game.** Iterate until approved.
- [ ] **Step 5: Run** `floating_eye_test`. Expected: PASS, with the hit shape unchanged.
- [ ] **Step 6: Commit** `feat(eye): the floating eye's model`.

### Task 14: The first playable loop and the user's verdict

**Files:**
- Create: `tests/hunt_loop_test.gd`, `tests/hunt_loop_test.tscn`, `docs/systems/hunts.md`
- Modify: `docs/systems/README.md`

- [ ] **Step 1: Write the check** with real input from spawn, seeded:
  ```gdscript
  _check("LP1 read the clue, pack copal and the egg, walk out, wave 1 clears, and walk back", finished)
  _check("LP2 that same bot with only lead packed spends more than twice the rounds", lead_rounds > copal_rounds * 2.0)
  _check("LP3 dying in the yard and applying the auto save puts you in the kit room with the pack", restored)
  ```
  LP2 is the spec's anti-goal as a number: plain lead must be a much worse answer.

- [ ] **Step 2: Run.** Expected: FAIL until the bot exists, then PASS. If LP2 fails, tune `Bestiary` numbers, not the bot.

- [ ] **Step 3: Write `docs/systems/hunts.md`** in the manner of `docs/systems/audio.md`: the tables, how to add a kind, the suites.

- [ ] **Step 4: Run every suite** the branch touches (`fight_move_test`, `bestiary_test`, `monster_test`, `loadout_test`, `safe_place_test`, `hunt_gym_test`, `floating_eye_test`, `hunt_loop_test`, `ammo_ui_test`, `revolver_test`, `gunfight_test`, `combat_test`, `feel_test`, `traversal_test`, `freerun_test`, `movement_gym_test`, the save suites), then the whole `tests/` list, since the seeded-stream rule says a change to draws can bite anywhere. Report any failure with its output, and compare against `main` before calling it new.

- [ ] **Step 5: Commit** `test(hunt): the whole loop, clue to the walk back`.

- [ ] **Step 6: Stop for the user's verdict.** Give the command to run `maps/hunt_gym.tscn`, the keys (Alt dodge, Ctrl at a sprint slide, T switch round, V egg, F5 restart, F6 next wave), and ask about **tempo, weight, stakes**. Have these knobs ready, with numbers from the baseline: gun-drawn walk speed (`walk_speed` is 6.5 m/s today and is a likely weight lever), `ready_one_hand`, swoop speed and tell, refund size, shield `recover_delay`. Do not start the next plan before this verdict.
