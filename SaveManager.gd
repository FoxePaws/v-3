extends Node

const SAVE_DIRECTORY: String = "user://saves"
const PLAYER_SAVE_PATH: String = "user://saves/player.json"
const LOCATIONS_DIRECTORY: String = "user://saves/locations"

@export var save_action: StringName = &"save_game"
@export var load_action: StringName = &"load_game"


func _unhandled_input(_event: InputEvent) -> void:
	if InputMap.has_action(save_action) and Input.is_action_just_pressed(save_action):
		save_game()
		get_viewport().set_input_as_handled()
	elif InputMap.has_action(load_action) and Input.is_action_just_pressed(load_action):
		load_game()
		get_viewport().set_input_as_handled()


func save_game(_slot_name: String = "quick") -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		push_error("SaveManager: активная сцена не найдена")
		return false

	var player: Player = _find_player(scene)
	if player == null:
		push_error("SaveManager: Player не найден")
		return false

	var player_records: Array[Dictionary] = []
	var location_records: Array[Dictionary] = []

	for item: ItemInstance in _find_items(scene):
		var record: Dictionary = _make_record(item)
		if _is_player_item(item):
			player_records.append(record)
		else:
			location_records.append(record)

	var player_transform: Transform3D = player.global_transform
	var player_rotation: Quaternion = player_transform.basis.get_rotation_quaternion()

	var player_data: Dictionary = {
		"version": 3,
		"player": {
			"position": _vector_to_array(player_transform.origin),
			"rotation": _quaternion_to_array(player_rotation),
		},
		"items": player_records,
		"world_time": _make_world_time_save_data(scene),
		"stats": _make_player_stats_save_data(player),
	}

	var location_data: Dictionary = {
		"version": 3,
		"location_id": _get_location_id(scene),
		"items": location_records,
	}

	if not _write_json(PLAYER_SAVE_PATH, player_data):
		return false

	var location_path: String = _get_location_save_path(scene)
	if not _write_json(location_path, location_data):
		return false

	print(
		"SaveManager: сохранено предметов игрока: %d; предметов локации: %d"
		% [player_records.size(), location_records.size()]
	)
	return true


func load_game(_slot_name: String = "quick") -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		push_error("SaveManager: активная сцена не найдена")
		return false

	var player: Player = _find_player(scene)
	if player == null:
		push_error("SaveManager: Player не найден")
		return false

	if not FileAccess.file_exists(PLAYER_SAVE_PATH):
		push_error("SaveManager: файл игрока не найден: %s" % PLAYER_SAVE_PATH)
		return false

	var player_data: Dictionary = _read_json(PLAYER_SAVE_PATH)
	if player_data.is_empty():
		return false

	var location_path: String = _get_location_save_path(scene)
	var location_data: Dictionary = {}

	if FileAccess.file_exists(location_path):
		location_data = _read_json(location_path)
		if location_data.is_empty():
			return false

	var player_records: Array[Dictionary] = _get_item_records(player_data)
	var location_records: Array[Dictionary] = _get_item_records(location_data)
	var all_records: Array[Dictionary] = []
	all_records.append_array(player_records)
	all_records.append_array(location_records)

	await _clear_existing_items(scene, player)
	_restore_player_transform(player, player_data)

	var instances: Dictionary[String, ItemInstance] = {}
	var restored_items: Array[ItemInstance] = []
	var records_by_item: Dictionary = {}

	# Сначала создаём все узлы. Связи parent_id устанавливаются после _ready().
	for record: Dictionary in all_records:
		var item: ItemInstance = _create_item_from_record(record)
		if item == null:
			continue

		scene.add_child(item)
		restored_items.append(item)

		var instance_id: String = str(record.get("instance_id", ""))
		if not instance_id.is_empty():
			instances[instance_id] = item
			records_by_item[item] = record

	await get_tree().process_frame

	# Восстанавливаем изменяемые данные после того, как компоненты прошли _ready().
	for item: ItemInstance in restored_items:
		var record: Dictionary = records_by_item.get(item, {})

		item.restore_save_data(record)

	# Все ссылки на родительские предметы уже доступны через instances.
	for item: ItemInstance in restored_items:
		var record: Dictionary = records_by_item.get(item, {})

		_restore_location(item, record, instances, player, scene)

	for item: ItemInstance in restored_items:
		item.recalculate_total_weight()

	if player.equipment != null:
		player.equipment.recalculate_equipment_weight()

	# Сохраняем существующий порядок интеграции времени и статусов.
	_restore_world_time_from_save(scene, player_data)
	_restore_player_stats_from_save(player, player_data)

	print(
		"SaveManager: загружено предметов игрока: %d; предметов локации: %d"
		% [player_records.size(), location_records.size()]
	)
	return true


