# Showcase Cinematography Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Calm the Cinema camera and give it real film coverage: moderate lenses, gentle focus, stillness, remembered setups, portrait conversations that build, softer transitions and a drama rhythm that lands on moments.

**Architecture:** Changes stay inside `scripts/Cinema/`, plus one showcase hook for act fades:
- `CineShot` gains a `portrait` kind and new lens tables.
- `CineOperator` sets lenses per shot, blurs only close and portrait framings, and stays still.
- `CineScreen` gains a dissolve and a fade through black.
- `CineEditor` gains setups, a talk state machine (build-up → portraits → re-establish) and a beat-waiting rhythm.

**Tech Stack:** Godot 4.5.1, GDScript; the headless suites `tests/cinema_test` and `tests/showcase_test`.

**Spec:** `docs/superpowers/specs/2026-09-27-showcase-cinematography-revision-design.md` (revises `2026-09-27-showcase-cinematography-design.md`).

## Global Constraints

- The Godot binary and the suite command are as before: `Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/<suite>.tscn`. Green means every result line is PASS and there is no SCRIPT ERROR.
- Worktree `.claude/worktrees/npc-showcase`, branch `cinematography-revision`. `scripts/Cinema/` names nothing of the showcase.
- **Lens:** vertical FOV range 26–40°. `LONG` 26–32°, `NORMAL` 40°, `PORTRAIT` 32°, `AXIAL` [40, 34, 28]. A new shot sets its lens at once; only `follow()` (the push-in) eases it. `PUSH_TO` 0.8 over 20 s.
- **Focus:** blur only for framings with `size` "close" or kind "portrait". Amount 0.04, far blur beginning 4 m behind the subject, near blur (over a shoulder only) beginning 1.0 m. Everything else has no blur.
- **Handheld:** observe 0; drama close ±0.15° and 0.5 cm; everything else 0; portraits 0 in either mode. Shake unchanged.
- **Setups:** one per man per kind per scene; reused if he is within 1.5 m of where it was made and it still sees him and is clear.
- **Portrait:** chest up (frame height 1.1 m), 32°, the camera at his eye height, 30° off the line toward the other man on the scene's side; facing = toward the other man.
- **Talks:** lines within `TALK_GAP` (3 s) are one talk.
  - Observe: portraits from the third line. Drama: a two-shot, then portraits from the second line.
  - A new speaker's portrait cut comes 0.3 s after his line began.
  - Reactions come on landing lines (shout or a grieving speaker) at the line's end, at most once in 8 s.
  - Re-establish every fourth change of speaker or when a third man speaks, held for the next line.
  - Portraits hold still: the aim moves only if the head moves more than 0.3 m.
- **Transitions:**
  - Observe takes that are not drifts: a 1.2 s dissolve.
  - `transition: "fade"`: 0.5 s to black, held until the next shot, then 0.5 s up.
  - The drama wipe stays for scenes of other men.
  - Headless: dissolve and fade are plain cuts.
- **Drama rhythm:** `SHOT` 3–8 s; a due cut waits up to 1.5 s for a beat (line start, blow, death); after two shots under 4 s the next is planned 6–8 s. Death, the knife and an alert to 3 or 4 cut at once after the 1.5 s floor.
- Match the codebase voice (`##` narrative doc comments, tabs, typed GDScript).

## Review Focus

1. A talk whose speaker is freed or knocked out mid-line (a portrait of a man who is gone) should give a new shot, no errors. Pinned in Task 4 (E31).
2. Three men talking in turn should get portraits that alternate between them without cuts under 1.5 s apart. Pinned in Task 4 (E32).
3. A talk that begins during a pinned shot should leave the pin alone; portraits start after it ends. Pinned in Task 4 (E33).
4. A dissolve or fade interrupted by hold or release should leave no black screen and no held frame. Pinned in Task 5 (S6).
5. A portrait whose setup would stand in a wall should fall back to a turned angle or a medium shot, and never stand inside geometry. Pinned in Task 3 (E26).

---

