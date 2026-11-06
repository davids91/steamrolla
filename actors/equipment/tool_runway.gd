class_name Runway
extends Node3D

signal payload_reset(tool_enum: ToolPanel.Tools)
signal payload_left(tool: RoadworkTool)
signal payload_entered(tool: RoadworkTool)

@export var road_chunk: RoadChunk
@export var player_view: PlayerView
@export var parking_spots: Dictionary[ToolPanel.Tools, Marker3D]
@export var parked_tools: Array[RoadworkTool]
@export var tool_movement_responsiveness: float = 0.9

func ready_to_deploy() -> bool:
	return tool_selected_to_deploy != null

@export var runway_drag_guard_length_sec: float = 1.
var tool_selected_to_deploy: RoadworkTool
var dragged_tool_exiting: bool = false
func call_twice_to_deploy(tool: RoadworkTool) -> void:
	if tool_selected_to_deploy == tool: # Stop runway to help deploy tool
		following = tool_selected_to_deploy
		player_view.cursor.visible = false
		can_drag_runway = false
		get_tree().create_timer(runway_drag_guard_length_sec).timeout.connect(
			func(): can_drag_runway = true
		)
	elif parked_tools.has(tool): # Select tool for deployment if it isn't already
		if tool.controlled_by == RoadworkTool.ControlMethods.DRAGGED:
			dragged_tool_exiting = true
		following = player_view.cursor
		player_view.cursor.visible = true
		tool_selected_to_deploy = tool
		parked_tools.erase(tool)
	else: following = tool

func register(tool: RoadworkTool) -> void:
	if parking_spots.has(tool.tool_enum) and tools_in_proximity.has(tool): call_to_park(tool)
	else: parked_tools.erase(tool)

func may_be_outside_bounds(body: RoadworkTool) -> void:
	tools_may_be_outside_bounds[body as RoadworkTool] = 0

func call_to_park(tool: RoadworkTool) -> void:
	if parking_spots.has(tool.tool_enum) and not parked_tools.has(tool):
		may_be_outside_bounds(tool)
		tool.stop_working()
		tool.prepare_for_runway()
		tool_selected_to_deploy = null
		parked_tools.push_back(tool)
		following = null

@onready var following: Node3D = $OriginalPositionMarker:
	set(v):
		following = v
		if not following: following = $OriginalPositionMarker

var locked_view: bool = false
var can_drag_runway: bool = true
func _unhandled_input(event: InputEvent) -> void:
	if can_drag_runway and player_view and player_view.looking_at and player_view.looking_at is Runway:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if event is InputEventMouseMotion: $OriginalPositionMarker.global_position = player_view.cursor.global_position
			if following == $OriginalPositionMarker and not locked_view:
				locked_view = true
				player_view.lock_view(self, true)
		elif locked_view:
			locked_view = false
			player_view.lock_view(self, false)

func _ready() -> void:
	$OriginalPositionMarker.global_position = global_position

