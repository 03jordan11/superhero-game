shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
void fragment() {
	float along = 1.0 - UV.y;
	float mist = sin(UV.x * 53.0 + along * 25.0 - TIME * 16.0)
		+ 0.5 * sin(UV.x * 107.0 - along * 35.0 + TIME * 12.0);
	float crystal = smoothstep(0.5, 1.3, mist);
	float fade = (1.0 - smoothstep(0.7, 1.0, along)) * smoothstep(0.0, 0.05, along);
	ALBEDO = mix(vec3(0.2, 0.6, 1.0), vec3(0.85, 0.98, 1.0), crystal);
	EMISSION = ALBEDO * 1.2;
	ALPHA = fade * (0.12 + crystal * 0.35);
}
