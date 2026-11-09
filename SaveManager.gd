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
			push_warning(
				"SaveManager: пропущен предмет без ItemData: %s"
				% item.get_path()
			)
			continue

		if item.data.resource_path.is_empty():
			push_warning(
				"SaveManager: у ItemData нет resource_path: %s"
				% item.get_path()
			)
			continue

		records.append(_make_record(item, player))

	var save_path: String = _get_save_path(slot_name)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(SAVE_DIRECTORY)
	)
	if directory_error != OK:
		push_error(
			"SaveManager: не удалось создать каталог сохранений: %s"
			% error_string(directory_error)
		)
		return false

	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error(
			"SaveManager: не удалось открыть файл для записи: %s (%s)"
			% [save_path, error_string(FileAccess.get_open_error())]
		)
		return false

	var player_transform: Transform3D = player.global_transform
	var player_rotation: Quaternion = (
		player_transform.basis.get_rotation_quaternion()
	)

	var save_data: Dictionary = {
		"version": 2,
		"player": {
			"position": _vector_to_array(player_transform.origin),
			"rotation": [
				player_rotation.x,
				player_rotation.y,
				player_rotation.z,
				player_rotation.w,
			],
		},
		"items": records,
		"world_time": _make_world_time_save_data(scene),
		"stats": _make_player_stats_save_data(player),
	}

	file.store_string(JSON.stringify(save_data, "\t"))
	file.flush()

	var write_error: Error = file.get_error()
	file.close()

	if write_error != OK:
		push_error(
			"SaveManager: ошибка записи %s: %s"
			% [save_path, error_string(write_error)]
		)
		return false

	print(
		"SaveManager: сохранено предметов: %d; слот: %s"
		% [records.size(), save_path]
	)
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

	var save_path: String = _get_save_path(slot_name)
	if not FileAccess.file_exists(save_path):
		push_error("SaveManager: файл сохранения не найден: %s" % save_path)
		return false

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error(
			"SaveManager: не удалось открыть файл: %s (%s)"
			% [save_path, error_string(FileAccess.get_open_error())]
		)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(json_text)
	if parse_error != OK:
		push_error(
			"SaveManager: ошибка JSON в строке %d: %s"
			% [json.get_error_line(), json.get_error_message()]
		)
		return false

	var parsed_data: Variant = json.data
	if not parsed_data is Dictionary:
		push_error(
			"SaveManager: корень файла сохранения должен быть Dictionary"
		)
		return false

	var save_data: Dictionary = parsed_data as Dictionary

	var raw_records: Variant = save_data.get("items", [])
	if not raw_records is Array:
		push_error("SaveManager: поле 'items' должно быть Array")
		return false

	var records: Array[Dictionary] = []
	for raw_record: Variant in raw_records:
		if raw_record is Dictionary:
			records.append(raw_record as Dictionary)
		else:
			push_warning("SaveManager: пропущена некорректная запись предмета")

	var raw_player_data: Variant = save_data.get("player", {})
	if not raw_player_data is Dictionary:
		push_error("SaveManager: поле 'player' должно быть Dictionary")
		return false

	var player_data: Dictionary = raw_player_data as Dictionary

	# Предметы удаляются только после чтения и проверки основного JSON.
	await _clear_existing_items(scene, player)
	_restore_player_transform(player, player_data)

	# Сначала создаём все предметы, затем восстанавливаем их расположение.
	var instances: Dictionary[String, ItemInstance] = {}
	var restored_items: Array[ItemInstance] = []
	var item_locations: Array[Dictionary] = []

	for record: Dictionary in records:
		var item: ItemInstance = _create_item_from_record(record)
		if item == null:
			continue

		scene.add_child(item)
		restored_items.append(item)

		var raw_location: Variant = record.get("location", {})
		if raw_location is Dictionary:
			item_locations.append(raw_location as Dictionary)
		else:
			item_locations.append({})

		var instance_id: String = str(
			record.get("instance_id", item.instance_id)
		)
		if not instance_id.is_empty():
			instances[instance_id] = item

	# Даём созданным сценам предметов завершить _ready().
	await get_tree().process_frame

	for index: int in range(restored_items.size()):
		_restore_location(
			restored_items[index],
			item_locations[index],
			instances,
			player,
			scene
		)

	for item: ItemInstance in restored_items:
		item.recalculate_total_weight()

	player.equipment.recalculate_equipment_weight()



	# Время восстанавливаем до эффектов: PlayerStats подключён к сигналу
	# мирового времени основной сцены.
	_restore_world_time_from_save(scene, save_data)

	# Экипировка уже восстановлена. Сначала пересчитываем итоговые
	# максимумы и модификаторы, затем возвращаем текущие ресурсы и эффекты.
	_restore_player_stats_from_save(player, save_data)

	print(
		"SaveManager: восстановлено предметов: %d; слот: %s"
		% [restored_items.size(), save_path]
	)
	return true

