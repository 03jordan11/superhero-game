shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D landscape : source_color, filter_linear_mipmap, repeat_disable;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 night_tint : source_color = vec3(0.08, 0.13, 0.17);
varying float wall_height;

void vertex() {
	wall_height = VERTEX.y;
}

void fragment() {
	// Normalize by the interpolated panel height; ordinary UV interpolation
	// introduces diagonal steps where the shoreline panels taper.
	float v = 1.0 - (wall_height - UV2.y) / max(UV2.x - UV2.y, 0.01);
	vec4 painted = texture(landscape, vec2(UV.x, clamp(v, 0.0, 1.0)));
	ALBEDO = mix(painted.rgb, night_tint * mix(0.85, 1.5, painted.r), night_amount);
	ALPHA = painted.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
