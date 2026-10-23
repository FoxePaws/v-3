class_name HeartHitEffect
extends Node3D


@export_category("References")
@export var hit_receiver: HitReceiver
@export var particles: GPUParticles3D


@export_category("Effect")
@export var effect_offset: Vector3 = Vector3.ZERO
@export var restart_on_new_hit: bool = true


func _ready() -> void:
	if hit_receiver == null:
		hit_receiver = _find_hit_receiver()

	if particles == null:
		particles = get_node_or_null(
			"GPUParticles3D"
		) as GPUParticles3D

	if hit_receiver == null:
		push_error(
			"HeartHitEffect '%s': HitReceiver не найден"
			% get_path()
		)
		return

	if particles == null:
		push_error(
			"HeartHitEffect '%s': GPUParticles3D не найден"
			% get_path()
		)
		return

	hit_receiver.hit_received.connect(
		_on_hit_received
	)


func _find_hit_receiver() -> HitReceiver:
	var current_node: Node = self

	while current_node != null:
		if current_node is HitReceiver:
			return current_node as HitReceiver

		current_node = current_node.get_parent()

	return null


func _on_hit_received(
	_attacker: Node,
	_damage: float,
	hit_position: Vector3,
	_hit_normal: Vector3
) -> void:
	if particles == null:
		return

	# Перемещаем эффект в точку попадания.
	particles.global_position = hit_position

	if restart_on_new_hit:
		particles.restart()

	particles.emitting = true
