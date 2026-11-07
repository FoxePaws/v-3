shader_type sky;
render_mode use_debanding;

uniform float cloud_base_height : hint_range(0.0, 0.8) = 0.12;
uniform float cloud_horizon_fade_start : hint_range(-0.2, 0.5) = 0.02;
uniform float cloud_horizon_fade_end : hint_range(0.0, 0.8) = 0.20;


// Атмосфера
uniform vec3 day_zenith : source_color = vec3(0.12, 0.34, 0.68);
uniform vec3 day_horizon : source_color = vec3(0.72, 0.64, 0.55);
uniform vec3 sunset_color : source_color = vec3(1.0, 0.30, 0.10);
uniform vec3 night_zenith : source_color = vec3(0.008, 0.012, 0.045);
uniform vec3 night_horizon : source_color = vec3(0.035, 0.045, 0.10);
uniform vec3 ground_color : source_color = vec3(0.025, 0.03, 0.04);

uniform float atmosphere_strength : hint_range(0.0, 2.0) = 1.0;
uniform float twilight_width : hint_range(0.01, 0.5) = 0.22;

// Небесные тела
uniform vec3 moon_direction = vec3(-0.5, 0.3, 0.7);
uniform float sun_angular_size : hint_range(0.001, 0.05) = 0.009;
uniform float moon_angular_size : hint_range(0.001, 0.05) = 0.012;
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;
uniform float moon_brightness : hint_range(0.0, 5.0) = 1.0;

// Текстуры-карты. Ожидаются эквидистантные (equirectangular) изображения.
uniform sampler2D star_map : source_color, filter_linear, repeat_enable;
uniform sampler2D moon_texture : source_color, filter_linear, repeat_disable;
uniform float star_brightness : hint_range(0.0, 5.0) = 1.0;
uniform float star_rotation = 0.0;

// Дальний мягкий слой облаков. Облачный купол/плоскость — отдельный материал.
uniform sampler2D cloudtext : source_color, filter_linear_mipmap, repeat_enable;

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.2;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.16;
uniform float cloud_scale : hint_range(2.0, 80.0) = 18.0;
uniform vec2 cloud_offset = vec2(0.0, 0.0);



vec2 direction_to_spherical_uv(vec3 direction) {
	vec3 d = normalize(direction);
	float u = atan(d.z, d.x) / (2.0 * PI) + 0.5;
	float v = acos(clamp(d.y, -1.0, 1.0)) / PI;
	return vec2(u, v);
}

