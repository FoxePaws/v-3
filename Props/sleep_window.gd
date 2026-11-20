class_name SleepWindow
extends Control

signal closed

@onready var description_label: Label = $Panel/Description
@onready var sleep_button: Button = $Panel/SleepButton
@onready var cancel_button: Button = $Panel/CancelButton

var _player_stats: PlayerStats = null
var _sleep_effect: StatusEffectData = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	sleep_button.text = "Спать"
	cancel_button.text = "Отмена"
	sleep_button.pressed.connect(_on_sleep_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED



func setup(
	stats: PlayerStats,
	effect: StatusEffectData,
	surface_description: String
) -> void:
	_player_stats = stats
	_sleep_effect = effect

	if is_node_ready():
		description_label.text = surface_description


func _on_sleep_pressed() -> void:
	if _player_stats == null or _sleep_effect == null:
		return
	_player_stats.add_status_effect(_sleep_effect)


func _on_cancel_pressed() -> void:
	if _player_stats != null and _sleep_effect != null:
		_player_stats.remove_status_effect(_sleep_effect.effect_id)

	closed.emit()
	queue_free()
