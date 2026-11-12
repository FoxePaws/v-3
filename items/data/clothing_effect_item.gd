class_name ClothingEffectItem
extends ItemInstance


enum ClothingEffectType {
	MOVEMENT_METER,
	MODE_SWITCH
}


@export var clothing_effect_type: ClothingEffectType = (
	ClothingEffectType.MOVEMENT_METER
)

@export_category("Movement meter")
@export_range(0.0, 100.0, 0.1) var meter_gain_per_second: float = 10.0
@export_range(0.0, 100.0, 0.1) var meter_decay_per_second: float = 5.0
@export_range(0.0, 100.0, 0.1) var threshold_1: float = 25.0
@export_range(0.0, 100.0, 0.1) var threshold_2: float = 50.0
@export_range(0.0, 100.0, 0.1) var threshold_3: float = 75.0
@export var movement_effect_1: StatusEffectData
@export var movement_effect_2: StatusEffectData
@export var movement_effect_3: StatusEffectData

@export_category("Mode switch")
@export var mode_effect_1: StatusEffectData
@export var mode_effect_2: StatusEffectData
@export var mode_effect_3: StatusEffectData


var movement_meter: float = 0.0
var active_effect: StatusEffectData = null
var active_player_stats: PlayerStats = null


func _physics_process(delta: float) -> void:
	var equipment: EquipmentComponent = _get_equipment_component()

	if equipment == null or equipment.player == null:
		_remove_active_effect()
		return

	var player: Player = equipment.player

	match clothing_effect_type:
		ClothingEffectType.MOVEMENT_METER:
			_update_movement_meter(delta, player)

		ClothingEffectType.MODE_SWITCH:
			_apply_mode_effect(player.stats)


func _get_equipment_component() -> EquipmentComponent:
	return current_holder as EquipmentComponent


func _update_movement_meter(delta: float, player: Player) -> void:
	var horizontal_velocity: Vector2 = Vector2(
		player.velocity.x,
		player.velocity.z
	)
	var horizontal_speed: float = horizontal_velocity.length()

	if horizontal_speed > 0.1:
		movement_meter += meter_gain_per_second * delta
	else:
		movement_meter -= meter_decay_per_second * delta

	movement_meter = clampf(movement_meter, 0.0, 100.0)

	var next_effect: StatusEffectData = _get_movement_effect()
	_set_active_effect(player.stats, next_effect)


func _get_movement_effect() -> StatusEffectData:
	if movement_meter >= threshold_3:
		return movement_effect_3

	if movement_meter >= threshold_2:
		return movement_effect_2

	if movement_meter >= threshold_1:
		return movement_effect_1

	return null


func on_primary_action() -> void:
	if clothing_effect_type != ClothingEffectType.MODE_SWITCH:
		return

	_change_mode(1)


func on_secondary_action() -> void:
	if clothing_effect_type != ClothingEffectType.MODE_SWITCH:
		return

	_change_mode(-1)


func _change_mode(direction: int) -> void:
	var current_mode: int = int(state.get("clothing_mode", 0))
	var next_mode: int = posmod(current_mode + direction, 4)

	state["clothing_mode"] = next_mode

	# Если одежда надета — применяем новый режим сразу.
	# Если она в руке — режим сохранится, эффект применится при экипировке.
	var equipment: EquipmentComponent = _get_equipment_component()
	if equipment != null and equipment.player != null:
		_apply_mode_effect(equipment.player.stats)


func _apply_mode_effect(stats: PlayerStats) -> void:
	var mode: int = int(state.get("clothing_mode", 0))
	var next_effect: StatusEffectData = null

	match mode:
		1:
			next_effect = mode_effect_1

		2:
			next_effect = mode_effect_2

		3:
			next_effect = mode_effect_3

		_:
			next_effect = null

	_set_active_effect(stats, next_effect)


func _set_active_effect(
	stats: PlayerStats,
	next_effect: StatusEffectData
) -> void:
	if active_effect == next_effect and active_player_stats == stats:
		return

	_remove_active_effect()

	if next_effect == null:
		return

	if stats == null:
		return

	if next_effect.effect_id == &"":
		push_warning(
			"ClothingEffectItem: у StatusEffectData пустой effect_id: "
			+ next_effect.resource_path
		)
		return

	var added: bool = stats.add_status_effect(next_effect)
	if not added:
		push_warning(
			"ClothingEffectItem: PlayerStats не добавил эффект "
			+ str(next_effect.effect_id)
		)
		return

	active_effect = next_effect
	active_player_stats = stats


func _remove_active_effect() -> void:
	if active_effect == null:
		active_player_stats = null
		return

	if is_instance_valid(active_player_stats):
		active_player_stats.remove_status_effect(active_effect.effect_id)

	active_effect = null
	active_player_stats = null


func _exit_tree() -> void:
	_remove_active_effect()
