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
	# Souls no one lit a candle for: what they drink, how they come. Copal hurts them;
	# lead passes through; a shell's few pellets that tell are a poor answer.
	&"anima": {
		"health": 70.0,
		"weak": {&"copal": 1.0},
		"resist": {&"lead": 0.15, &"shot": 0.5},
		"lead_read": &"through",
		"forms": {
			&"hands": {"swipe_damage": 6.0, "swipe_reach": 1.7, "swipe_wind": 0.32, "health": 40.0, "power_drain": 5.0, "life_drain": 1.5, "grip": 1, "speed": 2.6, "tell": 0.55, "leap_reach": 2.6, "leap_speed": 8.0, "hit_radius": 0.4, "height": 0.25, "floats": false},
			&"face": {"swipe_damage": 10.0, "swipe_reach": 2.0, "swipe_wind": 0.42, "health": 70.0, "power_drain": 8.0, "life_drain": 2.5, "grip": 1, "speed": 2.1, "tell": 0.7, "leap_reach": 3.4, "leap_speed": 7.5, "hit_radius": 0.4, "height": 1.3, "floats": true},
			&"torso": {"swipe_damage": 14.0, "swipe_reach": 2.2, "swipe_wind": 0.95, "health": 130.0, "power_drain": 12.0, "life_drain": 4.0, "grip": 2, "speed": 0.85, "tell": 1.5, "leap_reach": 3.6, "leap_speed": 4.8, "hit_radius": 0.95, "height": 0.5, "floats": false,
				# It is a great many dragged along as one: all of this is how heavy that is (Anima.gd).
				"hauls": true, "inertia": 3.0, "leap_gathers": 0.45, "rise_time": 1.0, "wake_time": 1.0, "missed_time": 1.7, "swipe_time": 0.34, "swipe_lunge": 1.2, "back_off_time": 1.1, "back_off_speed": 1.05, "circle_speed": 0.8, "edges_round": 0.5, "throw_speed": 5.0},
		},
	},
}


## {health, weak, resist}; {} for an unknown kind.
static func info(kind: StringName) -> Dictionary:
	return TABLE.get(kind, {})


## One of a kind's forms, {} if it has none by that name.
static func form(kind: StringName, form_id: StringName) -> Dictionary:
	return info(kind).get("forms", {}).get(form_id, {})


## What a blow counts as: a bullet its round's source; a shell's pellets, a
## blast, a shard and fire themselves; anything else, a blow.
static func source_of(hit_kind: StringName, round_id: StringName) -> StringName:
	match hit_kind:
		&"bullet":
			return Rounds.info(round_id).get("source", &"lead")
		&"shot", &"blast", &"fire":
			return hit_kind
		&"shard", &"burst":
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
