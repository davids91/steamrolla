class_name PusherCar
extends AnimatableBody3D

signal finished()

func crashed(_body: Node3D, _force: float) -> void: pass # To trigger crash with movable cars

func _ready() -> void:
	if not trajectory or not pivot:
		push_warning("Pusher car without trajectory!")
		queue_free()
		return
	time_left_for_segment_sec = trajectory.segment_durations_sec[0]
	progress_left_for_segment = trajectory.segment_normalized_progress[0]
	$CarBody.set_surface_override_material(0, $CarBody.get_active_material(0).duplicate())

#TechDebt: Horn logic is duplicated between pusher car and crashable car
@export var horn_interval_sec: float = 2.8
@export_range(0., 1.) var horn_randomness_percentage: float = 0.2
@export_range(0., 1.) var double_horn_chance: float = 0.3
@export var double_horn_pitch: float = 1.4
@onready var time_to_horn_sec: float = horn_interval_sec + randfn(0., horn_interval_sec * horn_randomness_percentage)
func _process(delta: float) -> void:
	# Handle Horn
	if not $HornSound.playing:
		time_to_horn_sec -= delta
		if 0. > time_to_horn_sec:
			time_to_horn_sec = horn_interval_sec + randfn(0., horn_interval_sec * horn_randomness_percentage)
			if randf() < double_horn_chance:
				$HornSound.pitch_scale = double_horn_pitch
				$HornSound.finished.connect($HornSound.play, CONNECT_ONE_SHOT)
			else:
				$HornSound.pitch_scale = 1.
			$HornSound.play()

@export var trajectory_speed_modifier: float = 3.
@onready var segment_progress: int = 0
var time_left_for_segment_sec: float = 0.
var progress_left_for_segment: float = 0.
var trajectory: TrajectoryData
var pivot: PathFollow3D
func _physics_process(delta: float) -> void:
	if not friends_in_me.is_empty(): return
	time_left_for_segment_sec -= delta
	var time_spent_in_current_segment = trajectory.segment_durations_sec[segment_progress] - time_left_for_segment_sec

	# In case segment progress is out of bounds, increase pivot progress gradually
	if abs(segment_progress) >= trajectory.segment_durations_sec.size():
		pivot.progress_ratio += trajectory_speed_modifier * delta

	# Handle increasing progress of the pivot based on the trajectory data
	if(time_spent_in_current_segment >= trajectory.stop_durations_sec[segment_progress]):
		var progress_to_increase: float = progress_left_for_segment * delta / time_left_for_segment_sec
		progress_left_for_segment -= progress_to_increase
		pivot.progress_ratio += progress_to_increase
		if 0. >= time_left_for_segment_sec:
			segment_progress += 1
			if segment_progress < trajectory.segment_durations_sec.size():
				time_left_for_segment_sec = trajectory.segment_durations_sec[segment_progress] - time_left_for_segment_sec
				progress_left_for_segment = trajectory.segment_normalized_progress[segment_progress]
			else:
				finished.emit()
				queue_free()
	if 1. <= pivot.progress_ratio:queue_free()

	# Set transform based on pivot and floor raycast
	var updated_transform: Transform3D = pivot.global_transform

	# Correct transform based on collision point
	if $FloorRaycast.is_colliding():
		updated_transform.origin.y = $FloorRaycast.get_collision_point().y

	global_transform = updated_transform

var friends_in_me: Array[PusherCar]
func _on_friend_detector_body_entered(body: Node3D) -> void:
	if body is PusherCar and body != self: friends_in_me.push_back(body)

func _on_friend_detector_body_exited(body: Node3D) -> void:
	if body is PusherCar and body != self: friends_in_me.erase(body)
