extends Control

@onready var level_container: Node = get_node("/root/Main/LevelContainer")

func _on_level_selection_btn_pressed() -> void:
	$ButtonSound.play()
	for c in level_container.get_children(): c.queue_free()
	level_container.add_child(preload("res://core/scenes/menus/level_select.tscn").instantiate())

func _on_scenery_museum_btn_pressed() -> void:
	$ButtonSound.play()
	for c in level_container.get_children(): c.queue_free()
	level_container.add_child(preload("res://core/scenes/scenery_museum.scn").instantiate())

func _on_option_btn_pressed() -> void:
	$ButtonSound.play()

func _on_credits_btn_pressed() -> void:
	$ButtonSound.play()
