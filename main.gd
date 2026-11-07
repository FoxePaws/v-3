extends Node3D



@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var rain: GPUParticles3D = $Weather/Rain
@onready var snow: GPUParticles3D = $Weather/Snow
@onready var player: Node3D = $Playermal

func update_weather_position() -> void:
	rain.global_position = player.global_position + Vector3(0, 8, 0)
	snow.global_position = player.global_position + Vector3(0, 8, 0)

var current_weather: String = "clear"



signal world_time_advanced(delta_world_seconds: float)

@export_range(0.01, 100000.0, 0.1)
var day_length_seconds: float = 120.0

@export_range(0.0, 1000.0, 0.1)
var time_scale: float = 1.0

@export_range(0.0, 24.0, 0.01)
var start_time: float = 8.0

var time_of_day: float = 8.0
var total_world_seconds: float = 0.0

@export_range(0.0, 1.0, 0.01) var cloud_coverage: float = 0.25

@export var wind_direction: Vector2 = Vector2(1.0, 0.0)
@export_range(0.0, 1.0, 0.001) var wind_speed: float = 0.002

@export_range(1.0, 100.0, 0.1) var moon_orbit_days: float = 27.3
@export_range(-30.0, 30.0, 0.1) var moon_orbit_inclination_degrees: float = 5.0


var cloud_offset: Vector2 = Vector2.ZERO
var sky_material: ShaderMaterial

func _ready() -> void:
	time_of_day = start_time

	var environment: Environment = world_environment.environment
	if environment == null or environment.sky == null:
		push_error("WorldEnvironment: Environment или Sky не назначен")
		return

	sky_material = environment.sky.sky_material as ShaderMaterial
	if sky_material == null:
		push_error("WorldEnvironment: у Sky не назначен ShaderMaterial")
		return

	set_weather("clear")
	update_day_night()
	_update_sky_shader()


func _process(delta: float) -> void:
	var world_delta: float = delta * time_scale
	var day_delta: float = 24.0 * world_delta / day_length_seconds

	time_of_day = fposmod(time_of_day + day_delta, 24.0)
	total_world_seconds += world_delta

	var wind: Vector2 = wind_direction.normalized()
	cloud_offset += wind * wind_speed * world_delta
	cloud_offset = Vector2(
		fposmod(cloud_offset.x, 1.0),
		fposmod(cloud_offset.y, 1.0)
	)

	update_day_night()
	_update_sky_shader()
	update_weather_position()

	if world_delta > 0.0:
		world_time_advanced.emit(world_delta)


func _update_sky_shader() -> void:
	if sky_material == null:
		return

	sky_material.set_shader_parameter("cloud_coverage", cloud_coverage)
	sky_material.set_shader_parameter("cloud_offset", cloud_offset)
	_update_moon_direction()



func update_day_night() -> void:
	var sun_angle := (time_of_day / 24.0) * 360.0 - 90.0
	sun.rotation_degrees.x = -sun_angle

	var sun_height := sin(deg_to_rad(sun_angle))

	var sun_visibility := smoothstep(-0.8, 0.35, sun_height)
	var light_factor := pow(sun_visibility, 0.55)

	sun.light_energy = lerp(0.02, 0.76, light_factor)

	if sun_height < -0.8:
		sun.light_energy = 0.0



	# Цвет на рассвете и закате
	var warm_factor := 1.0 - smoothstep(0.15, 0.7, sun_height)

	var day_color := Color(1.0, 0.733, 0.412, 1.0)
	var sunset_color := Color(1.0, 0.35, 0.12)

	sun.light_color = sunset_color.lerp(day_color, 1.0 - warm_factor)

	var environment := world_environment.environment

	if environment:
		var ambient_factor := smoothstep(-0.4, 0.4, sun_height)

		environment.ambient_light_energy = lerp(
			0.04,
			0.7,
			ambient_factor
		)

		environment.adjustment_enabled = false
		environment.adjustment_brightness = lerp(
			0.04,
			0.45,
			ambient_factor
		)


func set_weather(weather: String) -> void:
	current_weather = weather

	rain.emitting = false
	snow.emitting = false

	var environment: Environment = world_environment.environment
	if environment:
		# Сначала сбрасываем туман, чтобы его настройки не оставались
		# после перехода с дождя/снега/тумана на ясную погоду.
		environment.fog_enabled = false

	match weather:
		"clear":
			cloud_coverage = 0.12
			if sky_material:
				sky_material.set_shader_parameter("cloud_opacity", 0.16)

		"rain":
			cloud_coverage = 0.82
			rain.emitting = true
			if sky_material:
				sky_material.set_shader_parameter("cloud_opacity", 0.75)

			if environment:
				environment.fog_enabled = true
				environment.fog_density = 0.015
				environment.fog_light_color = Color(0.35, 0.42, 0.48)

		"snow":
			cloud_coverage = 0.72
			snow.emitting = true
			if sky_material:
				sky_material.set_shader_parameter("cloud_opacity", 0.65)

			if environment:
				environment.fog_enabled = true
				environment.fog_density = 0.025
				environment.fog_light_color = Color(0.75, 0.8, 0.85)

		"fog":
			cloud_coverage = 0.65
			if sky_material:
				sky_material.set_shader_parameter("cloud_opacity", 0.45)

			if environment:
				environment.fog_enabled = true
				environment.fog_density = 0.04
				environment.fog_light_color = Color(0.55, 0.6, 0.62)

		_:
			push_warning("Неизвестный тип погоды: " + weather)
			cloud_coverage = 0.12
			if sky_material:
				sky_material.set_shader_parameter("cloud_opacity", 0.16)

	_update_sky_shader()


func random_weather() -> void:
	var weather_types := ["clear", "rain", "snow", "fog"]
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



func set_time_scale(new_scale: float) -> void:
	time_scale = maxf(new_scale, 0.0)


func set_world_time(hour: float, elapsed_world_seconds: float = 0.0) -> void:
	time_of_day = fposmod(hour, 24.0)
	total_world_seconds = maxf(elapsed_world_seconds, 0.0)
	update_day_night()


func get_world_time_save_data() -> Dictionary:
	return {
		"time_of_day": time_of_day,
		"total_world_seconds": total_world_seconds,
		"time_scale": time_scale,
	}


func restore_world_time(data: Dictionary) -> void:
	set_world_time(
		float(data.get("time_of_day", start_time)),
		float(data.get("total_world_seconds", 0.0))
	)
	time_scale = maxf(float(data.get("time_scale", time_scale)), 0.0)


func _update_moon_direction() -> void:
	if sky_material == null:
		return

	# Один игровой день длится day_length_seconds реальных секунд.
	var game_days := total_world_seconds / maxf(day_length_seconds, 0.001)
	var orbit_angle := TAU * game_days / moon_orbit_days

	var inclination := deg_to_rad(moon_orbit_inclination_degrees)

	var moon_direction := Vector3(
		cos(orbit_angle),
		sin(orbit_angle) * cos(inclination),
		sin(orbit_angle) * sin(inclination)
	).normalized()

	sky_material.set_shader_parameter("moon_direction", moon_direction)
