# Menu theme source

These are the menu theme's stems, exported on 2026-10-25 from the user's Logic project `~/Music/Logic/hasta_los_huesos_overworld.logicx`, after the user's own changes. They are 48 kHz WAVs from File > Export > All Tracks as Audio Files, with normalisation off, the user's fader balance, and starting at bar 1.

| Stem | Logic track | Layer | Word |
|---|---|---|---|
| `stems/piano.wav` | Deluxe Classic (the sketch's Studio Grand) | base | |
| `stems/bass.wav` | Big Stadium Bass | base | |
| `stems/montuno.wav` | Studio Grand (Montuno Piano) | base | |
| `stems/drums.wav` | Vintage Cinema (Trip-Hop Drums) | low | |
| `stems/percussion.wav` | SoCal (Latin Percussion) | low | |
| `stems/trumpet.wav` | Sugar Hill (Trumpet) | high | New Game |
| `stems/guitar.wav` | Classical Acoustic Guitar | high | Continue |
| `stems/rhodes.wav` | Deluxe Classic (Rhodes) | high | Settings |
| `stems/bells.wav` | Toy Celesta (Bells) | high | Lore |
| `stems/choir.wav` | Mellotron Choir | fx | |
| `stems/drone.wav` | Classic Pad (Drone) | fx | |

The sketch's muted Back in the Day Beat loop is not used. The first placeholder stems (piano, bass and that loop) are kept in `stems_sketch/`.

`map.json` loops the first 8 bars at 78 bpm in 4-bar phrases. Each word's hover and press jingles are cut from that word's own instrument stem. Each one starts on a real note onset of its part (from `parts/menu_parts.mid`), with two variants per chord, and every cut was checked for sound.

The chords, read from the sketch's MIDI (`overworld_sketch.mid`, exported 2026-10-25), last two bars each. The piano rolls every chord up slowly and lets it ring:

| Bars | Chord |
|---|---|
| 1–2 | Dm9 |
| 3–4 | Bbmaj7#11 over C# |
| 5–6 | Gm9 |
| 7–8 | Ebmaj7#11 |

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

`parts/trip_hop_drums.mid`, from the same script, is a new trip-hop kit part. It is on the Mixed Boom Bap kit, track 12, in the Logic project, and the sketch's Back in the Day Beat track is muted:
- a heavy backbeat on 2 and 4, a hair late, with a clap layered under the snare
- a broken kick, doubled by a deeper kick
- swung 16th hats, kept quiet so the hits punch through
- ghost snares and a rim
- an open hat and a small fill at the end of each four bars
