// The candle lane's people as shades (scripts/Visual/Silhouette.gd): one flat figure of the sheet in Mignola's
// ink, nothing drawn inside it, drawn as the nahual's spectre is (spectre.gdshader) but on a card. Its body is
// solid ink; its outline frays into smoke that climbs it, cut hard, the last of each tongue a cold grey; its feet
// are lost in a mist eating up from the floor. All of it gentler than the nahual: a deep charcoal, a softer fray.
// (Its smoke rising off it is Silhouette.gd's wisps.)
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// The sheet and which of its cells is this figure (uv = offset + UV * scale; a mirrored figure's x scale is negative).
uniform sampler2D sheet : filter_linear, repeat_disable;
uniform vec2 cell_scale = vec2(0.25, 0.5);
uniform vec2 cell_offset = vec2(0.0, 0.0);
uniform vec4 ink : source_color = vec4(0.07, 0.068, 0.078, 1.0);
// The fraying's last edge, just before it is gone.
uniform vec4 fray_colour : source_color = vec4(0.26, 0.3, 0.32, 1.0);
uniform sampler3D noise : filter_linear, repeat_enable;
// How far in from its outline it frays (of the cell's width), how fine its fraying is, how fast its smoke climbs.
uniform float fray = 0.018;
// How hard the smoke eats its outline (gentler than the nahual's).
uniform float fray_amount = 1.1;
uniform float grain = 3.0;
uniform float rise = 0.25;
// How much of its foot the mist takes (of the cell's height).
uniform float hem = 0.055;
// How much of it is here (1 whole; 0 gone to smoke).
uniform float presence = 1.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float shape(vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(sheet, cell_offset + uv * cell_scale).a;
}

void fragment() {
	vec2 uv = UV;
	// Its fraying: fine noise drawn up over time.
	vec3 p = world * grain + vec3(0.0, -TIME * rise * grain, 0.0);
	float n = texture(noise, p).r * 0.75 + texture(noise, p * 2.1 + vec3(5.1)).r * 0.25;
	// How deep inside its outline this is.
	float r = fray;
	float around = (shape(uv + vec2(r, 0.0)) + shape(uv - vec2(r, 0.0)) + shape(uv + vec2(0.0, r * 0.5))
		+ shape(uv - vec2(0.0, r * 0.5)) + shape(uv + vec2(r, r * 0.5)) + shape(uv - vec2(r, r * 0.5))
		+ shape(uv + vec2(-r, r * 0.5)) + shape(uv + vec2(r, -r * 0.5))) / 8.0;
	float inner = shape(uv) * around;
	// Its body whole, only its outline eaten by the smoke (nothing of it where none of it is near); its foot eaten by
	// the mist.
	float by_it = smoothstep(0.05, 0.4, max(around, shape(uv)));
	float solid = inner + (n - 0.5) * fray_amount * (1.0 - inner) * by_it - (1.0 - by_it);
	float low = smoothstep(1.0 - hem, 1.0, uv.y);
	solid -= low * (0.4 + n * 0.9);
	// Forming out of its mist from the feet up (and going back to it the same way): above a ragged line rising with
	// its presence, nothing of it yet; its whole outline thin while it forms.
	float up = 1.0 - uv.y;
	solid -= smoothstep(-0.04, 0.04, up - presence * 1.15 + (n - 0.5) * 0.18) * 2.0;
	solid -= (1.0 - presence) * 0.35 * (1.0 - inner);
	// Cut hard where the smoke has eaten it: crisp shapes, not a soft fade.
	if (solid < 0.3) {
		discard;
	}
	// The last of each tongue a cold grey, then the ink.
	ALBEDO = mix(ink.rgb, fray_colour.rgb, 1.0 - smoothstep(0.3, 0.4, solid));
}
