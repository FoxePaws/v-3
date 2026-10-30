extends Node3D

@export var day_length_seconds: float = 120.0
@export var start_time: float = 8.0

@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var rain: GPUParticles3D = $Weather/Rain
@onready var snow: GPUParticles3D = $Weather/Snow
@onready var player: Node3D = $Playermal

func update_weather_position() -> void:
	rain.global_position = player.global_position + Vector3(0, 8, 0)
	snow.global_position = player.global_position + Vector3(0, 8, 0)

var time_of_day: float = 8.0
var current_weather: String = "clear"

func _ready() -> void:
	time_of_day = start_time
	set_weather("clear")
	update_day_night()


func _process(delta: float) -> void:
	# Продвижение игрового времени
	time_of_day += delta * 24.0 / day_length_seconds

	if time_of_day >= 24.0:
		time_of_day -= 24.0

	update_day_night()
	update_weather_position()

func update_day_night() -> void:
	var sun_angle := (time_of_day / 24.0) * 360.0 - 90.0
	sun.rotation_degrees.x = -sun_angle

	var sun_height := sin(deg_to_rad(sun_angle))

# Солнце начинает заметно темнеть только глубже за горизонтом
	var sun_visibility := smoothstep(-0.8, 0.35, sun_height)

# Чем меньше степень, тем дольше солнце остаётся ярким
	var light_factor := pow(sun_visibility, 0.35)

# Минимальная яркость в сумерках
	sun.light_energy = lerp(0.08, 1.2, light_factor)

# Полностью выключаем солнце только глубокой ночью
	if sun_height < -0.8:
		sun.light_energy = 0.0

	# Цвет на рассвете и закате
	var warm_factor := 1.0 - smoothstep(0.15, 0.7, sun_height)

	var day_color := Color(1.0, 0.92, 0.75)
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

		environment.adjustment_enabled = true
		environment.adjustment_brightness = lerp(
			0.65,
			1.1,
			ambient_factor
		)


func set_weather(weather: String) -> void:
	current_weather = weather

	rain.emitting = false
	snow.emitting = false

	var environment := world_environment.environment

	match weather:
		"clear":
			if environment:
				environment.fog_enabled = false

		"rain":
			rain.emitting = true

			if environment:
				environment.fog_enabled = true
				environment.fog_density = 0.015
				environment.fog_light_color = Color(0.35, 0.42, 0.48)

		"snow":
			snow.emitting = true

			if environment:
				environment.fog_enabled = true
				environment.fog_density = 0.025
				environment.fog_light_color = Color(0.75, 0.8, 0.85)

		"fog":
			if environment:
				environment.fog_enabled = true
				environment.fog_density = 0.04
				environment.fog_light_color = Color(0.55, 0.6, 0.62)


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
