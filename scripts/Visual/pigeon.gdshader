shader_type spatial;
// A pigeon (Pigeons.gd, the figures kit's pigeon) in the painterly look, its
// wings moved by its instance's custom (r its phase 0..1, g its flap: 1
// beating, b its spread: 1 out): on the ground the span drawn in to the
// shoulder (folded), in the air spread and beating about the body's long
// axis, more toward the tip (UV2.x the hinge: 0 at the root, 1 at the tip;
// UV2.y the side, -1 left, +1 right; the body 0, 0).

render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// The wings' root: how far out from the middle, and how high (m), as the
// kit models it (tools/eclipse/figures_kit.py: WING_ROOT; WING_Z and half
// WING_THICK, less the 2 cm the bird is set down by).
uniform vec2 shoulder = vec2(0.05, 0.137);
// Wingbeats a second (rad/s) and how far a beat turns the tip (rad).
uniform float rate = 14.0;
uniform float beat = 0.9;

void flap(inout vec3 v, inout vec3 n, vec2 hinge, vec4 custom, float time) {
	// (UV2 is stored compressed: the side is near -1, 0 or +1.)
	if (abs(hinge.y) < 0.5) {
		return;
	}

	float side = sign(hinge.y);
	vec2 root = vec2(side * shoulder.x, shoulder.y);
	vec2 local = v.xy - root;
	local.x *= mix(0.2, 1.0, custom.b);
	// A beat, and a little lift when spread (the wings' dihedral).
	float a = side * (custom.g * sin(time * rate + custom.r * 6.2832) * beat * hinge.x + custom.b * 0.15);
	mat2 turn = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	v.xy = root + turn * local;
	n.xy = turn * n.xy;
}

#define PAINTERLY_VERTEX flap(VERTEX, NORMAL, UV2, INSTANCE_CUSTOM, TIME);
#include "res://scripts/Visual/painterly.gdshaderinc"
