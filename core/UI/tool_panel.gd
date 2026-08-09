@tool
class_name ToolPanel
extends MarginContainer

enum Tools{ ROLLER, PAVER, DUMPTRUCK, COMPACTOR, SHOVEL, UNKNOWN }

signal selected_tool(tool: Tools)

@export var available_tools: Array[Tools]
@export_tool_button("Reload Buttons", "Button") var refresh_buttons_button: Callable = _refresh_buttons

func select(tool: Tools) -> void:
	for c in $Tools.get_children() as Array[ToolButton]:
		if c.get_tool_enum() != tool: c.unselect()
		else: c.select()
	selected_tool.emit(tool)
	var tool_index: int = available_tools.find(tool)
	create_tween().tween_property(
		$SelectedTool, "position",
		Vector2(
			get_theme_constant("margin_left") + $Tools.get_child(tool_index).position.x,
			get_theme_constant("margin_top")
		),
		0.1
	).set_ease(Tween.EASE_IN_OUT)

const TOOL_BUTTON_TEMPLATE: PackedScene = preload("res://core/UI/tool_button.tscn")
func _refresh_buttons() -> void:
	for c in $Tools.get_children(): queue_free()
	for t in available_tools:
		var button: ToolButton = TOOL_BUTTON_TEMPLATE.instantiate()
		button.selected.connect(select)
		button.tool_index = t
		$Tools.add_child(button)

func _ready() -> void:
	_refresh_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tool_1"):
		if available_tools.size() > 0: select(available_tools[0])
	if event.is_action_pressed("tool_2"):
		if available_tools.size() > 1: select(available_tools[1])
	if event.is_action_pressed("tool_3"):
		if available_tools.size() > 2: select(available_tools[2])
	if event.is_action_pressed("tool_4"):
		if available_tools.size() > 3: select(available_tools[3])
	if event.is_action_pressed("tool_5"):
		if available_tools.size() > 4: select(available_tools[4])
	if event.is_action_pressed("tool_6"):
		if available_tools.size() > 5: select(available_tools[5])
