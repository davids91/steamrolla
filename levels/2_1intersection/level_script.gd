extends BaseLevel

func _ready() -> void:
	super()
	if $HUD.is_objective_completed("pipe_covered"):
		$Pipe/WaterSpurt.emitting = false

func periodic_objective_check() -> void:
	(func():
		var asphalt_height: float = await %RoadChunk.get_asphalt_quantity_at($Pipe.global_position)
		if asphalt_height > 0.16:
			$HUD.objective_complete("pipe_covered")
			$Pipe/WaterSpurt.emitting = false
			%RoadChunk.save_user_data(base_dir)
	).call_deferred()

var crushed_cars: Array[Crushable]
func _on_car_crushed(me: Crushable) -> void:
	if not crushed_cars.has(me): crushed_cars.push_back(me)
	if crushed_cars.size() >= 5: $HUD.objective_complete("cars")
