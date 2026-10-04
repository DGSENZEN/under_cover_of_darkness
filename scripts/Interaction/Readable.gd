class_name Readable
extends StaticBody3D
## Words to read where they are (the harbour's job spec, section 5.1): a
## notice pinned up, a paper lying loose, a ledger open on a desk. Its words
## are its slot's in the district's job file (JobBook); reading one holds
## them up in both hands (PlayerFrob.read) and adds its pencil note. A paper
## is taken up while read and put back where it lay; a notice or a ledger
## stays where it is.

const JobBook := preload("res://scripts/Level/JobBook.gd")
const LetterText := preload("res://scripts/UI/LetterText.gd")

## Its words' id in the district's job file.
@export var slot := ""
## notice, paper or ledger (HeldPage.SIZES).
@export var look: StringName = &"paper"


func get_prompt(_player: Node) -> String:
	return "Read"


func frob(player: Node) -> void:
	if player.get("frob") != null and player.frob.has_method("read"):
		player.frob.read(self)


## Its words, one side; a slot the job file lacks shows as its placeholder.
func sides() -> PackedStringArray:
	var entry := JobBook.readable(slot)
	var text := String(entry.get("text", JobBook.OPEN + slot + JobBook.CLOSE))
	return PackedStringArray([LetterText.escape(text)])


## Held up (a paper goes with the hands) or put back.
func set_held(on: bool) -> void:
	if look == &"paper":
		visible = not on
