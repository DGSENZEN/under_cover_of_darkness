# Showcase Cinematography Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the NPC showcase's one-framing-per-beat camera with a reusable, event-driven film director: Tarkovsky-style observation in Act I and Kurosawa-style drama from the knife on.

**Architecture:** A new `scripts/Cinema/` folder, which knows nothing of the showcase:
- `CineEvents`: a static event bus.
- `CineShot`: pure framing maths.
- `CineVantage`: places to watch from.
- `CineScreen`: the letterbox and the wipe.
- `CineOperator`: moves and lenses the `Camera3D`.
- `CineEditor`: the director, which chooses shots under each mode's rules.

The guards, the talk director, the gatherings and the intruder send events. The showcase hands the editor a scene intent per beat and keeps its free-fly and follow modes.

**Tech Stack:** Godot 4.5.1, GDScript. Headless test suites (`tests/*_test.tscn`, `==== RESULTS ====` then `PASS`/`FAIL` lines). Godot's Movie Maker and ffmpeg for the recording.

**Spec:** `docs/superpowers/specs/2026-09-27-showcase-cinematography-design.md`

## Global Constraints

- Godot binary: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`.
- Every suite runs as `Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/<suite>.tscn`. A suite is green only if every result line is PASS and there is no `SCRIPT ERROR`. After adding new assets, run `Godot --headless --import --path .` first.
- Work in the worktree `.claude/worktrees/npc-showcase` on branch `showcase-cinematography`.
- Nothing in `scripts/Cinema/` may name `scripts/Showcase`, the cast, or the showcase's beats.
- The camera runs on `TimeFx.real_time()` / `TimeFx.real_since()`, never on a frame's delta divided by the time scale.
- The show camera keeps `physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF` (showcase D22).
- Only `TimeFx` writes `Engine.time_scale`.
- Observe: takes of 15–45 s; dolly ≤ 0.4 m/s, pan ≤ 8°/s; long lens 18–28° vertical FOV from 12–30 m; roving takes about 40°. A talk over 20 s narrows the lens to 0.7× its width. Hold 3 s after a talk. Drift to an element after 60–90 s with no line in the last 8 s.
- Drama:
  - shots of 2–7 s; tracking ≤ 6 m/s, pan ≤ 90°/s; close lens 35–45°;
  - axial cut-in 3 cuts 0.6 s apart, lens 40° → 30° → 22°;
  - face-off: opponents ≤ 4 m apart, facing within 45°, no blow for ≥ 1 s;
  - slow motion 0.3× eased in 0.2 s, held 1.2 s, eased out 0.5 s, at most once in 8 s;
  - wipe 0.6 s; letterbox 2.39:1 eased in over 1.5 s.
- Both modes: no jump cut (same size within 30°, axial excepted); replace a shot whose subject stays hidden > 0.6 s; no cut before 1.5 s (axial excepted). Priorities: death > knife > blow > alert/spotted > line > gathering > idle.
- Depth of field: far blur starts 1.5 m behind the subject (lens ≤ 28°) or 3 m (medium); amount ≤ 0.12; near blur only on over-the-shoulder; a focus pull takes 0.4 s. Handheld ±0.3° and ±1 cm on drama close shots, ±0.05° in observe. Shake: +0.3 light, +0.5 heavy, +0.8 death, for a blow within 6 m of the subject; decays 1.5/s; shake = trauma² × 2.5° at most.
- No procedural audio, no new animation, no textures.com images in git (public repo).
- Match the codebase's voice: `##` doc comments in plain narrative ("he", "his"), tabs, typed GDScript, explicit types where a value comes from a Variant (`get()`, `weakref()`).

## Review Focus

1. A subject freed or knocked out in the middle of a shot (severed, the intruder despawned at the end) should give a new shot with no errors. Pinned in Task 8 (E8).
2. Releasing the camera in the middle of a slow-motion ramp or a wipe (a fly key, follow, R, an act jump) should put time back to the show's speed at once and clear the wipe. Pinned in Task 9 (E18) and Task 6 (S2).
3. A melee flood of events (several men swinging, many blows a second) should never cut faster than the 1.5 s floor, never shake past 2.5°, and slow down at most once in 8 s. Pinned in Task 9 (E15).
4. A window that isn't 16:9 (4:3, ultrawide) should keep the head on a third and the letterbox at 2.39:1. Pinned in Task 4 (F6) and Task 6 (S1).
5. The show paused (Space) should cut nothing while paused, and the free camera should still fly. Pinned in Task 8 (E19); D15 is kept.

