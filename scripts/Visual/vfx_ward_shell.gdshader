// The Ward's shell (Ward.gd): a sphere of copal smoke exactly the size of
// what it stops. Nearly clear face on, brightest where it turns away (from
// inside, round the borders of your view), its smoke flowing round it in
// flat bands of the ward colours. It fills up from the floor (`fill`); a
// stopped shot flares there and a ripple runs out over it (`hits`: up to
// four, xyz the way from its middle in its own space, w seconds since, < 0
// none); `flare` brightens all of it a moment; `fade` takes it away;
// `inside` (the camera within it) makes it faint, only its far edge left, so
// your view out stays clear.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 core : source_color = vec4(0.95, 0.98, 0.99, 1.0);
uniform vec4 body : source_color = vec4(0.81, 0.91, 0.94, 1.0);
uniform vec4 edge : source_color = vec4(0.5, 0.65, 0.71, 1.0);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float energy = 0.9;
uniform float face = 0.03;
uniform float rim_opacity = 0.5;
uniform float rim_power = 2.6;
uniform float flow = 0.08;
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float flare = 0.0;
uniform float inside : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hits[4];
uniform float hit_speed = 4.0;
uniform float hit_life = 0.6;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 dir = normalize(local_pos);
	// Round it (u) and up it (v); the smoke flows round and a little up.
	vec2 uv = vec2(atan(dir.z, dir.x) / 6.2832 + 0.5, dir.y * 0.5 + 0.5);
	vec2 at = uv * vec2(3.0, 1.6) + vec2(TIME * flow, -TIME * flow * 0.5);
	float n = texture(noise, at).r * 0.65 + texture(noise, at * 2.1 + vec2(0.37, -TIME * flow)).r * 0.35;
	// (Round-it noise pinches to a pinwheel at the poles: the caps take
	// their own, laid flat across them.)
	vec2 cap = dir.xz * 1.4 + vec2(TIME * flow * 0.7, 0.0);
	float n_cap = texture(noise, cap).r * 0.65 + texture(noise, cap * 2.1 + vec2(0.61, TIME * flow)).r * 0.35;
	n = mix(n, n_cap, smoothstep(0.6, 0.9, abs(dir.y)));
	// Up from the floor as it fills, a ragged top.
	float up = uv.y;
	if (up > fill * 1.08 + (n - 0.5) * 0.12) {
		discard;
	}
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power + inside * 3.0);
	float smoke = smoothstep(0.32, 0.62, n);
	// Ripples from stopped shots: a band running out over it, and the flare
	// where it struck.
	float struck = 0.0;
	for (int i = 0; i < 4; i++) {
		if (hits[i].w >= 0.0) {
			float away = acos(clamp(dot(dir, normalize(hits[i].xyz)), -1.0, 1.0));
			float left = 1.0 - clamp(hits[i].w / hit_life, 0.0, 1.0);
			float front = hits[i].w * hit_speed;
			struck += exp(-pow((away - front) / 0.12, 2.0)) * left;
			struck += exp(-away * away / 0.04) * max(1.0 - hits[i].w / 0.15, 0.0) * 2.0;
		}
	}
	float strength = clamp(mix(face, rim_opacity, rim) * (0.4 + smoke) + struck * 0.7 + flare * 0.25 * rim, 0.0, 1.0);
	vec3 colour = edge.rgb;
	colour = mix(colour, body.rgb, step(0.45, n));
	colour = mix(colour, core.rgb, clamp(step(0.6, n) * rim + struck, 0.0, 1.0));
	ALBEDO = colour * (energy + flare * 0.6 + struck);
	// Its foot at the floor: gone under it.
	ALPHA = strength * fade * mix(1.0, 0.2, inside) * smoothstep(-0.95, -0.75, dir.y);
}
