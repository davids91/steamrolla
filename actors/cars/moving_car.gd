class_name MovingCar
extends RigidBody3D

signal finished()

@export var trajectory_crash_velo_multiplier: float = 3.81
@export var trajectory_crash_angle_multiplier: float = 5.
func _ready() -> void:
	$CarBody.set_surface_override_material(0, $CarBody.get_active_material(0).duplicate())
	if trajectory != null and pivot != null:
		large_velocity_dot_threshold_for_crash /= trajectory_crash_angle_multiplier
		mid_velocity_dot_threshold_for_crash /= trajectory_crash_angle_multiplier
		large_velocity_delta_threshold_for_crash *= trajectory_crash_velo_multiplier
		mid_velocity_delta_threshold_for_crash *= trajectory_crash_velo_multiplier

@export var horn_interval_sec: float = 2.8
@export_range(0., 1.) var horn_randomness_percentage: float = 0.2
@export_range(0., 1.) var double_horn_chance: float = 0.3
@export var double_horn_pitch: float = 1.4
@onready var time_to_horn_sec: float = horn_interval_sec + randfn(0., horn_interval_sec * horn_randomness_percentage)
func _process(delta: float) -> void:
	if not crashed and not $HornSound.playing:
		time_to_horn_sec -= delta
		if 0. > time_to_horn_sec:
			time_to_horn_sec = horn_interval_sec + randfn(0., horn_interval_sec * horn_randomness_percentage)
			if randf() < double_horn_chance:
				$HornSound.pitch_scale = double_horn_pitch
				$HornSound.finished.connect($HornSound.play, CONNECT_ONE_SHOT)
			else:
				$HornSound.pitch_scale = 1.
			$HornSound.play()

@export var force_strength: float = 25.:
	set(v):
		force_strength = v
		if not trajectory or not pivot:
			constant_force = global_basis.z * force_strength
@export var crash_min_velocity_threshold: float = 5.
@export var large_velocity_delta_threshold_for_crash: float = 25.
@export var large_velocity_dot_threshold_for_crash: float = 15.
@export var mid_velocity_delta_threshold_for_crash: float = 10.
@export var mid_velocity_dot_threshold_for_crash: float = 100.
@export var velocity_standstill_epsilon: float = 0.1
@export var velocity_standstill_threshold_sec: float = 1.
@export var crash_sets_in_sec: float = 0.6
@export var crash_noise: FastNoiseLite
@onready var crashed: bool = false:
	set(v):
		$SmokeParticles.emitting = v
		if not crashed and v:
			crash_noise.offset = Vector3(randf_range(-500., 500.), randf_range(-500., 500.), randf_range(-500., 500.))
			var noise_texture: NoiseTexture2D = NoiseTexture2D.new()
			noise_texture.noise = crash_noise
			$CarBody.get_surface_override_material(0).set_shader_parameter("crash_noise", noise_texture)
			create_tween().tween_method(
				func(w: float): $CarBody.get_surface_override_material(0).set_shader_parameter("crash_amount", w),
				0., 1., crash_sets_in_sec
			)
			finished.emit()
			constant_force = Vector3.ZERO
		crashed = v

@onready var previous_velocity: Vector3 = linear_velocity
@onready var standing_still_since: float = 0.
func _crash_detection(delta: float) -> void:
	# Crash based on flipping over
	if basis.y.y < -0.3: crashed = true

	# Crash based on standing still
	var velocity_delta: float = (previous_velocity - linear_velocity).length()
	var velocity_dot_abs: float = abs(previous_velocity.dot(linear_velocity))
	if linear_velocity.length() < velocity_standstill_epsilon:
		standing_still_since += delta
		if(
			not pivot or not trajectory
			or(
				trajectory.stop_durations_sec[current_segment] > 0.
				and trajectory.stop_durations_sec[current_segment] < time_in_segment
			)
		): crashed = true

	# Crash based on sudden velocity change
	if(
		not crashed # Not crashed already
		and linear_velocity.length() > crash_min_velocity_threshold
		and( # Detect crash from velocity delta and delta velocity dot product (smaller dot means larger angular diff)
			velocity_delta > large_velocity_delta_threshold_for_crash
			or velocity_dot_abs < large_velocity_dot_threshold_for_crash
			or(
				velocity_delta > mid_velocity_delta_threshold_for_crash
				and velocity_dot_abs < mid_velocity_dot_threshold_for_crash
			)
		)
	):
		crashed = true
		force_strength = 0.
		if randf() < 0.5: $CrashSoundEek.play()
		if randf() < 0.5: $CrashSoundCrunch.play()
		$CrashSoundBoom.play()
	previous_velocity = linear_velocity

