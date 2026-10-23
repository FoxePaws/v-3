class_name HandController
extends Node3D

@export_category("Position Inertia")
@export var position_spring_strength: float = 55.0
@export var position_spring_damping: float = 14.0

var hand_position_velocity: Vector3 = Vector3.ZERO


@export_category("Hand")
@export var is_right_hand: bool = true
@export var held_item_point: Marker3D
@export var heavy_support_point: Marker3D
@export var hand_collision_cast: ShapeCast3D

@export_category("Distance")
@export var hand_distance: float = 0.3
@export var min_hand_distance: float = 0.1
@export var max_hand_distance: float = 0.4
@export var wheel_step: float = 0.1
@export var distance_smoothing: float = 3.0

@export_category("Mouse")
@export var hand_rotation_sensitivity: float = 0.003
@export var hand_move_sensitivity: float = 0.003
@export var hand_move_max_offset: float = 0.35

@export_category("Camera Offset")
@export var camera_side_offset: float = 0.25
@export var camera_vertical_offset: float = 0.0

@export_category("Collision")
@export var collision_margin: float = 0.12

var follows_camera: bool = false

var player: Player
var held_item: ItemInstance
var supporting_heavy_item: ItemInstance

var is_active: bool = false
var target_hand_distance: float = 1.5
var hand_rotation_mode: bool = false
var hand_move_mode: bool = false

var hand_move_offset: Vector2 = Vector2.ZERO
var camera_rotation_offset: Quaternion = Quaternion.IDENTITY

var base_local_transform: Transform3D = Transform3D.IDENTITY
var saved_local_transform: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	base_local_transform = transform
	saved_local_transform = transform
	target_hand_distance = hand_distance

	if held_item_point == null:
		held_item_point = get_node_or_null("HeldItemPoint") as Marker3D

	if heavy_support_point == null:
		heavy_support_point = get_node_or_null("HeavySupportPoint") as Marker3D

	if hand_collision_cast == null:
		hand_collision_cast = get_node_or_null("HandCollisionCast") as ShapeCast3D

func _physics_process(delta: float) -> void:
	if follows_camera and supporting_heavy_item == null:
		hand_distance = move_toward(
			hand_distance,
			target_hand_distance,
			distance_smoothing * delta
		)
		_update_active_transform(delta)

	if held_item != null:
		_attach_item_to_hand(held_item)



func set_active(value: bool, reset_when_disabled: bool) -> void:
	if is_active == value:
		return

	if value:
		saved_local_transform = transform
		is_active = true
		follows_camera = true
		hand_rotation_mode = false
		hand_move_mode = false
		# Не сбрасываем hand_move_offset:
		# сохраняем положение руки относительно камеры.
		return

	is_active = false
	hand_rotation_mode = false
	hand_move_mode = false

	if reset_when_disabled:
		follows_camera = false
		hand_move_offset = Vector2.ZERO
		camera_rotation_offset = Quaternion.IDENTITY
		transform = base_local_transform
	else:
		follows_camera = true


func set_rotation_mode(value: bool) -> void:
	hand_rotation_mode = value


func set_move_mode(value: bool) -> void:
	hand_move_mode = value


func adjust_distance(direction: float) -> void:
	target_hand_distance = clampf(
		target_hand_distance + direction * wheel_step,
		min_hand_distance,
		max_hand_distance
	)


func rotate_by_mouse(relative: Vector2) -> void:
	if not is_active or not hand_rotation_mode or player == null:
		return

	var yaw_delta: Quaternion = Quaternion(
		Vector3.UP,
		-relative.x * hand_rotation_sensitivity
	)
	var pitch_delta: Quaternion = Quaternion(
		Vector3.RIGHT,
		-relative.y * hand_rotation_sensitivity
	)

	# Вращаем вокруг осей камеры.
	camera_rotation_offset = (
		pitch_delta
		* yaw_delta
		* camera_rotation_offset
	)


func move_by_mouse(relative: Vector2) -> void:
	if not is_active or not hand_move_mode:
		return

	hand_move_offset.x = clampf(
		hand_move_offset.x + relative.x * hand_move_sensitivity,
		-hand_move_max_offset,
		hand_move_max_offset
	)
	hand_move_offset.y = clampf(
		hand_move_offset.y - relative.y * hand_move_sensitivity,
		-hand_move_max_offset,
		hand_move_max_offset
	)


