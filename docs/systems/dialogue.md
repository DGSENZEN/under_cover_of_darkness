# Talk: characters, their words and their quests

Some people in the city can be talked to: shades, figures of smoke and light in their own colour ([Shade](../../scripts/Interaction/Shade.gd)). `E` on one opens the painted talk box ([TalkBox](../../scripts/UI/TalkBox.gd)): their lines told out a few letters at a time, then the player's options. What they say, what they give and take, the side goals they set and what they remember are all written in plain text files in `data/dialogue/`, read by [DialogueBook](../../scripts/Level/DialogueBook.gd) and played by [Conversation](../../scripts/Interaction/Conversation.gd); what people remember is kept by [PeopleState](../../scripts/Level/PeopleState.gd) on the `CityState` autoload, **for good**. A sibling of the job's letter ([jobs.md](jobs.md)), in the same manner. Design: `docs/superpowers/specs/2026-10-23-talk-and-quests-design.md`.

## The files

- `data/dialogue/<character>.dialogue`: one character, the beats of their conversations, and the items, goals and notes their talk gives. Now: `curandera.dialogue` and `librarian.dialogue`.
- `data/dialogue/types/<type>.dialogue`: a kind of person (a trade), the beats every person of that kind offers. Now: `types/curandera.dialogue` and `types/bookseller.dialogue`.

