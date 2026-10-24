extends Node3D
## The test quest (the talk and quests spec, section 6), on the shipped files:
## data/dialogue/curandera.dialogue, librarian.dialogue and their types. Q1
## they load clean, every word a placeholder; Q2-Q6 the quest driven through
## Conversation headless (the truth route, the lie, the revisits, the types, a
## new mission); Q7 the shades stand in the candle lane (maps/candle_lane.tscn)
## and the player walks from the spawn to each and talks.
##   Godot --headless --fixed-fps 60 --path . res://tests/talk_quest_test.tscn
##
## The words still to write are printed as WORDS: lines; their number never
## fails a check.

const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const PeopleState := preload("res://scripts/Level/PeopleState.gd")
const Inventory := preload("res://scripts/Interaction/Inventory.gd")
const Conversation := preload("res://scripts/Interaction/Conversation.gd")
const LetterText := preload("res://scripts/UI/LetterText.gd")
const Shade := preload("res://scripts/Interaction/Shade.gd")
const TalkSkin := preload("res://scripts/UI/TalkSkin.gd")
const LANE := preload("res://maps/candle_lane.tscn")

## The nameless curandera of the type alone, as the lane names her.
const MARKET := "<<a market curandera>>"
## The frob's reach (PlayerFrob.frob_distance).
const REACH := 2.2
## How near a waypoint counts as reached (m), and how long a leg may take.
const REACHED := 0.35
const LEG_FRAMES := 900

var results: Array[String] = []


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	DialogueBook.reload()
	_shipped()
	_truth()
	await _lie()
	_revisits()
	_types()
	_new_mission()
	await _in_the_lane()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit(1 if failed > 0 else 0)


# ---------------------------------------------------------------------------
# Q1: the shipped files
# ---------------------------------------------------------------------------

func _shipped() -> void:
	var lib: Dictionary = DialogueBook.load_dir()
	var characters: Dictionary = lib.get("characters", {})
	var types: Dictionary = lib.get("types", {})
	var her: Dictionary = characters.get("curandera", {})
	var him: Dictionary = characters.get("librarian", {})
	var not_placeholder: Array[String] = []

	for group in ["characters", "types"]:
		for who in (lib.get(group, {}) as Dictionary).values():
			for beat in (who["beats"] as Dictionary).values():
				if not beat["own"]:
					continue

				for line in beat["body"]:
					if ["say", "sense", "option"].has(line["type"]) and not DialogueBook.is_placeholder(String(line["text"])):
						not_placeholder.append(String(line["source"]))

	for item in (lib.get("items", {}) as Dictionary).values():
		if not DialogueBook.is_placeholder(String(item["name"])):
			not_placeholder.append(String(item["source"]))

	for entry in lib.get("goals", []) + (lib.get("notes", {}) as Dictionary).values():
		if not DialogueBook.is_placeholder(String(entry["text"])):
			not_placeholder.append(String(entry["source"]))

	# R13: a type's lines are spoken by whoever is of the type, {name}.
	var literal_speakers: Array[String] = []

	for who in types.values():
		for beat in (who["beats"] as Dictionary).values():
			for line in beat["body"]:
				if line["type"] == "say" and line["speaker"] != "{name}":
					literal_speakers.append(String(line["source"]))

	var openers := func(who: Dictionary) -> Array: return who.get("openers", [])
	var shaped: bool = not her.is_empty() and not him.is_empty() \
		and openers.call(her) == ["open_first", "open_has_book", "open_after", "open"] \
		and openers.call(him) == ["open_first", "open_after_lie", "open_sent", "open"] \
		and her["body"] == &"duelist" and him["body"] == &"arms_master" and her["voice"] == &"female" and him["voice"] == &"male_b" \
		and him["colour"] == Color.html("#e63833") and her["colour"] == DialogueBook.colour_of("copal") \
		and her["type"] == "curandera" and him["type"] == "bookseller" \
		and (lib.get("items", {}) as Dictionary).has("the_book") and (lib.get("items", {}) as Dictionary).has("copal_bundle") \
		and (lib.get("items", {}) as Dictionary).get("copal_bundle", {}).get("look") == &"bundle" \
		and (lib.get("items", {}) as Dictionary).get("the_book", {}).get("look") == &"book" \
		and (lib.get("goals", []) as Array).any(func(g): return g["id"] == "bring_book" and g["kind"] == &"side") \
		and types.has("curandera") and types.has("bookseller")

	var words: Array = DialogueBook.placeholders(lib)

	for w in words:
		print("WORDS: %s" % w)

	for item in (lib.get("items", {}) as Dictionary).values():
		print("WORDS: %s item %s" % [item["source"], item["id"]])

	_check("Q1 the shipped dialogue loads with no errors or warnings, every text a placeholder, type lines spoken by {name}",
		(lib["errors"] as Array).is_empty() and (lib["warnings"] as Array).is_empty() and not_placeholder.is_empty()
		and literal_speakers.is_empty() and shaped and words.size() > 20,
		"errors %s, warnings %s, not placeholders %s, literal speakers %s, shaped %s, %d words" % [lib["errors"], lib["warnings"],
		not_placeholder, literal_speakers, shaped, words.size()])


