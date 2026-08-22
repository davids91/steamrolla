class_name Trajectory
extends Path3D

signal trajectory_drawn(follower: PathFollow3D, duration_sec: float, call_when_done: Callable)

@export var player_view: PlayerView
@export var curve_distance_threshold: float = 1.
@export var flat_distance_threshold: float = 10.
@export_range(0.01, 1.) var normalized_dot_diff_threshold: float = 0.95

func _cleanup()-> void:
	trajectory_duration = 0.
	curve.clear_points()

var is_enabled: bool = false
var is_drawing: bool = false
func _unhandled_input(event: InputEvent) -> void:
	if is_enabled and event is InputEventMouseButton:
		is_drawing = event.is_pressed()
		if not is_drawing:
			# Extend the curve with a point at the edge of the level
			add_new_segment(get_nearest_at_level_edge_to(curve.get_point_position(curve.point_count - 1)))
			if trajectory_drawn.has_connections(): trajectory_drawn.emit($TrajectoryControl, trajectory_duration, _cleanup)
			else: _cleanup()

func add_new_segment(to: Vector3) -> void:
	curve.add_point(to)
	curve.set_point_position(curve.point_count - 1, to)

var trajectory_duration: float = 0.
func _process(delta: float) -> void:
	if is_drawing: trajectory_duration += delta

func get_nearest_at_level_edge_to(p: Vector3) -> Vector3:
	var result: Vector3 = p
	var x_bound_min: float = level.global_position.x - level.get_size().x / 2.
	var x_bound_max: float = level.global_position.x + level.get_size().x / 2.
	var z_bound_min: float = level.global_position.z - level.get_size().z / 2.
	var z_bound_max: float = level.global_position.z + level.get_size().z / 2.
	var z_bound_min_position: Vector3 = Vector3(result.x, result.y, z_bound_min)
	var z_bound_min_distance_to_target: float = (result - z_bound_min_position).length()
	var z_bound_max_position: Vector3 = Vector3(result.x, result.y, z_bound_max)
	var z_bound_max_distance_to_target: float = (result - z_bound_max_position).length()
	var x_bound_min_position: Vector3 = Vector3(x_bound_min, result.y, result.z)
	var x_bound_min_distance_to_target: float = (result - x_bound_min_position).length()
	var x_bound_max_position: Vector3 = Vector3(x_bound_max, result.y, result.z)
	var x_bound_max_distance_to_target: float = (result - x_bound_max_position).length()
	var current_distance_to_target: float = INF # The given point should never be chosen
	if(z_bound_min_distance_to_target < current_distance_to_target):
		result = z_bound_min_position
		current_distance_to_target = z_bound_min_distance_to_target
	if(z_bound_max_distance_to_target < current_distance_to_target):
		result = z_bound_max_position
		current_distance_to_target = z_bound_max_distance_to_target
	if(x_bound_min_distance_to_target < current_distance_to_target):
		result = x_bound_min_position
		current_distance_to_target = x_bound_min_distance_to_target
	if(x_bound_max_distance_to_target < current_distance_to_target):
		result = x_bound_max_position
		current_distance_to_target = x_bound_max_distance_to_target
	return result

@export var level: RoadChunk
func _physics_process(_delta: float) -> void:
	if not is_drawing: return
	if curve.point_count <= 1:
		# Check which positions on the level edge would be closer to the current cursor
		# And start the trajectory from there
		add_new_segment(get_nearest_at_level_edge_to(player_view.cursor.global_position));
		return
	var last_segment_direction = (curve.get_point_position(curve.point_count - 1) - curve.get_point_position(curve.point_count - 2)).normalized()
	var to_cursor: Vector3 = player_view.cursor.global_position - curve.get_point_position(curve.point_count - 1)
	var cursor_distance = to_cursor.length()
	to_cursor = to_cursor.normalized()
	if( # Add a new point if the current point is far enough from the previous one
		cursor_distance > flat_distance_threshold
		or ( # Or the angle differs too much
			abs(last_segment_direction.dot(to_cursor)) < normalized_dot_diff_threshold
			and cursor_distance > curve_distance_threshold
		)
	): add_new_segment(player_view.cursor.global_position)
	elif abs(last_segment_direction.dot(to_cursor)) > normalized_dot_diff_threshold:
		# The latest segment can be updated if it's close enough to the intended curve
		curve.set_point_position(curve.point_count - 1, player_view.cursor.global_position)
