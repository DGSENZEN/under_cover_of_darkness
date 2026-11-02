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
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")

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
## The hand's pass, in the left of your sight: up from low, in toward the middle.
const PASS_FROM := Vector3(-0.3, -0.36, -0.52)
const PASS_THROUGH := Vector3(-0.23, -0.27, -0.5)
const PASS_TO := Vector3(-0.19, -0.26, -0.47)
## The hand through it: palm up and tipped toward you, fingers ahead and to the
## right, the egg standing in it; rolled in as it takes the curse.
const PALM_UP := Basis(Vector3(0.1, 0.849, 0.519), Vector3(0.488, 0.412, -0.77), Vector3(-0.868, 0.33, -0.373))
const PASS_ROLL := -0.3
## The ribbons reach the egg on the shader's clock (evil_eye_view.gdshader): when the
## first lands, and each next. Each lands with a jolt of the hand, down and away.
const RIBBON_LANDS_AT := 0.69
const RIBBON_LANDS_EVERY := 0.06
const JOLT := Vector3(-0.012, -0.03, 0.012)
const JOLT_FADE := 7.0
const JOLT_TRAUMA := 0.035
## How hard the burst throws the hand, of a ribbon's jolt, and how long it stays up.
const BURST_JOLT := 2.2
const SPENT_FOR := 0.28
## An item going off: the hold (real seconds), the slow beat after it, the kick.
const RELEASE_STOP := 0.04
const RELEASE_SLOW := 0.75
const RELEASE_SLOW_FOR := 0.18
const RELEASE_TRAUMA := 0.16
const SAVED := ["rounds", "items", "item_counts", "locked", "owned"]

var rounds: Array[StringName] = [&"lead"]
var items: Array[StringName] = []
var item_counts := {}
var locked := false
var owned := {&"rounds": 96, &"copal_rounds": 24, &"shells": 18, &"egg": 6}

var player: CharacterBody3D
var _using: StringName = &""
var _using_left := 0.0
## How many ribbons have reached the item in this use, and the last one's jolt, 1..0.
var _landed := 0
var _ribbons := 0
var _jolt := 0.0
var _spent_left := 0.0


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
	_landed = 0
	_jolt = 0.0
	_ribbons = int(player.curse.depth()) if player.curse != null else 0
	Sfx.play_flat(self, &"cloth", -6.0, 1.2)
	# It draws: a low rush, rising to the release.
	Sfx.play_flat(self, &"whoosh_heavy", -15.0, 0.55)
	return true


## Where the left hand is as it passes the item across your sight, in camera
## space at full size. (A stand-in pose: poses_needed.md.)
func left_frame() -> Transform3D:
	var u := 1.0 if just_spent() else smoothstep(0.0, 1.0, use_progress())
	var at := PASS_FROM.lerp(PASS_THROUGH, u).lerp(PASS_THROUGH.lerp(PASS_TO, u), u)
	return Transform3D(Basis(Vector3.BACK, PASS_ROLL * u) * PALM_UP, at + JOLT * _jolt)


## The item just burst: the hand stays up, open, a moment.
func just_spent() -> bool:
	return _spent_left > 0.0


## How many of the curse's ribbons have reached the item.
func ribbons_landed() -> int:
	return _landed


## How far through being taken up it is, 0..1; 0 if nothing is.
func use_progress() -> float:
	if not is_using():
		return 0.0

	return 1.0 - _using_left / maxf(float(PrepItems.info(_using).get("use_time", 1.0)), 0.001)


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

	_jolt = maxf(_jolt - _jolt * JOLT_FADE * delta, 0.0)
	_spent_left = maxf(_spent_left - delta, 0.0)

	if not is_using():
		return

	_using_left -= delta
	_land_ribbons()

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

	_release()
	item_used.emit(id)
	var hud: Node = player.get("hud")

	if hud != null and hud.has_method("egg_broke"):
		hud.egg_broke()

	changed.emit()


## Each ribbon reaching the item: a wet thud and a jolt, felt in the hand.
func _land_ribbons() -> void:
	if _landed >= _ribbons or use_progress() < RIBBON_LANDS_AT + RIBBON_LANDS_EVERY * float(_landed):
		return

	_landed += 1
	_jolt = 1.0
	Sfx.play_flat(self, &"flesh", -15.0, 0.85 + 0.07 * float(_landed))

	if player.juice != null:
		player.juice.add_trauma(JOLT_TRAUMA)


## What an item going off feels like: a stop, a beat of slow time, a kick, a sting.
func _release() -> void:
	_jolt = BURST_JOLT
	_spent_left = SPENT_FOR
	TimeFx.hitstop(get_tree(), RELEASE_STOP)
	TimeFx.request(get_tree(), &"dispel", RELEASE_SLOW, RELEASE_SLOW_FOR)
	Sfx.play_flat(self, &"ting", -6.0, 0.7)
	Sfx.play_flat(self, &"bone_crack", -10.0, 1.9)
	Fx.flash(player, player.global_position, Color(1.0, 0.86, 0.6), 0.5, 2.5, 0.1)

	if player.juice != null:
		player.juice.add_trauma(RELEASE_TRAUMA)
		player.juice.punch(-0.6, 0.0, 0.0)


func save_state() -> Dictionary:
	return SaveFields.save(self, SAVED)


func load_state(state: Dictionary) -> void:
	SaveFields.restore(self, state, SAVED)
	_using = &""
	player.revolver.packed_rounds = rounds.duplicate()
	changed.emit()
