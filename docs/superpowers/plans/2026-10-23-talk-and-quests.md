# Talk and Quests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build handcrafted, branching conversations with NPCs: quests and items given and taken, reactions carried by words and a shade's light, memory that lasts forever, and NPC types. Prove it with two shade characters (the curandera and the librarian) in a gym.

**Architecture:**
- Hand-written `.dialogue` files are read by `DialogueBook`, in JobBook's style.
- A node-free `Conversation` runner plays a character's beats against `PeopleState`. PeopleState is permanent talk memory on `CityState`, never reset by `begin()`, and it shares condition terms with `JobState`.
- `TalkBox` (mockup A) shows the runner. `Shade` is the frobbable NPC: a wardrobe body under a spirit shader.

**Tech Stack:** Godot 4.5.1, GDScript, headless test scenes in the project's own `_check` style.

**Spec:** `docs/superpowers/specs/2026-10-23-talk-and-quests-design.md`. Read it with this plan.

## Global Constraints

- **Branch:** `talk-quests` in its own worktree, cut from `free-run`. The main checkout has uncommitted work; don't touch it.
- **Test command:** `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . res://tests/<suite>.tscn`. A suite prints `N pass, M fail`; zero fails means it passed.
- **Words:** every text the player reads is a `<<placeholder>>`. The user writes all words, so Claude invents no dialogue.
- **Files:** character files are `data/dialogue/<character>.dialogue`, and type files are `data/dialogue/types/<type>.dialogue`. Never touch `data/talk/*.talk`, the guards' format.
- **Errors:** every error reads `<file>:<line>: <what>`, as JobBook's do.
- **Code style:** match the surrounding code. Plain-English `##` doc comments, `const X := preload(...)`, static parse functions, tabs, and blank lines around blocks, as in `scripts/Level/JobBook.gd`.
- **Assets:**
  - No downloaded VFX. Wisps use the project's own `res://assets/vfx/smoke.png` / Vfx sheets.
  - Only NOX voices: the Sfx sounds `murmur`, `nod`, `hm` with suffixes `""` (voice `male`), `_b` (`male_b`) and `_f` (`female`).
  - Existing animation clips only: `Idle`, `Idle_Talking`, `Yes`, `Idle_No`.
- **Bodies:** the curandera uses `duelist`, the librarian uses `arms_master`.
- **Colours:** copal amber `Color(1.0, 0.62, 0.22)`, ink violet `Color(0.55, 0.38, 1.0)`, marigold `Color(0.95, 0.69, 0.2)`, cochineal `Color(0.76, 0.16, 0.16)`, box black `Color(0.043, 0.043, 0.043)`.
- **Never call a visual defect harmless.** Fix it, or name it as unfinished.

## Review Focus

1. **Hands busy.** Frobbing a shade while carrying, shouldering or reading should never open the box. The prompt reads as it does for any frobbable whose action is blocked. (Task 6, check B4)
2. **Hurt mid-conversation.** Taking damage while talking closes the box at once and hands back control, without setting `walked_off`. (Task 6, check B5)
3. **Every option filtered out.** A beat whose options all fail their `[if]` must not trap the player. A `<<…>>` option that ends the conversation appears instead, and load-time checks warn about the beat. (Task 4, check C9)
4. **Taking what you don't have.** `take(x)` on an option without `[if has(x)]`, picked while not carrying x, must not record `gave` or break the belt. It is a no-op, and load-time checks warn. (Task 4, check C10; Task 2, check D14)
5. **Accented speaker names.** "Doña Amparo [dim]: …" must parse as a spoken line, not as an unknown key. (Task 1, check D4)

---

## File map

| File | Responsibility |
|---|---|
| `scripts/Level/Terms.gd` (new) | The condition and effect vocabulary shared by JobBook and DialogueBook: `term_error`, `effect_error`, `split_top` |
| `scripts/Level/DialogueBook.gd` (new) | Parses `.dialogue` files, merges types, checks links, and holds the library |
| `scripts/Level/PeopleState.gd` (new) | Permanent talk memory, talk goals and talk notes, save/load |
| `scripts/Level/JobState.gd`, `CityState.gd`, `JobBook.gd`, `scripts/UI/LetterText.gd` (modify) | Delegate the new terms, keep `people` through `begin()`, list talk goals and notes on the letter |
| `scripts/Interaction/Conversation.gd` (new) | The node-free runner |
| `scripts/Interaction/Props.gd` (modify) | `look_mesh(look)`; `belt_mesh` falls back to a dialogue item's look |
| `scripts/Visual/shade.gdshader` (new), `scripts/Interaction/Shade.gd` (new) | The spirit look, and the talkable NPC |
| `scripts/UI/TalkBox.gd` (new) | The mockup-A box, the live portrait, input |
| `scripts/Interaction/PlayerFrob.gd`, `scripts/PlayerController.gd` (modify) | `talk(shade)`, `talk_hold` |
| `data/dialogue/**` (new) | Two types, two characters, test-quest placeholders |
| `maps/talk_gym.gd/.tscn` (new) | The gym |
| `tests/dialogue_test.gd/.tscn` (new) | Suite D (book), P (people), C (conversation), S (shade), B (box), Q (quest) |
| `tests/visual/stage_shade.gd/.tscn` (new) | Windowed stills for review |
| `docs/systems/dialogue.md` (new), `docs/systems/README.md` (modify) | The writer's guide |

