// A tree's sway in the wind, shared by its bark (painterly.gdshaderinc) and
// its leaves (foliage.gdshader) so a crown stays on its limbs: the whole tree
// bends from its foot (`base`, the instance's origin), more the higher a
// point stands (as the square of its height over the first metre), pushed
// downwind and back as the wind breathes, with a little sideways sway; one
// phase for the whole tree, its own for each tree.
//   bend       how far it bends (m) for each square metre of height
//   blow       the wind (m/s, flat), Materials.blow
//   full       a wind this strong bends it fully
vec3 tree_sway(vec3 world, vec3 base, float bend, vec3 blow, float full, float time) {
	float speed = length(blow.xz);
	vec2 way = speed > 0.001 ? blow.xz / speed : vec2(0.7, 0.7);
	float strength = clamp(speed / full, 0.0, 1.3);
	float h = max(world.y - base.y - 1.0, 0.0);
	float phase = time + dot(base.xz, vec2(0.37, 0.23));
	float push = strength * (0.75 + 0.25 * sin(phase * 0.8)) + 0.35 * (0.2 + strength) * sin(phase * 1.9 + 0.7);
	float side = 0.18 * (0.2 + strength) * sin(phase * 1.3 + 2.1);
	return (vec3(way.x, 0.0, way.y) * push + vec3(-way.y, 0.0, way.x) * side) * bend * h * h;
}
