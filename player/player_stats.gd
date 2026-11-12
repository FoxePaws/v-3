class_name PlayerStats
extends Node

signal resources_changed(
	current_willpower: float,
	max_willpower: float,
	current_stamina: float,
	max_stamina: float
)
signal stats_recalculated()
signal status_effects_changed()

signal needs_changed(
	current_satiety: float,
	max_satiety: float,
	current_thirst: float,
	max_thirst: float
)


@export_category("Base resources")
@export_range(0.0, 100000.0, 0.1) var base_max_willpower: float = 100.0
@export_range(0.0, 100000.0, 0.1) var base_max_stamina: float = 100.0
@export_range(0.0, 100000.0, 0.1) var base_stamina_threshold: float = 0.0

@export_category("Base movement")
@export var base_walk_speed: float = 4.0
@export var base_sprint_speed: float = 7.0
@export var base_jump_velocity: float = 5.0

@export_category("Recovery")
@export_range(0.0, 100000.0, 0.1) var base_willpower_recovery: float = 0.0
@export_range(0.0, 100000.0, 0.1) var base_stamina_recovery: float = 20.0
@export var recovery_delay: float = 0.75

@export_category("Costs")
@export_range(0.0, 1000.0, 0.01) var base_stamina_cost_multiplier: float = 1.0
@export_range(0.0, 1000.0, 0.01) var base_willpower_cost_multiplier: float = 1.0
@export_range(0.0, 1000.0, 0.01) var exhaustion_willpower_multiplier: float = 1.0
@export_range(0.0, 100000.0, 0.1) var sprint_stamina_per_second: float = 12.0
@export_range(0.0, 100000.0, 0.1) var jump_stamina_cost: float = 15.0

@export_category("Exhaustion penalties")
@export_range(0.0, 1.0, 0.01) var exhausted_walk_multiplier: float = 0.5
@export_range(0.0, 1.0, 0.01) var exhausted_sprint_multiplier: float = 0.5
@export_range(0.0, 1.0, 0.01) var exhausted_jump_multiplier: float = 0.5

@export_category("Carried weight")
@export_range(0.1, 10000.0, 0.1) var max_carry_weight: float = 30.0
@export_range(0.0, 1.0, 0.01) var max_walk_weight_penalty: float = 0.25
@export_range(0.0, 1.0, 0.01) var max_sprint_weight_penalty: float = 0.25
@export_range(0.0, 1.0, 0.01) var max_jump_weight_penalty: float = 0.25
@export_range(0.0, 10.0, 0.01) var max_stamina_cost_weight_penalty: float = 0.25

@export_category("Survival needs")
@export_range(0.0, 100000.0, 0.1)
var base_max_satiety: float = 100.0
@export_range(0.0, 100000.0, 0.1)
var base_max_thirst: float = 100.0
@export_range(0.0, 100000.0, 0.001)
var satiety_loss_per_world_second: float = 0.01
@export_range(0.0, 100000.0, 0.001)
var thirst_loss_per_world_second: float = 0.02
@export_range(0.0, 1000.0, 0.01)
var satiety_restoration_multiplier: float = 1.0
@export_range(0.0, 1000.0, 0.01)
var thirst_restoration_multiplier: float = 1.0

@export_category("Survival penalties")

@export_range(0.0, 1.0, 0.01)
var max_satiety_walk_penalty: float = 0.10
@export_range(0.0, 1.0, 0.01)
var max_satiety_sprint_penalty: float = 0.20
@export_range(0.0, 1.0, 0.01)
var max_satiety_jump_penalty: float = 0.10
@export_range(0.0, 10.0, 0.01)
var max_satiety_stamina_cost_penalty: float = 0.25
@export_range(0.0, 1.0, 0.01)
var max_satiety_stamina_recovery_penalty: float = 0.50

@export_range(0.0, 1.0, 0.01)
var max_thirst_walk_penalty: float = 0.15
@export_range(0.0, 1.0, 0.01)
var max_thirst_sprint_penalty: float = 0.25
@export_range(0.0, 1.0, 0.01)
var max_thirst_jump_penalty: float = 0.10
@export_range(0.0, 10.0, 0.01)
var max_thirst_stamina_cost_penalty: float = 0.50
@export_range(0.0, 1.0, 0.01)
var max_thirst_stamina_recovery_penalty: float = 0.75


var equipment_weight: float = 0.0

var current_satiety: float = 100.0
var current_thirst: float = 100.0
var max_satiety: float = 100.0
var max_thirst: float = 100.0



