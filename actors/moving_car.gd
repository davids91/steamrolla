class_name MovingCar
extends RigidBody3D


func _ready() -> void:
	$CarBody.set_surface_override_material(0, $CarBody.get_active_material(0).duplicate())

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
		crashed = v
		if crashed:
			crash_noise.offset = Vector3(randf_range(-500., 500.), randf_range(-500., 500.), randf_range(-500., 500.))
			var noise_texture: NoiseTexture2D = NoiseTexture2D.new()
			noise_texture.noise = crash_noise
			$CarBody.get_surface_override_material(0).set_shader_parameter("crash_noise", noise_texture)
			create_tween().tween_method(
				func(w: float): $CarBody.get_surface_override_material(0).set_shader_parameter("crash_amount", w),
				0., 1., crash_sets_in_sec
			)
@onready var previous_velocity: Vector3 = linear_velocity
@onready var standing_still_since: float = 0.
func _physics_process(delta: float) -> void:
	var velocity_delta: float = (previous_velocity - linear_velocity).length()
	var velocity_dot_abs: float = abs(previous_velocity.dot(linear_velocity))
	if velocity_delta < velocity_standstill_epsilon:
		standing_still_since += delta
		if not crashed and standing_still_since >= velocity_standstill_threshold_sec:
			crashed = true
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

func _on_body_entered(body: Node) -> void:
	if body.has_method("crashed") and not crashed:
		body.crashed(self, linear_velocity.length())
