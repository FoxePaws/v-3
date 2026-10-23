class_name ItemData
extends Resource

enum ItemType {
	GENERIC,
	CLOTHING,
	EQUIPMENT,
	CONTAINER
}

@export_category("Identity")
@export var item_id: StringName = &""
@export var display_name: String = ""
@export var item_scene: PackedScene
@export var icon: Texture2D
@export var item_type: ItemType = ItemType.GENERIC

@export_category("Interaction")
@export var can_grab: bool = true
@export var can_throw: bool = true
@export var throw_force: float = 8.0

@export_category("Hands")
@export var is_heavy: bool = false
@export var secondary_hand_offset: Vector3 = Vector3.ZERO
@export var secondary_hand_rotation: Vector3 = Vector3.ZERO

@export_category("Equipment")
@export var equipment_slot: StringName = &""
@export var clothing_visual_id: StringName = &""
@export var hide_clothing_visuals: Array[StringName] = []
@export var bone_name: StringName = &""
@export var walk_speed_modifier: float = 0.0
@export var sprint_speed_modifier: float = 0.0
@export var protection: float = 0.0
@export var warmth: float = 0.0

@export_category("Container")
@export var container_capacity: int = 0
@export var max_item_size: float = 0.0
@export var item_size: float = 1.0

@export_group("Body Blend Shapes")
@export var body_shape_keys: Array[BlendShapeSetting] = []
@export var head_shape_keys: Array[BlendShapeSetting] = []
@export var sweater_shape_keys: Array[BlendShapeSetting] = []

@export_category("Collision")
@export_flags_3d_physics var collision_layer: int = 8
@export_flags_3d_physics var collision_mask: int = 1