---

### Task 1: Probe depth of field and the frame capture under the retro filter

**Files:**
- Create: `tests/visual/stage_cinema_probe.gd`, `tests/visual/stage_cinema_probe.tscn`

**Interfaces:**
- Produces: a ruling in the ledger. "DOF go" means Task 7 builds focus. "DOF no-go" means Task 7 sets `CineOperator.DEPTH_OF_FIELD := false`, and O6 checks that the camera has no attributes. It also rules whether the wipe capture includes the retro grid.

- [ ] **Step 1: Write the probe stage.**
  - Windowed; not a test. It loads `maps/npc_showcase.tscn` with `run_show = false`.
  - It places a `Camera3D` 2.2 m from Osric's head, 40° FOV, looking at it.
  - It saves `dof_off.png`, then sets `CameraAttributesPractical` (far blur on, far distance = focus + 1.5 m, transition 2.0, amount 0.12) and saves `dof_on.png`, each after 30 frames.
  - It saves `capture.png` from `get_viewport().get_texture().get_image()`.
  - It prints `[probe] fps off %.1f on %.1f` (the average of `Engine.get_frames_per_second()` over 120 frames each) and quits.
  - It takes `-- --out=<dir>`.

- [ ] **Step 2: Run it.**

Run: `Godot --fixed-fps 60 --resolution 1920x1080 --path . res://tests/visual/stage_cinema_probe.tscn -- --out=<scratchpad>/probe`
Expected: three PNGs and an `[probe]` line.

- [ ] **Step 3: Look at the three images and rule.**
  - DOF go if the background in `dof_on.png` is visibly softer than in `dof_off.png`, the pixel grid is intact, and fps on ≥ 60.
  - The capture counts as including the grid if `capture.png` shows the grid. If it doesn't, CineScreen's wipe layer goes below the Retro layer (layer 3) instead of above it.
  - Ledger both rulings.

- [ ] **Step 4: Commit.**

```bash
git add tests/visual/stage_cinema_probe.gd tests/visual/stage_cinema_probe.tscn
git commit -m "test(cinema): depth of field and frame capture under the retro filter"
```

### Task 2: The event bus and where events come from

**Files:**
- Create: `scripts/Cinema/CineEvents.gd`, `tests/cinema_test.gd`, `tests/cinema_test.tscn`
- Modify:
  - `scripts/AISystem/Guard.gd`: `speak`, `_utter`, `_set_state`, `take_hit` (each `struck_by.emit`), `die`, `knock_out`;
  - `scripts/AISystem/Talk/TalkDirector.gd` (`_say`);
  - `scripts/AISystem/Gathering.gd` (the three `_history.append(...)` sites where a gathering starts playing, and `_end`);
  - `scripts/Showcase/IntruderCombat.gd` (each `defended.emit`).

**Interfaces:**
- Produces:
  - `CineEvents.add_listener(listener: Object)`, `remove_listener(listener: Object)`, `emit(kind: StringName, data: Dictionary)` (calls `listener.cine_event(kind, data)` on each listener still valid; freed ones are dropped), and `clear()`.
  - Event data (every event also has `where: Vector3`):
    - `line`: `{speaker, listeners: Array, seconds: float, delivery: StringName, text: String}`;
    - `alert`: `{man, from: int, to: int}`;
    - `spotted`: `{man, target}`;
    - `blow`: `{attacker, victim, weight: &"light"|&"heavy", outcome: &"landed"|&"blocked"|&"parried"|&"killed"}`;
    - `death`: `{man, killer}`;
    - `knife`: `{attacker, victim}`;
    - `gathering`: `{kind, men: Array, state: &"started"|&"ended"}`.
  - `Guard.speak(text: String, delivery: StringName = &"", listeners: Array = [], seconds := -1.0)`. When `seconds < 0`, it is `TalkDirector.LINE_BASE + TalkDirector.LINE_PER_CHAR * text.length()`.
  - `Guard._struck(result: StringName, kind: StringName, damage: float, attacker: Node3D)` emits `struck_by` and the `blow` event: hit→landed, killed→killed, parried, blocked. Weight is heavy for kind `power`, `drop` or `backstab`, else light.
  - A backstab (`kind == &"backstab"`) emits `knife` before its `death`. `spotted` is emitted when `_set_state` enters COMBAT while `can_see_target`.
  - `IntruderCombat`'s defended sites emit `blow` with the intruder as victim, the guard as attacker, and outcome blocked or parried.