func _make_record(item: ItemInstance) -> Dictionary:
	var transform: Transform3D = item.global_transform
	var save_data: Dictionary = item.make_save_data()
	var location: Dictionary = _get_item_location(item)

	save_data["parent_id"] = str(location.get("parent_id", ""))
	save_data["location"] = location
	save_data["position"] = _vector_to_array(transform.origin)
	save_data["rotation"] = _quaternion_to_array(
		transform.basis.get_rotation_quaternion()
	)
	save_data["scale"] = _vector_to_array(transform.basis.get_scale())

	return save_data


func _get_item_location(item: ItemInstance) -> Dictionary:
	var holder: Node = item.current_holder

	if holder is HandController:
		var hand: HandController = holder as HandController
		return {
			"kind": "hand",
			"side": "right" if hand.is_right_hand else "left",
		}

	if holder is EquipmentComponent:
		var equipment: EquipmentComponent = holder as EquipmentComponent
		for slot_id: StringName in equipment.slot_ids:
			if equipment.get_item(slot_id) == item:
				return {
					"kind": "equipment",
					"slot": str(slot_id),
				}

	if holder is ItemContainer:
		var container: ItemContainer = holder as ItemContainer
		var parent_item: ItemInstance = _find_parent_item(container)

		if parent_item != null:
			return {
				"kind": "container",
				"parent_id": parent_item.instance_id,
				"container_path": str(parent_item.get_path_to(container)),
				"slot": container.items.find(item),
			}

	return {"kind": "world"}


func _restore_location(
	item: ItemInstance,
	record: Dictionary,
	instances: Dictionary[String, ItemInstance],
	player: Player,
	scene: Node
) -> void:
	var raw_location: Variant = record.get("location", {})
	if not raw_location is Dictionary:
		_restore_world_transform(item, record)
		return

	var location: Dictionary = raw_location as Dictionary
	var kind: String = str(location.get("kind", "world"))

	match kind:
		"hand":
			var side: String = str(location.get("side", "right"))
			var hand: HandController = (
				player.right_hand if side == "right" else player.left_hand
			)

			if hand == null or hand.held_item != null or hand.held_item_point == null:
				_restore_world_transform(item, record)
				return

			hand.held_item = item
			item.current_holder = hand
			item.current_hand = hand
			item.disable_collision()
			item.reparent(hand.held_item_point, false)
			hand._attach_item_to_hand(item)

		"equipment":
			var slot_id: StringName = StringName(str(location.get("slot", "")))
			if player.equipment == null:
				_restore_world_transform(item, record)
				return

			if not player.equipment.restore_item(item, slot_id):
				_restore_world_transform(item, record)

		"container":
			var parent_id: String = str(
				location.get("parent_id", record.get("parent_id", ""))
			)
			var parent_item: ItemInstance = instances.get(parent_id) as ItemInstance
			if parent_item == null:
				_restore_world_transform(item, record)
				return

			var container: ItemContainer = _get_saved_container(parent_item, location)
			if container == null:
				_restore_world_transform(item, record)
				return

			var slot_index: int = int(location.get("slot", -1))
			if not container.add_item(item, slot_index):
				_restore_world_transform(item, record)

		_:
			_restore_world_transform(item, record)


func _get_saved_container(
	parent_item: ItemInstance,
	location: Dictionary
) -> ItemContainer:
	var container_path: String = str(location.get("container_path", ""))
	if not container_path.is_empty():
		var saved_node: Node = parent_item.get_node_or_null(
			NodePath(container_path)
		)
		if saved_node is ItemContainer:
			return saved_node as ItemContainer

	return parent_item.find_child("ItemContainer", true, false) as ItemContainer