@onready var runway_height: float = global_position.y
@onready var target_global_position: Vector3 = global_position
const hidden_depth: float = -500;
var tools_may_be_outside_bounds: Dictionary[RoadworkTool, int] # Tool and the number of updates applied to its position
func _physics_process(_delta: float) -> void:
	# Calculate Horizontal trajectory of the runway
	var level_size: Vector3 = road_chunk.get_size()
	var x_bound_min: float = road_chunk.global_position.x - level_size.x / 2. - $Shape.shape.size.x / 2.
	var x_bound_max: float = road_chunk.global_position.x + level_size.x / 2. + $Shape.shape.size.x / 2.
	var y_bound_min: float = road_chunk.global_position.y - level_size.y / 2.
	var y_bound_max: float = road_chunk.global_position.y + level_size.y / 2.
	var z_bound_min: float = road_chunk.global_position.z - level_size.z / 2. - $Shape.shape.size.z / 2.
	var z_bound_max: float = road_chunk.global_position.z + level_size.z / 2. + $Shape.shape.size.z / 2.

	if( # Handle runway movement
		following
		and( # If the followed object is within level bounds
			road_chunk.is_within_bounds(following.global_position)
			or following == $OriginalPositionMarker
		)
	):
		# Check which positions at the levels edge would be best for the runway
		var current_distance_to_target: float = (following.global_position - global_position).length()
		var z_bound_min_position: Vector3 = Vector3(following.global_position.x, global_position.y, z_bound_min)
		var z_bound_min_distance_to_target: float = (following.global_position - z_bound_min_position).length()
		if(z_bound_min_distance_to_target < current_distance_to_target):
			target_global_position = z_bound_min_position
			current_distance_to_target = z_bound_min_distance_to_target

		var z_bound_max_position: Vector3 = Vector3(following.global_position.x, global_position.y, z_bound_max)
		var z_bound_max_distance_to_target: float = (following.global_position - z_bound_max_position).length()
		if(z_bound_max_distance_to_target < current_distance_to_target):
			target_global_position = z_bound_max_position
			current_distance_to_target = z_bound_max_distance_to_target

		var x_bound_min_position: Vector3 = Vector3(x_bound_min, global_position.y, following.global_position.z)
		var x_bound_min_distance_to_target: float = (following.global_position - x_bound_min_position).length()
		if(x_bound_min_distance_to_target < current_distance_to_target):
			target_global_position = x_bound_min_position
			current_distance_to_target = x_bound_min_distance_to_target

		var x_bound_max_position: Vector3 = Vector3(x_bound_max, global_position.y, following.global_position.z)
		var x_bound_max_distance_to_target: float = (following.global_position - x_bound_max_position).length()
		if(x_bound_max_distance_to_target < current_distance_to_target):
			target_global_position = x_bound_max_position
			current_distance_to_target = x_bound_max_distance_to_target

		# Set Vertical trajectory of the runway
		target_global_position.y = (
			runway_height
			- (
				Vector2(global_position.x, global_position.z)
				- Vector2(target_global_position.x, target_global_position.z)
			).length()
		)

	# Move towards target position and look at the center of the level always
	var next_transform: Transform3D = global_transform
	next_transform.origin = lerp(global_position, target_global_position, 0.35)
	var center_x_dif: float = next_transform.origin.x - road_chunk.global_position.x
	var center_z_dif: float = next_transform.origin.z - road_chunk.global_position.z
	var next_global_orientation_target: Vector3 = next_transform.origin + (
		Vector3(center_x_dif, 0., 0.) if abs(center_x_dif) > abs(center_z_dif) else Vector3(0., 0., center_z_dif)
	)
	next_transform = next_transform.looking_at(next_global_orientation_target)
	global_transform = next_transform

	# Move parked tools together with the runway
	for t in parked_tools: t.global_transform = parking_spots[t.tool_enum].global_transform

	# Check for tools that may be outside bounds
	var tools_inside_bounds: Array[RoadworkTool] = []
	for tool in tools_may_be_outside_bounds.keys():
		if parking_spots.has(tool.tool_enum):
			if( # Move roadwork tool to parking spot if it's outside bounds
				tool.global_position.x < x_bound_min or tool.global_position.x >= x_bound_max
				or tool.global_position.y < y_bound_min or tool.global_position.y >= y_bound_max
				or tool.global_position.z < z_bound_min or tool.global_position.z >= z_bound_max
			):
				tool.global_transform = lerp(
					tool.global_transform,
					parking_spots[tool.tool_enum].global_transform,
					tool_movement_responsiveness
				)
				tools_may_be_outside_bounds[tool] += 1
			else: tools_inside_bounds.push_back(tool)
			if(
				(tool.global_position - parking_spots[tool.tool_enum].global_position).length() < 5. #TechDebt: magic number is for adequate distance from parking spot
				and 10 < tools_may_be_outside_bounds[tool] #TechDebt: Magic number for the number of updates required to count tool as moved back into bounds
			):
				if "velocity" in tool: tool.velocity = Vector3.ZERO
				if "momentum" in tool: tool.momentum = Vector3.ZERO
				tools_inside_bounds.push_back(tool)
				payload_reset.emit(tool.tool_enum)
		else: tools_inside_bounds.push_back(tool)
	for tool in tools_inside_bounds: tools_may_be_outside_bounds.erase(tool)

	if tool_selected_to_deploy and not tool_selected_to_deploy.is_working:
		tool_selected_to_deploy.global_transform = lerp(
			tool_selected_to_deploy.global_transform, global_transform, tool_movement_responsiveness
		)

func _on_deployment_area_body_entered(body: Node3D) -> void:
	if body is RoadworkTool and not dragged_tool_exiting and not tool_selected_to_deploy and not parked_tools.has(body):
		call_to_park(body)
		payload_entered.emit(body)
	dragged_tool_exiting = false

func _on_deployment_area_body_exited(body: Node3D) -> void:
	if body is RoadworkTool and body == tool_selected_to_deploy and tool_selected_to_deploy and tool_selected_to_deploy.is_working:
		following = tool_selected_to_deploy
		parked_tools.erase(tool_selected_to_deploy)
		tool_selected_to_deploy = null
		payload_left.emit(following)

var tools_in_proximity: Array[RoadworkTool] = []
func _on_proximity_detector_body_entered(body: Node3D) -> void:
	if body is RoadworkTool: tools_in_proximity.push_back(body)

func _on_proximity_detector_body_exited(body: Node3D) -> void:
	if body is RoadworkTool:
		if body == tool_selected_to_deploy: tool_selected_to_deploy
		tools_in_proximity.erase(body)
