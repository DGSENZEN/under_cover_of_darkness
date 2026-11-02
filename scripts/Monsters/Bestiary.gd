extends RefCounted
## The monsters, as data: each kind's health, what it is weak to and what it
## shrugs off, by what a hit counts as (a "source"). A weak source's number
## is what it does to that kind; so is a resisted one's. New kinds and
## variants are new rows (docs/superpowers/specs/2026-11-01-hunt-combat-
## design.md).

const Rounds := preload("res://scripts/Combat/Rounds.gd")

const TABLE := {
	&"floating_eye": {
		"health": 120.0,
		"weak": {&"shot": 1.0, &"copal": 1.2, &"obsidian": 1.5, &"blast": 1.5},
		"resist": {&"lead": 0.3},
	},
}


## {health, weak, resist}; {} for an unknown kind.
static func info(kind: StringName) -> Dictionary:
	return TABLE.get(kind, {})


## What a blow counts as: a bullet its round's source; a shell's pellets, a
## blast, a shard and fire themselves; anything else, a blow.
static func source_of(hit_kind: StringName, round_id: StringName) -> StringName:
	match hit_kind:
		&"bullet":
			return Rounds.info(round_id).get("source", &"lead")
		&"shot", &"blast", &"fire":
			return hit_kind
		&"shard":
			return &"obsidian"

	return &"blow"


## What `source` does to `kind`, as a multiple of its damage.
static func scale_for(kind: StringName, source: StringName) -> float:
	var entry := info(kind)
	return float(entry.get("weak", {}).get(source, entry.get("resist", {}).get(source, 1.0)))


static func is_weak(kind: StringName, source: StringName) -> bool:
	return info(kind).get("weak", {}).has(source)


static func is_resisted(kind: StringName, source: StringName) -> bool:
	return info(kind).get("resist", {}).has(source)
