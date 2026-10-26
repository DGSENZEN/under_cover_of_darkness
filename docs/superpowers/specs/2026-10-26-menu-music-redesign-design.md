# Menu music redesign (piece 2 of 4)

Date: 2026-10-26. Status: design for approval.

This revises the music part of `2026-10-25-main-menu-overhaul-design.md`.

## Why

When the user played the menu, the jingles didn't fit the song's mix, and every part seemed to do its own thing. The jingles were cut from each word's own instrument stem, so they carried the arrangement and fought it.

The user wants:
- the layers to follow the menu's screens
- the jingles to be one voice that sits *inside* the music: a glockenspiel or piano in the chord, delayed and reverbed

## Decided with the user

**Layers by screen.** The song is still the user's 8-bar loop; no new music.

| Screen | Layers |
|---|---|
| Main menu: arriving, browsing, idle | base + low |
| Continue | base + low |
| Settings | base + low |
| Lore | base + low + fx |
| Archetype screen (after New Game, piece 3) | base + low + high |

- The menu starts on base + low at once. There's no four-bar build and no arrival cue for now; a cue still plays if a map names one.
- fx and high no longer rise just from moving around the menu. The selected word's instrument no longer leans forward either, because high is silent on the main menu.
- Changes between screens glide, as now (24 dB/s).
- Idle keeps its quieter floor after 30 s untouched (base −10 dB, low out).

**Jingles: glockenspiel on hover, piano on press.**
- **Motifs:** each word has its own short motif, written as MIDI for each of the loop's four chords (Dm9, Bbmaj7#11/C#, Gm9, Ebmaj7#11), with two variants each.
  - hover: 1–3 glockenspiel notes, about ½ beat
  - press: 3–5 piano notes, about 1½ beats
- **Source:** the user loads the motifs onto a Glockenspiel and a piano track in Logic. They're exported dry, without effects, and cut by the existing tool from those two stems (`file`/`cut` entries in `map.json`).
- **Timing:** unchanged. Hover plays on the same frame in the chord sounding now; press plays on the next eighth note.

**Effects in the game ("A").** All jingles play on a new `MenuJingles` bus, which sends to `Music`.
- **Delay:** feedback echoes on a dotted eighth (0.577 s at 78 bpm), wet about −12 dB, feedback about 30%, high frequencies rolled off.
- **Reverb:** a long room, wet about 35%, damped.
- **Level:** about −6 dB under the song, set by ear.
- **Voices:** up to 3 hovers at once, so echoes may ring under the next one; 1 press voice per word.

Exact effect settings are tuned by ear with the user.

## Approaches

- **Dry jingles with the game's effects (chosen).** The echoes ring past the next selection, and the amounts can be tuned live.
- **Effects baked in Logic (rejected).** The tails get cut at each jingle's end and at every new hover, and any change means re-exporting.

## Changes in the code

- `MenuMusic`:
  - the targets follow the table above
  - a new `ARCHETYPE` state (base + low + high)
  - activity no longer drives high, and the lean is removed
  - jingle voices go to `MenuJingles`
- `Sfx._ensure_buses` stays untouched. The menu creates `MenuJingles` itself when it's missing, along with its effects.
- The suites update their layer table and add the bus and effects checks.

## Left to the builder

- The motifs' notes: chord tones, a distinct contour per word, and the press motifs resolving inside the chord.
- How many variants: two per chord unless the user wants more.
- Tool tweaks if the jingle stems need them.
