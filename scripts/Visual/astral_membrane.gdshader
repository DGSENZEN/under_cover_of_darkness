// A ward-gate's vortex (scripts/Visual/AstralPassage.gd): filling a gap of the astral passage, what is seen through
// it pulled round and into its middle; spiral arms in three depths turning at their own paces, darker toward its eye
// (a tunnel into the deep); its rim a ring burning marigold; ward cyan-white on its arms, the seeped dark's green
// between. Outside its circle only a faint shiver. Brighter as the walker comes near.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_mix;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform sampler3D noise : filter_linear, repeat_enable;
uniform vec3 walker = vec3(0.0, -1000.0, 0.0);
uniform vec3 ink : source_color = vec3(0.012, 0.01, 0.016);
uniform vec3 ward : source_color = vec3(0.812, 0.91, 0.941);
uniform vec3 seeped : source_color = vec3(0.498, 0.827, 0.416);
uniform vec3 marigold : source_color = vec3(1.0, 0.62, 0.16);
uniform vec3 pale : source_color = vec3(1.0, 0.9, 0.72);
// Its size (m: width, height), so its circle stays round on a long gap; its circle's share of the shorter side.
uniform vec2 size = vec2(3.0, 3.0);
uniform float circle = 0.47;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 turned(vec2 v, float a) {
	return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a));
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	float side = min(size.x, size.y);
	// (Its circle's radius 1.)
	vec2 q = p / (side * circle);
	float r = length(q);
	float a = atan(q.y, q.x);
	float near = 1.0 - smoothstep(1.0, 7.0, distance(world_pos, walker + vec3(0.0, 0.9, 0.0)));
	float t = TIME;
	float inner = 1.0 - smoothstep(0.0, 1.0, r);
	// What is seen through it, pulled round and in: more toward its eye.
	float twist = inner * inner * (1.6 + 0.8 * near) + 0.15 * sin(t * 0.4);
	vec2 bend = (turned(q, twist) * (1.0 - 0.25 * inner) - q) * 0.035;
	float shiver = texture(noise, vec3(UV * 4.0, t * 0.06)).r - 0.5;
	vec3 seen = texture(screen, SCREEN_UV + bend + vec2(shiver) * 0.006).rgb;
	// Its arms in three depths, each turning its own way and pace, broken by the noise as paint is.
	float lr = log(max(r, 0.02));
	float arms = 0.0;
	float deep = 0.0;
	for (int i = 0; i < 3; i++) {
		float k = float(i);
		float pace = (0.18 + 0.1 * k) * (i == 1 ? -1.0 : 1.0);
		float s = a / 6.2831853 * (3.0 + k) + lr * (1.1 + 0.35 * k) + t * pace;
		float arm = smoothstep(0.32, 0.0, abs(fract(s) - 0.5));
		float broken = texture(noise, vec3(q * (1.5 + k), t * 0.03 + k * 3.1)).r;
		arm *= smoothstep(0.3, 0.7, broken);
		// (The farther layers dimmer, smaller toward its eye.)
		float weight = (1.0 - 0.3 * k) * smoothstep(1.02, 0.6 - 0.15 * k, r);
		arms += arm * weight;
		deep += weight;
	}
	arms = clamp(arms, 0.0, 1.2);
	// Its eye: ink, a tunnel going down, a faint green far in.
	float eye = smoothstep(0.42, 0.0, r);
	vec3 tunnel = mix(seen * 0.6, ink, eye * 0.85) + seeped * 0.06 * smoothstep(0.25, 0.0, r);
	vec3 col = mix(tunnel, seeped * 0.25, inner * 0.35);
	col += mix(seeped * 0.5, ward, smoothstep(0.3, 0.95, r)) * arms * (0.35 + 0.35 * near);
	// Its rim burning: a ring of fire licking out from it.
	float flame = texture(noise, vec3(cos(a) * 2.0, sin(a) * 2.0, t * 0.35)).r;
	float reach = 0.035 + 0.11 * smoothstep(0.35, 0.8, flame);
	float burn = smoothstep(reach, 0.0, r - 1.0) * smoothstep(-0.05, 0.0, r - 1.0);
	float core = smoothstep(0.022, 0.0, abs(r - 1.0));
	col = mix(col, marigold, burn * 0.85);
	col = mix(col, pale, core * (0.6 + 0.4 * near));
	// Outside its circle, only a shiver over what is behind it.
	float in_circle = smoothstep(1.02, 0.98, r);
	ALBEDO = mix(seen, col, max(in_circle, burn));
	ALPHA = clamp(in_circle * (0.55 + 0.25 * eye + 0.2 * arms) + burn * 0.9 + core + (1.0 - in_circle) * 0.06, 0.0, 1.0);
}
