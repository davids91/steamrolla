extends BaseLevel

@export var max_cars_count: int = 30
func _ready():
	super()
	if $HUD.is_objective_completed("traffic"):
		traffic_objective_complete = true
	var car_transform_readouts = LevelStructure.level_attribute_data_read(base_dir,"contained_cars")
	if car_transform_readouts is Array[Transform3D]:
		if max_cars_count <= car_transform_readouts.size():
			$CarLauncherTop.is_active = false
			$CarLauncherBottom.is_active = false
		for t in car_transform_readouts:
			var car: MovingCar = preload("res://actors/moving_car.tscn").instantiate()
			car.global_transform = t
			add_child(car)

func _on_hud_exit_scene() -> void:
	var car_transforms: Array[Transform3D] = []
	for car in contained_cars: car_transforms.push_back(car.global_transform)
	LevelStructure.level_attribute_store(base_dir, "contained_cars", car_transforms)
	super()

@export var traffic_objective_delay_sec: float = 25.
var time_to_check_objective_sec: float = traffic_objective_delay_sec
var traffic_objective_complete: bool = false
func _process(delta: float) -> void:
	time_to_check_objective_sec -= delta
	if time_to_check_objective_sec < 0. and not traffic_objective_complete:
		var crashed_car_count: int = 0
		for car in contained_cars: if car.crashed: crashed_car_count += 1
		if 0 == crashed_car_count:
			traffic_objective_complete = true
			$HUD.objective_complete("asphalt_done") # To make level asphalt snap too

var contained_cars: Array[MovingCar] = []
func _on_car_launcher_car_launched(car: MovingCar) -> void:
	contained_cars.push_back(car)
	$CarLauncherTop.is_active = max_cars_count > contained_cars.size()
	$CarLauncherBottom.is_active = max_cars_count > contained_cars.size()

func _on_level_proximity_body_exited(body: Node3D) -> void:
	if body is MovingCar and contained_cars.has(body):
		contained_cars.erase(body)
		body.queue_free()
		$CarLauncherTop.is_active = max_cars_count > contained_cars.size()
		$CarLauncherBottom.is_active = max_cars_count > contained_cars.size()
