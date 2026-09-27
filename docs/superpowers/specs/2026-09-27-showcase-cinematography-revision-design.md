# Showcase Cinematography Revision: Design

**Date:** 2026-09-27
**Status:** design approved in conversation; this document awaits the user's review.
**Revises:** `docs/superpowers/specs/2026-09-27-showcase-cinematography-design.md` (the Cinema camera, merged at 26f24b8). Where the two disagree, this document wins.
**Order:** the first of three sub-projects the user approved. After it come the environment (the yard rebuilt in Blender: sky, moon, foliage, detail and hiding places) and the night's pacing (the murder, the grief, a hunt the intruder can survive).

## 1. Goal

Having watched the recorded night, the user said:

> the FOV is a little bit sketchy in certain parts, the blur gets too distracting, the camera jumps around the character that is talking too much, so there is no real focus. the slow, building up shots are good, but there are no real good cuts, they're too stark. we need a rhythm between shots, have some real portrait conversations like in movies for the cutscenes

Asked what "too stark" meant, they chose both: softer transitions *and* cuts that land on something. The slow build-up takes stay as they are.

## 2. Decisions

| Question | Decision |
|---|---|
| Lens | A range of 26–40° vertical everywhere. Long 26–32° (watching, group, track, face-off); normal 40°; portraits 32° for both men; the axial cut-in 40 → 34 → 28. A cut sets the lens at once; a glide keeps it; the only change within a shot is a slow push-in, to 0.8× over a talk. |
| Focus blur | None on wide, medium, watching, group or establishing shots. On portraits and close shots: amount 0.04, far blur beginning 4 m behind the man. Over a shoulder, the near blur only light. |
| Stillness | No handheld sway in conversations or watching shots. Drama close shots in a fight keep ±0.15°. Shake from blows is unchanged. |
| Coverage | Fixed setups: one remembered position and lens per man per shot size in a scene, returned to on every cut back to him. |
| Conversations | They build, then go to portraits. Act I: the slow take, then from the third line matched portrait singles. Drama: a held two-shot, then portraits from the second line. |
| Transitions | Act I's takes are joined by 1.2 s dissolves; acts change through black; the wipe stays for a drama scene of other men. |
| Rhythm | Drama shots of 3–8 s. A due cut waits up to 1.5 s to land on a line, a blow or a man falling. After two short shots comes a long one. |

## 3. Lens, focus and stillness

- **CineShot lenses:**
  - `LONG` becomes 26–32°; observe, group and track fit within it.
  - `AXIAL` becomes [40, 34, 28].
  - A new `PORTRAIT` lens is 32°.
  - Close and medium stay at 40°.
- **CineOperator:**
  - On a cut, the lens is set at once (as now).
  - On a glide or a path, the lens holds at the shot's lens. It is eased only when the shot itself asks for a new one (the push-in).
- **The push-in:** `PUSH_TO` becomes 0.8, still over 20 s.
- **Depth of field (CineOperator):**
  - Focus blur is on only for framings with `size` "close" or kind "portrait".
  - Amount 0.04; far blur begins 4 m behind the subject.
  - Near blur, over a shoulder only: amount unchanged, beginning 1.0 m from the camera.
  - Every other framing turns far and near blur off.
- **Handheld (CineOperator.MODES):**
  - Observe: 0.
  - Drama: close shots ±0.15° and 0.5 cm; everything else 0.
  - Portrait framings: 0 in either mode.

## 4. Coverage

### 4.1 Setups

- `CineEditor` keeps, for the current scene, a setup per man per kind: `{position, fov, side, made_at_head}`.
- A shot of that man and kind reuses the setup, re-aimed at his head now, if all of these hold:
  - he is within 1.5 m of `made_at_head`;
  - the setup still sees him;
  - it is still clear.
- Otherwise a new setup is made, the only time the angle search (turns) runs, and remembered.
- Setups are forgotten when a new scene begins.

### 4.2 Portraits

