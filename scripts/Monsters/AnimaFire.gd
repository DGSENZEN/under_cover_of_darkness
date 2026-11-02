extends RefCounted
## The low fire a ravenous ánima has left: a dim, broken smoulder of spirit-fire along its
## bones (anima_ember.gdshader, the Metro's aura, nearly out). On the walking hands and on
## those in your view alike.

const EmberShader := preload("res://scripts/Monsters/anima_ember.gdshader")

## A burning copy of `mesh`, wearing the same skeleton.
static func ember_on(mesh: MeshInstance3D, thickness: float, z_clip := 1.0, fov := 0.0) -> MeshInstance3D:
	var ember := MeshInstance3D.new()
	ember.name = "Ember"
	ember.mesh = mesh.mesh
	ember.skin = mesh.skin
	ember.layers = mesh.layers
	ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var look := ShaderMaterial.new()
	look.shader = EmberShader
	look.set_shader_parameter(&"noise", MeshVfx.noise())
	look.set_shader_parameter(&"thickness", thickness)
	look.set_shader_parameter(&"z_clip", z_clip)
	look.set_shader_parameter(&"fov_override", fov)
	ember.material_override = look
	mesh.get_parent().add_child(ember)
	ember.skeleton = ember.get_path_to(mesh.get_node(mesh.skeleton))
	return ember
