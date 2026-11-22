extends TrafficMaker

@export var road_chunk: RoadChunk

@export var car_template: PackedScene = preload("res://actors/cars/pusher_car.tscn")
func launch_car() -> void:
	# make a Path3D, and a PathFollow
	var trajectory_data: TrajectoryData = road_chunk.level_data.trajectories.pick_random()
	var car_path: Path3D = Path3D.new()
	var car_pivot: PathFollow3D = PathFollow3D.new()
	car_path.curve = trajectory_data.curves
	car_path.add_child(car_pivot)
	add_child(car_path)

	# Make the car
	var car: PusherCar = car_template.instantiate()
	car.pivot = car_pivot
	car.trajectory = trajectory_data
	car.finished.connect(func(): car_path.queue_free())
	add_child(car)
