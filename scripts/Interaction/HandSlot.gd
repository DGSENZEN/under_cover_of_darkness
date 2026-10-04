extends Node3D
## Camera-child inventory viewmodel and world-contact hand presentation.
## The right hand shows the selection; the left queues pickup/key/purse jobs.
## Viewmodels use visual layer 19 and squeezed depth, lit by the world; lightgem
## cameras exclude them. ViewArms solves limbs and HandContacts supplies holds.

signal key_turned

const Fx := preload("res://scripts/Visual/Fx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const SwingTrailScript := preload("res://scripts/Visual/SwingTrail.gd")
const ViewArmsScript := preload("res://scripts/Interaction/ViewArms.gd")
const ViewPosesScript := preload("res://scripts/Combat/ViewPoses.gd")
const HandContactsScript := preload("res://scripts/Interaction/HandContacts.gd")
const HeldPageScript := preload("res://scripts/Interaction/HeldPage.gd")

## Visual layer 19. The lightgem cameras' cull masks leave it out.
const VIEWMODEL_LAYER := 1 << 18
## A page held up to read (the letter, a notice): where it sits in the view's
## miniature, tipped back to face the eye; how long it takes to come up or go
## down (s); how hard the head glances down to it as it comes (rad/s).
const PAGE_REST := Vector3(0.0, -0.045, -0.25)
const PAGE_TILT := -0.18
const PAGE_TIME := 0.25
const PAGE_GLANCE := -0.6
## Something precious taken: turned over in the off hand this long (s), this
## far about and toward the eye, before it goes away.
const REGARD_TIME := 1.2
const REGARD_TURN := 3.5
const REGARD_TILT := 0.44
## What a weapon's edge gets smeared with.
const BLADE_BLOOD := preload("res://scripts/Visual/blade_blood.gdshader")
## The smear your blade leaves (SwingTrail.gd): steel catching the light, and
## the blow that spends your adrenaline.
const TRAIL_COLOR := Color(0.86, 0.9, 1.0, 0.36)
const TRAIL_HOT := Color(1.0, 0.55, 0.3, 0.5)
## Resting hands stay within this distance of the eye: inside the capsule.
const MAX_REACH := 0.45
## How things sit in a hand, as the thing in the hand bone's space (+Y along
## the fingers, +Z the thumb side, the back of the right hand +X, of the left
## -X), full size. A blade (or a club, or anything held like one) out of the
## thumb side of the right fist, as the guards hold theirs (GuardRig.GRIP).
## The grip lies across the palm on a slant, as it does in a real fist, so
## a blade can point along the arm for a thrust without a broken wrist.
const HAND_GRIP := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)) * Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)), Vector3(-0.03, 0.08, 0.0))
## A bow in the left fist: upright, the string toward you.
const BOW_GRIP := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0.03, 0.08, 0.0))
## The purse sitting in the left palm, facing up.
const PURSE_GRIP := Transform3D(Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)), Vector3(0.085, 0.07, 0.0))
## A small thing (a key, a coin) pinched in the left hand, up from the palm.
const PINCH_GRIP := Transform3D(Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)), Vector3(0.05, 0.1, 0.0))
## The string hand: the right fingers hooked on the nock, palm toward the bow.
const STRING_GRIP := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(-0.02, 0.09, 0.0))
## A bow's string in its own space (assets/weapons/bow.glb): where it runs,
## where the limbs hold it, where the arrow sits on it, how far it comes back
## at full draw; and where an arrow's tail is along it.
const BOW_STRING_Z := 0.132
const BOW_LIMB_TIP := 0.595
const BOW_NOCK_Y := 0.07
const BOW_DRAW_LENGTH := 0.44
## After a shot the string hand goes to the quiver at your right hip, out of
## sight, and comes back with the next arrow (seconds; where, full size, from
## your eye).
const NOCK_TIME := 0.55
const QUIVER := Vector3(0.34, -0.62, 0.1)
## The left hand braced on the flat of the blade, in the sword's frame (the
## blade +Y, the true edge +X, the flat toward you +Z): palm on the flat,
## fingers up the edge, thumb toward the hilt.
const BRACE := Transform3D(Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)), Vector3(-0.08, 0.42, 0.05))
const ARROW_TAIL := 0.356

@export var main_rest := Vector3(0.19, -0.19, -0.34)
@export var off_rest := Vector3(-0.19, -0.21, -0.33)
## How far below its rest a lowered hand sits: out of view.
@export var lowered_drop := 0.34
## Items are fitted so their longest side is this long.
@export var item_length := 0.2
@export var switch_time := 0.13
@export var sway_amount := 0.01

var player: CharacterBody3D

var _main: Node3D
var _main_mesh: MeshInstance3D
var _main_item: Mesh = null
var _pending_item: Mesh = null
var _switching := false
var _main_lower := 1.0
var _suppressed := false
var _swing := 0.0
## Throwing what is in the hand: it goes partway through the swing.
var _throwing := false

var _off: Node3D
var _purse: MeshInstance3D
var _tally: Label3D
var _keyring: Node3D
var _off_item: MeshInstance3D
var _off_lower := 1.0
var _purse_bulge := 0.0

## Off-hand jobs run one at a time: { "kind", "mesh", "from", "done", "t" }.
var _jobs: Array[Dictionary] = []
var _job: Dictionary = {}
var _checking := false
var _time := 0.0

## Full-size camera-space weapon frames sent by combat and interpolated between ticks.
var _frame_now := Transform3D.IDENTITY
var _frame_before := Transform3D.IDENTITY
## Which set of poses the thing in hand has (a weapon), or none.
var _view_id: StringName = &""
## The left hand on the flat of the blade: a braced block.
var _brace := 0.0
var _brace_shown := 0.0
## The pose before this physics tick's: frames between ticks blend the two,
## so a swing is smooth on a fast screen instead of stepping at the tick rate.
var _frame_tick := -100
var _nocked: MeshInstance3D
## 0 -> 1 through fetching the next arrow after a shot (1: on the string);
## and how hard the string still shivers from the loose.
var _nock_t := 1.0
var _string_shiver := 0.0
var _has_arrow := false
## A bow's string, upper and lower half, drawn by hand: the model's own is
## hidden so it can bend back to the nock.
var _strings: Array[MeshInstance3D] = []
var _draw := 0.0
var _leg: MeshInstance3D
var _shin: MeshInstance3D
var _kick := 0.0

# Weight: springs that ride on top of whatever pose the hand is in. A blow
# that lands, a blade that is stopped, a wall that turns it: each is an
# impulse here. The shudder runs on real time, so it plays through hit-stop.
var _recoil := Vector3.ZERO
var _recoil_v := Vector3.ZERO
var _recoil_rot := Vector3.ZERO
var _recoil_rot_v := Vector3.ZERO
var _shudder := 0.0
var _real_time := 0.0
var _last_real := -1.0

# The blade: where its edge runs, the smear it leaves, the blood on it.
var _trail: MeshInstance3D
var _trail_on := false
var _has_blade := false
var _blade_base := Vector3.ZERO
var _blade_tip := Vector3.ZERO
## Per weapon (by its mesh): how much blood is on it, and how fresh.
var _blood := {}
var _blood_wet := {}
var _blood_overlay: ShaderMaterial
var _tint_timer := 0.0
var _glint: MeshInstance3D
var _glint_t := -1.0

