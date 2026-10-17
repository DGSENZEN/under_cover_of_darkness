extends Node3D
## Throwaway trace: sprint + forward up gym station 17, frame by frame, to
## see where the free-run flow stops and starts.

const GYM := preload("res://maps/traversal_gym.tscn")


func _ready() -> void:
	var gym = GYM.instantiate()
	add_child(gym)
	await _frames(6)
	var p = get_tree().get_first_node_in_group("player")
	p.inventory.select_by_id(&"")
	gym.select_station(16)
	var origin: Vector3 = gym.stations[16].root.position
	await _frames(4)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	var last: Vector3 = p.global_position
	var rows := []
	for i in 900:
		await _frames(1)
		var pos: Vector3 = p.global_position
		var speed: float = pos.distance_to(last) * 60.0
		last = pos
		var label: String = String(p.current_move.label) if p.current_move != null else "-"
		var cam: Basis = p.camera.global_basis
		rows.append("%d,%d,%s,%.3f,%.3f,%.3f,%.2f,%.2f,%.2f" % [i, p.movement_state, label, pos.y - 1.0, pos.z - origin.z, speed,
			rad_to_deg(p.neck.rotation.x), rad_to_deg(cam.get_euler().z), p.camera.fov])
		if p.movement_state == 0 and pos.z - origin.z < -24.0 and pos.y - 1.0 > 8.9:
			break
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_line("frame,state,move,feet,z,speed,pitch,roll,fov")
	for r in rows:
		f.store_line(r)
	f.close()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
