class_name EquipmentComponent
extends Node

@export var slot_ids: Array[StringName] = [
	&"head",
	&"mask",
	&"suit",
	&"back",
	&"belt",
	&"Shirt"
]

@export var skeleton: Skeleton3D
@export var clothing_visuals: ClothingVisuals

@export var body_mesh: MeshInstance3D
@export var head_mesh: MeshInstance3D
@export var sweater_mesh: MeshInstance3D

var slots: Dictionary = {}
var player: Player

# Mesh instance ID -> { shape name -> original value }
var _base_shape_values: Dictionary = {}


func _ready() -> void:
	for slot_id in slot_ids:
		slots[slot_id] = null

	_cache_base_shape_values(body_mesh)
	_cache_base_shape_values(head_mesh)
	_cache_base_shape_values(sweater_mesh)


func get_item(slot_id: StringName) -> ItemInstance:
	return slots.get(slot_id) as ItemInstance


func can_equip(item: ItemInstance, slot_id: StringName) -> bool:
	return (
		item != null
		and item.data != null
		and slots.has(slot_id)
		and item.data.equipment_slot == slot_id
		and slots[slot_id] == null
	)


func _get_bone_attachment(bone_name: StringName) -> BoneAttachment3D:
	if skeleton == null:
		return null

	for child in skeleton.get_children():
		var attachment := child as BoneAttachment3D
		if attachment != null and attachment.bone_name == bone_name:
			return attachment

	return null


func _set_clothing_visible(visual_id: StringName, value: bool) -> void:
	if visual_id == &"":
		return

	var visuals := clothing_visuals
	if visuals == null and player != null:
		visuals = player.get_node_or_null("ClothingVisuals") as ClothingVisuals

	if visuals == null:
		push_warning("EquipmentComponent: ClothingVisuals не назначен")
		return

	visuals.set_visible(visual_id, value)


func _attach_to_bone(item: ItemInstance) -> bool:
	if item == null or item.data == null:
		return false

	var bone_attachment := _get_bone_attachment(item.data.bone_name)
	if bone_attachment == null:
		push_warning("Не найдена точка крепления для кости: %s" % item.data.bone_name)
		return false

	var attach_point := item.get_node_or_null("AttachPoint") as Marker3D
	if attach_point == null:
		push_warning("У предмета %s нет Marker3D AttachPoint" % item.data.display_name)
		return false

	item.disable_collision()
	item.reparent(bone_attachment, false)
	item.global_transform = bone_attachment.global_transform * attach_point.transform.affine_inverse()
	return true


func equip(item: ItemInstance, slot_id: StringName) -> bool:
	if not can_equip(item, slot_id):
		return false

	if item.data.item_type == ItemData.ItemType.CLOTHING:
		if player == null:
			push_warning("EquipmentComponent: player не назначен")
			return false

		item.reparent(player, true)
		item.disable_collision()
		item.visible = false

	elif item.data.item_type == ItemData.ItemType.EQUIPMENT:
		if not _attach_to_bone(item):
			return false
	else:
		return false

	slots[slot_id] = item
	item.current_holder = self
	item.current_hand = null

	_refresh_clothing_visibility()
	refresh_equipment_blend_shapes()

	if player != null:
		player.recalculate_equipment_stats()

	return true


func unequip(slot_id: StringName) -> ItemInstance:
	var item := get_item(slot_id)
	if item == null:
		return null

	slots[slot_id] = null

	var scene_root := get_tree().current_scene
	if scene_root != null:
		item.reparent(scene_root, true)

	item.visible = true
	item.current_holder = null
	item.current_hand = null
	item.enable_collision()

	_refresh_clothing_visibility()
	refresh_equipment_blend_shapes()

	if player != null:
		player.recalculate_equipment_stats()

	return item