# ---------------------------------------------------------------------------
# Q2: the truth route
# ---------------------------------------------------------------------------

func _truth() -> void:
	DialogueBook.reload()
	var people: RefCounted = PeopleState.new()
	var inventory: Node = Inventory.new()
	var her: Dictionary = DialogueBook.character("curandera")
	var him: Dictionary = DialogueBook.character("librarian")

	var first := _visit("curandera", people, inventory)
	var opened_first: bool = _opened(first, her, "open_first")
	var asked: bool = _pick(first, her, "open_first", "asks") and _line_is(first, her, "asks")
	var listed: bool = people.goals_listed().any(func(g): return g["id"] == "bring_book" and not g["done"])

	var sent := _visit("librarian", people, inventory)
	var opened_sent: bool = _opened(sent, him, "open_sent")
	var told: bool = _pick(sent, him, "open_sent", "truth") and _line_is(sent, him, "truth")
	_play(sent[0])
	var on_belt: bool = inventory.count_of(&"the_book") == 1 and people.mood_of("librarian") == 1

	var back := _visit("curandera", people, inventory)
	var opened_book: bool = _opened(back, her, "open_has_book")
	var handed: bool = _pick(back, her, "open_has_book", "gives_bundle") and _line_is(back, her, "gives_bundle")
	_play(back[0])
	var job: RefCounted = _job(people)
	var sides := LetterText.sides(job)
	var goal_text := _goal_text("bring_book")
	var note_text := String((DialogueBook.library()["notes"] as Dictionary).get("curandera_bundle", {}).get("text", "?"))
	var struck: bool = sides[0].contains("[s]%s[/s]" % LetterText.escape(goal_text))
	var noted: bool = sides.size() == 2 and sides[1].contains(LetterText.escape(note_text))
	var swapped: bool = inventory.count_of(&"the_book") == 0 and inventory.count_of(&"copal_bundle") == 1 \
		and people.goal_done("bring_book") and people.holds("gave(the_book)", "curandera")

	# The other two ways to the book: his price, and the special option.
	var payer: RefCounted = PeopleState.new()
	var purse: Node = Inventory.new()
	purse.add_loot(5)
	_play(_visit("curandera", payer, purse)[0])
	var pay_talk := _visit("curandera", payer, purse)
	_pick(pay_talk, her, "open", "asks")
	var buying := _visit("librarian", payer, purse)
	var paid: bool = _pick(buying, him, "open_sent", "pay") and purse.purse == 0 and purse.count_of(&"the_book") == 1
	var special_people: RefCounted = PeopleState.new()
	var special_belt: Node = Inventory.new()
	_pick(_visit("curandera", special_people, special_belt), her, "open_first", "asks")
	var red := _visit("librarian", special_people, special_belt)
	var specials: Array = [] if red[1]["options"].is_empty() else (red[1]["options"].back() as Array).filter(func(o): return o["special"])
	var special_ok: bool = specials.size() == 1 and _pick(red, him, "open_sent", "special") and special_belt.count_of(&"the_book") == 1
	_release(job, people)

	_check("Q2 the truth route: she asks (the goal listed), he gives on the truth, she takes the book for her copal (goal struck, note on the back); his price and the special option give it too",
		opened_first and asked and listed and opened_sent and told and on_belt and opened_book and handed and struck and noted and swapped
		and paid and special_ok,
		"first %s asked %s listed %s | sent %s told %s belt %s | has_book %s handed %s struck %s noted %s swapped %s | paid %s special %s" % [
		opened_first, asked, listed, opened_sent, told, on_belt, opened_book, handed, struck, noted, swapped, paid, special_ok])
	inventory.free()
	purse.free()
	special_belt.free()


