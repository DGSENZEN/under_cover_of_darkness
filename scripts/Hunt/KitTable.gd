extends Node3D
## A table with what you can take on a hunt laid out on it (stand-in boxes
## until the pieces are made). Put it in a safe place (SafePlace.gd).

const Props := preload("res://scripts/Interaction/Props.gd")
const KitPieceScript := preload("res://scripts/Hunt/KitPiece.gd")

## What lies on it, left to right: [piece, type, stand-in colour].
const LAID_OUT := [
	[&"lead", &"round", Color(0.62, 0.66, 0.72)],
	[&"copal", &"round", Color(1.0, 0.58, 0.12)],
	[&"egg", &"item", Color(0.9, 0.86, 0.76)],
]
const TOP := 0.9
const SIZE := Vector3(1.8, 0.1, 0.9)
const PIECE := Vector3(0.22, 0.12, 0.16)

var _pieces := {}


static func build(parent: Node, at: Transform3D) -> Node3D:
	var table: Node3D = (load("res://scripts/Hunt/KitTable.gd") as GDScript).new()
	parent.add_child(table)
	table.global_transform = at
	return table


func _ready() -> void:
	var top := StaticBody3D.new()
	top.position = Vector3(0.0, TOP - SIZE.y * 0.5, 0.0)
	top.add_child(Props.shape_box(SIZE))
	top.add_child(Props.mesh_box(SIZE, Color(0.28, 0.2, 0.13)))
	add_child(top)
	var body := StaticBody3D.new()
	body.position = Vector3(0.0, (TOP - SIZE.y) * 0.5, 0.0)
	var legs := Vector3(SIZE.x - 0.1, TOP - SIZE.y, SIZE.z - 0.1)
	body.add_child(Props.shape_box(legs))
	body.add_child(Props.mesh_box(legs, Color(0.2, 0.14, 0.1)))
	add_child(body)

	for i in LAID_OUT.size():
		var entry: Array = LAID_OUT[i]
		var kit_piece: StaticBody3D = KitPieceScript.new()
		kit_piece.piece = entry[0]
		kit_piece.piece_type = entry[1]
		kit_piece.position = Vector3((i - (LAID_OUT.size() - 1) * 0.5) * 0.5, TOP + PIECE.y * 0.5, -0.1)
		kit_piece.add_child(Props.shape_box(PIECE))
		kit_piece.add_child(Props.mesh_box(PIECE, entry[2]))
		add_child(kit_piece)
		_pieces[entry[0]] = kit_piece


func piece(id: StringName) -> Node:
	return _pieces.get(id)


## All the pieces sit where the pack says.
func show_for(loadout: Node) -> void:
	for id in _pieces:
		_pieces[id].show_for(loadout)
