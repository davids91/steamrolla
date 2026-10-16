extends Marker3D

signal car_launched(car: MovingCar)

@export var is_active: bool = true
@export var car_template: PackedScene = preload("res://actors/moving_car.tscn")
@export var cars_per_minute: float = 5.
@export var car_launch_force: float = 25.
@export_range(0., 1.) var cars_frequency_variance_percentage: float = 0.2
@export_range(0., 1.) var cars_start_force_variance_percentage: float = 0.2

func _sample_time_to_next_car_sec() -> float:
	return 60. / (cars_per_minute + (randf_range(-1., 1.) * cars_per_minute * cars_frequency_variance_percentage))

@onready var car_start_position: Transform3D
@onready var time_to_launch_car_sec: float = _sample_time_to_next_car_sec()
func _process(delta: float) -> void:
	time_to_launch_car_sec -= delta
	if 0. > time_to_launch_car_sec and is_active:
		time_to_launch_car_sec = _sample_time_to_next_car_sec()
		var car: MovingCar = car_template.instantiate()
		add_child(car)
		car.force_strength = (
			car_launch_force
			+ randf_range(-1., 1.) * car_launch_force * cars_start_force_variance_percentage
		)
		car_launched.emit(car)
