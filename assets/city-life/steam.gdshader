shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float elapsed = 0.0;
uniform float density = 0.28;
varying float opacity;
void vertex() {
	float age = fract(elapsed * 0.16 + INSTANCE_CUSTOM.r);
	float phase = INSTANCE_CUSTOM.g * TAU;
	vec3 center = MODEL_MATRIX[3].xyz + vec3(sin(age * 3.0 + phase) * age * 0.8 + age * 1.2, age * 5.0, cos(age * 2.0 + phase) * age * 0.65);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(center, 1.0));
	VERTEX *= 0.4 + age * 1.8;
	opacity = sin(age * PI) * density;
}
void fragment() {
	float radius = length(UV - 0.5);
	if(radius > 0.5) discard;
	ALBEDO = vec3(0.55, 0.62, 0.66);
	ROUGHNESS = 1.0;
	ALPHA = exp(-radius * radius * 20.0) * opacity;
}
