class_name DoorHandAction
extends HandAction3D


@export var hinge: HingeJoint3D
@export_range(0.0, 20.0, 0.1) var mouse_to_speed: float = 0.04
@export_range(0.0, 10000.0, 1.0) var motor_max_impulse: float = 20.0
@export_range(0.0, 20.0, 0.1) var max_motor_speed: float = 4.0

var active_mouse_sign: float = 1.0


func _ready() -> void:
	if hinge == null:
		push_warning("DoorHandAction: не назначен HingeJoint3D")
		return

	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)


func begin(
	target_hand: HandController,
	target_handle: InteractionHandle3D
) -> bool:
	if hinge == null:
		push_warning("DoorHandAction: не назначен HingeJoint3D")
		return false

	if target_handle == null:
		return false

	if not super.begin(target_hand, target_handle):
		return false

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

	super.end()
