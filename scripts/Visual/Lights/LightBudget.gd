extends Node
## How many lights may draw shadows at once: the SHADOWS nearest the camera
## of those made to cast them (Torch.shadows). One of these lives in each
## level, made when the first such light is lit (as Fx.gd).
##
## A light only switches while it stands further from the camera than both
## NEAR and its own reach + 1 m: no shadow ever pops up close to you, and a
## light that is switched cannot be touching you, so the lightgem reads what
## it always did. The guards' light arithmetic (LightProbe) goes by what a
## light is made to do (its "casts_shadow" meta), never by what is drawn.
##
## More than SHADOWS shadow lights within NEAR of one spot is over budget:
## it warns once a level, and the level should be laid out otherwise.

const SHADOWS := 6
const NEAR := 12.0
const EVERY := 0.25

## Over budget somewhere in this level (warned once).
static var warned := false

static var _world: Node = null

var _burners: Array = []
var _clock := 0.0


static func register(burner: Node3D) -> void:
	var world := _world_for(burner)

	if world != null and not world._burners.has(burner):
		world._burners.append(burner)


static func unregister(burner: Node3D) -> void:
	if _world != null and is_instance_valid(_world):
		_world._burners.erase(burner)


## How many registered lights draw shadows now.
static func shadowed() -> int:
	if _world == null or not is_instance_valid(_world):
		return 0

	var count := 0

	for burner in _world._burners:
		if is_instance_valid(burner) and burner.light != null and burner.light.shadow_enabled:
			count += 1

	return count


static func _world_for(context: Node) -> Node:
	if context == null or not context.is_inside_tree():
		return null

	var carried: Array = []

	if _world != null and is_instance_valid(_world) and not _world.is_queued_for_deletion():
		if _world.is_inside_tree() or _joining(_world):
			return _world

		# Its level went before it could join it: start again, keeping the
		# lights it was told of.
		carried = _world._burners
		_world.free()

	var tree := context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var world: Node = (load("res://scripts/Visual/Lights/LightBudget.gd") as GDScript).new()
	world.name = "LightBudget"
	world._burners = carried
	world.set_meta(&"joining", parent.get_instance_id())
	_world = world
	warned = false
	parent.add_child.call_deferred(world)
	return world


## Whether a manager not yet in the tree still has a level to join.
static func _joining(world: Node) -> bool:
	var parent := instance_from_id(int(world.get_meta(&"joining", 0)))
	return parent is Node and not (parent as Node).is_queued_for_deletion()


func _exit_tree() -> void:
	if _world == self:
		_world = null


func _process(delta: float) -> void:
	_clock += delta

	if _clock < EVERY:
		return

	_clock = 0.0
	_decide()


func _decide() -> void:
	_burners = _burners.filter(func(b): return is_instance_valid(b) and b.is_inside_tree())
	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return

	var eye := camera.global_position
	var lit := _burners.filter(func(b): return b.shadows and b.is_lit() and b.light != null)
	lit.sort_custom(func(a, b): return eye.distance_squared_to(a.global_position) < eye.distance_squared_to(b.global_position))
	var crowded := 0

	for i in lit.size():
		var burner: Node3D = lit[i]
		var distance := eye.distance_to(burner.global_position)

		if distance < NEAR:
			crowded += 1

		var wanted := i < SHADOWS

		if burner.light.shadow_enabled != wanted and distance > maxf(NEAR, burner.light_range + 1.0):
			burner.light.shadow_enabled = wanted

	if crowded > SHADOWS and not warned:
		warned = true
		push_warning("LightBudget: %d shadow-casting lights within %.0f m of %s (at most %d draw shadows)" % [crowded, NEAR, eye, SHADOWS])
