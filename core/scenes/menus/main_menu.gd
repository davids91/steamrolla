extends Control

func _ready() -> void:
	Music.start_music(Music.Track.MAIN_MENU_MUSIC_LOOP)

func _on_level_selection_btn_pressed() -> void:
	$ButtonSound.play()
	SceneManager.return_to_level_select()

func _on_scenery_museum_btn_pressed() -> void:
	$ButtonSound.play()
	SceneManager.change_scene_to_file(
		"res://core/scenes/scenery_museum.scn"
		)

func _on_option_btn_pressed() -> void:
	$ButtonSound.play()

func _on_credits_btn_pressed() -> void:
	$ButtonSound.play()
