extends RefCounted
## The spells, as data: each one's school, tier, cost from the power pool,
## and how long it takes to cast. The more powerful a spell, the longer it
## takes: innate spells (cantrips) at once, a hand spell while its circle
## closes, a tome spell while the pages turn and the words are said. New
## schools' spells are new rows (docs/superpowers/specs/2026-10-23-revolver-
## and-magic-design.md).

enum Tier {
	INNATE,
	HAND,
	TOME,
}

const TABLE := {
	&"blink": {"school": &"obsidian", "tier": Tier.INNATE, "cost": 20.0, "cast_time": 0.0, "movement": true},
	&"shard": {"school": &"obsidian", "tier": Tier.HAND, "cost": 15.0, "cast_time": 0.4, "movement": false},
	&"ward": {"school": &"copal", "tier": Tier.HAND, "cost": 35.0, "cast_time": 0.4, "movement": false},
	&"empower": {"school": &"nahual", "tier": Tier.TOME, "cost": 50.0, "cast_time": 1.2, "movement": false},
}


## {school, tier, cost, cast_time, movement}; {} for an unknown spell.
static func info(id: StringName) -> Dictionary:
	return TABLE.get(id, {})


static func all() -> Array[StringName]:
	var ids: Array[StringName] = []

	for id in TABLE.keys():
		ids.append(id)

	return ids
