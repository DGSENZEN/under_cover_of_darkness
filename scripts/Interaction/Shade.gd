extends StaticBody3D
## Someone you can talk to, made of smoke and light (the talk and quests spec,
## section 5): a wardrobe body (Humanoid.dress) wearing the shade material
## (shade.gdshader) in its character's one colour, with wisps rising off its
## shoulders and feet. It listens in Idle and speaks in Idle_Talking, turns
## to face whoever talks to it, and shows what it feels in its light:
##   calm    resting
##   flare   rim and glow up, the smoke quickens
##   dim     it fades, thins and cools
##   gutter  a candle's flicker
## A line's cue (cue()) holds for that line, until end_line(); set_resting()
## changes what it goes back to. [shake] plays Idle_No; [nod] is a nod of the
## head alone (the library's Yes is a thumbs-up, not a nod).
## Written for any later spirit too: nothing in it is the curandera's own.

const Humanoid := preload("res://scripts/Visual/Humanoid.gd")
const DialogueBook := preload("res://scripts/Level/DialogueBook.gd")
const Layers := preload("res://scripts/Visual/Layers.gd")
const SHADER := preload("res://scripts/Visual/shade.gdshader")
const WISP_SHADER := preload("res://scripts/Visual/shade_wisp.gdshader")
const SMOKE := preload("res://assets/vfx/smoke.png")

## Each state's look: the shader's uniforms it eases toward.
const STATES := {
	&"calm": {&"glow": 1.0, &"opacity": 0.55, &"flicker": 0.0, &"smoke_speed": 0.15},
	&"flare": {&"glow": 2.2, &"opacity": 0.7, &"flicker": 0.0, &"smoke_speed": 0.35},
	&"dim": {&"glow": 0.35, &"opacity": 0.25, &"flicker": 0.0, &"smoke_speed": 0.08},
	&"gutter": {&"glow": 1.0, &"opacity": 0.55, &"flicker": 1.0, &"smoke_speed": 0.2},
}
## How fast every uniform eases toward its state's (per second, exponential).
const EASE := 4.0
## Turning to face someone, at most (rad/s).
const TURN := 3.0
## How far the head turns ahead of the body (rad): the head leads.
const HEAD_LEAD := 0.6
## From the soles up this far it frays away (m).
const FRAY_HEIGHT := 0.35
## The gestures a line's cue may play once, as clips.
const GESTURES := {&"shake": &"Idle_No"}
## A nod: two dips of the head over this long (s), the first this deep (rad).
const NOD_TIME := 1.0
const NOD_DEPTH := 0.22
## A body when its character names none.
const DEFAULT_BODY := &"duelist"
## How much of the clothes' painted light and dark shows, by part; a face
## shows none of its own and is veiled in thicker smoke.
const DETAIL := {&"Outfit": 0.55, &"Head": 0.0, &"Hair": 0.3, &"Beard": 0.3}

## The character id in the dialogue library (DialogueBook.character).
@export var character := ""
## Or, a nameless NPC of a type alone (DialogueBook.type_character).
@export var type_id := ""
@export var display_name := ""

## The resolved character (DialogueBook's record), or {} when none was found.
var dialogue := {}
var man: Humanoid

var _colour := Color(1.0, 0.62, 0.22)
var _seed := 0
## The colour pass of each worn mesh, then its depth pass (both shade.gdshader).
var _materials: Array[ShaderMaterial] = []
## The uniforms now, eased toward the state's.
var _now := {}
var _drift := 0.0
var _resting: StringName = &"calm"
## This line's cue, or &"" between lines.
var _line: StringName = &""
var _speaking := false
var _talk_time := 0.0
var _gesture: StringName = &""
var _gesture_time := 0.0
## How far into a nod (s), or below 0 when not nodding.
var _nod := -1.0
var _facing := false
var _face_point := Vector3.ZERO
var _head := 0.0
var _feet: GPUParticles3D
var _shoulders: GPUParticles3D
var _wisp_material: ShaderMaterial


