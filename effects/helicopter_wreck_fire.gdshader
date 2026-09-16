shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float elapsed = 0.0;
void fragment() {
	float height = 1.0 - UV.y;
	float wave = sin(UV.x*27.0-height*9.0+elapsed*7.0)*0.09
		+ sin(UV.x*51.0+height*17.0-elapsed*11.0)*0.04;
	float width = (0.5-height*0.43)+wave;
	float edge = 1.0-smoothstep(width-0.12, width,abs(UV.x-0.5));
	float fade = (1.0-smoothstep(0.65,1.0,height))*smoothstep(0.0,0.12,height);
	ALBEDO = mix(vec3(1.0,0.62,0.07),vec3(0.75,0.07,0.005),height);
	EMISSION = ALBEDO*2.0;
	ALPHA = edge*fade*0.8;
}
