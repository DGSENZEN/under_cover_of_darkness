"""The Metro score's MIDI parts hold to the frame: the pedal, the bars, the tempo."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
sys.path.insert(0, str(TOOLS))


def load(name):
    path = TOOLS / f'{name}.py'
    if not path.exists():
        raise AssertionError(f'{name} is not implemented')
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MetroPartsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.compose = load('compose_metro_parts')
        cls.midi = load('menu_midi')

    def test_bed_drones_sit_on_the_pedal_for_sixteen_bars(self):
        for pedal in ('C', 'Bb', 'E'):
            parts = self.compose.bed(pedal)
            names = [p['name'] for p in parts]
            self.assertEqual(names[:3], ['Drone (city)', 'Drone (deep)', 'Pulse'])
            city = parts[0]['notes']
            self.assertTrue(all(n[2] % 12 == self.midi.pitch_class(pedal) for n in city), pedal)
            self.assertAlmostEqual(max(s + l for s, l, _, _ in city), 16 * 4, places=3)
            deep = parts[1]['notes']
            self.assertLess(min(n[2] for n in deep), min(n[2] for n in city))

    def test_pulse_is_a_kick_each_bar_and_a_swung_ghost(self):
        pulse = self.compose.bed('C')[2]['notes']
        kicks = [n for n in pulse if n[0] % 4 < 0.05]
        self.assertEqual(len(kicks), 16)
        ghosts = [n for n in pulse if abs(n[0] % 4 - (2.5 + 0.08)) < 0.03]
        self.assertEqual(len(ghosts), 16)
        self.assertTrue(all(g[3] < k[3] for g, k in zip(ghosts, kicks)))

    def test_writes_one_file_per_take(self):
        out = Path(tempfile.mkdtemp())
        path = self.compose.write_piece('bed', 72, 'Bb', 2, out)
        self.assertEqual(path.name, 'bed_Bb_2.mid')
        song = self.midi.read_midi(path)
        self.assertAlmostEqual(song['bpm'], 72.0, places=1)
        self.assertGreaterEqual(len([t for t in song['tracks'] if t['notes']]), 3)


if __name__ == '__main__':
    unittest.main()
