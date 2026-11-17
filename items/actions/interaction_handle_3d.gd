class_name InteractionHandle3D
extends Area3D


@export var grip_marker: Marker3D
@export var action: Node


func _ready() -> void:
	if grip_marker == null:
		grip_marker = get_node_or_null("GripMarker") as Marker3D

	if action == null:
		action = get_node_or_null("Action")

	if grip_marker == null:
		push_warning(
			"InteractionHandle3D: не назначен GripMarker"
		)

	if action == null:
		push_warning(
			"InteractionHandle3D: не назначено действие Action"
		)
