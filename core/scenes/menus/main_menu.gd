extends Control

func _on_level_selection_btn_pressed() -> void:
	$ButtonSound.play()
	
	SceneManager.change_scene_to_packed(
		preload("res://core/scenes/menus/level_select.tscn")
		)

func _on_scenery_museum_btn_pressed() -> void:
	$ButtonSound.play()
	SceneManager.change_scene_to_file(
		"res://core/scenes/scenery_museum.scn"
		)

func _on_option_btn_pressed() -> void:
	$ButtonSound.play()

func _on_credits_btn_pressed() -> void:
	$ButtonSound.play()
