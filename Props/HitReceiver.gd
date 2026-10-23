class_name HitReceiver
extends Area3D


signal hit_received(
	attacker: Node,
	damage: float,
	hit_position: Vector3,
	hit_normal: Vector3
)


@export var damage_multiplier: float = 1.0


#func receive_hit(
	#attacker: Node,
	#damage: float,
	#hit_position: Vector3,
	#hit_normal: Vector3) -> void:
	#var final_damage: float = (
		#damage * damage_multiplier
	#)
#
	#print(
		#"HitReceiver получил удар. Урон: ",
		#final_damage
	#)
#
	#hit_received.emit(
		#attacker,
		#final_damage,
		#hit_position,
		#hit_normal
	#)

func receive_hit(
	attacker: Node,
	damage: float,
	hit_position: Vector3,
	hit_normal: Vector3) -> void:
	var final_damage: float = (
		damage * damage_multiplier
	)

	hit_received.emit(
		attacker,
		final_damage,
		hit_position,
		hit_normal
	)