var current_willpower: float = 100.0
var current_stamina: float = 100.0

var max_willpower: float = 100.0
var max_stamina: float = 100.0
var stamina_threshold: float = 0.0

var walk_speed: float = 4.0
var sprint_speed: float = 7.0
var jump_velocity: float = 5.0
var willpower_recovery: float = 0.0
var stamina_recovery: float = 20.0
var stamina_cost_multiplier: float = 1.0
var willpower_cost_multiplier: float = 1.0

var _recovery_timer: float = 0.0
var _equipment_modifiers: Dictionary = {}
var _status_modifiers: Dictionary = {}

var active_status_effects: Array[Dictionary] = []
var _world_clock: Node = null

func _ready() -> void:
	current_willpower = clampf(current_willpower, 0.0, base_max_willpower)
	current_stamina = clampf(current_stamina, 0.0, base_max_stamina)
	max_satiety = base_max_satiety
	max_thirst = base_max_thirst
	current_satiety = max_satiety
	current_thirst = max_thirst
	recalculate_stats()
	_connect_world_clock()


func _connect_world_clock() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	_world_clock = scene
	var callback: Callable = _on_world_time_advanced

	if _world_clock.has_signal("world_time_advanced"):
		if not _world_clock.is_connected("world_time_advanced", callback):
			_world_clock.connect("world_time_advanced", callback)
	else:
		push_warning(
			"PlayerStats: current scene не предоставляет world_time_advanced"
		)

func _process(_delta: float) -> void:
	# Восстановление и таймеры идут через world_time_advanced,
	# чтобы time_scale влиял на них так же, как на игровой календарь.
	pass

func set_equipment_weight(weight: float) -> void:
	var clamped_weight: float = maxf(weight, 0.0)
	if is_equal_approx(equipment_weight, clamped_weight):
		return

	equipment_weight = clamped_weight
	recalculate_stats()


func _on_world_time_advanced(delta_world_seconds: float) -> void:
	if delta_world_seconds <= 0.0:
		return

	var effects_changed: bool = false

	for index: int in range(active_status_effects.size() - 1, -1, -1):
		var effect: Dictionary = active_status_effects[index]
		var remaining: float = float(
			effect.get("remaining_world_seconds", 0.0)
		) - delta_world_seconds

		if remaining <= 0.0:
			active_status_effects.remove_at(index)
			effects_changed = true
		else:
			effect["remaining_world_seconds"] = remaining
			active_status_effects[index] = effect

	if effects_changed:
		_recalculate_status_modifiers()

	var needs_changed_local: bool = false

	if current_satiety > 0.0:
		var new_satiety: float = maxf(
			current_satiety
			- satiety_loss_per_world_second * delta_world_seconds,
			0.0
		)
		if not is_equal_approx(current_satiety, new_satiety):
			current_satiety = new_satiety
			needs_changed_local = true

	if current_thirst > 0.0:
		var new_thirst: float = maxf(
			current_thirst
			- thirst_loss_per_world_second * delta_world_seconds,
			0.0
		)
		if not is_equal_approx(current_thirst, new_thirst):
			current_thirst = new_thirst
			needs_changed_local = true

	if needs_changed_local:
		_emit_needs_changed()


	if _recovery_timer > 0.0:
		_recovery_timer = maxf(
			_recovery_timer - delta_world_seconds,
			0.0
		)
		return

	var resources_changed: bool = false

	if current_stamina < max_stamina:
		current_stamina = minf(
			current_stamina + stamina_recovery * delta_world_seconds,
			max_stamina
		)
		resources_changed = true

	if current_willpower < max_willpower and willpower_recovery > 0.0:
		current_willpower = minf(
			current_willpower + willpower_recovery * delta_world_seconds,
			max_willpower
		)
		resources_changed = true

	if resources_changed:
		_emit_resources_changed()

func restore_satiety(base_amount: float) -> void:
	if base_amount <= 0.0:
		return

	current_satiety = clampf(
		current_satiety
		+ base_amount * satiety_restoration_multiplier,
		0.0,
		max_satiety
	)
	_emit_needs_changed()


func restore_thirst(base_amount: float) -> void:
	if base_amount <= 0.0:
		return

	current_thirst = clampf(
		current_thirst
		+ base_amount * thirst_restoration_multiplier,
		0.0,
		max_thirst
	)
	_emit_needs_changed()


