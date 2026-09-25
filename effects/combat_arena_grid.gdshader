shader_type spatial;
render_mode unshaded;

uniform vec3 grid_color : source_color = vec3(0.02, 0.9, 0.32);
uniform float cell_size = 4.0;
uniform float line_width = 0.025;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coordinate = world_position.xz / cell_size;
	vec2 edge = abs(fract(coordinate - 0.5) - 0.5) * cell_size;
	vec2 antialias = max(fwidth(coordinate) * cell_size, vec2(0.001));
	vec2 lines = vec2(1.0) - smoothstep(vec2(line_width), vec2(line_width) + antialias, edge);
	float grid = max(lines.x, lines.y);
	float distance_fade = 1.0 - smoothstep(70.0, 240.0, length(VERTEX));
	ALBEDO = vec3(0.002, 0.007, 0.005) + grid_color * grid * distance_fade * 0.65;
	EMISSION = grid_color * grid * distance_fade * 0.5;
}
