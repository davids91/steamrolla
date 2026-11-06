class_name BaseLevel
extends Node3D

@export var accepted_asphalt_deviation: float = 0.005
@export var accepted_crashed_cars: int = 0
@export var level_objectives: Dictionary[String, String] = {"asphalt_done": "Fix road surface", "traffic_ok": "No crashed cars"}
@export var level_objective_photos: Array[Texture] = []
@export var transition_time_sec: float = 0.5
@export var max_cars_count: int = 30

@onready var base_dir: String = LevelStructure.get_base_dir_for_scene(self)
@onready var deployed_tools: Array[ToolPanel.Tools] = []
func _ready() -> void:
	# Handle permanent object positional storage
	var car_transform_readouts = LevelStructure.level_attribute_data_read(base_dir, "contained_cars")
	if car_transform_readouts is Array[Transform3D]:
		for t in car_transform_readouts:
			var car: MovingCar = preload("res://actors/moving_car.tscn").instantiate()
			add_child(car)
			car.global_transform = t
			car.crashed = true
	var readout = LevelStructure.level_attribute_data_read(base_dir, "tool_positions")
	var tool_transforms: Dictionary[ToolPanel.Tools, Transform3D]
	if readout is Dictionary[ToolPanel.Tools, Transform3D]: tool_transforms = readout
	if tool_transforms: # If any positions are stored, update the tools based on them
		for tool in $ToolController.get_children(): if tool is RoadworkTool and tool_transforms.has(tool.tool_enum):
			deployed_tools.push_back(tool.tool_enum)
			tool.global_transform = tool_transforms[tool.tool_enum]
			$ToolController/Runway.register(tool)

	# Handle Objectives
	LevelStructure.level_attribute_list_overwrite(base_dir, level_objectives)
	%RoadChunk.deviation_threshold = accepted_asphalt_deviation

	# Setup HUD
	$HUD.base_dir = base_dir
	$HUD.set_objectives(level_objectives, level_objective_photos)

	# Handle Screen blocker
	%ScreenBlocker.modulate = Color.WHITE
	create_tween().tween_property(%ScreenBlocker, "modulate", Color.TRANSPARENT, transition_time_sec)

## Provide the positions of the deployed tools
func get_deployed_tool_positions() -> Dictionary[ToolPanel.Tools, Transform3D]:
	var positions: Dictionary[ToolPanel.Tools, Transform3D]
	for c in $ToolController.get_children(): if c is RoadworkTool and deployed_tools.has(c.tool_enum):
		positions[c.tool_enum] = c.global_transform
	return positions

func periodic_objective_check() -> void: pass # For levels to overwrite!

@export var objective_check_interval_sec : float = 0.5
var time_left_to_check_sec: float = objective_check_interval_sec
func _process(delta: float) -> void:
	time_left_to_check_sec -= delta
	if 0. > time_left_to_check_sec:
		time_left_to_check_sec = objective_check_interval_sec
		periodic_objective_check()

var victory_tween: Tween:
	set(v):
		if victory_tween: victory_tween.kill()
		victory_tween = v

@export var road_paint_display_pause_sec: float = 0.01
@export var max_snap_value: float = 0.6
@export var snap_time_sec: float = 0.6
@export var snap_easing: float = 1.0
func _on_hud_objective_completed(objective_name: String) -> void:
	if objective_name == "asphalt_done":
		victory_tween = create_tween()

		# Start asphalt snapping to reference and lighting up the road
		victory_tween.tween_callback(func():
			var snap_tween: Tween = create_tween()
			snap_tween.tween_method(func(w: float):
				%RoadChunk.snap_to_reference(ease(w, snap_easing))
				%RoadChunk.update_asphalt(),
				0., max_snap_value, snap_time_sec
			)
			snap_tween.tween_callback(func():
				%RoadChunk.snap_to_reference(0.)
				%RoadChunk.save_user_data()
				%RoadChunk.asphalt_editable = false
			)
			var flash_tween: Tween = create_tween()
			flash_tween.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 1.3)
			flash_tween.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 0.15)
			flash_tween.tween_method(func(w: float): %RoadChunk.set_highlight(sin(w)), 0., PI, 0.15)
		)
		victory_tween.tween_callback(func():
			while ($RoadPaint.show_random()):
				await get_tree().create_timer(road_paint_display_pause_sec).timeout
		)

var contained_traffic: Array[MovingCar] = []
func _on_hud_exit_scene() -> void: # Exit the scene when there's no active tool
	# Save permanent objects
	%RoadChunk.save_user_data(base_dir)
	var car_transforms: Array[Transform3D] = []
	for car in contained_traffic: car_transforms.push_back(car.global_transform)
	LevelStructure.level_attribute_store(base_dir, "contained_cars", car_transforms)
	LevelStructure.level_attribute_store(base_dir, "tool_positions", get_deployed_tool_positions())

	# Start exit transition
	var transition = create_tween()
	transition.tween_property(%ScreenBlocker, "modulate", Color.WHITE, transition_time_sec)
	transition.tween_callback(SceneManager.return_to_level_select.bind(base_dir))

func _on_out_of_bounds_checker_body_entered(body: Node3D) -> void:
	if body is MovingCar:
		contained_traffic.push_back(body)
		for m in get_tree().get_nodes_in_group("TrafficMakers"):
			m.is_active = max_cars_count > contained_traffic.size()

func _on_out_of_bounds_checker_body_exited(body: Node3D) -> void:
	if body is MovingCar:
		contained_traffic.erase(body)
		body.queue_free()
		for m in get_tree().get_nodes_in_group("TrafficMakers"):
			m.is_active = max_cars_count > contained_traffic.size()
	elif body is RoadworkTool:
		$ToolController/Runway.may_be_outside_bounds(body)
		if not $RoadChunk.is_within_bounds(body.global_position) and $ToolController.active_tool == body.tool_enum:
			$ToolController.select_tool(ToolPanel.Tools.UNKNOWN)

func _on_runway_payload_left(tool: RoadworkTool) -> void:
	if not deployed_tools.has(tool.tool_enum): deployed_tools.push_back(tool.tool_enum)

func _on_runway_payload_entered(tool: RoadworkTool) -> void:
	$ToolController/Runway.may_be_outside_bounds(tool)
	if( # Camera transition from piloted camera to player view if the tool camera is active
		tool.get_node_or_null("OrbitCamera") and tool.get_node("OrbitCamera").get_current()
		and tool.controlled_by == RoadworkTool.ControlMethods.PILOTED
	): tool.get_node("OrbitCamera").transition_to($PlayerView)
	deployed_tools.erase(tool.tool_enum)
	$ToolController.select_tool(ToolPanel.Tools.UNKNOWN)
