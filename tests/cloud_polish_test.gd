extends Node3D
## Regression: a cloud moves across the moon with an irregular body, and
## moonlight follows the visible area of the disc rather than its centre.
const NightScript := preload("res://scripts/Night/Night.gd")
var results: Array[String] = []

func _ready() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_energy = 0.4
	add_child(moon)
	moon.global_basis = Basis.looking_at(Vector3(0.6, -0.5, 0.6).normalized(), Vector3.UP)
	var night := NightScript.new()
	night.seed = 17
	night.moon = moon
	add_child(night)
	night.set_process(false)
	var natural_field: Image = night._field
	var control := NightScript.new()
	control.seed = 17
	control.moon = moon
	add_child(control)
	control.set_process(false)
	night.to(&"cloudy", 0.0)
	control.to(&"cloudy", 0.0)
	var anchor: Vector2 = night.sky_uv(night.moon_direction())
	var initial := []
	for y in range(-4, 5):
		for x in range(-4, 5):
			var uv := anchor + Vector2(x, y) * 0.065
			initial.append(night.density_at(_direction(night, uv)))
	night.cover_moon(16.0)
	var cue_difference := 0.0
	var tracking_difference := 0.0
	var largest_speed := 0.0
	for second in 15:
		var offset: Vector2 = night._offset
		night._process(1.0)
		control._process(1.0)
		largest_speed = maxf(largest_speed, (night._offset as Vector2).distance_to(offset))
		var index := 0
		for y in range(-4, 5):
			for x in range(-4, 5):
				var uv := anchor + Vector2(x, y) * 0.065
				var tracked := _direction(night, uv)
				tracking_difference = maxf(tracking_difference, absf(night.density_at(tracked) - float(initial[index])))
				var view := _direction(control, uv)
				cue_difference = maxf(cue_difference, absf(night.density_at(view) - control.density_at(view)))
				index += 1
	_check("C1 a story cue cannot spawn a moon-targeted cloud", cue_difference < 0.0001, "maximum added opacity %.4f" % cue_difference)
	_check("C2 all cloud features follow the same slow weather advection", tracking_difference < 0.0001 and largest_speed > 0.001 and largest_speed < 0.004,
		"tracked opacity change %.4f, speed %.5f UV/s" % [tracking_difference, largest_speed])
	control.queue_free()

	# A sharp field boundary covers part of the disc while its centre is clear.
	# This fixture has no weather-dependent random movement.
	night.cover_moon(0.0)
	night._process(5.0)
	var field := Image.create(256, 256, false, Image.FORMAT_L8)
	field.fill(Color.BLACK)
	for y in 256:
		for x in range(128, 256):
			field.set_pixel(x, y, Color.WHITE)
	night._field = field
	night._now["cover"] = 0.5
	var dir: Vector3 = moon.global_basis.z.normalized()
	night._offset = Vector2.ZERO
	night._offset = Vector2(0.494, 0.5) - night.sky_uv(dir)
	var centre_cover: float = night.density_at(dir)
	var mean := _disc_density(night, dir)
	night._apply(night.wind())
	_check("C3 moonlight follows the covered area of the disc", mean > centre_cover + 0.1 and absf(night.cloud_cover() - mean) < 0.06 and absf(night.moon_share() - (1.0 - 0.85 * mean)) < 0.06,
		"centre %.3f, disc %.3f, light %.3f" % [centre_cover, mean, night.moon_share()])

	var public_source := night.has_method("moon_direction") and night.has_method("moon_visibility")
	var pure := false
	if public_source:
		var before: float = night.moon_visibility()
		night.flash()
		night._apply(night.wind())
		pure = absf(before - night.moon_visibility()) < 0.00001 and absf(before - (1.0 - mean)) < 0.06 and night.moon_share() > 1.0 and (night.moon_direction() as Vector3).distance_to(dir) < 0.0001
	_check("C4 the public moon source reports disc visibility independently of lightning", public_source and pure, "public %s, pure %s" % [public_source, pure])

	var before_release: Vector2 = night._offset
	var before_cover: float = night.density_at(dir)
	night.cover_moon(90.0)
	night.cover_moon(120.0)
	night.cover_moon(0.0)
	_check("C5 requesting, extending and releasing a crossing never teleports or fades the field", before_release == night._offset and absf(before_cover - night.density_at(dir)) < 0.00001,
		"opacity %.4f -> %.4f" % [before_cover, night.density_at(dir)])
	night._field = natural_field
	night.to(&"clear", 0.0)
	night._offset = Vector2.ZERO
	var least := 1.0
	var most := 0.0
	var partial_seconds := 0
	for second in 1200:
		# Follow an existing field through twenty calm minutes, independently
		# of any obsolete scripted crossing scheduler.
		var air: Vector3 = night.wind()
		night._offset -= Vector2(air.x, air.z) * 0.0025
		var cover: float = night.cloud_cover()
		least = minf(least, cover)
		most = maxf(most, cover)
		if cover > 0.1 and cover < 0.9:
			partial_seconds += 1
	_check("C6 sparse clear-weather clouds can naturally clear, partially cover and obscure the moon", least < 0.01 and most > 0.99 and partial_seconds > 10,
		"coverage %.3f..%.3f, partial %d s" % [least, most, partial_seconds])

	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit()

func _direction(night: Node, uv: Vector2) -> Vector3:
	var flat := (uv - (night._offset as Vector2)) / 0.35
	var r2 := flat.length_squared()
	var y := (-r2 * 0.25 + sqrt(1.0 + r2 * (1.0 - 0.25 * 0.25))) / (1.0 + r2)
	return Vector3(flat.x * (y + 0.25), y, flat.y * (y + 0.25)).normalized()

func _disc_density(night: Node, dir: Vector3) -> float:
	var right := dir.cross(Vector3.UP).normalized()
	var up := right.cross(dir)
	var total := 0.0
	var count := 0
	for y in range(-10, 11):
		for x in range(-10, 11):
			if x * x + y * y <= 100:
				total += night.density_at((dir + (right * x + up * y) * (0.0244 / 10.0)).normalized())
				count += 1
	return total / float(count)

func _check(label: String, ok: bool, detail: String) -> void:
	results.append("%s %s [%s]" % ["PASS" if ok else "FAIL", label, detail])