# ---------------------------------------------------------------------------
# Q3: the lie route
# ---------------------------------------------------------------------------

func _lie() -> void:
	var people: RefCounted = PeopleState.new()
	var inventory: Node = Inventory.new()
	var her: Dictionary = DialogueBook.character("curandera")
	var him: Dictionary = DialogueBook.character("librarian")
	var shade: StaticBody3D = Shade.new()
	shade.character = "librarian"
	add_child(shade)
	await _frames(2)

	_pick(_visit("curandera", people, inventory), her, "open_first", "asks")
	var sent := _visit("librarian", people, inventory, shade)
	var lied: bool = _pick(sent, him, "open_sent", "lie") and _line_is(sent, him, "lie")
	_play(sent[0])
	shade.end_line()
	var dimmed: bool = shade.shade_state() == &"dim" and people.mood_of("librarian") == -1 and inventory.count_of(&"the_book") == 0
	var again := _visit("librarian", people, inventory, shade)
	var after_lie: bool = _opened(again, him, "open_after_lie")
	var amends: bool = _pick(again, him, "open_after_lie", "amends") and _line_is(again, him, "amends")
	shade.end_line()
	var calm: bool = shade.shade_state() == &"calm" and not people.holds("said(lied)", "librarian")
	var truth_now: bool = _pick(again, him, "amends", "truth") and inventory.count_of(&"the_book") == 1
	_check("Q3 the lie route: the lie dims him (mood -1, resting dim), his next opener is open_after_lie, amends calms him and the truth is open again",
		lied and dimmed and after_lie and amends and calm and truth_now,
		"lied %s dimmed %s (state %s, mood %d) after_lie %s amends %s calm %s truth %s" % [lied, dimmed, shade.shade_state(),
		people.mood_of("librarian"), after_lie, amends, calm, truth_now])
	shade.queue_free()
	inventory.free()
	await _frames(2)


# ---------------------------------------------------------------------------
# Q4: after the quest
# ---------------------------------------------------------------------------

func _revisits() -> void:
	var her: Dictionary = DialogueBook.character("curandera")
	var him: Dictionary = DialogueBook.character("librarian")
	var remembers := _sense_text(him, "open")

	# The truth route, never lied to.
	var honest: RefCounted = PeopleState.new()
	var belt: Node = Inventory.new()
	_quest(honest, belt, false)
	var hers := _visit("curandera", honest, belt)
	var his := _visit("librarian", honest, belt)
	var plain: bool = _opened(hers, her, "open_after") and _opened(his, him, "open") and his[1]["senses"].is_empty()

	# The lie, amends, then the truth: the lie is cleared, and he remembers it.
	var liar: RefCounted = PeopleState.new()
	var pocket: Node = Inventory.new()
	_quest(liar, pocket, true)
	var hers_after := _visit("curandera", liar, pocket)
	var his_after := _visit("librarian", liar, pocket)
	var kept: bool = _opened(hers_after, her, "open_after") and _opened(his_after, him, "open") \
		and not liar.holds("said(lied)", "librarian") and (his_after[1]["senses"] as Array).map(func(s): return s[1]) == [remembers]

	# The lie never mended: he still opens on it, after the quest too.
	var sulk: RefCounted = PeopleState.new()
	var bag: Node = Inventory.new()
	_pick(_visit("curandera", sulk, bag), her, "open_first", "asks")
	_pick(_visit("librarian", sulk, bag), him, "open_sent", "lie")
	var still: bool = _opened(_visit("librarian", sulk, bag), him, "open_after_lie")
	_check("Q4 after the quest she opens on open_after and he on open; a mended lie is cleared and remembered (his sense line); an unmended one is kept",
		plain and kept and still,
		"plain %s kept %s still %s (senses %s)" % [plain, kept, still, his_after[1]["senses"]])
	belt.free()
	pocket.free()
	bag.free()


# ---------------------------------------------------------------------------
# Q5: the types
# ---------------------------------------------------------------------------

