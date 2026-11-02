shader_type canvas_item;
// Words in the menu's paint (the teaser's, the death quotes'): on a torn dry-brush wash, boiling in held steps, brushed in from the middle, coming apart in embers.
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float level = 0.0;
uniform float gone = 0.0;
uniform float spread = 1.0;
uniform float zoom = 1.0;
uniform float embers = 0.0;
uniform vec2 half_size = vec2(0.6, 0.08);
uniform float wash = 0.72;
uniform float aspect = 1.7778;
uniform float fps = 9.0;
uniform vec3 wash_col = vec3(0.02, 0.03, 0.04);
uniform vec3 ember_col = vec3(1.0, 0.62, 0.2);

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	float n = floor(TIME * fps);
	vec2 boil = vec2(hash(n), hash(n + 17.0)) * 0.5;
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float big = texture(noise, p * 1.4 + boil).r;
	float streak = texture(noise, p * vec2(2.5, 16.0) + boil * 1.7).r;
	vec2 wob = (vec2(texture(noise, p * 2.6 + boil).r, texture(noise, p * 2.6 + boil + 0.37).r) - 0.5) * 0.0042;
	// Coming apart: sheared along the brush, lifting.
	wob += vec2((big - 0.5) * gone * 0.05, gone * gone * 0.05);
	vec2 uv = 0.5 + (UV - 0.5) / zoom + wob;
	vec4 tex = texture(TEXTURE, uv);
	float a = tex.a;
	vec3 glyph = tex.rgb / max(a, 0.001);
	// Brushed in from the middle.
	float sweep = abs(p.x) / max(half_size.x, 0.01);
	float cover = smoothstep(0.0, 0.14, level * 1.5 - sweep * 0.92 - (streak - 0.5) * 0.45);
	// Eaten away by the same brush.
	float grain = big * 0.55 + streak * 0.45;
	float line = gone * 1.15;
	float keep = smoothstep(line - 0.1, line, grain + 0.02 * step(gone, 0.001));
	if (gone <= 0.001) keep = 1.0;
	float burn = gone > 0.001 ? a * smoothstep(line - 0.2, line - 0.08, grain) * (1.0 - keep) : 0.0;
	float text = a * cover * keep;
	// A brushed-in rim of fire.
	float rim = a * smoothstep(0.0, 0.14, level * 1.5 - sweep * 0.92 - (streak - 0.5) * 0.45 + 0.2) * (1.0 - cover);
	// Soft halo, from a few taps.
	float halo = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7854;
		vec2 off = vec2(cos(ang) / aspect, sin(ang));
		halo += texture(TEXTURE, uv + off * 0.0045).a + texture(TEXTURE, uv + off * 0.011).a * 0.6;
	}
	halo = clamp(halo / 8.0, 0.0, 1.0) * cover * keep;
	// The wash: torn top and bottom, melting at its two ends.
	vec2 half_now = half_size * vec2(spread, mix(0.7, 1.0, spread));
	float ey = (half_now.y - abs(p.y)) / max(half_size.y, 0.001);
	float ex = (half_now.x - abs(p.x)) / max(half_size.x, 0.001);
	float torn = smoothstep(0.0, 1.0, ey * 1.7 + (big - 0.5) * 1.1 + (streak - 0.5) * 0.5);
	float ends = smoothstep(0.0, 0.5, ex + (big - 0.5) * 0.28);
	float w = wash * torn * ends * smoothstep(0.0, 0.35, level) * (1.0 - smoothstep(0.1, 0.85, gone + (big - 0.5) * 0.3));
	// Embers: flecks in held frames, climbing.
	vec2 g = p * 15.0 + vec2(hash(floor(n / 3.0)) * 0.3, -n * 0.11);
	vec2 cell = floor(g);
	float pick = hash(cell.x * 37.0 + cell.y * 91.0);
	float fleck = step(0.93, pick) * (1.0 - smoothstep(0.03, 0.11, length(fract(g) - vec2(hash(pick * 7.0), hash(pick * 13.0)) * 0.7 - 0.15)));
	float e = fleck * embers * clamp(torn * ends * 1.3, 0.0, 1.0);
	// Over one another: wash, halo, fleck, fire, words.
	vec3 c = wash_col;
	float o = w;
	float h = halo * 0.5;
	c = mix(c, ember_col * 0.8, h / max(h + o * (1.0 - h), 0.001));
	o = h + o * (1.0 - h);
	float f = clamp(e + burn + rim, 0.0, 1.0);
	c = mix(c, ember_col, f / max(f + o * (1.0 - f), 0.001));
	o = f + o * (1.0 - f);
	c = mix(c, glyph, text / max(text + o * (1.0 - text), 0.001));
	o = text + o * (1.0 - text);
	COLOR = vec4(c, o);
}
