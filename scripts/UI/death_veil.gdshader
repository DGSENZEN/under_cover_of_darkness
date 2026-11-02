shader_type canvas_item;
// After everything: a deep dark, and someone has lit a candle for you, which is more than the ánimas
// ever had. Its light in a few close oil values, their edges a dry brush's, boiling in held
// steps like the menu's paint. `lit`, 0..1: the flame catching.

uniform sampler2D noise : filter_linear, repeat_enable;
uniform float lit = 0.0;
uniform float fps = 5.0;
uniform float aspect = 1.7778;
uniform vec2 flame_at = vec2(0.645, 0.72);

const vec3 NIGHT = vec3(0.016, 0.015, 0.026);
const vec3 DUSK = vec3(0.042, 0.032, 0.05);
const vec3 EMBER = vec3(0.105, 0.062, 0.058);
const vec3 GLOW = vec3(0.215, 0.12, 0.08);
const vec3 WAX = vec3(0.56, 0.46, 0.33);
const vec3 WAX_SHADE = vec3(0.2, 0.135, 0.1);
const vec3 FLAME = vec3(1.0, 0.72, 0.36);
const vec3 HEART = vec3(1.0, 0.93, 0.74);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	float n = floor(TIME * fps);
	vec2 boil = vec2(hash(n), hash(n + 17.0)) * 0.5;
	vec2 p = (UV - flame_at) * vec2(aspect, 1.0);
	float big = textureLod(noise, p * 1.4 + boil, 0.0).r;
	float streak = textureLod(noise, p * vec2(2.5, 14.0) + boil * 1.7, 0.0).r;
	float breath = 0.94 + 0.06 * hash(floor(n / 3.0));
	// The light, up and out from it, in stepped values.
	vec2 from_flame = p - vec2(0.0, -0.05);
	float light = lit * breath * exp(-dot(from_flame, from_flame) * 1.5);
	float body = light + (big - 0.5) * 0.11 + (streak - 0.5) * 0.05;
	vec3 col = mix(NIGHT, DUSK, smoothstep(0.1, 0.14, body));
	col = mix(col, EMBER, smoothstep(0.38, 0.44, body));
	col = mix(col, GLOW, smoothstep(0.76, 0.84, body) * 0.8);
	// The stub, lit from its top, sinking into the dark at its foot.
	float along = p.y / 0.13;
	// (Its width a little out of true, wax run down one side; its top a slumped lip.)
	float run = 0.004 * smoothstep(0.1, 0.3, along) * (1.0 - smoothstep(0.42, 0.56, along));
	float side = p.x + (big - 0.5) * 0.006;
	float inside = (1.0 - smoothstep(0.019 + run, 0.022 + run, side)) * (1.0 - smoothstep(0.019, 0.022, -side));
	float lip = 0.012 * (p.x / 0.02) + (streak - 0.5) * 0.012;
	float stub = inside * step(lip, p.y) * (1.0 - smoothstep(0.5, 0.95, along + (streak - 0.5) * 0.35));
	// Lit from its top and from the flame's side, in stepped values, as everything is.
	float wax_lit = (1.0 - smoothstep(0.08, 0.5, along)) * 0.8 + (0.5 - p.x / 0.04) * 0.3 + (big - 0.5) * 0.3;
	vec3 wax = mix(WAX_SHADE * 0.5, WAX_SHADE, smoothstep(0.08, 0.14, wax_lit));
	wax = mix(wax, WAX, smoothstep(0.52, 0.6, wax_lit));
	col = mix(col, wax, stub * smoothstep(0.0, 0.3, lit));
	// The flame: a torn teardrop, a held frame at a time.
	vec2 q = vec2(p.x + (hash(n * 3.0) - 0.5) * 0.006 * (-p.y / 0.07), p.y + 0.004) / vec2(0.02, 0.07) / max(lit, 0.001);
	float tall = clamp(-q.y, 0.0, 1.0);
	float wide = sqrt(max(tall, 0.0)) * (1.0 - tall) * 1.9;
	float cover = (1.0 - smoothstep(wide - 0.14, wide + 0.04, abs(q.x) + (streak - 0.5) * 0.2)) * step(0.0, -q.y) * step(-q.y, 0.98);
	float hot = (1.0 - smoothstep(wide * 0.3, wide * 0.65, abs(q.x))) * (1.0 - smoothstep(0.1, 0.62, tall));
	col = mix(col, mix(FLAME, HEART, hot), cover * step(0.01, lit));
	// A very few flecks off it, climbing and gone, a held frame at a time.
	vec2 g = p * vec2(16.0, 8.0) + vec2(0.0, n * 0.09);
	vec2 cell = floor(g);
	float pick = hash(cell.x * 37.0 + cell.y * 91.0);
	float fleck = step(0.965, pick) * (1.0 - smoothstep(0.02, 0.07, length(fract(g) - vec2(hash(pick * 7.0), hash(pick * 13.0)) * 0.7 - 0.15)));
	float near_it = exp(-p.x * p.x * 60.0) * smoothstep(0.02, -0.08, p.y) * (1.0 - smoothstep(0.1, 0.5, -p.y));
	col = mix(col, FLAME, fleck * near_it * lit * 0.8);
	COLOR = vec4(col, 1.0);
}
