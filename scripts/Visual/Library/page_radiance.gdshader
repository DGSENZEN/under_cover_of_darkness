// Animated light on the existing paper mesh; no extra card or authored writing.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 colour : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform vec3 page_min = vec3(0.0);
uniform vec3 page_size = vec3(1.0);
uniform float amount = 0.0;
uniform float seed = 0.0;
uniform bool caged = false;
varying vec3 paper_at;

void vertex() {
	paper_at = (VERTEX - page_min) / max(page_size, vec3(0.0001));
}

void fragment() {
	if (amount < 0.001) { discard; }
	vec2 p = (paper_at.xz - vec2(0.5)) * vec2(1.0, 1.2);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float time = TIME * 0.7 + seed;
	float ring = 1.0 - smoothstep(0.006, 0.015, abs(r - 0.32));
	float broken_ring = (1.0 - smoothstep(0.004, 0.011, abs(r - 0.4))) * step(0.15, sin(angle * 12.0 - time));
	float sweep = pow(max(0.0, cos(angle - time)), 18.0);
	float core = 1.0 - smoothstep(0.015, 0.035, r);
	float trace = (ring * (0.3 + sweep * 0.7) + broken_ring * 0.45 + core * 0.5);
	if (caged) {
		// Light leaking between the leaves: thin seams across the book's thickness, each running and flickering
		// along its length on its own clock, as if something inside were testing the pages.
		float leaf = paper_at.x * 9.0;
		float seam = abs(fract(leaf + 0.5) - 0.5);
		float line = 1.0 - smoothstep(0.04, 0.13, seam);
		float run = 0.5 + 0.5 * sin(paper_at.z * 13.0 + paper_at.y * 8.0 - time * 2.2 + floor(leaf) * 1.7 + seed);
		trace = line * (0.2 + 0.8 * pow(run, 3.0));
	}
	if (trace < 0.01) { discard; }
	float pulse = 0.8 + 0.2 * sin(TIME * 2.3 + seed);
	ALBEDO = colour.rgb * 3.0;
	ALPHA = clamp(trace * amount * pulse, 0.0, 1.0);
}
