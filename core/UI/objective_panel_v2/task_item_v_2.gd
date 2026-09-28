extends HBoxContainer

@export var uncompleted_region: Rect2
@export var completed_region: Rect2

@export var completed: bool = false:
	set(v):
		if get_node_or_null("%Checkmark") and v != completed:
			if v:
				%Checkmark.show()
			else:
				%Checkmark.hide()
		completed = v

func set_objective(text: String) -> void:
	$TaskLabel.text = text
