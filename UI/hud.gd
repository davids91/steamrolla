class_name HeadsUpDisplay
extends CanvasLayer

signal selected(tool: ToolPanel.Tools)
signal objective_completed(objective_name: String)
signal exit_scene()
signal exit_tool()

static var MAIN_COLOR_GREEN: Color = Color.from_string("#36a947", Color.WEB_GREEN)
@export var asphalt_check_interval_sec: float = 0.5
@export var level: RoadChunk
@export var base_dir: String = ""

func set_objectives(objectives: Dictionary[String, String], objective_photos: Array[Texture] = []) -> void:
	$ObjectivePanel.set_objectives(objectives, base_dir)
	$ObjectivePanel.photos = objective_photos

func is_objective_completed(objective_name: String) -> bool:
	return LevelStructure.level_attribute_present(base_dir, objective_name)

func objective_complete(objective_name: String) -> void:
	$ObjectivePanel.set_completed(objective_name) # This also triggers _on_objective_panel_objective_completed
	LevelStructure.level_attribute_store(base_dir, objective_name)

func _ready() -> void: # Automatically wire the level down to the objective panel
	if level: $ObjectivePanel.level = level

func _on_tool_panel_selected_tool(tool: ToolPanel.Tools) -> void:
	selected.emit(tool)

@export var transition_time_sec: float = 0.5
var is_selected_tool_piloted: bool = false
func _on_exit_btn_pressed() -> void:
	if is_selected_tool_piloted: exit_tool.emit()
	else: exit_scene.emit()

func _on_objective_panel_objective_completed(objective_name: String) -> void:
	objective_completed.emit(objective_name)
	if objective_name == "asphalt_done": $SuccessLevel.play()
	var level_completion_percentage: float = LevelStructure.level_attribute_completion(base_dir)
	$Rating.current_rating = round(GameDifficulty.instance.completion_to_rating.sample(level_completion_percentage))
	if( # Check if all objectives are complete to show completed dialouge
		level_completion_percentage >= 1.
		and not LevelStructure.level_attribute_present(base_dir, "shown_complete_screen")
	):
		$Rating.show_rating()
		$LevelCompletePanel.visible = true
		create_tween().tween_property($LevelCompletePanel, "modulate", Color.WHITE, transition_time_sec)
		LevelStructure.level_attribute_store(base_dir, "shown_complete_screen")

@export var exit_btn_normal_region: Rect2
@export var exit_btn_tool_region: Rect2
func _on_tool_controller_tool_switch(_from: RoadworkTool, to: RoadworkTool) -> void:
	is_selected_tool_piloted = to and to.controlled_by == RoadworkTool.ControlMethods.PILOTED
	if is_selected_tool_piloted: %ExitBtn/TextureRect.texture.region = exit_btn_tool_region
	else: %ExitBtn/TextureRect.texture.region = exit_btn_normal_region
