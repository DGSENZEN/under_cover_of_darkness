extends RefCounted
## What the whole level knows of you. Every squad that fights you tells it
## what it saw you do, and every guard who comes after you knows it already:
## word spreads through a garrison.
##   habits  how you fight, each 0..1: turtle (behind a raised guard), spam
##           (blows on each other's heels), kite (keeping away), bow. Built
##           slowly from what the squads see (it takes a habit, not one
##           moment), and never forgotten for the level. A new squad comes
##           knowing them, and keeps the answer to them in its hands.
##   dread   0..1, what you have done to them: each man of theirs you kill in
##           a hunt, their captains most, a man cut apart in front of them, a
##           body found. It fades once it has been quiet a while. It weighs
##           on a man by how little nerve he has (fear_of), and turns to anger
##           in a man with plenty (anger_of).
##   alarm   0..1, how roused they are right now: a man missing from his post,
##           one of your arrows in a wall, a body, a fight, the bell. It holds
##           a while once raised, then settles. Roused, men take lanterns into
##           the dark and talk of nothing else (GuardLife.gd).
##   fallen  the posts of men you took quietly (knocked out, or killed before
##           anyone knew you were there): a man who knew one, looking at his
##           post, misses him.
##   looks   who is looking into what: one man goes to see what the noise
##           was, and the men who heard him cover him from where they stand.
##   mercy   the men you let go when they begged (spared) and the ones you cut
##           down on their knees (slain_begging): they talk of both, and the
##           next man weighs them before he begs you (mercy_hope). Killing a
##           man who begged is a dread of its own.
##
## One for each target (`of`), kept for the level; `clear_all` forgets.

## A habit comes to match what they see over this many seconds.
const HABIT_TIME := 20.0
## What each thing adds to their dread.
const DREAD_KILL := 0.1
const DREAD_CAPTAIN := 0.15
const DREAD_GORE := 0.05
const DREAD_BODY := 0.03
## Over and above the kill: a man cut down on his knees, begging.
const DREAD_MERCILESS := 0.08
## Each man cut down begging, more than you have spared, takes this off the
## chance the next one begs at all (never below MERCY_HOPE_MIN).
const MERCY_DOUBT := 0.35
const MERCY_HOPE_MIN := 0.1
## Quiet this long, dread starts to fade, at this much a second.
const DREAD_HOLD := 30.0
const DREAD_FADE := 0.1 / 60.0
## A man with this much nerve turns dread into anger.
const BOLD_NERVE := 0.7
## Once raised, the alarm holds this long (seconds) and then settles at this
## much a second.
const ALARM_HOLD := 90.0
const ALARM_FADE := 1.0 / 240.0
## A look into something is his for this long, and covers this much ground.
const LOOK_HOLD := 15.0
const LOOK_REACH := 5.0
## What men at their ease talk about, [said, answered], by what is on their
## minds (gossip).
const SMALL_TALK := [
	["Quiet tonight.", "Too quiet. I don't like it."],
	["Cold enough to freeze the piss in you.", "Then stop standing in the wind."],
	["When's the relief due?", "Not soon enough."],
	["The captain's in a foul mood again.", "When isn't he?"],
	["I'd kill for a drink.", "Wait till the watch changes."],
	["You still owe me for the dice.", "Put it on my tab."],
	["They say the old keep's haunted.", "They say a lot of things."],
	["Did you hear something?", "Only your stomach."],
]
const TALK_OF_DEAD := [
	["How many is that now?", "Too many. Watch the shadows."],
	["Whoever it is, he's good.", "Nobody's that good. We'll have him."],
	["They found another one.", "Keep your voice down."],
]
const TALK_OF_DREAD := [
	["I'm not staying another night here.", "Nor me. Stay close."],
	["I keep hearing footsteps.", "That's me, you fool."],
]
const TALK_OF_CAPTAIN := [["They killed the captain.", "Then we make them pay for it."]]
const TALK_OF_ALARM := [
	["Eyes open. He's still in here somewhere.", "I know, I know."],
	["Stay where I can see you.", "Likewise."],
]
const TALK_OF_HABITS := {
	&"turtle": ["They say he hides behind his blade.", "Then put a boot through it."],
	&"spam": ["Swings like a butcher, they say.", "Then let him tire, and cut him down."],
	&"kite": ["He runs. Won't stand and fight.", "Then we'll run him down."],
	&"bow": ["He's got a bow. Keep out of the light.", "And off the open ground."],
	&"parry": ["He turns every blow aside, they say.", "Then feint. Make him guess."],
	&"dodge": ["Quick on his feet, that one.", "Then go for his legs."],
}
## Of what you did to men who begged: %s is the man.
const TALK_OF_SPARED := [
	["He had %s on his knees. And let him go.", "Then he's soft. Or he's playing with us."],
	["%s begged, and he walked away.", "I'd not count on that twice."],
]
const TALK_OF_SLAIN_BEGGING := [
	["%s begged him. On his knees. He cut him down anyway.", "Then nobody kneels. Nobody."],
	["He killed %s while he was begging.", "Then we fight to the last. All of us."],
]

