#!/usr/bin/env python3
"""Small Standard MIDI File reader/writer for writing menu-theme parts.

Parts are lists of (start_beat, length_beats, pitch, velocity), with optional
controls (beat, kind, value): kind 'bend' (-1..1 of the bend range), 'bend_range'
(semitones, sent as RPN 0) or a CC number (0..127). Writing
gives a format-0 file at 480 ticks per beat with tempo, 4/4 and a track
name, ready for Logic's File > Import > MIDI File. Reading returns every
track's notes, so a Logic export can be analysed. Standard library only.
"""
from pathlib import Path
import struct

PPQ = 480
NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
# Intervals above the root for each chord quality this score uses.
QUALITIES = {
    '': (0, 4, 7), 'm': (0, 3, 7), 'dim': (0, 3, 6), 'aug': (0, 4, 8),
    '7': (0, 4, 7, 10), 'm7': (0, 3, 7, 10), 'maj7': (0, 4, 7, 11), 'm7b5': (0, 3, 6, 10),
    'dim7': (0, 3, 6, 9), '7b9': (0, 4, 7, 10, 13), 'mmaj7': (0, 3, 7, 11), 'm9': (0, 3, 7, 10, 14),
    'sus4': (0, 5, 7), 'm6': (0, 3, 7, 9),
}


def pitch_class(name):
    """'Eb' -> 3, 'C#' -> 1."""
    pc = NAMES[name[0]]
    for mark in name[1:]:
        pc += {'b': -1, '#': 1}[mark]
    return pc % 12


def _split(name):
    chord = name.split('/')[0]
    root = chord[:1] + (chord[1] if len(chord) > 1 and chord[1] in 'b#' else '')
    return root, chord[len(root):]


def chord_tones(name, octave):
    """MIDI notes of a chord in root position from `octave` (C4 = 60). A slash bass is ignored."""
    root, quality = _split(name)
    if quality not in QUALITIES:
        raise ValueError(f'Unknown chord quality in {name!r}')
    base = 12 * (octave + 1) + pitch_class(root)
    return [base + step for step in QUALITIES[quality]]


def bass_note(name, octave):
    """The chord's bass: the slash note if there is one, else the root."""
    note = name.split('/')[1] if '/' in name else _split(name)[0]
    return 12 * (octave + 1) + pitch_class(note)


def vlq(value):
    out = [value & 0x7F]
    value >>= 7
    while value:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    return bytes(reversed(out))


def _control(kind, value, channel):
    if kind == 'bend':
        bend = max(0, min(16383, round(8192 + float(value) * 8192)))
        return bytes([0xE0 | channel, bend & 0x7F, bend >> 7])
    if kind == 'bend_range':
        cc = 0xB0 | channel
        return bytes([cc, 101, 0, cc, 100, 0, cc, 6, int(value), cc, 38, 0, cc, 101, 127, cc, 100, 127])
    return bytes([0xB0 | channel, int(kind), max(0, min(127, int(value)))])


def _track(notes, ppq, channel=0, name='', program=None, bpm=None, controls=None):
    events = []
    for beat, kind, value in controls or []:
        # Before a note starting on the same tick, so a bend or range is in place for it.
        data = _control(kind, value, channel)
        if kind == 'bend_range':
            for i in range(0, len(data), 3):
                events.append((round(beat * ppq), 0.5, data[i:i + 3]))
        else:
            events.append((round(beat * ppq), 0.5, data))
    for start, length, pitch, velocity in notes:
        on = round(start * ppq)
        off = round((start + length) * ppq)
        events.append((off, 0, bytes([0x80 | channel, pitch, 0])))
        events.append((on, 1, bytes([0x90 | channel, pitch, velocity])))
    events.sort(key=lambda e: (e[0], e[1]))
    track = bytearray()
    if name:
        label = name.encode()
        track += b'\x00\xff\x03' + vlq(len(label)) + label
    if bpm is not None:
        tempo = round(60_000_000 / bpm)
        track += b'\x00\xff\x51\x03' + tempo.to_bytes(3, 'big')
        track += b'\x00\xff\x58\x04\x04\x02\x18\x08'
    if program is not None:
        track += b'\x00' + bytes([0xC0 | channel, program])
    now = 0
    for tick, _, data in events:
        track += vlq(tick - now) + data
        now = tick
    track += b'\x00\xff\x2f\x00'
    return b'MTrk' + struct.pack('>I', len(track)) + bytes(track)


