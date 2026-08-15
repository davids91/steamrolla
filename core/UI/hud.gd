class_name HeadsUpDisplay
extends CanvasLayer

signal selected(tool: ToolPanel.Tools)

static var MAIN_COLOR_GREEN: Color = Color.from_string("#36a947", Color.WEB_GREEN)

func _on_tool_panel_selected_tool(tool: ToolPanel.Tools) -> void:
	selected.emit(tool)
