class_name Sponge
extends ItemInstance


@export_category("Surface Attachment")

@export var attach_distance: float = 2.5
@export var surface_collision_mask: int = 1

# Небольшое отступание от поверхности.
@export var grip_surface_offset: float = 0.04

@export var mouse_surface_sensitivity: float = 0.004
@export var max_surface_slide_distance: float = 1.5
@export var attachment_smoothing: float = 20.0

@export var detach_if_surface_lost: bool = true


@export_category("Hand Rotation")

# Если после вращения рука направлена от поверхности,
# поменяйте это значение на true.
@export var reverse_surface_direction: bool = false

# Локальная ось PrimaryGripPoint, которая должна смотреть
# перпендикулярно поверхности.
@export var grip_forward_axis: Vector3 = Vector3.FORWARD

# Локальная вертикальная ось руки.
@export var grip_up_axis: Vector3 = Vector3.UP


@export_category("References")

@export var sponge_surface_cast: RayCast3D

var hand_was_following_camera: bool = false

var attached: bool = false

var attached_normal: Vector3 = Vector3.UP

var attached_grip_position: Vector3 = Vector3.ZERO
var target_grip_position: Vector3 = Vector3.ZERO

var attachment_start_position: Vector3 = Vector3.ZERO

var attached_camera: Camera3D = null
var attached_hand: Node3D = null

# Положение руки до прилипания.
var saved_hand_global_transform: Transform3D = (
	Transform3D.IDENTITY
)

# Положение PrimaryGripPoint относительно руки.
var grip_point_local_transform: Transform3D = (
	Transform3D.IDENTITY
)

# Поворот руки до прилипания.
var saved_hand_basis: Basis = Basis.IDENTITY

# Поворот, который добавляется к исходному повороту руки.
var surface_rotation: Quaternion = Quaternion.IDENTITY


func _ready() -> void:
	super()

	if sponge_surface_cast == null:
		sponge_surface_cast = get_node_or_null(
			"SpongeSurfaceCast"
		) as RayCast3D

	if sponge_surface_cast != null:
		sponge_surface_cast.collision_mask = (
			surface_collision_mask
		)

		sponge_surface_cast.target_position = Vector3(
			0.0,
			0.0,
			-attach_distance
		)


func _physics_process(delta: float) -> void:
	if not attached:
		return

	if attached_hand == null:
		_detach_from_surface()
		return

	if attached_camera == null:
		_detach_from_surface()
		return

	if detach_if_surface_lost:
		if not _surface_still_exists():
			_detach_from_surface()
			return

	var interpolation: float = 1.0 - exp(
		-attachment_smoothing * delta
	)

	attached_grip_position = attached_grip_position.lerp(
		target_grip_position,
		interpolation
	)

	_apply_hand_transform()


func on_primary_action() -> void:
	if attached:
		return

	_try_attach_to_surface()


func on_primary_action_released() -> void:
	if not attached:
		return

	_detach_from_surface()


func on_mouse_motion(relative: Vector2) -> void:
	if not attached:
		return

	if attached_camera == null:
		return

	_move_along_surface(relative)



