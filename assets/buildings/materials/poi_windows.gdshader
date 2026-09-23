shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://assets/buildings/materials/window_palette.gdshaderinc"
uniform sampler2D facade_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D window_mask : filter_linear_mipmap, repeat_enable;
uniform sampler2D room_data : filter_nearest, repeat_disable;
uniform vec4 facade_tint : source_color = vec4(1.0);
uniform float facade_roughness = 0.75;
uniform float facade_metallic = 0.0;
uniform float facade_specular = 0.5;
uniform float occupancy = 0.1;
uniform float warm_fraction = 0.6;
uniform float brightness = 2.0;
uniform float emission_energy = 0.0;
uniform float room_count = 1.0;
uniform bool curtain_windows = false;

void fragment() {
	ALBEDO = texture(facade_albedo, UV).rgb * facade_tint.rgb;
	ROUGHNESS = facade_roughness;
	METALLIC = facade_metallic;
	SPECULAR = facade_specular;
	float room_index = UV2.x;
	if (curtain_windows) {
		// The hospital's curtain texture contains 4 columns and 12 85-pixel rows.
		float row = floor(UV.y) * 12.0 + floor(clamp((fract(UV.y) * 1024.0 - 4.0) / 85.0, 0.0, 11.0));
		room_index += clamp(floor(UV.x * 4.0), 0.0, 3.0) + (row - UV2.y) * 4.0;
	}
	vec4 room = texture(room_data, vec2((room_index + 0.5) / room_count, 0.5));
	float lit = 1.0 - step(occupancy, room.r);
	EMISSION = window_light_color(room, warm_fraction) * texture(window_mask, UV).r
		* lit * room.b * emission_energy * brightness * 0.5;
}
