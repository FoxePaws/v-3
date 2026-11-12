class_name StatusEffectIcon
extends PanelContainer

@onready var icon_texture: TextureRect = $TextureRect


func setup(
	icon: Texture2D,
	effect_name: String,
	effect_description: String
) -> void:
	icon_texture.texture = icon
	tooltip_text = "%s\n%s" % [
		effect_name,
		effect_description,
	]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
