extends Node3D
## How a floating eye looks and moves: its model (assets/monsters/floating_eye.glb)
## and all that is only for show. It turns its crown to you slowly while the ball
## tracks you on its own, twitching; it blinks; its lids, pupil and blood follow
## what it is doing, which FloatingEye tells it each tick. Its own dice, so it
## doesn't disturb anyone else's.

const MODEL := "res://assets/monsters/floating_eye.glb"
const TURNED_MODEL := "res://assets/monsters/floating_eye_turned.glb"
const FleshShader := preload("res://scripts/Monsters/eye_flesh.gdshader")
const BallShader := preload("res://scripts/Monsters/eye_ball.gdshader")
const NerveShader := preload("res://scripts/Monsters/eye_nerve.gdshader")
const StoneShader := preload("res://scripts/Monsters/eye_stone.gdshader")
## The brush the look's strokes come from.
const BRUSH: Texture2D = preload("res://textures/painted/eclipse/brush.png")
const Fx := preload("res://scripts/Visual/Fx.gd")
const Remains := preload("res://scripts/Monsters/Remains.gd")

## How far the lids turn from their rest (degrees): shut, and pulled back wide.
const TOP_SHUT := 25.0
const TOP_WIDE := 14.0
const BOTTOM_SHUT := 38.0
const BOTTOM_WIDE := 10.0
## How the crown and the ball come round to you.
const CROWN_RATE := 5.0
const BALL_RATE := 26.0
const BALL_MOST := 0.62
const SACCADE_EVERY := Vector2(0.22, 1.1)
const SACCADE_ANGLE := 0.075
const BLINK_EVERY := Vector2(2.5, 6.0)
const BLINK_TIME := 0.09
const WEEP_EVERY := 0.2
const WINCE_TIME := 0.14
const HURT_FADE := 0.28
const CHUNKS := 7
## Its whole body, sprung: how far it draws back and rears in its tell, thrown forward in a swoop,
## recoils when hit; how much it shakes as it gathers, least and most; how often something starts in
## it when it isn't doing anything.
const DRAWS_BACK := 0.14
const REARS := 0.1
const THROWN_FORWARD := 0.1
const RECOILS := 3.2
const SHAKE_LEAST := 0.005
const SHAKE_MOST := 0.03
const GATHERS := 0.5
const TWITCH_EVERY := Vector2(1.2, 3.2)
const TWITCH_KICK := 1.1
const BOB := 0.03
## How much a crack adds to its shown wounds, and for how long.
const CRACK_SHOWS := 0.3
const CRACK_LASTS := 1.5
static var _BLACK: Texture2D = _flat(Color(0.012, 0.009, 0.01))


static func _flat(colour: Color) -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.fill(colour)
	return ImageTexture.create_from_image(image)


const SWAY_PER_SPEED := 0.05
const SWAY_MOST := 0.7

@export var seed_value := 1
## What it shows now: lids -1 wide, 0 at rest, 1 shut; the pupil's size; blood up;
## a hit's flush; how hurt it is; the nerve's lean; tears wept.
var lids := 0.0
var pupil := 1.0
var rage := 0.0
var hurt := 0.0
var wounds := 0.0
var _crack_left := 0.0
var _doing: StringName = &""
var _doing_for := 0.0
var _back := 0.0
var _back_speed := 0.0
var _up := 0.0
var _up_speed := 0.0
var _twitch_in := 1.0
## How hard it is shaking now, and how many starts it has had.
var shake_now := 0.0
var twitches := 0
var sway := Vector3.ZERO
var tears := 0

var _rng := RandomNumberGenerator.new()
var _parts := {}
## Which model it wears.
var model := MODEL
## Resin burning on it while it is smoked, 0..1, and how fast that takes and dies.
var smoulder := 0.0
const SMOULDER_TAKES := 6.0
const SMOULDER_DIES := 3.0
var _living: Array[GeometryInstance3D] = []
var _nerves: Array[GeometryInstance3D] = []
var _saccade := Vector3.ZERO
var _saccade_in := 0.0
var _blink_in := 0.0
var _blink_left := 0.0
var _wince_left := 0.0
var _weep_in := 0.0
var _clock := 0.0
var _rest_scale := Vector3.ONE

static var _flesh_look: ShaderMaterial
static var _nerve_look: ShaderMaterial
static var _ball_look: ShaderMaterial
static var _stone_looks := {}


