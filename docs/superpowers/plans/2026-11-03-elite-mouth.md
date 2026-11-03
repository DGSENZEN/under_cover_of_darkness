# The Elite Mouth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An elite torso that, once hurt, seizes and takes in nearby hands and faces, healing and growing, and at three takes kills you if its lunge lands.

**Architecture:** The same `Anima` with `form = &"torso"` and an `elite` setting, as `FloatingEye.start_turned`; its numbers merged over the torso's from a Bestiary row; two new states for reaching and dragging; `AnimaMouth` shows what it has taken. A death of its own in `PlayerDeath`.

**Tech Stack:** Godot 4.5.1, GDScript, headless suites with `--fixed-fps 60`.

**Spec:** `docs/superpowers/specs/2026-11-03-elite-mouth-design.md`

## Global Constraints

- The plain torso is unchanged: its numbers, moves and look; all its checks pass as they were.
- No words of ours on screen. Effects are ours. Sounds: stand-ins from approved packs, wanted takes on `sounds_needed.md` and `elevenlabs_prompts.md`.
- All numbers live in `Bestiary` (`forms.torso.elite`), to be tuned in play.
- Failing checks first. Suite: `timeout 500 "$G" --headless --fixed-fps 60 --path . res://tests/anima_test.tscn`; pass is exit 0, no `^FAIL`, no `SCRIPT ERROR`.
- Mixed gym's worst wave holds 60 fps at 1152x648, vsync on (`tests/diag_mixed_perf.tscn`).
- Stills and film from the real game, inspected before anything is shown. Nothing moved in `_process` where it would judder.
- Commit explicit file lists; `assets/monsters/source/anima_hands.blend` is not ours to commit.

## Review Focus

- The small one seized dies, by you or anything else, in the same tick the mouth finishes taking it: no heal, no growth, no error (E3b).
- The elite dies, or is frozen or asleep, mid-drag: the small one drops alive and fights on (E3c).
- You die to something else while it reaches: it gives up and does as the others do (E3d).
- A save taken mid-drag: loaded, no drag is under way, the small one is back on the floor, what it had taken stays (E5c).
- Two elites, or one on a small one that is on you: never two claims on one, never one taken off you (E3e, E3f).

---

### Task 1: The elite, and what it grows into

**Files:**
- Modify: `scripts/Monsters/Bestiary.gd`, `scripts/Monsters/Anima.gd`, `scripts/Monsters/AnimaBody.gd`, `scripts/Monsters/AnimaMouth.gd`
- Test: `tests/anima_test.gd`

**Interfaces:**
- Produces: `Anima.elite: bool` (set before it enters the tree); `Anima.taken_count() -> int`; `Anima.take_in(kind: StringName) -> void`; `Bestiary.elite_form() -> Dictionary`. `AnimaMouth.grown_to(taken: Array[StringName]) -> void`, `AnimaMouth.candles_lit() -> bool`. `Monster.hit_radius()` follows it.
- Row, `forms.torso.elite`: `"health": 240.0`, `"start_size": 1.08`, `"grows": 0.12`, `"heals": 0.3`, `"most_taken": 3`, `"swipe_up": 0.2`, `"drain_up": 0.25`, `"slows": 0.08`, `"swipe_reach_up": 0.2`, `"leap_reach_up": 0.3`, `"hungry_below": 0.667`, `"hungry_every": 6.0`, `"looks_within": 5.5`, `"seizes_within": 2.6`, `"seizes_up": 0.3`, `"gives_up": 6.0`, `"drags": 1.2`.

- [ ] **Step 1: Write the failing checks** in a new `_elite_mouth()`:
```gdscript
_check("E1 a plain torso is as it was", plain.hit_radius() == 0.95 and not plain.body.candles_lit())
_check("E1b you can tell one: lit, and bigger", one.body.candles_lit() and one.hit_radius() > plain.hit_radius())
one.health = 100.0
one.take_in(&"face")
_check("E1c it wins back 30% of its most (%d)" % one.health, is_equal_approx(one.health, 100.0 + 240.0 * 0.3))
_check("E1d each one bigger, and it still stands on the floor", grown_size > size_was * 1.1 and absf(one.global_position.y - floor_y - expected_height) < 0.15)
_check("E1e its hands still reach the ground", one.body.arm_dug_in(0) and one.body.fingertip_y(0) < floor_y)
_check("E1f harder, slower", swipe_now > swipe_was and speed_now < speed_was and swipe_reach_now > swipe_reach_was)
_check("E1g never above its most, never over three", one.health <= 240.0 and one.taken_count() == 3)
_check("E1h what it took stays, a face for a face, a hand for a hand", one.body.taken_shown(&"face") == 1 and one.body.taken_shown(&"hands") == 2)
```
- [ ] **Step 2:** Run. Expected: FAIL (no `elite`).
- [ ] **Step 3: Implement.** `Anima._form` becomes the torso's row merged with the elite's and recomputed in `take_in`. Size on `AnimaMouth`'s root; `height` scaled so it stands on the floor. Lit candles: a small flame on each from `MeshVfx.flame`. What it took: built as `_build_presses`' nodes, standing up at a chosen spot, strength held. Fused spots stay out of the press spots' way.
- [ ] **Step 4:** Run. Expected: PASS. Film a shot `elite_stands` at 0, 1, 2, 3 taken, inspect each joint close up.
- [ ] **Step 5:** Commit.

