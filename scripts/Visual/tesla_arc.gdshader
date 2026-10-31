shader_type spatial;
// A tesla arc's ribbon (scripts/Visual/TeslaArc.gd): a white-hot core fading to its colour at its edges, added to what
// is behind it. Each vertex carries the arc's direction there (NORMAL) and which edge it is (UV.x, -1 or 1); the vertex
// shader turns the ribbon to face the eye about that direction, so it keeps its width from any side between rebuilds.
// Never fogged (fog added over an additive ribbon would draw its strip where the arc is dim).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(0.353, 0.706, 1.0, 1.0);
uniform float width = 0.05;
uniform float energy = 3.0;
// The step's flash (set by TeslaArc).
uniform float flash = 1.0;

void vertex() {
	vec3 along = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 at = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 side = normalize(cross(along, normalize(-at)));
	POSITION = PROJECTION_MATRIX * vec4(at + side * UV.x * width, 1.0);
}

void fragment() {
	float edge = abs(UV.x);
	float core = pow(1.0 - edge, 3.0);
	vec3 hot = mix(colour.rgb, vec3(1.0), core * 0.8);
	ALBEDO = hot * energy * flash * (0.25 + 0.75 * (1.0 - edge * edge));
}
