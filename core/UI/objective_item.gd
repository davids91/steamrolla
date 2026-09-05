@tool
class_name ObjectiveItem
extends HBoxContainer

@export var uncompleted_region: Rect2
@export var completed_region: Rect2

@export var completed: bool = false:
	set(v):
		completed = v
		if get_node_or_null("Icon"):
			if completed:
				$Icon.texture.region = completed_region
				$Icon.modulate = HeadsUpDisplay.MAIN_COLOR_GREEN
			else:
				$Icon.texture.region = uncompleted_region
				$Icon.modulate = Color.WHITE

func set_objective(text: String) -> void:
	$ObjectiveText.text = text