func _make_world_time_save_data(scene: Node) -> Dictionary:
	if not scene.has_method("get_world_time_save_data"):
		push_warning(
			"SaveManager: у текущей сцены нет get_world_time_save_data()"
		)
		return {}

	var raw_data: Variant = scene.call("get_world_time_save_data")
	if raw_data is Dictionary:
		return (raw_data as Dictionary).duplicate(true)

	push_warning(
		"SaveManager: get_world_time_save_data() вернул не Dictionary"
	)
	return {}


func _make_player_stats_save_data(player: Player) -> Dictionary:
	var stats_node: Node = player.get_node_or_null("PlayerStats")
	if stats_node == null:
		push_warning("SaveManager: узел PlayerStats не найден")
		return {}

	if not stats_node.has_method("make_save_data"):
		push_warning(
			"SaveManager: у PlayerStats нет метода make_save_data()"
		)
		return {}

	var raw_data: Variant = stats_node.call("make_save_data")
	if not raw_data is Dictionary:
		push_warning(
			"SaveManager: make_save_data() должен возвращать Dictionary"
		)
		return {}

	var stats_data: Dictionary = (raw_data as Dictionary).duplicate(true)

	if stats_node.has_method("make_status_effects_save_data"):
		var raw_effects: Variant = stats_node.call(
			"make_status_effects_save_data"
		)
		if raw_effects is Array:
			stats_data["status_effects"] = (
				raw_effects as Array
			).duplicate(true)
		else:
			push_warning(
				"SaveManager: make_status_effects_save_data() "
				+ "должен возвращать Array"
			)

	return stats_data


func _restore_world_time_from_save(
	scene: Node,
	save_data: Dictionary
) -> void:
	var raw_world_time: Variant = save_data.get("world_time", {})
	if not raw_world_time is Dictionary:
		push_warning(
			"SaveManager: поле 'world_time' отсутствует "
			+ "или имеет неверный тип"
		)
		return

	if not scene.has_method("restore_world_time"):
		push_warning(
			"SaveManager: у текущей сцены нет restore_world_time()"
		)
		return

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
		push_warning(
			"SaveManager: поле 'stats' отсутствует "
			+ "или имеет неверный тип"
		)
		return

	var stats_data: Dictionary = raw_stats as Dictionary

	# Этот вызов должен пересчитать экипировочные модификаторы после
	# восстановления слотов оборудования.
	if stats_node.has_method("recalculate_stats"):
		stats_node.call("recalculate_stats")

	if stats_node.has_method("restore_save_data"):
		stats_node.call("restore_save_data", stats_data)
	else:
		push_warning(
			"SaveManager: у PlayerStats нет restore_save_data()"
		)

	var raw_effects: Variant = stats_data.get("status_effects", [])
	if not stats_node.has_method("restore_status_effects_save_data"):
		if raw_effects is Array and not (raw_effects as Array).is_empty():
			push_warning(
				"SaveManager: у PlayerStats нет "
				+ "restore_status_effects_save_data()"
			)
		return

	stats_node.call("restore_status_effects_save_data", raw_effects)


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
		"instance_id": item.instance_id,
		"durability": item.durability,
		"flags": item.flags.duplicate(true),
		"state": item.state.duplicate(true),
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

func _create_item_from_record(record: Dictionary) -> ItemInstance:
	var data_path: String = str(record.get("item_data_path", ""))
	if data_path.is_empty():
		push_warning("SaveManager: у записи предмета нет item_data_path")
		return null

	var loaded_resource: Resource = load(data_path)
	if loaded_resource == null or not loaded_resource is ItemData:
		push_warning("SaveManager: не удалось загрузить ItemData: %s" % data_path)
		return null

	var item_data: ItemData = loaded_resource as ItemData
	var saved_custom_state: Variant = record.get("state", {})
	var saved_flags: Variant = record.get("flags", {})

	if not saved_custom_state is Dictionary:
		saved_custom_state = {}
	if not saved_flags is Dictionary:
		saved_flags = {}

	var instance_state: Dictionary = {
		"instance_id": str(record.get("instance_id", "")),
		"durability": record.get("durability", item_data.max_durability),
		"flags": (saved_flags as Dictionary).duplicate(true),
		"state": (saved_custom_state as Dictionary).duplicate(true),
	}

	var item: ItemInstance = ItemFactory.create_item(item_data, instance_state)
	if item == null:
		push_warning("SaveManager: ItemFactory не создала предмет из %s" % data_path)
		return null

	return item


func _restore_player_transform(player: Player, player_data: Dictionary) -> void:
	var position: Vector3 = _array_to_vector(
		player_data.get("position", []),
		player.global_position
	)

	var raw_rotation: Variant = player_data.get("rotation", [])
	if not raw_rotation is Array or raw_rotation.size() != 4:
		push_warning("SaveManager: rotation игрока отсутствует или некорректна")
		player.global_position = position
		return

	var rotation_data: Array = raw_rotation as Array
	var rotation: Quaternion = Quaternion(
		float(rotation_data[0]),
		float(rotation_data[1]),
		float(rotation_data[2]),
		float(rotation_data[3])
	).normalized()

	player.velocity = Vector3.ZERO
	player.global_transform = Transform3D(
		Basis(rotation),
		position
	)
