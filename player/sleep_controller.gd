class_name SleepController
extends Node3D

@export var sleep_window_scene: PackedScene
@export var default_sleep_effect: StatusEffectData
@export_multiline var default_surface_description: String = "Обычная поверхность."

@onready var player: Player = get_parent() as Player
@onready var player_stats: PlayerStats = $"../PlayerStats"

var _sleep_window: SleepWindow = null


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"sleep") or event.is_echo():
		return

	if _sleep_window != null and is_instance_valid(_sleep_window):
		return

	var zone: SleepZone = _get_best_sleep_zone()
	var effect: StatusEffectData = default_sleep_effect
	var description: String = default_surface_description

	if zone != null:
		if zone.sleep_effect != null:
			effect = zone.sleep_effect
		if not zone.surface_description.is_empty():
			description = zone.surface_description

	if effect == null:
		push_warning("SleepController: не назначен эффект сна")
		return

	_open_sleep_window(effect, description)
	get_viewport().set_input_as_handled()


func _get_best_sleep_zone() -> SleepZone:
	if player == null:
		return null

	var zones: Array[Node] = get_tree().get_nodes_in_group(&"sleep_zones")
	var best_zone: SleepZone = null

	for node: Node in zones:
		var zone: SleepZone = node as SleepZone
		if zone == null or not is_instance_valid(zone):
			continue
		if not zone.monitoring:
			continue
		if not zone.get_overlapping_bodies().has(player):
			continue

		if best_zone == null or zone.priority > best_zone.priority:
			best_zone = zone

	return best_zone


func _open_sleep_window(
	effect: StatusEffectData,
	description: String
) -> void:
	if sleep_window_scene == null:
		push_warning("SleepController: не назначена sleep_window_scene")
		return

	var instance: Node = sleep_window_scene.instantiate()
	var window: SleepWindow = instance as SleepWindow
	if window == null:
		instance.free()
		push_warning("SleepController: сцена окна должна иметь скрипт SleepWindow")
		return

	get_tree().root.add_child(window)
	_sleep_window = window
	window.setup(player_stats, effect, description)
	window.closed.connect(_on_sleep_window_closed)


func _on_sleep_window_closed() -> void:
	_sleep_window = null
