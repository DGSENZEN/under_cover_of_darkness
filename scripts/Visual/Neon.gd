class_name Neon
extends RefCounted
## Neon for the Metro Underground's signs (the new standard, Oct 16 2026):
## a tube material, and the flicker patterns NeonSign plays.

const SHADER := preload("res://scripts/Visual/neon.gdshader")


## An unshaded glowing tube in `colour`; `energy` how far past white it burns
## (the glow and the tonemap take it from there).
static func material(colour: Color, energy: float = 4.0) -> ShaderMaterial:
	var out := ShaderMaterial.new()
	out.shader = SHADER
	out.set_shader_parameter("colour", colour)
	out.set_shader_parameter("energy", energy)
	out.set_shader_parameter("flicker", 1.0)
	return out


## A pattern letter's level: a off, m full; past m it sags toward z, half lit
## (a tired tube's dip, not a brighter flash).
static func level(letter: String) -> float:
	var c := letter.unicode_at(0) - "a".unicode_at(0)
	var m := "m".unicode_at(0) - "a".unicode_at(0)
	var z := "z".unicode_at(0) - "a".unicode_at(0)

	if c <= m:
		return clampf(float(c) / m, 0.0, 1.0)

	return 1.0 - 0.5 * clampf(float(c - m) / (z - m), 0.0, 1.0)
