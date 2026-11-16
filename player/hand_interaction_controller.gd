class_name HandInteractionController
extends Node


@export_flags_3d_physics var interaction_collision_mask: int = 1
@export var interaction_distance: float = 3.0

var player: Player = null
var active_handle: InteractionHandle3D = null
var active_action: HandAction3D = null


func _ready() -> void:
	player = get_parent() as Player

	if player == null:
		push_warning(
			"HandInteractionController должен быть дочерним узлом Player"
		)


func _physics_process(_delta: float) -> void:
	if active_action != null:
		active_action.update_hand_pose()


func handle_input(event: InputEvent) -> bool:
	if active_action != null:
		if event is InputEventMouseMotion:
			var motion: InputEventMouseMotion = (
				event as InputEventMouseMotion
			)
			active_action.on_mouse_motion(motion.relative)
			return true

		if (
			event is InputEventMouseButton
			and (event as InputEventMouseButton).button_index
				== MOUSE_BUTTON_LEFT
			and not (event as InputEventMouseButton).pressed
		):
			active_action.end()
			active_action = null
			active_handle = null
			return true

		# Пока рука занята действием, камера не получает ввод
		# от других кнопок мыши.
		if event is InputEventMouseButton:
			return true

		return false

	if (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).button_index
			== MOUSE_BUTTON_LEFT
		and (event as InputEventMouseButton).pressed
	):
		return _try_begin_interaction()

	return false

func _try_begin_interaction() -> bool:
	if player == null or player.active_hand == null:
		return false

	var handle: InteractionHandle3D = _get_handle_under_cursor()
	if handle == null:
		return false

	var action: HandAction3D = handle.action as HandAction3D
	if action == null:
		return false

	if action.begin(player.active_hand, handle):
		active_handle = handle
		active_action = action
		return true

	return false


func _get_handle_under_cursor() -> InteractionHandle3D:
	if player == null or player.camera == null:
		return null

	var ray_from: Vector3 = player.camera.global_position
	var ray_to: Vector3 = (
		ray_from
		- player.camera.global_basis.z * interaction_distance
	)

	var query: PhysicsRayQueryParameters3D = (
		PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	)
	query.collision_mask = interaction_collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [player]

	var world: World3D = player.get_world_3d()
	if world == null:
		return null

	var result: Dictionary = (
		world.direct_space_state.intersect_ray(query)
	)
	if result.is_empty():
		return null

	var node: Node = result.get("collider") as Node
	while node != null:
		if node is InteractionHandle3D:
			return node as InteractionHandle3D
		node = node.get_parent()

	return null
