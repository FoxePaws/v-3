class_name ItemInstance
extends RigidBody3D

signal total_weight_changed(old_weight: float, new_weight: float)

@export_category("Identity")
@export var item_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D


@export_category("Interaction")
@export var can_grab: bool = true
@export var can_throw: bool = true
@export var heavy_item: bool = false
@export var throw_force: float = 8.0
@export var secondary_hand_offset: Vector3 = Vector3.ZERO
@export var secondary_hand_rotation: Vector3 = Vector3.ZERO

@export_category("Size and weight")
@export_range(0.0, 10000.0, 0.01) var item_size: float = 1.0
@export_range(0.0, 10000.0, 0.01) var item_weight: float = 1.0

@export_category("Durability")
@export_range(0.0, 100000.0, 0.1) var max_durability: float = 100.0

@export_category("Collision")
@export_flags_3d_physics var item_collision_layer: int = 8
@export_flags_3d_physics var item_collision_mask: int = 1

@export_category("Grip points")
@export var primary_grip_point: Marker3D
@export var secondary_grip_point: Marker3D

var instance_id: String = ""
var durability: float = -1.0
var state: Dictionary = {}
var flags: Dictionary = {}

var current_holder: Node = null
var current_hand: HandController = null

var saved_collision_layer: int = 8
var saved_collision_mask: int = 1

var base_weight: float = 0.0
var total_weight: float = 0.0


func _ready() -> void:
	_ensure_instance_id()

	if primary_grip_point == null:
		primary_grip_point = get_node_or_null("PrimaryGripPoint") as Marker3D

	if secondary_grip_point == null:
		secondary_grip_point = get_node_or_null("SecondaryGripPoint") as Marker3D

	if durability < 0.0:
		durability = maxf(max_durability, 0.0)

	saved_collision_layer = item_collision_layer
	saved_collision_mask = item_collision_mask
	collision_layer = saved_collision_layer
	collision_mask = saved_collision_mask

	base_weight = maxf(item_weight, 0.0)
	if total_weight < base_weight:
		total_weight = base_weight



func is_heavy() -> bool:
	return heavy_item
 
func setup(saved: Dictionary = {}) -> void:
	if saved.has("instance_id"):
		var saved_id: String = str(saved["instance_id"])
		if not saved_id.is_empty():
			instance_id = saved_id

	if saved.has("durability"):
		durability = clampf(float(saved["durability"]), 0.0, maxf(max_durability, 0.0))

	var saved_state: Variant = saved.get("state", {})
	if saved_state is Dictionary:
		state = (saved_state as Dictionary).duplicate(true)

	var saved_flags: Variant = saved.get("flags", {})
	if saved_flags is Dictionary:
		flags = (saved_flags as Dictionary).duplicate(true)

	if instance_id.is_empty():
		_ensure_instance_id()

	if durability < 0.0:
		durability = maxf(max_durability, 0.0)


func _ensure_instance_id() -> void:
	if instance_id.is_empty():
		instance_id = str(ResourceUID.create_id())


func get_components() -> Array[ItemComponent]:
	var result: Array[ItemComponent] = []
	_collect_components(self, result)
	return result


func _collect_components(node: Node, result: Array[ItemComponent]) -> void:
	for child: Node in node.get_children():
		if child is ItemComponent:
			result.append(child as ItemComponent)
		_collect_components(child, result)


func get_component(component_type: Variant) -> ItemComponent:
	for component: ItemComponent in get_components():
		if is_instance_of(component, component_type):
			return component
	return null


func can_be_grabbed() -> bool:
	return can_grab and current_holder == null


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
	for component: ItemComponent in get_components():
		component.on_primary_action()


func on_secondary_action() -> void:
	for component: ItemComponent in get_components():
		component.on_secondary_action()


func on_primary_action_released() -> void:
	for component: ItemComponent in get_components():
		component.on_primary_action_released()


func on_mouse_motion(relative: Vector2) -> void:
	for component: ItemComponent in get_components():
		component.on_mouse_motion(relative)


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


func change_contents_weight(weight_delta: float) -> void:
	if is_zero_approx(weight_delta):
		return

	var old_weight: float = total_weight
	total_weight = maxf(base_weight, total_weight + weight_delta)

	if not is_equal_approx(old_weight, total_weight):
		total_weight_changed.emit(old_weight, total_weight)


func set_total_weight(new_weight: float) -> void:
	var clamped_weight: float = maxf(base_weight, new_weight)
	if is_equal_approx(total_weight, clamped_weight):
		return

	var old_weight: float = total_weight
	total_weight = clamped_weight
	total_weight_changed.emit(old_weight, total_weight)


func recalculate_total_weight() -> float:
	var contents_weight: float = 0.0

	for component: ItemComponent in get_components():
		if component is ItemContainer:
			contents_weight += (component as ItemContainer).recalculate_contents_weight()

	set_total_weight(base_weight + contents_weight)
	return total_weight


func make_save_data() -> Dictionary:
	var component_states: Dictionary = {}

	for component: ItemComponent in get_components():
		var component_path: String = str(get_path_to(component))
		component_states[component_path] = component.make_save_data()

	return {
		"scene_path": scene_file_path,
		"item_id": str(item_id),
		"instance_id": instance_id,
		"durability": durability,
		"state": state.duplicate(true),
		"flags": flags.duplicate(true),
		"components": component_states,
	}


func restore_save_data(saved: Dictionary) -> void:
	setup(saved)

	var raw_components: Variant = saved.get("components", {})
	if not raw_components is Dictionary:
		return

	var component_states: Dictionary = raw_components as Dictionary

	for component: ItemComponent in get_components():
		var component_path: String = str(get_path_to(component))
		var raw_state: Variant = component_states.get(component_path, {})
		if raw_state is Dictionary:
			component.restore_save_data(raw_state as Dictionary)
