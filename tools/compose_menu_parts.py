#!/usr/bin/env python3
"""Write new parts for the menu theme: python3 tools/compose_menu_parts.py [--out PATH]

Over the user's 8-bar sketch (hasta_los_huesos_overworld, 78 bpm, two bars
per chord: Dm9 | Bbmaj7#11/C# | Gm9 | Ebmaj7#11) this writes one MIDI file,
two passes long (16 bars, matching the sketch's piano region), with a track
per part for Logic's File > Import > MIDI File. Instruments are only
suggestions (General MIDI programs); the user picks the real ones.

  High layer, one instrument per menu word (they play together):
    Trumpet (muted)   New Game  — the melody, noir, sparse
    Nylon Guitar      Continue  — bolero accompaniment, thumb and fingers
    Rhodes            Settings  — lazy trip-hop comping, behind the beat
    Bells             Lore      — two-note figures with tritones, very high
  Base:  Montuno Piano — a quiet guajeo under the sketch's rolled chords
  Low:   Latin Percussion — conga tumbao, güiro, maracas, swung
  FX:    Choir — long ooh tones;  Drone — D pedal and its fifth

It also writes parts/trip_hop_drums.mid: a new trip-hop kit part to replace
the sketch's drum loop (General MIDI drum map, for a Drum Machine Designer
kit such as Mixed Boom Bap).
"""
import argparse
import json
from pathlib import Path
import random
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from menu_midi import write_song  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/source/menu_theme/parts/menu_parts.mid'
DRUMS_OUT = ROOT / 'assets/audio/source/menu_theme/parts/trip_hop_drums.mid'
JINGLES_OUT = ROOT / 'assets/audio/source/menu_theme/parts/menu_jingles.mid'
JINGLES_TABLE = ROOT / 'assets/audio/source/menu_theme/parts/menu_jingles.json'
BPM = 78
BARS = 8
PASSES = 2
# Two bars per chord, as the sketch's piano and bass play them.
CHORDS = ['Dm9', 'Bbmaj7#11/C#', 'Gm9', 'Ebmaj7#11']
SWING = 0.04  # beats an off-beat eighth lands late (trip-hop lilt)


def bars(n):
    return n * 4.0


def trumpet():
    """Muted trumpet: a lyrical line that leans on each chord's colour tone."""
    line = [
        # Dm9: rise to the 9th
        (1.5, .5, 69, 72), (2.0, .5, 72, 76), (2.5, 1.5, 76, 84),
        (4.0, .75, 74, 80), (4.75, .25, 72, 70), (5.0, 2.0, 69, 74),
        # Bbmaj7#11 over C#: lean on the #11 (E), fall away
        (8.5, .5, 74, 78), (9.0, 1.5, 76, 86), (10.5, .5, 74, 76), (11.0, 1.0, 69, 74),
        (12.0, 2.5, 65, 70), (15.0, .5, 69, 72), (15.5, .5, 70, 76),
        # Gm9: answer, with a bolero triplet turn
        (16.0, 1.5, 74, 84), (17.5, .5, 70, 74), (18.0, 1.0, 69, 76), (19.0, 1.0, 67, 72),
        (20.0, 1 / 3, 65, 68), (20 + 1 / 3, 1 / 3, 67, 70), (20 + 2 / 3, 1 / 3, 69, 74), (21.0, 2.5, 74, 82),
        # Ebmaj7#11: the eerie #11 (A), then home to D for the loop
        (24.5, .5, 70, 74), (25.0, 2.0, 69, 80), (27.0, .5, 67, 70), (27.5, .5, 70, 74),
        (28.0, 3.0, 74, 78),
    ]
    return line


GUITAR = {  # thumb (root, fifth), fingers (upper chord)
    'Dm9': ((50, 45), (53, 57, 60, 64)),
    'Bbmaj7#11/C#': ((46, 53), (57, 62, 64, 65)),
    'Gm9': ((43, 50), (58, 62, 65, 69)),
    'Ebmaj7#11': ((51, 46), (55, 58, 62, 69)),
}


def guitar():
    """Bolero: thumb on 1 and 3, fingers on 2, 2&, 4, 4& (a little rolled)."""
    notes = []
    for i, chord in enumerate(CHORDS):
        thumb, fingers = GUITAR[chord]
        for bar in range(2):
            at = bars(i * 2 + bar)
            notes.append((at, 1.0, thumb[0], 66))
            notes.append((at + 2.0, 1.0, thumb[1], 58))
            for beat, vel in ((1.0, 56), (1.5, 50), (3.0, 56), (3.5, 50)):
                upper = fingers[1:] if beat % 1 else fingers[:3]
                for k, pitch in enumerate(upper):
                    notes.append((at + beat + k * 0.02, 0.45, pitch, vel - k * 3))
    return notes


