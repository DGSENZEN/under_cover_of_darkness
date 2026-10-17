extends RefCounted
## Advanced fixtures use the same player collision, water and climbing
## volumes as the game. Coordinates are local to the current station.

const Water := preload("res://scripts/Interaction/WaterVolume.gd")
const Handhold := preload("res://scripts/PlayerUtils/Handhold.gd")

## gym is the active traversal gym; index is the zero-based advanced station (8..15).
## Adds collision/visual fixtures under gym._fixture_root and updates that station's gates.
static func build(gym: Node3D, index: int) -> void:
	match index:
		8:
			gym._sign(0, "THIN LIPS & SEAMS\nCatch the 10 cm shelves. Shimmy across rises,\nfalls and changes in depth. Jump to pull up.\nThe last 30 cm rise requires a fresh leap.")
			for i in 5:
				var top: float = 3.6 + [0.0, 0.1, 0.0, -0.1, 0.2][i]
				gym._box(Vector3(i * 2.0 - 4.0, top - 0.05, -4.5 - (0.08 if i == 2 else 0.0)), Vector3(2, 0.1, 3), "brick")
			gym._box(Vector3(0, 0.6, -12), Vector3(3, 1.2, 2), "stone")
			gym._box(Vector3(0, 3.55, -20), Vector3(3, 0.1, 4), "brick")
			gym._box(Vector3(0, 3.95, -20), Vector3(3, 0.1, 4), "dark")
			gym.stations[index].gates = [Vector3(0, 1.5, 5), Vector3(4, 4.5, -4.5), Vector3(0, 1.5, -28)]
		9:
			gym._sign(0, "CORNERS & ANGLED FACES\nHang, shimmy around both ends, then move\ninto the inside corner. Angled blocks test\nnormal changes. Aim at the next face + jump.")
			gym._box(Vector3(0, 1.8, -4.5), Vector3(6, 3.6, 3), "brick")
			gym._box(Vector3(2.5, 1.8, -1.5), Vector3(1, 3.6, 3), "brick")
			var angled: StaticBody3D = gym._box(Vector3(0, 1.8, -12), Vector3(5, 3.6, 3), "stone")
			angled.rotation.y = PI / 6.0
			var next: StaticBody3D = gym._box(Vector3(2, 1.9, -19), Vector3(5, 3.8, 3), "stone")
			next.rotation.y = -PI / 4.0
			gym.stations[index].gates = [Vector3(0, 1.5, 5), Vector3(0, 4.5, -12), Vector3(2, 4.7, -19)]
		10:
			gym._sign(0, "CROUCHED CLEARANCE\n1.25 m headroom over a 1.2 m mantle.\nEnter crouched, pull through, then stand\nwhen clear. The lower red slot cannot fit.")
			gym._box(Vector3(0, 0.6, -4.5), Vector3(4, 1.2, 3), "stone")
			gym._box(Vector3(0, 2.55, -3.5), Vector3(4, 0.2, 5), "stone")
			gym._box(Vector3(0, 0.6, -12), Vector3(4, 1.2, 6), "stone")
			gym._box(Vector3(0, 2.55, -12), Vector3(4, 0.2, 6), "stone")
			gym._box(Vector3(6, 0.6, -5), Vector3(3, 1.2, 3), "brick")
			gym._box(Vector3(6, 2.3, -5), Vector3(3, 0.2, 3), "brick")
			gym.stations[index].gates[1] = Vector3(0, 2.2, -12)
		11:
			gym._sign(0, "MOVING OBSTRUCTION\nA sliding blocker crosses a mantle landing.\nPlan while clear; let it enter during the move.\nThe player must stop safely. R resets phase.")
			gym._box(Vector3(0, 0.6, -4.5), Vector3(4, 1.2, 3), "stone")
			gym._box(Vector3(0, 1.8, -13), Vector3(6, 3.6, 3), "brick")
			gym.add_mover(Vector3(0, 2.25, -4), Vector3(0.8, 2.0, 0.8), Vector3.RIGHT, 3.2, 1.4)
			gym.add_mover(Vector3(0, 4.5, -12), Vector3(0.6, 1.6, 0.6), Vector3.RIGHT, 4.0, 0.9)
			gym.stations[index].gates[1] = Vector3(0, 4.5, -13)
		12:
			gym._sign(0, "SLOPES & MOMENTUM\nSprint up the 15° / 30° ramps. Turn at the top,\nthen run down stairs and jump from the edge.\nWatch speed and landings at 30 / 60 / 120 Hz.")
			var ramp: StaticBody3D = gym._box(Vector3(0, 0.95, -5), Vector3(3, 0.3, 6), "steel")
			ramp.rotation.x = -deg_to_rad(15)
			gym._box(Vector3(0, 0.8, -9), Vector3(3, 1.6, 2), "steel")
			var steep: StaticBody3D = gym._box(Vector3(0, 3.05, -13), Vector3(3, 0.3, 6), "steel")
			steep.rotation.x = -deg_to_rad(30)
			gym._box(Vector3(0, 2.3, -17), Vector3(3, 4.6, 2), "steel")
			for i in 12:
				var h: float = 4.6 - float(i + 1) * 0.3
				gym._box(Vector3(0, h * 0.5, -18.3 - i * 0.6), Vector3(3, h, 0.6), "steel")
			gym.stations[index].gates[1] = Vector3(0, 5.7, -17)
		13:
			gym._sign(0, "WATER & LANDINGS\nDive, surface, mantle the far bank.\nLeft: walk the submerged quay steps.\nRight: jump over the boat rail onto its floor.\nSide platforms test 3 / 6 / 9 m landings.")
			gym._stairs(0, 5, 0.2, 0.3, 10, "moss")
			gym._box(Vector3(0, 1, -1), Vector3(14, 2, 6), "stone")
			Water.build(gym._fixture_root, gym._fixture_root.global_position + Vector3(0, 1, -9), Vector3(14, 2, 10))
			gym._box(Vector3(0, 1, -17), Vector3(14, 2, 6), "stone")
			for i in 8:
				var top: float = 0.5 + 0.2 * i
				gym._box(Vector3(-4.5, top * 0.5, -6.2 - 0.45 * i), Vector3(3, top, 0.45), "moss")
			gym._box(Vector3(-4.5, 1, -11.6), Vector3(3, 2, 5), "moss")
			# The harbour rowboat's three collision boxes, at this pool's surface.
			gym._box(Vector3(4, 1.83, -9), Vector3(3.2, 0.1, 1), "wood")
			gym._box(Vector3(4, 2.2, -8.32), Vector3(3.6, 0.8, 0.1), "wood")
			gym._box(Vector3(4, 2.2, -9.68), Vector3(3.6, 0.8, 0.1), "wood")
			for i in 3:
				var top: float = 3.0 * (i + 1)
				gym._box(Vector3(8, top * 0.5, -4 - i * 8), Vector3(3, top, 3), "moss")
				gym._ladder(Vector3(8, top * 0.5, -2.15 - i * 8), top)
			gym.stations[index].gates = [Vector3(0, 3.1, -1), Vector3(0, 2, -10), Vector3(0, 3.1, -17)]
		14:
			gym._sign(0, "VERTICAL RELAY\nLadder → thin sill → higher roof → rope.\nCatch-time jump should pull up; crouch drops.\nLook back across the gap and leap home.")
			gym._box(Vector3(0, 1.8, -4.5), Vector3(3, 3.6, 3), "brick")
			gym._ladder(Vector3(0, 1.8, -2.65), 3.6)
			gym._box(Vector3(0, 4.7, -10), Vector3(3, 0.1, 3), "brick")
			gym._box(Vector3(0, 3.25, -16), Vector3(3, 6.5, 3), "stone")
			gym._box(Vector3(0, 9, -21), Vector3(4, 0.3, 0.4), "wood")
			gym._rope(Vector3(0, 8.85, -21), 7.5, 0)
			gym._box(Vector3(0, 3.25, -24), Vector3(4, 6.5, 3), "stone")
			gym.stations[index].gates = [Vector3(0, 1.5, 5), Vector3(0, 7.5, -16), Vector3(0, 7.5, -24)]
		16:
			gym._sign(0, "FREE-RUN\nHold sprint: vault, wall run, climb, leap.\nSprint+crouch: climb down. Look behind + jump: back eject.\nThe dead-end roof stops you at its lip.")
			# The street: a fence to vault, a cart to mantle and run off.
			gym._box(Vector3(0, 0.45, 4), Vector3(4, 0.9, 0.2), "wood")
			gym._box(Vector3(0, 0.6, -1), Vector3(2.4, 1.2, 1.5), "wood")
			# The façade, 9 m, face at z = -7: sills straight up it from a
			# 3.4 m one (run up to) with one 2 m gap to leap, a column of
			# brackets to its right, a drainpipe to its left with a ledge
			# beside it.
			gym._box(Vector3(0, 4.5, -12), Vector3(8, 9, 10), "brick")
			for y in [3.4, 4.3, 5.2, 7.2, 8.1]:
				_sill(gym, Vector3(0, y, -7), 1.6)
			for i in 7:
				_bracket(gym, Vector3(2.6, 2.6 + 0.85 * i, -7))
			_pipe(gym, Vector3(-2.6, 0, -6.94), 9.0)
			_sill(gym, Vector3(-1.9, 4.6, -7), 0.6)
			# An alley 3 m wide along the façade's right side, to back eject
			# across: a wall facing it with a ledge at 6 m.
			gym._box(Vector3(8.5, 3, -12), Vector3(3, 6, 10), "stone")
			# The second roof across a 2.5 m gap; past it, nothing.
			gym._box(Vector3(0, 4.5, -24.25), Vector3(8, 9, 9.5), "brick")
			gym.stations[index].gates = [Vector3(0, 1.5, 6), Vector3(0, 10.4, -9), Vector3(0, 10.4, -25)]
		15:
			gym._sign(0, "COMBAT / STEALTH RELAY\nVault → cover → crouched mantle → guard.\nF6 toggles the sentry. Break sight behind cover.\nMetal is loud; carpet is quiet. Attack, dodge,\nclimb and disengage. R restores both actors.")
			gym._box(Vector3(0, 0.45, -4), Vector3(3, 0.9, 0.2), "wood")
			gym._box(Vector3(-1, 1.1, -9), Vector3(4, 2.2, 1.5), "brick")
			gym._box(Vector3(1, 1.1, -14), Vector3(4, 2.2, 1.5), "brick")
			gym._box(Vector3(0, 0.6, -19), Vector3(4, 1.2, 3), "stone")
			gym._box(Vector3(0, 2.55, -19), Vector3(4, 0.2, 3), "stone")
			var carpet: StaticBody3D = gym._box(Vector3(-4, 0.01, -17), Vector3(3, 0.02, 16), "moss")
			carpet.set_meta(&"surface", "carpet")
			gym._box(Vector3(4, 0.01, -17), Vector3(3, 0.02, 16), "steel")
			gym.stations[index].gates[1] = Vector3(0, 1.5, -16)


