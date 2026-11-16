class_name ItemEquip
extends ItemComponent

enum EquipKind {
	CLOTHING,
	EQUIPMENT,
}

@export_category("Equipment")
@export var equip_kind: EquipKind = EquipKind.CLOTHING
@export var equipment_slot: StringName = &""
@export var bone_name: StringName = &""

@export_category("Clothing visuals")
@export var clothing_visual_id: StringName = &""
@export var hide_clothing_visuals: Array[StringName] = []

@export_category("Player stat modifiers")
@export var player_modifiers: Dictionary = {}

@export_category("Blend shapes")
@export var body_shape_keys: Array[BlendShapeSetting] = []
@export var head_shape_keys: Array[BlendShapeSetting] = []
@export var sweater_shape_keys: Array[BlendShapeSetting] = []


func make_save_data() -> Dictionary:
	var saved_state: Dictionary = super.make_save_data()
	saved_state["player_modifiers"] = player_modifiers.duplicate(true)
	return saved_state


func restore_save_data(saved_state: Dictionary) -> void:
	super.restore_save_data(saved_state)
