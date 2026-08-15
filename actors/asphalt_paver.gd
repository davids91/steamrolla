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

var ground_entered: bool = false
func _on_body_representation_body_entered(body: Node3D) -> void:
	if body is RoadChunkBody: ground_entered = true

func _on_body_representation_body_exited(body: Node3D) -> void:
	if body is RoadChunkBody: ground_entered = false
