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

## More of what he says, in his own way, as the garrison works together (a
## call answered, a noise looked into, a blade lost and found, a door left
## open, a man missing, a lookout coming down or a friend he sent gone quiet:
## GuardLife.gd, GuardHands.gd, Comms.gd, Squad.gd; begging for his life, let
## go or struck, safe among his own, his heart back: GuardMercy.gd; to himself
## at his ease, and woken from a doze: GuardHabits.gd; a greeting going by, and
## one back: GuardLife.gd; the hunt given up, after he saw you: Guard.gd). "%s"
## in a "missing" or "quiet" line is the man's name; in a "greet", the name of
## the man greeted.
const MORE_LINES := {
	&"steady": {&"ack": ["On my way!", "Coming!", "I hear you!"], &"noise_ask": ["Did you hear that?", "What was that?"],
		&"noise_cover": ["Go on, I've got you.", "Careful."], &"clear": ["Nothing. Rats, likely.", "Nothing here."],
		&"disarmed": ["My sword!", "Where's my blade?!"], &"rearmed": ["That's better.", "Now then."],
		&"unreachable": ["Come down here!", "You can't stay up there forever!"], &"throw": ["Catch!", "Have this!"],
		&"watch": ["I'll keep watch from here.", "I'll watch this way."], &"intercept": ["I'll cut him off!", "Head him off!"],
		&"missing": ["Where's %s got to?", "%s? Where are you?"], &"odd_door": ["Who left this open?", "This was shut."],
		&"odd_arrow": ["An arrow? Someone's here.", "That's not one of ours."], &"odd_weapon": ["That's a guard's sword...", "Whose blade is this?"],
		&"lantern": ["Too dark. Let's have some light.", "Where's my lantern..."], &"bell": ["Ring the bell!", "Sound the alarm!"],
		&"danger": ["Powder! Get back!"],
		&"descend": ["I'm coming down!", "Hold on, I'm coming!", "Hold him! I'm coming down!"],
		&"quiet": ["%s's gone quiet! To arms!", "Something's got %s! Up, all of you!"],
		&"plead": ["Mercy! Mercy!", "Please - I yield! I yield!", "Don't kill me, I beg you!", "I've a wife... children... please!",
			"I never saw you! I swear it!", "Take whatever you want - just let me live!", "Please... please..."],
		&"mutter": ["Quiet night.", "Cold one tonight.", "When's my relief, then?", "My feet are killing me.", "Could do with a drink."],
		&"woken": ["Hm? Wha-?", "Who's there?", "I wasn't asleep!"],
		&"greet": ["Evening, %s.", "All quiet, %s?", "Evening.", "Keeping warm?", "Cold one, eh?"],
		&"greet_back": ["Evening.", "Quiet enough.", "Mm.", "Can't complain."],
		&"gave_up": ["He's gone. Keep your eyes open.", "Lost him. Stay sharp, all of you.", "He's out there somewhere. Stay alert."],
		&"greet_wary": ["Seen anything, %s?", "Anything your way?", "Keep your eyes open, %s."], &"greet_back_wary": ["Nothing.", "Not a thing.", "Nothing yet."],
		&"spared": ["Thank you... thank you!", "Gods bless you...", "I'm going, I'm going!"],
		&"struck": ["No! Please!", "I yielded, damn you!", "Help! He's killing me!"],
		&"safe": ["He's after me! There!", "He nearly had me! That way!", "Stand with me - he's coming!"],
		&"emboldened": ["Now we'll see!", "Not so brave now, are you?", "My turn."]},
	&"rash": {&"ack": ["He's mine!", "Leave him to me!"], &"noise_ask": ["You hear that? I'll go."], &"noise_cover": ["Hurry up, then."],
		&"clear": ["Nothing. Pity."], &"disarmed": ["I'll kill you with my bare hands!"], &"rearmed": ["Now you're dead!"],
		&"unreachable": ["Come down and fight, coward!"], &"throw": ["Eat this!"], &"watch": ["Fine, I'll watch. Hurry up."],
		&"intercept": ["He won't get past me!"], &"missing": ["%s! Get back here, you idler!"], &"odd_door": ["Who's been through here?!"],
		&"odd_arrow": ["Someone's shooting at us! Show yourself!"], &"odd_weapon": ["Whose sword is this?!"], &"lantern": ["Light! Where are you hiding?"],
		&"bell": ["Rouse them all!"], &"descend": ["Leave him to me!", "Enough watching!"], &"plead": ["Enough! Enough, you've won!", "Alright! I yield, curse you!"],
		&"struck": ["Coward! I yielded!"], &"emboldened": ["Now you'll pay for that!"],
		&"mutter": ["Nothing ever happens here.", "I'd give a month's pay for a fight.", "Bored. Bored, bored, bored."], &"woken": ["Who dares?!", "What? Who's there?!"],
		&"greet": ["Still awake, %s?", "Anything happen yet?", "Oi, %s."], &"greet_back": ["Nothing. As ever.", "Hah.", "What do you want?"],
		&"gave_up": ["Coward! Come back and fight!", "Next time, I'll have you.", "Run, then. I'll find you."],
		&"greet_wary": ["Any sign of him, %s?", "Found him yet?"], &"greet_back_wary": ["If I had, he'd be dead.", "No. Worse luck."]},
	&"sly": {&"ack": ["I'll come round the other way."], &"noise_ask": ["Hear that? Stay here."], &"noise_cover": ["I'll watch the shadows."],
		&"clear": ["Nothing... for now."], &"disarmed": ["Careless of me."], &"rearmed": ["Where were we?"],
		&"unreachable": ["We can wait."], &"throw": ["Heads up."], &"watch": ["I'll watch from here. Flush him out."],
		&"intercept": ["I'll get ahead of him."], &"missing": ["No %s... that's not like him."], &"odd_door": ["Now who opened this?"],
		&"odd_arrow": ["Someone's been shooting. Interesting."], &"odd_weapon": ["Somebody dropped this. Somebody dead."], &"lantern": ["Let's see you now."],
		&"bell": ["To the bell."], &"descend": ["Time I took a hand."], &"plead": ["Wait - wait! I can be useful to you!", "Spare me and I'll tell you where the others are!", "Let's be sensible about this..."],
		&"spared": ["You won't regret it.", "Wise. Very wise."], &"safe": ["He's there. Go on, then - get him."],
		&"emboldened": ["Did you really think I meant it?"],
		&"mutter": ["Quiet. Too quiet.", "Nobody's watching...", "Hm. I wonder."], &"woken": ["...I heard that.", "Who's creeping about?"],
		&"greet": ["Evening, %s...", "Anything to report?"], &"greet_back": ["Nothing worth telling.", "Mm. Evening."],
		&"gave_up": ["He'll be back. They always come back.", "Gone... for now."],
		&"greet_wary": ["Anything, %s?", "Quiet your way?"], &"greet_back_wary": ["Too quiet.", "Nothing I like."]},
	&"stubborn": {&"ack": ["Hold him there!"], &"noise_ask": ["Something's out there. Wait here."], &"noise_cover": ["I'm right behind you."],
		&"clear": ["Clear."], &"disarmed": ["I don't need a blade for you."], &"rearmed": ["Again."],
		&"unreachable": ["I'll be right here when you come down."], &"throw": ["Here!"], &"watch": ["Nothing gets past me."],
		&"intercept": ["Cut him off!"], &"missing": ["%s should be here."], &"odd_door": ["This stays shut."],
		&"odd_arrow": ["Arrows. Everyone look sharp."], &"odd_weapon": ["A blade on the floor. Not good."], &"lantern": ["Light it up."],
		&"bell": ["Sound the alarm!"], &"descend": ["Hold the line! I'm coming!"],
		&"mutter": ["Stay sharp.", "Not on my watch.", "Eyes open."], &"woken": ["On my feet! On my feet!"],
		&"greet": ["%s.", "All well?", "Eyes open, %s."], &"greet_back": ["All well.", "Aye."],
		&"gave_up": ["He's gone. I'm not going anywhere.", "Gone. Back to your posts - and stay sharp."],
		&"greet_wary": ["Eyes open, %s.", "All clear your way?"], &"greet_back_wary": ["Clear.", "Nothing."]},
	&"craven": {&"ack": ["C-coming..."], &"noise_ask": ["D-did you hear that?"], &"noise_cover": ["You go. I'll... watch."],
		&"clear": ["N-nothing. Thank the gods."], &"disarmed": ["No, no, no - my sword!"], &"rearmed": ["Stay back! I'm armed!"],
		&"unreachable": ["Someone get a bow!"], &"throw": ["Get away!"], &"watch": ["I'll... stay here and watch."],
		&"intercept": ["Th-this way!"], &"missing": ["%s? This isn't funny..."], &"odd_door": ["This was shut... wasn't it?"],
		&"odd_arrow": ["An arrow... gods."], &"odd_weapon": ["A sword... where's the man who carried it?"], &"lantern": ["I need light. I need light..."],
		&"bell": ["The bell! Somebody ring the bell!"], &"descend": ["Oh gods... I'm coming, I'm coming!"], &"plead": ["Please! Please! Don't hurt me!", "I don't want to die! Mercy!", "Mother... please... no...",
			"I'll do anything! Anything!"], &"spared": ["Th-thank you... oh gods, thank you!"], &"struck": ["No! No, please, no!"],
		&"safe": ["Help me! He's there! He's there!"],
		&"mutter": ["Was that... no. Nothing.", "I hate the dark.", "Please be a quiet night..."], &"woken": ["Aah! Who's there?!", "W-what was that?!"],
		&"greet": ["Oh - it's you, %s.", "S-seen anything?"], &"greet_back": ["N-no. Nothing.", "Nothing, thank the gods."],
		&"gave_up": ["Is he gone? Is he really gone?", "Gods, let him be gone..."],
		&"greet_wary": ["%s! Oh, it's you. Is he still about?", "D-did you see anything?"], &"greet_back_wary": ["N-no. Nothing.", "Don't creep up on me like that!"]},
}
## What the garrison calls its men (a woman by NAMES_F), the same man the same
## name every time the level loads (name_for).
const NAMES := ["Aldric", "Hendrik", "Osric", "Wulfram", "Tobias", "Gerolt", "Brandt", "Emeric", "Conrad", "Leofric",
	"Anselm", "Dietrich", "Harald", "Jory", "Merek", "Roderick", "Sigmund", "Tancred", "Ulric", "Wendel"]
const NAMES_F := ["Adela", "Brunhild", "Elsbeth", "Griselda", "Hedwig", "Irmgard", "Kunigunde", "Margit", "Ottilie", "Ysolde"]

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
		own = (MORE_LINES.get(tag, {}) as Dictionary).get(situation, [])

	if own.is_empty():
		own = (LINES[&"steady"] as Dictionary).get(situation, [])

	if own.is_empty():
		own = (MORE_LINES[&"steady"] as Dictionary).get(situation, [])

	return String(own[randi() % own.size()]) if not own.is_empty() else ""


## A name for the man whose look is `seed` (a woman's, if `female`).
static func name_for(seed: int, female := false) -> String:
	var names: Array = NAMES_F if female else NAMES
	return String(names[posmod(seed, names.size())])
