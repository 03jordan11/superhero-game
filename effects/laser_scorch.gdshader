shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float fade = 1.0;
void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float grain = 0.88 + 0.12 * sin(UV.x * 73.0) * sin(UV.y * 59.0);
	ALBEDO = vec3(0.008, 0.006, 0.005);
	ALPHA = (1.0 - smoothstep(0.38, 1.0, radius)) * grain * fade * 0.88;
}
