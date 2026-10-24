// The librarian's shadow (LibraryShadow.gd) thrown into a box over a case's front, its picture one frame (`frame`) of
// a sheet of his walk (`cells` across and down, the first top left): each pixel's surface found from
// the depth buffer, and where it lies in the box, the picture's black laid over what is drawn there, lit or glowing
// (the shop's painted look carries its light in emission, which a decal's albedo cannot darken). Surfaces turned away
// from the box's axis (floors, the tops of boards) let it fade; anything in front of the box keeps it off.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, blend_mix, shadows_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D picture : filter_linear_mipmap, repeat_disable;
// The box's size (m: across, up, through), how dark it is now, whether the picture is turned round.
uniform vec3 size = vec3(1.0, 2.0, 0.5);
uniform float darkness = 0.0;
uniform bool flip = false;
uniform vec2 cells = vec2(1.0, 1.0);
uniform float frame = 0.0;

varying mat4 to_box;

void vertex() {
	to_box = inverse(MODEL_MATRIX);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 at = (to_box * vec4(world, 1.0)).xyz / size;
	if (any(greaterThan(abs(at), vec3(0.5)))) {
		discard;
	}
	vec2 uv = vec2(at.x + 0.5, 0.5 - at.y);
	if (flip) {
		uv.x = 1.0 - uv.x;
	}
	// (Within its cell, kept a texel inside so its neighbour never bleeds in.)
	vec2 cell = vec2(mod(frame, cells.x), floor(frame / cells.x));
	uv = (cell + clamp(uv, vec2(0.004), vec2(0.996))) / cells;
	// (The surface's way, from how its points change across the screen, against the box's axis.)
	vec3 normal = normalize(cross(dFdx(world), dFdy(world)));
	float facing = abs(dot(normal, normalize(MODEL_MATRIX[2].xyz)));
	ALBEDO = vec3(0.0);
	ALPHA = texture(picture, uv).a * darkness * smoothstep(0.35, 0.65, facing);
}