### Task 1: Calmer lenses, gentle focus, stillness

**Files:**
- Modify: `scripts/Cinema/CineShot.gd` (`LONG`, `AXIAL`, add `PORTRAIT := 32.0`)
- Modify: `scripts/Cinema/CineOperator.gd` (`MODES`, DOF constants, `show`, `_lens`)
- Modify: `scripts/Cinema/CineEditor.gd` (`PUSH_TO`)
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Produces:
  - `CineShot.PORTRAIT := 32.0`, `LONG := Vector2(26.0, 32.0)`, `AXIAL := [40.0, 34.0, 28.0]`.
  - `CineOperator` constants `BLUR_AMOUNT := 0.04`, `FAR_BEHIND := 4.0`, `NEAR_SOFT := 1.0`.
  - `MODES[&"observe"]` sways 0; `MODES[&"drama"]` has `"close_sway": 0.15`, `"sway": 0.0`, `"drift": 0.005`.
  - `show()` sets the lens at once for every `how`; `follow()` eases it at `LENS_RATE`.
  - Blur is on only when `framing.size == &"close"` or `framing.kind == &"portrait"`.

- [ ] **Step 1: Change the checks to the new values and add new ones:**
  - F3: observe/group/track in [26, 32]; close/over_shoulder/reaction in [35, 45].
  - F5: lenses [40, 34, 28].
  - O5 becomes: `show(glide)` with a new lens sets it at once (camera.fov == new fov next frame), and `follow()` with a new lens eases it (no frame step over 1°).
  - O6: amount 0.04; far distance = focus + 4.0 (±0.1).
  - O7: drama close within 0.15° (and above 0.01); observe 0 (below 0.001).
  - E3: the lens at the end ≤ 0.82× the start.

```gdscript
# O11 no blur on a medium, watching or wide framing: far and near blur both off
for size in [&"medium", &"wide"]:
	op.show(_frame_at(Vector3(600, 1.6, 6), head, 30.0, size), &"cut")
	await _frames(2)
	var att := camera.attributes as CameraAttributesPractical
	blurless = blurless and (att == null or (not att.dof_blur_far_enabled and not att.dof_blur_near_enabled))
```
- [ ] **Step 2: Run cinema_test; F3/F5/O5/O6/O7/O11/E3 FAIL.**
- [ ] **Step 3: Implement the constants and the operator changes.** `_lens` eases only toward the framing's fov set by `follow()`; `show()` sets `_fov` directly.
- [ ] **Step 4: Run cinema_test; all PASS.**
- [ ] **Step 5: Commit** with `feat(cinema): calmer lenses, focus only up close, a still camera`.

### Task 2: The portrait framing

**Files:**
- Modify: `scripts/Cinema/CineShot.gd` (`frame`, a new `_portrait`)
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Produces: `CineShot.frame(&"portrait", [man], {"toward": Vector3, "side": Vector3, "aspect": float})` returns size &"close", kind &"portrait", fov 32.0, near_blur false. The camera's y is his eye height (the head of `head_of`), 30° off the line from him toward `toward`, on `side`; composition faces `toward`. Without `toward`, his facing is used.

- [ ] **Step 1: Write F9 and F10.**

```gdscript
# F9 a portrait: eye height, 32 deg, on a third facing the other man, the 30 deg off his line to him
var p := CineShot.frame(&"portrait", [man], {"toward": CineShot.head_of(other), "side": side})
# camera y == head y (±0.05); fov == 32; the head within 0.04 w of a third, on the side away from `other` on screen;
# angle between (position - head) and (other_head - head), flat, is 30 deg (±2)
# F10 the other man's portrait is its mirror: on the same side of the line, his head on the other third
```
- [ ] **Step 2: Run; F9/F10 FAIL.**
- [ ] **Step 3: Implement `_portrait(man, head, toward, side, aspect) -> Dictionary`** (frame height 1.1 m, distance from `_distance(1.1, PORTRAIT)`).
- [ ] **Step 4: Run; PASS.**
- [ ] **Step 5: Commit** with `feat(cinema): the portrait: eye height, 32 deg, eyelines across the cut`.

