extends Node3D
## The loadout: what you pack at the kit table, what restocking does, and the
## prep items. The real player.

const PLAYER := preload("res://Player.tscn")
const Props := preload("res://scripts/Interaction/Props.gd")
const KitTable := preload("res://scripts/Hunt/KitTable.gd")

var p: CharacterBody3D
var failed := 0


func _ready() -> void:
	Props.block(self, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	p.reload_on_death = false
	p.position = Vector3(0, 1.05, 0)
	Props.give_revolver(p, 24, 4)
	p.inventory.select_by_id(&"revolver")
	await _frames(60)
	var lo: Node = p.loadout
	var inv: Node = p.inventory
	var g: Node = p.revolver

	# Fire takes the place copal does; it goes in the shot barrel, never the cylinder.
	lo.pack_round(&"copal")
	_check("F7 fire takes copal's place: packing both is refused", not lo.pack_round(&"fire"))
	lo.unpack_round(&"copal")
	_check("F7b fire packs in its place", lo.pack_round(&"fire"))
	var plain_had: int = int(inv.ammo.get(&"shells", 0))
	lo.restock()
	_check("F7c it carries 4 at most (%d)" % int(inv.ammo.get(&"fire_shells", 0)), int(inv.ammo.get(&"fire_shells", 0)) <= 4 and g.shot_round == &"fire")
	_check("F7d T never puts fire in the cylinder", not g.packed_rounds.has(&"fire") and not g.switch_round() and g.cylinder_round == &"lead")
	inv.ammo[&"fire_shells"] = 0
	g.loaded[&"shot"] = 0
	lo.restock()
	lo.unpack_round(&"fire")
	lo.restock()
	_check("F7e with fire left off, the barrel holds a plain shell, and the pouch goes back (%s)" % g.shot_round, g.shot_round == &"shell" and int(inv.ammo.get(&"fire_shells", 0)) == 0 and plain_had >= 0)
	_check("L13 the default is lead, unlocked, and no pouch changes unless restocked",
		lo.rounds == [&"lead"] and not lo.locked and inv.ammo[&"rounds"] == 24 and g.packed_rounds == [&"lead"])

	var table: Node3D = KitTable.build(self, Transform3D(Basis.IDENTITY, Vector3(5, 0, 0)))
	await _frames(2)
	var copal: Node = table.piece(&"copal")
	var at: Vector3 = copal.position
	copal.frob(p)
	_check("L1 frobbing a piece packs it and moves it", lo.rounds.has(&"copal") and copal.position != at)
	_check("L2 a third round type is refused", not lo.pack_round(&"third"))
	_check("L3 the last round type can't be unpacked", lo.unpack_round(&"copal") and not lo.unpack_round(&"lead"))
	lo.pack_round(&"copal")
	table.piece(&"egg").frob(p)
	_check("L1b the egg goes in too", lo.items == [&"egg"])

	lo.lock()
	_check("L4 locked: nothing packs", not lo.unpack_item(&"egg") and not lo.pack_round(&"lead") and lo.items == [&"egg"])
	copal.frob(p)
	_check("L4b locked: a piece won't move", lo.rounds.has(&"copal"))
	lo.unlock()

	lo.restock()
	_check("L5 restock fills pouches from what you own, and spends it", inv.ammo[&"copal_rounds"] == 12 and lo.owned[&"copal_rounds"] == 12)
	_check("L5b it fills the carried eggs and shells", lo.item_counts[&"egg"] == 2 and lo.owned[&"egg"] == 4 and inv.ammo[&"shells"] == 6)
	_check("L11 packed_rounds follows the pack", g.packed_rounds == [&"lead", &"copal"])
	lo.restock()
	_check("L6 restock tops up, never over carry", inv.ammo[&"rounds"] == 24 and inv.ammo[&"copal_rounds"] == 12)
	inv.ammo[&"copal_rounds"] = 0
	lo.owned[&"copal_rounds"] = 3
	lo.restock()
	_check("L7 restock can't make what you don't own", inv.ammo[&"copal_rounds"] == 3 and lo.owned[&"copal_rounds"] == 0)

	lo.unpack_round(&"lead")
	g.cylinder_round = &"lead"
	lo.restock()
	_check("L11b a round left off comes out of the cylinder", g.cylinder_round == &"copal" and g.packed_rounds == [&"copal"])
	lo.pack_round(&"lead")
	lo.restock()
	g.cylinder_round = &"lead"
	g.loaded[&"cylinder"] = 6

	# The egg.
	lo.item_counts[&"egg"] = 2
	Input.action_press("use_item")
	await _frames(2)
	Input.action_release("use_item")
	_check("L14 with nothing on you, V doesn't waste one", not lo.is_using() and lo.item_counts[&"egg"] == 2)
	p.statuses.apply(&"evil_eye", 30.0)
	await _frames(40)
	Input.action_press("use_item")
	await _frames(2)
	Input.action_release("use_item")
	_check("L9 no firing or casting while using one", lo.is_using() and not g.ready_to_fire() and not p.caster.can_cast(&"shard"))
	await _frames(30)
	_check("L8a not done before its time", p.statuses.has(&"evil_eye"))
	await _frames(37)
	_check("L8 the egg clears the evil eye after 1 s and spends one", not p.statuses.has(&"evil_eye") and lo.item_counts[&"egg"] == 1 and not lo.is_using())
	lo.item_counts[&"egg"] = 0
	p.statuses.apply(&"evil_eye", 30.0)
	Input.action_press("use_item")
	await _frames(2)
	Input.action_release("use_item")
	_check("L10 no eggs: V does nothing", not lo.is_using())
	p.statuses.clear(&"evil_eye")

	# It always answers: the key is never just dead.
	var refusals := [0]
	lo.refused_use.connect(func(): refusals[0] += 1)
	lo.item_counts[&"egg"] = 2
	await _press("use_item")
	_check("L15 with nothing on you, V answers with a refusal", refusals[0] == 1 and not lo.is_using())
	lo.item_counts[&"egg"] = 0
	p.statuses.apply(&"evil_eye", 30.0)
	await _press("use_item")
	_check("L16 with none left, V answers with a refusal", refusals[0] == 2)
	await _frames(2)
	_check("L17a no egg, nothing offered", not lo.can_offer())
	lo.item_counts[&"egg"] = 1
	await _frames(2)
	_check("L17 the evil eye on you and an egg in hand, it is offered on the HUD", lo.can_offer() and Array(p.hud.prompt_texts()).any(func(t): return String(t).contains("Egg")))
	await _press("use_item")
	_check("L18 taking it up shows on the readout", p.hud.get("_ammo").snapshot()["using"] == &"egg")
	await _frames(68)
	_check("L18b and stops when it is done", p.hud.get("_ammo").snapshot()["using"] == &"")
	p.statuses.clear(&"evil_eye")
	await _frames(2)
	_check("L17b nothing on you, nothing offered", not Array(p.hud.prompt_texts()).any(func(t): return String(t).contains("Egg")))

	lo.item_counts[&"egg"] = 1
	lo.lock()
	var state: Dictionary = lo.save_state()
	lo.unlock()
	lo.item_counts[&"egg"] = 0
	lo.owned[&"rounds"] = 0
	lo.unpack_round(&"copal")
	lo.load_state(state)
	_check("L12 save and load keep the pack, counts, owned and lock",
		lo.rounds.has(&"copal") and lo.item_counts[&"egg"] == 1 and lo.owned[&"rounds"] > 0 and lo.locked and g.packed_rounds.has(&"copal"))

	print("==== RESULTS ====")
	get_tree().quit(1 if failed > 0 else 0)


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

	if not ok:
		failed += 1
