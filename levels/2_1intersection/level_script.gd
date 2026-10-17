extends BaseLevel

func _ready() -> void:
	super()
	if LevelStructure.level_attribute_present(base_dir, "pipe_covered"):
		$Pipe/WaterSpurt.emitting = false

func periodic_objective_check() -> void:
	(func():
		var asphalt_height: float = await %RoadChunk.get_asphalt_quantity_at($Pipe.global_position)
		print(asphalt_height)
		if asphalt_height > 0.16:
			LevelStructure.level_attribute_store(base_dir, "pipe_covered")
			$Pipe/WaterSpurt.emitting = false
			%RoadChunk.save_user_data(base_dir)
	).call_deferred()

var crushed_cars: Array[Crushable]
func _on_car_crushed(me: Crushable) -> void:
	if not crushed_cars.has(me): crushed_cars.push_back(me)
	if crushed_cars.size() >= 5: LevelStructure.level_attribute_store(base_dir, "cars")
