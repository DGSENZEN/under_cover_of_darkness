extends Node
## The evil eye deepens. It lands as one eye in the flesh at the edge of your view;
## while anything still hunts you another opens every so often, sooner under a
## stare, up to six, and each costs you more: magic, stamina, pace, your aim. Out of
## every eye's sight it ebbs, an eye closing at a time. The egg lifts all of it at
## once, which is the reason to carry one. Runs as the player's "Curse" child; the
## time and the depth themselves are kept on Statuses.gd, and so are saved.

signal deepened(depth: int)

const ID := &"evil_eye"
const MOST := 6
## Still hunted, another eye opens after this long (s).
const DEEPEN_EVERY := 7.0
## Hunted means looked at within this long (s). Past that, it ebbs.
const LOOKED_WITHIN := 10.0
## Ebbing, an eye closes this often (s).
const EBB_EVERY := 4.0
## What it costs, by how many eyes (0 is nothing on you). The worst pace still
## sprints over the slide's least speed (PlayerController.SLIDE_MIN_SPEED).
const MAGIC_REGEN := [1.0, 0.8, 0.65, 0.5, 0.4, 0.3, 0.2]
const STAMINA_REGEN := [1.0, 0.9, 0.78, 0.65, 0.52, 0.4, 0.3]
const PACE := [1.0, 0.98, 0.95, 0.92, 0.89, 0.86, 0.83]
const STRAY := [0.0, 0.7, 1.0, 1.4, 1.8, 2.2, 2.6]
const UNSTEADY := [0.0, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0]
const Sfx := preload("res://scripts/Audio/Sfx.gd")

var statuses: Node
var _clock := 0.0


## How many eyes are open now: as many as it has deepened to, or as few as the time
## it has left allows.
func depth() -> int:
	if statuses == null or not statuses.has(ID):
		return 0

	return clampi(mini(statuses.stacks(ID), ceili(statuses.left(ID) / EBB_EVERY)), 1, MOST)


## Another eye opens.
func deepen() -> void:
	var now := depth()

	if now == 0 or now >= MOST:
		return

	statuses.set_stacks(ID, now + 1)
	statuses.apply(ID, float(now + 1) * EBB_EVERY)
	_clock = 0.0
	deepened.emit(now + 1)
	Sfx.play_flat(self, &"flesh", -9.0, 0.62)
	var juice = get_parent().get("juice")

	if juice != null:
		juice.add_trauma(0.1)


func magic_regen() -> float:
	return MAGIC_REGEN[depth()]


func stamina_regen() -> float:
	return STAMINA_REGEN[depth()]


func speed() -> float:
	return PACE[depth()]


## Degrees your shots stray by.
func stray() -> float:
	return STRAY[depth()]


func unsteady() -> float:
	return UNSTEADY[depth()]


func _physics_process(delta: float) -> void:
	if depth() == 0:
		_clock = 0.0
		return

	if statuses.looked_ago() > LOOKED_WITHIN:
		return

	# Still hunted: it holds at what it has come to, and goes on deepening.
	var now := depth()
	statuses.set_stacks(ID, now)
	statuses.apply(ID, float(now) * EBB_EVERY)
	_clock += delta

	if _clock >= DEEPEN_EVERY:
		deepen()
