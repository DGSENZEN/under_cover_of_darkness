extends Node3D
## Diagnostic: per situation, each arm's shoulder slide (stretch), whether it
## ran out of length, its wrist bend and wrist twist (degrees).
const PLAYER := preload("res://Player.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")
const PROPS := preload("res://scripts/Interaction/Props.gd")
var player

func _ready() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(120, 1, 40))
	player = PLAYER.instantiate()
	add_child(player)
	player.debug_traversal = false
	player.invulnerable = true
	await _frames(40)
	_report("rest")
	PROPS.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	await _frames(90)
	_report("sword")
	PROPS.give_revolver(player)
	player.inventory.select_by_id(&"revolver")
	await _frames(90)
	_report("revolver")
	Input.action_press("aim")
	await _frames(60)
	_report("revolver aimed")
	Input.action_release("aim")
	player.inventory.select_by_id(&"")
	await _frames(60)
	_box(Vector3(10, 4.5, -4.5), Vector3(4, 9, 3))
	var sill := _hold(HANDHOLD.Kind.LEDGE, Vector3(10, 2.4, -3), 1.0)
	await _frames(2)
	var anchor: Vector3 = player.planner.hang_anchor(sill.global_position, Vector3.BACK, 2.4)
	player.teleport(Transform3D(Basis.IDENTITY, anchor))
	player.global_position = anchor
	player._enter_hang(Vector3.BACK, 2.4, false, &"", sill)
	await _frames(40)
	_report("hang")
	Input.action_press("jump")
	for i in 14:
		await _frames(1)
	_report("pullup")
	Input.action_release("jump")
	await _frames(60)
	_box(Vector3(30, 3, -4.5), Vector3(4, 6, 3))
	_hold(HANDHOLD.Kind.POLE, Vector3(30, 0, -2.9), 6.0)
	await _frames(2)
	player.teleport(Transform3D(Basis.IDENTITY, Vector3(30, 1.03, -1.6)))
	Input.action_press("move_forward")
	for i in 90:
		await _frames(1)
	_report("pole")
	Input.action_release("move_forward")
	get_tree().quit()

func _report(label: String) -> void:
	var r = player.hand._arms.reach
	var line := "%-7s" % label
	for side in [0, 1]:
		line += " | %s w%.1f slide %.2f straight %s len %.2f bend %3.0f twist %3.0f" % ["L" if side == 0 else "R", r.weights[side], r.shoulder_slides[side], r.straight[side], r.solved_lengths[side], r.wrist_bend[side], r.wrist_twist[side]]
	print("HEALTH ", line)

func _hold(kind: int, at: Vector3, length: float) -> Node3D:
	var hold: Node3D = HANDHOLD.new()
	hold.kind = kind
	hold.length = length
	add_child(hold)
	hold.global_position = at
	return hold

func _box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = center

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
