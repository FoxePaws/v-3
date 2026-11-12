class_name ConsumableItem
extends ItemInstance


func on_primary_action() -> void:
	if data == null:
		return

	if current_hand == null or current_hand.player == null:
		return

	var has_restoration: bool = (
		data.satiety_restoration > 0.0
		or data.thirst_restoration > 0.0
	)
	if not has_restoration:
		return

	var player: Player = current_hand.player
	var stats: PlayerStats = player.stats
	var can_restore_satiety: bool = (
		data.satiety_restoration > 0.0
		and stats.current_satiety < stats.max_satiety
	)
	var can_restore_thirst: bool = (
		data.thirst_restoration > 0.0
		and stats.current_thirst < stats.max_thirst
	)

	if not can_restore_satiety and not can_restore_thirst:
		return

	var durability_cost: float = maxf(
		data.consumable_durability_cost,
		0.0
	)
	if durability < durability_cost:
		return

	if can_restore_satiety:
		stats.restore_satiety(data.satiety_restoration)

	if can_restore_thirst:
		stats.restore_thirst(data.thirst_restoration)

	durability = maxf(durability - durability_cost, 0.0)
