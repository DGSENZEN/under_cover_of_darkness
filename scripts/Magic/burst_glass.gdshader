// The Burst's obsidian: dark amethyst-black volcanic glass, flaked, its facets catching a cold
// violet sheen in hard bands that slide as you move, with a faint oil of colour; its flaked ridges
// razor thin, so they let the light through. Inside it, seen at depth, veins of the spell's violet
// light, moving, strongest at the root where it tore up from the floor. `charge` is how much of the
// spell is still in it: a new spike is full of it, and it cools. `dark` is how far down its light
// sits. The model's colours: red, how near a ridge; green, how deep in a flake.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec4 glass : source_color = vec4(0.012, 0.011, 0.018, 1.0);
uniform vec4 sheen : source_color = vec4(0.36, 0.27, 0.72, 1.0);
uniform vec4 oil_a : source_color = vec4(0.28, 0.14, 0.5, 1.0);
uniform vec4 oil_b : source_color = vec4(0.06, 0.34, 0.38, 1.0);
uniform vec4 vein : source_color = vec4(0.5, 0.3, 0.95, 1.0);
uniform vec4 vein_hot : source_color = vec4(0.86, 0.8, 1.0, 1.0);
uniform vec4 ridge : source_color = vec4(0.62, 0.54, 0.95, 1.0);
uniform float charge = 0.3;
uniform float dark = 0.3;
// How much a MultiMesh instance's own alpha adds to it (0 for a lone mesh).
uniform float custom_share = 0.0;

varying vec3 local;
varying vec3 to_eye_local;
varying float near_ridge;
varying float in_flake;
varying float charged;

void vertex() {
	local = VERTEX;
	to_eye_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz - VERTEX;
	near_ridge = COLOR.r;
	in_flake = COLOR.g;
	charged = charge + INSTANCE_CUSTOM.a * custom_share;
}

float veins_at(vec3 at, float drift) {
	vec2 uv = vec2(at.x * 1.6 + at.z * 1.1, at.y * 0.55 - TIME * drift);
	float a = texture(noise, uv).r;
	float b = texture(noise, uv * 2.3 + vec2(0.37, TIME * drift * 0.5)).r;
	// Thin bright lines where the noise crosses its middle.
	return (1.0 - smoothstep(0.0, 0.05, abs(a - 0.5))) * 0.7 + (1.0 - smoothstep(0.0, 0.035, abs(b - 0.5))) * 0.4;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float turned = 1.0 - facing;
	ALBEDO = glass.rgb;
	METALLIC = 0.2;
	ROUGHNESS = 0.06;
	SPECULAR = 1.0;
	// A reflection of nothing in particular, in hard bands: the glass catching the room.
	vec3 r = reflect(-v, n);
	float world = texture(noise, r.xy * 0.42 + vec2(r.z * 0.2, 0.0)).r;
	float caught = smoothstep(0.56, 0.58, world) * 0.2 + smoothstep(0.66, 0.67, world) * 0.75;
	vec3 surface = sheen.rgb * caught * (0.35 + turned * 0.9);
	// The oil on it, turning as it turns.
	vec3 oil = mix(oil_a.rgb, oil_b.rgb, smoothstep(0.35, 0.75, turned + (world - 0.5) * 0.6));
	surface += oil * smoothstep(0.45, 0.85, turned) * 0.55;
	// Looking into it: the view bent in, two depths of veins.
	vec3 into = -normalize(to_eye_local);
	float up = clamp(local.y, 0.0, 1.0);
	float deep = veins_at(local + into * 0.09, 0.09) * 0.7 + veins_at(local + into * 0.2, 0.05) * 0.4;
	float at_root = 1.0 - smoothstep(0.0, 0.85, up);
	float spell = clamp(charged, 0.0, 1.5);
	vec3 inner = mix(vein.rgb, vein_hot.rgb, smoothstep(0.7, 1.3, spell)) * deep * (0.25 + at_root * 1.1) * (0.18 + spell * 1.5) * (0.35 + facing * 0.65);
	// A low glow up from the root, fading up it.
	inner += vein.rgb * pow(at_root, 3.0) * (0.03 + spell * 0.34) * (0.5 + in_flake * 0.5);
	// Its ridges, thin enough to pass the light.
	vec3 edge = ridge.rgb * smoothstep(0.55, 1.0, near_ridge) * (0.12 + spell * 0.7 + caught * 0.4);
	EMISSION = (surface + inner + edge) * mix(dark, 1.0, smoothstep(0.5, 1.2, spell));
}
