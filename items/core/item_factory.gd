class_name ItemFactory
extends RefCounted


static func create_item(
	item_scene: PackedScene,
	initial_state: Dictionary = {}
) -> ItemInstance:
	if item_scene == null:
		push_error("ItemFactory: не передана сцена предмета")
		return null

	var node: Node = item_scene.instantiate()
	if not node is ItemInstance:
		push_error("ItemFactory: корень сцены должен наследоваться от ItemInstance")
		node.free()
		return null

	var item_instance: ItemInstance = node as ItemInstance
	item_instance.setup(initial_state)
	return item_instance
