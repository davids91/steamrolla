extends RoadworkTool

#region Common Interface For Roadwork Tools
func set_color(color: Color) -> void:
	create_tween().tween_property($DisplayMesh.get_active_material(0), "albedo_color", color, 0.5)

func set_angle_from_prev_pos(prev_pos: Vector3) -> void:
	look_at(global_position + (global_position - prev_pos))

@export var drag_response: float = 0.1
func set_transform_based_on(target_position: Vector3) -> void:
	global_position = lerp(global_position, target_position, drag_response)
	set_angle_from_prev_pos(previous_position)
#endregion Common Interface For Roadwork Tools

var trajectory_tween: Tween
var trajectory_reference_pos: Vector3
func trajectory_drawn(trajectory: PathFollow3D, duration_sec: float, call_when_done: Callable) -> void:
	if trajectory_tween: return # Do not start multiple times at once
	trajectory.progress_ratio = 0.
	global_position = trajectory.global_position
	set_color(default_color)
	start_working()
	trajectory_reference_pos = global_position
	get_tree().create_timer(0.0).timeout.connect(func():
		trajectory_tween = create_tween()
		trajectory_tween.tween_method(
			func(w: float):
				trajectory.progress_ratio = w
				trajectory_reference_pos = lerp(global_position, trajectory_reference_pos, inv_turn_responsiveness)
				global_position = trajectory.global_position
				set_angle_from_prev_pos(trajectory_reference_pos),
			0., 1., duration_sec
		).set_ease(Tween.EASE_IN_OUT).finished.connect(func():
			stop_working()
			set_color(Color.TRANSPARENT)
			trajectory_tween = null
			call_when_done.call()
		)
	)
var ground_entered: bool = false
func _on_body_representation_body_entered(body: Node3D) -> void:
	if body is RoadChunkBody: ground_entered = true

func _on_body_representation_body_exited(body: Node3D) -> void:
	if body is RoadChunkBody: ground_entered = false
