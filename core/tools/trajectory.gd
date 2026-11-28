@tool
class_name Trajectory
extends Path3D

"""
Tool to draw trajectories onto levels

Usage:
From within game(not the editor), drag the mouse with left click to draw a trajectory onto the level.
The trajectory always starts and ends from the edge of the level, edge points are automatically calculated.
The drawing duration of each segment is stored for later use. To indicate slow speed on a segment, draw it slower.
Additionally, at the start of each segment, wait times are stored
The wait times are counted based on the time spent near the start of the segment; As long as the cursor is close enough.
The stored wait times are used to make the trajectory follower sit at the start of the segment until the stored wait time,
and then finish the segment with the remaining time of the segment duration.
"""
signal trajectory_drawn(follower: PathFollow3D, data: TrajectoryData, call_when_done: Callable)

@export_category("Node Dependencies")
@export var player_view: PlayerView
@export var road_chunk: RoadChunk

@export_category("Trajectory Data")
## Data to set form the editor to load into the curve
@export var trajectory_data: TrajectoryData = TrajectoryData.new():
	set(v):
		trajectory_data = v
		if not v or not v.curves: curve.clear_points()
		else: curve = v.curves

@export_tool_button("Read Last Trajectory From RoadChunk Data", "CenterView") var scan_for_height: Callable = func():
	if road_chunk and not road_chunk.level_data.trajectories.is_empty():
		trajectory_data = road_chunk.level_data.trajectories[-1]

@export_category("Trajectory Brush Parameters")
@export var cursor_in_place_distance_threshold: float = 0.45
@export var cursor_follow_responsiveness: float = 0.3
@export var curve_distance_threshold: float = 1.
@export var flat_distance_threshold: float = 10.
@export var stopping_distance_threshold: float = 3.
@export var stopping_time_threshold_sec: float = 1.35
@export var segment_min_time_sec: float = 0.15
@export_range(0.01, 1.) var normalized_dot_diff_threshold: float = 0.95
func _cleanup()-> void:
	trajectory_data = TrajectoryData.new()

const MICROSEC_TO_SEC_MULTIPLIER: float = 0.000001
func _add_point_to_curve(to: Vector3) -> void:
	curve.add_point(to)
	trajectory_data.curves = curve
	trajectory_data.stop_durations_sec.push_back(0.)
	if trajectory_data.segment_durations_sec.size() > 1:
		trajectory_data.segment_durations_sec[-1] = float(Time.get_ticks_usec() - segment_start_us) * MICROSEC_TO_SEC_MULTIPLIER
	trajectory_data.segment_durations_sec.push_back(segment_min_time_sec)
	segment_start_us = Time.get_ticks_usec()

func _calculate_normalized_trajectory_data() -> void:
	trajectory_data.segment_normalized_progress = []
	trajectory_data.segment_normalized_progress.resize(trajectory_data.segment_durations_sec.size())
	var i: int = 0
	for duration in trajectory_data.segment_durations_sec:
		trajectory_data.segment_normalized_progress[i] = duration / trajectory_data.trajectory_duration_sec
		i += 1
	assert(
		(1. - trajectory_data.segment_normalized_progress.reduce(func(accum: float, number: float): return accum + number, 0.))
		< 0.01,
		"The sum of normalized durations should take up the whole of the trajectory"
	)

@export var is_enabled: bool = false
var is_drawing: bool = false
var segment_start_us: int = 0
var trajectory_start_us: int = 0
func _unhandled_input(event: InputEvent) -> void:
	if is_enabled and event is InputEventMouseButton:
		if not is_drawing and event.is_pressed():
			cursor_slow_pos = player_view.cursor.global_position
			cursor_time_spent_in_place_sec = 0.
			cursor_last_pos = player_view.cursor.global_position
			trajectory_start_us = Time.get_ticks_usec()
			segment_start_us = Time.get_ticks_usec()
			# Check which positions on the level edge would be closer to the current cursor
			# And start the trajectory from there
			_add_point_to_curve(_get_nearest_at_level_edge_to(player_view.cursor.global_position))
			_add_point_to_curve(player_view.cursor.global_position)
		if is_drawing and not event.is_pressed(): # When the mouse is released
			# Extend the curve with a point at the edge of the level
			_add_point_to_curve(_get_nearest_at_level_edge_to(curve.get_point_position(curve.point_count - 1)))

			# The last duration and stop time interval points are invalid
			trajectory_data.segment_durations_sec.pop_back()
			trajectory_data.stop_durations_sec.pop_back()

			# Finalize trajectory
			trajectory_data.trajectory_duration_sec = float(Time.get_ticks_usec() - trajectory_start_us) * MICROSEC_TO_SEC_MULTIPLIER
			_calculate_normalized_trajectory_data()
			if trajectory_drawn.has_connections(): trajectory_drawn.emit($TrajectoryControl, trajectory_data, _cleanup)
			else: _cleanup()
		is_drawing = event.is_pressed()

func _get_nearest_at_level_edge_to(p: Vector3) -> Vector3:
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
@onready var cursor_slow_pos: Vector3 = player_view.cursor.global_position
@onready var cursor_last_pos: Vector3 = player_view.cursor.global_position
@onready var cursor_time_spent_in_place_sec: float = 0.
func _physics_process(delta: float) -> void:
	if not is_drawing: return
	if curve.point_count < 1: return # Only extend a trajectory that already has a point
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
	): _add_point_to_curve(player_view.cursor.global_position)
	elif abs(last_segment_direction.dot(to_cursor)) > normalized_dot_diff_threshold:
		# The latest segment can be updated if it's close enough to the intended curve
		curve.set_point_position(curve.point_count - 1, player_view.cursor.global_position)
		trajectory_data.curves.set_point_position(curve.point_count - 1, player_view.cursor.global_position)

	# Keep track of time spent in one place
	cursor_slow_pos = lerp(cursor_slow_pos, player_view.cursor.global_position, cursor_follow_responsiveness)
	var cursor_in_place: bool = (
		(cursor_slow_pos - player_view.cursor.global_position).length() < cursor_in_place_distance_threshold
		and (cursor_last_pos - player_view.cursor.global_position).length() < cursor_in_place_distance_threshold
	)
	if cursor_in_place: cursor_time_spent_in_place_sec += delta
	else:
		cursor_last_pos = player_view.cursor.global_position
		cursor_time_spent_in_place_sec = 0.

	if cursor_time_spent_in_place_sec >= stopping_time_threshold_sec:
		if ( # Add the new segment for the stop if current position is far enough from the segment position
			(
				trajectory_data.curves.get_point_position(trajectory_data.curves.point_count - 2)
				- player_view.cursor.global_position
			).length() >= cursor_in_place_distance_threshold
		): _add_point_to_curve(player_view.cursor.global_position)
		trajectory_data.stop_durations_sec[-1] = cursor_time_spent_in_place_sec
