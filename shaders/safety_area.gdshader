shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

// Translucent shell that inflates an obstacle outward by `thickness`, showing
// the mesh "safe area" used for collision checks against noisy scanned meshes.

uniform float thickness = 0.02;
uniform vec3 shell_color : source_color = vec3(0.15, 0.75, 1.0);

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = shell_color;
	// Slightly stronger at grazing angles so the shell reads as a boundary.
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALPHA = 0.12 + edge * 0.35;
}