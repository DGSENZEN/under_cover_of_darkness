extends Node3D
## The letter and the readables in both hands (the harbour's job plan, Tasks
## 4-6): J raises and lowers the letter, its front the job and its back the
## pencil notes; what lowers it; both hands on the page; readables held and
## put back; the seal turned in the hand; the goal's sting.
##   Godot --headless --fixed-fps 60 --path . res://tests/letter_test.tscn

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const HeldPage := preload("res://scripts/Interaction/HeldPage.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const CITY := preload("res://maps/city.tscn")

var player: CharacterBody3D
var results: Array[String] = []


func _ready() -> void:
	TemperamentScript.rolling = false
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	add_child(world)
	Props.block(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	CityState.begin()
	player = PLAYER.instantiate()
	player.set("show_hud", false)
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.reload_on_death = false
	player.global_position = Vector3(0, 1.05, 0)
	Props.give_blackjack(player)
	CityState.job.arrive(&"harbour")
	await _frames(10)
	await _letter()
	await _readables()
	await _special()
	await _harbour()
	print("\n==== RESULTS ====")

	for line in results:
		print(line)

	var failed := results.filter(func(r): return r.begins_with("FAIL")).size()
	print("\n%d pass, %d fail" % [results.size() - failed, failed])
	get_tree().quit()


# ---------------------------------------------------------------------------
# L1-L11: the letter
# ---------------------------------------------------------------------------

func _letter() -> void:
	var hand: Node = player.hand
	var frob: Node = player.frob

	await _tap("letter")
	var up: bool = hand.is_page_up() and frob.letter_up()
	await _frames(10)
	await _tap("letter")
	await _frames(2)
	_check("L1 J raises the letter and J lowers it", up and not hand.is_page_up() and not frob.letter_up(),
		"up %s, after %s" % [up, hand.is_page_up()])

	await _raise()
	var page: Node = hand.page()
	var front: String = page.text_of(0)
	var commission := String(CityState.job.book["letter"]["text"])
	var listed: bool = CityState.job.goals_listed().all(func(g): return front.contains(String(g["text"])))
	CityState.job.took_loot("the_seal", 250)
	await _frames(2)
	var seal_text := ""

	for g in CityState.job.goals_listed():
		if g["id"] == "seal":
			seal_text = String(g["text"])

	var struck: bool = page.text_of(0).contains("[s]" + seal_text)
	_check("L2 the front lists the job, a done goal struck through", front.contains(commission) and listed and struck,
		"commission %s, listed %s, struck %s" % [front.contains(commission), listed, struck])

	CityState.begin()
	CityState.job.arrive(&"harbour")
	var ids: Array = (CityState.job.book["notes"] as Dictionary).keys()

	for i in ids.size():
		CityState.job.learn(String(ids[i]))

	# Eleven notes: the harbour's eight and three more from a book of its own.
	var extra: Dictionary = CityState.job.book.duplicate(true)

	for n in ["n_a", "n_b", "n_c"]:
		extra["notes"][n] = {"id": n, "text": "<<%s>>" % n}

	CityState.job.book = extra

	for n in ["n_a", "n_b", "n_c"]:
		CityState.job.learn(n)

	await _frames(2)
	var sides: int = page.side_count()
	var side_1: PackedStringArray = _lines(page.text_of(1))
	var side_2: PackedStringArray = _lines(page.text_of(2)) if sides > 2 else PackedStringArray()
	var pencil: bool = side_1.size() == 10 and Array(side_1).all(func(l): return String(l).contains("— ")) and side_2.size() == 1
	_check("L3 the back holds the notes in pencil, ten to a side", sides == 3 and pencil,
		"%d sides, side 1 %d lines, side 2 %d" % [sides, side_1.size(), side_2.size()])

	await _tap("throw")
	await _frames(2)
	_check("L4 a click turns the sheet; it is not an attack", page.side == 1 and frob._swing_windup < 0.0 and float(hand._swing) == 0.0,
		"side %d, windup %.2f, swing %.2f" % [page.side, frob._swing_windup, hand._swing])

	var door: Node3D = Props.door(self, Vector3(0.0, 0.0, -1.6))
	await _aim(Vector3(0.0, 1.0, -1.6))
	await _tap("frob")
	await _frames(20)
	_check("L5 E puts the letter away and opens nothing", not hand.is_page_up() and door.get("is_open") == false,
		"up %s, door open %s" % [hand.is_page_up(), door.get("is_open")])
	door.queue_free()
	await _frames(2)

	await _raise()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(20)
	var sprint_lowers: bool = not hand.is_page_up()
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _settle()
	await _raise()
	await _tap("jump")
	await _frames(6)
	var jump_lowers: bool = not hand.is_page_up()
	await _settle()
	await _raise()
	player.movement_state = player.MoveState.CLIMBING
	var climb_lowers: bool = frob.page_must_lower()
	player.movement_state = player.MoveState.LOCOMOTION
	_check("L6 sprinting, jumping and climbing lower it", sprint_lowers and jump_lowers and climb_lowers,
		"sprint %s, jump %s, climb %s" % [sprint_lowers, jump_lowers, climb_lowers])

	await _raise()
	await _frames(30)
	var weights: Array = hand._grip_weights
	_check("L7 both hands hold the page; what the right held goes down", float(weights[0]) > 0.9 and float(weights[1]) > 0.9
		and float(hand._main_lower) > 0.9, "grips %.2f %.2f, main lowered %.2f" % [weights[0], weights[1], hand._main_lower])

	var material: Variant = page.paper_material()
	var lit: bool = material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled \
		and (material as StandardMaterial3D).emission_energy_multiplier >= HeldPage.LIGHT_FLOOR \
		and (material as StandardMaterial3D).albedo_texture is ViewportTexture
	_check("L8 the page reads in the dark: its own words lit to a floor", lit, "material %s" % material)

	player.take_damage(5.0, null)
	await _frames(12)
	_check("L9 getting hit puts the page away", not hand.is_page_up(), "up %s" % hand.is_page_up())
	player.health = player.max_health if player.get("max_health") != null else player.health
	await _settle()

	var crate: RigidBody3D = Props.crate(self, Vector3(0.0, 0.3, -1.3))
	await _aim(crate.global_position)
	await _tap("frob")
	await _frames(4)
	var carrying: bool = frob.held != null
	await _tap("letter")
	await _frames(2)
	var no_page_carrying: bool = not hand.is_page_up()
	await _tap("frob")
	await _frames(10)
	crate.queue_free()
	var locked: Node3D = Props.door(self, Vector3(0.0, 0.0, -1.6), 0.0, 1.0, 2.1, true, &"study", "study door")
	player.inventory.add_key(&"study", "study key")
	await _settle()
	await _aim(Vector3(0.0, 1.0, -1.6))
	await _tap("frob")
	await _frames(2)
	var unlocking: bool = frob._unlocking
	await _tap("letter")
	await _frames(60)
	_check("L10 J does nothing while the hands are busy (carrying, turning a key); the key still turns",
		carrying and no_page_carrying and unlocking and not hand.is_page_up() and locked.get("locked") == false,
		"carrying %s, page %s; unlocking %s, page %s, unlocked %s" % [carrying, not no_page_carrying, unlocking, hand.is_page_up(),
			locked.get("locked") == false])
	locked.queue_free()
	await _settle()

	await _raise()
	await _tap("throw")
	await _frames(2)
	var blowhole := "<<pencil: the blowhole>>"
	CityState.begin()
	CityState.job.arrive(&"harbour")
	CityState.job.learn("office_key")
	await _frames(1)
	var before: String = page.text_of(1)
	CityState.job.learn("blowhole")
	var now: String = page.text_of(1)
	_check("L11 a note learnt while reading shows at once", hand.is_page_up() and not before.contains(blowhole) and now.contains(blowhole),
		"up %s, before %s, now %s" % [hand.is_page_up(), before.contains(blowhole), now.contains(blowhole)])
	frob.put_page_away()
	await _frames(2)


# ---------------------------------------------------------------------------
# L12-L14: readables
# ---------------------------------------------------------------------------

func _readables() -> void:
	var hand: Node = player.hand
	var frob: Node = player.frob
	CityState.begin()
	CityState.job.arrive(&"harbour")
	await _settle()

	# A paper lying on a desk in front.
	Props.block(self, Vector3(0.0, 0.4, -1.4), Vector3(1.0, 0.8, 0.6))
	var lying := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.8, -1.4))
	var paper: Node3D = Props.readable(self, lying, &"paper", "duty_orders")
	var was: Transform3D = paper.global_transform
	await _aim(paper.global_position)
	var prompt: Array = frob.current_actions()
	await _tap("frob")
	await _frames(4)
	var held: bool = hand.is_page_up() and hand.page_look() == &"paper" and not paper.visible and frob.reading() == paper
	var taken: bool = CityState.job.read_slots == ["duty_orders"] and CityState.job.notes.has("office_key")
	var words: String = hand.page().text_of(0)
	await _tap("frob")
	await _frames(4)
	_check("L12 reading a paper holds it up, adds its note, and puts it back", prompt == [[&"frob", "Read"]] and held and taken
		and words.contains("<<the duty orders>>") and not hand.is_page_up() and paper.visible and paper.global_transform.is_equal_approx(was),
		"prompt %s, held %s, read %s notes %s, back %s %s" % [prompt, held, CityState.job.read_slots, CityState.job.notes,
			not hand.is_page_up(), paper.visible])

	# A notice on a wall to the left: read, then walked away from.
	await _settle()
	Props.block(self, Vector3(-1.6, 1.5, 0.0), Vector3(0.2, 3.0, 2.0))
	var on_wall := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-1.5, 1.6, 0.0))
	var notice: Node3D = Props.readable(self, on_wall, &"notice", "curfew")
	await _aim(notice.global_position)
	await _tap("frob")
	await _frames(4)
	var reading_notice: bool = hand.is_page_up() and hand.page_look() == &"notice" and notice.visible
	var look_away: Array = frob.current_actions()
	player.global_position += Vector3(2.1, 0.0, 0.0)
	await _frames(3)
	var walked_off: bool = not hand.is_page_up()
	await _settle()
	await _aim(paper.global_position)
	await _tap("frob")
	await _frames(4)
	var paper_up: bool = hand.is_page_up() and not paper.visible
	frob.drop_held()
	frob.put_page_away()
	await _frames(2)
	_check("L13 walking 2 m away lowers a notice; the hands put away for a journey lower any page, the paper put back",
		reading_notice and look_away == [[&"frob", "Look away"]] and walked_off and paper_up and not hand.is_page_up() and paper.visible,
		"notice %s %s, walked off %s, paper up %s, after %s %s" % [reading_notice, look_away, walked_off, paper_up, hand.is_page_up(),
			paper.visible])

	await _settle()
	var nothing: Node3D = Props.readable(self, Transform3D(Basis.IDENTITY, Vector3(0.4, 0.8, -1.4)), &"paper", "nothing_here")
	await _aim(nothing.global_position)
	await _tap("frob")
	await _frames(4)
	_check("L14 a readable whose slot has no words reads as its placeholder", hand.is_page_up() and hand.page().text_of(0) == "<<nothing_here>>",
		"up %s, words %s" % [hand.is_page_up(), hand.page().text_of(0) if hand.page() != null else "-"])
	frob.put_page_away()
	await _frames(2)


