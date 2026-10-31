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
