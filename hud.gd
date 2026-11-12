class_name PlayerHUD
extends CanvasLayer

@export var effect_icon_scene: PackedScene

@onready var status_effects_container: HBoxContainer = \
	$Layout/BottomLeft/StatusEffects
@onready var stamina_bar: StatBarUI = \
	$Layout/BottomLeft/Bars/StaminaBar
@onready var willpower_bar: StatBarUI = \
	$Layout/BottomLeft/Bars/WillpowerBar


var _player_stats: PlayerStats = null


func bind_stats(stats: PlayerStats) -> void:
	if stats == null:
		push_warning("PlayerHUD: PlayerStats не назначен")
		return

	if _player_stats != null:
		if _player_stats.resources_changed.is_connected(
			_on_resources_changed
		):
			_player_stats.resources_changed.disconnect(
				_on_resources_changed
			)

		if _player_stats.status_effects_changed.is_connected(
			_on_status_effects_changed
		):
			_player_stats.status_effects_changed.disconnect(
				_on_status_effects_changed
			)

	_player_stats = stats

	if not _player_stats.resources_changed.is_connected(
		_on_resources_changed
	):
		_player_stats.resources_changed.connect(
			_on_resources_changed
		)

	if not _player_stats.status_effects_changed.is_connected(
		_on_status_effects_changed
	):
		_player_stats.status_effects_changed.connect(
			_on_status_effects_changed
		)

	_refresh_resources()
	_refresh_status_effects()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_hud"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _on_resources_changed(
	_current_willpower: float,
	_max_willpower: float,
	_current_stamina: float,
	_max_stamina: float
) -> void:
	_refresh_resources()


func _on_status_effects_changed() -> void:
	_refresh_status_effects()


func _refresh_resources() -> void:
	if _player_stats == null:
		return

	stamina_bar.set_stat(
		"Stamina",
		_player_stats.current_stamina,
		_player_stats.max_stamina
	)

	willpower_bar.set_stat(
		"Willpower",
		_player_stats.current_willpower,
		_player_stats.max_willpower
	)


func _refresh_status_effects() -> void:
	if _player_stats == null:
		return

	update_status_effects(_player_stats.active_status_effects)


func update_status_effects(effects: Array[Dictionary]) -> void:
	for child: Node in status_effects_container.get_children():
		status_effects_container.remove_child(child)
		child.queue_free()

	if effect_icon_scene == null:
		push_warning("PlayerHUD: effect_icon_scene не назначена")
		return

	for effect: Dictionary in effects:
		var effect_icon: StatusEffectIcon = \
			effect_icon_scene.instantiate() as StatusEffectIcon

		if effect_icon == null:
			push_warning(
				"PlayerHUD: сцена значка не содержит StatusEffectIcon"
			)
			continue

		var icon_path: String = str(effect.get("icon_path", ""))
		var icon: Texture2D = null

		if not icon_path.is_empty():
			icon = load(icon_path) as Texture2D

		var effect_name: String = str(
			effect.get("display_name", effect.get("effect_id", "Эффект"))
		)
		var effect_description: String = str(
			effect.get("description", "")
		)

		status_effects_container.add_child(effect_icon)
		effect_icon.setup(icon, effect_name, effect_description)