func _ready() -> void:
	_rng.seed = seed_value + 9000
	_saccade_in = _rng.randf_range(SACCADE_EVERY.x, SACCADE_EVERY.y)
	_blink_in = _rng.randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
	_clock = _rng.randf() * 10.0
	var made: Node = (load(model) as PackedScene).instantiate()

	for mesh in made.find_children("*", "MeshInstance3D", true, false):
		_parts[StringName(mesh.name)] = mesh

	# Over to this node, flat, keeping where each is (a child stays with its parent).
	for child in made.get_children():
		made.remove_child(child)
		child.owner = null
		add_child(child)

	made.free()
	_dress()


func part(id: StringName) -> MeshInstance3D:
	return _parts.get(id)


func _dress() -> void:
	if _flesh_look == null:
		_flesh_look = _painted_look(FleshShader, 1.0)
		_nerve_look = _painted_look(NerveShader, 0.9)
		_ball_look = _painted_look(BallShader, 0.7)
		_ball_look.set_shader_parameter(&"wet_tight", 90.0)
		var painted: Material = part(&"Ball").mesh.surface_get_material(0)
		_ball_look.set_shader_parameter(&"paint", (painted as BaseMaterial3D).albedo_texture)

	for id in [&"Frame", &"Tier", &"Rim", &"Spines", &"LidSpines", &"Socket"]:
		part(id).set_surface_override_material(0, _stone_look(part(id)))

	var black := _painted_look(StoneShader, 0.9)
	black.set_shader_parameter(&"wet_tight", 120.0)
	black.set_shader_parameter(&"paint", _BLACK)
	part(&"Pupil").set_surface_override_material(0, black)

	for id in [&"Pupil_2", &"Pupil_3"]:
		if part(id) != null:
			part(id).set_surface_override_material(0, black)

	for id in [&"Flesh", &"LidTop", &"LidBottom", &"Meat"]:
		if part(id) != null:
			part(id).set_surface_override_material(0, _flesh_look)
			_living.append(part(id))

	part(&"Ball").set_surface_override_material(0, _ball_look)
	_living.append(part(&"Ball"))

	for id in [&"Nerve", &"Shreds"]:
		part(id).set_surface_override_material(0, _nerve_look)
		_living.append(part(id))
		_nerves.append(part(id))


static func _painted_look(shader: Shader, wet: float) -> ShaderMaterial:
	var look := ShaderMaterial.new()
	look.shader = shader
	look.set_shader_parameter(&"stroke_sheet", BRUSH)
	look.set_shader_parameter(&"wet", wet)
	return look


## One look to each painted sheet.
static func _stone_look(mesh: MeshInstance3D) -> ShaderMaterial:
	var painted := mesh.mesh.surface_get_material(0) as BaseMaterial3D
	var sheet: Texture2D = painted.albedo_texture if painted != null else null

	if not _stone_looks.has(sheet):
		var look := _painted_look(StoneShader, 0.0)

		if sheet != null:
			look.set_shader_parameter(&"paint", sheet)

		_stone_looks[sheet] = look

	return _stone_looks[sheet]


## Each tick, from the eye: what it is doing (lower-case state), who it looks at,
## how it is moving.
func tick(delta: float, doing: StringName, you: Node3D, moving: Vector3, exposed: bool, smoked: bool, whole: float) -> void:
	_clock += delta
	_crack_left = maxf(_crack_left - delta, 0.0)
	wounds = clampf(1.0 - whole + (CRACK_SHOWS if _crack_left > 0.0 else 0.0), 0.0, 1.0)
	hurt = move_toward(hurt, 0.0, delta / HURT_FADE)
	smoulder = move_toward(smoulder, 1.0 if smoked else 0.0, delta * (SMOULDER_TAKES if smoked else SMOULDER_DIES))
	_wince_left = maxf(_wince_left - delta, 0.0)
	var wants := _wanted(doing, exposed, smoked)
	var ease_rate := 70.0 if _blink_left > 0.0 else (26.0 if wants["lids"] > lids and doing != &"circle" else 12.0)
	lids = lerpf(lids, _blinking(delta, doing, wants["lids"]), 1.0 - exp(-ease_rate * delta))
	pupil = lerpf(pupil, wants["pupil"] + sin(_clock * 3.3) * 0.05, 1.0 - exp(-14.0 * delta))
	rage = lerpf(rage, maxf(wants["rage"], wounds * 0.35), 1.0 - exp(-8.0 * delta))
	var leaning := (-moving * SWAY_PER_SPEED).limit_length(SWAY_MOST)
	sway = sway.lerp(global_basis.inverse() * leaning, 1.0 - exp(-7.0 * delta))
	_turn_crown(delta, doing, you, moving)
	_turn_ball(delta, doing, you)
	_show_lids()
	part(&"Pupil").scale = Vector3(pupil, pupil, 1.0)
	_pose(doing, delta)
	_shader_state()
	_weep(delta, doing, smoked)


