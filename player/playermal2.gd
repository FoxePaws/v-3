class_name Player
extends RigidBody3D

signal jump_started
signal landed

enum BodyState {
	STANDING,
	CROUCHING,
	LYING
}

@export_category("References")
@export var camera: Camera3D
@export var camera_pivot: Node3D
@export var visual_root: Node3D
@export var ground_ray_left: RayCast3D
@export var ground_ray_right: RayCast3D

@export_category("Movement")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
@export var prone_speed: float = 1.0
@export var slow_walk_multiplier: float = 0.55
@export var ground_acceleration: float = 18.0
@export var air_acceleration: float = 5.0
@export var jump_impulse: float = 5.0
@export var jump_support_lock_time: float = 0.25

@export_category("Virtual ground support")
@export var target_ray_gap: float = 0.35
@export var support_stiffness: float = 8.0
@export var support_damping: float = 7.0
@export var max_support_correction: float = 4.0

@export_category("Body rotation")
@export var body_turn_speed: float = 5.0
@export var camera_dead_zone_degrees: float = 35.0

@export_category("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch_degrees: float = -85.0
@export var max_pitch_degrees: float = 85.0
@export var vertical_body_follow_speed: float = 5.0

@export_category("Visual pose")
@export var body_state_speed: float = 10.0
@export var crouch_root_offset: float = -0.35
@export var crouch_root_pitch_degrees: float = -8.0
@export var lying_root_offset: float = -0.75
@export var lying_root_pitch_degrees: float = -90.0

var body_state: BodyState = BodyState.STANDING
var view_pitch: float = 0.0

var _left_ground_gap: float = 0.0
var _right_ground_gap: float = 0.0
var _has_left_ground_hit: bool = false
var _has_right_ground_hit: bool = false
var _previously_supported: bool = false

var _jump_requested: bool = false
var _jump_support_lock: float = 0.0
var _desired_yaw_rate: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	can_sleep = false

	# Оставляем вращение только вокруг вертикальной оси.
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	axis_lock_angular_y = false

	if ground_ray_left != null:
		ground_ray_left.add_exception(self)

	if ground_ray_right != null:
		ground_ray_right.add_exception(self)


func _physics_process(delta: float) -> void:
	_jump_support_lock = maxf(
		0.0,
		_jump_support_lock - delta
	)

	_update_ground_ray_data()
	_update_body_state()
	_update_visual_pose(delta)
	_apply_horizontal_movement(delta)
	_update_body_yaw(delta)
	_update_camera_pitch(delta)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _jump_requested and _has_two_ground_hits():
		state.apply_central_impulse(
			Vector3.UP * jump_impulse * mass
		)
		_jump_requested = false
		_jump_support_lock = jump_support_lock_time
		_previously_supported = false
		jump_started.emit()
		return

	_jump_requested = false

	# Управляем поворотом физического тела через его угловую скорость.
	state.angular_velocity.y = _desired_yaw_rate

	if _jump_support_lock > 0.0:
		_previously_supported = false
		return

	if not _has_two_ground_hits():
		_previously_supported = false
		return

	var measured_gap: float = (
		_left_ground_gap + _right_ground_gap
	) * 0.5

	var height_error: float = target_ray_gap - measured_gap
	var gravity_magnitude: float = -state.total_gravity.dot(Vector3.UP)
	var vertical_speed: float = state.linear_velocity.dot(Vector3.UP)

	var correction: float = (
		support_stiffness * height_error
		- support_damping * vertical_speed
	)

	correction = clampf(
		correction,
		-gravity_magnitude,
		max_support_correction
	)

	var upward_acceleration: float = gravity_magnitude + correction

	state.apply_central_force(
		Vector3.UP * upward_acceleration * mass
	)

	if not _previously_supported:
		landed.emit()

	_previously_supported = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = (
			event as InputEventMouseMotion
		)
		_rotate_camera_by_mouse(mouse_motion.relative)

	if event.is_action_pressed(&"jump"):
		_jump_requested = true

	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _update_ground_ray_data() -> void:
	_has_left_ground_hit = false
	_has_right_ground_hit = false

	if ground_ray_left != null and ground_ray_left.enabled:
		ground_ray_left.force_raycast_update()
		_has_left_ground_hit = ground_ray_left.is_colliding()

		if _has_left_ground_hit:
			_left_ground_gap = (
				ground_ray_left.global_position.y
				- ground_ray_left.get_collision_point().y
			)

	if ground_ray_right != null and ground_ray_right.enabled:
		ground_ray_right.force_raycast_update()
		_has_right_ground_hit = ground_ray_right.is_colliding()

		if _has_right_ground_hit:
			_right_ground_gap = (
				ground_ray_right.global_position.y
				- ground_ray_right.get_collision_point().y
			)


func _has_two_ground_hits() -> bool:
	return _has_left_ground_hit and _has_right_ground_hit


func _apply_horizontal_movement(delta: float) -> void:
	if camera == null:
		return

	var input_vector: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_forward",
		&"move_backward"
	)

	var camera_forward: Vector3 = -camera.global_basis.z
	var camera_right: Vector3 = camera.global_basis.x

	camera_forward.y = 0.0
	camera_right.y = 0.0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()

	var move_direction: Vector3 = (
		camera_right * input_vector.x
		+ camera_forward * -input_vector.y
	)

	if move_direction.length_squared() > 1.0:
		move_direction = move_direction.normalized()

	var target_speed: float = _get_move_speed()

	if Input.is_action_pressed(&"slow_walk"):
		target_speed *= slow_walk_multiplier

	var target_velocity: Vector3 = move_direction * target_speed
	var current_velocity: Vector3 = Vector3(
		linear_velocity.x,
		0.0,
		linear_velocity.z
	)

	var acceleration: float = ground_acceleration
	if not _has_two_ground_hits():
		acceleration = air_acceleration

	var velocity_difference: Vector3 = target_velocity - current_velocity
	var required_acceleration: Vector3 = (
		velocity_difference / maxf(delta, 0.0001)
	)
	required_acceleration = required_acceleration.limit_length(acceleration)

	apply_central_force(required_acceleration * mass)