def write_part(path, bpm, notes, ppq=PPQ, channel=0, name='', program=None):
    """One part as a format-0 file."""
    header = b'MThd' + struct.pack('>IHHH', 6, 0, 1, ppq)
    Path(path).write_bytes(header + _track(notes, ppq, channel, name, program, bpm))


def write_song(path, bpm, parts, ppq=PPQ):
    """Several parts as a format-1 file: a tempo track, then one track per part
    ({'name', 'notes', 'channel'=0, 'program'=None}), so one import makes them all."""
    chunks = [_track([], ppq, bpm=bpm)]
    for part in parts:
        chunks.append(_track(part['notes'], ppq, part.get('channel', 0), part.get('name', ''), part.get('program'),
                             controls=part.get('controls')))
    header = b'MThd' + struct.pack('>IHHH', 6, 1, len(chunks), ppq)
    Path(path).write_bytes(header + b''.join(chunks))


def _read_vlq(data, at):
    value = 0
    while True:
        byte = data[at]
        at += 1
        value = (value << 7) | (byte & 0x7F)
        if not byte & 0x80:
            return value, at


def read_midi(path):
    """{'ppq', 'bpm', 'tracks': [{'name', 'notes': [(start_beat, length_beats, pitch, velocity, channel)],
    'controls': [(beat, kind, value, channel)]}]} (an RPN 0 bend range is read back as 'bend_range')."""
    data = Path(path).read_bytes()
    if data[:4] != b'MThd':
        raise ValueError('Not a MIDI file')
    _, _, count, ppq = struct.unpack('>IHHH', data[4:14])
    at = 14
    song = {'ppq': ppq, 'bpm': 120.0, 'tracks': []}
    tempo_found = False
    for _ in range(count):
        if data[at:at + 4] != b'MTrk':
            raise ValueError('Bad track chunk')
        length = struct.unpack('>I', data[at + 4:at + 8])[0]
        at += 8
        end = at + length
        tick, status, name, held, notes, controls, rpn = 0, 0, '', {}, [], [], {}
        while at < end:
            delta, at = _read_vlq(data, at)
            tick += delta
            if data[at] & 0x80:
                status = data[at]
                at += 1
            if status == 0xFF:
                kind = data[at]
                size, at = _read_vlq(data, at + 1)
                body = data[at:at + size]
                at += size
                if kind == 0x03:
                    name = body.decode(errors='replace')
                elif kind == 0x51 and not tempo_found:
                    song['bpm'] = 60_000_000 / int.from_bytes(body, 'big')
                    tempo_found = True
            elif status in (0xF0, 0xF7):
                size, at = _read_vlq(data, at)
                at += size
            else:
                kind, channel = status & 0xF0, status & 0x0F
                width = 1 if kind in (0xC0, 0xD0) else 2
                args = data[at:at + width]
                at += width
                if kind == 0xE0:
                    controls.append((tick / ppq, 'bend', ((args[1] << 7 | args[0]) - 8192) / 8192, channel))
                elif kind == 0xB0 and args[0] in (101, 100, 6, 38):
                    rpn[(channel, args[0])] = args[1]
                    if args[0] == 6 and rpn.get((channel, 101)) == 0 and rpn.get((channel, 100)) == 0:
                        controls.append((tick / ppq, 'bend_range', args[1], channel))
                elif kind == 0xB0:
                    controls.append((tick / ppq, args[0], args[1], channel))
                elif kind == 0x90 and args[1] > 0:
                    held.setdefault((channel, args[0]), []).append((tick, args[1]))
                elif kind == 0x80 or (kind == 0x90 and args[1] == 0):
                    starts = held.get((channel, args[0]))
                    if starts:
                        on, velocity = starts.pop(0)
                        notes.append((on / ppq, (tick - on) / ppq, args[0], velocity, channel))
        at = end
        song['tracks'].append({'name': name, 'notes': sorted(notes), 'controls': controls})
    return song
