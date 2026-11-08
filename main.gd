extends Node3D

@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var rain: GPUParticles3D = $Weather/Rain
@onready var snow: GPUParticles3D = $Weather/Snow
@onready var player: Node3D = $Playermal

var current_weather: String = "clear"

signal world_time_advanced(delta_world_seconds: float)

@export_group("Calendar")
@export_range(1, 9999, 1) var start_year: int = 2010
@export_range(1, 12, 1) var start_month: int = 5
@export_range(1, 31, 1) var start_day: int = 1
@export_range(0.0, 23.999, 0.001) var start_hour: float = 8.0

# Реальные секунды на полные игровые сутки при time_scale = 1.
@export_range(1.0, 86400.0, 1.0) var day_length_seconds: float = 7200.0
@export_range(0.0, 1000.0, 0.1) var time_scale: float = 1.0

@export_range(-12.0, 14.0, 0.25) var utc_offset_hours: float = 3.0
@export_range(-90.0, 90.0, 0.00001) var latitude_degrees: float = 51.67167
@export_range(-180.0, 180.0, 0.00001) var longitude_degrees: float = 39.21056

@export_group("Sky Update")
@export var update_sky_every_frame: bool = false
@export_range(0.01, 10.0, 0.01) var sky_update_interval_seconds: float = 0.25

@export_group("Clouds")
@export_range(0.0, 1.0, 0.01) var cloud_coverage: float = 0.25
@export_range(0.0, 1.0, 0.01) var cloud_opacity: float = 0.16
@export var wind_direction: Vector2 = Vector2(1.0, 0.0)
@export_range(0.0, 1.0, 0.001) var wind_speed: float = 0.002

@export_group("Fog")
@export var fog_enabled: bool = true
@export_range(0.0, 0.2, 0.001) var fog_density: float = 0.015
@export var fog_color: Color = Color(0.55, 0.6, 0.62, 1.0)

var _cloud_coverage_multiplier: float = 1.0
var _cloud_opacity_multiplier: float = 1.0
var _fog_density_multiplier: float = 0.0

var game_timestamp_utc: float = 0.0
var time_of_day: float = 8.0
var total_world_seconds: float = 0.0
var cloud_offset: Vector2 = Vector2.ZERO
var sky_material: ShaderMaterial
var _sky_update_accumulator: float = 0.0
var _sun_direction: Vector3 = Vector3.UP
var _moon_direction: Vector3 = Vector3.DOWN
var _moon_phase: float = 0.5
var _star_rotation: float = 0.0


func update_weather_position() -> void:
	rain.global_position = player.global_position + Vector3(0.0, 8.0, 0.0)
	snow.global_position = player.global_position + Vector3(0.0, 8.0, 0.0)


func _ready() -> void:
	game_timestamp_utc = _make_start_timestamp_utc()
	_sync_calendar_fields()

	var environment: Environment = world_environment.environment
	if environment == null or environment.sky == null:
		push_error("WorldEnvironment: Environment или Sky не назначен")
		return

	sky_material = environment.sky.sky_material as ShaderMaterial
	if sky_material == null:
		push_error("WorldEnvironment: у Sky не назначен ShaderMaterial")
		return

	set_weather("clear")
	_update_sky()


func _process(delta: float) -> void:
	var world_delta: float = _advance_game_time(delta)

	# Передаём игровое время, а не обычные секунды кадра.
	if world_delta > 0.0:
		world_time_advanced.emit(world_delta)

	var wind: Vector2 = wind_direction.normalized()
	cloud_offset += wind * wind_speed * 0.5 * world_delta
	cloud_offset.x = fposmod(cloud_offset.x, 1.0)
	cloud_offset.y = fposmod(cloud_offset.y, 1.0)

	update_weather_position()

	if update_sky_every_frame:
		_update_sky()
	else:
		_sky_update_accumulator += delta
		if _sky_update_accumulator >= sky_update_interval_seconds:
			_sky_update_accumulator = fposmod(
				_sky_update_accumulator,
				sky_update_interval_seconds
			)
			_update_sky()


func _make_start_timestamp_utc() -> float:
	var hour: int = floori(start_hour)
	var minute_float: float = (start_hour - float(hour)) * 60.0
	var minute: int = floori(minute_float)
	var second: int = roundi((minute_float - float(minute)) * 60.0)

	var local_datetime: Dictionary = {
		"year": start_year,
		"month": start_month,
		"day": start_day,
		"hour": hour,
		"minute": minute,
		"second": second,
	}

	var local_timestamp: float = float(
		Time.get_unix_time_from_datetime_dict(local_datetime)
	)
	return local_timestamp - utc_offset_hours * 3600.0


