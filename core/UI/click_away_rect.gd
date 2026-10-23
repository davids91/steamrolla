extends ColorRect

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		get_parent().clicked_away()