### Task 2: They stay near it

**Files:**
- Modify: `scripts/Monsters/Anima.gd`
- Test: `tests/anima_test.gd`

**Interfaces:**
- Produces: `Anima.waits_for: Anima` (null unless an elite is in play), `Anima.elite_near() -> Anima`.

- [ ] **Step 1: Write the failing checks:**
```gdscript
_check("E2 small ones wait round it, you far off (%.1f m)" % off, off < 4.0)
_check("E2b you near, they come for you as ever", small.state in [STATE.RUSH, STATE.TELL, STATE.WIND_UP, STATE.LEAP, STATE.ON])
_check("E2c with nothing on you, they drift back", distance_after < distance_before)
_check("E2d with no elite, nothing has changed", ordinary_rush_distance == expected)
```
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** In `RUSH`, a small one with an elite near (group `elite_mouths`, 12 m), whose target is further than `leap_reach * 2.0`, circles the elite at 2.2 m by its `_spread_turn`. Otherwise as ever. `_hunger()`'s surge doesn't apply while waiting.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit.

### Task 3: Hungry, reaching, dragging in

**Files:**
- Modify: `scripts/Monsters/Anima.gd`, `scripts/Monsters/AnimaBody.gd`, `scripts/Monsters/AnimaMouth.gd`
- Test: `tests/anima_test.gd`

**Interfaces:**
- Consumes: Task 1's `take_in`, the row's numbers.
- Produces: `State.REACH`, `State.DRAG`, in `DOING` as `&"reach"`, `&"drag"`, `MOUTH_POSES` for each; `Anima.seized_by: Anima`; `Anima.is_seized() -> bool`; `Anima.prey() -> Anima`; `Anima.let_go_of_prey() -> void`; `AnimaMouth.seize_arm(at: Vector3, how_far: float) -> void`. `_is_opening()` true in both states, so a hit through `_is_opening_to` gives the tell's triple and power back.

- [ ] **Step 1: Write the failing checks:**
```gdscript
_check("E3 whole, it doesn't look for one", whole.state != STATE.REACH)
_check("E3a below two-thirds it goes for the nearest, not on you", one.prey() == nearest and one.state == STATE.REACH)
_check("E3g only from crawling, circling, backing off: never off you, nor from a lunge", held.state == STATE.ON and teller.state == STATE.TELL)
_check("E3h a wall or a copal line between: no", one.prey() == null)
_check("E3i smoked, it can't seize", smoked.state != STATE.DRAG)
_check("E3j seized, the small one stops and thrashes, and is dragged", small.is_seized() and small.global_position.distance_to(one.global_position) < at_start)
_check("E3k taken in 1.2 s: gone as the dead are, no burn, no reward", small.dead and not small.visible and p.power.power == power_was and one.taken_count() == 1)
_check("E3l a hit from anything but lead: triple, power back, stunned, and it lets go", result == &"weak" and one.state == STATE.THROWN and is_equal_approx(lost, base * 3.0) and not small.is_seized() and not small.dead)
_check("E3m lead changes nothing", one.state == STATE.DRAG)
_check("E3n kill the small one: it gets nothing", one.taken_count() == 0 and one.state != STATE.DRAG)
_check("E3o 6 s between tries", gap >= 5.9)
_check("E3p it gives up after 6 s if it can't get there", one.state != STATE.REACH)
_check("E3b dying as it is taken: no heal, no growth, no error", one.taken_count() == before)
_check("E3c the mouth dies or sleeps mid-drag: the small one drops alive", not small.is_seized() and not small.dead)
_check("E3d you die to something else as it reaches: it gives up", one.state != STATE.REACH)
_check("E3e two elites: never one prey between them", a.prey() != b.prey() or a.prey() == null)
_check("E3f one on you is never taken off you", on_you.state == STATE.ON and elite.prey() != on_you)
```
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** Selection on a ray with mask 1 and `CopalLine.crossing`. A seized small one's `_brain` moves it along the arm and does nothing else, its body told `&"thrown"`. `seize_arm` draws arm 2 out past `ARM_GETS`, its stretch allowed to the seize's reach for that moment.
- [ ] **Step 4:** Run. Expected: PASS. Film a shot `elite_feeds` and one `elite_stopped`.
- [ ] **Step 5:** Commit.

### Task 4: At three

**Files:**
- Modify: `scripts/Monsters/Anima.gd`, `scripts/Monsters/AnimaMouth.gd`, `scripts/Monsters/LifeLeech.gd`, `scripts/Monsters/LeechHands.gd`, `scripts/Monsters/LeechCage.gd`, `scripts/PlayerUtils/PlayerDeath.gd`, `scripts/UI/DeathQuotes.gd`
- Test: `tests/anima_test.gd`, `tests/player_death_test.gd`

