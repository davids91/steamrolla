extends RoadworkTool

#region from @RoadworkTools
func set_color(color: Color) -> void:
	create_tween().tween_property($DisplayMesh.get_active_material(0), "albedo_color", color, 0.5)

func set_angle_from_prev_pos(prev_pos: Vector3) -> void:
	look_at(global_position + (global_position - prev_pos))

@export var drag_response: float = 0.1
func set_transform_based_on(target_position: Vector3) -> void:
	global_position = lerp(global_position, target_position, drag_response)
	set_angle_from_prev_pos(previous_position)

func start_working() -> void:
	if controlled_by == RoadworkTool.ControlMethods.PILOTED: $OrbitCamera.make_current()
	set_color(default_color)
	super()
#endregion

var ground_entered: bool = false
func _on_body_representation_body_entered(body: Node3D) -> void:
	if body is RoadChunkBody: ground_entered = true

func _on_body_representation_body_exited(body: Node3D) -> void:
	if body is RoadChunkBody: ground_entered = false


func _physics_process(delta: float) -> void:
	super(delta)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var raycast_result: Dictionary = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 100., 0.0), global_position - Vector3(0.0, 100., 0.0)
	))
	if "position" in raycast_result: global_position.y = raycast_result.position.y