func _create_item_from_record(record: Dictionary) -> ItemInstance:
	var scene_path: String = str(record.get("scene_path", ""))
	if scene_path.is_empty():
		push_warning("SaveManager: у записи предмета нет scene_path")
		return null

	var loaded_resource: Resource = load(scene_path)
	if loaded_resource == null or not loaded_resource is PackedScene:
		push_warning(
			"SaveManager: не удалось загрузить PackedScene: %s" % scene_path
		)
		return null

	var item: ItemInstance = ItemFactory.create_item(
		loaded_resource as PackedScene
	)
	if item == null:
		push_warning("SaveManager: ItemFactory не создала предмет: %s" % scene_path)
		return null

	return item


func _restore_world_transform(item: ItemInstance, record: Dictionary) -> void:
	var position: Vector3 = _array_to_vector(
		record.get("position", []),
		Vector3.ZERO
	)
	var scale: Vector3 = _array_to_vector(
		record.get("scale", []),
		Vector3.ONE
	)
	var rotation: Quaternion = _array_to_quaternion(
		record.get("rotation", []),
		Quaternion.IDENTITY
	)

	item.current_holder = null
	item.current_hand = null
	item.reparent(get_tree().current_scene, false)
	item.global_transform = Transform3D(Basis(rotation).scaled(scale), position)
	item.enable_collision()



func _is_player_item(item: ItemInstance) -> bool:
	var current: Node = item

	while current != null:
		if current is Player:
			return true
		current = current.get_parent()

	return false


func _find_parent_item(node: Node) -> ItemInstance:
	var current: Node = node.get_parent()

	while current != null:
		if current is ItemInstance:
			return current as ItemInstance
		current = current.get_parent()

	return null


func _get_item_records(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_items: Variant = data.get("items", [])

	if not raw_items is Array:
		push_warning("SaveManager: поле 'items' отсутствует или не является Array")
		return result

	for raw_record: Variant in raw_items:
		if raw_record is Dictionary:
			result.append(raw_record as Dictionary)
		else:
			push_warning("SaveManager: пропущена некорректная запись предмета")

	return result


func _write_json(path: String, data: Dictionary) -> bool:
	var directory_path: String = path.get_base_dir()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory_path)
	)

	if directory_error != OK:
		push_error(
			"SaveManager: не удалось создать каталог %s: %s"
			% [directory_path, error_string(directory_error)]
		)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error(
			"SaveManager: не удалось открыть %s: %s"
			% [path, error_string(FileAccess.get_open_error())]
		)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.flush()

	var write_error: Error = file.get_error()
	file.close()

	if write_error != OK:
		push_error(
			"SaveManager: ошибка записи %s: %s"
			% [path, error_string(write_error)]
		)
		return false

	return true


func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error(
			"SaveManager: не удалось открыть %s: %s"
			% [path, error_string(FileAccess.get_open_error())]
		)
		return {}

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		push_error(
			"SaveManager: ошибка JSON в %s, строка %d: %s"
			% [path, json.get_error_line(), json.get_error_message()]
		)
		return {}

	if not json.data is Dictionary:
		push_error("SaveManager: корень %s должен быть Dictionary" % path)
		return {}

	return json.data as Dictionary


func _get_location_id(scene: Node) -> String:
	var raw_id: Variant = null

	if scene.has_method("get_location_id"):
		raw_id = scene.call("get_location_id")
	else:
		for property: Dictionary in scene.get_property_list():
			if str(property.get("name", "")) == "location_id":
				raw_id = scene.get("location_id")
				break

	var location_id: String = str(raw_id).strip_edges()
	if location_id.is_empty():
		location_id = scene.scene_file_path.get_file().get_basename()
	if location_id.is_empty():
		location_id = "default"

	return _sanitize_file_name(location_id)


func _get_location_save_path(scene: Node) -> String:
	return "%s/%s.json" % [LOCATIONS_DIRECTORY, _get_location_id(scene)]