static var _garrisons := {}

var target_ref: WeakRef
var habits := {&"turtle": 0.0, &"spam": 0.0, &"kite": 0.0, &"bow": 0.0, &"parry": 0.0, &"dodge": 0.0}
var dread := 0.0
## Their dead, and their captains among them; the names they knew them by.
var dead := 0
var captains := 0
var dead_names: Array[String] = []
var alarm := 0.0
## [{where, name, at (Comms.now), noticed}] for each man taken from his post.
var fallen := []
## The names of the men you let go when they begged, and of the men you cut
## down begging.
var spared: Array[String] = []
var slain_begging: Array[String] = []
## The garrison's own time, advanced once a physics frame whoever calls.
var clock := 0.0
var _frame := -1
var _last_dread_at := -100.0
var _alarm_at := -100.0
## [{where, by (weakref), at}]: who is looking into what.
var _looks := []


## The garrison's memory of `target` (made the first time it is asked for).
static func of(target: Node3D) -> RefCounted:
	if target == null or not is_instance_valid(target):
		return null

	var key := target.get_instance_id()
	var garrison: RefCounted = _garrisons.get(key)

	if garrison == null:
		_prune()
		garrison = (load("res://scripts/AISystem/Garrison.gd") as GDScript).new()
		garrison.target_ref = weakref(target)
		_garrisons[key] = garrison

	return garrison


## Forget everything (a new level, a test, the gym's F5).
static func clear_all() -> void:
	_garrisons.clear()


## Whoever it remembered is gone (a level reloaded): let it go.
static func _prune() -> void:
	for key in _garrisons.keys():
		var w: WeakRef = _garrisons[key].target_ref

		if w == null or w.get_ref() == null:
			_garrisons.erase(key)


## Once a physics frame, whoever calls first.
func tick(delta: float) -> void:
	var frame := Engine.get_physics_frames()

	if frame == _frame:
		return

	_frame = frame
	advance(delta)


## Time passes: dread fades for as much of it as came after the quiet began,
## and so does the alarm once it has held.
func advance(seconds: float) -> void:
	var before := clock
	clock += seconds
	var fading := clampf(clock - maxf(before, _last_dread_at + DREAD_HOLD), 0.0, seconds)
	dread = maxf(dread - DREAD_FADE * fading, 0.0)
	var settling := clampf(clock - maxf(before, _alarm_at + ALARM_HOLD), 0.0, seconds)
	alarm = maxf(alarm - ALARM_FADE * settling, 0.0)


## What a squad has seen of you (its `read`) over `step` seconds: a habit
## grows toward it, never back.
func learn(read: Dictionary, step: float) -> void:
	var k := 1.0 - exp(-step / HABIT_TIME)

	for key in habits.keys():
		var seen := float(read.get(key, 0.0))

		if seen > float(habits[key]):
			habits[key] = float(habits[key]) + (seen - float(habits[key])) * k


## One of theirs killed in a hunt (their leader, the worse), known to them as
## `called`.
func on_death(was_leader: bool, called := "") -> void:
	dead += 1

	if was_leader:
		captains += 1

	if called != "":
		dead_names.append(called)

	_dread(DREAD_KILL + (DREAD_CAPTAIN if was_leader else 0.0))
	raise_alarm(0.8)


## A man cut apart where they could see it.
func on_gore() -> void:
	_dread(DREAD_GORE)


## One of theirs found lying where you left him.
func on_body_found() -> void:
	_dread(DREAD_BODY)
	raise_alarm(0.6)


## A man who begged you, let go (GuardMercy): each man once, however often.
func on_spared(called := "") -> void:
	var who := called if called != "" else "one of ours"

	if not (who in spared) or called == "":
		spared.append(who)


