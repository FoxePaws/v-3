class_name ItemSpawner
extends Node3D


@export var item_data: ItemData
@export var spawn_on_ready: bool = true
@export var spawn_parent: Node


var spawned_item: ItemInstance = null


func _ready() -> void:
	if spawn_on_ready:
		spawn()


func spawn() -> ItemInstance:
	if item_data == null:
		push_error(
			"ItemSpawner '%s': не назначен item_data"
			% get_path()
		)
		return null

	if item_data.item_scene == null:
		push_error(
			"ItemSpawner '%s': в ItemData не назначен item_scene"
			% get_path()
		)
		return null

	if is_instance_valid(spawned_item):
		return spawned_item

	var new_item: Node = item_data.item_scene.instantiate()

	if not new_item is ItemInstance:
		push_error(
			"Сцена предмета не содержит ItemInstance: "
			+ str(item_data.item_scene)
		)

		new_item.queue_free()
		return null

	var item := new_item as ItemInstance

	# Назначаем данные ДО add_child().
	item.data = item_data

	var parent_node: Node = spawn_parent

	if parent_node == null:
		parent_node = get_tree().current_scene

	parent_node.add_child(item)

	item.global_transform = global_transform

	spawned_item = item

	return spawned_item


func despawn() -> void:
	if is_instance_valid(spawned_item):
		spawned_item.queue_free()

	spawned_item = null


func respawn() -> ItemInstance:
	despawn()
	return spawn()
