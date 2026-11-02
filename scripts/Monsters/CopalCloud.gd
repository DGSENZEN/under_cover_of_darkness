extends Node3D
## Where a copal round bursts on a monster, its resin hangs for a few seconds: a
## bank of the curanderas' smoke that blinds whatever is in it (Statuses:
## smoked). So one round answers a bunch of them.

const PuffShader := preload("res://scripts/Monsters/copal_puff.gdshader")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

const LASTS := 4.0
const REACH := 3.5
## Smoked for this long after each tick in it, so it wears off just past the edge.
const CLINGS := 0.6
const PUFFS := 7
## Seconds to swell, and to thin away.
const SWELL := 0.35
const THIN := 0.8

var _left := LASTS
var _puffs: Array[MeshInstance3D] = []
var _sizes: Array[float] = []


static func burst(context: Node, at: Vector3) -> Node3D:
	var cloud: Node3D = (load("res://scripts/Monsters/CopalCloud.gd") as GDScript).new()
	context.add_child(cloud)
	cloud.global_position = at
	return cloud


func _ready() -> void:
	add_to_group(&"copal_clouds")
	Sfx.play(self, &"whoosh_light", global_position, -6.0, 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)

	for i in PUFFS:
		var puff := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 16
		ball.rings = 8
		var look := ShaderMaterial.new()
		look.shader = PuffShader
		look.set_shader_parameter(&"seed", rng.randf() * 10.0)
		ball.material = look
		puff.mesh = ball
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.position = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.7), rng.randf_range(-1.0, 1.0)) * REACH * 0.5
		puff.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU
		add_child(puff)
		_puffs.append(puff)
		_sizes.append(rng.randf_range(0.8, 1.3) * REACH * 0.38)

	_show()


func _physics_process(delta: float) -> void:
	_left -= delta

	if _left <= 0.0:
		queue_free()
		return

	_show()

	for monster in get_tree().get_nodes_in_group(&"monsters"):
		if not monster.dead and not monster.asleep and monster.global_position.distance_to(global_position) <= REACH:
			monster.statuses.apply(&"smoked", CLINGS)


func _show() -> void:
	var grown := minf((LASTS - _left) / SWELL, 1.0)
	var left := minf(_left / THIN, 1.0)

	for i in _puffs.size():
		var drift := 1.0 + (LASTS - _left) * 0.06
		_puffs[i].scale = Vector3.ONE * maxf(_sizes[i] * ease(grown, 0.4) * drift, 0.001)
		(_puffs[i].mesh.material as ShaderMaterial).set_shader_parameter(&"fade", left)
