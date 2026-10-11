// The effects' shared craft (the effects plan, docs/superpowers/plans/2026-10-10-zocalo-vfx.md):
// flipbook frames, erosion, multiplied noise, hard light bands (the Mignola
// look), six-way lit smoke.

// A frame of a flipbook sheet `grid` frames across and down; `progress` 0..1
// over the frames (a particle's INSTANCE_CUSTOM.z), stepped, looping.
vec2 flipbook_uv(vec2 uv, float progress, ivec2 grid) {
	float total = float(grid.x * grid.y);
	float frame = mod(floor(progress * total), total);
	vec2 cell = vec2(mod(frame, float(grid.x)), floor(frame / float(grid.x)));
	return (uv + cell) / vec2(grid);
}

// Alpha eaten from its thinnest parts first as `threshold` rises (0 keeps it
// all, 1 eats it all), with a soft or hard edge (`feather`).
float erode(float alpha, float threshold, float feather) {
	return clamp((alpha - threshold) / max(feather, 0.001), 0.0, 1.0) * step(0.001, alpha);
}

// Two noise octaves multiplied, the Diablo 3 way: holes where either is dark.
float multiply_noise(float a, float b) {
	return clamp(a * b * 2.0, 0.0, 1.0);
}

// Light in `steps` hard bands: shadow as a solid mass.
float bands(float light, float steps) {
	return floor(clamp(light, 0.0, 1.0) * steps + 0.5) / steps;
}

// Six-way lit smoke: sheet A holds the light from the right, top and back in
// r, g, b; sheet B from the left, bottom and front; `l` the light's way in
// the sprite's own axes (x right, y up, z toward the camera).
float six_way(vec4 a, vec4 b, vec3 l) {
	return a.r * max(l.x, 0.0) + b.r * max(-l.x, 0.0)
		+ a.g * max(l.y, 0.0) + b.g * max(-l.y, 0.0)
		+ a.b * max(-l.z, 0.0) + b.b * max(l.z, 0.0);
}
