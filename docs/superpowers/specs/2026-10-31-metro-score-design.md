# The Metro score: one piece, a theme for every space

Status: approved by the user, 2026-10-31.

## Intent

The Metro Underground gets its own music: one continuous piece that changes and morphs as you explore. Every space has its own theme, and each theme adapts as things change: where you are, what is near you, and what you have done. It is a new score. It borrows nothing from the menu theme (`hasta_los_huesos_overworld`) or the combat score (*Hasta los huesos*).

The Metro is for immersion, leads and characters, with no combat (the Metro spec, 2026-10-16). The music is how a space feels before anyone speaks in it.

## The palette

The palette is the same as the rest of the game's music (`docs/superpowers/refs/main_menu/music_references.md`, and the bible's sound section). It is neo-noir and trip hop with an occult side, coloured by Latin jazz: bolero, danzón, son.

- **Restraint, as in Goldsmith's *Chinatown*:** few instruments, period colour, no cliché.
- **Mood:** Portishead and Massive Attack, Bohren & der Club of Gore, Badalamenti.
- **Mexico:** Grim Fandango's mix of Bogart films and raw son. For the period city, barrel organs and típica orchestras.
- **The deep:** Revueltas's street-band ostinatos for the darkest layer; drones, the tritone, bells and wordless choir for the occult.

## Goals

- **One piece across the whole Metro.** You never hear a song stop and another start.
- **Every space has a theme of its own,** with its own melody, instruments and groove.
- **Crossing a threshold is a musical event.** The theme you leave thins out while the next grows in, and corridors and stairs hold a bit of both.
- **What is near you right now bends the theme playing.** Ánimas, the dark train and the other supernatural things change it while they are close, then let it recover.
- **What you have done picks a theme's variant.** Her theme sounds different once you have helped her.
- **Depth darkens everything.** The older and deeper the layer, the fewer city instruments are left.
- **Themes are made one at a time,** each judged by the user by ear before the next.

## Non-goals

- The menu and the combat score are not changed. If a fight starts in the Metro, the combat score takes over as it does today and the Metro score sinks under it (see "Living beside the other music").
- The other districts' music. The system is built so the Zócalo or anywhere else could get a score of its own later, but none is written here.
- The car ride's theme is listed, but the ride itself (Metro Part 2) is not built yet. Its theme waits for it.
- No new ambience or sound effects. The Metro's sounds are a separate piece of work, waiting on the user's recordings.

## Anti-goals

These would make it a failure even if it works:

- **Pastiche:** a "Latin music" preset, or a 1990s trip-hop parody.
- **Music on top of the world.** It must sit under the Metro's sounds (ánima voices, neon, pipes, books, the crowd), never over them.
- **Cuts and seams:** a theme snapping in, a click at a loop, two themes out of step.
- **Fatigue:** the same loop heard so many times in one place that it grates.
- **Shipping a stand-in as finished.** Placeholder stems are labelled as such until the user approves the real ones by ear.

## Constraints

- **Claude cannot hear.** Every musical decision is auditioned and approved by the user. Claude writes MIDI and drives Logic on screen; the user listens, swaps instruments, and keeps or cuts.
- **Logic Pro** is the tool, as for the menu theme (`~/Music/Logic/`). Logic's own players carry the grooves (Drummer, the Percussionist, Bass Player on a Chord Track). Claude writes MIDI for everything melodic, because melodies need exact notes.
- **Godot 4's `AudioStreamSynchronized`** holds up to 32 locked streams. The combat score and the menu already use it, reading their clock from the playback position (`scripts/Audio/Music.gd`, `scripts/Audio/MenuMusic.gd`, `MenuClock.gd`).
- **Buses** come from `scripts/Audio/Sfx.gd`. The `Music` bus already ducks under `World` sounds through a sidechain compressor.
- **Source masters** live under `assets/audio/source/` (gdignored and not committed), as for the other two scores. Game files are prepared by a script that records hashes and levels.

## Approaches

1. **Pure layering:** every theme's stems in one giant locked stream, with volumes turned up and down. It morphs perfectly, but eight or more themes of four to six stems each will not fit in 32 streams, and every theme would have to be the same length. Not chosen.
2. **Song sections:** each theme a run of sections, switched on bar lines through written bridges. Each theme gets its own shape, but it feels like switching songs rather than morphing, and the bridges multiply with every new theme. Not chosen.
3. **Bed plus theme sets. Chosen by the user.** A bed loops forever as the Metro's spine. Each theme is its own small set of locked stems, started in step with the bed's clock. Spaces fade theme sets in and out, overlapping on thresholds, while the bed never stops. It morphs like approach 1, has no cap on the number of themes, and lets each theme loop at its own length. The cost is that the bed must be written first and fixed early, because every theme is composed over it.

## How it works

### The frame

The whole score shares one tempo, one bar grid and one home pitch.

