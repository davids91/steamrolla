extends Node3D

@export var speed: float = -0.025

func _process(delta: float) -> void:
	rotate_y(speed * delta)