## What each thing it does asks of its face.
func _wanted(doing: StringName, exposed: bool, smoked: bool) -> Dictionary:
	var lid := 0.0
	var size := 1.0
	var blood := 0.14

	match doing:
		&"tell":
			lid = -1.0
			size = 2.0
			blood = 1.0
		&"swoop":
			lid = 0.55
			size = 0.6
			blood = 0.8
		&"batted", &"bounce":
			lid = 0.4
			size = 1.25
			blood = 0.4
		&"dazed":
			lid = 1.0
			size = 1.5
			blood = 0.5
		&"drift":
			lid = 0.2

	if exposed and doing != &"dazed":
		lid = maxf(lid, 0.5)
		size = 1.6

	if smoked:
		lid = maxf(lid, 0.6)
		size = 0.8

	if _wince_left > 0.0:
		lid = maxf(lid, 0.85)

	return {"lids": lid, "pupil": size, "rage": blood}


func _blinking(delta: float, doing: StringName, wanted_lids: float) -> float:
	if _blink_left > 0.0:
		_blink_left -= delta
		return 1.0

	if doing == &"tell" or doing == &"swoop" or doing == &"dazed":
		return wanted_lids

	_blink_in -= delta

	if _blink_in <= 0.0:
		_blink_in = _rng.randf_range(BLINK_EVERY.x, BLINK_EVERY.y)
		_blink_left = BLINK_TIME

	return wanted_lids


func _turn_crown(delta: float, doing: StringName, you: Node3D, moving: Vector3) -> void:
	var way := moving if doing == &"swoop" and moving.length() > 1.0 else (_aim_at(you) - global_position)

	if way.length() < 0.05:
		return

	var wanted := Basis.looking_at(way.normalized(), Vector3.UP)

	# Shut, it hangs, its crown tipped forward and over.
	if doing == &"dazed":
		wanted = wanted * Basis(Vector3.RIGHT, -0.55) * Basis(Vector3.BACK, 0.3)
	else:
		wanted = wanted * Basis(Vector3.BACK, sin(_clock * 0.9) * 0.09)

	# (Its stretch is put back in _pose: a turn is only a turn.)
	var keep := scale
	transform.basis = get_parent().global_basis.orthonormalized().inverse() * global_basis.orthonormalized().slerp(wanted, 1.0 - exp(-CROWN_RATE * delta))
	scale = keep


func _turn_ball(delta: float, doing: StringName, you: Node3D) -> void:
	_saccade_in -= delta

	if _saccade_in <= 0.0:
		_saccade_in = _rng.randf_range(SACCADE_EVERY.x, SACCADE_EVERY.y)
		var jump := SACCADE_ANGLE * (2.5 if doing == &"dazed" else 1.0)
		_saccade = Vector3(_rng.randf_range(-jump, jump), _rng.randf_range(-jump, jump), 0.0)

	var ball := part(&"Ball")
	var at := _aim_at(you)
	var local := (global_basis.inverse() * (at - ball.global_position)).normalized()
	# Up under the lid, rolled back, while it is shut.
	local = Vector3(0.0, 0.7, -0.7) if doing == &"dazed" else (local + _saccade).normalized()
	# It can only look so far out of its almond.
	local = Vector3(0.0, 0.0, -1.0).slerp(local, minf(1.0, BALL_MOST / maxf(local.angle_to(Vector3(0.0, 0.0, -1.0)), 0.001)))
	var wanted := Basis.looking_at(local, Vector3.UP)
	var now := ball.transform.basis.slerp(wanted, 1.0 - exp(-BALL_RATE * delta)).orthonormalized()
	ball.transform.basis = now
	part(&"Pupil").transform.basis = now.scaled(Vector3(pupil, pupil, 1.0))


func _aim_at(you: Node3D) -> Vector3:
	return you.get("camera").global_position if you.get("camera") != null else you.global_position


func _show_lids() -> void:
	var top := -TOP_SHUT * lids if lids >= 0.0 else -TOP_WIDE * lids
	var bottom := BOTTOM_SHUT * lids if lids >= 0.0 else BOTTOM_WIDE * lids
	part(&"LidTop").rotation.x = deg_to_rad(top)
	part(&"LidBottom").rotation.x = deg_to_rad(bottom)


