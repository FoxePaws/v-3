class_name ItemFactory
extends RefCounted


static func create_item(
	data: ItemData,
	initial_state: Dictionary = {}
) -> ItemInstance:
	if data == null or data.item_scene == null:
		push_error("Для ItemData не назначена сцена предмета")
		return null

	var item: ItemInstance = data.item_scene.instantiate() as ItemInstance
	if item == null:
		push_error("Корень сцены предмета должен наследоваться от ItemInstance")
		return null

	item.setup(data, initial_state)
	return item
