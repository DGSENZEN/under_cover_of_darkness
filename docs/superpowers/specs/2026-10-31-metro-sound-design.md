# The Metro's sound: every space its own, layered from the user's takes

Date: 2026-10-31. Branch `metro-sound` (worktree `.claude/worktrees/metro-sound`), cut from `metro-score` 30db5ec8.

## Intent

The Metro Underground (maps/metro.tscn: the station set, the Pasaje, the candle lane and the librarian's shop, the
greybox around them) gets its sound revamped from the user's new ElevenLabs takes (paid plan: cleared for commercial
use). Today the Metro has little of its own: on Oct 17 the bay's sounds were judged bad (too loud and harsh, fake and
cheap, repetitive, the wrong space), and `candle_lane._hush()` stops the vent hum, the flat train rumble, the jars, the
sound-only Crowd and the dark wind to wait for these recordings. What still sounds there: the neon (`neon_buzz_*`), the
pipes, the shop's books and the ánimas (their players are built after the hush, on purpose), and the default
`interior_night` ambience loop under everything (metro.tscn sets no `ambience`). The station hall's room tone, trains
and crowd never played outside the look-dev bay.

The game is getting a dynamic audio system next to the adaptive Metro score (docs/superpowers/specs/2026-10-31-metro-
score-design.md). The Metro's sound is that system's first place: it reads the same map of spaces the score reads, so
the sound and the music change together, room by room.

## The shape (the user's, Oct 31)

