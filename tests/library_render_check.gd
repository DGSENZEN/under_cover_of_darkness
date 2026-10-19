extends Node
## The shop's drawing cost against the underground bay's, windowed (headless draws nothing, so the bay suite's L20
## measures scripts and physics only). From three eyes in each bay, looking four ways, the median frame time
## (windowed, vsync off, so each frame waits on the GPU's drawing; this Mac's renderer reports no GPU timings) and
## the CPU render time; the shop passes at no more than 1.1 times the underground bay's frame time.
## Then the shop again with its shelf books casting shadows (as they did before Part 1's review), to show the cost.
##   Godot --path . --resolution 1600x900 res://tests/library_render_check.tscn

const SHOP := preload("res://maps/library_lab.tscn")
const UNDER := preload("res://maps/underground_lab.tscn")


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_mute(0, true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

	var shop: Node3D = SHOP.instantiate()
	add_child(shop)
	var ours: Vector2 = await _measure(shop, [Vector3(0.0, 1.7, -0.3), Vector3(0.0, 1.7, -2.6), Vector3(2.45, 1.7, -1.6)])
	for draw: MultiMeshInstance3D in shop.book_draws:
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var unshadowed: Vector2 = await _measure(shop, [Vector3(0.0, 1.7, -0.3), Vector3(0.0, 1.7, -2.6), Vector3(2.45, 1.7, -1.6)])
	shop.queue_free()
	await _frames(10)

	var under: Node3D = UNDER.instantiate()
	add_child(under)
	await _frames(5)
	var at: Vector3 = under.player.global_position + Vector3.UP * 0.65
	var theirs: Vector2 = await _measure(under, [at, at + Vector3(0.0, 0.0, -2.0), at + Vector3(2.0, 0.0, 0.0)])

	print("render: shop frame %.2f ms CPU %.2f ms; shelf books casting shadows frame %.2f ms CPU %.2f ms; underground bay frame %.2f ms CPU %.2f ms"
		% [ours.x, ours.y, unshadowed.x, unshadowed.y, theirs.x, theirs.y])
	print("%s  the shop's frames take no more than 1.1 times the underground bay's, drawn   [%.2f vs %.2f ms]"
		% ["PASS" if ours.x > 0.0 and theirs.x > 0.0 and ours.x <= 1.1 * theirs.x else "FAIL", ours.x, theirs.x])
	get_tree().quit()


## Median (frame, CPU render) time (ms) with an eye at each of `eyes`, looking four ways from each.
func _measure(bay: Node3D, eyes: Array) -> Vector2:
	if is_instance_valid(bay.get("player")):
		bay.player.queue_free()
	var eye := Camera3D.new()
	eye.fov = 75.0
	bay.add_child(eye)
	eye.make_current()
	await _frames(30)
	var gpu := []
	var cpu := []
	var vp := get_viewport().get_viewport_rid()

	for at: Vector3 in eyes:
		for k in 4:
			eye.global_transform = Transform3D(Basis(Vector3.UP, k * PI / 2.0), at)
			await _frames(20)
			var was := Time.get_ticks_usec()
			for i in 30:
				await get_tree().process_frame
				var now := Time.get_ticks_usec()
				gpu.append((now - was) / 1000.0)
				was = now
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))

	eye.queue_free()
	gpu.sort()
	cpu.sort()
	return Vector2(gpu[gpu.size() / 2], cpu[cpu.size() / 2])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
