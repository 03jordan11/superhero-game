shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float elapsed = 0.0;
uniform float night_amount = 0.0;
uniform float brightness = 5.0;
uniform float drift = 1.0;
varying float pulse;
varying vec3 glow_color;
void vertex() {
	float phase = INSTANCE_CUSTOM.r * TAU;
	float t = elapsed * (0.45 + INSTANCE_CUSTOM.g * 0.5);
	vec3 motion = vec3(sin(t + phase) * 1.8, sin(t * 1.31 + phase) * 0.55, cos(t * 0.73 + phase) * 1.5) * drift;
	vec3 center = MODEL_MATRIX[3].xyz + motion;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(center, 1.0));
	pulse = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(t * 2.7 + phase), 2.0);
	glow_color = vec3(1.0, 0.76, 0.2);
}
void fragment() {
	float radius = length(UV - vec2(0.5));
	if (radius > 0.5 || night_amount < 0.001) discard;
	ALBEDO = glow_color * exp(-radius * radius * 28.0) * pulse * brightness * night_amount;
}
