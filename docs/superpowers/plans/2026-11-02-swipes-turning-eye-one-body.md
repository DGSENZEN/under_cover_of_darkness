# Swipes, the Turning Eye, One Body Under Attack: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ánimas fight with swipes as well as latching on, a badly hurt eye turns into a worse one that spits the curse, the curse and the drain read as one body under attack, and a mixed gym lets the user try it all.

**Architecture:** Swipes are new states on `Anima.gd` with poses in `AnimaBody.gd`. The turn is a one-way change on `FloatingEye.gd`, with a new model and `EyeGob.gd` for the spit. `StealthHUD.gd` already feeds both screen shaders each frame, so it tells each about the other. `maps/mixed_gym` extends the hunt gym.

**Tech Stack:** Godot 4.5.1 GDScript and shaders; Blender headless Python.

**Spec:** `docs/superpowers/specs/2026-11-02-swipes-turning-eye-one-body-design.md`

## Global Constraints

- What the curse and the drain do to the player does not change. Only their look joins.
- The leap's numbers, the latch and the drain do not change, except that a leap happens only beyond swipe reach and at most once every 4 s.
- A turned eye has no more health and no change to its weaknesses.
- No `juice.punch` pitch for anything repeating: trauma and roll only.
- Sounds from approved packs or the user's ElevenLabs takes (`docs/superpowers/refs/hunt/elevenlabs_prompts.md`); stand-ins until they arrive, listed in `sounds_needed.md`. Effects made by us. No on-screen words without the user.
- Stills from the real game, room and dark yard, inspected close up, before anything is shown.
- Test: `G=/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot; timeout 280 "$G" --headless --fixed-fps 60 --path . res://tests/<suite>.tscn`; pass is exit 0, no `^FAIL`, no `SCRIPT ERROR`.

## Review Focus

1. A swipe landing while you are already held by another ánima, dead, or mid-dodge: a held player can still be cut; dead takes nothing; a dodge avoids it (Task 1).
2. An ánima whose wind-up is under way when it is thrown off, hit, or put on you by something else: the swipe cancels cleanly, no hit from a state it left (Task 1).
3. An eye dying in the same hit that crosses half health: it dies, with no turn burst and no model swap on a dead thing (Task 5).
4. A gob in flight when its eye dies, or the scene ends: it flies on or frees, no error, and a batted gob never hits you (Task 5).
5. Curse only, drain only, then one lifted while the other stays: each looks as approved when alone, with no stuck pale flesh or stuck eye direction (Task 6).

---

### Task 1: Swipes, as fighting

**Files:**
- Modify: `scripts/Monsters/Bestiary.gd`, `scripts/Monsters/Anima.gd`
- Test: `tests/anima_test.gd`

**Interfaces:**
- Produces: `Anima.State` gains `WIND_UP, SWIPE, BACK_OFF`; `DOING` maps them to `&"wind_up"`, `&"swipe"`, `&"back_off"`. `Anima.swiped` signal `(hit: bool)`. Form rows gain `swipe_damage, swipe_reach, swipe_wind, swipe_every` (Vector2).

Values: hands 6, 1.7 m, 0.32 s; face 10, 2.0 m, 0.42 s; torso 14, 2.2 m, 0.6 s; every (1.4, 2.4) s. `SWIPE_TIME := 0.16`, a lunge of 4 m/s during it. `BACK_OFF_TIME := 0.7` at 3 m/s away and to one side, then RUSH. `LEAP_EVERY := 4.0`.

- [ ] **Step 1: Write the failing checks** in a new `_swipes()`:

```gdscript
_check("P1 in reach, it winds up to swipe, it doesn't leap", e.state == STATE.WIND_UP)
_check("P2 the swipe hurts your life (%.1f), and takes no power" % lost, is_equal_approx(lost, 6.0) and p.power.power == power_was)
_check("P2b it doesn't get on you", p.leech.count() == 0)
_check("P3 then it backs off, and comes again", backed_away > 1.0 and came_again)
_check("P4 a dodge avoids it", not_hurt_dodging)
_check("P5 a non-lead hit in its wind-up breaks it, and opens it", broke.state == STATE.THROWN and broke.is_exposed())
_check("P5b lead passes through, and it swipes anyway", leaded.state == STATE.SWIPE or swipe_landed)
_check("P6 out of reach, in leap range, it may leap; not again within 4 s", leaps_in_6s == 1)
_check("P7 a copal line stops it reaching you", not_hurt_over_line)
_check("P8 held by one, another can still cut you", lost_held > 0.0)
_check("P9 dead, you take nothing", lost_dead == 0.0)
_check("P10 put on you mid wind-up: the swipe is gone", held.state == STATE.ON and no_late_hit)
_check("P11 the three forms, their numbers", hands_lost == 6.0 and face_lost == 10.0 and torso_lost == 14.0)
```

