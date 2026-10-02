extends RefCounted
## Deterministic flame flicker in [-1, 1], used by Torch as energy * (1 + flicker * value).
## Kind selects puff rate; salt decorrelates phases. Puff, half-harmonic, and drift weights sum to one.
## A candle is steady until draft() supplies a brief high-frequency disturbance.

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

## salt -> its three phases, drawn once.
static var _phases := {}


## The waver of a flame of `kind` at time `t` (s), -1..1.
static func value(kind: StringName, t: float, salt: int) -> float:
	var rate: float = KINDS.get(kind, KINDS[&"torch"])

	if rate <= 0.0:
		return 0.0

	var phases: Vector3 = _phases.get(salt, Vector3.INF)

	if phases == Vector3.INF:
		var rng := RandomNumberGenerator.new()
		rng.seed = salt
		phases = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU

		if _phases.size() > 4096:
			_phases.clear()

		_phases[salt] = phases

	return (
		0.55 * sin(TAU * rate * t + phases.x)
		+ 0.25 * sin(TAU * 1.73 * rate * t + phases.y)
		+ 0.2 * sin(TAU * DRIFT * t + phases.z)
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
