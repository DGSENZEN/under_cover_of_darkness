// The sun stone adrift far out in the astral deep (scripts/Visual/AstralPassage.gd): the city's great carved calendar
// disc, the size of a district, turning slowly, a wedge of it broken away. On its faces the script's rings
// (astral_rings.png) carved round and round, their cuts glowing faint marigold on the side the eclipse lights; its rim
// catching the eclipse; all of it half lost in the deep's haze. Seen only through the passage's windows.
shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, fog_disabled, blend_mix;
stencil_mode read, compare_equal, 1;

uniform sampler2D rings : filter_linear_mipmap, repeat_disable;
uniform sampler3D noise : filter_linear, repeat_enable;
// Its radius and half its thickness (m, in its own frame: its faces across its y).
uniform float radius = 70.0;
uniform float half_thick = 5.0;
// Where the eclipse is (so its lit side faces it).
uniform vec3 light_at = vec3(0.0, 100.0, 0.0);
uniform vec3 ink : source_color = vec3(0.03, 0.026, 0.03);
uniform vec3 stone : source_color = vec3(0.16, 0.13, 0.11);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 oxblood : source_color = vec3(0.431, 0.122, 0.102);
uniform vec3 haze : source_color = vec3(0.03, 0.035, 0.032);

varying vec3 local;
varying vec3 world_pos;

void vertex() {
	local = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 face = local.xz / radius;
	float r = length(face);
	float a = atan(face.y, face.x);
	// The wedge broken away: ragged.
	float jag = texture(noise, vec3(face * 3.0, 0.5)).r - 0.5;
	if (a > 0.5 + jag * 0.3 && a < 1.25 + jag * 0.3 && r > 0.35 + jag * 0.2) {
		discard;
	}
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float lit = clamp(dot(n, normalize(light_at - world_pos)), 0.0, 1.0);
	bool on_face = abs(local.y) > half_thick * 0.9;
	// Its carving: the sheet's three rings laid out to its edge, their cuts lit faintly.
	float carved = 0.0;
	if (on_face) {
		for (int k = 0; k < 3; k++) {
			// (Each of the sheet's rings, scaled to sit at its own band of the disc.)
			float scale = 1.0 + float(k) * 0.55;
			vec2 uv = face / scale * 0.5 + 0.5;
			if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
				carved = max(carved, texture(rings, vec2((uv.x + float(k)) / 3.0, uv.y)).a);
			}
		}
	}
	float grain = texture(noise, local * 0.05).r;
	vec3 col = mix(ink, stone * (0.5 + 0.5 * grain), lit * 0.6);
	col = mix(col, ink * 0.5, carved * 0.6);
	col += marigold * carved * (0.08 + 0.25 * lit) * (0.7 + 0.3 * sin(TIME * 0.3 + r * 9.0));
	// Its rim catching the eclipse.
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	col += mix(oxblood, marigold, lit) * rim * 0.6;
	float far = smoothstep(150.0, 700.0, distance(world_pos, CAMERA_POSITION_WORLD));
	ALBEDO = mix(col, haze, far * 0.7);
	ALPHA = 1.0;
}
