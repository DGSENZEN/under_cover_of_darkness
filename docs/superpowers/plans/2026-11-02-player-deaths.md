# The Exsecrator's Deaths Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the eyes, the ánimas or both kill you, you see a first-person death that carries straight on from the fight, then the death page.

**Architecture:** A new `PlayerDeath` node on the player decides the death once, at the moment of dying, and runs its clock. The camera, `LifeLeech`, `LeechHands`, `LeechFace` and `StealthHUD` ask it whether the fight is still on screen instead of reading `is_dead`, and read their beats off its clock. Ánimas gain a state for losing interest.

**Tech Stack:** Godot 4.5.1, GDScript, canvas_item shaders. Suites run headless with `--fixed-fps 60`; stills windowed at 1152x648.

**Spec:** `docs/superpowers/specs/2026-11-02-player-deaths-design.md`

## Global Constraints

- Failing checks first; run, read the output, then commit. Never chain a commit onto a test run.
- `G=/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`; a suite: `timeout 500 "$G" --headless --fixed-fps 60 --path . res://tests/<name>.tscn`. Passing means exit 0, no `^FAIL`, no `SCRIPT ERROR`.
- Nothing worded by Claude on screen. "You were caught." and the page's words stay.
- Deaths by guards, falls and hazards keep today's camera, timing and words.
- No cut, freeze-frame or copy of the effects at the moment of death.
- No `juice.punch` pitch for anything repeating; `juice` left clean for the reload.
- Stills from the real game, lit room and dark yard, at each beat, inspected close up before anything is shown. Green fire or gore drawn solid and cheap fails.
- Effects are made by us. Sounds use approved stand-ins; wanted takes go on `docs/superpowers/refs/hunt/sounds_needed.md` and `elevenlabs_prompts.md`.
- Frame cost is measured with vsync on, `tests/diag_mixed_perf.tscn`.
- Commit with explicit file lists, ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No stray `.uid`s or refs that aren't ours.

## Review Focus