RHODES = {
    'Dm9': (60, 64, 65, 69),
    'Bbmaj7#11/C#': (62, 64, 65, 69),
    'Gm9': (57, 58, 62, 65),
    'Ebmaj7#11': (55, 57, 58, 62),
}


def rhodes():
    """Behind the beat: a lazy chord on 1&, a push on 4&, a second touch on 3 of bar two."""
    notes = []
    for i, chord in enumerate(CHORDS):
        at = bars(i * 2)
        for start, length, vel in ((0.5, 2.5, 60), (3.5, 0.5, 48), (6.0, 1.5, 54)):
            for k, pitch in enumerate(RHODES[chord]):
                notes.append((at + start + k * 0.015, length, pitch, vel - k * 2))
    return notes


def bells():
    """Two notes falling at the end of each chord's first bar, one answer in its second.
    Over Bb and Eb the pair is a tritone."""
    figures = {
        'Dm9': (88, 81, 86),
        'Bbmaj7#11/C#': (88, 82, 81),
        'Gm9': (86, 79, 81),
        'Ebmaj7#11': (81, 87, 86),
    }
    notes = []
    for i, chord in enumerate(CHORDS):
        at = bars(i * 2)
        a, b, answer = figures[chord]
        notes += [(at + 3.0, 0.5, a, 54), (at + 3.5, 0.5, b, 48), (at + 6.0, 2.0 if i == 3 else 1.0, answer, 50)]
    return notes


MONTUNO = {
    'Dm9': (65, 69, 72, 76),
    'Bbmaj7#11/C#': (65, 69, 74, 76),
    'Gm9': (65, 69, 70, 74),
    'Ebmaj7#11': (67, 69, 70, 74),
}


def montuno():
    """A soft two-bar guajeo in octaves, walking the chord's upper tones."""
    onsets = [0, 1, 1.5, 2.5, 3, 4.5, 5, 6, 6.5, 7.5]
    walk = [0, 1, 2, 1, 3, 2, 1, 2, 3, 1]
    notes = []
    for i, chord in enumerate(CHORDS):
        tones = MONTUNO[chord]
        for onset, step in zip(onsets, walk):
            pitch = tones[step]
            vel = 58 if onset % 1 == 0 else 50
            notes += [(bars(i * 2) + onset, 0.4, pitch, vel), (bars(i * 2) + onset, 0.4, pitch - 12, vel - 8)]
    return notes


def percussion():
    """Conga tumbao (slap on 2, opens on 4 and 4&, low on 3& every other bar),
    güiro long-short, maracas on eighths: General MIDI drum notes, channel 10."""
    notes = []
    for bar in range(BARS):
        at = bars(bar)
        notes += [(at + 1.0, .25, 62, 64), (at + 3.0, .25, 63, 70), (at + 3.5, .25, 63, 62)]
        if bar % 2:
            notes.append((at + 2.5, .25, 64, 58))
        notes += [(at + 0.0, .5, 74, 46), (at + 2.0, .5, 74, 42), (at + 1.5, .2, 73, 40), (at + 3.5, .2, 73, 40)]
        for k in range(8):
            notes.append((at + k * 0.5, .2, 70, 34 if k % 2 == 0 else 44))
    return notes


KICK, RIM, SNARE, HAT, HAT_OPEN = 36, 37, 38, 42, 46
# Layers for punch: a deeper kick under the kick, a clap under the backbeat.
KICK_LOW, CLAP = 35, 39


