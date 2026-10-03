extends Node3D
## Builds sixteen movement stress stations using production traversal and collision.
## Owns resets, checkpoints, optional relay encounters and practice physics/time settings.
## See maps/MOVEMENT_GYM.md for controls, station routes and verification scenes.

const PLAYER := preload("res://Player.tscn")
const CLIMB := preload("res://scripts/PlayerUtils/ClimbVolume.gd")
const ROPE := preload("res://scripts/PlayerUtils/VerletRope.gd")

const LANE_WIDTH := 3.0

const Run := preload("res://maps/MovementGymRun.gd")
const Fixtures := preload("res://maps/MovementGymFixtures.gd")
const Props := preload("res://scripts/Interaction/Props.gd")
const GUARD := preload("res://Guard.tscn")
const Baker := preload("res://scripts/AISystem/NavBaker.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const Garrison := preload("res://scripts/AISystem/Garrison.gd")

var stations: Array[Dictionary] = []
var movers: Array[Dictionary] = []
var run := Run.new()
var selected := 0
var player: CharacterBody3D
var _fixture_root: Node3D
var _materials := {}
var _obstacle_time := 0.0
var _hud: Label
var _status: Label
var _transition := "Ready"
var _last_state := -1
var _last_move := ""
var _resets := 0
var _falls := 0
var _was_airborne := false
var _lowest_speed := 0.0
var _saved_rate := 60
var _saved_scale := 1.0
var _guard: CharacterBody3D
var _encounter: Node3D
var _baker: NavigationRegion3D
var _guard_enabled := false
var _damage_enabled := false

func _ready() -> void:
	_saved_rate = Engine.physics_ticks_per_second
	_saved_scale = TimeFx.base
	reset_physics_interpolation.call_deferred()
	_environment()
	_fixture_root = self
	_floor()
	var names := ["Steps & stairs", "Mantles", "Vault flow", "Hang & leap", "Kick & upward leap", "Progressive gaps", "Ladder, rope & chain", "Facade", "Thin lips & seams", "Corners & angled faces", "Crouched clearance", "Moving obstruction", "Slopes & momentum", "Water & landings", "Vertical relay", "Combat / stealth relay"]
	var legacy := [_lane_stairs, _lane_mantles, _lane_vaults, _lane_hang_course, _lane_kick_and_upward, _lane_gaps, _lane_ladder_and_rope, _lane_facade]
	for i in names.size():
		var root := Node3D.new()
		root.name = "Station%02d" % (i + 1)
		root.position = Vector3((i % 4) * 36.0, 0, -floori(float(i) / 4.0) * 44.0)
		add_child(root)
		_fixture_root = root
		_box(Vector3(4, -0.5, -11), Vector3(28, 1, 42), "floor")
		stations.append({"root": root, "title": names[i], "spawn": root.position + Vector3(0, 1.05, 8), "gates": [Vector3(0, 1.5, 5), Vector3(0, 1.5, -12), Vector3(0, 1.5, -30)]})
		if i < legacy.size():
			legacy[i].call(0.0)
		else:
			Fixtures.build(self, i)
		# Gates above elevated fixtures follow the intended route.
		if i == 3:
			stations[i].gates = [Vector3(0, 1.5, 5), Vector3(3.75, 4.5, -3.5), Vector3(0, 4.5, -15.5)]
		elif i == 4:
			stations[i].gates = [Vector3(0, 1.5, 5), Vector3(0, 5.2, -2.7), Vector3(0, 5.6, -12.5)]
		elif i == 5:
			stations[i].gates = [Vector3(0, 3.1, -1), Vector3(0, 3.1, -17.6), Vector3(0, 3.1, -28.1)]
		elif i == 6:
			stations[i].gates = [Vector3(0, 1.5, 5), Vector3(0, 5.5, -14.4), Vector3(0, 5.5, -23.4)]
		elif i == 7:
			stations[i].gates = [Vector3(0, 1.5, 5), Vector3(0, 5.5, -2.7), Vector3(0, 9.0, -4.5)]
		_course_gates(i)
	_fixture_root = self
	player = PLAYER.instantiate()
	player.debug_traversal = false
	player.reload_on_death = false
	player.invulnerable = true
	add_child(player)
	Props.give_weapons(player)
	player.inventory.select_by_id(&"sword")
	_build_hud()
	select_station(0)

func _exit_tree() -> void:
	Engine.physics_ticks_per_second = _saved_rate
	TimeFx.clear()
	TimeFx.set_base(_saved_scale)

# Lanes

func _lane_stairs(x: float) -> void:
	_sign(x, "STEPS & STAIRS\nwalk: 0.15, 0.25, 0.35 steps\nthen 0.2 x 0.3 and 0.3 x 0.3 stairs")

	_block(x, -3.0, 2.0, 0.15, "steel")
	_block(x, -6.0, 2.0, 0.25, "steel")
	_block(x, -9.0, 2.0, 0.35, "steel")

	_stairs(x, -12.0, 0.2, 0.3, 8, "steel")
	_block(x, -15.4, 2.0, 1.6, "steel")

	_stairs(x, -19.0, 0.3, 0.3, 6, "steel")
	_block(x, -21.8, 2.0, 1.8, "steel")


func _lane_mantles(x: float) -> void:
	_sign(x, "MANTLES\nforward + jump\n0.6 crate, 1.2 ledge, 2.0 wall\n3.0 wall: jump then hold\nlow ceiling: crouched mantle")

	_block(x, -4.0, 2.0, 0.6, "stone")
	_block(x, -9.0, 2.0, 1.2, "stone")
	_block(x, -14.0, 2.0, 2.0, "stone")
	_block(x, -19.5, 2.0, 3.0, "stone")

	_block(x, -25.5, 2.0, 1.2, "stone")
	_box(Vector3(x, 2.7, -25.5), Vector3(LANE_WIDTH, 0.2, 2.0), "stone")


func _lane_vaults(x: float) -> void:
	_sign(x, "VAULTS & FLOW\nsprint + jump\n0.9 fence, 1.0 rail\ntwo fences 3 m apart: press jump\nagain mid-vault to chain")

	_box(Vector3(x, 0.45, -4.0), Vector3(LANE_WIDTH, 0.9, 0.2), "wood")
	_box(Vector3(x, 0.5, -8.0), Vector3(LANE_WIDTH, 1.0, 0.1), "wood")
	_box(Vector3(x, 0.45, -13.0), Vector3(LANE_WIDTH, 0.9, 0.2), "wood")
	_box(Vector3(x, 0.45, -16.0), Vector3(LANE_WIDTH, 0.9, 0.2), "wood")

	# A 0.6 crate then a fence: mantle into vault.
	_block(x, -22.0, 1.0, 0.6, "wood")
	_box(Vector3(x, 0.45, -25.0), Vector3(LANE_WIDTH, 0.9, 0.2), "wood")


func _lane_hang_course(x: float) -> void:
	_sign(x, "HANG COURSE\njump + hold at the 3.6 wall\nstrafe: shimmy, gap: strafe + jump\nends: corners\nbetween the two walls: turn, look, jump\nfar wall, right end: aim past the corner\nat the side wall's ledge, jump")

	# Ledge A, ledge B across a 1.5 m gap, block C making an inside corner.
	_box(Vector3(x - 0.25, 1.8, -4.5), Vector3(2.5, 3.6, 3.0), "brick")
	_box(Vector3(x + 3.75, 1.8, -4.5), Vector3(2.5, 3.6, 3.0), "brick")
	_box(Vector3(x + 6.25, 1.8, -1.75), Vector3(2.5, 3.6, 2.5), "brick")

	# A wall facing a different way, across a 1.5 m alley past the end of the
	# second pair. Hang near the far right end, aim past the corner, jump.
	_box(Vector3(x + 9.5, 1.8, -12.1), Vector3(3.0, 3.6, 4.8), "brick")

	# Two walls facing each other, 3 m apart, for the leap across.
	_box(Vector3(x + 2.0, 1.8, -9.5), Vector3(9.0, 3.6, 3.0), "brick")
	_box(Vector3(x, 1.8, -15.5), Vector3(5.0, 3.6, 3.0), "brick")


func _lane_kick_and_upward(x: float) -> void:
	_sign(x, "KICK & UPWARD LEAP\ntall wall: jump, press jump again\nbeside it, keep holding: grab the sill\nmolding wall: hang, look up, jump")

	# Tall wall with a sill at 4.2 m.
	_box(Vector3(x, 4.0, -4.5), Vector3(LANE_WIDTH, 8.0, 3.0), "dark")
	_box(Vector3(x, 4.05, -2.7), Vector3(LANE_WIDTH, 0.3, 0.6), "dark")

	# 4.6 m wall with a molding at 3.4 m, and the roof lip 1.2 m above it.
	_box(Vector3(x, 2.3, -12.5), Vector3(LANE_WIDTH, 4.6, 3.0), "dark")
	_box(Vector3(x, 3.375, -10.85), Vector3(LANE_WIDTH, 0.25, 0.3), "dark")


func _lane_gaps(x: float) -> void:
	_sign(x, "GAPS\nup the stairs, then run and jump\n3 m: any jump\n4.6 m: assisted\n6.5 m: you will miss")

	_stairs(x, 5.0, 0.2, 0.3, 10, "moss")
	_box(Vector3(x, 1.0, -1.0), Vector3(LANE_WIDTH, 2.0, 6.0), "moss")
	_box(Vector3(x, 1.0, -9.0), Vector3(LANE_WIDTH, 2.0, 4.0), "moss")
	_box(Vector3(x, 1.0, -17.6), Vector3(LANE_WIDTH, 2.0, 4.0), "moss")
	_box(Vector3(x, 1.0, -28.1), Vector3(LANE_WIDTH, 2.0, 4.0), "moss")


func _lane_ladder_and_rope(x: float) -> void:
	_sign(x, "LADDER & ROPE\nwalk into them\nforward climbs the way you look\njump lets go\nrope: strafe swings around it")

	_box(Vector3(x, 2.5, -4.5), Vector3(LANE_WIDTH, 5.0, 3.0), "stone")
	_ladder(Vector3(x, 2.5, -2.65), 5.0)

	# A rope and a chain, each hanging from a beam, each beside a ledge.
	_box(Vector3(x, 7.15, -12.0), Vector3(LANE_WIDTH, 0.3, 0.3), "wood")
	_rope(Vector3(x, 7.0, -12.0), 6.0, ROPE.Style.ROPE)
	_box(Vector3(x, 2.25, -14.4), Vector3(LANE_WIDTH, 4.5, 3.0), "stone")

	_box(Vector3(x, 7.15, -21.0), Vector3(LANE_WIDTH, 0.3, 0.3), "wood")
	_rope(Vector3(x, 7.0, -21.0), 6.0, ROPE.Style.CHAIN)
	_box(Vector3(x, 2.25, -23.4), Vector3(LANE_WIDTH, 4.5, 3.0), "stone")


func _lane_facade(x: float) -> void:
	_sign(x, "FACADE\njump + hold at the wall: hang\nlook at the next ledge, jump\nlook down at a ledge, jump: drop to it\nclimb to the roof, then look down\nover the edge and press crouch")

	_box(Vector3(x, 4.0, -4.5), Vector3(5.0, 8.0, 3.0), "brick")
	_molding(x, 3.5)
	_molding(x + 1.1, 4.7)
	_molding(x - 0.4, 5.9)
	_molding(x + 0.9, 7.1)


# Builders

func _block(x: float, z: float, depth: float, height: float, material: String) -> void:
	_box(Vector3(x, height * 0.5, z), Vector3(LANE_WIDTH, height, depth), material)


func _stairs(x: float, z_start: float, riser: float, tread: float, count: int, material: String) -> void:
	for i in range(count):
		var top := riser * (i + 1)
		_box(
			Vector3(x, top * 0.5, z_start - tread * i - tread * 0.5),
			Vector3(LANE_WIDTH, top, tread),
			material
		)


func _box(center: Vector3, size: Vector3, material: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.set_meta(&"surface", "metal" if material == "steel" else ("wood" if material == "wood" else "stone"))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material(material)
	body.add_child(visual)
	_fixture_root.add_child(body)
	return body


func _ladder(center: Vector3, height: float) -> void:
	var volume := Area3D.new()
	volume.set_script(CLIMB)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, height, 0.7)
	shape.shape = box
	volume.add_child(shape)
	volume.position = center
	_fixture_root.add_child(volume)

	# Rungs, purely visual.
	var rungs := int(height / 0.3)

	for i in range(rungs):
		var rung := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.8, 0.04, 0.04)
		rung.mesh = mesh
		rung.material_override = _material("wood")
		rung.position = Vector3(center.x, center.y - height * 0.5 + 0.3 * (i + 1), center.z - 0.28)
		_fixture_root.add_child(rung)


