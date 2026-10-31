#!/usr/bin/env python3
"""Write the Metro score's MIDI parts for Logic: python3 tools/compose_metro_parts.py --piece bed [--bpm 72] [--pedal C] [--take 1]

One format-1 file per take, assets/audio/source/metro_score/parts/<piece>_<pedal>_<take>.mid,
for File > Import > MIDI File into the Logic project (docs/superpowers/specs/2026-10-31-metro-score-design.md).
Every part is judged by ear in Logic: these are starting points, not the music.

  bed   the Metro's spine, 16 bars: the city drone (the pedal and its octave, re-struck each
        phrase), the deep drone (the pedal an octave down and its fifth), and the pulse
        (a soft kick on each downbeat and a ghost on 3&, swung 58 %). The room texture is a
        Logic patch, not MIDI.
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


PIECES = {'bed': bed}


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
