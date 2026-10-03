# The harbour's job: a goal, words in the world, and the way on (Oct 3 2026)

**Status:** design approved in conversation (Oct 3 2026), awaiting the user's review of this file.
**Branch:** `harbour-job` (worktree `.claude/worktrees/harbour-job`) from main c99b516.
**Program:** the city on the rock (`2026-09-28-city-on-the-rock-design.md`). This pulls the part of
program step 6 (mission systems) that the harbour needs forward, built general so every later
district reuses it.

## 1. Goal

The user (Oct 3 2026):

> I feel like the harbor lacks a few more things, it's supposed to be an implicit tutorial, it's
> where the player learns how stealth work, how sounds works, how the blackjack and their tools
> work ... but I feel like it is lacking *something* gameplay wise still.

Asked which gap it was, the user chose **words in the world** and **a goal with payoff**, and
added: *"There should be something that drives the player towards moving to the next district.
When you take the seal for example, you're now able to progress to old city."* Staged lessons
and teachable floor sounds were not chosen and are out of scope (section 10).

**Success:** a new player lands in the rowboat, learns from the world what they are there for
and roughly where it is, takes the seal, and feels the harbour hand them on to the old town;
a careless theft turns the harbour against them on the way out, a careful one does not; the
harbour's tally greets them on the way up.

## 2. Decisions (the user's, Oct 3 2026)

| Question | Decision |
|---|---|
| What is missing | Words in the world; a goal with payoff; a drive towards the next district |
| How the seal opens the way | **The job sends you on**: all four ways up stay as they are, but each turns you back without the seal (a short thought); with it, all four lead on |
| How the job is shown | **A letter that fills in**: the commission held in both hands; what you overhear and read is added as the thief's pencil notes; done goals struck through |
| Who writes the words | **The user writes, Claude builds**: every piece of writing is a slot with an intent and a placeholder; Claude writes none of the lore |
| Payoff | All four: the moment itself (hand + sting + note), the theft noticed, the harbour's tally, side goals on the letter |
| Approach | **A general mission layer, filled for the harbour first**; the old town reuses it |

**Words that are Claude's** (UI, like the existing prompts): key prompts (`[J] Put away`,
`[E] Read`, `[E] Go on`), the "Noted" caption, the tally's labels. **Words that are the
user's:** the commission, goals, pencil notes, readables, the refusal thought, the harbour's
conversations.

## 3. The job files

Two plain text files in a format like `data/talk/*.talk` (`#` comments, `== kind id` headers,
`key: value` lines, a free `text:` block running to the next header):

- `data/jobs/mission.job`: the commission's body (the whole mission's) and the city-wide loot goal.
- `data/jobs/<district>.job`: that district's goals, notes, readables and gate. This plan writes
  `harbour.job` in full (placeholders) and an empty `old_town.job`.

```
# data/jobs/harbour.job
== goal seal
kind: main
done: took(the_seal)
intent: The job itself: the harbourmaster's seal, in his office in the customs house.
text: <<take the seal>>

== goal up
kind: main
shows: done(seal)
done: arrived(old_town)
note: way_up
intent: Bring the seal up to the old town.
text: <<the onward goal>>

== goal captains_ring
kind: side
done: took(captains_ring)
intent: A special: the captain's ring, in the carrack's cabin strongbox.
text: <<the captain's ring>>

== note office_key
intent: The office key is kept on the customs house's ground floor.
text: <<pencil: the office key>>

== readable night_orders
note: tower_bell
intent: The harbour's night orders: the tower lookout rings the bell at anything amiss; lamps stay lit and are relit.
text:
<<the night orders, as many lines as you like>>

== gate old_town
exits: to(old_town)
needs: seal
intent: The thief's thought when a way up turns them back without the seal.
text: <<turned back>>
```

- **Kinds:** `goal` (`kind: main|side`, optional `shows:` condition, `done:` condition,
  optional `note:` added when it shows), `note`, `readable` (optional `note:` added on reading),
  `gate` (`exits:` by marker name or `to(<district>)`, `needs:` a goal id).
