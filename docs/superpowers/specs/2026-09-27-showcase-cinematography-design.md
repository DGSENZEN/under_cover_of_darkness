# Showcase Cinematography: Design

**Date:** 2026-09-27
**Status:** design approved in conversation; this document awaits the user's review.
**Sub-project 2 of 4** of the showcase polish (1 life and voice: done; 3 sound; 4 environment art).

## 1. Goal

The user, watching the NPC showcase: "camera shots are very boring".

Today the showcase camera (`scripts/Showcase/ShowCamera.gd`) takes one framing per beat of the night and holds it for the whole beat, often 20 to 60 seconds. The framings are a crane, a close-up, a follow shot behind a man, a two-shot and a reveal. It glides between them on one floaty ease. The lens never changes, nothing is out of focus, and the subject always sits dead centre. A conversation gets one two-shot, with no cutting to whoever speaks and no reactions. A fight gets the same side-on two-shot, with nothing to land a blow or a death.

This sub-project replaces that with directed camera work:

- **A style that turns with the night.** Act I is watched from hiding, like a documentary. From the murder on it is shot close and cut hard.
- **Two filmmakers to learn from, as the user asked.** Tarkovsky for the watching: long takes, slow movement, time you can feel, the elements. Kurosawa for the drama: long lenses, figures staged in depth, cuts straight in on one line, stillness before violence, slow-motion deaths, wipes.
- **A reusable system.** The showcase uses it first. The game can use it later (a scripted scene in the canal mission, a "caught" camera, a replay).

## 2. Decisions

| Question | Decision |
|---|---|
| Style | **The mix.** *Observe* mode (Tarkovsky) until the knife in Act II; *drama* mode (Kurosawa) from the knife to the end of the night; *observe* again for the ending's last beat, a coda (the letterbox stays). |
| Showcase only, or reusable | **Reusable.** A new `scripts/Cinema/` folder knows nothing of the showcase's story. The showcase talks to it through a scene intent and events. |
| Film techniques | **Depth of field, handheld sway, lens changes (long lens, push-ins), slow motion on key moments; letterbox bars from the moment the night turns.** No speed-ramp zoom punches. |
| How shots are chosen | **An automatic editor driven by events** (approach A). Events: a line spoken, an alert, a man spotting the intruder, a blow, a death, the knife, a gathering. The editor applies each mode's editing rules. A beat can pin an exact shot when a moment must land a certain way. |
| How the camera moves | **Critically damped springs** with speed limits per mode, planned paths for long takes, and a cut wherever a move would pass through a wall. |

## 3. Scope

**In scope:** the `scripts/Cinema/` system (shots, hidden watching spots, the operator, the editor, events); `TimeFx` eased slow motion; the letterbox and the wipe; event hooks in the guards, the talk director, the gatherings and the intruder; the showcase switched over (ShowCamera's director mode, ShowNight's beats as scene intents, about 8 marked spots in the map, subtitles in the letterbox); tests; a contact sheet of every shot; a Movie Maker recording of a whole night.

**Out of scope:** using the system in gameplay levels (the API is ready, nothing uses it yet); new weather (fog and rain belong to sub-project 4); sound changes (sub-project 3; the existing slow-motion audio is kept as is); new animation.

## 4. The system (`scripts/Cinema/`)

### 4.1 Parts

