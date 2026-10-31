"""The place score's preparation: one bed and a locked set per theme, all on one frame."""
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

import numpy as np

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


class PlaceScorePreparationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.prep = load('prepare_place_score')
        cls.fixture = load('fixture_place_score')
        cls.menu = load('prepare_menu_score')

    def setUp(self):
        self.source = Path(tempfile.mkdtemp())
        self.out = Path(tempfile.mkdtemp())
        self.fixture.write_sources(self.source)

    def tearDown(self):
        shutil.rmtree(self.source, ignore_errors=True)
        shutil.rmtree(self.out, ignore_errors=True)

    def mapping(self):
        return json.loads((self.source / 'map.json').read_text())

    def remap(self, mapping):
        (self.source / 'map.json').write_text(json.dumps(mapping))

    def run_prep(self):
        return self.prep.prepare(self.source, self.out, 'res://test/place')

    def test_theme_loops_must_be_whole_phrases(self):
        mapping = self.mapping()
        mapping['themes']['a']['bars'] = 6
        self.remap(mapping)
        with self.assertRaises(SystemExit):
            self.run_prep()

    def test_every_stem_of_a_set_has_the_set_length(self):
        report = self.run_prep()
        bpm = report['bpm']
        sets = dict(report['themes'])
        sets['bed'] = report['bed']
        for name, entry in sets.items():
            samples = round(entry['bars'] * 4 * 60 / bpm * 48000)
            for stem in entry['stems']:
                audio = self.menu.read_audio(self.out / name / f'{stem["id"]}.ogg')
                self.assertEqual(len(audio), samples, f'{name}/{stem["id"]}')

    def test_tails_fold_back_across_the_join(self):
        mapping = self.mapping()
        stem = mapping['themes']['c']['stems'][0]
        bars = mapping['themes']['c']['bars']
        loop = round(bars * 4 * 60 / mapping['bpm'] * 48000)
        ring = np.zeros((loop + round(0.2 * 48000), 2), dtype=np.float32)
        ring[loop:loop + 4800] = 0.5
        self.fixture.write_wav(self.source / stem['file'], ring)
        self.run_prep()
        audio = self.menu.read_audio(self.out / 'c' / f'{stem["id"]}.ogg')
        self.assertGreater(float(np.max(np.abs(audio[:4800]))), 0.05)

    def test_more_than_32_stems_in_a_set_fails(self):
        mapping = self.mapping()
        first = mapping['themes']['c']['stems'][0]
        mapping['themes']['c']['stems'] = [dict(first, id=f'extra{i}', part=f'p{i}') for i in range(33)]
        self.remap(mapping)
        with self.assertRaises(SystemExit):
            self.run_prep()

    def test_one_common_gain_for_bed_themes_and_cue(self):
        report = self.run_prep()
        sets = dict(report['themes'])
        sets['bed'] = report['bed']
        tracks = []
        for name, entry in sets.items():
            for stem in entry['stems']:
                tracks.append(self.menu.read_audio(self.out / name / f'{stem["id"]}.ogg'))
        longest = max(len(t) for t in tracks)
        mix = np.zeros((longest, 2), dtype=np.float32)
        for track in tracks:
            mix += np.tile(track, (longest // len(track) + 1, 1))[:longest]
        peak_db = 20 * np.log10(float(np.max(np.abs(mix))))
        self.assertLessEqual(peak_db, -3.0 + 0.3)
        self.assertLessEqual(report['common_gain_db'], -8.0 + 1e-6)

    def test_score_json_lists_indices_resources_and_roles(self):
        report = self.run_prep()
        mapping = self.mapping()
        written = json.loads((self.out / 'score.json').read_text())
        self.assertEqual(written, report)
        for name, theme in report['themes'].items():
            self.assertTrue(theme['resource'].endswith(f'{name}.tres'))
            self.assertTrue((self.out / f'{name}.tres').exists())
            self.assertEqual([s['index'] for s in theme['stems']], list(range(len(theme['stems']))))
            self.assertEqual([s['id'] for s in theme['stems']], [s['id'] for s in mapping['themes'][name]['stems']])
        self.assertTrue(report['bed']['resource'].endswith('bed.tres'))
        self.assertEqual(report['placeholder'], mapping['placeholder'])
        self.assertEqual(report['spaces'], mapping['spaces'])
        self.assertEqual(report['circles'], mapping['circles'])
        lead_met = [s for s in report['themes']['b']['stems'] if s['id'] == 'lead_met'][0]
        self.assertEqual(lead_met['variant'], {'character': 'curandera', 'when': 'met'})
        haunt = [s for s in report['themes']['a']['stems'] if s['id'] == 'haunt'][0]
        self.assertEqual(haunt['haunted'], 'pleading')
        self.assertTrue(report['cue']['path'].endswith('cue.ogg'))
        self.assertAlmostEqual(report['cue']['seconds'], 1.0, places=2)

    def test_missing_file_names_the_stem(self):
        mapping = self.mapping()
        mapping['themes']['a']['stems'][0]['file'] = 'nowhere.wav'
        self.remap(mapping)
        with self.assertRaises(SystemExit) as caught:
            self.run_prep()
        self.assertIn(mapping['themes']['a']['stems'][0]['id'], str(caught.exception.code))


if __name__ == '__main__':
    unittest.main()
