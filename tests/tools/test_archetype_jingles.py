"""python3 -m unittest discover -s tests/tools -p 'test_archetype_jingles.py'"""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import compose_menu_parts as compose  # noqa: E402


class ArchetypeJingles(unittest.TestCase):
    def setUp(self):
        self.parts, self.table = compose.archetype_jingles()

    def test_every_archetype_kind_chord_and_variant_has_a_slot(self):
        keys = {(j['button'], j['kind'], j['chord'], j['variant']) for j in self.table}
        self.assertEqual(len(self.table), 48)
        self.assertEqual(len(keys), 48)
        self.assertEqual({j['button'] for j in self.table}, {5, 6, 7})

    def test_slots_never_overlap(self):
        spans = sorted((j['start_beat'], j['start_beat'] + compose.ARCHETYPE_SLOT_BEATS) for j in self.table)
        for (a0, a1), (b0, _) in zip(spans, spans[1:]):
            self.assertLessEqual(a1, b0)

    def test_pitched_notes_are_tones_of_their_slots_chord(self):
        tones = {name: {(pc + t) % 12 for t in stack} for name, pc, stack in compose.JINGLE_CHORDS}
        for part in self.parts:
            if part['channel'] == 9:
                continue
            for start, _, pitch, _ in part['notes']:
                slot = next(j for j in self.table if j['start_beat'] <= start < j['start_beat'] + compose.ARCHETYPE_SLOT_BEATS)
                self.assertIn(pitch % 12, tones[slot['chord']], (part['name'], start, pitch, slot))

    def test_each_archetype_sounds_only_in_its_own_slots(self):
        owners = {name: button for name, button in compose.ARCHETYPE_TRACKS}
        for part in self.parts:
            for start, _, _, _ in part['notes']:
                slot = next(j for j in self.table if j['start_beat'] <= start < j['start_beat'] + compose.ARCHETYPE_SLOT_BEATS)
                self.assertEqual(slot['button'], owners[part['name']], (part['name'], start))

    def test_notes_fit_inside_their_cut(self):
        for part in self.parts:
            for start, length, _, _ in part['notes']:
                slot = next(j for j in self.table if j['start_beat'] <= start < j['start_beat'] + compose.ARCHETYPE_SLOT_BEATS)
                self.assertLessEqual(start - slot['start_beat'], slot['beats'] - 0.5, (part['name'], start))


if __name__ == '__main__':
    unittest.main()
