shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float post = 1.0-step(0.07,mod(UV.x,6.0));
	float rails = max(1.0-step(0.035,abs(UV.y-1.04)),1.0-step(0.025,abs(UV.y-0.48)));
	ALBEDO=vec3(0.07,0.10,0.115);
	ROUGHNESS=0.85;
	ALPHA=max(post,rails);
	ALPHA_SCISSOR_THRESHOLD=0.5;
}
