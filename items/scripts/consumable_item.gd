class_name ConsumableItem
extends ItemComponent

@export_category("Restoration")
@export_range(-1000.0, 10000.0, 0.1) var satiety_restoration: float = 0.0
@export_range(-1000.0, 10000.0, 0.1) var thirst_restoration: float = 0.0
@export_range(-1000.0, 10000.0, 0.1) var durability_cost: float = 1.0
@export_range(-1000.0, 10000.0, 0.1) var sleepiness_restoration: float = 0.0

func on_primary_action() -> void:
	if item == null or item.current_hand == null:
		return

	var player: Player = item.current_hand.player
	if player == null or player.stats == null:
		return

	var stats: PlayerStats = player.stats

	var can_restore_satiety: bool = (
		 stats.current_satiety < stats.max_satiety
	)
	var can_restore_thirst: bool = (
		 stats.current_thirst < stats.max_thirst
	)
	var can_restore_sleepiness: bool = (
		stats.current_sleepiness < stats.max_sleepiness
	)

	if (
		not can_restore_satiety
		and not can_restore_thirst
		and not can_restore_sleepiness
	):
		return

	var cost: float = maxf(durability_cost, 0.0)
	if item.durability < cost:
		return

	if can_restore_satiety:
		stats.restore_satiety(satiety_restoration)
	if can_restore_thirst:
		stats.restore_thirst(thirst_restoration)
	if can_restore_sleepiness:
		stats.restore_sleepiness(sleepiness_restoration)

	item.durability = maxf(item.durability - cost, 0.0)
