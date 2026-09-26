extends SkeletonModifier3D
## Starts his cloth (Cloth.gd) afresh when he is put somewhere far in one
## step (a teleport), at the one moment that works: in his skeleton's own
## update, after physics has posed him and before the cloth swings. Sits
## just ahead of the cloth.

## Further than this (metres) in one frame is being put somewhere, not
## moving: getting up from a fall moves him less.
const JUMP := 2.0
## Frames a jump restarts the cloth for: the cloth can feel a jump a frame
## after his skeleton reports it (the transform reaches it late), so a
## single restart can land a frame early.
const RESTARTS := 3

## The cloth it restarts.
var cloth: Node

var _last := Vector3.INF
var _owed := 0


func _process_modification() -> void:
	var skeleton := get_skeleton()

	if cloth == null or skeleton == null:
		return

	var at := skeleton.global_position

	if _last != Vector3.INF and at.distance_to(_last) > JUMP:
		_owed = RESTARTS

	_last = at

	if _owed > 0:
		_owed -= 1
		cloth.reset()