- [ ] **Step 2:** Run `anima_test`. Expected: FAIL (`WIND_UP` missing).
- [ ] **Step 3: Implement.** RUSH picks: in swipe reach and its swipe clock is up, WIND_UP; beyond reach, in `leap_reach`, room on you, and `LEAP_EVERY` since the last, TELL (as now); else keep coming. `_is_opening` includes WIND_UP. SWIPE hits once, by `player.take_damage(damage, self)`, if `_chest_distance <= reach + 0.3`, not dodging, not dead. No check on the Ward: it stops spells and shots, not blows (spec). Existing leap tests that expect a TELL up close move their ánima out of swipe reach.
- [ ] **Step 4:** Run `anima_test`, `anima_gym_test`, `burst_spell_test`, `copal_line_test`. Expected: PASS.
- [ ] **Step 5: Commit.**

### Task 2: Swipes, as seen

**Files:**
- Modify: `scripts/Monsters/AnimaBody.gd`, `scripts/Monsters/AnimaDeaths.gd` (no change expected; check), `scripts/UI/StealthHUD.gd`, `docs/superpowers/refs/hunt/sounds_needed.md`
- Test: `tests/anima_test.gd`, `tests/diag_anima_stills.gd`

**Interfaces:**
- Consumes: `Anima.swiped(hit)`, the `DOING` names from Task 1.
- Produces: `StealthHUD.claw_at(side: float) -> void`: opens the drain view's claw marks on that side (`claw_age`, `claws_from`) even with nothing on you. `drain_state()["claws"]` already reports them.

Poses: hands: draw back on the wrist, fingers spread, then a raking roll with fingers shutting in order. Face: two-handed crossing rake (one in three, the jaw-snap lunge), head into it, then scuttle away with `back_off`. Torso: its boxes lunge.

- [ ] **Step 1: Write the failing checks.**

