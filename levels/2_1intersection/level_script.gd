extends BaseLevel

func _ready() -> void:
	super()
	if LevelStructure.level_attribute_present(base_dir, "pipe_covered"):
		$Pipe/WaterSpurt.emitting = false

@export var objective_check_interval_sec : float = 0.5
var time_left_to_check_sec: float = objective_check_interval_sec
func _process(delta: float) -> void:
	time_left_to_check_sec -= delta
	if 0. > time_left_to_check_sec:
		time_left_to_check_sec = objective_check_interval_sec
		(func():
			var asphalt_height: float = await %RoadChunk.get_asphalt_quantity_at($Pipe.global_position)
			if asphalt_height > 0.2:
				LevelStructure.level_attribute_store(base_dir, "pipe_covered")
				$Pipe/WaterSpurt.emitting = false
				%RoadChunk.save_user_data(base_dir)
		).call_deferred()
