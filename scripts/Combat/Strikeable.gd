extends StaticBody3D
## Fixed collision target forwarding blade, arrow, and blast contacts as struck.
## Builders connect struck to the object-specific response.

signal struck(kind: StringName, point: Vector3)


## Emits struck(kind, point); point is world-space and _direction is unused.
func strike(kind: StringName, point: Vector3, _direction := Vector3.ZERO) -> void:
	struck.emit(kind, point)
