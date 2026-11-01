extends RefCounted
## What you can pack beside the gun, as data: what each one takes off you, how
## long the hand is busy with it, and how many you carry. The egg: the
## curanderas' limpia, rolled over you, draws the evil eye off into itself.

const TABLE := {
	&"egg": {"cures": &"evil_eye", "use_time": 0.8, "carry": 2, "colour": Color(0.9, 0.86, 0.76)},
}


## {cures, use_time, carry}; {} for an unknown item.
static func info(id: StringName) -> Dictionary:
	return TABLE.get(id, {})
