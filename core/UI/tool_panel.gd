extends MarginContainer

signal selected_tool(tool: ToolButton.Tools)

func _ready() -> void:
	for c in $Tools.get_children(): if c is ToolButton:
		c.selected.connect(selected)

var currently_selected: ToolButton
func selected(tool: ToolButton) -> void:
	if currently_selected: currently_selected.unselect()
	currently_selected = tool
	selected_tool.emit(currently_selected.get_tool_enum())
	$SelectedTool.global_position.x = currently_selected.global_position.x - 207. # TechDebt: Magic number for x offset
