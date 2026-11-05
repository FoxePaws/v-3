shader_type sky;

uniform vec3 sun_direction = vec3(0.0, 0.5, 0.0);
uniform vec3 moon_direction = vec3(0.0, -0.5, 0.0);

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.25;
uniform float cloud_scale : hint_range(0.1, 20.0) = 3.0;
uniform vec2 wind_offset = vec2(0.0);

uniform float star_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float moon_intensity : hint_range(0.0, 3.0) = 0.8;

uniform sampler2D cloud_noise : repeat_enable, filter_linear;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void sky() {
	vec2 uv = SKY_COORDS;
	vec3 direction = vec3(
		cos((uv.y - 0.5) * PI) * sin(uv.x * TAU),
		sin((uv.y - 0.5) * PI),
		cos((uv.y - 0.5) * PI) * cos(uv.x * TAU)
	);

	float daylight = smoothstep(-0.12, 0.2, sun_direction.y);
	vec3 night_color = vec3(0.008, 0.012, 0.035);
	vec3 day_color = vec3(0.22, 0.48, 0.78);
	vec3 color = mix(night_color, day_color, daylight);

	// Статичные звёзды: координаты не зависят от времени или ветра.
	vec2 star_grid = uv * vec2(900.0, 450.0);
	vec2 cell = floor(star_grid);
	float star_random = hash21(cell);
	float star = step(0.997, star_random);
	float night_factor = 1.0 - smoothstep(-0.08, 0.12, sun_direction.y);
	color += vec3(0.8, 0.86, 1.0) * star * star_intensity * night_factor;

	// Диск луны рисуется поверх звёзд, но перед облаками.
	float moon_dot = dot(normalize(direction), normalize(moon_direction));
	float moon_disk = smoothstep(0.9990, 0.9996, moon_dot);
	color += vec3(0.72, 0.78, 0.95) * moon_disk * moon_intensity * night_factor;

	// Движутся только облака; wind_offset задаёт направление и скорость.
	vec2 cloud_uv = uv * cloud_scale + wind_offset;
	float noise_value = texture(cloud_noise, cloud_uv).r;
	float cloud_alpha = smoothstep(
		1.0 - cloud_coverage - 0.18,
		1.0 - cloud_coverage + 0.18,
		noise_value
	);
	cloud_alpha *= 0.85;

	vec3 cloud_color = mix(
		vec3(0.12, 0.15, 0.22),
		vec3(0.92, 0.94, 1.0),
		daylight
	);
	color = mix(color, cloud_color, cloud_alpha);

	// Диск солнца поверх облаков.
	float sun_dot = dot(normalize(direction), normalize(sun_direction));
	float sun_disk = smoothstep(0.9992, 0.99975, sun_dot);
	vec3 sun_color = mix(vec3(1.0, 0.55, 0.28), vec3(1.0, 0.92, 0.72), daylight);
	color = mix(color, sun_color, sun_disk);

	COLOR = color;
}
