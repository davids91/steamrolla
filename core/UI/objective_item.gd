class_name ObjectiveItem
extends HBoxContainer

@export var completed: bool = false:
	set(v):
		completed = v
		if completed:
			$Icon.texture = preload("res://textures/shovel_icon.png")
			$Icon.modulate = HUD.MAIN_COLOR_GREEN
		else:
			$Icon.texture = preload("res://textures/shovel_icon_outline.png")
			$Icon.modulate = Color.WHITE

func set_objective(text: String) -> void:
	$ObjectiveText.text = text
