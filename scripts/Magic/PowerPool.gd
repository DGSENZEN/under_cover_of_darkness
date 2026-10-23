extends Node
## The one pool every spell draws on: it refills slowly once a moment has
## passed since the last cast. Runs as the player's "Power" child.

const Sfx := preload("res://scripts/Audio/Sfx.gd")

## A spell asked for what the pool does not have (the HUD's arc flashes).
signal refused_cast

const MAX := 100.0
## Per second, once REFILL_DELAY seconds have passed since the last spend.
const REFILL := 5.0
const REFILL_DELAY := 2.0

var power := MAX

var _since_spent := REFILL_DELAY


func _physics_process(delta: float) -> void:
	_since_spent += delta

	if _since_spent > REFILL_DELAY:
		# Only the part of this tick past the delay counts.
		var refilling := minf(delta, _since_spent - REFILL_DELAY)
		power = minf(power + REFILL * refilling, MAX)


func can_pay(cost: float) -> bool:
	return power >= cost


## Spends cost if the pool has it (and the refill waits again); false, and
## nothing spent, if not.
func pay(cost: float) -> bool:
	if not can_pay(cost):
		return false

	power = clampf(power - cost, 0.0, MAX)
	_since_spent = 0.0
	return true


## A spell that could not be paid for: a dry click, and the arc flashes.
func refused() -> void:
	Sfx.play_flat(self, &"gear", -10.0, 1.9)
	refused_cast.emit()
