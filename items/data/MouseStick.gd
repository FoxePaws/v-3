class_name MouseStick
extends Stick


@export_category("Mouse Rotation")
@export var mouse_sensitivity: float = 0.015
@export var max_mouse_angle: float = 100.0
@export var mouse_action: StringName = &"primary_action"


var mouse_attacking: bool = false
var mouse_hand: Node3D = null
var mouse_rotation_point_transform: Transform3D = (
	Transform3D.IDENTITY
)
var mouse_saved_hand_transform: Transform3D = (
	Transform3D.IDENTITY
)
var mouse_angle: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if current_hand == null:
		return

	if event.is_action_pressed(mouse_action):
		_start_mouse_attack()

	if event.is_action_released(mouse_action):
		_finish_mouse_attack()

	if event is InputEventMouseMotion:
		if mouse_attacking:
			var mouse_event: InputEventMouseMotion = (
				event as InputEventMouseMotion
			)

			_rotate_with_mouse(
				mouse_event.relative
			)


func _start_mouse_attack() -> void:
	if mouse_attacking:
		return

	if current_hand == null:
		return

	if not current_hand is Node3D:
		return

	if rotation_point == null:
		return

	mouse_hand = current_hand as Node3D

	mouse_saved_hand_transform = (
		mouse_hand.global_transform
	)

	mouse_rotation_point_transform = (
		rotation_point.global_transform
	)

	mouse_angle = 0.0
	mouse_attacking = true
	attacking = true

	if attack_tween != null:
		attack_tween.kill()

	already_hit_objects.clear()


func _rotate_with_mouse(relative: Vector2) -> void:
	if mouse_hand == null:
		return

	var horizontal_delta: float = (
		-relative.x * mouse_sensitivity
	)

	mouse_angle += horizontal_delta
	mouse_angle = clamp(
		mouse_angle,
		-max_mouse_angle,
		max_mouse_angle
	)

	var axis: Vector3 = Vector3(
		0.0,
		0.0,
		1.0
	)

	var angle_radians: float = (
		deg_to_rad(mouse_angle)
	)

	var rotation_basis: Basis = Basis(
		axis,
		angle_radians
	)

	var pivot_transform: Transform3D = (
		mouse_rotation_point_transform
	)

	var rotated_transform: Transform3D = (
		pivot_transform
		* Transform3D(
			rotation_basis,
			Vector3.ZERO
		)
		* pivot_transform.affine_inverse()
		* mouse_saved_hand_transform
	)

	mouse_hand.global_transform = rotated_transform

	if strike_cast != null:
		strike_cast.force_shapecast_update()
		_check_strike_collision()


func _finish_mouse_attack() -> void:
	if not mouse_attacking:
		return

	if mouse_hand == null:
		_reset_mouse_attack()
		return

	if attack_tween != null:
		attack_tween.kill()

	attack_tween = create_tween()
	attack_tween.set_trans(Tween.TRANS_QUAD)
	attack_tween.set_ease(Tween.EASE_IN_OUT)

	attack_tween.tween_property(
		mouse_hand,
		"global_transform",
		mouse_saved_hand_transform,
		return_duration
	)

	attack_tween.tween_callback(
		_reset_mouse_attack
	)


func _reset_mouse_attack() -> void:
	if mouse_hand != null:
		mouse_hand.global_transform = (
			mouse_saved_hand_transform
		)

	mouse_attacking = false
	attacking = false
	mouse_hand = null
	attack_tween = null
	mouse_angle = 0.0
	already_hit_objects.clear()
