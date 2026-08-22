class_name RollerController
extends RoadworkTool

@export var color_responsiveness: float = 0.075
var target_color: Color = default_color
var current_color: Color = default_color

@onready var skin: MeshInstance3D = $roller/Roller
#region from @RoadworkTools
func set_color(color: Color) -> void:
	target_color = color

func set_angle_from_prev_pos(prev_pos: Vector3) -> void:
	look_at(global_position - (global_position - prev_pos))

func start_working() -> void:
	if controlled_by == RoadworkTool.ControlMethods.PILOTED: $OrbitCamera.make_current()
	set_color(default_color)
	super()

func stop_working() -> void:
	if controlled_by != ControlMethods.PILOTED: set_color(Color.TRANSPARENT)
	$SqueezeSound.stop()
	super()

func work_at_cursor(target_position: Vector3) -> void:
	if not controlled_by == RoadworkTool.ControlMethods.DRAGGED: return
	if not is_working: $SqueezeSound.play(randf() * 1.89)
	super(target_position)
#endregion

var is_on_asphalt: bool = false
var was_on_asphalt: bool = is_on_asphalt
var connected_chunk: RoadChunkBody
func _on_asphalt_detector_body_entered(body: Node3D) -> void:
	if not connected_chunk or body is RoadChunkBody:
		connected_chunk = body as RoadChunkBody

func _on_asphalt_detector_body_exited(body: Node3D) -> void:
	if body == connected_chunk: connected_chunk = null

var moving_transparency_modifier: float = 0.
func _process(delta: float) -> void:
	super(delta)
	var movement_direction: Vector3 = (basis.z * -movement_intent.y).normalized()
	var camera_direction: Vector3 = ($OrbitCamera.get_view_origin() - global_position)
	if 0. > movement_direction.dot(camera_direction): moving_transparency_modifier = -1.
	else: moving_transparency_modifier = 0.
	current_color = lerp(
		current_color, Color(target_color.r, target_color.g, target_color.b, target_color.a + moving_transparency_modifier),
		color_responsiveness
	)
	skin.get_active_material(0).albedo_color = current_color

func _physics_process(delta: float) -> void:
	super(delta)
	if connected_chunk: is_on_asphalt = connected_chunk.is_on_asphalt(global_position)
	if(
		is_reversing != (direction.z > 0.0) or is_moving != (direction.z != 0.0)
		or was_on_asphalt != is_on_asphalt
	):
		var sound_should_be_playing: bool = (direction.z != 0.0) and is_on_asphalt
		if sound_should_be_playing: # Play from a random time within the length of the audio stream if not already playing
			if not $SqueezeSound.playing:
				$SqueezeSound.play(randf() * 1.89)
		else: $SqueezeSound.stop()
	was_on_asphalt = is_on_asphalt

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var raycast_result: Dictionary = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 100., 0.0), global_position - Vector3(0.0, 100., 0.0)
	))
	if "position" in raycast_result:
		global_position.y = raycast_result.position.y
