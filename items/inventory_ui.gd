class_name InventoryUI
extends CanvasLayer

@export var container_window_scene: PackedScene
@export var hand_slots: Array[ItemSlotUI] = []
@export var equipment_slots: Array[ItemSlotUI] = []

@onready var player_window: Control = $PlayerWindow
@onready var player_close_button: Button = $PlayerWindow/CloseButton

var player: Player

# Ключ — ItemContainer, значение — окно этого контейнера.
var container_windows: Dictionary = {}


func _ready() -> void:
	player_window.hide()

	if not player_close_button.pressed.is_connected(close_player_ui):
		player_close_button.pressed.connect(close_player_ui)


func setup(new_player: Player) -> void:
	player = new_player
	refresh_player_ui()


# Совместимость со старым вызовом inventory_ui.close_ui().
func close_ui() -> void:
	close_player_ui()


func toggle_player_ui() -> void:
	if player_window.visible:
		close_player_ui()
	else:
		open_player_ui()


func open_container(container: ItemContainer) -> void:
	if container == null:
		return

	if container_window_scene == null:
		push_error("InventoryUI: назначьте container_window_scene в Inspector")
		return

	var window := container_windows.get(container) as Control

	if window == null or not is_instance_valid(window):
		window = container_window_scene.instantiate() as Control

		if window == null:
			push_error(
				"Корень сцены окна контейнера должен наследоваться от Control"
			)
			return

		add_child(window)
		container_windows[container] = window

		if window.has_signal("closed"):
			var callback := Callable(self, "_on_container_window_closed")
			if not window.is_connected("closed", callback):
				window.connect("closed", callback)

		window.call("setup", container, player)
		_place_container_window(window)

	window.show()
	window.call("refresh")
	window.move_to_front()

	_layout_open_windows()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _place_container_window(window: Control) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := window.size

	if window_size == Vector2.ZERO:
		window_size = window.get_combined_minimum_size()

	if window_size == Vector2.ZERO:
		window_size = Vector2(320.0, 240.0)

	var gap := Vector2(12.0, 12.0)
	var step := window_size + gap

	var columns := maxi(
		1,
		int((viewport_size.x + gap.x) / step.x)
	)

	var visible_count := 0
	for value in container_windows.values():
		var existing := value as Control
		if existing != null and is_instance_valid(existing) and existing.visible:
			visible_count += 1

	# При создании нового окна оно ещё не показано,
	# поэтому видимые окна определяют его позицию.
	var column := visible_count % columns
	var row := int(visible_count / columns)

	var max_x := maxf(0.0, viewport_size.x - window_size.x)
	var max_y := maxf(0.0, viewport_size.y - window_size.y)

	window.position = Vector2(
		minf(column * step.x, max_x),
		minf(row * step.y, max_y)
	)



func is_ui_open() -> bool:
	if player_window.visible:
		return true

	for value in container_windows.values():
		var window := value as Control
		if window != null and is_instance_valid(window) and window.visible:
			return true

	return false


func close_all_container_windows() -> void:
	for value in container_windows.values():
		var window := value as Control
		if window != null and is_instance_valid(window):
			window.call("close_window")

	_layout_open_windows()
	_update_mouse_mode()


func refresh_player_ui() -> void:
	for slot in hand_slots:
		if slot != null:
			slot.player = player
			slot.refresh()

	for slot in equipment_slots:
		if slot != null:
			slot.player = player
			slot.refresh()


func _on_container_window_closed() -> void:
	_update_mouse_mode()


func _update_mouse_mode() -> void:
	if is_ui_open():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _layout_open_windows() -> void:
	var windows: Array[Control] = []

	# Сначала размещаем окно игрока, если оно открыто.
	if player_window.visible:
		windows.append(player_window)

	for value in container_windows.values():
		var window := value as Control
		if window != null and is_instance_valid(window) and window.visible:
			windows.append(window)

	var viewport_size := get_viewport().get_visible_rect().size
	var gap := 12.0

	# Берём максимальные размеры, чтобы сетка подходила всем окнам.
	var cell_size := Vector2.ZERO
	for window in windows:
		var window_size := window.size
		if window_size == Vector2.ZERO:
			window_size = window.get_combined_minimum_size()
		cell_size.x = maxf(cell_size.x, window_size.x)
		cell_size.y = maxf(cell_size.y, window_size.y)

	if cell_size == Vector2.ZERO:
		return

	var step := cell_size + Vector2(gap, gap)
	var columns := maxi(1, int((viewport_size.x + gap) / step.x))

	for i in range(windows.size()):
		var column := i % columns
		var row := int(i / columns)
		var window := windows[i]
		var window_size := window.size

		if window_size == Vector2.ZERO:
			window_size = window.get_combined_minimum_size()

		window.position = Vector2(
			minf(column * step.x, maxf(0.0, viewport_size.x - window_size.x)),
			minf(row * step.y, maxf(0.0, viewport_size.y - window_size.y))
		)

func open_player_ui() -> void:
	player_window.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_player_ui()
	_layout_open_windows()


func close_player_ui() -> void:
	player_window.hide()
	_layout_open_windows()
	_update_mouse_mode()
