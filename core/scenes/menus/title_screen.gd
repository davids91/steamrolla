extends Node3D

func _ready() -> void:
	%Intersection.used_base_dir = "res://levels/2_1intersection/"
	%Intersection.initialize(LevelStructure.resource_path_in_dir("res://levels/2_1intersection/"))
