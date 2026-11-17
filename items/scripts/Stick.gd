class_name Stick
extends ItemInstance


@export_category("Strike")
@export var damage: float = 10.0
@export var primary_strike_angle: float = -100.0
@export var secondary_strike_angle: float = -100.0
@export var strike_duration: float = 0.22
@export var return_duration: float = 0.18
@export var stop_on_collision: bool = true


@export_category("Strike Axis")
@export var primary_rotation_axis: Vector3 = Vector3(
	0.0,
	0.0,
	1.0
)

@export var secondary_rotation_axis: Vector3 = Vector3(
	1.0,
	0.0,
	0.0
)


@export_category("References")
@export var rotation_point: Marker3D
@export var strike_cast: ShapeCast3D


var attacking: bool = false
var attack_hand: Node3D = null
var attack_tween: Tween = null


# Положение руки относительно её родителя
# в момент начала атаки.
var saved_hand_local_transform: Transform3D = (
	Transform3D.IDENTITY
)

# Положение RotationPoint относительно руки
# в момент начала атаки.
var rotation_point_local_to_hand: Transform3D = (
	Transform3D.IDENTITY
)


var current_attack_axis: Vector3 = Vector3.ZERO
var current_attack_angle: float = 0.0
var current_attack_progress: float = 0.0

# Значение прогресса, которое передаёт Tween.
var pending_attack_progress: float = 0.0

var already_hit_objects: Array[Node] = []


func _ready() -> void:
	super()

	if primary_grip_point == null:
		primary_grip_point = get_node_or_null(
			"PrimaryGripPoint"
		) as Marker3D

	if secondary_grip_point == null:
		secondary_grip_point = get_node_or_null(
			"SecondaryGripPoint"
		) as Marker3D

	if rotation_point == null:
		rotation_point = get_node_or_null(
			"RotationPoint"
		) as Marker3D

	if strike_cast == null:
		strike_cast = get_node_or_null(
			"StrikeCast"
		) as ShapeCast3D


func _process(_delta: float) -> void:
	if not attacking:
		return

	if strike_cast == null:
		return

	strike_cast.force_shapecast_update()
	_check_strike_collision()


func _physics_process(_delta: float) -> void:
	if not attacking:
		return

	if attack_hand == null:
		return

	_apply_attack_hand_transform()


func on_primary_action() -> void:
	_start_attack(
		primary_rotation_axis,
		primary_strike_angle
	)


func on_secondary_action() -> void:
	_start_attack(
		secondary_rotation_axis,
		secondary_strike_angle
	)


func _start_attack(
	rotation_axis: Vector3,
	angle: float
) -> void:
	if attacking:
		return

	if current_hand == null:
		return

	if not current_hand is Node3D:
		return

	if rotation_point == null:
		return

	var hand := current_hand as Node3D
	var hand_parent := hand.get_parent() as Node3D

	if hand_parent == null:
		return

	attack_hand = hand

	# Сохраняем локальную позу руки
	# относительно её текущего родителя.
	saved_hand_local_transform = (
		hand_parent.global_transform.affine_inverse()
		* hand.global_transform
	)

	# Сохраняем положение RotationPoint
	# относительно руки.
	rotation_point_local_to_hand = (
		hand.global_transform.affine_inverse()
		* rotation_point.global_transform
	)

	current_attack_axis = rotation_axis.normalized()
	current_attack_angle = angle
	current_attack_progress = 0.0
	pending_attack_progress = 0.0

	already_hit_objects.clear()
	attacking = true

	if attack_tween != null:
		attack_tween.kill()

	attack_tween = create_tween()

	attack_tween.set_trans(Tween.TRANS_QUAD)
	attack_tween.set_ease(Tween.EASE_OUT)

	attack_tween.tween_method(
		_apply_attack_rotation,
		0.0,
		1.0,
		strike_duration
	)

	attack_tween.tween_callback(
		_start_return_animation
	)


func _apply_attack_rotation(progress: float) -> void:
	if attack_hand == null:
		return

	current_attack_progress = progress
	pending_attack_progress = progress


