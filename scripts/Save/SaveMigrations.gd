extends RefCounted
## What a save from an older build becomes in this one (the save and load
## spec, section 8). Each save's header carries the version it was written
## at; reading it passes the body through every step from there up to
## CURRENT, in order. A save newer than CURRENT is refused, never half-read.
##
## Bump CURRENT when a save_state() changes what one of its keys means, and
## add the step that turns the old meaning into the new one. A new key with a
## default in load_state needs no bump.

const CURRENT := 1

## {from: Callable(body) -> body}: the step from version `from` to from + 1.
## None yet; the first would read like:
##   1: func(body): body["city"]["purse"] = body["city"].get("coins", 0); return body
const STEPS := {}


static func readable(version: int) -> bool:
	return version >= 1 and version <= CURRENT


## `body` (written at version `from`) as this build reads it.
static func migrate(body: Dictionary, from: int) -> Dictionary:
	for version in range(from, CURRENT):
		if STEPS.has(version):
			body = (STEPS[version] as Callable).call(body)

	return body
