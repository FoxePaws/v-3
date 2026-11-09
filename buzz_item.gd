class_name BuzzItem
extends ItemInstance

@export var buzz_effect: StatusEffectData
@export_range(0.0, 100000.0, 0.1) var durability_change: float = 10.0


func on_primary_action() -> void:
	if buzz_effect == null:
		push_warning("BuzzItem: не назначен StatusEffectData для buzz")
		return

	if current_hand == null or current_hand.player == null:
		return

	if durability < durability_change:
		return

	var player: Player = current_hand.player
	if player.stats.add_status_effect(buzz_effect):
		durability = maxf(durability - durability_change, 0.0)


func on_secondary_action() -> void:
	durability = minf(
		durability + durability_change,
		data.max_durability if data != null else durability
	)