func _types() -> void:
	var her: Dictionary = DialogueBook.character("curandera")
	var market: Dictionary = DialogueBook.type_character("curandera", MARKET)
	var type_line := _first_say(DialogueBook.library()["types"].get("curandera", {}), "limpia")
	var belt: Node = Inventory.new()

	var own := _visit("curandera", PeopleState.new(), belt)
	var own_ok: bool = _pick(own, her, "open_first", "limpia") and _line_is(own, her, "limpia") and her["beats"]["limpia"]["own"] \
		and not (own[1]["lines"] as Array).any(func(l): return l[1] == type_line[1])
	var nameless := _visit_with(market, PeopleState.new(), belt)
	var type_ok: bool = not market.is_empty() and _opened(nameless, market, "open") \
		and _pick(nameless, market, "open", "limpia") and (nameless[1]["lines"] as Array).has([MARKET, type_line[1], type_line[2]])
	var book_type: Dictionary = DialogueBook.library()["types"].get("bookseller", {"beats": {}})
	var his_options := _offered_to(_visit("librarian", PeopleState.new(), belt))
	var bookseller_ok: bool = his_options.has("ask_title") and DialogueBook.character("librarian").get("beats", {}).has("buy_book") \
		and book_type["beats"].has("ask_title") and book_type["beats"].has("buy_book")
	_check("Q5 the type-only curandera offers the type's limpia (spoken by her name), the named curandera her own; the librarian a bookseller's",
		own_ok and type_ok and bookseller_ok,
		"own %s type %s (heard %s) bookseller %s (%s)" % [own_ok, type_ok, nameless[1]["lines"], bookseller_ok, his_options])
	belt.free()


# ---------------------------------------------------------------------------
# Q6: a new mission
# ---------------------------------------------------------------------------

func _new_mission() -> void:
	var her: Dictionary = DialogueBook.character("curandera")
	CityState.people = PeopleState.new()
	CityState.begin()
	var belt: Node = Inventory.new()
	_quest(CityState.people, belt, false)
	var struck_before: bool = LetterText.sides(CityState.job)[0].contains(LetterText.escape(_goal_text("bring_book")))
	CityState.begin()
	var after := _visit("curandera", CityState.people, belt)
	var gone: bool = not LetterText.sides(CityState.job)[0].contains(LetterText.escape(_goal_text("bring_book"))) \
		and CityState.people.goals_listed().is_empty() and CityState.people.goal_done("bring_book")
	_check("Q6 a new mission keeps it all: she still opens on open_after, the done goal has left the letter",
		struck_before and _opened(after, her, "open_after") and gone,
		"on the letter before %s, opener after %s, gone %s" % [struck_before, after[1]["lines"], gone])
	CityState.people = PeopleState.new()
	CityState.begin()
	belt.free()


# ---------------------------------------------------------------------------
# Q7: in the candle lane
# ---------------------------------------------------------------------------

func _in_the_lane() -> void:
	var lane: Node3D = LANE.instantiate()
	add_child(lane)
	await _frames(20)
	var player: CharacterBody3D = lane.get("player")
	var shades := {}

	for node in lane.find_children("*", "StaticBody3D", true, false):
		if node.get_script() == Shade:
			var key: String = node.character if node.character != "" else "type:%s:%s" % [node.type_id, node.display_name]
			shades[key] = node

	var market_key := "type:curandera:%s" % MARKET
	var standing: bool = shades.has("curandera") and shades.has("librarian") and shades.has(market_key) \
		and _inside_shop(lane, shades.get("librarian"))
	var spawn: Vector3 = player.global_position if player != null else Vector3.INF
	var reached := {}

	if standing and player != null:
		# From the spawn, on foot: into the shop to his desk's front, back out and along the lane to the ledges.
		reached["librarian"] = await _talk_to(player, shades["librarian"],
			[Vector3(1.0, 0, 3.0), Vector3(6.2, 0, 3.2), Vector3(6.2, 0, 7.0), Vector3(6.2, 0, 8.1), Vector3(7.1, 0, 8.3)], lane)
		reached["curandera"] = await _talk_to(player, shades["curandera"],
			[Vector3(6.2, 0, 8.1), Vector3(6.2, 0, 3.2), Vector3(11.0, 0, 2.2), Vector3(11.6, 0, 2.0)], lane)
		reached[market_key] = await _talk_to(player, shades[market_key], [Vector3(14.4, 0, 2.0)], lane)

	var all_ok: bool = reached.size() == 3 and reached.values().all(func(r): return r["ok"])
	_check("Q7 the candle lane holds both shades (him in his shop) and the type-only curandera; from the spawn the player walks to each, the frob finds it within 2.2 m as Talk, and E opens its painted box",
		standing and all_ok and spawn.distance_to(Vector3(0.0, 1.0, 4.0)) < 0.2,
		"shades %s, spawn %s, %s" % [shades.keys(), spawn, reached])
	lane.queue_free()
	await _frames(2)


