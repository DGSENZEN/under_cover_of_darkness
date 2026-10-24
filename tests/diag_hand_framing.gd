extends Node3D
## Diagnostic: how the hands sit on screen against the references (Dishonored
## 2 standing, Dying Light hanging): each hand's width as a share of the
## frame's, and where its middle is (0..1 across, 0..1 down).
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
	print("FOV ", player.camera.fov)
	get_tree().quit()

func _report(label: String) -> void:
	var arms = player.hand._arms
	var cam: Camera3D = player.camera
	var size: Vector2 = get_viewport().get_visible_rect().size
	var line := "%-6s" % label
	for side in [0, 1]:
		var pts: PackedVector3Array = arms.reach.solved_hand_points[side]
		if pts.is_empty():
			line += " | %s -" % ("L" if side == 0 else "R")
			continue
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in pts:
			var s: Vector2 = cam.unproject_position(p)
			lo = lo.min(s)
			hi = hi.max(s)
		var mid := (lo + hi) * 0.5 / size
		line += " | %s width %.0f%% at (%.2f, %.2f)" % ["L" if side == 0 else "R", (hi.x - lo.x) / size.x * 100.0, mid.x, mid.y]
	print("FRAME ", line)

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
