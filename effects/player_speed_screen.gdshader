shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 offset = SCREEN_UV - vec2(0.5);
	float edge = smoothstep(0.16, 0.56, length(offset));
	// A wider, stronger radial pull makes high speed readable in peripheral vision.
	// Preserve the center for aiming and keep sampling inside the screen bounds.
	vec2 uv = SCREEN_UV - offset * edge * intensity * 0.14;
	vec3 scene = textureLod(screen_texture, uv, 0.0).rgb;
	COLOR = vec4(scene * (1.0 - edge * intensity * 0.40), 1.0);
}
