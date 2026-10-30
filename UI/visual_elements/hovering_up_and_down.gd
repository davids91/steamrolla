extends AnimatedSprite3D

@export var hover_direction: Vector3 = -basis.y
@export var hover_speed: float = 0.3
@export var hover_speed_change_per_minute = 1.5
@export var hover_speed_delta_percentage: float = 0.05

func _ready() -> void:
	hover_speed = hover_speed + randf_range(-hover_speed_delta_percentage, hover_speed_delta_percentage) * hover_speed

var current_hover_direction_multiplier: float = 1.
var time_to_next_change = 60. / hover_speed_change_per_minute
func _process(delta: float) -> void:
	time_to_next_change -= delta
	if 0. >= time_to_next_change:
		time_to_next_change = 60. / hover_speed_change_per_minute
		hover_speed = hover_speed + randf_range(-hover_speed_delta_percentage, hover_speed_delta_percentage) * hover_speed
		current_hover_direction_multiplier *= -1.
	global_position += hover_direction * current_hover_direction_multiplier * hover_speed * delta
