class_name StatusEffectData
extends Resource

@export var effect_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(0.01, 100000.0, 0.1)
var duration_world_seconds: float = 10.0

# Модификаторы с ключами PlayerStats, например:
# max_willpower_add, stamina_recovery_multiplier,
# walk_speed_multiplier, jump_velocity_multiplier.
@export var modifiers: Dictionary[String, float] = {}