func _rope(anchor: Vector3, length: float, style: int) -> void:
	var rope := Area3D.new()
	rope.set_script(ROPE)
	rope.style = style
	rope.length = length
	# Placed before it is added: it hangs its links from where it is when it
	# enters the tree.
	rope.position = anchor
	_fixture_root.add_child(rope)


## A thin ledge sticking 0.3 m out of a wall whose face is at z = -3.
func _molding(x: float, top: float) -> void:
	_box(Vector3(x, top - 0.125, -2.85), Vector3(1.2, 0.25, 0.3), "brick")


func _sign(x: float, text: String) -> void:
	var label := Label3D.new()
	label.text = "%02d  %s" % [stations.size(), text]
	label.font_size = 36
	label.pixel_size = 0.006
	label.modulate = Color(0.95, 0.9, 0.8)
	label.outline_size = 8
	label.position = Vector3(x, 3.0, 3.0)
	label.shaded = false
	_fixture_root.add_child(label)


func _floor() -> void:
	_box(Vector3(54, -0.7, -66), Vector3(156, 1, 190), "dark")


func _environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.13, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	environment.ambient_light_energy = 0.7

	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _material(name: String) -> StandardMaterial3D:
	if _materials.has(name):
		return _materials[name]

	var colors := {
		"floor": Color(0.22, 0.22, 0.24),
		"steel": Color(0.45, 0.5, 0.58),
		"stone": Color(0.55, 0.52, 0.48),
		"wood": Color(0.55, 0.38, 0.22),
		"brick": Color(0.6, 0.3, 0.25),
		"dark": Color(0.28, 0.28, 0.32),
		"moss": Color(0.3, 0.45, 0.28),
		"rope": Color(0.75, 0.62, 0.4),
		"start": Color(0.2, 0.75, 0.65),
		"checkpoint": Color(0.95, 0.68, 0.2),
		"finish": Color(0.4, 0.65, 1.0),
	}

	var material := StandardMaterial3D.new()
	material.albedo_color = colors.get(name, Color.GRAY)
	material.roughness = 0.9
	_materials[name] = material
	return material

