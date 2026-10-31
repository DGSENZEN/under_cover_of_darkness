shader_type spatial;
// A gauge's dial on the Company's engine, under its glass (maps/metro_station_machinery.gd, Oct 31 2026): a lit face,
// its tick ring, a ring of marks in the Company's own script between them, a red needle that hunts as the engine
// runs. Each dial finds its own place (the card's middle, from how its UV runs across the screen) and so its own
// reading, whatever card it is drawn on.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 face : source_color = vec4(1.0, 0.86, 0.62, 1.0);
uniform vec4 ink : source_color = vec4(0.12, 0.08, 0.06, 1.0);
uniform vec4 script : source_color = vec4(0.45, 0.06, 0.05, 1.0);
uniform vec4 needle : source_color = vec4(0.95, 0.12, 0.08, 1.0);
uniform float energy = 1.5;
// The needle's sweep (radians either side of straight up), how fast it hunts, how much it trembles.
uniform float sweep = 2.2;
uniform float hunt = 0.35;
uniform float tremble = 0.06;

float hash(float n) {
	return fract(sin(n * 78.233) * 43758.5453);
}

void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dwx = dFdx(w);
	vec3 dwy = dFdy(w);
	vec2 dux = dFdx(UV);
	vec2 duy = dFdy(UV);
	float det = dux.x * duy.y - dux.y * duy.x;
	vec3 across = (dwx * duy.y - dwy * dux.y) / det;
	vec3 up = (dwy * dux.x - dwx * duy.x) / det;
	vec3 middle = w - (UV.x - 0.5) * across - (UV.y - 0.5) * up;
	float seed = fract(dot(middle, vec3(0.731, 1.37, 0.917)) * 3.0);
	vec2 p = UV - 0.5;
	p.y = -p.y;
	float r = length(p);
	if (r > 0.5) {
		discard;
	}
	float a = atan(p.x, p.y);
	vec3 colour = face.rgb * (1.0 - 0.35 * smoothstep(0.2, 0.5, r));
	// (The tick ring: a tick every 10°, longer every 30°, over the sweep only.)
	float step_a = radians(10.0);
	float k = round(a / step_a);
	float off = abs(a - k * step_a) * r;
	float major = mod(k, 3.0) == 0.0 ? 1.0 : 0.0;
	float tick = step(off, 0.006) * step(0.38 - 0.05 * major, r) * step(r, 0.45) * step(abs(a), sweep + 0.01);
	colour = mix(colour, ink.rgb, tick);
	// (The script: a mark in each of 16 cells between 0.24 and 0.32: a bar, a dot or a hook.)
	float cell = floor((a + 3.14159265) / 6.2831853 * 16.0);
	float in_cell = fract((a + 3.14159265) / 6.2831853 * 16.0);
	float kind = floor(hash(cell + seed * 31.0) * 3.0);
	float mark = 0.0;
	if (kind == 0.0) {
		mark = step(abs(in_cell - 0.5), 0.1) * step(0.245, r) * step(r, 0.315);
	} else if (kind == 1.0) {
		mark = step(length(vec2((in_cell - 0.5) * 0.17, r - 0.28)), 0.018);
	} else {
		mark = step(abs(r - 0.3), 0.008) * step(0.2, in_cell) * step(in_cell, 0.8) + step(abs(in_cell - 0.2), 0.08) * step(0.25, r) * step(r, 0.3);
	}
	colour = mix(colour, script.rgb, clamp(mark, 0.0, 1.0));
	// (The needle, hunting round its reading, trembling.)
	float t = TIME;
	float reading = 0.5 + 0.32 * sin(t * hunt * (0.6 + seed) + seed * 6.2831853) + 0.08 * sin(t * 1.7 + seed * 40.0);
	float angle = -sweep + 2.0 * sweep * clamp(reading, 0.0, 1.0) + tremble * sin(t * 23.0 + seed * 9.0);
	vec2 d = vec2(sin(angle), cos(angle));
	float along = clamp(dot(p, d), -0.06, 0.4);
	float side = length(p - d * along);
	colour = mix(colour, needle.rgb, step(side, 0.012 * (1.0 - along * 1.4)));
	colour = mix(colour, ink.rgb, step(r, 0.035));
	ALBEDO = colour * energy;
}
