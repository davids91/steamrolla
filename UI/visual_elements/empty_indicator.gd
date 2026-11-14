extends Sprite3D

@export var blink_interval_sec: float = 0.13
@onready var lines_shown: bool = true
@onready var time_to_switch_sec: float = blink_interval_sec
func _process(delta: float) -> void:
	time_to_switch_sec -= delta
	if 0. >= time_to_switch_sec:
		time_to_switch_sec = blink_interval_sec
		if lines_shown: modulate = Color.TRANSPARENT
		else: modulate = Color.WHITE
		lines_shown = not lines_shown