- **Conditions** (small and closed): `took(<loot marker>)`, `arrived(<district>)`,
  `done(<goal>)`, `loot>=<value>` (city-wide value taken), `not(...)`.
- **Placeholders:** any `text` wrapped in `<<...>>`. The game runs on them (shown as written);
  a check lists what is left to write (section 9).
- **Errors:** the parser reports file and line, as the talk parser does; an unknown id in a
  condition, gate or note reference is an error.
- A later district adds its own `.job`; its goals join the same letter, under the district's
  name.

## 4. The letter in the hands

- **`J`** (new action `letter`) raises the letter in both hands; `J` again lowers it.
- **The mission opens with it raised**: in the rowboat, reading the commission, with the prompt
  `[J] Put away`, so the key is taught by use.
- **Front:** the commission, then the goals in ink; done goals get an ink stroke through them;
  side goals under a rule. **Back:** pencil notes in a greyer, rougher hand, newest at the
  bottom. A click turns the sheet; notes that overflow go on to a second sheet in the cycle.
- **The world keeps running** while you read (no pause). Sprinting, jumping, climbing, hanging,
  swimming, fighting or carrying lowers it. Walking and crouch-walking keep it up.
- **New note:** a short pencil-scratch sound and the caption "Noted".
- **Readable in the dark:** the page is lit by the world but never below a floor, so it reads
  anywhere while still tinted by the lamp or moon you stand in.
- **Build:** a third off-hand mode in `HandSlot` beside the purse and key ring, as a shared
  **held page** (both hands' IK targets on the sheet's edges; a paper mesh of ours with a
  painted paper texture from `paint.py`; text as `Label3D` on the viewmodel layer; ink strokes as
  thin quads). The same held page serves every readable (section 5). Follow
  `fp-animation-principles`: the raise leads with the head's glance down, eases in, never
  steals control.

## 5. Words in the world

### 5.1 Readables

- **New marker `readable`** (`tools/level/markers.py` schema; built in `LevelGameplay`):
  `slot` (an id in the district's `.job`), `kind`:
  - `notice`: pinned to a wall or post; read where it hangs.
  - `paper`: loose on a desk or floor; picked up, put back where it lay when lowered.
  - `ledger`: an open book on a desk; read where it lies.
- Meshes are ours (kit pieces). Prompt `[E] Read`. The held page (section 4) shows the slot's
  text; `E`, `J` or walking 2 m away lowers it. Reading adds the slot's `note:` and marks it read
  (remembered by `CityState`).

### 5.2 Overheard talk

- **`where:`** a new conversation key (`garrison`, `harbour`, ...; absent = anywhere). The
  existing conversations that name garrison things (the captain, Brand, the yard, the chapel,
  the Moon-Glass: about 66 mentions over `data/talk/*.talk`) get `where: garrison`; the list is
  given to the user to review before it is merged. The director takes the district's id from
  the map.
- **New conditions** in `TalkFacts`: `done(<goal>)` and `theft_noticed`.
- **Notes from talk:** a line may carry `[note:<id>]` among its emotes. If the player overheard
  that line, the note goes on the letter. The director passes the conversation and line to the
  HUD with the bark (it does not today).
- **One rule for overhearing:** a line is overheard when the guard is within the subtitle range
  (22 m) **and** a ray from his head to the player's head is not blocked by the world (closed
  doors block; open ones do not). The subtitle and the note use the same test, so a shown line is
  a learnt line, and subtitles stop reaching through walls.
- **New file `data/talk/harbour.talk`:** the harbour's conversations with cast, conditions and
  `where: harbour` set by Claude; every line a `<<placeholder>>` with a `# intent:` comment.

### 5.3 The landmark fix

