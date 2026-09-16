shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform sampler2D panorama : filter_linear, repeat_disable;
uniform float night_amount = 0.0;
void fragment() {
	vec4 source=texture(panorama,UV);
	vec3 daylight=mix(vec3(0.17,0.25,0.30),vec3(0.36,0.46,0.56),source.r);
	ALBEDO=mix(daylight,vec3(0.008,0.015,0.031),night_amount);
	ALPHA=source.a;
	ALPHA_SCISSOR_THRESHOLD=0.5;
}
