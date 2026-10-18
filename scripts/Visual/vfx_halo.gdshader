// The glow a flame throws into the air round it (Vfx.gd's candles: one per
// flame, the flames' own MultiMesh transforms): a camera-facing disc lifted
// to the flame's middle, its light falling off in two soft painted rings,
// added over what is behind it. It pulses with its light (`flicker`), and
// fades where it meets the wall or shelf it stands against, so it never cuts.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, world_vertex_coords;

uniform sampler2D depth : hint_depth_texture, filter_nearest;
uniform vec4 colour : source_color = vec4(1.0, 0.62, 0.26, 1.0);
uniform float flicker = 0.85;
uniform float gutter = 0.0;
// Its size at a flame of 1 (m), how far up the flame its middle stands (m, at 1), how bright.
uniform float size = 0.32;
uniform float lift = 0.035;
uniform float strength = 0.55;
// Over how much depth it fades into what it meets (m).
uniform float soft = 0.12;

varying float phase;

void vertex() {
	phase = INSTANCE_CUSTOM.x;
	// (A flame of 1 stands 0.065 m: its instance's upright scale over that.)
	float scale = length(MODEL_MATRIX[0].xyz) / 0.065;
	vec3 middle = MODEL_MATRIX[3].xyz + vec3(0.0, lift * scale, 0.0);
	float s = size * scale * (0.9 + 0.25 * flicker) * (1.0 - 0.5 * gutter);
	// (VERTEX comes in already in the world: the quad's own corners from its UV.)
	vec2 corner = (UV - vec2(0.5)) * vec2(1.0, -1.0);
	VERTEX = middle + (INV_VIEW_MATRIX[0].xyz * corner.x + INV_VIEW_MATRIX[1].xyz * corner.y) * s;
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	if (r >= 1.0) {
		discard;
	}
	// A tight bright ring close round the flame, then a wide soft one.
	float near = 1.0 - smoothstep(0.0, 0.28, r);
	float far = pow(1.0 - r, 2.6);
	float wobble = 0.92 + 0.08 * sin(TIME * 9.0 + phase * 30.0);
	float glow = (near * 0.55 + far * 0.45) * strength * flicker * wobble * (1.0 - 0.6 * gutter);
	// Faded where it meets what stands behind it.
	float behind = texture(depth, SCREEN_UV).r;
	vec4 at = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, behind, 1.0);
	float gap = -at.z / at.w - (-VERTEX.z);
	glow *= clamp(gap / soft, 0.0, 1.0);
	ALBEDO = colour.rgb * glow;
}
