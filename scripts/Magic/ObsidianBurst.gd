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

const REACH := 5.5
## How long the wave takes to get there.
const WAVE_TIME := 0.5
const DAMAGE := 35.0
## How long it stays about, for what it has started. (The spikes are its children.)
const SPELL_LASTS := 6.0
const RELEASE_STOP := 0.05
const RELEASE_TRAUMA := 0.28
## From your chest, level.
const CHEST := 1.2
## The flash that lights what it reaches.
const FLASH_COLOUR := Color(0.78, 0.72, 1.0)

var _rng := RandomNumberGenerator.new()
var _player: CharacterBody3D
var _t := 0.0
var _hit: Dictionary = {}


static func cast_on(player: CharacterBody3D) -> Node3D:
	var burst: Node3D = (load("res://scripts/Magic/ObsidianBurst.gd") as GDScript).new()
	player.get_parent().add_child(burst)
	burst.global_position = player.global_position
	burst._go(player)
	return burst


func _go(player: CharacterBody3D) -> void:
	_rng.seed = hash(global_position)
	_player = player
	add_to_group(&"burst_spell")
	player.leech.free_all()
	TimeFx.hitstop(get_tree(), RELEASE_STOP)
	player.juice.add_trauma(RELEASE_TRAUMA)
	Sfx.play_flat(self, &"whoosh_heavy", -2.0, 1.25)
	Sfx.play_flat(self, &"ting", -7.0, 0.6)
	var floor_at := _floor_under(global_position)
	BurstWave.rise_at(self, floor_at, REACH, WAVE_TIME)
	Fx.flash(self, global_position + Vector3.UP * 0.4, FLASH_COLOUR, 3.0, REACH * 1.8, 0.16)
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
		target.take_hit(DAMAGE, _player, kind, at, way.normalized() if way.length() > 0.01 else Vector3.FORWARD)


func _floor_under(at: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 8.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit["position"] if not hit.is_empty() else at
