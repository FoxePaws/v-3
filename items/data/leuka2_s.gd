class_name WateringCant
extends ItemInstance


@onready var water_particles: GPUParticles3D = $WaterParticles


func _ready() -> void:
	super._ready()

	water_particles.emitting = false


func _process(_delta: float) -> void:

	# Если клавиша отпущена — прекращаем полив.
	if not Input.is_action_pressed("primary_action"):
		water_particles.emitting = false


func on_primary_action() -> void:

	water_particles.emitting = true


func on_secondary_action() -> void:
	print("Лейка наклонена")
