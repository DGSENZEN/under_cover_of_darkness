extends RigidBody3D
## A part of a man cut away from him (Humanoid.sever): a head, an arm, a leg.
## It flies off the blade bleeding, tumbles, and lies where it lands: a thing
## like any other to pick up and throw, and a guard who sees one lying in the
## light knows what happened here (it is one of the "bodies").
##
## Drawn by a copy of his skeleton, posed as he was the instant it was cut,
## with everything but the part itself shrunk to nothing.

const Fx := preload("res://scripts/Visual/Fx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")

## The bodies' physics layer (GuardBody.LAYER): it rests on the world and on
## other bodies, and you walk over it.
const LAYER := 4
## How many lie about at once; the oldest goes when another is cut.
const MAX_PARTS := 24
## Seconds it drips from the cut.
const BLEEDS_FOR := 6.0

static var _all: Array = []

var dead := true
var discovered := false
## Which part it is (Humanoid.SEVERABLE).
var part: StringName = &""

var _last_speed := 0.0
var _thuds := 0
## It bleeds a while from the cut: drops where it rolls, a pool where it
## comes to rest.
var _age := 0.0
var _drip := 0.0
var _pooled := false


func _ready() -> void:
	add_to_group(&"bodies")
	collision_layer = LAYER
	collision_mask = 1 | LAYER
	continuous_cd = true
	linear_damp = 0.4
	# Heavy, soft, and it does not roll far: a head is no ball.
	angular_damp = 3.5
	var grip := PhysicsMaterial.new()
	grip.friction = 1.0
	grip.rough = true
	grip.bounce = 0.05
	physics_material_override = grip
	_all.append(self)

	while _all.size() > MAX_PARTS:
		var oldest = _all.pop_front()

		if is_instance_valid(oldest):
			oldest.queue_free()


func _exit_tree() -> void:
	_all.erase(self)


func is_falling() -> bool:
	return not sleeping and linear_velocity.length() > 0.3


func _physics_process(delta: float) -> void:
	_age += delta

	if _age < BLEEDS_FOR:
		_drip -= delta

		if _drip <= 0.0:
			_drip = lerpf(0.1, 0.55, _age / BLEEDS_FOR)
			var cut := get_node_or_null("Skeleton3D/Cut") as Node3D
			Fx.drip(self, cut.global_position if cut != null else global_position, 0.12)

	if not _pooled and _age > 0.8 and linear_velocity.length() < 0.1:
		_pooled = true
		Fx.pool(self, global_position, 0.5 if part == &"neck_01" else 0.4, 4.5)

	# Landing: a wet thud, the first times it comes down hard.
	var speed := linear_velocity.length()

	if _last_speed > 3.0 and speed < _last_speed * 0.5 and _thuds < 2:
		_thuds += 1
		Sfx.play(self, &"flesh_heavy", global_position, -6.0 if _thuds == 1 else -12.0, 0.9)
		Fx.blood(self, global_position, Vector3.UP, 0.25)

	_last_speed = speed
