# The Harbour's Job Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the harbour a job: a letter in the hands that fills in with pencil notes from readables and overheard talk, the seal as the goal that opens the ways up to the old town, a theft the guards can notice, and the harbour's tally on the loading screen; built as a general mission layer every district reuses.

**Architecture:** Words live in plain `.job` files (`data/jobs/`) parsed by `JobBook`; progress lives in `JobState` on the `CityState` autoload. The hands get a shared held page (letter and readables) with a two-handed `HandContacts` READ state. `DistrictMap` wires it together: the gate, the cues, the tally, and guard "hails" that play the harbour's conversations. Guards learn one new oddity (a chest left open) and one new alarm (a robbed special).

**Tech Stack:** Godot 4 GDScript; headless suites (`tests/*_test.tscn`); Python level pipeline (`tools/level`, Blender export); `tools/prepare_sfx.py` for sounds.

**Spec:** `docs/superpowers/specs/2026-10-03-harbour-job-design.md` (commit 5c07fe4). Read it first; this plan argues from it.

## Global Constraints

- Work only in the worktree `/Users/tinkertailorr/a-world-of-darkness-alpha/.claude/worktrees/harbour-job` (branch `harbour-job`). Never `cd` to the main checkout to write.
- Godot: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . res://tests/<suite>.tscn`. Workspace scripts in `.superpowers/sdd/2026-10-03-harbour-job/` (git-excluded): copy `suite.sh`, `suites.sh`, `all_suites.sh`, `one_step.sh` from `../old-town/.superpowers/sdd/2026-10-02-districts-as-maps/` and change their `HERE` paths. `one_step.sh <step>` runs one `city_test` step (`--only=<step>`).
- **The words are the user's.** Every commission, goal, note, readable, refusal, shout and harbour conversation line is a placeholder `<<...>>` with an `intent:` (job files) or `# intent:` comment (talk files). Claude writes no lore.
- **Claude's UI strings, exactly:** prompts `Put away`, `Turn over`, `Read`, `Put down`, `Look away`, `Go on`; caption `Noted`; tally labels `Loot`, `Specials`, `Notes read`, `Knocked out`, `Killed`, `Bodies found`, `Times seen`, `Alarms`, `Time`; district labels in `data/districts.json`: `The harbour`, `The old town`.
- Keys: `J` (new action `letter`) raises and lowers the letter; `E` (`frob`) lowers a readable; the `throw` button turns the sheet while a page is up.
- Overheard = within **22 m** (`Earshot.RANGE`) **and** the speaker's sight line to the player's head is clear (closed doors block). Subtitles use the same rule.
- Refusal caption at most once per entry, **4 s** cooldown. Seal turn in the hand **~1.2 s**. Baltasar's office-landing wait **2 s**. Times-seen merge window **10 s**. A chest left open raises alarm **0.2** (`DOOR_ALARM`); a robbed special raises **1.0**.
- No procedural audio: sounds are cut by `tools/prepare_sfx.py` from the approved packs only (TomMusic pack `~/Downloads/Free Fantasy SFX Pack By TomMusic`, NOX Voices/Sounds Essentials, `~/Downloads/AUCOD Web SFX/` incl. Mixkit, the 400 Sounds Pack, FilmCow). The user approves new sounds by ear.
- No downloaded art: page and readable meshes and materials are ours.
- The repo is PUBLIC: never commit `textures/ps2/`, `textures/source/` or anything made from textures.com photos. Copy `textures/ps2` from the main checkout into the worktree before an export (it is gitignored), never `git add -f` it.
- Never run `tools/level/level.sh build city_harbour --force`. If the build's edit guard refuses (the user edited the .blend), stop and ask the user.
- After any harbour marker change: `tools/level/level.sh export city_harbour`, then `tools/level/level.sh navmesh harbour`.
- Follow `fp-animation-principles` (head leads, eased raise, never steal control) and the headless-determinism rules (no unseeded random; pin free-running clocks in tests).
- Check ids continue each suite's numbering: `city_test` C23+, `transitions_test` T15+, `talk_test` T50+. New suites: `job_test` (J1+), `letter_test` (L1+), `theft_test` (R1+).
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Baseline before Task 1: run `all_suites.sh` and record the tally in the ledger (`.superpowers/sdd/2026-10-03-harbour-job/progress.md`). Expected on main c99b516: 56 suites, 1377 checks, all pass. Every task ends with its own suites green; Task 13 runs everything.

## Review Focus

1. **A page up when the world takes the hands** (travel through a gate, getting hit, a fight starting, climbing). The page goes down, a held paper comes back to where it lay, and you arrive in the next district with hands free. Pinned: L9 (Task 4), L13 (Task 5).
2. **`J` while the hands are busy** (turning a key, picking a lock, carrying, a body on the shoulder). Nothing rises and nothing breaks. Pinned: L10 (Task 4).
3. **A note learnt while the letter is up.** The open sheet updates at once, without lowering and raising. Pinned: L11 (Task 4).
4. **A theft found twice** (a second guard after the first is knocked out, or a return visit). The theft counts once per district and the alarm is not tallied twice. Pinned: R6 (Task 8), T17 (Task 11).
5. **A word slot pointing at nothing**: `took(x)` for a loot marker not in the harbour, a talk `[note:x]` or a readable marker slot with no entry. Each fails loudly at test time, not silently in play. Pinned: J6 (Task 1), T53 (Task 9), C25 (Task 12).

---

### Task 1: The job files and their parser (`JobBook`)

**Files:**
- Create: `scripts/Level/JobBook.gd`
- Create: `data/jobs/mission.job`, `data/jobs/harbour.job`, `data/jobs/old_town.job`
- Create: `docs/systems/jobs.md` (the format, for the user)
- Create: `tests/job_test.gd`, `tests/job_test.tscn`

**Interfaces:**
- Produces:
  - `JobBook.parse(text: String, file: String) -> Dictionary`: `{"entries": Array, "errors": Array[String]}`. Each entry is `{"kind": StringName, "id": String, "keys": Dictionary, "text": String, "source": "file:line"}`.
  - `JobBook.load_dir(path := JobBook.FOLDER) -> Dictionary`, with keys:
    - `letter`: an entry.
    - `goals`: an ordered Array of `{id, district, kind, shows, done, note, text, intent, source}`. Order: mission.job first, then the districts in `data/districts.json` order.
    - `notes`, `readables`, `shouts`: each `{id: entry}`.
    - `gates`: an Array of `{id, district, exits: Array[String], needs, text, intent, source}`.
    - `errors`: Array[String].
  - `JobBook.library() -> Dictionary` (cached) and `JobBook.reload() -> void`.
  - Lookups: `JobBook.note_text(id: String) -> String`, `JobBook.readable(slot: String) -> Dictionary` (`{}` if none), `JobBook.shout(id: String) -> String`.
  - `JobBook.condition_error(cond: String) -> String` returns `""` when valid.
  - `JobBook.placeholders(lib := {}) -> Array[String]`: `"<file>:<line> <kind> <id>"` for every text still wrapped in `<<...>>`.
  - Constants: `FOLDER := "res://data/jobs"`, `KINDS := [&"letter", &"goal", &"note", &"readable", &"gate", &"shout"]`.

**Format** (spec section 3):
- Blocks are `== <kind> <id>`.
- Lines are `key: value`. A `text:` with nothing after it takes every following line up to the next `==` as the text (outer blank lines trimmed). Lines starting `#` are comments.
- A file's district is its basename (`mission` for mission.job).
- **Keys per kind:**
  - goal: `kind` (main|side), `shows`, `done` (required), `note`, `intent`, `text`
  - note: `intent`, `text`
  - readable: `note`, `intent`, `text`
  - gate: `exits`, `needs`, `intent`, `text`. `exits` is a comma list of exit marker names and/or `to(<district>)`.
  - shout and letter: `intent`, `text`
