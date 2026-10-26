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
"""
import argparse
from pathlib import Path
import random
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from menu_midi import write_song  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/source/menu_theme/parts/menu_parts.mid'
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


if __name__ == '__main__':
    main()
