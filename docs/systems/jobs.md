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