- **Conditions:** comma-separated terms, all must hold. A term is `took(<name>)`, `arrived(<district>)`, `done(<goal>)`, `loot>=<int>` or `not(<term>)`.
- **Errors**, each with file:line:
  - an unknown kind or key
  - an id used twice within a kind
  - a missing `text`
  - a goal without `done`
  - a bad condition
  - a goal or readable `note:` naming no note
  - a gate `needs:` naming no goal

**The data files' contents.** Every `text` is `<<...>>`; every `intent` is the spec's wording.
- `mission.job`:
  - `== letter commission`
  - `== goal loot` (side, `done: loot>=1000`; its intent says the value is the user's to tune)
  - `== shout theft`
- `harbour.job`:
  - Goals:
    - `seal`: main, `done: took(the_seal)`
    - `up`: main, `shows: done(seal)`, `done: arrived(old_town)`, `note: way_up`
    - `captains_ring`: side, `done: took(captains_ring)`
    - `signet`: side, `done: took(signet)`
  - Notes: `tower_bell`, `office_key`, `dark_bays`, `ways_up`, `cabin_key`, `blowhole`, `powder_room`, `way_up`.
  - Readables (spec 5.4, each with its `note:`):
    - `night_orders` → tower_bell
    - `duty_orders` → office_key
    - `curfew` → ways_up
    - `captains_log` → cabin_key
    - `smugglers_scrawl` → blowhole
    - `fort_note` → powder_room
    - `harbourmasters_letter` → way_up
  - `== gate old_town` with `exits: to(old_town)` and `needs: seal`.
- `old_town.job`: a header comment only (its goals come with its night plan).

- [ ] **Step 1: Write the failing tests** in `tests/job_test.gd`, following `state_test.gd`'s `_check(name, ok, detail)` harness:
  - `J1 the job files parse with no errors`: `JobBook.load_dir()["errors"].is_empty()`, `goals.size() == 5`, the goal ids in order `["loot", "seal", "up", "captains_ring", "signet"]`.
  - `J2 a text block runs to the next header`: parsing `"== note a\ntext:\nline one\n\nline two\n\n== note b\ntext: x"` gives a's text `"line one\n\nline two"`.
  - `J3 errors name file and line`: each of these gives exactly one error containing `"t.job:<line>"` and is rejected:
    - an unknown kind `== bell x`
    - a goal with no `done:`
    - a bad condition `done: took(`
    - `note: missing_note` on a goal
    - `needs: no_goal` on a gate
  - `J4 conditions`: `condition_error("took(a), not(done(b)), loot>=5")` is `""`; `condition_error("stole(a)")` is not `""`.
  - `J5 placeholders are listed`: `placeholders()` has one line per `<<` text in data/jobs (at least 4 + 8 + 7 + 1 + 3 = 23 lines), and each line starts `"harbour.job:"` or `"mission.job:"`. Print them prefixed `WORDS:`; the check never fails on their number.
  - `J6 every readable's and goal's note exists`: for each readable and goal with `note`, `lib["notes"].has(note)`.
- [ ] **Step 2: Run to see them fail.** `bash .superpowers/sdd/2026-10-03-harbour-job/suite.sh job_test`. Expected: a SCRIPT ERROR (JobBook missing).
- [ ] **Step 3: Implement `JobBook.gd`** and write the three data files and `docs/systems/jobs.md`.
  - The doc covers: the format, the condition words, what `<<...>>` means, and how to run `job_test` to list what is left to write.
- [ ] **Step 4: Run.** `suite.sh job_test`. Expected: J1-J6 PASS.
- [ ] **Step 5: Commit.** `git add scripts/Level/JobBook.gd data/jobs docs/systems/jobs.md tests/job_test.*` with message `feat(job): the job files and their parser`.

### Task 2: The job's progress (`JobState` on `CityState`)

**Files:**
- Create: `scripts/Level/JobState.gd`
- Modify: `scripts/Level/CityState.gd`: add `var job`; `begin()` calls `job.reset()`; `leave()` calls `job.leave(map.district)`.
- Modify: `data/districts.json`: add `"label"` to each district (`"The harbour"`, `"The old town"`).
- Test: `tests/job_test.gd`

**Interfaces:**
- Consumes: `JobBook.library()`, `JobBook.condition_error()`.
- Produces (`JobState extends RefCounted`):
  - **Signals:** `goal_shown(id: String)`, `goal_done(id: String, kind: StringName)`, `noted(id: String)`, `read(slot: String)`.
  - **Vars:** `here: StringName`, `last_left: StringName`, `arrived: Array[String]`, `took: Array[String]`, `loot: int`, `shown: Array[String]`, `done: Array[String]`, `notes: Array[String]` (in order learnt), `read_slots: Array[String]`, `facts: Dictionary` (`{district: {fact: value}}`), `tally: Dictionary` (`{district: {key: int}}`), `letter_opened: bool`, `book: Dictionary`.
  - **Where the facts live:** the district facts such as `theft_noticed` are kept here, per district, rather than in `DistrictState`. It is the same city memory that outlives a map (spec section 8), with one place to read them.
  - **Lifecycle:**
    - `reset(with_book := {}) -> void` (empty book means `JobBook.library()`).
    - `arrive(district: StringName) -> void` sets `here`, appends to `arrived`, refreshes.
    - `leave(district: StringName) -> void` sets `last_left`.
  - **Goals:**
    - `holds(condition: String) -> bool`.
    - `refresh() -> void`. In book order, a goal is listed if its district is `mission` or in `arrived`. A goal with no `shows:` is shown silently at listing. A goal with `shows:` emits `goal_shown` when it becomes true and learns its `note`. A shown goal whose `done` holds is added to `done` and emits `goal_done(id, kind)`.
    - `took_loot(loot_name: String, value: int) -> void` appends, adds to `loot`, refreshes.
    - `goals_listed() -> Array` returns `[{id, kind, text, done: bool}]` for the shown goals.
  - **Notes and readables:**
    - `learn(note_id: String) -> void`: once each; emits `noted`. An unknown id is a `push_error` and is ignored.
    - `read_slot(slot: String) -> void`: once each; emits `read`, learns the readable's note, and counts `read` in the tally.
  - **Facts:**
    - `set_fact(district: StringName, fact: StringName, value: Variant) -> void` and `fact(district: StringName, fact: StringName) -> Variant` (null when unset).
    - `notice_theft() -> bool`: true only the first time per `here`. It sets `theft_noticed` and counts `alarms` +1.
  - **The gate:** `gate_for(exit: Area3D) -> Dictionary`. Among the `here` district's gates, the first whose `exits` holds the exit's name, or `to(<exit meta to>)`, while its `needs` goal is not done. Otherwise `{}`.
  - **The tally:**
    - `count(key: String, by := 1, district: StringName = &"") -> void`.
    - `set_total(key: String, value: int, district: StringName = &"") -> void`.
    - An empty `district` in either means `here`.
    - `tally_rows(district: StringName) -> Array` returns `[[label, value]]` with the exact labels from Global Constraints, in order: `Loot` (`"%d of %d" % [loot, loot_total]`), `Specials` (`"%d of %d"`), `Notes read` (`"%d of %d"`), `Knocked out`, `Killed`, `Bodies found`, `Times seen`, `Alarms`, then `Time` (`"%d:%02d"` from `seconds`).
  - **Saving:** `save_state() -> Dictionary` and `load_state(state: Dictionary) -> void` cover every var except `book` and `here`.

- [ ] **Step 1: Write the failing tests** (job_test). Each runs on `JobState.new()` with `reset()`:
  - `J7 goals unfold`:
    - After `arrive(&"harbour")`: `goals_listed()` ids are `["loot", "seal", "captains_ring", "signet"]`, and no `goal_shown` was emitted.
    - After `took_loot("the_seal", 250)`: `done.has("seal")`; `goal_done` was emitted as `("seal", &"main")`; `goal_shown("up")` was emitted; `notes.has("way_up")`.
    - After `arrive(&"old_town")`: `done.has("up")`.
  - `J8 notes learnt once, in order`: on a fresh state, `learn("office_key")` twice, then `learn("tower_bell")` → `notes == ["office_key", "tower_bell"]` with `noted` emitted twice; `learn("no_such_note")` leaves `notes` unchanged.
  - `J9 reading`: `read_slot("duty_orders")` twice → `read_slots == ["duty_orders"]`, `notes == ["office_key"]`, `tally["harbour"]["read"] == 1`.
  - `J10 the gate`:
    - An `Area3D` named `exit_sea_gate` with meta `to = &"old_town"`: `gate_for` is non-empty with `text` beginning `"<<"` before the seal, and `{}` after `took_loot("the_seal", 250)`.
    - An exit with `to = &"gorge"` gives `{}`.
  - `J11 the theft counts once`: two `notice_theft()` calls in the harbour → `[true, false]`, `tally["harbour"]["alarms"] == 1`, `fact(&"harbour", &"theft_noticed") == true`.
  - `J12 the state round-trips`: `load_state(save_state())` on a second JobState gives equal `done`, `notes`, `took`, `loot`, `tally`, `facts`, `arrived` and `letter_opened`.
  - `J13 tally rows`: after `set_total("loot_total", 2040)`, `count("loot", 250)` and `count("seconds", 754)`: the rows' labels are exactly the ten in order, row 0 is `["Loot", "250 of 2040"]`, and the last is `["Time", "12:34"]`.
  - `J14 CityState.begin() resets the job` (the autoload): after a `took_loot`, `CityState.begin()` → `CityState.job.took.is_empty()`.
- [ ] **Step 2: Run to see them fail.** `suite.sh job_test`. Expected: FAIL or SCRIPT ERROR on J7-J14.
- [ ] **Step 3: Implement** `JobState.gd`, the `CityState` wiring and the registry labels. Check `scripts/Level/Districts.gd` tolerates the new `label` key, and add `Districts.label(district) -> String`.
- [ ] **Step 4: Run.** `suite.sh job_test`, `suite.sh state_test` and `suite.sh transitions_test 3000000`. Expected: all pass.
- [ ] **Step 5: Commit.** Message: `feat(job): the job's progress, remembered by the city`.

### Task 3: The level pipeline knows readables (Python)

**Files:**
- Create: `tools/level/jobs.py`
- Modify: `tools/level/markers.py`: SCHEMA `"readable": {"required": ["slot"], "optional": {"kind": "paper"}, "box": False}`; `READABLE_KINDS = ["notice", "paper", "ledger"]`, validated in `problems()`.
- Modify: `tools/level/rules.py`: add `readable_problems(data, slots)` and call it from `problems()` when `districts.district_of(districts.load(), data["level"])` is not None.
- Test: `tools/level/test_rules.py`

**Interfaces:**
- Produces:
  - `jobs.readable_slots(district: str, folder: str = JOBS) -> set[str]`: the ids of `== readable <id>` headers in `data/jobs/<district>.job`. An empty set if there is no file.
  - `rules.readable_problems(data: dict, slots: set) -> list[str]`: one problem per readable marker whose `slot` is not in `slots`, worded `"%s: reads slot '%s', not in the district's job file"`.
  - A readable marker in a level outside every district is a problem too (`"%s: a readable in a level of no district"`).

- [ ] **Step 1: Write failing tests** in `test_rules.py`:
  - `test_readable_slot_known` passes on `{"level": "city_harbour", "markers": [{"name": "r", "ucd": "readable", "props": {"slot": "curfew", "kind": "notice"}, "size": None}], ...}`.
  - `test_readable_slot_unknown` reports `r: reads slot 'nope'...`.
  - `test_readable_kind_checked`: `kind: "scroll"` is a schema problem.
  - `test_jobs_reads_headers`: on a temp folder holding `x.job` with `== readable a` and `== note b`, the result is `{"a"}`.
- [ ] **Step 2: Run them.** `cd tools/level && python3 -m pytest test_rules.py -q -k readable`, then `-k jobs`. Expected: FAIL.
- [ ] **Step 3: Implement** `jobs.py`, the schema entry and the rule.
- [ ] **Step 4: Run.** `python3 -m pytest test_rules.py -q` and `tools/level/level.sh test`. Expected: all pass.
- [ ] **Step 5: Commit.** Message: `feat(level): readable markers, checked against the district's job file`.

### Task 4: The letter in the hands

**Files:**
- Create: `scripts/Interaction/HeldPage.gd`
- Create: `scripts/UI/LetterText.gd`
- Modify: `scripts/Interaction/HandSlot.gd`: page hold, update, turn and lower; the page's edges; the main item lowered while a page is up.
- Modify: `scripts/Interaction/HandContacts.gd`: `State.READ`; `_state_now()` returns it before CARRY when `player.hand.is_page_up()`; `_keep_read()` plants both grips on `player.hand.page_edge(side)`.
- Modify: `scripts/Interaction/PlayerFrob.gd`: the `letter` action, the letter toggle, lowering rules, prompts, turning.
- Create: `tests/letter_test.gd`, `tests/letter_test.tscn`

**Interfaces:**
- Consumes: `CityState.job` (`JobState`: `goals_listed()`, `notes`, `noted`, `goal_done`, `goal_shown`, `letter_opened`), `JobBook.library()["letter"]`, `JobBook.note_text()`.
- Produces:
  - `LetterText.sides(job: JobState) -> PackedStringArray` (BBCode). Side 0 is the letter's text, a blank line, the main goals, then a line `[center]―――――[/center]` and the side goals. A done goal is `[s]…[/s]`. Sides 1.. are the notes, `NOTES_PER_SIDE := 10` per side, each line `"— " + text` in `PENCIL := Color(0.42, 0.42, 0.45)` italics.
  - `HeldPage extends Node3D`:
    - `show_sides(sides: PackedStringArray, look: StringName) -> void`, `turn() -> void`, `side: int`, `side_count() -> int`, `text_of(i: int) -> String`, `edge(hand: int) -> Transform3D` (world, palm frame as `HandContacts.Grip.at` expects).
    - `SIZES := {&"letter": Vector2(0.21, 0.28), &"paper": Vector2(0.21, 0.28), &"notice": Vector2(0.24, 0.32), &"ledger": Vector2(0.36, 0.25)}`, `LIGHT_FLOOR := 0.18`.
    - Drawn as a `SubViewport` (`RichTextLabel`, bbcode on, serif `SystemFont` like `LoadingScreen`'s) onto a paper quad on `HandSlot.VIEWMODEL_LAYER`, with `HandSlot._squeeze` on its material and emission = albedo × `LIGHT_FLOOR`.
  - `HandSlot`:
    - `hold_page(sides: PackedStringArray, look: StringName) -> void`, `update_page(sides: PackedStringArray) -> void`, `turn_page() -> void`, `lower_page() -> void`, `is_page_up() -> bool`, `page_edge(side: int) -> Transform3D`.
    - `page_look() -> StringName` returns `&""` when no page is up.
    - Raise and lower ease over `switch_time`: the page comes up from below the frame as the view dips 4°, and lowering reverses it. Every page change plays `Sfx.play_flat(self, &"paper")`. Missing recordings are silent in `Sfx`, so this is safe before Task 6 cuts the sound.
  - `PlayerFrob`:
    - `_ensure_action("letter", KEY_J)`.
    - `open_letter() -> void` and `put_page_away() -> void`.
    - `letter_up() -> bool`, true while the letter (not a readable) is up.
    - `const READ_LEAVE := 2.0`.

**Behaviour:**
- **`J`:** if a page is up, `put_page_away()`. Otherwise `open_letter()`, but only when `held == null`, `shouldered == null`, `not _unlocking`, `_picking == null` and `_hands_free()`.
- **While a page is up:**
  - `E` puts it away and does not frob.
  - `throw` calls `turn_page()` and does not attack (`player.spend_attack_press()`).
  - Tab does nothing.
- **Lowering:** each physics tick the page goes down unless all of these hold:
  - `player.movement_state == player.MoveState.LOCOMOTION`
  - `player.is_on_floor()`
  - `not player._is_sprinting()`
  - `held == null and shouldered == null`
  - `_combat_idle()`
  - `not player.is_dead`
- **`current_actions()` while the letter is up:** `[[&"letter", "Put away"]]`, plus `[&"throw", "Turn over"]` when there is more than one side.
- **Live updates:** `CityState.job.noted`, `goal_done` and `goal_shown` call `update_page(LetterText.sides(job))` while the letter is up. A Callable kept on PlayerFrob is disconnected in `_exit_tree`.
- `open_letter()` sets `job.letter_opened = true`.

- [ ] **Step 1: Write failing tests** in `letter_test.gd`. Setup: a floor, `Player.tscn` with `show_hud` false, `CityState.begin()`, `CityState.job.arrive(&"harbour")`.
  - `L1 J raises the letter and J lowers it`: inject `letter` via `Input.action_press`/`action_release` (call handlers directly where the harness doubles events, as interaction_test notes) → `player.hand.is_page_up()` and `player.frob.letter_up()`; then again → both false.
  - `L2 the front lists the job`: `page.text_of(0)` contains the letter's placeholder text and every listed goal's text. After `took_loot("the_seal", 250)`, it contains `"[s]"` + the seal goal's text.
  - `L3 the back holds the notes in pencil, ten to a side`: after learning 11 notes, `side_count() == 3`, side 1 has 10 lines starting `"— "`, side 2 has 1.
  - `L4 a click turns the sheet; it is not an attack`: with the blackjack selected, two notes learnt and the letter up, press `throw` → `page.side == 1`, `player.frob._swing_windup < 0.0` and `player.hand._swing == 0.0`.
  - `L5 E puts the letter away and frobs nothing`: a door 1 m in front, letter up, press `frob` → page down, `door.is_open == false`.
  - `L6 sprinting, jumping and climbing lower it`: sprint input for 0.3 s → page down. Raise again; a jump → down. Raise again; put the player in `MoveState.CLIMBING` on a ladder volume → down.
  - `L7 both hands hold the page`: with the letter up for 0.5 s, `player.hand._grip_weights[0] > 0.9` and `[1] > 0.9`, and the main hand's item is lowered (`_main_lower > 0.9`).
  - `L8 the page reads in the dark`: the page material's emission energy is ≥ `HeldPage.LIGHT_FLOOR` and its albedo texture is the viewport's.
  - `L9 getting hit puts the page away` (Review Focus 1): letter up, `player.take_damage(5.0, null)` → page down within 0.2 s. If `_combat_idle()` does not turn false on a hit, the lowering rule also checks a `hurt` within the last 0.2 s.
  - `L10 J does nothing while the hands are busy` (Review Focus 2): while carrying a crate, `J` → no page. While `_unlocking` (a key turn started on a locked door with its key), `J` → no page, and the door still opens when the turn completes.
  - `L11 a note learnt while reading shows at once` (Review Focus 1/3): letter up on side 1, `learn("blowhole")` → `page.text_of(1)` contains the blowhole note's text that same frame, and the page stays up.
- [ ] **Step 2: Run to see them fail.** `suite.sh letter_test`. Expected: SCRIPT ERROR.
- [ ] **Step 3: Implement** `LetterText`, `HeldPage`, the HandSlot page API, `HandContacts` READ, and the PlayerFrob wiring.
- [ ] **Step 4: Run.** `suite.sh letter_test`, then `suites.sh interaction_test feel_test motion_test traversal_test combat_test`. Expected: all pass. The last five guard the hands, climbing and combat input you touched.
- [ ] **Step 5: Commit.** Message: `feat(job): the letter in both hands, filling in`.

### Task 5: Readables

**Files:**
- Create: `scripts/Interaction/Readable.gd` (`class_name Readable extends StaticBody3D`)
- Modify: `scripts/Interaction/Props.gd`: add `static func readable(parent: Node3D, at: Transform3D, look: StringName, slot: String) -> StaticBody3D`.
- Modify: `scripts/Level/LevelGameplay.gd`: add `static func readables(parent: Node3D, level) -> Dictionary` (`{name: node}`), and the key `"readables"` in `build_all`. Each `readable` marker becomes `Props.readable(parent, m["transform"], StringName(props.get("kind", "paper")), String(props["slot"]))`, named after its marker.
- Modify: `scripts/Interaction/PlayerFrob.gd`: add `read(readable: Node) -> void` and `reading() -> Node`; the lowering rules gain "more than `READ_LEAVE` from where you began reading".
- Test: `tests/letter_test.gd`

**Interfaces:**
- Consumes:
  - `JobBook.readable(slot)` and `JobState.read_slot()`.
  - From Task 4: `HandSlot.hold_page`/`lower_page`/`page_look`, `PlayerFrob.put_page_away`.
- Produces:
  - `Readable`:
    - `@export var slot := ""` and `@export var look: StringName = &"paper"`.
    - `get_prompt(_player: Node) -> String` returns `"Read"`.
    - `frob(player: Node) -> void` calls `player.frob.read(self)`.
    - `sides() -> PackedStringArray` returns `[text]`; the text is the slot's, or `"<<" + slot + ">>"` if it is missing.
    - `set_held(on: bool) -> void`: a `paper` hides while held and shows again when lowered. A `notice` or `ledger` stays where it is.
  - **Meshes** (ours, flat aged-paper albedo `Color(0.78, 0.72, 0.58)`), each with a thin box collider on the frob ray's layer:
    - notice: a 0.24 × 0.32 m quad with a nail
    - paper: a 0.21 × 0.28 m sheet lying 2 mm over its surface
    - ledger: two 0.18 × 0.25 m leaves open at 160°
  - **Prompts while reading** (`current_actions()`): a paper gives `[[&"frob", "Put down"]]`; a notice or ledger gives `[[&"frob", "Look away"]]`.

- [ ] **Step 1: Write failing tests** (letter_test):
  - `L12 reading a paper holds it up, adds its note, and puts it back`: a `Props.readable` at a known transform with `slot = "duty_orders"`, frobbed:
    - the page is up with `page_look() == &"paper"` and the paper node invisible;
    - `CityState.job.read_slots == ["duty_orders"]` and `notes` has `"office_key"`;
    - after `E`, the page is down, the node is visible and its `global_transform` is unchanged.
  - `L13 walking 2 m away lowers a notice; the mission's travel lowers any page` (Review Focus 1):
    - Reading a notice, then moving the player 2.1 m → page down.
    - Reading a paper, then calling `player.frob.drop_held()` and the put-away hook that `Mission.travel` will call (`put_page_away()`) → page down and paper visible.
  - `L14 a readable whose slot has no entry reads as its placeholder`: `slot = "nothing_here"` → `text_of(0) == "<<nothing_here>>"`, with no crash.
- [ ] **Step 2: Run to see them fail.** `suite.sh letter_test`.
- [ ] **Step 3: Implement.** Also call `put_page_away()` from `maps/mission.gd` `travel()` next to `drop_held()`.
- [ ] **Step 4: Run.** `suites.sh letter_test level_test state_test`. Expected: all pass.
- [ ] **Step 5: Commit.** Message: `feat(job): readables, held in both hands, their notes taken`.

### Task 6: The seal moment, the cues, and their sounds

**Files:**
- Modify: `scripts/Interaction/PlayerFrob.gd`: `_pickup_visual` returns kind `"special"` when the node has meta `special`.
- Modify: `scripts/Interaction/HandSlot.gd`: the `"special"` job.
- Modify: `scripts/Level/DistrictMap.gd`: add `@export var open_with_letter := true`; add `_job_setup()` (called right after `_player()`), `_on_frobbed(target: Node)` and the cues; `_exit_tree` sets `CityState.job.here = &""` when it is this district.
  - `_job_setup()` calls `CityState.job.arrive(district)` and connects `player.frob.frobbed` to `_on_frobbed`.
  - If `open_with_letter and not CityState.job.letter_opened`, it calls `player.frob.open_letter()`. This is the mission opening in the rowboat with the letter up.
- Modify: `maps/mission.gd`: add `static var open_with_letter := true`, given to each map in `go()` before `add_child`.
- Modify: `tests/city_test.gd`, `tests/city_stills.gd`, `tests/transitions_test.gd`: set `open_with_letter = false` on each map before `add_child`. transitions_test sets the mission's static to false at its start.
- Modify: `tools/prepare_sfx.py`: `STINGS` gains `sting_goal_1`/`_2`; new cuts `paper_1..3` and `pencil_1..2`.
- Modify: `scripts/Audio/Sfx.gd`: `MUSICAL += [&"sting_goal"]`; `GAIN` entries for `sting_goal`, `paper` and `pencil` (measured the way the script prints LUFS).
- Create: the audio files under `audio/sfx/`.
- Test: `tests/letter_test.gd`

**Interfaces:**
- Consumes: `JobState.took_loot`, `goal_done`, `noted`; `HandSlot.receive`.
- Produces:
  - **`HandSlot` `"special"` job:** the thing flies into the off hand (0.2 s). It turns about its up axis 200° with a 25° tilt toward the eye over `REGARD_TIME := 1.2` s, then shrinks away (0.16 s) with `Sfx.play_flat(self, &"pickup")`. The turn is cut short at once if `player._is_sprinting()` or `not player.is_on_floor()`, or when an attack starts.
  - **`DistrictMap._on_frobbed(target)`:** if `target is Loot and target.taken`, call `CityState.job.took_loot(String(target.name), target.value)`, `CityState.job.count("loot", target.value)` and, for a special, `count("specials")`.
  - **Cues**, connected in `_job_setup()` and disconnected on exit:
    - `noted`: `player.hud.show_caption("Noted", 1.6)` and `Sfx.play_flat(player, &"pencil")`.
    - `goal_done(id, kind)`: `kind == &"main"` plays `Sfx.play_flat(player, &"sting_goal")`; `&"side"` plays `&"pencil"` only.
  - **The sounds:** audition candidates from the approved packs.
    - `sting_goal` takes: a short, low, resolved swell of about 2-4 s, not a combat hit.
    - `paper`: handling paper or parchment.
    - `pencil`: a short scratch of writing.
    - If no pencil scratch exists in the approved packs, use a short paper scratch and say so in the ledger. Never synthesize.

- [ ] **Step 1: Write failing tests** (letter_test):
  - `L15 the seal turns in the hand, then goes`: give a loot node meta `special` and frob it. `player.hand._job["kind"] == "special"`. After 0.6 s the off item is visible and its rotation y has moved more than 1.0 rad. After 1.8 s the job is empty.
  - `L16 sprinting cuts the turn short`: same, with sprint held from 0.3 s → the job is empty by 0.7 s.
  - `L17 taking the seal plays the goal's sting and notes the way up`: instantiate `maps/city.tscn` (the harbour; it loads in about 3 s from its saved navmesh), await `ready_to_play`, set `Sfx.recording = true`, then `player.frob.target = made["city_harbour"]["pickups"]["the_seal"]` and `player.frob._on_frob()`. Then:
    - `Sfx.recorded` has a `sting_goal` entry;
    - `CityState.job.done.has("seal")`;
    - `notes.has("way_up")`;
    - the HUD caption reads `"Noted"`;
    - `tally["harbour"]["loot"] == 250` and `["specials"] == 1`.
    - This instance keeps `open_with_letter` at its default, and so also checks `L18 a fresh mission opens with the letter up`: right after `ready_to_play`, `player.hand.is_page_up()` and `player.frob.current_actions() == [[&"letter", "Put away"]]`. Lower it before the seal part.
- [ ] **Step 2: Run to see them fail.** `suite.sh letter_test`.
- [ ] **Step 3: Cut the sounds.**
  - Run `python3 tools/prepare_sfx.py --only=sting_goal,paper,pencil`, after adding the entries; extend `--only` if stings are not covered by it.
  - Copy the printed LUFS into `GAIN`.
  - Record every chosen source file in the ledger for the user's approval.
- [ ] **Step 4: Implement** the special job, `_job_setup`, `_on_frobbed` and the cues.
- [ ] **Step 5: Run.** `suites.sh letter_test sound_test interaction_test`. Expected: all pass.
- [ ] **Step 6: Commit.** Message: `feat(job): the seal turned in the hand; the goal's sting; paper and pencil`.

### Task 7: The gate

**Files:**
- Modify: `scripts/Level/DistrictMap.gd`:
  - `_exit_reached` asks `CityState.job.gate_for(area)` before the travel test and before "On to …".
  - Add `const REFUSE_GAP := 4.0` and `var _refused_at := -100.0`.
- Modify: `tests/transitions_test.gd`. Before any harbour-to-old-town travel, give the seal: `CityState.job.took_loot("the_seal", 250)` after the map is up. Add T15.

**Interfaces:**
- Consumes: `JobState.gate_for`, `arrive`.
- Produces:
  - Refusal: when `gate_for` is non-empty, there is no travel and no "On to …". If `Time.get_ticks_msec() / 1000.0 - _refused_at >= REFUSE_GAP`, show `player.hud.show_caption(gate["text"], 4.0)` and print `city: gate: refused (%s)`.
  - With the gate met, the behaviour is as today.

- [ ] **Step 1: Write failing tests.** transitions_test:
  - `T15 without the seal no way up leads on; with it, it does`:
    - In the mission with a fresh job, put the player in the Sea Gate exit's box. After 3 s, `mission.map.district == &"harbour"` and the HUD caption text begins `"<<"`.
    - Leave the box and come back within 2 s: the caption timer was not reset (no spam).
    - `took_loot("the_seal", 250)`, step in again → the old town within `CROSSING` + GRACE.
- [ ] **Step 2: Run to see it fail.** `suite.sh transitions_test 3000000`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `suite.sh transitions_test 3000000` and `suite.sh state_test`. Expected: all pass, T1-T14 included.
- [ ] **Step 5: Commit.** Message: `feat(job): the ways up turn you back without the seal`.

### Task 8: The theft noticed

**Files:**
- Modify: `scripts/Interaction/Chest.gd`: `_opened_by` set on each `frob`.
- Modify: `scripts/Level/LevelGameplay.gd`:
  - `chests()` adds each chest to group `&"chests"`.
  - `bells()` names each bell after its marker (`bell.name = m["name"]`, e.g. `tower_bell`).
  - Add `static func fill_chests(chests: Dictionary, pickups: Dictionary) -> void`, called at the end of `build_all`.
  - Add `const INSIDE := 0.7`.
- Modify: `scripts/AISystem/GuardLife.gd`:
  - `const CHEST_RANGE := 12.0`.
  - In `_look_for_oddities`, scan chests **before** doors: `left_open()`, not noticed, near-filter as for doors, `_watch_for(chest, [chest.global_position + Vector3.UP * 0.3], CHEST_RANGE, eye, step)`, then `_notice(chest, &"chest", at)`.
  - `_notice` for `&"chest"`: `guard.say(&"odd_door")` and `raise_alarm(DOOR_ALARM)`; he goes to the nav point nearest the chest.
  - `deal_with_oddity` for `&"chest"`: if `thing.robbed()`, call `guard.discover_theft(thing)` and leave it open; otherwise if it is open, `thing.frob(guard)`.
- Modify: `scripts/AISystem/Guard.gd`: add `discover_theft` and `send_to_bell_for`.
- Create: `tests/theft_test.gd`, `tests/theft_test.tscn` (the fixture level, as `state_test._build` makes it, with its navmesh baked as state_test does)

**Interfaces:**
- Consumes: `JobState.notice_theft()`, `JobBook.shout("theft")`, the `AlarmBell` group `&"alarm_bells"`.
- Produces:
  - `Chest`:
    - `opened_by() -> Node`.
    - `left_open() -> bool`: `is_open` and the opener is not in group `&"guards"` (or is null).
    - `held_specials: Array[String]` and `hold_special(loot: Node) -> void` (keeps the name and a WeakRef).
    - `robbed() -> bool`: any held special whose ref is gone or whose `taken` is true.
  - `LevelGameplay.fill_chests`: each pickup with meta `special` within `INSIDE` m of a chest's `global_position` is `hold_special`ed by that chest.
  - `Guard.discover_theft(chest: Node3D) -> void`:
    - Sets `last_known_position = chest.global_position` and SEARCHING (as `_discover` does).
    - `_chorus(&"theft", JobBook.shout("theft"), 1, 0.0, true)` and `shout()`.
    - `_life._garrison().raise_alarm(1.0)`.
    - If `CityState.job.notice_theft()` returns true, the nearest alarm bell's nearest other able guard (not knocked out, not in COMBAT) gets `send_to_bell_for(chest.global_position)`.
  - `Guard.send_to_bell_for(where: Vector3) -> void`: sets `last_known_position = where`, `has_last_known = true`, then `send_to_bell()`.

- [ ] **Step 1: Write failing tests** in theft_test:
  - `R1 a chest left open by the player is an oddity; one opened by a guard is not`: `left_open()` true after the player frobs it open; false after a guard node (group `guards`) frobs it open.
  - `R2 a special inside a chest is held by it`: `fill_chests` on a chest and a special Loot 0.2 m inside → `held_specials == [name]`. A Loot 1.5 m away is not held.
  - `R3 robbed when the special is taken`: frob the Loot with a player → `robbed()` true. A fresh chest whose special node was freed before the frob (as a revisit makes it) is also `robbed()`.
  - `R4 a guard who sees an open chest goes and shuts it`: a relaxed guard 6 m off with the chest lit and in his view → within 20 s the chest `is_open == false`, and the garrison alarm is ≥ 0.2 and < 1.0.
  - `R5 an open robbed chest raises the full alarm and sends a man to the bell`: plus a bell and a second guard by it → within 25 s: `CityState.job.fact(here, &"theft_noticed") == true`, the garrison alarm is 1.0, and the bell's `rung` signal was emitted by the second guard.
  - `R6 found twice, counted once` (Review Focus 4): after R5, knock out the finder and put a third guard in view of the same chest → within 20 s he deals with it, `tally[here]["alarms"] == 1`, and the bell is not rung a second time by this chest.
  - `R7 a closed robbed chest goes unnoticed`: the special taken, the chest shut by the player, a guard in view for 20 s → `theft_noticed` unset and alarm 0.
  - Before building, set `CityState.job.reset()` and `arrive(&"fixture")`.
- [ ] **Step 2: Run to see them fail.** `suite.sh theft_test`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `suites.sh theft_test stealth_test stealth_polish_test hunt_test squad_test state_test life_test`. Expected: all pass.
- [ ] **Step 5: Commit.** Message: `feat(job): a chest left open is noticed; a robbed special raises the alarm`.

### Task 9: Talk knows where it is, and what you overhear

**Files:**
- Create: `scripts/AISystem/Talk/Earshot.gd`
- Modify: `scripts/AISystem/Talk/TalkScript.gd`:
  - `KEYS += ["where"]`; `block["where"]: StringName` (default `&""`), validated as `garrison` or a registry district.
  - `EMOTE_PREFIXES += ["note:"]`.
- Modify: `scripts/AISystem/Talk/TalkFacts.gd`:
  - `WHEN_WORDS += ["theft_noticed"]`, `WHEN_NAMED += ["done"]`, `SITUATIONS += ["hail"]`.
  - `world()` sets `facts["done"] = CityState.job.done` and `facts["theft_noticed"] = CityState.job.fact(CityState.job.here, &"theft_noticed") == true`.
  - Add `static func place_now() -> StringName`: `CityState.job.here`, or `&"garrison"` when that is empty.
- Modify: `scripts/AISystem/Talk/TalkDirector.gd`:
  - `_available(conv)` is false when `conv["where"] != &""` and `!= TalkFacts.place_now()`.
  - `_say` takes the `note:` emotes out before any emote is played. For each one, if a node in group `&"player"` is `Earshot.heard(speaker, player)`, it calls `CityState.job.learn(id)`.
- Modify: `scripts/UI/StealthHUD.gd`: `_on_bark` and `_on_alert` use `Earshot.heard(guard, player)` in place of the `SUBTITLE_RANGE` distance test; `SUBTITLE_RANGE` is removed in favour of `Earshot.RANGE`.
- Modify: `scripts/Level/LevelLoader.gd:386-392`: landmark nodes join group `&"landmarks"` with meta `&"landmark"` = label (meta `label` kept).
- Modify: `data/talk/*.talk`: add `where: garrison` to each conversation that names garrison people or places (the captain, Brand, Tam and the cast sheet's other names, the yard, the chapel, the barracks, the Moon-Glass).
- Create: `docs/superpowers/refs/2026-10-03-talk-where.md`: a table of every conversation id, its `where`, and the words that decided it, for the user's review.
- Test: `tests/talk_test.gd`

**Interfaces:**
- Produces: `Earshot.RANGE := 22.0`; `Earshot.heard(speaker: Node3D, listener: Node3D) -> bool`, which is the distance test plus `speaker._line_of_sight(speaker.eye_position(), listener head, listener)` when the speaker has it, else a world ray (mask 1).

- [ ] **Step 1: Write failing tests** (talk_test):
  - `T50 where: keeps a conversation to its place`: with `CityState.job.here = &"harbour"`, a `where: garrison` conversation is not `_available`, a `where: harbour` one is, and an untagged one is. With `here = &""`, the garrison one is.
  - `T51 done() and theft_noticed are facts`: `TalkFacts.holds("done(seal)", world)` is false, then true after `took_loot("the_seal", 250)`. `holds("theft_noticed", …)` is true after `notice_theft()`.
  - `T52 a [note:] line is heard in range and not through a wall`: two guards in a small built room with the player 5 m off in the open → the note is learnt. Then a fresh job, with a 4 m-tall box wall between them, or 25 m off → not learnt. The emote is never passed to `Guard.emote` (spy on the rig/voice, or check `GuardVoice`'s last emote).
  - `T53 every [note:] in the talk files names a job note` (Review Focus 5): scan `TalkScript.library()` turns for `note:` emotes; each id is in `JobBook.library()["notes"]`.
  - `T54 the landmarks are named`: a level built from the fixture or a hand-made `landmark` marker via `LevelLoader` → its node is in `landmarks`, and `Comms.landmark_near(tree, at)` returns its label.
  - `T55 subtitles stop at walls`: `StealthHUD._on_bark` with the guard behind the wall leaves `_subtitle.text` unchanged.
- [ ] **Step 2: Run to see them fail.** `suite.sh talk_test 3000000`.
- [ ] **Step 3: Implement**, then tag the talk files and write the review list.
- [ ] **Step 4: Run.** `suites.sh talk_test showcase_test intruder_test cinema_test` (each with `3000000`), then `suites.sh life_test habits_test routines_test stations_test`. Expected: all pass. The garrison's talk still plays there because `place_now()` is `garrison`.
- [ ] **Step 5: Commit.** Message: `feat(talk): conversations know their place; overheard notes; guards name the city's landmarks`.

### Task 10: The harbour's hails and its conversations

**Files:**
- Modify: `scripts/Level/DistrictMap.gd`:
  - Add `func _hails() -> Array` (default `[]`) and `const HAIL_EVERY := 2.0`.
  - A Timer started in `_job_setup()` runs `_hail_tick()`. For each `[a_name, b_name, reach]` whose men are both in `guards`, neither is knocked out, and they are within `reach` m, it calls `TalkDirectorScript.of(a).call_pair(&"hail", a, {"b": b})`.
- Modify: `maps/city.gd`: `_hails()` returns:
  - `[["Fernao", "Gaspar", 30.0], ["Duarte", "Inigo", 12.0], ["Rodrigo", "Tome", 8.0]]`
  - `["Baltasar", "Duarte", 10.0], ["Baltasar", "Inigo", 10.0], ["Leonor", "Duarte", 9.0], ["Leonor", "Inigo", 9.0]`
- Create: `data/talk/harbour.talk`. Every conversation has `where: harbour` and `when: situation:hail` plus its own terms. Lines are `<<...>>` with `# intent:` comments, and the hint lines carry `[note:<id>]`.
  - `harbour_tower_bell`: A `name(Fernao)`, B `name(Gaspar)`; `at_ease`; cooldown 4m; note `tower_bell`.
  - `harbour_office_key`: A `name(Baltasar)`, B `name(Duarte)|name(Inigo)`; `at_ease`; 4m; note `office_key`.
  - `harbour_dark_bays`: A `name(Duarte)`, B `name(Inigo)`; `at_ease`; 4m; note `dark_bays`.
  - `harbour_ways_up`: A `name(Rodrigo)`, B `name(Tome)`; `at_ease`; 4m; note `ways_up`.
  - `harbour_cabin_key`: A `name(Leonor)`, B `name(Duarte)|name(Inigo)`; `at_ease`; 4m; note `cabin_key`.
  - `harbour_theft_1`, `_2`, `_3`: A `any`, B `any`; `theft_noticed`; cooldown `once`; no notes.
- Test: `tests/talk_test.gd`

- [ ] **Step 1: Write failing tests** (talk_test):
  - `T56 the harbour's talk parses, in its place`: `TalkScript.library()["errors"]` is empty; the 8 `harbour_*` conversations exist with `where == &"harbour"`.
  - `T57 a hail plays the pair's conversation`: two guard nodes named Rodrigo and Tome, at ease, 5 m apart, `here = &"harbour"`, `call_pair(&"hail", rodrigo, {"b": tome})` → true; the director's `played()` holds `"harbour_ways_up"`.
  - `T58 after a theft the hail is the theft's`: with `notice_theft()` done and the men not at ease, the same call plays a `harbour_theft_*`.
- [ ] **Step 2: Run to see them fail.** `suite.sh talk_test 3000000`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** `suite.sh talk_test 3000000`. Expected: all pass.
- [ ] **Step 5: Commit.** Message: `feat(city): the harbour's men hail each other, and what they say is the player's to overhear`.

### Task 11: The tally

**Files:**
- Create: `scripts/Level/Tally.gd`
- Modify: `scripts/UI/LoadingScreen.gd`: add `static var holds := true`, `show_tally(title: String, rows: Array) -> void` and `hold() -> void`.
- Modify: `scripts/Level/DistrictMap.gd`:
  - After `LoadingScreen.open`: if `_mission() != null and CityState.job.last_left != &""`, `screen.show_tally(Districts.label(job.last_left), job.tally_rows(job.last_left))`.
  - Before `screen.close()`: `await screen.hold()` when a tally was shown.
  - In `_job_setup()`, add a `Tally` child.
- Modify: `tests/transitions_test.gd`: set `LoadingScreen.holds = false` at its start, except inside T16. Add T16 and T17.

**Interfaces:**
- Consumes: `JobState.count`, `set_total`, `tally_rows`, `notice_theft`.
- Produces:
  - `Tally extends Node`, `setup(map: Node) -> void`, `const SEEN_MERGE := 10.0`.
  - On setup it sets the totals from the map's own levels' markers: `loot_total` (the sum of loot `value`s), `specials_total` (count of `special`) and `read_total` (count of `readable`).
  - Every 1.0 s it connects to new members of `&"guards"`:
    - `knocked_out` → `knockouts`
    - `died` → `kills`
    - `found_body` → `bodies_found`
    - `alert_changed(new, _)` with `new == 4` (COMBAT) and the guard's `_target == player` → `seen`, unless the last `seen` was under `SEEN_MERGE` s ago.
  - It also connects to `&"alarm_bells"`' `rung` → `alarms`.
  - Each `_process` adds `delta / Engine.time_scale` to `seconds` (process mode PAUSABLE, so pause and loading do not count).
  - `LoadingScreen.show_tally`: under the status line, a two-column `GridContainer` in the screen's serif, 20 pt: the labels in `DIM`, the values in `INK`. The title row is the district label at 26 pt.
  - `LoadingScreen.hold`: if `holds` is false it returns at once. Otherwise it shows `"[%s] Go on" % StealthHUD.key_name(&"frob")` (a static helper; preload the HUD script), pauses the tree, waits for `frob` (just pressed, with the screen in `PROCESS_MODE_ALWAYS`), then unpauses.

- [ ] **Step 1: Write failing tests** (transitions_test):
  - `T16 the harbour's tally greets you on the way up, and waits for you`: with `holds = true`, the seal given and 250 loot counted, go through the Sea Gate.
    - The new map's `LoadingScreen` shows `"The harbour"` and a row `["Loot", "250 of <harbour total>"]`.
    - After the old town is built, `get_tree().paused == true` and `mission.settled == false`.
    - Press `frob` → within 1 s the screen is gone and the tree unpaused.
  - `T17 the tally adds up over visits; the theft counts once` (Review Focus 4): notice a theft in the harbour (`CityState.job.notice_theft()` while there), go up, come back down, `notice_theft()` again → `tally["harbour"]["alarms"] == 1` and `seconds` larger than after the first visit.
  - In `job_test`, add `J15 Tally counts what happens`: on the fixture level (as theft_test builds it), knock out a guard → `knockouts == 1`. Set a guard to COMBAT on the player twice 3 s apart → `seen == 1`; again 11 s later → `seen == 2`.
- [ ] **Step 2: Run to see them fail.** `suite.sh transitions_test 3000000` and `suite.sh job_test`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** The same two suites, plus `suite.sh city_test`, since its C15 loading-screen check must still pass with no tally at a map's own start.
- [ ] **Step 5: Commit.** Message: `feat(job): the district's tally on the way out`.

### Task 12: The harbour's markers, rounds and checks

**Files:**
- Modify: `tools/level/layouts/lay.py`: in `route()`, a point may carry a fifth element, its own wait (`p[4] if len(p) > 4 else wait`).
- Modify: `tools/level/layouts/harbour/markers.py`:
  - `captains_ring` and `signet` gain `"special": True`.
  - Seven `readable` markers. Each lies on a surface and is reachable; check with the hole scan's floor ray, and see `inspect-geometry-closely`.
    - `night_orders`: notice, on the golden tower's wall beside `tower_door`, at eye height, facing the mole's walk.
    - `duty_orders`: paper on the watchman's desk, 0.6 m from `customs_office_key` (6.0, 3.35, -13.0).
    - `curfew`: notice on a Terreiro arcade pier near `hide_terreiro_arcade` (-92.5, 2.5, -40.0).
    - `captains_log`: ledger on the cabin's table or chest top near `cabin_strongbox`.
    - `smugglers_scrawl`: paper on the cave beach near `smugglers_chest` (234, 1.35, 21).
    - `fort_note`: paper in the fort near `powder_money` (-80, 4.1, 196).
    - `harbourmasters_letter`: paper on the office desk near `office_purse` (9.0, 7.36, -28.15).
  - **Rounds:**
    - **`customs_round`:** after (10.5, 2.5, -24.0) it climbs the customs stair (find its foot and head in `kit_customs.STAIR`/`_stair()`) to the landing outside `office_door` (7.0, 6.5, ~-21.0). It waits 2 s there facing the door, comes back down, and passes out through an unlocked door to the quay at `lm_customs` (1.6, 2.5, -3.5) for a 4 s wait.
    - **`mole_round`:** its far end moves to the golden tower's door and waits 4 s there.
    - **`quays_round`** is unchanged. Duarte and Inigo cross on its out-and-back.
  - Update the plan-era comment at the round's definitions.
- Run:
  - `cp -R ../../../textures/ps2 textures/` (gitignored; do not add).
  - `tools/level/level.sh build city_harbour`, without `--force`. If the edit guard refuses, STOP and ask the user.
  - `tools/level/level.sh export city_harbour`, then `tools/level/level.sh navmesh harbour`.
- Test: `tests/city_test.gd` gains a step `job` (`["job", _job]`) with checks C23-C30.

**Checks:**
- `C23 standalone, no way up leads on without the seal`: put the player in each of the four old-town exits' boxes (by `to == &"old_town"`). The caption begins `"<<"`, and no exit prints `On to`. After `took_loot("the_seal", 250)` the caption is `"On to <label>"`.
- `C24 the harbour's readables are built, each with its slot`: `made["city_harbour"]["readables"].size() == 7`, and each node's `slot` is in `JobBook.library()["readables"]`.
- `C25 every word the harbour points at exists` (Review Focus 5):
  - every `took(x)` in `harbour.job` names a loot marker in the level;
  - every special loot marker is some side or main goal's `took(...)`;
  - every gate's `to(...)` is a district some exit leads to.
- `C26 each hail pair's rounds bring them within reach`: for each `_hails()` pair, the minimum distance between A's route waypoints (or post) and B's is ≤ reach. For Fernao and Gaspar this uses the new tower-door point.
- `C27 the Sea Gate pair's hint is overheard`: unfreeze Rodrigo and Tome, put the player 6 m in front of them in the open, `here == &"harbour"`. Within 90 s of game time, `harbour_ways_up` plays and `CityState.job.notes.has("ways_up")`. Put them back after.
- `C28 Baltasar's round reaches the office landing`: a navmesh path from his first waypoint to the landing waypoint ends within 0.5 m of it.
- `C29 a careless theft in the harbour is found`: open `office_door` and `seal_chest` as the player, take `the_seal`, put Baltasar at the landing waypoint (released, the rest frozen but Gaspar), and keep the office candle lit. Within 30 s, `theft_noticed` and `tower_bell` rung.
- `C30 a harbour guard names the golden tower`: `Comms.landmark_near(tree, lm_golden_tower's position + (2, 0, 0)) == "the golden tower"`.

- [ ] **Step 1: Write the failing checks** C23-C30 in `city_test.gd` as the `job` step.
- [ ] **Step 2: Run to see them fail.** `bash .superpowers/sdd/2026-10-03-harbour-job/one_step.sh job`. Expected: FAIL on C24-C29, since the markers and rounds are not yet there.
- [ ] **Step 3: Change the layout**, then build, export and rebake as above.
- [ ] **Step 4: Run.** `one_step.sh job`, then the whole `suite.sh city_test` and `python3 -m pytest tools/level -q`. Expected: all pass, C1-C22 included. Record the harbour's `loot_total` in the ledger.
- [ ] **Step 5: Look.**
  - Take daylight close-up stills of each readable and of Baltasar's landing; use the workspace's stills script from `../city-harbour/.superpowers/sdd/2026-09-29-city-harbour/stills.sh`, adapted.
  - Check each lies on its surface with no float or clip.
  - Stills showing bought textures stay out of git.
- [ ] **Step 6: Commit.** Commit the layout, the exported harbour, the navmesh and the tests: `git add tools/level assets/level/city_harbour assets/level/source/city_harbour.blend assets/level/navmesh/harbour.scn tests/city_test.gd`. Check `git status` for anything under `textures/` first. Message: `feat(city): the harbour's readables, specials and rounds for the job`.

### Task 13: The whole branch, verified

**Files:** none new, except the ledger.

- [ ] **Step 1: Run every suite.** `bash .superpowers/sdd/2026-10-03-harbour-job/all_suites.sh`. Expected: every suite passes, 59 suites (56 + job, letter, theft), with no `SCRIPT ERROR`.
- [ ] **Step 2: Run the Python tests.** `cd tools/level && python3 -m pytest -q`. Expected: all pass.
- [ ] **Step 3: Bench.** Run the harbour's bench as before (`--fps-report=40` on `maps/city.tscn`). Expected: within 3 fps of the baseline in the ledger (101.8 fps, p99 16.6 ms on main c99b516).
- [ ] **Step 4: List the words left to write.** `suite.sh job_test` and take its `WORDS:` lines; add the `<<` lines of `data/talk/harbour.talk`. Write the list into the ledger and into the final message for the user.
- [ ] **Step 5: Sounds for the user's ear.** List each new sound with its source file (from the ledger) for approval.
- [ ] **Step 6: Review list for the user.** Point to `docs/superpowers/refs/2026-10-03-talk-where.md`.
- [ ] **Step 7: Update the docs.**
  - `docs/systems/jobs.md` gets anything learnt.
  - `docs/systems/world.md` gets the `readable` marker.
  - The spec's status line becomes "built".
  - Commit with message `docs(job): the harbour's job built; what is left to write`.
- [ ] **Step 8: Finish.** Use superpowers:finishing-a-development-branch. Do not merge or push without the user's word.
