# Menu theme source

Placeholder stems exported from the user's Logic project `~/Music/Logic/hasta_los_huesos_overworld.logicx` on 2026-10-25. They were exported with File > Export > All Tracks as Audio Files: WAVE, 24-bit, 48 kHz, normalisation off, trimmed at the file end, starting at bar 1. The project was not edited.

| Stem | Logic track | Layer |
|---|---|---|
| `stems/piano.wav` | Deluxe Classic (Studio Grand) | base |
| `stems/bass.wav` | Big Stadium Bass ("Simple Foundation") | base |
| `stems/drums.wav` | Back in the Day Beat (mono audio loop) | low |

`map.json` loops the first 8 bars at 78 bpm in 4-bar phrases. That is where all three parts play. The piano part runs to about bar 11.

The chords, read from the sketch's MIDI (`overworld_sketch.mid`, exported 2026-10-25), last two bars each. The piano rolls every chord up slowly and lets it ring:

| Bars | Chord |
|---|---|
| 1–2 | Dm9 |
| 3–4 | Bbmaj7#11 over C# |
| 5–6 | Gm9 |
| 7–8 | Ebmaj7#11 |

The placeholder jingles are slices of the piano on each chord. Each word gets its own moment, with two variants per chord. The real jingles replace them in Part C of `docs/superpowers/plans/2026-10-25-main-menu-overhaul.md`.

The WAVs are working masters and are not committed, as with `../hasta_los_huesos`. To regenerate the game files:

```sh
python3 tools/prepare_menu_score.py
```

## New parts (Part C)

`tools/compose_menu_parts.py` writes `parts/menu_parts.mid`. It holds eight tracks over two passes of the 8 bars, imported into the Logic project on 2026-10-25 for the user to audition:
- High: Trumpet (New Game), Nylon Guitar (Continue), Rhodes (Settings), Bells (Lore)
- Base: Montuno Piano
- Low: Latin Percussion (General MIDI drum notes)
- FX: Choir, Drone

Change the script and re-run it to revise a part.
