# Talk and quests: the design

Settled with the user on 2026-10-23. This is project 5 of the demo program (`2026-10-16-mexico-city-demo-program.md`, "Talking"), brought forward by the user ahead of powers and combat. Lines marked *(Claude's call)* are Claude's proposals; the rest is the user's.

## Intent

We are building the game's conversation and quest layer: walk up to someone, talk, and leave with a mission, an item, or a changed relationship. Two placeholder characters prove it out: **the curandera** and **the librarian**. They are drawn as Deadlock-style shades over the existing swordmaster bodies.

**Dialogue and missions must genuinely feel handcrafted.** Every conversation is written by hand as a branching script. Nothing is stitched together from generic parts, and nothing is radiant or procedural.

## Goals

- **Quests are given in talk.** A choice can put a goal on the letter (the existing JobBook/JobState/LetterText spine) and later mark it done.
- **Items are given and taken in talk.** A character can hand the player something, and can ask for something the player carries.
- **What you say causes reactions.** The next lines depend on what you chose. Reactions are carried by **the words and the shade's light**: it flares, dims or gutters. The user said reactions come from dialogue plus the shade flaring or dimming, because animations are limited.
- **Characters remember.** What was said, what was given, and how they feel about you all shape the next visit and can gate options. *(Claude's call, accepted.)*
- **The dialogue box is mockup "A"** from 2026-10-16 (`.superpowers/brainstorm/69653-1792176203/content/dialogue-directions.html`): a portrait cut-in, a dark text box with a cochineal-red edge, the name on a black tag in marigold, and options as bold marigold tags, with cochineal red for special options. Per the program, it follows Persona 5's direction but is not literally as big and slanted.
- **The user writes every word.** Claude builds the systems and both characters with `<<placeholder>>` lines, in a format the user edits by hand.

## Non-goals (this project)

- Saving to disk, a world clock, and civilians with routines. These stay later items of program project 5 and project 7. The talk state has its own `save_state`/`load_state`, ready for when disk saving exists.
- Placing the characters in their real homes: the librarian's shop on `metro-standard`, and the curandera in the Zócalo's market. They live in a gym for now.
- Painted portraits. They are the user's to source later (see "Ask for textures and designs"). The placeholder portrait is described below.
- New body animations. Existing clips only.
- Real powers. The magic plan (`revolver-magic`) is unbuilt, so the Disco-style "sense" interjections are gated by plain flags for now.

## Anti-goals (a failure even if it works)

- **Generic RPG talk:** an "Ask about…" hub that empties as you exhaust topics, shop menus, or exposition walls.
- **Visible meters:** approval bars, "+1 respect" popups, or option labels that tell you the outcome.
- **Quest markers** of any kind. Goals appear only as lines in the letter.
- **A box that floats outside the world.** The world keeps running behind it.
- **Shades that read as a cheap transparency toggle on a guard,** or that look like the "hideous" humanoids the user rejected on Oct 17. The shade has to make these bodies read as deliberate spirits.

## Approaches considered

| | Approach | Trade-off |
|---|---|---|
| **A (picked by the user)** | **Our own script format in the job files' style:** `data/dialogue/*.dialogue`, parsed in GDScript, with goals and conditions shared with JobBook | The most to build (a parser, a runner, tests). In return there is one writing format across letter, goals and talk, one spine for quests, and full control over shade cues and inner voices. |
| B | The Dialogue Manager plugin | The fastest basic branching. But it adds a second writing language, needs glue to JobState and Inventory, its box gets replaced anyway, and later odd features get bent around it. |
| C | Node graphs in the Godot editor | Visual structure, but slow to write prose in and hard to review in diffs. |

The user picked A: "our own script format".

## The pieces

### 1. The `.dialogue` format (DialogueBook)

*(Claude's call)* `data/talk/` and `.talk` already belong to the guards' overheard conversations (TalkScript and TalkDirector, `tests/talk_test.gd`). Character dialogue is kept apart, so neither format breaks the other. Unifying the two is out of scope.

One file per character: `data/dialogue/<character>.dialogue`. It is read by a new `DialogueBook.gd` and follows the conventions of `JobBook.gd`: `== <kind> <id>` blocks, `key: value` lines, `#` comments, `<<...>>` placeholders, `intent:` for the writer (never shown), and every error reported as `file:line`. The writer's guide is `docs/systems/dialogue.md`, a sibling of `docs/systems/jobs.md`.

The block kinds:

- **`== character <id>`** (one per file): `name`, `type` (the kind of NPC, see "NPC types" below), `colour` (the shade's colour, a named swatch or hex), `body` (a wardrobe kind), `voice` (`male`, `male_b` or `female`), and `intent`.
- **`== beat <id>`**: one moment of a conversation, the core unit.
  - `when:` is a condition. It is used only on **openers**, beats whose id starts with `open`. On frob, the first opener in file order whose `when:` holds is played. This is how a character greets you differently on the first visit, after a lie, or while you carry the book.
  - `do:` lists effects run when the beat starts.
  - The beat's body is lines like a play, in order:
    - `Amparo [dim]: <<Stand still, joven.>>` is a spoken line. The speaker's name is followed by optional cues in brackets.
    - `[pause 1.2]` is a held silence.
    - `Sense obsidian: <<The copal bends toward your shoulder.>>` is an inner-voice interjection. It shows in the box in cochineal red, Disco-style, and can carry its own `[if <condition>]`.
    - `> <<Who is behind me?>> -> behind` is an option. Its forms:
      - `> [if <condition>] <<…>> -> beat` is shown only when the condition holds.
      - `> ! <<…>> -> beat` is a special option, drawn red.
      - `> <<…>> -> beat {do: give(the_book), mood(+1)}` runs effects when picked.
      - `-> end` closes the conversation.
    - A beat with no options carries on to the next beat named by `-> <beat>` alone on a line, or ends.
- **`== item <id>`**: a thing given or asked for, with `name`, `look` (a Props mesh kind; see below), and `intent`.
- **`== goal <id>`**: exactly JobBook's goal block, written here so a character's quests live with them. A goal given by talk carries `shows: said(<flag>)` or is shown by the `goal()` effect, and still needs its own `done:` condition. The `done()` effect is an extra way to finish it. These are **talk goals**: they're kept by PeopleState (section 2) and listed city-wide, outliving any one mission.
- **`== note <id>`**: a pencil note, the same as JobBook's. Talk can add notes to the back of the letter.

**Conditions** extend JobBook's terms (`took`, `arrived`, `done`, `loot>=`, `not`) with:

- `said(<flag>)`: the flag is per-character in its own file. Name another character's flag as `said(<character>.<flag>)`.
- `has(<item>)`: the player carries it now.
- `gave(<item>)`: the player gave it to this character. Name another character's as `gave(<character>.<item>)`.
- `mood>=n` and `mood<=n`: this character's hidden feeling toward you. Name another's as `mood(<character>)>=n`.
- `purse>=n`.
- `met`: this character has been talked to before.

These terms also work in `.job` files, so a district goal can show on `said(curandera.asked_book)`.

**Effects** (`do:`):

- `set(<flag>)` and `clear(<flag>)`
- `give(<item>)`: to the player. `take(<item>)`: from the player, recorded as `gave`.
- `pay(n)` and `charge(n)` move money through the purse.
- `goal(<id>)` puts the goal on the letter now. `done(<id>)` marks it done.
- `note(<id>)` adds a pencil note.
- `mood(+n)` or `mood(-n)` changes this character's feeling toward you.
- `shade(flare|dim|gutter|calm)` sets the shade's resting state from now on, unlike a one-line cue.

**NPC types.** The user wants options to depend on the type of NPC (the demo program's "menus that depend on NPC type"), and the talk must still feel handcrafted. *(Claude's call, how)*:

- A type is a file of its own, `data/dialogue/types/<type>.dialogue`, such as `curandera.dialogue` or `bookseller.dialogue`. It holds the beats and options every NPC of that type offers. A curandera can always do a limpia or sell copal; a bookseller can always be asked for a title or sell a book. Each type is written by hand for that trade, never as a generic hub.
- A type file uses the same blocks as a character file. Its options are marked `>>` and are **added to the end of every opener's options** (before any `-> end` option) of each character of that type, when their `[if]` holds.
- **The character's own words win.** A character file can override any type beat by writing a beat with the same id, so the curandera's limpia can be hers alone while a nameless curandera in the market uses the type's version. `{name}` in a type line stands for the speaker's name.
- Type beats use the speaker's own memory: flags, mood and items given are kept per character, not per type.
- A type can also give its characters a default `colour` and `voice`, which the character file can override.
- Load-time checks also cover a `type:` naming a missing type file, and an override that matches no type beat (reported as a warning, since it may be a fresh beat).

**Load-time checks:** unknown keys, kinds, cues, effects and terms; a `-> beat` that doesn't exist; an item, goal or flag named by another character that doesn't exist; a beat nothing reaches; a character with no opener whose `when:` is empty (the fallback); and `give`/`take` of an undeclared item. A placeholder listing covers `.dialogue` files too.

### 2. The talk state (PeopleState, lasting forever)

The user decided that what characters remember, and the quests they give, **last forever**. They are never wiped by a new mission. `CityState.begin()` resets `JobState` at the start of every mission, so the talk state cannot live there.

- A new `PeopleState.gd` is held by `CityState` as `people`, beside `job`. **`begin()` never resets it.** It keeps:
  - `said` (`{character: [flags]}`)
  - `gave` (`{character: [items]}`)
  - `moods` (`{character: int}`)
  - `met` (`[characters]`)
  - the shown and done lists of **talk goals**, the goals written in `.dialogue` files
  - the pencil notes added by talk
- **Talk goals stay on the letter until they're done,** across missions. *(Claude's call)* A struck-through talk goal leaves the letter at the next mission's start. The letter lists the job's goals first, then the open talk goals as side goals. LetterText and JobState's `goals_listed()` take both.
- `JobState.holds()` asks PeopleState about the new terms, so `.job` goals can depend on talk. The new terms can likewise ask JobState about `took`/`done`/`arrived`. Both states refresh after every effect, so goals that depend on talk show at once.
- `PeopleState` has its own `save_state()` and `load_state()`, ready for disk saving later.

Items given go through `Inventory.add_belt_item` with the item's `name` and a mesh from `Props.belt_mesh` by `look`, so the belt wheel and hand already show them. `Props.belt_mesh` looks meshes up by id, so it learns to take the item's `look` too. Items taken go through `take_one`. *(Claude's call)* New `look` kinds such as `book` and `bundle` are simple Props meshes for now. Real models for quest items follow the one-at-a-time rule.

### 3. The conversation runner (Conversation.gd)

This is pure logic in a `RefCounted`, with no nodes, so a test can drive a whole conversation headless. `start(character)` picks the opener. `step()` yields the next line, pause, sense line or option list. `choose(i)` runs the option's effects and moves to its beat. It emits signals for the box (`line`, `options`, `ended`) and the shade (`cue`). Options whose `[if]` fails are left out without a trace, never greyed.

### 4. The dialogue box (TalkBox.gd)

A code-built `CanvasLayer`, in the manner of the existing HUD. **Its look is the painted UI settled with the user in draft 28 ("Character skins" below), for every character** (the user, 2026-10-23: "can we fit the talk box to the ui we previously established?"). Mockup A is superseded.

- **The portrait**, for a character without a painted one, is a **live render of the shade's own head and shoulders** through a SubViewport camera, framed by the same frayed brush edge, so it flares and dims with the body. *(Claude's call)*
- **Options** are picked with the mouse, number keys, or the wheel plus frob.
- **It works inside the game's existing UI**. The user clarified on 2026-10-23 that "fit into the ui work" meant getting the designed box into the game, not restyling it. The approved draft colours and font stay. *(Claude's call, the integration:)*
  - While talking, the HUD hides the crosshair, the light gem, the awareness marks and the rings, and subtitles move to the top of the screen.
  - The prompts ("Choose", "Continue", "Hold to walk away") appear in the HUD's own key-and-label rows.
  - The letter can't be raised.
  - Esc's pause screen draws over the box.
  - A level change closes the box.
- Lines appear with a short reveal. Frob or a click finishes the line, and a second press advances it. *(Claude's call)*
- While talking, the player stands still: movement and look are held, and the camera eases to face the speaker. The world keeps running, so guards walk and sounds play. **Walking away** has its own key, because Escape already pauses the game; the plan picks which key. *(Claude's call)* Walking away sets the flag `walked_off` so the writer can react to it on the next visit.
- *(Claude's call)* Each spoken line plays a short NOX "hm" or murmur in the character's voice. Only NOX voices are used; they're the project rule.

#### Character skins (added 2026-10-23, from the user's paintings)

Every **important character** gets a talk box painted for them. The user supplied the curandera's three paintings and said "we will do this for each important character". They asked that the box, the dialogue and everything in it **fit the art style of the paintings**, and that the box be **a panel, not a full screen** ("panel! this is UI").

The layout was settled over 28 drafts with the user on 2026-10-23. **The agreed picture is draft 28**, `.superpowers/talkbox/draft28.jpg`, with close-ups `draft28_left.jpg` and `draft28_right.jpg`. The script that drew it, `.superpowers/talkbox/draft28_reference.py`, is the reference for every measure below. All positions are given at 1920×1080 and scale with the screen.

- **A skin is three paintings**, kept in `assets/ui/talk/<character>/`:
  - `backdrop`: the panel's painting. For the curandera this is the cabinet of bottles, skulls and spectral faces. Its own black frame is cropped away, at (98, 22)–(1900, 1072) of the 2000×1120 original.
  - `portrait`: the speaker, painted.
  - `cursor`: a painted spike with a face at its right end. Its black background is keyed out by flood-filling from the image border.

  A character without paintings uses the **default skin**: the same layout, swipes and frayed edges, over a dark painted panel generated by shader from noise in the same palette (green-black ground, muted purple and gold passes toward the edges, a dark reading pool), with the live-render portrait and a simple painted spike as the marker. That covers the librarian until the user supplies his paintings, and every type-only NPC. *(Claude's call)*
- **Every backdrop is centre-cropped to one proportion**, that of the curandera's cropped panel (1802:1050), so the layout numbers hold for every character. *(Claude's call: the librarian's painting is wider, and the uncropped panel pushed his last option off the screen.)*
- **The librarian's skin** (the user's paintings, 2026-10-23: "here it is for the librarian, backdrop, portrait and cursor use the same as the curandera but tinted red"):
  - `backdrop`: the room of red books, skulls, saints and the dark window frame. The black frame is cropped at (30, 40)–(1966, 1076) of 2000×1120, then centre-cropped to (109, 40)–(1887, 1076).
  - `portrait`: the bearded priest-librarian.
  - `cursor`: the curandera's cursor, tinted red (greyscale multiplied by `(255, 70, 60)`, blended at 0.75). It is recorded in his `.json` as `cursor_from: curandera` and `cursor_tint`.
  - Swipe paint: his red books (60, 720)–(400, 960) for unchosen swipes, and his gold cross panel (1700, 420)–(1930, 820) under the warm wash for the chosen one.
  - The agreed look is `.superpowers/talkbox/librarian2.jpg` (the script is `librarian2.py`, beside draft28's).
- **The paintings are only ever scaled down from the user's high-resolution originals**, with mipmapped, filtered sampling, so their quality isn't harmed (the user's words: "so manipulation doesnt fuck up their quality"). They are never upscaled.
- **Layout** (bottom middle, New Vegas order in our own paint):
  - **The panel** is the backdrop, 1000 px wide with its proportions kept. The portrait and the panel are **centred together** horizontally, with the portrait overlapping the panel's left edge by 70 px.
  - **The panel sits low:** its top is at `H - panel_height + 40`, so its foot runs about 40 px off the bottom of the screen. The portrait is 470 px tall, and its top is 70 px above the panel's.
  - A **soft dark shadow**, Gaussian with about a 40 px radius, seats the pair in the world. The world stays visible around the panel.
  - **A dark reading pool** is painted into the upper middle of the backdrop (an ellipse; see the reference script), so the text reads over the painting.
  - **Inside the panel, centred:** the speaker's name in marigold, then the spoken line in cream, wrapped, then the options beneath. The name's baseline sits 146 px below the panel's top, the line starts at 182 px with 38 px line spacing, and the options start at 318 px with 50 px steps. The user set these by eye ("15 px higher", "10 px higher"), so keep them exact.
- **Options** (the user: "have it be inside of the container of selection itself, make it be part of it"):
  - Each option sits in its own **painted brush swipe**, one shared width (the longest option plus 70 px), made of bristle lines with lightly frayed tips. The swipes erode only at their outer 4–5%; the user said a heavier erosion "deletes too much of it".
  - An unchosen swipe is painted with colour lifted from the backdrop's purple flank (region (100, 620)–(260, 900) of the original), at 0.5 brightness.
  - **The chosen option's swipe** is warm: the backdrop's gold table paint (region (130, 965)–(700, 1075)), under a 0.78 wash of `(222, 186, 118)`, with dark ink text. It is longer by the marker's width.
  - **The cursor is part of the chosen swipe:** its spike and face are cut to the swipe's height and set at the swipe's right end, so the tip points at the end of the option's text. Its alpha is multiplied by the swipe's own bristles so it frays with them, and its rim is softened. It is low-key, about 150 px wide in the original's proportions.
  - Text colours are marigold for normal options, cochineal for special ones, and dark ink on the chosen swipe.
- **Borders** (the user: "more integrated, use the colors to your advantage", "more painterly and blended to the image"):
  - Each painting **frays out from its own paint**. Its border is eaten inward by streaky noise that runs along each edge, like a dry brush, with slower noise giving deeper and shallower bites, and with soft rounded corners.
  - A thin, darker **pigment rim** pools just inside the fray.
  - A few thin, tapered **dry strokes** drag the edge's own colours a short way past it.
  - There is **no stretched or blurred copy** behind the edge; the user rejected that look, which read as a glitch. There are no square tabs at the corners and no cross-hatched grain. Draft 28's `painted_edge` is the reference.
- **The living painting** *(Claude's call, proposed to the user with draft 2 and not objected to)*:
  - **Opening:** the panel and the portrait **brush in** stroke by stroke, through a noise-masked reveal, in about 0.6 s. Closing reverses it.
  - **The backdrop's spectral faces breathe**, through a slow masked warp. **Their eyes glow in the shade's colour** and follow the conversation's flare, dim and gutter. Faint dust drifts, and the panel shifts slightly with the mouse.
  - **The chosen swipe** paints in from left to right when the choice moves.
  - **The portrait reacts:** it warms on flare, greys on dim, and flickers on gutter.
  - Where on each backdrop the faces and eyes are is per-skin data. `assets/ui/talk/<character>.json` (beside the gitignored folder, so it is committed) lists normalised rects for `breathe` and `eyes`, plus the crop, the reading-pool ellipse, and the two swipe paint regions, all hand-authored for each skin. Claude writes the curandera's from the reference script.
- **Magic options get their school's shader** (the user: "if we do any obsidian magic or those types of prompts let's have a shader that dictates that type of work going on"):
  - A special option names its school: `> !obsidian <<…>>`. A bare `!` keeps the plain special red.
  - `Sense <school>:` lines are styled the same way.
  - Each school has a swipe and text treatment that shows its kind of work. **Obsidian:** a black volcanic-glass swipe, a cold glint sliding across it, fine fracture lines, and text with a faint mirrored doubling. The program's other schools (copal smoke, séance ghost-light, nahual claw marks, Lumen arc flicker, relic gilding) get the hook and a simple first look. Obsidian is the one finished now. *(Claude's call: the details of each look.)*
  - Built in Task 6c.
- **In Godot**, the swipes, the frayed edges and the reading pool are **shaders on TextureRects** over the user's paintings. They are not baked images, so they keep full resolution and can animate. The masks may be generated once at load from seeded noise, matching the reference script's look.
- **Art files:** the user's originals for the curandera are in `assets/ui/talk/curandera/originals/` (`backdrop.webp`, `portrait.webp`, `cursor.webp`). A script, `tools/prepare_talk_art.py <character>`, converts them to PNG, keys the cursor, and caps their size at 2048 px for import.
- **Rights** *(Claude's call)*: the repository is public and the paintings' licence isn't recorded, so `assets/ui/talk/*/` is **gitignored**, as `textures/ps2` is. A checkout without the paintings falls back to the plain box. `assets/ui/talk/README.md` says where the paintings come from. The user can flip this once the rights are settled.
- **Font:** the drafts use Georgia (regular, bold, italic) as a stand-in, but it isn't in the project. Until the user picks a typeface, the box uses a system serif where one is found and Godot's default font otherwise. **The typeface is the user's to choose.** Sizes at 1080p: name 24 bold, line 29, options 26 italic.

### 5. The shade (Shade.gd and shade.gdshader)

An NPC node is a `StaticBody3D` with `frob()`/`get_prompt()` ("Talk") and an exported `character` id. It holds a `Humanoid` dressed from the wardrobe. The curandera uses the **`duelist`** (female swordmaster). The librarian uses *(Claude's call, to confirm)* **`arms_master`**, or `swordsman` if the user prefers. Every mesh gets the shade material instead of the wardrobe shader.

- **The look** *(Claude's call: the user gave no reference, and a web search didn't confirm what Deadlock calls shades)*:
  - The body is smoky and half see-through, so the clothes still read as a silhouette.
  - A bright fresnel rim outlines it.
  - Slow smoke drifts inside, as 3D noise in object space.
  - The body thins and frays into wisps toward the feet, by height.
  - Each character has one colour: **copal amber** for the curandera and **cochineal red** `Color(0.9, 0.22, 0.2)` for the librarian (the user, 2026-10-23: "lets make the librarian redder").
  - Our own wisp particles rise off the shoulders and feet, built from the project's own smoke sheets or noise and never downloaded.
  - A depth prepass keeps the inside of the body from showing through itself.
- **States** are a few uniforms eased over time: **calm** (resting), **flare** (rim and glow up, smoke quickens), **dim** (fades, thins and cools), and **gutter** (a candle-like flicker). A line's cue acts for that line. `shade()` changes the resting state.
- **Body:** `Idle` while listening and `Idle_Talking` while speaking. The shade turns smoothly to face the player when talked to. *(Claude's call)* The optional cues `[nod]` and `[shake]` play the existing `Yes` and `Idle_No` clips. They're used sparingly; the light carries the reaction.
- **Scope** *(Claude's call)*: the shade is a stand-in for these two characters. The shader and `Shade.gd` are written so any later spirit, such as the familiar, can reuse them. The live-render portrait and the wisps are sized for one speaker at a time, not crowds. No in-world reason for the shades is claimed yet.
- **Review order:** following the standing rule that models are built one at a time under supervision, the shade look is shown to the user on the curandera first, in-game stills plus the gym, and fixed before the librarian is dressed.

### 6. The test quest and gym

`maps/talk_gym.tscn` holds both shades in a dim room with a lamp each, plus the player. The structure below is *(Claude's call)*, and every word in it is a placeholder for the user:

1. **Curandera, first visit:** she reads you, a sense line can fire, and she asks for a book that only the librarian has. This shows the side goal "bring her the book".
2. **Librarian:**
   - He knows of her.
   - Telling the truth, paying, or a special option gets you the book (`give(the_book)`).
   - A lie dims him, sets `mood(-1)`, and he refuses. His opener is different on your next visit, and you can make amends.
3. **Curandera, with the book:**
   - Handing it over runs `take(the_book)`. She gives a copal bundle (`give(copal_bundle)`), the goal is marked done, and she adds a pencil note.
   - Lying that you don't have it while `has(the_book)` holds makes her gutter and react.
4. **Revisits:** each character opens differently after the quest, and the librarian remembers the lie.

5. **Types:**
   - The curandera is type `curandera`, which gives every curandera a limpia and copal for sale. Her file overrides the limpia with her own.
   - The librarian is type `bookseller`, which gives every bookseller "ask for a title" and selling a book.
   - The gym adds a third, nameless **curandera stand-in shade** that uses only the type file, to prove types work without a character file of their own. *(Claude's call)*

This one quest exercises quest given, item given, item taken, reactions, memory, a cross-character condition, NPC types, and the letter.

## Testing

`tests/dialogue_test.gd` runs headless like the other suites. It covers:

- Parse errors with `file:line` for every check listed above.
- Every new condition term and effect.
- The whole test quest driven through `Conversation`: both routes (truth and lie), revisits, the goal showing and being marked done on the letter, items on and off the belt, purse changes, moods, and `walked_off`.
- `save_state` and `load_state` round-tripping PeopleState, and the talk state and open talk goals **surviving `CityState.begin()`**.
- Type options merged into the openers, overridden by the character's own beat, and a type-only NPC playing without a character file.
- The shipped `.dialogue` files loading with no errors.

The existing job, guard-talk and interaction suites must stay green. Stills of the shade (calm, flare, dim, gutter) and the box are staged windowed for the user's review. The user plays the gym.

## Constraints

- Godot 4, GDScript, matching the surrounding code's style: plain-English `##` comments and the conventions of JobBook and JobState.
- *(Claude's call)* Work goes on a new branch `talk-quests` in its own worktree, cut from `free-run`, because `free-run` has uncommitted work in the main checkout.
- No downloaded VFX. Only NOX voices. Never call a visual defect harmless.

## Left to the builder

- The exact shader maths and uniform ranges, the wisp emitter, and the box's animation timings.
- Box sizes and placement at different resolutions, within mockup A's look.
- How the camera eases toward the speaker, and how long it holds.
- The internal structure of TalkBook, Conversation and the gym's layout.