func _ready() -> void:
	if character != "":
		dialogue = DialogueBook.character(character)
	elif type_id != "":
		dialogue = DialogueBook.type_character(type_id, display_name)

	if dialogue.is_empty():
		push_warning("Shade %s: no character '%s' or type '%s' in the dialogue library" % [name, character, type_id])

	_colour = dialogue.get("colour", DialogueBook.colour_of("copal"))
	_seed = absi(hash(String(dialogue.get("id", name)))) % 997
	collision_layer = Layers.WORLD
	collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	man = Humanoid.new()
	man.name = "Man"
	add_child(man)
	var body: StringName = dialogue.get("body", &"")

	if body == &"":
		body = DEFAULT_BODY

	if not man.dress(body, _seed, &"Idle"):
		man.build(&"", true, &"Idle")

	_now = STATES[&"calm"].duplicate()
	_dress_in_smoke()
	_add_wisps()
	_apply()


# What it shows

## What it goes back to between lines (a shade(...) effect, Conversation's
## `resting`).
func set_resting(state: StringName) -> void:
	if STATES.has(state):
		_resting = state


## A line's cue: a state for this line, or a gesture played once.
func cue(what: StringName) -> void:
	if STATES.has(what):
		_line = what
	elif what == &"nod":
		_nod = 0.0
	elif GESTURES.has(what):
		_gesture = GESTURES[what]
		_gesture_time = 0.0


## The line is over: its cue passes, back to resting.
func end_line() -> void:
	_line = &""


## Speaking (Idle_Talking on its arms and chest) or listening (Idle).
func speaking(on: bool) -> void:
	if on == _speaking:
		return

	_speaking = on

	if not on and man != null:
		man.clear_upper(0.4)


## Turns to face `point` (world), smoothly, the head first.
func face(point: Vector3) -> void:
	_face_point = point
	_facing = true


## Where its eyes are (world).
func head_point() -> Vector3:
	if man == null:
		return global_position + Vector3.UP * 1.6

	return man.bone_global(&"Head").origin + Vector3.UP * 0.08


## The state it shows now: this line's cue, else its resting state.
func shade_state() -> StringName:
	return _line if _line != &"" else _resting


## How bright it burns now (for tests).
func glow_now() -> float:
	return float(_now.get(&"glow", 0.0))


# Talking to it (PlayerFrob)

func get_prompt(_player: Node) -> String:
	return "Talk"


func frob(player: Node) -> void:
	if player.get("frob") != null and player.frob.has_method("talk"):
		player.frob.talk(self)


# Every frame

func _process(delta: float) -> void:
	var goal: Dictionary = STATES[shade_state()]
	var k := 1.0 - exp(-EASE * delta)

	for key in goal:
		_now[key] = lerpf(float(_now[key]), float(goal[key]), k)

	_drift += float(_now[&"smoke_speed"]) * delta
	_apply()

	if man == null:
		return

	man.set_motion(Vector3.ZERO, false, delta)
	_turn(delta)

	if _speaking:
		var length := maxf(man.action_length(&"Idle_Talking"), 0.1)
		_talk_time = fmod(_talk_time + delta, length)
		man.show_upper(&"Idle_Talking", _talk_time, 0.3, 0.85)

	# Not Humanoid.play_once: that holds the last frame for good (a fall).
	if _gesture != &"":
		_gesture_time += delta
		var end := man.action_length(_gesture) - 0.02

		if _gesture_time >= end:
			_gesture = &""
			man.clear_action(0.3)
		else:
			man.show_action(_gesture, _gesture_time, 0.2, 0.9)

	if _nod >= 0.0:
		_nod += delta
		var phase := minf(_nod / NOD_TIME, 1.0)
		# Down and up twice, the second dip shallower.
		man.pitch_head(-NOD_DEPTH * pow(sin(phase * TAU), 2.0) * (1.0 - 0.45 * phase))

		if phase >= 1.0:
			_nod = -1.0
			man.pitch_head(0.0)

	_place_shoulder_wisps()


func _turn(delta: float) -> void:
	if not _facing:
		return

	var local := to_local(_face_point)

	if Vector2(local.x, local.z).length() < 0.05:
		return

	var yaw := atan2(-local.x, -local.z)
	man.rotation.y = rotate_toward(man.rotation.y, yaw, TURN * delta)
	# The head leads the turn, then settles as the body comes round.
	var lead := clampf(angle_difference(man.rotation.y, yaw), -HEAD_LEAD, HEAD_LEAD)
	_head = lerpf(_head, lead, 1.0 - exp(-8.0 * delta))
	man.turn_head(_head)


