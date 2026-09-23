shader_type spatial;

uniform sampler2D asphalt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 paint_color : source_color = vec4(0.78, 0.80, 0.76, 1.0);
uniform float paint_fade_start_m = 170.0;
uniform float paint_fade_end_m = 200.0;
instance uniform vec2 lot_size_m = vec2(30.0, 36.0);
instance uniform float stall_width_m = 2.6;
instance uniform float stall_depth_m = 5.2;
instance uniform float aisle_width_m = 6.0;
const float EDGE = 0.6;
const float PAINT_HALF_WIDTH = 0.045;
varying vec2 position_m;
varying vec2 dimensions_m;
varying vec3 world_position;

void vertex() {
	// Include editor/parent scaling: both paving grain and bays keep their size.
	vec2 scale_m = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
	position_m = VERTEX.xz * scale_m;
	dimensions_m = lot_size_m * scale_m;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float line(float distance_m, float aa) {
	return 1.0 - smoothstep(PAINT_HALF_WIDTH, PAINT_HALF_WIDTH + aa, abs(distance_m));
}

void fragment() {
	vec3 base = texture(asphalt, world_position.xz / 4.0).rgb;
	vec2 aa = max(fwidth(position_m), vec2(0.005));
	// A clear aisle down the right edge connects all rows; each row also has
	// its own driving aisle. Only complete spaces AND complete aisles are drawn.
	float columns = floor(max(0.0, dimensions_m.x - EDGE * 2.0 - aisle_width_m) / stall_width_m);
	float pitch = stall_depth_m + aisle_width_m;
	float rows = floor(max(0.0, dimensions_m.y - EDGE * 2.0) / pitch);
	float paint = 0.0;
	if (columns >= 1.0 && rows >= 1.0) {
		vec2 extent = vec2(columns * stall_width_m, rows * pitch);
		vec2 start = vec2(-dimensions_m.x * 0.5 + EDGE, -extent.y * 0.5);
		vec2 p = position_m - start;
		float row_index = clamp(floor(p.y / pitch), 0.0, rows - 1.0);
		float row_z = p.y - row_index * pitch;
		float boundary = mod(p.x + stall_width_m * 0.5, stall_width_m) - stall_width_m * 0.5;
		float x_mask = smoothstep(-PAINT_HALF_WIDTH-aa.x, -PAINT_HALF_WIDTH, p.x)
			* (1.0-smoothstep(extent.x+PAINT_HALF_WIDTH, extent.x+PAINT_HALF_WIDTH+aa.x, p.x));
		float stall_mask = smoothstep(-PAINT_HALF_WIDTH-aa.y, -PAINT_HALF_WIDTH, row_z)
			* (1.0-smoothstep(stall_depth_m, stall_depth_m+aa.y, row_z));
		// U-shaped bays: dividers and a back line, with the aisle-facing end open.
		paint = max(line(boundary, aa.x)*stall_mask, line(row_z, aa.y))*x_mask;
	}
	// Fade only the markings, per surface point: large lots never pop as a whole.
	float camera_distance = distance(world_position, CAMERA_POSITION_WORLD);
	paint *= 1.0 - smoothstep(paint_fade_start_m, max(paint_fade_start_m + 0.01, paint_fade_end_m), camera_distance);
	ALBEDO = mix(base, paint_color.rgb, paint);
	ROUGHNESS = 0.98;
}
