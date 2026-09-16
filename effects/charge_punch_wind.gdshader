shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 wind_color : source_color = vec4(0.82, 0.91, 1.0, 0.5);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float power : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float angle = UV.x * 6.283185;
	float head = progress * 1.3;
	// Broken pressure arcs followed by thin, fast-moving air streaks.
	float curl = 0.025 * sin(angle * 3.0 + progress * 8.0);
	float front = exp(-pow((UV.y - head + curl) / 0.055, 2.0));
	float second = 0.45 * exp(-pow((UV.y - head + 0.17 - curl) / 0.035, 2.0));
	float broken_arc = smoothstep(-0.3, 0.55, sin(angle * 3.0 + UV.y * 10.0 - progress * 5.0));
	float strands = pow(max(0.0, sin(angle * 13.0 + UV.y * 8.0 - progress * 4.0)), 18.0);
	float wake = smoothstep(head - 0.38, head - 0.1, UV.y) * (1.0 - smoothstep(head - 0.03, head + 0.03, UV.y));
	float ends = smoothstep(0.025, 0.1, UV.y) * (1.0 - smoothstep(0.8, 1.0, UV.y));
	float fade = smoothstep(0.0, 0.07, progress) * (1.0 - smoothstep(0.55, 1.0, progress));
	ALBEDO = wind_color.rgb;
	ALPHA = clamp(((front + second) * broken_arc + strands * wake * 0.65) * ends * fade * wind_color.a * mix(0.65, 1.0, power), 0.0, 0.7);
}