## Whether `shade` stands on the shop's floor, inside its room.
func _inside_shop(lane: Node3D, shade: Node3D) -> bool:
	if shade == null:
		return false

	var local: Vector3 = (lane.shop as Node3D).to_local(shade.global_position)
	return absf(local.x) < 4.0 and local.z < 0.0 and local.z > -6.0


## Walks the player along `way` (the lane's frame, on its floor) from where he
## stands, then turns his view on the shade's chest: the frob finds it within
## reach with the prompt Talk, and E opens its box (painted if its paintings
## are here), which is then broken off.
func _talk_to(player: CharacterBody3D, shade: Node3D, way: Array, lane: Node3D) -> Dictionary:
	for point in way:
		var leg := await _leg(player, lane.to_global(point) + Vector3(0, 1.0, 0))

		if not leg["ok"]:
			return {"ok": false, "stuck": "to %s at %s" % [point, lane.to_local(player.global_position)]}

	_aim(player, shade.global_position + Vector3(0, 1.2, 0))
	await _frames(10)
	var found: bool = player.frob.target == shade
	var prompt: String = player.frob.current_prompt()
	var eye: Vector3 = player.get_node("Neck/Camera3D").global_position
	var reach: float = eye.distance_to(player.frob._target_point)
	await _press("frob")
	var box: Node = player.frob.talking()
	var id := String(shade.dialogue.get("id", ""))
	var opened := box != null
	var painted: bool = opened and (box.skin.backdrop != null) == TalkSkin.exists(id)
	var ok: bool = found and prompt == "Talk" and reach <= REACH and opened and painted

	if opened:
		box.interrupt()

	await _frames(4)
	return {"ok": ok, "found": found, "prompt": prompt, "reach": snappedf(reach, 0.01), "box": opened, "painted": painted,
		"paintings here": TalkSkin.exists(id), "at": lane.to_local(player.global_position).snapped(Vector3.ONE * 0.01)}


## One leg on foot: steered every frame toward `target` (as a player would),
## until across from it; fails if it stalls.
func _leg(player: CharacterBody3D, target: Vector3) -> Dictionary:
	var from := player.global_position
	var heading := Vector2(target.x - from.x, target.z - from.z)

	if heading.length() < REACHED:
		return {"ok": true}

	Input.action_press("move_forward")
	var arrived := false
	var still := 0
	var last := player.global_position

	for i in LEG_FRAMES:
		var here := player.global_position
		var to := Vector2(target.x - here.x, target.z - here.z)
		player.rotation.y = atan2(-to.x, -to.y)
		await get_tree().physics_frame
		here = player.global_position
		to = Vector2(target.x - here.x, target.z - here.z)
		still = still + 1 if here.distance_to(last) < 0.003 else 0
		last = here

		if to.length() < REACHED or to.dot(heading) < 0.0:
			arrived = true
			break

		if still > 30:
			break

	Input.action_release("move_forward")
	await _frames(6)
	return {"ok": arrived}


# ---------------------------------------------------------------------------
# Driving the talk
# ---------------------------------------------------------------------------

## The truth route (or the lie, amends and then the truth) to the end: she
## asks, he gives the book, she takes it for her copal.
func _quest(people: RefCounted, inventory: Node, lying: bool) -> void:
	var her: Dictionary = DialogueBook.character("curandera")
	var him: Dictionary = DialogueBook.character("librarian")
	_pick(_visit("curandera", people, inventory), her, "open_first", "asks")

	if lying:
		_pick(_visit("librarian", people, inventory), him, "open_sent", "lie")
		var mend := _visit("librarian", people, inventory)
		_pick(mend, him, "open_after_lie", "amends")
		_pick(mend, him, "amends", "truth")
	else:
		_pick(_visit("librarian", people, inventory), him, "open_sent", "truth")

	_pick(_visit("curandera", people, inventory), her, "open_has_book", "gives_bundle")


## Every signal of `talk`, collected.
func _listen(talk: RefCounted) -> Dictionary:
	var heard := {"lines": [], "senses": [], "options": [], "ended": []}
	talk.line.connect(func(speaker, text, cues): heard["lines"].append([speaker, text, cues]))
	talk.sense.connect(func(school, text): heard["senses"].append([school, text]))
	talk.options.connect(func(list): heard["options"].append(list))
	talk.ended.connect(func(how): heard["ended"].append(how))
	return heard


