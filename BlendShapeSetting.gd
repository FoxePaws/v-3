class_name BlendShapeSetting
extends Resource

@export var mesh_path: NodePath
@export var shape_name: StringName = &""
@export_range(-1.0, 1.0, 0.01) var value: float = 0.0
@export var priority: int = 0