- [ ] **Step 1: Write the failing tests in `tests/cinema_test.gd`.**
  - Same frame as `tests/aliveness_test.gd`: `results`, `_check`, `_frames`, `_until`, `_fresh`, a floor `Props.block`.
  - An `Ears` inner class records events.
  - Guards come from `Guard.tscn`, with `TemperamentScript.rolling = false` and `GuardScript.bleeding_on = false`.

```gdscript
# C1 a guard's line: speaker, listeners given, a length, a delivery
a.speak("A line of some length.", &"whisper", [b])
_check("C1 ...", heard.any(func(e): return e.kind == &"line" and e.data.speaker == a and e.data.listeners == [b] and e.data.seconds > 1.0 and e.data.delivery == &"whisper"), ...)
# C2 a conversation's line names the others as listeners (a two-line test conversation, loaded as talk_test's _use does)
# C3 alert event on a state change (from/to); spotted on entering COMBAT seeing the target
# C4 take_hit quick -> blow light landed; power -> heavy; parried -> outcome parried; backstab -> knife then death
# C5 die(attacker) -> death with killer; knock_out -> death
# C6 a freed listener is skipped: no SCRIPT ERROR, the live one still hears
```

- [ ] **Step 2: Run the suite and see it fail.**

Run: `Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/cinema_test.tscn`
Expected: a parse error (`CineEvents` missing), or C1–C6 FAIL.

- [ ] **Step 3: Implement `CineEvents.gd` and the hooks as the Interfaces block says.**
  - `TalkDirector._say` passes `talk["members"]` minus the speaker, and the length it computes.
  - Gathering emits `started` with `g["members"]` where it appends to `_history`, and `ended` in `_end`.

- [ ] **Step 4: Run the suite; C1–C6 PASS. Then run `talk_test`, `routines_test`, `intruder_test`, `duel_test` and `life_test`, and expect them all green.**

- [ ] **Step 5: Commit.**

```bash
git add scripts/Cinema/CineEvents.gd tests/cinema_test.* scripts/AISystem/Guard.gd scripts/AISystem/Talk/TalkDirector.gd scripts/AISystem/Gathering.gd scripts/Showcase/IntruderCombat.gd
git commit -m "feat(cinema): an event bus, fed by lines, alerts, blows, deaths, the knife and gatherings"
```

### Task 3: Eased slow motion (`TimeFx.ramp`)

**Files:**
- Modify: `scripts/Visual/TimeFx.gd`
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Produces: `TimeFx.ramp(tree: SceneTree, id: StringName, scale: float, ease_in: float, hold: float, ease_out: float) -> void`.
  - It eases the request `id` from 1 to `scale` over `ease_in`, holds for `hold`, and eases back to 1 over `ease_out` (real seconds), then erases it.
  - It stacks as requests do: `Engine.time_scale = min(requests) × base`.
  - The same `id` restarts the ramp, and `clear()` ends it.
  - It is driven by a tween on the tree that ignores the time scale.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# R1 TimeFx.ramp(tree, &"cinema", 0.3, 0.2, 1.2, 0.5): at 0.5 s real, time_scale ~0.3 (±0.02); at 2.2 s, 1.0; is_active false
