extends RefCounted
## The library's words (docs/superpowers/specs/2026-10-17-librarian-shop-design.md, "Words"): the invented script that
## stands in until the user writes theirs, and the atlases words are drawn from (tools/textures/library_glyphs.py bakes
## them: `script`, our own forty glyphs on U+E000 on; `latin`, Spanish and Latin with their accents, from a font).
## Any atlas the tool bakes from any font works in its place.

const FIRST := 0xE000
const COUNT := 40
const SOURCE := "res://assets/eclipse/source/glyphs_%s.json"
const IMAGE := "res://textures/painted/library/glyphs_%s.png"


## `count` glyphs of the invented script in words of two to seven, the same for the same `seed`.
static func script(seed: int, count: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var words: Array[String] = []
	var left := count
	while left > 0:
		var n := rng.randi_range(2, 7)
		# (Never a lone glyph left over at the end.)
		if left - n == 1:
			n = n + 1 if n < 7 else n - 1
		n = mini(n, left)
		var word := ""
		for i in n:
			word += char(FIRST + rng.randi_range(0, COUNT - 1))
		words.append(word)
		left -= n
	return " ".join(words)


## An atlas by name: its texture, its grid, where each character sits, how wide it runs, where the fallback is.
static func atlas(name: String) -> Dictionary:
	var path := SOURCE % name
	if not FileAccess.file_exists(path):
		return {}
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var chars := {}
	for ch: String in raw["chars"]:
		var at: Array = raw["chars"][ch]
		chars[ch] = Vector2i(int(at[0]), int(at[1]))
	var fallback: Array = raw["fallback"]
	return {"name": name, "texture": load(IMAGE % name), "cols": int(raw["cols"]), "rows": int(raw["rows"]),
		"chars": chars, "advance": raw.get("advance", {}), "fallback": Vector2i(int(fallback[0]), int(fallback[1]))}


## Where `ch` sits in `atlas` (its fallback if it has no such character).
static func cell_of(atlas: Dictionary, ch: String) -> Vector2i:
	return atlas["chars"].get(ch, atlas["fallback"])


## How wide `ch` runs in `atlas`, of a glyph's size.
static func advance_of(atlas: Dictionary, ch: String) -> float:
	return float(atlas["advance"].get(ch, 0.7))
