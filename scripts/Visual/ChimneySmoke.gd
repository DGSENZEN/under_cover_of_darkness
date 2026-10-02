extends Node3D
## A chimney's smoke (a level's "smoke" marker): FireParticles' smoke (our
## own puffs, smoke.gdshader) breathing off its pots and carried away on the
## night's wind, while the camera is near enough to see it.
##
##   var smoke := ChimneySmokeScript.new()
##   add_child(smoke)
##   smoke.global_position = over_its_pots

const FireParticles := preload("res://scripts/Visual/Lights/FireParticles.gd")
const NightScript := preload("res://scripts/Night/Night.gd")

## Puffs a second; a puff's size (m); the embers' glow under it; drawn only
## within `reach` of the camera (m).
@export var rate := 2.5
@export var size := 0.6
@export var glow := Color(0.22, 0.15, 0.1)
@export var reach := 110.0

var _due := 0.0


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()

	if camera == null or camera.global_position.distance_to(global_position) > reach:
		_due = 0.0
		return

	_due += rate * delta

	while _due >= 1.0:
		_due -= 1.0
		var night := NightScript.of(self)
		var wind: Vector3 = night.wind() if night != null else Vector3(0.5, 0.0, 0.5)
		FireParticles.emit(self, &"smoke", global_position, 1, wind, glow, size)