def drums():
    """Trip-hop: a heavy backbeat on 2 and 4 (snare with a clap under it) that
    sits a hair late, a broken kick doubled by a deeper one, quiet swung
    sixteenth hats so the hits punch through, ghost snares, and an open hat
    and small fill closing each four bars."""
    kicks = [[(0.0, 127), (1.75, 96), (2.5, 118)],
             [(0.0, 127), (2.25, 100), (2.75, 114), (3.75, 76)]]
    ghosts = [[(2.25, 30), (3.75, 26)], [(1.75, 30), (3.25, 28)]]
    notes = []
    for bar in range(BARS):
        at = bars(bar)
        phrase_end = bar % 4 == 3
        for beat, vel in kicks[bar % 2]:
            if not (phrase_end and beat == 3.75):
                notes.append((at + beat, 0.25, KICK, vel))
                notes.append((at + beat, 0.25, KICK_LOW, vel - 14))
        for beat in (1.0, 3.0):
            notes.append((at + beat + 0.012, 0.25, SNARE, 127 if beat == 3.0 else 124))
            notes.append((at + beat + 0.012, 0.25, CLAP, 92))
        for beat, vel in ghosts[bar % 2]:
            notes.append((at + beat, 0.2, SNARE, vel))
        for k in range(16):
            beat = k * 0.25
            if phrase_end and beat >= 3.5:
                break
            # Downbeats lead, eighths answer, sixteenths whisper; swing the sixteenths.
            vel = 62 if k % 4 == 0 else 46 if k % 2 == 0 else 28 + (k * 7) % 10
            notes.append((at + beat + (0.035 if k % 2 else 0.0), 0.2, HAT, vel))
        notes.append((at + 2.75, 0.2, RIM, 38))
        if phrase_end:
            notes += [(at + 3.5, 0.5, HAT_OPEN, 58), (at + 3.25, 0.2, KICK, 108), (at + 3.25, 0.2, KICK_LOW, 94),
                      (at + 3.5, 0.2, SNARE, 46), (at + 3.75, 0.2, SNARE, 60)]
    return notes


def choir():
    """Long 'ooh' tones over each chord: the colour that makes it uncanny."""
    tops = [(69, 74), (69, 76), (70, 74), (69, 74)]
    return [(bars(i * 2), 8.0, p, 50) for i, pair in enumerate(tops) for p in pair]


def drone():
    """D and A, low, under everything: against Eb it rubs (the occult b9)."""
    return [(0.0, bars(4), 38, 52), (0.0, bars(4), 45, 44), (bars(4), bars(4), 38, 52), (bars(4), bars(4), 45, 44)]


PARTS = [
    ('Trumpet (New Game)', trumpet, 0, 59),
    ('Nylon Guitar (Continue)', guitar, 1, 24),
    ('Rhodes (Settings)', rhodes, 2, 4),
    ('Bells (Lore)', bells, 3, 8),
    ('Montuno Piano', montuno, 4, 0),
    ('Latin Percussion', percussion, 9, None),
    ('Choir (FX)', choir, 5, 52),
    ('Drone (FX)', drone, 6, 89),
]


def humanize(notes, rng, swing):
    out = []
    for start, length, pitch, vel in notes:
        if swing and abs((start * 2) % 2 - 1) < 1e-6:
            start += SWING
        start = max(0.0, start + rng.uniform(-0.008, 0.008))
        out.append((round(start, 4), round(length, 4), pitch, max(1, min(127, vel + rng.randint(-4, 4)))))
    return out


# The menu's jingles: each word's own motif in each of the loop's chords.
# Chord tones stacked up from the root (semitones): 9ths for the minor
# chords, the #11 on top of the major-seventh ones.
JINGLE_CHORDS = [('Dm', 2, (0, 3, 7, 10, 14)), ('Bb', 10, (0, 4, 7, 11, 18)),
                 ('Gm', 7, (0, 3, 7, 10, 14)), ('Eb', 3, (0, 4, 7, 11, 18))]
# Which stacked tones each word plays, and when (beats): New Game rises
# root-5th-top, Continue answers 3rd-7th, Settings rings one tone and its
# octave, Lore falls from the top through the 7th to the 5th.
HOVER_SHAPES = [((0, 2, 4), (0.0, 0.125, 0.25)), ((1, 3), (0.0, 0.25)),
                ((2, 7), (0.0, 0.125)), ((4, 3, 2), (0.0, 0.125, 0.25))]
SLOT_BEATS = 8.0
HOVER_BEATS, PRESS_BEATS = 2.0, 4.0


def _tone(root, stack, step):
    """The step-th tone of a chord stacked upward, past the top in octaves."""
    octave, i = divmod(step, len(stack))
    return root + stack[i] + 12 * octave