# Motion: the hands answer the body. They drag behind a turn and swing back,
# bob in step with the walk, dip when you land, rise when you jump, and drop
# into a running carry when you sprint.
@export var sway_lag := 0.55
@export var bob_amount := 1.0
var _sway := Vector2.ZERO
var _sway_v := Vector2.ZERO
var _last_look := Basis.IDENTITY
var _look_known := false
var _hop := 0.0
var _hop_v := 0.0
var _run := 0.0

# HandContacts provides world holds; ViewArms solves them from the shoulders.
# A weapon lowers when the right hand is needed on a ledge, ladder, or rope.
const SHOULDERS := [Vector3(-0.22, -0.4, 0.02), Vector3(0.22, -0.4, 0.02)]
var _gripping := 0.0
## The world wants the right hand (a ledge, a rung): what it holds goes down
## out of sight first.
var _right_wanted := false
## Each hand's hold on the world this frame: the palm (in this node's space,
## full size) and how firmly, left then right.
var _grip_palms: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _grip_weights: Array[float] = [0.0, 0.0]
var _grip_curls: Array[float] = [0.5, 0.5]
## Your arms.
var _arms: Node3D
## The page held up to read (HeldPage), made the first time; wanted up or
## not, and how far up it is (0..1).
var _page: Node3D = null
var _page_wanted := false
var _page_up := 0.0
## Where your hands hold on to the world (HandContacts.gd).
var _contacts: RefCounted


func _ready() -> void:
	player = _find_player()

	_main = Node3D.new()
	_main.name = "MainHand"
	add_child(_main)
	_main_mesh = _viewmodel_instance()
	_main.add_child(_main_mesh)

	_off = Node3D.new()
	_off.name = "OffHand"
	add_child(_off)

	_purse = _viewmodel_instance()
	var pouch := SphereMesh.new()
	pouch.radius = 0.034
	pouch.height = 0.06
	pouch.radial_segments = 10
	pouch.rings = 6
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.3, 0.2, 0.12)
	leather.roughness = 0.9
	pouch.material = leather
	_purse.mesh = pouch
	_purse.material_override = _viewmodel_material(pouch)
	_off.add_child(_purse)

	_tally = Label3D.new()
	_tally.layers = VIEWMODEL_LAYER
	_tally.no_depth_test = true
	_tally.render_priority = 12
	_tally.pixel_size = 0.00042
	_tally.font_size = 40
	_tally.outline_size = 10
	_tally.modulate = Color(0.95, 0.88, 0.7)
	_tally.shaded = false
	_tally.position = Vector3(0.0, 0.052, 0.012)
	_purse.add_child(_tally)

	_keyring = Node3D.new()
	_keyring.position = Vector3(0.055, -0.01, 0.0)
	_off.add_child(_keyring)

	_off_item = _viewmodel_instance()
	_off.add_child(_off_item)

	# An arrow on the string, shown while drawing a bow, and the string
	# itself in two halves, pulled back to it.
	_nocked = _viewmodel_instance()
	_nocked.visible = false
	_main_mesh.add_child(_nocked)
	# Waxed linen: brown, not white, or right by your eye it is a bar of light.
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.42, 0.35, 0.25)
	cord.roughness = 0.8
	_squeeze(cord)

	for half in range(2):
		var strand := _viewmodel_instance()
		var line := BoxMesh.new()
		line.size = Vector3(0.0035, 1.0, 0.0035)
		strand.mesh = line
		strand.material_override = cord
		strand.visible = false
		_main_mesh.add_child(strand)
		_strings.append(strand)

	# A boot, for the kick.
	_leg = _viewmodel_instance()
	var boot := BoxMesh.new()
	boot.size = Vector3(0.16, 0.14, 0.32)
	var hide := StandardMaterial3D.new()
	hide.albedo_color = Color(0.16, 0.12, 0.09)
	hide.roughness = 0.9
	boot.material = hide
	_leg.mesh = boot
	_leg.material_override = _viewmodel_material(boot)
	_leg.visible = false
	add_child(_leg)

	# The shin, from a knee below the view down to the heel: laid along the
	# two every frame, so the leg always reads as a leg.
	_shin = _viewmodel_instance()
	var calf := BoxMesh.new()
	calf.size = Vector3(0.15, 1.0, 0.13)
	var legging := StandardMaterial3D.new()
	legging.albedo_color = Color(0.26, 0.27, 0.32)
	legging.roughness = 0.95
	calf.material = legging
	_shin.mesh = calf
	_shin.material_override = _viewmodel_material(calf)
	_shin.visible = false
	add_child(_shin)

	_arms = ViewArmsScript.new()
	add_child(_arms)
	_arms.setup(VIEWMODEL_LAYER)

	if player != null:
		_contacts = HandContactsScript.new(player)

	# Blood on the blade, over the steel, squeezed in front like the rest.
	_blood_overlay = ShaderMaterial.new()
	_blood_overlay.shader = BLADE_BLOOD
	_blood_overlay.render_priority = 11 # After the held steel (10).
	_blood_overlay.set_shader_parameter("z_clip", ViewArmsScript.Z_CLIP)

	# The smear a blade leaves, drawn over the world like the hands.
	_trail = SwingTrailScript.new()
	_trail.name = "BladeTrail"
	_trail.setup(VIEWMODEL_LAYER, true)
	_trail.lifetime = 0.1
	_trail.base_fade = 0.5
	_trail.color = TRAIL_COLOR
	add_child(_trail)

	# A star on the blade's tip: a charged blow is ready.
	_glint = _viewmodel_instance()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_glint.mesh = quad
	var star := StandardMaterial3D.new()
	star.albedo_texture = Fx.texture(&"star")
	star.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	star.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	star.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star.albedo_color = Color(1.0, 0.95, 0.8)
	star.no_depth_test = true
	star.render_priority = 12
	star.disable_fog = true
	_glint.material_override = star
	_glint.visible = false
	_main.add_child(_glint)

	_place_hands()


func _find_player() -> CharacterBody3D:
	var node := get_parent()

	while node != null and not (node is CharacterBody3D):
		node = node.get_parent()

	return node as CharacterBody3D


# The main hand

## Queues lowering/switching to item.mesh; {} or absent/null mesh selects empty hands.
## May play the previous item’s stow sound immediately.
func show_item(item: Dictionary) -> void:
	# What goes away is heard going: a blade into its sheath, a bow onto the
	# back. A small blade rings higher.
	if _main_item != null and item.get("mesh") != _main_item:
		var voice: float = float(_main_item.get_meta(&"voice", 1.0))

		if _main_item.has_meta(&"stow_sound"):
			Sfx.play_flat(self, _main_item.get_meta(&"stow_sound"), 0.0, voice)
		elif _has_blade:
			Sfx.play_flat(self, &"sheath", 0.0, voice)

	_pending_item = item.get("mesh")
	_switching = true


## A quick overhand swing of whatever is held.
func play_swing() -> void:
	_swing = 1.0


## Thrown (a flash bomb, a water flask): the same overhand, the thing leaving
## your hand partway, and the next one (if any) coming up from your belt.
func play_throw() -> void:
	_swing = 1.0
	_throwing = true


## Both hands are busy (a crate, a body): the item goes out of sight.
func set_suppressed(suppressed: bool) -> void:
	_suppressed = suppressed


## Combat poses the weapon each physics tick: where its grip is and which
## way it points (ViewPoses.gd), in camera space, full size.
func set_weapon_frame(frame: Transform3D) -> void:
	var tick := Engine.get_physics_frames()

	if tick != _frame_tick:
		_frame_before = _frame_now if _frame_tick >= 0 else frame
		_frame_tick = tick

	_frame_now = frame


