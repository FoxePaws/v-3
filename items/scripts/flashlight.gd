class_name Flashlight
extends ItemComponent


var light: SpotLight3D = null
var switch_sound: AudioStreamPlayer3D = null


func _ready() -> void:
	super._ready()

	if item == null:
		push_warning("Flashlight: компонент не прикреплён к ItemInstance")
		return

	light = item.get_node_or_null("SpotLight3D") as SpotLight3D
	switch_sound = (
		item.get_node_or_null("SwitchSound") as AudioStreamPlayer3D
	)

	var is_on: bool = bool(mutable_state.get("is_on", false))
	if light != null:
		light.visible = is_on


func on_primary_action() -> void:
	if item == null:
		return

	var is_on: bool = not bool(mutable_state.get("is_on", false))
	mutable_state["is_on"] = is_on

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
		light.light_energy = 1.0
