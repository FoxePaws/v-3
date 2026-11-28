class_name ProceduralLegController
extends Node3D

signal foot_contact(foot_index: int, world_position: Vector3)

@export_category("Player")
@export var player: Player

@export_category("Left leg")
@export var left_orbit_axis: Node3D
@export var left_orbit_marker: Node3D
@export var left_ground_ray: RayCast3D
@export var left_ik_target: Node3D

@export_category("Right leg")
@export var right_orbit_axis: Node3D
@export var right_orbit_marker: Node3D
@export var right_ground_ray: RayCast3D
@export var right_ik_target: Node3D

@export_category("Orbit radii")
@export var standing_radius: float = 0.02
@export var walking_radius: float = 0.35
@export var running_radius: float = 0.55
@export var crouching_radius: float = 0.2
@export var radius_transition_speed: float = 5.0

@export_category("Orbit speed")
@export var walk_orbit_speed: float = 4.0
@export var run_orbit_speed: float = 6.0
@export var crouch_orbit_speed: float = 2.5

@export_category("Ray settings")
@export var ray_start_height: float = 0.35
@export var ray_length: float = 1.5
@export var foot_surface_offset: float = 0.03

@export_category("Step sound")
@export var step_audio: AudioStreamPlayer3D

var _current_radius: float = 0.0
var _left_was_at_ground: bool = false
var _right_was_at_ground: bool = false

@export var minimum_orbit_radius: float = 0.05
@export var maximum_orbit_speed: float = 12.0
@export var movement_direction_threshold: float = 0.1
@export var direction_turn_speed: float = 8.0

var _left_ray_base_x: float = 0.0
var _right_ray_base_x: float = 0.0




func _ready() -> void:
	if left_ground_ray != null:
		_left_ray_base_x = left_ground_ray.position.x
		_configure_ray(left_ground_ray)

	if right_ground_ray != null:
		_right_ray_base_x = right_ground_ray.position.x
		_configure_ray(right_ground_ray)


func _physics_process(delta: float) -> void:
	if player == null:
		return

	_current_radius = move_toward(
		_current_radius,
		_get_target_radius(),
		radius_transition_speed * delta
	)

	_set_orbit_radius(left_orbit_marker, _current_radius)
	_set_orbit_radius(right_orbit_marker, _current_radius)

	_update_controller_direction(delta)
	_rotate_orbits(delta)

	_update_foot(
		left_orbit_marker,
		left_ground_ray,
		left_ik_target,
		_left_ray_base_x,
		0,
		delta
	)
	_update_foot(
		right_orbit_marker,
		right_ground_ray,
		right_ik_target,
		_right_ray_base_x,
		1,
		delta
	)


func _update_controller_direction(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_forward",
		&"move_backward"
	)

	if input_vector.length() < movement_direction_threshold:
		return

	# Движение задано относительно камеры, поэтому переводим его в мир.
	var camera: Camera3D = player.camera
	if camera == null:
		return

	var camera_forward: Vector3 = -camera.global_basis.z
	var camera_right: Vector3 = -camera.global_basis.x
	camera_forward.y = 0.0
	camera_right.y = 0.0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()

	var world_direction: Vector3 = (
		camera_right * input_vector.x
		+ camera_forward * -input_vector.y
	).normalized()

	# Переводим направление движения в локальные координаты Player.
	var local_direction: Vector3 = (
		player.global_basis.inverse() * world_direction
	).normalized()

	# Угол вокруг Y: вперёд, вбок и диагональные направления.
	var target_yaw: float = atan2(
		local_direction.x,
		-local_direction.z
	)

	var current_yaw: float = rotation.y
	var weight: float = 1.0 - exp(-direction_turn_speed * delta)
	rotation.y = lerp_angle(current_yaw, target_yaw, weight)