## The left hand braces the flat of the blade (a sword block): 0..1.
func set_brace(amount: float) -> void:
	_brace = clampf(amount, 0.0, 1.0)


## Returns the last displayed weapon transform in full-size camera space.
func weapon_frame() -> Transform3D:
	return _frame_now


## A bow being drawn: 0 slack, 1 fully drawn. An arrow shows on the string.
func set_bow_draw(draw: float, arrow: Mesh) -> void:
	_draw = draw
	_has_arrow = arrow != null
	# On the string at rest as well as drawn; not while the hand is off
	# fetching it.
	_nocked.visible = _has_arrow and _nock_t >= 0.4

	if arrow != null and _nocked.mesh != arrow:
		_nocked.mesh = arrow
		_apply_materials(_nocked, arrow)


func play_kick() -> void:
	_kick = 1.0


## Feet hit the ground: the hands keep falling a moment, then spring back.
func land(fall_speed: float) -> void:
	_hop_v -= clampf(fall_speed * 0.07, 0.0, 1.1)


## Pushing off: the hands lift.
func jump() -> void:
	_hop_v += 0.4


## How far the hands lag behind the view right now (radians, yaw and pitch).
func sway() -> Vector2:
	return _sway


## The blade leaves a smear while `on`. A power blow leaves a brighter one,
## a blow that spends your adrenaline a hot one.
func set_trail(on: bool, power := false, hot := false) -> void:
	_trail_on = on and _has_blade and not _suppressed
	_trail.color = TRAIL_HOT if hot else TRAIL_COLOR
	_trail.color.a *= 1.5 if power else 1.0


## Something met the weapon (or the boot). `kind`: "flesh", "heavy",
## "blocked" (he caught your blow), "deflect" (a wall turned it), "block"
## (you caught his), "parry", "kick".
func impact(kind: StringName) -> void:
	match kind:
		&"flesh":
			_shudder = maxf(_shudder, 0.7)
			_recoil_v += Vector3(0.0, -0.15, 0.25)
			_recoil_rot_v += Vector3(0.6, 0.0, 0.0)
		&"heavy":
			_shudder = 1.0
			_recoil_v += Vector3(0.0, -0.25, 0.4)
			_recoil_rot_v += Vector3(1.0, 0.0, 0.0)
		&"blocked":
			_shudder = 1.0
			_recoil_v += Vector3(0.1, 0.35, 1.0)
			_recoil_rot_v += Vector3(2.2, 0.0, 0.6)
		&"deflect":
			_shudder = 1.0
			_recoil_v += Vector3(0.0, 0.25, 1.2)
			_recoil_rot_v += Vector3(2.5, 0.0, -0.8)
		&"block":
			_shudder = 0.9
			_recoil_v += Vector3(0.15, -0.3, 0.9)
			_recoil_rot_v += Vector3(-1.0, 0.0, 1.2)
		&"parry":
			_shudder = 1.0
			_recoil_v += Vector3(-0.2, 0.4, 0.6)
			_recoil_rot_v += Vector3(1.5, 0.8, 0.0)
		&"kick":
			_shudder = maxf(_shudder, 0.8)
		&"bow":
			# The limbs throw the bow forward and the top over; the string
			# hums; the hand goes for the next arrow.
			_recoil_v += Vector3(0.0, 0.1, -0.6)
			_recoil_rot_v += Vector3(-1.2, 0.0, 1.5)
			_string_shiver = 1.0
			_nock_t = 0.0

	# A blade that was stopped stops smearing; one that cut through goes on.
	if kind in [&"blocked", &"deflect", &"block", &"parry"]:
		set_trail(false)


## Let go of the blood's material before it is freed: a mesh still pointing
## at a freed shader material complains on the way out.
func _exit_tree() -> void:
	if _main_mesh != null:
		_main_mesh.material_overlay = null


## Blood on the blade in hand. It builds up with each cut and dries off
## slowly; each weapon keeps its own.
func bloody(amount: float) -> void:
	if not _has_blade or _main_item == null:
		return

	var key := _main_item.get_instance_id()
	_blood[key] = clampf(float(_blood.get(key, 0.0)) + amount, 0.0, 1.0)
	_blood_wet[key] = 1.0
	_tint_blade()


func blood_on_blade() -> float:
	if _main_item == null:
		return 0.0

	return float(_blood.get(_main_item.get_instance_id(), 0.0))


## A glint runs up to the tip: the blow is charged.
func show_glint() -> void:
	if _has_blade:
		_glint_t = 0.0


func is_trail_on() -> bool:
	return _trail_on


func trail_samples() -> int:
	return _trail.sample_count()


func is_item_visible() -> bool:
	return _main_item != null and _main_lower < 0.05


func current_item_mesh() -> Mesh:
	return _main_item


func _update_main(delta: float) -> void:
	var step := delta / maxf(switch_time, 0.01)

	# Lower first, swap at the bottom, then come back up.
	# Both hands on a ledge or a ladder: what you held goes out of sight.
	var want_up := _main_item != null and not _suppressed and not _switching and not _right_wanted

	# Down out of sight quickly when the hand is wanted on a ledge or a rung.
	if _right_wanted:
		step = delta / 0.1

	if _switching:
		_main_lower = move_toward(_main_lower, 1.0, step)

		if _main_lower >= 1.0:
			_switching = false
			_set_main_item(_pending_item)
	else:
		_main_lower = move_toward(_main_lower, 0.0 if want_up else 1.0, step)

	_swing = move_toward(_swing, 0.0, delta * 3.2)

	# Thrown: gone from the hand at the release; the swing done, the next one
	# comes up from below.
	if _throwing:
		if _swing < 0.62:
			_main_mesh.visible = false

		if _swing <= 0.0:
			_throwing = false
			_main_lower = 1.0
			_main_mesh.visible = true


func _set_main_item(mesh: Mesh) -> void:
	_main_item = mesh
	_main_mesh.mesh = mesh
	_apply_materials(_main_mesh, mesh)
	_view_id = mesh.get_meta(&"view_poses", &"") if mesh != null else &""

	if _view_id != &"":
		# A weapon: square in the fist, at the arms' own size.
		_main_mesh.transform = Transform3D(Basis.from_scale(Vector3.ONE * ViewArmsScript.SCALE), Vector3.ZERO)
	else:
		_main_mesh.scale = Vector3.ONE * _fit_scale(mesh)
		_main_mesh.rotation = mesh.get_meta(&"hold_rotation", Vector3(-0.35, 0.25, 0.3)) if mesh != null else Vector3.ZERO

	# Taken up at its rest: nothing to glide from.
	_frame_now = _rest_frame()
	_frame_before = _frame_now

	# A bow's own string is drawn by hand (_place_string), so it can bend.
	if mesh != null and mesh.has_meta(&"draw_sound"):
		for i in range(mesh.get_surface_count()):
			var source := mesh.surface_get_material(i)

			if source != null and source.resource_name == "M_Feather":
				var gone := StandardMaterial3D.new()
				gone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				gone.albedo_color = Color(1, 1, 1, 0)
				_main_mesh.set_surface_override_material(i, gone)

	# A blade: where its edge runs, and the material that shows blood.
	_has_blade = mesh != null and mesh.has_meta(&"blade_tip")

	# Drawn: steel sings out of the scabbard, a bow comes off the back;
	# anything else is just taken up.
	if mesh != null and _time > 0.3:
		var voice: float = float(mesh.get_meta(&"voice", 1.0))

		if mesh.has_meta(&"draw_sound"):
			Sfx.play_flat(self, mesh.get_meta(&"draw_sound"), 0.0, voice)
		else:
			Sfx.play_flat(self, &"blade_draw" if _has_blade else &"pickup", 0.0, voice)
	_trail_on = false
	_trail.clear()
	_main_mesh.material_overlay = null

	if _has_blade:
		_blade_base = mesh.get_meta(&"blade_base", Vector3.ZERO)
		_blade_tip = mesh.get_meta(&"blade_tip", Vector3.UP)
		_blood_overlay.set_shader_parameter("blade_base", _blade_base)
		_blood_overlay.set_shader_parameter("blade_tip", _blade_tip)
		_blood_overlay.set_shader_parameter("seed", float(mesh.get_instance_id() % 97) * 0.37)
		_main_mesh.material_overlay = _blood_overlay
		_tint_blade()