func _refresh_clothing_visibility() -> void:
	var visuals := clothing_visuals
	if visuals == null and player != null:
		visuals = player.get_node_or_null("ClothingVisuals") as ClothingVisuals

	if visuals == null:
		push_warning("EquipmentComponent: ClothingVisuals не назначен")
		return

	# Сбрасываем визуалы, в том числе визуал только что снятой вещи.
	visuals.hide_all()

	var hidden_visuals: Dictionary = {}

	for slot_value: Variant in slots.values():
		var item := slot_value as ItemInstance
		if item == null or item.data == null:
			continue
		if item.data.item_type != ItemData.ItemType.CLOTHING:
			continue

		for visual_id in item.data.hide_clothing_visuals:
			hidden_visuals[visual_id] = true

	for slot_value: Variant in slots.values():
		var item := slot_value as ItemInstance
		if item == null or item.data == null:
			continue
		if item.data.item_type != ItemData.ItemType.CLOTHING:
			continue

		var visual_id: StringName = item.data.clothing_visual_id
		if visual_id == &"" or hidden_visuals.has(visual_id):
			continue

		visuals.set_visible(visual_id, true)


func refresh_equipment_blend_shapes() -> void:
	_restore_base_shape_values(body_mesh)
	_restore_base_shape_values(head_mesh)
	_restore_base_shape_values(sweater_mesh)

	var body_settings := _collect_winning_settings(&"body_shape_keys")
	var head_settings := _collect_winning_settings(&"head_shape_keys")
	var sweater_settings := _collect_winning_settings(&"sweater_shape_keys")

	_apply_winning_settings(body_mesh, body_settings)
	_apply_winning_settings(head_mesh, head_settings)
	_apply_winning_settings(sweater_mesh, sweater_settings)


# Для каждого shape name сохраняет настройку с наибольшим priority.
# При равном приоритете более поздняя настройка заменяет предыдущую.
func _collect_winning_settings(property_name: StringName) -> Dictionary:
	var winners: Dictionary = {}

	for slot_id in slot_ids:
		var item := get_item(slot_id)
		if item == null or item.data == null:
			continue

		var settings: Array = item.data.get(property_name)
		for setting_value in settings:
			var setting := setting_value as BlendShapeSetting
			if setting == null or setting.shape_name == &"":
				continue

			var existing: BlendShapeSetting = winners.get(setting.shape_name) as BlendShapeSetting
			if existing == null or setting.priority >= existing.priority:
				winners[setting.shape_name] = setting

	return winners


func _cache_base_shape_values(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return

	var shape_values: Dictionary = {}

	for shape_index in range(mesh_instance.mesh.get_blend_shape_count()):
		var shape_name :StringName= mesh_instance.mesh.get_blend_shape_name(shape_index)
		shape_values[shape_name] = mesh_instance.get_blend_shape_value(shape_index)

	_base_shape_values[mesh_instance.get_instance_id()] = shape_values


func _restore_base_shape_values(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return

	var mesh_id := mesh_instance.get_instance_id()
	if not _base_shape_values.has(mesh_id):
		return

	var shape_values: Dictionary = _base_shape_values[mesh_id]

	for shape_index in range(mesh_instance.mesh.get_blend_shape_count()):
		var shape_name :StringName= mesh_instance.mesh.get_blend_shape_name(shape_index)
		if shape_values.has(shape_name):
			mesh_instance.set_blend_shape_value(
				shape_index,
				shape_values[shape_name]
			)


func _apply_winning_settings(
	mesh_instance: MeshInstance3D,
	winners: Dictionary
) -> void:
	if mesh_instance == null or mesh_instance.mesh == null:
		return

	var mesh: Mesh = mesh_instance.mesh

	for shape_name: StringName in winners:
		var setting := winners[shape_name] as BlendShapeSetting
		var shape_index := -1

		for index in range(mesh.get_blend_shape_count()):
			if mesh.get_blend_shape_name(index) == shape_name:
				shape_index = index
				break

		if shape_index == -1:
			push_warning(
				"Не найден shape key '%s' на меше '%s'"
				% [shape_name, mesh_instance.name]
			)
			continue

		mesh_instance.set_blend_shape_value(shape_index, setting.value)
