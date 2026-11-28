extends TrafficMaker

@export var force_strength: float = 25.
@export var trajectory_speed_modifier: float = 3.
@export var road_chunk: RoadChunk
@export var car_templates: Array[PackedScene] = [
	preload("res://actors/cars/pusher_car.tscn"),
	preload("res://actors/cars/moving_car.tscn"),
]
@export var car_template_percentages: Array[float] = [
	0.2, 0.8
]

func pick_car() -> PackedScene:
	assert(not car_templates.is_empty(), "Car Dragger should have non-zero car templates to instantiate cars!")
	for i in car_templates.size():
		var car_chance: float = 0.
		if i < car_template_percentages.size(): car_chance = car_template_percentages[i]
		if randf() < car_chance: return car_templates[i]
	return car_templates[-1]

func launch_car() -> void:
	# make a Path3D, and a PathFollow
	var trajectory_data: TrajectoryData = road_chunk.level_data.trajectories.pick_random()
	var car_pivot: PathFollow3D = PathFollow3D.new()
	car_pivot.progress = 0.
	car_pivot.loop = false
	car_pivot.use_model_front = true

	var car_path: Path3D = Path3D.new()
	car_path.curve = trajectory_data.curves
	car_path.add_child(car_pivot)
	add_child(car_path)

	# Make the car
	var car = pick_car().instantiate()
	car.global_transform = car_pivot.global_transform
	car.pivot = car_pivot
	car.trajectory = trajectory_data
	car.finished.connect(func(): car_path.queue_free())
	if "force_strength" in car: car.force_strength = force_strength
	if "trajectory_speed_modifier" in car: car.trajectory_speed_modifier = trajectory_speed_modifier
	add_child(car)
