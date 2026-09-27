# NPC Showcase, Part 2: Life and Voice: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the showcase's twelve guards feel alive. That means authored conversations chosen by rules, a voice with a heart rate and a speech ladder, pastimes, an expression layer, gatherings, a night rota, a fire that burns down and atmosphere, with Act I rebuilt around all of it.

**Architecture:**
- Plain-text `.talk` files are parsed by `TalkScript` into dictionaries.
- A `TalkDirector`, one per scene tree, groups men at their ease. It casts parts through pure `TalkFacts` functions and plays lines through `Guard.speak`. Subtitles still come from the `barked` signal; `GuardVoice` adds the murmur, the emotes and the ladder.
- Presentation (`Expression`, the `Humanoid` upper-body layer, `Atmosphere`) reads the AI and never feeds it.
- Routines (`NightRota`, `Gathering`) move men by changing their duties and by lending them `GuardRota` stations.

**Tech Stack:** Godot 4.5.1, GDScript, headless test scenes.

**Spec:** `docs/superpowers/specs/2026-09-26-npc-showcase-life-design.md`

## Global Constraints

**Running and working**
- Godot: `/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot`.
- A suite runs as `Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/<suite>.tscn`. It passes when every line after `==== RESULTS ====` starts with `PASS` and the output contains no `SCRIPT ERROR`.
- Work only on branch `npc-showcase` in `.claude/worktrees/npc-showcase`. Commit once per task. Never touch the main working tree (the user commits it as "fix N"). No bare `git stash`.
- Every existing suite stays green (28 suites, 680 checks at d1b18b7).
- New suites pin their dice: `seed(N)`, `GuardScript.randomize_on = false`, `TemperamentScript.rolling = false`, then restore `randomize_on = true`.
- Every timer runs on game time (physics delta or `Comms.now()`), never the wall clock.

**Sound and assets**
- No procedural audio. Every sound is a recording cut by `tools/prepare_sfx.py` from approved files.
- A sound with no recording stays silent (`Sfx.stream` returns null, `Sfx._play_3d` returns early).
- Download nothing without the user's explicit yes to a list of files.
- Never commit textures.com-derived images (the repo is public).

**Presentation**
- Presentation systems (Expression, Atmosphere, the upper layer) are read-only toward the AI.
- The one exception is the per-man walk scale (spec 5.3). It multiplies `patrol_speed` once, at spawn.

**Writing and the talk format**
- Lines are short, mostly under twelve words, in plain period English.
- Oaths are mild only (gods, damn, piss); no modern slang. Wry at rest, human in fear.
- The `.talk` format is exactly spec 4.1 plus two block keys this plan adds:
  - `group: <word>`: conversations sharing it are all used before any repeats.
  - `again: yes`: its lines may be repeated by the same man in one night.

  Also two emotes, `throws` and `nudges`. Ids are unique across all files.

**House style**
- Tabs and typed variables; `const` tables at the top of the file.
- `##` doc comments in plain English about the men, e.g. `## Standing still this long, a man finds something to do with himself.`
- Hold references to men that may be freed as `Variant` or weakrefs, checked with `is_instance_valid`. Never hold them as typed `Node3D` fields.

## Review Focus

1. **A man freed or knocked out in the middle of a line** (killed, cleared by a test, knocked senseless). The director drops him without a SCRIPT ERROR and ends or continues the talk cleanly. Pinned by T14 (Task 3).
2. **A man who walks off or is sent to a new duty mid-conversation** (a NightRota handover, a gathering). Nobody is left "talking" forever: the talk ends once he is beyond `2 × TALK_RANGE`. Pinned by T15 (Task 3) and R11 (Task 12).
3. **Talk files the user edits.** An unknown emote, an unknown condition word, an undeclared part or a duplicate id each gives an error naming `file:line`. None of them is silently false. Pinned by T3 (Task 1) and T8 (Task 2).
4. **The showcase at another seed or on a slower machine.** Act I's beats still end (every beat has `enough`/`timeout`), and a gathering whose man is busy picks another or is skipped. Pinned by D32 (Task 16).
5. **Twelve voices, particles and directors on the frame rate.** The `--fps-report` average with everything on stays within 10% of before. Moths are thinned first, then leaves. Measured in Task 16 (Step 7), with `Atmosphere.quality` pinned by A20 (Task 15).

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `scripts/AISystem/Talk/TalkScript.gd` (new) | parse `.talk` files and the cast sheet; validation | 1, 2 |
| `scripts/AISystem/Talk/TalkFacts.gd` (new) | pure facts, conditions, requirements, casting, specificity | 2 |
| `scripts/AISystem/Talk/TalkDirector.gd` (new) | groups, choosing, playback, interruption, memory, solo, pairs, grief | 3, 4, 13 |
| `data/talk/cast.talk`, `at_ease.talk`, `unease.talk`, `fear.talk`, `solo.talk`, `combat.talk`, `gatherings.talk` (new) | the cast sheet and all the writing | 1, 11-14 |
| `scripts/AISystem/GuardVoice.gd` (new) | heart rate, ladder, murmur, emote sounds, breathing | 6 |
| `scripts/Visual/Expression.gd` (new) | gaze, posture, gait, breath, weight shifts, gestures, variation | 7 |
| `scripts/AISystem/GuardPastimes.gd` (new) | pastimes by dual utility with memory | 10 |
| `scripts/AISystem/NightRota.gd` (new) | duties, needs, the hour, relief wanted | 9 |
| `scripts/AISystem/Gathering.gd` (new) | the gathering director and its seven kinds | 11, 12 |
| `scripts/Visual/Atmosphere.gd` (new) | wind, embers, moths, leaves, crows, breath, chips | 15 |
| `scripts/Visual/Humanoid.gd`, `Posture.gd` | upper-body layer, walk clip, stride; new posture turns | 5 |
| `scripts/Combat/Fire.gd`, `scripts/Visual/Torch.gd` | fuel, strength, flare, lean | 8, 15 |
| `scripts/AISystem/GuardLife.gd` | talk and fidgets handed on | 3, 10 |
| `scripts/AISystem/Guard.gd`, `GuardRig.gd`, `GuardRota.gd`, `GuardBody.gd`, `GuardFighter.gd`, `Squad.gd`, `Garrison.gd` | small hooks (listed per task) | 3-13 |
| `maps/npc_showcase.gd`, `scripts/Showcase/ShowNight.gd`, `ShowOverlay.gd` | Act I rebuilt, rota and places, grief beat, whisper size | 16 |
| `tools/prepare_sfx.py`, `CREDITS.md`, `scripts/Audio/Sfx.gd` | the approved voice recordings | 6 (GAIN keys), 17 |
| `tests/talk_test`, `tests/aliveness_test`, `tests/routines_test` (new); `tests/showcase_test` | tests | all |

---

### Task 1: The talk files and their parser

**Files:**
- Create: `scripts/AISystem/Talk/TalkScript.gd`
- Create: `data/talk/cast.talk`. The cast sheet from spec §9:
  - Mirelle: rank 4; captain; south.
  - Osric: kin Jory. Jory: sweetheart.
  - Brand: rival Ned; undertown; storyteller.
  - Wat: rival Aldous; sings; gambler.
  - Aldous: old_guard; knees.
  - Hendrik: friend Ned; daughter.
  - Piers: owes Col; friend Col.
  - Col: hungry; lucky.
  - Tam: sleeps_on_watch.
  - Gideon: suspects Wat; ledger.
  - Ned: recruit.
  - Rank 2 for Osric, Brand and Aldous; rank 3 for Gideon; everyone else rank 1.
- Create: the spec §10.1 samples verbatim, each in the file it will live in:
  - `data/talk/at_ease.talk`: tam_resting, wat_sings, the_moon_glass, hendriks_girl, oil_gone, mothers_letter.
  - `data/talk/gatherings.talk`: round_tam.
  - `data/talk/fear.talk`: where_is_jory, grief_jory_osric.
  - `data/talk/combat.talk`: status_check, not_there.
  - `data/talk/solo.talk`: brand_block, tam_sleeptalk.
- Test: `tests/talk_test.gd`, `tests/talk_test.tscn`. The scene is a `Node3D` root with the script, as `tests/stations_test.tscn`.
- Workspace (not committed): `<workspace>/run_suites.sh` and `<workspace>/check.sh <suite>`.
  - `run_suites.sh` runs every `tests/*_test.tscn` headless, logs each run to `<workspace>/logs/<suite>.log`, and prints `suite PASS/FAIL counts, SCRIPT ERROR count`.
  - `check.sh` runs one suite and prints its RESULTS block plus the SCRIPT ERROR count.

**Interfaces:**
- Produces:
  - `TalkScript.ONCE := -1.0`, `TalkScript.DEFAULT_COOLDOWN := 300.0`.
  - `TalkScript.EMOTES := ["laughs","sighs","nods","shakes","shrugs","spits","coughs","drinks","kicks","whispers","shouts","murmurs","throws","nudges"]` plus the prefixes `points:` and `looks:`.
  - `static func parse(text: String, file: String) -> Dictionary` returns `{"conversations": Array, "cast": Dictionary, "errors": Array[String]}`. Each error reads `"<file>:<line>: <message>"`.
  - `static func load_dir(path := "res://data/talk") -> Dictionary`: the same shape, all files merged. It adds duplicate-id errors across files and runs `push_error` for each error.
  - `static func library() -> Dictionary`: `load_dir()` cached. `static func reload() -> void`.
  - A conversation: `{"id": String, "when": Array, "cast": Array, "place": StringName, "cooldown": float, "priority": int, "group": StringName, "again": bool, "lines": Array, "interrupt": Array, "source": "file:line"}`.
    - `when` is an Array of terms. Each term is an `Array[String]` of alternatives.
    - `cast` is an Array of `{"key": "A", "optional": bool, "reqs": Array}`. `reqs` has the same shape as `when`.
  - A turn: `{"part": "A", "choices": [{"if": String, "emotes": Array[String], "text": String, "source": String}]}`.
    - A turn is one or more consecutive lines of one part. Every line except the last carries `{if …}`; `if` is `""` on the plain line.
    - If the last line also carries `{if}`, the turn has no fallback and is skipped when no condition holds.
  - The cast sheet: `{name: {"rank": int, "traits": Array[String], "ties": {"kin": [], "friend": [], "rival": [], "owes": [], "suspects": []}}}`.
    - `kin`, `friend` and `rival` are made both ways. `owes` and `suspects` are one way.
    - `rank N` sets the rank; any other bare word is a trait.
- Parsing rules the tests pin:
  - `|` splits alternatives outside parentheses. A bare word that follows a `key:value` alternative inherits the key: `night:early|middle` gives `["night:early","night:middle"]`.
  - Terms are split by `,`; parts by `;`.
  - Durations: `30s`, `10m` or `once`.
  - A line: `^([A-D])\s*(\[[^\]]*\])?\s*(\{if [^}]*\})?\s*:\s*(.+)$`. Emotes are split by `,` or spaces.

- [ ] **Step 1: Write the failing tests T1–T4 in `tests/talk_test.gd`.** Harness: `extends Node3D`, `results`, `_check(name, ok, detail)`, printing `==== RESULTS ====`, as `tests/stations_test.gd`.

