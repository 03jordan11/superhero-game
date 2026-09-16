shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float elapsed = 0.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float ripple = sin(world_position.x * 0.7 + world_position.z * 0.46 - elapsed * 1.5);
	float fleck = sin(world_position.x * 2.7 - world_position.z * 1.3 + elapsed * 0.5);
	ALBEDO = vec3(0.6, 0.78, 0.75);
	ROUGHNESS = 0.8;
	ALPHA = COLOR.a * (0.18 + 0.35 * smoothstep(-0.3, 0.8, ripple * fleck));
}