# R2 with set_base(0.5): during the hold 0.15; a hitstop(0.1) inside the hold gives 0.025, then 0.15 again
# R3 clear() in the middle of the ramp: time_scale == base at once, and stays there after the tween would have ended
```
Wait real seconds with `_frames(int(seconds * 60))` (physics frames are real seconds: `TimeFx.real_time`).

- [ ] **Step 2: Run the suite; R1–R3 FAIL (no `ramp`).**
- [ ] **Step 3: Implement `ramp`.**
- [ ] **Step 4: Run `cinema_test`, then `feel_test` and `duel_test` (both use TimeFx), and expect them green.**
- [ ] **Step 5: Commit** with `git commit -m "feat(time): eased slow motion (TimeFx.ramp)"`.

### Task 4: Framing (`CineShot`)

**Files:**
- Create: `scripts/Cinema/CineShot.gd`
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Produces:
  - `CineShot.frame(kind: StringName, men: Array, context: Dictionary) -> Dictionary` returns `{kind, size: &"wide"|&"medium"|&"close", position: Vector3, look: Vector3, fov: float, focus: float, near_blur: bool}`.
  - `context` keys (all optional):
    - `aspect: float` (default 16/9);
    - `side: Vector3`, a unit vector off the line between `men[0]` and `men[1]`, pointing to the camera's side;
    - `from: Vector3`, a vantage for observe, group, establishing and axial;
    - `step: int` (axial 0, 1, 2);
    - `target: Node3D`, for insert.
  - `CineShot.head_of(man: Node3D) -> Vector3`: the feet plus `HEAD_LYING` 0.35 m for sleep/lie_down/wake; `HEAD_KNEELING` 0.95 × size for kneel/plead_kneel/rise_knees/rummage/sit/sit_talk/sit_down/sneak/doze; else `HEAD_STANDING` 1.6 × size (`size` from `man._rig.size`, default 1).
  - `CineShot.facing(man: Node3D) -> Vector3`: flat velocity if above 0.5 m/s, else `-global_basis.z` flattened.
  - Kinds: `establishing`, `observe`, `roving`, `group`, `medium`, `close`, `over_shoulder`, `two`, `reaction`, `insert`, `track`, `axial`, `overhead`.
  - Lenses (vertical FOV): establishing 35; observe, group and track 18–28 (fitted to the subjects from `from`); roving, medium and two 40; close, over_shoulder and reaction 40; insert 32; axial 40/30/22; overhead 50.
  - Frame heights (for distance `d = h / (2 tan(fov/2))`): close 0.9 m, medium 1.6 m, wide 6 m.
  - Composition: turn the aim so the head lands at NDC x = ∓1/3, away from where he faces, with `tan(hfov/2) = aspect × tan(fov/2)`. Pitch it so the eyes land at NDC y = +1/3.

- [ ] **Step 1: Write the failing tests.** Frame into a `SubViewport` of the tested size holding a `Camera3D` set from the framing, and use `unproject_position`.

```gdscript
# F1 close on a standing man facing +X: head x within 0.04 w of w/3 or 2w/3, on the side away from his facing; head y within [0.22 h, 0.40 h]
# F2 look room: facing +X in view -> head in the left third; facing -X -> right third
# F3 lens per kind: observe/group/track fov in [18, 28]; close/over_shoulder/reaction in [35, 45]; medium/two/roving 40; establishing in [30, 40]; overhead 50
# F4 side of the line: two with context.side = S -> (position - centre).dot(S) > 0
# F5 axial steps 0,1,2 from one `from`: directions within 2 deg, distances decreasing, fov 40 -> 30 -> 22
# F6 aspect 4:3 (SubViewport 1440x1080): F1's head still within 0.04 w of a third
# F7 over_shoulder: speaker's head on a third, listener's head in frame, near_blur true
# F8 head_of: a man whose activity() is &"sleep" -> 0.35 m over his feet; &"sit" -> 0.95 x size
```

- [ ] **Step 2: Run; F1–F8 FAIL.**
- [ ] **Step 3: Implement `CineShot.gd`** (static functions only; no scene tree beyond the men's transforms and `activity()`).
- [ ] **Step 4: Run; F1–F8 PASS.**
- [ ] **Step 5: Commit** with `git commit -m "feat(cinema): shot framing on the thirds, lenses by kind, the line, axial steps"`.

### Task 5: Places to watch from (`CineVantage`)

**Files:**
- Create: `scripts/Cinema/CineVantage.gd`
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Consumes: `CineShot.head_of`.
- Produces: `CineVantage.best(tree: SceneTree, men: Array, lens: StringName, side: Vector3, space: PhysicsDirectSpaceState3D) -> Vector3` (`Vector3.INF` if none).
  - Candidates:
    - `Marker3D`s in group `cine_vantage` within 30 m, with optional metadata `lens` (&"long"/&"medium");
    - 16 bearings × distances [12, 18, 24] m (long) or [4, 6] m (medium), at heights 1.6 and 3.5 m.
  - A candidate must have a clear ray (mask 1) to every head, and be on `side` when `side != Vector3.ZERO`.
  - Score:
    - distance closeness to the ideal (long 18 m, medium 5 m);
    - +0.3 if a second ray, offset 0.8 m sideways, is blocked (foreground: watched from hiding);
    - +0.5 for a marker.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# V1 a marker behind a wall is never chosen (a clear sample is)
# V2 long lens with clear markers at 8, 18 and 40 m: the 18 m one
# V3 two clear markers at 18 m, one with a post 0.8 m off its sight line: that one
# V4 side given: the chosen point is on that side
# V5 a man boxed in by four walls, no markers: INF
```

