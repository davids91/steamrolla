extends BaseLevel

func _on_hud_objective_completed(objective_name: String) -> void:
	super(objective_name)
	if objective_name == "traffic_ok":
		$HUD.objective_complete("asphalt_done") # To make level asphalt snap too
