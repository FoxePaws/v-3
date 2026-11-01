extends Node

const SAVE_PATH: String = "user://savegame.json"

const SAVE_DIRECTORY: String = "user://saves"
const DEFAULT_SLOT: String = "quick"

@export var save_action: StringName = &"save_game"
@export var load_action: StringName = &"load_game"


func _unhandled_input(_event: InputEvent) -> void:
	if InputMap.has_action(save_action) and Input.is_action_just_pressed(save_action):
		save_game(DEFAULT_SLOT)
		get_viewport().set_input_as_handled()
	elif InputMap.has_action(load_action) and Input.is_action_just_pressed(load_action):
		load_game(DEFAULT_SLOT)
		get_viewport().set_input_as_handled()

func save_game(slot_name: String = DEFAULT_SLOT) -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		push_error("SaveManager: активная сцена не найдена")
		return false

	var player: Player = _find_player(scene)
	if player == null:
		push_error("SaveManager: Player не найден")
		return false

	var records: Array[Dictionary] = []
	for item: ItemInstance in _find_items(scene):
		if item.data == null:
			continue
		records.append(_make_record(item, player))

	# Здесь создание каталога, открытие файла и запись records.
	# Вызов JSON.stringify должен быть внутри этой функции.
	return true


func load_game(slot_name: String = DEFAULT_SLOT) -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		push_error("SaveManager: активная сцена не найдена")
		return false

	var player: Player = _find_player(scene)
	if player == null:
		push_error("SaveManager: Player не найден")
		return false

	# Здесь чтение и проверка JSON.
	# После разбора файла:
	await _clear_existing_items(scene, player)

	# Здесь создание и восстановление предметов.
	return true


func _get_save_path(slot_name: String) -> String:
	var safe_name: String = slot_name.strip_edges()
	if safe_name.is_empty():
		safe_name = DEFAULT_SLOT

	# Не допускаем, чтобы имя слота стало путём к файлу вне каталога сейвов.
	var regex: RegEx = RegEx.new()
	regex.compile("[^A-Za-z0-9_-]")
	safe_name = regex.sub(safe_name, "_", true)

	return "%s/%s.json" % [SAVE_DIRECTORY, safe_name]


func _make_record(item: ItemInstance, player: Player) -> Dictionary:
	return {
		"item_data_path": item.data.resource_path,
		"state": item.make_state_dict(),
		"location": _get_location(item, player),
	}


func _get_location(item: ItemInstance, player: Player) -> Dictionary:
	var holder: Node = item.current_holder

	if holder is HandController:
		var hand: HandController = holder as HandController
		return {"kind": "hand", "side": "right" if hand.is_right_hand else "left"}

	if holder is EquipmentComponent:
		var equipment: EquipmentComponent = holder as EquipmentComponent
		for slot_id: StringName in equipment.slot_ids:
			if equipment.get_item(slot_id) == item:
				return {"kind": "equipment", "slot": str(slot_id)}

	if holder is ItemContainer:
		var container: ItemContainer = holder as ItemContainer
		var parent_item: ItemInstance = container.get_parent() as ItemInstance
		var index: int = container.items.find(item)
		if parent_item != null:
			return {
				"kind": "container",
				"owner_id": parent_item.instance_id,
				"slot": index,
			}

	var transform: Transform3D = item.global_transform
	var rotation: Quaternion = transform.basis.get_rotation_quaternion()
	return {
		"kind": "world",
		"position": _vector_to_array(transform.origin),
		"rotation": [
			rotation.x,
			rotation.y,
			rotation.z,
			rotation.w,
		],
		"scale": _vector_to_array(transform.basis.get_scale()),
	}


func _restore_location(
	item: ItemInstance,
	location: Dictionary,
	instances: Dictionary[String, ItemInstance],
	player: Player,
	scene: Node
) -> void:
	var kind: String = str(location.get("kind", "world"))

	match kind:
		"hand":
			var side: String = str(location.get("side", "right"))
			var hand: HandController = (
				player.right_hand if side == "right" else player.left_hand
			)
			if hand == null or hand.held_item != null or hand.held_item_point == null:
				return

			hand.held_item = item
			item.current_holder = hand
			item.current_hand = hand
			item.disable_collision()
			item.reparent(hand.held_item_point, false)
			hand._attach_item_to_hand(item)

		"equipment":
			var slot_id: StringName = StringName(str(location.get("slot", "")))
			player.equipment.restore_item(item, slot_id)

		"container":
			var owner_id: String = str(location.get("owner_id", ""))
			var owner_item: ItemInstance = instances.get(owner_id) as ItemInstance
			if owner_item == null:
				return

			var container: ItemContainer = owner_item.find_child(
				"ItemContainer", true, false
			) as ItemContainer
			if container == null:
				return

			var slot_index: int = int(location.get("slot", -1))
			container.add_item(item, slot_index)

		_:
			_restore_world_transform(item, location)


func _restore_world_transform(item: ItemInstance, location: Dictionary) -> void:
	var position: Vector3 = _array_to_vector(location.get("position", []), Vector3.ZERO)
	var scale: Vector3 = _array_to_vector(location.get("scale", []), Vector3.ONE)
	var rotation_data: Variant = location.get("rotation", [])

	var rotation: Quaternion = Quaternion.IDENTITY
	if rotation_data is Array and rotation_data.size() == 4:
		rotation = Quaternion(
			float(rotation_data[0]),
			float(rotation_data[1]),
			float(rotation_data[2]),
			float(rotation_data[3])
		)

	item.global_transform = Transform3D(
		Basis(rotation).scaled(scale),
		position
	)


func _clear_existing_items(scene: Node, player: Player) -> void:
	player.right_hand.held_item = null
	player.left_hand.held_item = null
	player.equipment.clear_slots_for_load()

	for item: ItemInstance in _find_items(scene):
		item.queue_free()

	# Даём Godot удалить старые узлы, прежде чем создавать экземпляры с теми же ID.
	await get_tree().process_frame


func _find_items(root: Node) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	_collect_items_recursive(root, result)
	return result


func _collect_items_recursive(node: Node, result: Array[ItemInstance]) -> void:
	for child: Node in node.get_children():
		if child is ItemInstance:
			result.append(child as ItemInstance)
		_collect_items_recursive(child, result)


func _find_player(root: Node) -> Player:
	if root is Player:
		return root as Player

	for child: Node in root.get_children():
		var found: Player = _find_player(child)
		if found != null:
			return found

	return null


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _array_to_vector(value: Variant, fallback: Vector3) -> Vector3:
	if not value is Array or value.size() != 3:
		return fallback

	return Vector3(
		float(value[0]),
		float(value[1]),
		float(value[2])
	)
