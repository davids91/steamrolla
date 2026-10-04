extends Label

@export var vibrate_length: float = 0.0015
@onready var highlight_tween: Tween = create_tween()
func _ready() -> void:
	highlight_tween.tween_method(
		func(w: float): material.set_shader_parameter("stripes_edge", sin(w) * vibrate_length),
		0, TAU, 0.5
	)
	highlight_tween.set_loops()