- [ ] **Step 2: Run; V1–V5 FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; V1–V5 PASS.**
- [ ] **Step 5: Commit** with `git commit -m "feat(cinema): places to watch from: markers and samples, seen, far enough, half hidden"`.

### Task 6: The letterbox and the wipe (`CineScreen`)

**Files:**
- Create: `scripts/Cinema/CineScreen.gd`
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Produces: `CineScreen extends CanvasLayer`, at layer 6 (above Retro's 4 and below ShowOverlay's 10), or layer 3 for the wipe if Task 1 ruled the capture lacks the grid.
  - `letterbox(on: bool)` eases its bars over 1.5 s. `bar_height() -> float` gives the bar height now. `static bar_for(size: Vector2) -> float` gives `max((size.y - size.x / 2.39) / 2, 0)`.
  - `wipe(texture: Texture2D)` shows the old frame and slides a hard vertical edge across it over 0.6 s (a shader on a full-rect `TextureRect`). `wiping() -> bool`.
  - `clear()` ends a wipe at once and releases its texture.
  - `subtitle_band() -> Rect2` is the lower bar's rect while the bars show, else `Rect2()`.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# S1 bar_for(1920x1080) -> the band between the bars is 2.39:1 (+-0.01); bar_for(1280x960) likewise; letterbox(true): bar_height() reaches bar_for(viewport) by 1.6 s and is under half of it at 0.5 s
# S2 wipe(an ImageTexture): wiping() true, false by 0.7 s, and the rect's texture is null after; clear() in the middle ends it and releases the texture at once
# S3 subtitle_band() is empty before the letterbox and the lower bar's rect after
```

- [ ] **Step 2: Run; S1–S3 FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; S1–S3 PASS.**
- [ ] **Step 5: Commit** with `git commit -m "feat(cinema): the letterbox and the wipe"`.

### Task 7: The operator (`CineOperator`)

**Files:**
- Create: `scripts/Cinema/CineOperator.gd`
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Consumes: CineShot's framing dictionary; `CineScreen.wipe`.
- Produces: `CineOperator extends Node`.
  - `attach(camera: Camera3D, screen: CineScreen)` sets the camera's `physics_interpolation_mode` OFF.
  - `set_mode(mode: StringName)`: `&"observe"` or `&"drama"`, which sets the speed limits and handheld amount.
  - `show(framing: Dictionary, how: StringName)`, where `how` is `&"cut"`, `&"glide"`, `&"path"` (uses `framing.path: PackedVector3Array`) or `&"wipe"`.
  - `shake(amount: float)`; `trauma` (read-only).
  - `fov() -> float`, `focus_distance() -> float`, `moving() -> bool`.
  - `const DEPTH_OF_FIELD := true` (false if Task 1 ruled no-go).
  - It updates in `_process` on `TimeFx.real_since`.
  - Critically damped springs on position and look point, speed-clamped by mode (observe 0.4 m/s and 8°/s, drama 6 m/s and 90°/s).
  - A glide whose straight path sphere-casts (radius 0.3, mask 1) into a wall becomes a cut.
  - Paths are Catmull–Rom through the points.
  - The lens eases.
  - Focus uses a `CameraAttributesPractical` per the Global Constraints.
  - Handheld is 3 octaves of `FastNoiseLite` (drama close ±0.3° and ±1 cm; observe ±0.05°).
  - `wipe` captures `get_viewport().get_texture().get_image()` into an `ImageTexture` for the screen, then cuts. A null capture (headless) is a plain cut.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# O1 drama glide 5 m: distance to the goal never grows frame to frame; under 0.01 m by 3 s
# O2 observe glide 10 m: the fastest frame-to-frame speed <= 0.42 m/s
# O3 a glide whose way crosses a wall: the camera is at the goal on the next frame (a cut)
# O4 a path through 4 points: passes within 0.3 m of each, in order
# O5 fov 40 -> 28 within one shot: no frame changes it by more than 1 deg
# O6 (DOF go) focus_distance() within 0.1 m of camera-to-head after 0.5 s; blur amount <= 0.12; near blur only when framing.near_blur. (DOF no-go) camera.attributes == null
# O7 handheld: drama close, the rotation off the aim stays within 0.3 deg (no shake); observe within 0.05 deg
# O8 shake(0.8): the extra rotation never exceeds 2.5 deg; trauma < 0.01 by 0.6 s
# O9 attach(): physics_interpolation_mode OFF
```

