class_name StatBarUI
extends PanelContainer

@onready var progress_bar: ProgressBar = $Margin/Column/ProgressBar
@onready var value_label: Label = $Margin/Column/ProgressBar/ValueLabel




func set_stat(
	stat_name: String,
	current_value: float,
	maximum_value: float
) -> void:
	var safe_maximum: float = maxf(maximum_value, 0.0)
	var safe_current: float = clampf(current_value, 0.0, safe_maximum)

	value_label.text = "%s  %s / %s" % [
		stat_name,
		_format_number(safe_current),
		_format_number(safe_maximum),
	]

	progress_bar.max_value = maxf(safe_maximum, 1.0)
	progress_bar.value = safe_current


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))

	return "%.1f" % value
