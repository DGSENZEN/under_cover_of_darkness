#!/usr/bin/env python3
"""Rebuild the menu music test score: python3 tests/fixtures/make_menu_score_fixture.py

Numpy tones (test data only, never game audio) run through the real
tools/prepare_menu_score.py into tests/fixtures/menu_score/: 78 bpm, 16 bars,
8-bar phrases, Dm then Gm every 4 bars, one stem per layer plus a stem for
each button, and hover/press jingles (2 variants) per button per chord.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tests/fixtures/menu_score'
RATE = 48000
BPM, BARS = 78, 16
STEMS = [('piano', 'base', -1), ('drums', 'low', -1), ('trumpet', 'high', 0), ('guitar', 'high', 1),
         ('rhodes', 'high', 2), ('bells', 'high', 3), ('drone', 'fx', -1)]


def main():
    work = Path(tempfile.mkdtemp())
    (work / 'stems').mkdir()
    seconds = BARS * 4 * 60 / BPM
    t = np.arange(round(seconds * RATE)) / RATE
    for i, (name, _, _) in enumerate(STEMS):
        tone = 0.2 * np.sin(2 * np.pi * 110 * (i + 1) * t)
        with wave.open(str(work / f'stems/{name}.wav'), 'wb') as out:
            out.setnchannels(2)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes((np.column_stack([tone, tone]) * 32767).astype('<i2').tobytes())
    jingles = []
    for button, stem in enumerate(['trumpet', 'guitar', 'rhodes', 'bells']):
        for chord, bar in (('Dm', 0), ('Gm', 4)):
            for variant in (0, 1):
                jingles.append(dict(button=button, kind='hover', chord=chord, variant=variant, file=None,
                                    cut=dict(stem=stem, start_bar=bar + variant, beats=0.5)))
                jingles.append(dict(button=button, kind='press', chord=chord, variant=variant, file=None,
                                    cut=dict(stem=stem, start_bar=bar + variant, beats=1.5)))
    mapping = dict(bpm=BPM, beats_per_bar=4, bars=BARS, phrase_bars=8,
                   chords=[dict(bar=b, name='Dm' if (b // 4) % 2 == 0 else 'Gm') for b in range(0, BARS, 4)],
                   stems=[dict(id=n, file=f'stems/{n}.wav', layer=l, button=b, trim_db=0) for n, l, b in STEMS],
                   arrival=None, jingles=jingles)
    (work / 'map.json').write_text(json.dumps(mapping))
    subprocess.run([sys.executable, str(ROOT / 'tools/prepare_menu_score.py'), '--source', str(work), '--out', str(OUT),
                    '--res-prefix', 'res://tests/fixtures/menu_score'], check=True)


if __name__ == '__main__':
    main()
