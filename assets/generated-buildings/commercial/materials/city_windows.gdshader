shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D facade_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D window_mask : filter_nearest_mipmap, repeat_enable;
// Numeric room data must not undergo sRGB conversion or mip/filter blending.
uniform sampler2D room_data : filter_nearest, repeat_disable;
uniform vec4 facade_tint : source_color = vec4(1.0);
uniform float facade_roughness = 0.9;
uniform float facade_metallic = 0.0;
uniform float facade_specular = 0.5;
uniform float occupancy : hint_range(0.0, 1.0) = 0.5;
uniform float warm_fraction : hint_range(0.0, 1.0) = 0.75;
uniform float brightness : hint_range(0.0, 3.0) = 1.0;
uniform float emission_energy = 0.0;
#include "res://assets/buildings/materials/window_palette.gdshaderinc"

void fragment() {
	ALBEDO = texture(facade_albedo, UV).rgb * facade_tint.rgb;
	ROUGHNESS = facade_roughness;
	METALLIC = facade_metallic;
	SPECULAR = facade_specular;
	vec4 room = texture(room_data, UV2);
	vec3 color = window_light_color(room, warm_fraction);
	float lit = 1.0 - step(occupancy, room.r);
	// The legacy controller supplies 2x energy. Normalize it so the palette keeps
	// its amber/blue color instead of clipping toward white at default brightness.
	EMISSION = color * texture(window_mask, UV).r * lit * room.b * emission_energy * brightness * 0.5;
}