# ---------------------------------------------------------------------------
# L15-L18: the seal in the hand; the goal's sting; the mission's letter
# ---------------------------------------------------------------------------

func _special() -> void:
	var hand: Node = player.hand
	await _settle()
	var seal: RigidBody3D = Props.loot(self, Vector3(0.0, 0.9, -1.4), 250, "seal")
	seal.set_meta(&"special", true)
	seal.freeze = true
	await _aim(seal.global_position)
	await _tap("frob")
	await _frames(2)
	var kind := String(hand._job.get("kind", ""))
	await _frames(32)
	var shown: bool = hand._off_item.visible
	var turned: float = absf(hand._off_item.rotation.y)
	await _frames(74)
	_check("L15 the seal turns in the hand, then goes", kind == "special" and shown and turned > 1.0 and hand._job.is_empty(),
		"job %s, shown %s, turned %.2f rad, done %s" % [kind, shown, turned, hand._job.is_empty()])

	await _settle()
	var ring: RigidBody3D = Props.loot(self, Vector3(0.0, 0.9, -1.4), 150, "ring")
	ring.set_meta(&"special", true)
	ring.freeze = true
	await _aim(ring.global_position)
	await _tap("frob")
	await _frames(18)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(24)
	var cut: bool = hand._job.is_empty()
	Input.action_release("sprint")
	Input.action_release("move_forward")
	_check("L16 sprinting cuts the turn short", cut, "job %s" % hand._job.get("kind", "none"))
	await _settle()