## The blood on the blade in hand, drawn (blade_blood.gdshader).
func _tint_blade() -> void:
	if _main_item == null or _blood_overlay == null:
		return

	var key := _main_item.get_instance_id()
	_blood_overlay.set_shader_parameter("amount", float(_blood.get(key, 0.0)))
	_blood_overlay.set_shader_parameter("wet", float(_blood_wet.get(key, 1.0)))


# The off hand

## Queues a pickup presentation job {kind, mesh, from, t}; from is a world transform.
func receive(kind: String, mesh: Mesh, from: Transform3D) -> void:
	_jobs.append({ "kind": kind, "mesh": mesh, "from": from, "t": 0.0 })


## Prioritizes a key-turn job at world lock_point; done runs on completion.
## A current pickup is hurried; a current key turn is not replaced.
func turn_key(mesh: Mesh, lock_point: Vector3, done: Callable) -> void:
	if not _job.is_empty() and _job["kind"] != "key_turn" and not _job.has("hurry"):
		_job["hurry"] = float(_job["t"])

	_jobs.push_front({ "kind": "key_turn", "mesh": mesh, "lock": lock_point, "done": done, "t": 0.0 })


## Holding up the purse and key ring to see what you carry.
func set_checking(checking: bool) -> void:
	_checking = checking


# A page held up in both hands

## Raises a page (`sides` BBCode, one per side; `look` a HeldPage.SIZES key)
## in both hands, or shows these on the one already up.
func hold_page(sides: PackedStringArray, look: StringName) -> void:
	if _page == null:
		_page = HeldPageScript.new()
		_page.name = "Page"
		_page.visible = false
		add_child(_page)
		_squeeze(_page.paper_material())

	_page.side = 0 if not _page_wanted else _page.side
	_page.show_sides(sides, look)

	if not _page_wanted:
		_page_wanted = true
		Sfx.play_flat(self, &"paper")

		# The head goes down to it first.
		if player != null and player.get("juice") != null:
			player.juice.punch(PAGE_GLANCE, 0.0)


## New words on the page up (the side kept).
func update_page(sides: PackedStringArray) -> void:
	if _page != null and _page_wanted:
		_page.show_sides(sides, _page.look)


func turn_page() -> void:
	if _page != null and _page_wanted and _page.side_count() > 1:
		_page.turn()
		Sfx.play_flat(self, &"paper")


func lower_page() -> void:
	if _page_wanted:
		_page_wanted = false
		Sfx.play_flat(self, &"paper")


func is_page_up() -> bool:
	return _page_wanted


## The page (HeldPage), or null if none was ever held.
func page() -> Node3D:
	return _page


## What the page up is (HeldPage.SIZES' key), or &"" with none up.
func page_look() -> StringName:
	return _page.look if _page != null and _page_wanted else &""


## Where a hand holds the page (world, a HandContacts hold).
func page_edge(side: int) -> Transform3D:
	return _page.edge(side) if _page != null else global_transform


func _update_page(delta: float) -> void:
	_page_up = move_toward(_page_up, 1.0 if _page_wanted else 0.0, delta / PAGE_TIME)


func is_busy() -> bool:
	return not _job.is_empty() or not _jobs.is_empty()


func is_purse_visible() -> bool:
	return _purse.visible and _off_lower < 0.05


func tally_text() -> String:
	return _tally.text


func _update_off(delta: float) -> void:
	if _job.is_empty() and not _jobs.is_empty():
		_job = _jobs.pop_front()
		_start_job()

	_purse_bulge = move_toward(_purse_bulge, 0.0, delta * 3.0)

	if not _job.is_empty():
		_job["t"] = float(_job["t"]) + delta
		_run_job()
		return

	# Idle: the off hand is up only while you are checking your purse.
	_off_item.visible = false
	_purse.visible = true
	_keyring.visible = true
	_refresh_purse()
	var want := 0.0 if _checking and not _suppressed and _gripping < 0.2 and not _page_wanted else 1.0
	_off_lower = move_toward(_off_lower, want, delta / maxf(switch_time, 0.01))


func _start_job() -> void:
	var mesh: Mesh = _job.get("mesh")
	_off_item.mesh = mesh
	_apply_materials(_off_item, mesh)
	_off_item.scale = Vector3.ONE * _fit_scale(mesh) * 0.7
	_off_item.visible = mesh != null
	_off_item.rotation = Vector3.ZERO
	_refresh_purse()

	var kind: String = _job["kind"]
	_purse.visible = kind == "loot"
	_keyring.visible = kind == "key"

	if kind == "special":
		_off_item.scale = Vector3.ONE * _fit_scale(mesh) * 0.9


func _run_job() -> void:
	var t: float = _job["t"]
	var kind: String = _job["kind"]

	if kind == "key_turn":
		_run_key_turn(t)
		return

	if kind == "special":
		_run_regard(t)
		return

	# Taking something: it flies from where it lay into the raised off hand,
	# drops into the purse (loot) or onto the ring (keys), and the hand goes
	# back down.
	var fly := 0.2
	var stow := 0.16
	var show := 0.55 if kind == "loot" else 0.25
	var lower := 0.18

	# A key to turn: shown only as long as it has been, then straight down.
	if _job.has("hurry"):
		show = clampf(float(_job["hurry"]) - fly - stow, 0.0, show)
	_off_lower = 1.0 - smoothstep(0.0, fly * 0.8, t)

	if t < fly:
		var start := _to_off_space(_job["from"])
		var u := _ease_out(t / fly)
		_off_item.position = start.lerp(Vector3(0.0, 0.05, 0.0), u)
	elif t < fly + stow:
		var u := (t - fly) / stow
		_off_item.position = Vector3(0.0, 0.05 * (1.0 - u), 0.0)
		_off_item.scale = Vector3.ONE * _fit_scale(_off_item.mesh) * 0.7 * (1.0 - u)
	else:
		_off_item.visible = false

		if not _job.get("stowed", false):
			_job["stowed"] = true
			_purse_bulge = 1.0
			_refresh_purse()

			# Into the purse, onto the ring, into a pocket.
			match kind:
				"loot":
					Sfx.play_flat(self, &"coins")
				"key":
					Sfx.play_flat(self, &"keys")
				_:
					Sfx.play_flat(self, &"pickup")

	if t > fly + stow + show:
		_off_lower = smoothstep(fly + stow + show, fly + stow + show + lower, t)

	if t > fly + stow + show + lower:
		_job = {}