func _get_local_datetime() -> Dictionary:
	var local_timestamp: int = floori(
		game_timestamp_utc + utc_offset_hours * 3600.0
	)
	return Time.get_datetime_dict_from_unix_time(local_timestamp)


func _sync_calendar_fields() -> void:
	var date_time: Dictionary = _get_local_datetime()
	var hour: int = int(date_time.get("hour", 0))
	var minute: int = int(date_time.get("minute", 0))
	var second: int = int(date_time.get("second", 0))

	time_of_day = (
		float(hour)
		+ float(minute) / 60.0
		+ float(second) / 3600.0
	)


func _advance_game_time(real_delta: float) -> float:
	if real_delta <= 0.0 or time_scale <= 0.0 or day_length_seconds <= 0.0:
		return 0.0

	var game_seconds_per_real_second: float = 86400.0 / day_length_seconds
	var world_delta: float = (
		real_delta * time_scale * game_seconds_per_real_second
	)

	game_timestamp_utc += world_delta
	total_world_seconds += world_delta
	_sync_calendar_fields()

	return world_delta


func set_time_scale(new_scale: float) -> void:
	time_scale = maxf(new_scale, 0.0)


func set_world_time(hour: float, day_number: int = 0) -> void:
	# day_number — число календарных дней относительно начальной даты.
	var start_timestamp: float = _make_start_timestamp_utc()
	var requested_hour: float = fposmod(hour, 24.0)

	game_timestamp_utc = (
		start_timestamp
		+ float(day_number) * 86400.0
		+ requested_hour * 3600.0
	)

	_sync_calendar_fields()
	_update_sky()


func get_world_time_save_data() -> Dictionary:
	return {
		"game_timestamp_utc": game_timestamp_utc,
		"time_scale": time_scale,
		"day_length_seconds": day_length_seconds,
		"utc_offset_hours": utc_offset_hours,
		"latitude_degrees": latitude_degrees,
		"longitude_degrees": longitude_degrees,
		"total_world_seconds": total_world_seconds,
	}


func restore_world_time(data: Dictionary) -> void:
	time_scale = maxf(float(data.get("time_scale", time_scale)), 0.0)
	day_length_seconds = maxf(
		float(data.get("day_length_seconds", day_length_seconds)),
		1.0
	)
	utc_offset_hours = float(data.get("utc_offset_hours", utc_offset_hours))
	latitude_degrees = float(data.get("latitude_degrees", latitude_degrees))
	longitude_degrees = float(data.get("longitude_degrees", longitude_degrees))
	total_world_seconds = maxf(
		float(data.get("total_world_seconds", 0.0)),
		0.0
	)

	if data.has("game_timestamp_utc"):
		game_timestamp_utc = float(data["game_timestamp_utc"])
	else:
		# Поддержка старых сохранений, где была только time_of_day.
		var old_hour: float = fposmod(
			float(data.get("time_of_day", start_hour)),
			24.0
		)
		game_timestamp_utc = (
			_make_start_timestamp_utc()
			+ (old_hour - start_hour) * 3600.0
		)

	_sync_calendar_fields()
	_update_sky()


func _update_sky() -> void:
	if sky_material == null:
		return

	_update_celestial_directions()
	update_day_night()

	sky_material.set_shader_parameter(
		"cloud_coverage",
		clampf(cloud_coverage * _cloud_coverage_multiplier, 0.0, 1.0)
	)
	sky_material.set_shader_parameter(
		"cloud_opacity",
		clampf(cloud_opacity * _cloud_opacity_multiplier, 0.0, 1.0)
	)
	sky_material.set_shader_parameter("cloud_offset", cloud_offset)
	sky_material.set_shader_parameter("moon_direction", _moon_direction)
	sky_material.set_shader_parameter("moon_phase", _moon_phase)
	sky_material.set_shader_parameter("star_rotation", _star_rotation)

	var environment: Environment = world_environment.environment
	if environment != null:
		environment.fog_enabled = fog_enabled
		environment.fog_density = fog_density * _fog_density_multiplier
		environment.fog_light_color = fog_color