# Practice harness

## Wraps zero-based index to the available station range and resets player/course state.
func select_station(index: int) -> void:
	selected = posmod(index, stations.size())
	reset_station()

## Restores practice actors, health/stamina, input guards and deterministic mover phase.
## Retains course records; clears transient encounters and gameplay time effects.
func reset_station() -> void:
	_resets += 1
	TimeFx.clear()
	_obstacle_time = 0.0
	_update_obstacles()
	for mover in movers:
		mover.body.reset_physics_interpolation()
	_was_airborne = false
	_lowest_speed = 0.0
	player.frob.drop_held()
	player.teleport(Transform3D(Basis.IDENTITY, stations[selected].spawn))
	player.health = 100.0
	player.is_dead = false
	player._death_fall = 0.0
	player._set_crouched(false)
	player.neck.rotation = Vector3.ZERO
	player.juice.death = 0.0
	player.hand.set_suppressed(false)
	player.combat.reset_for_practice()
	player.body_motion.reset()
	if Input.is_action_pressed("throw"):
		player.spend_attack_press()
	run.reset(selected, stations[selected].gates.size(), _preset())
	_transition = "Ready — cross START"
	_last_state = -1
	_last_move = ""
	if is_instance_valid(_encounter):
		_encounter.queue_free()
		_encounter = null
		_guard = null
	Garrison.clear_all()
	if _guard_enabled and selected == 15 and is_instance_valid(_baker) and _baker.is_baked:
		_spawn_guard.call_deferred()
	_update_hud()