# Building

## Every worn mesh wears the shade material. Its thin strips (a mantle, a
## fringe, a flap) go to a mesh of their own: the same smoke, seen from both
## sides but with no rim, since a strip seen edge-on would be all rim.
func _dress_in_smoke() -> void:
	for mesh in man.worn():
		var original := mesh.get_surface_override_material(0) as ShaderMaterial
		var albedo: Texture2D = original.get_shader_parameter(&"albedo") if original != null else null
		var part := String(mesh.name).get_slice("_", 0)
		var strips := _split_strips(mesh)

		if strips != mesh:
			_smoke_on(mesh, albedo, part, false)

		if strips != null:
			_smoke_on(strips, albedo, part, true)


## The shade material on one mesh: its own depth first (render priority 0,
## sorted with the rest of what is see-through), then its colour over only
## the nearest surface (priority 1, after every depth pass of hers).
func _smoke_on(mesh: MeshInstance3D, albedo: Texture2D, part: String, strips: bool) -> void:
	var colour := ShaderMaterial.new()
	colour.shader = SHADER

	if albedo != null:
		colour.set_shader_parameter(&"albedo", albedo)

	# A strip's paint (laces, studs, a tassel) would sparkle on it: kept faint.
	var detail := float(DETAIL.get(StringName(part), 0.4)) * (0.2 if strips else 1.0)
	colour.set_shader_parameter(&"detail", detail)
	# The face is veiled; a head's strips (the band over its neck seam) are
	# not a face.
	colour.set_shader_parameter(&"veil", 1.0 if part == "Head" and not strips else 0.0)
	colour.set_shader_parameter(&"strips", 1.0 if strips else 0.0)
	colour.set_shader_parameter(&"seed", float(_seed))
	colour.set_shader_parameter(&"fray_height", FRAY_HEIGHT)
	var depth := colour.duplicate() as ShaderMaterial
	depth.set_shader_parameter(&"depth_only", true)
	depth.render_priority = 0
	colour.render_priority = 1
	colour.next_pass = depth
	_materials.append(colour)
	_materials.append(depth)

	mesh.material_override = colour
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# PlayerFrob's highlight would draw its whole inside; its own light
	# shows it is looked at.
	mesh.set_meta(&"no_highlight", true)


## Takes a worn mesh's strip surfaces (Wardrobe's WR_strips: fringes, flaps,
## capes, lashes) into a mesh of their own on the same skin, leaving it its
## closed surfaces. Returns the strips' mesh, null if it has none, or the
## mesh itself if it is all strips.
func _split_strips(worn: MeshInstance3D) -> MeshInstance3D:
	var source := worn.mesh
	var closed := ArrayMesh.new()
	var thin := ArrayMesh.new()

	for surface in range(source.get_surface_count()):
		var material := source.surface_get_material(surface)
		var is_strips := material != null and String(material.resource_name).begins_with("WR_strips")
		var into := thin if is_strips else closed
		var flags: int = source.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		into.add_surface_from_arrays(source.surface_get_primitive_type(surface), source.surface_get_arrays(surface), [], {}, flags)
		into.surface_set_material(into.get_surface_count() - 1, material)

	if thin.get_surface_count() == 0:
		return null

	if closed.get_surface_count() == 0:
		return worn

	worn.mesh = closed
	var strips := MeshInstance3D.new()
	strips.name = String(worn.name) + "_strips"
	strips.mesh = thin
	strips.skin = worn.skin
	worn.get_parent().add_child(strips)
	strips.skeleton = NodePath("..")
	strips.layers = worn.layers
	return strips


