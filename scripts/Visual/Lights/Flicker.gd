extends RefCounted
## How a flame wavers, as a number from -1 to 1 that a light's energy swings
## by (Torch.gd: energy × (1 + flicker × value)).
##
## Flames puff at a rate set by their size: about 1.5 / sqrt(width) Hz, so a
## torch flutters and a campfire heaves slowly. Each kind's value is its puff,
## a quicker half-harmonic that never lines up with it, and a slow drift,
## weighted 0.55 + 0.25 + 0.2, so it can never leave -1..1 and its strongest
## frequency is always its puff rate. The phases come from `salt`, so no two
## flames breathe together but each always breathes the same.
##
## A lone candle in still air does not flicker at all. A draft (a door, a man
## running past) makes it shiver about ten times a second for a second.

## kind -> puff rate (Hz). 0: still.
const KINDS := {
	&"candle": 0.0,
	&"lamp": 4.5,
	&"torch": 5.0,
	&"cresset": 3.5,
	&"brazier": 2.4,
	&"fire": 1.7,
}
const DRIFT := 0.4
const DRAFT_RATE := 10.0
const DRAFT_TIME := 1.0


## The waver of a flame of `kind` at time `t` (s), -1..1.
static func value(kind: StringName, t: float, salt: int) -> float:
	var rate: float = KINDS.get(kind, KINDS[&"torch"])

	if rate <= 0.0:
		return 0.0

	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	return (
		0.55 * sin(TAU * rate * t + p1)
		+ 0.25 * sin(TAU * 1.73 * rate * t + p2)
		+ 0.2 * sin(TAU * DRIFT * t + p3)
	)


## A draft's shiver `since` seconds after it began: fast, dying away, gone
## after DRAFT_TIME.
static func draft(since: float) -> float:
	if since < 0.0 or since >= DRAFT_TIME:
		return 0.0

	var left := 1.0 - since / DRAFT_TIME
	return sin(TAU * DRAFT_RATE * since) * left * left


## A flame's own salt, from where it stands (to the centimetre).
static func seed_of(at: Vector3) -> int:
	var x := int(round(at.x * 100.0))
	var y := int(round(at.y * 100.0))
	var z := int(round(at.z * 100.0))
	return absi(hash(Vector3i(x, y, z)))
