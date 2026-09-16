shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D facade_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D window_mask : filter_nearest_mipmap, repeat_enable;
uniform sampler2D occupied_rooms : source_color, filter_nearest, repeat_disable;
uniform vec4 facade_tint : source_color = vec4(1.0);
uniform float facade_roughness = 0.87;
uniform float emission_energy : hint_range(0.0, 5.0) = 0.0;
varying vec3 facade_normal;
void vertex() { facade_normal = NORMAL; }
void fragment() {
	ALBEDO = texture(facade_albedo, UV).rgb * facade_tint.rgb;
	ROUGHNESS = facade_roughness;
	// UVs span real floors/bays; only the architectural window outlines repeat.
	float face = mod(floor((atan(facade_normal.z, facade_normal.x) + 3.14159265) * 4.0 / 3.14159265 + 0.5), 8.0);
	vec2 room = floor(UV * 4.0 + 0.0001);
	vec2 atlas_uv = (vec2(face * 16.0 + clamp(room.x, 0.0, 15.0), clamp(room.y, 0.0, 63.0)) + 0.5) / vec2(128.0, 64.0);
	vec3 office = texture(occupied_rooms, atlas_uv).rgb;
	EMISSION = office * texture(window_mask, UV).r * emission_energy;
}