func reset_hand_position() -> void:
	hand_move_offset = Vector2.ZERO
	camera_rotation_offset = Quaternion.IDENTITY
	transform = base_local_transform

func _update_active_transform(delta: float) -> void:
	if player == null:
		return

	var camera: Camera3D = player.camera
	var camera_basis: Basis = camera.global_basis
	var distance: float = _get_safe_distance()

	var target_position: Vector3 = (
		camera.global_position
		- camera_basis.z * distance
		+ camera_basis.x * hand_move_offset.x
		+ camera_basis.y * hand_move_offset.y
	)

	var side_sign: float = 1.0 if is_right_hand else -1.0
	target_position += camera_basis.x * camera_side_offset * side_sign
	target_position += camera_basis.y * camera_vertical_offset

	# Сглаживаем только позицию, сохраняя инерцию при перемещении и прыжках.
	var spring_force: Vector3 = (
		(target_position - global_position) * position_spring_strength
	)
	var damping_force: Vector3 = hand_position_velocity * position_spring_damping

	hand_position_velocity += (spring_force - damping_force) * delta
	global_position += hand_position_velocity * delta

	# Поворот сразу следует за камерой; инерция на него не влияет.
	var forward_pose: Quaternion = Quaternion(Vector3.RIGHT, PI / 2.0)
	global_basis = (
		camera_basis
		* Basis(camera_rotation_offset)
		* Basis(forward_pose)
	)


func _get_safe_distance() -> float:
	var distance: float = clampf(
		hand_distance,
		min_hand_distance,
		max_hand_distance
	)

	if hand_collision_cast == null:
		return distance

	hand_collision_cast.target_position = Vector3(0.0, 0.0, -distance)
	hand_collision_cast.force_shapecast_update()

	if not hand_collision_cast.is_colliding():
		return distance

	var safe_fraction: float = clampf(
		hand_collision_cast.get_closest_collision_safe_fraction(),
		0.0,
		1.0
	)

	return maxf(
		min_hand_distance,
		distance * safe_fraction - collision_margin
	)


func _world_transform_to_parent_local(world_transform: Transform3D) -> Transform3D:
	var parent_node: Node3D = get_parent() as Node3D
	if parent_node == null:
		return world_transform

	return parent_node.global_transform.affine_inverse() * world_transform


func _attach_item_to_hand(item: ItemInstance) -> void:
	if held_item_point == null:
		return

	var grip_point: Marker3D = item.primary_grip_point
	if not is_right_hand:
		grip_point = item.secondary_grip_point

	if grip_point == null:
		item.global_transform = held_item_point.global_transform
		return

	item.global_transform = (
		held_item_point.global_transform
		* grip_point.transform.affine_inverse()
	)


func try_grab() -> void:
	if not is_active or held_item != null:
		return

	var camera: Camera3D = player.camera
	var ray_from: Vector3 = camera.global_position
	var ray_to: Vector3 = ray_from - camera.global_basis.z * 3.0

	var query: PhysicsRayQueryParameters3D = (
		PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	)
	query.collision_mask = 8
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [player]

	var result: Dictionary = (
		get_world_3d().direct_space_state.intersect_ray(query)
	)
	if result.is_empty():
		return

	var collider: Node = result.get("collider") as Node
	while collider != null and not collider is ItemInstance:
		collider = collider.get_parent()

	if not collider is ItemInstance:
		return

	var item: ItemInstance = collider as ItemInstance
	if not item.can_be_grabbed():
		return

	held_item = item
	item.current_hand = self
	item.disable_collision()

	if held_item_point != null:
		item.reparent(held_item_point, false)
		_attach_item_to_hand(item)

	item.on_grab(self)


func drop_item() -> void:
	if held_item == null:
		return

	var item: ItemInstance = held_item
	held_item = null

	item.reparent(get_tree().current_scene, true)
	item.enable_collision()
	item.on_drop()


func use_primary_action() -> void:
	if held_item != null:
		held_item.on_primary_action()


func use_secondary_action() -> void:
	if held_item != null:
		held_item.on_secondary_action()
