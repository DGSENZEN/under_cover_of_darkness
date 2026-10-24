extends RefCounted
## The words conditions and effects are written in, shared by the job files
## (data/jobs/*.job) and the character files (data/dialogue/*.dialogue).
##
## A condition is terms joined by commas, all of which must hold:
##   took(x) arrived(x) done(x) loot>=n    the job's own (JobBook)
##   said(x) gave(x) mood>=n mood<=n met   about the character whose file it is
##   said(c.x) gave(c.x) mood(c)>=n        about another character, by id
##   has(x) purse>=n                       about the player
##   not(<term>)                           any of them turned round
## An effect is one change a beat makes: set(f) clear(f) give(i) take(i)
## pay(n) charge(n) goal(g) done(g) note(n) mood(+n) mood(-n) shade(<state>).
## A .job file has no character of its own, so there the undotted said, gave
## and mood, and met, are errors. Each check answers "" or what is wrong.

## The job's own terms (what JobBook always knew), written as name(word).
const BASE := ["took", "arrived", "done"]
## Terms that name a flag or an item of a character, dotted for another's.
const OWNED := ["said", "gave"]
## The states a character's shade may rest in.
const SHADES := ["flare", "dim", "gutter", "calm"]
## Effects that take one word: set(f), clear(f), give(i), take(i), goal(g),
## done(g), note(n).
const WORD_EFFECTS := ["set", "clear", "give", "take", "goal", "done", "note"]
## Effects that take a whole number: pay(n), charge(n).
const NUMBER_EFFECTS := ["pay", "charge"]


## "" if `term` is a condition's term, else what is wrong. `in_character` is
## true in a character's file (its own said, gave, mood and met are there).
static func term_error(term: String, in_character: bool) -> String:
	if term.begins_with("not(") and term.ends_with(")"):
		return term_error(term.substr(4, term.length() - 5).strip_edges(), in_character)

	if _matches("^loot\\s*>=\\s*[0-9]+$", term) or _matches("^purse\\s*>=\\s*[0-9]+$", term):
		return ""

	if _matches("^has\\([A-Za-z0-9_]+\\)$", term):
		return ""

	if _matches("^mood\\([A-Za-z0-9_]+\\)\\s*(>=|<=)\\s*-?[0-9]+$", term):
		return ""

	var called := RegEx.create_from_string("^([a-z_]+)\\(([A-Za-z0-9_]+)(\\.[A-Za-z0-9_]+)?\\)$").search(term)

	if called != null:
		var name := called.get_string(1)
		var dotted := called.get_string(3) != ""

		if BASE.has(name) and not dotted:
			return ""

		if OWNED.has(name):
			if dotted or in_character:
				return ""

			return "'%s' needs a character: %s(<character>.<name>), a .job file has none of its own" % [term, name]

	if _matches("^mood\\s*(>=|<=)\\s*-?[0-9]+$", term) or term == "met":
		if in_character:
			return ""

		return "'%s' needs a character, a .job file has none of its own" % term

	return "'%s' is not a condition (%s)" % [term, _condition_words(in_character)]


## "" if `cond` is terms joined by commas, each one fine, else what is wrong.
static func condition_error(cond: String, in_character: bool) -> String:
	if cond.strip_edges() == "":
		return "an empty condition"

	for term in split_top(cond):
		var problem := term_error(String(term), in_character)

		if problem != "":
			return problem

	return ""


## "" if `effect` is one change a beat may make, else what is wrong.
static func effect_error(effect: String) -> String:
	var called := RegEx.create_from_string("^([a-z_]+)\\((.*)\\)$").search(effect)

	if called != null:
		var name := called.get_string(1)
		var arg := called.get_string(2).strip_edges()

		if WORD_EFFECTS.has(name) and _matches("^[A-Za-z0-9_]+$", arg):
			return ""

		if NUMBER_EFFECTS.has(name) and _matches("^[0-9]+$", arg):
			return ""

		if name == "mood" and _matches("^[+-][0-9]+$", arg):
			return ""

		if name == "shade" and SHADES.has(arg):
			return ""

	return "'%s' is not an effect (%s)" % [effect, _effect_words()]


## `text` cut at the commas outside parentheses, each piece trimmed.
static func split_top(text: String) -> PackedStringArray:
	var out := PackedStringArray()

	if text.strip_edges() == "":
		return out

	var depth := 0
	var piece := ""

	for ch in text:
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth = maxi(depth - 1, 0)

		if ch == "," and depth == 0:
			out.append(piece.strip_edges())
			piece = ""
		else:
			piece += ch

	out.append(piece.strip_edges())
	return out


static func _matches(pattern: String, text: String) -> bool:
	return RegEx.create_from_string(pattern).search(text) != null


static func _condition_words(in_character: bool) -> String:
	if in_character:
		return "took(x), arrived(x), done(x), loot>=n, said(x), gave(x), has(x), mood>=n, mood<=n, purse>=n, met, said(c.x), gave(c.x), mood(c)>=n, not(...)"

	return "took(x), arrived(x), done(x), loot>=n, said(c.x), gave(c.x), has(x), mood(c)>=n, purse>=n, not(...)"


static func _effect_words() -> String:
	return "set(f), clear(f), give(i), take(i), pay(n), charge(n), goal(g), done(g), note(n), mood(+n), mood(-n), shade(%s)" % "|".join(SHADES)
