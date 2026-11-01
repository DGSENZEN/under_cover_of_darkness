# The Séance Menu Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the *Hasta los huesos* menu loop with the séance: occult jazz-noir at 63 bpm in E Phrygian, written as MIDI for the user's Logic project, and prepared into the menu's game files with its word and archetype jingles.

**Architecture:**
- `tools/compose_seance_parts.py` writes the MIDI in pieces: groove, audition, voices, jingles. It uses `tools/menu_midi.py` (with the pitch-bend and CC support cherry-picked from metro-score) and a shared performance pass, `tools/midi_perform.py`.
- The user arranges and exports in Logic.
- `tools/prepare_menu_score.py --source assets/audio/source/menu_seance` writes `audio/music/menu/`, which `scripts/Audio/MenuMusic.gd` already plays. Its one code change is a jingle echo that follows the score's tempo.

**Tech Stack:** Python 3 (numpy, ffmpeg via prepare_menu_score), Godot 4.5.1 GDScript, Logic Pro (driven by the user, and by computer-use where granted).

**Spec:** `docs/superpowers/specs/2026-10-31-seance-menu-theme-design.md`

## Global Constraints

- **Tempo and key:** 63 bpm, 4/4, E Phrygian; a 16-bar loop in 4-bar phrases.
- **Chord plan,** two bars each, by these exact names in the scripts and in `map.json`:
  `Em7b9`, `Fmaj7#11`, `Gm9`, `Bb7alt`, `Am9`, `Gm9`, `Fmaj7#11`, `F7#11`.
- **Six distinct chord names:** `Em7b9`, `Fmaj7#11`, `Gm9`, `Bb7alt`, `Am9`, `F7#11`.
- **Layers:**

  | Layer | Stems |
  |---|---|
  | base | fuzz bass, Rhodes, low choir, crackle |
  | low | kit, bell |
  | high | button 0 trumpet, 1 theremin, 2 profundo, 3 glockenspiel |
  | fx | soprano, whispers, bowed metal |

- **Archetype jingles:**
  - Derive (button 5): kit and fuzz bass.
  - Thaumaturge (button 6): glockenspiel and choir.
  - Factotum (button 7): Rhodes and muted trumpet.
- **The old theme's source stays untouched:** `assets/audio/source/menu_theme/` is not edited.
- **The menu's game-file path stays as it is:** `audio/music/menu/` (`MenuMusic.SCORE_JSON`).
- **Never commit WAVs:** the new source folder gets a `.gitignore`, as `menu_theme`'s has.
- **Logic save panels are the user's:** Claude never clicks the Open, Save, Export or Bounce panels; the user imports, exports and bounces.
- **Workspace:** a worktree at `.claude/worktrees/seance-menu`, on a branch `seance-menu` cut from `main-menu-overhaul` HEAD (9a5eee22 or later). The main checkout carries the user's uncommitted work and is not touched.
- **Godot suites:**
  - Run: `perl -e 'alarm 280; exec @ARGV' /Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 res://tests/<scene>.tscn`.
  - A pass is no `FAIL` line and no `SCRIPT ERROR` line.

## Review Focus

