class_name MovingCar
extends RigidBody3D

@export var force_strength: float = 25.:
	set(v):
		force_strength = v
		constant_force = global_basis.z * force_strength

var crashed: bool = false
func _on_collision_detector_body_entered(body: Node3D) -> void:
	if body != self:
		crashed = true
		force_strength = 0.
