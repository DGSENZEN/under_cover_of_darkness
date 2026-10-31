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

    def test_cue_takes_hold_to_c_and_land_on_the_phrase_line(self):
        # C minor with the Phrygian D flat the deep layers lean on.
        allowed = {0, 1, 2, 3, 5, 7, 8, 10}
        land = self.compose.CUE_LANDS_BAR * 4 - 4
        parts = self.compose.cue('C')
        self.assertEqual({p['name'][0] for p in parts}, {'1', '2', '3'})
        for part in parts:
            # (Drum hits, on channel 10, are not pitches.)
            if part.get('channel') != 9:
                self.assertTrue(all(n[2] % 12 in allowed for n in part['notes']), part['name'])
            # (Nothing starts past the land but the second clack of the last pair.)
            self.assertTrue(all(s <= land + 0.5 for s, _, _, _ in part['notes']), part['name'])
        for take in '123':
            ends = [s + l for p in parts if p['name'][0] == take for s, l, _, _ in p['notes']]
            self.assertGreaterEqual(max(ends), land - 0.3, take)

    def test_tape_sink_bends_down_an_octave_as_it_slows(self):
        organ = [p for p in self.compose.cue('C') if p['name'] == '1 Street organ'][0]
        self.assertIn((0.0, 'bend_range', 12), organ['controls'])
        bends = [v for _, k, v in organ['controls'] if k == 'bend']
        self.assertAlmostEqual(min(bends), -1.0, places=2)
        starts = [n[0] for n in organ['notes']]
        gaps = [b - a for a, b in zip(starts, starts[1:])]
        self.assertGreater(gaps[-1], gaps[0] * 2)

    def test_wheels_brake_onto_the_land(self):
        wheels = [p for p in self.compose.cue('C') if p['name'] == '3 Wheels'][0]['notes']
        land = self.compose.CUE_LANDS_BAR * 4 - 4
        pairs = sorted({round(n[0], 3) for n in wheels})
        firsts = pairs[::2]
        gaps = [b - a for a, b in zip(firsts, firsts[1:])]
        self.assertTrue(all(b >= a - 1e-6 for a, b in zip(gaps, gaps[1:])), gaps)
        self.assertAlmostEqual(firsts[-1], land, places=3)

    def test_pressure_clusters_drift_apart(self):
        parts = {p['name']: p for p in self.compose.cue('C')}
        a = [v for _, k, v in parts['2 Cluster A']['controls'] if k == 'bend']
        b = [v for _, k, v in parts['2 Cluster B']['controls'] if k == 'bend']
        self.assertGreater(max(a), 0.0)
        self.assertLess(min(b), 0.0)

    def test_lane_is_sixteen_bars_of_c_dorian_with_its_haunts(self):
        parts = {p['name']: p for p in self.compose.lane('C')}
        for name in ('L Sub', 'L Bass', 'L Kit', 'L Keys', 'L Glass', 'L Guitar', 'L Candle pad',
                     'L Trumpet', 'L Backbeat', 'H Pleading', 'H Dragged', 'H Swarm'):
            self.assertIn(name, parts)
        # C Dorian, with the Db and Ab the deep layers lean on.
        allowed = {0, 1, 2, 3, 5, 7, 8, 9, 10}
        for name, part in parts.items():
            if part.get('channel') == 9:
                continue
            self.assertTrue(all(n[2] % 12 in allowed for n in part['notes']), name)
            self.assertTrue(all(s < 64.0 for s, _, _, _ in part['notes']), name)
        self.assertAlmostEqual(max(s + l for s, l, _, _ in parts['L Bass']['notes']), 64.0, delta=0.6)

    def test_every_part_keeps_to_its_own_register(self):
        import statistics
        parts = {p['name']: p for p in self.compose.lane('C')}
        bands = [('L Sub', 24, 35), ('L Bass', 36, 47), ('L Candle pad', 48, 64), ('L Keys', 60, 74),
                 ('L Trumpet', 62, 79), ('L Glass', 84, 98)]
        for name, low, high in bands:
            median = statistics.median(n[2] for n in parts[name]['notes'])
            self.assertTrue(low <= median <= high, f'{name} median {median}')

    def test_trip_hop_backbeat_sits_late_on_two_and_four(self):
        parts = {p['name']: p for p in self.compose.lane('C')}
        snares = [n for n in parts['L Backbeat']['notes'] if n[2] == 38 and n[3] >= 100]
        offsets = {round((n[0] % 4) - int(n[0] % 4), 3) for n in snares}
        self.assertTrue(all(0.0 < o < 0.05 for o in offsets), offsets)
        self.assertEqual({int(n[0] % 4) for n in snares}, {1, 3})
        kicks = [n for n in parts['L Kit']['notes'] if n[2] == 36]
        self.assertEqual(sum(1 for n in kicks if n[0] % 4 == 0.0), 16)
        hats = sorted(n[0] % 1 for n in parts['L Kit']['notes'] if n[2] == 42)
        self.assertTrue(any(abs(h - 0.285) < 0.01 for h in hats))

    def test_him_then_her(self):
        parts = {p['name']: p for p in self.compose.lane('C')}
        trumpet = [n[0] for n in parts['L Trumpet']['notes']]
        guitar = parts['L Guitar']['notes']
        # His melody leads the first eight bars; her thirds carry the second eight.
        self.assertGreater(sum(1 for t in trumpet if t < 32), 2 * sum(1 for t in trumpet if t >= 32))
        second = [n for n in guitar if n[0] >= 32]
        starts = {}
        for n in second:
            starts.setdefault(round(n[0], 3), []).append(n[2])
        thirds = [ps for ps in starts.values() if len(ps) == 2 and 3 <= abs(ps[0] - ps[1]) <= 4]
        self.assertGreater(len(thirds), 8)

    def test_pleading_sighs_bend_down(self):
        pleading = [p for p in self.compose.lane('C') if p['name'] == 'H Pleading'][0]
        bends = [v for _, k, v in pleading['controls'] if k == 'bend']
        self.assertLess(min(bends), -0.5)

    def test_performance_moves_notes_only_a_little_and_the_same_each_time(self):
        raw = {p['name']: p for p in self.compose.lane('C')}
        played = {p['name']: p for p in self.compose.perform(self.compose.lane('C'))}
        again = {p['name']: p for p in self.compose.perform(self.compose.lane('C'))}
        self.assertEqual(played, again)
        for name, part in raw.items():
            before = sorted(part['notes'])
            after = sorted(played[name]['notes'])
            self.assertEqual(len(before), len(after), name)
            for a, b in zip(before, after):
                self.assertLess(abs(a[0] - b[0]), 0.08, name)
                self.assertEqual(a[2], b[2], name)
            self.assertNotEqual(before, after, name)

    def test_trumpet_breathes_blooms_and_drifts(self):
        trumpet = [p for p in self.compose.perform(self.compose.lane('C')) if p['name'] == 'L Trumpet'][0]
        moves = trumpet['controls']
        self.assertTrue(any(k == 1 and v >= 40 for _, k, v in moves), 'no vibrato bloom')
        self.assertTrue(any(k == 11 for _, k, v in moves), 'no expression')
        written = [p for p in self.compose.lane('C') if p['name'] == 'L Trumpet'][0]['controls']
        added = [m for m in moves if m not in written]
        drift = [v for _, k, v in added if k == 'bend']
        self.assertTrue(any(v != 0.0 for v in drift), 'no drift')
        self.assertTrue(all(abs(v) <= 0.03 for v in drift), 'drift too wide')
        # Laid back: on average a little behind the beat.
        raw = sorted(n[0] for n in [p for p in self.compose.lane('C') if p['name'] == 'L Trumpet'][0]['notes'])
        played = sorted(n[0] for n in trumpet['notes'])
        self.assertGreater(sum(b - a for a, b in zip(raw, played)) / len(raw), 0.005)

    def test_guitar_strums_low_first_and_keys_roll(self):
        played = {p['name']: p for p in self.compose.perform(self.compose.lane('C'))}
        second = sorted((n for n in played['L Guitar']['notes'] if n[0] >= 32), key=lambda n: n[0])
        pairs = [(a, b) for a, b in zip(second, second[1:]) if abs(a[0] - b[0]) < 0.05 and 3 <= abs(a[2] - b[2]) <= 4]
        self.assertGreater(len(pairs), 8)
        self.assertTrue(all(a[2] < b[2] for a, b in pairs), 'the lower string sounds first')
        keys = played['L Keys']['notes']
        stabs = {}
        for n in keys:
            stabs.setdefault(round(n[0] * 4) / 4, []).append(n[0])
        self.assertTrue(any(len(set(v)) > 1 for v in stabs.values()), 'chords not rolled')

    def test_midi_carries_bends_ccs_and_bend_range(self):
        out = Path(tempfile.mkdtemp()) / 'moves.mid'
        controls = [(0.0, 'bend_range', 12), (0.0, 74, 10), (1.0, 'bend', -1.0), (2.0, 'bend', 0.5), (3.0, 11, 127)]
        self.midi.write_song(out, 72, [{'name': 'Moves', 'notes': [(0.0, 4.0, 60, 90)], 'controls': controls}])
        song = self.midi.read_midi(out)
        moves = [t for t in song['tracks'] if t['name'] == 'Moves'][0]['controls']
        self.assertIn((0.0, 'bend_range', 12, 0), moves)
        self.assertIn((0.0, 74, 10, 0), moves)
        self.assertIn((3.0, 11, 127, 0), moves)
        bends = [m for m in moves if m[1] == 'bend']
        self.assertAlmostEqual(bends[0][2], -1.0, places=3)
        self.assertAlmostEqual(bends[1][2], 0.5, places=3)

    def test_menu_parts_without_controls_are_unchanged(self):
        out = Path(tempfile.mkdtemp())
        a, b = out / 'a.mid', out / 'b.mid'
        self.midi.write_song(a, 78, [{'name': 'P', 'notes': [(0.0, 1.0, 62, 80)]}])
        self.midi.write_song(b, 78, [{'name': 'P', 'notes': [(0.0, 1.0, 62, 80)], 'controls': []}])
        self.assertEqual(a.read_bytes(), b.read_bytes())

    def test_writes_one_file_per_take(self):
        out = Path(tempfile.mkdtemp())
        path = self.compose.write_piece('bed', 72, 'Bb', 2, out)
        self.assertEqual(path.name, 'bed_Bb_2.mid')
        song = self.midi.read_midi(path)
        self.assertAlmostEqual(song['bpm'], 72.0, places=1)
        self.assertGreaterEqual(len([t for t in song['tracks'] if t['notes']]), 3)


if __name__ == '__main__':
    unittest.main()