func update_day_night() -> void:
	# Направленный свет в Godot направлен вдоль локальной оси -Z.
	sun.look_at(
		sun.global_position - _sun_direction,
		Vector3.UP
	)

	var sun_height: float = _sun_direction.y
	var sun_visibility: float = smoothstep(-0.8, 0.35, sun_height)
	var light_factor: float = pow(sun_visibility, 0.55)

	sun.light_energy = lerpf(0.0, 0.76, light_factor)

	var warm_factor: float = 1.0 - smoothstep(0.15, 0.7, sun_height)
	var day_color: Color = Color(0.995, 0.721, 0.425, 1.0)
	var sunset_color: Color = Color(1.0, 0.35, 0.12)
	sun.light_color = sunset_color.lerp(day_color, 1.0 - warm_factor)

	var environment: Environment = world_environment.environment
	if environment == null:
		return

	var ambient_factor: float = smoothstep(-0.4, 0.4, sun_height)
	environment.ambient_light_energy = lerpf(0.04, 0.7, ambient_factor)
	environment.adjustment_enabled = false
	environment.adjustment_brightness = lerpf(0.04, 0.45, ambient_factor)


func _update_celestial_directions() -> void:
	var jd: float = game_timestamp_utc / 86400.0 + 2440587.5
	var t: float = (jd - 2451545.0) / 36525.0

	var mean_longitude: float = fposmod(
		280.46646 + t * (36000.76983 + t * 0.0003032),
		360.0
	)
	var mean_anomaly: float = deg_to_rad(
		357.52911 + t * (35999.05029 - 0.0001537 * t)
	)
	var eccentricity: float = 0.016708634 - t * (
		0.000042037 + 0.0000001267 * t
	)

	var equation_of_center: float = (
		sin(mean_anomaly) * (1.914602 - t * (0.004817 + 0.000014 * t))
		+ sin(2.0 * mean_anomaly) * (0.019993 - 0.000101 * t)
		+ sin(3.0 * mean_anomaly) * 0.000289
	)

	var true_longitude: float = deg_to_rad(
		mean_longitude + equation_of_center
	)
	var omega: float = deg_to_rad(125.04 - 1934.136 * t)
	var apparent_longitude: float = true_longitude - deg_to_rad(
		0.00569 + 0.00478 * sin(omega)
	)

	var obliquity: float = deg_to_rad(
		23.0
		+ (
			26.0
			+ (
				21.448
				- t * (46.815 + t * (0.00059 - t * 0.001813))
			) / 60.0
		) / 60.0
		+ 0.00256 * cos(omega)
	)

	var sun_ra: float = atan2(
		cos(obliquity) * sin(apparent_longitude),
		cos(apparent_longitude)
	)
	var sun_dec: float = asin(
		sin(obliquity) * sin(apparent_longitude)
	)

	var sidereal_degrees: float = (
		280.46061837
		+ 360.98564736629 * (jd - 2451545.0)
		+ 0.000387933 * t * t
		- t * t * t / 38710000.0
		+ longitude_degrees
	)
	var local_sidereal: float = deg_to_rad(
		fposmod(sidereal_degrees, 360.0)
	)

	_sun_direction = _equatorial_to_local_direction(
		sun_ra,
		sun_dec,
		local_sidereal
	)

	var moon_equatorial: Vector2 = _get_moon_equatorial(jd, obliquity)
	var moon_ra: float = moon_equatorial.x
	var moon_dec: float = moon_equatorial.y

	_moon_direction = _equatorial_to_local_direction(
		moon_ra,
		moon_dec,
		local_sidereal
	)

	var synodic_month: float = 29.530588853
	var days_from_known_new_moon: float = jd - 2451550.1
	var lunar_age: float = fposmod(days_from_known_new_moon, synodic_month)
	_moon_phase = lunar_age / synodic_month

	# Угол вращения эквидистантной звёздной карты.
	_star_rotation = fposmod(local_sidereal / TAU, 1.0)


func _equatorial_to_local_direction(
	right_ascension: float,
	declination: float,
	local_sidereal: float
) -> Vector3:
	var latitude: float = deg_to_rad(latitude_degrees)
	var hour_angle: float = wrapf(
		local_sidereal - right_ascension,
		-PI,
		PI
	)

	var east: float = -cos(declination) * sin(hour_angle)
	var north: float = (
		cos(latitude) * sin(declination)
		- sin(latitude) * cos(declination) * cos(hour_angle)
	)
	var up: float = (
		sin(latitude) * sin(declination)
		+ cos(latitude) * cos(declination) * cos(hour_angle)
	)

	# Шейдер использует Y как вертикальную ось.
	return Vector3(east, up, north).normalized()


