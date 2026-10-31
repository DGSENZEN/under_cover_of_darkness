# Metro score source

The Metro's adaptive score (docs/superpowers/specs/2026-10-31-metro-score-design.md):
a bed that loops for as long as you are in the Metro, and a theme for every space
over it. The WAVs are Logic exports, working masters, and are never committed
(`.gitignore` here); `map.json`, the MIDI parts and this README are.

## The frame

Approved by the user by ear on 2026-10-31.

| | |
|---|---|
| Pedal (home pitch) | C |
| Tempo | 72 bpm, 4/4 |
| Phrase | 4 bars (13.33 s); every theme loops at a whole number of phrases |
| Template | `~/Music/Logic/metro_score/metro_score_template.logicx` |

## The bed

16 bars, from the C take of `parts/bed_audition.mid` (written by
`tools/compose_metro_parts.py --piece bed`), on sounds the user chose in Logic.
Exported with File > Export > All Tracks as Audio Files: 48 kHz, 24-bit, normalise
off, effects on, the user's fader balance.

| Stem | Logic track | Role |
|---|---|---|
| `bed/drone_city.wav` | Bebop Organ | `drone_city`: the station and the market, fades with depth |
| `bed/drone_deep.wav` | Dark Heavy Bass | `drone_deep`: comes in with depth (the old layer) |
| `bed/pulse.wav` | West Coast Modular | `pulse`: falters when an ánima is straining or dragged back |

No room texture yet (the user approved the bed without one); it can be added as a
fourth stem with role `room`.

## The entrance cue

`cue/enter.wav`: take 3, "under the floor", from `parts/cue_C_2.mid` (written by
`tools/compose_metro_parts.py --piece cue`), chosen by the user on 2026-10-31 and
finished by them in Logic (`~/Music/Logic/metro_score/bed/metro_cue.logicx`):

| Track | Sound and effects |
|---|---|
| 3 Wheels | Vintage Breaks+: Channel EQ, Compressor, Overdrive, ChromaVerb, Pitch Shifter, Distortion; send to the Large Room |
| 3 Brake | Wooden Plank Keys: Multipressor, Channel EQ, AutoFilter; send to the Large Room |
| 3 Rumble | Deep Sub Bass |
| Large Room (bus 12) | ChromaVerb |

A train braking under the floor: the wheels' double clack slows until its last pair
lands on bar 5, where the bed comes in (`lands_bar` 4 in `map.json`: four bars after
the cue starts). Bounced alone, bars 1-7 (20 s, so the tails ring out), WAVE 24-bit
48 kHz, normalise off. The first two takes (tape sink, pressure change) stay in the
Logic project, muted.

## The candle lane

`lane/*.wav`: 16 bars, a slow trip-hop bolero in C Dorian between her and him, composed
by `tools/compose_metro_parts.py --piece lane` (take 5, `parts/lane_C_5.mid`: the trip-hop
groove, every part in its own register, the performance pass, the requinto, the Latin jazz
haunts) and finished by the user in Logic (`~/Music/Logic/metro_score/metro_lane.logicx`):
their sounds and chains, every track's space baked onto it (ChromaVerb room ~20% wet; a
chamber on the trumpet, flute and vibes; their Large Room on her guitar), the sends' aux
returns muted. Exported with Export All Tracks (24-bit, 48 kHz, normalise off, tails on).

| Stem | Logic track | Role |
|---|---|---|
| `sub` | Deep Sub Bass | calm |
| `bass` | Upright Clean | calm (keeps playing when the theme rests) |
| `kit` | Old School+ | calm |
| `keys` | Deluxe Classic | calm |
| `glass` | Toy Celesta | calm |
| `guitar` | Classical Acoustic Guitar (hers) | calm |
| `requinto` | Studio Grand (the user's choice for the lead) | calm |
| `pad` | Classic Pad | calm |
| `trumpet` | Sugar Hill (his) | full |
| `backbeat` | Old School+ (second) | full |
| `pleading` | Mellotron Flute | haunted: pleading |
| `dragged` | Studio Trombone 1 | haunted: dragged |
| `swarm`, `swarm_drums` | Vibraphone, Latin+ | haunted: swarm |

Under the lane the bed keeps only its city drone (Bebop Organ); a haunt brings the deep
drone (Dark Heavy Bass) back; the pulse never plays there (the user's call: `bed` and
`haunt_bed` in `map.json`). The candle lane, the librarian's shop (until his own theme)
and the chapel play it; every other space is mapped to "" (no theme yet).

## Regenerating the game files

```sh
python3 tools/prepare_place_score.py
```

writes `audio/music/metro/` (score.json, bed.tres, one .tres per theme, the oggs).
Listen to a walk through the candle lane without playing:

```sh
Godot --headless --path . res://tests/diag_place_score_walk.tscn -- \
  --score=res://audio/music/metro/score.json --walk=lane|her|shop|all [--pleading=10] --out=<file.wav>
```