func _preset() -> String:
	return "%d Hz / %.1fx" % [Engine.physics_ticks_per_second, TimeFx.base]

func _input(event: InputEvent) -> void:
	if get_tree().paused or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == 0:
		key = event.keycode
	if key >= KEY_1 and key <= KEY_9:
		select_station(key - KEY_1)
	elif key == KEY_BRACKETLEFT:
		select_station(selected - 1)
	elif key == KEY_BRACKETRIGHT:
		select_station(selected + 1)
	elif key == KEY_R or key == KEY_0:
		reset_station()
	elif key == KEY_F4:
		var rates := [30, 60, 120]
		Engine.physics_ticks_per_second = rates[(rates.find(Engine.physics_ticks_per_second) + 1) % rates.size()]
		reset_station()
	elif key == KEY_F5:
		player.debug_traversal = not player.debug_traversal
	elif key == KEY_F6:
		_guard_enabled = not _guard_enabled
		select_station(15)
		if _guard_enabled:
			_enable_guard()
	elif key == KEY_F8:
		_damage_enabled = not _damage_enabled
		player.invulnerable = not _damage_enabled
		reset_station()
	elif key == KEY_F9:
		TimeFx.set_base(0.5 if TimeFx.base >= 0.99 else 1.0)
		reset_station()
	else:
		return
	get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_obstacle_time += delta
	_update_obstacles()
	run.tick(delta)
	if player == null:
		return
	var move_name := ""
	if player.current_move != null:
		move_name = str(player.current_move.kind)
	if player.movement_state != _last_state or move_name != _last_move:
		var names := ["Ground / air", "Traversal", "Hanging", "Climbing", "Swimming"]
		var previous: String = names[_last_state] if _last_state >= 0 and _last_state < names.size() else "Ready"
		var current: String = names[player.movement_state] if player.movement_state < names.size() else "Unknown"
		_transition = "%s → %s %s" % [previous, current, move_name]
		_last_state = player.movement_state
		_last_move = move_name
	if not player.is_on_floor() and player.movement_state == 0:
		_was_airborne = true
		_lowest_speed = minf(_lowest_speed, player.velocity.y)
	elif player.is_on_floor() and _was_airborne:
		if _lowest_speed < -12.0:
			_falls += 1
		_was_airborne = false
		_lowest_speed = 0.0
	if player.is_dead or player.global_position.y < -8:
		reset_station()
	_update_hud()