func _harbour() -> void:
	# The letter test's own player gives way to the harbour's.
	player.queue_free()
	await _frames(2)
	CityState.begin()
	var city: Node3D = CITY.instantiate()
	add_child(city)
	await city.ready_to_play
	player = city.player
	await _frames(4)
	var opened: bool = player.hand.is_page_up() and player.frob.letter_up()
	var actions: Array = player.frob.current_actions()
	_check("L18 a fresh mission opens with the letter up", opened and actions == [[&"letter", "Put away"]] and CityState.job.letter_opened,
		"up %s, actions %s" % [opened, actions])
	player.frob.put_page_away()
	await _frames(10)

	Sfx.recording = true
	Sfx.recorded.clear()
	var seal: Node = city.made["city_harbour"]["pickups"]["the_seal"]
	player.frob.target = seal
	player.frob._on_frob()
	await _frames(4)
	var sounds: Array = Sfx.recorded.map(func(r): return String(r[0]))
	Sfx.recording = false
	var tally: Dictionary = CityState.job.tally_of(&"harbour")
	var caption: String = player.hud._caption.text if player.hud != null else ""
	_check("L17 taking the seal: the goal's sting, the way up noted, the loot counted",
		sounds.has("sting_goal") and CityState.job.done.has("seal") and CityState.job.notes.has("way_up") and caption == "Noted"
		and int(tally.get("loot", 0)) == 250 and int(tally.get("specials", 0)) == 1,
		"sounds %s, done %s, notes %s, caption '%s', tally %s" % [sounds, CityState.job.done, CityState.job.notes, caption, tally])
	city.queue_free()
	await _frames(2)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## The letter up, from rest.
func _raise() -> void:
	if not player.hand.is_page_up():
		await _tap("letter")

	await _frames(2)


## Standing still on the floor again, nothing pressed, the page down.
func _settle() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "frob", "throw", "letter"]:
		if InputMap.has_action(a):
			Input.action_release(a)

	if player.hand.is_page_up():
		player.frob.put_page_away()

	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 1.05, 0)
	await _frames(30)


func _aim(at: Vector3) -> void:
	var eye: Vector3 = player.get_node("Neck/Camera3D").global_position
	var to := at - eye
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Neck").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(3)


func _lines(text: String) -> PackedStringArray:
	return text.strip_edges().split("\n", false)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
