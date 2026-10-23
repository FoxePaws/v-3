class_name ItemSlotUI
extends Panel

enum SlotKind { HAND, EQUIPMENT, CONTAINER }

@export var slot_kind: SlotKind
@export var slot_id: StringName = &""
@export var slot_index: int = 0

var player: Player
var container: ItemContainer
var item: ItemInstance

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label


func set_item(value: ItemInstance) -> void:
	item = value

	if item == null or item.data == null:
		icon.texture = null
		label.text = ""
		return

	icon.texture = item.data.icon
	label.text = item.data.display_name


func refresh() -> void:
	match slot_kind:
		SlotKind.HAND:
			var hand := _get_hand()
			set_item(hand.held_item if hand != null else null)

		SlotKind.EQUIPMENT:
			if player == null or player.equipment == null:
				set_item(null)
				return

			set_item(player.equipment.get_item(slot_id))

		SlotKind.CONTAINER:
			set_item(container.get_item_at(slot_index) if container != null else null)


func _get_drag_data(_at_position: Vector2) -> Variant:
	refresh()

	if item == null:
		return null

	var preview := TextureRect.new()
	preview.texture = item.data.icon
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	set_drag_preview(preview)

	return {
		"item": item,
		"source": self
	}


func _can_drop_data(_at_position: Vector2, drag_data: Variant) -> bool:
	if not drag_data is Dictionary:
		return false

	var dragged_item := drag_data.get("item") as ItemInstance
	var source := drag_data.get("source") as ItemSlotUI

	if dragged_item == null or source == null or source == self:
		return false

	refresh()

	# Перемещение в занятый слот и обмен предметов пока не поддерживаются.
	if item != null:
		return false

	match slot_kind:
		SlotKind.HAND:
			var hand := _get_hand()
			return hand != null and hand.held_item == null

		SlotKind.EQUIPMENT:
			return (
				player != null
				and player.equipment != null
				and player.equipment.can_equip(dragged_item, slot_id)
			)

		SlotKind.CONTAINER:
			return (
				container != null
				and container.can_accept(dragged_item, slot_index)
			)

	return false


func _drop_data(_at_position: Vector2, drag_data: Variant) -> void:
	if not drag_data is Dictionary:
		return

	var dragged_item := drag_data.get("item") as ItemInstance
	var source := drag_data.get("source") as ItemSlotUI

	if dragged_item == null or source == null:
		return

	if not _can_drop_data(Vector2.ZERO, drag_data):
		return

	if not source._remove_item(dragged_item):
		return

	if not _put_item(dragged_item):
		# Если целевой слот не принял предмет, возвращаем его в исходный слот.
		if not source._put_item(dragged_item):
			push_error("Не удалось вернуть предмет в исходный слот: %s" % dragged_item.name)

	source.refresh()
	refresh()

	if source.slot_kind == SlotKind.CONTAINER and source.container != null:
		source.container.notify_changed()

	if slot_kind == SlotKind.CONTAINER and container != null:
		container.notify_changed()


func _remove_item(target: ItemInstance) -> bool:
	match slot_kind:
		SlotKind.HAND:
			var hand := _get_hand()

			if hand == null or hand.held_item != target:
				return false

			hand.held_item = null
			target.current_holder = null
			target.current_hand = null

			var world := get_tree().current_scene
			if world != null:
				target.reparent(world, true)

			target.enable_collision()
			return true

		SlotKind.EQUIPMENT:
			if player == null or player.equipment == null:
				return false

			if player.equipment.get_item(slot_id) != target:
				return false

			# В этой системе unequip() возвращает снятый ItemInstance.
			var removed_item: ItemInstance = player.equipment.unequip(slot_id)
			return removed_item == target

		SlotKind.CONTAINER:
			return container != null and container.remove_item(target)

	return false


func _put_item(target: ItemInstance) -> bool:
	match slot_kind:
		SlotKind.HAND:
			var hand := _get_hand()

			if hand == null or hand.held_item != null:
				return false

			hand.held_item = target
			target.reparent(hand.held_item_point, false)
			hand._attach_item_to_hand(target)
			target.current_hand = hand
			target.current_holder = hand
			target.disable_collision()
			return true

		SlotKind.EQUIPMENT:
			return (
				player != null
				and player.equipment != null
				and player.equipment.equip(target, slot_id)
			)

		SlotKind.CONTAINER:
			return container != null and container.add_item(target, slot_index)

	return false


func _get_hand() -> HandController:
	if player == null:
		return null

	if slot_index == 0:
		return player.right_hand

	return player.left_hand

func _gui_input(event: InputEvent) -> void:
	if not (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		return

	refresh()

	if item == null or item.data == null:
		return


	var item_container := item.find_child(
		"ItemContainer",
		true,
		false
	) as ItemContainer

	if item_container == null:
		push_warning(
			"У предмета-контейнера %s не найден дочерний узел ItemContainer"
			% item.data.display_name
		)
		return

	if player == null or player.inventory_ui == null:
		push_warning("ItemSlotUI: не найдены Player или InventoryUI")
		return

	player.inventory_ui.open_container(item_container)
	accept_event()
