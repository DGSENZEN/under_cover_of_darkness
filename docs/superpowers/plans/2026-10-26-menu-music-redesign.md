# Menu Music Redesign (Piece 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the menu's layers follow its screens, and replace the stem-cut jingles with chord-fitted glockenspiel (hover) and piano (press) motifs that play dry through a delay and reverb bus.

**Architecture:**
- `MenuMusic` gets the new layer table and an `ARCHETYPE` state. Jingle voices move to a `MenuJingles` bus that `MenuMusic` creates, with `AudioEffectDelay` and `AudioEffectReverb`, sending to `Music`.
- The motifs are composed by `tools/compose_menu_parts.py` into `parts/menu_jingles.mid`: two tracks, one jingle per 2-bar slot.
- The tracks are rendered in Logic. The prep tool learns to cut jingles from a separate rendered file (`cut.file`).

**Tech Stack:** Godot 4.5.1 GDScript, Python 3 stdlib with numpy, Logic Pro (with the user).

**Spec:** `docs/superpowers/specs/2026-10-26-menu-music-redesign-design.md`

## Global Constraints

- **Layers by state:**

  | State | base | low | high | fx |
  |---|---|---|---|---|
  | ARRIVAL, BROWSING, CONTINUE, SETTINGS | 0 | 0 | out | out |
  | IDLE | −10 | out | out | out |
  | LORE | 0 | 0 | out | 0 |
  | ARCHETYPE | 0 | 0 | 0 | out |

  "out" is −80 dB.
- **Removed:** the activity-driven high layer, the lean, and ARRIVAL's 4-bar build. Gains still glide at 24 dB/s.
- **Bus `MenuJingles`:**
  - sends to `Music`, volume −6 dB
  - effect 0: `AudioEffectDelay`, tap1 at 577 ms (a dotted eighth at 78 bpm), level −12 dB, feedback on at 577 ms, level −10 dB, lowpass 3500 Hz, dry 1.0
  - effect 1: `AudioEffectReverb`, room_size 0.8, damping 0.6, wet 0.35, dry 1.0
- **Voices:** `HOVER_VOICES` = 3, `PRESS_VOICES` = 1 per word.
- **Motif slots:** one jingle per 2-bar slot (8 beats) on each track, in a fixed order: word 0–3, then chord Dm/Bb/Gm/Eb, then variant 0/1. That's 32 slots per track, 64 bars at 78 bpm.
- **Cut lengths:** hover 2 beats, press 4 beats, so the dry decay is kept.
- **Commits:** commit only this plan's paths.

## Review Focus

1. **Many quick hovers:** the echoes may overlap, but never more than 3 hover voices. Test in Task 2.
2. **A jingle chord missing from the table:** falls back to the first chord, as now. Covered by the existing test.
3. **The `MenuJingles` bus already exists** (for example from a second menu instance): don't add effects twice. Test in Task 2.
4. **Lore while idle:** Lore leaves idle, so its layers come back. Test in Task 1.
5. **The silent score fallback:** still no errors with no score files. Covered by the existing test.

---

### Task 1: Layer table and the ARCHETYPE state

**Files:**
- Modify: `scripts/Audio/MenuMusic.gd`
- Test: `tests/menu_music_test.gd` (rewrite the layer checks to the new table)

- [ ] **Step 1: Failing tests.**
  - Each state's `layer_target_db` matches the table, including `ARCHETYPE`.
  - At pos 0 in ARRIVAL, `layer_target_db(&"low") == 0.0`.
  - `set_selected(2)` changes no stem's target.
  - From IDLE, `set_state(LORE)` gives fx 0 and low 0.
- [ ] **Step 2:** Run the tests and watch them fail.
- [ ] **Step 3: Implement.**
  - TARGETS follow the table.
  - Remove `HIGH_BUSY`, activity's effect on high (`activity` stays, for idle only), and `LEAN`.
  - Add `ARCHETYPE` to the enum.
- [ ] **Step 4:** Run the tests and check they pass, along with main_menu_test (its "chosen word sounds its instrument" check becomes "plays its hover jingle").
- [ ] **Step 5:** Commit as `feat(audio): menu layers follow the screens`.

