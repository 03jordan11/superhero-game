shader_type spatial;
render_mode cull_back;
uniform float elapsed = 0.0;
uniform float night_amount = 0.0;
uniform float wave_strength = 1.0;
uniform bool river = false;
varying vec3 world_position;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Value noise with analytic derivatives: irregular waves without repeating stripes.
vec3 noise_gradient(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return vec3(mix(mix(a, b, u.x), mix(c, d, u.x), u.y),
		mix(b - a, d - c, u.y) * du.x, mix(c - a, d - b, u.x) * du.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float speed = river ? 1.4 : 0.65;
	p.y -= elapsed * speed;
	float distance_to_camera = length(CAMERA_POSITION_WORLD - world_position);
	vec3 a = noise_gradient(p * 0.075 + vec2(elapsed * 0.018, 0.0));
	vec3 b = noise_gradient(p * 0.24 + vec2(7.3, elapsed * 0.032));
	vec3 c = noise_gradient(p * 0.83 - vec2(elapsed * 0.026, 13.4));
	float medium_detail = 1.0 - smoothstep(500.0, 1800.0, distance_to_camera);
	float fine_detail = 1.0 - smoothstep(70.0, 350.0, distance_to_camera);
	vec2 slope = (a.yz * 0.085 + b.yz * 0.06 * medium_detail + c.yz * 0.025 * fine_detail) * wave_strength;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);
	vec3 deep_color = river ? vec3(0.014, 0.068, 0.063) : vec3(0.007, 0.039, 0.073);
	float crest = smoothstep(0.8, 0.98, (a.x + b.x) * 0.5) * medium_detail;
	ALBEDO = deep_color * mix(1.0, 0.36, night_amount) + vec3(0.06, 0.09, 0.09) * crest;
	ROUGHNESS = mix(0.28, 0.4, max(crest, 1.0 - medium_detail));
	METALLIC = 0.35;
	SPECULAR = 0.85;
}
