@tool
class_name ToolPanel
extends MarginContainer

enum Tools{ ROLLER, PAVER, DUMPTRUCK, COMPACTOR, SHOVEL, UNKNOWN }

signal selected_tool(tool: Tools)

@export var available_tools: Array[Tools]

const TOOL_BUTTON_TEMPLATE: PackedScene = preload("res://core/UI/tool_button.tscn")
func _ready() -> void:
	for t in available_tools:
		var button: ToolButton = TOOL_BUTTON_TEMPLATE.instantiate()
		button.selected.connect(select)
		button.tool_index = t
		$Tools.add_child(button)

func select(tool: Tools) -> void:
	for c in $Tools.get_children() as Array[ToolButton]:
		if c.get_tool_enum() != tool: c.unselect()
		else: c.select()
	selected_tool.emit(tool)
	var tool_index: int = available_tools.find(tool)
	create_tween().tween_property(
		$SelectedTool, "global_position",
		global_position + $Tools.get_child(tool_index).global_position - Vector2(207., 0.), # TechDebt: Magic number for x offset,
		0.1
	).set_ease(Tween.EASE_IN_OUT)
