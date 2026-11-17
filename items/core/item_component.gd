class_name ItemComponent
extends Node

@export var mutable_state: Dictionary = {}

var item: ItemInstance = null


func _ready() -> void:
	item = _find_item_owner()


func _find_item_owner() -> ItemInstance:
	var current: Node = get_parent()

	while current != null:
		if current is ItemInstance:
			return current as ItemInstance
		current = current.get_parent()

	return null


func make_save_data() -> Dictionary:
	return mutable_state.duplicate(true)


func restore_save_data(saved_state: Dictionary) -> void:
	mutable_state = saved_state.duplicate(true)


func on_primary_action() -> void:
	pass


func on_secondary_action() -> void:
	pass


func on_primary_action_released() -> void:
	pass


func on_mouse_motion(_relative: Vector2) -> void:
	pass
