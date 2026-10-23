# item_instance.gd
class_name ItemInstance
extends RigidBody3D

@export var data: ItemData

var instance_id: String = ""
var state: Dictionary = {}

var current_holder: Node = null
var current_hand: HandController = null
var saved_collision_layer: int = 8
var saved_collision_mask: int = 1

@export var primary_grip_point: Marker3D
@export var secondary_grip_point: Marker3D


func _ready() -> void:
	if instance_id.is_empty():
		instance_id = str(ResourceUID.create_id())

	if primary_grip_point == null:
		primary_grip_point = get_node_or_null("PrimaryGripPoint") as Marker3D
	if secondary_grip_point == null:
		secondary_grip_point = get_node_or_null("SecondaryGripPoint") as Marker3D

	if data == null:
		push_error("У предмета '%s' не назначен ItemData" % get_path())
		return

	_apply_item_data()


func setup(item_data: ItemData, initial_state: Dictionary = {}) -> void:
	data = item_data
	state = initial_state.duplicate(true)

	if is_inside_tree():
		_apply_item_data()


func _apply_item_data() -> void:
	saved_collision_layer = data.collision_layer
	saved_collision_mask = data.collision_mask
	collision_layer = saved_collision_layer
	collision_mask = saved_collision_mask


func can_be_grabbed() -> bool:
	return data != null and data.can_grab and current_holder == null


func is_heavy() -> bool:
	return data != null and data.is_heavy


func on_grab(holder: Node) -> void:
	current_holder = holder


func on_drop() -> void:
	current_holder = null
	current_hand = null


func on_throw(direction: Vector3, force: float) -> void:
	current_holder = null
	current_hand = null
	linear_velocity = direction * force


func on_primary_action() -> void:
	pass


func on_secondary_action() -> void:
	pass


func on_primary_action_released() -> void:
	pass


func on_mouse_motion(_relative: Vector2) -> void:
	pass


func disable_collision() -> void:
	freeze = true
	sleeping = true
	collision_layer = 0
	collision_mask = 0


func enable_collision() -> void:
	freeze = false
	sleeping = false
	collision_layer = saved_collision_layer
	collision_mask = saved_collision_mask


func make_state_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"item_id": data.item_id if data != null else &"",
		"state": state.duplicate(true)
	}
