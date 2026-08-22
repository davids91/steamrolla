extends Node3D

@export var trajectory: Trajectory
@export var HUD: HeadsUpDisplay
@export var view: PlayerView
@export var road_chunk: RoadChunk
@export var runways: Dictionary[ToolPanel.Tools, Runway]
@export var tool_nodes: Dictionary[ToolPanel.Tools, RoadworkTool]

@export_range(0., 10.) var draw_strength: float = 0.15
@export_range(0., 10.) var asphalt_addition: float = 0.25
@export_range(0., 10.) var asphalt_removal: float = 0.25
@export_range(0., 1.) var draw_radius: float = 0.03:
	set(v):
		draw_radius = v
		if road_chunk: road_chunk.set_update_brush_radius(draw_radius)

var active_tool: ToolPanel.Tools = ToolPanel.Tools.UNKNOWN
var tool_session_ongoing: bool = false
func select_tool(tool: ToolPanel.Tools) -> void:
	if runways.has(tool):
		if tool_session_ongoing and runways.has(tool):
			runways[tool].interrupt_deployment()
			if HUD: HUD.visible = true
			view.make_current()
		tool_session_ongoing = true
		tool_nodes[tool].reset_color()
		runways[tool].initiate_deployment()
		runways[tool].payload_left.connect(func():
			if HUD: HUD.visible = false,
			CONNECT_ONE_SHOT
		)
		runways[tool].payload_entered.connect(func():
			tool_session_ongoing = false
			if HUD: HUD.visible = true
			view.make_current(),
			CONNECT_ONE_SHOT
		)
	elif road_chunk and tool_nodes.has(tool):
		road_chunk.configure_to(tool_nodes[tool])
		if trajectory:
			trajectory.is_enabled = tool_nodes[tool].controlled_by == RoadworkTool.ControlMethods.DRAWN
	active_tool = tool

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
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if active_tool != ToolPanel.Tools.UNKNOWN:
			if active_tool == ToolPanel.Tools.SHOVEL and event.pressed:
				$ShovelSound.play()
				dig_shovel_into(view.cursor.global_position)
			if tool_nodes.has(active_tool):
				asphalt_delta = tool_nodes[active_tool].tool_strength
		view.lock_view(event.is_pressed())
		if tool_nodes.has(active_tool) and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.DRAGGED:
			if event.is_pressed(): tool_nodes[active_tool].start_working()
			else: tool_nodes[active_tool].stop_working()

func _ready() -> void:
	if trajectory: # Connect trajectory drawn signal if a drawn trajectory is available
		for tool in get_children(): if tool is RoadworkTool and tool.controlled_by == RoadworkTool.ControlMethods.DRAWN:
			trajectory.trajectory_drawn.connect(tool.trajectory_drawn)

const VALUE_EPSILON: float = 0.001;
func _process(delta: float) -> void:
	# Set the asphalt being updated
	if tool_nodes.has(active_tool):
		if tool_nodes[active_tool].is_working:
			# Configure the level to be updated based on the tool
			#TODO: check for roller is_working in editor (dragged)
			#TODO: check if roller is working on level ( piloted through runway )
			#TODO: implement roller controlled by trajectory
			road_chunk.set_update_brush_amount(asphalt_delta * delta)
			road_chunk.set_update_brush_center(tool_nodes[active_tool].global_position)
			road_chunk.set_tool_angle(Vector2(-tool_nodes[active_tool].basis.z.x, -tool_nodes[active_tool].basis.z.z).angle())
			if (active_tool == ToolPanel.Tools.PAVER):
				road_chunk.set_paver_brush_height_by(tool_nodes[active_tool].global_position.y + tool_nodes[active_tool].tool_strength)
			tool_nodes[active_tool].work_at_cursor(view.cursor.global_position)
			road_chunk.update_asphalt()
		else:
			asphalt_delta *= (1. - tool_nodes[active_tool].tool_responsiveness)
			if abs(asphalt_delta) < VALUE_EPSILON: asphalt_delta = 0.