---

### Task 1: Terms and the `.dialogue` parser

**Files:**
- Create: `scripts/Level/Terms.gd`, `scripts/Level/DialogueBook.gd`, `tests/dialogue_test.gd`, `tests/dialogue_test.tscn` (same shape as `tests/job_test.tscn`)
- Modify: `scripts/Level/JobBook.gd` (`_term_error` delegates unknown words to `Terms.term_error(term, false)`)

**Interfaces:**
- Produces:
  - `Terms.term_error(term: String, in_character: bool) -> String`: `""` if fine. It accepts JobBook's terms plus `said(x)`, `said(c.x)`, `has(x)`, `gave(x)`, `gave(c.x)`, `mood>=n`, `mood<=n`, `mood(c)>=n`, `mood(c)<=n`, `purse>=n` and `met`, wrapped in `not(...)` or not. When `in_character` is false (a `.job` file), undotted `said`/`gave`, bare `mood` and `met` are errors.
  - `Terms.condition_error(cond: String, in_character: bool) -> String`
  - `Terms.effect_error(effect: String) -> String`: accepts `set(f)`, `clear(f)`, `give(i)`, `take(i)`, `pay(n)`, `charge(n)`, `goal(g)`, `done(g)`, `note(n)`, `mood(+n)`, `mood(-n)`, and `shade(flare|dim|gutter|calm)`.
  - `Terms.split_top(text: String) -> PackedStringArray`: splits on commas outside parentheses.
  - `DialogueBook.parse(text: String, file: String) -> Dictionary`, which returns `{"entries": [...], "errors": [...], "warnings": [...]}`. Each entry is `{kind, id, keys, body, source, sources}`. `body` is an Array of line dicts:
    - `{"type": "say", "speaker": String, "cues": Array[StringName], "text": String, "source"}`
    - `{"type": "sense", "school": String, "if": String, "text", "source"}`
    - `{"type": "pause", "seconds": float, "source"}`
    - `{"type": "option", "type_only": bool, "if": String, "special": bool, "text", "to": String ("end" or a beat id), "do": Array[String], "source"}`
    - `{"type": "goto", "to": String, "source"}`
