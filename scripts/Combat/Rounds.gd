extends RefCounted
## The cylinder's round types, as data: which pouch each comes from, what its
## hit counts as to a monster (Bestiary), what it leaves on one, and its
## casing's colour. To a man, every round is a bullet. Copal: the curanderas'
## resin packed behind the ball, so a spirit or an eye takes it as smoke. Each is
## told apart at a glance: cold grey lead, hot amber copal, on the readout, on your
## aim, in the air and on what it hits.

const TABLE := {
	&"lead": {"stock": &"rounds", "source": &"lead", "colour": Color(0.62, 0.66, 0.72),
		"tracer_core": Color("#F2F5F8"), "tracer_edge": Color("#7C8794"), "tracer_width": 0.016, "tracer_life": 0.07},
	&"copal": {"stock": &"copal_rounds", "source": &"copal", "colour": Color(1.0, 0.58, 0.12), "status": &"smoked", "cloud": true,
		"tracer_core": Color("#FFB04A"), "tracer_edge": Color("#D8600F"), "tracer_energy": 1.3, "tracer_width": 0.055, "tracer_life": 0.16, "trail": true},
	# For the shot barrel, not the cylinder: it takes the place copal would. Few, and light: what it does is burn. It is what keeps the drowned down.
	&"fire": {"stock": &"fire_shells", "source": &"fire", "colour": Color(1.0, 0.36, 0.08), "shell": true, "pellet_damage": 5.0,
		"tracer_core": Color("#FFD27A"), "tracer_edge": Color("#E04A10"), "tracer_energy": 1.6, "tracer_width": 0.05, "tracer_life": 0.14},
}


## {stock, source, colour, status?}; {} for an unknown round.
static func info(id: StringName) -> Dictionary:
	return TABLE.get(id, {})
