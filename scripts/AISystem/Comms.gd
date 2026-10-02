extends RefCounted
## Builds timestamped guard messages and emits them through SoundBus.
## Guard listeners apply hearing range/navmesh distance before acting on messages.
## Kinds: spotted, lost, danger, noise, clear, look and alarm. Location text uses
## landmarks, height or relative direction; may_voice reserves nearby chorus slots.
## Calls are gameplay events; callers separately choose/display their spoken line.

const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

## A raised voice (a shout carries as far), and speech between men near.
const CALL_DB := 72.0
const SPEECH_DB := 56.0
## A landmark this near a place names it.
const LANDMARK_REACH := 7.0
## Higher or lower than the caller by this much: "up high", "down below".
const HEIGHT_CALL := 1.8
## Lines, by what is called; %s is the place.
const SPOTTED := ["There! %s!", "He's %s!", "Over here! %s!", "I see him! %s!"]
const LOST := ["Lost him! He went %s!", "He's gone %s!", "He slipped away %s!"]
const LOST_HERE := ["Lost him!", "Where'd he go?", "He's gone again!"]
const DANGER := ["Powder! Get back!", "It's going to blow! Move!", "Barrel! Get clear!"]
## Sending a man to look: his name, then the place.
const SEND := ["%s! Something %s! Go and look!", "%s! Movement %s! Have a look!", "%s! I saw something %s! Go and see!"]

static var _serial := 0
## The same sort of thing said within CHORUS_REACH (m) in the last
## CHORUS_TIME (s) by as many as want saying it: the rest keep quiet.
const CHORUS_TIME := 2.5
const CHORUS_REACH := 18.0
## Said lately: [time, kind, where].
static var _voiced: Array = []


## Seconds of game time: the one clock every man's calls are stamped with.
static func now() -> float:
	return float(Engine.get_physics_frames()) / float(maxi(Engine.physics_ticks_per_second, 1))


## Whether a line of `kind` ("coming", "heard", "lost", "stand_down"...)
## wants saying at `where` now, or has been said near there just now by
## `voices` men already. Said (true), it is counted.
static func may_voice(kind: StringName, where: Vector3, voices := 1) -> bool:
	var at := now()
	var said := 0
	var kept := []

	for entry in _voiced:
		if at - float(entry[0]) > CHORUS_TIME or float(entry[0]) > at:
			continue

		kept.append(entry)

		if entry[1] == kind and (entry[2] as Vector3).distance_to(where) < CHORUS_REACH:
			said += 1

	_voiced = kept

	if said >= voices:
		return false

	_voiced.append([at, kind, where])
	return true


## Copies data into {what: StringName, where: Vector3, time: float, id: int,
## from: WeakRef}; reserved keys overwrite data. speaker supplies eye_position() or
## feet + 1.6 m. db defaults to CALL_DB. Emits synchronously and returns the message.
static func call_out(speaker: Node3D, what: StringName, where: Vector3, data := {}, db := CALL_DB) -> Dictionary:
	_serial += 1
	var message := data.duplicate()
	message["what"] = what
	message["where"] = where
	message["time"] = now()
	message["id"] = _serial
	message["from"] = weakref(speaker)
	var mouth: Vector3 = speaker.eye_position() if speaker.has_method("eye_position") else speaker.global_position + Vector3.UP * 1.6
	SoundBus.emit_message(mouth, db, speaker, &"call", message)
	return message


## Resolves message.from weak reference as Node3D, or null if absent/freed.
static func caller(message: Dictionary) -> Node3D:
	var w: Variant = message.get("from")
	return (w as WeakRef).get_ref() as Node3D if w is WeakRef else null


## What a man at `from` calls `where`: "by the well", "up high", "behind me".
static func place(where: Vector3, from: Node3D) -> String:
	var mark := landmark_near(from.get_tree(), where)

	if mark != "":
		return "by the " + mark

	var rise := where.y - from.global_position.y

	if rise > HEIGHT_CALL:
		return "up high"

	if rise < -HEIGHT_CALL:
		return "down below"

	var to := where - from.global_position
	to.y = 0.0

	if to.length() < 2.5:
		return "right here"

	var local: Vector3 = from.global_basis.inverse() * to
	var angle := rad_to_deg(atan2(local.x, -local.z))

	if absf(angle) < 40.0:
		return "straight ahead"

	if absf(angle) > 140.0:
		return "behind me"

	return "to my right" if angle > 0.0 else "to my left"


## The name of the landmark nearest `where`, within LANDMARK_REACH; "" if none.
static func landmark_near(tree: SceneTree, where: Vector3) -> String:
	var best := ""
	var nearest := LANDMARK_REACH

	for mark in tree.get_nodes_in_group(&"landmarks"):
		if not (mark is Node3D):
			continue

		var at := (mark as Node3D).global_position
		var d := Vector2(at.x - where.x, at.z - where.z).length()

		if d < nearest and absf(at.y - where.y) < 4.0:
			nearest = d
			best = String(mark.get_meta(&"landmark")) if mark.has_meta(&"landmark") else String(mark.name).to_lower()

	return best


## Which way `heading` goes, as a compass would say it (-Z north, +X east).
static func compass(heading: Vector3) -> String:
	var flat := Vector2(heading.x, -heading.z)

	if flat.length() < 0.01:
		return ""

	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var angle := fposmod(atan2(flat.x, flat.y), TAU)
	return names[int(round(angle / (TAU / 8.0))) % 8]


## What is shouted on seeing you at `where`.
static func spotted_line(where: Vector3, from: Node3D) -> String:
	var said: String = SPOTTED[randi() % SPOTTED.size()] % place(where, from)
	return _capital_after_bang(said)


## What is shouted on losing you, going `heading` from `where`.
static func lost_line(where: Vector3, heading: Vector3, from: Node3D) -> String:
	var mark := landmark_near(from.get_tree(), where)

	if heading.length() > 1.0:
		return LOST[randi() % LOST.size()] % compass(heading)

	if mark != "":
		return "Lost him by the %s!" % mark

	return LOST_HERE[randi() % LOST_HERE.size()]


static func danger_line() -> String:
	return DANGER[randi() % DANGER.size()]


## What a man at his post calls down to `name`, to send him to look at `where`.
static func send_line(where: Vector3, from: Node3D, name: String) -> String:
	return SEND[randi() % SEND.size()] % [name if name != "" else "You", place(where, from)]


## "There! by the well!" reads "There! By the well!".
static func _capital_after_bang(text: String) -> String:
	var at := text.find("! ")

	if at < 0 or at + 2 >= text.length():
		return text

	return text.substr(0, at + 2) + text.substr(at + 2, 1).to_upper() + text.substr(at + 3)
