extends Node3D

@export var view: PlayerView
@export var road_chunk: RoadChunk
@export var tool_nodes: Dictionary[ToolPanel.Tools, RoadWorkTool]

@export_range(0., 10.) var draw_strength: float = 0.15
@export_range(0., 10.) var asphalt_addition: float = 0.25
@export_range(0., 10.) var asphalt_removal: float = 0.25
@export_range(0., 1.) var draw_radius: float = 0.03:
	set(v):
		draw_radius = v
		if road_chunk: road_chunk.set_update_brush_radius(draw_radius)

var active_tool: ToolPanel.Tools = ToolPanel.Tools.UNKNOWN
func select_tool(tool: ToolPanel.Tools) -> void:
	active_tool = tool
	if road_chunk and tool_nodes.has(tool):
		road_chunk.configure_to(tool_nodes[tool])

@export_range(0., 5.) var shovel_icon_duration_sec: float = 1.
@export var shovel_icon_travel_distance: float = 2.
@export var shovel_icon_y_offset: float = 2.
@export var shovel_icon_dig_travel_y: Curve
@export var shovel_icon_fill_travel_y: Curve
func dig_shovel_into(target_position: Vector3) -> void:
	$ShovelIcon.modulate = Color.WHITE
	if asphalt_delta < 0.: # Digging
		var shovel_icon_start_position: Vector3 = target_position + Vector3(0., shovel_icon_y_offset, 0.)
		$ShovelIcon.global_position = shovel_icon_start_position
		create_tween().tween_method(
			func(w: float):
				$ShovelIcon.global_position = (
					shovel_icon_start_position
					+ Vector3(0., shovel_icon_dig_travel_y.sample(w) * shovel_icon_travel_distance, 0.)
				),
			0., 1., shovel_icon_duration_sec
		).set_ease(Tween.EASE_IN_OUT)
	else:
		var shovel_icon_start_position: Vector3 = (target_position + Vector3(0., shovel_icon_travel_distance + shovel_icon_y_offset, 0.))
		$ShovelIcon.global_position = shovel_icon_start_position
		create_tween().tween_method(
			func(w: float):
				$ShovelIcon.global_position = (
					shovel_icon_start_position
					+ Vector3(0., shovel_icon_fill_travel_y.sample(w) * shovel_icon_travel_distance, 0.)
				),
			0., 1., shovel_icon_duration_sec
		).set_ease(Tween.EASE_IN_OUT)
	create_tween().tween_property(
		$ShovelIcon, "modulate", Color.TRANSPARENT,
		shovel_icon_duration_sec
	)

var asphalt_delta: float = 0.
var shoveling_asphalt: bool = false
var dragging: bool = false:
	set(v):
		if not dragging and tool_nodes.has(active_tool): tool_nodes[active_tool].stop_working()
		dragging = v
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		dragging = false
		if active_tool != ToolPanel.Tools.UNKNOWN:
			dragging = event.is_pressed()
			if active_tool == ToolPanel.Tools.PAVER and event.pressed:
				asphalt_delta = asphalt_addition
				$ShovelSound.play()
				shoveling_asphalt = true
			elif active_tool == ToolPanel.Tools.SHOVEL and event.pressed:
				asphalt_delta = -asphalt_removal
				$ShovelSound.play()
				shoveling_asphalt = true
	view.lock_view(dragging)

const asphalt_removal_delay_sec: float = 0.25
var time_to_remove_asphalt_sec: float = asphalt_removal_delay_sec
func _process(delta: float) -> void:
	# Handle Asphalt addition/removal
	if 0. != asphalt_delta:
		if 0. > asphalt_delta and time_to_remove_asphalt_sec > 0.:
			time_to_remove_asphalt_sec -= delta
		elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			asphalt_delta *= 0.85
			if abs(asphalt_delta) < 0.1: asphalt_delta = 0.
			if 0. == asphalt_delta: dragging = false
		%RoadChunk.set_update_brush_amount(asphalt_delta * delta)
	else:
		time_to_remove_asphalt_sec = asphalt_removal_delay_sec

func _physics_process(_delta: float) -> void:
	if dragging or 0. != asphalt_delta:
		road_chunk.set_update_brush_center(view.cursor.global_position)
		if shoveling_asphalt and active_tool == ToolPanel.Tools.SHOVEL:
			dig_shovel_into(view.cursor.global_position)
			shoveling_asphalt = false
		else:
			if tool_nodes.has(active_tool):
				tool_nodes[active_tool].work_at(view.cursor.global_position)
				road_chunk.set_tool_angle(Vector2(-tool_nodes[active_tool].basis.z.x, -tool_nodes[active_tool].basis.z.z).angle())
				if (active_tool == ToolPanel.Tools.PAVER):
					road_chunk.set_paver_brush_height_by(tool_nodes[active_tool].global_position.y)
	shoveling_asphalt = false
	road_chunk.update_asphalt()
