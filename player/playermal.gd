class_name Player
extends CharacterBody3D


signal jump_started
signal landed


enum BodyState {
	STANDING,
	CROUCHING,
	LYING
}
@onready var inventory_ui: InventoryUI = $InventoryUI

@export_category("Movement")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
@export var prone_speed: float = 1.0
@export var slow_walk_multiplier: float = 0.55
@export var jump_velocity: float = 5.0
@export var gravity: float = 9.4
@export var ground_acceleration: float = 35.0
@export var ground_deceleration: float = 45.0


@export_category("Air Movement")
@export var air_control_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.5


@export_category("Body Rotation")
@export var camera_dead_zone: float = 35.0
@export var body_turn_speed: float = 5.0
@export var body_turn_acceleration: float = 12.0


@export_category("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch: float = deg_to_rad(-85.0)
@export var max_pitch: float = deg_to_rad(85.0)


@export_category("Vertical Camera Dead Zone")
@export_group("Standing / Crouching")
@export_range(-89.0, 0.0, 0.1, "degrees")
var vertical_dead_zone_lower: float = -25.0
@export_range(0.0, 89.0, 0.1, "degrees")
var vertical_dead_zone_upper: float = 25.0

@export_group("Lying")
@export_range(-89.0, 0.0, 0.1, "degrees")
var lying_vertical_dead_zone_lower: float = -10.0
@export_range(0.0, 89.0, 0.1, "degrees")
var lying_vertical_dead_zone_upper: float = 45.0

@export var vertical_body_follow_speed: float = 5.0
@export var min_body_pitch: float = deg_to_rad(-35.0)
@export var max_body_pitch: float = deg_to_rad(35.0)


@export_category("Body Pose")
@export var crouch_root_offset: float = -0.35
@export var crouch_root_pitch: float = -8.0
@export var lying_root_offset: float = -0.75
@export var lying_root_pitch: float = -90.0
@export var body_pose_speed: float = 10.0


@export_category("Hand Support")
@export var heavy_support_smoothing: float = 15.0


var body_state: BodyState = BodyState.STANDING
var view_pitch: float = 0.0

var active_hand: HandController = null
var hand_rotation_mode: bool = false
var hand_move_mode: bool = false


@onready var visual_root: Node3D = $Root
@onready var camera_pivot: Node3D = $Root/CameraPivot
@onready var camera: Camera3D = $Root/CameraPivot/Camera3D

@onready var right_hand: HandController = (
	$Root/R_Hand_Base/RightHand
)
@onready var left_hand: HandController = (
	$Root/L_Hand_Base/LeftHand
)

@onready var standing_shape: CollisionShape3D = $StandingShape
@onready var crouching_shape: CollisionShape3D = $CrouchingShape
@onready var lying_shape: CollisionShape3D = $LyingShape
@onready var ceiling_check: ShapeCast3D = $CeilingCheck

@onready var equipment: EquipmentComponent = $EquipmentComponent

var base_walk_speed: float
var base_sprint_speed: float
var protection: float = 0.0
var warmth: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	inventory_ui.player = self
	right_hand.player = self
	right_hand.is_right_hand = true

	left_hand.player = self
	left_hand.is_right_hand = false

	# Правая рука активна при старте.
	right_hand.set_active(true, false)
	left_hand.set_active(false, false)
	active_hand = right_hand

	base_walk_speed = walk_speed
	base_sprint_speed = sprint_speed
	equipment.player = self

	# Остальной код вашего _ready() оставьте.
	# После загрузки визуальных узлов заполните clothing_visuals.
	recalculate_equipment_stats()
	_apply_body_collision_shapes()


func recalculate_equipment_stats() -> void:
	walk_speed = base_walk_speed
	sprint_speed = base_sprint_speed
	protection = 0.0
	warmth = 0.0

	if equipment == null:
		return

	for item in equipment.slots.values():
		if item == null or item.data == null:
			continue

		walk_speed += item.data.walk_speed_modifier
		sprint_speed += item.data.sprint_speed_modifier
		protection += item.data.protection
		warmth += item.data.warmth

func _physics_process(delta: float) -> void:
	_handle_body_state()
	_update_body_pose(delta)

	_handle_jump_and_gravity(delta)
	_handle_movement()

	var is_moving: bool = has_movement_input()
	_update_body_rotation(delta, is_moving)
	_update_vertical_rotation(delta)

	var was_on_floor: bool = is_on_floor()
	move_and_slide()
	var now_on_floor: bool = is_on_floor()

	if not was_on_floor and now_on_floor:
		landed.emit()


func _process(delta: float) -> void:
	_update_heavy_item_support(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		inventory_ui.toggle_player_ui()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact"):
		if not inventory_ui.is_ui_open():
			_try_open_container()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("drop_item"):
		if active_hand != null:
			active_hand.drop_item()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("transfer_item"):
		transfer_item()
		get_viewport().set_input_as_handled()
		return


	if inventory_ui.is_ui_open():
		if event.is_action_pressed("ui_cancel"):
			inventory_ui.close_player_ui()
			inventory_ui.close_all_container_windows()
			get_viewport().set_input_as_handled()
		return
	
	
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("ui_cancel"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	# Переключение активной руки.
	if event.is_action_pressed("right_hand_active"):
		_switch_active_hand(right_hand)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("left_hand_active"):
		_switch_active_hand(left_hand)
		get_viewport().set_input_as_handled()
		return

	# Сброс активной руки в её исходную позицию относительно базы.
	if event.is_action_pressed("reset_hand_position"):
		if active_hand != null:
			active_hand.reset_hand_position()
		get_viewport().set_input_as_handled()
		return

	# Режим перемещения руки по плоскости камеры.
	if event.is_action_pressed("move_hand"):
		if active_hand != null and not hand_rotation_mode:
			hand_move_mode = true
			active_hand.set_move_mode(true)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released("move_hand"):
		hand_move_mode = false
		if active_hand != null:
			active_hand.set_move_mode(false)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = (
			event as InputEventMouseButton
		)

		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if active_hand != null:
				hand_rotation_mode = mouse_event.pressed
				active_hand.set_rotation_mode(hand_rotation_mode)

				# Вращение и перемещение руки не работают одновременно.
				if hand_rotation_mode:
					hand_move_mode = false
					active_hand.set_move_mode(false)
				elif Input.is_action_pressed("move_hand"):
					hand_move_mode = true
					active_hand.set_move_mode(true)

			get_viewport().set_input_as_handled()
			return

		# Дистанция активной руки регулируется колёсиком.
		if active_hand != null and mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				active_hand.adjust_distance(1.0)
				get_viewport().set_input_as_handled()
				return

			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				active_hand.adjust_distance(-1.0)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = (
			event as InputEventMouseMotion
		)

		if active_hand != null and hand_rotation_mode:
			active_hand.rotate_by_mouse(motion.relative)
			get_viewport().set_input_as_handled()
			return

		if active_hand != null and hand_move_mode:
			active_hand.move_by_mouse(motion.relative)
			get_viewport().set_input_as_handled()
			return

		if (
			active_hand != null
			and active_hand.held_item is Sponge
		):
			var sponge: Sponge = active_hand.held_item as Sponge

			if sponge.attached:
				sponge.on_mouse_motion(motion.relative)
				get_viewport().set_input_as_handled()
				return

		_rotate_camera_by_mouse(motion.relative)
		return

	# Предметные действия выполняет только активная рука.
	if event.is_action_pressed("grab_item"):
		if active_hand != null:
			active_hand.try_grab()
		get_viewport().set_input_as_handled()
		return


	if event.is_action_pressed("throw_item"):
		_throw_active_hand_item()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("primary_action"):
		if active_hand != null:
			active_hand.use_primary_action()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released("primary_action"):
		if active_hand != null and active_hand.held_item != null:
			active_hand.held_item.on_primary_action_released()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("secondary_action"):
		if active_hand != null:
			active_hand.use_secondary_action()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()


func _switch_active_hand(hand: HandController) -> void:
	if hand == null:
		return

	# Повторное нажатие клавиши активной руки выключает её
	# и сбрасывает её в исходную позу относительно базы.
	if active_hand == hand:
		hand.set_active(false, true)
		active_hand = null
		hand_rotation_mode = false
		hand_move_mode = false
		return

	# Предыдущая активная рука перестаёт следовать за камерой,
	# сохраняя своё мировое положение относительно игрока.
	if active_hand != null:
		active_hand.set_active(false, false)

	hand_rotation_mode = false
	hand_move_mode = false

	# Если другая кнопка нажата, назначаем выбранную руку активной.
	hand.set_active(true, false)
	active_hand = hand

func _throw_active_hand_item() -> void:
	if active_hand == null or active_hand.held_item == null:
		return

	var item: ItemInstance = active_hand.held_item
	active_hand.held_item = null

	item.reparent(get_tree().current_scene, true)

	var throw_force: float = 8.0
	if item.data != null:
		throw_force = item.data.throw_force

	item.enable_collision()
	item.on_throw(-camera.global_basis.z, throw_force)


func transfer_item() -> void:
	# Передача возможна в обе стороны, если во второй руке свободно.
	if right_hand.held_item != null and left_hand.held_item == null:
		if right_hand.held_item.is_heavy():
			return
		_move_item_between_hands(right_hand, left_hand)
		return

	if left_hand.held_item != null and right_hand.held_item == null:
		if left_hand.held_item.is_heavy():
			return
		_move_item_between_hands(left_hand, right_hand)
		return

	# Если обе руки заняты, меняем предметы местами,
	# но тяжёлые предметы не переносим.
	if right_hand.held_item != null and left_hand.held_item != null:
		if right_hand.held_item.is_heavy():
			return
		if left_hand.held_item.is_heavy():
			return

		_swap_hand_items()


func _move_item_between_hands(
	from_hand: HandController,
	to_hand: HandController
) -> void:
	if from_hand == null or to_hand == null:
		return
	if from_hand.held_item == null or to_hand.held_item != null:
		return
	if to_hand.held_item_point == null:
		return

	var item: ItemInstance = from_hand.held_item
	from_hand.held_item = null
	to_hand.held_item = item

	item.reparent(to_hand.held_item_point, false)
	_attach_item_to_hand(item, to_hand)
	item.current_hand = to_hand


func _swap_hand_items() -> void:
	var right_item: ItemInstance = right_hand.held_item
	var left_item: ItemInstance = left_hand.held_item

	if right_item == null or left_item == null:
		return
	if right_hand.held_item_point == null or left_hand.held_item_point == null:
		return

	right_hand.held_item = left_item
	left_hand.held_item = right_item

	left_item.reparent(right_hand.held_item_point, false)
	_attach_item_to_hand(left_item, right_hand)
	left_item.current_hand = right_hand

	right_item.reparent(left_hand.held_item_point, false)
	_attach_item_to_hand(right_item, left_hand)
	right_item.current_hand = left_hand


func _attach_item_to_hand(
	item: ItemInstance,
	hand: HandController
) -> void:
	if item == null or hand == null or hand.held_item_point == null:
		return

	var grip_point: Marker3D = item.primary_grip_point
	if not hand.is_right_hand:
		grip_point = item.secondary_grip_point

	if grip_point == null:
		item.global_transform = hand.held_item_point.global_transform
		return

	item.global_transform = (
		hand.held_item_point.global_transform
		* grip_point.transform.affine_inverse()
	)


func _update_heavy_item_support(delta: float) -> void:
	_update_support_for_hand(right_hand, left_hand, delta)
	_update_support_for_hand(left_hand, right_hand, delta)


func _update_support_for_hand(
	holding_hand: HandController,
	support_hand: HandController,
	_delta: float
) -> void:
	# Активная рука свободна для управления и не поддерживает предмет.
	if support_hand.is_active:
		_clear_hand_support(support_hand)
		return

	if holding_hand.held_item == null:
		_clear_hand_support(support_hand)
		return

	var item: ItemInstance = holding_hand.held_item

	if not item.is_heavy() or item.secondary_grip_point == null:
		_clear_hand_support(support_hand)
		return

	# Если в руке лежит отдельный предмет, поддержка невозможна.
	if support_hand.held_item != null:
		_clear_hand_support(support_hand)
		return

	if support_hand.held_item_point == null:
		return

	support_hand.supporting_heavy_item = item

	var target_grip: Transform3D = (
		item.global_transform
		* item.secondary_grip_point.transform
	)

	var target_hand_transform: Transform3D = (
		target_grip
		* support_hand.held_item_point.transform.affine_inverse()
	)

	support_hand.global_transform = target_hand_transform

func _clear_hand_support(hand: HandController) -> void:
	if hand.supporting_heavy_item == null:
		return

	hand.supporting_heavy_item = null

	# Возвращаем неактивную поддерживающую руку к базе.
	if not hand.is_active:
		hand.transform = hand.base_local_transform


func _handle_body_state() -> void:
	if Input.is_action_just_pressed("prone"):
		if body_state == BodyState.LYING:
			_try_stand_up()
		else:
			_set_body_state(BodyState.LYING)
		return

	if body_state == BodyState.LYING:
		return

	if Input.is_action_pressed("crouch"):
		if body_state != BodyState.CROUCHING:
			_set_body_state(BodyState.CROUCHING)
		return

	if body_state == BodyState.CROUCHING:
		_try_stand_up()


func _set_body_state(new_state: BodyState) -> void:
	if body_state == new_state:
		return

	body_state = new_state
	_apply_body_collision_shapes()


func _apply_body_collision_shapes() -> void:
	standing_shape.set_deferred(
		"disabled",
		body_state != BodyState.STANDING
	)
	crouching_shape.set_deferred(
		"disabled",
		body_state != BodyState.CROUCHING
	)
	lying_shape.set_deferred(
		"disabled",
		body_state != BodyState.LYING
	)


func _try_stand_up() -> void:
	if body_state == BodyState.STANDING:
		return
	if _has_ceiling_above():
		return

	_set_body_state(BodyState.STANDING)


func _has_ceiling_above() -> bool:
	ceiling_check.force_shapecast_update()
	return ceiling_check.is_colliding()


func _update_body_pose(delta: float) -> void:
	var target_y: float = 0.0
	var target_pitch: float = 0.0

	match body_state:
		BodyState.STANDING:
			target_y = 0.0
			target_pitch = 0.0
		BodyState.CROUCHING:
			target_y = crouch_root_offset
			target_pitch = deg_to_rad(crouch_root_pitch)
		BodyState.LYING:
			target_y = lying_root_offset
			target_pitch = deg_to_rad(lying_root_pitch)

	var interpolation: float = 1.0 - exp(-body_pose_speed * delta)

	visual_root.position.y = lerpf(
		visual_root.position.y,
		target_y,
		interpolation
	)
	visual_root.rotation.x = lerp_angle(
		visual_root.rotation.x,
		target_pitch,
		interpolation
	)


func _handle_jump_and_gravity(delta: float) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and body_state == BodyState.STANDING:
			velocity.y = jump_velocity
			jump_started.emit()
		else:
			velocity.y = -0.5
	else:
		velocity.y -= gravity * delta


func _handle_movement() -> void:
	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
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

	var current_speed: float = walk_speed

	match body_state:
		BodyState.STANDING:
			if Input.is_action_pressed("sprint"):
				current_speed = sprint_speed
		BodyState.CROUCHING:
			current_speed = crouch_speed
		BodyState.LYING:
			current_speed = prone_speed

	if Input.is_action_pressed("slow_walk"):
		current_speed *= slow_walk_multiplier

	var delta: float = get_physics_process_delta_time()

	if not is_on_floor():
		if not air_control_enabled:
			return

		var air_target: Vector3 = move_direction * current_speed
		var air_acceleration: float = ground_acceleration * air_control

		velocity.x = move_toward(
			velocity.x,
			air_target.x,
			air_acceleration * delta
		)
		velocity.z = move_toward(
			velocity.z,
			air_target.z,
			air_acceleration * delta
		)
		return

	var target_velocity: Vector3 = move_direction * current_speed
	var acceleration: float = ground_acceleration

	if move_direction.length_squared() == 0.0:
		acceleration = ground_deceleration

	velocity.x = move_toward(
		velocity.x,
		target_velocity.x,
		acceleration * delta
	)
	velocity.z = move_toward(
		velocity.z,
		target_velocity.z,
		acceleration * delta
	)


func _update_vertical_rotation(delta: float) -> void:
	var dead_zone: Vector2 = _get_vertical_dead_zone()
	var desired_body_pitch: float = 0.0

	if view_pitch < dead_zone.x:
		desired_body_pitch = view_pitch - dead_zone.x
	elif view_pitch > dead_zone.y:
		desired_body_pitch = view_pitch - dead_zone.y

	desired_body_pitch = clampf(
		desired_body_pitch,
		min_body_pitch,
		max_body_pitch
	)

	camera_pivot.rotation.x = move_toward(
		camera_pivot.rotation.x,
		desired_body_pitch,
		vertical_body_follow_speed * delta
	)

	var yaw: float = rotation.y + camera_pivot.rotation.y
	var desired_camera_basis: Basis = (
		Basis(Vector3.UP, yaw)
		* Basis(Vector3.RIGHT, view_pitch)
	)
	camera.global_basis = desired_camera_basis


func _rotate_camera_by_mouse(relative: Vector2) -> void:
	camera_pivot.rotation.y -= relative.x * mouse_sensitivity
	view_pitch -= relative.y * mouse_sensitivity
	view_pitch = clampf(view_pitch, min_pitch, max_pitch)


func _update_body_rotation(delta: float, is_moving: bool) -> void:
	var camera_offset: float = wrapf(
		camera_pivot.rotation.y,
		-PI,
		PI
	)

	var dead_zone: float = deg_to_rad(camera_dead_zone)
	if is_moving:
		dead_zone = 0.0

	if absf(camera_offset) <= dead_zone:
		return

	var rotation_needed: float = camera_offset
	if camera_offset > 0.0:
		rotation_needed -= dead_zone
	else:
		rotation_needed += dead_zone

	var current_turn_speed: float = (
		body_turn_speed
		+ absf(rotation_needed) * body_turn_acceleration
	)
	var rotation_step: float = current_turn_speed * delta
	var body_rotation_delta: float = clampf(
		rotation_needed,
		-rotation_step,
		rotation_step
	)

	rotation.y += body_rotation_delta
	camera_pivot.rotation.y -= body_rotation_delta
	camera_pivot.rotation.y = wrapf(camera_pivot.rotation.y, -PI, PI)


func has_movement_input() -> bool:
	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	return input_vector.length_squared() > 0.0


func _get_vertical_dead_zone() -> Vector2:
	var lower_limit: float = vertical_dead_zone_lower
	var upper_limit: float = vertical_dead_zone_upper

	if body_state == BodyState.LYING:
		lower_limit = lying_vertical_dead_zone_lower
		upper_limit = lying_vertical_dead_zone_upper

	return Vector2(
		deg_to_rad(lower_limit),
		deg_to_rad(upper_limit)
	)

func _try_open_container() -> void:
	var ray_from: Vector3 = camera.global_position
	var ray_to: Vector3 = ray_from - camera.global_basis.z * 3.0

	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.exclude = [self]
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var node := result.get("collider") as Node
	while node != null:
		var container := node.get_node_or_null("ItemContainer") as ItemContainer
		if container != null:
			inventory_ui.open_container(container)
			return
		node = node.get_parent()
