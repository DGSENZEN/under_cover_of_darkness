extends Node3D
## The crowd's answer: splinters of black glass flung out in a ring all round you.
## Everything within REACH in your sight is hurt and thrown out, a wall stops it, and
## anything on you is thrown off first. The glass stays in the floor a little while.
## Obsidian, so it answers any crowd, not only spirits (Spells: `burst`, a stand-in
## name). The wind-up is the hand's own circle (HandSlot.set_circle).

const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")

const REACH := 5.5
const DAMAGE := 35.0
const RELEASE_STOP := 0.05
const RELEASE_TRAUMA := 0.28
## From your chest, level.
const CHEST := 1.2
## The ring: how many, how long it takes to get there, at what heights.
const RING := 28
const RING_TIME := 0.25
const RING_LOW := 0.35
const RING_HIGH := 1.4
## Left in the floor: how many, how long they stay, and how long to go.
const STUCK := 24
const STUCK_STAYS := 3.0
const STUCK_GOES := 1.0
const SPLINTER := Vector3(0.09, 0.8, 0.05)
## The wave across the floor, out to its true reach: cold bright on black glass, so
## it reads in the dark; and the flash that lights what it reaches.
const WAVE_CORE := Color("#F4F1FF")
const WAVE_BODY := Color("#9A86C8")
const WAVE_EDGE := Color("#2C2140")
const WAVE_TIME := 0.28
const WAVE_ENERGY := 2.6
const FLASH_COLOUR := Color(0.78, 0.72, 1.0)

var _rng := RandomNumberGenerator.new()


static func cast_on(player: CharacterBody3D) -> Node3D:
	var burst: Node3D = (load("res://scripts/Magic/ObsidianBurst.gd") as GDScript).new()
	player.get_parent().add_child(burst)
	burst.global_position = player.global_position
	burst._go(player)
	return burst


func _go(player: CharacterBody3D) -> void:
	_rng.seed = hash(global_position)
	player.leech.free_all()
	_strike(player)
	TimeFx.hitstop(get_tree(), RELEASE_STOP)
	player.juice.add_trauma(RELEASE_TRAUMA)
	Sfx.play_flat(self, &"whoosh_heavy", -2.0, 1.25)
	Sfx.play_flat(self, &"ting", -7.0, 0.6)
	var floor_at := _floor_under(global_position)
	_wave(floor_at)
	Fx.flash(self, global_position + Vector3.UP * 0.4, FLASH_COLOUR, 3.0, REACH * 1.8, 0.16)
	_ring(floor_at)
	_leave_stuck(floor_at)
	get_tree().create_timer(STUCK_STAYS + STUCK_GOES + 0.1, false, true).timeout.connect(queue_free)


func _strike(player: CharacterBody3D) -> void:
	var from := player.global_position + Vector3.UP * (CHEST - 1.0)
	var space := player.get_world_3d().direct_space_state

	for target in get_tree().get_nodes_in_group(&"monsters") + get_tree().get_nodes_in_group(&"guards"):
		if not (target is Node3D) or not target.has_method("take_hit") or target.get("asleep") == true or target.get("dead") == true:
			continue

		var at: Vector3 = (target as Node3D).global_position

		if at.distance_to(player.global_position) > REACH:
			continue

		var ray := PhysicsRayQueryParameters3D.create(from, at + Vector3.UP * 0.2, 1, [player.get_rid(), (target as CollisionObject3D).get_rid()])

		if not space.intersect_ray(ray).is_empty():
			continue

		var way := at - player.global_position
		way.y = 0.0
		var kind := &"burst" if target.is_in_group(&"monsters") else &"blast"
		target.take_hit(DAMAGE, player, kind, at, way.normalized() if way.length() > 0.01 else Vector3.FORWARD)


func _floor_under(at: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit["position"] if not hit.is_empty() else at


func _wave(floor_at: Vector3) -> void:
	var wave := MeshInstance3D.new()
	wave.mesh = MagicFx._ring_mesh(1.0, 0.09, 64)
	var look := MeshVfx.look(WAVE_CORE, WAVE_BODY, WAVE_EDGE, WAVE_ENERGY, 0.1, 1.0)
	wave.material_override = look
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	wave.add_to_group(&"burst_ring")
	add_child(wave)
	wave.global_position = floor_at + Vector3.UP * 0.06
	wave.scale = Vector3.ONE * 0.5
	var goes := wave.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	goes.tween_property(wave, "scale", Vector3(REACH, 1.0, REACH), WAVE_TIME).set_ease(Tween.EASE_OUT)
	goes.tween_method(func(e: float): look.set_shader_parameter(&"erosion", e), 0.1, 0.95, WAVE_TIME).set_ease(Tween.EASE_IN)
	goes.chain().tween_callback(wave.queue_free)


func _ring(floor_at: Vector3) -> void:
	var mesh: ArrayMesh = MagicFx.splinter_mesh(SPLINTER.x, SPLINTER.y, SPLINTER.z)

	for i in RING:
		var turn := TAU * float(i) / float(RING) + _rng.randf() * 0.1
		var way := Vector3(cos(turn), 0.0, sin(turn))
		var piece := _splinter(mesh)
		piece.add_to_group(&"burst_ring")
		add_child(piece)
		var height := _rng.randf_range(RING_LOW, RING_HIGH)
		piece.global_transform = Transform3D(Basis.looking_at(way, Vector3.UP), floor_at + way * 0.5 + Vector3.UP * height)
		var fly := piece.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		fly.tween_property(piece, "global_position", floor_at + way * REACH + Vector3.UP * height * 0.6, RING_TIME).set_ease(Tween.EASE_OUT)
		fly.tween_callback(piece.queue_free)


func _leave_stuck(floor_at: Vector3) -> void:
	var mesh: ArrayMesh = MagicFx.splinter_mesh(SPLINTER.x, SPLINTER.y * 0.8, SPLINTER.z)
	var space := get_world_3d().direct_space_state

	for i in STUCK:
		var turn := _rng.randf() * TAU
		var way := Vector3(cos(turn), 0.0, sin(turn))
		var out := _rng.randf_range(REACH * 0.45, REACH)
		var spot := floor_at + way * out + Vector3.UP * 0.5
		var along := PhysicsRayQueryParameters3D.create(floor_at + Vector3.UP * 0.5, spot, 1)

		# Not through a wall.
		if not space.intersect_ray(along).is_empty():
			continue

		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot, spot + Vector3.DOWN * 2.0, 1))

		if down.is_empty():
			continue

		var piece := _splinter(mesh)
		piece.add_to_group(&"burst_splinters")
		add_child(piece)
		var lean := (way + Vector3.UP * 0.8 + Vector3(_rng.randf() - 0.5, 0.0, _rng.randf() - 0.5) * 0.5).normalized()
		piece.global_transform = Transform3D(Basis.looking_at(lean, Vector3.FORWARD if absf(lean.dot(Vector3.UP)) > 0.99 else Vector3.UP), down["position"] + lean * 0.1)
		var goes := piece.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		goes.tween_interval(STUCK_STAYS + _rng.randf() * 0.3)
		goes.tween_property(piece, "scale", Vector3.ONE * 0.01, STUCK_GOES * 0.7)
		goes.tween_callback(piece.queue_free)


func _splinter(mesh: ArrayMesh) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = MagicFx.obsidian_look()
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return piece
