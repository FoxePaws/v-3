class_name BuzzItem
extends ItemComponent


@export var buzz_effect: StatusEffectData
@export_range(0.0, 100000.0, 0.1) var durability_change: float = 10.0


func on_primary_action() -> void:
	if item == null:
		return

	if buzz_effect == null:
		push_warning("BuzzItem: не назначен StatusEffectData для buzz")
		return

	if item.current_hand == null:
		return

	var player: Player = item.current_hand.player
	if player == null or player.stats == null:
		return

	if item.durability < durability_change:
		return

	if player.stats.add_status_effect(buzz_effect):
		item.durability = maxf(
			item.durability - durability_change,
			0.0
		)


func on_secondary_action() -> void:
	if item == null:
		return

	item.durability = minf(
		item.durability + durability_change,
		item.max_durability
	)
