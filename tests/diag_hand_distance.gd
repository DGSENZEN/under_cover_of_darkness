extends Node3D
## Diagnostic: where each hand is drawn from the eye (camera space, metres,
## and its distance), standing empty-handed, holding the sword, and hanging
## on a sill (with the eye's distance from the wall).
const PLAYER := preload("res://Player.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")
const PROPS := preload("res://scripts/Interaction/Props.gd")
var player

func _ready() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(60, 1, 40))
	player = PLAYER.instantiate()
	add_child(player)
	player.debug_traversal = false
	player.invulnerable = true
	await _frames(30)
	_report("empty")
	PROPS.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	await _frames(90)
	_report("sword")
	player.inventory.select_by_id(&"")
	await _frames(60)
	_box(Vector3(10, 4.5, -4.5), Vector3(4, 9, 3))
	var sill: Node3D = HANDHOLD.new()
	sill.kind = HANDHOLD.Kind.LEDGE
	sill.length = 1.0
	add_child(sill)
	sill.global_position = Vector3(10, 2.4, -3)
	await _frames(2)
	var anchor: Vector3 = player.planner.hang_anchor(sill.global_position, Vector3.BACK, 2.4)
	player.teleport(Transform3D(Basis.IDENTITY, anchor))
	player.global_position = anchor
	player._enter_hang(Vector3.BACK, 2.4, false, &"", sill)
	await _frames(40)
	_report("hang")
	print("BODY radius %.3f gap %.3f, body %.3f m from the wall, camera offset %s (body space)" % [player.scanner.radius, player.planner.hang_gap, player.global_position.z - (-3.0), (player.global_transform.affine_inverse() * player.camera.global_position).snapped(Vector3.ONE * 0.001)])
	print("WALL eye %.3f m from the wall, %.3f m below the lip" % [player.camera.global_position.z - (-3.0), 2.4 - player.camera.global_position.y])
	get_tree().quit()

func _report(label: String) -> void:
	var arms = player.hand._arms
	var inv: Transform3D = player.camera.global_transform.affine_inverse()
	var line := "%-6s" % label
	for side in [0, 1]:
		var at: Vector3 = inv * arms.hand_position(side)
		line += " | %s %s %.2f m w%.1f" % ["L" if side == 0 else "R", at.snapped(Vector3.ONE * 0.01), at.length(), arms.reach.weights[side]]
	print("HANDS ", line, " scale %.2f" % arms.scale.x)

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
