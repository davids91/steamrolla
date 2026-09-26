extends RoadworkTool

#region from @RoadworkTools
func prepare_for_runway() -> void:
	asphalt_remaining = asphalt_capacity

var opacity: float = 1.
func set_color(color: Color) -> void:
	create_tween().tween_property($DisplayMesh.get_active_material(0), "albedo_color", color, 0.5)
	var local_opacity: float = opacity
	create_tween().tween_method(
		func(w: float):
			$AsphaltPile.get_active_material(0).set_shader_parameter("opacity", w)
			opacity = w,
		local_opacity, color.a, 0.5
	)

func set_angle_from_prev_pos(prev_pos: Vector3) -> void:
	look_at(global_position + (global_position - prev_pos))

@export_range(0. , 1.) var dynamism: float = 0.1
func set_transform_based_on(target_position: Vector3) -> void:
	global_position = lerp(global_position, target_position, dynamism)
	set_angle_from_prev_pos(previous_position)

func start_working() -> void:
	if controlled_by == RoadworkTool.ControlMethods.PILOTED: $OrbitCamera.make_current()
	super()

func stop_working() -> void:
	$ActiveSound.stop()
	super()
#endregion

var ground_entered: bool = false
func _on_body_representation_body_entered(body: Node3D) -> void:
	if body is RoadChunkBody: ground_entered = true

func _on_body_representation_body_exited(body: Node3D) -> void:
	if body is RoadChunkBody: ground_entered = false

@export var asphalt_height_for_quantity: float = 2.
@export var asphalt_capacity: float = 1.
@export var asphalt_usage_per_sec: float = 1.
@onready var asphalt_remaining: float = asphalt_capacity:
	set(v):
		asphalt_remaining = v
		$AsphaltPile.get_active_material(0).set_shader_parameter("asphalt_pile_size", v * asphalt_height_for_quantity)

func _process(delta: float) -> void:
	super(delta)
	if 0. >= asphalt_remaining: payload_triggered = false
	if is_working and payload_triggered:
		if asphalt_remaining == asphalt_capacity: $ActiveSound.play()
		asphalt_remaining = max(0., asphalt_remaining - asphalt_usage_per_sec * delta)
	else: $ActiveSound.stop()

func _physics_process(delta: float) -> void:
	super(delta)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var raycast_result: Dictionary = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 100., 0.0), global_position - Vector3(0.0, 100., 0.0)
	))
	if "position" in raycast_result: global_position.y = lerp(global_position.y, raycast_result.position.y, dynamism)