### Task 3: Remembered setups

**Files:**
- Modify: `scripts/Cinema/CineEditor.gd` (`_pick`, `_open_scene`, new `_setup_for`)
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Produces:
  - `_setups: Dictionary` keyed `"%d:%s" % [man.get_instance_id(), kind]` → `{position: Vector3, fov: float, side: Vector3, head: Vector3}`, cleared in `_open_scene`.
  - `_pick` uses a valid setup for a one-man option before any angle search; a new setup is remembered when an option is taken.
  - A reused setup is framed from `position`: `context["from"]`, re-aimed with `CineShot._composed`.

- [ ] **Step 1: Write E24, E25 and E26.**

```gdscript
# E24 a cut back to a man returns to the same framing: two drama close shots of `a` in one scene
#     (another shot between) from positions within 0.1 m, same fov
# E25 `a` moved 2 m between them: a new setup (positions more than 0.5 m apart)
# E26 (Review Focus 5) a portrait of a man with a wall where his setup would stand: the shot taken stands
#     clear (CineVantage.clear) and sees him
```
- [ ] **Step 2: Run; FAIL.**
- [ ] **Step 3: Implement.** CineShot `_single` and `_portrait` honour `context.from` as a fixed position (look composed from it).
- [ ] **Step 4: Run; all PASS (E9–E23 still).**
- [ ] **Step 5: Commit** with `feat(cinema): setups remembered: a cut back to a man finds him where he was`.

### Task 4: Conversations that build into portraits

**Files:**
- Modify: `scripts/Cinema/CineEditor.gd` (the talk state: `cine_event` line handling, new `_talk_step`; `_observe_step`/`_drama_step` defer to it; `_follow` stillness)
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Produces:
  - `_talk: Dictionary` = `{lines: int, speaker, listener, changes: int, portraits: bool, men: Array}`, reset `TALK_GAP` after the last line.
  - Constants `PORTRAIT_FROM := {&"observe": 3, &"drama": 2}`, `SPEAKER_CUT := 0.3`, `REACTION_EVERY := 8.0`, `REESTABLISH_EVERY := 4`, `STILL_WITHIN := 0.3`.
  - Shots cut in a talk carry causes `&"two"` (build-up), `&"portrait"`, `&"reaction"`, `&"reestablish"`.

- [ ] **Step 1: Write E27 to E33** (lines emitted by the test as in E2, with a and b facing each other):

```gdscript
# E27 drama talk: a two-shot until the 2nd line, then portraits; each portrait cut 0.3 s (±0.1) after its line began;
#     the same man speaking again keeps his portrait (no shot_started)
# E28 observe talk: the take goes on until the 3rd line, then portraits (cause &"portrait")
# E29 a shouted line: the listener's portrait at the line's end; a second shout 4 s later: none
# E30 the 4th change of speaker: a two-shot (cause &"reestablish") held for the next line, then portraits again
# E31 (RF1) the speaker freed mid-line: a new shot within FLOOR + 0.1 s, no SCRIPT ERROR
# E32 (RF2) three men talking in turn: portraits of each, no two cuts under 1.5 s apart, a group re-establish when the third speaks
# E33 (RF3) a talk begun during a pin: the pin holds its seconds; portraits after
# E34 portraits hold still: camera moves < 0.01 m and turns < 0.1 deg over 3 s while the speaker stands
```
- [ ] **Step 2: Run; FAIL.**
- [ ] **Step 3: Implement the talk state and its cuts.** Portraits take `{"toward": the other man's head}` and use setups (Task 3). While `_talk.portraits` is on, `_observe_step` and `_drama_step` do nothing but the talk's cuts. In `_follow`, a portrait keeps `_operator`'s aim unless the head moved more than `STILL_WITHIN`.
- [ ] **Step 4: Run; all PASS.**
- [ ] **Step 5: Commit** with `feat(cinema): conversations build into portraits: the speaker, his voice first, the eyeline across the cut`.

