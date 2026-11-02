shader_type spatial;
render_mode unshaded, cull_disabled;

// Subtle floor: a dark base that lightens toward the centre with a faint
// world-space grid and a soft vignette toward the horizon.

uniform vec3 center_color : source_color = vec3(0.13, 0.14, 0.17);
uniform vec3 edge_color : source_color = vec3(0.035, 0.04, 0.05);
uniform vec3 grid_color : source_color = vec3(0.20, 0.22, 0.27);
uniform float grid_spacing = 0.5;
uniform float center_radius = 1.5;
uniform float fade_radius = 7.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = world_pos.xz;
	float r = length(p);
	float fade = 1.0 - smoothstep(center_radius, fade_radius, r);
	vec3 col = mix(edge_color, center_color, fade);

	// Faint world grid.
	float g = max(
		abs(fract(p.x / grid_spacing + 0.5) - 0.5),
		abs(fract(p.y / grid_spacing + 0.5) - 0.5)
	);
	float line = 1.0 - smoothstep(0.02, 0.035, g);
	col = mix(col, grid_color, line * fade * 0.7);

	col += (hash(p * 90.0) - 0.5) * 0.001;

	ALBEDO = col;
}