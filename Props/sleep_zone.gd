class_name SleepZone
extends Area3D

@export_range(-100000, 100000, 1) var SLeep_priority: int = 0
@export var sleep_effect: StatusEffectData
@export_multiline var surface_description: String = ""

func _ready() -> void:
	add_to_group(&"sleep_zones")
