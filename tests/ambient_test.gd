extends Node3D
## The street's ambient effects and the plaza's pigeons (the scenes plan,
## Task 4), from a made-up dressing. Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/ambient_test.tscn


var results: Array[String] = []
var eye: Camera3D


func _ready() -> void:
	eye = Camera3D.new()
	add_child(eye)
	eye.make_current()
	eye.global_position = Vector3(0, 1.7, 0)
	await _run()

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _run() -> void:
	# A1 near runs, far does not.
	var ambient := Ambient.build([{"effect": "steam", "at": [10, 0, 0]}, {"effect": "steam", "at": [80, 0, 0]}])
	add_child(ambient)
	ambient.step(0.3)
	_check("A1 an emitter 10 m off runs, one 80 m off does not", ambient.running() == [0], "%s" % [ambient.running()])
	ambient.free()

	# A2 a hundred near: the nearest forty run.
	var many := []

	for k in 100:
		many.append({"effect": "copal", "at": [cos(k * 0.7) * (5.0 + k * 0.25), 0, sin(k * 0.7) * (5.0 + k * 0.25)]})

	ambient = Ambient.build(many)
	add_child(ambient)
	ambient.step(0.3)
	var on := ambient.running()
	var far_on := 0.0
	var near_off := INF

	for k in 100:
		var d := Vector3(many[k]["at"][0], 0, many[k]["at"][2]).distance_to(Vector3(0, 0, 0))

		if k in on:
			far_on = maxf(far_on, d)
		else:
			near_off = minf(near_off, d)

	_check("A2 at most forty run, the nearest", on.size() == Ambient.ACTIVE and far_on <= near_off,
		"%d running, farthest on %.1f, nearest off %.1f" % [on.size(), far_on, near_off])
	ambient.free()

	# A3 a night emitter is still by day.
	ambient = Ambient.build([{"effect": "embers", "at": [5, 0, 0], "when": "night"}])
	add_child(ambient)
	ambient.set_day(true)
	ambient.step(0.3)
	var by_day := ambient.running().size()
	ambient.set_day(false)
	ambient.step(0.3)
	_check("A3 a night emitter is still by day and runs at night", by_day == 0 and ambient.running() == [0],
		"day %d, night %s" % [by_day, ambient.running()])
	ambient.free()

	# A4 copal smokes pale; mist keeps low (its system's configuration:
	# GPU particles are not read back, the plan's Ruling 2).
	ambient = Ambient.build([{"effect": "copal", "at": [3, 0, 0]}, {"effect": "mist", "at": [-3, 0, 0]}])
	add_child(ambient)
	ambient.step(0.3)
	var copal: GPUParticles3D = _particles(ambient.system(0))
	var mist: GPUParticles3D = _particles(ambient.system(1))
	var pale: bool = copal != null and Vfx.tint(copal).is_equal_approx(Color("ECE6DA")) and copal.emitting
	var low: bool = mist != null and (mist.process_material as ParticleProcessMaterial).emission_box_extents.y <= 0.3 \
		and (mist.process_material as ParticleProcessMaterial).initial_velocity_max <= 0.4
	_check("A4 copal smokes pale, mist keeps low", pale and low, "copal %s, mist %s" % [copal, mist])
	ambient.free()

	# A5 the pigeons lift when someone comes close, and settle after.
	var watcher := Node3D.new()
	add_child(watcher)
	watcher.global_position = Vector3(30, 0, 0)
	var pigeons := Pigeons.build([{"at": [0, 0, 0], "count": 12, "radius": 2.5}], QuadMesh.new())
	pigeons.watcher = watcher
	add_child(pigeons)

	for k in 30:
		pigeons.step(0.1)

	var settled := not pigeons.flying(0)
	watcher.global_position = Vector3(3, 0, 0)

	for k in 10:
		pigeons.step(0.1)

	var lifted := pigeons.flying(0)
	watcher.global_position = Vector3(30, 0, 0)

	for k in 90:
		pigeons.step(0.1)

	_check("A5 a flock lifts when someone comes 3 m off and settles 8 s after", settled and lifted and not pigeons.flying(0),
		"settled %s, lifted %s, after %s" % [settled, lifted, pigeons.flying(0)])
	pigeons.free()

	# A6 petals, leaves and dust: their systems emit and draw.
	ambient = Ambient.build([{"effect": "petals", "at": [2, 0, 2]}, {"effect": "leaves", "at": [-2, 6, 2], "floor": 0.0},
		{"effect": "dust", "at": [0, 0, 3]}])
	add_child(ambient)
	ambient.step(0.3)
	var drawn := {}

	for k in 3:
		var p: GPUParticles3D = _particles(ambient.system(k))
		drawn[k] = p != null and p.emitting and p.draw_pass_1 != null

	_check("A6 petals, leaves and dust emit and draw", drawn.values().all(func(v): return v), "%s" % [drawn])
	ambient.free()

	# A7 every preset builds its system
	var built := {}

	for effect in Vfx.PRESETS:
		var node: Node3D = Vfx.system(effect)
		built[effect] = node != null and node.get_child_count() > 0
		if node:
			node.free()

	_check("A7 every effect builds its system", built.values().all(func(v): return v) and built.size() >= 12, "%s" % [built])

	# A8 thinner with distance
	ambient = Ambient.build([{"effect": "steam", "at": [10, 0, 0]}, {"effect": "steam", "at": [40, 0, 0]}])
	add_child(ambient)
	ambient.step(0.3)
	var near_ratio: float = _particles(ambient.system(0)).amount_ratio
	var far_ratio: float = _particles(ambient.system(1)).amount_ratio
	_check("A8 a system 40 m off runs thinner than one 10 m off", is_equal_approx(near_ratio, 1.0) and far_ratio < 0.7,
		"10 m %.2f, 40 m %.2f" % [near_ratio, far_ratio])
	ambient.free()

	# A9 day stops a night system without freeing it
	ambient = Ambient.build([{"effect": "embers", "at": [5, 0, 0], "when": "night"}])
	add_child(ambient)
	ambient.set_day(false)
	ambient.step(0.3)
	var lit: bool = _particles(ambient.system(0)).emitting
	ambient.set_day(true)
	ambient.step(0.3)
	var kept := ambient.system(0) != null and is_instance_valid(ambient.system(0))
	_check("A9 day stops a night system emitting, kept to start again", lit and kept and not _particles(ambient.system(0)).emitting,
		"night %s, kept %s" % [lit, kept])
	ambient.free()

	# A11 a brazier: flames, colliding embers that spark, haze, a light
	var brazier: Node3D = Vfx.system("brazier")
	add_child(brazier)
	var flames: Array = brazier.find_children("flames*", "MeshInstance3D", true, false)
	var embers: GPUParticles3D = brazier.find_child("embers", true, false)
	var haze: Array = brazier.find_children("haze*", "MeshInstance3D", true, false)
	var light: Array = brazier.find_children("*", "OmniLight3D", true, false)
	var collides: bool = embers != null and (embers.process_material as ParticleProcessMaterial).collision_mode \
		!= ParticleProcessMaterial.COLLISION_DISABLED
	var sparks: bool = embers != null and not embers.sub_emitter.is_empty() \
		and (embers.process_material as ParticleProcessMaterial).sub_emitter_mode == ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	_check("A11 a brazier: flames, trailed embers that bounce and spark, haze, a light",
		flames.size() >= 1 and collides and sparks and embers.trail_enabled and haze.size() == 1 and light.size() == 1,
		"flames %d, embers %s (collide %s, spark %s), haze %d, lights %d" % [flames.size(), embers, collides, sparks, haze.size(), light.size()])

	# A12 the flame and its light flicker from one noise
	await _frames(3)
	var f: float = brazier.flicker
	var flame_uniform: float = (flames[0] as MeshInstance3D).get_surface_override_material(0).get_shader_parameter(&"flicker") \
		if flames.size() > 0 and (flames[0] as MeshInstance3D).get_surface_override_material(0) else -1.0
	_check("A12 the flames and the brazier's light flicker together", is_equal_approx(flame_uniform, f)
		and is_equal_approx((light[0] as OmniLight3D).light_energy, Vfx.BRAZIER_ENERGY * f),
		"flicker %.3f, flame %.3f, light %.3f" % [f, flame_uniform, (light[0] as OmniLight3D).light_energy])
	brazier.free()

	# A13 candles: one MultiMesh of flames, one light
	var candles: Node3D = Vfx.system("candles")
	add_child(candles)
	var multis: Array = candles.find_children("*", "MultiMeshInstance3D", true, false)
	var count: int = (multis[0] as MultiMeshInstance3D).multimesh.instance_count if multis.size() == 1 else 0
	_check("A13 candles: one MultiMesh of five to nine flames, one light", multis.size() == 1 and count >= 5 and count <= 9
		and candles.find_children("*", "OmniLight3D", true, false).size() == 1, "%d multimeshes, %d flames" % [multis.size(), count])
	candles.free()

	# A13a copal's stem is a thread of smoke, its noise in metres (in the
	# quad's UVs on a tall quad it stretched into white drips)
	var censer: Node3D = Vfx.system("copal")
	add_child(censer)
	var stem: MeshInstance3D = censer.get_node("stem")
	var extent: Vector3 = stem.mesh.get_aabb().size
	var sized: Variant = stem.get_surface_override_material(0).get_shader_parameter(&"size")
	_check("A13a copal's stem samples its noise in metres", sized is Vector2 and sized.is_equal_approx(Vector2(maxf(extent.x, extent.z), extent.y)),
		"stem %s, its shader's size %s" % [extent, sized])
	censer.free()

	# A13b a brazier's embers streak short (a long trail drew a stick of
	# light), its flames stand a metre over the coals
	var fire: Node3D = Vfx.system("brazier")
	add_child(fire)
	var trailed: GPUParticles3D = fire.get_node("embers")
	var streak: float = trailed.trail_lifetime * (trailed.process_material as ParticleProcessMaterial).initial_velocity_max
	var tall: float = (fire.get_node("flames") as MeshInstance3D).mesh.get_aabb().size.y
	_check("A13b embers streak at most 15 cm; flames a metre tall", streak <= 0.15 and tall >= 0.95,
		"streak %.2f m, flames %.2f m" % [streak, tall])
	# A13e the flames rise from inside the coals: their faded foot (12 cm)
	# sunk below the effect's spot, the heap's top (it hung in the air)
	var sunk: float = -(fire.get_node("flames") as MeshInstance3D).position.y
	_check("A13e the flames' faded foot sits in the coals", sunk >= 0.1, "sunk %.2f m" % sunk)
	fire.free()

	# A13d smoke drifts on the wind at most at its own pace (the wind adds
	# to its gravity; uncapped, its oldest puffs sped off and the column
	# broke into a string of balls)
	var capped := []

	for effect in ["copal", "steam", "smoke"]:
		var puffs: Node3D = Vfx.system(effect)
		var limit: CurveTexture = _particles(puffs).process_material.velocity_limit_curve
		capped.append(limit != null and limit.curve.sample(0.5) <= 1.2)
		puffs.free()

	_check("A13d copal, steam and smoke drift no faster than 1.2 m/s on the wind", capped.all(func(c): return c), str(capped))

	# A13f the wind carries a brazier's smoke (its sparks, a sub-emitter
	# with no wind of their own, stopped the blowing short of the smoke)
	var burning: Node3D = Vfx.system("brazier")
	add_child(burning)
	var smoke_puffs: GPUParticles3D = burning.get_children().filter(
		func(c): return c is GPUParticles3D and c.draw_pass_1.material is ShaderMaterial)[0]
	var calm: Vector3 = smoke_puffs.process_material.gravity
	Vfx.blow(burning, Vector3(4, 0, 0))
	_check("A13f the wind carries a brazier's smoke past its sparks", smoke_puffs.process_material.gravity.x > calm.x + 0.5,
		"calm %s, blown %s" % [calm, smoke_puffs.process_material.gravity])
	burning.free()

	# A13c each of the flame's three heat bands its own warm colour, none
	# near black (the ramp's stops sat just past the bands: the outer band
	# took the ember's black)
	var heat: Gradient = Vfx.ramp().gradient
	var shades: Array = [1.0 / 3.0, 2.0 / 3.0, 1.0].map(func(b): return heat.sample(b))
	_check("A13c the flame's three bands: three warm colours, none near black", shades[0].get_luminance() > 0.25
		and shades[0] != shades[1] and shades[1] != shades[2] and shades.all(func(c): return c.r > c.b), str(shades))

	# A14 the seeped mist: a fog volume, its own fog shader, glowing the
	# seeped's phosphor green
	var seeped: Node3D = Vfx.system("mist")
	add_child(seeped)
	var volumes: Array = seeped.find_children("*", "FogVolume", true, false)
	var mist_look: ShaderMaterial = volumes[0].material if volumes.size() == 1 and volumes[0].material is ShaderMaterial else null
	_check("A14 the seeped mist is a fog volume in phosphor green", mist_look != null
		and mist_look.shader.resource_path == "res://scripts/Visual/vfx_mist.gdshader"
		and Color(mist_look.get_shader_parameter(&"colour")).is_equal_approx(Color("7FD36A")),
		"%d volumes, %s" % [volumes.size(), mist_look.shader.resource_path if mist_look else "no shader"])
	seeped.free()

	# A15 fog volumes are costly: of twenty near, the nearest eight show
	var foggy: Array = []

	for k in 20:
		foggy.append({"effect": "canal_fog", "at": [2.0 + 2.0 * k, 0, 0]})

	ambient = Ambient.build(foggy)
	add_child(ambient)
	ambient.step(0.3)
	var shown: Array = []

	for i in 20:
		var node := ambient.system(i)

		if node != null and node.find_children("*", "FogVolume", true, false).any(func(v): return v.visible):
			shown.append(i)

	_check("A15 of twenty fog volumes near, the nearest eight show", shown == range(8), str(shown))
	ambient.free()

	# A16 dust motes show only in their lamp's cone (the lamp above them)
	var motes: Node3D = Vfx.system("dust")
	add_child(motes)
	var mote_look: Material = (_particles(motes).draw_pass_1 as Mesh).surface_get_material(0)
	_check("A16 dust shows in its lamp's cone", mote_look is ShaderMaterial
		and Vector3(mote_look.get_shader_parameter(&"cone_axis")).is_equal_approx(Vector3.DOWN)
		and float(mote_look.get_shader_parameter(&"cone_angle")) > 0.2,
		str(mote_look.get_shader_parameter(&"cone_angle")) if mote_look is ShaderMaterial else "no shader")
	motes.free()

	# A16b the lamps light the night air (shafts in the fog), the
	# stuttering ones not (they would ghost)
	var lamps_at: Array = []

	for k in 24:
		lamps_at.append({"at": [k * 7.0, 5.0, k * 3.0], "colour": "#e8d8a8", "range": 12.0})

	var kit := KitLoader.build({"pieces": [], "colliders": [], "lights": lamps_at})
	add_child(kit)
	kit.set_day(false)
	var lit_steady: Array = kit.lights.filter(func(l): return not kit.stuttering.has(l))
	_check("A16b at night the lamps light the fog, the stuttering ones not", kit.stuttering.size() > 0
		and lit_steady.all(func(l): return is_equal_approx(l.light_volumetric_fog_energy, 1.5))
		and kit.stuttering.all(func(l): return l.light_volumetric_fog_energy == 0.0),
		"%d steady, %d stuttering" % [lit_steady.size(), kit.stuttering.size()])
	kit.free()

	# B1 the god's breath: in and out, about seven seconds a breath
	var breath := Breath.new()
	add_child(breath)
	var lo := INF
	var hi := -INF
	var ups: Array[float] = []
	var last := breath.value()
	var deeps := [0]
	breath.deep_exhale.connect(func(): deeps[0] += 1)

	for k in 700:
		breath.step(0.1)
		var v := breath.value()
		lo = minf(lo, v)
		hi = maxf(hi, v)

		if last < 0.0 and v >= 0.0:
			ups.append((k + 1) * 0.1)

		last = v

	var periods: Array[float] = []

	for k in range(1, ups.size()):
		periods.append(ups[k] - ups[k - 1])

	var steady := periods.size() >= 8 and periods.all(func(p): return absf(p - Breath.PERIOD) <= 0.5)
	_check("B1 the god breathes in and out, about seven seconds a breath", lo <= -0.99 and hi >= 0.99 and steady,
		"%.2f..%.2f, periods %s" % [lo, hi, periods])
	_check("B2 every fourth breath is a deep one, its exhale signalled", deeps[0] == 2, "%d deep exhales in 70 s" % deeps[0])
	breath.free()


## A system's first particles node.
func _particles(node: Node) -> GPUParticles3D:
	if node == null:
		return null

	if node is GPUParticles3D:
		return node

	var found := node.find_children("*", "GPUParticles3D", true, false)
	return found[0] if not found.is_empty() else null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
