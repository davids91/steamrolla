@tool
class_name ToolButton
extends Panel

signal selected(me: ToolButton)

enum Tools{ ROLLER, PAVER, DUMPTRUCK, COMPACTOR, SHOVEL }

@export var tool_icon_regions: Array[Rect2]
@export var tool_enums: Array[Tools]
@export var tool_index: int = 0:
	set(v):
		tool_index = v
		if %ToolImage and abs(v) < tool_icon_regions.size():
			%ToolImage.texture.region = tool_icon_regions[v]

func get_tool_enum() -> Tools: return tool_enums[tool_index]

var is_selected: bool = false
func unselect() -> void:
	is_selected = false

@export var clicked_modulate: Color = Color.WHITE
@export var focused_modulate: Color = Color.WEB_GRAY
@export var unfocused_modulate: Color = Color.DIM_GRAY
var is_in_focus: bool = false
func _on_mouse_entered() -> void:
	modulate = focused_modulate
	is_in_focus = true

func _on_mouse_exited() -> void:
	if is_selected: modulate = clicked_modulate
	else: modulate = unfocused_modulate
	is_in_focus = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and is_in_focus:
		if event.pressed:
			is_selected = true
			selected.emit(self)
			modulate = clicked_modulate
		else: modulate = focused_modulate
