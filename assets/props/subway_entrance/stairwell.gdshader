shader_type spatial;
render_mode unshaded;

// A painted, sealed stairwell lets the prop sit on an uncut city sidewalk.
void fragment() {
	float depth = 1.0 - UV.y;
	float steps = depth * 8.0;
	float tread = 1.0 - smoothstep(0.70, 0.95, fract(steps));
	float fade = pow(1.0 - depth, 2.0);
	vec3 dark = vec3(0.009, 0.013, 0.018);
	ALBEDO = dark + vec3(0.085, 0.095, 0.10) * tread * fade;
}
