shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float elapsed = 0.0;
uniform float intensity = 0.0;
uniform sampler2D roof_heights : filter_nearest, repeat_disable;
uniform vec2 grid_origin = vec2(0.0);
uniform float grid_width = 36.0;
varying float above_roof;
varying float edge_fade;

void vertex() {
	vec3 strip = INV_VIEW_MATRIX[0].xyz * VERTEX.x + vec3(-VERTEX.y * 0.12, VERTEX.y, 0.0);
	strip.y += 14.0 - mod(elapsed * (22.0 + INSTANCE_CUSTOM.y * 6.0) + INSTANCE_CUSTOM.x * 26.0, 26.0);
	VERTEX = strip;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 map_uv = (world.xz - grid_origin) / grid_width;
	float roof = texture(roof_heights, clamp(map_uv, vec2(0.0), vec2(1.0))).r;
	above_roof = world.y - roof - 0.12;
	edge_fade = smoothstep(0.0, 0.12, min(min(map_uv.x, map_uv.y), min(1.0-map_uv.x, 1.0-map_uv.y)));
}

void fragment() {
	if (above_roof < 0.0) discard;
	float line = (1.0 - abs(UV.x * 2.0 - 1.0)) * sin(UV.y * 3.14159265);
	ALBEDO = vec3(0.62, 0.73, 0.86);
	ALPHA = line * 0.48 * intensity * edge_fade;
}