1. The last feeder dying mid-death (your Burst's wave landing late, a copal cloud): it lets go and burns as normal; the death goes on without error and finishes on its sight and colour. (Task 2)
2. Esc during a death: the clock waits, as the old 2 s timer did, and a skip press can't fire behind the pause screen. (Task 1)
3. Dying while climbing, hanging, swimming or in mid-air, with something feeding: `_die` lets go as it does now, the death plays, and the camera ends on the floor it lands on, not through it. (Task 3)
4. Dying while the egg is being used or a spell is casting: the curse's `gather` and `dispel` don't fight the death, and the page still comes. (Task 4)
5. A load or scene change during a death: nothing fires on a freed player, and the next run starts with `Sfx.drain_muffle` at 0 and no death state. (Task 1)

---

### Task 1: The director: which death, how long, then the page

**Files:**
- Create: `scripts/PlayerUtils/PlayerDeath.gd`, `tests/player_death_test.gd`, `tests/player_death_test.tscn`
- Modify: `scripts/PlayerController.gd` (`take_damage`, `drain_life`, `_die`, setup near `:644`), `scripts/Monsters/FloatingEye.gd`, `scripts/Monsters/EyeGob.gd`, `scripts/Monsters/Anima.gd`, `scripts/UI/StealthHUD.gd:1529-1531`

**Interfaces:**
- Produces, on `player.death` (`PlayerDeath`, a `Node`):
  - `kind: StringName`, one of `&""` (alive), `&"eyes"`, `&"animas"`, `&"both"`, `&"swipe"`, `&"fall"`
  - `begin(last_blow: StringName) -> void`, called once from `_die` before `died.emit()`
  - `playing() -> bool`: a death other than the fall, its clock still running
  - `at() -> float`: seconds since it began; `share() -> float`: 0..1 of its length
  - `signal finished`
  - `LENGTHS := {&"eyes": 3.0, &"animas": 3.5, &"both": 4.0, &"swipe": 2.0}`, `SKIP_AFTER := 1.0`, `WORDS_FROM_END := 0.5`
- Produces: `kills_as: StringName` on `FloatingEye` and `EyeGob` (`&"eyes"`) and `Anima` (`&"swipe"`). `PlayerController.last_blow: StringName`, set in `take_damage` from `from.get("kills_as")`, `&""` when it has none. `drain_life` leaves it alone.

- [ ] **Step 1: Write the failing checks** in `tests/player_death_test.gd`, staged as `tests/floating_eye_test.gd` stages its player (`reload_on_death = false`, `invulnerable = false`), one fresh player per case:

```gdscript
_check("P1 curse and something feeding, any blow: both", _kind_after(cursed, feeding, &"") == &"both")
_check("P1b even a guard's blow", _kind_after(cursed, feeding, guard) == &"both")
_check("P2 something feeding, no curse: the ánimas", _kind_after(clean, feeding, guard) == &"animas")
_check("P3 nothing feeding, an eye's bite: the eyes", _kind_after(clean, none, eye) == &"eyes")
_check("P3b a gob: the eyes", _kind_after(cursed, none, gob) == &"eyes")
_check("P4 nothing feeding, an ánima's swipe: the swipe", _kind_after(clean, none, anima) == &"swipe")
_check("P5 cursed, killed by a guard, nothing feeding: today's fall", _kind_after(cursed, none, guard) == &"fall")
_check("P6 each takes its length", is_equal_approx(eyes_took, 3.0) and is_equal_approx(both_took, 4.0))
_check("P7 the page waits for the end", page_shut_at_2_9 and page_open_after)
_check("P7b the fall's page still comes at 2 s", is_equal_approx(fall_page_at, 2.0))
_check("P8 the words start half a second from the end", words_at_end_minus_0_6 == 0.0 and words_at_end > 0.9)
_check("P8b the fall's fade and words start at once", fall_fade_after_half_second > 0.2)
_check("P9 an attack press before 1 s does nothing", death.playing())
_check("P9b after it, straight to the end", skipped_at < 1.3)
_check("P10 paused, the clock waits and a press is ignored", is_equal_approx(share_before_pause, share_after_pause))
_check("P11 freed mid-death, nothing fires, and the next player starts clean", no_error and Sfx.drain_muffle == 0.0 and fresh.death.kind == &"")
```

- [ ] **Step 2:** Run `player_death_test`. Expected: FAIL, `PlayerDeath` not found.
- [ ] **Step 3: Implement.** `PlayerDeath.begin` reads `player.leech.count()`, `player.statuses.has(&"evil_eye")` and `last_blow` by the spec's table. `process_mode` pausable. Skip reads `Input.is_action_just_pressed("throw")`. `_die` awaits `death.finished` where `death.playing()`, else today's 2 s timer. The HUD's fade and words at `:1529`: where `player.death.playing()`, hold off until `WORDS_FROM_END` from the end, then reach full by the end; the fall as today.
- [ ] **Step 4:** Run. Expected: PASS. Then `floating_eye_test`, `hunt_loop_test`. Expected: PASS.
- [ ] **Step 5: Commit.**

### Task 2: They don't let go, then they lose interest

**Files:**
- Modify: `scripts/Monsters/LifeLeech.gd` (`:256` the throw on death, `_gulp_now`), `scripts/Monsters/Anima.gd` (`State`, `DOING`, `_brain`, `_wish`), `scripts/Monsters/AnimaBody.gd` (`POSES`)
- Test: `tests/player_death_test.gd`, `tests/anima_test.gd` (`A16`)

**Interfaces:**
- Consumes: `player.death`.
- Produces: `Anima.State.LEAVE`, `DOING` `&"leave"`, `AnimaBody.POSES[&"leave"]` (low, slack, head down, slow), `Anima.lose_interest() -> void`, constants `LEAVE_SPEED := 1.4`, `LEAVE_TIME := 6.0`, then `State.REST`.
- Produces: `LifeLeech.last_gulp() -> float`: 0 until the death's final gulp, then rising to 1 and held. `PlayerDeath.LETS_GO := {&"animas": 2.6, &"both": 3.0, &"swipe": 0.4}` (seconds in, when everything feeding or awake loses interest). `PlayerDeath.gulps_slow() -> float`, the gulp pace's multiplier: 1 at the start, `3.0` by the final gulp.

- [ ] **Step 1: Write the failing checks:**

```gdscript
_check("L1 dead with one on you, it stays on you", p.leech.count() == 1 and taker.state == STATE.ON)
_check("L2 it goes on gulping, slower each time", gaps[2] > gaps[0] * 1.3)
_check("L3 a last long gulp before it lets go", last_gulp_rose)
_check("L4 at its moment it lets go and crawls off", p.leech.count() == 0 and taker.state == STATE.LEAVE)
_check("L4b away from you, and not fast", went_away and taker.velocity.length() <= Anima.LEAVE_SPEED + 0.01)
_check("L5 after a while it rests", ended_in_rest)
_check("L6 it never hurts you, or takes power, after you die", power_same)
_check("L7 awake and not on you: every ánima crawls off, swings stopped", all_leaving and no_swing_after)
_check("L7b the fall too: a guard kills you, they crawl off", fall_leaving)
_check("L8 the last feeder killed mid-death: the death goes on, no error", p.leech.count() == 0 and death.playing() and not script_error)
```

`A16` in `anima_test` changes on purpose: it now expects `LEAVE` after the let-go, power still unchanged.

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** `Anima._brain`: once `you.is_dead`, unless ON and the death still has it, `lose_interest()`; a wind-up or swipe under way cancels. LEAVE walks away from you at `LEAVE_SPEED`, keeping the existing wall and height handling. It doesn't sleep, so a save or a late Burst can still find it. `LifeLeech` stops throwing on death; at `LETS_GO` it releases each with `lose_interest()`. No drain after death: `drain_life` already returns.
- [ ] **Step 4:** Run `player_death_test`, `anima_test`, `anima_gym_test`, `mixed_gym_test`. Expected: PASS.
- [ ] **Step 5: Commit.**

### Task 3: Going down: the camera, and the hands and face staying on you

**Files:**
- Modify: `scripts/PlayerUtils/CameraJuice.gd:561`, `scripts/PlayerController.gd:4479`, `scripts/Monsters/LeechHands.gd:201`, `scripts/Monsters/LeechFace.gd`, `tests/diag_anima_stills.gd`
- Test: `tests/player_death_test.gd`

**Interfaces:**
- Consumes: `player.death`, `LifeLeech.last_gulp()`, `LETS_GO`.
- Produces: `CameraJuice.death_fall: Dictionary` of `{"down": float, "turn": Vector3, "side": float}` written each frame by `PlayerDeath.camera_pose() -> Dictionary`. Empty means today's fall. `PlayerDeath.camera_pose` for each kind:
  - eyes: sinks slowly to kneeling (down 0.7), head dropping forward, then to the floor in the last second
  - animas, both: dragged toward the side the first holder has you (`player.leech.slot_side`), down onto your side (down 1.3, roll 1.15) by `LETS_GO`, then still, breathing less
  - swipe: rolled off the rake's side (`StealthHUD._cut_at.x`), quick, floor by 0.7 s
- Produces: `LeechHands` and `LeechFace` read `player.death.playing()` where they read `is_dead` today. `LeechFace.drink` gains `last: float`: the face comes in to fill the view (`near` up to its held-close limit), jaw clamped, throat working. With only hands on you, `last` closes them in one long squeeze, and they stop.

- [ ] **Step 1: Write the failing checks:**

```gdscript
_check("C1 the fall's camera is as it was", fall_pose_equals_old_formula)
_check("C2 dying with one on you, the hands stay shown", hands.shown(slot) and p.is_dead)
_check("C2b the face too, and it comes in", hands.face_shown(slot) and face_near_at_last > face_near_before + 0.2)
_check("C2c only hands: one long squeeze, then still", hands_squeeze_at_last > 0.8 and hands_still_after)
_check("C3 dragged toward its side", sign(view_roll_or_lean) == sign(slot_side_x))
_check("C4 you end low on the floor, not through it", cam_y_above_floor > 0.08 and cam_y_above_floor < 0.5)
_check("C4b dying in mid-air, you come down first", ended_near_floor)
_check("C4c dying on a climb or a ledge: no error, you land", ended_near_floor_from_climb)
_check("C5 after it lets go, the hands go", not hands.shown(slot))
_check("C6 the view holds still after it lets go", moved_after_let_go < 0.02)
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** Keep `death_fall` empty for the fall. The camera's floor check: the existing `_stop_on_death` keeps the body on the floor; clamp the view's `down` to the height above it.
- [ ] **Step 4:** Run. Expected: PASS. Add `--only=die_animas` to `diag_anima_stills`, stills at 0.5, 1.5, 2.5, 3.2 s in the room and yard, and read them close up. Fix what fails the Global Constraints.
- [ ] **Step 5: Commit.**

### Task 4: The eyes' death, on screen

**Files:**
- Modify: `scripts/UI/evil_eye_view.gdshader`, `scripts/UI/StealthHUD.gd` (`_show_curse`, `_tell_each_other`), `tests/diag_anima_stills.gd`
- Test: `tests/player_death_test.gd`

**Interfaces:**
- Consumes: `player.death`.
- Produces: `evil_eye_view` uniforms `dying` (0..1, the flesh closing past where it ever goes, all the way in), `last_eye` (0..1, the eye tearing open in the very middle, size about a third of the view's height), `extra_eyes` (0..1, four more eyes than the curse's six tearing open across the closing flesh), `failing` (0..1, the beat faster, then stopping). `StealthHUD.curse_state()` gains `dying`, `last_eye`, `extra_eyes`, `failing`. HUD constants for the beat: `CLOSES_FROM := 0.15`, `LAST_EYE_AT := 0.6`, `FAILS_FROM := 0.7` (shares of the death).
- The curse's `alive` in `_show_curse` is true while `player.death.playing()`, so its ring stays. All six rings open during this death, whatever the depth was. `middle_kept_clear` is only asked of the living.

- [ ] **Step 1: Write the failing checks:**

```gdscript
_check("E1 killed by an eye with no curse on you: the flesh still comes", state["dying"] > 0.0 and curse_view_shown)
_check("E2 it closes all the way", state_late["dying"] > 0.95)
_check("E3 every eye opens, and more than the curse ever had", state_late["ring_open"] == 6 and state_late["extra_eyes"] > 0.9)
_check("E4 the last eye opens in the middle, late", at_half["last_eye"] == 0.0 and state_late["last_eye"] > 0.9)
_check("E5 the fall: none of it", fall_state["dying"] == 0.0)
_check("E6 using the egg as you die: the egg stops, and the page still comes", gather_zero and finished)
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** `dying` drives `closing` past 1 in `flesh_past` until it covers the view. The last eye uses `sunk_eye`, fully open and looking at you, through a tear in the flesh. A death stops the egg: `_gather` and `_dispel` read 0 while it plays.
- [ ] **Step 4:** Run. Expected: PASS. Stills via `--only=die_eyes`, room and yard, at each beat, read close up. Fix what fails.
- [ ] **Step 5: Commit.**

### Task 5: The ánimas' death, both, and the swipe, on screen

**Files:**
- Modify: `scripts/UI/life_drain_view.gdshader`, `scripts/UI/evil_eye_view.gdshader`, `scripts/UI/StealthHUD.gd` (`_show_drain`, `_tell_each_other`), `tests/diag_anima_stills.gd`
- Test: `tests/player_death_test.gd`

**Interfaces:**
- Consumes: `player.death`, `LifeLeech.last_gulp()`, Task 4's uniforms.
- Produces: `life_drain_view` uniforms `no_colour` (0..1, all colour gone, middle too) and `sight_fails` (0..1, the dark in from the edges, to all of it, the middle no longer spared). `evil_eye_view` uniforms `slack` (0..1, the flesh stops beating and sags open a little; the heart stops) and `shut` (0..1, every eye shuts together). `drain_state()` gains `no_colour`, `sight_fails`; `curse_state()` gains `slack`, `shut`.
- Beats: animas: `no_colour` rises with each gulp to 1 by the last, `sight_fails` from `LETS_GO` to the end. both: as animas, with flesh closing (`dying`) up to `0.8`, not all the way; `shut` and `slack` go to 1 together across 0.2 s on the last gulp; no `last_eye`. swipe: `claw_at` the blow's side, marks held open to the end, `no_colour` none, `sight_fails` from 0.9 s; with the curse on you, `slack` rises from 0.2 s, no `last_eye`.

- [ ] **Step 1: Write the failing checks:**

```gdscript
_check("A1 the ánimas' death: colour goes with the gulps", rose_on_each_gulp and at_last["no_colour"] > 0.95)
_check("A2 you still see them leave, grey", at_leave["sight_fails"] < 0.5)
_check("A3 then your sight fails", end["sight_fails"] > 0.95)
_check("B1 both: the eyes watch them to the end", watching_until_last_gulp)
_check("B2 on the last gulp all shut and the flesh goes slack, together", absf(shut_at - slack_at) < 0.05 and shut_at_gulp)
_check("B3 no eye in the middle", both_state["last_eye"] == 0.0)
_check("B4 the heart stops: the flesh's beat is still", failing_after_shut == 1.0)
_check("S1 the swipe: its marks stay open to the end", swipe_claw_age < 0.5)
_check("S2 cursed, its flesh falls slack, with no ending of its own", swipe_cursed["slack"] > 0.9 and swipe_cursed["last_eye"] == 0.0)
_check("R1 the next life starts clean: nothing stuck", clean_after_reload)
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** Eyes go on using `feeders` while `watching`. `_tell_each_other`'s `held` and `_show_drain`'s `held` count while `player.death.playing()`. `Sfx.drain_muffle` holds until the let-go, then falls.
- [ ] **Step 4:** Run. Expected: PASS. Stills via `--only=die_both`, `--only=die_swipe`, room and yard, each beat, read close up. Fix what reads as two pictures.
- [ ] **Step 5: Commit.**

### Task 6: Heard, measured, judged whole

**Files:**
- Modify: `scripts/PlayerUtils/PlayerDeath.gd`, `docs/superpowers/refs/hunt/sounds_needed.md`, `docs/superpowers/refs/hunt/elevenlabs_prompts.md`, `docs/systems/hunts.md`, `tests/diag_mixed_perf.gd`

**Interfaces:**
- Consumes: everything above.
- Produces: `PlayerDeath` plays its beats with stand-ins: the heartbeat slowing and stopping (`heartbeat`), the last gulp (`flesh`, `anima_moan`), the body down (`body_fall`), the eye tearing (`flesh_heavy`). New wanted takes: `death_last_gulp`, `death_heart_stops`, `death_eye_tears_open`, `death_flesh_slack`, `death_breath_out`.

- [ ] **Step 1: Write the failing check:** `_check("H1 the heart stops: no heartbeat sound after the shut", beats_after == 0)`, reading a new `PlayerDeath.heartbeats: int`, counted where it plays one.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement** the sounds and the docs.
- [ ] **Step 4:** Add a death to `diag_mixed_perf`, measure with vsync on. Expected: no frames over 16.7 ms that the fight before it didn't have.
- [ ] **Step 5:** Run all the fight suites: `mixed_gym_test`, `anima_test`, `floating_eye_test`, `anima_gym_test`, `hunt_gym_test`, `hunt_loop_test`, `revolver_test`, `burst_spell_test`, `copal_line_test`, `monster_test`, `bestiary_test`, `fight_move_test`, `loadout_test`, `safe_place_test`, `player_death_test`, plus `sound_test`. Expected: PASS. Commit.
- [ ] **Step 6:** Final fresh review of the plan's range. One fix pass. Hand the user `maps/mixed_gym.tscn` with how to die each way: a wave one eye's bite for the eyes, a hand on you for the ánimas, both with the curse up.
