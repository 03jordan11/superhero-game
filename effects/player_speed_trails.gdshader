shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	VERTEX.x += sin(UV.y * 8.0 - TIME * 9.0) * UV.y * 0.045;
}

void fragment() {
	float width = pow(max(0.0, 1.0 - abs(UV.x * 2.0 - 1.0)), 1.4);
	float tail = sin(UV.y * 3.14159265);
	float gust = 0.65 + 0.35 * sin(UV.y * 15.0 - TIME * 12.0);
	ALBEDO = vec3(0.78, 0.9, 1.0);
	ALPHA = width * tail * gust * intensity * 0.34;
}
