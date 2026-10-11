extends Node3D

func _ready() -> void:
	%Intersection.used_base_dir = "res://levels/2_1intersection/"
	%Intersection.initialize(LevelStructure.resource_path_in_dir(%Intersection.used_base_dir))
	if LevelStructure.level_attribute_present(%Intersection.used_base_dir, "pipe_covered"):
		%Pipe/WaterSpurt.emitting = false
