extends Control

signal exit_scene()

func _on_stay_button_pressed() -> void:
	queue_free()

func _on_level_select_button_pressed() -> void:
	exit_scene.emit()
