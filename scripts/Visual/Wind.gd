extends Node
## The night's wind on the foliage (Materials.blow): the leaves, grass,
## reeds and ivy stir as the night's wind blows, still on a calm night,
## thrashing in a storm. A level with foliage adds one.

const Materials := preload("res://scripts/Visual/Materials.gd")

func _process(_delta: float) -> void:
	var night := get_tree().get_first_node_in_group(&"night")

	if night != null and night.has_method(&"wind"):
		Materials.blow(night.wind())
