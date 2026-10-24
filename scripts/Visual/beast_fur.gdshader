// Empower's charge in the gun hand (HandSlot.set_pelt): passes chained on
// the arms' Skin surface after its own look, on the gun hand's side only.
// Shell 0 darkens the skin to a dusky umber with bone-white veins in it,
// glowing with the heartbeat (`veins`); shells 1.. stand out along the
// skin's normals as fur, sparser the further out, darker at the root and
// pale at the tips, lit by the scene (unlit, it glowed tan at night); the
// veins glow of themselves. `bristle` throws the fur further out as the
// charge is spent. Drawn as the arms are: at their own field of view and
// depth squeeze.
shader_type spatial;
render_mode cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec4 dusk : source_color = vec4(0.16, 0.1, 0.06, 1.0);
uniform vec4 root : source_color = vec4(0.06, 0.04, 0.025, 1.0);
uniform vec4 tip : source_color = vec4(0.3, 0.22, 0.15, 1.0);
uniform vec4 vein : source_color = vec4(0.85, 0.78, 0.64, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float shell = 0.0;
uniform float shells = 3.0;
uniform float reach = 0.0022;
uniform float bristle = 0.0;
uniform float veins = 0.0;
// Which side of the arms' space is the gun arm (+1 or -1), from where.
uniform float side_sign = 1.0;
uniform float side_from = 0.06;
uniform float z_clip = 1.0;
uniform float fov_override = 0.0;

varying float on_side;
varying vec3 model_at;

void vertex() {
	Z_CLIP_SCALE = z_clip;

	if (fov_override > 0.0) {
		float f = 1.0 / tan(radians(fov_override) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		PROJECTION_MATRIX[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		PROJECTION_MATRIX[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
	}

	model_at = VERTEX;
	on_side = smoothstep(side_from, side_from + 0.1, VERTEX.x * side_sign);
	VERTEX += NORMAL * shell * reach * amount * (1.0 + bristle * 1.5);
}

void fragment() {
	if (shell < 0.5) {
		// The skin gone dusky, and its veins: thin lines where the noise
		// crosses its middle, running along the arm.
		float n = texture(noise, vec2(model_at.x * 3.0 + model_at.z * 3.0, model_at.y * 1.2)).r;
		float line = 1.0 - smoothstep(0.005, 0.014, abs(n - 0.5));
		ALBEDO = dusk.rgb;
		ROUGHNESS = 0.8;
		EMISSION = vein.rgb * line * veins * 2.5;
		ALPHA = amount * on_side * max(0.6, line * veins);
	} else {
		// Strands: fine noise drawn out along the arm, fewer the further out.
		float n = texture(noise, vec2(model_at.x * 110.0 + model_at.z * 110.0, model_at.y * 30.0)).r;
		float out_by = shell / shells;
		float keep = step(0.46 + out_by * 0.14, n);
		ALBEDO = mix(root.rgb, tip.rgb, out_by);
		ROUGHNESS = 1.0;
		ALPHA = keep * amount * on_side * (1.0 - out_by * 0.3);
	}

	if (ALPHA < 0.01) {
		discard;
	}
}