func _update_obstacles() -> void:
	for mover in movers:
		mover.body.position = mover.origin + mover.axis * sin(_obstacle_time * mover.speed) * mover.distance

## station/gate are zero-based; body must be this gym's player in the selected station.
## Ignores other bodies/stations, then advances ordered run timing and refreshes the HUD.
func checkpoint_reached(station: int, gate: int, body: Node3D) -> void:
	if body != player or station != selected:
		return
	if run.reach(gate):
		_transition = "FINISH %.2f s" % run.elapsed if run.finished else "Checkpoint %d / %d" % [gate + 1, run.gate_count]
		_update_hud()

func _course_gates(index: int) -> void:
	for i in stations[index].gates.size():
		var at: Vector3 = stations[index].gates[i]
		var area := Area3D.new()
		area.name = "Gate%d" % i
		area.position = at
		area.collision_layer = 0
		area.collision_mask = 1
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(3.2, 2.8, 0.5)
		collider.shape = shape
		area.add_child(collider)
		_fixture_root.add_child(area)
		_connect_gate(area, index, i)
		var color := "start" if i == 0 else ("finish" if i == stations[index].gates.size() - 1 else "checkpoint")
		# Visible non-colliding posts: the trigger is the opening between them.
		for x in [-1.75, 1.75]:
			var post := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.08, 2.8, 0.08)
			post.mesh = mesh
			post.material_override = _material(color)
			area.add_child(post)
			post.position.x = x
		var label := Label3D.new()
		label.text = "START" if i == 0 else ("FINISH" if i == stations[index].gates.size() - 1 else "CHECK %d" % i)
		label.font_size = 38
		label.pixel_size = 0.007
		label.shaded = false
		label.modulate = _material(color).albedo_color
		label.position.y = 1.6
		area.add_child(label)

