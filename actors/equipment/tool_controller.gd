extends Node3D

@export var trajectory: Trajectory
@export var view: PlayerView
@export var level: RoadChunk
@export var runway: Runway
@export var tool_nodes: Dictionary[ToolPanel.Tools, RoadworkTool]

@export_range(0., 10.) var draw_strength: float = 0.15
@export_range(0., 10.) var asphalt_addition: float = 0.25
@export_range(0., 10.) var asphalt_removal: float = 0.25
@export_range(0., 1.) var draw_radius: float = 0.03:
	set(v):
		draw_radius = v
		if level: level.update_brush_radius = draw_radius

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
	runway.payload_left.connect(func():
		if not tool_nodes.has(active_tool) or deployed_tools.has(active_tool): return
		deployed_tools.push_back(active_tool)
		if( # Camera transition from level overview if tool camera is available
				view.get_current()
				and tool_nodes[active_tool].get_node_or_null("OrbitCamera")
				and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.PILOTED
		): view.transition_to(tool_nodes[active_tool].get_node("OrbitCamera"))
	)
	runway.payload_entered.connect(func():
		if not tool_nodes.has(active_tool): return
		runway.tools_may_be_outside_bounds.push_back(tool_nodes[active_tool])
		if( # Camera transition from piloted camera to player view if the tool camera is active
			tool_nodes[active_tool].get_node_or_null("OrbitCamera")
			and tool_nodes[active_tool].get_node("OrbitCamera").get_current()
			and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.PILOTED
		): (tool_nodes[active_tool].get_node("OrbitCamera") as OrbitCamera3D).transition_to(view)
		deployed_tools.erase(active_tool)
		select_tool(ToolPanel.Tools.UNKNOWN)
	)

	# Storage and retrieval of the positions of the deployed tools
	level.user_data_saved.connect(func(): LevelStructure.level_attribute_store(
		level.used_base_dir, "tool_positions", get_deployed_tool_positions()
	))
	var readout = LevelStructure.level_attribute_data_read(level.used_base_dir, "tool_positions")
	var tool_transforms: Dictionary[ToolPanel.Tools, Transform3D]
	if readout is Dictionary[ToolPanel.Tools, Transform3D]: tool_transforms = readout

	if tool_transforms: # If any positions are stored, update the tools based on them
		for c in get_children(): if c is RoadworkTool:
			if tool_transforms.has(c.tool_enum):
				deployed_tools.push_back(c.tool_enum)
				c.global_transform = tool_transforms[c.tool_enum]

func piloted_tool_driver_intention_changed(is_moving: bool, forward: bool) -> void:
	if ( # Update angle of piloted tool based on driver intention
		is_moving and tool_nodes.has(active_tool) and tool_nodes[active_tool]
		and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.PILOTED
	):
		if forward: level.tool_angle_offset = tool_nodes[active_tool].tool_angle
		else: level.tool_angle_offset = tool_nodes[active_tool].tool_angle + PI

## Provide the positions of the deployed tools
func get_deployed_tool_positions() -> Dictionary[ToolPanel.Tools, Transform3D]:
	var positions: Dictionary[ToolPanel.Tools, Transform3D]
	for c in get_children(): if c is RoadworkTool and deployed_tools.has(c.tool_enum):
		positions[c.tool_enum] = c.global_transform
	return positions