```gdscript
_check("Q1 wind-up: drawn back, fingers open (%.2f)" % curl, drawn_back and curl < 0.2)
_check("Q2 the swing shuts its fingers through the rake", curl_after > curl + 0.4)
_check("Q3 a face's hands cross", crossed)
_check("Q4 cut, your view shows the claw marks, nothing on you", hud.drain_state()["claws"] > 0.1 and p.leech.count() == 0)
_check("Q4b and they go, leaving no drain", faded and hud.drain_state()["drain"] < 0.01)
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** The view: the drain shader must draw claws while `drain` is 0, so `_show_drain` stays visible while a claw mark is young. Add stand-in sounds (`whoosh_light` high, `flesh`) with a row for each ElevenLabs name.
- [ ] **Step 4:** Run. Expected: PASS. Stills: `--only=swipe` (hands and face through wind-up and swing, close), inspected.
- [ ] **Step 5: Commit.**

### Task 3: The eye alive

**Files:**
- Modify: `scripts/Monsters/EyeBody.gd`, `tests/floating_eye_test.gd`, `tests/diag_curse_stills.gd`

**Interfaces:**
- Produces: `EyeBody.spring_pose() -> Dictionary`, for tests: `{"crown": float, "lids": float, "drawn_back": float}`; `EyeBody.lean_back() -> float`.

Sprung as `AnimaBody._spring` is, on its existing parts: at rest a slow drift and a sudden twitch; the tell draws it back with lids wide and a tremble that builds; a swoop's head thrown forward; hurt, a recoil and a shudder; bounce, stagger.

- [ ] **Step 1: Write the failing checks.**

```gdscript
_check("E1 its tell draws it back (%.2f)" % eye.body.lean_back(), eye.body.lean_back() > 0.05)
_check("E2 it shakes harder the nearer it is to going", shake_late > shake_early * 1.5)
_check("E3 hurt, it recoils and shudders", recoil > 0.04)
_check("E4 at rest it twitches now and then", twitches >= 1)
```

- [ ] **Step 2:** Run `floating_eye_test`. Expected: FAIL.
- [ ] **Step 3: Implement** in `EyeBody._pose` and `_wanted`.
- [ ] **Step 4:** Run. Expected: PASS. Stills inspected.
- [ ] **Step 5: Commit.**

### Task 4: The turned eye's model (the user sees it before the rest is built)

**Files:**
- Create: `tools/monsters/build_eye_turned.py`, `assets/monsters/floating_eye_turned.glb`
- Test: `tests/floating_eye_test.gd`

**Interfaces:**
- Produces: `floating_eye_turned.glb`, with the same part names as `floating_eye.glb`, so `EyeBody` can swap. Extra parts `Pupil_2`, `Pupil_3` and `Meat`.

Edit the approved eye (`tools/monsters/build_eye.py`'s output), not from scratch: the lids ripped back in tatters, the meat split open round the ball and hanging, two more pupils pushing through the ball, exposed wet veins, painted in the eye's own palette with a wetter dark red. Closed solids; the script refuses an open edge.

- [ ] **Step 1: Write the failing check** `T0`: it loads, has every part of `floating_eye.glb` and the extra three.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Build it.** Inspect close up, every joint, from all sides ([[inspect-geometry-closely]]). Render in the game's look, room and yard.
- [ ] **Step 4:** Run. Expected: PASS. Send the user the picture. **Stop for the user's verdict; fix until approved.**
- [ ] **Step 5: Commit.**

### Task 5: The turn and the spit

**Files:**
- Create: `scripts/Monsters/EyeGob.gd`
- Modify: `scripts/Monsters/FloatingEye.gd`, `scripts/Monsters/EyeBody.gd`, `scripts/Combat/Revolver.gd`, `docs/superpowers/refs/hunt/sounds_needed.md`
- Test: `tests/floating_eye_test.gd`

**Interfaces:**
- Consumes: Task 4's model; `EvilEyeCurse.deepen()`; `Statuses.apply(&"evil_eye", …)`, as the gaze does.
- Produces: `FloatingEye.turned: bool`; `FloatingEye.turn() -> void`, one-way; `FloatingEye.start_turned` for tests and stills; `State.SPIT_UP`, `State.SPIT`. `EyeGob.spat_at(context: Node, from: Vector3, at: Vector3, by: Node3D) -> Node3D`, group `eye_gobs`; `EyeGob.bat(way: Vector3, by: Node3D) -> void`. `FloatingEye.TURNS_AT := 0.5`.

Values: spit every 2.5 to 4 s from CIRCLE, wind-up 0.55 s, gob 9 m/s at where you were, 8 damage, radius 0.5 m; a wall or the Ward stops it. Batted: `BAT_SPEED`, `BAT_HURT`, hurts what it meets, and never you. Whip reach for a gob as for a swoop (3.2 m); the whip picks a gob in reach first.

- [ ] **Step 1: Write the failing checks.**

```gdscript
_check("U1 at half health or less it turns", eye.turned)
_check("U1b once, and not before", not_turned_above and turn_count == 1)
_check("U2 killed outright through half: no turn, no burst", not killed.turned and turn_bursts == 0)
_check("U3 it wears the turned model", eye.body.part(&"Pupil_2") != null)
_check("U4 its health and weaknesses are as they were", is_equal_approx(eye.health, was - 60.0) and eye_scale_same)
_check("U5 a turned eye spits, with a wind-up to read", saw_spit_up and gob != null)
_check("U6 it hurts (%.1f) and opens another eye" % lost, is_equal_approx(lost, 8.0) and p.curse.depth() == depth_was + 1)
_check("U6b on no curse, it starts one", p.curse.depth() == 1)
_check("U7 you can step out of its way", dodged_clean)
_check("U8 a wall stops it; so does the Ward", walled and warded)
_check("U9 whipped back, it hurts what it meets, and not you", other.health < other_was and you_unhurt)
_check("U10 its eye dead, it flies on; the scene ending frees it", no_errors)
_check("U11 it still swoops and stares", swooped and stared)
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** `take_hit` turn check after `_die`, so a dead eye never turns. The burst: gore, a shriek, a hitch. Stand-in sounds with ElevenLabs names listed.
- [ ] **Step 4:** Run `floating_eye_test`, `hunt_loop_test`, `revolver_test`. Expected: PASS. Stills, frame by frame, inspected.
- [ ] **Step 5: Commit.**

