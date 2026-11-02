extends Node
## What you take on a hunt: round types and prep items, chosen at a kit table
## and locked once you leave a safe place (SafePlace.gd). `owned` is what you
## have put by; restock() fills your pouches from it. The gun's own pouches are
## the inventory's. Runs as the player's "Loadout" child. Off a hunt it stays
## lead only and unlocked and touches nothing.

const PrepItems := preload("res://scripts/Hunt/PrepItems.gd")
const Rounds := preload("res://scripts/Combat/Rounds.gd")
const SaveFields := preload("res://scripts/Save/SaveFields.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")

## An item was spent; the pack or a count changed.
signal item_used(id: StringName)
signal changed
## The key was pressed and there was nothing to do.
signal refused_use

## Round types beside the shells, which always come; kinds of item.
const MAX_ROUND_TYPES := 2
const MAX_ITEM_KINDS := 2
## What a pouch holds, carried.
const CARRY := {&"rounds": 24, &"copal_rounds": 12, &"shells": 6}
## This many watching you and the HUD offers what would answer them, uncursed.
const OFFER_WATCHED_BY := 2
const SAVED := ["rounds", "items", "item_counts", "locked", "owned"]

var rounds: Array[StringName] = [&"lead"]
var items: Array[StringName] = []
var item_counts := {}
var locked := false
var owned := {&"rounds": 96, &"copal_rounds": 24, &"shells": 18, &"egg": 6}

var player: CharacterBody3D
var _using: StringName = &""
var _using_left := 0.0


func _ready() -> void:
	player = get_parent() as CharacterBody3D

	if not InputMap.has_action(&"use_item"):
		InputMap.add_action(&"use_item")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_V
		InputMap.action_add_event(&"use_item", key)


func pack_round(id: StringName) -> bool:
	if locked or rounds.has(id) or rounds.size() >= MAX_ROUND_TYPES or Rounds.info(id).is_empty():
		return false

	rounds.append(id)
	changed.emit()
	return true


## False for the last one: you always carry something for the cylinder.
func unpack_round(id: StringName) -> bool:
	if locked or not rounds.has(id) or rounds.size() <= 1:
		return false

	rounds.erase(id)
	changed.emit()
	return true


func pack_item(id: StringName) -> bool:
	if locked or items.has(id) or items.size() >= MAX_ITEM_KINDS or PrepItems.info(id).is_empty():
		return false

	items.append(id)
	changed.emit()
	return true


func unpack_item(id: StringName) -> bool:
	if locked or not items.has(id):
		return false

	items.erase(id)
	changed.emit()
	return true


## Pouches and items filled up to what you carry, out of what you own; what
## you have left off goes back. The cylinder comes round to what is packed
## and is loaded.
func restock() -> void:
	var inv: Node = player.inventory
	var stocks: Array[StringName] = [&"shells"]

	for id in rounds:
		stocks.append(Rounds.info(id)["stock"])

	for stock in CARRY:
		if not stocks.has(stock) and int(inv.ammo.get(stock, 0)) > 0:
			owned[stock] = int(owned.get(stock, 0)) + int(inv.ammo[stock])
			inv.ammo[stock] = 0

	for id in item_counts.keys():
		if not items.has(id):
			owned[id] = int(owned.get(id, 0)) + int(item_counts[id])
			item_counts.erase(id)

	_top_up(stocks)
	player.revolver.take_up(rounds)
	_top_up(stocks)

	for id in items:
		var have := int(item_counts.get(id, 0))
		var taken := mini(maxi(int(PrepItems.info(id)["carry"]) - have, 0), int(owned.get(id, 0)))
		item_counts[id] = have + taken
		owned[id] = int(owned.get(id, 0)) - taken

	inv.changed.emit()
	changed.emit()


func _top_up(stocks: Array[StringName]) -> void:
	var inv: Node = player.inventory

	for stock in stocks:
		var have := int(inv.ammo.get(stock, 0))
		var taken := mini(maxi(int(CARRY.get(stock, 0)) - have, 0), int(owned.get(stock, 0)))
		inv.ammo[stock] = have + taken
		owned[stock] = int(owned.get(stock, 0)) - taken


func lock() -> void:
	locked = true


func unlock() -> void:
	locked = false


## Takes up the packed item at `index`, if there is one left and it would do
## something: you have what it cures on you, or something is watching you to send
## it back at (so one is never wasted). The hand is busy for its time, then it is
## spent and done. False if not.
func use_item(index := 0) -> bool:
	if is_using() or index >= items.size() or player.is_dead or not player.combat.is_able():
		return false

	var id := items[index]
	var info := PrepItems.info(id)

	if int(item_counts.get(id, 0)) <= 0 or not (player.statuses.has(info.get("cures", &"")) or _watching_you(id) > 0):
		return false

	_using = id
	_using_left = float(info["use_time"])
	Sfx.play_flat(self, &"cloth", -6.0, 1.2)
	return true


## There is something packed that would help you now (the HUD offers it).
func can_offer() -> bool:
	if is_using() or items.is_empty() or int(item_counts.get(items[0], 0)) <= 0:
		return false

	if player.statuses.has(PrepItems.info(items[0]).get("cures", &"")):
		return true

	# Not while what it leaves still lies on you: no nagging.
	return not player.statuses.has(PrepItems.info(items[0]).get("leaves", &"")) and _watching_you(items[0]) >= OFFER_WATCHED_BY


## How many monsters this item would be sent back at, here and now.
func _watching_you(id: StringName) -> int:
	return _sent_back_at(id).size()


func _sent_back_at(id: StringName) -> Array:
	var reach := float(PrepItems.info(id).get("returns", 0.0))

	if reach <= 0.0:
		return []

	return get_tree().get_nodes_in_group(&"monsters").filter(func(monster):
		return monster.has_method("limpia") and not monster.dead and not monster.asleep and monster.global_position.distance_to(player.global_position) <= reach and monster.sees(player))


## The item being taken up, or &"".
func using() -> StringName:
	return _using


func is_using() -> bool:
	return _using != &""


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("use_item") and not use_item():
		Sfx.play_flat(self, &"gear", -12.0, 1.8)
		refused_use.emit()

	if not is_using():
		return

	_using_left -= delta

	if _using_left > 0.0:
		return

	var id := _using
	_using = &""
	item_counts[id] = int(item_counts[id]) - 1
	var info := PrepItems.info(id)
	player.statuses.clear(info["cures"])

	if info.has("leaves"):
		player.statuses.apply(info["leaves"], float(info["leaves_for"]))

	for monster in _sent_back_at(id):
		monster.limpia(player)

	Sfx.play_flat(self, &"ting", -6.0, 0.8)
	Fx.flash(player, player.global_position, Color(1.0, 0.86, 0.6), 2.5, 7.0, 0.14)
	item_used.emit(id)
	var hud: Node = player.get("hud")

	if hud != null and hud.has_method("egg_broke"):
		hud.egg_broke()

	changed.emit()


func save_state() -> Dictionary:
	return SaveFields.save(self, SAVED)


func load_state(state: Dictionary) -> void:
	SaveFields.restore(self, state, SAVED)
	_using = &""
	player.revolver.packed_rounds = rounds.duplicate()
	changed.emit()
