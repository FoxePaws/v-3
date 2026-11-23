class_name ClothingVisuals
extends Node

# Ключ — clothing_visual_id, значение — путь от Skeleton3D до меша.
@export var visual_paths: Dictionary[StringName, NodePath] = {}

var visuals: Dictionary = {}


func _ready() -> void:

	for visual_id in visual_paths:
		var visual := get_node_or_null(visual_paths[visual_id]) as Node3D
		if visual == null:
			push_warning("Не найден меш одежды для ID: %s" % visual_id)
			continue

		visuals[visual_id] = visual
		visual.visible = false


func set_visible(visual_id: StringName, value: bool) -> void:
	var visual := visuals.get(visual_id) as Node3D
	if visual == null:
		push_warning("Не зарегистрирован меш одежды с ID: %s" % visual_id)
		return

	visual.visible = value


func hide_all() -> void:
	for visual_value in visuals.values():
		var visual := visual_value as Node3D
		if visual != null:
			visual.visible = false