(`data/talk/*.talk` are the guards' overheard conversations, a different format: [jobs.md](jobs.md), "Writing the words".)

## The format

```
# A comment: a line starting with #.

== character curandera                 one per file: who this is
name: Curandera                        the name; the speaker of her lines
type: curandera                        her trade (types/curandera.dialogue)
body: duelist                          the wardrobe body her shade wears
colour: copal                          her shade's colour: copal, ink, marigold, cochineal, teal, or hex (#e63833)
voice: female                          male, male_b or female

== beat open_first                     a beat: one moment of a conversation
when: not(met)                         (openers only) played when this holds
intent: she reads him before he speaks for the writer; never shown in the game
Curandera [flare]: <<She reads you.>>  a spoken line: the speaker, its cues, the words
Sense obsidian: <<The obsidian...>>    an inner voice, in its school's look
[pause 1.2]                            a held silence (s)
> <<Ask what she wants.>> -> asks      an option, and the beat it leads to
> <<Leave.>> -> end                    -> end closes the conversation

== beat asks
do: set(asked_book), goal(bring_book)  effects, run as the beat begins
Curandera: <<Bring me the book.>>
> <<Say you will.>> -> end
```

| Kind | Keys | What it is |
| --- | --- | --- |
| `character` | `name`, `type`, `colour`, `body`, `voice`, `intent` | Who the file is (one per file). `colour` is a swatch, `copal`, `ink`, `marigold`, `cochineal` or `teal`, or hex like `#c8a040`. A type file holds its defaults (`colour`, `voice`, `body`) as `== character <type>`. |
| `beat` | `when`, `do`, `intent`, then its body | One moment of a conversation. A beat whose id starts with `open` is an **opener**: on `E` the first opener, in file order, whose `when:` holds is played. Every character needs one opener with no `when:` (played when no other holds). |
| `item` | `name`, `look`, `intent` | A thing given or taken: `name` is shown on the belt, `look` its mesh (`book`, `bundle`). |
| `goal` | `kind` (main or side), `shows`, `done` (required), `note`, `intent`, `text` | A line on the letter, exactly as the job's: shown when `shows:` holds (or by the `goal()` effect), struck through when `done:` holds (or by `done()`). |
| `note` | `intent`, `text` | A pencil note on the back of the letter, added by the `note()` effect. |

**A beat's body**, read like a play, in order:

| Line | What it is |
| --- | --- |
| `Name [cue] [cue]: <<words>>` | A spoken line. The name before the colon is shown over it; the cues are optional. |
| `Sense obsidian [if <condition>]: <<words>>` | An inner voice, drawn in its school's ink with that school's faint doubling (see Schools); with an `[if]`, heard only when it holds. |
| `[pause 1.2]` | A held silence, in seconds. |
| `> <<words>> -> beat` | An option. `-> end` closes the conversation. `[if <condition>]` after the `>`: offered only when it holds (left out, never greyed). `{do: <effects>}` at its end: run when picked. |
| `> ! <<words>> -> beat` | A **special** option, drawn red: the player's own uncanny way through. |
| `> !obsidian <<words>> -> beat` | A special option of a **school**: its swipe and words wear that school's look instead of the red (see Schools). |
| `>> <<words>> -> beat` | In a type file's opener: an option every character of the type is offered (see Types). |
| `-> beat` | Alone on a line, after the lines: the beat that follows when there are no options. A beat with neither ends the talk. A beat has options **or** a goto, not both: a goto after its options is never taken (the talk waits on the options), and options after a goto are never offered (it goes on at once). Either is a warning at the goto's line. |

All together: `> [if has(the_book)] ! <<Take it.>> -> end {do: give(the_book), mood(+1)}`.

**The parts go in that order**: `>`, then `[if ...]`, then `!` (or `!obsidian`), then the words, then `-> beat`, then `{do: ...}`. A Sense line is `Sense <school> [if ...]: <<words>>`, its `[if]` before the colon. Out of order, an `[if]`, `{do:` or `->` would land in the words and be shown, its meaning lost (`> ! [if purse>=5] <<Pay.>> -> pay` would always be offered), so the game refuses it: a load error at its file:line, spelling the right order.

### Schools

A special option may name the school of work it is, right after the `!` with no space: `> !obsidian <<Read the glass.>> -> end`. A `Sense <school>:` line names one too. The box then draws it in that school's look, chosen or not, in place of the plain red. A bare `!` stays the plain red. A school not in this list is a load error at its file:line.

| School | Its look in the box |
| --- | --- |
| `obsidian` | A black volcanic-glass swipe with fine fracture lines and a cold glint sliding across it. The words are cold, with a faint second print beside them, like a reflection in the glass. Chosen, the glint comes quicker and a thin cold rim lights the stroke. |
| `copal` | Amber-grey resin smoke drifting through the swipe. |
| `seance` | A pale ghost-light pulsing from the middle. |
| `nahual` | Three claw strokes raked through it. |
| `lumen` | A blue-white arc flickering along it. |
| `relic` | Gilt leaf laid in flakes, a slow sheen over them. |

Obsidian is the finished look; the other five are first looks.

The box shows any number of options. Up to about four sit at the full step. More close up a little, and more than fit scroll with the choice, with a painted fade at the edge that has more beyond it. The wheel stops at the first and the last option. The number keys still pick by the option's place in the list (2 is always the second).

**The words are shown exactly as written.** No quotation marks are added round a spoken line: write “ ” into the text where you want them.

### Cues

A line's cues act for that line, then the shade goes back to its resting state.

| Cue | The shade |
| --- | --- |
| `[flare]` | Its rim and glow rise, the smoke inside quickens. |
| `[dim]` | It fades, thins and cools. |
| `[gutter]` | A candle's flicker. |
| `[calm]` | Its resting look. |
| `[nod]` | A nod of the head. |
| `[shake]` | A shake of the head. |

### Conditions

`when:`, `[if ...]`, `shows:` and `done:` are terms separated by commas, all of which must hold. `not(<term>)` turns any of them round.

| Term | Holds when |
| --- | --- |
| `said(<flag>)` | This character's flag is set (`set()`). Another's: `said(<character>.<flag>)`, as `said(curandera.asked_book)`. |
| `gave(<item>)` | The player gave this character the item (`take()`). Another's: `gave(<character>.<item>)`. |
| `has(<item>)` | The player carries it now. |
| `mood>=n`, `mood<=n` | This character's hidden feeling toward the player. Another's: `mood(<character>)>=n`. |
| `met` | This character has been talked to before (true from the second visit). |
| `purse>=n` | The player has at least n coins. |
| `took(x)`, `arrived(x)`, `done(x)`, `loot>=n` | The job's own (jobs.md). |

`said`, `gave` and `mood` with a character's name work in `.job` files too, so a district goal can wait on talk: `shows: said(curandera.asked_book)`. Every character has the flag `walked_off`, set when the player walks away mid-talk.

### Effects

`do:` on a beat (run as it begins) or `{do: ...}` on an option (run when picked), separated by commas:

| Effect | What it does |
| --- | --- |
| `set(<flag>)`, `clear(<flag>)` | Sets or clears this character's flag. |
| `give(<item>)` | Puts the item on the player's belt. |
| `take(<item>)` | Takes one off the belt, remembered as given to this character (`gave()`); nothing if he has none. Offer it with `[if has(<item>)]`. |
| `pay(n)`, `charge(n)` | Coins to the player; coins from him (nothing if he is short: gate it with `[if purse>=n]`). |
| `goal(<id>)`, `done(<id>)` | Puts a goal on the letter now; marks it done. |
| `note(<id>)` | Adds a pencil note to the back of the letter. |
| `mood(+n)`, `mood(-n)` | Changes this character's feeling toward the player. |
| `shade(flare\|dim\|gutter\|calm)` | Its resting state from now on (a cue lasts one line; this lasts). |

## Types

A type is a trade, written by hand for that trade: a curandera can always do a limpia or sell copal; a bookseller can always be asked for a title or sell a book. A character with `type: curandera` gets:

- every beat of the type file that their own file does not write. **Their own words win**: a beat of the same id in the character's file replaces the type's (the candle lane's curandera writes her own `limpia`; a nameless market curandera gets the type's);
- the type's `>>` options added to each of their own openers, before the options that `-> end`, when their `[if]` holds. An opener of their own with no options that goes on by a goto (`-> menu`) keeps its goto: the type's options join the beat it leads to instead (once, however many openers lead there; none if it leads to `end`);
- the type's `colour`, `voice` and `body` where their file gives none.

**In a type file the speaker is `{name}`**: `{name} [flare]: <<...>>`. It is spoken by whoever is of the type, the character's `name` shown in its place (`{name}` in the words is replaced too). A literal name in a type file would show that name for every one of them.

A nameless person of a type alone needs no file at all: a `Shade` with `type_id` and a `display_name` (the candle lane's market curandera). What they remember is their own, under the id `<type>_<name>`.

## Memory lasts forever

What people remember is never wiped: the flags they set, what they were given, their moods, whom they have met, their goals and the notes their talk added. A new mission (`CityState.begin()`) keeps all of it. Only a talk goal already done leaves the letter then; an open one stays on it until done, across missions. (`PeopleState.save_state()`/`load_state()` is ready for saving to disk.)

So write openers for coming back: a different greeting after a lie (`when: said(lied)`), while the player carries the thing (`when: has(the_book), not(gave(the_book))`), after it is all over (`when: gave(the_book)`).

## The test quest

The curandera and the librarian of the candle lane (`maps/candle_lane.tscn`) carry one small quest, every word still a placeholder:

1. **The curandera** (`open_first`) reads the stranger and asks for a book only the librarian has (`asks`: the side goal `bring_book` on the letter).
2. **The librarian** knows of her (`open_sent`). The truth (`truth`, mood +1), his price (`pay`, 5 coins) or the special option (`special`) gets the book. A lie (`lie`) dims him (mood −1, resting dim) and he refuses; next time he opens on it (`open_after_lie`), and the stranger may make amends (`amends`: calm again, the truth open, and his `open` remembers it after with a sense line).
3. **The curandera again**, the book on him (`open_has_book`): handed over (`gives_bundle`), she takes it, gives a bundle of her copal and he notes what it is for; the goal is struck. Lying that he has none (`lie_no_book`) makes her gutter (mood −1).
4. **After:** she opens on `open_after`, he on `open`.

## Writing the words

A text still in `<<...>>` is a placeholder: the game shows it as written. Each beat's `intent:` says what its words must do. To see what is left to write, run the quest's suite and read its `WORDS:` lines (`<file>:<line> beat <beat>`, `... goal <id>`, `... note <id>`, `... item <id>`):

```
Godot --headless --fixed-fps 60 --path . res://tests/talk_quest_test.tscn | grep WORDS
```

The `name:` and the speaker before each line's colon are working names (`Curandera`, `Librarian`): change both together. The market curandera's name is `MARKET_CURANDERA` in `maps/candle_lane.gd`.

A mistake in a file is reported with its file and line when the game starts (`dialogue: ...` errors and warnings) and by `talk_quest_test` (Q1): an unknown key, kind, cue, effect or term; a `-> beat` that does not exist; an item, goal, note, flag or character named that does not exist; a character with no opener without a `when:`; a `type:` with no type file. An option or Sense line with its parts out of order (see the format). Warnings: a beat no opener reaches, a `take()` offered without `[if has()]`, a beat whose every option has an `[if]`, a beat with both options and a goto, and a lowercase speaker with plain words, which is probably a mistyped key (`wehn: not(met)` is read as a speaker called `wehn`; a speaker's line with a cue or still in `<<...>>` is not warned of).

## How the game uses them

| Piece | What it does |
| --- | --- |
| The shade | [Shade](../../scripts/Interaction/Shade.gd), a `StaticBody3D` (prompt `Talk`): `character` names its file, or `type_id` and `display_name` a nameless one. Its body is the file's `body` in smoke of its `colour` ([talk_shade.gdshader](../../scripts/Visual/talk_shade.gdshader)); it turns to face the player, and its cues and resting state show in its light. |
| The box | `E` on a shade opens [TalkBox](../../scripts/UI/TalkBox.gd) (`PlayerFrob.talk`, only with the hands free). `E` or a click tells a line out at once, the next goes on; options are picked with 1-9 (the number row or the numpad), the mouse (point and click), or the wheel and `E`; holding back walks away (`walked_off`). A blow, a death or leaving the district breaks it off, nothing remembered. The player stands still meanwhile and the HUD gives way. |
| The paintings | A character with paintings (`assets/ui/talk/<id>.json` committed, its pictures in `assets/ui/talk/<id>/` kept out of git) gets their own painted box ([TalkSkin](../../scripts/UI/TalkSkin.gd)): the curandera and the librarian. Anyone else, or a checkout without the pictures, gets the plain one. |
| The belt | `give()` puts the item on the belt with its `name` and its `look`'s mesh; `take()` takes one off. |
| The letter | Talk goals are listed after the job's, side goals under the rule; talk notes on the back after the job's ([LetterText](../../scripts/UI/LetterText.gd)). |
| Memory | `CityState.people` ([PeopleState](../../scripts/Level/PeopleState.gd)): flags, gifts, moods, who was met, talk goals shown and done, notes; untouched by `begin()`. |
| Where they stand | The candle lane (`maps/candle_lane.gd`, `_shades()`): the librarian at his high desk in his shop, the curandera at the far wall's votive ledges east of it, the market curandera a little along the same ledges. |