## Something precious: into the off hand, turned over in the light, then
## away. A run, a jump or a blow cuts the look short.
func _run_regard(t: float) -> void:
	var fly := 0.2
	var stow := 0.16
	var lower := 0.18
	var regard := float(_job.get("cut", REGARD_TIME))

	if t > fly and t < fly + regard and _cut_short():
		_job["cut"] = t - fly
		regard = t - fly

	_off_lower = 1.0 - smoothstep(0.0, fly * 0.8, t)

	if t < fly:
		var start := _to_off_space(_job["from"])
		_off_item.position = start.lerp(Vector3(0.0, 0.05, 0.0), _ease_out(t / fly))
	elif t < fly + regard:
		var u := _ease_out((t - fly) / REGARD_TIME)
		_off_item.position = Vector3(0.0, 0.05 + 0.02 * sin(PI * u), 0.0)
		_off_item.rotation = Vector3(REGARD_TILT * sin(PI * u), REGARD_TURN * u, 0.0)
	elif t < fly + regard + stow:
		var u := (t - fly - regard) / stow
		_off_item.scale = Vector3.ONE * _fit_scale(_off_item.mesh) * 0.7 * (1.0 - u)
	else:
		_off_item.visible = false

		if not _job.get("stowed", false):
			_job["stowed"] = true
			Sfx.play_flat(self, &"pickup")

	if t > fly + regard + stow:
		_off_lower = smoothstep(fly + regard + stow, fly + regard + stow + lower, t)

	if t > fly + regard + stow + lower:
		_job = {}


## The player is off: running, in the air, in a blow.
func _cut_short() -> bool:
	if player == null:
		return false

	var fighting: Node = player.get("combat")
	return player._is_sprinting() or (not player.is_on_floor() and absf(player.velocity.y) > 1.5) \
		or (fighting != null and fighting.get("phase") != null and int(fighting.phase) != 0)


func _run_key_turn(t: float) -> void:
	var raise := 0.14
	var reach := 0.2
	var turn := 0.22
	var back := 0.18

	_off_lower = 1.0 - smoothstep(0.0, raise, t)
	_purse.visible = false
	_keyring.visible = false

	# Toward the lock, as far as a hand reaches without leaving the body.
	var lock_local := _to_off_space(Transform3D(Basis.IDENTITY, _job["lock"]))
	var toward := lock_local.normalized() * minf(lock_local.length(), 0.14)
	var out := smoothstep(raise, raise + reach, t) - smoothstep(raise + reach + turn, raise + reach + turn + back, t)
	_off_item.position = toward * out
	_off_item.rotation = Vector3(0.0, 0.0, -PI * 0.5 * smoothstep(raise + reach, raise + reach + turn, t))

	if t >= raise + reach + turn and not _job.get("turned", false):
		_job["turned"] = true
		key_turned.emit()
		var done: Callable = _job["done"]

		if done.is_valid():
			done.call()

	if t > raise + reach + turn + back:
		_off_lower = smoothstep(raise + reach + turn + back, raise + reach + turn + back + 0.15, t)

	if t > raise + reach + turn + back + 0.15:
		_off_item.visible = false
		_job = {}


func _refresh_purse() -> void:
	if player == null or player.get("inventory") == null:
		return

	var total: int = player.inventory.purse
	_tally.text = "%d" % total

	# Slack when empty, fat when rich. Full size at 1000.
	var fullness := 0.75 + clampf(float(total) / 1000.0, 0.0, 1.0) * 0.8
	_purse.scale = Vector3.ONE * fullness * (1.0 + _purse_bulge * 0.25)

	var keys: Array = player.inventory.keys
	var shown := _keyring.get_child_count()

	if shown != keys.size() + 1:
		_rebuild_keyring(keys.size())


func _rebuild_keyring(count: int) -> void:
	for child in _keyring.get_children():
		child.queue_free()

	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.75, 0.62, 0.3)
	brass.metallic = 0.8
	brass.roughness = 0.4

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.012
	ring_mesh.outer_radius = 0.016
	ring_mesh.material = brass
	var ring := _viewmodel_instance()
	ring.mesh = ring_mesh
	ring.material_override = _viewmodel_material(ring_mesh)
	ring.rotation.x = PI * 0.5
	_keyring.add_child(ring)

	for i in range(mini(count, 6)):
		var key_mesh := BoxMesh.new()
		key_mesh.size = Vector3(0.006, 0.04, 0.002)
		key_mesh.material = brass
		var key := _viewmodel_instance()
		key.mesh = key_mesh
		key.material_override = _viewmodel_material(key_mesh)
		var fan := 0.0 if count <= 1 else lerpf(-0.5, 0.5, float(i) / float(mini(count, 6) - 1))
		key.position = Vector3(sin(fan) * 0.02, -0.022 - cos(fan) * 0.02, 0.0)
		key.rotation.z = fan
		_keyring.add_child(key)


# Every frame

func _process(delta: float) -> void:
	_time += delta
	var real_delta := TimeFx.real_since(_last_real) if _last_real >= 0.0 else 0.0
	_last_real = TimeFx.real_time()
	_real_time += real_delta
	_kick = move_toward(_kick, 0.0, delta / 0.42)
	_update_main(delta)
	_update_off(delta)
	_update_page(delta)
	_update_weight(delta, real_delta)
	_update_motion(delta)
	_place_hands()


func _update_motion(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)

	# The turn since last frame, from where you look (the neck: your aim, not
	# the camera's shake).
	var neck: Node3D = player.get("neck") if player != null else null

	if neck != null:
		var look := neck.global_basis.orthonormalized()

		if _look_known:
			var turn := (_last_look.inverse() * look).get_euler()
			_sway -= Vector2(turn.y, turn.x) * sway_lag

		_last_look = look
		_look_known = true

	_sway_v += (-_sway * 150.0 - _sway_v * 18.0) * dt
	_sway += _sway_v * dt
	_sway = _sway.limit_length(0.3)
	_hop_v += (-_hop * 170.0 - _hop_v * 13.0) * dt
	_hop += _hop_v * dt

	var running := false

	if player != null and player.has_method("_is_sprinting") and player.get("velocity") != null:
		var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
		running = player._is_sprinting() and flat.length() > float(player.get("walk_speed")) + 0.3

	_run = move_toward(_run, 1.0 if running else 0.0, delta * 4.0)


