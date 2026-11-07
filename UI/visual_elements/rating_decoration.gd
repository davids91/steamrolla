class_name RatingDecoration
extends Sprite3D

@export var level_title: String = ""
@export var current_completion_percentage: float = 0.:
	set(v):
		current_completion_percentage = v
		%Rating.current_rating = GameDifficulty.instance.completion_to_rating.sample(current_completion_percentage)

func show_rating() -> void:
	%Rating.show_rating()

func hide_rating() -> void:
	%Rating.hide_rating()

func _ready() -> void:
	get_tree().create_timer(0.5).timeout.connect(func():
		$Sprite3D.top_level = true
		$Sprite3D2.top_level = true
		$Sprite3D3.top_level = true
		$Sprite3D4.top_level = true
	)