func _emit_needs_changed() -> void:
	needs_changed.emit(
		current_satiety,
		max_satiety,
		current_thirst,
		max_thirst
	)




func is_exhausted() -> bool:
	return current_stamina <= stamina_threshold


func is_willpower_depleted() -> bool:
	return current_willpower <= 0.0


func get_walk_speed() -> float:
	var result: float = walk_speed
	if is_exhausted():
		result *= exhausted_walk_multiplier
	return maxf(result, 0.0)


func get_sprint_speed() -> float:
	var result: float = sprint_speed
	if is_exhausted():
		result *= exhausted_sprint_multiplier
	return maxf(result, 0.0)


func get_jump_velocity() -> float:
	var result: float = jump_velocity
	if is_exhausted():
		result *= exhausted_jump_multiplier
	return maxf(result, 0.0)


# Возвращает true, если затрата принята.
# Выносливость не опускается ниже порога; нехватка конвертируется в силу воли.
func consume_stamina(base_cost: float) -> bool:
	if base_cost <= 0.0:
		return true

	var cost: float = base_cost * stamina_cost_multiplier
	var available_stamina: float = maxf(current_stamina - stamina_threshold, 0.0)
	var stamina_paid: float = minf(cost, available_stamina)
	var uncovered_cost: float = cost - stamina_paid
	var willpower_cost: float = (
		uncovered_cost
		* exhaustion_willpower_multiplier
		* willpower_cost_multiplier
	)

	if willpower_cost > current_willpower:
		# Не допускаем действия, которое должно было бы опустить силу воли ниже нуля.
		current_willpower = 0.0
		current_stamina -= stamina_paid
		_recovery_timer = recovery_delay
		_emit_resources_changed()
		return false

	current_stamina -= stamina_paid
	current_willpower -= willpower_cost
	_recovery_timer = recovery_delay
	_emit_resources_changed()
	return true


func restore_willpower(amount: float) -> void:
	if amount <= 0.0:
		return
	current_willpower = minf(current_willpower + amount, max_willpower)
	_emit_resources_changed()


func restore_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	current_stamina = minf(current_stamina + amount, max_stamina)
	_emit_resources_changed()


# Формат модификаторов:
# {"max_stamina_add": 10.0, "walk_speed_multiplier": 1.1, ...}
# Значения оборудования и эффектов складываются для *_add,
# складываются относительно 1 для *_multiplier.
func set_equipment_modifiers(modifiers: Dictionary) -> void:
	_equipment_modifiers = modifiers.duplicate(true)
	recalculate_stats()


func set_status_modifiers(modifiers: Dictionary) -> void:
	_status_modifiers = modifiers.duplicate(true)
	recalculate_stats()


