class_name LocalZHandAction
extends HandAction3D


@export var mouse_sensitivity: float = 0.005
@export var min_local_z: float = -0.5
@export var max_local_z: float = 0.5


func on_mouse_motion(relative: Vector2) -> void:
	if not is_active:
		return

	if not is_instance_valid(interaction_handle):
		return

	var marker: Marker3D = interaction_handle.grip_marker
	if marker == null:
		return

	marker.position.z = clampf(
		marker.position.z - relative.y * mouse_sensitivity,
		min_local_z,
		max_local_z
	)
