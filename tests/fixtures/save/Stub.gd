extends Node3D
## A thing that saves itself, for the save suites: a number and where it is.

@export var value := 0
## Set to give it an id of its own (save_id), as a node without a stable name would.
@export var fixed_id := ""
## Where it was on its first physics frame (the save must be on before then).
var first_physics := Vector3.INF


func _ready() -> void:
	var save := get_node_or_null("/root/SaveGame")

	if save != null:
		save.register(self)


func _physics_process(_delta: float) -> void:
	if first_physics == Vector3.INF:
		first_physics = position


func save_state() -> Dictionary:
	return {"value": value, "pos": position}


func load_state(state: Dictionary) -> void:
	value = int(state.get("value", value))
	position = state.get("pos", position)


## Its own id ("" leaves it to its path).
func save_id() -> String:
	return fixed_id