- Block kinds and keys: `character` (`name`, `type`, `colour`, `body`, `voice`, `intent`), `beat` (`when`, `do`, `intent`), `item` (`name`, `look`, `intent`), `goal` (exactly JobBook's goal keys), `note` (`intent`, `text`).
- `goal` and `note` keep JobBook's `text:` rule, a single line or `text:` then lines up to the next `==`. In a `beat`, a line `<word>: …` whose word is a beat key is a key. Anything else is a body line.
- **Body-line grammar** (whitespace trimmed; `#` lines are comments):
  - A spoken line is `^(?<speaker>[\p{L}' .-]+?)\s*(?<cues>(\[[a-z]+\]\s*)*):\s*(?<text>.+)$`. The allowed cues are `flare`, `dim`, `gutter`, `calm`, `nod` and `shake`.
  - A sense line is `^Sense (?<school>[a-z]+)\s*(\[if (?<if>[^\]]+)\])?\s*:\s*(?<text>.+)$`, matched before the spoken pattern.
  - A pause is `^\[pause (?<s>[0-9.]+)\]$`.
  - An option is `^(?<m>>>?)\s*(\[if (?<if>[^\]]+)\])?\s*(?<sp>!)?\s*(?<text>.+?)\s*->\s*(?<to>[A-Za-z0-9_]+)\s*(\{do:\s*(?<do>.*)\})?$`.
  - A goto is `^->\s*(?<to>[A-Za-z0-9_]+)$`.

- [ ] **Step 1: Write the failing tests** in `tests/dialogue_test.gd`, using job_test's `_check` and results printing. The checks:
  - `D1 a beat's body parses into say/sense/pause/option/goto in order`. A fixture beat has one of each kind. Assert the `type` sequence is `["say","sense","pause","option","option","goto"]` and that the `special`, `if`, `to` and `do` fields equal the fixture's values. For example, `do == ["give(the_book)", "mood(+1)"]`.
  - `D2 cues are read off the speaker`. `Amparo [dim] [nod]: <<x>>` gives `cues == [&"dim", &"nod"]` and `speaker == "Amparo"`.
  - `D3 errors name file and line`. Six broken fixtures, each giving exactly one error containing `t.dialogue:<line>`: an unknown kind, an unknown cue `[wobble]`, a bad condition `when: stole(x)`, a bad effect `do: steal(x)`, an option with no `->`, and a body line outside any beat.
  - `D4 an accented speaker is a spoken line`. `Doña Amparo [dim]: <<Stand still.>>` parses as a `say` with `speaker == "Doña Amparo"` and no error.
  - `D5 the new terms`:
    - `Terms.condition_error("said(met), has(the_book), mood>=2, not(gave(librarian.the_book)), purse>=3, met", true) == ""`
    - `Terms.condition_error("said(met)", false) != ""`
    - `JobBook.condition_error("said(curandera.asked_book)") == ""`
- [ ] **Step 2: Run** `.../Godot --headless --fixed-fps 60 --path . res://tests/dialogue_test.tscn`. Expected: a parse error or FAIL, because DialogueBook doesn't exist yet.
- [ ] **Step 3: Implement `Terms.gd`, then `DialogueBook.parse`.** Reuse JobBook's block loop shape (`==` headers, `seen` duplicates, skipping) rather than inventing a new one. Change JobBook `_term_error` so a word it doesn't know falls through to `Terms.term_error(term, false)`. The job suite must still pass.
- [ ] **Step 4: Run** dialogue_test and `res://tests/job_test.tscn`. Expected: D1–D5 PASS, and job_test has 0 fail.
- [ ] **Step 5: Commit** with `feat(dialogue): the .dialogue format and its shared terms`.

### Task 2: The library: types, links and checks

**Files:**
- Modify: `scripts/Level/DialogueBook.gd`, `tests/dialogue_test.gd`
- Create: `tests/fixtures/dialogue/` (two characters and one type, used only by tests)

**Interfaces:**
- Consumes: `DialogueBook.parse`, Terms (Task 1)
- Produces:
  - `DialogueBook.load_dir(path := "res://data/dialogue") -> Dictionary`, the library. It returns:
    - `characters`: `{id: {id, name, type, colour: Color, body: StringName, voice: StringName, beats: {id: beat}, openers: Array[String] (file order, type openers after the character's), source}}`
    - `types`: the same shape, for type files
    - `items`: `{id: {id, name, look: StringName, source}}`
    - `goals`: an Array of JobBook-shaped goals with `district = &"people"`
    - `notes`: `{id: entry}`
    - `errors`, `warnings`
  - `library()`, `reload()`, `character(id) -> Dictionary`, `item(id) -> Dictionary`, `placeholders(lib := {}) -> Array[String]`
  - `check_alone(files: Dictionary) -> Dictionary`: `{filename: text}`, gathered like `load_dir`, for tests.
  - `DialogueBook.colour_of(value: String) -> Color` for the named swatches `copal`, `ink`, `marigold`, `cochineal` and `teal` (`Color(0.18,0.55,0.55)`), or hex.
- **Type merge:**
  - A character with `type: t` gets every beat of type `t` it doesn't define itself, with the same id. Its own beat wins.
  - Each of its openers (beats whose id begins with `open`) gets the type's `>>` options appended. They go before the opener's own options whose `to` is `end`, in type-file order.
  - A type's `colour`/`voice`/`body` are defaults under the character's own.
  - `{name}` in type text is left in place; Conversation substitutes it.
  - A character file may be absent for a type-only NPC. `character("curandera_stand_in")` is not required; Shade asks for `type_character(type_id, name)` instead.
  - `DialogueBook.type_character(type_id: String, display_name: String) -> Dictionary` builds a character from the type alone.

- [ ] **Step 1: Write the failing tests.**
  - `D6 the library gathers characters, types, items, goals and notes`. On the fixtures, `characters.keys()` sorted equals `["fx_curandera","fx_librarian"]`, `types.has("fx_trade")`, `items.has("fx_book")`, and the goals include `fx_bring_book`.
  - `D7 a type's >> options join every opener, before its end options`. The `fx_curandera` opener `open` has options texts in the order own, own, type, end.
  - `D8 the character's own beat overrides the type's`. `characters.fx_curandera.beats.limpia.source` begins with `fx_curandera.dialogue:`.
  - `D9 a type-only NPC`. `type_character("fx_trade", "Stand-in").beats.has("open")` and its `name == "Stand-in"`.
  - `D10 broken links are errors with file:line`, one each:
    - a `-> nowhere`
    - `give(no_item)`
    - `said(nobody.flag)`
    - `type: no_type`
    - a character with no opener lacking `when:`
  - `D11 an unreachable beat is a warning, not an error`.
  - `D12 the shipped files load clean`. `DialogueBook.load_dir().errors.is_empty()`. Before Task 7 this passes on an empty folder, so create `data/dialogue/.gdkeep`.
  - `D13 placeholders list file:line for dialogue` too, and print them as `WORDS:` lines, as job_test does.
  - `D14 take(x) on an option without [if has(x)] warns` (Review Focus 4).
  - `D15 a beat whose options can all be filtered warns` when every option has an `[if]` (Review Focus 3).
- [ ] **Step 2: Run** dialogue_test. Expected: D6–D15 FAIL.
- [ ] **Step 3: Implement** `load_dir` and `_gather`/`_merge_types`/`_link` in DialogueBook. Types are read from the `types/` subfolder first, so characters can merge them. Link checks resolve a dotted name against the gathered characters.
- [ ] **Step 4: Run** dialogue_test. Expected: D1–D15 PASS.
- [ ] **Step 5: Commit** with `feat(dialogue): the library, NPC types and its link checks`.

### Task 3: PeopleState, memory that lasts forever

**Files:**
- Create: `scripts/Level/PeopleState.gd`
- Modify:
  - `scripts/Level/CityState.gd`: add `var people: RefCounted = PeopleStateScript.new()`. `begin()` calls `people.begin_mission()` and never resets people, then sets `job.people = people`.
  - `scripts/Level/JobState.gd`: add `var people: RefCounted = null`. `_term` delegates unknown words to `people.term(term, "")` when set. `done(x)` also holds when `people.goal_done(x)`.
  - `scripts/UI/LetterText.gd`: after the job's goals, append `job.people.goals_listed()` (as side goals). After the job's notes, append `job.people.notes` (text from `DialogueBook.library().notes`).
  - `scripts/Interaction/Props.gd`: add `look_mesh(look: StringName) -> Mesh`, with `book` (a box 0.16×0.04×0.22, leather `Color(0.35,0.2,0.12)`), `bundle` (a box 0.1×0.1×0.18, herb `Color(0.4,0.45,0.25)`), and a default small box. `belt_mesh(id)` falls back to `look_mesh(DialogueBook.item(id).look)` when the id is a dialogue item.
- Test: `tests/dialogue_test.gd`

**Interfaces:**
- Consumes: `DialogueBook.library()`, `Terms` (Tasks 1–2)
- Produces (PeopleState):
  - State: `said: Dictionary` (`{char: Array[String]}`), `gave` (same shape), `moods: Dictionary` (`{char: int}`), `met: Array[String]`, `goals_shown: Array[String]`, `goals_done: Array[String]`, `notes: Array[String]`.
  - `var job: RefCounted`, `var inventory: Node` (either may be null).
  - Signals: `goal_shown(id: String)`, `goal_done(id: String)`, `noted(id: String)`.
  - `holds(condition: String, character: String) -> bool`, `term(term: String, character: String) -> bool`. Bare names resolve to `character`; dotted names to the one named. `has` and `purse` read `inventory`, and are false without one. `took`, `arrived` and `loot` go to `job`.
  - Memory: `set_flag(character, flag)`, `clear_flag(character, flag)`, `add_mood(character, by: int)`, `mood_of(character) -> int`, `meet(character)`, `record_gave(character, item)`.
  - Goals: `show_goal(id)`, `finish_goal(id)`, `goal_done(id) -> bool`, `goals_listed() -> Array` (`[{id, kind, text, done}]`, shown talk goals in library order), `learn(note_id)`.
  - `refresh()`: shows goals whose `shows:` holds, finishes goals whose `done:` holds, and loops until nothing changes, like `JobState.refresh`.
  - `begin_mission()`: drops goals already done from `goals_shown` and keeps everything else.
  - `save_state() -> Dictionary`, `load_state(state: Dictionary)`.

- [ ] **Step 1: Write the failing tests.**
  - `P1 flags, moods and met are per character`. After `set_flag("a","x")`, `holds("said(x)","a")` is true, `holds("said(x)","b")` is false, and `holds("said(a.x)","b")` is true.
  - `P2 has and purse read the inventory`, using a real `Inventory.gd` node with `add_belt_item(&"fx_book", "book")` and `add_loot(5)`. Then `holds("has(fx_book), purse>=5","a")` is true, and false with `inventory = null`.
  - `P3 a talk goal shows on said() and is done by its done: or by finish_goal()`, with the fixture goal `fx_bring_book` (`shows: said(fx_curandera.asked)`, `done: gave(fx_curandera.fx_book)`).
  - `P4 a .job goal can depend on talk`. With `JobState.reset(check_alone(...))` holding a goal `shows: said(fx_curandera.asked)`, setting the flag then `job.refresh()` shows it.
  - `P5 the letter lists talk goals and talk notes`. `LetterText.sides(job)[0]` contains the talk goal's text, and the back of the letter contains the talk note's text.
  - `P6 memory survives CityState.begin()`. Set a flag, a mood, a shown goal and a done goal, then call `CityState.begin()`. The flag, mood and shown goal remain, the done goal is gone from `goals_listed()`, and `CityState.job.people == CityState.people`.
  - `P7 save_state/load_state round-trips` every field into a fresh PeopleState.
  - `P8 a dialogue item keeps its mesh across a gate`. `Inventory.load_state` of a belt holding `fx_book` gives an entry whose `mesh != null`.
- [ ] **Step 2: Run** dialogue_test. Expected: P1–P8 FAIL.
- [ ] **Step 3: Implement** PeopleState and the four modifications above.
- [ ] **Step 4: Run** dialogue_test, job_test and `res://tests/interaction_test.tscn`, or whichever suite is named for Inventory: check with `ls tests | grep -i interact`. Expected: 0 fail on all of them.
- [ ] **Step 5: Commit** with `feat(dialogue): what people remember, kept for good`.

### Task 4: The conversation runner

**Files:**
- Create: `scripts/Interaction/Conversation.gd`
- Test: `tests/dialogue_test.gd`

**Interfaces:**
- Consumes: DialogueBook (Task 2), PeopleState (Task 3), `Inventory.add_belt_item/take_one/add_loot/count_of`, `Props.look_mesh`
- Produces: `Conversation extends RefCounted`.
  - Signals:
    - `line(speaker: String, text: String, cues: Array)`
    - `sense(school: String, text: String)`
    - `paused(seconds: float)`
    - `options(list: Array)`, where each item is `{text, special: bool}`
    - `cue(what: StringName)` (flare, dim, gutter, calm, nod or shake)
    - `resting(state: StringName)`, from the `shade()` effect
    - `gave_item(id: String)`, `took_item(id: String)`
    - `ended(how: StringName)`, with how one of `&"end"`, `&"walked_off"` or `&"interrupted"`
  - `func _init(p_character: Dictionary, p_people: RefCounted, p_inventory: Node)`
  - `start() -> void`: picks the first opener whose `when:` holds and calls `people.meet()` after the opener's conditions are read, so `met` is false on the first visit.
  - `advance() -> void`: emits the next body item. Spoken text has `{name}` replaced by `character.name`.
  - `choose(index: int) -> void` indexes the last emitted `options` list.
  - `walk_off()` and `interrupt()`. `walk_off` sets flag `walked_off`; `interrupt` sets nothing.
  - `is_waiting_for_choice() -> bool`, `is_over() -> bool`.
  - **Effect order:** a beat's `do:` runs when it is entered. An option's `do:` runs on `choose`, before moving to `to`. `people.refresh()` runs after every effect list.
  - `give` adds the item via `inventory.add_belt_item(id, item.name, Props.look_mesh(item.look))`. `take` is a no-op unless `inventory.count_of(id) > 0`; if so it calls `take_one` and `record_gave`. `pay(n)` calls `add_loot(n)`. `charge(n)` subtracts only when `purse >= n`; if not it is a no-op. `goal` calls `show_goal`, `done` calls `finish_goal`, `note` calls `learn`, `mood` calls `add_mood`, and `set`/`clear` set and clear flags.
  - A beat with no visible options and no goto ends with `ended(&"end")`. If its option list is empty after filtering, it emits a single `{text: "<<…>>", special: false}` that ends the conversation.

- [ ] **Step 1: Write the failing tests** on the Task 2 fixtures. Drive `start()`/`advance()`/`choose()` and collect the signals into arrays.
  - `C1 the first opener whose when: holds plays`. On the first visit the opener is `open_first`; after `met` it is `open`.
  - `C2 lines arrive in order with their cues`, comparing the `line` signal's sequence and cues with the fixture.
  - `C3 an [if] option is hidden when false and shown when true`, toggled by a flag.
  - `C4 choose runs the option's effects then enters its beat`. After choosing "ask", `said(asked)`, the goal `fx_bring_book` is shown, and the next line is from beat `asked`.
  - `C5 give puts the item on the belt with a mesh`.
  - `C6 take removes it, records gave, and finishes the goal`.
  - `C7 mood moves with a lie and gates the next opener`. The `fx_librarian` lie route gives mood −1, and the next start plays `open_after_lie`.
  - `C8 walk_off sets walked_off; interrupt sets nothing`.
  - `C9 all options filtered: a single ending option appears` (Review Focus 3).
  - `C10 take without the item changes nothing` (Review Focus 4): `gave` stays empty and `belt.size()` is unchanged.
  - `C11 {name} becomes the speaker's name` on a type-only character.
- [ ] **Step 2: Run** dialogue_test. Expected: C1–C11 FAIL.
- [ ] **Step 3: Implement** Conversation.
- [ ] **Step 4: Run** dialogue_test. Expected: every D, P and C check PASSES.
- [ ] **Step 5: Commit** with `feat(dialogue): the conversation runner`.

### Task 5: The shade (shown to the user before Task 6)

**Files:**
- Create: `scripts/Visual/shade.gdshader`, `scripts/Interaction/Shade.gd`, `tests/visual/stage_shade.gd`, `tests/visual/stage_shade.tscn`
- Test: `tests/dialogue_test.gd`

**Interfaces:**
- Consumes: `Humanoid.dress(kind, seed, &"Idle")`, `Humanoid.worn()`, `set_motion`, `show_upper`, `clear_upper`, `play_once`, `turn_head`, `bone_global(&"head")`, `DialogueBook.character/type_character/colour_of`
- Produces: `Shade extends StaticBody3D`.
  - Exports: `character: String` (a character id), or `type_id: String` plus `display_name: String` for a type-only NPC.
  - `var dialogue: Dictionary` is the resolved character.
  - `var man: Humanoid`
  - `get_prompt(player) -> String` returns `"Talk"`.
  - `frob(player)` calls `player.frob.talk(self)` (Task 6).
  - `set_resting(state: StringName)`, `cue(what: StringName)`: a one-line flare/dim/gutter lasts until `end_line()`. `nod`/`shake` play `Yes`/`Idle_No` once.
  - `speaking(on: bool)` shows or clears the upper `Idle_Talking`.
  - `face(point: Vector3)` turns the body smoothly at 3 rad/s max.
  - `head_point() -> Vector3`
  - `shade_state() -> StringName`, `glow_now() -> float` (for tests).
  - Collision: a `CapsuleShape3D` with radius 0.35 and height 1.8 on layer 1, so the frob ray hits it.
- **Shader uniforms** and their resting values:
  - `shade_colour: vec4`
  - `glow` (calm 1.0, flare 2.2, dim 0.35, gutter 1.0 with flicker)
  - `opacity` (calm 0.55, flare 0.7, dim 0.25)
  - `flicker` (gutter 1.0, else 0.0)
  - `smoke_speed` (calm 0.15, flare 0.35)
  - `fray_height` 0.35 m in model space: alpha fades to 0 at the soles
  - `seed`
- The material is unshaded, with a fresnel rim, object-space 3D noise smoke and a depth prepass. Shade eases every uniform toward its target at rate 4/s.
- Wisps: a GPUParticles3D at the feet and shoulders, using `res://assets/vfx/smoke.png` tinted `shade_colour`.

- [ ] **Step 1: Write the failing tests.**
  - `S1 a shade dresses its body and every worn mesh wears the shade material`. For a `character = "fx_curandera"` shade, `man.worn().all(m.material_override.shader == preload(shade.gdshader))`.
  - `S2 flare raises and dim lowers the glow`. After 1 s at fixed fps: flare gives `glow_now() > 2.0`, dim gives `< 0.5`, and returning to calm gives a value near 1.0.
  - `S3 a line's cue passes; a resting state stays`. `cue(&"flare")` then `end_line()` returns toward calm, while `set_resting(&"dim")` stays dim.
  - `S4 the frob ray finds it and its prompt is Talk`. Use a Player.tscn instance facing it at 1.5 m: `player.frob.target == shade` and `current_prompt() == "Talk"`.
- [ ] **Step 2: Run** dialogue_test. Expected: S1–S4 FAIL.
- [ ] **Step 3: Implement** the shader and Shade.gd.
- [ ] **Step 4: Run** dialogue_test. Expected: PASS.
- [ ] **Step 5: Stage stills.** `tests/visual/stage_shade.gd` follows `tests/visual/stage_fp_hands.gd`'s windowed pattern. It shows the curandera's shade (duelist, copal) under one lamp at night, calm, flare, dim and gutter, from the front and three-quarter view at 2 m, plus a close-up of the feet's fray. Run it windowed. Expected: 9 PNGs in the scratchpad.
- [ ] **Step 6: Inspect** every still up close for seams, see-through artefacts inside the body, sorting faults and wisps clipping. Fix them, or list them as unfinished.
- [ ] **Step 7: Commit** with `feat(dialogue): the shade`.
- [ ] **Step 8: STOP for the user's review** of the curandera's shade, per the standing rule that models go one at a time. Send the stills. Only after the user's yes, dress the librarian (`arms_master`, ink violet), stage his stills, and get his yes too.

### Task 6: The talk box and the player

**Files:**
- Create: `scripts/UI/TalkBox.gd`
- Modify:
  - `scripts/Interaction/PlayerFrob.gd`: add `talk(shade)`, `talking() -> Node`. A shade's prompt shows only when `_hands_free()` and not carrying, shouldering or reading; otherwise the blocked status row is shown, as with "Too heavy".
  - `scripts/PlayerController.gd`: add `var talk_hold := false`. Add `_move_axis() -> Vector2`, which returns `Vector2.ZERO` while `talk_hold`, and replace each `Input.get_vector("move_left", "move_right", "move_forward", "move_back")` with it. Skip mouse-look motion, jump and crouch input while `talk_hold`. When hurt (the damage entry point near line 1491), call `frob.talking().interrupt()` if talking.
- Test: `tests/dialogue_test.gd`

**Interfaces:**
- Consumes: Conversation (Task 4), Shade (Task 5), PeopleState via `CityState.people`, `Sfx.play(context, sound, at)`
- Produces: `TalkBox extends CanvasLayer`.
  - `open(shade: Node, player: Node)`, `close()`
  - `var conversation: Conversation`
  - `shown_text() -> String`, `shown_options() -> Array[String]` (for tests)
  - `select(index: int)`, `press_advance()` (the frob/click path)
  - Constants: `REVEAL_CPS := 45.0` and `OPTION_GUARD := 0.25` (seconds after options appear during which presses are ignored).
- **Behaviour:**
  - Walking away is holding `move_back` for 0.5 s, which calls `conversation.walk_off()`. Escape still pauses, and the box pauses with the tree.
  - The mouse is visible while options are up and is captured again on close.
  - Each `line` plays `murmur` + the voice suffix at the shade's head, with a `hm` on `sense`.
  - Shade cues route to `shade.cue`, and `speaking(true)` lasts for the reveal.
  - The camera eases the player's yaw and neck pitch toward `shade.head_point()`; easing is left to the builder.
- **Layout (mockup A):**
  - The portrait cut-in is on the right, a `SubViewport` 256×320 sharing the world, with a Camera3D 0.9 m in front of `head_point()` and FOV 30, shown through a TextureRect clipped to polygon `(18%,0) (100%,0) (100%,100%) (0,92%)`.
  - The name tag is on box black in marigold, rotated −4°.
  - The text box is box black with a 6 px cochineal left edge.
  - Options are marigold tags skewed −12°, with specials in cochineal.
  - Keys 1–4, the mouse wheel and frob all pick.

- [ ] **Step 1: Write the failing tests** in a small room with a Player.tscn instance, one fixture shade and `CityState.begin()`:
  - `B1 frob on a shade opens the box with the opener's first line`, so `shown_text()` equals the fixture's first line after the reveal.
  - `B2 the player is held while talking and freed on close`. With `talk_hold` set and `move_forward` pressed for 30 frames, the position changes by less than 0.01 m. After close, `talk_hold == false`.
  - `B3 choosing an option advances the conversation and applies effects`, checking the flag set by the fixture.
  - `B4 hands busy: no box` (Review Focus 1). While carrying a crate, frob on the shade leaves `talking() == null`.
  - `B5 hurt mid-talk closes the box without walked_off` (Review Focus 2).
  - `B6 a press inside OPTION_GUARD picks nothing`, so a double-press doesn't skip a choice.
  - `B7 holding back 0.5 s walks away and sets walked_off`.
- [ ] **Step 2: Run** dialogue_test. Expected: B1–B7 FAIL.
- [ ] **Step 3: Implement** TalkBox and the two modifications.
- [ ] **Step 4: Run** dialogue_test plus the movement and interaction suites (`ls tests | grep -iE "movement|traversal|interaction|polish"`). Expected: 0 fail. `_move_axis` must not change any movement result while not talking.
- [ ] **Step 5: Stage** windowed stills of the box mid-line and with options (normal and special), with the portrait live. Inspect them against mockup A and fix faults.
- [ ] **Step 6: Commit** with `feat(dialogue): the talk box`.

### Task 7: The test quest, the gym and the writer's guide

**Files:**
- Create:
  - `data/dialogue/types/curandera.dialogue`, `data/dialogue/types/bookseller.dialogue`
  - `data/dialogue/curandera.dialogue`, `data/dialogue/librarian.dialogue`
  - `maps/talk_gym.gd`, `maps/talk_gym.tscn`
  - `docs/systems/dialogue.md`
- Modify: `docs/systems/README.md` (link the guide)
- Test: `tests/dialogue_test.gd`

**Interfaces:**
- Consumes: everything above
- Content: the structure follows spec section 6. Every text is `<<…>>`, with an `intent:` on each beat saying what the user's words must do.
  - **`curandera`** (`body: duelist`, `colour: copal`, `voice: female`, `type: curandera`):
    - Openers: `open_first`, `open_has_book` (`when: has(the_book), not(gave(the_book))`), `open_after` (`when: gave(the_book)`), `open`.
    - Beats: `asks` (`do: set(asked_book), goal(bring_book)`), `limpia` (overrides the type's), `gives_bundle` (`take(the_book)`, `give(copal_bundle)`, `note(curandera_bundle)`), `lie_no_book` (cue `gutter`, `mood(-1)`).
    - A sense line `Sense obsidian [if said(asked_book)]`.
    - Blocks: `goal bring_book` (`kind: side`, `shows: said(asked_book)`, `done: gave(the_book)`), `item copal_bundle` (`look: bundle`), `note curandera_bundle`.
  - **`librarian`** (`body: arms_master`, `colour: ink`, `voice: male_b`, `type: bookseller`):
    - Openers: `open_first`, `open_after_lie` (`when: said(lied)`), `open_sent` (`when: said(curandera.asked_book), not(gave(curandera.the_book)), not(has(the_book))`), `open`.
    - Beats: `truth` (`give(the_book)`, `mood(+1)`), `pay` (`[if purse>=5]`, `charge(5)`, `give(the_book)`), `special` (`!`, `[if said(curandera.asked_book)]`), `lie` (cue `dim`, `set(lied)`, `mood(-1)`, `shade(dim)`), `amends` (`clear(lied)`, `shade(calm)`).
    - Block: `item the_book` (`look: book`).
  - **Types:**
    - `curandera`: `>>` options `limpia` and `copal` (`charge(2)`, `give(copal_bundle)`), with defaults `colour: copal` and `voice: female`.
    - `bookseller`: `>>` options `ask_title` and `buy_book`, with defaults `colour: ink` and `voice: male`.
- **The gym** is built in code like `maps/npc_gym.gd`:
  - A dim stone room about 14×10 m with three lamps.
  - The Player at the door, plus 2 loot on a table so `pay` can be tested by playing.
  - The curandera's shade at the left wall, the librarian's at the right, and a type-only `curandera` shade named `<<a market curandera>>` in the middle.
  - It calls `CityState.begin()`, and `J` raises the letter.

- [ ] **Step 1: Write the failing tests.**
  - `Q1 the shipped dialogue loads with no errors` (D12 on real files) and every say, sense and option text, and every item name, goal and note text, is a placeholder (`DialogueBook.is_placeholder`).
  - `Q2 the truth route`:
    - Curandera: `open_first` → `asks`, and the goal `bring_book` is listed.
    - Librarian: `open_sent` → `truth`, and the book is on the belt.
    - Curandera: `open_has_book` → `gives_bundle`. The book is gone, the bundle is on the belt, the goal is done (struck on the letter), and the note is on the letter's back.
  - `Q3 the lie route`. Lying to the librarian gives mood −1, `shade_state() == &"dim"`, and the next opener `open_after_lie`. `amends` restores calm.
  - `Q4 after the quest each opens differently`. The curandera plays `open_after`, and the librarian plays `open` with memory of the lie flag cleared or kept, as written.
  - `Q5 the type-only curandera offers the type's limpia, and the named curandera her own`.
  - `Q6 a new mission keeps it all`. After `CityState.begin()`, the curandera still plays `open_after` and the done goal has left the letter.
- [ ] **Step 2: Run** dialogue_test. Expected: Q1–Q6 FAIL.
- [ ] **Step 3: Write** the four `.dialogue` files and the gym. Write `docs/systems/dialogue.md`, the writer's guide: the format with an example, cues, conditions, effects, types and overrides, memory lasting forever, and the placeholder listing. Write it in the manner of `docs/systems/jobs.md`.
- [ ] **Step 4: Run** dialogue_test. Expected: every check PASSES, and `WORDS:` lines list what the user has to write.
- [ ] **Step 5: Run** the gym windowed (`.../Godot --path . res://maps/talk_gym.tscn`) and play both routes by hand. Note anything that feels wrong and fix it.
- [ ] **Step 6: Commit** with `feat(dialogue): the curandera, the librarian and the talk gym`.

### Task 8: The whole branch green

- [ ] **Step 1: Run** every suite under `tests/*_test.tscn` headless, in a loop. Expected: 0 fail in each. A known flake under load must be named, with the suite and check (see the headless-test-determinism memory). It must not be called passing.
- [ ] **Step 2:** fix any regression with a failing test first.
- [ ] **Step 3: Commit** any fixes, and send the user the gym, the stills and the `WORDS:` list.