func _update_weight(delta: float, real_delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	_recoil_v += (-_recoil * 320.0 - _recoil_v * 22.0) * dt
	_recoil += _recoil_v * dt
	_recoil_rot_v += (-_recoil_rot * 320.0 - _recoil_rot_v * 22.0) * dt
	_recoil_rot += _recoil_rot_v * dt
	_shudder = move_toward(_shudder, 0.0, real_delta / 0.16)
	_nock_t = minf(_nock_t + delta / NOCK_TIME, 1.0)
	_string_shiver = move_toward(_string_shiver, 0.0, delta / 0.4)

	# Blood dries dark on the blade in half a minute, and wears off it over
	# a few.
	_tint_timer -= delta

	if _tint_timer <= 0.0 and _main_item != null:
		_tint_timer = 0.25
		var key := _main_item.get_instance_id()

		if float(_blood.get(key, 0.0)) > 0.0:
			_blood[key] = maxf(float(_blood[key]) - 0.25 / 240.0, 0.0)
			_blood_wet[key] = maxf(float(_blood_wet.get(key, 1.0)) - 0.25 / 30.0, 0.0)
			_tint_blade()

	if _glint_t >= 0.0:
		_glint_t += real_delta

		if _glint_t > 0.32:
			_glint_t = -1.0


func _place_hands() -> void:
	var sway := Vector3(sin(_time * 1.7), sin(_time * 2.3) * 0.6, 0.0) * sway_amount

	# The weapon's frame (full size, camera space): combat's, drawn between
	# its last two ticks; with no one posing it, its rest, glided back to.
	var rest := _rest_frame()

	if Engine.get_physics_frames() - _frame_tick > 2:
		var ease := 1.0 - exp(-12.0 * get_process_delta_time())
		_frame_now = ViewPosesScript.blend(_frame_now, rest, ease)
		_frame_before = _frame_now

	var between := Engine.get_physics_interpolation_fraction() if get_tree().physics_interpolation else 1.0
	var frame: Transform3D = ViewPosesScript.blend(_frame_before, _frame_now, between)

	# A quick swing of whatever is held (the blackjack, a tool): over and down.
	if _swing > 0.0:
		frame = _swing_frame(frame)

	# Put away or taken out: down out of sight, the point falling forward.
	var low := _ease_in_out(_main_lower)
	frame.origin += Vector3(0.05, -lowered_drop / ViewArmsScript.SCALE, 0.08) * low
	frame.basis = Basis(Vector3.RIGHT, -0.9 * low) * frame.basis

	# The body: lagging behind turns, and whatever the shoulders do under the
	# view (BodyMotion.gd): a footfall a beat after the head, a landing further
	# than the view, the push of a start and the carry of a stop, breathing,
	# and the lowered carry of a run as the body leans into it. (The old feel:
	# a bob of its own, a hop, a run carry at a fixed rate, an idle wobble.)
	var body: RefCounted = player.get("body_motion") if player != null else null
	var motion_position := Vector3(-_sway.x * 0.08, _sway.y * 0.06, 0.0)
	var motion_rotation := Vector3(_sway.y * 0.5, _sway.x * 0.6, _sway.x * 0.35)

	if body != null and not bool(player.get("legacy_feel")):
		var shoulders: Transform3D = body.shoulder_offset(between)
		var carry: float = body.sprint_lean()
		sway = Vector3.ZERO
		# The shoulders move in the world; the hands are drawn in the view's
		# miniature, where the same angle is SCALE of the distance.
		motion_position += shoulders.origin * ViewArmsScript.SCALE + Vector3(0.0, -0.035, 0.02) * carry
		motion_rotation += shoulders.basis.get_euler() + Vector3(0.18, 0.0, 0.1) * carry
	else:
		var phase := 0.0
		var weight := 0.0

		if player != null and player.get("juice") != null:
			phase = player.juice.bob_phase()
			weight = player.juice.bob_weight() * bob_amount

		var bob_position := Vector3(sin(phase) * 0.009, cos(phase * 2.0) * 0.006, 0.0) * weight
		var bob_rotation := Vector3(0.0, 0.0, sin(phase) * 0.025) * weight
		motion_position += Vector3(0.0, _hop * 0.05, 0.0) + bob_position + Vector3(0.0, -0.035, 0.02) * _run
		motion_rotation += bob_rotation + Vector3(0.18, 0.0, 0.1) * _run

	# Weight on top: recoils, and the shudder of steel biting.
	var shake := _shudder * _shudder
	var buzz := Vector3(sin(_real_time * 97.0), sin(_real_time * 83.0 + 1.0), sin(_real_time * 71.0 + 2.0))

	# All of it turns the weapon about its grip and moves it (the numbers are
	# in the view's small world, so they are grown to full size here).
	var turned := motion_rotation + _recoil_rot + buzz * 0.035 * shake
	frame.basis = Basis.from_euler(turned) * frame.basis
	frame.origin += (sway + motion_position + _recoil + buzz * 0.005 * shake) / ViewArmsScript.SCALE

	# The fist turns the way the forearm runs: the wrist stays straight and
	# only tips the blade. The pose says where the grip is and where the blade
	# points; the arm says the rest.
	if _view_id != &"" and _view_id != &"bow":
		frame = _natural(frame)

	_main.transform = Transform3D(frame.basis, frame.origin * ViewArmsScript.SCALE)

	# The edge's smear, recorded in this node's space so it rides the view.
	if _trail_on and _main.visible and _has_blade:
		var to_here := global_transform.affine_inverse()
		var blade := _main_mesh.global_transform
		_trail.push(to_here * (blade * _blade_base), to_here * (blade * _blade_tip))

	# The glint rides the tip while the blade is held back; it is gone once
	# the blade is cutting (swung past your eye, it would be a flare).
	_glint.visible = _glint_t >= 0.0 and _main.visible and not _trail_on

	if _glint.visible:
		var flare := sin(PI * clampf(_glint_t / 0.32, 0.0, 1.0))
		_glint.position = _main_mesh.transform * _blade_tip
		_glint.scale = Vector3.ONE * 0.045 * flare
		_glint.rotation.z = _glint_t * 5.0

	_place_string()

	# The kick: the knee comes up, the boot drives out fast, holds against
	# whatever it met, and drops away.
	if _kick > 0.0:
		var k := 1.0 - _kick
		var at := Vector3.ZERO
		var pitch := 0.0

		if k < 0.22:
			# The knee comes up: the boot rises into the bottom of the view.
			var u := _ease_out(k / 0.22)
			at = Vector3(0.09, lerpf(-0.72, -0.4, u), lerpf(-0.5, -0.36, u))
			pitch = lerpf(0.3, 0.7, u)
		elif k < 0.36:
			# Driven out, faster and faster, sole first.
			var u := (k - 0.22) / 0.14
			u = u * u
			at = Vector3(0.09, lerpf(-0.4, -0.26, u), lerpf(-0.36, -0.7, u))
			pitch = lerpf(0.7, 1.15, u)
		elif k < 0.5:
			at = Vector3(0.09, -0.26, -0.7)
			pitch = 1.15
		else:
			var u := _ease_in_out((k - 0.5) / 0.5)
			at = Vector3(0.09, lerpf(-0.26, -0.8, u), lerpf(-0.7, -0.45, u))
			pitch = lerpf(1.15, 0.4, u)

		# Where the boot is: his own right foot is put there (_place_arms).
		var jolt := buzz * 0.008 * shake
		_leg.position = at + jolt
		_leg.rotation = Vector3(pitch, 0.0, 0.0)

	_leg.visible = false
	_shin.visible = false

	_off.position = off_rest + Vector3.DOWN * lowered_drop * _ease_in_out(_off_lower) + sway * 0.8 + motion_position * 0.8
	_off.rotation = motion_rotation * 0.8
	_off.visible = _off_lower < 0.99
	_main.visible = _main_lower < 0.99

	if _page != null:
		var page_low := _ease_in_out(1.0 - _page_up)
		_page.position = PAGE_REST + Vector3.DOWN * lowered_drop * page_low + sway * 0.5 + motion_position * 0.6
		_page.rotation = Vector3(PAGE_TILT - 0.7 * page_low, 0.0, 0.0) + motion_rotation * 0.5
		_page.visible = _page_up > 0.01

	_place_grips()
	_place_arms()


## Hands on the world (HandContacts.gd): planted on the real ledge, rung or
## rope and held there in the world while the body moves, each hand moving on
## in its turn. The arms reach for them as they take hold.
func _place_grips() -> void:
	var strongest := 0.0

	for side in range(2):
		_grip_weights[side] = 0.0

	_right_wanted = false

	if _contacts != null and not _suppressed_for_grips():
		_contacts.right_busy = _main_item != null and not _switching
		_contacts.update(get_process_delta_time())
		_right_wanted = _contacts.wants(1)

		for side in range(2):
			var weight: float = _contacts.weight(side)

			# The right lets go of what it holds before it takes hold.
			if side == 1 and _main_item != null:
				weight *= smoothstep(0.7, 1.0, _main_lower)

			_grip_weights[side] = weight if weight >= 0.03 else 0.0
			# In this node's space, which rides the camera: full size.
			_grip_palms[side] = global_transform.affine_inverse() * _contacts.hand(side)
			_grip_curls[side] = _contacts.curl(side)
			strongest = maxf(strongest, weight)

	_gripping = strongest


## Both hands busy with nothing we draw (a body over the shoulder, dead).
func _suppressed_for_grips() -> bool:
	if player == null or player.get("is_dead") == true:
		return true

	return player.get("frob") != null and player.frob.has_method("is_shouldering") and player.frob.is_shouldering()


## Your arms, reaching for what each hand has: the right the grip of what you
## carry (a bow: its string, the bow itself in the left), the left the purse
## or whatever it is being handed, both the world when you hold on to it.
func _place_arms() -> void:
	if _arms == null:
		return

	var dead: bool = player != null and player.get("is_dead") == true
	var targets: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
	var weights: Array[float] = [0.0, 0.0]
	var curls: Array[float] = [0.35, 0.35]
	var bow := _main_item != null and _main_item.has_meta(&"draw_sound")

	var braced := 0.0

	if _main.visible and _main_item != null and not dead:
		# The fist is on the grip: the weapon's frame, whatever is drawn in it.
		var held := _main.transform

		if bow:
			# The bow in the left fist, the right on the string, drawn back
			# with the arrow. The fist turns about the stave to suit the arm.
			targets[0] = _around_stave(_held_by(held, BOW_GRIP), held.basis.y)
			weights[0] = 1.0
			curls[0] = 1.0
			var drawn := _main.transform * _main_mesh.transform * Transform3D(Basis.IDENTITY, _nock_point())
			targets[1] = _held_by(Transform3D(held.basis, drawn.origin), STRING_GRIP)
			weights[1] = 1.0
			curls[1] = 0.75

			if _nock_t < 1.0:
				targets[1] = _fetching(targets[1])
				curls[1] = 0.9
		else:
			targets[1] = _held_by(held, HAND_GRIP)
			weights[1] = 1.0
			curls[1] = 1.0

			# A braced block: the left palm on the flat.
			_brace_shown = move_toward(_brace_shown, _brace if _view_id == &"sword" else 0.0, get_process_delta_time() / 0.08)

			if _brace_shown > 0.01:
				var at := ViewArmsScript.SCALE
				braced = _brace_shown
				targets[0] = Transform3D(held.basis * BRACE.basis, held.origin + held.basis * (BRACE.origin * at))
				weights[0] = smoothstep(0.0, 1.0, braced)
				curls[0] = 0.2

	if _off.visible and not dead and not (bow and _main.visible) and braced < 0.5:
		if _off_item.visible:
			targets[0] = _held_by(_off.transform * _off_item.transform, PINCH_GRIP)
			curls[0] = 0.8
		else:
			targets[0] = _held_by(_off.transform * _purse.transform, PURSE_GRIP)
			curls[0] = 0.55

		weights[0] = 1.0

	# Holding on to the world wins.
	for side in range(2):
		var grip := _grip_weights[side]

		if grip > 0.0:
			var palm := _grip_palms[side]
			var hand := Transform3D(palm.basis * (_LEDGE_RIGHT if side == 1 else _LEDGE_LEFT), palm * Vector3(0.0, 0.02, 0.07))
			var shown: Transform3D = ViewArmsScript.shrink(hand)

			if weights[side] > 0.0:
				shown = targets[side].interpolate_with(shown, grip)

			targets[side] = shown
			weights[side] = maxf(weights[side], smoothstep(0.0, 0.5, grip))
			curls[side] = lerpf(curls[side], _grip_curls[side], grip)

	for side in range(2):
		_arms.set_hand(side, targets[side], weights[side], curls[side])

	# The kick: his own right foot where the boot goes.
	if _kick > 0.0 and not dead:
		var ankle := _leg.transform * Transform3D(_KICK_FOOT, Vector3(0.0, 0.05, 0.07))
		_arms.set_foot(ViewArmsScript.shrink(ankle), clampf(_kick * 6.0, 0.0, 1.0))
	else:
		_arms.set_foot(Transform3D.IDENTITY, 0.0)


## `frame` turned about its blade so the fist's fingers run along the forearm.
func _natural(frame: Transform3D) -> Transform3D:
	if _arms == null:
		return frame

	var blade := frame.basis.y.normalized()
	var wrist := (frame.origin - frame.basis.x.normalized() * 0.08) * ViewArmsScript.SCALE
	var forearm: Vector3 = _arms.forearm_to(1, wrist)
	var edge := forearm - blade * forearm.dot(blade)

	# A blade nearly along the forearm (no wrist bends that far) keeps the
	# pose's own edge, and between the two it eases, so the fist never spins.
	var sure := smoothstep(0.12, 0.4, edge.length())

	if sure <= 0.0:
		return frame

	edge = edge.normalized()
	var natural := Transform3D(Basis(edge, blade, edge.cross(blade)), frame.origin)
	return frame.interpolate_with(natural, sure) if sure < 1.0 else natural


## A left fist round a bow's stave (`hand`, its thumb up the stave), turned
## about the stave so its fingers run along the forearm.
func _around_stave(hand: Transform3D, stave: Vector3) -> Transform3D:
	var up := stave.normalized()
	var grip := hand * (BOW_GRIP.origin)
	var forearm: Vector3 = _arms.forearm_to(0, hand.origin)
	var fingers := forearm - up * forearm.dot(up)

	if fingers.length() < 0.25:
		return hand

	fingers = fingers.normalized()
	var basis := Basis(fingers.cross(up), fingers, up).scaled(Vector3.ONE * ViewArmsScript.SCALE)
	return Transform3D(basis, grip - basis * BOW_GRIP.origin)


## The frame the thing in hand rests at (ViewPoses.gd).
func _rest_frame() -> Transform3D:
	var poses: Dictionary = ViewPosesScript.set_of(_view_id)

	if _view_id == &"bow":
		return ViewPosesScript.bow_frame(poses["rest"])

	return ViewPosesScript.frame(poses["rest"])


## A quick overhand of whatever is held (the blackjack, anything swung
## without combat's help), _swing running 1 -> 0 through it: cocked, over,
## down, and back to `from`.
func _swing_frame(from: Transform3D) -> Transform3D:
	var poses: Dictionary = ViewPosesScript.set_of(_view_id)
	var sweeps: Dictionary = poses.get("sweeps", ViewPosesScript.BLACKJACK["sweeps"])
	var sweep: Dictionary = sweeps.get(&"overhead", ViewPosesScript.BLACKJACK["sweeps"][&"overhead"])
	var s := 1.0 - _swing

	if s < 0.22:
		return ViewPosesScript.blend(from, ViewPosesScript.sweep_frame(sweep, 0.0), _ease_out(s / 0.22))

	if s < 0.55:
		var u := (s - 0.22) / 0.33
		return ViewPosesScript.sweep_frame(sweep, u * u)

	return ViewPosesScript.blend(ViewPosesScript.sweep_frame(sweep, 1.0), from, _ease_in_out((s - 0.55) / 0.45))


## Where the string meets the arrow, in the bow's space: back with the draw,
## which only starts once the bow is up.
func _nock_point() -> Vector3:
	return Vector3(0.0, BOW_NOCK_Y, BOW_STRING_Z + BOW_DRAW_LENGTH * _pull())


## How far the string is drawn back, 0..1: the first of the draw raises the
## bow, the rest pulls, slowest at the end where the weight is.
func _pull() -> float:
	var t := clampf((_draw - 0.15) / 0.85, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)


## The string hand after a shot: back past your cheek and down to the quiver
## at your hip, then up again with an arrow to the string (`on_string`).
func _fetching(on_string: Transform3D) -> Transform3D:
	var quiver := Transform3D(on_string.basis.rotated(Vector3.RIGHT, 0.9), QUIVER * ViewArmsScript.SCALE)

	if _nock_t < 0.4:
		return on_string.interpolate_with(quiver, _ease_in_out(_nock_t / 0.4))

	return quiver.interpolate_with(on_string, _ease_in_out((_nock_t - 0.4) / 0.6))


## A bow's string: straight at rest, a V back to the nock as it is drawn,
## the arrow's tail on it. In the bow's own space.
func _place_string() -> void:
	var bow := _main_item != null and _main_item.has_meta(&"draw_sound")

	for strand in _strings:
		strand.visible = bow

	if not bow:
		return

	var nock := _nock_point()
	# Drawn to your chin, the string passes right by your eye: finer there, so
	# it is a line and not a beam.
	var eye: Vector3 = (_main.transform * _main_mesh.transform).affine_inverse() * Vector3.ZERO
	var fine := clampf(nock.distance_to(eye) / 0.45, 0.35, 1.0)

	# Loosed: the string shivers a moment where it was drawn from.
	if _string_shiver > 0.0:
		var hum := sin(_real_time * 95.0) * _string_shiver * _string_shiver
		nock += Vector3(0.006 * hum, 0.0, 0.014 * hum)

	for half in range(2):
		var tip := Vector3(0.0, BOW_LIMB_TIP if half == 0 else -BOW_LIMB_TIP, BOW_STRING_Z)
		var along := nock - tip
		var up := along.normalized()
		var side := up.cross(Vector3.BACK)
		side = side.normalized() if side.length() > 0.001 else Vector3.RIGHT
		_strings[half].transform = Transform3D(Basis(side * fine, along, side.cross(up) * fine), tip + along * 0.5)

	var on_string := Transform3D(Basis.IDENTITY, nock + Vector3(-0.012, 0.0, -ARROW_TAIL))
	_nocked.transform = on_string

	# The next arrow, up from the quiver in the string hand: from pointing
	# up out of it, round onto the string.
	if _nock_t < 1.0 and _nock_t >= 0.4:
		var t := _ease_in_out((_nock_t - 0.4) / 0.6)
		var to_bow := (_main.transform * _main_mesh.transform).affine_inverse()
		var fist: Vector3 = to_bow * (global_transform.affine_inverse() * _arms.hand_position(1)) if _arms != null else nock
		var raised := Transform3D(Basis(Vector3.RIGHT, -1.2), fist + Vector3(0.0, ARROW_TAIL * 0.8, 0.0))
		_nocked.transform = raised.interpolate_with(on_string, t)


## The hand holding `item` (this node's space) the way `grip` says, as if the
## item were at the arms' own scale.
func _held_by(item: Transform3D, grip: Transform3D) -> Transform3D:
	var at_scale := Transform3D(item.basis.orthonormalized().scaled(Vector3.ONE * ViewArmsScript.SCALE), item.origin)
	return at_scale * grip.affine_inverse()


## A hand on a ledge, in the palm's frame (fingers -Z, back of the hand +Y):
## the hand bone's axes, right then left.
const _LEDGE_RIGHT := Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0))
const _LEDGE_LEFT := Basis(Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0))
## The foot in the boot's frame (toe -Z, sole down): toe along +Y, +Z the sole.
const _KICK_FOOT := Basis(Vector3(-1, 0, 0), Vector3(0, -0.3, -0.954), Vector3(0, -0.954, 0.3))


