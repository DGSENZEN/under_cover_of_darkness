extends Node3D
## The garrison's night: the fire burning down and fed (Fire), the night
## rota (duties, needs, the hour: NightRota), and the things the men do
## together (Gathering: dice, the flask, a story, the watch changing, the
## captain's round, waking the sleeper, feeding the fire).
##
##   Godot --headless --fixed-fps 60 --quit-after 3000000 --path . res://tests/routines_test.tscn

const FireScript := preload("res://scripts/Combat/Fire.gd")
const PLAYER := preload("res://Player.tscn")
const GUARD := preload("res://Guard.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const NavBakerScript := preload("res://scripts/AISystem/NavBaker.gd")
const SquadScript := preload("res://scripts/AISystem/Squad.gd")
const GarrisonScript := preload("res://scripts/AISystem/Garrison.gd")
const TemperamentScript := preload("res://scripts/AISystem/Temperament.gd")
const GuardScript := preload("res://scripts/AISystem/Guard.gd")
const LightProbe := preload("res://scripts/StimuliSystem/LightProbe.gd")
const NightRotaScript := preload("res://scripts/AISystem/NightRota.gd")
const GuardStationScript := preload("res://scripts/AISystem/GuardStation.gd")
const GatheringScript := preload("res://scripts/AISystem/Gathering.gd")
const TalkDirector := preload("res://scripts/AISystem/Talk/TalkDirector.gd")
const SoundBus := preload("res://scripts/StimuliSystem/SoundBus.gd")

var results: Array[String] = []
var player: CharacterBody3D


func _ready() -> void:
	await _yard()
	seed(2028)
	GuardScript.randomize_on = false
	await _run()
	GuardScript.randomize_on = true
	print("\n==== RESULTS ====")

	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	await _fire()
	await _rota()
	await _gatherings()
	await _duties()
	await _review_fixes()


# ---------------------------------------------------------------------------
# The fire
# ---------------------------------------------------------------------------

func _fire() -> void:
	# R1 it burns down, its light with it, never quite out
	var fire: Area3D = FireScript.brazier(self, Vector3(0, 0, 20))
	fire.fuel_seconds = 10.0
	var torch: Node3D = fire.torch
	await _frames(480)
	var low_light: float = torch.light.light_energy
	var was_low: bool = fire.low()
	await _frames(420)
	_check("R1 a fire burns down and its light with it, and never quite out",
		was_low and low_light < 0.6 * torch.energy and fire.fuel >= FireScript.EMBERS - 0.001 and fire.burning() == &"low",
		"low %s, light %.2f of %.2f, fuel at the end %.3f" % [was_low, low_light, torch.energy, fire.fuel])

	# R2 fed, it flares, then burns as its fuel says
	var before: float = fire.fuel
	fire.feed()
	var fed: float = fire.fuel
	await _frames(10)
	var base := lerpf(0.25, 1.0, fire.fuel)
	var flared: bool = fire.strength() > base * 1.3
	var ratio: float = torch.light.light_energy / (torch.energy * fire.strength())
	await _frames(180)
	var settled := absf(fire.strength() - lerpf(0.25, 1.0, fire.fuel)) <= lerpf(0.25, 1.0, fire.fuel) * 0.05
	_check("R2 a fire fed a log flares up, then burns as its fuel says, its light following",
		absf(fed - minf(before + 0.6, 1.0)) < 0.01 and flared and absf(ratio - 1.0) <= torch.flicker + 0.02 and settled,
		"fuel %.2f -> %.2f, flared %s, light to strength %.2f, settled %s" % [before, fed, flared, ratio, settled])
	fire.get_parent().queue_free()


# ---------------------------------------------------------------------------
# The night rota
# ---------------------------------------------------------------------------

func _rota() -> void:
	# R3 the hour passes
	await _fresh()
	var rota: RefCounted = NightRotaScript.setup(self, 10.0)
	var idler := _guard(Vector3(0, 0, 0), 0.0)
	var at_start: StringName = rota.hour()
	await _frames(12 * 60)
	var at_12: StringName = rota.hour()
	await _frames(23 * 60)
	var at_35: StringName = rota.hour()
	_check("R3 the night's hour passes: early, then middle, then on to dawn", at_start == &"early" and at_12 == &"middle" and at_35 == &"dawn",
		"%s, %s, %s" % [at_start, at_12, at_35])

	# R4 needs: the cold away from the fire, warmth beside it, rest in bed
	await _fresh()
	rota = NightRotaScript.setup(self, 600.0)
	var fire: Area3D = FireScript.brazier(self, Vector3(40, 0, 0))
	var bed: Node3D = _station(&"sleep", Vector3(40, 0, -12), 0.0)
	rota.add_duty(&"bed", &"bed", {"paths": [bed.get_path()]})
	var far := _guard(Vector3(40, 0, 12), 0.0)
	var near := _guard(Vector3(41.5, 0, 0), 0.0)
	var sleeper := _guard(Vector3(41, 0, -12), 0.0)
	rota.assign(sleeper, &"bed")
	rota.set_need(near, &"cold", 0.5)
	await _until(func(): return sleeper._rota.asleep(), 600)
	rota.set_need(sleeper, &"tired", 0.8)
	await _frames(900)
	var cold_far: float = rota.needs_of(far)["cold"]
	var cold_near: float = rota.needs_of(near)["cold"]
	var tired: float = rota.needs_of(sleeper)["tired"]
	_check("R4 away from the fire a man grows cold, beside it he warms, and asleep he rests",
		cold_far > 0.05 and cold_near < 0.5 and sleeper._rota.asleep() and tired < 0.8,
		"cold far %.3f near %.3f, asleep %s tired %.3f" % [cold_far, cold_near, sleeper._rota.asleep(), tired])
	fire.get_parent().queue_free()

	# R5 a post stood too long wants relief
	await _fresh()
	rota = NightRotaScript.setup(self, 600.0)
	rota.post_turn = 20.0
	rota.add_duty(&"gate", &"post", {"transform": Transform3D(Basis.IDENTITY, Vector3(60, 0, 0))})
	var sentry := _guard(Vector3(60, 0, 0), 0.0)
	rota.assign(sentry, &"gate")
	await _frames(18 * 60)
	var early: bool = rota.asked(sentry, &"relief")
	await _frames(3 * 60)
	var wants: bool = rota.asked(sentry, &"relief")
	_check("R5 a man on a post too long wants relieving, not before", not early and wants, "at 18 s %s, at 21 s %s" % [early, wants])

	# R6 the alarm suspends the rota
	await _fresh()
	rota = NightRotaScript.setup(self, 600.0)
	var hungry := _guard(Vector3(70, 0, 0), 0.0)
	await _frames(5)
	GarrisonScript.of(player).raise_alarm(0.5)
	var held: bool = rota.suspended()
	rota.set_need(hungry, &"hungry", 0.99)
	await _frames(120)
	var nothing: bool = not rota.asked(hungry, &"hungry") and float(rota.needs_of(hungry)["hungry"]) >= 0.99
	GarrisonScript.of(player).alarm = 0.0
	await _frames(60)
	var resumed: bool = not rota.suspended() and rota.asked(hungry, &"hungry")
	_check("R6 the alarm holds the rota: needs still grow, nobody is moved; at ease again it goes on",
		held and nothing and resumed, "held %s, nothing wanted %s, resumed %s (%s)" % [held, nothing, resumed, rota.wanted()])

	# R7 a duty moves a man: a round walked, a post stood
	await _fresh()
	rota = NightRotaScript.setup(self, 600.0)
	var route := Node3D.new()
	add_child(route)

	for point in [Vector3(80, 0, 0), Vector3(80, 0, 10)]:
		var marker := Marker3D.new()
		route.add_child(marker)
		marker.global_position = point

	rota.add_duty(&"round", &"round", {"route": route.get_path()})
	rota.add_duty(&"post", &"post", {"transform": Transform3D(Basis.IDENTITY, Vector3(90, 0, -8))})
	var walker := _guard(Vector3(86, 0, -2), 0.0)
	rota.assign(walker, &"round")
	await _until(func(): return walker.global_position.distance_to(Vector3(80, 0, 10)) < 1.2, 900)
	var rounded: bool = walker.global_position.distance_to(Vector3(80, 0, 10)) < 1.2
	rota.assign(walker, &"post")
	await _frames(900)
	var posted: bool = Vector2(walker.global_position.x - 90, walker.global_position.z + 8).length() < 0.8
	_check("R7 a duty moves a man: he walks the round he is given, then stands the post",
		rounded and posted and rota.duty_of(walker) == &"post", "rounded %s posted %s at %s, duty %s" % [rounded, posted, walker.global_position, rota.duty_of(walker)])
	route.queue_free()


# ---------------------------------------------------------------------------
# Gatherings
# ---------------------------------------------------------------------------

func _gatherings() -> void:
	# R8 dice: gathered, played, and broken up by a noise
	await _fresh()
	var dice := _place(&"dice", Vector3(0, 0, 0), [[Vector3(-0.8, 0, 0.6), &"squat", &"any"], [Vector3(0.8, 0, 0.6), &"squat", &"any"], [Vector3(0, 0, -0.9), &"squat", &"any"]])
	var men := [_guard(Vector3(-3, 0, 6), 0.0), _guard(Vector3(0, 0, 6), 0.0), _guard(Vector3(3, 0, 6), 0.0)]
	for g in men:
		g._life._talk_rest = 0.0
	var gatherings: RefCounted = GatheringScript.of(self)
	var director: RefCounted = TalkDirector.of(self)
	gatherings.request(&"dice")
	await _until(func(): return _gathered(gatherings, &"dice", 3), 900)
	var spots_ok := _gathered(gatherings, &"dice", 3)
	await _until(func(): return director.played().any(func(id): return String(id).begins_with("dice_")), 2400)
	var played: bool = director.played().any(func(id): return String(id).begins_with("dice_"))
	SoundBus.emit_sound(men[0].global_position + Vector3(2, 0, 0), 60.0, self, &"test")
	await _frames(120)
	var over: bool = gatherings.live().is_empty() and not men.any(func(g): return g._rota.on_loan())
	_check("R8 dice: three men gather at the crate, play, and a noise breaks it up",
		spots_ok and played and over, "gathered %s, played %s, over %s (%s)" % [spots_ok, played, over, director.played()])
	dice.queue_free()

	# R9 the flask between two
	await _fresh()
	var a := _guard(Vector3(20, 0, 0), -PI * 0.5)
	var b := _guard(Vector3(22, 0, 0), PI * 0.5)
	for g in [a, b]:
		g._life._talk_rest = 0.0
	gatherings = GatheringScript.of(self)
	director = TalkDirector.of(self)
	gatherings.request(&"flask")
	await _until(func(): return director.played().any(func(id): return String(id).begins_with("flask_")), 1500)
	var flask_talk: Array = director.played().filter(func(id): return String(id).begins_with("flask_"))
	await _until(func(): return gatherings.live().is_empty() and not a._rota.on_loan() and not b._rota.on_loan(), 1500)
	_check("R9 the flask passes between two men, and they go back to what they were at",
		not flask_talk.is_empty() and gatherings.live().is_empty() and not a._rota.on_loan() and not b._rota.on_loan() and gatherings.history().has(&"flask"),
		"played %s, live %d, history %s" % [director.played(), gatherings.live().size(), gatherings.history()])

	# R10 a story at the fire: the teller, and listeners turned to him
	await _fresh()
	var fire: Area3D = FireScript.brazier(self, Vector3(40, 0, 0))
	var story := _place(&"story", Vector3(40, 0, 0), [[Vector3(0, 0, -1.9), &"stand", &"teller"], [Vector3(1.6, 0, 1.0), &"squat", &"listener"], [Vector3(-1.6, 0, 1.0), &"squat", &"listener"], [Vector3(0, 0, 1.9), &"stand", &"listener"]])
	var teller := _guard(Vector3(36, 0, 6), 0.0, &"rash", "Brand")
	var listeners := [_guard(Vector3(39, 0, 6), 0.0), _guard(Vector3(42, 0, 6), 0.0), _guard(Vector3(44, 0, 6), 0.0)]
	for g in [teller] + listeners:
		g._life._talk_rest = 0.0
	gatherings = GatheringScript.of(self)
	director = TalkDirector.of(self)
	gatherings.request(&"story")
	await _until(func():
		for t in director.talks():
			if String(t["id"]).begins_with("story_") and director.speaking(teller):
				return true
		return false, 3000)
	await _frames(30)
	var told: Dictionary = {}

	for t in director.talks():
		if String(t["id"]).begins_with("story_"):
			told = t

	var turned := 0
	var angles := []

	for g in listeners:
		if not (told.get("members", []) as Array).has(g):
			continue

		var pose: Dictionary = await _posed_global(g, [&"Head"])
		var facing: Vector3 = ((pose[&"Head"] as Transform3D).basis * _rest_forward_axis(g)).normalized()
		var to_him: Vector3 = (teller.eye_position() - (pose[&"Head"] as Transform3D).origin).normalized()
		var angle := rad_to_deg(acos(clampf(Vector2(facing.x, facing.z).normalized().dot(Vector2(to_him.x, to_him.z).normalized()), -1.0, 1.0)))
		angles.append(int(angle))

		# His eyes on the teller (his head as well as a squat lets it).
		if director.speaker_near(g) == teller and angle < 50.0:
			turned += 1

	_check("R10 a story at the fire: the storyteller tells it, and the men listening turn to him",
		not told.is_empty() and told["cast"].get("A") == teller and turned >= 2 and turned == angles.size(),
		"story %s, teller cast %s, listeners' heads %s deg off him" % [told.get("id", "none"), told.get("cast", {}).get("A") == teller, angles])
	story.queue_free()
	fire.get_parent().queue_free()


# ---------------------------------------------------------------------------
# The watch, the round, the sleeper, the fire, and needs
# ---------------------------------------------------------------------------

func _duties() -> void:
	# R11 the watch changes: a walk-over, a word, and the duties swap
	await _fresh()
	var rota: RefCounted = NightRotaScript.setup(self, 600.0)
	rota.post_turn = 10.0
	var bench: Node3D = _station(&"sit", Vector3(0, 0, 12), PI)
	rota.add_duty(&"post", &"post", {"transform": Transform3D(Basis.IDENTITY, Vector3(0, 0, -8))})
	rota.add_duty(&"bench", &"bench", {"paths": [bench.get_path()]})
	var on_post := _guard(Vector3(0, 0, -8), 0.0)
	var relief := _guard(Vector3(0, 0, 11), PI)
	rota.assign(on_post, &"post")
	rota.assign(relief, &"bench")
	var director: RefCounted = TalkDirector.of(self)
	var gatherings: RefCounted = GatheringScript.of(self)
	var walked := [false]
	await _until(func():
		if relief.global_position.distance_to(Vector3(0, 0, -8)) < 1.5:
			walked[0] = true
		return rota.duty_of(relief) == &"post", 2400)
	var talked: bool = director.played().any(func(id): return String(id).begins_with("watch_"))
	var swapped: bool = rota.duty_of(relief) == &"post" and rota.duty_of(on_post) == &"bench"
	await _frames(600)
	var left_post: bool = on_post.global_position.distance_to(Vector3(0, 0, -8)) > 3.0
	var standing: bool = Vector2(relief.global_position.x, relief.global_position.z + 8).length() < 0.8
	_check("R11 the watch changes: the relief walks over, a word between them, and their duties swap",
		walked[0] and talked and swapped and left_post and standing,
		"walked %s talked %s swapped %s, the relieved man gone %s, the relief at the post %s (%s)" % [walked[0], talked, swapped, left_post, standing, director.played()])

	# R12 the captain's round reaches every man, and boots the sleeper
	await _fresh()
	var bed: Node3D = _station(&"sleep", Vector3(24, 0, 8), 0.0)
	var captain := _guard(Vector3(20, 0, 0), 0.0, &"steady", "Mirelle", [], &"duelist")
	var sleeper := _guard(Vector3(24.5, 0, 8), 0.0, &"steady", "", [bed])
	var men := [_guard(Vector3(16, 0, 4), 0.0), _guard(Vector3(26, 0, -3), 0.0, &"craven"), _guard(Vector3(18, 0, -6), 0.0, &"rash"), sleeper]
	await _until(func(): return sleeper._rota.asleep(), 900)
	director = TalkDirector.of(self)
	gatherings = GatheringScript.of(self)
	gatherings.request(&"round")
	var visited := {}
	await _until(func():
		for t in director.talks():
			if t["place"] == &"round" and t["cast"].has("B"):
				visited[t["cast"]["B"]] = true
		return visited.size() >= men.size() and gatherings.live().is_empty(), 7200)
	_check("R12 the captain's round reaches every man, and the sleeper is booted awake",
		men.all(func(m): return visited.has(m)) and not sleeper._rota.asleep() and gatherings.history().has(&"round"),
		"visited %d of %d, sleeper asleep %s, history %s" % [visited.size(), men.size(), sleeper._rota.asleep(), gatherings.history()])

	# R13 the relief is asleep: he is woken, then takes the post
	await _fresh()
	rota = NightRotaScript.setup(self, 600.0)
	rota.post_turn = 10.0
	var cot: Node3D = _station(&"sleep", Vector3(40, 0, 10), 0.0)
	rota.add_duty(&"post", &"post", {"transform": Transform3D(Basis.IDENTITY, Vector3(40, 0, -8))})
	rota.add_duty(&"cot", &"bed", {"paths": [cot.get_path()]})
	var guard_post := _guard(Vector3(40, 0, -8), 0.0)
	var dozer := _guard(Vector3(40.5, 0, 10), 0.0)
	rota.assign(guard_post, &"post")
	rota.assign(dozer, &"cot")
	await _until(func(): return dozer._rota.asleep(), 900)
	director = TalkDirector.of(self)
	gatherings = GatheringScript.of(self)
	await _until(func(): return rota.duty_of(dozer) == &"post", 3600)
	var woken: bool = gatherings.history().has(&"wake") and director.played().any(func(id): return String(id).begins_with("wake_"))
	_check("R13 a sleeper wanted for the watch is woken, grumbles, and takes the post",
		woken and rota.duty_of(dozer) == &"post" and not dozer._rota.asleep(), "history %s, played %s, duty %s" % [gatherings.history(), director.played(), rota.duty_of(dozer)])

	# R14 the fire burns low: a man fetches a log and feeds it
	await _fresh()
	var fire: Area3D = FireScript.brazier(self, Vector3(60, 0, 0))
	fire.fuel = 0.3
	fire.fuel_seconds = 100000.0
	var pile := Marker3D.new()
	pile.add_to_group(&"woodpiles")
	add_child(pile)
	pile.global_position = Vector3(60, 0, 6)
	var tender := _guard(Vector3(63, 0, 3), 0.0)
	var shown := {}
	await _until(func():
		shown[tender.activity()] = true
		return fire.fuel > 0.8, 2400)
	_check("R14 the fire burns low: a man fetches a log from the woodpile and feeds it",
		shown.has(&"pick_log") and shown.has(&"feed_fire") and fire.fuel > 0.8, "did %s, fuel %.2f" % [shown.keys(), fire.fuel])
	fire.get_parent().queue_free()
	pile.queue_free()

	# R15 needs move men
	await _fresh()
	rota = NightRotaScript.setup(self, 600.0)
	var hearth: Area3D = FireScript.brazier(self, Vector3(80, 0, 0))
	var bowl: Node3D = _station(&"eat", Vector3(80, 0, 12), 0.0)
	var pallet: Node3D = _station(&"sleep", Vector3(92, 0, 12), 0.0)
	var seat: Node3D = _station(&"sit", Vector3(92, 0, 0), 0.0)
	rota.add_duty(&"pallet", &"bed", {"paths": [pallet.get_path()]})
	rota.add_duty(&"seat", &"bench", {"paths": [seat.get_path()]})
	var eater := _guard(Vector3(84, 0, 12), 0.0)
	var cold := _guard(Vector3(80, 0, -12), 0.0)
	var tired := _guard(Vector3(92, 0, 1), 0.0)
	rota.assign(tired, &"seat")
	await _frames(30)
	rota.set_need(eater, &"hungry", 1.0)
	rota.set_need(cold, &"cold", 1.0)
	rota.set_need(tired, &"tired", 1.0)
	var ate := [false]
	var warmed := [false]
	await _until(func():
		if eater.activity() == &"eat":
			ate[0] = true
		if cold.activity() == &"warm_hands" and Vector2(cold.global_position.x - 80, cold.global_position.z).length() < 2.0:
			warmed[0] = true
		return ate[0] and warmed[0] and rota.kind_of(rota.duty_of(tired)) == &"bed", 1200)
	_check("R15 needs move men: the hungry to eat, the cold to the fire, the tired to bed",
		ate[0] and warmed[0] and rota.kind_of(rota.duty_of(tired)) == &"bed", "ate %s warmed %s, tired man's duty %s" % [ate[0], warmed[0], rota.duty_of(tired)])
	hearth.get_parent().queue_free()


# ---------------------------------------------------------------------------
# The final review's findings
# ---------------------------------------------------------------------------

func _review_fixes() -> void:
	# R16 the storyteller tells the story, whoever else of rank sits with him
	await _fresh()
	var fire: Area3D = FireScript.brazier(self, Vector3(100, 0, 0))
	var story := _place(&"story", Vector3(100, 0, 0), [[Vector3(1.9, 0, 0), &"stand", &"teller"], [Vector3(-1.9, 0, 0), &"squat", &"listener"],
		[Vector3(0, 0, -1.9), &"stand", &"listener"], [Vector3(0.3, 0, 1.9), &"squat", &"listener"]])
	var brand := _guard(Vector3(104, 0, 6), 0.0, &"rash", "Brand", [], &"brute")
	var others := [_guard(Vector3(98, 0, 6), 0.0, &"steady", "Mirelle", [], &"duelist"), _guard(Vector3(100, 0, 7), 0.0), _guard(Vector3(102, 0, 7), 0.0)]
	for g in [brand] + others:
		g._life._talk_rest = 0.0
	var gatherings: RefCounted = GatheringScript.of(self)
	var director: RefCounted = TalkDirector.of(self)
	gatherings.request(&"story")
	var told := [{}]
	await _until(func():
		for t in director.talks():
			if String(t["id"]).begins_with("story_"):
				told[0] = t
		return not told[0].is_empty(), 3000)
	_check("R16 the storyteller tells the story, whoever else of rank sits and listens",
		not told[0].is_empty() and told[0]["cast"].get("A") == brand, "story %s told by %s" % [told[0].get("id", "none"), told[0].get("cast", {}).get("A").given_name if told[0].get("cast", {}).get("A") != null else "nobody"])
	story.queue_free()
	fire.get_parent().queue_free()

	# R17 a gathering asked for and never possible is not asked for forever
	# (a man about to keep the director ticking; no dice place for him)
	await _fresh()
	_guard(Vector3(120, 0, 0), 0.0)
	gatherings = GatheringScript.of(self)
	gatherings.request(&"dice")
	gatherings.request(&"watch_change", ["Nobody", "Noone"])
	await _frames(int((GatheringScript.REQUEST_FOR + 5.0) * 60))
	var stale: int = gatherings.queued().size()
	gatherings.request(&"flask")
	gatherings.cancel(&"flask")
	_check("R17 a gathering asked for that cannot come about is given up after a while, and one can be called off",
		stale == 0 and gatherings.queued().is_empty(), "still queued %d, after calling off %s" % [stale, gatherings.queued()])


## A gathering place of `kind` at `at`: spots [offset, activity, role], each
## facing the middle.
func _place(kind: StringName, at: Vector3, spots: Array) -> Node3D:
	var place := Marker3D.new()
	place.set_meta(&"gathering", kind)
	place.add_to_group(&"gathering_places")
	add_child(place)
	place.global_position = at

	for spot in spots:
		var marker := Marker3D.new()
		marker.set_meta(&"activity", spot[1])
		marker.set_meta(&"role", spot[2])
		place.add_child(marker)
		marker.global_position = at + (spot[0] as Vector3)
		var inward: Vector3 = -(spot[0] as Vector3)
		marker.global_basis = Basis.looking_at(Vector3(inward.x, 0, inward.z).normalized(), Vector3.UP)

	return place


## A gathering of `kind` with `count` men, each settled at his spot.
func _gathered(gatherings: RefCounted, kind: StringName, count: int) -> bool:
	for g in gatherings.live():
		if g["kind"] == kind and (g["members"] as Array).size() == count:
			return (g["members"] as Array).all(func(m): return m._rota.at_station())

	return false


## A man's Head axis that points to his front when he stands at rest.
func _rest_forward_axis(guard: Node3D) -> Vector3:
	var man: Node3D = guard._rig.man
	var rest: Transform3D = man.skeleton.global_transform * man.skeleton.get_bone_global_rest(man.skeleton.find_bone(&"Head"))
	var front := -guard.global_basis.z
	var best := Vector3.ZERO
	var best_dot := -INF

	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var dot: float = (rest.basis * axis).normalized().dot(front)

		if dot > best_dot:
			best_dot = dot
			best = axis

	return best


## `bones` of a guard's man in the world as posed this frame.
func _posed_global(guard: Node3D, bones: Array) -> Dictionary:
	var man: Node3D = guard._rig.man
	var got := {}
	man.skeleton.skeleton_updated.connect(func():
		for bone in bones:
			got[bone] = man.bone_global(bone), CONNECT_ONE_SHOT)

	while got.is_empty():
		await get_tree().process_frame

	return got


# ---------------------------------------------------------------------------
# The yard
# ---------------------------------------------------------------------------

func _yard() -> void:
	TemperamentScript.rolling = false
	Props.block(self, Vector3(60, -0.5, 0), Vector3(200, 1, 60))
	var baker := NavigationRegion3D.new()
	baker.set_script(NavBakerScript)
	add_child(baker)
	player = PLAYER.instantiate()
	add_child(player)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.debug_traversal = false
	player.invulnerable = true
	player.reload_on_death = false

	if player.has_node("LightGem"):
		player.get_node("LightGem").queue_free()

	player.debug_light_level = 0.0
	player.global_position = Vector3(60, 1.05, 28)
	await baker.baked
	await _frames(5)


func _guard(at: Vector3, yaw := 0.0, preset: StringName = &"steady", name := "", stations := [], archetype: StringName = &"") -> CharacterBody3D:
	var g: CharacterBody3D = GUARD.instantiate()
	g.archetype = archetype
	g.temperament = preset
	g.debug_ai = false
	g.given_name = name

	if not stations.is_empty():
		var paths: Array[NodePath] = []

		for station in stations:
			paths.append((station as Node).get_path())

		g.stations = paths

	g.position = at
	g.rotation.y = yaw
	add_child(g)
	g._attack_timer = 999.0
	g.attack_cooldown = 999.0
	g._life._talk_rest = 99.0
	return g


func _station(kind: StringName, at: Vector3, yaw: float) -> Node3D:
	var station: Node3D = GuardStationScript.new()
	station.kind = kind
	add_child(station)
	station.global_position = at
	station.rotation.y = yaw
	return station


func _fresh() -> void:
	for g in get_tree().get_nodes_in_group(&"guards"):
		g.remove_from_group(&"guards")
		g.set_physics_process(false)
		g.queue_free()

	for group in [&"bodies", &"dropped_weapons", &"dropped_lights", &"stray_arrows", &"guard_stations", &"gathering_places", &"woodpiles"]:
		for thing in get_tree().get_nodes_in_group(group):
			thing.queue_free()

	SquadScript.clear_all()
	GarrisonScript.clear_all()
	player.global_position = Vector3(60, 1.05, 28)
	await _frames(5)
	LightProbe.invalidate()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return

		await get_tree().physics_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
