class_name PlaceClock
## A place score's musical time (PlaceScore), from its bed's position in
## seconds. Pure functions: PlaceScore reads its players through them, tests
## call them. Bed time runs on across the bed's loops; a theme started at bed
## time t plays from theme_offset(t, its loop), so it is in step with the bed.

static func bar_seconds(bpm: float, beats_per_bar: int) -> float:
	return MenuClock.beat_seconds(bpm) * beats_per_bar

static func phrase_seconds(bpm: float, beats_per_bar: int, phrase_bars: int) -> float:
	return bar_seconds(bpm, beats_per_bar) * phrase_bars

## The first phrase line from pos on (pos's own line if just past one).
static func next_phrase_line(pos: float, phrase: float) -> float:
	var before := floorf(pos / phrase) * phrase
	if pos - before <= MenuClock.SLACK:
		return before
	return before + phrase

## Where in its own loop a theme is at bed time bed_pos.
static func theme_offset(bed_pos: float, theme_loop: float) -> float:
	return fposmod(bed_pos, theme_loop)

## What is actually being heard (Godot's audio sync guidance).
static func heard(position: float, since_mix: float, latency: float) -> float:
	return MenuClock.corrected(position, since_mix, latency)
