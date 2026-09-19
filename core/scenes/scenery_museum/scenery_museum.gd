@tool
extends Node3D

func _ready() -> void: for c in get_children(): if c is RoadChunk: c._initialize(c.level_data)

@export var camera_speed: float = 0.01
func _process(delta: float) -> void:
	$CameraPath/Follower.progress_ratio += delta * camera_speed
	if$CameraPath/Follower.progress_ratio > 1.: $CameraPath/Follower.progress_ratio -= 1.
	$CameraPath/Follower/Camera3D.look_at($CameraPath/CameraTarget.global_position)

@onready var level_container: Node = get_node("/root/Main/LevelContainer")
func _on_exit_btn_pressed() -> void:
	for c in level_container.get_children(): c.queue_free()
	level_container.add_child(load("res://core/scenes/title_screen.tscn").instantiate())
