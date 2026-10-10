class_name HeadsUpDisplay
extends CanvasLayer

signal selected(tool: ToolPanel.Tools)
signal objective_completed(objective_name: String)
signal exit_scene()

static var MAIN_COLOR_GREEN: Color = Color.from_string("#36a947", Color.WEB_GREEN)
@export var asphalt_check_interval_sec: float = 0.5
@export var level: RoadChunk
@export var base_dir: String = ""

func set_objectives(objectives: Dictionary[String, String]) -> void:
	$ObjectivePanel.set_objectives(objectives, base_dir)

func objective_complete(objective_name: String) -> void:
	$ObjectivePanel.set_completed(objective_name) # This also triggers _on_objective_panel_objective_completed

func _ready() -> void: # Automatically wire the level down to the objective panel
	if level: $ObjectivePanel.level = level

func _on_tool_panel_selected_tool(tool: ToolPanel.Tools) -> void:
	selected.emit(tool)

@export var transition_time_sec: float = 0.5
func _on_exit_btn_pressed() -> void:
	exit_scene.emit()

func _on_objective_panel_objective_completed(objective_name: String) -> void:
	objective_completed.emit(objective_name)
	if objective_name == "asphalt_done": $SuccessLevel.play()

	# Check if all objectives are complete
	if(
		LevelStructure.level_attribute_completion(base_dir) >= 1.
		and not LevelStructure.level_attribute_present(base_dir, "shown_complete_screen")
	):
		$LevelCompletePanel.visible = true
		create_tween().tween_property($LevelCompletePanel, "modulate", Color.WHITE, transition_time_sec)
		LevelStructure.level_attribute_store(base_dir, "shown_complete_screen")
