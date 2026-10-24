extends Node3D
## Diagnostic: through a pull-up onto a top, where each arm's shoulder is
## drawn (camera space): the solved (slid) shoulder and the shoulder at rest.
const PLAYER := preload("res://Player.tscn")
const HANDHOLD := preload("res://scripts/PlayerUtils/Handhold.gd")

func _ready() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(60, 1, 40))
	_box(Vector3(0, 1.2, -4.5), Vector3(4, 2.4, 3))
	var p = PLAYER.instantiate()
	add_child(p)
	p.debug_traversal = false
	p.invulnerable = true
	var lip: Node3D = HANDHOLD.new()
	lip.kind = HANDHOLD.Kind.LEDGE
	lip.length = 1.0
	add_child(lip)
	lip.global_position = Vector3(0, 2.4, -3)
	for i in 10: await get_tree().physics_frame
	var anchor: Vector3 = p.planner.hang_anchor(lip.global_position, Vector3.BACK, 2.4)
	p.teleport(Transform3D(Basis.IDENTITY, anchor))
	p.global_position = anchor
	p._enter_hang(Vector3.BACK, 2.4, false, &"", lip)
	for i in 30: await get_tree().physics_frame
	Input.action_press("jump")
	var arms = p.hand._arms
	for i in 40:
		await get_tree().physics_frame
		if i % 3 != 0: continue
		var inv: Transform3D = p.camera.global_transform.affine_inverse()
		var sk: Skeleton3D = arms.man.skeleton
		var rest: Vector3 = inv * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"upperarm_r")).origin)
		print("%2d held %.2f pitch %.0f | solved S %s rest S %s slide %.2f" % [i, arms.held(), rad_to_deg(p.neck.rotation.x), (inv * arms.reach.solved_shoulders[1]).snapped(Vector3.ONE * 0.01), rest.snapped(Vector3.ONE * 0.01), arms.reach.shoulder_slides[1]])
	get_tree().quit()

func _box(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = center
