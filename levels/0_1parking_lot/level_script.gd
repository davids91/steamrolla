extends BaseLevel

func periodic_objective_check() -> void:
	(func():
		var asphalt_height: float = await %RoadChunk.get_asphalt_quantity_at($Skeleton.global_position)
		if asphalt_height > 0.2:
			LevelStructure.level_attribute_store(base_dir, "skeleton")
			%RoadChunk.save_user_data(base_dir)
	).call_deferred()
