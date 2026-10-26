#!/usr/bin/env python3
"""Render the menu theme: python3 tools/prepare_menu_score.py [--source DIR] [--out DIR] [--res-prefix res://...]

Reads <source>/map.json (see docs/systems/audio.md) and the Logic exports it
names, and writes to <out>:
  <stem id>.ogg            one seamless loop per stem, all the same length
  score.tres               AudioStreamSynchronized, one stream per stem in map order
  jingles/b<button>_<kind>_<chord>_<variant>.ogg
  arrival.ogg              when the map names one
  score.json               the map's timing plus stem indices, jingle paths, levels
Requires ffmpeg, libsndfile (with Vorbis) and numpy, as tools/prepare_score.py.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_score import command, encode, stereo  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/audio/source/menu_theme'
OUTPUT = ROOT / 'audio/music/menu'
RATE = 48000
LAYERS = ('base', 'low', 'high', 'fx')
KINDS = ('hover', 'press')
FADE_OUT = round(0.005 * RATE)
# A cut can start mid-note: ease in so it never clicks.
FADE_IN = round(0.003 * RATE)


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def read_audio(path):
    data = command(['ffmpeg', '-nostdin', '-v', 'error', '-xerror', '-i', str(path), '-f', 'f32le', '-'])
    probe = command(['ffprobe', '-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=channels,sample_rate',
                     '-of', 'json', str(path)])
    info = json.loads(probe)['streams'][0]
    if int(info['sample_rate']) != RATE:
        raise ValueError(f'{path.name} is {info["sample_rate"]} Hz, not {RATE}')
    audio = np.frombuffer(data, dtype='<f4').reshape(-1, int(info['channels']))
    if audio.shape[1] == 1:
        return np.repeat(audio, 2, axis=1)
    return stereo(audio) if audio.shape[1] != 2 else audio.copy()


# Whatever sounds past the loop's end (notes ringing over the bar line) is
# folded back onto the loop's start, fading out over this long, so the
# seam continues instead of cutting off.
FOLD = round(0.25 * RATE)


def fit(audio, samples):
    out = np.zeros((samples, 2), dtype=np.float32)
    n = min(samples, len(audio))
    out[:n] = audio[:n]
    tail = audio[samples:samples + FOLD]
    if len(tail):
        out[:len(tail)] += tail * np.linspace(1, 0, FOLD)[:len(tail), None]
    return out


def import_header(path, res_path):
    metadata = path.with_suffix('.ogg.import')
    if metadata.exists():
        return metadata, metadata.read_text().partition('[params]')[0]
    return metadata, ('[remap]\n\nimporter="oggvorbisstr"\ntype="AudioStreamOggVorbis"\n\n'
                      f'[deps]\n\nsource_file="{res_path}"\n\n')


def write_ogg(path, pcm, res_path, loop, bpm=0.0, beats=0, bar_beats=4):
    path.parent.mkdir(parents=True, exist_ok=True)
    encode(path, pcm)
    metadata, header = import_header(path, res_path)
    params = f'[params]\n\nloop={"true" if loop else "false"}\nloop_offset=0.0\nbpm={float(bpm)}\nbeat_count={beats}\nbar_beats={bar_beats}\n'
    metadata.write_text(header + params)


def write_resource(out, prefix, stems):
    lines = [f'[gd_resource type="AudioStreamSynchronized" load_steps={len(stems) + 1} format=3]', '']
    for stem in stems:
        lines.append(f'[ext_resource type="AudioStream" path="{prefix}/{stem["id"]}.ogg" id="{stem["id"]}"]')
    lines.extend(['', '[resource]', f'stream_count = {len(stems)}'])
    for index, stem in enumerate(stems):
        lines.extend([f'stream_{index}/stream = ExtResource("{stem["id"]}")', f'stream_{index}/volume = -80.0'])
    (out / 'score.tres').write_text('\n'.join(lines) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--out', type=Path, default=OUTPUT)
    parser.add_argument('--res-prefix', default='res://audio/music/menu')
    args = parser.parse_args()
    prefix = args.res_prefix.rstrip('/')
    mapping = json.loads((args.source / 'map.json').read_text())
    bpm, bar_beats, bars = float(mapping['bpm']), int(mapping['beats_per_bar']), int(mapping['bars'])
    beat = 60.0 / bpm
    loop_seconds = bars * bar_beats * beat
    loop_samples = round(loop_seconds * RATE)

    stems = mapping['stems']
    audio = {}
    for stem in stems:
        if stem['layer'] not in LAYERS:
            fail(f'Stem {stem["id"]}: unknown layer {stem["layer"]!r} (expected one of {", ".join(LAYERS)})')
        path = args.source / stem['file']
        if not path.exists():
            fail(f'Stem {stem["id"]}: missing file {path}')
        audio[stem['id']] = fit(read_audio(path), loop_samples) * 10 ** (float(stem.get('trim_db', 0)) / 20)
    # One common gain for the whole score (and its jingles), as the combat score.
    peak = float(np.max(np.abs(sum(audio.values()))))
    gain = min(10 ** (-8 / 20), 0.70 / max(peak, 1e-12))

    args.out.mkdir(parents=True, exist_ok=True)
    report = dict(bpm=bpm, beats_per_bar=bar_beats, bars=bars, phrase_bars=int(mapping['phrase_bars']),
                  loop_seconds=loop_seconds, sample_rate=RATE, common_gain_db=float(20 * np.log10(gain)),
                  chords=mapping['chords'], stems=[], jingles={}, arrival=None, arrival_seconds=0.0)
    for index, stem in enumerate(stems):
        pcm = audio[stem['id']] * gain
        write_ogg(args.out / f'{stem["id"]}.ogg', pcm, f'{prefix}/{stem["id"]}.ogg', True, bpm, bars * bar_beats, bar_beats)
        source = (args.source / stem['file']).read_bytes()
        report['stems'].append(dict(id=stem['id'], layer=stem['layer'], button=int(stem.get('button', -1)), index=index,
                                    peak_db=float(20 * np.log10(max(float(np.max(np.abs(pcm))), 1e-9))),
                                    sha256=hashlib.sha256(source).hexdigest()))

    for jingle in mapping.get('jingles', []):
        if jingle['kind'] not in KINDS:
            fail(f'Jingle for button {jingle["button"]}: unknown kind {jingle["kind"]!r}')
        name = f'b{jingle["button"]}_{jingle["kind"]}_{jingle["chord"]}_{jingle["variant"]}'
        if jingle.get('file'):
            path = args.source / jingle['file']
            if not path.exists():
                fail(f'Jingle {name}: missing file {path}')
            pcm = read_audio(path) * gain
        else:
            cut = jingle['cut']
            if cut['stem'] not in audio:
                fail(f'Jingle {name}: unknown stem {cut["stem"]!r}')
            start = round(float(cut['start_bar']) * bar_beats * beat * RATE)
            count = round(float(cut['beats']) * beat * RATE)
            pcm = audio[cut['stem']][start:start + count].copy() * gain
            if len(pcm) != count:
                fail(f'Jingle {name}: cut runs past the loop')
            ease = min(FADE_IN, len(pcm))
            pcm[:ease] *= np.linspace(0, 1, ease)[:, None]
        fade = min(FADE_OUT, len(pcm))
        pcm[-fade:] *= np.linspace(1, 0, fade)[:, None]
        write_ogg(args.out / 'jingles' / f'{name}.ogg', pcm, f'{prefix}/jingles/{name}.ogg', False)
        table = report['jingles'].setdefault(str(jingle['button']), {}).setdefault(jingle['kind'], {})
        table.setdefault(jingle['chord'], []).append(f'{prefix}/jingles/{name}.ogg')
    for button in report['jingles'].values():
        for kind in button.values():
            for chord in kind:
                kind[chord].sort()

    if mapping.get('arrival'):
        path = args.source / mapping['arrival']
        if not path.exists():
            fail(f'Arrival: missing file {path}')
        pcm = read_audio(path) * gain
        write_ogg(args.out / 'arrival.ogg', pcm, f'{prefix}/arrival.ogg', False)
        report['arrival'] = f'{prefix}/arrival.ogg'
        report['arrival_seconds'] = len(pcm) / RATE

    write_resource(args.out, prefix, stems)
    (args.out / 'score.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'{len(stems)} stems, {bars} bars at {bpm:g} bpm ({loop_seconds:.3f} s), '
          f'{len(mapping.get("jingles", []))} jingles, gain {report["common_gain_db"]:.1f} dB')


if __name__ == '__main__':
    main()
