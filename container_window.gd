class_name ContainerWindow
extends Panel

signal closed

@export var slot_scene: PackedScene

@onready var title_label: Label = $Header/Title
@onready var close_button: Button = $Header/CloseButton
@onready var slots_grid: GridContainer = $Slots

var player: Player
var container: ItemContainer


func _ready() -> void:
	close_button.pressed.connect(close_window)


func setup(new_container: ItemContainer, new_player: Player) -> void:
	container = new_container
	player = new_player

	if is_node_ready():
		_setup_window()


func _setup_window() -> void:
	if container == null:
		return

	title_label.text = _get_container_name()
	_create_slots_once()
	refresh()

	if not container.changed.is_connected(refresh):
		container.changed.connect(refresh)


func _get_container_name() -> String:
	var container_item := container.get_parent() as ItemInstance
	if container_item != null and container_item.data != null:
		return container_item.data.display_name

	return "Container"


func _create_slots_once() -> void:
	if slot_scene == null:
		push_error("ContainerWindow: назначьте slot_scene в Inspector")
		return

	if slots_grid.get_child_count() > 0:
		return

	for i in range(container.items.size()):
		var slot := slot_scene.instantiate() as ItemSlotUI
		if slot == null:
			push_error("Сцена слота должна иметь корень ItemSlotUI")
			return

		slot.slot_kind = ItemSlotUI.SlotKind.CONTAINER
		slot.slot_index = i
		slot.container = container
		slot.player = player
		slots_grid.add_child(slot)


func refresh() -> void:
	if container == null:
		return

	for i in range(slots_grid.get_child_count()):
		var slot := slots_grid.get_child(i) as ItemSlotUI
		if slot != null:
			slot.container = container
			slot.player = player
			slot.slot_index = i
			slot.refresh()


func close_window() -> void:
	hide()
	closed.emit()
