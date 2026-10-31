# The séance: a new main menu theme

Short design, 2026-10-31. It replaces the *Hasta los huesos* overworld loop as the main menu's music.

## Intent

The user's brief: slow, heavy, theatrical occult jazz-noir at 63 bpm. It is campy and gothic, but played completely straight and genuinely menacing: a grand, sinister séance in a smoky underground cabaret.
- **Drums:** a live drummer drags far behind the beat: a deep thudding kick, a fat cracking snare on two and four, soft ghost notes, a barely-touched hi-hat, dusty tape in a small dark room.
- **Bass:** a fuzz-distorted bass growls a slow chromatic line in E Phrygian: a drone on the flat second, a creeping semitone crawl, a tense tritone detour, then a walk back down so it loops.
- **Rhodes and trumpet:** a dirty tremolo Rhodes plays minor-ninth and altered-dominant chords, and a muted trumpet answers in brief phrases.
- **Theremin:** it swoops and wails with wide vibrato, sliding between notes a semitone apart, unashamedly old horror-film.
- **Voices:**
  - A gothic choir chants wordless, Latin-sounding syllables in low unison, and swells into a full dissonant cry at the tritone.
  - A basso profundo intones on the bass notes.
  - A lone soprano wails high and far away.
  - Hushed whispers drift between the hits.
- **Glockenspiel:** a detuned figure, like a cursed music box, every few bars.
- **Textures:** a low tolling bell, bowed metal, vinyl crackle.
- **Reverb:** dark cathedral reverb on the voices only.

The anti-goal is the Metro feedback ([[music-contemporary-not-generic]]): stock MIDI lines on stock patches. The sound design is part of the writing: bends, expression, tape, drive and space.

## Approaches

1. **Groove first, with voices auditioned alongside (chosen by the user).** Round 1 writes the foundation in full: kit, fuzz bass and Rhodes. It adds short audition clips for the theremin, choir, profundo, soprano and glockenspiel. Round 2 writes the rest against the sounds the user picked. The jingles come last.
2. **All parts at once,** on stand-in sounds. Fastest to a first listen, but parts get rewritten once the real sounds are chosen.
3. **Sounds first,** then the parts. Safest for the voices, but nothing to judge musically until round 2.

## The frame

- **63 bpm, 4/4, E Phrygian,** at its true tempo. The menu has its own frame in its `map.json`, apart from the Metro's 72.
- **The loop: 16 bars in 4-bar phrases** (61 s; 15.2 s a phrase). Claude's call: the old loop's 8 bars at 63 would be only 30 s, and a menu is listened to for long stretches.
- **Chord plan,** two bars each (Claude's call, to be judged by ear in round 1). The bass carries the brief's line through it.

| Bars | Chord | The bass |
|---|---|---|
| 1–2 | Em7♭9 | home on E, grinding on the flat second F |
| 3–4 | Fmaj7♯11 | the flat second |
| 5–6 | Gm9 | the semitone crawl F, F♯, G |
| 7–8 | B♭7alt | the tritone detour; the choir's full cry |
| 9–10 | Am9 | the walk back down begins |
| 11–12 | Gm9 | down |
| 13–14 | Fmaj7♯11 | down |
| 15–16 | F7♯11 | the altered dominant (B7's tritone substitute), falling a semitone back onto E |

The loop has six distinct chords, and each word gets a hover and a press jingle in each of them.

## The menu's layers

The menu's layers keep their meaning (`scripts/Audio/MenuMusic.gd`):
- base and low play on the menu;
- idle drops the low layer and lowers the base;
- Lore adds fx;
- the archetype screen brings in the high layer;
- a hovered word's own instrument leans forward, and its jingles come from that instrument.

| Layer | Stems |
|---|---|
| base | fuzz bass, tremolo Rhodes, low choir (chant and the tritone cry), vinyl crackle |
| low | the kit, the tolling bell |
| high (one per word) | New Game: muted trumpet. Continue: theremin. Settings: basso profundo. Lore: the cursed glockenspiel. |
| fx (Lore) | far soprano, whispers, bowed metal |

This mapping is Claude's call, and the user can move any stem in Logic or in `map.json`.

## How it gets made

- **Logic project:** the user's new one, `~/Music/Logic/Untitled.logicx`. The workflow is the Metro's:
  - Claude writes the MIDI;
  - the user imports it;
  - sounds and effects are set up together, with the reverb baked into the stems;
  - the user exports all tracks;
  - Claude prepares the game files.
- **New source folder:** `assets/audio/source/menu_seance/`, holding `map.json`, `parts/`, a README and stems that are never committed. `tools/prepare_menu_score.py --source` reads it. The *Hasta los huesos* source in `menu_theme/` stays as it is, so the old theme can still be prepared again.
- **Composition:** a new `tools/compose_seance_parts.py`, with pieces `groove`, `audition`, `voices` and `jingles`. It needs the MIDI controls (pitch bend, bend range, CC1, CC11 and CC74) and the humanising performance pass, both built on the metro-score branch. The controls come over by cherry-picking 58ccb598 (`tools/menu_midi.py`). The performance pass moves into a shared `tools/midi_perform.py` (Claude's call), and metro-score can import it once the branches meet.
- **The drag:** the drummer's lateness is written into the MIDI, not quantised away. Snare and kick sit a little late, hats looser still, and ghost notes are soft and uneven. The bass and Rhodes sit on the beat, so the drag reads against them.
- **Gaps:**
  - Logic's choirs sing vowels only, so the Latin-sounding syllables need a choir library or an Alchemy formant patch.
  - Logic has no whispers, so they come from recordings: the NOX voice pack if it has them, or a source the user picks.
- **One code change:** the jingles' echo (`ECHO_MS = 577`, a dotted eighth at 78 bpm) becomes the score's own dotted eighth, 714 ms at 63, read from the score's bpm, with a test that fails first.

## Done looks like

1. Round 1: the user approves the groove's feel and picks the voices.
2. Round 2: the user approves the full arrangement.
3. The jingles, written and approved.
4. The user's export is prepared into `audio/music/menu/`, the menu suites pass, and the user hears it on the real menu: hover, press, Lore, the archetype screen, idle and leaving on a phrase line.

## Left to the builder

Voicings, the exact bass line within the chord plan, the trumpet's and theremin's phrases, the glockenspiel's figure, and how the choir's cry is built. All are judged by the user's ear in each round.