- **`CineEvents.gd`**: a static event bus in the manner of `SoundBus`: `add_listener`, `remove_listener`, `emit(kind: StringName, data: Dictionary)`. Every event carries `where: Vector3` and the men it concerns.
- **`CineShot.gd`**: pure framing maths. `frame(kind, subjects, context) -> {position, look, fov, focus, size}`, where `size` is wide, medium or close (for the editing rules). No scene tree needed beyond the men's transforms.
- **`CineVantage.gd`**: places to watch from. Level markers in the group `cine_vantage` (a `Marker3D`, optionally with metadata `lens: long|medium`), plus candidates sampled on rings round the subject when no marker serves. Scored by line of sight to the subject's head, distance right for the lens, the side of the line, and a little foreground between (partly in the way: watched from hiding).
- **`CineOperator.gd`**: owns the `Camera3D`. It moves it to a shot's framing with damped springs, plans long-take paths, and runs the handheld layer, shake, lens changes, focus, cuts and wipes. Runs on `TimeFx.real_time()` (counted in physics ticks: steady under slow motion and in Movie Maker).
- **`CineScreen.gd`**: a `CanvasLayer` with the letterbox bars and the wipe.
- **`CineEditor.gd`**: the director. It holds the scene intent, listens to `CineEvents`, chooses shots under the mode's rules, hands them to the operator (cut, glide, roving path or wipe), and asks `TimeFx` for slow motion.

### 4.2 The API

- `CineEditor.scene(intent: Dictionary)`, where `intent` has:
  - `mode`: `observe` or `drama`;
  - `subjects`: `Array[Node3D]`, the men who matter;
  - `pin` (optional): `{kind, subjects, seconds}`, one exact shot held for its seconds, overriding the rules.
- `CineEditor.take_over(camera: Camera3D)` and `release()`.
- The editor weighs events that involve the scene's subjects, or anyone within 12 m of one.

### 4.3 Shot types (`CineShot`)

| Kind | Size | Lens (vertical FOV) | Framing |
|---|---|---|---|
| establishing | wide | 30–40° | the whole place, high, from a vantage |
| observe | wide or medium | 18–28° (long) | from a hidden vantage 12–30 m off, the subject on a third |
| roving | medium | about 40° | a long take whose path drifts between the subjects |
| group | wide | 18–28° | several men staged at different depths, the nearest on a third |
| medium | medium | about 40° | waist up, a third, room on the side he faces |
| close | close | 35–45° | head and shoulders, the eyes on the upper third |
| over_shoulder | close | 35–45° | over the listener's shoulder onto the speaker; the shoulder soft (near blur) |
| two | medium | about 40° | both men, from the side of the line the camera is on |
| reaction | close | 35–45° | the listener's face as a line lands |
| insert | close | 30–40° | a detail: the fire, a torch flame, a hand on a hilt, breath |
| track | medium | 18–28° | sideways, alongside a running man, long lens |
| axial | wide, then medium, then close | a narrower lens each cut | three cuts straight in along one line |
| overhead | wide | about 50° | straight down from high: the last resort |

Composition: the head sits on a third, never dead centre; space is left on the side a man faces or moves toward; the eyes stay in the upper third.

## 5. The grammar of the two modes

### 5.1 Observe (Tarkovsky)

- **Takes of 15 to 45 s.** The default is a roving long take: the camera dollies at up to 0.4 m/s and pans at up to 8°/s from one point of interest to the next instead of cutting. It cuts only when the next interest is more than 12 m off or behind a wall, and only after the take's first 15 s.
- **Long lenses** (18–28°) from hidden vantages 12–30 m off. Roving takes use about 40°.
- **Talk in one take.** No cutting back and forth. The camera holds the group, the look point weighted toward whoever is speaking, and over a talk longer than 20 s the lens narrows to 0.7× its width.
- **It lingers.** When a talk ends it holds 3 s more on the listener or the empty place. After 60–90 s with no line spoken within the last 8 s and no event, it drifts to an element: embers above the fire, a torch flame bending in the wind, leaves skittering, breath on the air, crows on the wall (from the `fires`, `torches` and `atmosphere` groups).

### 5.2 Drama (Kurosawa)

