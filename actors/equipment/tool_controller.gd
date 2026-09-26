extends Node3D

signal deployment_changed(tool: ToolPanel.Tools, deployed: bool)

@export var trajectory: Trajectory
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

## Tools deployed by the runway (if the given tool has an assigned runway)
var deployed_tools: Array[ToolPanel.Tools] = []
func _ready() -> void:
	# Connect driver intention changed signals for piloted tools
	for c in get_children():
		if(
			"controlled_by" in c and c.controlled_by == RoadworkTool.ControlMethods.PILOTED
			and c.has_signal("driver_intention_changed")
		): c.driver_intention_changed.connect(piloted_tool_driver_intention_changed)

	# Runway deployment signals
	for r in runways:
		runways[r].payload_left.connect(func():
			if not deployed_tools.has(active_tool):
				deployed_tools.push_back(active_tool)
				deployment_changed.emit(active_tool, true)
		)
		runways[r].payload_entered.connect(func():
			tool_session_ongoing = false
			runways[r].stop_deployment()
			deployed_tools.erase(active_tool)
			deployment_changed.emit(active_tool, false)
			select_tool(active_tool)
		)

	# Storage and retrieval of the positions of the deployed tools
	road_chunk.user_data_saved.connect(func():LevelStructure.level_attribute_store(
		road_chunk.used_base_dir, "tool_positions", get_deployed_tool_positions()
	))
	var readout = LevelStructure.level_attribute_data_read(road_chunk.used_base_dir, "tool_positions")
	var tool_transforms: Dictionary[ToolPanel.Tools, Transform3D]
	if readout is Dictionary[ToolPanel.Tools, Transform3D]: tool_transforms = readout

	if tool_transforms: # If any positions are stored, update the tools based on them
		for c in get_children(): if c is RoadworkTool:
			if tool_transforms.has(c.tool_enum):
				deployed_tools.push_back(c.tool_enum)
				c.global_transform = tool_transforms[c.tool_enum]
				deployment_changed.emit(c.tool_enum, true)
			elif runways.has(c.tool_enum): # Hide undeployed, but deployable tools
				c.set_color(Color.TRANSPARENT)

func piloted_tool_driver_intention_changed(is_moving: bool, forward: bool) -> void:
	if ( # Update angle of piloted tool based on driver intention
		is_moving and tool_nodes.has(active_tool) and tool_nodes[active_tool]
		and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.PILOTED
	):
		if forward: road_chunk.tool_angle_offset = tool_nodes[active_tool].tool_angle
		else: road_chunk.tool_angle_offset = tool_nodes[active_tool].tool_angle + PI

## Provide the positions of the deployed tools
func get_deployed_tool_positions() -> Dictionary[ToolPanel.Tools, Transform3D]:
	var positions: Dictionary[ToolPanel.Tools, Transform3D]
	for c in get_children(): if c is RoadworkTool and deployed_tools.has(c.tool_enum):
		positions[c.tool_enum] = c.global_transform
	return positions

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
	view.make_current()
	if runways.has(active_tool):
		tool_nodes[active_tool].stop_working()
		runways[active_tool].stop_deployment()
		tool_nodes[active_tool].prepare_for_runway()
		if tool != active_tool and not deployed_tools.has(active_tool):
			tool_nodes[active_tool].set_color(Color.TRANSPARENT)
	if tool_nodes.has(active_tool) and tool_nodes[active_tool] and tool != active_tool:
		# Rewire driver intention changed
		tool_nodes[active_tool].driver_intention_changed.disconnect(piloted_tool_driver_intention_changed)
		tool_nodes[active_tool].driver_intention_changed.connect(piloted_tool_driver_intention_changed)

		# Hide undeployed tool
		if not deployed_tools.has(active_tool): tool_nodes[active_tool].set_color(Color.TRANSPARENT)

	# Initiate runway logic
	if( #  if runway is available, it's not deployed already
		runways.has(tool) and not deployed_tools.has(tool)
		# and the tool is not controlled by a trajectory
		and tool_nodes[tool].controlled_by != RoadworkTool.ControlMethods.DRAWN
	):
		if tool_session_ongoing: runways[tool].stop_deployment()
		tool_session_ongoing = true
		tool_nodes[tool].reset_color()
		runways[tool].carrying = tool_nodes[tool]
		runways[tool].initiate_deployment()
	elif road_chunk and tool_nodes.has(tool):# No runway available or tool already deployed
		road_chunk.configure_to(tool_nodes[tool]) # Configure tool
		if runways.has(tool): # Configure runway if available
			runways[tool].resume_deployment()
			runways[tool].carrying = tool_nodes[tool]
			runways[tool].following = tool_nodes[tool]
		if( # Also resume work on Drawn and Piloted tools
			tool_nodes[tool].controlled_by == RoadworkTool.ControlMethods.DRAWN
			or tool_nodes[tool].controlled_by == RoadworkTool.ControlMethods.PILOTED
		): tool_nodes[tool].start_working()

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
	if active_tool == ToolPanel.Tools.UNKNOWN: return

	# Handle releasing the payload
	if Input.is_action_just_pressed("deploy_payload"):
		tool_nodes[active_tool].payload_triggered = true
	elif Input.is_action_just_released("deploy_payload"):
		tool_nodes[active_tool].payload_triggered = false

	# Handle dragged control method and shovel
	if event is InputEventMouseButton:
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
	# Configure the level to be updated based on the active tool
	if tool_nodes.has(active_tool):
		if tool_nodes[active_tool].is_working:
			if (tool_nodes[active_tool].payload_triggered or not tool_nodes[active_tool].has_payload):
				road_chunk.asphalt_delta = asphalt_delta * delta
				road_chunk.update_asphalt()
			tool_nodes[active_tool].work_at_cursor(view.cursor.global_position)
			road_chunk.set_update_brush_center(tool_nodes[active_tool].global_position)
			road_chunk.tool_angle = Vector2(-tool_nodes[active_tool].basis.z.x, -tool_nodes[active_tool].basis.z.z).angle()
		else:
			asphalt_delta *= (1. - tool_nodes[active_tool].tool_responsiveness)
			if abs(asphalt_delta) < VALUE_EPSILON: asphalt_delta = 0.