## A talk with character `id`, started and played to its first choice:
## [talk, heard, who]. With a shade, it hears the cues and resting states as
## the box would pass them on.
func _visit(id: String, people: RefCounted, inventory: Node, shade: Node = null) -> Array:
	return _visit_with(DialogueBook.character(id), people, inventory, shade)


func _visit_with(who: Dictionary, people: RefCounted, inventory: Node, shade: Node = null) -> Array:
	var talk: RefCounted = Conversation.new(who, people, inventory)
	var heard := _listen(talk)

	if shade != null:
		talk.cue.connect(shade.cue)
		talk.resting.connect(shade.set_resting)

	talk.start()
	_play(talk)
	return [talk, heard, who]


## Advances until the conversation wants a choice or is over.
func _play(talk: RefCounted) -> void:
	var guard := 0

	while not talk.is_over() and not talk.is_waiting_for_choice() and guard < 200:
		talk.advance()
		guard += 1


## Chooses, in the visit's last options, the one `beat` of `who` writes leading
## to `to`, and plays on to the next choice. False if it was not offered.
func _pick(visit: Array, who: Dictionary, beat: String, to: String) -> bool:
	var talk: RefCounted = visit[0]
	var heard: Dictionary = visit[1]
	var text := _option_text(who, beat, to)

	if not talk.is_waiting_for_choice() or text == "" or heard["options"].is_empty():
		return false

	var index: int = (heard["options"].back() as Array).map(func(o): return String(o["text"])).find(text)

	if index < 0:
		return false

	talk.choose(index)
	_play(talk)
	return true


## The beats the last options offered lead to (by their texts in the opener played).
func _offered_to(visit: Array) -> Array:
	var who: Dictionary = visit[2]
	var heard: Dictionary = visit[1]
	var texts: Array = (heard["options"].back() as Array).map(func(o): return String(o["text"])) if not heard["options"].is_empty() else []
	var out := []

	for beat in (who.get("beats", {}) as Dictionary).values():
		for line in beat["body"]:
			if line["type"] == "option" and texts.has(String(line["text"])) and not out.has(line["to"]):
				out.append(line["to"])

	return out


## Whether the visit's first line is the first line of `beat`.
func _opened(visit: Array, who: Dictionary, beat: String) -> bool:
	var lines: Array = visit[1]["lines"]
	return not lines.is_empty() and lines[0][1] == _first_say(who, beat)[1]


## Whether the visit's last line heard is the first line of `beat` (just entered).
func _line_is(visit: Array, who: Dictionary, beat: String) -> bool:
	var lines: Array = visit[1]["lines"]
	return not lines.is_empty() and (lines.any(func(l): return l[1] == _first_say(who, beat)[1]))


## [speaker, text, cues] of the first spoken line of `beat` (written, before {name}).
func _first_say(who: Dictionary, beat: String) -> Array:
	for line in (who.get("beats", {}) as Dictionary).get(beat, {}).get("body", []):
		if line["type"] == "say":
			return [line["speaker"], line["text"], line["cues"]]

	return ["", "?", []]


## The text of the first sense line of `beat`.
func _sense_text(who: Dictionary, beat: String) -> String:
	for line in (who.get("beats", {}) as Dictionary).get(beat, {}).get("body", []):
		if line["type"] == "sense":
			return String(line["text"])

	return "?"


## The text of the option of `beat` leading to `to`, or "".
func _option_text(who: Dictionary, beat: String, to: String) -> String:
	for line in (who.get("beats", {}) as Dictionary).get(beat, {}).get("body", []):
		if line["type"] == "option" and line["to"] == to:
			return String(line["text"])

	return ""


func _goal_text(id: String) -> String:
	for goal in DialogueBook.library()["goals"]:
		if goal["id"] == id:
			return String(goal["text"])

	return "?"


## A job of its own (no book) holding `people`, for the letter.
func _job(people: RefCounted) -> RefCounted:
	var job: RefCounted = (load("res://scripts/Level/JobState.gd") as GDScript).new()
	job.reset()
	job.people = people
	return job


## The job and the people hold each other: let go, or neither is ever freed.
func _release(job: RefCounted, people: RefCounted) -> void:
	job.people = null
	people.job = null


# ---------------------------------------------------------------------------

## Turns the player's view on `point`.
func _aim(player: CharacterBody3D, point: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck/Camera3D").global_position
	var to := point - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Neck").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## One press of an action, a frame long.
func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
