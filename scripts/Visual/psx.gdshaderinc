// The PS1's wobble, shared by every shader that draws the world (and by the
// twins Retro makes of the plain materials): a vertex snapped to a grid of
// psx_snap_lines screen lines, so edges step and polygons shiver a little as
// they move, the way a console without sub-pixel precision drew them. Retro
// sets both globals (psx_snap_lines 0: smooth). Only the main view snaps:
// a pass whose frame is not the screen's shape (a light's square shadow
// map) is left smooth, or shadows would stripe.
//
//   POSITION = psx_snapped(PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)), VIEWPORT_SIZE);

global uniform float psx_snap_lines;
global uniform float psx_snap_aspect;

vec4 psx_snapped(vec4 clip, vec2 viewport) {
	if (psx_snap_lines <= 0.0 || clip.w <= 0.0001 || viewport.y <= 0.0 || abs(viewport.x / viewport.y - psx_snap_aspect) > 0.02) {
		return clip;
	}

	vec2 grid = vec2(psx_snap_lines * viewport.x / viewport.y, psx_snap_lines) * 0.5;
	vec2 ndc = clip.xy / clip.w;
	clip.xy = floor(ndc * grid + 0.5) / grid * clip.w;
	return clip;
}