- **Shots of 2 to 7 s, cut on action.** Medium, close and over-the-shoulder alternate, and the size changes at each cut.
- **The line.** In a confrontation the camera stays on one side of the line between the two principal men. It crosses only through a neutral shot (head-on to the line) or a continuous move.
- **Confrontations:** over-the-shoulder on the speaker, and a reaction close-up on the listener as a line with weight lands (a shout, grief, a threat).
- **Axial cut-in** on a realisation (a man's alert jumping to searching or combat, the witness, grief): wide, medium, close, 0.6 s apart, straight in along one line.
- **Stillness, then violence.** A face-off (two opponents within 4 m, facing each other within 45°, no blow for 1 s or more) is held on a still, side-on, long-lens shot. The first blow cuts to medium on the striker.
- **The hunt:** long-lens group shots with men at several depths, and sideways tracking alongside the runners at up to 6 m/s.
- **Slow motion** on the knife, a staggering parry, a killing blow or a fatal arrow: eased down to 0.3× over 0.2 s, held 1.2 s (real time), eased back over 0.5 s; at most once in 8 s.
- **A wipe** (a hard vertical edge across the frame, 0.6 s) between scenes: a new act, or a beat whose subjects share nobody with the last beat's.
- **The letterbox** eases to 2.39:1 over 1.5 s when drama begins, and stays to the end.
- **Handheld** on close shots; blows add shake.

### 5.3 Rules for both

- **No jump cuts:** never cut to a shot of the same size from within 30° of the same angle, except the axial cut-in.
- **Visibility:** never choose a shot whose subject's head is hidden (a ray from the camera to the head). A shot whose subject stays hidden more than 0.6 s is replaced, even inside an observe take's first 15 s. In observe the replacement is a move if a clear path serves, else a cut.
- **Priorities:** death, then the knife, a blow, an alert or a spotting, a line, a gathering, and idle time last.
- **Pins** override everything for their seconds.
- **The operator's minimum:** a shot is never cut before 1.5 s, not even by a death (the axial cut-in's own cuts excepted).

## 6. How the camera moves and looks (`CineOperator`)

- **Springs.** Position and look point each follow a critically damped spring (no overshoot). Speed limits: observe 0.4 m/s and 8°/s; drama 6 m/s and 90°/s.
- **Paths.** A roving take plans a smooth path (Catmull–Rom through 3–5 points) checked for a clear view of its subject at each sample. A move whose straight path hits a wall (a sphere cast of 0.3 m) becomes a cut.
- **Lens.** Each shot sets its vertical FOV; changes within a shot (push-ins) ease over seconds.
- **Focus.** `CameraAttributesPractical` on the camera: focus at the subject's head. Far blur begins behind the subject, 1.5 m for a long lens (28° or narrower) and 3 m for a medium one. The blur amount is at most 0.12, so the pixel grid still reads. Near blur only for over-the-shoulder shots. A change of subject within a shot pulls focus over 0.4 s.
- **Handheld.** Three octaves of slow noise (`FastNoiseLite`) on rotation (±0.3°) and position (±1 cm) on drama close shots; in observe, ±0.05°.
- **Shake.** A trauma value: a blow within 6 m of the shot's subject adds 0.3 (light), 0.5 (heavy) or 0.8 (a death). It decays 1.5 a second; the shake is trauma² × 2.5° at most.
- **Slow motion.** `TimeFx` gains `ramp(tree, id, scale, ease_in, hold, ease_out)`: an eased request that stacks with the show's own speed (`TimeFx.base`) and hit-stop (the slowest wins, as now).
- **Letterbox and subtitles.** `CineScreen` eases its bars to 2.39:1 over 1.5 s. `ShowOverlay` places the subtitles in the lower bar while it shows.
- **Wipe.** The last frame is captured to a texture and a hard vertical edge slides across it over 0.6 s, uncovering the new shot. The capture is freed at the end.

## 7. Events, and the showcase

### 7.1 Where events come from

