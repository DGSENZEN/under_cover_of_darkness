// The feathered serpent in the astral deep (scripts/Visual/AstralPassage.gd), a god's own beast (oxblood its colour,
// the seeped dark's green its sheen), seen only through the passage's windows; lit (the only thing in the deep that
// is) by the deep's light, the eclipse's pale fire high ahead and a green glow from far below. Every part of it swims
// together: its UV.x is how far along its body it is (0 its head, 1 its tail), and the swim's reach grows toward its
// tail. Its parts: 0 its scaled body (glossy overlapping scales, each a little dome catching the light at its edge, a
// zigzag down its back, dull plates under its belly), 1 its feathers (a quill, barbs, oxblood to green, light through
// them; their own UV2), 2 its head (larger plates, brows, nostrils, its lips; UV2 along and round it), 3 its fangs (old
// bone), 4 its eyes (burning marigold, a slit, a glint; UV2 round the dome), 5 its tongue (wet).
shader_type spatial;
render_mode cull_back, fog_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

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

// Overlapping scales over `uv` (rows along, every other row offset): x each scale's dome (0 at its edge, 1 at its
// crown, leaning to its free edge), y its edge line, z its own hash.
vec3 scales(vec2 uv) {
	vec2 cell = uv;
	cell.y += 0.5 * mod(floor(cell.x), 2.0);
	vec2 f = fract(cell) - vec2(0.35, 0.5);
	float d = length(f * vec2(1.1, 1.0)) / 0.56;
	float dome = clamp(1.0 - d * d, 0.0, 1.0) * (0.75 + 0.25 * smoothstep(-0.35, 0.4, f.x));
	return vec3(dome, smoothstep(0.86, 1.0, d), hash(floor(cell)));
}

