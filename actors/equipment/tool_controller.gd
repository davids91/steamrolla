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
		if road_chunk: road_chunk.update_brush_radius = draw_radius

func piloted_tool_driver_intention_changed(is_moving: bool, forward: bool) -> void:
	if ( # Update angle of piloted tool based on driver intention
		is_moving and tool_nodes.has(active_tool) and tool_nodes[active_tool]
		and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.PILOTED
	):
		if forward: road_chunk.tool_angle_offset = tool_nodes[active_tool].tool_angle
		else: road_chunk.tool_angle_offset = tool_nodes[active_tool].tool_angle + PI

var active_tool: ToolPanel.Tools = ToolPanel.Tools.UNKNOWN
var tool_session_ongoing: bool = false
func select_tool(tool: ToolPanel.Tools) -> void:
	# Rewire trajectory drawn signal if a drawn trajectory is available
	if trajectory:
		if tool_nodes.has(active_tool) and tool_nodes[active_tool] and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.DRAWN:
			trajectory.trajectory_drawn.disconnect(tool_nodes[active_tool].trajectory_drawn)
		if tool_nodes.has(tool) and tool_nodes[tool].controlled_by == RoadworkTool.ControlMethods.DRAWN: 
			trajectory.trajectory_drawn.connect(tool_nodes[tool].trajectory_drawn)

	# Cleanup after previously used tool
	if runways.has(active_tool):
		runways[active_tool].stop_deployment()
	if tool_nodes.has(active_tool) and tool_nodes[active_tool] and tool != active_tool:
		tool_nodes[active_tool].set_color(Color.TRANSPARENT)
		# Rewire driver intention changed
		tool_nodes[active_tool].driver_intention_changed.disconnect(piloted_tool_driver_intention_changed)
		tool_nodes[tool].driver_intention_changed.connect(piloted_tool_driver_intention_changed)

	# Initiate runway logic if runway is available and the tool is not controlled by a trajectory
	if runways.has(tool) and tool_nodes[tool].controlled_by != RoadworkTool.ControlMethods.DRAWN:
		if tool_session_ongoing:
			runways[tool].stop_deployment()
			if HUD: HUD.visible = true
			view.make_current()
		tool_session_ongoing = true
		tool_nodes[tool].reset_color()
		runways[tool].carrying = tool_nodes[tool]
		runways[tool].initiate_deployment()
		runways[tool].payload_left.connect(func(): if HUD: HUD.visible = false, CONNECT_ONE_SHOT)
		runways[tool].payload_entered.connect(func():
			tool_session_ongoing = false
			if HUD: HUD.visible = true
			view.make_current()
			runways[tool].stop_deployment()
			select_tool(tool),
			CONNECT_ONE_SHOT
		)
	elif road_chunk and tool_nodes.has(tool): # No runway available, simply configure tool
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

const VALUE_EPSILON: float = 0.001;
func _process(delta: float) -> void:
	# Set the asphalt being updated
	if tool_nodes.has(active_tool):
		if tool_nodes[active_tool].is_working:
			# Configure the level to be updated based on the tool
			road_chunk.asphalt_delta = asphalt_delta * delta
			road_chunk.set_update_brush_center(tool_nodes[active_tool].global_position)
			road_chunk.tool_angle = Vector2(-tool_nodes[active_tool].basis.z.x, -tool_nodes[active_tool].basis.z.z).angle()
			if (active_tool == ToolPanel.Tools.PAVER):
				road_chunk.paver_height = tool_nodes[active_tool].global_position.y + tool_nodes[active_tool].tool_strength
			tool_nodes[active_tool].work_at_cursor(view.cursor.global_position)
			road_chunk.update_asphalt()
		else:
			asphalt_delta *= (1. - tool_nodes[active_tool].tool_responsiveness)
			if abs(asphalt_delta) < VALUE_EPSILON: asphalt_delta = 0.