func recalculate_stats() -> void:
	var all_modifiers: Dictionary = {}

	_merge_modifiers(all_modifiers, _equipment_modifiers)
	_merge_modifiers(all_modifiers, _status_modifiers)

	max_willpower = maxf(
		0.0,
		(base_max_willpower + _add_value(all_modifiers, "max_willpower_add"))
		* _multiplier_value(all_modifiers, "max_willpower_multiplier")
	)
	max_stamina = maxf(
		0.0,
		(base_max_stamina + _add_value(all_modifiers, "max_stamina_add"))
		* _multiplier_value(all_modifiers, "max_stamina_multiplier")
	)
	stamina_threshold = clampf(
		base_stamina_threshold + _add_value(all_modifiers, "stamina_threshold_add"),
		0.0,
		max_stamina
	)

	walk_speed = maxf(
		0.0,
		(base_walk_speed + _add_value(all_modifiers, "walk_speed_add"))
		* _multiplier_value(all_modifiers, "walk_speed_multiplier")
	)
	sprint_speed = maxf(
		0.0,
		(base_sprint_speed + _add_value(all_modifiers, "sprint_speed_add"))
		* _multiplier_value(all_modifiers, "sprint_speed_multiplier")
	)
	jump_velocity = maxf(
		0.0,
		(base_jump_velocity + _add_value(all_modifiers, "jump_velocity_add"))
		* _multiplier_value(all_modifiers, "jump_velocity_multiplier")
	)

	stamina_recovery = maxf(
		0.0,
		(base_stamina_recovery + _add_value(all_modifiers, "stamina_recovery_add"))
		* _multiplier_value(all_modifiers, "stamina_recovery_multiplier")
	)
	willpower_recovery = maxf(
		0.0,
		(base_willpower_recovery + _add_value(all_modifiers, "willpower_recovery_add"))
		* _multiplier_value(all_modifiers, "willpower_recovery_multiplier")
	)
	stamina_cost_multiplier = maxf(
		0.0,
		(base_stamina_cost_multiplier + _add_value(all_modifiers, "stamina_cost_multiplier_add"))
		* _multiplier_value(all_modifiers, "stamina_cost_multiplier_multiplier")
	)
	willpower_cost_multiplier = maxf(
		0.0,
		(base_willpower_cost_multiplier + _add_value(all_modifiers, "willpower_cost_multiplier_add"))
		* _multiplier_value(all_modifiers, "willpower_cost_multiplier_multiplier")
	)

	var safe_max_carry_weight: float = maxf(max_carry_weight, 0.01)
	var load_ratio: float = clampf(
		equipment_weight / safe_max_carry_weight,
		0.0,
		1.0
	)
	var load_factor: float = load_ratio * load_ratio

	var satiety_factor: float = _get_need_penalty_factor(
		current_satiety,
		max_satiety
	)
	var thirst_factor: float = _get_need_penalty_factor(
		current_thirst,
		max_thirst
	)

	walk_speed *= 1.0 - max_walk_weight_penalty * load_factor
	sprint_speed *= 1.0 - max_sprint_weight_penalty * load_factor
	jump_velocity *= 1.0 - max_jump_weight_penalty * load_factor
	stamina_cost_multiplier *= (
		1.0 + max_stamina_cost_weight_penalty * load_factor
	)

	walk_speed *= 1.0 - max_satiety_walk_penalty * satiety_factor
	sprint_speed *= 1.0 - max_satiety_sprint_penalty * satiety_factor
	jump_velocity *= 1.0 - max_satiety_jump_penalty * satiety_factor
	stamina_cost_multiplier *= (
		1.0 + max_satiety_stamina_cost_penalty * satiety_factor
	)
	stamina_recovery *= (
		1.0
		- max_satiety_stamina_recovery_penalty * satiety_factor
	)

	walk_speed *= 1.0 - max_thirst_walk_penalty * thirst_factor
	sprint_speed *= 1.0 - max_thirst_sprint_penalty * thirst_factor
	jump_velocity *= 1.0 - max_thirst_jump_penalty * thirst_factor
	stamina_cost_multiplier *= (
		1.0 + max_thirst_stamina_cost_penalty * thirst_factor
	)
	stamina_recovery *= (
		1.0
		- max_thirst_stamina_recovery_penalty * thirst_factor
	)



	current_willpower = clampf(current_willpower, 0.0, max_willpower)
	current_stamina = clampf(current_stamina, 0.0, max_stamina)

	stats_recalculated.emit()
	_emit_resources_changed()


func _get_need_penalty_factor(
	current_value: float,
	maximum_value: float
) -> float:
	if maximum_value <= 0.0:
		return 0.0

	var ratio: float = clampf(current_value / maximum_value, 0.0, 1.0)
	var deficit_below_half: float = clampf(
		(0.5 - ratio) / 0.5,
		0.0,
		1.0
	)

	return deficit_below_half * deficit_below_half


func make_save_data() -> Dictionary:
	return {
		"current_satiety": current_satiety,
		"current_thirst": current_thirst,
		"current_willpower": current_willpower,
		"current_stamina": current_stamina,
		"recovery_timer": _recovery_timer,
	}


func restore_save_data(data: Dictionary) -> void:
	current_willpower = clampf(
		float(data.get("current_willpower", max_willpower)),
		0.0,
		max_willpower
	)
	current_stamina = clampf(
		float(data.get("current_stamina", max_stamina)),
		0.0,
		max_stamina
	)
	_recovery_timer = maxf(float(data.get("recovery_timer", 0.0)), 0.0)
	
	current_satiety = clampf(
		float(data.get("current_satiety", max_satiety)),
		0.0,
		max_satiety
	)
	current_thirst = clampf(
		float(data.get("current_thirst", max_thirst)),
		0.0,
		max_thirst
	)
	_emit_needs_changed()

	
	_emit_resources_changed()


func _merge_modifiers(target: Dictionary, source: Dictionary) -> void:
	for key_variant: Variant in source.keys():
		var key: String = str(key_variant)
		var value: float = float(source[key_variant])

		if key.ends_with("_multiplier"):
			target[key] = float(target.get(key, 1.0)) + value - 1.0
		else:
			target[key] = float(target.get(key, 0.0)) + value


func _add_value(modifiers: Dictionary, key: String) -> float:
	return float(modifiers.get(key, 0.0))


