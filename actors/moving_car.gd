class_name MovingCar
extends RigidBody3D

@export var force_strength: float = 25.:
	set(v):
		force_strength = v
		constant_force = global_basis.z * force_strength
@export var crash_min_velocity_threshold: float = 5.
@export var large_velocity_delta_threshold_for_crash: float = 25.
@export var large_velocity_dot_threshold_for_crash: float = 15.
@export var mid_velocity_delta_threshold_for_crash: float = 10.
@export var mid_velocity_dot_threshold_for_crash: float = 100.
@onready var crashed: bool = false
@onready var previous_velocity: Vector3 = linear_velocity
func _physics_process(_delta: float) -> void:
	var velocity_delta: float = (previous_velocity - linear_velocity).length()
	var velocity_dot_abs: float = abs(previous_velocity.dot(linear_velocity))
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
	previous_velocity = linear_velocity
