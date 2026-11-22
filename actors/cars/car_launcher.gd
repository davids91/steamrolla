extends TrafficMaker

signal car_launched(car: MovingCar)

@export var car_template: PackedScene = preload("res://actors/cars/moving_car.tscn")
@export var car_launch_force: float = 45.
func launch_car() -> void:
	var car: MovingCar = car_template.instantiate()
	car.force_strength = (
		car_launch_force
		+ randf_range(-1., 1.) * car_launch_force * cars_start_force_variance_percentage
	)
	car_launched.emit(car)
	add_child(car)
