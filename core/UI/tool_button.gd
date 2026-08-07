@tool
class_name ToolButton
extends Panel

signal selected(tool: ToolPanel.Tools)

@export var tool_icon_regions: Array[Rect2]
@export var tool_enums: Array[ToolPanel.Tools]
@export var tool_index: int = 0: ## aligns to ToolPanel.tools
	set(v):
		tool_index = v
		if get_node_or_null("%ToolImage") and abs(v) < tool_icon_regions.size():
			%ToolImage.texture.region = tool_icon_regions[v]

func get_tool_enum() -> ToolPanel.Tools: return tool_enums[tool_index]

func select() -> void:
	is_selected = true
	modulate = clicked_modulate

var is_selected: bool = false
func unselect() -> void:
	is_selected = false
	modulate = unfocused_modulate

@export var clicked_modulate: Color = Color.WHITE
@export var focused_modulate: Color = Color.WEB_GRAY
@export var unfocused_modulate: Color = Color.DIM_GRAY
var is_in_focus: bool = false
func _on_mouse_entered() -> void:
	if is_selected: modulate = clicked_modulate
	else: modulate = focused_modulate
	is_in_focus = true

func _on_mouse_exited() -> void:
	if is_selected: modulate = clicked_modulate
	else: modulate = unfocused_modulate
	is_in_focus = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and is_in_focus:
		if event.pressed:
			selected.emit(get_tool_enum())
			is_selected = true
			modulate = clicked_modulate
