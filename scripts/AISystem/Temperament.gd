extends RefCounted
## Who a man is, under what he is. Two swordsmen are trained alike; one
## holds when the rest run, another cannot wait his turn, a third works round
## behind you. Three numbers, 0 to 1:
##   nerve   how long he stays in it when their heart goes: the stubborn man
##           holds to the last, the craven one breaks first. Fear (the dread
##           you have put into the garrison) weighs most on a man short of it.
##   drive   how hard he presses: the rash man takes the front, goes in when
##           it is not his turn, and presses on when told to fall back; he
##           also guards and feints less, so he overreaches.
##   guile   how he fights with others: the sly man takes the place behind
##           you, waits for you to commit to someone else, and in the hunt
##           goes round to cut you off.
##
## Each class has its own (BASE); each man is rolled within SPREAD of it,
## new every time the level loads, unless the level pins him to a preset
## (Guard.temperament: a preset moves his class's numbers, and always far
## enough to be what it names). His tag names what shows most in him, for
## his lines (LINES) and his stance (GuardRig).
##
## Squad.gd reads the numbers themselves (who takes which place, who breaks);
## GuardFighter.gd turns only his difference from his own class into how he
## fights, so the man his class describes fights exactly as it says.

## nerve, drive, guile by archetype ("" is the plain watchman).
const BASE := {
	&"": [0.35, 0.35, 0.25],
	&"swordsman": [0.6, 0.5, 0.4],
	&"duelist": [0.7, 0.45, 0.85],
	&"brute": [0.85, 0.9, 0.1],
	&"archer": [0.3, 0.2, 0.7],
	&"trainer": [1.0, 0.0, 0.0],
}
## What a preset adds to his class: nerve, drive, guile.
const PRESETS := {
	&"steady": [0.0, 0.0, 0.0],
	&"stubborn": [0.35, 0.0, 0.0],
	&"craven": [-0.35, 0.0, 0.0],
	&"rash": [0.0, 0.35, -0.15],
	&"sly": [0.0, -0.1, 0.35],
}
## How far a rolled man strays from his class, each way.
const SPREAD := 0.2
## Where each tag starts to show.
const STUBBORN_AT := 0.75
const CRAVEN_AT := 0.3
const RASH_AT := 0.75
const SLY_AT := 0.75
## A preset means what it says whatever his class: its trait goes at least
## this far (a watchman pinned rash is rash; a stubborn one never breaks).
const PRESET_REACH := {&"stubborn": 0.85, &"craven": 0.25, &"rash": 0.8, &"sly": 0.8}
## What he says, by his tag and what he is doing.
const LINES := {
	&"steady": {&"engage": ["You there! Stop!"], &"flank": ["I'll take his side.", "Round him!"], &"press": ["Now! While he's busy!"],
		&"hold": ["Stay back! Help! Over here!", "I need help here!"], &"break": ["I'll get help!", "Fall back!"],
		&"fetch": ["Help! Over here!", "To me! He's here!"], &"rouse": ["Where?! Show me!", "Right behind you!"],
		&"revenge": ["You'll pay for them!", "You'll hang for this!"], &"desperate": ["Come on, then!", "Die, damn you!"], &"hunt": ["Spread out! Find him!"]},
	&"rash": {&"engage": ["Stand and fight!", "You're mine!"], &"flank": ["Out of my way, he's mine!"], &"press": ["Come ON!", "I'll do it myself!"],
		&"hold": ["Come here and fight me!"], &"break": ["I'll take you with me!"], &"fetch": ["I'll get the others!"],
		&"rouse": ["Where is he?! I'll gut him!"], &"revenge": ["You'll pay for that!", "Blood for blood!"], &"desperate": ["I'll take you with me!", "Die! DIE!"], &"hunt": ["Come out and fight!"]},
	&"sly": {&"engage": ["Easy now...", "Let's see what you've got."], &"flank": ["Keep him busy...", "I'll get round him."], &"press": ["Now, while he's looking away."],
		&"hold": ["No need to rush this."], &"break": ["Not today."], &"fetch": ["I'll bring the others."],
		&"rouse": ["Show me where. Quietly."], &"revenge": ["I'll make this slow."], &"desperate": ["Clever, aren't you?"], &"hunt": ["He went that way. I'll cut him off."]},
	&"stubborn": {&"engage": ["Hold the line!", "Not one step further."], &"flank": ["I've got this side."], &"press": ["Push him! Push!"],
		&"hold": ["You'll have to kill me.", "I'm not going anywhere."], &"fetch": ["Get help! I'll hold him!"],
		&"rouse": ["Lead on."], &"revenge": ["You'll answer for them!", "Not another one. Not while I stand."], &"desperate": ["Come on, then!"], &"hunt": ["He can't have gone far. Search everything."]},
	&"craven": {&"engage": ["Oh gods...", "S-stop right there!"], &"flank": ["I'll... I'll go round."], &"press": ["Get him! Get him!"],
		&"hold": ["Stay back! Stay BACK!", "Somebody help me!"], &"break": ["I'm not dying here!", "Run! Run!"],
		&"fetch": ["Help! He's killing us!", "HELP! HELP!"], &"rouse": ["Where? Where is he?"], &"revenge": ["You... you killed them!"],
		&"desperate": ["Get away from me!"], &"hunt": ["M-maybe he's gone..."]},
}

