shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

void fragment() {
	float along = 1.0 - UV.y;
	float ribbons = sin(UV.x * 43.0 + along * 17.0 - TIME * 22.0)
		+ 0.5 * sin(UV.x * 91.0 - along * 31.0 + TIME * 29.0);
	float flicker = smoothstep(-0.5, 1.2, ribbons);
	float fade = (1.0 - smoothstep(0.65, 1.0, along)) * smoothstep(0.0, 0.04, along);
	ALBEDO = mix(vec3(1.0, 0.09, 0.005), vec3(1.0, 0.65, 0.08), flicker * (1.0 - along));
	EMISSION = ALBEDO * 2.0;
	ALPHA = fade * (0.12 + flicker * 0.38);
}
