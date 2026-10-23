class_name ItemContainer
extends Node

@export_range(1, 100) var capacity: int = 8
@export var hide_item_models: bool = true

var items: Array[ItemInstance] = []


func _ready() -> void:
	items.resize(maxi(capacity, 0))


func get_item_at(index: int) -> ItemInstance:
	if index < 0 or index >= items.size():
		return null
	return items[index]


func can_accept(item: ItemInstance, index: int = -1) -> bool:
	if item == null:
		return false

	if item == get_parent() or item.is_ancestor_of(self):
		return false

	if index >= 0:
		if index >= items.size() or items[index] != null:
			return false
	else:
		if _first_empty_slot() < 0:
			return false

	var max_size := 0.0
	var container_item := get_parent() as ItemInstance

	if container_item != null and container_item.data != null:
		max_size = container_item.data.max_item_size

	if max_size > 0.0 and item.data != null:
		if item.data.item_size > max_size:
			return false

	return true


func add_item(item: ItemInstance, index: int = -1) -> bool:
	if index < 0:
		index = _first_empty_slot()

	if not can_accept(item, index):
		return false

	items[index] = item
	item.current_holder = self
	item.current_hand = null
	item.disable_collision()
	item.reparent(self, false)
	item.visible = not hide_item_models
	return true


func remove_item(item: ItemInstance) -> bool:
	var index := items.find(item)
	if index < 0:
		return false

	items[index] = null
	item.current_holder = null
	item.visible = true
	return true


func _first_empty_slot() -> int:
	for i in range(items.size()):
		if items[i] == null:
			return i
	return -1

signal changed


func notify_changed() -> void:
	changed.emit()
