shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2DArray facades : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2DArray masks : filter_nearest_mipmap, repeat_enable;
uniform sampler2DArray rooms : filter_nearest, repeat_disable;
uniform sampler2D material_data : filter_nearest, repeat_disable;
varying flat float layer;
#include "res://assets/buildings/materials/window_palette.gdshaderinc"

void vertex() {
	layer = round(COLOR.r * 255.0) + round(COLOR.g * 255.0) * 256.0;
}

void fragment() {
	int slot = int(layer);
	vec4 tint = texelFetch(material_data, ivec2(slot, 0), 0);
	vec4 surface = texelFetch(material_data, ivec2(slot, 1), 0);
	ALBEDO = texture(facades, vec3(UV, layer)).rgb * tint.rgb;
	ROUGHNESS = surface.x;
	METALLIC = surface.y;
	SPECULAR = surface.z;
	if (surface.w > 0.5) {
		vec4 settings = texelFetch(material_data, ivec2(slot, 2), 0);
		vec4 lighting = texelFetch(material_data, ivec2(slot, 3), 0);
		ivec2 cell = clamp(ivec2(floor(UV2 * settings.xy)), ivec2(0), ivec2(settings.xy) - ivec2(1));
		if (surface.w > 1.5) {
			cell = ivec2(clamp(int(floor(UV2.x)), 0, int(settings.x) - 1), 0);
		}
		vec4 room = texelFetch(rooms, ivec3(cell, slot), 0);
		vec3 color = window_light_color(room, settings.w);
		float lit = 1.0 - step(settings.z, room.r);
		EMISSION = color * texture(masks, vec3(UV, layer)).r * lit * room.b * lighting.x * lighting.y * 0.5;
	}
}
