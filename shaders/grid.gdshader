shader_type spatial;
render_mode unshaded, cull_disabled;


uniform vec3 edge_color : source_color = vec3(0.035, 0.04, 0.05);
uniform vec3 grid_color : source_color = vec3(0.20, 0.22, 0.27);
uniform float grid_spacing = 0.05;

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
	vec3 col = edge_color;

	// Faint world grid.
	float g = max(
		abs(fract(p.x / grid_spacing + 0.5) - 0.5),
		abs(fract(p.y / grid_spacing + 0.5) - 0.5)
	);
	float line = 1.0 - smoothstep(0.02, 0.035, g);
	col = mix(col, grid_color, line);

	ALBEDO = col;
}