func _get_moon_equatorial(julian_day: float, obliquity: float) -> Vector2:
	# Низкоточная кеплерова модель Луны.
	var days: float = julian_day - 2451543.5
	var ascending_node: float = deg_to_rad(
		fposmod(125.1228 - 0.0529538083 * days, 360.0)
	)
	var inclination: float = deg_to_rad(5.1454)
	var periapsis: float = deg_to_rad(
		fposmod(318.0634 + 0.1643573223 * days, 360.0)
	)
	var eccentricity: float = 0.0549
	var mean_anomaly: float = deg_to_rad(
		fposmod(115.3654 + 13.0649929509 * days, 360.0)
	)

	var eccentric_anomaly: float = mean_anomaly + eccentricity * sin(mean_anomaly) * (
		1.0 + eccentricity * cos(mean_anomaly)
	)

	for _iteration: int in range(4):
		eccentric_anomaly -= (
			eccentric_anomaly
			- eccentricity * sin(eccentric_anomaly)
			- mean_anomaly
		) / (
			1.0 - eccentricity * cos(eccentric_anomaly)
		)

	var orbital_x: float = cos(eccentric_anomaly) - eccentricity
	var orbital_y: float = (
		sqrt(1.0 - eccentricity * eccentricity)
		* sin(eccentric_anomaly)
	)

	var true_anomaly: float = atan2(orbital_y, orbital_x)
	var distance: float = sqrt(orbital_x * orbital_x + orbital_y * orbital_y)

	var x_ecliptic: float = distance * (
		cos(ascending_node) * cos(true_anomaly + periapsis)
		- sin(ascending_node)
		* sin(true_anomaly + periapsis)
		* cos(inclination)
	)
	var y_ecliptic: float = distance * (
		sin(ascending_node) * cos(true_anomaly + periapsis)
		+ cos(ascending_node)
		* sin(true_anomaly + periapsis)
		* cos(inclination)
	)
	var z_ecliptic: float = distance * (
		sin(true_anomaly + periapsis) * sin(inclination)
	)

	var x_equatorial: float = x_ecliptic
	var y_equatorial: float = (
		y_ecliptic * cos(obliquity)
		- z_ecliptic * sin(obliquity)
	)
	var z_equatorial: float = (
		y_ecliptic * sin(obliquity)
		+ z_ecliptic * cos(obliquity)
	)

	var right_ascension: float = atan2(y_equatorial, x_equatorial)
	var declination: float = atan2(
		z_equatorial,
		sqrt(x_equatorial * x_equatorial + y_equatorial * y_equatorial)
	)

	return Vector2(right_ascension, declination)

func set_weather(weather: String) -> void:
	current_weather = weather

	rain.emitting = false
	snow.emitting = false

	match weather:
		"clear":
			_cloud_coverage_multiplier = 0.48
			_cloud_opacity_multiplier = 1.0
			_fog_density_multiplier = 0.0

		"rain":
			_cloud_coverage_multiplier = 1.0
			_cloud_opacity_multiplier = 1.0
			_fog_density_multiplier = 1.0
			rain.emitting = true

		"snow":
			_cloud_coverage_multiplier = 0.88
			_cloud_opacity_multiplier = 1.0
			_fog_density_multiplier = 1.67
			snow.emitting = true

		"fog":
			_cloud_coverage_multiplier = 0.72
			_cloud_opacity_multiplier = 1.0
			_fog_density_multiplier = 2.67

		_:
			push_warning("Неизвестный тип погоды: " + weather)
			current_weather = "clear"
			_cloud_coverage_multiplier = 0.48
			_cloud_opacity_multiplier = 1.0
			_fog_density_multiplier = 0.0

	_update_sky()



func random_weather() -> void:
	var weather_types: Array[String] = ["clear", "rain", "snow", "fog"]
	var new_weather: String = weather_types.pick_random()

	set_weather(new_weather)
	print("Новая погода: ", new_weather)


func _on_weather_timer_timeout() -> void:
	random_weather()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				set_weather("clear")
			KEY_2:
				set_weather("rain")
			KEY_3:
				set_weather("snow")
			KEY_4:
				set_weather("fog")