```gdscript
# T1 the talk files load clean
var lib := TalkScript.load_dir()
var cast: Dictionary = lib["cast"]
_check("T1 the talk files load clean, the cast sheet has all twelve and its ties run both ways where they should",
	lib["errors"].is_empty() and lib["conversations"].size() >= 13 and cast.size() == 12
	and "Jory" in cast["Osric"]["ties"]["kin"] and "Osric" in cast["Jory"]["ties"]["kin"]
	and "Col" in cast["Piers"]["ties"]["owes"] and not ("Piers" in cast["Col"]["ties"]["owes"])
	and cast["Mirelle"]["rank"] == 4 and "captain" in cast["Mirelle"]["traits"], str(lib["errors"]))
# T2 a sample reads as written
var glass: Dictionary = _conv(lib, "the_moon_glass")
_check("T2 the_moon_glass reads as written",
	glass["when"] == [["at_ease"], ["night:early", "night:middle"]] and glass["cast"][1]["reqs"] == [["friend(A)", "any"]]
	and glass["cooldown"] == TalkScript.ONCE and glass["lines"][3]["part"] == "B" and glass["lines"][3]["choices"].size() == 2
	and glass["lines"][3]["choices"][0]["if"] == "stubborn" and glass["lines"][0]["choices"][0]["emotes"] == ["looks:the tower"], str(glass))
# T3 a bad file reports its file and line
var bad := TalkScript.parse("== x\ncast: A = any\nA [dances]: Hi.\nQ: Who?\n== x\ncast: A = any\nA: Again.\n", "bad.talk")
var errs: String = "\n".join(bad["errors"])
_check("T3 a bad file names the file and line of each fault", errs.contains("bad.talk:3") and errs.contains("bad.talk:4") and errs.contains("bad.talk:5"), errs)
# T4 turn and turn about
var wrong := []
for c in lib["conversations"]:
	if c["cast"].size() >= 2 and c["lines"].size() >= 2 and c["lines"][0]["part"] == c["lines"][1]["part"]:
		wrong.append(c["id"])
_check("T4 every conversation of two or more opens with two different speakers", wrong.is_empty(), str(wrong))
```

- [ ] **Step 2: Run it and watch it fail.** Run `<workspace>/check.sh talk_test`. Expected: a SCRIPT ERROR (TalkScript not found), then FAILs.
- [ ] **Step 3: Implement `TalkScript.gd` and the data files.** Read files with `FileAccess`. List `.talk` files with `DirAccess.get_files_at`.
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh talk_test`. Expected: T1–T4 PASS, 0 SCRIPT ERROR.
- [ ] **Step 5: Commit.**

```bash
git add scripts/AISystem/Talk/TalkScript.gd data/talk tests/talk_test.gd tests/talk_test.tscn
git commit -m "feat(talk): the .talk files, the cast sheet and their parser"
```

---

### Task 2: Facts and casting

**Files:**
- Create: `scripts/AISystem/Talk/TalkFacts.gd` (static functions only)
- Modify: `scripts/AISystem/Talk/TalkScript.gd`. `load_dir` validates every `when:` term with `TalkFacts.known(term, false)` and every requirement or `{if}` with `TalkFacts.known(term, true, traits)`. An unknown one is an error `"file:line: unknown condition 'x'"`.
- Test: `tests/talk_test.gd` (T5–T9; pure dictionaries, no scene)

**Interfaces:**
- Consumes: the TalkScript conversation and cast-sheet shapes (Task 1).
- Produces:
  - `static func man(guard: Node, sheet: Dictionary) -> Dictionary` returns `{"name", "temper": StringName, "rank": int, "kind": StringName, "traits": Array, "ties": Dictionary, "states": Dictionary, "station": StringName, "near": Array[String], "quiet_for": float, "node": guard}`.
    - `states` holds `tired`, `hungry`, `cold` (0..1, from `NightRota.needs_of` if a rota exists, else 0) and `hurt` (`1 - health / max_health`).
    - It also holds `grieving` (`guard.grief > 0.5`), `afraid` (the garrison's `fear_of(nerve) > 0.3`) and `asleep` (`_rota.asleep()`).
    - `station` is the held `GuardStation.kind`, else `""`. `near` lists the landmarks within `Comms.LANDMARK_REACH`.
  - `static func sheet_man(name: String, sheet: Dictionary, temper := &"steady", kind := &"") -> Dictionary`: the same shape with no node, for pure tests and castability.
  - `static func world(men: Array, tree: SceneTree, extra := {}) -> Dictionary` returns these keys:
    - The men: `at_ease`, `uneasy`, `combat`, `hunt`.
    - The garrison: `alarm`, `bell_rung`, `dead`, `dead_names`, `body_found`, `missing`, `dread`, `spared`, `slain_begging`, `habits`.
    - The night: `night` (`NightRota.hour()`, else `&"early"`), `cold`, `fire`, `wind`.
      - `fire` is `&"low"` if any node in group `fires` within 15 m has `low()` true, `&"burning"` if one is near, else `&""`.
    - Who is about: `present`, `asleep`.
    - From `extra`: `situation`, `place`, `place_name`, `dead_name`.
    - Garrison facts come from `Garrison.of(first node in group "player")` when there is one, otherwise zeros.
  - `static func holds(term: String, world: Dictionary, cast := {}) -> bool`. The when-words are:
    - bare: `at_ease`, `uneasy`, `alarm`, `hunt`, `combat`, `bell_rung`, `body_found`, `spared`, `slain_begging`, `cold`, `wind`;
    - keyed: `night:<h>`, `fire:<low|burning>`, `habit:<h>`, `situation:<x>`;
    - compared: `alarm>=N`, `dead>=N`, `dread>=N`;
    - named: `dead(<name>)`, `missing(<name>)`, `present(<name>)`, `asleep(<name>)`;
    - negated: `not(<term>)`.
  - `static func meets(man: Dictionary, term: String, cast: Dictionary, world: Dictionary) -> bool`. The requirement words are:
    - who he is: `any`, a temperament (`rash`, `craven`, `stubborn`, `sly`, `steady`), `rank>=N`, `name(<n>)`, `kind(<archetype>)`, `captain`, a trait;
    - ties: `kin(P)`, `friend(P)`, `rival(P)`, `owes(P)`, `suspects(P)`, where P is a part key already cast (looked up in `cast[P]["name"]`) or a name;
    - states: `tired`, `hungry`, `cold`, `hurt`, `grieving`, `afraid`, `asleep`, each true at ≥ 0.5, or compared as `hurt>N`, `tired>N`;
    - where he is: `station(<kind>)`, `near(<landmark>)`;
    - negated: `not(<req>)`.
  - `static func known(term: String, as_requirement: bool, traits := []) -> bool`.
  - `static func cast_parts(conv: Dictionary, men: Array, world: Dictionary, allowed := Callable()) -> Dictionary` returns `{part_key: man_dict}`, or `{}` if a required part cannot be filled.
    - It searches every assignment of distinct men to parts, in the order given (the director passes the quietest first).
    - The score is, over the filled parts, the count of requirement terms other than `any`, plus 10 for each filled optional part. The first best assignment wins.
    - `allowed.call(man_dict, part_key) -> bool` can veto a pairing.
    - Parts are filled in order A, B, C, D, so a tie like `owes(A)` sees A.
  - `static func specificity(conv: Dictionary, cast: Dictionary) -> int` = the count of `when` terms, plus the requirement terms other than `any` of every filled part.
  - In `TalkScript`: `static func load_text_for_test(text: String, file: String) -> Dictionary` is `parse` plus the validation. `load_dir` uses it for each file.
  - Scripts from later tasks (NightRota, Gathering) are reached through `ResourceLoader.exists(path)` and `load(path)` at call time, never `preload`, so this task stands alone and avoids preload cycles.

- [ ] **Step 1: Write the failing tests T5–T9.**

```gdscript
var sheet: Dictionary = TalkScript.library()["cast"]
var w := {"night": &"late", "dead": 2, "at_ease": false, "dead_names": ["Jory"]}
_check("T5 conditions read the night and the garrison",
	TalkFacts.holds("night:late", w) and not TalkFacts.holds("night:early", w) and TalkFacts.holds("dead>=1", w)
	and TalkFacts.holds("not(at_ease)", w) and TalkFacts.holds("dead(Jory)", w), "")
var osric := TalkFacts.sheet_man("Osric", sheet); var jory := TalkFacts.sheet_man("Jory", sheet)
var piers := TalkFacts.sheet_man("Piers", sheet, &"craven"); var col := TalkFacts.sheet_man("Col", sheet)
_check("T6 requirements read temperament, rank and ties",
	TalkFacts.meets(jory, "kin(A)", {"A": osric}, {}) and TalkFacts.meets(piers, "owes(A)", {"A": col}, {})
	and not TalkFacts.meets(col, "owes(A)", {"A": piers}, {}) and TalkFacts.meets(piers, "craven", {}, {})
	and TalkFacts.meets(TalkFacts.sheet_man("Mirelle", sheet), "rank>=4", {}, {}), "")
var dice := TalkScript.parse("== d\ncast: A = any; B = owes(A); C? = friend(A)|friend(B)\nA: You owe me.\nB: Three.\nC: Pay him.\n", "t")["conversations"][0]
var cast7 := TalkFacts.cast_parts(dice, [piers, col, TalkFacts.sheet_man("Ned", sheet)], {})
_check("T7 casting fills parts by their ties and leaves an optional part empty when nobody fits",
	cast7.get("A", {}).get("name") == "Col" and cast7.get("B", {}).get("name") == "Piers" and not cast7.has("C"), str(cast7.keys()))
var bad := TalkScript.load_text_for_test("== y\nwhen: at_eaze\ncast: A = any\nA: Hm.\n", "y.talk")
_check("T8 a condition nobody knows is an error with its file and line", "\n".join(bad["errors"]).contains("y.talk:2: unknown condition 'at_eaze'"), str(bad["errors"]))
var any2 := TalkScript.parse("== q\ncast: A = any; B = any\nA: One.\nB: Two.\n", "t")["conversations"][0]
var x := TalkFacts.sheet_man("Tam", sheet); var y := TalkFacts.sheet_man("Gideon", sheet)
_check("T9 the quietest man is cast first", TalkFacts.cast_parts(any2, [x, y], {})["A"]["name"] == "Tam", "")
```

`TalkScript.load_text_for_test(text, file)` is `parse` plus the validation `load_dir` runs. It is a static helper, so tests and `load_dir` share one path.

- [ ] **Step 2: Run it and watch it fail.** Run `check.sh talk_test`. Expected: T5–T9 FAIL or SCRIPT ERROR; T1–T4 PASS.
- [ ] **Step 3: Implement `TalkFacts.gd` and the validation in `TalkScript`.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh talk_test`. Expected: T1–T9 PASS. The sample files must still load clean: every word they use is known or a sheet trait.
- [ ] **Step 5: Commit.** `git commit -m "feat(talk): facts, requirements and casting"`

---

### Task 3: The director plays conversations

**Files:**
- Create: `scripts/AISystem/Talk/TalkDirector.gd`
- Modify: `scripts/AISystem/GuardLife.gd`.
  - Talk moves to the director: `talking()`, `partner_direction()`, `end_talk()` and the `talk`/`listen` result of `activity()` delegate to it; `_talk_rest` stays.
  - Delete `_look_for_company`, `_begin_talk`, `_join_talk`, `_update_talk`, `partner`, `_lead`, `_lines`, `_line`, `_line_timer` and `_spoke_at`.
  - `update()` calls `TalkDirector.of(guard).tick(delta)`.
- Modify: `scripts/AISystem/Guard.gd`.
  - Add `var last_delivery: StringName = &""` and `func speak(text: String, delivery: StringName = &"") -> void`: puppets are silent; it sets `last_delivery`, sets `_bark_timer = 3.0`, emits `barked(text)` and sets the label.
  - Add `func emote(what: String) -> void`, which forwards to `_voice.emote(what)` and `_rig.emote(what)` when they have the method.
  - `bark()` now also ends his conversation (`if _life != null and _life.talking(): _life.end_talk()`) before emitting.
- Modify: `scripts/AISystem/Garrison.gd`.
  - `clear_all()` also calls `TalkDirector.clear_all()`, loaded by path with `load()` to avoid a preload cycle (TalkFacts reads Garrison).
  - Delete `gossip()`, `SMALL_TALK` and the `TALK_OF_*` tables. Their lines move to data:
    - `SMALL_TALK` to `data/talk/at_ease.talk`, as two-line conversations in `group: small_talk`, `cast: A = any; B = any`, `cooldown: 2m`.
    - `TALK_OF_*` to `data/talk/unease.talk`, with `when:` terms `dead>=1`, `dread>=0.35`, `alarm>=0.45`, `habit:<h>`, `spared`, `slain_begging`. Names become `{dead}`.