- [ ] **Step 2: Run; O1–O9 FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run; O1–O9 PASS.**
- [ ] **Step 5: Commit** with `git commit -m "feat(cinema): the operator: springs, speed limits, paths, lens, focus, handheld, shake"`.

### Task 8: The editor, with observe mode (`CineEditor`)

**Files:**
- Create: `scripts/Cinema/CineEditor.gd`
- Test: `tests/cinema_test.gd`, with a light `Man` inner class: a `Node3D` with `velocity`, `eye_height`, `eye_position()` and `activity()`, plus `_knocked_out := false`.

**Interfaces:**
- Consumes: CineEvents (the editor is a listener, `cine_event(kind, data)`), `CineShot`, `CineVantage`, `CineOperator`, `CineScreen`.
- Produces: `CineEditor extends Node`.
  - `take_over(camera: Camera3D)` makes its own operator and screen as children; `release()` frees them, ends its `&"cinema"` ramp (`TimeFx` request) and clears the screen.
  - `scene(intent: Dictionary)`. The intent has `mode: &"observe"|&"drama"`, `subjects: Array | Callable` (a Callable is called once a second for the current men), optional `pin: {kind, subjects: Array | Callable, seconds}`, and optional `letterbox: bool`.
  - `signal shot_started(shot: Dictionary)`, where `shot = {kind, size, subjects, cause: StringName, how: StringName, at: float}`.
  - `mode() -> StringName`, `current() -> Dictionary`, `history() -> Array` (every shot with its `at` and `length`).
  - Its process mode is PAUSABLE (nothing is cut while the tree is paused).
  - An event counts if it names a subject or happens within 12 m of one.
  - Observe rules: Global Constraints and spec 5.1 and 5.3.
    - Takes are roving by default.
    - The next interest is the latest event among the subjects. It is reached by a `path` move within 12 m with a clear view, else a cut, and only after 15 s. A forced new take comes at 45 s.
    - No cut while a `line` among the subjects runs (visibility replacement excepted).
    - The lens narrows to 0.7× over a talk longer than 20 s. Hold 3 s after the last line.
    - An `insert` on the nearest node of groups `fires`, `torches` or `atmosphere` after 60–90 s idle (no line in 8 s, no event).
    - No subjects: `establishing` from the best vantage over the last known place (the world origin if none).
    - Visibility: a ray to the subject's head; hidden more than 0.6 s means a new shot.

- [ ] **Step 1: Write the failing tests** (observe, on a stage with a wall, a `fires` node and 2–3 `Man`s).

```gdscript
# E1 one still subject, no events, 200 s: >= 3 shots, each (but the last) 15-45 s long
# E2 a line of 4 s every 6 s among the subjects: no shot_started while a line runs
# E3 a talk of 25 s: the lens at its end <= 0.72 x the lens at its start
# E4 after the last line ends, the next shot starts >= 3 s later
# E5 95 s with no event: a shot of kind insert on the fire
# E6 a wall moved between camera and subject: a new shot within 1.0 s (cause &"hidden")
# E7 a pin (close, 10 s) under a flood of lines: the kind stays close for 10 s
# E8 the subject freed in the middle of a shot, then all subjects gone: a new shot, then establishing; no SCRIPT ERROR
# E19 the tree paused 10 s: no shot_started while paused; shots resume after
```

- [ ] **Step 2: Run; FAIL.**
- [ ] **Step 3: Implement the editor core and observe rules.**
- [ ] **Step 4: Run; E1–E8 and E19 PASS; earlier checks still PASS.**
- [ ] **Step 5: Commit** with `git commit -m "feat(cinema): the editor: scene intents, pins, visibility, and observe (long takes, lingering, the elements)"`.

### Task 9: Drama mode

**Files:**
- Modify: `scripts/Cinema/CineEditor.gd`
- Test: `tests/cinema_test.gd`

