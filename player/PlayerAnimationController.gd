class_name PlayerAnimationController
extends Node


@export var player: Player
@export var animation_tree: AnimationTree


@export_category("Blend Spaces")

@export var locomotion_blend_path: StringName = (
	&"parameters/Locomotion/blend_position"
)

@export var crouch_locomotion_blend_path: StringName = (
	&"parameters/CrouchLocomotion/blend_position"
)

@export var prone_locomotion_blend_path: StringName = (
	&"parameters/ProneLocomotion/blend_position"
)


@export_category("Animation")

@export var movement_dead_zone: float = 0.05
@export var state_change_fade: float = 0.15


var state_machine: AnimationNodeStateMachinePlayback


func _ready() -> void:
	if player == null:
		player = get_parent() as Player

	if player == null:
		push_error("PlayerAnimationController: Player не найден")
		return

	if animation_tree == null:
		push_error("PlayerAnimationController: AnimationTree не назначен")
		return

	animation_tree.active = true

	state_machine = animation_tree.get(&"parameters/playback")

	if state_machine == null:
		push_error(
			"PlayerAnimationController: State Machine не найден"
		)
		return

	player.jump_started.connect(_on_jump_started)
	player.landed.connect(_on_landed)

	state_machine.start(&"Locomotion")


func _process(_delta: float) -> void:
	if player == null:
		return

	if animation_tree == null:
		return

	if state_machine == null:
		return

	_update_locomotion_blends()
	_update_ground_locomotion_state()
	_update_air_state()


func _update_locomotion_blends() -> void:
	var horizontal_velocity := Vector3(
		player.velocity.x,
		0.0,
		player.velocity.z
	)

	var current_speed := horizontal_velocity.length()

	var local_velocity := (
		player.global_transform.basis.inverse()
		* horizontal_velocity
	)

	var animation_position := Vector2.ZERO

	if current_speed > movement_dead_zone:
		var local_direction := Vector2(
			local_velocity.x,
			-local_velocity.z
		).normalized()

		var speed_reference := _get_speed_reference()

		var speed_blend := 0.0

		if speed_reference > 0.0:
			speed_blend = current_speed / speed_reference

		speed_blend = clamp(speed_blend, 0.0, 1.0)

		animation_position = local_direction * speed_blend

	_set_current_blend_position(animation_position)


func _get_speed_reference() -> float:
	match player.body_state:
		Player.BodyState.STANDING:
			return player.sprint_speed

		Player.BodyState.CROUCHING:
			return player.crouch_speed

		Player.BodyState.LYING:
			return player.prone_speed

	return player.walk_speed


func _set_current_blend_position(
	animation_position: Vector2
) -> void:
	match player.body_state:
		Player.BodyState.STANDING:
			animation_tree.set(
				locomotion_blend_path,
				animation_position
			)

		Player.BodyState.CROUCHING:
			animation_tree.set(
				crouch_locomotion_blend_path,
				animation_position
			)

		Player.BodyState.LYING:
			animation_tree.set(
				prone_locomotion_blend_path,
				animation_position
			)


func _update_ground_locomotion_state() -> void:
	if not player.is_on_floor():
		return

	var target_state := _get_locomotion_state_name()
	var current_state := state_machine.get_current_node()

	if current_state == target_state:
		return

	# Не прерываем анимацию приземления.
	if current_state == &"Land":
		return

	# Не прерываем старт прыжка, если он ещё проигрывается.
	if current_state == &"JumpStart":
		return

	state_machine.travel(target_state)


func _get_locomotion_state_name() -> StringName:
	match player.body_state:
		Player.BodyState.STANDING:
			return &"Locomotion"

		Player.BodyState.CROUCHING:
			return &"CrouchLocomotion"

		Player.BodyState.LYING:
			return &"ProneLocomotion"

	return &"Locomotion"


func _update_air_state() -> void:
	if player.is_on_floor():
		return

	var current_state := state_machine.get_current_node()

	# Пока персонаж движется вверх, сохраняем JumpStart.
	if player.velocity.y > 0.0:
		return

	if current_state != &"Fall":
		state_machine.travel(&"Fall")


func _on_jump_started() -> void:
	state_machine.travel(&"JumpStart")


func _on_landed() -> void:
	state_machine.travel(&"Land")
