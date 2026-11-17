class_name PivotRotationHandAction
extends HandAction3D


@export var pivot: Marker3D
@export var local_rotation_axis: Vector3 = Vector3.RIGHT
@export var mouse_sensitivity: float = 0.01
@export var minimum_angle_degrees: float = -45.0
@export var maximum_angle_degrees: float = 45.0
@export var invert_mouse_y: bool = false

var initial_pivot_basis: Basis = Basis.IDENTITY
var current_angle_radians: float = 0.0

func _ready() -> void:
	if pivot == null:
		pivot = get_node_or_null("Pivot") as Marker3D

	if pivot == null:
		push_warning(
			"PivotRotationHandAction: не найден дочерний узел Pivot"
		)
		return

	initial_pivot_basis = pivot.transform.basis
	current_angle_radians = 0.0

func begin(
	target_hand: HandController,
	target_handle: InteractionHandle3D
) -> bool:
	if pivot == null:
		return false

	return super.begin(target_hand, target_handle)


func on_mouse_motion(relative: Vector2) -> void:
	if not is_active or pivot == null:
		return

	var direction: float = -1.0
	if invert_mouse_y:
		direction = 1.0

	current_angle_radians += (
		relative.y
		* mouse_sensitivity
		* direction
	)

	var minimum_angle_radians: float = deg_to_rad(
		minimum_angle_degrees
	)
	var maximum_angle_radians: float = deg_to_rad(
		maximum_angle_degrees
	)

	current_angle_radians = clampf(
		current_angle_radians,
		minimum_angle_radians,
		maximum_angle_radians
	)

	var axis: Vector3 = local_rotation_axis.normalized()
	if axis.is_zero_approx():
		push_warning(
			"PivotRotationHandAction: local_rotation_axis не может быть нулевым"
		)
		return

	var rotation_basis: Basis = Basis(axis, current_angle_radians)
	pivot.transform.basis = initial_pivot_basis * rotation_basis


func end() -> void:
	super.end()