func _update_surface_rotation() -> void:
	if attached_hand == null:
		return

	if attached_normal.length_squared() < 0.0001:
		surface_rotation = Quaternion.IDENTITY
		return

	var local_forward: Vector3 = (
		grip_forward_axis.normalized()
	)

	if local_forward.length_squared() < 0.0001:
		local_forward = Vector3.FORWARD

	var local_up: Vector3 = (
		grip_up_axis.normalized()
	)

	if local_up.length_squared() < 0.0001:
		local_up = Vector3.UP

	# Направление локальной оси хватки
	# в мировых координатах до прилипания.
	var current_forward: Vector3 = (
		saved_hand_basis * local_forward
	).normalized()

	var current_up: Vector3 = (
		saved_hand_basis * local_up
	).normalized()

	# Нормаль поверхности является направлением,
	# перпендикулярным поверхности.
	var target_forward: Vector3 = attached_normal

	if reverse_surface_direction:
		target_forward = -target_forward

	target_forward = target_forward.normalized()

	# Поворачиваем руку так, чтобы направление хватки
	# совпало с нормалью поверхности.
	var first_rotation: Quaternion = Quaternion(
		current_forward,
		target_forward
	)

	var rotated_up: Vector3 = (
		first_rotation * current_up
	).normalized()

	# Убираем лишний roll вокруг нормали.
	var projected_rotated_up: Vector3 = (
		rotated_up
		- target_forward
		* rotated_up.dot(target_forward)
	)

	var projected_target_up: Vector3 = (
		Vector3.UP
		- target_forward
		* Vector3.UP.dot(target_forward)
	)

	# Если мировая вертикаль почти совпала
	# с нормалью, используем вертикаль камеры.
	if projected_target_up.length_squared() < 0.0001:
		if attached_camera != null:
			var camera_up: Vector3 = (
				attached_camera.global_transform.basis.y
			)

			projected_target_up = (
				camera_up
				- target_forward
				* camera_up.dot(target_forward)
			)

	if projected_rotated_up.length_squared() < 0.0001:
		surface_rotation = first_rotation
		return

	if projected_target_up.length_squared() < 0.0001:
		surface_rotation = first_rotation
		return

	projected_rotated_up = (
		projected_rotated_up.normalized()
	)

	projected_target_up = (
		projected_target_up.normalized()
	)

	var roll_angle: float = _signed_angle_around_axis(
		projected_rotated_up,
		projected_target_up,
		target_forward
	)

	var second_rotation: Quaternion = Quaternion(
		target_forward,
		roll_angle
	)

	surface_rotation = (
		second_rotation * first_rotation
	)


func _signed_angle_around_axis(
	from: Vector3,
	to: Vector3,
	axis: Vector3
) -> float:
	var cross_value: Vector3 = from.cross(to)

	var sin_value: float = (
		cross_value.dot(axis)
	)

	var cos_value: float = clamp(
		from.dot(to),
		-1.0,
		1.0
	)

	return atan2(sin_value, cos_value)


func _move_along_surface(relative: Vector2) -> void:
	if attached_camera == null:
		return

	var camera_basis: Basis = (
		attached_camera.global_transform.basis
	)

	# Преобразуем движение мыши
	# в мировое направление.
	var movement: Vector3 = (
		camera_basis.x * relative.x
		- camera_basis.y * relative.y
	)

	movement *= mouse_surface_sensitivity

	# Убираем составляющую по нормали.
	movement = movement.slide(attached_normal)

	var desired_position: Vector3 = (
		target_grip_position + movement
	)

	var offset_from_start: Vector3 = (
		desired_position - attachment_start_position
	)

	if offset_from_start.length() > max_surface_slide_distance:
		offset_from_start = (
			offset_from_start.normalized()
			* max_surface_slide_distance
		)

		desired_position = (
			attachment_start_position
			+ offset_from_start
		)

	var surface_result: Dictionary = (
		_try_find_surface_position(desired_position)
	)

	var surface_found: bool = bool(
		surface_result.get("success", false)
	)

	if surface_found:
		var corrected_position: Vector3 = (
			Vector3(
				surface_result.get(
					"position",
					target_grip_position
				)
			)
		)

		target_grip_position = corrected_position

		# При переходе на другую грань поверхности
		# обновляем ориентацию руки.
		_update_surface_rotation()


func _try_find_surface_position(
	desired_position: Vector3
) -> Dictionary:
	var ray_start: Vector3 = (
		desired_position
		+ attached_normal * 0.3
	)

	var ray_end: Vector3 = (
		desired_position
		- attached_normal * 0.5
	)

	var query: PhysicsRayQueryParameters3D = (
		PhysicsRayQueryParameters3D.new()
	)

	query.from = ray_start
	query.to = ray_end
	query.collision_mask = surface_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [self]

	var result: Dictionary = (
		get_world_3d().direct_space_state.intersect_ray(query)
	)

	if result.is_empty():
		return {
			"success": false,
			"position": Vector3.ZERO
		}

	var new_normal: Vector3 = (
		Vector3(result["normal"]).normalized()
	)

	if new_normal.length_squared() < 0.0001:
		return {
			"success": false,
			"position": Vector3.ZERO
		}

	attached_normal = new_normal

	var corrected_position: Vector3 = (
		Vector3(result["position"])
		+ attached_normal * grip_surface_offset
	)

	return {
		"success": true,
		"position": corrected_position
	}


