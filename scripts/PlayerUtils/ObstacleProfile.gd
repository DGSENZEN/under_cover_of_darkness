extends RefCounted
## Traversal measurements; positions are world-space, height is feet-relative.
## Unmeasured thickness and absent far-floor drop use INF.

enum Headroom {
	STANDING,
	CROUCHED,
	BLOCKED,
}

## Point on the vertical face that was hit.
var face_point := Vector3.ZERO

## Horizontal unit normal of that face. Points out of the wall, toward the player.
var face_normal := Vector3.ZERO

## Point on the top surface, just behind the face.
var top_point := Vector3.ZERO
var top_normal := Vector3.UP

## World height of the player's feet when the scan ran.
var feet_y := 0.0

## top_point.y - feet_y
var height := 0.0

## Front-to-back depth of the obstacle. INF when the top never ends.
var thickness := INF

## Where the top surface stops, at top height. Only valid when thickness is finite.
var far_edge := Vector3.ZERO

var has_far_floor := false
var far_floor := Vector3.ZERO

## Surface point where a mantle would place the feet.
var landing := Vector3.ZERO
## Stairs rise behind the top (a step up within reach of it): the landing is
## on them, lifted onto the next tread as a body stands on a staircase.
var on_stairs := false
var headroom := Headroom.BLOCKED

## Horizontal speed toward the face, never negative.
var approach_speed := 0.0

## facing . -face_normal. 1.0 means looking straight at the face.
var facing_dot := 0.0

var airborne := false
var collider: Object = null


## Returns feet_y minus far_floor.y, or INF when no far floor was measured.
func far_drop() -> float:
	if not has_far_floor:
		return INF

	return feet_y - far_floor.y
