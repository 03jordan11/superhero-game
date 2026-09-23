shader_type spatial;
// COLOR: linear albedo. UV: painted masonry mask / height. UV2: glow / roughness.
uniform float night_amount = 0.0;
uniform vec3 course_color : source_color = vec3(0.16078432,0.20784314,0.23529412);
uniform vec3 lamp_emission : source_color = vec3(1.0,0.776471,0.52549);
void fragment() {
	ALBEDO = COLOR.rgb;
	if (UV.x > 0.5) {
		float band_distance = min(abs(UV.y+1.6),min(abs(UV.y+3.2),abs(UV.y+4.8)));
		float width = max(fwidth(UV.y),0.001);
		float band = clamp((0.0275+width*0.5-band_distance)/width,0.0,1.0);
		band *= min(1.0,0.055/width); // Subpixel courses fade instead of becoming thick dark bands.
		ALBEDO = mix(ALBEDO,course_color,band);
	}
	ROUGHNESS = UV2.y;
	EMISSION = lamp_emission * UV2.x * night_amount;
}