func _connect_gate(area: Area3D, station: int, gate: int) -> void:
	area.body_entered.connect(func(body: Node3D): checkpoint_reached(station, gate, body))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_right = 440
	panel.offset_top = -278
	panel.offset_bottom = -16
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, 0.9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 16)
	stack.add_child(_hud)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.modulate = Color(0.75, 0.82, 0.9)
	stack.add_child(_status)

func _update_hud() -> void:
	if _hud == null:
		return
	var best := "—" if not run.best.has(selected) else "%.2f s" % run.best[selected]
	var timer := "FINISHED" if run.finished else ("RUNNING" if run.running else "READY")
	var move := ""
	if player.current_move != null:
		move = " · %s %.0f%%" % [player.current_move.kind, player.move_progress * 100.0]
	_hud.text = "%02d / %02d  %s\n%s  %.2f s  ·  gates %d/%d  ·  best %s\nSpeed %.2f m/s  ·  height %.2f m  ·  %s%s\n%s\nAttempts %d  ·  hard landings %d  ·  resets %d" % [selected + 1, stations.size(), stations[selected].title, timer, run.elapsed, run.next_gate, run.gate_count, best, Vector2(player.velocity.x, player.velocity.z).length(), player.global_position.y - 1.0, _preset(), move, _transition, run.attempts.get(selected, 0), _falls, _resets]
	var rejection: String = player._last_reject
	_status.text = "1–9 station   [ / ] previous / next   R restart\nF4 physics   F5 probes   F6 guard relay   F8 damage %s\nF9 slow motion   F10 legacy feel   Esc pause\n%s" % ["ON" if _damage_enabled else "OFF", "Planner: " + rejection if rejection != "" else "Cross green → amber → blue gates in order"]
	if selected == 15 and is_instance_valid(_guard):
		_status.text += "\nGuard: alert %.0f · sees you %s" % [_guard.alert, _guard.can_see_target]

func _enable_guard() -> void:
	if is_instance_valid(_baker):
		if _baker.is_baked and not is_instance_valid(_guard):
			_spawn_guard()
		return
	_baker = NavigationRegion3D.new()
	_baker.set_script(Baker)
	_baker.source_root = NodePath("..")
	_baker.bake_bounds = AABB(Vector3(-10, -1, -33), Vector3(28, 16, 43))
	_baker.traversal_links = false
	stations[15].root.add_child(_baker)
	_baker.baked.connect(_spawn_guard)

func _spawn_guard() -> void:
	if not _guard_enabled or selected != 15 or is_instance_valid(_guard):
		return
	_guard = GUARD.instantiate()
	_encounter = Node3D.new()
	_encounter.name = "RelayAttempt"
	add_child(_encounter)
	_guard.position = stations[15].root.position + Vector3(0, 0, -24)
	_guard.rotation.y = PI
	_guard.speaker_name = "Relay sentry"
	_guard.debug_ai = false
	_encounter.add_child(_guard)

## at and size are station-local metres; axis is the motion direction.
## distance is amplitude in metres, speed is radians per game second; axis is used as supplied.
## Adds a scripted collision blocker; normalize axis for distance to equal travel amplitude.
func add_mover(at: Vector3, size: Vector3, axis: Vector3, distance: float, speed: float) -> void:
	var body := AnimatableBody3D.new()
	# Updated in the physics tick; no render-to-physics transform buffering.
	body.sync_to_physics = false
	body.position = at
	body.collision_layer = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material("checkpoint")
	body.add_child(visual)
	_fixture_root.add_child(body)
	movers.append({"body": body, "origin": at, "axis": axis, "distance": distance, "speed": speed})