func _rotate_orbits(delta: float) -> void:
	if _current_radius < minimum_orbit_radius:
		return

	var horizontal_speed: float = Vector2(
		player.linear_velocity.x,
		player.linear_velocity.z
	).length()

	if horizontal_speed < 0.05:
		return

	# Скорость по окружности приблизительно равна omega * radius.
	# Поэтому рост скорости персонажа ускоряет орбиту.
	var angular_speed: float = minf(
		horizontal_speed / _current_radius,
		maximum_orbit_speed
	)

	var direction_sign: float = 1.0
	if player.body_state == Player.BodyState.LYING:
		return

	if left_orbit_axis != null:
		left_orbit_axis.rotate_x(-angular_speed * direction_sign * delta)

	if right_orbit_axis != null:
		right_orbit_axis.rotate_x(-angular_speed * direction_sign * delta)




func _get_target_radius() -> float:
	if player.body_state == Player.BodyState.LYING:
		return standing_radius

	if player.body_state == Player.BodyState.CROUCHING:
		return crouching_radius

	var horizontal_speed: float = Vector2(
		player.linear_velocity.x,
		player.linear_velocity.z
	).length()

	if horizontal_speed < 0.1:
		return standing_radius

	if Input.is_action_pressed(&"sprint"):
		return running_radius

	return walking_radius


func _get_orbit_speed() -> float:
	if player.body_state == Player.BodyState.LYING:
		return 0.0

	if player.body_state == Player.BodyState.CROUCHING:
		return crouch_orbit_speed

	if Input.is_action_pressed(&"sprint"):
		return run_orbit_speed

	return walk_orbit_speed


func _set_orbit_radius(marker: Node3D, radius: float) -> void:
	if marker == null:
		return

	var marker_position: Vector3 = marker.position
	marker_position.z = -absf(radius)
	marker.position = marker_position


func _rotate_orbit(axis: Node3D, angular_speed: float, delta: float) -> void:
	if axis == null:
		return

	axis.rotate_x(-angular_speed * delta)

func _update_foot(
	orbit_marker: Node3D,
	ground_ray: RayCast3D,
	ik_target: Node3D,
	ray_base_x: float,
	foot_index: int,
	delta: float
) -> void:
	if orbit_marker == null:
		return
	if ground_ray == null:
		return
	if ik_target == null:
		return

	# Маркер и луч приводятся к координатам общего контроллера.
	var marker_in_controller: Vector3 = to_local(
		orbit_marker.global_position
	)

	var ray_local_position: Vector3 = ground_ray.position
	ray_local_position.x = ray_base_x
	ray_local_position.y = ray_start_height
	ray_local_position.z = marker_in_controller.z
	ground_ray.position = ray_local_position
	ground_ray.target_position = Vector3.DOWN * ray_length
	ground_ray.force_raycast_update()

	var target_world: Vector3 = orbit_marker.global_position
	var has_ground: bool = ground_ray.is_colliding()
	var contact_world: Vector3 = Vector3.ZERO

	if has_ground:
		contact_world = ground_ray.get_collision_point()

		# По Y цель никогда не оказывается ниже найденной поверхности.
		target_world.y = maxf(
			target_world.y,
			contact_world.y + foot_surface_offset
		)

	var weight: float = 1.0 - exp(-12.0 * delta)
	var smoothed_world: Vector3 = ik_target.global_position.lerp(
		target_world,
		weight
	)

	# Не сглаживаем вертикальное ограничение: иначе цель временно
	# может оказаться ниже точки столкновения.
	if has_ground:
		smoothed_world.y = maxf(
			smoothed_world.y,
			contact_world.y + foot_surface_offset
		)

	ik_target.global_position = smoothed_world

	var was_grounded: bool = false
	if foot_index == 0:
		was_grounded = _left_was_at_ground
		_left_was_at_ground = has_ground
	else:
		was_grounded = _right_was_at_ground
		_right_was_at_ground = has_ground

	if has_ground and not was_grounded:
		_emit_step(foot_index, contact_world)


func _configure_ray(ray: RayCast3D) -> void:
	ray.target_position = Vector3.DOWN * ray_length
	ray.add_exception(player)
	ray.enabled = true


func _emit_step(foot_index: int, world_position: Vector3) -> void:
	foot_contact.emit(foot_index, world_position)

	if step_audio != null:
		step_audio.global_position = world_position
		step_audio.play()