void sky() {
	vec3 view_dir = normalize(EYEDIR);
	vec3 sun_dir = normalize(LIGHT0_DIRECTION);
	vec3 moon_dir = normalize(moon_direction);

	float sun_height = sun_dir.y;
	float day_amount = smoothstep(-0.12, 0.10, sun_height);
	float night_amount = 1.0 - smoothstep(-0.16, 0.06, sun_height);
	float twilight = (1.0 - smoothstep(0.0, twilight_width, abs(sun_height)));

	float sky_height = clamp(view_dir.y * 0.5 + 0.5, 0.0, 1.0);
	float horizon_factor = pow(1.0 - sky_height, 3.0);

	vec3 day_sky = mix(day_horizon, day_zenith, pow(sky_height, 0.55));
	vec3 night_sky = mix(night_horizon, night_zenith, pow(sky_height, 0.55));
	vec3 sky_color = mix(night_sky, day_sky, day_amount);

	float horizon_glow = exp(-abs(view_dir.y) * 9.0) * twilight;
	sky_color = mix(
		sky_color,
		sunset_color,
		clamp(horizon_glow * atmosphere_strength, 0.0, 1.0)
	);

	// Темнее под горизонтом — при этом sky shader остаётся небом, не землёй.
	sky_color = mix(sky_color, ground_color, smoothstep(0.0, -0.08, view_dir.y));

	// Солнце следует за основным DirectionalLight3D.
	float sun_dot = clamp(dot(view_dir, sun_dir), -1.0, 1.0);
	float sun_angle = acos(sun_dot);
	float sun_disk = 1.0 - smoothstep(
		sun_angular_size * 0.72,
		sun_angular_size,
		sun_angle
	);
	float sun_halo = pow(max(sun_dot, 0.0), 180.0);

// Слабее свечение вокруг солнца.
	sky_color += vec3(1.0, 0.30, 0.10) * sun_halo * twilight * 0.25;
	sky_color += vec3(1.0, 0.72, 0.42) * sun_halo * day_amount * 0.08;

	// Более тёплый и менее яркий диск.
	vec3 sun_disk_color = mix(
		vec3(1.0, 0.20, 0.035), // рассвет и закат
		vec3(1.0, 0.55, 0.22),  // дневное солнце
		day_amount
	);
	sky_color += sun_disk_color * sun_disk * 0.87;

	// Звёздная карта вращается параметром star_rotation.
	vec2 star_uv = direction_to_spherical_uv(view_dir);
	star_uv.x = fract(star_uv.x + star_rotation);
	vec3 stars = texture(star_map, star_uv).rgb;
	float stars_visible = night_amount * (1.0 - twilight * 0.65);
	sky_color += stars * star_brightness * stars_visible;

	// Лунный диск: отдельное направление, не обязательно строго напротив Солнца.
	float moon_dot = clamp(dot(view_dir, moon_dir), -1.0, 1.0);
	float moon_angle = acos(moon_dot);
	float moon_radius = max(sin(moon_angular_size), 0.001);
	float moon_disk = 1.0 - smoothstep(
		moon_angular_size * 0.94,
		moon_angular_size,
		moon_angle
	);

	// Локальные координаты на видимом диске Луны.
	vec3 reference_up = vec3(0.0, 1.0, 0.0);
	if (abs(dot(moon_dir, reference_up)) > 0.98) {
		reference_up = vec3(1.0, 0.0, 0.0);
	}
	vec3 moon_right = normalize(cross(reference_up, moon_dir));
	vec3 moon_up = normalize(cross(moon_dir, moon_right));

	float disk_x = dot(view_dir, moon_right) / moon_radius;
	float disk_y = dot(view_dir, moon_up) / moon_radius;
	vec2 moon_uv = vec2(disk_x, disk_y) * 0.5 + 0.5;

	vec4 moon_texel = texture(moon_texture, moon_uv);

	// Направление света на Луне задаёт фазу.
	// moon_phase: 0 — новолуние, 0.5 — полнолуние.
	float phase_angle = moon_phase * 2.0 * PI;
	vec3 phase_light_dir = normalize(
		sun_dir * cos(phase_angle) +
		moon_right * sin(phase_angle)
	);
	vec3 moon_surface_normal = normalize(
		moon_dir +
		moon_right * disk_x +
		moon_up * disk_y
	);
	float phase_light = max(dot(moon_surface_normal, phase_light_dir), 0.0);

	float moon_visibility = night_amount * moon_brightness;
	vec3 moon_color = moon_texel.rgb * (0.12 + phase_light * 0.88);
	sky_color = mix(
		sky_color,
		moon_color * moon_brightness,
		moon_disk * moon_texel.a * moon_visibility
	);

	// Небольшое рассеянное свечение вокруг Луны.
	float moon_glow = pow(max(moon_dot, 0.0), 90.0);
	sky_color += vec3(0.18, 0.25, 0.42) * moon_glow * moon_visibility * 0.25;

		// Облачная проекция на плоскость, подобная применённой в Sky3D.
	// Направление xz задаёт координаты, y управляет масштабом проекции.
	// Мягче меняем масштаб проекции у горизонта:
	// это уменьшает сильное «сползание» узора по краям.
	float cloud_height = max(view_dir.y + 0.35, 0.25);
	vec2 cloud_uv = (view_dir.xz / cloud_height) / cloud_scale;
	cloud_uv += cloud_offset;

	float cloud_noise = texture(cloudtext, cloud_uv).r;

	float cloud_edge = mix(0.85, 0.30, cloud_coverage);
	float cloud_mask = smoothstep(
		cloud_edge - 0.08,
		cloud_edge + 0.08,
		cloud_noise
	);

	// Убираем облака у самой линии горизонта.
	// Чем выше первый порог, тем выше начинается видимый слой.
// Нижняя граница облаков: увеличивайте cloud_base_height, чтобы
// облачная область начиналась выше.
float cloud_base_fade = smoothstep(
	cloud_base_height,
	cloud_base_height + 0.12,
	view_dir.y
);

// Отдельное плавное исчезновение у горизонта.
// Меньшие значения позволяют облакам дотянуться ближе к горизонту.
float horizon_fade = smoothstep(
	cloud_horizon_fade_start,
	cloud_horizon_fade_end,
	view_dir.y
);

cloud_mask *= cloud_base_fade * horizon_fade;


	// Не рисуем облака под горизонтом, край делаем плавным.

	vec3 cloud_day_color = vec3(0.78, 0.82, 0.88);
	vec3 cloud_night_color = vec3(0.10, 0.13, 0.22);
	vec3 cloud_color = mix(cloud_night_color, cloud_day_color, day_amount);
	cloud_color = mix(
		cloud_color,
		sunset_color,
		twilight * horizon_factor * 0.5
	);

	float cloud_alpha = cloud_mask * cloud_opacity;
	COLOR = mix(sky_color, cloud_color, cloud_alpha);

}