def jingles():
    """Glockenspiel hover motifs and piano press motifs, one per 2-bar slot,
    in order word / chord / variant; returns the two parts and the slot table."""
    hover, press, table = [], [], []
    slot = 0
    for word, (steps, times) in enumerate(HOVER_SHAPES):
        for chord, pc, stack in JINGLE_CHORDS:
            for variant in (0, 1):
                at = slot * SLOT_BEATS
                lift = variant  # the second variant starts one chord tone higher
                glock_root = 72 + pc
                for step, t in zip(steps, times):
                    hover.append((at + t, 0.5, _tone(glock_root, stack, step + lift), 72))
                piano_root = 60 + pc
                for k, step in enumerate(steps):
                    press.append((at + k * 0.5, 0.45, _tone(piano_root, stack, step + lift), 66))
                # Resolve inside the chord: root and 3rd above (the 5th too on the bII).
                close = (0, 1, 2) if chord == 'Eb' else (0, 1)
                for step in close:
                    press.append((at + 1.5, 1.5, _tone(piano_root + 12, stack, step), 58))
                table += [dict(button=word, kind='hover', chord=chord, variant=variant, start_beat=at, beats=HOVER_BEATS),
                          dict(button=word, kind='press', chord=chord, variant=variant, start_beat=at, beats=PRESS_BEATS)]
                slot += 1
    return hover, press, table


# The archetype screen's sounds: each archetype's own two instruments, from
# the song's own band, in each of the loop's chords. Buttons 5-7 in the score
# (after the menu's five words); every hover and confirm has its own slot.
ARCHETYPES_OUT = ROOT / 'assets/audio/source/menu_theme/parts/archetype_jingles.mid'
ARCHETYPES_TABLE = ROOT / 'assets/audio/source/menu_theme/parts/archetype_jingles.json'
ARCHETYPE_SLOT_BEATS = 8.0
ARCHETYPE_HOVER_BEATS, ARCHETYPE_PRESS_BEATS = 3.0, 6.0
# (track, button), with the General MIDI channel and program they ask for.
ARCHETYPE_TRACKS = [('Derive Piano', 5), ('Derive Drums', 5), ('Thaumaturge Glockenspiel', 6),
                    ('Thaumaturge Choir', 6), ('Factotum Rhodes', 7), ('Factotum Trumpet', 7)]
ARCHETYPE_VOICES = {'Derive Piano': (0, 0), 'Derive Drums': (9, None), 'Thaumaturge Glockenspiel': (1, 9),
                    'Thaumaturge Choir': (2, 52), 'Factotum Rhodes': (3, 4), 'Factotum Trumpet': (4, 59)}
CRASH = 49


def _base(octave_c, pc):
    """The chord's root near `octave_c`: the upper keys drop an octave, so
    every chord sits in the same register."""
    return octave_c + pc - (12 if pc >= 7 else 0)


def _derive(hover, at, pc, stack, lift, notes):
    """Body, gut and fists: low piano octaves struck with the trip-hop kick
    and snare: a one-two on hover, a combination ending in a heavy blow on confirm."""
    piano, drums = notes['Derive Piano'], notes['Derive Drums']
    low, mid = _base(36, pc), _base(48, pc)
    if hover:
        piano += [(at, 0.4, low, 100), (at, 0.4, low + 12, 92)]
        drums += [(at, 0.25, KICK, 120), (at, 0.25, KICK_LOW, 106)]
        fifth = _tone(mid, stack, 2 + lift)
        piano += [(at + 0.5, 0.4, fifth, 96), (at + 0.5, 0.4, fifth + 12, 84)]
        drums += [(at + 0.5, 0.25, SNARE, 112), (at + 0.5, 0.25, CLAP, 82)]
    else:
        piano += [(at, 0.25, low, 100), (at, 0.25, low + 12, 92)]
        drums += [(at, 0.25, KICK, 118), (at, 0.25, KICK_LOW, 104), (at + 0.25, 0.25, KICK, 100)]
        piano += [(at + 0.5, 0.35, _tone(mid, stack, s + lift), 94) for s in (0, 2, 4)]
        drums += [(at + 0.5, 0.25, SNARE, 116), (at + 0.5, 0.25, CLAP, 86)]
        piano += [(at + 1.0, 3.0, low, 118), (at + 1.0, 3.0, low + 12, 108)]
        piano += [(at + 1.0, 3.0, _tone(mid + 12, stack, s), 80) for s in (1, 2, 4)]
        drums += [(at + 1.0, 0.25, KICK, 127), (at + 1.0, 0.25, KICK_LOW, 120), (at + 1.0, 1.0, CRASH, 96)]


def _thaumaturge(hover, at, pc, stack, lift, notes):
    """People and the occult: a glockenspiel that hangs over a choir's
    breath: two tones on hover, a rising triplet spell over a swelling chord on confirm."""
    glock, choir = notes['Thaumaturge Glockenspiel'], notes['Thaumaturge Choir']
    high, voices = _base(72, pc), _base(60, pc)
    if hover:
        glock += [(at, 0.6, _tone(high, stack, 4 + lift), 70), (at + 0.375, 0.9, _tone(high, stack, 2 + lift), 62)]
        choir.append((at, 2.0, _tone(voices, stack, 1 + lift), 46))
    else:
        choir += [(at, 4.5, _tone(voices, stack, s), 58) for s in (2, 3, 5, 6)]
        for k in range(6):
            glock.append((at + k / 3.0, 0.5, _tone(high, stack, k + lift), 60 + k * 4))
        glock.append((at + 2.25, 1.5, _tone(high, stack, 7 + lift), 84))


