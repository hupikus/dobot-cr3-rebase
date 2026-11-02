shader_type sky;

uniform vec3 horizon_color : source_color = vec3(0.14, 0.16, 0.20);
uniform vec3 zenith_color : source_color = vec3(0.06, 0.07, 0.10);
uniform float gradient_power : hint_range(0.1, 4.0) = 0.8;
uniform float grain : hint_range(0.0, 0.1) = 0.004;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453) * 0.1 ;
}

void sky() {
	float t = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(horizon_color, zenith_color, pow(t, gradient_power));
	col += (hash(EYEDIR.xz * 900.0) - 0.5) * grain;
	COLOR = col;
}