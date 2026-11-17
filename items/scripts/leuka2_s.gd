class_name WateringCan
extends ItemComponent


@export var water_particles: GPUParticles3D


func _ready() -> void:
	super._ready()

	if water_particles == null and item != null:
		water_particles = (
			item.get_node_or_null("WaterParticles") as GPUParticles3D
		)

	if water_particles != null:
		water_particles.emitting = false
	else:
		push_warning("WateringCan: не найден узел WaterParticles")


func on_primary_action() -> void:
	if water_particles != null:
		water_particles.emitting = true


func on_primary_action_released() -> void:
	if water_particles != null:
		water_particles.emitting = false


func on_secondary_action() -> void:
	print("Лейка наклонена")