**Interfaces:**
- Consumes: Task 8's editor; `TimeFx.ramp`; `CineOperator.shake`; `CineScreen.letterbox`.
- Produces: the drama rules in spec 5.2.
  - Shots of 2–7 s (a random length each); size changes each cut.
  - The line of the two principal subjects is kept across a confrontation's cuts; the camera crosses only through a shot marked `neutral` in `shot.cause`.
  - `over_shoulder` on the speaker of a `line`, and `reaction` on a listener at a `line` with delivery `shout` or from a grieving man.
  - An `axial` triple on an `alert` whose `to` is SEARCHING (3) or COMBAT (4), for a subject.
  - A `face-off` shot: `observe` kind side-on with a long lens, the camera still, held until a `blow` among them, which cuts to `medium` on the attacker.
  - `group` and `track` while three or more subjects are running (flat speed > 2 m/s).
  - A `ramp(&"cinema", 0.3, 0.2, 1.2, 0.5)` on `knife`, a `death`, or a `blow` with outcome `parried` among the subjects, at most once in 8 s.
  - A wipe (`how = &"wipe"`) when a drama scene's subjects share nobody with the last scene's.
  - Letterbox on when a drama intent arrives. It stays on through later observe intents unless `letterbox: false`, or until `release()`.
  - Shake per the Global Constraints for blows within 6 m of the subject.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# E9  drama with a line every 3 s and blows every 2 s for 40 s: every shot 1.5-7.5 s (axial parts excepted), the median in 2-7
