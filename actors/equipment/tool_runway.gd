class_name Runway
extends Node3D

signal payload_left()
signal payload_entered()

@export var level: RoadChunk
@export var player_cursor: Node3D
@export var parking_spots: Dictionary[ToolPanel.Tools, Marker3D]
@export var parked_tools: Array[RoadworkTool]
@export var tool_movement_responsiveness: float = 0.9

func ready_to_deploy() -> bool:
	return tool_selected_to_deploy != null

var tool_selected_to_deploy: RoadworkTool
func call_twice_to_deploy(tool: RoadworkTool) -> void:
	if tool_selected_to_deploy == tool: # Stop runway to help deploy tool
		following = tool_selected_to_deploy
		player_cursor.visible = false
	elif parked_tools.has(tool): # Select tool for deployment if it isn't already
		following = player_cursor
		player_cursor.visible = true
		tool_selected_to_deploy = tool
		parked_tools.erase(tool)

@onready var following: Node3D
@onready var runway_height: float = global_position.y
@onready var target_global_position: Vector3 = global_position
const hidden_depth: float = -500;
var tools_may_be_outside_bounds: Array[RoadworkTool]
func _physics_process(_delta: float) -> void:
	# Calculate Horizontal trajectory of the runway
	var x_bound_min: float = level.global_position.x - level.get_size().x / 2. - $Shape.shape.size.x / 2.
	var x_bound_max: float = level.global_position.x + level.get_size().x / 2. + $Shape.shape.size.x / 2.
	var z_bound_min: float = level.global_position.z - level.get_size().z / 2. - $Shape.shape.size.z / 2.
	var z_bound_max: float = level.global_position.z + level.get_size().z / 2. + $Shape.shape.size.z / 2.

	if( # If the followed object is within level bounds
		following
		and (
			following.global_position.x >= x_bound_min and following.global_position.x < x_bound_max
			and following.global_position.z >= z_bound_min and following.global_position.z < z_bound_max
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
	next_transform.origin = lerp(global_position, target_global_position, 0.3)
	var center_x_dif: float = next_transform.origin.x - level.global_position.x
	var center_z_dif: float = next_transform.origin.z - level.global_position.z
	var next_global_orientation_target: Vector3 = next_transform.origin + (
		Vector3(center_x_dif, 0., 0.) if abs(center_x_dif) > abs(center_z_dif) else Vector3(0., 0., center_z_dif)
	)
	next_transform = next_transform.looking_at(next_global_orientation_target)
	global_transform = next_transform

	# Move parked tools together with the runway
	for t in parked_tools: t.global_transform = parking_spots[t.tool_enum].global_transform
	for i in tools_may_be_outside_bounds.size():
		if i >= tools_may_be_outside_bounds.size(): break
		var maybe_oob_tool: RoadworkTool = tools_may_be_outside_bounds[i]
		if parking_spots.has(maybe_oob_tool.tool_enum):
			if( # Move roadwork tool to parking spot if it's outside bounds
				maybe_oob_tool.global_position.x < x_bound_min or maybe_oob_tool.global_position.x >= x_bound_max
				or maybe_oob_tool.global_position.z < z_bound_min or maybe_oob_tool.global_position.z >= z_bound_max
			): maybe_oob_tool.global_transform = lerp(
				maybe_oob_tool.global_transform,
				parking_spots[maybe_oob_tool.tool_enum].global_transform,
				tool_movement_responsiveness
			)
			if (maybe_oob_tool.global_position - parking_spots[maybe_oob_tool.tool_enum].global_position).length() < 5.:
				tools_may_be_outside_bounds.remove_at(i)
		else: tools_may_be_outside_bounds.remove_at(i)

	if tool_selected_to_deploy and not tool_selected_to_deploy.is_working:
		tool_selected_to_deploy.global_transform = lerp(
			tool_selected_to_deploy.global_transform, global_transform, tool_movement_responsiveness
		)

func _on_deployment_area_area_entered(area: Area3D) -> void:
	if not tool_selected_to_deploy and area.get_parent() is RoadworkTool:
		var incoming_tool: RoadworkTool = area.get_parent()
		if parking_spots.has(incoming_tool.tool_enum): parked_tools.push_back(incoming_tool)
		payload_entered.emit()

func _on_deployment_area_area_exited(area: Area3D) -> void:
	if tool_selected_to_deploy and tool_selected_to_deploy.is_working and area.get_parent() == tool_selected_to_deploy:
		following = tool_selected_to_deploy
		parked_tools.erase(tool_selected_to_deploy)
		tool_selected_to_deploy = null
		payload_left.emit()
