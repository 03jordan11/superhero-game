shader_type spatial;
uniform float night_amount = 0.0;
uniform sampler2D paving : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size = 4.0;
uniform vec3 warm_emission : source_color = vec3(1.0,0.7372549,0.44705883);
uniform vec3 cool_emission : source_color = vec3(0.635294,0.823529,0.909804);
uniform vec3 iron_color : source_color = vec3(0.160784,0.207843,0.235294);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.82;
	if (UV2.y > 0.5 && UV2.y < 1.5) {
		ALBEDO = texture(paving,world_position.xz/tile_size).rgb;
		ROUGHNESS = 0.98;
	} else if (UV2.y > 1.5) {
		// Distant container ribs and door bars are painted, not separate boxes.
		float d = UV2.y < 2.5 ? abs(mod(UV.x+1.0,2.0)-1.0) : min(abs(UV.x-1.5),abs(UV.x+1.5));
		float width = max(fwidth(UV.x),0.001);
		float half_width = UV2.y < 2.5 ? 0.065 : 0.04;
		float band = clamp((half_width+width*0.5-d)/width,0.0,1.0)*min(1.0,2.0*half_width/width);
		ALBEDO = mix(ALBEDO,iron_color,band*step(abs(UV.y),1.3));
	}
	EMISSION = (UV2.x < 0.0 ? cool_emission : warm_emission)*abs(UV2.x)*night_amount;
}
