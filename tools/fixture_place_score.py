#!/usr/bin/env python3
"""Rebuild the place score test score: python3 tools/fixture_place_score.py

Numpy clicks over quiet tones (test data only, never game audio) run through
the real tools/prepare_place_score.py into tests/fixtures/place_score/. At
240 bpm a bar is one second: a bed of 8 bars, theme a (8 bars: a calm lead, a
full lead, a pleading haunt), theme b (4 bars: a lead and its variant once the
curandera is met), theme c (4 bars, one stem, a circle in the lane), and a
one-bar cue that lands on bar 1. Every stem clicks on each bar's downbeat, so
offsets between players can be measured.
"""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'tests/fixtures/place_score'
RATE = 48000
BPM = 240
BAR = 4 * 60 / BPM
CLICK = round(0.004 * RATE)

MAP = {
    'bpm': BPM, 'beats_per_bar': 4, 'phrase_bars': 4, 'placeholder': True,
    'bed': {'bars': 8, 'stems': [
        {'id': 'drone_city', 'file': 'bed/drone_city.wav', 'role': 'drone_city'},
        {'id': 'drone_deep', 'file': 'bed/drone_deep.wav', 'role': 'drone_deep'},
        {'id': 'pulse', 'file': 'bed/pulse.wav', 'role': 'pulse'},
        {'id': 'room', 'file': 'bed/room.wav', 'role': 'room'}]},
    'cue': {'file': 'cue/enter.wav', 'lands_bar': 1},
    'themes': {
        'a': {'bars': 8, 'stems': [
            {'id': 'bass', 'file': 'a/bass.wav', 'part': 'bass'},
            {'id': 'lead', 'file': 'a/lead.wav', 'part': 'lead', 'intensity': 'calm'},
            {'id': 'lead_city', 'file': 'a/lead_city.wav', 'part': 'lead_city', 'intensity': 'calm', 'city': True},
            {'id': 'lead_full', 'file': 'a/lead_full.wav', 'part': 'lead_full', 'intensity': 'full'},
            {'id': 'haunt', 'file': 'a/haunt.wav', 'part': 'haunt', 'haunted': 'pleading'}]},
        'b': {'bars': 4, 'stems': [
            {'id': 'lead_met', 'file': 'b/lead_met.wav', 'part': 'lead', 'variant': {'character': 'curandera', 'when': 'met'}},
            {'id': 'lead', 'file': 'b/lead.wav', 'part': 'lead'}]},
        'c': {'bars': 4, 'stems': [
            {'id': 'lead', 'file': 'c/lead.wav', 'part': 'lead'}]}},
    'spaces': {'candle_lane': 'a', 'librarian_shop': 'b'},
    'circles': [{'theme': 'c', 'inside': 'candle_lane', 'at': [12.8, -11.0, 73.2], 'radius': 3.5, 'full': 1.5}],
}


def write_wav(path, pcm):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes((np.clip(pcm, -1, 1) * 32767).astype('<i2').tobytes())


def clicks(bars, pitch):
    """A click on each bar's downbeat over a quiet tone of its own pitch."""
    samples = round(bars * BAR * RATE)
    t = np.arange(samples) / RATE
    tone = 0.02 * np.sin(2 * np.pi * pitch * t)
    for bar in range(bars):
        start = round(bar * BAR * RATE)
        tone[start:start + CLICK] += 0.25
    return np.column_stack([tone, tone]).astype(np.float32)


def write_sources(source):
    source = Path(source)
    pitch = 110.0
    sets = dict(MAP['themes'])
    sets['bed'] = MAP['bed']
    for entry in sets.values():
        for stem in entry['stems']:
            pitch += 20.0
            write_wav(source / stem['file'], clicks(entry['bars'], pitch))
    write_wav(source / MAP['cue']['file'], clicks(1, 880.0))
    (source / 'map.json').write_text(json.dumps(MAP, indent=1) + '\n')


def main():
    sys.path.insert(0, str(ROOT / 'tools'))
    from prepare_place_score import prepare
    work = Path(tempfile.mkdtemp())
    try:
        write_sources(work)
        if OUT.exists():
            shutil.rmtree(OUT)
        prepare(work, OUT, 'res://tests/fixtures/place_score')
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    main()
