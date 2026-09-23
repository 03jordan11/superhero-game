uniform vec4 warm_amber : source_color;
uniform vec4 soft_yellow : source_color;
uniform vec4 cool_white : source_color;

vec3 window_light_color(vec4 room, float warm_mix) {
	vec3 warm = mix(warm_amber.rgb, soft_yellow.rgb, step(0.5, room.a));
	return mix(warm, cool_white.rgb, step(warm_mix, room.g));
}