## A man cut down while he begged you (GuardMercy): dread beyond the kill.
func on_slain_begging(called := "") -> void:
	slain_begging.append(called if called != "" else "one of ours")
	_dread(DREAD_MERCILESS)


## The chance a man broken and caught thinks begging you is any use (0..1):
## less for every man you have cut down begging, more than you have spared.
func mercy_hope() -> float:
	var owed := slain_begging.size() - spared.size()
	return clampf(1.0 - MERCY_DOUBT * float(maxi(owed, 0)), MERCY_HOPE_MIN, 1.0)


## Something has roused them this far (0..1): it never lowers the alarm.
func raise_alarm(level: float) -> void:
	alarm = maxf(alarm, clampf(level, 0.0, 1.0))
	_alarm_at = clock


## A man taken quietly from his post at `where` (knocked out, or killed while
## nobody knew you were there): whoever knew him will miss him there.
func post_fell(where: Vector3, called: String, at: float) -> void:
	fallen.append({"where": where, "name": called, "at": at, "noticed": false})


## Someone is looking into what happened near `where`: `by` claims it, unless
## another man already has (then he is who you get back, and `by` covers him).
func look_into(where: Vector3, by: Node3D) -> Node3D:
	_looks = _looks.filter(func(l: Dictionary) -> bool:
		var man: Object = (l["by"] as WeakRef).get_ref()
		return man != null and is_instance_valid(man) and man.get("_knocked_out") != true and clock - float(l["at"]) < LOOK_HOLD)

	for look in _looks:
		var man: Node3D = (look["by"] as WeakRef).get_ref() as Node3D

		if man != by and (look["where"] as Vector3).distance_to(where) < LOOK_REACH:
			return man

	for look in _looks:
		if (look["by"] as WeakRef).get_ref() == by:
			look["where"] = where
			look["at"] = clock
			return null

	_looks.append({"where": where, "by": weakref(by), "at": clock})
	return null


## `by` has finished looking.
func looked(by: Node3D) -> void:
	_looks = _looks.filter(func(l: Dictionary) -> bool: return (l["by"] as WeakRef).get_ref() != by)


## Something two men at their ease might say to each other now, [said,
## answered]: of their dead, their fear, what they have heard of you, or
## nothing much.
func gossip() -> Array:
	var topics: Array = []

	if captains > 0:
		topics.append_array(TALK_OF_CAPTAIN)

	if not dead_names.is_empty():
		var name: String = dead_names[randi() % dead_names.size()]
		topics.append(["They found %s. Throat cut, they say." % name, "Keep your voice down."])
		topics.append(["%s owed me money." % name, "Then you'd best find who did it."])

	if dead > 0:
		topics.append_array(TALK_OF_DEAD)

	if dread > 0.35:
		topics.append_array(TALK_OF_DREAD)

	if alarm > 0.45:
		topics.append_array(TALK_OF_ALARM)

	for habit in TALK_OF_HABITS:
		if float(habits.get(habit, 0.0)) > 0.35:
			topics.append(TALK_OF_HABITS[habit])

	for post in fallen:
		if bool(post["noticed"]) and String(post["name"]) != "":
			topics.append(["Anyone seen %s?" % post["name"], "Not since he took his post."])

	for pair in [[spared, TALK_OF_SPARED], [slain_begging, TALK_OF_SLAIN_BEGGING]]:
		var names: Array = pair[0]

		if not names.is_empty():
			var said: Array = (pair[1] as Array)[randi() % (pair[1] as Array).size()]
			topics.append([String(said[0]) % names[randi() % names.size()], said[1]])

	# What is on their minds comes up more often than the weather.
	if topics.is_empty() or randf() < 0.3:
		topics.append_array(SMALL_TALK)

	return topics[randi() % topics.size()]


func _dread(amount: float) -> void:
	dread = minf(dread + amount, 1.0)
	_last_dread_at = clock


## How much the dread weighs on a man of this nerve.
func fear_of(nerve: float) -> float:
	return dread * (1.0 - nerve)


## How much of it a bold man turns to anger.
func anger_of(nerve: float) -> float:
	return dread * nerve if nerve >= BOLD_NERVE else 0.0


## A new squad's heart, before a blow is struck.
func opening_heart() -> float:
	return 1.0 - 0.3 * dread