### Task 2: The jingle bus

**Files:**
- Modify: `scripts/Audio/MenuMusic.gd`
- Test: `tests/menu_music_test.gd`

**Interfaces:**
- Produces:
  - `const JINGLE_BUS := &"MenuJingles"`
  - `static func ensure_jingle_bus() -> void`, which is idempotent
- Behaviour: jingle voices play on `JINGLE_BUS`.

- [ ] **Step 1: Failing tests.**
  - After `make_music()`, the bus exists, sends to `Music`, and sits at −6 dB.
  - Its effect 0 is an AudioEffectDelay with tap1 delay 577 ± 1 ms, and its effect 1 is an AudioEffectReverb with wet 0.35.
  - A second `make_music()` leaves exactly 2 effects on the bus.
  - `hover(1)` creates a voice whose `bus == &"MenuJingles"`.
  - Hover spam across 8 frames never has more than 3 hover voices.
- [ ] **Step 2:** Run the tests and watch them fail.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run the tests and check they pass.
- [ ] **Step 5:** Commit as `feat(audio): menu jingles through a delay and reverb`.

### Task 3: Motifs and the tool's `cut.file`

**Files:**
- Modify:
  - `tools/compose_menu_parts.py`: write `parts/menu_jingles.mid` (tracks "Glockenspiel (hover)" and "Piano (press)") plus `parts/menu_jingles.json`, which lists each slot's (word, kind, chord, variant, start_beat, beats)
  - `tools/prepare_menu_score.py`: a jingle `cut` may name `file` (a WAV under the source folder) instead of `stem`, cut from `start_beat` for `beats`, with the same fades
- Test: `tests/tools/test_prepare_menu_score.py`

**Motif rules:**
- Hover (glockenspiel, octave 5–6): word 0 rises root→5th→9th; word 1 is two notes, 3rd→7th; word 2 is one chord tone plus its octave; word 3 falls through the #11 or 9th to the 5th. Variant 1 transposes the contour to start one chord tone higher.
- Press (piano, octave 4–5): the word's hover contour in eighths, then a resolving dyad on beat 1½ (root and 3rd, or the 5th on the ♭II).
- Every note is a tone of its chord (Dm9: D F A C E; Bbmaj7#11: Bb D F A E; Gm9: G Bb D F A; Ebmaj7#11: Eb G Bb D A).

- [ ] **Step 1: Failing tool test.** A `cut` with `file` and `start_beat` gives the right slice (RMS-equal to the source slice × gain) and the right length (from ffprobe). A missing `file` names the jingle in its error.
- [ ] **Step 2:** Run the test and watch it fail. Implement, then run it again and watch it pass.
- [ ] **Step 3:** Generate the motifs. Check that every note is a chord tone of its slot's chord, and that the slot table has 64 rows.
- [ ] **Step 4:** Commit as `feat(audio): glockenspiel and piano menu motifs`.

### Task 4: Render in Logic (with the user) and drop in

- [ ] **Import and render.**
  1. Import `parts/menu_jingles.mid` into the project. Set the hover track to a Glockenspiel patch and the press track to a piano (Studio Grand).
  2. Export those two tracks dry: open Logic's export with options, with Normalize off and nothing on the tracks' insert effects. Save them as `stems/jingle_glock.wav` and `stems/jingle_piano.wav`.
  3. Mute the two tracks in the song so they don't play under it.
- [ ] **Map and build.** Rewrite `map.json`'s `jingles` from `menu_jingles.json`, as `cut.file` entries. Run `prepare_menu_score.py` and import.
- [ ] **Check.** Run every suite and the native preview. Do a real-score check that each word's hover and press plays on `MenuJingles` in the right chord.
- [ ] **Tune by ear.** Launch the game for the user. Tune the bus level and the delay and reverb amounts from their notes, then record the final values in `docs/systems/main-menu.md`.
- [ ] **Commit** as `feat(audio): the menu's glockenspiel and piano jingles`.
