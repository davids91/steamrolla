extends Node3D

@export var level: RoadChunk
@export var following: Node3D

@onready var level_size: Vector3 = level.get_size()
@onready var runway_height: float = global_position.y

var target_global_position: Vector3
func _physics_process(_delta: float) -> void:
	# Set Vertical trajectory of the runway
	target_global_position.y = (
		runway_height
		- (
			Vector2(global_position.x, global_position.z)
			- Vector2(target_global_position.x, target_global_position.z)
		).length()
	)

	# Calculate Horizontal trajectory of the runway
	var x_bound_min: float = level.global_position.x - level_size.x / 2.
	var x_bound_max: float = level.global_position.x + level_size.x / 2.
	var z_bound_min: float = level.global_position.z - level_size.z / 2.
	var z_bound_max: float = level.global_position.z + level_size.z / 2.
	if(
		following.global_position.x < x_bound_min or following.global_position.x > x_bound_max
		or following.global_position.z < z_bound_min or following.global_position.z > z_bound_max
	): return # Do not move runway if roller is outside the level

	x_bound_min -= $Shape.shape.size.x / 2.
	x_bound_max += $Shape.shape.size.x / 2.
	z_bound_min -= $Shape.shape.size.z / 2.
	z_bound_max += $Shape.shape.size.z / 2.
	
	var current_distance_to_target: float = (following.global_position - global_position).length()
	# Check which positions would be closer to the target
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

	# Move towards target position
	global_position = lerp(global_position, target_global_position, 0.3)
