extends Node
## What a revenant's grasp has left on you: its touch, until the one that laid it is gone. One touch on you and the next grasp, any
## revenant's, is the end. While it holds you, you can't go anywhere; and just after, you have a moment before a grasp can finish it.
## Runs as the player's "Touch" child.

signal laid
signal cleared

var _by: Node3D = null
var _on := false
var _hold := 0.0
var _grace := 0.0
## A save, waiting for what laid it to be found again.
var _by_path := ""


## It has you: `hold` seconds, and `grace` after it.
func lay(by: Node3D, hold: float, grace: float) -> void:
	var fresh := not _on
	_by = by
	_on = true
	_hold = hold
	_grace = grace

	if fresh:
		laid.emit()


func on_you() -> bool:
	return _on


func laid_by() -> Node3D:
	return _by if is_instance_valid(_by) else null


func holding() -> bool:
	return _on and _hold > 0.0


func in_grace() -> bool:
	return _on and (_hold > 0.0 or _grace > 0.0)


## It lets go of you: the touch stays.
func let_go() -> void:
	_hold = 0.0


func clear() -> void:
	var was := _on
	_by = null
	_on = false
	_hold = 0.0
	_grace = 0.0
	_by_path = ""

	if was:
		cleared.emit()


## The one that laid it is finished.
func clear_if(by: Node3D) -> void:
	if _by == by:
		clear()


func _physics_process(delta: float) -> void:
	if not _on:
		return

	if _by_path != "":
		_by = get_node_or_null(_by_path) as Node3D
		_by_path = ""

	# Gone from play: nothing is left to burn, so it can't stay on you.
	if not is_instance_valid(_by) or _by.get("dead") == true or _by.get("asleep") == true:
		clear()
		return

	if _hold > 0.0:
		_hold = maxf(_hold - delta, 0.0)
	else:
		_grace = maxf(_grace - delta, 0.0)


func save_state() -> Dictionary:
	return {"on": _on, "by": String(_by.get_path()) if is_instance_valid(_by) else "", "hold": _hold, "grace": _grace}


func load_state(state: Dictionary) -> void:
	_on = bool(state.get("on", false))
	_by_path = String(state.get("by", ""))
	_by = null
	_hold = float(state.get("hold", 0.0))
	_grace = float(state.get("grace", 0.0))
