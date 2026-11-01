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
	await _frames(25)
	_check("L8 the egg clears the evil eye after 0.8 s and spends one", not p.statuses.has(&"evil_eye") and lo.item_counts[&"egg"] == 1 and not lo.is_using())
	lo.item_counts[&"egg"] = 0
	p.statuses.apply(&"evil_eye", 30.0)
	Input.action_press("use_item")
	await _frames(2)
	Input.action_release("use_item")
	_check("L10 no eggs: V does nothing", not lo.is_using())
	p.statuses.clear(&"evil_eye")

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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

	if not ok:
		failed += 1
