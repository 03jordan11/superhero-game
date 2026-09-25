shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float elapsed = 0.0;
uniform float lifetime = 1.0;
uniform bool preview = false;
uniform bool upright = false;
uniform bool radial = false;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float noise(float n) { return mix(hash(floor(n)), hash(floor(n) + 1.0), fract(n)); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float ring = smoothstep(0.95, 0.97, radius) * (1.0 - smoothstep(0.995, 1.0, radius));
	float energy = 0.0;
	float age = clamp(elapsed / max(lifetime, 0.001), 0.0, 1.0);
	float frame = floor(elapsed * 25.0);
	if (preview) {
		ALBEDO = vec3(1.0);
		EMISSION = vec3(1.4) * ring;
		ALPHA = ring;
	} else {
		if (upright) {
			// Forking arcs climb above the surface, fading toward their tips.
			for (int i = 0; i < 7; i++) {
				float seed = float(i) * 31.7 + frame;
				float path = 0.08 + float(i) * 0.14 + (noise(UV.y * 15.0 + seed) - 0.5) * 0.1;
				float d = abs(UV.x - path);
				energy += exp(-d * 190.0) * (1.0 - UV.y) * smoothstep(0.0, 0.12, UV.y);
			}
		} else {
			float angle = atan(p.y, p.x);
			float jagged = (noise(radius * 24.0 + frame * 19.0) - 0.5) * 0.6;
			float spoke = abs(sin(angle * 9.0 + jagged));
			energy = exp(-spoke * 42.0) * smoothstep(0.015, 0.12, radius);
			energy += exp(-abs(radius - (0.2 + age * 0.8)) * 85.0) * (1.0 - age);
			if (radial) energy += exp(-abs(radius - min(age * 3.0, 1.0)) * 100.0) * 2.0;
			energy *= 1.0 - smoothstep(0.92, 1.0, radius);
		}
		float fade = 1.0 - smoothstep(0.65, 1.0, age);
		ALBEDO = vec3(0.2, 0.55, 1.0);
		EMISSION = mix(vec3(0.1, 0.35, 1.0), vec3(0.8, 0.95, 1.0), min(energy, 1.0)) * energy * 4.0 * fade;
		ALPHA = clamp(energy * fade, 0.0, 1.0);
	}
}