# E10 two men trading lines for 30 s: every shot's camera on one side of their line, unless its cause is &"neutral"
# E11 no two consecutive shots of one size within 30 deg (axial excepted)
# E12 alert to 3 on a subject: the next three shots are axial steps 0,1,2, 0.6 s (+-0.1) apart, one axis (within 5 deg), lens narrowing
# E13 two opponents 3 m apart facing, no blow 1 s: a still side-on long-lens shot (fov <= 28, the camera moving < 0.05 m/s); a blow 3 s in -> the next shot medium on the attacker within 0.3 s
# E14 knife -> time_scale <= 0.32 x base by 0.3 s, base again by 2.1 s; a death 3 s later: no ramp; a death 9 s later: a ramp
# E15 30 blows in 2 s: no two cuts under 1.5 s apart, the shake never over 2.5 deg, one ramp at most
# E16 a drama intent whose subjects share nobody with the last: the shot's how is &"wipe"
# E17 a drama intent: bar_height() reaches the 2.39 bar by 1.6 s; a later observe intent leaves it up; letterbox: false takes it down
# E18 release() in the middle of a ramp and a wipe: time_scale == base at once, the screen cleared
# E20 a line and a death among the subjects in one frame (the shot 2 s old): the next shot's cause is &"death"
```

- [ ] **Step 2: Run; FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole `cinema_test`; all PASS.**
- [ ] **Step 5: Commit** with `git commit -m "feat(cinema): drama: short shots, the line, axial cut-ins, face-offs, slow motion, wipes, the letterbox"`.

### Task 10: The showcase switched over

**Files:**
- Modify:
  - `scripts/Showcase/ShowCamera.gd`: DIRECTOR hands the camera to a `CineEditor`; the old `_aim`, `_frame_*`, `_clear_view` and `_recent` code goes; FREE and FOLLOW and their keys stay; `want(intent)` passes it on.
  - `scripts/Showcase/ShowDirector.gd`: `beat_started(beat_name, scene)` carries `beat.get("scene", {})`.
  - `scripts/Showcase/ShowNight.gd`: `_shot` becomes `_scene(mode, names, pin := {})`; beats use `"scene"`; new subject `"@hunt"` (the men searching or in combat).
  - `maps/npc_showcase.gd`: about 8 `cine_vantage` markers, and the camera wiring.
  - `scripts/Showcase/ShowOverlay.gd`: subtitles in `subtitle_band()` while it shows.
  - `tests/showcase_test.gd`, `tests/visual/stage_showcase.gd` (the signal parameter name only).

**Interfaces:**
- Consumes: `CineEditor.take_over/release/scene/shot_started/history`, `CineScreen.subtitle_band`.
- Produces: the beats' intents:
  - Act I, observe: `establish` (pin roving on Mirelle, Osric, Piers and Col, 8 s), `fire_talk` (@talk), `dice` (@gathering:dice), `round` (Mirelle), `fire_fed` (@gathering:fire), `story` (@gathering:story), `watch_change` (Jory, Hendrik), `wall` (Wat), `lookout` (Aldous).
  - Act II:
    - `drop_in` and `his_moment`: observe;
    - `the_knife`: drama, pin `track` on intruder and Jory for 4 s;
    - `the_witness` (Ned) and `grief` (Osric): drama.
  - Acts III and IV, drama: `the_cry` (Ned), `lost_him` (intruder), `the_hunt` (@hunt), `found`, `trade`, `turtle`, `parry`, `focus`, `press` (intruder, @hunt).
  - Act V:
    - `overwhelmed`, `break_them`, `spare`, `break_off`: drama;
    - the codas `silence`, `walk_out`, `gone`: observe.
  - Vantage markers at: behind the woodpile, the wall-walk (2), through the gate bars, the NE tower, the shed doorway, behind the store's crates, the alley mouth.

- [ ] **Step 1: Update and add the failing showcase checks.**

```gdscript
# D14 (updated) want({"mode": &"observe", "subjects": [osric], "pin": {"kind": &"close", "subjects": [osric], "seconds": 30.0}}): after 300 frames his head within 0.08 w of a third, y in [0.2 h, 0.45 h], under 4 m off
# D36 Act I (the D4 run): the editor's mode observe throughout; the mean length of Act I's shots >= 15 s
# D37 the run from the knife on: the letterbox up (bar >= 0.9 x its 2.39 height) and the mean shot length <= 7 s
# D38 every shot_started with subjects: a clear ray from the camera to its first subject's head when it starts (at most 1 in 20 not)
# D39 over the runs: events seen of kinds line, gathering (started and ended), alert, spotted, blow (landed, and blocked or parried), death, knife
```
D13, D15, D16, D21 and D22 are kept as they are.

- [ ] **Step 2: Run `showcase_test`; the new checks FAIL.**
- [ ] **Step 3: Implement the switch-over as the Files and Interfaces blocks say.**
- [ ] **Step 4: Run `showcase_test` (all PASS), then `intruder_test` and `sound_test`.**
- [ ] **Step 5: Commit** with `git commit -m "feat(showcase): the night filmed by the Cinema editor: observed, then dramatic"`.

### Task 11: The contact sheet, the recording, the frame rate

**Files:**
- Modify:
  - `tests/visual/stage_showcase.gd`: a still 0.6 s into each shot that is still current, labelled `Act beat, kind (cause)`; the sheet at 8 across, 240×135 each;
  - `maps/npc_showcase.gd`: `--fps-report=N` now measures with the show running (the editor's camera, depth of field on), from the start of Act I.
- Create: `tools/record_showcase.sh`.

**Interfaces:**
- Consumes: `CineEditor.shot_started`.
- Produces: `tools/record_showcase.sh <out_dir> [ending]`.
  1. It checks for 20 GB free on `out_dir`'s disk.
  2. It runs `Godot --path . --write-movie <out>/showcase_<ending>.avi --fixed-fps 60 --resolution 1920x1080 res://maps/npc_showcase.tscn -- --auto --ending=<ending> --quit-at-end`.
  3. It runs `ffmpeg -y -i ...avi -c:v libx264 -crf 20 -pix_fmt yuv420p -c:a aac <out>/showcase_<ending>.mp4`.
  4. It removes the .avi. The default ending is escape.

- [ ] **Step 1: Run the frame-rate report.** `Godot --resolution 1920x1080 --path . res://maps/npc_showcase.tscn -- --fps-report=30` should print an average of 60 or above. If not, ledger it and lower the DOF blur amount or cap the handheld noise evaluation until it passes.
- [ ] **Step 2: Run the stage** (`Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_showcase.tscn -- --out=<scratchpad>/sheet`). Look at `sheet.png` and fix whatever is visibly wrong: a head cut off, a wall in the frame, a dead-centre subject.
- [ ] **Step 3: Record a night** with `tools/record_showcase.sh <scratchpad>/movie escape`. Expected: an .mp4 of about the night's length.
- [ ] **Step 4: Run every suite** (the 32 existing, plus `cinema_test`). All green.
- [ ] **Step 5: Commit** with `git commit -m "feat(showcase): a contact sheet of every shot, a recorded night, frame rate with depth of field"`.
