class_name HeadsUpDisplay
extends CanvasLayer

signal selected(tool: ToolPanel.Tools)
signal exit_scene()

static var MAIN_COLOR_GREEN: Color = Color.from_string("#36a947", Color.WEB_GREEN)
const level_select_scene: PackedScene = preload("res://core/scenes/level_select.tscn")
@onready var level_container: Node = get_node("/root/Main/LevelContainer")

func _on_tool_panel_selected_tool(tool: ToolPanel.Tools) -> void:
	selected.emit(tool)

func _on_exit_btn_pressed() -> void:
	exit_scene.emit()
	for c in level_container.get_children(): c.queue_free()
	level_container.add_child(level_select_scene.instantiate())