func _get_move_speed() -> float:
	match body_state:
		BodyState.CROUCHING:
			return crouch_speed
		BodyState.LYING:
			return prone_speed
		BodyState.STANDING:
			if Input.is_action_pressed(&"sprint"):
				return sprint_speed
			return walk_speed

	return walk_speed


func _update_body_state() -> void:
	if Input.is_action_just_pressed(&"prone"):
		if body_state == BodyState.LYING:
			body_state = BodyState.STANDING
		else:
			body_state = BodyState.LYING
		return

	if body_state == BodyState.LYING:
		return

	if Input.is_action_pressed(&"crouch"):
		body_state = BodyState.CROUCHING
	else:
		body_state = BodyState.STANDING


func _update_visual_pose(delta: float) -> void:
	if visual_root == null:
		return

	var target_y: float = 0.0
	var target_pitch: float = 0.0

	match body_state:
		BodyState.STANDING:
			target_y = 0.0
			target_pitch = 0.0
		BodyState.CROUCHING:
			target_y = crouch_root_offset
			target_pitch = deg_to_rad(crouch_root_pitch_degrees)
		BodyState.LYING:
			target_y = lying_root_offset
			target_pitch = deg_to_rad(lying_root_pitch_degrees)

	var weight: float = 1.0 - exp(-body_state_speed * delta)

	visual_root.position.y = lerpf(
		visual_root.position.y,
		target_y,
		weight
	)

	visual_root.rotation.x = lerp_angle(
		visual_root.rotation.x,
		target_pitch,
		weight
	)


func _update_body_yaw(delta: float) -> void:
	if camera_pivot == null:
		_desired_yaw_rate = 0.0
		return

	var camera_offset: float = wrapf(
		camera_pivot.rotation.y,
		-PI,
		PI
	)

	var dead_zone: float = deg_to_rad(camera_dead_zone_degrees)
	if _has_movement_input():
		dead_zone = 0.0

	if absf(camera_offset) <= dead_zone:
		_desired_yaw_rate = 0.0
		return

	var turn_error: float = (
		absf(camera_offset) - dead_zone
	) * signf(camera_offset)

	_desired_yaw_rate = clampf(
		turn_error / maxf(delta, 0.0001),
		-body_turn_speed,
		body_turn_speed
	)

	camera_pivot.rotation.y -= _desired_yaw_rate * delta
	camera_pivot.rotation.y = wrapf(
		camera_pivot.rotation.y,
		-PI,
		PI
	)


func _update_camera_pitch(delta: float) -> void:
	if camera_pivot == null:
		return

	var lower_dead_zone: float = deg_to_rad(-25.0)
	var upper_dead_zone: float = deg_to_rad(25.0)

	if body_state == BodyState.LYING:
		lower_dead_zone = deg_to_rad(-10.0)
		upper_dead_zone = deg_to_rad(45.0)

	var target_body_pitch: float = 0.0

	if view_pitch < lower_dead_zone:
		target_body_pitch = view_pitch - lower_dead_zone
	elif view_pitch > upper_dead_zone:
		target_body_pitch = view_pitch - upper_dead_zone

	target_body_pitch = clampf(
		target_body_pitch,
		deg_to_rad(-35.0),
		deg_to_rad(35.0)
	)

	camera_pivot.rotation.x = move_toward(
		camera_pivot.rotation.x,
		target_body_pitch,
		vertical_body_follow_speed * delta
	)


func _rotate_camera_by_mouse(relative: Vector2) -> void:
	if camera_pivot == null:
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	camera_pivot.rotation.y -= relative.x * mouse_sensitivity
	view_pitch -= relative.y * mouse_sensitivity

	view_pitch = clampf(
		view_pitch,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)


func _has_movement_input() -> bool:
	var input_vector: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_forward",
		&"move_backward"
	)

	return input_vector.length_squared() > 0.0