## Returns world hand positions whose grip weight exceeds 0.5; [] without arms.
func grip_points() -> Array[Vector3]:
	var points: Array[Vector3] = []

	if _arms == null:
		return points

	for side in range(2):
		if _grip_weights[side] > 0.5:
			points.append(_arms.hand_position(side))

	return points


## How firmly the hands hold on to the world right now, 0..1.
func gripping() -> float:
	return _gripping


## Returns contact angle below view in radians, or 0 when suppressed/unavailable.
func grip_below(view: Transform3D) -> float:
	return _contacts.below(view) if _contacts != null and not _suppressed_for_grips() else 0.0


## Where a world transform sits relative to the off hand's rest pose.
func _to_off_space(world: Transform3D) -> Vector3:
	var camera_local := global_transform.affine_inverse() * world.origin
	return camera_local - off_rest


# Helpers

func _viewmodel_instance() -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.layers = VIEWMODEL_LAYER
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## The mesh's own look, drawn over the world instead of into it.
func _viewmodel_material(mesh: Mesh) -> Material:
	var source: Material = null

	if mesh is PrimitiveMesh:
		source = (mesh as PrimitiveMesh).material
	elif mesh != null and mesh.get_surface_count() > 0:
		source = mesh.surface_get_material(0)

	var material: StandardMaterial3D

	if source is StandardMaterial3D:
		material = (source as StandardMaterial3D).duplicate()
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = Color(0.6, 0.6, 0.6)

	_squeeze(material)
	return material