- Test: `tests/talk_test.gd` (T10–T15)

**Interfaces:**
- Consumes: `TalkScript.library()`, `TalkFacts.*` (Tasks 1–2); `GuardLife.at_ease(man)` (static, existing).
- Produces, in `TalkDirector`:
  - `static func of(node: Node) -> RefCounted`: one per `SceneTree`, keyed by the tree's instance id, made on the first ask.
  - `static func clear_all() -> void`.
  - `func use_library(lib: Dictionary) -> void`: tests set their own conversations; `{}` returns to `TalkScript.library()`.
  - `func tick(delta: float) -> void`: once per physics frame, guarded by `Engine.get_physics_frames()`.
  - `func in_talk(man: Node) -> bool`, `func speaking(man: Node) -> bool`, `func speaker_near(man: Node) -> Variant`.
    - `speaker_near` gives whom he should face: the man speaking now, or, while he speaks himself, the member nearest his front. It returns null if none.
  - `func leave(man: Node, interrupted := true) -> void`.
  - `func play(conv_id: String, cast: Dictionary) -> bool`, where `cast` maps part keys to men.
  - `func talks() -> Array`: the live talks as `{"id", "cast": {key: man}, "members": Array, "turn": int, "started_at": float, "place": StringName}`.
  - `func played() -> Array[String]`: ids in the order started tonight.
  - `func lines_of(man: Node) -> Array[String]`: what he has said tonight.
  - Constants:
    - `CHOOSE_EVERY := 2.0`, `TALK_RANGE := 3.8`, `GROUP_MAX := 4`;
    - `LINE_BASE := 0.9`, `LINE_PER_CHAR := 0.055`, `WHISPER_SLOW := 1.15`, `SHOUT_FAST := 0.85`;
    - `PAUSE := Vector2(0.4, 0.9)`, `TALK_REST := Vector2(20.0, 45.0)`;
    - `LEAVE_RANGE := 2.0 * TALK_RANGE`.
- Rules the tests pin:
  - **Who can talk.** A man is free for a group when all of these hold:
    - `GuardLife.at_ease(man)`;
    - not a `lookout`;
    - `_life._talk_rest <= 0`;
    - not asleep and not already in a talk;
    - either `_life._resting >= 1.0` (standing still) or his rota activity is one of `sit`, `sit_talk`, `eat`, `lean`.
  - **Groups.** A group is a connected set of free men within `TALK_RANGE` of each other with `guard._line_of_sight` between eye positions. It is capped at the `GROUP_MAX` nearest to its first man.
  - **Choosing.** Every `CHOOSE_EVERY` seconds (the first pass at a random offset in [0, 2)), for each group:
    - The candidates are conversations of 2 or more parts, with no more required parts than members. Their `place` must be empty or among the group's station kinds, and every `when` term must hold (any alternative). They must be castable.
    - The pool is the candidates of the top priority whose specificity is within 1 of the best. It is sampled by weight `1 + specificity`.
    - Never the id this same set of men last played.
  - **A turn.**
    - Before each turn, re-check `when` on a fresh `world()` of the cast, and check every member is valid, at ease and within `LEAVE_RANGE` of the rest. If any check fails, interrupt.
    - Choose the choice: the first whose `if` holds (`TalkFacts.meets`) for the speaker, else the plain one, else skip the turn.
    - Turns of an empty optional part are skipped.
    - Substitute `{A}`–`{D}` with names, `{dead}` with `world.dead_name` or the last of `dead_names`, and `{place}` with `world.place_name`.
    - Delivery: the emotes `whispers`, `shouts` or `murmurs` give `whisper`, `shout` or `murmur`. Unmarked, it is whatever `speaker._voice.delivery_for(&"", uneasy)` says, if a voice exists, else `&""`.
    - Call `speaker.speak(text, delivery)`, then `speaker.emote(e)` for each emote other than a delivery.
    - The speaker is `speaking` for `LINE_BASE + LINE_PER_CHAR × len(text)` s (× 1.15 for a whisper, × 0.85 for a shout), then a pause drawn from `PAUSE`.
  - **Interrupt.** The speaker is the man of the next turn's part if that man can still speak (valid, not knocked out); otherwise the first filled interrupt part's man who can.
    - He speaks the talk's first interrupt turn for his part, if there is one.
    - Then the talk ends: every remaining member gets `_life._talk_rest = randf_range(TALK_REST)`.
    - A normal end does the same without the interrupt line.
  - **Freed men.** They are dropped silently; members are held as Variants, checked with `is_instance_valid`.
- Produces, in `GuardLife`: the same public API as before.
  - `talking()` = `director.in_talk(guard)`.
  - `partner_direction()` = direction to `speaker_near`, or `Vector3.ZERO`.
  - `end_talk()` = `director.leave(guard)`.
  - `activity()`: `&"talk"` while `director.speaking(guard)`, `&"listen"` while in a talk; the fidgets unchanged until Task 10.

- [ ] **Step 1: Write the failing tests T10–T15 in a yard.**
  - Build the yard in `talk_test._ready` after the pure checks: `Props.block` floor `(0,-0.5,0)`, size `(400,1,60)`, a `NavBakerScript` region awaited on `baked`, and a Player at `(0,1,-25)` with `debug_light_level = 0`.
  - Helpers `_guard(at, yaw, preset, name := "")` and `_fresh()` as in `tests/wits_test.gd`.
  - Each check does `TalkDirector.of(self).use_library(TalkScript.parse(<fixture>, "fixture")...)` with a small fixture library, so the checks don't depend on the writing.
  - T10: two men 2.6 m apart face each other; the fixture's `talk_pair` has 4 alternating turns; `_talk_rest = 0` for both. Within 900 frames 4 lines are barked, alternating men, exactly the fixture's texts in order.
  - T11: three men in a triangle 2.5 m apart; the fixture has one 3-part conversation of 6 turns. Over the whole talk `speaking()` is never true for two at once, and each gap between lines is ≥ `LINE_BASE` s of game time.
  - T12: the fixture `hush` is `when: at_ease` with 4 turns and `-- interrupt` `B: Hush. What was that?`. After line 1, `SoundBus.emit_sound` 60 dB at 6 m. B's last bark is "Hush. What was that?", neither man is `talking()` 20 frames later, and line 3 is never spoken.
  - T13: during `talk_pair`, A calls `bark("Over here!")`. Both men are out of the talk within 12 frames.
  - T14: during `talk_pair`, `queue_free()` the man who is speaking. No SCRIPT ERROR (the suite output is checked), and the other man is out of the talk within 60 frames.
  - T15: during `talk_pair`, B is sent walking 12 m away (`_go_to` and `_walk` via a patrol route). The talk ends once he is beyond `LEAVE_RANGE`, and A is not talking.

- [ ] **Step 2: Run it and watch it fail.** Run `check.sh talk_test`. Expected: T10–T15 FAIL.
- [ ] **Step 3: Implement the director and the GuardLife, Guard and Garrison changes, and migrate the old lines into `at_ease.talk` and `unease.talk`.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh talk_test`, then `check.sh wits_test`, `check.sh stations_test`, `check.sh showcase_test` and `check.sh life_test`. Expected: T1–T15 PASS; W8, T2 and D4 still PASS, and every other line in those suites PASS.
- [ ] **Step 5: Run the whole suite and commit.** Run `run_suites.sh`. Expected: all green. Then `git commit -m "feat(talk): the talk director plays written conversations; GuardLife hands talk to it"`.

---

### Task 4: Memory, variants, late joiners and solo remarks

**Files:**
- Modify: `scripts/AISystem/Talk/TalkDirector.gd`
- Test: `tests/talk_test.gd` (T16–T22)

**Interfaces:**
- Consumes: Task 3's director.
- Produces:
  - `SOLO_GAP := 40.0`, `SOLO_FIRST := Vector2(5.0, 40.0)`, `SOLO_EARSHOT := 15.0`, `SOLO_QUIET := 8.0`.
  - `func remarks() -> Array`: `[{"id", "man", "at"}]`, for tests and the showcase.
  - The memory is the director's, advanced on its own game clock:
    - `cooldown` is measured from the start. `once` means once a night.
    - A `group` cycle: every member of the group is used before any repeats.
    - Per man, the plain and variant texts he has spoken. Casting vetoes a man for a part whose texts he has already said, unless the conversation has `again`. This is `cast_parts`' `allowed` callable.
    - Per unordered pair of cast men, the topics they have aired (the topic is `group` if set, else `id`). This applies only to conversations without a `place`.
  - **Late joiner.** During a talk with an empty optional part, a free man within `TALK_RANGE` of any member who meets that part's requirements (with the talk's cast) fills the part and becomes a member. His later turns are spoken.
  - **Solo remarks.** A man qualifies when all of these hold:
    - he is at ease and in no talk;
    - no other free man is within `TALK_RANGE`;
    - his own `SOLO_GAP` has run out;
    - nobody has remarked within `SOLO_EARSHOT` in the last `SOLO_QUIET` s.

    He may be asleep; only `place: sleep` remarks fit a sleeper.
    - The candidates are conversations with exactly one part whose `place` is his station kind, or empty, and whose `when` holds.
    - Unmarked, a solo line is delivered as `murmur`.

- [ ] **Step 1: Write the failing tests T16–T22,** each with its own fixture library and two or three men as in Task 3.
  - T16: fixtures `a` and `b` have `cooldown: 60s`. The first two talks between the same pair are different ids. With only `a` loaded, a second `a` does not start before 60 s of game time (checked at 55 s) but has started by 75 s.
  - T17: `once` has priority 5, `plain` priority 0. Over 180 s, `once` is played exactly once.
  - T18: three conversations in `group: g` with `cooldown: 0s`. The first three played are all different.
  - T19: two conversations share the line "Cold again." for part A; cast is `A = name(<man1>); B = any`. Over 120 s man1 never says "Cold again." twice.
  - T20: a fixture with `B {if rash}: I'll gut him.` and `B: Let it be.` A rash B says the first; a steady B the second.
  - T21: `C? = any` is empty at the start. A third man walks up from 10 m (a route ending 2 m from them) and speaks C's turn once in range.
  - T22: a man alone at a `chop` station, with fixture `chop_curse` (`place: chop`), remarks within 60 s and not again before `SOLO_GAP`. Two lone men 10 m apart, each with a solo fixture, never remark within `SOLO_QUIET` of each other.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh talk_test`. Expected: T16–T22 FAIL.
- [ ] **Step 3: Implement the memory, variants' use of the veto, late joiners and solo remarks.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh talk_test` (T1–T22 PASS), then `run_suites.sh` (all green).
- [ ] **Step 5: Commit.** `git commit -m "feat(talk): memory, late joiners and solo remarks"`

---

### Task 5: The rig's upper-body layer and posture's new turns

**Files:**
- Modify: `scripts/Visual/Humanoid.gd`, `scripts/Visual/Posture.gd`
- Test: `tests/aliveness_test.gd`, `tests/aliveness_test.tscn` (A1–A3)

**Interfaces:**
- Produces, in `Humanoid`:
  - `func show_upper(animation: StringName, time: float, fade_in := 0.15, weight := 0.9) -> void`: called every frame, like `show_action`, but moving only bones not in `LEGS`.
  - `func clear_upper(fade := 0.25) -> void`, `func upper_weight() -> float`.
  - `func set_walk_clip(clip: StringName) -> void`: sets the animation of blend point 1 of `relaxed`.
  - `var stride := 1.0`: `set_motion`'s pace becomes `position / (natural × stride)`, clamped as now.
  - The tree gets `upper_clip` (AnimationNodeAnimation) → `upper_seek` (TimeSeek) → `upper` (Blend2, `filter_enabled`, filter = `_arm_tracks(&"Idle")`), inserted between `legs` and `output`: input 0 is `legs`, input 1 is `upper_seek`.
  - `_process` eases `upper` toward its goal: `fade_in` up, `fade` down.
