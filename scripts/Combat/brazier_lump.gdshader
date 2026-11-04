shader_type spatial;
// A coal thrown out of the brazier: a black lump, its cracks burning, going out at the end of its life (COLOR.r).

varying float hot;
varying vec3 at;

float bump(vec3 p) {
	return fract(sin(dot(floor(p), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	hot = COLOR.r;
	at = VERTEX;
	// (Not a ball: a broken lump.)
	VERTEX *= 0.72 + 0.5 * bump(VERTEX * 2.4 + INSTANCE_CUSTOM.xyz + vec3(float(INSTANCE_ID)));
}

void fragment() {
	float crack = smoothstep(0.35, 0.8, bump(at * 3.2 + vec3(TIME * 0.4)));
	ALBEDO = vec3(0.014, 0.012, 0.011);
	ROUGHNESS = 0.9;
	EMISSION = mix(vec3(0.5, 0.06, 0.01), vec3(2.6, 1.0, 0.2), crack * hot) * hot * (0.5 + 0.9 * hot);
}