Busy and warm near the Pasaje and the stalls (crowd, trains, neon), thinning with depth to near-silence in the old
layer (water, stone settling, a cold draught), so the ánimas and the strange things stand out when you meet them.
Deeper is older (the plan's `layer`), as in the layout and the score.

## Goals

- Every take the user made is used where it fits, and the user's several takes of one noise are **layered**: each sound
  the game plays is built from several takes laid together, varied in pitch, offset and level, baked as many variations,
  one picked at random each time. Nothing repeats exactly.
- Each of the plan's spaces sounds like itself: a bed per family of spaces, crossfaded through openings, thinned by depth.
- The things that make noise carry it: neon signs, pipes, the Company's electrics, books, steps.
- A Metro mix: compression to glue it, a tiled-hall reverb that follows the space, everything low and spread out.
- The candle lane un-hushed with the new sounds.

## Non-goals

- **The spells** (Blink, Shard, Ward takes exist; Empower and the Ward's stop and drain do not): a follow-up once the
  user has the rest of the takes.
- **The mix outside the Metro** (the harbour, the garrison, sword fights): its buses, compression and reverb unchanged.
  (A sound that keeps its game name but gets a new source, such as the carpet steps, changes wherever it plays: the user
  asked for the older sounds to be revamped with these takes. Claude's call; suites re-baselined where they listen.)
- **The dark train** (the user's: not in this work). It already runs inside the lane set (candle_lane extends the bay,
  which builds it): it sinks the lights and hushes the ánimas, and its wind is silent. It stays exactly so: the selective
  hush keeps `dark_wind` stopped (Claude's call).
- **Voices** (the lane's pockets for prayer, bargaining, a radio, vendors' calls): no takes; they stay silent and are
  listed as needing sources.
- **Changing the score**: PlaceScore is left as it is; the two only share `PlaceZones`.

## Anti-goals

- **The Oct 17 failures again:** too loud, harsh, fake, repetitive, wrong space. Every family is approved by the user by
  ear before it counts as done; a stand-in is never shipped as finished.
- **Sound on top of the score, or the score on top of the sound:** both stay under the Metro's own sounds (the score's
  duck under World stays as it is).
- **A drone fighting the score:** the score's bed is in C. A hum is a real pitch, so every hum sits on G or is retuned to it.
- **Colliding with the map's builders:** another session builds the map on `metro-standard` right now. The sound lives
  in its own files; the map's files get one hook each (see "Where it lives").

## Constraints

- Godot 4, the existing audio code: `Sfx.gd` (buses World, WorldFar, Body, Music, Ambience, Souls; the master limiter;
  occlusion; `probe_room`/`shape_room`/`set_acoustics` reverb), `Focus.gd` (tiers: bed 1, loop 3, detail 4, featured 2;
  the rest sink −12 dB), `NeonSign.gd`, `PipeSounds.gd`, `BookSounds.gd`, `Animas.gd`, `TrainPass.gd`.
- `tools/prepare_sfx.py` cuts every sound; sources live outside git (`~/Downloads/...`), the results in `audio/`.
- The suites run headless and frame-exact; new randomness is seeded and owns its RNG (headless-test-determinism memory).
- Physics interpolation is on project-wide: nothing that moves an emitter in `_process` (judder memory).

## The takes (the user's zip, 39 files)

Moved out of the Desktop to `~/Downloads/AUCOD ElevenLabs/ucod_sounds/` (outside git, like every other pack) and
credited in CREDITS.md as ElevenLabs Sound Effects, generated by the user on a paid plan.

| Group | Takes | Measured |
|---|---|---|
| Station hall room tone | 1 (30 s) | broadband, low rumble |
| Distant train through rock | 3 (15 s) | |
| Tunnel draught | 2 (15 s) | |
| Market crowd down a corridor | 2 (30 s) | |
| Water hammer | 2 (12 s) | 3 hits each |
| Pipes cooling, ticking | 3 (15 s) | |
| Travelling knock | 1 (8 s) | 5 hits |
| Steam valve | 2 (8 s) | |
| Neon hum | 2 (20 s) | 100 Hz (+35 cents: nudged to 98) and 97.5 Hz (−9 cents, keep) |
| Neon stutters | 2 (8 s) | |
| Neon switching on | 1 (6 s) | |
| Junction box | 1 (15 s) | 200 Hz (+35 cents: nudged to 196) |
| Transformer | 1 (30 s) | 113 Hz: retune to 98 Hz (G) |
| Cable surge | 1 (20 s) | 120 Hz (60 Hz mains): retune to 98 Hz |
| Tile steps, leather soles | 1 (15 s) | ~37 onsets |
| Carpet steps | 1 (15 s) | 9 steps, muffled |
| A person: stop and turn, or landing | 1 (12 s) | 8 hits; which it is decided by ear |
| Heavy book opening | 1 (15 s) | |
| Book slammed shut | 1 (6 s) | |
| Single page turns | 1 (15 s) | |
| Riffle | 1 (6 s) | |
| Spells (not in this work) | 8 | Blink 2, Shard 4, Ward 2 |

Which file is which: the names are cut short, so the three 15 s `Close_foley_of_singl_` files are told apart by their
onsets and brightness (measured Oct 31: 37 bright onsets the tile steps ...480540, 9 muffled the carpet ...499577, 4
bright the page turns ...652718); the table in `prepare_sfx.py` names each file.

Not made yet (the current sound stays, listed for the user): drips, the old layer's cavern, the breathing crack,
floating books, the shelf stirring, a book dropped.

## Approaches

1. **Follow the spaces, on the score's map (chosen by the user).** A director reads the plan's spaces through the
   score's `PlaceZones` and crossfades a bed per family as you walk, thinned by depth; point sources ride on the pieces
   that make them; a Metro mix (compression, a space-led reverb) over it. It feeds the dynamic audio system and never
   collides with the map's builders: when a room moves, its sound moves with it.
2. **Hand-placed pockets** (the candle lane's way now): simple and exact, but it breaks when the map moves, edits the
   files another session is in, and gives the adaptive system nothing.
3. **Baking the space into the files** (dropped): it brings back "wrong space" and "too dry", and cannot adapt.

## How it works

### Preparing the sounds (`tools/prepare_sfx.py --metro`)

A new table set, METRO, beside LAYER_LOOPS and BEDS, and one mode `--metro` that makes only these:

- **Layered one-shots.** A group names its source takes; each take is split into its separate hits (`split_events`, as
  the voices are). A variation lays one hit with, sometimes, a second from another take under it (−6 to −12 dB, a few ms
  late, its own pitch), each with its own pitch (±6 %) and level; 8 to 12 variations a group, loudness-matched, mono
  (the game places them). Seeded, so a re-run makes the same files.
- **Layered loops.** A bed's takes are laid over each other at offsets, so no two loops start alike; seams crossfaded
  equal-power (as `write_loop`); 2 or 3 loops a bed, picked per space. The beds stay stereo (heard everywhere, not
  placed); the loops a piece carries are mono.
- **Retuning.** A take's measured hum is pitched to G (98 Hz family) by resampling before layering; the tool measures
  the result and refuses a hum that lands more than 20 cents off.
- **Dry.** Nothing is reverbed offline: the room is the game's.
- **Listening files.** Each group writes a short listening WAV (its variations one after another) to the scratch
  folder for the user's ear, before anything is wired.

### The director (`scripts/Audio/PlaceSound.gd`)

A node the Metro adds once its sets are in, as it adds PlaceScore. It loads the plan and builds its own `PlaceZones` from
its own table (space → bed family; the score's table maps only the lane's spaces, so the two cross over at different
openings: the score at the lane's, the beds at every family's). Every frame, on real time (TimeFx, as Ambience; slow
motion leaves it alone), it sets each bed's weight from where the player stands: a space's bed at full inside it, two
beds crossing over within THRESHOLD of an opening. No circles: the stall has no source of its own yet.

The Metro sets its `ambience` meta to "" so the default `interior_night` loop no longer plays under the beds.

The bed families (Claude's call on which space goes where; the user corrects by ear):

| Family | Spaces | Bed |
|---|---|---|
| hall | hall, corridors, crossings, exit stairs, kiosk landings | room tone, a far crowd at a whisper |
| platforms | platform_n/s, track, siding, stairs_n/s | room tone, the trains and their draught (below) |
| market | pasaje, pasaje_n/s, market_stairs, the lanes, fondas, square_s, herb_market | the market crowd, warm |
| candle lane | candle_lane, chapel | the crowd from the Pasaje's end only, low; the lane's own sources carry it |
| shop | librarian_shop | near-silence: the books and the room |
| old | every layer 3 space | near-silence: the cavern bed once the user makes it; until then the room tone taken far down |

**Depth** (PlaceZones' depth: 0 the station, 0.35 the market layer, 0.7 the old layer, deeper down its shafts) thins
what is the city only on the way into the old layer: the station and the market (both busy, the market the busiest)
keep the city at full; from 0.35 to 0.7 the crowd and the trains fall away, gone in layer 3; the room tone darkens over
the same stretch (a low-pass eased with depth). (Claude's call: thinning from 0 would quiet the Pasaje below the hall,
against the shape.)

The beds play on a new bus `MetroBed` under Ambience, so they keep Ambience's duck under World and its hurt filter.

### The trains: one clock for the Metro

One `TrainPass` (seeded, game time) for the whole Metro, owned by the director. While a train passes:

- its rumble plays from the track's tunnel mouths (placed, occluded as any sound), so it is strongest on the platforms
  and comes through the walls everywhere else, thinned by depth;
- its draught gusts on the platforms and down the stairs;
- the Company's lines sag: the candle lane's lights already sag on its train; in the Metro the lane follows this clock
  instead of its own, and a cable surge sounds from the nearest electrics while the lights dip.

### The things that make noise

Pieces opt in by tag: a node in group `metro_sound` with meta `sound` (`transformer`, `junction`, `valve`, ...) gets its
loop or its events from the director, held by Focus at its tier. The map's builders tag their pieces (the station's
mains, risers and vents on `metro-standard`) with one line each; the director never needs the map's code.

- **Neon** (`NeonSign`): its hum from the new buzz takes (two layered loops, one per sign); its stutter ticks and its
  short strike back (`neon_zap`) from the flicker takes. The switching-on take has a cause in the world (Claude's call):
  it plays when a sign comes back from a deep brownout (a train drawing on the line sags it far enough to go out), and
  on a sign that starts dark; its tail is the hum coming in. The hum still follows the tube.
- **Pipes** (`PipeSounds`): its knocks become the water hammer and the travelling knock; the ticking joins as a sparse
  detail on hot lines; the valve as an event on the gate valves. Its drips, gurgles and trickle stay until new takes.
- **The Company's electrics:** the junction box loop on wall boxes, the transformer on the station's mains (both retuned
  to G), the surge with the trains.
- **Steps:** no Metro floor carries a `surface` meta today, so everything walks as stone. Rather than tagging floors in
  the map builders' files, the floor answers from the place (Claude's call): a floor with no `surface` meta asks the
  director, which answers by the family you stand in (the station and the market: `tile`; the shop: `carpet`; the old
  layer: stone). A floor's own meta, where one is set, still wins. `tile` gets its own steps (`step_tile` from the new
  take, layered) instead of walking as stone; `carpet` its steps from the new take. Runs, jumps and landings on tile
  stay stone's. The person take is cut into scuffs (stops and turns) or landings, as it turns out to be.
- **Books** (`BookSounds`): opening, shutting, page turns and the riffle from the new takes, layered with the current
  ones; the shelf, the flutter and the landing stay.

### The candle lane un-hushed

`_hush()` becomes selective. The neon, pipes, books and ánimas already sound and get their new sources as above. Of what
it stops: the vent hum and the jars play again from new sources (the vent from the draught take, the jars as they are,
which the user has not judged apart); the flat rumble and the Crowd node give way to the director's trains and crowd,
so nothing doubles; the dark wind stays stopped. Standalone (the lane opened on its own) it stays as it is.

### The mix

- **Compression (glue):** while the Metro is loaded the director puts a gentle compressor on Master, before the limiter
  (threshold about −20 dB, ratio about 2:1, attack 10 ms, release 250 ms), and another on MetroBed; it takes them off when
  the Metro goes. Not on World (Claude's call): World is the sidechain of the Music and Ambience ducks, and the ánimas'
  Souls bus sends into it, so a compressor there would change the ducks and squash the ánimas. The master limiter stays.
- **Reverb led by the space:** a new acoustics kind, `tile` (a bright tiled hall: longer, less damped than stone), and
  the director sets the level's kind from the family you stand in (tile in the station and the market, stone in the
  lane and the shop, cave in the old layer), eased so it never jumps; `probe_room` still sizes the room under it.
- **Levels:** low, set by ear; Focus keeps the layers from piling up.

### Living beside the score

The score and the director do not talk to each other. Both use the `PlaceZones` code, each with its own table; in a
fight the score sinks under the combat score as today, and the beds sink with Ambience's duck.

## Where it lives

- Built on `metro-sound` (cut from `metro-score`: it has PlaceZones and main). New files: `PlaceSound.gd`, the METRO
  tables in `prepare_sfx.py`, `audio/sfx/metro_*`, `audio/ambience/metro_*`, tests.
- Hooks, one each: `maps/metro.gd` adds the director beside PlaceScore; `Sfx.gd` gains the `tile` acoustics and steps;
  `NeonSign`, `PipeSounds`, `BookSounds` read their new names; `candle_lane._hush()` turns selective.
- The station set (`maps/metro_station.tscn`) and its machine came in from `metro-standard` (merged into `metro-sound`
  on the user's word, Oct 31, at its commit 0adfe1b8). The station's pieces (Company lamps, mains, risers, vents, wall
  boxes) get their `metro_sound` tags on this branch, one line each. `metro-standard` keeps moving in its own session;
  this branch takes its later commits by merging again, never by editing its files ahead of it beyond those tags.

## Order of work

1. Sources moved, credited; `--metro` cuts and layers every group; the user approves each by ear from listening files.
2. The director and the beds, the depth thinning, the Metro buses.
3. The trains on one clock.
4. The point sources: neon, pipes, electrics.
5. Steps and books.
6. The candle lane un-hushed.
7. The mix: compression, the space-led reverb, levels.
8. A listening walk (a scripted walk recorded with `AudioEffectRecord`, as the score's) through every family, for the
   user's ear; then the user plays it.

## Testing

- `tests/test_prepare_sfx_metro.py`: every group's takes found, variations seeded and loudness-matched, every hum on G
  within 20 cents, loops seamless.
- `tests/metro_sound_test.gd`: each family's bed at full inside its spaces; crossing over at an opening; depth thinning
  the city to nothing in layer 3; one train clock, its rumble placed, the lane following it; tagged pieces sounding;
  `tile` steps; the buses and compressors on with the Metro and off after; the acoustics easing per family.
- Failing first, as always; the existing suites (layers_test, place_score_test, sound_test) stay green.

## Left to the builder

- Which space joins which family where the table is unclear (the light gallery, the grate room, the loft).
- The exact counts of variations, the layering ranges, the compressor's numbers, every level: by ear.
- How the director finds the track's tunnel mouths (the plan's `track` polygon ends, most likely).
