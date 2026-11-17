class_name HandAction3D
extends Node


var hand: HandController = null
var interaction_handle: InteractionHandle3D = null
var previous_follows_camera: bool = false
var is_active: bool = false


func begin(
	target_hand: HandController,
	target_handle: InteractionHandle3D
) -> bool:
	if target_hand == null or target_handle == null:
		return false

	if target_handle.grip_marker == null:
		return false

	hand = target_hand
	interaction_handle = target_handle
	previous_follows_camera = hand.follows_camera
	is_active = true

	hand.follows_camera = false
	hand.global_transform = interaction_handle.grip_marker.global_transform
	return true


func on_mouse_motion(_relative: Vector2) -> void:
	pass


func update_hand_pose() -> void:
	if not is_active:
		return

	if not is_instance_valid(hand):
		return

	if not is_instance_valid(interaction_handle):
		return

	if interaction_handle.grip_marker == null:
		return

	hand.global_transform = interaction_handle.grip_marker.global_transform


func end() -> void:
	if not is_active:
		return

	if is_instance_valid(hand):
		hand.follows_camera = previous_follows_camera

	hand = null
	interaction_handle = null
	is_active = false
