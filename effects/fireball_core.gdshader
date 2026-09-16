shader_type spatial;
render_mode unshaded;
varying vec3 surface_position;
void vertex() {
	surface_position = normalize(VERTEX);
}
void fragment() {
	vec3 p = surface_position;
	float flow = p.y * 12.0 + sin(p.x * 8.0 + TIME * 4.0) * 2.0
		+ sin(p.z * 8.0 - TIME * 3.0) * 2.0 - TIME * 7.0;
	float swirl = sin(flow) + 0.4 * sin(dot(p, vec3(23.0, 17.0, 19.0)) + TIME * 11.0);
	float hot = smoothstep(-0.8, 1.1, swirl);
	vec3 fire = mix(vec3(0.9, 0.045, 0.002), vec3(1.0, 0.85, 0.25), hot);
	ALBEDO = fire;
	EMISSION = fire * (1.0 + hot * 1.5);
}
