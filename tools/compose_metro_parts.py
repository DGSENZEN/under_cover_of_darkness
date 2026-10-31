#!/usr/bin/env python3
"""Write the Metro score's MIDI parts for Logic: python3 tools/compose_metro_parts.py --piece bed [--bpm 72] [--pedal C] [--take 1]

One format-1 file per take, assets/audio/source/metro_score/parts/<piece>_<pedal>_<take>.mid,
for File > Import > MIDI File into the Logic project (docs/superpowers/specs/2026-10-31-metro-score-design.md).
Every part is judged by ear in Logic: these are starting points, not the music.

  bed   the Metro's spine, 16 bars: the city drone (the pedal and its octave, re-struck each
        phrase), the deep drone (the pedal an octave down and its fifth), and the pulse
        (a soft kick on each downbeat and a ghost on 3&, swung 58 %). The room texture is a
        Logic patch, not MIDI.
  cue   the entrance: four bars (a phrase) that land on the bed's first downbeat, bar 5.
        Three takes on their own tracks, all from bar 1 (mute the others to hear one); the
        movement is written in (pitch bend, CC11 expression, CC74 brightness, CC1), the
        rooms and echoes are Logic's (ChromaVerb, Tape Delay) on each track:
          1  tape sink: the street's barrel-organ tune, its notes spreading apart while it
             bends down an octave, as if the tape under the city slowed; a reversed swell
             of the bed's chord rises out of it, and a sub drops onto the land
          2  pressure change: a C Db G Ab cluster on two layers drifting apart (beating),
             air rushing up the tunnel as its filter opens, then everything closes to a
             muffle and cuts on a held breath; glass pings; a sub pressing up from below
          3  under the floor: a train braking below, the wheels' double clack slowing until
             it locks onto the land, a brake squeal bending down over it, a rumble passing
  lane  the candle lane, 16 bars over the bed: a slow bolero in C Dorian, between her and
        him. Cm9 F13 vamping, Abmaj7#11 and G7sus(b9) turning it, a Dbmaj7#11 pulling down.
        Calm: an upright bass on the bolero's step, votive glass chiming its rhythm, a candle pad
        flickering (CC74), her nylon guitar's fills. Full: his harmon trumpet's melody (bars
        1-8, scoops and fall-offs bent in), brushes; her guitar answers it in thirds (9-16).
        Haunts, silent until the anima act: H Pleading (wordless sighs bending down),
        H Dragged (a low slide an octave down), H Swarm (glass trembling in a cluster).
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


CUE_LANDS_BAR = 5


def _ramp(beat0, beat1, kind, v0, v1, steps=24, curve=1.0):
    """A control moving from v0 to v1 between two beats (curve > 1: slow, then fast)."""
    out = []
    for i in range(steps + 1):
        f = i / steps
        out.append((beat0 + (beat1 - beat0) * f, kind, v0 + (v1 - v0) * f ** curve))
    return out


def cue(pedal):
    """The entrance cue's three takes, a phrase from bar 1, landing on bar 5."""
    import math
    c = pitch_class(pedal)
    land = (CUE_LANDS_BAR - 1) * BEATS

    # 1 Tape sink. The street tune (G C Eb D C Bb Ab G), each note further from the last.
    tune = [7, 12, 15, 14, 12, 10, 8, 7, 3, 2, 0]
    organ, at, gap = [], 0.0, 0.42
    for step in tune:
        if at >= land - 1.0:
            break
        organ.append((round(at, 4), gap * 0.9, 60 + c + step, 84))
        at += gap
        gap *= 1.28
    organ_moves = [(0.0, 'bend_range', 12), (0.0, 11, 112), (0.0, 74, 100)]
    # The tape slowing: down an octave, slow then sinking, with a little wow.
    for i in range(65):
        beat = 1.5 + (land - 1.5) * i / 64
        sink = -((i / 64) ** 1.8)
        wow = 0.015 * math.sin(i * 0.9)
        organ_moves.append((beat, 'bend', max(-1.0, sink + wow * (1 + sink))))
    organ_moves += _ramp(land * 0.5, land, 11, 112, 30) + _ramp(2.0, land, 74, 100, 15)
    swell_at = land - 6.0
    swell = [(swell_at, 6.0 - 0.1, n, 80) for n in (48 + c, 55 + c, 62 + c, 63 + c)]
    swell_moves = [(0.0, 11, 0)] + _ramp(swell_at, land - 0.12, 11, 0, 127, 32, 3.0) + [(land - 0.1, 11, 0)]
    sub = [(land - 2.0, 4.0, 36 + c, 110)]
    sub_moves = [(0.0, 'bend_range', 12), (land - 2.0, 'bend', 1.0)] + _ramp(land - 2.0, land + 0.75, 'bend', 1.0, 0.0, 24, 0.5)

    # 2 Pressure change. The cluster held on two layers drifting apart, a few cents each way.
    cluster_notes = (60 + c, 61 + c, 67 + c, 68 + c)
    hold = land - 0.25
    a = [(0.0, hold, n, 70) for n in cluster_notes]
    b = [(0.0, hold, n - 12, 64) for n in cluster_notes]
    closing = _ramp(0.0, 4.0, 11, 0, 100) + _ramp(land - 4.0, hold, 74, 100, 8) + _ramp(land - 3.0, hold, 11, 100, 60)
    a_moves = [(0.0, 'bend_range', 2), (0.0, 74, 100)] + _ramp(0.0, hold, 'bend', 0.0, 0.08) + closing
    b_moves = [(0.0, 'bend_range', 2), (0.0, 74, 100)] + _ramp(0.0, hold, 'bend', 0.0, -0.08) + closing
    air = [(0.0, hold, 72 + c, 90)]
    air_moves = [(0.0, 11, 90)] + _ramp(0.0, land - 4.0, 74, 10, 115, 32, 0.7) + _ramp(land - 4.0, hold, 74, 115, 0, 16)
    air_moves += [(beat * 0.5, 1, int(40 + 40 * math.sin(beat))) for beat in range(int(hold * 2))]
    glass = [(3.25, 0.8, 96 + c, 46), (7.6, 0.8, 91 + c, 38), (11.1, 0.8, 97 + c, 30)]
    pressure_sub = [(land / 2, hold - land / 2, 24 + c, 100)]
    pressure_sub_moves = [(0.0, 11, 0)] + _ramp(land / 2, hold, 11, 0, 120, 24, 1.5)

    # 3 Under the floor. Pairs of clacks (a bogie over a rail joint), the train braking:
    # each pair further from the last, the last pair on the land.
    # (Back from the land: the gaps shrink toward the train's running speed, a pair
    # every quarter beat or so.)
    firsts, gap = [], 1.6
    t = land
    while t >= 0.0:
        firsts.append(t)
        t -= gap
        gap = max(0.3, gap * 0.82)
    firsts.reverse()
    wheels = []
    for i, first in enumerate(firsts):
        spread = 0.16 + 0.14 * (i / max(1, len(firsts) - 1))
        vel = int(50 + 50 * math.sin(math.pi * min(1.0, (i + 1) / len(firsts))))
        wheels.append((round(first, 4), 0.1, 75, max(40, vel)))
        wheels.append((round(first + spread, 4), 0.1, 76, max(34, vel - 12)))
    brake = [(land * 0.35, land * 0.65, 96 + c, 60)]
    brake_moves = [(0.0, 'bend_range', 2), (land * 0.35, 'bend', 0.5)]
    for i in range(64):
        beat = land * 0.35 + land * 0.65 * i / 63
        f = i / 63
        brake_moves.append((beat, 'bend', 0.5 - 1.5 * f ** 1.4 + 0.04 * math.sin(i * 1.7)))
    brake_moves += [(0.0, 11, 0)] + _ramp(land * 0.35, land * 0.6, 11, 0, 90) + _ramp(land * 0.8, land, 11, 90, 0)
    rumble = [(0.0, land + 1.0, 24 + c, 100)]
    rumble_moves = [(0.0, 11, 30)] + _ramp(0.0, land * 0.5, 11, 30, 120) + _ramp(land * 0.5, land + 1.0, 11, 120, 0)
    rumble_moves += _ramp(0.0, land + 1.0, 74, 60, 10)

    return [{'name': '1 Street organ', 'channel': 0, 'program': 20, 'notes': organ, 'controls': organ_moves},
            {'name': '1 Reverse swell', 'channel': 1, 'program': 19, 'notes': swell, 'controls': swell_moves},
            {'name': '1 Sub drop', 'channel': 2, 'program': 38, 'notes': sub, 'controls': sub_moves},
            {'name': '2 Cluster A', 'channel': 3, 'program': 49, 'notes': a, 'controls': a_moves},
            {'name': '2 Cluster B', 'channel': 4, 'program': 49, 'notes': b, 'controls': b_moves},
            {'name': '2 Air', 'channel': 5, 'program': 122, 'notes': air, 'controls': air_moves},
            {'name': '2 Glass', 'channel': 6, 'program': 14, 'notes': glass},
            {'name': '2 Sub', 'channel': 7, 'program': 38, 'notes': pressure_sub, 'controls': pressure_sub_moves},
            {'name': '3 Wheels', 'channel': 9, 'notes': wheels},
            {'name': '3 Brake', 'channel': 10, 'program': 80, 'notes': brake, 'controls': brake_moves},
            {'name': '3 Rumble', 'channel': 11, 'program': 38, 'notes': rumble, 'controls': rumble_moves}]


