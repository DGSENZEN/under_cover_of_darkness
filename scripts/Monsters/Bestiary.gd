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
	# The drowned of the old lakebed, raised by the seepage: a body, so copal is only a ball to it. Fire is what keeps it dead (Revenant.gd).
	&"revenant": {
		"health": 540.0,
		"resist": {&"lead": 0.3, &"copal": 0.3, &"shot": 0.5},
		"speed": 1.6, "hit_radius": 0.55, "height": 2.6, "turns": 1.7, "steps_winding": 0.55,
		"surge_every": [4.0, 7.0], "surge_tell": 0.5, "surge_speed": 6.0, "surge_time": 0.9, "surge_from": 3.6,
		"swipe_reach": 2.4, "swipe_wind": 1.0, "swipe_damage": 25.0, "swipe_time": 0.45,
		"rake_reach": 2.2, "rake_wind": 1.35, "rake_damage": 35.0, "rake_time": 0.6,
		"grasp_reach": 3.0, "grasp_wind": 1.4, "grasp_damage": 5.0, "grasp_hold": 1.0, "grasp_time": 0.5, "touch_grace": 1.5, "grasp_chance": 0.4,
		"bite_reach": 2.6, "bite_wind": 0.85, "bite_damage": 30.0, "bite_time": 0.4, "bite_chance": 0.35, "finds": 0.3, "lurches": 5.2, "keeps_off": 2.0, "shoves": 8.0, "between_attacks": 0.9, "shove_time": 0.4, "stagger_time": 0.55,
		"soaked_time": 8.0, "soaked_stamina": 0.4,
		"down_time": 5.0, "rise_time": 1.6, "rises_with": 0.4,
		"dies_in": 3.2, "burn_time": 5.0, "burn_rate": 8.0, "seared_time": 3.0, "brazier_shoves": 0.085, "push_takes": 0.15, "thrown_takes": 0.8,
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
			&"torso": {"swipe_damage": 14.0, "swipe_reach": 2.2, "swipe_wind": 1.35, "health": 130.0, "power_drain": 12.0, "life_drain": 4.0, "grip": 2, "speed": 0.6, "tell": 2.0, "leap_reach": 3.0, "leap_speed": 3.4, "hit_radius": 0.95, "height": 0.5, "floats": false,
				# It is a great many dragged along as one: all of this is how heavy that is (Anima.gd).
				"hauls": true, "inertia": 1.8, "leap_gathers": 0.75, "rise_time": 1.5, "wake_time": 1.5, "missed_time": 2.4, "swipe_time": 0.5, "swipe_lunge": 0.7, "back_off_time": 1.4, "back_off_speed": 0.7, "circle_speed": 0.5, "edges_round": 0.3, "throw_speed": 3.5,
				# The elite: what it starts as, what each it takes does to it, and how it goes about taking them.
				"elite": {"health": 380.0, "start_size": 1.08, "grows": 0.12, "heals": 0.3, "most_taken": 3, "swipe_up": 0.2, "drain_up": 0.25, "slows": 0.08, "swipe_reach_up": 0.2, "leap_reach_up": 0.3, "hungry_below": 0.667, "hungry_every": 6.0, "looks_within": 5.5, "seizes_within": 2.6, "seizes_up": 0.3, "gives_up": 6.0, "drags": 1.2}},
		},
	},
}


## {health, weak, resist}; {} for an unknown kind.
static func info(kind: StringName) -> Dictionary:
	return TABLE.get(kind, {})


## The elite mouth's numbers, as it stands having taken `taken`.
static func elite_form(taken: int) -> Dictionary:
	var base: Dictionary = form(&"anima", &"torso").duplicate()
	var row: Dictionary = base["elite"]
	var scale: float = float(row["start_size"]) * (1.0 + float(row["grows"]) * float(taken))
	base["health"] = row["health"]
	base["size"] = scale
	base["hit_radius"] = float(base["hit_radius"]) * scale
	base["swipe_damage"] = float(base["swipe_damage"]) * (1.0 + float(row["swipe_up"]) * float(taken))
	base["life_drain"] = float(base["life_drain"]) * (1.0 + float(row["drain_up"]) * float(taken))
	base["speed"] = float(base["speed"]) * (1.0 - float(row["slows"]) * float(taken))
	base["swipe_reach"] = float(base["swipe_reach"]) + float(row["swipe_reach_up"]) * float(taken)
	base["leap_reach"] = float(base["leap_reach"]) + float(row["leap_reach_up"]) * float(taken)
	return base


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
		&"brazier", &"splash":
			return &"fire"
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
