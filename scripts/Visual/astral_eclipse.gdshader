// The eclipse in the astral deep (scripts/Visual/AstralPassage.gd): the city's eclipse seen from the other side. A black
// sun, its rim a thin burning line, its corona oxblood and marigold in streamers that climb slowly off it, the whole
// breathing; turned to whoever looks, seen only through the passage's windows.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_mix;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 ink : source_color = vec3(0.004, 0.003, 0.006);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 pale : source_color = vec3(1.0, 0.9, 0.72);

void vertex() {
	// (Turned to the eye that looks at it.)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	// Its breath.
	float breath = 0.85 + 0.15 * sin(TIME * 0.22);
	float disc = 0.26;
	// The inner corona: broad tongues climbing slowly off the rim.
	float streams = texture(noise, vec3(cos(a) * 1.2, sin(a) * 1.2, r * 1.4 - TIME * 0.03)).r;
	float reach = disc + (0.08 + 0.22 * smoothstep(0.4, 0.85, streams)) * breath;
	float corona = smoothstep(reach, disc, r) * smoothstep(disc - 0.01, disc + 0.015, r);
	// The outer corona: fine streamers drawn out far along the radius (noise round it only, so they run straight
	// out), thinning as they go, a few reaching to its edge.
	float strands = texture(noise, vec3(cos(a) * 7.0, sin(a) * 7.0, TIME * 0.01)).r;
	float long_ones = texture(noise, vec3(cos(a) * 2.2, sin(a) * 2.2, 3.0 + TIME * 0.006)).r;
	float far = disc + 0.15 + 0.55 * smoothstep(0.45, 0.8, long_ones);
	float streamer = smoothstep(0.5, 0.8, strands) * smoothstep(far, disc, r) * smoothstep(disc, disc + 0.03, r);
	vec3 col = mix(oxblood, marigold, smoothstep(0.0, 0.8, corona) * smoothstep(disc + 0.2, disc, r));
	col = mix(col, pale, smoothstep(0.85, 1.0, corona) * smoothstep(disc + 0.05, disc, r));
	col = mix(col, mix(oxblood * 1.4, marigold, smoothstep(disc + 0.3, disc, r)), streamer * (1.0 - corona));
	// Its rim, a thin burning line, and a bead of light running slowly round it.
	float rim = smoothstep(0.012, 0.0, abs(r - disc));
	float bead_at = TIME * 0.05;
	float bead = exp(-pow(length(p - vec2(cos(bead_at), sin(bead_at)) * disc) / 0.035, 2.0));
	col += pale * (rim * breath + bead * 1.5);
	// A dim oxblood halo far round it.
	float halo = smoothstep(1.0, disc, r);
	halo = halo * halo * 0.3;
	float lit = max(max(max(corona, rim), streamer * 0.8), max(halo, bead));
	col = mix(oxblood * 0.6, col, smoothstep(0.0, 0.3, max(max(corona, rim), max(streamer, bead))));
	ALBEDO = r < disc ? ink : col;
	ALPHA = r < disc ? 1.0 : clamp(lit, 0.0, 1.0);
}
