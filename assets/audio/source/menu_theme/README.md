# Menu theme source

Placeholder stems exported from the user's Logic project `~/Music/Logic/hasta_los_huesos_overworld.logicx` on 2026-10-25. They were exported with File > Export > All Tracks as Audio Files: WAVE, 24-bit, 48 kHz, normalisation off, trimmed at the file end, starting at bar 1. The project was not edited.

| Stem | Logic track | Layer |
|---|---|---|
| `stems/piano.wav` | Deluxe Classic (Studio Grand) | base |
| `stems/bass.wav` | Big Stadium Bass ("Simple Foundation") | base |
| `stems/drums.wav` | Back in the Day Beat (mono audio loop) | low |

`map.json` loops the first 8 bars at 78 bpm in 4-bar phrases. That is where all three parts play. The piano part runs to about bar 11.

The chords were estimated from the piano and bass audio, bar by bar, and still need confirming by ear:

| Bars | Chord |
|---|---|
| 1–4 | Dm (C# in the bass in bars 3–4) |
| 5–6 | Gm over D |
| 7 | E♭ over D |
| 8 | Dm |

The placeholder jingles are slices of the piano on each chord. Each word gets its own moment, with two variants per chord. The real jingles replace them in Part C of `docs/superpowers/plans/2026-10-25-main-menu-overhaul.md`.

The WAVs are working masters and are not committed, as with `../hasta_los_huesos`. To regenerate the game files:

```sh
python3 tools/prepare_menu_score.py
```