- Produces, in `Posture` (every turn is about the man's axes, like the existing ones):
  - `head_pitch` (rad, + down): neck_01 35%, Head 65%, about his right.
  - `chest_yaw` (rad, + left): spine_02 45%, spine_03 55%, about his up.
  - `chest_lean` (rad, + forward): spine_02 50%, spine_03 50%, about his right.
  - `shoulders` (−1..1, + up): clavicle_l and clavicle_r, 0.18 rad at 1, about his forward axis with opposite signs.
  - `breath` (0..1): spine_03 −0.035 rad about his right; clavicles 0.03 rad up.
  - `hip_shift` (−1..1): pelvis 0.05 rad about his forward axis, spine_01 the opposite 0.04.
  - `limp` (0..1) with `limp_phase` (0..1, the walk cycle): a pelvis dip of 0.06 rad × limp × max(0, sin(2π × limp_phase)).
  - `head_pitch`, `chest_*`, `shoulders` and `hip_shift` are smoothed at rate 8, like `head_yaw`. `breath` and `limp` are applied directly. The new turns are applied after `hips_yaw` and before the kick block, and are skipped while `knee > 0.001`.

- [ ] **Step 1: Write the failing tests A1–A3.**
  - Two `Humanoid`s built the way `GuardRig.setup` builds them (read it for the build call and the dress seed), 3 m apart, both driven by `set_motion(Vector3(0,0,-1.1), false, dt)` every physics frame.
  - A1: on twin B, `show_upper(&"Consume", t)` for 1.0 s. At 1.0 s, `bone_global(&"hand_r").origin` of B is more than 0.08 m from A's in their local frames, and `thigh_l`'s local rotation differs by less than 0.02 rad (angle between quaternions).
  - A2: B `clear_upper(0.25)`. After 0.45 s, B's hand is within 0.02 m of A's.
  - A3, standing still: `posture.head_pitch = 0.4` lowers the Head's forward y by > 0.2 against its twin. `shoulders = 1.0` raises `clavicle_l` origin y by > 0.015. `breath` 1 against 0 changes spine_03's rotation by ≥ 0.03 rad.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh aliveness_test`. Expected: SCRIPT ERROR (`show_upper` not found), then FAILs.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh aliveness_test` (A1–A3 PASS), then `run_suites.sh` (all green: the layer sits at weight 0 unless asked).
- [ ] **Step 5: Commit.** `git commit -m "feat(rig): an upper-body action layer, the walk clip and stride, new posture turns"`

---

### Task 6: The voice

**Files:**
- Create: `scripts/AISystem/GuardVoice.gd`
- Modify: `scripts/AISystem/Guard.gd`.
  - `var _voice: RefCounted`, made in `_ready` after `_rig`. `_voice.update(delta)` runs in `_physics_process` next to `_hands.update`, for puppets too.
  - `bark()` calls `_voice.utter(GuardVoice.CALL, text, &"")`; `speak()` calls `_voice.utter(GuardVoice.CHATTER, text, delivery)`; `voice(kind, volume)` calls `_voice.cry(kind, volume)`, keeping the `_voice_at` spacing.
- Modify: `scripts/Audio/Sfx.gd`. `GAIN` gains `murmur` −8, `murmur_f` −8, `laugh` −6, `laugh_f` −6, `sigh` −10, `sigh_f` −10, `cough` −8, `spit` −10, `grunt_effort` −6, `hm` −8, `breath_heavy` −12, `breath_scared` −10, `yawn` −10, `snore` −14, `gasp` −6, `sob` −8. They stay silent until Task 17.
- Test: `tests/talk_test.gd` (T23–T27)

**Interfaces:**
- Produces, in `GuardVoice`:
  - Rungs: `BREATH := 0`, `CHATTER := 1`, `CALL := 2`, `PAIN := 3`, `DEATH := 4`.
  - Heart constants:
    - `HEART_ASLEEP := 60.0`, `HEART_MAX := 170.0`;
    - `GOAL := [72.0, 88.0, 98.0, 108.0, 135.0]`, by `Guard.Alert`;
    - `RUN_ADD := 25.0` (speed > 3 m/s), `FEAR_ADD := 40.0` (× the garrison's `fear_of(nerve)`), `WOUND_ADD := 30.0` (× hurt);
    - `RISE := 0.6` (exponential rate up);
    - `EXHAUSTED_AT := 150.0`, `EXHAUSTION_STEPS := [12.0, 25.0, 45.0]` (seconds above 150, counted), `EXHAUSTION_FLOOR := 8.0` (bpm per step added to the goal), `RECOVER_STEP := 30.0` (s below 100 bpm per step lost);
    - `AUDIBLE_AT := 118.0`.
  - Ladder holds: `HOLD := {CALL: 1.2, PAIN: 0.7}`; DEATH holds forever; CHATTER holds for the line's length.
  - Murmur loudness: `DELIVERY_DB := {&"": 0.0, &"whisper": -10.0, &"murmur": -5.0, &"shout": 7.0}`, added to `Sfx.GAIN["murmur"]`.
  - `func _init(p_guard)`. The per-man recovery rate comes from `look_seed` via a seeded `RandomNumberGenerator`: `randf_range(0.04, 0.08)` per second.
  - `var heart := 72.0`, `var exhaustion := 0`.
  - `func update(delta)`: eases the heart toward the goal (asleep → `HEART_ASLEEP`), advances the breath phase and runs the breathing sounds.
  - `func breath_rate() -> float` = `lerpf(0.22, 0.8, (heart - 60) / 110) × breath variation`. The variation is 1.0 until Task 7 sets it through `var breath_scale`.
  - `func breath_phase() -> float` (0..1), `func out_breath() -> bool` (phase ≥ 0.5).
  - `func utter(rung: int, text: String, delivery: StringName) -> bool`: false if `sounding() > rung`. Otherwise it starts the rung's hold. CHATTER plays the murmur; a CALL or higher stops any murmur.
  - `func cry(kind: StringName, volume := 0.0) -> void`. The rung is DEATH for `death`, else PAIN. It stops the murmur and plays the old `Sfx.play(guard, kind or kind_f, eye, volume, pitch, 0.03)`.
  - `func emote(what: String) -> void`, mapping sounds at the CHATTER rung: laughs → laugh(_f), sighs → sigh(_f), coughs → cough, spits → spit, kicks and throws → grunt_effort. No sound for the rest.
  - `func sounding() -> int` (−1 when nothing sounds), `func murmuring() -> bool`.
  - `func delivery_for(marked: StringName, uneasy: bool) -> StringName`: marked if given; `&"shout"` if heart ≥ 125; `&"whisper"` if `uneasy`; else `&""`.
  - `func hold_heart(bpm: float) -> void`: tests pin the heart there (`-1` releases it).
  - **Murmur.** An `AudioStreamPlayer3D` named `Mouth`, child of the guard's `Head` node (or the guard at +1.6 y), on bus `Sfx.BUS_WORLD`.
    - The stream is `Sfx.stream(&"murmur_f" if female else &"murmur")`. It plays from `randf_range(0, max(len - dur, 0))` with pitch `voice_pitch() × randf_range(0.97, 1.03)`.
    - It fades in over 0.06 s and out over the last 0.15 s of the line (volume tweened in `update`).
    - If `Sfx.recording`, it appends `[&"murmur", db, true]` whether or not a stream exists.
    - `murmuring()` is true for the line's length even when silent.
  - **Breathing.** On each out-breath start at heart ≥ `AUDIBLE_AT` or `exhaustion ≥ 1`: `Sfx.play(guard, &"breath_scared" if afraid else &"breath_heavy", eye, lerpf(-14, -4, (heart-118)/52))`, but only when `sounding() <= BREATH`. Asleep, `snore` on every other out-breath.

- [ ] **Step 1: Write the failing tests T23–T27** in the Task 3 yard.
  - T23: a watchman `_engage(player)` with the player 6 m away. After 600 frames `_voice.heart ≥ 120`. Then `_give_up()`, the player moved 40 m away out of sight, 2400 frames: `heart ≤ 95`.
  - T24: `utter(CHATTER, "Cold tonight.", &"")` → `murmuring()`. `cry(&"pain")` → `sounding() == PAIN` and not `murmuring()`. After 60 frames, `sounding() < CALL`.
  - T25: `utter(CALL, "Over here!", &"")`, then `utter(CHATTER, …)` returns false.
  - T26: with `Sfx.recording = true`, a man held at `heart = 72` (a test setter `_voice.hold_heart(72)` pins the goal) requests no `breath_heavy` in 600 frames. Held at 150, he requests it ≥ 3 times in 600 frames, and `out_breath()` changes on a period within 10% of `1 / breath_rate()`.
  - T27: with `Sfx.recording`, `speak("Hush now.", &"whisper")` and then (after its hold) `speak("Get over here!", &"shout")` record two `murmur` entries, the whisper's dB ≤ the shout's − 12.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh talk_test`. Expected: T23–T27 FAIL.
- [ ] **Step 3: Implement GuardVoice, the Guard hooks and the GAIN keys.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh talk_test` (T1–T27 PASS), `check.sh sound_test` (M8 still PASS: pain_f and pain spoken through `cry`), then `run_suites.sh` (all green).
- [ ] **Step 5: Commit.** `git commit -m "feat(voice): heart rate, the speech ladder, murmur, emote sounds and breathing"`

---

### Task 7: Expression

**Files:**
- Create: `scripts/Visual/Expression.gd`
- Modify: `scripts/AISystem/GuardRig.gd`.
  - Make `expression` in `setup` after `man`, and call `expression.update(delta)` in `_process` after `_animate`.
  - Head yaw becomes `logical + _glance + expression.head_yaw()`, and `posture.head_pitch` becomes `expression.head_pitch()`.
  - Remove `talk`, `listen`, `fold_arms` and `drink` from `ACTIVITIES`. Expression shows them on the upper layer, and `_show_activity` returns false for them.
  - Add `func emote(what: String) -> void` forwarding to `expression.emote`.
- Modify: `scripts/AISystem/Guard.gd`. At the end of `_ready`: `patrol_speed *= Expression.walk_scale(look_seed or path hash, archetype, temper tag)`.
- Test: `tests/aliveness_test.gd` (A4–A10)

**Interfaces:**
- Consumes: `Humanoid.show_upper/clear_upper/set_walk_clip/stride` and the Posture vars (Task 5); `GuardVoice.breath_phase()`, `heart`, `breath_scale` (Task 6); `TalkDirector.speaker_near`, `speaking` (Task 3).
- Produces:
  - `static func variation(seed: int, kind: StringName, tag: StringName) -> Dictionary` returns `{"walk", "rhythm", "breath", "gesture", "darts"}`.
    - Each is `rng.randfn(mean, sd)` clamped, from a `RandomNumberGenerator` seeded with `seed`.
    - Means are 1.0 except `gesture` = `GESTURE[tag]`. The sds and clamps:
      - walk: sd 0.04, clamp 0.92–1.08;
      - rhythm: sd 0.12, clamp 0.8–1.25;
      - breath: sd 0.08, clamp 0.85–1.15;
      - gesture: sd 0.15, clamp 0.6–1.4 × mean;
      - darts: sd 0.25, clamp 0.5–1.6.
  - `static func walk_scale(seed: int, kind: StringName, tag: StringName) -> float` = `variation.walk × GAIT[tag][0]`.
  - `POSTURE` (tag → `[chest_lean, shoulders, head_pitch]`): rash `[0.06, 0.0, -0.05]`, craven `[0.12, 0.45, 0.12]`, stubborn `[-0.04, -0.1, -0.03]`, sly `[0.08, 0.15, 0.05]`, steady `[0, 0, 0]`.
    - Fear adds `craven_row × fear_of(nerve)`.
    - `grief > 0.5` adds shoulders −0.4.
    - Within 4 m of a captain on her round (Task 12's `Gathering.captain_near(man)`, when the script exists), he eases to the stubborn row for 2 s.
  - `GAIT` (tag → `[speed, stride]`): rash `[1.06, 1.1]`, craven `[1.03, 0.85]`, stubborn `[0.95, 1.0]`, sly `[1.0, 0.95]`, steady `[1, 1]`. A man with the sheet trait `captain` gets `set_walk_clip(&"Walk_Formal")`.
  - `GESTURE` (tag → talking gesture weight): rash 1.0, steady 0.7, craven 0.5, stubborn 0.4, sly 0.25.
  - Gaze, only while `state <= SUSPICIOUS` and not in COMBAT. The first of these that applies is the target:
    1. the intruder, if `can_see_target`;
    2. `last_known_position`, if SUSPICIOUS;
    3. `speaker_near`, if in a talk;
    4. a guard within 4 m moving faster than 0.8 m/s;
    5. the nearest `fires` node, if his activity is `warm_hands` or `squat`;
    6. the landmark "the tower", pitch up to −0.5, if his activity is `look_up`;
    7. straight ahead.

    Yaw is clamped to ±1.2; `chest_yaw = 0.25 × yaw`.
    - Darts come every 3–6 s at ±0.15 rad (steady, stubborn, rash), or every 1–2.5 s at ±0.35 (sly, craven), with the interval ÷ `darts`. Each is held 0.4–1.0 s.
  - Upper-layer priority:
    1. An emote gesture. `EMOTE_GESTURES`:
       - clips: nods → `Yes` 1.2 s; shakes → `Idle_No` 1.2 s; drinks → `Consume` 1.33 s; points → `Spell_Simple_Shoot` 0.62 s, gaze to the landmark; throws → `OverhandThrow` 0.9 s; nudges → `Push` 1.5 s;
       - procedural: shrugs → a shoulders pulse +0.8 over 0.6 s; laughs → head_pitch −0.15 plus a shoulders shake over 1 s; sighs → shoulders −0.4 over 1.2 s; coughs → two head_pitch +0.2 pulses over 0.8 s; spits → head_pitch +0.25 over 0.5 s; kicks → `man.kick_pose` knee 0.6 to extend 1 over 0.5 s.
    2. Speaking: `Idle_Talking` at weight `GESTURE × gesture`.
    3. `UPPER_ACTIVITIES`: fold_arms `Idle_FoldArms`, listen `Idle_FoldArms` (at 0.6 weight), drink `Consume`, scratch `Zombie_Scratch`, warm_hands `Spell_Simple_Idle`, check_blade `Sword_Idle`, carry_log `Walk_Carry`.
    4. `clear_upper()`.

    A seated man (activity `sit_talk`) gets no talking gesture, since the full body already shows it.
  - Breathing: `posture.breath = (0.5 - 0.5 × cos(TAU × breath_phase)) × lerpf(0.4, 1.0, (heart - 60) / 110)`. `voice.breath_scale = variation.breath`.
  - Weight shifts: when his speed is under 0.2, every `randf_range(3, 7) × rhythm` s, `hip_shift` eases to `±randf_range(0.4, 1.0)`.
  - Limp: below half health, `limp = 1 - health / (0.5 × max)`; `limp_phase = fposmod(_walk_phase / TAU, 1)`.
  - Perlin drift: `FastNoiseLite` seeded with the man's seed nudges `rhythm` and `darts` by ±10% over ~20 s.
  - `func emote(what: String) -> void`, `func head_yaw() -> float`, `func head_pitch() -> float`, `var traits: Dictionary` (the variation).
  - **Listeners react** (spec 4.2). When a line ends, TalkDirector picks one listener.
    - If the next turn is his and its choice carries `nods` or `shakes`, he does that.
    - Otherwise he nods or shakes by chance: steady and stubborn nod 0.35; rash shakes 0.25; the rest nod 0.15.
    - This is a director change in this task: `TalkDirector._line_ended(talk)` calls `listener.emote(...)`.
  - Captain check: `Gathering.captain_near` is reached through `ResourceLoader.exists` and `load` (Gathering is made in Task 11).
  - A hand to the wound is dropped: no library clip reads as it (spec 13: clips that read wrong are dropped). The limp stays.

- [ ] **Step 1: Write the failing tests A4–A10** in `aliveness_test`'s yard: a floor, a NavBaker, a Player far off, and guards made as in wits_test.
  - A4: two men talk a fixture conversation. While A speaks, B's Head bone forward is within 35° of the direction to A's head.
  - A5: a craven and a steady watchman stand idle 30 frames. The craven's `clavicle_l` y minus `pelvis` y is higher by > 0.015, and his Head forward y is lower by > 0.05.
  - A6: `variation(1,…).walk != variation(2,…).walk`. Two watchmen with look_seeds 21 and 22 have `patrol_speed` differing by ≥ 0.5%, and their `traits.rhythm` differ.
  - A7: over 600 frames at a steady heart, spine_03's local rotation angle oscillates. Its peaks number `round(breath_rate() × 10) ± 1`.
  - A8: a standing man speaks a line. `man.upper_weight() > 0.3` mid-line, and `thigh_l` stays within 0.03 rad of an idle twin's.
  - A9: a guard given the sheet name "Mirelle" (trait captain) has blend point 1 of `relaxed` animating `Walk_Formal`.
  - A10: `emote("nods")` makes `upper_clip.animation == &"Yes"` within 6 frames and `upper_weight() < 0.05` by 90 frames. In a fixture talk whose second turn carries `[nods]`, the second man starts `Yes` within 6 frames of the first line's end.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh aliveness_test`. Expected: A4–A10 FAIL.
- [ ] **Step 3: Implement Expression, the GuardRig wiring and the walk scale.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh aliveness_test` (A1–A10 PASS), then `run_suites.sh`. Expected: all green. Any suite whose timings drift from the walk scale is fixed by pinning `look_seed` in that test or widening a timing margin, never by changing the scale. Ledger each one.
- [ ] **Step 5: Commit.** `git commit -m "feat(expression): gaze, posture and gait by temperament, breathing, weight shifts, gestures, per-man variation"`

---

### Task 8: The fire burns down

**Files:**
- Modify: `scripts/Combat/Fire.gd`, `scripts/Visual/Torch.gd`
- Test: `tests/routines_test.gd`, `tests/routines_test.tscn` (R1–R2)

**Interfaces:**
- Produces, in `Fire`:
  - `@export var fuel_seconds := 240.0`, `var fuel := 1.0`, `var torch: Node3D` (set by `brazier`).
  - `LOW_AT := 0.35`, `EMBERS := 0.08`, `FLARE := 1.5`, `FLARE_TIME := 2.0`.
  - `func feed(amount := 0.6) -> void`, `func low() -> bool`, `func burning() -> StringName` (`&"low"` or `&"burning"`), `func strength() -> float` (`lerpf(0.25, 1.0, fuel)` × the flare).
  - It joins group `fires`, and each frame burns `fuel -= delta / fuel_seconds`, floored at `EMBERS`.
  - The flare eases from `FLARE` to 1 over `FLARE_TIME`. It calls `torch.set_strength(strength())`.
- Produces, in `Torch`: `func set_strength(k: float) -> void`.
  - `light.light_energy = energy × k × flicker`, and `omni_range = light_range × lerpf(0.55, 1.0, clampf(k, 0, 1))`.
  - `flame.scale = lerpf(0.35, 1.0, clampf(k, 0, 1.5)) × flicker`.
  - `_process` keeps its flicker, multiplied by the strength.

- [ ] **Step 1: Write the failing tests.**
  - R1: a brazier with `fuel_seconds = 10`. After 480 frames, `low()` is true and the light energy is < 0.6 × the full-fuel energy; after 900 frames, fuel is ≥ 0.08.
  - R2: `feed()`. Fuel rises by 0.6 (capped at 1), and the light energy 10 frames later is > the full-fuel energy (the flare). After 180 frames it is back within 10% of `energy × strength-without-flare`.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh routines_test`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh routines_test` (R1–R2 PASS), `check.sh showcase_test` (still green), then `run_suites.sh`.
- [ ] **Step 5: Commit.** `git commit -m "feat(fire): fuel that burns down, a flare when fed, the light follows"`

---

### Task 9: The night rota

**Files:**
- Create: `scripts/AISystem/NightRota.gd`
- Modify: `scripts/AISystem/Guard.gd`, adding `func take_duty(duty: Dictionary) -> void`.
- Modify: `scripts/AISystem/GuardRota.gd`, adding `set_stations`, `lend`, `end_loan`, `on_loan`, `at_station`.
- Modify: `scripts/AISystem/GuardLife.gd`. `update` calls `NightRota.of(guard).tick(delta)` if a rota exists.
- Modify: `scripts/AISystem/Garrison.gd`. `clear_all` also clears NightRota.
- Test: `tests/routines_test.gd` (R3–R7)

**Interfaces:**
- Produces, in `NightRota`:
  - `static func setup(node: Node, hour_length: float, start_hour := &"early") -> RefCounted` (per tree). `static func of(node: Node) -> RefCounted`, null when no level set one up. `static func clear_all()`.
  - `HOURS := [&"early", &"middle", &"late", &"dawn"]`.
  - Need rates:
    - `TIRED_RATE := 1.0 / 300.0` and `SLEEP_RATE := 1.0 / 60.0`;
    - `HUNGRY_RATE := 1.0 / 240.0` and `EAT_RATE := 1.0 / 40.0`;
    - `COLD_RATE := 1.0 / 180.0` and `WARM_RATE := 1.0 / 30.0`, with `FIRE_WARMTH := 5.0` m (a `fires` node within it warms him).
  - `var post_turn := 600.0`, `SUSPEND_ALARM := 0.3`.
  - `func add_duty(id: StringName, kind: StringName, data: Dictionary) -> void`, with `kind` one of:
    - `&"post"`: `{"transform": Transform3D}`;
    - `&"round"`: `{"route": NodePath}`;
    - `&"stations"`, `&"bench"` or `&"bed"`: `{"paths": Array[NodePath]}`.
  - `func assign(man: Node, id: StringName) -> void` calls `man.take_duty(duty)` and records it.
  - `func duty_of(man) -> StringName`, `func men_on(id) -> Array`, `func hour() -> StringName`, `func needs_of(man) -> Dictionary` (`{tired, hungry, cold}`), `func on_post_for(man) -> float`.
  - `func tick(delta)`: once per frame. Needs rise and fall by where he is and what he does: asleep, eating, near a fire.
    - When not `suspended()`, it queues wants: `{"kind": &"relief", "man", "duty"}` when `on_post_for(man) > post_turn` or his tired ≥ 1, and `{"kind": &"rest", "man", "need": &"tired"|&"hungry"|&"cold"}` when a need reaches 1. Each man and kind is queued once until taken.
  - `func take_wanted() -> Array`, `func wanted() -> Array` (peek).
  - `func suspended() -> bool`: the garrison's alarm ≥ `SUSPEND_ALARM`, or any guard SEARCHING or in COMBAT.
  - `func swap(a: Node, b: Node) -> void`: exchanges the two duties and resets `on_post_for` for both.
  - `func set_need(man: Node, need: StringName, value: float) -> void`: a test setter.
  - `func free_duty(kind: StringName) -> StringName`: a duty of `kind` nobody holds, or `&""`.
- Produces, in `Guard.take_duty(duty)`:
  - `post`: `_home = transform`; waypoints cleared; `_rota.set_stations([])`.
  - `round`: `_waypoints` from the route's `Node3D` children; `_waypoint_index = 0`; `_go_to(first, true)`.
  - `stations`, `bench`, `bed`: `_rota.set_stations(nodes)`; waypoints cleared.
- Produces, in `GuardRota`:
  - `func set_stations(nodes: Array[Node3D]) -> void`: releases what he holds (without the exit clip if he is walking), then replaces the list.
  - `func lend(station: Node3D) -> void`: keeps his own list aside and holds only the loan.
  - `func end_loan() -> void`: releases and restores his list; it exits the way `stir` does for sit and squat.
  - `func on_loan() -> bool`, `func at_station() -> bool` (step DOING or ENTER finished).

- [ ] **Step 1: Write the failing tests** in `routines_test`'s yard: a floor, a NavBaker, a brazier at the origin, a Player far off out of sight.
  - R3: `setup(self, 10.0)`. `hour()` is `early` at 0 s, `middle` at 12 s and `dawn` at 35 s.
  - R4: a man 10 m from the fire has cold rising (> 0.05 after 900 frames); beside the fire it falls. A man on a `bed` duty asleep has tired falling.
  - R5: `post_turn = 20`. A man on a post duty is in `wanted()` as relief after 20 s, not before 18 s.
  - R6: the garrison's alarm set to 0.5 makes `suspended()` true; needs keep rising but nothing is wanted. With the alarm at 0 and everyone relaxed, it resumes.
  - R7: `assign(man, &"yard_round")` has him walk the route (he reaches waypoint 1 within 600 frames). `assign(man, &"postern")` has him stand within 0.8 m of the post.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh routines_test`. Expected: R3–R7 FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh routines_test` (R1–R7 PASS), `check.sh stations_test` (green), then `run_suites.sh`.
- [ ] **Step 5: Commit.** `git commit -m "feat(rota): the night rota: duties, needs, the hour, relief wanted"`

---

### Task 10: Pastimes

**Files:**
- Create: `scripts/AISystem/GuardPastimes.gd`
- Modify: `scripts/AISystem/GuardLife.gd`.
  - `at_rest` and `walking` delegate to `_pastimes`. `activity()` returns talk/listen first, else `_pastimes.activity()` while RELAXED.
  - Delete `_idle`, `_idle_left`, `_idle_wait` and the fold_arms/drink fidget.
- Modify: `scripts/AISystem/Guard.gd`. In `_do_patrol`'s no-waypoint branch: if `_life.pastime_step()` is a Vector3, `_go_to` it and `_walk(patrol_speed × 0.6)` instead of `_stop`.
- Modify: `scripts/AISystem/GuardRig.gd`. `ACTIVITIES` gains `squat: [&"Crouch_Idle", true, 0.3, 1.0]` (`lean` exists).
- Test: `tests/aliveness_test.gd` (A11–A15)

**Interfaces:**
- Consumes: `NightRota.needs_of` (Task 9), the fires group (Task 8), Expression's upper activities (Task 7).
- Produces:
  - `GuardPastimes.new(guard)`, `func at_rest(delta)`, `func walking()`, `func activity() -> StringName`, `func wants_step() -> Variant`.
  - `func choose() -> StringName`: one pick now, using and updating the memory; the test hook. `func history() -> Array[StringName]` (the last 5, newest last).
  - `GuardLife.pastime_step() -> Variant` forwards `wants_step()`.
  - `IDLE_AFTER := 3.0`, `GAP := Vector2(2.0, 6.0)` (× the man's `rhythm`), `POOL := 0.8`, `MEMORY := [0.5, 0.3, 0.2, 0.1, 0.05]`.
  - `OPTIONS` (id → `{cat, needs, len, cd}`):

    | id | cat | needs | len (s) | cd (s) |
    |---|---|---|---|---|
    | warm_hands | cold | fire ≤ 3 m | 6–12 | 20 |
    | squat | cold | fire ≤ 2.5 m | 8–15 | 40 |
    | stamp | cold | cold ≥ 0.4 | 3–5 | 15 |
    | lean | tired | a wall behind or beside within 1 m (ray at 1.1 m) | 8–14 | 30 |
    | scratch | idle | none | 2–3.6 | 25 |
    | drink | idle | none | 1.33 | 30 |
    | fold_arms | idle | none | 5–9 | 10 |
    | check_blade | idle | weapon shown (not sheathed) | 2.5–4 | 45 |
    | look_up | idle | landmark "the tower" within 35 m and in line of sight | 3–5 | 40 |
    | pace | idle | a navmesh point 1.5 m ahead reachable | 6–10 | 35 |
    | spit | idle | none | 1.0 | 50 |
    | roll_shoulders | idle | none | 1.5 | 30 |

  - Categories go in order: cold (cold ≥ 0.5), then tired (tired ≥ 0.6), then idle. The first category with an available option wins.
  - Utility = `TEMPER_WEIGHT[tag].get(id, 1.0) × (1 - penalty)`, where `penalty` is the sum of `MEMORY[i]` over the history positions holding this id.
    - The pool is the options with utility ≥ `POOL` × best, sampled by utility.
    - Streak filter: never the last pick, never an id already twice in the last 4.
  - `TEMPER_WEIGHT`:
    - rash: stamp 1.3, spit 1.5, roll_shoulders 1.4, check_blade 1.5, fold_arms 0.8;
    - craven: look_up 1.5, pace 1.5, scratch 1.3, drink 1.3, check_blade 0.6;
    - stubborn: fold_arms 1.6, lean 0.6, spit 1.2;
    - sly: lean 1.6, scratch 0.7, look_up 1.2.
  - Pace: out to the 1.5 m point and back to where he stood, at 0.6 × patrol speed. `activity()` is `&"pace"` while he walks.
  - Sitting is not a pastime here. A tired man sits through the rota's `bench` duty (NightRota, Task 9; spec 5.1's "tired → lean or sit"), and the needs route him there (Task 12).
  - Stamp, spit and roll_shoulders are procedural in Expression: stamp a quick hip_shift ±1 at 3 Hz; spit is emote spits; roll_shoulders a shoulders pulse up and back over 1.5 s.

- [ ] **Step 1: Write the failing tests A11–A15.**
  - A11: `choose()` 200 times in a row (no waiting). No two consecutive are the same, and no window of 5 holds any id 3 times.
  - A12: a man 2 m from a brazier, with NightRota cold forced to 0.8 (the rota's test setter `set_need(man, &"cold", 0.8)`), picks from {warm_hands, squat, stamp} for 20 picks. The same man 20 m from any fire picks stamp or an idle option only.
  - A13: with no fire, no wall and a sheathed weapon (station sheathed), 100 picks hold no warm_hands, squat, lean or check_blade.
  - A14: 300 picks each for a stubborn and a steady man: the stubborn fold_arms share exceeds the steady one's.
  - A15: a man standing his post (no route), after 3600 frames, has shown ≥ 3 different activities. His distance from the post stays ≤ 2.0 m throughout, and he ends within 0.8 m once not pacing.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh aliveness_test`. Expected: A11–A15 FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh aliveness_test` (A1–A15 PASS), then `check.sh showcase_test` and `check.sh stations_test`.
  - In showcase_test, `SHOWS[&"eat"]` and `SHOWS[&"chop"]` gain the new pastime names only if a check reads them; ledger any test data change.
  - Then `run_suites.sh`.
- [ ] **Step 5: Commit.** `git commit -m "feat(pastimes): pastimes by dual utility with memory, replacing the two fidgets"`

---

### Task 11: Gatherings I: the director, dice, the flask, a story

**Files:**
- Create: `scripts/AISystem/Gathering.gd`
- Modify: `scripts/AISystem/Talk/TalkDirector.gd`.
  - Add `func play_place(members: Array, place: StringName) -> bool`: the best-fitting `place:` conversation cast from exactly these men.
  - Members of a live gathering are left out of ordinary groups and solo remarks.
- Modify: `scripts/AISystem/Garrison.gd` (`clear_all` clears Gathering), `scripts/AISystem/GuardLife.gd` (`update` ticks `Gathering.of(guard)`).
- Modify: `scripts/AISystem/GuardStation.gd`, documenting the loan kinds `squat` and `stand` (`stand` has no clip: he stands facing).
- Create: in `data/talk/gatherings.talk`:
  - 3 dice conversations, `place: dice`, `group: dice`;
  - 2 flask, `place: flask`;
  - 3 stories, `place: story`, with `A = storyteller|rank>=2` and `B`, `C?`, `D?` listeners; the longest writing, 8–12 turns, a laugh at the end;
  - invites `invite_dice`, `invite_story`, `invite_flask`, each 2 turns (e.g. "Dice?" / "Go on then.").
- Test: `tests/routines_test.gd` (R8–R10)

**Interfaces:**
- Consumes: `GuardRota.lend/end_loan/at_station` (Task 9), `NightRota.suspended()`, `TalkDirector.play`, `play_place`, `talks()`.
- Produces:
  - `static func of(node: Node) -> RefCounted` (per tree), `static func clear_all()`.
  - `func tick(delta)` runs once per frame. Every `START_EVERY := 4.0` s, unless `NightRota.of(...)` exists and is suspended, it may start one.
  - `func request(kind: StringName, names := []) -> void` puts `kind` at the head of the queue, ignoring its cooldown. `names`, if given, are who must be in it.
  - `func live() -> Array` of `{"kind", "members": Array, "roles": Dictionary, "place": Node3D, "started_at", "conversations": int, "state": &"invite"|&"gathering"|&"playing"|&"ending"}`.
  - `func history() -> Array[StringName]`: kinds that reached `playing`.
  - `func member_of(man) -> Dictionary`.
  - Places are `Marker3D` nodes in group `gathering_places` with meta `gathering` (the kind). Their `Marker3D` children are spots, each with meta `activity` (`squat`/`stand`/`sit`) and meta `role` (`teller`/`listener`/`any`); a spot faces its -Z.
  - `KINDS`:
    - dice: size [2, 3], place `dice`, length 45–80 s, convs 2, cooldown 150, reach 14 m;
    - flask: size [2, 2], no place (spots made where the first two free men stand, facing each other 1.2 m apart), length 12–20, convs 1, cooldown 90, reach 5 m;
    - story: size [3, 4], place `story`, roles teller + listeners, until its one story conversation ends, cooldown 180, reach 14 m.
  - A free man for a gathering:
    - at ease, not a lookout;
    - not on a `post` duty (if a rota exists), not carrying, not asleep;
    - not in a talk unless it is his invite;
    - within `reach` of the place.

    The teller needs the trait `storyteller` or rank ≥ 2.
  - Flow:
    1. Invite: the invite conversation plays with the first two members.
    2. Each member gets a `GuardStation` made at his spot (kind = the spot's `activity`) and `lend()`s it.
    3. Once all are `at_station()`, `play_place` runs up to `convs` times, 3–6 s apart. Its `talks()` members are exactly the gathering's.
    4. At the end (time up, convs done, or the story done), every member calls `end_loan()`, gets `_talk_rest = TALK_REST`, and the stations are freed.
    5. It ends early the moment a member is invalid, knocked out or not at ease.
  - `func captain_near(man: Node) -> bool`: a `round` gathering's captain is within 4 m of him (Task 12 fills the round; false until then).

- [ ] **Step 1: Write the failing tests** in the routines yard, with a dice place (a crate, 3 squat spots) and a story place (a brazier, 4 spots: 1 teller, 3 listeners).
  - R8: three free men 6 m from the dice place, `request(&"dice")`. Within 600 frames `live()` has dice with 3 members, each within 0.8 m of his spot, and within 2400 frames ≥ 1 dice conversation is in `played()`. Then a 60 dB sound beside one member: within 120 frames the gathering is gone and no member is `on_loan()`.
  - R9: two free men 2 m apart, `request(&"flask")`. A flask conversation is played by exactly those two, and both are off loan within 1500 frames.
  - R10: four free men, one with trait storyteller (a sheet name that has it: the test uses a fixture sheet via `TalkDirector.use_library`). `request(&"story")` makes the teller A of a story conversation with ≥ 2 listeners at spots. While the teller speaks, each listener's Head forward is within 40° of the teller.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh routines_test`. Expected: R8–R10 FAIL.
- [ ] **Step 3: Implement the director, the three kinds and their writing.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh routines_test` (R1–R10 PASS), `check.sh talk_test` (T1 still clean with the new file), then `run_suites.sh`.
- [ ] **Step 5: Commit.** `git commit -m "feat(gatherings): the gathering director, dice, the flask, a story"`

---

### Task 12: Gatherings II: the watch changes, the captain's round, waking the sleeper, feeding the fire

**Files:**
- Modify: `scripts/AISystem/Gathering.gd`, adding the four kinds and consuming `NightRota.take_wanted()`.
- Modify: `scripts/AISystem/GuardRig.gd`. `ACTIVITIES` gains `feed_fire: [&"Fixing_Kneeling", false, 0.2, 1.0]` and `pick_log: [&"Farm_Harvest", false, 0.15, 1.0]`. `warm_hands` as a loan station kind is shown by Expression's upper table.
- Create: in `data/talk/gatherings.talk`:
  - 4 watch-change conversations, `place: watch_change`, `A` the man on the post and `B` the relief; one is "Anything?" / "Nothing but the cold";
  - `place: round` lines: one per cast man by name or temperament (12), round_tam among them;
  - 2 wake, `place: wake`, `B = sleeps_on_watch|asleep`;
  - 2 fire, `place: fire`, 1–2 parts.
- Test: `tests/routines_test.gd` (R11–R14)

**Interfaces:**
- Consumes: `NightRota.take_wanted`, `swap`, `assign`, `duty_of` (Task 9); `Fire.low/feed` (Task 8); `GuardRota.stir()` (existing) to wake a sleeper.
- Produces the four `KINDS`:
  - `watch_change`: made from a `relief` want.
    - The relief is the free man (duty `bench` or `stations`, or none) with the lowest tired need; failing that, a sleeper through `wake` first.
    - He lends a `stand` station 1.1 m from the post, facing the man on it. A `watch_change` conversation plays (A = on post, B = relief).
    - Then `NightRota.swap(on_post, relief)`: the relief takes the post, the relieved man the relief's old duty, or `bed` if his tired ≥ 0.8.
  - `round`: size 1 (a man with trait captain), cooldown 240.
    - She visits up to 6 men at ease, nearest first. For each she lends a `stand` station 1.2 m from him, facing him, and plays `play_place([captain, him], &"round")`.
    - A sleeper's conversation carries `[kicks]`. After it, `him._rota.stir()` wakes him, and NightRota queues nothing new for him.
    - `captain_near(man)` is true while she is within 4 m of him.
  - `wake`: made when a relief is needed and the best free man is asleep.
    - The nearest awake free man walks to the sleeper's side and emotes `nudges`. The sleeper `stir()`s awake, the wake conversation plays, and the `watch_change` follows with the woken man as relief.
  - `fire`: when any `fires` node is `low()`.
    - The nearest free man goes to the nearest `woodpiles` Marker3D (activity `pick_log` 1.0 s), then carries (activity `carry_log`) to a spot 0.9 m from the brazier.
    - There he kneels (activity `feed_fire`, 2.5 s), then `fire.feed(0.6)`, and a `place: fire` conversation plays with him plus anyone free within 4 m.
- Produces the handling of `rest` wants (spec 6.2, "needs move men"). A man on a post is relieved first, through a `relief` want. Otherwise:
  - tired: `NightRota.assign(man, free_duty(&"bed"))`, or `&"bench"` if no bed is free;
  - hungry: `lend` of the nearest free `eat` station for 30 s;
  - cold: `lend` of a `warm_hands` station at a free spot on the fire's ring for 25 s.

- [ ] **Step 1: Write the failing tests.**
  - R11: man A on a post duty (the post 8 m from the fire), man B on a bench duty. `post_turn = 10`.
    - Within 2400 frames: B has come within 1.5 m of the post, and a `watch_change` conversation with A and B cast is in `played()`.
    - Then `duty_of(B) == &"post"` and `duty_of(A) == &"bench"`, A is > 3 m from the post within 600 more frames, and B stands within 0.8 m of it.
  - R12: a captain (sheet trait captain via the fixture sheet) and 4 men at ease, one asleep on a bed station. `request(&"round")`. Within 7200 frames the round has played a `round` conversation with each of the 4 as B, and the sleeper is no longer `asleep()`.
  - R13: a relief wanted, and the only free man asleep: a `wake` gathering plays, the sleeper stands, and he then takes the post through a watch change.
  - R14: a brazier with fuel 0.3 (`fuel_seconds` large) and a woodpile marker 6 m away. Within 2400 frames a man shows `pick_log`, then `feed_fire`, and the fuel is > 0.8.
  - R15, needs move men:
    - Hunger set to 1: he goes to the free eat station and shows `eat` within 900 frames.
    - Cold set to 1, 12 m from the fire: he shows `warm_hands` within 2 m of it within 900 frames.
    - Tired set to 1, on a bench duty: `duty_of` him becomes a bed duty.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh routines_test`. Expected: R11–R15 FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh routines_test` (R1–R15 PASS), then `run_suites.sh`.
- [ ] **Step 5: Commit.** `git commit -m "feat(gatherings): the watch change, the captain's round, waking the sleeper, feeding the fire"`

---

### Task 13: Call-and-answer, grief by name, the missing, the lookout's send

**Files:**
- Modify: `scripts/AISystem/Talk/TalkDirector.gd`, adding `call_pair`, `grieve` and `play_missing`.
- Modify: `scripts/AISystem/Squad.gd`.
  - The tactic call (line ~785, `caller.bark(lines[…])`) first tries `TalkDirector.of(caller).call_pair(StringName("tactic_" + tactic), caller)`. It falls back to the bark.
  - `member_died` tries `call_pair(&"man_down", <a living member>, {"dead_name": called})`.
  - `_give_places` tries `call_pair(&"excuse", man)` when a man is set to a place within 3 m of where a friend fell.
  - Resolve: `resolve -= GRIEF_WEIGHT * man.grief` for men with nerve < `Temperament.CRAVEN_AT`, where `GRIEF_WEIGHT := 0.25`.
  - The hunt's call (line ~1522, `guard.bark(t.line(&"hunt"))`) first tries `call_pair(&"spotted_ask", guard)`. The pair is "Anyone see him?" / "He went {place}!", with `place_name` from the squad's last known position.
  - A man given `fetch` or `flee` who is the last of them standing tries `call_pair(&"last_man", man)` ("I'll fetch the others!").
  - Status checks: in `think`, at most every 20 s, if a member is below 60% health, the leader tries `call_pair(&"status", leader)` with B required to be `hurt`.
- Modify: `scripts/AISystem/Guard.gd`.
  - Add `var grief := 0.0`.
  - In `_discover(body)`: if `body.called != ""`, call `TalkDirector.of(self).grieve(self, body.called)`.
  - In `die()`, before `queue_free`: every guard within 20 m with line of sight to him and a kin or friend tie calls `grieve(that, given_name)`.
  - The lookout's send (line ~2335) tries `call_pair(&"send", self, {"place_name": Comms.place(where, self), "friend": friend})`, else the old bark.
- Modify: `scripts/AISystem/GuardBody.gd`: `var called := ""`, set in `spawn` from `guard.given_name`.
- Modify: `scripts/AISystem/GuardFighter.gd`: `var rage_until := -1.0`; `_judge_mood` returns `&"enraged"` while `guard._game_time < rage_until` (checked first after `desperate`).
- Modify: `scripts/AISystem/GuardLife.gd`. `_look_for_missing` tries `TalkDirector.of(guard).play_missing(guard, name)` before its temper-line bark.
- Create: `data/talk/combat.talk`, up to about 25 pairs:
  - status checks by hurt;
  - "Anyone see him?" with an answer naming `{place}`;
  - man down with counts;
  - excuses (`not_there`, `no_way`);
  - "I'll fetch the others!";
  - `tactic_<name>` pairs for each `Squad.CALLS` key;
  - `send` with craven and sly variants of the answer.
- Create: `data/talk/fear.talk`, up to about 8:
  - a grief conversation per tie in the sheet (`dead(<name>)`, `A = kin(<name>)|friend(<name>)`), priority 10;
  - `where_is_<name>` missing conversations;
  - fear lines for `dread>=0.35`.
- Test: `tests/talk_test.gd` (T28–T33)

**Interfaces:**
- Produces:
  - `func call_pair(situation: StringName, caller: Node, facts := {}) -> bool`.
    - Candidates have `situation:<situation>` in `when`. A is the caller. B is a man who is alive, not knocked out, `_voice.sounding() < PAIN`, within `EARSHOT_CALL := 25.0` m, and meets B's requirements.
    - It plays at once, pre-empting any chatter of theirs; unmarked lines come out as `shout`. It returns false if none fits.
  - `func grieve(man: Node, dead_name: String) -> bool`.
    - Only if `man` has a kin or friend tie to `dead_name`. It plays the highest-priority conversation with `dead(<dead_name>)` whose A he fits, with `world.dead_name = dead_name`.
    - It sets `man.grief` to 1.0 (kin) or 0.6 (friend). A rash man gets `_fighter.rage_until = _game_time + 20`.
    - Kin grief stays 1.0 for the night; friend grief decays 0.01/s to 0.
  - `func play_missing(man: Node, missing_name: String) -> bool`: a conversation with `missing(<missing_name>)`, or a generic missing conversation with `{dead}` set to the name.
  - `TalkFacts.world` gains `missing` from `Garrison.fallen` entries that are `noticed`, and `dead_name` from `extra`.

- [ ] **Step 1: Write the failing tests** in the talk yard with the real library.
  - T28: two watchmen in combat with the player (engaged); the second at 50% health. `call_pair(&"status", first)` returns true; the second's next line is one of `status_check`'s B choices, spoken after the first's.
  - T29: the answerer knocked out, or moved 40 m off: `call_pair` returns false.
  - T30: two guards named Osric and Jory (so the sheet ties apply). Jory is killed (`die(player)`) in Osric's line of sight 6 m away. Within 180 frames Osric barks a line containing "Jory", and `Osric.grief ≥ 0.9`.
  - T31: a craven friend of the dead man in a squad has `resolve_of` lower than a craven non-friend twin by ≥ 0.2 at the next judge. A rash friend's `_fighter.mood == &"enraged"` within 30 frames.
  - T32: a `fallen` post named "Hendrik", noticed by a man at ease: his bark contains "Hendrik".
  - T33: a lookout sends a named friend. Within 180 frames the friend barks one of `send`'s B choices.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh talk_test`. Expected: T28–T33 FAIL.
- [ ] **Step 3: Implement the hooks and the writing.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh talk_test` (T1–T33 PASS), then `check.sh squad_test`, `check.sh hunt_test`, `check.sh wits_test` (green: every bark falls back), then `run_suites.sh`.
- [ ] **Step 5: Commit.** `git commit -m "feat(talk): call-and-answer in the fight, grief by name, the missing, the lookout's send"`

---

### Task 14: The writing

**Files:**
- Modify: `data/talk/at_ease.talk`, up to about 22 conversations (plus the migrated small talk), drawing on every man's sheet line and ties.
- Modify: `data/talk/unease.talk`, about 5 new plus the migrated ones.
- Modify: `data/talk/solo.talk`, about 100 remarks:
  - by station place: sit, eat, sleep (Tam's sleep talk), rummage (Gideon and the oil), carry (Ned), chop (Brand), lean;
  - by pastime or where he is: `near(the fire)`, `near(the tower)`;
  - the wall walk: Wat sings, `name(Wat)`;
  - the lookout: Aldous' knees;
  - general, at `when: cold` and `night:late`.
- Modify: `data/talk/combat.talk`, `fear.talk` and `gatherings.talk`, topped up to the spec's volumes.
- Test: `tests/talk_test.gd` (T34–T37)

**Interfaces:**
- Consumes: the format (Tasks 1–4, 11–13). No code changes, unless a check exposes a parser gap; ledger it.

- [ ] **Step 1: Write the failing tests.**
  - T34: every conversation can be cast from the showcase's men, ignoring `when`. The twelve `TalkFacts.sheet_man(name, sheet, temper, kind)` come from `MapScript.CAST`.
    - For place conversations, the men's `station` is set to the place.
    - The combat, grief and missing ones are tried with the `states` the requirement names set true.
    - The failing ids are listed.
  - T35 volumes: at-ease ≥ 20, gathering ≥ 15, unease ≥ 5, fear and grief ≥ 7, solo ≥ 90, combat ≥ 22. Counted by file.
  - T36 voice rules: no line over 16 words, and no word from `["okay","ok","guys","yeah","cool","dude","gonna","wanna","kids","awesome"]` (whole words, any case).
  - T37: every cast man is named (`name(X)`) or tied into at least 2 at-ease or gathering conversations.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh talk_test`. Expected: T35 and T37 FAIL (volumes).
- [ ] **Step 3: Write the lines.** Follow spec §10's voice and the samples' register. Keep lore light (the Moon-Glass, Hollin's emeralds, the Drowned Lantern, the Undertown, Lower and High Town, the Steps Gate).
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh talk_test` (T1–T37 PASS), then `run_suites.sh`.
- [ ] **Step 5: Commit.** `git commit -m "feat(talk): the night's writing: conversations, remarks, call-outs and grief for every man"`

---

### Task 15: Atmosphere

**Files:**
- Create: `scripts/Visual/Atmosphere.gd`
- Modify: `scripts/Visual/Torch.gd`: `func lean(v: Vector3)` tips the flame mesh up to 0.35 rad toward `v`.
- Modify: `scripts/Combat/Fire.gd`: `signal fed`.
- Modify: `scripts/AISystem/GuardRig.gd`. At a `chop` activity, on each `TreeChopping` loop crossing 0.55 s, call `Atmosphere.chips_at(guard, weapon tip)`.
- Test: `tests/aliveness_test.gd` (A16–A20)

**Interfaces:**
- Consumes: `GuardVoice.out_breath/heart` (Task 6), `Fire.fuel/fed` (Task 8), `SoundBus.add_listener` and the `hear_sound(event)` shape (existing).
- Produces:
  - `extends Node3D`, joins group `atmosphere`. `static func of(node: Node) -> Node`: the first in the group, or null.
  - `static func chips_at(context: Node, at: Vector3) -> void`: a no-op without an atmosphere.
  - `var quality := 2`: 2 is everything; 1 has no moths; 0 has no moths and no leaves.
  - `func force_wind(v: Variant) -> void`: a test setter (`null` releases it).
  - `func wind() -> Vector3`: a gust vector. Its strength is 0..1, from a `FastNoiseLite` over time (gusts every 6–15 s); its direction drifts slowly from the north-west.
  - **Breath.** Per guard, a `CPUParticles3D` attached to the Head bone (`man.attach(&"Head", …)`, 0.12 m in front of the mouth).
    - `emitting = voice.out_breath() and not dead`.
    - `amount_ratio = lerpf(0.25, 1.0, (heart - 60) / 110)`, × 1.5 while his `last_delivery == &"shout"` in a line.
    - Particles are pale, fade in 0.8 s, and drift with `wind()`.
  - **Embers.** Per `fires` node, a `CPUParticles3D` whose `amount_ratio = fuel`, velocity up plus `wind() × 1.5`. A second one-shot emitter bursts on `fed`.
  - **Moths.** For each `Torch` in the level (found by script), 3 small unshaded quads circling on noise paths at 0.3–0.7 m (not at quality < 2).
  - **Leaves.** One `CPUParticles3D` over the yard's bounds (meta `yard_size` on the level, else 40 × 30), `amount_ratio = wind strength` (not at quality 0).
  - **Chips.** A pooled one-shot `CPUParticles3D` burst at `at`, 8 particles.
  - **Crows.**
    - `func add_crows(points: Array[Vector3]) -> void`: small black meshes. `func crows() -> Array` of `{"node", "state": &"perched"|&"flying"|&"returning", "home"}`.
    - A crow takes off when an event `db ≥ 55` lands within 10 m, or a guard moving faster than 3.5 m/s comes within 5 m. It flies up and away for 4 s, then returns after 25–40 s.
    - The atmosphere is itself a SoundBus listener (`hear_sound(event)`).
  - Every torch leans with `wind()` each frame.

- [ ] **Step 1: Write the failing tests A16–A20.**
  - A16: one man with an atmosphere in the yard. Over 120 frames, the breath emitter's `emitting` equals `_voice.out_breath()` on ≥ 90% of frames. `amount_ratio` at a held heart of 150 is > at 72.
  - A17: a brazier. The ember `amount_ratio` at fuel 0.2 is < at 1.0; `feed()` sets the burst emitter emitting within 2 frames.
  - A18: crows at a point. `SoundBus.emit_sound` 70 dB, 6 m off, has the crow `flying` within 12 frames and `perched` again within 2700 frames.
  - A19: with the wind forced (`force_wind(Vector3(1,0,0))`), a torch's flame rotation is non-zero, tipping toward +X.
  - A20: `quality = 1` hides every moth; `quality = 0` also stops the leaves.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh aliveness_test`. Expected: A16–A20 FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh aliveness_test` (A1–A20 PASS), then `run_suites.sh`.
- [ ] **Step 5: Commit.** `git commit -m "feat(atmosphere): breath, embers, moths, wind and leaves, chips, crows"`

---

### Task 16: The showcase: Act I rebuilt, the cast sheet in, grief after the murder

**Files:**
- Modify: `maps/npc_showcase.gd`.
  - **The rota:** `NightRota.setup(self, 90.0, &"early")` with `post_turn = 75.0`. The duties:
    - `postern` (post at `marks.postern_post`);
    - `yard_round` and `wall_round` (the routes);
    - `bench` (a new sit station `sit_bench` on the south bench);
    - `bed_tam` (sleep_tam);
    - `stations_*` (each stationed man's own).
  - **The cast changes:** Hendrik starts on `postern`, Jory on `bench`. Their `CAST` role texts and the header change to match.
  - **Places:**
    - a `dice` place: a crate at (1.6, 0, 3.6) with 3 squat spots;
    - a `story` place at the fire: 4 spots on a 1.9 m ring, the teller facing north;
    - a `woodpiles` marker at (-13.8, 0, 11.2).
  - **The fire** starts at fuel 0.45 with `fuel_seconds = 120`.
  - **Atmosphere:** added, with crows at 5 points along the wall-walk.
  - `TalkDirector.of(self)` is warmed in `_ready`, so `TalkScript.library()` loads before the night.
- Modify: `scripts/Showcase/ShowNight.gd`.
  - Act I's `enter` sets short talk rests (0–3 s) for all.
  - Act I beats, in order:

    | Beat | Shot | Ends | Timeout |
    |---|---|---|---|
    | `establish` | wide | min 8 | — |
    | `fire_talk` | two, subjects `@talk` | a conversation among Mirelle/Osric/Piers/Col ends (min 10, enough 30) | — |
    | `dice` | `request(&"dice")`; subjects `@gathering:dice` | dice has played a conversation (min 12, enough 40) | 60 |
    | `round` | `request(&"round")`; track Mirelle | 3 visits or enough 40 | 60 |
    | `fire_fed` | close, subjects `@gathering:fire` | fuel > 0.7 | 45 |
    | `story` | `request(&"story")`; subjects `@gathering:story` | the story conversation ends (enough 45) | 70 |
    | `watch_change` | two, Jory and Hendrik | Jory's duty is postern and he is within 1 m of the post | 60 |
    | `wall` | track Wat | min 8 | — |
    | `lookout` | close, Aldous | min 7 | — |

    For `watch_change`, `request(&"watch_change", ["Jory", "Hendrik"])` builds it from a relief want; the Gathering director accepts this form, and the plan pins that.
  - `subjects(shot)` resolves `"@talk"` to the latest live talk's members (falling back to Mirelle, Osric), and `"@gathering:<kind>"` to that gathering's members.
  - Act II: after the murder beat, add a `grief` beat (close on Osric, until `_has_said("Osric", "Jory")`, timeout 45).
- Modify: `scripts/Showcase/ShowOverlay.gd`. `_on_barked` reads `man.last_delivery`: whisper `SAY_SIZE_WHISPER := 12` in italic grey, shout `SAY_SIZE_SHOUT := 17`, else `SAY_SIZE`.
- Modify: `tests/showcase_test.gd`.
  - D1: Hendrik at the postern and Jory at the bench at the start.
  - D4: kept, now with the new Act I.
  - New D30–D32.
- Modify: `tests/visual/stage_showcase.gd`, only if a still misframes a gathering beat; ledger any change.

**Interfaces:**
- Consumes: every earlier task.

- [ ] **Step 1: Write the failing checks.**
  - D30: from Act I's start to Act II's start:
    - `TalkDirector.of(map).played()` has ≥ 8 distinct ids and no duplicates;
    - `Gathering.of(map).history()` has ≥ 3 kinds besides `watch_change`, plus `watch_change` itself;
    - Jory is within 1.2 m of the postern at Act II's start;
    - Act II has started within 300 s of game time.
  - D31: from Act II's start to the end of Act III, Osric barks a line containing "Jory".
  - D32 (Review Focus 4): Act I from the start at `seed(7)` and at `seed(99)` (the map's `_seed()` reads `--seed`; the test sets `MapScript.seed_override`, a new static the map reads first) reaches Act II within 330 s each.
  - D1's new placement.
- [ ] **Step 2: Run it and watch it fail.** Run `check.sh showcase_test`. Expected: D1, D30, D31 and D32 FAIL.
- [ ] **Step 3: Implement the map, ShowNight and overlay changes.**
- [ ] **Step 4: Run it and watch it pass.** Run `check.sh showcase_test` (every D PASS, including D2–D25 unchanged in meaning), then `run_suites.sh` (all green).
- [ ] **Step 5: Look at it.** Run windowed:

```bash
/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot --fixed-fps 60 --resolution 1280x720 --path . res://tests/visual/stage_showcase.tscn -- --out=<workspace>/sheet
```

Expected: `staged N stills` and a `sheet.png`. Look at every Act I still: the gatherings are framed, the subtitles are legible, and a whisper is smaller.

- [ ] **Step 6: Commit.** `git commit -m "feat(showcase): Act I rebuilt as a night that moves; grief after the murder; whispers shown small"`
- [ ] **Step 7: Measure the frame rate** (Review Focus 5). Compare these two:

```bash
/Users/tinkertailorr/Desktop/Godot.app/Contents/MacOS/Godot --path . res://maps/npc_showcase.tscn -- --fps-report=30
```

  - the same command at d1b18b7 (a temporary `git worktree add` of that commit under the workspace);
  - the same command now.

  Ledger both averages and lows. If the average drops by more than 10%, set the showcase's `Atmosphere.quality = 1`, re-measure, and ledger the result. The fix is a failing check only if the drop remains; then treat it as a finding in the final review.

---

### Task 17: The voice recordings (only once the user approves specific files)

**Files:**
- Modify: `tools/prepare_sfx.py`. Add cuts for `murmur` (4–8 takes from the approved walla and murmur sources, 4–10 s each, levelled, trimmed of loud peaks), `murmur_f`, `laugh(_f)`, `sigh(_f)`, `cough`, `spit`, `grunt_effort`, `hm`, `breath_heavy`, `breath_scared`, `yawn`, `snore`, `gasp` and `sob`, each levelled to the `Sfx.GAIN` targets.
- Modify: `CREDITS.md`. Every file's source, author and licence: CC-BY under "Attribution required", CC0 and royalty-free under "Free to use".
- Modify: `scripts/Audio/Sfx.gd`, re-levelling the `GAIN` values by ear against the existing voices.
- Test: `tests/sound_test.gd`, new M-check: `_load_files(&"murmur").size() >= 4` and `_load_files(&"laugh").size() >= 2`, and every approved sound key has ≥ 1 file.

**Gate:** skip this task until the user has said yes to a list of files (file, source, size). If the rest is done first, the final review and the finishing step go ahead without it, and the lines play silently with subtitles. Ledger `Task 17: deferred: awaiting the user's approval of the recordings`.

- [ ] **Step 1: Write the failing check.** Run `check.sh sound_test`. Expected: the new check FAILs (no files).
- [ ] **Step 2: Download the approved files** into `~/Downloads/AUCOD Web SFX/<source>/`, then run `python3 tools/prepare_sfx.py`.
- [ ] **Step 3: Run it and watch it pass.** Run `check.sh sound_test` (PASS), then `run_suites.sh` (all green). Then listen to one Act I windowed and ledger the level changes.
- [ ] **Step 4: Commit.** `git commit -m "feat(sound): the guards' murmur, emotes and breathing from approved recordings"`
