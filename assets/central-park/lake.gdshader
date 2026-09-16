shader_type spatial;
render_mode cull_back;
uniform float elapsed = 0.0;
uniform float night_amount = 0.0;
varying vec2 water_position;
void vertex() {
	water_position = VERTEX.xz;
}
void fragment() {
	vec2 p = water_position;
	float a = p.x * 0.33 + p.y * 0.19 + elapsed * 0.85;
	float b = p.y * 0.41 - p.x * 0.14 - elapsed * 0.6;
	float c = (p.x + p.y) * 0.71 + sin(p.x * 0.11) * 1.3 + elapsed * 0.5;
	float ripple = (sin(a) + sin(b) + sin(c)) / 3.0;
	ALBEDO = mix(vec3(0.025, 0.16, 0.17), vec3(0.007, 0.035, 0.065), night_amount) + vec3(0.002) * ripple;
	// Wave slopes are world-aligned; transform to view space for lighting.
	float dx = 0.025 * cos(a) - 0.009 * cos(b) + (0.71 + 0.143 * cos(p.x * 0.11)) * 0.022 * cos(c);
	float dz = 0.014 * cos(a) + 0.027 * cos(b) + 0.016 * cos(c);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-dx, 1.0, -dz)), 0.0)).xyz);
	METALLIC = 0.5;
	ROUGHNESS = 0.2 + 0.04 * ripple;
	SPECULAR = 0.75;
}