- **Tempo:** about 72 bpm in 4/4, a little slower than the menu, like a held breath. *Claude's proposal; the user sets it by ear in the template.*
- **Home pitch:** one pedal note under everything. Its pitch is chosen by ear in the first session, deliberately not the menu's D. *Claude's proposal.*
- **Theme lengths:** every theme loops at a whole number of 4-bar phrases, so any theme can enter or leave on any phrase line.

### The bed

The bed never stops while you are in the Metro. It is the reason the music feels like one piece. It holds:

- a **drone** on the pedal note, in two colours, city and deep, crossfaded by how far down you are;
- a **soft pulse,** felt more than heard, which themes can lean on or drop;
- a **room texture:** tape, hiss and the tiled hall's air.

**Change from the conversation (Claude's call):** the bass belongs to the themes, not the bed. A bass line in the bed would fix the harmony, and every theme would then have to share one chord loop, which would make eight themes sound like one. With only a pedal in the bed, each theme is free to make its own harmony over it, and its own modal colour does the work:

- the city spaces in plain minor;
- the lane warmer, Dorian;
- the deep layers sliding into Phrygian, with the tritone.

### The themes

Each theme is a set of stems over the bed: its bass, its groove, its lead (the theme itself), and colour parts. It also has:

- **intensities:** a calmer version and a fuller version, from which stems are playing;
- **story variants:** alternate stems chosen by what you have done;
- **haunted stems:** written for the moments when a live effect is not enough.

The themes and their first ideas, all Claude's proposals for the user to change:

| Space (plan names) | First idea |
|---|---|
| **Entering the Metro**: a cue, not a looping theme (Claude's call) | The city above falls away: a descent cue that hands off to the bed's first breath and the theme of wherever you are. Today it plays when the Metro map starts, as the loading screen lifts after the menu's last phrase; New Game puts you in the candle lane. When the Zócalo's stairs and the car exist, the same cue plays from them. |
| **Hall and platforms**: `hall`, the corridors, `platform_n`/`platform_s`, `stairs_*` | Public and distant: a barrel-organ waltz drifting in over a dusty trip-hop break. |
| **The Pasaje**: `pasaje`, market lanes, `fondas`, `square_s` | A danzón figure on güiro or claves, under neon. |
| **The candle lane**: `candle_lane` | A slow bolero. The lane's street theme sits between her and him. |
| **The curandera's space**: around her stall, inside the lane | Marigold-warm: guitar in thirds, copal in the air. |
| **The librarian's space**: `librarian_shop` | Harpsichord, celesta and wordless choir, with the books' rustle left room. |
| **The old layer**: `vaults`, `cistern`, `drain_n`, `crypt`, `pawn_vault`, `templo_shells`, `temple_tunnel` | Drones, teponaztli and huehuetl, clay flutes and Revueltas-style ostinatos. Possibly several themes (drain, crypt, temple). |
| **Inside the car**: the ride, when Metro Part 2 exists | Over the moving tunnel: vaults, then Aztec shells, then ghost stations. |

Spaces not listed (storerooms, the loft, the chapel and the rest) take the theme of the space they open from, until the user wants one of their own.

### Where you are

- **Spaces come from the Metro plan** (`assets/eclipse/metro/plan.json`). Each space has a name, a floor polygon and openings, and a table maps space names to themes.
- **A small space inside a bigger one** (her stall in the lane) is a soft circle around a point. Near her, the lane's theme leans toward hers rather than switching outright.
- **Thresholds:** within a few metres of an opening between two themes, both play. Their weights cross over as you walk through, so corridors and stairs hold a bit of both.
- **Changes land on the music's lines.** A theme coming in begins on the next phrase line, in step with the bed, and swells up. A theme going out fades over a bar or two. Weights move smoothly, never in jumps.
- **Depth means age, not height (Claude's call).** The plan's heights don't follow its layers: the platforms at −14 sit below the older candle lane at −11, and the cistern alone is 16 m tall. So depth is read from the plan's `layer` of the space you are in (1 the station, 2 the market, 3 the old layer), crossfaded across thresholds the same way themes are. Only inside layer 3 does height deepen it further, so going down the old layer's shafts keeps darkening. Depth drives the bed's city-to-deep crossfade and thins every theme's city instruments.

### What is near you

The supernatural things already in the Metro tell the music when they are near, and the music bends:

- **Ánimas** (`scripts/Visual/Animas.gd`) react by **what they do, not by being near (the user's choice).** They live in the candle lane all the time (the drain and three wall vents), so nearness alone would haunt the lane's theme constantly. The music answers their acts, read from `state_of()`:
  - **pleading** (begging you): the lead detunes slightly and the tritone colour comes in;
  - **straining** and **dragged** (pulled back to the drain): the theme's pulse falters and a haunted stem can sound;
  - several at once out of the drain (swarming): stronger, by count.
  Climbing, warming, lurking, hiding and escorting leave the theme alone. Which act gets which change is decided by ear.
- **Others, as wanted:** the watching eyes, the shades and their crowd surge, the wisps.
- **Not in this work: the dark train (the user's choice).** It exists only in the look-dev bay (`maps/underground_lab.gd`, `scripts/Visual/TrainPass.gd`), not in the Metro map, and it stays out for now. When it comes into the Metro, its idea is to steal the pulse (the theme holds its breath until it has passed). The Company's ordinary trains would not; they are daily life (Claude's call).

Two tools do this:

- **live effects** on the score's own bus: a slight detune or chorus, a low-pass that muffles, the pulse dropping out;
- **written haunted stems,** when a theme needs a change an effect cannot make.

Which effect each thing gets is decided by ear per theme.

### What you have done

- Story variants read what the people of the city remember (`scripts/Level/PeopleState.gd`): flags, moods and whether you have met. Conditions are written in the same words the talk system already uses (`Terms`), for example *met*, or *mood ≥ 2*.
- A variant changes on its theme's next phrase line, crossfaded, never mid-phrase.
- **What exists today:** conversations and their memory. The quest and world-state stage of the progression program is not built yet. Until it is, variants can only hook onto what `PeopleState` already knows.

### Against fatigue (Claude's call)

After you have stayed in one space for a number of loops, its theme thins back toward the bed for a while, then returns, perhaps in its other intensity. The numbers are set by ear.

### Living beside the other music

- **The combat score:** if `Music.gd` is playing (a fight), the Metro score sinks well under it and comes back when the fight has faded.
- **The menu score** is never playing in the Metro.
- **Bus:** the Metro score plays on `Music` through its own sub-bus, which carries the live effects. The existing duck under `World` sounds keeps it under the Metro's sounds.

## Making the music

- **The template.** One Logic project holds the frame: tempo, bar grid, the pedal, and the bed's tracks. Every theme starts as a copy of it, so it is composed over the real bed. *Suggested name: `~/Music/Logic/metro_score_template.logicx`, with one `metro_<theme>.logicx` per theme.*
- **Melodic parts.** Claude writes them as MIDI from a script (a sibling of `tools/compose_menu_parts.py`) and imports them into Logic, driving it on screen. Logic's players carry the grooves.
- **The user listens and decides.** Nothing is final until approved by ear.
- **Export:** per-stem audio files, 48 kHz, from bar 1, normalisation off, the user's fader balance. This is the same export as the menu's.
- **Preparation:** a script (a sibling of `tools/prepare_menu_score.py`) turns stems into game files under `audio/music/metro/`. It writes a `score.json` with each theme's stems, length, intensity and variant roles, haunted stems, hashes and levels. Reverb tails are preserved across loop joins, as `prepare_score.py` does.

## Order of work

One piece at a time, each approved by the user by ear before the next:

0. **The frame and the bed,** in the template. Until the bed is approved, no theme is composed.
1. **Entering the Metro.**
2. **The candle lane.**
3. **The curandera's space.**
4. **The librarian's space.**
5. **Later, one by one:** hall and platforms, the Pasaje, the old layer, the car ride, the dark train once it is in the Metro, and the haunted stems as each supernatural thing comes up.

The game side is built alongside, against placeholder stems bounced from the template, so that each approved theme can be walked in the game at once. The candle lane, her stall and the librarian's shop are the only finished places, so pieces 2 to 4 can be judged in place. Piece 1 is judged on arriving from New Game.

**Levels (Claude's call):** the candle lane is hushed today (`candle_lane._hush()` stops every sound except the ánima voices and the shop's books) until the user's recordings arrive. Approving a theme approves its music. Its level against the world gets a re-balance pass once the recordings are in, and no theme's mix counts as finished before that pass.

## Testing

- **Headless checks:**
  - zone weights from the plan, including thresholds and soft circles;
  - themes entering on phrase lines in step with the bed;
  - variants switching on phrase lines from `PeopleState`;
  - the ánimas' acts (pleading, straining, dragged, several out at once) bending the theme and letting it recover;
  - sinking under the combat score;
  - the fatigue thinning;
  - stopping and restarting cleanly when leaving and re-entering the map.
- **Listening renders:** a scripted walk recorded with `AudioEffectRecord` (as for the ánima voices), so the user can hear a transition without playing.
- **The user's walk in the game** is the real test.

## Risks

- **Several players in step.** The bed and each theme set are separate players, started on the bed's clock. Whether they stay locked over minutes, and whether a set can start mid-loop at the right position, must be measured early. If they drift, there are two fallbacks: re-align on phrase lines, or merge the bed into each theme set.
- **Monotony from one pedal.** If one pedal under everything tires, the bed may need a slow second pitch (a long two-note sway) that every theme respects. This is decided by ear at step 0.

## Left to the builder

- Node and file names. The proposal is a reusable `PlaceScore` node, data-driven by `score.json`, with the Metro as its first score.
- How zones are read from the plan, and the threshold width.
- Fade times, swell shapes and effect amounts, all tuned by ear with the user.
- How the listening renders are scripted.
