class_name DoorHandAction
extends HandAction3D


@export var hinge: HingeJoint3D
@export_range(0.0, 20.0, 0.1) var mouse_to_speed: float = 0.04
@export_range(0.0, 10000.0, 0.1) var motor_max_impulse: float = 20.0
@export_range(0.0, 20.0, 0.1) var max_motor_speed: float = 4.0

@export var door_body: RigidBody3D

@export var enable_close_lock: bool = true
@export var close_lock_only_while_held: bool = false

var has_left_closed_position: bool = false


@export_range(0.0, 15.0, 0.1) var closed_angle_tolerance_degrees: float = 2.0
@export_range(0.0, 2.0, 0.01) var closed_angular_speed_threshold: float = 0.08
@export var frame_body: Node3D

var closed_relative_basis: Basis = Basis.IDENTITY
var closed_transform_ready: bool = false


var closed_basis: Basis = Basis.IDENTITY


var active_mouse_sign: float = 1.0

func _ready() -> void:
	if hinge == null:
		push_warning("DoorHandAction: не назначен HingeJoint3D")
		return

	if door_body == null:
		door_body = get_parent() as RigidBody3D

	if door_body == null:
		push_warning("DoorHandAction: не найден RigidBody3D двери")
		return

	if frame_body == null:
		push_warning("DoorHandAction: не назначена рама двери")
		return

	closed_relative_basis = (
		frame_body.global_transform.basis.inverse()
		* door_body.global_transform.basis
	).orthonormalized()

	closed_transform_ready = true
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)


func begin(
	target_hand: HandController,
	target_handle: InteractionHandle3D
) -> bool:
	if door_body == null or hinge == null:
		return false

	door_body.freeze = false
	door_body.sleeping = false

	if not super.begin(target_hand, target_handle):
		return false

	has_left_closed_position = false
	active_mouse_sign = target_handle.mouse_y_sign

	hinge.set_param(
		HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
		motor_max_impulse
	)
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	return true




func on_mouse_motion(relative: Vector2) -> void:
	if not is_active or hinge == null:
		return

	var target_velocity: float = (
		-relative.y
		* mouse_to_speed
		* active_mouse_sign
	)
	target_velocity = clampf(
		target_velocity,
		-max_motor_speed,
		max_motor_speed
	)

	hinge.set_param(
		HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
		target_velocity
	)

func end() -> void:
	if hinge != null:
		hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)

	if door_body != null:
		door_body.sleeping = false

	super.end()

func _physics_process(_delta: float) -> void:
	if not enable_close_lock:
		return

	if door_body == null or frame_body == null:
		return

	if not closed_transform_ready or door_body.freeze:
		return

	var near_closed: bool = _is_near_closed_position()

	if is_active:
		# Не защёлкиваем дверь сразу при захвате ручки.
		# Сначала она должна открыться, затем вернуться в закрытую зону.
		if not near_closed:
			has_left_closed_position = true
			return

		if not has_left_closed_position:
			return
	elif close_lock_only_while_held:
		return

	if not near_closed:
		return

	if door_body.angular_velocity.length() > closed_angular_speed_threshold:
		return

	door_body.angular_velocity = Vector3.ZERO
	door_body.freeze = true


func _is_near_closed_position() -> bool:
	if door_body == null or frame_body == null:
		return false

	var current_relative_basis: Basis = (
		frame_body.global_transform.basis.inverse()
		* door_body.global_transform.basis
	).orthonormalized()

	var relative_rotation: Quaternion = (
		closed_relative_basis.inverse()
		* current_relative_basis
	).orthonormalized().get_rotation_quaternion()

	var relative_angle_radians: float = 2.0 * acos(
		clampf(absf(relative_rotation.w), 0.0, 1.0)
	)

	return relative_angle_radians <= deg_to_rad(
		closed_angle_tolerance_degrees
	)
