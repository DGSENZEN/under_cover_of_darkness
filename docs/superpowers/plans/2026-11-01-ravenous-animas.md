# Ravenous Ánimas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A second hunt enemy, in three withered forms, that latches on and drains your willpower and life; the answers that knock it off, including a new crowd spell and a copal line item; all playable alone in a new gym.

**Architecture:** `Anima.gd` extends `Monster.gd` by path, as `FloatingEye.gd` does, with its forms as data in `Bestiary`. A `LifeLeech.gd` node on the player owns who is on you and what that costs, as `EvilEyeCurse.gd` owns the curse. The fight is built and played on stand-in bodies first; the real models replace them behind `AnimaBody.gd`, one at a time, each reviewed by the user.

**Tech Stack:** Godot 4.5.1, GDScript, spatial and canvas_item shaders; Blender headless for models.

**Spec:** `docs/superpowers/specs/2026-11-01-ravenous-animas-design.md`. Parent: `docs/superpowers/specs/2026-11-01-hunt-combat-design.md`.

## Global Constraints

- Work on branch `hunt-combat`, worktree `.claude/worktrees/hunt-combat`. Not merged or pushed without the user's word.
- Failing check first, always (`failing-checks-kept`). Log lines `SCRIPT ERROR` and `SHADER ERROR` count as failures: check for them on every run.
- Godot: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`. A suite: `$G --headless --fixed-fps 60 --path . res://tests/<name>.tscn`. Stills need a window: `$G --path . --resolution 1152x648 res://tests/<diag>.tscn -- --out=<scratchpad>/stills`.
- Monsters extend by path, no `class_name` (fresh headless checkouts can't resolve it). `take_hit(damage, attacker, kind, point, direction) -> StringName` stays the contract.
- Any new `RefCounted` member read off the player (`juice`) is untyped or `RefCounted`, never `Node`.
- The Metro's `scripts/Visual/Animas.gd` does not change.
- No odd sawed-off topology: every model part is a closed solid, and the build script refuses an open edge, as `tools/monsters/build_eye.py` does.
- Painted look: custom `light()` hard bands, `SPECULAR = 0`, ink lines, the world's brush sheet, muted with one sick accent (`eye_paint.gdshaderinc`). No downloaded VFX. Effects in the mesh-and-shader language of `MeshVfx` and `vfx_obsidian.gdshader`. No tesla arcs.
- Judge looks in the game with stills, not Blender renders. Inspect every joint close up before showing a model.
- Never move anything in `_process` without switching physics interpolation off for it (`judder-physics-interpolation`).
- The user writes all words: ids and prompts are stand-ins, listed in `docs/superpowers/refs/hunt/words_needed.md`. Poses go in `poses_needed.md`, sounds in `sounds_needed.md`.
- Commit by explicit file list. Stray `.uid` files that aren't yours and `docs/superpowers/refs/underground/...` are not ours. A `.uid` for a file you created is yours.
- Every commit ends: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Numbers from the spec

| | Hands | Face | Torso |
|---|---|---|---|
| Health | 40 | 70 | 130 |
| Power drained /s | 5 | 8 | 12 |
| Life drained /s | 1.5 | 2.5 | 4 |
| Whips to throw off (`grip`) | 1 | 1 | 2 |

My starting values, for the plan to pin: speed 6.5 / 4.5 / 2.2 m/s; tell 0.3 / 0.45 / 0.7 s; leap reach 3 / 4 / 6 m; leap speed 11 / 9 / 10 m/s; hit radius 0.3 / 0.4 / 0.55 m; held height 0.25 (on the floor) / 1.3 (floats) / 0.35 (on the floor).

Scales on `&"anima"`: copal 1.0 (weak); lead 0.15, shot 0.5 (resist); everything else 1.0. Most on you: 3. Pace on you: ×0.8, ×0.65, ×0.5. Thrown off: stunned and exposed 1.5 s.

## Review Focus

1. You die with them on you: every latch ends, the drain stops, your view comes back on restart, no errors. (Pinned in Task 2: A16.)
2. An ánima leaves play while on you, by death, a free or a map change: the leech forgets it and the drain stops. (Task 2: A17.)
3. Walking back into the kit room with one on you: it must not restock you or lift the drain for free. (Task 2: A18.)
4. A drained player with no power: the Ward and burst refuse, the whip still works, life drains double. (Task 3: W7, with A12.)
5. Mixed with the curse: speed and refill costs multiply, both screen effects show together and neither blanks the other (two canvas shaders each reading the screen). (Task 5: S6 and a still.)

---

### Task 1: The kind, its forms, and a monster that comes at you

**Files:**
- Modify: `scripts/Monsters/Bestiary.gd`, `scripts/Monsters/Monster.gd`
- Create: `scripts/Monsters/Anima.gd`, `scripts/Monsters/AnimaBody.gd`
- Test: `tests/anima_test.gd`, `tests/anima_test.tscn` (fixture as `tests/floating_eye_test.gd`: a floor, the player invulnerable, `Props.give_revolver(p, 200, 40)`, with the same `_until`, `_frames`, `_press`, `_check` helpers)

**Interfaces:**
- Produces: `Bestiary.TABLE[&"anima"]` with `"forms": {&"hands": {...}, &"face": {...}, &"torso": {...}}`; `Bestiary.form(kind, form) -> Dictionary`.
- Produces: `Monster._is_opening_to(source: StringName) -> bool`, default `return _is_opening()`, called by `take_hit` in place of `_is_opening()`.
- Produces in `Anima.gd`: `@export var form: StringName`; `enum State {RISE, RUSH, CIRCLE, TELL, LEAP, MISSED, ON, THROWN}`; `var state`; `var body` (AnimaBody); `func hit_radius()`; `var whip_reach := 1.6`.
- Produces in `AnimaBody.gd`: `form`, `tick(delta, doing: StringName, you: Node3D, moving: Vector3, fed: float, exposed: bool, smoked: bool)`, `struck(point, direction, result)`, `burst(context, at, push)`. Stand-in shapes for now: dark capsules, plainly unfinished.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("A1 three forms, their health", _health(&"hands") == 40.0 and _health(&"face") == 70.0 and _health(&"torso") == 130.0)
_check("A2 lead passes through: resisted, little harm", _hit(&"face", &"lead") == &"resisted" and is_equal_approx(_lost, 50.0 * 0.15))
_check("A3 copal is weak, exposes, pays power back", _hit(&"face", &"copal") == &"weak" and e.is_exposed() and refunded)
_check("A4 a shell is a poor answer", _hit_shot(&"torso") == &"resisted")
_check("A5 from far off it rushes you", closer_after_one_second)
_check("A5b hands are faster than a torso", hands_covered > torso_covered * 2.0)
_check("A6 close enough it tells, then leaps", saw_tell and saw_leap)
_check("A7 in its tell, a copal hit breaks it: weak, triple", state_after == STATE.THROWN and lost == 50.0 * 3.0)
_check("A7b in its tell, lead still does nothing to it", state_after_lead == STATE.TELL and result_lead == &"resisted")
_check("A8 hands and torso keep to the floor, the face floats", abs(hands.y - 0.25) < 0.2 and abs(face.y - 1.3) < 0.3)
```

- [ ] **Step 2: Run it. Expected: FAIL (parse error, no `Anima.gd`).**

- [ ] **Step 3: Implement.** Row and helper in `Bestiary.gd`, `_is_opening_to` in `Monster.gd`, the brain in `Anima.gd` with the forms' values from the table above. Set `health` from the form before `super._ready()`. Crawlers use gravity and `move_and_slide`; the face holds its height. Rush along a `NavigationAgent3D` when a map exists, straight at you when none does. `_is_opening_to` returns `state == State.TELL and source != &"lead"`. A hit in the tell goes to THROWN (Task 2's `throw_off` fills this out; for now, state and push).

- [ ] **Step 4: Run it. Expected: all PASS, no errors. Also run `floating_eye_test` and `bestiary_test`: PASS.**

- [ ] **Step 5: Commit.** `feat(hunt): the ravenous ánima, its forms, and its rush`

### Task 2: The leech on the player

**Files:**
- Create: `scripts/Monsters/LifeLeech.gd`
- Modify: `scripts/PlayerController.gd` (`curse`-style setup; `leech`; `_feel_statuses`; speed; `drain_life`; recover), `scripts/Monsters/Anima.gd`
- Test: `tests/anima_test.gd`

**Interfaces:**
- Produces in `LifeLeech.gd`: `signal latched(who)`, `signal released(who)`, `const MOST := 3`, `func latch(who: Node3D) -> bool`, `func release(who: Node3D)`, `func on_me() -> Array`, `func count() -> int`, `func speed() -> float`, `func free_all()`, `func tear_free()`, `func slot_of(who) -> int`.
- Produces on the player: `var leech: Node`, `func drain_life(amount: float)`: lowers `health`, respects `invulnerable` and `is_dead`, sets `_hurt_at`, dies at 0, and does **not** play the hurt reaction, freeze or flash. (Per-tick `take_damage` would stutter.)
- Produces in `Anima.gd`: `func drain_power() -> float`, `func drain_life() -> float`, `var fed := 0.0`, `func throw_off(from: Vector3)`, `func let_go()`.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("A9 a leap that lands puts it on you", p.leech.count() == 1 and e.state == STATE.ON)
_check("A10 a dodge at the right moment makes it miss", missed.state == STATE.MISSED and p.leech.count() == 0)
_check("A11 it drains power (%.1f /s) and life (%.1f /s)" % [power_rate, life_rate], is_equal_approx_to(power_rate, 8.0, 0.5) and is_equal_approx_to(life_rate, 2.5, 0.3))
_check("A11b your shield doesn't refill and power doesn't either", p.power.refill_scale == 0.0 and no_recover)
_check("A12 no power left, life goes twice as fast", is_equal_approx_to(life_rate_empty, 5.0, 0.4))
_check("A13 pace by how many: 0.8, 0.65, 0.5", p.leech.speed() == pace_expected)
_check("A14 no more than three; the rest wait, circling", p.leech.count() == 3 and fourth.state == STATE.CIRCLE)
_check("A15 what it drank, half comes back when it dies", is_equal_approx_to(power_after - power_before, drank * 0.5, 0.5))
_check("A15b with the curse too, the costs multiply", is_equal_approx_to(speed_both, p.curse.speed() * p.leech.speed(), 0.001))
_check("A16 dead, all let go and it stops", p.leech.count() == 0 and health_steady)
_check("A17 freed while on you, the leech forgets it", p.leech.count() == 0 and not p.leech.on_me().has(gone))
_check("A18 with one on you the kit room won't restock you", restocked == false)
```

- [ ] **Step 2: Run it. Expected: FAIL.**

- [ ] **Step 3: Implement.** Three slots in camera yaw space, front-left `(-0.55, -0.2, -0.6)`, front-right `(0.55, -0.2, -0.6)`, low `(0.0, -0.55, -0.7)`, so whatever is on you can be seen and shot and is off the crosshair. `Anima` in `ON` moves to its slot each physics tick, with its collision shape left on so shots find it. `_feel_statuses` sets `power.refill_scale = curse.magic_regen() * (0.0 if leech.count() > 0 else 1.0)`. Multiply `target_speed` by `leech.speed()` beside `curse.speed()`. Power comes off directly, not through `pay()`, so a cast isn't refused or delayed by the drain's own bookkeeping. Add `PlayerCombat.is_dodging() -> bool` (`phase == Phase.DODGE`). `SafePlace` already refuses when hunted: make a latched ánima count, and check it in A18. Smoked ánimas can't latch and drain at half (`statuses.has(&"smoked")`).

- [ ] **Step 4: Run. Expected: PASS, plus `safe_place_test`, `fight_move_test`, `floating_eye_test`.**

- [ ] **Step 5: Commit.** `feat(hunt): ánimas latch on and drain your willpower and life`

### Task 3: Getting them off

**Files:**
- Modify: `scripts/Combat/Revolver.gd` (`try_whip`; `_show_hit`), `scripts/Visual/GunFx.gd` (`impact` read `&"through"`), `scripts/Monsters/Anima.gd`, `scripts/Magic/Caster.gd` (Ward, Blink)
- Test: `tests/anima_test.gd`

**Interfaces:**
- Consumes: `leech.free_all()`, `leech.tear_free()`, `Anima.throw_off(from)`, `Anima.let_go()`.
- Produces: `var grip_left: int` on `Anima`, from the form's `grip`.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("W1 a whip throws off the one you aim at, only that one", face_a.state == STATE.THROWN and face_b.state == STATE.ON)
_check("W1b thrown clear, stunned and exposed for 1.5 s", face_a.global_position.distance_to(p.global_position) > 1.5 and face_a.is_exposed())
_check("W2 a torso needs two whips", torso.state == STATE.ON and torso.grip_left == 1)
_check("W2b and the second throws it off", torso.state == STATE.THROWN)
_check("W3 a copal round throws off the one it hits, and pays you", a.state == STATE.THROWN and b.state == STATE.ON and power_up)
_check("W3b its cloud doesn't: the other holds on, draining at half", b.state == STATE.ON and is_equal_approx_to(rate_in_cloud, full_rate * 0.5, 0.5))
_check("W3c nothing can latch inside the cloud", p.leech.count() == 0 and smoked.state != STATE.ON)
_check("W4 lead doesn't free you; seen to pass through", a.state == STATE.ON and read == &"through")
_check("W4b nor a shell, nor a shard, though both hurt", a.state == STATE.ON and hurt)
_check("W5 the Ward throws off everything, and they can't enter it", p.leech.count() == 0 and not WardScript.covers(a.global_position))
_check("W6 a blink tears you free, but they aren't thrown or hurt", p.leech.count() == 0 and a.state == STATE.RUSH and not a.is_exposed())
_check("W7 no power: the Ward refuses, the whip still works", not warded and a.state == STATE.THROWN)
_check("W8 mantling with one on you: it holds on", p.leech.count() == 1)
```

- [ ] **Step 2: Run. Expected: FAIL.**

- [ ] **Step 3: Implement.** `try_whip` first looks through `leech.on_me()` for the one nearest your aim, whatever the cone; otherwise as it is. In `Anima`, a handler on `struck`: source `&"blow"` lowers `grip_left` and throws at 0; source `&"copal"` throws. `Caster._effect(&"ward")` calls `free_all()` after `WardScript.cast_on`. `_blink_to` calls `tear_free()`. Ánimas don't step into `WardScript.covers()`. `_show_hit` reads `&"through"` for a resisted lead hit on `anima` only, so the eye keeps `glance`: a data key `"lead_read"` on the Bestiary row. Spec's table is the authority for what frees you.

- [ ] **Step 4: Run. Expected: PASS, plus `round_read_test`, `revolver_test`, `spells` suites (search `tests/` for `Caster`).**

- [ ] **Step 5: Commit.** `feat(hunt): the whip, copal, the Ward and a blink get them off you`

### Task 4: The obsidian burst

**Files:**
- Create: `scripts/Magic/ObsidianBurst.gd`
- Modify: `scripts/Magic/Spells.gd`, `scripts/Magic/Caster.gd`, `scripts/Monsters/Bestiary.gd`, `scripts/Monsters/Monster.gd` (`PUSH`), `docs/superpowers/refs/hunt/words_needed.md`
- Test: `tests/burst_spell_test.gd`, `tests/burst_spell_test.tscn`

**Interfaces:**
- Produces: `Spells.TABLE[&"burst"] = {"school": &"obsidian", "tier": Tier.HAND, "cost": 40.0, "cast_time": 0.3, "movement": false}`; `Caster.KEYED` gains `&"burst"`, action `spell_4`, `KEY_4`.
- Produces: `ObsidianBurst.cast_on(player: CharacterBody3D) -> Node3D`; `const REACH := 5.5`, `const DAMAGE := 35.0`; groups `burst_ring`, `burst_splinters`.
- Produces: `Bestiary.source_of(&"burst", _) == &"obsidian"`; `Monster.PUSH[&"burst"] = 9.0`. Guards get `take_hit(DAMAGE, player, &"blast", ...)`, the kind they already know.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("B1 key 4, 40 power, 0.3 s", _cast_time_frames_ok and is_equal_approx(p.power.power, 60.0))
_check("B2 hurts everything within 5.5 m", near_a.health == full - 35.0 and near_b.health == full - 35.0)
_check("B2b nothing farther", far.health == full)
_check("B3 eyes take it at 1.5", eye_lost == 35.0 * 1.5)
_check("B4 a wall stops it", behind_wall.health == full)
_check("B5 all on you thrown off", p.leech.count() == 0 and a.state == STATE.THROWN and b.state == STATE.THROWN)
_check("B6 thrown outward, hard", a_moved_away > 1.5)
_check("B7 castable with one on you", cast_while_latched)
_check("B8 refused without the power, nothing spent", not cast_broke and p.power.power == 30.0)
_check("B9 a ring goes out, and splinters stay a while", ring_seen and splinters > 0 and gone_after_five_seconds)
_check("B10 a man takes it as a blast and lives to tell", guard_hurt)
```

- [ ] **Step 2: Run. Expected: FAIL.**

- [ ] **Step 3: Implement, three beats in `vfx_obsidian.gdshader`'s look.** Wind-up: the existing hand circle (`set_circle(&"obsidian", ...)`) already shows for a hand spell; add splinters drawn in through `cast_progress()`. Release: `TimeFx.hitstop(get_tree(), 0.05)`, a ring of about 28 black glass splinters flung out on the floor plane to `REACH` in 0.25 s. Aftermath: about 24 splinters left in the floor, fading over 4 s (`burst_splinters`). Line of sight: `direct_space_state.intersect_ray` on mask 1. Call `leech.free_all()` first, then damage. Stand-in name `burst` goes in `words_needed.md`.

- [ ] **Step 4: Run. Expected: PASS, plus suites touching `Caster` and `anima_test`.**

- [ ] **Step 5: Windowed stills of wind-up, release, aftermath (`tests/diag_anima_stills.gd`, new). Read them. Fix what's off before moving on.**

- [ ] **Step 6: Commit.** `feat(hunt): an obsidian burst for when you're crowded`

### Task 5: Being drained, on screen and in your ears

**Files:**
- Create: `scripts/UI/life_drain_view.gdshader`, `scripts/Monsters/LeechHands.gd`
- Modify: `scripts/UI/StealthHUD.gd`, `scripts/PlayerController.gd`, `docs/superpowers/refs/hunt/poses_needed.md`, `sounds_needed.md`
- Test: `tests/anima_test.gd`

**Interfaces:**
- Consumes: `leech.count()`, `on_me()`, `slot_of()`, signals.
- Produces: `StealthHUD.drain_state() -> Dictionary` `{"drain": float, "release": float, "threads": int}`; shader uniforms `drain`, `release`, `threads[3]` (`vec3`: screen x, y, weight); `LeechHands.shown(slot) -> bool`, `LeechHands.on_screen(slot) -> Vector2`.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("S1 nothing on you, nothing shows", hud.drain_state()["drain"] < 0.01 and not view_visible)
_check("S2 one on you: it starts, and deepens with each", d1 > 0.2 and d3 > d1 + 0.2)
_check("S3 hands in your view on its side", hands.shown(0) and hands.on_screen(0).x < 0.5)
_check("S3b never over the crosshair", hands.on_screen(0).distance_to(Vector2(0.5, 0.5)) > 0.28)
_check("S4 a thread toward each one holding you", hud.drain_state()["threads"] == 2)
_check("S5 thrown off: colour floods back at once", hud.drain_state()["release"] > 0.7 and d_after < d_before * 0.5)
_check("S5b and the hands are gone", not hands.shown(0))
_check("S6 with the curse on too, both show", hud.curse_view_shown() and view_visible)
```

- [ ] **Step 2: Run. Expected: FAIL.**

- [ ] **Step 3: Implement the view.** A `ColorRect` added to `_play` before `_curse_view`. A `BackBufferCopy` between it and `_curse_view`, since two canvas shaders each read the screen, with S6's still as proof. Colour is drawn out from the edges in toward cold grey, with no darkening over the middle 35% of the view. Threads of warm colour pulled along lines to `threads[i]`, painted with the brush sheet, per-pixel cost only while shown. `release` is 1..0 over 0.5 s and briefly lifts colour past normal. No flat vignette. Sound: a dull low-pass on the world while on you (as `Sfx.ward_muffle`), a rasping drink on the Souls bus (`monster_04`'s kin) per hold, a slowing heartbeat. List gaps in `sounds_needed.md`.

- [ ] **Step 4: Implement `LeechHands.gd`.** On the camera, `VIEWMODEL_LAYER`, `Z_CLIP` and `VIEW_FOV` as `HandSlot`'s egg is. A pair for each slot at the collar and shoulder, clutching: fingers tighten with a slow pulse and flex harder as it feeds. Stand-in meshes now. Entry in `poses_needed.md`.

- [ ] **Step 5: Run. Expected: PASS. Stills: one on, three on, thrown off, and curse with three on. Read them. The middle of the view must stay clear.**

- [ ] **Step 6: Commit.** `feat(hunt): what being drained looks and sounds like`

### Task 6: The copal line

**Files:**
- Create: `scripts/Hunt/CopalLine.gd`
- Modify: `scripts/Hunt/PrepItems.gd`, `scripts/Hunt/Loadout.gd`, `scripts/Hunt/KitTable.gd`, `scripts/Magic/Caster.gd`, `scripts/Monsters/Anima.gd`, `docs/superpowers/refs/hunt/words_needed.md`
- Test: `tests/copal_line_test.gd`, `.tscn`, `tests/loadout_test.gd`

**Interfaces:**
- Produces: `PrepItems.TABLE[&"copal_line"] = {"use_time": 0.6, "carry": 2, "colour": Color(1.0, 0.58, 0.12), "lays": true, "hold": &"cast"}`; egg's row gains `"hold": &"egg"`. Stand-in id.
- Produces: `CopalLine.lay(player) -> Node3D`, `const LENGTH := 5.0`, `const LASTS := 20.0`, group `copal_lines`; `static CopalLine.crossing(tree, from: Vector3, to: Vector3) -> Node3D`; `way_round(at: Vector3, wish: Vector3) -> Vector3`.
- Produces: action `use_item_2` on `KEY_B`, calling `use_item(1)`; `KitTable.build(parent, at, laid_out := LAID_OUT)`; `Loadout.owned[&"copal_line"] = 6`.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("L1 laid on the floor, square to your look, 5 m long, ahead of you", line_ok)
_check("L2 it takes 0.6 s and one from the pack", count_after == count_before - 1)
_check("L3 no ánima crosses it", none_past_line_in_ten_seconds)
_check("L4 in the open they go round it", reached_player_in_open)
_check("L4b in a doorway they can't", not reached_through_door)
_check("L5 laying it throws off any on you", p.leech.count() == 0 and a.state == STATE.THROWN)
_check("L6 eyes ignore it", eye_crossed)
_check("L7 gone after 20 s", get_tree().get_nodes_in_group(&"copal_lines").is_empty())
_check("L8 no eyes or curse needed to use it, unlike the egg", usable_when_nothing_on_you)
_check("L9 packed second, B uses it; V still the first", b_used_second and v_used_first)
_check("L10 the egg still works as it did", egg_hold == &"egg")
```

- [ ] **Step 2: Run. Expected: FAIL.**

- [ ] **Step 3: Implement.** Guard `Loadout` completion so only items with `"cures"` clear a status, only those with `"returns"` send back, and `_release`, ribbons and `egg_broke` run for the egg only. Caster's left hold uses the item's `"hold"`; for the line, a low stand-in frame (`poses_needed.md`). `can_offer()` is also true for a `"lays"` item with one on you, so the HUD offers it when it helps. Steering: an ánima whose step would cross a line slides along it toward its nearer end, plus a margin; walls then stall it in a doorway by themselves. Look: a strip of ash on the floor with low copal smoke along it, in `vfx_smoke.gdshader`, thin enough to see past, thinning in the last 2 s.

- [ ] **Step 4: Run. Expected: PASS, plus `floating_eye_test`, `loadout_test`, `hunt_loop_test`, `ammo_ui_test`. Still of the line.**

- [ ] **Step 5: Commit.** `feat(hunt): a line of copal they can't cross`

### Task 7: The ánima gym

**Files:**
- Create: `maps/anima_gym.gd`, `maps/anima_gym.tscn`, `data/jobs/anima_gym.job`
- Modify: `maps/hunt_gym.gd` (virtuals only), `docs/superpowers/refs/hunt/words_needed.md`, the suite that polices job words (search `tests/` for `hunt_gym.job`), `docs/systems/hunts.md`
- Test: `tests/anima_gym_test.gd`, `.tscn`

**Interfaces:**
- Produces in `hunt_gym.gd`, behaviour unchanged: `func _map_id() -> StringName`, `func _waves() -> Array`, `func _spawn_member(entry, index) -> Node3D`, `func _kit() -> Array`.
- `anima_gym.gd`: `extends "res://maps/hunt_gym.gd"`, waves `[{"hands": 5}, {"face": 2, "hands": 4}, {"torso": 1, "face": 2, "hands": 4}]`, kit `lead`, `copal`, `copal_line`.

- [ ] **Step 1: Write the failing checks**

```gdscript
_check("G1 it loads: a room, a table, a yard", loaded)
_check("G2 the table offers lead, copal and the line, no egg", kit == [&"lead", &"copal", &"copal_line"])
_check("G3 into the yard, five hands come from drains and grilles", awake == 5 and all_from_spawns)
_check("G4 cleared, the next: two faces and four hands", awake_2 == {&"face": 2, &"hands": 4})
_check("G5 the third: a torso, two faces, four hands", awake_3 == {&"torso": 1, &"face": 2, &"hands": 4})
_check("G6 F5 starts it again, F6 calls the next wave", restarted and next_called)
_check("G7 no eyes in it", no_eyes)
_check("G8 a bot with copal and the whip clears wave one", cleared)
_check("G9 a bot with only lead cannot, in the same time", not cleared_with_lead)
_check("G10 the hunt gym is as it was", hunt_gym_waves_same)
```

- [ ] **Step 2: Run. Expected: FAIL.**

- [ ] **Step 3: Implement.** Same kit room and dark yard as `hunt_gym`, with drains and low wall grilles as spawn points (a dark slot, greybox), a doorway and a pinch to lay a line in, room to be crowded. The clue's words are placeholders; list them in `words_needed.md`, the user writes them. Add the job to the words suite's allow-list as `hunt_gym.job` is. The `hunts.md` section covers ánimas, the leech, the burst, the line and how to play.

- [ ] **Step 4: Run. Expected: PASS, plus `hunt_gym_test`, `hunt_loop_test`. Stills: a wave coming, three on you.**

- [ ] **Step 5: Commit.** `feat(hunt): the ánima gym`

### Task 8: The user plays it on stand-ins

This is a gate. The fight's feel is judged before any modelling.

- [ ] **Step 1: Hand the user the play command, and say the bodies are stand-ins.**

```bash
/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot --path /Users/tinkertailorr/a-world-of-darkness-alpha/.claude/worktrees/hunt-combat --resolution 1152x648 res://maps/anima_gym.tscn
```

- [ ] **Step 2: Stop. Change what the user says, each change with a failing check first.** Numbers tune here. Don't start Task 9 until the user is happy with how being drained feels.

### Task 9: The silhouette sheet

This is a gate.

**Files:**
- Create: `tools/monsters/anima_silhouettes.py`, `docs/superpowers/refs/hunt/anima_silhouettes.png`

- [ ] **Step 1: Draw about three candidates for each of the three forms, as solid black shapes at fight distance, on one labelled sheet, as `eye_silhouettes.png` was.** Withered and aggressive, nothing like the Metro's hand-in-a-crown (`Animas.gd`). Check against `aesthetic-checklist-for-models` and `world-built-by-its-events`: souls no one lit a candle for, fire nearly out. The face is mostly open mouth, not a modelled human face.
- [ ] **Step 2: Send it to the user. Stop until they pick one for each form.** Record the picks in the spec and in the file's docstring.

### Tasks 10, 11, 12: The hands, then the face, then the torso

Each is one task, one model, and a gate. Do them in this order. Don't start the next until the user has approved this one (`models-one-by-one-supervised`).

**Files, each:**
- Create: `tools/monsters/build_anima_<form>.py` (shared helpers in `tools/monsters/anima_common.py`), `assets/monsters/anima_<form>.glb`, `assets/monsters/source/anima_<form>_*.png` (previews, gitignored if the repo's rules say), `scripts/Monsters/anima_flesh.gdshader` (once)
- Modify: `scripts/Monsters/AnimaBody.gd`, `scripts/Monsters/LeechHands.gd` (hands model, from Task 10), `tests/anima_test.gd`

**Interfaces:** `AnimaBody`'s surface from Task 1 doesn't change. Add `fed` as an instance uniform: fuller flesh and brighter fire the more it has drunk.

- [ ] **Step 1: Write the failing checks.**

```gdscript
_check("V1 the model loads, with its parts", body.part(&"...") != null)
_check("V1b vertex colours arrive, not white", colours_painted)
_check("V2 it moves as it does: fingers walk, or the arms drag", pose_changed_while_moving)
_check("V3 it shows what it drank", body.fed_shown > 0.5)
_check("V4 under its budget (eye: about 7,500 tris each)", tris <= budget)
```

- [ ] **Step 2: Run. Expected: FAIL.**
- [ ] **Step 3: Build through the eye's pipeline.** Script refuses open edges. Colour attribute active and `export_all_vertex_colors=False`, or the exporter writes white. Where the torso ends it ends in closed form inside its fire, not a cut. Fire: burnt-out, low and dirty, a trace of chartreuse, built as `MeshVfx` meshes.

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/monsters/build_anima_<form>.py -- "$PWD"
```

- [ ] **Step 4: Import with `$G --headless --path . --import` (exit 134 is the harmless editor crash). Motion is procedural in `AnimaBody`, as `EyeBody` does: fingers walking for the hands, a surge and bite for the face, hand-over-hand for the torso, with a held anticipation on each tell and a recoil when thrown off (`fp-animation-principles`).**
- [ ] **Step 5: Stills in the game, close up and at fight distance, in the yard's light and the room's. Inspect every joint (`inspect-geometry-closely`, `finished-means-meticulous`). Fix every fault. Run `anima_test`.**
- [ ] **Step 6: Commit, send the stills and the play command, and stop for the user's verdict.** `feat(hunt): the <form>'s model`

### Task 13: Deaths, and the whole thing

**Files:**
- Modify: `scripts/Monsters/AnimaBody.gd`, `scripts/Monsters/Anima.gd`, `docs/systems/hunts.md`, `docs/superpowers/refs/hunt/sounds_needed.md`, `tests/anima_test.gd`, `tests/diag_hunt_video.gd`

- [ ] **Step 1: Failing checks.**

```gdscript
_check("E1 killed, it comes apart: chunks, and its fire goes out", chunks_seen and not visible_after)
_check("E2 a kill is felt: hold and jolt", held and jolted)
_check("E3 it leaves something on the floor a while", remains > 0)
_check("E4 many at once stay within frame budget: 7 bodies, no errors in a long run", long_run_ok)
```

- [ ] **Step 2: Run. Expected: FAIL.**
- [ ] **Step 3: Implement.** `burst` uses `Remains.gd` and goes to withered ash, with the fire guttering out, in keeping with no downloaded VFX. Voices from the `monster_04` kin on the Souls bus (2 at once, as the Metro's). Measure frame rate in a windowed run of wave three and report the number.
- [ ] **Step 4: Run every hunt suite, then the full library** (`.superpowers/sdd/2026-11-01-hunts-1-first-playable-loop/run_all.py`, when the user isn't playing). Compare failures with main. Known already: `freerun` FR50, `lane_landmarks_view`, `sway_test`, `old_town_walk` W1, `vfx_test` V1/V5b/V6 flipping, showcase flaky.
- [ ] **Step 5: Commit.** `feat(hunt): how ánimas die; the ánima hunt whole`
- [ ] **Step 6: Final whole-branch review by a fresh reviewer. Tell the user this is ready for mixing with the eyes, which is the next plan, not this one.**
