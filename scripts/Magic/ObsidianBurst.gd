extends Node3D
## The crowd's answer: a wave of black glass up through the floor, out from where you stood.
## Everything it reaches in REACH, in your sight, is hurt and thrown out as it arrives, the
## nearest first; a wall stops it; anything on you is thrown off at once, ahead of it.
## Obsidian, so it answers any crowd, not only spirits (Spells: `burst`, a stand-in
## name). The wind-up is the hand's own circle (HandSlot.set_circle).

const MagicFx := preload("res://scripts/Visual/MagicFx.gd")
const TimeFx := preload("res://scripts/Visual/TimeFx.gd")
const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Fx := preload("res://scripts/Visual/Fx.gd")
const BurstWave := preload("res://scripts/Magic/BurstWave.gd")
const BurstCracks := preload("res://scripts/Magic/BurstCracks.gd")

const REACH := 5.5
## How long the wave takes to get there.
const WAVE_TIME := 0.5
const DAMAGE := 35.0
## How long it stays about, for what it has started. (The spikes are its children.)
const SPELL_LASTS := 6.0
const RELEASE_STOP := 0.07
const RELEASE_TRAUMA := 0.42
## The thump in your view: rolled, not pitched (a pitch would walk your aim off).
const RELEASE_ROLL := 1.5
## From your chest, level.
const CHEST := 1.2
## What it leaves in them: how many shards, how far apart (m).
const STUCK_IN := 3
const STUCK_SPREAD := 0.12
## The flash that lights what it reaches.
const FLASH_COLOUR := Color(0.78, 0.72, 1.0)

var _rng := RandomNumberGenerator.new()
var _player: CharacterBody3D
var _t := 0.0
var _hit: Dictionary = {}


## `cracks`: the floor already cracking under you (BurstCracks.gd), or none.
static func cast_on(player: CharacterBody3D, cracks: Node3D = null) -> Node3D:
	var burst: Node3D = (load("res://scripts/Magic/ObsidianBurst.gd") as GDScript).new()
	player.get_parent().add_child(burst)
	burst.global_position = player.global_position
	burst._go(player)

	if not is_instance_valid(cracks):
		cracks = BurstCracks.on_floor(player.get_parent(), floor_below(player))

	cracks.scar(REACH, WAVE_TIME)
	return burst


## The floor under them, or a little under their feet if there is none in reach.
static func floor_below(player: CharacterBody3D) -> Vector3:
	var at := player.global_position
	var ray := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 8.0, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit["position"] if not hit.is_empty() else at + Vector3.DOWN


func _go(player: CharacterBody3D) -> void:
	_rng.seed = hash(global_position)
	_player = player
	add_to_group(&"burst_spell")
	player.leech.free_all()
	TimeFx.hitstop(get_tree(), RELEASE_STOP)
	player.juice.add_trauma(RELEASE_TRAUMA)
	player.juice.punch(0.0, 0.0, RELEASE_ROLL * (1.0 if _rng.randf() < 0.5 else -1.0))
	Sfx.play_flat(self, &"thud", 0.0, 0.5)
	Sfx.play_flat(self, &"whoosh_heavy", -2.0, 0.72)
	Sfx.play_flat(self, &"ting", -8.0, 0.55)
	var floor_at := _floor_under(global_position)
	BurstWave.rise_at(self, floor_at, REACH, WAVE_TIME)
	Fx.flash(self, global_position + Vector3.UP * 0.4, FLASH_COLOUR, 1.4, REACH * 1.8, 0.3)
	get_tree().create_timer(SPELL_LASTS, false, true).timeout.connect(queue_free)


## How far out the wave has come (m).
func wave_reach() -> float:
	return minf(REACH * _t / WAVE_TIME, REACH)


## Whether the wave has hit that.
func was_hit(target: Node3D) -> bool:
	return _hit.has(target.get_instance_id())


func _physics_process(delta: float) -> void:
	_t += delta

	if is_instance_valid(_player):
		_strike_what_it_reached()

	if wave_reach() >= REACH:
		set_physics_process(false)


func _strike_what_it_reached() -> void:
	var out := wave_reach()
	var from := global_position + Vector3.UP * (CHEST - 1.0)
	var space := get_world_3d().direct_space_state

	for target in get_tree().get_nodes_in_group(&"monsters") + get_tree().get_nodes_in_group(&"guards"):
		if not (target is Node3D) or was_hit(target) or not target.has_method("take_hit") or target.get("asleep") == true or target.get("dead") == true:
			continue

		var at: Vector3 = (target as Node3D).global_position

		if at.distance_to(global_position) > out:
			continue

		_hit[target.get_instance_id()] = true
		var ray := PhysicsRayQueryParameters3D.create(from, at + Vector3.UP * 0.2, 1, [_player.get_rid(), (target as CollisionObject3D).get_rid()])

		if not space.intersect_ray(ray).is_empty():
			continue

		var way := at - global_position
		way.y = 0.0
		var kind := &"burst" if target.is_in_group(&"monsters") else &"blast"
		var out_way := way.normalized() if way.length() > 0.01 else Vector3.FORWARD
		target.take_hit(DAMAGE, _player, kind, at, out_way)
		_marked_by_it(target, at, out_way)


## It goes up and over, with the glass in it, if it is still there.
func _marked_by_it(target: Node3D, at: Vector3, way: Vector3) -> void:
	if not is_instance_valid(target) or target.get("dead") == true or not target.is_in_group(&"monsters"):
		return

	if target.has_method("flung_up"):
		target.flung_up(global_position)

	if target.has_method("cracked_by"):
		target.cracked_by(at, way)

	for i in STUCK_IN:
		var off := Vector3(_rng.randf_range(-STUCK_SPREAD, STUCK_SPREAD), _rng.randf_range(-STUCK_SPREAD, STUCK_SPREAD), _rng.randf_range(-STUCK_SPREAD, STUCK_SPREAD))
		# Up through it, from the floor, and out.
		MagicFx.stuck_in(target, at + off, (way + Vector3.UP * 1.1 + off * 2.0).normalized())


func _floor_under(at: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 8.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit["position"] if not hit.is_empty() else at
