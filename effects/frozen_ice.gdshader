shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform float cracks : hint_range(0.0, 1.0) = 0.0;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	vec3 p = local_position;
	float veins = abs(sin(p.x * 14.0 + p.y * 9.0 + sin(p.z * 13.0)));
	float fractures = 1.0 - smoothstep(0.02, 0.08 + cracks * 0.1, veins);
	float frost = smoothstep(0.15, 0.85, sin(p.y * 19.0 + sin(p.x * 22.0) + p.z * 17.0) * 0.5 + 0.5);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = mix(vec3(0.13, 0.48, 0.72), vec3(0.8, 0.96, 1.0), clamp(frost * 0.3 + fractures * 0.65 + rim * 0.4, 0.0, 1.0));
	ROUGHNESS = 0.18;
	METALLIC = 0.15;
	EMISSION = vec3(0.16, 0.5, 0.7) * (0.15 + fractures * 0.5 + rim * 0.35);
	ALPHA = 0.32 + frost * 0.16 + fractures * 0.32 + rim * 0.15;
}
