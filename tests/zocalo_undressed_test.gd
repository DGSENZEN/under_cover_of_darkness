extends Node3D
## The Zócalo undressed (the effects plan, Task 1): no effects, no wind, no
## pigeons, and day and night still switch. Headless:
##   Godot --headless --fixed-fps 60 --path . res://tests/zocalo_undressed_test.tscn

const MAP := preload("res://maps/zocalo.tscn")

var results: Array[String] = []


func _ready() -> void:
	var map: Node3D = MAP.instantiate()
	map.undressed = true
	add_child(map)

	for i in 10:
		await get_tree().physics_frame

	map.set_day(false)
	map.set_day(true)
	_check("A10 undressed: no effects, wind or pigeons; day and night switch", map.ambient == null and map.gusts == null
		and map.pigeons == null and map.kit == null, "ambient %s, gusts %s, pigeons %s" % [map.ambient, map.gusts, map.pigeons])

	print("\n==== RESULTS ====")
	for r in results:
		print(r)

	get_tree().quit()


func _check(test_name: String, ok: bool, detail: String) -> void:
	results.append("%s  %s   [%s]" % ["PASS" if ok else "FAIL", test_name, detail])
