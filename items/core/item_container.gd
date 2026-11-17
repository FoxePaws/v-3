class_name ItemContainer
extends ItemComponent

signal changed

@export_range(1, 100) var capacity: int = 8
@export_range(0.0, 10000.0, 0.01) var max_item_size: float = 100.0
@export var hide_item_models: bool = true

var items: Array[ItemInstance] = []


func _ready() -> void:
	super._ready()
	_rebuild_items()


func _rebuild_items() -> void:
	items.clear()

	for child: Node in get_children():
		if child is ItemInstance:
			items.append(child as ItemInstance)

	while items.size() < maxi(capacity, 0):
		items.append(null)


func get_item_at(index: int) -> ItemInstance:
	if index < 0 or index >= items.size():
		return null
	return items[index]


func can_accept(item_instance: ItemInstance, index: int = -1) -> bool:
	if item_instance == null or item_instance == item:
		return false

	if item_instance.is_ancestor_of(self):
		return false

	if max_item_size > 0.0 and item_instance.item_size > max_item_size:
		return false

	if index >= 0:
		return index < items.size() and items[index] == null

	return _first_empty_slot() >= 0


func add_item(item_instance: ItemInstance, index: int = -1) -> bool:
	if index < 0:
		index = _first_empty_slot()

	if not can_accept(item_instance, index):
		return false

	var old_holder: Node = item_instance.current_holder
	if old_holder is ItemContainer:
		var old_container: ItemContainer = old_holder as ItemContainer
		if not old_container.remove_item(item_instance):
			return false

	items[index] = item_instance
	item_instance.current_holder = self
	item_instance.current_hand = null
	item_instance.disable_collision()
	item_instance.reparent(self, false)
	item_instance.visible = not hide_item_models

	var weight_callback: Callable = _on_item_total_weight_changed
	if not item_instance.total_weight_changed.is_connected(weight_callback):
		item_instance.total_weight_changed.connect(weight_callback)

	_update_owner_weight(item_instance.total_weight)
	changed.emit()
	return true


func remove_item(item_instance: ItemInstance) -> bool:
	var index: int = items.find(item_instance)
	if index < 0:
		return false

	_update_owner_weight(-item_instance.total_weight)

	var weight_callback: Callable = _on_item_total_weight_changed
	if item_instance.total_weight_changed.is_connected(weight_callback):
		item_instance.total_weight_changed.disconnect(weight_callback)

	items[index] = null
	item_instance.current_holder = null
	item_instance.current_hand = null
	item_instance.visible = true
	changed.emit()
	return true


func _update_owner_weight(weight_delta: float) -> void:
	var owner_item: ItemInstance = item
	if owner_item != null:
		owner_item.change_contents_weight(weight_delta)


func _on_item_total_weight_changed(old_weight: float, new_weight: float) -> void:
	_update_owner_weight(new_weight - old_weight)
	changed.emit()


func recalculate_contents_weight() -> float:
	var contents_weight: float = 0.0

	for contained_item: ItemInstance in items:
		if contained_item == null:
			continue
		contents_weight += contained_item.recalculate_total_weight()

	return contents_weight


func _first_empty_slot() -> int:
	for index: int in range(items.size()):
		if items[index] == null:
			return index
	return -1


func notify_changed() -> void:
	changed.emit()


func make_save_data() -> Dictionary:
	var saved_state: Dictionary = super.make_save_data()
	saved_state["capacity"] = capacity
	return saved_state