## A stone sill on a face pointing +Z: its top at y, a hold along its front.
static func _sill(gym: Node3D, at: Vector3, width: float) -> void:
	gym._box(Vector3(at.x, at.y - 0.05, at.z + 0.075), Vector3(width, 0.1, 0.15), "stone")
	_hold(gym, Handhold.Kind.LEDGE, Vector3(at.x, at.y, at.z + 0.15), width)


## An iron bracket sticking out of a face pointing +Z, held by its top.
static func _bracket(gym: Node3D, at: Vector3) -> void:
	gym._box(Vector3(at.x, at.y - 0.06, at.z + 0.1), Vector3(0.12, 0.12, 0.2), "steel")
	_hold(gym, Handhold.Kind.POINT, Vector3(at.x, at.y, at.z + 0.2), 1.0)


## A drainpipe standing just off a face pointing +Z, from at up length.
static func _pipe(gym: Node3D, at: Vector3, length: float) -> void:
	gym._box(Vector3(at.x, at.y + length * 0.5, at.z), Vector3(0.12, length, 0.12), "steel")
	_hold(gym, Handhold.Kind.POLE, at + Vector3(0, 0, 0.06), length)


static func _hold(gym: Node3D, kind: int, at: Vector3, length: float) -> void:
	var hold: Node3D = Handhold.new()
	hold.kind = kind
	hold.length = length
	hold.position = at
	gym._fixture_root.add_child(hold)
