class_name Flashlight
extends ItemInstance

@onready var light: SpotLight3D = $SpotLight3D
@onready var switch_sound: AudioStreamPlayer3D = (
	$SwitchSound
)

var is_on: bool = false


func _ready() -> void:
	super()

	if light != null:
		light.visible = false


func on_primary_action() -> void:
	is_on = not is_on

	if light != null:
		light.visible = is_on

	if switch_sound != null:
		switch_sound.play()


func on_secondary_action() -> void:
	if light == null:
		return

	if is_equal_approx(light.spot_angle, 45.0):
		light.spot_angle = 20.0
		light.spot_range = 10.0
		light.light_energy = 2.0
	else:
		light.spot_angle = 45.0
		light.spot_range = 5.0
		light.light_energy = 1
