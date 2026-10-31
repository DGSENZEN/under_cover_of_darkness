#!/usr/bin/env python3
"""Render a place score: python3 tools/prepare_place_score.py [--source DIR] [--out DIR] [--res-prefix res://...]

Reads <source>/map.json (see docs/systems/audio.md, "Metro score") and the
Logic exports it names, and writes to <out>:
  bed/<stem id>.ogg, <theme>/<stem id>.ogg   one seamless loop per stem, each set's stems one length
  bed.tres, <theme>.tres                     AudioStreamSynchronized per set, its stems in map order
  cue.ogg                                    the entrance cue, when the map names one
  score.json                                 the map's frame, roles, spaces and circles, plus
                                             each set's resource and stems' indices, levels, hashes
The bed and every theme loop at a whole number of phrases on one frame, so any
theme can come in on any of the bed's phrase lines.
Requires ffmpeg, libsndfile (with Vorbis) and numpy, as tools/prepare_menu_score.py.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_menu_score import RATE, fit, read_audio, write_ogg, write_resource  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/audio/source/metro_score'
OUTPUT = ROOT / 'audio/music/metro'
# AudioStreamSynchronized's limit.
MAX_STEMS = 32
# The stems' own fields that score.json carries (the file is the source's business).
KEPT = ('id', 'role', 'part', 'intensity', 'city', 'haunted', 'variant')


def fail(message):
    raise SystemExit(message)


def sets_of(mapping):
    """The bed first, then the themes in map order: [(name, entry)]."""
    return [('bed', mapping['bed'])] + list(mapping['themes'].items())


def prepare(source, out, prefix):
    source, out, prefix = Path(source), Path(out), prefix.rstrip('/')
    mapping = json.loads((source / 'map.json').read_text())
    bpm, bar_beats, phrase = float(mapping['bpm']), int(mapping['beats_per_bar']), int(mapping['phrase_bars'])
    bar_seconds = bar_beats * 60.0 / bpm

    audio = {}
    for name, entry in sets_of(mapping):
        bars = int(entry['bars'])
        if bars <= 0 or bars % phrase:
            fail(f'{name}: {bars} bars is not a whole number of {phrase}-bar phrases')
        if len(entry['stems']) > MAX_STEMS:
            fail(f'{name}: {len(entry["stems"])} stems, more than {MAX_STEMS}')
        samples = round(bars * bar_seconds * RATE)
        for stem in entry['stems']:
            path = source / stem['file']
            if not path.exists():
                fail(f'Stem {name}/{stem["id"]}: missing file {path}')
            audio[(name, stem['id'])] = fit(read_audio(path), samples) * 10 ** (float(stem.get('trim_db', 0)) / 20)

    # One common gain for the bed, every theme and the cue, from all of them
    # sounding at once (each set tiled to the longest), as the menu score.
    longest = max(len(pcm) for pcm in audio.values())
    mix = np.zeros((longest, 2), dtype=np.float32)
    for pcm in audio.values():
        mix += np.tile(pcm, (longest // len(pcm) + 1, 1))[:longest]
    gain = min(10 ** (-8 / 20), 0.70 / max(float(np.max(np.abs(mix))), 1e-12))

    out.mkdir(parents=True, exist_ok=True)
    report = dict(bpm=bpm, beats_per_bar=bar_beats, phrase_bars=phrase, sample_rate=RATE,
                  placeholder=bool(mapping.get('placeholder', False)), common_gain_db=float(20 * np.log10(gain)),
                  bed=None, themes={}, cue=None, spaces=mapping.get('spaces', {}), circles=mapping.get('circles', []))
    for name, entry in sets_of(mapping):
        bars = int(entry['bars'])
        stems = []
        for index, stem in enumerate(entry['stems']):
            pcm = audio[(name, stem['id'])] * gain
            write_ogg(out / name / f'{stem["id"]}.ogg', pcm, f'{prefix}/{name}/{stem["id"]}.ogg', True,
                      bpm, bars * bar_beats, bar_beats)
            kept = {key: stem[key] for key in KEPT if key in stem}
            stems.append(dict(kept, index=index, peak_db=float(20 * np.log10(max(float(np.max(np.abs(pcm))), 1e-9))),
                              sha256=hashlib.sha256((source / stem['file']).read_bytes()).hexdigest()))
        # The menu's writer names its file score.tres: one per set, renamed.
        write_resource(out, f'{prefix}/{name}', entry['stems'])
        (out / 'score.tres').replace(out / f'{name}.tres')
        made = dict(bars=bars, loop_seconds=bars * bar_seconds, resource=f'{prefix}/{name}.tres', stems=stems)
        if name == 'bed':
            report['bed'] = made
        else:
            report['themes'][name] = made

    cue = mapping.get('cue')
    if cue:
        path = source / cue['file']
        if not path.exists():
            fail(f'Cue: missing file {path}')
        pcm = read_audio(path) * gain
        write_ogg(out / 'cue.ogg', pcm, f'{prefix}/cue.ogg', False)
        report['cue'] = dict(path=f'{prefix}/cue.ogg', seconds=len(pcm) / RATE, lands_bar=int(cue.get('lands_bar', 0)))

    (out / 'score.json').write_text(json.dumps(report, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--out', type=Path, default=OUTPUT)
    parser.add_argument('--res-prefix', default='res://audio/music/metro')
    args = parser.parse_args()
    report = prepare(args.source, args.out, args.res_prefix)
    print(f'bed {report["bed"]["bars"]} bars + {len(report["themes"])} themes at {report["bpm"]:g} bpm, '
          f'gain {report["common_gain_db"]:.1f} dB{" (placeholder)" if report["placeholder"] else ""}')


if __name__ == '__main__':
    main()