| Event | Data | Sent from |
|---|---|---|
| `line` | speaker, listeners, seconds, delivery (whisper, talk, shout), text | where lines are voiced (`Guard.speak`/bark, the talk director) |
| `alert` | man, from, to | the guard's existing alert signal |
| `spotted` | man, target | a guard first seeing the intruder |
| `blow` | attacker, victim, weight (light, heavy), outcome (landed, blocked, parried) | the guards' and the intruder's combat |
| `death` | man, killer | a death or knockout |
| `knife` | attacker, victim | the intruder's backstab |
| `gathering` | kind, men, started or ended | `Gathering.gd` |

The face-off is not sent: the editor reads it from the fight (5.2).

### 7.2 The showcase

- **`ShowCamera`** keeps free-fly, follow, and C back to the director. Its director mode hands the camera to `CineEditor`; its own shot code goes.
- **`ShowNight`**: each beat's `shot` becomes a `scene` intent. Act I beats are observe scenes with their subjects (the fire talk's speakers, the dice players, Mirelle on her round, Wat on the wall, Aldous on the tower). `establish` pins a roving take across the yard. From `drop_in` to `the_knife` the intruder is watched from hiding, in observe. `the_knife` turns the night to drama: letterbox in, a pinned side-on long-lens shot, slow motion on the blow. From there events drive the coverage. The ending's last beat returns to observe, as a coda.
- **The map** gains about 8 `cine_vantage` markers: behind the woodpile, the wall-walk (two), through the gate bars, the NE tower, the shed doorway, behind the store's crates, the alley mouth.
- **`ShowOverlay`**: subtitles in the letterbox; name cards and marks as now.

## 8. Testing and review

### 8.1 Headless checks

A new `tests/cinema_test` suite on a small stage of its own, driven by real guards and synthetic events:

- **Framing:** the head on a third, room on the side he faces, the lens right for the kind, the camera on the chosen side of the line. The tests project with an explicit 16:9 aspect (the headless viewport is 64×64).
- **Vantages:** a blocked one is rejected; observe prefers a far spot with a little foreground.
- **Operator:** the springs settle without overshoot; the observe dolly stays within 0.4 m/s; a move through a wall is a cut; handheld and shake stay within bounds and shake decays; focus follows the subject; a push-in eases; the letterbox reaches 2.39:1; a wipe finishes and frees its capture.
- **Editor:**
  - observe takes last 15–45 s, and no cut falls inside a line;
  - drama shots last 2–7 s and hold the line across a confrontation's cuts;
  - no jump cuts;
  - an axial cut-in on a realisation; a face-off held still until the first blow;
  - slow motion at most once in 8 s, and time back to the show's speed after;
  - a subject hidden more than 0.6 s gets a new shot;
  - a pin overrides the rules.
- **TimeFx:** `ramp` eases down and back, and stacks with `base` and hit-stop.

`tests/showcase_test`, updated. D14 now asks for the head on a third; D13, D15, D16, D21 and D22 are kept. New checks:

- Act I's shots average 15 s or more.
- From the knife on, the letterbox shows and shots average 7 s or less.
- Every shot's subject is visible as it begins.

All existing suites stay green, run as before (`--headless --fixed-fps 60 --quit-after 3000000`).

### 8.2 By eye

- **A contact sheet:** the first frame of every shot in a night, labelled with its kind and the event that caused it (the stills stage, `tests/visual/stage_showcase`, extended).
- **A recording** of a whole night with Movie Maker (`--write-movie`, 1920×1080, 60 fps, `--auto --quit-at-end`), converted with ffmpeg to an .mp4 for the user.
- **Frame rate:** the showcase's `--fps-report` average stays at 60 or above at 1920×1080 on this Mac with depth of field on.
- **A final review** of the whole branch by a fresh reviewer.

## 9. Risks

- **Depth of field under the retro pixel filter.** It may smear badly or cost too much. The plan's first task tries it on the showcase before anything is built on it. If it fails, focus effects are dropped and every other part still stands.
- **The wipe's frame capture under the retro filter's scaling.** Checked in the same first task.
- **Emergent fights.** The editor never assumes who wins. Pins are kept to the moments the director already stages (the knife).
