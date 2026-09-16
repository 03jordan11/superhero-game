shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float night_amount = 0.0;
varying vec3 local_point;
varying vec3 local_normal;
void vertex() {
	local_point = VERTEX;
	local_normal = NORMAL;
	// Lift the overlay off its base surface to avoid equal-depth rejection.
	VERTEX += NORMAL * 0.002;
}
void fragment() {
	// Next pass on the existing unit silhouette / flat LOD; no extra traffic objects.
	float side = step(0.23, abs(local_point.x)) * (1.0 - step(0.46, abs(local_point.x)));
	float front = step(0.495, local_point.z) * step(0.5, local_normal.z);
	float rear = step(local_point.z, -0.495) * step(local_normal.z, -0.5);
	float height = step(-0.22, local_point.y) * (1.0 - step(-0.06, local_point.y));
	// Thin strips on the far flat-car representation, visible from rooftops.
	if (abs(local_point.y) < 0.001 && local_normal.y > 0.9) {
		front = step(0.40, local_point.z);
		rear = step(local_point.z, -0.40);
		height = 1.0;
	}
	float mask = side * height * max(front, rear) * night_amount;
	if (mask < 0.001) discard;
	ALBEDO = mix(vec3(4.5, 0.035, 0.012), vec3(4.0, 4.8, 6.0), front) * mask;
}
