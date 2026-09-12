@tool
extends Node3D

func _ready() -> void: for c in get_children(): if c is RoadChunk: c._initialize(c.level_data)

@export var camera_speed: float = 0.01
func _process(delta: float) -> void:
	$CameraPath/Follower.progress_ratio += delta * camera_speed
	if$CameraPath/Follower.progress_ratio > 1.: $CameraPath/Follower.progress_ratio -= 1.
	$CameraPath/Follower/Camera3D.look_at($CameraPath/CameraTarget.global_position)