var asphalt_delta: float = 0.
var active_tool: ToolPanel.Tools = ToolPanel.Tools.UNKNOWN
func select_tool(tool: ToolPanel.Tools) -> void:
	# Cleanup after previously used tool
	if tool_nodes.has(active_tool) and tool_nodes[active_tool] and tool != active_tool:
		tool_nodes[active_tool].stop_working()
		tool_nodes[active_tool].prepare_for_runway()
		runway.tools_may_be_outside_bounds.push_back(tool_nodes[active_tool])

		# Rewire driver intention changed
		if tool_nodes[active_tool].driver_intention_changed.is_connected(piloted_tool_driver_intention_changed):
			tool_nodes[active_tool].driver_intention_changed.disconnect(piloted_tool_driver_intention_changed)
		tool_nodes[active_tool].driver_intention_changed.connect(piloted_tool_driver_intention_changed)

		if( # Camera transition from the piloted tool to level overview
			tool_nodes[active_tool].get_node_or_null("OrbitCamera")
			and tool_nodes[active_tool].get_node("OrbitCamera").get_current()
			and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.PILOTED
		): tool_nodes[active_tool].get_node("OrbitCamera").transition_to(view)

	# Rewire trajectory drawn signal if a drawn trajectory is available
	if trajectory:
		if tool_nodes.has(active_tool) and tool_nodes[active_tool] and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.DRAWN:
			trajectory.trajectory_drawn.disconnect(tool_nodes[active_tool].trajectory_drawn)
		if tool_nodes.has(tool):
			trajectory.is_enabled = tool_nodes[tool].controlled_by == RoadworkTool.ControlMethods.DRAWN
			if tool_nodes[tool].controlled_by == RoadworkTool.ControlMethods.DRAWN:
				trajectory.trajectory_drawn.connect(tool_nodes[tool].trajectory_drawn)

	# Early exit if no tools are selected
	if tool == ToolPanel.Tools.UNKNOWN:
		view.cursor.visible = true
		return

	if tool_nodes.has(tool): # Configure tool for level and runway
		var ready_to_deploy = runway.ready_to_deploy()
		runway.call_twice_to_deploy(tool_nodes[tool])
		if (
			tool_nodes[tool].controlled_by == RoadworkTool.ControlMethods.DRAGGED
			or level.is_within_bounds(tool_nodes[tool].global_position)
		): # Deploy drawn tools and tools within the level from the get go
			runway.call_twice_to_deploy(tool_nodes[tool])
			ready_to_deploy = true
		if level and ready_to_deploy:
			asphalt_delta = tool_nodes[tool].tool_strength
			level.configure_to(tool_nodes[tool]) # Configure tool
			tool_nodes[tool].start_working()
			if( # Camera transition from level overview if tool camera is available
				view.get_current()
				and tool_nodes[tool].get_node_or_null("OrbitCamera")
				and tool_nodes[tool].controlled_by == RoadworkTool.ControlMethods.PILOTED
			): view.transition_to(tool_nodes[tool].get_node("OrbitCamera"))
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

func _unhandled_input(event: InputEvent) -> void:
	# Handle releasing the payload
	if Input.is_action_just_pressed("deploy_payload"):
		tool_nodes[active_tool].payload_triggered = true
	elif Input.is_action_just_released("deploy_payload"):
		tool_nodes[active_tool].payload_triggered = false

	# Handle dragged control method and shovel
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_MIDDLE:
		if event.is_pressed():
			# Select desired(pointed at) tool and deactivate selection, confirm deployment if ready!
			if UsageIndicator.displayed and UsageIndicator.displayed.get_parent() is RoadworkTool:
				select_tool(UsageIndicator.displayed.get_parent().tool_enum)
				UsageIndicator.displayed = null
			elif runway.ready_to_deploy(): select_tool(active_tool)


			# Lock View if the currently active tool is controlled by mouse drag
			view.lock_view(
				event.is_pressed() and tool_nodes.has(active_tool)
				and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.DRAGGED
			)

			# Handel Shovel UI
			if active_tool == ToolPanel.Tools.SHOVEL:
				$ShovelSound.play()
				dig_shovel_into(view.cursor.global_position)
		elif(
			event.button_index == MOUSE_BUTTON_LEFT
			and tool_nodes.has(active_tool)
			and tool_nodes[active_tool].controlled_by == RoadworkTool.ControlMethods.DRAGGED
		):
			tool_nodes[active_tool].stop_working()
			view.cursor.visible = true

const VALUE_EPSILON: float = 0.001;
func _process(delta: float) -> void:
	# Configure the level to be updated based on the active tool
	if tool_nodes.has(active_tool):
		if tool_nodes[active_tool].is_working:
			if (tool_nodes[active_tool].payload_triggered or not tool_nodes[active_tool].has_payload):
				level.asphalt_delta = asphalt_delta * delta
				level.update_asphalt()
			tool_nodes[active_tool].work_at_cursor(view.cursor.global_position)
			level.set_update_brush_center(tool_nodes[active_tool].global_position)
			level.tool_angle = Vector2(-tool_nodes[active_tool].basis.z.x, -tool_nodes[active_tool].basis.z.z).angle()
		else:
			asphalt_delta *= (1. - tool_nodes[active_tool].tool_responsiveness)
			if abs(asphalt_delta) < VALUE_EPSILON: asphalt_delta = 0.

func _on_hud_exit_scene() -> void:
	# Call deferred to ensure order of execution, HUD::exit_scene has many listeners
	runway.tools_may_be_outside_bounds.push_back(tool_nodes[active_tool])
	select_tool.call_deferred(ToolPanel.Tools.UNKNOWN)
