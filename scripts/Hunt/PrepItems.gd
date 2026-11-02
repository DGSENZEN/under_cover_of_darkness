extends RefCounted
## What you can pack beside the gun, as data: what each one takes off you, how
## long the hand is busy with it, how many you carry, and whether it is sent back
## at what is watching you (`returns`, how far). The egg: the curanderas' limpia,
## rolled over you, draws the evil eye out into itself and back on the eyes that
## cast it: they squeeze shut, and you are clean of it for a while.

const TABLE := {
	&"egg": {"cures": &"evil_eye", "use_time": 1.0, "carry": 2, "colour": Color(0.9, 0.86, 0.76), "returns": 14.0, "leaves": &"cleansed", "leaves_for": 12.0},
}


## {cures, use_time, carry}; {} for an unknown item.
static func info(id: StringName) -> Dictionary:
	return TABLE.get(id, {})