# C Dorian, one bar each, two passes of eight: (name, chord tones above the root, root pc).
LANE_CHORDS = [('Cm9', 0, (0, 3, 7, 10, 14)), ('F13', 5, (0, 4, 10, 14, 21)), ('Cm9', 0, (0, 3, 7, 10, 14)),
               ('F13', 5, (0, 4, 10, 14, 21)), ('Abmaj7#11', 8, (0, 4, 7, 11, 18)), ('G7sus(b9)', 7, (0, 5, 10, 13, 17)),
               ('Cm9', 0, (0, 3, 7, 10, 14)), ('Cm9', 0, (0, 3, 7, 10, 14)),
               ('Cm9', 0, (0, 3, 7, 10, 14)), ('F13', 5, (0, 4, 10, 14, 21)), ('Cm9', 0, (0, 3, 7, 10, 14)),
               ('F13', 5, (0, 4, 10, 14, 21)), ('Abmaj7#11', 8, (0, 4, 7, 11, 18)), ('Dbmaj7#11', 1, (0, 4, 7, 11, 18)),
               ('Cm9', 0, (0, 2, 7, 10, 15)), ('Cm9', 0, (0, 3, 7, 10, 14))]
# His melody, bars 1-8: (bar, beat, length, semitones above middle C).
LANE_MELODY = [(0, 1.5, 0.5, -5), (0, 2.0, 1.0, -2), (0, 3.0, 1.5, 0),
               (1, 0.5, 0.5, 2), (1, 1.0, 1.0, 3), (1, 2.0, 0.75, 2), (1, 2.75, 1.25, 0),
               (2, 0.0, 2.0, -2), (2, 2.0, 0.5, -3), (2, 2.5, 0.5, -5), (2, 3.0, 1.0, -3),
               (3, 0.0, 3.0, -5),
               (4, 1.0, 0.5, 0), (4, 1.5, 0.5, 2), (4, 2.0, 2.0, 3),
               (5, 0.0, 1.5, 2), (5, 1.5, 0.5, 0), (5, 2.0, 2.0, -4),
               (6, 0.0, 1.0, -5), (6, 1.0, 1.0, -7), (6, 2.0, 2.0, -9),
               (7, 0.0, 3.5, -10)]
