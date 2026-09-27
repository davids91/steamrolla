@tool
class_name ToolButton
extends Panel

signal selected(tool: ToolPanel.Tools)

@export var tool_icon_regions: Array[Rect2]
@export var tool_enums: Array[ToolPanel.Tools]
@export var tool_number: int = 0: ## aligns to ToolPanel.tools
	set(v):
		tool_number = v
		if get_node_or_null("%ToolNumber"): %ToolNumber.text = str(v + 1)

@export var tool_index: int = 0: ## aligns to ToolPanel.tools
	set(v):
		tool_index = v
		if get_node_or_null("%ToolImage") and abs(v) < tool_icon_regions.size():
			%ToolImage.texture.region = tool_icon_regions[v]

@export var deployed: bool:
	set(v):
		if deployed != v:
			if v: create_tween().tween_property(%ToolImage, "custom_minimum_size", Vector2(132, 132), 0.3)
			else: create_tween().tween_property(%ToolImage, "custom_minimum_size", Vector2(100, 100), 0.3)
		deployed = v

func get_tool_enum() -> ToolPanel.Tools: return tool_enums[tool_index]

func select() -> void:
	is_selected = true
	modulate = clicked_modulate
	highlight_tween.play()

var is_selected: bool = false
func unselect() -> void:
	is_selected = false
	modulate = unfocused_modulate
	highlight_tween.pause()

@onready var highlight_tween: Tween = create_tween()
func _ready() -> void:
	highlight_tween.tween_method(
		func(w: float): %ToolNumber.material.set_shader_parameter("stripes_edge", sin(w) * 0.0015),
		0, TAU, 0.5
	)
	highlight_tween.set_loops()
	highlight_tween.pause()

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
