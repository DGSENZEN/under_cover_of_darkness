extends RefCounted
## Ordered course timing; best times stay separate for each station and
## physics/time preset, so slow-motion runs cannot replace normal records.

var station := -1
var gate_count := 3
var next_gate := 0
var running := false
var finished := false
var elapsed := 0.0
var splits: Array[float] = []
var best := {}
var attempts := {}
var preset := "60 Hz / 1.0x"
var _records := {}

## Selects zero-based station index and count gates; setting identifies the physics/time preset.
## Clears the current run, retains per-preset best records and increments attempts.
func reset(index: int, count := 3, setting := "60 Hz / 1.0x") -> void:
	station = index
	gate_count = count
	preset = setting
	next_gate = 0
	running = false
	finished = false
	elapsed = 0.0
	splits.clear()
	best = _records.get(preset, {})
	attempts[index] = attempts.get(index, 0) + 1

## Adds simulation seconds delta only while a run is active.
func tick(delta: float) -> void:
	if running:
		elapsed += delta

## Accepts the next zero-based gate; returns false for out-of-order or finished runs.
## Gate zero starts timing; the final gate stores the best elapsed time for this preset.
func reach(gate: int) -> bool:
	if finished or gate != next_gate:
		return false
	if gate == 0:
		running = true
	splits.append(elapsed)
	next_gate += 1
	if next_gate == gate_count:
		running = false
		finished = true
		best[station] = minf(best.get(station, INF), elapsed)
		_records[preset] = best
	return true