DORIAN = (0, 2, 3, 5, 7, 9, 10)


def _third_below(pitch, c):
    """The C Dorian note a diatonic third under `pitch` (itself in the mode)."""
    degree = (pitch - c) % 12
    if degree not in DORIAN:
        return pitch - 3
    i = DORIAN.index(degree)
    below = DORIAN[(i - 2) % 7]
    return pitch - ((degree - below) % 12)


def lane(pedal):
    """The candle lane's theme: 16 bars, calm and full parts, and its three haunts."""
    import math
    import random
    c = pitch_class(pedal)
    rng = random.Random(1924)
    bars = len(LANE_CHORDS)
    end = bars * BEATS

    bass, glass, pad, pad_moves = [], [], [], [(0.0, 11, 96)]
    for bar, (_, root, tones) in enumerate(LANE_CHORDS):
        at = bar * BEATS
        r = 36 + (c + root) % 12
        nxt = 36 + (c + LANE_CHORDS[(bar + 1) % bars][1]) % 12
        # The bolero's step: the root, the fifth on three, a lean into the next root from its fifth below.
        lean = nxt - 5 if nxt - 5 >= 31 else nxt + 7
        bass += [(at, 1.4, r, 92), (at + 2.0, 1.0, r + 7, 78), (at + 3.5, 0.45, lean, 64)]
        # The votives: the bolero's rhythm on chord tones up high, soft and uneven.
        for k, beat in enumerate((0.0, 1.0, 1.5, 2.0, 3.0)):
            tone = 84 + (c + root + tones[(k * 2 + bar) % len(tones)]) % 12
            vel = (52 if beat in (0.0, 2.0) else 34) + rng.randint(-6, 6)
            glass.append((round(at + beat + rng.uniform(-0.02, 0.02), 4), 0.4, tone, vel))
        pad += [(at, BEATS, 60 + (c + root + t) % 12 + (12 if t > 12 else 0) - 12, 54) for t in tones[1:4]]
    # The candle flicker: the pad's brightness wandering, an eighth at a time.
    bright = 60.0
    for i in range(int(end * 2)):
        bright = max(30.0, min(90.0, bright + rng.uniform(-9, 9)))
        pad_moves.append((i * 0.5, 74, int(bright)))

    # His melody (bars 1-8), scooped up into long notes and falling off phrase ends.
    trumpet, trumpet_moves = [], [(0.0, 'bend_range', 2)]
    phrase_ends = {(2, 1), (3, 0), (5, 2), (7, 0)}
    for bar, beat, length, step in LANE_MELODY:
        at = bar * BEATS + beat
        trumpet.append((at, length * 0.95, 60 + c + step, 80 if length >= 1.0 else 70))
        if length >= 1.0:
            trumpet_moves += [(at, 'bend', -0.25), (at + 0.15, 'bend', 0.0)]
            trumpet_moves += _ramp(at, at + min(length, 2.0), 11, 70, 110, 8)
        if (bar, int(beat)) in phrase_ends:
            trumpet_moves += _ramp(at + length * 0.7, at + length * 0.95, 'bend', 0.0, -1.0, 8, 2.0)
            trumpet_moves.append((at + length, 'bend', 0.0))
    # A few of his answers to her, sparse, in the second eight.
    for bar, beat, step in ((9, 3.0, 3), (11, 3.5, 2), (13, 2.5, 7)):
        trumpet.append((bar * BEATS + beat, 0.9, 60 + c + step, 62))

    # Her guitar: fills in the first eight, then his melody answered in thirds.
    guitar = []
    for bar in (1, 3, 5, 7):
        at = bar * BEATS + 3.0
        root, tones = LANE_CHORDS[bar][1], LANE_CHORDS[bar][2]
        for i, t in enumerate(tones[:3]):
            # The chord tone in the guitar's middle, G3 up.
            pitch = 48 + (c + root + t) % 12
            guitar.append((at + i * 0.25, 0.3, pitch + 12 if pitch < 55 else pitch, 58 - i * 6))
    for bar, beat, length, step in LANE_MELODY:
        at = (bar + 8) * BEATS + beat
        top = 60 + c + step
        guitar += [(at, length * 0.9, top, 72), (at, length * 0.9, _third_below(top, c), 64)]

    # Brushes (full): a slow bolero groove, swept.
    brushes = []
    for bar in range(bars):
        at = bar * BEATS
        brushes += [(at, 0.2, 36, 70), (at + 2.75, 0.2, 36, 52), (at + 1.0, 0.3, 38, 48), (at + 3.0, 0.3, 38, 56)]
        brushes += [(at + h + 0.5, 0.1, 42, 26 + rng.randint(0, 8)) for h in range(4)]

    # The haunts. Pleading: sighs, a wordless voice bending down a tone, every two bars.
    pleading, pleading_moves = [], [(0.0, 'bend_range', 2), (0.0, 11, 0)]
    for k in range(8):
        at = k * 8.0 + 1.0
        root, tones = LANE_CHORDS[k * 2][1], LANE_CHORDS[k * 2][2]
        pitch = 72 + (c + root + tones[(k + 2) % len(tones)]) % 12
        pleading.append((at, 5.5, pitch, 70))
        pleading_moves += [(at, 'bend', 0.0)] + _ramp(at + 1.5, at + 5.0, 'bend', 0.0, -1.0, 12, 1.5)
        pleading_moves += _ramp(at, at + 1.5, 11, 0, 110, 6) + _ramp(at + 4.0, at + 5.5, 11, 110, 0, 6)
    # Dragged: something low hauled down an octave, every four bars.
    dragged, dragged_moves = [], [(0.0, 'bend_range', 12)]
    for k in range(4):
        at = k * 16.0
        dragged.append((at, 8.0, 36 + c, 96))
        dragged_moves += [(at, 'bend', 0.0)] + _ramp(at + 1.0, at + 8.0, 'bend', 0.0, -1.0, 24, 1.6)
    # Swarm: the votives' glass trembling in a cluster, thirty-seconds the whole way.
    cluster = [84 + (c + n) % 12 for n in (0, 1, 2, 3, 7, 8)]
    swarm = [(round(i * 0.125, 4), 0.12, rng.choice(cluster), rng.randint(14, 44)) for i in range(int(end * 8))]

    return [{'name': 'L Bass', 'channel': 0, 'program': 32, 'notes': bass},
            {'name': 'L Glass', 'channel': 1, 'program': 8, 'notes': glass},
            {'name': 'L Guitar', 'channel': 2, 'program': 24, 'notes': guitar},
            {'name': 'L Candle pad', 'channel': 3, 'program': 89, 'notes': pad, 'controls': pad_moves},
            {'name': 'L Trumpet', 'channel': 4, 'program': 59, 'notes': trumpet, 'controls': trumpet_moves},
            {'name': 'L Brushes', 'channel': 9, 'notes': brushes},
            {'name': 'H Pleading', 'channel': 5, 'program': 52, 'notes': pleading, 'controls': pleading_moves},
            {'name': 'H Dragged', 'channel': 6, 'program': 38, 'notes': dragged, 'controls': dragged_moves},
            {'name': 'H Swarm', 'channel': 7, 'program': 14, 'notes': swarm}]


PIECES = {'bed': bed, 'cue': cue, 'lane': lane}


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
