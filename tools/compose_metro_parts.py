#!/usr/bin/env python3
"""Write the Metro score's MIDI parts for Logic: python3 tools/compose_metro_parts.py --piece bed [--bpm 72] [--pedal C] [--take 1]

One format-1 file per take, assets/audio/source/metro_score/parts/<piece>_<pedal>_<take>.mid,
for File > Import > MIDI File into the Logic project (docs/superpowers/specs/2026-10-31-metro-score-design.md).
Every part is judged by ear in Logic: these are starting points, not the music.

  bed   the Metro's spine, 16 bars: the city drone (the pedal and its octave, re-struck each
        phrase), the deep drone (the pedal an octave down and its fifth), and the pulse
        (a soft kick on each downbeat and a ghost on 3&, swung 58 %). The room texture is a
        Logic patch, not MIDI.
  cue   the entrance: two bars that land on the bed's first downbeat (bar 3), three
        takes on their own tracks, all from bar 1 (mute the others to hear one):
          A  falling away: a bell line down C minor from the top, over an organ chord that
             turns from Cm(add9) to Abmaj7 over C
          B  the street above: a barrel-organ waltz figure, heard three times, each an
             octave lower and quieter, as if going down the stairs away from it
          C  breath in: a soft repeated fifth swelling to the held breath before the land,
             a high D left in the air
"""
import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from menu_midi import pitch_class, write_song  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio/source/metro_score/parts'
BARS = 16
PHRASE_BARS = 4
BEATS = 4
# 58 % swing: an eighth's offbeat lands at 0.58 of its beat instead of 0.5.
SWING = 0.08
KICK, GHOST = 36, 37


def bed(pedal):
    """The bed's parts on a pedal ('C', 'Bb', ...): [{'name', 'channel', 'program', 'notes'}]."""
    pc = pitch_class(pedal)
    low = 36 + pc if pc <= 7 else 24 + pc
    phrase = PHRASE_BARS * BEATS
    city, deep, pulse = [], [], []
    for p in range(BARS // PHRASE_BARS):
        at = p * phrase
        # Re-struck each phrase so a pad's attack marks the line; held to its end.
        city += [(at, phrase, low + 12, 58), (at, phrase, low + 24, 40)]
        deep += [(at, phrase, low, 64), (at + 0.5, phrase - 0.5, low + 7, 44)]
    for bar in range(BARS):
        at = bar * BEATS
        pulse.append((at, 0.5, KICK, 70))
        pulse.append((at + 2.5 + SWING, 0.25, GHOST, 34))
    return [{'name': 'Drone (city)', 'channel': 0, 'program': 89, 'notes': city},
            {'name': 'Drone (deep)', 'channel': 1, 'program': 95, 'notes': deep},
            {'name': 'Pulse', 'channel': 9, 'notes': pulse}]


def cue(pedal):
    """The entrance cue's three takes, two bars from bar 1, landing on bar 3."""
    c = pitch_class(pedal)
    land = 2 * BEATS
    # A: down the C minor scale from the top, one step a beat, the last held into the land.
    steps = [12, 10, 8, 7, 5, 3, 2]
    bells = [(beat, 1.0, 72 + c + step, 78 - 4 * beat) for beat, step in enumerate(steps)]
    bells.append((7.0, 3.0, 60 + c + 12, 52))
    pad = [(0.0, 4.0, n, 50) for n in (48 + c, 51 + c, 55 + c, 62 + c)]
    pad += [(4.0, 4.5, n, 38) for n in (44 + c, 48 + c, 51 + c, 55 + c)]
    # B: a waltz turn (G C Eb D C), from high and loud to low and faint.
    figure = [(0.0, 7), (0.5, 12), (1.0, 15), (1.5, 14), (2.0, 12)]
    street = []
    for i, (octave, vel) in enumerate(((72, 74), (60, 54), (48, 36))):
        at = i * 8.0 / 3.0
        street += [(at + t, 0.45, octave + c + n - 12, vel) for t, n in figure if at + t < land - 0.2]
    street.append((land - 0.5, 2.5, 36 + c, 40))
    # C: sixteenths on the fifth, swelling, cut a sixteenth before the land; a high D hangs on.
    swell = []
    for k in range(int((land - 0.25) * 4)):
        vel = int(18 + 82 * (k / ((land - 0.25) * 4)) ** 2)
        swell += [(k * 0.25, 0.22, 55 + c, vel), (k * 0.25, 0.22, 60 + c, max(1, vel - 10))]
    air = [(0.0, land + 1.0, 74 + c, 30)]
    return [{'name': 'A Bells', 'channel': 0, 'program': 14, 'notes': bells},
            {'name': 'A Organ', 'channel': 1, 'program': 19, 'notes': pad},
            {'name': 'B Street organ', 'channel': 2, 'program': 20, 'notes': street},
            {'name': 'C Swell', 'channel': 3, 'program': 49, 'notes': swell},
            {'name': 'C Air', 'channel': 4, 'program': 88, 'notes': air}]


PIECES = {'bed': bed, 'cue': cue}


def write_piece(piece, bpm, pedal, take, out=OUT):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    path = out / f'{piece}_{pedal}_{take}.mid'
    write_song(path, bpm, PIECES[piece](pedal))
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--piece', choices=sorted(PIECES), required=True)
    parser.add_argument('--bpm', type=float, default=72.0)
    parser.add_argument('--pedal', default='C')
    parser.add_argument('--take', type=int, default=1)
    parser.add_argument('--out', type=Path, default=OUT)
    args = parser.parse_args()
    path = write_piece(args.piece, args.bpm, args.pedal, args.take, args.out)
    print(f'wrote {path}')


if __name__ == '__main__':
    main()
