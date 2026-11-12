extends CanvasLayer

@export var effect_icon_scene: PackedScene

@onready var status_effects_container: HBoxContainer = \
	$Layout/BottomLeft/StatusEffects
@onready var stamina_bar: StatBarUI = \
	$Layout/BottomLeft/StaminaBar
@onready var willpower_bar: StatBarUI = \
	$Layout/BottomLeft/WillpowerBar


func _ready() -> void:
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_hud"):
		visible = not visible
		get_viewport().set_input_as_handled()


func update_bars(
	current_stamina: float,
	maximum_stamina: float,
	current_willpower: float,
	maximum_willpower: float
) -> void:
	stamina_bar.set_stat(
		"Stamina",
		current_stamina,
		maximum_stamina
	)
	willpower_bar.set_stat(
		"Willpower",
		current_willpower,
		maximum_willpower
	)


func update_status_effects(effects: Array[Dictionary]) -> void:
	for child: Node in status_effects_container.get_children():
		child.queue_free()

	if effect_icon_scene == null:
		push_warning("HUD: effect_icon_scene не назначена")
		return

	for effect: Dictionary in effects:
		var effect_icon: StatusEffectIcon = \
			effect_icon_scene.instantiate() as StatusEffectIcon

		if effect_icon == null:
			push_warning("HUD: сцена значка не содержит StatusEffectIcon")
			continue

		var icon_path: String = str(effect.get("icon_path", ""))
		var icon: Texture2D = null

		if not icon_path.is_empty():
			icon = load(icon_path) as Texture2D

		var effect_name: String = str(
			effect.get("display_name", effect.get("effect_id", "Эффект"))
		)
		var effect_description: String = str(
			effect.get("description", "")
		)

		status_effects_container.add_child(effect_icon)
		effect_icon.setup(icon, effect_name, effect_description)
