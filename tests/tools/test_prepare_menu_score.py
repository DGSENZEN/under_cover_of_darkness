"""python3 -m unittest discover -s tests/tools -p 'test_prepare_menu_score.py'

The fixtures here are numpy tones: test data for the tool, never game audio.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / 'tools/prepare_menu_score.py'
RATE = 48000


def write_wav(path, seconds, freq, channels=2):
    t = np.arange(round(seconds * RATE)) / RATE
    tone = (0.3 * np.sin(2 * np.pi * freq * t) * (1 + 0.5 * np.sin(2 * np.pi * 0.5 * t)))
    pcm = (np.column_stack([tone, tone * 0.9][:channels]) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(channels)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())


def decode(path):
    data = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ac', '2', '-'],
                          capture_output=True, check=True).stdout
    return np.frombuffer(data, dtype='<f4').reshape(-1, 2)


def frames(path):
    """Sample count recorded in the Ogg (ffmpeg's decoder drops the last block)."""
    info = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=duration_ts',
                           '-of', 'json', str(path)], capture_output=True, check=True, text=True).stdout
    return int(json.loads(info)['streams'][0]['duration_ts'])


def fixture_map(bpm=120, bars=2):
    return {
        'bpm': bpm, 'beats_per_bar': 4, 'bars': bars, 'phrase_bars': 1,
        'chords': [{'bar': 0, 'name': 'Dm'}, {'bar': 1, 'name': 'Gm'}],
        'stems': [
            {'id': 'piano', 'file': 'stems/piano.wav', 'layer': 'base', 'button': -1, 'trim_db': 0},
            {'id': 'drums', 'file': 'stems/drums.wav', 'layer': 'low', 'button': -1, 'trim_db': -3},
        ],
        'arrival': None,
        'jingles': [
            {'button': 0, 'kind': 'hover', 'chord': 'Dm', 'variant': 0, 'file': None,
             'cut': {'stem': 'piano', 'start_bar': 0.0, 'beats': 0.5}},
            {'button': 0, 'kind': 'press', 'chord': 'Gm', 'variant': 0, 'file': None,
             'cut': {'stem': 'piano', 'start_bar': 1.0, 'beats': 1.5}},
        ],
    }


class PrepareMenuScore(unittest.TestCase):
    def build(self, mapping, stems=('piano', 'drums'), seconds=4.0):
        work = Path(tempfile.mkdtemp())
        (work / 'src/stems').mkdir(parents=True)
        for i, stem in enumerate(stems):
            write_wav(work / f'src/stems/{stem}.wav', seconds, 220 * (i + 1))
        (work / 'src/map.json').write_text(json.dumps(mapping))
        result = subprocess.run([sys.executable, str(TOOL), '--source', str(work / 'src'), '--out', str(work / 'out'),
                                 '--res-prefix', 'res://fixture'], capture_output=True, text=True)
        return work, result

    def test_loop_length_and_seamless_stems(self):
        work, result = self.build(fixture_map())
        self.assertEqual(result.returncode, 0, result.stderr)
        score = json.loads((work / 'out/score.json').read_text())
        self.assertAlmostEqual(score['loop_seconds'], 2 * 4 * 60 / 120)
        for stem in ('piano', 'drums'):
            self.assertEqual(frames(work / f'out/{stem}.ogg'), round(score['loop_seconds'] * RATE))

    def test_cut_jingle_is_the_source_slice(self):
        work, result = self.build(fixture_map())
        self.assertEqual(result.returncode, 0, result.stderr)
        path = work / 'out/jingles/b0_press_Gm_0.ogg'
        self.assertEqual(frames(path), round(1.5 * 0.5 * RATE))
        press = decode(path)
        source = decode(work / 'src/stems/piano.wav')[round(2.0 * RATE):round(2.0 * RATE) + len(press)]
        body = slice(0, len(press) - round(0.01 * RATE))
        score = json.loads((work / 'out/score.json').read_text())
        gain = 10 ** (score['common_gain_db'] / 20)
        self.assertLess(np.sqrt(np.mean((press[body] - source[body] * gain) ** 2)), 0.01)
        # The last 5 ms fade out: compare what ffmpeg decodes of it (it stops 128 short).
        total = round(1.5 * 0.5 * RATE)
        fade = round(0.005 * RATE)
        ramp = np.linspace(1, 0, fade)[len(press) - (total - fade) - 48:len(press) - (total - fade)]
        expected = source[len(press) - 48:len(press)] * gain * ramp[:, None]
        self.assertLess(np.sqrt(np.mean((press[-48:] - expected) ** 2)), 0.01)

    def test_jingle_table_groups_by_button_kind_chord(self):
        work, result = self.build(fixture_map())
        self.assertEqual(result.returncode, 0, result.stderr)
        score = json.loads((work / 'out/score.json').read_text())
        self.assertEqual(score['jingles']['0']['hover']['Dm'], ['res://fixture/jingles/b0_hover_Dm_0.ogg'])
        self.assertEqual(score['jingles']['0']['press']['Gm'], ['res://fixture/jingles/b0_press_Gm_0.ogg'])
        self.assertEqual([s['index'] for s in score['stems']], [0, 1])
        self.assertIn('stream_1/stream', (work / 'out/score.tres').read_text())

    def test_ring_out_folds_onto_the_loop_start(self):
        # A stem that sounds past the loop's end: its ring-out continues at the
        # top of the loop instead of being cut off (no click at the seam).
        work, result = self.build(fixture_map(), seconds=5.0)
        self.assertEqual(result.returncode, 0, result.stderr)
        loop = decode(work / 'out/piano.ogg')
        source = decode(work / 'src/stems/piano.wav')
        n = round(4.0 * RATE)
        gain = 10 ** (json.loads((work / 'out/score.json').read_text())['common_gain_db'] / 20)
        expected = (source[:64] + source[n:n + 64]) * gain
        self.assertLess(np.abs(loop[:64] - expected).max(), 0.02)

    def test_mono_stem_becomes_stereo(self):
        work = Path(tempfile.mkdtemp())
        (work / 'src/stems').mkdir(parents=True)
        write_wav(work / 'src/stems/piano.wav', 4.0, 220)
        write_wav(work / 'src/stems/drums.wav', 4.0, 440, channels=1)
        (work / 'src/map.json').write_text(json.dumps(fixture_map()))
        result = subprocess.run([sys.executable, str(TOOL), '--source', str(work / 'src'), '--out', str(work / 'out')],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        drums = decode(work / 'out/drums.ogg')
        self.assertGreater(np.abs(drums).max(), 0.05)
        self.assertLess(np.abs(drums[:, 0] - drums[:, 1]).max(), 0.01)

    def test_cut_jingle_fades_in(self):
        work, result = self.build(fixture_map())
        self.assertEqual(result.returncode, 0, result.stderr)
        hover = decode(work / 'out/jingles/b0_hover_Dm_0.ogg')
        self.assertLess(np.abs(hover[:8]).max(), 0.01)

    def test_unknown_layer_is_named(self):
        mapping = fixture_map()
        mapping['stems'][1]['layer'] = 'loud'
        _, result = self.build(mapping)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('drums', result.stderr)

    def test_missing_file_is_named(self):
        mapping = fixture_map()
        mapping['stems'][0]['file'] = 'stems/nope.wav'
        _, result = self.build(mapping)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('piano', result.stderr)


if __name__ == '__main__':
    unittest.main()