**Interfaces:**
- Produces: `Anima.is_full() -> bool`; `PlayerDeath` kind `&"mouth"`, `LENGTHS[&"mouth"] = 2.6`, using the ánimas' quotes; `LifeLeech.swallowed_by(who: Node3D) -> void`; `LeechCage.shut_now(delta: float) -> void`.

- [ ] **Step 1: Write the failing checks:**
```gdscript
_check("E4 you can see it: every eye burning, all of them straining, hunger high", full.body.presses_up() == full.body.presses_held() and full.body.hunger() >= 0.6)
_check("E4b full, it looks for no more", full.state != STATE.REACH)
_check("E4c its tell is 2 s, and you can break it", told >= 114 and full.state == STATE.THROWN)
_check("Mo4 its lunge lands: dead there and then", p.is_dead and p.death.kind == &"mouth")
_check("Mo5 nothing frees you: whip, copal, Burst, blink", p.is_dead and p.leech_hands.cage().visible)
_check("Mo6 its ribs shut within a second, and stay shut", shut_by <= 62 and stayed_shut)
_check("Mo7 and your words come", p.death.quote_shown())
_check("Mo8 its swipe still only cuts", not p.is_dead and p.health == life_was - swipe)
_check("Mo9 short of three, it is the hold it always was", p.leech.slot_of(two) >= 0 and not p.is_dead)
_check("Mo10 invulnerable holds: no death", p.invulnerable and not p.is_dead)
```
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** In the leap's landing: `if is_full(): player.leech.swallowed_by(self)`. Death kind set before `begin`; `last_gulp()` for `&"mouth"` runs over the first second and holds at 1.
- [ ] **Step 4:** Run. Expected: PASS. Film `elite_kills`, inspect frame by frame.
- [ ] **Step 5:** Commit.

### Task 5: In the gyms, in the cage, in its death, in a save

**Files:**
- Modify: `maps/mixed_gym.gd`, `maps/anima_gym.gd`, `scripts/Monsters/Anima.gd`, `scripts/Monsters/AnimaMouth.gd`, `scripts/Monsters/LeechCage.gd`
- Test: `tests/anima_test.gd`, `tests/mixed_gym_test.gd`, `tests/anima_gym_test.gd`, `tests/save_coverage_test.gd` if it lists monsters

**Interfaces:**
- Produces: wave entry `&"elite": 1` in `MIXED_WAVES` and `ANIMA_WAVES`, a last wave of `{&"elite": 1, &"face": 2, &"hands": 4}` (mixed adds `&"eyes": 3`), small ones placed within 3 m of it; `Anima.save_state` adds `taken: Array[StringName]`.

- [ ] **Step 1: Write the failing checks:**
```gdscript
_check("E5 left alone and hurt, it reaches three", neglected.taken_count() == 3)
_check("E5b stopped or cleared, it doesn't", tended.taken_count() == 0)
_check("E5c saved mid-drag, loaded: no drag, the small one back, what it took stays", loaded.state != STATE.DRAG and not small_loaded.is_seized() and loaded.taken_count() == 1)
_check("E5d in the cage, a face for each taken, and the middle clear", cage.faces_shown() == 4 + faces_taken and cage.in_the_middle(aspect) == "")
_check("E5e dying, what it took comes out too", dead_body.souls_apart() >= plain_count + taken)
_check("X the last wave: an elite, and enough to take three", _counts(_awake()).get(&"elite") == 1)
```
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement** to the interfaces.
- [ ] **Step 4:** Run the gym suites and the frame cost. Expected: PASS, 60 fps held.
- [ ] **Step 5:** Commit.

### Task 6: Heard, shown, reviewed

This also finishes the mouth plan's Task 6 (`docs/superpowers/plans/2026-11-02-the-mouth.md`): its stand-ins, wanted takes and shots.

**Files:**
- Modify: `scripts/Audio/Sfx.gd`, `tests/sound_test.gd`, `docs/superpowers/refs/hunt/sounds_needed.md`, `docs/superpowers/refs/hunt/elevenlabs_prompts.md`, `tests/diag_showcase_video.gd`, `docs/systems/hunts.md`, `CREDITS.md` if any pack is new

- [ ] **Step 1:** Failing checks in `tests/sound_test.gd`: the mouth's `mouth_drag_loop`, `mouth_ribs_open`, `mouth_snap`, `mouth_close_on_you`, `mouth_ribs_crack`, `mouth_burst`; the elite's `mouth_seize`, `mouth_takes_in`, `mouth_full`. Each plays, on the world's sound buses, at the moment named.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Stand-ins from approved packs. Wanted takes listed. Shots in `SHOTS`, with `_expect`. `docs/systems/hunts.md`: the mouth, the elite, how to tune it.
- [ ] **Step 4:** Run all fight suites: anima, player_death, floating_eye, mixed_gym, anima_gym, hunt_gym, hunt_loop, revolver, burst_spell, copal_line, monster, bestiary, fight_move, loadout, safe_place, sound, caster, gunfight. Frame cost, with a dying mouth in it. Expected: PASS, 60 fps held.
- [ ] **Step 5:** Commit. Final review of the whole branch's mouth work, one fix pass, hand the gym over with Rulings and Deferred minors from both ledgers.