1. **A second menu at another tempo:** the jingle bus is made once and shared, so a menu loaded at 63 bpm after one at 78 must re-time the echo, not keep 577 ms. Pinned in Task 2.
2. **Chord names that don't match:** if a chord name in `map.json` differs from the jingle tables (`Em7b9` vs `Em`), the game warns and falls back to the first chord's jingle, which is out of key. Pinned in Task 6 by a coverage test.
3. **A late drummer at the loop seam:** the kit plays late on purpose. The clamp in the performance pass must not cut that lateness off, and the last bar's late hits must stay inside the loop or fold across the join (prepare folds tails). Pinned in Tasks 1 and 3.
4. **A theremin slide needs a set bend range:** a semitone slide only lands if the part sets its bend range. Without one, Logic's default of ±2 halves the written bend values. Pinned in Task 4.
5. **Jingles that sit outside their chord:** a hover or press tone outside its chord (the `F7#11` jingle drawn from `Fmaj7#11`'s tones) sounds wrong against the loop. Pinned in Task 5.

---

### Task 1: MIDI controls and the shared performance pass

**Files:**
- Cherry-pick: 58ccb598 (its `tools/menu_midi.py` hunk; the test hunk goes to a new file)
- Create: `tools/midi_perform.py`
- Test: `tests/test_menu_midi.py`, `tests/test_midi_perform.py`

**Interfaces:**
- Produces:
  - `menu_midi.write_song(path, bpm, parts)`, where each part is `{name, channel?, program?, notes: [(start_beat, length, pitch, vel)], controls?: [(beat, kind, value)]}` and `kind` is `'bend'` (in semitones), `'bend_range'` or an int CC number.
  - `menu_midi.read_midi(path)`, which returns `{'tracks': [{name, notes, controls: [(beat, kind, value, channel)]}]}`.
  - `midi_perform.perform(parts, players, seed) -> parts`, where `players` maps a part name to `dict(spread, behind, vel, roll?, drift?, breath?)`; every value is in beats.
  - `midi_perform.ramp(beat0, beat1, kind, v0, v1, steps=24, curve=1.0) -> controls`.

- [ ] **Step 1: Make the worktree.** Run `git worktree add .claude/worktrees/seance-menu -b seance-menu main-menu-overhaul`, then `cd` there.
- [ ] **Step 2: Cherry-pick.** Run `git cherry-pick -n 58ccb598`. Take its `tools/menu_midi.py` change, move its two tests (`test_midi_carries_bends_ccs_and_bend_range`, `test_menu_parts_without_controls_are_unchanged`) into a new `tests/test_menu_midi.py`, and drop `tests/test_compose_metro_parts.py`.
  - Run: `python3 -m unittest tests.test_menu_midi -v`
  - Expected: 2 pass. The menu's MIDI stays byte-identical.
- [ ] **Step 3: Write the failing tests** in `tests/test_midi_perform.py`:
  - `test_same_seed_same_performance`: two `perform` calls with seed 1925 are equal.
  - `test_player_sits_behind_the_beat`: a kit part of 64 snares on beats 1 and 3 (0-based), with player `dict(spread=0.004, behind=0.07, vel=4)`. The mean of `start - written` is within 0.01 of 0.07, and no hit is earlier than written minus 0.02.
  - `test_lateness_is_not_clamped_away`: with `behind=0.09`, the mean lateness is above 0.08 beats.
  - `test_chords_roll_lowest_first`: a three-note chord with `roll=0.02` starts in pitch order.
  - `test_breath_replaces_written_cc11`: a part with written CC11 and `breath=True` keeps no written CC11 events, and has its own swell on every note of 1 beat or more.
  - `test_unknown_parts_pass_through`: a part with no player comes back unchanged.
  - Run: `python3 -m unittest tests.test_midi_perform -v`
  - Expected: fails with "midi_perform is not implemented".
- [ ] **Step 4: Implement `tools/midi_perform.py`.**
  - Port `perform`, `_drift`, `_breathe` and `_ramp` (renamed `ramp`) from `.claude/worktrees/metro-score/tools/compose_metro_parts.py`, with `PLAYERS` passed in as `players`.
  - Change the shift clamp from fixed bounds (-0.05..0.06) to `behind - 0.05 .. behind + 0.05`.
  - Run: `python3 -m unittest tests.test_midi_perform tests.test_menu_midi -v`
  - Expected: all pass.
- [ ] **Step 5: Commit.** `git add tools/menu_midi.py tools/midi_perform.py tests/test_menu_midi.py tests/test_midi_perform.py && git commit -m "feat(music): MIDI controls and a shared performance pass for the menu"`

### Task 2: The jingle echo follows the score's tempo

**Files:**
- Modify: `scripts/Audio/MenuMusic.gd`: `ECHO_MS` (line 19) and the bus setup (lines 136–150)
- Test: `tests/menu_music_test.gd` (`bus_checks`)

**Interfaces:**
- Produces: `static func echo_ms(bpm: float) -> float` on MenuMusic, returning a dotted eighth: `0.75 * 60000.0 / bpm`.
- Every menu that loads sets the shared bus's delay taps (tap1 and feedback) from its own score's bpm, including when the bus already exists.

- [ ] **Step 1: Write the failing checks** in `bus_checks`:
  - `MenuMusic.echo_ms(63.0)` is within 0.1 of 714.29, and `echo_ms(78.0)` is within 0.1 of 576.92.
  - Copy the fixture `score.json` into `user://seance_score.json` with `"bpm": 63`, keeping the resource paths absolute (`res://tests/fixtures/menu_score/...`). After `make_music()` at 78, `make_music("user://seance_score.json")` leaves both delay times within 1 ms of 714.29.
  - Replace the existing `577.0` literal with `MenuMusic.echo_ms(78.0)`.
  - Run the `menu_music_test.tscn` suite.
  - Expected: FAIL (`echo_ms` doesn't exist, which is a parse error, or the delay stays at 577).
- [ ] **Step 2: Implement.** Drop `ECHO_MS` and add `echo_ms(bpm)`. Wherever the jingle bus is ensured, set the delay effect's two delay times from `float(score.bpm)`, whether the bus was just made or already existed.
- [ ] **Step 3: Run** `menu_music_test.tscn` and `main_menu_test.tscn`.
  - Expected: no FAIL lines.
- [ ] **Step 4: Commit.** `git commit -am "feat(audio): the menu's jingle echo follows the score's tempo"`

### Task 3: Round 1: the groove and the voice auditions

**Files:**
- Create: `tools/compose_seance_parts.py`
- Create: `assets/audio/source/menu_seance/.gitignore` (ignores `*.wav`), `assets/audio/source/menu_seance/.gdignore`, `assets/audio/source/menu_seance/README.md` (the frame, the chord plan and the layers table from Global Constraints), and `parts/`
- Test: `tests/test_compose_seance_parts.py`

**Interfaces:**
- Consumes: Task 1's `write_song`, `perform` and `ramp`.
- Produces: in `compose_seance_parts.py`:
  - `BPM = 63`, `BARS = 16`, `PHRASE_BARS = 4`;
  - `CHORD_PLAN = [(bar, name, root_pitch_class, stack)]`, eight entries;
  - `PLAYERS`;
  - `groove() -> parts` (tracks `Kit`, `Fuzz Bass`, `Rhodes`);
  - `audition() -> parts` (tracks `Theremin`, `Choir`, `Profundo`, `Soprano`, `Glockenspiel`, each 4 bars over bars 1–4);
  - `PIECES` and `write_piece(piece, take, out) -> Path`, writing `parts/seance_<piece>_<take>.mid`.
  - CLI: `python3 tools/compose_seance_parts.py --piece groove --take 1`.

- [ ] **Step 1: Write the failing tests:**
  - `test_frame`: BPM 63, BARS 16; the names in `CHORD_PLAN` are exactly the Global Constraints list, at bars 0, 2, …, 14.
  - `test_bass_follows_the_plan`:
    - the first `Fuzz Bass` note of each chord's span has that chord's bass pitch class (E, F, G, B♭, A, G, F, F);
    - every bass note is in E Phrygian, plus F♯ in bars 5–6 (the crawl) and B♭ in bars 7–8 (the detour) and in `Gm9`;
    - all bass notes are below MIDI 52.
  - `test_kit_drags`:
    - the kick (36) lands within 0.1 beat after beat 0 of every bar (beats are 0-based);
    - the snare (38) is on beats 1 and 3 of every bar, after the performance pass, late by a mean of 0.05–0.10 beats;
    - ghost snares (velocity ≤ 45) exist in at least 12 bars;
    - hi-hat velocities are all ≤ 50.
  - `test_rhodes_voices_the_chords`: every note the Rhodes plays in a chord's span is a tone of that chord's stack (or its octave), and it has CC1 or CC74 moves (the tremolo or the dirt is played).
  - `test_loop_fits`: no note in `groove()` starts at or after 64 beats.
  - `test_audition_has_every_voice`: the five track names exist; `Theremin` has a `bend_range` and at least eight `bend` events.
  - `test_writes_one_file_per_take`: `write_piece('groove', 2, tmp)` makes `seance_groove_2.mid`, and `read_midi` finds 63 bpm.
  - Run: `python3 -m unittest tests.test_compose_seance_parts -v`
  - Expected: fails with "compose_seance_parts is not implemented".
- [ ] **Step 2: Implement `groove()`.** Effects-led from the start ([[music-contemporary-not-generic]]):
  - **Fuzz bass:** half-time weight, with grinding semitone pickups into each chord.
  - **Rhodes:** low, spread voicings, with CC1 swells for its tremolo depth and CC74 for the dirt.
  - **Kit:** written straight, then laid back by `PLAYERS` (snare `behind` about 0.07 beats, which is 67 ms at 63; kick about 0.03; hats about 0.09 and loose).
  - Then implement `audition()`: one strong gesture per voice in `Em7b9`:
    - Theremin: semitone slides and wide vibrato, as bends;
    - Choir: low unison on E;
    - Profundo: E1–E2;
    - Soprano: a high held wail;
    - Glockenspiel: a detuned four-note music-box figure.
- [ ] **Step 3: Run** the tests.
  - Expected: all pass.
- [ ] **Step 4: Write take 1.** Run `python3 tools/compose_seance_parts.py --piece groove --take 1` and `--piece audition --take 1`.
  - Expected: two `.mid` files in `parts/`.
- [ ] **Step 5: Commit.** `git add tools/compose_seance_parts.py tests/test_compose_seance_parts.py assets/audio/source/menu_seance && git commit -m "feat(music): the séance's groove and voice auditions"`
- [ ] **Step 6: User gate.** The user imports both files into `~/Music/Logic/Untitled.logicx`. Sounds and effects are set up together: fuzz on the bass, drive and tremolo on the Rhodes, tape and room on the kit, a cathedral reverb on the voices only. The user judges the drag and picks the voices, including where the choir's syllables and the whispers come from.
  - Ledger the verdict. A "needs changes" means a new take; the round ends on approval.

### Task 4: Round 2: the voices

**Files:**
- Modify: `tools/compose_seance_parts.py` (adds `voices()` and `PIECES['voices']`)
- Test: `tests/test_compose_seance_parts.py`

**Interfaces:**
- Produces: `voices() -> parts`, with tracks `Trumpet`, `Theremin`, `Choir`, `Profundo`, `Soprano`, `Glockenspiel`, `Bell`, `Bowed Metal`, all over 16 bars. The kit, bass and Rhodes stay as they are in `groove()`.

- [ ] **Step 1: Write the failing tests:**
  - `test_profundo_on_the_bass_notes`: every `Profundo` note starts within 0.1 beats of a `Fuzz Bass` note and has its pitch class, below MIDI 48.
  - `test_choir_cries_at_the_tritone`: in bars 7–8 the choir sounds at least five notes at once, including two a semitone apart; elsewhere it sings at most two pitch classes at once (the low unison chant).
  - `test_theremin_slides_by_semitones`: the theremin sets a bend range of 2 or more, and has slides that reach ±1 semitone and return.
  - `test_glockenspiel_every_few_bars`: the figure plays in bars 4, 8, 12 and 16 only, and each one carries a detuning bend between ±0.1 and ±0.4 semitone.
  - `test_trumpet_answers_briefly`: every trumpet phrase (a run of notes with gaps under 1 beat) is at most 6 beats long and starts on a beat where the theremin is silent.
  - `test_bell_tolls`: there are 4–8 bell strikes per 16 bars, all on E or B♭.
  - `test_voices_fit_the_loop`: no `voices()` note starts at or after 64 beats.
  - Run the tests.
  - Expected: they fail, because `voices` doesn't exist.
- [ ] **Step 2: Implement `voices()`.** Give the trumpet `breath=True` in `PLAYERS`, the theremin `drift`, and the soprano a far, soft velocity range of 30–55.
- [ ] **Step 3: Run** the tests.
  - Expected: all pass, the Task 3 tests included.
- [ ] **Step 4: Write and commit.** Run `--piece voices --take 1`, then `git commit -am "feat(music): the séance's voices"`.
- [ ] **Step 5: User gate.** The user imports the file, the arrangement is finished in Logic, and the user approves it. The user then exports all tracks (48 kHz, normalise off, effects on, from bar 1). Claude moves the WAVs to `assets/audio/source/menu_seance/stems/<id>.wav`, using the ids in Task 6's map.

### Task 5: The word and archetype jingles

**Files:**
- Modify: `tools/compose_seance_parts.py` (adds `jingles()`, `archetype_jingles()` and `PIECES['jingles']`)
- Test: `tests/test_compose_seance_parts.py`

**Interfaces:**
- Produces:
  - `jingles() -> (parts, table)`: one 2-bar slot per word, chord and variant, in the order word / chord / variant, over the six distinct chords. Table rows are `dict(button, kind, chord, variant, start_beat, beats)`, as `assets/audio/source/menu_theme/parts/menu_jingles.json`. Each word's motif is on its own séance instrument: tracks `Trumpet (jingle)`, `Theremin (jingle)`, `Profundo (jingle)`, `Glockenspiel (jingle)`, where hover is 2 beats and press is 4.
  - `archetype_jingles() -> (parts, table)`: buttons 5–7 on the archetype instruments in Global Constraints, as compose_menu_parts' `archetype_jingles` (hover 3 beats, press 6, 8-beat slots).
  - The piece writes `parts/seance_jingles_<take>.mid`, `parts/seance_jingles.json`, `parts/seance_archetype_jingles_<take>.mid` and `parts/seance_archetype_jingles.json`.

- [ ] **Step 1: Write the failing tests:**
  - `test_word_jingles_cover_every_chord`: for buttons 0–3, both kinds, the six chords and variants 0 and 1, there is exactly one row each (96 rows).
  - `test_archetype_jingles_cover_every_chord`: the same for buttons 5–7 (72 rows).
  - `test_jingle_tones_sit_in_their_chord`: every pitched note in a slot is a tone of that slot's chord stack.
  - `test_slots_do_not_overlap`: each slot's notes start inside its own slot.
  - Run the tests.
  - Expected: they fail.
- [ ] **Step 2: Implement both functions.** Each word keeps its old shape (New Game rises, Continue answers, Settings rings a tone and its octave, Lore falls), played by its séance instrument. The theremin's jingles slide into their first tone by a semitone bend.
- [ ] **Step 3: Run** the tests.
  - Expected: all pass.
- [ ] **Step 4: Write and commit.** Run `--piece jingles --take 1`, then `git commit -am "feat(music): the séance's word and archetype jingles"`.
- [ ] **Step 5: User gate.** The user imports both jingle files onto their instruments, as muted tracks, and approves them by ear. The user exports them dry (effect plug-ins bypassed, audio tail included) to `stems_jingles/`, one WAV per jingle track.

### Task 6: The séance on the menu

**Files:**
- Create: `assets/audio/source/menu_seance/map.json`
- Modify: `assets/audio/source/menu_seance/README.md` (stems table: stem, Logic track, layer, word)
- Regenerate: `audio/music/menu/` (by `tools/prepare_menu_score.py --source assets/audio/source/menu_seance`)
- Test: `tests/test_compose_seance_parts.py` (map coverage)

**Interfaces:**
- Consumes: Task 5's tables and Task 4's stems.
- `map.json` uses `menu_theme/map.json`'s schema:
  - top level: `bpm` 63, `beats_per_bar` 4, `bars` 16, `phrase_bars` 4, `arrival` null;
  - `chords`: the eight `CHORD_PLAN` entries as `{bar, name}`;
  - `stems`: `{id, file, layer, button, trim_db}`, with layers and buttons from Global Constraints;
  - `jingles`: rows built from the tables, each with a `cut` of `{file, start_beat, beats}` and a `gain_db`, as the old map's jingle rows.

- [ ] **Step 1: Write the failing test.** `test_map_covers_every_chord_and_button` loads `map.json` and checks:
  - its chord names equal `CHORD_PLAN`'s;
  - every chord name has a hover and a press row with variants 0 and 1 for buttons 0–3 and 5–7;
  - every stem's file exists;
  - every jingle's cut file exists.
  - Run the test.
  - Expected: it fails, because there is no `map.json`.
- [ ] **Step 2: Write `map.json`** from the tables and the stems. The press gain stays at the old +6 dB until the user balances it by ear.
- [ ] **Step 3: Prepare and reimport.**
  - Run: `python3 tools/prepare_menu_score.py --source assets/audio/source/menu_seance`, then `Godot --headless --path . --import`.
  - Expected: it reports 63 bpm and 16 bars, with no missing file.
- [ ] **Step 4: Run the suites:** `python3 -m unittest tests.test_compose_seance_parts tests.test_midi_perform tests.test_menu_midi tests.test_prepare_score -v`, then the Godot suites `menu_music_test`, `main_menu_test`, `menu_scene_change_test` and `pause_menu_test`.
  - Expected: everything passes.
- [ ] **Step 5: Commit.** `git add assets/audio/source/menu_seance audio/music/menu tests/test_compose_seance_parts.py && git commit -m "feat(audio): the séance is the menu theme"`
- [ ] **Step 6: User gate.** The user plays the real menu and checks: hover and press on each word, Lore, the archetype screen, idle after 30 s, and New Game leaving on a phrase line. Ledger the verdict. Then do the final whole-branch review and finishing-a-development-branch (merging back into `main-menu-overhaul` is the user's call).
