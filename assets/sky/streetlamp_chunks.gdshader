shader_type spatial;
uniform float night_amount = 0.0;
uniform vec3 metal_color : source_color = vec3(0.055,0.065,0.075);
uniform vec3 bulb0 : source_color;
uniform vec3 bulb1 : source_color;
uniform vec3 bulb2 : source_color;
uniform vec3 emission0 : source_color;
uniform vec3 emission1 : source_color;
uniform vec3 emission2 : source_color;
varying vec3 bulb_color;
varying vec3 glow_color;
varying float lens;
void vertex() {
	lens = COLOR.r;
	bulb_color = INSTANCE_CUSTOM.r < 0.5 ? bulb0 : (INSTANCE_CUSTOM.r < 1.5 ? bulb1 : bulb2);
	glow_color = INSTANCE_CUSTOM.r < 0.5 ? emission0 : (INSTANCE_CUSTOM.r < 1.5 ? emission1 : emission2);
}
void fragment() {
	ALBEDO = mix(metal_color,bulb_color,lens);
	METALLIC = 0.65*(1.0-lens);
	ROUGHNESS = mix(0.42,1.0,lens);
	EMISSION = glow_color*lens*5.0*night_amount;
}