## In front of the world, in order among the rest of the view's things.
static func _squeeze(material: BaseMaterial3D) -> void:
	# Solid-looking alpha draws after SSR/screen copies. Write depth in that
	# later pass so fingers and grips still occlude each other correctly.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	material.no_depth_test = false
	material.use_z_clip_scale = true
	material.z_clip_scale = ViewArmsScript.Z_CLIP
	material.render_priority = 10


## Every surface drawn over the world, each with its own look.
func _apply_materials(instance: MeshInstance3D, mesh: Mesh) -> void:
	instance.material_override = null

	if mesh == null:
		return

	if mesh is PrimitiveMesh or mesh.get_surface_count() <= 1:
		instance.material_override = _viewmodel_material(mesh)
		return

	for i in range(mesh.get_surface_count()):
		var source := mesh.surface_get_material(i)
		var material: StandardMaterial3D = (source as StandardMaterial3D).duplicate() if source is StandardMaterial3D else StandardMaterial3D.new()
		_squeeze(material)
		instance.set_surface_override_material(i, material)


func _fit_scale(mesh: Mesh) -> float:
	if mesh == null:
		return 1.0

	if mesh.has_meta(&"hold_scale"):
		return float(mesh.get_meta(&"hold_scale"))

	var size := mesh.get_aabb().size
	var longest := maxf(maxf(size.x, size.y), maxf(size.z, 0.001))
	return clampf(item_length / longest, 0.3, 1.2)


func _ease_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c)


func _ease_in_out(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
