shader_type sky;
render_mode disable_fog;

// The visible background stays sharp; the lighting cubemap skips celestial detail.
uniform samplerCube milky_way : filter_linear_mipmap;
uniform samplerCube bright_stars : filter_linear_mipmap;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform mat3 star_rotation;
uniform vec3 sun_direction = vec3(0.0, 0.5, 0.866);
uniform vec3 moon_direction = vec3(0.0, 0.5, -0.866);
uniform float milky_way_intensity : hint_range(0.0, 12.0) = 0.0;
uniform float star_intensity : hint_range(0.0, 8.0) = 0.18;
uniform float star_density : hint_range(0.0, 1.0) = 0.08;
uniform float horizon_light_pollution : hint_range(0.0, 1.0) = 0.12;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.32;
uniform vec2 cloud_offset = vec2(0.0);
uniform float moon_size : hint_range(0.002, 0.05) = 0.015;
uniform float storm_amount : hint_range(0.0, 1.0) = 0.0;
uniform float lightning_flash = 0.0;
uniform vec3 lightning_direction = vec3(0.0, 0.0, -1.0);
uniform float lightning_seed = 0.0;

float bolt_noise(float n) {
	return fract(sin(n * 127.1 + lightning_seed) * 43758.5453);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float altitude = max(d.y, 0.0);
	float daylight = smoothstep(-0.12, 0.22, sun_direction.y);
	float night = 1.0 - smoothstep(-0.23, -0.045, sun_direction.y);
	float twilight = exp(-pow((sun_direction.y + 0.015) / 0.17, 2.0));
	float horizon = exp(-altitude * 5.0);
	float sun_dot = clamp(dot(d, sun_direction), -1.0, 1.0);
	float facing_sun = pow(max(sun_dot * 0.5 + 0.5, 0.0), 4.0);
	vec3 zenith = mix(vec3(0.0015, 0.003, 0.012), vec3(0.055, 0.22, 0.58), daylight);
	vec3 horizon_color = mix(vec3(0.018, 0.029, 0.058), vec3(0.48, 0.69, 0.91), daylight);
	vec3 col = mix(zenith, horizon_color, horizon);
	// Faint urban skyglow close to the horizon; the zenith remains dark.
	col += vec3(0.34, 0.28, 0.22) * horizon_light_pollution * exp(-altitude * 10.0) * night;
	// Gold near the sun, rose above it, violet on the opposite horizon.
	col += twilight * horizon * mix(vec3(0.12, 0.028, 0.12), vec3(1.65, 0.32, 0.065), facing_sun);
	col += twilight * exp(-pow((altitude - 0.22) * 6.0, 2.0)) * vec3(0.14, 0.028, 0.09);
	vec3 sun_color = mix(vec3(1.0, 0.24, 0.055), vec3(1.0, 0.87, 0.65), smoothstep(0.0, 0.35, sun_direction.y));
	float sun_visible = smoothstep(-0.045, 0.005, sun_direction.y);
	col += sun_color * pow(max(sun_dot, 0.0), 32.0) * 0.32 * sun_visible;
	if (!AT_CUBEMAP_PASS) {
		float sun_disc = smoothstep(cos(0.0105), cos(0.0085), sun_dot);
		col += sun_color * sun_disc * 12.0 * sun_visible;
		if (night > 0.001 && d.y > 0.0) {
			vec3 star_dir = normalize(star_rotation * d);
			// Direct spherical lookup: no latitude/longitude singularity at either pole.
			vec3 galaxy = texture(milky_way, star_dir).rgb;
			vec3 stars = texture(bright_stars, star_dir).rgb;
			// Reject faint stars from the dense source cube, leaving sparse bright cores.
			float threshold = mix(2.4, 0.0, sqrt(star_density));
			float luminance = max(stars.r, max(stars.g, stars.b));
			float visible_star = smoothstep(threshold, threshold + 0.35, luminance) * step(0.0001, star_density);
			stars *= visible_star;
			col += (galaxy * milky_way_intensity + min(stars, vec3(2.5)) * star_intensity) * night * smoothstep(0.08, 0.38, altitude);
		}
		float moon_dot = dot(d, moon_direction);
		float moon_disc = smoothstep(cos(moon_size * 1.04), cos(moon_size * 0.96), moon_dot);
		vec3 moon_right = normalize(cross(vec3(0.0, 1.0, 0.0), moon_direction));
		vec3 moon_up = cross(moon_direction, moon_right);
		vec2 moon_uv = vec2(dot(d, moon_right), dot(d, moon_up)) / moon_size;
		float lunar_detail = texture(cloud_noise, moon_uv * 0.28 + vec2(0.32, 0.17)).r;
		float lunar_shading = sqrt(max(0.0, 1.0 - dot(moon_uv, moon_uv)));
		float moon_visible = smoothstep(-0.03, 0.04, moon_direction.y) * (1.0 - daylight * 0.92);
		col = mix(col, vec3(0.62, 0.72, 0.92) * (0.5 + lunar_detail * 0.9) * (0.5 + lunar_shading * 0.7), moon_disc * moon_visible);
		col += vec3(0.045, 0.075, 0.14) * pow(max(moon_dot, 0.0), 180.0) * moon_visible;
	}
	float coverage = mix(cloud_coverage, 0.98, storm_amount);
	if (d.y > 0.0 && coverage > 0.001) {
		// Two inexpensive, wind-driven layers on a curved sky plane.
		vec2 p = d.xz / (altitude + 0.18);
		float base = texture(cloud_noise, p * 0.22 + cloud_offset).r;
		float wisps = texture(cloud_noise, p * vec2(0.38, 0.12) - cloud_offset * 0.6 + vec2(0.37)).r;
		float threshold = mix(0.86, 0.28, coverage);
		float density = smoothstep(threshold, threshold + 0.18, base * 0.8 + wisps * 0.2);
		float thin = smoothstep(0.59, 0.78, wisps) * coverage * 0.35;
		float opacity = (density * 0.87 + thin) * smoothstep(0.0, 0.09, altitude);
		vec3 cloud_color = mix(vec3(0.018, 0.027, 0.052), vec3(0.72, 0.8, 0.91), daylight);
		cloud_color *= mix(0.66, 1.25, base);
		cloud_color += twilight * mix(vec3(0.17, 0.035, 0.08), vec3(1.7, 0.48, 0.12), facing_sun);
		// Broad dark cloud banks retain layered detail under full overcast.
		float banks = texture(cloud_noise, p * 0.11 + cloud_offset * 0.45).r;
		vec3 storm_cloud = mix(vec3(0.022, 0.027, 0.038), vec3(0.24, 0.26, 0.29), daylight);
		storm_cloud *= 0.42 + banks * 1.05 + base * 0.35;
		cloud_color = mix(cloud_color, storm_cloud, storm_amount);
		opacity = mix(opacity, 0.94 + density * 0.06, storm_amount);
		col = mix(col, cloud_color, clamp(opacity, 0.0, 1.0));
	}
	col = mix(col, mix(vec3(0.017, 0.023, 0.034), vec3(0.22, 0.25, 0.29), daylight), storm_amount * exp(-abs(d.y) * 16.0) * 0.75);
	if (lightning_flash > 0.001 && storm_amount > 0.001) {
		float forward = dot(d, lightning_direction);
		col += vec3(0.26, 0.31, 0.43) * lightning_flash * storm_amount * pow(max(forward, 0.0), 5.0);
		if (!AT_CUBEMAP_PASS && forward > 0.4 && d.y > 0.015 && d.y < 0.31) {
			vec3 right = cross(lightning_direction, vec3(0.0, 1.0, 0.0));
			float x = dot(d, right) / forward;
			float y = (d.y - 0.015) / 0.295;
			float cell = y * 16.0;
			float path = mix(bolt_noise(floor(cell)), bolt_noise(floor(cell) + 1.0), fract(cell)) * 0.055;
			float line = abs(x - path);
			float branch = abs(x - path - (y - 0.5) * 0.18);
			if (y > 0.2 && y < 0.62) line = min(line, branch);
			float bolt = exp(-line * 1200.0) * 8.0 + exp(-line * 150.0) * 0.65;
			col += vec3(0.65, 0.8, 1.0) * bolt * lightning_flash * storm_amount;
		}
	}
	// Ground hemisphere blends into haze, including when flying above the city.
	col = mix(mix(vec3(0.008, 0.014, 0.027), vec3(0.16, 0.21, 0.28), daylight), col, smoothstep(-0.14, 0.015, d.y));
	COLOR = max(col, vec3(0.0));
}