### Task 6: One body under attack

**Files:**
- Modify: `scripts/UI/StealthHUD.gd`, `scripts/UI/evil_eye_view.gdshader`, `scripts/UI/life_drain_view.gdshader`, `scripts/Combat/Crosshair.gd` or wherever `Crosshair` lives
- Test: `tests/floating_eye_test.gd`, `tests/anima_test.gd`, `tests/diag_anima_stills.gd` (`--only=both`)

**Interfaces:**
- Produces: new `evil_eye_view` uniforms `drained` (0..1), `gulp` (0..1), `claw_age`, `claws_from[3]`, `feeders[3]` (screen x, y, weight). `StealthHUD.curse_state()` gains `drained`, `squeeze`, `eyes_to`. `Crosshair` draws one mark when both are up. `StealthHUD.middle_kept_clear() -> bool`.

- [ ] **Step 1: Write the failing checks**, in `anima_test`'s `_both()`:

```gdscript
_check("B1 drained, the flesh goes pale", state["drained"] > 0.5)
_check("B2 on a gulp the flesh squeezes in", squeeze_high > squeeze_low + 0.3)
_check("B3 the eyes turn to what is on you", state["eyes_to"].x > 0.5)
_check("B4 a rake reaching the flesh tears it", eye_look.get_shader_parameter(&"claw_age") < 0.5)
_check("B5 one crosshair", hud._crosshair.marks_shown() == 1)
_check("B6 at the worst, the middle is clear", hud.middle_kept_clear())
_check("B7 curse alone: as it was", alone_curse["drained"] == 0.0)
_check("B7b the drain gone, the flesh comes back", back["drained"] < 0.05)
_check("B7c the curse gone, the drain as it was", curse_view_hidden and drain_view_shown)
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** Draw order stays; `_drain_copy` stays. Palette: the curse's reds and the drain's wash meet in a shared muted tone as `drained` rises; orange irises and sick green stay the only accents. The eyes' turn uses the existing `gazers` logic with `feeders`.
- [ ] **Step 4:** Run. Expected: PASS. Stills at each of: curse alone, drain alone, both with one on you, the worst. Close up, inspected. Fix what reads as two pictures.
- [ ] **Step 5: Commit.**

### Task 7: The mixed gym, judged whole

**Files:**
- Create: `maps/mixed_gym.gd`, `maps/mixed_gym.tscn`, `data/jobs/mixed_gym.job`, `tests/mixed_gym_test.gd`, `tests/mixed_gym_test.tscn`
- Modify: `docs/systems/hunts.md`, `docs/systems/README.md` if it lists gyms

**Interfaces:**
- Consumes: `maps/anima_gym.gd`'s room, drains and copal kit by extending it; `AnimaScript`, `EyeScript`.

Waves: 3 hands and 2 eyes; 2 faces, 3 hands, 3 eyes; torso, 2 faces, 3 hands, 4 eyes. F5, F6 as the others. The kit holds lead, copal, the copal line and the egg. The job's words are `<<...>>` placeholders for the user.

- [ ] **Step 1: Write the failing checks.**

```gdscript
_check("X1 three waves, both kinds in each", waves_mixed)
_check("X2 clearing one brings the next", next_came)
_check("X3 a bot can clear it", cleared)
_check("X4 the kit has what answers both", has_copal and has_egg)
```

- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Windowed, the last wave, forcing the worst: measure frame time. Expected: holds 60 fps on this M4 Pro at 1152x648. Ledger the numbers. If it doesn't, find what costs most and fix it here.
- [ ] **Step 6:** All the fight suites, then `docs/systems/hunts.md`. Commit.
- [ ] **Step 7:** Final fresh review of the branch range. One fix pass. Then hand the user the gym.