func _sanitize_file_name(value: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("[^A-Za-z0-9_-]")
	return regex.sub(value, "_", true)


func _make_world_time_save_data(scene: Node) -> Dictionary:
	if not scene.has_method("get_world_time_save_data"):
		push_warning(
			"SaveManager: у текущей сцены нет get_world_time_save_data()"
		)
		return {}

	var raw_data: Variant = scene.call("get_world_time_save_data")
	if raw_data is Dictionary:
		return (raw_data as Dictionary).duplicate(true)

	push_warning("SaveManager: данные мирового времени должны быть Dictionary")
	return {}


func _make_player_stats_save_data(player: Player) -> Dictionary:
	var stats_node: Node = player.get_node_or_null("PlayerStats")
	if stats_node == null or not stats_node.has_method("make_save_data"):
		push_warning("SaveManager: PlayerStats или make_save_data() не найдены")
		return {}

	var raw_data: Variant = stats_node.call("make_save_data")
	if not raw_data is Dictionary:
		push_warning("SaveManager: PlayerStats.make_save_data() должен вернуть Dictionary")
		return {}

	var stats_data: Dictionary = (raw_data as Dictionary).duplicate(true)

	if stats_node.has_method("make_status_effects_save_data"):
		var raw_effects: Variant = stats_node.call(
			"make_status_effects_save_data"
		)
		if raw_effects is Array:
			stats_data["status_effects"] = (raw_effects as Array).duplicate(true)

	return stats_data


func _restore_world_time_from_save(scene: Node, save_data: Dictionary) -> void:
	var raw_world_time: Variant = save_data.get("world_time", {})
	if not raw_world_time is Dictionary:
		push_warning("SaveManager: world_time отсутствует или имеет неверный тип")
		return

	if scene.has_method("restore_world_time"):
		scene.call("restore_world_time", raw_world_time as Dictionary)


func _restore_player_stats_from_save(
	player: Player,
	save_data: Dictionary
) -> void:
	var stats_node: Node = player.get_node_or_null("PlayerStats")
	if stats_node == null:
		push_warning("SaveManager: узел PlayerStats не найден")
		return

	var raw_stats: Variant = save_data.get("stats", {})
	if not raw_stats is Dictionary:
		push_warning("SaveManager: stats отсутствуют или имеют неверный тип")
		return

	var stats_data: Dictionary = raw_stats as Dictionary

	# К этому моменту уже восстановлены руки и экипировка.
	player.recalculate_equipment_stats()

	if stats_node.has_method("restore_save_data"):
		stats_node.call("restore_save_data", stats_data)
	else:
		push_warning("SaveManager: у PlayerStats нет restore_save_data()")

	var raw_effects: Variant = stats_data.get("status_effects", [])
	if stats_node.has_method("restore_status_effects_save_data"):
		stats_node.call("restore_status_effects_save_data", raw_effects)


func _clear_existing_items(scene: Node, player: Player) -> void:
	if player.right_hand != null:
		player.right_hand.held_item = null
	if player.left_hand != null:
		player.left_hand.held_item = null
	if player.equipment != null:
		player.equipment.clear_slots_for_load()

	for item: ItemInstance in _find_items(scene):
		item.queue_free()

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


func _restore_player_transform(player: Player, player_data: Dictionary) -> void:
	var raw_player: Variant = player_data.get("player", {})
	if not raw_player is Dictionary:
		push_warning("SaveManager: данные player отсутствуют")
		return

	var data: Dictionary = raw_player as Dictionary
	var position: Vector3 = _array_to_vector(
		data.get("position", []),
		player.global_position
	)
	var rotation: Quaternion = _array_to_quaternion(
		data.get("rotation", []),
		player.global_transform.basis.get_rotation_quaternion()
	)

	player.velocity = Vector3.ZERO
	player.global_transform = Transform3D(Basis(rotation), position)


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _quaternion_to_array(value: Quaternion) -> Array[float]:
	return [value.x, value.y, value.z, value.w]


func _array_to_vector(value: Variant, fallback: Vector3) -> Vector3:
	if not value is Array:
		return fallback

	var array: Array = value as Array
	if array.size() != 3:
		return fallback

	return Vector3(
		float(array[0]),
		float(array[1]),
		float(array[2])
	)


func _array_to_quaternion(value: Variant, fallback: Quaternion) -> Quaternion:
	if not value is Array:
		return fallback

	var array: Array = value as Array
	if array.size() != 4:
		return fallback

	return Quaternion(
		float(array[0]),
		float(array[1]),
		float(array[2]),
		float(array[3])
	).normalized()