def _factotum(hover, at, pc, stack, lift, notes):
    """Knowledge and experience: quick Rhodes and a muted trumpet that
    answers it: a three-note turn and a blip on hover, a Charleston stab and a
    trumpet phrase on confirm."""
    rhodes, trumpet = notes['Factotum Rhodes'], notes['Factotum Trumpet']
    keys, horn = _base(60, pc), _base(60, pc)
    if hover:
        rhodes += [(at + k * 0.25, 0.3, _tone(keys, stack, s + lift), 70) for k, s in enumerate((1, 2, 3))]
        trumpet.append((at + 0.75, 0.25, _tone(horn, stack, 4 + lift), 62))
    else:
        for t, length in ((0.0, 0.6), (0.75, 2.5)):
            rhodes += [(at + t, length, _tone(keys - 12, stack, s), 72) for s in (1, 3, 4)]
        for t, length, s, vel in ((1.0, 0.22, 2, 70), (1.25, 0.22, 3, 66), (1.5, 0.4, 4, 74), (2.0, 1.8, 6, 80)):
            trumpet.append((at + t, length, _tone(horn, stack, s + lift), vel))


def archetype_jingles():
    """Every archetype's hover and confirm in each chord and variant, one
    slot each; returns the parts (one per instrument) and the slot table."""
    notes = {name: [] for name, _ in ARCHETYPE_TRACKS}
    table = []
    slot = 0
    for button, voice in ((5, _derive), (6, _thaumaturge), (7, _factotum)):
        for kind in ('hover', 'press'):
            for chord, pc, stack in JINGLE_CHORDS:
                for variant in (0, 1):
                    at = slot * ARCHETYPE_SLOT_BEATS
                    voice(kind == 'hover', at, pc, stack, variant, notes)
                    beats = ARCHETYPE_HOVER_BEATS if kind == 'hover' else ARCHETYPE_PRESS_BEATS
                    table.append(dict(button=button, kind=kind, chord=chord, variant=variant, start_beat=at, beats=beats))
                    slot += 1
    parts = [{'name': name, 'channel': ARCHETYPE_VOICES[name][0], 'program': ARCHETYPE_VOICES[name][1],
              'notes': sorted(notes[name])} for name, _ in ARCHETYPE_TRACKS]
    return parts, table


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=OUT)
    args = parser.parse_args()
    rng = random.Random(1923)
    parts = []
    for name, make, channel, program in PARTS:
        one = make()
        notes = [(s + bars(BARS) * p, l, n, v) for p in range(PASSES) for s, l, n, v in one]
        swing = make in (guitar, montuno, percussion)
        parts.append({'name': name, 'channel': channel, 'program': program, 'notes': humanize(notes, rng, swing)})
    args.out.parent.mkdir(parents=True, exist_ok=True)
    write_song(args.out, BPM, parts)
    print(f'wrote {args.out}: {len(parts)} parts, {BARS * PASSES} bars at {BPM} bpm')
    beat = [(s + bars(BARS) * p, l, n, v) for p in range(PASSES) for s, l, n, v in drums()]
    write_song(DRUMS_OUT, BPM, [{'name': 'Trip-Hop Drums', 'channel': 9, 'notes': humanize(beat, rng, False)}])
    print(f'wrote {DRUMS_OUT}')
    hover, press, table = jingles()
    write_song(JINGLES_OUT, BPM, [{'name': 'Glockenspiel (hover)', 'channel': 0, 'program': 9, 'notes': hover},
                                  {'name': 'Piano (press)', 'channel': 1, 'program': 0, 'notes': press}])
    JINGLES_TABLE.write_text(json.dumps(table, indent=1) + '\n')
    print(f'wrote {JINGLES_OUT}: {len(table)} jingles in {len(table) // 2} slots')
    parts, table = archetype_jingles()
    write_song(ARCHETYPES_OUT, BPM, parts)
    ARCHETYPES_TABLE.write_text(json.dumps(table, indent=1) + '\n')
    print(f'wrote {ARCHETYPES_OUT}: {len(table)} archetype jingles, one slot each')


if __name__ == '__main__':
    main()
