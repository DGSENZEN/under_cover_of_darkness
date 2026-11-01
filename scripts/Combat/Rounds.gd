extends RefCounted
## The cylinder's round types, as data: which pouch each comes from, what its
## hit counts as to a monster (Bestiary), what it leaves on one, and its
## casing's colour. To a man, every round is a bullet. Copal: the curanderas'
## resin packed behind the ball, so a spirit or an eye takes it as smoke.

const TABLE := {
	&"lead": {"stock": &"rounds", "source": &"lead", "colour": Color(0.55, 0.48, 0.3)},
	&"copal": {"stock": &"copal_rounds", "source": &"copal", "colour": Color(0.72, 0.55, 0.22), "status": &"smoked"},
}


## {stock, source, colour, status?}; {} for an unknown round.
static func info(id: StringName) -> Dictionary:
	return TABLE.get(id, {})
