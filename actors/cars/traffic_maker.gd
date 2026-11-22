class_name TrafficMaker
extends Node3D

## Function to overwrite for 
func launch_car() -> void: pass

@export var is_active: bool = true
@export var cars_per_minute: float = 5.
@export_range(0., 1.) var cars_frequency_variance_percentage: float = 0.2
@export_range(0., 1.) var cars_start_force_variance_percentage: float = 0.2

func _sample_time_to_next_car_sec() -> float:
	return 60. / (cars_per_minute + (randf_range(-1., 1.) * cars_per_minute * cars_frequency_variance_percentage))

func _ready() -> void:
	if not is_in_group("TrafficMakers"): add_to_group("TrafficMakers")

@onready var time_to_launch_car_sec: float = _sample_time_to_next_car_sec()
func _process(delta: float) -> void:
	time_to_launch_car_sec -= delta
	if 0. > time_to_launch_car_sec and is_active:
		time_to_launch_car_sec = _sample_time_to_next_car_sec()
		launch_car()