func _pose(doing: StringName, delta: float) -> void:
	if doing != _doing:
		_doing = doing
		_doing_for = 0.0

	_doing_for += delta
	var stretched := 1.0

	if doing == &"swoop":
		stretched = 1.16

	scale = scale.lerp(Vector3(1.0 / sqrt(stretched), 1.0 / sqrt(stretched), stretched), 0.2)
	var back_to := 0.0
	var up_to := 0.0

	match doing:
		&"tell":
			back_to = DRAWS_BACK
			up_to = REARS
		&"swoop":
			back_to = -THROWN_FORWARD
		&"dazed":
			up_to = -REARS
		&"drift", &"circle":
			_twitch_in -= delta

			if _twitch_in <= 0.0:
				_twitch_in = _rng.randf_range(TWITCH_EVERY.x, TWITCH_EVERY.y)
				twitches += 1
				_back_speed += TWITCH_KICK * (-1.0 if _rng.randf() < 0.5 else 1.0)
				_up_speed += TWITCH_KICK * (-1.0 if _rng.randf() < 0.5 else 1.0)

	var w := minf(TAU * (9.0 if doing == &"tell" or doing == &"swoop" else 4.0), 0.8 / delta)
	_back_speed += (w * w * (back_to - _back) - 2.0 * 0.5 * w * _back_speed) * delta
	_back += _back_speed * delta
	_up_speed += (w * w * (up_to - _up) - 2.0 * 0.5 * w * _up_speed) * delta
	_up += _up_speed * delta
	# It shudders as it gathers, harder the nearer it is to going.
	shake_now = lerpf(SHAKE_LEAST, SHAKE_MOST, minf(_doing_for / GATHERS, 1.0)) if doing == &"tell" else (0.006 if _wince_left > 0.0 else 0.0)
	var bob := sin(_clock * 1.7) * BOB * (0.0 if doing == &"swoop" else 1.0)
	position = Vector3(sin(_clock * 61.0) * shake_now, cos(_clock * 53.0) * shake_now + _up + bob, _back)


## How far back it is drawn (m), - thrown forward.
func lean_back() -> float:
	return _back


func _shader_state() -> void:
	for mesh in _living:
		mesh.set_instance_shader_parameter(&"rage", rage)
		mesh.set_instance_shader_parameter(&"hurt", hurt)
		mesh.set_instance_shader_parameter(&"wounds", wounds)
		mesh.set_instance_shader_parameter(&"smoulder", smoulder)

	for mesh in _nerves:
		mesh.set_instance_shader_parameter(&"sway", sway)


func _weep(delta: float, doing: StringName, smoked: bool) -> void:
	if doing != &"dazed" and not smoked and wounds < 0.5:
		return

	_weep_in -= delta

	if _weep_in <= 0.0:
		_weep_in = WEEP_EVERY if doing == &"dazed" else WEEP_EVERY * 3.0
		tears += 1
		var lip: Vector3 = part(&"Ball").global_position - global_basis.z * 0.26 - global_basis.y * 0.2
		Fx.drip(self, lip, 0.1)


## A hit: it winces and flushes, and bleeds where it was struck.
## Glass through it: the ball cracks, for a while more than its wounds say.
func crack(point: Vector3, direction: Vector3) -> void:
	_crack_left = CRACK_LASTS
	Fx.blood(self, point, -direction.normalized(), 1.6)


func cracked() -> bool:
	return _crack_left > 0.0


func struck(point: Vector3, direction: Vector3, result: StringName) -> void:
	_wince_left = WINCE_TIME
	_back_speed += RECOILS
	var strength := 0.3 if result == &"resisted" else (1.3 if result == &"weak" else 0.8)
	hurt = maxf(hurt, 0.55 + strength * 0.35)
	Fx.blood(self, point, -direction.normalized(), strength)


## Dead: the ball bursts and is gone, chunks fly, and the crown and its meat drop
## as remains.
func burst(context: Node, at: Vector3, push: Vector3) -> void:
	part(&"Ball").visible = false
	part(&"Pupil").visible = false
	hurt = 1.0
	rage = 0.0
	lids = 0.35
	_show_lids()
	_shader_state()
	Fx.blood(context, part(&"Ball").global_position, global_basis * Vector3.FORWARD, 3.0)

	for i in CHUNKS:
		var way := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.2, 1.2), _rng.randf_range(-1.0, 1.0)).normalized()
		Remains.chunk(context, at + way * 0.2, way * _rng.randf_range(2.5, 6.5) + push * 0.5, i % 3 == 2, _flesh_look)

	Remains.drop(context, self, at, push, 0.36)
