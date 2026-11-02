extends Node3D
## A line of copal drawn on the floor, ash and low smoke: ánimas cannot cross it, and
## go round if they can (Anima.gd asks). Across a doorway, that seals it. Laying it
## throws off whatever is on you (Loadout.gd). Eyes pay it no mind.

const PuffShader := preload("res://scripts/Monsters/copal_puff.gdshader")

const LENGTH := 5.0
const LASTS := 20.0
## How far ahead of you it is drawn.
const AHEAD := 2.0
## Thinning away for this long at the end.
const THINS := 2.0
## An ánima going round passes the end by this much.
const ROUND_MARGIN := 0.5
const ASH := Color(0.2, 0.17, 0.13)
const EMBER := Color(1.0, 0.5, 0.12)
const PUFFS := 9

var _left := LASTS
var _across := Vector3.RIGHT
var _ash_look: StandardMaterial3D
var _puffs: Array[ShaderMaterial] = []


## Drawn square to where `player` looks, ahead of them; or at `at`, if it is given.
static func lay(player: Node3D, at := Vector3.INF) -> Node3D:
	var line: Node3D = (load("res://scripts/Hunt/CopalLine.gd") as GDScript).new()
	player.get_parent().add_child(line)
	var ahead: Vector3 = -player.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var spot: Vector3 = at if at != Vector3.INF else player.global_position + ahead * AHEAD
	line._draw_at(spot, ahead)
	return line


## The first line across the way from `from` to `to`, if any.
static func crossing(tree: SceneTree, from: Vector3, to: Vector3) -> Node3D:
	for line in tree.get_nodes_in_group(&"copal_lines"):
		if line._crossed_by(from, to):
			return line

	return null


func ends() -> Array:
	return [global_position - _across * LENGTH * 0.5, global_position + _across * LENGTH * 0.5]


## Which way along it to go, to get round it: to the end nearer where you want to be.
func way_round(at: Vector3, wish: Vector3) -> Vector3:
	var along := (at - global_position).dot(_across)
	var sign_of := signf(along) if absf(along) > 0.01 else signf(wish.dot(_across))
	return _across * (sign_of if sign_of != 0.0 else 1.0)


func _crossed_by(from: Vector3, to: Vector3) -> bool:
	var reach: float = LENGTH * 0.5 + ROUND_MARGIN
	var a := Vector2(from.x - global_position.x, from.z - global_position.z)
	var b := Vector2(to.x - global_position.x, to.z - global_position.z)
	var side := Vector2(_across.x, _across.z)
	var out := Vector2(-side.y, side.x)
	var from_out := a.dot(out)
	var to_out := b.dot(out)

	if signf(from_out) == signf(to_out) and absf(to_out) > 0.25:
		return false

	# Where it would meet the line, along it.
	var t: float = from_out / (from_out - to_out) if absf(from_out - to_out) > 0.0001 else 0.0
	return absf(a.lerp(b, clampf(t, 0.0, 1.0)).dot(side)) <= reach


func _draw_at(spot: Vector3, ahead: Vector3) -> void:
	_across = Vector3(-ahead.z, 0.0, ahead.x)
	var down := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 1.0, spot + Vector3.DOWN * 3.0, 1))
	global_position = down["position"] if not down.is_empty() else spot
	global_basis = Basis(_across, Vector3.UP, _across.cross(Vector3.UP))
	reset_physics_interpolation()
	add_to_group(&"copal_lines")
	_ash_look = StandardMaterial3D.new()
	_ash_look.albedo_color = ASH
	_ash_look.roughness = 1.0
	_ash_look.emission_enabled = true
	_ash_look.emission = EMBER
	_ash_look.emission_energy_multiplier = 0.35
	_ash_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(LENGTH, 0.012, 0.14)
	box.material = _ash_look
	strip.mesh = box
	strip.position = Vector3.UP * 0.012
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spot)

	for i in PUFFS:
		var puff := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 12
		ball.rings = 6
		var look := ShaderMaterial.new()
		look.shader = PuffShader
		look.set_shader_parameter(&"seed", rng.randf() * 10.0)
		look.set_shader_parameter(&"opacity", 0.11)
		ball.material = look
		puff.mesh = ball
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var along := (float(i) / float(PUFFS - 1) - 0.5) * LENGTH
		puff.position = Vector3(along, rng.randf_range(0.1, 0.22), rng.randf_range(-0.08, 0.08))
		puff.scale = Vector3(0.48, rng.randf_range(0.22, 0.38), 0.3)
		add_child(puff)
		_puffs.append(look)


func _physics_process(delta: float) -> void:
	_left -= delta

	if _left <= 0.0:
		queue_free()
		return

	var thin := minf(_left / THINS, 1.0)
	_ash_look.albedo_color.a = thin
	_ash_look.emission_energy_multiplier = 0.35 * thin

	for look in _puffs:
		look.set_shader_parameter(&"fade", thin)