## Off, every man not pinned to a preset is exactly his class (tests).
static var rolling := true

var nerve := 0.5
var drive := 0.5
var guile := 0.5
## His class's own numbers: what he is measured against.
var base_nerve := 0.5
var base_drive := 0.5
var base_guile := 0.5
## What shows most in him: steady, stubborn, craven, rash or sly.
var tag: StringName = &"steady"


## A man of `archetype`: pinned to `preset`, or rolled about his class (or
## exactly his class, when not rolling).
static func roll(archetype: StringName, preset: StringName = &"") -> RefCounted:
	var t: RefCounted = (load("res://scripts/AISystem/Temperament.gd") as GDScript).new()
	var base: Array = BASE.get(archetype, BASE[&""])
	var offsets: Array = [0.0, 0.0, 0.0]

	if preset != &"" and not PRESETS.has(preset):
		push_warning("Temperament: no preset '%s'; rolling instead" % preset)

	if PRESETS.has(preset):
		offsets = PRESETS[preset]
	elif rolling:
		offsets = [randf_range(-SPREAD, SPREAD), randf_range(-SPREAD, SPREAD), randf_range(-SPREAD, SPREAD)]

	t.base_nerve = float(base[0])
	t.base_drive = float(base[1])
	t.base_guile = float(base[2])
	t.nerve = _moved(t.base_nerve, float(offsets[0]))
	t.drive = _moved(t.base_drive, float(offsets[1]))
	t.guile = _moved(t.base_guile, float(offsets[2]))
	t.tag = tag_of(t.nerve, t.drive, t.guile)

	# Pinned to a temperament: far enough to show it, and named for it.
	match preset:
		&"stubborn":
			t.nerve = maxf(t.nerve, float(PRESET_REACH[preset]))
			t.tag = preset
		&"craven":
			t.nerve = minf(t.nerve, float(PRESET_REACH[preset]))
			t.tag = preset
		&"rash":
			t.drive = maxf(t.drive, float(PRESET_REACH[preset]))
			t.tag = preset
		&"sly":
			t.guile = maxf(t.guile, float(PRESET_REACH[preset]))
			t.tag = preset

	return t


## His class's number, moved: never quite all or nothing.
static func _moved(base: float, offset: float) -> float:
	return base if offset == 0.0 else clampf(base + offset, 0.02, 0.98)


## What shows most: the trait furthest past where it starts to show.
static func tag_of(p_nerve: float, p_drive: float, p_guile: float) -> StringName:
	var best: StringName = &"steady"
	var margin := -1.0

	for entry in [[&"stubborn", p_nerve - STUBBORN_AT], [&"craven", CRAVEN_AT - p_nerve], [&"rash", p_drive - RASH_AT], [&"sly", p_guile - SLY_AT]]:
		if float(entry[1]) >= 0.0 and float(entry[1]) > margin:
			margin = float(entry[1])
			best = entry[0]

	return best


## What a man angry at their dead says, taking you on: for their captain, if
## you have killed one, as often as not.
const CAPTAIN_LINE := "For the captain!"


func revenge_line(captains: int) -> String:
	if captains > 0 and randf() < 0.5:
		return CAPTAIN_LINE

	return line(&"revenge")


## Something he would say about `situation`, in his own way: "" if nothing.
func line(situation: StringName) -> String:
	var own: Array = (LINES.get(tag, {}) as Dictionary).get(situation, [])

	if own.is_empty():
		own = (LINES[&"steady"] as Dictionary).get(situation, [])

	return String(own[randi() % own.size()]) if not own.is_empty() else ""