// `n` (view space) bent as the height `h` rises and falls across the surface (no tangents needed).
vec3 bumped(vec3 n, vec3 at, float h, float strength) {
	vec3 dpdx = dFdx(at);
	vec3 dpdy = dFdy(at);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * n - grad * strength);
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = ink;
	float rough = 0.4;
	float metal = 0.0;
	vec3 glow = vec3(0.0);
	if (part == 0 || part == 2) {
		// (Its head's plates fewer and larger.)
		vec3 s = scales(part == 0 ? vec2(UV.x * 220.0, UV.y * 22.0) : UV2 * vec2(22.0, 18.0));
		float grain = texture(noise, world_pos * 0.8).r;
		// Each scale its own dark green, a few nearer black, a few nearer teal.
		col = mix(ink * 1.4, seeped * 0.09, 0.35 + 0.5 * s.z) * (0.8 + 0.4 * grain);
		if (part == 0) {
			// A zigzag down its back, oxblood; dull plates under its belly.
			float back = abs(UV.y - 0.25);
			float zig = abs(fract(UV.x * 36.0) - 0.5) * 0.12;
			col = mix(col, oxblood * 0.32, smoothstep(0.035, 0.005, abs(back - zig - 0.02)) * 0.9);
			float belly = smoothstep(0.15, 0.09, abs(UV.y - 0.75));
			float plate = smoothstep(0.0, 0.2, fract(UV.x * 70.0)) * smoothstep(1.0, 0.85, fract(UV.x * 70.0));
			col = mix(col, mix(oxblood * 0.12, bone * 0.18, plate), belly);
			rough = mix(mix(0.26, 0.62, s.y), 0.7, belly);
			s.x = mix(s.x, plate * 0.6, belly);
		} else {
			// Its brows over its eyes; its nostrils near its snout; the line of its lips, oxblood.
			float round_at = UV2.y;
			float brow = exp(-pow((UV2.x - 0.42) / 0.1, 2.0)) * (smoothstep(0.06, 0.0, abs(round_at - 0.167))
				+ smoothstep(0.06, 0.0, abs(round_at - 0.333)));
			col += seeped * 0.05 * brow;
			float nostril = smoothstep(0.035, 0.015, length(vec2((UV2.x - 0.92) * 0.6, round_at - 0.21)))
				+ smoothstep(0.035, 0.015, length(vec2((UV2.x - 0.92) * 0.6, round_at - 0.29)));
			col = mix(col, ink * 0.2, clamp(nostril, 0.0, 1.0));
			float lips = smoothstep(0.025, 0.0, min(abs(round_at - 0.53), abs(round_at - 0.97))) * smoothstep(0.2, 0.35, UV2.x);
			col = mix(col, oxblood * 0.4, lips);
			// (Its head's plates flatter and duller than its body's scales: hide, not beads.)
			rough = mix(0.48, 0.7, s.y);
			s.x *= 0.5;
		}
		metal = part == 0 ? 0.25 : 0.1;
		NORMAL = bumped(NORMAL, VERTEX, s.x, part == 0 ? 0.012 : 0.008);
		// (A faint glow at its edge, so its shape holds in the dark: the seeped green above, oxblood under.)
		glow = mix(oxblood * 0.08, seeped * 0.06, smoothstep(-0.3, 0.6, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y)) * rim;
	} else if (part == 1) {
		// A feather, as the quetzal's: a bare quill at its root, its vane widening to a rounded tip; fine barbs; oxblood
		// at its root going to the seeped dark's green; a cold edge; on its tail's plume (UV.x 1) an eye near the tip.
		vec2 f = UV2;
		float x = clamp(f.x, 0.0, 1.0);
		float half_width = 0.5 * smoothstep(0.0, 0.08, x) * (0.3 + 0.7 * smoothstep(0.1, 0.7, x)) * sqrt(clamp(1.0 - pow(x, 8.0), 0.0, 1.0));
		float across = abs(f.y - 0.5);
		float vane = smoothstep(half_width, half_width - 0.03, across);
		float barbs = 0.5 + 0.5 * sin(x * 160.0 - across * 70.0);
		float ragged = texture(noise, vec3(f * vec2(7.0, 2.0), 2.0)).r;
		vane *= smoothstep(0.3, 0.42, ragged + (half_width - across) * 6.0);
		float quill = smoothstep(0.025, 0.0, across);
		col = mix(oxblood * 0.4, seeped * 0.12, smoothstep(0.05, 0.45, x)) * (0.75 + 0.25 * barbs);
		col = mix(col, oxblood * 0.3, smoothstep(0.75, 1.0, x) * 0.5);
		col = mix(col, ward * 0.25, smoothstep(half_width - 0.05, half_width, across) * 0.3);
		if (UV.x > 0.99) {
			float o = length(vec2((x - 0.82) * 1.5, f.y - 0.5));
			col = mix(col, marigold * 0.7, smoothstep(0.06, 0.04, o));
			col = mix(col, ink, smoothstep(0.025, 0.015, o));
			glow += marigold * 0.25 * smoothstep(0.06, 0.04, o) * smoothstep(0.015, 0.025, o);
		}
		col = mix(col, bone * 0.4, quill);
		rough = 0.5;
		NORMAL = bumped(NORMAL, VERTEX, barbs, 0.004);
		// (Light through the vane where it is thin.)
		BACKLIGHT = seeped * 0.25 * vane * (1.0 - quill);
		if (max(vane, quill * step(f.x, 0.98)) < 0.5) {
			discard;
		}
	} else if (part == 3) {
		col = bone * 0.55;
		rough = 0.35;
		glow = bone * 0.03;
	} else if (part == 5) {
		// Its tongue: oxblood, darker down its middle, its tips black; wet.
		col = oxblood * 0.5 * (0.8 + 0.2 * abs(UV2.y - 0.5) * 4.0);
		col = mix(col, ink, smoothstep(0.75, 1.0, UV2.x));
		rough = 0.18;
	} else {
		// Its eye: burning marigold, a slit, a glint.
		vec2 e = UV2 * 2.0 - 1.0;
		float d = length(e);
		float fibres = 0.75 + 0.25 * sin(atan(e.y, e.x) * 40.0);
		vec3 iris = mix(marigold * 1.4, oxblood, smoothstep(0.3, 1.0, d)) * fibres;
		float slit = smoothstep(0.17, 0.12, abs(e.x)) * smoothstep(1.0, 0.9, abs(e.y));
		col = ink;
		glow = iris * (1.0 - slit) * 1.2;
		rough = 0.1;
		glow += vec3(1.0, 0.92, 0.75) * smoothstep(0.2, 0.0, length(e - vec2(-0.35, 0.4)));
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.6;
	EMISSION = glow + col * 0.06;
}
