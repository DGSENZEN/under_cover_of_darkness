class_name MenuClock
## The menu score's musical time, from the stem player's position in seconds.
## Pure functions: MenuMusic reads its player through them, tests call them.

## Within this long after a boundary a press still counts as on it.
const SLACK := 0.005

static func beat_seconds(bpm: float) -> float:
	return 60.0 / bpm

static func bar_at(pos: float, bpm: float, beats_per_bar: int) -> int:
	return floori(pos / (beat_seconds(bpm) * beats_per_bar))

## The first eighth-note boundary from pos on (pos itself if just past one).
static func next_eighth(pos: float, bpm: float) -> float:
	var eighth := beat_seconds(bpm) * 0.5
	var before := floorf(pos / eighth) * eighth
	if pos - before <= SLACK:
		return before
	return before + eighth

## The chord sounding in a bar: the last entry at or before it, with the loop.
static func chord_at(chords: Array, bar: int, bars: int) -> String:
	if chords.is_empty():
		return ""
	var in_loop := posmod(bar, maxi(bars, 1))
	var name := String(chords[0]["name"])
	for chord in chords:
		if int(chord["bar"]) <= in_loop:
			name = String(chord["name"])
	return name

## When the phrase playing at pos ends.
static func phrase_end_after(pos: float, bpm: float, beats_per_bar: int, phrase_bars: int) -> float:
	var phrase := beat_seconds(bpm) * beats_per_bar * phrase_bars
	return (floorf(pos / phrase) + 1.0) * phrase

## What is actually being heard: the player's position plus time since the
## last mix, minus output latency (Godot's audio sync guidance).
static func corrected(position: float, since_mix: float, latency: float) -> float:
	return maxf(position + since_mix - latency, 0.0)
