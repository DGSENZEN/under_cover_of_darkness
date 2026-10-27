// The feathered serpent in the astral deep (scripts/Visual/AstralPassage.gd), a god's own beast (oxblood its colour,
// the seeped dark's green its sheen), seen only through the passage's windows. Every part of it swims together: its
// UV.x is how far along its body it is (0 its head, 1 its tail), and the swim's reach grows toward its tail. Its parts:
// 0 its scaled body (overlapping scales, a zigzag down its back, broad plates under its belly), 1 its feathers (a quill,
// barbs, green to oxblood, a cold edge; their own UV2), 2 its head (larger plates, a brow), 3 its fangs (old bone),
// 4 its eyes (marigold, a slit, a glint; UV2 round the dome).
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
stencil_mode read, compare_equal, 1;

uniform sampler3D noise : filter_linear, repeat_enable;
uniform int part = 0;
// The swim's reach at its tail (m), its body's length (m).
uniform float swim = 1.2;
uniform float body_length = 30.0;
uniform vec3 ink : source_color = vec3(0.016, 0.014, 0.02);
uniform vec3 seeped : source_color = vec3(0.498, 0.827, 0.416);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);
uniform vec3 ward : source_color = vec3(0.812, 0.91, 0.941);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 bone : source_color = vec3(0.72, 0.66, 0.52);

varying vec3 world_pos;

void vertex() {
	float reach = swim * pow(UV.x, 0.8);
	float phase = UV.x * body_length * 0.32 - TIME * 0.9;
	VERTEX.x += reach * sin(phase);
	VERTEX.y += reach * 0.3 * sin(phase * 0.7 + 1.3);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Overlapping scales over `uv` (rows along, offset every other row): x its face's light (its free edge brighter), y its
// edge line.
vec2 scales(vec2 uv) {
	vec2 cell = uv;
	cell.y += 0.5 * mod(floor(cell.x), 2.0);
	vec2 f = fract(cell) - vec2(0.15, 0.5);
	vec2 id = floor(cell);
	float round_edge = length(f * vec2(1.2, 1.0));
	float edge = smoothstep(0.5, 0.58, round_edge);
	float face = smoothstep(0.0, 0.85, f.x + 0.15) * (0.7 + 0.6 * hash(id));
	return vec2(face * (1.0 - edge), edge);
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// (Lit from the deep above, cold; from the market below, warm.)
	float above = smoothstep(-0.2, 0.9, n.y);
	vec3 rim_col = mix(oxblood * 1.6, mix(seeped, ward, 0.4), above);
	vec3 col = ink;
	float alpha = 1.0;
	if (part == 0 || part == 2) {
		// (Its head's plates fewer and larger.)
		vec2 s = scales(part == 0 ? vec2(UV.x * 150.0, UV.y * 16.0) : UV2 * vec2(10.0, 8.0));
		float grain = texture(noise, world_pos * 0.6).r;
		col = ink + seeped * s.x * (0.05 + 0.13 * above) * (0.7 + 0.6 * grain);
		col += oxblood * s.x * 0.08 * (1.0 - above);
		if (part == 0) {
			// A zigzag down its back, oxblood; broad plates under its belly.
			float back = abs(UV.y - 0.25);
			float zig = abs(fract(UV.x * 36.0) - 0.5) * 0.12;
			col = mix(col, oxblood * (0.35 + 0.4 * s.x), smoothstep(0.03, 0.0, abs(back - zig - 0.02)) * 0.9);
			float belly = smoothstep(0.14, 0.08, abs(UV.y - 0.75));
			float plate = smoothstep(0.0, 0.25, fract(UV.x * 60.0)) * smoothstep(1.0, 0.85, fract(UV.x * 60.0));
			col = mix(col, mix(oxblood * 0.18, bone * 0.16, plate) * (0.6 + 0.4 * plate), belly);
		} else {
			// Its brow: a heavier ridge over its eyes.
			col += seeped * 0.08 * smoothstep(0.08, 0.0, abs(UV2.y - 0.72)) * smoothstep(0.2, 0.5, UV2.x);
		}
		col *= 1.0 - 0.5 * s.y;
		col += rim_col * rim * 0.9;
	} else if (part == 1) {
		// A feather, as the quetzal's: a bare quill at its root, its vane widening to a rounded tip; fine barbs; oxblood
		// at its root going to the seeped dark's green, iridescent toward ward-white as it turns; a cold edge; on its
		// tail's plume (UV.x 1) an eye near the tip.
		vec2 f = UV2;
		float x = clamp(f.x, 0.0, 1.0);
		float half_width = 0.5 * smoothstep(0.0, 0.08, x) * (0.3 + 0.7 * smoothstep(0.1, 0.7, x)) * sqrt(clamp(1.0 - pow(x, 8.0), 0.0, 1.0));
		float across = abs(f.y - 0.5);
		float vane = smoothstep(half_width, half_width - 0.03, across);
		float barbs = 0.85 + 0.15 * sin(x * 160.0 - across * 70.0);
		float ragged = texture(noise, vec3(f * vec2(7.0, 2.0), 2.0)).r;
		vane *= smoothstep(0.3, 0.42, ragged + (half_width - across) * 6.0);
		float quill = smoothstep(0.025, 0.0, across);
		float turn = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
		col = mix(oxblood * 0.55, seeped * 0.38, smoothstep(0.05, 0.45, x)) * barbs;
		col = mix(col, mix(seeped, ward, 0.5) * 0.6, turn * smoothstep(0.2, 0.6, x));
		col = mix(col, ward * 0.5, smoothstep(half_width - 0.06, half_width, across) * 0.5);
		if (UV.x > 0.99) {
			float o = length(vec2((x - 0.82) * 1.5, f.y - 0.5));
			col = mix(col, marigold * 0.85, smoothstep(0.06, 0.04, o));
			col = mix(col, ink, smoothstep(0.025, 0.015, o));
		}
		col = mix(col, bone * 0.5, quill);
		alpha = max(vane, quill * step(f.x, 0.98));
		if (alpha < 0.5) {
			discard;
		}
	} else if (part == 3) {
		col = bone * (0.45 + 0.35 * above) + rim_col * rim * 0.5;
	} else {
		// Its eye: marigold, a slit, a glint.
		vec2 e = UV2 * 2.0 - 1.0;
		float d = length(e);
		float fibres = 0.75 + 0.25 * sin(atan(e.y, e.x) * 40.0);
		col = mix(marigold * 1.2, oxblood, smoothstep(0.3, 1.0, d)) * fibres;
		col = mix(col, ink, smoothstep(0.17, 0.12, abs(e.x)) * smoothstep(1.0, 0.9, abs(e.y)));
		col += vec3(1.0, 0.92, 0.75) * smoothstep(0.2, 0.0, length(e - vec2(-0.35, 0.4)));
	}
	ALBEDO = col;
}
