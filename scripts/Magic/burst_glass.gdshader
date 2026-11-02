// The Burst's obsidian: volcanic glass, black to look at and deep to look into. Each flat facet
// carries the curved ripples obsidian breaks in, ringing out from one of its corners, and flashes
// cold as it turns to the light, those ripples bending the flash. Its true ridges are a dim
// hairline, thin glass passing the light (the model's colours: half a barycentric corner, half
// more for an edge that is no ridge, so a facet's own triangles draw no line). A faint
// oil of colour where it turns away. Inside, at depth and near the root only, the spell's violet
// veins, moving. `charge` is how much of the spell is still in it: a new spike is full of it, and
// it cools to near black.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec4 glass : source_color = vec4(0.012, 0.011, 0.018, 1.0);
uniform vec4 flash : source_color = vec4(0.42, 0.42, 0.6, 1.0);
uniform vec4 oil_a : source_color = vec4(0.2, 0.09, 0.36, 1.0);
uniform vec4 oil_b : source_color = vec4(0.04, 0.2, 0.24, 1.0);
uniform vec4 vein : source_color = vec4(0.38, 0.2, 0.8, 1.0);
uniform vec4 vein_hot : source_color = vec4(0.82, 0.76, 1.0, 1.0);
uniform vec4 edge_colour : source_color = vec4(0.62, 0.58, 0.85, 1.0);
uniform float charge = 0.3;
// How much a MultiMesh instance's own alpha adds to it (0 for a lone mesh).
uniform float custom_share = 0.0;
uniform float ripples = 24.0;

varying vec3 local;
varying vec3 to_eye_local;
varying vec3 corner;
varying float charged;

void vertex() {
	local = VERTEX;
	to_eye_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz - VERTEX;
	corner = COLOR.rgb;
	charged = charge + INSTANCE_CUSTOM.a * custom_share;
}

float veins_at(vec3 at, float drift) {
	vec2 uv = vec2(at.x * 1.6 + at.z * 1.1, at.y * 0.55 - TIME * drift);
	float a = texture(noise, uv).r;
	return 1.0 - smoothstep(0.0, 0.03, abs(a - 0.5));
}

void fragment() {
	vec3 v = normalize(VIEW);
	vec3 n = normalize(NORMAL);
	float turned = 1.0 - clamp(dot(n, v), 0.0, 1.0);
	// The ripples of the break: rings out from a corner, closer together near it, dying away.
	vec3 bary = mod(min(corner, vec3(0.9999)), vec3(0.5)) * 2.0;
	float from_corner = length(bary.yz);
	float ring = sin(pow(from_corner, 0.7) * ripples);
	float dies = 1.0 - smoothstep(0.2, 0.8, from_corner);
	vec3 bent = normalize(n + vec3(ring * 0.05 * dies));
	ALBEDO = glass.rgb;
	METALLIC = 0.2;
	ROUGHNESS = 0.08 + (ring * 0.5 + 0.5) * 0.1 * dies;
	SPECULAR = 1.0;
	NORMAL = bent;
	// A facet turning to the light flashes, in one hard band, broken by the ripples.
	float caught = smoothstep(0.62, 0.64, turned + ring * 0.05 * dies);
	vec3 surface = flash.rgb * caught * 0.3;
	surface += flash.rgb * smoothstep(0.72, 0.92, ring * 0.5 + 0.5) * dies * (0.008 + turned * turned * 0.09);
	surface += mix(oil_a.rgb, oil_b.rgb, smoothstep(0.6, 0.95, turned)) * smoothstep(0.55, 0.95, turned) * 0.2;
	// Looking into it, near the root.
	vec3 into = -normalize(to_eye_local);
	float spell = clamp(charged, 0.0, 1.5);
	float at_root = 1.0 - smoothstep(0.0, 0.6, clamp(local.y, 0.0, 1.0));
	float deep = veins_at(local + into * 0.12, 0.07) + veins_at(local + into * 0.24, 0.04) * 0.5;
	vec3 inner = mix(vein.rgb, vein_hot.rgb, smoothstep(0.7, 1.3, spell)) * deep * at_root * (0.06 + spell * 0.75);
	inner += vein.rgb * at_root * at_root * at_root * spell * 0.1;
	// The thin of its edges.
	// (By the pixel, so it is a hairline whatever the facet's shape or how far off it is.)
	float to_edge = min(corner.x, min(corner.y, corner.z)) * 2.0;
	float pixel = max(fwidth(to_edge), 0.0001);
	float edge = 1.0 - smoothstep(pixel * 0.35, pixel * 1.1, to_edge);
	EMISSION = surface + inner + edge_colour.rgb * edge * (0.08 + spell * 0.45);
}
