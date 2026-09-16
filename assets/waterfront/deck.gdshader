shader_type spatial;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz;
	float row = floor(p.y / 0.42);
	float variation = fract(sin(row * 17.71) * 4358.54);
	vec2 board = vec2(p.x / 3.5 + variation, p.y / 0.42);
	vec2 edge = min(fract(board), 1.0 - fract(board));
	float seams = 1.0 - smoothstep(0.005, 0.025, min(edge.x, edge.y));
	float detail = 1.0 - smoothstep(40.0, 150.0, length(CAMERA_POSITION_WORLD - world_position));
	ALBEDO = mix(vec3(0.14, 0.088, 0.049), vec3(0.21, 0.143, 0.085), variation * detail);
	ALBEDO *= 1.0 - seams * 0.6 * detail;
	ROUGHNESS = 0.86;
}
