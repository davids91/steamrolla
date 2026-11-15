extends BaseLevel

func _ready() -> void:
	super()
	if $HUD.is_objective_completed("bomb_set_off"):
		%AsphaltBomb.queue_free()

	if $HUD.is_objective_completed("flowers"):
		$FireHydrant.object_hitting_hydrant = $PlayerView
		$FireHydrant.already_crushed = true
	else: $Flowers.dry_me(0.4)

func _on_asphalt_bomb_asphalt_bomb_exploded(_blast_pos: Vector3, _explode_radius: float, _amount_to_add_asphalt: float) -> void:
	$HUD.objective_complete("bomb_set_off")

func _on_fire_hydrant_water_spouts() -> void:
	$HUD.objective_complete("flowers")