### Task 5: Dissolves and fades

**Files:**
- Modify: `scripts/Cinema/CineScreen.gd` (`dissolve`, `fade_through`, `clear`)
- Modify: `scripts/Cinema/CineOperator.gd` (`show` hows "dissolve", "fade")
- Modify: `scripts/Cinema/CineEditor.gd` (observe new takes `dissolve`; `scene(intent)` honours `transition`)
- Modify: `scripts/Showcase/ShowCamera.gd` (`fade_next()`), `maps/npc_showcase.gd` (`act_started` → `camera.fade_next()`)
- Test: `tests/cinema_test.gd`, `tests/showcase_test.gd`

**Interfaces:**
- Produces:
  - `CineScreen.dissolve(texture: Texture2D)` fades a held frame 1 → 0 alpha over `DISSOLVE := 1.2`.
  - `CineScreen.fade_through(hold: float)`: black 0 → 1 over `FADE := 0.5`, held `hold` s, then 1 → 0 over `FADE`.
  - `dissolving() -> bool`, `black() -> float` (0..1).
  - `clear()` ends both at once.
  - The operator's `show(framing, &"dissolve" | &"fade")` captures or darkens, then cuts.
  - Scene intent `transition: &"fade"`.
  - `ShowCamera.fade_next()` marks the next `want()` with `transition: &"fade"`.

- [ ] **Step 1: Write S4 to S6, E35 and D41.**

```gdscript
# S4 dissolve(texture): dissolving() true, alpha about 0.5 at 0.6 s, false and texture released by 1.3 s
# S5 fade_through(0.4): black() reaches 1 by 0.55 s, stays until 0.9 s, 0 by 1.5 s
# S6 (RF4) clear() in the middle of a fade and a dissolve: black() 0 and no held frame at once
# E35 observe: a new take that is no drift is taken with how &"dissolve"
# D41 each act's first shot comes through black: after act_started, the next shot's how is &"fade"
```
- [ ] **Step 2: Run; FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both suites; PASS.**
- [ ] **Step 5: Commit** with `feat(cinema): dissolves between takes, acts through black`.

### Task 6: A drama rhythm that lands on moments

**Files:**
- Modify: `scripts/Cinema/CineEditor.gd` (`SHOT`, `_drama_step`, `_drama_next` length choice)
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Produces:
  - `SHOT := Vector2(3.0, 8.0)`, `BEAT_WAIT := 1.5`, `SHORT := 4.0`, `LONG_AFTER := Vector2(6.0, 8.0)`.
  - `_beat_at: float` is set by a line start, a blow or a death among the subjects.

- [ ] **Step 1: Update E9 (lengths 3–8.5, median 3–8) and write E36 and E37.**

```gdscript
# E36 a drama shot past its length with a blow 0.8 s later: the cut comes within 0.1 s of the blow, not before
# E37 after two shots under 4 s, the next runs 6 s or more (no urgent events)
```
- [ ] **Step 2: Run; FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; PASS.**
- [ ] **Step 5: Commit** with `feat(cinema): drama breathes: 3-8 s shots, cuts on a beat, a long one after short ones`.

### Task 7: The showcase, judged

**Files:**
- Modify: `tests/showcase_test.gd` (D37's mean ≤ 8; new D42)
- Test: the stills stage and `tools/record_showcase.sh`

- [ ] **Step 1: Write D42:** over Act I (the D4 run), at least one shot with cause `&"portrait"` during a conversation.
- [ ] **Step 2: Run showcase_test; fix what fails.**
- [ ] **Step 3: Stage the contact sheet** (`tests/visual/stage_showcase.tscn`, 1280x720) and look at it. Fix what is visibly wrong: a head cut off, a jumping portrait, blur in a wide shot.
- [ ] **Step 4: Record a night** with `tools/record_showcase.sh <scratchpad>/movie escape`.
- [ ] **Step 5: Run every suite; all green. Commit** with `test(showcase): Act I talks reach portraits; a recorded night`.