- A new CineShot kind, `portrait`: chest up (frame height 1.1 m), lens 32°, the camera at his eye height.
- The camera stands three-quarters round from the other man's direction: 30° off the line from him toward the other man, on the scene's side of the line.
- The other man's portrait is the mirror of it.
- Composition uses the direction to the other man as "facing", so each man sits on the third facing the other: the eyeline match.
- It takes `context.toward` (the other man's head).

### 4.3 A conversation

- **What counts:** a talk is lines between two or more of the scene's subjects (a line whose speaker and a listener are both subjects). Lines within `TALK_GAP` (3 s) of each other are one talk.
- **Build-up:**
  - Observe: the existing take, pushing in.
  - Drama: a two-shot of the speaker and the first listener, held until the talk's second line.
- **Portraits:**
  - They begin with the talk's third line (observe) or second line (drama).
  - When a line starts from a speaker other than the man in the current portrait, the cut to his portrait comes 0.3 s after the line began.
  - A man who speaks again keeps his portrait.
  - The observe rules (15–45 s takes, no cut inside a line) give way to the talk while portraits are on.
- **Reactions:**
  - After a line that lands (delivery "shout", or a grieving speaker), the listener's portrait is cut to as the line ends.
  - At most once in 8 s.
- **Re-establishing:** every fourth change of speaker, or when a third man speaks, the talk goes back to a two-shot (or a group shot for three or more), held for the next line, then portraits again.
- **Stillness:** portraits are still. The operator holds position and aim, with no drift or sway; the aim follows the man's head only if it moves more than 0.3 m.
- **The end:** the talk ends `TALK_GAP` after its last line. Observe then lingers (as now) and returns to its takes; drama returns to its coverage.

### 4.4 Outside conversations

Drama coverage keeps its size changes, the 180° line and its event cuts, but draws on the setups (4.1) instead of a new angle each cut.

## 5. Rhythm and transitions

- **CineScreen:**
  - `dissolve(texture)`: the held frame fades out over 1.2 s.
  - `fade_through(seconds)`: to black over 0.5 s, held until the next shot, then up over 0.5 s.
  - `clear()` ends either.
- **CineOperator:** new `how` values "dissolve" and "fade" (headless: plain cuts, as the wipe is).
- **CineEditor:**
  - In observe, a new take that is not a drift is taken `dissolve`.
  - A scene intent with `transition: "fade"` opens through black.
  - Drama scene changes keep the wipe; drama cuts stay cuts.
- **The showcase:** the first scene of each act carries `transition: "fade"` (ShowCamera marks the next intent after the director's `act_started`).
- **Drama rhythm:**
  - `SHOT` becomes 3–8 s.
  - A cut due by the shot's length waits up to 1.5 s for a beat (a line starting, a blow, a death), then cuts on it; if none comes, it cuts at the end of the wait.
  - After two shots under 4 s, the next is planned at 6–8 s.
  - A death, the knife, and an alert to searching or fighting still cut at once (after the 1.5 s floor).
- **Eyelines:** consecutive shots of a pair come from the same side of their line (as now), and portraits (4.2) face each other.

## 6. Testing

### 6.1 The Cinema suite

Changed:
- F3 lens ranges (long 26–32, portrait 32);
- F5 axial lenses 40/34/28;
- O6 the blur amount and which framings blur;
- O7 handheld amounts;
- E3 the push-in to 0.8×;
- E9 drama lengths of 3–8 s.

New checks:
- a portrait framing (eye height, 32°, facing the other man on a third, the mirror of the other's);
- a cut back to a man returns to the same setup (within 0.1 m and the same lens), and a man who moved 2 m gets a new one;
- a drama talk: a two-shot until the second line, then portraits, each cut 0.3 s (±0.1) after the new speaker's line began, and none while the same man speaks again;
- an observe talk reaches portraits by the third line;
- a reaction only on a landing line, once in 8 s;
- re-establishing on the fourth change of speaker;
- portraits hold still (the camera moves under 0.01 m and turns under 0.1° while he stands);
- no blur on a wide or watching shot, 0.04 on a portrait;
- a dissolve fades over 1.2 s and lets its frame go;
- a fade goes to black and back up;
- a due drama cut lands on a beat within 1.5 s;
- after two short shots, a long one.

### 6.2 The showcase suite

- Act I's conversations reach portraits.
- Each act opens through black.
- D36–D40 still pass (D37's mean becomes 8 s or less).

### 6.3 Judging by eye

A new contact sheet and a recorded night (720p, `tools/record_showcase.sh`).

## 7. Out of scope

The environment and the night's pacing (the next two sub-projects), sound, and the minor findings deferred from the first cinematography review (except where this work replaces the code they concern).
