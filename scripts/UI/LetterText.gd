extends RefCounted
## The letter's words, side by side (the harbour's job spec, section 4): the
## front the commission and the goals in ink (a done one struck through, the
## side goals under a rule); then the thief's pencil notes, NOTES_PER_SIDE to
## a side, newest last. BBCode for the held page's RichTextLabel.

const JobBook := preload("res://scripts/Level/JobBook.gd")

const NOTES_PER_SIDE := 10
## Pencil, against the ink.
const PENCIL := Color(0.3, 0.3, 0.33)
const RULE := "[center]―――――[/center]"


## [front, notes..., notes...] for `job` (a JobState).
static func sides(job: RefCounted) -> PackedStringArray:
	var out := PackedStringArray()
	var book: Dictionary = job.book
	var front := escape(String((book.get("letter", {}) as Dictionary).get("text", "")))
	var mains := []
	var others := []

	for goal in job.goals_listed():
		var line := escape(String(goal["text"]))
		line = "[s]%s[/s]" % line if bool(goal["done"]) else line
		(mains if StringName(goal["kind"]) == &"main" else others).append(line)

	front += "\n\n" + "\n".join(mains)

	if not others.is_empty():
		front += "\n" + RULE + "\n" + "\n".join(others)

	out.append(front)
	var notes: Array = job.notes

	for start in range(0, notes.size(), NOTES_PER_SIDE):
		var lines := PackedStringArray()

		for id in notes.slice(start, start + NOTES_PER_SIDE):
			var text := String((book.get("notes", {}) as Dictionary).get(id, {}).get("text", JobBook.OPEN + String(id) + JobBook.CLOSE))
			lines.append("[color=#%s][i]— %s[/i][/color]" % [PENCIL.to_html(false), escape(text)])

		out.append("\n".join(lines))

	return out


## The words as written: a [ in them is not a tag.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")
