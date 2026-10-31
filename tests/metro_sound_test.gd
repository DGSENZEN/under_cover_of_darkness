extends Node3D
## The Metro's sound (docs/superpowers/specs/2026-10-31-metro-sound-design.md), headless with --fixed-fps 60, sound on
## and Master muted: Sfx's tile steps, gains and blended rooms (S1-S3).

const Sfx := preload("res://scripts/Audio/Sfx.gd")
const Focus := preload("res://scripts/Audio/Focus.gd")

var results: Array[String] = []
var failures := 0


func _ready() -> void:
	Sfx.enabled = true
	AudioServer.set_bus_mute(0, true)
	Sfx._ensure_buses()
	await _sfx()
	Focus.reset()
	Sfx.silence()
	await _frames(3)
	print("\n==== RESULTS ====")
	for result in results:
		print(result)
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		failures += 1


func _world_reverb() -> AudioEffectReverb:
	var index := AudioServer.get_bus_index(Sfx.BUS_WORLD)
	for i in range(AudioServer.get_bus_effect_count(index)):
		if AudioServer.get_bus_effect(index, i) is AudioEffectReverb:
			return AudioServer.get_bus_effect(index, i)
	return null


## S1-S3: Sfx.
func _sfx() -> void:
	_check("S1 tile has its own steps; its runs, jumps and landings are stone's",
		Sfx.step("tile") == &"step_tile" and Sfx.step("tile", true) == &"step_tile"
		and Sfx.step("tile", false, "jump") == &"jump_stone" and Sfx.step("tile", false, "land") == &"land_stone",
		"%s %s %s %s" % [Sfx.step("tile"), Sfx.step("tile", true), Sfx.step("tile", false, "jump"), Sfx.step("tile", false, "land")])

	Sfx.set_acoustics_mix({"tile": 1.0})
	var tiled := _world_reverb().room_size
	Sfx.set_acoustics_mix({"stone": 1.0})
	var stoned := _world_reverb().room_size
	Sfx.set_acoustics_mix({"tile": 0.5, "stone": 0.5})
	var half := _world_reverb().room_size
	Sfx.set_acoustics("stone")
	_check("S2 the acoustics blend by weight", tiled > stoned and absf(half - (tiled + stoned) / 2.0) < 0.02,
		"%.3f %.3f %.3f" % [tiled, stoned, half])

	var shots := [&"pipe_tick", &"neon_ignite", &"cable_surge", &"train_far", &"metro_draught"]
	var loops := [&"metro_room", &"metro_room_deep", &"metro_crowd", &"junction_hum", &"transformer_hum"]
	_check("S3 every Metro name has a gain", shots.all(func(n): return Sfx.GAIN.has(n))
		and loops.all(func(n): return Sfx.LOOP_GAIN.has(n)),
		"missing %s" % str((shots.filter(func(n): return not Sfx.GAIN.has(n))
			+ loops.filter(func(n): return not Sfx.LOOP_GAIN.has(n)))))
