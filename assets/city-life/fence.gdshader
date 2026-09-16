shader_type spatial;
render_mode cull_disabled, shadows_disabled;
varying vec3 p;
void vertex() { p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float a = abs(sin((p.x+p.z+p.y)*12.0));
	float b = abs(sin((p.x+p.z-p.y)*12.0));
	ALBEDO=vec3(0.21,0.25,0.25);
	METALLIC=0.6;
	ROUGHNESS=0.7;
	ALPHA=min(a,b)<0.12?1.0:0.0;
	ALPHA_SCISSOR_THRESHOLD=0.5;
}
