shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D facade : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D night_facade : source_color, filter_linear_mipmap, repeat_disable;
uniform float night_amount = 0.0;
uniform float window_brightness = 2.0;
void fragment() {
	vec4 color = texture(facade, UV);
	if (color.a < 0.25) discard;
	ALBEDO = color.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	EMISSION = texture(night_facade, UV).rgb * night_amount * window_brightness;
}
