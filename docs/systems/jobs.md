# The job: its words, goals and notes

The player's job is held in the hands as a letter (`J`) that fills in as they play: the commission and its goals on the front, struck through when done; the thief's pencil notes on the back, added by what they read and overhear. Every word of it is written in plain text files in `data/jobs/`, read by [JobBook](../../scripts/Level/JobBook.gd); what the player has done is kept by [JobState](../../scripts/Level/JobState.gd) on the `CityState` autoload. Design: `docs/superpowers/specs/2026-10-03-harbour-job-design.md`.

## The files

- `data/jobs/mission.job`: the commission (`== letter`), the city's own goals (the loot goal) and the guards' shouts.
- `data/jobs/<district>.job`, named after its district in `data/districts.json`: that district's goals, the pencil notes, the texts of its readables, and its gates. A district's goals join the letter once the player has arrived there.

## The format

```
# A comment: a line starting with #.

== goal seal                       a block: its kind, then its id (letters, digits, _)
kind: main                         key: value
done: took(the_seal)
intent: what the words must say    for the writer; never shown in the game
text: <<take the seal>>            the words, on one line...

== readable night_orders
note: tower_bell
text:                              ...or `text:` alone, then every line up to the next ==
By order of the harbourmaster,
the lamps on the mole stay lit.
```

| Kind | Keys | What it is |
| --- | --- | --- |
| `letter` | `intent`, `text` | The commission (mission.job only, one). |
| `goal` | `kind` (main or side), `shows`, `done` (required), `note`, `intent`, `text` | A line on the letter. Without `shows:` it is there from the start (once its district is reached); with it, it appears when that holds, and its `note:` is added then. Struck through once `done:` holds. |
| `note` | `intent`, `text` | A pencil note on the back of the letter. |
| `readable` | `note`, `intent`, `text` | The words on a notice, paper or ledger in the level (its `readable` marker names this id as its `slot`). Reading it adds its `note:`. |
| `gate` | `exits`, `needs`, `intent`, `text` | Exits (marker names, or `to(<district>)` for every exit leading there) that turn the player back until the `needs:` goal is done; `text` is the thought shown when turned back. |
| `shout` | `intent`, `text` | A guard's shout (`theft`: finding a robbed chest). |

**Conditions** (`shows:`, `done:`): terms separated by commas, all of which must hold: `took(<loot marker>)`, `arrived(<district>)`, `done(<goal>)`, `loot>=<value>` (the value of everything taken, city-wide), `not(<term>)`.

## Writing the words

A text still in `<<...>>` is a placeholder: the game shows it as written. To see what is left to write, run the job's suite and read its `WORDS:` lines:

```
Godot --headless --fixed-fps 60 --path . res://tests/job_test.tscn | grep WORDS
```

The harbour's conversations (`data/talk/harbour.talk`) are written the same way: each line a `<<placeholder>>` under a `# intent:` comment. A line carrying `[note:<id>]` adds that pencil note when the player overhears it (in 22 m, nothing solid between).

A mistake in a file (an unknown key, a note that does not exist, a broken condition) is reported with its file and line when the game starts and by `job_test`.

## How the game uses them

| Piece | What it does |
| --- | --- |
| The letter | `J` raises it (`PlayerFrob.open_letter`), `J` or `E` lowers it, a click turns the sheet. A fresh mission opens with it up (`DistrictMap.open_with_letter`; tests turn it off). It goes down for a run, a jump, a climb, a swim, a carry, a blow struck or taken; the HUD hides the crosshair and lifts its prompts above it. Drawn by [HeldPage](../../scripts/Interaction/HeldPage.gd) (its words a SubViewport, lit by the world but never darker than `LIGHT_FLOOR`) from [LetterText](../../scripts/UI/LetterText.gd). |
| Readables | `readable` markers (docs/systems/world.md) become [Readable](../../scripts/Interaction/Readable.gd)s: `E` holds the page up, walking 2 m off or `E` puts it down. Reading one adds its note. |
| Notes from talk | A talk line's `[note:<id>]` is learnt when the player hears it ([Earshot](../../scripts/AISystem/Talk/Earshot.gd): 22 m, nothing solid between; subtitles use the same rule). A conversation's `where:` keeps it to the garrison or a district. |
| Hails | A district map's `_hails()` pairs (`maps/city.gd`) call each other when their rounds bring them near (`TalkDirector.call_pair(&"hail", ...)`); their conversations say `when: situation:hail`. |
| The gate | An exit whose gate is not met turns the player back with the gate's text, once per 4 s (`DistrictMap._exit_reached`). |
| The seal | Taking something `special` turns it in the hand (`HandSlot` "special" job, cut short by a run, a jump or a blow); a main goal done plays `sting_goal`, a note the pencil and "Noted". |
| The theft | A chest left open is noticed (`GuardLife`, CHEST_RANGE 12 m); robbed of its special, the finder shouts the job's `== shout theft`, the alarm goes full and the man nearest the nearest bell rings it, once per district (`JobState.notice_theft`). |
| The tally | [Tally](../../scripts/Level/Tally.gd) counts knockouts, kills, bodies found, times seen (one per 10 s), bells and time; loot and specials are counted where taken. Shown on the loading screen on the way into the next district, waiting for `[E] Go on` (`LoadingScreen.holds`; tests turn it off). |
| Memory | `CityState.job` ([JobState](../../scripts/Level/JobState.gd)): goals shown and done, notes, readables read, what was taken, districts reached, each district's facts and tally; `save_state`/`load_state` for saving to disk. |
