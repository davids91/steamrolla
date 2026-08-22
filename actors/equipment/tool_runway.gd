class_name Runway
extends Node3D

signal payload_deployed()
signal payload_left()
signal payload_entered()

enum State{
	## State of the runway not being shown
	HIDDEN,

	## Player decides where to deploy the carried tool
	PLACEMENT,

	## Player Deployed the carried tool, Runway awaits the tool re-entering 
	DEPLOYED,
	
	## The carried tool left the Runway, Runway is awaiting re-entry
	RELEASED, 
}

@export var level: RoadChunk
@export var player_cursor: Node3D
@export var carrying: RoadworkTool

@onready var following: Node3D = player_cursor
@onready var runway_height: float = global_position.y

var current_state: State = State.HIDDEN
func initiate_deployment() -> void:
	following = player_cursor
	current_state = State.PLACEMENT

func stop_deployment() -> void:
	current_state = State.HIDDEN
	following = player_cursor
	carrying.stop_working()

func _unhandled_input(event: InputEvent) -> void:
	if current_state == State.PLACEMENT and event.is_action_pressed("deploy_tool"):
		current_state = State.DEPLOYED
		payload_deployed.emit()
		level.configure_to(carrying)
		carrying.start_working()
		following = carrying

var target_global_position: Vector3
const hidden_depth: float = -500;
func _physics_process(_delta: float) -> void:
	if current_state == State.HIDDEN: target_global_position.y = hidden_depth
	elif current_state == State.PLACEMENT || current_state == State.DEPLOYED || current_state == State.RELEASED:
		# Calculate Horizontal trajectory of the runway
		var x_bound_min: float = level.global_position.x - level.get_size().x / 2.
		var x_bound_max: float = level.global_position.x + level.get_size().x / 2.
		var z_bound_min: float = level.global_position.z - level.get_size().z / 2.
		var z_bound_max: float = level.global_position.z + level.get_size().z / 2.
		if(
			following.global_position.x < x_bound_min or following.global_position.x > x_bound_max
			or following.global_position.z < z_bound_min or following.global_position.z > z_bound_max
		): return # Do not move runway if target is outside the level

		x_bound_min -= $Shape.shape.size.x / 2.
		x_bound_max += $Shape.shape.size.x / 2.
		z_bound_min -= $Shape.shape.size.z / 2.
		z_bound_max += $Shape.shape.size.z / 2.
		
		# Check which positions at the levels edge would be best for the runway
		var current_distance_to_target: float = (following.global_position - global_position).length()
		if(not(
			following.global_position.x < x_bound_min or following.global_position.x > x_bound_max
			or following.global_position.z < z_bound_min or following.global_position.z > z_bound_max
		)): current_distance_to_target = INF # Runway is inside the level, it shouldn't stay there!
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

		# Set carried tool position and angle
		if current_state == State.PLACEMENT and carrying:
			carrying.global_position = global_position
			var target_x_dif: float = target_global_position.x - level.global_position.x
			var target_z_dif: float = target_global_position.z - level.global_position.z
			if abs(target_x_dif) > abs(target_z_dif):
				carrying.look_at(carrying.global_position + Vector3(target_x_dif, 0., 0.))
			else: carrying.look_at(carrying.global_position + Vector3(0., 0., target_z_dif))

	# Move towards target position
	global_position = lerp(global_position, target_global_position, 0.3)

var payload_inside_deployment: bool = false
func _on_deployment_area_area_entered(area: Area3D) -> void:
	if area.get_parent() == carrying:
		payload_inside_deployment = true
		if current_state == State.RELEASED:
			payload_entered.emit()

func _on_deployment_area_area_exited(area: Area3D) -> void:
	if area.get_parent() == carrying:
		payload_inside_deployment = false
		if current_state == State.DEPLOYED:
			current_state = State.RELEASED
			payload_left.emit()
