class_name SleepSurface
extends Node

@export var description: String = ""
@export var sleep_effect: StatusEffectData
@export_range(0.1, 100.0, 0.1) var sleepiness_recovery_multiplier: float = 1.0
