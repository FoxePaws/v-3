# item_instance.gd
class_name ItemInstance
extends RigidBody3D

var data: ItemData

var instance_id: String = ""
var state: Dictionary = {}

var current_holder: Node = null
var current_hand: HandController = null
var saved_collision_layer: int = 8
var saved_collision_mask: int = 1

var flags: Dictionary = {}
var durability: float = -1.0

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

	if durability < 0.0:
		durability = data.max_durability

	_apply_item_data()


func setup(item_data: ItemData, initial_state: Dictionary = {}) -> void:
	data = item_data

	# Словарь сохранения содержит instance_id и вложенный state.
	# Старые вызовы setup(data, {"custom_key": value}) продолжают работать.
	if initial_state.has("instance_id") or initial_state.has("durability"):
		load_state_dict(initial_state)
	else:
		state = initial_state.duplicate(true)

	if is_inside_tree():
		if instance_id.is_empty():
			instance_id = str(ResourceUID.create_id())
		if data != null and durability < 0.0:
			durability = data.max_durability
		_apply_item_data()

func make_state_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"item_id": data.item_id if data != null else &"",
		"item_data_path": data.resource_path if data != null else "",
		"state": state.duplicate(true),
		"durability": durability,
		"flags": flags.duplicate(true),
	}

func load_state_dict(saved: Dictionary) -> void:
	var saved_id: Variant = saved.get("instance_id", "")
	if saved_id is String and not saved_id.is_empty():
		instance_id = saved_id

	var saved_state: Variant = saved.get("state", {})
	if saved_state is Dictionary:
		state = saved_state.duplicate(true)

	var saved_durability: Variant = saved.get(
		"durability",
		data.max_durability if data != null else 100.0
	)
	if saved_durability is int or saved_durability is float:
		var maximum: float = data.max_durability if data != null else 100.0
		durability = clampf(float(saved_durability), 0.0, maximum)

	var saved_flags: Variant = saved.get("flags", {})
	if saved_flags is Dictionary:
		flags.clear()
		for key: Variant in saved_flags:
			var value: Variant = saved_flags[key]
			if value is bool:
				flags[StringName(str(key))] = value

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