func _apply_hand_transform() -> void:
	if attached_hand == null:
		return

	# Преобразуем Quaternion в Basis.
	# Quaternion * Basis напрямую использовать нельзя.
	var surface_basis: Basis = (
		Basis(surface_rotation)
	)

	# Итоговый поворот:
	# добавочный поворот * исходный поворот руки.
	var final_basis: Basis = (
		surface_basis
		* saved_hand_basis
	)

	# Поскольку GripPoint находится
	# не в центре руки, учитываем его смещение.
	var grip_offset: Vector3 = (
		final_basis
		* grip_point_local_transform.origin
	)

	var final_hand_position: Vector3 = (
		attached_grip_position
		- grip_offset
	)

	attached_hand.global_transform = Transform3D(
		final_basis,
		final_hand_position
	)


func _surface_still_exists() -> bool:
	if attached_hand == null or attached_camera == null:
		return false

	if primary_grip_point == null:
		return false

	var current_grip_position: Vector3 = (
		primary_grip_point.global_position
	)

	# Если игрок отошёл от закреплённой точки дальше
	# досягаемости, прекращаем прилипание.
	var max_attachment_distance: float = attach_distance + 0.01

	if (
		attached_camera.global_position.distance_to(current_grip_position)
		> max_attachment_distance
	):
		return false

	var ray_start: Vector3 = (
		current_grip_position + attached_normal * 0.15
	)
	var ray_end: Vector3 = (
		current_grip_position - attached_normal * 0.4
	)

	var query := PhysicsRayQueryParameters3D.new()
	query.from = ray_start
	query.to = ray_end
	query.collision_mask = surface_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [self]

	var result: Dictionary = (
		get_world_3d().direct_space_state.intersect_ray(query)
	)

	return not result.is_empty()


func _try_attach_to_surface() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var hand: Node3D = current_hand as Node3D
	if hand == null or primary_grip_point == null:
		return

	var ray_start: Vector3 = camera.global_position
	var ray_direction: Vector3 = -camera.global_transform.basis.z
	var ray_end: Vector3 = ray_start + ray_direction * attach_distance

	var query := PhysicsRayQueryParameters3D.new()
	query.from = ray_start
	query.to = ray_end
	query.collision_mask = surface_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [self]

	var result: Dictionary = (
		get_world_3d().direct_space_state.intersect_ray(query)
	)

	if result.is_empty():
		return

	var hit_position: Vector3 = result["position"]
	var hit_normal: Vector3 = Vector3(result["normal"]).normalized()

	if hit_normal.length_squared() < 0.0001:
		return

	# Сохраняем позу и состояние руки до того, как перехватить управление.
	attached_camera = camera
	attached_hand = hand
	saved_hand_global_transform = hand.global_transform
	saved_hand_basis = hand.global_transform.basis
	grip_point_local_transform = (
		hand.global_transform.affine_inverse()
		* primary_grip_point.global_transform
	)
	hand_was_following_camera = hand.follows_camera

	# HandController больше не должен возвращать руку к камере.
	hand.follows_camera = false

	attached_normal = hit_normal
	attached_grip_position = (
		hit_position + attached_normal * grip_surface_offset
	)
	target_grip_position = attached_grip_position
	attachment_start_position = attached_grip_position

	_update_surface_rotation()

	attached = true
	_apply_hand_transform()


func _detach_from_surface() -> void:
	if attached_hand != null:
		# Сначала восстанавливаем позу, затем возвращаем обычное управление.
		attached_hand.global_transform = saved_hand_global_transform
		attached_hand.follows_camera = hand_was_following_camera

	attached = false
	attached_camera = null
	attached_hand = null

	attached_grip_position = Vector3.ZERO
	target_grip_position = Vector3.ZERO
	attachment_start_position = Vector3.ZERO

	surface_rotation = Quaternion.IDENTITY