## Wisps of its colour rising off its feet and shoulders: thin ribbons
## (shade_wisp.gdshader) whose soft ends are puffs of the project's own
## smoke sheet (assets/vfx/smoke.png).
func _add_wisps() -> void:
	_wisp_material = ShaderMaterial.new()
	_wisp_material.shader = WISP_SHADER
	_wisp_material.set_shader_parameter(&"puffs", SMOKE)
	# After the body's colour: in front of it they show, behind it its depth
	# hides them.
	_wisp_material.render_priority = 2
	var feet_ring := func(process: ParticleProcessMaterial) -> void:
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		process.emission_ring_axis = Vector3.UP
		process.emission_ring_radius = 0.18
		process.emission_ring_inner_radius = 0.04
		process.emission_ring_height = 0.06
	_feet = _wisps("FeetWisps", 14, 2.6, Vector2(0.24, 0.7), feet_ring)
	add_child(_feet)
	_feet.position = Vector3(0.0, 0.02, 0.0)
	var shoulder_line := func(process: ParticleProcessMaterial) -> void:
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(0.15, 0.02, 0.05)
	# Fainter and shorter than the feet's: a breath off her, not a pair of
	# flames beside her head.
	_shoulders = _wisps("ShoulderWisps", 10, 1.5, Vector2(0.14, 0.34), shoulder_line, 0.55)
	add_child(_shoulders)
	_shoulders.top_level = true
	_place_shoulder_wisps()


## One emitter; `shape` sets where it lets its wisps go, `strength` how much
## of each wisp shows. All of its process material is set before the emitter
## takes it: a change after leaks the shader it had (Godot 4.5).
func _wisps(label: String, amount: int, life: float, size: Vector2, shape: Callable, strength := 1.0) -> GPUParticles3D:
	var wisps := GPUParticles3D.new()
	wisps.name = label
	wisps.amount = amount
	wisps.lifetime = life
	wisps.randomness = 0.4
	wisps.preprocess = life
	wisps.local_coords = false
	wisps.layers = Layers.FX
	wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wisps.visibility_aabb = AABB(Vector3(-1.0, -0.5, -1.0), Vector3(2.0, 3.5, 2.0))
	wisps.set_meta(&"no_highlight", true)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.18
	process.gravity = Vector3(0.0, 0.08, 0.0)
	process.damping_min = 0.02
	process.damping_max = 0.05
	process.scale_min = 0.7
	process.scale_max = 1.15
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.55))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 0.8 * strength))
	fade.add_point(0.6, Color(1, 1, 1, 0.45 * strength))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	# Each wisp's own sway and puff (shade_wisp reads it as a seed).
	process.anim_offset_min = 0.0
	process.anim_offset_max = 1.0
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.5
	process.turbulence_noise_scale = 1.6
	process.turbulence_noise_speed_random = 0.2
	process.turbulence_influence_min = 0.02
	process.turbulence_influence_max = 0.06
	shape.call(process)
	wisps.process_material = process
	var quad := QuadMesh.new()
	quad.size = size
	# Standing on where it was let go, not centred on it.
	quad.center_offset = Vector3(0.0, size.y * 0.4, 0.0)
	quad.material = _wisp_material
	wisps.draw_pass_1 = quad
	return wisps


## The shoulders' emitter over the line of its shoulders (world-aligned, so
## the smoke rises straight up whichever way it turns).
func _place_shoulder_wisps() -> void:
	if _shoulders == null or man == null or not is_inside_tree():
		return

	var left := man.bone_global(&"upperarm_l").origin
	var right := man.bone_global(&"upperarm_r").origin
	_shoulders.global_transform = Transform3D(Basis(Vector3.UP, man.global_rotation.y), (left + right) * 0.5 + Vector3.UP * 0.05)


## The eased uniforms onto every pass, and the wisps' colour with them.
func _apply() -> void:
	for material in _materials:
		material.set_shader_parameter(&"shade_colour", _colour)
		material.set_shader_parameter(&"glow", _now[&"glow"])
		material.set_shader_parameter(&"opacity", _now[&"opacity"])
		material.set_shader_parameter(&"flicker", _now[&"flicker"])
		material.set_shader_parameter(&"smoke_speed", _now[&"smoke_speed"])
		material.set_shader_parameter(&"drift", _drift)

	if _wisp_material != null:
		_wisp_material.set_shader_parameter(&"wisp_colour", _colour)
		_wisp_material.set_shader_parameter(&"glow", _now[&"glow"])
		_wisp_material.set_shader_parameter(&"opacity", _now[&"opacity"])
		_wisp_material.set_shader_parameter(&"flicker", _now[&"flicker"])
		_wisp_material.set_shader_parameter(&"seed", float(_seed))
		_feet.speed_scale = 0.7 + 0.3 * float(_now[&"smoke_speed"]) / 0.15
		_shoulders.speed_scale = _feet.speed_scale