func _multiplier_value(modifiers: Dictionary, key: String) -> float:
	return float(modifiers.get(key, 1.0))


func _emit_resources_changed() -> void:
	resources_changed.emit(
		current_willpower,
		max_willpower,
		current_stamina,
		max_stamina
	)

func add_status_effect(effect: StatusEffectData) -> bool:
	if effect == null or effect.effect_id == &"":
		push_warning("PlayerStats: некорректный StatusEffectData")
		return false

	for index: int in range(active_status_effects.size()):
		var active: Dictionary = active_status_effects[index]
		if str(active.get("effect_id", "")) == str(effect.effect_id):
			active["remaining_world_seconds"] = effect.duration_world_seconds
			active["display_name"] = effect.display_name
			active["description"] = effect.description
			active["icon_path"] = (
				effect.icon.resource_path
				if effect.icon != null
				else ""
			)
			active_status_effects[index] = active
			_recalculate_status_modifiers()
			return true

	active_status_effects.append({
		"effect_id": str(effect.effect_id),
		"resource_path": effect.resource_path,
		"display_name": effect.display_name,
		"description": effect.description,
		"remaining_world_seconds": effect.duration_world_seconds,
		"modifiers": effect.modifiers.duplicate(true),
		"icon_path": (
			effect.icon.resource_path
			if effect.icon != null
			else ""
		),
	})

	_recalculate_status_modifiers()
	return true


func remove_status_effect(effect_id: StringName) -> void:
	var old_size: int = active_status_effects.size()

	for index: int in range(active_status_effects.size() - 1, -1, -1):
		if str(active_status_effects[index].get("effect_id", "")) == str(effect_id):
			active_status_effects.remove_at(index)

	if active_status_effects.size() != old_size:
		_recalculate_status_modifiers()


func clear_status_effects() -> void:
	if active_status_effects.is_empty():
		return

	active_status_effects.clear()
	_recalculate_status_modifiers()



func _recalculate_status_modifiers() -> void:
	var combined: Dictionary = {}

	for effect: Dictionary in active_status_effects:
		var raw_modifiers: Variant = effect.get("modifiers", {})
		if not raw_modifiers is Dictionary:
			continue

		var modifiers: Dictionary = raw_modifiers as Dictionary
		for key_variant: Variant in modifiers.keys():
			var key: String = str(key_variant)
			var value: float = float(modifiers[key_variant])

			if key.ends_with("_multiplier"):
				combined[key] = float(combined.get(key, 1.0)) + value - 1.0
			else:
				combined[key] = float(combined.get(key, 0.0)) + value

	set_status_modifiers(combined)
	status_effects_changed.emit()

func make_status_effects_save_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for effect: Dictionary in active_status_effects:
		var remaining: float = float(
			effect.get("remaining_world_seconds", 0.0)
		)
		if remaining <= 0.0:
			continue

		result.append({
			"resource_path": str(effect.get("resource_path", "")),
			"remaining_world_seconds": remaining,
		})

	return result


func restore_status_effects_save_data(raw_effects: Variant) -> void:
	active_status_effects.clear()

	if not raw_effects is Array:
		_recalculate_status_modifiers()
		return

	for raw_effect: Variant in raw_effects:
		if not raw_effect is Dictionary:
			continue

		var saved: Dictionary = raw_effect as Dictionary
		var resource_path: String = str(
			saved.get("resource_path", "")
		)
		var remaining: float = float(
			saved.get("remaining_world_seconds", 0.0)
		)

		if resource_path.is_empty() or remaining <= 0.0:
			continue
		if not ResourceLoader.exists(resource_path):
			push_warning(
				"PlayerStats: ресурс эффекта не найден: %s"
				% resource_path
			)
			continue

		var loaded: Resource = load(resource_path)
		if not loaded is StatusEffectData:
			push_warning(
				"PlayerStats: ресурс не является StatusEffectData: %s"
				% resource_path
			)
			continue

		var effect_data: StatusEffectData = loaded as StatusEffectData

		active_status_effects.append({
			"effect_id": str(effect_data.effect_id),
			"resource_path": resource_path,
			"remaining_world_seconds": remaining,
			"modifiers": effect_data.modifiers.duplicate(true),
			"icon_path": (
				effect_data.icon.resource_path
				if effect_data.icon != null
				else ""
			),
			"display_name": effect_data.display_name,
			"description": effect_data.description,
		})

	_recalculate_status_modifiers()