func _start_return_animation() -> void:
	if attack_hand == null:
		_finish_attack()
		return

	if attack_tween != null:
		attack_tween.kill()

	attack_tween = create_tween()

	attack_tween.set_trans(Tween.TRANS_QUAD)
	attack_tween.set_ease(Tween.EASE_IN_OUT)

	attack_tween.tween_method(
		_apply_return_rotation,
		1.0,
		0.0,
		return_duration
	)

	attack_tween.tween_callback(
		_finish_attack
	)


func _apply_return_rotation(progress: float) -> void:
	if attack_hand == null:
		return

	current_attack_progress = progress
	pending_attack_progress = progress


func _apply_attack_hand_transform() -> void:
	if attack_hand == null:
		return

	var hand_parent := attack_hand.get_parent() as Node3D

	if hand_parent == null:
		return

	# Получаем актуальное мировое положение руки
	# с учётом движения игрока и камеры.
	var base_hand_transform: Transform3D = (
		hand_parent.global_transform
		* saved_hand_local_transform
	)

	# Получаем актуальную мировую трансформацию
	# точки вращения с учётом движения родителя.
	var current_rotation_point_transform: Transform3D = (
		base_hand_transform
		* rotation_point_local_to_hand
	)

	var angle_radians: float = lerp(
		0.0,
		deg_to_rad(current_attack_angle),
		pending_attack_progress
	)

	var rotation_basis := Basis(
		current_attack_axis,
		angle_radians
	)

	var rotation_transform := Transform3D(
		rotation_basis,
		Vector3.ZERO
	)

	# Вращаем руку вокруг RotationPoint.
	var rotated_world_transform: Transform3D = (
		current_rotation_point_transform
		* rotation_transform
		* current_rotation_point_transform.affine_inverse()
		* base_hand_transform
	)

	# Переводим полученный мировой результат
	# обратно в локальные координаты руки.
	attack_hand.transform = (
		hand_parent.global_transform.affine_inverse()
		* rotated_world_transform
	)


func _finish_attack() -> void:
	if attack_hand != null:
		pending_attack_progress = 0.0
		current_attack_progress = 0.0

		_apply_attack_hand_transform()

	attacking = false
	attack_hand = null
	attack_tween = null

	already_hit_objects.clear()


func _check_strike_collision() -> void:
	if strike_cast == null:
		return

	if not strike_cast.is_colliding():
		return

	var collision_count: int = (
		strike_cast.get_collision_count()
	)

	for index: int in range(collision_count):
		var collider: Object = (
			strike_cast.get_collider(index)
		)

		if collider == null:
			continue

		if collider == self:
			continue

		if collider is Node:
			_process_hit(
				collider as Node,
				index
			)


func _process_hit(
	collider: Node,
	collision_index: int
) -> void:
	if collider == null:
		return

	var receiver: HitReceiver = (
		_find_hit_receiver(collider)
	)

	if receiver != null:
		if receiver not in already_hit_objects:
			already_hit_objects.append(receiver)

			var hit_position: Vector3 = (
				strike_cast.get_collision_point(
					collision_index
				)
			)

			var hit_normal: Vector3 = (
				strike_cast.get_collision_normal(
					collision_index
				)
			)

			receiver.receive_hit(
				self,
				damage,
				hit_position,
				hit_normal
			)

	if stop_on_collision:
		_stop_attack_on_collision()


func _find_hit_receiver(
	node: Node
) -> HitReceiver:
	var current_node: Node = node

	while current_node != null:
		if current_node is HitReceiver:
			return current_node as HitReceiver

		current_node = current_node.get_parent()

	return null


func _stop_attack_on_collision() -> void:
	if attack_tween != null:
		attack_tween.kill()

	if attack_hand != null:
		pending_attack_progress = 0.0
		current_attack_progress = 0.0

		_apply_attack_hand_transform()

	attacking = false
	attack_hand = null
	attack_tween = null

	already_hit_objects.clear()
