extends StaticBody3D
## One thing laid out on a kit table: a box of rounds, an egg. Frobbed, it goes
## into the pack and slides to the table's near edge, or back. Won't move once
## the pack is locked.

## How far it slides, packed.
const SLIDE := Vector3(0.0, 0.0, 0.25)

@export var piece: StringName
## &"round" or &"item".
@export var piece_type: StringName = &"round"
var verb := "Pack"

var _home := Vector3.ZERO


func _ready() -> void:
	_home = position


## What the frob prompt says.
func get_prompt(_player: Node) -> String:
	return verb


func frob(player: Node) -> void:
	var loadout: Node = player.get("loadout")

	if _packed_in(loadout):
		if piece_type == &"round":
			loadout.unpack_round(piece)
		else:
			loadout.unpack_item(piece)
	elif piece_type == &"round":
		loadout.pack_round(piece)
	else:
		loadout.pack_item(piece)

	show_for(loadout)


## Sits where the pack says it should.
func show_for(loadout: Node) -> void:
	var packed := _packed_in(loadout)
	position = _home + (SLIDE if packed else Vector3.ZERO)
	verb = "Put back" if packed else "Pack"


func _packed_in(loadout: Node) -> bool:
	return loadout.rounds.has(piece) if piece_type == &"round" else loadout.items.has(piece)
