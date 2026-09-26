extends SpringBoneSimulator3D
## What swings on him: skirts, tabards, capes, hood tails. Each is a chain of
## cloth bones (made in Blender, added to his skeleton by Wardrobe.gd) that
## springs back toward the way it hangs, drags, and falls with gravity; it is
## kept out of his legs and belly by capsules riding his bones. PS2 cloth: a
## few bones a strip, no simulated fabric.
##
## Runs after the ragdoll (Humanoid.add_ragdoll puts it there), so a body's
## cloth drapes over him as he falls, and before Severed, which keeps the
## last word. It runs on game time: slow motion slows it. It swings in the
## world, so it trails when he runs and drapes as he falls; when he is put
## somewhere far in one step (a teleport), ClothReset, just ahead of it,
## starts it afresh instead of letting it whip.
##
##   var cloth := Cloth.new()
##   skeleton.add_child(cloth)
##   cloth.setup(kind_json.cloth, kind_json.colliders)

## Where the floor plane waits while he stands (Cloth.gd's "Floor").
const PARKED := Vector3(0.0, -1000.0, 0.0)


## The chains ({bones, tip, stiffness, drag, gravity, radius}) and the
## capsules on his bones ({bone, radius, height}) from the wardrobe's JSON.
func setup(chains: Array, colliders: Array) -> void:
	set_setting_count(chains.size())

	for i in range(chains.size()):
		var chain: Dictionary = chains[i]
		var bones: Array = chain.get("bones", [])

		if bones.is_empty():
			continue

		set_root_bone_name(i, bones[0])
		set_end_bone_name(i, bones[-1])
		# The hem is past the last bone, along it.
		set_extend_end_bone(i, true)
		set_end_bone_direction(i, BONE_DIRECTION_PLUS_Y)
		set_end_bone_length(i, float(chain.get("tip", 0.1)))
		set_stiffness(i, float(chain.get("stiffness", 1.0)))
		set_drag(i, float(chain.get("drag", 0.4)))
		set_gravity(i, float(chain.get("gravity", 1.0)))
		set_gravity_direction(i, Vector3.DOWN)
		set_radius(i, float(chain.get("radius", 0.03)))
		set_enable_all_child_collisions(i, true)

	# A floor under him while he lies limp: ClothReset keeps it at the floor
	# under his hips then, parked far below otherwise.
	var ground := SpringBoneCollisionPlane3D.new()
	ground.name = "Floor"
	add_child(ground)
	ground.global_position = PARKED

	for spec in colliders:
		var capsule := SpringBoneCollisionCapsule3D.new()
		var radius := float(spec.get("radius", 0.08))
		var length := float(spec.get("height", 0.4))
		capsule.name = "Keep_" + String(spec.get("bone", ""))
		capsule.bone_name = spec.get("bone", "")
		capsule.radius = radius
		# The whole bone, end to end: its height counts the round ends.
		capsule.height = length + radius * 2.0
		capsule.position_offset = Vector3(0.0, length * 0.5, 0.0)
		add_child(capsule)


