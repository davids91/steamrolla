class_name HeadsUpDisplay
extends CanvasLayer

signal selected(tool: ToolPanel.Tools)
signal objective_completed(objective_name: String)
signal exit_scene()

static var MAIN_COLOR_GREEN: Color = Color.from_string("#36a947", Color.WEB_GREEN)
const LEVEL_SELECT_SCENE_TEMPLATE: PackedScene = preload("res://core/scenes/level_select.tscn")
@export var asphalt_check_interval_sec: float = 0.5
@export var level: RoadChunk
@onready var level_container: Node = get_node("/root/Main/LevelContainer")

func set_objectives(objectives: Dictionary[String, String], base_dir: String) -> void:
	$ObjectivePanel.set_objectives(objectives, base_dir)

func objective_complete(objective_name: String) -> void:
	$ObjectivePanel.set_completed(objective_name)

func _ready() -> void: # Automatically wire the level down to the objective panel
	if level: $ObjectivePanel.level = level

func _on_tool_panel_selected_tool(tool: ToolPanel.Tools) -> void:
	selected.emit(tool)

func _on_exit_btn_pressed() -> void:
	exit_scene.emit()
	for c in level_container.get_children(): c.queue_free()
	var level_select_scene: LevelSelectScene = LEVEL_SELECT_SCENE_TEMPLATE.instantiate()
	level_select_scene.coming_from = get_parent().base_dir.get_file()
	level_container.add_child(level_select_scene)

func _on_objective_panel_objective_completed(objective_name: String) -> void:
	objective_completed.emit(objective_name)
	if objective_name == "asphalt_done": $SuccessLevel.play()
