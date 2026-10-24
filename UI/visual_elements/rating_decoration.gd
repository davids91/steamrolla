class_name RatingDecoration
extends Sprite3D

@export var current_completion_percentage: float = 0.:
	set(v):
		current_completion_percentage = v
		%Rating.current_rating = GameDifficulty.instance.completion_to_rating.sample(current_completion_percentage)

func show_rating() -> void:
	%Rating.show_rating()

func hide_rating() -> void:
	%Rating.hide_rating()
