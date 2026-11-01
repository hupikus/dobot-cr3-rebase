shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// Meter grid overlay for the table top. Draws centimetre, decimetre and metre
// lines in white, at different weights.

uniform vec2 plane_size = vec2(1.4, 0.9);
uniform vec3 line_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float cm_width = 0.0016;
uniform float dm_width = 0.0038;
uniform float m_width = 0.0075;
uniform float cm_alpha = 0.09;
uniform float dm_alpha = 0.32;
uniform float m_alpha = 0.85;

float grid_mask(float coord, float spacing, float width) {
	// Distance (in metres) to the nearest line at a multiple of `spacing`,
	// smoothed into a soft band of the requested width.
	float d = abs(fract(coord / spacing + 0.5) - 0.5) * spacing;
	float aa = max(fwidth(coord), 1e-5);
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + aa, d);
}

void fragment() {
	vec2 p = (UV - 0.5) * plane_size; // metres, centred on the table
	float cm = max(grid_mask(p.x, 0.01, cm_width), grid_mask(p.y, 0.01, cm_width));
	float dm = max(grid_mask(p.x, 0.10, dm_width), grid_mask(p.y, 0.10, dm_width));
	float m = max(grid_mask(p.x, 1.0, m_width), grid_mask(p.y, 1.0, m_width));

	float a = max(max(cm * cm_alpha, dm * dm_alpha), m * m_alpha);
	ALBEDO = line_color;
	ALPHA = a;
}