@export var trajectory_speed_modifier: float = 4.
@export var distance_from_pivot_to_step: float = 4.
@export var distance_from_pivot_to_intensify: float = 2.
@export var upwards_force_ratio_for_obstacles: float = 0.3
@export var turning_force_harshness_ratio: float = 0.2
@export var gravity: Vector3 = Vector3(0., -0.15, 0.)
@onready var time_in_segment: float = 0.
@onready var current_segment: int = 0
var trajectory: TrajectoryData
var pivot: PathFollow3D
func _trajectory_handling(delta: float) -> void:
	if not trajectory or not pivot or crashed: return

	var to_pivot: Vector3 = Vector3(
		pivot.global_position.x - global_position.x,
		sign(pivot.global_position.y - global_position.y) * $BodyShape.shape.size.y * upwards_force_ratio_for_obstacles,
		pivot.global_position.z - global_position.z,
	)
	var pivot_distance: float = (
		Vector3(global_position.x, 0., global_position.z)
		- Vector3(pivot.global_position.x, 0., pivot.global_position.z)
	).length()
	var close_enough: bool = pivot_distance <= distance_from_pivot_to_step
	var segment_progress: int = min(
		round(pivot.progress_ratio * float(trajectory.segment_normalized_progress.size() - 1)),
		trajectory.segment_normalized_progress.size() - 1
	)
	var speed: float = (
		# The amount the car should advance in this segment --> distance covered
		trajectory.segment_normalized_progress[segment_progress] * trajectory.curves.get_baked_length()
		/ trajectory.segment_durations_sec[segment_progress] # The unit of time to cover the distance
	) * trajectory_speed_modifier

	# Handle timing in current segment
	if current_segment != segment_progress: time_in_segment = 0.
	else: time_in_segment += delta
	current_segment = segment_progress

	# Handle pivot progress and force calculations
	if time_in_segment >= trajectory.stop_durations_sec[segment_progress]:
		pivot.progress = max(pivot.progress, trajectory.curves.get_closest_offset(global_position) + speed * delta)
	if pivot.progress_ratio >= 1. and close_enough:
		finished.emit()
		queue_free()
	else: # Set force to current trajectory
		var force_intensity: float = max(pivot_distance, 0.00001) / distance_from_pivot_to_intensify
		constant_force = lerp(
			constant_force,
			to_pivot.normalized() * force_strength * speed * force_intensity * trajectory_speed_modifier * delta,
			turning_force_harshness_ratio
		)
		constant_force.y = $BodyShape.shape.size.y * 0.5 # Only have minimal upward force
		if (global_position.y - pivot.global_position.y) > distance_from_pivot_to_step * 2.:
			constant_force += gravity

		# Set angular velocity
		var candidate_angular_velocity: Vector3 = (
			basis.z.cross(pivot.basis.z).normalized()
			* speed * force_strength * force_intensity * delta
		)
		candidate_angular_velocity.z = -global_rotation.z # Try to not tilt sideways
		angular_velocity = lerp(
			angular_velocity,
			candidate_angular_velocity,
			turning_force_harshness_ratio
		)
		linear_velocity = linear_velocity.limit_length(speed)

		if( # correct force for stopping or trajectory correction
			(
				time_in_segment < trajectory.stop_durations_sec[segment_progress]
				and 0. < trajectory.stop_durations_sec[segment_progress]
			)
			or pivot_distance >= distance_from_pivot_to_intensify
		): constant_force = lerp(
				constant_force,
				(
					(pivot.global_position - (global_position + linear_velocity))
					* force_strength * force_intensity * delta
				),
				turning_force_harshness_ratio
			)
		if close_enough:
			constant_force = constant_force.limit_length(force_strength)
			constant_force *= 1. - turning_force_harshness_ratio

func _physics_process(delta: float) -> void:
	_crash_detection(delta)
	_trajectory_handling(delta)

@export var sibling_crash_speed_sum_threshold: float = 15.
func _on_body_entered(body: Node) -> void:
	if(
		not crashed
		and (
			body is MovingCar
			and (body.linear_velocity + linear_velocity).length() < sibling_crash_speed_sum_threshold
			and (body.linear_velocity.length() > sibling_crash_speed_sum_threshold or linear_velocity.length() > sibling_crash_speed_sum_threshold)
		)
	): crashed = true
	if not crashed and body.has_method("crashed"):
		crashed = true
		body.crashed(self, linear_velocity.length())
