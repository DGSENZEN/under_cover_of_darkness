"""python3 -m unittest discover -s tests/tools -p 'test_menu_midi.py'"""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import menu_midi  # noqa: E402


class MenuMidi(unittest.TestCase):
    def test_chord_tones(self):
        self.assertEqual(menu_midi.chord_tones('Dm', 4), [62, 65, 69])
        self.assertEqual(menu_midi.chord_tones('Gm7', 3), [55, 58, 62, 65])
        self.assertEqual(menu_midi.chord_tones('A7b9', 3), [57, 61, 64, 67, 70])
        self.assertEqual(menu_midi.chord_tones('Bbmaj7', 3), [58, 62, 65, 69])
        self.assertEqual(menu_midi.chord_tones('Edim', 4), [64, 67, 70])
        self.assertEqual(menu_midi.chord_tones('Eb', 4), [63, 67, 70])

    def test_vlq(self):
        self.assertEqual(menu_midi.vlq(0), b'\x00')
        self.assertEqual(menu_midi.vlq(127), b'\x7f')
        self.assertEqual(menu_midi.vlq(128), b'\x81\x00')
        self.assertEqual(menu_midi.vlq(480), b'\x83\x60')

    def test_exact_bytes_for_one_note(self):
        path = Path(tempfile.mkdtemp()) / 'one.mid'
        menu_midi.write_part(path, 120, [(0.0, 1.0, 60, 100)], name='T')
        data = path.read_bytes()
        self.assertEqual(data[:14], b'MThd\x00\x00\x00\x06\x00\x00\x00\x01\x01\xe0')
        self.assertEqual(data[14:18], b'MTrk')
        body = data[22:]
        self.assertIn(b'\x00\xff\x51\x03\x07\xa1\x20', body)  # 500000 us per beat
        self.assertIn(b'\x00\x90\x3c\x64', body)  # note on at 0
        self.assertIn(b'\x83\x60\x80\x3c\x00', body)  # note off 480 ticks later
        self.assertTrue(body.endswith(b'\x00\xff\x2f\x00'))

    def test_round_trip(self):
        path = Path(tempfile.mkdtemp()) / 'part.mid'
        notes = [(0.0, 0.5, 62, 90), (0.5, 1.5, 65, 70), (2.0, 2.0, 69, 80), (2.0, 2.0, 74, 60)]
        menu_midi.write_part(path, 78, notes, channel=3)
        song = menu_midi.read_midi(path)
        self.assertEqual(song['ppq'], 480)
        self.assertAlmostEqual(song['bpm'], 78, places=2)
        got = sorted((n[0], n[1], n[2], n[3]) for n in song['tracks'][0]['notes'])
        self.assertEqual(got, sorted(notes))
        self.assertEqual({n[4] for n in song['tracks'][0]['notes']}, {3})


if __name__ == '__main__':
    unittest.main()
