shader_type sky;

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.25;
uniform float cloud_scale : hint_range(1.0, 30.0) = 8.0;
uniform float cloud_wind_angle = 0.0;

uniform float star_rotation = 0.0;
uniform float star_intensity : hint_range(0.0, 3.0) = 0.7;

uniform vec3 moon_direction = vec3(0.0, 1.0, 0.0);
uniform float moon_intensity : hint_range(0.0, 3.0) = 0.7;


float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}


float noise3d(vec3 p) {
	vec3 cell = floor(p);
	vec3 local_pos = fract(p);

	local_pos = local_pos * local_pos * (3.0 - 2.0 * local_pos);

	float n000 = hash31(cell + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(cell + vec3(1.0, 1.0, 1.0));

	float x00 = mix(n000, n100, local_pos.x);
	float x10 = mix(n010, n110, local_pos.x);
	float x01 = mix(n001, n101, local_pos.x);
	float x11 = mix(n011, n111, local_pos.x);

	float y0 = mix(x00, x10, local_pos.y);
	float y1 = mix(x01, x11, local_pos.y);

	return mix(y0, y1, local_pos.z);
}


vec3 rotate_y(vec3 direction, float angle) {
	float c = cos(angle);
	float s = sin(angle);

	return vec3(
		c * direction.x - s * direction.z,
		direction.y,
		s * direction.x + c * direction.z
	);
}


void sky() {
	float sun_height = LIGHT0_DIRECTION.y;
	float daylight = smoothstep(-0.12, 0.18, sun_height);
	float night_factor = 1.0 - smoothstep(-0.08, 0.12, sun_height);

	vec3 night_color = vec3(0.012, 0.015, 0.025);
	vec3 day_color = vec3(0.18, 0.25, 0.34);
	vec3 color = mix(night_color, day_color, daylight);


	// ЗВЁЗДЫ: неподвижный узор, вращается только со временем суток.
	vec3 star_direction = normalize(rotate_y(EYEDIR, star_rotation));
	vec3 star_cell = floor(star_direction * 120.0);
	float star_random = hash31(star_cell);
	float star = step(0.9985, star_random);

	color += vec3(0.72, 0.78, 0.9)
		* star
		* star_intensity
		* night_factor;


	// ЛУНА: заменяет цвет звёзд под диском, а не добавляется поверх них.
	float moon_dot = dot(
		normalize(EYEDIR),
		normalize(moon_direction)
	);
	float moon_disk = smoothstep(0.9990, 0.9995, moon_dot);
	float moon_visibility = moon_disk * night_factor;

	vec3 moon_color = vec3(0.62, 0.67, 0.76);
	color = mix(color, moon_color, moon_visibility * moon_intensity);


	// ОБЛАКА: вычисляются по 3D-направлению взгляда, без текстурных швов.
	vec3 cloud_direction = normalize(rotate_y(EYEDIR, cloud_wind_angle));
	float cloud_noise_value = noise3d(cloud_direction * cloud_scale);

	float cloud_alpha = smoothstep(
		1.0 - cloud_coverage - 0.12,
		1.0 - cloud_coverage + 0.12,
		cloud_noise_value
	);
	cloud_alpha *= 0.75;

	vec3 night_cloud_color = vec3(0.045, 0.052, 0.067);
	vec3 day_cloud_color = vec3(0.52, 0.55, 0.58);
	vec3 cloud_color = mix(
		night_cloud_color,
		day_cloud_color,
		daylight
	);

	color = mix(color, cloud_color, cloud_alpha);


	// СОЛНЦЕ: направление берётся от первого DirectionalLight3D.
	float sun_dot = dot(
		normalize(EYEDIR),
		normalize(LIGHT0_DIRECTION)
	);
	float sun_disk = smoothstep(0.9990, 0.99965, sun_dot);

	vec3 sun_color = mix(
		vec3(0.85, 0.48, 0.27),
		vec3(1.0, 0.82, 0.58),
		daylight
	);

	color = mix(color, sun_color, sun_disk);

	COLOR = color;
}
