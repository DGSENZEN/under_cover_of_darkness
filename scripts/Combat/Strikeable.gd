extends StaticBody3D
## Something fixed that reacts to being hit without being a person: a rope,
## a chain, a lamp. Blades, arrows and blasts call strike(); whoever built it
## listens to `struck`.

signal struck(kind: StringName, point: Vector3)


func strike(kind: StringName, point: Vector3, _direction := Vector3.ZERO) -> void:
	struck.emit(kind, point)
