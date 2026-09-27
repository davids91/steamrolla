extends BaseLevel

func _ready() -> void:
	super()
	if LevelStructure.level_attribute_present(base_dir, "bomb_set_off"):
		%AsphaltBomb.queue_free()
		$HUD.objective_complete("bomb_set_off")

func _on_asphalt_bomb_asphalt_bomb_exploded(_blast_pos: Vector3, _explode_radius: float, _amount_to_add_asphalt: float) -> void:
	LevelStructure.level_attribute_store(base_dir, "bomb_set_off")
	$HUD.objective_complete("bomb_set_off")
