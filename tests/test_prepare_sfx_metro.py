"""The Metro's sounds (docs/superpowers/specs/2026-10-31-metro-sound-design.md): the user's takes layered into
seeded variations and seamless loops, every hum on G."""
import importlib.util
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import wave

import numpy as np

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
sys.path.insert(0, str(TOOLS))


def load(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MetroLayeringTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.prep = load('prepare_sfx')

    def setUp(self):
        prep = self.prep
        rate = prep.RATE
        rng = np.random.default_rng(7)
        self.source = Path(tempfile.mkdtemp())
        self.out = Path(tempfile.mkdtemp())
        t = np.arange(int(12 * rate)) / rate
        self.hum113 = 0.4 * np.sin(2 * np.pi * 113.3 * t) + 0.02 * rng.standard_normal(len(t))
        self.hum100 = 0.4 * np.sin(2 * np.pi * 100.0 * t) + 0.02 * rng.standard_normal(len(t))
        knocks = 0.001 * rng.standard_normal(int(8 * rate))
        for k in range(5):
            at = int((0.5 + 1.5 * k) * rate)
            n = int(0.3 * rate)
            knocks[at:at + n] += (0.5 + 0.05 * k) * rng.standard_normal(n) * np.exp(-np.arange(n) / (0.07 * rate))
        self.knocks = knocks
        prep.write_wav(str(self.source / 'knocks.wav'), knocks)
        self.hits = [knocks[int(a * rate):int(b * rate)] for a, b in prep.split_events(knocks, 5)]
        self.bed_a = 0.2 * rng.standard_normal((int(8 * rate), 2))
        self.bed_b = 0.2 * rng.standard_normal((int(8 * rate), 2))

    def tearDown(self):
        shutil.rmtree(self.source, ignore_errors=True)
        shutil.rmtree(self.out, ignore_errors=True)

    def read(self, path):
        with wave.open(str(path)) as w:
            return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)

    def test_retunes_a_hum_onto_g(self):
        x = self.prep.retune(self.hum113, 98.0)
        self.assertLess(abs(1200 * np.log2(self.prep.hum_hz(x) / 98.0)), 20.0)

    def test_nudges_a_sharp_hum(self):
        self.assertAlmostEqual(self.prep.g_of(100.0), 98.0)
        self.assertAlmostEqual(self.prep.g_of(200.0), 196.0)
        x = self.prep.retune(self.hum100, self.prep.g_of(self.prep.hum_hz(self.hum100)))
        self.assertLess(abs(1200 * np.log2(self.prep.hum_hz(x) / 98.0)), 20.0)

    def test_shots_are_seeded_and_matched(self):
        self.assertEqual(len(self.hits), 5)
        a = self.prep.layered_shots(self.hits, 10, np.random.default_rng(1931))
        b = self.prep.layered_shots(self.hits, 10, np.random.default_rng(1931))
        self.assertEqual(len(a), 10)
        self.assertTrue(all(np.array_equal(p, q) for p, q in zip(a, b)))
        levels = [self.prep.loudness(v) for v in a]
        self.assertLess(max(levels) - min(levels), 1.0)

    def test_loop_seam_is_seamless(self):
        x = self.prep.layered_loop([self.bed_a, self.bed_b], 6.0, np.random.default_rng(1), stereo=True)
        self.assertEqual(x.shape[1], 2)
        self.assertAlmostEqual(len(x) / self.prep.RATE, 6.0, places=2)
        jump = np.abs(x[0] - x[-1]).max()
        self.assertLess(jump, 4 * np.abs(np.diff(x, axis=0)).mean() + 1e-3)

    def test_prepare_metro_replaces_a_group_whole(self):
        sfx = self.out / 'sfx'
        sfx.mkdir()
        for k in range(1, 13):
            (sfx / f'pipe_knock_{k}.wav').write_bytes(b'')
            (sfx / f'pipe_knock_{k}.wav.import').write_bytes(b'')
        self.prep.prepare_metro(str(self.source), str(sfx), str(self.out / 'amb'), None,
                                shots=[('pipe_knock', [('knocks', 5)], 4)], loops=[])
        self.assertEqual(sorted(p.name for p in sfx.glob('pipe_knock_*.wav')), [f'pipe_knock_{k}.wav' for k in range(1, 5)])
        self.assertEqual(list(sfx.glob('pipe_knock_1[0-2].wav.import')), [])

    def test_listening_file_holds_every_variation(self):
        written = self.prep.prepare_metro(str(self.source), str(self.out / 'sfx'), str(self.out / 'amb'),
                                          str(self.out / 'listen'), shots=[('pipe_knock', [('knocks', 5)], 4)], loops=[])
        total = sum(len(self.read(p)) for p in written['pipe_knock']) + 4 * int(0.4 * self.prep.RATE)
        self.assertLess(abs(len(self.read(self.out / 'listen' / 'pipe_knock.wav')) - total), self.prep.RATE // 10)


@unittest.skipUnless(os.path.isdir(os.path.expanduser('~/Downloads/AUCOD ElevenLabs/ucod_sounds')), 'the takes are not here')
class MetroTablesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.prep = load('prepare_sfx')

    def test_real_tables_resolve(self):
        prep = self.prep
        self.assertGreater(len(prep.METRO_SHOTS), 0)
        self.assertGreater(len(prep.METRO_LOOPS), 0)
        for row in prep.METRO_SHOTS:
            for take, _split in row[1]:
                self.assertTrue(os.path.exists(prep._take_path(prep.METRO_SOURCE, take)), take)
        for row in prep.METRO_LOOPS:
            for take in row[1]:
                self.assertTrue(os.path.exists(prep._take_path(prep.METRO_SOURCE, take)), take)

    def test_real_hums_land_on_g(self):
        prep = self.prep
        out = Path(tempfile.mkdtemp())
        try:
            hums = [row for row in prep.METRO_LOOPS if row[3].get('hum')]
            hum_shots = [row for row in prep.METRO_SHOTS if len(row) > 3 and row[3].get('hum')]
            self.assertEqual(sorted(r[0] for r in hums + hum_shots), ['cable_surge', 'junction_hum', 'neon_buzz', 'transformer_hum'])
            for path in [p for paths in prep.prepare_metro(shots=hum_shots, loops=hums, sfx_out=str(out),
                                                            ambience_out=str(out)).values() for p in paths]:
                x = prep._decode_take(path)
                self.assertLess(abs(1200 * np.log2(prep.hum_hz(x) / prep.g_of(prep.hum_hz(x)))), prep.HUM_CENTS, path)
        finally:
            shutil.rmtree(out, ignore_errors=True)


if __name__ == '__main__':
    unittest.main()
