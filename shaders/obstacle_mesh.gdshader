shader_type spatial;

// Presentation for obstacle meshes that come from 3D-scanning software: the
// geometry is typically noisy and deformed, so it is shown matte with a fresnel
// rim and a soft animated scan band that makes the real topology easy to read.

uniform vec3 base_color : source_color = vec3(0.42, 0.15, 0.11);
uniform vec3 rim_color : source_color = vec3(1.0, 0.55, 0.35);
uniform vec3 scan_color : source_color = vec3(1.0, 0.72, 0.5);
uniform float rim_power : hint_range(0.5, 6.0) = 2.5;
uniform float scan_density = 7.0;
uniform float scan_speed = 0.35;
uniform float scan_strength : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float band = 0.5 + 0.5 * sin(world_pos.y * scan_density - TIME * scan_speed * 6.2831853);
	band = smoothstep(0.78, 1.0, band);

	ALBEDO = mix(base_color, scan_color, band * scan_strength);
	EMISSION = rim_color * rim * 0.5 + scan_color * band * 0.25;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}