`LevelLoader` puts landmark markers in group `landmark` with meta `label`; `Comms` and
`TalkFacts` read group `landmarks` with meta `landmark`. One name for both (the readers'),
so the harbour's guards name places in shouts and talk ("by the golden tower"). The alarm bell
built by `LevelGameplay.bells` takes its marker's name (`tower_bell`) too.

### 5.4 The harbour's slots

Each key hint has two sources, one read and one overheard, where the place allows.

| Hint (note id) | Readable: slot, kind, where | Overheard: who, where |
|---|---|---|
| The tower lookout has a bell (`tower_bell`) | `night_orders`, notice, by the golden tower's door on the mole: the first thing near the start | Fernao calling up to Gaspar from the tower's foot |
| The office key is on the customs ground floor (`office_key`) | `duty_orders`, paper, the watchman's desk on the ground floor | Baltasar and a quay lantern man at the customs door |
| The arcade's dark bays; lamps get relit (`dark_bays`) | (none) | Duarte and Inigo where their rounds cross |
| The ways up: Sea Gate shut and watched; the Guindais stair, the wall-walk (`ways_up`) | `curfew`, notice, in the Terreiro arcade | Rodrigo and Tome at the Sea Gate |
| The cabin key left on the quay; the strongbox (`cabin_key`) | `captains_log`, ledger, the carrack's cabin | Leonor and a quay man at the carrack's gangway |
| The blowhole covers sound (`blowhole`) | `smugglers_scrawl`, paper, the cave beach | (none) |
| Something behind the fort's powder room (`powder_room`) | `fort_note`, paper, the fort | (none) |
| Why the seal matters; what lies up the hill (`way_up`, also the onward goal's note) | `harbourmasters_letter`, paper, the office desk | (none) |
| After the theft (no note) | (none) | 2-3 reactive conversations on `theft_noticed` |

- **Meetings:** rounds are adjusted so each pair actually meets where its talk belongs: the
  quay pair passes the customs door as Baltasar's round reaches it; the mole round ends at the
  tower's foot under the lookout; a quay man's round touches the carrack's gangway.
- **Side goals:** the harbour's specials. Today only the seal is marked special; the captain's
  ring (cabin strongbox) and the fort's signet (powder room) are marked special too, and become
  side goals. The city-wide loot goal sits in `mission.job`.

## 6. The gate, the seal, the theft noticed

### 6.1 The gate

- `DistrictMap._exit_reached` asks the job whether the exit's gate is met before
  `mission.travel`. If not: the gate's text as a caption (`StealthHUD.show_caption`), at most
  once per entry, 4 s cooldown; no travel.
- With the seal, all four ways up (Sea Gate, wall-walk, Guindais upper gate, west wall) lead on
  as today. The river and cave exits keep "On to ..." (unbuilt districts). The old town's ways
  back down have no gate.
- Arriving in the old town does `arrived(old_town)`, striking the onward goal.

### 6.2 The seal moment

- On taking the seal: the off hand brings it up and turns it in the light (~1.2 s, a new
  `HandSlot` job beside `receive`), then stows it. Sprinting, jumping or an attack cuts it short.
- A new sting `sting_goal`, cut from the user's TomMusic pack by `tools/prepare_sfx.py` (no
  procedural audio), in `Sfx.MUSICAL` and `GAIN`, respecting `Music.STING_GAP`; approved by ear.
- *Take the seal* struck; *bring it up* shows; its note `way_up` added (scratch + "Noted").
- **Side-goal specials** (the ring, the signet): the same turn in the hand, no sting; scratch,
  "Noted", their line struck.

### 6.3 The theft noticed

- **A new oddity: a chest left open.** `Chest.left_open()` (open, and last opened by the
  player), beside `Door.left_open()` and `Torch.left_out()` in `GuardLife._look_for_oddities`.
  A guard who sees one goes to shut it (`deal_with_oddity`) and raises the alarm a little, as
  for a door (0.2).
- **A robbed chest:** a chest knows the specials that lay inside it when the level was built
  (loot inside its interior box). If one is gone when a guard notices the open chest, it is a
  theft: he shouts (naming the place), the alarm goes to 1.0, `theft_noticed` is set (a
  district fact kept by the district's memory), the tower lookout rings the bell, and the
  guards hunt outward from the customs house.
- **Baltasar's round** climbs to the office landing (the office is upstairs, `CUSTOMS_UPPER`)
  and waits there 2 s facing the office door, as the original harbour plan meant. An office door
  left open is an oddity he already notices; going in to shut it, he sees the strongbox open.
- **The careful thief** shuts the strongbox and the office door and is not found out. The
  careless one leaves through an alarmed harbour. The way up stays open either way.

## 7. The tally

- `CityState` counts per district, adding up over visits:
  - loot taken, of the district's total value (from its loot markers);
  - specials taken, of total;
  - readables read, of total;
  - knockouts and kills;
  - bodies found by guards;
  - **times seen**: a guard reaching full alert on the player, with a 10 s window so a group
    spotting you at once counts once;
  - alarms (bells rung, the theft);
  - time in the district, in real time, not counting pause or loading.
- **Shown when you go through a way out:** the loading screen keeps its title (the user's
  words) and shows the leaving district's tally under the bar in the HUD's serif; once the next
  district is ready it waits for `[E] Go on`, then fades in. Not shown at the mission's start.

## 8. Memory

- `CityState` gains a `job` record: goals done, notes known (in order), readables read, the
  tally per district; it saves and loads with the rest of its state and is cleared by `begin()`.
- `theft_noticed` and the chests' open/locked state ride the district's memory
  (`DistrictState`, chests already save `{open, locked}`).
- Saving to disk stays the program's own later step; this rides the in-mission memory as the
  purse and keys do.

## 9. Testing

- **`job_test` (new suite):** the `.job` parser (good files, errors with lines), conditions,
  `shows:`, the gate check, note order, the `CityState` round trip, the tally driven by real
  knockouts, sightings, loot and time.
- **Interaction suite:** `J` raises and lowers; sprint, climb, swim and carry lower it; a
  readable adds its note once; a paper goes back where it lay; the page is readable in the dark
  (its light floor).
- **Talk:** `where:` filtering by district; `done()` and `theft_noticed`; a `[note:]` line
  heard in range and not through a wall; the landmark fix (a harbour guard's shout names the
  golden tower).
- **Guards:** an open chest is noticed and shut (alarm 0.2); an open, robbed seal chest gives
  alarm 1.0, `theft_noticed` and the bell; a closed robbed chest goes unnoticed; Baltasar's round
  reaches the office landing.
- **`city_test`:** each way up refuses without the seal and travels with it; every `readable`
  marker's slot exists; every note id resolves; each pair in the slot table meets on its rounds;
  the three specials exist.
- **Python layout rule** (`tools/level/rules.py`): a `readable` marker must name a slot in its
  district's `.job`.
- **Placeholders:** a check prints the slots still in `<<...>>` (does not fail), so the user
  sees what is left to write.
- All 56 suites (1377 checks) stay green; the harbour is re-exported and its navmesh rebaked
  after the marker changes (`level.sh navmesh harbour`).

## 10. Out of scope

Staged lessons (a lone guard placed for a first knockout, a lamp to douse to pass, a bottle to
throw); teachable floor sounds (gravel, metal grates, rugs, glass, and loudness for gravel and
dirt); secrets as a system; the mission's final end screen and ending; saving to disk; the old
town's own goals (its night plan, B1b).

## 11. Risks and open points

- **Overhearing's ray** runs once per line per listener, which is cheap. The HUD's subtitles
  change with it (no more lines through walls); that is intended.
- **Garrison talk tagging** is a judgement per conversation; the user reviews the list.
- **Baltasar on the stair** needs the customs house's stair on the navmesh to the office landing;
  the plan checks it before relying on it.
- **The robbed-chest test** depends on which loot lies inside a chest at build time; the seal
  sits in the strongbox's box today (`markers.py` 167/172) and the captain's ring in the cabin
  strongbox's (168/180); the signet lies loose in the fort (184), so taking it is never a
  robbed chest.
- **The sting** waits on the user's ear; until approved, the goal plays an existing sting.
