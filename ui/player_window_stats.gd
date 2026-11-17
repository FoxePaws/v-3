class_name PlayerWindowStats
extends VBoxContainer

@onready var stamina_recovery_label: Label = $StaminaRecoveryLabel
@onready var willpower_recovery_label: Label = $WillpowerRecoveryLabel
@onready var walk_speed_label: Label = $WalkSpeedLabel
@onready var sprint_speed_label: Label = $SprintSpeedLabel
@onready var jump_velocity_label: Label = $JumpVelocityLabel
@onready var weight_label: Label = $WeightLabel

@onready var satiety_bar: StatBarUI = \
	$"../NeedsBars/SatietyBar"
@onready var thirst_bar: StatBarUI = \
	$"../NeedsBars/ThirstBar"

var _stats: PlayerStats = null


func setup(stats: PlayerStats) -> void:
	if stats == null:
		push_warning("PlayerWindowStats: PlayerStats не назначен")
		return

	if _stats != null:
		if _stats.stats_recalculated.is_connected(_refresh_stats):
			_stats.stats_recalculated.disconnect(_refresh_stats)
		if _stats.resources_changed.is_connected(_refresh_stats):
			_stats.resources_changed.disconnect(_refresh_stats)
		if _stats.needs_changed.is_connected(_refresh_needs):
			_stats.needs_changed.disconnect(_refresh_needs)

	_stats = stats

	if not _stats.stats_recalculated.is_connected(_refresh_stats):
		_stats.stats_recalculated.connect(_refresh_stats)
	if not _stats.resources_changed.is_connected(_refresh_stats):
		_stats.resources_changed.connect(_refresh_stats)
	if not _stats.needs_changed.is_connected(_refresh_needs):
		_stats.needs_changed.connect(_refresh_needs)

	_refresh_stats()
	_refresh_needs()

func _refresh_stats(
	_current_willpower: float = 0.0,
	_max_willpower: float = 0.0,
	_current_stamina: float = 0.0,
	_max_stamina: float = 0.0
) -> void:
	if _stats == null:
		return

	stamina_recovery_label.text = "Восстановление стамины: %.1f/с" % _stats.stamina_recovery
	willpower_recovery_label.text = "Восстановление силы воли: %.1f/с" % _stats.willpower_recovery
	walk_speed_label.text = "Скорость ходьбы: %.2f" % _stats.walk_speed
	sprint_speed_label.text = "Скорость бега: %.2f" % _stats.sprint_speed
	jump_velocity_label.text = "Сила прыжка: %.2f" % _stats.jump_velocity
	weight_label.text = "Вес: %.2f / %.2f кг" % [
		_stats.equipment_weight,
		_stats.max_carry_weight,
	]


func _refresh_needs(
	_current_satiety: float = 0.0,
	_max_satiety: float = 0.0,
	_current_thirst: float = 0.0,
	_max_thirst: float = 0.0
) -> void:
	if _stats == null:
		return

	satiety_bar.set_stat(
		"СЫТОСТЬ",
		_stats.current_satiety,
		_stats.max_satiety
	)
	thirst_bar.set_stat(
		"ЖАЖДА",
		_stats.current_thirst,
		_stats.max_thirst
	)
