shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float elapsed = 0.0;
uniform vec4 arc_color : source_color = vec4(0.12, 0.48, 1.0, 1.0);

float hash(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

float jagged(float y, float seed) {
	float cell = y * 18.0;
	return mix(hash(floor(cell) + seed), hash(floor(cell) + 1.0 + seed), fract(cell)) - 0.5;
}

void fragment() {
	float frame = floor(elapsed * 24.0);
	float glow = 0.0;
	float core = 0.0;
	for (int i = 0; i < 3; i++) {
		float seed = frame * 13.7 + float(i) * 71.3;
		float center = 0.22 + float(i) * 0.28;
		float path = center + jagged(UV.y, seed) * 0.28;
		float distance_to_arc = abs(UV.x - path);
		// Short forks split outward from each main jagged strand.
		float branch_y = fract(UV.y * 3.0 + hash(seed));
		float fork = path + (branch_y - 0.5) * (i == 1 ? -0.48 : 0.48);
		float branch = abs(UV.x - fork) + smoothstep(0.28, 0.48, abs(branch_y - 0.5)) * 0.2;
		distance_to_arc = min(distance_to_arc, branch);
		float flicker = 0.55 + 0.45 * hash(seed + 2.0);
		glow += exp(-distance_to_arc * 90.0) * flicker;
		core += (1.0 - smoothstep(0.0015, 0.0045, distance_to_arc)) * flicker;
	}
	float ends = smoothstep(0.0, 0.09, UV.y) * smoothstep(0.0, 0.09, 1.0 - UV.y);
	ALBEDO = arc_color.rgb;
	EMISSION = (arc_color.rgb * glow * 2.2 + vec3(0.75, 0.95, 1.0) * core * 3.0) * ends;
	ALPHA = clamp((glow + core) * ends, 0.0, 1.0);
}
